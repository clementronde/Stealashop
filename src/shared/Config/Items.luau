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
--       TutorialOnly ni les hors tirage (OutOfDraw, a497). Existe pour les 6 raretés de Commun à Mythique (pas pour Secret) ; liste
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
--
-- a429 (lot100, L-327 et L-339, Clément 24/11 ; liste : docs/claude/notes/objets-catalogue-v3.md) : catalogue v3,
-- des objets drôles et « trendy », même structure que la v2 (mêmes nombres par zone et par rareté, un Rare du tuto en
-- zone 1 : Z1_RamenDeFeu, un Secret : Secret_ToilettesEnOr). Interrupteur (décision C2 de Cantin, 24/11) :
-- Features.ItemsV3 (partout, false) ou Features.ItemsV3Dev dans le jeu DEV (Config/ProductIds.IsDev, true). Coupé, tout
-- reste en v2. Un seul catalogue actif à la fois : List, ById, ByZone, Secrets sont ceux du catalogue actif.
--   Items.Version: number            2 ou 3, le catalogue actif
--   Items.V2ToV3, Items.V3ToV2: { [ItemId]: ItemId }
--       Renommage des objets des profils (DataService, au chargement, sans changement de version ; champ ItemCatalog
--       du profil) : V0 proposé (Cantin, 24/11) : l'objet de même zone, même rareté et même rang dans l'ordre de
--       l'index (le Pot de nouilles devient le Ramen de feu, le Chat porte-bonheur doré les Toilettes en or).
--       Une bijection : l'interrupteur recoupé, les objets reviennent en v2.
--   Items.Resolve(id) -> Item?       l'objet actif pour un ItemId de la v2 ou de la v3 (même rareté, même zone)
--   Items.TutorialItemId: string     l'objet du tuto du catalogue actif (Config/Tutorial.GuaranteedItemId)
--   Items.OtherAssets: { [string]: boolean }
--       Modèles ITM_ de l'autre catalogue : encore rangés dans Assets/Items, ni attendus ni signalés « pas au catalogue »
--       (ContractChecker) ; leurs icônes ICON_ non plus.
--
-- a497 (Cantin, 26/11 ; note a497-note-gains-zone) : rangement du catalogue v3 refait dans LAYOUT_V3, seul endroit à
-- changer : 12 objets tirés par zone (11 en zone 6, plus le Secret), des Peu communs en zone 1, un Rare en zone 2,
-- 11 objets hors tirage (Item.OutOfDraw : dans List et ById, avec leur revenu, jamais dans ByZone ni tirés ; l'Index
-- ne les compte pas). Plus d'objet TutorialOnly en v3 : l'objet du tuto est le meilleur Peu commun de la zone 1
-- (TUTORIAL_V3), qui se tire aussi normalement ; le Ramen de feu devient un Rare de la zone 3. V2ToV3 reste celui
-- d'a429 (INDEX_ORDER_V3_A429). La v2 (PROD) ne change pas.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Rarities = require(script.Parent.Rarities)

-- a429 : module de Config chargé s'il est là (bancs à liste de modules fixe, comme ProductIds dans Config/Monetization).
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")
-- a429 : catalogue v3 allumé partout (ItemsV3) ou dans le jeu DEV seulement (ItemsV3Dev et ProductIds.IsDev).
local V3: boolean = Features.ItemsV3 == true or (Features.ItemsV3Dev == true and ProductIds.IsDev == true)

export type Item = {
	Id: string, -- ItemId
	DisplayName: string, -- nom affiché, en anglais (L-036)
	Zone: number?, -- nil pour un Secret (toutes zones)
	Rarity: Rarities.RarityId,
	Asset: string, -- nom du modèle dans ReplicatedStorage/Assets : ITM_<ItemId>
	Category: string, -- catégorie affichée, en anglais (étiquette BB_Box) ; « ??? » pour le Secret
	CategoryId: string, -- identifiant de la catégorie, sans accent (« Legumes ») ; « Secret » pour le Secret (V0)
	TutorialOnly: boolean, -- ne sort que du premier colis du tuto, jamais d'un tirage (Pot de nouilles)
	OutOfDraw: boolean, -- a497 (v3) : hors tirage : gardé dans les profils, avec son revenu, mais jamais tiré ni compté par l'Index
	Exclusive: boolean, -- a497 : objet de la caisse exclusive (Items.Exclusives) ; revenu en zone IncomeRules.ExclusiveZone
	Rank: number, -- vague 76 : rang dans sa rareté et sa zone, dans l'ordre de l'index (1 = le moins rentable)
	DrawWeight: number, -- vague 76 : poids au tirage dans sa rareté et sa zone, 1 / 1,1^(Rank − 1) (Items.Pick)
}

type Entry = { Id: string, Name: string, Rarity: Rarities.RarityId, TutorialOnly: boolean? }
type CategoryEntry = { Id: string, Name: string, Items: { Entry } }
-- a497 : une ligne du rangement d'une zone (LAYOUT_V3) : l'objet, sa rareté dans le jeu, hors tirage ou non.
type Slot = { Id: string, Rarity: Rarities.RarityId, OutOfDraw: boolean? }

