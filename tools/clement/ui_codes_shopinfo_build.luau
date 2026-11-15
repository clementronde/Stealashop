--!nonstrict
-- ui_codes_shopinfo_build.luau (L-168, L-169 ; demande de Clément du 2026-11-15). À lancer en Edit. Annulable.
-- Aucun script. Noms lus par le code (CodeController, RebirthController, PvPController) :
--   1. UI_Settings : Rows.CodeRow avec CodeBox (TextBox), RedeemButton (RedeemLabel, Shade), CodeStatus ;
--      la fenêtre grandit pour garder la hauteur des 4 autres lignes.
--   2. UI_Rewards : Window.Header.UpdateCountdown (« NEXT UPDATE IN 2d 04h »), pastille dorée.
--   3. UI_Rebirth : attribut OwnedColor (vert) sur ItemRequirement.Status, à lire par le code pour « Owned! ».
--   4. Assets/UI/BB_ShopInfo : panneau du voleur au-dessus de la porte d'une boutique, OwnerName, Income,
--      HP (« 7/40 », avec l'icône du marteau) et Status (« LOCKED 23s », « OPEN », « ROB AGAIN IN 42s »).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local UIA = game:GetService("ReplicatedStorage").Assets.UI

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local ICON_GIFT = "rbxassetid://111068746694124" -- icône de l'onglet Daily de UI_Rewards
local ICON_HAMMER = "rbxassetid://103484440763586" -- ICON_TOOL_Hammer
local STUDS = "rbxassetid://3014551673"
local report = {}

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
local function corner(o, s)
	return new("UICorner", { CornerRadius = UDim.new(s, 0) }, o)
end
local function border(o, t, scaled)
	return new("UIStroke", {
		Thickness = t, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round,
		StrokeSizingMode = if scaled then Enum.StrokeSizingMode.ScaledSize else Enum.StrokeSizingMode.FixedSize,
	}, o)
end
local function textStroke(o, t)
	return new("UIStroke", {
		Thickness = t or 0.12, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Round,
	}, o)
end
local function text(name, value, parent, props)
	local l = new("TextLabel", {
		Name = name, Text = value, BackgroundTransparency = 1, FontFace = HEAVY, TextColor3 = WHITE,
		TextScaled = true, TextWrapped = true,
	}, parent)
	for k, v in props or {} do
		l[k] = v
	end
	return l
end

-- 1. UI_Settings.CodeRow ------------------------------------------------------------------------------
local function buildCodeRow()
	local root = SG.UI_Settings.Root
	local rows = root.Window.Rows
	if rows:FindFirstChild("CodeRow") then
		table.insert(report, "CodeRow : déjà là")
		return
	end
	-- 5 lignes au lieu de 4 : la fenêtre grandit (même largeur, même hauteur de ligne en pixels).
	root.Size = UDim2.fromScale(1, 0.74)
	root.UIAspectRatioConstraint.AspectRatio = 1.1
	rows.UIListLayout.Padding = UDim.new(0.025, 0)
	-- 362 px de haut au minimum dépassait l'écran d'un téléphone (311 px utiles en paysage).
	root.UISizeConstraint.MinSize = Vector2.new(337, 306)
	for _, r in rows:GetChildren() do
		if r:IsA("Frame") then
			r.Size = UDim2.fromScale(1, 0.155)
		end
	end
	local row = new("Frame", {
		Name = "CodeRow", LayoutOrder = 5, Size = UDim2.fromScale(1, 0.28),
		BackgroundColor3 = rows.MusicRow.BackgroundColor3, BackgroundTransparency = rows.MusicRow.BackgroundTransparency,
		BorderSizePixel = 0, ZIndex = rows.MusicRow.ZIndex,
	}, rows)
	local c = rows.MusicRow:FindFirstChildOfClass("UICorner")
	if c then
		c:Clone().Parent = row
	end
	border(row, 2)
	local icon = new("ImageLabel", {
		Name = "Icon", Image = ICON_GIFT, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.02, 0.37), Size = UDim2.fromScale(0.3, 0.6), ZIndex = 6,
	}, row)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	local box = new("TextBox", {
		Name = "CodeBox", Text = "", PlaceholderText = "Enter code", PlaceholderColor3 = Color3.fromHex("8a93a3"),
		ClearTextOnFocus = false, FontFace = HEAVY, TextColor3 = WHITE, TextScaled = true, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = Color3.fromHex("0c0f18"), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.15, 0.37), Size = UDim2.fromScale(0.5, 0.56), ZIndex = 6,
	}, row)
	corner(box, 0.22)
	border(box, 2)
	new("UIPadding", { PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0), PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }, box)
	new("UISizeConstraint", { MinSize = Vector2.new(0, 44) }, box)
	local button = new("TextButton", {
		Name = "RedeemButton", Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.975, 0.37), Size = UDim2.fromScale(0.29, 0.62), ZIndex = 6,
	}, row)
	corner(button, 0.22)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("91f630"), Color3.fromHex("31dd22")), Rotation = 90 }, button)
	border(button, 2)
	new("UISizeConstraint", { MinSize = Vector2.new(0, 44) }, button)
	local studs = new("ImageLabel", {
		Name = "Studs", Image = STUDS, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageTransparency = 0.55,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromScale(0.17, 0.6), ZIndex = 7,
	}, button)
	corner(studs, 0.22)
	textStroke(text("RedeemLabel", "REDEEM", button, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.56), ZIndex = 8,
	}), 0.12)
	local shade = new("Frame", {
		Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9,
	}, button)
	corner(shade, 0.22)
	textStroke(text("CodeStatus", "Find codes on our socials!", row, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.15, 0.97), Size = UDim2.fromScale(0.825, 0.21),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromHex("c9ced6"), ZIndex = 6,
	}), 0.1)
	table.insert(report, "UI_Settings.Rows.CodeRow : construit (fenêtre agrandie, 5 lignes)")
