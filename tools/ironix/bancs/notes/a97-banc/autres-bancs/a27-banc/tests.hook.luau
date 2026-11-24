--!nocheck
-- F. Crochet de test (Studio) TruckSpawnNow ; points TruckSpawn ; copie vidée de ses scripts ;
-- modèle absent ; côté client, traînée V0 et pas de barre quand Clément n'a rien livré.

local Night = serverModule("NightCycleService")
local TruckEvent = sharedModule("Config/TruckEvent")
-- Un script dans le modèle de Clément (venu du Creator Store ?) : la copie n'en garde aucun.
make("Script", { Name = "Sneaky" }, TRUCK_ASSET.Pieces.Piece_02)
-- Ni traînée ni barre livrées : le client se rabat sur ses V0.
TRAIL_ASSET:Destroy()
ASSETS.UI.BB_WindowHP:Destroy()
startServer()
local A = newPlayer("Alice")
spawnCharacter(A, Vector3.new(-40, 3, 0))
startClient(A)

section("F. Crochet TruckSpawnNow")
Workspace:SetAttribute("TruckSpawnNow", 4)
flush()
local t1 = currentTruck()
check(t1 ~= nil and t1:GetAttribute("Zone") == 4 and Workspace:GetAttribute("TruckSpawnNow") == nil, "F1 4 : un camion en zone 4 tout de suite, attribut effacé")
local scripts = 0
for _, d in t1:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
check(scripts == 0, "F2 la copie est vidée de ses scripts")
check(TRUCK_ASSET.Pieces.Piece_02:FindFirstChild("Sneaky") ~= nil, "F3 le modèle de Clément n'est pas touché")
Workspace:SetAttribute("TruckSpawnNow", "5")
flush()
local t2 = currentTruck()
check(#trucks() == 1 and isDestroyed(t1) and t2:GetAttribute("Zone") == 5, "F4 \"5\" : remplacé par un camion en zone 5 (toujours un seul)")
check(#notifies("The truck drove away.") == 0, "F5 remplacé sans message")
Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
check(#truckDrops() == 12 and not hasTag(t2, "HitTarget"), "F6 Explode : 12 colis, plus de coups possibles")
check(#notifies("The truck exploded: grab the boxes!") == 1, "F7 Notify de l'explosion")
advance(0.3)
local v0Trail = nil
for _, model in truckDrops() do
	v0Trail = v0Trail or model.PrimaryPart:FindFirstChildOfClass("Trail")
end
check(v0Trail ~= nil and v0Trail.Lifetime == 0.35 and v0Trail.Attachment0 ~= nil, "F8 FX_BoxTrail pas livré : traînée V0 blanche")
check(logHas("FX_BoxTrail absent", "PRINT", "client"), "F9 … annoncée une fois en Studio")
check(A.PlayerGui:FindFirstChild("BB_WindowHP_EventTruck") == nil and logHas("BB_WindowHP absent", "PRINT", "client"), "F10 BB_WindowHP pas livré : pas de barre, une ligne")
advance(TruckEvent.RemoveDelay)
check(#trucks() == 0, "F11 copie retirée après l'explosion")
clearLog()
Workspace:SetAttribute("TruckSpawnNow", "Leave")
flush()
check(logHas("aucun camion en jeu", "WARN"), "F12 Leave sans camion : avertit")
clearLog()
Workspace:SetAttribute("TruckSpawnNow", 9)
flush()
check(logHas("attendu une zone de 1 à 6", "WARN") and #trucks() == 0, "F13 9 : avertit, rien")
Workspace:SetAttribute("TruckSpawnNow", 2.5)
flush()
check(#trucks() == 0, "F14 2.5 : rien")
Night._set("Night", 120)
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
check(#trucks() == 1, "F15 même de nuit (outil de test)")
Workspace:SetAttribute("TruckSpawnNow", " leave ")
flush()
check(#trucks() == 0 and #notifies("The truck drove away.") == 1, "F16 \" leave \" (casse et espaces ignorées) : parti, avec son message")
Night._set("Day", 450)

section("F'. Points TruckSpawn (proposition à Clément)")
local point = make("Part", {
	Name = "TruckSpawn_Z2",
	Anchored = true,
	CanCollide = false,
	Transparency = 1,
	Size = Vector3.new(1, 1, 1),
	CFrame = CFrame.new(150, 0, 8) * CFrame.Angles(0, math.rad(30), 0),
}, MAP)
point:SetAttribute("Zone", 2)
addTag(point, "TruckSpawn")
local attachmentPoint = make("Attachment", { Name = "TruckSpawn_Z5", CFrame = CFrame.new(510, 0.5, -5) }, ROAD)
attachmentPoint:SetAttribute("Zone", 5)
addTag(attachmentPoint, "TruckSpawn")
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
check(cfClose(currentTruck():GetPivot(), point:GetPivot(), 1e-6), "F17 pièce TruckSpawn de la zone 2 : pivot du camion dessus, tourné comme elle")
Workspace:SetAttribute("TruckSpawnNow", 5)
flush()
check(cfClose(currentTruck():GetPivot(), attachmentPoint.WorldCFrame, 1e-6), "F18 Attachment TruckSpawn de la zone 5 : idem")
Workspace:SetAttribute("TruckSpawnNow", 3)
flush()
local p3 = currentTruck():GetPivot().Position
check(near(p3.X, 240, 1e-6) and near(p3.Z, 0, 1e-6), "F19 zone 3 sans point : place calculée")
Workspace:SetAttribute("TruckSpawnNow", "Leave")
flush()

section("F''. Modèle absent")
TRUCK_ASSET.Parent = nil
clearLog()
Workspace:SetAttribute("TruckSpawnNow", 1)
flush()
Workspace:SetAttribute("TruckSpawnNow", 1)
flush()
check(#trucks() == 0 and logCount("ENV_Event_Truck introuvable", "WARN") == 1, "F20 ENV_Event_Truck absent : pas de camion, un seul avertissement")
TRUCK_ASSET.Parent = folder(ServerStorage, "Assets")
Workspace:SetAttribute("TruckSpawnNow", 1)
flush()
check(#trucks() == 1, "F21 rangé dans ServerStorage/Assets : trouvé aussi")

summary("scénario crochet")
