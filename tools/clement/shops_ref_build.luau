--[[
	UI_AuraShop et UI_WeaponShop refaits sur le modèle de la vidéo de référence de Clément (prototype
	validé le 2026-11-13 : shop_ref_proto.luau). À lancer en Edit. Annulable (Ctrl+Z).
	- Les anciens Root sont rangés dans ServerStorage/_UI_RETIREE (OLD_UI_AuraShop_Root_2026-11-13,
	  OLD_UI_WeaponShop_Root_2026-11-13) : rien n'est perdu.
	- Noms du contrat gardés : CloseButton, Tabs.AurasTab, Tabs.TrailsTab (auras), List (ScrollingFrame),
	  List.Template avec Icon, ItemName, Bonus (auras) ou Power (armes), Price, BuyButton, EquipButton.
	  Price est dans BuyButton, Bonus et Power dans BonusBand : le code les trouve à n'importe quel niveau.
	- Ajoutés, pas lus par le code aujourd'hui : Card, Card.Fill (fond selon la rareté), RarityLabel
	  (vide dans Template), BonusBand, RobuxButton (visible, prix « — » : aucun prix Robux au doc), Tabs.*.Selected.
	- Cartes d'exemple Preview_* (retirées par le code à l'ouverture) avec la rareté proposée par palier.
	- ReplicatedStorage/Assets/UI/ShopCardBg/<Rareté> : un fond de carte par rareté, que le code clonera
	  dans Card.Fill. Attributs : RarityColor (couleur du texte de rareté), Motion (Sheen, Rainbow ou
	  Sweep pour les fonds animés), Period (s pour un passage) ou Speed (largeurs de carte par seconde).
	Aucun script.
]]

