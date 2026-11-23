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
-- Vague 39 (optimisation téléphone, audit docs/claude/notes/perf-telephone.md, correction 1) :
--   - toutes les pièces d'un objet sont déplacées d'un seul Workspace:BulkMoveTo par image (comme
--     ShatterController), au lieu d'une écriture de CFrame par pièce ;
--   - un objet hors de l'écran (Config/ItemIdle.OnScreenOnly, contrôlé avec la distance toutes les
--     DistanceCheckInterval s) n'est pas animé : il garde sa dernière pose, sans retour au repos ;
--   - au-delà de NearDistance (jusqu'à MaxDistance), il n'est replacé que toutes les FarInterval s.
-- De près et à l'écran, rien ne change : chaque image, même pose qu'avant.
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
--       Objets suivis et objets animés en ce moment (à portée de la caméra et à l'écran), pour les tests.
--
-- a317 (liaison L-304 point 3, Clément, 2026-11-23 ; prototype tools/clement/collect_motion_proto.luau ; valeurs :
-- Config/DisplayMotion, Enabled = true) : TOUS les objets exposés flottent, plus seulement ceux qui ont Idle ou des
-- pièces Spin_ / Wave_. Le mouvement est fait ici, où les pièces des objets exposés étaient déjà déplacées : deux
-- contrôleurs qui écriraient les mêmes pièces se battraient. Par objet :
--   - au repos, le bas de sa boîte (pièces visibles hors halo) à FloatGap au-dessus de son DisplaySlot_xx (son pivot
--     de repos), ±BobHeight en sinus de BobPeriod s, décalé de (DisplaySlot − 1) × PhaseStep rad ;
--   - ItemIdleController.Hop(model), appelé par DisplayController à l'encaissement de sa plaque (remote CashCollect,
--     chez tous les joueurs) : un tour autour de l'axe vertical au centre de sa boîte en SpinTime s (Quad Out) et Hops
--     sauts (HopHeight, puis × HopDecay) ;
--   - le halo de rareté (RarityHalo) et le point du billboard (BillboardPoint, donc BB_Item) suivent la hauteur, sans
--     tourner ; l'Idle et les pièces Spin_ / Wave_ de Clément se font par-dessus, comme avant ;
--   - plus loin que DisplayMotion.MaxDistance (au lieu d'ItemIdle.MaxDistance pour un objet qui flotte) : posé à
--     FloatGap, immobile ; hors de l'écran : figé, comme avant.
-- Tout reste local : le serveur ne déplace jamais l'objet (aucune physique, aucune propriété de collision changée).
-- En plus :
--   ItemIdleController.FloatMotion(t, phase, since?) -> (hauteur, angle)
--       Hauteur au-dessus de la pose flottante (flottement + saut, studs) et angle du tour (radians, 0 à 2π) à
--       l'instant t, `since` secondes après l'encaissement (nil : aucun).
--   ItemIdleController.Hop(model) -> boolean   tour et sauts de l'objet exposé `model` (false s'il n'est pas suivi).
--   ItemIdleController.WithRest(model, fn)     appelle fn() avec les pièces de `model` à leur place de repos (copie
--       de l'objet pour le socle « BEST ITEM », VfxController), puis les replace aussitôt.
--   ItemIdleController.GetPose(model) -> { Lift: number, Phase: number, Spinning: boolean }?   pour les tests.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemIdle = require(Shared:WaitForChild("Config"):WaitForChild("ItemIdle"))
-- a317 : facultatif (bancs plus anciens : sans lui, comme avant).
local motionModule = Shared:WaitForChild("Config"):FindFirstChild("DisplayMotion")
local DisplayMotion: any = if motionModule and motionModule:IsA("ModuleScript") then require(motionModule) :: any else nil
local FLOAT: boolean = DisplayMotion ~= nil and DisplayMotion.Enabled == true
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))
local Models = require(Shared:WaitForChild("Contract"):WaitForChild("Models"))

-- Posés par DisplayService (mêmes noms là-bas).
local DISPLAY_TAG = "DisplayItem"
local HALO_PART = "RarityHalo"
local BILLBOARD_POINT = "BillboardPoint"

local IDLE_ATTRIBUTE: string = Attributes.Idle.Name
local SLOT_ATTRIBUTE = "DisplaySlot" -- a317 : numéro du présentoir (DisplayService)
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
	halo: boolean, -- a317 : pièce du halo (RarityHalo) : suit seulement la hauteur du flottement
}

