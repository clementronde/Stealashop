---------------------------------------------------------------- scénarios a209 (vague 63, L-204 points 1 à 3)
-- Après setup.luau du banc a50 (joueur P1 et son PlayerGui). Temps simulé : step(sec).
-- Modules montés dans Controllers209 (UI : Motion, Appear, HudMask, CrateLoop, PurchaseGlow, DiamondBalance).
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers209")
local ui = folder(ctrl, "UI")
moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
local appearModule = moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
local crateModule = moduleScript(ui, "CrateLoop", "client/Controllers/UI/CrateLoop.luau")
local glowModule = moduleScript(ui, "PurchaseGlow", "client/Controllers/UI/PurchaseGlow.luau")
local diamondModule = moduleScript(ui, "DiamondBalance", "client/Controllers/UI/DiamondBalance.luau")
CHASED = false
SOURCES["stub/ChaseController"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController")
local motionCtrl = moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau")
local shopFxCtrl = moduleScript(ctrl, "ShopFxController", "client/Controllers/ShopFxController.luau")

local Appear = requireModule(appearModule, "client")
local CrateLoop = requireModule(crateModule, "client")
local PurchaseGlow = requireModule(glowModule, "client")
local DiamondBalance = requireModule(diamondModule, "client")
local UiMotionController = requireModule(motionCtrl, "client")
local ShopFxController = requireModule(shopFxCtrl, "client")
local ShopFx = requireModule(ReplicatedStorage.Shared.Config.ShopFx, "client")
local Settings = requireModule(ReplicatedStorage.Shared.Config.Settings, "client")
taskLib.spawn(UiMotionController.Start)
taskLib.spawn(ShopFxController.Start)
step(0.1)

local function scaleOf(object)
	for _, child in object:GetChildren() do
		if child:IsA("UIScale") then
			return child
		end
	end
	return nil
end
local function sameUDim2(a, b, eps)
	eps = eps or 1e-6
	return near(a.X.Scale, b.X.Scale, eps) and near(a.X.Offset, b.X.Offset, eps) and near(a.Y.Scale, b.Y.Scale, eps) and near(a.Y.Offset, b.Y.Offset, eps)
end
local function centerX(o)
	return o.Position.X.Scale + o.Size.X.Scale * 0.5
end

---------------------------------------------------------------- 0. La pose, calculée (CrateLoop.Sample)
print("-- Pose")
local p0 = CrateLoop.Sample(0)
check(near(p0.Rays, 0) and near(p0.Glow, 0.45) and near(p0.IconY, 0) and near(p0.IconScale, 1) and near(p0.IconRotation, 0), "S1 t = 0 : rayons à 0, Glow à 0,45, caisse à sa place")
check(near(p0.Stars[1], 0.2) and near(p0.Button, 1) and near(p0.BadgeY, 0) and near(p0.OddY[1], 0), "S2 t = 0 : étoiles à × 0,2, bouton à 1, badge et Odd_1 à leur place")
check(near(p0.OddY[2], 4 * math.sin(0.9), 1e-9) and near(p0.OddY[3], 4 * math.sin(1.8), 1e-9), "S3 t = 0 : Odd_2 et Odd_3 décalées de 0,9 rad")
local p05 = CrateLoop.Sample(0.5)
check(near(p05.IconY, -7) and near(p05.ShadowWidth, 0.88), "S4 t = 0,5 : caisse 7 px plus haut, ombre serrée (× 0,88)")
local p1 = CrateLoop.Sample(1)
check(near(p1.Rays, -11.25) and near(p1.Glow, 0.225) and near(p1.IconY, 0, 1e-9), "S5 t = 1 : rayons à −11,25°, Glow à 0,225, caisse revenue à sa place")
check(p1.Button > 1 and p1.Button < 1.05 and near(CrateLoop.Sample(1.1).Button, 1.05) and near(CrateLoop.Sample(3.1).Button, 1.05), "S6 BuyButton3 : × 1,05 au sommet à 1,1 s et à 3,1 s")
check(p1.Stars[2] > 1 and near(p1.Stars[1], 0.2) and near(CrateLoop.Sample(0.5).Stars[1], 1.25), "S7 étoiles l'une après l'autre : la 1re au sommet (× 1,25) à 0,5 s, la 2e à 1 s")
local p28 = CrateLoop.Sample(2.8)
check(near(p28.IconScale, 1.05) and near(p28.Rays, -31.5) and math.abs(p28.IconRotation) < 1e-6, "S8 t = 2,8 : secousse au milieu (× 1,05), rayons à −31,5°")
local rot265 = math.abs(CrateLoop.Sample(2.65).IconRotation)
check(rot265 > 1 and rot265 <= 5, "S9 secousse : jusqu'à ± 5° (" .. rot265 .. ")")
local p4 = CrateLoop.Sample(4)
check(near(p4.Rays, 0) and near(p4.Glow, 0.45) and near(p4.IconY, 0, 1e-9), "S10 t = 4 : la boucle repart (pas de saut)")
check(near(CrateLoop.Sample(3.999).Rays, -45, 0.05), "S11 rayons : −45° en 4 s")

---------------------------------------------------------------- 1. La caisse dans l'écran
print("-- Caisse")
local function buildShop(name)
	local gui = new("ScreenGui", { Name = name, Enabled = false })
	local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.9, 0.94) }, gui)
	local window = new("Frame", { Name = "Window", Size = UDim2.fromScale(1, 1) }, root)
	local list = new("ScrollingFrame", { Name = "List", Size = UDim2.fromScale(1, 1), AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(1200, 700) }, window)
	local content = new("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1) }, list)
	local crate = new("Frame", { Name = "Crate", Size = UDim2.fromScale(1, 1), AbsolutePosition = Vector2.new(30, 10), AbsoluteSize = Vector2.new(1130, 372) }, content)
	local backdrop = new("ImageLabel", { Name = "Backdrop", Size = UDim2.fromScale(1, 1) }, crate)
	local rays = new("ImageLabel", { Name = "Rays", Position = UDim2.fromScale(-0.1, -0.29), Size = UDim2.fromScale(0.53, 1.6), ImageTransparency = 0.3 }, backdrop)
	new("UIGradient", { Name = "Fade", Rotation = 0 }, rays)
	new("ImageLabel", { Name = "Glow", Position = UDim2.fromScale(0.03, 0.11), Size = UDim2.fromScale(0.27, 0.81), ImageTransparency = 0.2 }, backdrop)
	new("ImageLabel", { Name = "Shadow", Position = UDim2.fromScale(65 / 1130, 316 / 372), Size = UDim2.fromScale(240 / 1130, 39 / 372), ImageTransparency = 0.35 }, backdrop)
	new("ImageLabel", { Name = "Icon", Position = UDim2.fromScale(35 / 1130, 40 / 372), Size = UDim2.fromScale(300 / 1130, 300 / 372), Rotation = 5 }, crate)
	new("Frame", { Name = "NewBadge", Position = UDim2.fromScale(18 / 1130, 16 / 372), Size = UDim2.fromScale(96 / 1130, 43 / 372), Rotation = -8 }, crate)
	local odds = new("Frame", { Name = "Odds", Position = UDim2.fromScale(360 / 1130, 116 / 372), Size = UDim2.fromScale(746 / 1130, 114 / 372) }, crate)
	odds:SetAttribute("Appear", "Cascade")
	local sizes = { 94, 102, 110, 118, 126, 134 }
	local x = 0
	for i = 1, 6 do
		local sz = sizes[i]
		local y = 114 - sz
		if i >= 4 then
			local gs = 1.4 * sz
			new("ImageLabel", { Name = "RarityGlow", Position = UDim2.fromScale((x + sz / 2 - gs / 2) / 746, (y + sz / 2 - gs / 2) / 114), Size = UDim2.fromScale(gs / 746, gs / 114), ImageTransparency = 0.25 }, odds)
		end
		new("Frame", { Name = "Odd_" .. i, Position = UDim2.fromScale(x / 746, y / 114), Size = UDim2.fromScale(sz / 746, sz / 114) }, odds)
		if i >= 4 then
			local k = sz / 114
			new("ImageLabel", { Name = "Star", Position = UDim2.fromScale((x + sz * 0.8) / 746, (y - 9 * k) / 114), Size = UDim2.fromScale(25 * k / 746, 25 * k / 114) }, odds)
			new("ImageLabel", { Name = "Star", Position = UDim2.fromScale((x - 7 * k) / 746, (y + 0.3 * sz) / 114), Size = UDim2.fromScale(18 * k / 746, 18 * k / 114) }, odds)
		end
		x += sz + 12
	end
	local buyRow = new("Frame", { Name = "BuyRow", Position = UDim2.fromScale(360 / 1130, 262 / 372), Size = UDim2.fromScale(746 / 1130, 84 / 372) }, crate)
	for i = 1, 3 do
		new("TextButton", { Name = "BuyButton" .. i, Position = UDim2.fromScale((i - 1) * 255 / 746, 0), Size = UDim2.fromScale(236 / 746, 1) }, buyRow)
	end
	local decor = new("Frame", { Name = "Decor", Size = UDim2.fromScale(1, 1) }, gui)
	for i = 1, 4 do
		local hang = new("Frame", { Name = "Hang" .. i, Position = UDim2.fromScale(i * 0.2, 0), Size = UDim2.fromScale(0.05, 0.12), AbsoluteSize = Vector2.new(60, 100) }, decor)
		hang:SetAttribute("Appear", "DropIn")
	end
	gui.Parent = playerGui
	return gui
end

local shop = buildShop("UI_RobuxShop_v2")
step(0.05)
local crate = shop.Root.Window.List.Content.Crate
local odds = crate.Odds
local icon, rays, fade = crate.Icon, crate.Backdrop.Rays, crate.Backdrop.Rays.Fade
local glow, shadow = crate.Backdrop.Glow, crate.Backdrop.Shadow
local button3, badge = crate.BuyRow.BuyButton3, crate.NewBadge
local cells, stars, rarity = {}, {}, {}
for _, c in odds:GetChildren() do
	if string.match(c.Name, "^Odd_") then
		cells[tonumber(string.sub(c.Name, 5))] = c
	elseif c.Name == "Star" then
		table.insert(stars, c)
	elseif c.Name == "RarityGlow" then
		table.insert(rarity, c)
	end
end
local base = {}
for _, o in { icon, rays, glow, shadow, button3, badge, table.unpack(stars) } do
	base[o] = { Position = o.Position, Size = o.Size, Rotation = o.Rotation }
end
for _, o in rarity do
	base[o] = { Position = o.Position, Size = o.Size, Rotation = o.Rotation, T = o.ImageTransparency }
end
local cellSize = {}
for n, c in cells do
	base[c] = { Position = c.Position, Size = c.Size }
	cellSize[n] = c.Size
end
check(not CrateLoop.IsMoving(shop), "C0 écran éteint : rien ne bouge")
local hang1 = shop.Decor.Hang1
check(shop.Decor.Visible, "C0b sur PC : Decor reste visible")

shop.Enabled = true
step(1 / 30)
local t = CrateLoop.GetTime(shop)
check(CrateLoop.IsMoving(shop) and t ~= nil and t < 0.05, "C1 écran allumé : la boucle part de t = 0")
local pose = CrateLoop.Sample(t)
check(near(icon.Position.Y.Offset, pose.IconY, 1e-6) and near(icon.Rotation, 5 + pose.IconRotation, 1e-6), "C2 t ≈ 0 : Icon à sa place (± le premier pas)")
check(near(glow.ImageTransparency, pose.Glow, 1e-6), "C3 Glow suit la boucle (0,45 au départ)")
-- Cascade des cases : de Odd_1 à Odd_6, 0,033 s d'écart, RarityGlow et Star avec leur case.
step(0.04)
local s1, s6 = scaleOf(cells[1]), scaleOf(cells[6])
check(s1 ~= nil and s1.Scale > 0 and s6 ~= nil and near(s6.Scale, 0), "C4 cascade : Odd_1 entre en premier, Odd_6 attend")
step(0.1)
local rg4 = nil
for _, r in rarity do
	if math.abs(centerX(r) - centerX(cells[4])) < 1e-6 then
		rg4 = r
	end
end
local s4, sr4 = scaleOf(cells[4]), rg4 and scaleOf(rg4)
check(s4 ~= nil and sr4 ~= nil and s4.Scale > 0 and near(s4.Scale, sr4.Scale, 1e-6), "C5 RarityGlow de Odd_4 entre avec sa case")
local s5 = scaleOf(cells[5])
s6 = scaleOf(cells[6])
check(s6 ~= nil and near(s6.Scale, 0) and s5 ~= nil and s4 ~= nil and s5.Scale < s4.Scale, "C6 Odd_5 après Odd_4, Odd_6 attend encore (de la plus commune à la plus rare)")
step(0.8)
check(scaleOf(cells[6]) == nil, "C7 cascade finie : plus de UIScale sur les cases")
step(1 - CrateLoop.GetTime(shop))
t = CrateLoop.GetTime(shop)
pose = CrateLoop.Sample(t)
check(near(t, 1, 0.02), "C8 t ≈ 1 (" .. t .. ")")
check(near(rays.Rotation, pose.Rays, 1e-6) and near(fade.Rotation, -rays.Rotation, 1e-6) and rays.Rotation < -10, "C9 t ≈ 1 : rayons à ≈ −11°, Fade.Rotation = −Rays.Rotation")
local px = 372 / ShopFx.Crate.DesignHeight
local okCells = true
for n, c in cells do
	if not near(c.Position.Y.Offset, pose.OddY[n] * px, 1e-6) or c.Size ~= cellSize[n] then
		okCells = false
	end
end
check(okCells, "C10 t ≈ 1 : Odd_n décalées en Y comme la pose, Size jamais touchée")
check(near(button3.Size.X.Scale, base[button3].Size.X.Scale * pose.Button, 1e-9) and near(centerX(button3), centerX(base[button3]), 1e-9), "C11 t ≈ 1 : BuyButton3 grossit autour de son centre")
local okStars = true
for _, s in stars do
	if not near(centerX(s), centerX(base[s]), 1e-9) then
		okStars = false
	end
end
check(okStars and stars[1].Size ~= base[stars[1]].Size, "C12 étoiles : grossies autour de leur centre")
step(2.8 - CrateLoop.GetTime(shop))
t = CrateLoop.GetTime(shop)
pose = CrateLoop.Sample(t)
check(near(t, 2.8, 0.02) and pose.IconScale > 1.04, "C13 t ≈ 2,8 : la caisse grossit (× 1,05)")
check(near(icon.Size.X.Scale, base[icon].Size.X.Scale * pose.IconScale, 1e-9) and near(icon.Rotation, 5 + pose.IconRotation, 1e-9), "C14 t ≈ 2,8 : Icon écrit comme la pose (taille et secousse)")
check(near(shadow.Size.X.Scale, base[shadow].Size.X.Scale * pose.ShadowWidth, 1e-9) and shadow.Size.Y.Scale == base[shadow].Size.Y.Scale, "C15 ombre : seule sa largeur suit le mouvement")
local r1 = rarity[1]
check(near(r1.ImageTransparency, math.min(base[r1].T + pose.RarityFade, 1), 1e-9), "C16 RarityGlow pulse (transparence)")
crate.AbsolutePosition = Vector2.new(30, 900)
step(1 / 30)
check(not CrateLoop.IsMoving(shop) and sameUDim2(icon.Position, base[icon].Position) and icon.Rotation == 5 and near(rays.Rotation, 0), "C17 caisse sortie de la liste : tout revient à sa place")
crate.AbsolutePosition = Vector2.new(30, 10)
step(1 / 30)
check(CrateLoop.IsMoving(shop), "C18 caisse revenue à l'écran : la boucle reprend")
P1:SetAttribute(Settings.VfxAttribute, false)
step(0.6)
check(not CrateLoop.IsMoving(shop) and sameUDim2(icon.Position, base[icon].Position) and glow.ImageTransparency == 0.2, "C19 effets visuels coupés : pas de boucle, tout à sa place")
P1:SetAttribute(Settings.VfxAttribute, true)
step(0.6)
check(CrateLoop.IsMoving(shop), "C20 effets rallumés : la boucle reprend")
FAKE_GUISERVICE.ReducedMotionEnabled = true
step(0.6)
check(not CrateLoop.IsMoving(shop), "C21 « Réduire les mouvements » de Roblox : pas de boucle")
FAKE_GUISERVICE.ReducedMotionEnabled = false
step(0.6)
check(CrateLoop.IsMoving(shop), "C22 réglage retiré : la boucle reprend")

---------------------------------------------------------------- 2. Lueur d'un achat Robux
print("-- Lueur")
check(Appear.GetPhase(hang1) ~= "Out", "G0 décor : Hang1 tombé (DropIn)")
local enabledChanges = 0
shop:GetPropertyChangedSignal("Enabled"):Connect(function()
	enabledChanges += 1
end)
PurchaseGlow.Show()
check(PurchaseGlow.GetState() == "Idle", "G1 sans UI_PurchaseGlow : Show ne fait rien")
local hud = new("ScreenGui", { Name = "UI_HUD", Enabled = true }, playerGui)
local glowGui = new("ScreenGui", { Name = "UI_PurchaseGlow", Enabled = false }, playerGui)
local border = new("Frame", { Name = "RainbowBorder", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, glowGui)
local stroke = new("UIStroke", { Thickness = 8, Transparency = 0 }, border)
local gradient = new("UIGradient", { Rotation = 0 }, stroke)
step(0.05)
PurchaseGlow.Show()
check(PurchaseGlow.GetState() == "Shown" and glowGui.Enabled and border.Visible, "G2 Show : la lueur s'allume d'un coup")
check(#gradient.Color.Keypoints == 5 and sameColor(gradient.Color.Keypoints[1].Value, Color3.fromHex("1DC395")) and sameColor(gradient.Color.Keypoints[5].Value, Color3.fromHex("FFC21A")), "G3 dégradé resté blanc : les 5 couleurs de L-204")
step(1 / 30)
check(not hud.Enabled and shop.Enabled and glowGui.Enabled, "G4 le HUD se cache ; la boutique et la lueur restent")
local r0 = gradient.Rotation
step(0.5)
local turned = (gradient.Rotation - r0) % 360
check(near(turned, 90, 3), "G5 le dégradé tourne d'environ 0,5 tour/s (" .. turned .. "° en 0,5 s)")
FAKE_MARKET.PromptProductPurchaseFinished:Fire(P1.UserId, 123, true)
check(PurchaseGlow.GetState() == "Fading", "G6 PromptProductPurchaseFinished : la lueur s'efface")
step(0.05)
check(stroke.Transparency > 0.2 and stroke.Transparency < 0.8 and glowGui.Enabled, "G7 à mi-effacement (0,05 s) : contour à moitié transparent (" .. stroke.Transparency .. ")")
step(0.1)
check(PurchaseGlow.GetState() == "Idle" and not glowGui.Enabled and not border.Visible and stroke.Transparency == 0 and gradient.Rotation == 0, "G8 effacée en 0,1 s : écran et contour remis comme Clément les a laissés")
step(1 / 30)
check(hud.Enabled, "G9 le HUD revient")
check(enabledChanges == 0 and Appear.GetPhase(hang1) ~= "Out", "G10 la boutique n'a jamais été éteinte : le décor ne retombe pas")
local mine = ColorSequence.new(Color3.fromHex("FF0000"), Color3.fromHex("00FF00"))
gradient.Color = mine
PurchaseGlow.Show()
check(gradient.Color == mine and PurchaseGlow.GetState() == "Shown", "G11 couleurs de Clément gardées")
step(0.3)
PurchaseGlow.Show()
check(PurchaseGlow.GetState() == "Shown", "G12 rappelée pendant la lueur : elle reste")
FAKE_MARKET.PromptGamePassPurchaseFinished:Fire(P1, 456, false)
step(0.2)
check(PurchaseGlow.GetState() == "Idle" and not glowGui.Enabled and hud.Enabled, "G13 PromptGamePassPurchaseFinished : effacée, HUD revenu")
PurchaseGlow.Show()
step(ShopFx.PurchaseGlow.Timeout - 1)
check(PurchaseGlow.GetState() == "Shown", "G14 avant le délai de sécurité : encore là")
step(1.2)
check(PurchaseGlow.GetState() == "Idle" and not glowGui.Enabled and hud.Enabled, "G15 délai de sécurité : effacée toute seule")
P1:SetAttribute(Settings.VfxAttribute, false)
PurchaseGlow.Show()
step(0.5)
check(gradient.Rotation == 0 and glowGui.Enabled, "G16 effets visuels coupés : la lueur s'allume mais ne tourne pas")
FAKE_MARKET.PromptProductPurchaseFinished:Fire(P1.UserId, 1, false)
step(0.2)
P1:SetAttribute(Settings.VfxAttribute, true)
check(PurchaseGlow.GetState() == "Idle", "G17 effacée")

---------------------------------------------------------------- 3. Fermeture de la boutique
print("-- Fermeture")
step(0.7)
check(CrateLoop.IsMoving(shop), "F0 boucle en cours")
shop.Enabled = false
step(1 / 30)
local back = true
for o, b in base do
	if not sameUDim2(o.Position, b.Position) or o.Size ~= b.Size then
		back = false
		print("  pas remis : " .. o.Name)
	end
	if b.Rotation ~= nil and o.Rotation ~= b.Rotation then
		back = false
		print("  rotation pas remise : " .. o.Name)
	end
	if b.T ~= nil and o.ImageTransparency ~= b.T then
		back = false
		print("  transparence pas remise : " .. o.Name)
	end
end
check(back and not CrateLoop.IsMoving(shop), "F1 écran éteint : chaque élément exactement à la place de Clément")
check(fade.Rotation == 0 and glow.ImageTransparency == 0.2 and rays.Rotation == 0, "F2 Fade, Glow et Rays remis")
shop.Enabled = true
step(1 / 30)
local tAgain = CrateLoop.GetTime(shop)
check(CrateLoop.IsMoving(shop) and tAgain ~= nil and tAgain < 0.05, "F3 rouvert : la boucle repart de 0")
shop.Enabled = false
step(0.1)

---------------------------------------------------------------- 4. Téléphone : Decor caché
print("-- Téléphone")
FAKE_UIS.TouchEnabled = true
FAKE_UIS.KeyboardEnabled = false
local phoneShop = buildShop("UI_RobuxShop")
step(0.05)
check(not phoneShop.Decor.Visible, "T1 sur téléphone : Decor caché")
phoneShop.Enabled = true
step(0.1)
check(CrateLoop.IsMoving(phoneShop), "T2 la caisse de UI_RobuxShop tourne aussi")
phoneShop.Enabled = false
step(0.1)
FAKE_UIS.TouchEnabled = false
FAKE_UIS.KeyboardEnabled = true
phoneShop:Destroy()
step(0.1)

---------------------------------------------------------------- 5. Diamants
print("-- Diamants")
local dshop = new("ScreenGui", { Name = "UI_DiamondShop", Enabled = true })
local header = new("Frame", { Name = "Header" }, dshop)
local balance = new("Frame", { Name = "Balance" }, header)
local amount = new("TextLabel", { Name = "Amount", Text = "0" }, balance)
local spentLabel = new("TextLabel", { Name = "Spent", Text = "-0", Visible = true, Position = UDim2.new(0.5, 0, 1, 2), AbsoluteSize = Vector2.new(80, 20), TextTransparency = 0 }, balance)
local spentStroke = new("UIStroke", { Transparency = 0.1 }, spentLabel)
dshop.Parent = playerGui
step(0.1)
check(not spentLabel.Visible and amount.Text == "0", "D1 écran arrivé : Spent caché, pas de solde sans l'attribut")
P1:SetAttribute("Diamonds", 1000)
step(1 / 30)
check(amount.Text == "1K" and DiamondBalance.GetSpent() == nil, "D2 premier solde : écrit d'un coup (" .. amount.Text .. ")")
P1:SetAttribute("Diamonds", 400)
step(0.1)
check(spentLabel.Visible and spentLabel.Text == "-600" and spentLabel.TextTransparency > 0.3 and spentLabel.TextTransparency < 0.7, "D3 achat : « -600 » apparaît (à mi-apparition à 0,1 s : " .. spentLabel.TextTransparency .. ")")
check(spentStroke.Transparency > 0.1 and spentStroke.Transparency < 1, "D4 son contour apparaît avec lui")
check(amount.Text ~= "1K" and amount.Text ~= "400", "D5 le solde décompte (" .. amount.Text .. ")")
step(0.15)
check(spentLabel.TextTransparency == 0 and spentStroke.Transparency == 0.1 and sameUDim2(spentLabel.Position, UDim2.new(0.5, 0, 1, 2)), "D6 après 0,25 s : « -600 » plein, à sa place")
step(1)
check(spentLabel.Visible and spentLabel.Position.Y.Offset < 2 and spentLabel.TextTransparency > 0, "D7 après 1,25 s : il monte et s'efface")
step(0.3)
check(not spentLabel.Visible and spentLabel.TextTransparency == 0 and spentStroke.Transparency == 0.1 and sameUDim2(spentLabel.Position, UDim2.new(0.5, 0, 1, 2)) and DiamondBalance.GetSpent() == nil, "D8 après 1,55 s : caché, remis comme Clément")
check(amount.Text ~= "400", "D9 le décompte dure plus (1,9 s) : " .. amount.Text)
step(0.5)
check(amount.Text == "400", "D10 au bout de 1,9 s : exactement 400 (" .. amount.Text .. ")")
P1:SetAttribute("Diamonds", 300)
step(0.5)
P1:SetAttribute("Diamonds", 250)
step(1 / 30)
check(spentLabel.Visible and spentLabel.Text == "-150" and spentLabel.TextTransparency == 0, "D11 deux achats : « -150 », il reste à l'écran (" .. spentLabel.Text .. ")")
step(2.5)
check(amount.Text == "250" and not spentLabel.Visible, "D12 fini : 250, « -X » caché")
P1:SetAttribute("Diamonds", 5000)
step(2.5)
check(amount.Text == "5K" and not spentLabel.Visible, "D13 une hausse défile sans « -X » (" .. amount.Text .. ")")

summary()
