--!strict
-- Appear (vague 59, a189, L-182 point 1 ; client) : les apparitions que Clément pose en attribut Appear sur un
-- GuiObject de ses écrans (Contract/Attributes ; durées et courbes dans Config/UiMotion.Appear). Module d'aide rangé
-- dans Controllers/UI : le Loader ne le démarre pas. UiMotionController le lance quand un écran s'allume (Enabled) ou
-- qu'un élément Appear devient visible ; Motion.Close et Motion.Hide jouent sa fermeture et l'attendent ; Motion ne
-- met à l'échelle ni un cadre qui porte Appear, ni les cartes d'une Cascade (Covers).
--
--   Pop         l'élément passe de Pop.From à 1 ; fermeture : de 1 à Pop.CloseTo (correctif f73c1 : avec WindowE, le
--               cadre racine Pop d'une fenêtre centrale suit Config/UiMotion Open et Close, comme Motion)
--   Cascade     l'élément (le fond) est là tout de suite, puis ses enfants visibles (sauf Template) entrent l'un après
--               l'autre (Gap s d'écart, dans l'ordre LayoutOrder puis de lecture) ; un enfant cloné dans les Late s
--               qui suivent entre aussi, à la suite ; fermeture : tous ensemble
--   Stamp       de Stamp.From à 1 et de Rotation + Tilt à la Rotation de Clément ; fermeture comme Pop
--   SlideRight  depuis juste derrière le bord droit de l'écran jusqu'à sa Position ; fermeture : il y repart
--   DropIn      (L-188) tombe de sa hauteur à sa Position (Back Out), DropIn.Gap s après le frère DropIn d'avant, puis se
--               balance autour de sa Rotation tant qu'il est affiché (GetPhase reste "In") ; pas de fermeture
--
-- API (client) :
--   Appear.KindOf(object) -> string?   valeur d'Appear connue (Pop, Cascade, Stamp, SlideRight), sinon nil
--   Appear.Has(object) -> boolean      l'objet porte une valeur d'Appear connue
--   Appear.Covers(item) -> boolean     l'objet porte Appear, ou un de ses parents est une Cascade
--   Appear.Open(root)                  entrée de root et de chaque élément Appear visible dedans (hors Template)
--   Appear.Play(object)                entrée d'un élément Appear
--   Appear.Close(root) -> number       sortie des éléments Appear affichés de root ; durée de la plus longue (0 : rien)
--   Appear.Reset(root)                 arrête tout sous root et remet chaque élément à l'état de Clément
--   Appear.GetPhase(object) -> string? "In" ou "Out" tant qu'une animation est en cours ou finie en sortie, sinon nil
--   Appear.SetCascade(container, rank?, gap?)
--                                      (vague 63, a209, L-204) règle propre à une Cascade : rank(enfant) -> rang (0 = le
--                                      premier ; même rang = entrent ensemble), gap = écart entre deux rangs ; sans rien :
--                                      la règle commune (ordre de lecture, Cascade.Gap). Sert aux cases de la caisse.
--   Appear.Reduced() -> boolean        (vague 64, a212) réglage « animations réduites » (Settings.VfxReduced, ou
--                                      ReducedMotionEnabled de Roblox) : rien ne bouge, tout apparaît et part d'un coup
--
-- Vague 64 (a212, vidéo de référence, Config/UiMotion.Appear.Blocks) : à l'ouverture d'un écran (Appear.Open), les
-- éléments Pop et Stamp posés dans un cadre animé (un élément Appear, ou un cadre racine que Motion.Open met à
-- l'échelle) sont des blocs : cachés (UIScale à Blocks.From), ils entrent l'un après l'autre dans l'ordre de lecture.
-- Un bloc déjà en train de sortir (écran rouvert pendant sa fermeture) repart tout de suite de là où il en est.
--
-- Ce qui est touché, le temps de l'animation seulement : un UIScale ScaleName créé ici (sur l'élément, ou sur chaque
-- enfant d'une Cascade), la Rotation (Stamp) et la Position (SlideRight) de l'élément, remises exactement à la valeur
-- de Clément à la fin de l'entrée ou à Reset, et une NumberValue SlideName (glissement). Un élément qui a déjà un
-- UIScale qui n'est pas le sien (celui de Clément, ou un survol en cours) n'est pas mis à l'échelle. Deux ouvertures
-- rapides : la deuxième repart de là où en est la première (jamais deux UIScale). Rien ne tourne quand rien ne bouge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))

