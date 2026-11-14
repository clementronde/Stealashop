--!nonstrict
-- wheel_style.luau (L-165, 2026-11-14) : habillage de StarterGui/UI_Wheel dans le style du jeu, après
-- hub_ui_build.luau (version grise). Aucun nom lu par le code ne change : Wheel, Segment_01 à _08 (Icon,
-- Amount), SpinButton, CloseButton, Timer, Result. Repris de UI_Rebirth : ombre, fenêtre à studs, en-tête à
-- reflet, bouton X rouge ; bouton vert comme ceux du HUD. Annulable (ChangeHistoryService). Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")

local gui = SG.UI_Wheel
local rebirth = SG.UI_Rebirth.Root
local root = gui.Root
local window = root.Window
assert(not window:FindFirstChild("Header"), "UI_Wheel est déjà habillé")

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://3014551673"
local ICON_CASH = "rbxassetid://138179722277427"
local SEGMENT_COLORS = { -- haut → bas du dégradé, un par segment
	{ "ff5a5a", "d81f2a" }, { "4fb4ff", "1e72e0" }, { "7be84f", "2fae46" }, { "c36bff", "8a2be2" },
	{ "ffb23a", "f07a12" }, { "ff6fcf", "d62f9f" }, { "4fe3d9", "15a8a8" }, { "ffe14a", "f0b414" },
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
local function grad(parent, a, b, rot)
	return new("UIGradient", { Color = ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b)), Rotation = rot or 90 }, parent)
end
local function textStroke(label, t)
	local s = label:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, label)
	s.Thickness = t or 0.1
	s.Color = BLACK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
end
local function borderStroke(obj, t)
	new("UIStroke", {
		Thickness = t, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Round,
	}, obj)
end
local function studs(parent, transparency, tile, z, cornerScale)
	local s = new("ImageLabel", {
		Name = "Studs", Image = STUDS, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ImageTransparency = transparency, ScaleType = Enum.ScaleType.Tile, TileSize = tile, ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(cornerScale, 0) }, s)
	return s
end

local rec = CHS:TryBeginRecording("UI_Wheel : habillage (L-165)")

-- Fenêtre : ombre, fond, contour et studs de UI_Rebirth.
local shadow = rebirth.WindowShadow:Clone()
shadow.Position = UDim2.fromScale(0.02, 0.035)
shadow.Size = UDim2.fromScale(0.98, 0.975)
shadow.Parent = root
window.Position = UDim2.fromScale(0, 0)
window.Size = UDim2.fromScale(0.98, 0.975)
window.ZIndex = 2
window.BackgroundColor3 = rebirth.Window.BackgroundColor3
local windowCorner = window:FindFirstChildOfClass("UICorner") or new("UICorner", {}, window)
windowCorner.CornerRadius = rebirth.Window.UICorner.CornerRadius
rebirth.Window.UIStroke:Clone().Parent = window
local winStuds = rebirth.Window.Studs:Clone()
winStuds.Parent = window

-- En-tête doré (celui de UI_Rebirth, recoloré) ; le titre gris part dedans.
window.Title:Destroy()
local header = rebirth.Window.Header:Clone()
header.UIGradient.Color = ColorSequence.new(Color3.fromHex("ffcf3a"), Color3.fromHex("f08a12"))
header.HeaderFill.UIGradient.Color = ColorSequence.new(Color3.fromHex("ffad2a"), Color3.fromHex("f08a12"))
header.Title.Text = "Spin the Wheel"
header.Title.Size = UDim2.fromScale(0.6, 0.7)
header.Parent = window

-- Bouton X rouge de UI_Rebirth (même nom, même XLabel).
window.CloseButton:Destroy()
local close = rebirth.Window.CloseButton:Clone()
close.Parent = window

-- Roue : cercle bleu nuit à studs, cerclé d'or ; rayons dorés ; segments en pastilles de couleur.
local area = window.WheelArea
area.ZIndex = 3 -- au-dessus des studs de la fenêtre (ZIndexBehavior Sibling)
local wheel = area.Wheel
local rim = new("Frame", {
	Name = "Rim", AnchorPoint = Vector2.new(0.5, 0.5), Position = wheel.Position, Size = UDim2.fromScale(0.94 * 1.07, 0.94 * 1.07),
	BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2,
}, area)
new("UIAspectRatioConstraint", { AspectRatio = 1 }, rim)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, rim)
grad(rim, "ffe14a", "e08a12", 90)
borderStroke(rim, 0.022)
wheel.ZIndex = 3
wheel.BackgroundColor3 = WHITE
grad(wheel, "33408f", "151a44", 90)
borderStroke(wheel, 0.012)
studs(wheel, 0.85, UDim2.fromScale(0.08, 0.08), 3, 0.5)
for _, child in wheel:GetChildren() do
	if child.Name:match("^Divider_") then
		child.BackgroundColor3 = Color3.fromHex("ffd23a")
		child.Size = UDim2.fromScale(0.014, 1)
		child.ZIndex = 4
	end
