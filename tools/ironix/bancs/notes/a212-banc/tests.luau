---------------------------------------------------------------- scénarios a212 (vague 64, écrans comme dans la vidéo)
-- Après setup.luau du banc a50 (joueur P1 et son PlayerGui). Tweens simulés dans le temps (TIMED_TWEENS d'ext-a189).
-- Modules montés dans un dossier à part (Controllers212) : Motion, Appear, HudMask, UiMotionController.
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers212")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
local appearModule = moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
local hudMaskModule = moduleScript(ui, "HudMask", "client/Controllers/UI/HudMask.luau")
CHASED = false
SOURCES["stub/ChaseController212"] = [==[
local ChaseController = {}
function ChaseController.IsChased() return CHASED end
return ChaseController
]==]
moduleScript(ctrl, "ChaseController", "stub/ChaseController212")
local controllerModule = moduleScript(ctrl, "UiMotionController", "client/Controllers/UiMotionController.luau")

local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local Motion = requireModule(motionModule, "client")
local Appear = requireModule(appearModule, "client")
local HudMask = requireModule(hudMaskModule, "client")
local UiMotionController = requireModule(controllerModule, "client")
taskLib.spawn(UiMotionController.Start)
Motion.SetSoundPlayer(function()
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
-- Avance jusqu'à `t` s après `t0` (temps simulé).
local clock = 0
local function mark()
	clock = 0
end
local function to(t)
	if t > clock then
		step(t - clock)
		clock = t
	end
end

---------------------------------------------------------------- 0. Valeurs (Config/UiMotion)
print("-- Valeurs")
check(UiMotion.VideoRhythm == true, "V1 interrupteur VideoRhythm allumé")
check(UiMotion.Open.From == 0.55 and UiMotion.Open.Time == 0.38 and UiMotion.Open.Style == Enum.EasingStyle.Back and UiMotion.Open.Direction == Enum.EasingDirection.Out, "V2 ouverture : 0,55 → 1 en 0,38 s, Back Out")
check(UiMotion.Close.To == 0 and UiMotion.Close.Time == 0.2 and UiMotion.Close.Style == Enum.EasingStyle.Back and UiMotion.Close.Direction == Enum.EasingDirection.In, "V3 fermeture : 1 → 0 en 0,2 s, Back In")
local pop = UiMotion.Appear.Pop
check(pop.From == 0.55 and pop.Time == 0.38 and pop.Style == Enum.EasingStyle.Back and pop.CloseTo == 0 and pop.CloseTime == 0.2 and pop.CloseStyle == Enum.EasingStyle.Back, "V4 Appear = Pop : mêmes valeurs")
local cas = UiMotion.Appear.Cascade
check(cas.Gap == 0.022 and cas.Start == 0.23 and cas.From == 0.2 and cas.Time == 0.13 and cas.Style == Enum.EasingStyle.Quad, "V5 Cascade : 22 ms, +230 ms, 0,2 → 1 en 0,13 s Quad Out")
local st = UiMotion.OpenStagger
check(st.Gap == 0.022 and st.Start == 0.23 and st.From == 0.2 and st.Time == 0.13 and st.Style == Enum.EasingStyle.Quad and st.Max == 8, "V6 OpenStagger : comme les cartes de la vidéo")
local bl = UiMotion.Appear.Blocks
check(bl.Enabled and bl.Start == 0.13 and bl.Gap == 0.065 and bl.Start + bl.Span + bl.Time <= 0.6, "V7 blocs : +130 ms, 65 ms d'écart, tout en place vers 0,5 s")
local aw = UiMotion.HudAway
check(aw.Enabled and aw.OutTime == 0.15 and aw.BackTime == 0.17 and aw.OutStyle == Enum.EasingStyle.Quad and aw.BackStyle == Enum.EasingStyle.Back, "V8 barre du bas : sort en 0,15 s, revient en 0,17 s")

---------------------------------------------------------------- 1. Ouverture
print("-- Ouverture")
local shop = screen("UI_T212Open")
local window = new("Frame", { Name = "Window", Size = UDim2.fromScale(0.5, 0.5) }, shop)
window:SetAttribute("Appear", "Pop")
local plain = new("Frame", { Name = "Plain", Size = UDim2.fromScale(0.3, 0.3) }, shop)
step(0.05)
Motion.Open(shop)
mark()
check(shop.Enabled and near(sv(window) or -1, 0.55) and near(sv(plain) or -1, 0.55), `O1 t = 0 : Pop et cadre racine à 0,55 ({fmt(sv(window))}, {fmt(sv(plain))})`)
check(scales(window) == 1, "O2 un seul UIScale sur Window")
to(0.19)
local w19, p19 = sv(window), sv(plain)
check(w19 ~= nil and w19 > 1.02 and w19 < 1.06 and p19 ~= nil and p19 > 1.02 and p19 < 1.06, `O3 t = 0,19 s : déjà au-dessus de 1 (Back Out ; {fmt(w19)}, {fmt(p19)})`)
local peak = 0
while clock < 0.37 do
	to(clock + 0.01)
	peak = math.max(peak, sv(window) or 0)
end
check(peak > 1.035 and peak < 1.056, `O4 dépassement : ~1,045 au plus haut ({fmt(peak)})`)
to(0.4)
check(scaleOf(window) == nil and scaleOf(plain) == nil and Motion.GetState(shop) == "Open", "O5 t = 0,38 s : à 1, UIScale retirés")

---------------------------------------------------------------- 2. Fermeture
print("-- Fermeture")
Motion.Close(shop)
mark()
to(0.06)
check(shop.Enabled and sv(window) ~= nil and near(sv(window), 1.08, 0.015) and near(sv(plain) or -1, 1.08, 0.015), `C1 t = 0,06 s : elle prend son élan (Back In ; {fmt(sv(window))}, {fmt(sv(plain))})`)
local swell = 0
while clock < 0.19 do
	to(clock + 0.01)
	swell = math.max(swell, sv(window) or 0)
end
check(swell > 1.09 and swell < 1.105, `C2 elle gonfle d'environ 10 % ({fmt(swell)})`)
check(shop.Enabled and (sv(window) or 1) < 0.3, `C3 t = 0,19 s : presque à 0, écran encore allumé ({fmt(sv(window))})`)
to(0.25)
check(not shop.Enabled and scaleOf(window) == nil and scaleOf(plain) == nil and Motion.GetState(shop) == "Closed", "C4 t = 0,2 s : éteint, tout remis à l'état de Clément")

---------------------------------------------------------------- 3. Fermeture puis réouverture rapide
print("-- Réouverture")
Motion.Open(shop)
step(0.5)
Motion.Close(shop)
step(0.08)
local before = sv(window)
Motion.Open(shop)
check(scales(window) <= 1 and scales(plain) <= 1, "Q1 rouvert pendant la fermeture : jamais deux UIScale")
check(sv(window) ~= nil and near(sv(window), before or -1, 0.02), `Q2 il repart de là où il en est ({fmt(before)} → {fmt(sv(window))})`)
mark()
to(0.25)
check(shop.Enabled and Motion.GetState(shop) ~= "Closed", "Q3 la fermeture est annulée : l'écran reste allumé après 0,2 s")
to(0.5)
check(shop.Enabled and Motion.GetState(shop) == "Open" and scaleOf(window) == nil and scaleOf(plain) == nil, "Q4 ouvert, à sa taille, UIScale retirés")
Motion.Close(shop)
step(0.3)

---------------------------------------------------------------- 4. Blocs
print("-- Blocs")
local blocksGui = screen("UI_T212Blocks")
local frame = new("Frame", { Name = "Window", Size = UDim2.fromScale(0.6, 0.6) }, blocksGui)
local blocksWindow = frame
local function block(name, kind, x, y, props)
	local p = props or {}
	p.Name = name
	p.Size = UDim2.fromScale(0.5, 0.1)
	p.AbsolutePosition = Vector2.new(x, y)
	local b = new(if kind == "Stamp" then "TextLabel" else "Frame", p, frame)
	b:SetAttribute("Appear", kind)
	return b
end
-- Ordre de l'arbre mélangé : l'ordre de lecture (haut → bas, puis gauche → droite) doit gagner.
local buy = block("BuyButton", "Stamp", 100, 300, { Rotation = 2 })
local row2 = block("Row2", "Pop", 300, 151)
local tabs = block("Tabs", "Pop", 100, 100)
local title = block("Title", "Pop", 100, 50)
local row1 = block("Row1", "Pop", 100, 150)
local list = { title, tabs, row1, row2, buy }
step(0.05)
Motion.Open(blocksGui)
mark()
local allHidden = true
for _, b in list do
	allHidden = allHidden and sv(b) ~= nil and near(sv(b), 0)
end
check(allHidden and near(buy.Rotation, 2), "B1 t = 0 : les 5 blocs attendent cachés (UIScale à 0), Rotation de Clément")
check(scaleOf(frame) ~= nil and near(sv(frame), 0.55), "B2 le cadre, lui, s'ouvre tout de suite (0,55)")
to(0.12)
check(near(sv(title) or -1, 0) and near(sv(tabs) or -1, 0), "B3 t = 0,12 s : rien n'est encore entré")
to(0.17)
check((sv(title) or 0) > 0 and near(sv(tabs) or -1, 0), `B4 t = 0,17 s : le titre entre (+130 ms), les onglets attendent ({fmt(sv(title))})`)
to(0.235)
check((sv(tabs) or 0) > 0 and near(sv(row1) or -1, 0), "B5 t = 0,235 s : les onglets entrent (+195 ms), la 1re ligne attend")
to(0.3)
check((sv(row1) or 0) > 0 and near(sv(row2) or -1, 0), "B6 t = 0,3 s : Row1 (à gauche) entre avant Row2 (même rangée, à droite)")
to(0.36)
check((sv(row2) or 0) > 0 and near(sv(buy) or -1, 0) and near(buy.Rotation, 2), "B7 t = 0,36 s : Row2 entre, le bouton attend")
to(0.42)
check((sv(buy) or 0) > 1 and not near(buy.Rotation, 2), `B8 t = 0,42 s : le bouton (Stamp) entre en tampon ({fmt(sv(buy))}, {fmt(buy.Rotation)}°)`)
to(0.56)
local allDone = true
for _, b in list do
	allDone = allDone and scaleOf(b) == nil
end
check(allDone and near(buy.Rotation, 2) and Appear.GetPhase(title) == nil, "B9 t = 0,56 s : tout est en place, UIScale retirés, Rotation de Clément")
-- Fermeture pendant l'attente des blocs, puis réouverture.
Motion.Close(blocksGui)
step(0.3)
Motion.Open(blocksGui)
step(0.05)
Motion.Close(blocksGui)
step(0.3)
local clean = true
for _, b in list do
	clean = clean and scaleOf(b) == nil
end
check(not blocksGui.Enabled and clean and near(buy.Rotation, 2), "B10 fermé pendant l'attente : éteint, blocs remis à l'état de Clément")
Motion.Open(blocksGui)
mark()
to(0.05)
check(near(sv(title) or -1, 0), "B11 rouvert : les blocs attendent de nouveau")
to(0.17)
check((sv(title) or 0) > 0, "B12 et repartent dans l'ordre")
to(0.7)
-- Réouverture pendant la fermeture : un bloc qui sort repart de là où il en est (jamais caché de nouveau).
Motion.Close(blocksGui)
step(0.06)
local swollen = sv(title)
Motion.Open(blocksGui)
step(1 / 30)
check(swollen ~= nil and swollen > 1 and (sv(title) or 0) > 0.5 and scales(title) <= 1, `B13 rouvert pendant la sortie : le titre repart de {fmt(swollen)}, pas de 0`)
step(0.6)
clean = true
for _, b in list do
	clean = clean and scaleOf(b) == nil
end
check(blocksGui.Enabled and clean and Motion.GetState(blocksGui) == "Open", "B14 ouvert, tout en place")
Motion.Close(blocksGui)
step(0.3)
-- Beaucoup de blocs : l'écart se resserre (tout part avant Start + Span).
local manyGui = screen("UI_T212Many")
frame = new("Frame", { Name = "Window", Size = UDim2.fromScale(0.6, 0.8) }, manyGui)
local many = {}
for i = 1, 8 do
	many[i] = block("Line" .. i, "Pop", 100, 40 * i)
end
step(0.05)
Motion.Open(manyGui)
mark()
to(0.42)
check((sv(many[7]) or 0) > 0 and near(sv(many[8]) or -1, 0), "B15 8 blocs : écart resserré (0,32 / 7 s), le 7e part vers 0,40 s, le 8e attend")
to(0.48)
check((sv(many[8]) or 0) > 0, "B16 le 8e part à 0,45 s (Start + Span)")
to(0.7)
check(scaleOf(many[8]) == nil and scaleOf(many[1]) == nil, "B17 tout en place")
Motion.Close(manyGui)
step(0.3)
-- Pas des blocs : Pop dans un cadre plein écran sans Appear (fond), Pop posé directement dans l'écran.
local fullGui = screen("UI_T212Full")
local back = new("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1) }, fullGui)
local inBack = new("Frame", { Name = "Panel", Size = UDim2.fromScale(0.5, 0.5) }, back)
inBack:SetAttribute("Appear", "Pop")
step(0.05)
Motion.Open(fullGui)
check(near(sv(inBack) or -1, 0.55), "B18 Pop dans un fond plein écran : pas un bloc, il s'ouvre tout de suite (0,55)")
step(0.5)
Motion.Close(fullGui)
step(0.3)

---------------------------------------------------------------- 5. Cartes (Cascade) et OpenStagger
print("-- Cartes")
local cardsGui = screen("UI_T212Cards")
local root = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, cardsGui)
local grid = new("Frame", { Name = "Cards", Size = UDim2.fromScale(1, 0.8) }, root)
grid:SetAttribute("Appear", "Cascade")
local cards = {}
for i = 5, 1, -1 do -- ordre de l'arbre à l'envers : de gauche à droite quand même
	cards[i] = new("Frame", { Name = "Card" .. i, AbsolutePosition = Vector2.new(100 * i, 200) }, grid)
end
step(0.05)
Motion.Open(cardsGui)
mark()
local waitAll = true
for _, c in cards do
	waitAll = waitAll and near(sv(c) or -1, 0.2)
end
check(waitAll, "K1 t = 0 : les 5 cartes attendent à 0,2")
to(0.22)
check(near(sv(cards[1]) or -1, 0.2), "K2 t = 0,22 s : encore rien")
to(0.25)
check((sv(cards[1]) or 0) > 0.2 and near(sv(cards[2]) or -1, 0.2), `K3 t = 0,25 s : la carte de gauche entre (+230 ms), la 2e attend ({fmt(sv(cards[1]))})`)
to(0.27)
check((sv(cards[2]) or 0) > 0.2 and near(sv(cards[3]) or -1, 0.2), "K4 t = 0,27 s : la 2e entre 22 ms après, la 3e attend")
to(0.5)
local cardsDone = true
for _, c in cards do
	cardsDone = cardsDone and scaleOf(c) == nil
end
check(cardsDone, "K5 t = 0,5 s : les 5 cartes en place (0,13 s chacune), UIScale retirés")
Motion.Close(cardsGui)
step(0.3)
-- Appear.SetCascade (a209) : rang et écart propres.
local rankGui = screen("UI_T212Rank")
local rroot = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, rankGui)
local slots = new("Frame", { Name = "Slots", Size = UDim2.fromScale(1, 1) }, rroot)
slots:SetAttribute("Appear", "Cascade")
local sa = new("Frame", { Name = "SlotA", AbsolutePosition = Vector2.new(500, 0) }, slots)
local sb = new("Frame", { Name = "SlotB", AbsolutePosition = Vector2.new(100, 0) }, slots)
sa:SetAttribute("Rank", 0)
sb:SetAttribute("Rank", 1)
Appear.SetCascade(slots, function(item)
	return item:GetAttribute("Rank") or 0
end, 0.1)
step(0.05)
Motion.Open(rankGui)
mark()
to(0.28)
check((sv(sa) or 0) > 0.2 and near(sv(sb) or -1, 0.2), "K6 SetCascade : rang 0 à +230 ms, rang 1 attend (écart propre de 0,1 s)")
to(0.36)
check((sv(sb) or 0) > 0.2, "K7 SetCascade : rang 1 à +330 ms")
to(0.6)
Motion.Close(rankGui)
step(0.3)
-- OpenStagger (Motion) : cartes à HoverOutline dans un cadre racine sans Appear.
local stagGui = screen("UI_T212Stagger")
local sroot = new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, stagGui)
local hov = {}
for i = 3, 1, -1 do
	hov[i] = new("Frame", { Name = "Item" .. i, AbsolutePosition = Vector2.new(100 * i, 200) }, sroot)
	new("Frame", { Name = "HoverOutline", Visible = false }, hov[i])
