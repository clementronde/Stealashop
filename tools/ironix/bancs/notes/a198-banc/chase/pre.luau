-- a198 (vague 61) : correctifs des sources pour la poursuite à l'échelle (après sources.luau, avant setup.luau).
-- Comme pre.luau d'a193, mais sans relever le plafond de marche : le banc court au plus à 70 × K, le vrai plafond.
local function patch(key, from, to)
	local patched, count = string.gsub(SOURCES[key], from, to)
	assert(count == 1, key .. " : « " .. from .. " » introuvable")
	SOURCES[key] = patched
end
-- Minimum de la zone 1 pour la règle : 1e5 = tous au-dessus (hold) ; 1e30 = tous très en dessous (catch).
local required = if A193_SCENARIO == "a198hold" then "100000" else "1e30"
patch("shared/Config/Chase.luau", "Zone1SpeedRequired = 0,", "Zone1SpeedRequired = " .. required .. ",")
patch("shared/Config/Night.luau", "GuardsPerZone = 2,", "GuardsPerZone = 1,")
