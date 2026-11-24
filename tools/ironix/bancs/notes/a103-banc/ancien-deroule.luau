-- a103 (2026-11-12, vague 31, L-112) : le banc qui lit ce fichier vérifie l'ancien déroulé du braquage
-- (colis porté fermé, ouvert en base), gardé derrière Features.ShelfOpen : l'interrupteur y est forcé à
-- false. Sans effet sur un arbre d'avant L-112. Le nouveau déroulé est vérifié par le banc a103.
if SOURCES["shared/Config/Features.luau"] then
	SOURCES["shared/Config/Features.luau"] = (string.gsub(SOURCES["shared/Config/Features.luau"], "ShelfOpen = true", "ShelfOpen = false"))
end
