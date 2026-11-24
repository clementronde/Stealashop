-- a249 (poursuite phase 2, Cantin 2026-11-17, L-235) : retour doux du vigile du magasin (Chase.SpringReturn,
-- SpringMaxFactor, SpringBrake), départ et reprise après la cinématique à Chase.StartDelay (WaitAfterReveal), une seule
-- capture à la fois (OneCatchAtATime), minimum de la zone 1 (Zone1SpeedRequired = 10). Collé après les aides de
-- tests.luau d'a193 (speedFor, nextStore, FAR2, C, finish…). Scénarios : voir run.sh. « …off » : mesure « avant ».
local S249 = A193_SCENARIO
local OFF249 = string.find(S249, "off", 1, true) ~= nil
local TAG249 = if OFF249 then "avant" else "après"

if not OFF249 and S249 ~= "below" then
	check(ChaseCfg.SpringReturn == true and ChaseCfg.SpringMaxFactor == 1.5 and ChaseCfg.SpringBrake == 20 * BalanceCfg.Stats.RealSpeedScale ^ 2,
		"0 Config/Chase : SpringReturn, SpringMaxFactor 1,5, SpringBrake 20 × k²")
	check(ChaseCfg.StartDelay == 1 and ChaseCfg.WaitAfterReveal == true and ChaseCfg.OneCatchAtATime == true and ChaseCfg.Debug == false,
		"0 Config/Chase : StartDelay 1, WaitAfterReveal, OneCatchAtATime, Debug éteint")
	check(ChaseCfg.Zone1SpeedRequired == 10, "0 Config/Chase : Zone1SpeedRequired 10")
	-- a249b (Cantin, 2026-11-18 : « plus vite de loin » ; Play de fusion68 : voleur coincé jamais attrapé, sortie lente)
	check(ChaseCfg.SpringFar == true and ChaseCfg.SpringFarFactor == 2.5 and ChaseCfg.SpringFarDistance == 40
		and ChaseCfg.SpringFarBrake == 40 * BalanceCfg.Stats.RealSpeedScale ^ 2,
		"0 Config/Chase : SpringFar, SpringFarFactor 2,5, SpringFarDistance 40, SpringFarBrake 40 × k²")
	check(ChaseCfg.StuckCatch == true and ChaseCfg.StuckCatchTime == 0.3 and ChaseCfg.StuckMoveMax == 1 and ChaseCfg.PathLookahead == 8,
		"0 Config/Chase : StuckCatch, StuckCatchTime 0,3, StuckMoveMax 1, PathLookahead 8")
	check(ChaseCfg.StuckWallMax == 0.75 and ChaseCfg.StuckHeightMax == 3,
		"0 Config/Chase : StuckWallMax 0,75, StuckHeightMax 3")
end
-- a249b : plus forte baisse de WalkSpeed permise (studs/s²) : freinage de loin (SpringFarBrake) ou de près (SpringBrake).
local BRAKE249 = math.max(2 * ChaseCfg.SpringBrake, 1.25 * (ChaseCfg.SpringFarBrake or 0))

-- Un voleur de Speed `speed` braque, ressort en OUT et court vers FAR2 ; son poursuivant (modèle) ou nil.
local function start249(speed)
	NET.oneWay = 0
	local P = thief(speed)
	advance(8)
	if heist(P, nextStore(), OUT) == nil then
		return P, nil
	end
	walk(P, FAR2)
	local model = chaserOf(P)
	for _ = 1, 150 do
		if model then
			break
		end
		advance(FRAME)
		model = chaserOf(P)
	end
	return P, model
end

