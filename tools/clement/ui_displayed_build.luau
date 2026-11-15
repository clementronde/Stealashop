--!nonstrict
-- ui_displayed_build.luau (2026-11-15) : écran UI_Displayed, « On Display », d'après la maquette Figma validée par Clément
-- (page « 20 Index et Exposés », PC 106:1279, téléphone 106:2677), en carré, et sa réserve (L-192 Q3 : les objets
-- remplacés par « Display Best » y vont). Noms lus par DisplayedController (Contract/UI, L-192) et noms de la réserve
-- proposés dans Figma (note figma-refonte-coordination) :
--   UI_Displayed
--     Dock (décor : tout le panneau, calé à droite, Appear = SlideRight)
--       CloseButton (XLabel)
--       Panel
--         Header (HeaderLine, Title, DisplayCount : CountIcon, CountLabel « 3/8 »)
--         List (ScrollingFrame, Appear = Cascade) → Template : IconBack, Icon, ItemName, RarityChip.RarityLabel,
--           Income, RemoveButton.RemoveLabel
--         ScrollTrack (décor)
--         Reserve (caché par le code quand la réserve est vide) : ReserveTitle « IN RESERVE »,
--           ReserveCount.ReserveCountLabel, ReserveList (ScrollingFrame, Appear = Cascade) → Template : IconBack, Icon,
--           ItemName, Income, DisplayButton.DisplayLabel
--       DisplayBestButton (DisplayBestLabel)
-- Pas d'OpenButton : le panneau s'ouvre par UI_HUD.RightRail.DisplayedButton, donc le code allume et éteint l'écran entier.
-- Une seule mise en page pour PC et téléphone, celle du téléphone de Figma : 2 objets exposés et 1 en réserve visibles
-- sans coupe, le reste défile. Tout est en Scale dans Dock (rapport 405 × 323), qui prend 90 % de la hauteur, 474 px de
-- large au plus (la largeur du panneau PC de Figma). Boutons de 48 px de haut au téléphone (au moins 44 px à 667 × 335).
-- Attributs d'animation (L-182) : Dock Appear = SlideRight ; List et ReserveList Appear = Cascade ; CloseButton,
-- RemoveButton, DisplayButton et DisplayBestButton Hover = Pop, Press = Squash.
-- À lancer en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

assert(not SG:FindFirstChild("UI_Displayed"), "UI_Displayed existe déjà")

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("1b1b24")
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://3014551673"
local STUD_PX = 28
local DOCK_W, DOCK_H = 405, 323

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
-- Place o dans un parent de W × H (unités de la maquette téléphone).
local function rect(o, x, y, w, h, W, H)
	o.Position = UDim2.fromScale(x / W, y / H)
	o.Size = UDim2.fromScale(w / W, h / H)
	return o
end
local function frame(name, parent, color, transparency, z)
	return new("Frame", {
		Name = name, BackgroundColor3 = color or WHITE, BackgroundTransparency = transparency or 0, BorderSizePixel = 0, ZIndex = z or 1,
	}, parent)
end
local function grad(o, a, b)
	return new("UIGradient", { Color = ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b)), Rotation = 90 }, o)
end
local function border(o, px, W, H, inner)
	return new("UIStroke", {
		Thickness = px / math.min(W, H), Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Miter,
		BorderStrokePosition = if inner then Enum.BorderStrokePosition.Inner else Enum.BorderStrokePosition.Outer,
	}, o)
end
local function studs(o, transparency, W, H)
	return new("ImageLabel", {
		Name = "Studs", Image = STUDS, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Tile, Size = UDim2.fromScale(1, 1),
		ImageTransparency = transparency, TileSize = UDim2.fromScale(STUD_PX / W, STUD_PX / H), ZIndex = o.ZIndex,
	}, o)
end
-- Texte Montserrat Black à contour noir ; strokePx et h en unités de la maquette.
local function text(name, parent, str, color, strokePx, h, align, z)
	local t = new("TextLabel", {
		Name = name, Text = str, FontFace = HEAVY, TextScaled = true, TextWrapped = true, TextColor3 = color or WHITE,
		BackgroundTransparency = 1, TextXAlignment = align or Enum.TextXAlignment.Center, ZIndex = z or 3,
	}, parent)
	new("UIStroke", {
		Thickness = strokePx / h, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Round,
	}, t)
	return t
