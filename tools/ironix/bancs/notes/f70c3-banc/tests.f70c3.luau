-- f70c3 (Play de diagnostic de fusion70, A4 et A5 ; f70c3b : Play de rejeu de fusion71, A4 et T-217) : collé après les
-- aides de tests.a249.luau (start249…), elles-mêmes après celles de tests.luau d'a193. Scénarios : voir run.sh.
-- « …off » : mesure « avant ».
local PA = ChaseCfg.PathAvoid
local SS = ChaseCfg.Sidestep
local GS = serverModule("GuardService")
local Avoid = GS._PathAvoid
local Side = GS._Sidestep
check(type(PA) == "table" and Avoid ~= nil, "0 Config/Chase.PathAvoid et Guard/PathAvoid chargés par GuardService")
check(type(SS) == "table" and Side ~= nil, "0 Config/Chase.Sidestep et Guard/Sidestep chargés par GuardService")
local POLE = S249 == "poteau" or S249 == "poteauoff"
if S249 == "promo" then
	check(PA.Enabled == true and PA.Prefixes[1] == "Promo_" and #PA.Prefixes == 1 and PA.Label == "GuardAvoid" and PA.Cost == math.huge
		and PA.Headroom == 4 and PA.JumpNear == 3 and PA.JumpMargin == 2 and PA.JumpMin == 3,
		"0 Config/Chase.PathAvoid : Enabled, Prefixes { Promo_ }, Label GuardAvoid, Cost math.huge, Headroom 4, JumpNear 3, JumpMargin 2, JumpMin 3")
	check(SS.Enabled == true and SS.ThinMax == 3 and SS.Beyond == 1.5 and SS.ShiftStep == 0.5 and SS.ShiftMax == 4,
		"0 Config/Chase.Sidestep : Enabled, ThinMax 3, Beyond 1,5, ShiftStep 0,5, ShiftMax 4")

	section("promo : BeforeJump, saut à la hauteur de la marche (pur)")
	-- Pieds du vigile à y = 3. Point de saut sur la marche (comme Roblox), point suivant au-delà ; « bas » : point de saut
	-- au pied et point suivant sur la marche.
	local function wps(rise, low)
		if low then
			return { { Position = Vector3.new(0, 3, 0) }, { Position = Vector3.new(2, 3 + rise, 0) } }
		end
		return { { Position = Vector3.new(1, 3 + rise, 0) }, { Position = Vector3.new(4, 3, 0) } }
	end
	local function jumpFor(props, rise, low)
		local h = make("Humanoid", props)
		local ok = Avoid.BeforeJump(h, wps(rise, low), 1, 3)
		return h, ok
	end
	local h1, ok1 = jumpFor({ UseJumpPower = false, JumpHeight = 7.2 }, 2.2)
	check(math.abs(h1.JumpHeight - 4.2) < 1e-6 and h1.UseJumpPower == false and ok1 == true,
		"U1 marche 2,2 : saut 4,2, permis (" .. fmt(h1.JumpHeight) .. ", " .. tostring(ok1) .. ")")
	local h1b = jumpFor({ UseJumpPower = false, JumpHeight = 7.2 }, 2.2, true)
	check(math.abs(h1b.JumpHeight - 4.2) < 1e-6, "U1b point de saut au pied, suivant sur la marche : 4,2 aussi (" .. fmt(h1b.JumpHeight) .. ")")
	local h2 = jumpFor({ UseJumpPower = false, JumpHeight = 7.2 }, 10)
	check(math.abs(h2.JumpHeight - 7.2) < 1e-6, "U2 marche 10 : jamais plus que le saut du rig, 7,2 (" .. fmt(h2.JumpHeight) .. ")")
	local h3 = jumpFor({ UseJumpPower = false, JumpHeight = 7.2 }, 0.4)
	check(math.abs(h3.JumpHeight - 3) < 1e-6, "U3 marche 0,4 : au moins JumpMin, 3 (" .. fmt(h3.JumpHeight) .. ")")
	local h4 = jumpFor({ UseJumpPower = false, JumpHeight = 7.2 }, -3)
	check(math.abs(h4.JumpHeight - 7.2) < 1e-6, "U4 descente : saut du rig (" .. fmt(h4.JumpHeight) .. ")")
	local h5 = jumpFor({ UseJumpPower = true, JumpPower = 50 }, 10)
	local rig5 = 50 * 50 / (2 * Workspace.Gravity)
	check(math.abs(h5.JumpHeight - rig5) < 1e-6 and h5.UseJumpPower == false,
		"U5 rig en JumpPower 50 : plafond " .. fmt(rig5) .. ", UseJumpPower coupé (" .. fmt(h5.JumpHeight) .. ")")
	-- Le saut du rig est lu une fois : un second saut plus haut ne part pas de la valeur déjà baissée.
	Avoid.BeforeJump(h1, wps(10), 1, 3)
	check(math.abs(h1.JumpHeight - 7.2) < 1e-6, "U6 second saut du même vigile : plafond du rig d'origine (" .. fmt(h1.JumpHeight) .. ")")
	local h7 = jumpFor({ UseJumpPower = false, JumpHeight = 7.2 }, 2.2)
	Avoid.BeforeJump(h7, { { Position = Vector3.new(0, 3, 0) } }, 1, 3)
	check(math.abs(h7.JumpHeight - 7.2) < 1e-6, "U7 point de saut seul, au niveau des pieds : saut du rig (" .. fmt(h7.JumpHeight) .. ")")

	section("promo : modificateurs et volumes des présentoirs bas")
	local before = Avoid.GetState()
	local direct = make("Part", { Name = "Promo_B", Anchored = true, Size = Vector3.new(4, 2, 2), CFrame = CFrame.new(0, -500, 0) }, STORE_A)
	local shelf = make("Part", { Name = "Shelf_Test", Anchored = true, Size = Vector3.new(4, 2, 2), CFrame = CFrame.new(0, -500, 0) }, STORE_A)
	local outside = make("Part", { Name = "Promo_Out", Anchored = true, Size = Vector3.new(4, 2, 2), CFrame = CFrame.new(0, -500, 0) }, Workspace)
	local group = make("Model", { Name = "Promo_C" }, STORE_A)
	local leg = make("Part", { Name = "Leg", Anchored = true, Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(0, -500, 30) }, group)
	local m = direct:FindFirstChild("PathAvoid")
	check(m ~= nil and m.ClassName == "PathfindingModifier" and m.Label == "GuardAvoid" and m.PassThrough == false,
		"M1 Promo_B (pièce d'un magasin) : PathfindingModifier « PathAvoid », Label GuardAvoid, PassThrough coupé")
	check(leg:FindFirstChild("PathAvoid") ~= nil, "M2 pièce d'un modèle Promo_C d'un magasin : marquée aussi")
	check(shelf:FindFirstChild("PathAvoid") == nil, "M3 Shelf_Test : jamais marqué")
	check(outside:FindFirstChild("PathAvoid") == nil, "M4 Promo_Out hors d'un magasin : jamais marqué")
	local mid = Avoid.GetState()
	check(mid.Marked == before.Marked + 2, "M5 deux pièces marquées, une seule fois chacune (" .. tostring(mid.Marked - before.Marked) .. ")")
	local costs = Avoid.Costs()
	check(costs ~= nil and costs.GuardAvoid == math.huge, "M6 Costs de l'agent : GuardAvoid = math.huge")
	-- f70c3b : volumes.
	local vf = Workspace:FindFirstChild("PathAvoidVolumes")
	local volume = nil
	if vf then
		for _, v in vf:GetChildren() do
			if math.abs(v.CFrame.Position.Y - (-500 + 2)) < 1e-6 and math.abs(v.CFrame.Position.Z) < 1e-6 then
				volume = v
			end
		end
	end
	check(mid.Volumes == before.Volumes + 2, "M7 un volume par pièce marquée (" .. tostring(mid.Volumes - before.Volumes) .. ")")
	check(volume ~= nil and volume.Name == "PathAvoidVolume" and volume.Anchored == true and volume.CanCollide == false
		and volume.CanQuery == false and volume.CanTouch == false and volume.Transparency == 1,
		"M8 volume de Promo_B dans Workspace/PathAvoidVolumes : invisible, Anchored, ni collision, ni rayon, ni contact")
	check(volume ~= nil and (volume.Size - Vector3.new(4, 6, 2)).Magnitude < 1e-6,
		"M9 volume : empreinte de la pièce, de son bas à 4 studs au-dessus (4 × 6 × 2)")
	local vm = volume and volume:FindFirstChild("PathAvoid")
	check(vm ~= nil and vm.ClassName == "PathfindingModifier" and vm.Label == "GuardAvoid" and vm.PassThrough == false,
		"M10 volume : PathfindingModifier, Label GuardAvoid")
	check(direct:FindFirstChild(("PathAvoidVolume")) == nil and #direct:GetChildren() == 1,
		"M11 rien d'autre sous la pièce de Clément que le modificateur")
	-- Saut interdit près d'une pièce marquée (BeforeJump false, JumpHeight pas touchée).
	local hj = make("Humanoid", { UseJumpPower = false, JumpHeight = 7.2 })
	local onTop = Avoid.BeforeJump(hj, { { Position = Vector3.new(0, -499, 0) }, { Position = Vector3.new(0, -501, 6) } }, 1, -501)
	check(onTop == false and hj.JumpHeight == 7.2, "J1 point de saut sur Promo_B : saut refusé, JumpHeight pas touchée")
	local nextOn = Avoid.BeforeJump(hj, { { Position = Vector3.new(0, -501, -6) }, { Position = Vector3.new(0, -499, 0.5) } }, 1, -501)
	check(nextOn == false, "J2 point de saut à 5 studs du bord, suivant sur Promo_B : refusé")
	local nearSide = Avoid.BeforeJump(hj, { { Position = Vector3.new(4.5, -501, 0) }, { Position = Vector3.new(9, -501, 0) } }, 1, -501)
	check(nearSide == false, "J3 point de saut à 2,5 studs du bord (< JumpNear 3) : refusé")
	local far = Avoid.BeforeJump(hj, { { Position = Vector3.new(0, -501, 10) }, { Position = Vector3.new(0, -499, 14) } }, 1, -501)
	check(far == true, "J4 point de saut à 9 studs du bord : permis")
	for _, inst in { direct, shelf, outside, group } do
		inst:Destroy()
	end
	check(Avoid.GetState().Volumes == before.Volumes, "M12 pièces retirées du jeu : volumes retirés aussi")

	section("promo : Sidestep (rayons sur de vraies pièces)")
	local params = RaycastParamsAPI.new()
	local function never()
		return false
	end
	local origin = Vector3.new(0, -300, 0)
	local target = Vector3.new(30, -300, 0)
	local free = Side.Aim(origin, target, 1.5, 2, params, never)
	check(free == target, "S1 rien sur les flancs : le point visé")
	local pole = make("Part", { Name = "Pole", Anchored = true, Size = Vector3.new(1.35, 10, 1.35), CFrame = CFrame.new(12, -300, -0.8) }, Workspace)
	local around = Side.Aim(origin, target, 1.5, 2, params, never)
	check(around ~= target and around.Z > 0 and math.abs(around.Y - target.Y) < 1e-6 and around.X > 12 and around.X < 30,
		"S2 poteau de 1,35 à 0,8 stud de sa ligne : point après le poteau, décalé de l'autre côté (" .. tostring(around) .. ")")
	pole.CanCollide = false
	check(Side.Aim(origin, target, 1.5, 2, params, never) == target, "S3 poteau sans collision : le point visé")
	pole:Destroy()
	local wall = make("Part", { Name = "Wall", Anchored = true, Size = Vector3.new(20, 10, 1), CFrame = CFrame.new(15, -300, -1.6) }, Workspace)
	check(Side.Aim(origin, target, 1.5, 2, params, never) == target, "S4 mur le long d'un flanc (20 studs) : le point visé")
	wall:Destroy()
