-- Scénarios du banc a182, partie witness (2026-11-15, vague 56, L-172 : le témoin qui filme la casse). Harnais du
-- banc a100 (copie a151, lu sur place) : vrai WitnessService ; zone safe : X < SAFE_X = -100.
--   F1 déroulé complet avec TakePhoto : il s'approche (Walk) de son poste devant la vitre, Look, appel au « ? »
--      plein (marqueur Call), puis photos (TakePhoto, un flash par marqueur Flash, jamais deux à moins de
--      MinInterval), coups et casse sans effet, arrêt à l'arrivée du policier, balade
--   F2 sans TakePhoto : pose de l'appel gardée, flash toutes les Interval s (cadence mesurée), arrêt au départ du voleur
--   F3 zone safe : le voleur s'abrite pendant les photos, arrêt ; policiers repartis : arrêt
--   F4 les autres témoins fuient toujours à la casse tant que leur « ? » n'est pas plein
--   F5 « ? » plein en chemin : il appelle là où il est ; poste sans vitre orientée (ligne vitrine → témoin)
--   F6 sans policier : arrêt au bout de MaxTime ; TakePhoto sans marqueur : secours après deux intervalles

local vec = Vector3.new
local Witness = requireShared("Shared.Config.Witness")
local Gauge = requireShared("Shared.WitnessGauge")
local Animations = requireShared("Shared.Contract.Animations")
local Models = requireShared("Shared.Contract.Models")
local PHOTO = Witness.Photo

-- 0. Contrat et config ----------------------------------------------------------------------------
do
	local photo = nil
	for _, spec in Animations.Witness do
		if spec.Name == "TakePhoto" then
			photo = spec
		end
	end
	check("0 TakePhoto au contrat des témoins : boucle, Action, marqueur Flash", photo ~= nil and photo.Loop == true and photo.Priority == "Action" and photo.Marker == "Flash")
	local fx = Models.WitnessFlash
	check("0 FX_Witness_Flash au contrat des modèles (Attachment Flash, sans Root), pas exigé", fx ~= nil and fx.Names[1] == "FX_Witness_Flash" and fx.Parts[1].Name == "Flash" and fx.Parts[1].Class == "Attachment" and fx.Expected == nil)
	local flashPoint = nil
	for _, part in Models.Witness.Parts do
		if part.Name == "FlashPoint" then
			flashPoint = part
		end
	end
	check("0 FlashPoint facultatif sur les témoins", flashPoint ~= nil and flashPoint.Optional == true and flashPoint.Class == "Attachment")
	check("0 FX_Witness_Flash dans le rapport", table.find(Models.List, fx) ~= nil)
	check("0 cadence de Clément : 0,9 s, jamais moins de 0,45 s", PHOTO.Interval == 0.9 and PHOTO.MinInterval == 0.45 and PHOTO.Enabled == true)
	check("0 attribut WitnessFlash", Gauge.FlashAttribute == "WitnessFlash")
end

-- Monde ---------------------------------------------------------------------------------------------
local map = node("Folder", "Map", Workspace)
local zone1 = node("Folder", "Zone_1", map)
local P = { vec(20, 0, -20), vec(60, 0, -20), vec(100, 0, -20), vec(100, 0, 20), vec(20, 0, 20) }
newPaths(zone1, P)
local kiosk = newStore("STORE_Z1_Kiosque", zone1, 1, vec(40, 5, -50))
-- Vitre orientée : face avant vers +Z (la rue), mince en Z.
kiosk.Window.CFrame = CFrame.lookAt(vec(40, 5, -50), vec(40, 5, -49))
kiosk.Window.Size = vec(10, 6, 0.5)
local superette = newStore("STORE_Z1_Superette", zone1, 1, vec(200, 5, -50)) -- vitre sans orientation
local witnesses = node("Folder", "Witnesses", zone1)
local w1 = newWitness("NPC_Witness_Z1_01", witnesses, vec(60, 3, -30), "STORE_Z1_Kiosque")
local w3 = newWitness("NPC_Witness_Z1_03", witnesses, vec(200, 3, 40), "STORE_Z1_Superette")
local alice = newPlayer("Alice", vec(40, 3, -45))
local bob = newPlayer("Bob", vec(44, 3, -45))
POLICE_TEMPLATE = node("Model", "NPC_Police", ReplicatedStorage)

local Service = loadWitness()

-- TakePhoto livrée ou pas : le faux AnimPlayer renvoie une piste pour les noms de HAVE.
local HAVE = { TakePhoto = true }
for _, model in { w1, w3 } do
	local p = ANIM_PLAYERS[model]
	local base = p.Play
	p.Play = function(self, name, ...)
		base(self, name, ...)
		if HAVE[name] then
			return {}
		end
		return nil
	end
end

local function stateOf(model)
	return model:GetAttribute(Gauge.StateAttribute)
