-- Lot B des retours de test du 2026-11-25 : fenêtre Display (UI_Displayed) et bouton Display du HUD.
-- À lancer dans Studio en Edit. Ne touche aucun nom lu par le code (DisplayedController, HudMenuController).
--
-- (1) Trois lignes d'objets à l'ouverture, plus grandes, jamais coupées (Clément : « augmenter la taille de chaque ligne
--     pour qu'on ne voit que 3 lignes d'item à l'ouverture ») ; c'est l'inverse de L-320 (6 lignes basses).
--     Dock plus large (0,3 × 0,5 de l'écran, au moins 460 × 290 px), centré un peu plus bas pour rester sous la barre
--     de Roblox sur téléphone ; List.Template = 1/3 de la liste ; icône plus grande ; boutons côte à côte, 64 px de haut
--     au plus.
-- (2) DisplayBestButton vert (couleurs du bouton YES) avec un contour foncé autour de la face (la partie non ombrée).
-- (3) Bouton Display du HUD (RightRail et RightRailTouch) : le même contour foncé autour de sa face (Rectangle 2).
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_LotB (UI_Displayed et UI_HUD d'avant).

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

local displayed = StarterGui:FindFirstChild("UI_Displayed")
local hud = StarterGui:FindFirstChild("UI_HUD")
assert(displayed and hud, "UI_Displayed ou UI_HUD introuvable")

local backups = ServerStorage:FindFirstChild("MapBackups")
assert(backups, "MapBackups introuvable")
if not backups:FindFirstChild("2026-11-25_LotB") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_LotB"
	displayed:Clone().Parent = f
	hud:Clone().Parent = f
	f.Parent = backups
end

local GREEN_LIP = Color3.new(0.355098, 0.572941, 0.0547059)
local GREEN_FACE = Color3.new(0.603922, 1, 0.0352941)
local GREEN_TOP = Color3.new(0.714824, 1, 0.305412)
local LINE_GREEN = Color3.fromRGB(17, 57, 9) -- contour de la même teinte (recette des boutons, #113909)
local LINE_GOLD = Color3.fromRGB(74, 46, 6)

-- Contour foncé autour d'une face : un cadre transparent à la taille de la face, avec son UIStroke (pas sur la face
-- elle-même, pour que son UIGradient ne le teinte pas).
local function faceLine(face: GuiObject, color: Color3, thickness: number, sizing: Enum.StrokeSizingMode, radius: UDim)
	local line = face:FindFirstChild("FaceLine") or Instance.new("Frame")
	line.Name = "FaceLine"
	line.BackgroundTransparency = 1
	line.BorderSizePixel = 0
	line.Size = UDim2.fromScale(1, 1)
	line.Position = UDim2.fromScale(0, 0)
	line.AnchorPoint = Vector2.zero
	line.ZIndex = face.ZIndex
	line.Parent = face
	local corner = line:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = line
	local stroke = line:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	stroke.StrokeSizingMode = sizing
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.Transparency = 0
	stroke.Parent = line
end

-- (1) Dock et lignes
local dock = displayed:FindFirstChild("Dock")
assert(dock and dock:IsA("GuiObject"), "Dock introuvable")
dock.Size = UDim2.new(0.3, 0, 0.5, 0)
dock.Position = UDim2.new(1, -20, 0.5, 16)
local dockSize = dock:FindFirstChildOfClass("UISizeConstraint")
if dockSize then
	dockSize.MinSize = Vector2.new(460, 290)
	dockSize.MaxSize = Vector2.new(640, 860)
end
local template = dock:FindFirstChild("Template", true)
assert(template and template:IsA("GuiObject"), "List.Template introuvable")
template.Size = UDim2.new(0.96, 0, 1 / 3, -3) -- 3 lignes et 2 écarts de 4 px
local iconSlot = template:FindFirstChild("IconSlot")
if iconSlot and iconSlot:IsA("GuiObject") then
	iconSlot.Size = UDim2.new(0.28, 0, 0.84, 0)
end
local buttons = template:FindFirstChild("Buttons")
if buttons and buttons:IsA("GuiObject") then
	buttons.Size = UDim2.new(0.36, 0, 0.86, 0)
	local cap = buttons:FindFirstChild("MaxHeight") or Instance.new("UISizeConstraint")
	cap.Name = "MaxHeight"
	cap.MaxSize = Vector2.new(math.huge, 64)
	cap.Parent = buttons
end

-- (2) DisplayBestButton vert
local best = dock:FindFirstChild("DisplayBestButton")
assert(best, "DisplayBestButton introuvable")
local lip = best:FindFirstChild("Lip")
if lip and lip:IsA("GuiObject") then
	lip.BackgroundColor3 = GREEN_LIP
end
local face = best:FindFirstChild("Face")
if face and face:IsA("GuiObject") then
	face.BackgroundColor3 = GREEN_FACE
	local grad = face:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(GREEN_TOP, GREEN_FACE)
	end
	local lipStroke = lip and lip:FindFirstChildOfClass("UIStroke")
	local corner = face:FindFirstChildOfClass("UICorner")
	faceLine(face, LINE_GREEN, if lipStroke then lipStroke.Thickness else 0.07,
		if lipStroke then lipStroke.StrokeSizingMode else Enum.StrokeSizingMode.ScaledSize,
		if corner then corner.CornerRadius else UDim.new(0.2, 0))
end

-- (3) Bouton Display du HUD
for _, railName in { "RightRail", "RightRailTouch" } do
	local rail = hud:FindFirstChild(railName)
	local button = rail and rail:FindFirstChild("DisplayedButton")
	local rect = button and button:FindFirstChild("Rectangle 2")
	if rect and rect:IsA("GuiObject") then
		local corner = rect:FindFirstChildOfClass("UICorner")
		local white = rect:FindFirstChildOfClass("UIStroke")
		faceLine(rect, LINE_GOLD, if white then white.Thickness * 0.8 else 0.05,
			if white then white.StrokeSizingMode else Enum.StrokeSizingMode.ScaledSize,
			if corner then corner.CornerRadius else UDim.new(0, 0))
	end
end

-- (4) Les autres boutons de la fenêtre (CloseButton, RemoveButton, DisplayButton, SellButton, YesButton, NoButton) :
-- le même contour autour de la face, dans une teinte foncée de leur rebord, pour que la fenêtre reste homogène.
for _, b in dock:GetDescendants() do
	if b:IsA("GuiButton") and b.Name ~= "DisplayBestButton" then
		local bLip, bFace = b:FindFirstChild("Lip"), b:FindFirstChild("Face")
		if bLip and bFace and bLip:IsA("GuiObject") and bFace:IsA("GuiObject") then
			local s = bLip:FindFirstChildOfClass("UIStroke")
			local c = bLip.BackgroundColor3
			local corner = bFace:FindFirstChildOfClass("UICorner")
			faceLine(bFace, Color3.new(c.R * 0.3, c.G * 0.3, c.B * 0.3), if s then s.Thickness else 0.07,
				if s then s.StrokeSizingMode else Enum.StrokeSizingMode.ScaledSize,
				if corner then corner.CornerRadius else UDim.new(0.2, 0))
		end
	end
end

-- (5) Même taille de texte dans une ligne (retour du chef UI sur la capture PC) :
--     - Dock un peu plus large (0,32 de l'écran, au moins 500 px) et Buttons à 0,42 de la ligne : REMOVE et DISPLAY
--       plus grands ;
--     - la largeur de chaque libellé suit la longueur de son mot (REMOVE 157, DISPLAY 158, SELL 87 px à 40 px de
--       Montserrat gras) : les trois sont limités par leur largeur à la même échelle, donc à la même taille sur tous
--       les écrans ;
--     - ItemName sur 2 lignes possibles (0,46 de Info) et plafonné à 17 px (NameSize) : même taille de nom sur PC ;
--       sur téléphone, seuls les noms de plus de 20 lettres (« Laughing Monster Plush ») descendent à 13 px.
dock.Size = UDim2.new(0.32, 0, 0.5, 0)
if dockSize then
	dockSize.MinSize = Vector2.new(500, 290)
	dockSize.MaxSize = Vector2.new(660, 860)
end
if buttons and buttons:IsA("GuiObject") then
	buttons.Size = UDim2.new(0.42, 0, 0.86, 0)
	for bname, w in { RemoveButton = 0.855, DisplayButton = 0.86, SellButton = 0.474 } do
		local b = buttons:FindFirstChild(bname)
		if b then
			for _, l in b:GetChildren() do
				if l:IsA("TextLabel") then
					l.Size = UDim2.new(w, 0, l.Size.Y.Scale, l.Size.Y.Offset)
				end
			end
		end
	end
end
local info = template:FindFirstChild("Info")
if info then
	local chip = info:FindFirstChild("RarityChip")
	local itemName = info:FindFirstChild("ItemName")
	local income = info:FindFirstChild("Income")
	if chip and chip:IsA("GuiObject") then
		chip.Position = UDim2.fromScale(0, 0.02)
		chip.Size = UDim2.fromScale(1, 0.18)
	end
	if itemName and itemName:IsA("TextLabel") then
		itemName.Position = UDim2.fromScale(0, 0.22)
		itemName.Size = UDim2.fromScale(1, 0.46)
		itemName.TextWrapped = true
		itemName.TextScaled = true
		local cap = itemName:FindFirstChild("NameSize") or Instance.new("UITextSizeConstraint")
		cap.Name = "NameSize"
		cap.MaxTextSize = 17
		cap.Parent = itemName
	end
	if income and income:IsA("GuiObject") then
		income.Position = UDim2.fromScale(0, 0.7)
		income.Size = UDim2.fromScale(1, 0.26)
	end
end

print("[ui_lot_b_display] fait")
