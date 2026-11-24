--!nocheck
-- Scénario « receipts » : MarketplaceService.ProcessReceipt idempotent (Partie 1, 9.6 ; DEV-100).
-- Un reçu est donné une seule fois, même rejoué ; PurchaseGranted seulement quand la sauvegarde
-- contient le PurchaseId ; joueur absent, profil pas chargé, produit inconnu ou pas codé :
-- NotProcessedYet sans rien donner ; sauvegarde ratée puis départ : NotProcessedYet, et le reçu rappelé
-- au retour est accepté sans redonner ; historique borné à 100 achats ; packs d'argent (montant, minimum,
-- télémétrie « Robux »).

startServer()

-- Profil aisé : 3 objets de la zone 3 exposés.
local function richProfile()
	local data = newProfile()
	addItem(data, "r-1", "Z3_Ecouteurs", 1, 3)
	addItem(data, "r-2", "Z3_TelephoneAClapet", 2, 3)
	addItem(data, "r-3", "Z3_Smartphone", 3, 3)
	return data
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(MarketplaceStub.ProcessReceipt ~= nil, "ProcessReceipt posé")
check(logHas("[MonetizationService] boutique Robux branchée : 6 gamepass(es) et 11 produit(s) en vente", "PRINT", "server"), "offres créées comptées : les Ids à 0 (Gants, pack de 5 h, Ouvrir maintenant sans palier) ignorés")

local ada = join("Ada", richProfile())
advance(1.5)
local income = ada:GetAttribute("Income")
check(income ~= nil and income > 0 and income == DisplayService.GetIncome(ada), `revenu d'Ada : {income} $/s, sans bonus`)

