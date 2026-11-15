--!nonstrict
-- refonte_ui_hud_v2.luau (2026-11-15) : UI_HUD construit d'après la page Figma « 30 HUD, tapis, poursuite », validée
-- par Clément (fichier fXjkvf39sRhlsL94YicwDH, état 1 · 106:557 et noms · 106:10614 ; liaison L-182 et L-183).
-- À lancer en Edit, après refonte_ui_hud.luau (v1) ; l'original est déjà dans
-- ServerStorage/MapBackups/2026-11-15_RefonteUI/UI_HUD, la v1 y est rangée en UI_HUD_v1. Annulable. Aucun script.
--
-- Ce qui est construit (mesures de la maquette PC 1920 × 1080 et téléphone 844 × 390) :
--   - LeftRail (PC) et LeftRailTouch (téléphone) : RobuxShopButton, SkillTreeButton, MenuButton (+ MenuAlert) ;
--   - MenuArea.MenuPanel (caché, un seul) : IndexButton, RebirthButton, RewardsButton, InviteButton, SettingsButton,
--     déplacés avec leurs pastilles ; MenuArea est un carré de la hauteur de l'écran, pour que le panneau tombe à
--     côté des boutons sur PC comme sur téléphone ; SocialRow disparaît ;
--   - RightRail : DisplayedButton, SpeedBoostButton et SleepButton (cachés, + Label, Price.Amount ; Sleep : Hint,
--     Cooldown) ;
--   - BottomLeft : BottomRow (FriendBoost, VipBoost, CashBoost, TrainingBoost en pastilles) au-dessus de StatsPanel ;
--     CashSpent (rouge, caché) au-dessus d'Income ;
--   - NightCountdown en bas à droite ; HeistTimer (+ Box) en haut au centre, sous le bandeau RUN! (demande de Clément),
--     GuardMeter dessous ; DropButton (caché) en bas au centre. NightCountdown porte PhonePosition et PhoneAnchorPoint :
--     sa place sur téléphone dans la maquette (le code doit l'appliquer, L-189) ;
--   - attributs d'animation de L-182 : Hover = Pop et Press = Squash sur chaque bouton, Appear = Pop sur MenuPanel,
--     Appear = SlideRight sur SpeedBoostButton et SleepButton.
-- Gardés : Cash, Income, Speed, Strength, Damage, HeistTimer.Box (UIGradient, PoliceGradient), GuardMeter.Fill,
-- CashFly, RevealTint, AdminButton. Retirés : InventoryButton, InventoryAlert (inventaire archivé, L-182 point 5).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local hud = SG.UI_HUD
assert(not hud:FindFirstChild("RightRail"), "UI_HUD est déjà en v2")

local MONT = "rbxasset://fonts/families/Montserrat.json"
local BLACK_FONT = Font.new(MONT, Enum.FontWeight.Heavy)
local ITALIC_FONT = Font.new(MONT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local INK = Color3.fromHex("1b1b24") -- contour des briques
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://3014551673"
local STUD_PX = 28 -- taille d'un stud dans la maquette PC

-- Images : celles de Clément (importées le 2026-11-15) quand elles existent, sinon les images actuelles.
local IMG = {
	Shop = "rbxassetid://100238404671866",
	SkillTree = "rbxassetid://94595191807390", -- UI_Icon_Upgrades (Clément, 2026-11-15)
	Index = "rbxassetid://90733951567919",
	Rebirth = "rbxassetid://79628492433715",
	Gift = "rbxassetid://93299345687418",
	Invite = "rbxassetid://102094661385258",
	Settings = "rbxassetid://96039690137195",
	Displays = "rbxassetid://122667151083826", -- UI_Icon_Displays
	SpeedBoost = "rbxassetid://114903617420676", -- UI_Icon_SpeedBoost
	Training2x = "rbxassetid://106315635775683", -- pass ×2 Training (TrainingBoost)
	Sleep = "rbxassetid://81902433249804", -- UI_Icon_Sleep
	Moon = "rbxassetid://107090509896098",
	Robux = "rbxassetid://139320447847280",
	Vip = "rbxassetid://71854395817195",
	Cash2x = "rbxassetid://90748953656553",
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
local function grad(o, a, b, rot)
	local g = o:FindFirstChild("UIGradient") or new("UIGradient", {}, o)
	g.Color = ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b))
	g.Rotation = rot or 90
	return g
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
	return s
end
local function textStroke(o, scale)
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = scale
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end
local function aspect(o, ar)
	local a = o:FindFirstChildOfClass("UIAspectRatioConstraint") or new("UIAspectRatioConstraint", {}, o)
	a.AspectRatio = ar
	a.AspectType = Enum.AspectType.FitWithinMaxSize
	a.DominantAxis = Enum.DominantAxis.Width
end
local function minSize(o, v)
	local c = o:FindFirstChildOfClass("UISizeConstraint") or new("UISizeConstraint", {}, o)
	c.MinSize = v
end
-- Rectangle de la maquette (px, relatif au parent de W × H) en Scale.
local function rect(o, x, y, w, h, W, H)
	o.Position = UDim2.fromScale(x / W, y / H)
	o.Size = UDim2.fromScale(w / W, h / H)
end
local function label(name, text, parent, props)
	local l = new("TextLabel", {
		Name = name, Text = text, BackgroundTransparency = 1, FontFace = BLACK_FONT, TextColor3 = WHITE, TextScaled = true,
		TextWrapped = true,
	}, parent)
	for k, v in props or {} do
		l[k] = v
	end
	return l
end
local function animated(b, appear)
	b:SetAttribute("Hover", "Pop")
	b:SetAttribute("Press", "Squash")
	if appear then
		b:SetAttribute("Appear", appear)
	end
end

-- Bouton des briques (maquette : W × H px) : dégradé, studs, reflet, contour, ombre dure, icône et texte.
-- spec : W, H, top, bottom, radius, stroke, shadow, z, icon = { image, x, y, w, h }, label = { text, x, y, w, h, stroke,
-- align, color, italic }, class (TextButton par défaut).
local function brick(name, parent, spec)
	local W, H, z = spec.W, spec.H, spec.z or 3
	local m = math.min(W, H)
	local b = new(spec.class or "TextButton", {
		Name = name, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z, Size = UDim2.fromScale(1, 1),
	}, parent)
	if b:IsA("TextButton") then
		b.Text = ""
		b.AutoButtonColor = false
	end
	if spec.top then
		grad(b, spec.top, spec.bottom, 90)
	end
	corner(b, spec.radius / m)
	border(b, spec.stroke / m)
	local shadow = new("Frame", {
		Name = "Shadow", Position = UDim2.fromScale(0, spec.shadow / H), Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK,
		BorderSizePixel = 0, ZIndex = z - 1,
	}, b)
	corner(shadow, spec.radius / m)
	if spec.top then
		local studs = new("ImageLabel", {
			Name = "Studs", Image = STUDS, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageTransparency = 0.6,
			ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromScale(STUD_PX / W, STUD_PX / H), ZIndex = z + 1,
		}, b)
		corner(studs, spec.radius / m)
		local shineH = spec.shineH or math.floor(H * 0.4)
		local shine = new("Frame", {
			Name = "Shine", BackgroundColor3 = WHITE, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = z + 2,
		}, b)
		rect(shine, 5, 5, W - 10, shineH, W, H)
		corner(shine, 0.4)
	end
	if spec.icon then
		local i = spec.icon
		local icon = new("ImageLabel", {
			Name = "Icon", Image = i[1], BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = z + 3,
		}, b)
		rect(icon, i[2], i[3], i[4], i[5], W, H)
	end
	if spec.label then
		local t = spec.label
		local l = label("Label", t.text, b, {
			FontFace = if t.italic then ITALIC_FONT else BLACK_FONT, TextColor3 = t.color or WHITE, ZIndex = z + 4,
			TextXAlignment = t.align or Enum.TextXAlignment.Center,
		})
		rect(l, t.x, t.y, t.w, t.h, W, H)
		textStroke(l, t.stroke / t.h)
	end
	return b
end

-- Pastille rouge « ! » (gardée si elle existe : son Pulse est au contrat).
local function placeAlert(alert, parent, cx, cy, d, W, H)
	alert.Parent = parent
	alert.AnchorPoint = Vector2.new(0.5, 0.5)
	alert.Position = UDim2.fromScale(cx / W, cy / H)
	alert.Size = UDim2.fromScale(d / W, d / H)
	alert.ZIndex = 20
	alert.Visible = false
	aspect(alert, 1)
	grad(alert, "ff5a5a", "e0101f", 90)
	corner(alert, 0.5)
	border(alert, 0.1)
	local al = alert:FindFirstChild("AlertLabel")
	if al then
		al.ZIndex = 21
		al.FontFace = BLACK_FONT
		textStroke(al, 0.11)
	end
end

local rec = CHS:TryBeginRecording("Refonte UI : UI_HUD v2 d'après Figma")
local ok, err = pcall(function()
	local folder = SS.MapBackups["2026-11-15_RefonteUI"]
	if not folder:FindFirstChild("UI_HUD_v1") then
		local v1 = hud:Clone()
		v1.Name = "UI_HUD_v1"
		v1.Enabled = false
		v1:SetAttribute("AncienEmplacement", "StarterGui.UI_HUD")
		v1.Parent = folder
	end
	local inventory = SG:FindFirstChild("UI_Inventory")
	if inventory then
		inventory:SetAttribute("AncienEmplacement", "StarterGui.UI_Inventory")
		inventory.Parent = folder -- archivé (L-182 point 5), pas supprimé
	end

	-- Pastilles à garder avant de démonter l'ancien HUD.
	local function take(path)
		local x = hud:FindFirstChild(path, true)
		return x
	end
	local alertSkillPC = hud.LeftRail.SkillTreeButton:FindFirstChild("SkillTreeAlert")
	local alertSkillTouch = hud.LeftRailTouch.SkillTreeButton:FindFirstChild("SkillTreeAlert")
	local alertIndex = hud.LeftRail.IndexButton:FindFirstChild("IndexAlert")
	local alertRebirth = hud.LeftRail.RebirthButton:FindFirstChild("RebirthAlert")
	local alertRewards = take("RewardsAlert")
	for _, a in { alertSkillPC, alertSkillTouch, alertIndex, alertRebirth, alertRewards } do
		a.Parent = nil
	end
	local function menuAlert()
		local m = alertRewards:Clone()
		m.Name = "MenuAlert"
		return m
	end

	-- Démontage : colonnes, SocialRow, rangée v1.
	for _, rail in { hud.LeftRail, hud.LeftRailTouch } do
		for _, c in rail:GetChildren() do
			c:Destroy()
		end
	end
	hud.SocialRow:Destroy()
	hud.BottomLeft.BottomRow:Destroy()

	-- 1. Colonne de gauche, PC : 3 boutons de 220 × 70, 16 px entre deux, centrée à 46 % de la hauteur.
	local rail = hud.LeftRail
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.fromScale(0.0198, 0.463)
	rail.Size = UDim2.fromScale(0.1146, 0.237)
	rail.BackgroundTransparency = 1
	aspect(rail, 220 / 242)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(16 / 242, 0),
	}, rail)
	local railSpec = { W = 220, H = 70, radius = 16, stroke = 5, shadow = 6, shineH = 28 }
	local function railButton(name, order, top, bottom, icon, text, textSize, textX)
		local s = table.clone(railSpec)
		s.top, s.bottom = top, bottom
		s.icon = icon
		s.label = { text = text, x = textX, y = (70 - textSize) / 2, w = 220 - textX - 8, h = textSize, stroke = textSize * 0.133,
			align = Enum.TextXAlignment.Left }
		local b = brick(name, rail, s)
		b.LayoutOrder = order
		b.Size = UDim2.fromScale(1, 70 / 242)
		aspect(b, 220 / 70)
		animated(b)
		return b
	end
	railButton("RobuxShopButton", 1, "8cf54a", "35c21f", { IMG.Shop, 1, -6, 77, 77 }, "Shop", 30, 102)
	local skillPC = railButton("SkillTreeButton", 2, "ff7a6b", "e0313f", { IMG.SkillTree, 1, -6, 77, 77 }, "Upgrades", 25, 78)
	local menuPC = railButton("MenuButton", 3, "7a859e", "3a404b", nil, "More", 30, 104)
	placeAlert(alertSkillPC, skillPC, 213, 5, 34, 220, 70)
	placeAlert(menuAlert(), menuPC, 213, 5, 34, 220, 70)

	-- Icône « menu » : 3 barres blanches cerclées (comme la maquette).
	local function burger(button, x, y, size, W, H)
		local icon = new("Frame", { Name = "Icon", BackgroundTransparency = 1, ZIndex = button.ZIndex + 3 }, button)
		rect(icon, x, y, size, size, W, H)
		for k = 0, 2 do
			local bar = new("Frame", {
				Name = "Bar", BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = button.ZIndex + 3,
				Position = UDim2.fromScale(0.125, 0.12 + k * 0.3), Size = UDim2.fromScale(0.75, 0.16),
			}, icon)
			corner(bar, 0.5)
			border(bar, 0.3)
		end
	end
	burger(menuPC, 14, 13, 44, 220, 70)

	-- 2. Colonne de gauche, téléphone : 3 boutons de 56 × 56, 8 px entre deux, juste sous la barre de Roblox.
	local touch = hud.LeftRailTouch
	touch.AnchorPoint = Vector2.new(0, 0)
	touch.Position = UDim2.fromScale(0.019, 0.012)
	touch.Size = UDim2.fromScale(0.066, 0.554)
	touch.BackgroundTransparency = 1
	aspect(touch, 56 / 184)
	local old = touch:FindFirstChildOfClass("UISizeConstraint")
	if old then
		old:Destroy()
	end
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(8 / 184, 0),
	}, touch)
	local function touchButton(name, order, top, bottom, icon, text)
		local b = brick(name, touch, {
			W = 56, H = 56, radius = 9, stroke = 3, shadow = 4, shineH = 22, top = top, bottom = bottom, icon = icon,
			label = { text = text, x = 1, y = 40, w = 54, h = 13, stroke = 2 }, -- 10 px au moins en 667 × 375
		})
		b.LayoutOrder = order
		b.Size = UDim2.fromScale(1, 56 / 184)
		aspect(b, 1)
		animated(b)
		return b
	end
	touchButton("RobuxShopButton", 1, "8cf54a", "35c21f", { IMG.Shop, 8, 2, 39, 39 }, "Shop")
	local skillTouch = touchButton("SkillTreeButton", 2, "ff7a6b", "e0313f", { IMG.SkillTree, 8, 2, 39, 39 }, "Upgrades")
	local menuTouch = touchButton("MenuButton", 3, "7a859e", "3a404b", nil, "More")
	burger(menuTouch, 13, 6, 30, 56, 56)
	placeAlert(alertSkillTouch, skillTouch, 53, 3, 22, 56, 56)
	placeAlert(menuAlert(), menuTouch, 53, 3, 22, 56, 56)

	-- 3. Panneau « More » (un seul, caché) dans MenuArea, un carré de la hauteur de l'écran : il s'ouvre à droite des
	-- boutons, son bas aligné sur celui de More (PC : x 266, 376 × 262 ; téléphone : x 86, 201 × 140).
	local area = new("Frame", {
		Name = "MenuArea", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1,
	}, hud)
	new("UIAspectRatioConstraint", { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Height }, area)
	local panel = new("Frame", {
		Name = "MenuPanel", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.26, 0.575), Size = UDim2.fromScale(1, 0.256),
		BackgroundColor3 = Color3.fromHex("3a404b"), BorderSizePixel = 0, ZIndex = 30, Visible = false,
	}, area)
	minSize(panel, Vector2.new(201, 140))
	aspect(panel, 376 / 262)
	panel.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	corner(panel, 22 / 262)
	border(panel, 5 / 262)
	panel:SetAttribute("Appear", "Pop")
	local panelShadow = new("Frame", {
		Name = "Shadow", Position = UDim2.fromScale(0, 8 / 262), Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0,
		ZIndex = 29,
	}, panel)
	corner(panelShadow, 22 / 262)
	-- Les boutons dans un cadre à part : sinon l'ombre compte comme une case de la grille.
	local grid = new("Frame", { Name = "Buttons", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 31 }, panel)
	new("UIPadding", {
		PaddingLeft = UDim.new(18 / 376, 0), PaddingRight = UDim.new(18 / 376, 0), PaddingTop = UDim.new(18 / 262, 0),
		PaddingBottom = UDim.new(18 / 262, 0),
	}, grid)
	new("UIGridLayout", {
		CellSize = UDim2.fromScale(104 / 340, 104 / 226), CellPadding = UDim2.fromScale(14 / 340, 18 / 226),
		SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 3,
	}, grid)
	local function menuItem(name, order, top, bottom, image, text)
		local b = brick(name, grid, {
			W = 104, H = 104, radius = 17, stroke = 5, shadow = 6, shineH = 42, z = 33, top = top, bottom = bottom,
			icon = { image, 16, 4, 73, 73 }, label = { text = text, x = 4, y = 76, w = 96, h = 20, stroke = 2.6 },
		})
		b.LayoutOrder = order
		animated(b)
		return b
	end
	local index = menuItem("IndexButton", 1, "6cc2ff", "2d6fe0", IMG.Index, "Index")
	local rebirth = menuItem("RebirthButton", 2, "d88bff", "8e3be0", IMG.Rebirth, "Rebirth")
	local rewards = menuItem("RewardsButton", 3, "ff94d6", "e0459b", IMG.Gift, "Rewards")
	menuItem("InviteButton", 4, "6beaff", "1ea0e0", IMG.Invite, "Invite")
	menuItem("SettingsButton", 5, "d3d8e2", "8a93a3", IMG.Settings, "Settings")
	placeAlert(alertIndex, index, 96, 6, 32, 104, 104)
	placeAlert(alertRebirth, rebirth, 96, 6, 32, 104, 104)
	placeAlert(alertRewards, rewards, 96, 6, 32, 104, 104)
	for _, a in { alertIndex, alertRebirth, alertRewards } do
		a.ZIndex = 40
		a.AlertLabel.ZIndex = 41
	end

	-- 4. Rail de droite : « Mes objets exposés » et les boutons en situation (PC 270 × 260 ; téléphone 145 × 140).
	local right = new("Frame", {
		Name = "RightRail", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(0.98, 0.56), Size = UDim2.fromScale(0.5, 0.254),
		BackgroundTransparency = 1,
	}, hud)
	minSize(right, Vector2.new(150, 140))
	aspect(right, 270 / 260)
	right.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	local displayed = brick("DisplayedButton", right, {
		W = 112, H = 112, radius = 18, stroke = 6, shadow = 7, shineH = 45, top = "ffe36b", bottom = "f29a0c",
		icon = { IMG.Displays, 17, 4, 78, 78 }, label = { text = "Displays", x = 4, y = 82, w = 104, h = 21, stroke = 3 },
	})
	displayed.AnchorPoint = Vector2.new(1, 0)
	displayed.Position = UDim2.fromScale(1, 0)
	displayed.Size = UDim2.fromScale(112 / 270, 112 / 260)
	aspect(displayed, 1)
	animated(displayed)

	local function situational(name, top, bottom)
		local b = brick(name, right, { W = 270, H = 96, radius = 16, stroke = 5, shadow = 6, shineH = 38, top = top, bottom = bottom })
		b.Position = UDim2.fromScale(0, 136 / 260)
		b.Size = UDim2.fromScale(1, 96 / 260)
		aspect(b, 270 / 96)
		b.Visible = false
		animated(b, "SlideRight")
		return b
	end
	local function price(button, x, y, w, h, W, H)
		local p = new("Frame", { Name = "Price", BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = button.ZIndex + 5 }, button)
		rect(p, x, y, w, h, W, H)
		grad(p, "c77dff", "8a1fe0", 90)
		corner(p, 0.5)
		border(p, 3 / h)
		local ri = new("ImageLabel", {
			Name = "RobuxIcon", Image = IMG.Robux, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = p.ZIndex + 1,
		}, p)
		rect(ri, 4, 4, h - 8, h - 8, w, h)
		local amount = label("Amount", "R$ ?", p, { ZIndex = p.ZIndex + 1, TextXAlignment = Enum.TextXAlignment.Left })
		rect(amount, h - 2, h * 0.22, w - h - 2, h * 0.56, w, h)
		textStroke(amount, 0.12)
		return p
	end

	-- x2 SPEED (sur un tapis) : arc-en-ciel.
	local speed = situational("SpeedBoostButton", "ff4d6d", "a66bff")
	speed.UIGradient.Rotation = 0
	speed.UIGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("ff4d6d")), ColorSequenceKeypoint.new(0.2, Color3.fromHex("ffb443")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("fff15a")), ColorSequenceKeypoint.new(0.6, Color3.fromHex("5bea6b")),
		ColorSequenceKeypoint.new(0.8, Color3.fromHex("4fc3ff")), ColorSequenceKeypoint.new(1, Color3.fromHex("a66bff")),
	})
	local si = new("ImageLabel", { Name = "Icon", Image = IMG.SpeedBoost, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 6 }, speed)
	rect(si, 2, -6, 101, 101, 270, 96)
	local sl = label("Label", "x2 SPEED", speed, { ZIndex = 7, TextXAlignment = Enum.TextXAlignment.Left })
	rect(sl, 83, 17, 180, 34, 270, 96)
	textStroke(sl, 4 / 34)
	price(speed, 118, 56, 83, 32, 270, 96)

	-- zZz (dans le couloir) : violet nuit ; Cooldown = temps qui reste (caché), à la place du texte.
	local sleep = situational("SleepButton", "8a97ff", "3b2db5")
	local zi = new("ImageLabel", { Name = "Icon", Image = IMG.Sleep, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 6 }, sleep)
	rect(zi, 8, -1, 91, 91, 270, 96)
	local zl = label("Label", "zZz", sleep, { ZIndex = 7 })
	rect(zl, 100, 4, 140, 48, 270, 96)
	textStroke(zl, 5 / 48)
	local hint = label("Hint", "Guards sleep 60s", sleep, { ZIndex = 7, TextColor3 = Color3.fromHex("e6e9ff") })
	rect(hint, 89, 56, 170, 20, 270, 96)
	textStroke(hint, 3 / 20)
	local cd = label("Cooldown", "0:58", sleep, { ZIndex = 8, Visible = false })
	rect(cd, 100, 4, 140, 48, 270, 96)
	textStroke(cd, 5 / 48)
	price(sleep, 96, -22, 78, 30, 270, 96)

	-- 5. Bas à gauche : bonus en pastilles au-dessus des chiffres ; l'argent reste tout en bas.
	local bottomLeft = hud.BottomLeft
	bottomLeft.AnchorPoint = Vector2.new(0, 1)
	bottomLeft.Position = UDim2.fromScale(0.0198, 0.9726)
	bottomLeft.Size = UDim2.fromScale(0.32, 0.3)
	bottomLeft.UIListLayout.Padding = UDim.new(12 / 307, 0)
	local row = new("Frame", { Name = "BottomRow", BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.fromScale(1, 40 / 307) }, bottomLeft)
	minSize(row, Vector2.new(0, 22))
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)
	for k, b in { { "FriendBoost", IMG.Invite, "+0%", true }, { "VipBoost", IMG.Vip, "+10%", false }, { "CashBoost", IMG.Cash2x, "x2", false },
		{ "TrainingBoost", IMG.Training2x, "x2", false } } do
		local pill = new("Frame", {
			Name = b[1], LayoutOrder = k, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("12151b"), BackgroundTransparency = 0.3,
			BorderSizePixel = 0, Visible = b[4], ZIndex = 2,
		}, row)
		aspect(pill, 96 / 40)
		pill.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
		corner(pill, 0.5)
		border(pill, 3 / 40)
		local icon = new("ImageLabel", { Name = "Icon", Image = b[2], BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 }, pill)
		rect(icon, 4, 2, 36, 36, 96, 40)
		local amount = label("Amount", b[3], pill, { ZIndex = 4, TextXAlignment = Enum.TextXAlignment.Left })
		rect(amount, 44, 10, 48, 20, 96, 40)
		textStroke(amount, 3 / 20)
	end

	local stats = bottomLeft.StatsPanel
	stats.LayoutOrder = 2
	stats.Size = UDim2.fromScale(1, 174 / 307)
	minSize(stats, Vector2.new(200, 76))
	stats.UIListLayout.Padding = UDim.new(6 / 174, 0)
	stats.StrengthDamageRow.Size = UDim2.fromScale(1, 38 / 174)
	stats.SpeedRow.Size = UDim2.fromScale(1, 54 / 174)
	stats.CashRow.Size = UDim2.fromScale(1, 70 / 174)
	stats.CashRow.CashIcon.Size = UDim2.fromScale(1, 66 / 70)
	for name, g in {
		Strength = { "ffe08a", "ff9a1f", 30 / 38, 0.133 }, Damage = { "ffe08a", "ff9a1f", 30 / 38, 0.133 },
		Speed = { "ffa3e2", "c04bff", 44 / 54, 0.114 }, Cash = { "e2ff6b", "2fcb1f", 58 / 70, 0.103 },
	} do
		local t = stats:FindFirstChild(name, true)
		t.FontFace = ITALIC_FONT
		t.TextColor3 = WHITE
		t.Size = UDim2.fromScale(t.Size.X.Scale, g[3])
		grad(t, g[1], g[2], 90)
		textStroke(t, g[4])
	end
	stats.CashRow.Cash.Size = UDim2.fromScale(0.34, 58 / 70) -- Income juste après l'argent, comme la maquette
	local income = stats.CashRow.Income
	income.FontFace = ITALIC_FONT
	income.Size = UDim2.fromScale(income.Size.X.Scale, 28 / 70)
	textStroke(income, 0.143)
	local spent = label("CashSpent", "-$3.0B", income, {
		FontFace = ITALIC_FONT, TextColor3 = Color3.fromHex("ff3b3b"), TextXAlignment = Enum.TextXAlignment.Left, Visible = false,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, -0.214), Size = UDim2.fromScale(0.96, 1.214), ZIndex = income.ZIndex + 1,
	})
	textStroke(spent, 0.147)

	-- 6. Bas à droite : nuit (432 × 60), chrono (322 × 74) au-dessus, jauge des vigiles (cachée) au-dessus.
	local night = hud.NightCountdown
	for _, c in night:GetChildren() do
		if c.Name ~= "Band" and c.Name ~= "MoonIcon" then
			c:Destroy()
		end
	end
	night.AnchorPoint = Vector2.new(1, 1)
	night.Position = UDim2.fromScale(0.98, 0.9726)
	night.Size = UDim2.fromScale(0.5, 60 / 1022)
	night.FontFace = ITALIC_FONT
	night.TextColor3 = WHITE
	night.TextScaled = true
	night.TextWrapped = true
	night.TextXAlignment = Enum.TextXAlignment.Left
	night.BackgroundTransparency = 1
	night.ZIndex = 6
	aspect(night, 432 / 60)
	night.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	minSize(night, Vector2.new(212, 30))
	new("UIPadding", {
		PaddingLeft = UDim.new(72 / 432, 0), PaddingRight = UDim.new(0.04, 0), PaddingTop = UDim.new(14 / 60, 0), PaddingBottom = UDim.new(14 / 60, 0),
	}, night)
	textStroke(night, 4 / 32)
	local band = night.Band
	band.Position = UDim2.new(-72 / 432 / (1 - 72 / 432 - 0.04), 0, -14 / 32, 0)
	band.Size = UDim2.fromScale(1 / (1 - 72 / 432 - 0.04), 60 / 32)
	band.BackgroundColor3 = Color3.fromHex("12151b")
	band.BackgroundTransparency = 0.18
	band.BorderSizePixel = 0
	band.ZIndex = 4
	for _, c in band:GetChildren() do
		c:Destroy()
	end
	corner(band, 16 / 60)
	border(band, 3 / 60)
	local moon = night.MoonIcon
	moon.AnchorPoint = Vector2.new(0, 0.5)
	moon.Position = UDim2.new(-64 / 432 / (1 - 72 / 432 - 0.04), 0, 0.5, 0)
	moon.Size = UDim2.fromScale(56 / 432 / (1 - 72 / 432 - 0.04), 56 / 32)
	moon.ZIndex = 5
	night:SetAttribute("PhoneAnchorPoint", Vector2.new(0.5, 1))
	night:SetAttribute("PhonePosition", UDim2.fromScale(0.5, 0.985)) -- sous la barre du bas (maquette téléphone)

	-- Chrono du braquage : en haut au centre, comme avant la refonte (demande de Clément, exception voulue à « rien
	-- d'important en haut »), juste sous le bandeau RUN! de UI_Chase pour ne pas le couvrir pendant une poursuite.
	local heist = hud.HeistTimer
	heist.AnchorPoint = Vector2.new(0.5, 0)
	heist.Position = UDim2.fromScale(0.5, 0.094)
	heist.Size = UDim2.fromScale(0.5, 74 / 1022)
	heist.FontFace = ITALIC_FONT
	heist.TextColor3 = WHITE
	heist.TextXAlignment = Enum.TextXAlignment.Center
	heist.ZIndex = 8
	aspect(heist, 322 / 74)
	heist.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	minSize(heist, Vector2.new(150, 44))
	local pad = heist:FindFirstChildOfClass("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(18 / 74, 0), UDim.new(18 / 74, 0)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	textStroke(heist, 5 / 38)
	local box = heist.Box
	box.Position = UDim2.fromScale(-0.06 / 0.88, -18 / 38)
	box.Size = UDim2.fromScale(1 / 0.88, 74 / 38)
	box.BackgroundColor3 = WHITE
	box.BackgroundTransparency = 0
	box.ZIndex = 6
	for _, c in box:GetChildren() do
		if not c:IsA("UIGradient") then
			c:Destroy()
		end
	end
	box.UIGradient.Color = ColorSequence.new(Color3.fromHex("ffb347"), Color3.fromHex("f2541b"))
	box.UIGradient.Rotation = 90
	corner(box, 16 / 74)
	border(box, 5 / 74)
	local boxStuds = new("ImageLabel", {
		Name = "Studs", Image = STUDS, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageTransparency = 0.6, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(STUD_PX / 322, STUD_PX / 74), ZIndex = 7,
	}, box)
	corner(boxStuds, 16 / 74)
	local boxShine = new("Frame", { Name = "Shine", BackgroundColor3 = WHITE, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 7 }, box)
	rect(boxShine, 5, 5, 312, 30, 322, 74)
	corner(boxShine, 0.4)
	local boxShadow = new("Frame", { Name = "Shadow", Position = UDim2.fromScale(0, 6 / 74), Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 5 }, box)
	corner(boxShadow, 16 / 74)

	local meter = hud.GuardMeter -- caché par le code ; sous le chrono, comme avant
	meter.AnchorPoint = Vector2.new(0.5, 0)
	meter.Position = UDim2.fromScale(0.5, 0.174)
	meter.Size = UDim2.fromScale(0.5, 26 / 1022)
	aspect(meter, 322 / 26)
	meter.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	minSize(meter, Vector2.new(150, 12))

	-- 7. DROP (caché, montré pendant une poursuite) : en bas au centre, à la place de la barre du bas.
	local drop = brick("DropButton", hud, {
		W = 380, H = 104, radius = 16, stroke = 5, shadow = 8, shineH = 42, top = "ff5a6e", bottom = "d9203a", z = 12,
		label = { text = "DROP", x = 40, y = 28, w = 300, h = 48, stroke = 6 },
	})
	drop.AnchorPoint = Vector2.new(0.5, 1)
	drop.Position = UDim2.fromScale(0.5, 0.961)
	drop.Size = UDim2.fromScale(0.5, 104 / 1022)
	drop.Visible = false
	aspect(drop, 380 / 104)
	drop.UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	minSize(drop, Vector2.new(160, 54))
	animated(drop)

	-- Bouton d'admin (admins seulement) : en haut à droite, pour ne plus couvrir RightRail.
	hud.AdminButton.AnchorPoint = Vector2.new(1, 0)
	hud.AdminButton.Position = UDim2.fromScale(0.98, 0)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HUD v2 construit"