end
step(0.05)
Motion.Open(stagGui)
mark()
step(1 / 60)
clock = 1 / 60
check(near(sv(hov[1]) or -1, 0.2) and near(sv(hov[3]) or -1, 0.2), `K8 OpenStagger : les cartes attendent à 0,2 ({fmt(sv(hov[1]))})`)
to(0.25)
check((sv(hov[1]) or 0) > 0.2 and near(sv(hov[2]) or -1, 0.2), "K9 OpenStagger : la 1re à +230 ms, la 2e attend")
to(0.6)
check(scaleOf(hov[1]) == nil and scaleOf(hov[3]) == nil, "K10 OpenStagger : en place")
Motion.Close(stagGui)
step(0.3)

---------------------------------------------------------------- 6. Barre du bas qui s'écarte
print("-- HUD")
local function hotbar()
	local gui = new("ScreenGui", { Name = "UI_Hotbar", Enabled = true })
	local bar = new("Frame", { Name = "Bar", Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.new(0.5, 0, 0, 70), AbsolutePosition = Vector2.new(250, 520) }, gui)
	gui.Parent = playerGui
	return gui, bar
end
local hotGui, bar = hotbar()
local BASE = UDim2.new(0.5, 0, 1, -80)
local function atBase(b)
	local p = b.Position
	return p.X.Scale == 0.5 and p.X.Offset == 0 and p.Y.Scale == 1 and p.Y.Offset == -80
