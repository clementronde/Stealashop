--!nocheck
-- Scénario « refused » (9.4 : chaque remote validé par le serveur) : PlaceItemAuto(itemUid) et
-- UnplaceItem(itemUid) envoyés à la main. Refusés sans effet : uid d'un autre joueur ou inconnu, objet au
-- coffre-fort, déjà exposé (PlaceItemAuto) ou pas exposé (UnplaceItem), arguments mal formés, débit
-- dépassé ; avec un Notify : objet tenu par un voleur, tous les présentoirs pris, inventaire plein
-- (UnplaceItem), pas de boutique. Rien ne sort du profil : ni objet en double, ni objet perdu.

advance(1000)
startServer()

local function snapshot(player)
	local d = dataOf(player)
	local display = {}
	for k, v in d.Display do
		display[k] = v
	end
	return { items = countKeys(d.Items), display = display }
end
local function sameDisplay(a, b)
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	for k, v in b do
		if a[k] ~= v then
			return false
		end
	end
	return true
end

local data = newProfile()
addItem(data, "mine", "Z1_Banane", nil, 1, 1)
addItem(data, "shown", "Z1_Donut", 1, 1, 2)
addItem(data, "safe", "Z1_Banane", nil, 1, 3)
data.Vault["1"] = "safe"
local ada = join("Ada", data)
local bobData = newProfile()
addItem(bobData, "bobs", "Z3_Smartphone", nil, 3, 1)
addItem(bobData, "bobshown", "Z3_Smartphone", 1, 3, 2)
local bob = join("Bob", bobData)
advance(1.5)

section("uid d'un autre, inconnu, au coffre-fort, déjà exposé : sans effet")
local before = snapshot(ada)
local bobBefore = snapshot(bob)
local notes = #notifies(ada)
fireAs(ada, "PlaceItemAuto", "bobs")
advance(0.3)
fireAs(ada, "PlaceItemAuto", "pas-un-objet")
advance(0.3)
fireAs(ada, "PlaceItemAuto", "safe")
advance(0.3)
fireAs(ada, "PlaceItemAuto", "shown")
flush()
check(sameDisplay(before.display, snapshot(ada).display) and sameDisplay(bobBefore.display, snapshot(bob).display), "aucun présentoir ne change, ni chez Ada ni chez Bob")
check(dataOf(ada).Items.bobs == nil and dataOf(bob).Items.bobs ~= nil and dataOf(ada).Vault["1"] == "safe", "rien ne change de profil, le coffre-fort garde son objet")
check(#notifies(ada) == notes, "envois malhonnêtes : aucun message")
check(logHas("PlaceItemAuto(bobs) refusé : objet absent de son profil") and logHas("PlaceItemAuto(safe) refusé : au coffre-fort"), "une ligne en Studio pour chaque refus")
advance(0.3)
fireAs(ada, "UnplaceItem", "bobshown")
advance(0.3)
fireAs(ada, "UnplaceItem", "mine") -- pas exposé
flush()
check(dataOf(bob).Display["1"] == "bobshown" and dataOf(ada).Display["1"] == "shown" and #notifies(ada) == notes, "UnplaceItem : l'objet exposé d'un autre ou un objet pas exposé ne bougent pas")

section("arguments mal formés et débit")
local calls = 0
fireAs(ada, "PlaceItemAuto", 12)
fireAs(ada, "PlaceItemAuto", string.rep("x", 65))
fireAs(ada, "UnplaceItem", nil)
flush()
check(sameDisplay(before.display, snapshot(ada).display), "nombre, uid trop long, argument absent : refusés par Net")
advance(1.1)
for _ = 1, 10 do
	fireAs(ada, "UnplaceItem", "shown")
end
flush()
check(dataOf(ada).Display["1"] == nil and dataOf(ada).Items.shown ~= nil and #notifies(ada, "removed from its display") == 1, "10 envois d'affilée : un seul retrait (débit et état revérifié)")
advance(1.1)
for _ = 1, 10 do
	fireAs(ada, "PlaceItemAuto", "shown")
end
flush()
local placedCount = 0
for _, uid in dataOf(ada).Display do
	if uid == "shown" then
		placedCount += 1
	end
end
check(placedCount == 1 and #notifies(ada, "placed on a display!") == 1, "10 envois d'affilée : posé une seule fois, jamais en double")

section("objet tenu par un voleur : refusé avec un message")
local slot = DisplayService.Hold(ada, "shown")
check(slot ~= nil, "l'objet exposé est tenu par un voleur")
advance(1.1)
fireAs(ada, "UnplaceItem", "shown")
flush()
check(dataOf(ada).Display[tostring(slot)] == "shown" and #notifies(ada, "being stolen") == 1, "UnplaceItem : « This item is being stolen… », il reste où il est")
DisplayService.Release(ada, "shown")

section("tous les présentoirs pris")
local full = newProfile()
for i = 1, 4 do
	addItem(full, `d{i}`, "Z1_Banane", i, 1, i)
end
addItem(full, "spare", "Z1_Banane", nil, 1, 9)
local cy = join("Cy", full)
advance(1.5)
fireAs(cy, "PlaceItemAuto", "spare")
flush()
check(invItem(cy, "spare").Slot == nil and #notifies(cy, "All your displays are full!") == 1, "« All your displays are full! », l'objet reste dans l'inventaire")

section("inventaire plein : UnplaceItem refusé")
local packed = newProfile()
for i = 1, Balance.Display.InventoryMax do
	addItem(packed, `s{i}`, "Z1_Banane", nil, 1, i)
end
addItem(packed, "top", "Z1_Donut", 1, 1, 99)
local dee = join("Dee", packed)
advance(1.5)
fireAs(dee, "UnplaceItem", "top")
flush()
check(dataOf(dee).Display["1"] == "top" and #notifies(dee, "Your inventory is full") == 1, `{Balance.Display.InventoryMax} objets dans l'inventaire : « Your inventory is full… », l'objet reste exposé`)

section("pas de boutique : refusé avec un message")
local extras = {}
for i = 1, 3 do
	table.insert(extras, join(`P{i}`, nil))
end
local noShop = newProfile()
addItem(noShop, "lonely", "Z1_Banane", nil, 1, 1)
local eve = join("Eve", noShop)
advance(1.5)
check(shopOf(eve) == nil, "7e joueur : pas de boutique libre")
fireAs(eve, "PlaceItemAuto", "lonely")
flush()
check(next(dataOf(eve).Display) == nil and #notifies(eve, "You don't have a shop yet") == 1, "« You don't have a shop yet… »")

section("rien n'a été créé ni perdu")
check(countKeys(dataOf(ada).Items) == before.items and countKeys(dataOf(bob).Items) == bobBefore.items, "Ada et Bob gardent le même nombre d'objets")

summary("scénario refused")
