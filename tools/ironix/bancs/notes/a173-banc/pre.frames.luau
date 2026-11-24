-- a153 : la zone 1 reçoit un minimum de 100K pour la règle (Chase.Zone1SpeedRequired), pour faire varier r.
do
	local key = "shared/Config/Chase.luau"
	local patched, count = string.gsub(SOURCES[key], "Zone1SpeedRequired = 0,", "Zone1SpeedRequired = 100000,")
	assert(count == 1, "Chase.Zone1SpeedRequired introuvable")
	SOURCES[key] = patched
end
-- a173 : un seul vigile de nuit par zone (le second, s'il voit le voleur, l'attrapait avant le mesuré).
do
	local key = "shared/Config/Night.luau"
	local patched, count = string.gsub(SOURCES[key], "GuardsPerZone = 2,", "GuardsPerZone = 1,")
	assert(count == 1, "Night.GuardsPerZone introuvable")
	SOURCES[key] = patched
end
