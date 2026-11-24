-- f70c3 : après pre252.luau (`patch` vient de pre249.luau). « promooff » : Chase.PathAvoid.Enabled coupé (ni modificateur
-- ni coût : le chemin passe par-dessus la table, mesure « avant ») ; « sautoff » : en plus JumpMargin = 0 (saut du rig).
-- f70c3b : « poteauoff » : Chase.Sidestep.Enabled coupé (droit sur le point visé, mesure « avant »).
if A193_SCENARIO == "promooff" or A193_SCENARIO == "sautoff" then
	patch("shared/Config/Chase.luau", "Enabled = true, %-%- V0 : contournement des présentoirs bas", "Enabled = false, -- banc :")
end
if A193_SCENARIO == "sautoff" then
	patch("shared/Config/Chase.luau", "JumpMargin = 2,", "JumpMargin = 0,")
end
if A193_SCENARIO == "poteauoff" then
	patch("shared/Config/Chase.luau", "Enabled = true, %-%- V0 : contournement des poteaux en poursuite directe", "Enabled = false, -- banc :")
end
-- f70c3b : « procheoff » : Chase.ApproachSlowNear = true (l'approche lente d'a224, mesure « avant »). Table et poteau
-- aussi (voleur arrêté : sans l'approche lente, attrapé avant la table ou le poteau, rien à mesurer).
if A193_SCENARIO ~= "proche" then
	patch("shared/Config/Chase.luau", "ApproachSlowNear = false,", "ApproachSlowNear = true,")
end
