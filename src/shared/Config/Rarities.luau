--!strict
-- Raretés, attente d'ouverture et probabilités par type de colis (Partie 1, sections 7.3, 5.6, 5.7 et 2.4).
-- L'Id est la valeur stockée dans la sauvegarde (Boxes[..].Rarity, 9.5), par exemple "Epic".

local DeepFreeze = require(script.Parent.DeepFreeze)

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

-- Halo de rareté autour d'un colis porté ou d'un objet exposé (5.6)
export type Halo = "None" | "Light" | "Clear" | "Rays" | "Rainbow"

export type Rarity = {
	Id: RarityId,
	Order: number, -- 1 = Commun … 7 = Secret, pour comparer deux raretés
	DisplayName: string,
	DisplayNameUpper: string, -- string.upper ne met pas les lettres accentuées en majuscules
	ColorName: string, -- couleur écrite dans le doc (7.3)
	Color: Color3, -- planche de style de Clément (doc 10.6, MOD-002), validée à deux le 2026-11-06 (liaison L-018)
	Rainbow: boolean, -- couleur animée arc-en-ciel (Secret)
	RainbowColors: { Color3 }?, -- suite de couleurs de l'arc-en-ciel animé (Secret, doc 10.6)
	IncomeMultiplier: number, -- M rareté de la formule du revenu (7.1)
	OpenDelay: number, -- attente d'ouverture d'un colis PNJ, en secondes
	Halo: Halo,
	FullReveal: boolean, -- storyboard complet (Rare et plus), sinon version courte de 2 s (5.7)
	Confetti: boolean, -- confettis plein écran (Épique et plus)
	Announce: boolean, -- annonce à tout le serveur et animation Celebrate (Légendaire et plus)
	SlowMotion: boolean, -- ralenti, musique unique et arc-en-ciel (Secret)
}

local List: { Rarity } = {
	{
		Id = "Common",
		Order = 1,
		DisplayName = "Commun",
		DisplayNameUpper = "COMMUN",
		ColorName = "Gris",
		Color = Color3.fromHex("#B0B7C3"),
		Rainbow = false,
		IncomeMultiplier = 1,
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
		DisplayName = "Peu commun",
		DisplayNameUpper = "PEU COMMUN",
		ColorName = "Vert",
		Color = Color3.fromHex("#2FE08F"), -- vert menthe : ne disparaît pas sur l'herbe
		Rainbow = false,
		IncomeMultiplier = 2,
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
		IncomeMultiplier = 5,
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
		DisplayName = "Épique",
		DisplayNameUpper = "ÉPIQUE",
		ColorName = "Violet",
		Color = Color3.fromHex("#A855F7"),
		Rainbow = false,
		IncomeMultiplier = 15,
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
		DisplayName = "Légendaire",
		DisplayNameUpper = "LÉGENDAIRE",
		ColorName = "Or",
		Color = Color3.fromHex("#FFC21A"),
		Rainbow = false,
		IncomeMultiplier = 50,
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
		DisplayName = "Mythique",
		DisplayNameUpper = "MYTHIQUE",
		ColorName = "Rouge",
		Color = Color3.fromHex("#FF3B5C"),
		Rainbow = false,
		IncomeMultiplier = 200,
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
		IncomeMultiplier = 1_000,
		OpenDelay = 15 * 60,
		Halo = "Rainbow",
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = true,
	},
}

local ById: { [string]: Rarity } = {}
for _, rarity in List do
	ById[rarity.Id] = rarity
end

-- Probabilités de tirage par type de colis, en pour cent (chaque colonne fait 100).
-- BoxOdds[BoxTier][RarityId] = pourcentage.
local BoxOdds: { [string]: { [string]: number } } = {
	Standard = { Common = 70, Uncommon = 22, Rare = 7, Epic = 1, Legendary = 0, Mythic = 0, Secret = 0 },
	Premium = { Common = 35, Uncommon = 35, Rare = 20, Epic = 8, Legendary = 1.8, Mythic = 0.2, Secret = 0 },
	Luxe = { Common = 0, Uncommon = 25, Rare = 40, Epic = 25, Legendary = 8, Mythic = 1.8, Secret = 0.2 },
}

local Rarities = {
	List = List, -- dans l'ordre, de Commun à Secret
	ById = ById,
	BoxOdds = BoxOdds,
}

export type Rarities = typeof(Rarities)

return DeepFreeze(Rarities)
