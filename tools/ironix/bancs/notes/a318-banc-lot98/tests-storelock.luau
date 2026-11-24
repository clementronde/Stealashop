--!nocheck
-- Banc a318, StoreLockController : le magasin fermé pour le joueur sort du streaming et revient. Le vrai rideau est
-- recaché au retour, même s'il a perdu le LocalTransparencyModifier posé par ce client (avant a318 : même objet, pas
-- recaché, le vrai rideau ouvert se voyait derrière la copie baissée). À la réouverture, il réapparaît.
local store = model({ Name = "Store_Z1_A" }, map())
store:SetAttribute("StoreId", "Z1_A")
store:SetAttribute("Zone", 1)
store:SetAttribute("ShutterClosedPivot", CFrame.new(0, 2, 0))
local shutter = part({ Name = "Shutter", Position = Vector3.new(0, 10, 0) }, store)
store:AddTag("NPCStore")
snapshot(store)

scenario("storelock")
startClientPhase()
startController("StoreLockController")
LocalPlayer:SetAttribute("ClosedStores", "Z1_A")
advance(1)
local folder = Workspace:FindFirstChild("LocalShutters")
local clone = if folder then folder:FindFirstChild("Z1_A_LocalShutter") else nil
check(clone ~= nil, "fermé pour lui : copie locale du rideau posée")
check(shutter.LocalTransparencyModifier == 1, "vrai rideau caché chez lui")
for _, lose in { false, true } do
	local how = if lose then "en perdant les changements locaux" else "en les gardant"
	streamOut(store)
	advance(0.2)
	streamIn(store, lose)
	advance(0.2)
	check(shutter.LocalTransparencyModifier == 1, `revenu du streaming ({how}) : vrai rideau toujours caché`)
	check(folder ~= nil and #folder:GetChildren() == 1, `revenu ({how}) : une seule copie locale`)
end
LocalPlayer:SetAttribute("ClosedStores", "")
advance(2)
check(shutter.LocalTransparencyModifier == 0, "rouvert : vrai rideau de nouveau visible")
check(folder ~= nil and #folder:GetChildren() == 0, "rouvert : copie locale retirée")
noErrors("storelock")
summary("storelock")
