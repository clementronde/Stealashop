--!nocheck
-- Scénario « refusal » (Studio) : AnalyticsService refuse tout, comme Roblox en Studio ou en panne.
-- Le jeu n'en dépend pas : encaissements, achats, colis tombés, captures, vols et tuto se font ;
-- chaque envoi refusé écrit une ligne dans la sortie (« refusé par Roblox en Studio »), sans erreur
-- ni avertissement. Quand Roblox accepte de nouveau, les envois repartent (un envoi refusé n'est pas
-- renvoyé).

startServer()
ANALYTICS_FAILS = true

local ada = join("Ada", richProfile(20000))
local adaData = DataService.Get(ada)
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local kim = join("Kim", tutorialProfile())
giveBat(bob)
advance(1.2)
local REFUSED = "(refusé par Roblox en Studio : AnalyticsService: events can't be sent from Studio)"

section("tuto et funnel")
check(kim:GetAttribute("TutorialStep") == 1, "Kim a son tuto (étape 1)")
check(logHas(`[TutorialService] funnel Kim : étape 1 « {Tutorial.FunnelSteps[1]} » (refusé par Roblox en Studio`, "PRINT", "server"), "funnel refusé : une ligne de TutorialService")

section("revenus et achat d'outil")
advance(2)
local a1 = cashOut(ada)
check(a1 > 0 and cashOf(ada) == 20000 + a1, `encaissement fait ({a1} $)`)
goWeaponShop(ada)
buy(ada, "Wrench")
check(table.find(adaData.Tools.Owned, "Wrench") ~= nil and cashOf(ada) == 20000 + a1 - 300, "Clé à molette achetée et payée")
check(logHas(`Ada : Source Gameplay Income +{a1} Cash, solde {20000 + a1} (Kind - Income) {REFUSED}`, "PRINT", "server"), "le cumul des revenus, refusé : une ligne")
check(logHas(`Ada : Sink Shop Wrench -300 Cash, solde {20000 + a1 - 300} (Kind - Tool) {REFUSED}`, "PRINT", "server"), "l'achat, refusé : une ligne")
goHome(ada)
buy(ada, "Treadmill")
check(adaData.Upgrades.Treadmill == 1, "amélioration achetée")
goAuraShop(ada)
buy(ada, "Spark")
check(table.find(adaData.Cosmetics.Auras, "Spark") ~= nil, "aura achetée")

section("événements custom refusés")
moveTo(cy, Vector3.new(420, 3, 0), Vector3.new(0, 0, -1))
local def = Items.ByZone[2].Rare[1]
check(CarryService.StartCarry(cy, { Kind = "NPCBox", Tier = "Standard", Zone = 2, Rarity = "Rare", ItemId = def.Id, StoreId = "STORE_Z2_Kiosque", SlotId = "S1" }), "Cy porte un colis hors zone safe")
moveTo(bob, Vector3.new(420, 3, 4), Vector3.new(0, 0, -1))
humanoidOf(bob):EquipTool(batOf(bob))
fireAs(bob, "SwingBat")
flush()
check(not CarryService.IsCarrying(cy), "le coup de batte fait tomber le colis")
check(logHas(`Bob : BatBoxKnockdown (Zone - 2, Rarity - Rare, Source - Store) {REFUSED}`, "PRINT", "server"), "BatBoxKnockdown refusé : une ligne")
advance(3.2)
moveTo(cy, Vector3.new(500, 3, 0))
check(CarryService.StartCarry(cy, { Kind = "NPCBox", Tier = "Standard", Zone = 2, Rarity = "Rare", ItemId = def.Id, StoreId = "STORE_Z2_Kiosque", SlotId = "S2" }), "Cy porte un autre colis")
CarryService.Fail(cy, "Caught")
flush()
check(not CarryService.IsCarrying(cy), "capture faite")
check(logHas(`Cy : GuardCatch (Zone - 2, Phase - Day, Rarity - Rare) {REFUSED}`, "PRINT", "server"), "GuardCatch refusé : une ligne")

section("vol entre joueurs")
local adaShop = shopOf(ada)
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
check(steal(bob, adaShop, 1), "Bob prend les Écouteurs")
runHome(bob, adaShop)
check(DataService.Get(bob).Items["r-earbuds"] ~= nil and adaData.Items["r-earbuds"] == nil, "vol déposé chez Bob")
check(logHas(`Bob : PvPTheftSuccess (Rarity - Common, Zone - 3) {REFUSED}`, "PRINT", "server"), "PvPTheftSuccess refusé : une ligne")

section("Roblox accepte de nouveau")
local refusedCount = #ANALYTICS.refused
ANALYTICS_FAILS = false
goAuraShop(ada)
local before = cashOf(ada)
buy(ada, "Dust")
local list = economyOf(ada)
check(#list == 1 and list[1].sku == "Dust" and list[1].balance == before - 300, "le trail suivant part normalement")
goHome(ada)
advance(2)
local a2 = cashOut(ada)
advance(61)
list = economyOf(ada)
check(#list == 2 and list[2].sku == "Income" and list[2].amount == a2, "les revenus suivants aussi (les refusés ne sont pas renvoyés)")
check(#ANALYTICS.refused == refusedCount, "plus aucun refus")

section("fin")
check(refusedCount == 8, `8 envois refusés : funnel, revenus, 3 achats, colis tombé, capture, vol (trouvé {refusedCount})`)
check(not logHas("[TelemetryService]", "WARN"), "en Studio : des lignes dans la sortie, aucun avertissement")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")

if VERBOSE then
	dumpLog("refusé")
end
summary("scénario refusal")
