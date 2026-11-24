--!nocheck
-- Scénario « hooks » : les points d'accroche des gains, dépenses et événements pas encore codés
-- (TelemetryService.LogEconomy et LogEvent) : receleur, quotidien, temps de jeu, code, Robux, défense
-- (économie et DefenseBought). Bon sens et bon type, solde lu à l'appel, cumuls envoyés d'abord,
-- textes nettoyés, appels invalides refusés sans erreur (un avertissement par cause).

startServer()

local ada = join("Ada", richProfile(10000))
local bob = join("Bob", newProfile())
advance(1)

local function expectEconomy(e, label, flow, transaction, sku, amount, balance, f1, f2)
	check(e ~= nil, `{label} : un envoi`)
	if e == nil then
		return
	end
	check(flowName(e) == flow and e.transaction == transaction, `{label} : {flow} {transaction} (trouvé {flowName(e)} {tostring(e.transaction)})`)
	check(e.sku == sku and e.amount == amount and e.balance == balance, `{label} : {sku} {amount}, solde {balance} (trouvé {tostring(e.sku)} {tostring(e.amount)}, {tostring(e.balance)})`)
	check(e.currency == "Cash" and fieldOf(e, 1) == f1 and fieldOf(e, 2) == f2, `{label} : champs « {f1} », « {tostring(f2)} » (trouvé {tostring(fieldOf(e, 1))}, {tostring(fieldOf(e, 2))})`)
end
-- Gain à venir : l'argent d'abord (comme le futur service), puis l'envoi.
local function gain(kind, amount, sku, fields)
	DataService.AddCash(ada, amount)
	local ok = TelemetryService.LogEconomy(ada, kind, amount, sku, fields)
	return ok, lastOf(economyOf(ada))
end

section("gains à venir")
local cash = cashOf(ada)
local ok, e = gain("Fence", 1200, "Rare")
check(ok, "receleur : accepté")
expectEconomy(e, "receleur (DEV-034)", "Source", "Shop", "Rare", 1200, cash + 1200, "Kind - Fence", nil)
cash = cashOf(ada)
ok, e = gain("DailyReward", 250, "Day1")
expectEconomy(e, "quotidien", "Source", "TimedReward", "Day1", 250, cash + 250, "Kind - DailyReward", nil)
cash = cashOf(ada)
ok, e = gain("PlaytimeReward", 100, "Playtime5")
expectEconomy(e, "temps de jeu", "Source", "TimedReward", "Playtime5", 100, cash + 100, "Kind - PlaytimeReward", nil)
cash = cashOf(ada)
ok, e = gain("Code", 500, "XMAS2026")
expectEconomy(e, "code cadeau (type à nous)", "Source", "Code", "XMAS2026", 500, cash + 500, "Kind - Code", nil)
check(logHas("revenus regroupés toutes les 60 s au plus ; types de transaction à nous : Code", "PRINT", "server"), "Studio : le type « Code » est signalé comme un type à nous, dans la ligne du démarrage")
cash = cashOf(ada)
ok, e = gain("Robux", 100000, "CashPack1")
expectEconomy(e, "argent acheté en Robux", "Source", "IAP", "CashPack1", 100000, cash + 100000, "Kind - Robux", nil)

section("dépense à venir : une défense")
cash = cashOf(ada)
check(DataService.SpendCash(ada, 25000), "la défense est payée")
check(TelemetryService.LogEconomy(ada, "Defense", 25000, "GlassThickness", { "Level - 1" }), "LogEconomy Defense : accepté")
expectEconomy(lastOf(economyOf(ada)), "défense", "Sink", "Shop", "GlassThickness", 25000, cash - 25000, "Kind - Defense", "Level - 1")
check(TelemetryService.LogEvent(ada, "DefenseBought", { "Defense - GlassThickness", "Level - 1" }), "LogEvent DefenseBought : accepté")
local ev = lastOf(eventsNamed("DefenseBought", ada))
check(ev ~= nil and ev.value == 1 and fieldOf(ev, 1) == "Defense - GlassThickness" and fieldOf(ev, 2) == "Level - 1" and fieldOf(ev, 3) == nil, "DefenseBought : valeur 1, champs Defense et Level")
check(TelemetryService.LogEvent(ada, "DefenseBought", nil, 3), "LogEvent avec une valeur")
ev = lastOf(eventsNamed("DefenseBought", ada))
check(ev.value == 3 and ev.fields == nil, "valeur 3, sans champ")
TelemetryService.LogEvent(ada, "DefenseBought", nil, 0 / 0)
check(lastOf(eventsNamed("DefenseBought", ada)).value == 1, "valeur NaN : 1")

