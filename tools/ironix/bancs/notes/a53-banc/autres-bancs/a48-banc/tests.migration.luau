--!nocheck
-- Copie d'a53 (DEV-101) : v8 quand Types/Profile a Rewards (récompenses), v7 sinon.
PV = if string.find(SOURCES["shared/Types/Profile.luau"] or "", "Rewards: Rewards", 1, true) then 8 else 7
-- Scénario « migration » (DEV-102) : profil v5 → v6 sans rien perdre ; un vieux profil n'a pas d'heure :
-- aucun gain hors ligne la première fois ; profils abîmés ; profil neuf ; sauvegarde v6 ; le profil v6
-- rapporte au retour suivant.

advance(1000)
startServer()
check(logHas("[OfflineService] gains hors ligne : 100 % des revenus, 4 h au plus", "PRINT", "server"), "OfflineService branché (Rate = 1, MaxHours = 4)")

section("v5 → v6 : rien de perdu, aucun gain la première fois")
alignSecond()
local data = newProfile(5)
addItem(data, "a", "Z1_Donut", 1, 1, 500)
addItem(data, "b", "Z1_Banane", 2, 1, 500)
addItem(data, "inv", "Z1_Donut", nil, 1, 500)
data.Cash = 4321
data.Index = { Z1_Donut = 500, Z1_Banane = 500 }
data.Boxes["3"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 99999 }
data.BoxQueue = { { Tier = "Premium", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 5 } }
data.Purchases = { P1 = 123 }
data.Boosts.Cash = 600
local before = deepCopy(data)
local wall = wallNow()
local ada = join("Ada", data)
local d = dataOf(ada)
-- a51 (L-089) : la migration va maintenant jusqu'à la v7 (colis dans l'inventaire).
check(d.Version == PV, "profil v5 : passé en v6 puis v7")
check(type(d.Offline) == "table" and d.Offline.LastSeenAt == wall and d.Offline.Income == 0, `Offline complété : LastSeenAt = maintenant ({wall}), Income = 0`)
check(#creditsOf(ada) == 0 and DisplayService.GetRegister(ada) == 0, "heure inconnue : aucun gain hors ligne, caisse vide")
check(d.Cash == 4321 and d.Items.a and d.Items.b and d.Items.inv and d.Display["1"] == "a" and d.Display["2"] == "b", "argent, objets et présentoirs gardés")
local kept = {}
for uid, box in d.Boxes do
	if tonumber(uid) == nil and box.Spot == nil then
		kept[box.ReadyAt] = box
	end
end
check(kept[99999] and kept[5] and d.BoxQueue == nil, "colis gardés dans l'inventaire (v7 : celui du présentoir 3 et celui de la file), heures promises gardées")
check(d.Index.Z1_Donut == 500 and d.Purchases.P1 == 123 and d.Boosts.Cash == 600, "index, achats et boost gardés")
check(not logHas("migration v6", "WARN", "server"), "aucune ligne orange de migration")
advance(3.5)
check(#notifies(ada, "while you were away") == 0, "aucun message")
advance(Offline.SnapshotInterval + 0.5)
local exposed = incomeOf("Z1_Donut") + incomeOf("Z1_Banane")
check(near(d.Offline.Income, exposed) and d.Offline.LastSeenAt == wallNow(), `relevé en jeu : Income = {exposed} $/s exposés, LastSeenAt suit l'heure`)

section("sauvegarde v6 puis retour : le gain hors ligne compte")
leave(ada)
local saved = SAVED["Player_1"]
check(saved.Version == PV and saved.Offline.LastSeenAt == wallNow() and near(saved.Offline.Income, exposed), "sauvegardé en v6 avec l'heure et le revenu du départ")
check(saved.Cash >= 4321 and saved.Items.a and saved.Display["1"] == "a", "le reste est sauvegardé (Cash + la caisse encaissée au départ)")
alignSecond()
local leftAt = saved.Offline.LastSeenAt
away(100)
clearLog()
local back = join("Ada", nil, 1)
local absence = wallNow() - leftAt
local credits = creditsOf(back)
check(not logHas("migration v", nil, "server"), "déjà en v7 : aucune migration au retour")
check(#credits == 1 and near(credits[1].amount, absence * exposed), `retour : {absence} s × {exposed} $/s = {absence * exposed} $ versés dans la caisse ({credits[1] and credits[1].amount})`)
leave(back)

section("profils abîmés")
local p = newProfile(5)
p.Offline = "pas une table"
local bea = join("Bea", p)
check(dataOf(bea).Version == PV and type(dataOf(bea).Offline) == "table" and dataOf(bea).Offline.Income == 0, "Offline qui n'est pas une table : repart du modèle")
check(logHas("migration v6 : Offline n'est pas une table (pas une table)", "WARN", "server"), "ligne orange")
check(#creditsOf(bea) == 0, "aucun gain")
leave(bea)

local q = newProfile(5)
q.Offline = { LastSeenAt = "hier", Income = math.huge }
alignSecond()
local cid = join("Cid", q)
check(dataOf(cid).Offline.Income == 0 and dataOf(cid).Offline.LastSeenAt == wallNow(), "valeurs illisibles remises à 0 (puis LastSeenAt = maintenant)")
check(logHas("migration v6 : Offline.LastSeenAt illisible (hier) : remis à 0", "WARN", "server") and logHas("migration v6 : Offline.Income illisible (inf) : remis à 0", "WARN", "server"), "une ligne orange par valeur")
check(#creditsOf(cid) == 0, "aucun gain")
leave(cid)

alignSecond()
local r = newProfile(5)
r.Offline = { LastSeenAt = wallNow() - 50, Income = 2 }
local dan = join("Dan", r)
check(#creditsOf(dan) == 1 and near(creditsOf(dan)[1].amount, 100), "Offline lisible déjà là avant la v6 : gardé (50 s × 2 $/s = 100 $)")
leave(dan)

section("vieux profil et profil neuf")
local old = newProfile(3)
alignSecond()
local eve = join("Eve", old)
check(dataOf(eve).Version == PV and type(dataOf(eve).Index) == "table" and dataOf(eve).BoxQueue == nil and dataOf(eve).Offline.LastSeenAt == wallNow(), "profil v3 : v4, v5 puis v6")
check(#creditsOf(eve) == 0, "aucun gain")
leave(eve)
alignSecond()
local fresh = join("Fay", nil)
check(dataOf(fresh).Version == PV and dataOf(fresh).Offline.LastSeenAt == wallNow() and dataOf(fresh).Offline.Income == 0, "profil neuf : v6, heure posée, revenu 0")
check(#creditsOf(fresh) == 0, "profil neuf : aucun gain")

summary("scénario migration")
