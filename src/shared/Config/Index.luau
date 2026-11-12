--!strict
-- Index des objets (DEV-111 ; Partie 2, section 3.4, avancé avant la MAJ 2 : liaison L-071, point 1).
-- Un objet du catalogue (Config/Items) est découvert la première fois que le joueur le possède
-- (IndexService). Règles communes au serveur (IndexService ; DataService pour la migration des
-- profils en v4) et au client (IndexController, écran UI_Index de Clément).
--
--   Index.ZoneBonus     0,05 : une zone complète donne +5 % de revenus permanents (doc 3.4). Bonus en
--                       pour cent : il s'additionne aux autres (Partie 2, section 4 ;
--                       DisplayService.GetIncomeBonus)
--   Récompense d'une zone complète, en plus des +5 % (Clément, 2026-11-10, liaison L-083 point 7 : à la
--   place de l'aura « Collectionneur », chaque zone complète donne de l'argent et de la vitesse) :
--   Index.ZoneCashMinutes   10 : prime unique = 10 min de revenu de la collection complète de la zone
--                           exposée (Index.ZoneCash), versée une fois par zone et par joueur (IndexService)
--   Index.ZoneSpeedBonus    0,03 : +3 % de WalkSpeed permanent par zone complète (StatsService,
--                           modificateur « Index ») : × 1,18 avec les 6 zones
--   Index.ZoneCash(zone) -> number              prime de la zone, en $ (entier), 0 pour une zone inconnue
--   Index.SpeedMultiplier(discovered) -> number 1 + ZoneSpeedBonus × zones complètes
--   Index.ZoneReward(zone) -> ZoneReward        { Cash, Speed, Income } : prime ($), vitesse et revenus
--                                               (fractions : 0,03 = +3 %) d'une zone, pour l'écran
--   Index.ZoneRewardText(zone) -> string        la même, écrite pour le joueur (anglais, L-036) :
--                                               « +$10.2K +3% SPEED +5% INCOME » (RewardLabel)
--   Index.Attribute    « IndexDiscovered » : attribut du Player posé par IndexService, lu par
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
-- Index complet (les 83) : l'aura « Collectionneur » du doc 3.4 est abandonnée (Clément, 2026-11-10,
-- L-083 point 7) ; ce sont les zones complètes qui récompensent (argent et vitesse en plus des +5 %).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Format = require(script.Parent.Parent.Format)
local Formulas = require(script.Parent.Formulas)
local Items = require(script.Parent.Items)
local Zones = require(script.Parent.Zones)

type Item = Items.Item
export type Discovered = { [string]: any }
-- Récompense d'une zone complète : Cash en $, Speed et Income en fractions (0,03 = +3 %).
export type ZoneReward = {
	Cash: number,
	Speed: number,
	Income: number,
}

local ZONE_COUNT = #Zones

local byZone: { [number]: { Item } } = {}
for zone = 1, ZONE_COUNT do
	byZone[zone] = {}
