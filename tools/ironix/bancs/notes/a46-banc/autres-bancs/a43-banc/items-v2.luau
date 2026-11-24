--!strict
-- FAUX Config/Items v2 du banc a23 : la forme de l'API que l'agent a22 construit (catalogue v2,
-- plusieurs objets par zone et par rareté), avec un contenu choisi pour les tests :
--   - zone 1 : 4 Communs, et un Rare (le Pot de nouilles du tuto) que la zone ne tire jamais ;
--   - zone 2 : plusieurs objets par rareté, de Commun à Mythique ;
--   - zone 3 : aucun Légendaire (pour la condition « un objet tirable existe ») ;
--   - zones 4 à 6 : un objet par rareté ;
--   - 2 Secrets.
-- Items.Pick note ses appels dans ITEMS_PICKS (table globale du banc).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Item = {
	Id: string,
	DisplayName: string,
	Zone: number?,
	Rarity: string,
	Asset: string,
	Category: string?,
}

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local CATALOG: { [number]: { [string]: { string } } } = {
	[1] = { Common = { "Banana", "Carrot", "Donut", "SodaCan" }, Rare = { "InstantNoodles" } },
	[2] = {
		Common = { "RubberDuck", "YoYo", "Lollipop" },
		Uncommon = { "RcCar", "ToyRobot" },
		Rare = { "ElectricTrain", "DoubleDecker" },
		Epic = { "TeddyBear", "GingerbreadHouse" },
		Legendary = { "GiantPlush" },
		Mythic = { "HoloFigure" },
	},
	[3] = {
		Common = { "Earbuds", "UsbCable" },
		Uncommon = { "Gamepad", "Mouse" },
		Rare = { "Smartphone", "Tablet" },
		Epic = { "HandheldConsole" },
		Legendary = {},
		Mythic = { "GoldenGpu" },
	},
	[4] = { Common = { "Ring" }, Uncommon = { "GoldWatch" }, Rare = { "Pearls" }, Epic = { "RawDiamond" }, Legendary = { "Crown" }, Mythic = { "DiamondEgg" } },
	[5] = { Common = { "Vase" }, Uncommon = { "MarbleBust" }, Rare = { "Canvas" }, Epic = { "GoldStatue" }, Legendary = { "AncientMask" }, Mythic = { "Meteorite" } },
	[6] = { Common = { "Coins" }, Uncommon = { "Bills" }, Rare = { "GoldBar" }, Epic = { "Briefcase" }, Legendary = { "DiamondChest" }, Mythic = { "UltimateKey" } },
}
local SECRETS = { "GoldenLuckyCat", "GoldenToilet" }

local List: { Item } = {}
local ById: { [string]: Item } = {}
local ByZone: { [number]: { [string]: { Item } } } = {}
local Secrets: { Item } = {}

local function spaced(name: string): string
	return (string.gsub(name, "(%l)(%u)", "%1 %2"))
end

for zone = 1, 6 do
	ByZone[zone] = {}
	for _, rarity in RARITIES do
		ByZone[zone][rarity] = {}
		for _, name in CATALOG[zone][rarity] or {} do
			local id = `Z{zone}_{name}`
			local item: Item = {
				Id = id,
				DisplayName = spaced(name),
				Zone = zone,
				Rarity = rarity,
				Asset = `ITM_{id}`,
				Category = "Test",
			}
			table.insert(List, item)
			ById[id] = item
			table.insert(ByZone[zone][rarity], item)
		end
	end
end
for _, name in SECRETS do
	local id = `Secret_{name}`
	local item: Item = { Id = id, DisplayName = spaced(name), Zone = nil, Rarity = "Secret", Asset = `ITM_{id}`, Category = "???" }
	table.insert(List, item)
	ById[id] = item
	table.insert(Secrets, item)
end

local Items = {
	List = List,
	ById = ById,
	ByZone = ByZone,
	Secrets = Secrets,
	Divines = {}, -- a92 (2026-11-12, rareté Divine, L-106) : ajout pur, comme Config/Items
	AllZones = { Secret = Secrets, Divine = {} }, -- a92 : ajout pur
	Pick = function(zone: number, rarity: string, rng: Random?): Item?
		local list: { Item }
		if rarity == "Secret" then
			list = Secrets
		else
			local byZone = ByZone[zone]
			list = if byZone and byZone[rarity] then byZone[rarity] else {}
		end
		table.insert(ITEMS_PICKS, { zone = zone, rarity = rarity, rng = rng })
		if #list == 0 then
			return nil
		end
		local r = rng or Random.new()
		return list[r:NextInteger(1, #list)]
	end,
}

return DeepFreeze(Items)
