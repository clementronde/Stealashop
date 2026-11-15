--!strict
-- Boutique Robux v2 (maquette Figma « 10 Boutiques », UI_RobuxShop v2, demande de Clément du 2026-11-16).
-- Construit un écran à part, StarterGui/UI_RobuxShop_v2 (désactivé), à partir de UI_RobuxShop (style v3) :
-- une seule liste qui défile (List.Content, UIListLayout vertical), dans l'ordre :
--   Crate (caisse exclusive) · Featured (Starter Pack) · GamepassesSection · BoostsSection · CashSection.
-- Chaque section : Header (Bar, Label, Bar) et Grid (UIGridLayout, 4 colonnes) avec son Template et des Preview_*.
-- Les onglets ne filtrent plus : le code les fera défiler jusqu'à leur section (liaison).
-- Règles : coins droits, contour noir, studs en fond léger ; seuls les boutons de prix sont légèrement arrondis.
-- Relançable : l'ancien UI_RobuxShop_v2 part dans ServerStorage/MapBackups/<date>_RefonteForge.

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DARK = Color3.fromRGB(20, 20, 26)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 40)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local icons = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Icons")
local function tex(name: string): string
	local d = icons:FindFirstChild(name)
	if d and d:IsA("Decal") then
		return d.Texture
	end
	return ""
end

-- sauvegarde de l'ancienne v2
local backups = ServerStorage:FindFirstChild("MapBackups") or Instance.new("Folder")
backups.Name = "MapBackups"
backups.Parent = ServerStorage
local folder = backups:FindFirstChild("2026-11-16_RefonteForge") or Instance.new("Folder")
folder.Name = "2026-11-16_RefonteForge"
folder.Parent = backups
local previous = StarterGui:FindFirstChild("UI_RobuxShop_v2")
if previous then
	previous.Name = "UI_RobuxShop_v2_" .. os.time()
	previous.Parent = folder
end

local source = StarterGui:WaitForChild("UI_RobuxShop") :: ScreenGui
local gui = source:Clone()
gui.Name = "UI_RobuxShop_v2"
gui.Enabled = false
gui:SetAttribute("Version", 2)

local window = (gui:WaitForChild("Root") :: Frame):WaitForChild("Window") :: Frame
local list = window:WaitForChild("List") :: ScrollingFrame
local oldTemplate = list:WaitForChild("Template") :: Frame
oldTemplate.Parent = nil
for _, c in list:GetChildren() do
	if not c:IsA("UIPadding") then
		c:Destroy()
	end
end
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()

local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3?, anchor: Vector2?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.AnchorPoint = anchor or Vector2.new(0, 0)
	l.Text = text
	l.FontFace = FONT
	l.TextColor3 = color or WHITE
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	local s = Instance.new("UIStroke")
	s.Color = DARK
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.12
	s.Parent = l
	l.Parent = parent
	return l
end

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or DARK
	f.BackgroundTransparency = color and 0 or 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function stroke(o: GuiObject, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = DARK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = thickness
	s.Parent = o
end

local function image(parent: Instance, name: string, img: string, size: UDim2, pos: UDim2, anchor: Vector2?): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = img
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = size
	i.Position = pos
	i.AnchorPoint = anchor or Vector2.new(0, 0)
	i.Parent = parent
	return i
end

-- bouton de prix Robux : on reprend celui des cartes (déjà au bon style, légèrement arrondi)
local priceButton = (oldTemplate:WaitForChild("BuyRow") :: Frame):WaitForChild("BuyButton") :: TextButton

-- Contenu vertical
local content = frame(list, "Content", UDim2.fromScale(1, 0), UDim2.new())
content.AutomaticSize = Enum.AutomaticSize.Y
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 14)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = content