end
local function yOff(b)
	return b.Position.Y.Offset
end
local weapon = screen("UI_WeaponShop")
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, weapon)
step(0.1)
check(atBase(bar) and select(1, HudMask.GetAway()) == false, "H1 aucun écran : la barre à la Position de Clément")
Motion.Open(weapon)
mark()
to(0.075)
check(yOff(bar) > -64 and yOff(bar) < -56 and bar.Position.X.Scale == 0.5 and bar.Position.Y.Scale == 1, `H2 t = 0,075 s : elle descend (Quad In, -60 attendu : {yOff(bar)})`)
to(0.17)
check(near(yOff(bar), 0) and bar.Position.X.Offset == 0 and select(1, HudMask.GetAway()) == true, `H3 t = 0,15 s : sortie sous le bord du bas (+80 px ; {yOff(bar)})`)
to(0.6)
check(near(yOff(bar), 0), "H4 elle reste sortie tant que la boutique est ouverte")
Motion.Close(weapon)
mark()
to(0.15)
check(near(yOff(bar), 0) and weapon.Enabled, "H5 fermeture en cours : encore sortie")
local high = 0
while clock < 0.45 do
	to(clock + 0.01)
	high = math.min(high, yOff(bar))
end
check(high < -80.5 and high > -90, `H6 retour en Back Out : elle passe un peu au-dessus ({fmt(high)})`)
check(atBase(bar) and #select(2, HudMask.GetAway()) == 0, "H7 revenue en 0,17 s après l'extinction : Position de Clément exactement, rien de gardé")
-- Jamais en poursuite.
CHASED = true
Motion.Open(weapon)
step(0.4)
check(atBase(bar), "H8 en poursuite : la barre ne bouge pas")
CHASED = false
step(0.3)
check(near(yOff(bar), 0), "H9 poursuite finie, boutique ouverte : elle s'écarte")
CHASED = true
step(0.3)
check(atBase(bar), "H10 poursuite qui commence boutique ouverte : elle revient")
CHASED = false
step(0.3)
-- Copie neuve de la barre (ResetOnSpawn) pendant l'écart : elle s'écarte à son tour, l'ancienne est oubliée.
hotGui:Destroy()
local hotGui2, bar2 = hotbar()
step(0.8)
check(near(yOff(bar2), 0), "H11 copie neuve de UI_Hotbar : elle s'écarte aussi (revue toutes les 0,5 s)")
Motion.Close(weapon)
step(0.6)
check(atBase(bar2) and #select(2, HudMask.GetAway()) == 0, "H12 fermée : la copie revient, plus rien de gardé")
-- Attribut HudAway posé par Clément ; écran hors liste.
local marked = screen("UI_T212Marked", { HudAway = true })
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, marked)
local other = screen("UI_T212Other")
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.6, 0.6) }, other)
step(0.05)
Motion.Open(other)
step(0.4)
check(atBase(bar2), "H13 écran hors de HudAway.Screens : la barre reste")
Motion.Close(other)
step(0.3)
Motion.Open(marked)
step(0.4)
check(near(yOff(bar2), 0), "H14 ScreenGui avec l'attribut HudAway = true : elle s'écarte")
Motion.Close(marked)
step(0.6)
check(atBase(bar2), "H15 éteint : revenue")

