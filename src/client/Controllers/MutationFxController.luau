--!strict
-- MutationFxController (client, liaison L-127 point 5, a119) : le design des mutations de Clément, joué en
-- local, sans rien envoyer au serveur. Les tailles ne font que l'échelle (DisplayService), comme avant.
--
-- 1. Texte (Assets/UI/MutationStyles/<Id>, Folder ; Id = l'effet, ou « Size » pour une taille seule) :
--    - étiquette MutationTag des cartes de l'inventaire (StyleTag, appelé par InventoryController) : son
--      UIGradient est éteint (Enabled = false) et remplacé par une copie de TagGradient (MutationGradient),
--      MutationLabel prend LabelColor, les UIStroke de l'étiquette et du texte prennent StrokeColor ;
--    - ligne Mutation de BB_Item (et de BB_Carry si Clément l'ajoute) (StyleText) : copie de TextGradient,
--      texte blanc (pour que la couleur se voie), UIStroke à StrokeColor. Les billboards des objets suivis
--      (ci-dessous) sont faits ici ; celui que ShelfOpenController copie dans le PlayerGui, par lui.
--    Mouvement (attributs Motion, MotionPeriod en s ; Config/MutationFx) : Shine (Offset X du dégradé de −1
--    à 1 en ShineTime s, toutes les MotionPeriod s), Pulse (transparence des contours 0 ↔ 0,4), Glitch
--    (Offset X saute de ±0,3 pendant 0,08 s, toutes les 0,5 à 1,2 × MotionPeriod s), Scan (Offset Y de −1
--    à 1 en MotionPeriod s, en boucle), Spin (Rotation + 360° en MotionPeriod s), None. Joué seulement
--    quand l'écran (ou le billboard) est allumé et, pour un billboard d'objet, l'objet proche.
--    Sans mutation : tout est remis comme avant (dégradés rallumés, couleurs d'origine).
-- 2. Objets : les modèles taggés DisplayItem (exposés, DisplayService), FloorItem (au sol, sous antivol),
--    ShelfItem (sortis sur le rayon, StoreHeistService) et CarriedItem (portés et lâchés, CarryService),
--    avec l'attribut MutationEffect, reçoivent Assets/FX/Mutations/FX_Mutation_<Id>, comme apply() et
--    update() de tools/clement/mutations_proto.luau : ColorMode (Keep, Shade, Saturate), Material,
--    Reflectance (−1 = gardée) ; Emitters dans une pièce invisible MutationFX à la taille de la boîte
--    (× EmitterBoxScale ; tailles, vitesses et accélérations × plus grand côté / ReferenceSize) ; Ghosts :
--    une copie de l'objet par entrée (MutationGhost_NN : ForceField décalée, qui tremble ; MutationGlow_NN :
--    coque de néon, KeepColor = la couleur de la pièce de l'objet) ; PointLight de la couleur moyenne si
--    LightBrightness > 0 ; Extras.RainbowArc derrière l'objet ; mouvements Rainbow, Pulse, Glitch.
--    Différences avec l'aperçu de Clément, pour le jeu :
--    - ce que l'effet ajoute (MutationFX, doubles, arc) est rangé dans Workspace/_MutationFX (dossier local,
--      jamais répliqué), pas dans le modèle : la boîte de l'objet, que lisent les autres contrôleurs (BB_Item
--      de ShelfOpenController, chaînes de l'antivol), ne change pas ; le tout suit l'objet (porté, qui
--      tourne avec ItemIdleController : chaque double suit sa pièce) ;
--    - les copies sont vidées de leurs tags, attributs, scripts, invites et billboards, ancrées, sans
--      collision ni requête : elles ne déclenchent rien et le serveur n'en sait rien ;
--    - le saut de Glitch ne déplace que les pièces visibles ancrées de l'objet, remises exactement à leur
--      place au bout de 0,12 s, et jamais sur un objet porté ou animé (Idle, pièces Spin_ / Wave_) ;
--    - jamais touchés : les pièces invisibles (Root…), le halo de rareté (RarityHalo, HaloPoint), les
--      chaînes de l'antivol (AntiTheftChains), les billboards ;
--    - l'objet n'est habillé qu'à échelle stable (Config/MutationFx.SettleChecks : la révélation du rayon
--      le fait grandir) et rhabillé si ses pièces ou ses attributs changent ;
--    - plus loin de la caméra que MaxDistance : couleurs et matière gardées (posées une fois), mais
--      particules, lumière, doubles et arc retirés, rien d'animé ; tout est nettoyé (couleurs d'origine
--      remises) quand l'objet perd sa mutation ou disparaît.
--    FX_Mutation_<Id> absent : l'objet reste normal, un avertissement unique.
--
-- API (client) :
--   MutationFxController.StyleId(mutation) -> string?   Id du style : l'effet, sinon "Size", sinon nil
--   MutationFxController.StyleTag(tag, label?, mutation?)  étiquette de carte (nil : remise comme avant)
--   MutationFxController.StyleText(label, mutation?, gate?)  ligne de texte (gate : animer seulement si vrai)
--   MutationFxController.GetState(model) -> { Effect, Shown, Ghosts, Parts }?   pour les tests
--   MutationFxController.GetStats() -> { Tracked, Dressed, Shown, Texts }

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MutationFx = require(Config:WaitForChild("MutationFx"))
local Mutations = require(Config:WaitForChild("Mutations"))

