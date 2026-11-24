-- Scénario « tapis » du banc a205 (vague 63, L-207 : tapis de Clément élargis ×1,5). Harnais du banc a180 (copie
-- a134 d'a65 + a115, lus sur place). Le tapis d'Alice reçoit une bande de 5,16 × 0,2 × 6,08 studs (au lieu de
-- 3 × 0,2 × 6,5) et une UseZone de 12,8 × 6 × 13,1 ; UsePoint tourné vers −Z (axe du tapis Z, grands côtés en ±X).
-- La règle d'a180 (L-187 : monter par un grand côté seulement) doit tenir sur la bande élargie.

local FRAME = 1 / 60
local TrainingZone = requireModule(ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("TrainingZone"))
local alice = newPlayer("Alice")
local plot, mill = newPlot("PLOT_Shop_01", alice, Vector3.new(0, 0, 0))
local belt = mill:FindFirstChild("Belt")
belt.Size = Vector3.new(5.16, 0.2, 6.08)
mill:FindFirstChild("Frame").Size = Vector3.new(6, 1, 8)
local useZone = part("UseZone", mill, Vector3.new(12.8, 6, 13.1), Vector3.new(0, 3, 0))
useZone.CanCollide = false
TrainingService.Init()
startClient(alice)

local STAND_T = Vector3.new(0, 4.2, 0)
local function away(p)
	setMove(p, 0, 0)
	moveTo(p, Vector3.new(p.UserId * 10, 3, -400))
	step(0.6, FRAME)
end
local function walk(p, from, to)
	local d = to - from
	local length = math.sqrt(d.X * d.X + d.Y * d.Y + d.Z * d.Z)
	local n = math.max(1, math.ceil(length / (16 * FRAME)))
	for i = 0, n do
		if machineOf(p) ~= nil or ANIM.playing.TreadmillRun then
			break
		end
		moveTo(p, from + d * (i / n))
		step(FRAME, FRAME)
	end
end
local function onBoth()
	return machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true and rootPos(alice) == STAND_T
end
local function offBoth()
	return machineOf(alice) == nil and ANIM.playing.TreadmillRun == nil
end

-- W0 : la géométrie lue sur le modèle (Belt, UseZone), pas une largeur codée.
local zone = TrainingZone.describe(mill, "Treadmill")
local _, beltSize = TrainingZone.beltBox(zone)
check("W0 bande lue sur le modèle : 5,16 de large", beltSize.X == 5.16 and beltSize.Z == 6.08, tostring(beltSize))
local _, zoneSize = TrainingZone.zoneBox(zone)
check("W0 zone d'entrée = UseZone de Clément", zoneSize == Vector3.new(12.8, 6, 13.1), tostring(zoneSize))
check("W0 zone : bords en X (±6,4)", TrainingZone.inZone(zone, Vector3.new(6.35, 3, 0)) and not TrainingZone.inZone(zone, Vector3.new(6.45, 3, 0)))
check("W0 zone : bords en Z (±6,55)", TrainingZone.inZone(zone, Vector3.new(0, 3, -6.5)) and not TrainingZone.inZone(zone, Vector3.new(0, 3, 6.6)))
check("W0 cœur : 2,5 studs du centre est sur la bande élargie", TrainingZone.inCore(zone, Vector3.new(2.5, 3, 0)) and not TrainingZone.inCore(zone, Vector3.new(2.7, 3, 0)))
check("W0 FALLBACK_BELT_SIZE à la largeur des nouveaux tapis", TrainingZone.FALLBACK_BELT_SIZE == Vector3.new(5.16, 0.2, 6.08))

-- W1, W2 : par chaque grand côté : monte (serveur et client).
away(alice)
walk(alice, Vector3.new(8, 3, 0.5), Vector3.new(1, 3, 0.5))
check("W1 entrée par le côté +X : monte (serveur et client)", onBoth(), tostring(machineOf(alice)))
away(alice)
walk(alice, Vector3.new(-8, 3, -1), Vector3.new(-1, 3, -1))
check("W2 entrée par le côté −X : monte", onBoth(), tostring(machineOf(alice)))
away(alice)
-- W3 : arrêt à x = 2,3 (hors de l'ancienne bande de 3, sur la nouvelle) : monte.
walk(alice, Vector3.new(8, 3, 0), Vector3.new(2.3, 3, 0))
check("W3 arrêt sur le bord de la bande élargie (x = 2,3) : monte", onBoth(), tostring(rootPos(alice)))
away(alice)

-- F1 à F3 : devant, derrière, par les bouts : rien.
walk(alice, Vector3.new(-8, 3, -4.5), Vector3.new(8, 3, -4.5))
check("F1 traverser devant (dans la UseZone) : ne monte pas", offBoth())
away(alice)
walk(alice, Vector3.new(0, 3, -9), Vector3.new(0.3, 3, 0.3))
check("F2 par l'avant jusqu'au milieu de la bande : ne monte pas", offBoth())
step(1, FRAME)
check("F2 resté 1 s : toujours rien", offBoth())
away(alice)
walk(alice, Vector3.new(2, 3, 9), Vector3.new(2, 3, 1))
check("F3 par l'arrière, au bord de la bande élargie : ne monte pas", offBoth())
-- R1 : ressorti par le côté puis revenu par le côté : monte.
walk(alice, Vector3.new(2, 3, 1), Vector3.new(4, 3, 1))
walk(alice, Vector3.new(4, 3, 1), Vector3.new(1, 3, 1))
check("R1 ressorti puis revenu par le côté : monte", onBoth())
away(alice)

-- N1 : tapis sans Belt : bande de secours (FALLBACK_BELT_SIZE) posée sur le UsePoint, même règle.
local bare = buildTreadmill(workspace, Vector3.new(0, 0, 300), { noBelt = true, tag = false })
local bareZone = TrainingZone.describe(bare, "Treadmill")
local _, bareSize = TrainingZone.beltBox(bareZone)
check("N1 sans Belt : bande de secours 5,16 × 6,08", bareSize == TrainingZone.FALLBACK_BELT_SIZE, tostring(bareSize))
check("N1 sans Belt : x = 2,4 sur la bande, 2,7 non", TrainingZone.inCore(bareZone, Vector3.new(2.4, 3, 300)) and not TrainingZone.inCore(bareZone, Vector3.new(2.7, 3, 300)))
check("N1 sans Belt : arrivée par le côté reconnue", TrainingZone.fromSide(bareZone, Vector3.new(3, 3, 300)) and not TrainingZone.fromSide(bareZone, Vector3.new(0, 3, 296)))

check("aucune erreur dans la sortie", not hasLog("ERREUR"))
print("banc a205 tapis : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
