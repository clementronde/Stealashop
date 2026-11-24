--!nocheck
-- a204 : Features.SingleBoxReveal = false : RevealController ne se branche pas.
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(65, 3, -40))
Workspace.CurrentCamera = CAMERA
CAMERA.CameraType = Enum.CameraType.Custom
CAMERA.CFrame = CFrame.lookAt(Vector3.new(65, 8, -25), Vector3.new(65, 3, -45))
startClient(alice)
local RC = clientModule("RevealController")
section("O. Interrupteur coupé")
NET.Server.RevealStarted:FireAll(alice, STORES[1].Name, STORES[1].Name .. "/03", ITEM_A.Id, "Common", "", 1, 1, "Large", "o1")
flush()
advance(5)
check(RC.GetState().Started == 0 and #serverCalls("RevealDone") == 0, "O1 aucune scène, aucun RevealDone")
check(CAMERA.CameraType == Enum.CameraType.Custom and Workspace:FindFirstChild("_RevealFX") == nil, "O2 caméra intacte, rien créé")
STORES[1]:SetAttribute("CeilingBroken", true)
flush()
check(STORES[1].Ceiling.LocalTransparencyModifier == 0, "O3 plafond non suivi")
summary("scénario off")
