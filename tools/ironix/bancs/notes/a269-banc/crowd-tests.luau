-- Banc a269, partie foule (Cantin, 20/11 : la foule devant les boutiques ne se rentre plus dedans) : le vrai
-- WitnessCrowdController sur le faux Roblox du banc a240 crowd (lignes avant « -- B1. », ajoutées par crowd-run.sh).
-- En plus : GetExtentsSize des modèles (largeurs 4, 3,6 et 4,4 studs : écart attendu 4,4 + Margin).
--   F1 plusieurs largeurs de vitrine × plusieurs tirages : aucune paire plus proche que l'écart, 2 × PerSide places
--   F2 deux magasins voisins, deux foules à la fois (la seconde formée pendant la création de la première)
--   F3 un circuit WitnessPaths devant la vitrine et deux témoins sur les places : rien à moins de l'écart
--   off (Crowd.Spacing.Enabled = false) : les places d'avant, dont des paires plus proches que l'écart
do
	function methods.GetExtentsSize(self)
		return rawget(self, "_extents")
	end
	rawset(Models.NPC_Crowd_01, "_extents", vec(4, 5.2, 1.2))
	rawset(Models.NPC_Crowd_02, "_extents", vec(3.6, 5, 1))
	rawset(Models.NPC_Crowd_03, "_extents", vec(1.5, 5, 4.4))
end
local SP = CROWD.Spacing
local GAP = 4.4 + (if SP then SP.Margin else 0)

