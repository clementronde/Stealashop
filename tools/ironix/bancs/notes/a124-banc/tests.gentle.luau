--!nocheck
-- Scénario « gentle » (a124) : pendant le tuto de Bob (point d'accroche BotService.IsGentle, remplacé ici comme
-- TutorialService le fait), le bot court à 12 et ne le frappe qu'une fois : à la 2e prise, il le suit sans
-- frapper et Bob ramène l'objet. Cy (hors tuto) est poursuivie à 13,4 et frappée.

startBotServer()
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local plot, S = botArrives()
local root, humanoid = botRoot(), botHumanoid()
BotService.IsGentle = function(player)
	return player == bob
end

section("1re prise pendant le tuto : plus lent, frappé une fois")
check(breakDoor(bob, plot), "Bob casse la porte")
advance(0.3)
check(humanoid.WalkSpeed == 12, `WalkSpeed 12 pendant le tuto de Bob (trouvé {humanoid.WalkSpeed})`)
check(steal(bob, plot, 2), "Bob prend un objet")
check(waitFor(function()
	return #BOT_HITS > 0
end, 8) and BOT_HITS[1].target == bob, "frappé une fois")
check(waitFor(function()
	return root.Anchored
end, 15), "le bot rentre")

section("2e prise : suivi, plus frappé")
advance(61)
check(breakDoor(bob, plot), "Bob casse la porte de nouveau")
check(steal(bob, plot, 3), "Bob reprend un objet et reste là")
local close = waitFor(function()
	return (root.Position - rootOf(bob).Position).Magnitude <= 7
end, 8)
check(close and BotService.IsChasing(bob), "le bot est à portée et le poursuit")
local swings = animPlays("SwingBat")
advance(3)
check(#BOT_HITS == 1 and bob:GetAttribute("BatStun") == nil and CarryService.IsCarrying(bob), "pas de 2e coup : Bob garde l'objet")
check(animPlays("SwingBat") == swings, "aucun SwingBat")
runHome(bob, plot, 16)
check(not CarryService.IsCarrying(bob), "Bob ramène l'objet chez lui (tuto finissable)")

section("hors tuto : vitesse normale et coup")
check(waitFor(function()
	return root.Anchored
end, 15), "le bot rentre")
local waited, id = 0, WindowService.GetWindowId(plot)
while WindowService.IsBroken(id) and waited < 40 do
	advance(0.5)
	waited += 0.5
end
check(breakDoor(cy, plot), "Cy casse la porte")
advance(0.3)
check(humanoid.WalkSpeed == 13.4, `WalkSpeed 13,4 pour Cy (trouvé {humanoid.WalkSpeed})`)
check(steal(cy, plot, 4), "Cy prend un objet et reste là")
check(waitFor(function()
	return #BOT_HITS > 1
end, 8) and BOT_HITS[2].target == cy and BOT_HITS[2].usage == "Defend", "Cy frappée")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
summary("scénario gentle")
