--[[
	Prototype : on comprend d'un coup d'œil que les premières cartes de la boutique sont faibles et les
	dernières excellentes (demande de Clément, 2026-11-13). À lancer en Edit : copie de UI_AuraShop dans
	CoreGui (_PROTO_ShopTiers_CLAUDE), rien n'est répliqué ni sauvegardé, StarterGui n'est pas touché.
	API : _G.ShopTiers.Show("Auras" | "Trails" | "Weapons"), _G.ShopTiers.Stop().
	Onglets Auras / Trails cliquables ; X ferme le prototype.

	Échelle par palier (rareté proposée : palier 1 = Common, 2 = Uncommon…) :
	- visuel : teinté de la couleur de l'objet (Config/Cosmetics), cerné d'une ombre noire, de 62 % à 100 %
	  de sa place ; Common grisé ; trails couchés (90°) comme une traînée ;
	- Common terne ; Rare : lueur derrière le visuel ; Epic : + rayons qui tournent ; Legendary : + contour
	  doré et 2 étincelles ; Mythic : + reflet qui descend et 4 étincelles ; Secret : arc-en-ciel, contour
	  arc-en-ciel et 5 étincelles ; Divine : or pâle, reflet qui passe, contour or pâle.
	Aucun script dans l'UI : ce prototype est piloté d'ici (barre de commande).
]]

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

if _G.ShopTiers and _G.ShopTiers.Stop then pcall(_G.ShopTiers.Stop) end

local NAME = "_PROTO_ShopTiers_CLAUDE"
local hex = Color3.fromHex
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local GLOW = "rbxassetid://130850617844067"
local RAYS = "rbxassetid://96610322911997" -- UI_Rays_Soft (groupe) : s'efface en cercle, pas de coupure en tournant
local STAR = "rbxassetid://98471192881940" -- FX_Aura_Etincelle : étoile à 4 branches
local RAINBOW = { hex("FF3B3B"), hex("FFC21A"), hex("3BE15A"), hex("2F9BFF"), hex("A855F7") }

