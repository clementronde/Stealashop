-- a22 : catalogue modifié pour le repli d'une case vide (StoreHeistService.drawContent). Placé
-- avant la mise en place du banc : FALLBACK (écrit par run.sh) dit quels objets retirer de
-- Config/Items avant qu'il soit chargé.
--   "Rare" : plus aucun Rare tirable en zone 3 ;
--   "Low"  : plus aucun Commun ni Peu commun en zone 3 (rien en dessous d'un Commun tiré).
-- a31 (vague 11) : les objets sont retirés par zone et par rareté, et plus par une liste d'ItemId
-- (la zone 3 a 3 Rares depuis les ajouts du 2026-11-07 : Smartphone, Casque VR, Console à double
-- écran) ; le patch marche avec le catalogue à 74 comme à 83 objets.
local RARITIES = if FALLBACK == "Rare" then { "Rare" } else { "Common", "Uncommon" }
local itemsSource = SOURCES["shared/Config/Items.luau"]
for _, rarity in RARITIES do
	local removed = 0
	itemsSource = string.gsub(itemsSource, `\n[^\n]*Id = "Z3_[^"]*"[^\n]*Rarity = "{rarity}"[^\n]*`, function()
		removed += 1
		return ""
	end)
	assert(removed > 0, `banc : aucun objet {rarity} de la zone 3 dans Config/Items.luau`)
end
SOURCES["shared/Config/Items.luau"] = itemsSource