-- 1. Caisse exclusive (Crate)
local crate = frame(content, "Crate", UDim2.fromScale(0.98, 0), UDim2.new(), Color3.fromRGB(60, 20, 110))
crate.LayoutOrder = 1
crate.BackgroundTransparency = 0
crate.ClipsDescendants = true
local crateRatio = Instance.new("UIAspectRatioConstraint")
crateRatio.AspectRatio = 1130 / 356
crateRatio.Parent = crate
crate.Size = UDim2.fromScale(0.98, 1)
stroke(crate, 0.012)
local backdrop = image(crate, "Backdrop", tex("UI_Bg_CrateVault"), UDim2.fromScale(1, 1), UDim2.new())
backdrop.ScaleType = Enum.ScaleType.Crop
image(crate, "Icon", tex("ICON_BOX_Secret"), UDim2.fromScale(0.3, 0.92), UDim2.fromScale(0.02, 0.08))
local badge = frame(crate, "NewBadge", UDim2.fromScale(0.092, 0.17), UDim2.fromScale(0.016, 0.045), Color3.fromRGB(230, 40, 50))
badge.Rotation = -8
stroke(badge, 0.04)
local badgeLabel = label(badge, "Label", "NEW!", UDim2.fromScale(0.86, 0.78), UDim2.fromScale(0.5, 0.5), WHITE, Vector2.new(0.5, 0.5))
badgeLabel.TextXAlignment = Enum.TextXAlignment.Center
label(crate, "ItemName", "EXCLUSIVE CRATE", UDim2.fromScale(0.47, 0.22), UDim2.fromScale(0.3, 0.07), GOLD)
local odds = frame(crate, "Odds", UDim2.fromScale(0.678, 0.42), UDim2.fromScale(0.3, 0.3))
local rareIcons = { "ICON_BOX_Rare", "ICON_BOX_Epic", "ICON_BOX_Legendary", "ICON_BOX_Mythic", "ICON_BOX_Secret", "ICON_BOX_Divine" }
for i = 1, 6 do
	local w = 0.14 + i * 0.004
	local cell = frame(odds, "Odd_" .. i, UDim2.fromScale(w, 0.66 + i * 0.05), UDim2.fromScale((i - 1) * 0.163, 1), Color3.fromRGB(40, 16, 80))
	cell.AnchorPoint = Vector2.new(0, 1)
	stroke(cell, 0.04)
	image(cell, "Icon", tex(rareIcons[i]), UDim2.fromScale(0.82, 0.7), UDim2.fromScale(0.5, 0.04), Vector2.new(0.5, 0))
	local chance = label(cell, "Chance", "?%", UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.5, 0.97), WHITE, Vector2.new(0.5, 1))
	chance.TextXAlignment = Enum.TextXAlignment.Right
end
local buyRow = frame(crate, "BuyRow", UDim2.fromScale(0.678, 0.18), UDim2.fromScale(0.3, 0.77))
for i, count in ipairs({ "×1", "×3", "×10" }) do
	local b = priceButton:Clone()
	b.Name = "BuyButton" .. i
	b.Size = UDim2.fromScale(0.315, 1)
	b.Position = UDim2.fromScale((i - 1) * 0.342, 0)
	local cnt = frame(b, "Count", UDim2.fromScale(0.3, 0.6), UDim2.fromScale(-0.03, -0.25), Color3.fromRGB(40, 16, 80))
	stroke(cnt, 0.05)
	local cl = label(cnt, "Label", count, UDim2.fromScale(0.85, 0.8), UDim2.fromScale(0.5, 0.5), GOLD, Vector2.new(0.5, 0.5))
	cl.TextXAlignment = Enum.TextXAlignment.Center
	local price = b:FindFirstChild("Price", true)
	if price and price:IsA("TextLabel") then
		price.Text = "?"
	end
	b.Parent = buyRow
end

-- 2. Offre vedette (Featured, Starter Pack)
local featured = frame(content, "Featured", UDim2.fromScale(0.98, 1), UDim2.new(), Color3.fromRGB(20, 40, 90))
featured.LayoutOrder = 2
featured.ClipsDescendants = true
local fRatio = Instance.new("UIAspectRatioConstraint")
fRatio.AspectRatio = 1130 / 170
fRatio.Parent = featured
stroke(featured, 0.02)
local fBack = image(featured, "Backdrop", tex("UI_Bg_StarterPack"), UDim2.fromScale(1, 1), UDim2.new())
fBack.ScaleType = Enum.ScaleType.Crop
image(featured, "Icon", tex("UI_Icon_DP_StarterPack"), UDim2.fromScale(0.15, 1.05), UDim2.fromScale(0.01, -0.02))
label(featured, "ItemName", "STARTER PACK", UDim2.fromScale(0.4, 0.3), UDim2.fromScale(0.17, 0.1))
label(featured, "Subtitle", "Only during your first hour", UDim2.fromScale(0.35, 0.15), UDim2.fromScale(0.17, 0.42), Color3.fromRGB(220, 230, 255))
local perks = frame(featured, "Perks", UDim2.fromScale(0.45, 0.22), UDim2.fromScale(0.17, 0.66))
local perkList = Instance.new("UIListLayout")
perkList.FillDirection = Enum.FillDirection.Horizontal
perkList.Padding = UDim.new(0.02, 0)
perkList.Parent = perks
for i, p in ipairs({ { "UI_Icon_GP_x2Cash", "×2 Cash 1h" }, { "UI_Icon_Upgrades", "Hammer" }, { "UI_Icon_DP_Cash_1", "$50K" } }) do
	local perk = frame(perks, "Perk" .. i, UDim2.fromScale(0.31, 1), UDim2.new(), Color3.fromRGB(15, 25, 55))
	perk.BackgroundTransparency = 0.2
	image(perk, "Icon", tex(p[1]), UDim2.fromScale(0.25, 0.9), UDim2.fromScale(0.03, 0.05))
	label(perk, "Label", p[2], UDim2.fromScale(0.68, 0.7), UDim2.fromScale(0.3, 0.15))