-- Tags posés par le serveur (mêmes noms là-bas : DisplayService, UnboxService, ShelfOpenState.ItemTag,
-- CarryService).
local TRACKED_TAGS = { "DisplayItem", "FloorItem", "ShelfItem", "CarriedItem" }
local SIZE_ATTRIBUTE = "MutationSize"
local EFFECT_ATTRIBUTE = "MutationEffect"
-- Noms de Clément (L-127).
local STYLES_FOLDER = "MutationStyles" -- Assets/UI
local FX_FOLDER = "Mutations" -- Assets/FX
local FX_PREFIX = "FX_Mutation_"
local SIZE_STYLE = "Size"
local TAG_GRADIENT = "TagGradient"
local TEXT_GRADIENT = "TextGradient"
local MUTATION_FIELD = "Mutation"
local ITEM_LABELS: { [string]: boolean } = { BB_Item = true, BB_Carry = true }
-- Noms du code.
local OWN_GRADIENT = "MutationGradient"
local LOCAL_FOLDER = "_MutationFX"
local FX_PART = "MutationFX"
local LIGHT_NAME = "MutationLight"
-- Sous-arbres de l'objet jamais recolorés, déplacés ni copiés.
local SKIPPED: { [string]: boolean } = {
	RarityHalo = true, -- DisplayService
	HaloPoint = true, -- CarryService
	AntiTheftChains = true, -- chaînes de l'antivol (L-127 point 4)
	BillboardPoint = true,
}
-- Classes gardées dans une copie de l'objet (comme l'aperçu de Clément).
local KEPT_CLASSES = { "BasePart", "Model", "Folder", "Attachment", "SpecialMesh" }
local SPIN_PREFIX = "Spin_"
local WAVE_PREFIX = "Wave_"
local IDLE_ATTRIBUTE = "Idle"

local WHITE = Color3.new(1, 1, 1)
local TAU = 2 * math.pi
local JITTER_STEP = 0.05 -- s, Glitch : les doubles tremblent (aperçu de Clément)
local BURST_TIME = 0.12 -- s, Glitch : durée d'un saut (aperçu de Clément)
local IS_STUDIO = RunService:IsStudio()

type Motion = "None" | "Shine" | "Pulse" | "Glitch" | "Scan" | "Spin" | string

------------------------------------------------------------------------------
-- Types
------------------------------------------------------------------------------

type TextEntry = {
	holder: Instance,
	gradient: UIGradient,
	strokes: { UIStroke },
	motion: Motion,
	period: number,
	rotation: number,
	offset: Vector2,
	phase: number,
	nextAt: number,
	untilAt: number,
	jump: number,
	gate: (() -> boolean)?,
}

type SavedText = {
	key: string, -- style et dégradé posés (« Gold/TagGradient ») : rien à refaire s'ils ne changent pas
	target: Instance,
	label: TextLabel?,
	labelColor: Color3?,
	strokeColors: { [UIStroke]: Color3 },
	strokeTransparency: { [UIStroke]: number },
	disabled: { UIGradient },
}

type PartState = {
	part: BasePart,
	color: Color3, -- couleur posée par l'effet
	shade: number,
	h: number,
	s: number,
	v: number,
	origColor: Color3,
	origMaterial: Enum.Material,
	origReflectance: number,
}

type GhostPart = { part: BasePart, source: BasePart, rel: CFrame }

type Ghost = {
	model: Model,
	parts: { GhostPart },
	keepColor: boolean,
	transparency: number,
	offset: Vector3, -- en part de la boîte
	jitter: number, -- studs
	current: Vector3,
	flicker: boolean,
}

type Extra = { model: Model, rel: CFrame }

type Fx = {
	id: string,
	style: Instance,
	anchor: BasePart,
	boxRel: CFrame, -- boîte de l'objet dans le repère de l'ancre
	size: Vector3,
	maxSide: number,
	parts: { PartState },
	ghosts: { Ghost },
	holder: Model,
	fxPart: BasePart?,
	fxRel: CFrame,
	light: PointLight?,
	lightBrightness: number,
	extras: { Extra },
	motion: Motion,
	period: number,
	glitchJump: number,
	glitchSpread: number,
	moving: boolean, -- porté ou animé : les doubles sont replacés à chaque image
	canJump: boolean,
	lastAnchor: CFrame?,
	nextJitter: number,
	nextBurst: number,
	burstUntil: number,
	burstOffset: Vector3,
	bursting: boolean,
	jumped: { [BasePart]: CFrame }?,
	lastPaint: number,
	shown: boolean,
}

type Entry = {
	model: Model,
	connections: { RBXScriptConnection },
	dirty: boolean,
	labelsDirty: boolean,
	lastScale: number?,
	stable: number,
	missing: string?, -- effet dont le FX manque (pas de nouvel essai avant un changement)
	fx: Fx?,
	near: boolean,
	labels: { TextLabel },
}

local MutationFxController = {}

