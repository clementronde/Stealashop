-- a155 : Color3:ToHex() ajouté au faux Roblox (ajout pur).
do
	local mt = getmetatable(Color3.new(0, 0, 0))
	local old = mt.__index
	mt.__index = function(c, k)
		if k == "ToHex" then
			return function(self)
				return string.format("%02X%02X%02X", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5))
			end
		end
		return old(c, k)
	end
end
