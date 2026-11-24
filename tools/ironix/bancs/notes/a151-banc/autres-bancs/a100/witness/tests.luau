-- Scénarios du banc a100 (vague 30, L-111 : témoins et police).

local vec = Vector3.new
local Witness = requireShared("Shared.Config.Witness")
local Zones = requireShared("Shared.Config.Zones")
local Animations = requireShared("Shared.Contract.Animations")
local Models = requireShared("Shared.Contract.Models")
local UI = requireShared("Shared.Contract.UI")
local Gauge = requireShared("Shared.WitnessGauge")

-- 0. Contrat, config et calcul de la jauge ------------------------------------------------------
do
	local call = nil
	for _, spec in Animations.Witness do
		if spec.Name == "CallPolice" then
			call = spec
		end
	end
	check("0 CallPolice au contrat, en boucle, marqueur Call", call ~= nil and call.Loop == true and call.Marker == "Call")
	check("0 Models.Witness : préfixe NPC_Witness", Models.Witness ~= nil and Models.Witness.Prefix == "NPC_Witness" and Models.Witness.Class == "Model")
	local head, required = nil, 0
	for _, part in Models.Witness.Parts do
		if part.Name == "WitnessHead" then
			head = part
		elseif not part.Optional then
			required += 1
		end
	end
	check("0 WitnessHead facultatif (pas de ligne rouge s'il manque)", head ~= nil and head.Optional == true and head.Class == "Attachment")
	check("0 seul HumanoidRootPart est obligatoire sur un témoin", required == 1 and Models.Witness.Attributes == nil)
	check("0 Models.Police : NPC_Police attendu", Models.Police.Names[1] == "NPC_Police" and Models.Police.Expected[1] == "NPC_Police")
	local series = Models.WitnessPaths.Parts[1]
	check("0 Models.WitnessPaths : WitnessPath_NN, 2 au moins", Models.WitnessPaths.Names[1] == "WitnessPaths" and series.Name == "WitnessPath_%02d" and series.Min == 2 and series.To >= 28 and series.Class == "Attachment")
	local at = {}
	for index, spec in Models.List do
		at[spec.Key] = index
	end
	check("0 les 3 specs sont dans le rapport, avant les comptoirs", at.Witness and at.Police and at.WitnessPaths and at.WitnessPaths < at.WeaponShopCounter and at.Witness < at.Police)
	local bb = nil
	for _, screen in UI.Billboards do
		if screen.Name == "BB_Witness" then
			bb = screen
		end
	end
	local paths = {}
	for _, element in (if bb then bb.Elements else {}) do
		paths[element.Path] = element
	end
	check("0 BB_Witness au contrat UI (Mark, Fill, FillMark, Alert, PhoneIcon)", bb ~= nil and bb.Class == "BillboardGui" and paths["Mark"] and paths["Mark.Fill"] and paths["Mark.Fill.FillMark"] and paths["Alert"] and paths["Alert.PhoneIcon"])

	check("0 FillTime = 8 s (Clément)", Witness.FillTime == 8)
	check("0 valueAt : moitié à 4 s", near(Gauge.valueAt(0, 1 / 8, 10, 14), 0.5))
	check("0 valueAt borné à 1 et à 0", Gauge.valueAt(0.9, 1, 0, 5) == 1 and Gauge.valueAt(0.2, -1, 0, 5) == 0)
	check("0 valueAt : pas de retour en arrière avant l'écriture", Gauge.valueAt(0.3, 1, 10, 9) == 0.3)
	check("0 timeLeft", near(Gauge.timeLeft(0.5, 1 / 8), 4) and near(Gauge.timeLeft(0.5, -1), 0.5) and Gauge.timeLeft(0.5, 0) == math.huge)
	check("0 couleur : jaune sous 50 %", Gauge.stage(0) == 1 and Gauge.stage(0.49) == 1 and Gauge.color(0.2).Hex == "FFD84A")
	check("0 couleur : orange dès 50 %", Gauge.stage(0.5) == 2 and Gauge.stage(0.79) == 2 and Gauge.color(0.6).Hex == "FF8C1A")
	check("0 couleur : rouge dès 80 %", Gauge.stage(0.8) == 3 and Gauge.stage(1) == 3 and Gauge.color(0.9).Hex == "E8413C")
	local bare = node("Model", "Bare")
	local state, value = Gauge.read(bare, 5)
	check("0 read sans attribut : Stroll, 0", state == "Stroll" and value == 0)
end

