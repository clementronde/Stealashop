--!strict
-- WindowService (DEV-014) : PV, régénération, casse et reconstruction des vitrines
-- (Partie 1, sections 5.2, 5.3, 5.4, 6, 7.1, 9.4 et 9.7). Le même code sert aux magasins
-- PNJ et aux parcelles des joueurs (9.3).
--
-- Une vitrine = l'objet `Window` (Part, MeshPart ou Model) d'un modèle taggé `NPCStore` ou
-- `PlayerPlot` (contrat 2.1 et 10.4), posé dans la map : Workspace, hors _INBOX_CLEMENT.
-- Au démarrage, le serveur pose sur cet objet :
--   WindowId (texte)   identifiant stable, renvoyé par le client dans HitWindow :
--                      magasin = nom du modèle (« STORE_Z1_Superette »), parcelle =
--                      « Plot_<PlotIndex> » (suffixe _2, _3… si un nom est en double) ;
--   MaxHP (nombre)     PV max ; 0 = incassable (parcelle libre) ;
--   Broken (booléen)   vitrine cassée, pour les clients qui arrivent ou la voient apparaître.
--
-- Règles :
--   - PV max : magasin PNJ = Zones[Zone].WindowHP (4). Parcelle occupée (attribut
--     OwnerUserId ≠ 0, posé par PlotService, propriétaire présent) = base fixe selon le niveau de la
--     boutique (attribut StageLevel de la parcelle, 1 s'il manque ; Formulas.PlayerWindowHP, vague 29,
--     L-106 point 3 : plus les dégâts du propriétaire), recalculés à chaque tick : un niveau de
--     boutique qui change compte à fraction de PV égale. Parcelle libre : incassable. Sur une parcelle,
--     cette vitrine est la vitre de la porte (PlotDoor/Window) : la porte n'a pas d'autres PV.
--   - Régénération continue de 3 % des PV max par seconde (5.3, Balance.Window).
--   - Défenses de la boutique (arbre de compétences, vague 27 ; SkillTreeService remplace les points
--     d'accroche GetPlotHPMultiplier et GetPlotRegen, plus bas) : PV max d'une parcelle occupée ×
--     GetPlotHPMultiplier(propriétaire) (Glass × Walls), réparation de GetPlotRegen(propriétaire) des PV max par
--     seconde au lieu de Balance.Window.RegenPerSecond (Glass Regen). Lus à chaque tick : un achat compte
--     au tick suivant (0,1 s), à fraction de PV égale. Une erreur ou une valeur invalide (pas un nombre
--     fini > 0 pour les PV, ≥ 0 pour la réparation) reprend la valeur de base.
--   - Chrono de casse, magasins PNJ seulement (Clément, L-074) : le premier coup lance un chrono de
--     Balance.Window.BreakTimer s (13, V0), montré dans HeistTimer à chaque joueur qui frappe (même
--     remote que le chrono du braquage, même identifiant que le magasin, avec police = true : c'est le
--     chrono de police, « POLICE IN 13s », Cantin 2026-11-14). Cassée à temps : il disparaît chez ceux qui
--     ont frappé et StoreHeistService lance le chrono « HEIST » de Balance.Heist.Duration s (BreakInfo.ChronoEndsAt
--     reste dans BreakInfo, plus lu par StoreHeistService). Sinon la vitre revient à ses PV max, chrono masqué et message à ceux qui
--     ont frappé. Pas de régénération plus forte en plus : le chrono suffit contre la casse lente.
--   - HitWindow(windowId) (9.4), ignoré si : vitrine inconnue, cassée ou incassable ; vitrine
--     du joueur lui-même ; outil de casse pas en main ; plus de 10 studs entre le joueur et
--     le point le plus proche de la vitre (Balance.Hit.ServerMaxDistance) ; CanBeHit refuse.
--     Le débit (≤ 10 coups/s) est déjà limité par Net. Dégâts = ToolService.GetHitDamage.
--   - Chaque coup validé, celui qui casse compris : WindowHit(windowId, point de frappe, frappeur,
--     dégâts), non fiable, au frappeur et aux joueurs à moins de Config.Shatter.HitBroadcastRadius
--     studs du point (L-028 a) : chacun voit le creux des coups des autres (ShatterController, L-081) et
--     le chiffre de dégâts de chaque coup (DamageNumberController, DEV-053). Le coup qui casse
--     l'envoie juste avant WindowBroken. Un coup refusé n'envoie rien.
--   - À 0 PV : la vitre est cachée et ne bloque plus (Transparency, CanCollide, CanQuery),
--     Broken = true, WindowBroken(windowId, point d'impact) part à tous ; la casse elle-même
--     (éclats, flash, son) est jouée par les clients (5.4, ShatterController, DEV-016). Les
--     éclats sont ancrés et déplacés par le client, sans collision : aucun groupe de collision
--     n'est nécessaire pour qu'ils ignorent les joueurs.
--   - Reconstruction automatique, PV pleins : 5.3 dit « 20 s après la fermeture », et le
--     rideau tombe à la fin du chrono de 10 s, soit 10 + 20 = 30 s après la casse
--     (Balance.Heist.Duration + Balance.Window.RebuildDelay). Parcelle : même mécanique (6),
--     PvP.StealDuration (10) + 20 s au plus tôt ; vague 33 (Cantin, 2026-11-13) : plus de chrono chez un
--     joueur, et sa porte attend sans limite les points d'attente (AddRebuildGate : PvPService la garde
--     cassée tant qu'un intrus est dedans) ; les vitrines PNJ gardent GATE_MAX_WAIT. Le chrono de casse
--     reste aux magasins PNJ.
--   - WindowHP(windowId, hp, maxHp), non fiable : au plus 10 fois par seconde par vitrine
--     (Balance.Window.HPSyncHz), et seulement si les PV ou les PV max ont changé.
--
-- Cible d'événement (Kind = "Event" ; camion de l'événement, liaison L-049, TruckEventService) : un
-- modèle ajouté par le code avec AddTarget, frappé par la même chaîne que les vitrines : HitWindow,
-- outil de casse en main, 10 studs au plus du point le plus proche de la boîte du modèle, débit de
-- Net, CanBeHit, dégâts de ToolService.GetHitDamage. Ce qui change pour elle seulement :
--   - PV max fixes (donnés à AddTarget), sans régénération ni reconstruction ;
--   - un seul remote, WindowHit, comme pour une vitrine (chaque coup validé, celui qui casse compris,
--     avec ses dégâts : chiffre flottant, et son du coup joué par TruckController ; DEV-053) ; ni
--     WindowHP ni WindowBroken. Les clients n'y posent aucun effet de verre (WindowController ne
--     relaie à ShatterController que les coups sur ses vitrines). Ses PV sont l'attribut HP du
--     modèle, écrit au tick (10 fois par seconde au plus), lisible aussi par un client qui arrive en
--     cours de route ;
--   - à 0 PV : Broken = true et HP = 0, puis OnBroken (Kind = "Event") ; rien n'est caché ni
--     reconstruit, le service qui l'a ajoutée décide de la suite ;
--   - le modèle porte le tag HitTarget (posé par le code, hors du contrat de la section 2.1) et les
--     attributs WindowId, MaxHP, HP et Broken : HitController la vise comme une vitrine.
-- Les vitrines (magasins PNJ et parcelles) ne changent pas.
--
-- API (serveur) :
--   WindowService.CanBeHit(player, windowId) -> boolean
--       Point d'accroche des protections du jalon M3 (bouclier débutant, immunité après un
--       vol, 6.4) : renvoie true. PvPService le remplace (WindowService.CanBeHit = function…).
--       false ou une erreur = coup ignoré.
--   WindowService.AddHitGate(gate)
--       gate(player, windowId, kind, model) -> boolean, appelé pour chaque coup qui passerait (après
--       CanBeHit, juste avant les dégâts) : false = coup ignoré, sans dégâts, ni WindowHit, ni chrono
--       de casse ; c'est au point d'accroche de prévenir le joueur s'il le faut. Une erreur laisse
--       passer le coup (un avertissement). StoreHeistService s'en sert : un seul braquage à la fois
--       (Cantin, 2026-11-11, L-099 point 3).
--   WindowService.GetPlotHPMultiplier(owner) -> number
--   WindowService.GetPlotRegen(owner) -> number
--       Points d'accroche des défenses de la boutique de `owner` (voir les règles) : 1 et
--       Balance.Window.RegenPerSecond par défaut. SkillTreeService les remplace (WindowService.X = function…).
--   WindowService.GetHitDamageMultiplier(player) -> number
--       Point d'accroche des potions (vague 28, L-085 : Strength) : multiplicateur des dégâts d'un coup de
--       `player` (vitrines, parcelles et cibles d'événement), 1 par défaut. PotionService le remplace en gardant
--       celui d'avant. Ne touche ni ToolService.GetHitDamage, ni l'attribut Damage, ni les PV de la vitrine de
--       sa boutique. Une erreur ou une valeur qui n'est pas un nombre fini > 0 compte pour 1.
--   WindowService.GetFreePlotHP(model) -> number
--       Point d'accroche du bot joueur (L-105) : PV max de la porte d'une parcelle libre (OwnerUserId = 0),
--       0 (incassable) par défaut ; BotService le remplace pour la parcelle de son bot.
--   WindowService.OnHit(listener) -> déconnexion
--       listener(player, windowId, kind, model, damage) après chaque coup validé et compté (celui qui
--       casse compris, cibles d'événement comprises), juste après WindowHit. Pour les caméras de la
--       boutique (SkillTreeService, vague 27).
--   WindowService.OnBroken(listener) -> déconnexion
--       listener(info) à chaque casse ; info = { WindowId, Kind ("NPC" ou "Plot"), Model
--       (le magasin ou la parcelle), Breaker (joueur du dernier coup), ImpactPoint }.
--   WindowService.OnRebuilt(listener) -> déconnexion
--       listener(windowId, model) à chaque reconstruction.
--   WindowService.GetWindowId(model) -> string?
--       Id de la vitrine d'un magasin PNJ ou d'une parcelle.
--   WindowService.IsBroken(windowId) -> boolean
--   WindowService.Rebuild(windowId) -> boolean
--       Reconstruit tout de suite (ex. à l'aube, NightCycleService) ; false si la vitrine
--       est inconnue ou déjà intacte.
--   WindowService.AddTarget(model, maxHP) -> string?
--       Ajoute la cible d'événement `model` (voir plus haut), PV pleins ; renvoie son id (le nom du
--       modèle, suffixe _2… s'il est pris). nil, avec un avertissement, si le modèle n'est pas dans
--       le Workspace, s'il est déjà une cible ou une vitrine, ou si maxHP n'est pas un nombre > 0.
--       Retirée toute seule quand le modèle quitte le Workspace (Destroy compris).
--   WindowService.RemoveTarget(windowId) -> boolean
--       Retire une cible d'événement : plus aucun coup, tag HitTarget retiré (les attributs restent).
--       false si `windowId` n'est pas une cible d'événement enregistrée.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Config.Formulas)
local PvP = require(Shared.Config.PvP)
local Shatter = require(Shared.Config.Shatter)
local Zones = require(Shared.Config.Zones)
local Attributes = require(Shared.Contract.Attributes)
local Net = require(Shared.Net.Net)

local ToolService = require(script.Parent.ToolService)

export type WindowKind = "NPC" | "Plot" | "Event"

export type BreakInfo = {
	WindowId: string,
	Kind: WindowKind,
	Model: Model,
	Breaker: Player,
	ImpactPoint: Vector3,
	-- Magasin PNJ (L-118 point 9) : fin du chrono lancé au premier coup (heure serveur), qui continue après
	-- la casse ; nil pour une parcelle ou une cible d'événement.
	ChronoEndsAt: number?,
}

type BrokenListener = (info: BreakInfo) -> ()
type HitListener = (player: Player, windowId: string, kind: WindowKind, model: Model, damage: number) -> ()
type RebuiltListener = (windowId: string, model: Model) -> ()

type SavedPart = { CanCollide: boolean, CanQuery: boolean, Transparency: number }

type Window = {
	Id: string,
	Kind: WindowKind,
	Model: Model, -- le magasin PNJ ou la parcelle
	Object: Instance, -- l'objet nommé Window (BasePart ou Model)
	Parts: { BasePart }, -- ses pièces
	Saved: { [BasePart]: SavedPart }, -- leur état d'avant la casse
	Zone: number, -- magasin PNJ ; 0 pour une parcelle
	OwnerUserId: number, -- parcelle ; 0 = libre
	HP: number,
	MaxHP: number, -- 0 = incassable
	FixedMaxHP: number, -- cible d'événement : PV max donnés à AddTarget ; 0 pour une vitrine
	Broken: boolean,
	Dirty: boolean, -- PV à envoyer au prochain tick
	RebuildToken: number, -- change à chaque casse ou reconstruction : périme l'ancien délai
	Connections: { RBXScriptConnection },
	BreakEndsAt: number?, -- chrono de casse (L-074) : GetServerTimeNow() de la fin ; nil = pas lancé
	Hitters: { [Player]: boolean }?, -- joueurs qui voient ce chrono (ceux qui ont frappé)
}

-- Modèles qui portent une vitrine (contrat 2.1, Contract/Tags).
local WATCHED: { { Tag: string, Kind: WindowKind } } = {
	{ Tag = "NPCStore", Kind = "NPC" },
	{ Tag = "PlayerPlot", Kind = "Plot" },
}
local WINDOW_NAME = "Window" -- enfant obligatoire (10.4)
-- Livraisons de Clément pas encore posées dans la map (2.1) : comme le ContractChecker,
-- on ne les compte pas (ni les modèles rangés hors du Workspace, dans Assets).
local INBOX_NAME = "_INBOX_CLEMENT"
local OWNER_ATTRIBUTE = "OwnerUserId" -- posé par PlotService sur la parcelle
local PLOT_INDEX_ATTRIBUTE = "PlotIndex" -- posé sur la parcelle (greybox, L-015)
local STAGE_LEVEL_ATTRIBUTE = "StageLevel" -- posé sur la parcelle par ShopStageService (niveau de la boutique)
-- Posés ici sur l'objet Window, lus par les clients (mêmes noms dans HitController).
local WINDOW_ID_ATTRIBUTE = "WindowId"
local MAX_HP_ATTRIBUTE = "MaxHP"
local BROKEN_ATTRIBUTE = "Broken"
-- Cible d'événement seulement (mêmes noms dans HitController et TruckController).
local HP_ATTRIBUTE = "HP"
local HIT_TARGET_TAG = "HitTarget"
-- Longueur max d'un id accepté par Net (Definitions, windowId) ; 4 de marge pour « _n ».
local MAX_ID_LENGTH = 64

local SYNC_INTERVAL = 1 / Balance.Window.HPSyncHz
local IS_STUDIO = RunService:IsStudio()
-- Chrono de casse (L-074) : message quand la vitre se répare faute d'être cassée à temps. V0, en anglais (L-036).
local BREAK_TOO_SLOW = "Too slow! The glass repaired itself. Hit harder, or bring friends!"

local WindowService = {}

local windows: { [string]: Window } = {}
local byModel: { [Instance]: Window } = {}
local brokenListeners: { BrokenListener } = {}
local hitListeners: { HitListener } = {}
local modifierWarned: { [string]: boolean } = {}
local rebuiltListeners: { RebuiltListener } = {}
local lastRefusal: { [Player]: number } = {}
local canBeHitWarned = false
-- Points d'accroche de chaque coup (voir AddHitGate).
type HitGate = (player: Player, windowId: string, kind: WindowKind, model: Model) -> boolean
local hitGates: { HitGate } = {}
local hitGateWarned = false

function WindowService.CanBeHit(_player: Player, _windowId: string): boolean
	return true
end

-- Points d'accroche des défenses de la boutique (voir l'en-tête) : valeurs de base.
function WindowService.GetPlotHPMultiplier(_owner: Player): number
	return 1
end

function WindowService.GetPlotRegen(_owner: Player): number
	return Balance.Window.RegenPerSecond
end

function WindowService.GetHitDamageMultiplier(_player: Player): number
	return 1
end

-- Point d'accroche du bot joueur (L-105) : PV max de la porte d'une parcelle sans propriétaire joueur
-- (OwnerUserId = 0) ; 0 = incassable, par défaut. BotService le remplace pour la parcelle de son bot. Lu à
-- chaque tick, régénération de base ; une erreur ou une valeur invalide compte pour 0.
function WindowService.GetFreePlotHP(_model: Model): number
	return 0
end

-- Valeur d'un point d'accroche : un nombre fini ≥ 0 (> 0 si `strict`), sinon `base` (une erreur :
-- un avertissement, une fois par point d'accroche).
local function modifier(label: string, fn: (Player) -> number, owner: Player, base: number, strict: boolean): number
	local ok, value = pcall(fn, owner)
	if not ok then
		if not modifierWarned[label] then
			modifierWarned[label] = true
			warn(`[WindowService] {label} : erreur ({value}), valeur de base gardée`)
		end
		return base
	end
	if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or (strict and value == 0) then
		return base
	end
	return value
end

-- PV max de la porte d'une parcelle libre (GetFreePlotHP) : un nombre fini ≥ 0, sinon 0.
local function freePlotHP(model: Model): number
	local ok, value = pcall(WindowService.GetFreePlotHP, model)
	if not ok or type(value) ~= "number" or value ~= value or value == math.huge or value < 0 then
		return 0
	end
	return value
end

-- Renvoie une fonction qui retire `listener` de `list`.
local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

-- Coup refusé pour une raison anormale : signalé en Studio seulement (aide au test), au plus
-- une ligne par seconde et par joueur.
local function refuse(player: Player, windowId: string, reason: string)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[WindowService] coup de {player.Name} sur « {windowId} » ignoré : {reason}`)
end

local function windowBox(window: Window): (CFrame, Vector3)
	local object = window.Object
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	return (object :: Model):GetBoundingBox()
end

-- Point de la boîte (cf, size) le plus proche de `point`.
local function closestPoint(cf: CFrame, size: Vector3, point: Vector3): Vector3
	local p = cf:PointToObjectSpace(point)
	local h = size / 2
	return (cf:PointToWorldSpace(
		Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))
	)) -- parenthèses : une seule valeur (PointToWorldSpace est déclarée variadique)
end

local function computeMaxHP(window: Window): number
	if window.Kind == "Event" then
		return window.FixedMaxHP
	end
	if window.Kind == "NPC" then
		return Zones[window.Zone].WindowHP
	end
	if window.OwnerUserId == 0 then
		return freePlotHP(window.Model) -- 0 (incassable), sauf la boutique du bot joueur (L-105)
	end
	local owner = Players:GetPlayerByUserId(window.OwnerUserId)
	if owner == nil then
		return 0
	end
	local stage = window.Model:GetAttribute(STAGE_LEVEL_ATTRIBUTE)
	local base = Formulas.PlayerWindowHP(if type(stage) == "number" then stage else 1)
	return base * modifier("GetPlotHPMultiplier", WindowService.GetPlotHPMultiplier, owner, 1, true)
end

-- Part des PV max réparée par seconde (5.3) ; parcelle occupée : celle de son propriétaire (Glass Regen).
local function regenRate(window: Window): number
	local base = Balance.Window.RegenPerSecond
	if window.Kind ~= "Plot" or window.OwnerUserId == 0 then
		return base
	end
	local owner = Players:GetPlayerByUserId(window.OwnerUserId)
	if owner == nil then
		return base
	end
	return modifier("GetPlotRegen", WindowService.GetPlotRegen, owner, base, false)
end

-- Nouveaux PV max, même fraction de PV (une vitrine pleine reste pleine).
local function setMaxHP(window: Window, maxHP: number)
	if maxHP == window.MaxHP then
		return
	end
	if not window.Broken then
		window.HP = if window.MaxHP > 0 then window.HP / window.MaxHP * maxHP else maxHP
	end
	window.MaxHP = maxHP
	window.Dirty = true
	window.Object:SetAttribute(MAX_HP_ATTRIBUTE, maxHP)
end

-- PV max recalculés, PV pleins.
local function refill(window: Window)
	window.MaxHP = computeMaxHP(window)
	window.HP = window.MaxHP
	window.Dirty = true
	window.Object:SetAttribute(MAX_HP_ATTRIBUTE, window.MaxHP)
end

local function hideGlass(window: Window)
	for _, part in window.Parts do
		window.Saved[part] = { CanCollide = part.CanCollide, CanQuery = part.CanQuery, Transparency = part.Transparency }
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 1
	end
end

local function restoreGlass(window: Window)
	for part, saved in window.Saved do
		part.CanCollide = saved.CanCollide
		part.CanQuery = saved.CanQuery
		part.Transparency = saved.Transparency
	end
	table.clear(window.Saved)
end

local function rebuild(window: Window): boolean
	if not window.Broken then
		return false
	end
	window.Broken = false
	window.RebuildToken += 1
	restoreGlass(window)
	refill(window)
	window.Object:SetAttribute(BROKEN_ATTRIBUTE, false)
	for _, listener in table.clone(rebuiltListeners) do
		task.spawn(listener, window.Id, window.Model)
	end
	return true
end

-- Points d'attente avant la reconstruction automatique d'une vitrine (voir AddRebuildGate). V0
-- proposés, absents du doc : contrôle toutes les 0,25 s, 60 s d'attente en plus au plus.
type RebuildGate = (windowId: string, model: Model?) -> boolean
local rebuildGates: { RebuildGate } = {}
local GATE_POLL = 0.25
local GATE_MAX_WAIT = 60

local function gatesOpen(window: Window): boolean
	for _, gate in rebuildGates do
		local ok, open = pcall(gate, window.Id, window.Model)
		if ok and open == false then
			return false
		end
	end
	return true
end

local function rebuildDelay(window: Window): number
	local openFor = if window.Kind == "NPC" then Balance.Heist.Duration else PvP.StealDuration
	return openFor + Balance.Window.RebuildDelay
end

-- Prévient les écouteurs d'OnBroken.
local function emitBroken(window: Window, breaker: Player, impactPoint: Vector3, chronoEndsAt: number?)
	local info: BreakInfo = {
		WindowId = window.Id,
		Kind = window.Kind,
		Model = window.Model,
		Breaker = breaker,
		ImpactPoint = impactPoint,
		ChronoEndsAt = chronoEndsAt,
	}
	table.freeze(info :: any) -- gelée sur place ; :: any : le nouveau solveur bute sur le type générique de table.freeze
	for _, listener in table.clone(brokenListeners) do
		task.spawn(listener, info)
	end
end

local function breakWindow(window: Window, breaker: Player, impactPoint: Vector3)
	-- Cassée à temps : le chrono lancé au premier coup continue, c'est celui du vigile (L-118 point 9) ;
	-- cassée d'un seul coup : il part maintenant.
	local chronoEndsAt = if window.Kind == "NPC"
		then window.BreakEndsAt or Workspace:GetServerTimeNow() + Balance.Window.BreakTimer
		else nil
	local hitters = window.Hitters
	window.BreakEndsAt = nil
	window.Hitters = nil
	window.Broken = true
	window.HP = 0
	window.Dirty = true
	window.RebuildToken += 1
	local token = window.RebuildToken
	hideGlass(window)
	window.Object:SetAttribute(BROKEN_ATTRIBUTE, true)
	Net.Server.WindowBroken:FireAll(window.Id, impactPoint)
	task.delay(rebuildDelay(window), function()
		-- Points d'attente (AddRebuildGate) : le magasin ne se rouvre pas tant que ses vigiles ne
		-- sont pas rentrés (GuardService). Au plus GATE_MAX_WAIT s d'attente en plus, par sécurité.
		local waited = 0
		-- Vague 33 : une porte de boutique attend sans limite (PvPService : tant qu'un intrus est dedans).
		while
			window.RebuildToken == token
			and windows[window.Id] == window
			and (window.Kind == "Plot" or waited < GATE_MAX_WAIT)
			and not gatesOpen(window)
		do
			task.wait(GATE_POLL)
			waited += GATE_POLL
		end
		if window.RebuildToken == token and windows[window.Id] == window then
			rebuild(window)
		end
	end)
	-- Vague 40 (Cantin, 2026-11-14) : cassée à temps, le chrono de police disparaît chez ceux qui ont frappé ;
	-- StoreHeistService (OnBroken, juste après, même remote et même identifiant) montre le chrono « HEIST ».
	if hitters then
		for hitter in hitters do
			if hitter.Parent == Players then
				Net.Server.HeistTimer:Fire(hitter, window.Id, 0)
			end
		end
	end
	emitBroken(window, breaker, impactPoint, chronoEndsAt)
end

-- Cible d'événement à 0 PV : ni verre caché, ni remote, ni reconstruction (voir l'en-tête).
local function breakTarget(window: Window, breaker: Player, impactPoint: Vector3)
	window.Broken = true
	window.HP = 0
	window.Dirty = false
	window.RebuildToken += 1
	window.Object:SetAttribute(HP_ATTRIBUTE, 0)
	window.Object:SetAttribute(BROKEN_ATTRIBUTE, true)
	emitBroken(window, breaker, impactPoint)
end

-- Coup validé (celui qui casse compris) : WindowHit au frappeur (écho de son coup, au point
-- calculé ici, et son chiffre de dégâts) et aux joueurs proches du point de frappe (L-028 a,
-- DEV-053). Un joueur sans personnage ne reçoit rien, sauf le frappeur.
local function broadcastHit(window: Window, hitter: Player, point: Vector3, damage: number)
	for _, other in Players:GetPlayers() do
		if other ~= hitter then
			local character = other.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root == nil or not root:IsA("BasePart") then
				continue
			end
			if ((root :: BasePart).Position - point).Magnitude > Shatter.HitBroadcastRadius then
				continue
			end
		end
		Net.Server.WindowHit:Fire(other, window.Id, point, hitter, damage)
	end
end

local function canBeHit(player: Player, windowId: string): boolean
	local ok, allowed = pcall(WindowService.CanBeHit, player, windowId)
	if ok then
		return allowed == true
	end
	if not canBeHitWarned then
		canBeHitWarned = true
		warn(`[WindowService] CanBeHit : erreur ({allowed}), coups ignorés tant qu'elle se produit`)
	end
	return false
end

-- Points d'accroche (AddHitGate) : false si l'un refuse le coup ; une erreur le laisse passer.
local function gatesAllow(player: Player, window: Window): boolean
	for _, gate in hitGates do
		local ok, allowed = pcall(gate, player, window.Id, window.Kind, window.Model)
		if not ok then
			if not hitGateWarned then
				hitGateWarned = true
				warn(`[WindowService] AddHitGate : erreur ({allowed}), coup laissé passer`)
			end
		elseif allowed == false then
			return false
		end
	end
	return true
end

local function onHitWindow(player: Player, windowId: string)
	local window = windows[windowId]
	if window == nil then
		refuse(player, windowId, "vitrine inconnue")
		return
	end
	if window.Broken or window.MaxHP <= 0 then
		return -- déjà cassée ou incassable : normal juste après une casse, rien à signaler
	end
	if window.Kind == "Plot" and window.OwnerUserId == player.UserId then
		return -- sa propre vitrine
	end
	if not ToolService.IsHoldingTool(player) then
		refuse(player, windowId, "outil de casse pas en main")
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return
	end
	local position = (root :: BasePart).Position
	local cf, size = windowBox(window)
	local impactPoint = closestPoint(cf, size, position)
	local distance = (impactPoint - position).Magnitude
	if distance > Balance.Hit.ServerMaxDistance then
		refuse(player, windowId, `trop loin ({math.round(distance * 10) / 10} studs)`)
		return
	end
	if not canBeHit(player, windowId) then
		return
	end
	if not gatesAllow(player, window) then
		return
	end
	local damage = ToolService.GetHitDamage(player)
		* modifier("GetHitDamageMultiplier", WindowService.GetHitDamageMultiplier, player, 1, true)
	if damage <= 0 then
		return
	end
	window.HP = math.max(0, window.HP - damage)
	window.Dirty = true
	if window.Kind == "NPC" and window.HP > 0 then
		-- Chrono de casse (L-074) : lancé au premier coup, montré à chaque joueur qui frappe.
		local endsAt = window.BreakEndsAt
		if endsAt == nil then
			endsAt = Workspace:GetServerTimeNow() + Balance.Window.BreakTimer
			window.BreakEndsAt = endsAt
		end
		local hitters = window.Hitters or {}
		window.Hitters = hitters
		if not hitters[player] then
			hitters[player] = true
			Net.Server.HeistTimer:Fire(player, window.Id, endsAt, true) -- chrono de police (vague 40)
		end
	end
	-- Avant la casse : le chiffre du coup qui casse part comme les autres (DEV-053).
	broadcastHit(window, player, impactPoint, damage)
	for _, listener in table.clone(hitListeners) do
		task.spawn(listener, player, window.Id, window.Kind, window.Model, damage)
	end
	if window.Kind == "Event" then
		if window.HP <= 0 then
			breakTarget(window, player, impactPoint)
		end
	elseif window.HP <= 0 then
		breakWindow(window, player, impactPoint)
	end
end

-- Un tick (10 par seconde) : PV max des parcelles, régénération, envoi des PV changés.
local function step(dt: number)
	for _, window in windows do
		if window.Kind == "Event" then
			-- Cible d'événement : ni régénération ni WindowHP, ses PV sont l'attribut HP (en-tête).
			if window.Dirty then
				window.Dirty = false
				window.Object:SetAttribute(HP_ATTRIBUTE, window.HP)
			end
			continue
		end
		if window.Kind == "Plot" then
			setMaxHP(window, computeMaxHP(window))
		end
		local endsAt = window.BreakEndsAt
		if endsAt and not window.Broken and Workspace:GetServerTimeNow() >= endsAt then
			-- Pas cassée à temps (L-074) : la vitre revient à ses PV max.
			window.HP = window.MaxHP
			window.Dirty = true
			local hitters = window.Hitters
			if hitters then
				for hitter in hitters do
					if hitter.Parent == Players then
						Net.Server.HeistTimer:Fire(hitter, window.Id, 0)
						Net.Server.Notify:Fire(hitter, BREAK_TOO_SLOW, "Alert")
					end
				end
			end
			window.BreakEndsAt = nil
			window.Hitters = nil
		end
		if not window.Broken and window.HP < window.MaxHP then
			window.HP = math.min(window.MaxHP, window.HP + regenRate(window) * dt * window.MaxHP)
			window.Dirty = true
		end
		if window.Dirty then
			window.Dirty = false
			Net.Server.WindowHP:FireAll(window.Id, window.HP, window.MaxHP)
		end
	end
end

local function readOwner(model: Model): number
	local value = model:GetAttribute(OWNER_ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

-- Nouveau propriétaire ou parcelle libérée : vitrine intacte, PV pleins.
local function onOwnerChanged(window: Window)
	local owner = readOwner(window.Model)
	if owner == window.OwnerUserId then
		return
	end
	window.OwnerUserId = owner
	if not rebuild(window) then
		refill(window)
	end
end

local function makeId(kind: WindowKind, model: Model): string
	local index = model:GetAttribute(PLOT_INDEX_ATTRIBUTE)
	local base = if kind == "Plot" and type(index) == "number" then `Plot_{index}` else model.Name
	if base == "" then
		base = WINDOW_NAME
	end
	base = string.sub(base, 1, MAX_ID_LENGTH - 4)
	local id, n = base, 1
	while windows[id] ~= nil do
		n += 1
		id = `{base}_{n}`
	end
	return id
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

local function register(instance: Instance, kind: WindowKind)
	if not instance:IsA("Model") or byModel[instance] ~= nil or not inMap(instance) then
		return
	end
	local model = instance :: Model
	local object = model:FindFirstChild(WINDOW_NAME) or model:FindFirstChild(WINDOW_NAME, true)
	if object == nil or not (object:IsA("BasePart") or object:IsA("Model")) then
		warn(`[WindowService] {model:GetFullName()} : pas de vitrine « {WINDOW_NAME} » (Part ou Model), ignoré`)
		return
	end
	local zone = 0
	if kind == "NPC" then
		local value = model:GetAttribute(Attributes.Zone.Name)
		if type(value) ~= "number" or Zones[value] == nil then
			warn(`[WindowService] {model:GetFullName()} : attribut {Attributes.Zone.Name} invalide ({value}), vitrine ignorée`)
			return
		end
		zone = value
	end
	local parts: { BasePart } = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	end
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	local window: Window = {
		Id = makeId(kind, model),
		Kind = kind,
		Model = model,
		Object = object,
		Parts = parts,
		Saved = {},
		Zone = zone,
		OwnerUserId = if kind == "Plot" then readOwner(model) else 0,
		HP = 0,
		MaxHP = 0,
		FixedMaxHP = 0,
		Broken = false,
		Dirty = false,
		RebuildToken = 0,
		Connections = {},
	}
	windows[window.Id] = window
	byModel[model] = window
	object:SetAttribute(WINDOW_ID_ATTRIBUTE, window.Id)
	object:SetAttribute(BROKEN_ATTRIBUTE, false)
	refill(window)
	window.Dirty = false -- PV pleins : rien à envoyer, l'attribut MaxHP suffit
	if kind == "Plot" then
		table.insert(
			window.Connections,
			model:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(function()
				onOwnerChanged(window)
			end)
		)
	end
end

local function unregister(instance: Instance)
	local window = byModel[instance]
	if window == nil then
		return
	end
	byModel[instance] = nil
	windows[window.Id] = nil
	window.RebuildToken += 1
	for _, connection in window.Connections do
		connection:Disconnect()
	end
end

function WindowService.OnHit(listener: HitListener): () -> ()
	return subscribe(hitListeners, listener)
end

function WindowService.OnBroken(listener: BrokenListener): () -> ()
	return subscribe(brokenListeners, listener)
end

function WindowService.OnRebuilt(listener: RebuiltListener): () -> ()
	return subscribe(rebuiltListeners, listener)
end

function WindowService.GetWindowId(model: Instance): string?
	local window = byModel[model]
	return if window then window.Id else nil
end

function WindowService.IsBroken(windowId: string): boolean
	local window = windows[windowId]
	return window ~= nil and window.Broken
end

-- Ajoute un point d'attente à la reconstruction automatique (après la casse) : tant qu'il renvoie
-- false, la vitrine attend (au plus GATE_MAX_WAIT s). WindowService.Rebuild, appelé par le code (aube,
-- tests), ne l'attend pas. Utilisé par GuardService : pas de rouverture tant qu'un vigile rentre.
function WindowService.AddRebuildGate(gate: RebuildGate)
	table.insert(rebuildGates, gate)
end

function WindowService.AddHitGate(gate: HitGate)
	table.insert(hitGates, gate)
end

function WindowService.Rebuild(windowId: string): boolean
	local window = windows[windowId]
	return window ~= nil and rebuild(window)
end

-- Cibles d'événement (voir l'en-tête) -------------------------------------------------------

local function removeTarget(window: Window): boolean
	if window.Kind ~= "Event" or windows[window.Id] ~= window then
		return false
	end
	unregister(window.Model)
	CollectionService:RemoveTag(window.Model, HIT_TARGET_TAG)
	return true
end

function WindowService.AddTarget(model: Model, maxHP: number): string?
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
		warn(debug.traceback(`[WindowService] AddTarget({model}) refusé : il faut un Model posé dans le Workspace`, 2))
		return nil
	end
	if byModel[model] ~= nil then
		warn(debug.traceback(`[WindowService] AddTarget({model:GetFullName()}) refusé : déjà une cible ou une vitrine`, 2))
		return nil
	end
	if type(maxHP) ~= "number" or maxHP ~= maxHP or maxHP <= 0 or maxHP == math.huge then
		warn(debug.traceback(`[WindowService] AddTarget({model:GetFullName()}) refusé : PV max invalides ({maxHP})`, 2))
		return nil
	end
	local window: Window = {
		Id = makeId("Event", model),
		Kind = "Event",
		Model = model,
		Object = model,
		Parts = {},
		Saved = {},
		Zone = 0,
		OwnerUserId = 0,
		HP = maxHP,
		MaxHP = maxHP,
		FixedMaxHP = maxHP,
		Broken = false,
		Dirty = false,
		RebuildToken = 0,
		Connections = {},
	}
	windows[window.Id] = window
	byModel[model] = window
	model:SetAttribute(WINDOW_ID_ATTRIBUTE, window.Id)
	model:SetAttribute(MAX_HP_ATTRIBUTE, maxHP)
	model:SetAttribute(HP_ATTRIBUTE, maxHP)
	model:SetAttribute(BROKEN_ATTRIBUTE, false)
	table.insert(
		window.Connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				removeTarget(window)
			end
		end)
	)
	CollectionService:AddTag(model, HIT_TARGET_TAG)
	return window.Id
end

function WindowService.RemoveTarget(windowId: string): boolean
	local window = windows[windowId]
	return window ~= nil and removeTarget(window)
end

function WindowService.Init()
	for _, watched in WATCHED do
		for _, instance in CollectionService:GetTagged(watched.Tag) do
			register(instance, watched.Kind)
		end
		CollectionService:GetInstanceAddedSignal(watched.Tag):Connect(function(instance: Instance)
			register(instance, watched.Kind)
		end)
		CollectionService:GetInstanceRemovedSignal(watched.Tag):Connect(unregister)
	end
	Net.Server.HitWindow:Connect(onHitWindow)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRefusal[player] = nil
	end)

	local stores, plots = 0, 0
	for _, window in windows do
		if window.Kind == "NPC" then
			stores += 1
		else
			plots += 1
		end
	end
	print(`[WindowService] {stores + plots} vitrine(s) prête(s) : {stores} de magasins PNJ, {plots} de parcelles`)
end

function WindowService.Start()
	while true do
		local dt = task.wait(SYNC_INTERVAL)
		local ok, err = pcall(step, dt)
		if not ok then
			warn(`[WindowService] tick : {err}`)
		end
	end
end

return WindowService
