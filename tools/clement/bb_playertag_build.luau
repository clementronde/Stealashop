-- BB_PlayerTag : nom du joueur puis titre au-dessus de la tête (Clément, 2026-11-25).
-- v2 (réponse de Clément du 25/11 : « Prénom puis titre, les titres s'activent dans l'inventaire. Le owner, texte en
-- multicolore puis contour noir ») :
--   - NameLabel en haut, TitleLabel en dessous ;
--   - OWNER : texte arc-en-ciel (TextGradient multicolore, qui défile : Motion Spin) et contour noir ; plus de
--     contour arc-en-ciel (StrokeGradient retiré) ;
--   - OG violet (Pulse) et TESTER cyan (Scan) inchangés ;
--   - le joueur choisit son titre dans l'inventaire (UI_Inventory, onglet des titres : voir ui_inventaire_titres.luau).
-- Billboard modèle, sans script, dans ReplicatedStorage/Assets/UI. Le code de Cantin le clone sur la tête de chaque
-- joueur, écrit le nom et le titre choisi, applique le style du titre et joue le mouvement.
-- Styles (même modèle que Assets/UI/MutationStyles) : attributs Label, StrokeColor, StrokeThickness, LabelColor,
-- Motion (None, Shine, Pulse, Spin, Scan, Glitch), MotionPeriod ; UIGradient TagGradient et TextGradient.
-- À relancer sans risque : remplace BB_PlayerTag s'il existe.

local ui = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("UI")

local old = ui:FindFirstChild("BB_PlayerTag")
if old then
	old:Destroy()
end

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local BLACK = Color3.new(0, 0, 0)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D4D")),
	ColorSequenceKeypoint.new(0.17, Color3.fromHex("FFA63D")),
	ColorSequenceKeypoint.new(0.33, Color3.fromHex("FFE94D")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("5CFF6B")),
	ColorSequenceKeypoint.new(0.67, Color3.fromHex("4DC3FF")),
	ColorSequenceKeypoint.new(0.83, Color3.fromHex("9B6BFF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("FF6BE1")),
})

local function gradient(name: string, seq: ColorSequence, rotation: number, parent: Instance)
	local g = Instance.new("UIGradient")
	g.Name = name
	g.Rotation = rotation
	g.Color = seq
	g.Parent = parent
	return g
end

local function stroke(parent: Instance, name: string, thickness: number)
	local s = Instance.new("UIStroke")
	s.Name = name
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = BLACK
	s.Parent = parent
	return s
end

local function label(name: string, order: number, height: number, text: string, maxSize: number, parent: Instance)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, height)
	l.FontFace = FONT
	l.Text = text
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	return l
end

local bb = Instance.new("BillboardGui")
bb.Name = "BB_PlayerTag"
bb.Size = UDim2.new(6, 0, 1.7, 0)
bb.StudsOffset = Vector3.new(0, 2.3, 0)
bb.LightInfluence = 0
bb.MaxDistance = 90
bb.AlwaysOnTop = false
bb.ResetOnSpawn = false
bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bb:SetAttribute("Note", "Clone sur la tête de chaque joueur : NameLabel (nom), puis TitleLabel (titre choisi dans l'inventaire), caché sans titre. Style : TitleStyles/<Titre>.")

local tag = Instance.new("Frame")
tag.Name = "Tag"
tag.BackgroundTransparency = 1
tag.Size = UDim2.fromScale(1, 1)
tag.Parent = bb

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Bottom
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0.02, 0)
list.Parent = tag

local name = label("NameLabel", 1, 0.5, "PlayerName", 48, tag)
stroke(name, "NameStroke", 0.13)

local title = label("TitleLabel", 2, 0.4, "OWNER", 40, tag)
stroke(title, "TitleStroke", 0.14)
gradient("TextGradient", RAINBOW, 0, title)

local styles = Instance.new("Folder")
styles.Name = "TitleStyles"
styles.Parent = bb

local function style(id: string, labelText: string, seq: ColorSequence, rotation: number, strokeColor: Color3, motion: string, period: number)
	local f = Instance.new("Folder")
	f.Name = id
	f:SetAttribute("Label", labelText)
	f:SetAttribute("StrokeColor", strokeColor)
	f:SetAttribute("StrokeThickness", 0.14)
	f:SetAttribute("LabelColor", Color3.new(1, 1, 1))
	f:SetAttribute("Motion", motion)
	f:SetAttribute("MotionPeriod", period)
	gradient("TagGradient", seq, rotation, f)
	gradient("TextGradient", seq, rotation, f)
	f.Parent = styles
end

-- OWNER : texte arc-en-ciel qui défile (Spin fait tourner TextGradient), contour noir
style("Owner", "OWNER", RAINBOW, 0, BLACK, "Spin", 3)
style("OG", "OG", ColorSequence.new(Color3.fromHex("E3A6FF"), Color3.fromHex("8A2BFF")), 90, Color3.fromHex("2A0A4A"), "Pulse", 1.6)
style("Tester", "TESTER", ColorSequence.new(Color3.fromHex("8CFFF4"), Color3.fromHex("1FA8FF")), 90, Color3.fromHex("06324A"), "Scan", 1.5)

bb.Parent = ui
return "BB_PlayerTag v2 : nom puis titre ; OWNER texte arc-en-ciel, contour noir"
