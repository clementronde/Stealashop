-- Scénarios a69 (2026-11-11, vague 24) : le vigile coupe la route (point d'interception), tout de suite et
-- sans à-coups. Vrai GuardService poursuivi par un conducteur du camion (même chaseStep que les vigiles
-- de jour et de nuit). Le joueur envoie sa vitesse au sol (AssemblyLinearVelocity) ; le « témoin » est la
-- même poursuite sans vitesse envoyée : il vise alors le joueur lui-même (poursuite d'avant, au même rythme).
--   I1 le joueur fait demi-tour et passe à côté du vigile : il coupe vers où le joueur va (changement de
--      direction mesuré), le rattrape, plus tôt que le témoin
--   I2 fuite en ligne droite : vigile plus rapide (point devant le joueur, sur sa ligne, au plus 1,5 s) ;
--      vigile plus lent (pas de solution : il vise le joueur, poursuite sans fin)
--   I3 zigzag : le vigile zigzague moins que le joueur
--   I4 obstacle : chemin vers un point jamais dans le bâtiment, pas de demi-tour, capture
--   I5 zone safe : aucun point visé dans la zone safe, poursuite finie à son entrée
--   I6 cadence des MoveTo : au plus un toutes les 0,1 s ; redonné toutes les 2 s à une cible immobile
--   I7 coût : rayons par seconde, interception active

if not A69 then
	print("\na69 SAUTÉ : cet arbre n'a pas encore l'interception (interceptPoint)")
	summary()
	return
end

local MOVE_LOG = {}
do
	local baseMoveTo = Methods.MoveTo
	Methods.MoveTo = function(self, position)
		table.insert(MOVE_LOG, { hum = self, pos = position, t = now() })
		return baseMoveTo(self, position)
	end
end
local function movesOf(model, since, untilT)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local out = {}
	for _, e in MOVE_LOG do
		if e.hum == hum and e.t >= since and (untilT == nil or e.t <= untilT) then
			table.insert(out, e)
		end
	end
	return out
end
local function startChase(name, n, pos, spawn, overrides)
	local p = addPlayer(name, pos)
	humOf(p).WalkSpeed = 16
	CarryService.StartCarry(p, truckBox(n))
	local o = { Spawn = CFrame.new(spawn) }
	for k, v in overrides or {} do
		o[k] = v
	end
	local model = GuardService.StartDriverChase(chaseOf(p, n, o))
	return p, model
end
local SLOW = { SpeedMultiplier = 0.9, MinSpeed = 1 } -- 14,4 studs/s : le vigile de jour (0,9 × vitesse conseillée − 1)
local FAST = { SpeedMultiplier = 1.2, MinSpeed = 1 } -- 19,2 studs/s
table.clear(WALLS)

---------------------------------------------------------------- I1 demi-tour à côté du vigile
print("\n--- I1 le joueur fait demi-tour et passe à côté du vigile")
local function uTurn(n, x0, sendVelocity)
	SEND_VELOCITY = sendVelocity
	local p, model = startChase(`Turner{n}`, n, Vector3.new(x0 + 12, 3, 0), Vector3.new(x0, GROUND, 0), SLOW)
	RUN[p] = Vector3.new(16, 0, 0)
	frames(1.6) -- délai de réaction (0,5 s), puis tout droit : le vigile, plus lent, est derrière
	RUN[p] = Vector3.new(0, 0, 16) -- il s'écarte sur le côté…
	frames(1.2)
	local rec = { gap = flatDist(model.HumanoidRootPart.Position, rootOf(p).Position) }
	RUN[p] = Vector3.new(-16, 0, 0) -- … et repart dans l'autre sens, à côté du vigile
	local turnAt = now()
	local maxZ = -math.huge
	local t = 0
	while t < 3 and caughtAt(p) == nil do
		frame()
		t += DT
		local h = heading(model)
		if rec.cut == nil and h and h.X < -0.1 then
			rec.cut = now() - turnAt
		end
		maxZ = math.max(maxZ, model.HumanoidRootPart.Position.Z)
	end
	rec.caught = caughtAt(p)
	rec.caughtIn = if rec.caught then rec.caught - turnAt else nil
	rec.maxZ = maxZ
	RUN[p] = nil
	SEND_VELOCITY = true
	CarryService.Fail(p, "Test") -- le témoin, jamais rattrapé, ne poursuit plus pendant la suite
	frames(0.2)
	return rec
end
local cut = uTurn(601, 6000, true)
local tail = uTurn(602, 6400, false)
local function fmt(v)
	return if v then string.format("%.2f s", v) else "jamais"
end
print(string.format("    écart au demi-tour %.1f studs ; interception : coupe vers l'arrière en %s, capture en %s, Z max %.1f ; témoin : %s, capture %s, Z max %.1f",
	cut.gap, fmt(cut.cut), fmt(cut.caughtIn), cut.maxZ, fmt(tail.cut), fmt(tail.caughtIn), tail.maxZ))
check(cut.cut ~= nil and cut.cut <= 0.25, `I1a il coupe vers où va le joueur en 0,25 s au plus ({fmt(cut.cut)})`)
check(cut.caught ~= nil and cut.caughtIn <= 2, `I1b il le rattrape en 2 s au plus après le demi-tour ({fmt(cut.caughtIn)})`)
check(tail.cut == nil or cut.cut < tail.cut, `I1c il tourne avant le témoin qui vise le joueur ({fmt(tail.cut)})`)
check(tail.caughtIn == nil or cut.caughtIn <= tail.caughtIn, `I1d rattrapé avant le témoin ({fmt(tail.caughtIn)})`)
check(cut.maxZ < tail.maxZ - 1, string.format("I1e il ne refait pas le détour du joueur (Z max %.1f contre %.1f)", cut.maxZ, tail.maxZ))

---------------------------------------------------------------- I2 fuite en ligne droite
print("\n--- I2 fuite en ligne droite")
local function straight(n, x0, sendVelocity, speed)
	SEND_VELOCITY = sendVelocity
	local p, model = startChase(`Runner{n}`, n, Vector3.new(x0 + 8, 3, 0), Vector3.new(x0, GROUND, 0), speed)
	RUN[p] = Vector3.new(16, 0, 0)
	local startAt = now()
	frames(1.5)
	local rec = { aim = moveTarget(model), at = rootOf(p).Position, rays0 = RAYCASTS, t0 = now() }
	rec.gap = flatDist(model.HumanoidRootPart.Position, rec.at)
	local t = 0
	while t < 1 and caughtAt(p) == nil do
		frame()
		t += DT
	end
	rec.rays = (RAYCASTS - rec.rays0) / math.max(t, DT)
	rec.moves = #movesOf(model, rec.t0, now()) / math.max(t, DT)
	rec.t = t
	frames(8)
	rec.caught = caughtAt(p)
	rec.caughtIn = if rec.caught then rec.caught - startAt else nil
	rec.chased = not fullLogHas(`abandonne {p.Name}`)
	rec.player = p
	rec.model = model
	RUN[p] = nil
	SEND_VELOCITY = true
	return rec
end
local fast = straight(611, 7000, true, FAST)
local fastTail = straight(612, 7400, false, FAST)
print(string.format("    vigile plus rapide : point visé %.1f studs devant le joueur (écart latéral %.2f), capture %s ; témoin : capture %s",
	fast.aim.X - fast.at.X, math.abs(fast.aim.Z - fast.at.Z), fmt(fast.caughtIn), fmt(fastTail.caughtIn)))
check(fast.aim.X > fast.at.X + 1 and fast.aim.X - fast.at.X <= 16 * 1.5 + 0.5 and math.abs(fast.aim.Z) < 0.5,
	"I2a vigile plus rapide : il vise devant le joueur, sur sa ligne, au plus 1,5 s de course devant lui")
-- Rattrapage à pleine vitesse : de 1,5 s à la capture, l'écart fond à 19,2 − 16 = 3,2 studs/s (le départ
-- peut varier d'une image entre deux poursuites : on compare depuis 1,5 s, pas depuis l'apparition).
local closing = if fast.caughtIn then (fast.caughtIn - 1.5) else math.huge
local ideal = (fast.gap - Balance.Guard.CatchDistance) / (19.2 - 16)
print(string.format("    de 1,5 s à la capture : %.2f s (en ligne droite à pleine vitesse : %.2f s)", closing, ideal))
check(fast.caught ~= nil and fastTail.caught ~= nil and closing <= ideal + 0.15, "I2b rattrapé à pleine vitesse (comme le témoin en ligne droite)")
local slow = straight(613, 7800, true, SLOW)
local aimSlow = moveTarget(slow.model)
print(string.format("    vigile plus lent : point visé à %.2f studs du joueur, toujours poursuivi : %s", if aimSlow then flatDist(aimSlow, rootOf(slow.player).Position) else -1, tostring(slow.chased)))
check(slow.caught == nil and slow.chased, "I2c vigile plus lent : pas de solution, poursuite sans fin (pas d'abandon)")
check(slow.aim and slow.aim.X <= slow.at.X + 1e-3 and flatDist(slow.aim, slow.at) <= 16 * 0.2 + 1.1,
	"I2d sans solution : il vise le joueur lui-même, jamais devant lui")
CarryService.Fail(slow.player, "Test")

---------------------------------------------------------------- I3 zigzag
print("\n--- I3 zigzag")
local function zigzag(n, x0, sendVelocity)
	SEND_VELOCITY = sendVelocity
	local p, model = startChase(`Zig{n}`, n, Vector3.new(x0 + 30, 3, 0), Vector3.new(x0, GROUND, 0), FAST)
	local side, flipAt = 1, 0
	local playerFlips, guardFlips, lastGuardSide = 0, 0, 0
	-- Chemin parcouru sur le côté (somme des |ΔZ|) : le zigzag de chacun, sans compter la dérive vers la
	-- ligne moyenne du joueur.
	local pz = { travel = 0 }
	local gz = { travel = 0 }
	local startAt = now()
	local function every()
		if now() >= flipAt then
			side = -side
			flipAt = now() + 0.4
			RUN[p] = Vector3.new(12.8, 0, 9.6 * side) -- 16 studs/s, en zigzag
			if now() - startAt >= 1.6 then
				playerFlips += 1
			end
		end
		if now() - startAt >= 1.6 and caughtAt(p) == nil then
			local z = rootOf(p).Position.Z
			local g = model.HumanoidRootPart.Position.Z
			if pz.last then
				pz.travel += math.abs(z - pz.last)
				gz.travel += math.abs(g - gz.last)
			end
			pz.last, gz.last = z, g
			local h = heading(model)
			if h and math.abs(h.Z) > 0.05 then
				local s = if h.Z > 0 then 1 else -1
				if lastGuardSide ~= 0 and s ~= lastGuardSide then
					guardFlips += 1
				end
				lastGuardSide = s
			end
		end
	end
	frames(4.6, every)
	local rec = { pz = pz.travel, gz = gz.travel, playerFlips = playerFlips, guardFlips = guardFlips }
	frames(6, every)
	rec.caught = caughtAt(p)
	RUN[p] = nil
	SEND_VELOCITY = true
	return rec
end
local zig = zigzag(621, 8200, true)
local zigTail = zigzag(622, 8600, false)
print(string.format("    en 3 s, sur le côté : joueur %.1f studs, %d zigzags ; vigile %.1f studs, %d changements de côté ; témoin %.1f studs, %d",
	zig.pz, zig.playerFlips, zig.gz, zig.guardFlips, zigTail.gz, zigTail.guardFlips))
check(zig.gz <= zig.pz * 0.5, string.format("I3a le vigile zigzague au plus moitié moins que le joueur (%.1f contre %.1f studs sur le côté)", zig.gz, zig.pz))
check(zig.guardFlips <= zig.playerFlips, `I3b il ne change pas de côté plus souvent que le joueur ({zig.guardFlips} contre {zig.playerFlips})`)
check(zig.caught ~= nil, "I3c le joueur qui zigzague est rattrapé")

---------------------------------------------------------------- I4 obstacle
print("\n--- I4 obstacle")
local X0 = 9000
local function wallEntry(name, x0, z0, x1, z1)
	local part = new("Part", name, nil)
	part.Size = Vector3.new(x1 - x0, 10, z1 - z0)
	part.CFrame = CFrame.new((x0 + x1) / 2, 5, (z0 + z1) / 2)
	return { cframe = part.CFrame, size = part.Size, part = part, name = name }
end
local BUILDING = { x0 = X0 + 20, z0 = 3, x1 = X0 + 60, z1 = 40 }
local function insideBuilding(pos)
	return pos.X > BUILDING.x0 and pos.X < BUILDING.x1 and pos.Z > BUILDING.z0 and pos.Z < BUILDING.z1
end
table.clear(WALLS)
table.insert(WALLS, wallEntry("Building", BUILDING.x0, BUILDING.z0, BUILDING.x1, BUILDING.z1))
NAV_NODES = { Vector3.new(X0 + 62, GROUND, 1), Vector3.new(X0 + 62, GROUND, 42), Vector3.new(X0 + 18, GROUND, 1) }
local goals0 = #PATH_GOALS
local bob, driver = startChase("Bob", 631, Vector3.new(X0 + 40, 3, 0), Vector3.new(X0, GROUND, 0), { SpeedMultiplier = 1.5, MinSpeed = 20 })
RUN[bob] = Vector3.new(16, 0, 0)
local rec = { uTurns = 0, inside = false }
local prevPos, prevStep, turned = nil, nil, false
local lost, back, backAim, backPos = nil, nil, nil, nil
local t = 0
while t < 10 and caughtAt(bob) == nil do
	frame()
	t += DT
	local pos = driver.HumanoidRootPart.Position
	if not turned and rootOf(bob).Position.X >= X0 + 64 then
		turned = true
		RUN[bob] = Vector3.new(0, 0, 16)
	end
	if insideBuilding(pos) then
		rec.inside = true
	end
	local seen = sees(driver, bob)
	if not seen and lost == nil then
		lost = now()
	elseif seen and lost and back == nil then
		back = now()
	end
	if back and backAim == nil and now() - back >= 0.15 - 1e-6 then
		backAim, backPos = moveTarget(driver), pos
	end
	if prevPos then
		local stepVec = Vector3.new(pos.X - prevPos.X, 0, pos.Z - prevPos.Z)
		if stepVec.Magnitude > 1e-3 then
			if prevStep and angleDeg(stepVec.Unit, prevStep) > 120 then
				rec.uTurns += 1
			end
			prevStep = stepVec.Unit
		end
	end
	prevPos = pos
end
local badGoals = 0
for i = goals0 + 1, #PATH_GOALS do
	local g = PATH_GOALS[i].goal
	if insideBuilding(g) or g.X < -100 then
		badGoals += 1
	end
end
print(string.format("    caché %.2f s, %d chemin(s) calculé(s), %d but(s) dans le bâtiment, demi-tours %d, rattrapé : %s",
	if lost and back then back - lost else 0, #PATH_GOALS - goals0, badGoals, rec.uTurns, tostring(caughtAt(bob) ~= nil)))
check(turned and lost ~= nil and back ~= nil, "I4a le bâtiment cache le joueur, puis la vue revient")
check(#PATH_GOALS - goals0 >= 1 and badGoals == 0, "I4b caché : un chemin, vers un point jamais dans le bâtiment")
check(rec.uTurns == 0 and not rec.inside, `I4c ni demi-tour ni course dans le bâtiment ({rec.uTurns})`)
check(backAim ~= nil and Workspace:Raycast(backPos, backAim - backPos) == nil, "I4d la vue revenue : droit sur un point en ligne de vue")
check(caughtAt(bob) ~= nil, "I4e rattrapé après le bâtiment")
RUN[bob] = nil
table.clear(WALLS)
NAV_NODES = {}

---------------------------------------------------------------- I5 zone safe
print("\n--- I5 zone safe (X < −100)")
local eve, safeGuard = startChase("Eve", 641, Vector3.new(-70, 3, 25), Vector3.new(-50, GROUND, 0), { SpeedMultiplier = 1.3, MinSpeed = 1 })
local since = now()
frames(0.6)
RUN[eve] = Vector3.new(-16, 0, 0)
local deepest = math.huge
t = 0
while t < 4 and rootOf(eve).Position.X > -101 do
	frame()
	t += DT
	deepest = math.min(deepest, safeGuard.HumanoidRootPart.Position.X)
end
frames(0.3)
RUN[eve] = nil
local inSafe, ahead = 0, 0
for _, e in movesOf(safeGuard, since, now()) do
	if e.pos.X < -100 then
		inSafe += 1
	end
end
print(string.format("    %d MoveTo, %d dans la zone safe ; vigile au plus loin à X = %.1f ; attrapée : %s", #movesOf(safeGuard, since, now()), inSafe, deepest, tostring(caughtAt(eve) ~= nil)))
check(inSafe == 0, "I5a aucun point visé dans la zone safe")
check(deepest > -100, "I5b le vigile n'y entre pas")
check(caughtAt(eve) ~= nil or not GuardService.IsChased(eve), "I5c attrapée avant, ou poursuite finie à l'entrée de la zone safe")

---------------------------------------------------------------- I6 cadence des MoveTo
print("\n--- I6 cadence des MoveTo")
print(string.format("    ligne droite, interception : %.1f MoveTo/s", fast.moves))
check(fast.moves <= 1 / 0.1 + 1, `I6a au plus un MoveTo toutes les 0,1 s ({string.format("%.1f", fast.moves)}/s)`)
-- Cible immobile, loin, vigile lent : même point ; MoveTo redonné toutes les 2 s (Humanoid.MoveTo lâche à 8 s).
local fay, idle = startChase("Fay", 651, Vector3.new(10080, 3, 0), Vector3.new(10000, GROUND, 0), { SpeedMultiplier = 0.1, MinSpeed = 6 })
frames(0.6)
local idleSince = now()
frames(6.5)
local idleMoves = movesOf(idle, idleSince, now())
local same = true
for _, e in idleMoves do
	if flatDist(e.pos, rootOf(fay).Position) > 0.5 then
		same = false
	end
end
print(string.format("    cible immobile : %d MoveTo en 6,5 s", #idleMoves))
check(#idleMoves >= 3 and #idleMoves <= 5 and same, `I6b cible immobile : même point, redonné toutes les 2 s ({#idleMoves} en 6,5 s)`)
CarryService.Fail(fay, "Test")

---------------------------------------------------------------- I7 coût
print("\n--- I7 coût")
print(string.format("    interception active : %.0f rayons/s", fast.rays))
check(fast.rays <= 120, `I7a au plus 120 rayons/s par vigile en vue ({string.format("%.0f", fast.rays)})`)

summary()
