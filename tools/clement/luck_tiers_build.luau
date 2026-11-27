-- Paliers de la chance « ×N LUCK » (Clément, 27/11 : « plein de versions en fonction des paliers de luck, pour que ce
-- soit de plus en plus impressionnant ») ; chef UI.
-- v2 (27/11, retours de Clément sur la v1 : « très cool », mais la chance devient une stat qui grandit par zone, de 1 à
-- 100 en zone 1, puis de 100 à 10 000 en zone 2… jusqu'aux trillions ; l'arc-en-ciel est plus rare que l'or) :
--   - 13 paliers, un par ordre de grandeur : ×1, ×10, ×100, ×1K … ×1T. Les MinLuck sont des V0 : Cantin fixe les
--     vrais seuils (attribut MinLuck, ou une table dans Config, au choix du code) ;
--   - l'ordre des couleurs : vert, bleu, violet, or (Légendaire), rouge (Mythique), or pâle (Divin), puis l'arc-en-ciel
--     (Secret) tout en haut ; chaque couleur a deux crans (le second avec plus d'effet), l'arc-en-ciel en a trois ;
--   - chaque palier monte d'un cran : texte plus grand, contour plus épais, trèfle plus gros, halo, rayons, mouvement,
--     rebond, éclat VFX (BurstLevel 0 à 6, Assets/FX/FX_LuckTier_1 à _6 du chef VFX).
-- Même modèle que MutationStyles : un Folder par palier, des attributs, des UIGradient nommés. Sans script.
-- Halo et Rays cachés derrière le trèfle de BB_ShelfOpen.Row.LuckIcon (inchangés depuis la v1).
-- À relancer sans risque : remplace LuckTiers, Halo et Rays.

local ui = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("UI")
local hex = Color3.fromHex
local W = Color3.new(1, 1, 1)

local function seq(list)
	local kp = {}
	for i, c in list do
		table.insert(kp, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(kp)
end
local RAINBOW = { hex("#FF3B3B"), hex("#FFC21A"), hex("#3BE15A"), hex("#2F9BFF"), hex("#A855F7"), hex("#FF3B3B") }

-- couleurs (Config/Rarities, sauf le vert de départ = le compteur d'aujourd'hui)
local GREEN, BLUE, PURPLE, GOLD, RED, PALE = hex("#5CFF4A"), hex("#2F9BFF"), hex("#A855F7"), hex("#FFC21A"), hex("#FF3B5C"), hex("#FFE9A8")
local K, M, B, T = 1e3, 1e6, 1e9, 1e12

-- stylua: ignore
local TIERS = {
	{ MinLuck = 1,        Look = "Base",      Color = GREEN,  Stroke = hex("#000000"), Thick = 2.6, Text = 1.00, Icon = 1.00, Halo = false, Rays = false, Motion = "None",  Period = 0,   Pop = 1.10, Burst = 0 },
	{ MinLuck = 10,       Look = "Rare",      Color = BLUE,   Stroke = hex("#06213F"), Thick = 2.8, Text = 1.04, Icon = 1.03, Halo = false, Rays = false, Motion = "None",  Period = 0,   Pop = 1.12, Burst = 1 },
	{ MinLuck = 100,      Look = "Rare",      Color = BLUE,   Stroke = hex("#06213F"), Thick = 3.0, Text = 1.08, Icon = 1.06, Halo = false, Rays = false, Motion = "Shine", Period = 2.8, Pop = 1.14, Burst = 1 },
	{ MinLuck = 1 * K,    Look = "Epic",      Color = PURPLE, Stroke = hex("#2A0E45"), Thick = 3.2, Text = 1.12, Icon = 1.09, Halo = false, Rays = false, Motion = "Shine", Period = 2.5, Pop = 1.17, Burst = 2 },
	{ MinLuck = 10 * K,   Look = "Epic",      Color = PURPLE, Stroke = hex("#2A0E45"), Thick = 3.4, Text = 1.16, Icon = 1.12, Halo = true,  Rays = false, Motion = "Shine", Period = 2.2, Pop = 1.20, Burst = 2 },
	{ MinLuck = 100 * K,  Look = "Legendary", Color = GOLD,   Stroke = hex("#4A2E00"), Thick = 3.6, Text = 1.21, Icon = 1.16, Halo = true,  Rays = false, Motion = "Shine", Period = 2.0, Pop = 1.23, Burst = 3 },
	{ MinLuck = 1 * M,    Look = "Legendary", Color = GOLD,   Stroke = hex("#4A2E00"), Thick = 3.8, Text = 1.26, Icon = 1.20, Halo = true,  Rays = false, Motion = "Pulse", Period = 1.4, Pop = 1.26, Burst = 3 },
	{ MinLuck = 10 * M,   Look = "Mythic",    Color = RED,    Stroke = hex("#4A0614"), Thick = 4.0, Text = 1.31, Icon = 1.25, Halo = true,  Rays = false, Motion = "Pulse", Period = 1.2, Pop = 1.29, Burst = 4 },
	{ MinLuck = 100 * M,  Look = "Mythic",    Color = RED,    Stroke = hex("#4A0614"), Thick = 4.2, Text = 1.36, Icon = 1.30, Halo = true,  Rays = true,  Motion = "Pulse", Period = 1.0, Pop = 1.32, Burst = 4 },
	{ MinLuck = 1 * B,    Look = "Divine",    Color = PALE,   Stroke = hex("#3A2600"), Thick = 4.4, Text = 1.41, Icon = 1.35, Halo = true,  Rays = true,  Motion = "Spin",  Period = 2.2, Pop = 1.36, Burst = 5 },
	{ MinLuck = 10 * B,   Look = "Divine",    Color = PALE,   Stroke = hex("#3A2600"), Thick = 4.6, Text = 1.46, Icon = 1.40, Halo = true,  Rays = true,  Motion = "Spin",  Period = 1.8, Pop = 1.40, Burst = 5 },
	{ MinLuck = 100 * B,  Look = "Secret",    Color = RED,    Stroke = hex("#2B1240"), Thick = 4.8, Text = 1.52, Icon = 1.45, Halo = true,  Rays = true,  Motion = "Spin",  Period = 2.6, Pop = 1.45, Burst = 6 },
	{ MinLuck = 1 * T,    Look = "Secret",    Color = RED,    Stroke = hex("#2B1240"), Thick = 5.0, Text = 1.60, Icon = 1.50, Halo = true,  Rays = true,  Motion = "Spin",  Period = 1.4, Pop = 1.50, Burst = 6 },
}

local old = ui:FindFirstChild("LuckTiers")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "LuckTiers"
folder:SetAttribute("Note", "Paliers du compteur « ×N LUCK » (v2 chef UI, 27/11). Un par ordre de grandeur, ×1 à ×1T ; MinLuck V0, seuils réels de Cantin. Même modèle que MutationStyles : le code prend le dernier palier dont MinLuck ≤ la chance affichée.")
folder:SetAttribute("NumberFormat", "×%s LUCK, %s = 1 à 3 chiffres + K, M, B, T (×1.5K, ×250M, ×3.2T)")
for i, t in TIERS do
	local f = Instance.new("Folder")
	f.Name = string.format("Tier_%02d", i)
	f:SetAttribute("MinLuck", t.MinLuck)
	f:SetAttribute("RarityLook", t.Look)
	f:SetAttribute("LabelColor", W) -- le texte est blanc, coloré par TextGradient
	f:SetAttribute("StrokeColor", t.Stroke)
	f:SetAttribute("StrokeThickness", t.Thick) -- en px (le UIStroke de Row.Luck est en FixedSize, 2,6 aujourd'hui)
	f:SetAttribute("TextScale", t.Text) -- échelle du compteur (UIScale sur Row, taille du billboard suivie)
	f:SetAttribute("IconScale", t.Icon) -- échelle du trèfle, en plus de TextScale
	f:SetAttribute("IconHalo", t.Halo) -- Row.LuckIcon.Halo visible, teinté par HaloGradient
	f:SetAttribute("IconRays", t.Rays) -- Row.LuckIcon.Rays visible, qui tourne
	f:SetAttribute("Motion", t.Motion) -- None, Shine, Pulse, Spin (mêmes noms que MutationStyles)
	f:SetAttribute("MotionPeriod", t.Period)
	f:SetAttribute("Pop", t.Pop) -- rebond au changement de palier : × Pop puis 1
	f:SetAttribute("BurstLevel", t.Burst) -- éclat FX_LuckTier_<BurstLevel> autour du colis (0 = aucun)
	local g = Instance.new("UIGradient")
	g.Name = "TextGradient"
	if t.Look == "Secret" then
		g.Color = seq(RAINBOW)
		g.Rotation = 0
	elseif t.Look == "Divine" then
		g.Color = seq({ hex("#FFF6D6"), PALE, GOLD, PALE, W })
		g.Rotation = 0
	else
		g.Color = ColorSequence.new(t.Color:Lerp(W, 0.45), t.Color) -- clair en haut, couleur en bas
		g.Rotation = 90
	end
	g.Parent = f
	if t.Halo then
		local hg = Instance.new("UIGradient")
		hg.Name = "HaloGradient"
		hg.Color = if t.Look == "Secret" then seq(RAINBOW) else ColorSequence.new(t.Color)
		hg.Parent = f
	end
	f.Parent = folder
end
folder.Parent = ui

local icon = ui.BB_ShelfOpen.Row.LuckIcon
for _, spec in { { "Halo", "rbxassetid://130850617844067", 1.9, 0.15 }, { "Rays", "rbxassetid://96610322911997", 2.6, 0.35 } } do
	local prev = icon:FindFirstChild(spec[1])
	if prev then
		prev:Destroy()
	end
	local h = Instance.new("ImageLabel")
	h.Name = spec[1]
	h.Image = spec[2]
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(0.5, 0.5)
	h.Size = UDim2.fromScale(spec[3], spec[3])
	h.ImageTransparency = spec[4]
	h.ZIndex = 0
	h.Visible = false
	h.Parent = icon
end