end
local function infoOf(store, model)
	for _, s in Service.GetState(store) do
		if s.Witness == model then
			return s
		end
	end
	return nil
end
local function flashes(model)
	return model:GetAttribute(Gauge.FlashAttribute) or 0
end
local function goalOf(model)
	return rawget(model.Humanoid, "_goal")
end
local function moveTo(player, position)
	rootOf(player.Character).Position = position
end
local function photoSounds()
	local n = 0
	for _, s in SOUNDS do
		if s.name == PHOTO.Sound then
			n += 1
		end
	end
	return n
end
local function flatDistance(a, b)
	return vec(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function clearPolice()
	for _, entry in CHASES do
		if entry.model then
			entry.model.Parent = nil
		end
	end
end
-- Avance jusqu'au début des photos (au plus 10 s) ; renvoie l'heure du début.
local function untilFilming(store, model)
	for _ = 1, 200 do
		if infoOf(store, model).Filming then
			return NOW
		end
		advance(0.05)
	end
	return NOW
end
-- Attend la balade, au plus `limit` s.
local function settle(model, limit)
	for _ = 1, math.ceil((limit or 30) / 0.5) do
		if stateOf(model) == "Stroll" and not infoOf(kiosk, model).Filming and not infoOf(kiosk, model).Approaching then
			return
		end
		advance(0.5)
	end
end

-- F1. Déroulé complet avec TakePhoto ------------------------------------------------------------------
local spot = vec(38, 3, -42) -- 8 studs devant la vitre (+Z), décalé de 2 studs (témoin impair : à droite)
do
	hit(alice, kiosk)
	local info = infoOf(kiosk, w1)
	check("F1 premier coup : Watch, il s'approche", stateOf(w1) == "Watch" and info.Approaching == true and info.Filming == false)
	check("F1 il marche vers son poste devant la vitre", goalOf(w1) ~= nil and flatDistance(goalOf(w1), spot) < 1e-6, goalOf(w1) and `{goalOf(w1).X}, {goalOf(w1).Z}`)
	check("F1 Walk, au pas pressé (ApproachSpeed)", playing(w1, "Walk") and w1.Humanoid.WalkSpeed == PHOTO.ApproachSpeed and not playing(w1, "Look"))
	check("F1 le « ? » monte pendant la marche", w1:GetAttribute(Gauge.RateAttribute) > 0)
	advance(3)
	info = infoOf(kiosk, w1)
	check("F1 arrivé : il regarde (Look), ne marche plus", info.Approaching == false and playing(w1, "Look") and not playing(w1, "Walk"))
	check("F1 posté à Distance studs de la vitre", flatDistance(rootOf(w1).Position, spot) <= Witness.PointReached, flatDistance(rootOf(w1).Position, spot))
	local look = rootOf(w1).CFrame.LookVector
	local want = vec(40 - rootOf(w1).Position.X, 0, -50 - rootOf(w1).Position.Z).Unit
	check("F1 tourné vers la vitre", math.abs(look.X - want.X) < 1e-6 and math.abs(look.Z - want.Z) < 1e-6)
	check("F1 trace : à son poste", hasLog("est à son poste devant la vitrine"))
	hit(bob, kiosk)
	advance(5.3)
	check("F1 « ? » plein : appel (CallPolice)", stateOf(w1) == "Call" and playing(w1, "CallPolice") and not playing(w1, "Look"))
	fireMarker(w1, "CallPolice", "Call")
	check("F1 marqueur Call : la police part (un policier par voleur)", #CHASES == 2)
	-- Les policiers arrivent du bout de la rue : loin de la vitre.
	for _, entry in CHASES do
		node("Part", "HumanoidRootPart", entry.model).Position = vec(100, 3, 20)
	end
	untilFilming(kiosk, w1)
	info = infoOf(kiosk, w1)
	check("F1 l'appel fini : il filme", info.Filming == true and stateOf(w1) == "Stroll")
	check("F1 TakePhoto en boucle, CallPolice arrêtée", playing(w1, "TakePhoto") and not playing(w1, "CallPolice"))
	check("F1 pas de balade pendant les photos", not playing(w1, "Walk") and flatDistance(rootOf(w1).Position, spot) <= Witness.PointReached)
	check("F1 IsCalling faux, GetFill 0 (le « ! » s'efface)", Service.IsCalling(kiosk) == false and Service.GetFill(kiosk) == 0)
	check("F1 trace : il prend des photos", hasLog("prend des photos (TakePhoto)"))
	local before = flashes(w1)
	fireMarker(w1, "TakePhoto", "Flash")
	check("F1 marqueur Flash : un flash (WitnessFlash + 1)", flashes(w1) == before + 1 and infoOf(kiosk, w1).Flashes == before + 1)
	check("F1 son d'appareil photo sur le témoin", photoSounds() == 1 and SOUNDS[#SOUNDS].at == rootOf(w1))
	advance(0.2)
	fireMarker(w1, "TakePhoto", "Flash")
	check("F1 deux marqueurs à 0,2 s : un seul flash (MinInterval)", flashes(w1) == before + 1)
	advance(0.3)
	fireMarker(w1, "TakePhoto", "Flash")
	check("F1 à 0,5 s : second flash", flashes(w1) == before + 2 and photoSounds() == 2)
	advance(2)
	check("F1 les marqueurs donnent le rythme : pas de flash de secours", flashes(w1) == before + 2)
	hit(alice, kiosk)
	check("F1 un coup pendant les photos : pas de « ? »", stateOf(w1) == "Stroll" and infoOf(kiosk, w1).Filming == true)
	breakWindow(alice, kiosk)
	advance(0.2)
	check("F1 la casse ne le fait pas fuir (il filme)", infoOf(kiosk, w1).Filming == true and not playing(w1, "Walk"))
	check("F1 policier encore loin : il filme toujours", infoOf(kiosk, w1).Filming == true)
	CHASES[1].model.HumanoidRootPart.Position = vec(45, 3, -40)
	advance(0.2)
	check("F1 le policier arrive : fin des photos", infoOf(kiosk, w1).Filming == false and not playing(w1, "TakePhoto"))
	check("F1 trace : le policier est arrivé", hasLog("arrête les photos (le policier est arrivé)"))
	advance(0.3)
	check("F1 il reprend sa balade (point du circuit le plus proche)", playing(w1, "Walk") and goalOf(w1) == P[1], goalOf(w1) and `{goalOf(w1).X}, {goalOf(w1).Z}`)
	check("F1 suspects oubliés", infoOf(kiosk, w1).Suspects == 0)
	clearPolice()
	settle(w1)
end

-- F2. Sans TakePhoto : pose de l'appel, flash au rythme de 0,9 s, arrêt au départ du voleur ----------------
do
	HAVE.TakePhoto = nil
	moveTo(alice, vec(40, 3, -45))
	hit(alice, kiosk)
	advance(8.2)
	fireMarker(w1, "CallPolice", "Call")
	check("F2 appel, un policier", stateOf(w1) == "Call" and CHASES[#CHASES].model ~= nil)
	local filmAt = untilFilming(kiosk, w1)
	check("F2 il filme sans TakePhoto : il garde la pose de l'appel", infoOf(kiosk, w1).Filming == true and playing(w1, "CallPolice"))
	check("F2 trace : TakePhoto pas livrée", hasLog("TakePhoto pas livrée : pose de l'appel"))
	local start = flashes(w1)
	local times = {}
	local last = start
	for _ = 1, 100 do -- 5 s
		advance(0.05)
		if flashes(w1) ~= last then
			last = flashes(w1)
			table.insert(times, NOW)
		end
	end
	local okRhythm = #times >= 5
	local gaps = {}
	for index = 2, #times do
		local gap = times[index] - times[index - 1]
		table.insert(gaps, string.format("%.2f", gap))
		if gap < PHOTO.MinInterval or math.abs(gap - PHOTO.Interval) > 0.11 then
			okRhythm = false
		end
	end
	check("F2 un flash toutes les 0,9 s environ (5 en 5 s)", okRhythm and #times == 5, table.concat(gaps, " "))
	check("F2 premier flash Interval s après le début des photos", #times > 0 and math.abs(times[1] - filmAt - PHOTO.Interval) <= 0.11)
	moveTo(alice, vec(40, 3, -45 + PHOTO.LeaveDistance + 20)) -- elle s'éloigne de la vitre
	advance(0.2)
	check("F2 le voleur part : fin des photos", infoOf(kiosk, w1).Filming == false and not playing(w1, "CallPolice"))
	check("F2 trace : le voleur est parti", hasLog("arrête les photos (le voleur est parti)"))
	local count = flashes(w1)
	advance(2)
	check("F2 plus de flash après", flashes(w1) == count)
	clearPolice()
	settle(w1)
	HAVE.TakePhoto = true
end

-- F3. Zone safe, puis police repartie ----------------------------------------------------------------------
do
	moveTo(alice, vec(40, 3, -45))
	hit(alice, kiosk)
	advance(8.2)
	fireMarker(w1, "CallPolice", "Call")
	advance(Witness.CallDuration)
	check("F3 il filme", infoOf(kiosk, w1).Filming == true)
	moveTo(alice, vec(-150, 3, -45)) -- à l'abri en zone safe
	advance(0.2)
	check("F3 voleur à l'abri en zone safe : fin des photos", infoOf(kiosk, w1).Filming == false and not playing(w1, "TakePhoto"))
	clearPolice()
	settle(w1)

	moveTo(alice, vec(40, 3, -45))
	hit(alice, kiosk)
	advance(8.2)
	fireMarker(w1, "CallPolice", "Call")
	advance(Witness.CallDuration)
	check("F3b il filme, un policier en jeu", infoOf(kiosk, w1).Filming == true and #Service.GetPolice(kiosk) == 1)
	advance(1)
	clearPolice() -- le policier a fini (capture ailleurs, fondu)
	advance(0.2)
	check("F3b tous les policiers repartis : fin des photos", infoOf(kiosk, w1).Filming == false)
	check("F3b trace : la police est repartie", hasLog("arrête les photos (la police est repartie)"))
	settle(w1)
end

-- F4. Les autres témoins fuient toujours à la casse ------------------------------------------------------
do
	moveTo(alice, vec(40, 3, -45))
	hit(alice, kiosk)
	advance(2)
	check("F4 il s'approche", infoOf(kiosk, w1).Approaching == true or playing(w1, "Look"))
	breakWindow(alice, kiosk)
	check("F4 casse avant le « ? » plein : il fuit (Flee reste)", stateOf(w1) == "Stroll" and infoOf(kiosk, w1).Approaching == false and infoOf(kiosk, w1).Filming == false and playing(w1, "Walk") and table.find(P, goalOf(w1)) == nil)
	advance(Witness.FleeMaxTime + 0.5)
	check("F4 puis il remarche vers son circuit", playing(w1, "Walk") and table.find(P, goalOf(w1)) ~= nil)
	settle(w1)
end

-- F5. « ? » plein en chemin ; vitre sans orientation ---------------------------------------------------------
do
	local carol = newPlayer("Carol", vec(200, 3, -45))
	local start = rootOf(w3).Position
	hit(carol, superette)
	local goal = goalOf(w3)
	local window = vec(200, 5, -50)
	check("F5 vitre sans orientation : poste sur la ligne vitrine → témoin, à Distance studs", goal ~= nil and math.abs(flatDistance(goal, window) - math.sqrt(PHOTO.Distance ^ 2 + PHOTO.SideOffset ^ 2)) < 1e-6, goal and flatDistance(goal, window))
	check("F5 il part de loin (plus de 80 studs)", flatDistance(start, goal) > 80, flatDistance(start, goal))
	w3.Humanoid.WalkSpeed = 0 -- pas d'élan (il n'arrivera pas à temps)
	w3.Humanoid._blocked = true
	advance(Witness.StuckTime + 0.3)
	w3.Humanoid._blocked = nil
	check("F5 bloqué StuckTime s : il s'arrête et regarde", infoOf(superette, w3).Approaching == false and playing(w3, "Look"))
	-- Nouveau départ : « ? » plein en marchant (Raise d'un plein en 1 s).
	rootOf(w3).Position = vec(200, 3, 60)
	Service.Calm(superette)
	advance(2)
	Service.Raise(superette, carol, 1)
	advance(0.3)
	check("F5b il marche vers son poste", infoOf(superette, w3).Approaching == true)
	advance(1)
	check("F5b « ? » plein en chemin : il appelle là où il est", stateOf(w3) == "Call" and infoOf(superette, w3).Approaching == false and not playing(w3, "Walk") and playing(w3, "CallPolice"))
	check("F5b il s'est arrêté", goalOf(w3) == rootOf(w3).Position)
	clearPolice()
	advance(Witness.CallDuration + 1)
	removePlayer(carol)
	advance(0.3)
end

-- F6. Sans policier : MaxTime ; TakePhoto sans marqueur : secours après deux intervalles ----------------------
do
	POLICE_TEMPLATE = nil
	moveTo(alice, vec(40, 3, -45))
	hit(alice, kiosk)
	advance(8.2)
	fireMarker(w1, "CallPolice", "Call")
	untilFilming(kiosk, w1)
	check("F6 il filme sans policier", infoOf(kiosk, w1).Filming == true and #Service.GetPolice(kiosk) == 0)
	local start = flashes(w1)
	advance(PHOTO.Interval * 2 - 0.15)
	check("F6 TakePhoto sans marqueur : rien avant deux intervalles", flashes(w1) == start)
	advance(0.3)
	check("F6 puis le flash de secours", flashes(w1) == start + 1)
	advance(PHOTO.MaxTime - PHOTO.Interval * 2 - 0.5)
	check("F6 encore en train de filmer avant MaxTime", infoOf(kiosk, w1).Filming == true)
	advance(0.8)
	check("F6 au bout de MaxTime : fin des photos", infoOf(kiosk, w1).Filming == false and hasLog("arrête les photos (temps écoulé)"))
	check("F6 aucune erreur dans la boucle", not hasLog("WARN [WitnessService] NPC_Witness"))
end

print(`banc a182 witness : {CHECKS} vérification(s), {FAILS} échec(s)`)