local entries: { [Model]: Entry } = {}
local texts: { [Instance]: TextEntry } = {}
local savedTexts: { [Instance]: SavedText } = {}
local warned: { [string]: boolean } = {}
local rng = Random.new()
local localFolder: Folder? = nil
local sinceCheck = math.huge
local lastTextPaint = -math.huge

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[MutationFxController] {message}`)
end

------------------------------------------------------------------------------
-- Assets de Clément
------------------------------------------------------------------------------

local function assetsChild(folderName: string, name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild(folderName) else nil
	return if folder then folder:FindFirstChild(name) else nil
end

local function styleFolder(id: string): Instance?
	local styles = assetsChild("UI", STYLES_FOLDER)
	if styles == nil then
		warnOnce("styles", `Assets/UI/{STYLES_FOLDER} absent : textes des mutations sans style`)
		return nil
	end
	local found = styles:FindFirstChild(id)
	if found == nil then
		warnOnce(`style:{id}`, `Assets/UI/{STYLES_FOLDER}/{id} absent : texte de la mutation sans style`)
	end
	return found
end

local function fxFolder(id: string): Instance?
	local root = assetsChild("FX", FX_FOLDER)
	if root == nil then
		warnOnce("fx", `Assets/FX/{FX_FOLDER} absent : objets mutés sans effet`)
		return nil
	end
	local found = root:FindFirstChild(FX_PREFIX .. id)
	if found == nil then
		warnOnce(`fx:{id}`, `Assets/FX/{FX_FOLDER}/{FX_PREFIX}{id} absent : objets {id} sans effet`)
	end
	return found
end

local function referenceSize(): number
	local root = assetsChild("FX", FX_FOLDER)
	local value = if root then root:GetAttribute("ReferenceSize") else nil
	return if type(value) == "number" and value > 0 then value else 2
end

local function numberAttribute(inst: Instance, name: string, default: number): number
	local value = inst:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function stringAttribute(inst: Instance, name: string, default: string): string
	local value = inst:GetAttribute(name)
	return if type(value) == "string" then value else default
end

local function colorAttribute(inst: Instance, name: string, default: Color3): Color3
	local value = inst:GetAttribute(name)
	return if typeof(value) == "Color3" then value :: Color3 else default
end

local function materialOf(name: string): Enum.Material?
	if name == "" then
		return nil
	end
	local ok, value = pcall(function(): any
		return (Enum.Material :: any)[name]
	end)
	if ok and value ~= nil then
		return value :: Enum.Material
	end
	warnOnce(`material:{name}`, `matière « {name} » inconnue (Enum.Material) : gardée`)
	return nil
end

------------------------------------------------------------------------------
-- Style d'une mutation
------------------------------------------------------------------------------

function MutationFxController.StyleId(mutation: any): string?
	local clean = Mutations.Sanitize(mutation)
	if clean == nil then
		return nil
	end
	if clean.Effect ~= nil then
		return clean.Effect
	end
	return if clean.Size ~= nil then SIZE_STYLE else nil
end

------------------------------------------------------------------------------
-- Texte : dégradé, couleurs, mouvement
------------------------------------------------------------------------------

local function strokesOf(inst: Instance?, list: { UIStroke })
	if inst == nil then
		return
	end
	for _, child in inst:GetChildren() do
		if child:IsA("UIStroke") then
			table.insert(list, child :: UIStroke)
		end
	end
end

-- Remet `holder` comme avant le style : dégradés de Clément rallumés, couleurs d'origine.
local function clearText(holder: Instance)
	texts[holder] = nil
	local saved = savedTexts[holder]
	if saved == nil then
		return
	end
	savedTexts[holder] = nil
	local own = saved.target:FindFirstChild(OWN_GRADIENT)
	if own then
		own:Destroy()
	end
	for _, gradient in saved.disabled do
		gradient.Enabled = true
	end
	local label = saved.label
	if label and saved.labelColor then
		label.TextColor3 = saved.labelColor :: Color3
	end
	for stroke, color in saved.strokeColors do
		stroke.Color = color
	end
	for stroke, transparency in saved.strokeTransparency do
		stroke.Transparency = transparency
	end
end

-- Pose le style `id` : `target` reçoit le dégradé `gradientName`, `label` la couleur `labelColor` (nil :
-- LabelColor du style), `strokes` StrokeColor. Renvoie false si le style manque (rien n'est changé).
local function applyText(
	holder: Instance,
	target: Instance,
	label: TextLabel?,
	strokeOwners: { Instance? },
	id: string,
	gradientName: string,
	textColor: Color3?,
	gate: (() -> boolean)?
): boolean
	local key = `{id}/{gradientName}`
	local previous = savedTexts[holder]
	if previous and previous.key == key and previous.target == target then
		local own = target:FindFirstChild(OWN_GRADIENT)
		if own and own:IsA("UIGradient") then
			local entry = texts[holder]
			if entry then
				entry.gate = gate
			end
			return true -- déjà posé (carte repeinte) : le mouvement continue
		end
	end
	clearText(holder)
	local style = styleFolder(id)
	if style == nil then
		return false
	end
	local template = style:FindFirstChild(gradientName)
	if template == nil or not template:IsA("UIGradient") then
		warnOnce(`gradient:{id}:{gradientName}`, `{STYLES_FOLDER}/{id}/{gradientName} absent (UIGradient) : texte sans style`)
		return false
	end
	local saved: SavedText = {
		key = key,
		target = target,
		label = label,
		labelColor = if label then label.TextColor3 else nil,
		strokeColors = {},
		strokeTransparency = {},
		disabled = {},
	}
	savedTexts[holder] = saved
	for _, child in target:GetChildren() do
		if child:IsA("UIGradient") and child.Name ~= OWN_GRADIENT and (child :: UIGradient).Enabled then
			(child :: UIGradient).Enabled = false
			table.insert(saved.disabled, child :: UIGradient)
		end
	end
	local gradient = template:Clone() :: UIGradient
	gradient.Name = OWN_GRADIENT
	gradient.Enabled = true
	gradient.Parent = target
	if label then
		label.TextColor3 = textColor or colorAttribute(style, "LabelColor", WHITE)
	end
	local strokes: { UIStroke } = {}
	for _, owner in strokeOwners do
		strokesOf(owner, strokes)
	end
	local strokeColor = style:GetAttribute("StrokeColor")
	for _, stroke in strokes do
		saved.strokeColors[stroke] = stroke.Color
		saved.strokeTransparency[stroke] = stroke.Transparency
		if typeof(strokeColor) == "Color3" then
			stroke.Color = strokeColor :: Color3
		end
	end
	local motion = stringAttribute(style, "Motion", "None")
	local period = numberAttribute(style, "MotionPeriod", 0)
	if motion ~= "None" and period > 0 then
		texts[holder] = {
			holder = holder,
			gradient = gradient,
			strokes = strokes,
			motion = motion,
			period = period,
			rotation = gradient.Rotation,
			offset = gradient.Offset,
			phase = rng:NextNumber() * period,
			nextAt = 0,
			untilAt = 0,
			jump = 0,
			gate = gate,
		}
	end
	return true
end

-- Étiquette MutationTag d'une carte (inventaire). mutation nil : remise comme avant.
function MutationFxController.StyleTag(tag: Instance?, label: Instance?, mutation: any)
	if tag == nil then
		return
	end
	local id = MutationFxController.StyleId(mutation)
	if id == nil then
		clearText(tag)
		return
	end
	local textLabel: TextLabel? = if label and label:IsA("TextLabel") then label :: TextLabel else nil
	applyText(tag, tag, textLabel, { tag, label }, id, TAG_GRADIENT, nil, nil)
end

-- Ligne Mutation d'un billboard (BB_Item, BB_Carry). gate : le mouvement n'est joué que s'il renvoie vrai.
function MutationFxController.StyleText(label: Instance?, mutation: any, gate: (() -> boolean)?)
	if label == nil or not label:IsA("TextLabel") then
		return
	end
	local id = MutationFxController.StyleId(mutation)
	if id == nil then
		clearText(label)
		return
	end
	applyText(label, label, label :: TextLabel, { label }, id, TEXT_GRADIENT, WHITE, gate)
end

-- Allumé à l'écran : visible, et son écran (ScreenGui, BillboardGui) allumé.
local function onScreen(holder: Instance): boolean
	if holder:IsA("GuiObject") and not (holder :: GuiObject).Visible then
		return false
	end
	local layer = holder:FindFirstAncestorWhichIsA("LayerCollector")
	return layer == nil or (layer :: LayerCollector).Enabled
end

local function paintText(entry: TextEntry, t: number)
	local gradient = entry.gradient
	local period = entry.period
	local motion = entry.motion
	if motion == "Shine" then
		local sweep = MutationFx.ShineTime
		local cycle = math.max(period, sweep)
		local p = (t + entry.phase) % cycle
		local x = if p < sweep then -1 + 2 * p / sweep else -1
		gradient.Offset = Vector2.new(x, entry.offset.Y)
	elseif motion == "Pulse" then
		local wave = 0.5 - 0.5 * math.cos(TAU * (t + entry.phase) / period)
		local transparency = MutationFx.PulseStrokeTransparency * wave
		for _, stroke in entry.strokes do
			stroke.Transparency = transparency
		end
	elseif motion == "Glitch" then
		if t >= entry.nextAt then
			entry.untilAt = t + MutationFx.GlitchTextTime
			entry.nextAt = t + period * (0.5 + 0.7 * rng:NextNumber())
			entry.jump = (if rng:NextNumber() < 0.5 then -1 else 1) * MutationFx.GlitchTextOffset
		end
		local x = if t < entry.untilAt then entry.offset.X + entry.jump else entry.offset.X
		gradient.Offset = Vector2.new(x, entry.offset.Y)
	elseif motion == "Scan" then
		local y = -1 + 2 * (((t + entry.phase) / period) % 1)
		gradient.Offset = Vector2.new(entry.offset.X, y)
	elseif motion == "Spin" then
		gradient.Rotation = (entry.rotation + 360 * (((t + entry.phase) / period) % 1)) % 360
	end
end

local function updateTexts(t: number)
	if t - lastTextPaint < 1 / MutationFx.PaintRate then
		return
	end
	lastTextPaint = t
	for holder, entry in texts do
		if entry.gradient.Parent == nil then
			-- carte ou billboard détruit
			texts[holder] = nil
			savedTexts[holder] = nil
			continue
		end
		local gate = entry.gate
		if (gate and not gate()) or not onScreen(holder) then
			continue
		end
		paintText(entry, t)
	end
end

------------------------------------------------------------------------------
-- Objets : pièces, boîte, copies
------------------------------------------------------------------------------

local function isSkipped(inst: Instance, root: Instance): boolean
	local current: Instance? = inst
	while current ~= nil and current ~= root do
		if SKIPPED[current.Name] then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Pièces visibles de l'objet (ordre de GetDescendants), hors halo, chaînes et billboards.
local function visibleParts(model: Model): { BasePart }
	local list: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d :: BasePart).Transparency < 0.99 and not isSkipped(d, model) then
			table.insert(list, d :: BasePart)
		end
	end
	return list
end

local function anchorOf(model: Model, parts: { BasePart }): BasePart?
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	if parts[1] then
		return parts[1]
	end
	local any = model:FindFirstChildWhichIsA("BasePart", true)
	return if any then any :: BasePart else nil
end

-- Boîte des pièces `parts` dans l'orientation de `frame` : (centre, taille).
local function boundsOf(parts: { BasePart }, frame: CFrame): (CFrame, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in parts do
		local h = part.Size / 2
		local cf = part.CFrame
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = frame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
					lo = lo:Min(p)
					hi = hi:Max(p)
				end
			end
		end
	end
	if #parts == 0 then
		return frame, Vector3.zero
	end
	return frame * CFrame.new((lo + hi) / 2), hi - lo
end

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function scaleSequence(seq: NumberSequence, k: number): NumberSequence
	local keys = {}
	for _, kp in seq.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(keys)
end

local function isKept(inst: Instance): boolean
	for _, class in KEPT_CLASSES do
		if inst:IsA(class) then
			return true
		end
	end
	return false
end

-- Copie de l'objet pour un double : mêmes pièces, sans tags, attributs, scripts, invites, billboards, halo
-- ni chaînes ; toutes ancrées, sans collision. Renvoie la copie et ses pièces jumelles des pièces `sources`.
local function cleanCopy(model: Model, sources: { BasePart }): (Model, { [BasePart]: BasePart })
	local wanted: { [Instance]: boolean } = {}
	for _, part in sources do
		wanted[part] = true
	end
	local copy = model:Clone()
	local twins: { [BasePart]: BasePart } = {}
	local from = model:GetDescendants()
	local to = copy:GetDescendants()
	for i, d in from do
		local twin = to[i]
		if twin and wanted[d] and twin:IsA("BasePart") then
			twins[d :: BasePart] = twin :: BasePart
		end
	end
	for _, d in copy:GetDescendants() do
		if d.Parent ~= nil and (SKIPPED[d.Name] or not isKept(d)) then
			d:Destroy()
		end
	end
	for _, d in { copy :: Instance, table.unpack(copy:GetDescendants()) } do
		for _, tag in CollectionService:GetTags(d) do
			CollectionService:RemoveTag(d, tag)
		end
		for name in d:GetAttributes() do
			d:SetAttribute(name, nil)
		end
		if d:IsA("BasePart") then
			local part = d :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	for source, twin in twins do
		if twin.Parent == nil then
			twins[source] = nil
		end
	end
	return copy, twins
end

local function hasMovingPieces(model: Model): boolean
	if model:GetAttribute(IDLE_ATTRIBUTE) ~= nil then
		return true
	end
	for _, d in model:GetDescendants() do
		local name = d.Name
		if string.sub(name, 1, #SPIN_PREFIX) == SPIN_PREFIX or string.sub(name, 1, #WAVE_PREFIX) == WAVE_PREFIX then
			return true
		end
	end
	return false
end

local function averageColor(parts: { PartState }): Color3
	local r, g, b = 0, 0, 0
	for _, p in parts do
		r += p.part.Color.R
		g += p.part.Color.G
		b += p.part.Color.B
	end
	local n = math.max(#parts, 1)
	return Color3.new(r / n, g / n, b / n)
end

------------------------------------------------------------------------------
-- Objets : habiller, animer, déshabiller
------------------------------------------------------------------------------

local function syncGhostColors(fx: Fx)
	for _, ghost in fx.ghosts do
		if ghost.keepColor then
			for _, gp in ghost.parts do
				gp.part.Color = gp.source.Color
			end
		end
	end
end

-- Doubles à leur place : chaque pièce suit sa pièce d'origine, décalée de Offset (× `factor` pendant un
-- saut de Glitch) et de son tremblement, dans le repère de la boîte.
local function placeGhosts(fx: Fx, anchorCFrame: CFrame, factor: number)
	if #fx.ghosts == 0 then
		return
	end
	local box = anchorCFrame * fx.boxRel
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, ghost in fx.ghosts do
		local o = Vector3.new(ghost.offset.X * fx.size.X, ghost.offset.Y * fx.size.Y, ghost.offset.Z * fx.size.Z)
		local world: Vector3 = box:VectorToWorldSpace(o * factor + ghost.current)
		local shift = CFrame.new(world)
		for _, gp in ghost.parts do
			table.insert(parts, gp.part)
			table.insert(cframes, shift * gp.source.CFrame * gp.rel)
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function placeAll(fx: Fx, anchorCFrame: CFrame)
	local fxPart = fx.fxPart
	if fxPart then
		fxPart.CFrame = anchorCFrame * fx.fxRel
	end
	for _, extra in fx.extras do
		extra.model:PivotTo(anchorCFrame * extra.rel)
	end
	placeGhosts(fx, anchorCFrame, if fx.bursting then fx.glitchSpread else 1)
end

-- Fin du saut de Glitch : les pièces déplacées reviennent exactement à leur place.
local function endJump(fx: Fx)
	local jumped = fx.jumped
	if jumped == nil then
		return
	end
	fx.jumped = nil
	for part, cf in jumped do
		part.CFrame = cf
	end
end

local function localRoot(): Folder
	local folder = localFolder
	if folder and folder.Parent ~= nil then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = LOCAL_FOLDER
	created.Parent = Workspace
	localFolder = created
	return created
end

local function setShown(fx: Fx, shown: boolean)
	if fx.shown == shown then
		return
	end
	fx.shown = shown
	if shown then
		fx.lastAnchor = nil -- tout est replacé à la prochaine image
		placeAll(fx, fx.anchor.CFrame)
		fx.holder.Parent = localRoot()
	else
		endJump(fx)
		fx.bursting = false
		fx.holder.Parent = nil
	end
end

-- Habille `model` de l'effet `id` (apply() de l'aperçu de Clément). nil : FX absent ou objet sans pièce.
local function buildFx(model: Model, id: string): Fx?
	local style = fxFolder(id)
	if style == nil then
		return nil
	end
	local visible = visibleParts(model)
	local anchor = anchorOf(model, visible)
	if anchor == nil or #visible == 0 then
		return nil
	end
	local frame = model:GetPivot()
	local box, size = boundsOf(visible, frame)
	local maxSide = math.max(size.X, size.Y, size.Z, 0.05)
	local k = maxSide / referenceSize()
	local mode = stringAttribute(style, "ColorMode", "Keep")
	local tint = colorAttribute(style, "TintColor", WHITE)
	local shadeMin = numberAttribute(style, "ShadeMin", 1)
	local material = materialOf(stringAttribute(style, "Material", ""))
	local reflectance = numberAttribute(style, "Reflectance", -1)
	local anchorCFrame = anchor.CFrame
	local anchorInverse = anchorCFrame:Inverse()

	local holder = Instance.new("Model")
	holder.Name = `Mutation_{model.Name}`

	-- doubles et coques, copiés sur l'objet encore intact
	local ghosts: { Ghost } = {}
	local ghostFolder = style:FindFirstChild("Ghosts")
	if ghostFolder then
		for _, g in ghostFolder:GetChildren() do
			local copy, twins = cleanCopy(model, visible)
			copy.Name = "Mutation" .. g.Name
			local keepColor = g:GetAttribute("KeepColor") == true
			local transparency = numberAttribute(g, "Transparency", 0)
			local ghostMaterial = materialOf(stringAttribute(g, "Material", ""))
			local color = colorAttribute(g, "Color", WHITE)
			for _, part in twins do
				if not keepColor then
					part.Color = color
				end
				if ghostMaterial then
					part.Material = ghostMaterial
				end
				part.Transparency = transparency
				part.Reflectance = 0
			end
			copy.WorldPivot = box
			local ok, problem = pcall(function()
				copy:ScaleTo(copy:GetScale() * numberAttribute(g, "Scale", 1))
			end)
			if not ok then
				warnOnce(`scale:{id}:{g.Name}`, `{FX_PREFIX}{id}/{g.Name} : ScaleTo a échoué ({problem}), double à la taille de l'objet`)
			end
			local ghostParts: { GhostPart } = {}
			for _, source in visible do
				local twin = twins[source]
				if twin then
					table.insert(ghostParts, { part = twin, source = source, rel = source.CFrame:Inverse() * twin.CFrame })
				end
			end
			local offset = g:GetAttribute("Offset")
			table.insert(ghosts, {
				model = copy,
				parts = ghostParts,
				keepColor = keepColor,
				transparency = transparency,
				offset = if typeof(offset) == "Vector3" then offset :: Vector3 else Vector3.zero,
				jitter = numberAttribute(g, "Jitter", 0) * maxSide,
				current = Vector3.zero,
				flicker = stringAttribute(g, "Material", "") == "ForceField",
			})
			copy.Parent = holder
		end
	end

	-- couleurs et matière de l'objet
	local parts: { PartState } = {}
	local maxLum = 0.01
	for _, p in visible do
		maxLum = math.max(maxLum, luminance(p.Color))
	end
	for _, p in visible do
		local original = p.Color
		local state: PartState = {
			part = p,
			color = original,
			shade = shadeMin + (1 - shadeMin) * math.clamp(luminance(original) / maxLum, 0, 1),
			h = 0,
			s = 0,
			v = 0,
			origColor = original,
			origMaterial = p.Material,
			origReflectance = p.Reflectance,
		}
		if mode == "Shade" then
			p.Color = Color3.new(tint.R * state.shade, tint.G * state.shade, tint.B * state.shade)
		elseif mode == "Saturate" then
			local h, s, v = original:ToHSV()
			p.Color = Color3.fromHSV(h, math.max(s, 0.85), math.max(v, 0.95))
		end
		if material then
			p.Material = material
		end
		if reflectance >= 0 then
			p.Reflectance = reflectance
		end
		state.color = p.Color
		state.h, state.s, state.v = p.Color:ToHSV()
		table.insert(parts, state)
	end

	-- particules et lumière, dans une pièce invisible à la taille de la boîte
	local fxPart: Part? = nil
	local light: PointLight? = nil
	local lightBrightness = numberAttribute(style, "LightBrightness", 0)
	local emitters = style:FindFirstChild("Emitters")
	local hasEmitters = emitters ~= nil and #emitters:GetChildren() > 0
	if hasEmitters or lightBrightness > 0 then
		local boxScale = numberAttribute(style, "EmitterBoxScale", 1)
		local part = Instance.new("Part")
		part.Name = FX_PART
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(math.max(size.X * boxScale, 0.2), math.max(size.Y * boxScale, 0.2), math.max(size.Z * boxScale, 0.2))
		part.CFrame = box
		if emitters then
			for _, e in emitters:GetChildren() do
				if e:IsA("ParticleEmitter") then
					local copy = e:Clone() :: ParticleEmitter
					copy.Size = scaleSequence(copy.Size, k)
					copy.Speed = NumberRange.new(copy.Speed.Min * k, copy.Speed.Max * k)
					copy.Acceleration *= k
					copy.Parent = part
				end
			end
		end
		if lightBrightness > 0 then
			local l = Instance.new("PointLight")
			l.Name = LIGHT_NAME
			l.Brightness = lightBrightness
			l.Range = numberAttribute(style, "LightRange", 6) * k
			l.Shadows = false
			l.Color = averageColor(parts)
			l.Parent = part
			light = l
		end
		part.Parent = holder
		fxPart = part
	end

	-- extras (arc-en-ciel derrière l'objet, face avant = −Z)
	local extras: { Extra } = {}
	local extrasFolder = style:FindFirstChild("Extras")
	if extrasFolder then
		for _, e in extrasFolder:GetChildren() do
			if e:IsA("Model") then
				local copy = e:Clone() :: Model
				local fit = numberAttribute(copy, "FitHeight", 2)
				local scale = math.max(size.Y, size.X * 0.7) / fit
				if scale > 0 then
					copy:ScaleTo(scale)
				end
				copy:PivotTo(box * CFrame.new(0, -size.Y * 0.3, size.Z / 2 + 0.15 * scale))
				copy.Parent = holder
				table.insert(extras, { model = copy, rel = anchorInverse * copy:GetPivot() })
			end
		end
	end

	local moving = not anchor.Anchored or hasMovingPieces(model)
	local fx: Fx = {
		id = id,
		style = style,
		anchor = anchor,
		boxRel = anchorInverse * box,
		size = size,
		maxSide = maxSide,
		parts = parts,
		ghosts = ghosts,
		holder = holder,
		fxPart = fxPart,
		fxRel = anchorInverse * box,
		light = light,
		lightBrightness = lightBrightness,
		extras = extras,
		motion = stringAttribute(style, "Motion", "None"),
		period = math.max(numberAttribute(style, "MotionPeriod", 1), 0.05),
		glitchJump = numberAttribute(style, "GlitchJump", 0.03),
		glitchSpread = numberAttribute(style, "GlitchSpread", 1.8),
		moving = moving,
		canJump = not moving,
		lastAnchor = nil,
		nextJitter = 0,
		nextBurst = os.clock() + rng:NextNumber() * 1.5,
		burstUntil = 0,
		burstOffset = Vector3.zero,
		bursting = false,
		jumped = nil,
		lastPaint = -math.huge,
		shown = false,
	}
	syncGhostColors(fx)
	placeGhosts(fx, anchorCFrame, 1)
	return fx
end

-- Enlève l'effet : pièces remises à leurs couleurs, matière et place d'origine, copies détruites.
local function removeFx(fx: Fx)
	endJump(fx)
	for _, p in fx.parts do
		p.part.Color = p.origColor
		p.part.Material = p.origMaterial
		p.part.Reflectance = p.origReflectance
	end
	fx.holder:Destroy()
	fx.shown = false
end

-- Un pas d'animation (update() de l'aperçu de Clément) ; t = os.clock().
local function updateFx(fx: Fx, t: number)
	local anchorCFrame = fx.anchor.CFrame
	local moved = fx.lastAnchor ~= anchorCFrame
	fx.lastAnchor = anchorCFrame
	local replace = moved or fx.moving
	local motion = fx.motion
	if motion == "Rainbow" or motion == "Pulse" then
		if t - fx.lastPaint >= 1 / MutationFx.PaintRate then
			fx.lastPaint = t
			if motion == "Rainbow" then
				local c = Color3.fromHSV((t / fx.period) % 1, 0.85, 1)
				for _, p in fx.parts do
					p.part.Color = Color3.new(c.R * p.shade, c.G * p.shade, c.B * p.shade)
				end
				syncGhostColors(fx)
				local light = fx.light
				if light then
					light.Color = c
				end
			else
				local wave = math.sin(t * TAU / fx.period) -- −1 à 1
				local f = 0.875 + 0.125 * wave
				for _, p in fx.parts do
					p.part.Color = Color3.fromHSV(p.h, p.s, p.v * f)
				end
				syncGhostColors(fx)
				for _, ghost in fx.ghosts do
					local transparency = math.clamp(ghost.transparency - 0.08 * wave, 0, 1)
					for _, gp in ghost.parts do
						gp.part.Transparency = transparency
					end
				end
				local light = fx.light
				if light then
					light.Brightness = fx.lightBrightness * (1 + 0.3 * wave)
				end
			end
		end
	elseif motion == "Glitch" then
		if t >= fx.nextJitter then
			fx.nextJitter = t + JITTER_STEP
			for _, ghost in fx.ghosts do
				ghost.current = Vector3.new((rng:NextNumber() * 2 - 1) * ghost.jitter, (rng:NextNumber() * 2 - 1) * ghost.jitter * 0.5, 0)
				if ghost.flicker then
					local hidden = fx.bursting and rng:NextNumber() < 0.5
					for _, gp in ghost.parts do
						gp.part.LocalTransparencyModifier = if hidden then 1 else 0
					end
				end
			end
			replace = true
		end
		if t >= fx.nextBurst then
			fx.burstUntil = t + BURST_TIME
			fx.nextBurst = t + fx.period * (0.5 + rng:NextNumber())
			local jump = fx.glitchJump * fx.maxSide
			fx.burstOffset = Vector3.new((rng:NextNumber() * 2 - 1) * jump, (rng:NextNumber() * 2 - 1) * jump * 0.4, 0)
		end
		local bursting = t < fx.burstUntil
		if bursting ~= fx.bursting then
			fx.bursting = bursting
			replace = true
			if bursting and fx.canJump then
				local shift = (anchorCFrame * fx.boxRel):VectorToWorldSpace(fx.burstOffset)
				local jumped: { [BasePart]: CFrame } = {}
				for _, p in fx.parts do
					if p.part.Anchored then
						jumped[p.part] = p.part.CFrame
						p.part.CFrame = p.part.CFrame + shift
					end
				end
				fx.jumped = jumped
			elseif not bursting then
				endJump(fx)
				for _, ghost in fx.ghosts do
					if ghost.flicker then
						for _, gp in ghost.parts do
							gp.part.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end
	end
	if replace then
		placeAll(fx, anchorCFrame)
	end
