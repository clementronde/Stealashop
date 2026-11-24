--!nocheck
-- Tout coupé pour le scénario « off » : ni vitrine Robux, ni aperçu Rebirth, ni index (les valeurs
-- d'avant L-071). Les vraies sources, modifiées en texte avant leur chargement.
local function replace(key, from, to)
	local source = SOURCES[key]
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. to .. string.sub(source, last + 1)
end
local F = "shared/Config/Features.luau"
replace(F, "RobuxShopPreview = true,", "RobuxShopPreview = false,")
replace(F, "Index = true,", "Index = false,")
replace(F, "RebirthPreview = true,", "RebirthPreview = false,")
