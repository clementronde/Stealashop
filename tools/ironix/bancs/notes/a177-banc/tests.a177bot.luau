--!nocheck
-- Scénario « a177bot » (a177, vague 55, Cantin 2026-11-15), sur la mise en place du banc a124 : le bot sort de sa
-- boutique et frappe celui qui casse sa porte, devant elle : même interdiction que l'intrus (PvP.KickRobCooldown s),
-- message BreakerHit, un autre joueur pas touché ; la porte n'est pas cassée. Pendant son tuto (IsGentle), le
-- casseur n'est ni poursuivi ni frappé (il doit casser la porte du bot). Le bot rentre ensuite.

startBotServer()
local PvP = sharedModule("Config/PvP")
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local dan = join("Dan", newProfile())
local plot, S = botArrives()
local id = WindowService.GetWindowId(plot)
local root = botRoot()
local home = root.CFrame

-- `p` frappe la porte du bot à 5 coups/s jusqu'à `stop()` (au plus `max` coups). Renvoie le nombre de coups envoyés.
local function hitDoor(p, stop, max, offset)
	moveTo(p, S.outside + S.front * -3 + (offset or Vector3.zero), S.front * -1)
	local tool = giveTool(p)
	local n = 0
	while n < max and not stop() and not WindowService.IsBroken(id) do
		fireAs(p, "HitWindow", id)
		n += 1
		advance(0.2, 0.2)
	end
	tool:Destroy()
	return n
end

section("Bob frappe la porte du bot : le bot sort et le frappe")
check(root.Anchored, "le bot attend, ancré")
local sent = hitDoor(bob, function()
	return #BOT_HITS > 0
end, 60)
check(not root.Anchored or #BOT_HITS > 0, "le bot s'est désancré")
check(#BOT_HITS == 1 and BOT_HITS[1].target == bob and BOT_HITS[1].usage == "Intruder", `coup du bot sur Bob, « Intruder » (trouvé {BOT_HITS[1] and BOT_HITS[1].usage}, après {sent} coups de Bob)`)
check(not WindowService.IsBroken(id), "la porte du bot n'est pas cassée")
check(BOT_HITS[1] and not inBox(plot:FindFirstChild("Bounds"), rootOf(bob).Position), "Bob frappé dehors, devant la porte")
advance(0.2)
local left = PvPService.GetRobCooldown(bob, plot)
check(left > PvP.KickRobCooldown - 2 and left <= PvP.KickRobCooldown, `Bob : {PvP.KickRobCooldown} s sans voler le bot (reste {string.format("%.1f", left)})`)
check(#notifies(bob, "Bonked! You can't break into this shop for") == 1, "message BreakerHit à Bob")
check(PvPService.GetRobCooldown(cy, plot) == 0, "Cy pas touchée")

section("Bob ne peut plus frapper la porte ; le bot rentre")
advance(2.5)
local hitsBefore = #remotes("WindowHit", function(e)
	return e.args[1] == id and e.to == bob
end)
hitDoor(bob, function()
	return false
end, 5)
local hitsAfter = #remotes("WindowHit", function(e)
	return e.args[1] == id and e.to == bob
end)
check(hitsAfter == hitsBefore, "coups de Bob sur la porte du bot refusés")
moveTo(bob, HUB_CENTER)
check(waitFor(function()
	return root.Anchored
end, 15), "le bot rentre et se ré-ancre")
check((root.Position - home.Position).Magnitude < 1e-3, "à son point d'apparition")

section("tuto : le casseur n'est ni poursuivi ni frappé")
local saved = BotService.IsGentle
BotService.IsGentle = function(p)
	return p == dan
end
local hits0 = #BOT_HITS
hitDoor(dan, function()
	return false
end, 15)
check(root.Anchored and not BotService.IsChasing(dan), "Dan en tuto : le bot reste ancré")
check(#BOT_HITS == hits0 and PvPService.GetRobCooldown(dan, plot) == 0, "Dan pas frappé, aucune interdiction")
BotService.IsGentle = saved

section("Cy, hors tuto, est frappée à son tour")
moveTo(dan, HUB_CENTER)
advance(40) -- porte réparée (3 s sans coup, puis 3 % par seconde)
hitDoor(cy, function()
	return #BOT_HITS > hits0
end, 60, Vector3.new(2, 0, 0))
check(#BOT_HITS == hits0 + 1 and BOT_HITS[#BOT_HITS].target == cy, "Cy frappée par le bot")
check(PvPService.GetRobCooldown(cy, plot) > 55, "Cy : 60 s sans voler le bot")

section("sortie")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles")
summary("scénario a177bot")
