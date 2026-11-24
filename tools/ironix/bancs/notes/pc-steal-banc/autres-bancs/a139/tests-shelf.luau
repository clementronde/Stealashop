-- a139 : lu après les scénarios du banc a17-shelf (copie a128), sans leur bilan (leurs locales servent ici).
-- A139_PERF = "on" ou "off". Chaque image d'un trajet de caméra écrit une ligne « TRACE » (contours actifs, nombre
-- d'étiquettes à portée) : run.sh vérifie que les deux passes écrivent exactement les mêmes lignes.
print("--- a139. Colis lointains (PerfClient.ShelfBoxFarSkip)")
local ON = A139_PERF == "on"
local function snapshot()
	local bits = {}
	for n = 1, 40 do
		if n ~= 6 then
			bits[#bits + 1] = if outlineOf(boxes[n]).Enabled then "1" else "0"
		end
	end
	bits[#bits + 1] = if outlineOf(newcomer).Enabled then "1" else "0"
	local stats = Controller.GetStats()
	return table.concat(bits) .. "|" .. stats.NearLabels .. "|" .. stats.ActiveOutlines
end
local step = 0
local function trace(n)
	for _ = 1, n do
		frames(1)
		step += 1
		print(`TRACE {step} {snapshot()}`)
	end
end
-- 1. Loin, puis on s'approche à 42 studs/s, on s'arrête, on repart sur le côté.
camera.CFrame = CFrame.new(60.37, 5, -400)
trace(60)
for _ = 1, 560 do
	camera.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 0, 0.7))
	trace(1)
end
trace(40)
for _ = 1, 200 do
	camera.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(1.3, 0, -0.4))
	trace(1)
end
-- 2. Sauts (téléportation, retour à la base) : loin, près, loin.
camera.CFrame = CFrame.new(5000, 5, 0)
trace(30)
camera.CFrame = CFrame.new(45.11, 5, 3)
trace(30)
camera.CFrame = CFrame.new(60.37, 5, -260)
trace(30)
-- 3. Très vite (180 studs/s) à travers la file.
for _ = 1, 120 do
	camera.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 0, 3))
	trace(1)
end

-- 4. Caméra immobile loin de tout : les colis du rayon ne sont plus relus.
camera.CFrame = CFrame.new(5000, 5, 0)
frames(30)
local basePivot = Methods.GetPivot
local pivots = 0
Methods.GetPivot = function(self)
	pivots += 1
	return basePivot(self)
end
frames(60)
local still = pivots
pivots = 0
frames(90)
local later = pivots
Methods.GetPivot = basePivot
if ON then
	check(still <= 5, `loin et immobile : contours des 40 colis plus relus pendant 1 s ({still} lectures, le contour non taggé seul)`)
	check(later >= 40, `revus au bout de ShelfBoxFarMaxSkip ({later} lectures en 1,5 s)`)
else
	check(still >= 120, `PerfClient coupé : relus à chaque tri, comme avant ({still})`)
end
camera.CFrame = CFrame.new(3 * 30, 5, 0)
frames(30)
check(labelOf(boxes[30]).Enabled == true, "revenu au milieu : étiquette revue tout de suite")
local warnings = logCount("WARN", "")
check(warnings == 0, `a139 : aucun avertissement ({warnings})`)
if warnings > 0 then
	dumpLog()
end
print(string.format("%d vérification(s), %d échec(s)", CHECKS, FAILS))
