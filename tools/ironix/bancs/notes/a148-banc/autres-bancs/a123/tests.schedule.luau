--!nocheck
-- C. Studio, Features.FortuneTower = true (camion coupé) : apparition automatique toutes les 40 à 60 min,
-- jamais à moins de 2 joueurs, jamais la nuit ni trop près de l'aube ou de l'alerte, jamais avec un camion.

local Night = serverModule("NightCycleService")
local FortuneTower = sharedModule("Config/FortuneTower")
setFeature("FortuneTower", true)
setFeature("TruckEvent", false)
startServer()
local A = newPlayer("Alice")
spawnCharacter(A, Vector3.new(-40, 3, 0))
startClient(A)

local spawnTimes = {}
local seen = {}
local maxVaults = 0
ON_FRAME = function()
	maxVaults = math.max(maxVaults, #vaults())
	for _, v in vaults() do
		if not seen[v] then
			seen[v] = true
			table.insert(spawnTimes, now())
		end
	end
end
local function seal()
	local v = currentVault()
	if v then
		Workspace:SetAttribute("FortuneTest", "Seal")
		flush()
	end
end

section("C1. Démarrage")
check(logHas("événement Fortune Tower : une vitrine toutes les 2400 à 3600 s", "PRINT", "server"), "C1a ligne au démarrage")

section("C2. Seul sur le serveur : jamais")
advance(65 * 60, 1)
check(#spawnTimes == 0, "C2a un seul joueur : aucune vitrine en 65 min")
local B = newPlayer("Bob")
spawnCharacter(B, Vector3.new(-40, 3, 4))
advance(0.3, 0.1)
check(#spawnTimes == 1, "C2b un deuxième joueur : la vitrine due apparaît")
local v = currentVault()
check(v and v:GetAttribute("Zone") == 6, "C2c en zone 6")
local t0 = spawnTimes[1]
seal()

section("C3. Toutes les 40 à 60 min")
advance(FortuneTower.SpawnIntervalMin - 1, 1)
check(#spawnTimes == 1, "C3a rien avant 40 min")
advance(FortuneTower.SpawnIntervalMax - FortuneTower.SpawnIntervalMin + 2, 0.5)
check(#spawnTimes == 2, "C3b une vitrine entre 40 et 60 min")
local dt = (spawnTimes[2] or 0) - t0
check(dt >= FortuneTower.SpawnIntervalMin - 0.2 and dt <= FortuneTower.SpawnIntervalMax + 0.6, `C3c écart {dt} s`)
check(maxVaults == 1, `C3d une seule à la fois ({maxVaults})`)
seal()

section("C4. Pas la nuit, pas près de l'aube")
local t1 = spawnTimes[2]
Night._set("Night", 1e6)
advance(FortuneTower.SpawnIntervalMax + 5, 1)
check(#spawnTimes == 2, "C4a la nuit : rien")
Night._set("Day", 1e6)
advance(FortuneTower.DawnDelay - 2, 0.5)
check(#spawnTimes == 2, "C4b rien dans les 30 s de l'aube")
advance(3, 0.1)
check(#spawnTimes == 3, "C4c puis elle apparaît")
seal()

section("C5. Pas trop près de l'alerte")
Night._set("Day", FortuneTower.MinDayLeft - 10)
advance(FortuneTower.SpawnIntervalMax + 5, 1)
check(#spawnTimes == 3, "C5a moins de 240 s avant l'alerte : rien")

section("C6. Pas avec un camion")
Night._set("Day", 1e6)
local fakeTruck = make("Model", { Name = "EventTruck" }, Workspace)
addTag(fakeTruck, "EventTruck")
advance(30, 0.5)
check(#spawnTimes == 3, "C6a un camion en jeu : rien")
fakeTruck:Destroy()
advance(0.3, 0.1)
check(#spawnTimes == 4, "C6b le camion parti : elle apparaît")

summary("scénario horaire")