elseif S249 == "promooff" or S249 == "sautoff" then
	check(Avoid.Costs() == nil, "0 " .. S249 .. " : PathAvoid coupé, aucun Costs")
end

DECEL = 700
if S249 == "proche" or S249 == "procheoff" then
	-- f70c3b (Cantin, 2026-11-18) : voleur au-dessus du minimum, tenu à distance tant qu'il court, puis arrêt net à 7 s.
	section(`{S249} : le voleur s'arrête net devant le vigile ({TAG249})`)
	check(ChaseCfg.ApproachSlowNear == (S249 == "procheoff"), "N0 Config/Chase.ApproachSlowNear : " .. tostring(ChaseCfg.ApproachSlowNear))
	local P, model = start249(speedFor(30))
	check(model ~= nil, "N1 braquage, vigile apparu")
	if model then
		local STOP = 7
		local stopped = false
		local rec = follow249(P, model, 14, function(t)
			if not stopped and t >= STOP then
				stopped = true
				stop(P)
			end
		end)
		local W = if rec.samples[1] then rec.samples[1].walk else humanoidOf(P).WalkSpeed
		local before, lowWs, held = math.huge, math.huge, 0
		for _, s in rec.samples do
			if s.t < STOP then
				before = math.min(before, s.d)
				if s.t >= STOP - 2 then
					held = math.max(held, math.abs(s.d - ChaseCfg.HoldDistance))
				end
			elseif s.t >= STOP + 0.1 then
				lowWs = math.min(lowWs, s.ws) -- après l'arrêt (le relevé finit à la capture)
			end
		end
		local after = rec.caught and rec.caught.t - STOP
		print(string.format("  mesure %s %s : marche %.1f, au plus près %.2f studs avant l'arrêt (écart à HoldDistance %.2f), capture %s s après l'arrêt, vigile au plus lent %s studs/s après l'arrêt",
			S249, TAG249, W, before, held, fmt(after), fmt(lowWs)))
		check(before >= ChaseCfg.HoldDistance - 1, "N2 pas de capture ni de dépassement tant qu'il court (" .. fmt(before) .. ")")
		check(held <= 1, "N3 tenu à HoldDistance ± 1 les 2 s avant l'arrêt (" .. fmt(held) .. ")")
		check(rec.caught ~= nil and rec.caught.t > STOP, "N4 arrêté, il est attrapé")
		if S249 == "proche" then
			check(after ~= nil and after <= 1, "N5 attrapé en au plus 1 s après l'arrêt (" .. fmt(after) .. ")")
			check(lowWs >= W - 0.5, "N6 le vigile ne ralentit pas sous la marche du voleur (" .. fmt(lowWs) .. " pour " .. fmt(W) .. ")")
			-- Élan : le freinage d'arrivée reste (plafond à sa marche + rapprochement freiné jusqu'à CatchDistance) ; jamais
			-- dans le voleur ni au-delà avant la capture.
			local closest = if rec.caught then rec.caught.d else math.huge
			for _, s in rec.samples do
				if s.t >= STOP then
					closest = math.min(closest, s.d)
				end
			end
			print(string.format("  mesure %s : au plus près %.2f studs après l'arrêt (capture comprise), vitesse à la capture %s", S249, closest, fmt(rec.caught and rec.caught.ws)))
			check(closest >= 1, "N7 ni dans le voleur ni au-delà : au moins 1 stud entre les centres (" .. fmt(closest) .. ")")
		else
			check(after ~= nil and after > 1, "N5 avant : approche lente, plus d'1 s (" .. fmt(after) .. ")")
		end
		finish(rec)
	end
	DECEL = nil
	summary("scénario " .. S249)
	return
