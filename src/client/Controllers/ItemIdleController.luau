--!strict
-- ItemIdleController (DEV-020, client) : animation idle des objets exposés (liaison L-045 :
-- proposition de Clément, validée par Ironix le 2026-11-07 ; pièces Wave_ : L-055). Aucun script
-- dans les modèles : tout se joue ici, en local. Rien n'est envoyé au serveur ; chaque joueur anime
-- chez lui les objets qu'il voit.
--
-- Ce qui bouge (contrat : Contract/Attributes.Idle, Contract/Models.Item.SpinPrefix et WavePrefix) :
--   - l'attribut Idle du modèle ITM_ de Clément, gardé sur l'objet exposé (copie faite par
--     DisplayService) :
--       Spin     le modèle tourne sur l'axe Y de son pivot (en bas au centre, sur le présentoir) ;
--       Bob      il monte puis redescend doucement, sans passer sous sa position de repos ;
--       SpinBob  les deux ;
--     absent : immobile ; une autre valeur est ignorée (le ContractChecker la signale) ;
--   - les pièces Spin_<Nom> (BasePart ou Model) tournent sans fin autour de l'axe Y de leur pivot
--     (GetPivot, PivotOffset compris : c'est là que Clément règle l'axe), que le modèle ait
--     l'attribut Idle ou non ;
--   - les pièces Wave_<Nom> (BasePart ou Model) font un va-et-vient autour de l'axe Y de leur
--     pivot, de part et d'autre de leur pose de départ (sinus, Config/ItemIdle.WaveAmplitude et
--     WavePeriod), avec ou sans Idle : la patte du Chat porte-bonheur doré (Wave_Paw et
--     Wave_PawPads, même pivot, à l'épaule, orienté gauche-droite). Toutes les pièces Wave_ d'un
--     objet reçoivent le même angle au même instant.
--   Une pièce Spin_ ou Wave_ rangée dans une autre bouge sur elle-même et avec elle.
-- Ce qui reste fixe : le halo de rareté (pièce RarityHalo, que DisplayController anime) et le
-- billboard BB_Item, posés par DisplayService : le point d'accroche du billboard (BillboardPoint,
-- dans Root) est recalé à sa place de repos à chaque image.
--
-- Objets suivis : les objets exposés, Models taggés DisplayItem par DisplayService (rangés dans les
-- parcelles, ModelStreamingMode Atomic : ils arrivent en entier avec le streaming). Un objet sans
-- Idle ni pièce Spin_ ou Wave_ (la plupart) n'est pas suivi. Les objets portés ne sont pas animés :
-- l'objet volé à un joueur (6.1) est soudé à la tête, et déplacer une de ses pièces déplacerait le
-- personnage.
--
-- Position de repos d'une pièce : celle qu'elle a en arrivant chez le client (le serveur ne déplace
-- jamais un objet exposé : il le détruit et en crée un autre). À chaque image, chaque pièce est
-- replacée depuis sa position de repos, l'angle calculé depuis l'instant (jamais ajouté image après
-- image) : aucune dérive, et une pièce Wave_ repasse exactement par sa pose de départ. Plus loin de
-- la caméra que Config/ItemIdle.MaxDistance, l'objet reprend sa position de repos et n'est plus
-- animé. Chaque objet a son propre décalage dans le temps, tiré de sa position : deux objets voisins
-- ne bougent pas d'un même bloc.
--
-- Réglages : Config/ItemIdle (V0, à faire valider par Clément).
--
-- API (client) :
--   ItemIdleController.ModelMotion(mode, t) -> (angle, hauteur)
--       Mouvement du modèle entier à l'instant t (secondes) pour une valeur d'Idle : rotation
--       autour de l'axe Y du pivot (radians, de 0 à 2π) et hauteur au-dessus du repos (studs).
--   ItemIdleController.PieceAngle(t) -> number
--       Rotation d'une pièce Spin_ autour de l'axe Y de son pivot à l'instant t (radians, de 0 à 2π).
--   ItemIdleController.WaveAngle(t) -> number
--       Angle d'une pièce Wave_ autour de l'axe Y de son pivot à l'instant t, depuis sa pose de
--       départ (radians, de −WaveAmplitude à +WaveAmplitude ; 0 à t = 0).
--   ItemIdleController.GetStats() -> { Tracked: number, Animated: number }
--       Objets suivis et objets animés en ce moment (à portée de la caméra), pour les tests.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemIdle = require(Shared:WaitForChild("Config"):WaitForChild("ItemIdle"))
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))
local Models = require(Shared:WaitForChild("Contract"):WaitForChild("Models"))

