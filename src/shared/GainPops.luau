--!strict
-- GainPops (a480, Clément via Cantin, 25/11) : logique pure des gains du tapis qui sortent autour du joueur
-- (Config/TreadmillFX.GainPops ; affichage dans GainController). Aucun service Roblox : testable hors Studio.
--
-- API :
--   GainPops.Split(total, perSecond, minPiece) -> { number }
--       Découpe le gain affiché `total` (Speed finale, trail compris) en au plus `perSecond` morceaux, même somme
--       exacte. Morceaux entiers dès que total ≥ perSecond (le reste en plus sur les premiers, la fraction sur le
--       dernier) ; sinon des dixièmes ; jamais un morceau sous `minPiece` (moins de morceaux à la place). total ≤ 0,
--       NaN ou infini : aucun morceau.
--   GainPops.Pick(rng, recent, spec) -> Vector3
--       Décalage (repère du monde, depuis le HumanoidRootPart) d'une nouvelle apparition : distance horizontale entre
--       spec.RadiusMin et spec.Radius, angle au hasard, hauteur entre spec.HeightMin et spec.HeightMax. Garde au moins
--       spec.MinSpacing avec chaque décalage de `recent` (apparitions encore visibles) ; après spec.Tries essais sans
--       y arriver, l'essai le plus éloigné de ses voisins. Toujours dans le rayon et la plage de hauteur.

local GainPops = {}

export type Spec = {
	RadiusMin: number,
	Radius: number,
	HeightMin: number,
	HeightMax: number,
	MinSpacing: number,
	Tries: number,
}

-- Ce que Pick utilise de Random (un vrai Random, ou un faux dans les bancs).
export type Rng = { NextNumber: (self: any, min: number, max: number) -> number }

function GainPops.Split(total: number, perSecond: number, minPiece: number): { number }
	if type(total) ~= "number" or total ~= total or total <= 0 or total == math.huge then
		return {}
	end
	local count = math.max(1, math.floor(perSecond))
	local unit = if total >= count then 1 else 0.1
	unit = math.max(unit, minPiece)
	local units = math.floor(total / unit + 1e-9)
	if units < 1 then
		return { total }
	end
	count = math.min(count, units)
	local base = units // count
	local extra = units % count
	local pieces: { number } = {}
	local sum = 0
	for rank = 1, count do
		local value = (base + (if rank <= extra then 1 else 0)) * unit
		table.insert(pieces, value)
		sum += value
	end
	pieces[count] += total - sum -- reste de la division (et arrondis) sur le dernier : même somme exacte
	return pieces
end

local function nearest(offset: Vector3, recent: { Vector3 }): number
	local best = math.huge
	for _, other in recent do
		best = math.min(best, (offset - other).Magnitude)
	end
	return best
end

function GainPops.Pick(rng: Rng, recent: { Vector3 }, spec: Spec): Vector3
	local inner = math.max(0, math.min(spec.RadiusMin, spec.Radius))
	local outer = math.max(inner, spec.Radius)
	local low = math.min(spec.HeightMin, spec.HeightMax)
	local high = math.max(spec.HeightMin, spec.HeightMax)
	local best: Vector3? = nil
	local bestGap = -1
	for _ = 1, math.max(1, math.floor(spec.Tries)) do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local radius = rng:NextNumber(inner, outer)
		local height = rng:NextNumber(low, high)
		local offset = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local gap = nearest(offset, recent)
		if gap >= spec.MinSpacing then
			return offset
		end
		if gap > bestGap then
			best, bestGap = offset, gap
		end
	end
	return best :: Vector3
end

return GainPops