-- Point d'accroche du billboard de DisplayService, gardé à sa place de repos.
type PointEntry = {
	attachment: Attachment,
	holder: number, -- indice de sa pièce dans parts (et dans targets)
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
	partList: { BasePart }, -- les pièces de parts, dans le même ordre (BulkMoveTo)
	restList: { CFrame }, -- leurs CFrame de repos
	targets: { CFrame }, -- CFrame de l'image en cours (réutilisée d'une image à l'autre)
	pieces: { Piece }, -- les pièces contenantes avant les pièces contenues
	points: { PointEntry },
	center: Vector3, -- pivot du modèle au repos (test « à l'écran »)
	radius: number, -- rayon autour de center qui contient toutes les pièces animées
	active: boolean, -- à portée de la caméra et à l'écran : animé
	far: boolean, -- au-delà de NearDistance : replacé toutes les FarInterval s
	nextApply: number, -- loin : instant (clock) de la prochaine pose
	moved: boolean, -- des pièces sont hors de leur position de repos
	dirty: boolean, -- pièces ajoutées ou retirées : à reconstruire
	connections: { RBXScriptConnection },
	-- a317 (L-304 point 3) : flottement de tous les objets exposés (Config/DisplayMotion).
	float: boolean,
	lift: number, -- hauteur ajoutée au repos : bas de la boîte à FloatGap au-dessus du présentoir
	axis: CFrame, -- axe du tour : centre de la boîte en X et Z, à la hauteur du pivot
	axisInverse: CFrame,
	floatPhase: number, -- (DisplaySlot − 1) × PhaseStep
	collectAt: number?, -- clock de l'encaissement de sa plaque (tour et sauts en cours)
	parked: boolean, -- posé à la hauteur du flottement, immobile (au loin)
}

local ItemIdleController = {}

local entries: { [Model]: Entry } = {}
local clock = 0
local sinceCheck = math.huge
local anyDirty = false -- au moins un objet à reconstruire

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

-- a317 : flottement (sinus de BobPeriod, décalé de `phase` rad) et, `since` s après l'encaissement de la plaque, saut
-- (une parabole par saut, chacun HopDecay × le précédent) et tour (Quad Out) pendant SpinTime s : formules de
-- collect_motion_proto.luau. Sans Config/DisplayMotion : (0, 0).
function ItemIdleController.FloatMotion(t: number, phase: number, since: number?): (number, number)
	local spec = DisplayMotion
	if spec == nil then
		return 0, 0
	end
	local height = spec.BobHeight * math.sin((t / spec.BobPeriod % 1) * TAU + phase)
	local angle = 0
	if since ~= nil and since >= 0 and since < spec.SpinTime then
		local a = since / spec.SpinTime
		angle = (1 - (1 - a) * (1 - a)) * TAU
		local k = a * spec.Hops
		local which = math.floor(k)
		local f = k - which
		height += spec.HopHeight * (spec.HopDecay ^ which) * 4 * f * (1 - f)
	end
	return height, angle
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
	local float = FLOAT -- a317 : tous les objets exposés flottent
	if mode == nil and #movers == 0 and not float then
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
	local partList: { BasePart } = {}
	local restList: { CFrame } = {}
	local points: { PointEntry } = {}
	-- a317 : avec le flottement, toutes les pièces bougent, halo compris (il suit seulement la hauteur).
	local pivot = model:GetPivot()
	local minY: number, minX: number, maxX: number, minZ: number, maxZ: number = math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, descendant in descendants do
		local piece = pieceOf(descendant, model, piecesOf)
		local halo = inHalo(descendant, model)
		if descendant:IsA("BasePart") and (if halo then float else (float or mode ~= nil or piece ~= nil)) then
			local part = descendant :: BasePart
			if float and not halo and part.Transparency < 1 then
				-- Boîte des pièces visibles dans le repère du pivot (comme DisplayService.fitFactor).
				local half = part.Size / 2
				for sx = -1, 1, 2 do
					for sy = -1, 1, 2 do
						for sz = -1, 1, 2 do
							local p = pivot:PointToObjectSpace(part.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
							minY = math.min(minY, p.Y)
							minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
							minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
						end
					end
				end
			end
			table.insert(parts, { part = part, rest = part.CFrame, piece = if halo then nil else piece, halo = halo })
			table.insert(partList, part)
			table.insert(restList, part.CFrame)
			for _, child in part:GetChildren() do
				if child.Name == BILLBOARD_POINT and child:IsA("Attachment") then
					local attachment = child :: Attachment
					table.insert(points, {
						attachment = attachment,
						holder = #parts,
						restLocal = attachment.CFrame,
						restWorld = part.CFrame * attachment.CFrame,
					})
				end
			end
		end
	end

	local position = pivot.Position
	-- Rayon des pièces animées autour du pivot (une pièce Spin_ ou Wave_ tourne autour d'un pivot du
	-- modèle : elle reste dans cette sphère, à BobHeight près ; a317 : et au flottement près).
	local extra = ItemIdle.BobHeight + (if float then DisplayMotion.Headroom else 0)
	local radius = extra
	for _, part in partList do
		radius = math.max(radius, (part.Position - position).Magnitude + part.Size.Magnitude / 2 + extra)
	end
	-- a317 : pose flottante (aucune pièce visible : le pivot sert de bas de boîte et d'axe).
	local seenBox = minY < math.huge
	local lift = if float then DisplayMotion.FloatGap - (if seenBox then minY else 0) else 0
	local axis = if seenBox then pivot * CFrame.new(((minX :: number) + (maxX :: number)) / 2, 0, ((minZ :: number) + (maxZ :: number)) / 2) else pivot
	local slot = model:GetAttribute(SLOT_ATTRIBUTE)
	local floatPhase = if float and type(slot) == "number" and slot == slot then (slot - 1) * DisplayMotion.PhaseStep else 0
	local targets: { CFrame } = table.clone(restList) -- même taille, réécrite à chaque pose
	return {
		model = model,
		pivot = pivot,
		pivotInverse = pivot:Inverse(),
		mode = mode,
		phase = (position.X * 0.37 + position.Z * 0.61) % PHASE_SPAN,
		parts = parts,
		partList = partList,
		restList = restList,
		targets = targets,
		pieces = pieces,
		points = points,
		center = position,
		radius = radius,
		active = false,
		far = false,
		nextApply = 0,
		moved = false,
		dirty = false,
		connections = {},
		float = float,
		lift = lift,
		axis = axis,
		axisInverse = axis:Inverse(),
		floatPhase = floatPhase,
		collectAt = nil,
		parked = false,
	}
end

-- Replace toutes les pièces à l'instant t. a317 : `still` : pose immobile (flottement à sa hauteur de repos, Idle et
-- pièces Spin_ / Wave_ à leur pose de départ), pour un objet au loin.
local function apply(entry: Entry, t: number, still: boolean?)
	local time = t + entry.phase
	local angle, height = 0, 0
	if not still then
		angle, height = ItemIdleController.ModelMotion(entry.mode, time)
	end
	local whole = CFrame.identity
	if angle ~= 0 or height ~= 0 then
		whole = entry.pivot * CFrame.new(0, height, 0) * CFrame.Angles(0, angle, 0) * entry.pivotInverse
	end
	-- a317 : flottement, tour et sauts, par-dessus l'Idle ; `shift` (hauteur seule) pour le halo et le billboard.
	local shift = CFrame.identity
	if entry.float then
		local rise, spin = entry.lift, 0
		if not still then
			local at = entry.collectAt
			local since = if at then t - at else nil
			if since and since >= DisplayMotion.SpinTime then
				entry.collectAt = nil
				since = nil
			end
			local h, a = ItemIdleController.FloatMotion(t, entry.floatPhase, since)
			rise += h
			spin = a
		end
		shift = CFrame.new(0, rise, 0)
		local floated = if spin ~= 0 then shift * entry.axis * CFrame.Angles(0, spin, 0) * entry.axisInverse else shift
		whole = floated * whole
	end
	-- Même angle pour toutes les pièces d'une sorte : celles de la patte bougent d'un bloc.
	local spinTurn = if still then CFrame.identity else CFrame.Angles(0, ItemIdleController.PieceAngle(time), 0)
	local waveTurn = if still then CFrame.identity else CFrame.Angles(0, ItemIdleController.WaveAngle(time), 0)
	for _, piece in entry.pieces do
		local base = if piece.parent then piece.parent.current else whole
		local turn = if piece.wave then waveTurn else spinTurn
		piece.current = base * piece.pivot * turn * piece.pivotInverse
	end
	local targets = entry.targets
	for index, entryPart in entry.parts do
		local piece = entryPart.piece
		local move = if entryPart.halo then shift elseif piece then piece.current else whole
		targets[index] = move * entryPart.rest
	end
	-- Vague 39 : toutes les pièces d'un coup (une écriture de CFrame par pièce coûtait le plus cher).
	Workspace:BulkMoveTo(entry.partList, targets, Enum.BulkMoveMode.FireCFrameChanged)
	for _, point in entry.points do
		point.attachment.CFrame = targets[point.holder]:ToObjectSpace(shift * point.restWorld)
	end
	entry.moved = true
	entry.parked = still == true
end

local function restore(entry: Entry)
	Workspace:BulkMoveTo(entry.partList, entry.restList, Enum.BulkMoveMode.FireCFrameChanged)
	for _, point in entry.points do
		point.attachment.CFrame = point.restLocal
	end
	entry.moved = false
	entry.parked = false
end

-- Vague 39 : la sphère de l'objet (center, radius + ScreenMargin) coupe le champ de la caméra.
-- Test des quatre côtés du champ, dans le repère de la caméra (elle regarde vers −Z).
local function isOnScreen(entry: Entry, camera: Camera): boolean
	if not ItemIdle.OnScreenOnly then
		return true
	end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return true -- fenêtre pas encore dimensionnée : comme avant
	end
	local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
	local tanH = tanV * viewport.X / viewport.Y
	local inCamera = camera.CFrame:PointToObjectSpace(entry.center)
	local depth = -inCamera.Z
	local radius = entry.radius + ItemIdle.ScreenMargin
	if depth < -radius then
		return false -- derrière la caméra
	end
	-- Distance au plan d'un côté : |x| − profondeur × tan ≤ rayon × √(1 + tan²).
	return math.abs(inCamera.X) <= depth * tanH + radius * math.sqrt(1 + tanH * tanH)
		and math.abs(inCamera.Y) <= depth * tanV + radius * math.sqrt(1 + tanV * tanV)
end

-- Distance et écran : `active` (animé), `far` (cadence réduite) ; repos au-delà de MaxDistance.
local function evaluate(entry: Entry, camera: Camera?)
	local distance = if camera then (entry.center - camera.CFrame.Position).Magnitude else math.huge
	-- a317 : un objet qui flotte est animé jusqu'à DisplayMotion.MaxDistance (au moins ItemIdle.MaxDistance), puis
	-- posé à la hauteur de son flottement, immobile (pas redescendu sur le présentoir).
	local limit = if entry.float then math.max(ItemIdle.MaxDistance, DisplayMotion.MaxDistance) else ItemIdle.MaxDistance
	local near = distance <= limit
	if not near then
		if entry.float then
			if not entry.parked then
				apply(entry, clock, true)
			end
		elseif entry.moved then
			restore(entry)
		end
	end
	local far = distance > ItemIdle.NearDistance
	if far and not entry.far then
		-- Décalé selon l'objet : les objets lointains ne sont pas tous replacés à la même image.
		local interval = ItemIdle.FarInterval
		entry.nextApply = clock + (if interval > 0 then entry.phase % interval else 0)
	end
	entry.far = far
	entry.active = near and camera ~= nil and isOnScreen(entry, camera)
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
			anyDirty = true
		end
	end
	table.insert(entry.connections, model.DescendantAdded:Connect(markDirty))
	table.insert(entry.connections, model.DescendantRemoving:Connect(markDirty))
	evaluate(entry, Workspace.CurrentCamera)
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
	local camera = Workspace.CurrentCamera
	for _, entry in entries do
		evaluate(entry, camera)
	end
end

local function onHeartbeat(dt: number)
	clock += dt
	sinceCheck += dt
	if sinceCheck >= ItemIdle.DistanceCheckInterval then
		sinceCheck = 0
		refreshDistances()
	end
	if anyDirty then
		anyDirty = false
		local dirty: { Entry } = {}
		for _, entry in entries do
			if entry.dirty then
				table.insert(dirty, entry)
			end
		end
		for _, entry in dirty do
			rebuild(entry)
		end
	end
	local farInterval = ItemIdle.FarInterval
	for _, entry in entries do
		if entry.active then
			if entry.far then
				if clock < entry.nextApply then
					continue
				end
				entry.nextApply = clock + farInterval
			end
			apply(entry, clock)
		end
	end
end

-- a317 : tour et sauts de l'objet exposé `model` à l'encaissement de sa plaque (DisplayController).
function ItemIdleController.Hop(model: Instance): boolean
	local entry = if model:IsA("Model") then entries[model :: Model] else nil
	if entry == nil or not entry.float then
		return false
	end
	entry.collectAt = clock
	return true
end

-- a317 : `fn` voit les pièces de `model` à leur place de repos (une copie faite là n'emporte ni le flottement ni le
-- tour) ; elles sont replacées aussitôt, dans la même image.
function ItemIdleController.WithRest(model: Instance, fn: () -> ())
	local entry = if model:IsA("Model") then entries[model :: Model] else nil
	if entry == nil or not entry.moved then
		fn()
		return
	end
	local parked = entry.parked
	restore(entry)
	local ok, err = pcall(fn :: any)
	apply(entry, clock, parked)
	if not ok then
		error(err, 0)
	end
end

function ItemIdleController.GetPose(model: Instance): { Lift: number, Phase: number, Spinning: boolean }?
	local entry = if model:IsA("Model") then entries[model :: Model] else nil
	if entry == nil then
		return nil
	end
	return { Lift = entry.lift, Phase = entry.floatPhase, Spinning = entry.collectAt ~= nil }
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
