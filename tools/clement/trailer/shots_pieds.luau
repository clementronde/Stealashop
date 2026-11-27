--!nocheck
-- Pieds sur le sol (Clément, 26/11 nuit : « les personnages qui courent sont la plupart du temps dans le sol, ça ne doit
-- plus exister »). À charger en dernier (après shots_lancement, shots_inspi_allees, shots_banque, shots_sequences).
--
-- Cause : l'outil posait chaque figurant par sa HumanoidRootPart, à « sol + HipHeight + moitié de la HRP ». Le pied
-- n'était jamais regardé. Or la pose de course (Run, CarryRun, Flee, TreadmillRun) descend les jambes sous la ligne de
-- repos, et le HipHeight de certains modèles (copies de témoins, de la foule, vigiles) ne colle pas à la longueur de leurs
-- jambes : les pieds passaient sous le sol.
--
-- Correction, à chaque image, APRÈS Animator:StepAnimations (branchée sur T.fx.updateCarry, voir plus bas) :
--   - point le plus bas des deux pieds (LeftFoot, RightFoot, les 8 coins de chaque pièce) ;
--   - surface sous ce pied : rayon vers le bas qui ignore _TRAILER et les pièces invisibles (sol, trottoir, bande du tapis) ;
--   - tout le figurant monte ou descend de l'écart (l'objet porté suit) : le pied le plus bas touche la surface.
-- Contrôle : après la correction, on remesure ; si un pied est à plus de L.FEET_TOL (0,1 stud) de sa surface sur une
-- image, le plan est REFUSÉ (S.feetFail, et L.batchRun le dit). On garde aussi l'écart avant correction (S.feetBefore),
-- pour savoir quels plans étaient touchés.
-- Exceptions : un figurant marqué a.air (projeté, en vol) n'est ni corrigé ni contrôlé.
local T = _G.Trailer
local L = T.launch
assert(T and L, "charger trailer_lib et shots_lancement d'abord")
local V = Vector3.new
L.FEET_TOL = 0.1

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude

local FEET = { "LeftFoot", "RightFoot" }
local function lowestFoot(a)
	local best, at
	for _, n in FEET do
		local p = a.model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			local cf, h = p.CFrame, p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = cf:PointToWorldSpace(V(sx * h.X, sy * h.Y, sz * h.Z))
						if not best or w.Y < best then best, at = w.Y, w end
					end
				end
			end
		end
	end
	return best, at
end

local function surfaceBelow(pt: Vector3)
	rp.FilterDescendantsInstances = { T.root() }
	local origin = pt + V(0, 3, 0)
	for _ = 1, 10 do
		local r = workspace:Raycast(origin, V(0, -14, 0), rp)
		if not r then return nil end
		local i = r.Instance
		if i.Transparency < 0.9 and i.LocalTransparencyModifier < 0.9 and i.CanQuery ~= false then return r.Position.Y end
		origin = r.Position - V(0, 0.02, 0)
	end
	return nil
end

-- corrige un figurant ; rend l'écart avant correction (studs, + = pied sous la surface)
function L.groundFeet(a)
	if a.air then return nil end
	local y, at = lowestFoot(a)
	if not y then return nil end
	local s = surfaceBelow(at)
	if not s then return nil end
	local d = s - y
	if math.abs(d) > 1e-4 then
		a.cf = (a.cf or a.model:GetPivot()) + V(0, d, 0)
		a.model:PivotTo(a.model:GetPivot() + V(0, d, 0))
		if T.fx and T.fx.updateCarry then T.fx.updateCarry(a) end
	end
	return d
end

local function checkFeet(a)
	if a.air then return 0 end
	local y, at = lowestFoot(a)
	if not y then return 0 end
	local s = surfaceBelow(at)
	if not s then return 0 end
	return s - y
end

