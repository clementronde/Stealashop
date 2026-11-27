--!nonstrict
-- ui_inventaire_refF.luau (Clément, 25/11 dans la nuit : « L'inventaire est dégueulasse », « on retire le fond en
-- stud, on revoit la taille des textes », « Retire les sunbursts pour les onglets de l'inventaire ») : à lancer en
-- Edit APRÈS ui_inventaire_refE.luau. Version grise, d'après ses 2 références :
--   StealAShop-Art/References/UI/Inventaire/ref_inventaire_items_2026-11-25.webp et ref_inventaire_plantes_2026-11-25.webp
--   - grand panneau sombre et translucide, droit, sans tenons ;
--   - bandeau bleu en dégradé en haut, icône de sac qui dépasse à gauche, grand titre « Inventory » ;
--   - à droite du bandeau : Equip Best (vert) et la croix ;
--   - sous le bandeau : les onglets en boutons rectangles (sans sunburst), puis la recherche à droite ;
--   - une ligne d'aide (« Click an item to place it ») et les compteurs ;
--   - une grille de cartes : bord de la couleur de la rareté, sunburst derrière l'objet, $/s en vert en haut,
--     nom en bas ; un clic sur la carte place l'objet (PlaceButton et UnequipButton couvrent la carte, transparents).
-- Règle de Clément (25/11) : aucun bouton inventé. Onglets et Equip Best = clones des rectangles validés de
-- UI_HUD.LeftRail (Shop vert, Index bleu, Upgrades rose), on ne change que Label, LabelShadow et Icon ; sur les
-- onglets, le Sunburst est caché (demande de Clément). Il n'y a pas de rectangle jaune validé : 4 onglets pour
-- 3 couleurs, TITLES reprend le bleu.
-- Noms lus par InventoryController : tous gardés.
-- Ajouts : Header.HeaderIcon, Window.HintLabel, et dans chaque Template RarityFrame.Body (le bord de rareté).
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Inventory_avant_refF.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local INK = Color3.fromHex("0D0D14")
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromHex("5CFF5C")
local GREY = Color3.fromHex("8C8C9C") -- bord de rareté par défaut (le code y met la couleur de la rareté)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local FONT_BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local function must(parent, name, recursive)
	local found = parent and parent:FindFirstChild(name, recursive)
	assert(found, `{name} introuvable`)
	return found
end

local hud = SG.UI_HUD
local rail = must(hud, "LeftRail", true)
local RECT = {
	green = must(rail, "RobuxShopButton"),
	blue = must(rail, "IndexButton"),
	pink = must(rail, "SkillTreeButton"),
}
local TABS = { -- ordre, couleur validée, texte
	{ "ItemsTab", "blue", "Items" },
	{ "ToolsTab", "pink", "Weapons" },
	{ "PotionsTab", "green", "Potions" },
	{ "TitlesTab", "blue", "Titles" },
}

local function child(parent, class, name)
	local c = parent:FindFirstChild(name)
	if c and not c:IsA(class) then
		c:Destroy()
		c = nil
	end
	if not c then
		c = Instance.new(class)
		c.Name = name
		c.Parent = parent
	end
	return c
end

local function place(o, ap, pos, size, z)
	o.AnchorPoint = ap
	o.Position = pos
	o.Size = size
	if z then
		o.ZIndex = z
	end
end

-- texte à la taille de sa boîte, plafonné (Clément : « on revoit la taille des textes »)
local function text(l, value, align, color, maxSize, stroke)
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = value
	l.TextColor3 = color or WHITE
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	local c = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize or 40
	c.MinTextSize = 8
	c.Parent = l
	local s = l:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = stroke or 0.12
	s.Color = INK
	s.Parent = l
end

local function square(o, ratio)
	local ar = o:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = ratio or 1
	ar.Parent = o
end

local function noAspect(o)
	local ar = o:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ar then
		ar:Destroy()
	end
end

-- Clone d'un rectangle validé : texte de Label et LabelShadow, image d'Icon ; les alertes du HUD sont retirées.
local function validated(src, name, label, icon, noSunburst)
	local b = src:Clone()
	b.Name = name
	for _, d in b:GetChildren() do
		if d.Name:match("Alert$") then
			d:Destroy()
		end
	end
	for _, n in { "Label", "LabelShadow" } do
		local l = b:FindFirstChild(n)
		if l then
			l.Text = label
			if #label > 4 then
				l.Size = UDim2.new(0.58, 0, l.Size.Y.Scale, 0)
				l.Position = UDim2.new(0.665, 0, l.Position.Y.Scale, 0)
				l.TextScaled = true
				l.TextWrapped = true -- Studio coupe TextScaled sans TextWrapped
			end
		end
	end
	local ic = b:FindFirstChild("Icon", true)
	if ic and icon then
		ic.Image = icon
	end
	if noSunburst then
		for _, d in b:GetDescendants() do
			if d.Name == "Sunburst" and d:IsA("GuiObject") then
				d.Visible = false
			end
		end
	end
	return b
end

-- zone d'appui transparente qui couvre la carte (« Click an item to place it »)
local function hitArea(card, name, textName)
	local old = card:FindFirstChild(name)
	local wasVisible = if old then old.Visible else true
	if old then
		old:Destroy()
	end
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Visible = wasVisible
	place(b, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 12)
	if textName then
		local l = Instance.new("TextLabel")
		l.Name = textName -- écrit par le code (potions : « USE ») ; caché, la carte entière est le bouton
		l.Visible = false
		l.Parent = b
	end
	b.Parent = card
	return b
end

-- carte : fond noir (bord extérieur), RarityFrame (bord de la couleur de la rareté), RarityFrame.Body (fond sombre),
-- Clip (sunburst Rays et Glow, teints par le code), Icon au centre
local function card(t)
	t.BackgroundColor3 = INK
	t.BackgroundTransparency = 0
	t.AutoButtonColor = false
	t.Text = ""
	place(t, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1))
	noAspect(t)
	for _, c in t:GetChildren() do
		if c:IsA("UICorner") or c:IsA("UIGradient") or c:IsA("UIStroke") then
			c:Destroy()
		end
	end
	local rf = child(t, "Frame", "RarityFrame")
	place(rf, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(1, -4, 1, -4), 1)
	rf.BackgroundColor3 = GREY
	rf.BorderSizePixel = 0
	local body = child(rf, "Frame", "Body")
	place(body, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(1, -6, 1, -6), 1)
	body.BackgroundColor3 = Color3.fromHex("1A1A26")
	body.BorderSizePixel = 0
	local shadow = t:FindFirstChild("CardShadow")
	if shadow then
		shadow.Visible = false
	end
	local clip = t:FindFirstChild("Clip")
	if clip then
		noAspect(clip)
		place(clip, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.47), UDim2.new(1, -10, 0.62, 0), 2)
		clip.ClipsDescendants = true
		clip.BackgroundTransparency = 1
	end
	local icon = t:FindFirstChild("Icon")
	if icon then
		place(icon, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.47), UDim2.fromScale(0.72, 0.56), 3)
		square(icon)
	end
	local outline = t:FindFirstChild("HoverOutline")
	if outline then
		place(outline, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 11)
	end
