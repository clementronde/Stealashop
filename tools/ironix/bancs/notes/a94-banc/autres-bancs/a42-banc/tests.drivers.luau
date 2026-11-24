--!nocheck
-- D. Conducteurs du camion (L-071, point 7) : avec une animation Idle dans leur dossier Animations,
-- le serveur la joue (Animator du Humanoid, créé s'il manque), seule leur racine est ancrée et leurs
-- membres reliés par les articulations restent libres ; sans Idle, tout reste ancré et rien ne joue.
-- Le reste du camion est ancré comme avant, scripts retirés.

startServer()

local function spawn(zone)
	Workspace:SetAttribute("TruckSpawnNow", zone)
	flush()
	return trucks()[1]
end
local function playsOn(rig)
	local animator = rig.Humanoid:FindFirstChildOfClass("Animator")
	local out = {}
	for _, entry in ANIM_LOG do
		if entry.animator == animator then
			table.insert(out, entry)
		end
	end
	return out
end

section("D. Conducteurs avec Idle")
-- Un script laissé dans un conducteur est retiré (jamais de script dans un modèle).
make("Script", { Name = "OldAnimate" }, TRUCK_ASSET.Drivers.Driver)
-- Le passager arrive sans Animator : le serveur en crée un.
TRUCK_ASSET.Drivers.CoDriver.Humanoid.Animator:Destroy()
local truck = spawn(3)
local driver = truck.Drivers.Driver
local coDriver = truck.Drivers.CoDriver
check(driver:FindFirstChild("OldAnimate") == nil, "D1 script du conducteur retiré")
local plays = playsOn(driver)
check(#plays == 1 and plays[1].name == "Idle" and plays[1].id == "rbxassetid://555001", `D2 Idle jouée sur l'Animator du conducteur ({#plays})`)
check(coDriver.Humanoid:FindFirstChildOfClass("Animator") ~= nil and #playsOn(coDriver) == 1, "D3 passager sans Animator : créé côté serveur, Idle jouée")
check(driver.HumanoidRootPart.Anchored == true, "D4 racine ancrée (le conducteur ne tombe pas)")
check(driver.UpperTorso.Anchored == false and driver.Head.Anchored == false, "D5 torse et tête libres, tenus par leurs Motor6D (l'animation peut les bouger)")
check(driver.Hat.Anchored == true, "D6 pièce reliée à rien : reste ancrée (elle tomberait)")
local others = true
for _, d in truck:GetDescendants() do
	if d:IsA("BasePart") and not d:IsDescendantOf(truck.Drivers) and not d.Anchored then
		others = false
	end
end
check(others, "D7 toutes les autres pièces du camion restent ancrées")
check(TRUCK_ASSET.Drivers.Driver.UpperTorso.Anchored == true and TRUCK_ASSET.Drivers.Driver:FindFirstChild("OldAnimate") ~= nil, "D8 le modèle de Clément n'est pas touché (seule la copie change)")

section("D'. Explosion : rien ne casse")
Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
check(driver.UpperTorso.CanCollide == false and driver.HumanoidRootPart.CanQuery == false, "D9 explosion : collisions des conducteurs coupées, comme les pièces")
advance(5)
check(truck.Parent == nil, "D10 copie retirée après RemoveDelay")

section("D''. Conducteurs sans Idle : immobiles")
for _, rig in TRUCK_ASSET.Drivers:GetChildren() do
	rig.Animations:Destroy()
end
local before = #ANIM_LOG
local still = spawn(4)
check(#ANIM_LOG == before, "D11 sans Idle : aucune animation jouée")
local anchored = true
for _, d in still:GetDescendants() do
	if d:IsA("BasePart") and not d.Anchored then
		anchored = false
	end
end
check(anchored, "D12 toutes les pièces ancrées, conducteurs compris")
check(logCount("", "WARN", "server") == 0, "D13 aucun avertissement côté serveur")

summary("scénario conducteurs")
