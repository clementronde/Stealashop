-- a252 : après pre250.luau (`patch` vient de pre249.luau). Les captures du harnais ont lieu dans la rue : « ramasse »
-- met Chase.CatchPickUp.Always à true (le vigile ramasse, l'objet revole sur son rayon) ; « ramasseoff » coupe en plus
-- l'interrupteur Enabled (mesure « avant ») ; « rue » garde les valeurs du dépôt (dans la rue, rien ne change).
if A193_SCENARIO == "ramasse" or A193_SCENARIO == "ramasseoff" then
	patch("shared/Config/Chase.luau", "\t\tAlways = false,", "\t\tAlways = true,")
end
if A193_SCENARIO == "ramasseoff" then
	patch("shared/Config/Chase.luau", "Enabled = true, %-%- V0 : interrupteur", "Enabled = false, -- banc :")
end
if A193_SCENARIO == "nuitoff" then
	patch("shared/Config/Chase.luau", "DayCatchAtNightSendsHome = true,", "DayCatchAtNightSendsHome = false,")
end
