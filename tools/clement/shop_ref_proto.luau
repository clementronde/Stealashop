--[[
	Prototype de la boutique d'auras sur le modèle de la vidéo de référence de Clément
	(StealAShop-Art/References/2026-11-13_Boutiques/boutique_reference.mp4, 1866 × 950, 30 images/s).
	À lancer en Edit : copie dans CoreGui (_PROTO_AuraShop_CLAUDE), rien n'est répliqué ni sauvegardé.
	Jouable à la souris dans le viewport : survol et clic des boutons, molette ou glisser pour faire
	défiler, X pour fermer (réouverture 1 s après), onglets Auras / Trails, achat et équipement simulés.
	API : _G.ShopProto.Replay(), .Close(), .Rarity("Secret") (toutes les cartes à cette rareté), .Stop().

	Valeurs mesurées sur la vidéo (tableau : docs/claude/notes/ui-motion-skilltree.md, section « Boutiques ») :
	- panneau 1178 × 700 sur 1866 (63 % de la largeur), rapport 1,683, haut à 20 px sous la barre Roblox ;
	- ouverture : échelle 0,5 → 1 en 0,10 s, Quad Out, en montant de 0,2 × sa hauteur (pivot à 70 % de
	  la hauteur depuis le haut) ; fermeture : 1 → 0,7 en 0,11 s, Quad In, pivot à 62,5 %, puis caché ;
	- boutons : survol × 1,12 et 10 % plus sombre en 0,10 s (retour 0,08 s) ; appui × 0,88 en 0,04 s,
	  relâché en 0,07 s ; les cartes ne bougent pas au survol ;
	- défilement : 3 cartes visibles, de droite à gauche ; un cran de molette = 26 % d'une carte et de
	  son écart, et le contenu rattrape sa cible en divisant l'écart par 2 toutes les 33 ms ; pas de
	  calage sur les cartes ;
	- fonds : Common à Legendary fixes (dégradé du haut vers le bas) ; Mythic, Secret et Divine animés.
	Rareté des auras et des trails : PROPOSITION (absente du doc), palier 1 = Common, 2 = Uncommon…
	Prix Robux : absents du doc, le bouton violet affiche « — ».
	Aucun script dans l'UI : ce prototype est piloté d'ici (barre de commande).
]]

local CoreGui = game:GetService("CoreGui")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

if _G.ShopProto and _G.ShopProto.Stop then pcall(_G.ShopProto.Stop) end

local NAME = "_PROTO_AuraShop_CLAUDE"
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local STUDS = "rbxassetid://3014551673"
local ROBUX = "rbxassetid://139320447847280"
local hex = Color3.fromHex

local V = {
	Aspect = 1178 / 700,
	Top = 20,
	OpenFrom = 0.5, OpenTime = 0.10, OpenPivot = 0.70,
	CloseTo = 0.7, CloseTime = 0.11, ClosePivot = 0.625,
	HoverTo = 1.12, HoverTime = 0.10, HoverBack = 0.08, HoverShade = 0.9,
	PressTo = 0.88, PressTime = 0.04, ReleaseTime = 0.07,
	WheelStep = 0.26, Half = 0.033,
}

-- Couleurs des cartes par rareté : nos couleurs (Config/Rarities), haut clair, bas saturé, comme la vidéo.
local RAR = {
	Common = { Text = hex("9aa0ab"), Top = hex("f4f4f6"), Bottom = hex("c6cad2") },
	Uncommon = { Text = hex("2fe08f"), Top = hex("a8ffd0"), Bottom = hex("2fd884") },
	Rare = { Text = hex("2f9bff"), Top = hex("86e0ff"), Bottom = hex("2f9bff") },
	Epic = { Text = hex("c77dff"), Top = hex("e0a6ff"), Bottom = hex("a855f7") },
	Legendary = { Text = hex("ffc21a"), Top = hex("ffe98a"), Bottom = hex("ffb31a") },
	Mythic = { Text = hex("ff3b5c"), Top = hex("ff95a5"), Bottom = hex("ff3b5c"), Anim = "Sheen" },
	Secret = { Text = hex("ffffff"), Top = hex("ffffff"), Bottom = hex("ffffff"), Anim = "Rainbow" },
	Divine = { Text = hex("ffe9a8"), Top = hex("fff7d9"), Bottom = hex("e9c462"), Anim = "Sweep" },
}
local RAINBOW = { hex("FF3B3B"), hex("FFC21A"), hex("3BE15A"), hex("2F9BFF"), hex("A855F7") }
local ORDER_RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }

