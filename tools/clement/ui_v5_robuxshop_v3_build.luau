--!strict
-- L-203 (2026-11-16) : UI_RobuxShop_v2 passe en v3, d'après Figma « Steal a Shop — UI », page 10 Boutiques,
-- section UI_RobuxShop (cadre « Contenu complet de List », 1130 × 1971 px sur PC).
-- Garde l'écran UI_RobuxShop_v2 (fenêtre, en-tête, onglets, CloseButton) et refait List.Content :
--   Crate · Featured · GamepassesSection (2 colonnes) · BoostsSection (3) · CashSection (3), plus Decor.Hang1 à 4.
-- Règles (L-203, point 1) : coins droits partout sauf les boutons pour payer (UICorner 0,12) ; boutons en
-- UIGradient vertical 3 tons (haut +22 %, couleur à 45 %, bas −12 %), reflet doux (blanc 38 % → 0 sur la moitié
-- haute), UIStroke de la couleur foncée de 25 % à 65 % d'opacité, aucune ombre ; studs « Overlay » à 0,45
-- (Roblox n'a pas de mode Overlay : texture des studs teintée de la couleur du fond, à 45 % d'opacité).
-- Attributs d'animation (L-203, point 4) : Root Appear=Pop, Title Appear=Stamp, grilles et Odds Appear=Cascade,
-- boutons Hover=Pop + Press=Squash, cartes Hover=Pop, Decor.HangN Appear=DropIn. CardColor (Color3) par carte.
-- Relançable : l'ancien écran part dans ServerStorage/MapBackups/2026-11-16_L203.
-- Icônes des objets exclusifs : leurs ID du groupe (EXCLUSIVE_IDS), sans Decal ICON_* (voir plus bas).
-- Retours de Clément du 2026-11-16 : contour noir sur les boutons pour payer, rayons aux bords fondus, studs à 25 %.

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local INK = Color3.fromHex("15151d")
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local XBOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local STUDS = "rbxassetid://3014551673"
local RAYS = "rbxassetid://110553518823718" -- UI_Tex_Rays (carte de L-196)
local GLOW = "rbxassetid://130850617844067" -- UI_Tex_Glow
local STAR = "rbxassetid://98471192881940" -- étoile des cartes de boutique (ShopCardBg/IconDecor)
local ROBUX = "rbxassetid://139320447847280" -- UI_Icon_Robux
local W = 1130 -- largeur de List.Content dans Figma (PC)

local icons = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Icons")
local function tex(name: string, fallback: string?): string
	for _, n in { name, fallback } do
		local d = icons:FindFirstChild(n :: string)
		if d and d:IsA("Decal") and d.Texture ~= "" then
			return d.Texture
		end
	end
	return ""
end