end

------------------------------------------------------------------------------
-- Objets suivis
------------------------------------------------------------------------------

local function mutationOf(model: Model): Mutations.Mutation?
	return Mutations.Sanitize({ Size = model:GetAttribute(SIZE_ATTRIBUTE), Effect = model:GetAttribute(EFFECT_ATTRIBUTE) })
end

local function styleLabels(entry: Entry)
	local mutation = mutationOf(entry.model)
	local found: { TextLabel } = {}
	for _, d in entry.model:GetDescendants() do
		if d:IsA("BillboardGui") and ITEM_LABELS[d.Name] then
			local field = d:FindFirstChild(MUTATION_FIELD, true)
			if field and field:IsA("TextLabel") then
				table.insert(found, field :: TextLabel)
			end
		end
	end
	for _, label in entry.labels do
		if not table.find(found, label) then
			clearText(label)
		end
	end
	entry.labels = found
	local function gate(): boolean
		return entry.near
	end
	for _, label in found do
		MutationFxController.StyleText(label, mutation, gate)
	end
end

local function dropFx(entry: Entry)
	local fx = entry.fx
	if fx then
		entry.fx = nil
		removeFx(fx)
	end
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
	dropFx(entry)
	for _, label in entry.labels do
		clearText(label)
	end
end

