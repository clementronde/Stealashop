-- Scénarios du banc a157, partie witness (2026-11-14, vague 49, Cantin : en zone safe, plus aucun événement des
-- magasins PNJ). Harnais du banc a100 (copie a151, lu sur place) : vrai WitnessService, GuardService.IsInSafeZone
-- de remplacement (zone safe : X < SAFE_X = -100).

local vec = Vector3.new
local Witness = requireShared("Shared.Config.Witness")
local Gauge = requireShared("Shared.WitnessGauge")

local map = node("Folder", "Map", Workspace)
local zone1 = node("Folder", "Zone_1", map)
local kiosk = newStore("STORE_Z1_Kiosque", zone1, 1, vec(40, 5, -50))
local w1 = newWitness("NPC_Witness_Z1_01", node("Folder", "Witnesses", zone1), vec(60, 3, -40), "STORE_Z1_Kiosque")
local alice = newPlayer("Alice", vec(40, 3, -45))
local bob = newPlayer("Bob", vec(45, 3, -45))
POLICE_TEMPLATE = node("Model", "NPC_Police", ReplicatedStorage)

local Service = loadWitness()
local CALLS = {}
Service.OnCall(function(store, suspect, police)
	table.insert(CALLS, { store = store, suspect = suspect, police = police })
end)
local function stateOf(model)
	return model:GetAttribute(Gauge.StateAttribute)
end
local function rateOf(model)
	return model:GetAttribute(Gauge.RateAttribute)
end
local function moveTo(player, position)
	rootOf(player.Character).Position = position
end
local function notifiesTo(player)
	local n = 0
	for _, e in NOTIFIES do
		if e.player == player and e.args[1] == Witness.Messages.Called then
			n += 1
		end
	end
	return n
end
local function settle()
	for _ = 1, 60 do
		if stateOf(w1) == "Stroll" then
			return
		end
		advance(0.5)
	end
end

-- T1 : le seul suspect entre en zone safe pendant le « ? » : il se vide, aucun appel.
do
	hit(alice, kiosk)
	advance(3)
	check("T1 il regarde, le « ? » monte", stateOf(w1) == "Watch" and rateOf(w1) > 0)
	moveTo(alice, vec(-150, 3, -45))
	advance(0.3)
	check("T1 suspect à l'abri : le « ? » se vide", stateOf(w1) == "Watch" and rateOf(w1) < 0, rateOf(w1))
	check("T1 trace dans la sortie", hasLog("suspects à l'abri en zone safe, le « ? » se vide"))
	advance(10)
	check("T1 aucun appel ni policier", #CALLS == 0 and #CHASES == 0 and #SOUNDS == 0 and stateOf(w1) == "Stroll")
	moveTo(alice, vec(40, 3, -45))
	settle()
end

-- T2 : à l'abri pendant l'appel, avant le marqueur Call : appel coupé, ni son, ni police, ni Notify, ni OnCall.
do
	hit(alice, kiosk)
	advance(8.3)
	check("T2 « ! » : au téléphone", stateOf(w1) == "Call" and playing(w1, "CallPolice"))
	moveTo(alice, vec(-150, 3, -45))
	advance(0.3)
	check("T2 appel coupé : balade, CallPolice arrêtée", stateOf(w1) == "Stroll" and not playing(w1, "CallPolice"))
	check("T2 marqueur Call plus tard : rien", fireMarker(w1, "CallPolice", "Call") >= 1 and #SOUNDS == 0 and #CHASES == 0 and #CALLS == 0 and notifiesTo(alice) == 0)
	advance(Witness.CallDuration + 1)
	check("T2 toujours rien après CallDuration", #SOUNDS == 0 and #CHASES == 0 and #CALLS == 0)
	moveTo(alice, vec(40, 3, -45))
	settle()
end

-- T3 : deux suspects, un seul à l'abri : l'appel part, un policier et un Notify pour l'autre seulement.
do
	hit(alice, kiosk)
	advance(0.5)
	hit(bob, kiosk)
	advance(7.9)
	check("T3 « ! » : au téléphone", stateOf(w1) == "Call")
	moveTo(alice, vec(-150, 3, -45))
	advance(0.3)
	check("T3 un suspect reste dehors : l'appel continue", stateOf(w1) == "Call")
	fireMarker(w1, "CallPolice", "Call")
	check("T3 un seul policier, sur Bob", #CHASES == 1 and CHASES[1].chase.Target == bob)
	check("T3 Notify à Bob seulement", notifiesTo(bob) == 1 and notifiesTo(alice) == 0)
	check("T3 OnCall, suspect Bob", #CALLS == 1 and CALLS[1].suspect == bob)
end

-- T4 : la marque Call arrive entre deux pas, suspect déjà à l'abri mais pas encore retiré : pas de Notify pour lui.
do
	settle()
	advance(Witness.Police.ChaseDuration + 1)
	for _, entry in CHASES do
		if entry.model then
			entry.model.Parent = nil
		end
	end
	advance(1)
	moveTo(alice, vec(40, 3, -45))
	moveTo(bob, vec(45, 3, -45))
	hit(alice, kiosk)
	hit(bob, kiosk)
	advance(8.3)
	local before = notifiesTo(alice)
	moveTo(alice, vec(-150, 3, -45)) -- pas d'advance : le pas suivant ne l'a pas encore vu
	fireMarker(w1, "CallPolice", "Call")
	check("T4 Notify « Called » pas envoyé à celui à l'abri", notifiesTo(alice) == before and notifiesTo(bob) == 2)
end

print(`banc a157 witness : {CHECKS} vérification(s), {FAILS} échec(s)`)
