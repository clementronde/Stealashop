-- Scénarios du banc a310 (Cantin, 2026-11-22 : « il suffit d'arriver contre un grand côté du tapis »).
-- Tapis d'Alice à l'origine : bande X ±1,5, Z ±3,25 (dessus à 1,2), UsePoint tourné vers −Z : l'axe du tapis
-- est Z, les grands côtés sont en ±X, l'avant (console) en −Z. UseZone comme celles de Clément (machine + 3 studs,
-- L-207) : X ±5, Z −7 à 6, pour voir la marge à l'intérieur de la zone. Marge en travers lue dans Config :
-- emprise d'entrée X ±(1,5 + marge), Z ±3,25 (bouts stricts). Le HumanoidRootPart est à y = 3.
-- Chaque montée regarde le serveur (TrainingMachine) ET le client (place, TreadmillRun). Bob (tapis à z = 100,
-- sans UseZone : boîte du modèle + 1, X ±3) : serveur seul.

local FRAME = 1 / 60
local Training = requireModule(ReplicatedStorage.Shared.Config.Training)
local TZ = requireModule(ReplicatedStorage.Shared.TrainingZone)
local MARGIN = Training.Treadmill.SideEntryMargin
check("Config : SideEntryMargin = 1,5 (V0)", MARGIN == 1.5, MARGIN)
local EDGE = 1.5 -- demi-largeur de la bande
local END = 3.25 -- demi-longueur de la bande

local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
local plotA = newInst("Model", "PLOT_Shop_01", nil)
plotA._tags.PlayerPlot = true
plotA:SetAttribute("OwnerUserId", alice.UserId)
plotA.Parent = workspace
table.insert(PLOTS, plotA)
OWNER[plotA] = alice
local treadA = buildTreadmill(plotA, vec(0, 0, 0), { useZone = { size = vec(10, 6, 13), offset = vec(0, 3, -0.5) } })
local benchA = buildBench(plotA, vec(20, 0, 0))
newPlot("PLOT_Shop_02", bob, vec(0, 0, 100))
TrainingService.Init()
startClient(alice)

local STAND_T = vec(0, 4.2, 0)
local function away(p)
	setMove(p, 0, 0)
	moveTo(p, vec(p.UserId * 10, 3, -400))
	step(0.6, FRAME)
end
-- Marche image par image de `from` à `to` (16 studs/s), sans toucher la position une fois monté.
local function walk(p, from, to)
	local d = to - from
	local length = math.sqrt(d.X * d.X + d.Y * d.Y + d.Z * d.Z)
	local n = math.max(1, math.ceil(length / (16 * FRAME)))
	for i = 0, n do
		if machineOf(p) ~= nil or (p == alice and ANIM.playing.TreadmillRun) then
			break
		end
		moveTo(p, from + d * (i / n))
		step(FRAME, FRAME)
	end
end
-- Deux contrôles : un hors de l'emprise (dans la zone), puis `at` (arrêté contre le côté, par exemple).
local function hop(p, from, at)
	moveTo(p, from)
	step(FRAME, FRAME)
	moveTo(p, at)
	step(FRAME, FRAME)
end
local function onBoth()
	return machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true and rootPos(alice) == STAND_T
end
local function offBoth()
	return machineOf(alice) == nil and ANIM.playing.TreadmillRun == nil
end
local function descend()
	setMove(alice, 0, 1)
	step(FRAME, FRAME)
end

-- S1 : arrêté contre un grand côté, 0,5, 1 et 1,4 stud hors de la bande, de chaque côté : monte, placé sur la bande.
for _, d in { 0.5, 1, 1.4 } do
	for _, sx in { 1, -1 } do
		away(alice)
		hop(alice, vec(sx * 4.5, 3, 0.5), vec(sx * (EDGE + d), 3, 0.5))
		check(`S1 contre le côté {if sx > 0 then "+X" else "−X"} à {d} stud : monte et placé sur la bande (serveur et client)`, onBoth(), `{machineOf(alice)} {rootPos(alice)}`)
	end
end
-- … en marchant vers le côté et en s'arrêtant à 1 stud (perso R15 collé) : monte.
away(alice)
walk(alice, vec(4.8, 3, -1), vec(EDGE + 1, 3, -1))
check("S1 marche jusqu'au côté (1 stud) : monte", onBoth())
-- S1b : au-delà de la marge (1,6 et 2 studs hors de la bande, encore dans la zone) : rien, même en y restant 1 s.
for _, d in { MARGIN + 0.1, 2 } do
	away(alice)
	walk(alice, vec(4.8, 3, 0), vec(EDGE + d, 3, 0))
	step(1, FRAME)
	check(`S1b arrêté à {d} stud du côté (au-delà de la marge) : ne monte pas`, offBoth())
	check(`S1b le client ne déplace pas le joueur ({d})`, rootPos(alice) == vec(EDGE + d, 3, 0), tostring(rootPos(alice)))
