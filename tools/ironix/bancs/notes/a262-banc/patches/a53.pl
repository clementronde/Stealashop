# a262 (vague 76, 2026-11-19) : banc a53 (récompenses). Une rareté minimale absente de la zone fait passer l'objet offert
# à la première zone où elle existe (V0 proposé, UnboxService.GiveItem) : J7 « Épique ou mieux » → zone 4 (au lieu de 3 ou
# 2), et la zone 1 Épique donne aussi un objet de zone 4 ; l'Épique est la rareté la plus haute de la zone 4 : le cas
# « Luxe, au moins Épique » des crans passe en zone 5 (Légendaire possible).
if (has(q{check(luxe and luxe.Zone == 3, "zone 3 (plus haute que le minimum 2)")})) {
	lit(q{check(luxe and luxe.Zone == 3, "zone 3 (plus haute que le minimum 2)")}, q{check(luxe and luxe.Zone == 4, "zone 4 (a262 : première zone des Épiques)")}, 'luxe');
	lit(q{check(#gifts == 1 and gifts[1].entry.Zone == 2, "objet zone 2 (aucun objet : zone 1, relevée à 2)")}, q{check(#gifts == 1 and gifts[1].entry.Zone == 4, "objet zone 4 (a262 : aucun objet, relevée à la première zone des Épiques)")}, 'bob');
	lit(q{	if itemDef == nil or entry.Zone ~= 2 or (itemDef.Zone ~= nil and itemDef.Zone ~= 2) then}, q{	if itemDef == nil or entry.Zone ~= 4 or (itemDef.Zone ~= nil and itemDef.Zone ~= 4) then}, 'allZone');
	lit(q{"tous de la zone 2 (ou Secret, toutes zones, Zone gardée à 2)"}, q{"tous de la zone 4 (a262 : première zone des Épiques)"}, 'allZone msg');
	lit(q{check(z1 == nil and why == "NoContent" and next(dataOf(bob).Items) == nil, "zone 1 Épique : aucune rareté possible (NoContent), rien d'écrit")}, q{check(z1 ~= nil and dataOf(bob).Items[z1] ~= nil and dataOf(bob).Items[z1].Zone == 4, "zone 1 Épique : un objet de la zone 4 (a262)")
if z1 then
	dataOf(bob).Items[z1] = nil
end}, 'z1');
}
lit(q|{ "Luxe", 4, "Epic" } }|, q|{ "Luxe", 5, "Epic" } }|, "crans") if has(q|for _, case in { { "Standard", 3, nil }, { "Premium", 4, nil }, { "Luxe", 4, "Epic" } } do|);
