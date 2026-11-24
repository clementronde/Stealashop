---------------------------------------------------------------- scénarios a189 (vague 59, L-182 points 1 à 3)
-- Après setup.luau du banc a50 (joueur P1 et son PlayerGui). Tweens simulés dans le temps (TIMED_TWEENS). Les modules
-- d'a189 sont montés dans un dossier à part (Controllers189), avec une copie fraîche de Motion qui y trouve Appear.
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers189")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
local appearModule = moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
local rarityModule = moduleScript(ui, "RarityFx", "client/Controllers/UI/RarityFx.luau")
CHASED = false
SOURCES["stub/ChaseController"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController")
local controllerModule = moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau")

local Motion = requireModule(motionModule, "client")
local Appear = requireModule(appearModule, "client")
local RarityFx = requireModule(rarityModule, "client")
local UiMotionController = requireModule(controllerModule, "client")
taskLib.spawn(UiMotionController.Start)
local SOUNDS = {}
Motion.SetSoundPlayer(function(name)
	table.insert(SOUNDS, name)
	return true
end)
step(0.1)

local function scaleOf(object)
	for _, child in object:GetChildren() do
		if child:IsA("UIScale") then
			return child
		end
	end
	return nil
end
local function scales(object)
	local n = 0
	for _, child in object:GetChildren() do
		if child:IsA("UIScale") then
			n += 1
		end
	end
	return n
end
local function screen(name, props)
	local gui = new("ScreenGui", { Name = name, Enabled = false })
	for k, v in props or {} do
		gui:SetAttribute(k, v)
	end
	gui:SetAttribute("ScreenGroup", "Menu")
	gui.Parent = playerGui
	return gui
end

---------------------------------------------------------------- 1. Pop
print("-- Pop")
local shop = screen("UI_TestPop")
local window = new("Frame", { Name = "Window", Size = UDim2.fromScale(0.5, 0.5) }, shop)
window:SetAttribute("Appear", "Pop")
local plain = new("Frame", { Name = "Plain", Size = UDim2.fromScale(0.3, 0.3) }, shop)
step(0.05)
Motion.Open(shop)
local s = scaleOf(window)
check(shop.Enabled and s ~= nil and s.Name == "AppearScale" and near(s.Scale, 0.55), "P1 ouverture : Window part de 0,55 (UIScale AppearScale)")
check(scales(window) == 1, "P2 un seul UIScale sur Window (Motion ne le met pas à l'échelle)")
check(scaleOf(plain) ~= nil and scaleOf(plain).Name ~= "AppearScale", "P3 un cadre sans Appear garde l'ouverture de Motion")
step(0.075)
s = scaleOf(window)
check(s ~= nil and s.Scale > 0.8 and s.Scale < 1, "P4 à mi-course (0,075 s) : entre 0,8 et 1 (Quint Out)")
step(0.1)
check(scaleOf(window) == nil and Appear.GetPhase(window) == nil, "P5 au bout de 0,15 s : Window à sa taille, UIScale retiré")
Motion.Close(shop)
step(0.035)
s = scaleOf(window)
check(shop.Enabled and s ~= nil and s.Scale < 1 and s.Scale > 0, "P6 fermeture : Window rapetisse, écran encore allumé")
step(0.1)
check(not shop.Enabled and scaleOf(window) == nil, "P7 fermeture finie (0,07 s) : écran éteint, Window remis à l'état de Clément")
-- Deux ouvertures rapides.
Motion.Open(shop)
step(0.05)
Motion.Close(shop)
step(0.03)
Motion.Open(shop)
check(scales(window) <= 1, "P8 deux ouvertures rapides : jamais deux UIScale")
step(0.3)
check(shop.Enabled and scaleOf(window) == nil and Motion.GetState(shop) == "Open", "P9 deux ouvertures rapides : ouvert, Window à sa taille")
-- Éteint directement pendant l'entrée.
Motion.Close(shop)
step(0.3)
Motion.Open(shop)
step(0.03)
shop.Enabled = false
check(scaleOf(window) == nil, "P10 écran éteint pendant l'entrée : UIScale retiré tout de suite")

---------------------------------------------------------------- 2. Cascade
print("-- Cascade")
local list = screen("UI_TestCascade")
local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, list)
local cards = new("Frame", { Name = "Cards", Size = UDim2.fromScale(1, 0.8) }, root)
cards:SetAttribute("Appear", "Cascade")
local template = new("Frame", { Name = "Template", Visible = false, LayoutOrder = 0 }, cards)
new("Frame", { Name = "HoverOutline", Visible = false }, template)
local c3 = new("Frame", { Name = "Card3", LayoutOrder = 3 }, cards)
local c1 = new("Frame", { Name = "Card1", LayoutOrder = 1 }, cards)
local c2 = new("Frame", { Name = "Card2", LayoutOrder = 2 }, cards)
new("Frame", { Name = "HoverOutline", Visible = false }, c1)
step(0.05)
Motion.Open(list)
check(scaleOf(c1) and near(scaleOf(c1).Scale, 0) and scaleOf(c2) and scaleOf(c3) and near(scaleOf(c3).Scale, 0), "C1 ouverture : les 3 cartes attendent à 0")
check(scaleOf(template) == nil and scales(c1) == 1, "C2 Template jamais touché ; Card1 (HoverOutline) sans l'entrée OpenStagger de Motion")
check(scaleOf(cards) == nil, "C3 le fond (Cards) est là tout de suite")
step(0.07)
check(scaleOf(c1).Scale > 0 and near(scaleOf(c2).Scale, 0), "C4 à 0,07 s : Card1 entre, Card2 attend (ordre LayoutOrder)")
step(0.05)
check(scaleOf(c2) and scaleOf(c2).Scale > 0 and near(scaleOf(c3).Scale, 0), "C5 à 0,12 s : Card2 entre (0,05 s après), Card3 attend")
local late = template:Clone()
late.Visible = true
late.Name = "Template"
late.Parent = cards
late.Name = "Card4" -- copie renommée juste après son arrivée, comme un contrôleur
late.LayoutOrder = 4
step(1 / 30)
check(scaleOf(late) ~= nil and near(scaleOf(late).Scale, 0), "C6 carte clonée juste après l'ouverture : elle entre aussi, à la suite")
step(0.6)
check(scaleOf(c1) == nil and scaleOf(c2) == nil and scaleOf(c3) == nil and scaleOf(late) == nil and Appear.GetPhase(cards) == nil, "C7 au bout : toutes les cartes à leur taille, UIScale retirés")
local after = c1:Clone()
after.Name = "Card5"
after.Parent = cards
step(0.1)
check(scaleOf(after) == nil, "C8 carte ajoutée bien après l'ouverture : pas d'entrée")
Motion.Close(list)
step(0.035)
check(scaleOf(c1) and scaleOf(c1).Scale < 1 and scaleOf(c2) and scaleOf(c2).Scale < 1, "C9 fermeture : toutes les cartes rapetissent ensemble")
step(0.2)
check(not list.Enabled and scaleOf(c1) == nil and scaleOf(c2) == nil, "C10 fermée : cartes remises")

