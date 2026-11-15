--!nocheck
-- UI_Loading (écran de chargement, proposition A « affiche »), construit dans ReplicatedFirst.
-- À lancer en Edit (barre de commande ou execute_luau). Relançable : remplace l'ancien UI_Loading.
-- Aucun script dedans : le code d'Ironix le clone dans PlayerGui depuis ReplicatedFirst.

local KEYART = "rbxassetid://0" -- UI_Loading_KeyArt (groupe RoundStone Studio), remplacé après l'import
local LOGO = "rbxassetid://0" -- UI_Loading_Logo (groupe RoundStone Studio), remplacé après l'import
local RAYS ="rbxassetid://96610322911997" -- UI_Rays_Soft (groupe), déjà utilisée par les cartes de boutique

local NAVY = Color3.fromHex("040435")
local YELLOW = Color3.fromHex("FFD23A")
local SKY = Color3.fromHex("006EF5")
local MONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function stroke(parent, thickness, mode)
	return make("UIStroke", parent, {
		Color = NAVY,
		Thickness = thickness,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function label(parent, props)
	local l = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		TextScaled = true,
		TextWrapped = true,
		FontFace = MONT,
		TextColor3 = Color3.new(1, 1, 1),
	})
	for k, v in props do
		l[k] = v
	end
	return l
end

local RF = game:GetService("ReplicatedFirst")
local old = RF:FindFirstChild("UI_Loading")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "UI_Loading"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = make("Frame", gui, { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundColor3 = SKY, BorderSizePixel = 0 })

-- Illustration à droite, rayons derrière qui prolongent ceux de l'image jusqu'au bord gauche
local hero = make("Frame", root, {
	Name = "Hero",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.fromScale(0.62, 1),
	BackgroundTransparency = 1,
	ZIndex = 1,
})
make("UIAspectRatioConstraint", hero, { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Height })
make("ImageLabel", hero, {
	Name = "Rays",
	Image = RAYS,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.55, 0.42),
	Size = UDim2.fromScale(4, 4),
	BackgroundTransparency = 1,
	ImageColor3 = Color3.fromHex("5CC8FF"),
	ImageTransparency = 0.45,
	ZIndex = 1,
})
local art = make("ImageLabel", hero, {
	Name = "Art",
	Image = KEYART,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 2,
})
-- raccord court sur le bord gauche de l'image (pas un fond en dégradé)
make("UIGradient", art, {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.16, 0),
		NumberSequenceKeypoint.new(1, 0),
	}),
})

-- Logo en image (un texte Roblox plafonne à 100 px : trop petit sur PC). Rendu par
-- StealAShop-Art/UI/Loading/_scripts/logo.py (Luckiest Guy, contour et ombre dure marine, penché).
local logo = make("ImageLabel", root, {
	Name = "Logo",
	Image = LOGO,
	ScaleType = Enum.ScaleType.Fit,
	Position = UDim2.fromScale(0.065, 0.12),
	Size = UDim2.fromScale(0.39, 0.37),
	BackgroundTransparency = 1,
	ZIndex = 5,
})
make("UIAspectRatioConstraint", logo, { AspectRatio = 1024 / 588 })

-- Astuce : le code change le texte (RichText pour « TIP: » en jaune)
local tip = label(root, {
	Name = "Tip",
	RichText = true,
	Text = '<font color="#FFD23A">TIP:</font> At night a wall closes the street. Rob the shops before it drops!',
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromScale(0.07, 0.53),
	Size = UDim2.fromScale(0.42, 0.2),
	ZIndex = 5,
})
stroke(tip, 0.1)
make("UITextSizeConstraint", tip, { MinTextSize = 12, MaxTextSize = 36 })

-- Barre de progression : le code règle Bar.Fill.Size.X.Scale (0 à 1) et Bar.Percent.Text
local bar = make("Frame", root, {
	Name = "Bar",
	Position = UDim2.fromScale(0.07, 0.81),
	Size = UDim2.fromScale(0.5, 0.078),
	BackgroundColor3 = Color3.fromHex("171C46"),
	BorderSizePixel = 0,
	ZIndex = 5,
})
make("UICorner", bar, { CornerRadius = UDim.new(0.5, 0) })
stroke(bar, 0.1, Enum.ApplyStrokeMode.Border)
make("UISizeConstraint", bar, { MinSize = Vector2.new(0, 26) })
local fill = make("Frame", bar, {
	Name = "Fill",
	Size = UDim2.fromScale(0.64, 1),
	BackgroundColor3 = YELLOW,
	BorderSizePixel = 0,
	ZIndex = 6,
})
make("UICorner", fill, { CornerRadius = UDim.new(0.5, 0) })
-- reflet plein en haut de la barre (pas de dégradé)
local shine = make("Frame", fill, {
	Name = "Shine",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.16),
	Size = UDim2.new(1, -16, 0.22, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	ZIndex = 7,
})
make("UICorner", shine, { CornerRadius = UDim.new(0.5, 0) })
local pct = label(bar, {
	Name = "Percent",
	Text = "64%",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.4, 0.7),
	ZIndex = 8,
})
stroke(pct, 0.12)

-- Bouton Skip : le code le cache au départ et l'affiche après quelques secondes
local skip = make("TextButton", root, {
	Name = "SkipButton",
	Text = "",
	AutoButtonColor = true,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(0.955, 0.92),
	Size = UDim2.fromScale(0.14, 0.105),
	BackgroundColor3 = Color3.fromHex("E84C3D"),
	BorderSizePixel = 0,
	ZIndex = 5,
})
make("UICorner", skip, { CornerRadius = UDim.new(0.22, 0) })
stroke(skip, 0.05, Enum.ApplyStrokeMode.Border)
make("UISizeConstraint", skip, { MinSize = Vector2.new(96, 48) })
make("ImageLabel", skip, {
	Name = "Studs",
	Image = "rbxassetid://3014551673",
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromScale(0.2, 0.5),
	ImageTransparency = 0.55,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 6,
})
local sl = label(skip, {
	Name = "Label",
	Text = "SKIP",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.75, 0.55),
	ZIndex = 7,
})
stroke(sl, 0.12)

gui.Parent = RF
return "UI_Loading construit dans ReplicatedFirst"
