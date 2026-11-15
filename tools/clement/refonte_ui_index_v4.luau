--!nonstrict
-- refonte_ui_index_v4.luau (2026-11-15) : l'index d'après la maquette Figma validée par Clément (page « 20 Index et Exposés »,
-- PC 105:507, téléphone 106:369, noms 106:11389 ; correction de L-188). L'écran garde son nom UI_Index_v3 (IndexController
-- le cherche sous ce nom) et tous les noms lus par le code ; seul le visuel change, en carré (sans coins arrondis).
--   - fenêtre à studs, en-tête bleu à reflets, cartouche jaune « Index » qui déborde en haut à gauche, X rouge en haut à
--     droite, panneau intérieur ; à gauche la liste des zones qui défile, en bas « 23 / 83 discovered », à droite la fiche
--     Detail (fond à la couleur de la rareté, posée par le code) et Rewards ; hors de la fenêtre à droite, Categories ;
--   - chaque Zone<N>Section : ZoneArt = la façade de la zone (UI_Index_Zone<N>, ScaleType Crop) sur toute la hauteur, avec
--     ZoneName et ZoneTheme (nouveau) en haut ; ZoneBar au-dessus des cartes (4 par rangée), RewardIcon (nouveau) au bout ;
--   - Categories : NormalButton, LimitedButton (nouveau, à la place de SecretsButton), MutationsButton.
-- Encore au contrat mais retirés de l'écran (L-188) : SecretsButton (dans Categories.Unused), MutationTabs et
-- MutationCaption (dans Root.Unused), cachés ; ZoneItem et UnlockedBar.ClaimAllButton cachés ; SecretsSection reste cachée dans la liste.
-- Attributs d'animation de L-182 : Window Appear = Pop ; Cards Appear = Cascade ; Template, CloseButton, ClaimButton et
-- boutons de Categories Hover = Pop, Press = Squash.
-- À lancer en Edit. Sauvegarde d'abord l'écran dans ServerStorage/MapBackups/2026-11-15_RefonteUI/UI_Index_v3. Annulable.
-- Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_Index_v3
assert(not gui:GetAttribute("RefonteV4"), "UI_Index_v3 est déjà en v4")
local root = gui.Root
local win = root.Window

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("1b1b24")
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://3014551673"
local STUD_PX = 28
-- Zones : façade (images de Clément), nom et thème affichés.
local ZONES = {
	{ "Zone1Section", "rbxassetid://79033284809537", "MINI MART", "KIOSK" },
	{ "Zone2Section", "rbxassetid://84755273159668", "LONDON", "TOYS" },
	{ "Zone3Section", "rbxassetid://99531283375310", "TOKYO", "ELECTRONICS" },
	{ "Zone4Section", "rbxassetid://92041859844119", "LOS ANGELES", "JEWELRY" },
	{ "Zone5Section", "rbxassetid://132462923559904", "PARIS", "GALLERY" },
	{ "Zone6Section", "rbxassetid://136578131946595", "NEW YORK", "BANK" },
}

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end
local function rect(o, x, y, w, h, W, H)
	o.AnchorPoint = Vector2.zero
	o.Position = UDim2.fromScale(x / W, y / H)
	o.Size = UDim2.fromScale(w / W, h / H)
end
local function grad(o, a, b, rot)
	local g = o:FindFirstChild("UIGradient") or new("UIGradient", {}, o)
	g.Color = ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b))
	g.Rotation = rot or 90
	g.Transparency = NumberSequence.new(0)
	return g
end
local function noGrad(o)
	for _, g in o:GetChildren() do
		if g:IsA("UIGradient") then
			g:Destroy()
		end
	end
end
local function border(o, scale, color, transparency)
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = scale
	s.Color = color or INK
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Miter
	return s
