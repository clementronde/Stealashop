--!nocheck
-- Télémétrie coupée : Config/Telemetry.Enabled = false dans le faux arbre.
for key, src in SOURCES do
	if string.find(key, "Config/Telemetry.luau", 1, true) then
		SOURCES[key] = (string.gsub(src, "\tEnabled = true,", "\tEnabled = false,"))
	end
end
