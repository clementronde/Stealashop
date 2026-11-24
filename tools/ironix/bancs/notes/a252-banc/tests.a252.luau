-- a252 (L-244, L-245 ; capture qui se voit, plan large, renvoi de nuit) : collé après les aides de tests.a249.luau
-- (start249, follow249…), elles-mêmes après celles de tests.luau d'a193. Scénarios : voir run.sh.
local S252 = A193_SCENARIO
local function module252(folderName, name)
	local f = SERVICES:FindFirstChild(folderName)
	local m = if f then f:FindFirstChild(name) else nil
	return if m then requireModule(m, SERVER_SIDE) else nil
end
local Pick = module252("Guard", "CatchPickUp")
local PickCfg = ChaseCfg.CatchPickUp
check(Pick ~= nil and Guard._CatchShow == Pick, "0 Guard/CatchPickUp chargé, vu par GuardService")
check(ChaseCfg.PathJumpLead == 0.3 and ChaseCfg.PathJumpLeadMax == 1.5, "0 Config/Chase : PathJumpLead 0,3, PathJumpLeadMax 1,5")
check(PickCfg ~= nil and PickCfg.Reach == 2.5 and PickCfg.FallTime == 0.3 and PickCfg.PickUpDelay == 0.2 and PickCfg.GrabFallback == 0.5
	and PickCfg.HoldTime == 0.4 and PickCfg.MaxAfterImpact == 1.6 and PickCfg.MaxAfterCatch == 2.2,
	"0 Config/Chase.CatchPickUp : Reach 2,5, FallTime 0,3, PickUpDelay 0,2, GrabFallback 0,5, HoldTime 0,4, MaxAfterImpact 1,6, MaxAfterCatch 2,2")
check(PickCfg ~= nil and PickCfg.Enabled == (S252 ~= "ramasseoff") and PickCfg.Always == (S252 == "ramasse" or S252 == "ramasseoff"),
	"0 Config/Chase.CatchPickUp : Enabled " .. tostring(PickCfg and PickCfg.Enabled) .. ", Always " .. tostring(PickCfg and PickCfg.Always))
check(ChaseCfg.DayCatchAtNightSendsHome == (S252 ~= "nuitoff") and ChaseCfg.DayCatchAtNightDelay == 2,
	"0 Config/Chase : DayCatchAtNightSendsHome " .. tostring(ChaseCfg.DayCatchAtNightSendsHome) .. ", DayCatchAtNightDelay 2")

if S252 == "ramasse" or S252 == "ramasseoff" or S252 == "rue" then
	local ON = S252 == "ramasse"
	section(`{S252} : capture dans la rue, {if ON then "le vigile ramasse (Always)" else "l'objet repart tout de suite (comme avant)"}`)
	local P, model = start249(speedFor(30))
	check(model ~= nil, "R1 braquage, vigile apparu")
	if model then
		check(Carry.IsCarrying(P), "R2 le voleur porte l'objet")
		local stopped = false
		local rec = follow249(P, model, 14, function(t)
			if not stopped and t >= 3 then
				stopped = true
				stop(P)
			end
		end)
		check(rec.caught ~= nil, "R3 arrêté, il est attrapé (" .. fmt(rec.caught and rec.caught.t) .. " s)")
		if rec.caught then
			local before = Pick.GetState()
			local t0 = now()
			local seen, endAt, clearAt = false, nil, nil
			if not Carry.IsCarrying(P) then
				endAt = 0
			end
			while now() - t0 < 4 do
				if P:GetAttribute("CatchPickUp") == true then
					seen = true
				elseif seen and clearAt == nil then
					clearAt = now() - t0
				end
				if endAt == nil and not Carry.IsCarrying(P) then
					endAt = now() - t0
				end
				advance(FRAME)
			end
			local after = Pick.GetState()
			print(string.format("  mesure %s : attribut CatchPickUp %s, retiré à %s s, portage fini %s s après la capture, ramassé %d, fini %d, depuis %s",
				S252, tostring(seen), fmt(clearAt), fmt(endAt), after.Grabbed - before.Grabbed, after.Done - before.Done, tostring(after.LastFrom)))
			if ON then
				check(seen, "R4 attribut CatchPickUp posé sur le Player pendant la séquence")
				check(clearAt ~= nil and endAt ~= nil and math.abs(clearAt - endAt) <= 2 * FRAME, "R5 attribut retiré quand l'objet repart (" .. fmt(clearAt) .. " / " .. fmt(endAt) .. ")")
				check(endAt ~= nil and endAt >= 0.3 and endAt <= PickCfg.MaxAfterCatch + 0.05,
					"R6 l'objet repart après le ramassage, au plus 2,2 s après la capture (" .. fmt(endAt) .. " s)")
				check(after.Done == before.Done + 1 and after.Pending == 0, "R7 une séquence finie, aucune en attente")
				check(after.Grabbed == before.Grabbed + 1, "R8 l'objet est passé dans la main du vigile (repli GrabFallback, PickUp absente du banc)")
			else
				check(not seen, "R4 aucun attribut CatchPickUp")
				check(endAt ~= nil and endAt <= 2 * FRAME, "R5 l'objet repart dès la capture, comme avant (" .. fmt(endAt) .. " s)")
				check(after.Done == before.Done, "R6 aucune séquence")
			end
		end
		finish(rec)
	end