-- Monde ---------------------------------------------------------------------------------------------
local map = node("Folder", "Map", Workspace)
local inbox = node("Folder", "_INBOX_CLEMENT", Workspace)
local zone1 = node("Folder", "Zone_1", map)
local P = {
	vec(40, 0, -40),
	vec(80, 0, -40),
	vec(110, 0, -40),
	vec(110, 0, 0),
	vec(110, 0, 40),
	vec(80, 0, 40),
	vec(40, 0, 40),
	vec(40, 0, 0),
}
newPaths(zone1, P)
local kiosk = newStore("STORE_Z1_Kiosque", zone1, 1, vec(40, 5, -50))
local superette = newStore("STORE_Z1_Superette", zone1, 1, vec(110, 5, 50))
local witnesses1 = node("Folder", "Witnesses", zone1)
local w1 = newWitness("NPC_Witness_Z1_01", witnesses1, vec(78, 3, -38), "STORE_Z1_Kiosque")
local w2 = newWitness("NPC_Witness_Z1_02", witnesses1, vec(82, 3, 38), "STORE_Z1_Superette")
local zone2 = node("Folder", "Zone_2", map)
local witnesses2 = node("Folder", "Witnesses", zone2)
local wUnknown = newWitness("NPC_Witness_Z2_01", witnesses2, vec(200, 3, 0), "STORE_Z2_Nope")
local wNoAttr = newWitness("NPC_Witness_Z2_02", witnesses2, vec(210, 3, 0), nil)
local zone3 = node("Folder", "Zone_3", map)
local store3 = newStore("STORE_Z3_Electronique", zone3, 3, vec(300, 5, -20))
local w3 = newWitness("NPC_Witness_Z3_01", node("Folder", "Witnesses", zone3), vec(300, 3, 0), "STORE_Z3_Electronique", { noAnimator = true })
local wInbox = newWitness("NPC_Witness_Z9_01", inbox, vec(0, 3, 0), "STORE_Z1_Kiosque")
local wBroken = newWitness("NPC_Witness_Z4_01", map, vec(0, 3, 0), "STORE_Z1_Kiosque", { noRoot = true })
newStore("STORE_Z1_Kiosque", inbox, 1, vec(-500, 5, 0)) -- livraison pas encore posée : jamais regardée

local alice = newPlayer("Alice", vec(40, 3, -45))
local bob = newPlayer("Bob", vec(45, 3, -45))
local carol = newPlayer("Carol", vec(300, 3, -15))

local Service = loadWitness()
local CALLS = {}
Service.OnCall(function(store, suspect, police)
	table.insert(CALLS, { store = store, suspect = suspect, police = police })
end)
local function stateOf(model)
	return model:GetAttribute(Gauge.StateAttribute)
end
local function fillOf(model)
	local _, value = Gauge.read(model, Workspace.GetServerTimeNow())
	return value
end
local function humOf(model)
	return model:FindFirstChildOfClass("Humanoid")
end
local function goalOf(model)
	return rawget(humOf(model), "_goal")
end
-- Laisse finir ce qui est en cours : tous les témoins de la zone 1 en balade.
local function settle()
	for _ = 1, 40 do
		if stateOf(w1) == "Stroll" and stateOf(w2) == "Stroll" then
			return
		end
		advance(0.5)
	end
end