end
-- Objets sans zone : les Secrets, et aussi les Divins quand le catalogue en aura (L-106 ; même
-- section SecretsSection tant que Clément n'en ajoute pas une à UI_Index_v3).
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

-- V0 proposé, absent du doc : la prime vaut ZONE_CASH_MINUTES min de revenu de la collection complète
-- de la zone exposée (somme des revenus 7.1 de ses objets, sans bonus). Même unité que les récompenses
-- en argent de Config/Rewards (« X min de revenus ») ; 10 min, deux fois J1 du calendrier, pour une
-- collection qui demande un Mythique (zones 2 à 6). Zone 1 : 17 $/s × 600 = 10,2 K$, le prix de la 1re
-- renaissance (Config/Rebirths, 10 K$).
local ZONE_CASH_MINUTES = 10

-- Revenu ($/s) de tous les objets de chaque zone, exposés une fois chacun (Formulas.ItemIncome).
local setIncome: { [number]: number } = {}
for zone = 1, ZONE_COUNT do
	local total = 0
	for _, item in byZone[zone] do
		total += Formulas.ItemIncome(zone, item.Rarity)
	end
	setIncome[zone] = total
end

local Index = {
	ZoneBonus = 0.05, -- doc 3.4 : zone complète = +5 % de revenus permanents
	ZoneCashMinutes = ZONE_CASH_MINUTES, -- V0 proposé, absent du doc (voir plus haut)
	-- V0 proposé, absent du doc : +3 % de WalkSpeed par zone complète, × 1,18 au plus (6 zones). Sous
	-- l'écart entre deux zones voisines (vitesse conseillée +17 % à +38 %, Config/Zones) : on ne saute pas
	-- l'entraînement d'une zone, mais le vigile (0,9 × conseillée − 1) se sème plus facilement.
	ZoneSpeedBonus = 0.03,
	Attribute = "IndexDiscovered", -- V0 proposé, absent du doc : nom de l'attribut du Player
	ZoneCount = ZONE_COUNT,
	Total = #Items.List,
	ByZone = byZone,
	Secrets = secrets,
	-- Écran UI_Index_v3 (L-095 point 1 ; IndexController, client seulement). Valeurs du prototype de
	-- Clément tools/clement/index_v3.luau, validé le 2026-11-10, et du tableau docs/claude/notes/
	-- ui-motion-skilltree.md (T.29 Swap, T.45 DetailPop, T.46 RewardsSwap), sauf les lignes « V0 ».
	View = {
		ClipDarken = 0.55, -- prototype : fond Clip d'un objet pas trouvé = couleur de la rareté vers le noir à 55 %
		SilhouetteDarken = 0.82, -- prototype : silhouette (Icon.ImageColor3) = couleur de la rareté vers le noir à 82 %
		RarityLighten = 0.3, -- prototype : DetailRarity.TextColor3 = couleur de la rareté vers le blanc à 30 %
		ViewMargin = 30, -- prototype : une section est « visible » quand son haut passe 30 px sous le haut de la liste
		-- T.45 : DetailIcon 0,82 → 1 en 0,16 à chaque clic sur une carte, Back Out.
		DetailPop = { From = 0.82, Time = 0.16, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out },
		-- T.46 : Rewards 0,92 → 1 en 0,18 quand la zone visible change, Back Out.
		RewardsSwap = { From = 0.92, Time = 0.18, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out },
		-- T.29 Swap, entrée (comme OpenStagger) : chaque carte 0 → 1 en 0,14, départ à 0,08, 0,035 entre
		-- deux, 14 au plus, Back Out. La sortie (cartes à 0 avant le changement) n'est pas faite (V0).
		CardsIn = { Time = 0.14, Start = 0.08, Gap = 0.035, Max = 14, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out },
		-- Prototype : les onglets de mutation entrent à 0,05 s d'écart, 0 → 1 en 0,14, Back Out.
		TabsIn = { Time = 0.14, Gap = 0.05, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out },
		-- Prototype : « Claim » sur une zone pas complète, son UI_Deny et le bouton tremble (décalages en
		-- part de la largeur de son parent, un toutes les 0,04 s, puis retour à sa place).
		Deny = { Sound = "UI_Deny", Offsets = { -0.03, 0.03, -0.02, 0.02 }, Step = 0.04 },
	},
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

function Index.ZoneCash(zone: number): number
	local income = setIncome[zone]
	if income == nil then
		return 0
	end
	return math.floor(income * ZONE_CASH_MINUTES * 60)
end

function Index.SpeedMultiplier(discovered: Discovered): number
	return 1 + Index.ZoneSpeedBonus * #completedZones(discovered)
end

function Index.ZoneReward(zone: number): ZoneReward
	return { Cash = Index.ZoneCash(zone), Speed = Index.ZoneSpeedBonus, Income = Index.ZoneBonus }
end

-- V0 proposé, absent du doc : texte du RewardLabel (maquette de Clément : « +5% INCOME »).
function Index.ZoneRewardText(zone: number): string
	local reward = Index.ZoneReward(zone)
	return `+{Format.money(reward.Cash)} +{math.round(reward.Speed * 100)}% SPEED +{math.round(reward.Income * 100)}% INCOME`
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