end
local function textStyle(o, strokeScale, color)
	o.FontFace = HEAVY
	o.TextScaled = true
	o.TextWrapped = true
	o.TextColor3 = color or WHITE
	o.BackgroundTransparency = 1
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = strokeScale
	s.Color = INK
	s.Transparency = 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	for _, g in o:GetChildren() do
		if g:IsA("UIGradient") then
			g:Destroy()
		end
	end
end
local function studs(o, transparency, W, H, z)
	local s = o:FindFirstChild("Studs")
	if not (s and s:IsA("ImageLabel")) then
		s = new("ImageLabel", { Name = "Studs", Image = STUDS, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Tile }, o)
	end
	s.Size = UDim2.fromScale(1, 1)
	s.Position = UDim2.fromScale(0, 0)
	s.ImageTransparency = transparency
	s.TileSize = UDim2.fromScale(STUD_PX / W, STUD_PX / H)
	s.ZIndex = z or o.ZIndex
	local c = s:FindFirstChildOfClass("UICorner")
	if c then
		c:Destroy()
	end
	return s
end
local function aspect(o, ar)
	local a = o:FindFirstChildOfClass("UIAspectRatioConstraint") or new("UIAspectRatioConstraint", {}, o)
	a.AspectRatio = ar
	a.AspectType = Enum.AspectType.FitWithinMaxSize
	a.DominantAxis = Enum.DominantAxis.Width
end
local function animated(o, appear)
	o:SetAttribute("Hover", "Pop")
	o:SetAttribute("Press", "Squash")
	if appear then
		o:SetAttribute("Appear", appear)
	end
end
-- Brique « bouton à studs » de 00 Briques, en carré : dégradé, studs, contour.
local function brick(o, top, bottom, strokePx, W, H)
	o.BackgroundColor3 = WHITE
	o.BackgroundTransparency = 0
	o.BorderSizePixel = 0
	grad(o, top, bottom, 90)
	studs(o, 0.55, W, H)
	border(o, strokePx / math.min(W, H))
end

