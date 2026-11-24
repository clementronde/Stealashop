# a262 (vague 76, 2026-11-20) : banc a116 (ouverture en restant appuyé).
# Serveur (scénario « hold ») : les colis du rayon n'ont plus de type, leur maintien suit leur rareté
# (Commun 0,3 s, Rare 0,6 s, Légendaire 1 s) et la zone 1 n'a que des colis Communs. Pour garder H2 sur les trois
# temps de maintien, la copie de StoreHeistService de CE scénario pose en zone 1, dans l'ordre et en boucle,
# Commun, Rare, Commun, Légendaire, Commun (6 Communs, 2 Rares, 2 Légendaires par rayon de 10 ; drawRarity
# seulement : Config, contenu et revenus inchangés) ; les types lus par le banc passent par A262_TIER (même temps
# de prise).
# Client : les faux colis reçoivent la BoxRarity de leur type (patches/boxtier.pl), lue par HeistController.
if (has(q{H2 maintien trop court refusé})) {
	lit(q{local function drawRarity(zone: number): string?
	local odds = ShelfBoxes.ZoneOdds[zone]}, q{local a262Draws = 0 -- a262 : banc a116 seulement
local A262_CYCLE = { "Common", "Rare", "Common", "Legendary", "Common" }
local function drawRarity(zone: number): string?
	if zone == 1 then
		a262Draws += 1
		return A262_CYCLE[(a262Draws - 1) % #A262_CYCLE + 1]
	end
	local odds = ShelfBoxes.ZoneOdds[zone]}, 'drawRarity zone 1');
}
inc('boxtier') if has(q{== a116 HeistController});
