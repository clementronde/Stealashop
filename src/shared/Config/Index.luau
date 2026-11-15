--!strict
-- Index des objets (DEV-111 ; Partie 2, section 3.4, avancé avant la MAJ 2 : liaison L-071, point 1).
-- Un objet du catalogue (Config/Items) est découvert la première fois que le joueur le possède
-- (IndexService). Règles communes au serveur (IndexService ; DataService pour la migration des
-- profils en v4) et au client (IndexController, écran UI_Index de Clément).
--
--   Récompense d'une zone complète (décisions de Clément, 2026-11-15, liaison L-183 puis L-192 ; vagues 59
--   et 61) : UN OBJET SEULEMENT, donné une seule fois quand le joueur la réclame (IndexService) ; ni argent,
--   ni vitesse, ni diamants (la prime et la Vitesse d'a191 sont retirées, comme les pourcentages d'avant) :
--   Index.ZoneRewards[zone]  { Item = { Kind, Id } } : un objet de boutique donné
--                            (Kind = "Weapon" : Config/Tools ; "Aura" ou "Trail" : Config/Cosmetics)
--   Index.ZoneReward(zone) -> ZoneReward?       la ligne de ZoneRewards (nil pour une zone inconnue)
--   Index.ZoneRewardName(zone) -> string        nom de l'objet donné (« Wrench »), "" sans récompense
--   Index.ZoneRewardIcon(zone) -> string?       nom à passer à Contract/Icons.get pour l'icône de boutique
--                                               de l'objet (« TOOL_Wrench », « Aura_Flamme »), nil sans
--   Index.ZoneRewardText(zone) -> string        la récompense écrite pour le joueur (anglais, L-036) :
--                                               « +WRENCH » (RewardLabel, ClaimButton.RewardCaption)
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
--   Index.Encode(discovered) -> string                   ItemId découverts du catalogue, dans son ordre,
--                                                        séparés par des virgules
--   Index.Decode(text) -> { [ItemId]: true }             l'inverse ; ItemId inconnus du catalogue ignorés
--   Prime réclamée (L-127 point 2, vague 34) : elle n'est plus versée toute seule, le joueur la réclame
--   (remote ClaimIndexReward, IndexService) :
--   Index.ClaimedAttribute  « IndexClaimed » : attribut du Player, les zones dont la prime est réclamée
--   Index.EncodeZones(zones) -> string                   « 1,3 » : zones 1 à ZoneCount présentes dans
--                                                        `zones` (clé « 3 » du profil ou 3)
--   Index.DecodeZones(text) -> { [number]: true }        l'inverse ; zone hors de 1..ZoneCount ignorée
--   Index.ClaimableZones(discovered, claimed) -> { number }  zones complètes pas encore réclamées
-- discovered : table [ItemId] = valeur vraie (dans le profil : os.time() de la découverte).
-- Index complet (les 83) : l'aura « Collectionneur » du doc 3.4 est abandonnée (Clément, 2026-11-10,
-- L-083 point 7) ; ce sont les zones complètes qui récompensent (un objet chacune, L-192).
-- Écran UI_Index_v4 (L-183) : Index.View.PageSize cartes par page (grille 4 × 2 de Cards).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Cosmetics = require(script.Parent.Cosmetics)
local Items = require(script.Parent.Items)
local Tools = require(script.Parent.Tools)
local Zones = require(script.Parent.Zones)

