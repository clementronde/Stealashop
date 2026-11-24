-- a416 : après pre252.luau (`patch` vient de pre249.luau). Scénario « …avant » : Chase.ClientView.Enabled coupé (la règle
-- d'a193, mesure « avant ») ; « zones », « pings », « heurte » : minimum de la zone 1 très haut
-- (1e300 : voleur toujours sous le minimum, même au plafond de la marche, rapprochement le plus fort, il est attrapé en ligne droite).
do
	local name = A193_SCENARIO
	local avant = string.sub(name, -5) == "avant"
	local base = if avant then string.sub(name, 1, -6) else name
	if avant then
		patch("shared/Config/Chase.luau", "Enabled = true, %-%- V0 proposé %(Cantin, 23/11%), à confirmer", "Enabled = false, -- banc :")
	end
	if base == "zones" or base == "pings" or base == "heurte" then
		patch("shared/Config/Chase.luau", "Zone1SpeedRequired = 10,", "Zone1SpeedRequired = 1e300,")
	end
end