end
local timer = frame(featured, "Timer", UDim2.fromScale(0.2, 0.18), UDim2.fromScale(0.77, 0.12), Color3.fromRGB(200, 30, 50))
stroke(timer, 0.04)
local tl = label(timer, "Label", "Ends in 42:10", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.5, 0.5), WHITE, Vector2.new(0.5, 0.5))
tl.TextXAlignment = Enum.TextXAlignment.Center
local fBuy = priceButton:Clone()
fBuy.Name = "BuyButton"
fBuy.Size = UDim2.fromScale(0.2, 0.36)
fBuy.Position = UDim2.fromScale(0.77, 0.45)
local fPrice = fBuy:FindFirstChild("Price", true)
if fPrice and fPrice:IsA("TextLabel") then
	fPrice.Text = "99"
end
fBuy.Parent = featured

-- 3. Sections à cartes
local function section(name: string, title: string, order: number, previews: { { string } })
	local s = frame(content, name, UDim2.fromScale(0.98, 0), UDim2.new())
	s.LayoutOrder = order
	s.AutomaticSize = Enum.AutomaticSize.Y
	local sl = Instance.new("UIListLayout")
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Padding = UDim.new(0, 8)
	sl.Parent = s
	local header = frame(s, "Header", UDim2.new(1, 0, 0, 40), UDim2.new())
	header.LayoutOrder = 1
	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	hl.SortOrder = Enum.SortOrder.LayoutOrder
	hl.Padding = UDim.new(0.015, 0)
	hl.Parent = header
	for i = 1, 2 do
		local bar = frame(header, "Bar", UDim2.fromScale(0.09, 0.17), UDim2.new(), GOLD)
		bar.LayoutOrder = i == 1 and 1 or 3
	end
	local hlabel = label(header, "Label", title, UDim2.fromScale(0.3, 1), UDim2.new(), GOLD)
	hlabel.LayoutOrder = 2
	hlabel.TextXAlignment = Enum.TextXAlignment.Center
	local grid = frame(s, "Grid", UDim2.fromScale(1, 0), UDim2.new())
	grid.LayoutOrder = 2
	grid.AutomaticSize = Enum.AutomaticSize.Y
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromScale(0.232, 0)
	g.CellPadding = UDim2.fromScale(0.024, 0)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 262 / 320
	ratio.Parent = g
	g.Parent = grid
	local t = oldTemplate:Clone()
	t.Name = "Template"
	t.Visible = false
	t.Parent = grid
	for i, p in ipairs(previews) do
		local c = oldTemplate:Clone()
		c.Name = "Preview_" .. i
		c.Visible = true
		c.LayoutOrder = i
		local n = c:FindFirstChild("ItemName")
		if n and n:IsA("TextLabel") then
			n.Text = p[1]
		end
		local ic = c:FindFirstChild("Icon")
		if ic and ic:IsA("ImageLabel") then
			ic.Image = tex(p[2])
			ic:SetAttribute("IconAsset", p[2])
			ic.Size = UDim2.fromScale(0.62, 0.5)
		end
		local pr = c:FindFirstChild("Price", true)
		if pr and pr:IsA("TextLabel") then
			pr.Text = p[3]
		end
		local own = c:FindFirstChild("Owned")
		local buy = c:FindFirstChild("BuyRow")
		if own and own:IsA("GuiObject") and buy and buy:IsA("GuiObject") then
			own.Visible = false
			buy.Visible = true
		end
		c.Parent = grid
	end
end

-- Contenus d'aperçu : noms et prix de Config/Monetization (les prix « ? » sont à fixer par Cantin)
section("GamepassesSection", "GAMEPASSES", 3, {
	{ "×2 CASH", "UI_Icon_GP_x2Cash", "449" },
	{ "×2 TRAINING", "UI_Icon_GP_x2Training", "299" },
	{ "AUTO COLLECT", "UI_Icon_GP_AutoCollect", "199" },
	{ "FAST OPEN", "UI_Icon_GP_FastOpen", "299" },
	{ "+4 DISPLAYS", "UI_Icon_GP_Displays", "349" },
	{ "VIP", "UI_Icon_GP_VIP", "249" },
	{ "HYDRAULIC GLOVES", "UI_Icon_GP_HydraulicGloves", "499" },
})
section("BoostsSection", "BOOSTS", 4, {
	{ "×2 SPEED", "UI_Icon_SpeedBoost", "29" },
	{ "zZz", "UI_Icon_Sleep", "79" },
	{ "OPEN NOW", "UI_Icon_DP_OpenNow", "19" },
	{ "×3 LUCK", "UI_Icon_DP_Luck3", "79" },
	{ "30 MIN SHIELD", "UI_Icon_DP_Shield30", "99" },
	{ "REVENGE", "UI_Icon_DP_Revenge", "25" },
	{ "INSTANT SHUTTER", "UI_Icon_DP_InstantShutter", "29" },
})
section("CashSection", "CASH", 5, {
	{ "10 MIN OF CASH", "UI_Icon_DP_Cash_1", "49" },
	{ "1 HOUR OF CASH", "UI_Icon_DP_Cash_3", "199" },
	{ "5 HOURS OF CASH", "UI_Icon_DP_Cash_5", "799" },
})

