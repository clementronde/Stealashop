--!nonstrict
--[[
	uifx_disabled.luau : aperçu de l'état de bouton Disabled (Steal a Shop, UI de Clément, 25/11/2026)

	Ce que fait l'effet : l'aspect d'un bouton qu'on ne peut pas cliquer (pas assez d'argent, déjà acheté).
	Attribut : aucun nouvel attribut. L'état suit la propriété Interactable du bouton : le code la passe
	à false, puis play montre l'enfant StateDisabled (dessiné par Clément) ; Motion ne doit plus jouer le
	survol ni l'appui tant que Interactable est false.
	Sans calque StateDisabled : couleurs du bouton et de ses enfants (fond, image, texte) tirées à 75 %
	vers leur gris, un peu foncé.
	Durée, courbe (V0) : 0,12 s, Quad Out, à l'entrée et à la sortie de l'état. Tenu.
	Propriétés animées : transparences du calque, Visible ; sinon BackgroundColor3, ImageColor3, TextColor3.

	Code écrit par nous d'après le comportement observé ; aucun fichier, image ni code du plugin Figma.
	Pour Ironix : button.Interactable = false ; play(button). Puis button.Interactable = true ; play(button).
	play(button, { on = true | false }) force l'état sans lire Interactable.
	Aperçu : coller dans la barre de commande en Edit. Construit _UIFX_PREVIEW_Disabled dans CoreGui,
	bloque et débloque 3 fois, puis détruit tout.
]]

local TweenService = game:GetService("TweenService")
local QUAD, OUT, IN = Enum.EasingStyle.Quad, Enum.EasingDirection.Out, Enum.EasingDirection.In

local DEFAULTS = {
	Time = 0.12, -- s
	Gray = 0.75, -- part du chemin vers le gris (0 = couleurs d'origine)
	Darken = 0.85, -- le gris visé est un peu foncé
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

local GRAY = setmetatable({}, { __mode = "k" })

local function toGray(button, amount, darken, time)
	local list = GRAY[button]
	if not list then
		list = {}
		for _, inst in { button, table.unpack(button:GetDescendants()) } do
			if inst:IsA("GuiObject") then
				table.insert(list, { inst = inst, prop = "BackgroundColor3", base = inst.BackgroundColor3 })
				if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
					table.insert(list, { inst = inst, prop = "ImageColor3", base = inst.ImageColor3 })
				end
				if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
					table.insert(list, { inst = inst, prop = "TextColor3", base = inst.TextColor3 })
				end
			end
		end
		GRAY[button] = list
	end
	local info = TweenInfo.new(time, QUAD, OUT)
	for _, e in list do
		local c = e.base
		local l = (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) * darken
		TweenService:Create(e.inst, info, { [e.prop] = c:Lerp(Color3.new(l, l, l), amount) }):Play()
	end
end

local function play(button, options)
	options = options or {}
	local o = setmetatable(options, { __index = DEFAULTS })
	local on = o.on
	if on == nil then on = not button.Interactable end
	if not setState(button, on and "Disabled" or "Default", o.Time) then
		toGray(button, on and o.Gray or 0, on and o.Darken or 1, o.Time)
	end
	return on
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
	local NAME = "_UIFX_PREVIEW_Disabled"
	local CoreGui = game:GetService("CoreGui")
	local old = CoreGui:FindFirstChild(NAME)
	if old then old:Destroy() end
	local sg = new("ScreenGui", { Name = NAME, ResetOnSpawn = false }, CoreGui)

	local ok, err = pcall(function()
		local a = layeredButton(sg, UDim2.fromScale(0.4, 0.5))
		local b = grayButton(sg, "Sans calque", UDim2.fromScale(0.6, 0.5))
		b.BackgroundColor3 = Color3.fromRGB(90, 170, 90) -- un peu de couleur pour voir le gris
		for _ = 1, 3 do
			for _, btn in { a, b } do
				btn.Interactable = false
				play(btn)
			end
			task.wait(0.6)
			for _, btn in { a, b } do
				btn.Interactable = true
				play(btn)
			end
			task.wait(0.5)
		end
		assert(a.StateDefault.Visible and not a.StateDisabled.Visible, "état final inattendu")
	end)

	sg:Destroy()
	if not ok then error(err) end
	print("uifx_disabled : aperçu joué, " .. NAME .. " détruit")
end