end
if POLE then
	-- f70c3b (T-217) : voleur arrêté, le vigile le voit à 14 studs ; un poteau de 1,35 stud de large, à mi-chemin, à
	-- 0,8 stud de sa ligne (comme Lamp_S1 : il ne coupe pas la ligne de vue). Le faux vigile ne heurte rien : on mesure
	-- la plus petite distance à plat de son centre à l'axe du poteau (moins de 0,675 + 1 : il le percute).
	section(`{S249} : poteau fin à côté de sa ligne ({TAG249})`)
	local P, model = start249(speedFor(30))
	check(model ~= nil, "P1 braquage, vigile apparu")
	if model then
		advance(5)
		local root = model:FindFirstChild("HumanoidRootPart")
		local hum = model:FindFirstChildOfClass("Humanoid")
		local spot = rootOf(P).Position
		local y = root.Position.Y
		local feet = y - (hum.HipHeight + root.Size.Y / 2)
		local HALF = 0.675
		local poleX, poleZ = spot.X - 7, spot.Z - 0.8
		local pole = make("Part", { Name = "Pole", Anchored = true, Size = Vector3.new(2 * HALF, 10, 2 * HALF),
			CFrame = CFrame.new(poleX, feet + 5, poleZ) }, Workspace)
		local c = clientOf(P)
		local base = BEFORE_FRAME
		BEFORE_FRAME = function(dt)
			c.pos = Vector3.new(spot.X, c.pos.Y, spot.Z)
			base(dt)
			rootOf(P).AssemblyLinearVelocity = Vector3.zero
		end
		root.CFrame = CFrame.new(spot.X - 14, y, spot.Z) * root.CFrame.Rotation
		local t0 = now()
		local n = #CATCHES
		local caughtAt, closest = nil, math.huge
		while now() - t0 < 10 and caughtAt == nil do
			advance(FRAME)
			local p = root.Position
			closest = math.min(closest, Vector3.new(p.X - poleX, 0, p.Z - poleZ).Magnitude)
			if #CATCHES > n then
				caughtAt = now() - t0
			end
			if TRACE_F70C3 then
				print(string.format("    t %.2f pos (%.1f ; %.1f ; %.1f) ws %.1f", now() - t0, p.X - spot.X, p.Y - y, p.Z - spot.Z, hum.WalkSpeed))
			end
		end
		BEFORE_FRAME = base
		pole:Destroy()
		print(string.format("  mesure %s %s : plus près de l'axe du poteau %.2f studs, capture %s s après le placement",
			S249, TAG249, closest, fmt(caughtAt)))
		check(caughtAt ~= nil, "P2 attrapé (" .. fmt(caughtAt) .. ")")
		if S249 == "poteau" then
			check(closest >= HALF + 1, "P3 jamais dans le poteau : centre à au moins 1,675 stud de son axe (" .. fmt(closest) .. ")")
			check(caughtAt ~= nil and caughtAt <= 2, "P4 attrapé en au plus 2 s (" .. fmt(caughtAt) .. ")")
		else
			check(closest < HALF + 1, "P3 avant : il passe dans le poteau (" .. fmt(closest) .. ")")
		end
		finish({ P = P, caught = caughtAt })
	end
	DECEL = nil
	summary("scénario " .. S249)
	return