end
local function animated(o, appear)
	o:SetAttribute("Hover", "Pop")
	o:SetAttribute("Press", "Squash")
	if appear then
		o:SetAttribute("Appear", appear)
	end
end
-- Bouton carré à studs de 00 Briques : dégradé, studs, contour.
local function brick(name, parent, top, bottom, strokePx, W, H, inner)
	local b = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2,
	}, parent)
	grad(b, top, bottom)
	studs(b, 0.55, W, H)
	border(b, strokePx, W, H, inner)
	animated(b)
	return b
end
local function list(name, parent)
	local l = new("ScrollingFrame", {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 5, ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.45,
		VerticalScrollBarInset = Enum.ScrollBarInset.None, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 2,
	}, parent)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, l)
	l:SetAttribute("Appear", "Cascade")
	return l
end
-- Ligne de liste (W × H) : largeur en part de la liste, hauteur par son rapport (pas de Scale en Y dans un ScrollingFrame).
local function row(parent, listW, W, H)
	local r = frame("Template", parent, WHITE, 0, 2)
	r.Size = UDim2.new(W / listW, 0, 0, 10000)
	new("UIAspectRatioConstraint", { AspectRatio = W / H, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width }, r)
	grad(r, "4e5566", "383e4c")
	border(r, 2.5, W, H, true)
	r.Visible = false
	return r
end
local function iconBack(parent, x, y, s, W, H)
	local b = rect(frame("IconBack", parent, Color3.fromHex("d0d4db"), 0, 3), x, y, s, s, W, H) -- couleur de la rareté : posée par le code
	new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromHex("b4b4b4")), Rotation = 90 }, b)
	border(b, 2, s, s, true)
	return b
end
local function itemIcon(parent, x, y, s, W, H, image)
	return rect(new("ImageLabel", {
		Name = "Icon", Image = image, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 4,
	}, parent), x, y, s, s, W, H)
end