-- Palier → style. Glow/Rays : transparence (nil = absent) ; Stars : nombre d'étincelles.
local TIER = {
	Common = { Top = hex("d3d6dc"), Bottom = hex("a9aeb8"), Text = hex("8d939e"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.94, Icon = 0.62, Grey = 0.55 },
	Uncommon = { Top = hex("a8ffd0"), Bottom = hex("2fd884"), Text = hex("2fe08f"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.88, Icon = 0.7 },
	Rare = { Top = hex("86e0ff"), Bottom = hex("2f9bff"), Text = hex("2f9bff"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.88, Icon = 0.78, Glow = 0.55 },
	Epic = { Top = hex("e0a6ff"), Bottom = hex("a855f7"), Text = hex("c77dff"), Edge = hex("2c1245"), EdgeT = 3, Studs = 0.88, Icon = 0.86, Glow = 0.4, Rays = 0.4, Spin = 10 },
	Legendary = { Top = hex("ffe98a"), Bottom = hex("ffb31a"), Text = hex("ffc21a"), Edge = hex("ffd84a"), EdgeT = 3.5, Studs = 0.88, Icon = 0.92, Glow = 0.3, Rays = 0.28, Spin = 14, Stars = 2 },
	Mythic = { Top = hex("ff95a5"), Bottom = hex("ff3b5c"), Text = hex("ff3b5c"), Edge = hex("ffd84a"), EdgeT = 4, Studs = 0.88, Icon = 1, Glow = 0.2, Rays = 0.18, Spin = 18, Stars = 4, Motion = "Sheen" },
	Secret = { Text = WHITE, Edge = WHITE, EdgeT = 4.5, Studs = 0.9, Icon = 1, Glow = 0.12, Rays = 0.1, Spin = 24, Stars = 5, Motion = "Rainbow" },
	Divine = { Top = hex("fff7d9"), Bottom = hex("e9c462"), Text = hex("ffe9a8"), Edge = hex("fff2c2"), EdgeT = 4.5, Studs = 0.9, Icon = 1, Glow = 0.1, Rays = 0.08, Spin = 24, Stars = 5, Motion = "Sweep" },
}
local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }

local SETS = {
	Auras = { Title = "Aura Shop", Word = "Power", Items = {
		{ "Spark", "rbxassetid://98471192881940", hex("FFD93B"), 1.5, 500 }, { "Flame", "rbxassetid://131088547064793", hex("FF6A1A"), 2, 15000 },
		{ "Lightning", "rbxassetid://75945124058128", hex("2FC4FF"), 3, 400000 }, { "Plasma", "rbxassetid://114471121541998", hex("FF3BD4"), 5, 10000000 },
		{ "Galaxy", "rbxassetid://81850914175452", hex("8B5CFF"), 8, 250000000 }, { "Royal", "rbxassetid://85620811638560", hex("FFC21A"), 11, 3000000000 },
	} },
	Trails = { Title = "Trail Shop", Word = "Speed", Rotate = 90, Items = {
		{ "Dust", "rbxassetid://85694011941199", hex("E5C38A"), 1.1, 300 }, { "Wind", "rbxassetid://105024342048733", hex("8CFFD4"), 1.25, 10000 },
		{ "Turbo", "rbxassetid://123304181369029", hex("FF7A1A"), 1.4, 300000 }, { "Comet", "rbxassetid://127285158778689", hex("4FC3FF"), 1.6, 8000000 },
		{ "Hyperspace", "rbxassetid://122381863731356", hex("9B5CFF"), 1.8, 200000000 },
	} },
	Weapons = { Title = "Weapon Shop", Word = "Power", NoTint = true, Items = {
		{ "Fists", "ICON_TOOL_Fists", nil, 1, 0 }, { "Wrench", "ICON_TOOL_Wrench", nil, 3, 300 }, { "Crowbar", "ICON_TOOL_Crowbar", nil, 8, 8000 },
		{ "Hammer", "ICON_TOOL_Hammer", nil, 20, 120000 }, { "Sledgehammer", "ICON_TOOL_Sledgehammer", nil, 50, 2000000 },
		{ "Fire Axe", "ICON_TOOL_FireAxe", nil, 125, 30000000 }, { "Angle Grinder", "ICON_TOOL_AngleGrinder", nil, 300, 400000000 },
	} },
}

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props or {} do o[k] = v end
	o.Parent = parent
	return o
end
local function short(v)
	for _, u in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if v >= u[1] then
			local s = string.format("%.1f", v / u[1]):gsub("%.0$", "")
			return s .. u[2]
		end
	end
	return tostring(v)
end
local function iconOf(n)
	local icons = RS.Assets:FindFirstChild("Icons")
	local d = icons and icons:FindFirstChild(n)
	return d and d.Texture or n
end

-- Écran : copie de UI_AuraShop ----------------------------------------------------------------------
local old = CoreGui:FindFirstChild(NAME)
if old then old:Destroy() end
local src = game.StarterGui:FindFirstChild("UI_AuraShop")
assert(src and src:FindFirstChild("Root"), "UI_AuraShop.Root introuvable")
local gui = src:Clone()
gui.Name = NAME
gui.Enabled = true
gui.DisplayOrder = 60
gui.Parent = CoreGui
local root = gui.Root
local list = root.List
local template = list.Template
for _, c in list:GetChildren() do if c.Name:match("^Preview_") then c:Destroy() end end

local animated, conns = {}, {}
local function keep(c) table.insert(conns, c) return c end

local function setFill(card, tier)
	local f = card.Fill
	for _, k in f:GetChildren() do k:Destroy() end
	f.Size, f.Position = UDim2.fromScale(1, 1), UDim2.new()
	if tier.Motion == "Rainbow" then
		f.Size = UDim2.fromScale(2, 1)
		local kp, n = {}, #RAINBOW
		for i = 0, 2 * n do table.insert(kp, ColorSequenceKeypoint.new(i / (2 * n), RAINBOW[i % n + 1]:Lerp(WHITE, 0.35))) end
		make("UIGradient", f, { Color = ColorSequence.new(kp) })
		table.insert(animated, { kind = "Rainbow", obj = f, phase = math.random() })
	else
		make("UIGradient", f, { Color = ColorSequence.new(tier.Top, tier.Bottom), Rotation = 90 })
		if tier.Motion == "Sheen" or tier.Motion == "Sweep" then
			local s = make("Frame", f, { Name = tier.Motion, Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4 })
			local mid = tier.Motion == "Sheen" and 0.45 or 0.35
			local g = make("UIGradient", s, { Rotation = tier.Motion == "Sheen" and 90 or 18, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.36, 1), NumberSequenceKeypoint.new(0.5, mid), NumberSequenceKeypoint.new(0.64, 1), NumberSequenceKeypoint.new(1, 1) }) })
			table.insert(animated, { kind = tier.Motion, obj = g, phase = math.random() })
		end
	end
