--!nocheck
-- Scénario « reward » (a201, copie du scénario d'a191) : une zone complète ne donne qu'un objet (L-192), réclamé
-- une seule fois ; une zone réclamée avant reçoit l'objet une fois au chargement ; rien de versé n'est repris.
advance(1000)
startServer()
local function speedOf(player)
	return dataOf(player).Stats.Speed
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(Features.Index == true, "Features.Index = true (pre.on)")

section("zone complétée : un message, rien de donné")
local ada = join("Ada", profileWith({ 1 }, "Z1_Carotte"))
advance(1.5)
local cash0, speed0, gems0 = dataOf(ada).Cash, speedOf(ada), dataOf(ada).Diamonds
check(IndexService.Discover(ada, "Z1_Carotte"), "la Carotte complète la zone 1")
flush()
check(#notifies(ada, "Index: Zone 1 complete! Claim +WRENCH in the Index!") == 1, "Notify « Index: Zone 1 complete! Claim +WRENCH in the Index! »")
check(dataOf(ada).IndexRewards == nil and dataOf(ada).IndexGifts == nil and countOf(dataOf(ada).Tools.Owned, "Wrench") == 0, "rien de donné avant la réclamation")

section("réclamée (remote) : l'arme seule")
fireAs(ada, "ClaimIndexReward", 1)
flush()
local d = dataOf(ada)
check(d.Cash == cash0, `pas d'argent (trouvé +{d.Cash - cash0})`)
check(speedOf(ada) == speed0, `pas de Vitesse (trouvé +{speedOf(ada) - speed0})`)
check(d.Diamonds == gems0, "pas de diamants")
check(countOf(d.Tools.Owned, "Wrench") == 1 and d.Tools.Equipped == "Fists", "Wrench possédée, pas équipée")
check(d.IndexRewards ~= nil and type(d.IndexRewards["1"]) == "number" and d.IndexGifts ~= nil and type(d.IndexGifts["1"]) == "number", "IndexRewards et IndexGifts notés")
check(#indexTelemetry(ada) == 0, "aucune télémétrie d'argent IndexReward")
check(ada:GetAttribute("IndexClaimed") == "1", "IndexClaimed « 1 »")

section("une seule fois")
advance(1)
fireAs(ada, "ClaimIndexReward", 1)
fireAs(ada, "ClaimIndexReward")
flush()
check(IndexService.Claim(ada, 1) == 0 and IndexService.Claim(ada, nil) == 0, "2e réclamation : 0")
check(countOf(d.Tools.Owned, "Wrench") == 1 and d.Cash == cash0, "ni 2e arme, ni argent")
local userAda = ada.UserId
leave(ada)
local back = join("Ada", nil, userAda)
advance(1.5)
check(countOf(dataOf(back).Tools.Owned, "Wrench") == 1 and dataOf(back).Cash == cash0 and speedOf(back) == speed0, "retour : rien de plus au chargement")
leave(back)

section("Claim All : deux zones, arme et aura")
local bob = join("Bob", profileWith({ 1, 2 }))
advance(1.5)
local b0, bs0 = dataOf(bob).Cash, speedOf(bob)
check(IndexService.Claim(bob, nil) == 2, "Claim All : 2 récompenses")
check(dataOf(bob).Cash == b0 and speedOf(bob) == bs0, "ni argent ni Vitesse")
check(countOf(dataOf(bob).Tools.Owned, "Wrench") == 1 and countOf(dataOf(bob).Cosmetics.Auras, "Flame") == 1 and dataOf(bob).Cosmetics.EquippedAura == nil, "Wrench et l'aura Flame possédées, rien d'équipé")
check(bob:GetAttribute("IndexClaimed") == "1,2", "IndexClaimed « 1,2 »")
leave(bob)

section("arme déjà possédée : pas de doublon, rien à la place")
local cyData = profileWith({ 1 })
cyData.Tools.Owned = { "Fists", "Wrench" }
local cy = join("Cy", cyData)
advance(1.5)
local c0 = dataOf(cy).Cash
check(IndexService.Claim(cy, 1) == 1 and dataOf(cy).Cash == c0, "réclamée, pas d'argent")
check(countOf(dataOf(cy).Tools.Owned, "Wrench") == 1, "une seule Wrench")
leave(cy)

section("zone réclamée avant : l'objet une fois au chargement, rien d'autre")
local oldData = profileWith({ 1 })
oldData.IndexRewards = { ["1"] = 123 }
local dan = join("Dan", oldData)
advance(1.5)
check(dataOf(dan).Cash == 1000 and speedOf(dan) == 0 and #indexTelemetry(dan) == 0, "ni argent ni Vitesse")
check(countOf(dataOf(dan).Tools.Owned, "Wrench") == 1, "la Wrench")
check(dataOf(dan).IndexGifts ~= nil and type(dataOf(dan).IndexGifts["1"]) == "number" and dataOf(dan).IndexRewards["1"] == 123, "IndexGifts noté, IndexRewards gardé")
check(IndexService.Claim(dan, 1) == 0, "rien à réclamer")
local userDan = dan.UserId
leave(dan)
local dan2 = join("Dan", nil, userDan)
advance(1.5)
check(countOf(dataOf(dan2).Tools.Owned, "Wrench") == 1 and speedOf(dan2) == 0, "retour : une seule fois")
leave(dan2)

section("déjà versé par la vague 59 (argent, Vitesse, objet) : gardé, rien de plus")
local paidData = profileWith({ 1 })
paidData.IndexRewards = { ["1"] = 123 }
paidData.IndexGifts = { ["1"] = 124 }
paidData.Cash = 11000
paidData.Stats.Speed = 300
paidData.Tools.Owned = { "Fists", "Wrench" }
local fay = join("Fay", paidData)
advance(1.5)
check(dataOf(fay).Cash == 11000 and speedOf(fay) == 300 and countOf(dataOf(fay).Tools.Owned, "Wrench") == 1, "rien de repris, rien de plus")
check(IndexService.Claim(fay, 1) == 0, "rien à réclamer")
leave(fay)

section("IndexGifts abîmé : rien de versé")
local broken = profileWith({ 1 })
broken.IndexGifts = "oups"
local eve = join("Eve", broken)
advance(1.5)
check(IndexService.Claim(eve, nil) == 0 and countOf(dataOf(eve).Tools.Owned, "Wrench") == 0, "réclamation refusée, rien de donné")
check(logHas("[IndexService] Eve : IndexGifts illisible", "WARN", "server"), "avertissement")
leave(eve)

summary("scénario reward")
