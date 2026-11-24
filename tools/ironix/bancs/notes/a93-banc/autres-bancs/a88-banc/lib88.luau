---------------------------------------------------------------- a88 : mise en place (après setup.luau)
-- NightCycleService : bouclier débutant (a29), plus la nuit (NIGHT) et le côté couloir (x > 350).
NIGHT = false
SOURCES["stub/NightCycleService"] = [==[
local NightCycleService = { Priority = 115 }
function NightCycleService.IsShielded(player)
	if SHIELD_ERROR then error("panne simulée de IsShielded") end
	return SHIELDED[player] == true
end
function NightCycleService.IsNight()
	return NIGHT == true
end
function NightCycleService.IsInCorridor(position)
	return position.X > 350
end
return NightCycleService
]==]
moduleScript(SERVICES, "SkillTreeService", "server/Services/SkillTreeService.luau")
moduleScript(SERVICES, "TelemetryService", "stub/TelemetryService")
moduleScript(SERVICES, "GuardService", "stub/GuardService")
moduleScript(SERVICES, "AaBoostService", "stub/AaBoostService")
moduleScript(SERVICES, "PotionService", "server/Services/PotionService.luau")

-- Couloir (relevé du 2026-11-11, en plus petit) : deux rues côté couloir (x de 400 à 600, dessus à y = 0,
-- z de -52,5 à 52,5), un arbre (décor visible) sur la 1re, un volume invisible au-dessus de la 2e, et une
-- rue « Street » côté safe (x = -100), à ne jamais utiliser.
CORRIDOR = folder(Workspace, "Corridor")
STREET_A = make("Part", { Name = "Street", Anchored = true, Size = Vector3.new(88, 1, 105), CFrame = CFrame.new(444, -0.5, 0) }, CORRIDOR)
STREET_B = make("Part", { Name = "Street", Anchored = true, Size = Vector3.new(112, 1, 105), CFrame = CFrame.new(544, -0.5, 0) }, CORRIDOR)
TREE = make("Part", { Name = "Tree", Anchored = true, CanCollide = false, Size = Vector3.new(30, 20, 30), CFrame = CFrame.new(444, 10, 0) }, CORRIDOR)
TRIGGER = make("Part", { Name = "ZoneTrigger", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(200, 50, 200), CFrame = CFrame.new(544, 25, 0) }, CORRIDOR)
SAFE_STREET = make("Part", { Name = "Street", Anchored = true, Size = Vector3.new(60, 1, 60), CFrame = CFrame.new(-100, 0.1, 0) }, HUB)

POTIONS_CFG = nil
function startPotions()
	startServer()
	-- copie a93 (vague 29) : base de la porte selon StageLevel ; niveau 2 = 500, comme avant
	for _, plot in CollectionService:GetTagged("PlayerPlot") do
		plot:SetAttribute("StageLevel", 2)
	end
	SkillTreeService = serverModule("SkillTreeService")
	PotionService = serverModule("PotionService")
	GuardStub = serverModule("GuardService")
	POTIONS_CFG = sharedModule("Config/Potions")
end
function serverNow()
	return Workspace:GetServerTimeNow()
end
-- PotionSpawned / PotionRemoved envoyés à `player` (liste d'événements).
function spawnedTo(player)
	return remotes("PotionSpawned", function(e)
		return e.to == player
	end)
end
function removedTo(player)
	return remotes("PotionRemoved", function(e)
		return e.to == player
	end)
end
-- Potions encore là pour `player`, d'après les remotes : [uid] = { id, position }.
function livePotions(player)
	local live = {}
	for _, e in REMOTE_LOG do
		if e.to == player and e.name == "PotionSpawned" then
			live[e.args[1]] = { id = e.args[2], position = e.args[3] }
		elseif e.to == player and e.name == "PotionRemoved" then
			live[e.args[1]] = nil
		end
	end
	return live
end
function countOf(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end
function lastSpawned(player)
	local list = spawnedTo(player)
	local e = list[#list]
	return if e then e.args[1] else nil, if e then e.args[2] else nil, if e then e.args[3] else nil
end
function lastNotify(player)
	local list = notifies(player)
	local e = list[#list]
	return if e then e.args[1] else nil, if e then e.args[2] else nil
end
function test(command)
	Workspace:SetAttribute("PotionTest", command)
	flush()
end
function skill(player, id, level)
	Workspace:SetAttribute("SkillTest", `{player.Name} {id} {level}`)
	flush()
end
-- Pose une potion de type `id` devant `player` (crochet de test) et renvoie son uid et sa position.
function spawnNear(player, id)
	moveTo(player, Vector3.new(560, 3, 20))
	test(`{player.Name} spawn {id}`)
	local uid, _, position = lastSpawned(player)
	return uid, position
end
function pick(player, uid)
	fireAs(player, "PickPotion", uid)
	advance(0.3)
end
function attr(player, id)
	return player:GetAttribute("Potion_" .. id)
end
-- Avance jusqu'à ce qu'une potion de plus soit envoyée à `player` (au plus `limit` s) ; renvoie le temps attendu.
function waitSpawn(player, limit)
	local n = #spawnedTo(player)
	local t0 = now()
	while #spawnedTo(player) == n and now() - t0 < limit do
		advance(0.25, 0.25)
	end
	return if #spawnedTo(player) > n then now() - t0 else nil
end
-- Ligne de vérification de fin de scénario.
function finish(label)
	check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
	check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
	check(not logHas("valeur de base gardée", "WARN"), "aucun point d'accroche en erreur")
	if VERBOSE then
		dumpLog("Potion")
	end
	summary(label)
end
