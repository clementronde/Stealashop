---------------------------------------------------------------- a401 (vague GC4, 23/11) : avant setup.luau
-- setup.luau (banc a60) rallume la case qui vole (UiMotion.CashFly.Enabled = true) dans sa copie des sources ; dans le
-- jeu elle est coupée (L-091), et l'encaissement d'a401 ne passe que sans case : le commentaire visé par setup.luau est
-- changé ici, la case reste coupée comme dans le jeu.
do
	local key = "shared/Config/UiMotion.luau"
	if SOURCES[key] then
		SOURCES[key] = (string.gsub(SOURCES[key], "true remet la case%.\n", "true remet la case (a401).\n", 1))
	end
end
