--!strict
-- Style v3 de UI_RobuxShop, d'après Break and Steal an Egg (Clément, 2026-11-15 et 16).
-- À lancer dans la barre de commande de Studio (mode Edit). Ne change aucun nom lu par le code
-- (RobuxShopController) : seulement des tailles, des positions et l'habillage.
--   - studs seulement en fond de la fenêtre, à faible opacité ;
--   - coins droits partout, contour noir épais ;
--   - grille de 3 colonnes bord à bord, 2 rangées entières visibles ;
--   - dessins dans leur carte, une seule ligne de texte (Effect caché) ;
--   - onglets agrandis à droite (grosse icône, nom dessous).
-- Paramètre : TARGET = l'écran à modifier (StarterGui par défaut, ou une copie de test).

local TARGET: ScreenGui = game:GetService("StarterGui"):WaitForChild("UI_RobuxShop") :: ScreenGui
local DARK = Color3.fromRGB(20, 20, 26)

local root = TARGET:WaitForChild("Root") :: Frame
local window = root:WaitForChild("Window") :: Frame

local function square(o: Instance)
	for _, c in o:GetDescendants() do
		if c:IsA("UICorner") then
			local parent = c.Parent
			-- le bouton de prix garde son léger arrondi (règle : seuls les boutons de paiement sont arrondis)
			if not (parent and (parent.Name == "BuyButton" or parent.Name == "Owned")) then
				c.CornerRadius = UDim.new(0, 0)
			end
		end
	end
	local own = o:FindFirstChildOfClass("UICorner")
	if own then
		own.CornerRadius = UDim.new(0, 0)
	end
end

-- 1. Studs : seulement en fond de fenêtre, très légers
for _, d in TARGET:GetDescendants() do
	if d.Name == "Studs" and d:IsA("GuiObject") then
		d.Visible = false
	end
end
local windowStuds = window:FindFirstChild("Studs")
if windowStuds and windowStuds:IsA("ImageLabel") then
	windowStuds.Visible = true
	windowStuds.ImageTransparency = 0.85
end

-- 2. Cadre droit, contour noir épais, titre centré
square(window)
local shadow = root:FindFirstChild("WindowShadow")
if shadow then
	square(shadow)
end
local stroke = window:FindFirstChildOfClass("UIStroke")
if stroke then
	stroke.Thickness = 0.012
	stroke.Color = DARK
end
local header = window:WaitForChild("Header") :: Frame
square(header)
local title = header:WaitForChild("Title") :: TextLabel
title.Size = UDim2.fromScale(0.5, 0.86)
title.AnchorPoint = Vector2.new(title.AnchorPoint.X, 0.5)
title.Position = UDim2.new(title.Position.X.Scale, title.Position.X.Offset, 0.5, 0)

-- 3. Grille bord à bord, 3 colonnes, 2 rangées entières
local list = window:WaitForChild("List") :: ScrollingFrame
local grid = list:WaitForChild("UIGridLayout") :: UIGridLayout
list.Position = UDim2.fromScale(0.012, 0.155)
list.Size = UDim2.fromScale(0.976, 0.83)
list.ScrollBarThickness = 6
grid.CellSize = UDim2.new(0.322, 0, 0, 10000)
grid.CellPadding = UDim2.new(0.012, 0, 0, 8)
local gridSize = grid:FindFirstChildOfClass("UISizeConstraint")
if gridSize then
	gridSize.MinSize = Vector2.new(0, 0)
end
local gridRatio = grid:FindFirstChildOfClass("UIAspectRatioConstraint")
if gridRatio then
	gridRatio.AspectRatio = 1.32
end
local padding = list:FindFirstChildOfClass("UIPadding")
if padding then
	padding.PaddingLeft = UDim.new(0, 0)
	padding.PaddingRight = UDim.new(0, 0)
	padding.PaddingTop = UDim.new(0, 4)
end

-- 4. Cartes : droites, contour noir, dessin dans le cadre, une ligne de texte
for _, card in list:GetChildren() do
	if card:IsA("Frame") and (card.Name == "Template" or string.find(card.Name, "^Preview")) then
		square(card)
		local cardStroke = card:FindFirstChildOfClass("UIStroke")
		if cardStroke then
			cardStroke.Color = DARK
			cardStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
			cardStroke.Thickness = 0.03
		end
		local icon = card:FindFirstChild("Icon")
		local name = card:FindFirstChild("ItemName")
		local effect = card:FindFirstChild("Effect")
		local buy = card:FindFirstChild("BuyRow")
		local owned = card:FindFirstChild("Owned")
		if icon and icon:IsA("GuiObject") then
			icon.Size = UDim2.fromScale(0.5, 0.44)
			icon.Position = UDim2.fromScale(0.5, 0.05)
			if name and name:IsA("GuiObject") then
				name.Position = UDim2.fromScale(0.5, 0.5)
				name.Size = UDim2.fromScale(0.97, 0.18)
				name.ZIndex = icon.ZIndex + 1
			end
		end
		if effect and effect:IsA("GuiObject") then
			effect.Visible = false
		end
		if buy and buy:IsA("GuiObject") then
			buy.Position = UDim2.fromScale(0.04, 0.955)
			buy.Size = UDim2.fromScale(0.92, 0.25)
			if owned and owned:IsA("GuiObject") then
				owned.Position = buy.Position
				owned.Size = buy.Size
			end
		end
	end
end

-- 5. Onglets agrandis : grosse icône, nom dessous (comme la référence)
local tabs = root:FindFirstChild("Tabs")
if tabs and tabs:IsA("Frame") then
	tabs.Size = UDim2.fromScale(0.15, 0.86)
	tabs.Position = UDim2.fromScale(0.862, 0.05)
	for _, tab in tabs:GetChildren() do
		if tab:IsA("TextButton") then
			tab.Size = UDim2.fromScale(1, 0.24)
			local ratio = tab:FindFirstChildOfClass("UIAspectRatioConstraint")
			if ratio then
				ratio.AspectRatio = 1.15
			end
			local tabIcon = tab:FindFirstChild("TabIcon")
			local tabLabel = tab:FindFirstChild("TabLabel")
			if tabIcon and tabIcon:IsA("GuiObject") then
				tabIcon.Size = UDim2.fromScale(0.78, 0.8)
				tabIcon.Position = UDim2.fromScale(0.5, 0)
			end
			if tabLabel and tabLabel:IsA("GuiObject") then
				tabLabel.Size = UDim2.fromScale(1.15, 0.34)
				tabLabel.Position = UDim2.fromScale(0.5, 1.02)
			end
		end
	end
end

print("[ui_v3_robuxshop] style v3 posé sur " .. TARGET:GetFullName())
