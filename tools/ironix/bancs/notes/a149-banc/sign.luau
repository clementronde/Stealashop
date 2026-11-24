--!nocheck
-- Banc a149 (vague 42), scénario sign, après P1 et P2 du banc a52 (copie a134) : L-157 point 2, UpgradeSign.Gain.
print("\nG1 Gain sur le panneau du tapis")
do
	check(text(guiOf(signAt(treadPoint)), "Gain") == nil, "sans Gain dans le modèle : rien (aucune erreur)")
	-- Clément ajoute Gain sous Level ; panneaux refaits (copies retirées, puis un niveau change).
	new("TextLabel", "Gain", template:FindFirstChild("Board"):FindFirstChild("SignGui")).Text = "+0/s > +0/s"
	for _, s in allSigns() do
		s:Destroy()
	end
	alice:SetAttribute("TreadmillLevel", 4)
	advance(0.2)
	local gui = guiOf(signAt(treadPoint))
	local want = `+{Format.short(Formulas.TreadmillGain(4))}/s > +{Format.short(Formulas.TreadmillGain(5))}/s`
	check(gui ~= nil and text(gui, "Gain") == want and want == "+16/s > +32/s", `niveau enregistré 4 : « {text(gui, "Gain")} » (attendu {want})`)
	check(Find.path(gui, "Gain").Visible ~= false, "… visible")
	local stand = guiOf(signAt(kioskPoint))
	check(stand ~= nil and Find.path(stand, "Gain") and Find.path(stand, "Gain").Visible == false, "panneau des présentoirs : Gain caché")
	alice:SetAttribute("TreadmillLevel", 19)
	advance(0.2)
	gui = guiOf(signAt(treadPoint))
	check(text(gui, "Level") == "Max level" and text(gui, "Gain") == `+{Format.short(Formulas.TreadmillGain(19))}/s`, `niveau max : « {text(gui, "Gain")} » seul`)
	check(text(template:FindFirstChild("Board"):FindFirstChild("SignGui"), "Gain") == "+0/s > +0/s", "modèle d'origine intact")
end
summary()
