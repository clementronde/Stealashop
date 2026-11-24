-- a224 (vague 67) : correctifs des sources pour la poursuite (après sources.luau, avant setup.luau), comme pre.luau
-- d'a198 : minimum de la zone 1 très haut (1e30 : tous les voleurs bien en dessous, rapprochement le plus fort),
-- un vigile de nuit par zone. Scénario « …off » : Chase.ApproachBrake = 0, la règle d'avant a224.
local function patch(key, from, to)
	local patched, count = string.gsub(SOURCES[key], from, to)
	assert(count == 1, key .. " : « " .. from .. " » introuvable")
	SOURCES[key] = patched
end
patch("shared/Config/Chase.luau", "Zone1SpeedRequired = 0,", "Zone1SpeedRequired = 1e30,")
patch("shared/Config/Night.luau", "GuardsPerZone = 2,", "GuardsPerZone = 1,")
A224_OFF = string.find(A193_SCENARIO, "off", 1, true) ~= nil
if A224_OFF then
	patch("shared/Config/Chase.luau", "ApproachBrake = 5,", "ApproachBrake = 0,")
end
