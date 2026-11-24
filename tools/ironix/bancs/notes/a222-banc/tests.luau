---------------------------------------------------------------- scénarios a222 (vague 66, L-210 points 6 et 9)
-- Après setup.luau du banc a50 (joueur P1 et son PlayerGui). Tweens simulés dans le temps (TIMED_TWEENS d'ext-a189).
-- Modules montés dans un dossier à part (Controllers222) : Motion, Appear, ScrollReveal, UiMotionController.
-- Les positions absolues ne bougent pas seules dans le faux Roblox : le test déplace les cartes, puis la liste.
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers222")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
local appearModule = moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
local revealModule = moduleScript(ui, "ScrollReveal", "client/Controllers/UI/ScrollReveal.luau")
CHASED = false
SOURCES["stub/ChaseController222"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController222")
local controllerModule = moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau")

local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local Motion = requireModule(motionModule, "client")
local Appear = requireModule(appearModule, "client")
local ScrollReveal = requireModule(revealModule, "client")
local UiMotionController = requireModule(controllerModule, "client")
taskLib.spawn(UiMotionController.Start)
Motion.SetSoundPlayer(function()
	return true
end)
step(0.1)
local _ = Appear

local function scaleOf(object)
	for _, child in object:GetChildren() do
		if child:IsA("UIScale") then
			return child
		end
	end
	return nil
end
local function sv(object)
	local s = scaleOf(object)
	return if s then s.Scale else nil
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
local function fmt(v)
	return if v == nil then "nil" else string.format("%.3f", v)
end
local function screen(name, props)
	local gui = new("ScreenGui", { Name = name, Enabled = false })
	for k, v in props or {} do
		gui:SetAttribute(k, v)
	end
	gui.Parent = playerGui
	return gui
end

---------------------------------------------------------------- 0. Valeurs
print("-- Valeurs")
local SR = UiMotion.ScrollReveal
check(SR.Enabled == true and SR.ArmDelay > 0 and SR.ArmDelay < 1 and SR.Split == 0.5 and SR.ScaleName == "RevealScale", "V1 ScrollReveal allumé, armé après ~0,6 s")
local function listed(name)
	return table.find(SR.Screens, name) ~= nil
end
check(listed("UI_WeaponShop") and listed("UI_AuraShop") and listed("UI_RobuxShop_v2") and listed("UI_Index_v3") and listed("UI_Displayed"), "V2 boutiques, index et objets exposés")
check(UiMotion.HoverFit.Enabled == true and UiMotion.HoverFit.Inset == 2, "V3 HoverFit allumé, 2 px")

---------------------------------------------------------------- 1. Cartes au défilement
print("-- Défilement")
-- Liste de 400 × 300 px en (100, 100) ; 10 cartes de 400 × 80, une toutes les 90 px.
local shop = screen("UI_WeaponShop")
local window = new("Frame", { Name = "Window", Size = UDim2.fromScale(0.6, 0.6) }, shop)
local list = new("ScrollingFrame", { Name = "List", AbsolutePosition = Vector2.new(100, 100), AbsoluteSize = Vector2.new(400, 300) }, window)
local template = new("Frame", { Name = "Template", Visible = false, AbsolutePosition = Vector2.new(100, 100), AbsoluteSize = Vector2.new(400, 80) }, list)
local cards = {}
for i = 0, 9 do
	cards[i] = new("Frame", { Name = `Card{i}`, AbsoluteSize = Vector2.new(400, 80) }, list)
end
local function scrollTo(y)
	for i = 0, 9 do
		cards[i].AbsolutePosition = Vector2.new(100, 100 + i * 90 - y)
	end
	list.CanvasPosition = Vector2.new(0, y)
end
for i = 0, 9 do
	cards[i].AbsolutePosition = Vector2.new(100, 100 + i * 90)
end
Motion.Open(shop)
step(0.3)
local l0 = ScrollReveal.GetCounts(shop)
check(l0 == 0, "D1 pas encore armé pendant l'ouverture (la cascade d'ouverture joue)")
step(0.5)
local l1, m1 = ScrollReveal.GetCounts(shop)
check(l1 == 1 and m1 == 0, `D2 armé après ArmDelay : 1 liste, rien qui bouge ({l1}, {m1})`)
local none = true
for i = 0, 9 do
	if scaleOf(cards[i]) ~= nil then
		none = false
	end
end
check(none, "D3 rien n'est caché d'avance (aucun UIScale)")
scrollTo(200) -- cartes 4 (y 260) et 5 (y 350) arrivent ; 2 et 3 étaient déjà visibles
check(near(sv(cards[4]) or -1, UiMotion.Appear.Cascade.From) and near(sv(cards[5]) or -1, UiMotion.Appear.Cascade.From), `D4 cartes 4 et 5 : à 0,2 dès qu'elles touchent la zone ({fmt(sv(cards[4]))}, {fmt(sv(cards[5]))})`)
check(scaleOf(cards[2]) == nil and scaleOf(cards[3]) == nil and scaleOf(cards[6]) == nil, "D5 cartes déjà vues ou encore cachées : rien")
check(scaleOf(cards[4]) ~= nil and scaleOf(cards[4]).Name == "RevealScale" and scales(cards[4]) == 1, "D6 un seul UIScale, RevealScale")
step(0.02)
local s4, s5 = sv(cards[4]), sv(cards[5])
check(s4 ~= nil and s4 > 0.2 and (s5 == nil or s5 < s4), `D7 la 4 entre d'abord, la 5 22 ms après ({fmt(s4)}, {fmt(s5)})`)
step(0.2)
local _, m2 = ScrollReveal.GetCounts(shop)
check(scaleOf(cards[4]) == nil and scaleOf(cards[5]) == nil and m2 == 0, "D8 à 1 en 0,13 s, UIScale retirés")
scrollTo(0)
scrollTo(200)
check(scaleOf(cards[4]) == nil and scaleOf(cards[2]) == nil, "D9 une fois chacune : rien en remontant ni en redescendant")
scrollTo(760) -- 8 (y 60) et 9 (y 150) ; 6 et 7 sautées par un grand défilement
check(sv(cards[8]) ~= nil and sv(cards[9]) ~= nil and scaleOf(cards[6]) == nil and scaleOf(cards[7]) == nil, "D10 grand défilement : seules les cartes visibles entrent")
check(scaleOf(template) == nil, "D11 Template jamais touché")
step(0.3)
scrollTo(400) -- 6 (y 240) et 7 (y 330), jamais vues
check(sv(cards[6]) ~= nil and sv(cards[7]) ~= nil, "D12 les cartes sautées entrent quand on y revient")
-- Fermeture pendant une entrée : tout revient.
shop.Enabled = false
local l3, m3 = ScrollReveal.GetCounts(shop)
check(l3 == 0 and m3 == 0 and scaleOf(cards[6]) == nil and scaleOf(cards[7]) == nil, "D13 écran éteint pendant l'entrée : désarmé, UIScale retirés")
-- Réouverture : de nouveau une fois chacune.
scrollTo(0)
Motion.Open(shop)
step(0.8)
scrollTo(200)
check(sv(cards[4]) ~= nil, "D14 rouverte : les cartes rentrent de nouveau en défilant")
step(0.3)
-- Carte avec son propre UIScale (Clément, survol) : pas touchée.
scrollTo(0)
local own = new("UIScale", { Name = "ClementScale", Scale = 1 }, cards[9])
shop.Enabled = false
Motion.Open(shop)
step(0.8)
scrollTo(600)
check(scales(cards[9]) == 1 and scaleOf(cards[9]) == own and sv(cards[8]) ~= nil, "D15 carte avec son propre UIScale : laissée telle quelle")
step(0.3)
own:Destroy()
-- Carte clonée après l'armement (liste refaite), déjà visible : vue, pas animée au défilement suivant.
local late = new("Frame", { Name = "Late", AbsoluteSize = Vector2.new(400, 40), AbsolutePosition = Vector2.new(100, 120) }, list)
step(0.05)
late.AbsolutePosition = Vector2.new(100, 110)
list.CanvasPosition = Vector2.new(0, 612)
check(scaleOf(late) == nil, "D16 carte clonée déjà visible : pas d'entrée au défilement suivant")
shop.Enabled = false
step(0.1)
-- Onglet caché à l'ouverture : au premier défilement une fois affiché, ce qui est visible est « vu », pas animé.
local tabs = screen("UI_AuraShop")
local page = new("Frame", { Name = "Page2", Visible = false }, tabs)
local plist = new("ScrollingFrame", { Name = "List", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(400, 300) }, page)
local p1 = new("Frame", { Name = "P1", AbsolutePosition = Vector2.new(0, 400), AbsoluteSize = Vector2.new(400, 80) }, plist)
local p2 = new("Frame", { Name = "P2", AbsolutePosition = Vector2.new(0, 600), AbsoluteSize = Vector2.new(400, 80) }, plist)
tabs.Enabled = true
step(0.8)
page.Visible = true
p1.AbsolutePosition = Vector2.new(0, 100)
plist.CanvasPosition = Vector2.new(0, 300)
local firstQuiet = scaleOf(p1) == nil
p2.AbsolutePosition = Vector2.new(0, 200)
plist.CanvasPosition = Vector2.new(0, 400)
check(firstQuiet and sv(p2) ~= nil, "D17 onglet caché à l'ouverture : 1er défilement sans entrée, puis entrée normale")
tabs.Enabled = false
step(0.1)

---------------------------------------------------------------- 2. Sections (zones de l'index)
print("-- Sections")
local index = screen("UI_Index_v3")
local ilist = new("ScrollingFrame", { Name = "List", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(400, 300) }, index)
local section = new("Frame", { Name = "Zone1Section", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(400, 700) }, ilist)
new("Frame", { Name = "ZoneBar", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(400, 40) }, section)
local cells = {}
for i = 1, 6 do
	cells[i] = new("Frame", { Name = `Cell{i}`, AbsolutePosition = Vector2.new(0, 50 + (i - 1) * 110), AbsoluteSize = Vector2.new(400, 100) }, section)
end
index.Enabled = true
step(0.8)
for i = 1, 6 do
	cells[i].AbsolutePosition = Vector2.new(0, 50 + (i - 1) * 110 - 200)
end
ilist.CanvasPosition = Vector2.new(0, 200)
-- Cell4 (y 180) et Cell5 (y 290) arrivent ; la section elle-même n'est pas mise à l'échelle.
check(scaleOf(section) == nil and sv(cells[4]) ~= nil and sv(cells[5]) ~= nil and scaleOf(cells[2]) == nil, "S1 section plus haute que la moitié de la liste : ses cases entrent une par une")
index.Enabled = false
step(0.1)

---------------------------------------------------------------- 3. Écrans
print("-- Écrans")
local other = screen("UI_T222Other")
new("ScrollingFrame", { Name = "List", AbsoluteSize = Vector2.new(400, 300) }, other)
other.Enabled = true
step(0.8)
check(ScrollReveal.GetCounts(other) == 0, "E1 écran hors de la liste : rien")
other.Enabled = false
other:SetAttribute("ScrollReveal", true)
other.Enabled = true
step(0.8)
check(ScrollReveal.GetCounts(other) == 1, "E2 attribut ScrollReveal = true : armé")
other.Enabled = false
local off = screen("UI_AuraShop", { ScrollReveal = false })
new("ScrollingFrame", { Name = "List", AbsoluteSize = Vector2.new(400, 300) }, off)
off.Enabled = true
step(0.8)
check(ScrollReveal.GetCounts(off) == 0, "E3 attribut ScrollReveal = false : coupé")
off.Enabled = false

---------------------------------------------------------------- 4. Survol gardé dans la carte (point 9)
print("-- Survol dans la carte")
local robux = screen("UI_T222Robux")
robux.Enabled = true
local rlist = new("ScrollingFrame", { Name = "List", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(800, 600) }, robux)
local card = new("Frame", { Name = "Card", AbsolutePosition = Vector2.new(100, 100), AbsoluteSize = Vector2.new(200, 100) }, rlist)
local row = new("Frame", { Name = "Row", BackgroundTransparency = 1, AbsolutePosition = Vector2.new(110, 150), AbsoluteSize = Vector2.new(180, 40) }, card)
local function button(name, parent, x, width, anchor)
	return new("TextButton", { Name = name, AnchorPoint = anchor or Vector2.new(0.5, 0.5), AbsolutePosition = Vector2.new(x, 150), AbsoluteSize = Vector2.new(width, 40) }, parent)
end
local buy = button("BuyButton", row, 110, 180)
buy:SetAttribute("Hover", "Pop")
buy:SetAttribute("Press", "Squash")
Motion.Button(buy)
buy.MouseEnter:Fire()
step(0.1)
-- Centre x = 200 ; bord de la carte 100..300, moins 2 px : (298 − 200) / 90 = 1,089 (Row, transparent, est sauté).
local limit = (298 - 200) / 90
check(near(sv(buy) or -1, limit, 0.002), `F1 Hover = Pop dans une carte : × {fmt(limit)} au lieu de 1,10 ({fmt(sv(buy))})`)
buy.MouseButton1Down:Fire()
step(0.05)
buy.MouseButton1Up:Fire()
local peak = 0
for _ = 1, 20 do
	step(0.01)
	peak = math.max(peak, sv(buy) or 1)
end
check(peak <= limit + 0.002, `F2 rebond de Squash : jamais hors de la carte ({fmt(peak)})`)
buy.MouseLeave:Fire()
step(0.3)
check(scaleOf(buy) == nil, "F3 souris sortie : taille d'origine")
local plain = button("PlainButton", card, 110, 180)
Motion.Button(plain)
plain.MouseEnter:Fire()
step(0.1)
check(near(sv(plain) or -1, 1.06), `F4 survol classique (× 1,06) : il tient dans la carte, inchangé ({fmt(sv(plain))})`)
plain.MouseLeave:Fire()
local stroked = button("StrokeButton", card, 110, 180)
new("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stroked)
stroked:SetAttribute("Hover", "Pop")
Motion.Button(stroked)
stroked.MouseEnter:Fire()
step(0.1)
check(near(sv(stroked) or -1, (300 - 5 - 200) / 90, 0.002), `F5 contour du bouton (3 px) compté : × {fmt(sv(stroked))}`)
stroked.MouseLeave:Fire()
local full = button("FullButton", card, 100, 200)
full:SetAttribute("Hover", "Pop")
Motion.Button(full)
full.MouseEnter:Fire()
step(0.1)
check(sv(full) == nil or near(sv(full), 1), "F6 bouton aussi large que la carte : il ne grossit pas (assombri seulement)")
full.MouseLeave:Fire()
local corner = button("CornerButton", card, 255, 40, Vector2.new(0, 0))
corner:SetAttribute("Hover", "Pop")
Motion.Button(corner)
corner.MouseEnter:Fire()
step(0.1)
check(near(sv(corner) or -1, (298 - 255) / 40, 0.002), `F7 AnchorPoint (0, 0) : il grossit vers la droite jusqu'au bord ({fmt(sv(corner))})`)
corner.MouseLeave:Fire()
step(0.3)
Motion.Success(buy)
local jump = 0
for _ = 1, 30 do
	step(0.01)
	jump = math.max(jump, sv(buy) or 1)
end
check(jump <= limit + 0.002, `F8 réussite (× 1,22) : gardée dans la carte ({fmt(jump)})`)
-- Hors d'une liste : comme avant.
local hud = screen("UI_T222Hud")
hud.Enabled = true
local holder = new("Frame", { Name = "Holder", AbsolutePosition = Vector2.new(100, 100), AbsoluteSize = Vector2.new(200, 100) }, hud)
local free = button("FreeButton", holder, 100, 200)
free:SetAttribute("Hover", "Pop")
Motion.Button(free)
free.MouseEnter:Fire()
step(0.1)
check(near(sv(free) or -1, 1.1), "F9 hors d'une liste (HUD) : × 1,10 comme avant")
free.MouseLeave:Fire()

---------------------------------------------------------------- 5. Animations réduites
print("-- Animations réduites")
P1:SetAttribute("VfxEnabled", false)
scrollTo(0)
shop.Enabled = false
Motion.Open(shop)
step(0.8)
scrollTo(200)
check(ScrollReveal.GetCounts(shop) == 0 and scaleOf(cards[4]) == nil, "R1 animations réduites : rien au défilement")
shop.Enabled = false
P1:SetAttribute("VfxEnabled", nil)
step(1)
summary()
