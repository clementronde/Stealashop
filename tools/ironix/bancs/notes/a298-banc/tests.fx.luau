--!nocheck
-- Scénario « fx » (a298, client) : faux écrans copiés de l'arbre de Studio du 21/11 (bouton Shop Framewisp_5C9UZM dans
-- UI_HUD.LeftRail, bouton Display QMN9WW dans RightRail), un bouton du plugin sans FigmaSmooth (assombrissement),
-- deux contours FigmaStroke, un écran qui garde un script Framewisp, des boutons du HUD, un bouton à UIGradient Gleam,
-- une carte de UI_RobuxShop_v2 (ItemName à Gleam = Loop, BuyButton, BuyButton1). Tout passe par UiAttrFx.Wire, comme
-- UiFeelController. F1 état ; F2 Spin ; F3 Wiggle ; F4 Lean ; F5 Burst ; F6 Gleam de groupe ; F7 assombrissement ;
-- F8 Stroke ; F9 script du plugin ; F10 reflet du bouton entier et Gleam sur un texte ; F11 attributs sans préfixe ;
-- F12 animations réduites ; F13 Destroying ; F14 textes des sources.
startServer()
local ada = join("Ada", newProfile())
advance(1)
CLIENT_PLAYER = ada
Players.LocalPlayer = ada
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local UI_FOLDER = CONTROLLERS:FindFirstChild("UI")
moduleScript(UI_FOLDER, "FramewispFx", "client/Controllers/UI/FramewispFx.luau")
local Fx = requireModule(moduleScript(UI_FOLDER, "UiAttrFx", "client/Controllers/UI/UiAttrFx.luau"), "client")
local FW = requireModule(UI_FOLDER:FindFirstChild("FramewispFx"), "client")
local Motion = requireModule(UI_FOLDER:FindFirstChild("Motion"), "client")
local UiMotion = sharedModule("Config/UiMotion", "client")
local Features = sharedModule("Config/Features", "client")
local AF = UiMotion.AttrFx
local C = AF.Framewisp
local S = AF.ButtonSheen
local WHITE = Color3.new(1, 1, 1)

local function gui(class, name, props, parent)
	local base = {
		Name = name, Visible = true, ZIndex = 2, Rotation = 0, BackgroundTransparency = 1, ImageTransparency = 0,
		TextTransparency = 0, Image = "", Text = "", AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0.2, 0.2), AbsoluteSize = Vector2.new(100, 100), AbsolutePosition = Vector2.new(0, 0),
		BackgroundColor3 = Color3.new(0.5, 0.5, 0.5), ImageColor3 = Color3.new(1, 1, 1), TextColor3 = Color3.new(1, 1, 1),
		MouseEnter = newSignal(), MouseLeave = newSignal(), MouseButton1Down = newSignal(), MouseButton1Up = newSignal(),
		InputBegan = newSignal(),
	}
	for k, v in props or {} do
		base[k] = v
	end
	return make(class, base, parent)
end
local function attrs(object, list)
	for k, v in list do
		object:SetAttribute(k, v)
	end
	return object
end
local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-6)
end
local function named(root, name)
	local list = {}
	for _, d in root:GetDescendants() do
		if d.Name == name then
			table.insert(list, d)
		end
	end
	return list
end
local function run(seconds, each)
	for _ = 1, math.floor(seconds / 0.05 + 0.5) do
		advance(0.05, 0.05)
		if each then
			each()
		end
	end
end

---------------------------------------------------------------- arbres
local hud = make("ScreenGui", { Name = "UI_HUD", Enabled = true, AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(1000, 600) }, playerGui)
local leftRail = gui("Frame", "LeftRail", { AbsoluteSize = Vector2.new(300, 400), AbsolutePosition = Vector2.new(0, 100) }, hud)
make("UIListLayout", { Name = "UIListLayout" }, leftRail)
local rightRail = gui("Frame", "RightRail", { AbsoluteSize = Vector2.new(300, 400), AbsolutePosition = Vector2.new(700, 100) }, hud)

-- Bouton Shop (Framewisp_5C9UZM) : racine TextButton au texte vide.
local shop = attrs(gui("TextButton", "Frame 1", { AbsoluteSize = Vector2.new(290, 90), AbsolutePosition = Vector2.new(0, 100) }, leftRail),
	{ FigmaBurst = true, FigmaGleam = true, FigmaSmooth = true, FigmaGleamWidth = 0.19, FigmaBurstSizeMax = 49, FigmaBurstW = 290, FigmaBurstH = 90, FW_Owned = true })
