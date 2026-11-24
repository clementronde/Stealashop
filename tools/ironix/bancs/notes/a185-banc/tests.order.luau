--!nocheck
-- Scénario « order » (a185, L-174) : parcelle libre au plus petit AssignOrder ; sans lui, ordre des PlotIndex.
startSkills()
local function plotName(player)
	local plot = shopOf(player)
	return if plot then plot.Name else "aucune"
end
local P1, P2, P3 = SHOPS[1].model, SHOPS[2].model, SHOPS[3].model

section("avec AssignOrder : 3 en face (1), puis 1 (2), puis 2 (3)")
P3:SetAttribute("AssignOrder", 1)
P1:SetAttribute("AssignOrder", 2)
P2:SetAttribute("AssignOrder", 3)
local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
check(shopOf(ada) == P3, `Ada (1re) : PLOT_Shop_03 (trouvé {plotName(ada)})`)
check(shopOf(bob) == P1, `Bob (2e) : PLOT_Shop_01 (trouvé {plotName(bob)})`)
leave(ada)
advance(0.3)
local cy = join("Cy", newProfile())
check(shopOf(cy) == P3, `Cy après le départ d'Ada : la place d'en face reprise (trouvé {plotName(cy)})`)
leave(bob)
leave(cy)
advance(0.3)

section("bot : la dernière dans l'ordre d'attribution")
local botPlot = PlotService.ReserveForBot("Bot")
check(botPlot == P2, `bot sur PLOT_Shop_02 (AssignOrder 3) (trouvé {botPlot and botPlot.Name})`)
local dan = join("Dan", newProfile())
check(shopOf(dan) == P3, `Dan avec le bot là : PLOT_Shop_03 (trouvé {plotName(dan)})`)
if botPlot then
	PlotService.ReleaseBot(botPlot)
end
leave(dan)
advance(0.3)

section("AssignOrder partiel ou invalide : ceux sans lui après, dans l'ordre des PlotIndex")
P3:SetAttribute("AssignOrder", nil)
P1:SetAttribute("AssignOrder", "x")
P2:SetAttribute("AssignOrder", 5)
local eve = join("Eve", newProfile())
local fay = join("Fay", newProfile())
local gus = join("Gus", newProfile())
check(shopOf(eve) == P2, `Eve : PLOT_Shop_02, seule avec un AssignOrder valide (trouvé {plotName(eve)})`)
check(shopOf(fay) == P1, `Fay : PLOT_Shop_01 (« x » ignoré, PlotIndex 1) (trouvé {plotName(fay)})`)
check(shopOf(gus) == P3, `Gus : PLOT_Shop_03 (trouvé {plotName(gus)})`)
leave(eve)
leave(fay)
leave(gus)
advance(0.3)

section("sans AssignOrder : l'ordre d'avant (PlotIndex)")
P1:SetAttribute("AssignOrder", nil)
P2:SetAttribute("AssignOrder", nil)
local hal = join("Hal", newProfile())
local ivy = join("Ivy", newProfile())
check(shopOf(hal) == P1, `Hal : PLOT_Shop_01 (trouvé {plotName(hal)})`)
check(shopOf(ivy) == P2, `Ivy : PLOT_Shop_02 (trouvé {plotName(ivy)})`)
local bot2 = PlotService.ReserveForBot("Bot")
check(bot2 == P3, `bot sur la dernière, PLOT_Shop_03 (trouvé {bot2 and bot2.Name})`)

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
summary("scénario order")
