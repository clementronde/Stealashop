--!nocheck
-- Copie a175 (vague 54) : la prise dans la boutique ne déclenche rien ; Bob sort avec l objet (exitShop) et c est là
-- que le bot le poursuit et le frappe. Idem pour la 2e prise (« nouvelle poursuite »).
-- Scénario « grab » (a124) : Bob casse la porte, prend un objet du bot et reste dans la boutique. Le bot le
-- rattrape et le frappe (« Defend ») : l'objet revole sur son présentoir, Bob est étourdi, sorti, 60 s sans
-- voler le bot ; OnTheft « Returned » ; le bot rentre. Cy, qui ne fait rien, n'est jamais visée. Enfin, le bot
-- qui part pendant une poursuite (5e vrai joueur) ne laisse rien.

startBotServer()
local bobData = newProfile()
local bob = join("Bob", bobData)
local cy = join("Cy", newProfile())
giveBat(bob)
local plot, S = botArrives()
local root = botRoot()
local home = root.CFrame
local thefts = {}
BotService.OnTheft(function(thief, itemId, stage)
	table.insert(thefts, { thief = thief, stage = stage })
end)

section("prise d'un objet")
check(breakDoor(bob, plot), "Bob casse la porte du bot")
local exposed = BotService.GetExposed(plot)
local uid2 = exposed[2].Uid
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2")
advance(3)
check(not BotService.IsChasing(bob) and #BOT_HITS == 0 and botRoot().Anchored, "a175 : 3 s dans la boutique avec l objet, ni poursuite ni coup")
exitShop(bob, S)
advance(0.2)
check(BotService.IsChasing(bob) and not BotService.IsChasing(cy), "le bot poursuit Bob, pas Cy")
check(BotService.GetExposed(plot)[2] == nil, "présentoir 2 vide (objet sur la tête de Bob)")

section("le bot le rattrape et le frappe")
local hit = waitFor(function()
	return #BOT_HITS > 0
end, 8)
check(hit and BOT_HITS[1].target == bob and BOT_HITS[1].usage == "Defend", `coup « Defend » sur Bob (trouvé {BOT_HITS[1] and BOT_HITS[1].usage})`)
check(BOT_HITS[1] and BOT_HITS[1].payload and BOT_HITS[1].payload.ItemUid == uid2, "le payload de l'objet volé")
advance(0.2)
check(not CarryService.IsCarrying(bob), "Bob ne porte plus rien")
local back = BotService.GetExposed(plot)[2]
check(back ~= nil and back.Uid == uid2, "l'objet est revenu sur le présentoir 2 du bot")
check(thefts[#thefts] and thefts[#thefts].stage == "Returned", "BotService.OnTheft « Returned » (tuto : retour à l'étape 12)")
check(bob:GetAttribute("BatStun") == "Stun", "Bob étourdi")
check(PvPService.GetRobCooldown(bob, plot) > 58, "60 s sans voler le bot")
check(not inBox(plot:FindFirstChild("Bounds"), rootOf(bob).Position), "Bob sorti devant la porte")
check(#notifies(bob, "Kicked out!") == 0 and #notifies(bob, "You can rob this shop again in") == 1, "a175 : frappé dehors, Notify « You can rob this shop again in 60s. » (pas « Kicked out! »)")
check(bobData.Items[uid2] == nil, "rien n'est passé chez Bob")
check(#PLAYER_HITS == 0, "aucun OnHit de joueur")

section("une seule frappe, puis retour")
advance(4)
check(#BOT_HITS == 1, `un seul coup (trouvé {#BOT_HITS})`)
check(waitFor(function()
	return root.Anchored
end, 12) and (root.Position - home.Position).Magnitude < 1e-3, "rentré et ré-ancré au point d'apparition")
check(cy:GetAttribute("BatStun") == nil, "Cy jamais frappée")

section("le bot part pendant une poursuite")
advance(62)
check(breakDoor(bob, plot) and steal(bob, plot, 3), "60 s plus tard, Bob reprend un objet")
check(not BotService.IsChasing(bob), "a175 : pas de poursuite tant qu il est dedans")
exitShop(bob, S)
advance(0.2)
check(root.Anchored == false and BotService.IsChasing(bob), "nouvelle poursuite")
for i = 1, 3 do
	join("P" .. i, newProfile())
end
advance(1)
check(BotService.GetBotPlot() == nil and botAvatar() == nil, "5e vrai joueur : le bot part, avatar retiré")
check(not BotService.IsChasing(bob), "plus de poursuite")
advance(1)
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles")
summary("scénario grab")
