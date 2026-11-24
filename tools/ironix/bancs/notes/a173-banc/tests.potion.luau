--!nocheck
-- a173 (2026-11-15, Play de fusion48 : « PickPotion refusé : trop loin (10.3 studs) » en courant à 29 studs/s) :
-- PickPotion tolère StoreHeistService.ReachPad studs de plus, comme StealItem (a165). Le harnais d'a88 n'a pas
-- StoreHeistService : un module StoreHeistService de test donne ReachPad avec la formule de Balance.Heist
-- (min(WalkSpeed × (ping + ReachLatencyPad), max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds))).
startPotions()
local P = POTIONS_CFG
local Heist = sharedModule("Config/Balance").Heist
REACH_CALLS = 0
function REACH_PAD(player, humanoid)
	REACH_CALLS += 1
	local speed = if humanoid then humanoid.WalkSpeed else 0
	return math.min(speed * Heist.ReachLatencyPad, math.max(Heist.ReachToleranceMin, speed * Heist.ReachToleranceSeconds))
end
SOURCES["stub/StoreHeistReach"] = [==[
local StoreHeistService = {}
function StoreHeistService.ReachPad(player, humanoid)
	return REACH_PAD(player, humanoid)
end
return StoreHeistService
]==]
moduleScript(SERVICES, "StoreHeistService", "stub/StoreHeistReach")
local ada = join("Ada", newProfile())
advance(0.3)
local function hum(player)
	return player.Character:FindFirstChildOfClass("Humanoid")
end
-- Joueur à `distance` studs de la potion (son HumanoidRootPart 3 studs au-dessus du sol, distance en 3D).
local function at(player, position, distance)
	moveTo(player, position + Vector3.new(math.sqrt(distance * distance - 9), 3, 0))
end

section("PT potion touchée en courant")
local uid, position = spawnNear(ada, "Money")
check(uid ~= nil, "PT0 potion posée devant Ada")
local before = stock(ada, "Money")
hum(ada).WalkSpeed = 0
at(ada, position, P.PickupMaxDistance + 0.3)
pick(ada, uid)
check(stock(ada, "Money") == before and logHas("trop loin", "WARN", "server"), "PT1 arrêtée à " .. (P.PickupMaxDistance + 0.3) .. " studs : refusée (stock " .. stock(ada, "Money") .. ")")
local calls = REACH_CALLS
local pad = REACH_PAD(ada, { WalkSpeed = 29 })
REACH_CALLS = calls
hum(ada).WalkSpeed = 29
at(ada, position, P.PickupMaxDistance + pad + 1)
pick(ada, uid)
check(stock(ada, "Money") == before, "PT2 en courant à 29, " .. string.format("%.1f", P.PickupMaxDistance + pad + 1) .. " studs (au-delà de la tolérance) : refusée")
at(ada, position, P.PickupMaxDistance + 0.3)
pick(ada, uid)
check(stock(ada, "Money") == before + 1, "PT3 en courant à 29, " .. (P.PickupMaxDistance + 0.3) .. " studs : ramassée (stock " .. stock(ada, "Money") .. ")")
check(REACH_CALLS >= 3, "PT4 StoreHeistService.ReachPad lu par PotionService (" .. REACH_CALLS .. " appels)")
summary("scénario potion")
