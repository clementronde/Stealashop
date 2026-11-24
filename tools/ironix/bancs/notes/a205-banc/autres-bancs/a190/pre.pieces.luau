-- Copie a200 : scénario « pieces » : Config/Hud.TreadmillGain.ChunksPerSecond = 5 dans la copie des sources (morceaux d'a190).
do
	local key = "shared/Config/Hud.luau"
	SOURCES[key] = (string.gsub(SOURCES[key], "ChunksPerSecond = 1,", "ChunksPerSecond = 5,", 1))
end
