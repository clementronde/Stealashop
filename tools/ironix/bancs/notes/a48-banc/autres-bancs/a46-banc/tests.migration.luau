--!nocheck
-- Copie d'a48 (DEV-102) : version attendue PROFILE_V = 6 quand Types/Profile a Offline (gains hors ligne), 5 sinon.
PROFILE_V = if string.find(SOURCES["shared/Types/Profile.luau"] or "", "Offline: Offline", 1, true) then 6 else 5
-- Scénario « migration » (L-086) : profil v4 → v5. Les colis en attente sur les établis vont, dans
-- l'ordre des établis, sur le premier présentoir débloqué et libre ; sans place, dans BoxQueue, puis
-- sur le premier présentoir qui se libère. Aucun colis perdu (ReadyAt et contenu gardés), profils
-- abîmés, vieux profils (v3), profil neuf, sauvegarde.

advance(1000)
startServer()

section("v4 → v5 : établis → présentoirs, le reste dans la file")
local now0 = serverTime()
local data = newProfile(4)
addItem(data, "a", "Z1_Donut", 1, 1, 500)
addItem(data, "c", "Z1_Donut", 3, 1, 500)
data.Boxes["1"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = now0 + 500 }
data.Boxes["2"] = { Tier = "Premium", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = now0 + 600 }
data.Boxes["4"] = { Tier = "Luxe", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = now0 + 700 }
data.Boxes["3"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = now0 + 800 }
local ada = join("Ada", data)
advance(1.5)
local d = dataOf(ada)
check(d.Version == PROFILE_V, "profil v4 : passé en v5")
check(d.Boxes["2"] ~= nil and d.Boxes["2"].ReadyAt == now0 + 500 and d.Boxes["2"].Tier == "Standard", "établi 1 → présentoir 2 (premier libre), ReadyAt gardé")
check(d.Boxes["4"] ~= nil and d.Boxes["4"].ReadyAt == now0 + 600 and d.Boxes["4"].Tier == "Premium", "établi 2 → présentoir 4")
check(d.Boxes["1"] == nil and d.Boxes["3"] == nil, "présentoirs 1 et 3 gardent leurs objets")
check(#d.BoxQueue == 2 and d.BoxQueue[1].ReadyAt == now0 + 800 and d.BoxQueue[2].ReadyAt == now0 + 700, "établis 3 puis 4 : dans la file, dans l'ordre des établis")
check(d.Display["1"] == "a" and d.Display["3"] == "c" and d.Items.a and d.Items.c, "objets et présentoirs inchangés")
check(d.Upgrades.UnboxBenches == 3, "Upgrades.UnboxBenches gardé (sans effet)")
check(logHas("Ada (Player_1) : migration v5 : colis de l'établi 1 posé sur le présentoir 2", "PRINT", "server"), "une ligne de migration par colis")
check(logHas("migration v5 : colis de l'établi 4 mis dans la file des colis à poser (aucun présentoir libre)", "WARN", "server"), "colis sans place : ligne orange")
local function standBox(player, slot)
	return shopOf(player):FindFirstChild(string.format("StandBox_%02d", slot))
end
check(standBox(ada, 2) ~= nil and standBox(ada, 4) ~= nil, "colis affichés sur les présentoirs 2 et 4")
DisplayService.Unplace(ada, "a")
advance(1.2)
check(d.Boxes["1"] ~= nil and d.Boxes["1"].ReadyAt == now0 + 800 and #d.BoxQueue == 1, "présentoir 1 libéré : le plus ancien de la file y est posé")
DisplayService.Unplace(ada, "c")
advance(1.2)
check(d.Boxes["3"] ~= nil and d.Boxes["3"].ReadyAt == now0 + 700 and #d.BoxQueue == 0, "présentoir 3 libéré : le dernier de la file y est posé")
local total = 0
for _ in d.Boxes do
	total += 1
end
check(total == 4, "4 colis sur 4 présentoirs : aucun perdu")

section("sauvegarde v5 et retour")
leave(ada)
local saved = SAVED["Player_1"]
check(saved.Version == PROFILE_V and type(saved.BoxQueue) == "table" and #saved.BoxQueue == 0 and saved.Boxes["3"] ~= nil, "sauvegardé en v5")
clearLog()
local back = join("Ada", nil, 1)
advance(1.5)
check(not logHas("migration v", nil, "server"), "déjà en v5 : aucune migration au retour")
check(dataOf(back).Boxes["1"] ~= nil and standBox(back, 1) ~= nil, "colis remis sur leurs présentoirs")
leave(back)

section("présentoirs achetés, profils abîmés, vieux profil")
local p = newProfile(4)
p.Upgrades.DisplaySlots = 2 -- 6 présentoirs
for i = 1, 4 do
	addItem(p, `x{i}`, "Z1_Donut", i, 1)
end
p.Boxes["2"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 1 }
p.Boxes["1"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 2 }
p.Boxes["9"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 3 }
p.Boxes.bad = "pas un colis"
local bea = join("Bea", p)
advance(1.5)
local b = dataOf(bea)
check(b.Version == PROFILE_V and b.Boxes["5"] and b.Boxes["5"].ReadyAt == 2 and b.Boxes["6"] and b.Boxes["6"].ReadyAt == 1, "6 présentoirs débloqués : établis 1 et 2 → présentoirs 5 et 6")
check(#b.BoxQueue >= 1 and b.BoxQueue[1].ReadyAt == 3, "établi 9 : dans la file")
local foundBad = false
for _, entry in b.BoxQueue do
	if entry == "pas un colis" then
		foundBad = true
	end
end
check(foundBad and logHas("colis de l'établi bad mis dans la file des colis à poser (colis illisible)", "WARN", "server"), "colis illisible : gardé tel quel dans la file, ligne orange")
leave(bea)

local broken = newProfile(4)
broken.Boxes = 42
local cid = join("Cid", broken)
advance(1.5)
local c = dataOf(cid)
check(c.Version == PROFILE_V and type(c.Boxes) == "table" and next(c.Boxes) == nil and c.BoxQueue[1] == 42, "Boxes qui n'est pas une table : gardé dans la file")
check(logHas("Boxes n'est pas une table (42)", "WARN", "server"), "ligne orange")
leave(cid)

local old = newProfile(3)
old.Boxes["1"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 5 }
local dan = join("Dan", old)
advance(1.5)
check(dataOf(dan).Version == PROFILE_V and dataOf(dan).Boxes["1"] and dataOf(dan).Boxes["1"].ReadyAt == 5 and type(dataOf(dan).Index) == "table", "profil v3 : v4 puis v5, colis sur le présentoir 1")
leave(dan)

local fresh = join("Eve", nil)
advance(1.5)
check(dataOf(fresh).Version == PROFILE_V and #dataOf(fresh).BoxQueue == 0, "profil neuf : v5, file vide")

summary("scénario migration")
