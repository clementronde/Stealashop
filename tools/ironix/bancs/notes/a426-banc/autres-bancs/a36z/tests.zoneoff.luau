--!nocheck
-- a426 (L-319) : Features.SafeZoneSpeed coupé : comme avant a426, la vitesse de la formule partout et la vitesse fixe
-- Carry.StolenItemWalkSpeed pour l'objet volé, dans la zone comme dehors.

startServer()
setStrict(true)
local Balance = sharedModule("Config/Balance")
local Features = sharedModule("Config/Features")
local MAX = Balance.Stats.MaxWalkSpeed * Balance.Stats.RealSpeedScale
local STOLEN = Balance.Carry.StolenItemWalkSpeed
local NEWBIE = Balance.Stats.BaseWalkSpeed * Balance.Stats.RealSpeedScale
local function speedOf(player)
	return humanoidOf(player).WalkSpeed
end

local adaData = newProfile()
adaData.Stats.Speed = 1e30
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
local ada = join("Ada", adaData)
local bobData = newProfile()
bobData.Stats.Strength = 10000
local bob = join("Bob", bobData)
advance(1)

section("O1 Interrupteur coupé : la formule dans la zone")
check(Features.SafeZoneSpeed == false, "O1a Features.SafeZoneSpeed coupé")
check(near(speedOf(ada), MAX, 1e-3), `O1b Ada dans sa boutique : {MAX} (lu {speedOf(ada)})`)
check(near(speedOf(bob), NEWBIE, 1e-3), `O1c Bob dans sa boutique : {NEWBIE} (lu {speedOf(bob)})`)

section("O2 Vol : vitesse fixe dans la zone, comme avant")
check(breakDoor(bob, shopOf(ada)), "O2a porte d'Ada cassée")
check(steal(bob, shopOf(ada), 1), "O2b Bob porte la canette")
advance(0.6)
check(near(speedOf(bob), STOLEN, 1e-3), `O2c Bob porte dans la zone : {STOLEN} (lu {speedOf(bob)})`)
check(strikes(ada) == 0 and strikes(bob) == 0, "O2d aucune détection")

summary("scénario zoneoff")
