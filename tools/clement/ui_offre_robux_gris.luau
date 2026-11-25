-- Lot E : offre Robux flottante près du bouton Display du HUD, VERSION GRISE (bons noms, aucun style), à valider.
-- Construction reprise de la référence offre_starter_pack_au_dessus_boutons.webp : sans cadre ni fond, de haut en bas
-- Title, Subtitle, Income, Preview (ViewportFrame) avec deux bulles BonusA et BonusB inclinées, PackName, Price, Timer.
-- Une copie par colonne, comme DisplayedButton : RightRail (PC) et RightRailTouch (téléphone). Chaque copie est posée
-- dans un cadre décoratif OfferAnchor qui a la place exacte du DisplayedButton de sa colonne :
--   - PC : l'offre est au-dessus du bouton (1,5 × 1,9 fois sa taille, au moins 170 × 215 px), un peu calée à droite
--     pour ne pas sortir de l'écran ;
--   - téléphone : au-dessus du bouton, il n'y a que 105 px sous le compte à rebours ; l'offre est donc juste à
--     gauche du bouton, entre le compte à rebours et la barre du bas.
-- FeaturedOffer est caché (Visible = false) : c'est le code qui le montre, selon Features.RobuxShop.
-- À lancer dans Studio en Edit. Refait les deux copies à chaque lancement.

local StarterGui = game:GetService("StarterGui")

local hud = StarterGui:FindFirstChild("UI_HUD")
assert(hud, "UI_HUD introuvable")

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local GREY = Color3.fromRGB(138, 143, 153)

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function text(name: string, parent: Instance, value: string, y: number, h: number, w: number?)
	local t = new("TextLabel", {
		Name = name,
		Text = value,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(w or 1, h),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 3,
	}, parent)
	new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }, t)
	return t
end

local function bubble(name: string, parent: Instance, value: string, x: number, rot: number)
	local b = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, 0.62),
		Size = UDim2.fromScale(0.42, 0.24),
		Rotation = rot,
		BackgroundColor3 = GREY,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)
	new("TextLabel", {
		Name = "BonusLabel",
		Text = value,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 5,
	}, b)
	return b
end

local function build(rail: Instance, phone: boolean)
	local display = rail:FindFirstChild("DisplayedButton")
	assert(display and display:IsA("GuiObject"), rail.Name .. ".DisplayedButton introuvable")
	local old = rail:FindFirstChild("OfferAnchor")
	if old then
		old:Destroy()
	end
	-- Cadre décoratif à la place exacte du bouton Display
	local anchor = new("Frame", {
		Name = "OfferAnchor",
		AnchorPoint = display.AnchorPoint,
		Position = display.Position,
		Size = display.Size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, rail)
	local ar = display:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ar then
		ar:Clone().Parent = anchor
	end
	local offer = new("TextButton", {
		Name = "FeaturedOffer",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, anchor)
	if phone then
		offer.AnchorPoint = Vector2.new(1, 0.68)
		offer.Position = UDim2.new(0, -6, 0.5, 0)
		offer.Size = UDim2.fromScale(3.1, 3.8)
		new("UISizeConstraint", { MinSize = Vector2.new(130, 170) }, offer)
	else
		offer.AnchorPoint = Vector2.new(0.68, 1)
		offer.Position = UDim2.new(0.5, 0, 0, -6)
		offer.Size = UDim2.fromScale(1.5, 1.9)
		new("UISizeConstraint", { MinSize = Vector2.new(170, 215) }, offer)
	end
	text("Title", offer, "ULTRA VALUE!", 0, 0.13)
	text("Subtitle", offer, "LIMITED TIME!", 0.13, 0.09, 0.8)
	text("Income", offer, "$572/s", 0.22, 0.09, 0.7)
	local preview = new("ViewportFrame", {
		Name = "Preview",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.31),
		Size = UDim2.fromScale(0.7, 0.39),
		BackgroundColor3 = GREY,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, offer)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, preview)
	bubble("BonusA", offer, "+5K", 0.2, -14)
	bubble("BonusB", offer, "+$50K", 0.8, 12)
	text("PackName", offer, "STARTER PACK", 0.7, 0.1, 0.9)
	text("Price", offer, "ONLY R$19", 0.8, 0.1, 0.7)
	text("Timer", offer, "14:25", 0.9, 0.1, 0.5)
	return offer
end

for _, pair in { { "RightRail", false }, { "RightRailTouch", true } } do
	local rail = hud:FindFirstChild(pair[1])
	if rail then
		build(rail, pair[2])
	end
end
print("[ui_offre_robux_gris] fait")