end

-- 2. UI_Rewards.UpdateCountdown -------------------------------------------------------------------------
local function buildCountdown()
	local header = SG.UI_Rewards.Root.Window.Header
	if header:FindFirstChild("UpdateCountdown") then
		table.insert(report, "UpdateCountdown : déjà là")
		return
	end
	local l = text("UpdateCountdown", "NEXT UPDATE IN 2d 04h", header, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.92, -16, 0.5, 0), Size = UDim2.fromScale(0.42, 0.56),
		BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromHex("1b1f27"), TextColor3 = Color3.fromHex("ffd23a"), ZIndex = 7,
	})
	corner(l, 0.35)
	border(l, 0.06, true)
	new("UIPadding", { PaddingLeft = UDim.new(0.05, 0), PaddingRight = UDim.new(0.05, 0), PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0) }, l)
	table.insert(report, "UI_Rewards.Window.Header.UpdateCountdown : construit")
end

-- 3. UI_Rebirth : couleur de « Owned! » ------------------------------------------------------------------
local function ownedColor()
	local status = SG.UI_Rebirth.Root.Window.Body.Requirements.Inner.ItemRequirement.Status
	status:SetAttribute("OwnedColor", Color3.fromHex("5cff4a"))
	table.insert(report, "UI_Rebirth ItemRequirement.Status@OwnedColor = 5cff4a")
end

-- 4. Assets/UI/BB_ShopInfo -----------------------------------------------------------------------------
local function buildShopInfo()
	if UIA:FindFirstChild("BB_ShopInfo") then
		table.insert(report, "BB_ShopInfo : déjà là")
		return
	end
	local bb = new("BillboardGui", {
		Name = "BB_ShopInfo", Size = UDim2.new(8, 0, 4.4, 0), SizeOffset = Vector2.new(0, 0.5), MaxDistance = 120,
		LightInfluence = 0, AlwaysOnTop = false, ClipsDescendants = false, ResetOnSpawn = false,
	})
	local panel = new("Frame", {
		Name = "Panel", Size = UDim2.fromScale(1, 0.76), BackgroundColor3 = Color3.fromHex("1b1f27"), BackgroundTransparency = 0.2,
		BorderSizePixel = 0, ZIndex = 1,
	}, bb)
	corner(panel, 0.14)
	border(panel, 0.025, true)
	textStroke(text("OwnerName", "Alice's Shop", panel, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.92, 0.28), ZIndex = 2,
	}), 0.1)
	textStroke(text("Income", "+$12.4K/s", panel, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.33), Size = UDim2.fromScale(0.92, 0.22),
		TextColor3 = Color3.fromHex("35c93b"), ZIndex = 2,
	}), 0.1)
	local line = new("Frame", {
		Name = "HPLine", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.92, 0.38),
		BackgroundTransparency = 1, ZIndex = 2,
	}, panel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.02, 0),
	}, line)
	local hammer = new("ImageLabel", {
		Name = "HPIcon", Image = ICON_HAMMER, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, LayoutOrder = 1,
		Size = UDim2.fromScale(0.2, 1), ZIndex = 3,
	}, line)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, hammer)
	textStroke(text("HP", "7/40", line, {
		LayoutOrder = 2, Size = UDim2.fromScale(0.4, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}), 0.1)
	-- Status : pastille orange sous le panneau, cachée par le code quand il n'y a rien à dire.
	local status = text("Status", "LOCKED 23s", bb, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.7, 0.21),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("ff8c1a"), ZIndex = 4,
	})
	corner(status, 0.4)
	textStroke(status, 0.12)
	new("UIPadding", { PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0), PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0) }, status)
	bb.Parent = UIA
	table.insert(report, "Assets/UI/BB_ShopInfo : construit")
end

local rec = CHS:TryBeginRecording("UI : codes, compte à rebours, Owned vert, BB_ShopInfo (L-168, L-169)")
local ok, err = pcall(function()
	buildCodeRow()
	buildCountdown()
	ownedColor()
	buildShopInfo()
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return table.concat(report, "\n")