local function track(inst: Instance)
	if not inst:IsA("Model") or entries[inst :: Model] ~= nil then
		return
	end
	local model = inst :: Model
	local entry: Entry = {
		model = model,
		connections = {},
		dirty = false,
		labelsDirty = true,
		lastScale = nil,
		stable = 0,
		missing = nil,
		fx = nil,
		near = false,
		labels = {},
	}
	local function changed()
		entry.dirty = true
		entry.labelsDirty = true
	end
	table.insert(entry.connections, model:GetAttributeChangedSignal(EFFECT_ATTRIBUTE):Connect(changed))
	table.insert(entry.connections, model:GetAttributeChangedSignal(SIZE_ATTRIBUTE):Connect(changed))
	table.insert(
		entry.connections,
		model.DescendantAdded:Connect(function(d: Instance)
			if d:IsA("BillboardGui") or d.Name == MUTATION_FIELD then
				entry.labelsDirty = true
			elseif d:IsA("BasePart") and entry.fx ~= nil and not isSkipped(d, model) then
				entry.dirty = true -- pièce arrivée après l'habillage (streaming) : rhabillé
			end
		end)
	)
	entries[model] = entry
	sinceCheck = math.huge -- contrôlé à la prochaine image
end

local function eyePosition(): Vector3?
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

