--!strict
-- Badges du jeu (vague GC7, a413, 23/11 ; idées du rapport a404, section 7). Donnés par BadgeService (serveur),
-- une seule fois par joueur, quand la condition est vraie dans son profil. Interrupteur : Features.Badges.
--
-- Ids : un badge se crée à la main sur le Creator Hub (jeu → Engagement → Badges), un jeu à la fois. DEV et PROD
-- sont deux jeux Roblox distincts (Config/ProductIds) : Id = celui du jeu PROD, DevId = celui du jeu DEV ; le jeu
-- utilisé est choisi comme pour les offres Robux (ProductIds.IsDev). 0 = badge pas encore créé dans ce jeu : il
-- est sauté, sans erreur ni requête (tous valent 0 tant que Cantin ne les a pas créés).
--
-- Règles (Rule) :
--   Join        le profil est chargé (le joueur est entré dans le jeu) ;
--   Heists      Lifetime.Heists ≥ Min (objets sortis d'un colis PNJ et ramenés en base, UnboxService) ;
--   Steals      Lifetime.Steals ≥ Min (objets volés à un autre joueur et déposés chez soi, PvPService) ;
--   Rarity      l'Index (objets déjà possédés une fois) a un objet de rareté Rarity ou plus rare ;
--   ZoneItem    l'Index a un objet de la zone Zone (catalogue, Config/Items) ;
--   Rebirths    renaissances faites ≥ Min (RebirthService) ;
--   BestIncome  meilleur revenu par seconde de tous les temps (Lifetime.BestIncome, sans les boosts) ≥ Min.
-- Rarity et ZoneItem ne comptent pas les objets exclusifs de la caisse Robux (Items.Exclusives) : un badge ne
-- s'achète pas. Comme l'Index n'oublie rien, un objet revendu, volé ou remis à une renaissance compte encore.
--
-- Name, Description et Image ne sont pas lus par le code : ce sont les textes et l'image à poser sur le Creator Hub
-- (textes en anglais, image carrée 512 × 512, Roblox la découpe en cercle). V0 proposé (Cantin, 23/11).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Rule = "Join" | "Heists" | "Steals" | "Rarity" | "ZoneItem" | "Rebirths" | "BestIncome"

export type Badge = {
	Key: string, -- nom interne, stable (journal de la sortie, bancs)
	Id: number, -- badge du jeu PROD ; 0 = pas créé
	DevId: number, -- badge du jeu DEV ; 0 = pas créé
	Rule: Rule,
	Min: number?, -- Heists, Steals, Rebirths, BestIncome
	Rarity: string?, -- Rarity : RarityId de Config/Rarities
	Zone: number?, -- ZoneItem : 1 à 6
	Name: string, -- nom sur le Creator Hub
	Description: string, -- description sur le Creator Hub
	Image: string, -- image à faire par Clément
}

local Badges = {
	-- V0 proposé (Cantin, 23/11) : secondes entre deux relevés des profils des joueurs présents.
	CheckInterval = 2,
	-- V0 proposé (Cantin, 23/11) : après une erreur de Roblox (réseau, limite de requêtes), secondes avant de
	-- réessayer ce badge pour ce joueur, et nombre d'essais ratés avant d'abandonner jusqu'à la prochaine session.
	RetryDelay = 30,
	MaxTries = 5,
	-- Dans l'ordre où ils sont vérifiés.
	List = {
		{
			Key = "Welcome",
			Id = 734742039332229,
			DevId = 1421862584260439,
			Rule = "Join",
			Name = "Welcome to the Street",
			Description = "Join Steal a Shop for the first time.",
			Image = "The street at dusk with a small shop front, a bright OPEN sign.",
		},
		{
			Key = "FirstHeist",
			Id = 1996896044857741,
			DevId = 1899748846610750,
			Rule = "Heists",
			Min = 1,
			Name = "First Heist",
			Description = "Steal your first item from a store and bring it back to your shop.",
			Image = "A shattered shop window with a mystery box in front.",
		},
		{
			Key = "FirstSteal",
			Id = 3089515347599975,
			DevId = 853103740412758,
			Rule = "Steals",
			Min = 1,
			Name = "Sneaky Thief",
			Description = "Steal an item from another player's shop.",
			Image = "A gloved hand grabbing an item off a display stand.",
		},
		{
			Key = "Legendary",
			Id = 2192011030479327,
			DevId = 3461348261333770,
			Rule = "Rarity",
			Rarity = "Legendary",
			Name = "Legendary Loot",
			Description = "Get a Legendary item (or rarer).",
			Image = "An opened mystery box with a glowing item, Legendary rarity color.",
		},
		{
			Key = "Mythic",
			Id = 4412861862965984,
			DevId = 3741634080661251,
			Rule = "Rarity",
			Rarity = "Mythic",
			Name = "Mythic Find",
			Description = "Get a Mythic item (or rarer).",
			Image = "An opened mystery box with a glowing item, Mythic rarity color.",
		},
		{
			Key = "Secret",
			Id = 12482347170482,
			DevId = 1046738162941963,
			Rule = "Rarity",
			Rarity = "Secret",
			Name = "Secret Finder",
			Description = "Get a Secret item.",
			Image = "A mystery box with a rainbow glow and a question mark.",
		},
		{
			Key = "Zone6",
			Id = 2376081713577200,
			DevId = 1615804164972793,
			Rule = "ZoneItem",
			Zone = 6,
			Name = "End of the Street",
			Description = "Get an item from a Zone 6 store.",
			Image = "The Zone 6 store front with a big ZONE 6 sign.",
		},
		{
			Key = "Reborn",
			Id = 3486392182556727,
			DevId = 1191932509312544,
			Rule = "Rebirths",
			Min = 1,
			Name = "Reborn",
			Description = "Rebirth for the first time.",
			Image = "A golden circular arrow around a small shop.",
		},
		{
			Key = "Millionaire",
			Id = 1297138662347094,
			DevId = 2825808733331096,
			Rule = "BestIncome",
			Min = 1_000_000,
			Name = "Millionaire Shop",
			Description = "Make $1M per second in your shop.",
			Image = "A shop overflowing with cash and a 1M/s sign.",
		},
	} :: { Badge },
}

export type Badges = typeof(Badges)

return DeepFreeze(Badges)