gui.Parent = StarterGui

-- Corrections relevées en Studio le 2026-11-16 (ZIndex global, ancrage des prix, hauteurs) :
-- 1. l'écran est en ZIndexBehavior Global : tout ce qui est créé ici passe au-dessus du fond de fenêtre.
local function depthOf(o: Instance): number
	local d = 0
	local p = o.Parent
	while p and p ~= content do
		d += 1
		p = p.Parent
	end
	return d
end
for _, o in content:GetDescendants() do
	if o:IsA("GuiObject") and o.ZIndex < 4 then
		local d = depthOf(o)
		o.ZIndex = if o.Name == "Backdrop" or d == 0 then 4 else 5 + d
	end
end
for _, o in buyRow:GetDescendants() do
	if o:IsA("GuiObject") and (o.Name == "Count" or (o.Parent and o.Parent.Name == "Count")) then
		o.ZIndex = if o.Name == "Count" then 11 else 12
	end
end
-- 2. les boutons de prix clonés des cartes ont un AnchorPoint (0, 1) : on le remet à (0, 0).
for i = 1, 3 do
	local b = buyRow:FindFirstChild("BuyButton" .. i)
	if b and b:IsA("GuiObject") then
		b.AnchorPoint = Vector2.new(0, 0)
		b.Position = UDim2.fromScale((i - 1) * 0.342, 0)
	end
end
fBuy.AnchorPoint = Vector2.new(0, 0)
fBuy.Position = UDim2.fromScale(0.77, 0.45)
-- 3. hauteurs sans AutomaticSize (un parent automatique avec des enfants en Scale dérive) :
--    chaque section et la liste entière prennent leur hauteur par un rapport largeur / hauteur.
layout.Padding = UDim.new(0.012, 0)
local headerFrac = 0.07
for _, sec in { "GamepassesSection", "BoostsSection", "CashSection" } do
	local s = content:WaitForChild(sec) :: Frame
	local grid = s:WaitForChild("Grid") :: Frame
	local g = grid:WaitForChild("UIGridLayout") :: UIGridLayout
	local count = 0
	for _, c in grid:GetChildren() do
		if string.find(c.Name, "^Preview") then
			count += 1
		end
	end
	local rows = math.max(1, math.ceil(count / 4))
	local cellH = 0.232 / (262 / 320)
	local pad = 0.02
	local gridH = rows * cellH + (rows - 1) * pad
	local cellRatio = g:FindFirstChildOfClass("UIAspectRatioConstraint")
	if cellRatio then
		cellRatio:Destroy()
	end
	g.CellSize = UDim2.fromScale(0.232, cellH / gridH)
	g.CellPadding = UDim2.fromScale(0.024, pad / gridH)
	local total = gridH + headerFrac + 0.015
	s.AutomaticSize = Enum.AutomaticSize.None
	s.Size = UDim2.fromScale(0.98, 1)
	local sRatio = Instance.new("UIAspectRatioConstraint")
	sRatio.AspectRatio = 1 / total
	sRatio.Parent = s
	local header = s:WaitForChild("Header") :: Frame
	header.Size = UDim2.fromScale(1, headerFrac / total)
	grid.AutomaticSize = Enum.AutomaticSize.None
	grid.Size = UDim2.fromScale(1, gridH / total)
end
local frac = 0
local blocks = 0
for _, ch in content:GetChildren() do
	if ch:IsA("GuiObject") then
		local r = ch:FindFirstChildOfClass("UIAspectRatioConstraint")
		if r then
			frac += ch.Size.X.Scale / r.AspectRatio
			blocks += 1
		end
	end
end
frac += (blocks - 1) * 0.012 * 1.6 + 0.05
content.AutomaticSize = Enum.AutomaticSize.None
content.Size = UDim2.fromScale(1, 20)
local contentRatio = Instance.new("UIAspectRatioConstraint")
contentRatio.AspectRatio = 1 / frac
contentRatio.Parent = content
local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 6)
contentPad.PaddingBottom = UDim.new(0, 24)
contentPad.Parent = content

print("[ui_v4_robuxshop_build] UI_RobuxShop_v2 construit (désactivé)")
