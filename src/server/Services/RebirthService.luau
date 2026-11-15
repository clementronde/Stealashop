--!strict
-- RebirthService (DEV-120, MAJ 3 ; vague 51, agent a164, 2026-11-14) : la renaissance côté serveur (Partie 2,
-- section 3.2 ; règles V0 de docs/claude/notes/renaissance-proposition.md, 1.1 à 1.3, tableau dans
-- Config/Rebirths). Rien n'est décidé (liaison L-158) : TOUT est V0 et reste coupé.
--
-- Interrupteur : Features.Rebirth (false). Coupé, ce service n'installe aucune accroche, ne pose aucun
-- attribut et ignore le remote Rebirth : le jeu ne change pas. En Studio seulement, on l'allume pour les
-- tests sans toucher à Features :
--   Workspace:SetAttribute("RebirthTest", true)              allumé (false ou nil : coupé)
--   Workspace:SetAttribute("RebirthTestLevel", "<UserId ou nom> <n>")   allumé, et le joueur passe à n
--                                                            renaissances faites (attribut remis à nil)
--
-- Remote Rebirth(level) (client → serveur ; Net a contrôlé forme et débit) : `level` = la renaissance que le
-- joueur confirme (renaissances faites + 1) ; une demande en retard (déjà faite, double clic) est ignorée.
-- Refus, dans l'ordre, chacun avec un Notify « Warning » et rien de changé : porte quelque chose (colis,
-- objet volé : CarryService) ; un de ses objets est en train d'être volé ; un objet ou un colis posé au sol
-- de sa boutique (« à ramasser d'abord ») ; pas l'objet requis (dans l'inventaire, sur un présentoir) ; pas
-- assez d'argent (argent + plaques de ses présentoirs).
--
-- Ce que la renaissance fait (proposition 1.1 et 1.2, V0) :
--   remis à zéro  argent (plaques encaissées d'abord), Speed et Strength, tapis, banc et présentoirs
--                 achetés (retour à Balance.Display.StartSlots), outils (Fists), auras et trails, coffre-fort
--                 du profil (Vault), gains hors ligne pas réclamés, et tous les objets sauf Rebirths.KeepItems ;
--                 l'objet requis est remis (la copie qui rapporte le moins) et ne compte pas dans les 3
--   colis         (question 5, proposition « ouverts d'office ») : chaque colis de l'inventaire compte comme
--                 l'objet qu'il contient pour le choix des 3 ; s'il est gardé, il devient cet objet (mutation
--                 comprise), sinon il part
--   3 objets      (question 9 : le sélecteur de Clément est retiré, L-158) : V0 = les 3 qui rapportent le plus
--                 (revenu 7.1 × mutation, comme Equip Best), à revenu égal un objet exposé d'abord puis le plus
--                 petit uid ; ils reviennent sur les présentoirs (DisplayService.PlaceAuto), sans antivol
--   gardé         index, arbre de compétences, achats Robux et Monetization, boosts, récompenses, tuto,
--                 Lifetime, réglages, potions en stock, zones atteintes
--   gagné         Rebirths (renaissances faites) + 1 dans le profil, d'où : revenus des présentoirs ×
--                 Rebirths.IncomeMultiplier (DisplayService.GetIncomeMultiplier ; pas le receleur), tapis ×
--                 Rebirths.TreadmillMultiplier (TrainingService.GetGainMultiplier), présentoirs à l'abri +
--                 Rebirths.ExtraSafes (PvPService.GetVaultSlots). Aura, trail, Marteau-piqueur, Bélier,
--                 2e agent et titre : notés gagnés (Rebirths.HasReward), sans effet en jeu tant qu'ils
--                 n'existent pas (Config/Rebirths, RewardEffect). Le Bélier n'agit pas sur les portes (L-163)
-- D'un seul tenant : toutes les écritures du profil se font dans une seule exécution sans yield (commit), le
-- versement de l'argent restant en dernier ; une sauvegarde de ProfileStore passe avant ou après, jamais au
-- milieu. Les services sont remis d'accord ensuite (affichage, outils, effets), chacun sous pcall : une
-- erreur là ne touche plus le profil. Puis DataService.Save. Télémétrie : dépense « Rebirth » (SKU Rebirth<n>)
-- et événement « Rebirth » (champ Level, valeur = temps de jeu cumulé en s).
--
-- Attributs du Player (seulement allumé ; lus par RebirthController) :
--   Rebirths          renaissances faites (0 au départ) ; sa présence dit au client que la renaissance est ouverte
--   RebirthItemOwned  true si le joueur a l'objet requis de la prochaine (hors sol), revu chaque seconde
--
-- API (serveur) :
--   RebirthService.IsEnabled() -> boolean
--   RebirthService.GetCount(player) -> number          renaissances faites (0 sans profil)
--   RebirthService.Request(player, level) -> (boolean, string?)
--       La même chose que le remote (bancs, panel admin plus tard) : true, ou false et la raison du refus.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rebirths = require(Shared.Config.Rebirths)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local CarryService = require(script.Parent.CarryService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local HeldItemService = require(script.Parent.HeldItemService)
local IndexService = require(script.Parent.IndexService)
local InventoryService = require(script.Parent.InventoryService)
local MachineVariantService = require(script.Parent.MachineVariantService)
local PlotService = require(script.Parent.PlotService)
local PvPService = require(script.Parent.PvPService)
local RayonService = require(script.Parent.RayonService)
local ShopService = require(script.Parent.ShopService)
local StatsService = require(script.Parent.StatsService)
local TelemetryService = require(script.Parent.TelemetryService)
local ToolService = require(script.Parent.ToolService)
local TrainingService = require(script.Parent.TrainingService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data
type Item = ProfileTypes.Item
type Mutation = ProfileTypes.Mutation

-- Un objet candidat au choix des 3 gardés : un objet du profil, ou l'objet d'un colis de l'inventaire.
type Candidate = {
	uid: string, -- uid de l'objet, ou du colis
	id: string, -- ItemId
	zone: number?,
	mutation: Mutation?,
	fromBox: boolean,
	exposed: boolean,
	income: number,
}

local IS_STUDIO = RunService:IsStudio()
local TEST_ATTRIBUTE = "RebirthTest"
local TEST_LEVEL_ATTRIBUTE = "RebirthTestLevel"
local COUNT_ATTRIBUTE = "Rebirths"
local OWNED_ATTRIBUTE = "RebirthItemOwned"
local OWNED_REFRESH = 1 -- s entre deux contrôles de l'objet requis (V0)
local DEFAULT_TOOL = "Fists"
local NOTIFY_WARNING = "Warning"
local NOTIFY_INFO = "Info"

-- Messages lus par le joueur (Notify), en anglais (L-036). V0, absents du doc.
local MESSAGES = {
	Carrying = "Bring home what you are carrying first.",
	Stolen = "One of your items is being stolen!",
	Floor = "Pick up the items and boxes on your shop floor first.",
	NoItem = "You need a %s to rebirth.",
	NoCash = "You need %s to rebirth.",
	Done = "Rebirth %d! Income x%s forever.",
	Announce = "%s reached Rebirth %d!",
}

local RebirthService = {}
RebirthService.Priority = 300 -- après SkillTreeService (100), MonetizationService (150) et PotionService : leurs accroches d'abord

local testOn = false

local function log(message: string)
	if IS_STUDIO then
		print(`[RebirthService] {message}`)
	end
end

local function isEnabled(): boolean
	return Features.Rebirth == true or (IS_STUDIO and testOn)
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[RebirthService] Notify vers {player.Name} : {err}`)
	end
end

-- Renaissances faites, lues dans le profil : entier ≥ 0.
local function countOf(data: Data?): number
	local value = if data then (data :: any).Rebirths else nil
	if type(value) ~= "number" or value ~= value or value < 1 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

local function count(player: Player): number
	return countOf(DataService.Get(player))
end

------------------------------------------------------------------------------
-- Objets
------------------------------------------------------------------------------

-- Revenu d'un objet ($/s), formule 7.1 × mutation (comme DisplayService et Equip Best) ; 0 si illisible.
local function incomeOf(id: string, zone: number?, mutation: Mutation?): number
	local def = Items.ById[id]
	if def == nil then
		return 0
	end
	local ok, value = pcall(Formulas.ItemIncome, zone or def.Zone or 1, def.Rarity, nil)
	if not ok or type(value) ~= "number" or value ~= value then
		return 0
	end
	return value * Mutations.IncomeMultiplier(mutation)
end

local function exposedSet(data: Data): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, uid in data.Display do
		set[uid] = true
	end
	return set
end

-- La copie de l'objet requis à remettre : celle qui rapporte le moins, parmi les objets hors sol ; nil sinon.
local function requiredUid(data: Data, itemId: string): string?
	local best: string? = nil
	local bestIncome = math.huge
	for uid, entry in data.Items do
		if type(entry) == "table" and entry.Id == itemId and entry.Spot == nil then
			local income = incomeOf(entry.Id, entry.Zone, entry.Mutation)
			if income < bestIncome or (income == bestIncome and best ~= nil and uid < best) then
				best, bestIncome = uid, income
			end
		end
	end
	return best
end

-- Les candidats au choix des 3 gardés, du meilleur au moins bon (voir l'en-tête), sans l'objet remis.
local function candidates(data: Data, remitted: string?): { Candidate }
	local exposed = exposedSet(data)
	local list: { Candidate } = {}
	for uid, entry in data.Items do
		if uid ~= remitted and type(entry) == "table" and Items.ById[entry.Id] ~= nil then
			table.insert(list, {
				uid = uid,
				id = entry.Id,
				zone = entry.Zone,
				mutation = entry.Mutation,
				fromBox = false,
				exposed = exposed[uid] == true,
				income = incomeOf(entry.Id, entry.Zone, entry.Mutation),
			})
		end
	end
	for uid, box in data.Boxes do
		if type(box) == "table" and type(box.ItemId) == "string" and Items.ById[box.ItemId] ~= nil then
			table.insert(list, {
				uid = uid,
				id = box.ItemId,
				zone = box.Zone,
				mutation = box.Mutation,
				fromBox = true,
				exposed = false,
				income = incomeOf(box.ItemId, box.Zone, box.Mutation),
			})
		end
	end
	table.sort(list, function(a: Candidate, b: Candidate): boolean
		if a.income ~= b.income then
			return a.income > b.income
		end
		if a.exposed ~= b.exposed then
			return a.exposed
		end
		return a.uid < b.uid
	end)
	return list
end

local function hasFloorStuff(data: Data): boolean
	for _, entry in data.Items do
		if type(entry) == "table" and entry.Spot ~= nil then
			return true
		end
	end
	for _, box in data.Boxes do
		if type(box) == "table" and box.Spot ~= nil then
			return true
		end
	end
	return false
end

local function hasStolenItem(player: Player, data: Data): boolean
	for uid in data.Items do
		if DisplayService.IsHeld(player, uid) then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Attributs
------------------------------------------------------------------------------

local function publish(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	if not isEnabled() then
		player:SetAttribute(COUNT_ATTRIBUTE, nil)
		player:SetAttribute(OWNED_ATTRIBUTE, nil)
		return
	end
	local done = countOf(data)
	if player:GetAttribute(COUNT_ATTRIBUTE) ~= done then
		player:SetAttribute(COUNT_ATTRIBUTE, done)
	end
	local tier = Rebirths.Get(done + 1)
	local owned = tier ~= nil and requiredUid(data, tier.ItemId) ~= nil
	if player:GetAttribute(OWNED_ATTRIBUTE) ~= owned then
		player:SetAttribute(OWNED_ATTRIBUTE, owned)
	end
end

local function publishAll()
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

------------------------------------------------------------------------------
-- La renaissance
------------------------------------------------------------------------------

-- Toutes les écritures du profil, d'un seul tenant (aucun yield). Renvoie les uid gardés (objets du profil
-- après coup) et les ItemId gardés qui sortent d'un colis (pour l'index).
local function commit(player: Player, data: Data, level: number, remitted: string): ({ string }, { string })
	local chosen: { Candidate } = {}
	for _, candidate in candidates(data, remitted) do
		if #chosen >= Rebirths.KeepItems then
			break
		end
		table.insert(chosen, candidate)
	end

	-- Objets : seuls les gardés restent (sans antivol ni place au sol) ; un colis gardé devient son objet.
	local kept: { [string]: Item } = {}
	local keptUids: { string } = {}
	local fromBoxes: { string } = {}
	local now = os.time()
	for _, candidate in chosen do
		if candidate.fromBox then
			local uid = candidate.uid
			while data.Items[uid] ~= nil or kept[uid] ~= nil do
				uid = HttpService:GenerateGUID(false)
			end
			kept[uid] = { Id = candidate.id, Source = "NPC", At = now, Zone = candidate.zone, Mutation = candidate.mutation }
			table.insert(keptUids, uid)
			table.insert(fromBoxes, candidate.id)
		else
			local entry = data.Items[candidate.uid]
			entry.AntiTheft = nil
			entry.UnlockAt = nil
			entry.Spot = nil
			kept[candidate.uid] = entry
			table.insert(keptUids, candidate.uid)
		end
	end
	table.clear(data.Items)
	for uid, entry in kept do
		data.Items[uid] = entry
	end
	table.clear(data.Display)
	table.clear(data.Vault)
	table.clear(data.Boxes)
	local hotbar = data.Hotbar
	if hotbar then
		for index, slot in hotbar do
			if slot ~= "Tool" and slot ~= "Bat" and slot ~= "" and kept[slot] == nil then
				hotbar[index] = ""
			end
		end
	end

	-- Stats, améliorations, outils, auras et trails, gains hors ligne.
	data.Stats.Speed = 0
	data.Stats.Strength = 0
	data.Upgrades.Treadmill = 0
	data.Upgrades.Bench = 0
	data.Upgrades.DisplaySlots = 0
	table.clear(data.Tools.Owned)
	table.insert(data.Tools.Owned, DEFAULT_TOOL)
	data.Tools.Equipped = DEFAULT_TOOL
	table.clear(data.Cosmetics.Auras)
	table.clear(data.Cosmetics.Trails)
	data.Cosmetics.EquippedAura = nil
	data.Cosmetics.EquippedTrail = nil
	data.Offline.Pending = nil

	-- Le compteur, puis l'argent en dernier (DataService.SpendCash : attribut Cash et écouteurs).
	;(data :: any).Rebirths = level
	if data.Cash > 0 then
		DataService.SpendCash(player, data.Cash)
	end
	return keptUids, fromBoxes
end

-- Remet chaque service d'accord avec le profil, chacun sous pcall.
local function refreshServices(player: Player, keptUids: { string }, fromBoxes: { string })
	local function step(name: string, fn: () -> ())
		local ok, err = pcall(fn :: any)
		if not ok then
			warn(`[RebirthService] {player.Name} : {name} après la renaissance : {err}`)
		end
	end
	step("StatsService", function()
		StatsService.Refresh(player)
	end)
	step("CosmeticService", function()
		CosmeticService.Refresh(player)
	end)
	step("ToolService", function()
		ToolService.RefreshDamage(player)
	end)
	step("ShopService", function()
		ShopService.RefreshPlayer(player)
	end)
	step("UnboxService", function()
		UnboxService.Refresh(player)
	end)
	step("plot", function()
		local plot = PlotService.GetPlot(player)
		if plot then
			MachineVariantService.Refresh(plot)
			RayonService.Refresh(plot)
		end
	end)
	step("DisplayService", function()
		for _, uid in keptUids do
			DisplayService.PlaceAuto(player, uid)
		end
	end)
	step("InventoryService", function()
		InventoryService.Refresh(player)
	end)
	step("IndexService", function()
		for _, itemId in fromBoxes do
			IndexService.Discover(player, itemId)
		end
	end)
end

local function request(player: Player, level: any): (boolean, string?)
	if not isEnabled() then
		return false, "Disabled"
	end
	local data = DataService.Get(player)
	if data == nil then
		return false, "NoProfile"
	end
	local done = countOf(data)
	if type(level) ~= "number" or level ~= done + 1 then
		return false, "Stale" -- déjà faite (double clic) ou demande d'un autre palier : ignorée
	end
	local tier = Rebirths.Get(level)
	if tier == nil then
		return false, "Stale"
	end
	if CarryService.IsCarrying(player) then
		notify(player, MESSAGES.Carrying, NOTIFY_WARNING)
		return false, "Carrying"
	end
	if hasStolenItem(player, data) then
		notify(player, MESSAGES.Stolen, NOTIFY_WARNING)
		return false, "Stolen"
	end
	if hasFloorStuff(data) then
		notify(player, MESSAGES.Floor, NOTIFY_WARNING)
		return false, "Floor"
	end
	local remitted = requiredUid(data, tier.ItemId)
	if remitted == nil then
		local def = Items.ById[tier.ItemId]
		notify(player, string.format(MESSAGES.NoItem, if def then def.DisplayName else tier.ItemId), NOTIFY_WARNING)
		return false, "NoItem"
	end
	if data.Cash + DisplayService.GetRegister(player) < tier.Cash then
		notify(player, string.format(MESSAGES.NoCash, Format.money(tier.Cash)), NOTIFY_WARNING)
		return false, "NoCash"
	end

	-- Tout ce qui suit est sans yield : deux demandes ne se croisent jamais. Avant le profil (sans perte si
	-- la suite échoue) : objet en main rangé, séance de tapis
	-- finie, poings en main, plaques encaissées.
	pcall(HeldItemService.Stow, player)
	pcall(TrainingService.Stop, player)
	pcall(ToolService.Equip, player, DEFAULT_TOOL)
	pcall(DisplayService.CashOut, player)
	local paid = data.Cash
	if paid < tier.Cash then
		notify(player, string.format(MESSAGES.NoCash, Format.money(tier.Cash)), NOTIFY_WARNING)
		return false, "NoCash"
	end
	local keptUids, fromBoxes = commit(player, data, level, remitted)

	refreshServices(player, keptUids, fromBoxes)
	publish(player)
	DataService.Save(player)
	pcall(TelemetryService.LogEconomy, player, "Rebirth", tier.Cash, `Rebirth{level}`, nil)
	pcall(TelemetryService.LogEvent, player, "Rebirth", { `Level - {level}` }, data.Lifetime.PlaySeconds)
	notify(player, string.format(MESSAGES.Done, level, Format.short(Rebirths.IncomeMultiplier(level))), NOTIFY_INFO)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notify(other, string.format(MESSAGES.Announce, player.DisplayName, level), NOTIFY_INFO)
		end
	end
	log(`{player.Name} : renaissance {level} ({Format.money(paid)} remis à 0, {tier.ItemId} remis, {#keptUids} objet(s) gardé(s))`)
	return true, nil
end

------------------------------------------------------------------------------
-- Accroches (installées seulement si la renaissance peut s'allumer)
------------------------------------------------------------------------------

local function activeCount(player: Player): number
	return if isEnabled() then count(player) else 0
end

local function installHooks()
	local baseIncome = DisplayService.GetIncomeMultiplier
	DisplayService.GetIncomeMultiplier = function(player: Player): number
		return baseIncome(player) * Rebirths.IncomeMultiplier(activeCount(player))
	end
	local baseGain = TrainingService.GetGainMultiplier
	TrainingService.GetGainMultiplier = function(player: Player, kind: any): number
		local multiplier = if kind == "Treadmill" then Rebirths.TreadmillMultiplier(activeCount(player)) else 1
		return baseGain(player, kind) * multiplier
	end
	local baseVault = PvPService.GetVaultSlots
	PvPService.GetVaultSlots = function(owner: Player): number
		return baseVault(owner) + Rebirths.ExtraSafes(activeCount(owner))
	end
end

------------------------------------------------------------------------------
-- Studio : interrupteur de test
------------------------------------------------------------------------------

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
	testOn = Workspace:GetAttribute(TEST_ATTRIBUTE) == true
	log(`test : renaissance {if isEnabled() then "allumée" else "coupée"}`)
	publishAll()
end

local function onTestLevel()
	local value = Workspace:GetAttribute(TEST_LEVEL_ATTRIBUTE)
	if value == nil then
		return
	end
	Workspace:SetAttribute(TEST_LEVEL_ATTRIBUTE, nil)
	local words: { string } = {}
	for word in string.gmatch(tostring(value), "%S+") do
		table.insert(words, word)
	end
	local player = if words[1] then findPlayer(words[1]) else nil
	local data = if player then DataService.Get(player) else nil
	local level = tonumber(words[2])
	if player == nil or data == nil or level == nil or level < 0 or level % 1 ~= 0 then
		warn(`[RebirthService] test « {tostring(value)} » : joueur introuvable, profil pas chargé ou nombre invalide`)
		return
	end
	testOn = true
	;(data :: any).Rebirths = level
	publishAll()
	pcall(StatsService.Refresh, player)
	log(`test : {player.Name} à {level} renaissance(s) faite(s)`)
end

------------------------------------------------------------------------------
-- API et démarrage
------------------------------------------------------------------------------

function RebirthService.IsEnabled(): boolean
	return isEnabled()
end

function RebirthService.GetCount(player: Player): number
	return count(player)
end

function RebirthService.Request(player: Player, level: number): (boolean, string?)
	return request(player, level)
end

function RebirthService.Init()
	if not (Features.Rebirth or IS_STUDIO) then
		-- Coupé hors Studio : aucune accroche, aucun attribut ; le remote est ignoré.
		Net.Server.Rebirth:Connect(function() end)
		return
	end
	installHooks()
	Net.Server.Rebirth:Connect(function(player: Player, level: number)
		request(player, level)
	end)
	DataService.OnProfileLoaded(publish)
	if IS_STUDIO then
		testOn = Workspace:GetAttribute(TEST_ATTRIBUTE) == true
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTestAttribute)
		Workspace:GetAttributeChangedSignal(TEST_LEVEL_ATTRIBUTE):Connect(onTestLevel)
	end
	log(`{if isEnabled() then "allumée" else "coupée (Studio : RebirthTest pour l'allumer)"}, {#Rebirths.Tiers} paliers`)
end

function RebirthService.Start()
	if not (Features.Rebirth or IS_STUDIO) then
		return
	end
	while true do
		task.wait(OWNED_REFRESH)
		if isEnabled() then
			publishAll()
		end
	end
end

return RebirthService