local shopBg = gui("ImageLabel", "Frame 1Background", { Image = "rbxassetid://10", ZIndex = 4, AbsoluteSize = Vector2.new(290, 90), AbsolutePosition = Vector2.new(0, 100) }, shop)
attrs(gui("ImageLabel", "Frame 1Background_Sheen", { Image = "rbxassetid://11", ImageTransparency = 1 }, shopBg), { FigmaSheen = true })
local group = gui("Frame", "Group 1", nil, shop)
local masked = gui("Frame", "Frame 1Masked", nil, group)
make("UICorner", { Name = "UICorner", CornerRadius = UDim.new(0.2, 0) }, masked)
local sunburst = attrs(gui("ImageLabel", "Sunburst", { Image = "rbxassetid://12", ImageTransparency = 0.7, Rotation = 5, AbsoluteSize = Vector2.new(120, 120), AbsolutePosition = Vector2.new(10, 85) }, masked),
	{ FigmaSpin = true, FigmaSpinSpeed = 40 })
attrs(gui("ImageLabel", "Sunburst_Sheen", { Image = "rbxassetid://13", ImageTransparency = 1 }, sunburst), { FigmaSheen = true })
gui("TextLabel", "LabelShadow", { Text = "SHOP", AbsoluteSize = Vector2.new(150, 40), AbsolutePosition = Vector2.new(120, 130) }, shop)
local label = gui("TextLabel", "Label", { Text = "SHOP", AbsoluteSize = Vector2.new(150, 40), AbsolutePosition = Vector2.new(120, 125) }, shop)
make("UIStroke", { Name = "UIStroke", Thickness = 3, Color = Color3.new(0, 0, 0) }, label)
local icon = attrs(gui("ImageLabel", "Icon", { Image = "rbxassetid://14", AbsoluteSize = Vector2.new(70, 70), AbsolutePosition = Vector2.new(20, 110) }, shop),
	{ FigmaLean = true, FigmaWiggle = true, FigmaWiggleEvery = 6 })
