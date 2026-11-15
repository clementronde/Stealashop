--!nonstrict
-- refonte_ui_hotbar.luau (refonte des écrans « AI slop », demande de Clément du 2026-11-15, écran 1 : UI_Hotbar).
-- Les cases prennent le style des tuiles du HUD (SettingsButton, la référence) : fond à studs, contour noir épais,
-- ombre dure, gros dessin de l'objet qui dépasse un peu du haut, nom blanc à contour, numéro dans une pastille
-- sombre au coin, revenu au dégradé vert de l'argent du HUD, pastille « ! » plus grande.
-- Aucun nom lu par HotbarController ne change : Bar, Template, Clip, Clip.Glow, Icon, KeyLabel, ItemName, Income,
-- Equipped, HoverOutline, AntiTheft, SlotAlert, SlotAlert.Pulse ; attributs SlotCount et TouchSlotCount gardés.
-- Ajoutés (décor, pas lus par le code) : Template.Shadow, Clip.Studs, Income.UIGradient, KeyLabel.UIPadding.
-- À lancer en Edit. Sauvegarde d'abord l'écran dans ServerStorage/MapBackups/2026-11-15_RefonteUI. Annulable.
-- Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_Hotbar
local t = gui.Bar.Template
assert(not t:FindFirstChild("Shadow"), "UI_Hotbar est déjà refaite")

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local STUDS = "rbxassetid://3014551673"
local SLATE = Color3.fromHex("3a404b") -- fond des fenêtres (10.6) : outils et cases vides
local RADIUS = 0.16

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
local function corner(o, r)
	local c = o:FindFirstChildOfClass("UICorner") or new("UICorner", {}, o)
	c.CornerRadius = UDim.new(r or RADIUS, 0)
end
local function stroke(o, t, mode, color, join)
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = t
	s.Color = color or BLACK
	s.ApplyStrokeMode = mode
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = join or Enum.LineJoinMode.Round
	return s
end
local function label(o, props)
	o.FontFace = HEAVY
	o.TextScaled = true
	o.TextWrapped = true
	for k, v in props do
		o[k] = v
	end
end

local rec = CHS:TryBeginRecording("Refonte UI : UI_Hotbar")
local ok, err = pcall(function()
	local backups = SS:FindFirstChild("MapBackups") or new("Folder", { Name = "MapBackups" }, SS)
	local folder = backups:FindFirstChild("2026-11-15_RefonteUI") or new("Folder", { Name = "2026-11-15_RefonteUI" }, backups)
	if not folder:FindFirstChild("UI_Hotbar") then
		local old = gui:Clone()
		old.Enabled = false
		old:SetAttribute("AncienEmplacement", "StarterGui.UI_Hotbar")
		old.Parent = folder
	end

	-- Barre : cases plus grandes sur PC (102 px en 1080), 44 px au moins sur téléphone ; remontée de 44 px pour
	-- passer au-dessus du compte à rebours de nuit du HUD sur téléphone (mesuré sans chevauchement de 750 × 350
	-- à 1920 × 1080, encoches comprises ; seul l'iPhone SE, 667 × 375, touche encore l'argent et SocialRow).
	local bar = gui.Bar
	bar.Position = UDim2.new(0.5, 14, 0.985, -44)
	bar.Size = UDim2.fromScale(0.62, 0.095)
	bar.WidthLimit.AspectRatio = 7.5
	bar.UISizeConstraint.MinSize = Vector2.new(0, 44)
	bar.UIListLayout.Padding = UDim.new(0, 10)

	-- Ombre dure sous la case (comme les tuiles du HUD).
	local shadow = new("Frame", {
		Name = "Shadow", Position = UDim2.fromScale(0, 0.06), Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 1,
	}, t)
	corner(shadow)
	stroke(shadow, 0.05, Enum.ApplyStrokeMode.Border)

	-- Fond : ardoise à studs (le code le recolore à la rareté pour un objet), contour noir épais.
	local clip = t.Clip
	clip.BackgroundColor3 = SLATE
	clip.ZIndex = 2
	corner(clip)
	stroke(clip, 0.05, Enum.ApplyStrokeMode.Border)
	clip.UIGradient.Color = ColorSequence.new(WHITE, Color3.fromHex("a8a8a8"))
	local studs = new("ImageLabel", {
		Name = "Studs", Image = STUDS, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageTransparency = 0.72,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromScale(0.34, 0.34), ZIndex = 3,
	}, clip)
	corner(studs)
	local glow = clip.Glow
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.42)
	glow.Size = UDim2.fromScale(1.25, 1.25)
	glow.ImageTransparency = 0.45
	glow.ZIndex = 4

	-- Gros dessin de l'objet, qui dépasse un peu du haut de la case.
	local icon = t.Icon
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.4)
	icon.Size = UDim2.fromScale(0.94, 0.94)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 5

	-- Nom en bas, blanc à contour noir.
	label(t.ItemName, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.97), Size = UDim2.fromScale(0.92, 0.25),
		TextColor3 = WHITE, ZIndex = 6,
	})
	stroke(t.ItemName, 0.12, Enum.ApplyStrokeMode.Contextual, BLACK, Enum.LineJoinMode.Bevel)

	-- Numéro de touche : pastille sombre au coin haut gauche (cachée sur téléphone par le code).
	local key = t.KeyLabel
	label(key, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.13, 0.13), Size = UDim2.fromScale(0.3, 0.3),
		TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = Color3.fromHex("1b1f27"),
		BackgroundTransparency = 0, ZIndex = 7,
	})
	if not key:FindFirstChildOfClass("UIAspectRatioConstraint") then
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, key)
	end
	corner(key, 0.3)
	stroke(key, 0.08, Enum.ApplyStrokeMode.Border)
	new("UIPadding", {
		PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0), PaddingLeft = UDim.new(0.16, 0), PaddingRight = UDim.new(0.16, 0),
	}, key)

	-- Revenu au-dessus de la case : même dégradé vert que l'argent du HUD.
	local income = t.Income
	label(income, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, -0.05), Size = UDim2.fromScale(1.08, 0.3),
		TextColor3 = WHITE, ZIndex = 6,
	})
	stroke(income, 0.13, Enum.ApplyStrokeMode.Contextual, BLACK, Enum.LineJoinMode.Bevel)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("d4ff5c"), Color3.fromHex("2fcb1f")), Rotation = 90 }, income)

	-- En main et survol : anneaux épais un peu plus grands que la case.
	for name, color in { Equipped = Color3.fromHex("7dff4a"), HoverOutline = WHITE } do
		local ring = t[name]
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(1.1, 1.1)
		corner(ring, 0.2)
		stroke(ring, if name == "Equipped" then 0.06 else 0.05, Enum.ApplyStrokeMode.Border, color)
	end

	-- Pastille « ! » : plus grande, au coin haut droit, qui déborde.
	local alert = t.SlotAlert
	alert.Position = UDim2.fromScale(0.87, 0.13)
	alert.Size = UDim2.fromScale(0.34, 0.34)
	alert.UIStroke.Thickness = 0.12
	label(alert.AlertLabel, { Size = UDim2.fromScale(0.7, 0.78) })
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Hotbar refaite"
