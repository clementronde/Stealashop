-- a237 (vague 71) : ajout pur au faux Roblox de la copie a101 du banc a42 (stubs.luau), collé juste après lui :
-- Instance:GetPropertyChangedSignal(nom), déclenché quand la propriété change (ZoneBannerController rééteint
-- UI_ZoneBanner rallumé par un autre code au repos). Rien ne change pour un banc qui ne demande pas ce signal.
do
	local probe = newInstance("Folder")
	local mt = getmetatable(probe)
	local base = mt.__newindex
	mt.__newindex = function(self, key, value)
		local props = rawget(self, "_props")
		local old = if props then props[key] else nil
		base(self, key, value)
		local signals = rawget(self, "_propSignals")
		if signals and signals[key] and old ~= value then
			signals[key]:Fire()
		end
	end
	Methods.GetPropertyChangedSignal = function(self, name)
		local signals = rawget(self, "_propSignals")
		if signals == nil then
			signals = {}
			rawset(self, "_propSignals", signals)
		end
		-- newSignal et newInstance : globaux de stubs.luau.
		signals[name] = signals[name] or newSignal()
		return signals[name]
	end
	probe:Destroy()
end
