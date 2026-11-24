# a262 (vague 76, 2026-11-20) : banc a35 (télémétrie). Chaque zone n'a que ses raretés (Rarities.ZoneOdds) : un colis
# « Rare de la zone 2 » ou « Commun de la zone 5 » n'a plus d'objet dans sa zone. Les colis portés du banc gardent leur
# zone et leur rareté (champs lus par la télémétrie) ; leur objet est le premier de cette rareté dans la zone, sinon
# dans une autre zone (A262_ANY). Funnel : le Smartphone (Peu commun, ~9 $/s) n'encaisse plus 300 $ en 3 s ; Kim
# expose un Épique de la zone 4 (Diamant brut, 450 $/s).
if (has(q{local def = Items.ByZone[}) || has(q{kimData.Items["k-phone"]})) {
	$t = q|A262_ANY = function(zone, rarity)
	local Items = A262_ITEMS
	local list = Items.ByZone[zone] and Items.ByZone[zone][rarity]
	if list and list[1] then
		return list[1]
	end
	for z = 1, 6 do
		local l = Items.ByZone[z] and Items.ByZone[z][rarity]
		if l and l[1] then
			return l[1]
		end
	end
	return nil
end
| . $t;
	lit(q{local def = Items.ByZone[zone][rarity][1]}, q{A262_ITEMS = Items
	local def = A262_ANY(zone, rarity) -- a262 : rareté absente de la zone}, 'boxPayload') if has(q{local def = Items.ByZone[zone][rarity][1]});
	lit(q{local def = Items.ByZone[2].Rare[1]}, q{A262_ITEMS = Items
local def = A262_ANY(2, "Rare") -- a262 : pas de Rare en zone 2}, 'Rare de zone 2', 1) if has(q{local def = Items.ByZone[2].Rare[1]});
	lit(q{kimData.Items["k-phone"] = { Id = "Z3_Smartphone", Source = "NPC", At = 0, Zone = 3 }}, q{kimData.Items["k-phone"] = { Id = "Z4_DiamantBrut", Source = "NPC", At = 0, Zone = 4 } -- a262 : Épique, 450 $/s}, 'funnel') if has(q{kimData.Items["k-phone"] = { Id = "Z3_Smartphone", Source = "NPC", At = 0, Zone = 3 }});
}