local rec = CHS:TryBeginRecording("UI : UI_Displayed (On Display) et sa réserve")
local ok, err = pcall(function()
	local gui = new("ScreenGui", {
		Name = "UI_Displayed", Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Dock : tout le panneau, à droite, centré en hauteur.
	local dock = new("Frame", {
		Name = "Dock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromScale(0.6, 0.9),
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = DOCK_W / DOCK_H, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width }, dock)
	new("UISizeConstraint", { MaxSize = Vector2.new(474, 10000) }, dock)
	dock:SetAttribute("Appear", "SlideRight")

	-- X rouge à gauche du panneau.
	local close = rect(brick("CloseButton", dock, "fb303e", "d00709", 3, 48, 48), 0, 0, 48, 48, DOCK_W, DOCK_H)
	close.Studs:Destroy()
	rect(text("XLabel", close, "X", WHITE, 5.5, 34), 7, 4, 34, 40, 48, 48)

	-- Panneau à studs, ombre franche dessous.
	local PW, PH = 354, 266
	rect(frame("PanelShadow", dock, INK, 0, 1), 51, 5, PW, PH, DOCK_W, DOCK_H)
	local panel = rect(frame("Panel", dock, Color3.fromHex("3a404b"), 0, 2), 51, 0, PW, PH, DOCK_W, DOCK_H)
	studs(panel, 0.8, PW, PH)
	border(panel, 3, PW, PH)

	local header = rect(frame("Header", panel, WHITE, 0, 3), 0, 0, PW, 46, PW, PH)
	grad(header, "ffb13b", "f26b0f")
	studs(header, 0.55, PW, 46)
	rect(frame("HeaderLine", header, INK, 0, 4), 0, 44, PW, 2, PW, 46)
	local title = rect(text("Title", header, "On Display", WHITE, 2, 27, Enum.TextXAlignment.Left, 5), 14, 8, 150, 30, PW, 46)
	new("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromHex("e3e9f2")), Rotation = 90 }, title)
	title:SetAttribute("Appear", "Stamp")
	local count = rect(frame("DisplayCount", header, INK, 0.45, 5), 243, 9, 104, 28, PW, 46)
	rect(new("ImageLabel", {
		Name = "CountIcon", Image = Icons.UI_Icon_Displays.Texture, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 6,
	}, count), -6, -4, 36, 36, 104, 28)
	rect(text("CountLabel", count, "3/8", WHITE, 2, 20, Enum.TextXAlignment.Center, 6), 36, 3, 62, 22, 104, 28)

	-- Objets exposés : 2 lignes de 60 visibles, le reste défile.
	local LW, LH = 342, 126
	local exposedList = rect(list("List", panel), 7, 52, LW, LH, PW, PH)
	local RW, RH = 333, 60
	local t = row(exposedList, LW, RW, RH)
	iconBack(t, 4, 4, 52, RW, RH)
	itemIcon(t, 3, -1, 54, RW, RH, "")
	rect(text("ItemName", t, "ITEM NAME", WHITE, 1.95, 16, Enum.TextXAlignment.Left), 62, 5, 188, 17, RW, RH)
	local chip = rect(frame("RarityChip", t, WHITE, 1, 3), 62, 23, 120, 14, RW, RH) -- fond invisible : la rareté se lit au texte
	rect(text("RarityLabel", chip, "COMMON", WHITE, 1.4, 11, Enum.TextXAlignment.Left, 4), 0, 0, 120, 14, 120, 14)
	rect(text("Income", t, "+$0/s", Color3.fromHex("7cff4f"), 1.95, 16, Enum.TextXAlignment.Left), 62, 39, 150, 17, RW, RH)
	local remove = rect(brick("RemoveButton", t, "ff6a5a", "d9201e", 2.5, 70, 48, true), 257, 6, 70, 48, RW, RH)
	remove.ZIndex = 4
	remove.Studs.ZIndex = 4
	rect(text("RemoveLabel", remove, "REMOVE", WHITE, 1.8, 15, Enum.TextXAlignment.Center, 5), 6, 15, 58, 18, 70, 48)
	rect(frame("ScrollTrack", panel, INK, 0.5, 2), 344, 56, 5, 118, PW, PH)

	-- Réserve : 1 ligne de 54 visible, le reste défile.
	local reserve = rect(frame("Reserve", panel, INK, 0.65, 3), 7, 184, 340, 78, PW, PH)
	border(reserve, 2, 340, 78)
	rect(text("ReserveTitle", reserve, "IN RESERVE", Color3.fromHex("ffd43b"), 1.8, 15, Enum.TextXAlignment.Left, 4), 6, 4, 92, 18, 340, 78)
	local rCount = rect(frame("ReserveCount", reserve, INK, 0.2, 4), 102, 5, 28, 16, 340, 78)
	rect(text("ReserveCountLabel", rCount, "0", WHITE, 1.6, 13, Enum.TextXAlignment.Center, 5), 2, 1, 24, 14, 28, 16)
	local reserveList = rect(list("ReserveList", reserve), 0, 24, 340, 54, 340, 78)
	local QW, QH = 329, 54
	local q = row(reserveList, 340, QW, QH)
	iconBack(q, 4, 4, 46, QW, QH)
	itemIcon(q, 3, 1, 48, QW, QH, "")
	rect(text("ItemName", q, "ITEM NAME", WHITE, 1.95, 16, Enum.TextXAlignment.Left), 56, 8, 180, 18, QW, QH)
	rect(text("Income", q, "+$0/s", Color3.fromHex("7cff4f"), 1.65, 13, Enum.TextXAlignment.Left), 56, 30, 120, 15, QW, QH)
	local display = rect(brick("DisplayButton", q, "91f630", "31dd22", 2.5, 78, 48, true), 247, 3, 78, 48, QW, QH)
	display.ZIndex = 4
	display.Studs.ZIndex = 4
	rect(text("DisplayLabel", display, "DISPLAY", WHITE, 2.2, 15, Enum.TextXAlignment.Center, 5), 7, 15, 64, 18, 78, 48)

	-- Gros bouton vert sous le panneau.
	local best = rect(brick("DisplayBestButton", dock, "91f630", "31dd22", 3, PW, 48), 51, 275, PW, 48, DOCK_W, DOCK_H)
	best.ZIndex = 3
	best.Studs.ZIndex = 3
	rect(text("DisplayBestLabel", best, "DISPLAY BEST", WHITE, 3.5, 27, Enum.TextXAlignment.Center, 4), 40, 9, 274, 30, PW, 48)

	gui.Parent = SG
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	local half = SG:FindFirstChild("UI_Displayed")
	if half then
		half:Destroy()
	end
	error(err)
end
return "UI_Displayed : construit"
