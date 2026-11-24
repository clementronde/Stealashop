--!nocheck
-- a202 : doublure de Shared/ItemWeight (contrat a202, a203, a204), pilotée par le banc (IW), à la place du module.
IW = { kg = 10, scale = 1, factor = 1, size = nil, class = "Small", lucks = {}, calls = {} }
SOURCES["shared/ItemWeight.luau"] = [==[
local W = {}
function W.Roll(rng, luck)
	table.insert(IW.lucks, luck)
	return IW.kg
end
function W.ScaleFor(kg) return IW.scale end
function W.IncomeFactor(kg) return IW.factor end
function W.SizeMutationFor(kg) return IW.size end
function W.SizeClassFor(kg, freeHeight, modelHeight)
	table.insert(IW.calls, { kg = kg, freeHeight = freeHeight, modelHeight = modelHeight })
	return IW.class
end
return W
]==]