local CH = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local STUDS = "rbxassetid://3014551673"
local ROBUX = "rbxassetid://139320447847280"
local hex = Color3.fromHex
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local RAR = {
	{ Id = "Common", Text = hex("9aa0ab"), Top = hex("f4f4f6"), Bottom = hex("c6cad2") },
	{ Id = "Uncommon", Text = hex("2fe08f"), Top = hex("a8ffd0"), Bottom = hex("2fd884") },
	{ Id = "Rare", Text = hex("2f9bff"), Top = hex("86e0ff"), Bottom = hex("2f9bff") },
	{ Id = "Epic", Text = hex("c77dff"), Top = hex("e0a6ff"), Bottom = hex("a855f7") },
	{ Id = "Legendary", Text = hex("ffc21a"), Top = hex("ffe98a"), Bottom = hex("ffb31a") },
	{ Id = "Mythic", Text = hex("ff3b5c"), Top = hex("ff95a5"), Bottom = hex("ff3b5c"), Motion = "Sheen", Period = 2.1 },
	{ Id = "Secret", Text = WHITE, Motion = "Rainbow", Speed = 0.36 },
	{ Id = "Divine", Text = hex("ffe9a8"), Top = hex("fff7d9"), Bottom = hex("e9c462"), Motion = "Sweep", Period = 3 },
}
local RAINBOW = { hex("FF3B3B"), hex("FFC21A"), hex("3BE15A"), hex("2F9BFF"), hex("A855F7") }

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props or {} do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(p, r) return make("UICorner", p, { CornerRadius = UDim.new(r or 0.12, 0) }) end
local function stroke(p, t, c) return make("UIStroke", p, { Thickness = t, Color = c or hex("1b1b1b"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function grad(p, top, bottom, rot) return make("UIGradient", p, { Color = ColorSequence.new(top, bottom), Rotation = rot or 90 }) end
local function textStroke(t, th)
	make("UIStroke", t, { Thickness = th or 0.09, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Color = hex("101010"), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round })
end
local function label(p, name, str, z, props, color)
	local t = make("TextLabel", p, { Name = name, Text = str, FontFace = FONT, TextColor3 = color or WHITE, BackgroundTransparency = 1, TextScaled = true, TextWrapped = true, ZIndex = z })
	textStroke(t)
	for k, v in props or {} do t[k] = v end
	return t
end
local function studs(p, tile, transp, z)
	return make("ImageLabel", p, { Name = "Studs", Image = STUDS, ScaleType = Enum.ScaleType.Tile, TileSize = tile, ImageTransparency = transp, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z })
end
-- Bouton : le fond dégradé est dans Fill (sous le texte), Shade au-dessus pour le survol (Motion).
local function button(parent, name, top, bottom, z, props, edge)
	local b = make("TextButton", parent, { Name = name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 1, FontFace = FONT, TextColor3 = WHITE, TextScaled = true, TextWrapped = true })
	for k, v in props or {} do b[k] = v end
	local f = make("Frame", b, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = z })
	grad(f, top, bottom)
	corner(f)
	stroke(f, 2.5, edge)
	local sh = make("Frame", b, { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = z + 3 })
	corner(sh)
	return b
end
-- Fond d'une carte pour une rareté (dans `parent`, nommé `name`).
local function rarityFill(parent, name, r, z)
	local f = make("Frame", parent, { Name = name, Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z })
	f:SetAttribute("Rarity", r.Id)
	f:SetAttribute("RarityColor", r.Text)
	if r.Motion then f:SetAttribute("Motion", r.Motion) end
	if r.Period then f:SetAttribute("Period", r.Period) end
	if r.Speed then f:SetAttribute("Speed", r.Speed) end
	if r.Motion == "Rainbow" then
		-- deux tours d'arc-en-ciel sur deux largeurs de carte : le code fait glisser Position.X de 0 à -1
		f.Size = UDim2.fromScale(2, 1)
		local kp, n = {}, #RAINBOW
		for i = 0, 2 * n do table.insert(kp, ColorSequenceKeypoint.new(i / (2 * n), RAINBOW[i % n + 1]:Lerp(WHITE, 0.35))) end
		make("UIGradient", f, { Name = "Colors", Color = ColorSequence.new(kp), Rotation = 0 })
		local tg = {}
		for i, col in RAINBOW do table.insert(tg, ColorSequenceKeypoint.new((i - 1) / (n - 1), col)) end
		make("UIGradient", f, { Name = "TextGradient", Color = ColorSequence.new(tg), Enabled = false }) -- à copier sur RarityLabel
	else
		make("UIGradient", f, { Name = "Colors", Color = ColorSequence.new(r.Top, r.Bottom), Rotation = 90 })
		if r.Motion == "Sheen" then
			-- bande claire : le code fait aller Offset.Y de -0,9 à 0,9 en Period s, en boucle
			local s = make("Frame", f, { Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z })
			make("UIGradient", s, { Rotation = 90, Offset = Vector2.new(0, -0.9), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.36, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.64, 1), NumberSequenceKeypoint.new(1, 1) }) })
		elseif r.Motion == "Sweep" then
			-- reflet penché : le code fait aller Offset.X de -1,1 à 1,1 en Period s, en boucle
			local s = make("Frame", f, { Name = "Sweep", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z })
			make("UIGradient", s, { Rotation = 18, Offset = Vector2.new(-1.1, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 1) }) })
		end
	end
	return f
end

