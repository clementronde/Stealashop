--!nocheck
-- Interrupteur coupé : Config/Telemetry avec Enabled = false (le module est gelé : on change sa source).
do
	local key = "shared/Config/Telemetry.luau"
	local source = SOURCES[key]
	local from = "\tEnabled = true,"
	local at = string.find(source, from, 1, true)
	assert(at ~= nil and string.find(source, from, at + 1, true) == nil, "pre.switch : « Enabled = true, » introuvable ou en double dans Config/Telemetry")
	SOURCES[key] = string.sub(source, 1, at - 1) .. "\tEnabled = false," .. string.sub(source, at + #from)
end