elseif S252 == "nuit" then
	section("nuit : capture par le vigile d'un magasin la nuit, dans le couloir : renvoi à la boutique (hooks factices)")
	local P = thief(speedFor(30))
	local sent = function()
		return true
	end
	local inCorridor = true
	local hooks = {
		InCorridor = function()
			return inCorridor
		end,
		SendHome = sent,
	}
	local at = Vector3.new(150, 3, 0)
	check(Pick.NightSendHome(P, hooks, at) == sent, "N1 dans le couloir : renvoi à la boutique")
	check(Pick.NightSendHomeDelay() == 2, "N2 au bout de DayCatchAtNightDelay = 2 s")
	inCorridor = false
	check(Pick.NightSendHome(P, hooks, at) == nil, "N3 hors du couloir : pas de renvoi")
	inCorridor = true
	check(Pick.NightSendHome(P, nil, at) == nil, "N4 de jour (pas de hooks de nuit) : pas de renvoi")
	hooks.InCorridor = function()
		error("panne")
	end
	check(Pick.NightSendHome(P, hooks, at) == nil, "N6 InCorridor en erreur : pas de renvoi")
elseif S252 == "nuitoff" then
	section("nuitoff : DayCatchAtNightSendsHome coupé : jamais de renvoi (la règle d'avant)")
	local P = thief(speedFor(30))
	local hooks = { InCorridor = function() return true end, SendHome = function() return true end }
	check(Pick.NightSendHome(P, hooks, Vector3.new(150, 3, 0)) == nil, "N5 interrupteur coupé : pas de renvoi")
elseif S252 == "plan" then
	section("plan : cadrage de la caméra de capture (CatchScene/Shot.Frame, pur)")
	local Shot = module252("_a252Client", "Shot")
	check(Shot ~= nil, "P0 CatchScene/Shot chargé")
	local cfg = ChaseCfg.CatchShot
	if Shot and cfg then
		local a = Vector3.new(0, 3, 0)
		local b = Vector3.new(4, 3, 0)
		local focus = (a + b) / 2 + Vector3.new(0, cfg.FocusRise, 0)
		local function free()
			return nil
		end
		local function never()
			return false
		end
		local fov, aspect = 70, 16 / 9
		local d = Shot.Distance(a, b, fov, aspect, cfg)
		check(d >= cfg.MinDistance and d <= cfg.MaxDistance, "P1 distance bornée (" .. fmt(d) .. ")")
		check(Shot.Distance(a, Vector3.new(200, 3, 0), fov, aspect, cfg) == cfg.MaxDistance, "P2 très loin : MaxDistance")
		check(Shot.Distance(a, a, fov, aspect, cfg) == cfg.MinDistance, "P3 l'un sur l'autre : MinDistance")
		local pos, f, kind = Shot.Frame(a, b, fov, aspect, Vector3.new(2, 8, 20), free, never, cfg)
		local flat = Vector3.new(pos.X - f.X, 0, pos.Z - f.Z)
		check(kind == "Free" and near(f.Y, focus.Y, 1e-6) and near(f.X, focus.X, 1e-6), "P4 libre : plan « Free », visé au milieu des deux")
		check(near(flat.Unit:Dot(Vector3.new(1, 0, 0)), 0, 1e-3), "P5 plein côté : perpendiculaire à l'axe joueur → vigile")
		check(pos.Z > 0, "P6 du côté de la caméra d'avant (z " .. fmt(pos.Z) .. ")")
		check(near(flat.Magnitude, d, 1e-3) and near(pos.Y - f.Y, cfg.Rise, 1e-3), "P7 à la distance de cadrage, Rise au-dessus")
		-- un mur à 4 studs du côté +z (celui de la caméra) : l'autre côté, libre.
		local function wallPlusZ(from, to)
			if to.Z > from.Z + 1 then
				return 4
			end
			return nil
		end
		local pos2, _, kind2 = Shot.Frame(a, b, fov, aspect, Vector3.new(2, 8, 20), wallPlusZ, never, cfg)
		check(kind2 == "Free" and pos2.Z < 0, "P8 mur proche d'un côté : l'autre côté (" .. kind2 .. ", z " .. fmt(pos2.Z) .. ")")
		-- murs partout à 10 studs (les deux à 20 studs l'un de l'autre : cadrage plus loin que 10) : en deçà, WallPad devant.
		local b2 = Vector3.new(20, 3, 0)
		local d2 = Shot.Distance(a, b2, fov, aspect, cfg)
		local function wallAt(r)
			return function(from, to)
				return if (to - from).Magnitude > r then r else nil
			end
		end
		local pos3, f3, kind3 = Shot.Frame(a, b2, fov, aspect, nil, wallAt(10), never, cfg)
		check(d2 > 10 and kind3 == "Wall" and near((pos3 - f3).Magnitude, 10 - cfg.WallPad, 1e-3),
			"P9 murs à 10 studs (cadrage à " .. fmt(d2) .. ") : caméra à 9,4 studs, devant le mur (" .. kind3 .. ", " .. fmt((pos3 - f3).Magnitude) .. ")")
		-- murs partout à 3 studs : derrière le mur, jamais dans une pièce (épaisse jusqu'à d + 2).
		local function thick(p)
			return (p - focus).Magnitude < d + 2
		end
		local pos4, f4, kind4 = Shot.Frame(a, b, fov, aspect, nil, wallAt(3), thick, cfg)
		check(kind4 == "Through" and not thick(pos4), "P10 murs à 3 studs : derrière le mur, hors de la pièce (" .. kind4 .. ", " .. fmt((pos4 - f4).Magnitude) .. ")")
	end
end
summary("scénario " .. S252)
