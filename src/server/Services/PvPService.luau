--!strict
-- PvPService (DEV-041, DEV-044, fin de DEV-040) : vol entre joueurs et règles anti-frustration
-- (Partie 1, sections 6, 6.1, 6.2, 6.4, 9.3, 9.4, 9.6 et 14.3 ; boutique du hub, liaison L-050).
--
-- Une boutique = un Model taggé PlayerPlot (PlotService), avec sa porte à casser `PlotDoor/Window`
-- (la vitrine « Plot_<PlotIndex> » de WindowService : PV = 50 × les dégâts du propriétaire,
-- régénération 3 %/s), son volume `Bounds`, sa `DepositZone` et ses `DisplaySlot_01` à `_20`.
--
-- Le vol, dans l'ordre (6.1) :
--   1. Repérage : panneau côté client (PvPController), rien ici. Ce service publie sur la parcelle
--      ce que le panneau ne peut pas deviner (attributs plus bas).
--   2. Frappe : WindowService.CanBeHit est remplacé ici (l'ancienne fonction sert toujours pour les
--      autres vitrines). Un coup sur la porte d'un joueur est refusé si le joueur est protégé :
--      bouclier débutant (NightCycleService.IsShielded), immunité de PvP.TheftImmunityDuration
--      (120 s) après un vol subi, anti-racket (valeur exposée de la victime < 10 % de celle du
--      frappeur). Le frappeur reçoit un Notify (au plus un par NOTICE_INTERVAL s et par raison).
--      Quand la porte casse, la victime est prévenue (« l'alarme de base », Notify Warning).
--   3. Casse (WindowService.OnBroken, Kind « Plot ») : la boutique s'ouvre PvP.StealDuration (10 s).
--      Le chrono HeistTimer(windowId, fin) part aux non-propriétaires proches (TIMER_RADIUS), comme
--      pour un magasin PNJ (HUD « HEIST: 10s »). Prise par StealItem(plotIndex, slotIndex), en deux
--      appels comme GrabItem : le premier ouvre un maintien (heure serveur), le second n'est accepté
--      qu'après PvP.StealGrabTime − GRAB_TIME_TOLERANCE s ; le maintien est revérifié 10 fois par
--      seconde et expire GrabTime + HOLD_EXPIRY s après son début. Le serveur vérifie : boutique
--      ouverte, pas la sienne, les deux profils chargés, mains vides (un objet à la fois), aucune
--      protection (voir 2), le voleur a une boutique et de la place (DisplayService.HasRoom), il est
--      vivant, dans Bounds de la boutique et à PvP.StealMaxDistance (8 studs) au plus du présentoir,
--      l'objet est exposé sur ce présentoir (ni colis des établis, ni coffre-fort, ni objet déjà
--      tenu) et n'est pas l'objet à l'abri (coffre-fort V0, plus bas).
--   4. Fuite : DisplayService.Hold vide le présentoir (le profil de la victime ne change pas), puis
--      CarryService.StartCarry(voleur, PlayerItemPayload) : l'objet flotte au-dessus de sa tête avec
--      son halo, BB_Carry et un contour rouge, malus de −25 % (CarryService). TheftAlert(true,
--      voleur, itemId) et un Notify à la victime (UI_TheftAlert et Adrénaline : DEV-042).
--   5. Réussite : le voleur entre dans la DepositZone de SA boutique (contrôlé 10 fois par seconde :
--      emprise au sol de la DepositZone, et dans le volume Bounds de sa boutique).
--      Transfert (voir « Transfert sûr ») : l'objet est à lui tout de suite, Source = "PvP", avec sa
--      zone et sa mutation (DEV-131 : même revenu, même nom, même taille chez le voleur), sur un
--      présentoir libre (DisplayService.PlaceAuto, le plus proche de lui) sinon dans son inventaire,
--      et il rapporte aussitôt. Puis Lifetime.Steals + 1 pour le voleur, immunité de 120 s pour la
--      victime, TheftAlert(false), un Notify à chacun, et une sauvegarde des deux profils.
--   6. Échec : coup de batte (CarryService.Fail(voleur, "Bat"), DEV-043), mort, départ ou personnage
--      retiré du voleur, départ de la victime (Fail « VictimLeft »), anomalie (ReportAnomaly), plus de
--      place au dépôt (« NoRoom »), ou toute autre fin de portage : l'objet revient sur son présentoir
--      d'origine (DisplayService.Release). Rien à défaire : le profil n'a jamais changé.
--
-- Transfert sûr (6.4, 9.6, 14.3) : l'objet ne change de propriétaire qu'au dépôt, et dans une seule
-- exécution serveur, sans yield : vérification (les deux joueurs présents et pas en train de partir,
-- leurs deux profils actifs dans DataService, l'objet toujours dans Items de la victime avec le même
-- ItemId, absent de chez le voleur, toujours tenu, le portage est bien celui de ce vol), puis
-- DisplayService.TakeHeld (présentoir de la victime), retrait de Items de la victime, ajout à Items
-- du voleur (même uid), PlaceAuto, CarryService.Consume. Roblox n'exécute qu'un fil à la fois : un
-- départ (PlayerRemoving, libération du profil) passe soit avant le dépôt (vérification ratée : le
-- vol échoue, l'objet n'a jamais quitté le profil de la victime), soit après (les deux profils sont
-- déjà à jour et chacun se sauvegarde avec son état). Jamais deux exemplaires, jamais aucun.
-- Sauvegarde : DataService.Save de la victime, puis du voleur, tout de suite (au lieu de la sauvegarde
-- automatique, jusqu'à 5 min plus tard). Seul un arrêt brutal du serveur pendant ces deux écritures
-- pourrait encore laisser un doublon ou une perte (deux clés DataStore, aucune transaction possible) ;
-- l'uid reste le même chez le voleur : un doublon se repère.
-- Contrôle du dépôt (9.6, V0 proposé, absent du doc) : la distance de la prise au dépôt ne peut pas
-- dépasser ce qu'un porteur au plafond de vitesse parcourt dans ce temps (Balance.Stats.MaxWalkSpeed ×
-- Balance.Carry.StolenItemSpeedMultiplier × Balance.AntiCheat.SpeedTolerance, × la potion Speed s'il l'a,
-- plus ESCAPE_MARGIN s) :
-- sinon CarryService.ReportAnomaly, l'objet revient. Un joueur lent ou qui rame n'est jamais pris.
-- Avant lui, AntiCheatService.Verify(voleur, From, StartedAt) (DEV-060) contrôle tout de suite son
-- dernier déplacement (téléport) et le trajet depuis la prise à sa vitesse réelle (speed hack) :
-- sanctionné, le portage échoue et l'objet revient. Le contrôle du dépôt reste un filet : il marche
-- aussi en Studio sans AntiCheatStrict et quand Features.AntiCheat = false.
--
-- Protections (6.4) : bouclier débutant ; 3 s d'immunité aux coups de batte (DEV-043) ; 120 s
-- d'immunité après un vol subi (coups et prises refusés) ; anti-racket (coups et prises refusés) ;
-- coffre-fort ; l'argent n'est jamais volé (ni Cash ni la caisse ne sont lus ou écrits ici) ;
-- transfert sûr.
-- Coffre-fort V0 (6.4 « au moins 1 objet est toujours à l'abri » ; Partie 2, section 2 : « présentoirs
-- non volables, 1 offert dès le MVP ») : les PvP.VaultSlots (1) objets exposés qui rapportent le
-- plus ne sont jamais volables (à revenu égal, le présentoir de plus petit numéro). Ils restent sur
-- leur présentoir et rapportent ; aucune action du joueur, aucun remote, profil inchangé (le champ
-- Vault et VaultSlot_01 restent pour le coffre physique de la MAJ 2, DEV-110). Un joueur qui n'expose
-- qu'un objet ne peut donc pas être volé.
--
-- Boutique du hub (L-050), sortie par le serveur devant la porte (PlotService.PutOutside), avec ce
-- qu'il porte :
--   - 10 fois par seconde : un non-propriétaire dans Bounds d'une boutique dont la porte n'est pas
--     cassée et dont la fenêtre de vol est fermée (rien n'y entre sans casser la porte ; boutique
--     libre comprise, où il serait enfermé). Un joueur qui part (profil libéré) n'est pas déplacé ;
--   - à la reconstruction de la porte (WindowService.OnRebuilt) : tout non-propriétaire encore
--     dedans, même un voleur chargé (sinon il resterait enfermé) ; la fenêtre de vol se ferme.
-- Le passage du propriétaire reste côté client (PlotDoorController).
--
-- Posé par ce service sur la parcelle, lu par PvPController (aucun nom du contrat) :
--   StealOpen (booléen, nil fermé), StealEndsAt (heure serveur de la fin des 10 s) ;
--   Protection ("Shield", "Immune" ou nil) et ProtectedUntil (heure serveur, immunité seulement) ;
--   SafeSlots (texte « 3 » ou « 3,7 » : présentoirs à l'abri, nil sans objet exposé).
--
-- Remote StealItem(plotIndex, slotIndex) (Net/Definitions, ajout de la vague 10 au tableau 9.4).
--
-- API (serveur) :
--   PvPService.GetTheft(thief) -> TheftInfo?
--       { Victim, ItemUid, ItemId, SlotIndex } du vol en cours (objet porté), nil sinon.
--   PvPService.IsThiefOf(player, owner) -> boolean
--       true si `player` porte un objet volé à `owner` (SwingBat, usage 1 de 6.2, DEV-043).
--   PvPService.GetProtection(player) -> (string?, number?)
--       "Shield" ou "Immune" (et secondes restantes d'immunité) si sa boutique est protégée.
--   PvPService.GetVaultSlots(owner) -> number
--       Point d'accroche : nombre d'objets exposés à l'abri chez `owner` (coffre-fort V0) ; PvP.VaultSlots
--       (1) par défaut, remplacé par SkillTreeService (compétence Safe, vague 27 : 1 + Effects[niveau]).
--       Jamais moins que PvP.VaultSlots ; une erreur ou une valeur invalide reprend PvP.VaultSlots.
--   PvPService.OnTheftStarted(listener) -> déconnexion     listener(thief, victim, itemId)
--   PvPService.OnTheftEnded(listener) -> déconnexion
--       listener(thief, victim, itemId, result, reason) ; result = "Stolen" (dépôt) ou "Returned"
--       (échec : l'objet est revenu sur son présentoir), reason = raison du portage. Pour DEV-042
--       (UI_TheftAlert, Adrénaline, batte équipée) et la télémétrie.
--   Branchés par TheftAlertService (DEV-042) : Adrénaline de la victime, réannonce de l'alerte quand
--   plusieurs vols ont lieu chez elle, Lifetime.Defenses ; côté client, TheftAlertController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local PvP = require(Shared.Config.PvP)
local Find = require(Shared.Contract.Find)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local CarryTypes = require(Shared.Types.Carry)

local AntiCheatService = require(script.Parent.AntiCheatService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local NightCycleService = require(script.Parent.NightCycleService)
local PlotService = require(script.Parent.PlotService)
local WindowService = require(script.Parent.WindowService)

type PlayerItemPayload = CarryTypes.PlayerItemPayload

-- Une protection (6.4) s'écrit en texte : "Shield", "Immune" ou "Racket" (voir protectionOf).
export type TheftResult = "Stolen" | "Returned"

export type TheftInfo = {
	Victim: Player,
	ItemUid: string,
	ItemId: string,
	SlotIndex: number,
}

type StartedListener = (thief: Player, victim: Player, itemId: string) -> ()
type EndedListener = (thief: Player, victim: Player, itemId: string, result: TheftResult, reason: string) -> ()

-- Boutique à la porte cassée, pendant ses 10 s de vol.
type Shop = {
	Plot: Model,
	Victim: Player,
	WindowId: string,
	EndsAt: number, -- heure serveur (Workspace:GetServerTimeNow)
	Viewers: { [Player]: boolean }, -- joueurs qui voient le chrono
}

type Hold = {
	Plot: Model,
	Victim: Player,
	Slot: number,
	Uid: string,
	StartedAt: number, -- os.clock()
}

type Theft = {
	Thief: Player,
	Victim: Player,
	Plot: Model, -- boutique de la victime
	Uid: string,
	ItemId: string,
	Slot: number,
	Payload: PlayerItemPayload, -- la table donnée à StartCarry (CarryService la garde telle quelle)
	StartedAt: number, -- os.clock() de la prise
	From: Vector3, -- position du voleur à la prise (contrôle du dépôt)
	SpeedBoost: number, -- vitesse au-dessus du plafond à la prise (potion Speed), 1 sinon
}

-- Pièces du contrat 10.4 d'une parcelle, trouvées avant que DisplayService y pose des objets.
type PlotRefs = {
	Bounds: BasePart?,
	Deposit: BasePart?,
	Slots: { [number]: Attachment? },
}

-- Noms du contrat (10.4).
local BOUNDS = "Bounds"
local DEPOSIT_ZONE = "DepositZone"
local SLOT_FORMAT = "DisplaySlot_%02d"
-- Attributs posés par ce service sur la parcelle (mêmes noms dans PvPController).
local OPEN_ATTRIBUTE = "StealOpen"
local ENDS_AT_ATTRIBUTE = "StealEndsAt"
local PROTECTION_ATTRIBUTE = "Protection"
local PROTECTED_UNTIL_ATTRIBUTE = "ProtectedUntil"
local SAFE_SLOTS_ATTRIBUTE = "SafeSlots"

-- V0 proposé, absent du doc : services, joueurs et maintiens vérifiés 10 fois par seconde (comme
-- StoreHeistService) ; attributs de la parcelle publiés toutes les PUBLISH_EVERY images.
local TICK = 0.1
local PUBLISH_EVERY = 5
-- V0 proposé, absent du doc : après WindowService et StoreHeistService (110), avant les écrans.
local PRIORITY = 120
-- V0 proposé, absent du doc : écart du réseau toléré sur la durée de maintien, et expiration d'un
-- maintien non conclu (comme GrabItem).
local GRAB_TIME_TOLERANCE = 0.1
local HOLD_EXPIRY = 1
-- V0 proposé, absent du doc : le chrono est montré aux non-propriétaires à 60 studs ou moins du
-- centre de la boutique (comme pour un magasin PNJ).
local TIMER_RADIUS = 60
-- V0 proposé, absent du doc : au plus un message de refus par raison toutes les 3 s.
local NOTICE_INTERVAL = 3
-- V0 proposé, absent du doc : marge du contrôle du dépôt (voir l'en-tête), en secondes.
local ESCAPE_MARGIN = 0.5
local MAX_ESCAPE_SPEED = Balance.Stats.MaxWalkSpeed * Balance.Carry.StolenItemSpeedMultiplier * Balance.AntiCheat.SpeedTolerance

-- Potion Speed (Cantin, 2026-11-12) : la vitesse peut dépasser le plafond de 70. Le contrôle du dépôt
-- multiplie MAX_ESCAPE_SPEED par le plus fort multiplicateur au-dessus du plafond, à la prise ou au dépôt
-- (StatsService.GetSpeedBoost). require protégé : sans StatsService (bancs), 1.
local getSpeedBoost: ((Player) -> number)? = nil
do
	local ok, loaded = pcall(function(): any
		return require(script.Parent.StatsService) :: any
	end)
	local api: any = if ok then loaded else nil
	local fn: any = if type(api) == "table" then api.GetSpeedBoost else nil
	if type(fn) == "function" then
		getSpeedBoost = fn
	end
end

local function speedBoost(player: Player): number
	local fn = getSpeedBoost
	if fn then
		local ok, value = pcall(fn, player)
		if ok and type(value) == "number" and value >= 1 then
			return value
		end
	end
	return 1
end

-- Messages lus par les joueurs (Notify), en anglais (L-036) ; nombres par Shared/Format.
local MESSAGES: { [string]: string } = {
	DoorSmashed = "%s smashed your shop door! Defend your shop!",
	Stealing = "%s is stealing your %s! Hit them with your bat!",
	Grabbed = "You grabbed the %s: run back to your shop!",
	Stolen = "You stole the %s: %s!",
	StolenToInventory = "You stole the %s: it went to your inventory (your stands are full).",
	Robbed = "%s stole your %s. Your shop is protected for %ds.",
	Returned = "Your %s is back on its stand!",
	Lost = "The %s went back to its owner.",
	Shield = "This shop is protected: its owner just started playing.",
	Immune = "This shop was just robbed: protected for %ds.",
	Racket = "This shop is too small for you to rob.",
	Safe = "This item is in the safe: nobody can steal it.",
	Full = "Your shop is full: make room before stealing.",
	NoShop = "You need a shop to steal.",
	DoorBack = "The door is fixed: you were moved outside.",
	NotYourShop = "Only the owner can be inside this shop.",
}

local IS_STUDIO = RunService:IsStudio()

local PvPService = {}
PvPService.Priority = PRIORITY

local shops: { [Model]: Shop } = {}
local holds: { [Player]: Hold } = {}
local thefts: { [Player]: Theft } = {}
local immuneUntil: { [Player]: number } = {} -- os.clock() de la fin de l'immunité après un vol subi
-- Joueurs dont PlayerRemoving est passé. Clés faibles : l'entrée part avec le Player.
local leaving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastNotice: { [Player]: { [string]: number } } = {}
local lastRefusal: { [Player]: number } = {}
local refsOf: { [Model]: PlotRefs } = {}
local startedListeners: { StartedListener } = {}
local endedListeners: { EndedListener } = {}
local previousCanBeHit: ((player: Player, windowId: string) -> boolean)? = nil
local publishCount = 0

-- Outils ------------------------------------------------------------------------------------------

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function log(message: string)
	if IS_STUDIO then
		print(`[PvPService] {message}`)
	end
end

-- Refus anormal : signalé en Studio seulement (aide au test), une ligne par seconde et par joueur.
local function refuse(player: Player, what: string, reason: string)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[PvPService] {what} de {player.Name} refusé : {reason}`)
end

local function notify(player: Player, message: string, kind: string)
	if player.Parent ~= Players then
		return
	end
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[PvPService] Notify vers {player.Name} : {err}`)
	end
end

-- Message de refus, au plus un par raison toutes les NOTICE_INTERVAL s (coups à 10 par seconde).
local function notice(player: Player, key: string, message: string)
	local byKey = lastNotice[player] or {}
	lastNotice[player] = byKey
	local now = os.clock()
	if now - (byKey[key] or -math.huge) < NOTICE_INTERVAL then
		return
	end
	byKey[key] = now
	notify(player, message, "Warning")
end

local function itemName(itemId: string): string
	local item = Items.ById[itemId]
	return if item then item.DisplayName else itemId
end

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Dans l'emprise au sol de la pièce (sa hauteur n'est pas lue) : la DepositZone « couvre tout le sol
-- intérieur » (relevé Studio), sa hauteur exacte ne compte pas ; le volume Bounds dit qu'on est dedans.
local function overFootprint(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Z) <= h.Z
end

-- HumanoidRootPart d'un joueur vivant, ou nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

local function isCarrying(player: Player): boolean
	local ok, carrying = pcall(CarryService.IsCarrying, player)
	return ok and carrying == true
end

-- Le joueur est-il là, et pas en train de partir ?
local function present(player: Player): boolean
	return player.Parent == Players and not leaving[player]
end

local function refsFor(plot: Model): PlotRefs
	local cached = refsOf[plot]
	if cached then
		return cached
	end
	local bounds = Find.path(plot, BOUNDS)
	local deposit = Find.path(plot, DEPOSIT_ZONE)
	local slots: { [number]: Attachment? } = {}
	for index = 1, Balance.Display.MaxSlots do
		local found = Find.path(plot, string.format(SLOT_FORMAT, index))
		if found and found:IsA("Attachment") then
			slots[index] = found :: Attachment
		end
	end
	-- Présentoirs bonus du gamepass « +4 présentoirs » (DEV-100) : DisplaySlot_21 et suivants, à la
	-- suite, optionnels (même règle et même borne V0 de 10 que DisplayService) : leurs objets se volent
	-- comme les autres.
	for index = Balance.Display.MaxSlots + 1, Balance.Display.MaxSlots + 10 do
		local found = Find.path(plot, string.format(SLOT_FORMAT, index))
		if found == nil or not found:IsA("Attachment") then
			break
		end
		slots[index] = found :: Attachment
	end
	local refs: PlotRefs = {
		Bounds = if bounds and bounds:IsA("BasePart") then bounds :: BasePart else nil,
		Deposit = if deposit and deposit:IsA("BasePart") then deposit :: BasePart else nil,
		Slots = slots,
	}
	refsOf[plot] = refs
	return refs
end

local function plotOfWindow(windowId: string): Model?
	for _, plot in PlotService.GetPlots() do
		if WindowService.GetWindowId(plot) == windowId then
			return plot
		end
	end
	return nil
end

-- Protections (6.4) ------------------------------------------------------------------------------

-- Pourquoi la boutique de `victim` ne peut pas être frappée ni volée par `attacker` en ce moment :
-- "Shield" (bouclier débutant), "Immune" (vol subi il y a moins de 120 s, avec les secondes
-- restantes) ou "Racket" (valeur exposée < 10 % de celle d'`attacker` ; pas vérifié sans `attacker`).
local function protectionOf(attacker: Player?, victim: Player): (string?, number?)
	local ok, shielded = pcall(NightCycleService.IsShielded, victim)
	if not ok or shielded == true then
		return "Shield", nil -- une erreur compte comme protégé (bénéfice du doute, comme les vigiles)
	end
	local untilClock = immuneUntil[victim]
	local now = os.clock()
	if untilClock and untilClock > now then
		return "Immune", untilClock - now
	end
	if attacker then
		local theirs = DisplayService.GetIncome(victim)
		local mine = DisplayService.GetIncome(attacker)
		if theirs < PvP.AntiRacketRatio * mine then
			return "Racket", nil
		end
	end
	return nil, nil
end

local function protectionMessage(refusal: string, left: number?): string
	if refusal == "Immune" then
		return string.format(MESSAGES.Immune, math.ceil(left or PvP.TheftImmunityDuration))
	elseif refusal == "Shield" then
		return MESSAGES.Shield
	end
	return MESSAGES.Racket
end

-- Nombre de présentoirs à l'abri chez `owner` : PvPService.GetVaultSlots (arbre de compétences, Safe),
-- un entier ≥ PvP.VaultSlots ; une erreur ou une valeur invalide reprend PvP.VaultSlots.
local vaultWarned = false
local function vaultSlotsOf(owner: Player): number
	local ok, value = pcall(PvPService.GetVaultSlots, owner)
	if not ok then
		if not vaultWarned then
			vaultWarned = true
			warn(`[PvPService] GetVaultSlots : erreur ({value}), {PvP.VaultSlots} présentoir(s) à l'abri`)
		end
		return PvP.VaultSlots
	end
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return PvP.VaultSlots
	end
	return math.max(PvP.VaultSlots, math.floor(value))
end

-- Coffre-fort V0 : présentoirs à l'abri parmi les objets exposés de `owner` (voir l'en-tête).
local function safeSlotsOf(owner: Player, exposed: { [number]: DisplayService.ExposedItem }): { [number]: boolean }
	local list: { number } = {}
	for slot in exposed do
		table.insert(list, slot)
	end
	table.sort(list, function(a: number, b: number): boolean
		local ia, ib = exposed[a].Income, exposed[b].Income
		if ia ~= ib then
			return ia > ib
		end
		return a < b
	end)
	local safe: { [number]: boolean } = {}
	for index = 1, math.min(vaultSlotsOf(owner), #list) do
		safe[list[index]] = true
	end
	return safe
end

-- Remplace WindowService.CanBeHit (voir l'en-tête).
local function canBeHit(player: Player, windowId: string): boolean
	local plot = plotOfWindow(windowId)
	if plot then
		local victim = PlotService.GetOwner(plot)
		if victim == nil or victim == player or not present(player) or not present(victim) then
			return false
		end
		if DataService.Get(player) == nil or DataService.Get(victim) == nil then
			return false
		end
		local refusal, left = protectionOf(player, victim)
		if refusal then
			notice(player, refusal, protectionMessage(refusal, left))
			return false
		end
	end
	local previous = previousCanBeHit
	return previous == nil or previous(player, windowId)
end

-- Chrono des 10 s ----------------------------------------------------------------------------------

local function hideTimer(shop: Shop, player: Player)
	if shop.Viewers[player] then
		shop.Viewers[player] = nil
		if player.Parent == Players then
			Net.Server.HeistTimer:Fire(player, shop.WindowId, 0)
		end
	end
end

local function updateViewers(shop: Shop)
	local bounds = refsFor(shop.Plot).Bounds
	local center = if bounds then bounds.Position else shop.Plot:GetPivot().Position
	for _, player in Players:GetPlayers() do
		if player == shop.Victim then
			continue
		end
		if thefts[player] or isCarrying(player) then
			hideTimer(shop, player)
		elseif not shop.Viewers[player] then
			local root = rootOf(player)
			if root and (root.Position - center).Magnitude <= TIMER_RADIUS then
				shop.Viewers[player] = true
				Net.Server.HeistTimer:Fire(player, shop.WindowId, shop.EndsAt)
			end
		end
	end
end

-- Ouverture et fermeture --------------------------------------------------------------------------

local function closeShop(shop: Shop, why: string)
	local plot = shop.Plot
	if shops[plot] ~= shop then
		return
	end
	shops[plot] = nil
	plot:SetAttribute(OPEN_ATTRIBUTE, nil)
	plot:SetAttribute(ENDS_AT_ATTRIBUTE, nil)
	for player in table.clone(shop.Viewers) do
		hideTimer(shop, player)
	end
	for player, hold in holds do
		if hold.Plot == plot then
			holds[player] = nil
		end
	end
	log(`{plot.Name} : fenêtre de vol fermée ({why})`)
end

local function openShop(plot: Model, victim: Player, windowId: string, breaker: Player?)
	local existing = shops[plot]
	if existing then
		closeShop(existing, "nouvelle casse")
	end
	local duration = PvP.StealDuration
	local shop: Shop = {
		Plot = plot,
		Victim = victim,
		WindowId = windowId,
		EndsAt = Workspace:GetServerTimeNow() + duration,
		Viewers = {},
	}
	shops[plot] = shop
	plot:SetAttribute(OPEN_ATTRIBUTE, true)
	plot:SetAttribute(ENDS_AT_ATTRIBUTE, shop.EndsAt)
	updateViewers(shop)
	task.delay(duration, function()
		if shops[plot] == shop then
			closeShop(shop, "10 s écoulées")
		end
	end)
	log(`{plot.Name} de {victim.Name} : porte cassée par {if breaker then breaker.Name else "?"}, {duration} s pour voler`)
end

-- Sortie devant la porte ----------------------------------------------------------------------------

-- Sort de la boutique `plot` les non-propriétaires qui sont dans son volume Bounds. Renvoie les
-- joueurs sortis.
local function ejectFrom(plot: Model, owner: Player?): { Player }
	local moved: { Player } = {}
	local bounds = refsFor(plot).Bounds
	if bounds == nil then
		return moved
	end
	for _, player in Players:GetPlayers() do
		-- Un joueur qui part (profil déjà libéré) reste où il est : c'est souvent l'ancien propriétaire.
		if player ~= owner and present(player) and DataService.Get(player) ~= nil then
			local root = rootOf(player)
			if root and inside(bounds, root.Position) and PlotService.PutOutside(player, plot) then
				table.insert(moved, player)
				local theft = thefts[player]
				local outside = rootOf(player)
				if theft and outside then
					-- Déplacement fait par le serveur : le contrôle du dépôt repart d'ici.
					theft.From = outside.Position
					theft.StartedAt = os.clock()
				end
			end
		end
	end
	return moved
end

local function ejectStep()
	for _, plot in PlotService.GetPlots() do
		-- Parcelle libre comprise : ses murs et sa porte sont solides pour tous, on y serait enfermé.
		local owner = PlotService.GetOwner(plot)
		if shops[plot] ~= nil then
			continue
		end
		local windowId = WindowService.GetWindowId(plot)
		if windowId == nil or WindowService.IsBroken(windowId) then
			continue -- porte cassée : on entre librement jusqu'à sa reconstruction
		end
		for _, player in ejectFrom(plot, owner) do
			notice(player, "NotYourShop", MESSAGES.NotYourShop)
			log(`{player.Name} sorti de {plot.Name} : porte intacte, ce n'est pas sa boutique`)
		end
	end
end

-- Fin d'un vol ------------------------------------------------------------------------------------------

local function emitEnded(theft: Theft, result: TheftResult, reason: string)
	for _, listener in table.clone(endedListeners) do
		task.spawn(listener, theft.Thief, theft.Victim, theft.ItemId, result, reason)
	end
end

-- Échec : l'objet revient sur son présentoir (le profil de la victime n'a jamais changé).
local function returnItem(theft: Theft, reason: string)
	if thefts[theft.Thief] ~= theft then
		return
	end
	thefts[theft.Thief] = nil
	DisplayService.Release(theft.Victim, theft.Uid)
	local name = itemName(theft.ItemId)
	if present(theft.Victim) then
		Net.Server.TheftAlert:Fire(theft.Victim, false)
		notify(theft.Victim, string.format(MESSAGES.Returned, name), "Info")
	end
	if reason ~= "Left" and reason ~= "NoRoom" then
		notify(theft.Thief, string.format(MESSAGES.Lost, name), "Warning")
	end
	log(`vol de {theft.Thief.Name} chez {theft.Victim.Name} raté ({reason}) : {theft.ItemId} revient sur le présentoir {theft.Slot}`)
	emitEnded(theft, "Returned", reason)
end

-- Fait échouer le vol : le portage finit (CarryService prévient onCarryEnded, qui rend l'objet). Si
-- le portage avait déjà disparu, l'objet est rendu ici.
local function abandon(theft: Theft, reason: string)
	pcall(CarryService.Fail, theft.Thief, reason)
	if thefts[theft.Thief] == theft then
		returnItem(theft, reason)
	end
end

local function onCarryEnded(player: Player, payload: any, _result: string, reason: string)
	if type(payload) ~= "table" or payload.Kind ~= "PlayerItem" then
		return
	end
	local theft = thefts[player]
	if theft == nil or theft.Payload ~= payload then
		return -- déjà réglé (dépôt) : rien à rendre
	end
	-- Toute autre fin (batte, mort, départ, anomalie… et un Consume qui ne vient pas d'ici) : l'objet revient.
	returnItem(theft, reason)
end

-- Dépôt : transfert sûr (voir l'en-tête). Sans yield.
local function deposit(theft: Theft, root: BasePart)
	local thief, victim = theft.Thief, theft.Victim
	if not present(thief) or not present(victim) then
		return -- le départ va annuler le vol
	end
	local thiefData = DataService.Get(thief)
	local victimData = DataService.Get(victim)
	if thiefData == nil or victimData == nil then
		return -- profil en cours de libération : le départ va annuler le vol
	end
	-- Contrôle des déplacements tout de suite (DEV-060), sans attendre le suivant, et du trajet depuis la
	-- prise (à la vitesse réelle du voleur) : un téléport dans sa propre DepositZone ou un speed hack
	-- entre deux boutiques proches sont vus avant le transfert. Sanctionné : le portage vient d'échouer.
	if not AntiCheatService.Verify(thief, theft.From, theft.StartedAt) then
		if thefts[thief] == theft then
			returnItem(theft, "Anomaly")
		end
		return
	end
	local elapsed = os.clock() - theft.StartedAt
	local distance = (root.Position - theft.From).Magnitude
	if distance > MAX_ESCAPE_SPEED * math.max(theft.SpeedBoost, speedBoost(thief)) * (elapsed + ESCAPE_MARGIN) then
		CarryService.ReportAnomaly(thief, `objet volé déposé à {math.round(distance)} studs en {math.round(elapsed * 10) / 10} s`)
		if thefts[thief] == theft then
			returnItem(theft, "Anomaly")
		end
		return
	end
	if CarryService.GetPayload(thief) ~= theft.Payload then
		warn(`[PvPService] {thief.Name} : le portage n'est plus celui du vol, objet rendu`)
		abandon(theft, "Anomaly")
		return
	end
	local entry = victimData.Items[theft.Uid]
	if entry == nil or entry.Id ~= theft.ItemId or thiefData.Items[theft.Uid] ~= nil or not DisplayService.IsHeld(victim, theft.Uid) then
		warn(`[PvPService] {thief.Name} : l'objet {theft.Uid} n'est plus le même chez {victim.Name}, vol annulé`)
		abandon(theft, "Anomaly")
		return
	end
	if not DisplayService.HasRoom(thief) then
		notify(thief, MESSAGES.Full, "Warning")
		abandon(theft, "NoRoom")
		return
	end

	-- Transfert, d'un seul tenant.
	thefts[thief] = nil
	DisplayService.TakeHeld(victim, theft.Uid)
	victimData.Items[theft.Uid] = nil
	-- La mutation suit l'objet (DEV-131), comme sa zone.
	thiefData.Items[theft.Uid] = { Id = entry.Id, Source = "PvP", At = os.time(), Zone = entry.Zone, Mutation = Mutations.Sanitize(entry.Mutation) }
	local slot = DisplayService.PlaceAuto(thief, theft.Uid, root.Position)
	CarryService.Consume(thief, "Deposited")

	local lifetime = (thiefData :: any).Lifetime
	if type(lifetime) == "table" and type(lifetime.Steals) == "number" then
		lifetime.Steals += 1
	else
		warn(`[PvPService] {thief.Name} : Lifetime absent du profil, vol non compté`)
	end
	immuneUntil[victim] = os.clock() + PvP.TheftImmunityDuration
	Net.Server.TheftAlert:Fire(victim, false)
	local name = itemName(theft.ItemId)
	if slot then
		notify(thief, string.format(MESSAGES.Stolen, name, Format.income(theft.Payload.Income)), "Info")
	else
		notify(thief, string.format(MESSAGES.StolenToInventory, name), "Info")
	end
	notify(victim, string.format(MESSAGES.Robbed, thief.DisplayName, name, PvP.TheftImmunityDuration), "Warning")
	-- Les deux sauvegardes tout de suite (la victime d'abord), plutôt qu'à la sauvegarde automatique :
	-- seul un arrêt brutal du serveur pendant ces deux écritures pourrait encore créer un écart.
	DataService.Save(victim)
	DataService.Save(thief)
	local where = if slot then `présentoir {slot}` else "inventaire"
	log(`{thief.Name} a volé {theft.ItemId} ({theft.Uid}) à {victim.Name} : {where}, immunité de {PvP.TheftImmunityDuration} s pour la victime`)
	emitEnded(theft, "Stolen", "Deposited")
end

-- Prise ------------------------------------------------------------------------------------------------------

-- Raison du refus d'une prise sur le présentoir `slot` de `plot` (texte pour la sortie de Studio) et,
-- pour un joueur honnête, la clé et le texte du message à lui envoyer ; nil si la prise est permise.
local function stealRefusal(player: Player, plot: Model, slot: number): (string?, string?, string?)
	local victim = PlotService.GetOwner(plot)
	if victim == nil then
		return "boutique libre", nil, nil
	end
	if victim == player then
		return "sa propre boutique", nil, nil
	end
	local shop = shops[plot]
	if shop == nil or shop.Victim ~= victim then
		return "boutique fermée (porte intacte ou 10 s écoulées)", nil, nil
	end
	if not present(player) or not present(victim) then
		return "départ en cours", nil, nil
	end
	local victimData = DataService.Get(victim)
	if DataService.Get(player) == nil or victimData == nil then
		return "profil pas chargé", nil, nil
	end
	if thefts[player] or isCarrying(player) then
		return "mains pleines", nil, nil
	end
	local refusal, left = protectionOf(player, victim)
	if refusal then
		return `boutique protégée ({refusal})`, refusal, protectionMessage(refusal, left)
	end
	if PlotService.GetPlot(player) == nil then
		return "pas de boutique", "NoShop", MESSAGES.NoShop
	end
	local root = rootOf(player)
	if root == nil then
		return "pas de personnage vivant", nil, nil
	end
	local refs = refsFor(plot)
	local bounds = refs.Bounds
	if bounds == nil then
		return "boutique sans volume Bounds", nil, nil
	end
	if not inside(bounds, root.Position) then
		return "hors du volume Bounds", nil, nil
	end
	local attachment = refs.Slots[slot]
	if attachment == nil then
		return `présentoir {slot} absent de la boutique`, nil, nil
	end
	local distance = (root.Position - attachment.WorldPosition).Magnitude
	if distance > PvP.StealMaxDistance then
		return `trop loin ({math.round(distance * 10) / 10} studs)`, nil, nil
	end
	local exposed = DisplayService.GetExposed(victim)
	local item = exposed[slot]
	if item == nil or victimData.Display[tostring(slot)] ~= item.Uid or victimData.Items[item.Uid] == nil then
		return "présentoir vide", nil, nil
	end
	if safeSlotsOf(victim, exposed)[slot] then
		return "objet à l'abri (coffre-fort)", "Safe", MESSAGES.Safe
	end
	if not DisplayService.HasRoom(player) then
		return "plus de place chez le voleur", "Full", MESSAGES.Full
	end
	return nil, nil, nil
end

local function grant(thief: Player, victim: Player, plot: Model, slot: number, uid: string)
	local item = DisplayService.GetExposed(victim)[slot]
	local def = if item then Items.ById[item.ItemId] else nil
	local root = rootOf(thief)
	if item == nil or item.Uid ~= uid or def == nil or root == nil then
		refuse(thief, "StealItem", "objet changé pendant le maintien")
		return
	end
	if DisplayService.Hold(victim, uid) == nil then
		refuse(thief, "StealItem", "DisplayService.Hold a refusé")
		return
	end
	-- Mutation de l'objet (DEV-131) : sur BB_Carry pendant la fuite (le revenu d'item.Income la compte déjà).
	local victimData = DataService.Get(victim)
	local victimEntry = if victimData then victimData.Items[uid] else nil
	local mutation = if victimEntry then Mutations.Sanitize(victimEntry.Mutation) else nil
	local payload: PlayerItemPayload = {
		Kind = "PlayerItem",
		ItemUid = uid,
		ItemId = def.Id,
		Rarity = def.Rarity,
		Income = item.Income,
		VictimUserId = victim.UserId,
		SlotIndex = slot,
		Mutation = mutation,
	}
	local theft: Theft = {
		Thief = thief,
		Victim = victim,
		Plot = plot,
		Uid = uid,
		ItemId = def.Id,
		Slot = slot,
		Payload = payload,
		StartedAt = os.clock(),
		From = root.Position,
		SpeedBoost = speedBoost(thief),
	}
	thefts[thief] = theft
	local ok, started = pcall(CarryService.StartCarry, thief, payload)
	if not ok or started ~= true then
		thefts[thief] = nil
		DisplayService.Release(victim, uid)
		if not ok then
			warn(`[PvPService] CarryService.StartCarry : {started}`)
		end
		refuse(thief, "StealItem", "CarryService a refusé le portage")
		return
	end
	local shop = shops[plot]
	if shop then
		hideTimer(shop, thief)
	end
	local name = itemName(def.Id)
	Net.Server.TheftAlert:Fire(victim, true, thief, def.Id)
	notify(victim, string.format(MESSAGES.Stealing, thief.DisplayName, name), "Warning")
	notify(thief, string.format(MESSAGES.Grabbed, name), "Info")
	log(`{thief.Name} prend {def.Id} ({uid}) sur le présentoir {slot} de {victim.Name}`)
	for _, listener in table.clone(startedListeners) do
		task.spawn(listener, thief, victim, def.Id)
	end
end

-- StealItem(plotIndex, slotIndex) : premier appel = début du maintien, second = fin (voir l'en-tête).
local function onStealItem(player: Player, plotIndex: number, slotIndex: number)
	local what = `StealItem({plotIndex}, {slotIndex})`
	local plot = PlotService.GetPlotByIndex(plotIndex)
	if plot == nil then
		refuse(player, what, "boutique inconnue")
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, what, "déplacement sanctionné par l'anti-triche (audit 9.8)")
		return
	end
	local hold = holds[player]
	local reason, key, message = stealRefusal(player, plot, slotIndex)
	if reason then
		if hold and hold.Plot == plot and hold.Slot == slotIndex then
			holds[player] = nil
		end
		refuse(player, what, reason)
		if key and message then
			notice(player, key, message)
		end
		return
	end
	local victim = PlotService.GetOwner(plot) :: Player
	local uid = DisplayService.GetExposed(victim)[slotIndex].Uid
	local now = os.clock()
	if hold and hold.Plot == plot and hold.Slot == slotIndex and hold.Uid == uid then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= PvP.StealGrabTime then
			holds[player] = nil
			grant(player, victim, plot, slotIndex, uid)
		else
			refuse(player, what, `maintien trop court ({math.round(elapsed * 100) / 100} s sur {PvP.StealGrabTime} s)`)
		end
		return
	end
	holds[player] = { Plot = plot, Victim = victim, Slot = slotIndex, Uid = uid, StartedAt = now }
end

-- Attributs de la parcelle -----------------------------------------------------------------------------------

local function setIfChanged(plot: Model, name: string, value: any)
	if plot:GetAttribute(name) ~= value then
		plot:SetAttribute(name, value)
	end
end

local function publish(plot: Model)
	local owner = PlotService.GetOwner(plot)
	local protection: string? = nil
	local protectedUntil: number? = nil
	local safeText: string? = nil
	if owner then
		local refusal, left = protectionOf(nil, owner)
		protection = refusal
		if refusal == "Immune" and left then
			-- Arrondi à la seconde : l'attribut ne change pas à chaque publication.
			protectedUntil = math.ceil(Workspace:GetServerTimeNow() + left)
		end
		local slots: { number } = {}
		for slot in safeSlotsOf(owner, DisplayService.GetExposed(owner)) do
			table.insert(slots, slot)
		end
		table.sort(slots)
		if #slots > 0 then
			local parts: { string } = {}
			for _, slot in slots do
				table.insert(parts, tostring(slot))
			end
			safeText = table.concat(parts, ",")
		end
	end
	setIfChanged(plot, PROTECTION_ATTRIBUTE, protection)
	setIfChanged(plot, PROTECTED_UNTIL_ATTRIBUTE, protectedUntil)
	setIfChanged(plot, SAFE_SLOTS_ATTRIBUTE, safeText)
end

-- Tick -----------------------------------------------------------------------------------------------------------

local function step()
	local now = os.clock()
	for player, hold in table.clone(holds) do
		local exposed = DisplayService.GetExposed(hold.Victim)[hold.Slot]
		if
			exposed == nil
			or exposed.Uid ~= hold.Uid
			or now - hold.StartedAt > PvP.StealGrabTime + HOLD_EXPIRY
			or stealRefusal(player, hold.Plot, hold.Slot) ~= nil
		then
			holds[player] = nil
		end
	end
	for thief, theft in table.clone(thefts) do
		if thefts[thief] ~= theft then
			continue
		end
		if not present(theft.Victim) then
			abandon(theft, "VictimLeft")
			continue
		end
		local plot = PlotService.GetPlot(thief)
		local root = rootOf(thief)
		local refs = if plot then refsFor(plot) else nil
		local zone = if refs then refs.Deposit else nil
		local bounds = if refs then refs.Bounds else nil
		if root and zone and overFootprint(zone, root.Position) and (bounds == nil or inside(bounds, root.Position)) then
			deposit(theft, root)
		end
	end
	for _, shop in table.clone(shops) do
		updateViewers(shop)
	end
	ejectStep()
	publishCount += 1
	if publishCount >= PUBLISH_EVERY then
		publishCount = 0
		for _, plot in PlotService.GetPlots() do
			publish(plot)
		end
	end
end

-- Événements -------------------------------------------------------------------------------------------------------

local function onBroken(info: WindowService.BreakInfo)
	if info.Kind ~= "Plot" then
		return
	end
	local plot = info.Model
	local victim = PlotService.GetOwner(plot)
	if victim == nil then
		return
	end
	openShop(plot, victim, info.WindowId, info.Breaker)
	-- L'alarme de base (6.1, point 2).
	notify(victim, string.format(MESSAGES.DoorSmashed, info.Breaker.DisplayName), "Warning")
end

local function onRebuilt(_windowId: string, model: Model)
	if not table.find(PlotService.GetPlots(), model) then
		return -- pas une boutique (magasin PNJ)
	end
	local shop = shops[model]
	if shop then
		closeShop(shop, "porte reconstruite")
	end
	for _, player in ejectFrom(model, PlotService.GetOwner(model)) do
		notify(player, MESSAGES.DoorBack, "Warning")
		log(`{player.Name} sorti de {model.Name} : la porte est reconstruite`)
	end
end

local function onPlayerRemoving(player: Player)
	leaving[player] = true
	holds[player] = nil
	for thief, theft in table.clone(thefts) do
		if theft.Victim == player then
			abandon(theft, "VictimLeft")
		elseif thief == player then
			abandon(theft, "Left")
		end
	end
	for _, shop in table.clone(shops) do
		shop.Viewers[player] = nil
		if shop.Victim == player then
			closeShop(shop, "départ de la victime")
		end
	end
	immuneUntil[player] = nil
	lastNotice[player] = nil
	lastRefusal[player] = nil
end

-- API --------------------------------------------------------------------------------------------------------------

function PvPService.GetTheft(thief: Player): TheftInfo?
	local theft = thefts[thief]
	if theft == nil then
		return nil
	end
	return { Victim = theft.Victim, ItemUid = theft.Uid, ItemId = theft.ItemId, SlotIndex = theft.Slot }
end

function PvPService.IsThiefOf(player: Player, owner: Player): boolean
	local theft = thefts[player]
	return theft ~= nil and theft.Victim == owner
end

function PvPService.GetProtection(player: Player): (string?, number?)
	return protectionOf(nil, player)
end

-- Point d'accroche du coffre-fort (voir l'en-tête) : PvP.VaultSlots par défaut ; SkillTreeService le
-- remplace (compétence Safe).
function PvPService.GetVaultSlots(_owner: Player): number
	return PvP.VaultSlots
end

function PvPService.OnTheftStarted(listener: StartedListener): () -> ()
	return subscribe(startedListeners, listener)
end

function PvPService.OnTheftEnded(listener: EndedListener): () -> ()
	return subscribe(endedListeners, listener)
end

function PvPService.Init()
	for _, plot in PlotService.GetPlots() do
		refsFor(plot) -- avant que DisplayService y pose des objets (mêmes noms possibles)
	end
	previousCanBeHit = WindowService.CanBeHit
	WindowService.CanBeHit = canBeHit
	WindowService.OnBroken(onBroken)
	WindowService.OnRebuilt(onRebuilt)
	CarryService.OnCarryEnded(onCarryEnded)
	Net.Server.StealItem:Connect(onStealItem)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	log(`{#PlotService.GetPlots()} boutique(s) suivie(s) pour le vol entre joueurs`)
end

function PvPService.Start()
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[PvPService] tick : {err}`)
		end)
	end
end

return PvPService
