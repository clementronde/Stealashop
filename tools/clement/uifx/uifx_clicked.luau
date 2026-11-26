--!nonstrict
--[[
	uifx_clicked.luau : aperçu de l'état de bouton Clicked (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : pendant l'appui, le bouton montre un autre aspect dessiné par Clément.
	Attribut : aucun nouvel attribut. Enfant StateClicked du bouton (avec StateDefault, StateOver, StateActive,
	StateDisabled) ; le code le montre et cache les autres. S'ajoute à Press = "Squash" (échelle), sans le remplacer.
	Sans calque StateClicked : couleurs assombries × 0,62 (comme Shade à 0,62 et le Dim actuel).
	Durée, courbe : 0,05 s, Quad Out ; au relâché, retour vers StateOver (doigt encore dessus) ou StateDefault
	dans le même temps. Tenu tant que le doigt reste.
	Propriétés animées : transparences du calque, Visible à la fin ; sinon BackgroundColor3 et ImageColor3.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : play(button, { on = true }) à l'appui, play(button, { on = false, back = "Over" }) au relâché
	(back = "Default" si la souris est sortie).
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Clicked dans CoreGui, joue
	3 appuis, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")
local QUAD, OUT, IN = Enum.EasingStyle.Quad, Enum.EasingDirection.Out, Enum.EasingDirection.In

local DEFAULTS = {
	Time = 0.05, -- s
	Dim = 0.62, -- facteur de couleur sans calque StateClicked
	OverDim = 0.8, -- retour vers Over sans calque
}

-- Noyau commun des états (copié dans uifx_default, _over, _clicked, _active, _disabled) ----------------------
local BASE = setmetatable({}, { __mode = "k" }) -- transparences d'origine de Clément, lues une fois
local TOKEN = setmetatable({}, { __mode = "k" })
local COLORS = setmetatable({}, { __mode = "k" })

local function transparencyProps(inst)
	if inst:IsA("UIStroke") then return { "Transparency" } end
	if not inst:IsA("GuiObject") then return {} end
	local list = { "BackgroundTransparency" }
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		table.insert(list, "TextTransparency")
		table.insert(list, "TextStrokeTransparency")
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("ViewportFrame") then
		table.insert(list, "ImageTransparency")
	end
	return list
end

local function baseOf(root)
	if BASE[root] then return BASE[root] end
	local entries = {}
	local function add(inst)
		for _, p in transparencyProps(inst) do
			table.insert(entries, { inst = inst, prop = p, base = inst[p] })
		end
	end
	add(root)
	for _, d in root:GetDescendants() do add(d) end
	BASE[root] = entries
	return entries
end

-- hidden = 0 : allure de Clément ; hidden = 1 : invisible
local function setHidden(root, hidden)
	if root:IsA("CanvasGroup") then root.GroupTransparency = hidden return end
	for _, e in baseOf(root) do e.inst[e.prop] = e.base + (1 - e.base) * hidden end
end

local function fadeTo(root, hidden, time, dir)
	if time <= 0 then setHidden(root, hidden) return end
	local info = TweenInfo.new(time, QUAD, dir or OUT)
	if root:IsA("CanvasGroup") then
		TweenService:Create(root, info, { GroupTransparency = hidden }):Play()
		return
	end
	for _, e in baseOf(root) do
		if e.inst.Parent then
			TweenService:Create(e.inst, info, { [e.prop] = e.base + (1 - e.base) * hidden }):Play()
		end
	end
end

local function showLayer(layer, on, time)
	local n = (TOKEN[layer] or 0) + 1
	TOKEN[layer] = n
	baseOf(layer)
	if on then
		if not layer.Visible then
			setHidden(layer, 1)
			layer.Visible = true
		end
		fadeTo(layer, 0, time)
	elseif layer.Visible then
		fadeTo(layer, 1, time)
		task.delay(time, function()
			if TOKEN[layer] ~= n then return end
			layer.Visible = false
			setHidden(layer, 0)
		end)
	end
end

-- Montre State<name> et cache les autres State* ; false si le bouton n'a pas de calque State<name>
local function setState(button, name, time)
	if not button:FindFirstChild("State" .. name) then return false end
	for _, child in button:GetChildren() do
		if child:IsA("GuiObject") and child.Name:sub(1, 5) == "State" then
			showLayer(child, child.Name == "State" .. name, time)
		end
	end
	return true
end

-- Repli sans calque : couleurs du bouton et de ses enfants multipliées par factor (1 = couleurs d'origine)
local function dim(button, factor, time)
	local list = COLORS[button]
	if not list then
		list = {}
		for _, inst in { button, table.unpack(button:GetDescendants()) } do
			if inst:IsA("GuiObject") then
				table.insert(list, { inst = inst, prop = "BackgroundColor3", base = inst.BackgroundColor3 })
				if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
					table.insert(list, { inst = inst, prop = "ImageColor3", base = inst.ImageColor3 })
				end
			end
		end
		COLORS[button] = list
	end
	local info = TweenInfo.new(time, QUAD, OUT)
	for _, e in list do
		local c = e.base
		TweenService:Create(e.inst, info, { [e.prop] = Color3.new(c.R * factor, c.G * factor, c.B * factor) }):Play()
	end
end
-- Fin du noyau commun ----------------------------------------------------------------------------------------

local function play(button, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local on = o.on ~= false
	local back = o.back or "Default"
	if not setState(button, on and "Clicked" or back, o.Time) then
		local factor = on and o.Dim or (back == "Over" and o.OverDim or 1)
		dim(button, factor, o.Time)
	end
	return o.Time
end

-- APERÇU -------------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local LOOKS = {
	Default = { 150, "DEFAULT" },
	Over = { 180, "OVER" },
	Clicked = { 105, "CLICKED" },
	Active = { 210, "ACTIVE" },
	Disabled = { 85, "DISABLED" },
}

local function layeredButton(parent, pos)
	local b = new("TextButton", {
		Name = "PreviewLayered", AnchorPoint = Vector2.new(0.5, 0.5), Position = pos,
		Size = UDim2.fromOffset(220, 64), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
	})
	for name, look in LOOKS do
		local g = look[1]
		local layer = new("Frame", {
			Name = "State" .. name, Size = UDim2.fromScale(1, 1), Visible = name == "Default",
			BackgroundColor3 = Color3.fromRGB(g, g, g),
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, layer)
		new("TextLabel", {
			Name = "Label", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
			TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = look[2],
		}, layer)
		layer.Parent = b
	end
	b.Parent = parent
	return b
end

local function grayButton(parent, text, pos)
	local b = new("TextButton", {
		Name = "PreviewGray", AnchorPoint = Vector2.new(0.5, 0.5), Position = pos,
		Size = UDim2.fromOffset(220, 64), BackgroundColor3 = Color3.fromRGB(150, 150, 150), AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(13, 13, 20), Text = text,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
	b.Parent = parent
	return b
end

do
	local NAME = "_UIFX_PREVIEW_Clicked"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local a = layeredButton(sg, UDim2.fromScale(0.4, 0.5))
		local b = grayButton(sg, "Sans calque", UDim2.fromScale(0.6, 0.5))
		for i = 1, 3 do
			play(a, { on = true })
			play(b, { on = true })
			task.wait(0.35)
			local back = i == 2 and "Over" or "Default"
			play(a, { on = false, back = back })
			play(b, { on = false, back = back })
			task.wait(0.45)
		end
		play(a, { on = false })
		play(b, { on = false })
		task.wait(0.1)
		assert(a.StateDefault.Visible and not a.StateClicked.Visible, "état final inattendu")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_clicked : aperçu joué, " .. NAME .. " détruit")
end
