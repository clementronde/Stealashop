-- Banc f70c2, partie witness (Cantin, 18/11 : le témoin photographe « passe de son animation de course a une animation
-- posée devant la boutique sans que ce soit fluide »). Harnais a100 (copie a151) : les Humanoid avancent à leur WalkSpeed,
-- Heartbeat toutes les 0,05 s ; le faux AnimPlayer est enveloppé ici pour noter fondus et vitesses de lecture.
--   B0 réglages V0 ; B1 loin : course (Flee) à RushSpeed, sans freiner ; B2 freinage sur les BrakeDistance derniers studs
--   (vitesse qui baisse, jamais sous BrakeMinSpeed, course ralentie, au plus bas BrakeAnimMin) ; B3 arrivée à ArriveDistance,
--   lente, toujours en moins de 2,5 s pour 40 studs ; B4 fondus : course arrêtée en StopFade, TakePhoto lancée en PoseFade ;
--   B5 rotation progressive vers la vitrine en TurnTime ; B6 la casse pendant la rotation : la fuite garde son cap ;
--   B7 sans TakePhoto ni Flee : marche ralentie, Look en fondu ; B8 aucune alerte.

local vec = Vector3.new
local Witness = requireShared("Shared.Config.Witness")
local PHOTO = Witness.Photo

check(
	"B0 réglages V0 : BrakeDistance 6, BrakeMinSpeed 4, BrakeAnimMin 0,4, ArriveDistance 1, StopFade 0,35, PoseFade 0,35, TurnTime 0,4",
	PHOTO.BrakeDistance == 6
		and PHOTO.BrakeMinSpeed == 4
		and PHOTO.BrakeAnimMin == 0.4
		and PHOTO.ArriveDistance == 1
		and PHOTO.StopFade == 0.35
		and PHOTO.PoseFade == 0.35
		and PHOTO.TurnTime == 0.4
)

local map = node("Folder", "Map", Workspace)
local zone1 = node("Folder", "Zone_1", map)
local witnesses = node("Folder", "Witnesses", zone1)
local function store(name, x)
	local s = newStore(name, zone1, 1, vec(x, 5, -50))
	s.Window.CFrame = CFrame.lookAt(vec(x, 5, -50), vec(x, 5, -49))
	s.Window.Size = vec(10, 6, 0.5)
	return s
end
local sA = store("STORE_Z1_A", 0)
local sB = store("STORE_Z1_B", 400)
-- Poste : 8 studs devant la vitre (z = -42), décalé de 2 studs (témoin impair : x − 2). Il part à 40 studs du poste.
local spotA = vec(-2, 3, -42)
local wA = newWitness("NPC_Witness_Z1_01", witnesses, vec(-2, 3, -2), "STORE_Z1_A")
local spotB = vec(398, 3, -42)
local wB = newWitness("NPC_Witness_Z1_03", witnesses, vec(398, 3, -22), "STORE_Z1_B")
-- Tourné vers +X au départ : la vitrine est à environ 90° à sa droite une fois posté.
rootOf(wA).CFrame = CFrame.lookAt(rootOf(wA).Position, rootOf(wA).Position + vec(1, 0, 0))
rootOf(wB).CFrame = CFrame.lookAt(rootOf(wB).Position, rootOf(wB).Position + vec(1, 0, 0))
local alice = newPlayer("Alice", vec(0, 3, -45))
POLICE_TEMPLATE = nil

local Service = loadWitness()
local warnsAtStart = 0
for _, l in LOGS do
	if string.sub(l, 1, 4) == "WARN" then
		warnsAtStart += 1
	end
end

