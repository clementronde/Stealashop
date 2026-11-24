--!nocheck
-- Scénario « off » (a191) : Features.Index = false, ni récompense ni rattrapage.
advance(1000)
startServer()
section("index fermé")
check(Features.Index == false, "Features.Index = false (pre.off)")
local data = profileWith({ 1 })
data.IndexRewards = { ["1"] = 123 }
local ada = join("Ada", data)
advance(1.5)
check(dataOf(ada).Stats.Speed == 0 and countOf(dataOf(ada).Tools.Owned, "Wrench") == 0 and dataOf(ada).IndexGifts == nil, "zone réclamée avant : rien donné au chargement")
local bob = join("Bob", profileWith({ 1 }))
advance(1.5)
check(IndexService.Claim(bob, 1) == 0 and dataOf(bob).Cash == 1000 and dataOf(bob).Stats.Speed == 0, "réclamation refusée")
fireAs(bob, "ClaimIndexReward", 1)
flush()
check(dataOf(bob).IndexRewards == nil and countOf(dataOf(bob).Tools.Owned, "Wrench") == 0, "remote : rien")
summary("scénario off")
