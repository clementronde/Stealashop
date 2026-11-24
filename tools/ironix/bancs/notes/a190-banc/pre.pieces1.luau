-- Scénario « pieces1 » : Config/Hud.TreadmillGain.Pieces = 1 dans la copie des sources (l'ancien affichage).
do
	local key = "shared/Config/Hud.luau"
	SOURCES[key] = (string.gsub(SOURCES[key], "Pieces = 5,", "Pieces = 1,", 1))
end