end
for n = 1, 8 do
	local seg = wheel[string.format("Segment_%02d", n)]
	local c = SEGMENT_COLORS[n]
	seg.BackgroundTransparency = 0
	seg.BackgroundColor3 = WHITE
	seg.ZIndex = 5
	seg.Size = UDim2.fromScale(0.21, 0.21)
	new("UICorner", { CornerRadius = UDim.new(0.28, 0) }, seg)
	grad(seg, c[1], c[2], 90)
	borderStroke(seg, 0.05)
	studs(seg, 0.6, UDim2.fromScale(0.34, 0.34), 6, 0.28)
	seg.Icon.BackgroundTransparency = 1
	seg.Icon.Image = ICON_CASH -- exemple : le code y pose l'icône du lot
	seg.Icon.Position = UDim2.fromScale(0.5, 0.06)
	seg.Icon.Size = UDim2.fromScale(0.6, 0.52)
	seg.Icon.ZIndex = 7
	seg.Amount.ZIndex = 7
	seg.Amount.Position = UDim2.fromScale(0.04, 0.58)
	seg.Amount.Size = UDim2.fromScale(0.92, 0.36)
	textStroke(seg.Amount, 0.12)
end
local hub = wheel.Hub
hub.BackgroundColor3 = WHITE
hub.ZIndex = 8
hub.Size = UDim2.fromScale(0.2, 0.2)
grad(hub, "ffe14a", "e08a12", 90)
borderStroke(hub, 0.08)
local hubIcon = new("ImageLabel", {
	Name = "HubIcon", Image = ICON_CASH, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ZIndex = 9,
}, hub)
new("UIAspectRatioConstraint", { AspectRatio = 1 }, hubIcon)

-- Pointeur rouge (losange), fixe, au-dessus de la roue.
local pointer = area.Pointer
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Position = UDim2.fromScale(0.5, 0.075)
pointer.Size = UDim2.fromScale(0.085, 0.085)
pointer.Rotation = 45
pointer.BackgroundColor3 = WHITE
pointer.ZIndex = 10
new("UIAspectRatioConstraint", { AspectRatio = 1 }, pointer)
new("UICorner", { CornerRadius = UDim.new(0.18, 0) }, pointer)
grad(pointer, "ff5a5a", "c4161c", 45)
borderStroke(pointer, 0.12)

-- Résultat : bandeau sombre cerclé d'or, texte doré.
local result = area.Result
result.ZIndex = 11
result.BackgroundColor3 = Color3.fromHex("1b1f27")
result.BackgroundTransparency = 0.08
result.TextColor3 = Color3.fromHex("ffd23a")
new("UIStroke", {
	Thickness = 0.03, Color = Color3.fromHex("ffc21a"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Round,
}, result)
new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), PaddingLeft = UDim.new(0.05, 0), PaddingRight = UDim.new(0.05, 0) }, result)

-- Colonne de droite : textes blancs à contour, bouton vert du HUD.
local side = window.Side
side.ZIndex = 3
textStroke(side.Info, 0.1)
side.Info.ZIndex = 4
side.Timer.TextColor3 = Color3.fromHex("ffd23a")
side.Timer.ZIndex = 4
textStroke(side.Timer, 0.1)
local spin = side.SpinButton
spin.BackgroundColor3 = WHITE
spin.AutoButtonColor = false
spin.ZIndex = 5
new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, spin)
grad(spin, "91f630", "31dd22", 90)
borderStroke(spin, 0.05)
studs(spin, 0.55, UDim2.fromScale(0.13, 0.6), 6, 0.2)
local spinShadow = new("Frame", {
	Name = "ButtonShadow", AnchorPoint = spin.AnchorPoint, Position = spin.Position + UDim2.fromScale(0, 0.025), Size = spin.Size,
	BackgroundColor3 = BLACK, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 4,
}, side)
new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, spinShadow)
new("UISizeConstraint", { MinSize = Vector2.new(120, 44) }, spinShadow)
spin.SpinLabel.Text = "SPIN!"
spin.SpinLabel.TextColor3 = WHITE
spin.SpinLabel.ZIndex = 8
textStroke(spin.SpinLabel, 0.12)
local shade = new("Frame", {
	Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9,
}, spin)
new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, shade)

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return "UI_Wheel habillé"
