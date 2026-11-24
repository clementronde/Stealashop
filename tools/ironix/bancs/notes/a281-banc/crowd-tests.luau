-- Banc a281 (vague GC3, 23/11, audit a271 point 1) : le vrai WitnessCrowdController sur le faux Roblox du banc a240
-- crowd (lignes avant « -- B1. », ajoutées par crowd-run.sh). Magasins du faux : vitrine en z = −50 tournée vers +Z,
-- Bounds de z = −80 à −50, magasin n en x = (n − 1) × 200. Caméra du faux complétée ici : FieldOfView 70, écran
-- 1600 × 900 (typeof rend "Vector2" pour ce faux).
--   C0 valeurs (Cull.Enabled, AnimDistance 80, Radius 5, ViewDistanceLow 120)
--   C1 caméra devant la foule : à l'écran, animées à leur rythme sauf au-delà de AnimDistance ; tournées vers le voleur
--   C2 caméra retournée (foule derrière) : toutes en pause, GetStats().Paused = toutes ; le voleur bouge : pas de regard
--   C3 caméra revenue : reprise au même rythme qu'avant la pause, regards sur le voleur
--   C4 caméra loin, foule à l'écran : toutes en pause, mais elles se tournent encore vers le voleur
--   C5 appareil faible : refusée au-delà de ViewDistanceLow, formée en deçà ; appareil normal : formée jusqu'à ViewDistance
--   aucune erreur

do
	local realTypeof = typeof
	typeof = function(v)
		if type(v) == "table" and rawget(v, "_v2") then
			return "Vector2"
		end
		return realTypeof(v)
	end
end
camera.FieldOfView = 70
camera.ViewportSize = { X = 1600, Y = 900, _v2 = true }

local CULL = CROWD.Cull
local function xOf(index)
	return (index - 1) * 200
end
local function waitFull()
	for _ = 1, 80 do
		if (Controller.GetStats().Pending or 0) == 0 then
			return
		end
		advance(0.05)
	end
end
local function crowdAt(index)
	for _, c in Controller.GetCrowds() do
		if c.Store == stores[index] then
			return c
		end
	end
	return nil
