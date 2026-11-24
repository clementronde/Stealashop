--!nocheck
-- a319, variante « on » : boutique Robux ouverte, Id de DoubleSpeed = 9007.
A319_VARIANT = "on"
A319_PASS_ID = 9007
do
	local function replace(key, from, to)
		local first, last = string.find(SOURCES[key], from, 1, true)
		assert(first, "a319 : remplacement introuvable dans " .. key .. " : " .. from)
		SOURCES[key] = string.sub(SOURCES[key], 1, first - 1) .. to .. string.sub(SOURCES[key], last + 1)
	end
	if 1 == 1 then
		replace("shared/Config/Features.luau", "RobuxShop = false", "RobuxShop = true")
	end
	if 9007 ~= 0 then
		replace("shared/Config/Monetization.luau", '{ Key = "DoubleSpeed", Id = 0,', '{ Key = "DoubleSpeed", Id = 9007,')
	end
end