type Item = Items.Item
export type Discovered = { [string]: any }
export type RewardKind = "Weapon" | "Aura" | "Trail"
-- Récompense d'une zone complète : Item, l'objet donné (L-192 : rien d'autre).
export type ZoneReward = {
	Item: { Kind: RewardKind, Id: string },
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

-- Objets gardés par Clément (L-192, 2026-11-15) ; choisis par a191 (V0) : un objet visé par la zone suivante
-- (Kit de Config/Zones ou TargetZones), deux de chaque sorte : Wrench (300 $), Flame (60 K$), Turbo (1 M$),
-- Sledgehammer (20 M$), Galaxy (400 M$), Hyperspace (2,5 B$). Déjà possédé : rien de plus (ni doublon, ni
-- argent à la place).
local ZONE_REWARDS: { [number]: ZoneReward } = {
	{ Item = { Kind = "Weapon", Id = "Wrench" } },
	{ Item = { Kind = "Aura", Id = "Flame" } },
	{ Item = { Kind = "Trail", Id = "Turbo" } },
	{ Item = { Kind = "Weapon", Id = "Sledgehammer" } },
	{ Item = { Kind = "Aura", Id = "Galaxy" } },
	{ Item = { Kind = "Trail", Id = "Hyperspace" } },
}
for zone = 1, ZONE_COUNT do
	local reward = ZONE_REWARDS[zone]
	assert(reward ~= nil, `Config.Index : pas de récompense pour la zone {zone}`)
	local item = reward.Item
	if item.Kind == "Weapon" then
		assert(Tools.ById[item.Id] ~= nil, `Config.Index : arme {item.Id} (zone {zone}) absente de Config/Tools`)
	else
		local cosmetic = Cosmetics.ById[item.Id]
		assert(cosmetic ~= nil and cosmetic.Kind == item.Kind, `Config.Index : {item.Kind} {item.Id} (zone {zone}) absent de Config/Cosmetics`)
	end
end

local Index = {
	ZoneRewards = ZONE_REWARDS,
	Attribute = "IndexDiscovered", -- V0 proposé, absent du doc : nom de l'attribut du Player
	ClaimedAttribute = "IndexClaimed", -- V0 proposé, absent du doc : zones dont la prime est réclamée (L-127)
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
		-- UI_Index_v4 (L-183, vague 59) : grille Cards de 4 × 2 cartes, Footer.Pager pour les pages suivantes.
		PageSize = 8,
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

function Index.ZoneReward(zone: number): ZoneReward?
	return ZONE_REWARDS[zone]
end

function Index.ZoneRewardName(zone: number): string
	local reward = ZONE_REWARDS[zone]
	if reward == nil then
		return ""
	end
	local item = reward.Item
	local def: any = if item.Kind == "Weapon" then Tools.ById[item.Id] else Cosmetics.ById[item.Id]
	return if def then def.DisplayName else item.Id
end

function Index.ZoneRewardIcon(zone: number): string?
	local reward = ZONE_REWARDS[zone]
	if reward == nil then
		return nil
	end
	local item = reward.Item
	if item.Kind == "Weapon" then
		return "TOOL_" .. item.Id -- ICON_TOOL_<Id>, comme la boutique d'armes (L-090)
	end
	local cosmetic = Cosmetics.ById[item.Id]
	local texture = if cosmetic then cosmetic.Texture else nil
	if type(texture) ~= "string" then
		return nil
	end
	-- FX_Aura_Flamme → ICON_Aura_Flamme, comme la boutique d'auras (L-171)
	return if string.sub(texture, 1, 3) == "FX_" then string.sub(texture, 4) else texture
end

-- V0 proposé, absent du doc : texte de la récompense (RewardLabel, ClaimButton.RewardCaption, Notify).
function Index.ZoneRewardText(zone: number): string
	if ZONE_REWARDS[zone] == nil then
		return ""
	end
	return `+{string.upper(Index.ZoneRewardName(zone))}`
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

function Index.EncodeZones(zones: { [any]: any }): string
	local list: { string } = {}
	for zone = 1, ZONE_COUNT do
		if zones[tostring(zone)] ~= nil or zones[zone] ~= nil then
			table.insert(list, tostring(zone))
		end
	end
	return table.concat(list, ",")
end

function Index.DecodeZones(text: any): { [number]: boolean }
	local set: { [number]: boolean } = {}
	if type(text) == "string" then
		for word in string.gmatch(text, "[^,]+") do
			local zone = tonumber(word)
			if zone ~= nil and zone == math.floor(zone) and zone >= 1 and zone <= ZONE_COUNT then
				set[zone] = true
			end
		end
	end
	return set
end

function Index.ClaimableZones(discovered: Discovered, claimed: { [number]: boolean }): { number }
	local zones: { number } = {}
	for _, zone in completedZones(discovered) do
		if not claimed[zone] then
			table.insert(zones, zone)
		end
	end
	return zones
end

export type Index = typeof(Index)

return DeepFreeze(Index)