-- Panneau commun ---------------------------------------------------------------------------------
local function buildRoot(gui, title, headerColors, bandName, bandSample)
	local root = make("Frame", gui, { Name = "Root", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.new(0.515, 217, 0.92, 0), BackgroundColor3 = hex("32322f"), ZIndex = 1 })
	make("UIAspectRatioConstraint", root, { AspectRatio = 1178 / 700 })
	corner(root, 0.012)
	stroke(root, 3, hex("121212"))
	studs(root, UDim2.fromScale(0.026, 0.044), 0.93, 2)

	local bar = make("Frame", root, { Name = "Header", Position = UDim2.fromScale(0.0017, 0.0043), Size = UDim2.fromScale(0.9966, 0.164), BackgroundColor3 = WHITE, ClipsDescendants = true, ZIndex = 3 })
	make("UIGradient", bar, { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, headerColors[1]), ColorSequenceKeypoint.new(0.45, headerColors[2]), ColorSequenceKeypoint.new(1, headerColors[3]) }) })
	for i, x in { 0.47, 0.53, 0.62 } do
		make("Frame", bar, { Name = "Stripe" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(i == 2 and 0.012 or 0.028, 1.9), Rotation = 28, BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 4 })
	end
	make("Frame", bar, { Name = "HeaderLine", Position = UDim2.fromScale(0, 0.975), Size = UDim2.fromScale(1, 0.025), BackgroundColor3 = headerColors[4], BorderSizePixel = 0, ZIndex = 5 })
	label(bar, "Title", title, 6, { Position = UDim2.fromScale(0.025, 0.12), Size = UDim2.fromScale(0.5, 0.76), TextXAlignment = Enum.TextXAlignment.Left })

	-- carré grâce au rapport du panneau (0,082 × 1178 ≈ 0,137 × 700) ; 44 px au moins sur téléphone
	local close = button(root, "CloseButton", hex("ff5b6b"), hex("b3101f"), 7, { Position = UDim2.fromScale(0.947, 0.087), Size = UDim2.fromScale(0.082, 0.137) }, hex("2a0b0f"))
	make("UISizeConstraint", close, { MinSize = Vector2.new(44, 44) })
	label(close, "XLabel", "X", 8, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7) })

	-- 3 cartes visibles ; chaque case = carte + écart (388 × 525 sur la vidéo), hauteur 93,25 % de la liste
	local list = make("ScrollingFrame", root, { Name = "List", Position = UDim2.fromScale(0.0153, 0.194), Size = UDim2.fromScale(0.9686, 0.804), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("d4d4d4"), HorizontalScrollBarInset = Enum.ScrollBarInset.None, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 3 })
	local grid = make("UIGridLayout", list, { FillDirection = Enum.FillDirection.Vertical, FillDirectionMaxCells = 1, CellSize = UDim2.new(0, 10000, 0.9325, 0), CellPadding = UDim2.new(), SortOrder = Enum.SortOrder.LayoutOrder })
	make("UIAspectRatioConstraint", grid, { AspectRatio = 388 / 525 })

	-- carte modèle
	local template = make("Frame", list, { Name = "Template", BackgroundTransparency = 1, Visible = false, ZIndex = 3 })
	local card = make("Frame", template, { Name = "Card", Size = UDim2.fromScale(365 / 388, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4 })
	corner(card, 0.025)
	stroke(card, 2.5, hex("1e1e1e"))
	rarityFill(card, "Fill", RAR[1], 4)
	studs(card, UDim2.fromScale(0.0822, 0.057), 0.88, 5)
	-- contenu en colonne : sur téléphone, la rangée des boutons garde 44 px et le visuel (IconArea) prend le reste
	local content = make("Frame", card, { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
	make("UIPadding", content, { PaddingTop = UDim.new(0.03, 0), PaddingBottom = UDim.new(0.032, 0), PaddingLeft = UDim.new(0.041, 0), PaddingRight = UDim.new(0.041, 0) })
	make("UIListLayout", content, { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.012, 0) })
	label(content, "ItemName", "Spark", 7, { Size = UDim2.fromScale(1, 0.12), LayoutOrder = 1 })
	label(content, "RarityLabel", "", 7, { Size = UDim2.fromScale(0.76, 0.075), LayoutOrder = 2 }, RAR[1].Text)
	local area = make("Frame", content, { Name = "IconArea", Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 6 })
	make("UIFlexItem", area, { FlexMode = Enum.UIFlexMode.Fill })
	make("ImageLabel", area, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 6 })
	local band = make("Frame", content, { Name = "BonusBand", Size = UDim2.fromScale(1, 0.143), BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, LayoutOrder = 4, ZIndex = 6 })
	make("UISizeConstraint", band, { MinSize = Vector2.new(0, 28) })
	stroke(band, 2, hex("1e1e1e"))
	label(band, bandName, bandSample, 7, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.74) })
	make("Frame", content, { Name = "Spacer", Size = UDim2.fromScale(1, 0.012), BackgroundTransparency = 1, LayoutOrder = 5 })
	local rowB = make("Frame", content, { Name = "ButtonRow", Size = UDim2.fromScale(1, 0.143), BackgroundTransparency = 1, LayoutOrder = 6, ZIndex = 6 })
	make("UISizeConstraint", rowB, { MinSize = Vector2.new(0, 44) })
	-- achat en $ en vert (Clément, 2026-11-13) et achat en Robux à côté, comme la vidéo
	local buy = button(rowB, "BuyButton", hex("dbfe4e"), hex("57eb0a"), 8, { Position = UDim2.fromScale(0.3135, 0.5), Size = UDim2.fromScale(0.627, 1) })
	label(buy, "Price", "$500", 9, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.72) })
	local rbx = button(rowB, "RobuxButton", hex("d96df3"), hex("bb0bef"), 8, { Position = UDim2.fromScale(0.829, 0.5), Size = UDim2.fromScale(0.343, 1) })
	local rc = make("Frame", rbx, { Name = "Content", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.7), ZIndex = 9 })
	make("UIListLayout", rc, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder })
	local ri = make("ImageLabel", rc, { Name = "RobuxIcon", Image = ROBUX, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.9), ZIndex = 9 })
	make("UIAspectRatioConstraint", ri, { AspectRatio = 1 })
	label(rc, "RobuxPrice", "—", 9, { Size = UDim2.fromScale(0.5, 1), LayoutOrder = 2 })
	root:SetAttribute("Build", "shops_ref_build")
	return root, list, template, card, rowB
