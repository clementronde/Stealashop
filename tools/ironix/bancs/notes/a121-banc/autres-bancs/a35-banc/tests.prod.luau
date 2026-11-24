--!nocheck
-- Scénario « prod » : hors de Studio (RunService:IsStudio() = false). Aucune ligne par envoi dans la
-- sortie ; un refus de Roblox avertit une seule fois par nom, quel que soit le nombre d'envois
-- refusés, et jamais d'erreur. Quand Roblox accepte, les envois partent sans rien écrire.

startServer()

local ada = join("Ada", richProfile(500000))
local adaData = DataService.Get(ada)
local dan = join("Dan", newProfile())
advance(1)

local function carryBox(player, slot)
	local def = Items.ByZone[3].Common[1]
	return CarryService.StartCarry(player, { Kind = "NPCBox", Tier = "Standard", Zone = 3, Rarity = "Common", ItemId = def.Id, StoreId = "STORE_Z3_Electro", SlotId = slot })
end

section("démarrage hors de Studio")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(not logHas("[TelemetryService]", "PRINT"), "aucune ligne de TelemetryService dans la sortie (Studio seulement)")

section("Roblox refuse : un avertissement par nom")
ANALYTICS_FAILS = true
advance(2)
local a1 = cashOut(ada)
check(a1 > 0, "encaissement fait")
goWeaponShop(ada)
buy(ada, "Wrench")
buy(ada, "Crowbar")
buy(ada, "Hammer")
check(table.find(adaData.Tools.Owned, "Hammer") ~= nil, "les trois outils sont achetés")
for i = 1, 3 do
	check(carryBox(dan, `S{i}`), `Dan porte un colis ({i})`)
	CarryService.Fail(dan, "Caught")
	flush()
end
check(logCount("[TelemetryService] Tool refusé par AnalyticsService", "WARN", "server") == 1, "3 achats d'outil refusés : un seul avertissement « Tool »")
check(logCount("[TelemetryService] Income refusé par AnalyticsService", "WARN", "server") == 1, "cumul des revenus refusé : un avertissement « Income »")
check(logCount("[TelemetryService] GuardCatch refusé par AnalyticsService", "WARN", "server") == 1, "3 captures refusées : un seul avertissement « GuardCatch »")
check(logCount("[TelemetryService]", "WARN", "server") == 3, `3 avertissements en tout (trouvé {logCount("[TelemetryService]", "WARN", "server")})`)
check(logHas("AnalyticsService: events can't be sent from Studio", "WARN", "server"), "l'avertissement donne la raison de Roblox")
check(#ANALYTICS.refused == 7, `7 envois refusés (trouvé {#ANALYTICS.refused})`)

section("Roblox accepte de nouveau")
ANALYTICS_FAILS = false
clearLog()
goAuraShop(ada)
buy(ada, "Spark")
check(carryBox(dan, "S4"), "Dan porte un colis")
CarryService.Fail(dan, "Caught")
flush()
local list = economyOf(ada)
check(#list == 1 and list[1].sku == "Spark" and list[1].balance == cashOf(ada), "l'achat suivant part, avec le bon solde")
check(#eventsNamed("GuardCatch", dan) == 1, "la capture suivante aussi")
check(not logHas("[TelemetryService]"), "rien n'est écrit pour des envois acceptés")

section("fin")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")
summary("scénario prod")
