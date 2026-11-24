--!nocheck
-- Scénario « economy » : chaque gain et chaque dépense codés aujourd'hui partent en LogEconomyEvent,
-- avec le bon sens, le bon type, la monnaie Cash, le montant, le solde après l'opération et un SKU
-- lisible. Revenus (DisplayService.OnCashOut) : regroupés par joueur, un envoi au plus par minute,
-- même avec des allers-retours sur le tapis ; le cumul part avant tout autre envoi d'économie du
-- joueur et à son départ. Achats (ShopService.OnPurchase) : outil, amélioration (niveau atteint),
-- aura, trail, un envoi chacun ; un achat refusé ou rendu n'envoie rien.

startServer()

local ada = join("Ada", richProfile(20000))
local bob = join("Bob", richProfile(5000))
advance(1)

local function check1(e, label, expect)
	check(e ~= nil, `{label} : un envoi`)
	if e == nil then
		return
	end
	for key, value in expect do
		local got = if key == "flow" then flowName(e) elseif key == "f1" then fieldOf(e, 1) elseif key == "f2" then fieldOf(e, 2) elseif key == "f3" then fieldOf(e, 3) else e[key]
		check(got == value, `{label} : {key} = {tostring(value)} (trouvé {tostring(got)})`)
	end
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(logHas("[TelemetryService] économie et événements custom branchés, noms vérifiés", "PRINT", "server"), "TelemetryService démarré, noms vérifiés")
check(not logHas("[TelemetryService]", "WARN", "server"), "aucun avertissement au démarrage")
check(#ANALYTICS.all == 0, "rien n'est envoyé à l'arrivée des joueurs")

section("revenus : deux encaissements, un seul envoi")
advance(2)
local a1 = cashOut(ada)
local t1 = now()
check(a1 > 0, `Ada encaisse {a1} $`)
check(#economyOf(ada) == 0, "rien n'est envoyé tout de suite : le gain attend son cumul")
advance(10)
local a2 = cashOut(ada)
local b2 = cashOf(ada)
local bobCash = cashOut(bob)
check(a2 > 0 and bobCash > 0, `Ada encaisse encore {a2} $, Bob {bobCash} $`)
advance(t1 + 59 - now())
check(#economyOf(ada) == 0, "59 s après le premier encaissement : toujours rien")
advance(1.5)
local list = economyOf(ada)
check(#list == 1, `60 s après : un seul envoi pour Ada (trouvé {#list})`)
check1(list[1], "revenus d'Ada", {
	flow = "Source",
	currency = "Cash",
	amount = a1 + a2,
	balance = b2,
	transaction = "Gameplay",
	sku = "Income",
	f1 = "Kind - Income",
	f2 = nil,
	f3 = nil,
})
check(logHas(`Ada : Source Gameplay Income +{a1 + a2} Cash, solde {b2} (Kind - Income), 2 opérations regroupées`, "PRINT", "server"), "Studio : une ligne dans la sortie pour l'envoi")
check(#economyOf(bob) == 0, "le cumul de Bob a commencé 10 s plus tard : pas encore parti")
advance(10)
check1(lastOf(economyOf(bob)), "revenus de Bob", { player = bob, amount = bobCash, balance = cashOf(bob), sku = "Income" })

section("allers-retours sur le tapis : regroupés")
local count0 = #economyOf(ada)
local cashOuts, sum = 0, 0
for _ = 1, 20 do
	local got = cashOut(ada)
	if got > 0 then
		cashOuts += 1
		sum += got
	end
end
local balanceAfter = cashOf(ada)
check(cashOuts == 20, `20 encaissements en {math.floor(20 * 0.3)} s (trouvé {cashOuts})`)
check(#economyOf(ada) == count0, "aucun envoi pendant les allers-retours")
advance(61)
list = economyOf(ada)
check(#list == count0 + 1, `un seul envoi pour les 20 encaissements (trouvé {#list - count0})`)
check1(lastOf(list), "cumul des allers-retours", { amount = sum, balance = balanceAfter, sku = "Income", flow = "Source" })
check(logHas("20 opérations regroupées", "PRINT", "server"), "Studio : « 20 opérations regroupées »")

section("encaissement par l'API (DisplayService.CashOut)")
advance(3)
local apiAmount = DisplayService.CashOut(ada)
check(apiAmount > 0, `DisplayService.CashOut : {apiAmount} $`)
advance(61)
check1(lastOf(economyOf(ada)), "encaissement « Api »", { amount = apiAmount, balance = cashOf(ada), sku = "Income" })

section("achat d'un outil : le cumul part d'abord")
advance(2)
local a3 = cashOut(ada)
local b3 = cashOf(ada)
count0 = #economyOf(ada)
goWeaponShop(ada)
buy(ada, "Wrench")
check(table.find(DataService.Get(ada).Tools.Owned, "Wrench") ~= nil, "Ada possède la Clé à molette")
list = economyOf(ada)
check(#list == count0 + 2, `deux envois : le cumul des revenus, puis l'achat (trouvé {#list - count0})`)
check1(list[count0 + 1], "cumul envoyé avant l'achat", { flow = "Source", amount = a3, balance = b3, sku = "Income" })
check1(list[count0 + 2], "achat de la Clé à molette", {
	flow = "Sink",
	currency = "Cash",
	amount = 300,
	balance = b3 - 300,
	transaction = "Shop",
	sku = "Wrench",
	f1 = "Kind - Tool",
	f2 = nil,
})
check(cashOf(ada) == b3 - 300, "le solde envoyé est celui du profil après l'achat")
advance(61)
check(#economyOf(ada) == count0 + 2, "le cumul ne repart pas une seconde fois")

section("améliorations : niveau atteint dans le champ 2")
goHome(ada)
local function buyUpgrade(id, expectedLevel)
	local level = DataService.Get(ada).Upgrades[id]
	local cost = Formulas.UpgradeCost(id, level)
	local before = cashOf(ada)
	local n = #economyOf(ada)
	buy(ada, id)
	local e = economyOf(ada)[n + 1]
	check(#economyOf(ada) == n + 1, `{id} : un envoi`)
	check1(e, `{id} niveau {expectedLevel}`, {
		flow = "Sink",
		amount = cost,
		balance = before - cost,
		transaction = "Shop",
		sku = id,
		f1 = "Kind - Upgrade",
		f2 = `Level - {expectedLevel}`,
	})
end
buyUpgrade("Treadmill", 1)
buyUpgrade("Treadmill", 2)
buyUpgrade("Bench", 1)
buyUpgrade("DisplaySlots", 3) -- le profil du banc a déjà 2 niveaux de présentoirs
buyUpgrade("UnboxBenches", 1)

section("aura et trail")
goAuraShop(ada)
local before = cashOf(ada)
local n = #economyOf(ada)
buy(ada, "Spark")
check1(economyOf(ada)[n + 1], "aura Étincelle", { flow = "Sink", amount = 500, balance = before - 500, transaction = "Shop", sku = "Spark", f1 = "Kind - Aura" })
buy(ada, "Dust")
check1(economyOf(ada)[n + 2], "trail Poussière", { flow = "Sink", amount = 300, balance = before - 800, transaction = "Shop", sku = "Dust", f1 = "Kind - Trail" })
check(#economyOf(ada) == n + 2, "deux envois, un par achat")

section("achats refusés ou rendus : rien ne part")
n = #ANALYTICS.economy
buy(ada, "Spark") -- déjà possédée
goWeaponShop(ada)
buy(ada, "Wrench") -- déjà possédée
DataService.Get(ada).Cash = 100
buy(ada, "Crowbar") -- pas assez d'argent
DataService.Get(ada).Cash = 50000
goHome(ada)
buy(ada, "Crowbar") -- loin de la boutique d'armes
goWeaponShop(ada)
buy(ada, "Treadmill") -- loin de sa parcelle
buy(ada, "NotAnItem") -- Id inconnu
GRANT_TOOL_FAILS = true
buy(ada, "Crowbar") -- l'octroi échoue : argent rendu
GRANT_TOOL_FAILS = false
check(cashOf(ada) == 50000 and table.find(DataService.Get(ada).Tools.Owned, "Crowbar") == nil, "Clé non donnée, argent rendu")
goAuraShop(ada)
GRANT_COSMETIC_FAILS = true
buy(ada, "Flame") -- l'octroi échoue : argent rendu
GRANT_COSMETIC_FAILS = false
check(cashOf(ada) == 50000, "aura non donnée, argent rendu")
check(#ANALYTICS.economy == n, `aucun envoi pour 8 achats refusés ou rendus (trouvé {#ANALYTICS.economy - n})`)

section("départ : le cumul et l'encaissement automatique partent tout de suite")
goHome(ada)
advance(2)
local a4 = cashOut(ada)
advance(5)
local register = DisplayService.GetRegister(ada)
check(a4 > 0 and register > 0, `Ada encaisse {a4} $, puis {register} $ attendent dans sa caisse`)
n = #economyOf(ada)
leave(ada)
flush()
list = economyOf(ada)
check(#list == n + 1, `un envoi au départ (trouvé {#list - n})`)
local saved = STORE[ada.UserId]
check1(lastOf(list), "départ d'Ada", { flow = "Source", amount = a4 + register, balance = saved.Cash, sku = "Income" })
check(logHas("de sa caisse encaissés automatiquement", "PRINT", "server"), "DisplayService a encaissé la caisse au départ (source « Leave »)")
advance(61)
check(#economyOf(ada) == n + 1, "plus rien n'est envoyé pour Ada après son départ")

section("fin")
check(noRefusal(), "aucun envoi refusé par le faux AnalyticsService (noms, montants, champs)")
for _, e in ANALYTICS.economy do
	if e.currency ~= "Cash" or not (e.amount > 0) or e.balance < 0 then
		check(false, `envoi incohérent : {e.sku} {e.amount} {e.balance}`)
	end
end
check(#ANALYTICS.custom == 0 and #ANALYTICS.funnel == 0, "aucun événement custom ni étape de funnel dans ce scénario")
check(not logHas("[TelemetryService]", "WARN"), "aucun avertissement de TelemetryService")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")

if VERBOSE then
	dumpLog("TelemetryService")
end
summary("scénario economy")
