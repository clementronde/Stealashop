---------------------------------------------------------------- a153 : aides communes
-- Le voleur sort du magasin en (150, 3, 0) et court tout droit vers +x (FAR) dès que le vigile apparaît ;
-- watch relève, image par image, la distance horizontale vigile-voleur (positions vues par le serveur), la
-- WalkSpeed du vigile et celle du voleur, la fin de la ruée (la WalkSpeed du vigile retombe) et la capture.
FAR = Vector3.new(720, 3, 0)
OUT = Vector3.new(150, 3, 0)
CATCHES = {}
local userCount = 0

function startBanc()
	startServer()
	ChaseCfg = sharedModule("Config/Chase")
	ZonesCfg = sharedModule("Config/Zones")
	Guard.OnCatch(function(player)
		table.insert(CATCHES, { player = player, t = now() })
	end)
end

function thief(speed)
	userCount += 1
	local profile = newProfile()
	profile.Stats.Strength = 10000
	profile.Stats.Speed = speed
	local player = join("Thief" .. userCount, profile)
	advance(0.5)
	return player
end

-- Le poursuivant de `player` : modèle, HumanoidRootPart, Humanoid.
function chaserOf(player)
	local folder = Workspace:FindFirstChild("ActiveGuards")
	for _, model in (if folder then folder:GetChildren() else {}) do
		if model:GetAttribute("TargetUserId") == player.UserId then
			local root = model:FindFirstChild("HumanoidRootPart")
			local hum = model:FindFirstChildOfClass("Humanoid")
			if root and hum then
				return model, root, hum
			end
		end
	end
	return nil, nil, nil
end

-- Braquage de `store`, sortie en OUT, course vers FAR dès que le vigile est là.
function heistAndRun(player, store)
	advance(8)
	local box = heist(player, store, OUT)
	if box == nil then
		return false
	end
	walk(player, FAR)
	for _ = 1, 150 do
		if chaserOf(player) then
			break
		end
		advance(FRAME)
	end
	return chaserOf(player) ~= nil
end

-- Relevé de la poursuite pendant `seconds` s au plus (arrêt à la capture).
function watch(player, seconds)
	local rec = { samples = {}, maxSpeed = 0, switchT = nil, switchD = nil, caughtT = nil, startT = now() }
	local n = #CATCHES
	while now() - rec.startT < seconds do
		advance(FRAME)
		if #CATCHES > n then
			rec.caughtT = now()
			break
		end
		local _, root, hum = chaserOf(player)
		local mine = rootOf(player)
		if root == nil or mine == nil then
			break
		end
		local d = horizontal(root.Position, mine.Position)
		local ws = hum.WalkSpeed
		if rec.switchT == nil and rec.maxSpeed >= ChaseCfg.RushMinSpeed - 0.01 and ws < rec.maxSpeed - 1 then
			rec.switchT = now()
			rec.switchD = d
		end
		rec.maxSpeed = math.max(rec.maxSpeed, ws)
		table.insert(rec.samples, { t = now(), d = d, ws = ws, walk = humanoidOf(player).WalkSpeed })
	end
	return rec
end

function sampleAt(rec, t)
	local best, gap = nil, math.huge
	for _, s in rec.samples do
		if math.abs(s.t - t) < gap then
			best, gap = s, math.abs(s.t - t)
		end
	end
	return best
end
function distanceAt(rec, t)
	local s = sampleAt(rec, t)
	return if s then s.d else nil
end
-- Écart max − min de la distance entre t1 et t2.
function spread(rec, t1, t2)
	local lo, hi = math.huge, -math.huge
	for _, s in rec.samples do
		if s.t >= t1 and s.t <= t2 then
			lo = math.min(lo, s.d)
			hi = math.max(hi, s.d)
		end
	end
	return hi - lo
end
function fmt(x)
	return if x == nil then "nil" else string.format("%.2f", x)
end
function report(label, rec)
	print("  mesure " .. label .. " : ruée max " .. fmt(rec.maxSpeed) .. ", fin de ruée à " .. fmt(rec.switchD)
		.. " studs (" .. fmt(rec.switchT and rec.switchT - rec.startT) .. " s), capture "
		.. fmt(rec.caughtT and rec.switchT and rec.caughtT - rec.switchT) .. " s après")
end
-- Fin d'une poursuite sans capture : le portage échoue, le vigile abandonne.
function endChase(player)
	stop(player)
	if Carry.IsCarrying(player) then
		Carry.Fail(player, "Test")
	end
	advance(1)
end