section("pack d'argent : donné une fois, même rejoué")
local cash0 = cashOf(ada)
local expected = Monetization.CashPackAmount(income, 10)
check(expected == math.floor(income * 600), `10 min de revenus = {expected} $`)
local r1 = receipt(ada, PRODUCT_IDS.Cash10, "PA-1")
flush()
check(cashOf(ada) == cash0 + expected, "argent donné tout de suite, dans la même exécution")
check(type(dataOf(ada).Purchases["PA-1"]) == "number", "PurchaseId noté dans Purchases (date du don)")
check(not r1.done, "pas encore de réponse : la sauvegarde n'est pas faite")
check(settle(r1) == GRANTED, "PurchaseGranted après la sauvegarde")
check(r1.doneAt - r1.t >= SAVE_DELAY - 1e-6, `réponse après la sauvegarde ({string.format("%.2f", r1.doneAt - r1.t)} s)`)
check(SAVED["Player_1"] ~= nil and SAVED["Player_1"].Purchases["PA-1"] ~= nil, "PurchaseId dans la sauvegarde")
check(#TELEMETRY == 1 and TELEMETRY[1].kind == "Robux" and TELEMETRY[1].sku == "Cash10" and TELEMETRY[1].amount == expected, "télémétrie : économie « Robux », SKU Cash10, le montant")
check(#notifies(ada, "added to your cash") == 1, "Notify au joueur")
local r2 = receipt(ada, PRODUCT_IDS.Cash10, "PA-1")
check(settle(r2) == GRANTED, "rejoué : PurchaseGranted")
check(cashOf(ada) == cash0 + expected and #TELEMETRY == 1, "rejoué : rien n'est redonné")
check(logHas("reçu PA-1 (Cash10) déjà donné, rien de plus", "PRINT", "server"), "Studio : une ligne pour le reçu rejoué")
-- Deux appels du même reçu en même temps : un seul don.
local r3 = receipt(ada, PRODUCT_IDS.Cash10, "PA-2")
local r4 = receipt(ada, PRODUCT_IDS.Cash10, "PA-2")
settle(r3)
settle(r4)
check(r3.decision == GRANTED and r4.decision == GRANTED and cashOf(ada) == cash0 + 2 * expected, "deux appels simultanés du même reçu : donné une fois")

section("montants")
local cashA = cashOf(ada)
settle(receipt(ada, PRODUCT_IDS.Cash60))
check(cashOf(ada) == cashA + math.floor(income * 3600), "pack de 1 h : 60 min de revenus")
local bob = join("Bob", newProfile()) -- aucun objet exposé : revenu 0
advance(1.5)
local bob0 = cashOf(bob)
check(settle(receipt(bob, PRODUCT_IDS.Cash10)) == GRANTED and cashOf(bob) == bob0 + 500, "sans revenu : le minimum, 50 $ par minute (500 $ pour 10 min)")

section("reçus refusés : rien n'est donné ni noté")
local count0 = 0
for _ in dataOf(ada).Purchases do
	count0 += 1
end
local cashR = cashOf(ada)
clearLog()
check(settle(receipt(ada, 7777, "PX-1")) == NOT_YET, "produit inconnu : NotProcessedYet")
check(logHas("produit 7777 absent de Config/Monetization", "WARN", "server"), "avertissement")
check(settle(receipt(ada, PRODUCT_IDS.Revenge, "PX-2")) == NOT_YET, "produit pas codé (Vengeance) : NotProcessedYet")
check(logHas("Revenge pas encore codé", "WARN", "server"), "avertissement")
check(settle(receipt(4242, PRODUCT_IDS.Cash10, "PX-3")) == NOT_YET, "joueur absent du serveur : NotProcessedYet")
local bad = { PlayerId = ada.UserId, ProductId = PRODUCT_IDS.Cash10 } -- sans PurchaseId
check(MarketplaceStub.ProcessReceipt(bad) == NOT_YET and logHas("reçu mal formé", "WARN", "server"), "reçu mal formé : NotProcessedYet")
local count1 = 0
for id in dataOf(ada).Purchases do
	count1 += 1
	check(string.sub(id, 1, 2) ~= "PX", `{id} : aucun reçu refusé noté`)
end
check(count1 == count0 and cashOf(ada) == cashR, "Purchases et argent inchangés")

section("profil pas encore chargé")
LOAD_DELAY = 5
local cid = newProfile()
PRESET_PROFILES["Player_3"] = cid
local cidPlayer = make("Player", { Name = "Cid", DisplayName = "Cid", UserId = 3 })
cidPlayer.Parent = Players
Players.PlayerAdded:Fire(cidPlayer)
local rc = receipt(cidPlayer, PRODUCT_IDS.Cash10, "PC-1")
advance(3)
check(not rc.done, "le reçu attend le profil")
advance(4)
check(rc.done and rc.decision == GRANTED and cashOf(cidPlayer) == 1000 + 500, "profil chargé au bout de 5 s : donné et accepté")
LOAD_NEVER["Player_4"] = true
local dan = make("Player", { Name = "Dan", DisplayName = "Dan", UserId = 4 })
dan.Parent = Players
Players.PlayerAdded:Fire(dan)
local rd = receipt(dan, PRODUCT_IDS.Cash10, "PD-1")
advance(Monetization.Receipts.ProfileWait - 1)
check(not rd.done, `toujours en attente avant {Monetization.Receipts.ProfileWait} s`)
advance(6)
check(rd.done and rd.decision == NOT_YET, "profil jamais chargé : NotProcessedYet au bout de l'attente")
LOAD_DELAY = 0

section("sauvegarde qui n'arrive pas, puis départ et retour")
SAVE_FAILS = true
local cashS = cashOf(ada)
local rs = receipt(ada, PRODUCT_IDS.Cash10, "PS-1")
advance(3)
check(not rs.done and cashOf(ada) == cashS + expected, "donné, mais pas de réponse tant que la sauvegarde ne passe pas")
leave(ada)
advance(0.5)
check(rs.done and rs.decision == NOT_YET, "départ : NotProcessedYet (Roblox rappellera le reçu)")
check(SAVED["Player_1"].Purchases["PS-1"] ~= nil and SAVED["Player_1"].Cash >= cashS + expected, "la sauvegarde de fin de session contient le don et le PurchaseId (plus la caisse encaissée au départ)")
SAVE_FAILS = false
local ada2 = join("Ada", nil, 1)
advance(1.5)
local back = cashOf(ada2)
check(back == SAVED["Player_1"].Cash and back >= cashS + expected, "retour : l'argent du don est là")
local rb = receipt(ada2, PRODUCT_IDS.Cash10, "PS-1")
check(settle(rb) == GRANTED and cashOf(ada2) == back, "reçu rappelé au retour : PurchaseGranted, rien de redonné")

section("historique borné")
local eve = newProfile()
for index = 1, 100 do
	eve.Purchases[`old-{index}`] = 1000 + index
end
local evePlayer = join("Eve", eve, 5)
advance(1)
check(settle(receipt(evePlayer, PRODUCT_IDS.Cash10, "PE-new")) == GRANTED, "nouvel achat accepté")
local count = 0
for _ in dataOf(evePlayer).Purchases do
	count += 1
end
check(count == Monetization.Receipts.History, `{count} achats gardés ({Monetization.Receipts.History} au plus)`)
check(dataOf(evePlayer).Purchases["old-1"] == nil and dataOf(evePlayer).Purchases["old-2"] ~= nil, "le plus ancien est parti")
check(dataOf(evePlayer).Purchases["PE-new"] ~= nil, "le nouveau est gardé")

section("migration v2 → v3")
local old = newProfile()
old.Version = 2
old.Purchases = { legacy = true }
old.Monetization = nil
old.Boosts = nil
local fay = join("Fay", old, 6)
advance(1)
local fd = dataOf(fay)
-- Copie d'a40 (DEV-111) : v4 (index des objets) quand l'arbre testé a Config/Index ; la migration v3 passe toujours.
-- Copie d'a48 (DEV-102) : v6 quand Types/Profile a Offline (gains hors ligne).
-- Copie d'a46 (L-086) : v5 quand Types/Profile a BoxQueue (colis sur les présentoirs).
-- Copie d'a51 (L-089) : v7 quand Types/Profile a Spot (colis rangés par uid).
local V = if SOURCES["shared/Types/Profile.luau"] and string.find(SOURCES["shared/Types/Profile.luau"], "Spot: Spot?", 1, true) then 7 elseif SOURCES["shared/Types/Profile.luau"] and string.find(SOURCES["shared/Types/Profile.luau"], "Offline: Offline", 1, true) then 6 elseif SOURCES["shared/Types/Profile.luau"] and string.find(SOURCES["shared/Types/Profile.luau"], "BoxQueue", 1, true) then 5 elseif SOURCES["shared/Config/Index.luau"] then 4 else 3
check(fd.Version == V and fd.Purchases.legacy == 0, `profil v2 : passé en v{V}, ancien true devenu 0`)
check(type(fd.Monetization) == "table" and fd.Monetization.StarterPack == false and fd.Monetization.OpenNowCredit == 0 and type(fd.Monetization.Passes) == "table", "Monetization complété depuis le modèle")
check(type(fd.Boosts) == "table" and fd.Boosts.Cash == 0, "Boosts complété")
check(logHas("migration v3 : Purchases : 1 achat(s) au format v3", "PRINT", "server"), "la migration l'écrit dans la sortie")

check(#KICKS == 1 and KICKS[1].player == dan, "seul Dan (profil jamais chargé) est expulsé, comme le prévoit DataService")
summary("scénario receipts")
