--!nocheck
-- Scénario « owner » (a177, vague 55, Cantin 2026-11-15) : le propriétaire frappe à la batte celui qui casse sa porte,
-- dehors devant elle : PvP.KickRobCooldown (60) s sans frapper cette porte ni voler cette boutique, message BreakerHit ;
-- un autre joueur n'est pas touché ; la porte garde ses coups reçus (comme pour l'intrus : seule une porte cassée se
-- refait). Témoins : un joueur loin de la porte, ou qui a fini de frapper depuis plus de PvP.BreakerMemory s, n'est pas
-- frappable (mains vides, en zone safe).
startServer()
local PvP = sharedModule("Config/PvP")
local ada = join("Ada", victimProfile())
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local dan = join("Dan", newProfile())
for _, p in { ada, bob, cy, dan } do
	giveBat(p)
end
advance(1.2)
local hits = {}
BatService.OnHit(function(hitter, target, usage)
	table.insert(hits, { hitter = hitter, target = target, usage = usage })
end)
local plot = shopOf(ada)
local S = refsOfShop(plot)
local id = windowIdOf(plot)

section("valeurs V0")
check(PvP.BreakerMemory == 3 and PvP.BreakerMargin == 2 and PvP.ShopPanelForward == 3, "Config/PvP : BreakerMemory 3, BreakerMargin 2, ShopPanelForward 3")

-- Coups comptés (WindowHit renvoyé au frappeur) de `p` sur la porte d'Ada depuis `since`.
local function counted(p, since)
	return #remotes("WindowHit", function(e)
		return e.args[1] == id and e.to == p and e.args[3] == p and e.t >= since
	end)
end
-- `p` frappe la porte `n` fois (5 coups/s), devant elle, à 3,5 studs.
local function hitDoor(p, n, offset)
	moveTo(p, S.outside + S.front * -3 + (offset or Vector3.zero), S.front * -1)
	local tool = giveTool(p)
	for _ = 1, n do
		fireAs(p, "HitWindow", id)
		advance(0.2, 0.2)
	end
	tool:Destroy()
end
-- Ada sort devant `p` (3 studs plus loin vers la rue, tournée vers lui) et frappe. Renvoie true si un coup a porté sur `p`.
local function adaSwings(p)
	local pos = rootOf(p).Position
	moveTo(ada, pos + S.front * 3, -S.front)
	if not holdsBat(ada) then
		humanoidOf(ada):EquipTool(batOf(ada))
	end
	local count = #hits
	fireAs(ada, "SwingBat")
	flush()
	return #hits > count and hits[#hits].target == p, hits[#hits]
end

section("Bob casse la porte d'Ada : frappé devant elle")
local t0 = now()
hitDoor(bob, 10)
check(counted(bob, t0) >= 9 and not WindowService.IsBroken(id), `Bob frappe la porte : {counted(bob, t0)} coups comptés, pas cassée`)
check(WindowService.IsBreaking(plot, bob), "WindowService.IsBreaking : Bob casse la porte d'Ada")
check(not WindowService.IsBreaking(plot, cy), "Cy ne casse rien")
local hitBob, last = adaSwings(bob)
check(hitBob and last.usage == "Intruder", `coup d'Ada sur Bob, usage « Intruder » (trouvé {last and last.usage})`)
advance(0.1)
local left = PvPService.GetRobCooldown(bob, plot)
check(left > PvP.KickRobCooldown - 2 and left <= PvP.KickRobCooldown, `Bob : {PvP.KickRobCooldown} s d'interdiction sur la boutique d'Ada (reste {string.format("%.1f", left)})`)
check(#notifies(bob, "Bonked! You can't break into this shop for") == 1, "message BreakerHit à Bob (V0, anglais)")
check(#notifies(bob, "Kicked out") == 0, "pas « Kicked out » : il était dehors")
check(bob:GetAttribute("RobCooldown_" .. plot:GetAttribute("PlotIndex")) ~= nil, "attribut RobCooldown_<PlotIndex> posé sur Bob (panneau, invites)")
check(PvPService.GetRobCooldown(cy, plot) == 0 and PvPService.GetRobCooldown(dan, plot) == 0, "Cy et Dan pas touchés")
check(not WindowService.IsBroken(id), "la porte n'est pas cassée")

section("Bob ne peut plus frapper cette porte ; Cy si")
advance(3.2) -- étourdissement et immunité finis
local t1 = now()
hitDoor(bob, 6)
check(counted(bob, t1) == 0, `coups de Bob refusés (comptés : {counted(bob, t1)})`)
check(#notifies(bob, "You can rob this shop again in") >= 1, "refus annoncé à Bob (RobCooldown)")
local other = shopOf(cy)
local otherId = windowIdOf(other)
local t2 = now()
do
	local SO = refsOfShop(other)
	moveTo(bob, SO.outside + SO.front * -3, SO.front * -1)
	local tool = giveTool(bob)
	for _ = 1, 5 do
		fireAs(bob, "HitWindow", otherId)
		advance(0.2, 0.2)
	end
	tool:Destroy()
end
check(#remotes("WindowHit", function(e) return e.args[1] == otherId and e.to == bob and e.t >= t2 end) >= 4, "Bob frappe toujours la porte de Cy (une autre boutique)")
moveTo(bob, HUB_CENTER)
local t3 = now()
hitDoor(cy, 5, Vector3.new(3, 0, 0))
check(counted(cy, t3) >= 4, `Cy frappe la porte d'Ada : {counted(cy, t3)} coups comptés`)

section("Bob ne peut pas voler la boutique d'Ada, même porte cassée")
advance(4)
check(breakDoor(dan, plot), "Dan casse la porte d'Ada")
advance(0.3)
check(not steal(bob, plot, 1), "Bob ne prend rien (interdit 60 s)")
check(steal(cy, plot, 2), "Cy, elle, prend l'objet du présentoir 2")

section("témoins : pas un casseur")
-- Porte refaite, plus personne dedans.
WindowService.Rebuild(id)
advance(3.5)
moveTo(cy, HUB_CENTER)
advance(0.5)
local tE = now()
local eve = join("Eve", newProfile())
giveBat(eve)
advance(1)
hitDoor(eve, 3)
moveTo(eve, S.outside + S.front * 20, S.front * -1) -- loin de la porte
check(not WindowService.IsBreaking(plot, eve), "Eve partie à 26 studs de la porte : plus casseuse")
local hitEve = adaSwings(eve)
check(not hitEve, "Ada ne peut pas frapper Eve (mains vides, zone safe, loin de la porte)")
advance(3.2)
hitDoor(eve, 3)
advance(PvP.BreakerMemory + 0.3)
check(not WindowService.IsBreaking(plot, eve), `Eve devant la porte mais sans coup depuis {PvP.BreakerMemory} s : plus casseuse`)
check(not adaSwings(eve), "Ada ne peut pas la frapper")
check(PvPService.GetRobCooldown(eve, plot) == 0, "Eve n'a aucune interdiction")

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("IsIntruder", "WARN") and not logHas("IsBotIntruder", "WARN"), "points d'accroche de la batte sans erreur")
summary("scénario owner")
