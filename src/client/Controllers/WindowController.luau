--!strict
-- WindowController (client) : état des vitrines envoyé par WindowService, et barre de PV au-dessus
-- de chaque vitre (Partie 1, sections 5.3, 9.4 et 9.7 ; contrat UI 2.2).
--
-- Garde en mémoire :
--   - les vitrines de la map : l'objet `Window` des modèles taggés NPCStore et PlayerPlot, dès
--     que le serveur y a posé l'attribut WindowId (WindowService pose aussi MaxHP et Broken).
--     Une vitrine qui sort de la map (streaming) est oubliée, puis reprise à son retour ;
--   - les derniers PV reçus (`WindowHP`, non fiable, 10 fois/s au plus), les coups (`WindowHit`)
--     et les casses (`WindowBroken`), redistribués aux autres contrôleurs (ShatterController).
--     WindowHit arrive aussi pour les coups sur une cible d'événement (camion, DEV-053) : seuls les
--     coups sur une vitrine de ce registre sont relayés (pas d'effet de verre sur le camion). Les
--     chiffres de dégâts de tous les coups sont à DamageNumberController, le son du coup sur le
--     camion à TruckController : ils écoutent WindowHit eux-mêmes.
--
-- Barre de PV : une copie du modèle de Clément ReplicatedStorage/Assets/UI/BB_WindowHP (contrat
-- 2.2) au-dessus de chaque vitre, avec la taille et le décalage du modèle : `Label` écrit
-- « PV / PV max », `Fill` (dans `Bar`) prend la largeur des PV. Proposition V0 : visible quand la
-- vitre est entamée, ou quand le joueur est à moins de Config.Shatter.HPBar.ShowDistance studs
-- de la vitre ; cachée quand elle est cassée ou incassable (parcelle libre). Le modèle absent :
-- pas de barre (une ligne en Studio).
-- Où elle est accrochée : sur un magasin PNJ, à la vitre (pièce Window, ou une pièce du Model Window).
-- Sur une boutique de joueur (PlayerPlot, a300, demande de Cantin du 21/11), à un point fixe, car sa
-- vitre est une porte (PlotDoor/Window, vantaux Leaf_L et Leaf_R) qui coulisse quand on entre :
--   1. l'Attachment `HealthBarPoint` de la parcelle, s'il est livré (même nom que le camion et la
--      Fortune Tower ; le décalage du modèle BB_WindowHP s'y ajoute) ;
--   2. sinon, un Attachment à nous dans Workspace.Terrain (local, rien dans le modèle de Clément), posé
--      une fois pour toutes au centre de la façade : milieu de `Bounds` en largeur, hauteur et
--      profondeur du centre de la vitre (que le coulissement des vantaux ne change pas). Même place à
--      l'écran qu'avant, la vitre fermée ;
--   3. tant que `Bounds` ou la vitre manquent (streaming) : à la vitre, comme avant, puis raccrochée.
-- La distance d'affichage se mesure toujours à la vitre.
--
-- API (client) :
--   WindowController.GetHP(windowId) -> (hp: number?, maxHp: number?)
--       Derniers PV reçus ; nil tant que la vitrine n'a jamais été touchée.
--   WindowController.GetFraction(windowId) -> number
--       PV / PV max : 1 sans nouvelles (vitre pleine), 0 si elle est cassée.
--   WindowController.GetWindow(windowId) -> (window: Instance?, model: Model?)
--       L'objet `Window` (Part, MeshPart ou Model) et son magasin ou sa parcelle, s'ils sont là.
--   WindowController.OnHP(fn(windowId, hp, maxHp)) -> déconnexion
--   WindowController.OnHit(fn(windowId, point, hitter: Player?)) -> déconnexion
--       Coups validés sur une vitrine du registre, celui qui casse compris (envoyé juste avant
--       WindowBroken, mais non fiable : il peut aussi arriver juste après OnBroken).
--   WindowController.OnBroken(fn(windowId, impactPoint)) -> déconnexion
--   WindowController.OnRebuilt(fn(windowId)) -> déconnexion        Broken repasse à false
--   WindowController.OnRemoved(fn(windowId)) -> déconnexion        vitrine sortie de la map

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local Shatter = require(Shared:WaitForChild("Config"):WaitForChild("Shatter"))
local Format = require(Shared:WaitForChild("Format"))

type HPListener = (windowId: string, hp: number, maxHp: number) -> ()
type HitListener = (windowId: string, point: Vector3, hitter: Player?) -> ()
type BrokenListener = (windowId: string, impactPoint: Vector3) -> ()
type IdListener = (windowId: string) -> ()

type Entry = {
	Id: string,
	Window: Instance, -- l'objet Window (BasePart ou Model)
	Model: Model, -- le magasin PNJ ou la parcelle
	WasBroken: boolean,
	Billboard: BillboardGui?,
	Fill: GuiObject?,
	Label: TextLabel?,
	FillHeight: UDim, -- hauteur d'origine de Fill, gardée
	Fraction: number?, -- largeur affichée de Fill
	IsPlot: boolean, -- boutique d'un joueur (PlayerPlot) : barre à un point fixe
	Point: Instance?, -- HealthBarPoint de Clément, trouvé dans la parcelle
	PointDirty: boolean, -- HealthBarPoint à chercher (au début, puis quand une pièce de ce nom arrive)
	Anchor: Attachment?, -- notre point fixe dans Workspace.Terrain (sans HealthBarPoint)
	Connections: { RBXScriptConnection },
}

local WINDOW_NAME = "Window" -- enfant obligatoire (10.4)
local WINDOW_TAGS = { "NPCStore", "PlayerPlot" } -- contrat 2.1
local WINDOW_ID_ATTRIBUTE = "WindowId" -- posés par WindowService sur la vitrine
local MAX_HP_ATTRIBUTE = "MaxHP"
local BROKEN_ATTRIBUTE = "Broken"
local BILLBOARD_NAME = "BB_WindowHP" -- contrat 2.2
local PLOT_TAG = "PlayerPlot"
local HEALTH_BAR_POINT = "HealthBarPoint" -- Attachment fixe de la parcelle (pas encore livré, a300)
local BOUNDS_NAME = "Bounds" -- enfant obligatoire de la parcelle (10.4)
local HPBar = Shatter.HPBar

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer

local WindowController = {}

local hpById: { [string]: { hp: number, maxHp: number } } = {}
local entries: { [string]: Entry } = {}
local entryByModel: { [Instance]: Entry } = {}
local waiting: { [Instance]: RBXScriptConnection } = {} -- modèles dont la vitre n'est pas encore prête
local hpListeners: { HPListener } = {}
local hitListeners: { HitListener } = {}
local brokenListeners: { BrokenListener } = {}
local rebuiltListeners: { IdListener } = {}
local removedListeners: { IdListener } = {}
local playerGui: Instance? = nil
local templateWarned = false

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function emitId(list: { IdListener }, windowId: string)
	for _, listener in table.clone(list) do
		task.spawn(listener, windowId)
	end
end

------------------------------------------------------------------------------
-- PV
------------------------------------------------------------------------------

local function maxHpOf(entry: Entry): number
	local value = entry.Window:GetAttribute(MAX_HP_ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

-- PV connus de la vitrine (les PV max si aucun coup n'a encore été reçu).
local function hpOf(entry: Entry, maxHp: number): number
	local known = hpById[entry.Id]
	if known == nil then
		return maxHp
	end
	return math.min(known.hp, maxHp)
end

------------------------------------------------------------------------------
-- Barre de PV (BB_WindowHP)
------------------------------------------------------------------------------

local function billboardTemplate(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local template = if current then current:FindFirstChild(BILLBOARD_NAME) else nil
	if template and template:IsA("BillboardGui") then
		return template
	end
	if IS_STUDIO and not templateWarned then
		templateWarned = true
		print(`[WindowController] {BILLBOARD_NAME} absent de ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")} : pas de barre de PV`)
	end
	return nil
end

-- Pièce à laquelle accrocher la barre : la vitre elle-même, ou une pièce de la vitre si c'est un Model.
local function adorneeOf(window: Instance): BasePart?
	if window:IsA("BasePart") then
		return window
	end
	if window:IsA("Model") then
		local primary = window.PrimaryPart
		if primary then
			return primary
		end
		return window:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function windowBox(window: Instance): (CFrame?, Vector3?)
	if window:IsA("BasePart") then
		return window.CFrame, window.Size
	elseif window:IsA("Model") then
		return window:GetBoundingBox()
	end
	return nil, nil
end

-- Distance entre `position` et le point de la vitre le plus proche.
local function distanceTo(window: Instance, position: Vector3): number
	local cf, size = windowBox(window)
	if cf == nil or size == nil then
		return math.huge
	end
	local p = cf:PointToObjectSpace(position)
	local h = size / 2
	local closest = Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))
	return (p - closest).Magnitude
end

-- HealthBarPoint de Clément dans la parcelle (Attachment, ou une pièce), cherché seulement quand il le faut.
local function plotPoint(entry: Entry): Instance?
	local point = entry.Point
	if point and not point:IsDescendantOf(Workspace) then
		entry.Point = nil
		entry.PointDirty = true
	end
	if entry.Point == nil and entry.PointDirty then
		entry.PointDirty = false
		local found = Find.path(entry.Model, HEALTH_BAR_POINT)
		if found and (found:IsA("Attachment") or found:IsA("BasePart")) and found:IsDescendantOf(Workspace) then
			entry.Point = found
		end
	end
	return entry.Point
end

-- Notre point fixe, posé une fois : centre de la façade (milieu de Bounds en largeur), à la hauteur et à la
-- profondeur du centre de la vitre. Les vantaux coulissent en largeur seulement (PlotDoorController) : même
-- la vitre ouverte, ou un seul vantail arrivé, donne la bonne hauteur. nil tant que Bounds ou la vitre manquent.
local function plotAnchor(entry: Entry): Attachment?
	if entry.Anchor then
		return entry.Anchor
	end
	local bounds = Find.path(entry.Model, BOUNDS_NAME)
	if bounds == nil or not bounds:IsA("BasePart") or adorneeOf(entry.Window) == nil then
		return nil
	end
	local cf = windowBox(entry.Window)
	if cf == nil then
		return nil
	end
	local frame = bounds.CFrame
	local center = frame:PointToObjectSpace(cf.Position)
	local anchor = Instance.new("Attachment")
	anchor.Name = `{BILLBOARD_NAME}_{entry.Id}`
	anchor.Position = frame:PointToWorldSpace(Vector3.new(0, center.Y, center.Z)) -- Terrain au centre du monde
	anchor.Parent = Workspace.Terrain
	entry.Anchor = anchor
	return anchor
end

-- Où accrocher la barre : point fixe pour une boutique de joueur, sinon (ou en attendant) la vitre.
local function billboardAdornee(entry: Entry): Instance?
	if entry.IsPlot then
		local fixed: Instance? = plotPoint(entry) or plotAnchor(entry)
		if fixed then
			return fixed
		end
	end
	return adorneeOf(entry.Window)
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function makeBillboard(entry: Entry)
	if entry.Billboard or playerGui == nil then
		return
	end
	local template = billboardTemplate()
	if template == nil then
		return
	end
	local adornee = billboardAdornee(entry)
	if adornee == nil then
		return
	end
	local gui = template:Clone()
	gui.Name = `{BILLBOARD_NAME}_{entry.Id}`
	gui.Adornee = adornee
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local fill = Find.path(gui, "Fill")
	local label = Find.path(gui, "Label")
	if fill and fill:IsA("GuiObject") then
		entry.Fill = fill
		entry.FillHeight = fill.Size.Y
	end
	if label and label:IsA("TextLabel") then
		entry.Label = label
	end
	entry.Fraction = nil
	gui.Parent = playerGui
	entry.Billboard = gui
end

local function refresh(entry: Entry, position: Vector3?)
	-- Vitre en Model (parcelles de Clément, PlotDoor.Window) : avec le streaming, le Model arrive avant ses
	-- pièces, donc pas d'Adornee au premier essai ; on recrée ou raccroche la barre dès qu'une pièce est là.
	-- Boutique de joueur : revue à chaque tour, pour passer de la vitre (en attendant) au point fixe.
	if entry.Billboard == nil then
		makeBillboard(entry)
	end
	local gui = entry.Billboard
	if gui == nil then
		return
	end
	local adornee: Instance? = gui.Adornee
	if entry.IsPlot or adornee == nil or not adornee:IsDescendantOf(Workspace) then
		local wanted = billboardAdornee(entry)
		if wanted and wanted ~= adornee then
			gui.Adornee = wanted
		end
	end
	local maxHp = maxHpOf(entry)
	if entry.Window:GetAttribute(BROKEN_ATTRIBUTE) == true or maxHp <= 0 then
		gui.Enabled = false
		return
	end
	local hp = hpOf(entry, maxHp)
	local fraction = math.clamp(hp / maxHp, 0, 1)
	local damaged = fraction < 1 - 1e-6
	local near = position ~= nil and distanceTo(entry.Window, position) <= HPBar.ShowDistance
	local wasVisible = gui.Enabled
	gui.Enabled = damaged or near
	if not gui.Enabled then
		return
	end
	local label = entry.Label
	if label then
		label.Text = `{Format.hp(hp)} / {Format.hp(maxHp)}`
	end
	local fill = entry.Fill
	if fill and entry.Fraction ~= fraction then
		local target = UDim2.new(fraction, 0, entry.FillHeight.Scale, entry.FillHeight.Offset)
		if wasVisible and entry.Fraction ~= nil then
			TweenService:Create(fill, TweenInfo.new(HPBar.TweenTime), { Size = target }):Play()
		else
			fill.Size = target
		end
		entry.Fraction = fraction
	end
end

local function refreshAll()
	local position = rootPosition()
	for _, entry in entries do
		refresh(entry, position)
	end
end

------------------------------------------------------------------------------
-- Registre des vitrines
------------------------------------------------------------------------------

local function windowOf(model: Instance): Instance?
	local object = model:FindFirstChild(WINDOW_NAME) or model:FindFirstChild(WINDOW_NAME, true)
	if object and (object:IsA("BasePart") or object:IsA("Model")) then
		return object
	end
	return nil
end

local function removeEntry(entry: Entry)
	if entryByModel[entry.Model] == entry then
		entryByModel[entry.Model] = nil
	end
	if entries[entry.Id] ~= entry then
		return
	end
	entries[entry.Id] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	table.clear(entry.Connections)
	local gui = entry.Billboard
	entry.Billboard = nil
	if gui then
		gui:Destroy()
	end
	local anchor = entry.Anchor
	entry.Anchor = nil
	entry.Point = nil
	if anchor then
		anchor:Destroy()
	end
	emitId(removedListeners, entry.Id)
end

local function addEntry(id: string, window: Instance, model: Model)
	local previous = entries[id]
	if previous then
		removeEntry(previous)
	end
	local entry: Entry = {
		Id = id,
		Window = window,
		Model = model,
		WasBroken = window:GetAttribute(BROKEN_ATTRIBUTE) == true,
		Billboard = nil,
		Fill = nil,
		Label = nil,
		FillHeight = UDim.new(1, 0),
		Fraction = nil,
		IsPlot = CollectionService:HasTag(model, PLOT_TAG),
		Point = nil,
		PointDirty = true,
		Anchor = nil,
		Connections = {},
	}
	entries[id] = entry
	entryByModel[model] = entry
	if entry.IsPlot then
		-- HealthBarPoint qui arrive avec le streaming (ou livré plus tard) : à chercher au prochain tour.
		table.insert(
			entry.Connections,
			model.DescendantAdded:Connect(function(descendant: Instance)
				if descendant.Name == HEALTH_BAR_POINT then
					entry.PointDirty = true
				end
			end)
		)
	end
	table.insert(
		entry.Connections,
		window:GetAttributeChangedSignal(BROKEN_ATTRIBUTE):Connect(function()
			local broken = window:GetAttribute(BROKEN_ATTRIBUTE) == true
			local rebuilt = entry.WasBroken and not broken
			entry.WasBroken = broken
			if rebuilt then
				local maxHp = maxHpOf(entry)
				hpById[id] = { hp = maxHp, maxHp = maxHp }
				emitId(rebuiltListeners, id)
			end
			refresh(entry, rootPosition())
		end)
	)
	table.insert(
		entry.Connections,
		window:GetAttributeChangedSignal(MAX_HP_ATTRIBUTE):Connect(function()
			refresh(entry, rootPosition())
		end)
	)
	table.insert(
		entry.Connections,
		window.AncestryChanged:Connect(function()
			if window.Parent == nil then
				removeEntry(entry) -- vitre retirée du modèle
			end
		end)
	)
	makeBillboard(entry)
	refresh(entry, rootPosition())
end

local function stopWaiting(model: Instance)
	local connection = waiting[model]
	if connection then
		connection:Disconnect()
		waiting[model] = nil
	end
end

-- Enregistre la vitre du modèle dès qu'elle a son WindowId (elle peut arriver plus tard : streaming).
local function track(model: Instance)
	if not model:IsA("Model") or entryByModel[model] ~= nil then
		return
	end
	local window = windowOf(model)
	local id = if window then window:GetAttribute(WINDOW_ID_ATTRIBUTE) else nil
	if window and type(id) == "string" and id ~= "" then
		stopWaiting(model)
		addEntry(id, window, model :: Model)
		return
	end
	if waiting[model] then
		return
	end
	if window then
		waiting[model] = window:GetAttributeChangedSignal(WINDOW_ID_ATTRIBUTE):Connect(function()
			stopWaiting(model)
			track(model)
		end)
	else
		waiting[model] = model.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == WINDOW_NAME then
				stopWaiting(model)
				track(model)
			end
		end)
	end
end

local function untrack(model: Instance)
	stopWaiting(model)
	local entry = entryByModel[model]
	if entry then
		removeEntry(entry)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function WindowController.GetHP(windowId: string): (number?, number?)
	local entry = hpById[windowId]
	if entry == nil then
		return nil, nil
	end
	return entry.hp, entry.maxHp
end

function WindowController.GetFraction(windowId: string): number
	local entry = entries[windowId]
	if entry and entry.Window:GetAttribute(BROKEN_ATTRIBUTE) == true then
		return 0
	end
	local known = hpById[windowId]
	if known and known.maxHp > 0 then
		return math.clamp(known.hp / known.maxHp, 0, 1)
	end
	return 1
end

function WindowController.GetWindow(windowId: string): (Instance?, Model?)
	local entry = entries[windowId]
	if entry == nil or entry.Window.Parent == nil then
		return nil, nil
	end
	return entry.Window, entry.Model
end

function WindowController.OnHP(listener: HPListener): () -> ()
	return subscribe(hpListeners, listener)
end

function WindowController.OnHit(listener: HitListener): () -> ()
	return subscribe(hitListeners, listener)
end

function WindowController.OnBroken(listener: BrokenListener): () -> ()
	return subscribe(brokenListeners, listener)
end

function WindowController.OnRebuilt(listener: IdListener): () -> ()
	return subscribe(rebuiltListeners, listener)
end

function WindowController.OnRemoved(listener: IdListener): () -> ()
	return subscribe(removedListeners, listener)
end

-- Registre prêt avant les Start : les autres contrôleurs peuvent appeler GetWindow tout de suite.
function WindowController.Init()
	for _, tag in WINDOW_TAGS do
		for _, model in CollectionService:GetTagged(tag) do
			track(model)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	end
end

function WindowController.Start()
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any

	Net.Client.WindowHP:Connect(function(windowId: string, hp: number, maxHp: number)
		hpById[windowId] = { hp = hp, maxHp = maxHp }
		for _, listener in table.clone(hpListeners) do
			task.spawn(listener, windowId, hp, maxHp)
		end
		local entry = entries[windowId]
		if entry then
			refresh(entry, rootPosition())
		end
	end)

	Net.Client.WindowHit:Connect(function(windowId: string, point: Vector3, hitter: Player?)
		if entries[windowId] == nil then
			return -- cible d'événement (camion) ou vitrine pas encore là : rien à creuser
		end
		for _, listener in table.clone(hitListeners) do
			task.spawn(listener, windowId, point, hitter)
		end
	end)

	Net.Client.WindowBroken:Connect(function(windowId: string, impactPoint: Vector3)
		local known = hpById[windowId]
		if known then
			known.hp = 0
		end
		local entry = entries[windowId]
		if entry then
			entry.WasBroken = true
			refresh(entry, rootPosition())
		end
		for _, listener in table.clone(brokenListeners) do
			task.spawn(listener, windowId, impactPoint)
		end
	end)

	-- Barres de PV : il faut le PlayerGui du joueur.
	playerGui = player:WaitForChild("PlayerGui")
	for _, entry in entries do
		makeBillboard(entry)
	end
	while true do
		task.wait(HPBar.UpdateInterval)
		refreshAll()
	end
end

return WindowController
