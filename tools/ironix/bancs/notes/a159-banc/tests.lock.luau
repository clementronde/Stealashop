--!nocheck
-- Scénario « lock » (a159, L-163) : la tuile Curtain devient le verrou de la boutique (remote LockShop).
startSkills()
local SkillTree = sharedModule("Config/SkillTree")
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
adaData.Cash = 1e12
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile()) -- sans boutique ? il en a une : sert de témoin
advance(1.2)
local shop = shopOf(ada)
local id = windowIdOf(shop)
local S = refsOfShop(shop)
local Lock = SkillTree.Lock
local function serverNow()
	return Workspace:GetServerTimeNow()
end
local function lockFor()
	local u = shop:GetAttribute("LockedUntil")
	return if type(u) == "number" then u - serverNow() else 0
end
local function lastNote(player)
	local l = notifies(player)
	return if #l > 0 then l[#l].args[1] else nil
end
local function hitN(player, n)
	moveTo(player, S.outside + S.front * -3)
	local tool = giveTool(player)
	local since = now()
	for _ = 1, n do
		fireAs(player, "HitWindow", id)
		advance(0.2, 0.2)
	end
	tool:Destroy()
	return #remotes("WindowHit", function(e)
		return e.args[1] == id and e.to == player and e.t >= since
	end)
end

section("configuration")
local curtain = SkillTree.ById.Curtain
check(curtain.Coded == 2 and curtain.MaxLevel == 2 and curtain.Effects[1] == 45 and curtain.Effects[2] == 60, "Curtain : codée, 45 et 60 s")
check(Lock.BaseDuration == 30 and Lock.Cooldown == 120, `Lock : 30 s offertes, recharge 120 s (trouvé {Lock.BaseDuration}, {Lock.Cooldown})`)
check(curtain.DisplayName == "Lock" and curtain.Labels[0] == "30s", "tuile : « Lock », 30s offertes")

section("verrou de 30 s offert")
fireAs(ada, "LockShop")
flush()
check(math.abs(lockFor() - 30) < 0.2, `LockedUntil = dans 30 s (trouvé {lockFor()})`)
check(lastNote(ada) == "Shop locked for 30s!", `Notify à Ada : « {lastNote(ada)} »`)
local readyAt = ada:GetAttribute("LockReadyAt")
check(type(readyAt) == "number" and math.abs(readyAt - serverNow() - 150) < 0.2, `LockReadyAt = fin + 120 s (dans {readyAt and readyAt - serverNow()} s)`)
local n = hitN(bob, 10)
check(n == 0, `porte verrouillée : aucun coup de Bob compté (trouvé {n})`)
check(#notifies(bob, "This shop is locked! Opens in") >= 1, "Bob est prévenu")
check(#notifies(bob, "This shop is locked!") <= 2, `au plus un message toutes les 2 s ({#notifies(bob, "This shop is locked!")} en 2 s)`)
fireAs(ada, "LockShop")
flush()
check(lastNote(ada) == "Your shop is already locked.", `deuxième verrou : « {lastNote(ada)} »`)
advance(28.5)
check(shop:GetAttribute("LockedUntil") == nil, "après 30 s : attribut LockedUntil retiré")
n = hitN(bob, 5)
check(n == 5, `verrou fini : les coups de Bob comptent (trouvé {n})`)

section("recharge de 120 s")
advance(2)
fireAs(ada, "LockShop")
flush()
check(string.find(lastNote(ada) or "", "Lock recharging: ", 1, true) == 1, `pendant la recharge : « {lastNote(ada)} »`)
check(shop:GetAttribute("LockedUntil") == nil, "pas de verrou pendant la recharge")

section("niveaux achetés : 45 puis 60 s")
advance(120)
buy(ada, "GlassThickness") -- ouvre la tuile Curtain (OpensWhen Glass 1)
buy(ada, "Curtain")
check(ada:GetAttribute("Skill_Curtain") == 1, `Curtain niveau 1 acheté (attribut {ada:GetAttribute("Skill_Curtain")})`)
fireAs(ada, "LockShop")
flush()
check(math.abs(lockFor() - 45) < 0.3, `niveau 1 : 45 s (trouvé {lockFor()})`)
advance(45 + 120 + 1)
Workspace:SetAttribute("SkillTest", "Ada Curtain 2")
advance(0.1)
fireAs(ada, "LockShop")
flush()
check(math.abs(lockFor() - 60) < 0.3, `niveau 2 : 60 s (trouvé {lockFor()})`)
advance(61)
check(shop:GetAttribute("LockedUntil") == nil, "après 60 s : ouverte")

section("porte cassée : verrou refusé")
ada:SetAttribute("LockReadyAt", nil)
WindowService.GetPlotRegen = function()
	return 0
end
local broke = breakDoor(bob, shop, 300)
check(broke, "Bob casse la porte")
fireAs(ada, "LockShop")
flush()
check(lastNote(ada) == "Your door is broken: you can't lock it now!", `porte cassée : « {lastNote(ada)} »`)
check(shop:GetAttribute("LockedUntil") == nil, "pas de verrou")

section("sans boutique : refus")
local eve = newPlayer("Eve")
fireAs(eve, "LockShop")
flush()
check(lastNote(eve) == "You need a shop to lock it.", `sans boutique : « {lastNote(eve)} »`)

section("boutique libérée : verrou levé")
WindowService.Rebuild(id)
advance(0.3)
ada:SetAttribute("LockReadyAt", nil)
fireAs(ada, "LockShop")
flush()
check(lockFor() > 0, "Ada verrouille")
leave(ada)
advance(0.5)
check(shop:GetAttribute("LockedUntil") == nil, "Ada part : verrou levé")

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
summary("scénario lock")