local AURAS = {
	{ Id = "Spark", Name = "Spark", Mult = 1.5, Price = 500, Img = "rbxassetid://98471192881940" },
	{ Id = "Flame", Name = "Flame", Mult = 2, Price = 15000, Img = "rbxassetid://131088547064793" },
	{ Id = "Lightning", Name = "Lightning", Mult = 3, Price = 400000, Img = "rbxassetid://75945124058128" },
	{ Id = "Plasma", Name = "Plasma", Mult = 5, Price = 10000000, Img = "rbxassetid://114471121541998" },
	{ Id = "Galaxy", Name = "Galaxy", Mult = 8, Price = 250000000, Img = "rbxassetid://81850914175452" },
	{ Id = "Royal", Name = "Royal", Mult = 11, Price = 3000000000, Img = "rbxassetid://85620811638560" },
}
local TRAILS = {
	{ Id = "Dust", Name = "Dust", Mult = 1.1, Price = 300, Img = "rbxassetid://85694011941199" },
	{ Id = "Wind", Name = "Wind", Mult = 1.25, Price = 10000, Img = "rbxassetid://105024342048733" },
	{ Id = "Turbo", Name = "Turbo", Mult = 1.4, Price = 300000, Img = "rbxassetid://123304181369029" },
	{ Id = "Comet", Name = "Comet", Mult = 1.6, Price = 8000000, Img = "rbxassetid://127285158778689" },
	{ Id = "Hyperspace", Name = "Hyperspace", Mult = 1.8, Price = 200000000, Img = "rbxassetid://122381863731356" },
}

local function short(v)
	for _, u in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if v >= u[1] then
			local s = string.format("%.1f", v / u[1]):gsub("%.0$", "")
			return s .. u[2]
		end
	end
	return tostring(v)
end
local function mult(m) return (string.format("%.2f", m):gsub("0+$", ""):gsub("%.$", "")) end

