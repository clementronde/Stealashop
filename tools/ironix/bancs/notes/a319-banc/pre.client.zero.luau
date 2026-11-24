--!nocheck
-- a319, variante « zero » : boutique Robux ouverte, Id de DoubleSpeed = 0.
A319_VARIANT = "zero"
A319_PASS_ID = 0
do
	local function replace(key, from, to)
		local first, last = string.find(SOURCES[key], from, 1, true)
		assert(first, "a319 : remplacement introuvable dans " .. key .. " : " .. from)
		SOURCES[key] = string.sub(SOURCES[key], 1, first - 1) .. to .. string.sub(SOURCES[key], last + 1)
	end
	if 1 == 1 then
		replace("shared/Config/Features.luau", "RobuxShop = false", "RobuxShop = true")
	end
	if 0 ~= 0 then
		replace("shared/Config/Monetization.luau", '{ Key = "DoubleSpeed", Id = 0,', '{ Key = "DoubleSpeed", Id = 0,')
	end
end