-- Raretés tirées dans une zone, dans l'ordre (le Secret est tiré toutes zones confondues).
local ZONE_RARITIES: { Rarities.RarityId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- [zone] = catégories dans l'ordre du catalogue : Id (sans accent), Name (affiché, en anglais) et
-- objets { ItemId, nom affiché en anglais, rareté } ; en commentaire, le nom français du doc.
local CATALOG_V2: { { CategoryEntry } } = {
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
local INDEX_ORDER_V2: { { string } } = {
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
local SECRETS_V2: { Entry } = {
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

-- a429 (L-327, L-339 ; docs/claude/notes/objets-catalogue-v3.md, Clément 24/11, base validée, noms encore modifiables) :
-- catalogue v3. Catégories (Id = Name, en anglais, sans accent) dans l'ordre où la note les cite ; noms affichés de la
-- note, sans l'étoile ★ des créatures (V0 proposé (Cantin, 24/11) : l'étoile marque la direction « créature absurde »
-- dans la note, pas le nom). Modèles : ITM_<ItemId> livrés dans Assets/Items (L-339).
local CATALOG_V3: { { CategoryEntry } } = {
	{ -- Zone 1 : Supérette, Kiosque (12 Communs + le Rare du tuto)
		{
			Id = "Snack",
			Name = "Snack",
			Items = {
				{ Id = "Z1_ChocolatDeDubai", Name = "Dubai Chocolate", Rarity = "Common" },
				{ Id = "Z1_BananeScotchee", Name = "Taped Banana", Rarity = "Common" },
				{ Id = "Z1_ChipsMystere", Name = "Mystery Chips", Rarity = "Common" },
				{ Id = "Z1_PouletALunettes", Name = "Cool Fried Chicken", Rarity = "Common" },
				{ Id = "Z1_PastequeMewing", Name = "Mewing Watermelon", Rarity = "Common" },
				{ Id = "Z1_OeufBoudeur", Name = "Grumpy Fried Egg", Rarity = "Common" },
				{ Id = "Z1_RamenDeFeu", Name = "Fire Ramen", Rarity = "Rare" }, -- a497 : Rare de la zone 3, tiré (LAYOUT_V3)
			},
		},
		{
			Id = "Drink",
			Name = "Drink",
			Items = {
				{ Id = "Z1_BoissonSigma", Name = "Sigma Drink", Rarity = "Common" },
				{ Id = "Z1_Canette67", Name = '"67" Can', Rarity = "Common" },
				{ Id = "Z1_SlushieArcEnCiel", Name = "Rainbow Slushie", Rarity = "Common" },
			},
		},
		{
			Id = "Sweet",
			Name = "Sweet",
			Items = {
				{ Id = "Z1_GlaceArcEnCiel", Name = "Rainbow Ice Cream", Rarity = "Common" },
				{ Id = "Z1_SachetSurprise", Name = "Mystery Bag", Rarity = "Common" },
			},
		},
		{
			Id = "Kiosk",
			Name = "Kiosk",
			Items = {
				{ Id = "Z1_TicketGagnant", Name = "Winning Scratch Card", Rarity = "Common" },
			},
		},
	},
	{ -- Zone 2 : Jouets et bonbons, Londres (8 Communs, 8 Peu communs)
		{
			Id = "Toy",
			Name = "Toy",
			Items = {
				{ Id = "Z2_CanardRoyal", Name = "Royal Rubber Duck", Rarity = "Common" },
				{ Id = "Z2_PopIt", Name = "Giant Pop-It", Rarity = "Common" },
				{ Id = "Z2_Squishy", Name = "Squishy", Rarity = "Common" },
				{ Id = "Z2_Slime", Name = "Slime", Rarity = "Common" },
				{ Id = "Z2_FigurineSurprise", Name = "Surprise Figure", Rarity = "Common" },
				{ Id = "Z2_BlasterAMousse", Name = "Foam Blaster", Rarity = "Uncommon" },
			},
		},
		{
			Id = "Candy",
			Name = "Candy",
			Items = {
				{ Id = "Z2_SucetteTourbillon", Name = "Swirl Lollipop", Rarity = "Common" },
				{ Id = "Z2_BarbeAPapaNuage", Name = "Cloud Cotton Candy", Rarity = "Common" },
				{ Id = "Z2_BonbonPiquant", Name = "Super Sour Candy", Rarity = "Common" },
				{ Id = "Z2_OursGelifieGeant", Name = "Giant Gummy Bear", Rarity = "Uncommon" },
				{ Id = "Z2_MachineABonbons", Name = "Candy Machine", Rarity = "Uncommon" },
				{ Id = "Z2_BusEnGelatine", Name = "Jelly Double-Decker", Rarity = "Uncommon" },
			},
		},
		{
			Id = "Plush",
			Name = "Plush",
			Items = {
				{ Id = "Z2_CapybaraOrange", Name = "Orange Capybara", Rarity = "Uncommon" },
				{ Id = "Z2_AxolotlEnPeluche", Name = "Axolotl Plush", Rarity = "Uncommon" },
				{ Id = "Z2_PelucheMonstre", Name = "Laughing Monster Plush", Rarity = "Uncommon" },
			},
		},
		{
			Id = "Creature",
			Name = "Creature",
			Items = {
				{ Id = "Z2_TheiereDansante", Name = "Dancing Teapot", Rarity = "Uncommon" }, -- ★
			},
		},
	},
	{ -- Zone 3 : Électronique et jeux vidéo, Tokyo (5 Communs, 5 Peu communs, 4 Rares)
		{
			Id = "Meme",
			Name = "Meme",
			Items = {
				{ Id = "Z3_ChatQuiTourne", Name = "Spinning Cat", Rarity = "Common" },
			},
		},
		{
			Id = "Gaming",
			Name = "Gaming",
			Items = {
				{ Id = "Z3_ManetteQuiTranspire", Name = "Sweaty Controller", Rarity = "Common" },
				{ Id = "Z3_CasqueOreillesDeChat", Name = "Cat Ear Headset", Rarity = "Common" },
				{ Id = "Z3_ClavierRgb", Name = "RGB Keyboard", Rarity = "Common" },
				{ Id = "Z3_MicroDeStreamer", Name = "Streamer Mic", Rarity = "Uncommon" },
				{ Id = "Z3_PcGamerQuiFume", Name = "Overheating Gaming PC", Rarity = "Rare" },
			},
		},
		{
			Id = "Phone",
			Name = "Phone",
			Items = {
				{ Id = "Z3_TelephonePliant", Name = "Folding Phone", Rarity = "Common" },
			},
		},
		{
			Id = "Gadget",
			Name = "Gadget",
			Items = {
				{ Id = "Z3_RobotChien", Name = "Robot Dog", Rarity = "Uncommon" },
				{ Id = "Z3_LampeALave", Name = "Lava Lamp", Rarity = "Uncommon" },
				{ Id = "Z3_AppareilPhotoInstantane", Name = "Instant Camera", Rarity = "Uncommon" },
				{ Id = "Z3_EnseigneNeon", Name = "Neon Sign", Rarity = "Uncommon" },
				{ Id = "Z3_Hoverboard", Name = "Hoverboard", Rarity = "Rare" },
				{ Id = "Z3_ProjecteurGalaxie", Name = "Galaxy Projector", Rarity = "Rare" },
			},
		},
		{
			Id = "Creature",
			Name = "Creature",
			Items = {
				{ Id = "Z3_SushiNinja", Name = "Ninja Sushi", Rarity = "Rare" }, -- ★
			},
		},
	},
	{ -- Zone 4 : Bijoux et montres, Los Angeles (4 Communs, 4 Peu communs, 4 Rares, 3 Épiques)
		{
			Id = "Fashion",
			Name = "Fashion",
			Items = {
				{ Id = "Z4_LunettesDeStar", Name = "Star Sunglasses", Rarity = "Common" }, -- gardé de la v2 (Peu commun en v2)
				{ Id = "Z4_CasquetteAStrass", Name = "Bling Cap", Rarity = "Common" },
				{ Id = "Z4_FauxOnglesEnOr", Name = "Golden Nails", Rarity = "Common" },
				{ Id = "Z4_BasketsLumineuses", Name = "Light-Up Sneakers", Rarity = "Uncommon" },
				{ Id = "Z4_BasketsEnOr", Name = "Golden Sneakers", Rarity = "Rare" },
				{ Id = "Z4_PerruquePresidentielle", Name = "Presidential Wig", Rarity = "Rare" },
			},
		},
		{
			Id = "Jewelry",
			Name = "Jewelry",
			Items = {
				{ Id = "Z4_BraceletDAmitie", Name = "Friendship Bracelet", Rarity = "Common" },
				{ Id = "Z4_ChaineDrip", Name = "Drip Chain", Rarity = "Uncommon" },
				{ Id = "Z4_GrillzEnDiamant", Name = "Diamond Grillz", Rarity = "Rare" },
			},
		},
		{
			Id = "Star",
			Name = "Star",
			Items = {
				{ Id = "Z4_MicroDePopStar", Name = "Pop Star Mic", Rarity = "Uncommon" },
				{ Id = "Z4_TropheeDeStar", Name = "Star Trophy", Rarity = "Rare" },
				{ Id = "Z4_GuitareNeon", Name = "Neon Guitar", Rarity = "Epic" },
			},
		},
		{
			Id = "Watch",
			Name = "Watch",
			Items = {
				{ Id = "Z4_MontreGlacee", Name = "Iced-Out Watch", Rarity = "Uncommon" },
				{ Id = "Z4_MontreDiamant", Name = "Diamond Watch", Rarity = "Epic" },
			},
		},
		{
			Id = "Creature",
			Name = "Creature",
			Items = {
				{ Id = "Z4_ChihuahuaEnDiamants", Name = "Diamond Chihuahua", Rarity = "Epic" }, -- ★
			},
		},
	},
	{ -- Zone 5 : Galerie d'art, Antiquaire, Paris (3 Peu communs, 3 Rares, 3 Épiques, 3 Légendaires)
		{
			Id = "Paris",
			Name = "Paris",
			Items = {
				{ Id = "Z5_BaguetteEnOr", Name = "Golden Baguette", Rarity = "Uncommon" },
				{ Id = "Z5_BeretDeMime", Name = "Mime Beret", Rarity = "Uncommon" },
			},
		},
		{
			Id = "Painting",
			Name = "Painting",
			Items = {
				{ Id = "Z5_TableauPixelArt", Name = "Pixel Art Painting", Rarity = "Uncommon" },
				{ Id = "Z5_JocondeSelfie", Name = "Selfie Mona Lisa", Rarity = "Rare" },
			},
		},
		{
			Id = "Sculpture",
			Name = "Sculpture",
			Items = {
				{ Id = "Z5_StatueMewing", Name = "Mewing Statue", Rarity = "Rare" },
				{ Id = "Z5_StatueDeChatGeant", Name = "Giant Cat Statue", Rarity = "Epic" },
			},
		},
		{
			Id = "Relic",
			Name = "Relic",
			Items = {
				{ Id = "Z5_EpeeDansLaPierre", Name = "Sword in the Stone", Rarity = "Rare" },
				{ Id = "Z5_OeufDeDinoFossile", Name = "Fossil Dino Egg", Rarity = "Epic" },
				{ Id = "Z5_OeufDeDragon", Name = "Dragon Egg", Rarity = "Legendary" },
			},
		},
		{
			Id = "Sport",
			Name = "Sport",
			Items = {
				{ Id = "Z5_CramponsDores", Name = "Golden Cleats No. 10", Rarity = "Epic" },
				{ Id = "Z5_GoldenBall", Name = "Golden Ball", Rarity = "Legendary" },
			},
		},
		{
			Id = "Creature",
			Name = "Creature",
			Items = {
				{ Id = "Z5_CroissantRequin", Name = "Croissant Shark", Rarity = "Legendary" }, -- ★
			},
		},
	},
	{ -- Zone 6 : Banque, Salle des coffres, New York (3 Rares, 3 Épiques, 3 Légendaires, 3 Mythiques)
		{
			Id = "Gold",
			Name = "Gold",
			Items = {
				{ Id = "Z6_LingotGeant", Name = "Giant Gold Bar", Rarity = "Rare" },
				{ Id = "Z6_LiberteEnOr", Name = "Golden Liberty", Rarity = "Epic" },
				{ Id = "Z6_TaxiEnOr", Name = "Golden Taxi", Rarity = "Epic" },
				{ Id = "Z6_CapybaraDore", Name = "Golden Capybara", Rarity = "Epic" },
			},
		},
		{
			Id = "Cash",
			Name = "Cash",
			Items = {
				{ Id = "Z6_ValiseDeBillets", Name = "Cash Briefcase", Rarity = "Rare" },
				{ Id = "Z6_CarteNoireInfinie", Name = "Infinite Black Card", Rarity = "Rare" },
			},
		},
		{
			Id = "Treasure",
			Name = "Treasure",
			Items = {
				{ Id = "Z6_CouronneCosmique", Name = "Cosmic Crown", Rarity = "Legendary" },
				{ Id = "Z6_DragonDeDiamant", Name = "Diamond Dragon", Rarity = "Mythic" },
			},
		},
		{
			Id = "Creature",
			Name = "Creature",
			Items = {
				{ Id = "Z6_CoffreADents", Name = "Toothy Safe", Rarity = "Legendary" }, -- ★
				{ Id = "Z6_BilletQuiCourt", Name = "Running Million Bill", Rarity = "Legendary" }, -- ★
				{ Id = "Z6_PigeonEnOr", Name = "Golden Pigeon", Rarity = "Mythic" }, -- ★
				{ Id = "Z6_CerveauDore", Name = "Golden Brain", Rarity = "Mythic" }, -- ★
			},
		},
	},
}

-- a429 : ordre de l'index v3 de départ, celui des tableaux de la note (rareté, puis ligne). a497 : ce n'est plus le
-- rangement du jeu (LAYOUT_V3, plus bas) ; gardé tel quel, avec les raretés écrites dans CATALOG_V3, pour le seul
-- renommage v2 ↔ v3 des profils (V2ToV3 : même zone, même rareté, même rang dans CE rangement), qui ne bouge plus.
local INDEX_ORDER_V3_A429: { { string } } = {
	{ -- Zone 1 : 12 Communs, puis le Ramen de feu (tuto)
		"Z1_ChocolatDeDubai", "Z1_BoissonSigma", "Z1_Canette67", "Z1_BananeScotchee", "Z1_ChipsMystere",
		"Z1_PouletALunettes", "Z1_GlaceArcEnCiel", "Z1_SlushieArcEnCiel", "Z1_SachetSurprise", "Z1_PastequeMewing",
		"Z1_OeufBoudeur", "Z1_TicketGagnant", "Z1_RamenDeFeu",
	},
	{ -- Zone 2 : 8 Communs, 8 Peu communs
		"Z2_CanardRoyal", "Z2_PopIt", "Z2_Squishy", "Z2_Slime", "Z2_SucetteTourbillon", "Z2_BarbeAPapaNuage",
		"Z2_BonbonPiquant", "Z2_FigurineSurprise",
		"Z2_CapybaraOrange", "Z2_AxolotlEnPeluche", "Z2_OursGelifieGeant", "Z2_PelucheMonstre", "Z2_BlasterAMousse",
		"Z2_MachineABonbons", "Z2_BusEnGelatine", "Z2_TheiereDansante",
	},
	{ -- Zone 3 : 5 Communs, 5 Peu communs, 4 Rares
		"Z3_ChatQuiTourne", "Z3_ManetteQuiTranspire", "Z3_CasqueOreillesDeChat", "Z3_TelephonePliant", "Z3_ClavierRgb",
		"Z3_MicroDeStreamer", "Z3_RobotChien", "Z3_LampeALave", "Z3_AppareilPhotoInstantane", "Z3_EnseigneNeon",
		"Z3_PcGamerQuiFume", "Z3_Hoverboard", "Z3_ProjecteurGalaxie", "Z3_SushiNinja",
	},
	{ -- Zone 4 : 4 Communs, 4 Peu communs, 4 Rares, 3 Épiques
		"Z4_LunettesDeStar", "Z4_BraceletDAmitie", "Z4_CasquetteAStrass", "Z4_FauxOnglesEnOr",
		"Z4_ChaineDrip", "Z4_BasketsLumineuses", "Z4_MicroDePopStar", "Z4_MontreGlacee",
		"Z4_GrillzEnDiamant", "Z4_BasketsEnOr", "Z4_PerruquePresidentielle", "Z4_TropheeDeStar",
		"Z4_MontreDiamant", "Z4_GuitareNeon", "Z4_ChihuahuaEnDiamants",
	},
	{ -- Zone 5 : 3 Peu communs, 3 Rares, 3 Épiques, 3 Légendaires
		"Z5_BaguetteEnOr", "Z5_BeretDeMime", "Z5_TableauPixelArt",
		"Z5_JocondeSelfie", "Z5_StatueMewing", "Z5_EpeeDansLaPierre",
		"Z5_CramponsDores", "Z5_OeufDeDinoFossile", "Z5_StatueDeChatGeant",
		"Z5_GoldenBall", "Z5_OeufDeDragon", "Z5_CroissantRequin",
	},
	{ -- Zone 6 : 3 Rares, 3 Épiques, 3 Légendaires, 3 Mythiques (plus le Secret, toutes zones)
		"Z6_LingotGeant", "Z6_ValiseDeBillets", "Z6_CarteNoireInfinie",
		"Z6_LiberteEnOr", "Z6_TaxiEnOr", "Z6_CapybaraDore",
		"Z6_CouronneCosmique", "Z6_CoffreADents", "Z6_BilletQuiCourt",
		"Z6_DragonDeDiamant", "Z6_PigeonEnOr", "Z6_CerveauDore",
	},
}

-- a497 (Cantin, 26/11) : LA répartition du catalogue v3, seul endroit à changer pour déplacer un objet, changer sa
-- rareté, son rang ou le sortir du tirage (aucun code à toucher autour). Chaque zone : ses objets, dans l'ordre de
-- l'index (le rang d'un objet dans sa rareté et sa zone = l'ordre de ses lignes ; il fixe son revenu, +10 % par rang,
-- et son poids au tirage), puis ceux qui sont hors tirage :
--   Id         un objet de CATALOG_V3 (son nom affiché et sa catégorie y restent) ; chacun figure ici une fois ;
--   Rarity     sa rareté dans le jeu (celle de CATALOG_V3 ne sert plus qu'au renommage v2 ↔ v3) ; elle doit exister
--              dans la zone (Rarities.ZoneOdds) ;
--   OutOfDraw  true : hors tirage (Cantin, 26/11). L'objet garde son modèle, sa place dans les profils et un revenu
--              (son rang suit ceux des objets tirés de sa rareté), mais ne sort d'aucun colis et l'Index ne le
--              compte pas (Config/Index).
-- L'ItemId garde le préfixe de sa zone d'origine (V0 du 26/11 : rien à renommer) ; le revenu prend la zone d'ici
-- (Formulas.ItemIncome). Vérifié au chargement : 8 à 12 objets tirés par zone, aucune rareté de la zone sans objet tiré.
local LAYOUT_V3: { { Slot } } = {
	{ -- Zone 1 : 9 Communs et 3 Peu communs tirés
		{ Id = "Z1_ChocolatDeDubai", Rarity = "Common" },
		{ Id = "Z1_BoissonSigma", Rarity = "Common" },
		{ Id = "Z1_Canette67", Rarity = "Common" },
		{ Id = "Z1_BananeScotchee", Rarity = "Common" },
		{ Id = "Z1_ChipsMystere", Rarity = "Common" },
		{ Id = "Z1_PouletALunettes", Rarity = "Common" },
		{ Id = "Z1_GlaceArcEnCiel", Rarity = "Common" },
		{ Id = "Z1_SachetSurprise", Rarity = "Common" },
		{ Id = "Z1_PastequeMewing", Rarity = "Common" },
		{ Id = "Z2_OursGelifieGeant", Rarity = "Uncommon" }, -- de la zone 2
		{ Id = "Z2_MachineABonbons", Rarity = "Uncommon" }, -- de la zone 2
		{ Id = "Z2_BusEnGelatine", Rarity = "Uncommon" }, -- de la zone 2 ; objet du tuto (TUTORIAL_V3)
		{ Id = "Z1_SlushieArcEnCiel", Rarity = "Common", OutOfDraw = true },
		{ Id = "Z1_OeufBoudeur", Rarity = "Common", OutOfDraw = true },
		{ Id = "Z1_TicketGagnant", Rarity = "Common", OutOfDraw = true },
	},
	{ -- Zone 2 : 7 Communs, 4 Peu communs et 1 Rare tirés
		{ Id = "Z2_CanardRoyal", Rarity = "Common" },
		{ Id = "Z2_Squishy", Rarity = "Common" },
		{ Id = "Z2_Slime", Rarity = "Common" },
		{ Id = "Z2_SucetteTourbillon", Rarity = "Common" },
		{ Id = "Z2_BarbeAPapaNuage", Rarity = "Common" },
		{ Id = "Z2_BonbonPiquant", Rarity = "Common" },
		{ Id = "Z2_FigurineSurprise", Rarity = "Common" },
		{ Id = "Z2_CapybaraOrange", Rarity = "Uncommon" },
		{ Id = "Z2_AxolotlEnPeluche", Rarity = "Uncommon" },
		{ Id = "Z2_PelucheMonstre", Rarity = "Uncommon" },
		{ Id = "Z2_BlasterAMousse", Rarity = "Uncommon" },
		{ Id = "Z3_Hoverboard", Rarity = "Rare" }, -- de la zone 3
		{ Id = "Z2_PopIt", Rarity = "Common", OutOfDraw = true },
	},
	{ -- Zone 3 : 4 Communs, 5 Peu communs et 3 Rares tirés
		{ Id = "Z3_ChatQuiTourne", Rarity = "Common" },
		{ Id = "Z3_CasqueOreillesDeChat", Rarity = "Common" },
		{ Id = "Z3_TelephonePliant", Rarity = "Common" },
		{ Id = "Z3_ClavierRgb", Rarity = "Common" },
		{ Id = "Z3_MicroDeStreamer", Rarity = "Uncommon" },
		{ Id = "Z3_RobotChien", Rarity = "Uncommon" },
		{ Id = "Z3_LampeALave", Rarity = "Uncommon" },
		{ Id = "Z3_AppareilPhotoInstantane", Rarity = "Uncommon" },
		{ Id = "Z2_TheiereDansante", Rarity = "Uncommon" }, -- de la zone 2
		{ Id = "Z1_RamenDeFeu", Rarity = "Rare" }, -- de la zone 1 (ancien objet du tuto), à la place du Galaxy Projector
		{ Id = "Z3_SushiNinja", Rarity = "Rare" },
		{ Id = "Z4_TropheeDeStar", Rarity = "Rare" }, -- de la zone 4
		{ Id = "Z3_ManetteQuiTranspire", Rarity = "Common", OutOfDraw = true },
		{ Id = "Z3_EnseigneNeon", Rarity = "Uncommon", OutOfDraw = true },
		{ Id = "Z3_PcGamerQuiFume", Rarity = "Rare", OutOfDraw = true },
		{ Id = "Z3_ProjecteurGalaxie", Rarity = "Rare", OutOfDraw = true },
	},
	{ -- Zone 4 : 4 Communs, 2 Peu communs, 3 Rares et 3 Épiques tirés
		{ Id = "Z4_LunettesDeStar", Rarity = "Common" },
		{ Id = "Z4_BraceletDAmitie", Rarity = "Common" },
		{ Id = "Z4_CasquetteAStrass", Rarity = "Common" },
		{ Id = "Z4_FauxOnglesEnOr", Rarity = "Common" },
		{ Id = "Z4_ChaineDrip", Rarity = "Uncommon" },
		{ Id = "Z4_BasketsLumineuses", Rarity = "Uncommon" },
		{ Id = "Z4_GrillzEnDiamant", Rarity = "Rare" },
		{ Id = "Z4_BasketsEnOr", Rarity = "Rare" },
		{ Id = "Z4_PerruquePresidentielle", Rarity = "Rare" },
		{ Id = "Z4_MontreDiamant", Rarity = "Epic" },
		{ Id = "Z4_GuitareNeon", Rarity = "Epic" },
		{ Id = "Z4_ChihuahuaEnDiamants", Rarity = "Epic" },
	},
	{ -- Zone 5 : 3 Peu communs, 3 Rares, 3 Épiques et 3 Légendaires tirés
		{ Id = "Z5_TableauPixelArt", Rarity = "Uncommon" },
		{ Id = "Z4_MicroDePopStar", Rarity = "Uncommon" }, -- de la zone 4
		{ Id = "Z4_MontreGlacee", Rarity = "Uncommon" }, -- de la zone 4
		{ Id = "Z5_JocondeSelfie", Rarity = "Rare" },
		{ Id = "Z5_StatueMewing", Rarity = "Rare" },
		{ Id = "Z5_EpeeDansLaPierre", Rarity = "Rare" },
		{ Id = "Z5_CramponsDores", Rarity = "Epic" },
		{ Id = "Z5_OeufDeDinoFossile", Rarity = "Epic" },
		{ Id = "Z5_StatueDeChatGeant", Rarity = "Epic" },
		{ Id = "Z5_GoldenBall", Rarity = "Legendary" },
		{ Id = "Z5_OeufDeDragon", Rarity = "Legendary" },
		{ Id = "Z5_CroissantRequin", Rarity = "Legendary" },
		{ Id = "Z5_BaguetteEnOr", Rarity = "Uncommon", OutOfDraw = true },
		{ Id = "Z5_BeretDeMime", Rarity = "Uncommon", OutOfDraw = true },
	},
	{ -- Zone 6 : 3 Rares, 3 Épiques, 3 Légendaires et 2 Mythiques tirés (plus le Secret, SECRETS_V3)
		{ Id = "Z6_LingotGeant", Rarity = "Rare" },
		{ Id = "Z6_ValiseDeBillets", Rarity = "Rare" },
		{ Id = "Z6_CarteNoireInfinie", Rarity = "Rare" },
		{ Id = "Z6_LiberteEnOr", Rarity = "Epic" },
		{ Id = "Z6_TaxiEnOr", Rarity = "Epic" },
		{ Id = "Z6_CapybaraDore", Rarity = "Epic" },
		{ Id = "Z6_CouronneCosmique", Rarity = "Legendary" },
		{ Id = "Z6_CoffreADents", Rarity = "Legendary" },
		{ Id = "Z6_BilletQuiCourt", Rarity = "Legendary" },
		{ Id = "Z6_DragonDeDiamant", Rarity = "Mythic" },
		{ Id = "Z6_PigeonEnOr", Rarity = "Mythic" },
		{ Id = "Z6_CerveauDore", Rarity = "Mythic", OutOfDraw = true },
	},
}
-- a497 (Cantin, 26/11) : objet du tuto du catalogue v3 = le dernier objet tiré (le meilleur) de cette zone et de cette
-- rareté dans LAYOUT_V3 (Jelly Double-Decker). Il se tire aussi normalement ; le tuto le donne sans mutation, au poids de
-- repère (ShelfOpen.Reveal.TutorialWeight, revenu × 1).
local TUTORIAL_V3 = { Zone = 1, Rarity = "Uncommon" }
local DRAWN_PER_ZONE_V3 = { Min = 8, Max = 12 } -- a497 (Cantin, 26/11) : objets tirés par zone

local SECRETS_V3: { Entry } = {
	{ Id = "Secret_ToilettesEnOr", Name = "Solid Gold Toilet", Rarity = "Secret" },
}

-- a429 : le catalogue actif (Features.ItemsV3, ItemsV3Dev). a497 : son rangement (zone, rareté, rang, tirage) est
-- LAYOUT_V3 en v3 ; en v2, l'ordre de l'index et les raretés de CATALOG_V2, comme avant (aucun objet hors tirage).
local CATALOG: { { CategoryEntry } } = if V3 then CATALOG_V3 else CATALOG_V2
local SECRETS: { Entry } = if V3 then SECRETS_V3 else SECRETS_V2
local function layoutOf(catalog: { { CategoryEntry } }, order: { { string } }): { { Slot } }
	local entryOf: { [string]: Entry } = {}
	for _, categories in catalog do
		for _, category in categories do
			for _, entry in category.Items do
				entryOf[entry.Id] = entry
			end
		end
	end
	local layout: { { Slot } } = {}
	for zone, ids in order do
		local slots: { Slot } = {}
		for _, id in ids do
			local entry = entryOf[id]
			assert(entry ~= nil, `Config.Items : {id} dans l'ordre de l'index sans être au catalogue`)
			table.insert(slots, { Id = id, Rarity = entry.Rarity })
		end
		layout[zone] = slots
	end
	return layout
end
local LAYOUT: { { Slot } } = if V3 then LAYOUT_V3 else layoutOf(CATALOG_V2, INDEX_ORDER_V2)

-- a429 : clé « zone:rareté:rang » de chaque objet d'un catalogue (rang dans l'ordre de l'index, comme Rank ; le
-- Secret : « Secret:<rang> »), pour le renommage v2 ↔ v3 des profils (même zone, même rareté, même rang).
local function rankKeys(catalog: { { CategoryEntry } }, order: { { string } }, secrets: { Entry }): { [string]: string }
	local rarityOf: { [string]: string } = {}
	for _, categories in catalog do
		for _, category in categories do
			for _, entry in category.Items do
				rarityOf[entry.Id] = entry.Rarity
			end
		end
	end
	local keys: { [string]: string } = {}
	for zone, ids in order do
		local ranks: { [string]: number } = {}
		for _, id in ids do
			local rarity = rarityOf[id]
			assert(rarity ~= nil, `Config.Items : {id} dans l'ordre de l'index sans être au catalogue`)
			local rank = (ranks[rarity] or 0) + 1
			ranks[rarity] = rank
			keys[id] = `{zone}:{rarity}:{rank}`
		end
	end
	for index, entry in secrets do
		keys[entry.Id] = `Secret:{index}`
	end
	return keys
end

local V2_TO_V3: { [string]: string } = {}
local V3_TO_V2: { [string]: string } = {}
do
	local byKeyV3: { [string]: string } = {}
	for id, key in rankKeys(CATALOG_V3, INDEX_ORDER_V3_A429, SECRETS_V3) do
		byKeyV3[key] = id
	end
	local count = 0
	for id, key in rankKeys(CATALOG_V2, INDEX_ORDER_V2, SECRETS_V2) do
		local new = byKeyV3[key]
		assert(new ~= nil, `Config.Items : {id} ({key}) sans objet v3 de même zone, rareté et rang`)
		V2_TO_V3[id] = new
		V3_TO_V2[new] = id
		count += 1
	end
	for key, id in byKeyV3 do
		assert(V3_TO_V2[id] ~= nil, `Config.Items : {id} ({key}) sans objet v2 de même zone, rareté et rang`)
	end
	assert(count == #INDEX_ORDER_V3_A429[1] + #INDEX_ORDER_V3_A429[2] + #INDEX_ORDER_V3_A429[3] + #INDEX_ORDER_V3_A429[4] + #INDEX_ORDER_V3_A429[5] + #INDEX_ORDER_V3_A429[6] + #SECRETS_V3, "Config.Items : v2 et v3 n'ont pas le même nombre d'objets")
end

-- a429 : modèles ITM_ de l'autre catalogue (ContractChecker : ni attendus ni « pas au catalogue »).
local OTHER_ASSETS: { [string]: boolean } = {}
local otherIds: { [string]: string } = if V3 then V2_TO_V3 else V3_TO_V2
for id in otherIds do
	OTHER_ASSETS[`ITM_{id}`] = true
end

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

-- Fiche de chaque objet des zones du catalogue actif (nom affiché, catégorie, tuto) et la zone où le catalogue l'écrit.
type Written = { entry: Entry, category: CategoryEntry, zone: number }
local written: { [string]: Written } = {}
for zone, categories in CATALOG do
	for _, category in categories do
		for _, entry in category.Items do
			assert(string.sub(entry.Id, 1, 3) == `Z{zone}_`, `Config.Items : {entry.Id} écrit en zone {zone}`)
			assert(written[entry.Id] == nil, `Config.Items : ItemId en double {entry.Id}`)
			written[entry.Id] = { entry = entry, category = category, zone = zone }
		end
	end
end

-- Vague 76 : objets de chaque zone dans l'ordre de l'index (a497 : LAYOUT), rang dans leur rareté et poids au tirage.
-- a497 : en v3, la zone, la rareté et le tirage viennent de LAYOUT_V3 (un objet peut y changer de zone) ; en v2, un
-- objet reste dans la zone où CATALOG_V2 l'écrit.
local placed: { [string]: boolean } = {}
for zone, slots in LAYOUT do
	local byRarity: { [string]: { Item } } = {}
	for _, rarity in ZONE_RARITIES do
		byRarity[rarity] = {}
	end
	ByZone[zone] = byRarity
	local ranks: { [string]: number } = {}
	local drawn = 0
	for _, slot in slots do
		local id = slot.Id
		local info = written[id]
		assert(info ~= nil, `Config.Items : la zone {zone} du rangement cite {id}, absent du catalogue`)
		assert(placed[id] == nil, `Config.Items : {id} rangé deux fois`)
		placed[id] = true
		assert(V3 or info.zone == zone, `Config.Items : {id} rangé en zone {zone}, écrit en zone {info.zone}`)
		local entry = info.entry
		-- a497 : en v3, plus aucun objet à part (l'objet du tuto est TUTORIAL_V3, tiré normalement).
		assert(not (V3 and entry.TutorialOnly == true), `Config.Items : {id} TutorialOnly dans le catalogue v3`)
		local tutorialOnly = entry.TutorialOnly == true
		local outOfDraw = slot.OutOfDraw == true
		local rarity = slot.Rarity
		assert(tutorialOnly or Rarities.Allows(zone, rarity), `Config.Items : {id} est {rarity}, rareté absente de la zone {zone} (Rarities.ZoneOdds)`)
		local rank = (ranks[rarity] or 0) + 1
		ranks[rarity] = rank
		local item: Item = {
			Id = id,
			DisplayName = entry.Name,
			Zone = zone,
			Rarity = slot.Rarity,
			Asset = `ITM_{id}`,
			Category = info.category.Name,
			CategoryId = info.category.Id,
			TutorialOnly = tutorialOnly,
			OutOfDraw = outOfDraw,
			Exclusive = false,
			Rank = rank,
			DrawWeight = if outOfDraw then 0 else 1 / (1 + Rarities.IncomeRules.RankStep) ^ (rank - 1),
		}
		add(item)
		local drawable = byRarity[rarity]
		assert(drawable ~= nil, `Config.Items : {id} ({rarity}) ne peut pas être rangé dans une zone`)
		if not tutorialOnly and not outOfDraw then
			table.insert(drawable, item)
			drawn += 1
		end
	end
	-- Chaque rareté de la zone (sauf Secret et Divine, toutes zones) a au moins un objet tirable.
	local zoneRarities: { string } = Rarities.ZoneRarities[zone] or {}
	for _, rarityId in zoneRarities do
		local drawable = byRarity[rarityId]
		assert(drawable == nil or #drawable > 0, `Config.Items : aucun objet {rarityId} tirable en zone {zone}`)
	end
	-- a497 (Cantin, 26/11) : de 8 à 12 objets tirés par zone (catalogue v3).
	if V3 then
		assert(drawn >= DRAWN_PER_ZONE_V3.Min and drawn <= DRAWN_PER_ZONE_V3.Max, `Config.Items : {drawn} objets tirés en zone {zone} (de {DRAWN_PER_ZONE_V3.Min} à {DRAWN_PER_ZONE_V3.Max})`)
	end
end
assert(#LAYOUT == #CATALOG, `Config.Items : {#LAYOUT} zones rangées pour {#CATALOG} zones au catalogue`)
for id in written do
	assert(placed[id], `Config.Items : {id} au catalogue, rangé dans aucune zone`)
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
			OutOfDraw = false,
			Exclusive = false,
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
		OutOfDraw = false,
		Exclusive = true,
		Rank = 1, -- seul de sa rareté dans la caisse (Formulas.ItemIncome ; a497 : table 2, zone IncomeRules.ExclusiveZone)
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

-- a429 : les tables v1 donnent un ItemId v2 (DataService les applique avant le renommage v2 → v3).
for old, new in RENAMED_V1 do
	assert(ById[old] == nil and V2_TO_V3[old] == nil and V2_TO_V3[new] ~= nil, `Config.Items : renommage v1 {old} → {new} incohérent`)
end
for old, new in RETIRED_V1 do
	assert(ById[old] == nil and V2_TO_V3[old] == nil and V2_TO_V3[new] ~= nil, `Config.Items : remplacement v1 {old} → {new} incohérent`)
end

-- a429 : l'objet du tuto du catalogue actif. v2 : le seul TutorialOnly (Pot de nouilles). a497 (v3) : le dernier objet
-- tiré (le meilleur) de TUTORIAL_V3.Zone et TUTORIAL_V3.Rarity dans LAYOUT_V3, un objet ordinaire (Jelly Double-Decker).
local tutorialItemId: string? = nil
for _, item in List do
	if item.TutorialOnly then
		assert(tutorialItemId == nil, `Config.Items : deux objets TutorialOnly ({tutorialItemId}, {item.Id})`)
		tutorialItemId = item.Id
	end
end
if V3 then
	local byRarity = ByZone[TUTORIAL_V3.Zone]
	local drawable: { Item }? = if byRarity then byRarity[TUTORIAL_V3.Rarity] else nil
	assert(drawable ~= nil and #drawable > 0, `Config.Items : aucun objet {TUTORIAL_V3.Rarity} tiré en zone {TUTORIAL_V3.Zone} pour le tuto`)
	tutorialItemId = drawable[#drawable].Id
end
assert(tutorialItemId ~= nil, "Config.Items : aucun objet du tuto")

-- a429 : l'objet actif pour un ItemId de la v2 ou de la v3 (même rareté ; a497 : la zone peut changer, LAYOUT_V3) ; nil
-- s'il n'est dans aucun.
local function resolve(id: string): Item?
	local item = ById[id]
	if item ~= nil then
		return item
	end
	local other = if V3 then V2_TO_V3[id] else V3_TO_V2[id]
	return if other ~= nil then ById[other] else nil
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
	-- a429 (L-327, L-339) : catalogue v3 derrière Features.ItemsV3 / ItemsV3Dev.
	Version = if V3 then 3 else 2,
	V2ToV3 = V2_TO_V3,
	V3ToV2 = V3_TO_V2,
	Resolve = resolve,
	TutorialItemId = tutorialItemId :: string,
	OtherAssets = OTHER_ASSETS,
}

export type Items = typeof(Items)

return DeepFreeze(Items)
