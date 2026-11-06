--!strict
-- Catalogue des objets V1 : un objet par zone et par rareté, plus le Secret
-- (Partie 1, section 10.5). 37 objets au MVP. Toilettes en or : Partie 2, absent ici.
--
-- ItemId = nom du modèle sans le préfixe ITM_ (convention 10.3 et 9.5) :
-- modèle `ITM_Z3_Smartphone` <-> ItemId "Z3_Smartphone", stocké dans Items[uid].Id.
-- Le Secret n'a pas de zone : il prend la catégorie "Secret" (V0 proposé, absent du doc).
-- Revenu d'un objet : Formulas.ItemIncome (R zone × M rareté × M global).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Rarities = require(script.Parent.Rarities)

export type Item = {
	Id: string, -- ItemId
	DisplayName: string,
	Zone: number?, -- nil pour un Secret (toutes zones)
	Rarity: Rarities.RarityId,
	Asset: string, -- nom du modèle dans ReplicatedStorage/Assets
}

-- Raretés des 6 colonnes du catalogue, dans l'ordre.
local ZONE_RARITIES: { Rarities.RarityId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- [zone] = 6 objets de Commun à Mythique : { nom PascalCase de l'ItemId, nom affiché }
local CATALOG: { { { string } } } = {
	{ -- Zone 1 · Supérette
		{ "CanetteDeSoda", "Canette de soda" },
		{ "PaquetDeChips", "Paquet de chips" },
		{ "PotDeNouilles", "Pot de nouilles" },
		{ "BoissonEnergisante", "Boisson énergisante" },
		{ "TicketAGratterGagnant", "Ticket à gratter gagnant" },
		{ "HotDogEnOr", "Hot-dog en or" },
	},
	{ -- Zone 2 · Jouets
		{ "CanardEnPlastique", "Canard en plastique" },
		{ "YoYo", "Yo-yo" },
		{ "VoitureTelecommandee", "Voiture télécommandée" },
		{ "RobotJouet", "Robot jouet" },
		{ "PelucheGeante", "Peluche géante" },
		{ "FigurineHolographique", "Figurine holographique" },
	},
	{ -- Zone 3 · Électronique
		{ "Ecouteurs", "Écouteurs" },
		{ "Manette", "Manette" },
		{ "Smartphone", "Smartphone" },
		{ "ConsolePortable", "Console portable" },
		{ "PcGamer", "PC gamer" },
		{ "CarteGraphiqueEnOr", "Carte graphique en or" },
	},
	{ -- Zone 4 · Bijouterie
		{ "Bague", "Bague" },
		{ "Montre", "Montre" },
		{ "CollierDePerles", "Collier de perles" },
		{ "DiamantBrut", "Diamant brut" },
		{ "Couronne", "Couronne" },
		{ "OeufEnDiamant", "Œuf en diamant" },
	},
	{ -- Zone 5 · Galerie
		{ "Vase", "Vase" },
		{ "BusteEnMarbre", "Buste en marbre" },
		{ "ToileAbstraite", "Toile abstraite" },
		{ "StatueDoree", "Statue dorée" },
		{ "MasqueAncien", "Masque ancien" },
		{ "Meteorite", "Météorite" },
	},
	{ -- Zone 6 · Banque
		{ "LiasseDeBillets", "Liasse de billets" },
		{ "SacDePieces", "Sac de pièces" },
		{ "LingotDOr", "Lingot d'or" },
		{ "MalletteDeBillets", "Mallette de billets" },
		{ "CoffreDeDiamants", "Coffre de diamants" },
		{ "CleDuCoffreUltime", "Clé du coffre ultime" },
	},
}

-- Secrets, toutes zones (0,2 % des colis Luxe) : { nom PascalCase, nom affiché }
local SECRETS: { { string } } = {
	{ "ChatPorteBonheurDore", "Chat porte-bonheur doré" },
}

local List: { Item } = {}
local ById: { [string]: Item } = {}
local ByZone: { { [string]: Item } } = {} -- [zone][RarityId] = Item, raretés Commun à Mythique
local Secrets: { Item } = {}

local function add(item: Item)
	assert(ById[item.Id] == nil, `Config.Items : ItemId en double {item.Id}`)
	table.insert(List, item)
	ById[item.Id] = item
end

for zone, entries in CATALOG do
	ByZone[zone] = {}
	for column, entry in entries do
		local id = `Z{zone}_{entry[1]}`
		local item: Item = {
			Id = id,
			DisplayName = entry[2],
			Zone = zone,
			Rarity = ZONE_RARITIES[column],
			Asset = `ITM_{id}`,
		}
		add(item)
		ByZone[zone][item.Rarity] = item
	end
end

for _, entry in SECRETS do
	local id = `Secret_{entry[1]}`
	local item: Item = {
		Id = id,
		DisplayName = entry[2],
		Zone = nil,
		Rarity = "Secret",
		Asset = `ITM_{id}`,
	}
	add(item)
	table.insert(Secrets, item)
end

local Items = {
	List = List, -- zone par zone, de Commun à Mythique, puis les Secrets
	ById = ById,
	ByZone = ByZone, -- Items.ByZone[3].Rare = Smartphone
	Secrets = Secrets, -- tirés quand la rareté est Secret, quelle que soit la zone
}

export type Items = typeof(Items)

return DeepFreeze(Items)
