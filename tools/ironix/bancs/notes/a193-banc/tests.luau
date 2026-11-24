--!nocheck
-- a193 (2026-11-15, vague 60, T-069) : poursuite avec retard réseau. Voir run.sh. Lu après commun173.luau.
startBanc()
FRAME = 1 / 60
local BalanceCfg = sharedModule("Config/Balance")
local C = BalanceCfg.Guard.CatchDistance
local FAR2 = Vector3.new(4000, 3, 0)
local ON = ChaseCfg.LagCompensation == true
check(ON == (A193_SCENARIO ~= "off"), "0 Config/Chase.LagCompensation = " .. tostring(ChaseCfg.LagCompensation))
check(ChaseCfg.LagPingFactor == 2 and ChaseCfg.LagMaxSeconds == 0.3 and ChaseCfg.LagMaxStuds == 8 and ChaseCfg.LagContactReach == 3,
	"0 Config/Chase : LagPingFactor 2, LagMaxSeconds 0,3, LagMaxStuds 8, LagContactReach 3")

-- Speed du profil qui donne la marche `w` (Formulas.WalkSpeed, sans trail).
local function speedFor(w)
	local s = BalanceCfg.Stats
	return s.SpeedScale * (10 ^ ((w - s.BaseWalkSpeed) / s.WalkPerDecade) - 1)
end

-- Collisions simulées (collide) : le vigile ne passe pas à moins de BODY studs de la copie de sa cible sur le serveur.
local BODY = 1.5
COLLIDE = false
local baseFrame = BEFORE_FRAME
BEFORE_FRAME = function(dt)
	baseFrame(dt)
	if not COLLIDE then
		return
	end
	local active = Workspace:FindFirstChild("ActiveGuards")
	for _, model in (if active then active:GetChildren() else {}) do
		local id = model:GetAttribute("TargetUserId")
		local root = model:FindFirstChild("HumanoidRootPart")
		local target
		for _, p in Players:GetPlayers() do
			if p.UserId == id then
				target = rootOf(p)
			end
		end
		if root and target then
			local offset = Vector3.new(root.Position.X - target.Position.X, 0, root.Position.Z - target.Position.Z)
			if offset.Magnitude < BODY then
				local dir = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.new(-1, 0, 0)
				local at = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z) + dir * BODY
				root.CFrame = CFrame.new(at) * root.CFrame.Rotation
			end
		end
	end
end

local stores = { STORE_A, STORE_B }
local turn = 0
local function nextStore()
	turn += 1
	if turn > 2 then
		advance(25)
	end
	return stores[(turn - 1) % 2 + 1]
end

