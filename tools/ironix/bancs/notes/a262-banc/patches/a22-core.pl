# a262 (vague 76, 2026-11-19) : banc a22-core (catalogue v2). Config/Items.List suit l'ordre de l'index (zone, rareté, puis
# ordre du JSON dans la rareté) ; raretés réattribuées V0 (zone 2 : C 8, U 8 ; zone 3 : C 5, U 5, R 4 ; zone 4 : C 4, U 4,
# R 4, E 3 ; zone 5 : U, R, E, L 3 chacun ; zone 6 : R, E, L, M 3 chacun) ; Items.Pick pondéré par DrawWeight ; Secret en
# zone 6 seulement ; plus de Tutorial.FirstBoxTier ; RetiredV1 figé (même zone, pour la migration des profils) ; un colis
# migré prend la rareté du catalogue (Trône en or : Légendaire, Smartphone : Peu commun).
return unless has(q{== A. Config/Items = docs/claude/notes/objets-catalogue-v2.json});
lit(q{-- a31 : 83 objets depuis}, q{do
	-- a262 : ordre de l'index (INDEX_ORDER, vérifié par le banc a262 : revenus croissants dans chaque zone)
	local pos = {}
	for i, item in Items.List do
		pos[item.Id] = i
	end
	local function key(e)
		return pos[e.Id] or 1e9
	end
	table.sort(expected, function(a, b)
		return key(a) < key(b)
	end)
end
-- a31 : 83 objets depuis}, 'tri index');
lit(q{	[2] = { Common = 4, Uncommon = 5, Rare = 2, Epic = 3, Legendary = 1, Mythic = 1, Total = 16 },
	[3] = { Common = 3, Uncommon = 3, Rare = 3, Epic = 3, Legendary = 1, Mythic = 1, Total = 14 },
	[4] = { Common = 4, Uncommon = 4, Rare = 3, Epic = 2, Legendary = 1, Mythic = 1, Total = 15 },
	[5] = { Common = 3, Uncommon = 3, Rare = 2, Epic = 2, Legendary = 1, Mythic = 1, Total = 12 },
	[6] = { Common = 3, Uncommon = 3, Rare = 2, Epic = 2, Legendary = 1, Mythic = 1, Total = 12 },}, q{	[2] = { Common = 8, Uncommon = 8, Total = 16 },
	[3] = { Common = 5, Uncommon = 5, Rare = 4, Total = 14 },
	[4] = { Common = 4, Uncommon = 4, Rare = 4, Epic = 3, Total = 15 },
	[5] = { Uncommon = 3, Rare = 3, Epic = 3, Legendary = 3, Total = 12 },
	[6] = { Rare = 3, Epic = 3, Legendary = 3, Mythic = 3, Total = 12 },}, 'ZONE_SETS');
lit(q{		total += want[rarity]}, q{		total += want[rarity] or 0}, 'total');
lit(q{(zone 2 : 4, 5, 2, 3, 1, 1 ; zone 3 : 3, 3, 3, 3, 1, 1 ; zone 4 : 4, 4, 3, 2, 1, 1 ; zones 5 et 6 : 3, 3, 2, 2, 1, 1)}, q{(a262 : zone 2 : C 8, U 8 ; zone 3 : C 5, U 5, R 4 ; zone 4 : C 4, U 4, R 4, E 3 ; zone 5 : U, R, E, L 3 ; zone 6 : R, E, L, M 3)}, 'ZONE_SETS msg');
lit(q{check(#Items.ByZone[3].Rare == 3 and Items.ByZone[3].Rare[1].Id == "Z3_Smartphone" and Items.ByZone[3].Rare[2].Id == "Z3_CasqueVr" and Items.ByZone[3].Rare[3].Id == "Z3_ConsoleADoubleEcran", "ByZone[3].Rare = { Smartphone, Casque VR, Console à double écran }")}, q{check(#Items.ByZone[3].Rare == 4 and Items.ByZone[3].Rare[1].Id == "Z3_ConsoleDeSalon" and Items.ByZone[3].Rare[2].Id == "Z3_ConsolePortable" and Items.ByZone[3].Rare[3].Id == "Z3_PcGamer" and Items.ByZone[3].Rare[4].Id == "Z3_CarteGraphiqueEnOr", "ByZone[3].Rare = { Console de salon, Console portable, PC gamer, Carte graphique en or } (a262)")}, 'ByZone3');
lit(q{local d3 = draws(3, "Common", 30000)}, q{local function share(list, item)
	local total = 0
	for _, other in list do
		total += other.DrawWeight
	end
	return item.DrawWeight / total
end
local d3 = draws(3, "Common", 30000)}, 'share');
lit(q{	if math.abs(share - 1 / 3) > 0.02 then}, q{	if math.abs(share - share_(Items.ByZone[3].Common, item)) > 0.02 then}, 'spread3');
lit(q{	local share = (d3[item.Id] or 0) / 30000}, q{	local share_ = share
	local share = (d3[item.Id] or 0) / 30000}, 'spread3b');
lit(q{"zone 3 Commun : chacun des 3 objets ≈ 1/3 des 30 000 tirages (± 2 %)"}, q{"zone 3 Commun : chacun des 5 objets ≈ sa part de DrawWeight des 30 000 tirages (± 2 %, a262)"}, 'spread3 msg');
lit(q{	if math.abs((d1[item.Id] or 0) / 24000 - 1 / 12) > 0.01 then}, q{	if math.abs((d1[item.Id] or 0) / 24000 - share(Items.ByZone[1].Common, item)) > 0.01 then}, 'spread1');
lit(q{"zone 1 Commun : chacun des 12 objets ≈ 1/12 des tirages (± 1 %)"}, q{"zone 1 Commun : chacun des 12 objets ≈ sa part de DrawWeight des tirages (± 1 %, a262)"}, 'spread1 msg');
lit(q{	if item == nil or item.Id ~= "Secret_ChatPorteBonheurDore" then}, q{	if (zone == 6) ~= (item ~= nil) or (item ~= nil and item.Id ~= "Secret_ChatPorteBonheurDore") then}, 'secret');
lit(q{"Secret : le Chat porte-bonheur doré, quelle que soit la zone"}, q{"Secret : le Chat porte-bonheur doré en zone 6, nil ailleurs (a262)"}, 'secret msg');
lit(q{ and Tutorial.FirstBoxTier == "Premium", "objet garanti : TutorialOnly, zone 1, Rare (a169 : Tutorial.GuaranteedRarity retiré, lu par personne), colis Premium"}, q{, "objet garanti : TutorialOnly, zone 1, Rare (a262 : plus de Tutorial.FirstBoxTier)"}, 'FirstBoxTier');
lit(q{	if want ~= new or Items.ById[old] ~= nil then}, q{	if v1 == nil or Items.ById[new] == nil or Items.ById[new].Zone ~= v1[1] or Items.ById[old] ~= nil then}, 'retirés');
lit(q{"chaque retiré → premier objet tirable de même zone et rareté, sinon la rareté la plus proche en dessous"}, q{"chaque retiré → un objet de la même zone (a262 : table figée pour la migration des profils)"}, 'retirés msg');
lit(q{b["1"].Rarity == "Epic" and b["1"].Tier == "Luxe"}, q{b["1"].Rarity == "Legendary" and b["1"].Tier == "Luxe"}, 'b1');
lit(q{b["6"].ItemId == "Z3_Smartphone" and b["6"].Rarity == "Rare"}, q{b["6"].ItemId == "Z3_Smartphone" and b["6"].Rarity == "Uncommon"}, 'b6');
