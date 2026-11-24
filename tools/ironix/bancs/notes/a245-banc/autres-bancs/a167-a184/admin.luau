-- Banc a167, partie admin : StartEvent d'un événement live (vrai AdminService, EventService bouchon du harnais a98).

local Admin = requireShared("Shared.Config.Admin")
local AdminLists = requireShared("Shared.AdminLists")
local LiveEvents = requireShared("Shared.Config.LiveEvents")

do
	check("0 StartEvent n'est plus StudioOnly", Admin.ById.StartEvent.StudioOnly ~= true)
	check("0 Events : AdminAbuse et StopLive au panel", AdminLists.Has("Events", "AdminAbuse") and AdminLists.Has("Events", Admin.StopLiveEvent))
	check("0 Events : Truck toujours là", AdminLists.Has("Events", "Truck"))
	check("0 Events : un par format + StopLive", #AdminLists.Entries("Events") == #Admin.Events + #LiveEvents.Formats + 1, #AdminLists.Entries("Events"))
end

-- 1. Serveur en ligne -----------------------------------------------------------------------------------
STUDIO = false
RANKS = { Owner = 255, Member = 10 }
local owner = newPlayer("Owner")
local member = newPlayer("Member")
loadAdmin()
do
	fire(owner, "StartEvent", nil, nil, "AdminAbuse")
	local launches = called("EventLaunch")
	check("1 admin en ligne : AdminAbuse lancé", #launches == 1 and launches[1].args[1] == "AdminAbuse")
	check("1 qui : nom et UserId", launches[1] and launches[1].args[2] == "Owner (1)", launches[1] and launches[1].args[2])
	check("1 réponse ok", lastReply()[1] == "StartEvent" and lastReply()[2] == true)
	check("1 journal d'AdminService", hasLog("Owner (1) StartEvent text=\"AdminAbuse\" : ok"))
	check("1 télémétrie AdminCommand", #called("Telemetry") == 1)

	local replies = #REPLIES
	fire(member, "StartEvent", nil, nil, "AdminAbuse")
	fire(member, "StartEvent", nil, nil, Admin.StopLiveEvent)
	check("1 non-admin : rien lancé ni arrêté", #called("EventLaunch") == 1 and #called("EventStop") == 0)
	check("1 non-admin : aucune réponse", #REPLIES == replies)

	fire(owner, "StartEvent", nil, nil, Admin.StopLiveEvent)
	check("1 StopLive : EventService.Stop", #called("EventStop") == 1 and called("EventStop")[1].args[1] == "Owner (1)")

	EVENT_OK = false
	fire(owner, "StartEvent", nil, nil, "LuckRush")
	check("1 refus d'EventService renvoyé à l'admin", lastReply()[2] == false)
	EVENT_OK = nil

	fire(owner, "StartEvent", nil, nil, "Truck")
	check("1 Truck refusé en ligne", lastReply()[2] == false and lastReply()[3] == Admin.Messages.StudioOnly and Workspace:GetAttribute("TruckSpawnNow") == nil)
	fire(owner, "StartEvent", nil, 30, "Night")
	check("1 Night refusé en ligne, SkipTo pas appelé", lastReply()[2] == false and #called("SkipTo") == 0)
	fire(owner, "StartEvent", nil, nil, "Fortune")
	check("1 Fortune refusé en ligne", lastReply()[2] == false and #called("FortuneForce") == 0)
end

-- 2. Studio : les anciens événements passent toujours --------------------------------------------------
STUDIO = true
local alice = newPlayer("Alice")
loadAdmin()
do
	fire(alice, "StartEvent", nil, 2, "Truck")
	check("2 Studio : Truck zone 2", Workspace:GetAttribute("TruckSpawnNow") == 2)
	fire(alice, "StartEvent", nil, nil, "PotionRain")
	check("2 Studio : un événement live passe par EventService", called("EventLaunch")[#called("EventLaunch")].args[1] == "PotionRain")
	fire(alice, "StartEvent", nil, nil, "Rain")
	check("2 Studio : Id inconnu", lastReply()[2] == false and lastReply()[3] == "Unknown event.")
end

print(`partie admin : {CHECKS} vérification(s), {FAILS} échec(s)`)
