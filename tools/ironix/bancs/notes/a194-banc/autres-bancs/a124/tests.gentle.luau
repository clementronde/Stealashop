--!nocheck
-- Copie a194 (vague 60, Cantin : poursuite jusqu au bout) : ressorti avec l objet, plus d abandon à 10 s ; fin au dépôt.
-- Copie a175 (vague 54) : chaque prise se fait dans la boutique sans rien déclencher ; la poursuite part à la sortie
-- avec l objet (exitShop). 2e prise : 8 s dedans sans poursuite, puis sortie, rentrée (poursuite sans limite), ressortie.
-- Scénario « gentle », copie a149 (vague 42) : pendant le tuto de Bob (IsGentle remplacé ici comme TutorialService
-- le fait), le bot court à 12 dès que Bob porte son objet et ne le frappe qu'une fois ; Bob attend 15 s (L-146
-- point 3, Clément) au lieu de 60 avant de revoler le bot. 2e prise (Cantin, 2026-11-14) : dans la boutique, suivi sans
-- limite de temps (et sans coup : déjà frappé une fois) ; dehors, abandon 10 s après la sortie.
-- (le porteur reste à portée). Cy (hors tuto) : 13,4, frappée, 60 s.

startBotServer()
local PvP = sharedModule("Config/PvP")
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local plot, S = botArrives()
local root, humanoid = botRoot(), botHumanoid()
BotService.IsGentle = function(player)
	return player == bob
end

section("1re prise pendant le tuto : plus lent, frappé une fois, 15 s")
check(breakDoor(bob, plot), "Bob casse la porte")
advance(0.3)
check(not BotService.IsChasing(bob), "porte cassée : pas de poursuite")
check(steal(bob, plot, 2), "Bob prend un objet")
advance(2)
check(not BotService.IsChasing(bob) and #BOT_HITS == 0, "a175 : dans la boutique avec l objet, pas de poursuite")
exitShop(bob, S)
advance(0.3)
check(humanoid.WalkSpeed == 12, `WalkSpeed 12 pendant le tuto de Bob (trouvé {humanoid.WalkSpeed})`)
check(waitFor(function()
	return #BOT_HITS > 0
end, 8) and BOT_HITS[1].target == bob, "frappé une fois")
advance(0.1)
local left = PvPService.GetRobCooldown(bob, plot)
check(left > 14 and left <= 15, `interdiction de 15 s en tuto (reste {left})`)
check(#notifies(bob, "rob this shop again in 15s.") >= 1 and #notifies(bob, "again in 60s.") == 0, "message à Bob : 15s, jamais 60s")
check(waitFor(function()
	return root.Anchored
end, 15), "le bot rentre")
advance(15)
check(PvPService.GetRobCooldown(bob, plot) == 0, "15 s plus tard, Bob peut revoler le bot")

section("2e prise : sans limite dans la boutique, 10 s dehors")
local id = WindowService.GetWindowId(plot)
local waited = 0
while WindowService.IsBroken(id) and waited < 40 do
	advance(0.5)
	waited += 0.5
end
check(breakDoor(bob, plot), "Bob casse la porte de nouveau (porte refaite entre-temps : 20 s avant la suivante)")
check(steal(bob, plot, 3), "Bob reprend un objet")
local bounds = plot:FindFirstChild("Bounds")
local insideSpot = Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6
moveTo(bob, insideSpot, S.front * -1)
advance(0.1)
check(inBox(bounds, rootOf(bob).Position), "Bob reste dans la boutique du bot")
local swings = animPlays("SwingBat")
advance(8)
check(not BotService.IsChasing(bob), "a175 : 8 s dans la boutique avec l objet : pas de poursuite")
check(#BOT_HITS == 1 and CarryService.IsCarrying(bob), "aucun coup dedans : Bob garde l objet")
check(animPlays("SwingBat") == swings, "aucun SwingBat")
local outsideSpot = Vector3.new(S.door.X, 3, S.door.Z) + S.front * 5
moveTo(bob, outsideSpot, S.front)
advance(0.1)
check(not inBox(bounds, rootOf(bob).Position), "Bob sort, à 5 studs de la porte")
advance(3)
check(BotService.IsChasing(bob), "a175 : sorti avec l objet, poursuivi ; 3 s dehors : encore poursuivi")
moveTo(bob, insideSpot, S.front * -1)
advance(9)
check(BotService.IsChasing(bob), "rentré : 9 s de plus (3 + 9 > 10), poursuite de nouveau sans limite")
moveTo(bob, outsideSpot, S.front)
advance(12)
check(BotService.IsChasing(bob), "a194 : ressorti avec l objet, encore poursuivi 12 s plus tard (plus d abandon à 10 s)")
runHome(bob, plot, 16)
check(not CarryService.IsCarrying(bob), "Bob ramène l'objet chez lui (tuto finissable)")
advance(0.3)
check(not BotService.IsChasing(bob), "a194 : déposé, plus poursuivi")

section("hors tuto : vitesse normale, coup, 60 s")
check(waitFor(function()
	return root.Anchored
end, 15), "le bot rentre")
waited = 0
while WindowService.IsBroken(id) and waited < 40 do
	advance(0.5)
	waited += 0.5
end
check(breakDoor(cy, plot), "Cy casse la porte")
check(steal(cy, plot, 4), "Cy prend un objet et reste là")
advance(2)
check(not BotService.IsChasing(cy) and #BOT_HITS == 1, "a175 : Cy dans la boutique, rien")
exitShop(cy, S)
advance(0.3)
check(humanoid.WalkSpeed == 13.4, `WalkSpeed 13,4 pour Cy (trouvé {humanoid.WalkSpeed})`)
check(waitFor(function()
	return #BOT_HITS > 1
end, 8) and BOT_HITS[2].target == cy and BOT_HITS[2].usage == "Defend", "Cy frappée")
advance(0.1)
local cyLeft = PvPService.GetRobCooldown(cy, plot)
check(cyLeft > 58 and cyLeft <= PvP.KickRobCooldown, `Cy : {PvP.KickRobCooldown} s (reste {cyLeft})`)
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
summary("scénario gentle")
