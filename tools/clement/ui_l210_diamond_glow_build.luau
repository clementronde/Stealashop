--!nonstrict
-- ui_l210_diamond_glow_build.luau (L-208 point 6, demandé par Cantin) : deux écrans neufs, désactivés.
--   1. UI_DiamondShop, d'après la maquette Figma (page « 10 Boutiques », section UI_DiamondShop) et la fenêtre de
--      UI_RobuxShop_v2 (même style et même taille, clonée puis vidée) :
--        Root · Window · Header (Title « Diamond Shop », Balance : Icon, Amount, Spent rouge caché au repos) ·
--        Window.AddButton (AddLabel « + ») · Window.CloseButton · Tabs.GetDiamondsTab et Tabs.CustomizeTab (TabIcon,
--        TabLabel ; mot jaune sur l'onglet ouvert) · Window.PacksList (ScrollingFrame, UIGridLayout de 4 cartes) →
--        Template (Icon, Amount, BuyButton.Content : RobuxIcon, Price), cartes d'exemple Preview_1 à 4.
--      L'onglet My Shop (ShopPreview, Categories, CatalogList) n'est pas construit : catégories, objets et prix ne sont
--      pas décidés. Le solde ne s'affiche que dans cet écran (décision de Clément du 2026-11-15).
--   2. UI_PurchaseGlow : RainbowBorder (Frame plein écran transparent) avec un UIStroke de 8 px dessiné à l'intérieur
--      et son UIGradient arc-en-ciel (le premier UIGradient de RainbowBorder, que le code fait tourner). Attribut
--      PhoneThickness = 5 sur RainbowBorder : épaisseur voulue sur téléphone (un UIStroke n'a pas de minimum).
-- À lancer en Edit, après ui_l210_robuxshop.luau. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

assert(not SG:FindFirstChild("UI_DiamondShop"), "UI_DiamondShop existe déjà")
assert(not SG:FindFirstChild("UI_PurchaseGlow"), "UI_PurchaseGlow existe déjà")

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("1b1b24")
local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromHex("ffd43b")
local DIAMOND = Icons.UI_Icon_Diamond.Texture

local function seq(a, b)
	return ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b))
end
local function recolor(object, a, b)
	local gradient = object:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = seq(a, b)
	end
end
local function drop(parent, name)
	local x = parent:FindFirstChild(name)
	if x then
		x:Destroy()
	end
end
local function text(name, parent, str, color, stroke)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = str
	t.FontFace = HEAVY
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color or WHITE
	t.BackgroundTransparency = 1
	t.ZIndex = 6
	local s = Instance.new("UIStroke")
	s.Thickness = stroke or 0.1
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	t.Parent = parent
	return t
end

