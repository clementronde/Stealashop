--!nonstrict
-- refonte_ui_hud_v3.luau (décision de Clément du 2026-11-15, L-192 Q1) : plus de bouton « More ».
--   - MenuButton (dans les deux colonnes), MenuAlert, MenuArea et MenuPanel sont retirés ;
--   - LeftRail (PC) et LeftRailTouch (téléphone) : 3 gros boutons avec leur nom, RobuxShopButton, IndexButton (+ IndexAlert,
--     un exemplaire par colonne) et SkillTreeButton ;
--   - TopLeftRow (nouveau cadre) : RewardsButton (+ RewardsAlert), InviteButton, SettingsButton en petites icônes carrées de
--     44 px, en haut à gauche dans la barre de Roblox, à côté de son menu (exception voulue à « rien en haut ») ; RebirthButton
--     (+ RebirthAlert) y est aussi, caché tant que la renaissance est coupée. Un seul exemplaire de chacun (Find.path).
--     TopLeftRow porte l'attribut FollowTopbarInset : le code peut le caler sur GuiService.TopbarInset (la place libre de la
--     barre de Roblox), sinon il reste à 120 px du bord gauche.
-- À lancer en Edit après refonte_ui_hud_v2.luau ; la version d'avant est rangée dans
-- ServerStorage/MapBackups/2026-11-15_RefonteUI/UI_HUD_v2. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local hud = SG.UI_HUD
assert(hud:FindFirstChild("MenuArea"), "UI_HUD est déjà en v3")

local MONT = "rbxasset://fonts/families/Montserrat.json"
local BLACK_FONT = Font.new(MONT, Enum.FontWeight.Heavy)
local INK = Color3.fromHex("1b1b24")
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://3014551673"
local STUD_PX = 28
local IMG_INDEX = "rbxassetid://90733951567919"

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
	o.Position = UDim2.fromScale(x / W, y / H)
	o.Size = UDim2.fromScale(w / W, h / H)
end
local function corner(o, scale)
	local c = o:FindFirstChildOfClass("UICorner") or new("UICorner", {}, o)
	c.CornerRadius = UDim.new(scale, 0)
end
local function border(o, scale)
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = scale
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
end
local function textStroke(o, scale)
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = scale
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
end
local function aspect(o, ar)
	local a = o:FindFirstChildOfClass("UIAspectRatioConstraint") or new("UIAspectRatioConstraint", {}, o)
	a.AspectRatio = ar
	a.AspectType = Enum.AspectType.FitWithinMaxSize
	a.DominantAxis = Enum.DominantAxis.Width
end
-- Brique de 00 Briques (comme refonte_ui_hud_v2.luau).
local function brick(name, parent, spec)
	local W, H, z = spec.W, spec.H, spec.z or 3
	local m = math.min(W, H)
	local b = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z, Size = UDim2.fromScale(1, 1),
	}, parent)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromHex(spec.top), Color3.fromHex(spec.bottom)), Rotation = 90 }, b)
	corner(b, spec.radius / m)
	border(b, spec.stroke / m)
	local shadow = new("Frame", {
		Name = "Shadow", Position = UDim2.fromScale(0, spec.shadow / H), Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0,
		ZIndex = z - 1,
	}, b)
	corner(shadow, spec.radius / m)
	local studs = new("ImageLabel", {
		Name = "Studs", Image = STUDS, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageTransparency = 0.6, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(STUD_PX / W, STUD_PX / H), ZIndex = z + 1,
	}, b)
	corner(studs, spec.radius / m)
	local shine = new("Frame", { Name = "Shine", BackgroundColor3 = WHITE, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = z + 2 }, b)
	rect(shine, 4, 4, W - 8, spec.shineH, W, H)
	corner(shine, 0.4)
	local i = spec.icon
	local icon = new("ImageLabel", { Name = "Icon", Image = i[1], BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = z + 3 }, b)
	rect(icon, i[2], i[3], i[4], i[5], W, H)
	if spec.label then
		local t = spec.label
		local l = new("TextLabel", {
			Name = "Label", Text = t.text, BackgroundTransparency = 1, FontFace = BLACK_FONT, TextColor3 = WHITE, TextScaled = true, TextWrapped = true,
			ZIndex = z + 4, TextXAlignment = t.align or Enum.TextXAlignment.Center,
		}, b)
		rect(l, t.x, t.y, t.w, t.h, W, H)
		textStroke(l, t.stroke / t.h)
	end
	b:SetAttribute("Hover", "Pop")
	b:SetAttribute("Press", "Squash")
	return b
