--!strict
-- Tension/Path (a465 ; liaison L-340) : calculs sans effet de bord de TensionController, pour les bancs hors Studio.
-- Module d'aide (sous-dossier : le Loader ne le démarre pas). Un chemin est une liste de points (Vector3) du joueur à la
-- porte de sa boutique ; les distances « le long du chemin » se mesurent à plat (X et Z), la hauteur suit le sol.
--
-- API :
--   Path.Length(points) -> number
--   Path.Project(points, position) -> (along, off)    abscisse du point le plus proche sur le chemin et écart à plat
--   Path.PointAt(points, along) -> (Vector3, Vector3) point du chemin à cette abscisse et direction à plat (unité)
--   Path.Sample(points, fromAlong, spec) -> { Sample }  chevrons sur une grille fixe (abscisses multiples de Spacing,
--       Index = rang sur la grille), le premier au moins FirstAt studs après fromAlong (la place du joueur), jamais à
--       moins de EndMargin de la fin, Max au plus
--   Path.Wave(rank, time, spec) -> number             transparence d'une barre du chevron de rang `rank` (son Index :
--       les rangs croissent vers la boutique) à l'instant `time` : de From à Peak puis From, Step s de décalage d'un
--       rang au suivant (la vague va vers la boutique), une vague toutes les Period s
--   Path.FlashSteps(keys, times) -> (start, { Step })  flash d'arrivée : valeur de départ, puis chaque pas (To, Time)

export type Sample = { Position: Vector3, Direction: Vector3, Along: number, Index: number }
export type SampleSpec = { Spacing: number, FirstAt: number, EndMargin: number, Max: number }
export type WaveSpec = { From: number, Peak: number, Step: number, PulseTime: number, Period: number }
export type Step = { To: number, Time: number }

local Path = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatLength(a: Vector3, b: Vector3): number
	return flat(b - a).Magnitude
end

function Path.Length(points: { Vector3 }): number
	local total = 0
	for i = 2, #points do
		total += flatLength(points[i - 1], points[i])
	end
	return total
end

function Path.Project(points: { Vector3 }, position: Vector3): (number, number)
	if #points == 0 then
		return 0, math.huge
	end
	if #points == 1 then
		return 0, flatLength(points[1], position)
	end
	local p = flat(position)
	local bestAlong, bestOff = 0, math.huge
	local walked = 0
	for i = 2, #points do
		local a = flat(points[i - 1])
		local b = flat(points[i])
		local segment = b - a
		local length = segment.Magnitude
		local t = 0
		if length > 1e-6 then
			local d = p - a
			t = math.clamp((d.X * segment.X + d.Z * segment.Z) / (length * length), 0, 1)
		end
		local closest = a + segment * t
		local off = (p - closest).Magnitude
		if off < bestOff then
			bestOff = off
			bestAlong = walked + length * t
		end
		walked += length
	end
	return bestAlong, bestOff
end

function Path.PointAt(points: { Vector3 }, along: number): (Vector3, Vector3)
	local count = #points
	if count == 0 then
		return Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)
	end
	local lastDirection = Vector3.new(0, 0, -1)
	local walked = 0
	for i = 2, count do
		local a, b = points[i - 1], points[i]
		local length = flatLength(a, b)
		if length > 1e-6 then
			local direction = flat(b - a) * (1 / length)
			lastDirection = direction
			if along <= walked + length then
				local t = math.clamp((along - walked) / length, 0, 1)
				return a + (b - a) * t, direction
			end
		end
		walked += length
	end
	return points[count], lastDirection
end

function Path.Sample(points: { Vector3 }, fromAlong: number, spec: SampleSpec): { Sample }
	local out: { Sample } = {}
	local spacing = math.max(spec.Spacing, 0.5)
	local total = Path.Length(points)
	-- Grille fixe le long du chemin (multiples de Spacing) : un chevron ne glisse pas quand le joueur avance, il
	-- disparaît une fois dépassé. Index = rang sur la grille (1 = le premier après le départ du chemin).
	local index = math.max(math.ceil((fromAlong + spec.FirstAt) / spacing - 1e-9), 1)
	local stop = total - spec.EndMargin
	while index * spacing <= stop and #out < spec.Max do
		local along = index * spacing
		local position, direction = Path.PointAt(points, along)
		table.insert(out, { Position = position, Direction = direction, Along = along, Index = index })
		index += 1
	end
	return out
end

function Path.Wave(rank: number, time: number, spec: WaveSpec): number
	local period = math.max(spec.Period, 1e-3)
	local u = (time - (rank - 1) * spec.Step) % period
	local pulse = math.max(spec.PulseTime, 1e-3)
	if u >= pulse then
		return spec.From
	end
	local half = pulse / 2
	local k = if u < half then u / half else (pulse - u) / half -- 0 → 1 → 0
	return spec.From + (spec.Peak - spec.From) * k
end

function Path.FlashSteps(keys: { number }, times: { number }): (number, { Step })
	local steps: { Step } = {}
	for i = 2, #keys do
		table.insert(steps, { To = keys[i], Time = math.max(times[i - 1] or 0, 0) })
	end
	return keys[1] or 1, steps
end

return Path
