--!nocheck
-- Scénario divine : la table des caisses Communes devient { Common = 1, Divine = 1 } (aucun objet Divine au
-- catalogue : l'objet doit retomber sur la rareté la plus proche en dessous qui en a, Secret).
do
	local src = SOURCES["shared/Config/ShelfOpen.luau"]
	local out, n = string.gsub(src, "\n(%s*)Common = { Common = [^\n]*", "\n%1Common = { Common = 1, Divine = 1 },", 1)
	assert(n == 1, "pre.divine : table Common introuvable")
	SOURCES["shared/Config/ShelfOpen.luau"] = out
end