local conns, tweens = {}, {}
local function keep(c) table.insert(conns, c) return c end
local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props or {} do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(p, r) return make("UICorner", p, { CornerRadius = UDim.new(r or 0.08, 0) }) end
local function stroke(p, t, c) return make("UIStroke", p, { Thickness = t, Color = c or hex("1b1b1b"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function grad(p, top, bottom, rot)
	return make("UIGradient", p, { Color = ColorSequence.new(top, bottom), Rotation = rot or 90 })
end
local function text(p, name, str, color, props)
	local t = make("TextLabel", p, { Name = name, Text = str, FontFace = FONT, TextColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = 1, TextScaled = true, TextWrapped = true, ZIndex = 5 })
	make("UIStroke", t, { Thickness = 0.09, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Color = hex("101010"), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round })
	for k, v in props or {} do t[k] = v end
	return t
end
local function studs(p, tile, transp)
	return make("ImageLabel", p, { Name = "Studs", Image = STUDS, ScaleType = Enum.ScaleType.Tile, TileSize = tile, ImageTransparency = transp or 0.86, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
end
local function play(obj, t, props, style, dir)
	local tw = TS:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Bouton : survol, appui, relâché (valeurs de la vidéo), puis onClick.
local function wireButton(b, onClick)
	local sc = make("UIScale", b, { Name = "HoverScale" })
	local shade = b:FindFirstChild("Shade")
	local hovering = false
	keep(b.MouseEnter:Connect(function()
		hovering = true
		play(sc, V.HoverTime, { Scale = V.HoverTo })
		if shade then play(shade, V.HoverTime, { BackgroundTransparency = V.HoverShade }) end
	end))
	keep(b.MouseLeave:Connect(function()
		hovering = false
		play(sc, V.HoverBack, { Scale = 1 })
		if shade then play(shade, V.HoverBack, { BackgroundTransparency = 1 }) end
	end))
	keep(b.MouseButton1Down:Connect(function() play(sc, V.PressTime, { Scale = V.PressTo }) end))
	keep(b.MouseButton1Up:Connect(function() play(sc, V.ReleaseTime, { Scale = hovering and V.HoverTo or 1 }) end))
	keep(b.Activated:Connect(function() if onClick then onClick() end end))
end

local function button(parent, name, top, bottom, props)
	local b = make("TextButton", parent, { Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
	for k, v in props or {} do b[k] = v end
	grad(b, top, bottom)
	corner(b, 0.12)
	stroke(b, 2.5)
	make("Frame", b, { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 })
	corner(b.Shade, 0.12)
	return b
end

-- Écran ------------------------------------------------------------------------------------------
local old = CoreGui:FindFirstChild(NAME)
if old then old:Destroy() end
local gui = make("ScreenGui", CoreGui, { Name = NAME, IgnoreGuiInset = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50 })

local root = make("Frame", gui, { Name = "Root", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, V.Top), Size = UDim2.new(0.515, 217, 0.92, 0), BackgroundColor3 = hex("32322f") })
make("UIAspectRatioConstraint", root, { AspectRatio = V.Aspect })
corner(root, 0.012)
stroke(root, 3, hex("121212"))
studs(root, UDim2.fromScale(0.026, 0.044), 0.93)
local rootScale = make("UIScale", root, { Name = "OpenScale" })

-- bandeau titre (bleu en diagonale, comme la boutique de trails de la vidéo)
local bar = make("Frame", root, { Name = "Header", Position = UDim2.fromScale(0.0017, 0.0043), Size = UDim2.fromScale(0.9966, 0.164), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, ZIndex = 3 })
make("UIGradient", bar, { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex("7fe8fb")), ColorSequenceKeypoint.new(0.45, hex("3fbaf2")), ColorSequenceKeypoint.new(1, hex("1a8fd8")) }) })
for i, x in { 0.47, 0.53, 0.62 } do
	local s = make("Frame", bar, { Name = "Stripe" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(i == 2 and 0.012 or 0.028, 1.9), Rotation = 28, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 3 })
end
make("Frame", bar, { Name = "HeaderLine", Position = UDim2.fromScale(0, 0.975), Size = UDim2.fromScale(1, 0.025), BackgroundColor3 = hex("0f4f86"), BorderSizePixel = 0, ZIndex = 4 })
text(bar, "Title", "Aura Shop", nil, { Position = UDim2.fromScale(0.025, 0.12), Size = UDim2.fromScale(0.5, 0.76), TextXAlignment = Enum.TextXAlignment.Left })

-- onglets (noms du contrat : Tabs.AurasTab, Tabs.TrailsTab) dans le bandeau, avant le X
local tabs = make("Frame", root, { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromScale(0.6, 0.032), Size = UDim2.fromScale(0.29, 0.108), ZIndex = 4 })
local tabButtons = {}
for i, def in { { "AurasTab", "Auras" }, { "TrailsTab", "Trails" } } do
	local b = button(tabs, def[1], hex("ffffff"), hex("c9ccd3"), { Position = UDim2.fromScale(0.25 + (i - 1) * 0.5, 0.5), Size = UDim2.fromScale(0.47, 0.92) })
	text(b, "TabLabel", def[2], nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.7) })
	tabButtons[def[2]] = b
end

local close = button(root, "CloseButton", hex("ff5b6b"), hex("c81d2f"), { Position = UDim2.fromScale(0.947, 0.087), Size = UDim2.fromScale(0.082, 0.137) })
make("UIAspectRatioConstraint", close, { AspectRatio = 1 })
stroke(close, 3, hex("2a0b0f"))
text(close, "XLabel", "X", nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7) })

