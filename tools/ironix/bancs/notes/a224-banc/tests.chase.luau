-- a224 (vague 67) : le poursuivant ralentit en arrivant (Config/Chase.ApproachBrake, ApproachMinClosing ;
-- GuardService.approachCap). Collé après les aides de tests.luau d'a193 (run, speedFor, nextStore, FAR2, C, comp…).
-- Scénarios : still / stilloff (voleur qui s'arrête), run / runoff (voleur qui court, bien sous le minimum).
-- « …off » : ApproachBrake = 0, la règle d'avant a224 (mesures « avant »).
local OFF = A224_OFF == true
local TAG = if OFF then "avant" else "après"
if not OFF then
	check(ChaseCfg.ApproachBrake == 5 and ChaseCfg.ApproachMinClosing == 3, "0 Config/Chase : ApproachBrake 5, ApproachMinClosing 3")
end

-- Le voleur court à la marche `w` ; il s'arrête net quand le vigile est à `stopAt` studs (serveur, à plat). Relevé
-- image par image jusqu'à la capture : distance, vitesse réelle du vigile (déplacement / image), sa WalkSpeed.
local function still(w, stopAt, seconds)
	NET.oneWay = 0
	local P = thief(speedFor(w))
	advance(8)
	if heist(P, nextStore(), OUT) == nil then
		return nil
	end
	walk(P, FAR2)
	for _ = 1, 150 do
		if chaserOf(P) then
			break
		end
		advance(FRAME)
	end
	local model = chaserOf(P)
	if model == nil then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rec = { P = P, samples = {}, startT = now() }
	local last = root.Position
	local n = #CATCHES
	while now() - rec.startT < seconds do
		advance(FRAME)
		if model.Parent == nil or rootOf(P) == nil then
			break
		end
		local d = horizontal(rootOf(P).Position, root.Position)
		local v = horizontal(root.Position, last) / FRAME
		last = root.Position
		if #CATCHES > n then
			rec.caught = { t = now(), d = d }
			break
		end
		if rec.stopT == nil and d <= stopAt then
			stop(P)
			rec.stopT = now()
			rec.stopD = d
			rec.stopV = v
		end
		table.insert(rec.samples, { t = now(), d = d, v = v, ws = hum.WalkSpeed })
	end
	return rec
end

if A193_SCENARIO == "still" or A193_SCENARIO == "stilloff" then
	section(`{A193_SCENARIO} : voleur qui s'arrête ({TAG})`)
	for _, case in { { 30, ChaseCfg.HoldDistance + 0.5, "S1 arrêté à la fin de la ruée" }, { 30, 24, "S2 arrêté pendant la ruée (24 studs)" }, { 70, ChaseCfg.HoldDistance + 0.5, "S3 marche 70, arrêté à la fin de la ruée" }, { 70, 30, "S4 marche 70, arrêté pendant la ruée (30 studs)" } } do
		local w, stopAt, label = case[1], case[2], case[3]
		local rec = still(w, stopAt, 8)
		check(rec ~= nil and rec.stopT ~= nil, label .. " : braquage, poursuite, arrêt")
		check(rec ~= nil and rec.caught ~= nil, label .. " : toujours attrapé")
		if rec and rec.stopT and rec.caught then
			-- Temps des 10 derniers studs (d ≤ capture + 10) et vitesses réelles du vigile sur ce trajet.
			local enterT, enterV, rises, maxRise, lastV, nineV = nil, nil, 0, 0, nil, nil
			local prevV = nil
			for _, s in rec.samples do
				if s.t >= rec.stopT then
					if enterT == nil and s.d <= C + 10 then
						enterT, enterV = s.t, s.v
					end
					if nineV == nil and s.d <= C + 9 and s.t >= rec.stopT + 2 * FRAME - 1e-9 then -- pas l'image de l'arrêt net (WalkSpeed d'avant)
						nineV = s.v
					end
					if enterT and prevV then
						local rise = s.v - prevV
						if rise > 0.75 then
							rises += 1
							maxRise = math.max(maxRise, rise)
						end
					end
					if enterT then
						prevV = s.v
						lastV = s.v
					end
				end
			end
			local total = rec.caught.t - rec.stopT
			local final = if enterT then rec.caught.t - enterT else 0
			print(string.format("  mesure %s %s : arrêt à %.1f studs (vigile %.1f studs/s), capture %.2f s après l'arrêt ; 10 derniers studs en %.2f s, entrés à %s studs/s, dernier %s studs/s",
				TAG, label, rec.stopD, rec.stopV, total, final, fmt(enterV), fmt(lastV)))
			if not OFF then
				-- Arrêt pendant la ruée (le vrai cas : le voleur est déjà immobile quand le vigile arrive) : au moins ≈ 1,2 s ;
				-- arrêt net à 14 studs, vigile lancé à la marche du voleur : au moins 1 s (il ne freine pas en une image).
				local need = if stopAt > ChaseCfg.HoldDistance + 1 then 1.15 else 1
				check(final >= need, label .. string.format(" : les 10 derniers studs en au moins %.2f s (%.2f s)", need, final))
				check(final <= 2.5, label .. string.format(" : pas de capture qui traîne (%.2f s)", final))
				check(rises == 0, label .. string.format(" : vitesse décroissante sur les 10 derniers studs (%d hausse(s), au plus %.2f)", rises, maxRise))
				check(lastV ~= nil and lastV <= ChaseCfg.ApproachMinClosing + 1, label .. " : il arrive presque au pas (" .. fmt(lastV) .. " studs/s)")
				check(nineV ~= nil and nineV <= math.sqrt(2 * ChaseCfg.ApproachBrake * 10) + 1, label .. " : à 9 studs de la capture, au plus ≈ √(20 × frein) studs/s (" .. fmt(nineV) .. ")")
			end
		end
		finish(rec)
	end
else
	section(`{A193_SCENARIO} : voleur qui court, bien sous le minimum ({TAG})`)
	for _, w in { 30, 50, 70 } do
		for _, R in { 0, 0.1 } do
			local label = string.format("R%d/%d", w, R * 1000)
			local rec = run(w, R, 6)
			check(rec ~= nil and rec.caught ~= nil, label .. " : attrapé sous le minimum")
			if rec ~= nil and rec.caught ~= nil then
				local t = rec.caught.t - (rec.switchT or rec.startT)
				print(string.format("  mesure %s %s : marche %.1f, attrapé %.2f s après la fin de ruée", TAG, label, rec.caught.walk, t))
				check(t <= 3, label .. string.format(" : capture en moins de 3 s (%.2f s)", t))
			end
			finish(rec)
		end
	end
end
summary("scénario " .. A193_SCENARIO)