-- Une poursuite : voleur à la marche `w`, retard aller-retour `R` (s). Relevé image par image : distance vue
-- (position vraie du client − vigile tel que le client le voit, NET.oneWay s plus tôt), distance vraie (au même
-- instant), distance serveur (copie reçue − vigile).
local function run(w, R, seconds)
	NET.oneWay = 0
	local P = thief(speedFor(w))
	advance(8)
	if heist(P, nextStore(), OUT) == nil then
		return nil
	end
	NET.oneWay = R / 2
	PING[P] = R / 2
	walk(P, FAR2)
	for _ = 1, 150 do
		if chaserOf(P) then
			break
		end
		advance(FRAME)
	end
	local rec = { P = P, samples = {}, maxSpeed = 0, startT = now(), walk = humanoidOf(P).WalkSpeed }
	local model = chaserOf(P)
	if model == nil then
		return rec
	end
	local hist = {}
	local down = R / 2
	local n = #CATCHES
	while now() - rec.startT < seconds do
		advance(FRAME)
		local root = model:FindFirstChild("HumanoidRootPart")
		local hum = model:FindFirstChildOfClass("Humanoid")
		local mine = rootOf(P)
		local truth = clientPos(P)
		if root == nil or hum == nil or mine == nil or truth == nil or model.Parent == nil then
			rec.broke = string.format("vigile %s, root %s, client %s", tostring(model.Parent ~= nil), tostring(mine ~= nil), tostring(truth ~= nil))
			print("    arrêt du relevé à " .. fmt(now() - rec.startT) .. " s : " .. rec.broke .. ", cible " .. tostring(model:GetAttribute("TargetUserId")))
			break
		end
		table.insert(hist, { t = now(), pos = root.Position })
		local seen = hist[1].pos
		for _, h in hist do
			if h.t <= now() - down + 1e-9 then
				seen = h.pos
			else
				break
			end
		end
		local s = {
			t = now(),
			seen = horizontal(truth, seen),
			truth = horizontal(truth, root.Position),
			server = horizontal(mine.Position, root.Position),
			ws = hum.WalkSpeed,
			walk = humanoidOf(P).WalkSpeed,
		}
		if #CATCHES > n then
			-- la capture immobilise le voleur (marche 0) : marche et vitesse du vigile de l image d avant
			local prev = rec.samples[#rec.samples]
			if prev then
				s.walk, s.ws = prev.walk, prev.ws
			end
			rec.caught = s
			break
		end
		if rec.switchT == nil and rec.maxSpeed >= ChaseCfg.RushMinSpeed - 0.01
			and hum.WalkSpeed <= math.max(s.walk + ChaseCfg.ClosingSpeedMax + ChaseCfg.HoldRecallMax, ChaseCfg.HoldMinSpeed) + 0.5 then
			rec.switchT = now()
		end
		rec.maxSpeed = math.max(rec.maxSpeed, hum.WalkSpeed)
		table.insert(rec.samples, s)
	end
	return rec
end

local function finish(rec)
	if rec == nil then
		return
	end
	NET.oneWay = 0
	if rec.caught then
		stop(rec.P)
		advance(4)
	else
		endChase(rec.P)
	end
end

-- Avance compensée attendue (studs) : min(marche × R, LagMaxStuds) ; 0 compensation coupée.
local function comp(w, R)
	return if ON then math.min(w * math.min(R, ChaseCfg.LagMaxSeconds), ChaseCfg.LagMaxStuds) else 0
end

-- Bornes et moyenne entre +2 et +4 s après la fin de ruée.
local function window(rec, field)
	local lo, hi, sum, count = math.huge, -math.huge, 0, 0
	if rec.switchT then
		for _, s in rec.samples do
			if s.t >= rec.switchT + 2 and s.t <= rec.switchT + 4 then
				lo = math.min(lo, s[field])
				hi = math.max(hi, s[field])
				sum += s[field]
				count += 1
			end
		end
	end
	return lo, hi, if count > 0 then sum / count else nil
end

local function holdRun(w, R, label)
	local rec = run(w, R, 7)
	check(rec ~= nil and rec.switchT ~= nil, label .. " : braquage, ruée et fin de ruée")
	if rec == nil then
		return
	end
	local walkNow = rec.walk
	-- distance vue = D + marche × aller + vitesse du vigile (≈ la marche) × retour − avance compensée
	local expected = ChaseCfg.HoldDistance + walkNow * R - comp(walkNow, R)
	local lo, hi, mean = window(rec, "seen")
	local slo, shi = window(rec, "server")
	print(string.format("  mesure %s : marche %.1f, distance vue %s à %s (attendu %.2f), serveur %s à %s, capture %s",
		label, walkNow, fmt(lo), fmt(hi), expected, fmt(slo), fmt(shi), tostring(rec.caught ~= nil)))
	check(rec.caught == nil, label .. " : pas de capture en ligne droite au-dessus du minimum")
	check(mean ~= nil and lo >= expected - 0.5 and hi <= expected + 0.5,
		label .. string.format(" : distance vue %.2f ± 0,5 (%s à %s)", expected, fmt(lo), fmt(hi)))
	if not ON or R == 0 then
		check(mean ~= nil and slo >= ChaseCfg.HoldDistance - 0.5 and shi <= ChaseCfg.HoldDistance + 0.5,
			label .. " : sans compensation, 14 ± 0,5 de la position reçue (" .. fmt(slo) .. " à " .. fmt(shi) .. ")")
	end
	finish(rec)
end

local function catchRun(w, R, label, contact)
	local rec = run(w, R, 6)
	check(rec ~= nil and rec.caught ~= nil, label .. " : attrapé sous le minimum")
	if rec and rec.caught == nil then
		local last = rec.samples[#rec.samples]
		print(string.format("    %s : %d relevés, dernier : serveur %s, vue %s, vigile %s, marche %s", label, #rec.samples, fmt(last and last.server), fmt(last and last.seen), fmt(last and last.ws), fmt(last and last.walk)))
	end
	if rec == nil or rec.caught == nil then
		finish(rec)
		return
	end
	local s = rec.caught
	local up, down = R / 2, R / 2
	print(string.format("  mesure %s : marche %.1f, vigile %.1f, à la capture : vue %.2f, vraie %.2f, serveur %.2f",
		label, s.walk, s.ws, s.seen, s.truth, s.server))
	if contact then
		check(s.server <= ChaseCfg.LagContactReach + 0.05 and s.server >= BODY - 0.05,
			label .. " : capture au contact de la copie du serveur (" .. fmt(s.server) .. " studs)")
		check(s.seen < C + s.walk * R + s.ws * down, label .. " : vue plus près qu'avant (" .. fmt(s.seen) .. ")")
	else
		-- Le vigile arrive par derrière la copie du serveur : capture dès que sa distance à cette copie d_s vaut
		-- C − avance (estimation à C) ou LagContactReach (contact), la plus grande : d_s = max(C − avance, contact).
		-- vraie = d_s + marche × aller ; vue = vraie + vitesse du vigile × retour. Sans compensation : d_s = C.
		local a = comp(s.walk, R)
		local ds = if ON then math.max(C - a, ChaseCfg.LagContactReach) else C
		local truth = ds + s.walk * up
		local seen = truth + s.ws * down
		check(near(s.server, ds, 0.6), label .. string.format(" : à %.2f ± 0,6 de la copie du serveur (%.2f)", ds, s.server))
		check(near(s.seen, seen, 0.6), label .. string.format(" : distance vue à la capture %.2f ± 0,6 (%.2f)", seen, s.seen))
		check(near(s.truth, truth, 0.6), label .. string.format(" : distance vraie à la capture %.2f ± 0,6 (%.2f)", truth, s.truth))
		if ON then
			check(s.truth < C + s.walk * up - 0.5, label .. " : plus près qu avant (" .. fmt(s.truth) .. " < " .. fmt(C + s.walk * up) .. ")")
		end
	end
	finish(rec)
end

if A193_SCENARIO == "hold" then
	section("hold : au-dessus du minimum")
	for _, w in { 30, 60, 90 } do
		for _, R in { 0, 0.1, 0.2 } do
			holdRun(w, R, string.format("H%d/%d", w, R * 1000))
		end
	end
elseif A193_SCENARIO == "catch" then
	section("catch : bien sous le minimum")
	for _, w in { 30, 60, 90 } do
		for _, R in { 1 / 30, 0.1, 0.2 } do -- 1/30 : aller d une image (le relevé suit les images)
			catchRun(w, R, string.format("C%d/%d", w, R * 1000))
		end
	end
elseif A193_SCENARIO == "collide" then
	section("collide : le vigile bute sur la copie du voleur")
	COLLIDE = true
	holdRun(90, 0.2, "K90/200 au-dessus")
	holdRun(90, 0.1, "K90/100 au-dessus")
	catchRun(60, 0.2, "K60/200 dessous", true)
	COLLIDE = false
else
	section("off : compensation coupée, l'ancien comportement")
	holdRun(90, 0.2, "O90/200 au-dessus")
	holdRun(90, 0.1, "O90/100 au-dessus")
	catchRun(60, 0.2, "O60/200 dessous")
end
summary("scénario " .. A193_SCENARIO)
