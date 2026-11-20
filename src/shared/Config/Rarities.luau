--!strict
-- Raretés, attente d'ouverture et probabilités par type de colis (Partie 1, sections 7.3, 5.6, 5.7 et 2.4).
-- L'Id est la valeur stockée dans la sauvegarde (Boxes[..].Rarity, 9.5), par exemple "Epic".
-- Divine (8e rareté, au-dessus de Secret) : décidée par Clément (doc section 15, 2026-11-08 et
-- 2026-11-12 ; liaison L-106 point 1), couleur #FFE9A8. Ses autres valeurs sont des V0 proposés,
-- absents du doc (table 7.3). Comme le Secret, elle est tirée toutes zones confondues
-- (Items.AllZones). Tant que le catalogue n'a aucun objet Divine, sa chance de tirage reste à 0
-- (BoxOdds, plus bas).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret" | "Divine"

-- Halo de rareté autour d'un colis porté ou d'un objet exposé (5.6)
export type Halo = "None" | "Light" | "Clear" | "Rays" | "Rainbow" | "Divine"

export type Rarity = {
	Id: RarityId,
	Order: number, -- 1 = Commun … 7 = Secret, 8 = Divine, pour comparer deux raretés
	DisplayName: string,
	DisplayNameUpper: string, -- string.upper ne met pas les lettres accentuées en majuscules
	ColorName: string, -- couleur écrite dans le doc (7.3)
	Color: Color3, -- planche de style de Clément (doc 10.6, MOD-002), validée à deux le 2026-11-06 (liaison L-018)
	Rainbow: boolean, -- couleur animée arc-en-ciel (Secret)
	RainbowColors: { Color3 }?, -- suite de couleurs de l'arc-en-ciel animé (Secret, doc 10.6)
	Income: number, -- vague 76 : $/s de base de la rareté (Formulas.ItemIncome), avant zone, rang, mutation et poids
	OpenDelay: number, -- attente d'ouverture d'un colis PNJ, en secondes
	Halo: Halo,
	FullReveal: boolean, -- storyboard complet (Rare et plus), sinon version courte de 2 s (5.7)
	Confetti: boolean, -- confettis plein écran (Épique et plus)
	Announce: boolean, -- annonce à tout le serveur et animation Celebrate (Légendaire et plus)
	SlowMotion: boolean, -- ralenti et musique unique (Secret, Divine) ; l'arc-en-ciel, c'est Rainbow
}

local List: { Rarity } = {
	{
		Id = "Common",
		Order = 1,
		DisplayName = "Common",
		DisplayNameUpper = "COMMON",
		ColorName = "Gris",
		Color = Color3.fromHex("#B0B7C3"),
		Rainbow = false,
		Income = 1, -- V0 (Cantin et Clément, 19/11)
		OpenDelay = 10,
		Halo = "None",
		FullReveal = false,
		Confetti = false,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Uncommon",
		Order = 2,
		DisplayName = "Uncommon",
		DisplayNameUpper = "UNCOMMON",
		ColorName = "Vert",
		Color = Color3.fromHex("#2FE08F"), -- vert menthe : ne disparaît pas sur l'herbe
		Rainbow = false,
		Income = 8, -- V0 (Cantin et Clément, 19/11)
		OpenDelay = 20,
		Halo = "Light",
		FullReveal = false,
		Confetti = false,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Rare",
		Order = 3,
		DisplayName = "Rare",
		DisplayNameUpper = "RARE",
		ColorName = "Bleu",
		Color = Color3.fromHex("#2F9BFF"),
		Rainbow = false,
		Income = 60, -- V0 (Cantin et Clément, 19/11)
		OpenDelay = 45,
		Halo = "Clear",
		FullReveal = true,
		Confetti = false,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Epic",
		Order = 4,
		DisplayName = "Epic",
		DisplayNameUpper = "EPIC",
		ColorName = "Violet",
		Color = Color3.fromHex("#A855F7"),
		Rainbow = false,
		Income = 450, -- V0 (Cantin et Clément, 19/11)
		OpenDelay = 90,
		Halo = "Clear",
		FullReveal = true,
		Confetti = true,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Legendary",
		Order = 5,
		DisplayName = "Legendary",
		DisplayNameUpper = "LEGENDARY",
		ColorName = "Or",
		Color = Color3.fromHex("#FFC21A"),
		Rainbow = false,
		Income = 3_500, -- V0 (Cantin et Clément, 19/11)
		OpenDelay = 3 * 60,
		Halo = "Rays",
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = false,
	},
	{
		Id = "Mythic",
		Order = 6,
		DisplayName = "Mythic",
		DisplayNameUpper = "MYTHIC",
		ColorName = "Rouge",
		Color = Color3.fromHex("#FF3B5C"),
		Rainbow = false,
		Income = 25_000, -- V0 (Cantin et Clément, 19/11)
		OpenDelay = 8 * 60,
		Halo = "Rays",
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = false,
	},
	{
		Id = "Secret",
		Order = 7,
		DisplayName = "Secret",
		DisplayNameUpper = "SECRET",
		ColorName = "Arc-en-ciel animé",
		Color = Color3.fromHex("#FF3B3B"), -- première couleur de l'arc-en-ciel, pour un affichage fixe
		Rainbow = true,
		RainbowColors = {
			Color3.fromHex("#FF3B3B"),
			Color3.fromHex("#FFC21A"),
			Color3.fromHex("#3BE15A"),
			Color3.fromHex("#2F9BFF"),
			Color3.fromHex("#A855F7"),
		},
		Income = 150_000, -- V0 (Cantin et Clément, 19/11)
		OpenDelay = 15 * 60,
		Halo = "Rainbow",
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = true,
	},
	{
		-- L-106 point 1 : Id, couleur et place au-dessus de Secret. Le reste : V0 proposé, absent du doc.
		Id = "Divine",
		Order = 8,
		DisplayName = "Divine",
		DisplayNameUpper = "DIVINE",
		ColorName = "Or pâle",
		Color = Color3.fromHex("#FFE9A8"), -- L-106 : couleur choisie par Clément
		Rainbow = false, -- couleur fixe
		Income = 750_000, -- V0 proposé : ×5 du Secret, comme avant (aucun objet Divine encore)
		OpenDelay = 30 * 60, -- V0 : 30 min, le double du Secret (la suite double presque à chaque palier)
		Halo = "Divine", -- V0 : rayons plus nombreux et plus lumineux que ceux du Secret, or pâle
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = true, -- V0 : même ralenti que le Secret ; son Unbox_Reveal_Divine s'il est livré
	},
}