local function isTracked(inst: Instance): boolean
	for _, tag in TRACKED_TAGS do
		if CollectionService:HasTag(inst, tag) then
			return true
		end
	end
	return false
end

-- Contrôle de chaque objet (toutes les DistanceCheckInterval s) : attributs, échelle stable, distance.
local function checkEntries()
	local eye = eyePosition()
	for model, entry in entries do
		if model.Parent == nil then
			untrack(model)
			continue
		end
		if entry.dirty then
			entry.dirty = false
			dropFx(entry)
			entry.missing = nil
			entry.lastScale = nil
			entry.stable = 0
		end
		if entry.labelsDirty then
			entry.labelsDirty = false
			styleLabels(entry)
		end
		local effect = model:GetAttribute(EFFECT_ATTRIBUTE)
		local hasMutation = type(effect) == "string" or model:GetAttribute(SIZE_ATTRIBUTE) ~= nil
		if not hasMutation then
			entry.near = false
			continue
		end
		local fx = entry.fx
		local position = if fx then fx.anchor.Position else model:GetPivot().Position
		entry.near = eye ~= nil and (position - eye).Magnitude <= MutationFx.MaxDistance
		if type(effect) ~= "string" or entry.missing == effect then
			continue
		end
		local scale = model:GetScale()
		if fx then
			if math.abs(scale - (entry.lastScale or scale)) > 1e-4 then
				-- l'objet a changé d'échelle : rhabillé quand il sera de nouveau stable
				dropFx(entry)
				entry.stable = 0
				entry.lastScale = scale
				continue
			end
			setShown(fx, entry.near)
			continue
		end
		if entry.lastScale ~= nil and math.abs(scale - entry.lastScale) <= 1e-4 then
			entry.stable += 1
		else
			entry.stable = 0
		end
		entry.lastScale = scale
		if entry.stable >= MutationFx.SettleChecks then
			local built = buildFx(model, effect)
			if built == nil then
				entry.missing = effect
			else
				entry.fx = built
				setShown(built, entry.near)
			end
		end
	end
