---------------------------------------------------------------- scénarios a290 (L-270 : clic sur la taille réelle du bouton)
-- Après setup.luau du banc a50. Tweens simulés dans le temps (ext-a189). Le faux Roblox ne fait ni le rendu ni le
-- choix du bouton sous la souris : render290 recalcule les tailles absolues d'après le UIScale, et le banc joue
-- Roblox (MouseLeave quand le pointeur n'est plus sur le bouton dessiné, MouseButton1Up et Activated seulement sur
-- le bouton dessiné, InputEnded de UserInputService toujours).
USE_UIS290 = true
ROBLOX_STRICT = false
local playerGui = P1.PlayerGui
local client = StarterPlayerScripts.Client
local ctrl = folder(client, "Controllers290")
local ui = folder(ctrl, "UI")
local motionModule = moduleScript(ui, "Motion", "client/Controllers/UI/Motion.luau")
moduleScript(ui, "Appear", "client/Controllers/UI/Appear.luau")
local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local Motion = requireModule(motionModule, "client")
local sounds = {}
Motion.SetSoundPlayer(function(name)
	sounds[name] = (sounds[name] or 0) + 1
	return true
end)

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
	return if s then s.Scale else 1
end
local function fmt(v)
	return if v == nil then "nil" else string.format("%.3f", v)
end

local gui = new("ScreenGui", { Name = "UI_T290", Enabled = true })
gui.Parent = playerGui
local holder = new("Frame", { Name = "Holder", BackgroundTransparency = 1 }, gui)
-- Bouton de 200 × 80 px en (100, 100), ancré au centre (200, 140), Hover = Pop (× 1,10), Press = Squash (0,75).
local function makeButton(name, parent)
	local b = new("TextButton", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5) }, parent or holder)
	b:SetAttribute("Hover", "Pop")
	b:SetAttribute("Press", "Squash")
	base290(b, 100, 100, 200, 80)
	return b
end
local function inside(b, x, y)
	local p, s = b.AbsolutePosition, b.AbsoluteSize
	return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
end
local function run(b, seconds, samples)
	local n = math.max(1, math.ceil(seconds / 0.01))
	for _ = 1, n do
		step(0.01)
		render290(b)
		if samples then
			table.insert(samples, sv(b))
		end
	end
end

-- Un clic à la souris joué comme Roblox : survol, appui en (x, y), relâché en (rx, ry) après `moves` (points), et
-- Activated de Roblox seulement si le relâché tombe sur le bouton dessiné. Rend le nombre de clics reçus et la
-- suite des échelles après le relâché.
local function mouseClick(b, count, x, y, rx, ry, opts)
	opts = opts or {}
	local samples = {}
	-- La souris arrive sur le bouton (InputChanged de UserInputService), puis MouseEnter.
	UIS290.InputChanged:Fire(input290("MouseMovement", x + (opts.shift or 0), y + (opts.shiftY or 0)), false)
	b.MouseEnter:Fire()
	run(b, 0.12)
	local input = input290("MouseButton1", x + (opts.shift or 0), y + (opts.shiftY or 0))
	b.InputBegan:Fire(input)
	UIS290.InputBegan:Fire(input, false)
	b.MouseButton1Down:Fire()
	run(b, 0.06)
	local mouseIn = true
	local left = false
	if not inside(b, x, y) then
		b.MouseLeave:Fire() -- le bouton a rétréci sous la souris
		mouseIn = false
		left = true
	end
	run(b, 0.05)
	local squashed = sv(b)
	for _, m in opts.moves or {} do
		local move = input290("MouseMovement", m[1] + (opts.shift or 0), m[2] + (opts.shiftY or 0))
		UIS290.InputChanged:Fire(move, false)
		local now = inside(b, m[1], m[2])
		if mouseIn and not now then
			b.MouseLeave:Fire()
			left = true
		elseif not mouseIn and now then
			b.MouseEnter:Fire()
		end
		mouseIn = now
		run(b, 0.05)
	end
	local zx, zy, zw, zh = Motion.GetClickZone(b)
	input.Position = { X = rx + (opts.shift or 0), Y = ry + (opts.shiftY or 0), Z = 0 }
	input.UserInputState = if opts.cancel then Enum.UserInputState.Cancel else Enum.UserInputState.End
	-- Roblox strict (ROBLOX_STRICT) : pas de clic de Roblox si la souris a quitté le bouton pendant l'appui.
	local onButton = inside(b, rx, ry)
	local robloxClick = onButton and not (ROBLOX_STRICT and left)
	if opts.activatedFirst and onButton then
		b.MouseButton1Up:Fire()
		if robloxClick then
			b.Activated:Fire(input, 1)
		end
	end
	UIS290.InputEnded:Fire(input, false)
	if not opts.activatedFirst and onButton then
		b.MouseButton1Up:Fire()
		if robloxClick then
			b.Activated:Fire(input, 1)
		end
	end
	if opts.lateActivated then
		run(b, 0.1)
		b.Activated:Fire(input, 1)
	end
	for _ = 1, 40 do
		step(0.01)
		render290(b)
		table.insert(samples, sv(b))
		if not mouseIn and inside(b, rx, ry) then
			b.MouseEnter:Fire() -- le bouton regrossit sous la souris
			mouseIn = true
		end
	end
	return count(), samples, squashed, zx, zy, zw, zh
