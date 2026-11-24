--!strict
-- Calculs purs de la construction « en mode Lego » (L-297, a406) : sans Roblox, lus par
-- Controllers/ShopBuildController et testés hors Studio (banc a406).
--
--   ShopBuildPlan.backOut(t, overshoot) -> number
--       Courbe Back « Out » avec son dépassement (L-297 : BackOvershoot 1,9 ; Roblox : 1,70158). 0 → 0, 1 → 1.
--   ShopBuildPlan.plan(items, maxPieces, delay, dropTime, maxDuration) -> (order, rest, delay)
--       items[i] = { bottom = bas de la boîte (y), volume = volume de la boîte }. Les maxPieces plus grosses tombent,
--       triées du bas vers le haut (bottom croissant, puis le rang d'origine) ; `rest` : les autres, qui apparaissent
--       d'un coup avec la dernière. L'écart rendu est `delay`, réduit si besoin pour que la dernière pièce soit posée
--       maxDuration s après le départ de la première : (n − 1) × écart + dropTime ≤ maxDuration.
--   ShopBuildPlan.pitch(rank, step, max) -> number
--       PlaybackSpeed du rank-ième clic (1 pour le premier) : step ^ (rank − 1), au plus max.
--   ShopBuildPlan.isPurchase(old, new, maxStep) -> boolean
--       Un niveau qui passe de old à new est-il un achat (monte de 1 à maxStep, ancien niveau connu) ?
--   ShopBuildPlan.newStands(startSlots, old, new, standAt?) -> { number }
--       Numéros des présentoirs débloqués par le passage du niveau old à new (débloqués = startSlots + niveau).
--       a427 (L-321) : avec `standAt(niveau) -> number?` (Shared/ShopFloor.StandAt), le présentoir de chaque niveau est
--       le sien (31… à l'étage) ; nil (achat de l'étage) : aucun présentoir pour ce niveau.

export type Item = { bottom: number, volume: number }

local ShopBuildPlan = {}

function ShopBuildPlan.backOut(t: number, overshoot: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local u = t - 1
	return 1 + (overshoot + 1) * u * u * u + overshoot * u * u
end

function ShopBuildPlan.plan(items: { Item }, maxPieces: number, delay: number, dropTime: number, maxDuration: number): ({ number }, { number }, number)
	local all: { number } = {}
	for index in items do
		table.insert(all, index)
	end
	local chosen: { number } = all
	local rest: { number } = {}
	local cap = math.max(0, math.floor(maxPieces))
	if #all > cap then
		local bySize = table.clone(all)
		table.sort(bySize, function(a: number, b: number): boolean
			local va, vb = items[a].volume, items[b].volume
			if va ~= vb then
				return va > vb
			end
			return a < b
		end)
		chosen = {}
		for rank, index in bySize do
			table.insert(if rank <= cap then chosen else rest, index)
		end
		table.sort(rest)
	end
	table.sort(chosen, function(a: number, b: number): boolean
		local ba, bb = items[a].bottom, items[b].bottom
		if ba ~= bb then
			return ba < bb
		end
		return a < b
	end)
	local step = math.max(0, delay)
	if #chosen > 1 and maxDuration > 0 then
		local fit = (maxDuration - dropTime) / (#chosen - 1)
		if fit < step then
			step = math.max(0, fit)
		end
	end
	return chosen, rest, step
end

function ShopBuildPlan.pitch(rank: number, step: number, max: number): number
	return math.min(max, step ^ math.max(0, rank - 1))
end

function ShopBuildPlan.isPurchase(old: any, new: any, maxStep: number): boolean
	return type(old) == "number" and type(new) == "number" and new > old and new - old <= maxStep
end

function ShopBuildPlan.newStands(startSlots: number, old: number, new: number, standAt: ((level: number) -> number?)?): { number }
	local out: { number } = {}
	for level = math.floor(old) + 1, math.floor(new) do
		local number = if standAt then standAt(level) else startSlots + level
		if number then
			table.insert(out, number)
		end
	end
	return out
end

return ShopBuildPlan
