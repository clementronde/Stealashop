--!strict
-- ShelfBoxController (DEV-015, DEV-017, client) : contour et étiquette des colis, côté joueur
-- (liaison L-031, décisions de Clément acceptées par Ironix le 2026-11-07). Réglages :
-- Config/ShelfBoxes. Tout est local : rien n'est envoyé au serveur, aucune UI créée.
--
-- Contours. Les modèles BOX_* de Clément portent un Highlight `OutlineHighlight` (contour noir,
-- DepthMode Occluded), mais Roblox n'affiche que 31 Highlight à la fois et la map compte 120
-- colis. Ce contrôleur suit tous les Highlight `OutlineHighlight` du Workspace : colis des rayons,
-- colis portés, colis sur les établis, colis au sol. Seuls les ShelfBoxes.MaxOutlines (25) plus
-- proches de la caméra, à OutlineMaxDistance studs au plus, restent actifs ; les autres sont
-- coupés en local. Les arêtes noires `Outline` (SelectionBox) restent toujours visibles, en
-- secours. Les autres Highlight du jeu (contour rouge d'un objet volé, StolenOutline) ne sont pas
-- touchés : la marge de 6 leur sert.
--
-- Étiquettes. Chaque colis d'un rayon (tag ShelfBox, posé par StoreHeistService) porte BB_Box,
-- en AlwaysOnTop chez Clément : on la verrait à travers les rayons voisins. Elle n'est active que
-- si son colis est en vue :
--   - son point d'accroche (LabelPoint) est à MaxDistance de BB_Box au plus de la caméra ;
--   - un rayon lancé de la caméra vers ce point n'est arrêté par rien. Ignorés : les colis (leurs
--     pièces ont CanQuery = false), les personnages (tout modèle avec un Humanoid : joueurs,
--     vigiles), les pièces au moins aussi transparentes que SeeThroughTransparency (vitres,
--     volumes invisibles), et un obstacle à LabelRayTolerance studs ou moins du point (le bord de
--     son propre casier).
-- Les rayons partent à fréquence réduite (un même colis au plus toutes les LabelCheckInterval s)
-- et sont répartis sur les images (LabelChecksPerFrame au plus par image) ; la liste des colis à
-- portée est refaite toutes les RefreshInterval s. Un colis qui arrive a son étiquette coupée
-- jusqu'à son premier contrôle. Les étiquettes des colis portés ou au sol ne sont pas touchées.
--
-- API (client) :
--   ShelfBoxController.GetStats() -> { Outlines, ActiveOutlines, Labels, NearLabels, VisibleLabels }
--       Compteurs, pour un test dans Studio (barre de commande côté client).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ShelfBoxes = require(Config:WaitForChild("ShelfBoxes"))

-- Posés par StoreHeistService et CarryService (mêmes noms là-bas).
local SHELF_BOX_TAG = "ShelfBox"
local LABEL_NAME = "BB_Box" -- contrat 2.2 (L-031)

type LabelEntry = {
	Box: Instance,
	Gui: BillboardGui?,
	CheckedAt: number, -- os.clock() du dernier rayon
}

type OutlineEntry = {
	Highlight: Highlight,
	Distance: number,
}

export type Stats = {
	Outlines: number,
	ActiveOutlines: number,
	Labels: number,
	NearLabels: number,
	VisibleLabels: number,
}

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local ShelfBoxController = {}

local outlines: { [Highlight]: boolean } = {}
local labels: { [Instance]: LabelEntry } = {}
local near: { LabelEntry } = {} -- étiquettes à portée, revues par rayon chacune à son tour
local cursor = 1
local sinceRefresh = math.huge -- premier tri à la première image
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local lastError = -math.huge
local ERROR_INTERVAL = 10 -- V0 proposé, absent du doc : une erreur écrite toutes les 10 s au plus

