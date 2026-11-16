--!strict
-- ScrollReveal (vague 66, a222, L-210 point 6 : « surtout l'apparition des éléments au défilement » ; client) : dans
-- une liste qui défile (ScrollingFrame) d'un écran ouvert, les cartes et lignes qui étaient hors de la zone visible
-- à l'ouverture entrent quand elles y arrivent en défilant (molette, doigt, ou défilement par le code), une fois
-- chacune par ouverture, avec la courbe des cartes de la cascade (Config/UiMotion.Appear.Cascade : de From à 1 en
-- Time, Gap s entre deux cartes arrivées ensemble, Max au plus dans la file). Réglages : Config/UiMotion.ScrollReveal.
-- Module d'aide rangé dans Controllers/UI : le Loader ne le démarre pas ; UiMotionController l'arme quand un écran
-- s'allume (Enabled) et le désarme quand il s'éteint.
--
--   - Écrans : ScrollReveal.Screens, ou un ScreenGui qui porte l'attribut ScrollReveal.Attribute = true (false le coupe).
--   - Armé ArmDelay s après l'ouverture (la cascade d'ouverture a fini) : ce qui est visible à cet instant est « vu » ;
--     le reste attend. Un enfant cloné ensuite dans une liste (liste refaite) est « vu » s'il est déjà visible.
--   - Cartes : les enfants visibles de la liste (hors Template) ; un enfant plus long que Split fois la zone visible
--     (dans le sens du défilement) est une section (zone de l'index) : ses enfants entrent un par un (Depth niveaux).
--   - Rien n'est caché d'avance : une carte reçoit son UIScale passager (ScaleName, à From) au moment où elle touche
--     la zone visible, puis il est détruit à 1. Une carte qui a déjà un UIScale (celui de Clément, un survol, la
--     cascade) n'est pas animée. Animations réduites, ou Enabled = false : rien ne bouge.
--
-- API (client) :
--   ScrollReveal.Arm(gui)             écran allumé : armé après ArmDelay (relancé à chaque ouverture)
--   ScrollReveal.Disarm(gui)          écran éteint : tout s'arrête, chaque carte retrouve sa taille
--   ScrollReveal.Check(list)          revoit une liste tout de suite (bancs ; sinon à chaque CanvasPosition)
--   ScrollReveal.GetCounts(gui) -> (number, number)   listes suivies, cartes en train d'entrer (bancs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiMotion"))
local Appear = require(script.Parent:WaitForChild("Appear"))

local SPEC = UiMotion.ScrollReveal
local CASCADE = UiMotion.Appear.Cascade
local REVEAL_IN = TweenInfo.new(CASCADE.Time, CASCADE.Style, CASCADE.Direction)
local TEMPLATE = "Template"

local SCREENS: { [string]: boolean } = {}
for _, name in SPEC.Screens do
	SCREENS[name] = true
end

type List = {
	seen: { [GuiObject]: boolean },
	ready: boolean, -- « vu » a été fait liste affichée (une liste cachée à l'ouverture : son premier défilement ne fait que ça)
	connection: RBXScriptConnection?,
}

type Screen = {
	token: number,
	lists: { [ScrollingFrame]: List },
	connections: { RBXScriptConnection },
	scales: { [GuiObject]: UIScale },
	tweens: { Tween },
}

local ScrollReveal = {}

local screens: { [ScreenGui]: Screen } = setmetatable({}, { __mode = "k" }) :: any
local owners: { [ScrollingFrame]: Screen } = setmetatable({}, { __mode = "k" }) :: any
local tokens = 0

local function wanted(gui: ScreenGui): boolean
	if not SPEC.Enabled then
		return false
	end
	local flag = gui:GetAttribute(SPEC.Attribute)
	if flag == false then
		return false
	end
	return flag == true or SCREENS[gui.Name] == true
end

local function vertical(list: ScrollingFrame): boolean
	return list.ScrollingDirection ~= Enum.ScrollingDirection.X
end

-- Les cartes de `container` : ses enfants visibles (hors Template) ; une section (plus longue que Split fois la zone
-- visible) est remplacée par ses propres cartes, sur Depth niveaux au plus.
local function collect(container: Instance, isVertical: boolean, limit: number, depth: number, out: { GuiObject })
	for _, child in container:GetChildren() do
		if not child:IsA("GuiObject") or child.Name == TEMPLATE or not (child :: GuiObject).Visible then
			continue
		end
		local item = child :: GuiObject
		local size = item.AbsoluteSize
		local length = if isVertical then size.Y else size.X
		if depth < SPEC.Depth and length > limit and item:FindFirstChildWhichIsA("GuiObject") ~= nil then
			collect(item, isVertical, limit, depth + 1, out)
		else
			table.insert(out, item)
		end
	end
end

local function cards(list: ScrollingFrame): { GuiObject }
	local isVertical = vertical(list)
	local window = list.AbsoluteSize
	local out: { GuiObject } = {}
	collect(list, isVertical, (if isVertical then window.Y else window.X) * SPEC.Split, 1, out)
	return out
end

-- La carte touche la zone visible de la liste.
local function inView(item: GuiObject, list: ScrollingFrame): boolean
	local size, position = item.AbsoluteSize, item.AbsolutePosition
	if size.X <= 0 or size.Y <= 0 then
		return false
	end
	local origin, window = list.AbsolutePosition, list.AbsoluteSize
	return position.X < origin.X + window.X and position.X + size.X > origin.X
		and position.Y < origin.Y + window.Y and position.Y + size.Y > origin.Y
end

local function readingOrder(a: GuiObject, b: GuiObject): boolean
	local pa, pb = a.AbsolutePosition, b.AbsolutePosition
	if math.abs(pa.Y - pb.Y) > UiMotion.OpenStagger.RowTolerance then
		return pa.Y < pb.Y
	end
	return pa.X < pb.X
end

-- La liste et ses parents sont visibles, et elle a une taille.
local function shown(list: ScrollingFrame): boolean
	local size = list.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return false
	end
	local current: Instance? = list
	while current ~= nil and not current:IsA("LayerCollector") do
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

-- Ce qui est visible maintenant est « vu », sans animation.
local function settle(list: ScrollingFrame, state: List)
	if not state.ready and shown(list) then
		state.ready = true
	end
	for _, item in cards(list) do
		if not state.seen[item] and inView(item, list) then
			state.seen[item] = true
		end
	end
end

local function reveal(screen: Screen, items: { GuiObject })
	table.sort(items, readingOrder)
	local token = screen.token
	local rank = 0
	for _, item in items do
		if item:FindFirstChildOfClass("UIScale") ~= nil then
			continue -- son propre UIScale (Clément, survol, cascade) : il reste comme il est
		end
		local scale = Instance.new("UIScale")
		scale.Name = SPEC.ScaleName
		scale.Scale = CASCADE.From
		scale.Parent = item
		screen.scales[item] = scale
		task.delay(math.min(rank, CASCADE.Max - 1) * CASCADE.Gap, function()
			if screen.token ~= token or screen.scales[item] ~= scale or scale.Parent ~= item then
				return
			end
			local tween = TweenService:Create(scale, REVEAL_IN, { Scale = 1 })
			table.insert(screen.tweens, tween)
			tween.Completed:Connect(function(playback: Enum.PlaybackState)
				if playback ~= Enum.PlaybackState.Completed or screen.token ~= token then
					return
				end
				local index = table.find(screen.tweens, tween)
				if index then
					table.remove(screen.tweens, index)
				end
				if screen.scales[item] == scale then
					screen.scales[item] = nil
				end
				scale:Destroy()
			end)
			tween:Play()
		end)
		rank += 1
	end
end

function ScrollReveal.Check(list: ScrollingFrame)
	local screen = owners[list]
	local state = if screen then screen.lists[list] else nil
	if screen == nil or state == nil then
		return
	end
	if Appear.Reduced() then
		settle(list, state) -- animations réduites : tout est là, d'un coup
		return
	end
	if not state.ready then
		settle(list, state) -- liste cachée jusqu'ici (onglet, réserve) : ce qui est visible est « vu »
		return
	end
	local fresh: { GuiObject } = {}
	for _, item in cards(list) do
		if not state.seen[item] and inView(item, list) then
			state.seen[item] = true
			table.insert(fresh, item)
		end
	end
	if #fresh > 0 then
		reveal(screen, fresh)
	end
end

local function watchList(screen: Screen, list: ScrollingFrame)
	if screen.lists[list] then
		return
	end
	local state: List = { seen = setmetatable({}, { __mode = "k" }) :: any, ready = false, connection = nil }
	screen.lists[list] = state
	owners[list] = screen
	settle(list, state)
	state.connection = list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		ScrollReveal.Check(list)
	end)
end

local function unwatchList(screen: Screen, list: ScrollingFrame)
	local state = screen.lists[list]
	if state == nil then
		return
	end
	screen.lists[list] = nil
	if owners[list] == screen then
		owners[list] = nil
	end
	local connection = state.connection
	state.connection = nil
	if connection then
		connection:Disconnect()
	end
end

-- La liste qui contient `inst` (la plus proche), suivie par cet écran.
local function listOf(screen: Screen, inst: Instance): ScrollingFrame?
	local current = inst.Parent
	while current ~= nil and not current:IsA("LayerCollector") do
		if current:IsA("ScrollingFrame") and screen.lists[current :: ScrollingFrame] then
			return current :: ScrollingFrame
		end
		current = current.Parent
	end
	return nil
end

function ScrollReveal.Disarm(gui: ScreenGui)
	local screen = screens[gui]
	if screen == nil then
		return
	end
	screens[gui] = nil
	screen.token = -1
	for _, connection in screen.connections do
		connection:Disconnect()
	end
	table.clear(screen.connections)
	for list in table.clone(screen.lists) do
		unwatchList(screen, list)
	end
	for _, tween in screen.tweens do
		tween:Cancel()
	end
	table.clear(screen.tweens)
	for _, scale in screen.scales do
		scale:Destroy() -- chaque carte retrouve sa taille
	end
	table.clear(screen.scales)
end

function ScrollReveal.Arm(gui: ScreenGui)
	ScrollReveal.Disarm(gui)
	if not wanted(gui) or Appear.Reduced() then
		return
	end
	tokens += 1
	local screen: Screen = { token = tokens, lists = {}, connections = {}, scales = {}, tweens = {} }
	screens[gui] = screen
	local token = screen.token
	task.delay(SPEC.ArmDelay, function()
		if screen.token ~= token or screens[gui] ~= screen or not gui.Enabled or gui.Parent == nil then
			return
		end
		for _, descendant in gui:GetDescendants() do
			if descendant:IsA("ScrollingFrame") then
				watchList(screen, descendant :: ScrollingFrame)
			end
		end
		-- Liste ajoutée, ou cartes clonées dans une liste (liste refaite) : ce qui est déjà visible est « vu ».
		table.insert(screen.connections, gui.DescendantAdded:Connect(function(descendant: Instance)
			if not descendant:IsA("GuiObject") then
				return
			end
			task.defer(function()
				if screen.token ~= token or descendant.Parent == nil then
					return
				end
				if descendant:IsA("ScrollingFrame") then
					watchList(screen, descendant :: ScrollingFrame)
				end
				local list = listOf(screen, descendant)
				local state = if list then screen.lists[list] else nil
				if list and state then
					settle(list, state)
				end
			end)
		end))
		table.insert(screen.connections, gui.DescendantRemoving:Connect(function(descendant: Instance)
			if descendant:IsA("ScrollingFrame") then
				unwatchList(screen, descendant :: ScrollingFrame)
			end
		end))
	end)
end

function ScrollReveal.GetCounts(gui: ScreenGui): (number, number)
	local screen = screens[gui]
	if screen == nil then
		return 0, 0
	end
	local lists, moving = 0, 0
	for _ in screen.lists do
		lists += 1
	end
	for _ in screen.scales do
		moving += 1
	end
	return lists, moving
end

return ScrollReveal
