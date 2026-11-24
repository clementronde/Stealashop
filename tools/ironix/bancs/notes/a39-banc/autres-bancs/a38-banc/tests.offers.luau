--!nocheck
-- Scénario « offers » : les produits à effet.
--   Pack de départ : proposé la 1re heure de jeu seulement (attribut StarterPackEndsAt), donne
--   50 000 $ (télémétrie « Robux »), le Marteau (équipé s'il est plus fort), un boost ×2 argent d'1 h
--   compté seulement en jeu (gardé au départ, repris au retour, prolongé par un 2e boost, fini à
--   l'heure) ; l'offre disparaît ; racheté quand même : redonné, avec un avertissement.
--   Ouvrir maintenant : paliers de prix (Monetization.OpenNowTier), le reçu termine ou raccourcit
--   l'attente du colis qui attend le plus (BoxReady), sans colis : crédit retiré des prochains colis.
--   Packs d'argent : revenus du HUD, bonus compris.

startServer()

local function itemOf(rarity)
	for zone = 1, 6 do
		local list = Items.ByZone[zone] and Items.ByZone[zone][rarity]
		for _, item in list or {} do
			if item.Id ~= Tutorial.GuaranteedItemId then
				return item.Id, zone
			end
		end
	end
	error("pas d'objet " .. rarity)
end

section("pack de départ : la 1re heure seulement")
local new = newProfile()
new.Lifetime.PlaySeconds = 0
addItem(new, "n-1", "Z3_Smartphone", 1, 3)
local ada = join("Ada", new)
local almost = newProfile()
almost.Lifetime.PlaySeconds = 3590
local bob = join("Bob", almost)
local veteran = join("Cid", newProfile()) -- 2 h de jeu
local bought = newProfile()
bought.Lifetime.PlaySeconds = 0
bought.Monetization.StarterPack = true
local dan = join("Dan", bought)
advance(1.5)
local endsAt = ada:GetAttribute("StarterPackEndsAt")
check(type(endsAt) == "number" and endsAt - serverTime() > 3595 and endsAt - serverTime() < 3600, `nouveau joueur : offre jusqu'à dans {endsAt and string.format("%.0f", endsAt - serverTime())} s`)
check(type(bob:GetAttribute("StarterPackEndsAt")) == "number", "3 590 s de jeu : encore proposée")
check(veteran:GetAttribute("StarterPackEndsAt") == nil, "2 h de jeu : pas proposée")
check(dan:GetAttribute("StarterPackEndsAt") == nil, "déjà achetée : pas proposée")
advance(12)
check(bob:GetAttribute("StarterPackEndsAt") == nil, "Bob passe la 1re heure : l'offre disparaît")
leave(bob) -- libère des boutiques pour les joueurs suivants (6 boutiques)
leave(dan)

section("pack de départ : achat")
local cash0 = cashOf(ada)
local income0 = ada:GetAttribute("Income")
check(dataOf(ada).Tools.Equipped == "Fists", "Ada a ses poings en main")
local r = receipt(ada, PRODUCT_IDS.StarterPack, "SP-1")
check(settle(r) == GRANTED, "PurchaseGranted")
check(cashOf(ada) == cash0 + 50000, "+50 000 $")
check(table.find(dataOf(ada).Tools.Owned, "Hammer") ~= nil and dataOf(ada).Tools.Equipped == "Hammer", "Marteau donné et équipé (plus fort que les poings)")
check(ada:GetAttribute("EquippedTool") == "Hammer" and string.find(ada:GetAttribute("OwnedTools") or "", "Hammer", 1, true) ~= nil, "attributs de la boutique d'armes à jour (ShopService.RefreshPlayer)")
check(dataOf(ada).Monetization.StarterPack == true and ada:GetAttribute("StarterPackEndsAt") == nil, "offre prise : elle disparaît")
local boostEnds = ada:GetAttribute("CashBoostEndsAt")
check(type(boostEnds) == "number" and near(boostEnds - serverTime(), 3600, 0.5), "boost ×2 argent d'1 h")
advance(1.1)
check(ada:GetAttribute("Income") == 2 * income0, "revenus doublés pendant le boost")
local starterTelemetry = nil
for _, e in TELEMETRY do
	if e.player == ada and e.sku == "StarterPack" then
		starterTelemetry = e
	end
end
check(starterTelemetry ~= nil and starterTelemetry.kind == "Robux" and starterTelemetry.amount == 50000, "télémétrie : 50 000 $ en « Robux », SKU StarterPack")
check(#notifies(ada, "Starter Pack: +$50K, a Hammer and ×2 Cash for 1 hour!") == 1, "Notify")

section("pack de départ : outil plus fort déjà équipé")
local strong = newProfile()
strong.Lifetime.PlaySeconds = 0
strong.Tools = { Owned = { "Fists", "Sledgehammer" }, Equipped = "Sledgehammer" }
local eve = join("Eve", strong)
advance(1)
check(settle(receipt(eve, PRODUCT_IDS.StarterPack, "SP-E")) == GRANTED, "PurchaseGranted")
check(table.find(dataOf(eve).Tools.Owned, "Hammer") ~= nil and dataOf(eve).Tools.Equipped == "Sledgehammer", "Marteau donné, la Masse reste équipée")

section("Ouvrir maintenant : paliers")
local function tierPrice(remaining)
	local tier = Monetization.OpenNowTier(remaining)
	return if tier then tier.Price else nil
end
check(tierPrice(5) == nil and tierPrice(10) == nil, "10 s ou moins : pas proposé")
check(tierPrice(11) == 19 and tierPrice(60) == 19, "jusqu'à 1 min : 19")
check(tierPrice(61) == 39 and tierPrice(180) == 39, "jusqu'à 3 min : 39")
check(tierPrice(181) == 59 and tierPrice(480) == 59, "jusqu'à 8 min : 59")
check(tierPrice(481) == 99 and tierPrice(900) == 99 and tierPrice(5000) == 99, "au-delà : 99")

section("Ouvrir maintenant : le colis qui attend le plus")
local epic, epicZone = itemOf("Epic")
local mythic, mythicZone = itemOf("Mythic")
local b1 = placeBox(veteran, 1, "Epic", epic, "Premium", epicZone)
local b2 = placeBox(veteran, 2, "Mythic", mythic, "Luxe", mythicZone)
advance(1.1)
check(veteran:GetAttribute("OpenNowReadyAt") == b2.ReadyAt, "OpenNowReadyAt = heure du colis qui attend le plus (Mythique)")
table.clear(REMOTE_LOG)
check(settle(receipt(veteran, TIER_IDS[1], "ON-1")) == GRANTED, "palier à 19 (1 min) : PurchaseGranted")
local left2 = dataOf(veteran).Boxes["2"].ReadyAt - serverTime()
check(near(left2, Rarities.ById.Mythic.OpenDelay - 60 - 1.2, 1), `Mythique raccourci d'1 min seulement (reste {string.format("%.0f", left2)} s)`)
check(near(dataOf(veteran).Boxes["1"].ReadyAt, b1.ReadyAt, 1e-6), "l'Épique n'est pas touché")
check(#notifies(veteran, "Your box wait is 1:00 shorter!") == 1, "Notify")
check(settle(receipt(veteran, TIER_IDS[4], "ON-2")) == GRANTED, "palier à 99 : PurchaseGranted")
check(dataOf(veteran).Boxes["2"].ReadyAt <= serverTime() + 1e-6, "le Mythique est prêt")
check(#remotes("BoxReady", function(e) return e.to == veteran and e.args[1] == 2 end) == 1, "BoxReady part tout de suite")
check(#notifies(veteran, "Your box is ready to open!") == 1, "Notify")
advance(1.1)
check(veteran:GetAttribute("OpenNowReadyAt") == b1.ReadyAt, "OpenNowReadyAt passe à l'Épique")
local bench = shopOf(veteran):FindFirstChild("UnboxBench_02", true)
check(bench ~= nil and bench:GetAttribute("UnboxState") == "Ready", "établi 2 : « Ready »")

section("Ouvrir maintenant : aucun colis en attente → crédit")
local fay = join("Fay", newProfile())
advance(1.1)
check(fay:GetAttribute("OpenNowReadyAt") == nil, "aucun colis : pas d'attribut")
check(settle(receipt(fay, TIER_IDS[2], "ON-F")) == GRANTED, "PurchaseGranted quand même")
check(dataOf(fay).Monetization.OpenNowCredit == 180, "180 s gardées en crédit")
check(#notifies(fay, "No box is waiting") == 1, "Notify")
local rare, rareZone = itemOf("Rare")
local f1 = placeBox(fay, 1, "Rare", rare, "Premium", rareZone)
flush()
check(f1 ~= nil and f1.ReadyAt <= serverTime() + 1e-6, "colis suivant (Rare, 45 s) : prêt tout de suite")
check(dataOf(fay).Monetization.OpenNowCredit == 135, "reste 135 s de crédit")
local f2 = placeBox(fay, 2, "Mythic", mythic, "Luxe", mythicZone)
flush()
check(near(f2.ReadyAt - serverTime(), Rarities.ById.Mythic.OpenDelay - 135, 0.05), "colis suivant (Mythique) : 135 s de moins")
check(dataOf(fay).Monetization.OpenNowCredit == 0, "crédit épuisé")
check(#notifies(fay, "Open Now: your new box wait is") == 2, "Notify à chaque colis raccourci")
local f3 = placeBox(fay, 3, "Rare", rare, "Premium", rareZone)
flush()
check(near(f3.ReadyAt - serverTime(), 45, 0.05), "sans crédit : attente normale")

section("pack d'argent avec bonus")
MARKET.owns[7] = { [PASS_IDS.DoubleCash] = true }
local rich = newProfile()
addItem(rich, "g-1", "Z3_Smartphone", 1, 3)
local gus = join("Gus", rich, 7)
advance(2)
local exposedG = gus:GetAttribute("ExposedIncome")
local cashG = cashOf(gus)
check(settle(receipt(gus, PRODUCT_IDS.Cash10, "CG-1")) == GRANTED, "PurchaseGranted")
check(cashOf(gus) - cashG == math.floor(exposedG * 2 * 600), `10 min des revenus du HUD (× 2 Argent compris) : +{cashOf(gus) - cashG} $`)

section("boost : compté seulement en jeu, gardé au départ")
advance(100)
local leftBefore = ada:GetAttribute("CashBoostEndsAt") - serverTime()
leave(ada)
local savedBoost = SAVED["Player_1"].Boosts.Cash
check(near(savedBoost, leftBefore, 0.2) and savedBoost < 3600 - 100, `départ : {string.format("%.0f", savedBoost)} s de boost sauvegardées`)
advance(500) -- hors du jeu : le boost ne s'use pas
local ada2 = join("Ada", nil, 1)
advance(1.2)
local ends2 = ada2:GetAttribute("CashBoostEndsAt")
check(type(ends2) == "number" and near(ends2 - serverTime(), savedBoost - 1.5, 1.5), "retour : le boost reprend là où il en était")
check(ada2:GetAttribute("Income") == 2 * ada2:GetAttribute("ExposedIncome"), "revenus doublés au retour")
check(MonetizationService.AddCashBoost(ada2, 600), "AddCashBoost (récompenses) : accepté")
check(near(ada2:GetAttribute("CashBoostEndsAt") - ends2, 600, 0.01), "un 2e boost prolonge le premier de 600 s")
check(ada2:GetAttribute("Income") == 2 * ada2:GetAttribute("ExposedIncome"), "sans doubler l'effet (× 2, pas × 4)")
check(not MonetizationService.AddCashBoost(ada2, -5) and not MonetizationService.AddCashBoost(ada2, 0 / 0), "durée invalide : refusée")
advance(ada2:GetAttribute("CashBoostEndsAt") - serverTime() + 2, 1)
check(ada2:GetAttribute("CashBoostEndsAt") == nil and dataOf(ada2).Boosts.Cash == 0, "boost fini")
check(ada2:GetAttribute("Income") == ada2:GetAttribute("ExposedIncome"), "revenus normaux après le boost")

section("pack de départ racheté (fenêtre ouverte sans l'écran)")
local cashA = cashOf(ada2)
clearLog()
check(settle(receipt(ada2, PRODUCT_IDS.StarterPack, "SP-2")) == GRANTED, "PurchaseGranted : le joueur a payé")
check(cashOf(ada2) == cashA + 50000 and type(ada2:GetAttribute("CashBoostEndsAt")) == "number", "redonné")
check(logHas("pack de départ acheté une 2e fois", "WARN", "server"), "avertissement dans la sortie")

summary("scénario offers")
