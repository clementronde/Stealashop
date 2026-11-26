--!nonstrict
--[[
	uifx_select.luau : aperçu de l'effet Select (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : un seul choix à la fois dans un groupe ; le choisi prend un contour qui s'ouvre
	et grossit un peu, l'ancien choix perd le sien.
	Attribut proposé : Select = "<nom du groupe>" sur chaque élément du groupe (un seul choisi par groupe,
	cherché dans le même ScreenGui). Contour : un UIStroke enfant nommé SelectStroke, dessiné par Clément
	(son épaisseur et sa couleur font foi) ; sans lui, le code en crée un blanc de 3 px.
	Durée, courbe (V0) : contour 0 → épaisseur de Clément en 0,12 s (Back Out) et × 1,04 ; l'ancien choix
	perd son contour en 0,08 s (Quad Out) et revient à son échelle. Une fois par choix.
	Propriétés animées : SelectStroke.Thickness ; UIScale.Scale (UIScale existant, sinon « FxScale »).

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(gui) au clic ; options.group force le groupe sans lire l'attribut.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Select dans CoreGui (trois
	cases du même groupe), choisit 3 fois une autre case, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
	Scale = 1.04,
	InTime = 0.12, -- s, Back Out
	OutTime = 0.08, -- s, Quad Out
	Thickness = 3, -- px, si le code crée le contour
	Color = Color3.new(1, 1, 1),
}

local THICK = setmetatable({}, { __mode = "k" }) -- épaisseur de Clément, lue une fois
local SCALE_BASE = setmetatable({}, { __mode = "k" })

local function strokeOf(gui, o)
	local stroke = gui:FindFirstChild("SelectStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "SelectStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = o.Color
		stroke.Thickness = 0
		THICK[stroke] = o.Thickness
		stroke.Parent = gui
	end
	if THICK[stroke] == nil then THICK[stroke] = stroke.Thickness end
	return stroke
end

local function scaleOf(gui)
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Parent = gui
	end
	if SCALE_BASE[s] == nil then SCALE_BASE[s] = s.Scale end
	return s, SCALE_BASE[s]
end

local function members(gui, group)
	local root = gui:FindFirstAncestorWhichIsA("LayerCollector") or gui.Parent
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") and d:GetAttribute("Select") == group then table.insert(list, d) end
	end
	return list
end

local function play(gui, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local group = o.group or gui:GetAttribute("Select")
	local list = group and members(gui, group) or { gui }
	if not table.find(list, gui) then table.insert(list, gui) end
	for _, m in list do
		local stroke = strokeOf(m, o)
		local s, base = scaleOf(m)
		if m == gui then
			local info = TweenInfo.new(o.InTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			if stroke.Thickness >= THICK[stroke] then stroke.Thickness = 0 end -- rejoue l'ouverture
			TweenService:Create(stroke, info, { Thickness = THICK[stroke] }):Play()
			TweenService:Create(s, info, { Scale = base * o.Scale }):Play()
		else
			local info = TweenInfo.new(o.OutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(stroke, info, { Thickness = 0 }):Play()
			TweenService:Create(s, info, { Scale = base }):Play()
		end
	end
	return o.InTime
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

do
	local NAME = "_UIFX_PREVIEW_Select"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local tiles = {}
		for i = 1, 3 do
			local t = new("TextButton", {
				Name = "Tile" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 2) * 130, 0.5, 0),
				Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
				Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = tostring(i),
			})
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, t)
			t:SetAttribute("Select", "PreviewGroup")
			t.Parent = sg
			tiles[i] = t
		end
		for _, i in { 1, 3, 2 } do
			task.wait(play(tiles[i]) + 0.6)
		end
		assert(tiles[2].SelectStroke.Thickness > 2.9 and tiles[1].SelectStroke.Thickness < 0.01, "un seul choix attendu")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_select : aperçu joué, " .. NAME .. " détruit")
end