section("les cumuls partent d'abord")
advance(2)
local a1 = cashOut(ada)
local b1 = cashOf(ada)
local n = #economyOf(ada)
ok, e = gain("Code", 10, "PROMO")
local list = economyOf(ada)
check(#list == n + 2, "deux envois : le cumul des revenus, puis le code")
expectEconomy(list[n + 1], "cumul d'abord", "Source", "Gameplay", "Income", a1, b1, "Kind - Income", nil)
expectEconomy(list[n + 2], "puis le code", "Source", "Code", "PROMO", 10, b1 + 10, "Kind - Code", nil)

section("un genre regroupé passe aussi par l'API")
n = #economyOf(ada)
DataService.AddCash(ada, 50)
check(TelemetryService.LogEconomy(ada, "Income", 50), "LogEconomy Income : accepté")
check(#economyOf(ada) == n, "regroupé : rien tout de suite")
advance(61)
expectEconomy(lastOf(economyOf(ada)), "cumul de l'API", "Source", "Gameplay", "Income", 50, cashOf(ada), "Kind - Income", nil)

section("textes nettoyés")
TelemetryService.LogEconomy(ada, "Code", 10, `D'oh, "X" ’Y’ «Z» ‘W’ “V” \`U\``)
check(lastOf(economyOf(ada)).sku == "Doh X Y Z W V U", `SKU sans virgule, guillemet ni apostrophe (trouvé « {lastOf(economyOf(ada)).sku} »)`)
TelemetryService.LogEvent(ada, "DefenseBought", { "Defense - L’œil, «test»", "'", "Level - 2" })
ev = lastOf(eventsNamed("DefenseBought", ada))
check(fieldOf(ev, 1) == "Defense - Lœil test", `champ nettoyé (trouvé « {tostring(fieldOf(ev, 1))} »)`)
check(fieldOf(ev, 2) == nil and fieldOf(ev, 3) == "Level - 2", "un champ vide une fois nettoyé n'est pas envoyé, les autres gardent leur place")
check(noRefusal(), "aucun texte refusé par le faux AnalyticsService")

section("appels invalides : false, un avertissement par cause, rien envoyé")
n = analyticsCount()
check(TelemetryService.LogEconomy(ada, "Lottery", 10) == false, "genre inconnu : false")
check(TelemetryService.LogEconomy(ada, "Lottery", 20) == false, "genre inconnu, encore : false")
check(logCount("genre « Lottery » absent de Config/Telemetry.Economy", "WARN", "server") == 1, "un seul avertissement pour ce genre")
for _, bad in { 0, -5, 0 / 0, math.huge, "12" } do
	check(TelemetryService.LogEconomy(ada, "Fence", bad, "Rare") == false, `montant {tostring(bad)} : false`)
end
check(logCount("Fence : montant invalide", "WARN", "server") == 1, "un seul avertissement pour les montants invalides du receleur")
check(TelemetryService.LogEvent(ada, "Teleport") == false and TelemetryService.LogEvent(ada, "Teleport") == false, "événement inconnu : false")
check(logCount("événement « Teleport » absent de Config/Telemetry.Events", "WARN", "server") == 1, "un seul avertissement pour cet événement")
leave(bob)
flush()
check(TelemetryService.LogEconomy(bob, "Fence", 10, "Rare") == false, "joueur parti (profil fermé) : false")
check(logHas("Bob : Fence pas envoyé, profil pas chargé", "PRINT", "server"), "Studio : une ligne")
check(analyticsCount() == n, "rien n'est envoyé pour ces appels")

section("fin")
check(noRefusal(), "aucun envoi refusé")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")
summary("scénario hooks")