-- Relevé image par image (positions vues par le serveur) jusqu'à `seconds` s ou la capture : distance à plat, WalkSpeed
-- du vigile, marche du voleur, déplacement du vigile. `onFrame(t)` avant chaque image (t depuis le début).
local function follow249(P, model, seconds, onFrame)
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rec = { P = P, samples = {}, startT = now(), maxWs = 0, n = #CATCHES }
	local last = root.Position
	while now() - rec.startT < seconds do
		if onFrame then
			onFrame(now() - rec.startT)
		end
		advance(FRAME)
		if model.Parent == nil or rootOf(P) == nil then
			rec.gone = true
			break
		end
		local s = {
			t = now() - rec.startT,
			d = horizontal(rootOf(P).Position, root.Position),
			ws = hum.WalkSpeed,
			walk = humanoidOf(P).WalkSpeed,
			moved = horizontal(root.Position, last),
		}
		last = root.Position
		if #CATCHES > rec.n then
			rec.caught = s
			break
		end
		rec.maxWs = math.max(rec.maxWs, s.ws)
		table.insert(rec.samples, s)
	end
	return rec
end

-- Première image où la distance passe sous `limit` à partir de `from` s ; min et max de la distance ensuite.
local function arrival(rec, limit, from, settleAfter)
	local at = nil
	local lo, hi = math.huge, -math.huge
	for _, s in rec.samples do
		if at == nil and s.t >= (from or 0) and s.d <= limit then
			at = s.t
		end
		if at and s.t >= at then
			lo = math.min(lo, s.d)
			if s.t >= at + (settleAfter or 0) then
				hi = math.max(hi, s.d)
			end
		end
	end
	return at, lo, hi
end

-- Plus forte baisse de WalkSpeed du vigile, en studs/s².
local function maxDrop(rec, from)
	local worst = 0
	for i = 2, #rec.samples do
		local a, b = rec.samples[i - 1], rec.samples[i]
		if b.t >= (from or 0) then
			worst = math.max(worst, (a.ws - b.ws) / FRAME)
		end
	end
	return worst
end

if S249 == "spring" or S249 == "springoff" then
	DECEL = 700 -- élan du Humanoid mesuré en Play (a249) : il ne freine qu'à ≈ 700 studs/s²
	section(`{S249} : voleur au-dessus du minimum ({TAG249})`)
	for _, w in { 20, 30, 40 } do
		local P, model = start249(speedFor(w))
		local label = string.format("R%d", w)
		check(model ~= nil, label .. " : braquage, vigile apparu")
		if model then
			local rec = follow249(P, model, 9)
			local W = if rec.samples[1] then rec.samples[1].walk else humanoidOf(P).WalkSpeed
			local at, lo, hi = arrival(rec, ChaseCfg.HoldDistance + 1, 0, 1)
			local drop = maxDrop(rec, 0.1)
			print(string.format("  mesure %s %s : marche %.1f, vigile au plus %.1f (%.2f × la marche), à 15 studs en %s s, ensuite %s à %s studs, plus forte baisse %.0f studs/s², capture %s",
				TAG249, label, W, rec.maxWs, rec.maxWs / math.max(W, 1e-6), fmt(at), fmt(lo), fmt(hi), drop, tostring(rec.caught ~= nil)))
			if OFF249 then
				check(rec.maxWs >= ChaseCfg.RushMinSpeed - 0.01, label .. " : avant, la ruée (" .. fmt(rec.maxWs) .. ")")
			else
				check(rec.caught == nil, label .. " : pas de capture au-dessus du minimum")
				check(rec.maxWs <= ChaseCfg.SpringFarFactor * W + 0.5, label .. string.format(" : au plus %.1f × la marche (%.2f)", ChaseCfg.SpringFarFactor, rec.maxWs / W))
				-- a249b : près de la distance gardée (≤ 16 studs), jamais plus que SpringMaxFactor × la marche.
				local nearMax = 0
				for _, s in rec.samples do
					if s.d <= ChaseCfg.HoldDistance + 2 then
						nearMax = math.max(nearMax, s.ws)
					end
				end
				check(nearMax <= ChaseCfg.SpringMaxFactor * W + 0.5, label .. string.format(" : à 16 studs ou moins, au plus %.1f × la marche (%.2f)", ChaseCfg.SpringMaxFactor, nearMax / W))
				-- Au plus : départ du vigile + l'écart à son départ couvert à (SpringMaxFactor − 1) × la marche + 1,5 s de freinage.
				local t0, d0 = 0, 0
				for _, s in rec.samples do
					if s.moved > 0.05 then
						t0, d0 = s.t, s.d
						break
					end
				end
				local bound = t0 + math.max(d0 - ChaseCfg.HoldDistance - 1, 0) / ((ChaseCfg.SpringMaxFactor - 1) * W) + 1.5
				check(at ~= nil and at <= bound, label .. string.format(" : revenu à 15 studs en %s s (au plus %.2f, parti à %.2f s à %.0f studs)", fmt(at), bound, t0, d0))
				check(lo >= ChaseCfg.HoldDistance - 1, label .. " : pas de dépassement, jamais sous 13 studs (" .. fmt(lo) .. ")")
				check(hi <= ChaseCfg.HoldDistance + 1.5, label .. " : garde la distance, au plus 15,5 studs (" .. fmt(hi) .. ")")
				check(drop <= math.max(2 * W, BRAKE249), label .. string.format(" : freinage doux, au plus %.0f studs/s² (%.0f)", math.max(2 * W, BRAKE249), drop))
			end
			finish(rec)
		end
	end
	DECEL = nil
elseif S249 == "letsgo" then
	DECEL = 700
	section("letsgo : le voleur prend 40 studs d'avance, le vigile revient")
	local P, model = start249(speedFor(30))
	check(model ~= nil, "L1 braquage, vigile apparu")
	if model then
		local jumped = false
		local rec = follow249(P, model, 12, function(t)
			if not jumped and t >= 6 then
				jumped = true
				local pos = rootOf(P).Position
				place(P, pos + Vector3.new(40, 0, 0))
				walk(P, FAR2)
			end
		end)
		local W = if rec.samples[1] then rec.samples[1].walk else humanoidOf(P).WalkSpeed
		local far, back, lo, maxAfter = 0, nil, math.huge, 0
		for _, s in rec.samples do
			if s.t >= 6 then
				far = math.max(far, s.d)
				maxAfter = math.max(maxAfter, s.ws)
				if back == nil and s.t > 6.1 and s.d <= ChaseCfg.HoldDistance + 1.5 then
					back = s.t - 6
				end
				if back then
					lo = math.min(lo, s.d)
				end
			end
		end
		print(string.format("  mesure letsgo : marche %.1f, écart après le saut %.1f studs, revenu à 15,5 studs en %s s, vigile au plus %.1f (%.2f × la marche), ensuite au plus près %s",
			W, far, fmt(back), maxAfter, maxAfter / math.max(W, 1e-6), fmt(lo)))
		check(far >= ChaseCfg.HoldDistance + 30, "L2 le voleur a bien pris de l'avance (" .. fmt(far) .. " studs)")
		check(rec.caught == nil, "L3 pas de capture")
		check(back ~= nil and back <= 2.5, "L4 le vigile revient à 15,5 studs en moins de 2,5 s (" .. fmt(back) .. ")")
		check(maxAfter <= ChaseCfg.SpringFarFactor * W + 0.5, "L5 au plus 2,5 × la marche pour revenir (" .. fmt(maxAfter) .. ")")
		check(lo >= ChaseCfg.HoldDistance - 1, "L6 pas de dépassement en revenant (" .. fmt(lo) .. ")")
		check(chaserOf(P) ~= nil and Guard.IsChased(P), "L7 il ne lâche pas prise")
		finish(rec)
	end
	DECEL = nil
elseif S249 == "arret" then
	DECEL = 700
	section("arret : le voleur au-dessus du minimum s'arrête, il est attrapé (comme avant a249)")
	local P, model = start249(speedFor(30))
	check(model ~= nil, "A1 braquage, vigile apparu")
	if model then
		local stopped = false
		local rec = follow249(P, model, 14, function(t)
			if not stopped and t >= 7 then
				stopped = true
				stop(P)
			end
		end)
		local before = math.huge
		for _, s in rec.samples do
			if s.t < 7 then
				before = math.min(before, s.d)
			end
		end
		print(string.format("  mesure arret : au plus près %.2f studs avant l'arrêt, capture %s s après l'arrêt",
			before, fmt(rec.caught and rec.caught.t - 7)))
		check(before >= ChaseCfg.HoldDistance - 1, "A2 pas de capture ni de dépassement avant l'arrêt (" .. fmt(before) .. ")")
		check(rec.caught ~= nil and rec.caught.t > 7 and rec.caught.t - 7 <= 5, "A3 arrêté, il est attrapé en moins de 5 s (" .. fmt(rec.caught and rec.caught.t - 7) .. ")")
		finish(rec)
	end
	DECEL = nil
elseif S249 == "below" then
	DECEL = 700
	section("below : voleur sous le minimum (Zone1SpeedRequired 1e30), toujours attrapé")
	for _, w in { 20, 30 } do
		local P, model = start249(speedFor(w))
		local label = string.format("B%d", w)
		check(model ~= nil, label .. " : braquage, vigile apparu")
		if model then
			local rec = follow249(P, model, 10)
			local W = if rec.samples[1] then rec.samples[1].walk else 0
			print(string.format("  mesure below %s : marche %.1f, vigile au plus %.1f, capture %s s après l'apparition, à %s studs",
				label, W, rec.maxWs, fmt(rec.caught and rec.caught.t), fmt(rec.caught and rec.caught.d)))
			check(rec.caught ~= nil and rec.caught.t <= 8, label .. " : attrapé en moins de 8 s (" .. fmt(rec.caught and rec.caught.t) .. ")")
			check(rec.maxWs <= ChaseCfg.SpringFarFactor * W + ChaseCfg.ClosingSpeedMax + 0.5, label .. " : au plus 2,5 × la marche + le rapprochement (" .. fmt(rec.maxWs) .. ")")
			finish(rec)
		end
	end
	DECEL = nil
elseif S249 == "zone1" then
	section("zone1 : minimum de la zone 1 = 10 (Speed du tutoriel)")
	for _, case in { { 0, true, "Z0 Speed 0" }, { 10, false, "Z10 Speed 10 (au minimum)" }, { speedFor(30), false, "Z30 Speed haute" } } do
		local P, model = start249(case[1])
		check(model ~= nil, case[3] .. " : braquage, vigile apparu")
		if model then
			local rec = follow249(P, model, 10)
			print(string.format("  mesure zone1 %s : marche %.1f, capture %s s après l'apparition", case[3], if rec.samples[1] then rec.samples[1].walk else 0, fmt(rec.caught and rec.caught.t)))
			if case[2] then
				check(rec.caught ~= nil, case[3] .. " : attrapé en zone 1")
			else
				check(rec.caught == nil, case[3] .. " : pas attrapé en 10 s")
			end
			finish(rec)
		end
	end
elseif S249 == "depart" or S249 == "departoff" then
	local delay = if OFF249 then 0.5 else 1
	section(`{S249} : départ du vigile {delay} s après la prise ({TAG249})`)
	for _, w in { 20, 30 } do
		local P = thief(speedFor(w))
		advance(8)
		local payload = heist(P, nextStore(), OUT) -- le vigile apparaît à la prise
		local t0 = now()
		local model, root = chaserOf(P)
		local label = string.format("D%d", w)
		check(payload ~= nil and model ~= nil, label .. " : braquage, vigile apparu à la prise")
		if model then
			walk(P, FAR2)
			local p0 = root.Position
			local movedAt = nil
			while now() - t0 < 2.5 and movedAt == nil do
				advance(FRAME)
				if model.Parent == nil then
					break
				end
				if horizontal(root.Position, p0) > 0.05 then
					movedAt = now() - t0
				end
			end
			print(string.format("  mesure %s %s : le vigile bouge %s s après la prise", TAG249, label, fmt(movedAt)))
			check(movedAt ~= nil and movedAt >= delay - 0.05, label .. string.format(" : immobile pendant %.1f s (%s)", delay - 0.05, fmt(movedAt)))
			check(movedAt ~= nil and movedAt <= delay + 0.25, label .. string.format(" : parti avant %.2f s (%s)", delay + 0.25, fmt(movedAt)))
			endChase(P)
			advance(3)
		end
	end
elseif S249 == "reprise" or S249 == "repriseoff" then
	section(`{S249} : reprise après la cinématique d'ouverture ({TAG249})`)
	local P, model = start249(speedFor(30))
	check(model ~= nil, "C1 braquage, vigile apparu")
	if model then
		local root = model:FindFirstChild("HumanoidRootPart")
		advance(3)
		P:SetAttribute("RevealProtected", true)
		stop(P)
		advance(0.2)
		local frozenAt = root.Position
		advance(1.8)
		local frozenMove = horizontal(root.Position, frozenAt)
		P:SetAttribute("RevealProtected", false)
		walk(P, FAR2)
		local t0 = now()
		local p0 = root.Position
		local n = #CATCHES
		local movedAt = nil
		while now() - t0 < 2.5 and movedAt == nil do
			advance(FRAME)
			if horizontal(root.Position, p0) > 0.05 then
				movedAt = now() - t0
			end
		end
		print(string.format("  mesure %s : figé %.2f studs pendant la cinématique, repart %s s après sa fin", TAG249, frozenMove, fmt(movedAt)))
		check(frozenMove < 0.2, "C2 figé pendant la cinématique (" .. fmt(frozenMove) .. " studs)")
		if OFF249 then
			check(movedAt ~= nil and movedAt <= 0.2, "C3 avant : il repartait tout de suite (" .. fmt(movedAt) .. ")")
		else
			check(movedAt ~= nil and movedAt >= ChaseCfg.StartDelay - 0.05, "C3 immobile 1 s après la fin de la cinématique (" .. fmt(movedAt) .. ")")
			check(movedAt ~= nil and movedAt <= ChaseCfg.StartDelay + 0.25, "C4 puis il repart (" .. fmt(movedAt) .. ")")
		end
		check(#CATCHES == n, "C5 pas de capture à la reprise")
		check(chaserOf(P) ~= nil, "C6 toujours poursuivi")
		endChase(P)
		advance(3)
	end
elseif S249 == "double" or S249 == "doubleoff" then
	section(`{S249} : vigile d'intrus et policier, une seule capture ({TAG249})`)
	local template = make("Model", { Name = "Chaser_Test249" }, ReplicatedStorage)
	local troot = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, template)
	template.PrimaryPart = troot
	local thum = make("Humanoid", { Name = "Humanoid", RootPart = troot, HipHeight = 2 }, template)
	make("Animator", { Name = "Animator" }, thum)
	local P = thief(speedFor(30))
	advance(8)
	place(P, OUT)
	walk(P, FAR2)
	check(Guard.ChaseIntruder(P, STORE_A), "X1 vigile d'intrus lancé")
	local day = chaserOf(P)
	local near14 = false
	for _ = 1, 600 do
		advance(FRAME)
		local _, root = chaserOf(P)
		if root and rootOf(P) and horizontal(root.Position, rootOf(P).Position) <= ChaseCfg.HoldDistance + 2 then
			near14 = true
			break
		end
	end
	check(near14, "X2 le vigile d'intrus suit à ≈ 14 studs")
	local at = rootOf(P).Position
	local police = Guard.StartDriverChase({
		Template = template,
		Name = "Police_Test249",
		Target = P,
		Spawn = CFrame.new(at.X - 20, 0, at.Z + 6),
		Zone = 1,
		SpeedMultiplier = 0,
		MinSpeed = 20,
		Keeps = function()
			return true
		end,
		Label = "policier",
		Tired = true,
		GiveUpReason = "test",
	})
	check(police ~= nil, "X3 policier lancé")
	local n = #CATCHES
	local firstT = nil
	local t0 = now()
	while now() - t0 < 8 and firstT == nil do
		advance(FRAME)
		if #CATCHES > n then
			firstT = now()
		end
	end
	check(firstT ~= nil, "X4 une première capture")
	-- Le joueur attrapé reste sur place (comme la nuit, figé jusqu'au renvoi) : l'autre poursuivant arrive-t-il sur lui ?
	stop(P)
	local dayAfter = nil
	if firstT then
		while now() - firstT < 8 do
			advance(FRAME)
			if dayAfter == nil and now() - firstT >= 0.3 then
				dayAfter = Guard.IsChased(P)
			end
		end
	end
	local count = #CATCHES - n
	print(string.format("  mesure %s : %d capture(s) en 8 s après la première ; vigile d'intrus encore sur lui 0,3 s après : %s",
		TAG249, count, tostring(dayAfter)))
	if OFF249 then
		check(count >= 2, "X5 avant : la double capture se reproduit (" .. count .. ")")
	else
		check(count == 1, "X5 une seule capture (" .. count .. ")")
		check(dayAfter == false, "X6 le vigile d'intrus abandonne le joueur déjà attrapé")
	end
	stop(P)
	advance(6)
	local _ = day
elseif S249 == "coince" or S249 == "coinceoff" then
	-- a249b (Play de fusion68, Supérette) : le voleur pousse contre un obstacle sans avancer (le client marche vers FAR2,
	-- remis chaque image au même point) ; un mur mince (0,3 stud) entre lui et le vigile coupe chaque rayon de CanTouch,
	-- et le vigile ne peut pas le traverser (bloqué à 1,2 stud du mur). Deux cas : vitesse lue sur le serveur nulle (un
	-- personnage bloqué par un mur, en vrai) ; vitesse lue = sa marche (le pire cas : la vitesse voulue). Kc (banc a146,
	-- « jamais à travers un mur ») : un mur de 1 stud (plus de StuckWallMax), le vigile bloqué contre lui : jamais.
	-- Kd : le mur mince, mais le vigile passe derrière lui à 10 studs/s (il n'est pas bloqué) : jamais pendant ce passage.
	DECEL = 700
	section(`{S249} : voleur coincé, un mur mince entre lui et le vigile ({TAG249})`)
	for _, case in { { "Ka", false, "vitesse lue nulle", 0.3 }, { "Kb", true, "vitesse lue = sa marche", 0.3 },
		{ "Kc", false, "mur de 1 stud", 1 }, { "Kd", false, "le vigile passe derrière le mur", 0.3, true } } do
		local label, pushing, thick, sweep = case[1], case[2], case[4], case[5] == true
		local limit = if sweep then 1.6 else 8
		local P, model = start249(speedFor(30))
		check(model ~= nil, label .. " : braquage, vigile apparu")
		if model then
			advance(5)
			local root = model:FindFirstChild("HumanoidRootPart")
			local spot = rootOf(P).Position
			local wallX = spot.X - 1
			local wall = make("Part", { Name = "Shelf_Test249", Anchored = true, Size = Vector3.new(thick, 12, 40), CFrame = CFrame.new(wallX, 5, spot.Z) }, Workspace)
			local c = clientOf(P)
			local base = BEFORE_FRAME
			local stopX = wallX - thick / 2 - 1.05 -- le vigile bute contre le mur (0,3 stud : à 1,2 stud de son milieu)
			local blockedAt = nil
			local sweepFrom = now()
			BEFORE_FRAME = function(dt)
				c.pos = Vector3.new(spot.X, c.pos.Y, spot.Z)
				base(dt)
				if not pushing then
					rootOf(P).AssemblyLinearVelocity = Vector3.zero
				end
				local p = root.Position
				if sweep then
					root.CFrame = CFrame.new(stopX, p.Y, spot.Z - 8 + 10 * (now() - sweepFrom)) * root.CFrame.Rotation
				elseif p.X > stopX then
					root.CFrame = CFrame.new(stopX, p.Y, p.Z) * root.CFrame.Rotation
					blockedAt = blockedAt or now()
				end
			end
			local t0 = now()
			local n = #CATCHES
			local caughtAt, inRangeAt, closest, maxVel = nil, nil, math.huge, 0
			while now() - t0 < limit and caughtAt == nil do
				advance(FRAME)
				local d = horizontal(rootOf(P).Position, root.Position)
				closest = math.min(closest, d)
				local v = rootOf(P).AssemblyLinearVelocity
				maxVel = math.max(maxVel, Vector3.new(v.X, 0, v.Z).Magnitude)
				if inRangeAt == nil and d <= C then
					inRangeAt = now() - t0
				end
				if #CATCHES > n then
					caughtAt = now() - t0
				end
			end
			BEFORE_FRAME = base
			wall:Destroy()
			local stoppedAt = blockedAt and blockedAt - t0
			print(string.format("  mesure %s %s (%s) : vigile au plus près %.2f studs (à portée %s s, contre le mur %s s après le blocage), vitesse lue du voleur au plus %.1f studs/s, capture %s s après le blocage",
				TAG249, label, case[3], closest, fmt(inRangeAt), fmt(stoppedAt), maxVel, fmt(caughtAt)))
			check(closest <= C, label .. " : le vigile est à portée, derrière le mur (" .. fmt(closest) .. " studs)")
			if OFF249 then
				check(caughtAt == nil, label .. " : avant, jamais attrapé en " .. limit .. " s (" .. fmt(caughtAt) .. ")")
			elseif sweep then
				check(caughtAt == nil, label .. " : jamais attrapé par un vigile qui passe (" .. fmt(caughtAt) .. ")")
			elseif thick > ChaseCfg.StuckWallMax then
				check(stoppedAt ~= nil, label .. " : le vigile bute contre le mur")
				check(caughtAt == nil, label .. " : jamais attrapé à travers un mur de " .. thick .. " stud en 8 s (" .. fmt(caughtAt) .. ")")
			else
				if pushing then
					check(caughtAt ~= nil and caughtAt <= 2.5, label .. " : attrapé en au plus 2,5 s (" .. fmt(caughtAt) .. ")")
				else
					check(caughtAt ~= nil and caughtAt >= 1 and caughtAt <= 2.5, label .. " : attrapé en 1 à 2,5 s, comme un voleur arrêté (" .. fmt(caughtAt) .. ")")
				end
				local ready = inRangeAt and (if stoppedAt then math.max(inRangeAt, stoppedAt) else inRangeAt)
				check(caughtAt ~= nil and ready ~= nil and caughtAt - ready <= ChaseCfg.StuckCatchTime + 0.2,
					label .. " : au plus StuckCatchTime + 0,2 s après être à portée (et contre le mur, s'il y bute) (" .. fmt(caughtAt and ready and caughtAt - ready) .. ")")
			end
			finish({ P = P, caught = caughtAt })
		end
	end
	DECEL = nil
elseif S249 == "loin" or S249 == "loinoff" then
	-- a249b (Cantin, 2026-11-18 : « plus vite de loin ») : voleur rapide, 150 studs d'avance d'un coup (le vigile sorti
	-- tard du magasin) ; le vigile revient jusqu'à SpringFarFactor × la marche, redescend en douceur à SpringMaxFactor ×
	-- près du voleur, sans dépassement ni capture. « off » : SpringFar = false (au plus SpringMaxFactor × la marche).
	DECEL = 700
	section(`{S249} : voleur rapide, 150 studs d'avance, le vigile revient de loin ({TAG249})`)
	local P, model = start249(speedFor(76 / 1.8)) -- marche ≈ 76 avec l'objet (profil rapide de Cantin)
	check(model ~= nil, "F1 braquage, vigile apparu")
	if model then
		local jumped = false
		local rec = follow249(P, model, 11, function(t)
			if not jumped and t >= 5 then
				jumped = true
				place(P, rootOf(P).Position + Vector3.new(150, 0, 0))
				walk(P, FAR2)
			end
		end)
		local W = if rec.samples[1] then rec.samples[1].walk else humanoidOf(P).WalkSpeed
		local far, back, lo, maxAfter, nearMax = 0, nil, math.huge, 0, 0
		local worst, prev = 0, nil
		for _, s in rec.samples do
			if s.t >= 5 then
				far = math.max(far, s.d)
				maxAfter = math.max(maxAfter, s.ws)
				if back == nil and s.t > 5.1 and s.d <= ChaseCfg.HoldDistance + 1.5 then
					back = s.t - 5
				end
				if back then
					lo = math.min(lo, s.d)
				end
				if s.t > 5.1 and s.d <= ChaseCfg.HoldDistance + 2 then
					nearMax = math.max(nearMax, s.ws)
				end
				if prev and s.t > 5.1 then
					worst = math.max(worst, (prev.ws - s.ws) / FRAME)
				end
				prev = s
			end
		end
		print(string.format("  mesure %s loin : marche %.1f, écart après le saut %.1f studs, revenu à 15,5 studs en %s s, vigile au plus %.1f (%.2f × la marche), à 16 studs ou moins au plus %.1f (%.2f ×), plus forte baisse %.0f studs/s², ensuite au plus près %s",
			TAG249, W, far, fmt(back), maxAfter, maxAfter / math.max(W, 1e-6), nearMax, nearMax / math.max(W, 1e-6), worst, fmt(lo)))
		check(W >= 70, "F2 voleur rapide (marche " .. fmt(W) .. ")")
		check(far >= ChaseCfg.HoldDistance + 140, "F3 le voleur a bien pris de l'avance (" .. fmt(far) .. " studs)")
		check(rec.caught == nil, "F4 pas de capture")
		check(chaserOf(P) ~= nil and Guard.IsChased(P), "F5 il ne lâche pas prise")
		check(lo >= ChaseCfg.HoldDistance - 1, "F6 pas de dépassement en revenant (" .. fmt(lo) .. ")")
		if OFF249 then
			check(maxAfter <= ChaseCfg.SpringMaxFactor * W + 0.5, "F7 avant : au plus 1,5 × la marche (" .. fmt(maxAfter) .. ")")
			check(back ~= nil and back >= 3.5, "F8 avant : plus de 3,5 s pour revenir (" .. fmt(back) .. ")")
		else
			check(maxAfter >= 2.4 * W and maxAfter <= ChaseCfg.SpringFarFactor * W + 0.5, "F7 de loin, ≈ 2,5 × la marche (" .. fmt(maxAfter / math.max(W, 1e-6)) .. " ×)")
			check(nearMax <= ChaseCfg.SpringMaxFactor * W + 0.5, "F8 près (≤ 16 studs), au plus 1,5 × la marche (" .. fmt(nearMax / math.max(W, 1e-6)) .. " ×)")
			check(back ~= nil and back <= 3, "F9 revenu à 15,5 studs en au plus 3 s (" .. fmt(back) .. ")")
			check(worst <= BRAKE249, string.format("F10 redescente douce, au plus %.0f studs/s² (%.0f)", BRAKE249, worst))
		end
		finish(rec)
	end
	DECEL = nil
end
summary("scénario " .. S249)