-- liste : 3 cartes visibles ; chaque case = carte + écart (388 × 525 px sur la vidéo)
local list = make("ScrollingFrame", root, { Name = "List", Position = UDim2.fromScale(0.0153, 0.194), Size = UDim2.fromScale(0.9686, 0.804), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0, ScrollingEnabled = false, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = 3 })
-- case : la hauteur fait 93,25 % de la liste, la largeur vient du rapport (pas de la longueur de la liste)
local grid = make("UIGridLayout", list, { FillDirection = Enum.FillDirection.Vertical, FillDirectionMaxCells = 1, CellSize = UDim2.new(0, 10000, 0.9325, 0), CellPadding = UDim2.new(), SortOrder = Enum.SortOrder.LayoutOrder })
make("UIAspectRatioConstraint", grid, { AspectRatio = 388 / 525 })
local track = make("Frame", root, { Name = "ScrollTrack", Position = UDim2.fromScale(0.0017, 0.979), Size = UDim2.fromScale(0.9966, 0.014), BackgroundTransparency = 1, ZIndex = 4 })
local thumb = make("Frame", track, { Name = "ScrollThumb", Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = hex("d4d4d4"), BorderSizePixel = 0, ZIndex = 4 })
corner(thumb, 0.5)

-- Carte (Template du contrat : Icon, ItemName, Bonus, Price, BuyButton, EquipButton)
local template = make("Frame", list, { Name = "Template", BackgroundTransparency = 1, Visible = false })
local card = make("Frame", template, { Name = "Card", Size = UDim2.fromScale(365 / 388, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, ZIndex = 3 })
corner(card, 0.025)
stroke(card, 2.5, hex("1e1e1e"))
local fill = make("Frame", card, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1 })
grad(fill, Color3.new(1, 1, 1), Color3.new(0.8, 0.8, 0.8))
studs(card, UDim2.fromScale(0.0822, 0.057), 0.88)
text(card, "ItemName", "Spark", nil, { Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.92, 0.12) })
text(card, "RarityLabel", "Common", hex("9aa0ab"), { Position = UDim2.fromScale(0.15, 0.165), Size = UDim2.fromScale(0.7, 0.075) })
make("ImageLabel", card, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.445), Size = UDim2.fromScale(0.84, 0.42), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 4 })
local band = make("Frame", card, { Name = "BonusBand", Position = UDim2.fromScale(0.041, 0.651), Size = UDim2.fromScale(0.918, 0.143), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 4 })
stroke(band, 2, hex("1e1e1e"))
text(band, "Bonus", "×1.5 Power", nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.74) })
local buy = button(card, "BuyButton", hex("ffffff"), hex("c4c8cf"), { Position = UDim2.fromScale(0.326, 0.8965), Size = UDim2.fromScale(0.576, 0.143) })
text(buy, "Price", "$500", nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.72) })
local rbx = button(card, "RobuxButton", hex("d84dff"), hex("a213dc"), { Position = UDim2.fromScale(0.8015, 0.8965), Size = UDim2.fromScale(0.315, 0.143) })
local rc = make("Frame", rbx, { Name = "Content", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.7), ZIndex = 5 })
make("UIListLayout", rc, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.04, 0) })
local ri = make("ImageLabel", rc, { Name = "RobuxIcon", Image = ROBUX, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.9), ZIndex = 5 })
make("UIAspectRatioConstraint", ri, { AspectRatio = 1 })
text(rc, "RobuxPrice", "—", nil, { Size = UDim2.fromScale(0.5, 1), LayoutOrder = 2 })
local equip = button(card, "EquipButton", hex("a6ff3d"), hex("5ec40f"), { Position = UDim2.fromScale(0.5, 0.8965), Size = UDim2.fromScale(0.918, 0.143), Visible = false })
text(equip, "EquipLabel", "Equip", nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.72) })