---------------------------------------------------------------- 3. Stamp
print("-- Stamp")
local stampGui = screen("UI_TestStamp")
local title = new("TextLabel", { Name = "Title", Rotation = 2, Size = UDim2.fromScale(0.4, 0.1) }, stampGui)
title:SetAttribute("Appear", "Stamp")
step(0.05)
Motion.Open(stampGui)
check(scaleOf(title) and near(scaleOf(title).Scale, 1.6) and near(title.Rotation, -3), "S1 tampon : 1,6 et −5° (Rotation 2 de Clément → −3)")
step(0.2)
check(scaleOf(title) == nil and near(title.Rotation, 2), "S2 au bout de 0,13 s : taille et Rotation de Clément exactement")
Motion.Open(stampGui)
check(scaleOf(title) == nil, "S3 écran déjà ouvert : pas de nouvelle entrée")
Motion.Close(stampGui)
step(0.2)
check(not stampGui.Enabled and scaleOf(title) == nil and near(title.Rotation, 2), "S4 fermé : remis")

---------------------------------------------------------------- 4. SlideRight
print("-- SlideRight")
local displayed = screen("UI_TestSlide")
local panel = new("Frame", { Name = "Panel", Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromScale(0.3, 0.8), AbsolutePosition = Vector2.new(700, 60) }, displayed)
panel:SetAttribute("Appear", "SlideRight")
step(0.05)
Motion.Open(displayed)
check(panel.Position.X.Scale == 1 and near(panel.Position.X.Offset, 280) and panel.Position.Y.Scale == 0.5, "R1 ouverture : le panneau part de derrière le bord droit (+300 px)")
step(0.085)
check(panel.Position.X.Offset < 280 and panel.Position.X.Offset > -20, "R2 à mi-course : il glisse")
step(0.15)
check(near(panel.Position.X.Offset, -20) and panel.Position.X.Scale == 1 and panel:FindFirstChild("AppearSlide") == nil, "R3 au bout de 0,17 s : Position de Clément exactement, NumberValue retirée")
Motion.Close(displayed)
step(0.05)
check(displayed.Enabled and panel.Position.X.Offset > -20, "R4 fermeture : il repart vers la droite")
step(0.2)
check(not displayed.Enabled and near(panel.Position.X.Offset, -20) and panel:FindFirstChild("AppearSlide") == nil, "R5 fermé : Position remise")
-- Le panneau seul (Visible), dans un écran allumé : Motion.Show et Motion.Hide.
displayed.Enabled = true
panel.Visible = false
step(0.05)
Motion.Show(panel)
check(panel.Visible and near(panel.Position.X.Offset, 280) and scaleOf(panel) == nil, "R6 Motion.Show : il glisse (pas d'échelle de Motion)")
step(0.3)
Motion.Hide(panel)
step(0.05)
check(panel.Visible, "R7 Motion.Hide : il attend la sortie")
step(0.2)
check(not panel.Visible and near(panel.Position.X.Offset, -20), "R8 caché après la sortie, Position remise")
displayed.Enabled = false