-- Faux AnimPlayer enveloppé : les animations livrées (HAVE) renvoient une piste ; fondus et vitesses notés.
local HAVE = { [wA] = { Flee = true, TakePhoto = true }, [wB] = {} }
local FADES = {} -- { model, name, action, fade, speed }
for model, names in HAVE do
	local p = ANIM_PLAYERS[model]
	local basePlay, baseStop = p.Play, p.Stop
	p.Play = function(self, name, fade, weight, speed)
		basePlay(self, name, fade, weight, speed)
		table.insert(FADES, { model = model, name = name, action = "Play", fade = fade, speed = speed })
		return if names[name] then {} else nil
	end
	p.Stop = function(self, name, fade)
		if self.playing[name] then
			table.insert(FADES, { model = model, name = name, action = "Stop", fade = fade })
		end
		baseStop(self, name, fade)
	end
end
local function lastOf(model, name, action)
	local found = nil
	for _, e in FADES do
		if e.model == model and e.name == name and e.action == action then
			found = e
		end
	end
	return found
end
local function infoOf(s, model)
	for _, entry in Service.GetState(s) do
		if entry.Witness == model then
			return entry
		end
	end
	return nil
end
local function flatDistance(a, b)
	return vec(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function windowDir(model)
	local p = rootOf(model).Position
	return vec(0 - p.X, 0, -50 - p.Z).Unit
end
local function angleTo(look, want)
	local dot = math.clamp(look.X * want.X + look.Z * want.Z, -1, 1)
	return math.deg(math.acos(dot))
end

-- B1 à B5 : avec Flee et TakePhoto.
local arrivedAt, lookAtArrival
do
	local t0 = NOW
	hit(alice, sA)
	local cruise = wA.Humanoid.WalkSpeed
	check("B1 il fonce : WalkSpeed = RushSpeed, Flee joue", cruise == PHOTO.RushSpeed and playing(wA, "Flee"), cruise)
	local fastFar, monotone, lowest, lowestAnim = true, true, math.huge, math.huge
	local previous = math.huge
	local samples = 0
	while infoOf(sA, wA).Approaching and NOW - t0 < 6 do
		local distance = flatDistance(rootOf(wA).Position, spotA)
		local speed = wA.Humanoid.WalkSpeed
		if distance > PHOTO.BrakeDistance + 0.01 and speed ~= cruise then
			fastFar = false
		end
		if distance < PHOTO.BrakeDistance then
			samples += 1
			if speed > previous + 1e-6 then
				monotone = false
			end
			previous = speed
			lowest = math.min(lowest, speed)
			local flee = ANIM_PLAYERS[wA].speeds.Flee
			if flee then
				lowestAnim = math.min(lowestAnim, flee)
			end
		end
		advance(0.05)
	end
	arrivedAt = NOW - t0
	check("B1 loin du poste : pas de freinage (RushSpeed tenue)", fastFar)
	check("B2 il freine sur les derniers studs (plusieurs images)", samples >= 3, samples)
	check("B2 la vitesse ne remonte pas pendant le freinage", monotone)
	check("B2 elle descend sous la moitié de la course, jamais sous BrakeMinSpeed", lowest < cruise / 2 and lowest >= PHOTO.BrakeMinSpeed - 1e-6, lowest)
	check("B2 la course ralentit avec lui, au plus bas BrakeAnimMin", lowestAnim < 1 and lowestAnim >= PHOTO.BrakeAnimMin - 1e-6, lowestAnim)
	local info = infoOf(sA, wA)
	check("B3 arrivé : TakePhoto, à ArriveDistance studs de son poste au plus", info.Approaching == false and info.Snapping == true and flatDistance(rootOf(wA).Position, spotA) <= PHOTO.ArriveDistance + 1e-6, flatDistance(rootOf(wA).Position, spotA))
	check("B3 arrivé lentement (≤ BrakeMinSpeed + 0,5)", previous <= PHOTO.BrakeMinSpeed + 0.5, previous)
	check("B3 toujours vite : 40 studs en moins de 2,5 s", arrivedAt <= 2.5, arrivedAt)
	local stop = lastOf(wA, "Flee", "Stop")
	check("B4 la course s'arrête en fondu de StopFade s", stop ~= nil and stop.fade == PHOTO.StopFade, stop and stop.fade)
	local pose = lastOf(wA, "TakePhoto", "Play")
	check("B4 TakePhoto arrive en fondu de PoseFade s", pose ~= nil and pose.fade == PHOTO.PoseFade, pose and pose.fade)
	check("B4 la course n'est plus jouée", not playing(wA, "Flee"))
	-- B5. La rotation : à l'arrivée, il n'est pas encore tourné ; elle avance en douceur, finie en TurnTime s.
	lookAtArrival = rootOf(wA).CFrame.LookVector
	local start = angleTo(lookAtArrival, windowDir(wA))
	check("B5 à l'arrivée : pas encore tourné vers la vitrine (plus de 45°)", start > 45, start)
	advance(PHOTO.TurnTime / 2)
	local half = angleTo(rootOf(wA).CFrame.LookVector, windowDir(wA))
	check("B5 à mi-temps : à moitié chemin environ (entre 25 % et 75 % de l'angle)", half > start * 0.25 and half < start * 0.75, `{half} sur {start}`)
	check("B5 à plat pendant la rotation", rootOf(wA).CFrame.LookVector.Y == 0)
	advance(PHOTO.TurnTime / 2 + 0.1)
	local look = rootOf(wA).CFrame.LookVector
	local want = windowDir(wA)
	check("B5 au bout de TurnTime s : face à la vitrine", near(look.X, want.X, 1e-6) and near(look.Z, want.Z, 1e-6) and look.Y == 0, `{look.X}, {look.Z}`)
	check("B5 il ne bouge pas en tournant", flatDistance(rootOf(wA).Position, spotA) <= PHOTO.ArriveDistance + 1e-6)
end

-- B6. La casse pendant la rotation : il fuit, et la rotation ne lui reprend plus son cap.
do
	rootOf(alice.Character).Position = vec(400, 3, -45)
	hit(alice, sB)
	-- B7. Sans Flee ni TakePhoto : la marche accélérée, ralentie elle aussi, puis Look en fondu.
	local firstGait = ANIM_PLAYERS[wB].speeds.Walk
	check("B7 sans Flee : la marche, à RushSpeed", playing(wB, "Walk") and wB.Humanoid.WalkSpeed == PHOTO.RushSpeed, wB.Humanoid.WalkSpeed)
	local lowestGait = math.huge
	local t = 0
	while infoOf(sB, wB).Approaching and t < 4 do
		advance(0.05)
		t += 0.05
		local gait = ANIM_PLAYERS[wB].speeds.Walk
		if gait and playing(wB, "Walk") then
			lowestGait = math.min(lowestGait, gait)
		end
	end
	check("B7 la marche ralentit au freinage", firstGait ~= nil and lowestGait < firstGait, `{lowestGait} / {firstGait}`)
	local walkStop = lastOf(wB, "Walk", "Stop")
	check("B7 la marche s'arrête en fondu de StopFade s", walkStop ~= nil and walkStop.fade == PHOTO.StopFade, walkStop and walkStop.fade)
	local look = lastOf(wB, "Look", "Play")
	check("B7 Look arrive en fondu de PoseFade s", look ~= nil and look.fade == PHOTO.PoseFade and playing(wB, "Look"), look and look.fade)
	advance(0.1) -- la rotation a commencé
	breakWindow(alice, sB)
	local away = rootOf(wB).CFrame.LookVector
	advance(0.3)
	local after = rootOf(wB).CFrame.LookVector
	check("B6 la casse pendant la rotation : il fuit et garde son cap de fuite", playing(wB, "Walk") and near(after.X, away.X, 1e-9) and near(after.Z, away.Z, 1e-9), `{after.X}, {after.Z}`)
end

local warns = 0
for _, l in LOGS do
	if string.sub(l, 1, 4) == "WARN" then
		warns += 1
	end
end
check("B8 aucune alerte dans la boucle ni à chaque image", warns == warnsAtStart, warns - warnsAtStart)

print(`banc f70c2 witness : {CHECKS} vérification(s), {FAILS} échec(s)`)
