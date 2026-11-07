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
--     OwnerUserId ≠ 0, posé par PlotService) = 50 × les dégâts par coup du propriétaire (6,
--     Formulas.PlayerWindowHP), recalculés à chaque tick : outil, Force ou aura qui changent
--     sont pris en compte, à fraction de PV égale. Parcelle libre : incassable.
--   - Régénération continue de 3 % des PV max par seconde (5.3, Balance.Window).
--   - HitWindow(windowId) (9.4), ignoré si : vitrine inconnue, cassée ou incassable ; vitrine
--     du joueur lui-même ; outil de casse pas en main ; plus de 10 studs entre le joueur et
--     le point le plus proche de la vitre (Balance.Hit.ServerMaxDistance) ; CanBeHit refuse.
--     Le débit (≤ 10 coups/s) est déjà limité par Net. Dégâts = ToolService.GetHitDamage.
--   - Chaque coup validé qui laisse des PV : WindowHit(windowId, point de frappe, frappeur), non
--     fiable, au frappeur et aux joueurs à moins de Config.Shatter.HitBroadcastRadius studs du
--     point (L-028 a) : chacun voit les fissures des autres (ShatterController, DEV-016).
--   - À 0 PV : la vitre est cachée et ne bloque plus (Transparency, CanCollide, CanQuery),
--     Broken = true, WindowBroken(windowId, point d'impact) part à tous ; la casse elle-même
--     (éclats, flash, son) est jouée par les clients (5.4, ShatterController, DEV-016). Les
--     éclats sont ancrés et déplacés par le client, sans collision : aucun groupe de collision
--     n'est nécessaire pour qu'ils ignorent les joueurs.
--   - Reconstruction automatique, PV pleins : 5.3 dit « 20 s après la fermeture », et le
--     rideau tombe à la fin du chrono de 10 s, soit 10 + 20 = 30 s après la casse
--     (Balance.Heist.Duration + Balance.Window.RebuildDelay). Parcelle : même mécanique (6),
--     10 s pour voler (PvP.StealDuration) + 20 s.
--   - WindowHP(windowId, hp, maxHp), non fiable : au plus 10 fois par seconde par vitrine
--     (Balance.Window.HPSyncHz), et seulement si les PV ou les PV max ont changé.
--
-- Cible d'événement (Kind = "Event" ; camion de l'événement, liaison L-049, TruckEventService) : un
-- modèle ajouté par le code avec AddTarget, frappé par la même chaîne que les vitrines : HitWindow,
-- outil de casse en main, 10 studs au plus du point le plus proche de la boîte du modèle, débit de
-- Net, CanBeHit, dégâts de ToolService.GetHitDamage. Ce qui change pour elle seulement :
--   - PV max fixes (donnés à AddTarget), sans régénération ni reconstruction ;
--   - aucun remote : ni WindowHit, ni WindowHP, ni WindowBroken (les effets de verre de
--     ShatterController n'ont rien à y faire). Ses PV sont l'attribut HP du modèle, écrit au tick
--     (10 fois par seconde au plus), lisible aussi par un client qui arrive en cours de route ;
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
}

type BrokenListener = (info: BreakInfo) -> ()
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

local WindowService = {}

local windows: { [string]: Window } = {}
local byModel: { [Instance]: Window } = {}
local brokenListeners: { BrokenListener } = {}
local rebuiltListeners: { RebuiltListener } = {}
local lastRefusal: { [Player]: number } = {}
local canBeHitWarned = false

function WindowService.CanBeHit(_player: Player, _windowId: string): boolean
	return true
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
		return 0
	end
	local owner = Players:GetPlayerByUserId(window.OwnerUserId)
	if owner == nil then
		return 0
	end
	local damage = ToolService.GetHitDamage(owner)
	return if damage > 0 then Formulas.PlayerWindowHP(damage) else 0 -- 0 : profil pas encore chargé
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

local function rebuildDelay(window: Window): number
	local openFor = if window.Kind == "NPC" then Balance.Heist.Duration else PvP.StealDuration
	return openFor + Balance.Window.RebuildDelay
end

-- Prévient les écouteurs d'OnBroken.
local function emitBroken(window: Window, breaker: Player, impactPoint: Vector3)
	local info: BreakInfo = {
		WindowId = window.Id,
		Kind = window.Kind,
		Model = window.Model,
		Breaker = breaker,
		ImpactPoint = impactPoint,
	}
	table.freeze(info :: any) -- gelée sur place ; :: any : le nouveau solveur bute sur le type générique de table.freeze
	for _, listener in table.clone(brokenListeners) do
		task.spawn(listener, info)
	end
end

local function breakWindow(window: Window, breaker: Player, impactPoint: Vector3)
	window.Broken = true
	window.HP = 0
	window.Dirty = true
	window.RebuildToken += 1
	local token = window.RebuildToken
	hideGlass(window)
	window.Object:SetAttribute(BROKEN_ATTRIBUTE, true)
	Net.Server.WindowBroken:FireAll(window.Id, impactPoint)
	task.delay(rebuildDelay(window), function()
		if window.RebuildToken == token and windows[window.Id] == window then
			rebuild(window)
		end
	end)
	emitBroken(window, breaker, impactPoint)
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

-- Coup validé qui laisse des PV : WindowHit au frappeur (son étoile de fissure, au point calculé
-- ici) et aux joueurs proches du point de frappe (L-028 a). Un joueur sans personnage ne reçoit
-- rien, sauf le frappeur.
local function broadcastHit(window: Window, hitter: Player, point: Vector3)
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
		Net.Server.WindowHit:Fire(other, window.Id, point, hitter)
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
	local damage = ToolService.GetHitDamage(player)
	if damage <= 0 then
		return
	end
	window.HP = math.max(0, window.HP - damage)
	window.Dirty = true
	if window.Kind == "Event" then
		if window.HP <= 0 then
			breakTarget(window, player, impactPoint)
		end
	elseif window.HP <= 0 then
		breakWindow(window, player, impactPoint)
	else
		broadcastHit(window, player, impactPoint)
	end
end

-- Un tick (10 par seconde) : PV max des parcelles, régénération, envoi des PV changés.
local function step(dt: number)
	local regen = Balance.Window.RegenPerSecond * dt
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
		if not window.Broken and window.HP < window.MaxHP then
			window.HP = math.min(window.MaxHP, window.HP + regen * window.MaxHP)
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