---------------------------------------------------------------- 5. Hover = Pop, Press = Squash (boutons)
print("-- Boutons")
local hud = screen("UI_TestButtons")
hud.Enabled = true
local holder = new("Frame", { Name = "Holder", Size = UDim2.fromScale(0.5, 0.5) }, hud)
local play = new("TextButton", { Name = "PlayButton", Size = UDim2.fromScale(0.2, 0.1) }, holder)
play:SetAttribute("Hover", "Pop")
play:SetAttribute("Press", "Squash")
local old = new("TextButton", { Name = "OldButton", Size = UDim2.fromScale(0.2, 0.1) }, holder)
Motion.Button(play)
Motion.Button(old)
play.MouseEnter:Fire()
old.MouseEnter:Fire()
step(0.1)
check(scaleOf(play) and near(scaleOf(play).Scale, 1.1), "B1 Hover = Pop : × 1,10 en 0,067 s")
check(scaleOf(old) and near(scaleOf(old).Scale, 1.06), "B2 sans attribut : survol validé × 1,06 (inchangé)")
play.MouseButton1Down:Fire()
step(0.05)
check(near(scaleOf(play).Scale, 0.75), "B3 Press = Squash : 0,75 en 0,033 s")
play.MouseButton1Up:Fire()
step(0.05)
check(near(scaleOf(play).Scale, 1.1 * 1.1), "B4 relâché : rebond à 1,1 fois le survol")
step(0.15)
check(near(scaleOf(play).Scale, 1.1), "B5 retour au survol en 0,1 s")
play.MouseLeave:Fire()
old.MouseLeave:Fire()
step(0.2)
check(scaleOf(play) == nil and scaleOf(old) == nil, "B6 souris sortie : taille d'origine, UIScale retirés")
-- Au doigt : appui, puis fin du toucher (sans MouseLeave).
play.MouseButton1Down:Fire()
step(0.05)
play.MouseButton1Up:Fire()
play.InputEnded:Fire({ UserInputType = "Enum.UserInputType.Touch" })
step(0.05)
check(scaleOf(play) and near(scaleOf(play).Scale, 1.1), "B7 au doigt : rebond à 1,1")
step(0.2)
check(scaleOf(play) == nil, "B8 au doigt : retour à 1, UIScale retiré")
-- Sortie de la souris pendant le rebond : il finit, puis revient à 1.
play.MouseEnter:Fire()
play.MouseButton1Down:Fire()
step(0.05)
play.MouseButton1Up:Fire()
step(0.02)
play.MouseLeave:Fire()
step(0.3)
check(scaleOf(play) == nil, "B9 souris sortie pendant le rebond : retour à 1")

