--!strict
-- SkillTreeService (vague 27, liaison L-096 point 2 ; décision de Clément du 2026-11-11 : l'arbre sort au
-- lancement) : arbre de compétences côté serveur. Contrat partagé avec le client (SkillTreeController,
-- écran UI_SkillTree) : en-tête de Config/SkillTree. Valeurs : Partie 2, section 2 (V0 du doc).
--
-- Sauvegarde : champ facultatif SkillTree du profil, [Id] = niveau acheté (Types/Profile, sans changement
-- de version). Au chargement, nettoyé : Id inconnu retiré, niveau entier borné à MaxLevel, niveau ≤ 0
-- retiré (table vide : champ retiré). Puis l'attribut `Skill_<Id>` (SkillTree.AttributePrefix) = niveau,
-- 0 compris, est posé sur le Player pour chaque Id de Config/SkillTree ; republié à chaque achat.
--
-- Remote BuySkill(id) (Net/Definitions ; Net a déjà contrôlé la forme et le débit) : achète le niveau
-- suivant. Le serveur décide tout, dans cet ordre :
--   - Id inconnu ou profil pas chargé : envoi malhonnête, ignoré sans message (une ligne en Studio) ;
--   - tuile fermée (OpensWhen : la compétence voisine n'a pas le niveau demandé), niveau maximum
--     atteint, niveau suivant au-delà de Coded ou sans prix (« Soon »), argent insuffisant au prix
--     Prices[niveau suivant] : refus honnête, Notify « Warning » en anglais ;
--   - accepté : DataService.SpendCash, niveau + 1 dans le profil, attribut republié, Notify « Success »,
--     télémétrie (genre Defense de Config/Telemetry, SKU = Id, champ « Level - n », et l'événement
--     DefenseBought), puis OnChanged. Débit et octroi dans la même exécution, sans yield.
-- Aucun lieu imposé : l'écran s'ouvre de partout (bouton du HUD).
--
-- Effets codés (Coded > 0), sur la boutique du joueur, par les points d'accroche de WindowService et de
-- PvPService (remplacés à l'Init, comme PvPService remplace WindowService.CanBeHit) :
--   GlassThickness  PV max de la vitrine de sa boutique × Effects[niveau] (WindowService.GetPlotHPMultiplier ;
--                   base : PvP.PlayerWindowHPPerDamage × dégâts du propriétaire). Relu à chaque tick de
--                   WindowService : l'achat compte dans les 0,1 s, à fraction de PV égale.
--   GlassRegen      réparation de Effects[niveau] des PV max par seconde au lieu de Balance.Window.RegenPerSecond
--                   (WindowService.GetPlotRegen).
--   Safe            présentoirs non volables = PvP.VaultSlots (1 offert) + Effects[niveau] (PvPService.GetVaultSlots).
--   Cameras         sur chaque coup compté sur la vitrine de sa boutique (WindowService.OnHit, coups refusés
--                   par les protections exclus) : niveau 1, le propriétaire est alerté dès le 1er coup, une
--                   fois par attaque (Notify « Warning », comme l'alarme de la casse de PvPService) ; une
--                   attaque = les coups d'un même joueur sur cette vitrine à moins de ATTACK_GAP s d'écart.
--                   Niveau 2 et plus : à la même alerte, CameraSpotted(attaquant, fin) au seul propriétaire,
--                   fin = heure serveur + Effects[niveau] s (30) : CameraAlertController (client) le surligne
--                   à travers les murs. Le niveau 3 (flèche, distance, son) n'est pas codé (Coded = 2).
--   PotionLuck et PotionTime (vague 28) : lus par PotionService avec GetEffect (délai entre deux potions
--                   × Effects[niveau], durée d'un effet × Effects[niveau]) ; rien à brancher ici.
-- Les compétences « Soon » (Coded = 0) n'ont aucun effet.
--
-- API (serveur) :
--   SkillTreeService.GetLevel(player, id) -> number      niveau acheté (0 sans profil ou Id inconnu)
--   SkillTreeService.GetEffect(player, id) -> number?    Effects[niveau] ; nil au niveau 0
--   SkillTreeService.OnChanged(listener) -> déconnexion
--       listener(player, id, level) après chaque achat accepté (niveau atteint), attribut déjà publié.
--
-- Tester dans Studio (barre de commande serveur ; hors de Studio, l'attribut n'est pas écouté) :
--   workspace:SetAttribute("SkillTest", "<joueur> cash 1000000")   ajoute de l'argent (joueur = nom ou UserId)
--   workspace:SetAttribute("SkillTest", "<joueur> Cameras 2")      met une compétence à ce niveau (borné)
--   workspace:SetAttribute("SkillTest", "<joueur> reset")          remet tout l'arbre à 0

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local PvP = require(Shared.Config.PvP)
local SkillTree = require(Shared.Config.SkillTree)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local PvPService = require(script.Parent.PvPService)
local TelemetryService = require(script.Parent.TelemetryService)
local WindowService = require(script.Parent.WindowService)

type Data = ProfileTypes.Data
type Skill = SkillTree.Skill
type ChangedListener = (player: Player, id: string, level: number) -> ()

-- Une attaque en cours sur la vitrine d'un propriétaire, par attaquant (Cameras).
type Attack = {
	LastHit: number, -- os.clock() du dernier coup compté
}

-- V0 proposé, absent du doc : deux coups du même joueur à plus de ATTACK_GAP s d'écart = deux attaques
-- (une vitrine se répare entièrement en 33 s au plus, à 3 %/s).
local ATTACK_GAP = 30
local OWNER_ATTRIBUTE = "OwnerUserId" -- posé par PlotService sur la parcelle (lu aussi par WindowService)
local TEST_ATTRIBUTE = "SkillTest"
-- Genre et événement de télémétrie (Config/Telemetry) : les compétences codées sont des défenses de boutique.
local TELEMETRY_KIND = "Defense"
local TELEMETRY_EVENT = "DefenseBought"

-- Messages lus par le joueur (Notify), en anglais (L-036). V0 proposés, absents du doc.
local MESSAGES = {
	Locked = "Locked: get %s level %d first.",
	Max = "%s is already at max level.",
	Soon = "%s: coming soon!",
	NotEnoughCash = "Not enough cash: %s needed.",
	Bought = "%s upgraded: %s!",
	CameraAlert = "Your cameras spotted %s hitting your shop door!",
}

local IS_STUDIO = RunService:IsStudio()

local SkillTreeService = {}

local changedListeners: { ChangedListener } = {}
local attacks: { [Player]: { [Player]: Attack } } = {} -- [propriétaire][attaquant]

local function log(message: string)
	if IS_STUDIO then
		print(`[SkillTreeService] {message}`)
	end
end

-- Refus d'un envoi malhonnête : rien pour le joueur, une ligne en Studio.
local function reject(player: Player, id: string, reason: string)
	if IS_STUDIO then
		warn(`[SkillTreeService] {player.Name} → BuySkill(« {id} ») refusé : {reason}`)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[SkillTreeService] Notify vers {player.Name} : {err}`)
	end
end

------------------------------------------------------------------------------
-- Niveaux
------------------------------------------------------------------------------

-- Niveau sauvegardé, borné (0 si absent ou illisible).
local function levelIn(data: Data, skill: Skill): number
	local tree = data.SkillTree
	local value = if tree then tree[skill.Id] else nil
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, skill.MaxLevel)
end

local function isOpen(data: Data, skill: Skill): boolean
	local opens = skill.OpensWhen
	if opens == nil then
		return true
	end
	local neighbour = SkillTree.ById[opens.Id]
	return neighbour ~= nil and levelIn(data, neighbour) >= opens.Level
end

local function publish(player: Player, data: Data)
	for _, skill in SkillTree.List do
		local name = SkillTree.AttributePrefix .. skill.Id
		local level = levelIn(data, skill)
		if player:GetAttribute(name) ~= level then
			player:SetAttribute(name, level)
		end
	end
end

-- Nettoyage du chargement (voir l'en-tête). Renvoie le nombre d'entrées retirées ou corrigées.
local function sanitize(data: Data): number
	local raw: any = data.SkillTree
	if raw == nil then
		return 0
	end
	if type(raw) ~= "table" then
		data.SkillTree = nil
		return 1
	end
	local clean: { [string]: number } = {}
	local fixed = 0
	local count = 0
	for key, value in raw do
		local skill = if type(key) == "string" then SkillTree.ById[key] else nil
		if skill == nil or type(value) ~= "number" or value ~= value then
			fixed += 1
			continue
		end
		local level = math.clamp(math.floor(value), 0, skill.MaxLevel)
		if level ~= value then
			fixed += 1
		end
		if level > 0 then
			clean[skill.Id] = level
			count += 1
		end
	end
	data.SkillTree = if count > 0 then clean else nil
	return fixed
end

local function setLevel(player: Player, data: Data, skill: Skill, level: number)
	local tree = data.SkillTree or {}
	tree[skill.Id] = if level > 0 then level else nil
	data.SkillTree = if next(tree) ~= nil then tree else nil
	publish(player, data)
end

local function emitChanged(player: Player, id: string, level: number)
	for _, listener in table.clone(changedListeners) do
		task.spawn(listener, player, id, level)
	end
end

------------------------------------------------------------------------------
-- Achat
------------------------------------------------------------------------------

local function onBuySkill(player: Player, id: string)
	local skill = SkillTree.ById[id]
	if skill == nil then
		reject(player, id, "Id inconnu")
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		reject(player, id, "profil pas chargé")
		return
	end
	if not isOpen(data, skill) then
		local opens = skill.OpensWhen :: SkillTree.Opens
		local neighbour = SkillTree.ById[opens.Id]
		notify(player, string.format(MESSAGES.Locked, if neighbour then neighbour.DisplayName else opens.Id, opens.Level), "Warning")
		return
	end
	local level = levelIn(data, skill)
	if level >= skill.MaxLevel then
		notify(player, string.format(MESSAGES.Max, skill.DisplayName), "Warning")
		return
	end
	local nextLevel = level + 1
	local price = skill.Prices[nextLevel]
	if nextLevel > skill.Coded or type(price) ~= "number" then
		notify(player, string.format(MESSAGES.Soon, skill.DisplayName), "Warning")
		return
	end
	if not DataService.SpendCash(player, price) then
		notify(player, string.format(MESSAGES.NotEnoughCash, Format.money(price)), "Warning")
		return
	end
	setLevel(player, data, skill, nextLevel)
	local label = skill.Labels[nextLevel] or `level {nextLevel}`
	notify(player, string.format(MESSAGES.Bought, skill.DisplayName, label), "Success")
	log(`{player.Name} : {skill.Id} niveau {level} → {nextLevel} pour {Format.money(price)}`)
	TelemetryService.LogEconomy(player, TELEMETRY_KIND, price, skill.Id, { `Level - {nextLevel}` })
	TelemetryService.LogEvent(player, TELEMETRY_EVENT, { `Defense - {skill.Id}`, `Level - {nextLevel}` })
	emitChanged(player, skill.Id, nextLevel)
end

------------------------------------------------------------------------------
-- Effets
------------------------------------------------------------------------------

function SkillTreeService.GetLevel(player: Player, id: string): number
	local skill = SkillTree.ById[id]
	local data = DataService.Get(player)
	if skill == nil or data == nil then
		return 0
	end
	return levelIn(data, skill)
end

function SkillTreeService.GetEffect(player: Player, id: string): number?
	local skill = SkillTree.ById[id]
	local level = SkillTreeService.GetLevel(player, id)
	if skill == nil or level <= 0 then
		return nil
	end
	return skill.Effects[level]
end

-- Caméras (voir l'en-tête).
local function onWindowHit(attacker: Player, _windowId: string, kind: string, model: Model, _damage: number)
	if kind ~= "Plot" then
		return
	end
	local ownerId = model:GetAttribute(OWNER_ATTRIBUTE)
	local owner = if type(ownerId) == "number" and ownerId ~= 0 then Players:GetPlayerByUserId(ownerId) else nil
	if owner == nil or owner == attacker or owner.Parent ~= Players then
		return
	end
	local level = SkillTreeService.GetLevel(owner, "Cameras")
	if level < 1 then
		return
	end
	local byAttacker = attacks[owner]
	if byAttacker == nil then
		byAttacker = {}
		attacks[owner] = byAttacker
	end
	local now = os.clock()
	local attack = byAttacker[attacker]
	local isNew = attack == nil or now - attack.LastHit > ATTACK_GAP
	byAttacker[attacker] = { LastHit = now }
	if not isNew then
		return
	end
	notify(owner, string.format(MESSAGES.CameraAlert, attacker.DisplayName), "Warning")
	local duration = SkillTreeService.GetEffect(owner, "Cameras")
	if level >= 2 and duration and duration > 0 then
		local ok, err = pcall(function()
			Net.Server.CameraSpotted:Fire(owner, attacker, Workspace:GetServerTimeNow() + duration)
		end)
		if not ok then
			warn(`[SkillTreeService] CameraSpotted vers {owner.Name} : {err}`)
		end
	end
	log(`{owner.Name} : caméras niveau {level}, {attacker.Name} frappe sa vitrine`)
end

local function installEffects()
	WindowService.GetPlotHPMultiplier = function(owner: Player): number
		return SkillTreeService.GetEffect(owner, "GlassThickness") or 1
	end
	WindowService.GetPlotRegen = function(owner: Player): number
		return SkillTreeService.GetEffect(owner, "GlassRegen") or Balance.Window.RegenPerSecond
	end
	PvPService.GetVaultSlots = function(owner: Player): number
		return PvP.VaultSlots + (SkillTreeService.GetEffect(owner, "Safe") or 0)
	end
	WindowService.OnHit(onWindowHit)
end

------------------------------------------------------------------------------
-- Chargement, départ, crochet de test
------------------------------------------------------------------------------

local function onProfileLoaded(player: Player)
	local data = DataService.Get(player)
	if data == nil or player.Parent == nil then
		return
	end
	local fixed = sanitize(data)
	if fixed > 0 then
		warn(`[SkillTreeService] {player.Name} : {fixed} entrée(s) de SkillTree corrigée(s) ou retirée(s) au chargement`)
	end
	publish(player, data)
end

local function onPlayerRemoving(player: Player)
	attacks[player] = nil
	for _, byAttacker in attacks do
		byAttacker[player] = nil
	end
end

local function findPlayer(who: string): Player?
	local userId = tonumber(who)
	for _, player in Players:GetPlayers() do
		if player.Name == who or (userId ~= nil and player.UserId == userId) then
			return player
		end
	end
	return nil
end

local function onTestAttribute()
	local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
	if value == nil then
		return
	end
	Workspace:SetAttribute(TEST_ATTRIBUTE, nil)
	local words: { string } = {}
	for word in string.gmatch(tostring(value), "%S+") do
		table.insert(words, word)
	end
	local player = if words[1] then findPlayer(words[1]) else nil
	local data = if player then DataService.Get(player) else nil
	if player == nil or data == nil then
		warn(`[SkillTreeService] test « {value} » : joueur introuvable ou profil pas chargé`)
		return
	end
	local command = words[2]
	local amount = tonumber(words[3])
	if command == "cash" and amount and amount > 0 then
		DataService.AddCash(player, amount)
		print(`[SkillTreeService] test : {player.Name} reçoit {Format.money(amount)}`)
	elseif command == "reset" then
		data.SkillTree = nil
		publish(player, data)
		print(`[SkillTreeService] test : arbre de {player.Name} remis à 0`)
	elseif command and SkillTree.ById[command] and amount then
		local skill = SkillTree.ById[command]
		local level = math.clamp(math.floor(amount), 0, skill.MaxLevel)
		setLevel(player, data, skill, level)
		emitChanged(player, skill.Id, level)
		print(`[SkillTreeService] test : {player.Name} {skill.Id} au niveau {level}`)
	else
		warn(`[SkillTreeService] test « {value} » : commande inconnue (cash <n>, reset, <Id> <niveau>)`)
	end
end

function SkillTreeService.OnChanged(listener: ChangedListener): () -> ()
	table.insert(changedListeners, listener)
	return function()
		local index = table.find(changedListeners, listener)
		if index then
			table.remove(changedListeners, index)
		end
	end
end

function SkillTreeService.Init()
	installEffects()
	Net.Server.BuySkill:Connect(onBuySkill)
	DataService.OnProfileLoaded(onProfileLoaded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTestAttribute)
	end
	local coded: { string } = {}
	for _, skill in SkillTree.List do
		if skill.Coded > 0 then
			table.insert(coded, `{skill.Id} {skill.Coded}/{skill.MaxLevel}`)
		end
	end
	log(`{#SkillTree.List} compétences, codées : {table.concat(coded, ", ")}`)
end

return SkillTreeService
