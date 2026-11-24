-- a249 (poursuite phase 2, L-235) : correctifs des sources pour un scénario (après les sources, avant setup.luau),
-- comme pre224.luau : un vigile de nuit par zone ; « below » : minimum de la zone 1 très haut (1e30, rapprochement le
-- plus fort) ; « …off » : l'interrupteur du scénario coupé (mesure « avant »).
local function patch(key, from, to)
	local patched, count = string.gsub(SOURCES[key], from, to)
	assert(count == 1, key .. " : « " .. from .. " » introuvable")
	SOURCES[key] = patched
end
patch("shared/Config/Night.luau", "GuardsPerZone = 2,", "GuardsPerZone = 1,")
if A193_SCENARIO == "below" then
	patch("shared/Config/Chase.luau", "Zone1SpeedRequired = 10,", "Zone1SpeedRequired = 1e30,")
elseif A193_SCENARIO == "springoff" then
	patch("shared/Config/Chase.luau", "SpringReturn = true,", "SpringReturn = false,")
elseif A193_SCENARIO == "departoff" then
	patch("shared/Config/Chase.luau", "StartDelay = 1,", "StartDelay = 0.5,")
elseif A193_SCENARIO == "repriseoff" then
	patch("shared/Config/Chase.luau", "WaitAfterReveal = true,", "WaitAfterReveal = false,")
elseif A193_SCENARIO == "doubleoff" then
	-- l'état d'avant complet : sans le retour doux, le vigile d'intrus s'approche du voleur étourdi (HoldMinSpeed)
	patch("shared/Config/Chase.luau", "SpringReturn = true,", "SpringReturn = false,")
	patch("shared/Config/Chase.luau", "OneCatchAtATime = true,", "OneCatchAtATime = false,")
elseif A193_SCENARIO == "coinceoff" then
	patch("shared/Config/Chase.luau", "StuckCatch = true,", "StuckCatch = false,")
elseif A193_SCENARIO == "loinoff" then
	patch("shared/Config/Chase.luau", "SpringFar = true,", "SpringFar = false,")
end