local T = {}
function T.flat(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
function T.positions()
	local list = {}
	for _, m in members() do
		table.insert(list, m.HumanoidRootPart.Position)
	end
	return list
end
function T.minPair(list)
	local best = math.huge
	for i = 1, #list do
		for j = i + 1, #list do
			best = math.min(best, T.flat(list[i], list[j]))
		end
	end
	return best
end
-- Places de chaque côté du passage (vitrine en x = cx, tournée vers +Z).
function T.sides(list, cx)
	local left, right = 0, 0
	for _, p in list do
		if p.X < cx then
			left += 1
		else
			right += 1
		end
	end
	return left, right
end
function T.wait()
	for _ = 1, 80 do
		if (Controller.GetStats().Pending or 0) == 0 then
			return
		end
		advance(0.05)
	end
end
-- `player` sort du magasin dont la vitrine est en x = cx (z = −50) ; `full` : attendre la foule complète.
function T.exit(player, cx, full)
	camera.CFrame = cf(vec(cx, 10, 30), 0)
	player:SetAttribute("Carrying", "Legendary")
	moveTo(player, vec(cx, 3, -60))
	advance(0.25)
	moveTo(player, vec(cx + 2, 3, -44))
	advance(0.25)
	if full then
		T.wait()
	end
end
function T.toSegment(p, a, b)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local apx, apz = p.X - a.X, p.Z - a.Z
	local l2 = abx * abx + abz * abz
	local t = if l2 > 1e-9 then math.clamp((apx * abx + apz * abz) / l2, 0, 1) else 0
	local dx, dz = apx - abx * t, apz - abz * t
	return math.sqrt(dx * dx + dz * dz)
end

local N = 2 * CROWD.PerSide
local EPS = 1e-6

if CROWD_OFF then
	-- off : les places d'avant ------------------------------------------------------------------------
	check("off Spacing.Enabled = false", SP ~= nil and SP.Enabled == false)
	local worst = math.huge
	for draw = 1, 3 do
		T.exit(alice, (draw - 1) * 200, true)
		local list = T.positions()
		check(`off tirage {draw} : {N} places`, #list == N, #list)
		worst = math.min(worst, T.minPair(list))
		finish()
	end
	print(`MESURE off : paire la plus proche {string.format("%.2f", worst)} studs (écart a269 : {GAP})`)
	check("off des paires plus proches que l'écart (comportement d'avant)", worst < GAP, worst)
	check("off GetStats().Gap = 0", Controller.GetStats().Gap == 0, Controller.GetStats().Gap)
	print(`banc a269 crowd off : {CHECKS} vérification(s), {FAILS} échec(s)`)
	return
end

-- F0. Les valeurs V0 ------------------------------------------------------------------------------------
check("F0 Spacing V0", SP ~= nil and SP.Enabled == true and SP.Margin == 0.5 and SP.WidthFallback == 4 and SP.WidthMax == 6 and SP.Step == 0.5 and SP.MaxPush == 20 and SP.Witnesses == true)
check("F0 au moins 10 par côté (Clément)", CROWD.PerSide >= 10 and CROWD.PerSideLow >= 10, `{CROWD.PerSide} {CROWD.PerSideLow}`)

-- F1. Largeurs de vitrine × tirages ----------------------------------------------------------------------
do
	local WIDTHS = { 4, 10, 16, 30 }
	local k, worst, far = 0, math.huge, 0
	local allCount, allSides, allGap = true, true, true
	for _, w in WIDTHS do
		for draw = 1, 3 do
			local index = k % 7 + 1
			k += 1
			if k > 7 and index == 1 then
				advance(CROWD.Cooldown) -- même magasin qu'au premier tour
			end
			local cx = (index - 1) * 200
			stores[index].Window.Size = vec(w, 6, 0.5)
			T.exit(alice, cx, true)
			local list = T.positions()
			local m = T.minPair(list)
			worst = math.min(worst, m)
			local left, right = T.sides(list, cx)
			for _, p in list do
				far = math.max(far, p.Z + 50)
			end
			if #list ~= N then
				allCount = false
				print(`  F1 vitrine {w}, tirage {draw} : {#list} places`)
			end
			if left < 10 or right < 10 then
				allSides = false
			end
			if m < GAP - EPS then
				print(`  F1 vitrine {w}, tirage {draw} : paire à {m}`)
			end
			allGap = allGap and m >= GAP - EPS
			finish()
		end
	end
	print(`MESURE F1 : paire la plus proche {string.format("%.2f", worst)} studs (écart {GAP}), place la plus loin à {string.format("%.1f", far)} studs de la vitrine`)
	check("F1 aucune paire plus proche que l'écart (4 largeurs × 3 tirages)", allGap, worst)
	check(`F1 toujours {N} places`, allCount)
	check("F1 au moins 10 de chaque côté", allSides)
	check("F1 GetStats().Gap = largeur réelle la plus grande + Margin", math.abs(Controller.GetStats().Gap - GAP) < EPS, Controller.GetStats().Gap)
	check("F1 place la plus loin à moins de Start + Length + MaxPush + Jitter", far <= CROWD.Start + CROWD.Length + SP.MaxPush + CROWD.Jitter + EPS, far)
end

-- F2. Deux magasins voisins ---------------------------------------------------------------------------------
do
	local A, B = 1600, 1622
	newStore("STORE_Z1_VoisinA", A)
	newStore("STORE_Z1_VoisinB", B)
	local bob = newPlayer("Bob", vec(B, 3, -80), false)
	T.exit(alice, A, false) -- la foule A se crée encore
	local pendingA = Controller.GetStats().Pending
	T.exit(bob, B, true)
	T.wait()
	local crowdsNow = Controller.GetCrowds()
	local list = T.positions()
	local m = T.minPair(list)
	print(`MESURE F2 : {#crowdsNow} foules, {#list} personnes, paire la plus proche {string.format("%.2f", m)} studs`)
	check("F2 la seconde foule formée pendant la création de la première", pendingA > 0 and #crowdsNow == 2, `{pendingA} {#crowdsNow}`)
	check("F2 aucune paire plus proche que l'écart, foules voisines comprises", m >= GAP - EPS, m)
	local ok = true
	for _, c in crowdsNow do
		local cx = if c.Store.Name == "STORE_Z1_VoisinA" then A else B
		local pos = {}
		for _, mm in c.Members do
			table.insert(pos, mm.HumanoidRootPart.Position)
		end
		local left, right = T.sides(pos, cx)
		if left < 10 or right < 10 then
			ok = false
			print(`  F2 {c.Store.Name} : {left} à gauche, {right} à droite`)
		end
	end
	check("F2 au moins 10 de chaque côté dans chaque foule", ok)
	finish()
	bob:SetAttribute("Carrying", nil)
	alice:SetAttribute("Carrying", nil)
	advance(0.5)
end

-- F3. Un circuit de témoins et deux témoins devant la vitrine -------------------------------------------------
do
	local X = 2400
	local zone = node("Folder", "Zone_9", map)
	local s = newStore("STORE_Z9_Circuit", X)
	s.Parent = zone
	local paths = node("Folder", "WitnessPaths", zone)
	local sub = node("Folder", "Trottoir", paths)
	local P = { vec(X - 40, 0.5, -38), vec(X + 40, 0.5, -38), vec(X + 40, 0.5, -36), vec(X - 40, 0.5, -36) }
	for i, p in P do
		node("Attachment", string.format("WitnessPath_%02d", i), if i % 2 == 0 then sub else paths, { WorldPosition = p })
	end
	node("Attachment", "Autre_01", paths, { WorldPosition = vec(X, 0.5, -20) }) -- pas un WitnessPath_ : ignoré
	local w1 = newWitness("NPC_Witness_Z9_01", vec(X - 9, 3, -25), "STORE_Z9_Circuit")
	local w2 = newWitness("NPC_Witness_Z9_02", vec(X + 9, 3, -25), "STORE_Z9_Circuit")
	T.exit(alice, X, true)
	local list = T.positions()
	local nearPath, nearWitness = math.huge, math.huge
	for _, p in list do
		for i = 1, #P do
			nearPath = math.min(nearPath, T.toSegment(p, P[i], P[i % #P + 1]))
		end
		nearWitness = math.min(nearWitness, T.flat(p, w1.HumanoidRootPart.Position), T.flat(p, w2.HumanoidRootPart.Position))
	end
	local left, right = T.sides(list, X)
	print(`MESURE F3 : {#list} personnes ({left} + {right}), circuit à {string.format("%.2f", nearPath)}, témoin à {string.format("%.2f", nearWitness)} studs au plus près`)
	check("F3 personne à moins de l'écart du circuit WitnessPaths", nearPath >= GAP - EPS, nearPath)
	check("F3 personne à moins de l'écart d'un témoin", nearWitness >= GAP - EPS, nearWitness)
	check("F3 aucune paire plus proche que l'écart", T.minPair(list) >= GAP - EPS, T.minPair(list))
	check("F3 au moins 10 de chaque côté", left >= 10 and right >= 10, `{left} {right}`)
	finish()
end

local warns = 0
for _, l in LOGS do
	if string.find(l, "^WARN") then
		warns += 1
		if VERBOSE then
			print(l)
		end
	end
end
check("F4 aucune erreur du contrôleur", not string.find(table.concat(LOGS, "\n"), "rror"), table.concat(LOGS, " | "))
print(`banc a269 crowd on : {CHECKS} vérification(s), {FAILS} échec(s)`)