end

-- Voleur arrêté derrière une table basse Promo_Test (2,2 × 2,2 × 5,4, dans un magasin PNJ) : la table coupe le rayon des
-- genoux (pas celui du centre), le vigile passe donc par un chemin. Faux PathfindingService (PATH_F70C3) : par-dessus
-- la table (point Jump avant, point sur la table, point après) si rien d'interdit ne couvre le dessus de la table (un
-- volume dont le Label coûte plus de 1 à l'agent : le modificateur de la pièce seule ne compte pas, comme dans le Play
-- de fusion71) ; sinon, autour de son bout. « promoforce » : toujours par-dessus (saut refusé par BeforeJump).
section(`{S249} : voleur arrêté derrière une table basse Promo_Test ({TAG249})`)
local P, model = start249(speedFor(30))
check(model ~= nil, "T1 braquage, vigile apparu")
if model then
	advance(5)
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local spot = rootOf(P).Position
	local y = root.Position.Y
	local feet = y - (hum.HipHeight + root.Size.Y / 2)
	local RISE, HALF_X, HALF_Z = 2.2, 1.1, 2.7
	local tableX = spot.X - 7
	local promo = make("Model", { Name = "Promo_Test" }, STORE_A)
	local top = make("Part", { Name = "Top", Anchored = true, Size = Vector3.new(2 * HALF_X, RISE, 2 * HALF_Z),
		CFrame = CFrame.new(tableX, feet + RISE / 2, spot.Z) }, promo)
	local function topForbidden(costs)
		local vf = Workspace:FindFirstChild("PathAvoidVolumes")
		if vf == nil or costs == nil then
			return false
		end
		local probe = Vector3.new(tableX, feet + RISE + 0.5, spot.Z)
		for _, v in vf:GetChildren() do
			local mod = v:FindFirstChild("PathAvoid")
			local cost = if mod then costs[mod.Label] else nil
			if cost and cost > 1 then
				local here = v.CFrame:PointToObjectSpace(probe)
				if math.abs(here.X) <= v.Size.X / 2 and math.abs(here.Y) <= v.Size.Y / 2 and math.abs(here.Z) <= v.Size.Z / 2 then
					return true
				end
			end
		end
		return false
	end
	local params, overCount, aroundCount = nil, 0, 0
	PATH_F70C3 = function(a, b, p)
		params = p
		local points = { { a, "Walk" } } -- points au niveau du sol (pieds), comme Roblox ; le premier est le départ
		if (a.X - tableX) * (b.X - tableX) < 0 and math.abs(a.X - tableX) > HALF_X and math.abs(b.X - tableX) > HALF_X then
			local dir = if b.X > a.X then 1 else -1
			if S249 ~= "promoforce" and topForbidden(p and p.Costs) then
				aroundCount += 1
				table.insert(points, { Vector3.new(tableX - dir * (HALF_X + 2), feet, spot.Z + HALF_Z + 2.5), "Walk" })
				table.insert(points, { Vector3.new(tableX + dir * (HALF_X + 2), feet, spot.Z + HALF_Z + 2.5), "Walk" })
			else
				overCount += 1
				table.insert(points, { Vector3.new(tableX - dir * (HALF_X - 0.3), feet + RISE, (a.Z + b.Z) / 2), "Jump" })
				table.insert(points, { Vector3.new(tableX + dir * (HALF_X - 0.3), feet + RISE, (a.Z + b.Z) / 2), "Walk" })
				table.insert(points, { Vector3.new(tableX + dir * (HALF_X + 1.5), feet, b.Z), "Walk" })
			end
		end
		table.insert(points, { Vector3.new(b.X, feet, b.Z), "Walk" })
		local out = {}
		for _, pt in points do
			table.insert(out, { Position = pt[1], Action = "Enum.PathWaypointAction." .. pt[2] })
		end
		return out
	end
	local c = clientOf(P)
	local base = BEFORE_FRAME
	BEFORE_FRAME = function(dt)
		c.pos = Vector3.new(spot.X, c.pos.Y, spot.Z)
		base(dt)
		rootOf(P).AssemblyLinearVelocity = Vector3.zero
	end
	root.CFrame = CFrame.new(spot.X - 14, y, spot.Z) * root.CFrame.Rotation
	hum.Jump = false
	local t0 = now()
	local n = #CATCHES
	local caughtAt, jumps, jumpHeight, jumpPower, onTable = nil, 0, nil, nil, false
	while now() - t0 < 10 and caughtAt == nil do
		advance(FRAME)
		local p = root.Position
		if hum.Jump == true then
			jumps += 1
			jumpHeight = hum.JumpHeight
			jumpPower = hum.UseJumpPower
			hum.Jump = false
		end
		if math.abs(p.X - tableX) < HALF_X + 0.3 and math.abs(p.Z - spot.Z) < HALF_Z + 0.3 then
			onTable = true
		end
		if #CATCHES > n then
			caughtAt = now() - t0
		end
		if TRACE_F70C3 then
			print(string.format("    t %.2f pos (%.1f ; %.1f ; %.1f) ws %.1f wp %s", now() - t0, p.X - spot.X, p.Y - y, p.Z - spot.Z, hum.WalkSpeed, tostring(params ~= nil)))
		end
	end
	BEFORE_FRAME = base
	PATH_F70C3 = nil
	local marked = top:FindFirstChild("PathAvoid") ~= nil
	local covered = topForbidden(Avoid.Costs())
	promo:Destroy()
	print(string.format("  mesure %s %s : chemins par-dessus %d, autour %d, sauts %d (hauteur %s), sur la table : %s, capture %s s après le placement",
		S249, TAG249, overCount, aroundCount, jumps, tostring(jumpHeight), tostring(onTable), fmt(caughtAt)))
	check(caughtAt ~= nil, "T2 attrapé (" .. fmt(caughtAt) .. ")")
	if S249 == "promo" then
		check(params ~= nil and params.Costs ~= nil and params.Costs.GuardAvoid == math.huge and params.AgentCanJump == true,
			"T3 agent du vigile : Costs GuardAvoid = math.huge, saut toujours permis ailleurs")
		check(marked and covered, "T4 table Promo_Test (posée pendant la partie) : marquée, son dessus dans un volume interdit")
		check(aroundCount >= 1 and overCount == 0, "T5 chemins autour de la table seulement (" .. aroundCount .. " / " .. overCount .. ")")
		check(jumps == 0, "T6 aucun saut (" .. jumps .. ")")
		check(not onTable, "T7 jamais sur la table")
		check(caughtAt ~= nil and caughtAt <= 2, "T8 attrapé en au plus 2 s (" .. fmt(caughtAt) .. ")")
	elseif S249 == "promoforce" then
		check(overCount >= 1, "T3 chemin forcé par-dessus la table (" .. overCount .. ")")
		check(jumps == 0, "T4 saut vers la table refusé : aucun saut (" .. jumps .. ")")
	else
		check(not marked and (params == nil or params.Costs == nil), "T3 avant : ni modificateur ni coût")
		check(overCount >= 1 and jumps >= 1, "T4 avant : par-dessus la table, avec un saut (" .. jumps .. ")")
		if S249 == "promooff" then
			check(jumpHeight ~= nil and math.abs(jumpHeight - (RISE + 2)) < 1e-6 and jumpPower == false,
				"T5 saut à la marche + JumpMargin, 4,2 studs, UseJumpPower coupé (" .. tostring(jumpHeight) .. ")")
		else
			check(jumpHeight == nil, "T5 JumpMargin = 0 : JumpHeight du rig jamais touchée (" .. tostring(jumpHeight) .. ")")
		end
	end
	finish({ P = P, caught = caughtAt })
end
DECEL = nil
summary("scénario " .. S249)