attrs(gui("ImageLabel", "Icon_Sheen", { Image = "rbxassetid://15", ImageTransparency = 1 }, icon), { FigmaSheen = true })
attrs(gui("ImageLabel", "Frame 1_BurstImg", { Image = "rbxassetid://77", Visible = false }, shop), { FigmaBurstImg = true })
make("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, shop)

-- Bouton Display (QMN9WW) : racine TextButton dans RightRail (pas de layout), éclats ronds.
local display = attrs(gui("TextButton", "Group 1", { AbsoluteSize = Vector2.new(220, 228), AbsolutePosition = Vector2.new(700, 100), Position = UDim2.new(0.1, 4, 0.2, 0), Size = UDim2.fromScale(0.5, 0.3) }, rightRail),
	{ FigmaBurst = true, FigmaBurstSize = 29, FigmaBurstW = 220, FigmaBurstH = 228, FigmaGleam = true, FigmaSmooth = true, FW_Owned = true })
local displayBg = gui("ImageLabel", "Group 1Background", { Image = "rbxassetid://20", AbsoluteSize = Vector2.new(220, 228), AbsolutePosition = Vector2.new(700, 100) }, display)
attrs(gui("ImageLabel", "Group 1Background_Sheen", { Image = "rbxassetid://21", ImageTransparency = 1 }, displayBg), { FigmaSheen = true })
local displayIcon = attrs(gui("ImageLabel", "Icon", { Image = "rbxassetid://22", Rotation = -3, AbsoluteSize = Vector2.new(60, 60), AbsolutePosition = Vector2.new(780, 180) }, display), { FigmaWiggle = true })

-- Boutons du HUD (pas du plugin) : reflet du bouton entier.
local quests = gui("TextButton", "QuestsButton", { BackgroundTransparency = 0, ZIndex = 3, AbsoluteSize = Vector2.new(80, 80) }, leftRail)
make("UICorner", { Name = "UICorner", CornerRadius = UDim.new(0.12, 0) }, quests)
local skill = gui("ImageButton", "SkillTreeButton", { Image = "rbxassetid://30" }, leftRail)
local skillFill = gui("Frame", "Fill", { BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, skill)
local empty = gui("ImageButton", "EmptyButton", { Image = "rbxassetid://31" }, rightRail)
local promo = attrs(gui("TextButton", "PromoButton", { BackgroundTransparency = 0 }, rightRail), { Gleam = "Loop" })

-- Écran de test : bouton du plugin sans FigmaSmooth, contours, bouton à UIGradient Gleam.
local test = make("ScreenGui", { Name = "UI_Test", Enabled = true }, playerGui)
local plain = attrs(gui("ImageButton", "Plain", { AutoButtonColor = true }, test), { FW_Owned = true })
local art = gui("ImageLabel", "Art", { Image = "rbxassetid://40", ImageColor3 = Color3.new(1, 0.5, 0.25) }, plain)
local glow = gui("ImageLabel", "Glow_nodim", { Image = "rbxassetid://41", ImageColor3 = Color3.new(0.9, 0.9, 0.9) }, plain)
local badge = attrs(gui("ImageLabel", "Badge", { Image = "rbxassetid://42", ImageColor3 = Color3.new(0.8, 0.8, 0.8) }, plain), { FigmaNoDim = true })
local state = attrs(gui("Frame", "On", nil, plain), { FigmaState = "On" })
local stateArt = gui("ImageLabel", "OnArt", { Image = "rbxassetid://43", ImageColor3 = Color3.new(0.7, 0.7, 0.7) }, state)
local ring = attrs(gui("Frame", "Ring", nil, test), { FigmaStroke = true })
local ringStroke = make("UIStroke", { Name = "UIStroke", Thickness = 2 }, ring)
local ring2 = attrs(gui("Frame", "Ring2", nil, test), { FigmaStroke = true, FigmaStrokeRotate = 10 })
local ring2Stroke = make("UIStroke", { Name = "UIStroke", Thickness = 2 }, ring2)
local ring2Gradient = make("UIGradient", { Name = "UIGradient", Rotation = 30, Offset = Vector2.new(0.1, 0) }, ring2Stroke)
local promo2 = gui("TextButton", "Promo2", { BackgroundTransparency = 0, AbsoluteSize = Vector2.new(200, 40) }, test)
local promoGleam = make("UIGradient", { Name = "Gleam", Offset = Vector2.new(AF.GleamGradient.From, 0) }, promo2)

-- Écran qui garde un LocalScript du plugin.
local other = make("ScreenGui", { Name = "UI_Other", Enabled = true }, playerGui)
make("LocalScript", { Name = "FramewispSpin" }, other)
local sun = attrs(gui("ImageLabel", "Sun", { Image = "rbxassetid://50", Rotation = 7 }, other), { FigmaSpin = true })

-- Carte de la boutique Robux v2.
local robux = make("ScreenGui", { Name = "UI_RobuxShop_v2", Enabled = true }, playerGui)
local cardFrame = gui("Frame", "Card", nil, robux)
local itemName = attrs(gui("TextLabel", "ItemName", { Text = "Golden Rocket" }, cardFrame), { Gleam = "Loop" })
local buy = gui("TextButton", "BuyButton", { BackgroundTransparency = 0, Text = "R$ 99", AbsoluteSize = Vector2.new(120, 40) }, cardFrame)
make("UICorner", { Name = "UICorner", CornerRadius = UDim.new(0.12, 0) }, buy)
local buyRow = gui("Frame", "BuyRow", nil, cardFrame)
local buy1 = gui("TextButton", "BuyButton1", { BackgroundTransparency = 0, AbsoluteSize = Vector2.new(120, 40) }, buyRow)
local close = gui("TextButton", "CloseButton", { BackgroundTransparency = 0 }, cardFrame)

local ok, err = pcall(function()
	for _, screen in { hud, test, other, robux } do
		for _, object in screen:GetDescendants() do
			Fx.Wire(object)
			Fx.Wire(object) -- une seule fois
		end
	end
end)
check(ok, `Wire sans erreur ({tostring(err)})`)

section("F1 état après Wire")
local st = FW.GetState()
check(Features.FramewispFx == true and Features.UiAttrFx == true, "Features.FramewispFx et UiAttrFx allumés (V0)")
check(st.Spins == 1 and st.Wiggles == 2 and st.Leans == 1 and st.Bursts == 2 and st.Gleams == 2 and st.Strokes == 2 and st.Dims == 1,
	`1 Spin, 2 Wiggle, 1 Lean, 2 Burst, 2 Gleam, 2 Stroke, 1 assombri ({st.Spins}, {st.Wiggles}, {st.Leans}, {st.Bursts}, {st.Gleams}, {st.Strokes}, {st.Dims})`)
check(st.ButtonSheens == 5 and st.Skipped == 1, `5 reflets de bouton entier, 1 écran sauté ({st.ButtonSheens}, {st.Skipped})`)
check(Fx.GetState().Running == true, "la boucle d'UiAttrFx tourne")
check(plain.AutoButtonColor == false, "bouton assombri : AutoButtonColor coupé, comme le plugin")

section("F2 Spin : le Sunburst tourne de FigmaSpinSpeed degrés par seconde depuis sa Rotation")
run(0.05)
local r0 = sunburst.Rotation
run(1)
check(near((sunburst.Rotation - r0) % 360, 40, 0.01), `40 °/s ({sunburst.Rotation - r0})`)
hud.Enabled = false
run(0.05)
check(sunburst.Rotation == 5, `écran éteint : revenu à sa Rotation de Clément ({sunburst.Rotation})`)
hud.Enabled = true

section("F3 Wiggle : un balancement amorti, puis rien jusqu'au suivant")
-- L'écran vient de se rallumer : chaque effet repart de zéro.
local maxAbs, after = 0, 0
local Wg = C.Wiggle
run(Wg.Time, function()
	maxAbs = math.max(maxAbs, math.abs(icon.Rotation))
end)
run(1, function()
	after = math.max(after, math.abs(icon.Rotation))
end)
check(maxAbs > Wg.Angle * 0.6 and maxAbs <= Wg.Angle + 1e-6, `balance jusqu'à ±{Wg.Angle}° amortis ({maxAbs})`)
check(after < 1e-6, `puis à sa Rotation (0 ; {after})`)
check(displayIcon.Rotation == -3, `l'autre Icon (WiggleEvery 4 par défaut) revenu à sa Rotation ({displayIcon.Rotation})`)

section("F4 Lean : au survol du bouton, l'Icon penche, puis revient")
shop.MouseEnter:Fire()
run(0.2)
check(near(icon.Rotation, C.Lean.Angle), `penche de {C.Lean.Angle}° ({icon.Rotation})`)
shop.MouseLeave:Fire()
run(0.2)
check(icon.Rotation == 0, `revient à 0 à la sortie ({icon.Rotation})`)
shop.MouseEnter:Fire()
run(0.2)
hud.Enabled = false
run(0.05)
check(icon.Rotation == 0, "écran éteint pendant le survol : à sa Rotation")
hud.Enabled = true
shop.MouseLeave:Fire()

section("F5 Burst : des éclats au clic, puis plus rien")
shop.Activated:Fire()
local layer = hud:FindFirstChild("Frame 1" .. C.Burst.LayerSuffix)
local bits = layer and layer:GetChildren() or {}
check(layer ~= nil and layer.Parent == hud, "calque Frame 1_Burst posé dans l'écran (LeftRail est rangé par un layout)")
check(#bits == C.Burst.Count and FW.GetState().Particles == C.Burst.Count, `{C.Burst.Count} éclats ({#bits})`)
local b1 = bits[1]
check(b1 and b1.ClassName == "ImageLabel" and b1.Image == "rbxassetid://77" and b1.Name == C.Burst.BitName, "éclats : l'image de l'enfant FigmaBurstImg")
local sizeOk = true
for _, b in bits do
	local px = b.Size.X.Scale * 290
	sizeOk = sizeOk and px >= 12 * 0.35 - 1e-6 and px <= 49 * 0.35 + 1e-6 -- au départ : 35 % de leur taille
end
check(sizeOk, "tailles entre FigmaBurstSize (12) et FigmaBurstSizeMax (49), à 35 % au départ")
check(layer and near(layer.Position.Y.Scale, 100 / 600) and near(layer.Size.X.Scale, 290 / 1000), "le calque couvre le bouton (mesuré à l'écran)")
local p0 = b1 and b1.Position
run(0.3)
check(b1 and b1.Parent == layer and p0 and (b1.Position.X.Scale ~= p0.X.Scale or b1.Position.Y.Scale ~= p0.Y.Scale), "les éclats s'éloignent")
run(1)
check(FW.GetState().Particles == 0 and hud:FindFirstChild("Frame 1" .. C.Burst.LayerSuffix) == nil, "finis : éclats et calque détruits")
display:SetAttribute("Burst", 1)
local dlayer = rightRail:FindFirstChild("Group 1" .. C.Burst.LayerSuffix)
local dbit = dlayer and dlayer:GetChildren()[1]
check(dlayer ~= nil and dlayer.Position == display.Position and dlayer.Size == display.Size and dlayer.ZIndex == display.ZIndex - 1, "attribut Burst : calque à côté du bouton, même boîte, sous lui")
check(dbit and dbit.ClassName == "Frame" and dbit:FindFirstChildOfClass("UICorner") ~= nil, "sans FigmaBurstImg : des ronds")
hud.Enabled = false
run(0.05)
check(FW.GetState().Particles == 0 and rightRail:FindFirstChild("Group 1" .. C.Burst.LayerSuffix) == nil, "écran éteint : tout détruit")
shop.Activated:Fire()
check(FW.GetState().Particles == 0, "clic sur un écran éteint : rien")
hud.Enabled = true

section("F6 Gleam : copies FW_GleamShine sur les pièces du bouton, une bande les traverse")
run(0.05)
local copies = named(shop, C.Gleam.CopyName)
check(#copies == 10, `5 pièces × 2 copies (fond, Sunburst, LabelShadow, Label, Icon : {#copies})`)
check(#named(shop:FindFirstChild("Frame 1_BurstImg"), C.Gleam.CopyName) == 0 and #named(sunburst:FindFirstChild("Sunburst_Sheen"), C.Gleam.CopyName) == 0, "ni l'image des éclats ni les silhouettes ne sont des pièces")
local bgCopy = shopBg:FindFirstChild(C.Gleam.CopyName)
check(bgCopy and bgCopy.ClassName == "ImageLabel" and bgCopy.Image == "rbxassetid://11" and bgCopy.ImageColor3 == WHITE, "fond : la silhouette Frame 1Background_Sheen, en blanc")
local labelCopies = {}
for _, c in label:GetChildren() do
	if c.Name == C.Gleam.CopyName then
		table.insert(labelCopies, c)
	end
end
local core = labelCopies[2]
check(#labelCopies == 2 and core.ClassName == "TextLabel" and core.Text == "SHOP" and core.TextColor3 == WHITE and core.ZIndex == label.ZIndex + 2 and labelCopies[1].ZIndex == label.ZIndex + 1, "texte : halo (Z + 1) et cœur (Z + 2) blancs, même texte")
local coreStroke = core:FindFirstChildOfClass("UIStroke")
check(coreStroke and coreStroke.Color == WHITE and coreStroke.Thickness == 3, "contour des lettres en blanc, même épaisseur")
local coreGradient = core:FindFirstChildOfClass("UIGradient")
-- L'écran s'est rallumé : le passage commence. Pendant Speed s visible, puis caché pendant Cooldown s.
local seen, offs = 0, {}
run(C.Gleam.Speed - 0.1, function()
	if core.Visible then
		seen += 1
		table.insert(offs, coreGradient.Offset.X)
	end
end)
check(seen >= 10 and offs[#offs] > offs[1], `visible pendant le passage, la bande avance ({seen} images, {offs[1]} → {offs[#offs]})`)
run(0.5)
local anyVisible = false
for _, c in copies do
	anyVisible = anyVisible or c.Visible
end
check(not anyVisible, "après le passage : toutes les copies cachées")
label.Text = "BUY"
run(C.Gleam.Cooldown + 0.1)
check(core.Visible and core.Text == "BUY", "passage suivant : visible, le texte suit")
hud.Enabled = false
run(0.05)
check(not core.Visible and not bgCopy.Visible, "écran éteint : copies cachées")
hud.Enabled = true
label.Text = "SHOP"
local dcopies = named(display, C.Gleam.CopyName)
run(0.05)
dcopies = named(display, C.Gleam.CopyName)
check(#dcopies == 4, `Display : fond et Icon, 2 copies chacun ({#dcopies})`)
check(logHas("Icon est une image sans sa silhouette Icon_Sheen", "PRINT", "client"), "image sans silhouette : une ligne en Studio")

section("F7 assombrissement : survol, appui, puis la couleur revient ; _nodim et FigmaNoDim gardés")
local base = art.ImageColor3
local function scaled(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end
plain.MouseEnter:Fire()
check(art.ImageColor3 == scaled(base, C.Dim.Hover), `survol : × {C.Dim.Hover}`)
check(glow.ImageColor3 == Color3.new(0.9, 0.9, 0.9) and badge.ImageColor3 == Color3.new(0.8, 0.8, 0.8) and stateArt.ImageColor3 == Color3.new(0.7, 0.7, 0.7), "_nodim, FigmaNoDim et calque d'état : pas assombris")
plain.MouseButton1Down:Fire()
check(art.ImageColor3 == scaled(base, C.Dim.Press), `appui : × {C.Dim.Press}`)
plain.MouseButton1Up:Fire()
check(art.ImageColor3 == scaled(base, C.Dim.Hover), "relâché : retour au survol")
plain.MouseLeave:Fire()
check(art.ImageColor3 == base, "sortie : sa couleur de Clément")
art.ImageColor3 = Color3.new(0, 1, 0)
plain.MouseEnter:Fire()
check(art.ImageColor3 == scaled(Color3.new(0, 1, 0), C.Dim.Hover), "couleur changée par un autre : la nouvelle sert de base")
test.Enabled = false
run(0.05)
check(art.ImageColor3 == Color3.new(0, 1, 0), "écran éteint pendant le survol : couleur rendue")
test.Enabled = true
local shopBgColor = shopBg.ImageColor3
shop.MouseEnter:Fire()
check(shopBg.ImageColor3 == shopBgColor, "bouton FigmaSmooth : pas assombri (Motion.Button le grossit)")
shop.MouseLeave:Fire()

section("F8 Stroke : le dégradé du contour tourne, puis revient")
run(0.05)
local made = ringStroke:FindFirstChild(C.Stroke.GradientName)
check(made ~= nil and made.ClassName == "UIGradient", "UIStroke sans dégradé : FW_StrokeGradient créé (celui du plugin)")
local s0, s20 = made.Rotation, ring2Gradient.Rotation
run(1)
check(near((made.Rotation - s0) % 360, C.Stroke.Rotate, 0.01), `{C.Stroke.Rotate} °/s ({made.Rotation - s0})`)
check(near((ring2Gradient.Rotation - s20) % 360, 10, 0.01) and ring2Gradient.Offset.X == 0.1, `FigmaStrokeRotate 10 °/s, Offset de Clément gardé ({ring2Gradient.Rotation - s20})`)
test.Enabled = false
run(0.05)
check(ring2Gradient.Rotation == 30 and made.Rotation == 0, "écran éteint : Rotation de Clément rendue")
test.Enabled = true

section("F9 script du plugin dans l'écran : pas de double effet")
run(0.5)
check(sun.Rotation == 7, "UI_Other garde FramewispSpin : le Sun ne tourne pas par le code")
check(logHas("UI_Other a encore un script Framewisp", "PRINT", "client"), "une ligne en Studio")

section("F10 reflet du bouton entier ; Gleam sur un texte ignoré")
local qs = quests:FindFirstChild(S.Name)
check(qs and qs.ClassName == "Frame" and qs.BackgroundColor3 == WHITE and qs.ZIndex == 4 and qs.Size == UDim2.fromScale(1, 1), "QuestsButton (LeftRail) : SheenFx blanc, par-dessus, toute la taille")
local qc = qs and qs:FindFirstChildOfClass("UICorner")
check(qc and qc.CornerRadius.Scale == 0.12 and qc ~= quests:FindFirstChildOfClass("UICorner"), "coupé par une copie de l'UICorner du bouton")
local qg = qs and qs:FindFirstChildOfClass("UIGradient")
check(qg and qg.Rotation == S.Tilt, `bande penchée de {S.Tilt}°`)
local minT = 1
for _, kp in qg.Transparency.Start do
	minT = math.min(minT, kp.Value)
end
check(near(1 - minT, S.Opacity), `opacité {S.Opacity} au cœur ({1 - minT})`)
check(skillFill:FindFirstChild(S.Name) ~= nil and skill:FindFirstChild(S.Name) == nil, "SkillTreeButton sans fond : sur son cadre Fill peint")
check(empty:FindFirstChild(S.Name) == nil and logHas("EmptyButton : pas de fond peint", "PRINT", "client"), "sans fond peint : rien, une ligne en Studio")
check(promo:FindFirstChild(AF.Gleam.Name) ~= nil and promo:FindFirstChild(S.Name) == nil, "bouton à Gleam = Loop : le reflet GleamFx seul (un seul reflet)")
check(promo2:FindFirstChild(S.Name) ~= nil, "bouton à UIGradient Gleam : SheenFx (le Gleam de Clément est gardé aussi)")
check(buy:FindFirstChild(S.Name) ~= nil and buy1:FindFirstChild(S.Name) ~= nil and close:FindFirstChild(S.Name) == nil, "UI_RobuxShop_v2 : BuyButton et BuyButton1, pas CloseButton")
check(#named(shop, S.Name) == 0 and #named(display, S.Name) == 0, "boutons du plugin : pas de deuxième reflet")
check(itemName:FindFirstChild(AF.Gleam.Name) == nil and itemName:GetAttribute("Gleam") == "Loop", "ItemName à Gleam = Loop : pas de copie, l'attribut reste")
check(logHas("sur un texte", "PRINT", "client"), "Gleam sur un texte : une ligne en Studio")
local seenQ, offQ = 0, {}
run(S.Pass + S.Pause + 0.1, function()
	if qs.Visible then
		seenQ += 1
		table.insert(offQ, qg.Offset.X)
	end
end)
check(seenQ >= 12 and seenQ <= 18 and offQ[#offQ] > offQ[1], `un passage par cycle de {S.Pass + S.Pause} s ({seenQ} images)`)
hud.Enabled = false
run(0.05)
check(not qs.Visible, "écran éteint : caché")
hud.Enabled = true

section("F11 les attributs sans préfixe gagnent")
sunburst:SetAttribute("SpinSpeed", 90)
ring2:SetAttribute("StrokeRotate", 60)
run(0.05)
local a, b = sunburst.Rotation, ring2Gradient.Rotation
run(1)
check(near((sunburst.Rotation - a) % 360, 90, 0.01), `SpinSpeed 90 devant FigmaSpinSpeed 40 ({sunburst.Rotation - a})`)
check(near((ring2Gradient.Rotation - b) % 360, 60, 0.01), `StrokeRotate 60 devant FigmaStrokeRotate 10 ({ring2Gradient.Rotation - b})`)

section("F12 animations réduites : rien ne bouge, tout revient")
local was = Motion.IsReduced
Motion.IsReduced = function()
	return true
end
run(0.1)
local movedAny = false
local rs, rr = sunburst.Rotation, ring2Gradient.Rotation
run(1, function()
	movedAny = movedAny or qs.Visible or core.Visible
end)
check(rs == 5 and rr == 30 and sunburst.Rotation == 5 and not movedAny, "Spin, Stroke, reflets : à l'état de Clément")
shop.Activated:Fire()
check(FW.GetState().Particles == 0, "pas d'éclats")
Motion.IsReduced = was

section("F13 Destroying : l'effet est oublié")
ring:Destroy()
quests:Destroy()
display:Destroy()
local st2 = FW.GetState()
check(st2.Strokes == 1 and st2.ButtonSheens == 4 and st2.Gleams == 1 and st2.Bursts == 1 and st2.Wiggles == 1, `détruits oubliés ({st2.Strokes}, {st2.ButtonSheens}, {st2.Gleams}, {st2.Bursts}, {st2.Wiggles})`)
run(0.2)
check(true, "la boucle continue sans erreur")

section("F14 textes des sources")
local attr = SOURCES["client/Controllers/UI/UiAttrFx.luau"]
local _, wires = string.gsub(attr, "FramewispFx%.Wire%(gui%)", "")
check(wires == 2, `UiAttrFx.Wire appelle FramewispFx.Wire dans ses deux sorties ({wires})`)
check(string.find(attr, "local ENABLED = Features.UiAttrFx == true", 1, true) ~= nil and string.find(attr, "if not ENABLED or wired[object]", 1, true) ~= nil, "derrière Features.UiAttrFx")
check(string.find(SOURCES["client/Controllers/UI/FramewispFx.luau"], "local ENABLED = Features.FramewispFx == true", 1, true) ~= nil, "derrière Features.FramewispFx")
check(not logHas("FramewispFx", "WARN", "client") and not logHas("UiAttrFx", "WARN", "client"), "aucune alerte")

summary("scénario fx")