local function lighten(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end
local function darken(c: Color3, k: number): Color3
	return c:Lerp(BLACK, k)
end

-- Sauvegarde puis copie de travail -------------------------------------------------------------------------
local backups = ServerStorage:FindFirstChild("MapBackups") or Instance.new("Folder")
backups.Name = "MapBackups"
backups.Parent = ServerStorage
local folder = backups:FindFirstChild("2026-11-16_L203") or Instance.new("Folder")
folder.Name = "2026-11-16_L203"
folder.Parent = backups

local current = StarterGui:WaitForChild("UI_RobuxShop_v2") :: ScreenGui
local saved = current:Clone()
saved.Name = "UI_RobuxShop_v2_avantV3_" .. os.time()
saved.Parent = folder

local gui = current:Clone()
gui:SetAttribute("Version", 3)
local root = gui:WaitForChild("Root") :: Frame
local window = root:WaitForChild("Window") :: Frame
local list = window:WaitForChild("List") :: ScrollingFrame
local oldContent = list:FindFirstChild("Content")
if oldContent then
	oldContent:Destroy()
end
local oldDecor = gui:FindFirstChild("Decor")
if oldDecor then
	oldDecor:Destroy()
end

-- Briques ---------------------------------------------------------------------------------------------------
type Box = { w: number, h: number }

local function place(o: GuiObject, p: Box, x: number, y: number, w: number, h: number)
	o.Position = UDim2.fromScale(x / p.w, y / p.h)
	o.Size = UDim2.fromScale(w / p.w, h / p.h)
end

local function frame(parent: Instance, name: string, p: Box, x: number, y: number, w: number, h: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	place(f, p, x, y, w, h)
	f.Parent = parent
	return f
end

local function image(parent: Instance, name: string, img: string, p: Box, x: number, y: number, w: number, h: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.BorderSizePixel = 0
	i.Image = img
	i.ScaleType = Enum.ScaleType.Fit
	place(i, p, x, y, w, h)
	i.Parent = parent
	return i
end

-- Texte : TextScaled + TextWrapped (sinon TextScaled ne marche pas posé par script), contour INK.
local function text(parent: Instance, name: string, str: string, p: Box, x: number, y: number, w: number, h: number, color: Color3, font: Font?, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Text = str
	l.FontFace = font or HEAVY
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	place(l, p, x, y, w, h)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.11
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = l
	l.Parent = parent
	return l
end

local function border(o: GuiObject, color: Color3, px: number, minSide: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = px / minSide
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Parent = o
end

-- Rayons aux bords fondus (retour de Clément du 2026-11-16) : un dégradé de transparence sur un seul axe ; les
-- autres bords de l'image passent sous le bord de leur cadre (ClipsDescendants). Pas de CanvasGroup : il échappe
-- au découpage de la liste. Le code qui fait tourner Crate.Backdrop.Rays tourne Fade.Rotation à l'inverse (L-204).
local function fade(o: Instance, rotation: number, from: number, to: number)
	local g = Instance.new("UIGradient")
	g.Name = "Fade"
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(from, 0),
		NumberSequenceKeypoint.new(to, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = o
end

local function gradient(o: Instance, keys: { { number } | any }, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 90
	local cs = {}
	for _, k in keys do
		table.insert(cs, ColorSequenceKeypoint.new(k[1], k[2]))
	end
	g.Color = ColorSequence.new(cs)
	g.Parent = o
	return g
end

-- 3 tons d'un bouton (L-203) et d'une carte (Figma : haut +30 %, couleur à 50 %, bas −17 %).
local function buttonTones(o: GuiObject, base: Color3)
	o.BackgroundColor3 = WHITE
	o.BackgroundTransparency = 0
	gradient(o, { { 0, lighten(base, 0.22) }, { 0.45, base }, { 1, darken(base, 0.12) } })
end
-- Contour en dégradé, dessiné à l'intérieur : chaque ton du bouton foncé de 25 %, à 65 % d'opacité (Figma).
local function gradientBorder(o: GuiObject, base: Color3, px: number, minSide: number)
	border(o, WHITE, px, minSide, 0.35)
	local s = o:FindFirstChildOfClass("UIStroke")
	if s then
		s.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		local g = gradient(s, { { 0, darken(lighten(base, 0.22), 0.25) }, { 0.45, darken(base, 0.25) }, { 1, darken(darken(base, 0.12), 0.25) } })
		g.Name = "StrokeGradient"
	end
end

local function cardTones(o: GuiObject, base: Color3)
	o.BackgroundColor3 = WHITE
	o.BackgroundTransparency = 0
	gradient(o, { { 0, lighten(base, 0.30) }, { 0.5, base }, { 1, darken(base, 0.17) } })
end

local function corner(o: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = o
end

-- Studs « Overlay » à 0,45 : texture teintée de la couleur du fond, tuile d'environ 28 px sur PC.
local function studs(parent: GuiObject, base: Color3, p: Box, round: number?)
	local s = image(parent, "Studs", STUDS, p, 0, 0, p.w, p.h)
	s.ScaleType = Enum.ScaleType.Tile
	-- tuile de 45 px Figma (retour de Clément du 2026-11-16 : studs plus grands sur les éléments en fond)
	s.TileSize = UDim2.fromScale(45 / p.w, 45 / p.h)
	s.ImageColor3 = base
	s.ImageTransparency = 0.75 -- à 0,55 les studs ressortaient bien plus que l'Overlay de Figma
	if round then
		corner(s, round)
	end
	return s
end

-- Reflet doux : blanc 38 % → 0 sur la moitié haute, sans bord net.
local function gloss(parent: GuiObject, p: Box, round: number?)
	local g = frame(parent, "Gloss", p, 0, 0, p.w, p.h / 2)
	g.BackgroundTransparency = 0
	local gr = Instance.new("UIGradient")
	gr.Rotation = 90
	gr.Transparency = NumberSequence.new(0.62, 1)
	gr.Parent = g
	if round then
		-- le reflet fait la moitié de la hauteur : rayon doublé pour garder les mêmes coins que le bouton (sinon ses
		-- coins dépassent du contour en gris, retour de Clément du 2026-11-16)
		corner(g, round * 2)
	end
	return g
end

-- Bouton (pay = bouton pour payer : arrondi 0,12). Shade = calque d'appui lu par le module Motion d'Ironix.
local function button(parent: Instance, name: string, p: Box, x: number, y: number, w: number, h: number, base: Color3, pay: boolean, strokePx: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	place(b, p, x, y, w, h)
	buttonTones(b, base)
	-- retour de Clément du 2026-11-16 : contour noir sur les boutons pour payer, en dégradé sur les autres
	if not pay then
		gradientBorder(b, base, strokePx, h)
	end
	local r = if pay then 0.12 else nil
	if r then
		corner(b, r)
	end
	local bp = { w = w, h = h }
	if not pay then
		studs(b, base, bp, r) -- pas de studs sur les boutons Robux (retour de Clément du 2026-11-16)
	end
	gloss(b, bp, r)
	local shade = frame(b, "Shade", bp, 0, 0, w, h)
	shade.BackgroundColor3 = BLACK
	shade.BackgroundTransparency = 1
	if r then
		corner(shade, r)
	end
	if pay then
		-- contour noir plein sur un cadre Outline, au-dessus du reflet (qui l'éclaircissait), coins ronds
		local o = frame(b, "Outline", bp, 0, 0, w, h)
		corner(o, 0.12)
		border(o, BLACK, strokePx, h)
	end
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(0, 44)
	min.Parent = b
	b:SetAttribute("Hover", "Pop")
	b:SetAttribute("Press", "Squash")
	b.Parent = parent
	return b
end

-- Prix Robux dans un bouton : Content (RobuxIcon, Price), centré, à la hauteur y..y+ch du bouton.
local function priceContent(b: TextButton, bw: number, bh: number, y: number, ch: number, iconPx: number, priceW: number, price: string)
	local bp = { w = bw, h = bh }
	local content = frame(b, "Content", bp, 0, y, bw, ch)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(7 / bw, 0)
	list.Parent = content
	local cp = { w = bw, h = ch }
	-- logo Robux à la hauteur des chiffres (85 % de Content, retour de Clément du 2026-11-16) ; iconPx n'est plus lu
	local _ = iconPx
	local icon = image(content, "RobuxIcon", ROBUX, cp, 0, 0, 0.85 * ch, 0.85 * ch)
	icon.LayoutOrder = 1
	icon:SetAttribute("IconAsset", "UI_Icon_Robux")
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = icon
	local pr = text(content, "Price", price, cp, 0, 0, priceW, ch, WHITE, HEAVY, Enum.TextXAlignment.Left)
	pr.LayoutOrder = 2
end

-- Rapport largeur / hauteur fixe d'un bloc (sa hauteur suit sa largeur, PC comme téléphone).
local function ratio(o: GuiObject, w: number, h: number)
	local r = Instance.new("UIAspectRatioConstraint")
	r.AspectRatio = w / h
	r.Parent = o
end

-- List.Content ----------------------------------------------------------------------------------------------
local TOTAL_H = 1971
local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Size = UDim2.fromScale(1, 20)
ratio(content, W, TOTAL_H)
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(18 / TOTAL_H, 0)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = content
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()

local function block(name: string, h: number, order: number): (Frame, Box)
	local b = Instance.new("Frame")
	b.Name = name
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.Size = UDim2.fromScale(1, 1)
	b.LayoutOrder = order
	ratio(b, W, h)
	b.Parent = content
	return b, { w = W, h = h }
end

-- 1. Caisse exclusive (Crate, 1130 × 372) --------------------------------------------------------------------
local crate, cb = block("Crate", 372, 1)
crate.ClipsDescendants = true
local backdrop = image(crate, "Backdrop", tex("UI_Bg_CrateVault"), cb, 0, 0, W, 372)
backdrop.ScaleType = Enum.ScaleType.Crop
backdrop:SetAttribute("IconAsset", "UI_Bg_CrateVault")
border(backdrop, INK, 4, 372)
local veil = frame(backdrop, "Veil", cb, 0, 0, W, 372)
veil.BackgroundColor3 = Color3.fromHex("120b33")
veil.BackgroundTransparency = 0
local vg = Instance.new("UIGradient")
vg.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.35, 0.85),
	NumberSequenceKeypoint.new(1, 0.55),
})
vg.Parent = veil
local crateRays = image(backdrop, "Rays", RAYS, cb, -112, -107, 595, 595)
fade(crateRays, 0, 0.6, 0.95) -- le fondu commence après l'icône
crateRays.ScaleType = Enum.ScaleType.Stretch
crateRays.ImageTransparency = 0.3
crateRays.ImageColor3 = Color3.fromHex("d9b8ff")
local crateGlow = image(backdrop, "Glow", GLOW, cb, 35, 40, 300, 300)
crateGlow.ScaleType = Enum.ScaleType.Stretch
crateGlow.ImageColor3 = Color3.fromHex("c88bff")
crateGlow.ImageTransparency = 0.2
local crateShadow = image(backdrop, "Shadow", GLOW, cb, 65, 316, 240, 39)
crateShadow.ScaleType = Enum.ScaleType.Stretch
crateShadow.ImageColor3 = BLACK
crateShadow.ImageTransparency = 0.35
local crateIcon = image(crate, "Icon", tex("ICON_BOX_Secret"), cb, 35, 40, 300, 300)
crateIcon.Rotation = 5
crateIcon:SetAttribute("IconAsset", "ICON_BOX_Secret")
local badge = frame(crate, "NewBadge", cb, 18, 16, 96, 43)
badge.Rotation = -8
buttonTones(badge, Color3.fromHex("e8222d"))
border(badge, Color3.fromHex("7a0a10"), 3, 43, 0.35)
text(badge, "Label", "NEW!", { w = 96, h = 43 }, 10, 7, 76, 29, WHITE)
local crateTitle = text(crate, "ItemName", "EXCLUSIVE CRATE", cb, 380, 20, 706, 70, WHITE)
gradient(crateTitle, { { 0, Color3.fromHex("fff9d6") }, { 0.5, Color3.fromHex("ffd23f") }, { 1, Color3.fromHex("ff9f1c") } })
local crateTitleStroke = crateTitle:FindFirstChildOfClass("UIStroke")
if crateTitleStroke then
	crateTitleStroke.Thickness = 0.1
end

local odds = frame(crate, "Odds", cb, 360, 116, 746, 114)
odds:SetAttribute("Appear", "Cascade")
local ob = { w = 746, h = 114 }
-- Icônes des 6 objets exclusifs (brouillons), importées au nom du groupe le 2026-11-15 et approuvées. Pas de Decal
-- ICON_* dans Assets/Icons tant que ces objets ne sont pas dans Config/Items : le ContractChecker en ferait des lignes rouges.
local EXCLUSIVE_IDS: { [string]: string } = {
	ICON_Exclusive_DiscoBall = "rbxassetid://71566468210751",
	ICON_Exclusive_GoldenGramophone = "rbxassetid://135558671959988",
	ICON_Exclusive_GoldenRocket = "rbxassetid://127104033248639",
	ICON_Exclusive_CrystalSkull = "rbxassetid://115111094076323",
	ICON_Exclusive_NeonJukebox = "rbxassetid://120358290858752",
	ICON_Exclusive_GoldenPlanet = "rbxassetid://102640872323532",
}
local exclusives = {
	{ "ICON_Exclusive_DiscoBall", "ICON_BOX_Rare" },
	{ "ICON_Exclusive_GoldenGramophone", "ICON_BOX_Epic" },
	{ "ICON_Exclusive_GoldenRocket", "ICON_BOX_Legendary" },
	{ "ICON_Exclusive_CrystalSkull", "ICON_BOX_Mythic" },
	{ "ICON_Exclusive_NeonJukebox", "ICON_BOX_Secret" },
	{ "ICON_Exclusive_GoldenPlanet", "ICON_BOX_Divine" },
}
local oddColors: { { string } } = {
	{ "97d0ff", "1c63cf" },
	{ "d7aeff", "7426c9" },
	{ "ffe68a", "e08c00" },
	{ "ff9aae", "c9183e" },
	{ "ff6b6b", "ffc21a", "3be15a", "2f9bff", "a855f7" },
	{ "fffdf2", "ffe7a3", "f5c55a" },
}
-- Retour de Clément du 2026-11-16 : la case la plus commune est la plus petite, puis de plus en plus grandes
-- (bas aligné) : 94 à 134 px, 684 px + 5 écarts de 12 = 744 px dans les 746 de Odds.
local ODD_SIZES = { 94, 102, 110, 118, 126, 134 }
local nextX = 0
for i = 1, 6 do
	local sz = ODD_SIZES[i]
	local x, y = nextX, 114 - sz
	nextX += sz + 12
	if i >= 4 then
		local gs = 1.4 * sz
		local rg = image(odds, "RarityGlow", GLOW, ob, x + sz / 2 - gs / 2, y + sz / 2 - gs / 2, gs, gs)
		rg.ScaleType = Enum.ScaleType.Stretch
		rg.ImageColor3 = Color3.fromHex(oddColors[i][1])
		rg.ImageTransparency = 0.25
	end
	local cell = frame(odds, "Odd_" .. i, ob, x, y, sz, sz)
	cell.BackgroundTransparency = 0
	local keys = {}
	local cols = oddColors[i]
	for k, hex in cols do
		table.insert(keys, { (k - 1) / (#cols - 1), Color3.fromHex(hex) })
	end
	gradient(cell, keys, if #cols > 2 then 45 else 90)
	border(cell, INK, 3, 114)
	local cp = { w = 114, h = 114 }
	studs(cell, Color3.fromHex(cols[1]), cp)
	local ic = image(cell, "Icon", EXCLUSIVE_IDS[exclusives[i][1]] or tex(exclusives[i][1], exclusives[i][2]), cp, 0, -11, 114, 114)
	ic:SetAttribute("IconAsset", exclusives[i][1])
	text(cell, "Chance", "?%", cp, 50, 80, 58, 30, WHITE, HEAVY, Enum.TextXAlignment.Right)
	if i >= 4 then
		local k = sz / 114
		local s1 = image(odds, "Star", STAR, ob, x + sz * 0.8, y - 9 * k, 25 * k, 25 * k)
		s1.ScaleType = Enum.ScaleType.Stretch
		local s2 = image(odds, "Star", STAR, ob, x - 7 * k, y + 0.3 * sz, 18 * k, 18 * k)
		s2.ScaleType = Enum.ScaleType.Stretch
	end
end

local buyRow = frame(crate, "BuyRow", cb, 360, 262, 746, 84)
local rb = { w = 746, h = 84 }
for i, count in { "1 CRATE", "3 CRATES", "10 CRATES" } do
	local base = if i == 3 then Color3.fromHex("ffb21f") else Color3.fromHex("4fe03a")
	local b = button(buyRow, "BuyButton" .. i, rb, (i - 1) * 255, 0, 236, 84, base, true, 4)
	priceContent(b, 236, 84, 6, 44, 29, 60, "?")
	text(b, "Count", count, { w = 236, h = 84 }, 20, 52, 196, 22, WHITE, XBOLD)
end

-- 2. Offre vedette (Featured, Starter Pack, 1130 × 150) --------------------------------------------------------
local featured, fb = block("Featured", 150, 2)
featured.ClipsDescendants = true
local fBack = image(featured, "Backdrop", tex("UI_Bg_StarterPack"), fb, 0, 0, W, 150)
fBack.ScaleType = Enum.ScaleType.Crop
fBack:SetAttribute("IconAsset", "UI_Bg_StarterPack")
border(fBack, INK, 4, 150)
local fVeil = frame(fBack, "Veil", fb, 0, 0, W, 150)
fVeil.BackgroundColor3 = Color3.fromHex("0a0d33")
fVeil.BackgroundTransparency = 0
local fvg = Instance.new("UIGradient")
fvg.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.12),
	NumberSequenceKeypoint.new(0.5, 0.22),
	NumberSequenceKeypoint.new(0.72, 0.9),
	NumberSequenceKeypoint.new(1, 0.7),
})
fvg.Parent = fVeil
local fRays = image(fBack, "Rays", RAYS, fb, -78, -90, 330, 330)
fRays.ScaleType = Enum.ScaleType.Stretch
fRays.ImageTransparency = 0.55
fade(fRays, 0, 0.6, 0.95)
local fIcon = image(featured, "Icon", tex("UI_Icon_DP_StarterPack"), fb, 22, 10, 130, 130)
fIcon:SetAttribute("IconAsset", "UI_Icon_DP_StarterPack")
local fName = text(featured, "ItemName", "STARTER PACK", fb, 170, 14, 420, 52, WHITE, HEAVY, Enum.TextXAlignment.Left)
gradient(fName, { { 0, WHITE }, { 1, Color3.fromHex("fff1b8") } })
text(featured, "Subtitle", "Only during your first hour", fb, 170, 64, 330, 23, WHITE, XBOLD, Enum.TextXAlignment.Left)
local perks = frame(featured, "Perks", fb, 170, 96, 420, 40)
local pb = { w = 420, h = 40 }
local perkData = {
	{ "UI_Icon_GP_x2Cash", "×2 Cash 1h", 0, 156 },
	{ "ICON_TOOL_Hammer", "Hammer", 166, 139 },
	{ "UI_Icon_DP_Cash_1", "$50K", 315, 105 },
}
for i, pd in perkData do
	local perk = frame(perks, "Perk" .. i, pb, pd[3], 0, pd[4], 40)
	perk.BackgroundColor3 = BLACK
	perk.BackgroundTransparency = 0.58
	border(perk, WHITE, 2, 40, 0.82)
	local pp = { w = pd[4], h = 40 }
	local pi = image(perk, "Icon", tex(pd[1]), pp, 10, 6, 28, 28)
	pi:SetAttribute("IconAsset", pd[1])
	text(perk, "Label", pd[2], pp, 43, 9, pd[4] - 50, 22, WHITE, HEAVY, Enum.TextXAlignment.Left)
end
local timer = frame(featured, "Timer", fb, 845, 18, 240, 26)
local tp = { w = 240, h = 26 }
local tIcon = image(timer, "Icon", tex("UI_Icon_DP_OpenNow"), tp, 30, 2, 22, 22)
tIcon:SetAttribute("IconAsset", "UI_Icon_DP_OpenNow")
text(timer, "Label", "Ends in 42:10", tp, 56, 1, 160, 24, Color3.fromHex("fff6d0"), HEAVY, Enum.TextXAlignment.Left)
local fBuy = button(featured, "BuyButton", fb, 830, 56, 270, 74, Color3.fromHex("4fe03a"), true, 4)
priceContent(fBuy, 270, 74, 14, 46, 31, 60, "99")
-- centré en hauteur : avec le minimum de 44 px du téléphone, il reste dans le bandeau (62 px de haut)
fBuy.AnchorPoint = Vector2.new(0, 0.5)
fBuy.Position = UDim2.fromScale(830 / W, (56 + 37) / 150)

-- 3. Sections à cartes ------------------------------------------------------------------------------------
type Offer = { name: string, effect: string, icon: string, price: string, color: string, effectColor: string, owned: boolean? }

-- Carte large (Gamepasses, 555 × 206) ou haute (Boosts et Cash, 363 × 270), d'après Preview_GP1 et Preview_BO1.
local function card(parent: Instance, name: string, wide: boolean, o: Offer): Frame
	local cw, ch = if wide then 555 else 363, if wide then 206 else 270
	local cp = { w = cw, h = ch }
	local base = Color3.fromHex(o.color)
	local c = Instance.new("Frame")
	c.Name = name
	c.BorderSizePixel = 0
	c.Size = UDim2.fromScale(1, 1)
	cardTones(c, base)
	border(c, INK, 3, ch)
	c:SetAttribute("CardColor", base)
	c:SetAttribute("Hover", "Pop")
	studs(c, base, cp)
	local clip = frame(c, "Clip", cp, 0, 0, cw, ch)
	clip.ClipsDescendants = true
	local img = tex(o.icon)
	if wide then
		-- 380 px centrés sur l'icône (104, 103) : haut, bas et gauche sous le bord de la carte ; rayons des deux côtés
		-- de l'icône, puis fondu de x 150 à 275 (retour de Clément : avec le fondu au centre, on ne voyait que la gauche)
		local r = image(clip, "Rays", RAYS, cp, -86, -87, 380, 380)
		fade(r, 0, 0.62, 0.95)
		r.ScaleType = Enum.ScaleType.Stretch
		r.ImageTransparency = 0.75
		local wm = image(clip, "Watermark", img, cp, 401, 10, 216, 216)
		wm.Rotation = -12
		wm.ImageTransparency = 0.86
		local ic = image(c, "Icon", img, cp, 28, 27, 152, 152)
		ic:SetAttribute("IconAsset", o.icon)
		-- textes un peu plus hauts que dans Figma : sur téléphone, le bouton de 44 px ne les recouvre pas
		text(c, "ItemName", o.name, cp, 222, 10, 322, 48, WHITE)
		text(c, "Effect", o.effect, cp, 222, 60, 322, 20, Color3.fromHex(o.effectColor), XBOLD)
	else
		-- 380 px centrés sur (181,5 ; 60) : gauche, droite et haut sous le bord de la carte, le bas s'efface
		local r = image(clip, "Rays", RAYS, cp, -8.5, -130, 380, 380)
		fade(r, 90, 0.62, 0.95)
		r.ScaleType = Enum.ScaleType.Stretch
		r.ImageTransparency = 0.75
		local wm = image(clip, "Watermark", img, cp, 176, 13, 263, 263)
		wm.Rotation = -12
		wm.ImageTransparency = 0.86
		local ic = image(c, "Icon", img, cp, 133, 8, 97, 97)
		ic:SetAttribute("IconAsset", o.icon)
		text(c, "ItemName", o.name, cp, 14, 104, 335, 36, WHITE)
		text(c, "Effect", o.effect, cp, 14, 142, 335, 19, Color3.fromHex(o.effectColor), XBOLD)
	end
	local bx, by, bw, bh = 290, 136, 186, 58
	if not wide then
		bx, by, bw, bh = 22, 202, 319, 56
	end
	local buy = button(c, "BuyButton", cp, bx, by, bw, bh, Color3.fromHex("4fe03a"), true, 3)
	priceContent(buy, bw, bh, 11, 36, 24, if #o.price > 2 then 62 else 40, o.price)
	-- bas ancré : avec le minimum de 44 px du téléphone, le bouton grandit vers le haut et reste dans la carte
	buy.AnchorPoint = Vector2.new(0, 1)
	buy.Position = UDim2.fromScale(bx / cw, (by + bh) / ch)
	local owned = frame(c, "Owned", cp, bx, by, bw, bh)
	owned.AnchorPoint = Vector2.new(0, 1)
	owned.Position = buy.Position
	local grey = Color3.fromHex("8c93a3")
	buttonTones(owned, grey)
	gradientBorder(owned, grey, 3, bh)
	local op = { w = bw, h = bh }
	studs(owned, grey, op)
	gloss(owned, op)
	text(owned, "OwnedLabel", "OWNED", op, 10, 14, bw - 20, 30, WHITE)
	local ownedMin = Instance.new("UISizeConstraint")
	ownedMin.MinSize = Vector2.new(0, 44)
	ownedMin.Parent = owned
	owned.Visible = o.owned == true
	buy.Visible = o.owned ~= true
	local outline = frame(c, "HoverOutline", cp, 0, 0, cw, ch)
	outline.Visible = false
	local os = Instance.new("UIStroke")
	os.Color = WHITE
	os.Thickness = 3
	os.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	os.Parent = outline
	c.Parent = parent
	return c
end

local function section(name: string, title: string, order: number, wide: boolean, offers: { Offer })
	local cols = if wide then 2 else 3
	local cw, ch = if wide then 555 else 363, if wide then 206 else 270
	local rows = math.max(1, math.ceil(#offers / cols))
	local gridH = rows * ch + (rows - 1) * 20
	local h = 41 + 12 + gridH
	local s, sb = block(name, h, order)
	local header = frame(s, "Header", sb, 0, 0, W, 41)
	local hb = { w = W, h = 41 }
	-- 6 px du bord : collé à x = 0, le contour du texte était coupé par la liste (retour de Clément du 2026-11-16)
	local label = text(header, "Label", title, hb, 6, 0, 420, 41, WHITE, HEAVY, Enum.TextXAlignment.Left)
	-- la ligne part juste après le texte : largeur du titre estimée (Montserrat Black 34 px ≈ 0,74 em par lettre)
	local textW = math.min(420, #title * 34 * 0.74)
	label.Size = UDim2.fromScale(textW / W, 1)
	local line = frame(header, "Line", hb, textW + 22, 18.5, W - textW - 22, 4)
	line.BackgroundTransparency = 0.78
	line.BackgroundColor3 = WHITE
	local grid = frame(s, "Grid", sb, 0, 53, W, gridH)
	grid:SetAttribute("Appear", "Cascade")
	grid:SetAttribute("Columns", cols)
	grid:SetAttribute("CardAspect", cw / ch)
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromScale(cw / W, ch / gridH)
	g.CellPadding = UDim2.fromScale(20 / W, 20 / gridH)
	g.FillDirectionMaxCells = cols
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Left
	g.Parent = grid
	local t = card(grid, "Template", wide, offers[1])
	t.Visible = false
	for i, o in offers do
		local c = card(grid, "Preview_" .. i, wide, o)
		c.LayoutOrder = i
	end
end

-- Contenus d'aperçu : noms, effets et prix de Config/Monetization et de la maquette (« ? » = à fixer).
section("GamepassesSection", "GAMEPASSES", 3, true, {
	{ name = "×2 CASH", effect = "Doubles all your income", icon = "UI_Icon_GP_x2Cash", price = "449", color = "45d63a", effectColor = "fff27a" },
	{ name = "×2 TRAINING", effect = "×2 treadmill gains", icon = "UI_Icon_GP_x2Training", price = "299", color = "ff9a2e", effectColor = "fff3c2", owned = true },
	{ name = "AUTO COLLECT", effect = "Cash collects itself, anywhere", icon = "UI_Icon_GP_AutoCollect", price = "199", color = "ffc928", effectColor = "ffffff" },
	{ name = "FAST OPEN", effect = "Anti-theft 2× shorter", icon = "UI_Icon_GP_FastOpen", price = "299", color = "2fa8f0", effectColor = "bff4ff" },
	{ name = "+4 DISPLAYS", effect = "4 extra display stands", icon = "UI_Icon_GP_Displays", price = "349", color = "e05ad8", effectColor = "ffd6fa" },
	{ name = "VIP", effect = "+10% income, aura, chat tag", icon = "UI_Icon_GP_VIP", price = "249", color = "8a5cf0", effectColor = "ffe27a" },
})
section("BoostsSection", "BOOSTS", 4, false, {
	{ name = "×2 SPEED", effect = "×2 speed on the treadmill", icon = "UI_Icon_SpeedBoost", price = "?", color = "f2553a", effectColor = "ffe0b8" },
	{ name = "zZz", effect = "Guards & police sleep 60 s", icon = "UI_Icon_Sleep", price = "?", color = "5b4be0", effectColor = "cfe3ff" },
	{ name = "OPEN NOW", effect = "Unlock now", icon = "UI_Icon_DP_OpenNow", price = "19", color = "18b894", effectColor = "d6fff2" },
})
section("CashSection", "CASH", 5, false, {
	{ name = "10 MIN OF CASH", effect = "10 min of income", icon = "UI_Icon_DP_Cash_1", price = "49", color = "5bcb3a", effectColor = "fff27a" },
	{ name = "1 HOUR OF CASH", effect = "1 hour of income", icon = "UI_Icon_DP_Cash_3", price = "199", color = "22a85a", effectColor = "fff27a" },
	{ name = "5 HOURS OF CASH", effect = "5 hours of income", icon = "UI_Icon_DP_Cash_5", price = "799", color = "e8a618", effectColor = "ffffff" },
})

-- Hauteur totale réelle (les sections dépendent du nombre de cartes).
local total = 0
local blocks = 0
for _, ch in content:GetChildren() do
	local r = ch:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ch:IsA("Frame") and r then
		total += W / r.AspectRatio
		blocks += 1
	end
end
total += (blocks - 1) * 18 + 20
local contentRatio = content:FindFirstChildOfClass("UIAspectRatioConstraint")
if contentRatio then
	contentRatio.AspectRatio = W / total
end
layout.Padding = UDim.new(18 / total, 0)
content.Parent = list

-- Défilement (Figma : Window 1190, List x 24 w 1130, piste x 1166 w 10) : la barre de Roblox se pose sur la piste
-- ScrollTrack, à droite de Content, pour que la 3e colonne ne passe pas dessous.
local track = window:FindFirstChild("ScrollTrack")
list.Position = UDim2.new(24 / 1190, 0, list.Position.Y.Scale, 0)
list.Size = UDim2.new((1176 - 24) / 1190, 0, list.Size.Y.Scale, 0)
list.ScrollBarThickness = 10
list.VerticalScrollBarInset = Enum.ScrollBarInset.None
list.ScrollBarImageColor3 = Color3.fromHex("e8e8ee")
list.ScrollBarImageTransparency = 0.15
list.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
list.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
content.Size = UDim2.fromScale(1130 / 1152, 20)
if track and track:IsA("GuiObject") then
	track.AnchorPoint = Vector2.new(1, 0)
	track.Position = UDim2.new(1176 / 1190, 0, list.Position.Y.Scale, 0)
	track.Size = UDim2.new(0, 10, list.Size.Y.Scale, 0)
	track.BackgroundColor3 = WHITE
	track.BackgroundTransparency = 0.88
	local tc = track:FindFirstChildOfClass("UICorner")
	if tc then
		tc:Destroy()
	end
end

-- 4. Décor suspendu (Decor.Hang1 à Hang4, PC seulement ; Figma 1920 × 1080) ----------------------------------
local decor = Instance.new("Frame")
decor.Name = "Decor"
decor.BackgroundTransparency = 1
decor.Size = UDim2.fromScale(1, 1)
decor.ZIndex = 1
local sb = { w = 1920, h = 1080 }
local hangs = {
	{ 70, 130, 320, 198, "UI_Icon_DP_Cash_3" },
	{ 195, 92, 187, 103, "ICON_BOX_Secret" },
	{ 1690, 104, 234, 138, "STAR" },
	{ 1800, 96, 326, 238, "ICON_Exclusive_GoldenRocket" },
}
for i, hd in hangs do
	local x, w, h, stringH, icon = hd[1], hd[2], hd[3], hd[4], hd[5]
	local hang = frame(decor, "Hang" .. i, sb, x, 0, w, h)
	hang:SetAttribute("Appear", "DropIn")
	ratio(hang, w, h)
	local hp = { w = w, h = h }
	local str = frame(hang, "String", hp, w / 2 - 1.5, 0, 3, stringH)
	str.BackgroundTransparency = 0
	str.BackgroundColor3 = INK
	local knot = frame(hang, "Knot", hp, w / 2 - 5, stringH - 10, 10, 10)
	knot.BackgroundTransparency = 0
	knot.BackgroundColor3 = INK
	local img = if icon == "STAR" then STAR else (EXCLUSIVE_IDS[icon] or tex(icon, "UI_Icon_SpeedBoost"))
	local hi = image(hang, "Icon", img, hp, 0, stringH - 8, w, w)
	if icon == "STAR" then
		hi.ImageColor3 = Color3.fromHex("ffc21a")
	else
		hi:SetAttribute("IconAsset", icon)
	end
end
decor.Parent = gui

-- 5. Fenêtre : toute la place utile, au plus 1360 × 740 (la maquette PC). Avec le rapport fixe de la v2, la
--    fenêtre restait à 580 px de large sur un téléphone de 844 px (690 dans la maquette téléphone).
local rootRatio = root:FindFirstChildOfClass("UIAspectRatioConstraint")
if rootRatio then
	rootRatio:Destroy()
end
local rootSize = root:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
rootSize.MinSize = Vector2.zero
rootSize.MaxSize = Vector2.new(1360, 740)
rootSize.Parent = root
root.Size = UDim2.fromScale(0.9, 0.94) -- marge à droite pour les libellés des onglets (écrans 4:3)

-- Attributs d'animation de la fenêtre
root:SetAttribute("Appear", "Pop")
local title = window:FindFirstChild("Title", true)
if title then
	title:SetAttribute("Appear", "Stamp")
end
for _, b in gui:GetDescendants() do
	if b:IsA("GuiButton") then
		b:SetAttribute("Hover", "Pop")
		b:SetAttribute("Press", "Squash")
	end
end

-- Contours (retours de Clément du 2026-11-16) : dans List.Content, dessinés à l'intérieur (sinon le bord gauche
-- des cartes est coupé par la liste) ; coins ronds sur le contour des boutons arrondis.
for _, s in content:GetDescendants() do
	if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
		s.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		if s.Parent and s.Parent:FindFirstChildOfClass("UICorner") then
			s.LineJoinMode = Enum.LineJoinMode.Round
		end
	end
end

-- Contour au-dessus du contenu (retour de Clément du 2026-11-16 : les rayons restent dans le cadre, pas sur le
-- contour) : le UIStroke des cartes, de Crate.Backdrop et de Featured.Backdrop passe sur un cadre Outline, ajouté en
-- dernier, donc au-dessus de tout dans l'empilement ci-dessous.
local function outline(holder: GuiObject, strokeOwner: Instance)
	for _, s in strokeOwner:GetChildren() do
		if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			local f = Instance.new("Frame")
			f.Name = "Outline"
			f.BackgroundTransparency = 1
			f.BorderSizePixel = 0
			f.Size = UDim2.fromScale(1, 1)
			s.Parent = f
			f.Parent = holder
			return
		end
	end
end
for _, c in content:GetDescendants() do
	if c:IsA("Frame") and (c.Name == "Template" or string.find(c.Name, "^Preview_")) then
		outline(c, c)
	end
end
outline(crate, backdrop)
outline(featured, fBack)

-- 6. ZIndex : l'écran est en ZIndexBehavior Global ; dans List.Content et Decor, chaque objet passe au-dessus du
--    précédent dans l'ordre de l'arbre (parent sous ses enfants), à partir de 5 (au-dessus du fond de fenêtre).
local z = 5
local function stack(o: Instance)
	if o:IsA("GuiObject") then
		o.ZIndex = z
		z += 1
	end
	for _, c in o:GetChildren() do
		stack(c)
	end
end
stack(content)
z = 1
stack(decor)
for _, d in decor:GetDescendants() do
	if d:IsA("GuiObject") then
		d.ZIndex = 1
	end
end

-- 7. Remplacement ---------------------------------------------------------------------------------------------
gui.Name = "UI_RobuxShop_v2"
current:Destroy()
gui.Parent = StarterGui
print(string.format("[ui_v5_robuxshop_v3_build] UI_RobuxShop_v2 v3 construit (désactivé), Content 1130 × %d, %d objets", math.floor(total), #gui:GetDescendants()))