-- Branchement : sur T.fx.updateCarry, que toutes les versions du moteur (trailer_lib et v5 image par image) appellent pour
-- chaque figurant juste après Animator:StepAnimations. (Un essai par S.camPost, le 26/11, ne marchait pas : la boucle
-- chargée dans Studio était plus ancienne que celle du fichier et n'appelle pas camPost.) Les mesures vont dans
-- L.feetRec[nom du plan] (le moteur remplace T.state en fin de prise) : écart avant correction, écart après, refus.
local uc0 = T.fx._uc0 or T.fx.updateCarry
T.fx._uc0 = uc0
L.feetRec = L.feetRec or {}
T.fx.updateCarry = function(a)
	uc0(a)
	if L._noFix or a.air or not (a.model and a.model.Parent and a.model:FindFirstChild("LeftFoot")) then return end
	local S = T.state
	local name = S and S.name or "?"
	local rec = L.feetRec[name]
	if not rec or rec.S ~= S then
		rec = { S = S, before = 0, after = 0, fail = nil, frames = 0 }
		L.feetRec[name] = rec
	end
	local y, at = lowestFoot(a)
	if not y then return end
	local s = surfaceBelow(at)
	if not s then return end
	local d = s - y
	if math.abs(d) > rec.before then rec.before = math.abs(d) end
	if math.abs(d) > 1e-4 then
		a.cf = (a.cf or a.model:GetPivot()) + V(0, d, 0)
		a.model:PivotTo(a.model:GetPivot() + V(0, d, 0))
		uc0(a)
	end
	rec.frames += 1
	local e = checkFeet(a)
	if math.abs(e) > rec.after then rec.after = math.abs(e) end
	if math.abs(e) > L.FEET_TOL and not rec.fail then
		rec.fail = ("%s à t = %.2f s : %.2f stud"):format(tostring(a.id or "?"), S and S.t or -1, e)
	end
end
L._lowestFoot, L._surfaceBelow, L._checkFeet = lowestFoot, surfaceBelow, checkFeet

-- batchRun : rend aussi l'écart des pieds par plan, et REFUSÉ si un pied dépasse la tolérance sur une image
function L.batchRun(list)
	local res = {}
	local t0 = os.clock()
	for _, name in list do
		local ok, err = pcall(T.prepare, name)
		if not ok then table.insert(res, name .. " ERREUR " .. tostring(err)) else
			task.wait(0.8)
			T.go()
			while T.state.phase ~= "done" do task.wait(0.1) end
			local S = T.state
			local rec = L.feetRec[name] or {}
			local verdict = if rec.fail then ("REFUSÉ (%s)"):format(rec.fail)
				elseif (rec.frames or 0) == 0 then "pas de figurant à pieds"
				else ("pieds ok (≤ %.3f sur %d mesures)"):format(rec.after or 0, rec.frames)
			table.insert(res, ("%s %d images %.0f i/s, %s, écart avant correction %.2f"):format(name, S.n or -1, S.fps or -1, verdict, rec.before or 0))
		end
	end
	return ("%.0f s :\n%s"):format(os.clock() - t0, table.concat(res, "\n"))
end

-- Diagnostic sans tourner : pour chaque plan, l'écart des pieds AVANT correction, mesuré à quelques instants du plan
-- (T.stillAt fait avancer le plan jusqu'à t). Rend la liste des plans où un pied passe sous la surface de plus de tol.
function L.feetAudit(list, samples, tol)
	samples, tol = samples or 6, tol or L.FEET_TOL
	local out = {}
	L._noFix = true -- stillAt appelle aussi updateCarry : rien n'est corrigé pendant l'audit
	for _, name in list do
		local sh = T.shots[name]
		local worst, who, when = 0, "", 0
		for k = 1, samples do
			local t = sh.dur * (k - 0.5) / samples
			local ok = pcall(T.stillAt, name, t)
			if ok then
				task.wait(0.15)
				for id, a in (T.state and T.state.actors) or {} do
					if a.model and a.model.Parent and not a.air then
						local e = checkFeet(a)
						if e > worst then worst, who, when = e, tostring(id), t end
					end
				end
			end
		end
		table.insert(out, ("%s : %s"):format(name, if worst > tol then ("PIEDS SOUS LE SOL de %.2f (%s, t = %.1f s)"):format(worst, who, when) else ("ok (%.2f)"):format(worst)))
	end
	L._noFix = nil
	return table.concat(out, "\n")
end
return "pieds : correction et contrôle branchés (T.fx.updateCarry)"