end

local function counter(b)
	local n = 0
	local connection = Motion.Activated(b):Connect(function()
		n += 1
	end)
	return function()
		return n
	end, connection
end
local function leaveAll(b)
	b.MouseLeave:Fire()
	run(b, 0.4)
end

---------------------------------------------------------------- 0. Valeurs
print("-- Valeurs")
local Z = UiMotion.ClickZone
check(Z.Enabled == true and Z.SettleTime > 0 and Z.SettleTime <= 0.1 and Z.Guard >= Z.SettleTime and Z.StillPixels >= 1 and Z.TouchSlop > 0,
	"V1 ClickZone allumé, rattrapage en 0,05 s au plus tard après 0,1 s")
check(UiMotion.PressSquash.To == 0.75 and UiMotion.HoverPop.To == 1.1 and UiMotion.PressSquash.Bounce == 1.1,
	"V2 l'écrasement et le survol de Clément sont inchangés (0,75 ; × 1,10 ; rebond 1,1)")
check(Motion.Activated(makeButton("Same")) == Motion.Activated(Motion and holder:FindFirstChild("Same")), "V3 un seul signal par bouton")

---------------------------------------------------------------- 1. Clic au centre : comme avant
print("-- Centre")
local center = makeButton("CenterButton")
Motion.Button(center)
local countC = counter(center)
local hovers0 = sounds.UI_Hover or 0
local nC, samplesC, squashC, zx, zy, zw, zh = mouseClick(center, countC, 200, 140, 200, 140)
check(nC == 1, `C1 appui et relâché au centre : un clic ({nC})`)
check(near(squashC, 0.75), `C2 écrasé à 0,75 pendant l'appui ({fmt(squashC)})`)
-- Zone de l'appui : survolé (× 1,10) au moment de l'appui : 220 × 88 autour de (200, 140), elle contient la taille réelle.
check(zx ~= nil and near(zx, 90, 0.5) and near(zy, 96, 0.5) and near(zw, 220, 0.5) and near(zh, 88, 0.5),
	`C3 zone de clic pendant l'écrasement : la taille survolée de l'appui (x {fmt(zx)}, y {fmt(zy)}, {fmt(zw)} × {fmt(zh)})`)
check(zx ~= nil and zx <= 100 and zy <= 100 and zx + zw >= 300 and zy + zh >= 180, "C4 la zone contient la taille réelle (200 × 80)")
check(center.AbsoluteSize.X > 200 and near(sv(center), 1.1), `C5 après le rebond : survol × 1,10 ({fmt(sv(center))})`)
check((sounds.UI_Hover or 0) - hovers0 == 1, "C6 un seul son de survol")
leaveAll(center)
local nC2 = mouseClick(center, countC, 200, 140, 200, 140, { activatedFirst = true })
check(nC2 == 2, `C7 Activated de Roblox avant InputEnded : un clic de plus, pas deux ({nC2 - 1})`)
leaveAll(center)
check(scaleOf(center) == nil, "C8 souris sortie : plus aucun UIScale (taille de Studio)")

