--!strict
-- Reveal/Unbox (client, vague 73, a251 ; liaison L-236, L-237, L-246 et L-234 ; valeurs : Config/Unbox.New ; plan :
-- Shared/UnboxPlan) : la nouvelle ouverture du colis, jouée par RevealController à la place de son étape Open<Rareté>
-- quand le serveur envoie un plan. Module d'aide (sous-dossier : le Loader ne le démarre pas). Rien n'est décidé ici :
-- la rareté, les améliorations et la cote viennent du plan du serveur.
--
-- Déroulé (une scène = un état, Unbox.Begin puis Unbox.Step à chaque image) :
--   Intro        une copie locale du colis saute du rayon au sol de l'allée (le vrai est caché en local) ; chez
--                l'ouvreur, le perso se place à côté, face au colis, et la caméra se met côté allée (jamais dans un
--                mur : rapprochée, et ce qui reste devant devient transparent) ; BB_UnboxOdds au-dessus du colis ;
--   Action, Gap  une action du plan après l'autre : animation Unbox_* du perso (ouvreur ; ses marqueurs Impact), outil
--                TOOL_Unbox_* dans sa main, réaction du colis, effet, mot BB_UnboxWord et son à chaque Impact ; au
--                dernier Impact attendu (le moment fort) la cote défile, et si la rareté montrée change : le colis
--                grossit, son scotch prend la couleur, FX_Unbox_Tier, « UPGRADE! », zoom et fondu des bords ; entre
--                deux actions, le colis tremble de plus en plus. Animation absente ou vide, et spectateurs : mêmes
--                Impacts aux instants de repli de la Config ;
--   Burst        moment fort de la dernière action : le colis éclate (FX_Unbox_Burst, FX_RevealSmash pour un objet
--                géant), le perso recule ; évènement « Burst » ;
--   Silhouettes  une silhouette noire par rareté, de la plus basse à la rareté gagnée (objets de la zone, la dernière
--                est le vrai objet, qui tremble) : FX_Unbox_Silhouette, FX_Unbox_Puff, nom de la rareté, zoom, bords ;
--   Overexpose   la dernière silhouette toute blanche, puis évènement « Reveal » (RevealController montre l'objet,
--                BB_Reveal, ses sons) ; Unbox.OnReveal : FX_Unbox_Reveal, zoom et bords plus forts, cote finale ;
--   After        évènement « Done » après AfterReveal : RevealController enchaîne sur sa croissance (Grow<Classe>).
-- Tout élément de Clément est facultatif : effet, outil, objet jeté ou billboard absent = rien (BB_UnboxOdds : un
-- billboard du code aux mêmes noms).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local UnboxConfig = require(Config:WaitForChild("Unbox"))
local RevealConfig = require(Config:WaitForChild("Reveal"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UI = require(Shared:WaitForChild("Contract"):WaitForChild("UI"))
local AnimPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("AnimPlayer"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local UnboxPlan = require(Shared:WaitForChild("UnboxPlan"))

local New = UnboxConfig.New
local REACT = New.React
local CAM = New.Camera
local UP = Vector3.new(0, 1, 0)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local KRAFT = Color3.fromRGB(176, 132, 84)

export type Context = {
	Id: string,
	Opener: boolean, -- la scène du joueur local
	Player: Player?, -- l'ouvreur
	Store: Model?,
	SlotFrame: CFrame, -- emplacement du rayon
	AisleHint: Vector3, -- direction à plat vers le centre du magasin
	ShelfBox: Instance?, -- le colis du rayon (serveur)
	Rarity: string, -- rareté gagnée
	SizeClass: string,
	ItemId: string,
	ItemScale: number, -- taille de départ de l'objet (comme à sa révélation)
	Plan: UnboxPlan.Plan,
	LowEnd: boolean,
	Folder: Instance, -- où poser ce qui est créé (Workspace/_RevealFX)
	Hide: (part: BasePart) -> (), -- cache une pièce en local jusqu'à la fin de la scène (remise par RevealController)
	ItemTop: () -> number, -- hauteur (Y du monde) du haut de l'objet révélé, en ce moment
}

type Pulse = { value: number, target: number, hold: number }
type Word = { board: BillboardGui, label: TextLabel?, scale: UIScale?, t: number, from: Vector3, drift: Vector3 }
type Junk = { model: PVInstance, position: Vector3, velocity: Vector3, spin: number, angle: number, t: number }
type Timed = { inst: Instance, left: number }

export type State = {
	ctx: Context,
	phase: string,
	t: number, -- secondes dans la phase
	events: { string },
	base: CFrame, -- pied du colis au sol de l'allée, LookVector vers l'allée (là où l'objet sortira)
	side: Vector3, -- du colis vers le perso
	stand: CFrame?, -- où se tient le perso de l'ouvreur
	home: CFrame, -- pivot du colis sur son rayon
	floor: CFrame, -- pivot du colis posé au sol
	box: Model?,
	boxScale0: number,
	boxHeight: number, -- à la taille de départ
	tierScale: number,
	appliedScale: number,
	lid: PVInstance?,
	lidOffset: CFrame,
	tapes: { BasePart },
	anchor: BasePart,
	board: BillboardGui?,
	boardOffset: number,
	oddsLabel: TextLabel?,
	rarityLabel: TextLabel?,
	upgradeLabel: GuiObject?,
	oddsScale: UIScale?,
	odds: number, -- cote montrée
	oddsFrom: number,
	oddsTo: number,
	oddsT: number, -- avancement du défilement, < 0 : aucun
	oddsTicks: number,
	upgradeLeft: number,
	finalLeft: number, -- temps restant de la cote finale, après la révélation
	tier: string, -- rareté montrée
	index: number, -- action en cours
	mode: string, -- "Anim" ou "Fallback"
	track: AnimationTrack?,
	trackStopped: boolean,
	connections: { RBXScriptConnection },
	impacts: number,
	strong: boolean, -- moment fort de l'action passé
	tool: PVInstance?,
	toolOffset: CFrame,
	mark: BillboardGui?,
	runFx: Instance?,
	runEvery: number,
	runLeft: number,
	react: string?,
	reactT: number,
	reactForce: number,
	words: { Word },
	junk: { Junk },
	junkIndex: number,
	timed: { Timed },
	silhouette: Model?,
	silhouetteIndex: number,
	silhouetteCount: number,
	silhouetteHome: CFrame,
	spin: number,
	zoom: Pulse,
	edge: Pulse,
	edgeColor: Color3,
	edgeLabel: ImageLabel?,
	edgeScreen: ScreenGui?,
	edgeWasEnabled: boolean,
	baseFov: number?,
	seeThrough: { Instance }, -- pièces rendues transparentes devant la caméra
	ignored: { Instance }, -- pièces invisibles que la caméra traverse
	muted: { Instance }, -- étiquette BB_Box et contour du vrai colis, éteints tant que la scène dure
	recoilLeft: number,
	revealed: boolean,
	released: boolean,
	destroyed: boolean,
	created: { Instance },
}

local Unbox = {}

-- Aides ------------------------------------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function partsOf(root: Instance): { BasePart }
	local out: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(out, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Copie locale inerte : sans script, sans tag, sans invite, ancrée, sans collision.
local function inert(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local function untag(inst: Instance)
		pcall(function()
			for _, tag in CollectionService:GetTags(inst) do
				CollectionService:RemoveTag(inst, tag)
			end
		end)
	end
	untag(root)
	for _, d in root:GetDescendants() do
		untag(d)
	end
	for _, part in partsOf(root) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.LocalTransparencyModifier = 0
	end
end

local function asModel(inst: Instance): Model
	if inst:IsA("Model") then
		return inst
	end
	local wrapper = Instance.new("Model")
	inst.Parent = wrapper
	if inst:IsA("BasePart") then
		wrapper.PrimaryPart = inst
	end
	return wrapper
end

local function block(size: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = CFrame.new(0, size.Y / 2, 0)
	root.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
	root.Color = color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function extents(model: Model): Vector3
	local ok, size = pcall(function()
		return model:GetExtentsSize()
	end)
	if ok and typeof(size) == "Vector3" and (size :: Vector3).Y > 0 then
		return size :: Vector3
	end
	return Vector3.new(2, 1.6, 2)
end

local function scaleOf(model: Model): number
	local ok, scale = pcall(function()
		return model:GetScale()
	end)
	return if ok and type(scale) == "number" and scale > 0 then scale else 1
end

local function scaleTo(model: Model, scale: number)
	pcall(function()
		model:ScaleTo(math.max(scale, 0.01))
	end)
end

local function walk(path: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in path do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

local function rarityOf(id: string): Rarities.Rarity?
	return Rarities.ById[id]
end

local function colorOf(id: string): Color3
	local rarity = rarityOf(id)
	return if rarity then rarity.Color else WHITE
end

local function rankOf(id: string): number
	local rarity = rarityOf(id)
	return if rarity then math.max(rarity.Order - 1, 0) else 0
end

local function characterOf(state: State): Model?
	local player = state.ctx.Player
	return if player then player.Character else nil
end

local function rootOf(state: State): BasePart?
	local character = characterOf(state)
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Son de la scène : 2D chez l'ouvreur, sur l'ancre du colis chez un spectateur ; absent = muet.
local function sound(state: State, name: string?, pitch: number?): boolean
	if name == nil then
		return false
	end
	local template = MarkerSounds.find(name)
	if template == nil then
		return false
	end
	local ok, played = pcall(MarkerSounds.playSound, template, if state.ctx.Opener then nil else state.anchor)
	if ok and pitch and typeof(played) == "Instance" then
		pcall(function()
			(played :: any).PlaybackSpeed = pitch
		end)
	end
	return ok
end

local function raycast(origin: Vector3, direction: Vector3, exclude: { Instance }, respectCollide: boolean): RaycastResult?
	local ok, result = pcall(function(): RaycastResult?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		params.RespectCanCollide = respectCollide
		return Workspace:Raycast(origin, direction, params)
	end)
	return if ok then result else nil
end

local function excluded(state: State?, ctx: Context): { Instance }
	local list: { Instance } = { ctx.Folder }
	if ctx.ShelfBox then
		table.insert(list, ctx.ShelfBox)
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(list, character)
		end
	end
	if state then
		for _, inst in state.seeThrough do
			table.insert(list, inst)
		end
		for _, inst in state.ignored do
			table.insert(list, inst)
		end
	end
	return list
end

-- Effets -----------------------------------------------------------------------------------------------------------

local function emitAll(root: Instance, color: Color3?)
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			if color and d:GetAttribute("RarityColor") then
				d.Color = ColorSequence.new(color)
			end
			local count = d:GetAttribute("EmitCount")
			d:Emit(if type(count) == "number" then count else New.FxEmit)
		end
	end
end

-- Copie d'un effet de Assets/FX posée au pied `foot` (ses Attachments FxTopAttachments au point `top`), comme
-- FX_ShelfReveal : émetteurs à Rate 0 lancés une fois (attribut EmitCount), RarityColor = couleur de la rareté,
-- détruite après son attribut Duration. `emit` faux : rien n'est lancé (effet rythmé par EmitEvery).
local function spawnFx(state: State, name: string?, foot: CFrame, top: Vector3?, color: Color3?, emit: boolean): Instance?
	if name == nil or state.ctx.LowEnd then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("FX") else nil
	local template = if folder then folder:FindFirstChild(name, true) else nil
	if template == nil or not template:IsA("PVInstance") then
		return nil
	end
	local copy = template:Clone()
	inert(copy)
	copy:PivotTo(foot)
	copy.Parent = state.ctx.Folder
	if top then
		for _, d in copy:GetDescendants() do
			if d:IsA("Attachment") and table.find(New.FxTopAttachments, d.Name) then
				local parent = d.Parent
				if parent and parent:IsA("BasePart") then
					d.Position = parent.CFrame:PointToObjectSpace(top)
				else
					d.WorldPosition = top
				end
			end
		end
	end
	if emit then
		emitAll(copy, color)
	end
	local life = copy:GetAttribute("Duration")
	table.insert(state.timed, { inst = copy, left = if type(life) == "number" and life > 0 then life else New.FxLife })
	return copy
end

local function pulse(p: Pulse, target: number, hold: number)
	p.target = math.max(target, 0)
	p.hold = hold
end

local function stepPulse(p: Pulse, dt: number, rise: number, fall: number)
	if p.hold > 0 then
		p.hold -= dt
		p.value += (p.target - p.value) * math.min(1, dt / math.max(rise, 1e-3))
	else
		p.value += (0 - p.value) * math.min(1, dt / math.max(fall, 1e-3))
	end
end

-- Zoom et fondu des bords à la couleur de `rarity` (ouvreur seul). `reveal` : les valeurs de la révélation.
local function flash(state: State, rarity: string, reveal: boolean)
	if not state.ctx.Opener then
		return
	end
	local amount = (if reveal then New.ZoomReveal else New.ZoomStep) * (1 + New.ZoomRank * rankOf(rarity))
	pulse(state.zoom, math.min(amount, New.ZoomMax), New.ZoomIn + New.ZoomHold)
	pulse(state.edge, 1 - (if reveal then New.EdgeReveal else New.EdgeStep), New.EdgeIn + New.EdgeHold)
	state.edgeColor = colorOf(rarity)
end

-- Colis ------------------------------------------------------------------------------------------------------------

local function boxTop(state: State): Vector3
	local scale = state.tierScale
	local pivot = if state.phase == "Intro" then state.home:Lerp(state.floor, math.clamp(state.t / New.Intro, 0, 1)) else state.floor
	return pivot.Position + UP * (state.boxHeight * scale)
end

local function reactNow(state: State, kind: string, force: number)
	state.react = kind
	state.reactT = 0
	state.reactForce = force
end

local function poseBox(state: State, dt: number)
	local box = state.box
	if box == nil then
		return
	end
	local pivot = state.floor
	if state.phase == "Intro" then
		local f = math.clamp(state.t / New.Intro, 0, 1)
		local eased = (1 - math.cos(math.pi * f)) / 2
		pivot = state.home:Lerp(state.floor, eased) + UP * (New.BoxHop * math.sin(math.pi * f))
	end
	local offset = Vector3.zero
	local tilt, yaw, squash, lidUp = 0, 0, 0, 0
	local kind = state.react
	if kind then
		state.reactT += dt
		local duration = if kind == "Push" then REACT.Time * 2 else REACT.Time
		local f = state.reactT / duration
		if f >= 1 then
			state.react = nil
		else
			local wave = math.sin(math.pi * f) * state.reactForce
			if kind == "Jump" then
				offset = UP * (REACT.Jump * wave)
			elseif kind == "Tilt" then
				tilt = REACT.Tilt * wave
			elseif kind == "Squash" then
				squash = REACT.Squash * wave
			elseif kind == "Spin" then
				yaw = REACT.Spin * wave
			elseif kind == "Slide" then
				offset = -state.side * (REACT.Slide * wave)
			elseif kind == "Push" then
				offset = -state.side * (REACT.Push * wave)
			elseif kind == "Lid" then
				lidUp = wave
				offset = UP * (REACT.Jump * 0.4 * wave)
			end
		end
	end
	if state.phase == "Gap" then
		local amplitude = REACT.Tremble + REACT.TrembleStep * state.index
		offset += Vector3.new((math.random() - 0.5) * 2 * amplitude, 0, (math.random() - 0.5) * 2 * amplitude)
	end
	local scale = state.boxScale0 * state.tierScale * (1 - squash)
	if math.abs(scale - state.appliedScale) > 1e-3 then
		state.appliedScale = scale
		scaleTo(box, scale)
	end
	local frame = (pivot + offset) * CFrame.Angles(tilt, yaw, 0)
	pcall(function()
		box:PivotTo(frame)
	end)
	local lid = state.lid
	if lid and lid.Parent ~= nil then
		local ratio = scale / state.boxScale0
		local rest = CFrame.new(state.lidOffset.Position * ratio) * state.lidOffset.Rotation
		pcall(function()
			lid:PivotTo(frame * rest * CFrame.new(0, REACT.LidLift * lidUp, 0) * CFrame.Angles(REACT.LidTilt * lidUp, 0, 0))
		end)
	end
	state.anchor.CFrame = CFrame.new(pivot.Position + UP * math.max(state.boxHeight * state.tierScale - New.OddsBelowTop, 0))
end

local function buildBox(state: State)
	local ctx = state.ctx
	local source = ctx.ShelfBox
	local box: Model? = nil
	if source and (source:IsA("Model") or source:IsA("BasePart")) then
		local ok, copy = pcall(function()
			return source:Clone()
		end)
		if ok and copy then
			box = asModel(copy)
		end
	end
	local model = box or block(Vector3.new(2, 1.6, 2), KRAFT)
	inert(model)
	model.Name = "UnboxBox"
	state.box = model
	state.boxScale0 = scaleOf(model)
	state.appliedScale = state.boxScale0
	state.boxHeight = extents(model).Y
	local lid = model:FindFirstChild("Lid", true)
	if lid and lid:IsA("PVInstance") then
		state.lid = lid
		state.lidOffset = model:GetPivot():ToObjectSpace(lid:GetPivot())
	end
	for _, part in partsOf(model) do
		if table.find(New.TapeNames, part.Name) then
			table.insert(state.tapes, part)
		end
	end
	model.Parent = ctx.Folder
	table.insert(state.created, model)
end

local function dropBox(state: State)
	local box = state.box
	if box then
		state.box = nil
		box:Destroy()
	end
end

-- Billboards -------------------------------------------------------------------------------------------------------

local function billboard(name: string): BillboardGui?
	local folder = walk(UI.BillboardFolder)
	local found = if folder then folder:FindFirstChild(name) else nil
	if found and found:IsA("BillboardGui") then
		return found:Clone()
	end
	return nil
end

local function v0Board(): BillboardGui
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(6, 2.6)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	for index, name in { "Upgrade", "Odds", "Rarity" } do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, if name == "Odds" then 0.45 else 0.27)
		label.Position = UDim2.fromScale(0, if index == 1 then 0 elseif index == 2 then 0.27 else 0.72)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = WHITE
		label.TextStrokeTransparency = 0
		label.Text = if name == "Upgrade" then "UPGRADE!" else ""
		label.Parent = board
	end
	return board
end

local function label(root: Instance, name: string): TextLabel?
	local found = Find.path(root, name)
	return if found and found:IsA("TextLabel") then found else nil
end

local function popScale(parent: Instance): UIScale
	local existing = parent:FindFirstChild("UnboxPop")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "UnboxPop"
	scale.Parent = parent
	return scale
end

local function showRarity(state: State, rarity: string)
	local text = state.rarityLabel
	local info = rarityOf(rarity)
	if text then
		text.Visible = true
		text.Text = if info then info.DisplayNameUpper else string.upper(rarity)
		text.TextColor3 = colorOf(rarity)
	end
end

local function showOdds(state: State, value: number)
	state.odds = value
	local text = state.oddsLabel
	if text then
		text.Text = UnboxPlan.oddsText(value)
	end
end

local function buildBoard(state: State)
	local board = billboard(New.OddsBoard) or v0Board()
	board.Name = "UnboxOdds"
	board.Adornee = state.anchor
	state.board = board
	state.boardOffset = board.StudsOffsetWorldSpace.Y
	state.oddsLabel = label(board, "Odds")
	state.rarityLabel = label(board, "Rarity")
	local upgrade = Find.path(board, "Upgrade")
	if upgrade and upgrade:IsA("GuiObject") then
		upgrade.Visible = false
		state.upgradeLabel = upgrade
	end
	if state.oddsLabel then
		state.oddsScale = popScale(state.oddsLabel)
	end
	showRarity(state, state.tier)
	showOdds(state, UnboxPlan.oddsAt(state.ctx.Plan, 0))
	board.Parent = state.ctx.Folder
	table.insert(state.created, board)
end

local function showWord(state: State, word: string?)
	if word == nil then
		return
	end
	local board = billboard(New.WordBoard)
	if board == nil then
		return
	end
	local text = label(board, "Word")
	if text then
		text.Text = word
	end
	board.Adornee = state.anchor
	local from = board.StudsOffsetWorldSpace
	local drift = Vector3.new((math.random() - 0.5) * 1.6, 0, (math.random() - 0.5) * 1.6)
	board.Parent = state.ctx.Folder
	table.insert(state.words, { board = board, label = text, scale = if text then popScale(text) else nil, t = 0, from = from, drift = drift })
end

local function stepWords(state: State, dt: number)
	for index = #state.words, 1, -1 do
		local word = state.words[index]
		word.t += dt
		local f = word.t / New.WordTime
		if f >= 1 then
			word.board:Destroy()
			table.remove(state.words, index)
			continue
		end
		word.board.StudsOffsetWorldSpace = word.from + word.drift * f + UP * (New.WordRise * f)
		if word.scale then
			word.scale.Scale = 0.6 + (New.WordPop - 0.6) * math.min(f * 3, 1)
		end
		local fade = math.clamp((f - 0.6) / 0.4, 0, 1)
		local text = word.label
		if text then
			text.TextTransparency = fade
			for _, d in text:GetDescendants() do
				if d:IsA("UIStroke") then
					d.Transparency = fade
				end
			end
		end
	end
end

local function dropMark(state: State)
	local mark = state.mark
	if mark then
		state.mark = nil
		mark:Destroy()
	end
end

local function showMark(state: State, text: string)
	local mark = state.mark
	if mark == nil then
		local character = characterOf(state)
		local head = if character then character:FindFirstChild("Head") else nil
		local board = billboard(New.MarkBoard)
		if board == nil or head == nil or not head:IsA("BasePart") then
			if board then
				board:Destroy()
			end
			return
		end
		board.Adornee = head
		board.Parent = state.ctx.Folder
		state.mark = board
		mark = board
	end
	local content = label(mark :: BillboardGui, "Mark")
	if content then
		content.Text = text
	end
end

-- Outil et objets jetés --------------------------------------------------------------------------------------------

local function dropTool(state: State)
	local tool = state.tool
	if tool then
		state.tool = nil
		tool:Destroy()
	end
end

local function poseTool(state: State)
	local tool = state.tool
	local character = characterOf(state)
	local hand = if character then character:FindFirstChild(New.ToolHand) else nil
	if tool == nil or hand == nil or not hand:IsA("BasePart") then
		return
	end
	local grip = hand:FindFirstChild(New.ToolGrip)
	local frame = if grip and grip:IsA("Attachment") then grip.WorldCFrame else hand.CFrame
	local angles = New.ToolGripAngles
	local target = frame * CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3])) * state.toolOffset
	pcall(function()
		tool:PivotTo(target)
	end)
end

local function takeTool(state: State, name: string?)
	dropTool(state)
	local folder = walk(New.ToolFolder)
	local template = if folder and name then folder:FindFirstChild(name) else nil
	if template == nil or not template:IsA("PVInstance") then
		return
	end
	local copy = template:Clone()
	inert(copy)
	local handle = copy:FindFirstChild("Handle", true)
	state.toolOffset = if handle and handle:IsA("BasePart") then handle.CFrame:ToObjectSpace(copy:GetPivot()) else CFrame.identity
	state.tool = copy
	poseTool(state)
	copy.Parent = state.ctx.Folder
end

local function throwJunk(state: State)
	local folder = walk(New.ToolFolder)
	if folder == nil or state.ctx.LowEnd then
		return
	end
	local list: { Instance } = {}
	for _, child in folder:GetChildren() do
		if string.sub(child.Name, 1, #New.JunkPrefix) == New.JunkPrefix and child:IsA("PVInstance") then
			table.insert(list, child)
		end
	end
	if #list == 0 then
		return
	end
	table.sort(list, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	state.junkIndex += 1
	local copy = list[(state.junkIndex + state.ctx.Plan.Odds) % #list + 1]:Clone()
	if not copy:IsA("PVInstance") then
		return
	end
	inert(copy)
	local from = boxTop(state)
	copy:PivotTo(CFrame.new(from))
	copy.Parent = state.ctx.Folder
	table.insert(state.junk, {
		model = copy,
		position = from,
		velocity = UP * New.JunkSpeedUp + state.side * New.JunkSpeedBack,
		spin = New.JunkSpin * (0.6 + math.random() * 0.8),
		angle = 0,
		t = 0,
	})
end

local function stepJunk(state: State, dt: number)
	for index = #state.junk, 1, -1 do
		local junk = state.junk[index]
		junk.t += dt
		if junk.t >= New.JunkLife then
			junk.model:Destroy()
			table.remove(state.junk, index)
			continue
		end
		junk.velocity -= UP * (New.JunkGravity * dt)
		junk.position += junk.velocity * dt
		junk.angle += junk.spin * dt
		pcall(function()
			junk.model:PivotTo(CFrame.new(junk.position) * CFrame.Angles(junk.angle, junk.angle * 0.7, 0))
		end)
	end
end

-- Silhouettes ------------------------------------------------------------------------------------------------------

local function blacken(model: Model, color: Color3, material: Enum.Material)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = color
			d.Material = material
			if d:IsA("MeshPart") then
				pcall(function()
					d.TextureID = ""
				end)
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		elseif d:IsA("Decal") or d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
end

local function itemTemplate(itemId: string): Instance?
	local def = Items.ById[itemId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("Items") else nil
	local template = if folder and def then folder:FindFirstChild(def.Asset, true) else nil
	return if template and (template:IsA("Model") or template:IsA("BasePart")) then template else nil
end

-- Objet montré en silhouette pour la rareté `rarity` : un objet de la zone du magasin, sinon de n'importe quelle zone.
local function silhouetteItem(state: State, rarity: string, index: number): string?
	local store = state.ctx.Store
	local zone = if store then store:GetAttribute("Zone") else nil
	local byZone: any = if type(zone) == "number" then (Items.ByZone :: any)[zone] else nil
	local zoned: { Items.Item }? = if byZone then byZone[rarity] else nil
	local everywhere: { Items.Item }? = (Items.AllZones :: any)[rarity]
	local list: { Items.Item } = {}
	if zoned and #zoned > 0 then
		list = zoned
	elseif everywhere and #everywhere > 0 then
		list = everywhere
	else
		for _, item in Items.List do
			if item.Rarity == rarity and not item.TutorialOnly then
				table.insert(list, item)
			end
		end
	end
	if #list == 0 then
		return nil
	end
	return list[(state.ctx.Plan.Odds + index) % #list + 1].Id
end

local function dropSilhouette(state: State)
	local silhouette = state.silhouette
	if silhouette then
		state.silhouette = nil
		silhouette:Destroy()
	end
end

local function silhouetteTop(state: State): Vector3
	local silhouette = state.silhouette
	local height = if silhouette then extents(silhouette).Y else 2
	return state.base.Position + UP * height
end

local function showSilhouette(state: State, index: number)
	dropSilhouette(state)
	local ctx = state.ctx
	local rarity = Rarities.List[index].Id
	local last = index >= state.silhouetteCount
	local itemId = if last then ctx.ItemId else silhouetteItem(state, rarity, index)
	local template = if itemId then itemTemplate(itemId) else nil
	local model: Model
	if template then
		model = asModel(template:Clone())
	else
		model = block(Vector3.new(1.2, 1.6, 1.2), BLACK)
	end
	inert(model)
	blacken(model, BLACK, Enum.Material.SmoothPlastic)
	model.Name = "UnboxSilhouette"
	if last then
		scaleTo(model, scaleOf(model) * ctx.ItemScale)
	else
		local size = extents(model)
		local longest = math.max(size.X, size.Y, size.Z, 0.1)
		scaleTo(model, scaleOf(model) * New.SilhouetteFit * (1 + New.SilhouetteGrow * (index - 1)) / longest)
	end
	state.silhouetteIndex = index
	state.silhouetteHome = state.base
	model:PivotTo(state.base * CFrame.Angles(0, if last then 0 else state.spin, 0))
	model.Parent = ctx.Folder
	state.silhouette = model
	local top = silhouetteTop(state)
	local center = state.base.Position:Lerp(top, 0.5)
	state.anchor.CFrame = CFrame.new(top - UP * New.OddsBelowTop)
	showRarity(state, rarity)
	local color = colorOf(rarity)
	spawnFx(state, New.Fx.Silhouette, CFrame.new(center), nil, color, true)
	spawnFx(state, New.Fx.Puff, CFrame.new(center), nil, color, true)
	flash(state, rarity, false)
	sound(state, New.SilhouetteSound, 1 + 0.06 * (index - 1))
	if last then
		sound(state, New.SuspenseSound)
	end
end

-- Actions ----------------------------------------------------------------------------------------------------------

local function stopTrack(state: State, fade: number)
	for _, connection in state.connections do
		connection:Disconnect()
	end
	table.clear(state.connections)
	local track = state.track
	state.track = nil
	if track then
		pcall(function()
			track:Stop(fade)
		end)
	end
end

local function stopRunFx(state: State)
	state.runFx = nil
end

local function burst(state: State)
	local ctx = state.ctx
	local giant = ctx.SizeClass == "Large" or ctx.SizeClass == "Colossal"
	local foot = CFrame.new(state.floor.Position)
	local color = colorOf(state.tier)
	if spawnFx(state, if giant then New.Fx.GiantBurst else New.Fx.Burst, foot, boxTop(state), color, true) == nil and giant then
		spawnFx(state, New.Fx.Burst, foot, boxTop(state), color, true)
	end
	dropBox(state)
	local text = state.oddsLabel
	if text then
		text.Visible = false
	end
	local rarityText = state.rarityLabel
	if rarityText then
		rarityText.Visible = false
	end
	local upgrade = state.upgradeLabel
	if upgrade then
		upgrade.Visible = false
	end
	state.oddsT = -1
	state.recoilLeft = New.RecoilTime
	state.phase = "Burst"
	state.t = 0
	table.insert(state.events, "Burst")
end

-- Moment fort de l'action en cours : la cote défile, le colis s'améliore si la rareté montrée change ; à la dernière
-- action, le colis éclate.
local function momentFort(state: State)
	if state.strong then
		return
	end
	state.strong = true
	stopRunFx(state)
	local plan = state.ctx.Plan
	if state.index >= #plan.Steps then
		burst(state)
		return
	end
	state.oddsFrom = state.odds
	state.oddsTo = math.max(UnboxPlan.oddsAt(plan, state.index), state.odds)
	state.oddsT = 0
	state.oddsTicks = 0
	local rarity = plan.Steps[state.index].Rarity
	if rarity ~= state.tier then
		state.tier = rarity
		state.tierScale *= New.UpgradeGrow
		local color = colorOf(rarity)
		for _, tape in state.tapes do
			tape.Color = color
		end
		showRarity(state, rarity)
		local upgrade = state.upgradeLabel
		if upgrade then
			upgrade.Visible = true
			state.upgradeLeft = New.UpgradeShow
		end
		spawnFx(state, New.Fx.Tier, CFrame.new(state.floor.Position), boxTop(state), color, true)
		flash(state, rarity, false)
		sound(state, New.UpgradeSound)
	end
end

local function onImpact(state: State)
	if state.phase ~= "Action" then
		return
	end
	local step = state.ctx.Plan.Steps[state.index]
	if step == nil then
		return
	end
	local action = step.Action
	state.impacts += 1
	local strong = state.impacts >= #action.Impacts and not state.strong
	reactNow(state, action.React, if strong then 1 else REACT.Before)
	spawnFx(state, action.Fx, CFrame.new(state.floor.Position), boxTop(state), colorOf(state.tier), true)
	showWord(state, action.Word)
	if not sound(state, action.Sound) then
		sound(state, New.ImpactSound)
	end
	if action.Junk then
		throwJunk(state)
	end
	if action.Mark and strong then
		showMark(state, New.MarkImpact)
	end
	if strong then
		momentFort(state)
	end
end

local function startAction(state: State, index: number)
	local ctx = state.ctx
	local step = ctx.Plan.Steps[index]
	state.index = index
	state.phase = "Action"
	state.t = 0
	state.impacts = 0
	state.strong = false
	state.mode = "Fallback"
	state.trackStopped = false
	local action = step.Action
	takeTool(state, action.Tool)
	dropMark(state)
	if action.Mark then
		showMark(state, New.MarkStart)
	end
	if action.RunFx then
		local fx = spawnFx(state, action.RunFx, CFrame.new(state.floor.Position), boxTop(state), colorOf(state.tier), false)
		local every = if fx then fx:GetAttribute("EmitEvery") else nil
		state.runFx = fx
		state.runEvery = if type(every) == "number" and every > 0 then every else 0.06
		state.runLeft = 0
	end
	if not ctx.Opener then
		return
	end
	local character = characterOf(state)
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	local animation = AnimPlayer.findAnimation(AnimPlayer.playerFolder(), action.Anim)
	if animator == nil or animation == nil then
		return
	end
	local found: Animation = animation
	local ok, loaded = pcall(function(): AnimationTrack
		return animator:LoadAnimation(found)
	end)
	if not ok then
		return
	end
	local track = loaded :: AnimationTrack
	table.insert(state.connections, track:GetMarkerReachedSignal("Impact"):Connect(function()
		if state.track == track and not state.destroyed then
			onImpact(state)
		end
	end))
	table.insert(state.connections, track.Stopped:Connect(function()
		if state.track == track then
			state.trackStopped = true
		end
	end))
	state.track = track
	state.mode = "Anim"
	pcall(function()
		track:Play(0.1)
		track:AdjustSpeed(math.max(New.ActionSpeed, 0.1))
	end)
end

local function endAction(state: State)
	if state.phase ~= "Action" then
		return
	end
	momentFort(state) -- au plus tard à la fin de l'action
	if state.phase ~= "Action" then
		return -- dernière action : le colis a éclaté
	end
	stopTrack(state, 0.1)
	dropTool(state)
	dropMark(state)
	state.phase = "Gap"
	state.t = 0
end

local function stepAction(state: State, dt: number)
	local step = state.ctx.Plan.Steps[state.index]
	local action = step.Action
	local fx = state.runFx
	if fx then
		state.runLeft -= dt
		if state.runLeft <= 0 then
			state.runLeft = state.runEvery
			emitAll(fx, colorOf(state.tier))
		end
	end
	if state.mode == "Anim" then
		local track = state.track
		if track == nil then
			state.mode = "Fallback"
			state.t = 0
			return
		end
		if track.Length <= 0 then
			if state.t >= RevealConfig.AnimLoadWait then
				stopTrack(state, 0)
				state.mode = "Fallback"
				state.t = 0
			end
			return
		end
		if state.trackStopped or (not track.IsPlaying and state.t > 0.1) or state.t >= UnboxPlan.actionLimit(action) then
			endAction(state)
		end
		return
	end
	local duration = UnboxPlan.actionTime(action)
	for index, at in action.Impacts do
		if state.phase == "Action" and index > state.impacts and state.t >= at * duration then
			onImpact(state)
		end
	end
	if state.phase == "Action" and state.t >= duration then
		endAction(state)
	end
end

-- Place du colis, du perso et de la caméra -------------------------------------------------------------------------

local function insideBounds(store: Model?, point: Vector3): boolean
	local bounds = if store then store:FindFirstChild("Bounds", true) else nil
	if bounds == nil or not bounds:IsA("BasePart") then
		return true
	end
	local at = bounds.CFrame:PointToObjectSpace(point)
	return math.abs(at.X) <= bounds.Size.X / 2 and math.abs(at.Z) <= bounds.Size.Z / 2
end

-- Sol sous `point` : rayon vers le bas depuis la hauteur de l'emplacement, sinon le bas de Bounds, sinon `point`.
local function floorUnder(ctx: Context, point: Vector3, exclude: { Instance }): number
	local hit = raycast(point + UP, -UP * (New.FloorProbe + 1), exclude, true)
	if hit then
		return hit.Position.Y
	end
	local store = ctx.Store
	local bounds = if store then store:FindFirstChild("Bounds", true) else nil
	if bounds and bounds:IsA("BasePart") then
		return bounds.Position.Y - bounds.Size.Y / 2
	end
	return point.Y
end

-- Où poser le colis au sol : depuis l'emplacement du rayon, la direction dégagée qui descend le plus bas, dans le
-- magasin (face avant de l'emplacement d'abord, puis vers le centre du magasin, puis les autres côtés).
local function place(ctx: Context): (Vector3, Vector3)
	local slot = ctx.SlotFrame
	local exclude = excluded(nil, ctx)
	local candidates: { Vector3 } = {}
	for _, v in { slot.LookVector, ctx.AisleHint, -slot.LookVector, slot.RightVector, -slot.RightVector } do
		local direction = flat(v)
		if direction then
			table.insert(candidates, direction)
		end
	end
	if #candidates == 0 then
		candidates = { Vector3.new(0, 0, -1) }
	end
	local need = New.BoxOut + New.BoxClear
	local origin = slot.Position + UP
	local best: Vector3? = nil
	local bestFloor = math.huge
	local widest, widestFree = candidates[1], -1
	for _, direction in candidates do
		local hit = raycast(origin, direction * (need + 4), exclude, true)
		local free = if hit then (hit.Position - origin).Magnitude else need + 4
		if free > widestFree then
			widest, widestFree = direction, free
		end
		local point = slot.Position + direction * New.BoxOut
		if free >= need and insideBounds(ctx.Store, point) then
			local y = floorUnder(ctx, point, exclude)
			if y < bestFloor - 0.25 then
				best, bestFloor = direction, y
			end
		end
	end
	local direction = best or widest
	local out = if best then New.BoxOut else math.clamp(widestFree - New.BoxClear, math.min(New.BoxOutMin, New.BoxOut), New.BoxOut)
	local point = slot.Position + direction * out
	local y = if best then bestFloor else floorUnder(ctx, point, exclude)
	return Vector3.new(point.X, y, point.Z), direction
end

-- Vue dégagée du point `focus` vers `from` (ouvreur) : un obstacle assez loin rapproche la caméra devant lui ; plus
-- près que MinDistance, il devient transparent pour ce joueur jusqu'à la fin de la scène (L-234).
function Unbox.Clear(state: State, from: Vector3, focus: Vector3): Vector3
	if not state.ctx.Opener or state.destroyed then
		return from
	end
	local offset = from - focus
	local distance = offset.Magnitude
	if distance < 1e-3 then
		return from
	end
	for _ = 1, 6 do
		local hit = raycast(focus, offset, excluded(state, state.ctx), false)
		if hit == nil then
			return from
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or #state.ignored + #state.seeThrough >= CAM.MaxHidden * 2 then
			return from
		end
		if part.Transparency >= 0.95 then
			table.insert(state.ignored, part) -- volume invisible : ni mur, ni rien à cacher
			continue
		end
		local reach = (hit.Position - focus).Magnitude
		if reach - CAM.Margin >= CAM.MinDistance then
			return focus + offset.Unit * (reach - CAM.Margin)
		end
		if #state.seeThrough >= CAM.MaxHidden then
			return from
		end
		table.insert(state.seeThrough, part)
		state.ctx.Hide(part)
	end
	return from
end

-- Caméra de l'ouvreur pendant l'ouverture : côté allée, le colis et le perso de profil.
function Unbox.CameraTarget(state: State): CFrame
	local aisle = state.base.LookVector
	local foot = state.base.Position
	local focus = foot + state.side * (New.StandSide * 0.5) + UP * CAM.LookHeight
	local from = focus + aisle * CAM.Distance + UP * (CAM.Height - CAM.LookHeight)
	return CFrame.lookAt(Unbox.Clear(state, from, focus), focus)
end

local function placeCharacter(state: State)
	local ctx = state.ctx
	local exclude = excluded(nil, ctx)
	local foot = state.base.Position
	local aisle = state.base.LookVector
	local right = aisle:Cross(UP)
	local side = right
	local probe = foot + UP * 2
	local reach = New.StandSide + 1.5
	local hitRight = raycast(probe, right * reach, exclude, true)
	local hitLeft = raycast(probe, -right * reach, exclude, true)
	local freeRight = if hitRight then (hitRight.Position - probe).Magnitude else reach
	local freeLeft = if hitLeft then (hitLeft.Position - probe).Magnitude else reach
	local free = freeRight
	if freeLeft > freeRight + 0.25 then
		side = -right
		free = freeLeft
	end
	state.side = side
	local root = rootOf(state)
	if root == nil then
		return
	end
	local character = characterOf(state)
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local height = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
	local at = foot + side * math.min(New.StandSide, math.max(free, 1.5) - 0.5) + UP * height
	local stand = CFrame.lookAt(at, Vector3.new(foot.X, at.Y, foot.Z))
	state.stand = stand
	if ctx.Opener then
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = stand
		end)
	end
end

-- API --------------------------------------------------------------------------------------------------------------

function Unbox.Begin(ctx: Context): State
	local point, aisle = place(ctx)
	local anchor = Instance.new("Part")
	anchor.Name = "UnboxAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(point)
	anchor.Parent = ctx.Folder
	local first = ctx.Plan.Steps[1]
	local home = ctx.SlotFrame
	local shelfBox = ctx.ShelfBox
	if shelfBox and shelfBox:IsA("PVInstance") then
		home = shelfBox:GetPivot()
	end
	local state: State = {
		ctx = ctx,
		phase = "Intro",
		t = 0,
		events = {},
		base = CFrame.lookAt(point, point + aisle),
		side = aisle:Cross(UP),
		stand = nil,
		home = home,
		floor = CFrame.new(point) * home.Rotation,
		box = nil,
		boxScale0 = 1,
		boxHeight = 1.6,
		tierScale = 1,
		appliedScale = 1,
		lid = nil,
		lidOffset = CFrame.identity,
		tapes = {},
		anchor = anchor,
		board = nil,
		boardOffset = 0,
		oddsLabel = nil,
		rarityLabel = nil,
		upgradeLabel = nil,
		oddsScale = nil,
		odds = 1,
		oddsFrom = 1,
		oddsTo = 1,
		oddsT = -1,
		oddsTicks = 0,
		upgradeLeft = 0,
		finalLeft = 0,
		tier = first.Rarity,
		index = 0,
		mode = "Fallback",
		track = nil,
		trackStopped = false,
		connections = {},
		impacts = 0,
		strong = false,
		tool = nil,
		toolOffset = CFrame.identity,
		mark = nil,
		runFx = nil,
		runEvery = 0.06,
		runLeft = 0,
		react = nil,
		reactT = 0,
		reactForce = 1,
		words = {},
		junk = {},
		junkIndex = 0,
		timed = {},
		silhouette = nil,
		silhouetteIndex = 0,
		silhouetteCount = math.max((rarityOf(ctx.Rarity) or Rarities.List[1]).Order, 1),
		silhouetteHome = CFrame.new(point),
		spin = 0,
		zoom = { value = 0, target = 0, hold = 0 },
		edge = { value = 0, target = 0, hold = 0 },
		edgeColor = WHITE,
		edgeLabel = nil,
		edgeScreen = nil,
		edgeWasEnabled = false,
		baseFov = nil,
		seeThrough = {},
		ignored = {},
		muted = {},
		recoilLeft = 0,
		revealed = false,
		released = false,
		destroyed = false,
		created = { anchor },
	}
	buildBox(state)
	buildBoard(state)
	placeCharacter(state)
	if shelfBox then
		-- Le vrai colis est caché en local, mais son étiquette et son contour se verraient encore sur le rayon.
		-- ShelfBoxController les rallume selon la distance : ils sont rééteints à chaque image (Unbox.Step).
		for _, d in shelfBox:GetDescendants() do
			if d:IsA("BillboardGui") or d:IsA("Highlight") then
				table.insert(state.muted, d)
			end
		end
	end
	if ctx.Opener then
		local camera = Workspace.CurrentCamera
		if camera then
			state.baseFov = camera.FieldOfView
		end
		local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local screen = if gui then gui:FindFirstChild(New.EdgeScreen) else nil
		local glow = if screen then Find.path(screen, New.EdgeGlow) else nil
		if screen and screen:IsA("ScreenGui") and glow and glow:IsA("ImageLabel") then
			state.edgeScreen = screen
			state.edgeLabel = glow
			state.edgeWasEnabled = screen.Enabled
			glow.ImageTransparency = 1
			screen.Enabled = true
		end
	end
	poseBox(state, 0)
	return state
end

local function stepOdds(state: State, dt: number)
	if state.oddsT >= 0 then
		state.oddsT += dt
		local f = math.min(state.oddsT / New.OddsRoll, 1)
		local ticks = math.floor(state.oddsT / New.OddsTick)
		if ticks > state.oddsTicks or f >= 1 then
			state.oddsTicks = ticks
			showOdds(state, state.oddsFrom * (state.oddsTo / state.oddsFrom) ^ f)
			if state.ctx.Opener then
				sound(state, New.OddsTickSound, 1 + New.OddsTickPitch * ticks)
			end
		end
		local scale = state.oddsScale
		if scale then
			scale.Scale = 1 + (New.OddsPop - 1) * math.sin(math.pi * f)
		end
		if f >= 1 then
			state.oddsT = -1
		end
	end
	if state.upgradeLeft > 0 then
		state.upgradeLeft -= dt
		local upgrade = state.upgradeLabel
		if state.upgradeLeft <= 0 and upgrade then
			upgrade.Visible = false
		end
	end
end

local function stepScreen(state: State, dt: number)
	if not state.ctx.Opener or state.released then
		return
	end
	stepPulse(state.zoom, dt, New.ZoomIn, New.ZoomOut)
	stepPulse(state.edge, dt, New.EdgeIn, New.EdgeOut)
	local camera = Workspace.CurrentCamera
	local fov = state.baseFov
	if camera and fov then
		camera.FieldOfView = fov * (1 - state.zoom.value)
	end
	local glow = state.edgeLabel
	if glow then
		glow.ImageColor3 = state.edgeColor
		glow.ImageTransparency = 1 - state.edge.value
	end
end

-- Appelé par RevealController quand son marqueur Reveal tombe (à l'évènement « Reveal » d'ici, ou d'un coup à son
-- plafond de temps) : tout ce qui précède l'objet disparaît, la cote finale s'affiche au-dessus de BB_Reveal.
function Unbox.OnReveal(state: State)
	if state.revealed or state.destroyed then
		return
	end
	state.revealed = true
	stopTrack(state, 0.2)
	stopRunFx(state)
	dropBox(state)
	dropTool(state)
	dropMark(state)
	dropSilhouette(state)
	local ctx = state.ctx
	local color = colorOf(ctx.Rarity)
	local top = Vector3.new(state.base.Position.X, ctx.ItemTop(), state.base.Position.Z)
	spawnFx(state, New.Fx.Reveal, CFrame.new(state.base.Position:Lerp(top, 0.5)), nil, color, true)
	flash(state, ctx.Rarity, true)
	state.tier = ctx.Rarity
	local rarityText = state.rarityLabel
	if rarityText then
		rarityText.Visible = false
	end
	local upgrade = state.upgradeLabel
	if upgrade then
		upgrade.Visible = false
	end
	local text = state.oddsLabel
	if text then
		text.Visible = true
	end
	state.oddsFrom = math.max(state.odds, 1)
	state.oddsTo = math.max(ctx.Plan.Odds, 1)
	state.oddsT = 0
	state.oddsTicks = 0
	state.finalLeft = New.FinalOddsHold
	state.phase = "After"
	state.t = 0
end

-- Une image. Rend un évènement au plus : « Burst » (le colis éclate), « Reveal » (montrer l'objet), « Done » (suite).
function Unbox.Step(state: State, dt: number): string?
	if state.destroyed then
		return nil
	end
	state.t += dt
	state.spin += RevealConfig.Fallback.Spin * dt
	local phase = state.phase
	if phase == "Intro" then
		if state.t >= New.Intro then
			startAction(state, 1)
		end
	elseif phase == "Action" then
		stepAction(state, dt)
	elseif phase == "Gap" then
		if state.t >= UnboxPlan.gap() then
			startAction(state, state.index + 1)
		end
	elseif phase == "Burst" then
		if state.t >= New.BurstHold then
			dropTool(state)
			state.phase = "Silhouettes"
			state.t = 0
			showSilhouette(state, 1)
		end
	elseif phase == "Silhouettes" then
		local last = state.silhouetteIndex >= state.silhouetteCount
		if last and state.t >= New.Suspense then
			local silhouette = state.silhouette
			if silhouette then
				blacken(silhouette, WHITE, Enum.Material.Neon)
				spawnFx(state, New.Fx.Overexpose, CFrame.new(state.base.Position:Lerp(silhouetteTop(state), 0.5)), nil, colorOf(state.ctx.Rarity), true)
			end
			state.phase = "Overexpose"
			state.t = 0
		elseif not last and state.t >= New.SilhouetteStep then
			state.t = 0
			showSilhouette(state, state.silhouetteIndex + 1)
		end
	elseif phase == "Overexpose" then
		if state.t >= New.Overexpose then
			table.insert(state.events, "Reveal")
			state.phase = "Wait" -- RevealController appelle OnReveal
			state.t = 0
		end
	elseif phase == "After" then
		if state.t >= New.AfterReveal then
			table.insert(state.events, "Done")
			state.phase = "Tail"
			state.t = 0
		end
	end
	local track = state.track
	if track and state.phase ~= "Action" and New.AnimEndFade > 0 then
		-- f70c4 : la dernière action continue après son coup (le colis éclate) ; elle s'arrête en fondu juste avant sa
		-- dernière image au lieu de s'y arrêter net (vitesse : ActionSpeed).
		local ok, left = pcall(function(): number
			return if track.IsPlaying and track.Length > 0 then (track.Length - track.TimePosition) / math.max(New.ActionSpeed, 0.1) else math.huge
		end)
		if ok and left <= New.AnimEndFade then
			stopTrack(state, math.max(left, 0))
		end
	end
	for _, inst in state.muted do
		local gui: any = inst
		if gui.Enabled then
			gui.Enabled = false
		end
	end
	poseBox(state, dt)
	poseTool(state)
	stepOdds(state, dt)
	stepWords(state, dt)
	stepJunk(state, dt)
	stepScreen(state, dt)
	local silhouette = state.silhouette
	if silhouette then
		local shake = Vector3.zero
		if state.phase == "Silhouettes" and state.silhouetteIndex >= state.silhouetteCount then
			local amplitude = New.SilhouetteShake * math.min(state.t / New.Suspense, 1)
			shake = Vector3.new((math.random() - 0.5) * 2 * amplitude, 0, (math.random() - 0.5) * 2 * amplitude)
		end
		-- La dernière (le vrai objet) ne tourne pas : elle est posée comme l'objet le sera à sa révélation.
		local angle = if state.silhouetteIndex >= state.silhouetteCount then 0 else state.spin
		pcall(function()
			silhouette:PivotTo((state.silhouetteHome + shake) * CFrame.Angles(0, angle, 0))
		end)
	end
	if state.recoilLeft > 0 and state.ctx.Opener then
		local slice = math.min(dt, state.recoilLeft)
		state.recoilLeft -= slice
		local root = rootOf(state)
		if root then
			pcall(function()
				root.CFrame += state.side * (New.Recoil * slice / New.RecoilTime)
			end)
		end
	end
	if state.revealed then
		local board = state.board
		if board and state.finalLeft > 0 then
			state.finalLeft -= dt
			state.anchor.CFrame = CFrame.new(
				state.base.Position.X,
				state.ctx.ItemTop() + RevealConfig.BoardOffset + New.FinalOddsAbove - state.boardOffset,
				state.base.Position.Z
			)
			if state.finalLeft <= 0 then
				state.board = nil
				board:Destroy()
			end
		end
	end
	for index = #state.timed, 1, -1 do
		local timed = state.timed[index]
		timed.left -= dt
		if timed.left <= 0 then
			timed.inst:Destroy()
			table.remove(state.timed, index)
		end
	end
	return table.remove(state.events, 1)
end

-- f70c4 : ce qu'il reste à remettre de l'écran de l'ouvreur (champ de vision, bords), de leur valeur en ce moment à
-- celle d'avant la scène ; Unbox.ScreenFade le fait avancer (0 = en ce moment, 1 = remis).
export type ScreenFade = {
	fovFrom: number?,
	fovTo: number?,
	edgeFrom: number,
	glow: ImageLabel?,
	screen: ScreenGui?,
	wasEnabled: boolean,
}

function Unbox.ScreenFade(fade: ScreenFade, e: number)
	local f = math.clamp(e, 0, 1)
	local camera = Workspace.CurrentCamera
	local from, to = fade.fovFrom, fade.fovTo
	if camera and from and to then
		camera.FieldOfView = from + (to - from) * f
	end
	local glow = fade.glow
	if glow then
		glow.ImageTransparency = 1 - fade.edgeFrom * (1 - f)
	end
	local screen = fade.screen
	if f >= 1 and screen then
		screen.Enabled = fade.wasEnabled
	end
end

-- L'ouvreur reprend la main (fin, mort, autre cinématique) : champ de vision et bords remis d'un coup ; soft (f70c4,
-- fin normale) : rien n'est remis ici, le fondu est rendu à RevealController, qui le fait avancer (Unbox.ScreenFade)
-- jusqu'à 1. La scène ne touche plus à l'écran ensuite (stepScreen), même détruite.
function Unbox.Release(state: State, soft: boolean?): ScreenFade?
	if state.released then
		return nil
	end
	state.released = true
	if not state.ctx.Opener then
		return nil
	end
	local camera = Workspace.CurrentCamera
	local fade: ScreenFade = {
		fovFrom = if camera then camera.FieldOfView else nil,
		fovTo = state.baseFov,
		edgeFrom = state.edge.value,
		glow = state.edgeLabel,
		screen = state.edgeScreen,
		wasEnabled = state.edgeWasEnabled,
	}
	if soft == true and not state.destroyed then
		return fade
	end
	Unbox.ScreenFade(fade, 1)
	return nil
end

function Unbox.Destroy(state: State)
	if state.destroyed then
		return
	end
	state.destroyed = true
	Unbox.Release(state)
	stopTrack(state, 0.2)
	dropBox(state)
	dropTool(state)
	dropMark(state)
	dropSilhouette(state)
	for _, word in state.words do
		word.board:Destroy()
	end
	table.clear(state.words)
	for _, junk in state.junk do
		junk.model:Destroy()
	end
	table.clear(state.junk)
	for _, timed in state.timed do
		timed.inst:Destroy()
	end
	table.clear(state.timed)
	for _, inst in state.created do
		inst:Destroy()
	end
	table.clear(state.created)
end

-- État pour un banc ou la barre de commande.
function Unbox.GetState(state: State): { [string]: any }
	local text = state.oddsLabel
	local rarityText = state.rarityLabel
	local upgrade = state.upgradeLabel
	return {
		Phase = state.phase,
		Index = state.index,
		Mode = state.mode,
		Impacts = state.impacts,
		Tier = state.tier,
		Odds = state.odds,
		OddsText = if text then text.Text else nil,
		RarityText = if rarityText and rarityText.Visible then rarityText.Text else nil,
		Upgrade = upgrade ~= nil and upgrade.Visible,
		BoxScale = state.tierScale,
		Box = state.box,
		Tool = state.tool,
		Mark = state.mark,
		Silhouette = state.silhouette,
		SilhouetteIndex = state.silhouetteIndex,
		Base = state.base,
		Stand = state.stand,
		Zoom = state.zoom.value,
		Edge = state.edge.value,
		SeeThrough = #state.seeThrough,
		Muted = #state.muted,
		Words = #state.words,
		Junk = #state.junk,
		Board = state.board,
	}
end

return Unbox
