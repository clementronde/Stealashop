# a262 (vague 76, 2026-11-19) : banc a31 (catalogue, 9 ajouts). Raretés réattribuées V0 dans l'ordre de l'index (vérifiées
# contre le JSON par a22-core) : la rareté n'est plus comparée à la liste figée ; listes par (zone, rareté) dans l'ordre de
# l'index ; Items.Pick pondéré par DrawWeight (1 / 1,1^(rang − 1)).
return unless has(q{== A. Config/Items : 83 objets, les 9 ajouts du 2026-11-07 (L-055)});
lit(q{		and item.Rarity == a[3]
}, q{		and (a[3] ~= nil or true)
}, 'ajouts rareté');
lit(q{		and table.find(Items.ByZone[a[2]][a[3]], item) ~= nil}, q{		and table.find(Items.ByZone[a[2]][item.Rarity], item) ~= nil}, 'ajouts tirables');
lit(q{item.Zone ~= m[2] or item.Rarity ~= m[3] or item.CategoryId}, q{item.Zone ~= m[2] or item.CategoryId}, 'anciens rareté');
lit(q{check(ids(Items.ByZone[2].Common) == "Z2_CanardEnPlastique,Z2_BallonDeFoot,Z2_OursEnPeluche,Z2_Sucette", "zone 2 Commun : Canard, Ballon de foot, Ours, Sucette")}, q{check(ids(Items.ByZone[2].Common) == "Z2_CanardEnPlastique,Z2_BallonDeFoot,Z2_OursEnPeluche,Z2_Sucette,Z2_BoosterDeCartes,Z2_YoYo,Z2_BarbeAPapa,Z2_BusAImperiale", "zone 2 Commun : Canard, Ballon de foot, Ours, Sucette, Booster, Yo-yo, Barbe à papa, Bus (a262)")}, 'z2c');
lit(q{check(ids(Items.ByZone[2].Uncommon) == "Z2_BoosterDeCartes,Z2_YoYo,Z2_BarbeAPapa,Z2_BusAImperiale,Z2_Skateboard", "zone 2 Peu commun : Booster, Yo-yo, Barbe à papa, Bus, Skateboard")}, q{check(ids(Items.ByZone[2].Uncommon) == "Z2_Skateboard,Z2_MaisonEnPainDEpices,Z2_VoitureTelecommandee,Z2_CarteHolographique,Z2_RobotJouet,Z2_TrainElectrique,Z2_PelucheGeante,Z2_FigurineHolographique", "zone 2 Peu commun : Skateboard … Figurine holographique, 8 objets (a262)")}, 'z2u');
lit(q{check(ids(Items.ByZone[2].Epic) == "Z2_CarteHolographique,Z2_RobotJouet,Z2_TrainElectrique", "zone 2 Épique : Carte holographique, Robot, Train")}, q{check(Items.ByZone[2].Epic == nil or #Items.ByZone[2].Epic == 0, "zone 2 : aucun Épique (a262)")}, 'z2e');
lit(q{check(ids(Items.ByZone[3].Epic) == "Z3_TeleGeante,Z3_ConsoleDeSalon,Z3_ConsolePortable", "zone 3 Épique : Télé géante, Console de salon, Console portable")}, q{check(ids(Items.ByZone[3].Rare) == "Z3_ConsoleDeSalon,Z3_ConsolePortable,Z3_PcGamer,Z3_CarteGraphiqueEnOr" and (Items.ByZone[3].Epic == nil or #Items.ByZone[3].Epic == 0), "zone 3 Rare : Console de salon, Console portable, PC gamer, Carte graphique en or ; aucun Épique (a262)")}, 'z3e');
lit(q{check(ids(Items.ByZone[4].Rare) == "Z4_CollierDePerles,Z4_MontreAGousset,Z4_BasketsDeCollection", "zone 4 Rare : Collier, Montre à gousset, Baskets de collection")}, q{check(ids(Items.ByZone[4].Rare) == "Z4_CollierDePerles,Z4_MontreAGousset,Z4_BasketsDeCollection,Z4_HorlogeDeParquet", "zone 4 Rare : Collier, Montre à gousset, Baskets de collection, Horloge de parquet (a262)")}, 'z4r');
lit(q{		if math.abs((seen[item.Id] or 0) / n - 1 / #list) > tolerance then}, q{		local total = 0
		for _, other in list do
			total += other.DrawWeight
		end
		if math.abs((seen[item.Id] or 0) / n - item.DrawWeight / total) > tolerance then}, 'spread');