local ById: { [string]: Rarity } = {}
for _, rarity in List do
	ById[rarity.Id] = rarity
end

-- Probabilités de tirage par type de colis, en pour cent (chaque colonne fait 100).
-- BoxOdds[BoxTier][RarityId] = pourcentage.
-- Vague 76 (Cantin et Clément, 19/11) : les rayons des magasins n'ont plus de types de colis (rareté du colis tirée
-- dans Rarities.ZoneOdds). Cette table ne sert plus qu'aux colis qui gardent un type : camion, tour de la fortune,
-- colis offerts (récompenses, codes ; UnboxService.GiveItem), aux mêmes chances qu'avant (V0), limitées aux raretés
-- de la zone par ShelfBoxes.OddsFor.
-- Divine : 0 partout tant que le catalogue n'a aucun objet Divine (Items.AllZones.Divine vide).
-- V0 proposé, absent du doc, à poser quand Clément livre les premiers objets Divine : Luxe = 0,02 %
-- (1 colis Luxe sur 5 000, le dixième du Secret), pris sur Rare (40 → 39,98) ; Standard et Premium 0.
-- Une chance > 0 sans objet ne casserait rien (repli de StoreHeistService et de TruckEventService :
-- la rareté tirable la plus proche en dessous, donc un Secret), mais elle augmenterait en silence la
-- chance du Secret au-delà de la table 7.3 : d'où le 0.
local BoxOdds: { [string]: { [string]: number } } = {
	Standard = { Common = 70, Uncommon = 22, Rare = 7, Epic = 1, Legendary = 0, Mythic = 0, Secret = 0, Divine = 0 },
	Premium = { Common = 35, Uncommon = 35, Rare = 20, Epic = 8, Legendary = 1.8, Mythic = 0.2, Secret = 0, Divine = 0 },
	Luxe = { Common = 0, Uncommon = 25, Rare = 40, Epic = 25, Legendary = 8, Mythic = 1.8, Secret = 0.2, Divine = 0 },
}

