--!nonstrict
-- refonte_ui_hud.luau (demande de Clément du 2026-11-15, avec une capture d'un autre jeu en référence) :
--   1. boutons de gauche (LeftRail sur PC, LeftRailTouch sur téléphone), stats (StatsPanel) et boutons de droite
--      (SocialRow) environ 25 % plus petits, textes compris ;
--   2. l'inventaire quitte la colonne de gauche : un seul InventoryButton, en bas à gauche, dans BottomLeft.BottomRow,
--      à côté des bonus actifs (FriendBoost, VipBoost, CashBoost, TrainingBoost : icône + Amount) ;
--   3. BottomLeft empile StatsPanel au-dessus de BottomRow (UIListLayout), quelles que soient les tailles minimales.
-- Le code retrouve InventoryButton, InventoryAlert, Cash, Speed, StatsPanel… par leur nom, où qu'ils soient
-- (Find.all, FindFirstChild récursif) : rien ne casse. Les bonus sont cachés par Clément sauf FriendBoost (« +0% ») ;
-- c'est le code d'Ironix qui doit les remplir et les montrer (liaison). À lancer en Edit. Sauvegarde d'abord l'écran
-- dans ServerStorage/MapBackups/2026-11-15_RefonteUI. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local hud = SG.UI_HUD
assert(not hud:FindFirstChild("BottomLeft"), "UI_HUD est déjà refait")

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local SCALE = 0.75 -- réduction demandée

-- Bonus actifs : nom, icône, texte d'exemple, dégradé du texte, visible au départ.
local BONUSES = {
	{ "FriendBoost", "rbxassetid://102094661385258", "+0%", { "d4ff5c", "2fcb1f" }, true }, -- icône d'InviteButton
	{ "VipBoost", "rbxassetid://71854395817195", "+10%", { "fff27a", "ffb21a" }, false }, -- icône du pass VIP
	{ "CashBoost", "rbxassetid://90748953656553", "x2", { "d4ff5c", "2fcb1f" }, false }, -- icône du pass ×2 Cash
	{ "TrainingBoost", "rbxassetid://106315635775683", "x2", { "9befff", "2ea6f2" }, false }, -- icône du pass ×2 Training
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
local function scaleSize(o, k)
	o.Size = UDim2.new(o.Size.X.Scale * k, o.Size.X.Offset, o.Size.Y.Scale * k, o.Size.Y.Offset)
end
local function minSize(o, v)
	local c = o:FindFirstChildOfClass("UISizeConstraint") or new("UISizeConstraint", {}, o)
	c.MinSize = v
end

local rec = CHS:TryBeginRecording("Refonte UI : UI_HUD plus petit, inventaire et bonus en bas à gauche")
local ok, err = pcall(function()
	local backups = SS:FindFirstChild("MapBackups") or new("Folder", { Name = "MapBackups" }, SS)
	local folder = backups:FindFirstChild("2026-11-15_RefonteUI") or new("Folder", { Name = "2026-11-15_RefonteUI" }, backups)
	if not folder:FindFirstChild("UI_HUD") then
		local old = hud:Clone()
		old.Enabled = false
		old:SetAttribute("AncienEmplacement", "StarterGui.UI_HUD")
		old.Parent = folder
	end

	-- 1. Colonne de gauche, PC : 25 % plus petite, sans l'inventaire (4 boutons).
	local rail = hud.LeftRail
	scaleSize(rail, SCALE)
	rail.InventoryButton:Destroy()
	-- Téléphone : grille de 2 × 2 (4 boutons), cases de 47 px environ en 844 × 390 (au moins 44).
	local touch = hud.LeftRailTouch
	touch.Size = UDim2.fromScale(0.2, 0.3)
	touch.UIAspectRatioConstraint.AspectRatio = 1.136
	touch.UIGridLayout.CellSize = UDim2.fromScale(0.476, 0.47)
	touch.UIGridLayout.CellPadding = UDim2.fromScale(0.048, 0.06)
	minSize(touch, Vector2.new(107, 94)) -- cases de 44 px au moins, même en 667 × 335
	local inventory = touch.InventoryButton

	-- 2. Boutons de droite : 25 % plus petits, 46 px au moins.
	local social = hud.SocialRow
	scaleSize(social, SCALE)
	social.Position = UDim2.new(1.0137, -66, 0.85, 0) -- un peu plus haut : ne touche plus NightCountdown en 750 × 350
	for _, b in social:GetChildren() do
		if b:IsA("GuiButton") then
			minSize(b, Vector2.new(46, 46))
		end
	end

	-- 3. Bas à gauche : stats au-dessus, rangée de l'inventaire et des bonus en dessous.
	local bottomLeft = new("Frame", {
		Name = "BottomLeft", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.021, 0.985),
		Size = UDim2.fromScale(0.34, 0.33), BackgroundTransparency = 1,
	}, hud)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Left, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.03, 0),
	}, bottomLeft)
	local stats = hud.StatsPanel
	stats.Parent = bottomLeft
	stats.LayoutOrder = 1
	stats.Size = UDim2.fromScale(0.706, 0.52) -- 0,24 × 0,17 de l'écran (avant : 0,32 × 0,23)
	minSize(stats, Vector2.new(200, 86))

	local row = new("Frame", {
		Name = "BottomRow", Size = UDim2.fromScale(1, 0.23), BackgroundTransparency = 1, LayoutOrder = 2,
	}, bottomLeft)
	minSize(row, Vector2.new(0, 44))
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Left, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.025, 0),
	}, row)

	inventory.Parent = row
	inventory.LayoutOrder = 1
	inventory.Size = UDim2.fromScale(1, 1)
	if not inventory:FindFirstChildOfClass("UIAspectRatioConstraint") then
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, inventory)
	end

	for i, b in BONUSES do
		local name, image, sample, colors, visible = b[1], b[2], b[3], b[4], b[5]
		local badge = new("Frame", {
			Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, LayoutOrder = i + 1, Visible = visible,
		}, row)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, badge)
		new("ImageLabel", {
			Name = "Icon", Image = image, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.86, 0.8), ZIndex = 2,
		}, badge)
		local amount = new("TextLabel", {
			Name = "Amount", Text = sample, BackgroundTransparency = 1, FontFace = HEAVY, TextColor3 = WHITE, TextScaled = true,
			TextWrapped = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1.02), Size = UDim2.fromScale(1.15, 0.38),
			ZIndex = 3,
		}, badge)
		new("UIStroke", {
			Thickness = 0.13, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Bevel,
		}, amount)
		new("UIGradient", { Color = ColorSequence.new(Color3.fromHex(colors[1]), Color3.fromHex(colors[2])), Rotation = 90 }, amount)
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HUD refait"