-- Réglage « animations réduites » (vague 64) : Settings.VfxReduced, lu seulement si le module est là (banc réduit).
type SettingsApi = { VfxReduced: (Instance?) -> boolean }
local settings: SettingsApi? = (function(): SettingsApi?
	local module = Config:FindFirstChild("Settings")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result :: any else nil
end)()

local SPEC = UiMotion.Appear
local BLOCKS = SPEC.Blocks
local BLOCK_IN = TweenInfo.new(BLOCKS.Time, BLOCKS.Style, BLOCKS.Direction)
local POP = SPEC.Pop
local CASCADE = SPEC.Cascade
local STAMP = SPEC.Stamp
local SLIDE = SPEC.SlideRight
local ATTRIBUTE = Attributes.Appear.Name
local TEMPLATE = "Template"

local KINDS: { [string]: boolean } = {}
for _, value in Attributes.Appear.Values do
	KINDS[value] = true
end

local POP_IN = TweenInfo.new(POP.Time, POP.Style, POP.Direction)
local POP_OUT = TweenInfo.new(POP.CloseTime, POP.CloseStyle, POP.CloseDirection)
local CASCADE_IN = TweenInfo.new(CASCADE.Time, CASCADE.Style, CASCADE.Direction)
local CASCADE_OUT = TweenInfo.new(CASCADE.CloseTime, POP.CloseStyle, POP.CloseDirection)
local STAMP_IN = TweenInfo.new(STAMP.Time, STAMP.Style, STAMP.Direction)
local STAMP_OUT = TweenInfo.new(STAMP.CloseTime, POP.CloseStyle, POP.CloseDirection)
local SLIDE_IN = TweenInfo.new(SLIDE.Time, SLIDE.Style, SLIDE.Direction)
local SLIDE_OUT = TweenInfo.new(SLIDE.CloseTime, SLIDE.CloseStyle, SLIDE.CloseDirection)
local DROP = SPEC.DropIn
local DROP_IN = TweenInfo.new(DROP.Time, DROP.Style, DROP.Direction)
-- Correctif f73c1 (T-420, L-259) : avec WindowE, le cadre racine Pop d'une fenêtre centrale (écran de Blur.Screens, ou
-- ScreenGui qui porte l'attribut Blur.Attribute = true) s'ouvre et se ferme comme Motion.Open et Motion.Close (Config/
-- UiMotion Open et Close, deux tweens par Peak) au lieu de Pop. Motion ne met pas à l'échelle un cadre qui porte Appear :
-- sans ce correctif, la Root de UI_WeaponShop gardait Pop (fermeture Back In 1 → 1,094 → 0 en 0,2 s).
local WINDOW_E = UiMotion.WindowE
local WINDOW = { open = UiMotion.Open, close = UiMotion.Close }
local WINDOW_OPEN = TweenInfo.new(WINDOW.open.Time, WINDOW.open.Style, WINDOW.open.Direction)
local WINDOW_OPEN_PEAK = TweenInfo.new(WINDOW.open.PeakTime, WINDOW.open.PeakStyle, WINDOW.open.PeakDirection)
local WINDOW_CLOSE = TweenInfo.new(WINDOW.close.Time, WINDOW.close.Style, WINDOW.close.Direction)
local WINDOW_CLOSE_PEAK = TweenInfo.new(WINDOW.close.PeakTime, WINDOW.close.PeakStyle, WINDOW.close.PeakDirection)
local CENTRAL: { [string]: boolean } = {}
for _, name in UiMotion.Blur.Screens do
	CENTRAL[name] = true
