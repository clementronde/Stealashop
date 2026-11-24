---------------------------------------------------------------- outils des scénarios
local function runUntil(t, dt)
	if t > now() then
		runFor(t - now(), nil, dt)
	end
end
local function fullLogHas(pattern, kind)
	for _, line in FULL_LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, pattern, 1, true) then
			return true
		end
	end
	return false
end
local function moveToSafe(p, z)
	place(p, Vector3.new(-60, 3, z or 0))
end

---------------------------------------------------------------- N2 cycle complet
print("\nN2 : enchaînement naturel Jour → Alerte → Nuit → aube → Jour, et durées")
do
	Window.Broken["STORE_Z1_Superette"] = true
	Window.Broken["STORE_Z2_MagasinDeJouets"] = true
	local phases = {}
	local unsubscribe = NightCycle.OnPhaseChanged(function(phase, previous)
		table.insert(phases, { phase = phase, previous = previous, t = now() })
	end)
	runUntil(449.5, 0.1)
	check(attr("NightPhase") == "Day", "toujours le jour à 449,5 s")
	runUntil(450.5, 0.1)
	check(attr("NightPhase") == "Warning", "alerte à 450 s")
	local warnAt = phases[1] and phases[1].t or now()
	check(phases[1] and phases[1].phase == "Warning" and phases[1].previous == "Day", "OnPhaseChanged(Warning, Day)")
	check(near(warnAt, 450, 0.15), "alerte après 450 s de jour (8 min − 30 s)")
	check(near(attr("NightPhaseEndsAt") - (warnAt + SERVER_TIME_OFFSET), 30, 0.01), "alerte de 30 s")
	check(near(attr("NightFallsAt"), attr("NightPhaseEndsAt"), 1e-6), "pendant l'alerte, NightFallsAt = fin de l'alerte")
	local warning = notifiedSince(alice, Night.WarningText, warnAt - 0.01)
	check(warning and warning.args[2] == "Warning", "Notify « NIGHT FALLS IN 30s » à tous")
	check(#Heist.Refills == 0, "pas de remplissage pendant le jour ni l'alerte")
	runUntil(warnAt + 29.5, 0.1)
	check(attr("NightPhase") == "Warning", "toujours l'alerte 29,5 s après son début")
	runUntil(warnAt + 30.5, 0.1)
	check(attr("NightPhase") == "Night", "nuit 30 s après le début de l'alerte")
	local nightAt = phases[2] and phases[2].t or now()
	check(phases[2] and phases[2].phase == "Night" and near(nightAt, 480, 0.25), "OnPhaseChanged(Night) à 8 min")
	check(#Heist.Refills == 1 and near(Heist.Refills[1], nightAt, 0.05), "StoreHeistService.RefillAll à la tombée de la nuit (nouveau tirage)")
	check(near(attr("NightPhaseEndsAt") - (nightAt + SERVER_TIME_OFFSET), 120, 0.01), "nuit de 2 min")
	check(near(attr("NightFallsAt") - attr("NightPhaseEndsAt"), 480, 0.01), "pendant la nuit, NightFallsAt = la nuit suivante")
	check(notifiedSince(alice, "Night has fallen: the corridor is closed.", nightAt - 0.01) ~= nil, "Notify de la tombée de la nuit (joueur en zone safe)")
	check(wallPart.Position.Y > -12.2 and wallPart.Position.Y < 11.8, "le mur monte (animé)")
	runFor(Night.WallRiseTime + 0.2, nil, DT)
	check(near(wallPart.Position.Y, 11.8, 1e-6), `mur levé de 24 studs en {Night.WallRiseTime} s (haut à 23,8)`)
	check(#nightGuards() == 12, `12 vigiles de nuit (2 par zone) : {#nightGuards()}`)
	runUntil(nightAt + 119.5, 0.1)
	check(attr("NightPhase") == "Night", "toujours la nuit à 1 min 59,5")
	runUntil(nightAt + 120.5, 0.1)
	local dawnAt = phases[3] and phases[3].t or now()
	check(attr("NightPhase") == "Day" and phases[3] and phases[3].previous == "Night" and near(dawnAt, 600, 0.35), "aube à 10 min, puis le jour")
	check(#nightGuards() == 0, "vigiles de nuit partis à l'aube")
	check(fullLogHas("parti (aube)", "PRINT"), "sortie : vigiles partis (aube)")
	check(#Window.Rebuilt == 2 and table.find(Window.Rebuilt, "STORE_Z1_Superette") and table.find(Window.Rebuilt, "STORE_Z2_MagasinDeJouets"), "les 2 vitrines cassées reconstruites (WindowService.Rebuild), pas les autres")
	check(notifiedSince(alice, "Dawn: the corridor is open and the stores are full!", dawnAt - 0.01) ~= nil, "Notify de l'aube")
	check(near(attr("NightPhaseEndsAt") - (dawnAt + SERVER_TIME_OFFSET), 450, 0.01), "nouveau jour de 7 min 30")
	runFor(Night.WallLowerTime + 0.2, nil, DT)
	check(near(wallPart.Position.Y, -12.2, 1e-6), "mur redescendu à sa position livrée")
	check(#Heist.Refills == 1, "un seul remplissage par nuit")
	unsubscribe()
end

---------------------------------------------------------------- N3 mur à sens unique
print("\nN3 : passage des joueurs du couloir, personne n'entre la nuit")
local carol, dave, erin
do
	-- Profils pas encore chargés : protégés, les vigiles de nuit les ignorent (on teste le mur seul).
	carol = addPlayer("Carol", Vector3.new(30, 3, 0)) -- couloir
	dave = addPlayer("Dave", Vector3.new(12.5, 3, 0)) -- au mur, là où il va monter
	erin = addPlayer("Erin", Vector3.new(5, 3, 0)) -- côté safe, hors du volume SafeZone
	for _, p in { carol, dave, erin } do
		Plot.Homes[p] = Vector3.new(-150, 3, -60)
	end
	clearLog()
	local since = now()
	check(NightCycle.SkipTo("Night") == true, "SkipTo(Night) en Studio")
	check(attr("NightPhase") == "Night", "nuit")
	check(allIn(carol, "NightPass") and carol:GetAttribute("NightPass") == true, "Carol (couloir) : passage, toutes ses pièces dans NightPass")
	check(allIn(dave, "NightPass"), "Dave (au mur) : passage aussi (le mur monte à travers lui)")
	check(allIn(erin, "Default") and erin:GetAttribute("NightPass") == nil, "Erin (côté safe) : pas de passage")
	check(allIn(alice, "Default"), "Alice (zone safe) : pas de passage")
	check(notifiedSince(carol, "Night guards are out: get back to the safe zone!", since) ~= nil, "Notify au joueur du couloir")
	check(notifiedSince(erin, "Night has fallen: the corridor is closed.", since) ~= nil, "Notify au joueur côté safe")
	check(logHas("2 joueur(s) dans le couloir avec le passage", "PRINT"), "sortie : 2 joueurs avec le passage")

	-- Pièce ajoutée au personnage pendant la nuit (colis porté) : elle prend le passage.
	local box = part("CarryVisual", carol.Character, Vector3.new(30, 6, 0), Vector3.new(2, 2, 2))
	runFor(0.2)
	check(box.CollisionGroup == "NightPass", "pièce ajoutée la nuit (colis porté) : passage aussi")

	-- Erin passe le mur (glitch) : renvoyée chez elle.
	local calls = #Plot.Calls
	since = now()
	place(erin, Vector3.new(40, 3, 0))
	runFor(0.3)
	check(#Plot.Calls == calls + 1 and Plot.Calls[#Plot.Calls].player == erin, "Erin entrée la nuit : TeleportHome")
	check(near(rootOf(erin).Position.X, -150, 1e-6), "Erin renvoyée chez elle")
	check(notifiedSince(erin, "The corridor is closed at night.", since) ~= nil, "Notify « The corridor is closed at night. »")

	-- Carol rentre par le mur, puis ressaute dans le couloir : renvoyée.
	motion[carol] = runTo(Vector3.new(-20, 3, 0), 30)
	runFor(2)
	motion[carol] = nil
	check(allIn(carol, "Default") and carol:GetAttribute("NightPass") == nil, "Carol rentrée côté safe : passage retiré, groupes d'origine")
	calls = #Plot.Calls
	place(carol, Vector3.new(30, 3, 0))
	runFor(0.3)
	check(#Plot.Calls == calls + 1 and near(rootOf(carol).Position.X, -150, 1e-6), "Carol ressortie la nuit : renvoyée chez elle")

	-- Dave reste au mur, puis réapparaît (nouveau personnage) : il perd le passage.
	check(allIn(dave, "NightPass"), "Dave toujours au mur : garde le passage")
	local old = dave.Character
	local char = new("Model", "Dave")
	local root = part("HumanoidRootPart", char, Vector3.new(-150, 3, -60), Vector3.new(2, 2, 1))
	root.Anchored = false
	new("Humanoid", "Humanoid", char)
	char.PrimaryPart = root
	char.Parent = Workspace
	dave.Character = char
	dave.CharacterAdded:Fire(char)
	old:Destroy()
	runFor(0.2)
	check(dave:GetAttribute("NightPass") == nil and allIn(dave, "Default"), "Dave réapparu chez lui : plus de passage")

	-- Bouclier débutant : sans profil, protégé ; peu joué, protégé ; 10 min cumulées, plus protégé.
	check(NightCycle.IsShielded(carol) == true, "profil pas encore chargé : bouclier débutant (V0)")
	Data.Load(carol, 0)
	runFor(0.1)
	check(NightCycle.IsShielded(carol) == true, "0 s de jeu : bouclier débutant")
	Data.Load(dave, 598.5)
	runFor(0.1)
	check(NightCycle.IsShielded(dave) == true, "598,5 s de jeu : encore protégé")
	runFor(2.5, nil, 0.1)
	check(NightCycle.IsShielded(dave) == false, "600 s de jeu cumulées (sessions passées + celle-ci) : plus protégé")

	check(NightCycle.SkipTo("Dawn") == true, "SkipTo(Dawn)")
	check(attr("NightPhase") == "Day", "aube → jour")
	local leftover = false
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("NightPass") then
			leftover = true
		end
	end
	check(not leftover and allIn(alice, "Default") and allIn(carol, "Default"), "aube : plus aucun passage")
end

---------------------------------------------------------------- N4 vigiles de nuit
print("\nN4 : vigiles de nuit, ronde, repérage au cône, capture")
do
	-- Joueurs aguerris (plus de 10 min de jeu) : les vigiles de nuit les voient. Ils sont dans le
	-- couloir avant la tombée de la nuit (sinon ils seraient renvoyés chez eux).
	local frank = addPlayer("Frank", PATROL[2][1] + Vector3.new(20, 3, 0)) -- 20 devant le vigile 1 de la zone 2
	local gina = addPlayer("Gina", PATROL[2][1] + Vector3.new(-20, 3, 0)) -- 20 derrière lui
	local hank = addPlayer("Hank", Vector3.new(PATROL[1][1].X + 45, 3, 0)) -- 45 devant le vigile 1 de la zone 1
	local ivy = addPlayer("Ivy", PATROL[4][1] + Vector3.new(20, 3, 0)) -- 20 devant, derrière un mur
	local jack = addPlayer("Jack", PATROL[5][1] + Vector3.new(15, 3, 0)) -- débutant, 15 devant
	local block = part("Block", Workspace, PATROL[4][1] + Vector3.new(10, 3, 0), Vector3.new(1, 10, 10))
	local blockBox = { cframe = block.CFrame, size = block.Size, part = block }
	table.insert(WALLS, blockBox)
	for _, p in { frank, gina, hank, ivy } do
		Data.Load(p, 5000)
		Plot.Homes[p] = Vector3.new(-200, 3, 80)
	end
	Data.Load(jack, 10)
	Plot.Homes[jack] = Vector3.new(-200, 3, 80)
	-- Frank porte un colis (magasin inconnu : pas de vigile de jour).
	Carry.StartCarry(frank, { Kind = "NPCBox", Tier = "Standard", Zone = 2, Rarity = "Common", ItemId = "Z2_YoYo", StoreId = "STORE_Inconnu", SlotId = "STORE_Inconnu/01" })
	runFor(0.1)

	clearLog()
	NightCycle.SkipTo("Night", 60)
	local g21 = guardNamed("NightGuard_Z2_1")
	local g22 = guardNamed("NightGuard_Z2_2")
	local r21 = g21 and g21:FindFirstChild("HumanoidRootPart")
	local r22 = g22 and g22:FindFirstChild("HumanoidRootPart")
	check(#nightGuards() == 12, `12 vigiles de nuit, posés tout de suite : {#nightGuards()}`)
	local okNames = true
	for zone = 1, 6 do
		for k = 1, 2 do
			if guardNamed(string.format("NightGuard_Z%d_%d", zone, k)) == nil then
				okNames = false
			end
		end
	end
	check(okNames, "noms NightGuard_Z<zone>_<n>, 2 par zone")
	check(r21 and near(flat(r21.Position - PATROL[2][1]).Magnitude, 0, 1e-6), "1er vigile de la zone 2 sur le point A")
	check(r22 and near(flat(r22.Position - PATROL[2][2]).Magnitude, 0, 1e-6), "2e vigile de la zone 2 sur le point B")
	check(r21 and r21.CFrame.LookVector.X > 0.99 and r22.CFrame.LookVector.X < -0.99, "chacun regarde vers l'autre point")
	check(r21 and near(r21.Position.Y, PATROL[2][1].Y + 3, 1e-6), "pieds au niveau du point de ronde (HipHeight 2 + demi-HumanoidRootPart)")
	local h21 = g21:FindFirstChildOfClass("Humanoid")
	check(h21.WalkSpeed == Night.PatrolSpeed, `ronde à {Night.PatrolSpeed}`)
	local light = g21:FindFirstChild("Head") and g21.Head:FindFirstChild("NightFlashlight")
	check(light and light.Range == 40 and light.Angle == 90 and light.Face == "Enum.NormalId.Front", "rig de remplacement : lampe torche (SpotLight 40 studs, 90°, vers l'avant)")
	check(g21:FindFirstChild("Animate", true) == nil, "aucun script dans le vigile de nuit")
	check(g21.ModelStreamingMode == "Enum.ModelStreamingMode.PersistentPerPlayer", "streaming : persistant pour la cible seulement")
	check(fullLogHas("NightPatrol_NoZone : point de ronde sans attribut Zone", "WARN"), "point de ronde sans Zone : avertissement")
	check(not fullLogHas("NightPatrol_Inbox", nil), "point de ronde du dépôt de Clément : ignoré sans bruit")

	runFor(0.2)
	check(g21:GetAttribute("TargetUserId") == frank.UserId, "Frank, 20 studs devant dans le cône : repéré")
	check(GuardService.IsNightChased(frank), "IsNightChased(Frank)")
	local cs = lastRemote("ChaseState", frank)
	check(cs and cs.args[1] == true and cs.args[2] == g21, "ChaseState(true, vigile de nuit) envoyé à Frank")
	check(not GuardService.IsNightChased(gina), "Gina, 20 studs derrière : hors du cône, pas repérée")
	check(not GuardService.IsNightChased(hank), "Hank à 45 studs : trop loin (40)")
	check(not GuardService.IsNightChased(ivy), "Ivy derrière un mur : pas vue")
	check(not GuardService.IsNightChased(jack), "Jack (bouclier débutant) : ignoré")
	check(logHas("NightGuard_Z2_1 : repère Frank à 20 studs, poursuite à 26", "PRINT"), "sortie : repéré, poursuite à 22 + 4")
	-- Les autres rentrent : ils ne gênent plus la suite.
	for i, p in { gina, hank, ivy, jack } do
		moveToSafe(p, 20 + 4 * i)
	end
	local before = r21.Position
	runFor(0.2)
	check(near((r21.Position - before).Magnitude, 0, 1e-6), "délai de réaction : il ne bouge pas encore")
	runFor(0.2)
	check(h21.WalkSpeed == Zones[2].AdvisedSpeed + 4, "poursuite à la vitesse conseillée + 4 (26)")

	-- Capture : Frank reste sur place.
	local caughtAt, knocked = nil, false
	local statsBefore = #Stats.Log
	runFor(3, function()
		if caughtAt == nil and #Carry.Calls > 0 and Carry.Calls[#Carry.Calls].player == frank then
			caughtAt = now()
		end
		if rootOf(frank):FindFirstChild("GuardKnockback") then
			knocked = true
		end
	end)
	local fail = Carry.Calls[#Carry.Calls]
	check(fail and fail.player == frank and fail.result == "Failed" and fail.reason == "Caught", "attrapé la nuit : CarryService.Fail(Frank, \"Caught\") (colis rendu)")
	check(knocked, "le coup du vigile (même poussée que le jour)")
	local home = nil
	for _, c in Plot.Calls do
		if c.player == frank and c.moved then
			home = c
		end
	end
	check(home and caughtAt and near(home.t - caughtAt, Night.SendHomeDelay, 0.1), "renvoyé chez lui 0,6 s après le coup (TeleportHome)")
	check(near(rootOf(frank).Position.X, -200, 1e-6), "Frank chez lui")
	local stuns = {}
	for i = statsBefore + 1, #Stats.Log do
		local e = Stats.Log[i]
		if e.player == frank and e.key == "GuardStun" then
			table.insert(stuns, e)
		end
	end
	check(stuns[1] and stuns[1].mult == 0 and caughtAt and near(stuns[1].t, caughtAt, 0.05), "immobilisé dès la capture")
	check(stuns[2] and stuns[2].mult == 0 and home and near(stuns[2].t, home.t, 0.05), "étourdi au retour à la base")
	runFor(2.2)
	local unstun = nil
	for i = statsBefore + 1, #Stats.Log do
		local e = Stats.Log[i]
		if e.player == frank and e.key == "GuardStun" and e.mult == nil then
			unstun = e
		end
	end
	check(unstun and home and near(unstun.t - home.t, Night.CaughtStunDuration, 0.05), "étourdi 2 s à partir du retour (Night.CaughtStunDuration)")
	check(caughtAt and notifiedSince(frank, "Caught by a night guard! Back to your shop.", caughtAt - 0.01) ~= nil, "Notify « Caught by a night guard! Back to your shop. »")
	local csEnd = lastRemote("ChaseState", frank)
	check(csEnd and csEnd.args[1] == false, "ChaseState(false) à la capture")
	check(logHas("NightGuard_Z2_1 : Frank attrapé, renvoyé chez lui", "PRINT"), "sortie : attrapé, renvoyé")
	check(caughtAt and not notifiedSince(frank, "Caught! Recommended speed: 22", caughtAt - 0.01), "pas le message du vigile de jour")

	-- Après la capture : il reprend sa ronde (il ne disparaît pas).
	runFor(6)
	check(g21.Parent ~= nil and g21:GetAttribute("TargetUserId") == 0, "le vigile de nuit reste en jeu après la capture")
	check(h21.WalkSpeed == Night.PatrolSpeed, "retour à l'allure de la ronde")

	-- Ronde : aller-retour entre A et B (vigile 2 de la zone 2).
	local minX, maxX = math.huge, -math.huge
	runFor(16, function()
		minX = math.min(minX, r22.Position.X)
		maxX = math.max(maxX, r22.Position.X)
	end)
	-- Un point est atteint à 3 studs (ARRIVE_DISTANCE de GuardService).
	check(maxX > PATROL[2][2].X - 3.5 and minX < PATROL[2][1].X + 3.5, `ronde de B à A et retour (x de {math.floor(minX)} à {math.floor(maxX)})`)
	check(r22.Position.X > minX + 5, "reparti vers B après la pause au point A")

	table.remove(WALLS, table.find(WALLS, blockBox))
	block:Destroy()
	NightCycle.SkipTo("Day")
end

---------------------------------------------------------------- N5 abandon : la cible passe le mur
print("\nN5 : la cible rentre par le mur, le vigile abandonne puis reprend sa ronde")
do
	-- Leo, dans le couloir avant la nuit : derrière le vigile 1 de la zone 1, devant le vigile 2.
	local leo = addPlayer("Leo", Vector3.new(44, 3, 0))
	Data.Load(leo, 5000)
	Plot.Homes[leo] = Vector3.new(-200, 3, -80)
	runFor(0.1)
	clearLog()
	NightCycle.SkipTo("Night", 60)
	-- Le mur levé cache et bloque les vigiles (rayons et pas).
	local wallBox = { cframe = CFrame.new(12, 11.8, 0), size = wallPart.Size, part = wallPart }
	table.insert(WALLS, wallBox)
	local g12 = guardNamed("NightGuard_Z1_2") -- au point B (82,5), regarde vers A (−X)
	runFor(0.2)
	check(g12:GetAttribute("TargetUserId") == leo.UserId, "Leo repéré par le vigile 2 de la zone 1 (38,5 studs)")
	check(guardNamed("NightGuard_Z1_1"):GetAttribute("TargetUserId") == 0, "le vigile 1, qui lui tourne le dos, ne le voit pas")
	check(leo:GetAttribute("NightPass") == true, "Leo était dans le couloir à la tombée de la nuit : passage")
	motion[leo] = runTo(Vector3.new(-30, 3, 0), 40)
	runFor(3)
	motion[leo] = nil
	check(logHas("NightGuard_Z1_2 : abandonne Leo (sorti du couloir)", "PRINT"), "abandon quand la cible passe côté safe")
	check(rootOf(leo).Position.X < 0, "Leo rentré en zone safe à travers le mur")
	check(g12.HumanoidRootPart.Position.X > 13, "le vigile reste côté couloir")
	runFor(8)
	check(g12.Parent ~= nil and g12:FindFirstChildOfClass("Humanoid").WalkSpeed == Night.PatrolSpeed, "le vigile reprend sa ronde")
	table.remove(WALLS, table.find(WALLS, wallBox))
	NightCycle.SkipTo("Day")
	check(#nightGuards() == 0, "aube : vigiles de nuit partis")
end

---------------------------------------------------------------- N6 course en cours
print("\nN6 : un porteur à la tombée de la nuit garde sa course")
do
	local nora = addPlayer("Nora", Vector3.new(150, 3, 0)) -- zone 2, profil pas chargé : ignorée par les vigiles
	Plot.Homes[nora] = Vector3.new(-120, 3, 90)
	Carry.StartCarry(nora, { Kind = "NPCBox", Tier = "Luxe", Zone = 2, Rarity = "Epic", ItemId = "Z2_RobotJouet", StoreId = "STORE_Inconnu", SlotId = "STORE_Inconnu/10" })
	local fails = #Carry.Calls
	NightCycle.SkipTo("Night", 60)
	runFor(0.2)
	check(Carry.IsCarrying(nora) and #Carry.Calls == fails, "la nuit tombe : le portage continue (aucun Fail)")
	check(nora:GetAttribute("NightPass") == true, "le porteur du couloir a le passage")
	motion[nora] = runTo(Vector3.new(-20, 3, 0), 40)
	runFor(5)
	motion[nora] = nil
	check(rootOf(nora).Position.X < 0 and Carry.IsCarrying(nora), "zone safe atteinte, colis toujours porté : il est à elle")
	check(nora:GetAttribute("NightPass") == nil, "passage retiré une fois rentrée")
	Carry.Consume(nora)
	NightCycle.SkipTo("Day")
end

---------------------------------------------------------------- N7 SkipTo
print("\nN7 : API de test SkipTo, Studio seulement")
do
	local since = now()
	check(NightCycle.SkipTo("Warning", 5) == true, "SkipTo(Warning, 5)")
	check(attr("NightPhase") == "Warning" and near(attr("NightPhaseEndsAt") - serverNow(), 5, 1e-6), "alerte de 5 s")
	check(notifiedSince(alice, Night.WarningText, since) ~= nil, "Notify de l'alerte")
	runFor(5.2, nil, 0.1)
	check(attr("NightPhase") == "Night", "la nuit suit l'alerte raccourcie")
	clearLog()
	check(NightCycle.SkipTo("Bogus") == false and logHas("phase « Bogus » inconnue", "WARN"), "phase inconnue : refus")
	check(NightCycle.SkipTo("Night", -1) == false, "durée négative : refus")
	local refills = #Heist.Refills
	check(NightCycle.SkipTo("Night", 3) == true and #Heist.Refills == refills + 1, "SkipTo(Night) pendant la nuit : nouvelle nuit (nouveau tirage)")
	NightCycle.SkipTo("Day")
	-- Sans require (barre de commande serveur) : l'attribut NightSkipTo du Workspace.
	Workspace:SetAttribute("NightSkipTo", "Warning 4")
	runFor(0.1)
	check(attr("NightPhase") == "Warning" and near(attr("NightPhaseEndsAt") - serverNow(), 3.9, 0.05), "attribut NightSkipTo = « Warning 4 » : alerte de 4 s")
	check(Workspace:GetAttribute("NightSkipTo") == nil, "attribut NightSkipTo effacé après usage")
	Workspace:SetAttribute("NightSkipTo", "Dawn")
	runFor(0.1)
	check(attr("NightPhase") == "Day", "attribut NightSkipTo = « Dawn » : le jour")
	-- Hors Studio : le même module chargé côté « prod » (RunService:IsStudio() = false).
	local prod = requireModule(M.NightCycleService, "prod")
	local phaseBefore, endsBefore = attr("NightPhase"), attr("NightPhaseEndsAt")
	clearLog()
	check(prod.SkipTo("Night") == false, "hors Studio : SkipTo refuse")
	check(logHas("SkipTo est réservé aux tests dans Studio", "WARN"), "hors Studio : avertissement")
	check(attr("NightPhase") == phaseBefore and attr("NightPhaseEndsAt") == endsBefore, "hors Studio : rien ne change")
end

---------------------------------------------------------------- N8 Retour base
print("\nN8 : Retour base (DEV-045), recharge 90 s, interdit en portant")
do
	local olga = addPlayer("Olga", Vector3.new(250, 3, 0))
	Plot.Homes[olga] = Vector3.new(-60, 3, -90)
	local function press(player)
		CLIENT_PLAYER = player
		ReplicatedStorage.Remotes.ReturnToBase:FireServer()
		runFor(0.1)
	end
	local calls = #Plot.Calls
	local firstAt = now()
	press(olga)
	local call = Plot.Calls[#Plot.Calls]
	check(#Plot.Calls == calls + 1 and call.player == olga and call.check, "TeleportHome(Olga, contrôle des mains vides)")
	check(near(rootOf(olga).Position.X, -60, 1e-6), "Olga rentrée à sa base")
	local readyAt = olga:GetAttribute("ReturnBaseReadyAt")
	check(type(readyAt) == "number" and near(readyAt - (firstAt + SERVER_TIME_OFFSET), 90, 0.01), "ReturnBaseReadyAt = heure serveur + 90 s")
	check(near(ReturnBase.GetCooldownLeft(olga), 89.9, 0.05), "GetCooldownLeft")
	place(olga, Vector3.new(250, 3, 0))
	runFor(1.85)
	local since = now()
	press(olga)
	check(#Plot.Calls == calls + 1 and rootOf(olga).Position.X > 200, "pendant la recharge : refus, pas de retour")
	check(notifiedSince(olga, "Return to base is ready in 89s.", since) ~= nil, "Notify « Return to base is ready in 89s. » (88,05 s restantes)")

	-- Mains pleines.
	local paul = addPlayer("Paul", Vector3.new(160, 3, 0))
	Plot.Homes[paul] = Vector3.new(-60, 3, 90)
	Carry.StartCarry(paul, { Kind = "NPCBox", Tier = "Standard", Zone = 2, Rarity = "Common", ItemId = "Z2_YoYo", StoreId = "STORE_Inconnu", SlotId = "STORE_Inconnu/02" })
	since = now()
	calls = #Plot.Calls
	press(paul)
	check(#Plot.Calls == calls and rootOf(paul).Position.X > 100, "en portant : refus, pas de retour")
	check(notifiedSince(paul, "You can't return to base while carrying something.", since) ~= nil, "Notify « You can't return to base while carrying something. »")
	check(paul:GetAttribute("ReturnBaseReadyAt") == nil, "refus : aucune recharge")
	Carry.Consume(paul)

	-- Colis pris pendant l'attente du chargement de la zone : retour annulé.
	local quinn = addPlayer("Quinn", Vector3.new(170, 3, 0))
	Plot.Homes[quinn] = Vector3.new(-60, 3, 30)
	Plot.Wait = 1
	CLIENT_PLAYER = quinn
	ReplicatedStorage.Remotes.ReturnToBase:FireServer()
	runFor(0.3)
	Carry.StartCarry(quinn, { Kind = "NPCBox", Tier = "Standard", Zone = 2, Rarity = "Common", ItemId = "Z2_YoYo", StoreId = "STORE_Inconnu", SlotId = "STORE_Inconnu/03" })
	since = now()
	runFor(1)
	Plot.Wait = 0
	check(rootOf(quinn).Position.X > 100 and quinn:GetAttribute("ReturnBaseReadyAt") == nil, "colis pris pendant l'attente : pas de retour, pas de recharge")
	check(notifiedSince(quinn, "You can't return to base while carrying something.", since) ~= nil, "Notify mains pleines")
	Carry.Consume(quinn)

	-- Sans parcelle.
	local rita = addPlayer("Rita", Vector3.new(180, 3, 0))
	since = now()
	press(rita)
	check(notifiedSince(rita, "You don't have a shop yet: wait for one to free up.", since) ~= nil, "sans parcelle : Notify")

	-- Au bout de 90 s : de nouveau possible.
	runUntil(firstAt + 89.8, 0.1)
	calls = #Plot.Calls
	press(olga)
	check(#Plot.Calls == calls and rootOf(olga).Position.X > 200, "à 89,8 s : encore en recharge")
	runUntil(firstAt + 91, 0.1)
	press(olga)
	check(#Plot.Calls == calls + 1 and near(rootOf(olga).Position.X, -60, 1e-6), "après 90 s : retour possible de nouveau")

	-- Quitte et revient sur le même serveur : la recharge le suit.
	local uid = olga.UserId
	Players.PlayerRemoving:Fire(olga)
	olga.Parent = nil
	local olga2 = addPlayer("Olga", Vector3.new(250, 3, 0), uid)
	local again = olga2:GetAttribute("ReturnBaseReadyAt")
	check(type(again) == "number" and again > serverNow() + 80, "revenue sur le serveur : la recharge est de nouveau affichée")
	check(ReturnBase.GetCooldownLeft(olga2) > 80, "et toujours appliquée")
	CLIENT_PLAYER = alice
end

---------------------------------------------------------------- N9 jour et nuit ensemble
print("\nN9 : vigile de jour et vigile de nuit sur le même joueur")
do
	-- Un magasin avec GuardSpawn en zone 6, et Sam devant le vigile 2 de la zone 6 avant la nuit.
	local store = new("Model", "STORE_Z6_Banque")
	store:SetAttribute("Zone", 6)
	local floorPart = part("Floor", store, Vector3.new(640, -0.4, 40), Vector3.new(20, 1.2, 20))
	local spawnAttachment = new("Attachment", "GuardSpawn", floorPart)
	spawnAttachment.CFrame = CFrame.new(0, 0.6, 5)
	store.Parent = Workspace
	addTag(store, "NPCStore")
	local sam = addPlayer("Sam", PATROL[6][2] + Vector3.new(-15, 3, 0))
	Data.Load(sam, 5000)
	Plot.Homes[sam] = Vector3.new(-200, 3, -100)
	runFor(0.1)
	NightCycle.SkipTo("Night", 60)
	local g62 = guardNamed("NightGuard_Z6_2") -- au point B (670), regarde vers A (−X)
	runFor(0.1)
	check(g62:GetAttribute("TargetUserId") == sam.UserId, "Sam repéré par le vigile de nuit")
	check(lastRemote("ChaseState", sam).args[2] == g62, "ChaseState : le vigile de nuit")
	Carry.StartCarry(sam, { Kind = "NPCBox", Tier = "Standard", Zone = 6, Rarity = "Common", ItemId = "Z6_Lingot", StoreId = "STORE_Z6_Banque", SlotId = "STORE_Z6_Banque/01" })
	runFor(0.2)
	local day = GuardService.GetGuard(sam)
	check(day ~= nil and lastRemote("ChaseState", sam).args[2] == day, "un vigile de jour en plus : ChaseState montre le vigile de jour")
	local sent = #remotesTo("ChaseState", sam)
	NightCycle.SkipTo("Day")
	runFor(0.1)
	check(not GuardService.IsNightChased(sam) and #remotesTo("ChaseState", sam) == sent, "aube : vigile de nuit parti, rien de renvoyé (le vigile de jour reste annoncé)")
	Carry.Fail(sam, "Test")
	runFor(0.2)
	check(lastRemote("ChaseState", sam).args[1] == false, "plus aucun vigile : ChaseState(false)")
end

summary()
