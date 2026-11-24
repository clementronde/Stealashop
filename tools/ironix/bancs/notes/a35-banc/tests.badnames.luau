--!nocheck
-- Scénario « badnames » : des noms fautifs dans la config (pre.badnames.luau). TelemetryService les
-- signale au démarrage, un avertissement par nom, et les envoie nettoyés : Roblox les accepte. L'étape
-- du funnel fautive, envoyée telle quelle par TutorialService, est refusée par Roblox : une ligne dans
-- la sortie, le tuto continue.

startServer()

local ada = join("Ada", richProfile(20000))
local dan = join("Dan", newProfile())
local kim = join("Kim", tutorialProfile())
advance(1)

section("signalés au démarrage")
check(logHas("nom de l'événement GuardCatch « Guard'Catch » vide, ou avec une virgule, un guillemet ou une apostrophe : Roblox le refuserait", "WARN", "server"), "nom d'événement signalé")
check(logHas("SKU de Income « In,come »", "WARN", "server"), "SKU fixe signalé")
check(logHas("type de transaction de Code « “Code” »", "WARN", "server"), "type de transaction signalé")
check(logHas("étape 1 du funnel « Arrivée sur l'aire »", "WARN", "server"), "étape du funnel signalée")
check(logCount("Roblox le refuserait", "WARN", "server") == 4, `4 avertissements (trouvé {logCount("Roblox le refuserait", "WARN", "server")})`)
check(logHas("économie et événements custom branchés, 4 nom(s) fautif(s), voir plus haut", "PRINT", "server"), "le démarrage le résume")

section("envoyés nettoyés, acceptés")
local def = Items.ByZone[1].Common[1]
check(CarryService.StartCarry(dan, { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = def.Id, StoreId = "STORE_Z1_Superette", SlotId = "S1" }), "Dan porte un colis")
CarryService.Fail(dan, "Caught")
flush()
check(#eventsNamed("GuardCatch", dan) == 1, "capture envoyée sous le nom « GuardCatch »")
advance(2)
local a1 = cashOut(ada)
advance(61)
local e = lastOf(economyOf(ada))
check(e ~= nil and e.sku == "Income" and e.amount == a1, "revenus envoyés avec le SKU « Income »")
DataService.AddCash(ada, 10)
TelemetryService.LogEconomy(ada, "Code", 10, "PROMO")
e = lastOf(economyOf(ada))
check(e ~= nil and e.transaction == "Code" and e.sku == "PROMO", "code envoyé avec le type « Code »")
check(#ANALYTICS.refused == 1, `un seul refus : l'étape du funnel (trouvé {#ANALYTICS.refused})`)

section("étape du funnel refusée par Roblox, le tuto continue")
local refused = ANALYTICS.refused[1]
check(refused and refused.kind == "funnel" and refused.refusedField == "stepName", "refus : champ stepName de l'étape 1")
check(logHas("[TutorialService] funnel Kim : étape 1 « Arrivée sur l'aire » (refusé par Roblox en Studio : Event field stepName is invalid)", "PRINT", "server"), "une ligne de TutorialService, avec la raison de Roblox")
check(kim:GetAttribute("TutorialStep") == 1, "Kim a son tuto")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")
summary("scénario badnames")
