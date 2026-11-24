--!nocheck
-- a309 (22/11, Cantin), scénario « flow » : les vrais RewardService, UnboxService et MonetizationService. Paliers de
-- 15 et 60 min réclamés avec des objets de zones différentes dans le profil : colis de la meilleure zone (15) et de la
-- suivante (60), plafonnée à 6 ; en zone safe la scène de la caisse exclusive (RevealStarted, ShopId ExclusiveCrate,
-- plan lisible) et pas de message ; hors zone safe l'objet et le message « <Rareté> Item: <nom> » ; inventaire plein :
-- refusé, rien de noté ; jour 7 et coffre hebdo inchangés.

advance(1000)
startServer()
days(10)
local Plan = sharedModule("UnboxPlan")
local SafeZoneMod = sharedModule("SafeZone")
local ZoneBoxOdds = sharedModule("ZoneBoxOdds")
local MAX = sharedModule("Config/Balance").Display.InventoryMax
local CRATE = sharedModule("Config/Monetization").Crate.Reveal

local function itemOfZone(zone)
	for _, item in Items.List do
		if item.Zone == zone and not item.TutorialOnly then
			return item.Id
		end
	end
	error(`aucun objet en zone {zone}`)
end
local function moveTo(player, position)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
end
local function revealsOf(player)
	return remotes("RevealStarted", function(e)
		return e.args[1] == player
	end)
end
local function rarityOf(entry)
	return Items.ById[entry.Id].Rarity
end
local function inSet(value, list)
	return table.find(list, value) ~= nil
end
-- Réclame un palier ; rend l'objet donné (ou nil) et les RevealStarted envoyés pour ce joueur.
local function claimGift(player, minutes)
	local keys = itemKeys(player)
	local before = #revealsOf(player)
	claimPlay(player, minutes)
	advance(0.2)
	local gifts = giftsSince(player, keys)
	local reveals = revealsOf(player)
	return gifts, { table.unpack(reveals, before + 1) }
end