end

-- S2 : bouts stricts : traverser devant et derrière, même tout près (0,15 stud du bout), à travers toute la zone.
away(alice)
walk(alice, vec(-4.8, 3, -(END + 0.15)), vec(4.8, 3, -(END + 0.15)))
check("S2 traverser devant, à 0,15 stud du bout : ne monte pas", offBoth())
away(alice)
walk(alice, vec(-4.8, 3, END + 0.15), vec(4.8, 3, END + 0.15))
check("S2 traverser derrière, à 0,15 stud du bout : ne monte pas", offBoth())
-- … arrêté juste devant le bout, au milieu : rien.
away(alice)
walk(alice, vec(0, 3, -6.5), vec(0, 3, -(END + 0.1)))
step(1, FRAME)
check("S2 arrêté contre le bout avant (0,1 stud) : ne monte pas", offBoth())
-- … par l'avant puis sur la bande, jusqu'au milieu : rien (règle d'a180).
walk(alice, vec(0, 3, -(END + 0.1)), vec(0.3, 3, 0.3))
step(1, FRAME)
check("S2 par l'avant, jusqu'au milieu de la bande : ne monte pas", offBoth())
away(alice)
walk(alice, vec(0, 3, 5.8), vec(0, 3, 1))
check("S2 par l'arrière, sur la bande : ne monte pas", offBoth())

-- S3 : coin : dans la marge en travers mais au-delà d'un bout : rien ; y entrer ensuite par le bout : rien.
away(alice)
walk(alice, vec(EDGE + 1, 3, -6.5), vec(EDGE + 1, 3, -(END + 0.3)))
step(0.5, FRAME)
check("S3 dans le coin avant (1 stud en travers, 0,3 au-delà du bout) : ne monte pas", offBoth())
walk(alice, vec(EDGE + 1, 3, -(END + 0.3)), vec(EDGE + 1, 3, -2))
step(0.5, FRAME)
check("S3 du coin vers le côté, en franchissant le bout : ne monte pas", offBoth())
away(alice)
walk(alice, vec(-4.8, 3, 6), vec(-(EDGE + 1), 3, END - 0.3))
check("S3 en diagonale par le coin arrière (le bout franchi d'abord) : ne monte pas", offBoth())
away(alice)
walk(alice, vec(4.8, 3, -3.6), vec(EDGE + 1, 3, -2.9))
check("S3 en diagonale par le côté près du bout (le côté franchi d'abord) : monte", onBoth())
-- fromSide directement (repère de la bande d'Alice).
local zoneA = TZ.describe(treadA, "Treadmill")
check("S3 fromSide : coin dans la marge, au-delà du bout → bout", TZ.fromSide(zoneA, vec(EDGE + 1, 3, -(END + 0.3))) == false)
check("S3 fromSide : coin hors marge, loin au-delà du bout → bout", TZ.fromSide(zoneA, vec(EDGE + MARGIN + 0.2, 3, -(END + 1.25))) == false)
check("S3 fromSide : au-delà du côté élargi → côté", TZ.fromSide(zoneA, vec(EDGE + MARGIN + 0.5, 3, 0)) == true)
check("S3 fromSide : devant, dans l'axe → bout", TZ.fromSide(zoneA, vec(0, 3, -(END + 0.5))) == false)
check("S3 fromSide : dans l'emprise élargie → aucun bord franchi", TZ.fromSide(zoneA, vec(EDGE + 1, 3, 0)) == false)
check("S3 inCore : 1,4 stud en travers → dedans", TZ.inCore(zoneA, vec(EDGE + 1.4, 3, 0)))
check("S3 inCore : 1,6 stud en travers → dehors", not TZ.inCore(zoneA, vec(EDGE + 1.6, 3, 0)))
check("S3 inCore : 0,1 stud au-delà du bout → dehors", not TZ.inCore(zoneA, vec(0, 3, END + 0.1)))

-- S4 : pas de remontée en boucle après une descente par le côté.
away(alice)
hop(alice, vec(4.5, 3, 0), vec(EDGE + 1, 3, 0))
check("S4 monté par le côté", onBoth())
descend()
check("S4 il bouge : descendu (serveur et client)", offBoth())
-- Il sort par le côté et s'arrête contre lui (dans la marge) : il ne remonte pas, même en y restant.
setMove(alice, 0, 0)
walk(alice, STAND_T, vec(EDGE + 1, 3, 0))
step(1.5, FRAME)
check("S4 descendu et arrêté contre le côté (1 stud) : ne remonte pas en boucle", offBoth())
check("S4 le client ne le replace pas sur la bande", rootPos(alice) == vec(EDGE + 1, 3, 0), tostring(rootPos(alice)))
-- Il revient sur la bande sans être sorti de l'emprise : toujours rien (il doit d'abord en sortir).
walk(alice, vec(EDGE + 1, 3, 0), vec(0.4, 3, 0))
step(0.5, FRAME)
check("S4 revenu sur la bande sans sortir de l'emprise élargie : ne remonte pas", offBoth())
-- Il sort de l'emprise élargie (encore dans la zone) puis revient contre le côté : il remonte (voulu).
walk(alice, vec(0.4, 3, 0), vec(EDGE + MARGIN + 0.6, 3, 0))
check("S4 sorti de l'emprise élargie : rien", offBoth())
walk(alice, vec(EDGE + MARGIN + 0.6, 3, 0), vec(EDGE + 1, 3, 0))
check("S4 revenu contre le côté : remonte", onBoth())
-- Descente en marchant d'une traite vers l'extérieur : aucune remontée en route.
descend()
local remount = 0
alice:GetAttributeChangedSignal("TrainingMachine"):Connect(function()
	if machineOf(alice) ~= nil then
		remount += 1
	end
end)
walk(alice, STAND_T, vec(4.8, 3, 0))
step(0.5, FRAME)
check("S4 descendu en marchant d'une traite par le côté : aucune remontée en route", offBoth() and remount == 0, remount)
setMove(alice, 0, 0)

-- S5 : Bob (tapis sans UseZone, zone X ±3 = emprise élargie) : contre le côté à 1 stud, serveur seul : monte ;
-- devant : rien.
walk(bob, vec(0, 3, 92), vec(0, 3, 100 - (END + 0.2)))
check("S5 Bob devant son tapis : ne monte pas", machineOf(bob) == nil)
away(bob)
walk(bob, vec(-5, 3, 100.5), vec(-(EDGE + 1), 3, 100.5))
check("S5 Bob contre le côté de son tapis (1 stud) : monte (serveur)", machineOf(bob) == "Treadmill")
away(bob)

-- S6 : banc de musculation inchangé : décor (on n'y monte pas) ; son cœur reste REENTRY_RADIUS autour du UsePoint.
away(alice)
walk(alice, vec(26, 3, 0), vec(20, 3, 0))
step(0.5, FRAME)
check("S6 sur le banc : rien (décor)", machineOf(alice) == nil and ANIM.playing.TreadmillRun == nil)
local zoneB = TZ.describe(benchA, "Bench")
check("S6 banc : inCore à 2,4 stud du UsePoint → dedans", TZ.inCore(zoneB, vec(22.4, 3, 0)))
check("S6 banc : inCore à 2,6 stud → dehors (REENTRY_RADIUS 2,5 inchangé)", not TZ.inCore(zoneB, vec(22.6, 3, 0)))
local ap = TZ.newApproach()
check("S6 banc : track toujours vrai (règle inchangée)", TZ.track(ap, zoneB, vec(22, 3, 0)) == true)
away(alice)

-- S7 : adopt inchangé : le suivi passe sur le nouveau tapis comme monté par le côté.
local ap2 = TZ.newApproach()
TZ.track(ap2, zoneA, vec(0, 3, -8))
TZ.track(ap2, zoneA, vec(0, 3, 0)) -- entré par le bout : pas de montée
check("S7 avant adopt : entré par le bout, pas de montée", TZ.track(ap2, zoneA, vec(0, 3.1, 0)) == false)
TZ.adopt(ap2, zoneA)
check("S7 adopt : zone et fromSide posés", ap2.zone == zoneA and ap2.fromSide == true)
check("S7 après adopt : sur la bande, montée permise", TZ.track(ap2, zoneA, vec(0, 3, 0)) == true)
-- Hauteur : au-dessus de l'emprise mais trop haut (saut) : non ; à la hauteur d'un perso debout : oui.
local ap3 = TZ.newApproach()
TZ.track(ap3, zoneA, vec(4.5, 3, 0))
check("S7 hauteur : contre le côté, HRP à 3 : oui", TZ.track(ap3, zoneA, vec(EDGE + 1, 3, 0)) == true)
check("S7 hauteur : même endroit, HRP à 6 (au-delà d'ENTRY_ABOVE) : non", TZ.track(ap3, zoneA, vec(EDGE + 1, 6, 0)) == false)

check("aucune erreur dans la sortie", not hasLog("ERREUR"))
print("banc a310 (tapis, entrée par le côté élargie) : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
