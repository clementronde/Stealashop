--!nonstrict
-- hud_robux_price_build.luau (Clément, 2026-11-23 : « pour les UI de Robux dans les boutons du HUD, voilà comment
-- afficher les Robux », référence d'un autre jeu du genre) : à lancer en Edit.
-- Boutons UI_HUD.RightRail.SpeedBoostButton (« x2 SPEED ») et SleepButton : le prix n'est plus une pastille violette
-- dans le coin, mais une ligne dorée dans le bouton, sous le titre : « ONLY ⏣ 49 » (mot, icône Robux, prix, tout en
-- or avec un contour sombre). Plus de sous-titre Hint (Clément : « x2 SPEED » est permanent, et « GUARDS SLEEP 60s »
-- devient le titre du second bouton à la place de « zZz ») ; le titre (Label et son ombre LabelShadow) prend sa
-- place, sur deux lignes au besoin.
-- Noms lus par le code gardés : Price.Amount (le code y écrit le prix, Format.short) ; Price reste le cadre de la ligne.
-- Nouveau, sans code : Price.OnlyLabel (« ONLY »), Price.RobuxIcon.Fill (l'icône en or, RobuxIcon devient son bord
-- sombre). Aucun script.
-- PREVIEW = true : rien ne change dans UI_HUD ; copies dans StarterGui._PREVIEW_CLAUDE_RobuxBtn (non archivable, à
-- détruire). PREVIEW = false : UI_HUD change (sauvegarde ServerStorage/MapBackups/2026-11-23_HudRobux, annulable).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local GOLD = Color3.fromHex("#FFD12E")
local EDGE = Color3.fromHex("#2A1A05")
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

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

local function goldText(label, align)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextColor3 = GOLD
	-- par script, TextScaled ne prend que si TextWrapped est vrai avant lui
	label.TextScaled = false
	label.TextWrapped = true
	label.TextScaled = true
	label.TextXAlignment = align
	label.TextYAlignment = Enum.TextYAlignment.Center
	local s = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = EDGE
	s.Thickness = 0.14
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
end

local TITLES = { SpeedBoostButton = "x2 SPEED", SleepButton = "GUARDS SLEEP 60s" }

local function apply(button)
	-- titre seul au-dessus du prix, sur deux lignes au besoin ; plus de sous-titre
	local label, shadow, hint = button.Label, button:FindFirstChild("LabelShadow"), button:FindFirstChild("Hint")
	local title = TITLES[button.Name]
	if hint then
		hint:Destroy()
	end
	for _, t in { label, shadow } do
		if t then
			t.Text = title
			t.TextScaled = false
			t.TextWrapped = true
			t.TextScaled = true
			t.Size = UDim2.fromScale(0.6, 0.5)
		end
	end
	label.Position = UDim2.fromScale(0.665, 0.33)
	if shadow then
		shadow.Position = UDim2.fromScale(0.665, 0.36)
	end

	-- la ligne du prix
	local price = button.Price
	price.AnchorPoint = Vector2.new(0.5, 0.5)
	price.Position = UDim2.fromScale(0.665, 0.76)
	price.Size = UDim2.fromScale(0.6, 0.3)
	price.BackgroundTransparency = 1
	for _, c in price:GetChildren() do
		if c:IsA("UIGradient") or c:IsA("UICorner") or c:IsA("UIStroke") then
			c:Destroy()
		end
	end
	local list = child(price, "UIListLayout", "UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left -- calé à gauche, comme le titre et Hint
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.015, 0)

	local only = child(price, "TextLabel", "OnlyLabel")
	only.Text = "ONLY"
	only.LayoutOrder = 1
	only.Size = UDim2.fromScale(0.3, 0.78) -- juste la largeur du mot (« ONLY » : 2,41 × sa hauteur), pas de trou avant l'icône
	only.ZIndex = 14
	goldText(only, Enum.TextXAlignment.Left)

	local icon = price.RobuxIcon -- devient le bord sombre ; Fill, l'icône en or, par-dessus
	icon.LayoutOrder = 2
	icon.Size = UDim2.fromScale(0.2, 0.92)
	icon.ImageColor3 = EDGE
	icon.ZIndex = 14
	local ar = icon:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = icon
	local fill = child(icon, "ImageLabel", "Fill")
	fill.Image = icon.Image
	fill.ImageColor3 = GOLD
	fill.BackgroundTransparency = 1
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(0.8, 0.8)
	fill.ZIndex = 15

	local amount = price.Amount
	amount.LayoutOrder = 3
	amount.AnchorPoint = Vector2.zero
	amount.Size = UDim2.fromScale(0.4, 1)
	amount.ZIndex = 14
	goldText(amount, Enum.TextXAlignment.Left)
end

local NAMES = { "SpeedBoostButton", "SleepButton" }

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_RobuxBtn")
	if old then
		old:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = "_PREVIEW_CLAUDE_RobuxBtn"
	g.Archivable = false
	g.DisplayOrder = 100
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = SG.UI_HUD.ZIndexBehavior
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromHex("#3A7A3A")
	bg.BorderSizePixel = 0
	bg.ZIndex = 0
	bg.Parent = g
	for i, n in NAMES do
		local b = SG.UI_HUD.RightRail[n]:Clone()
		b.Visible = true
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.fromScale(0.5, 0.15 + (i - 1) * 0.3)
		b.Size = UDim2.fromOffset(340, 106)
		local sc = b:FindFirstChildOfClass("UISizeConstraint")
		if sc then
			sc:Destroy()
		end
		apply(b)
		b.Price.Amount.Text = if n == "SpeedBoostButton" then "49" else "25"
		if b:FindFirstChild("Cooldown") then
			b.Cooldown.Visible = false
		end
		b.Parent = bg
	end
	g.Parent = SG
	return "aperçu posé"
end

local rec = CHS:TryBeginRecording("UI : prix Robux des boutons du HUD dans le bouton (ONLY ⏣ prix)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-23_HudRobux")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-23_HudRobux"
		backups.Parent = SS.MapBackups
	end
	for _, n in NAMES do
		if not backups:FindFirstChild(n) then
			SG.UI_HUD.RightRail[n]:Clone().Parent = backups
		end
		apply(SG.UI_HUD.RightRail[n])
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HUD : prix Robux dans les boutons"
