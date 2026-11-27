--!nonstrict
-- ui_inventaire_refE.luau (Clément, 25/11 au soir : « Inventaire à revoir selon référence ») : à lancer en Edit APRÈS
-- ui_inventaire_v3_retour.luau. Construction seulement (version grise), d'après :
--   - Reference_E e2_inventaire_67s.jpg et e2_m_ouverture_inventaire_64s.jpg : panneau sombre translucide à motif de
--     points, onglets carrés à gauche dans le panneau (l'onglet choisi en jaune), gros titre et compteur en haut à
--     gauche, champ de recherche en haut à droite, croix au coin, texte au centre quand la liste est vide ;
--   - le panneau « 7/10 Actifs » du 10/11 : une ligne par objet (icône, nom, $/s, bouton à droite) et un gros bouton
--     vert « Équiper le meilleur » en bas.
-- Règle de Clément (25/11) : aucun bouton inventé. Tous les boutons sont des CLONES des boutons validés du HUD :
--   - onglets = carré bleu d'Index (UI_HUD.LeftRailTouch.IndexButton) ; l'onglet choisi montre l'image Selected =
--     la face jaune or du bouton Display (rbxassetid://130385405874171), que le code allume déjà ;
--   - PlaceButton, EquipButton, EquipBestButton = rectangle vert du Shop (UI_HUD.LeftRail.RobuxShopButton) ;
--   - UnequipButton = rectangle rose d'Upgrades (UI_HUD.LeftRail.SkillTreeButton) ;
--   - on ne change que Label et LabelShadow (texte, et largeur pour les mots plus longs que « Shop ») et Icon.
-- La croix (CloseButton) n'a pas de modèle validé : elle reste celle du 15/11, à faire valider.
-- Le motif à points est provisoire (image des tenons en petit) : notre UI_Tex_Dots_Tile.png est à publier.
-- Noms lus par InventoryController : tous gardés (Tabs.<X>Tab.Selected, <X>Section.Cards.Template et ses enfants,
-- Counter, Displays, List, ScrollTrack, CloseButton, EquipBestButton, SectionCount.CountLabel).
-- Ajouts : Window.SearchBox (TextBox) et Window.EmptyLabel (caché), pas encore lus par le code.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Inventory_avant_refE.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local INK = Color3.fromHex("0D0D14")
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromHex("5CFF5C")
local PANEL = Color3.fromHex("1E1E2C")
local ROW = Color3.fromHex("2C2C40")
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local GOLD_SQUARE = "rbxassetid://130385405874171" -- Background du DisplayedButton (fiche Boutons_valides)
local DOTS = "rbxassetid://3014551673" -- provisoire : à remplacer par UI_Tex_Dots_Tile.png une fois publiée
local ROW_RATIO = 6.2 -- largeur / hauteur d'une ligne (boutons de 44 px en 844 × 390)

local function must(parent, name, recursive)
	local found = parent and parent:FindFirstChild(name, recursive)
	assert(found, `{name} introuvable`)
	return found
end

local hud = SG.UI_HUD
local SQUARE_BLUE = must(must(hud, "LeftRailTouch", true), "IndexButton")
local RECT_GREEN = must(must(hud, "LeftRail", true), "RobuxShopButton")
local RECT_PINK = must(must(hud, "LeftRail", true), "SkillTreeButton")

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

local function text(l, value, align, color, z)
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = value
	l.TextColor3 = color or WHITE
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	if z then
		l.ZIndex = z
	end
	local s = l:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.14
	s.Color = INK
	s.Parent = l
end

local function square(o)
	local ar = o:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = o
end

-- Clone d'un bouton validé : texte de Label et LabelShadow, image d'Icon ; rien d'autre (les alertes du HUD sont
-- retirées). Sur un rectangle, un mot plus long que « Shop » élargit Label et LabelShadow jusqu'au bord droit.
local function validated(src, name, label, icon, labelName)
	local b = src:Clone()
	b.Name = name
	for _, d in b:GetChildren() do
		if d.Name:match("Alert$") then
			d:Destroy()
		end
	end
	local lab, shadow = b:FindFirstChild("Label"), b:FindFirstChild("LabelShadow")
	local rect = src.Parent.Name == "LeftRail"
	for _, l in { lab, shadow } do
		if l then
			l.Text = label
			if not rect then
				l.TextScaled = true
				l.TextWrapped = false -- « WEAPONS » sur une ligne (TextScaled d'abord, sinon Studio remet le retour à la ligne)
			end
			if rect and #label > 4 then
				l.Size = UDim2.new(0.58, 0, l.Size.Y.Scale, 0)
				l.Position = UDim2.new(0.665, 0, l.Position.Y.Scale, 0)
				l.TextScaled = true
				l.TextWrapped = true
			end
		end
	end
	if lab and labelName then
		lab.Name = labelName
	end
	local ic = b:FindFirstChild("Icon", true)
	if ic and icon then
		ic.Image = icon
	end
	b.LayoutOrder = 0
	return b
end

local function row(template)
	template.BackgroundColor3 = ROW
	template.BackgroundTransparency = 0.15
	template.AutoButtonColor = false
	template.Text = ""
	template.AnchorPoint = Vector2.new(0, 0)
	template.Position = UDim2.new()
	template.Size = UDim2.new(1, -6, 0, 10000) -- la hauteur vient du rapport (même astuce que l'ancienne grille)
	for _, c in template:GetChildren() do
		if c:IsA("UICorner") or c:IsA("UIGradient") then
			c:Destroy()
		end
	end
	local ar = template:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = ROW_RATIO
	ar.AspectType = Enum.AspectType.FitWithinMaxSize
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.Parent = template
	local s = template:FindFirstChildOfClass("UIStroke")
	if s then
		s:Destroy() -- pas de contour : il noircissait les lignes dans les captures
	end
	local shadow = template:FindFirstChild("CardShadow")
	if shadow then
		shadow.Visible = false
	end
	-- icône à gauche (Clip garde Rays et Glow derrière elle)
	for _, n in { "Clip", "Icon" } do
		local o = template:FindFirstChild(n)
		if o then
			place(o, Vector2.new(0, 0.5), UDim2.fromScale(0.012, 0.5), UDim2.fromScale(0.2, 0.84), if n == "Clip" then 2 else 3)
			square(o)
		end
	end
	local outline = template:FindFirstChild("HoverOutline")
	if outline then
		place(outline, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 9)
	end
end

local function rightButton(template, b, z)
	place(b, Vector2.new(1, 0.5), UDim2.fromScale(0.985, 0.5), UDim2.fromScale(0.4, 0.8), z or 6)
	b.Parent = template
end

local function sectionCards(section)
	local cards = section.Cards
	local grid = cards:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid:Destroy()
	end
	local list = child(cards, "UIListLayout", "UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	cards.AutomaticSize = Enum.AutomaticSize.Y
	cards.Size = UDim2.fromScale(1, 0)
	local title = section:FindFirstChild("TitleRow")
	if title then
		title.Visible = false -- le gros titre et le compteur sont en haut du panneau (référence E)
	end
	return cards:FindFirstChild("Template")
end

local function apply(gui)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = gui.Root
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 0.56)
	local rar = root:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	rar.AspectRatio = 1.5
	rar.Parent = root
	local rsz = root:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	rsz.MinSize = Vector2.new(456, 304)
	rsz.Parent = root
	local shadowW = root:FindFirstChild("WindowShadow")
	if shadowW then
		shadowW.Visible = false
	end

	-- le panneau : sombre, translucide, droit, motif de points
	local w = root.Window
	place(w, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 2)
	w.BackgroundColor3 = PANEL
	w.BackgroundTransparency = 0.18
	local wc = w:FindFirstChildOfClass("UICorner")
	if wc then
		wc:Destroy()
	end
	local ws = w:FindFirstChildOfClass("UIStroke")
	if ws then
		ws.Color = INK
		ws.Thickness = 3
		ws.Transparency = 0
	end
	local dots = w:FindFirstChild("Studs")
	if dots then
		for _, c in dots:GetChildren() do
			if c:IsA("UICorner") then
				c:Destroy()
			end
		end
		place(dots, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 1)
		dots.Image = DOTS
		dots.ScaleType = Enum.ScaleType.Tile
		dots.TileSize = UDim2.fromOffset(18, 18)
		dots.ImageColor3 = WHITE
		dots.ImageTransparency = 0.94
		dots.BackgroundTransparency = 1
	end

	-- onglets carrés à gauche, dans le panneau (clones du carré bleu d'Index)
	local tabs = root:FindFirstChild("Tabs") or w:FindFirstChild("Tabs")
	tabs.Parent = w
	place(tabs, Vector2.zero, UDim2.fromScale(0.014, 0.03), UDim2.fromScale(0.115, 0.95), 5)
	tabs.BackgroundTransparency = 1
	local tl = tabs:FindFirstChildOfClass("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Vertical
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.Padding = UDim.new(0.02, 0)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	for order, n in { "ItemsTab", "ToolsTab", "PotionsTab", "TitlesTab" } do
		local old = tabs:FindFirstChild(n)
		local label, icon, selected = n:gsub("Tab$", ""):upper(), nil, order == 1
		if old then
			local ol, oi, os = old:FindFirstChild("TabLabel"), old:FindFirstChild("TabIcon"), old:FindFirstChild("Selected")
			local ol2, oi2 = old:FindFirstChild("Label"), old:FindFirstChild("Icon", true)
			if ol then
				label = ol.Text
			elseif ol2 then
				label = ol2.Text
			end
			if oi then
				icon = oi.Image
			elseif oi2 then
				icon = oi2.Image
			end
			if os then
				selected = os.Visible
			end
			old:Destroy()
		end
		local b = validated(SQUARE_BLUE, n, label, icon)
		b.LayoutOrder = order
		b.Size = UDim2.fromScale(1, 0.25)
		local bg = b.Background
		local sel = bg:Clone()
		sel.Name = "Selected"
		for _, c in sel:GetChildren() do
			c:Destroy()
		end
		for k in sel:GetAttributes() do
			sel:SetAttribute(k, nil)
		end
		sel.Image = GOLD_SQUARE
		place(sel, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1))
		sel.Visible = selected
		sel.Parent = bg
		b.Parent = tabs
	end

	-- en haut : gros titre, compteurs, recherche, croix
	local header = w.Header
	place(header, Vector2.zero, UDim2.fromScale(0.15, 0.03), UDim2.fromScale(0.46, 0.105), 4)
	header.BackgroundTransparency = 1
	for _, n in { "HeaderFill", "Studs", "Gloss", "HeaderLine" } do
		local o = header:FindFirstChild(n)
		if o then
			o.Visible = false
		end
	end
	local title = header.Title
	place(title, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 4)
	text(title, "INVENTORY", Enum.TextXAlignment.Left)
	for i, n in { "CounterPill", "DisplayPill" } do
		local pill = w[n]
		place(pill, Vector2.zero, UDim2.fromScale(if i == 1 then 0.15 else 0.375, 0.14), UDim2.fromScale(0.21, 0.06), 4)
		pill.BackgroundTransparency = 1
		local pmin = pill:FindFirstChildOfClass("UISizeConstraint")
		if pmin then
			pmin.MinSize = Vector2.new(0, 16) -- 190 × 30 débordait sur téléphone
		end
		for _, c in pill:GetChildren() do
			if c:IsA("UIStroke") or c:IsA("UIGradient") then
				c:Destroy()
			end
		end
		local ic = pill:FindFirstChildWhichIsA("ImageLabel")
		if ic then
			place(ic, Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), UDim2.fromScale(0.2, 1), 4)
			square(ic)
		end
		local t = pill:FindFirstChild(if i == 1 then "Counter" else "Displays")
		place(t, Vector2.new(0, 0.5), UDim2.fromScale(0.17, 0.5), UDim2.fromScale(0.83, 0.9), 4)
		text(t, t.Text, Enum.TextXAlignment.Left)
	end
	local search = child(w, "TextBox", "SearchBox")
	place(search, Vector2.zero, UDim2.fromScale(0.62, 0.045), UDim2.fromScale(0.3, 0.085), 4)
	search.BackgroundColor3 = Color3.fromHex("14141E")
	search.BackgroundTransparency = 0.1
	search.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	search.PlaceholderText = "Search..."
	search.PlaceholderColor3 = Color3.fromHex("9A9AB0")
	search.Text = ""
	search.TextColor3 = WHITE
	search.TextScaled = true
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.ClearTextOnFocus = false
	local sp = child(search, "UIPadding", "UIPadding")
	sp.PaddingLeft = UDim.new(0.05, 0)
	sp.PaddingTop = UDim.new(0.24, 0)
	sp.PaddingBottom = UDim.new(0.24, 0)
	local close = w.CloseButton
	place(close, Vector2.new(0.5, 0.5), UDim2.fromScale(0.985, 0.015), UDim2.fromScale(0.075, 0.12), 8)

	-- la liste, une ligne par objet
	local list = w.List
	place(list, Vector2.zero, UDim2.fromScale(0.15, 0.22), UDim2.fromScale(0.815, 0.58), 3)
	list.BackgroundTransparency = 1
	local track = w:FindFirstChild("ScrollTrack")
	if track then
		place(track, Vector2.zero, UDim2.new(0.972, 0, 0.22, 0), UDim2.new(0, 6, 0.58, 0), 3)
	end
	local empty = child(w, "TextLabel", "EmptyLabel")
	place(empty, Vector2.new(0.5, 0.5), UDim2.fromScale(0.56, 0.5), UDim2.fromScale(0.6, 0.08), 4)
	text(empty, "No items here.", Enum.TextXAlignment.Center)
	empty.Visible = false

	-- Items : icône, nom, $/s et rareté, mutation, badge, PLACE (vert) ou UNEQUIP (rose) à droite
	local it = sectionCards(list.ItemsSection)
	row(it)
	place(it.ItemName, Vector2.zero, UDim2.fromScale(0.165, 0.1), UDim2.fromScale(0.42, 0.36), 4)
	text(it.ItemName, it.ItemName.Text, Enum.TextXAlignment.Left)
	place(it.Income, Vector2.zero, UDim2.fromScale(0.165, 0.52), UDim2.fromScale(0.2, 0.28), 4)
	text(it.Income, it.Income.Text, Enum.TextXAlignment.Left, GREEN)
	local bar = it.RarityBar
	place(bar, Vector2.zero, UDim2.fromScale(0.375, 0.52), UDim2.fromScale(0.2, 0.28), 4)
	bar.BackgroundTransparency = 1
	if bar:FindFirstChild("RarityBarTop") then
		bar.RarityBarTop.Visible = false
	end
	place(bar.Rarity, Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1), 4)
	text(bar.Rarity, bar.Rarity.Text, Enum.TextXAlignment.Left)
	place(it.MutationTag, Vector2.zero, UDim2.fromScale(0.012, 0.06), UDim2.fromScale(0.135, 0.26), 5) -- en haut de l'icône
	place(it.DisplayedBadge, Vector2.zero, UDim2.fromScale(0.012, 0.66), UDim2.fromScale(0.13, 0.26), 5)
	local alert = it:FindFirstChild("CardAlert")
	if alert then
		place(alert, Vector2.new(0.5, 0.5), UDim2.fromScale(0.15, 0.18), UDim2.fromScale(0.1, 0.34), 8)
		square(alert)
	end
	local anti = it:FindFirstChild("AntiTheft")
	if anti then
		place(anti, Vector2.zero, UDim2.new(), UDim2.fromScale(0.15, 1), 7)
	end
	local displayIcon = w.DisplayPill:FindFirstChildWhichIsA("ImageLabel")
	local backpackIcon = w.CounterPill:FindFirstChildWhichIsA("ImageLabel")
	for _, n in { "PlaceButton", "UnequipButton" } do
		local old = it:FindFirstChild(n)
		local wasVisible = if old then old.Visible else n == "PlaceButton"
		if old then
			old:Destroy()
		end
		local b = if n == "PlaceButton"
			then validated(RECT_GREEN, n, "Place", displayIcon and displayIcon.Image)
			else validated(RECT_PINK, n, "Unequip", backpackIcon and backpackIcon.Image)
		b.Visible = wasVisible
		rightButton(it, b)
	end

	-- Outils (et potions, qui prennent ce Template) : icône, nom, stat, EQUIP (vert) ou EQUIPPED à droite
	local tt = sectionCards(list.ToolsSection)
	row(tt)
	place(tt.ToolName, Vector2.zero, UDim2.fromScale(0.165, 0.1), UDim2.fromScale(0.45, 0.38), 4)
	text(tt.ToolName, tt.ToolName.Text, Enum.TextXAlignment.Left)
	place(tt.ToolStat, Vector2.zero, UDim2.fromScale(0.165, 0.52), UDim2.fromScale(0.4, 0.28), 4)
	text(tt.ToolStat, tt.ToolStat.Text, Enum.TextXAlignment.Left, GREEN)
	local oldEquip = tt:FindFirstChild("EquipButton")
	if oldEquip then
		oldEquip:Destroy()
	end
	rightButton(tt, validated(RECT_GREEN, "EquipButton", "Equip", nil, "EquipLabel"))
	local pill = tt:FindFirstChild("EquippedPill")
	if pill then
		place(pill, Vector2.new(1, 0.5), UDim2.fromScale(0.985, 0.5), UDim2.fromScale(0.3, 0.5), 6)
	end

	-- Titres : nom du titre, description, EQUIP (vert) ou EQUIPPED à droite
	local ti = sectionCards(list.TitlesSection)
	row(ti)
	place(ti.TitleName, Vector2.zero, UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.6, 0.42), 4)
	ti.TitleName.TextXAlignment = Enum.TextXAlignment.Left
	place(ti.TitleDesc, Vector2.zero, UDim2.fromScale(0.03, 0.56), UDim2.fromScale(0.6, 0.28), 4)
	ti.TitleDesc.TextXAlignment = Enum.TextXAlignment.Left
	local oldTitleEquip = ti:FindFirstChild("EquipButton")
	if oldTitleEquip then
		oldTitleEquip:Destroy()
	end
	rightButton(ti, validated(RECT_GREEN, "EquipButton", "Equip"))
	local tpill = ti:FindFirstChild("EquippedPill")
	if tpill then
		place(tpill, Vector2.new(1, 0.5), UDim2.fromScale(0.985, 0.5), UDim2.fromScale(0.3, 0.5), 6)
	end

	-- en bas à droite : gros bouton vert « Equip Best » (clone du Shop)
	local oldBest = w:FindFirstChild("EquipBestButton")
	local starImage = oldBest and oldBest:FindFirstChild("StarIcon") and oldBest.StarIcon.Image
	if oldBest then
		oldBest:Destroy()
	end
	local best = validated(RECT_GREEN, "EquipBestButton", "Equip Best", starImage)
	place(best, Vector2.new(1, 1), UDim2.fromScale(0.97, 0.975), UDim2.fromScale(0.34, 0.16), 6) -- 46 px de haut en 844 × 390
	best.Parent = w
end

local gui = SG.UI_Inventory
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_UI_Inventory_avant_refE") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_UI_Inventory_avant_refE"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Inventory d'après la référence E (lignes, onglets à gauche, boutons validés)")
local ok, err = pcall(apply, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Inventory refait d'après la référence E (boutons clonés du HUD)"
