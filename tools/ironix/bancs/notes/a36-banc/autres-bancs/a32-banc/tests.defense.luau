--!nocheck
-- Scénario « defense » (vrai BatService) : Lifetime.Defenses + 1 quand la victime frappe son voleur
-- à la batte (usage « Defend »), et seulement là : ni le coup d'un tiers sur le voleur (usage
-- « Thief »), ni le coup sur un porteur de colis PNJ (usage « Box »), ni un coup dans le vide. Le coup
-- finit l'alerte et l'Adrénaline. Profil abîmé : signalé, rien de cassé.

startServer()

local adaData = victimProfile()
local ada = join("Ada", adaData)
local bobData = newProfile()
local bob = join("Bob", bobData)
local cyData = newProfile()
local cy = join("Cy", cyData)
local danData = newProfile()
local dan = join("Dan", danData)
for _, player in { ada, bob, cy, dan } do
	giveBat(player)
end
startClient(ada)
advance(1.2)
local adaShop = shopOf(ada)
local hits = {}
BatService.OnHit(function(hitter, target, usage)
	table.insert(hits, { hitter = hitter, target = target, usage = usage })
end)

local function defenses()
	return adaData.Lifetime.Defenses, bobData.Lifetime.Defenses, cyData.Lifetime.Defenses, danData.Lifetime.Defenses
end

section("défense réussie (usage 1)")
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
frame()
check(state().Active and holdsBat(ada), "Ada : alerte affichée, batte en main (BatController)")
check(near(walkSpeed(ada), 20), "Ada : Adrénaline")
-- Ada se place à 4 studs derrière Bob, face à lui, dans sa boutique.
local bobPos = rootOf(bob).Position
moveTo(ada, bobPos + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
fireAs(ada, "SwingBat")
flush()
check(#hits == 1 and hits[1].hitter == ada and hits[1].target == bob and hits[1].usage == "Defend", "BatService : coup « Defend » d'Ada sur Bob")
check(not CarryService.IsCarrying(bob) and adaData.Display["1"] == "v-soda", "Bob lâche l'objet : il revient sur son présentoir")
local a, b, c, d = defenses()
check(a == 1, `Lifetime.Defenses d'Ada : 1 (trouvé {a})`)
check(b == 0 and c == 0 and d == 0, "personne d'autre n'a de défense comptée")
check(near(walkSpeed(ada), 16), "le coup finit le vol : plus d'Adrénaline")
frame()
check(not state().Active and state().Highlights == 0, "alerte finie")
check(logHas("Ada frappe son voleur Bob : défense réussie (1 en tout)", "PRINT", "server"), "sortie : défense comptée")
check(adaData.Lifetime.Steals == 0 and bobData.Lifetime.Steals == 0 and adaData.Lifetime.Heists == 0, "les autres compteurs ne bougent pas")

section("coup d'un tiers sur le voleur (usage « Thief »)")
advance(3.1) -- immunité de 3 s de Bob après le coup (6.4)
check(steal(bob, adaShop, 2), "toujours dans les 10 s : Bob reprend le Paquet de chips")
-- Hors de la zone safe (x > 300), Cy frappe Bob par-derrière.
moveTo(bob, Vector3.new(400, 3, 0), Vector3.new(0, 0, -1))
moveTo(cy, Vector3.new(400, 3, 4), Vector3.new(0, 0, -1))
humanoidOf(cy):EquipTool(batOf(cy))
fireAs(cy, "SwingBat")
flush()
check(#hits == 2 and hits[2].hitter == cy and hits[2].usage == "Thief", "BatService : coup « Thief » de Cy sur Bob")
check(not CarryService.IsCarrying(bob) and adaData.Display["2"] == "v-chips", "l'objet revient chez Ada")
a, b, c, d = defenses()
check(a == 1 and c == 0, `un tiers qui frappe le voleur : aucune défense comptée (Ada {a}, Cy {c})`)

section("coup sur un porteur de colis PNJ (usage « Box »)")
local box = { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_Banane", StoreId = "STORE_Z1_Superette", SlotId = "Slot_1" }
moveTo(dan, Vector3.new(420, 3, 0), Vector3.new(0, 0, -1))
check(CarryService.StartCarry(dan, box), "Dan porte un colis PNJ hors de la zone safe")
advance(0.9) -- recharge de la batte de Cy (0,8 s)
moveTo(cy, Vector3.new(420, 3, 4), Vector3.new(0, 0, -1))
fireAs(cy, "SwingBat")
flush()
check(#hits == 3 and hits[3].usage == "Box", "BatService : coup « Box » de Cy sur Dan")
a, b, c, d = defenses()
check(a == 1 and c == 0 and d == 0, "colis PNJ tombé : aucune défense comptée")

section("coup dans le vide")
advance(0.9)
moveTo(cy, Vector3.new(500, 3, 0), Vector3.new(0, 0, -1))
fireAs(cy, "SwingBat")
flush()
check(#hits == 3, "personne à portée : aucun coup")
a, b, c, d = defenses()
check(a == 1 and c == 0, "rien de compté")

section("profil abîmé")
-- Porte refaite (30 s), recassée : un nouveau vol, et le Lifetime d'Ada illisible.
check(breakDoor(bob, adaShop), "porte d'Ada recassée par Bob")
check(steal(bob, adaShop, 4), "Bob prend le Donut")
frame()
adaData.Lifetime.Defenses = "abîmé"
bobPos = rootOf(bob).Position
moveTo(ada, bobPos + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
if not holdsBat(ada) then
	humanoidOf(ada):EquipTool(batOf(ada))
end
clearLog()
fireAs(ada, "SwingBat")
flush()
check(#hits == 4 and hits[4].usage == "Defend", "nouvelle défense d'Ada")
check(adaData.Lifetime.Defenses == 1, `Lifetime.Defenses illisible : repart de 0, donc 1 (trouvé {adaData.Lifetime.Defenses})`)
check(logHas("Lifetime.Defenses illisible", "WARN", "server"), "signalé dans la sortie")
advance(3.1)
check(steal(bob, adaShop, 5), "Bob prend la Banane")
local saved = adaData.Lifetime
adaData.Lifetime = nil
bobPos = rootOf(bob).Position
moveTo(ada, bobPos + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
advance(0.9)
clearLog()
fireAs(ada, "SwingBat")
flush()
check(#hits == 5 and hits[5].usage == "Defend", "encore une défense")
check(logHas("Lifetime absent du profil, défense non comptée", "WARN", "server"), "Lifetime absent : signalé, défense non comptée")
check(not CarryService.IsCarrying(bob) and adaData.Display["5"] == "v-banana", "le coup fait quand même son effet")
adaData.Lifetime = saved
check(not logHas("tick :", "WARN") and not logHas("ERREUR"), "aucune erreur dans les boucles")

if VERBOSE then
	dumpLog()
end
summary("scénario defense")