---------------------------------------------------------------- 7. Animations réduites
print("-- Animations réduites")
P1:SetAttribute("VfxEnabled", false)
check(Appear.Reduced(), "R1 VISUAL EFFECTS sur OFF : Appear.Reduced()")
Motion.Open(blocksGui)
local still = scaleOf(blocksWindow) == nil
for _, b in list do
	still = still and scaleOf(b) == nil
end
check(blocksGui.Enabled and still and scaleOf(blocksWindow) == nil, "R2 ouverture : écran là d'un coup, aucun UIScale (ni cadre ni blocs)")
step(0.1)
still = true
for _, b in list do
	still = still and scaleOf(b) == nil
end
check(still and near(buy.Rotation, 2), "R3 rien ne bouge ensuite")
Motion.Close(blocksGui)
step(1 / 30)
check(not blocksGui.Enabled and scaleOf(blocksWindow) == nil, "R4 fermeture : éteint d'un coup")
Motion.Open(cardsGui)
step(1 / 30)
local noCard = true
for _, c in cards do
	noCard = noCard and scaleOf(c) == nil
end
check(noCard, "R5 cartes : là d'un coup")
Motion.Close(cardsGui)
step(1 / 30)
Motion.Open(stagGui)
step(1 / 30)
check(scaleOf(hov[1]) == nil and scaleOf(sroot) == nil, "R6 OpenStagger : là d'un coup")
Motion.Close(stagGui)
step(1 / 30)
Motion.Open(weapon)
step(1 / 30)
check(near(yOff(bar2), 0), "R7 barre du bas : partie d'un coup (pas de glissement)")
Motion.Close(weapon)
step(1 / 30)
step(1 / 30)
check(not weapon.Enabled and atBase(bar2), "R8 revenue d'un coup")
P1:SetAttribute("VfxEnabled", true)
step(0.1)