-- Position monde d'un objet adorné (Attachment, pièce ou modèle), ou nil.
local function positionOf(object: Instance?): Vector3?
	if object == nil then
		return nil
	end
	if object:IsA("Attachment") then
		return object.WorldPosition
	elseif object:IsA("BasePart") then
		return object.Position
	elseif object:IsA("Model") then
		return object:GetPivot().Position
	end
	return nil
end

-- Contours -------------------------------------------------------------------------------------

local function trackOutline(instance: Instance)
	if instance:IsA("Highlight") and instance.Name == ShelfBoxes.OutlineName and not outlines[instance] then
		outlines[instance] = true
		instance.Enabled = false -- jusqu'au prochain tri : jamais plus de MaxOutlines actifs
	end
end

local function refreshOutlines(cameraPosition: Vector3)
	local list: { OutlineEntry } = {}
	for highlight in outlines do
		if not highlight:IsDescendantOf(Workspace) then
			outlines[highlight] = nil
			continue
		end
		local position = positionOf(highlight.Adornee or highlight.Parent)
		local distance = if position then (position - cameraPosition).Magnitude else math.huge
		if distance <= ShelfBoxes.OutlineMaxDistance then
			table.insert(list, { Highlight = highlight, Distance = distance })
		elseif highlight.Enabled then
			highlight.Enabled = false
		end
	end
	table.sort(list, function(a: OutlineEntry, b: OutlineEntry): boolean
		return a.Distance < b.Distance
	end)
	for index, entry in list do
		local enabled = index <= ShelfBoxes.MaxOutlines
		if entry.Highlight.Enabled ~= enabled then
			entry.Highlight.Enabled = enabled
		end
	end
end

-- Étiquettes -------------------------------------------------------------------------------------

-- BB_Box du colis (cherchée parmi ses descendants), coupée à sa découverte.
local function labelOf(entry: LabelEntry): BillboardGui?
	local gui = entry.Gui
	if gui and gui:IsDescendantOf(entry.Box) then
		return gui
	end
	entry.Gui = nil
	local found = entry.Box:FindFirstChild(LABEL_NAME, true)
	if found and found:IsA("BillboardGui") then
		found.Enabled = false
		entry.Gui = found
		return found
	end
	return nil
end

-- Portée de l'étiquette : sa MaxDistance (celle de Clément), sinon LabelFallbackDistance.
local function rangeOf(gui: BillboardGui): number
	local range = gui.MaxDistance
	if range <= 0 or range == math.huge then
		return ShelfBoxes.LabelFallbackDistance
	end
	return range
end

local function addBox(box: Instance)
	if labels[box] then
		return
	end
	local entry: LabelEntry = { Box = box, Gui = nil, CheckedAt = -math.huge }
	labels[box] = entry
	labelOf(entry)
end

local function removeBox(box: Instance)
	labels[box] = nil
end