end
local function placeAlert(alert, parent, cx, cy, d, W, H)
	alert.Parent = parent
	alert.AnchorPoint = Vector2.new(0.5, 0.5)
	alert.Position = UDim2.fromScale(cx / W, cy / H)
	alert.Size = UDim2.fromScale(d / W, d / H)
	alert.ZIndex = 20
	alert.Visible = false
	local al = alert:FindFirstChild("AlertLabel")
	if al then
		al.ZIndex = 21
	end
end

local rec = CHS:TryBeginRecording("Refonte UI : UI_HUD v3, plus de bouton More")
local ok, err = pcall(function()
	local folder = SS.MapBackups["2026-11-15_RefonteUI"]
	if not folder:FindFirstChild("UI_HUD_v2") then
		local v2 = hud:Clone()
		v2.Name = "UI_HUD_v2"
		v2.Enabled = false
		v2.Parent = folder
	end

	-- Boutons du panneau More, gardés ; le panneau et les boutons More partent.
	local buttons = hud.MenuArea.MenuPanel.Buttons
	local rewards, invite, settings, rebirth, index = buttons.RewardsButton, buttons.InviteButton, buttons.SettingsButton, buttons.RebirthButton, buttons.IndexButton
	local indexAlert = index:FindFirstChild("IndexAlert")
	for _, b in { rewards, invite, settings, rebirth } do
		b.Parent = nil
	end
	indexAlert.Parent = nil
	hud.MenuArea:Destroy()
	for _, railName in { "LeftRail", "LeftRailTouch" } do
		hud[railName].MenuButton:Destroy()
	end

	-- IndexButton en gros bouton dans chaque colonne, entre Shop et Upgrades.
	local pcIndex = brick("IndexButton", hud.LeftRail, {
		W = 220, H = 70, radius = 16, stroke = 5, shadow = 6, shineH = 28, top = "6cc2ff", bottom = "2d6fe0",
		icon = { IMG_INDEX, 1, -6, 77, 77 },
		label = { text = "Index", x = 102, y = 20, w = 110, h = 30, stroke = 4, align = Enum.TextXAlignment.Left },
	})
	pcIndex.LayoutOrder = 2
	pcIndex.Size = UDim2.fromScale(1, 70 / 242)
	aspect(pcIndex, 220 / 70)
	hud.LeftRail.SkillTreeButton.LayoutOrder = 3
	placeAlert(indexAlert:Clone(), pcIndex, 213, 5, 34, 220, 70)
	local touchIndex = brick("IndexButton", hud.LeftRailTouch, {
		W = 56, H = 56, radius = 9, stroke = 3, shadow = 4, shineH = 22, top = "6cc2ff", bottom = "2d6fe0",
		icon = { IMG_INDEX, 8, 2, 39, 39 }, label = { text = "Index", x = 1, y = 40, w = 54, h = 13, stroke = 2 },
	})
	touchIndex.LayoutOrder = 2
	touchIndex.Size = UDim2.fromScale(1, 56 / 184)
	aspect(touchIndex, 1)
	hud.LeftRailTouch.SkillTreeButton.LayoutOrder = 3
	placeAlert(indexAlert, touchIndex, 53, 3, 22, 56, 56)

	-- Petites icônes carrées dans la barre de Roblox, à côté de son menu.
	local row = new("Frame", {
		Name = "TopLeftRow", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 120, 0, -51), Size = UDim2.fromOffset(4 * 44 + 3 * 8, 44),
		BackgroundTransparency = 1,
	}, hud)
	row:SetAttribute("FollowTopbarInset", true)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)
	local small = {
		{ rewards, 1, "ff94d6", "e0459b", "RewardsAlert" }, { invite, 2, "6beaff", "1ea0e0" }, { settings, 3, "d3d8e2", "8a93a3" },
		{ rebirth, 4, "d88bff", "8e3be0", "RebirthAlert" },
	}
	for _, s in small do
		local old, order, top, bottom, alertName = s[1], s[2], s[3], s[4], s[5]
		local image = old.Icon.Image
		local alert = if alertName then old:FindFirstChild(alertName) else nil
		if alert then
			alert.Parent = nil
		end
		local b = brick(old.Name, row, {
			W = 44, H = 44, radius = 9, stroke = 3, shadow = 3, shineH = 16, top = top, bottom = bottom, icon = { image, 5, 4, 34, 34 },
		})
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(44, 44)
		if alert then
			placeAlert(alert, b, 40, 4, 20, 44, 44)
		end
		if old.Name == "RebirthButton" then
			b.Visible = false -- renaissance coupée (L-173) : le code la montre quand elle revient
		end
		old:Destroy()
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HUD v3 : plus de bouton More"