local rec = CHS:TryBeginRecording("UI : UI_DiamondShop et UI_PurchaseGlow (L-208 point 6)")
local ok, err = pcall(function()
	---------------------------------------------------------------- 1. UI_DiamondShop
	local gui = SG.UI_RobuxShop_v2:Clone()
	gui.Name = "UI_DiamondShop"
	gui.Enabled = false
	gui:SetAttribute("Version", nil)
	drop(gui, "Decor")
	local root = gui.Root
	local window = root.Window

	-- En-tête turquoise.
	local header = window.Header
	recolor(header, "8ee9e4", "33b9b3")
	recolor(header.HeaderFill, "5fd9d2", "33b9b3")
	header.Title.Text = "Diamond Shop"

	-- Solde : Header.Balance (Icon, Amount, Spent).
	local balance = Instance.new("Frame")
	balance.Name = "Balance"
	balance.AnchorPoint = Vector2.new(1, 0.5)
	balance.Position = UDim2.fromScale(0.83, 0.5)
	balance.Size = UDim2.fromScale(0.13, 0.66)
	balance.BackgroundColor3 = INK
	balance.BackgroundTransparency = 0.3
	balance.BorderSizePixel = 0
	balance.ZIndex = 5
	balance.Parent = header
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Image = DIAMOND
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Position = UDim2.fromScale(0.04, 0.1)
	icon.Size = UDim2.fromScale(0.36, 0.8)
	icon.ZIndex = 6
	icon.Parent = balance
	local amount = text("Amount", balance, "0", WHITE, 0.1)
	amount.Position = UDim2.fromScale(0.42, 0.14)
	amount.Size = UDim2.fromScale(0.54, 0.72)
	amount.TextXAlignment = Enum.TextXAlignment.Left
	local spent = text("Spent", balance, "-0", Color3.fromHex("ff4a4a"), 0.12)
	spent.AnchorPoint = Vector2.new(0.5, 0)
	spent.Position = UDim2.fromScale(0.6, 1.08)
	spent.Size = UDim2.fromScale(0.8, 0.62)
	spent.Visible = false -- caché au repos : DiamondBalance le montre après un achat

	-- Bouton « + » vert à gauche du X (ouvre l'onglet Diamonds).
	local close = window.CloseButton
	local add = close:Clone()
	add.Name = "AddButton"
	add.Position = UDim2.new(0.912, 0, close.Position.Y.Scale, 0)
	recolor(add, "8cf05a", "3fb52a")
	local label = add:FindFirstChild("XLabel")
	if label then
		label.Name = "AddLabel"
		label.Text = "+"
	end
	add.Parent = window

	-- Onglets : Diamonds (ouvert) et My Shop.
	local tabs = root.Tabs
	drop(tabs, "CashTab")
	drop(tabs, "BoostsTab")
	local diamonds, custom = tabs.OffersTab, tabs.GamepassesTab
	diamonds.Name = "GetDiamondsTab"
	diamonds.TabIcon.Image = DIAMOND
	diamonds.TabIcon:SetAttribute("IconAsset", "UI_Icon_Diamond")
	diamonds.TabLabel.Text = "Diamonds"
	diamonds.TabLabel.TextColor3 = YELLOW
	custom.Name = "CustomizeTab"
	custom.TabIcon.Image = Icons.UI_Icon_Displays.Texture -- image à faire : le rouleau de peinture de la maquette
	custom.TabIcon:SetAttribute("IconAsset", "UI_Icon_Displays")
	custom.TabLabel.Text = "My Shop"
	custom.TabLabel.TextColor3 = WHITE

	-- Liste des packs : PacksList, 4 cartes par rang.
	local list = window.List
	list.Name = "PacksList"
	local content = list.Content
	local cashTemplate = content.CashSection.Grid.Template:Clone()
	content:Destroy()
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = 4
	grid.CellSize = UDim2.new(0.2375, 0, 0.95, 0)
	grid.CellPadding = UDim2.new(0.0166, 0, 0, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 0.75
	ratio.Parent = grid
	grid.Parent = list
	list:SetAttribute("Appear", "Cascade")

	local t = cashTemplate
	t.Name = "Template"
	t.Visible = false
	t:SetAttribute("CardColor", Color3.fromHex("2fc4bd"))
	recolor(t, "8ee9e4", "2fa8a2")
	drop(t, "Effect")
	drop(t, "Owned")
	local name = t.ItemName
	name.Name = "Amount"
	name.Text = "???"
	t.Icon.Image = DIAMOND
	t.Icon:SetAttribute("IconAsset", "UI_Icon_Diamond")
	local watermark = t.Clip:FindFirstChild("Watermark")
	if watermark then
		watermark.Image = DIAMOND
	end
	t.BuyButton.Content.Price.Text = "???"
	t.Parent = list
	for i = 1, 4 do
		local p = t:Clone()
		p.Name = "Preview_" .. i
		p.LayoutOrder = i
		p.Visible = true
		p.Parent = list
	end

	gui.Parent = SG

	---------------------------------------------------------------- 2. UI_PurchaseGlow
	local glow = Instance.new("ScreenGui")
	glow.Name = "UI_PurchaseGlow"
	glow.Enabled = false
	glow.IgnoreGuiInset = true
	glow.ResetOnSpawn = false
	glow.DisplayOrder = 900
	glow.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local border = Instance.new("Frame")
	border.Name = "RainbowBorder"
	border.Size = UDim2.fromScale(1, 1)
	border.BackgroundTransparency = 1
	border.BorderSizePixel = 0
	border:SetAttribute("PhoneThickness", 5)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 8
	stroke.Color = WHITE
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	local rainbow = Instance.new("UIGradient")
	rainbow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("ff3b5c")),
		ColorSequenceKeypoint.new(0.2, Color3.fromHex("ff9a2e")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("ffd23b")),
		ColorSequenceKeypoint.new(0.6, Color3.fromHex("3bdc6a")),
		ColorSequenceKeypoint.new(0.8, Color3.fromHex("3b9bff")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("b84bff")),
	})
	rainbow.Rotation = 45
	rainbow.Parent = stroke
	stroke.Parent = border
	border.Parent = glow
	glow.Parent = SG
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	for _, n in { "UI_DiamondShop", "UI_PurchaseGlow" } do
		local half = SG:FindFirstChild(n)
		if half then
			half:Destroy()
		end
	end
	error(err)
end
return "UI_DiamondShop et UI_PurchaseGlow : construits"
