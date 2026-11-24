--!nocheck
-- a207 (ajout pur, faux Roblox d'a68) : GetPropertyChangedSignal, que RarityFx écoute (Enabled de l'écran) quand plus
-- rien ne bouge. Le signal rendu existe mais ne part jamais (le faux d'a68 ne suit pas les propriétés).
if Methods.GetPropertyChangedSignal == nil then
	function Methods.GetPropertyChangedSignal(self, key)
		local propSignals = rawget(self, "_propSignals")
		if propSignals == nil then
			propSignals = {}
			rawset(self, "_propSignals", propSignals)
		end
		propSignals[key] = propSignals[key] or newSignal()
		return propSignals[key]
	end
end
