--!nocheck
-- Banc a268 (vague 81), partie « lots » (harnais d'a266) : lot « colis d'une rareté » donné dans toutes les zones et
-- pour toutes les raretés de Rarities.ZoneRarities (Secret compris), quête StealPlayer (« Top ») en zone 5 et 6,
-- coffre de la semaine jamais sous Épique (2 000 tirages).
local RarityCfg = sharedModule("Config/Rarities")
local ItemCfg = sharedModule("Config/Items")
local RewardsCfg = sharedModule("Config/Rewards")
advance(1000)
startServer()
questTest("days 10")
local Unbox = serverModule("UnboxService")
local ada = join("Ada", newProfile8(), 71)
advance(1.5)

local function itemOfZone(zone)
	for _, item in ItemCfg.List do
		if item.Zone == zone and not item.TutorialOnly then
			return item.Id
		end
	end
end
local function orderOf(id)
	return RarityCfg.ById[id].Order
end

section("quête StealPlayer (Top) en zone 5 et 6")
for _, zone in { 5, 6 } do
	addItem(dataOf(ada), `best{zone}`, itemOfZone(zone), nil, zone)
	setQuests(ada, { "StealPlayer" }, { 1 })
	entryOf(ada, "StealPlayer").Progress = 1
	local keys = itemKeys(ada)
	claimQuest(ada, 1)
	local gifts = giftsSince(ada, keys)
	local list = RarityCfg.ZoneRarities[zone]
	local want = list[#list]
	local def = gifts[1] and ItemCfg.ById[gifts[1].entry.Id]
	check(#gifts == 1, `zone {zone} : un objet donné ({#gifts})`)
	check(def and orderOf(def.Rarity) >= orderOf(want), `zone {zone} : {want} ou mieux ({def and def.Rarity})`)
	check(entryOf(ada, "StealPlayer").Claimed > 0, `zone {zone} : quête réclamée`)
	for _, g in gifts do
		dataOf(ada).Items[g.uid] = nil
	end
end

section("toutes les zones, toutes les raretés de la zone")
local bad, refused, total = 0, 0, 0
for zone, list in RarityCfg.ZoneRarities do
	for _, rarityId in list do
		for _ = 1, 40 do
			local uid, reason, itemId = Unbox.GiveBoxRarityItem(ada, rarityId, zone)
			total += 1
			if uid == nil then
				refused += 1
				if refused <= 3 then print(`ÉCHEC détail : refus {rarityId} zone {zone} ({reason})`) end
			else
				if orderOf(ItemCfg.ById[itemId].Rarity) < orderOf(rarityId) then
					bad += 1
				end
				dataOf(ada).Items[uid] = nil
			end
		end
	end
end
check(refused == 0, `aucun refus ({refused} sur {total})`)
check(bad == 0, `jamais sous la rareté du colis ({bad} sur {total})`)

section("coffre de la semaine : jamais sous Épique")
local boxRarity = RewardsCfg.Weekly.Reward.BoxRarity
check(boxRarity == "Epic", "coffre : colis Épique")
local below, epic, given = 0, 0, 0
local zones = { 1, 4, 5, 6 }
for i = 1, 2000 do
	local uid, _reason, itemId = Unbox.GiveBoxRarityItem(ada, boxRarity, zones[(i - 1) % #zones + 1])
	if uid then
		given += 1
		local rarity = ItemCfg.ById[itemId].Rarity
		if orderOf(rarity) < orderOf("Epic") then below += 1 end
		if rarity == "Epic" then epic += 1 end
		dataOf(ada).Items[uid] = nil
	end
end
check(given == 2000, `2 000 tirages donnés ({given})`)
check(below == 0, `aucun sous Épique ({below})`)
check(epic > 1800, `surtout Épique, un peu au-dessus ({epic} Épiques)`)

summary("scénario a268 lots")
