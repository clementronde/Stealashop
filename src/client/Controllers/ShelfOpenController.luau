--!strict
-- ShelfOpenController (vague 31, client, liaison L-112) : l'ouverture d'un colis sur son rayon, vue par
-- tous les joueurs qui ont le magasin chargé. Seulement si Features.ShelfOpen (false : rien n'est branché).
-- Visuel validé par Clément : tools/clement/open_counter_antitheft_preview.luau ; animations T.53 à T.55
-- de docs/claude/notes/ui-motion-skilltree.md ; valeurs : Config/ShelfOpen et ShelfOpen/Logic.
--
-- Le serveur (StoreHeistService) décide de tout et n'écrit que des attributs (Shared/ShelfOpenState) :
-- sur le colis (tag ShelfBox) ShelfOpenState "Opening", ShelfOpenBy, ShelfOpenAt, ShelfLuck, ShelfRevealAt ;
-- puis il crée l'objet sorti (tag ShelfItem) à la place du colis. Ici, à chaque image, sans rien envoyer :
--   1. rabats (T.53) : Lid.FlapL et Lid.FlapR basculent de 115° autour de leur bord extérieur en 0,35 s ;
--      sans rabats (les BOX_<Rareté> des rayons), le Lid entier bascule autour de son bord arrière (+Z,
--      la face avant −Z regarde l'allée). Son Unbox_Open. Puis FX_ShelfLight (copie locale) posé sur le
--      haut du colis, InnerGlow 0 → 3 en 0,25 s ;
--   2. chance (T.54) : copie de BB_ShelfOpen sur le colis (si la chance tirée dépasse ×1), Row.Luck
--      « ×N.NN LUCK » = ShelfOpenState.luckAt à l'heure du serveur, figée à ShelfRevealAt (relu à chaque
--      image : le serveur l'avance si la police arrive) ; à chaque tic : Row 1,12 → 1, trèfle penché, son
--      UI_Click une octave plus haut sur toute la montée ; le colis (Model:ScaleTo, autour de son pivot)
--      et la lumière grandissent avec la chance (Logic.growth) ;
--   3. sortie (T.55), dès que l'objet sorti arrive (ou à ShelfRevealAt + RevealWait sans lui : fin) :
--      colis caché en local (LocalTransparencyModifier), son contour noir (Highlight, SelectionBox) et
--      BB_Box retirés ; FX_ShelfReveal au centre du colis, aux couleurs de la rareté de l'objet,
--      Emit(EmitCount) sur chaque émetteur, Flash 9 → 0, Shaft allumé puis effacé ; sons Unbox_UpgradePop
--      puis Unbox_Confetti ; l'objet sort 0,2 → 1 (Back Out), blanc (Highlight passager, réservé dans le
--      budget de ShelfBoxController) puis à ses couleurs ; BB_Item au-dessus (nom, rareté, Mutation
--      « BIG GOLD » montrée seulement avec une mutation, $/s) ; chez l'ouvreur, UI_HUD.RevealTint pour
--      Épique et plus (ShelfOpen.RevealTintMinRarity).
-- a139 (optimisation téléphone, Config/PerfClient.ShelfOpenWatchChanges) : seuls les colis dont l'état d'ouverture
-- change, ou n'est pas nil, sont relus à chaque image (avant : les attributs des 120 colis, à chaque image).
-- Tout ce qui est créé ici est local et libéré à la fin (FX, billboards, Highlight, réservation). Un
-- colis dont l'ouverture est annulée (attribut retiré avant la sortie) est remis comme avant.
--
-- API (client, pour un test dans Studio ou le banc) :
--   ShelfOpenController.GetState() -> { { Box, Phase, Luck, Shown, Mode, Item } }
--   ShelfOpenController.GetItemBoards() -> { [Instance]: BillboardGui }

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local ShelfOpen = require(Config:WaitForChild("ShelfOpen"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Format"))
local ShelfOpenState = require(Shared:WaitForChild("ShelfOpenState"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Logic = require(script.Parent:WaitForChild("ShelfOpen"):WaitForChild("Logic"))

-- Noms posés par StoreHeistService et par Clément (mêmes noms là-bas).
local SHELF_BOX_TAG = "ShelfBox"
local SLOT_ID_ATTRIBUTE = "SlotId"
local OUTLINE_SELECTION = "Outline" -- arêtes noires des BOX_* (SelectionBox)
local BOX_LABEL = "BB_Box"
local LUCK_BOARD = "BB_ShelfOpen"
local ITEM_BOARD = "BB_Item"
local LIGHT_FX = "FX_ShelfLight"
local REVEAL_FX = "FX_ShelfReveal"
local TINT_PATH = "RevealTint" -- dans UI_HUD
local EMIT_COUNT_ATTRIBUTE = "EmitCount"
local SCALE_NAME = "ShelfOpenScale" -- UIScale créé par le code sur les copies (jamais sur un gabarit)
local FX_FOLDER = "_ShelfOpenFX" -- dossier local du Workspace, jamais répliqué
local RESERVE_KEY = "ShelfOpen" -- places de Highlight gardées chez ShelfBoxController
-- Sons provisoires (V0, relevé de la vague 31 ; Clément donnera les siens).
local SOUND_FLAPS = "Unbox_Open"
local SOUND_TICK = "UI_Click"
local SOUND_POP = "Unbox_UpgradePop"
local SOUND_CONFETTI = "Unbox_Confetti"

local WHITE = Color3.new(1, 1, 1)
local IS_STUDIO = RunService:IsStudio()

-- a139 (optimisation téléphone, passe 2) : réglages de Config/PerfClient ; module absent (banc d'avant) : {},
-- ancien comportement.
local function perfSettings(): { [string]: any }
	local ok, found = pcall(function(): Instance?
		return Config:FindFirstChild("PerfClient") or Config:WaitForChild("PerfClient", 2)
	end)
	if ok and found and found:IsA("ModuleScript") then
		local loaded, result = pcall(require, found)
		if loaded and type(result) == "table" then
			return result
		end
	end
	return {}
end
-- Un colis n'est relu que si son état d'ouverture change ou tant qu'il en a un (false : tous à chaque image).
local WATCH_CHANGES = perfSettings().ShelfOpenWatchChanges == true

type Mover = {
	Target: Instance, -- Model ou BasePart
	Orig: CFrame, -- pivot ou CFrame d'origine, monde
	Hinge: CFrame, -- charnière, dans l'espace du colis
	Axis: Vector3, -- axe de bascule (espace de la charnière)
}

type Saved = {
	modifiers: { [Instance]: number },
	highlights: { [Highlight]: { number } },
	selections: { [SelectionBox]: boolean },
}

type Session = {
	Box: Model,
	SlotId: string?,
	OpenAt: number,
	Luck: number,
	Opener: boolean,
	Phase: string, -- "Opening", "Waiting", "Revealing"
	Mode: string, -- Logic.lidPlan
	Home: CFrame,
	BaseScale: number,
	Core: BasePart?,
	TopLocal: Vector3,
	CenterLocal: Vector3,
	Movers: { Mover },
	FlapsDone: boolean,
	Scaled: boolean,
	Light: Model?,
	LightRoot: BasePart?,
	Beam: Beam?,
	BeamWidth: number,
	Glow: PointLight?,
	Sparkles: ParticleEmitter?,
	SparkleRate: number,
	Board: BillboardGui?,
	BoardScale: UIScale?,
	BoardAt: number, -- os.clock de l'entrée du compteur
	Row: GuiObject?,
	RowScale: UIScale?,
	RowPopAt: number,
	LuckLabel: TextLabel?,
	Icon: GuiObject?,
	IconRotation: number,
	LastTick: number,
	BoxGone: boolean,
	WaitSince: number,
	LastCenter: Vector3,
	-- sortie
	Item: Model?,
	ItemBase: number,
	ItemPivot: CFrame,
	RevealAt: number, -- os.clock
	RevealFx: Model?,
	Flash: PointLight?,
	Shaft: Beam?,
	WhiteFlash: Highlight?,
	ItemBoardDone: boolean,
	Tint: GuiObject?,
	TintColor: Color3,
	TintTransparency: number,
	TintVisible: boolean,
	Hidden: Saved?,
}

type ItemBoard = {
	Gui: BillboardGui,
	Own: boolean, -- copie créée ici (détruite ici) ; false = BB_Item du serveur, seulement animé
	Scale: UIScale?,
	PopAt: number, -- os.clock ; 0 = pas d'entrée
}

export type SessionState = {
	Box: Model,
	Phase: string,
	Luck: number,
	Shown: number,
	Mode: string,
	Item: Model?,
}

local ShelfOpenController = {}

local localPlayer = Players.LocalPlayer
local boxes: { [Model]: boolean } = {}
-- a139 (PerfClient.ShelfOpenWatchChanges) : colis à relire à la prochaine image (état changé, ou état non nil).
local watched: { [Model]: boolean } = {}
local boxConnections: { [Model]: { RBXScriptConnection } } = {}
local sessions: { [Model]: Session } = {}
local hiddenBoxes: { [Model]: Saved } = {} -- colis cachés à la sortie, remis si leur état revient à nil
local doneAt: { [Model]: number } = {} -- colis dont la sortie est jouée → son ShelfOpenAt (pas de 2e fois)
local itemBoards: { [Instance]: ItemBoard } = {}
local items: { [Model]: boolean } = {}
local flashes = 0
local shelfBoxApi: any = nil
local fxFolder: Folder? = nil
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[ShelfOpen] {message}`)
	end
end

local function reserve()
	local api = shelfBoxApi
	if api then
		pcall(api.Reserve, RESERVE_KEY, flashes)
	end
end

local function asset(folder: string, name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sub = if assets then assets:FindFirstChild(folder) else nil
	local found = if sub then sub:FindFirstChild(name, true) else nil
	if found == nil then
		sayOnce(name, `{name} absent de ReplicatedStorage.Assets.{folder} : ouverture sans lui (L-112)`)
	end
	return found
end

local function folder(): Folder
	local current = fxFolder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FX_FOLDER
	created.Parent = Workspace
	fxFolder = created
	return created
end

local function playSound(name: string, at: Instance?, pitch: number?)
	local template = MarkerSounds.find(name)
	if template == nil then
		sayOnce(`sound:{name}`, `son {name} absent de ReplicatedStorage.Assets.Sounds : muet`)
		return
	end
	local sound = MarkerSounds.playSound(template, at)
	if pitch and pitch ~= 1 then
		sound.PlaybackSpeed = template.PlaybackSpeed * pitch
	end
end

local function playerGui(): PlayerGui?
	return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function guiScale(object: GuiObject?): UIScale?
	if object == nil then
		return nil
	end
	local existing = object:FindFirstChildOfClass("UIScale")
	if existing then
		return if existing.Name == SCALE_NAME then existing else nil -- celui de Clément : on n'y touche pas
	end
	local scale = Instance.new("UIScale")
	scale.Name = SCALE_NAME
	scale.Parent = object
	return scale
end

local function coreOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function bounds(target: Instance): (CFrame, Vector3)
	if target:IsA("Model") then
		return (target :: Model):GetBoundingBox()
	end
	local part = target :: BasePart
	return part.CFrame, part.Size
end

-- Boîte englobante de `target`, dans l'espace `space` : (min, max).
local function localExtent(target: Instance, space: CFrame): (Vector3, Vector3)
	local cf, size = bounds(target)
	local h = size / 2
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = space:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
				lo = lo:Min(p)
				hi = hi:Max(p)
			end
		end
	end
	return lo, hi
end

local function pivotOf(target: Instance): CFrame
	if target:IsA("Model") then
		return (target :: Model):GetPivot()
	end
	return (target :: BasePart).CFrame
end

local function moveTo(target: Instance, cf: CFrame)
	if target:IsA("Model") then
		(target :: Model):PivotTo(cf)
	elseif target:IsA("BasePart") then
		(target :: BasePart).CFrame = cf
	end
end

-- Rabats (ou Lid) : charnière sur le bord extérieur (rabats, axe Z du colis) ou arrière (Lid, axe X).
local function buildMovers(box: Model, home: CFrame, plan: Logic.LidPlan, center: Vector3): { Mover }
	local movers: { Mover } = {}
	for _, part in plan.Parts do
		local lo, hi = localExtent(part, home)
		local mid = (lo + hi) / 2
		local hinge: CFrame
		local axis: Vector3
		if plan.Mode == "Flaps" then
			if mid.X < center.X then
				hinge = CFrame.new(lo.X, mid.Y, mid.Z)
				axis = Vector3.new(0, 0, 1) -- le bord intérieur (+X) monte
			else
				hinge = CFrame.new(hi.X, mid.Y, mid.Z)
				axis = Vector3.new(0, 0, -1)
			end
		else
			hinge = CFrame.new(mid.X, mid.Y, hi.Z)
			axis = Vector3.new(1, 0, 0) -- l'avant (−Z) monte, le Lid bascule vers l'arrière
		end
		table.insert(movers, { Target = part, Orig = pivotOf(part), Hinge = hinge, Axis = axis })
	end
	return movers
end

local function applyMovers(session: Session, angle: number)
	local home = session.Home
	for _, mover in session.Movers do
		if mover.Target.Parent == nil then
			continue
		end
		local turn = home * mover.Hinge * CFrame.fromAxisAngle(mover.Axis, angle) * mover.Hinge:Inverse() * home:Inverse()
		moveTo(mover.Target, turn * mover.Orig)
	end
end

local function setBoxScale(session: Session, factor: number)
	local box = session.Box
	if box.Parent == nil or session.BoxGone then
		return
	end
	pcall(function()
		box:ScaleTo(session.BaseScale * factor)
		box:PivotTo(session.Home)
	end)
	session.Scaled = factor ~= 1
end

-- Lumière ----------------------------------------------------------------------------------------

local function createLight(session: Session)
	local template = asset("FX", LIGHT_FX)
	if template == nil or not template:IsA("Model") then
		return
	end
	local light = template:Clone() :: Model
	for _, d in light:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local root = light:FindFirstChild("Root", true)
	session.LightRoot = if root and root:IsA("BasePart") then root else coreOf(light)
	local beam = light:FindFirstChild("InnerLight", true)
	if beam and beam:IsA("Beam") then
		session.Beam = beam
		session.BeamWidth = beam.Width1
	end
	local glow = light:FindFirstChild("InnerGlow", true)
	if glow and glow:IsA("PointLight") then
		glow.Brightness = 0
		session.Glow = glow
	end
	local sparkles = light:FindFirstChild("Sparkles", true)
	if sparkles and sparkles:IsA("ParticleEmitter") then
		session.Sparkles = sparkles
		session.SparkleRate = sparkles.Rate
	end
	light.Parent = folder()
	session.Light = light
end

local function placeLight(session: Session, factor: number, k: number, glowIn: number)
	local light = session.Light
	if light == nil then
		return
	end
	local top = session.Home * CFrame.new(session.TopLocal * factor)
	local root = session.LightRoot
	if root then
		local offset = root.CFrame:ToObjectSpace(light:GetPivot())
		light:PivotTo(CFrame.new(top.Position) * session.Home.Rotation * offset)
	end
	local beam = session.Beam
	if beam then
		beam.Width1 = session.BeamWidth + Logic.LightWidthGain * k
	end
	local glow = session.Glow
	if glow then
		glow.Brightness = Logic.GlowBase * glowIn + Logic.GlowGain * k
	end
	local sparkles = session.Sparkles
	if sparkles then
		sparkles.Rate = session.SparkleRate + Logic.SparkleGain * k
	end
end

-- Compteur ---------------------------------------------------------------------------------------

local function createBoard(session: Session)
	local template = asset("UI", LUCK_BOARD)
	local gui = playerGui()
	if template == nil or not template:IsA("BillboardGui") or gui == nil or session.Core == nil then
		return
	end
	local board = template:Clone() :: BillboardGui
	local row = Find.path(board, "Row")
	local luck = Find.path(board, "Row.Luck")
	local icon = Find.path(board, "Row.LuckIcon")
	session.Row = if row and row:IsA("GuiObject") then row else nil
	session.LuckLabel = if luck and luck:IsA("TextLabel") then luck else nil
	session.Icon = if icon and icon:IsA("GuiObject") then icon else nil
	session.IconRotation = if session.Icon then (session.Icon :: GuiObject).Rotation else 0
	session.RowScale = guiScale(session.Row)
	local whole = Instance.new("UIScale")
	whole.Name = SCALE_NAME
	whole.Scale = 0
	whole.Parent = board
	session.BoardScale = whole
	session.BoardAt = os.clock()
	board.Adornee = session.Core
	board.Enabled = true
	board.Parent = gui
	session.Board = board
	local label = session.LuckLabel
	if label then
		label.Text = Logic.luckText(1)
	end
end

-- Objet sorti : BB_Item --------------------------------------------------------------------------

local function destroyItemBoard(item: Instance)
	local entry = itemBoards[item]
	if entry == nil then
		return
	end
	itemBoards[item] = nil
	if entry.Own then
		entry.Gui:Destroy()
	elseif entry.Scale then
		(entry.Scale :: UIScale):Destroy()
	end
end

local function setLabel(root: Instance, name: string, text: string, color: Color3?): TextLabel?
	local found = Find.path(root, name)
	if found and found:IsA("TextLabel") then
		found.Text = text
		if color then
			found.TextColor3 = color
		end
		return found
	end
	return nil
end

-- a119 (L-127 point 5) : style de la mutation sur la ligne Mutation de la copie de BB_Item (dégradé,
-- couleurs, mouvement), joué par MutationFxController s'il est chargé ; sans lui, le texte reste tel quel.
local mutationFx: any = false
local function styleMutationText(label: TextLabel, item: Model)
	if mutationFx == false then
		mutationFx = nil
		local module = script.Parent:FindFirstChild("MutationFxController")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" then
				mutationFx = result
			end
		end
	end
	if mutationFx then
		mutationFx.StyleText(label, { Size = item:GetAttribute("MutationSize"), Effect = item:GetAttribute("MutationEffect") })
	end
end

local function attachItemBoard(item: Model, pop: boolean)
	if itemBoards[item] then
		return
	end
	local entry: ItemBoard
	local existing = item:FindFirstChild(ITEM_BOARD, true)
	if existing and existing:IsA("BillboardGui") then
		entry = { Gui = existing, Own = false, Scale = nil :: UIScale?, PopAt = 0 }
	else
		local template = asset("UI", ITEM_BOARD)
		local gui = playerGui()
		local core = coreOf(item)
		if template == nil or not template:IsA("BillboardGui") or gui == nil or core == nil then
			return
		end
		local board = template:Clone() :: BillboardGui
		local itemId = item:GetAttribute("ItemId")
		local def = if type(itemId) == "string" then Items.ById[itemId] else nil
		local rarityId = item:GetAttribute("Rarity")
		local rarity = if type(rarityId) == "string" then Rarities.ById[rarityId] else nil
		local income = item:GetAttribute("Income")
		setLabel(board, "ItemName", if def then def.DisplayName else (if type(itemId) == "string" then itemId else ""))
		setLabel(board, "Rarity", if rarity then rarity.DisplayNameUpper else "", if rarity then rarity.Color else nil)
		setLabel(board, "Income", if type(income) == "number" then Format.income(income) else "")
		local text = Logic.mutationText(item:GetAttribute("MutationSize"), item:GetAttribute("MutationEffect"))
		local mutation = setLabel(board, "Mutation", text or "")
		if mutation then
			mutation.Visible = text ~= nil
			styleMutationText(mutation, item)
		end
		-- Aperçu de Clément : au-dessus du haut de l'objet, toujours devant.
		local _, size = item:GetBoundingBox()
		board.StudsOffset = Vector3.new(0, size.Y / 2 + Logic.ItemBoardLift, 0)
		board.AlwaysOnTop = true
		board.Adornee = core
		board.Enabled = true
		board.Parent = gui
		entry = { Gui = board, Own = true, Scale = nil :: UIScale?, PopAt = 0 }
	end
	if pop then
		local scale = Instance.new("UIScale")
		scale.Name = SCALE_NAME
		scale.Scale = 0
		scale.Parent = entry.Gui
		entry.Scale = scale
		entry.PopAt = os.clock()
	end
	itemBoards[item] = entry
end

local function updateItemBoards(clock: number)
	for item, entry in itemBoards do
		if item.Parent == nil or not items[item :: Model] then
			destroyItemBoard(item)
			continue
		end
		local scale = entry.Scale
		if scale and entry.PopAt > 0 then
			local t = (clock - entry.PopAt) / Logic.ItemBoardPopTime
			if t >= 1 then
				scale:Destroy()
				entry.Scale = nil
				entry.PopAt = 0
			else
				scale.Scale = Logic.backOut(t)
			end
		end
	end
end

-- Colis caché à la sortie -------------------------------------------------------------------------

local function hideBox(box: Model): Saved
	local saved: Saved = { modifiers = {}, highlights = {}, selections = {} }
	for _, d in box:GetDescendants() do
		if d:IsA("BasePart") then
			saved.modifiers[d] = d.LocalTransparencyModifier
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") then
			saved.modifiers[d] = d.LocalTransparencyModifier
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Highlight") then
			saved.highlights[d] = { d.FillTransparency, d.OutlineTransparency }
			d.FillTransparency = 1
			d.OutlineTransparency = 1
		elseif d:IsA("SelectionBox") then
			saved.selections[d] = d.Visible
			d.Visible = false
		elseif d:IsA("BillboardGui") and d.Name == BOX_LABEL then
			d:Destroy() -- le colis est consommé : ShelfBoxController ne le rallume plus
		end
	end
	return saved
end

local function showBox(saved: Saved)
	for d, value in saved.modifiers do
		if d.Parent then
			(d :: any).LocalTransparencyModifier = value
		end
	end
	for h, values in saved.highlights do
		if h.Parent then
			h.FillTransparency = values[1]
			h.OutlineTransparency = values[2]
		end
	end
	for s, visible in saved.selections do
		if s.Parent then
			s.Visible = visible
		end
	end
end

-- Fin d'une ouverture ----------------------------------------------------------------------------

local function dropWhite(session: Session)
	local white = session.WhiteFlash
	if white then
		session.WhiteFlash = nil
		white:Destroy()
		flashes -= 1
		reserve()
	end
end

local function restoreTint(session: Session)
	local tint = session.Tint
	if tint then
		session.Tint = nil
		tint.BackgroundTransparency = session.TintTransparency
		tint.BackgroundColor3 = session.TintColor
		tint.Visible = session.TintVisible
	end
end

local function finish(session: Session)
	if sessions[session.Box] == session then
		sessions[session.Box] = nil
	end
	if session.Phase == "Revealing" and session.Box.Parent and not session.BoxGone then
		doneAt[session.Box] = session.OpenAt
	end
	for _, object in { session.Light, session.Board, session.RevealFx } :: { Instance? } do
		if object then
			object:Destroy()
		end
	end
	session.Light, session.Board, session.RevealFx = nil, nil, nil
	dropWhite(session)
	restoreTint(session)
	local item = session.Item
	if item and item.Parent and session.Phase == "Revealing" then
		pcall(function()
			item:ScaleTo(session.ItemBase)
			item:PivotTo(session.ItemPivot)
		end)
	end
	local box = session.Box
	if box.Parent and not session.BoxGone then
		-- Le colis reprend sa taille et son couvercle ; caché à la sortie, il le reste tant que le serveur
		-- ne remet pas son état à nil (ouverture annulée : il revient tel quel).
		setBoxScale(session, 1)
		applyMovers(session, 0)
		if session.Hidden then
			hiddenBoxes[box] = session.Hidden
		end
	end
	if WATCH_CHANGES and boxes[box] then
		watched[box] = true -- a139 : doneAt ou colis caché posés ici, relus à la prochaine image comme avant
	end
end

-- Sortie ------------------------------------------------------------------------------------------

local function recolor(fx: Model, color: Color3)
	for _, d in fx:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local keys = d.Color.Keypoints
			if d.Name == "Ring" then
				d.Color = ColorSequence.new(color, WHITE)
			elseif d.Name == "Confetti" then
				d.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, keys[1].Value),
					ColorSequenceKeypoint.new(0.5, color),
					ColorSequenceKeypoint.new(1, keys[#keys].Value),
				})
			elseif d.Name == "Stars" then
				d.Color = ColorSequence.new(keys[1].Value, color:Lerp(WHITE, 0.3))
			end -- Streaks : blancs (aperçu)
		elseif d:IsA("PointLight") and d.Name == "Flash" then
			d.Color = color:Lerp(WHITE, 0.4)
		elseif d:IsA("Beam") and d.Name == "Shaft" then
			d.Color = ColorSequence.new(color:Lerp(WHITE, 0.35))
		end
	end
end

local function boxCenter(session: Session): Vector3
	local box = session.Box
	if box.Parent and not session.BoxGone then
		local ok, cf = pcall(function()
			return (box:GetBoundingBox())
		end)
		if ok then
			session.LastCenter = cf.Position
		end
	end
	return session.LastCenter
end

local function startReveal(session: Session, item: Model?)
	local clock = os.clock()
	session.Phase = "Revealing"
	session.RevealAt = clock
	session.Item = item
	local center = boxCenter(session)
	-- Le colis, son contour et sa lumière disparaissent.
	local box = session.Box
	if box.Parent and not session.BoxGone then
		session.Hidden = hideBox(box)
	end
	if session.Light then
		(session.Light :: Model):Destroy()
		session.Light = nil
	end
	local rarityId = if item then item:GetAttribute("Rarity") else nil
	local color = Logic.rarityColor(rarityId)
	-- Éclatement.
	local template = asset("FX", REVEAL_FX)
	if template and template:IsA("Model") then
		local fx = template:Clone() :: Model
		for _, d in fx:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local root = fx:FindFirstChild("Root", true)
		local rootPart = if root and root:IsA("BasePart") then root else coreOf(fx)
		local offset = if rootPart then rootPart.CFrame:ToObjectSpace(fx:GetPivot()) else CFrame.identity
		fx:PivotTo(CFrame.new(center) * session.Home.Rotation * offset)
		recolor(fx, color)
		fx.Parent = folder()
		for _, d in fx:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				local count = d:GetAttribute(EMIT_COUNT_ATTRIBUTE)
				d:Emit(if type(count) == "number" then count else 10)
			end
		end
		local flash = fx:FindFirstChild("Flash", true)
		if flash and flash:IsA("PointLight") then
			flash.Brightness = Logic.FlashBrightness
			session.Flash = flash
		end
		local shaft = fx:FindFirstChild("Shaft", true)
		if shaft and shaft:IsA("Beam") then
			shaft.Enabled = true
			session.Shaft = shaft
		end
		session.RevealFx = fx
		playSound(SOUND_POP, rootPart)
		task.delay(Logic.ConfettiDelay, function()
			if rootPart and rootPart.Parent then
				playSound(SOUND_CONFETTI, rootPart)
			end
		end)
	end
	-- L'objet sort petit et blanc.
	if item then
		session.ItemBase = item:GetScale()
		session.ItemPivot = item:GetPivot()
		pcall(function()
			item:ScaleTo(session.ItemBase * Logic.ItemPopFrom)
			item:PivotTo(session.ItemPivot)
		end)
		local white = Instance.new("Highlight")
		white.Name = "ShelfRevealWhite"
		white.FillColor = WHITE
		white.FillTransparency = 0
		white.OutlineTransparency = 1
		white.DepthMode = Enum.HighlightDepthMode.Occluded
		white.Adornee = item
		white.Parent = item
		session.WhiteFlash = white
		flashes += 1
		reserve()
	end
	-- Voile, chez l'ouvreur seulement.
	if session.Opener and Logic.wantsTint(rarityId) then
		local gui = playerGui()
		local hud = if gui then gui:FindFirstChild("UI_HUD") else nil
		local tint = if hud then Find.path(hud, TINT_PATH) else nil
		if tint and tint:IsA("GuiObject") then
			session.Tint = tint
			session.TintColor = tint.BackgroundColor3
			session.TintTransparency = tint.BackgroundTransparency
			session.TintVisible = tint.Visible
			tint.BackgroundColor3 = color
			tint.BackgroundTransparency = Logic.TintFrom
			tint.Visible = true
		end
	end
end

local function updateReveal(session: Session, clock: number)
	local t = clock - session.RevealAt
	local item = session.Item
	if item and item.Parent then
		local s = if t >= Logic.ItemPopTime
			then 1
			else Logic.ItemPopFrom + (1 - Logic.ItemPopFrom) * Logic.backOut(t / Logic.ItemPopTime)
		pcall(function()
			item:ScaleTo(session.ItemBase * s)
			item:PivotTo(session.ItemPivot)
		end)
		if t >= Logic.ItemPopTime and not session.ItemBoardDone then
			session.ItemBoardDone = true
			attachItemBoard(item, true)
		end
	end
	local white = session.WhiteFlash
	if white then
		local fade = (t - Logic.ItemPopTime) / Logic.WhiteFadeTime
		if fade >= 1 or white.Parent == nil then
			dropWhite(session)
		elseif fade > 0 then
			white.FillTransparency = fade
		end
	end
	local flash = session.Flash
	if flash then
		flash.Brightness = Logic.FlashBrightness * (1 - Logic.quadOut(t / Logic.FlashTime))
	end
	local shaft = session.Shaft
	if shaft and shaft.Enabled and t > Logic.ShaftDelay then
		local q = (t - Logic.ShaftDelay) / Logic.ShaftFadeTime
		if q >= 1 then
			shaft.Enabled = false
		else
			shaft.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.55, 0.3 + 0.7 * q),
				NumberSequenceKeypoint.new(1, 0.1 + 0.9 * q),
			})
		end
	end
	local board = session.Board
	if board then
		local q = t / Logic.BoardHideTime
		if q >= 1 then
			board:Destroy()
			session.Board = nil
		elseif session.BoardScale then
			(session.BoardScale :: UIScale).Scale = 1 - q * q
		end
	end
	local tint = session.Tint
	if tint then
		local q = t / Logic.TintTime
		if q >= 1 then
			restoreTint(session)
		else
			tint.BackgroundTransparency = Logic.TintFrom + (1 - Logic.TintFrom) * Logic.quadOut(q)
		end
	end
	if t >= Logic.RevealFxLife then
		finish(session)
	end
end

-- Ouverture ---------------------------------------------------------------------------------------

local function startSession(box: Model): Session?
	local openAt = box:GetAttribute(ShelfOpenState.AtAttribute)
	local luck = box:GetAttribute(ShelfOpenState.LuckAttribute)
	if type(openAt) ~= "number" or type(luck) ~= "number" then
		return nil
	end
	local saved = hiddenBoxes[box]
	if saved then
		hiddenBoxes[box] = nil
		showBox(saved)
	end
	local home = box:GetPivot()
	local lo, hi = localExtent(box, home)
	local center = (lo + hi) / 2
	local plan = Logic.lidPlan(box)
	local slotId = box:GetAttribute(SLOT_ID_ATTRIBUTE)
	local session: Session = {
		Box = box,
		SlotId = if type(slotId) == "string" then slotId else nil,
		OpenAt = openAt,
		Luck = math.max(luck, 1),
		Opener = box:GetAttribute(ShelfOpenState.ByAttribute) == localPlayer.UserId,
		Phase = "Opening",
		Mode = plan.Mode,
		Home = home,
		BaseScale = box:GetScale(),
		Core = coreOf(box),
		TopLocal = Vector3.new(center.X, hi.Y, center.Z),
		CenterLocal = center,
		Movers = buildMovers(box, home, plan, center),
		FlapsDone = false,
		Scaled = false,
		Light = nil,
		LightRoot = nil,
		Beam = nil,
		BeamWidth = 0,
		Glow = nil,
		Sparkles = nil,
		SparkleRate = 0,
		Board = nil,
		BoardScale = nil,
		BoardAt = 0,
		Row = nil,
		RowScale = nil,
		RowPopAt = 0,
		LuckLabel = nil,
		Icon = nil,
		IconRotation = 0,
		LastTick = 0,
		BoxGone = false,
		WaitSince = 0,
		LastCenter = home:PointToWorldSpace(center),
		Item = nil,
		ItemBase = 1,
		ItemPivot = CFrame.identity,
		RevealAt = 0,
		RevealFx = nil,
		Flash = nil,
		Shaft = nil,
		WhiteFlash = nil,
		ItemBoardDone = false,
		Tint = nil,
		TintColor = WHITE,
		TintTransparency = 1,
		TintVisible = false,
		Hidden = nil,
	}
	if plan.Mode == "None" then
		sayOnce(`lid:{box.Name}`, `{box.Name} : ni Lid.FlapL et FlapR, ni Lid : le colis ne s'ouvre pas en 3D`)
	end
	sessions[box] = session
	if Workspace:GetServerTimeNow() - openAt < Logic.FlapTime then
		playSound(SOUND_FLAPS, session.Core)
	end
	-- Ouverture déjà commencée chez les autres (arrivée en cours de route) : pas de tic de rattrapage.
	session.LastTick = Logic.tickIndex(openAt, session.Luck, nil, Workspace:GetServerTimeNow())
	return session
end

local function updateOpening(session: Session, serverNow: number, clock: number)
	local box = session.Box
	local revealAttr = box:GetAttribute(ShelfOpenState.RevealAtAttribute)
	local revealAt: number? = if type(revealAttr) == "number" then revealAttr else nil
	local elapsed = serverNow - session.OpenAt
	if not session.FlapsDone then
		applyMovers(session, Logic.flapAngle(elapsed))
		if elapsed >= Logic.FlapTime then
			applyMovers(session, Logic.FlapAngle)
			session.FlapsDone = true
		end
	end
	if session.FlapsDone and session.Light == nil and session.Phase == "Opening" then
		createLight(session)
	end
	if session.Luck > 1 and session.Board == nil and elapsed >= ShelfOpen.FlapsTime then
		createBoard(session)
	end
	local shown = Logic.shownLuck(session.OpenAt, session.Luck, revealAt, serverNow)
	local tick = Logic.tickIndex(session.OpenAt, session.Luck, revealAt, serverNow)
	if tick > session.LastTick then
		local total = ShelfOpenState.ticksTo(session.Luck)
		if tick - session.LastTick <= 2 then
			playSound(SOUND_TICK, session.Core, Logic.tickPitch(tick, total))
		end
		session.LastTick = tick
		session.RowPopAt = clock
		local icon = session.Icon
		if icon then
			icon.Rotation = session.IconRotation + math.sin(tick) * Logic.IconSwing
		end
	end
	local label = session.LuckLabel
	if label then
		label.Text = Logic.luckText(shown)
	end
	local rowScale = session.RowScale
	if rowScale then
		local q = if session.RowPopAt > 0 then (clock - session.RowPopAt) / Logic.RowPopTime else 1
		rowScale.Scale = if q >= 1 then 1 else Logic.RowPopFrom + (1 - Logic.RowPopFrom) * Logic.backOut(q)
	end
	local boardScale = session.BoardScale
	if boardScale and session.Board then
		boardScale.Scale = Logic.backOut((clock - session.BoardAt) / Logic.BoardPopTime)
	end
	local stop = Logic.stopAt(session.OpenAt, session.Luck, revealAt)
	local k = Logic.growth(shown)
	local factor = 1
	if session.FlapsDone and session.Luck > 1 then
		local rising = serverNow < stop and tick < ShelfOpenState.ticksTo(session.Luck)
		local phase: number? = nil
		if rising and tick > 0 then
			local t = math.min(serverNow, stop) - session.OpenAt - ShelfOpen.FlapsTime
			phase = ShelfOpenState.tickProgress(session.Luck, t) % 1 -- les tics se serrent (L-118 point 4)
		end
		factor = Logic.boxScale(k, phase)
		setBoxScale(session, factor)
	end
	local glowIn = Logic.quadOut((elapsed - Logic.FlapTime) / Logic.GlowTime)
	placeLight(session, factor, k, glowIn)
	if session.Phase == "Opening" then
		local state = box:GetAttribute(ShelfOpenState.StateAttribute)
		if serverNow >= stop or state == "Revealed" or session.BoxGone then
			session.Phase = "Waiting"
			session.WaitSince = clock
		end
	end
end

-- Objet sorti -------------------------------------------------------------------------------------

-- L'ouverture qui attend cet objet : même SlotId, sinon le colis le plus proche (ItemMatchDistance).
local function sessionFor(item: Model): Session?
	local slotId = item:GetAttribute(SLOT_ID_ATTRIBUTE)
	local best: Session? = nil
	local bestDistance = Logic.ItemMatchDistance
	local position = item:GetPivot().Position
	for _, session in sessions do
		if session.Phase == "Revealing" then
			continue
		end
		if type(slotId) == "string" and session.SlotId == slotId then
			return session
		end
		local distance = (session.Home.Position - position).Magnitude
		if distance <= bestDistance then
			best = session
			bestDistance = distance
		end
	end
	return best
end

local function onItem(instance: Instance)
	if not instance:IsA("Model") or items[instance :: Model] then
		return
	end
	local item = instance :: Model
	items[item] = true
	local session = sessionFor(item)
	if session then
		startReveal(session, item)
	else
		attachItemBoard(item, false) -- déjà sorti avant notre arrivée : pas d'animation
	end
end

local function offItem(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local item = instance :: Model
	items[item] = nil
	destroyItemBoard(item)
	for _, session in sessions do
		if session.Item == item then
			session.Item = nil
			dropWhite(session)
		end
	end
end

-- Colis --------------------------------------------------------------------------------------------

local function onBox(instance: Instance)
	if instance:IsA("Model") then
		local box = instance :: Model
		boxes[box] = true
		if WATCH_CHANGES and boxConnections[box] == nil then
			local function changed()
				if boxes[box] then
					watched[box] = true
				end
			end
			boxConnections[box] = {
				box:GetAttributeChangedSignal(ShelfOpenState.StateAttribute):Connect(changed),
				box:GetAttributeChangedSignal(ShelfOpenState.AtAttribute):Connect(changed),
			}
			watched[box] = true -- relu à la prochaine image, comme avant
		end
	end
end

local function offBox(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local box = instance :: Model
	boxes[box] = nil
	watched[box] = nil
	local connections = boxConnections[box]
	if connections then
		boxConnections[box] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	hiddenBoxes[box] = nil
	doneAt[box] = nil
	local session = sessions[box]
	if session then
		session.BoxGone = true
	end
end

local function step()
	local serverNow = Workspace:GetServerTimeNow()
	local clock = os.clock()
	-- a139 : avec PerfClient.ShelfOpenWatchChanges, seuls les colis dont l'état a changé ou n'est pas nil ; les
	-- autres n'ont rien à faire ici (état nil, ni ouverture, ni colis caché, ni ouverture déjà jouée).
	local list: { [Model]: boolean } = if WATCH_CHANGES then watched else boxes
	for box in list do
		local state = box:GetAttribute(ShelfOpenState.StateAttribute)
		local session = sessions[box]
		if state == "Opening" and session == nil then
			-- Une ouverture déjà jouée ici n'est pas rejouée tant que le serveur ne la relance pas (autre heure).
			if doneAt[box] == nil or doneAt[box] ~= box:GetAttribute(ShelfOpenState.AtAttribute) then
				startSession(box)
			end
		elseif state == nil then
			doneAt[box] = nil
			if session and session.Phase ~= "Revealing" then
				finish(session) -- annulée par le serveur : le colis revient comme avant
			end
			local saved = hiddenBoxes[box]
			if saved then
				hiddenBoxes[box] = nil
				showBox(saved)
			end
			watched[box] = nil -- plus rien à faire tant que son état ne change pas (ou qu'une sortie ne finit pas)
		end
	end
	if next(sessions) == nil then
		updateItemBoards(clock)
		return -- a139 : aucune ouverture en cours, pas de copie de la table à chaque image
	end
	for _, session in table.clone(sessions) do
		if session.Phase == "Revealing" then
			updateReveal(session, clock)
		else
			updateOpening(session, serverNow, clock)
			if session.Phase == "Waiting" and clock - session.WaitSince > Logic.RevealWait then
				if session.BoxGone or session.Box:GetAttribute(ShelfOpenState.StateAttribute) == "Revealed" then
					startReveal(session, nil) -- l'objet n'est pas arrivé chez nous : l'éclatement seul
				else
					finish(session)
				end
			end
		end
	end
	updateItemBoards(clock)
end

-- API -----------------------------------------------------------------------------------------------

function ShelfOpenController.GetState(): { SessionState }
	local list: { SessionState } = {}
	local now = Workspace:GetServerTimeNow()
	for box, session in sessions do
		local revealAttr = box:GetAttribute(ShelfOpenState.RevealAtAttribute)
		local revealAt: number? = if type(revealAttr) == "number" then revealAttr else nil
		table.insert(list, {
			Box = box,
			Phase = session.Phase,
			Luck = session.Luck,
			Shown = Logic.shownLuck(session.OpenAt, session.Luck, revealAt, now),
			Mode = session.Mode,
			Item = session.Item,
		})
	end
	return list
end

function ShelfOpenController.GetItemBoards(): { [Instance]: BillboardGui }
	local list: { [Instance]: BillboardGui } = {}
	for item, entry in itemBoards do
		list[item] = entry.Gui
	end
	return list
end

function ShelfOpenController.Start()
	if not Features.ShelfOpen then
		return -- ancienne ouverture en base : rien ici
	end
	local module = script.Parent:FindFirstChild("ShelfBoxController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).Reserve) == "function" then
			shelfBoxApi = result
		end
	end
	CollectionService:GetInstanceAddedSignal(SHELF_BOX_TAG):Connect(onBox)
	CollectionService:GetInstanceRemovedSignal(SHELF_BOX_TAG):Connect(offBox)
	for _, box in CollectionService:GetTagged(SHELF_BOX_TAG) do
		onBox(box)
	end
	CollectionService:GetInstanceAddedSignal(ShelfOpenState.ItemTag):Connect(onItem)
	CollectionService:GetInstanceRemovedSignal(ShelfOpenState.ItemTag):Connect(offItem)
	for _, item in CollectionService:GetTagged(ShelfOpenState.ItemTag) do
		onItem(item)
	end
	local lastError = -math.huge
	RunService.Heartbeat:Connect(function()
		xpcall(step, function(err: any)
			if os.clock() - lastError >= 10 then
				lastError = os.clock()
				warn(`[ShelfOpenController] {err}`)
			end
		end)
	end)
end

return ShelfOpenController