-- Fond d'une carte selon la rareté ----------------------------------------------------------------
local animated = {} -- { kind, obj, phase }
local function setRarity(c, rarity)
	local r = RAR[rarity]
	local f = c.Fill
	for _, k in f:GetChildren() do k:Destroy() end
	f.Size, f.Position = UDim2.fromScale(1, 1), UDim2.new()
	c.RarityLabel.Text = rarity
	c.RarityLabel.TextColor3 = r.Text
	local rg = c.RarityLabel:FindFirstChildOfClass("UIGradient")
	if rg then rg:Destroy() end
	if r.Anim == "Rainbow" then
		-- arc-en-ciel vertical qui glisse vers la gauche : 0,36 largeur de carte par seconde (Mythic de la vidéo)
		f.Size = UDim2.fromScale(2, 1)
		local kp, n = {}, #RAINBOW
		for i = 0, 2 * n do
			local col = RAINBOW[i % n + 1]:Lerp(Color3.new(1, 1, 1), 0.35)
			table.insert(kp, ColorSequenceKeypoint.new(i / (2 * n), col))
		end
		make("UIGradient", f, { Color = ColorSequence.new(kp), Rotation = 0 })
		local tg = {}
		for i, col in RAINBOW do table.insert(tg, ColorSequenceKeypoint.new((i - 1) / (n - 1), col)) end
		make("UIGradient", c.RarityLabel, { Color = ColorSequence.new(tg) })
		table.insert(animated, { kind = "Rainbow", obj = f, phase = math.random() })
	else
		grad(f, r.Top, r.Bottom)
		if r.Anim == "Sheen" then
			-- bande claire qui descend : 0,85 hauteur de carte par seconde, une toutes les 2,1 s (Eternal de la vidéo)
			local s = make("Frame", f, { Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1 })
			local g = make("UIGradient", s, { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.36, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.64, 1), NumberSequenceKeypoint.new(1, 1) }) })
			table.insert(animated, { kind = "Sheen", obj = g, phase = math.random() })
		elseif r.Anim == "Sweep" then
			-- reflet doré qui passe de côté, un toutes les 3 s (Divine de la vidéo)
			local s = make("Frame", f, { Name = "Sweep", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1 })
			local g = make("UIGradient", s, { Rotation = 18, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 1) }) })
			table.insert(animated, { kind = "Sweep", obj = g, phase = math.random() })
		end
	end
end

-- Contenu ------------------------------------------------------------------------------------------
local owned = { Spark = true, Dust = true }
local equipped = { Aura = "Spark", Trail = "Dust" }
local tab = "Auras"
local cards = {}
local target, pos = 0, 0
local forced = nil

local function refresh()
	for _, e in cards do
		local isOwned = owned[e.def.Id]
		e.card.BuyButton.Visible = not isOwned
		e.card.RobuxButton.Visible = not isOwned
		e.card.EquipButton.Visible = isOwned == true
		local kind = tab == "Auras" and "Aura" or "Trail"
		e.card.EquipButton.EquipLabel.Text = (isOwned and equipped[kind] == e.def.Id) and "Unequip" or "Equip"
	end
end

local function build()
	for _, e in cards do e.frame:Destroy() end
	table.clear(cards)
	table.clear(animated)
	local defs = tab == "Auras" and AURAS or TRAILS
	for i, def in defs do
		local fr = template:Clone()
		fr.Name = "Row_" .. def.Id
		fr.LayoutOrder = i
		fr.Visible = true
		local c = fr.Card
		c.ItemName.Text = def.Name
		c.BonusBand.Bonus.Text = "×" .. mult(def.Mult) .. (tab == "Auras" and " Power" or " Speed")
		c.BuyButton.Price.Text = "$" .. short(def.Price)
		c.Icon.Image = def.Img
		setRarity(c, forced or ORDER_RARITY[i])
		local kind = tab == "Auras" and "Aura" or "Trail"
		wireButton(c.BuyButton, function() owned[def.Id] = true; refresh() end)
		wireButton(c.RobuxButton, nil)
		wireButton(c.EquipButton, function()
			equipped[kind] = (equipped[kind] == def.Id) and nil or def.Id
			refresh()
		end)
		fr.Parent = list
		table.insert(cards, { frame = fr, card = c, def = def })
	end
	refresh()
	target, pos = 0, 0
	list.CanvasPosition = Vector2.zero
end

local function setTab(name)
	tab = name
	for n, b in tabButtons do
		local sel = n == name
		local g = b:FindFirstChildOfClass("UIGradient")
		g.Color = sel and ColorSequence.new(hex("fff36b"), hex("ffb71a")) or ColorSequence.new(hex("ffffff"), hex("c9ccd3"))
	end
	bar.Title.Text = name == "Auras" and "Aura Shop" or "Trail Shop"
	build()
end
for n, b in tabButtons do wireButton(b, function() if tab ~= n then setTab(n) end end) end

