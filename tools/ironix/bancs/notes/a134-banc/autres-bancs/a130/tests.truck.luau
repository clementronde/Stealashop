--!nocheck
-- a130 (vague 39) : FortuneTowerService.Force (Spawn, Open, Seal) et pas de camion tant qu'une vitrine est
-- en jeu. Studio, Features.FortuneTower = false (livré), camion allumé. Mise en place du banc a123 (a27 copie a51).
local Fortune = serverModule("FortuneTowerService")
local TruckEvent = sharedModule("Config/TruckEvent")
local FortuneTower = sharedModule("Config/FortuneTower")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(-40, 3, 0))
spawnCharacter(B, Vector3.new(-40, 3, 4))
local function trucks()
	local n = 0
	for _, t in CollectionService:GetTagged("EventTruck") do
		if t:IsDescendantOf(Workspace) then
			n += 1
		end
	end
	return n
end

section("F1. Force sans vitrine")
local ok, msg = Fortune.Force("Open")
check(ok == false and msg == "No closed Fortune vault in play.", `F1a Open sans vitrine refusé ({msg})`)
ok, msg = Fortune.Force("Seal")
check(ok == false, "F1b Seal sans vitrine refusé")
ok, msg = Fortune.Force("Dance")
check(ok == false and msg == "Unknown Fortune Tower action.", "F1c action inconnue refusée")

section("F2. Une vitrine en jeu : aucun camion")
ok, msg = Fortune.Force("Spawn")
flush()
check(ok == true and msg == "Fortune vault 1 spawned", `F2a Spawn ({tostring(ok)}, {msg})`)
check(#vaults() == 1 and trucks() == 0, "F2b une vitrine, pas de camion")
local waited, always, gap = 0, true, false
local chunk = FortuneTower.Lifetime - 20
while waited < TruckEvent.SpawnIntervalMax + 30 do
	advance(chunk, 1)
	waited += chunk
	if #vaults() ~= 1 then
		gap = true
	end
	if trucks() > 0 then
		always = false
	end
	Fortune.Force("Spawn") -- une nouvelle vitrine remplace l'ancienne sans trou
	flush()
end
check(not gap, "F2c une vitrine en jeu tout du long")
check(always, `F2d aucun camion en {waited} s (camion dû au plus tard à {TruckEvent.SpawnIntervalMax} s)`)

section("F3. Seal : le camion dû arrive")
ok, msg = Fortune.Force("Seal")
flush()
check(ok == true and string.find(msg, "sealed", 1, true) ~= nil and #vaults() == 0, `F3a Seal ({msg})`)
advance(0.5, 0.1)
check(trucks() == 1, `F3b le camion dû apparaît dès la vitrine refermée ({trucks()})`)

section("F4. Spawn remplace, Open ouvre")
ok = Fortune.Force("Spawn")
flush()
local v = currentVault()
check(ok and v ~= nil, "F4a Spawn forcé même avec un camion en jeu")
ok, msg = Fortune.Force("Spawn")
flush()
check(ok and #vaults() == 1 and currentVault() ~= v, "F4b un deuxième Spawn remplace la vitrine")
ok, msg = Fortune.Force("Open")
flush()
check(ok and string.find(msg, "opened", 1, true) ~= nil, `F4c Open ({msg})`)
check(#fortuneDrops() > 0, `F4d butin au sol ({#fortuneDrops()})`)
ok = Fortune.Force("Open")
check(ok == false, "F4e Open sur une vitrine déjà ouverte refusé")

summary("scénario truck")
