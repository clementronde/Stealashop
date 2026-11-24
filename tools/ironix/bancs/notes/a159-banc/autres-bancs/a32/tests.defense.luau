--!nocheck
-- Copie d'a99 (2026-11-12) : défense par le propriétaire (Bob sorti, 60 s sans voler Ada) ; tiers et colis par Bob, profil abîmé par Cy puis Dan.
-- Copie a151 (vague 43, 2026-11-14) : la porte se répare dès que l'intrus éjecté était le dernier ; Cy puis Dan la recassent avant de voler.
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
advance(0.15) -- copie a159 : un tour de PvPService (intrus retiré)
check(not state().Active and state().Highlights == 0, "alerte finie")
check(logHas("Ada frappe son voleur Bob : défense réussie (1 en tout)", "PRINT", "server"), "sortie : défense comptée")
check(adaData.Lifetime.Steals == 0 and bobData.Lifetime.Steals == 0 and adaData.Lifetime.Heists == 0, "les autres compteurs ne bougent pas")

-- Dans le volume Bounds de la boutique `plot` ?
local function inShop(player, plot)
	local bounds = plot:FindFirstChild("Bounds", true)
	local p = bounds.CFrame:PointToObjectSpace(rootOf(player).Position)
	local h = bounds.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
-- a99 (Cantin, 2026-11-12) : le voleur frappé par le propriétaire est sorti et ne peut plus voler cette
-- boutique pendant 60 s.
check(not inShop(bob, adaShop), "a99 : Bob est sorti de la boutique d'Ada")
check(PvPService.GetRobCooldown(bob, adaShop) > 55, `a99 : Bob ne peut plus voler Ada (reste {PvPService.GetRobCooldown(bob, adaShop)} s)`)
check(#notifies(bob, "Kicked out! You can rob this shop again in 60s.") == 1, "a99 : Notify « Kicked out! » à Bob")
check(#notifies(ada, "Bob was kicked out of your shop!") == 1, "a99 : retour à Ada")
-- a151 (vague 43) : Bob était le seul intrus : la porte d'Ada se répare tout de suite, PV max, vol fermé.
flush()
check(not WindowService.IsBroken(windowIdOf(adaShop)), "a151 : dernier intrus éjecté : porte d'Ada réparée tout de suite")
check(adaShop:GetAttribute("StealOpen") == nil, "a151 : la fenêtre de vol se ferme")
advance(3.1) -- immunité de 3 s de Bob après le coup (6.4)
check(not steal(bob, adaShop, 2), "a99 : Bob ne reprend rien")
check(#notifies(bob, "You can rob this shop again in") >= 1, "a99 : refus expliqué à Bob")

section("coup d'un tiers sur le voleur (usage « Thief »)")
check(breakDoor(cy, adaShop), "a151 : porte réparée, Cy la recasse")
check(steal(cy, adaShop, 2), "Cy prend le Paquet de chips")
-- Hors de la zone safe (x > 300), Bob frappe Cy par-derrière.
moveTo(cy, Vector3.new(400, 3, 0), Vector3.new(0, 0, -1))
moveTo(bob, Vector3.new(400, 3, 4), Vector3.new(0, 0, -1))
humanoidOf(bob):EquipTool(batOf(bob))
fireAs(bob, "SwingBat")
flush()
check(#hits == 2 and hits[2].hitter == bob and hits[2].usage == "Thief", "BatService : coup « Thief » de Bob sur Cy")
check(not CarryService.IsCarrying(cy) and adaData.Display["2"] == "v-chips", "l'objet revient chez Ada")
a, b, c, d = defenses()
check(a == 1 and b == 0, `un tiers qui frappe le voleur : aucune défense comptée (Ada {a}, Bob {b})`)
check(PvPService.GetRobCooldown(cy, adaShop) == 0, "a99 : le coup d'un tiers n'interdit rien à Cy")

section("coup sur un porteur de colis PNJ (usage « Box »)")
local box = { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_Banane", StoreId = "STORE_Z1_Superette", SlotId = "Slot_1" }
moveTo(dan, Vector3.new(420, 3, 0), Vector3.new(0, 0, -1))
check(CarryService.StartCarry(dan, box), "Dan porte un colis PNJ hors de la zone safe")
advance(0.9) -- recharge de la batte de Bob (0,8 s)
moveTo(bob, Vector3.new(420, 3, 4), Vector3.new(0, 0, -1))
fireAs(bob, "SwingBat")
flush()
check(#hits == 3 and hits[3].usage == "Box", "BatService : coup « Box » de Bob sur Dan")
a, b, c, d = defenses()
check(a == 1 and b == 0 and d == 0, "colis PNJ tombé : aucune défense comptée")

section("coup dans le vide")
advance(0.9)
moveTo(bob, Vector3.new(500, 3, 0), Vector3.new(0, 0, -1))
fireAs(bob, "SwingBat")
flush()
check(#hits == 3, "personne à portée : aucun coup")
a, b, c, d = defenses()
check(a == 1 and b == 0, "rien de compté")

section("profil abîmé")
-- Porte refaite (30 s), recassée : un nouveau vol (Cy : Bob est encore interdit chez Ada), et le Lifetime
-- d'Ada illisible.
advance(3.1) -- Cy n'est plus étourdi
check(breakDoor(cy, adaShop), "porte d'Ada recassée par Cy")
check(steal(cy, adaShop, 4), "Cy prend le Donut")
frame()
adaData.Lifetime.Defenses = "abîmé"
local cyPos = rootOf(cy).Position
moveTo(ada, cyPos + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
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
check(not WindowService.IsBroken(windowIdOf(adaShop)), "a151 : Cy éjecté, dernier intrus : porte réparée")
check(breakDoor(dan, adaShop), "a151 : Dan recasse la porte")
check(steal(dan, adaShop, 5), "Dan prend la Banane")
local saved = adaData.Lifetime
adaData.Lifetime = nil
local danPos = rootOf(dan).Position
moveTo(ada, danPos + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
advance(0.9)
clearLog()
fireAs(ada, "SwingBat")
flush()
check(#hits == 5 and hits[5].usage == "Defend", "encore une défense")
check(logHas("Lifetime absent du profil, défense non comptée", "WARN", "server"), "Lifetime absent : signalé, défense non comptée")
check(not CarryService.IsCarrying(dan) and adaData.Display["5"] == "v-banana", "le coup fait quand même son effet")
adaData.Lifetime = saved
check(not logHas("tick :", "WARN") and not logHas("ERREUR"), "aucune erreur dans les boucles")

if VERBOSE then
	dumpLog()
end
summary("scénario defense")
