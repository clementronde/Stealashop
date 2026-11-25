--!nonstrict
-- ui_admin_v3_habille.luau (chef de projet, 2026-11-25, pour Clément : « refais la mise en page d'UI_Admin sur ce modèle
-- [capture TikTok : bandeau rouge ADMIN PANEL, colonne d'onglets colorés à gauche, contenu à droite], avec notre
-- recette de bouton et les coins à 6 %, sans changer un seul nom lu par le code ») : à lancer en Edit, APRÈS
-- ui_admin_v2_gris.luau (mise en page en onglets).
-- Habillage seulement :
--   - recette de bouton du jeu (celle de UI_Displayed.DisplayBestButton, façon Throw a Seed) : Lip (rebord foncé),
--     Face (dégradé, 86 % de la hauteur) avec Quilt, Rim et FaceLine, Label et LabelShadow ;
--   - Header : bandeau rouge, « ADMIN PANEL » en grosses lettres blanches contourées, couronne, pastille bleue ADMIN ;
--   - onglets : un bouton de couleur vive chacun, icône qui dépasse à gauche ;
--   - boutons d'action verts, RESET rose, sortes (Item, Box…) bleues, entrées des listes grises ;
--   - champs de saisie sombres ; cadres, cartes et panneaux droits (règle des coins).
-- Aucun nom lu par AdminController ni par le contrat ne change. Les textes des boutons passent dans un enfant Label
-- (le code ne lit que ResetProfileButton.Label, qui existe déjà). Les Template gardent EntryName et Selected.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Admin_v2 (l'état gris).

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

local INK = Color3.fromHex("0D0D14")
local WHITE = Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local QUILT = "rbxassetid://87198718489515"

-- palettes de la recette : hi (haut de la face), base (bas de la face), lip (rebord), line (contour de la face)
local P = {
	green = { hi = "B6FF4E", base = "9AFF09", lip = "5B920E", line = "113909" },
	blue = { hi = "8AD8FF", base = "2A9BFF", lip = "1665B8", line = "0B2F5C" },
	yellow = { hi = "FFE873", base = "FFC61A", lip = "B8860B", line = "5A3D00" },
	pink = { hi = "FF8FC8", base = "FF4FA3", lip = "B82A6E", line = "5C0F33" },
	purple = { hi = "C89BFF", base = "9B5CFF", lip = "5F2FB8", line = "2A0F5C" },
	teal = { hi = "6BFFE0", base = "1FD6B0", lip = "0F8A70", line = "053D31" },
	red = { hi = "FF6B6B", base = "FF2E2E", lip = "A81414", line = "520707" },
	grey = { hi = "C8C8D0", base = "8E8E9C", lip = "4E4E5A", line = "1E1E26" },
}

local TABS = {
	StatsTab = { pal = "green", icon = "UI_Icon_DP_Cash_3" },
	BaseTab = { pal = "blue", icon = "UI_Icon_Upgrades" },
	GiveTab = { pal = "yellow", icon = "ICON_BOX_Epic" },
	EventsTab = { pal = "purple", icon = "UI_Icon_DP_Luck3" },
	TeleportTab = { pal = "teal", icon = "UI_Index_Zone1" },
	ResetTab = { pal = "red", icon = nil },
}

local function hex(h)
	return Color3.fromHex(h)
end

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

local function noCorner(o)
	local c = o:FindFirstChildOfClass("UICorner")
	if c then
		c:Destroy()
	end
end

local function stroke(o, name, th, color, mode)
	local s = child(o, "UIStroke", name)
	s.Thickness = th
	s.Color = color
	s.ApplyStrokeMode = mode
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end

local function text(l, value, z, xAlign)
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	if value then
		l.Text = value
	end
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	l.ZIndex = z
	stroke(l, "UIStroke", 0.14, INK, Enum.ApplyStrokeMode.Contextual)
end

-- recette de bouton sur un GuiButton existant ; labelName = l'enfant qui porte le texte (créé si besoin)
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
	local lip = child(b, "Frame", "Lip")
	lip.BackgroundColor3 = hex(pal.lip)
	lip.BackgroundTransparency = 0
	lip.Size = UDim2.fromScale(1, 1)
	lip.Position = UDim2.fromScale(0, 0)
	lip.ZIndex = z
	corner(lip, 0.2)
	stroke(lip, "UIStroke", 0.07, INK, Enum.ApplyStrokeMode.Border)
	local face = child(b, "Frame", "Face")
	face.BackgroundColor3 = WHITE
	face.BackgroundTransparency = 0
	face.Size = UDim2.fromScale(1, 0.86)
	face.Position = UDim2.fromScale(0, 0)
	face.ZIndex = z + 1
	corner(face, 0.2)
	local g = child(face, "UIGradient", "UIGradient")
	g.Color = ColorSequence.new(hex(pal.hi), hex(pal.base))
	g.Rotation = 90
	local quilt = child(face, "ImageLabel", "Quilt")
	quilt.BackgroundTransparency = 1
	quilt.Size = UDim2.fromScale(1, 1)
	quilt.Image = QUILT
	quilt.ImageTransparency = 0.91
	quilt.ScaleType = Enum.ScaleType.Tile
	quilt.TileSize = UDim2.fromOffset(48, 48)
	quilt.ZIndex = z + 1
	local rim = child(face, "Frame", "Rim")
	rim.BackgroundTransparency = 1
	rim.Size = UDim2.fromScale(1, 1)
	rim.ZIndex = z + 2
	corner(rim, 0.2)
	local rs = stroke(rim, "UIStroke", 0.04, WHITE, Enum.ApplyStrokeMode.Border)
	local fade = child(rs, "UIGradient", "RimFade")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	local line = child(face, "Frame", "FaceLine")
	line.BackgroundTransparency = 1
	line.Size = UDim2.fromScale(1, 1)
	line.ZIndex = z + 1
	corner(line, 0.2)
	stroke(line, "UIStroke", 0.07, hex(pal.line), Enum.ApplyStrokeMode.Border)
	if labelName then
		local l = b:FindFirstChild(labelName, true)
		if not l then
			l = Instance.new("TextLabel")
			l.Name = labelName
			l.Parent = b
		end
		if l.Parent ~= b and not l:IsDescendantOf(b) then
			l.Parent = b
		end
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.43)
		l.Size = UDim2.fromScale(0.88, 0.58)
		text(l, value, z + 5)
	end
	b:SetAttribute("Press", b:GetAttribute("Press") or "Squash")
	b:SetAttribute("Hover", b:GetAttribute("Hover") or "Pop")
	local shade = b:FindFirstChild("Shade")
	if shade and shade:IsA("GuiObject") then
		shade.Visible = false
	end
	local sel = b:FindFirstChild("Selected") or b:FindFirstChild("TabSelected")
	if sel and sel:IsA("GuiObject") then
		sel.BackgroundTransparency = 1
		sel.Size = UDim2.fromScale(1, 1)
		sel.Position = UDim2.fromScale(0, 0)
		sel.ZIndex = z + 6
		corner(sel, 0.2)
		local s = stroke(sel, "UIStroke", 0.09, WHITE, Enum.ApplyStrokeMode.Border)
		s.Transparency = 0
		for _, c in sel:GetChildren() do
			if c:IsA("GuiObject") then
				c.Visible = false
			end
		end
	end
end

local function field(box)
	box.BackgroundColor3 = hex("14141C")
	box.BackgroundTransparency = 0
	box.TextColor3 = WHITE
	box.PlaceholderColor3 = hex("8A8A99")
	box.FontFace = FONT
	box.TextScaled = true
	box.TextWrapped = true
	corner(box, 0.06)
	stroke(box, "UIStroke", 2, hex("3A3A48"), Enum.ApplyStrokeMode.Border).StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	local pad = child(box, "UIPadding", "UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
end

local function skin(gui)
	local root = gui.Root
	-- cadres droits (règle des coins) ; fenêtre sombre à contour encre
	root.BackgroundColor3 = hex("1F1F28")
	noCorner(root)
	stroke(root, "UIStroke", 4, INK, Enum.ApplyStrokeMode.Border).StrokeSizingMode = Enum.StrokeSizingMode.FixedSize

	-- bandeau rouge
	local header = root.Header
	header.BackgroundColor3 = WHITE
	local hg = child(header, "UIGradient", "UIGradient")
	hg.Color = ColorSequence.new(hex("FF5A5A"), hex("D61F1F"))
	hg.Rotation = 90
	noCorner(header)
	local crown = header.CrownIcon
	crown.BackgroundTransparency = 1
	crown.Image = Icons.ICON_Z4_Couronne.Texture
	crown.ScaleType = Enum.ScaleType.Fit
	crown.Size = UDim2.fromOffset(52, 52)
	crown.ZIndex = 4
	local title = header.Title
	for _, c in title:GetChildren() do
		if c:IsA("UITextSizeConstraint") then
			c.MaxTextSize = 44
		end
	end
	title.Size = UDim2.new(0.55, 0, 0, 44)
	text(title, "ADMIN PANEL", 4, Enum.TextXAlignment.Left)
	local badge = header.AdminBadge
	-- la pastille devient un bouton de la recette, sans action (Active = false)
	badge.BackgroundTransparency = 1
	local badgeBtn = child(badge, "Frame", "BadgeFace")
	badgeBtn.BackgroundTransparency = 1
	badgeBtn.Size = UDim2.fromScale(1, 1)
	badgeBtn.ZIndex = 3
	local lip = child(badge, "Frame", "Lip")
	lip.BackgroundColor3 = hex(P.blue.lip)
	lip.Size = UDim2.fromScale(1, 1)
	lip.ZIndex = 3
	corner(lip, 0.2)
	stroke(lip, "UIStroke", 0.07, INK, Enum.ApplyStrokeMode.Border)
	local face = child(badge, "Frame", "Face")
	face.BackgroundColor3 = WHITE
	face.Size = UDim2.fromScale(1, 0.86)
	face.ZIndex = 4
	corner(face, 0.2)
	local fg = child(face, "UIGradient", "UIGradient")
	fg.Color = ColorSequence.new(hex(P.blue.hi), hex(P.blue.base))
	fg.Rotation = 90
	badgeBtn:Destroy()
	text(badge.BadgeLabel, "ADMIN", 6)
	badge.BadgeLabel.Position = UDim2.fromScale(0.5, 0.43)
	badge.BadgeLabel.Size = UDim2.fromScale(0.8, 0.6)
	noCorner(badge)

	-- croix rose de la recette
	recipe(header.CloseButton, P.pink, "Label", "X")

	-- barre de la cible et panneau de contenu : droits, sombres
	local target = root.TargetSection
	target.BackgroundColor3 = hex("15151D")
	noCorner(target)
	target.TargetLabel.TextColor3 = WHITE
	text(target.TargetLabel, nil, target.TargetLabel.ZIndex, Enum.TextXAlignment.Left)
	local body = root.Body
	body.BackgroundColor3 = hex("15151D")
	noCorner(body)
	body.ScrollBarImageColor3 = hex("8E8E9C")

	-- onglets colorés, icône qui dépasse à gauche
	for name, t in TABS do
		local b = root.Tabs:FindFirstChild(name)
		if b then
			local tl = b.TabLabel
			recipe(b, P[t.pal], nil)
			tl.AnchorPoint = Vector2.new(0, 0.5)
			tl.Position = UDim2.new(0, 54, 0.43, 0)
			tl.Size = UDim2.new(1, -58, 0.5, 0)
			text(tl, nil, b.ZIndex + 5, Enum.TextXAlignment.Left)
			local icon = b.TabIcon
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, -4, 0.45, 0)
			icon.Size = UDim2.fromOffset(56, 56)
			icon.ScaleType = Enum.ScaleType.Fit
			icon.ZIndex = b.ZIndex + 6
			noCorner(icon)
			if t.icon then
				icon.Image = Icons[t.icon].Texture
			else
				icon.Image = ""
				local glyph = child(icon, "TextLabel", "Glyph")
				glyph.Size = UDim2.fromScale(0.8, 0.8)
				glyph.AnchorPoint = Vector2.new(0.5, 0.5)
				glyph.Position = UDim2.fromScale(0.5, 0.5)
				text(glyph, "!", b.ZIndex + 7)
			end
		end
	end
	-- l'icône dépasse à gauche du bouton : la colonne garde son découpage (elle défile sur téléphone) et décale les
	-- onglets de 10 px pour que l'icône reste dedans
	root.Tabs.ClipsDescendants = true
	local tp = child(root.Tabs, "UIPadding", "UIPadding")
	tp.PaddingLeft = UDim.new(0, 10)
	tp.PaddingTop = UDim.new(0, 8)
	tp.PaddingBottom = UDim.new(0, 8)
	for _, b in root.Tabs:GetChildren() do
		if b:IsA("TextButton") then
			b.Size = UDim2.new(1, -18, 0, 56)
		end
	end
	root.Body.StatsSection.SectionTitle.Text = "CASH AND SPEED" -- StrengthRow retiré

	-- sections : cartes droites, titres jaunes
	for _, sec in body:GetChildren() do
		if sec:IsA("Frame") and sec.Name:match("Section$") then
			sec.BackgroundColor3 = hex("1F1F2A")
			sec.BackgroundTransparency = 0
			noCorner(sec)
			local st = sec:FindFirstChild("SectionTitle")
			if st then
				text(st, nil, st.ZIndex, Enum.TextXAlignment.Left)
				st.TextColor3 = hex("FFD23F")
			end
		end
	end

	-- champs, boutons d'action, sortes, entrées des listes
	for _, d in root:GetDescendants() do
		if d:IsA("TextBox") then
			field(d)
		elseif d:IsA("GuiButton") and not d:IsDescendantOf(root.Tabs) and not d:IsDescendantOf(root.Header) then
			if d.Name == "Template" then
				recipe(d, P.grey, "EntryName")
			elseif d.Name:match("KindButton$") then
				recipe(d, P.blue, "Label")
			elseif d.Name == "ResetProfileButton" then
				recipe(d, P.pink, "Label")
			elseif not d.Name:match("^Entry_") then
				recipe(d, P.green, "Label")
			end
		end
	end
end

local gui = SG.UI_Admin
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_UI_Admin_v2") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_UI_Admin_v2"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Admin habillé (recette de bouton, bandeau rouge, onglets colorés)")
local ok, err = pcall(skin, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Admin habillé"
