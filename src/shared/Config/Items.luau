--!strict
-- Catalogue des objets v2 (liaison L-045, validé par Clément le 2026-11-07 ; DEV-020, MOD-014,
-- MOD-026, MOD-031) : 83 objets, 4 catégories par zone (5 en zone 4), plusieurs objets par zone et
-- par rareté, plus le Secret. Source : docs/claude/notes/objets-catalogue-v2.json, recopié ici en
-- Luau. Le JSON n'est jamais lu à l'exécution ; le banc hors Studio a22-core vérifie que ce fichier
-- lui est fidèle (mêmes objets, même ordre, mêmes champs).
--
-- Règles du catalogue (docs/claude/notes/objets-catalogue-v2.md) :
--   - zone 1 (zone tuto) : 12 Communs, 3 par catégorie, plus le Pot de nouilles (Rare), qui ne sort
--     que du premier colis du tuto (TutorialOnly ; Tutorial.GuaranteedItemId), jamais d'un tirage ;
--   - zones 2 à 6 : 12 objets chacune au départ (3 Communs, 3 Peu communs, 2 Rares, 2 Épiques,
--     1 Légendaire, 1 Mythique), plus 9 objets du quotidien ajoutés par Clément le 2026-11-07
--     (L-055) : zone 2 = 16 objets, zone 3 = 14, zone 4 = 15 avec la catégorie Mode (Fashion) ;
--   - vague 76 (Cantin et Clément, 19/11) : raretés par zone (Rarities.ZoneOdds : Z1 Commun, Z2 + Peu commun,
--     Z3 + Rare, Z4 Commun à Épique, Z5 Peu commun à Légendaire, Z6 Rare à Mythique et le Secret), raretés des
--     objets réattribuées V0 (a262) dans l'ordre de l'index (INDEX_ORDER, plus bas) ;
--   - tirage d'un colis (StoreHeistService) : la rareté du colis (Rarities.ZoneOdds), celle de l'objet
--     (ShelfBoxes.ContentWeights), puis un objet de la zone et de cette rareté, pondéré par DrawWeight (Items.Pick).
--
-- ItemId = nom du modèle sans le préfixe ITM_ (convention 10.3 et 9.5) : modèle
-- `ITM_Z3_Smartphone` <-> ItemId "Z3_Smartphone", stocké dans Items[uid].Id du profil.
-- Textes affichés, en anglais (L-036) : DisplayName (nom de l'objet) et Category (sa catégorie,
-- sur l'étiquette BB_Box des colis, L-031). Le Secret n'a pas de zone ; sa catégorie affichée est
-- « ??? ». Revenu d'un objet : Formulas.ItemIncome (vague 76 : rareté, zone, rang, M global).
--
-- API (partagée avec l'ouverture des colis, agent a23) :
--   Items.List: { Item }
--       Les 83 objets : zone par zone dans l'ordre de l'index (vague 76), puis le Secret.
--   Items.ById: { [ItemId]: Item }
--   Items.ByZone[zone][rarity]: { Item }
--       Objets tirables de cette zone et de cette rareté, dans l'ordre de l'index, sans les
--       TutorialOnly. Existe pour les 6 raretés de Commun à Mythique (pas pour Secret) ; liste
--       vide s'il n'y a aucun objet (raretés absentes de la zone, Rarities.ZoneOdds).
--   Items.Secrets: { Item }
--       Tirés quand la rareté est Secret, quelle que soit la zone.
--   Items.Divines: { Item }
--       Tirés quand la rareté est Divine, quelle que soit la zone (L-106 ; aucun objet encore).
--   Items.Exclusives: { Item }
--       a285 : objets de la caisse exclusive de la boutique Robux (dans ById, jamais dans List ni tirés).
--   Items.AllZones[rarity]: { Item }?
--       Secrets ou Divines pour ces deux raretés, nil pour une rareté rangée par zone.
--   Items.Pick(zone, rarity, rng?) -> Item?
--       Un objet au hasard (vague 76 : pondéré par DrawWeight) parmi ByZone[zone][rarity], ou parmi AllZones[rarity] pour "Secret" (zones de
--       Rarities.ZoneOdds qui l'ont : la 6) et "Divine" (toutes zones) ; nil si la liste est vide ou la zone inconnue. Jamais un objet
--       TutorialOnly.
--       rng : le Random de l'appelant, sinon celui de ce module.
--   Items.RenamedV1, Items.RetiredV1: { [ancien ItemId]: ItemId v2 }
--       ItemId du catalogue v1 absents de la v2 (voir plus bas) : migration des profils
--       (DataService) et noms de modèles refusés par le ContractChecker.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Rarities = require(script.Parent.Rarities)

export type Item = {
	Id: string, -- ItemId
	DisplayName: string, -- nom affiché, en anglais (L-036)
	Zone: number?, -- nil pour un Secret (toutes zones)
	Rarity: Rarities.RarityId,
	Asset: string, -- nom du modèle dans ReplicatedStorage/Assets : ITM_<ItemId>
	Category: string, -- catégorie affichée, en anglais (étiquette BB_Box) ; « ??? » pour le Secret
	CategoryId: string, -- identifiant de la catégorie, sans accent (« Legumes ») ; « Secret » pour le Secret (V0)
	TutorialOnly: boolean, -- ne sort que du premier colis du tuto, jamais d'un tirage (Pot de nouilles)
	Rank: number, -- vague 76 : rang dans sa rareté et sa zone, dans l'ordre de l'index (1 = le moins rentable)
	DrawWeight: number, -- vague 76 : poids au tirage dans sa rareté et sa zone, 1 / 1,1^(Rank − 1) (Items.Pick)
}

type Entry = { Id: string, Name: string, Rarity: Rarities.RarityId, TutorialOnly: boolean? }
type CategoryEntry = { Id: string, Name: string, Items: { Entry } }

-- Raretés tirées dans une zone, dans l'ordre (le Secret est tiré toutes zones confondues).
local ZONE_RARITIES: { Rarities.RarityId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- [zone] = catégories dans l'ordre du catalogue : Id (sans accent), Name (affiché, en anglais) et
-- objets { ItemId, nom affiché en anglais, rareté } ; en commentaire, le nom français du doc.
local CATALOG: { { CategoryEntry } } = {
	{ -- Zone 1 : Supérette, Kiosque
		{
			Id = "Boisson",
			Name = "Drink",
			Items = {
				{ Id = "Z1_CanetteDeSoda", Name = "Soda Can", Rarity = "Common" }, -- Canette de soda
				{ Id = "Z1_BoissonEnergisante", Name = "Energy Drink", Rarity = "Common" }, -- Boisson énergisante
				{ Id = "Z1_BriqueDeLait", Name = "Milk Carton", Rarity = "Common" }, -- Brique de lait
			},
		},
		{
			Id = "Snack",
			Name = "Snack",
			Items = {
				{ Id = "Z1_PaquetDeChips", Name = "Bag of Chips", Rarity = "Common" }, -- Paquet de chips
				{ Id = "Z1_Donut", Name = "Donut", Rarity = "Common" }, -- Donut
				{ Id = "Z1_HotDog", Name = "Hot Dog", Rarity = "Common" }, -- Hot-dog
				{ Id = "Z1_PotDeNouilles", Name = "Instant Noodles", Rarity = "Rare", TutorialOnly = true }, -- Pot de nouilles (tuto, renaissance 1)
			},
		},
		{
			Id = "Fruit",
			Name = "Fruit",
			Items = {
				{ Id = "Z1_Banane", Name = "Banana", Rarity = "Common" }, -- Banane
				{ Id = "Z1_Ananas", Name = "Pineapple", Rarity = "Common" }, -- Ananas
				{ Id = "Z1_Pasteque", Name = "Watermelon", Rarity = "Common" }, -- Pastèque
			},
		},
		{
			Id = "Legumes",
			Name = "Vegetable",
			Items = {
				{ Id = "Z1_Carotte", Name = "Carrot", Rarity = "Common" }, -- Carotte
				{ Id = "Z1_Brocoli", Name = "Broccoli", Rarity = "Common" }, -- Brocoli
				{ Id = "Z1_EpiDeMais", Name = "Corn Cob", Rarity = "Common" }, -- Épi de maïs
			},
		},
	},
	{ -- Zone 2 : Londres, magasin de jouets et confiserie
		{
			Id = "Jouet",
			Name = "Toy",
			Items = {
				{ Id = "Z2_CanardEnPlastique", Name = "Rubber Duck", Rarity = "Common" }, -- Canard en plastique
				{ Id = "Z2_BallonDeFoot", Name = "Soccer Ball", Rarity = "Common" }, -- Ballon de foot (ajout du 2026-11-07)
				{ Id = "Z2_BoosterDeCartes", Name = "Card Booster Pack", Rarity = "Common" }, -- Booster de cartes (ajout du 2026-11-07)
				{ Id = "Z2_YoYo", Name = "Yo-Yo", Rarity = "Common" }, -- Yo-yo
				{ Id = "Z2_CarteHolographique", Name = "Holo Card", Rarity = "Uncommon" }, -- Carte holographique (ajout du 2026-11-07)
				{ Id = "Z2_RobotJouet", Name = "Toy Robot", Rarity = "Uncommon" }, -- Robot jouet
				{ Id = "Z2_FigurineHolographique", Name = "Hologram Figure", Rarity = "Uncommon" }, -- Figurine holographique
			},
		},
		{
			Id = "Peluche",
			Name = "Plush",
			Items = {
				{ Id = "Z2_OursEnPeluche", Name = "Teddy Bear", Rarity = "Common" }, -- Ours en peluche
				{ Id = "Z2_PelucheGeante", Name = "Giant Plush", Rarity = "Uncommon" }, -- Peluche géante
			},
		},
		{
			Id = "Bonbon",
			Name = "Candy",
			Items = {
				{ Id = "Z2_Sucette", Name = "Lollipop", Rarity = "Common" }, -- Sucette
				{ Id = "Z2_BarbeAPapa", Name = "Cotton Candy", Rarity = "Common" }, -- Barbe à papa
				{ Id = "Z2_MaisonEnPainDEpices", Name = "Gingerbread House", Rarity = "Uncommon" }, -- Maison en pain d'épices
			},
		},
		{
			Id = "Vehicule",
			Name = "Vehicle",
			Items = {
				{ Id = "Z2_BusAImperiale", Name = "Double-Decker Bus", Rarity = "Common" }, -- Bus à impériale
				{ Id = "Z2_Skateboard", Name = "Skateboard", Rarity = "Uncommon" }, -- Skateboard (ajout du 2026-11-07)
				{ Id = "Z2_VoitureTelecommandee", Name = "RC Car", Rarity = "Uncommon" }, -- Voiture télécommandée
				{ Id = "Z2_TrainElectrique", Name = "Toy Train", Rarity = "Uncommon" }, -- Train électrique
			},
		},
	},
	{ -- Zone 3 : Tokyo, électronique et jeux vidéo
		{
			Id = "Telephone",
			Name = "Phone",
			Items = {
				{ Id = "Z3_Ecouteurs", Name = "Earbuds", Rarity = "Common" }, -- Écouteurs
				{ Id = "Z3_TelephoneAClapet", Name = "Flip Phone", Rarity = "Common" }, -- Téléphone à clapet
				{ Id = "Z3_Smartphone", Name = "Smartphone", Rarity = "Uncommon" }, -- Smartphone
			},
		},
		{
			Id = "Ordinateur",
			Name = "Computer",
			Items = {
				{ Id = "Z3_Souris", Name = "Computer Mouse", Rarity = "Common" }, -- Souris
				{ Id = "Z3_OrdinateurPortable", Name = "Laptop", Rarity = "Common" }, -- Ordinateur portable
				{ Id = "Z3_PcGamer", Name = "Gaming PC", Rarity = "Rare" }, -- PC gamer
				{ Id = "Z3_CarteGraphiqueEnOr", Name = "Golden Graphics Card", Rarity = "Rare" }, -- Carte graphique en or
			},
		},
		{
			Id = "Tele",
			Name = "TV",
			Items = {
				{ Id = "Z3_TeleRetro", Name = "Retro TV", Rarity = "Common" }, -- Télé rétro
				{ Id = "Z3_TeleGeante", Name = "Giant TV", Rarity = "Uncommon" }, -- Télé géante
			},
		},
		{
			Id = "Console",
			Name = "Console",
			Items = {
				{ Id = "Z3_Manette", Name = "Game Controller", Rarity = "Uncommon" }, -- Manette
				{ Id = "Z3_CasqueVr", Name = "VR Headset", Rarity = "Uncommon" }, -- Casque VR
				{ Id = "Z3_ConsoleADoubleEcran", Name = "Dual-Screen Console", Rarity = "Uncommon" }, -- Console à double écran (ajout du 2026-11-07)
				{ Id = "Z3_ConsoleDeSalon", Name = "Home Console", Rarity = "Rare" }, -- Console de salon (ajout du 2026-11-07)
				{ Id = "Z3_ConsolePortable", Name = "Handheld Console", Rarity = "Rare" }, -- Console portable
			},
		},
	},
	{ -- Zone 4 : Los Angeles, bijouterie et horlogerie
		{
			Id = "Bijou",
			Name = "Jewelry",
			Items = {
				{ Id = "Z4_Bague", Name = "Ring", Rarity = "Common" }, -- Bague
				{ Id = "Z4_ChaineEnOr", Name = "Gold Chain", Rarity = "Uncommon" }, -- Chaîne en or
				{ Id = "Z4_CollierDePerles", Name = "Pearl Necklace", Rarity = "Rare" }, -- Collier de perles
			},
		},
		{
			Id = "Montre",
			Name = "Watch",
			Items = {
				{ Id = "Z4_MontreEnOr", Name = "Gold Watch", Rarity = "Common" }, -- Montre en or (v1 : Z4_Montre)
				{ Id = "Z4_CoffretDeMontres", Name = "Watch Box", Rarity = "Uncommon" }, -- Coffret de montres
				{ Id = "Z4_MontreAGousset", Name = "Pocket Watch", Rarity = "Rare" }, -- Montre à gousset
			},
		},
		{
			Id = "Horloge",
			Name = "Clock",
			Items = {
				{ Id = "Z4_PenduleDoree", Name = "Golden Clock", Rarity = "Common" }, -- Pendule dorée
				{ Id = "Z4_HorlogeDeParquet", Name = "Grandfather Clock", Rarity = "Rare" }, -- Horloge de parquet
			},
		},
		{
			Id = "Mode", -- catégorie ajoutée par Clément le 2026-11-07 (L-055)
			Name = "Fashion",
			Items = {
				{ Id = "Z4_Parfum", Name = "Perfume", Rarity = "Common" }, -- Parfum (ajout du 2026-11-07)
				{ Id = "Z4_LunettesDeStar", Name = "Star Sunglasses", Rarity = "Uncommon" }, -- Lunettes de star (ajout du 2026-11-07)
				{ Id = "Z4_BasketsDeCollection", Name = "Collector Sneakers", Rarity = "Rare" }, -- Baskets de collection (ajout du 2026-11-07)
			},
		},
		{
			Id = "Joyau",
			Name = "Jewel",
			Items = {
				{ Id = "Z4_Rubis", Name = "Ruby", Rarity = "Uncommon" }, -- Rubis
				{ Id = "Z4_DiamantBrut", Name = "Rough Diamond", Rarity = "Epic" }, -- Diamant brut
				{ Id = "Z4_Couronne", Name = "Crown", Rarity = "Epic" }, -- Couronne
				{ Id = "Z4_OeufEnDiamant", Name = "Diamond Egg", Rarity = "Epic" }, -- Œuf en diamant
			},
		},
	},
	{ -- Zone 5 : Paris, galerie d'art et antiquaire
		{
			Id = "Tableau",
			Name = "Painting",
			Items = {
				{ Id = "Z5_TableauDeMaitre", Name = "Classic Painting", Rarity = "Uncommon" }, -- Tableau de maître
				{ Id = "Z5_LaJoconde", Name = "Mona Lisa", Rarity = "Epic" }, -- La Joconde
			},
		},
		{
			Id = "Sculpture",
			Name = "Sculpture",
			Items = {
				{ Id = "Z5_BusteEnMarbre", Name = "Marble Bust", Rarity = "Uncommon" }, -- Buste en marbre
				{ Id = "Z5_TourEiffelEnBronze", Name = "Bronze Eiffel Tower", Rarity = "Rare" }, -- Tour Eiffel en bronze
				{ Id = "Z5_LePenseur", Name = "The Thinker", Rarity = "Rare" }, -- Le Penseur
				{ Id = "Z5_StatueDoree", Name = "Golden Statue", Rarity = "Epic" }, -- Statue dorée
			},
		},
		{
			Id = "Antiquite",
			Name = "Antique",
			Items = {
				{ Id = "Z5_VaseAncien", Name = "Ancient Vase", Rarity = "Uncommon" }, -- Vase ancien (v1 : Z5_Vase)
				{ Id = "Z5_LustreEnCristal", Name = "Crystal Chandelier", Rarity = "Rare" }, -- Lustre en cristal
				{ Id = "Z5_ArmureDeChevalier", Name = "Knight Armor", Rarity = "Epic" }, -- Armure de chevalier
			},
		},
		{
			Id = "Relique",
			Name = "Relic",
			Items = {
				{ Id = "Z5_Sarcophage", Name = "Sarcophagus", Rarity = "Legendary" }, -- Sarcophage
				{ Id = "Z5_MasqueAncien", Name = "Ancient Mask", Rarity = "Legendary" }, -- Masque ancien
				{ Id = "Z5_Meteorite", Name = "Meteorite", Rarity = "Legendary" }, -- Météorite
			},
		},
	},
	{ -- Zone 6 : New York, banque et salle des coffres
		{
			Id = "Tresor",
			Name = "Treasure",
			Items = {
				{ Id = "Z6_LingotDOr", Name = "Gold Bar", Rarity = "Rare" }, -- Lingot d'or
				{ Id = "Z6_SceptreRoyal", Name = "Royal Scepter", Rarity = "Rare" }, -- Sceptre royal
				{ Id = "Z6_PyramideDeLingots", Name = "Gold Bar Pyramid", Rarity = "Epic" }, -- Pyramide de lingots
				{ Id = "Z6_TroneEnOr", Name = "Golden Throne", Rarity = "Legendary" }, -- Trône en or
			},
		},
		{
			Id = "Joyau",
			Name = "Jewel",
			Items = {
				{ Id = "Z6_SacDeDiamants", Name = "Bag of Diamonds", Rarity = "Epic" }, -- Sac de diamants
				{ Id = "Z6_DiamantGeant", Name = "Giant Diamond", Rarity = "Legendary" }, -- Diamant géant
			},
		},
		{
			Id = "Statue",
			Name = "Statue",
			Items = {
				{ Id = "Z6_AigleDeCristal", Name = "Crystal Eagle", Rarity = "Rare" }, -- Aigle de cristal
				{ Id = "Z6_TaureauEnOr", Name = "Golden Bull", Rarity = "Legendary" }, -- Taureau en or
				{ Id = "Z6_StatueDeLaLiberte", Name = "Statue of Liberty", Rarity = "Mythic" }, -- Statue de la Liberté
			},
		},
		{
			Id = "Coffre",
			Name = "Vault",
			Items = {
				{ Id = "Z6_CoffreFortBlinde", Name = "Armored Safe", Rarity = "Epic" }, -- Coffre-fort blindé
				{ Id = "Z6_CoffreDeDiamants", Name = "Diamond Chest", Rarity = "Mythic" }, -- Coffre de diamants
				{ Id = "Z6_CleDuCoffreUltime", Name = "Ultimate Vault Key", Rarity = "Mythic" }, -- Clé du coffre ultime
			},
		},
	},
}

-- Vague 76 (Cantin et Clément, 19/11) : ordre de l'index dans chaque zone, du moins au plus rentable (rareté, puis
-- rang dans la rareté). Le rang d'un objet dans sa rareté et sa zone fixe son revenu (+10 % par rang, Formulas.ItemIncome)
-- et sa chance au tirage (inverse de son revenu relatif, DrawWeight). Raretés réattribuées V0 (a262) dans l'ordre de
-- l'index d'avant (rareté puis catalogue), parts égales entre les raretés de la zone, le reste aux plus basses ; le
-- Pot de nouilles (TutorialOnly, Rare) ferme la zone 1. Chaque objet d'une zone y figure une fois (vérifié plus bas).
local INDEX_ORDER: { { string } } = {
	{ -- Zone 1 : 12 Communs, puis le Pot de nouilles
		"Z1_CanetteDeSoda", "Z1_BoissonEnergisante", "Z1_BriqueDeLait", "Z1_PaquetDeChips", "Z1_Donut", "Z1_HotDog",
		"Z1_Banane", "Z1_Ananas", "Z1_Pasteque", "Z1_Carotte", "Z1_Brocoli", "Z1_EpiDeMais", "Z1_PotDeNouilles",
	},
	{ -- Zone 2 : 8 Communs, 8 Peu communs
		"Z2_CanardEnPlastique", "Z2_BallonDeFoot", "Z2_OursEnPeluche", "Z2_Sucette", "Z2_BoosterDeCartes", "Z2_YoYo",
		"Z2_BarbeAPapa", "Z2_BusAImperiale",
		"Z2_Skateboard", "Z2_MaisonEnPainDEpices", "Z2_VoitureTelecommandee", "Z2_CarteHolographique", "Z2_RobotJouet",
		"Z2_TrainElectrique", "Z2_PelucheGeante", "Z2_FigurineHolographique",
	},
	{ -- Zone 3 : 5 Communs, 5 Peu communs, 4 Rares
		"Z3_Ecouteurs", "Z3_Souris", "Z3_TeleRetro", "Z3_TelephoneAClapet", "Z3_OrdinateurPortable",
		"Z3_Manette", "Z3_Smartphone", "Z3_CasqueVr", "Z3_ConsoleADoubleEcran", "Z3_TeleGeante",
		"Z3_ConsoleDeSalon", "Z3_ConsolePortable", "Z3_PcGamer", "Z3_CarteGraphiqueEnOr",
	},
	{ -- Zone 4 : 4 Communs, 4 Peu communs, 4 Rares, 3 Épiques
		"Z4_Bague", "Z4_MontreEnOr", "Z4_PenduleDoree", "Z4_Parfum",
		"Z4_ChaineEnOr", "Z4_CoffretDeMontres", "Z4_LunettesDeStar", "Z4_Rubis",
		"Z4_CollierDePerles", "Z4_MontreAGousset", "Z4_BasketsDeCollection", "Z4_HorlogeDeParquet",
		"Z4_DiamantBrut", "Z4_Couronne", "Z4_OeufEnDiamant",
	},
	{ -- Zone 5 : 3 Peu communs, 3 Rares, 3 Épiques, 3 Légendaires
		"Z5_TableauDeMaitre", "Z5_BusteEnMarbre", "Z5_VaseAncien",
		"Z5_TourEiffelEnBronze", "Z5_LePenseur", "Z5_LustreEnCristal",
		"Z5_StatueDoree", "Z5_ArmureDeChevalier", "Z5_LaJoconde",
		"Z5_Sarcophage", "Z5_MasqueAncien", "Z5_Meteorite",
	},
	{ -- Zone 6 : 3 Rares, 3 Épiques, 3 Légendaires, 3 Mythiques (plus le Secret, toutes zones)
		"Z6_LingotDOr", "Z6_SceptreRoyal", "Z6_AigleDeCristal",
		"Z6_PyramideDeLingots", "Z6_SacDeDiamants", "Z6_CoffreFortBlinde",
		"Z6_DiamantGeant", "Z6_TaureauEnOr", "Z6_TroneEnOr",
		"Z6_StatueDeLaLiberte", "Z6_CoffreDeDiamants", "Z6_CleDuCoffreUltime",
	},
}

-- Secrets, toutes zones ; vague 76 : tirés seulement en zone 6 (Rarities.ZoneOdds).
local SECRETS: { Entry } = {
	{ Id = "Secret_ChatPorteBonheurDore", Name = "Golden Lucky Cat", Rarity = "Secret" }, -- Chat porte-bonheur doré
}
local SECRET_CATEGORY = "???" -- catégorie affichée d'un Secret (catalogue v2)
local SECRET_CATEGORY_ID = "Secret" -- V0 proposé, absent du JSON (qui ne donne pas d'id au Secret)

-- Divines, toutes zones comme les Secrets (rareté créée par Clément le 2026-11-12, L-106 point 1).
-- Aucun objet au catalogue pour l'instant : sa chance de tirage reste à 0 (Rarities.BoxOdds) et
-- Items.Pick(zone, "Divine") rend nil. Un objet ajouté ici : { Id = "Divine_<Nom>", Name = "...",
-- Rarity = "Divine" }, modèle ITM_Divine_<Nom>, icône ICON_Divine_<Nom>.
local DIVINES: { Entry } = {}
local DIVINE_CATEGORY = "???" -- V0 proposé, absent du doc : comme le Secret
local DIVINE_CATEGORY_ID = "Divine" -- V0 proposé, absent du doc

-- a285 (21/11) : objets de la caisse exclusive de la boutique Robux (Monetization.Crate.Items), un par case de
-- `UI_RobuxShop_v2.Crate.Odds`, de Odd_1 à Odd_6 (L-247, L-216 point 9, L-252 ; icônes ICON_Exclusive_* de
-- tools/clement/ui_v5_robuxshop_v3_build.luau, EXCLUSIVE_IDS ; raretés des cases ICON_BOX_*). Jamais tirés
-- d'un colis, absents de l'index et d'Items.List : on ne les a qu'en achetant la caisse (MonetizationService).
-- Modèle ITM_Exclusive_<Nom> (repli : bloc à la couleur de la rareté, DisplayService), icône ICON_Exclusive_<Nom>.
-- a294 (L-276) : la Disco Ball passe de Rare à Épique, la caisse payante donne toujours au moins un Épique.
local EXCLUSIVES: { Entry } = {
	{ Id = "Exclusive_DiscoBall", Name = "Disco Ball", Rarity = "Epic" }, -- validé par Cantin, 21/11 (a294 ; avant : Rare)
	{ Id = "Exclusive_GoldenGramophone", Name = "Golden Gramophone", Rarity = "Epic" },
	{ Id = "Exclusive_GoldenRocket", Name = "Golden Rocket", Rarity = "Legendary" },
	{ Id = "Exclusive_CrystalSkull", Name = "Crystal Skull", Rarity = "Mythic" },
	{ Id = "Exclusive_NeonJukebox", Name = "Neon Jukebox", Rarity = "Secret" },
	{ Id = "Exclusive_GoldenPlanet", Name = "Golden Planet", Rarity = "Divine" },
}
local EXCLUSIVE_CATEGORY = "Exclusive" -- V0 proposé le 2026-11-21 (a285), absent du doc
local EXCLUSIVE_CATEGORY_ID = "Exclusive" -- V0 proposé le 2026-11-21 (a285), absent du doc

-- Anciens ItemId du catalogue v1 (doc 10.5), absents de la v2. Lus par la migration v1 → v2 des
-- profils (DataService, MIGRATIONS[2]) et par le ContractChecker (Contract/Models : un modèle
-- ITM_ qui porte encore un de ces noms est signalé).
-- Renommés, même objet (objets-catalogue-v2.md, « Pour Ironix ») :
local RENAMED_V1: { [string]: string } = {
	Z4_Montre = "Z4_MontreEnOr",
	Z5_Vase = "Z5_VaseAncien",
}
-- Retirés (objets-catalogue-v2.md, « Retirés de la v1 ») : l'objet v2 qui les remplace dans un
-- profil. Règle (choix de l'agent a22, V0 à confirmer par Ironix) : le premier objet tirable
-- (Items.ByZone, ordre du catalogue) de la même zone et de la même rareté qu'en v1, sinon de la
-- rareté la plus proche en dessous. La zone 1 n'a plus que des Communs : le Ticket à gratter
-- (Légendaire) et le Hot-dog en or (Mythique) deviennent une Canette de soda.
local RETIRED_V1: { [string]: string } = {
	Z1_TicketAGratterGagnant = "Z1_CanetteDeSoda", -- Légendaire en v1 → Commun
	Z1_HotDogEnOr = "Z1_CanetteDeSoda", -- Mythique en v1 → Commun
	Z5_ToileAbstraite = "Z5_StatueDoree", -- Rare
	Z6_LiasseDeBillets = "Z6_LingotDOr", -- Commun
	Z6_SacDePieces = "Z6_PyramideDeLingots", -- Peu commun
	Z6_MalletteDeBillets = "Z6_TroneEnOr", -- Épique
}

local List: { Item } = {}
local ById: { [string]: Item } = {}
local ByZone: { [number]: { [string]: { Item } } } = {} -- [zone][RarityId] = objets tirables
local Secrets: { Item } = {}
local Divines: { Item } = {}
local Exclusives: { Item } = {}

local function add(item: Item, listed: boolean?)
	assert(ById[item.Id] == nil, `Config.Items : ItemId en double {item.Id}`)
	assert(Rarities.ById[item.Rarity] ~= nil, `Config.Items : {item.Id} a une rareté inconnue ({item.Rarity})`)
	if listed ~= false then
		table.insert(List, item)
	end
	ById[item.Id] = item
end

for zone, categories in CATALOG do
	local byRarity: { [string]: { Item } } = {}
	for _, rarity in ZONE_RARITIES do
		byRarity[rarity] = {}
	end
	ByZone[zone] = byRarity
	local made: { [string]: Item } = {}
	local count = 0
	for _, category in categories do
		for _, entry in category.Items do
			assert(string.sub(entry.Id, 1, 3) == `Z{zone}_`, `Config.Items : {entry.Id} rangé en zone {zone}`)
			assert(made[entry.Id] == nil, `Config.Items : ItemId en double {entry.Id}`)
			made[entry.Id] = {
				Id = entry.Id,
				DisplayName = entry.Name,
				Zone = zone,
				Rarity = entry.Rarity,
				Asset = `ITM_{entry.Id}`,
				Category = category.Name,
				CategoryId = category.Id,
				TutorialOnly = entry.TutorialOnly == true,
				Rank = 1,
				DrawWeight = 1,
			}
			count += 1
		end
	end
	-- Vague 76 : objets de la zone dans l'ordre de l'index (INDEX_ORDER), rang dans leur rareté et poids au tirage.
	local order = INDEX_ORDER[zone]
	assert(order ~= nil and #order == count, `Config.Items : INDEX_ORDER[{zone}] ne liste pas les {count} objets de la zone`)
	local ranks: { [string]: number } = {}
	for _, id in order do
		local item = made[id]
		assert(item ~= nil, `Config.Items : INDEX_ORDER[{zone}] cite {id}, absent de la zone ou en double`)
		made[id] = nil
		assert(item.TutorialOnly or Rarities.Allows(zone, item.Rarity), `Config.Items : {id} est {item.Rarity}, rareté absente de la zone {zone} (Rarities.ZoneOdds)`)
		local rank = (ranks[item.Rarity] or 0) + 1
		ranks[item.Rarity] = rank
		item.Rank = rank
		item.DrawWeight = 1 / (1 + Rarities.IncomeRules.RankStep) ^ (rank - 1)
		add(item)
		local drawable = byRarity[item.Rarity]
		assert(drawable ~= nil, `Config.Items : {item.Id} ({item.Rarity}) ne peut pas être rangé dans une zone`)
		if not item.TutorialOnly then
			table.insert(drawable, item)
		end
	end
	-- Chaque rareté de la zone (sauf Secret et Divine, toutes zones) a au moins un objet tirable.
	local zoneRarities: { string } = Rarities.ZoneRarities[zone] or {}
	for _, rarityId in zoneRarities do
		local drawable = byRarity[rarityId]
		assert(drawable == nil or #drawable > 0, `Config.Items : aucun objet {rarityId} tirable en zone {zone}`)
	end
end

-- Objets sans zone (Secret, Divine) : `rarity` est la seule rareté admise dans `entries`.
local function addAllZones(entries: { Entry }, into: { Item }, rarity: Rarities.RarityId, category: string, categoryId: string)
	for index, entry in entries do
		assert(entry.Rarity == rarity, `Config.Items : {entry.Id} ({entry.Rarity}) rangé avec les {rarity}`)
		local item: Item = {
			Id = entry.Id,
			DisplayName = entry.Name,
			Zone = nil,
			Rarity = entry.Rarity,
			Asset = `ITM_{entry.Id}`,
			Category = category,
			CategoryId = categoryId,
			TutorialOnly = false,
			Rank = index, -- vague 76 : rang dans la liste, comme dans une zone
			DrawWeight = 1 / (1 + Rarities.IncomeRules.RankStep) ^ (index - 1),
		}
		add(item)
		table.insert(into, item)
	end
end
addAllZones(SECRETS, Secrets, "Secret", SECRET_CATEGORY, SECRET_CATEGORY_ID)
addAllZones(DIVINES, Divines, "Divine", DIVINE_CATEGORY, DIVINE_CATEGORY_ID)

-- a285 : objets exclusifs, dans Items.ById et Items.Exclusives seulement (ni List, ni ByZone, ni AllZones).
for _, entry in EXCLUSIVES do
	local item: Item = {
		Id = entry.Id,
		DisplayName = entry.Name,
		Zone = nil,
		Rarity = entry.Rarity,
		Asset = `ITM_{entry.Id}`,
		Category = EXCLUSIVE_CATEGORY,
		CategoryId = EXCLUSIVE_CATEGORY_ID,
		TutorialOnly = false,
		Rank = 1, -- seul de sa rareté dans la caisse : revenu de base de la rareté (Formulas.ItemIncome)
		DrawWeight = 0, -- jamais tiré par Items.Pick ; la caisse tire par Monetization.Crate.Odds
	}
	add(item, false)
	table.insert(Exclusives, item)
end

-- [RarityId] = objets tirés quelle que soit la zone (Secret, Divine) ; les autres raretés : ByZone.
local AllZones: { [string]: { Item } } = {
	Secret = Secrets,
	Divine = Divines,
}

for old, new in RENAMED_V1 do
	assert(ById[old] == nil and ById[new] ~= nil, `Config.Items : renommage v1 {old} → {new} incohérent`)
end
for old, new in RETIRED_V1 do
	assert(ById[old] == nil and ById[new] ~= nil, `Config.Items : remplacement v1 {old} → {new} incohérent`)
end

-- Tirage d'Items.Pick quand l'appelant ne donne pas son Random (créé au premier besoin).
local defaultRandom: Random? = nil

local function pick(zone: number, rarity: Rarities.RarityId, rng: Random?): Item?
	local list: { Item }? = AllZones[rarity]
	-- Vague 76 (Cantin et Clément, 19/11) : un Secret ne sort que des zones qui ont cette rareté (zone 6) ; la
	-- Divine, qu'aucune zone n'a encore (Rarities.FirstZone), reste toutes zones (L-106).
	if list ~= nil and Rarities.FirstZone[rarity] ~= nil and not Rarities.Allows(zone, rarity) then
		return nil
	end
	if list == nil then
		local byRarity = ByZone[zone]
		list = if byRarity then byRarity[rarity] else nil
	end
	if list == nil or #list == 0 then
		return nil
	end
	local random = rng or defaultRandom
	if random == nil then
		local created = Random.new()
		defaultRandom = created
		random = created
	end
	-- Vague 76 : chaque objet pèse son DrawWeight (inverse de son revenu relatif dans sa rareté et sa zone).
	local total = 0
	for _, item in list do
		total += item.DrawWeight
	end
	local roll = (random :: Random):NextNumber() * total
	for _, item in list do
		if roll < item.DrawWeight then
			return item
		end
		roll -= item.DrawWeight
	end
	return list[#list] -- arrondi des nombres à virgule
end

local Items = {
	List = List, -- zone par zone, dans l'ordre de l'index (INDEX_ORDER), puis les Secrets
	ById = ById,
	ByZone = ByZone, -- Items.ByZone[3].Rare = { Console de salon, Console portable, PC gamer, Carte graphique en or }
	Secrets = Secrets, -- tirés quand la rareté est Secret, quelle que soit la zone
	Divines = Divines, -- tirés quand la rareté est Divine, quelle que soit la zone (vide pour l'instant)
	AllZones = AllZones, -- [RarityId] = Secrets ou Divines ; nil pour une rareté rangée par zone
	Exclusives = Exclusives, -- a285 : objets de la caisse exclusive (boutique Robux), hors List et hors tirage
	Pick = pick,
	RenamedV1 = RENAMED_V1,
	RetiredV1 = RETIRED_V1,
}

export type Items = typeof(Items)

return DeepFreeze(Items)
