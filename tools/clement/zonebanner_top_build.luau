--[[
	UI_ZoneBanner en haut de l'écran, plus petit, avec les icônes du HUD (retour de Clément, 2026-11-13,
	liaison L-117). À lancer en Edit. Annulable (Ctrl+Z).
	- Banner : collé en haut de la zone sûre (ScreenInsets = CoreUISafeInsets : sous la barre Roblox et
	  ses boutons, hors encoche), centré. Largeur = 14 % de l'écran + 190 px (un plancher pour le
	  téléphone sans UISizeConstraint, qui se battrait avec le rapport), rapport 3,4.
	- Lignes : ZoneName (la ville) en haut sur sa bande, puis Advice, puis Difficulty.
	- Advice : RecommendedLabel, SpeedIcon, Speed, DamageIcon, Damage (icônes de UI_HUD.StatsPanel).
	  Le code écrit encore « Speed 28 » et « Strength 80 » : Ironix n'y mettra que le chiffre (L-117).
	- Noms lus par le code inchangés : Banner.ZoneName, Advice.Speed, Advice.Damage, Difficulty.
	  Ajoutés, non lus : Advice.SpeedIcon et Advice.DamageIcon (ImageLabel, le fondu du code les prend).
	- Contours en ScaledSize 0,1 (comme le HUD) : un contour fixe de 3 px empâtait le petit texte.
	Aucun script.
]]

local CH = game:GetService("ChangeHistoryService")
local SPEED_ICON = "rbxassetid://80577187405028" -- UI_HUD.StatsPanel.SpeedRow.SpeedIcon.IconImage
local STRENGTH_ICON = "rbxassetid://84783828444327" -- UI_HUD.StatsPanel.StrengthDamageRow.StrengthIcon.IconImage

local gui = game.StarterGui:FindFirstChild("UI_ZoneBanner")
assert(gui, "UI_ZoneBanner introuvable")
local banner = gui:FindFirstChild("Banner")
local zoneName = banner and banner:FindFirstChild("ZoneName")
local advice = banner and banner:FindFirstChild("Advice")
local difficulty = gui:FindFirstChild("Difficulty", true)
assert(banner and zoneName and advice and difficulty, "Banner, ZoneName, Advice ou Difficulty introuvable")

local function stroke(t)
	local s = t:FindFirstChildOfClass("UIStroke")
	if s then
		s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		s.Thickness = 0.1
	end
end

local function icon(name, image, order)
	local i = advice:FindFirstChild(name)
	if not i then
		i = Instance.new("ImageLabel")
		i.Name = name
		i.BackgroundTransparency = 1
		i.ScaleType = Enum.ScaleType.Fit
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.Parent = i
		i.Parent = advice
	end
	i.Image = image
	i.Size = UDim2.fromScale(1, 0.95) -- dans la liste, le rapport 1 la rend carrée, haute comme la ligne
	i.LayoutOrder = order
	return i
end

local rec = CH:TryBeginRecording("UI_ZoneBanner en haut, plus petit, icônes du HUD (L-117)")

gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 4)
banner.Size = UDim2.new(0.14, 190, 1, 0)
local ar = banner:FindFirstChildOfClass("UIAspectRatioConstraint")
if ar then
	ar.AspectRatio = 3.4
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.AspectType = Enum.AspectType.ScaleWithParentSize
end

local strip = banner:FindFirstChild("Strip")
if strip then
	strip.Position = UDim2.fromScale(0, 0)
	strip.Size = UDim2.fromScale(1, 0.5)
end
zoneName.AnchorPoint = Vector2.new(0.5, 0)
zoneName.Position = UDim2.fromScale(0.5, 0.04)
zoneName.Size = UDim2.fromScale(0.9, 0.42)
stroke(zoneName)

advice.AnchorPoint = Vector2.new(0.5, 0)
advice.Position = UDim2.fromScale(0.5, 0.54)
advice.Size = UDim2.fromScale(0.94, 0.24)
local list = advice:FindFirstChildOfClass("UIListLayout")
if list then
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.012, 0)
end
local rl = advice:FindFirstChild("RecommendedLabel")
if rl then
	rl.LayoutOrder = 1
	rl.Size = UDim2.fromScale(0.4, 0.85)
	rl.TextXAlignment = Enum.TextXAlignment.Right
	stroke(rl)
end
icon("SpeedIcon", SPEED_ICON, 2)
local sp = advice:FindFirstChild("Speed")
sp.LayoutOrder = 3
sp.Size = UDim2.fromScale(0.15, 1)
sp.TextXAlignment = Enum.TextXAlignment.Left
sp.Text = "28"
stroke(sp)
icon("DamageIcon", STRENGTH_ICON, 4)
local dm = advice:FindFirstChild("Damage")
dm.LayoutOrder = 5
dm.Size = UDim2.fromScale(0.15, 1)
dm.TextXAlignment = Enum.TextXAlignment.Left
dm.Text = "80"
stroke(dm)

difficulty.AnchorPoint = Vector2.new(0.5, 0)
difficulty.Position = UDim2.fromScale(0.5, 0.8)
difficulty.Size = UDim2.fromScale(0.34, 0.19)
stroke(difficulty)

for _, t in gui:GetDescendants() do
	if t:IsA("TextLabel") then t.TextScaled = true; t.TextWrapped = true end
end

if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return "UI_ZoneBanner mis en haut, plus petit, avec SpeedIcon et DamageIcon"
