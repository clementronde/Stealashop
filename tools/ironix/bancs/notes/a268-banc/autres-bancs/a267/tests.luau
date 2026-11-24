--!nocheck
-- Scénario a267 (vague 80) : coffre hebdomadaire allumé par Features.WeeklyChest (sans attribut de test), pastille
-- seulement si l'écran a WeeklyClaimButton, objet du coffre tiré comme un colis Épique de rayon
-- (UnboxService.GiveBoxRarityItem), pièges allumés (tuile Traps achetable).
advance(1000)
startServer()
days(10)
local Unbox = serverModule("UnboxService")
local Features = sharedModule("Config/Features")
local SkillTree = sharedModule("Config/SkillTree")

section("interrupteurs")
check(Features.WeeklyChest == true and Features.Traps == true, "Features.WeeklyChest et Features.Traps à true")
check(SkillTree.ById.Traps.Coded == 4, "tuile Traps achetable (Coded 4)")
check(Rewards.Weekly.Reward.BoxRarity == "Epic" and Rewards.Weekly.Reward.Tier == nil, "coffre : colis Épique, plus de type Luxe")
check(Workspace:GetAttribute("WeeklyChestTest") == nil, "aucun attribut de test")

-- Aller au lundi suivant.
local day = RewardService.GetDay()
local toMonday = (7 - (day + 3) % 7) % 7
if toMonday == 0 then toMonday = 7 end
days(toMonday)

section("sans WeeklyChest")
local ada = join("Ada", newProfile8(), 71)
advance(1.5)
buildUi(ada) -- UI_Rewards sans WeeklyChest (Clément ne l'a pas encore livré)
startClient(ada)
advance(0.5)
local Controller = clientModule("RewardsController")
check(ada:GetAttribute("RewardWeeklyDays") == 1 and ada:GetAttribute("RewardWeeklyClaimed") == false, `allumé sans attribut de test : lundi compté ({ada:GetAttribute("RewardWeeklyDays")})`)
claimDaily(ada)
for _ = 1, 4 do
	days(1)
	claimDaily(ada)
end
check(ada:GetAttribute("RewardWeeklyDays") == 5, `vendredi : 5 jours ({ada:GetAttribute("RewardWeeklyDays")})`)
check(Controller.GetState().WeeklyReady == true, "client : coffre prêt")
check(not UI.alert.Visible and Controller.GetState().Pending == false, "pas de WeeklyClaimButton : aucune pastille")

section("colis Épique")
local keys = itemKeys(ada)
fireAs(ada, "ClaimWeekly")
flush()
local gifts = giftsSince(ada, keys)
check(#gifts == 1, `ClaimWeekly (remote) : un objet donné ({#gifts})`)
local entry = gifts[1] and gifts[1].entry
local def = entry and Items.ById[entry.Id]
check(entry and entry.Zone >= 4, `zone 4 au moins, première zone des Épiques ({entry and entry.Zone})`)
check(def and Rarities.Allows(entry.Zone, def.Rarity), `rareté de la zone ({def and def.Rarity})`)
check(entry and #notifies(ada, giftText(entry)) == 1, "Notify de l'objet")
check(ada:GetAttribute("RewardWeeklyClaimed") == true, "réclamé")

-- Tirage : 600 colis Épiques en zone 4 puis en zone 6 (l'objet retiré après chaque don, inventaire jamais plein).
local function draw(zone, n)
	local counts, zones, total = {}, {}, 0
	for _ = 1, n do
		local uid, reason, itemId = Unbox.GiveBoxRarityItem(ada, "Epic", zone)
		if uid then
			local got = dataOf(ada).Items[uid]
			local rarity = Items.ById[itemId].Rarity
			counts[rarity] = (counts[rarity] or 0) + 1
			zones[got.Zone] = true
			total += 1
			dataOf(ada).Items[uid] = nil
		else
			counts["refus:" .. tostring(reason)] = (counts["refus:" .. tostring(reason)] or 0) + 1
		end
	end
	return counts, zones, total
end
local c4, z4, t4 = draw(1, 600)
check(t4 == 600 and z4[4] and countKeys(z4) == 1, `zone 1 demandée : portée à 4 (600 dons : {t4})`)
local epic4 = (c4.Epic or 0) / 600
check(epic4 == 1, `zone 4 : que des Épiques (plancher, rien au-dessus dans la zone) ({math.floor(epic4 * 100)} %)`)
check((c4.Legendary or 0) == 0 and (c4.Mythic or 0) == 0 and (c4.Secret or 0) == 0, "zone 4 : rien au-dessus d'Épique")
check((c4.Rare or 0) + (c4.Common or 0) + (c4.Uncommon or 0) == 0, "a268 : zone 4, jamais sous Épique (plancher)")
local c6, z6, t6 = draw(6, 600)
local epic6 = (c6.Epic or 0) / 600
check(t6 == 600 and z6[6] and countKeys(z6) == 1, "zone 6 : objets de la zone 6")
check(epic6 > 0.95 and (c6.Rare or 0) == 0, `a268 : zone 6, Épique ou mieux, jamais Rare ({math.floor(epic6 * 100)} % d'Épiques, {c6.Rare or 0} Rare)`)
check((c6.Common or 0) == 0 and (c6.Uncommon or 0) == 0, "zone 6 : ni Commun ni Peu commun (absents de la zone)")
check((c6.Legendary or 0) < 20, `zone 6 : Légendaire rare (× 0,05 par cran : {c6.Legendary or 0} sur 600)`)

section("refus")
local uid, reason = Unbox.GiveBoxRarityItem(ada, "Banana", 4)
check(uid == nil and reason == "Invalid", "rareté inconnue : Invalid")
uid, reason = Unbox.GiveBoxRarityItem(ada, "Divine", 6)
check(uid == nil and reason == "Invalid", "Divine (aucune zone) : Invalid")
uid, reason = Unbox.GiveBoxRarityItem(ada, "Epic", 9)
check(uid == nil and reason == "Invalid", "zone inconnue : Invalid")

-- Avec WeeklyChest et WeeklyClaimButton (pastille, bouton, CLAIMED) : copie du banc a166 (a267-banc/autres-bancs/a166),
-- un seul client par passe dans ce harnais.
summary("scénario a267")
