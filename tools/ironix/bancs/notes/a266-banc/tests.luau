--!nocheck
-- Banc a266 : quêtes quotidiennes (QuestService, QuestController) et roue de la fortune (WheelService, WheelController).
-- 2e commit : les lots « colis » sont des colis d'une rareté de la zone (Rank 1, 2 ou "Top" de Rarities.ZoneRarities).
local RarityCfg = sharedModule("Config/Rarities")
local ItemCfg = sharedModule("Config/Items")
local function giftRank(gift, rank)
	local entry = gift and gift.entry
	local list = entry and RarityCfg.ZoneRarities[entry.Zone]
	if list == nil then
		return false, "?", "?"
	end
	local want = list[if rank == "Top" then #list else math.min(rank, #list)]
	local def = ItemCfg.ById[entry.Id]
	local got = def and RarityCfg.ById[def.Rarity]
	return got ~= nil and got.Order >= RarityCfg.ById[want].Order, if def then def.Rarity else "?", `{want} (zone {entry.Zone})`
end
advance(1000)
startServer()
questTest("days 10") -- jour UTC 10 (horloge du banc partie de 0)
wheelTest("days 10")
local ada = join("Ada", newProfile8(), 71)
advance(1.5)
local bob = join("Bob", newProfile8(), 72)
advance(1.5)

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(not logHas("Quests illisible", "WARN") and not logHas("Wheel illisible", "WARN"), "profil neuf : pas d'avertissement")
local ids, seen, distinct = {}, {}, true
for slot = 1, 3 do
	local id = ada:GetAttribute(`Quest{slot}`)
	ids[slot] = id
	if id == nil or seen[id] or Quests.ById[id] == nil then
		distinct = false
	end
	if id then
		seen[id] = true
	end
end
check(distinct, `3 quêtes différentes tirées : {tostring(ids[1])}, {tostring(ids[2])}, {tostring(ids[3])}`)
check(ada:GetAttribute("Quest1Progress") == 0 and ada:GetAttribute("Quest1Claimed") == false and (ada:GetAttribute("Quest1Goal") or 0) >= 1, "place 1 : 0 / objectif, pas réclamée")
local endsAt = ada:GetAttribute("QuestsEndsAt")
local left = 86400 - (math.floor(now()) % 86400)
check(type(endsAt) == "number" and near(endsAt - serverTime(), left, 2), `QuestsEndsAt = prochain minuit UTC ({endsAt and endsAt - serverTime()} contre {left})`)
check(dataOf(ada).Quests and dataOf(ada).Quests.Day == 10, "profil : Quests.Day = jour UTC")
check(ada:GetAttribute("WheelFreeReady") == true and ada:GetAttribute("WheelExtraSpins") == 0, "roue : tour gratuit prêt, 0 tour en plus")
check(near((ada:GetAttribute("WheelNextFreeAt") or 0) - serverTime(), left, 2), "WheelNextFreeAt = prochain minuit UTC")
do
	local total = 0
	for _, s in Wheel.Sectors do
		total += s.Weight
	end
	check(#Wheel.Sectors == 8 and total == 100, `8 secteurs, poids total 100 ({total})`)
	-- Le tirage est-il bien pondéré ? (10 000 tirages)
	local counts = {}
	local rng = Random.new(5)
	for _ = 1, 10000 do
		local i = WheelService.Draw(rng)
		counts[i] = (counts[i] or 0) + 1
	end
	check(near((counts[1] or 0) / 100, 30, 2.5) and near((counts[8] or 0) / 100, 3, 1), `tirage pondéré : secteur 1 {counts[1]} / 10000, secteur 8 {counts[8]}`)
end

section("progression : braquage, colis, vitrine")
setQuests(ada, { "Heist", "OpenBoxes", "BreakWindow" })
fireList(STOWED, ada, "u1", "Z1_Brocoli")
fireList(STOWED, ada, "u2", "Z1_Brocoli")
check(entryOf(ada, "Heist").Progress == 2, "2 objets rangés : 2/3 braquages")
local payload = { Kind = "NPCItem", StoreId = "STORE_Z1_Test", ItemId = "Z1_Brocoli" }
CarryService.Give(ada, payload); flush()
CarryService.Give(ada, payload); flush() -- même objet repris au sol
CarryService.Give(ada, { Kind = "PlayerItem", ItemId = "Z1_Brocoli" }); flush()
check(entryOf(ada, "OpenBoxes").Progress == 1, `colis : le même objet repris compte une fois, un objet de joueur ne compte pas ({entryOf(ada, "OpenBoxes").Progress})`)
local rain = sharedModule("Config/ItemRain").StoreId
CarryService.Give(ada, { Kind = "NPCItem", StoreId = rain, ItemId = "Z1_Brocoli" }); flush()
check(entryOf(ada, "OpenBoxes").Progress == 1, "objet de la pluie d'objets : pas un colis")
fireList(STOWED, ada, "u3", "Z1_Brocoli")
check(entryOf(ada, "Heist").Progress == 2, "objet de la pluie rangé : pas un braquage")
fireList(BROKEN, { Kind = "NPC", Breaker = ada })
fireList(BROKEN, { Kind = "Plot", Breaker = ada })
fireList(BROKEN, { Kind = "Event", Breaker = ada })
fireList(BROKEN, { Kind = "NPC", Breaker = bob })
check(entryOf(ada, "BreakWindow").Progress == 1, "vitrine : seule une vitrine de magasin PNJ cassée par Ada compte")
CarryService.Give(ada, { Kind = "NPCItem", StoreId = "STORE_Z1_Test", ItemId = "Z1_Brocoli" }); flush()
fireList(STOWED, ada, "u4", "Z1_Brocoli")
check(entryOf(ada, "Heist").Progress == 3, "3e objet de magasin rangé : 3/3")
check(#notifies(ada, Quests.Messages.Complete) == 1, "Notify « quête finie » une fois")
advance(1.1)
local _, heistSlot = entryOf(ada, "Heist")
check(ada:GetAttribute(`Quest{heistSlot}Progress`) == 3 and ada:GetAttribute(`Quest{heistSlot}Goal`) == 3, "attributs à jour (3/3)")
fireList(STOWED, ada, "u5", "Z1_Brocoli")
check(entryOf(ada, "Heist").Progress == 3, "plafonné à l'objectif")

section("réclamer")
local _, boxSlot = entryOf(ada, "OpenBoxes")
local before = #notifies(ada)
claimQuest(ada, boxSlot)
check(#notifies(ada, Quests.Messages.NotDone) == 1 and entryOf(ada, "OpenBoxes").Claimed == 0, "quête pas finie : refus, rien noté")
local cash = dataOf(ada).Cash
claimQuest(ada, heistSlot)
local expected = 10 * sharedModule("Config/Rewards").MinCashPerMinute
check(dataOf(ada).Cash == cash + expected, `Heist : +{expected} $ (10 min, revenu nul : minimum) ({dataOf(ada).Cash - cash})`)
check(entryOf(ada, "Heist").Claimed > 0 and ada:GetAttribute(`Quest{heistSlot}Claimed`) == true, "notée réclamée")
local tq = telemetryOf(ada, "QuestReward")
check(#tq == 1 and tq[1].amount == expected and tq[1].sku == "Quest_Heist", "télémétrie QuestReward, SKU Quest_Heist")
local ev = eventsOf(ada, "QuestClaim")
check(#ev == 1 and ev[1].fields[1] == "Quest - Heist" and ev[1].fields[2] == "Gift - Cash", "événement QuestClaim (Quest, Gift)")
claimQuest(ada, heistSlot)
check(dataOf(ada).Cash == cash + expected and #telemetryOf(ada, "QuestReward") == 1, "2e réclamation : rien")
-- Lot refusé : inventaire plein (GiveItem renvoie InventoryFull) : la quête reste à réclamer.
local e2 = entryOf(ada, "OpenBoxes")
e2.Progress = e2.Goal
local giveItem = UnboxService.GiveItem
UnboxService.GiveItem = function()
	return nil, "InventoryFull"
end
claimQuest(ada, boxSlot)
check(e2.Claimed == 0 and #notifies(ada, "inventory is full") == 1, "inventaire plein : refus propre, pas noté")
UnboxService.GiveItem = giveItem
local keys = itemKeys(ada)
claimQuest(ada, boxSlot)
local openGifts = giftsSince(ada, keys)
check(e2.Claimed > 0 and #giftsSince(ada, keys) == 1, "inventaire libéré : objet donné, notée")
local okRank, got, want = giftRank(openGifts[1], 2)
check(okRank, `OpenBoxes : colis de la 2e rareté de la zone ou mieux ({got}, attendu {want})`)
-- Vitrine : potion Money.
local e3, windowSlot = entryOf(ada, "BreakWindow")
fireList(BROKEN, { Kind = "NPC", Breaker = ada })
fireList(BROKEN, { Kind = "NPC", Breaker = ada })
check(e3.Progress == 3, "vitrines : 3/3")
claimQuest(ada, windowSlot)
check(#POTIONS == 1 and POTIONS[1].id == "Money" and POTIONS[1].count == 1 and e3.Claimed > 0, "BreakWindow : +1 potion Money")
-- Remote : places hors bornes ou mal formées refusées par Net.
local n0 = #notifies(ada)
for _, bad in { 0, 4, 1.5, "1", -1 } do
	claimQuest(ada, bad)
end
check(#notifies(ada) == n0, "ClaimQuest(0, 4, 1.5, « 1 », -1) : ignoré, aucune réponse")
local function noBadWarn()
	return not logHas("[QuestService]", "WARN")
end
check(noBadWarn(), "aucun avertissement de QuestService")

section("progression : argent, tapis, vol")
setQuests(ada, { "EarnCash", "Treadmill", "StealPlayer" }, { 1000, 5, 1 })
DataService.AddCash(ada, 600); flush()
DataService.SpendCash(ada, 300); flush()
check(entryOf(ada, "EarnCash").Progress == 600, `argent gagné : +600, une dépense ne retire rien ({entryOf(ada, "EarnCash").Progress})`)
DataService.AddCash(ada, 600); flush()
check(entryOf(ada, "EarnCash").Progress == 1000, "plafonné à 1000")
TRAINING[ada] = true
advance(3.2)
check(entryOf(ada, "Treadmill").Progress >= 2 and entryOf(ada, "Treadmill").Progress < 5, `tapis : secondes comptées ({entryOf(ada, "Treadmill").Progress})`)
advance(3)
TRAINING[ada] = nil
check(entryOf(ada, "Treadmill").Progress == 5, "tapis : 5 s, fini")
fireList(PVP_ENDED, ada, bob, "Z1_Brocoli", "Returned", "Caught")
check(entryOf(ada, "StealPlayer").Progress == 0, "vol rendu : ne compte pas")
fireList(BOT_THEFT, ada, "Z1_Brocoli", "Started")
check(entryOf(ada, "StealPlayer").Progress == 0, "vol de bot commencé : ne compte pas")
fireList(PVP_ENDED, ada, bob, "Z1_Brocoli", "Stolen", "Stowed")
check(entryOf(ada, "StealPlayer").Progress == 1, "vol réussi sur un joueur : 1/1")
-- Lot argent : pas compté dans « gagner de l'argent ».
setQuests(ada, { "Treadmill", "EarnCash" }, { 1, 10000 })
entryOf(ada, "Treadmill").Progress = 1
claimQuest(ada, 1)
check(entryOf(ada, "Treadmill").Claimed > 0 and entryOf(ada, "EarnCash").Progress == 0, "lot d'argent d'une quête : pas compté dans EarnCash")
-- Vol par un bot.
setQuests(bob, { "StealPlayer" })
fireList(BOT_THEFT, bob, "Z1_Brocoli", "Stolen")
check(entryOf(bob, "StealPlayer").Progress == 1, "vol réussi sur un bot : compté")
-- Boost (EarnCash) et colis de la plus haute rareté de la zone (StealPlayer).
setQuests(ada, { "EarnCash", "StealPlayer" }, { 1, 1 })
entryOf(ada, "EarnCash").Progress = 1
entryOf(ada, "StealPlayer").Progress = 1
claimQuest(ada, 1)
check(near((ada:GetAttribute("CashBoostEndsAt") or 0) - serverTime(), 600, 2), "EarnCash : boost ×2 de 10 min")
keys = itemKeys(ada)
claimQuest(ada, 2)
local gifts = giftsSince(ada, keys)
check(#gifts == 1, "StealPlayer : un objet donné")
okRank, got, want = giftRank(gifts[1], "Top")
check(okRank, `StealPlayer : colis de la plus haute rareté de la zone ({got}, attendu {want})`)

section("minuit UTC : nouveau tirage")
setQuests(ada, { "Heist", "OpenBoxes", "BreakWindow" })
entryOf(ada, "Heist").Progress = 2
left = 86400 - (math.floor(now()) % 86400)
advance(left - 5, 1)
check(dataOf(ada).Quests.Day == 10 and entryOf(ada, "Heist") and entryOf(ada, "Heist").Progress == 2, "5 s avant minuit : mêmes quêtes")
advance(7, 0.5)
local q = dataOf(ada).Quests
local fresh = q.Day == 11 and #q.List == 3
for _, entry in q.List do
	if entry.Progress ~= 0 or entry.Claimed ~= 0 then
		fresh = false
	end
end
check(fresh, `après minuit : jour 11, 3 nouvelles quêtes à 0 (jour {q.Day})`)
check(near((ada:GetAttribute("QuestsEndsAt") or 0) - serverTime(), 86400 - 2, 3), "QuestsEndsAt repoussé d'un jour")
-- Profil abîmé : réparé sans erreur.
dataOf(bob).Quests = { Day = dataOf(bob).Quests.Day, List = { { Id = "Nope", Progress = 1, Goal = 1, Claimed = 0 }, "x" } }
advance(1.1)
check(#dataOf(bob).Quests.List == 0 and bob:GetAttribute("Quest1") == nil, "entrée inconnue ou abîmée retirée")
dataOf(bob).Quests = "abîmé"
advance(1.1)
check(type(dataOf(bob).Quests) == "table" and #dataOf(bob).Quests.List == 3, "Quests illisible : nouveau tirage")

section("roue : tour gratuit")
-- Roue sur le même jour que les quêtes (l'horloge de la roue a son propre décalage : elle a aussi passé minuit).
check(ada:GetAttribute("WheelFreeReady") == true, "tour gratuit prêt")
wheelTest("force 2") -- colis de la plus basse rareté de la zone
keys = itemKeys(ada)
spin(ada)
local wr = wheelResults(ada)
check(#wr == 1 and wr[1].args[1] == 2 and type(wr[1].args[2]) == "string" and string.find(wr[1].args[2], "Item", 1, true), `WheelResult(2, « {wr[1] and wr[1].args[2]} »)`)
local wheelGifts = giftsSince(ada, keys)
check(#giftsSince(ada, keys) == 1, "objet donné avant l'animation")
okRank, got, want = giftRank(wheelGifts[1], 1)
check(okRank and Wheel.Sectors[2].Icon == "WHEEL_Box" and Wheel.Sectors[6].Icon == "WHEEL_BoxRare" and Wheel.Sectors[6].Prize.Rank == 2, `roue : colis de la plus basse rareté ({got}, attendu {want}), icônes WHEEL_Box et WHEEL_BoxRare`)
check(ada:GetAttribute("WheelFreeReady") == false and dataOf(ada).Wheel.FreeDay == 11, "tour gratuit pris (FreeDay = 11)")
local ws = eventsOf(ada, "WheelSpin")
check(#ws == 1 and ws[1].fields[1] == "Sector - 2" and ws[1].fields[2] == "Gift - Box" and ws[1].fields[3] == "Spin - Free", "événement WheelSpin (Sector, Gift, Spin)")
spin(ada)
check(#wheelResults(ada) == 1 and #notifies(ada, Wheel.Messages.NoSpin) == 1, "2e tour : refusé (NoSpin), pas de WheelResult")
fireAs(ada, "SpinWheel", 3, "x"); flush()
check(#wheelResults(ada) == 1, "SpinWheel avec arguments : rien")

section("roue : tours en plus, lot d'argent, repli")
check(WheelService.AddSpins(ada, 3) and ada:GetAttribute("WheelExtraSpins") == 3, "AddSpins(3) : 3 tours en plus")
wheelTest("force 8")
cash = dataOf(ada).Cash
spin(ada)
local jackpot = 60 * sharedModule("Config/Rewards").MinCashPerMinute
check(dataOf(ada).Cash == cash + jackpot and ada:GetAttribute("WheelExtraSpins") == 2, `secteur 8 : +{jackpot} $, 2 tours en plus restants`)
local tw = telemetryOf(ada, "WheelReward")
check(#tw == 1 and tw[1].amount == jackpot and tw[1].sku == "Wheel_8", "télémétrie WheelReward, SKU Wheel_8")
check(eventsOf(ada, "WheelSpin")[2].fields[3] == "Spin - Extra", "tour en plus noté Extra")
POTION_FULL = true
wheelTest("force 4")
cash = dataOf(ada).Cash
spin(ada)
wr = wheelResults(ada)
local fallbackCash = 5 * sharedModule("Config/Rewards").MinCashPerMinute
check(wr[#wr].args[1] == 4 and string.find(wr[#wr].args[2], "Prize unavailable", 1, true) == 1 and dataOf(ada).Cash == cash + fallbackCash, `potion pleine : repli +{fallbackCash} $ (« {wr[#wr].args[2]} »)`)
check(ada:GetAttribute("WheelExtraSpins") == 1, "tour pris")
-- Repli refusé aussi (argent impossible) : le tour n'est pas pris.
local addCash = DataService.AddCash
DataService.AddCash = function()
	return nil
end
wheelTest("force 7")
local nres = #wheelResults(ada)
spin(ada)
DataService.AddCash = addCash
POTION_FULL = false
check(#wheelResults(ada) == nres and ada:GetAttribute("WheelExtraSpins") == 1, "lot et repli refusés : tour pas pris, pas de WheelResult")
check(not logHas("[WheelService]", "WARN"), "aucun avertissement de WheelService")

section("roue : jour suivant")
wheelTest("days 1")
advance(1.1)
check(ada:GetAttribute("WheelFreeReady") == true and ada:GetAttribute("WheelExtraSpins") == 1, "jour suivant : tour gratuit rendu, tours en plus gardés")
dataOf(bob).Wheel = { FreeDay = "x", Extra = -4 }
advance(1.1)
check(bob:GetAttribute("WheelFreeReady") == true and bob:GetAttribute("WheelExtraSpins") == 0, "Wheel abîmé : réparé")

section("client : quêtes")
buildUi(ada)
buildQuestUi(ada)
startClient(ada)
advance(0.5)
setQuests(ada, { "Heist", "EarnCash", "Treadmill" }, { 3, 12500, 180 })
entryOf(ada, "Heist").Progress = 3
entryOf(ada, "Treadmill").Progress = 90
advance(1.1)
local QC = clientModule("QuestController")
check(not logHas("[Loader", "WARN"), "client : aucun module en échec")
check(not QUI.quests.Enabled and not QUI.template.Visible, "UI_Quests fermé, Template caché")
check(QUI.questAlerts[1].Visible and QUI.questAlerts[2].Visible, "QuestsAlert allumée (LeftRail et LeftRailTouch) : une quête à réclamer")
click(QUI.questButtons[2])
advance(0.3)
check(QUI.quests.Enabled and QC.GetState().Open, "QuestsButton (LeftRailTouch) : écran ouvert")
local r1, r2, r3 = questRow(1), questRow(2), questRow(3)
check(r1 and r2 and r3 and QUI.list:FindFirstChild("Quest_4") == nil, "3 lignes Quest_1 à Quest_3")
check(r1.frame.Visible and r1.name.Text == "Rob 3 stores" and r1.progress.Text == "3/3" and r1.reward.Text == "10 min cash", `ligne 1 : « {r1.name.Text} » {r1.progress.Text} « {r1.reward.Text} »`)
check(near(r1.fill.Size.X.Scale, 1) and near(r3.fill.Size.X.Scale, 0.5) and near(r1.fill.Size.Y.Scale, 1), "Bar.Fill : 100 %, 50 %, hauteur gardée")
check(string.find(r2.name.Text, "Earn ", 1, true) == 1 and r2.progress.Text ~= "", `ligne 2 : « {r2.name.Text} » {r2.progress.Text}`)
check(r3.name.Text == "Run 3:00 on the treadmill" and r3.progress.Text == "1:30/3:00", `ligne 3 : « {r3.name.Text} » {r3.progress.Text}`)
check(r1.icon.Image == "rbxassetid://700", "pas d'ICON_QUEST_Heist livré : icône du Template")
check(r1.claimButton.Visible and not r2.claimButton.Visible and not r1.claimed.Visible, "ClaimButton seulement sur la quête finie")
check(string.find(QUI.questTimer.Text, "New quests in ", 1, true) == 1, `Timer « {QUI.questTimer.Text} »`)
cash = dataOf(ada).Cash
local calls = #serverCalls("ClaimQuest")
click(r1.claimButton)
advance(0.6)
check(#serverCalls("ClaimQuest") == calls + 1 and dataOf(ada).Cash > cash, "ClaimButton : ClaimQuest(1), argent donné")
check(not r1.claimButton.Visible and r1.claimed.Visible and r1.claimLabel.Text == "DONE", "réclamée : Claimed visible, « DONE »")
check(not QUI.questAlerts[1].Visible, "QuestsAlert éteinte")
click(QUI.questClose)
advance(0.3)
check(not QC.GetState().Open, "CloseButton : fermé")

section("client : roue")
local WC = clientModule("WheelController")
check(not QUI.wheelGui.Enabled, "UI_Wheel fermé")
check(QUI.segments[1]:FindFirstChild("Amount").Text == "5 MIN CASH" and QUI.segments[8]:FindFirstChild("Amount").Text == "60 MIN CASH", "Amount des segments : lots de Config")
check(QUI.segments[1]:FindFirstChild("Chance").Text == "30%" and QUI.segments[4]:FindFirstChild("Chance").Text == "5%", "Chance : 30 %, 5 %")
check(QUI.segments[1]:FindFirstChild("Icon").Image == "rbxassetid://800", "pas d'ICON_WHEEL_* livré : icône de Clément gardée")
check(QUI.price.Text == "Soon", "BuySpinButton.PriceLabel : « Soon » (ProductId = 0)")
check(QUI.wheelAlerts[1].Visible and QUI.wheelAlerts[2].Visible, "WheelAlert allumée : tour gratuit prêt")
check(not QUI.result.Visible, "Result caché")
click(QUI.wheelButtons[1])
advance(0.3)
check(QUI.wheelGui.Enabled and WC.GetState().Open and not QC.GetState().Open, "WheelButton : roue ouverte")
check(QUI.spinLabel.Text == "SPIN!", "SpinLabel : texte de Clément quand un tour attend")
wheelTest("force 5")
calls = #serverCalls("SpinWheel")
click(QUI.spinButton)
advance(0.3)
local st = WC.GetState()
check(#serverCalls("SpinWheel") == calls + 1 and st.LastSector == 5, `SpinButton : SpinWheel, secteur 5 reçu ({st.LastSector})`)
-- Secteur 5 (Segment_05, angle -90 + 4 × 45 = 90) sous Pointer (en haut, -90) : rotation ≡ 180 (± jitter).
local rot = st.Rotation or 0
local offset = ((rot - 180) + 180) % 360 - 180
check(rot >= Wheel.Turns * 360 and math.abs(offset) <= Wheel.Jitter * 22.5 + 0.01, `rotation {rot} : {Wheel.Turns} tours, secteur 5 en haut (écart {offset})`)
check(QUI.result.Visible and string.find(QUI.result.Text, "cash", 1, true) ~= nil, `Result : « {QUI.result.Text} »`)
check(not QUI.wheelAlerts[1].Visible, "WheelAlert éteinte : plus de tour gratuit")
check(ada:GetAttribute("WheelExtraSpins") == 1, "tour gratuit pris d'abord, le tour en plus reste")
advance(Wheel.ResultSeconds + 0.3)
check(not QUI.result.Visible, "Result caché après ResultSeconds")
dataOf(ada).Wheel.Extra = 0
advance(1.1)
advance(0.3)
check(string.match(QUI.spinLabel.Text, "^%d+:%d%d:%d%d$") ~= nil, `SpinLabel : temps avant minuit (« {QUI.spinLabel.Text} »)`)
check(string.find(QUI.wheelTimer.Text, "Next spin in ", 1, true) == 1, `Timer « {QUI.wheelTimer.Text} »`)
calls = #serverCalls("SpinWheel")
click(QUI.spinButton)
check(#serverCalls("SpinWheel") == calls, "pas de tour : SpinButton n'envoie rien")
click(QUI.wheelClose)
advance(0.3)
check(not WC.GetState().Open, "CloseButton : roue fermée")
WC.Open()
advance(0.3)
check(WC.GetState().Open, "WheelController.Open() (zone WheelZone du hub) : ouverte")

summary("scénario quêtes et roue")