---------------------------------------------------------------- 6. Hover = Pop sur une carte
print("-- Carte")
local card = new("Frame", { Name = "Card", Rotation = 1, Size = UDim2.fromScale(0.2, 0.3) }, holder)
card:SetAttribute("Hover", "Pop")
local icon = new("ImageLabel", { Name = "Icon", Rotation = 4, Position = UDim2.fromScale(0.5, 0.5) }, card)
Motion.HoverCard(card)
card.MouseEnter:Fire()
step(0.1)
check(near(card.Rotation, 4) and scaleOf(icon) and near(scaleOf(icon).Scale, 1.15) and near(icon.Rotation, 4), "K1 carte survolée : penche de 3°, Icon × 1,15 sans tourner")
card.MouseLeave:Fire()
step(0.2)
check(near(card.Rotation, 1) and scaleOf(icon) == nil and near(icon.Rotation, 4) and icon.Position.X.Scale == 0.5, "K2 sortie : carte et Icon exactement à l'état de Clément")

---------------------------------------------------------------- 7. Un son par action
print("-- Sons")
table.clear(SOUNDS)
local clicks = 0
local function click()
	clicks += 1
end
play.MouseEnter:Fire()
step(0.2)
Motion.Click(play, click)
step(1 / 30)
check(clicks == 1, "N1 clic simple : un son de clic (le survol ne compte pas)")
Motion.Click(play, click)
Motion.PlaySound("UI_Open")
step(1 / 30)
check(clicks == 1, "N2 clic qui ouvre une fenêtre : UI_Open seul")
step(0.2)
local buy = new("TextButton", { Name = "BuyButton" }, holder)
Motion.Click(buy, click)
step(1 / 30)
check(clicks == 1, "N3 bouton de réussite (BuyButton) : pas de clic, UI_Success suivra")
play.MouseLeave:Fire()
step(0.3)

---------------------------------------------------------------- 8. Raretés qui bougent
print("-- Raretés")
local rgui = screen("UI_TestRarity")
rgui.Enabled = true
local label = new("TextLabel", { Name = "ItemName", TextColor3 = Color3.new(0.2, 0.3, 0.4) }, rgui)
local clip = new("Frame", { Name = "Clip", BackgroundColor3 = Color3.new(0.5, 0.5, 0.5) }, rgui)
local own = new("UIGradient", { Name = "RarityGradient", Rotation = 12 }, clip)
local ownColor = own.Color
local gradientOf = function(o)
	return o:FindFirstChild("RarityGradient")
