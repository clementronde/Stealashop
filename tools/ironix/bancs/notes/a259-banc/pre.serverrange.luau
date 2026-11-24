--!nocheck
-- a259 : Config/Unbox.New.RealOdds = false (la cote finale tirée dans la plage de la rareté, comme avant).
do
	local key = "shared/Config/Unbox.luau"
	local text, n = string.gsub(SOURCES[key], "RealOdds = true, %-%- interrupteur", "RealOdds = false, -- interrupteur")
	assert(n == 1, "New.RealOdds introuvable dans Config/Unbox")
	SOURCES[key] = text
end
