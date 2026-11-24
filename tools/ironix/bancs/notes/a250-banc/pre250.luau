-- a250 : après pre249.luau (un vigile de nuit par zone) ; « …off » : l'interrupteur a250 du scénario coupé (mesure « avant »).
-- `patch` vient de pre249.luau.
if A193_SCENARIO == "porteoff" then
	patch("shared/Config/Chase.luau", 'StuckThinPrefix = "Shelf",', 'StuckThinPrefix = "",')
elseif A193_SCENARIO == "marcheoff" then
	patch("shared/Config/Chase.luau", "StuckProgressShare = 0.25,", "StuckProgressShare = 0,")
elseif A193_SCENARIO == "detouroff" then
	patch("shared/Config/Chase.luau", "ApproachAlongPath = true,", "ApproachAlongPath = false,")
	patch("shared/Config/Chase.luau", "ApproachBrakeHidden = 20,", "ApproachBrakeHidden = 0,")
end
