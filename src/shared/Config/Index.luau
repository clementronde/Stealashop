--!strict
-- Index des objets (DEV-111 ; Partie 2, section 3.4, avancé avant la MAJ 2 : liaison L-071, point 1).
-- Un objet du catalogue (Config/Items) est découvert la première fois que le joueur le possède
-- (IndexService). Règles communes au serveur (IndexService ; DataService pour la migration des
-- profils en v4) et au client (IndexController, écran UI_Index de Clément).
--
--   Index.ZoneBonus     0,05 : une zone complète donne +5 % de revenus permanents (doc 3.4). Bonus en
--                       pour cent : il s'additionne aux autres (Partie 2, section 4 ;
--                       DisplayService.GetIncomeBonus)
--   Index.Attribute     « IndexDiscovered » : attribut du Player posé par IndexService, lu par
--                       IndexController (texte d'Index.Encode)
--   Index.ZoneCount     6 : les zones du couloir (Config/Zones), onglets Zone1Tab à Zone6Tab
--   Index.Total         objets du catalogue, Secrets compris (83) : le compteur « 23 / 83 discovered »
--   Index.ByZone[zone]  objets de la zone, dans l'ordre du catalogue, objet du tuto compris (le Pot de
--                       nouilles compte en zone 1 : 13 objets, comme la maquette « MINI MART 9 / 13 »)
--   Index.Secrets       les Secrets (onglet SecretsTab) : hors des zones, comptés dans le total
--   Index.CountZone(discovered, zone) -> (trouvés, total)
--   Index.CountSecrets(discovered) -> (trouvés, total)
--   Index.CountAll(discovered) -> number                 objets du catalogue découverts
--   Index.IsZoneComplete(discovered, zone) -> boolean    tous les objets de la zone (les Secrets n'en
--                                                        font partie d'aucune)
--   Index.CompletedZones(discovered) -> { number }       zones complètes, dans l'ordre
--   Index.IncomeBonus(discovered) -> number              ZoneBonus × zones complètes (0,1 = +10 %)
--   Index.Encode(discovered) -> string                   ItemId découverts du catalogue, dans son ordre,
--                                                        séparés par des virgules
--   Index.Decode(text) -> { [ItemId]: true }             l'inverse ; ItemId inconnus du catalogue ignorés
-- discovered : table [ItemId] = valeur vraie (dans le profil : os.time() de la découverte).
-- Index complet (les 83) = aura exclusive « Collectionneur » (doc 3.4) : pas encore créée, rien ici.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Items = require(script.Parent.Items)
local Zones = require(script.Parent.Zones)

type Item = Items.Item
export type Discovered = { [string]: any }

local ZONE_COUNT = #Zones

local byZone: { [number]: { Item } } = {}
for zone = 1, ZONE_COUNT do
	byZone[zone] = {}
end
local secrets: { Item } = {}
for _, item in Items.List do
	local zone = item.Zone
	if zone == nil then
		table.insert(secrets, item)
	else
		local list = byZone[zone]
		assert(list ~= nil, `Config.Index : {item.Id} en zone {zone}, hors des {ZONE_COUNT} zones de Config/Zones`)
		table.insert(list, item)
	end
end

local function count(list: { Item }, discovered: Discovered): (number, number)
	local found = 0
	for _, item in list do
		if discovered[item.Id] then
			found += 1
		end
	end
	return found, #list
end

local function countZone(discovered: Discovered, zone: number): (number, number)
	local list = byZone[zone]
	if list == nil then
		return 0, 0
	end
	return count(list, discovered)
end

local function isZoneComplete(discovered: Discovered, zone: number): boolean
	local found, total = countZone(discovered, zone)
	return total > 0 and found == total
end

local function completedZones(discovered: Discovered): { number }
	local zones: { number } = {}
	for zone = 1, ZONE_COUNT do
		if isZoneComplete(discovered, zone) then
			table.insert(zones, zone)
		end
	end
	return zones
end

local Index = {
	ZoneBonus = 0.05, -- doc 3.4 : zone complète = +5 % de revenus permanents
	Attribute = "IndexDiscovered", -- V0 proposé, absent du doc : nom de l'attribut du Player
	ZoneCount = ZONE_COUNT,
	Total = #Items.List,
	ByZone = byZone,
	Secrets = secrets,
}

function Index.CountZone(discovered: Discovered, zone: number): (number, number)
	return countZone(discovered, zone)
end

function Index.CountSecrets(discovered: Discovered): (number, number)
	return count(secrets, discovered)
end

function Index.CountAll(discovered: Discovered): number
	return (count(Items.List, discovered))
end

function Index.IsZoneComplete(discovered: Discovered, zone: number): boolean
	return isZoneComplete(discovered, zone)
end

function Index.CompletedZones(discovered: Discovered): { number }
	return completedZones(discovered)
end

function Index.IncomeBonus(discovered: Discovered): number
	return Index.ZoneBonus * #completedZones(discovered)
end

function Index.Encode(discovered: Discovered): string
	local ids: { string } = {}
	for _, item in Items.List do
		if discovered[item.Id] then
			table.insert(ids, item.Id)
		end
	end
	return table.concat(ids, ",")
end

function Index.Decode(text: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			if Items.ById[id] ~= nil then
				set[id] = true
			end
		end
	end
	return set
end

export type Index = typeof(Index)

return DeepFreeze(Index)
