--!nocheck
-- Scénario « names » : tout texte que la télémétrie peut envoyer est accepté par Roblox (non vide,
-- sans virgule, guillemet ni apostrophe, droits ou typographiques) : Config/Telemetry, SKU du
-- catalogue, valeurs des champs, étapes du funnel. Et les limites de Roblox sont tenues.

startServer()
advance(0.5)
local Rarities = sharedModule("Config/Rarities")

local function safe(label, text)
	check(analyticsSafe(text), `{label} « {tostring(text)} »`)
end

section("Config/Telemetry")
safe("monnaie", Telemetry.Currency)
local eventCount = 0
for key, name in Telemetry.Events do
	eventCount += 1
	safe(`nom de l'événement {key}`, name)
end
local transactions = {}
local kinds = {}
for key, kind in Telemetry.Economy do
	table.insert(kinds, key)
	safe("genre (champ « Kind - … »)", `Kind - {key}`)
	safe(`type de transaction de {key}`, kind.Transaction)
	transactions[kind.Transaction] = true
	if kind.Sku then
		safe(`SKU fixe de {key}`, kind.Sku)
	end
	check(Enum.AnalyticsEconomyFlowType:FromName(kind.Flow) ~= nil, `{key} : sens « {kind.Flow} » membre de Enum.AnalyticsEconomyFlowType`)
end
for _, name in { "Gameplay", "Shop", "TimedReward", "IAP" } do
	check(transactions[name] and Enum.AnalyticsEconomyTransactionType:FromName(name) ~= nil, `type « {name} » utilisé, membre de Enum.AnalyticsEconomyTransactionType`)
end
check(Telemetry.Economy.Income.Flow == "Source" and Telemetry.Economy.Income.Transaction == "Gameplay", "revenus : Source, Gameplay")
for _, key in { "Tool", "Upgrade", "Aura", "Trail", "Defense" } do
	check(Telemetry.Economy[key].Flow == "Sink" and Telemetry.Economy[key].Transaction == "Shop", `{key} : Sink, Shop`)
end
check(Telemetry.Enabled == true and Telemetry.FlushInterval == 60, "interrupteur allumé, regroupement à 60 s")

section("SKU du catalogue")
local skus = { Income = true }
for _, tool in Tools.List do
	safe("outil", tool.Id)
	skus[tool.Id] = true
end
for _, upgrade in Upgrades.List do
	safe("amélioration", upgrade.Id)
	skus[upgrade.Id] = true
end
for id in Cosmetics.ById do
	safe("aura ou trail", id)
	skus[id] = true
end

section("valeurs des champs")
for _, key in kinds do
	safe("champ", `Kind - {key}`)
end
for level = 1, 20 do
	safe("champ", `Level - {level}`)
end
for _, rarity in Rarities.List do
	safe("champ", `Rarity - {rarity.Id}`)
end
for zone = 1, 6 do
	safe("champ", `Zone - {zone}`)
end
for _, phase in { "Day", "Warning", "Night" } do
	safe("champ", `Phase - {phase}`)
end
for _, reason in { "Deposited", "Bat", "Died", "Left", "CharacterRemoved", "VictimLeft", "NoRoom", "Anomaly", "Caught", "Unknown" } do
	safe("champ", `Reason - {reason}`)
end
for _, source in { "Store", "Truck" } do
	safe("champ", `Source - {source}`)
end

section("étapes du funnel (Config/Tutorial)")
check(#Tutorial.FunnelSteps == 10, "10 étapes (14.2)")
for index, step in Tutorial.FunnelSteps do
	safe(`étape {index}`, step)
end

section("vérification au démarrage")
check(logHas("[TelemetryService] économie et événements custom branchés, noms vérifiés", "PRINT", "server"), "TelemetryService : noms vérifiés")
check(not logHas("Roblox le refuserait", "WARN"), "aucun nom signalé")

section("limites de Roblox (doc « Event types »)")
check(eventCount <= 100, `{eventCount} noms d'événements custom (100 au plus)`)
local transactionCount = 0
for _ in transactions do
	transactionCount += 1
end
check(transactionCount <= 20, `{transactionCount} types de transaction (au-delà de 20 : « Other »)`)
local skuCount = 0
for _ in skus do
	skuCount += 1
end
check(skuCount <= 100, `{skuCount} SKU des gains et dépenses codés (au-delà de 100 : « Other »)`)
check(Rarities.List and #Rarities.List * 6 * 10 <= 8000, "combinaisons des champs custom sous 8 000")
summary("scénario names")