---------------------------------------------------------------- 8. Le reste ne change pas (Stamp, SlideRight, DropIn, Hover/Press)
print("-- Inchangé")
local stampGui = screen("UI_T212Stamp")
local stamp = new("TextLabel", { Name = "Title", Rotation = 2, Size = UDim2.fromScale(0.4, 0.1) }, stampGui)
stamp:SetAttribute("Appear", "Stamp")
step(0.05)
Motion.Open(stampGui)
check(near(sv(stamp) or -1, 1.6) and near(stamp.Rotation, -3), "U1 Stamp posé dans l'écran : 1,6 et −5°, tout de suite (pas un bloc)")
step(0.2)
check(scaleOf(stamp) == nil and near(stamp.Rotation, 2), "U2 Stamp : au bout de 0,13 s, état de Clément")
Motion.Close(stampGui)
step(0.3)
check(not stampGui.Enabled and scaleOf(stamp) == nil and near(stamp.Rotation, 2), "U3 Stamp fermé : remis")
local slideGui = screen("UI_T212Slide")
local panel = new("Frame", { Name = "Panel", Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromScale(0.3, 0.8), AbsolutePosition = Vector2.new(700, 60) }, slideGui)
panel:SetAttribute("Appear", "SlideRight")
step(0.05)
Motion.Open(slideGui)
check(near(panel.Position.X.Offset, 280), "U4 SlideRight : part de derrière le bord droit")
step(0.2)
check(near(panel.Position.X.Offset, -20) and panel:FindFirstChild("AppearSlide") == nil, "U5 SlideRight : Position de Clément en 0,17 s")
Motion.Close(slideGui)
step(0.3)
check(not slideGui.Enabled and near(panel.Position.X.Offset, -20), "U6 SlideRight fermé : remis")
local dropGui = screen("UI_T212Drop")
local decor = new("Frame", { Name = "Decor", Size = UDim2.fromScale(1, 1) }, dropGui)
local hang = new("ImageLabel", { Name = "Hang1", Rotation = 1, Position = UDim2.new(0.2, 0, 0, 10), Size = UDim2.fromScale(0.1, 0.2), AbsoluteSize = Vector2.new(100, 120) }, decor)
hang:SetAttribute("Appear", "DropIn")
step(0.05)
Motion.Open(dropGui)
check(near(hang.Position.Y.Offset, 10 - 120), "U7 DropIn : attend une hauteur au-dessus")
step(0.4)
check(near(hang.Position.Y.Offset, 10) and Appear.GetPhase(hang) == "In", "U8 DropIn : à sa place, il se balance")
Motion.Close(dropGui)
step(0.4)
check(not dropGui.Enabled and near(hang.Rotation, 1) and near(hang.Position.Y.Offset, 10), "U9 DropIn fermé : remis")
local btnGui = screen("UI_T212Buttons")
btnGui.Enabled = true
local holder = new("Frame", { Name = "Holder", Size = UDim2.fromScale(0.5, 0.5) }, btnGui)
local play = new("TextButton", { Name = "PlayButton", Size = UDim2.fromScale(0.2, 0.1) }, holder)
play:SetAttribute("Hover", "Pop")
play:SetAttribute("Press", "Squash")
Motion.Button(play)
play.MouseEnter:Fire()
step(0.1)
check(near(sv(play) or -1, 1.1), "U10 Hover = Pop : × 1,10")
play.MouseButton1Down:Fire()
step(0.05)
check(near(sv(play) or -1, 0.75), "U11 Press = Squash : 0,75")
play.MouseButton1Up:Fire()
play.MouseLeave:Fire()
step(0.4)
check(scaleOf(play) == nil, "U12 relâché, souris sortie : taille d'origine")
step(1)
summary()