end

local function onHeartbeat(dt: number)
	sinceCheck += dt
	if sinceCheck >= MutationFx.DistanceCheckInterval then
		sinceCheck = 0
		checkEntries()
	end
	local t = os.clock()
	for _, entry in entries do
		local fx = entry.fx
		if fx and fx.shown then
			updateFx(fx, t)
		end
	end
	updateTexts(t)
end

------------------------------------------------------------------------------
-- Tests
------------------------------------------------------------------------------

function MutationFxController.GetState(model: Model): { [string]: any }?
	local entry = entries[model]
	local fx = if entry then entry.fx else nil
	if fx == nil then
		return nil
	end
	return {
		Effect = fx.id,
		Shown = fx.shown,
		Ghosts = #fx.ghosts,
		Parts = #fx.parts,
		Holder = fx.holder,
		Bursting = fx.bursting,
	}
end

function MutationFxController.GetStats(): { [string]: number }
	local tracked, dressed, shown, textCount = 0, 0, 0, 0
	for _, entry in entries do
		tracked += 1
		local fx = entry.fx
		if fx then
			dressed += 1
			if fx.shown then
				shown += 1
			end
		end
	end
	for _ in texts do
		textCount += 1
	end
	return { Tracked = tracked, Dressed = dressed, Shown = shown, Texts = textCount }
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function MutationFxController.Start()
	for _, tag in TRACKED_TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst: Instance)
			if inst:IsA("Model") and not (inst.Parent ~= nil and isTracked(inst)) then
				untrack(inst :: Model)
			end
		end)
		for _, inst in CollectionService:GetTagged(tag) do
			track(inst)
		end
	end
	RunService.Heartbeat:Connect(onHeartbeat)
	if IS_STUDIO then
		print("[MutationFxController] prêt : styles du texte et effets des objets mutés")
	end
end

return MutationFxController