-- ZoneOdds[zone][RarityId] = pourcentage (chaque zone fait 100) : rareté du colis d'un emplacement du rayon
-- (StoreHeistService, via ShelfBoxes). Une rareté absente (ou à 0) n'existe pas dans la zone : ni colis, ni objet
-- (ZoneRarities ; Config/Items le vérifie).
-- Raretés de chaque zone : décision de Cantin et Clément (19/11) ; pourcentages : V0 proposé (a262) d'après les
-- repères de la consigne (la plus basse ≈ la moitié, chaque rareté au-dessus nettement plus rare, celle qui
-- apparaît dans la zone ≈ 3 %, Mythique de la zone 6 ≈ 0,5 %, Secret ≈ 0,03 %). Ce sont les chances des COLIS :
-- la chance réelle de chaque rareté d'OBJET en découle (contenu des caisses, chance du joueur), plus haute pour les
-- raretés rares (Shared/ItemOdds ; tables du rapport d'a262).
-- Zone 1 (zone du tuto) : le premier colis du tuto garde son objet Rare garanti (Pot de nouilles, TutorialOnly),
-- imposé à la sortie par l'accroche StoreHeistService.SetContentOverride, que pose TutorialService.
export type ZoneOdds = { [number]: { [string]: number } }

local ZONE_ODDS: ZoneOdds = {
	[1] = { Common = 100 },
	[2] = { Common = 97, Uncommon = 3 },
	[3] = { Common = 62, Uncommon = 35, Rare = 3 },
	[4] = { Common = 55, Uncommon = 30, Rare = 12, Epic = 3 },
	[5] = { Uncommon = 55, Rare = 30, Epic = 12, Legendary = 3 },
	[6] = { Rare = 55, Epic = 30, Legendary = 14.47, Mythic = 0.5, Secret = 0.03 },
}

-- [zone] = raretés de la zone, de la plus basse à la plus haute (List) ; [zone][RarityId] = true.
local ZONE_RARITIES: { [number]: { string } } = {}
local ALLOWED: { [number]: { [string]: boolean } } = {}
-- [RarityId] = première zone où la rareté existe (revenu, Formulas.ItemIncome) ; absente : aucune zone.
local FIRST_ZONE: { [string]: number } = {}
for zone, odds in ZONE_ODDS do
	local list: { string } = {}
	local set: { [string]: boolean } = {}
	for _, rarity in List do
		local value = odds[rarity.Id]
		if type(value) == "number" and value > 0 then
			table.insert(list, rarity.Id)
			set[rarity.Id] = true
			local first = FIRST_ZONE[rarity.Id]
			if first == nil or zone < first then
				FIRST_ZONE[rarity.Id] = zone
			end
		end
	end
	ZONE_RARITIES[zone] = list
	ALLOWED[zone] = set
end

-- Temps de prise d'un colis du rayon (et de l'objet qui en sort) selon la rareté du colis, en secondes : les 0,3, 0,6
-- et 1 s des anciens Standard, Premium et Luxe (vague 76, V0 proposé, a262). Lu par StoreHeistService et HeistController.
local GRAB_TIMES: { [string]: number } = {
	Common = 0.3,
	Uncommon = 0.3,
	Rare = 0.6,
	Epic = 0.6,
	Legendary = 1,
	Mythic = 1,
	Secret = 1,
	Divine = 1,
}
local DEFAULT_GRAB_TIME = 0.3 -- V0 : rareté inconnue

local Rarities = {
	List = List, -- dans l'ordre, de Commun à Divine
	ById = ById,
	BoxOdds = BoxOdds,
	-- Vague 76 : rareté des colis du rayon par zone (voir ZONE_ODDS plus haut) et ce qui s'en déduit.
	ZoneOdds = ZONE_ODDS,
	ZoneRarities = ZONE_RARITIES, -- [zone] = raretés de la zone, de la plus basse à la plus haute
	ZoneAllowed = ALLOWED, -- [zone][RarityId] = true
	FirstZone = FIRST_ZONE, -- [RarityId] = première zone où elle existe
	-- La rareté `rarityId` existe-t-elle dans la zone `zone` (colis et objets) ?
	Allows = function(zone: number, rarityId: string): boolean
		local allowed = ALLOWED[zone]
		return allowed ~= nil and allowed[rarityId] == true
	end,
	GrabTimes = GRAB_TIMES,
	-- Temps de prise d'un colis de rareté `rarityId` (DEFAULT_GRAB_TIME si inconnue).
	GrabTime = function(rarityId: string?): number
		local value = if rarityId then GRAB_TIMES[rarityId] else nil
		return if type(value) == "number" then value else DEFAULT_GRAB_TIME
	end,
	-- Vague 76 (Cantin et Clément, 19/11) : revenu d'un objet (Formulas.ItemIncome) = Income de sa rareté
	-- × (1 + ZoneStep × zones au-dessus de la première zone où la rareté existe, FirstZone)
	-- × (1 + RankStep) ^ (rang dans sa zone et sa rareté − 1, ordre de l'index : Items.Item.Rank).
	IncomeRules = {
		ZoneStep = 0.25, -- V0 (Cantin et Clément, 19/11) : +25 % par zone, ajoutés (pas composés)
		RankStep = 0.1, -- V0 (Cantin et Clément, 19/11) : +10 % par rang, composés
	},
}

export type Rarities = typeof(Rarities)

return DeepFreeze(Rarities)