-- Posés par DisplayService (mêmes noms là-bas).
local DISPLAY_TAG = "DisplayItem"
local HALO_PART = "RarityHalo"
local BILLBOARD_POINT = "BillboardPoint"

local IDLE_ATTRIBUTE: string = Attributes.Idle.Name
local SPIN_PREFIX: string = Models.Item.SpinPrefix or "Spin_"
local WAVE_PREFIX: string = Models.Item.WavePrefix or "Wave_"
local TAU = 2 * math.pi
local WAVE_AMPLITUDE = math.rad(ItemIdle.WaveAmplitude)
-- Décalage dans le temps d'un objet : de 0 à PHASE_SPAN secondes, tiré de sa position.
local PHASE_SPAN = 10

local MODES: { [string]: boolean } = {}
for _, value in Attributes.Idle.Values do
	MODES[value] = true
end

-- Pièce mobile, Spin_ (rotation sans fin) ou Wave_ (va-et-vient) autour de l'axe Y de son pivot :
-- son mouvement, et celui des pièces qui la contiennent.
type Piece = {
	wave: boolean, -- Wave_, sinon Spin_
	pivot: CFrame, -- au repos : pivot de la pièce (GetPivot : PivotOffset d'une BasePart compris)
	pivotInverse: CFrame,
	parent: Piece?, -- pièce mobile qui la contient
	current: CFrame, -- déplacement de l'image en cours, dans le repère du monde
}

type PartEntry = {
	part: BasePart,
	rest: CFrame,
	piece: Piece?, -- pièce mobile la plus proche qui la contient (ou elle-même)
}

-- Point d'accroche du billboard de DisplayService, gardé à sa place de repos.
type PointEntry = {
	attachment: Attachment,
	holder: BasePart,
	restLocal: CFrame,
	restWorld: CFrame,
}

type Entry = {
	model: Model,
	pivot: CFrame, -- pivot du modèle au repos
	pivotInverse: CFrame,
	mode: string?, -- valeur d'Idle reconnue, ou nil
	phase: number,
	parts: { PartEntry },
	pieces: { Piece }, -- les pièces contenantes avant les pièces contenues
	points: { PointEntry },
	active: boolean, -- à portée de la caméra : animé
	moved: boolean, -- des pièces sont hors de leur position de repos
	dirty: boolean, -- pièces ajoutées ou retirées : à reconstruire
	connections: { RBXScriptConnection },
}

local ItemIdleController = {}

local entries: { [Model]: Entry } = {}
local clock = 0
local sinceCheck = math.huge

------------------------------------------------------------------------------
-- Calcul (sans Roblox, sauf CFrame)
------------------------------------------------------------------------------

function ItemIdleController.ModelMotion(mode: string?, t: number): (number, number)
	local angle = 0
	local height = 0
	if mode == "Spin" or mode == "SpinBob" then
		angle = (t * ItemIdle.SpinTurnsPerSecond % 1) * TAU
	end
	if mode == "Bob" or mode == "SpinBob" then
		height = ItemIdle.BobHeight * (1 - math.cos(TAU * t / ItemIdle.BobPeriod)) / 2
	end
	return angle, height
end

function ItemIdleController.PieceAngle(t: number): number
	return (t * ItemIdle.PieceTurnsPerSecond % 1) * TAU
end

-- Sinus d'une période ramenée à [0, 1[ : l'angle ne dépend que de l'instant, jamais des images
-- d'avant, et reste précis même après des heures (t grandit, la fraction de période non).
function ItemIdleController.WaveAngle(t: number): number
	return WAVE_AMPLITUDE * math.sin((t / ItemIdle.WavePeriod % 1) * TAU)
end

------------------------------------------------------------------------------
-- Objets suivis
------------------------------------------------------------------------------

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- "Spin" ou "Wave" pour une pièce mobile (BasePart ou Model nommé Spin_… ou Wave_…), sinon nil.
local function pieceKind(inst: Instance): string?
	if not (inst:IsA("BasePart") or inst:IsA("Model")) then
		return nil
	end
	if startsWith(inst.Name, SPIN_PREFIX) then
		return "Spin"
	elseif startsWith(inst.Name, WAVE_PREFIX) then
		return "Wave"
	end
	return nil
end

-- Le halo de DisplayService (et ce qu'il contient) ne bouge pas.
local function inHalo(inst: Instance, model: Model): boolean
	local current: Instance? = inst
	while current ~= nil and current ~= model do
		if current.Name == HALO_PART and current.Parent == model then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Nombre de pièces mobiles (Spin_, Wave_) au-dessus de `inst` dans le modèle.
local function pieceDepth(inst: Instance, model: Model): number
	local depth = 0
	local current = inst.Parent
	while current ~= nil and current ~= model do
		if pieceKind(current) ~= nil then
			depth += 1
		end
		current = current.Parent
	end
	return depth
end

-- Pièce mobile la plus proche qui contient `inst` (lui compris), parmi celles déjà connues.
local function pieceOf(inst: Instance?, model: Model, known: { [Instance]: Piece }): Piece?
	local current = inst
	while current ~= nil and current ~= model do
		local piece = known[current]
		if piece then
			return piece
		end
		current = current.Parent
	end
	return nil
end

-- Lit le modèle au repos. nil s'il n'a rien à animer (ni Idle reconnu ni pièce Spin_ ou Wave_).
local function build(model: Model): Entry?
	local raw = model:GetAttribute(IDLE_ATTRIBUTE)
	local mode: string? = if type(raw) == "string" and MODES[raw] then raw else nil
	local descendants = model:GetDescendants()

	local movers: { Instance } = {}
	local waves: { [Instance]: boolean } = {}
	local depths: { [Instance]: number } = {}
	for _, descendant in descendants do
		local kind = pieceKind(descendant)
		if kind ~= nil and not inHalo(descendant, model) then
			table.insert(movers, descendant)
			waves[descendant] = kind == "Wave"
			depths[descendant] = pieceDepth(descendant, model)
		end
	end
	if mode == nil and #movers == 0 then
		return nil
	end
	table.sort(movers, function(a: Instance, b: Instance): boolean
		return depths[a] < depths[b]
	end)

	local piecesOf: { [Instance]: Piece } = {}
	local pieces: { Piece } = {}
	for _, mover in movers do
		-- Le pivot, pas le centre : pour une BasePart, CFrame × PivotOffset (formule de Clément,
		-- part:GetPivot()).
		local pivot = (mover :: PVInstance):GetPivot()
		local piece: Piece = {
			wave = waves[mover] == true,
			pivot = pivot,
			pivotInverse = pivot:Inverse(),
			parent = pieceOf(mover.Parent, model, piecesOf),
			current = CFrame.identity,
		}
		piecesOf[mover] = piece
		table.insert(pieces, piece)
	end

	-- Sans Idle, seules les pièces mobiles (et ce qu'elles contiennent) bougent : les autres ne sont
	-- pas réécrites.
	local parts: { PartEntry } = {}
	local points: { PointEntry } = {}
	for _, descendant in descendants do
		local piece = pieceOf(descendant, model, piecesOf)
		if descendant:IsA("BasePart") and not inHalo(descendant, model) and (mode ~= nil or piece ~= nil) then
			local part = descendant :: BasePart
			table.insert(parts, { part = part, rest = part.CFrame, piece = piece })
			for _, child in part:GetChildren() do
				if child.Name == BILLBOARD_POINT and child:IsA("Attachment") then
					local attachment = child :: Attachment
					table.insert(points, {
						attachment = attachment,
						holder = part,
						restLocal = attachment.CFrame,
						restWorld = part.CFrame * attachment.CFrame,
					})
				end
			end
		end
	end

	local pivot = model:GetPivot()
	local position = pivot.Position
	return {
		model = model,
		pivot = pivot,
		pivotInverse = pivot:Inverse(),
		mode = mode,
		phase = (position.X * 0.37 + position.Z * 0.61) % PHASE_SPAN,
		parts = parts,
		pieces = pieces,
		points = points,
		active = false,
		moved = false,
		dirty = false,
		connections = {},
	}
end

-- Replace toutes les pièces à l'instant t.
local function apply(entry: Entry, t: number)
	local time = t + entry.phase
	local angle, height = ItemIdleController.ModelMotion(entry.mode, time)
	local whole = CFrame.identity
	if angle ~= 0 or height ~= 0 then
		whole = entry.pivot * CFrame.new(0, height, 0) * CFrame.Angles(0, angle, 0) * entry.pivotInverse
	end
	-- Même angle pour toutes les pièces d'une sorte : celles de la patte bougent d'un bloc.
	local spinTurn = CFrame.Angles(0, ItemIdleController.PieceAngle(time), 0)
	local waveTurn = CFrame.Angles(0, ItemIdleController.WaveAngle(time), 0)
	for _, piece in entry.pieces do
		local base = if piece.parent then piece.parent.current else whole
		local turn = if piece.wave then waveTurn else spinTurn
		piece.current = base * piece.pivot * turn * piece.pivotInverse
	end
	for _, entryPart in entry.parts do
		local piece = entryPart.piece
		local move = if piece then piece.current else whole
		entryPart.part.CFrame = move * entryPart.rest
	end
	for _, point in entry.points do
		point.attachment.CFrame = point.holder.CFrame:ToObjectSpace(point.restWorld)
	end
	entry.moved = true
end

local function restore(entry: Entry)
	for _, entryPart in entry.parts do
		entryPart.part.CFrame = entryPart.rest
	end
	for _, point in entry.points do
		point.attachment.CFrame = point.restLocal
	end
	entry.moved = false
end

local function isNear(entry: Entry, eye: Vector3?): boolean
	return eye ~= nil and (entry.pivot.Position - eye).Magnitude <= ItemIdle.MaxDistance
end

local function eyePosition(): Vector3?
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

local function untrack(model: Model)
	local entry = entries[model]
	if entry == nil then
		return
	end
	entries[model] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	if entry.moved then
		restore(entry)
	end
end

-- Une pièce, une pièce mobile (Spin_, Wave_) ou le point du billboard qui arrive ou repart change
-- ce qu'il faut animer : le modèle est relu à l'image suivante, depuis sa position de repos.
local function matters(inst: Instance): boolean
	return inst:IsA("BasePart") or pieceKind(inst) ~= nil or inst.Name == BILLBOARD_POINT
end

local function track(inst: Instance)
	if not inst:IsA("Model") or entries[inst :: Model] ~= nil then
		return
	end
	local model = inst :: Model
	local built = build(model)
	if built == nil then
		return
	end
	local entry: Entry = built
	local function markDirty(descendant: Instance)
		if matters(descendant) then
			entry.dirty = true
		end
	end
	table.insert(entry.connections, model.DescendantAdded:Connect(markDirty))
	table.insert(entry.connections, model.DescendantRemoving:Connect(markDirty))
	entry.active = isNear(entry, eyePosition())
	entries[model] = entry
end

local function rebuild(entry: Entry)
	local model = entry.model
	untrack(model) -- remet les pièces au repos avant de les relire
	if CollectionService:HasTag(model, DISPLAY_TAG) and model:IsDescendantOf(Workspace) then
		track(model)
	end
end

local function refreshDistances()
	local eye = eyePosition()
	for _, entry in entries do
		local near = isNear(entry, eye)
		if not near and entry.moved then
			restore(entry)
		end
		entry.active = near
	end
end

local function onHeartbeat(dt: number)
	clock += dt
	sinceCheck += dt
	if sinceCheck >= ItemIdle.DistanceCheckInterval then
		sinceCheck = 0
		refreshDistances()
	end
	local dirty: { Entry }? = nil
	for _, entry in entries do
		if entry.dirty then
			local list = dirty or {}
			table.insert(list, entry)
			dirty = list
		end
	end
	if dirty then
		for _, entry in dirty do
			rebuild(entry)
		end
	end
	for _, entry in entries do
		if entry.active then
			apply(entry, clock)
		end
	end
end

function ItemIdleController.GetStats(): { Tracked: number, Animated: number }
	local tracked = 0
	local animated = 0
	for _, entry in entries do
		tracked += 1
		if entry.active then
			animated += 1
		end
	end
	return { Tracked = tracked, Animated = animated }
end

function ItemIdleController.Start()
	CollectionService:GetInstanceAddedSignal(DISPLAY_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(DISPLAY_TAG):Connect(function(inst: Instance)
		if inst:IsA("Model") then
			untrack(inst :: Model)
		end
	end)
	for _, inst in CollectionService:GetTagged(DISPLAY_TAG) do
		track(inst)
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return ItemIdleController