end

local function grid(section)
	local cards = section.Cards
	for _, c in cards:GetChildren() do
		if c:IsA("UIListLayout") or c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.08, 50, 0, 10000) -- la hauteur vient du rapport ; 8 cartes par ligne en 1920 × 1080
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 0.86 -- largeur / hauteur d'une carte (référence : 160 × 185)
	ar.Parent = g
	g.Parent = cards
	cards.AutomaticSize = Enum.AutomaticSize.Y
	cards.Size = UDim2.fromScale(1, 0)
	local title = section:FindFirstChild("TitleRow")
	if title then
		title.Visible = false
	end
	return cards:FindFirstChild("Template")
end

local function apply(gui)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = gui.Root
	-- grand panneau (référence : 90 % de l'écran), sans rapport fixe : sur téléphone il prend toute la largeur
	place(root, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.9))
	noAspect(root)
	local rsz = root:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	rsz.MinSize = Vector2.zero
	rsz.MaxSize = Vector2.new(1400, 960)
	rsz.Parent = root
	-- hauteurs en unités mixtes (échelle + px) : boutons de 44 px sur téléphone, sans géants sur PC
	-- bandeau (0,1 ; 16) · onglets (0,045 ; 30) · aide (0,03 ; 10) · grille jusqu'en bas

	-- panneau sombre et translucide, sans tenons
	local w = root.Window
	place(w, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 2)
	w.BackgroundColor3 = Color3.fromHex("121220")
	w.BackgroundTransparency = 0.22
	local ws = w:FindFirstChildOfClass("UIStroke")
	if ws then
		ws.Color = INK
		ws.Thickness = 3
	end
	local studs = w:FindFirstChild("Studs")
	if studs then
		studs.Visible = false
	end

	-- bandeau bleu en dégradé, icône de sac qui dépasse, grand titre
	local header = w.Header
	place(header, Vector2.zero, UDim2.new(), UDim2.new(1, 0, 0.1, 16), 6)
	header.BackgroundColor3 = WHITE
	header.BackgroundTransparency = 0
	header.BorderSizePixel = 0
	local hg = child(header, "UIGradient", "UIGradient")
	hg.Rotation = 90
	hg.Color = ColorSequence.new(Color3.fromHex("8FD6FF"), Color3.fromHex("2F8CF0"))
	local hs = child(header, "UIStroke", "UIStroke")
	hs.Color = INK
	hs.Thickness = 3
	hs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	for _, n in { "HeaderFill", "Studs", "Gloss" } do
		local o = header:FindFirstChild(n)
		if o then
			o.Visible = false
		end
	end
	local line = header:FindFirstChild("HeaderLine")
	if line then -- reflet clair en haut du bandeau
		line.Visible = true
		place(line, Vector2.zero, UDim2.fromScale(0, 0.06), UDim2.fromScale(1, 0.07), 1)
		line.BackgroundColor3 = WHITE
		line.BackgroundTransparency = 0.45
		line.BorderSizePixel = 0
	end
	local backpack = w.CounterPill:FindFirstChildWhichIsA("ImageLabel")
	local hicon = child(header, "ImageLabel", "HeaderIcon")
	place(hicon, Vector2.new(0, 0.5), UDim2.fromScale(-0.02, 0.5), UDim2.fromScale(0.2, 1.35), 8) -- dépasse sans sortir de l'écran
	hicon.BackgroundTransparency = 1
	hicon.ScaleType = Enum.ScaleType.Fit
	hicon.Image = if backpack then backpack.Image else ""
	square(hicon)
	local title = header.Title
	place(title, Vector2.new(0, 0.5), UDim2.fromScale(0.105, 0.5), UDim2.fromScale(0.4, 0.66), 7)
	text(title, "Inventory", Enum.TextXAlignment.Left, WHITE, 80, 0.1)
	-- à droite : Equip Best (vert validé) puis la croix
	local oldBest = w:FindFirstChild("EquipBestButton", true)
	local star = nil
	if oldBest then
		local ic = oldBest:FindFirstChild("Icon", true) or oldBest:FindFirstChild("StarIcon")
		star = ic and ic.Image
		oldBest:Destroy()
	end
	local best = validated(RECT.green, "EquipBestButton", "Equip Best", star)
	place(best, Vector2.new(1, 0.5), UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.24, 0.92), 8)
	best.Parent = header
	local close = w:FindFirstChild("CloseButton", true)
	close.Parent = header
	place(close, Vector2.new(1, 0.5), UDim2.fromScale(0.99, 0.5), UDim2.fromScale(0.07, 0.92), 8)
	square(close)

	-- sous le bandeau : onglets en rectangles validés, sans sunburst
	local tabs = w:FindFirstChild("Tabs", true)
	tabs.Parent = w
	place(tabs, Vector2.zero, UDim2.new(0.02, 0, 0.112, 24), UDim2.new(0.78, 0, 0.045, 30), 5)
	tabs.BackgroundTransparency = 1
	local tl = tabs:FindFirstChildOfClass("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	tl.Padding = UDim.new(0.012, 0)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	for order, def in TABS do
		local n, color, label = def[1], def[2], def[3]
		local old = tabs:FindFirstChild(n)
		local icon, selected = nil, order == 1
		if old then
			local oi = old:FindFirstChild("Icon", true) or old:FindFirstChild("TabIcon")
			icon = oi and oi.Image
			local os = old:FindFirstChild("Selected", true)
			if os then
				selected = os.Visible
			end
			old:Destroy()
		end
		local b = validated(RECT[color], n, label, icon, true)
		b.LayoutOrder = order
		b.Size = UDim2.fromScale(0.24, 1)
		-- onglet choisi : liseré blanc (le code montre « Selected » sur l'onglet ouvert)
		local sel = Instance.new("Frame")
		sel.Name = "Selected"
		sel.BackgroundTransparency = 1
		place(sel, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(1, 6, 1, 6), 20)
		local ss = Instance.new("UIStroke")
		ss.Color = WHITE
		ss.Thickness = 3
		ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ss.Parent = sel
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0.1, 0)
		sc.Parent = sel
		sel.Visible = selected
		sel.Parent = b
		b.Parent = tabs
	end

	-- recherche à droite des onglets
	local search = child(w, "TextBox", "SearchBox")
	place(search, Vector2.new(1, 0), UDim2.new(0.98, 0, 0.117, 26), UDim2.new(0.18, 0, 0.035, 26), 5)
	search.BackgroundColor3 = Color3.fromHex("0E0E18")
	search.BackgroundTransparency = 0.05
	search.FontFace = FONT_BOLD
	search.PlaceholderText = "Search items..."
	search.PlaceholderColor3 = Color3.fromHex("8A8AA0")
	search.TextColor3 = WHITE
	search.TextScaled = true
	search.TextXAlignment = Enum.TextXAlignment.Left
	local stc = search:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	stc.MaxTextSize = 22
	stc.Parent = search
	local sstroke = child(search, "UIStroke", "UIStroke")
	sstroke.Color = Color3.fromHex("2E2E44")
	sstroke.Thickness = 2
	sstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	child(search, "UICorner", "UICorner").CornerRadius = UDim.new(0.12, 0)

	-- ligne d'aide et compteurs
	local hint = child(w, "TextLabel", "HintLabel")
	place(hint, Vector2.zero, UDim2.new(0.025, 0, 0.167, 60), UDim2.new(0.5, 0, 0.03, 10), 5)
	text(hint, "Click an item to place it", Enum.TextXAlignment.Left, Color3.fromHex("DCE4F2"), 22, 0.1)
	for i, n in { "CounterPill", "DisplayPill" } do
		local pill = w[n]
		place(pill, Vector2.new(1, 0), UDim2.new(if i == 1 then 0.77 else 0.98, 0, 0.167, 60), UDim2.new(0.19, 0, 0.03, 10), 5)
		local t = pill:FindFirstChild(if i == 1 then "Counter" else "Displays")
		text(t, t.Text, Enum.TextXAlignment.Right, WHITE, 22, 0.1)
		place(t, Vector2.new(0, 0.5), UDim2.fromScale(0.16, 0.5), UDim2.fromScale(0.84, 1), 5)
	end

	-- la grille
	local list = w.List
	place(list, Vector2.zero, UDim2.new(0.02, 0, 0.207, 76), UDim2.new(0.955, 0, 0.78, -84), 3)
	local track = w:FindFirstChild("ScrollTrack")
	if track then
		place(track, Vector2.zero, UDim2.new(0.982, 0, 0.207, 76), UDim2.new(0, 6, 0.78, -84), 3)
	end
	local empty = w:FindFirstChild("EmptyLabel")
	if empty then
		place(empty, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.6), UDim2.fromScale(0.6, 0.06), 4)
		text(empty, "No items here.", Enum.TextXAlignment.Center, WHITE, 32)
	end

	-- Items : $/s en vert en haut, nom en bas, rareté sous le nom, badges en haut ; un clic sur la carte = Place
	local it = grid(list.ItemsSection)
	card(it)
	place(it.Income, Vector2.zero, UDim2.fromScale(0.07, 0.04), UDim2.fromScale(0.6, 0.11), 6)
	text(it.Income, it.Income.Text, Enum.TextXAlignment.Left, GREEN, 22)
	place(it.ItemName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.755), UDim2.fromScale(0.92, 0.16), 6) -- 2 lignes
	text(it.ItemName, it.ItemName.Text, Enum.TextXAlignment.Center, WHITE, 22)
	local bar = it.RarityBar
	place(bar, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.915), UDim2.fromScale(0.9, 0.06), 6)
	bar.BackgroundTransparency = 1
	local top = bar:FindFirstChild("RarityBarTop")
	if top then
		top.Visible = false
	end
	place(bar.Rarity, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 6)
	text(bar.Rarity, bar.Rarity.Text, Enum.TextXAlignment.Center, Color3.fromHex("C8C8D8"), 16)
	place(it.MutationTag, Vector2.zero, UDim2.fromScale(0.07, 0.16), UDim2.fromScale(0.46, 0.09), 7)
	place(it.DisplayedBadge, Vector2.new(1, 0), UDim2.fromScale(0.95, 0.04), UDim2.fromScale(0.42, 0.1), 7)
	local alert = it:FindFirstChild("CardAlert")
	if alert then
		place(alert, Vector2.new(0.5, 0.5), UDim2.fromScale(0.92, 0.08), UDim2.fromScale(0.2, 0.17), 10)
		square(alert)
	end
	local anti = it:FindFirstChild("AntiTheft")
	if anti then
		place(anti, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 9)
	end
	hitArea(it, "PlaceButton")
	hitArea(it, "UnequipButton").Visible = false

	-- Outils (et potions) : stat en vert en haut, nom en bas, EQUIPPED en haut à droite ; un clic = Equip
	local tt = grid(list.ToolsSection)
	card(tt)
	place(tt.ToolStat, Vector2.zero, UDim2.fromScale(0.07, 0.04), UDim2.fromScale(0.86, 0.11), 6)
	text(tt.ToolStat, tt.ToolStat.Text, Enum.TextXAlignment.Left, GREEN, 22)
	place(tt.ToolName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.9, 0.13), 6)
	text(tt.ToolName, tt.ToolName.Text, Enum.TextXAlignment.Center, WHITE, 22)
	hitArea(tt, "EquipButton", "EquipLabel")
	local pill = tt:FindFirstChild("EquippedPill")
	if pill then
		place(pill, Vector2.new(1, 0), UDim2.fromScale(0.95, 0.16), UDim2.fromScale(0.5, 0.1), 7)
	end

	-- Titres : le titre au centre, sa description en bas, EQUIPPED en haut à droite ; un clic = Equip
	local ti = grid(list.TitlesSection)
	card(ti)
	place(ti.TitleName, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.9, 0.2), 6)
	ti.TitleName.TextXAlignment = Enum.TextXAlignment.Center
	place(ti.TitleDesc, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.9, 0.12), 6)
	ti.TitleDesc.TextXAlignment = Enum.TextXAlignment.Center
	hitArea(ti, "EquipButton", "Label")
	local tpill = ti:FindFirstChild("EquippedPill")
	if tpill then
		place(tpill, Vector2.new(1, 0), UDim2.fromScale(0.95, 0.05), UDim2.fromScale(0.5, 0.1), 7)
	end
end

local gui = SG.UI_Inventory
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_UI_Inventory_avant_refF") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_UI_Inventory_avant_refF"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Inventory d'après les références de Clément du 25/11 (bandeau bleu, cartes)")
local ok, err = pcall(apply, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Inventory refait d'après les références du 25/11"