section("en zone safe : 15 min = la meilleure zone, 60 min = la suivante, scène d'ouverture")
local data = newProfile8()
addItem(data, "z1", itemOfZone(1), nil, 1, 1)
addItem(data, "z3", itemOfZone(3), nil, 3, 2)
addItem(data, "z2", itemOfZone(2), 1, 2, 3) -- exposé : compte aussi pour la zone de référence
local ada = join("Ada", data)
advance(1.5)
check(SafeZoneMod.ContainsPlayer(ada), "Ada est en zone safe (hub du banc)")
addPlay(ada, 900)
local gifts, reveals = claimGift(ada, 15)
local g = gifts[1] and gifts[1].entry
check(#gifts == 1 and g.Zone == 3 and g.Source == "NPC", `15 min : un objet de la zone 3 ({g and g.Id}, zone {g and g.Zone})`)
check(g and inSet(rarityOf(g), { "Common", "Uncommon", "Rare" }), `15 min, zone 3 : rareté {g and rarityOf(g)} parmi Commun, Peu commun, Rare`)
check(dataOf(ada).Rewards.Playtime.Claimed["15"] ~= nil, "palier 15 noté")
check(#reveals == 1, `RevealStarted envoyé ({#reveals})`)
local a = reveals[1] and reveals[1].args
if a then
	check(a[2] == CRATE.ShopId and a[3] == CRATE.SlotName and a[4] == g.Id and a[5] == rarityOf(g), `scène : {a[2]}/{a[3]}, objet {a[4]} ({a[5]})`)
	check(a[6] == (if type(g.Mutation) == "table" and g.Mutation.Effect then g.Mutation.Effect else ""), `mutation montrée « {a[6]} »`)
	local plan = Plan.parse(a[11])
	check(plan ~= nil and #plan.Steps >= 1, `plan lisible ({a[11]})`)
end
check(#notifies(ada, giftText(g)) == 0, "scène lancée : pas de message pour l'objet montré")
advance(40) -- la scène finit (plafond du plan)

addPlay(ada, 2700)
gifts, reveals = claimGift(ada, 60)
g = gifts[1] and gifts[1].entry
check(#gifts == 1 and g.Zone == 4, `60 min : un objet de la zone 4 (zone 3 + 1) ({g and g.Id}, zone {g and g.Zone})`)
check(g and inSet(rarityOf(g), { "Uncommon", "Rare", "Epic" }), `60 min, zone 4 : rareté {g and rarityOf(g)} parmi les 3 meilleures`)
check(#reveals == 1 and reveals[1].args[4] == g.Id and #notifies(ada, giftText(g)) == 0, "60 min : scène d'ouverture, pas de message")
advance(40)

section("hors zone safe : l'objet et le message, pas de scène ; zone 6 plafonnée")
local bobData = newProfile8()
addItem(bobData, "z6", itemOfZone(6), nil, 6, 1)
local bob = join("Bob", bobData)
advance(1.5)
moveTo(bob, Vector3.new(5000, 3, 5000))
advance(0.2)
check(not SafeZoneMod.ContainsPlayer(bob), "Bob hors de la zone safe")
addPlay(bob, 900)
gifts, reveals = claimGift(bob, 15)
g = gifts[1] and gifts[1].entry
check(#gifts == 1 and g.Zone == 6, `15 min : un objet de la zone 6 ({g and g.Id})`)
check(#reveals == 0 and g and #notifies(bob, giftText(g)) == 1, `pas de scène, Notify « {g and giftText(g)} »`)
check(logHas("colis offert sans ouverture (hors zone safe)"), "la sortie dit pourquoi")
addPlay(bob, 2700)
gifts, reveals = claimGift(bob, 60)
g = gifts[1] and gifts[1].entry
check(#gifts == 1 and g.Zone == 6, `60 min depuis la zone 6 : toujours la zone 6 (plafond) ({g and g.Id}, zone {g and g.Zone})`)
check(g and inSet(rarityOf(g), { "Epic", "Legendary", "Mythic" }), `60 min, zone 6 : rareté {g and rarityOf(g)} parmi Épique, Légendaire, Mythique (jamais Secret)`)
check(#reveals == 0 and #notifies(bob, giftText(g)) == 1, "pas de scène, message")

section("GiveZoneBoxItem : 200 dons depuis la zone 6 à 60 min, jamais de Secret")
local carl = join("Carl", newProfile8())
advance(1.5)
local secret, wrong = 0, 0
for n = 1, 200 do
	local uid, why, itemId, gift = UnboxService.GiveZoneBoxItem(carl, sharedModule("Config/Rewards").ZoneBox.NextZone, 6)
	if uid == nil then
		wrong += 1
		print(`    don {n} refusé : {why}`)
		break
	end
	local rarity = Items.ById[itemId].Rarity
	if rarity == "Secret" then
		secret += 1
	end
	if gift.Zone ~= 6 or gift.Rarity ~= rarity or not inSet(rarity, { "Epic", "Legendary", "Mythic" }) or gift.StartRarity ~= "Epic" then
		wrong += 1
	end
	dataOf(carl).Items[uid] = nil -- garde de la place
end
check(secret == 0 and wrong == 0, `200 dons : {secret} Secret, {wrong} incohérent(s) (zone 6, rareté, colis montré Épique)`)

section("inventaire plein : refusé, rien de noté")
local full = newProfile8()
for n = 1, MAX do
	addItem(full, string.format("full-%02d", n), itemOfZone(1), nil, 1, n)
end
local dan = join("Dan", full)
advance(1.5)
addPlay(dan, 3700)
local count0 = 0
for _ in dataOf(dan).Items do
	count0 += 1
end
for _, minutes in { 15, 60 } do
	gifts, reveals = claimGift(dan, minutes)
	check(#gifts == 0 and #reveals == 0 and dataOf(dan).Rewards.Playtime.Claimed[tostring(minutes)] == nil, `{minutes} min : aucun objet, aucune scène, palier pas noté`)
end
check(#notifies(dan, "Your inventory is full") == 2, "Notify « Your inventory is full… » deux fois")
local uid, why = UnboxService.GiveZoneBoxItem(dan, sharedModule("Config/Rewards").ZoneBox.BestZone, 1)
check(uid == nil and why == "InventoryFull", `GiveZoneBoxItem : {why}`)

section("jour 7 et coffre hebdo inchangés")
local R = sharedModule("Config/Rewards")
local d7 = R.Daily[7]
check(d7.Kind == "Box" and d7.Tier == "Luxe" and d7.MinRarity == "Epic" and d7.MinZone == 2 and d7.Rule == nil, "Daily[7] : colis Luxe, Épique ou mieux, zone 2 au moins")
check(R.Weekly.Reward.Kind == "Box" and R.Weekly.Reward.BoxRarity == "Epic" and R.Weekly.Reward.Rule == nil, "Weekly.Reward : objet Épique ou mieux")
local eveData = newProfile8()
eveData.Rewards.Daily = { Streak = 6, LastDay = 9 }
local eve = join("Eve", eveData)
advance(1.5)
local keys = itemKeys(eve)
claimDaily(eve)
advance(0.2)
gifts = giftsSince(eve, keys)
g = gifts[1] and gifts[1].entry
check(#gifts == 1 and g.Zone >= 2 and Rarities.ById[rarityOf(g)].Order >= Rarities.ById.Epic.Order, `J7 : {g and g.Id} ({g and rarityOf(g)}), zone {g and g.Zone}`)
check(#revealsOf(eve) == 0 and #notifies(eve, giftText(g)) == 1, "J7 : pas de scène, le message comme avant")
check(logCount("[RewardService]", "WARN") == 0 and logCount("[UnboxService]", "WARN") == 0, "aucun avertissement de RewardService ni d'UnboxService")
summary("scénario a309flow")