end

-- Pose une propriété sur le descendant `name` de `root` s'il existe.
local function setOn(root, name, prop, value)
	local x = root:FindFirstChild(name, true)
	if x then
		x[prop] = value
	end
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

local function preview(list, template, i, name, img, bandText, price, rarity, equipText)
	local p = template:Clone()
	p.Name = "Preview_" .. i
	p.LayoutOrder = i
	p.Visible = true
	local c = p.Card
	local function find(n) return c:FindFirstChild(n, true) end
	find("ItemName").Text = name
	find("Icon").Image = img
	local bandLabel = find("BonusBand"):FindFirstChildWhichIsA("TextLabel")
	if bandLabel then bandLabel.Text = bandText end
	find("Price").Text = price
	c.Fill:Destroy()
	local fill = rarityFill(c, "Fill", rarity, 4)
	local rl = find("RarityLabel")
	rl.Text = rarity.Id
	rl.TextColor3 = rarity.Text
	if rarity.Motion == "Rainbow" then
		local tg = fill.TextGradient:Clone()
		tg.Enabled = true
		tg.Parent = rl
	end
	if equipText then
		find("BuyButton").Visible = false
		local eq = find("EquipButton")
		eq.Visible = true
		local holder = eq:FindFirstChild("EquipLabel") or eq
		holder.Text = equipText
	end
	p.Parent = list
end

-- L'ancien Root de Clément va dans _UI_RETIREE ; un Root de ce script (attribut Build) est simplement remplacé.
local function retire(gui)
	local old = gui:FindFirstChild("Root")
	if not old then return end
	if old:GetAttribute("Build") == "shops_ref_build" or old:FindFirstChild("Stripe1", true) then
		old:Destroy()
		return
	end
	local folder = SS:FindFirstChild("_UI_RETIREE") or make("Folder", SS, { Name = "_UI_RETIREE" })
	local name = "OLD_" .. gui.Name .. "_Root_2026-11-13"
	local prev = folder:FindFirstChild(name)
	if prev then prev:Destroy() end
	old.Name = name
	old.Parent = folder
end

local rec = CH:TryBeginRecording("Boutiques sur le modèle de la vidéo (UI_AuraShop, UI_WeaponShop)")

-- UI_AuraShop (bandeau bleu, comme la boutique de trails de la vidéo) ------------------------------
local aura = SG:FindFirstChild("UI_AuraShop")
retire(aura)
aura.IgnoreGuiInset = false
aura.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local root, list, template, card, row = buildRoot(aura, "Aura Shop", { hex("7fe8fb"), hex("3fbaf2"), hex("1a8fd8"), hex("0f4f86") }, "Bonus", "×1.5 power")
-- EquipButton au-dessus de RobuxButton (ZIndex 11) : sur un objet possédé, il le recouvre
local equip = button(row, "EquipButton", hex("dbfe4e"), hex("57eb0a"), 11, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Visible = false })
label(equip, "EquipLabel", "Equip", 12, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.72) })
local tabs = make("Frame", root, { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromScale(0.6, 0.032), Size = UDim2.fromScale(0.29, 0.108), ZIndex = 7 })
for i, def in { { "AurasTab", "Auras" }, { "TrailsTab", "Trails" } } do
	local b = button(tabs, def[1], hex("f9f9f6"), hex("b6b9c2"), 7, { Position = UDim2.fromScale(0.25 + (i - 1) * 0.5, 0.5), Size = UDim2.fromScale(0.47, 0.92) })
	make("UISizeConstraint", b, { MinSize = Vector2.new(0, 44) })
	-- onglet ouvert : calque jaune Selected (le code le montre sur l'onglet ouvert)
	local sel = make("Frame", b, { Name = "Selected", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Visible = i == 1, ZIndex = 8 })
	grad(sel, hex("fff36b"), hex("ffb71a"))
	corner(sel)
	stroke(sel, 2.5)
	label(b, "TabLabel", def[2], 9, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.7) })
