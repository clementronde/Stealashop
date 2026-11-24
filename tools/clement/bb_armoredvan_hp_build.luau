-- bb_armoredvan_hp_build.luau : barre de vie du fourgon blindé, BB_ArmoredVanHP (L-313 point 2).
-- À lancer en Edit. Lue par ArmoredVanService (Config/ArmoredVan.BillboardAsset) : copiée sur l'Attachment
-- HealthBarPoint du fourgon ; le serveur règle Fill.Size.X (part des PV restants, en Scale) et HPText.Text
-- (« 12.3K / 30K »). PV partagés : la même barre pour tous les joueurs.
-- Style des briques Figma (page 00 Briques) : Montserrat Black, contour #1B1B24, dégradé or du cartouche
-- (#FFD84A → #FF9E1A), studs en surimpression, ombre portée sombre, coins presque droits.
-- Aucun script. Range le modèle dans ReplicatedStorage/Assets/UI et un aperçu (barre aux 2/3) sur le fourgon
-- de la vitrine (_SHOWROOM_CLEMENT/ÉVÉNEMENT ET NUIT/Show_ENV_Event_ArmoredVan).

local INK = Color3.fromHex("1B1B24")
local MONTSERRAT_BLACK = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy) -- « Black » de Figma = Heavy (900) dans Roblox
local STUDS = "rbxassetid://89499299399116" -- texture de studs des boutons des briques (UI_RobuxShop)

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) }, parent)
end

local function corner(parent: Instance, scale: number)
	new("UICorner", { CornerRadius = UDim.new(scale, 0) }, parent)
end

local function text(parent: Instance, name: string, value: string, props: { [string]: any }): TextLabel
	local label = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Text = value,
		FontFace = MONTSERRAT_BLACK,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
	}, parent)
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

local function build(): BillboardGui
	local gui = new("BillboardGui", {
		Name = "BB_ArmoredVanHP",
		Size = UDim2.new(11, 230, 3.4, 92), -- studs + pixels : lisible de près comme de loin (même principe que BB_TruckHP)
		AlwaysOnTop = true, -- le fourgon roule : jamais caché par son toit ni par la rue (comme BB_WindowHP)
		StudsOffset = Vector3.new(0, 1.5, 0), -- au-dessus des gyrophares
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, -- sinon (Global) le fond de Bar passe devant Fill
		LightInfluence = 0,
		MaxDistance = 400, -- Config/ArmoredVan.BillboardMaxDistance
		ResetOnSpawn = false,
		ClipsDescendants = false,
	})

	-- Titre doré avec son ombre (brique Title, 2e TextLabel « Shadow » sans script)
	text(gui, "TitleShadow", "ARMORED VAN", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(1, 0.4),
		TextColor3 = INK,
		ZIndex = 1,
	})
	local title = text(gui, "Title", "ARMORED VAN", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 0.4),
		ZIndex = 2,
	})
	gradient(title, Color3.fromHex("FFF3A0"), Color3.fromHex("FFC52E"))
	new("UIStroke", { Color = INK, Thickness = 0.1, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, title)

	-- Ombre portée de la barre
	local shadow = new("Frame", {
		Name = "BarShadow",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.94, 0.48),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, gui)
	corner(shadow, 0.12)

	-- Barre : fond sombre, Fill doré (réglé par le code), studs, texte des PV
	local bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.94, 0.48),
		BackgroundColor3 = Color3.fromHex("2C2F36"),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	}, gui)
	corner(bar, 0.12)
	new("UIStroke", { Color = INK, Thickness = 0.07, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bar)

	local fill = new("Frame", {
		Name = "Fill",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1), -- X = part des PV restants (code)
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 1,
	}, bar)
	corner(fill, 0.12)
	gradient(fill, Color3.fromHex("FFD84A"), Color3.fromHex("FF9E1A"))
	local shine = new("Frame", {
		Name = "Shine",
		Position = UDim2.fromScale(0.01, 0.1),
		Size = UDim2.fromScale(0.98, 0.32),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, fill)
	corner(shine, 0.3)

	local studs = new("ImageLabel", {
		Name = "Studs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = STUDS,
		ImageTransparency = 0.55,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(0.0625, 1), -- 16 studs sur la longueur, un rang en hauteur
		ZIndex = 3,
	}, bar)
	corner(studs, 0.12)

	local hp = text(bar, "HPText", "30K / 30K", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.78),
		ZIndex = 4,
	})
	new("UIStroke", { Color = INK, Thickness = 0.12, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, hp)

	return gui
end

-- Pose ---------------------------------------------------------------------------------------------------------------
local report = {}
local gui = build()
for _, d in gui:GetDescendants() do
	assert(not d:IsA("LuaSourceContainer"), "script dans le billboard")
end

local uiFolder = game:GetService("ReplicatedStorage").Assets.UI
local old = uiFolder:FindFirstChild(gui.Name)
if old then
	old:Destroy()
end
gui.Parent = uiFolder
table.insert(report, "modèle : " .. gui:GetFullName())

local showroom = workspace:FindFirstChild("_SHOWROOM_CLEMENT")
local events = showroom and showroom:FindFirstChild("ÉVÉNEMENT ET NUIT")
local van = events and events:FindFirstChild("Show_ENV_Event_ArmoredVan")
local point = van and van:FindFirstChild("HealthBarPoint", true)
if point then
	local previous = point:FindFirstChild("VanHP")
	if previous then
		previous:Destroy()
	end
	local preview = gui:Clone()
	preview.Name = "VanHP" -- même nom que la copie du code
	preview.Adornee = point
	preview.Bar.Fill.Size = UDim2.fromScale(0.65, 1)
	preview.Bar.HPText.Text = "19.5K / 30K"
	preview.Parent = point
	table.insert(report, "aperçu : " .. preview:GetFullName())
end
return table.concat(report, "\n")
