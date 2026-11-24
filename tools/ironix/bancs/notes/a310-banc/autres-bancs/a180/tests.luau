-- Scénarios du banc a180 (Cantin, 2026-11-15). Tapis d'Alice à l'origine : bande X ±1,5, Z ±3,25 (dessus à 1,2),
-- UsePoint tourné vers −Z : l'axe du tapis est Z, les grands côtés sont en ±X, l'avant (console) en −Z.
-- Zone d'entrée (boîte du modèle + 1) : X ±3, Z −6 à 5. Le HumanoidRootPart est à y = 3.
-- Chaque vérification regarde le serveur (TrainingMachine) ET le client (place, TreadmillRun).

local FRAME = 1 / 60
local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
newPlot("PLOT_Shop_01", alice, Vector3.new(0, 0, 0))
newPlot("PLOT_Shop_02", bob, Vector3.new(0, 0, 100))
TrainingService.Init()
startClient(alice)

local STAND_T = Vector3.new(0, 4.2, 0)
local function away(p)
	setMove(p, 0, 0)
	moveTo(p, Vector3.new(p.UserId * 10, 3, -400))
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
local function onBoth()
	return machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true and rootPos(alice) == STAND_T
end
local function offBoth()
	return machineOf(alice) == nil and ANIM.playing.TreadmillRun == nil
end

-- C1, C2 : par chaque grand côté : monte (serveur et client à la même image).
away(alice)
walk(alice, Vector3.new(5, 3, 0.5), Vector3.new(0.5, 3, 0.5))
check("C1 entrée par le côté +X : monte (serveur et client)", onBoth(), tostring(machineOf(alice)))
away(alice)
check("C1 parti : descendu", offBoth())
walk(alice, Vector3.new(-5, 3, -1), Vector3.new(-0.5, 3, -1))
check("C2 entrée par le côté −X : monte (serveur et client)", onBoth(), tostring(machineOf(alice)))
away(alice)

-- C3 : très rapide (un seul contrôle entre hors de la zone et le milieu de la bande) : monte quand même.
moveTo(alice, Vector3.new(4, 3, 0))
step(FRAME, FRAME)
moveTo(alice, Vector3.new(0.5, 3, 0))
step(FRAME, FRAME)
check("C3 grand saut par le côté (hors zone → bande) : monte", onBoth())
away(alice)

-- F1 : traverser devant le tapis (dans la zone, entre la bande et la console) : rien.
walk(alice, Vector3.new(-5, 3, -4.5), Vector3.new(5, 3, -4.5))
check("F1 traverser devant : ne monte pas (serveur et client)", offBoth())
check("F1 le client ne déplace pas le joueur", rootPos(alice) == Vector3.new(5, 3, -4.5), tostring(rootPos(alice)))
away(alice)
-- F2 : traverser derrière : rien.
walk(alice, Vector3.new(-5, 3, 4.5), Vector3.new(5, 3, 4.5))
check("F2 traverser derrière : ne monte pas", offBoth())
away(alice)

-- F3 : marcher sur le bout de la bande depuis l'avant, jusqu'au milieu, et y rester : rien.
walk(alice, Vector3.new(0, 3, -8), Vector3.new(0.3, 3, 0.3))
check("F3 par l'avant, jusqu'au milieu de la bande : ne monte pas", offBoth())
local f3 = rootPos(alice) - Vector3.new(0.3, 3, 0.3)
check("F3 le client ne déplace pas le joueur", math.abs(f3.X) + math.abs(f3.Y) + math.abs(f3.Z) < 1e-6, tostring(rootPos(alice)))
step(1, FRAME)
check("F3 resté sur la bande 1 s : toujours rien", offBoth())
-- … par l'arrière aussi.
away(alice)
walk(alice, Vector3.new(0, 3, 8), Vector3.new(0, 3, 1))
check("F4 par l'arrière, sur la bande : ne monte pas", offBoth())

-- R1 : sorti de la bande par le côté, revenu par le côté : monte. a310 : sortir veut dire sortir de l'emprise
-- élargie (bande ± 1,5 + 1,5 = X ±3) : 3,5 au lieu de 2,5 (2,5 reste dans l'emprise, la sortie ne compte pas).
walk(alice, Vector3.new(0, 3, 1), Vector3.new(3.5, 3, 1))
check("R1 sorti par le côté, hors de l'emprise élargie : rien", offBoth())
walk(alice, Vector3.new(3.5, 3, 1), Vector3.new(0.5, 3, 1))
check("R1 revenu par le côté : monte (serveur et client)", onBoth())

-- R2 : après une séance (descendu en bougeant), ressortir par le bout puis revenir par le bout : rien ;
-- ressortir par le côté puis revenir par le côté : remonte (remontée a115 gardée).
setMove(alice, 0, 1)
step(FRAME, FRAME)
setMove(alice, 0, 0)
check("R2 il bouge : descendu", offBoth())
walk(alice, STAND_T, Vector3.new(0, 3, -4.5))
walk(alice, Vector3.new(0, 3, -4.5), Vector3.new(0, 3, -1))
check("R2 ressorti et revenu par l'avant : ne remonte pas", offBoth())
walk(alice, Vector3.new(0, 3, -1), Vector3.new(-3.5, 3, -1)) -- a310 : -2,6 → -3,5 (hors de l'emprise élargie)
walk(alice, Vector3.new(-3.5, 3, -1), Vector3.new(-0.5, 3, -1))
check("R2 ressorti et revenu par le côté : remonte", onBoth())
away(alice)

-- B1 : Bob sur le tapis d'Alice : par l'avant, rien (pas de message) ; par le côté, refusé avec le message
-- (NOT_OWNER_COOLDOWN gardé : un seul message en 10 s).
local before = notifyCount(bob)
walk(bob, Vector3.new(0, 3, -8), Vector3.new(0, 3, 0))
check("B1 Bob par l'avant du tapis d'Alice : aucun message", machineOf(bob) == nil and notifyCount(bob) == before)
away(bob)
walk(bob, Vector3.new(5, 3, 0), Vector3.new(0.5, 3, 0))
check("B1 Bob par le côté : refusé avec un message", machineOf(bob) == nil and notifyCount(bob) == before + 1, notifyCount(bob) - before)
walk(bob, Vector3.new(0.5, 3, 0), Vector3.new(5, 3, 0))
walk(bob, Vector3.new(5, 3, 0), Vector3.new(0.5, 3, 0))
check("B1 Bob revient par le côté : pas de second message (cooldown)", notifyCount(bob) == before + 1)
away(bob)
-- B2 : Bob sur son propre tapis (serveur seul, sans client) : même règle.
walk(bob, Vector3.new(0, 3, 92), Vector3.new(0, 3, 100))
check("B2 Bob par l'avant de son tapis : ne monte pas", machineOf(bob) == nil)
walk(bob, Vector3.new(0, 3, 100), Vector3.new(-5, 3, 100))
walk(bob, Vector3.new(-5, 3, 100), Vector3.new(-0.5, 3, 100))
check("B2 Bob par le côté de son tapis : monte", machineOf(bob) == "Treadmill")
away(bob)

check("aucune erreur dans la sortie", not hasLog("ERREUR"))
print("banc a180 (tapis par le côté) : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
