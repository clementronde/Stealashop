-- a22 : catalogue modifié pour le repli d'une case vide (StoreHeistService.drawContent). Placé
-- avant la mise en place du banc : FALLBACK (écrit par run.sh) dit quels objets retirer de
-- Config/Items avant qu'il soit chargé.
--   "Rare" : plus aucun Rare tirable en zone 3 (Smartphone, Casque VR) ;
--   "Low"  : plus aucun Commun ni Peu commun en zone 3 (rien en dessous d'un Commun tiré).
local REMOVE = if FALLBACK == "Rare"
	then { "Z3_Smartphone", "Z3_CasqueVr" }
	else { "Z3_Ecouteurs", "Z3_Souris", "Z3_TeleRetro", "Z3_TelephoneAClapet", "Z3_OrdinateurPortable", "Z3_Manette" }
local itemsSource = SOURCES["shared/Config/Items.luau"]
for _, id in REMOVE do
	local before = #itemsSource
	itemsSource = string.gsub(itemsSource, `\n[^\n]*Id = "{id}"[^\n]*`, "")
	assert(#itemsSource < before, `banc : {id} introuvable dans Config/Items.luau`)
end
SOURCES["shared/Config/Items.luau"] = itemsSource
