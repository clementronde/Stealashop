--!nocheck
-- Copie a175 (vague 54) : le voleur prend l objet dedans (rien), sort avec (poursuite), puis rentre : frappé dedans.
-- Scénario « bot » (a151, vague 43) : mise en place du banc a32 (copie a37) + ext124.luau du banc a124. Le bot de la
-- boutique éjecte Bob alors que Cy est encore dedans : la porte attend ; Cy sort : la porte se répare tout de suite.
-- Puis le bot éjecte le seul intrus : réparée tout de suite.

startBotServer()
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local dan = join("Dan", newProfile())
giveBat(bob)
local plot, S = botArrives()
local doorId = windowIdOf(plot)
local bounds = plot:FindFirstChild("Bounds")
local function inside(player)
	return inBox(bounds, rootOf(player).Position)
end
-- Fusion 45 : avec a149 (règle de Cantin, « rien avant un vol »), le bot ne frappe qu'un voleur : Bob et Dan prennent
-- d'abord un objet (coup « Defend »). Arbre sans a149 : intrus sans objet, coup « Intruder », comme avant.
local A149 = string.find(SOURCES["shared/Config/Bot.luau"] or "", "TutorialKickCooldown", 1, true) ~= nil
local HIT_USAGE = if A149 then "Defend" else "Intruder"

section("le bot éjecte Bob, Cy encore dedans : la porte attend")
check(plot ~= nil and breakDoor(bob, plot), "Bob casse la porte du bot")
flush()
moveTo(cy, S.center, S.front * -1) -- au fond, loin de la porte
moveTo(bob, Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6, S.front * -1)
advance(0.1)
check(inside(bob) and inside(cy), "Bob et Cy sont dans la boutique du bot")
if A149 then
	check(steal(bob, plot, 2), "Bob prend un objet")
	flush()
	moveTo(bob, Vector3.new(S.door.X, 3, S.door.Z) + S.front * 5, S.front)
	advance(0.3)
	check(BotService.IsChasing(bob), "a175 : Bob sort avec l objet, poursuivi")
	moveTo(bob, Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6, S.front * -1)
end
local hit = waitFor(function()
	return #BOT_HITS > 0
end, 6)
check(hit and BOT_HITS[1].target == bob and BOT_HITS[1].usage == HIT_USAGE, `le bot frappe Bob (« {HIT_USAGE} »)`)
advance(0.2)
check(not inside(bob), "Bob est sorti")
check(WindowService.IsBroken(doorId) and inside(cy), "Cy encore dedans : la porte reste cassée")

section("Cy sort : porte réparée tout de suite")
moveTo(cy, S.outside, S.front)
advance(0.25)
check(not inside(cy), "Cy est sorti")
check(not WindowService.IsBroken(doorId), "plus aucun intrus : la porte du bot est reconstruite")
check(plot:GetAttribute("StealOpen") == nil, "vol fermé")

section("le bot éjecte le seul intrus : réparée tout de suite")
check(waitFor(function()
	return botRoot().Anchored
end, 15), "le bot est rentré")
local before = #BOT_HITS
check(breakDoor(dan, plot), "Dan casse la porte du bot")
flush()
moveTo(dan, Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6, S.front * -1)
advance(0.1)
if A149 then
	check(steal(dan, plot, 3), "Dan prend un objet")
	flush()
	moveTo(dan, Vector3.new(S.door.X, 3, S.door.Z) + S.front * 5, S.front)
	advance(0.3)
	check(BotService.IsChasing(dan), "a175 : Dan sort avec l objet, poursuivi")
	moveTo(dan, Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6, S.front * -1)
end
local again = waitFor(function()
	return #BOT_HITS > before
end, 12)
check(again and BOT_HITS[#BOT_HITS].target == dan, "le bot frappe Dan")
advance(0.2)
check(not inside(dan) and not WindowService.IsBroken(doorId), "Dan sorti, porte réparée")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles")
summary("scénario bot")
