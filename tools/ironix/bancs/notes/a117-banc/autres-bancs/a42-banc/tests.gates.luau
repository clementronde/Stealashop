--!nocheck
-- G. Arches après L-110 (a101) : plus aucun panneau (BB_ZoneGate retiré du contrat et du code), les arches
-- ne sont plus touchées, ZoneGateController les suit toujours ; StoreInfoController inchangé. Le bandeau
-- UI_ZoneBanner et la zone du joueur sont dans le banc a101.

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-100, 3, 0))
alice:SetAttribute("Damage", 0)
alice:SetAttribute("WalkSpeed", 16)
startClient(alice)
local Gates = clientModule("ZoneGateController")
local Stores = clientModule("StoreInfoController")

local function gatePanels()
	local count = 0
	for _, child in alice.PlayerGui:GetChildren() do
		if string.sub(child.Name, 1, 11) == "BB_ZoneGate" then
			count += 1
		end
	end
	return count
end
local function signsOn()
	local all = true
	for zone = 1, 6 do
		local sign = GATES[zone].SignPart
		all = all and sign.SignLeft.Enabled and sign.SignRight.Enabled
	end
	return all
end

section("G. Arches sans panneau")
advance(0.2)
check(gatePanels() == 0, "G1 aucun panneau d'arche")
check(signsOn(), "G2 SignLeft et SignRight ne sont plus touchés par le code")
check(#Gates.GetGates() == 6 and Gates.GetGates()[3].Zone == 3 and Gates.GetGates()[3].Gate == "ZoneGate_3", "G3 les 6 arches sont suivies, triées par zone")
check(Gates.GetPanels == nil, "G4 plus de GetPanels")
check(logCount("BB_ZoneGate", nil, "client") == 0, "G5 plus un mot sur BB_ZoneGate")

section("G'. Un vieux BB_ZoneGate dans Assets/UI ne fait plus rien")
buildZoneGate()
advance(0.2)
check(gatePanels() == 0 and signsOn(), "G6 aucun panneau, SurfaceGui intacts")

section("G''. Inbox, attribut Zone invalide, streaming")
local inbox = folder(Workspace, "_INBOX_CLEMENT")
local stray = make("Model", { Name = "ZoneGate_Test" })
make("Part", { Name = "SignPart", Anchored = true, Size = Vector3.new(3, 9, 69), CFrame = CFrame.new(50, 31.5, 0) }, stray)
stray:SetAttribute("Zone", 5)
stray.Parent = inbox
addTag(stray, "ZoneGate")
local bad = make("Model", { Name = "ZoneGate_Bad" })
make("Part", { Name = "Arch", Anchored = true, CFrame = CFrame.new(640, 12, 0) }, bad)
bad:SetAttribute("Zone", 9)
bad.Parent = MAP
addTag(bad, "ZoneGate")
advance(0.1)
check(#Gates.GetGates() == 6, "G7 une arche dans _INBOX_CLEMENT et une arche de zone 9 sont ignorées")
check(logCount("ZoneGate_Bad : attribut Zone invalide (9), arche ignorée", "WARN", "client") == 1, "G8 un avertissement en Studio")
GATES[4].Parent = nil
flush()
check(#Gates.GetGates() == 5, "G9 arche sortie du streaming : plus suivie")
GATES[4].Parent = MAP
advance(0.1)
check(#Gates.GetGates() == 6, "G10 de retour : suivie")
check(#Stores.GetPanels() == 12, "G11 StoreInfoController suit toujours ses 12 magasins")

summary("scénario arches")
