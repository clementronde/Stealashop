--!nocheck
-- Scénario « limit » : la limite de Roblox de 31 Highlight affichés à la fois, à 5 joueurs. 40 colis
-- de la map portent un OutlineHighlight : ShelfBoxController (vrai) n'en garde que 25. Quatre
-- voleurs chez Ada en même temps : chacun porte le contour StolenOutline de CarryService ; les 3
-- plus récents sont surlignés par le client d'Ada, qui coupe leur StolenOutline : le compte des
-- Highlight allumés ne bouge pas (25 + 4 = 29 ≤ 31, au lieu de 32 en les ajoutant). Une réannonce
-- change les 3 plus récents : le contour du voleur sorti du lot se rallume.

startServer()

local ada = join("Ada", victimProfile())
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local dan = join("Dan", newProfile())
local eve = join("Eve", newProfile())
-- 40 colis à portée de la caméra, chacun avec le contour noir de Clément (L-031).
local boxes = folder(MAP, "Boxes")
for i = 1, 40 do
	local box = make("Model", { Name = "BOX_Standard" }, boxes)
	local part = make("Part", { Name = "Body", Anchored = true, CFrame = CFrame.new(-60 + i, 1, 30), Size = Vector3.new(1, 1, 1) }, box)
	box.PrimaryPart = part
	make("Highlight", { Name = "OutlineHighlight" }, box)
end
lookFrom(Vector3.new(-40, 10, 40), Vector3.new(-40, 0, 0))
startClient(ada)
advance(1)
local adaShop = shopOf(ada)

local function report(label)
	local counts = highlightCounts()
	local boxesOn = named(counts, "OutlineHighlight").enabled
	local stolenOn = named(counts, "StolenOutline").enabled
	local glowsOn = named(counts, "TheftAlertHighlight").enabled
	return counts.enabled, boxesOn, stolenOn, glowsOn
end

section("au repos")
local total, boxesOn = report()
check(boxesOn == 25 and total == 25, `25 contours de colis allumés sur 40 (ShelfBoxController ; trouvé {boxesOn}, {total} en tout)`)

section("quatre voleurs en même temps")
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
check(steal(cy, adaShop, 2), "Cy prend le Paquet de chips")
check(steal(dan, adaShop, 4), "Dan prend le Donut")
check(steal(eve, adaShop, 5), "Eve prend la Banane")
advance(0.3)
local stolenOn, glowsOn
total, boxesOn, stolenOn, glowsOn = report()
local s = state()
check(s.Active and s.Thefts == 4 and s.Thief == eve, "4 vols ; Eve, la dernière, est affichée")
check(glowsOn == 3 and s.Highlights == 3, `3 voleurs surlignés au plus (trouvé {glowsOn})`)
check(alertHighlightOf(eve) and alertHighlightOf(dan) and alertHighlightOf(cy) and alertHighlightOf(bob) == nil, "les 3 plus récents : Eve, Dan, Cy ; pas Bob, le plus ancien")
check(stolenOutlineOf(bob).Enabled == true, "le StolenOutline de Bob reste allumé")
check(stolenOutlineOf(cy).Enabled == false and stolenOutlineOf(dan).Enabled == false and stolenOutlineOf(eve).Enabled == false, "ceux de Cy, Dan et Eve sont coupés")
check(stolenOn == 1, `un seul StolenOutline allumé (trouvé {stolenOn})`)
check(boxesOn == 25, "toujours 25 contours de colis")
check(total == 29, `29 Highlight allumés : 25 colis + 4 voleurs, comme sans l'alerte (trouvé {total})`)
check(total <= 31, "sous la limite de 31")

section("réannonce : les 3 plus récents changent")
-- Le serveur réannonce Bob (comme après la fin d'un autre vol) : Bob devient le plus récent.
NetServer.Server.TheftAlert:Fire(ada, true, bob, "Z1_CanetteDeSoda")
frame()
total, boxesOn, stolenOn, glowsOn = report()
check(state().Thief == bob, "Bob, réannoncé, est affiché")
check(alertHighlightOf(bob) and alertHighlightOf(eve) and alertHighlightOf(dan) and alertHighlightOf(cy) == nil, "surlignés : Bob, Eve, Dan ; plus Cy")
check(stolenOutlineOf(cy).Enabled == true and stolenOutlineOf(bob).Enabled == false, "le StolenOutline de Cy se rallume, celui de Bob se coupe")
check(total == 29 and glowsOn == 3 and stolenOn == 1, `toujours 29 Highlight allumés (trouvé {total})`)

section("un voleur meurt")
kill(eve)
flush()
advance(0.3)
total, boxesOn, stolenOn, glowsOn = report()
check(state().Thefts == 3 and alertHighlightOf(eve) == nil, "Eve meurt : 3 vols, sa surbrillance part")
check(glowsOn == 3 and stolenOn == 0, `les 3 voleurs restants sont surlignés, aucun StolenOutline allumé (trouvé {glowsOn}, {stolenOn})`)
check(total == 28, `28 Highlight allumés : 25 + 3 (trouvé {total})`)

section("fin")
for _, thief in { bob, cy, dan } do
	CarryService.Fail(thief, "Bat")
	-- a112 (vague 33) : resté dans la boutique, il serait un intrus (alerte d'intrusion) : il sort.
	moveTo(thief, HUB_CENTER)
end
flush()
advance(0.3)
total, boxesOn, stolenOn, glowsOn = report()
check(not state().Active and glowsOn == 0 and stolenOn == 0, "plus aucun vol : ni surbrillance ni contour")
check(total == 25, `25 Highlight allumés, ceux des colis (trouvé {total})`)
local counts = highlightCounts()
check(named(counts, "TheftAlertHighlight").total == 0, "les surbrillances sont détruites, pas seulement éteintes")
check(not logHas("[TheftAlertController]", "WARN"), "aucune erreur du contrôleur")

if VERBOSE then
	dumpLog()
end
summary("scénario limit")