end

local function styleCard(card, rarity, item, set)
	local tier = TIER[rarity]
	setFill(card, tier)
	card.Studs.ImageTransparency = tier.Studs
	local edge = card:FindFirstChildOfClass("UIStroke")
	edge.Color, edge.Thickness = tier.Edge, tier.EdgeT
	for _, g in edge:GetChildren() do g:Destroy() end
	if rarity == "Secret" then
		local kp = {}
		for i, col in RAINBOW do table.insert(kp, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), col)) end
		local g = make("UIGradient", edge, { Color = ColorSequence.new(kp) })
		table.insert(animated, { kind = "Spin", obj = g, speed = 90, phase = 0 })
	end
	local rl = card:FindFirstChild("RarityLabel", true)
	rl.Text, rl.TextColor3 = rarity, tier.Text
	for _, g in rl:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
	if rarity == "Secret" then
		local kp = {}
		for i, col in RAINBOW do table.insert(kp, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), col)) end
		make("UIGradient", rl, { Color = ColorSequence.new(kp) })
	end

	-- visuel : lueur, rayons, ombre, objet teinté, étincelles
	local area = card:FindFirstChild("IconArea", true)
	local icon = area.Icon
	for _, k in area:GetChildren() do if k ~= icon and k:IsA("GuiObject") then k:Destroy() end end
	local glowColor = tier.Text:Lerp(WHITE, 0.4)
	if tier.Rays then
		local r = make("ImageLabel", area, { Name = "Rays", Image = RAYS, ImageColor3 = (tier.Text):Lerp(WHITE, 0.75), ImageTransparency = tier.Rays, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.9, 1.9), ZIndex = 5 })
		make("UIAspectRatioConstraint", r, { AspectRatio = 1 })
		table.insert(animated, { kind = "Rotate", obj = r, speed = tier.Spin, phase = math.random() * 360 })
	end
	if tier.Glow then
		local g = make("ImageLabel", area, { Name = "Glow", Image = GLOW, ImageColor3 = glowColor, ImageTransparency = tier.Glow, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.15, 1.15), ZIndex = 5 })
		make("UIAspectRatioConstraint", g, { AspectRatio = 1 })
		table.insert(animated, { kind = "Pulse", obj = g, base = tier.Glow, phase = math.random() * 6 })
	end
	local img = set.NoTint and iconOf(item[2]) or item[2]
	local tint = set.NoTint and WHITE or item[3]
	if tier.Grey and not set.NoTint then tint = tint:Lerp(hex("8a8f99"), tier.Grey) end
	local s = tier.Icon
	local shadow = make("ImageLabel", area, { Name = "IconShadow", Image = img, ImageColor3 = BLACK, ImageTransparency = 0.25, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.515, 0.53), Size = UDim2.fromScale(0.92 * s * 1.06, s * 1.06), Rotation = set.Rotate or 0, ZIndex = 6 })
	icon.Image, icon.ImageColor3, icon.Rotation = img, tint, set.Rotate or 0
	icon.Size, icon.ZIndex = UDim2.fromScale(0.92 * s, s), 7 -- au-dessus de son ombre (ZIndex 6)
	for i = 1, tier.Stars or 0 do
		local spots = { { 0.16, 0.18 }, { 0.84, 0.78 }, { 0.82, 0.16 }, { 0.18, 0.82 }, { 0.5, 0.04 } }
		local p = spots[i]
		local st = make("ImageLabel", area, { Name = "Star" .. i, Image = STAR, ImageColor3 = rarity == "Secret" and WHITE or hex("fff6c2"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromScale(0.2, 0.2), ZIndex = 8 })
		make("UIAspectRatioConstraint", st, { AspectRatio = 1 })
		table.insert(animated, { kind = "Twinkle", obj = st, phase = i * 1.3 })
	end
	return shadow
end

local current = "Auras"
local cells = {}
local function show(name)
	current = name
	local set = SETS[name]
	for _, c in cells do c:Destroy() end
	table.clear(cells)
	table.clear(animated)
	root.Header.Title.Text = set.Title
	local tabs = root:FindFirstChild("Tabs")
	if tabs then
		tabs.Visible = name ~= "Weapons"
		for _, t in { "AurasTab", "TrailsTab" } do
			local sel = tabs[t]:FindFirstChild("Selected")
			if sel then sel.Visible = (t == "AurasTab") == (name == "Auras") end
		end
	end
	local headerGrad = root.Header:FindFirstChildOfClass("UIGradient")
	headerGrad.Color = name == "Weapons" and ColorSequence.new({ ColorSequenceKeypoint.new(0, hex("f1b837")), ColorSequenceKeypoint.new(0.45, hex("f29720")), ColorSequenceKeypoint.new(1, hex("e1680a")) })
		or ColorSequence.new({ ColorSequenceKeypoint.new(0, hex("7fe8fb")), ColorSequenceKeypoint.new(0.45, hex("3fbaf2")), ColorSequenceKeypoint.new(1, hex("1a8fd8")) })
	for i, item in set.Items do
		local cell = template:Clone()
		cell.Name = "Tier_" .. i
		cell.LayoutOrder = i
		cell.Visible = true
		local card = cell.Card
		local nameLabel = card:FindFirstChild("ItemName", true)
		if nameLabel then nameLabel.Text = item[1] end
		local bandFrame = card:FindFirstChild("BonusBand", true)
		local band = bandFrame and bandFrame:FindFirstChildWhichIsA("TextLabel")
		if band then band.Text = name == "Weapons" and ("Power: " .. short(item[4])) or ("×" .. tostring(item[4]) .. " " .. set.Word) end
		local price = card:FindFirstChild("Price", true)
		if price then price.Text = item[5] <= 0 and "Free" or ("$" .. short(item[5])) end
		styleCard(card, ORDER[i], item, set)
		cell.Parent = list
		table.insert(cells, cell)
	end
	list.CanvasPosition = Vector2.zero
end

local tabs = root:FindFirstChild("Tabs")
if tabs then
	keep(tabs.AurasTab.Activated:Connect(function() show("Auras") end))
	keep(tabs.TrailsTab.Activated:Connect(function() show("Trails") end))
end
keep(root.CloseButton.Activated:Connect(function() if _G.ShopTiers then _G.ShopTiers.Stop() end end))

local clock = 0
keep(RunService.Heartbeat:Connect(function(dt)
	clock += dt
	for _, a in animated do
		local o = a.obj
		if o.Parent == nil then continue end
		if a.kind == "Rotate" then
			o.Rotation = (a.phase + clock * a.speed) % 360
		elseif a.kind == "Spin" then
			o.Rotation = (clock * a.speed) % 360
		elseif a.kind == "Pulse" then
			o.ImageTransparency = math.clamp(a.base + 0.12 * math.sin(clock * 2.4 + a.phase), 0, 1)
		elseif a.kind == "Twinkle" then
			local k = 0.5 + 0.5 * math.sin(clock * 3 + a.phase)
			o.ImageTransparency = 0.6 - 0.6 * k
			o.Rotation = (clock * 40 + a.phase * 30) % 360
			o.Size = UDim2.fromScale(0.12 + 0.1 * k, 0.12 + 0.1 * k)
		elseif a.kind == "Rainbow" then
			o.Position = UDim2.fromScale(-((clock * 0.36 + a.phase) % 1), 0)
		elseif a.kind == "Sheen" then
			o.Offset = Vector2.new(0, -0.9 + 1.8 * ((clock / 2.1 + a.phase) % 1))
		elseif a.kind == "Sweep" then
			o.Offset = Vector2.new(-1.1 + 2.2 * ((clock / 3 + a.phase) % 1), 0)
		end
	end
end))

show("Auras")

_G.ShopTiers = {
	Show = show,
	Stop = function()
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		if gui.Parent then gui:Destroy() end
		_G.ShopTiers = nil
	end,
}
return "Prototype des paliers ouvert (CoreGui." .. NAME .. ")"
