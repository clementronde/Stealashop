--!nocheck
-- Copie a194 (vague 60) : sections 2 et 3 réécrites (plus de laisse ni d abandon pour un porteur ; fin au dépôt).
-- Banc a175 (vague 54, Cantin 2026-11-15 : « il faut qu'il commence à nous courir après, seulement lorsqu'on sort de son
-- magasin avec l'item »), sur la mise en place du banc a124 (copie a175, aides exitShop et enterShop d'ext175.luau).
-- 1. Bob prend un objet et le perd dans la boutique, puis sort sans objet : rien.
-- 2. Bob reprend un objet et sort : poursuivi. Cy prend un objet pendant ce temps et reste dedans : jamais visée ; elle
--    sort à son tour et Bob sème le bot (laisse) : Cy poursuivie.
-- 3. Abandon (10 s dehors) : Bob garde l'objet dehors, il n'est plus poursuivi ; rentrer et ressortir avec ne relance
--    rien (une poursuite par objet pris).

startBotServer()
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local plot, S = botArrives()
local root = botRoot()
local bounds = plot:FindFirstChild("Bounds")

section("1. objet perdu dans la boutique, sortie sans objet : rien")
check(breakDoor(bob, plot), "Bob casse la porte du bot")
enterShop(bob, S)
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2")
advance(2)
check(not BotService.IsChasing(bob) and root.Anchored, "dedans avec l'objet : pas de poursuite")
CarryService.Fail(cy, "rien") -- sans effet : Cy ne porte rien
CarryService.Fail(bob, "banc a175")
flush()
check(not CarryService.IsCarrying(bob) and BotService.GetExposed(plot)[2] ~= nil, "Bob perd l'objet : revenu sur son présentoir")
exitShop(bob, S)
advance(3)
check(not inBox(bounds, rootOf(bob).Position), "Bob est dehors")
check(not BotService.IsChasing(bob) and root.Anchored and #BOT_HITS == 0, "sorti sans objet : ni poursuite ni coup")

section("2. sortie avec l'objet : poursuivi ; Cy prend dedans : pas visée avant sa sortie")
enterShop(bob, S)
check(steal(bob, plot, 3), "Bob prend l'objet du présentoir 3")
check(steal(cy, plot, 4), "Cy prend l'objet du présentoir 4")
advance(1)
check(not BotService.IsChasing(bob) and not BotService.IsChasing(cy) and root.Anchored, "tous deux dedans avec un objet : rien")
exitShop(bob, S, 12)
advance(0.3)
check(BotService.IsChasing(bob) and not root.Anchored, "Bob sort avec l'objet : poursuivi")
advance(1.5)
check(not BotService.IsChasing(cy), "Cy, dedans avec son objet : jamais visée")
for _, h in BOT_HITS do
	check(h.target ~= cy, "Cy jamais frappée dedans")
end
exitShop(cy, S, 3)
advance(0.3)
exitShop(bob, S, 40) -- a194 : Bob au-delà de la laisse (15 studs) reste la cible tant qu il porte l objet
advance(1)
local bobHit = #BOT_HITS > 0 and BOT_HITS[#BOT_HITS].target == bob
check(BotService.IsChasing(bob) or bobHit, "a194 : Bob hors de la laisse avec l objet : toujours poursuivi")
if CarryService.IsCarrying(bob) then
	runHome(bob, plot, 16)
end
local cyChased = waitFor(function()
	return BotService.IsChasing(cy) or (#BOT_HITS > 0 and BOT_HITS[#BOT_HITS].target == cy)
end, 15)
check(cyChased, "Bob fini (déposé ou frappé) : le bot poursuit Cy, sortie avec son objet")

section("3. fin : Cy ramène son objet (ou est frappée), le bot rentre")
if CarryService.IsCarrying(cy) then
	runHome(cy, plot, 16)
end
check(not CarryService.IsCarrying(cy), "Cy n a plus l objet (déposé ou frappée)")
check(waitFor(function()
	return root.Anchored
end, 25), "le bot finit par rentrer")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles")
summary("scénario exit")
