--!nocheck
-- T. Barre de vie du camion (TruckController, L-052) : BB_TruckHP de Clément prise telle quelle
-- (taille et portée), sinon repli sur BB_WindowHP agrandie ; sous-dossier ; ni l'une ni l'autre.

local TruckEvent = sharedModule("Config/TruckEvent")

-- Portée choisie par Clément, différente du V0 du code (250) : elle doit rester la sienne.
TRUCK_BAR.MaxDistance = 300

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-113, 3, 0))
startClient(alice)

-- Copie du camion posée par le serveur : Model taggé EventTruck, PV en attributs, point HealthBarPoint.
local function spawnTruck(name, hp)
	local truck = make("Model", { Name = name })
	local root = make("Part", { Name = "Root", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(240, 0.5, 0) }, truck)
	truck.PrimaryPart = root
	make("Attachment", { Name = "HealthBarPoint", CFrame = CFrame.new(0, 18.5, 0) }, root)
	folder(truck, "Pieces")
	truck:SetAttribute("MaxHP", 1000)
	truck:SetAttribute("HP", hp or 1000)
	truck.Parent = Workspace
	addTag(truck, "EventTruck")
	flush()
	return truck
end
local function bar(name)
	return alice.PlayerGui:FindFirstChild(name)
end

section("T. BB_TruckHP livrée : prise telle quelle")
local truckA = spawnTruck("EventTruckA", 520)
local gui = bar("BB_TruckHP_EventTruckA")
check(gui ~= nil and gui:IsA("BillboardGui"), "T1 copie de BB_TruckHP chez le joueur")
check(bar("BB_WindowHP_EventTruckA") == nil, "T2 plus de copie de BB_WindowHP")
check(gui and gui.Size == UDim2.new(9, 200, 2.4, 80), `T3 taille de Clément, pas agrandie ({gui and tostring(gui.Size)})`)
check(gui and gui.MaxDistance == 300, `T4 portée de Clément (300), pas HealthBarMaxDistance ({gui and gui.MaxDistance})`)
check(gui and gui.StudsOffset == Vector3.new(0, 1, 0), "T5 décalage de Clément gardé")
check(gui and gui.Adornee == truckA:FindFirstChild("HealthBarPoint", true) and gui.Enabled == true and gui.ResetOnSpawn == false, "T6 accrochée à HealthBarPoint, visible, gardée à la réapparition")
local label = gui and gui:FindFirstChild("Label", true)
local fill = gui and gui:FindFirstChild("Fill", true)
check(label and label.Text == "520 / 1000", `T7 Label « {label and label.Text} »`)
check(fill and fill.Parent.Name == "Bar" and near(fill.Size.X.Scale, 0.52, 1e-9) and fill.Size.Y.Scale == 1, "T8 Bar.Fill à la largeur des PV, hauteur de Clément")
check(TRUCK_BAR.Parent == UI_FOLDER and TRUCK_BAR.Size == UDim2.new(9, 200, 2.4, 80) and TRUCK_BAR.MaxDistance == 300, "T9 le modèle de Clément n'a pas bougé")
check(TRUCK_BAR.Label.Text == "800 / 1K" and near(TRUCK_BAR.Bar.Fill.Size.X.Scale, 0.8, 1e-9) and TRUCK_BAR.Adornee == nil, "T10 … ni ses textes ni sa barre")
truckA:SetAttribute("HP", 130)
flush()
check(label.Text == "130 / 1000" and near(fill.Size.X.Scale, 0.13, 1e-9), `T11 coups : « {label.Text} », barre à 13 %`)
truckA:SetAttribute("ExplodedAt", Workspace:GetServerTimeNow())
advance(0.1)
check(gui.Enabled == false, "T12 cachée à l'explosion")
check(not logHas("BB_TruckHP absent", "PRINT", "client"), "T13 aucune ligne de repli")
truckA:Destroy()
flush()
check(bar("BB_TruckHP_EventTruckA") == nil, "T14 camion parti : sa barre aussi")

section("T'. Repli : BB_TruckHP pas un BillboardGui, BB_WindowHP agrandie")
TRUCK_BAR.Parent = nil
local wrong = make("Frame", { Name = "BB_TruckHP" }, UI_FOLDER)
local truckB = spawnTruck("EventTruckB", 1000)
local guiB = bar("BB_WindowHP_EventTruckB")
check(guiB ~= nil and bar("BB_TruckHP_EventTruckB") == nil, "T15 un Frame nommé BB_TruckHP ne compte pas : copie de BB_WindowHP")
check(guiB and guiB.Size == UDim2.new(8, 0, 1.2, 0), `T16 deux fois la taille de BB_WindowHP (HealthBarScale = {TruckEvent.HealthBarScale})`)
check(guiB and guiB.MaxDistance == TruckEvent.HealthBarMaxDistance, "T17 visible de loin (HealthBarMaxDistance)")
local labelB = guiB and guiB:FindFirstChild("Label", true)
check(labelB and labelB.Text == "1000 / 1000", `T18 Label « {labelB and labelB.Text} »`)
check(logCount("BB_TruckHP absent de ReplicatedStorage.Assets.UI : barre de vie du camion = copie de BB_WindowHP agrandie (L-052)", "PRINT", "client") == 1, "T19 une ligne en Studio")
check(WINDOW_BAR.Size == UDim2.new(4, 0, 0.6, 0) and WINDOW_BAR.MaxDistance == 60, "T20 le modèle BB_WindowHP n'a pas bougé")
wrong:Destroy()
truckB:Destroy()
flush()

section("T''. Ni l'une ni l'autre : pas de barre")
WINDOW_BAR.Parent = nil
local truckC = spawnTruck("EventTruckC", 1000)
local none = true
for _, child in alice.PlayerGui:GetChildren() do
	if string.find(child.Name, "EventTruckC", 1, true) then
		none = false
	end
end
check(none, "T21 pas de barre sur le camion")
check(logHas("BB_TruckHP et BB_WindowHP absents de ReplicatedStorage.Assets.UI : pas de barre de vie sur le camion", "PRINT", "client"), "T22 une ligne en Studio")
truckC:Destroy()
flush()

section("T'''. BB_TruckHP rangée dans un sous-dossier de Assets/UI")
local sub = folder(UI_FOLDER, "Event")
TRUCK_BAR.Parent = sub
local truckD = spawnTruck("EventTruckD", 250)
local guiD = bar("BB_TruckHP_EventTruckD")
check(guiD ~= nil and guiD.Size == UDim2.new(9, 200, 2.4, 80), "T23 trouvée dans Assets/UI/Event, à sa taille")
local labelD = guiD and guiD:FindFirstChild("Label", true)
check(labelD and labelD.Text == "250 / 1000", `T24 Label « {labelD and labelD.Text} »`)
check(not logHas("[TruckController]", "WARN", "client"), "T25 aucun avertissement du contrôleur")

summary("scénario camion")
