-- a193 : correctifs des sources du banc (après sources.luau, avant setup.luau), selon A193_SCENARIO.
local function patch(key, from, to)
	local patched, count = string.gsub(SOURCES[key], from, to)
	assert(count == 1, key .. " : « " .. from .. " » introuvable")
	SOURCES[key] = patched
end
-- Marche jusqu'à 100 studs/s (le banc court à 90 ; le jeu plafonne à 70 aujourd'hui, mais trails et potions
-- poussent la Speed affichée).
patch("shared/Config/Balance.luau", "MaxWalkSpeed = 70,", "MaxWalkSpeed = 100,")
-- Minimum de la zone 1 pour la règle (comme pre.frames d'a173) : 1e5 = tous au-dessus (hold) ; 1e30 = tous très
-- en dessous (catch) ; 1e15 = 90 studs/s au-dessus, 60 en dessous (collide, off).
local required = if A193_SCENARIO == "hold" then "100000" elseif A193_SCENARIO == "catch" then "1e30" else "1e15"
patch("shared/Config/Chase.luau", "Zone1SpeedRequired = 0,", "Zone1SpeedRequired = " .. required .. ",")
if A193_SCENARIO == "off" then
	patch("shared/Config/Chase.luau", "LagCompensation = true,", "LagCompensation = false,")
end
patch("shared/Config/Night.luau", "GuardsPerZone = 2,", "GuardsPerZone = 1,")
