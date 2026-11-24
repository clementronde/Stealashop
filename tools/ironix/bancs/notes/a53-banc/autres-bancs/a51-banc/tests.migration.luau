--!nocheck
-- Copie d'a53 (DEV-101) : v8 quand Types/Profile a Rewards (récompenses), v7 sinon.
PV = if string.find(SOURCES["shared/Types/Profile.luau"] or "", "Rewards: Rewards", 1, true) then 8 else 7
-- Scénario « migration » (profil v7, DataService MIGRATIONS[7]) : v6 → v7 sans perte (colis des
-- présentoirs dans l'ordre de leur numéro, puis la file, sous des uid neufs, dans l'inventaire, contenu
-- et heure promise gardés, BoxQueue retiré), un colis illisible gardé tel quel, v4 → v7 en une fois
-- (établis → présentoirs → inventaire), profil v8 refusé (TooNew), sauvegarde et retour.

advance(1000)
startServer()

section("v6 → v7")
local data = newProfile(6)
data.Boxes["7"] = { Tier = "Premium", Zone = 3, ItemId = "Z3_Smartphone", Rarity = "Rare", ReadyAt = 4000 }
data.Boxes["2"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 9999, Mutation = { Size = "Big" } }
data.BoxQueue = {
	{ Tier = "Luxe", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 1234 },
	"abîmé",
}
addItem(data, "it1", "Z1_Donut", 1, 1, 5)
local ada = join("Ada", data)
advance(1.5)
local d = dataOf(ada)
check(d.Version == PV and d.BoxQueue == nil, "profil en v7, BoxQueue retiré")
check(countKeys(d.Boxes) == 4, `4 colis dans Boxes (2 présentoirs, 2 dans la file) : {countKeys(d.Boxes)}`)
local byItem = {}
local unreadable = 0
for uid, box in d.Boxes do
	check(type(uid) == "string" and #uid >= 32 and tonumber(uid) == nil, `uid neuf ({uid})`)
	if type(box) == "table" then
		byItem[box.ItemId .. ":" .. tostring(box.ReadyAt)] = box
		check(box.Spot == nil and type(box.At) == "number", `{box.ItemId} : dans l'inventaire (Spot absent), At posé`)
	else
		unreadable += 1
	end
end
local rare = byItem["Z3_Smartphone:4000"]
local banana = byItem["Z1_Banane:9999"]
local donut = byItem["Z1_Donut:1234"]
check(rare and rare.Tier == "Premium" and rare.Zone == 3 and rare.Rarity == "Rare", "colis du présentoir 7 : contenu et heure promise gardés")
check(banana and banana.Mutation and banana.Mutation.Size == "Big", "colis du présentoir 2 : mutation gardée")
check(donut and donut.Tier == "Luxe", "colis de la file : gardé")
check(unreadable == 1, "colis illisible de la file : gardé tel quel")
check(logHas("migration v7 : 4 colis rangé(s) dans l'inventaire") and logHas("illisible", "WARN"), "sortie : la migration et le colis illisible")
check(d.Items.it1 ~= nil and d.Display["1"] == "it1", "objets et présentoirs inchangés")
-- La barre : 3 colis lisibles (l'illisible n'a pas de Tool), dans l'ordre présentoirs puis file (At égal :
-- l'ordre des uid).
local tools = toolsOf(ada)
local boxTools = 0
for key in tools do
	if string.sub(key, 1, 4) == "Box:" then
		boxTools += 1
	end
end
check(boxTools == 3, `3 Tools de colis (l'illisible n'en a pas) : {boxTools}`)

section("v4 → v7 en une fois : établis → présentoirs → inventaire")
local old = newProfile(4)
old.Boxes["1"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 4500 }
old.Boxes["3"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 4600 }
local bob = join("Bob", old)
advance(1.5)
local db = dataOf(bob)
check(db.Version == PV and db.BoxQueue == nil and countKeys(db.Boxes) == 2, "v4 → v7 : 2 colis dans l'inventaire")
local ok = true
for uid, box in db.Boxes do
	ok = ok and tonumber(uid) == nil and box.Spot == nil and (box.ReadyAt == 4500 or box.ReadyAt == 4600)
end
check(ok, "uid neufs, heures promises gardées")
check(db.Offline ~= nil and db.Index ~= nil, "Offline (v6) et Index (v4) complétés")

section("profils abîmés (repris d'a46) : rien n'est perdu")
local broken = newProfile(4)
broken.Boxes = 42
local bo = join("Bo", broken)
advance(1.5)
local dbo = dataOf(bo)
local only = select(2, next(dbo.Boxes))
check(dbo.Version == PV and countKeys(dbo.Boxes) == 1 and only == 42 and dbo.BoxQueue == nil, "Boxes qui n'est pas une table (v4) : gardé tel quel sous un uid (v5 : dans la file ; v7 : dans Boxes)")
local bad = newProfile(4)
bad.Upgrades.DisplaySlots = 2
bad.Boxes["2"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 1 }
bad.Boxes.bad = "pas un colis"
local be = join("Be", bad)
advance(1.5)
local dbe = dataOf(be)
local kept, readable = 0, 0
for _, box in dbe.Boxes do
	if box == "pas un colis" then
		kept += 1
	elseif type(box) == "table" and box.ReadyAt == 1 then
		readable += 1
	end
end
check(kept == 1 and readable == 1 and countKeys(dbe.Boxes) == 2, "colis illisible d'un établi « bad » et colis lisible : les deux gardés")
check(countKeys(toolsOf(be)) == 1, "un seul Tool : le colis lisible")

section("profil neuf et profil v8 (serveur pas à jour)")
local cy = join("Cy", nil)
advance(1.5)
check(dataOf(cy).Version == PV and next(dataOf(cy).Boxes) == nil and dataOf(cy).BoxQueue == nil, "profil neuf : v7, Boxes vide, pas de BoxQueue")
local future = newProfile(6)
future.Version = PV + 1
local di = join("Di", future)
advance(1.5)
check(dataOf(di) == nil and #KICKS >= 1 and string.find(KICKS[#KICKS].message, "just updated", 1, true) ~= nil, `profil v{PV + 1} : refusé (TooNew), joueur expulsé`)

section("sauvegarde : v7 écrit, colis gardés")
local userId = ada.UserId
local count = countKeys(dataOf(ada).Boxes)
leave(ada)
advance(2)
local saved = SAVED["Player_" .. userId]
check(saved and saved.Version == PV and countKeys(saved.Boxes) == count and saved.BoxQueue == nil, "sauvegardé en v7 avec ses colis")
local ada2 = join("Ada", nil, userId)
advance(1.5)
check(dataOf(ada2).Version == PV and countKeys(dataOf(ada2).Boxes) == count, "retour : rien ne migre deux fois, rien ne se perd")

summary("scénario migration")