end
-- Balancement : d'abord de la Rotation de Clément à +Sway (un quart de cycle), puis de +Sway à −Sway et retour, sans fin.
local SWAY_START = TweenInfo.new(DROP.SwayPeriod / 4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local SWAY_LOOP = TweenInfo.new(DROP.SwayPeriod / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

export type Phase = "In" | "Out"

-- Un élément animé. L'élément lui-même n'y est pas gardé (clés faibles de `states`).
type State = {
	kind: string,
	phase: Phase?,
	token: number, -- change à chaque animation : une fin ou un départ d'une animation remplacée est ignoré
	tweens: { Tween },
	scales: { [GuiObject]: UIScale }, -- UIScale créés ici (l'élément, ou les enfants d'une Cascade)
	baseRotation: number?, -- Rotation de Clément (Stamp)
	basePosition: UDim2?, -- Position de Clément (SlideRight)
	slide: NumberValue?, -- 0 = à sa place, 1 = derrière le bord droit
	slideConnection: RBXScriptConnection?,
	slideDistance: number, -- px jusqu'au bord droit (ou hauteur de l'élément, DropIn) ; 0 = inconnu (repli en Scale)
	vertical: boolean, -- DropIn : il vient d'au-dessus (Y), sinon de la droite (X)
	fallback: number, -- repli en Scale quand slideDistance est inconnu
	swaying: boolean, -- DropIn : à sa place, il se balance
	late: RBXScriptConnection?, -- Cascade : enfants clonés juste après l'ouverture
	queued: number, -- Cascade : enfants déjà rangés dans la file
	startedAt: number,
}

local Appear = {}

local states: { [GuiObject]: State } = setmetatable({}, { __mode = "k" }) :: any

type CascadeRule = { rank: ((GuiObject) -> number)?, gap: number? }
local cascadeRules: { [GuiObject]: CascadeRule } = setmetatable({}, { __mode = "k" }) :: any

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

function Appear.KindOf(object: Instance): string?
	local value = object:GetAttribute(ATTRIBUTE)
	return if type(value) == "string" and KINDS[value] then value else nil
end

function Appear.Has(object: Instance): boolean
	return Appear.KindOf(object) ~= nil
end

function Appear.Covers(item: Instance): boolean
	if Appear.Has(item) then
		return true
	end
	local parent = item.Parent
	while parent ~= nil and not parent:IsA("LayerCollector") do
		if Appear.KindOf(parent) == "Cascade" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Correctif f73c1 (T-420) : `object` est le cadre racine Pop d'une fenêtre centrale et WindowE est allumé.
local function windowRoot(object: GuiObject): boolean
	if not WINDOW_E or Appear.KindOf(object) ~= "Pop" then
		return false
	end
	local parent = object.Parent
	if parent == nil or not parent:IsA("ScreenGui") then
		return false
	end
	return CENTRAL[parent.Name] == true or parent:GetAttribute(UiMotion.Blur.Attribute) == true
end

function Appear.Reduced(): boolean
	local api = settings
	local player = Players.LocalPlayer
	if api ~= nil and player ~= nil then
		local ok, reduced = pcall(api.VfxReduced, player)
		if ok and reduced == true then
			return true
		end
	end
	local ok, value = pcall(function(): any
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- `inst` est le Template caché d'une liste, ou dedans : ses copies, elles, s'animent.
local function inTemplate(inst: Instance): boolean
	local current: Instance? = inst
	while current ~= nil and not current:IsA("LayerCollector") do
		if current.Name == TEMPLATE then
			return true
		end
		current = current.Parent
	end
	return false
end

-- `object` et ses parents, jusqu'à `root` (ou jusqu'à l'écran), sont visibles.
local function shownIn(object: GuiObject, root: Instance): boolean
	local current: Instance? = object
	while current ~= nil do
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		if current == root or current:IsA("LayerCollector") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function newState(kind: string): State
	return {
		kind = kind,
		phase = nil,
		token = 0,
		tweens = {},
		scales = {},
		baseRotation = nil,
		basePosition = nil,
		slide = nil,
		slideConnection = nil,
		slideDistance = 0,
		vertical = false,
		fallback = 1,
		swaying = false,
		late = nil,
		queued = 0,
		startedAt = 0,
	}
end

-- Arrête les tweens et les départs en attente (jeton) ; rien n'est remis.
local function stop(state: State)
	state.token += 1
	for _, tween in state.tweens do
		tween:Cancel()
	end
	table.clear(state.tweens)
	local late = state.late
	state.late = nil
	if late then
		late:Disconnect()
	end
end

-- Tout s'arrête et l'élément retrouve exactement l'état de Clément ; l'état est oublié.
local function restore(object: GuiObject, state: State)
	stop(state)
	for _, scale in state.scales do
		scale:Destroy()
	end
	table.clear(state.scales)
	local rotation = state.baseRotation
	if rotation ~= nil then
		object.Rotation = rotation
	end
	local connection = state.slideConnection
	state.slideConnection = nil
	if connection then
		connection:Disconnect()
	end
	local position = state.basePosition
	if position ~= nil then
		object.Position = position
	end
	local slide = state.slide
	state.slide = nil
	if slide then
		slide:Destroy()
	end
	state.phase = nil
	state.swaying = false
	if states[object] == state then
		states[object] = nil
	end
end

local function stateOf(object: GuiObject, kind: string): State
	local state: State? = states[object]
	if state ~= nil and state.kind ~= kind then
		restore(object, state) -- valeur d'Appear changée entre deux animations
		state = nil
	end
	if state == nil then
		local created = newState(kind)
		states[object] = created
		return created
	end
	return state
end

-- Le UIScale de cette animation sur `target` (créé à `initial` s'il manque ; un UIScale déjà là garde sa valeur, celle
-- d'une animation interrompue), ou nil si `target` a déjà un UIScale qui n'est pas le sien.
local function scaleOn(state: State, target: GuiObject, initial: number): UIScale?
	local own = state.scales[target]
	if own and own.Parent == target then
		return own
	end
	state.scales[target] = nil
	if target:FindFirstChildOfClass("UIScale") ~= nil then
		return nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = SPEC.ScaleName
	scale.Scale = initial
	scale.Parent = target
	state.scales[target] = scale
	return scale
end

-- Joue `tweens` ; `finish` quand tous sont arrivés, sauf si une autre animation a pris la place entre-temps.
local function run(state: State, tweens: { Tween }, finish: () -> ())
	local token = state.token
	if #tweens == 0 then
		finish()
		return
	end
	local remaining = #tweens
	for _, tween in tweens do
		table.insert(state.tweens, tween)
		tween.Completed:Connect(function(playback: Enum.PlaybackState)
			if playback ~= Enum.PlaybackState.Completed or state.token ~= token then
				return
			end
			remaining -= 1
			if remaining == 0 then
				finish()
			end
		end)
	end
	for _, tween in tweens do
		tween:Play()
	end
end

local function begin(state: State, phase: Phase)
	stop(state)
	state.phase = phase
end

------------------------------------------------------------------------------
-- Pop et Stamp : l'élément lui-même
------------------------------------------------------------------------------

-- `peak` (correctif f73c1, fenêtre centrale) : d'abord jusqu'à peak en peakInfo, puis jusqu'à 1 en info.
local function scaleIn(object: GuiObject, state: State, from: number, info: TweenInfo, extra: { [string]: any }?, peak: number?, peakInfo: TweenInfo?)
	local fresh = state.phase == nil
	begin(state, "In")
	local scale = scaleOn(state, object, from)
	if scale and fresh then
		scale.Scale = from
	end
	if scale ~= nil and peak ~= nil and peakInfo ~= nil then
		local current: UIScale = scale
		run(state, { TweenService:Create(current, peakInfo, { Scale = peak }) }, function()
			run(state, { TweenService:Create(current, info, { Scale = 1 }) }, function()
				restore(object, state)
			end)
		end)
		return
	end
	local tweens: { Tween } = {}
	if scale then
		table.insert(tweens, TweenService:Create(scale, info, { Scale = 1 }))
	end
	if extra then
		table.insert(tweens, TweenService:Create(object, info, extra))
	end
	run(state, tweens, function()
		restore(object, state)
	end)
end

local function scaleOut(object: GuiObject, state: State, to: number, info: TweenInfo, peak: number?, peakInfo: TweenInfo?): number
	begin(state, "Out")
	local scale = scaleOn(state, object, 1)
	if scale == nil then
		return 0
	end
	if peak ~= nil and peakInfo ~= nil then
		local current: UIScale = scale
		run(state, { TweenService:Create(current, peakInfo, { Scale = peak }) }, function()
			run(state, { TweenService:Create(current, info, { Scale = to }) }, function() end)
		end)
		return peakInfo.Time + info.Time
	end
	run(state, { TweenService:Create(scale, info, { Scale = to }) }, function() end)
	return info.Time
end

local function stampIn(object: GuiObject, state: State)
	if state.baseRotation == nil then
		state.baseRotation = object.Rotation
	end
	local base = state.baseRotation :: number
	if state.phase == nil then
		object.Rotation = base + STAMP.Tilt
	end
	scaleIn(object, state, STAMP.From, STAMP_IN, { Rotation = base })
end

------------------------------------------------------------------------------
-- Cascade : les enfants, l'un après l'autre
------------------------------------------------------------------------------

local function cascadeItems(container: GuiObject): { GuiObject }
	local list: { GuiObject } = {}
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") and (child :: GuiObject).Visible and child.Name ~= TEMPLATE then
			table.insert(list, child :: GuiObject)
		end
	end
	table.sort(list, function(a: GuiObject, b: GuiObject): boolean
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 4 then
			return pa.Y < pb.Y
		end
		return pa.X < pb.X
	end)
	return list
end

local function cascadeDone(container: GuiObject, state: State)
	if state.late == nil and next(state.scales) == nil and states[container] == state then
		restore(container, state)
	end
end

-- Range `item` dans la file : il attend à From (ou là où l'a laissé une sortie), puis entre à son tour.
local function cascadeAdd(container: GuiObject, state: State, item: GuiObject)
	local existing: UIScale? = state.scales[item]
	local scale = scaleOn(state, item, CASCADE.From)
	if scale == nil then
		return -- son propre UIScale : il apparaît d'un coup
	end
	if existing == nil then
		scale.Scale = CASCADE.From
	end
	local rule: CascadeRule? = cascadeRules[container]
	local ranker = if rule then rule.rank else nil
	local rank = if ranker then math.max(ranker(item), 0) else math.min(state.queued, CASCADE.Max - 1)
	local gap = if rule and rule.gap then rule.gap else CASCADE.Gap
	state.queued += 1
	local token = state.token
	local delay = math.max(CASCADE.Start + rank * gap - (os.clock() - state.startedAt), 0)
	task.delay(delay, function()
		if state.token ~= token then
			return
		end
		local found: UIScale? = state.scales[item]
		if found == nil or found.Parent ~= item then
			state.scales[item] = nil
			cascadeDone(container, state)
			return
		end
		local current: UIScale = found
		local tween = TweenService:Create(current, CASCADE_IN, { Scale = 1 })
		table.insert(state.tweens, tween)
		tween.Completed:Connect(function(playback: Enum.PlaybackState)
			if playback ~= Enum.PlaybackState.Completed or state.token ~= token then
				return
			end
			if state.scales[item] == current then
				state.scales[item] = nil
			end
			current:Destroy()
			cascadeDone(container, state)
		end)
		tween:Play()
	end)
end

local function cascadeIn(container: GuiObject, state: State)
	begin(state, "In")
	state.queued = 0
	state.startedAt = os.clock()
	local token = state.token
	local items = cascadeItems(container)
	local kept: { [GuiObject]: boolean } = {}
	for _, item in items do
		kept[item] = true
	end
	for item, scale in state.scales do
		if not kept[item] then -- enfant caché ou retiré pendant une sortie : il retrouve sa taille
			state.scales[item] = nil
			scale:Destroy()
		end
	end
	for _, item in items do
		cascadeAdd(container, state, item)
	end
	-- Enfants clonés par le contrôleur juste après l'ouverture (liste remplie à l'ouverture) : à la suite. Branché
	-- à la fin de l'image : une copie renommée juste après son arrivée n'est plus « Template ».
	state.late = container.ChildAdded:Connect(function(child: Instance)
		task.defer(function()
			if state.token ~= token or child.Parent ~= container or not child:IsA("GuiObject") then
				return
			end
			local item = child :: GuiObject
			if item.Visible and item.Name ~= TEMPLATE and not state.scales[item] then
				cascadeAdd(container, state, item)
			end
		end)
	end)
	task.delay(CASCADE.Late, function()
		if state.token ~= token then
			return
		end
		local late = state.late
		state.late = nil
		if late then
			late:Disconnect()
		end
		cascadeDone(container, state)
	end)
end

local function cascadeOut(container: GuiObject, state: State): number
	begin(state, "Out")
	local tweens: { Tween } = {}
	for _, item in cascadeItems(container) do
		local scale = scaleOn(state, item, 1)
		if scale then
			table.insert(tweens, TweenService:Create(scale, CASCADE_OUT, { Scale = CASCADE.CloseTo }))
		end
	end
	run(state, tweens, function() end)
	return if #tweens > 0 then CASCADE_OUT.Time else 0
end

------------------------------------------------------------------------------
-- SlideRight : la Position, par une NumberValue (0 = à sa place, 1 = derrière le bord droit)
------------------------------------------------------------------------------

local function slideTo(object: GuiObject, state: State, alpha: number)
	local base = state.basePosition
	if base == nil then
		return
	end
	local distance = state.slideDistance
	if state.vertical then
		if distance > 0 then
			object.Position = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset - distance * alpha)
		else
			object.Position = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale - state.fallback * alpha, base.Y.Offset)
		end
	elseif distance > 0 then
		object.Position = UDim2.new(base.X.Scale, base.X.Offset + distance * alpha, base.Y.Scale, base.Y.Offset)
	else
		object.Position = UDim2.new(base.X.Scale + state.fallback * alpha, base.X.Offset, base.Y.Scale, base.Y.Offset)
	end
end

-- px entre le bord gauche de l'élément (à sa place) et le bord droit de l'écran ; 0 si inconnu.
local function distanceToEdge(object: GuiObject): number
	local screen = object:FindFirstAncestorWhichIsA("LayerCollector")
	local width = if screen and screen:IsA("ScreenGui") then (screen :: ScreenGui).AbsoluteSize.X else 0
	local distance = width - object.AbsolutePosition.X
	return if width > 0 and distance > 0 then distance else 0
end

local function slideValue(object: GuiObject, state: State, initial: number): NumberValue
	local value = state.slide
	if value and value.Parent == object then
		return value
	end
	if state.basePosition == nil then
		state.basePosition = object.Position
	end
	local created = Instance.new("NumberValue")
	created.Name = SPEC.SlideName
	created.Value = initial
	created.Parent = object
	state.slide = created
	state.slideConnection = created:GetPropertyChangedSignal("Value"):Connect(function()
		slideTo(object, state, created.Value)
	end)
	return created
end

local function slideIn(object: GuiObject, state: State)
	if state.phase == nil then
		state.basePosition = object.Position
		state.slideDistance = distanceToEdge(object)
	end
	begin(state, "In")
	local value = slideValue(object, state, 1)
	slideTo(object, state, value.Value)
	run(state, { TweenService:Create(value, SLIDE_IN, { Value = 0 }) }, function()
		restore(object, state)
	end)
end

local function slideOut(object: GuiObject, state: State): number
	if state.phase == nil then
		state.basePosition = object.Position
		state.slideDistance = distanceToEdge(object)
	end
	begin(state, "Out")
	local value = slideValue(object, state, 0)
	run(state, { TweenService:Create(value, SLIDE_OUT, { Value = 1 }) }, function() end)
	return SLIDE_OUT.Time
end

------------------------------------------------------------------------------
-- DropIn (L-188) : il tombe à sa place (Position, comme SlideRight, à la verticale), puis se balance (Rotation)
------------------------------------------------------------------------------

-- Son rang parmi ses frères DropIn visibles (LayoutOrder, puis nom) : il part DropIn.Gap s après le précédent.
local function dropRank(object: GuiObject): number
	local parent = object.Parent
	if parent == nil then
		return 0
	end
	local list: { GuiObject } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") and (child :: GuiObject).Visible and Appear.KindOf(child) == "DropIn" then
			table.insert(list, child :: GuiObject)
		end
	end
	table.sort(list, function(a: GuiObject, b: GuiObject): boolean
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	return (table.find(list, object) or 1) - 1
end

local function sway(object: GuiObject, state: State)
	local base = state.baseRotation or object.Rotation
	state.swaying = true
	local token = state.token
	local first = TweenService:Create(object, SWAY_START, { Rotation = base + DROP.Sway })
	table.insert(state.tweens, first)
	first.Completed:Connect(function(playback: Enum.PlaybackState)
		if playback ~= Enum.PlaybackState.Completed or state.token ~= token then
			return
		end
		local loop = TweenService:Create(object, SWAY_LOOP, { Rotation = base - DROP.Sway })
		table.insert(state.tweens, loop)
		loop:Play()
	end)
	first:Play()
end

local function dropIn(object: GuiObject, state: State)
	if state.swaying then
		return -- déjà à sa place (écran rouvert pendant une fermeture) : il continue de se balancer
	end
	if state.phase == nil then
		state.basePosition = object.Position
		state.baseRotation = object.Rotation
		state.vertical = true
		state.slideDistance = math.max(object.AbsoluteSize.Y, 0)
		state.fallback = if object.Size.Y.Scale > 0 then object.Size.Y.Scale else 0.1
	end
	begin(state, "In")
	local value = slideValue(object, state, 1)
	slideTo(object, state, value.Value)
	local token = state.token
	task.delay(dropRank(object) * DROP.Gap, function()
		if state.token ~= token then
			return
		end
		run(state, { TweenService:Create(value, DROP_IN, { Value = 0 }) }, function()
			-- À sa place : Position de Clément exactement, NumberValue retirée ; puis le balancement.
			local connection = state.slideConnection
			state.slideConnection = nil
			if connection then
				connection:Disconnect()
			end
			local slide = state.slide
			state.slide = nil
			if slide then
				slide:Destroy()
			end
			local position = state.basePosition
			if position ~= nil then
				object.Position = position
			end
			sway(object, state)
		end)
	end)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function Appear.Play(object: GuiObject)
	local kind = Appear.KindOf(object)
	if kind == nil or object.Parent == nil then
		return
	end
	if Appear.Reduced() then
		local current = states[object]
		if current then
			restore(object, current) -- animations réduites : à l'état de Clément, tout de suite
		end
		return
	end
	local state = stateOf(object, kind)
	if kind == "Pop" and windowRoot(object) then
		scaleIn(object, state, WINDOW.open.From, WINDOW_OPEN, nil, WINDOW.open.Peak, WINDOW_OPEN_PEAK)
	elseif kind == "Pop" then
		scaleIn(object, state, POP.From, POP_IN, nil)
	elseif kind == "Stamp" then
		stampIn(object, state)
	elseif kind == "Cascade" then
		cascadeIn(object, state)
	elseif kind == "SlideRight" then
		slideIn(object, state)
	elseif kind == "DropIn" then
		dropIn(object, state)
	end
end

-- Les éléments Appear de `root` (root compris), visibles jusqu'à root, hors Template.
local function appearing(root: Instance): { GuiObject }
	local list: { GuiObject } = {}
	local function consider(inst: Instance)
		if inst:IsA("GuiObject") and Appear.Has(inst) and not inTemplate(inst) and shownIn(inst :: GuiObject, root) then
			table.insert(list, inst :: GuiObject)
		end
	end
	consider(root)
	for _, descendant in root:GetDescendants() do
		consider(descendant)
	end
	return list
end

------------------------------------------------------------------------------
-- Blocs (vague 64) : le contenu d'un écran qui s'ouvre, l'un après l'autre
------------------------------------------------------------------------------

local BLOCK_KINDS: { [string]: boolean } = { Pop = true, Stamp = true }
-- Cadres animés qui portent leurs blocs (Cascade : ses cartes s'animent déjà ; DropIn : décor).
local FRAME_KINDS: { [string]: boolean } = { Pop = true, Stamp = true, SlideRight = true }

-- `object` (Pop ou Stamp) est posé dans un cadre animé de son écran : un élément Appear, ou un cadre racine que
-- Motion.Open met à l'échelle (enfant direct de l'écran, sans Appear, qui ne couvre pas tout l'écran).
local function isBlock(object: GuiObject): boolean
	local kind = Appear.KindOf(object)
	if kind == nil or not BLOCK_KINDS[kind] then
		return false
	end
	local top: Instance? = nil
	local current = object.Parent
	while current ~= nil and not current:IsA("LayerCollector") do
		local parentKind = Appear.KindOf(current)
		if parentKind == "Cascade" then
			return false
		elseif parentKind ~= nil and FRAME_KINDS[parentKind] then
			return true
		end
		top = current
		current = current.Parent
	end
	if current == nil or top == nil or not top:IsA("GuiObject") or Appear.Has(top) then
		return false
	end
	local size = (top :: GuiObject).Size
	return not (size.X.Scale >= 1 and size.Y.Scale >= 1)
end

local function blockIn(object: GuiObject, state: State)
	if state.kind == "Stamp" then
		stampIn(object, state)
	else
		scaleIn(object, state, BLOCKS.From, BLOCK_IN, nil)
	end
end

-- Range les blocs neufs dans l'ordre de lecture (rangée à RowTolerance px près, puis de gauche à droite ; à égalité,
-- l'ordre de l'arbre) ; chacun attend caché, puis entre à son tour. Un bloc déjà animé (sortie en cours) : tout de suite.
local function playBlocks(blocks: { GuiObject })
	local waiting: { GuiObject } = {}
	local order: { [GuiObject]: number } = {}
	for index, object in blocks do
		local state = stateOf(object, Appear.KindOf(object) :: string)
		if state.phase ~= nil then
			Appear.Play(object)
			continue
		end
		local hidden = scaleOn(state, object, BLOCKS.From)
		if hidden == nil then
			Appear.Play(object) -- son propre UIScale : il apparaît comme avant
			continue
		end
		hidden.Scale = BLOCKS.From
		order[object] = index
		table.insert(waiting, object)
	end
	if #waiting == 0 then
		return
	end
	local tolerance = BLOCKS.RowTolerance
	table.sort(waiting, function(a: GuiObject, b: GuiObject): boolean
		local rowA = math.floor(a.AbsolutePosition.Y / tolerance + 0.5)
		local rowB = math.floor(b.AbsolutePosition.Y / tolerance + 0.5)
		if rowA ~= rowB then
			return rowA < rowB
		end
		if a.AbsolutePosition.X ~= b.AbsolutePosition.X then
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end
		return order[a] < order[b]
	end)
	local gap = if #waiting > 1 then math.min(BLOCKS.Gap, BLOCKS.Span / (#waiting - 1)) else BLOCKS.Gap
	for rank, object in waiting do
		local state = states[object] :: State
		local token = state.token
		task.delay(BLOCKS.Start + (rank - 1) * gap, function()
			if states[object] ~= state or state.token ~= token or state.phase ~= nil or object.Parent == nil then
				return -- fermé, remis ou rejoué entre-temps
			end
			blockIn(object, state)
		end)
	end
end

function Appear.Open(root: Instance)
	if Appear.Reduced() then
		Appear.Reset(root) -- animations réduites : tout à l'état de Clément, d'un coup
		return
	end
	local blocks: { GuiObject } = {}
	for _, object in appearing(root) do
		if BLOCKS.Enabled and object ~= root and isBlock(object) then
			table.insert(blocks, object)
		else
			Appear.Play(object)
		end
	end
	playBlocks(blocks)
end

function Appear.Close(root: Instance): number
	if Appear.Reduced() then
		return 0 -- animations réduites : rien ne sort, l'écran s'éteint d'un coup (Motion remet tout à l'état de Clément)
	end
	local longest = 0
	for _, object in appearing(root) do
		local kind = Appear.KindOf(object) :: string
		local state = stateOf(object, kind)
		local time = 0
		if kind == "Pop" and windowRoot(object) then
			time = scaleOut(object, state, WINDOW.close.To, WINDOW_CLOSE, WINDOW.close.Peak, WINDOW_CLOSE_PEAK)
		elseif kind == "Pop" then
			time = scaleOut(object, state, POP.CloseTo, POP_OUT)
		elseif kind == "Stamp" then
			time = scaleOut(object, state, STAMP.CloseTo, STAMP_OUT)
		elseif kind == "Cascade" then
			time = cascadeOut(object, state)
		elseif kind == "SlideRight" then
			time = slideOut(object, state)
		end
		longest = math.max(longest, time)
	end
	return longest
end

function Appear.Reset(root: Instance)
	local list: { GuiObject } = {}
	for object in states do
		if object == root or object:IsDescendantOf(root) then
			table.insert(list, object)
		end
	end
	for _, object in list do
		local state = states[object]
		if state then
			restore(object, state)
		end
	end
end

function Appear.SetCascade(container: GuiObject, rank: ((GuiObject) -> number)?, gap: number?)
	if rank == nil and gap == nil then
		cascadeRules[container] = nil
	else
		local rule: CascadeRule = { rank = rank, gap = gap }
		cascadeRules[container] = rule
	end
end

function Appear.GetPhase(object: Instance): Phase?
	if not object:IsA("GuiObject") then
		return nil
	end
	local state = states[object :: GuiObject]
	return if state then state.phase else nil
end

return Appear
