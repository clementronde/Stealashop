-- BB_TrainBubble : bulle ×N autour du joueur sur son tapis (Clément, 2026-11-26 ; chef UI).
-- Noms du contrat (src/shared/Contract/UI.luau, « Bulles ×N du tapis ») :
--   - Button : le disque cliquable ; le code anime son UIScale PopScale ;
--   - MultiplierLabel : le code y écrit « ×N » ;
--   - Shine : visible à partir de Config/Bubbles.Client.ShineFrom (×10 et ×20).
-- Rendu (fiche docs/claude/notes/2026-11-16_video-bulles-multiplicateur.md, sections 3 et 6) : disque à dégradé
-- vertical clair en haut et saturé en bas (bleu de la Vitesse, Config/Bubbles.Client.Fallback), anneau sombre de 3 %
-- du diamètre, icône Speed du HUD au centre (55 %), « ×N » blanc à gros contour noir en bas à droite, à cheval sur le
-- bord, penché de −10°. Pas de particules.
-- Shine est le premier enfant du bouton : son UIGradient est le premier que le code trouve et fait tourner.
-- Tout est en Scale (contours en ScaledSize) : le code peut changer la taille du BillboardGui sans rien casser.
-- Billboard modèle, sans script, dans ReplicatedStorage/Assets/UI. À relancer sans risque : remplace le modèle.

local ui = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("UI")
local old = ui:FindFirstChild("BB_TrainBubble")
if old then
	old:Destroy()
end

local hex = Color3.fromHex
local heavy = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local SPEED_ICON = "rbxassetid://80577187405028" -- icône Speed du HUD (StatsPanel.SpeedRow) et de BB_Gain

local function corner(parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = parent
end

local function ring(parent, name, color)
	local s = Instance.new("UIStroke")
	s.Name = name
	s.Color = color
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.03
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local gui = Instance.new("BillboardGui")
gui.Name = "BB_TrainBubble"
gui.Size = UDim2.fromOffset(150, 150) -- bouton de 100 px ; le code règle la taille (11,8 % de la hauteur)
gui.LightInfluence = 0
gui.AlwaysOnTop = true
gui.ResetOnSpawn = false
gui.Active = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local button = Instance.new("TextButton")
button.Name = "Button"
button.Text = ""
button.AutoButtonColor = false
button.AnchorPoint = Vector2.new(0.5, 0.5)
button.Position = UDim2.fromScale(0.5, 0.5)
button.Size = UDim2.fromScale(0.667, 0.667)
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.BorderSizePixel = 0
button.ZIndex = 1
button.Parent = gui

local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.Size = UDim2.fromScale(1, 1)
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.BorderSizePixel = 0
shine.ZIndex = 2
shine.Visible = false
shine.Parent = button
corner(shine)
local shineFill = Instance.new("UIGradient")
shineFill.Name = "ShineFill"
shineFill.Rotation = 90
shineFill.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hex("FFF4B0")),
	ColorSequenceKeypoint.new(0.45, hex("FFD23F")),
	ColorSequenceKeypoint.new(1, hex("F5A300")),
})
shineFill.Parent = shine
ring(shine, "ShineRing", hex("8A4B00"))

corner(button)
local fill = Instance.new("UIGradient")
fill.Name = "Fill"
fill.Rotation = 90
fill.Color = ColorSequence.new(hex("BFF0FF"), hex("1E8FE8"))
fill.Parent = button
ring(button, "Ring", hex("0B3A6B"))
local pop = Instance.new("UIScale")
pop.Name = "PopScale"
pop.Parent = button

local icon = Instance.new("ImageLabel")
icon.Name = "Icon"
icon.Image = SPEED_ICON
icon.BackgroundTransparency = 1
icon.AnchorPoint = Vector2.new(0.5, 0.5)
icon.Position = UDim2.fromScale(0.5, 0.48)
icon.Size = UDim2.fromScale(0.55, 0.55)
icon.ScaleType = Enum.ScaleType.Fit
icon.ZIndex = 3
icon.Parent = button

local label = Instance.new("TextLabel")
label.Name = "MultiplierLabel"
label.Text = "×2"
label.FontFace = heavy
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.BackgroundTransparency = 1
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.84, 0.86)
label.Size = UDim2.fromScale(0.8, 0.34)
label.Rotation = -10
label.ZIndex = 5
label.Parent = button
local outline = Instance.new("UIStroke")
outline.Color = Color3.new(0, 0, 0)
outline.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
outline.Thickness = 0.12
outline.LineJoinMode = Enum.LineJoinMode.Round
outline.Parent = label

gui.Parent = ui
