-- Banc a130 (vague 39) : commandes d'admin de la Fortune Tower (StartEvent Fortune, FortuneOpen, FortuneSeal) et
-- camion refusé pendant une vitrine. Faux Roblox et bouchons du banc a98 (harness.luau, lu sur place).
local Admin = requireShared("Shared.Config.Admin")
local AdminLists = requireShared("Shared.AdminLists")

do
	check("A0 Events : Fortune, FortuneOpen, FortuneSeal", AdminLists.Has("Events", "Fortune") and AdminLists.Has("Events", "FortuneOpen") and AdminLists.Has("Events", "FortuneSeal"))
	check("A0 Events : Truck, Night, Day gardés en tête", Admin.Events[1] == "Truck" and Admin.Events[2] == "Night" and Admin.Events[3] == "Day")
end

-- En ligne : StartEvent reste StudioOnly, même pour la Fortune Tower.
STUDIO = false
RANKS = { Owner = 255, Member = 10 }
local owner = newPlayer("Owner")
local member = newPlayer("Member")
loadAdmin()
do
	fire(member, "StartEvent", nil, nil, "Fortune")
	check("A1 non-admin : Force pas appelé", #called("FortuneForce") == 0)
	fire(owner, "StartEvent", nil, nil, "Fortune")
	check("A1 en ligne : refusé (Studio only)", lastReply()[2] == false and lastReply()[3] == Admin.Messages.StudioOnly and #called("FortuneForce") == 0)
	removePlayer(owner)
	removePlayer(member)
end

STUDIO = true
CALLS = {}
local alice = newPlayer("Alice")
loadAdmin()
do
	fire(alice, "StartEvent", nil, nil, "Fortune")
	local r = lastReply()
	check("A2 Fortune : Force(Spawn)", #called("FortuneForce") == 1 and called("FortuneForce")[1].args[1] == "Spawn")
	check("A2 Fortune : réponse de FortuneTowerService", r[1] == "StartEvent" and r[2] == true and r[3] == "Fortune Spawn", r[3])
	fire(alice, "StartEvent", nil, nil, "FortuneOpen")
	check("A3 FortuneOpen : Force(Open)", called("FortuneForce")[2].args[1] == "Open" and lastReply()[2] == true)
	fire(alice, "StartEvent", nil, nil, "FortuneSeal")
	check("A4 FortuneSeal : Force(Seal)", called("FortuneForce")[3].args[1] == "Seal" and lastReply()[2] == true)
	FORTUNE_OK = false
	fire(alice, "StartEvent", nil, nil, "FortuneOpen")
	check("A5 refus de FortuneTowerService transmis", lastReply()[2] == false)
	FORTUNE_OK = nil
	check("A6 télémétrie des commandes acceptées seulement", #called("Telemetry") == 3, #called("Telemetry"))

	fire(alice, "StartEvent", nil, 3, "Truck")
	check("A7 Truck sans vitrine : crochet posé", Workspace:GetAttribute("TruckSpawnNow") == 3)
	Workspace:SetAttribute("TruckSpawnNow", nil)
	local vault = node("Model", "FortuneVault", Workspace)
	tag(vault, "FortuneVault")
	fire(alice, "StartEvent", nil, 3, "Truck")
	r = lastReply()
	check("A8 Truck pendant une vitrine : refusé", r[2] == false and r[3] == "A Fortune vault is in play: no truck now." and Workspace:GetAttribute("TruckSpawnNow") == nil, r[3])
	fire(alice, "StartEvent", nil, 20, "Night")
	check("A9 Night pendant une vitrine : accepté", lastReply()[2] == true)
	fire(alice, "StartEvent", nil, nil, "Fortunes")
	check("A10 nom inconnu refusé", lastReply()[3] == "Unknown event.")
end

print(`banc a130-admin : {CHECKS} vérification(s), {FAILS} échec(s)`)