-- 1. Démarrage ----------------------------------------------------------------------------------------
do
	local list = tagged(Gauge.Tag)
	check("1 5 témoins de la map pris en charge (tag du code)", #list == 5, #list)
	check("1 témoin de _INBOX_CLEMENT ignoré", not wInbox:HasTag(Gauge.Tag) and stateOf(wInbox) == nil)
	check("1 témoin sans HumanoidRootPart ignoré, avec un avertissement", not wBroken:HasTag(Gauge.Tag) and hasLog("NPC_Witness_Z4_01 : Humanoid ou HumanoidRootPart manquant"))
	check("1 attributs posés : Stroll, 0, 0", stateOf(w1) == "Stroll" and w1:GetAttribute(Gauge.FillAttribute) == 0 and w1:GetAttribute(Gauge.RateAttribute) == 0 and type(w1:GetAttribute(Gauge.AtAttribute)) == "number")
	check("1 Idle jouée", playing(w1, "Idle") and playing(w3, "Idle"))
	check("1 pièces désancrées pour la partie (Head)", w1.Head.Anchored == false)
	check("1 physique au serveur", rawget(rootOf(w1), "_owner") == "server")
	check("1 états inutiles du Humanoid coupés", rawget(humOf(w1), "_states")["HumanoidStateType.FallingDown"] == false)
	check("1 Animator créé s'il manque", humOf(w3):FindFirstChildOfClass("Animator") ~= nil)
	check("1 contrat d'animations des témoins donné à AnimPlayer", ANIM_PLAYERS[w1].specs == Animations.Witness)
	check("1 magasin inconnu : avertissement, il se balade seulement", hasLog("NPC_Witness_Z2_01 : WatchedStore = « STORE_Z2_Nope »"))
	check("1 attribut WatchedStore manquant : avertissement", hasLog("NPC_Witness_Z2_02 : attribut WatchedStore manquant"))
	check("1 zone sans circuit : avertissement", hasLog("aucun point WitnessPaths/WitnessPath_NN"))
	check("1 GetState par magasin", #Service.GetState(kiosk) == 1 and Service.GetState(kiosk)[1].Witness == w1 and #Service.GetState(superette) == 1)
end

-- 2. Balade ---------------------------------------------------------------------------------------------
do
	advance(0.2)
	check("2 le témoin 01 part vers le point le plus proche (02)", goalOf(w1) == P[2], goalOf(w1) and goalOf(w1).X)
	check("2 le témoin 02 part vers le point le plus proche (06)", goalOf(w2) == P[6])
	check("2 WalkSpeed de la config", humOf(w1).WalkSpeed == Witness.WalkSpeed)
	check("2 Walk jouée au rythme du pas (6 / 10)", playing(w1, "Walk") and near(ANIM_PLAYERS[w1].speeds.Walk, 0.6))
	advance(1)
	check("2 point atteint : le 01 vise le suivant dans l'ordre (03)", goalOf(w1) == P[3])
	check("2 le 02 (numéro pair) tourne dans l'autre sens (05)", goalOf(w2) == P[5])
	-- Un tour complet : 300 studs à 6 studs/s = 50 s.
	local seen = {}
	local last = nil
	for _ = 1, 110 do
		advance(0.5)
		local goal = goalOf(w1)
		if goal ~= last then
			last = goal
			for index, point in P do
				if point == goal then
					table.insert(seen, index)
				end
			end
		end
	end
	check("2 le circuit se suit dans l'ordre et boucle (… 8, 1, 2 …)", string.sub(table.concat(seen, ","), 1, 17) == "3,4,5,6,7,8,1,2,3", table.concat(seen, ","))
	check("2 MoveTo redonné régulièrement (Humanoid.MoveTo lâche au bout de 8 s)", rawget(humOf(w1), "_moves") >= 25, rawget(humOf(w1), "_moves"))
	check("2 sans circuit : il ne marche pas", goalOf(wUnknown) == nil and not playing(wUnknown, "Walk"))

	-- Pause à un point.
	RNG_VALUE = 0
	local before = goalOf(w1)
	for _ = 1, 200 do
		advance(0.1)
		if not playing(w1, "Walk") then
			break
		end
	end
	local pausedAt = NOW
	check("2 pause à un point : Walk arrêtée, il reste sur place", not playing(w1, "Walk") and goalOf(w1) == rootOf(w1).Position and before ~= nil)
	RNG_VALUE = 0.99
	advance(Witness.PauseMin - 0.3)
	check("2 encore en pause avant PauseMin", not playing(w1, "Walk"), NOW - pausedAt)
	advance(0.6)
	check("2 il repart après la pause", playing(w1, "Walk") and goalOf(w1) ~= rootOf(w1).Position)

	-- Bloqué : il vise le point suivant.
	advance(1)
	local goal = goalOf(w1)
	humOf(w1)._blocked = true
	advance(Witness.StuckTime + 0.5)
	local nextGoal = goalOf(w1)
	humOf(w1)._blocked = nil
	local a, b = table.find(P, goal), table.find(P, nextGoal)
	check("2 bloqué StuckTime s : il vise le point suivant", a ~= nil and b == a % #P + 1, `{a} → {b}`)
end

-- 3. Premier coup : il regarde, le « ? » monte ---------------------------------------------------------
local t0
do
	local writes = w1._writes
	local writes2 = w2._writes
	hit(alice, kiosk)
	t0 = NOW
	check("3 état Watch dès le premier coup", stateOf(w1) == "Watch")
	check("3 pente : plein en 8 s", near(w1:GetAttribute(Gauge.RateAttribute), 1 / 8) and w1:GetAttribute(Gauge.FillAttribute) == 0)
	check("3 heure du serveur écrite", w1:GetAttribute(Gauge.AtAttribute) == Workspace.GetServerTimeNow())
	check("3 il s'arrête où qu'il soit", goalOf(w1) == rootOf(w1).Position and not playing(w1, "Walk"))
	local want = vec(40 - rootOf(w1).Position.X, 0, -50 - rootOf(w1).Position.Z).Unit
	local look = rootOf(w1).CFrame.LookVector
	check("3 tourné vers la vitrine, à plat", near(look.X, want.X, 1e-6) and near(look.Z, want.Z, 1e-6) and look.Y == 0)
	check("3 Look jouée", playing(w1, "Look"))
	check("3 l'autre témoin de la zone n'est pas concerné", stateOf(w2) == "Stroll" and w2._writes == writes2 and playing(w2, "Walk"))
	check("3 4 attributs écrits au changement", w1._writes == writes + 4, w1._writes - writes)
	for _ = 1, 10 do
		hit(alice, kiosk)
		hit(bob, kiosk)
	end
	check("3 les coups suivants n'écrivent rien (pas de flux réseau)", w1._writes == writes + 4)
	check("3 deux suspects retenus", Service.GetState(kiosk)[1].Suspects == 2)
	advance(4)
	check("3 à 4 s : moitié (serveur)", near(Service.GetFill(kiosk), 0.5, 0.01), Service.GetFill(kiosk))
	check("3 à 4 s : moitié (lecture client des attributs)", near(fillOf(w1), 0.5, 0.01) and stateOf(w1) == "Watch")
	check("3 il ne marche pas pendant qu'il regarde", not playing(w1, "Walk") and goalOf(w1) == rootOf(w1).Position)
end

-- 4. Vitrine cassée à temps (L-118 point 10, 2026-11-13) : le « ? » disparaît, il fuit, puis la balade reprend ----
do
	breakWindow(alice, kiosk)
	check("4 cassée : le « ? » disparaît tout de suite", stateOf(w1) == "Stroll" and fillOf(w1) == 0, fillOf(w1))
	check("4 Look arrêtée", not playing(w1, "Look"))
	check("4 il fuit (Walk accélérée tant que Flee manque), hors du circuit", playing(w1, "Walk") and table.find(P, goalOf(w1)) == nil)
	advance(Witness.FleeMaxTime + 0.5)
	check("4 il remarche vers son circuit", playing(w1, "Walk") and table.find(P, goalOf(w1)) ~= nil)
	check("4 ni police, ni message, ni son", #CHASES == 0 and #NOTIFIES == 0 and #SOUNDS == 0 and #CALLS == 0)
	check("4 suspects oubliés", Service.GetState(kiosk)[1].Suspects == 0)
	check("4 pas d'appel sans regard : casse en un coup", (function()
		hit(alice, kiosk)
		breakWindow(alice, kiosk)
		return stateOf(w1) == "Stroll"
	end)())
end

-- 5. « ? » plein : appel, police -------------------------------------------------------------------------
POLICE_TEMPLATE = node("Model", "NPC_Police", ReplicatedStorage)
local firstPolice
local secondPolice
do
	advance(Witness.FleeMaxTime + 0.5) -- la fuite de la casse en un coup du test 4 est finie
	hit(bob, kiosk)
	t0 = NOW
	advance(1)
	hit(alice, kiosk) -- la dernière à frapper
	advance(6.8)
	check("5 à 7,8 s : il regarde encore", stateOf(w1) == "Watch" and fillOf(w1) > 0.95)
	advance(0.4)
	check("5 plein : état Call (« ! »)", stateOf(w1) == "Call" and w1:GetAttribute(Gauge.FillAttribute) == 1 and w1:GetAttribute(Gauge.RateAttribute) == 0)
	check("5 CallPolice jouée, Look arrêtée", playing(w1, "CallPolice") and not playing(w1, "Look"))
	check("5 IsCalling et GetFill = 1", Service.IsCalling(kiosk) and Service.GetFill(kiosk) == 1 and not Service.IsCalling(superette))
	advance(0.3)
	check("5 avant le marqueur Call : ni son ni police", #SOUNDS == 0 and #CHASES == 0 and #NOTIFIES == 0)
	check("5 un marqueur Call branché", fireMarker(w1, "CallPolice", "Call") == 1)
	check("5 son au marqueur, sur le témoin", #SOUNDS == 1 and SOUNDS[1].name == Witness.CallSound and SOUNDS[1].at == rootOf(w1))
	-- a151 (vague 43) : deux joueurs ont frappé, deux policiers (avant : un seul, sur la dernière).
	check("5 un policier par joueur qui a frappé, lancés par GuardService", #CHASES == 2)
	local chase = CHASES[1].chase
	firstPolice = CHASES[1].model
	secondPolice = CHASES[2].model
	check("5 modèle NPC_Police de Clément, copie nommée NPC_Police_Z1", chase.Template == POLICE_TEMPLATE and chase.Name == "NPC_Police_Z1" and CHASES[2].chase.Name == "NPC_Police_Z1")
	check("5 cible : la dernière à avoir frappé d'abord, puis l'autre", chase.Target == alice and CHASES[2].chase.Target == bob)
	check("5 il arrive du bout de la rue (point le plus loin de la vitrine)", chase.Spawn.Position == P[5], `{chase.Spawn.Position.X}, {chase.Spawn.Position.Z}`)
	local second = CHASES[2].chase.Spawn.Position
	check("5 le second à côté, à SpawnSpacing studs", near((second - P[5]).Magnitude, Witness.Police.SpawnSpacing) and near(second.Y, P[5].Y), `{second.X}, {second.Z}`)
	check("5 chacun sa poursuite, même vitesse et même fin", CHASES[2].chase.MinSpeed == Zones[1].GuardSpeed and CHASES[2].chase.Keeps(bob) == true and CHASES[2].chase.Tired == true)
	check("5 vitesse fixe du vigile de jour de la zone", chase.SpeedMultiplier == 0 and chase.MinSpeed == Zones[1].GuardSpeed and chase.Zone == 1)
	check("5 policier : essoufflé à l'abandon, nommé dans la sortie", chase.Tired == true and chase.Label == "policier" and type(chase.GiveUpReason) == "string")
	check("5 message de capture", chase.CaughtMessage == Witness.Messages.Caught)
	check("5 il poursuit tout de suite", chase.Keeps(alice) == true)
	check("5 Notify aux deux joueurs vus", #NOTIFIES == 2 and NOTIFIES[1].remote == "Notify" and NOTIFIES[1].args[1] == Witness.Messages.Called and NOTIFIES[1].args[2] == "Alert" and NOTIFIES[1].player ~= NOTIFIES[2].player)
	check("5 OnCall(magasin, suspect, policier)", #CALLS == 1 and CALLS[1].store == kiosk and CALLS[1].suspect == alice and CALLS[1].police == firstPolice)
	check("5 GetPolice : les deux policiers et leur cible", #Service.GetPolice(kiosk) == 2 and Service.GetPolice(kiosk)[2].Player == bob and Service.GetPolice(kiosk)[2].Police == secondPolice)
	fireMarker(w1, "CallPolice", "Call")
	fireMarker(w1, "CallPolice", "Call")
	check("5 le marqueur revient à chaque boucle : seul le premier compte", #SOUNDS == 1 and #CHASES == 2 and #NOTIFIES == 2 and #CALLS == 1)
	local writes = w1._writes
	hit(alice, kiosk)
	check("5 un coup pendant l'appel ne change rien", stateOf(w1) == "Call" and w1._writes == writes)
	advance(2.8)
	check("5 encore au téléphone avant CallDuration", stateOf(w1) == "Call")
	advance(1.2)
	check("5 fin de l'appel : balade, « ? » vide", stateOf(w1) == "Stroll" and fillOf(w1) == 0 and not playing(w1, "CallPolice"))
	advance(0.3)
	check("5 il remarche", playing(w1, "Walk"))
	advance(Witness.Police.ChaseDuration)
	check("5 après ChaseDuration : la poursuite ne vaut plus (Keeps faux)", chase.Keeps(alice) == false)
end

-- 6. Pas de marqueur (animation pas livrée) ; un seul policier par joueur et par magasin (a151 : 3 lancés avant)
do
	firstPolice.Parent = nil -- les deux policiers sont repartis
	secondPolice.Parent = nil
	check("6 policiers repartis : GetPolice vide", #Service.GetPolice(kiosk) == 0)
	hit(alice, kiosk)
	advance(8.2)
	check("6 appel", stateOf(w1) == "Call" and #CHASES == 2)
	advance(0.6)
	check("6 sans marqueur : rien avant CallMarkerMaxWait", #CHASES == 2 and #SOUNDS == 1)
	advance(0.5)
	check("6 sans marqueur : la police part quand même", #CHASES == 3 and #SOUNDS == 2 and CHASES[3].chase.Target == alice)
	fireMarker(w1, "CallPolice", "Call")
	check("6 marqueur tardif : rien de plus", #CHASES == 3 and #SOUNDS == 2)
	settle()
	hit(alice, kiosk)
	advance(8.2)
	fireMarker(w1, "CallPolice", "Call")
	check("6 policier encore en jeu sur elle : pas de second policier pour elle", #CHASES == 3 and hasLog("un policier est déjà là pour STORE_Z1_Kiosque"))
	check("6 l'appel a quand même lieu (son, message, OnCall sans policier)", #SOUNDS == 3 and CALLS[#CALLS].police == nil and CALLS[#CALLS].suspect == nil)
	CHASES[3].model.Parent = nil
	settle()
end

-- 7. Choix du suspect -----------------------------------------------------------------------------------
do
	local function call(prepare)
		local chasesBefore = #CHASES
		prepare()
		advance(8.2)
		fireMarker(w1, "CallPolice", "Call")
		local made = {}
		for index = chasesBefore + 1, #CHASES do
			table.insert(made, CHASES[index])
		end
		for _, entry in made do
			if entry.model then
				entry.model.Parent = nil
			end
		end
		settle()
		return made
	end
	local aliceRoot = alice.Character.HumanoidRootPart
	local made = call(function()
		hit(bob, kiosk)
		advance(0.1)
		hit(alice, kiosk)
		aliceRoot.Position = vec(-150, 3, 0) -- à l'abri
	end)
	check("7 dernière à frapper en zone safe : le suivant est poursuivi", #made == 1 and made[1].chase.Target == bob)
	aliceRoot.Position = vec(40, 3, -45)

	REFUSE[alice] = true -- déjà poursuivie par un conducteur ou un policier
	made = call(function()
		hit(bob, kiosk)
		advance(0.1)
		hit(alice, kiosk)
	end)
	check("7 GuardService refuse la première : le suivant", #made == 2 and made[1].chase.Target == alice and made[1].model == nil and made[2].chase.Target == bob)
	check("7 OnCall donne celui qui est vraiment poursuivi", CALLS[#CALLS].suspect == bob and CALLS[#CALLS].police ~= nil)
	REFUSE[alice] = nil

	OVERRIDE[bob] = 12 -- joueur en tutoriel
	made = call(function()
		hit(bob, kiosk)
	end)
	check("7 vitesse du tutoriel (GetSpeedOverride)", #made == 1 and made[1].chase.MinSpeed == 12)
	OVERRIDE[bob] = nil

	bob.Character.Humanoid.Health = 0
	made = call(function()
		hit(bob, kiosk)
	end)
	check("7 suspect mort : personne à poursuivre", #made == 0 and CALLS[#CALLS].suspect == nil)
	bob.Character.Humanoid.Health = 100

	local dave = newPlayer("Dave", vec(42, 3, -45))
	local notifies = #NOTIFIES
	made = call(function()
		hit(dave, kiosk)
		advance(1)
		removePlayer(dave)
		check("7 joueur parti : oublié des suspects", Service.GetState(kiosk)[1].Suspects == 0)
	end)
	check("7 joueur parti : ni policier ni message", #made == 0 and #NOTIFIES == notifies)
end

-- 8. API pour L-112 (ouverture du colis dans le magasin) -------------------------------------------------
do
	check("8 le témoin de la supérette n'a jamais été dérangé", stateOf(w2) == "Stroll" and #animEvents(w2, "Look", "Play") == 0)
	check("8 Raise : magasin sans témoin → false", Service.Raise(node("Model", "STORE_Z9_Rien")) == false)
	check("8 Pause et Calm sans regard → false", Service.Pause(superette) == false and Service.Calm(superette) == false)
	check("8 Raise(store, joueur, 4) → true", Service.Raise(superette, bob, 4) == true)
	check("8 il regarde, pente d'un plein en 4 s", stateOf(w2) == "Watch" and near(w2:GetAttribute(Gauge.RateAttribute), 0.25) and playing(w2, "Look"))
	advance(2)
	check("8 moitié à 2 s", near(Service.GetFill(superette), 0.5, 0.01))
	check("8 Pause → true, figé", Service.Pause(superette) == true and w2:GetAttribute(Gauge.RateAttribute) == 0)
	advance(1)
	check("8 figé : la valeur ne bouge pas", near(Service.GetFill(superette), 0.5, 0.01) and near(fillOf(w2), 0.5, 0.01) and stateOf(w2) == "Watch")
	Service.Raise(superette, bob, 4)
	advance(1)
	check("8 Raise reprend là où il était", near(Service.GetFill(superette), 0.75, 0.01))
	Service.Pause(superette)
	advance(Witness.PauseTimeout - 0.5)
	check("8 en pause : toujours figé avant PauseTimeout", near(Service.GetFill(superette), 0.75, 0.01))
	advance(0.8)
	check("8 pause trop longue : il se vide tout seul", w2:GetAttribute(Gauge.RateAttribute) < 0)
	advance(1.2)
	check("8 puis balade", stateOf(w2) == "Stroll")

	Service.Raise(superette, bob, 4)
	advance(2)
	check("8 Calm → true", Service.Calm(superette) == true and w2:GetAttribute(Gauge.RateAttribute) < 0)
	advance(0.2)
	local low = Service.GetFill(superette)
	Service.Raise(superette, bob, 4)
	check("8 Raise pendant qu'il se vide : repart de la valeur du moment", near(w2:GetAttribute(Gauge.FillAttribute), low, 1e-6) and low > 0.2 and low < 0.4 and w2:GetAttribute(Gauge.RateAttribute) > 0, low)
	Service.Calm(superette)
	advance(1)
	check("8 vidé", stateOf(w2) == "Stroll" and Service.GetFill(superette) == 0)

	Service.Raise(superette)
	check("8 Raise sans durée : Witness.FillTime", near(w2:GetAttribute(Gauge.RateAttribute), 1 / Witness.FillTime))
	Service.Calm(superette)
	advance(0.5)

	local chases, sounds, calls = #CHASES, #SOUNDS, #CALLS
	Service.Raise(superette, nil, 1)
	advance(1.3)
	check("8 Raise sans suspect : appel quand même", stateOf(w2) == "Call" and Service.IsCalling(superette))
	fireMarker(w2, "CallPolice", "Call")
	check("8 sans suspect : son, pas de policier, OnCall(magasin, nil, nil)", #SOUNDS == sounds + 1 and #CHASES == chases and #CALLS == calls + 1 and CALLS[#CALLS].store == superette and CALLS[#CALLS].suspect == nil)
	check("8 Raise pendant l'appel → false", Service.Raise(superette, bob) == false)
	settle()

	Service.Raise(superette, bob, 1)
	advance(1.3)
	fireMarker(w2, "CallPolice", "Call")
	local last = CHASES[#CHASES]
	check("8 avec suspect : policier sur lui, du bout de la rue opposé", #CHASES == chases + 1 and last.chase.Target == bob and last.chase.Spawn.Position == P[1])
	last.model.Parent = nil
	settle()
end

-- 10. a151 (vague 43, Cantin) : un policier par casseur, plafond Witness.Police.MaxPerStore ----------------
do
	check("10 plafond V0 : 4 policiers par magasin, écart 3 studs", Witness.Police.MaxPerStore == 4 and Witness.Police.SpawnSpacing == 3)
	settle()
	local function targets(list)
		local names = {}
		for _, entry in list do
			table.insert(names, entry.chase.Target.Name)
		end
		return table.concat(names, ",")
	end
	local function newOnes(before)
		local list = {}
		for index = before + 1, #CHASES do
			table.insert(list, CHASES[index])
		end
		return list
	end
	local function clear(list)
		for _, entry in list do
			if entry.model then
				entry.model.Parent = nil
			end
		end
	end
	local eve = newPlayer("Eve", vec(44, 3, -46))
	local finn = newPlayer("Finn", vec(46, 3, -46))
	local gus = newPlayer("Gus", vec(48, 3, -46))

	-- Trois casseurs : trois policiers, du dernier à avoir frappé au premier, chacun à sa place.
	local before, notifies, calls = #CHASES, #NOTIFIES, #CALLS
	hit(bob, kiosk)
	advance(0.5)
	hit(eve, kiosk)
	advance(0.5)
	hit(alice, kiosk)
	advance(7.4)
	fireMarker(w1, "CallPolice", "Call")
	local made = newOnes(before)
	check("10 trois casseurs : trois policiers", #made == 3 and targets(made) == "Alice,Eve,Bob", targets(made))
	local spots = {}
	for _, entry in made do
		spots[`{entry.chase.Spawn.Position.X},{entry.chase.Spawn.Position.Z}`] = true
	end
	local distinct = 0
	for _ in spots do
		distinct += 1
	end
	check("10 trois points d'apparition différents", distinct == 3)
	check("10 un Notify à chacun des trois", #NOTIFIES == notifies + 3)
	check("10 OnCall : le premier poursuivi (la dernière à frapper)", #CALLS == calls + 1 and CALLS[#CALLS].suspect == alice and CALLS[#CALLS].police == made[1].model)
	check("10 GetPolice : trois", #Service.GetPolice(kiosk) == 3)
	check("10 sortie : trois policiers lancés", hasLog("3 policier(s) lancé(s) sur Alice, Eve, Bob"))

	-- Nettoyage : chaque policier retiré par GuardService est oublié ; aucun ne reste.
	made[2].model.Parent = nil
	check("10 un policier reparti : deux restent", #Service.GetPolice(kiosk) == 2)
	clear(made)
	check("10 tous repartis : GetPolice vide", #Service.GetPolice(kiosk) == 0)
	settle()

	-- Deux casseurs : deux policiers ; un seul : un seul (rien ne change).
	before = #CHASES
	hit(bob, kiosk)
	advance(0.2)
	hit(eve, kiosk)
	advance(8)
	fireMarker(w1, "CallPolice", "Call")
	made = newOnes(before)
	check("10 deux casseurs : deux policiers", #made == 2 and targets(made) == "Eve,Bob", targets(made))
	clear(made)
	settle()
	before = #CHASES
	hit(bob, kiosk)
	advance(8.2)
	fireMarker(w1, "CallPolice", "Call")
	made = newOnes(before)
	check("10 un seul casseur : un seul policier", #made == 1 and made[1].chase.Target == bob and made[1].chase.Spawn.Position == P[5])
	clear(made)
	settle()

	-- Cinq casseurs : plafond de 4 ; le premier à avoir frappé n'en a pas.
	before = #CHASES
	for _, player in { gus, finn, eve, bob, alice } do
		hit(player, kiosk)
		advance(0.2)
	end
	advance(7.4)
	fireMarker(w1, "CallPolice", "Call")
	made = newOnes(before)
	check("10 cinq casseurs : 4 policiers (plafond)", #made == 4 and targets(made) == "Alice,Bob,Eve,Finn", targets(made))
	check("10 plafond dans la sortie", hasLog("plafond de 4 policier(s) atteint pour STORE_Z1_Kiosque, Gus n'en a pas"))
	settle()

	-- Appel suivant, plafond déjà atteint : aucun de plus.
	before = #CHASES
	hit(gus, kiosk)
	advance(8.2)
	fireMarker(w1, "CallPolice", "Call")
	check("10 plafond atteint par les policiers en jeu : aucun de plus", #CHASES == before and hasLog("déjà 4 policier(s) pour STORE_Z1_Kiosque (plafond 4)"))
	settle()

	-- Deux repartis : l'appel suivant en lance pour les nouveaux seulement (ceux déjà poursuivis n'en ont pas d'autre).
	made[3].model.Parent = nil -- celui d'Eve
	made[4].model.Parent = nil -- celui de Finn
	before = #CHASES
	hit(gus, kiosk)
	advance(0.2)
	hit(alice, kiosk) -- déjà poursuivie par ce magasin
	advance(8)
	fireMarker(w1, "CallPolice", "Call")
	local again = newOnes(before)
	check("10 appel suivant : seulement le nouveau casseur", #again == 1 and again[1].chase.Target == gus and #Service.GetPolice(kiosk) == 3, targets(again))
	clear(made)
	clear(again)
	check("10 fin : aucun policier ne reste", #Service.GetPolice(kiosk) == 0)
	settle()
	for _, player in { eve, finn, gus } do
		removePlayer(player)
	end
end

-- 9. Zone sans circuit, modèle absent, témoin retiré -----------------------------------------------------
do
	local chases = #CHASES
	hit(carol, store3)
	check("9 zone 3 : il regarde sans avoir marché", stateOf(w3) == "Watch" and rawget(rootOf(w3), "Position") == vec(300, 3, 0))
	advance(8.2)
	fireMarker(w3, "CallPolice", "Call")
	local last = CHASES[#CHASES]
	check("9 policier de la zone 3 à la vitesse de sa zone", #CHASES == chases + 1 and last.chase.Zone == 3 and last.chase.MinSpeed == Zones[3].GuardSpeed and last.chase.Name == "NPC_Police_Z3")
	local spawn = last.chase.Spawn.Position
	check("9 sans circuit : il apparaît à côté du témoin, pieds au sol", near(spawn.X, 303) and near(spawn.Y, 0) and near(spawn.Z, 0), `{spawn.X}, {spawn.Y}, {spawn.Z}`)
	last.model.Parent = nil
	advance(5)

	POLICE_TEMPLATE = nil
	chases = #CHASES
	hit(carol, store3)
	advance(8.2)
	fireMarker(w3, "CallPolice", "Call")
	check("9 NPC_Police pas livré : pas de policier, un avertissement", #CHASES == chases and hasLog("NPC_Police absent de Assets/Guards"))
	advance(5)

	rootOf(w3).Parent = nil
	advance(0.3)
	check("9 témoin sorti du jeu : retiré, AnimPlayer détruit", ANIM_PLAYERS[w3].destroyed == true and Service.Raise(store3, carol) == false and #Service.GetState(store3) == 0)
	check("9 les autres continuent", stateOf(w1) == "Stroll" and playing(w1, "Walk"))
	check("9 aucune erreur dans la boucle", not hasLog("WARN [WitnessService] NPC_Witness_Z1"))
end

print(`banc a100 : {CHECKS} vérification(s), {FAILS} échec(s)`)