---------------------------------------------------------------- 2. Relâché dans le quart extérieur
print("-- Bord")
local ring = makeButton("RingButton")
Motion.Button(ring)
local countR = counter(ring)
local hovers1 = sounds.UI_Hover or 0
-- (110, 140) : sur la taille réelle (100…300), hors du bouton écrasé (125…275).
local nR, samplesR, squashR = mouseClick(ring, countR, 110, 140, 110, 140)
check(nR == 1, `R1 appui et relâché dans le quart extérieur : un clic ({nR})`)
check(near(squashR, 0.75), `R2 sorti du bouton écrasé sans sortir de la zone : il reste écrasé, comme au centre ({fmt(squashR)})`)
local same = #samplesR == #samplesC
for i, v in samplesC do
	if not near(samplesR[i] or -1, v, 0.0005) then
		same = false
	end
end
check(same, "R3 même rebond et même retour au survol qu'au centre, image par image")
check((sounds.UI_Hover or 0) - hovers1 == 1, `R4 le bouton qui regrossit sous la souris ne rejoue pas le son de survol ({(sounds.UI_Hover or 0) - hovers1})`)
check(near(sv(ring), 1.1), `R5 survol gardé après le relâché ({fmt(sv(ring))})`)
leaveAll(ring)
check(scaleOf(ring) == nil, "R6 souris sortie : taille de Studio")
-- Les quatre bords et un coin, à 5 px de la taille réelle.
local edges = 0
for _, p in { { 105, 140 }, { 295, 140 }, { 200, 104 }, { 200, 176 }, { 104, 104 } } do
	local before = countR()
	local after = mouseClick(ring, countR, p[1], p[2], p[1], p[2])
	if after - before == 1 then
		edges += 1
	end
	leaveAll(ring)
end
check(edges == 5, `R7 quart extérieur : gauche, droite, haut, bas et coin donnent chacun un clic ({edges}/5)`)
-- Bande entre la taille réelle et la taille survolée (× 1,10 : 90…310) : le bouton était sous la souris à l'appui.
local nBand = mouseClick(ring, countR, 95, 140, 95, 140)
check(nBand - countR() == 0 and nBand == 7, `R8 appui sur le bord du bouton survolé, relâché au même endroit : un clic ({nBand - 6})`)
leaveAll(ring)
-- Relâché au centre après un appui dans le bord : Roblox le donne, une fois.
local nBack = mouseClick(ring, countR, 110, 140, 200, 140)
check(nBack == 8, `R9 appui dans le bord, relâché au centre : un clic ({nBack - 7})`)
leaveAll(ring)
-- Glissé dans la zone puis relâché dans le bord.
local nSlide = mouseClick(ring, countR, 200, 140, 112, 150, { moves = { { 150, 140 }, { 112, 150 } } })
check(nSlide == 9, `R10 glissé du centre vers le bord, relâché : un clic ({nSlide - 8})`)
leaveAll(ring)

