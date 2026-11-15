--!nonstrict
-- ui_l170_build.luau (L-170, demande de Clément du 2026-11-15). À lancer en Edit, après ui_codes_shopinfo_build.luau.
-- Annulable. Aucun script.
--   1. UI_Settings : chaque ligne tient ses boutons de 44 px sur téléphone (RowMin : 44 px, 56 pour CodeRow) ;
--      la fenêtre prend plus de hauteur dans Root, en-tête 0,125, lignes de 0,135 à 0,99.
--   2. UI_Escape : textes d'exemple « ITEM SECURED! » et « LEGENDARY Golden Graphics Card » (le code écrit les siens).
--   3. UI_EventBanner (Enabled = false, EventBannerController l'allume) : Banner.Card avec Title, Effect, Timer ;
--      à droite, à 60 % de la hauteur (jamais en haut), DisplayOrder 3, sous les messages et l'alerte de vol.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

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
local function textStroke(o, t)
	return new("UIStroke", {
		Thickness = t or 0.1, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Round,
	}, o)
end
local function text(name, value, parent, props)
	local l = new("TextLabel", {
		Name = name, Text = value, BackgroundTransparency = 1, FontFace = HEAVY, TextColor3 = WHITE, TextScaled = true, TextWrapped = true,
	}, parent)
	for k, v in props or {} do
		l[k] = v
	end
	return l
end

local function settings()
	local root = SG.UI_Settings.Root
	local win = root.Window
	local rows = win.Rows
	win.Position = UDim2.fromScale(win.Position.X.Scale, 0.03)
	win.Size = UDim2.fromScale(win.Size.X.Scale, 0.94)
	root.WindowShadow.Position = UDim2.fromScale(root.WindowShadow.Position.X.Scale, 0.039)
	root.WindowShadow.Size = UDim2.fromScale(root.WindowShadow.Size.X.Scale, 0.94)
	win.Header.Size = UDim2.fromScale(1, 0.125)
	rows.Position = UDim2.fromScale(rows.Position.X.Scale, 0.135)
	rows.Size = UDim2.fromScale(rows.Size.X.Scale, 0.855)
	rows.UIListLayout.Padding = UDim.new(0.01, 0)
	for _, r in rows:GetChildren() do
		if r:IsA("Frame") then
			local isCode = r.Name == "CodeRow"
			r.Size = UDim2.fromScale(1, if isCode then 0.24 else 0.155)
			local sc = r:FindFirstChild("RowMin") or new("UISizeConstraint", { Name = "RowMin" }, r)
			sc.MinSize = Vector2.new(0, if isCode then 56 else 44)
		end
	end
	local code = rows:FindFirstChild("CodeRow")
	if code then
		for _, n in { "Icon", "CodeBox", "RedeemButton" } do
			code[n].Position = UDim2.fromScale(code[n].Position.X.Scale, 0.4)
		end
		code.CodeStatus.Position = UDim2.fromScale(0.15, 0.99)
		code.CodeStatus.Size = UDim2.fromScale(0.825, 0.19)
	end
end

local function escape()
	SG.UI_Escape.Banner.Title.Text = "ITEM SECURED!"
	SG.UI_Escape.Banner.Subtitle.Text = "LEGENDARY Golden Graphics Card"
end

local function eventBanner()
	if SG:FindFirstChild("UI_EventBanner") then
		return
	end
	local gui = new("ScreenGui", {
		Name = "UI_EventBanner", Enabled = false, DisplayOrder = 3, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	local banner = new("Frame", {
		Name = "Banner", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.985, 0.6), Size = UDim2.fromScale(0.2, 0.2),
		BackgroundTransparency = 1,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = 2, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width }, banner)
	new("UISizeConstraint", { MinSize = Vector2.new(170, 85), MaxSize = Vector2.new(360, 180) }, banner)
	local shadow = new("Frame", {
		Name = "Shadow", Position = UDim2.fromScale(0.02, 0.06), Size = UDim2.fromScale(0.98, 0.94), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 1,
	}, banner)
	new("UICorner", { CornerRadius = UDim.new(0.16, 0) }, shadow)
	local card = new("Frame", { Name = "Card", Size = UDim2.fromScale(0.98, 0.94), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2 }, banner)
	new("UICorner", { CornerRadius = UDim.new(0.16, 0) }, card)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("9b4dff"), Color3.fromHex("5418c8")), Rotation = 90 }, card)
	new("UIStroke", {
		Thickness = 0.022, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Round,
	}, card)
	local studs = new("ImageLabel", {
		Name = "Studs", Image = "rbxassetid://3014551673", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ImageTransparency = 0.7, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromScale(0.09, 0.18), ZIndex = 3,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0.16, 0) }, studs)
	textStroke(text("Title", "ADMIN ABUSE", card, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.06), Size = UDim2.fromScale(0.92, 0.3),
		TextColor3 = Color3.fromHex("ffd23a"), ZIndex = 4,
	}), 0.1)
	textStroke(text("Effect", "x2 cash for everyone, trucks every 2-3 min", card, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.92, 0.34), ZIndex = 4,
	}), 0.1)
	local timer = text("Timer", "29:59", card, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.44, 0.2),
		BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromHex("1b1f27"), ZIndex = 5,
	})
	new("UICorner", { CornerRadius = UDim.new(0.4, 0) }, timer)
	new("UIStroke", {
		Thickness = 0.05, Color = Color3.fromHex("ffc21a"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Round,
	}, timer)
	new("UIPadding", {
		PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), PaddingLeft = UDim.new(0.08, 0), PaddingRight = UDim.new(0.08, 0),
	}, timer)
	gui.Parent = SG
end

local rec = CHS:TryBeginRecording("UI L-170 : réglages sur téléphone, ITEM SECURED!, UI_EventBanner")
local ok, err = pcall(function()
	settings()
	escape()
	eventBanner()
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI L-170 : fait"
