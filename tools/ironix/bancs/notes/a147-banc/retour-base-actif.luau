-- a147 (vague 41, 2026-11-14) : faux arbre du banc a36 copié. Features.ReturnToBase passe à false dans le jeu (le
-- bouton BASE n'existe plus depuis la vague 38) ; le banc a36 vérifie encore que l'anti-triche accepte le téléport
-- du retour à la base (ReturnBaseService, toujours dans le code) : dans le faux arbre seulement, l'interrupteur
-- reste à true. Sans effet sur un arbre où il est déjà à true.
do
	for key, src in SOURCES do
		if string.find(key, "Config/Features.luau", 1, true) then
			SOURCES[key] = (string.gsub(src, "\tReturnToBase = false,", "\tReturnToBase = true,"))
		end
	end
end
