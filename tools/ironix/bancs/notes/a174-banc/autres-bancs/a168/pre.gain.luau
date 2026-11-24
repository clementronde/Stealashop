-- a153 : minimum de 100K en zone 1 et AboveRequired = "Gain".
do
	local key = "shared/Config/Chase.luau"
	local patched, count = string.gsub(SOURCES[key], "Zone1SpeedRequired = 0,", "Zone1SpeedRequired = 100000,")
	assert(count == 1, "Chase.Zone1SpeedRequired introuvable")
	local patched2, count2 = string.gsub(patched, "	AboveRequired = \"Hold\"", "	AboveRequired = \"Gain\"")
	assert(count2 == 1, "Chase.AboveRequired introuvable")
	SOURCES[key] = patched2
end
