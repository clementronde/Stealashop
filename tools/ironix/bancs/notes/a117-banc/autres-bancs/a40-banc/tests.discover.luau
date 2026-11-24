--!nocheck
-- Scénario « discover » : la découverte à chaque point d'entrée d'un objet dans Items (ouverture d'un
-- colis par le vrai UnboxService, colis garanti du tuto, vol à un joueur au dépôt, API Discover), une
-- seule fois ; l'attribut envoyé au client ; la récompense : +5 % de revenus par zone complète, Notify
-- au moment où l'objet se révèle (revealDelay d'OnBoxOpened), additionnée à Premium (les % s'additionnent)
-- puis multipliée par le boost ×2 argent, comptée aussi dans le pack d'argent ; départ.

advance(1000)
startServer()

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(logHas("[MonetizationService] boutique Robux branchée", "PRINT", "server"), "boutique Robux branchée (Premium, boost et pack d'argent pour ce banc)")

section("ouverture d'un colis : l'objet est découvert, une seule fois")
local ada = join("Ada", newProfile())
advance(1.5)
check(ada:GetAttribute("IndexDiscovered") == "", "profil sans objet : attribut vide")
local openedAt = nil
local uid1 = openBox(ada, 1, "Common", "Z1_Donut", "Standard", 1)
openedAt = math.floor(now())
local t1 = dataOf(ada).Index.Z1_Donut
check(uid1 ~= nil and dataOf(ada).Items[uid1] ~= nil and dataOf(ada).Items[uid1].Id == "Z1_Donut", "colis ouvert par le vrai OpenBox : le Donut est dans Items")
check(t1 ~= nil and t1 >= openedAt - 1 and t1 <= openedAt, `découvert à l'ouverture (Index.Z1_Donut = {tostring(t1)}, os.time() = {openedAt})`)
check(ada:GetAttribute("IndexDiscovered") == "Z1_Donut", "attribut envoyé au client : « Z1_Donut »")
check(IndexService.IsDiscovered(ada, "Z1_Donut") and not IndexService.IsDiscovered(ada, "Z1_Banane"), "IsDiscovered")
check(logHas("[IndexService] Ada : Z1_Donut découvert (1 / 83)", "PRINT", "server"), "une ligne dans la sortie (Studio)")
advance(5)
local uid2 = openBox(ada, 3, "Common", "Z1_Donut", "Standard", 1) -- copie a46 : le présentoir 1 garde le 1er Donut
check(uid2 ~= nil and uid2 ~= uid1 and dataOf(ada).Items[uid2].Id == "Z1_Donut", "2e Donut ouvert (autre uid)")
check(dataOf(ada).Index.Z1_Donut == t1, "2e copie : la date de découverte ne change pas")
check(logCount("Z1_Donut découvert", "PRINT", "server") == 1, "découvert une seule fois")
check(not IndexService.Discover(ada, "Z1_Donut"), "Discover d'un objet déjà découvert : false")
check(not IndexService.Discover(ada, "Z9_Futur") and dataOf(ada).Index.Z9_Futur == nil, "Discover d'un ItemId inconnu : false, rien de noté")
check(IndexService.Discover(ada, "Z1_Banane") and dataOf(ada).Index.Z1_Banane ~= nil, "Discover (pour un autre point d'entrée) : true, noté")
check(ada:GetAttribute("IndexDiscovered") == "Z1_Donut,Z1_Banane", `attribut dans l'ordre du catalogue : {tostring(ada:GetAttribute("IndexDiscovered"))}`)

section("colis garanti du tuto : le Pot de nouilles")
TUTORIAL_ACTIVE[ada] = true
local uid3 = openBox(ada, 2, "Rare", Tutorial.GuaranteedItemId, "Premium", 1)
TUTORIAL_ACTIVE[ada] = nil
check(uid3 ~= nil and dataOf(ada).Items[uid3].Id == Tutorial.GuaranteedItemId, "colis du tuto ouvert (5 s)")
check(dataOf(ada).Index[Tutorial.GuaranteedItemId] ~= nil, "objet offert par le tuto (TutorialOnly) : découvert")

section("vol à un joueur : découvert chez le voleur, au dépôt")
local bobData = newProfile()
addItem(bobData, "j-1", "Z5_LaJoconde", 1, 5, 900)
local bob = join("Bob", bobData)
advance(1.5)
check(dataOf(bob).Index.Z5_LaJoconde == 900, "la victime l'avait découverte (migration v3 → v4)")
PvPService.Fail(ada, bob, "Z5_LaJoconde", "Bat")
flush()
check(dataOf(ada).Index.Z5_LaJoconde == nil, "vol raté (« Returned ») : rien de découvert")
PvPService.Steal(ada, bob, "j-1")
flush()
check(dataOf(ada).Items["j-1"] ~= nil and dataOf(ada).Items["j-1"].Source == "PvP", "vol déposé : la Joconde est chez le voleur")
check(dataOf(ada).Index.Z5_LaJoconde ~= nil, "vol déposé (« Stolen ») : découverte chez le voleur")
check(string.find(ada:GetAttribute("IndexDiscovered"), "Z5_LaJoconde", 1, true) ~= nil, "attribut du voleur à jour")
check(dataOf(bob).Items["j-1"] == nil and dataOf(bob).Index.Z5_LaJoconde == 900, "la victime l'a perdue, mais elle reste dans son index")
-- Ordre du vrai PvPService (sa source) : l'objet entre dans Items du voleur, puis OnTheftEnded « Stolen ».
local pvp = SOURCES["server/Services/PvPService.luau"]
local transfer = string.find(pvp, "thiefData.Items[theft.Uid] = {", 1, true)
local emitted = string.find(pvp, 'emitEnded(theft, "Stolen", "Deposited")', 1, true)
check(transfer ~= nil and emitted ~= nil and transfer < emitted, "vrai PvPService : l'objet entre dans Items du voleur avant OnTheftEnded(…, \"Stolen\")")

section("zone 1 complète : +5 % de revenus, message à la révélation")
-- Cid : les 13 objets de la zone 1 sauf la Carotte (4 exposés, le reste dans l'inventaire).
local cidData = newProfile()
local count = 0
for _, item in Index.ByZone[1] do
	if item.Id ~= "Z1_Carotte" then
		count += 1
		addItem(cidData, `z1-{count}`, item.Id, if count <= 3 then count else nil, 1, 500) -- copie a46 : le présentoir 4 reçoit le colis
	end
end
local cid = join("Cid", cidData)
advance(1.5)
local exposed = cid:GetAttribute("ExposedIncome")
check(exposed ~= nil and exposed > 0 and cid:GetAttribute("Income") == exposed, `zone 1 à 12 / 13 : revenus sans bonus ({tostring(exposed)} $/s)`)
check(IndexService.GetIncomeBonus(cid) == 0 and #IndexService.GetCompletedZones(cid) == 0, "aucune zone complète, bonus 0")
local opened = openBox(cid, 4, "Common", "Z1_Carotte", "Standard", 1)
check(opened ~= nil and dataOf(cid).Index.Z1_Carotte ~= nil, "la Carotte, 13e objet de la zone 1 : découverte")
-- Copie a46 (L-086) : la Carotte reste exposée sur le présentoir 4 de son colis : la valeur exposée monte d'autant.
-- Copie a51 (L-089) : l'objet ouvert va dans l'inventaire, la valeur exposée ne change pas.
if not COMPAT51 then
	exposed += Formulas.ItemIncome(1, "Common")
end
local zones = IndexService.GetCompletedZones(cid)
check(near(IndexService.GetIncomeBonus(cid), 0.05) and #zones == 1 and zones[1] == 1, "zone 1 complète : +5 % (Config/Index)")
check(logHas("[IndexService] Cid : Z1_Carotte découvert (13 / 83), zone 1 complète", "PRINT", "server"), "une ligne dans la sortie")
check(#notifies(cid, "complete") == 0, "pas de message avant la révélation de l'objet")
local delay = revealDelay("Common")
advance(delay - 0.35)
check(#notifies(cid, "complete") == 0, `toujours rien {string.format("%.2f", delay - 0.35)} s après l'ouverture`)
advance(0.7)
local messages = notifies(cid, "Index: Zone 1 complete! +3% speed and +5% income forever. Claim your $10.2K in the Index!")
check(#messages == 1 and messages[1].args[2] == "Info", `« Index: Zone 1 complete! +3% speed and +5% income forever. Claim your $10.2K in the Index! » (Info) à la révélation, {string.format("%.2f", delay)} s après l'ouverture`)
check(#notifies(cid, "complete") == 1, "un seul message")
advance(1.5)
check(near(cid:GetAttribute("Income"), exposed * 1.05), `revenus × 1,05 : {cid:GetAttribute("Income")} $/s`)
check(cid:GetAttribute("ExposedIncome") == exposed, "valeur exposée inchangée (anti-racket, panneau des boutiques)")
check(near(DisplayService.GetGlobalMultiplier(cid), 1.05), "GetGlobalMultiplier = 1,05")

section("bonus additionnés : index et Premium, puis le boost ×2")
cid.MembershipType = Enum.MembershipType.Premium
advance(1.5)
check(near(cid:GetAttribute("Income"), exposed * 1.15), `Premium (+10 %) et index (+5 %) s'additionnent : × 1,15 ({cid:GetAttribute("Income")} $/s ; × 1,155 s'ils se multipliaient)`)
check(near(DisplayService.GetGlobalMultiplier(cid), 1.15), "GetGlobalMultiplier = 1,15")
check(near(MonetizationService.GetIncomeMultiplier(cid), 1.1), "part de la boutique Robux (MonetizationService.GetIncomeMultiplier) : 1,1, Premium seul")
check(MonetizationService.AddCashBoost(cid, 600), "boost ×2 argent de 10 min")
advance(1.5)
check(near(cid:GetAttribute("Income"), exposed * 2.3), `boost ×2 : (1 + 0,1 + 0,05) × 2 = × 2,3 ({cid:GetAttribute("Income")} $/s)`)
check(near(MonetizationService.GetIncomeMultiplier(cid), 2.2), "part de la boutique Robux : (1 + 0,1) × 2 = 2,2")

section("pack d'argent : revenus actuels, bonus de l'index compris")
local income = cid:GetAttribute("Income")
local cash0 = dataOf(cid).Cash
local r = receipt(cid, 8002, "PA-1")
check(settle(r) == GRANTED, "reçu du pack de 10 min : PurchaseGranted")
local expected = Monetization.CashPackAmount(income, 10)
check(dataOf(cid).Cash == cash0 + expected, `pack = 10 min des revenus du HUD, bonus compris : +{expected} $ (trouvé +{dataOf(cid).Cash - cash0})`)
check(expected > Monetization.CashPackAmount(exposed * 2.2, 10), "plus qu'avec Premium et le boost seuls : l'index compte")

section("deux zones complètes : +10 %")
for _, item in Index.ByZone[2] do
	IndexService.Discover(cid, item.Id)
end
flush()
check(near(IndexService.GetIncomeBonus(cid), 0.1) and #IndexService.GetCompletedZones(cid) == 2, "zones 1 et 2 : +10 %")
check(#notifies(cid, "Index: Zone 2 complete! +3% speed and +5% income forever. Claim your $1.5M in the Index!") == 1, "message de la zone 2, tout de suite (pas de colis à révéler)")
advance(1.5)
check(near(cid:GetAttribute("Income"), exposed * 2.4), `(1 + 0,1 + 0,1) × 2 = × 2,4 ({cid:GetAttribute("Income")} $/s)`)
check(#notifies(cid, "Zone 1 complete") == 1, "zone 1 : toujours un seul message")

section("départ")
leave(cid)
check(IndexService.GetIncomeBonus(cid) == 0, "joueur parti : bonus 0")
local saved = SAVED["Player_3"]
check(saved ~= nil and saved.Index.Z1_Carotte ~= nil and countKeys(saved.Index) == 13 + 16, `sauvegarde : l'index de Cid ({saved and countKeys(saved.Index)} objets : 13 de la zone 1, 16 de la zone 2)`)

section("message de zone : joueur parti avant la révélation")
local danData = newProfile()
count = 0
for _, item in Index.ByZone[1] do
	if item.Id ~= "Z1_EpiDeMais" then
		count += 1
		addItem(danData, `d1-{count}`, item.Id, nil, 1, 500)
	end
end
local dan = join("Dan", danData)
advance(1.5)
check(openBox(dan, 1, "Common", "Z1_EpiDeMais", "Standard", 1) ~= nil and #IndexService.GetCompletedZones(dan) == 1, "Dan complète la zone 1")
leave(dan)
advance(revealDelay("Common") + 1)
check(#notifies(dan, "complete") == 0, "parti avant la révélation : aucun message")
check(SAVED["Player_4"] ~= nil and SAVED["Player_4"].Index.Z1_EpiDeMais ~= nil, "la découverte est bien sauvegardée")

summary("scénario discover")
