--!nonstrict
-- ui_tas_tutorial.luau (demande de Clément du 2026-11-17, d'après Throw a Seed, note section 6 : « les trois guides ») :
--   1. Chevrons au sol qui défilent vers la cible : déjà là (FX_Tutorial_Arrow, Beam avec la texture de chevrons
--      FX_Tutorial_Chevron, TextureMode Wrap, TextureSpeed). Rien à changer ici.
--   2. Grand V au-dessus de la cible : FX_Tutorial_Marker.Root.Pointer.Arrow n'est plus le « ▼ » plein mais le V de la
--      même image de chevrons (rbxassetid://134123418187915), jaune en dégradé, contour sombre de l'image ; le V est plus
--      grand (3,4 studs) et plus haut (3,2 studs au-dessus de la cible). Le rebond est au code (comme le repère V0).
--   3. Écran assombri sauf le bon bouton : nouvel écran UI_TutorialFocus (DisplayOrder 60, au-dessus de tout, inset
--      ignoré, éteint) :
--        Focus    Frame transparent que le code pose sur le bouton visé (même rectangle, plus une marge) ; son UIStroke
--                 « Veil », noir et immense (4000 px), assombrit tout l'écran à 65 % sauf le trou ; coins arrondis.
--        Ring     l'anneau jaune autour du bouton (dans Focus, 8 px de marge, contour 4 px).
--        Pointer  le même V jaune, au-dessus de l'anneau, qui pointe vers le bouton ; caché : le code le fait venir quand
--                 le joueur hésite (1,2 s d'après la note).
--      Le voile ne bloque pas les clics (un contour ne capte rien) : griser ou bloquer l'autre bouton reste au code.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-17_ThrowASeed/FX_Tutorial_Marker. Peut se relancer, en Edit.
-- Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local CHEVRON = "rbxassetid://134123418187915" -- FX_Tutorial_Chevron (V blanc à contour noir), déjà importé au nom du groupe
local YELLOW = ColorSequence.new(Color3.fromHex("fff27a"), Color3.fromHex("ffb81f"))

local function ensure(parent, class, name)
	local x = parent:FindFirstChild(name)
	if x ~= nil and not x:IsA(class) then
		x:Destroy()
		x = nil
	end
	if x == nil then
		x = Instance.new(class)
		x.Name = name
		x.Parent = parent
	end
	return x
end
local function yellowV(image)
	image.Image = CHEVRON
	image.ImageColor3 = Color3.new(1, 1, 1)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	local g = ensure(image, "UIGradient", "UIGradient")
	g.Rotation = 90
	g.Color = YELLOW
end

local rec = CHS:TryBeginRecording("UI : guides du tuto façon Throw a Seed (grand V, écran assombri)")
local ok, err = pcall(function()
	local folder = SS.MapBackups["2026-11-17_ThrowASeed"]
	local marker = RS.Assets.FX.FX_Tutorial_Marker
	if not folder:FindFirstChild("FX_Tutorial_Marker") then
		marker:Clone().Parent = folder
	end

	-- 2. Grand V.
	local pointer = marker.Root.Pointer
	pointer.Size = UDim2.new(3.4, 48, 3.4, 48)
	pointer.StudsOffset = Vector3.new(0, 3.2, 0)
	local oldArrow = pointer:FindFirstChild("Arrow")
	local z = if oldArrow and oldArrow:IsA("GuiObject") then oldArrow.ZIndex else 2
	local arrow = ensure(pointer, "ImageLabel", "Arrow")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.ZIndex = z
	yellowV(arrow)

	-- 3. Écran assombri.
	local gui = SG:FindFirstChild("UI_TutorialFocus")
	if gui == nil then
		gui = Instance.new("ScreenGui")
		gui.Name = "UI_TutorialFocus"
		gui.Parent = SG
	end
	gui.Enabled = false
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local focus = ensure(gui, "Frame", "Focus")
	focus.AnchorPoint = Vector2.new(0.5, 0.5)
	focus.Position = UDim2.fromScale(0.5, 0.5) -- posé par le code sur le bouton visé
	focus.Size = UDim2.fromScale(0.12, 0.08)
	focus.BackgroundTransparency = 1
	focus.BorderSizePixel = 0
	local veil = ensure(focus, "UIStroke", "Veil")
	veil.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	veil.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	veil.Thickness = 4000
	veil.Color = Color3.new(0, 0, 0)
	veil.Transparency = 0.35
	veil.LineJoinMode = Enum.LineJoinMode.Round
	local corner = ensure(focus, "UICorner", "UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)

	local ring = ensure(focus, "Frame", "Ring")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, 16, 1, 16)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 2
	local ringStroke = ensure(ring, "UIStroke", "UIStroke")
	ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ringStroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	ringStroke.Thickness = 4
	ringStroke.Color = Color3.fromHex("ffd23a")
	ringStroke.Transparency = 0
	ensure(ring, "UICorner", "UICorner").CornerRadius = UDim.new(0.2, 0)

	local pointerUi = ensure(focus, "ImageLabel", "Pointer")
	pointerUi.AnchorPoint = Vector2.new(0.5, 1)
	pointerUi.Position = UDim2.new(0.5, 0, 0, -14)
	pointerUi.Size = UDim2.fromScale(1, 1)
	pointerUi.ZIndex = 3
	pointerUi.Visible = false -- le code le fait venir quand le joueur hésite
	yellowV(pointerUi)
	local ar = ensure(pointerUi, "UIAspectRatioConstraint", "UIAspectRatioConstraint")
	ar.AspectRatio = 1
	local size = ensure(pointerUi, "UISizeConstraint", "UISizeConstraint")
	size.MinSize = Vector2.new(48, 48)
	size.MaxSize = Vector2.new(88, 88)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "guides du tuto : grand V, écran assombri"