end
local AURAS = {
	{ "Spark", "rbxassetid://98471192881940", 1.5, 500 }, { "Flame", "rbxassetid://131088547064793", 2, 15000 },
	{ "Lightning", "rbxassetid://75945124058128", 3, 400000 }, { "Plasma", "rbxassetid://114471121541998", 5, 10000000 },
	{ "Galaxy", "rbxassetid://81850914175452", 8, 250000000 }, { "Royal", "rbxassetid://85620811638560", 11, 3000000000 },
}
setOn(template, "Icon", "Image", AURAS[1][2])
for i, a in AURAS do
	preview(list, template, i, a[1], a[2], "×" .. tostring(a[3]) .. " Power", "$" .. short(a[4]), RAR[i], i == 1 and "Unequip" or nil)
end

-- UI_WeaponShop (bandeau orange, comme le magasin de pelles de la vidéo) ---------------------------
local weapon = SG:FindFirstChild("UI_WeaponShop")
retire(weapon)
weapon.IgnoreGuiInset = false
weapon.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local wroot, wlist, wtemplate, wcard, wrow = buildRoot(weapon, "Weapon Shop", { hex("f1b837"), hex("f29720"), hex("e1680a"), hex("8a3a00") }, "Power", "Power: 8")
-- EquipButton porte son texte : le code y écrit « Equipped » sur l'arme équipée
local wequip = button(wrow, "EquipButton", hex("dbfe4e"), hex("57eb0a"), 11, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Visible = false, Text = "Equip" })
make("UIPadding", wequip, { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), PaddingLeft = UDim.new(0.08, 0), PaddingRight = UDim.new(0.08, 0) })
textStroke(wequip)
-- la marge rétrécit aussi les enfants : Fill et Shade sont agrandis pour couvrir tout le bouton
for _, n in { "Fill", "Shade" } do
	local f = wequip:FindFirstChild(n)
	if f then
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(1 / 0.84, 1 / 0.72)
	end
end
local TOOLS = {
	{ "Fists", "ICON_TOOL_Fists", 1, 0 }, { "Wrench", "ICON_TOOL_Wrench", 3, 300 }, { "Crowbar", "ICON_TOOL_Crowbar", 8, 8000 },
	{ "Hammer", "ICON_TOOL_Hammer", 20, 120000 }, { "Sledgehammer", "ICON_TOOL_Sledgehammer", 50, 2000000 },
	{ "Fire Axe", "ICON_TOOL_FireAxe", 125, 30000000 }, { "Angle Grinder", "ICON_TOOL_AngleGrinder", 300, 400000000 },
}
local icons = RS.Assets:FindFirstChild("Icons")
local function iconOf(n) local d = icons and icons:FindFirstChild(n) return d and d.Texture or "" end
setOn(wtemplate, "ItemName", "Text", "Crowbar")
setOn(wtemplate, "Icon", "Image", iconOf("ICON_TOOL_Crowbar"))
setOn(wtemplate, "Price", "Text", "$8K")
for i, t in TOOLS do
	preview(wlist, wtemplate, i, t[1], iconOf(t[2]), "Power: " .. short(t[3]), t[4] <= 0 and "Free" or "$" .. short(t[4]), RAR[i], i == 1 and "Equipped" or nil)
end

-- Fonds de carte par rareté, pour le code ----------------------------------------------------------
local ui = RS.Assets:FindFirstChild("UI")
local bgs = ui:FindFirstChild("ShopCardBg")
if bgs then bgs:Destroy() end
bgs = make("Folder", ui, { Name = "ShopCardBg" })
for _, r in RAR do rarityFill(bgs, r.Id, r, 4) end

if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return "UI_AuraShop et UI_WeaponShop refaits ; anciens Root dans ServerStorage/_UI_RETIREE ; Assets/UI/ShopCardBg posé"