local rec = CHS:TryBeginRecording("Refonte UI : index v4 d'après Figma")
local ok, err = pcall(function()
	local folder = SS.MapBackups["2026-11-15_RefonteUI"]
	if not folder:FindFirstChild("UI_Index_v3") then
		local old = gui:Clone()
		old.Enabled = false
		old:SetAttribute("AncienEmplacement", "StarterGui.UI_Index_v3")
		old.Parent = folder
	end

	-- En carré : plus aucun coin arrondi, sauf les pastilles « ! ».
	for _, c in gui:GetDescendants() do
		if c:IsA("UICorner") and not c.Parent.Name:match("Alert$") then
			c:Destroy()
		end
	end

	-- Ce qui est encore au contrat mais n'est plus à l'écran.
	local unused = new("Frame", { Name = "Unused", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	-- SecretsButton reste sous Categories (le contrat le cherche par « Categories.SecretsButton ») : cadre caché, hors de la liste.
	local hiddenCat = new("Frame", { Name = "Unused", Visible = false, BackgroundTransparency = 1, LayoutOrder = 99 }, root.Categories)
	root.Categories.SecretsButton.Parent = hiddenCat
	root.MutationTabs.Parent = unused
	root.MutationCaption.Parent = unused
	win.UnlockedBar.ClaimAllButton.Visible = false

	-- Bloc entier (fenêtre + catégories) : 1386 × 680 dans la maquette PC.
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.52)
	root.Size = UDim2.fromScale(0.722, 0.63)
	for _, c in root:GetChildren() do
		if c:IsA("UIAspectRatioConstraint") or c:IsA("UISizeConstraint") then
			c:Destroy()
		end
	end
	aspect(root, 1386 / 680)
	new("UISizeConstraint", { MinSize = Vector2.new(660, 324) }, root) -- téléphone : tient en 667 de large

	-- Fenêtre : ardoise à studs, contour, ombre dure (sœur de la fenêtre : en Sibling un enfant passe devant).
	rect(win, 0, 0, 1160, 680, 1386, 680)
	win.BackgroundColor3 = Color3.fromHex("3a404b")
	win.BackgroundTransparency = 0
	noGrad(win)
	studs(win, 0.8, 1160, 680, win.ZIndex)
	border(win, 4 / 680)
	win:SetAttribute("Appear", "Pop")
	local shadow = root:FindFirstChild("WindowShadow") or new("Frame", { Name = "WindowShadow" }, root)
	shadow.BackgroundColor3 = INK
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.new(0, 0, 8 / 680, 0)
	shadow.Size = win.Size
	shadow.ZIndex = win.ZIndex - 1

	-- En-tête bleu, reflets, filet noir.
	local header = win.Header
	rect(header, 0, 0, 1160, 100, 1160, 680)
	header.ClipsDescendants = false
	header.BackgroundColor3 = WHITE
	header.BackgroundTransparency = 0
	grad(header, "5cc8ff", "1e86e0", 90)
	studs(header, 0.55, 1160, 100, header.ZIndex)
	local reflets = new("Frame", { Name = "Reflets", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = header.ZIndex + 1 }, header)
	for _, n in { "Stripe1", "Stripe2", "Stripe3" } do
		header[n].Parent = reflets -- coupés au cadre : l'en-tête ne coupe plus (cartouche qui déborde)
	end
	for name, x in { Stripe1 = 0.69, Stripe2 = 0.75 } do
		local s = reflets[name]
		s.Position = UDim2.fromScale(x, 0.5)
		s.BackgroundColor3 = WHITE
		s.BackgroundTransparency = 0.72
		s.ZIndex = header.ZIndex + 1
	end
	reflets.Stripe3.Visible = false
	local edge = header.Edge
	edge.AnchorPoint = Vector2.new(0, 1)
	edge.Position = UDim2.fromScale(0, 1)
	edge.Size = UDim2.fromScale(1, 4 / 100)
	edge.BackgroundColor3 = INK
	edge.ZIndex = header.ZIndex + 1

	-- Cartouche « Index » qui déborde en haut à gauche.
	local box = new("Frame", { Name = "TitleBox", ZIndex = header.ZIndex + 2 }, header)
	rect(box, 36, -36, 259, 106, 1160, 100)
	brick(box, "ffd84a", "ff9e1a", 4, 259, 106)
	local boxShadow = new("Frame", { Name = "TitleShadow", BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = header.ZIndex + 1 }, header)
	rect(boxShadow, 36, -30, 259, 106, 1160, 100)
	local title = header.Title
	rect(title, 80, -17, 171, 68, 1160, 100)
	title.ZIndex = header.ZIndex + 4
	title.Text = "Index"
	title.TextXAlignment = Enum.TextXAlignment.Center
	textStyle(title, 5.5 / 68)
	new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromHex("e3e9f2")), Rotation = 90 }, title)

	-- X rouge carré qui déborde en haut à droite.
	local close = win.CloseButton
	rect(close, 1116, -20, 64, 64, 1160, 680)
	local closeAr = close:FindFirstChildOfClass("UIAspectRatioConstraint")
	if closeAr then
		closeAr:Destroy() -- carré par la fenêtre ; sans rapport fixe, le minimum de 44 × 44 tient
	end
	(close:FindFirstChildOfClass("UISizeConstraint") or new("UISizeConstraint", {}, close)).MinSize = Vector2.new(44, 44)
	close.ZIndex = header.ZIndex + 3
	brick(close, "fb303e", "d00709", 4, 64, 64)
	local studsClose = close:FindFirstChild("Studs")
	if studsClose then
		studsClose:Destroy()
	end
	textStyle(close.XLabel, 0.16)
	close.XLabel.ZIndex = close.ZIndex + 2
	animated(close)

	-- Panneau intérieur.
	local inner = win:FindFirstChild("Inner") or new("Frame", { Name = "Inner" }, win)
	rect(inner, 24, 126, 1112, 532, 1160, 680)
	inner.BackgroundColor3 = Color3.fromHex("2f343d")
	inner.BackgroundTransparency = 0.3
	inner.BorderSizePixel = 0
	inner.ZIndex = 1
	border(inner, 2 / 532, WHITE, 0.75)

	-- Liste des zones.
	local panel = win.ListPanel
	rect(panel, 40, 172, 760, 372, 1160, 680)
	panel.BackgroundColor3 = INK
	panel.BackgroundTransparency = 0.65
	border(panel, 3 / 372)
	local list = panel.List
	rect(list, 10, 10, 736, 352, 760, 372)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = WHITE
	list.ScrollBarImageTransparency = 0.45
	list.UIListLayout.Padding = UDim.new(0, 16)
	local listPad = list:FindFirstChildOfClass("UIPadding")
	if listPad then
		listPad.PaddingTop = UDim.new(0, 0)
	end

	-- Compteur global en bas.
	local ub = win.UnlockedBar
	rect(ub, 86, 568, 470, 58, 1160, 680)
	ub.BackgroundColor3 = INK
	ub.BackgroundTransparency = 0.4
	border(ub, 3 / 58)
	local counter = ub.Counter
	rect(counter, 108, 11, 340, 37, 470, 58)
	counter.TextXAlignment = Enum.TextXAlignment.Left
	counter.Text = "23 / 83 discovered"
	textStyle(counter, 4.2 / 37)
	local book = win.BookIcon
	rect(book, 40, 546, 96, 96, 1160, 680)
	book.Rotation = 0
	book.SizeConstraint = Enum.SizeConstraint.RelativeXY
	aspect(book, 1)
	book.ZIndex = ub.ZIndex + 2

	-- Fiche de l'objet cliqué : fond à la couleur de la rareté (le code), ombré.
	local det = win.Detail
	rect(det, 816, 172, 304, 270, 1160, 680)
	det.BackgroundColor3 = Color3.fromHex("ffc21a")
	grad(det, "ffffff", "cfcfcf", 90)
	studs(det, 0.75, 304, 270, det.ZIndex)
	border(det, 3 / 270)
	local iconFrame = det.IconFrame
	rect(iconFrame, 52, 12, 200, 130, 304, 270)
	iconFrame.BackgroundColor3 = INK
	iconFrame.BackgroundTransparency = 0.45
	border(iconFrame, 3 / 130)
	rect(iconFrame.DetailIcon, 30, -6, 140, 140, 200, 130)
	rect(det.DetailName, 30, 150, 244, 34, 304, 270)
	textStyle(det.DetailName, 3.9 / 34)
	rect(det.DetailRarity, 52, 190, 200, 26, 304, 270)
	textStyle(det.DetailRarity, 0.12, Color3.fromHex("ffc21a"))
	rect(det.DetailIncome, 40, 223, 224, 37, 304, 270)
	textStyle(det.DetailIncome, 4.2 / 37, Color3.fromHex("7cff4f"))

	-- Récompenses de la zone visible.
	local rw = win.Rewards
	rect(rw, 816, 454, 304, 194, 1160, 680)
	rw.BackgroundColor3 = INK
	rw.BackgroundTransparency = 0.65
	border(rw, 3 / 194)
	rect(rw.RewardsTitle, 14, 4, 160, 18, 304, 194)
	rw.RewardsTitle.Text = "REWARDS:"
	rw.RewardsTitle.TextXAlignment = Enum.TextXAlignment.Left
	textStyle(rw.RewardsTitle, 2.2 / 20)
	for name, x in { SpeedReward = 40, CashReward = 160 } do
		local tile = rw[name]
		rect(tile, x, 24, 104, 66, 304, 194) -- moins haut que la maquette : CLAIM! garde ses 44 px sur téléphone
		tile.BackgroundColor3 = WHITE
		tile.BackgroundTransparency = 0
		grad(tile, "4e5566", "2a2f3b", 90)
		border(tile, 3 / 86)
		rect(tile.Icon, 27, 3, 50, 42, 104, 66)
		tile.Icon.ScaleType = Enum.ScaleType.Fit
		rect(tile.Amount, 0, 44, 104, 20, 104, 66)
		tile.Amount.Text = if name == "SpeedReward" then "+?" else "$?"
		textStyle(tile.Amount, 2.8 / 24)
	end
	local claim = rw.ClaimButton
	rect(claim, 32, 128, 240, 58, 304, 194)
	claim.AnchorPoint = Vector2.new(0, 1) -- ancré en bas : ses 44 px minimum montent au lieu de déborder
	claim.Position = UDim2.fromScale(32 / 304, 186 / 194)
	brick(claim, "c9c6cb", "8f8b92", 3, 240, 58)
	local claimLabel = claim.ClaimLabel
	claimLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	claimLabel.Position = UDim2.fromScale(0.5, 0.5)
	claimLabel.Size = UDim2.fromScale(0.8, 0.56)
	claimLabel.Text = "CLAIM!"
	textStyle(claimLabel, 3.5 / 32, Color3.fromHex("f2f2f2"))
	-- Récompense prête : le code allume ReadyGradient (vert) et éteint UIGradient (gris), comme PoliceGradient du HUD.
	new("UIGradient", { Name = "ReadyGradient", Color = ColorSequence.new(Color3.fromHex("91f630"), Color3.fromHex("31dd22")), Rotation = 90, Enabled = false }, claim)
	local claimAlert = claim.ClaimAlert
	claimAlert.AnchorPoint = Vector2.new(0.5, 0.5)
	claimAlert.Position = UDim2.fromScale(1, 0.1)
	claimAlert.Size = UDim2.fromScale(36 / 240, 36 / 58)
	animated(claim)
	-- Récompense d'une zone complète = l'arme, l'aura ou la trail seule (décision de Clément, 2026-11-15) : les tuiles vitesse et
	-- argent (encore au contrat) passent dans Rewards.Unused, une tuile ItemReward (RewardIcon + RewardCaption) les remplace.
	local rewardsHidden = new("Frame", { Name = "Unused", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, rw)
	rw.SpeedReward.Parent = rewardsHidden
	rw.CashReward.Parent = rewardsHidden
	rw.RewardsTitle.Text = "REWARD:"
	local itemTile = new("Frame", { Name = "ItemReward", BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = rw.ZIndex + 1 }, rw)
	rect(itemTile, 32, 24, 240, 66, 304, 194)
	grad(itemTile, "4e5566", "2a2f3b", 90)
	border(itemTile, 3 / 66)
	local itemIcon = new("ImageLabel", { Name = "RewardIcon", BackgroundColor3 = INK, BackgroundTransparency = 0.4, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, Image = "", ZIndex = itemTile.ZIndex + 1 }, itemTile)
	rect(itemIcon, 5, 5, 56, 56, 240, 66)
	border(itemIcon, 3 / 56, Color3.fromHex("ffd43b"))
	local itemQ = new("TextLabel", { Name = "Unknown", Text = "?", ZIndex = itemIcon.ZIndex + 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.6) }, itemIcon)
	textStyle(itemQ, 0.14, Color3.fromHex("ffd43b"))
	local itemCaption = new("TextLabel", { Name = "RewardCaption", Text = "???", ZIndex = itemTile.ZIndex + 1, TextXAlignment = Enum.TextXAlignment.Left }, itemTile)
	rect(itemCaption, 70, 14, 162, 38, 240, 66)
	textStyle(itemCaption, 0.12)

	-- Catégories, hors de la fenêtre à droite.
	local cats = root.Categories
	rect(cats, 1176, 128, 210, 280, 1386, 680)
	cats.UIListLayout.Padding = UDim.new(14 / 280, 0)
	cats.UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local limited = cats.NormalButton:Clone()
	limited.Name = "LimitedButton"
	limited.Parent = cats
	limited:FindFirstChild("Selected").Visible = false -- « Selected » est aussi une propriété des boutons : FindFirstChild
	limited.Label.Text = "LIMITED"
	for _, c in limited:GetDescendants() do
		if c.Name == "CategoryAlert" then
			c.Name = "LimitedAlert" -- pas d'alerte au contrat pour LIMITED : décor éteint
			c.Visible = false
		end
	end
	local catStyle = {
		NormalButton = { 1, "5fdbff", "1c8be0" }, LimitedButton = { 2, "ffe066", "e8920f" }, MutationsButton = { 3, "c86bff", "ff4fa8" },
	}
	for name, st in catStyle do
		local b = cats[name]
		b.LayoutOrder = st[1]
		b.Size = UDim2.fromScale(1, 84 / 280)
		brick(b, st[2], st[3], 4, 210, 84)
		local gloss = b:FindFirstChild("Gloss") or new("Frame", { Name = "Gloss", BorderSizePixel = 0 }, b)
		rect(gloss, 8, 6, 194, 18, 210, 84)
		gloss.BackgroundColor3 = WHITE
		gloss.BackgroundTransparency = 0.7
		gloss.ZIndex = b.ZIndex + 1
		local l = b.Label
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.52)
		l.Size = UDim2.fromScale(0.88, 0.44)
		textStyle(l, 4.2 / 37)
		l.ZIndex = b.ZIndex + 2
		local sel = b:FindFirstChild("Selected")
		sel.AnchorPoint = Vector2.new(0.5, 0.5)
		sel.Position = UDim2.fromScale(0.5, 0.5)
		sel.Size = UDim2.fromScale(220 / 210, 94 / 84)
		sel.BackgroundTransparency = 1
		noGrad(sel)
		border(sel, 4 / 94, WHITE)
		sel.ZIndex = b.ZIndex + 3
		local star = b:FindFirstChild("StarIcon")
		if star then
			star.Visible = false
		end
		local alert = b:FindFirstChild("CategoryAlert") or b:FindFirstChild("LimitedAlert")
		if alert then
			alert.AnchorPoint = Vector2.new(0.5, 0.5)
			alert.Position = UDim2.fromScale(206 / 210, 4 / 84)
			alert.Size = UDim2.fromScale(36 / 210, 36 / 84)
			alert.ZIndex = b.ZIndex + 4
		end
		animated(b)
	end

	-- Carte (le code la clone) : fond à la couleur de la rareté, rayons, nom en haut, gros dessin.
	local tpl = list.Template
	local clip = tpl.Clip
	clip.BorderSizePixel = 0
	grad(clip, "ffffff", "c4c4c4", 90)
	border(clip, 3 / 128)
	clip.Rays.ImageTransparency = 0.82
	-- Case de la grille de 128 × 140 : la carte en haut (128), 12 d'écart dessous, proportionnels sur tous les écrans.
	clip.Position = UDim2.fromScale(0, 0)
	clip.Size = UDim2.fromScale(1, 128 / 140)
	rect(tpl.Icon, 13, 24, 102, 102, 128, 140)
	rect(tpl.ItemName, 9, 5, 110, 17, 128, 140)
	textStyle(tpl.ItemName, 2.1 / 17)
	local outline = tpl.HoverOutline
	outline.BackgroundTransparency = 1
	outline.Position = UDim2.fromScale(0, 0)
	outline.Size = UDim2.fromScale(1, 128 / 140)
	border(outline, 4 / 128, WHITE)
	animated(tpl)

	-- Sections des zones.
	for _, z in ZONES do
		local sec = list[z[1]]
		local layout = sec:FindFirstChildOfClass("UIListLayout")
		layout.Padding = UDim.new(16 / 724, 0)
		layout.ItemLineAlignment = Enum.ItemLineAlignment.Stretch
		local art = sec.ZoneArt
		for _, c in art:GetChildren() do
			if c:IsA("UIAspectRatioConstraint") or c:IsA("UIGradient") then
				c:Destroy()
			end
		end
		art.Size = UDim2.fromScale(0.235, 0)
		art.Image = z[2]
		art.ScaleType = Enum.ScaleType.Crop
		art.BackgroundColor3 = Color3.fromHex("171742")
		art.BorderSizePixel = 0
		border(art, 3 / 170)
		art.ZoneIcon.Visible = false
		local shade = new("Frame", {
			Name = "NameShade", BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 110 / 170),
			SizeConstraint = Enum.SizeConstraint.RelativeXX, ZIndex = art.ZIndex + 1,
		}, art)
		new("UIGradient", {
			Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		}, shade)
		local name = art.ZoneName
		name.Parent = shade
		rect(name, 8, 14, 154, 37, 170, 110)
		name.Text = z[3]
		textStyle(name, 4.2 / 37)
		name.ZIndex = shade.ZIndex + 1
		local theme = new("TextLabel", { Name = "ZoneTheme", Text = z[4], ZIndex = shade.ZIndex + 1 }, shade)
		rect(theme, 10, 52, 150, 21, 170, 110)
		textStyle(theme, 2.4 / 21, Color3.fromHex("ffd43b"))
		local zoneAlert = art:FindFirstChild("ZoneAlert")
		if zoneAlert then
			zoneAlert.ZIndex = shade.ZIndex + 2
		end

		local content = sec.Content
		-- Écarts en cadres vides à rapport fixe (pas en px) : la liste s'arrête sur 2 rangées entières, PC comme téléphone.
		content.UIListLayout.Padding = UDim.new(0, 0)
		for _, sp in { { "TopGap", 0, 538 / 16 }, { "Gap", 2, 538 / 14 } } do
			local g = new("Frame", { Name = sp[1], BackgroundTransparency = 1, LayoutOrder = sp[2], Size = UDim2.new(1, 0, 0, 10000) }, content)
			new("UIAspectRatioConstraint", { AspectRatio = sp[3] }, g)
		end
		local bar = content.ZoneBar
		bar.LayoutOrder = 1
		bar.Size = UDim2.new(0.93, 0, 0, 10000)
		aspect(bar, 500 / 54)
		bar.BackgroundColor3 = INK
		bar.BackgroundTransparency = 0.25
		border(bar, 3 / 54)
		local fill = bar.Fill
		grad(fill, "b6ff3b", "3bd12f", 90)
		studs(fill, 0.6, 431, 46, fill.ZIndex)
		textStyle(bar.ZoneCount, 4.5 / 39)
		bar.ZoneCount.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.ZoneCount.Position = UDim2.fromScale(0.46, 0.5)
		bar.ZoneCount.Size = UDim2.fromScale(0.4, 0.72)
		bar.ZoneItem.ImageTransparency = 1 -- remplacé par RewardIcon (L-188)
		local reward = new("ImageLabel", {
			Name = "RewardIcon", BackgroundColor3 = INK, BackgroundTransparency = 0.4, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
			Image = "", ZIndex = bar.ZIndex + 3,
		}, bar)
		rect(reward, 460, -16, 84, 84, 500, 54)
		new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, reward)
		border(reward, 3 / 84, Color3.fromHex("ffd43b"))
		local q = new("TextLabel", { Name = "Unknown", Text = "?", ZIndex = reward.ZIndex + 1 }, reward)
		q.AnchorPoint = Vector2.new(0.5, 0.5)
		q.Position = UDim2.fromScale(0.5, 0.5)
		q.Size = UDim2.fromScale(0.5, 0.6)
		textStyle(q, 0.14, Color3.fromHex("ffd43b"))

		local cards = content.Cards
		cards.LayoutOrder = 3
		cards:SetAttribute("Appear", "Cascade")
		local grid = cards.UIGridLayout
		grid.CellSize = UDim2.new(128 / 548, 0, 0, 10000)
		grid.CellPadding = UDim2.new(12 / 548, 0, 0, 0)
		grid:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio = 128 / 140
	end

	gui:SetAttribute("RefonteV4", true)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "index v4 construit"