end
local function facingAll(target)
	local list = members()
	for _, m in list do
		local root = m.HumanoidRootPart
		local look = vec(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if root.CFrame.LookVector:Dot(look.Unit) <= 0.99 then
			return false
		end
	end
	return #list > 0
end
local function camDist(m)
	return (m.HumanoidRootPart.Position - camera.CFrame.Position).Magnitude
end
local TURN = CROWD.TurnInterval + 0.02

-- C0. Valeurs ------------------------------------------------------------------------------------------------------
check("C0 Cull.Enabled, AnimDistance 80, Radius 5 (V0 23/11)", CULL ~= nil and CULL.Enabled == true and CULL.AnimDistance == 80 and CULL.Radius == 5)
check("C0 ViewDistance 220 inchangée, ViewDistanceLow 120 (V0 23/11)", CROWD.ViewDistance == 220 and CROWD.ViewDistanceLow == 120)
check("C0 MaxCrowds, PerSide, TurnInterval inchangés", CROWD.MaxCrowds == 2 and CROWD.PerSide == 12 and CROWD.TurnInterval == 0.1)

-- C1. Caméra devant la foule -----------------------------------------------------------------------------------------
moveTo(alice, vec(0, 3, -30))
advance(0.3)
camera.CFrame = cf(vec(0, 10, 30), 0)
moveTo(alice, vec(0, 3, -65))
advance(CROWD.CheckInterval + 0.05)
waitFull()
advance(TURN)
local list = members()
local speeds = {}
local okSpeed, nearCount, farCount = true, 0, 0
for _, m in list do
	local track = TRACKS[m]
	if track then
		if camDist(m) > CULL.AnimDistance then
			farCount += 1
			okSpeed = okSpeed and track.Speed == 0
		else
			nearCount += 1
			speeds[m] = track.Speed
			okSpeed = okSpeed and track.Speed >= 0.9 and track.Speed <= 1.1
		end
	end
end
print(`MESURE C1 : {#list} personnes, {nearCount} à moins de {CULL.AnimDistance} studs, {farCount} plus loin, Paused {Controller.GetStats().Paused}`)
check("C1 foule formée et complète", crowdAt(1) ~= nil and #list == 2 * CROWD.PerSide, #list)
check("C1 animées à leur rythme (0,9 à 1,1) ; au-delà de AnimDistance : en pause", okSpeed and nearCount > 0)
check("C1 Paused = personnes au-delà de AnimDistance", Controller.GetStats().Paused == farCount, Controller.GetStats().Paused)
check("C1 tournées vers le voleur", facingAll(alice.Character.HumanoidRootPart.Position))

-- C2. Caméra retournée ---------------------------------------------------------------------------------------------
camera.CFrame = cf(vec(0, 10, 20), math.pi) -- regarde vers +Z : toute la foule (z < 10) derrière
advance(TURN)
local allPaused = true
for _, m in members() do
	local track = TRACKS[m]
	if track and track.Speed ~= 0 then
		allPaused = false
	end
end
local stats = Controller.GetStats()
check("C2 hors écran : toutes en pause", allPaused and stats.Paused == stats.Members and stats.Members > 0, `{stats.Paused}/{stats.Members}`)
local yaws = {}
for _, m in members() do
	yaws[m] = m.HumanoidRootPart.CFrame._yaw
end
moveTo(alice, vec(6, 3, -60))
advance(3 * TURN)
local still = true
for _, m in members() do
	if m.HumanoidRootPart.CFrame._yaw ~= yaws[m] then
		still = false
	end
end
check("C2 hors écran : personne ne se tourne quand le voleur bouge", still)
check("C2 la foule reste (voleur dans Bounds)", crowdAt(1) ~= nil and #members() == 2 * CROWD.PerSide)

-- C3. Caméra revenue -----------------------------------------------------------------------------------------------
camera.CFrame = cf(vec(0, 10, 30), 0)
advance(TURN)
local sameSpeed, resumed = true, 0
for m, speed in speeds do
	local track = TRACKS[m]
	if track and camDist(m) <= CULL.AnimDistance then
		resumed += 1
		sameSpeed = sameSpeed and track.Speed == speed
	end
end
check("C3 reprise au même rythme qu'avant la pause", sameSpeed and resumed == nearCount, `{resumed}/{nearCount}`)
check("C3 Paused revenu au compte de C1", Controller.GetStats().Paused == farCount, Controller.GetStats().Paused)
check("C3 regards sur la nouvelle place du voleur", facingAll(alice.Character.HumanoidRootPart.Position))

-- C4. Caméra loin, foule à l'écran ---------------------------------------------------------------------------------
camera.CFrame = cf(vec(0, 10, 200), 0)
moveTo(alice, vec(-6, 3, -62))
advance(TURN)
stats = Controller.GetStats()
check("C4 loin : toutes en pause", stats.Paused == stats.Members and stats.Members > 0, `{stats.Paused}/{stats.Members}`)
check("C4 loin mais à l'écran : elles se tournent encore vers le voleur", facingAll(alice.Character.HumanoidRootPart.Position))

-- Fin de la foule : sortie sans objet, Duration s, puis plus de Cooldown.
moveTo(alice, vec(0, 3, -30))
advance(CROWD.Duration + CROWD.FadeTime + 0.5)
advance(CROWD.Cooldown + 1)
check("C4 foule partie après la sortie", #Controller.GetCrowds() == 0 and #members() == 0, #members())

-- C5. ViewDistanceLow ----------------------------------------------------------------------------------------------
local function enterFrom(index, distance)
	camera.CFrame = cf(vec(xOf(index), 3, -65 + distance), 0)
	moveTo(alice, vec(xOf(index), 3, -65))
	advance(CROWD.CheckInterval + 0.05)
	waitFull()
	local formedHere = crowdAt(index) ~= nil
	moveTo(alice, vec(xOf(index), 3, -30))
	advance(CROWD.Duration + CROWD.FadeTime + 0.5)
	advance(CROWD.Cooldown + 1)
	return formedHere
end
LOW = true
check("C5 appareil faible, caméra à 150 studs (> ViewDistanceLow) : pas de foule", not enterFrom(3, 150))
check("C5 appareil faible, caméra à 100 studs : foule", enterFrom(4, 100))
LOW = false
check("C5 appareil normal, caméra à 150 studs (< ViewDistance) : foule", enterFrom(6, 150))
check("C5 appareil normal, caméra à 230 studs : pas de foule", not enterFrom(7, 230))

check("aucune erreur du contrôleur", not string.find(table.concat(LOGS, "\n"), "rror"), table.concat(LOGS, " | "))
print(`banc a281 crowd enter : {CHECKS} vérification(s), {FAILS} échec(s)`)
