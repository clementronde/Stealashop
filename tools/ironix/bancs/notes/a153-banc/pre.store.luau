-- a153 : la zone 1 reçoit un minimum de 100K pour la règle (Chase.Zone1SpeedRequired), pour faire varier r.
do
	local key = "shared/Config/Chase.luau"
	local patched, count = string.gsub(SOURCES[key], "Zone1SpeedRequired = 0,", "Zone1SpeedRequired = 100000,")
	assert(count == 1, "Chase.Zone1SpeedRequired introuvable")
	SOURCES[key] = patched
end