---------------------------------------------------------------- 3. Pas de double clic
print("-- Un seul clic")
local nLate = mouseClick(ring, countR, 110, 140, 110, 140, { lateActivated = true })
check(nLate == 10, `D1 Activated de Roblox reçu juste après le clic rattrapé : ignoré ({nLate - 9})`)
leaveAll(ring)
-- Roblox donne lui-même le clic dans le bord (s'il le faisait) : pas de rattrapage en plus.
do
	local before = countR()
	ring.MouseEnter:Fire()
	run(ring, 0.12)
	local input = input290("MouseButton1", 110, 140)
	ring.InputBegan:Fire(input)
	ring.MouseButton1Down:Fire()
	run(ring, 0.1)
	ring.MouseLeave:Fire()
	input.UserInputState = Enum.UserInputState.End
	ring.Activated:Fire(input, 1)
	UIS290.InputEnded:Fire(input, false)
	run(ring, 0.3)
	check(countR() - before == 1, `D2 Activated de Roblox dans le bord : un clic, pas de rattrapage en plus ({countR() - before})`)
	leaveAll(ring)
end
-- Clavier ou manette (Activated sans appui suivi), juste après un clic rattrapé et bien après.
do
	local before = countR()
	mouseClick(ring, countR, 110, 140, 110, 140)
	leaveAll(ring)
	ring.Activated:Fire(nil, 1)
	run(ring, 0.05)
	check(countR() - before == 2, `D3 Activated sans appui (manette) après le garde : donné ({countR() - before - 1})`)
end

---------------------------------------------------------------- 4. Glissé loin : pas de clic
print("-- Glissé hors")
do
	local before = countR()
	local hovers = sounds.UI_Hover or 0
	local n, samples = mouseClick(ring, countR, 200, 140, 400, 140, { moves = { { 260, 140 }, { 400, 140 } } })
	check(n - before == 0, `G1 tenu puis glissé loin du bouton, relâché : aucun clic ({n - before})`)
	check(near(samples[#samples], 1), `G2 il revient à 1 dès que la souris sort de la zone ({fmt(samples[#samples])})`)
	check((sounds.UI_Hover or 0) - hovers == 1, "G3 un seul son de survol")
	run(ring, 0.3)
	check(scaleOf(ring) == nil, "G4 taille de Studio ensuite")
	-- Juste hors de la zone (au-dessus du bouton survolé : 90…310 × 96…184).
	local n2 = mouseClick(ring, countR, 200, 140, 200, 190, { moves = { { 200, 190 } } })
	check(n2 - before == 0, `G5 relâché à 6 px sous la zone : aucun clic ({n2 - before})`)
	leaveAll(ring)
	-- Annulé (Cancel) dans le bord : rien.
	local n3 = mouseClick(ring, countR, 110, 140, 110, 140, { cancel = true })
	check(n3 - before == 0, `G6 appui annulé (Cancel) : aucun clic ({n3 - before})`)
	leaveAll(ring)
end

---------------------------------------------------------------- 5. Bouton caché ou écran fermé pendant l'appui
print("-- Bouton parti")
do
	local before = countR()
	ring.MouseEnter:Fire()
	run(ring, 0.12)
	local input = input290("MouseButton1", 110, 140)
	ring.InputBegan:Fire(input)
	ring.MouseButton1Down:Fire()
	run(ring, 0.1)
	ring.MouseLeave:Fire()
	input.UserInputState = Enum.UserInputState.End
	UIS290.InputEnded:Fire(input, false)
	gui.Enabled = false -- l'écran se ferme avant la fin du rattrapage
	run(ring, 0.3)
	check(countR() - before == 0, `B1 écran fermé avant le rattrapage : aucun clic ({countR() - before})`)
	gui.Enabled = true
	leaveAll(ring)
end

---------------------------------------------------------------- 6. Toucher (téléphone)
print("-- Toucher")
local function touchTap(b, count, x, y, rx, ry, moves)
	local before = count()
	local input = input290("Touch", x, y)
	b.InputBegan:Fire(input)
	b.MouseButton1Down:Fire()
	run(b, 0.06)
	local squashed = sv(b)
	for _, m in moves or {} do
		input.Position = { X = m[1], Y = m[2], Z = 0 }
		UIS290.InputChanged:Fire(input, false)
		run(b, 0.03)
	end
	input.Position = { X = rx, Y = ry, Z = 0 }
	local onButton = inside(b, rx, ry)
	input:set290("UserInputState", Enum.UserInputState.End)
	UIS290.InputEnded:Fire(input, false)
	if onButton then
		b.InputEnded:Fire(input)
		b.Activated:Fire(input, 1)
	end
	local peak = 0
	for _ = 1, 30 do
		step(0.01)
		render290(b)
		peak = math.max(peak, sv(b))
	end
	return count() - before, squashed, peak
end
local tap = makeButton("TapButton")
Motion.Button(tap)
local countT = counter(tap)
local n1, sq1, peak1 = touchTap(tap, countT, 200, 140, 200, 140)
check(n1 == 1 and near(sq1, 0.75), `T1 doigt au centre : un clic, écrasé à 0,75 ({n1}, {fmt(sq1)})`)
local n2, sq2, peak2 = touchTap(tap, countT, 106, 140, 106, 140)
check(n2 == 1, `T2 doigt levé dans le quart extérieur : un clic ({n2})`)
check(near(sq2, sq1) and near(peak2, peak1, 0.002) and near(sv(tap), 1), `T3 même écrasement et même rebond qu'au centre ({fmt(sq2)}, pic {fmt(peak2)} / {fmt(peak1)})`)
local n3 = touchTap(tap, countT, 200, 140, 420, 140, { { 300, 140 }, { 420, 140 } })
check(n3 == 0, `T4 doigt glissé loin du bouton : aucun clic ({n3})`)
-- Dans une liste : un doigt qui glisse fait défiler, pas de clic ; liste qui a défilé : pas de clic.
local list = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1 }, holder)
local card = makeButton("ListBuyButton", list)
Motion.Button(card)
local countL = counter(card)
local l1 = touchTap(card, countL, 110, 140, 110, 140)
check(l1 == 1, `T5 dans une liste, doigt levé dans le bord sans glisser : un clic ({l1})`)
local l2 = touchTap(card, countL, 140, 140, 110, 140, { { 125, 140 }, { 110, 140 } })
check(l2 == 0, `T6 dans une liste, doigt glissé de 30 px : un défilement, aucun clic ({l2})`)
do
	local before = countL()
	local input = input290("Touch", 110, 140)
	card.InputBegan:Fire(input)
	card.MouseButton1Down:Fire()
	run(card, 0.06)
	base290(card, 100, 60, 200, 80) -- la liste a défilé de 40 px sous le doigt
	render290(card)
	input:set290("UserInputState", Enum.UserInputState.End)
	UIS290.InputEnded:Fire(input, false)
	run(card, 0.3)
	check(countL() - before == 0, `T7 liste défilée pendant l'appui : aucun clic ({countL() - before})`)
	base290(card, 100, 100, 200, 80)
end

---------------------------------------------------------------- 7. Repère de l'écran (GetGuiInset)
print("-- Repère")
do
	local shifted = makeButton("InsetButton")
	Motion.Button(shifted)
	local countI = counter(shifted)
	-- Pointeur rapporté 36 px plus bas que le repère des tailles absolues (écran sous la barre du haut).
	local n = mouseClick(shifted, countI, 110, 110, 110, 110, { shiftY = 36 })
	check(n == 1, `I1 décalage du haut de l'écran repéré à l'appui : un clic dans le bord ({n})`)
	leaveAll(shifted)
	local n2 = mouseClick(shifted, countI, 200, 140, 200, 200, { shiftY = 36, moves = { { 200, 200 } } })
	check(n2 == 1, `I2 même décalage, relâché sous le bouton : aucun clic ({n2 - 1})`)
	leaveAll(shifted)
end

---------------------------------------------------------------- 8. Connexions
print("-- Connexions")
do
	local b = makeButton("ConnButton")
	Motion.Button(b)
	local n, once = 0, 0
	local connection = Motion.Activated(b):Connect(function()
		n += 1
	end)
	Motion.Activated(b):Once(function()
		once += 1
	end)
	b.Activated:Fire(nil, 1)
	b.Activated:Fire(nil, 1)
	run(b, 0.05)
	check(n == 2 and once == 1 and connection.Connected == true, `K1 Connect reçoit chaque clic, Once un seul ({n}, {once})`)
	connection:Disconnect()
	b.Activated:Fire(nil, 1)
	run(b, 0.05)
	check(n == 2 and connection.Connected == false, "K2 Disconnect : plus rien")
	local ok = 0
	Motion.Activated(b):Connect(function()
		error("faute dans un contrôleur (attendue par le banc)")
	end)
	Motion.Activated(b):Connect(function()
		ok += 1
	end)
	local fails = FAILS
	b.Activated:Fire(nil, 1)
	run(b, 0.05)
	FAILS = fails -- l'erreur attendue n'est pas un échec du banc
	check(ok == 1, "K3 une erreur dans une fonction branchée n'empêche pas les autres")
end
-- Bouton sans Motion.Button (pas d'écrasement) : Activated de Roblox seulement, rien de rattrapé.
do
	local plain = new("TextButton", { Name = "PlainButton", AnchorPoint = Vector2.new(0.5, 0.5) }, holder)
	base290(plain, 100, 100, 200, 80)
	local countP = counter(plain)
	local input = input290("MouseButton1", 150, 140)
	plain.InputBegan:Fire(input)
	input.UserInputState = Enum.UserInputState.End
	UIS290.InputEnded:Fire(input, false)
	plain.Activated:Fire(input, 1)
	run(plain, 0.3)
	check(countP() == 1, `K4 bouton sans écrasement : le clic de Roblox, une fois ({countP()})`)
end

---------------------------------------------------------------- 8 bis. Roblox strict
-- Si Roblox ne donne plus son clic dès que la souris a quitté le bouton pendant l'appui (comportement non vérifié
-- hors Studio), le rattrapage le donne, une seule fois.
print("-- Roblox strict")
ROBLOX_STRICT = true
do
	local strict = makeButton("StrictButton")
	Motion.Button(strict)
	local countS = counter(strict)
	local n1 = mouseClick(strict, countS, 110, 140, 110, 140)
	check(n1 == 1, `S1 relâché dans le quart extérieur : un clic ({n1})`)
	leaveAll(strict)
	local n2 = mouseClick(strict, countS, 110, 140, 200, 140)
	check(n2 == 2, `S2 appui dans le bord, relâché au centre : un clic ({n2 - 1})`)
	leaveAll(strict)
	local n3 = mouseClick(strict, countS, 200, 140, 112, 150, { moves = { { 150, 140 }, { 112, 150 } } })
	check(n3 == 3, `S3 glissé du centre vers le bord : un clic ({n3 - 2})`)
	leaveAll(strict)
	local n4 = mouseClick(strict, countS, 200, 140, 400, 140, { moves = { { 260, 140 }, { 400, 140 } } })
	check(n4 == 3, `S4 glissé loin : aucun clic ({n4 - 3})`)
	leaveAll(strict)
	local n5 = mouseClick(strict, countS, 200, 140, 200, 140)
	check(n5 == 4, `S5 au centre sans sortir : le clic de Roblox, une fois ({n5 - 3})`)
	leaveAll(strict)
end
ROBLOX_STRICT = false

---------------------------------------------------------------- 8 ter. L-275 : fin du survol sans MouseLeave
print("-- Survol sans MouseLeave (L-275)")
do
	local Hw = UiMotion.HoverWatch
	check(Hw.Enabled == true and Hw.Slack >= 0 and Hw.Slack <= 2, "H0 HoverWatch allumé, marge de 2 px au plus")
	local b = makeButton("DisplaysButton")
	Motion.Button(b)
	local function moveTo(x, y)
		UIS290.InputChanged:Fire(input290("MouseMovement", x, y), false)
		run(b, 0.03)
	end
	local hovers = sounds.UI_Hover or 0
	moveTo(200, 140)
	b.MouseEnter:Fire()
	run(b, 0.2)
	check(near(sv(b), 1.1), `H1 survolé : × 1,10 ({fmt(sv(b))})`)
	moveTo(306, 140) -- dans le bouton grossi (90…310), hors de la taille réelle
	moveTo(250, 170)
	run(b, 0.2)
	check(near(sv(b), 1.1), `H2 la souris bouge sur le bouton grossi, même hors de sa taille réelle : survol gardé ({fmt(sv(b))})`)
	moveTo(520, 140) -- sortie rapide, Roblox n'envoie pas MouseLeave
	run(b, 0.4)
	check(scaleOf(b) == nil, `H3 souris sortie sans MouseLeave : le bouton revient au repos ({fmt(sv(b))})`)
	b.MouseLeave:Fire() -- MouseLeave en retard : sans effet
	run(b, 0.4)
	check(scaleOf(b) == nil, "H4 MouseLeave en retard ensuite : rien de plus")
	moveTo(200, 140)
	b.MouseEnter:Fire()
	run(b, 0.2)
	check(near(sv(b), 1.1) and (sounds.UI_Hover or 0) - hovers == 2, `H5 la souris revient : survolé de nouveau, son de survol rejoué une fois ({(sounds.UI_Hover or 0) - hovers})`)
	-- Écran fermé pendant le survol, souris immobile.
	gui.Enabled = false
	run(b, 0.4)
	check(scaleOf(b) == nil, `H6 écran fermé pendant le survol : le bouton revient au repos ({fmt(sv(b))})`)
	gui.Enabled = true
	b.MouseLeave:Fire()
	run(b, 0.2)
	moveTo(200, 140)
	b.MouseEnter:Fire()
	run(b, 0.2)
	b.Visible = false
	run(b, 0.4)
	check(scaleOf(b) == nil, "H7 bouton caché pendant le survol : au repos")
	b.Visible = true
	b.MouseLeave:Fire()
	run(b, 0.2)
	moveTo(200, 140)
	b.MouseEnter:Fire()
	run(b, 0.2)
	UIS290.WindowFocusReleased:Fire()
	run(b, 0.4)
	check(scaleOf(b) == nil, "H8 fenêtre qui perd le focus : au repos")
	b.MouseLeave:Fire()
	run(b, 0.2)
	-- Liste qui défile sous la souris immobile (le bouton s'en va).
	moveTo(200, 140)
	b.MouseEnter:Fire()
	run(b, 0.2)
	base290(b, 100, 300, 200, 80)
	run(b, 0.4)
	check(scaleOf(b) == nil, "H9 le bouton part de sous la souris immobile : au repos")
	base290(b, 100, 100, 200, 80)
	b.MouseLeave:Fire()
	run(b, 0.2)
	-- Pendant l'appui, la zone appuyée décide (pas de fin du survol au bord du bouton écrasé).
	moveTo(110, 140)
	b.MouseEnter:Fire()
	run(b, 0.15)
	local input = input290("MouseButton1", 110, 140)
	b.InputBegan:Fire(input)
	b.MouseButton1Down:Fire()
	run(b, 0.1)
	b.MouseLeave:Fire()
	moveTo(108, 142)
	check(near(sv(b), 0.75), `H10 appui tenu dans le bord du bouton écrasé : il reste écrasé ({fmt(sv(b))})`)
	input.UserInputState = Enum.UserInputState.End
	UIS290.InputEnded:Fire(input, false)
	for _ = 1, 40 do
		step(0.01)
		render290(b)
	end
	check(near(sv(b), 1.1), `H11 relâché dans le bord, souris immobile : survol gardé ({fmt(sv(b))})`)
	moveTo(520, 140)
	run(b, 0.4)
	check(scaleOf(b) == nil, "H12 puis sortie sans MouseLeave : au repos")
	b.MouseLeave:Fire()
	run(b, 0.2)
end
-- Carte de liste (Motion.HoverCard) : même fin du survol sans MouseLeave.
do
	local card = new("ImageButton", { Name = "ItemCard", AnchorPoint = Vector2.new(0.5, 0.5) }, holder)
	base290(card, 400, 100, 120, 160)
	Motion.HoverCard(card)
	UIS290.InputChanged:Fire(input290("MouseMovement", 460, 180), false)
	card.MouseEnter:Fire()
	run(card, 0.3)
	local grown = sv(card)
	UIS290.InputChanged:Fire(input290("MouseMovement", 700, 180), false)
	run(card, 0.5)
	check(grown > 1 and scaleOf(card) == nil, `H13 carte : survolée ({fmt(grown)}), puis souris sortie sans MouseLeave : au repos ({fmt(sv(card))})`)
end

---------------------------------------------------------------- 9. Contrôleurs branchés sur Motion.Activated
print("-- Contrôleurs")
check(LEFT_ACTIVATED == "" or LEFT_ACTIVATED == " ", `M1 plus aucun contrôleur d'écran UI_* sur button.Activated (reste : « {LEFT_ACTIVATED} »)`)
summary()
