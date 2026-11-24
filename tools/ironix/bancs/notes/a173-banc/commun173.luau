---------------------------------------------------------------- a173 : images de durée variable, élan du Humanoid
-- (lu après commun.luau d'a168). Play de fusion48 : la fin de ruée tombait vers 7,5 studs (image plus longue que
-- la précédente ; le vigile courait encore à ≈ 42 studs/s l'image d'après, WalkSpeed déjà à 33).
JITTER = nil -- suite de facteurs appliqués à FRAME, image par image (nil : images égales)
DECEL = nil -- studs/s² : la vitesse réelle d'un vigile ne baisse que de DECEL × dt par image (nil : sans élan)
local jitterAt = 0
function nextFrame()
	if JITTER == nil then
		return FRAME
	end
	jitterAt = jitterAt % #JITTER + 1
	return FRAME * JITTER[jitterAt]
end
local realSpeed = {}
local baseBefore = BEFORE_FRAME
FREEZE = false -- gel du serveur : l image passe sans que rien ne bouge (physique arrêtée aussi)
BEFORE_FRAME = function(dt)
	if FREEZE then
		return
	end
	if DECEL == nil then
		table.clear(realSpeed)
		return baseBefore(dt)
	end
	-- Le mouvement simulé lit Humanoid.WalkSpeed : on lui donne la vitesse réelle le temps du pas, puis on remet
	-- la WalkSpeed que le service a posée.
	local swapped = {}
	local active = Workspace:FindFirstChild("ActiveGuards")
	for _, model in (if active then active:GetChildren() else {}) do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			local ws = hum.WalkSpeed
			local v = realSpeed[hum] or ws
			v = if ws >= v then ws else math.max(ws, v - DECEL * dt)
			realSpeed[hum] = v
			if math.abs(v - ws) > 1e-6 then
				swapped[hum] = ws
				hum.WalkSpeed = v
			end
		end
	end
	baseBefore(dt)
	for hum, ws in swapped do
		hum.WalkSpeed = ws
	end
end

-- watch d'a168, une image à la fois de durée nextFrame() ; garde aussi la dernière distance avant la capture
-- (lastD : un autre poursuivant a-t-il attrapé ?).
function watch(player, seconds)
	local rec = { samples = {}, maxSpeed = 0, switchT = nil, switchD = nil, caughtT = nil, lastD = nil, startT = now() }
	local n = #CATCHES
	while now() - rec.startT < seconds do
		local f = nextFrame()
		advance(f, f)
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
		if rec.switchT == nil and rec.maxSpeed >= ChaseCfg.RushMinSpeed - 0.01 and ws <= math.max(humanoidOf(player).WalkSpeed + ChaseCfg.ClosingSpeedMax + ChaseCfg.HoldRecallMax, ChaseCfg.HoldMinSpeed) + 0.5 then
			rec.switchT = now()
			rec.switchD = d
		end
		rec.maxSpeed = math.max(rec.maxSpeed, ws)
		rec.lastD = d
		table.insert(rec.samples, { t = now(), d = d, ws = ws, walk = humanoidOf(player).WalkSpeed })
	end
	return rec
end

-- Distance la plus basse et la plus haute entre t1 et t2.
function rangeIn(rec, t1, t2)
	local lo, hi, count = math.huge, -math.huge, 0
	for _, s in rec.samples do
		if s.t >= t1 and s.t <= t2 then
			lo = math.min(lo, s.d)
			hi = math.max(hi, s.d)
			count += 1
		end
	end
	return lo, hi, count
end