end
check(RarityFx.Apply(label, "Epic") == "Static", "G1 Épique : dégradé fixe")
local g = gradientOf(label)
check(g ~= nil and #g.Color.Keypoints == 2 and g.Rotation == 90 and sameColor(label.TextColor3, Color3.new(1, 1, 1)), "G2 dégradé créé (2 couleurs, de haut en bas), texte en blanc")
check(not RarityFx.IsRunning(), "G3 dégradé fixe : rien ne tourne")
for _, id in { "Common", "Uncommon", "Rare" } do
	check(RarityFx.KindOf(id) == "Static", "G4 " .. id .. " : fixe")
end
check(RarityFx.Apply(label, "Legendary") == "Sheen" and RarityFx.IsRunning(), "G5 Légendaire : reflet, Heartbeat branché")
local seen = 0
for _ = 1, 20 do
	step(0.1)
	if #gradientOf(label).Color.Keypoints > 2 then
		seen += 1
	end
end
check(seen > 0 and seen < 20, "G6 le reflet passe puis s'en va (" .. seen .. " images sur 20)")
check(RarityFx.Apply(clip, "Mythic") == "Rainbow" and RarityFx.Apply(label, "Secret") == "Rainbow", "G7 Mythique et Secret : arc-en-ciel")
check(gradientOf(clip) == own and own.Rotation == 0, "G8 le UIGradient RarityGradient de Clément est repris")
local first = own.Color.Keypoints[1].Value
step(0.5)
local moved = own.Color.Keypoints[1].Value
check(not sameColor(first, moved), "G9 l'arc-en-ciel défile")
step(2.5)
local back = own.Color.Keypoints[1].Value
check(math.abs(back.R - first.R) < 0.02 and math.abs(back.G - first.G) < 0.02 and math.abs(back.B - first.B) < 0.02, "G10 un tour en 3 s")
local okKeys = true
for _, kp in own.Color.Keypoints do
	okKeys = okKeys and kp.Time >= 0 and kp.Time <= 1
end
check(okKeys and own.Color.Keypoints[1].Time == 0 and own.Color.Keypoints[#own.Color.Keypoints].Time == 1, "G11 suite de couleurs valide (de 0 à 1)")
rgui.Enabled = false
step(0.1)
check(not RarityFx.IsRunning(), "G12 écran éteint : plus rien ne tourne")
rgui.Enabled = true
step(0.1)
check(RarityFx.IsRunning(), "G13 écran rallumé : ça repart")
RarityFx.Clear(label)
RarityFx.Clear(clip)
check(gradientOf(label) == nil and sameColor(label.TextColor3, Color3.new(0.2, 0.3, 0.4)), "G14 Clear : dégradé créé retiré, couleur du texte de Clément")
check(own.Parent == clip and own.Color == ownColor and own.Rotation == 12 and sameColor(clip.BackgroundColor3, Color3.new(0.5, 0.5, 0.5)), "G15 Clear : UIGradient de Clément remis tel quel")
step(0.1)
check(not RarityFx.IsRunning(), "G16 plus rien à animer : Heartbeat débranché")
check(RarityFx.Apply(label, "Nope") == nil and gradientOf(label) == nil, "G17 rareté inconnue : rien")

---------------------------------------------------------------- 9. Flou
print("-- Flou")
local function blurEffect()
	return LightingService:FindFirstChild("UiBlur")
end
local aura = screen("UI_AuraShop")
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, aura)
step(0.05)
Motion.Open(aura)
step(0.3)
check(blurEffect() ~= nil and near(blurEffect().Size, 12), "F1 boutique ouverte : flou à 12 dans Lighting")
Motion.Close(aura)
step(0.1)
check(blurEffect() ~= nil and blurEffect().Size < 12, "F2 fermeture : le flou part")
step(0.2)
check(blurEffect() == nil and not UiMotionController.GetBlur().Active, "F3 parti en 0,17 s : BlurEffect retiré")
CHASED = true
Motion.Open(aura)
step(0.3)
check(blurEffect() == nil, "F4 en poursuite : jamais de flou")
CHASED = false
step(0.3)
check(blurEffect() ~= nil and near(blurEffect().Size, 12), "F5 poursuite finie, boutique ouverte : le flou revient")
CHASED = true
step(0.3)
check(blurEffect() == nil, "F6 poursuite qui commence boutique ouverte : flou parti")
CHASED = false
aura.Enabled = false
step(0.3)
check(blurEffect() == nil, "F7 boutique éteinte : pas de flou")
local other = screen("UI_TestNoBlur")
Motion.Open(other)
step(0.3)
check(blurEffect() == nil, "F8 écran sans flou : rien")
Motion.Close(other)
local marked = screen("UI_TestBlurAttr", { Blur = true })
step(0.05)
Motion.Open(marked)
step(0.3)
check(blurEffect() ~= nil, "F9 ScreenGui avec l'attribut Blur = true : flou")
marked.Enabled = false
step(0.3)
check(blurEffect() == nil, "F10 éteint : flou parti")

---------------------------------------------------------------- 9b. DropIn (L-188) et valeurs de L-188
print("-- DropIn")
check(RarityFx.KindOf("Divine") == "Rainbow", "D0 L-188 : Divine en arc-en-ciel")
local robux = screen("UI_TestDrop")
local decor = new("Frame", { Name = "Decor", Size = UDim2.fromScale(1, 1) }, robux)
local hang1 = new("ImageLabel", { Name = "Hang1", Rotation = 1, Position = UDim2.new(0.2, 0, 0, 10), Size = UDim2.fromScale(0.1, 0.2), AbsoluteSize = Vector2.new(100, 120) }, decor)
local hang2 = new("ImageLabel", { Name = "Hang2", Rotation = 0, Position = UDim2.new(0.4, 0, 0, 10), Size = UDim2.fromScale(0.1, 0.2), AbsoluteSize = Vector2.new(100, 120) }, decor)
hang1:SetAttribute("Appear", "DropIn")
hang2:SetAttribute("Appear", "DropIn")
step(0.05)
Motion.Open(robux)
check(near(hang1.Position.Y.Offset, 10 - 120) and near(hang2.Position.Y.Offset, 10 - 120) and hang1.Position.X.Scale == 0.2, "D1 ouverture : les décors attendent une hauteur au-dessus de leur place")
step(0.04)
check(hang1.Position.Y.Offset > -110 and near(hang2.Position.Y.Offset, -110), "D2 Hang1 tombe, Hang2 part 0,05 s après")
step(0.3)
check(near(hang1.Position.Y.Offset, 10) and hang1:FindFirstChild("AppearSlide") == nil and Appear.GetPhase(hang1) == "In", "D3 à sa place (Position exacte), NumberValue retirée, il se balance")
step(0.3)
check(hang1.Rotation > 3 and hang1.Rotation <= 3.5 + 1e-6, "D4 balancement : jusqu'à +2,5° autour de sa Rotation")
Motion.Close(robux)
step(0.3)
check(not robux.Enabled and near(hang1.Rotation, 1) and near(hang1.Position.Y.Offset, 10) and Appear.GetPhase(hang1) == nil, "D5 fermé : Rotation et Position de Clément, balancement arrêté")
local popGui = screen("UI_TestPopClose")
local win2 = new("Frame", { Name = "Window", Size = UDim2.fromScale(0.5, 0.5) }, popGui)
win2:SetAttribute("Appear", "Pop")
step(0.05)
Motion.Open(popGui)
step(0.3)
Motion.Close(popGui)
step(0.069)
check(scaleOf(win2) and scaleOf(win2).Scale > 0.4 and scaleOf(win2).Scale < 0.45, "D6 L-188 : la fermeture de Pop va jusqu'à 0,4")
step(0.1)

---------------------------------------------------------------- 10. Connexions
print("-- Connexions")
local leak = screen("UI_TestLeak")
local leakRoot = new("Frame", { Name = "Root" }, leak)
local box = new("Frame", { Name = "Box" }, leakRoot)
box:SetAttribute("Appear", "Pop")
step(0.05)
local count0 = UiMotionController.GetWatchCount()
local copy = box:Clone()
copy.Name = "Box2"
copy.Parent = leakRoot
step(1 / 30)
check(UiMotionController.GetWatchCount() == count0 + 1 and handlerCount(copy) > 0, "L1 copie avec Appear : suivie")
copy:Destroy()
step(1 / 30)
check(UiMotionController.GetWatchCount() == count0 and handlerCount(copy) == 0, "L2 copie détruite : plus aucune connexion")
Motion.Open(leak)
step(0.05)
leak:Destroy()
step(0.3)
check(handlerCount(leak) == 0 and handlerCount(box) == 0, "L3 écran détruit en pleine entrée : plus aucune connexion")
local tpl = new("Frame", { Name = "Template", Visible = false }, root)
local inner = new("Frame", { Name = "Inner" }, tpl)
inner:SetAttribute("Appear", "Pop")
step(1 / 30)
check(handlerCount(inner) == 0, "L4 dans un Template : pas suivi (ses copies le seront)")
local logBefore = logCount("[UiMotion]", "PRINT", "client")
local bad = new("Frame", { Name = "Bad" }, root)
bad:SetAttribute("Appear", "Bounce")
step(1 / 30)
check(logCount("[UiMotion]", "PRINT", "client") == logBefore + 1 and not Appear.Has(bad), "L5 valeur inconnue : une ligne dans la sortie, ignorée")
step(1)
summary()
