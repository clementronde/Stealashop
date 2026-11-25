--!nonstrict
-- ui_inventaire_v3_retour.luau (L-380, Clément, 2026-11-25 : « le bouton inventaire n'ouvre pas le display. Il ouvre
-- un inventaire […] retrouve les références et exécute ça » ; « je t'avais fait un exemple, tu le retrouves ») :
-- à lancer en Edit.
--   - Remet UI_Inventory, l'écran construit le 15/11 d'après la maquette Figma v3 du 10/11 (Old 67:1018 PC,
--     69:1294 téléphone, noms 70:1574), archivé dans ServerStorage/MapBackups/2026-11-15_RefonteUI/UI_Inventory :
--     bandeau orange « Inventory », compteur, « displays », EQUIP BEST, cartes, onglets à droite. Mêmes noms
--     qu'InventoryController (ItemsTab, ToolsTab, PotionsTab, List.ItemsSection.Cards.Template…).
--   - Ajoute l'onglet TITLES (Clément, 25/11 : « les titres s'activent dans l'inventaire ») : TitlesTab et
--     List.TitlesSection (TitleRow.SectionTitle, Cards avec un Template caché : TitleName, TitleDesc, EquipButton,
--     EquippedPill.EquippedLabel). Le code clone une carte par titre possédé et pose le titre choisi sur BB_PlayerTag.
--   - Habille avec la recette de bouton du jeu, sans changer de nom : EquipBestButton vert (texte dans
--     EquipBestLabel, StarIcon au-dessus), CloseButton rose (XLabel), EquipButton des titres vert.
-- UI_Inventory_Gris (lot D) n'est plus utile : il reste caché, le code ne le lit pas.
-- Sauvegardes : l'écran remis vient de la sauvegarde du 15/11 ; un UI_Inventory déjà présent dans StarterGui est
-- rangé dans ServerStorage/MapBackups/2026-11-25_Inventaire avant d'être remplacé.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

local INK = Color3.fromHex("0D0D14")
local WHITE = Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local QUILT = "rbxassetid://87198718489515"
local P = {
	green = { hi = "B6FF4E", base = "9AFF09", lip = "5B920E", line = "113909" },
	pink = { hi = "FF8FC8", base = "FF4FA3", lip = "B82A6E", line = "5C0F33" },
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

local function corner(o, r)
	child(o, "UICorner", "UICorner").CornerRadius = UDim.new(r, 0)
end

local function stroke(o, th, color, mode)
	local s = child(o, "UIStroke", "UIStroke")
	s.Thickness = th
	s.Color = color
	s.ApplyStrokeMode = mode
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end

local function text(l, value, z)
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	if value then
		l.Text = value
	end
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.TextWrapped = true
	l.ZIndex = z
	stroke(l, 0.14, INK, Enum.ApplyStrokeMode.Contextual)
end

-- recette de bouton du jeu (UI_Displayed.DisplayBestButton) ; le texte passe dans labelName
local function recipe(b, pal, labelName, value)
	local z = math.max(b.ZIndex, 2)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	if b:IsA("TextButton") then
		if value == nil and b.Text ~= "" then
			value = b.Text
		end
		b.Text = ""
	end
	-- l'ancien habillage du bouton (dégradé et contour posés sur le bouton lui-même) laisse la place à la recette
	for _, c in b:GetChildren() do
		if c:IsA("UIGradient") or c:IsA("UIStroke") then
			c:Destroy()
		end
	end
	for _, old in { "Shade", "Studs" } do
		local o = b:FindFirstChild(old)
		if o and o:IsA("GuiObject") then
			o.Visible = false
		end
	end
	local lip = child(b, "Frame", "Lip")
	lip.BackgroundColor3 = Color3.fromHex(pal.lip)
	lip.BackgroundTransparency = 0
	lip.Size = UDim2.fromScale(1, 1)
	lip.ZIndex = z
	corner(lip, 0.2)
	stroke(lip, 0.07, INK, Enum.ApplyStrokeMode.Border)
	local face = child(b, "Frame", "Face")
	face.BackgroundColor3 = WHITE
	face.BackgroundTransparency = 0
	face.Size = UDim2.fromScale(1, 0.86)
	face.ZIndex = z + 1
	corner(face, 0.2)
	local g = child(face, "UIGradient", "UIGradient")
	g.Color = ColorSequence.new(Color3.fromHex(pal.hi), Color3.fromHex(pal.base))
	g.Rotation = 90
	local quilt = child(face, "ImageLabel", "Quilt")
	quilt.BackgroundTransparency = 1
	quilt.Size = UDim2.fromScale(1, 1)
	quilt.Image = QUILT
	quilt.ImageTransparency = 0.91
	quilt.ScaleType = Enum.ScaleType.Tile
	quilt.TileSize = UDim2.fromOffset(48, 48)
	quilt.ZIndex = z + 1
	local line = child(face, "Frame", "FaceLine")
	line.BackgroundTransparency = 1
	line.Size = UDim2.fromScale(1, 1)
	line.ZIndex = z + 1
	corner(line, 0.2)
	stroke(line, 0.07, Color3.fromHex(pal.line), Enum.ApplyStrokeMode.Border)
	if labelName then
		local l = b:FindFirstChild(labelName, true)
		if not l then
			-- texte neuf : centré sur la face ; un texte existant (EquipBestLabel, XLabel) garde sa place
			l = Instance.new("TextLabel")
			l.Name = labelName
			l.Parent = b
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5, 0.43)
			l.Size = UDim2.fromScale(0.86, 0.58)
		end
		text(l, value, z + 5)
	end
	for _, c in b:GetChildren() do
		if c:IsA("ImageLabel") and c.Name ~= "Quilt" then
			c.ZIndex = z + 6 -- icône (StarIcon…) au-dessus de la face
		end
	end
	b:SetAttribute("Press", b:GetAttribute("Press") or "Squash")
	b:SetAttribute("Hover", b:GetAttribute("Hover") or "Pop")
end

local function titles(gui)
	local root = gui.Root
	local tabs = root.Tabs
	-- onglet TITLES, copie de PotionsTab (même taille, même habillage)
	local tab = tabs:FindFirstChild("TitlesTab")
	if tab then
		tab:Destroy()
	end
	tab = tabs.PotionsTab:Clone()
	tab.Name = "TitlesTab"
	tab.LayoutOrder = tabs.PotionsTab.LayoutOrder + 10
	tab.TabLabel.Text = "TITLES"
	tab.TabIcon.Image = Icons.ICON_Z4_Couronne.Texture
	local sel = tab:FindFirstChild("Selected")
	if sel then
		sel.Visible = false
	end
	tab.Parent = tabs
	-- 4 onglets : chacun un peu moins haut pour tenir dans la colonne
	for _, t in tabs:GetChildren() do
		if t:IsA("GuiButton") then
			t.Size = UDim2.fromScale(1, 0.235)
		end
	end
	tabs.Size = UDim2.fromScale(tabs.Size.X.Scale, math.max(tabs.Size.Y.Scale, 0.74))

	-- section des titres, copie de PotionsSection (titre, compteur, grille)
	local list = root.Window.List
	local sec = list:FindFirstChild("TitlesSection")
	if sec then
		sec:Destroy()
	end
	sec = list.PotionsSection:Clone()
	sec.Name = "TitlesSection"
	sec.LayoutOrder = list.PotionsSection.LayoutOrder + 10
	sec.Visible = false
	sec.TitleRow.SectionTitle.Text = "TITLES"
	sec.Parent = list
	local cards = sec.Cards
	for _, c in cards:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local grid = cards:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid.CellSize = UDim2.new(0.31, 0, 0, 120)
	end
	local tpl = Instance.new("TextButton")
	tpl.Name = "Template"
	tpl.Text = ""
	tpl.AutoButtonColor = false
	tpl.Visible = false
	tpl.BackgroundColor3 = Color3.fromHex("1F1F2A")
	tpl.BackgroundTransparency = 0
	tpl.ZIndex = 3
	stroke(tpl, 3, INK, Enum.ApplyStrokeMode.Border).StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	local name = Instance.new("TextLabel")
	name.Name = "TitleName"
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromScale(0.5, 0.08)
	name.Size = UDim2.fromScale(0.9, 0.3)
	text(name, "OWNER", 5)
	local g = Instance.new("UIGradient")
	g.Name = "TextGradient"
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D4D")),
		ColorSequenceKeypoint.new(0.33, Color3.fromHex("FFE94D")),
		ColorSequenceKeypoint.new(0.67, Color3.fromHex("4DC3FF")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("FF6BE1")),
	})
	g.Parent = name
	name.Parent = tpl
	local desc = Instance.new("TextLabel")
	desc.Name = "TitleDesc"
	desc.AnchorPoint = Vector2.new(0.5, 0)
	desc.Position = UDim2.fromScale(0.5, 0.4)
	desc.Size = UDim2.fromScale(0.9, 0.16)
	text(desc, "Game owner", 5)
	desc.TextColor3 = Color3.fromHex("C8C8D0")
	desc.Parent = tpl
	local equip = Instance.new("TextButton")
	equip.Name = "EquipButton"
	equip.AnchorPoint = Vector2.new(0.5, 1)
	equip.Position = UDim2.fromScale(0.5, 0.94)
	equip.Size = UDim2.fromScale(0.8, 0.32)
	equip.ZIndex = 4
	equip.Text = "EQUIP"
	equip.Parent = tpl
	local mn = Instance.new("UISizeConstraint")
	mn.MinSize = Vector2.new(0, 44)
	mn.Parent = equip
	recipe(equip, P.green, "Label")
	local pill = Instance.new("Frame")
	pill.Name = "EquippedPill"
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.fromScale(0.5, 0.94)
	pill.Size = UDim2.fromScale(0.8, 0.28)
	pill.BackgroundColor3 = Color3.fromHex("3A3A48")
	pill.ZIndex = 6
	pill.Visible = false
	corner(pill, 0.2)
	pill.Parent = tpl
	local pl = Instance.new("TextLabel")
	pl.Name = "EquippedLabel"
	pl.AnchorPoint = Vector2.new(0.5, 0.5)
	pl.Position = UDim2.fromScale(0.5, 0.5)
	pl.Size = UDim2.fromScale(0.86, 0.62)
	text(pl, "EQUIPPED", 7)
	pl.Parent = pill
	tpl.Parent = cards
end

local function apply()
	local current = SG:FindFirstChild("UI_Inventory")
	if current then
		local f = SS.MapBackups:FindFirstChild("2026-11-25_Inventaire")
		if not f then
			f = Instance.new("Folder")
			f.Name = "2026-11-25_Inventaire"
			f.Parent = SS.MapBackups
		end
		current.Parent = f
	end
	local src = SS.MapBackups["2026-11-15_RefonteUI"].UI_Inventory
	local gui = src:Clone()
	gui:SetAttribute("AncienEmplacement", nil)
	gui.Enabled = false
	titles(gui)
	local w = gui.Root.Window
	recipe(w.EquipBestButton, P.green, "EquipBestLabel")
	recipe(w.CloseButton, P.pink, "XLabel", "X")
	gui.Parent = SG
	local grey = SG:FindFirstChild("UI_Inventory_Gris")
	if grey then
		grey.Enabled = false
	end
	return gui
end

local rec = CHS:TryBeginRecording("UI : UI_Inventory remis (maquette v3), onglet TITLES (L-380)")
local ok, err = pcall(apply)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Inventory remis, onglet TITLES ajouté"