-- Modèle avec un Humanoid (joueur, vigile) qui contient `part`, ou nil.
local function characterOf(part: Instance): Instance?
	local current = part.Parent
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Rien ne cache `target` vu depuis `origin` (voir l'en-tête).
local function inView(origin: Vector3, target: Vector3): boolean
	local base: { Instance } = {}
	local character = localPlayer.Character
	if character then
		table.insert(base, character)
	end
	rayParams.FilterDescendantsInstances = base
	local tolerance = ShelfBoxes.LabelRayTolerance
	local from = origin
	for _ = 1, ShelfBoxes.LabelRayPasses do
		local offset = target - from
		if offset.Magnitude <= tolerance then
			return true
		end
		local result = Workspace:Raycast(from, offset, rayParams)
		if result == nil or (result.Position - target).Magnitude <= tolerance then
			return true
		end
		local hit = result.Instance
		local skip = characterOf(hit)
		if skip == nil and hit.Transparency >= ShelfBoxes.SeeThroughTransparency then
			skip = hit
		end
		if skip == nil then
			return false
		end
		rayParams:AddToFilter(skip)
		from = result.Position
	end
	return true -- trop de couches transparentes : l'étiquette reste visible
end

-- Liste des étiquettes à portée ; les autres sont coupées.
local function refreshNear(cameraPosition: Vector3)
	table.clear(near)
	for box, entry in labels do
		if box.Parent == nil then
			labels[box] = nil
			continue
		end
		local gui = labelOf(entry)
		if gui == nil then
			continue -- étiquette pas encore arrivée : revue au prochain tri
		end
		local position = positionOf(gui.Adornee or gui.Parent)
		if position and (position - cameraPosition).Magnitude <= rangeOf(gui) then
			table.insert(near, entry)
		elseif gui.Enabled then
			gui.Enabled = false
		end
	end
	if cursor > #near then
		cursor = 1
	end
end

-- Lance au plus LabelChecksPerFrame rayons, vers les étiquettes à portée pas revues depuis
-- LabelCheckInterval s, chacune à son tour.
local function checkLabels(now: number, cameraPosition: Vector3)
	local count = #near
	local budget = ShelfBoxes.LabelChecksPerFrame
	local scanned = 0
	while budget > 0 and scanned < count do
		if cursor > count then
			cursor = 1
		end
		local entry = near[cursor]
		cursor += 1
		scanned += 1
		if labels[entry.Box] ~= entry or now - entry.CheckedAt < ShelfBoxes.LabelCheckInterval then
			continue
		end
		entry.CheckedAt = now
		budget -= 1
		local gui = entry.Gui
		if gui == nil or not gui:IsDescendantOf(entry.Box) then
			continue
		end
		local position = positionOf(gui.Adornee or gui.Parent)
		local visible = position ~= nil and inView(cameraPosition, position)
		if gui.Enabled ~= visible then
			gui.Enabled = visible
		end
	end
end

local function step(deltaTime: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local cameraPosition = camera.CFrame.Position
	sinceRefresh += deltaTime
	if sinceRefresh >= ShelfBoxes.RefreshInterval then
		sinceRefresh = 0
		refreshOutlines(cameraPosition)
		refreshNear(cameraPosition)
	end
	checkLabels(os.clock(), cameraPosition)
end

-- API -----------------------------------------------------------------------------------------

function ShelfBoxController.GetStats(): Stats
	local stats: Stats = { Outlines = 0, ActiveOutlines = 0, Labels = 0, NearLabels = #near, VisibleLabels = 0 }
	for highlight in outlines do
		stats.Outlines += 1
		if highlight.Enabled then
			stats.ActiveOutlines += 1
		end
	end
	for _, entry in labels do
		stats.Labels += 1
		local gui = entry.Gui
		if gui and gui.Enabled then
			stats.VisibleLabels += 1
		end
	end
	return stats
end

function ShelfBoxController.Start()
	Workspace.DescendantAdded:Connect(trackOutline)
	for _, descendant in Workspace:GetDescendants() do
		trackOutline(descendant)
	end
	-- Avec StreamingEnabled, les colis arrivent et repartent avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(SHELF_BOX_TAG):Connect(addBox)
	CollectionService:GetInstanceRemovedSignal(SHELF_BOX_TAG):Connect(removeBox)
	for _, box in CollectionService:GetTagged(SHELF_BOX_TAG) do
		addBox(box)
	end
	if IS_STUDIO then
		local stats = ShelfBoxController.GetStats()
		print(
			`[ShelfBoxController] {stats.Outlines} contour(s) suivi(s), {ShelfBoxes.MaxOutlines} au plus actifs ; {stats.Labels} étiquette(s) de rayon, montrées en vue seulement`
		)
	end
	local function onError(err: any)
		if os.clock() - lastError >= ERROR_INTERVAL then
			lastError = os.clock() -- une ligne toutes les 10 s au plus, pas une par image
			warn(`[ShelfBoxController] {err}`)
		end
	end
	RunService.Heartbeat:Connect(function(deltaTime: number)
		xpcall(step, onError, deltaTime)
	end)
end

return ShelfBoxController
