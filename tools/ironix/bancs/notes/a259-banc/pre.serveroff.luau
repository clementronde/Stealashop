--!nocheck
-- a251 : Config/Unbox.New.Enabled = false (la cinématique d'avant).
do
	local key = "shared/Config/Unbox.luau"
	local text, n = string.gsub(SOURCES[key], "Enabled = true, %-%- interrupteur ; false = la cinématique d'avant", "Enabled = false, -- interrupteur ; false = la cinématique d'avant")
	assert(n == 1, "New.Enabled introuvable dans Config/Unbox")
	SOURCES[key] = text
end