-- Ouverture et fermeture --------------------------------------------------------------------------
local state = "open"
local function openAnim()
	state = "open"
	root.Visible = true
	local h = root.AbsoluteSize.Y / math.max(0.01, rootScale.Scale)
	rootScale.Scale = V.OpenFrom
	root.Position = UDim2.new(0.5, 0, 0, V.Top + V.OpenPivot * h * (1 - V.OpenFrom))
	play(rootScale, V.OpenTime, { Scale = 1 })
	play(root, V.OpenTime, { Position = UDim2.new(0.5, 0, 0, V.Top) })
end
local function closeAnim()
	if state ~= "open" then return end
	state = "closing"
	local h = root.AbsoluteSize.Y / math.max(0.01, rootScale.Scale)
	play(rootScale, V.CloseTime, { Scale = V.CloseTo }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	play(root, V.CloseTime, { Position = UDim2.new(0.5, 0, 0, V.Top + V.ClosePivot * h * (1 - V.CloseTo)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(V.CloseTime, function()
		if state ~= "closing" then return end
		root.Visible = false
		state = "closed"
		task.delay(1, function() if state == "closed" and gui.Parent then openAnim() end end)
	end)
end
wireButton(close, closeAnim)

-- Défilement : molette lissée et glisser à la souris ------------------------------------------------
local function maxScroll() return math.max(0, list.AbsoluteCanvasSize.X - list.AbsoluteWindowSize.X) end
local function pitch() return list.AbsoluteWindowSize.Y * 0.9325 * 388 / 525 end
keep(list.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		target = math.clamp(target - input.Position.Z * V.WheelStep * pitch(), 0, maxScroll())
	end
end))
local drag = nil
keep(list.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		drag = { x = input.Position.X, start = target, last = input.Position.X, t = os.clock(), v = 0 }
	end
end))
keep(UIS.InputChanged:Connect(function(input)
	if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local now = os.clock()
		local dt = math.max(1e-3, now - drag.t)
		drag.v = (input.Position.X - drag.last) / dt
		drag.last, drag.t = input.Position.X, now
		target = math.clamp(drag.start - (input.Position.X - drag.x), 0, maxScroll())
	end
end))
keep(UIS.InputEnded:Connect(function(input)
	if drag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		target = math.clamp(target - drag.v * 0.12, 0, maxScroll()) -- élan au lâcher
		drag = nil
	end
end))

local clock = 0
keep(RunService.Heartbeat:Connect(function(dt)
	clock += dt
	-- rattrapage de la cible : l'écart est divisé par 2 toutes les V.Half s (mesuré : 33 ms)
	pos += (target - pos) * (1 - 0.5 ^ (dt / V.Half))
	if math.abs(target - pos) < 0.5 then pos = target end
	list.CanvasPosition = Vector2.new(pos, 0)
	local m = maxScroll()
	local win, can = list.AbsoluteWindowSize.X, math.max(1, list.AbsoluteCanvasSize.X)
	thumb.Size = UDim2.fromScale(math.clamp(win / can, 0.05, 1), 1)
	thumb.Position = UDim2.fromScale(m > 0 and (pos / m) * (1 - thumb.Size.X.Scale) or 0, 0)
	for _, a in animated do
		if a.obj.Parent == nil then continue end
		if a.kind == "Rainbow" then
			local p = ((clock * 0.36 + a.phase) % 1)
			a.obj.Position = UDim2.fromScale(-p, 0)
		elseif a.kind == "Sheen" then
			local p = ((clock / 2.1 + a.phase) % 1)
			a.obj.Offset = Vector2.new(0, -0.9 + 1.8 * p)
		elseif a.kind == "Sweep" then
			local p = ((clock / 3 + a.phase) % 1)
			a.obj.Offset = Vector2.new(-1.1 + 2.2 * p, 0)
		end
	end
end))

setTab("Auras")
task.defer(openAnim)

_G.ShopProto = {
	Replay = function() state = "closed"; openAnim() end,
	Close = closeAnim,
	Rarity = function(r) forced = r; build() end,
	Stop = function()
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		if gui.Parent then gui:Destroy() end
		_G.ShopProto = nil
	end,
}
return "Prototype de la boutique d'auras ouvert (CoreGui." .. NAME .. ")"
