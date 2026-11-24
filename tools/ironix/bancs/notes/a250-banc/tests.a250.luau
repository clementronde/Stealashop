-- a250 (restes de la poursuite après fusion68) : collé après les aides de tests.a249.luau (start249, follow249…),
-- elles-mêmes après celles de tests.luau d'a193. Scénarios : voir run.sh. « …off » : mesure « avant ».
if not OFF249 then
	check(ChaseCfg.StuckThinPrefix == "Shelf" and ChaseCfg.StuckProgressShare == 0.25 and ChaseCfg.ApproachAlongPath == true
		and ChaseCfg.ApproachBrakeHidden == 20 and ChaseCfg.PathJumpLead == 0.3,
		"0 Config/Chase : StuckThinPrefix « Shelf », StuckProgressShare 0,25, ApproachAlongPath, ApproachBrakeHidden 20, PathJumpLead 0,3")
end

-- Voleur coincé (comme le scénario coince d'a249) : le client pousse vers FAR2, remis chaque image au même point, vitesse
-- lue nulle ; un panneau `name` d'épaisseur `thick` à 1 stud derrière lui. `guardAt(t, stopX, spot, root)` place le vigile
-- (nil : il bute contre le panneau, à 1,05 stud de sa face). Relevé jusqu'à `limit` s ou la capture.
local function cornered250(label, name, thick, limit, guardAt)
	local P, model = start249(speedFor(30))
	check(model ~= nil, label .. " : braquage, vigile apparu")
	if model == nil then
		return nil
	end
	advance(5)
	local root = model:FindFirstChild("HumanoidRootPart")
	local spot = rootOf(P).Position
	local wallX = spot.X - 1
	local wall = make("Part", { Name = name, Anchored = true, Size = Vector3.new(thick, 12, 40), CFrame = CFrame.new(wallX, 5, spot.Z) }, Workspace)
	local c = clientOf(P)
	local base = BEFORE_FRAME
	local stopX = wallX - thick / 2 - 1.05
	local t0 = now()
	BEFORE_FRAME = function(dt)
		c.pos = Vector3.new(spot.X, c.pos.Y, spot.Z)
		base(dt)
		rootOf(P).AssemblyLinearVelocity = Vector3.zero
		local p = root.Position
		if guardAt then
			root.CFrame = CFrame.new(guardAt(now() - t0, stopX, spot, p)) * root.CFrame.Rotation
		elseif p.X > stopX then
			root.CFrame = CFrame.new(stopX, p.Y, p.Z) * root.CFrame.Rotation
		end
	end
	local n = #CATCHES
	local caughtAt, closest, farthest = nil, math.huge, 0
	local inRange = 0
	while now() - t0 < limit and caughtAt == nil do
		advance(FRAME)
		local d = horizontal(rootOf(P).Position, root.Position)
		closest = math.min(closest, d)
		if d <= C then
			inRange += FRAME
			farthest = math.max(farthest, d)
		end
		if #CATCHES > n then
			caughtAt = now() - t0
		end
	end
	BEFORE_FRAME = base
	wall:Destroy()
	finish({ P = P, caught = caughtAt })
	return { caughtAt = caughtAt, closest = closest, farthest = farthest, inRange = inRange }
end

if S249 == "porte" or S249 == "porteoff" then
	-- reste 1 (Play de fusion68, Confiserie : attrapé « coincé » à travers DoorGlass_L, 0,3 stud) : un panneau mince qui
	-- n'est pas un rayon (porte vitrée, vitrine) reste un mur ; un bout de rayon (Shelf_…) reste traversable pour la règle.
	DECEL = 700
	section(`{S249} : voleur coincé derrière une porte vitrée ou un bout de rayon de 0,3 stud ({TAG249})`)
	for _, case in { { "Pa", "DoorGlass_L", "porte vitrée" }, { "Pb", "WindowGlass_Test250", "vitrine" }, { "Pc", "Shelf_A_EndA", "bout de rayon" } } do
		local label, name, what = case[1], case[2], case[3]
		local r = cornered250(label, name, 0.3, 8)
		if r then
			print(string.format("  mesure %s %s (%s) : vigile au plus près %.2f studs, à portée %.2f s, capture %s s",
				TAG249, label, what, r.closest, r.inRange, fmt(r.caughtAt)))
			check(r.closest <= C, label .. " : le vigile est à portée, derrière le panneau (" .. fmt(r.closest) .. ")")
			if name == "Shelf_A_EndA" or OFF249 then
				check(r.caughtAt ~= nil and r.caughtAt <= 2.5, label .. " : attrapé en au plus 2,5 s (" .. fmt(r.caughtAt) .. ")")
			else
				check(r.caughtAt == nil, label .. " : jamais attrapé à travers une " .. what .. " en 8 s (" .. fmt(r.caughtAt) .. ")")
			end
		end
	end
	DECEL = nil
elseif S249 == "marche" or S249 == "marcheoff" then
	-- reste 2 et a250b (Play de fusion69 : les cas 2 et 3 tirent en sens contraire). Derrière un bout de rayon, le vigile
	-- qui longe le panneau à 3 studs/s, à portée (de z − 1,2 à z + 1,2 en 0,8 s), attrape le voleur coincé (règle de
	-- fusion68 : 1 stud en 0,3 s) ; celui qui passe à 10 studs/s ne l'attrape jamais. En terrain ouvert, la capture se
	-- fait « en vue » (CatchReach.CanTouch) : la fenêtre stricte (StuckProgressShare) n'y sert qu'avec une position estimée.
	DECEL = 700
	section(`{S249} : vigile qui longe un bout de rayon à 3 puis 10 studs/s ({TAG249})`)
	for _, case in { { "M1", 3 }, { "M2", 10 } } do
		local label, speed = case[1], case[2]
		local r = cornered250(label, "Shelf_Test250", 0.3, 0.8, function(t, stopX, spot, p)
			return Vector3.new(stopX, p.Y, spot.Z - 1.2 + speed * t)
		end)
		if r then
			print(string.format("  mesure %s %s : vigile entre %.2f et %.2f studs (à portée %.2f s), capture %s s",
				TAG249, label, r.closest, r.farthest, r.inRange, fmt(r.caughtAt)))
			if speed <= 3 then
				check(r.inRange >= math.min(0.75, (r.caughtAt or 1) - 0.05), label .. " : le vigile est à portée tout du long (" .. fmt(r.inRange) .. " s)")
				check(r.caughtAt ~= nil and r.caughtAt <= 0.5, label .. " : attrapé en au plus 0,5 s en longeant le rayon à 3 studs/s (" .. fmt(r.caughtAt) .. ")")
			else
				check(r.inRange >= 0.3, label .. " : le vigile passe à portée (" .. fmt(r.inRange) .. " s)")
				check(r.caughtAt == nil, label .. " : jamais attrapé par un vigile qui passe à 10 studs/s (" .. fmt(r.caughtAt) .. ")")
			end
		end
	end
	DECEL = nil
elseif S249 == "detour" or S249 == "detouroff" then
	-- reste 3 (Play de fusion68, Supérette : voleur coincé derrière Shelf_A_EndA attrapé 3,3 à 3,4 s après l'arrivée du
	-- vigile, qui contourne le rayon à 3-10 studs/s). Un mur (1 stud, un vrai mur : pas de capture « coincé ») de 22 studs
	-- entre le vigile et le voleur arrêté ; le chemin (faux PathfindingService : PATH_VIA250) passe par le bout du mur.
	-- Le vigile ne traverse pas le mur (bloqué à 1,05 stud de sa face, comme dans coince). Mesure : du placement du vigile
	-- (8,9 studs en ligne droite, ≈ 16,7 par le chemin) à la capture.
	DECEL = 700
	section(`{S249} : voleur arrêté derrière un mur, le vigile le contourne ({TAG249})`)
	local P, model = start249(speedFor(30))
	check(model ~= nil, "D1 braquage, vigile apparu")
	if model then
		advance(5)
		local root = model:FindFirstChild("HumanoidRootPart")
		local spot = rootOf(P).Position
		local y = root.Position.Y
		local wallX, endZ, thick = spot.X - 1, spot.Z + 2, 1
		local wall = make("Part", { Name = "Wall_Test250", Anchored = true, Size = Vector3.new(thick, 12, 22), CFrame = CFrame.new(wallX, 5, endZ - 11) }, Workspace)
		local cornerA = Vector3.new(wallX - 2, y, endZ + 2.5)
		local cornerB = Vector3.new(wallX + 2, y, endZ + 2.5)
		PATH_VIA250 = function(a, b)
			local points = { a }
			if a.X < wallX and b.X > wallX then
				table.insert(points, Vector3.new(cornerA.X, a.Y, cornerA.Z))
				table.insert(points, Vector3.new(cornerB.X, a.Y, cornerB.Z))
			end
			table.insert(points, b)
			local wps = {}
			for _, p in points do
				table.insert(wps, { Position = p, Action = "Enum.PathWaypointAction.Walk" })
			end
			return wps
		end
		local c = clientOf(P)
		local base = BEFORE_FRAME
		local lastX = nil
		BEFORE_FRAME = function(dt)
			c.pos = Vector3.new(spot.X, c.pos.Y, spot.Z)
			base(dt)
			rootOf(P).AssemblyLinearVelocity = Vector3.zero
			-- Collision du vigile avec le mur : il ne passe pas d'un côté à l'autre le long du mur.
			local p = root.Position
			local face = wallX - thick / 2 - 1.05
			if lastX and lastX <= face + 1e-3 and p.X > face and p.Z < endZ + 1.05 then
				root.CFrame = CFrame.new(face, p.Y, p.Z) * root.CFrame.Rotation
			end
			lastX = root.Position.X
		end
		root.CFrame = CFrame.new(spot.X - 8, y, spot.Z - 4) * root.CFrame.Rotation
		lastX = root.Position.X
		local t0 = now()
		local n = #CATCHES
		local caughtAt, at14, maxWs, crossed = nil, nil, 0, false
		local prevWs, rise = nil, 0
		local path0 = 0
		do
			local g = root.Position
			path0 = horizontal(g, cornerA) + horizontal(cornerA, cornerB) + horizontal(cornerB, spot)
		end
		while now() - t0 < 10 and caughtAt == nil do
			advance(FRAME)
			local p = root.Position
			maxWs = math.max(maxWs, model:FindFirstChildOfClass("Humanoid").WalkSpeed)
			local ws = model:FindFirstChildOfClass("Humanoid").WalkSpeed
			if prevWs and now() - t0 > 0.1 then
				rise = math.max(rise, ws - prevWs)
			end
			prevWs = ws
			if p.Z > endZ then
				crossed = true
			end
			if #CATCHES > n then
				caughtAt = now() - t0
			end
		end
		BEFORE_FRAME = base
		PATH_VIA250 = nil
		wall:Destroy()
		print(string.format("  mesure %s : chemin %.1f studs, vigile au plus %.1f studs/s, passé par le bout du mur : %s, capture %s s après le placement",
			TAG249, path0, maxWs, tostring(crossed), fmt(caughtAt)))
		check(caughtAt ~= nil, "D2 attrapé (" .. fmt(caughtAt) .. ")")
		check(crossed, "D3 par le bout du mur, jamais à travers")
		print(string.format("  mesure %s : plus forte remontée du WalkSpeed %.2f studs/s", TAG249, rise))
		if not OFF249 then
			-- D5 : après le premier chemin (0,1 s ; avant, le vigile téléporté derrière le mur n'a que la ligne droite)
			check(rise <= 3, "D5 WalkSpeed sans remontée de plus de 3 studs/s (" .. fmt(rise) .. ")")
		end
		if not OFF249 then
			check(caughtAt ~= nil and caughtAt <= 2, "D4 attrapé en au plus 2 s (" .. fmt(caughtAt) .. ")")
		end
		finish({ P = P, caught = caughtAt })
	end
	DECEL = nil
end
summary("scénario " .. S249)
