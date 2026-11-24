--!nocheck
-- Banc a70, partie heist (2026-11-11, vague 24) : vrai StoreHeistService (serveur) et vrai
-- StoreLockController (client de P1), sur le faux Roblox et la mise en place (jusqu'au démarrage) de la
-- copie d'a66 du banc a17-heist. Ajouts au bouchon : WindowService.AddHitGate (le point d'accroche est
-- appelé directement, comme le ferait le vrai WindowService ; le banc window vérifie le vrai) et
-- GuardService.GetReturningGuards ; vigiles = modèles posés dans Workspace/ActiveGuards.
--   R1 rideau local qui attend la sortie du vigile (dedans, à 1 stud de Bounds : retenu ; à 10 : baissé)
--   R2 entrée et prise toujours refusées pendant ce temps
--   R3 vigile qui rentre vers la réserve : rideau levé à 16 studs, avant qu'il l'atteigne ; entrée refusée
--   R4 vigile d'un autre voleur qui apparaît dans le magasin : rideau levé, puis rebaissé à sa sortie
--   R5 vrai rideau baissé : plus rien à attendre
--   G1 à G7 un seul braquage à la fois (2e vitrine refusée, message, cadence, même vitrine, fin, colis,
--      parcelles et camion)

local function main()
	if string.find(SOURCES["server/Services/StoreHeistService.luau"] or "", "CurtainHeld", 1, true) == nil then
		print("\na70 SAUTÉ : cet arbre n'a pas encore le rideau local qui attend le vigile")
		summary()
		return
	end
	-- Bouchons complétés (ajouts purs, avant Init).
	W.gates = {}
	function W.AddHitGate(gate)
		table.insert(W.gates, gate)
	end
	GuardStub.returning = {}
	function GuardStub.GetReturningGuards(store)
		return GuardStub.returning[store] or {}
	end

	local LockModule = moduleScript(Controllers, "StoreLockController", "client/Controllers/StoreLockController.luau")
	clearLog()
	Heist.Init()
	GrabRemote = ReplicatedStorage.Remotes.GrabItem
	taskLib.spawn(Heist.Start)
	local Lock = requireModule(LockModule, "client")
	taskLib.spawn(Lock.Start)
	advance(0.2)
	check(#W.gates == 1, "R0 StoreHeistService pose un point d'accroche WindowService.AddHitGate")

	local SUPERETTE = "STORE_Z1_Superette"
	local MESSAGE = Balance.Heist.OneAtATimeMessage
	local function closedFor(player)
		return player:GetAttribute("ClosedStores")
	end
	local function localShutter(store)
		local f = Workspace:FindFirstChild("LocalShutters")
		return f and f:FindFirstChild(`{store.Name}_LocalShutter`)
	end
	local guards = folder(Workspace, "ActiveGuards")
	local function addGuard(name, position)
		local m = new("Model", name, nil)
		local root = new("Part", "HumanoidRootPart", m, { Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position) })
		m.PrimaryPart = root
		m.Parent = guards
		return m, root
	end
	local function place(root, position)
		root.CFrame = CFrame.new(position)
	end
	-- Façade de la Supérette : bord avant de Bounds à z = 21 (rue vers −z).
	local IN = Vector3.new(60, 3, 40)
	local function front(d)
		return Vector3.new(60, 3, 21 - d)
	end
	local function hit(player, store, kind)
		return W.gates[1](player, store.Name, kind or "NPC", store)
	end
	local function greedyCount(player)
		local n = 0
		for _, e in REMOTE_LOG do
			if e.name == "Notify" and e.to == player and e.args[1] == MESSAGE then
				n += 1
			end
		end
		return n
	end

	---------------------------------------------------------------- R1
	print("\nR1 : le rideau local attend la sortie du vigile")
	W._break(superette, p1)
	advance(Balance.Heist.BreakerHeadStart + 0.05)
	local pay = take(p1, superette, findSlot(superette, "Standard"))
	check(pay ~= nil, "R1a P1 prend un colis")
	local guard, groot = addGuard("Guard_P1", IN) -- son vigile, à la réserve
	moveTo(p1, P.outside)
	advance(0.3)
	check(closedFor(p1) == nil and localShutter(superette) == nil, "R1b P1 sorti, vigile dedans : pas de rideau local")
	check(logHas(`{SUPERETTE} fermé pour P1`, "PRINT"), "R1c le serveur le note bien fermé pour lui")
	place(groot, front(1))
	advance(0.3)
	check(closedFor(p1) == nil, "R1d vigile à 1 stud devant Bounds (corps encore dans la façade) : toujours retenu")
	place(groot, front(10))
	advance(0.15)
	check(closedFor(p1) == SUPERETTE, `R1e vigile à 10 studs dehors : ClosedStores = « {SUPERETTE} »`)
	advance(0.6)
	local copy = localShutter(superette)
	check(copy ~= nil and copy.CanCollide == true, "R1f rideau local tombé et solide chez P1")

	---------------------------------------------------------------- R2
	print("\nR2 : entrée et prise toujours refusées")
	place(groot, IN) -- un vigile revient se poster dedans (le rideau remonte)
	advance(0.15)
	check(closedFor(p1) == nil, "R2a vigile dedans : rideau local levé")
	moveTo(p1, P.center)
	advance(0.2)
	check(not insideBounds(superette, rootOf(p1)) and C.IsCarrying(p1), "R2b P1 entre : sorti devant la vitrine (règle inchangée)")
	clearLog()
	local n2 = findSlot(superette, "Standard")
	standNear(p1, superette, n2)
	grab(p1, slotId(superette, n2))
	check(logHas("magasin fermé pour lui", "WARN"), "R2c prise refusée : magasin fermé pour lui")
	advance(0.2)
	check(not insideBounds(superette, rootOf(p1)), "R2d et de nouveau sorti")

	---------------------------------------------------------------- R3
	print("\nR3 : le vigile rentre vers la réserve, rideau levé avant son arrivée")
	place(groot, front(40)) -- il est loin, P1 attrapé dehors par exemple
	C.Fail(p1, "Caught")
	advance(1.2)
	check(closedFor(p1) == SUPERETTE and localShutter(superette) ~= nil, "R3a vigile loin : rideau local baissé")
	GuardStub.returning[superette] = { groot }
	place(groot, front(30))
	advance(0.2)
	check(closedFor(p1) == SUPERETTE, "R3b il rentre, à 30 studs : rideau encore baissé")
	place(groot, front(16))
	advance(0.15)
	check(closedFor(p1) == nil, "R3c à 16 studs : ClosedStores retiré (rideau levé)")
	check(logHas("qui rentre vers la réserve", "PRINT"), "R3d sortie Studio : rideau levé pour un vigile qui rentre")
	local copy3 = localShutter(superette)
	check(copy3 == nil or copy3.CanCollide == false, "R3e le rideau local perd sa collision tout de suite")
	advance(1) -- 1,6 s à 10 studs/s pour arriver : la remontée (0,8 s) est finie avant
	check(localShutter(superette) == nil, "R3f rideau local remonté et retiré avant qu'il arrive à la façade")
	place(groot, IN)
	GuardStub.returning[superette] = {}
	moveTo(p1, P.center)
	advance(0.2)
	check(not insideBounds(superette, rootOf(p1)), "R3g pendant ce temps, P1 ne peut toujours pas entrer")
	guard:Destroy()
	guardBack(p1, superette)
	advance(0.2)
	check(closedFor(p1) == nil, "R3h vigile effacé : rouvert pour lui")

	---------------------------------------------------------------- R4
	print("\nR4 : vigile d'un autre voleur qui apparaît")
	local pay4 = take(p1, superette, findSlot(superette, "Standard"))
	check(pay4 ~= nil, "R4a P1 reprend un colis")
	moveTo(p1, P.outside)
	advance(0.8)
	check(closedFor(p1) == SUPERETTE and localShutter(superette) ~= nil, "R4b sorti, aucun vigile : rideau local baissé")
	local g2, root2 = addGuard("Guard_P2", IN) -- P2 vole à son tour, son vigile apparaît à la réserve
	advance(0.15)
	check(closedFor(p1) == nil, "R4c le vigile de P2 apparaît dedans : rideau de P1 levé (il va sortir par la vitrine)")
	place(root2, front(10))
	advance(0.15)
	check(closedFor(p1) == SUPERETTE, "R4d il est sorti : rideau de P1 rebaissé")
	g2:Destroy()

	---------------------------------------------------------------- R5
	print("\nR5 : vrai rideau baissé")
	advance(Balance.Heist.Duration) -- fin du chrono : le vrai rideau tombe (aucun porteur ni vigile dedans)
	local g3 = addGuard("Guard_Retour", front(5))
	GuardStub.returning[superette] = { g3.HumanoidRootPart }
	advance(0.3)
	local closedPivot = superette:GetAttribute("ShutterClosedPivot")
	check((superette.Shutter:GetPivot().Position - closedPivot.Position).Magnitude < 1e-3, "R5 (le vrai rideau est bien baissé)")
	check(closedFor(p1) == SUPERETTE, "R5a vrai rideau baissé : un vigile qui rentre ne lève rien (il s'arrête à la porte)")
	g3:Destroy()
	GuardStub.returning[superette] = {}

	---------------------------------------------------------------- G
	print("\nG : un seul braquage à la fois")
	C.Consume(p1)
	guardBack(p1, superette)
	W._rebuild(superette)
	W._rebuild(kiosque)
	advance(0.3)
	check(hit(p2, kiosque) == true and hit(p1, kiosque) == true, "G1 personne en braquage : coups permis")
	clearLog()
	local before = #REMOTE_LOG
	W._break(superette, p1)
	advance(0.1)
	check(hit(p1, kiosque) == false, "G2a P1 vient de casser la Supérette (chrono en cours) : coup sur le Kiosque refusé (aucun dégât)")
	check(greedyCount(p1) == 1, `G2b message « {MESSAGE} » envoyé`)
	check(logHas(`P1 frappe STORE_Z1_Kiosque pendant son braquage de {SUPERETTE}`, "PRINT"), "G2c sortie Studio")
	advance(0.5)
	check(hit(p1, kiosque) == false and hit(p1, kiosque) == false and greedyCount(p1) == 1, "G2d coups suivants refusés, message pas répété")
	advance(Balance.Heist.OneAtATimeCooldown)
	check(hit(p1, kiosque) == false and greedyCount(p1) == 2, `G2e de nouveau après {Balance.Heist.OneAtATimeCooldown} s`)
	check(hit(p1, superette) == true, "G3 même vitrine (son braquage) : permise")
	check(hit(p2, kiosque) == true and greedyCount(p2) == 0, "G3b P2 n'est pas concerné")
	check(hit(p1, kiosque, "Plot") == true and hit(p1, kiosque, "Event") == true, "G6 parcelle et camion : la règle ne s'applique pas")
	advance(Balance.Heist.Duration)
	check(not Heist.IsOpen(superette) and hit(p1, kiosque) == true, "G4 chrono fini, mains vides : braquage fini, coup permis")
	-- Porte un colis de la Supérette, chrono fini : toujours en braquage.
	W._rebuild(superette)
	advance(0.2)
	W._break(superette, p2) -- P2 casse, P1 prend un colis
	advance(Balance.Heist.BreakerHeadStart + 0.05)
	local pay5 = take(p1, superette, findSlot(superette, "Standard"))
	check(pay5 ~= nil, "G5a P1 prend un colis dans le braquage de P2")
	check(hit(p1, kiosque) == false, "G5b P1 porte un colis : coup sur le Kiosque refusé")
	check(hit(p2, kiosque) == false, "G5c P2 (son chrono tourne) : refusé aussi")
	advance(Balance.Heist.Duration)
	check(hit(p2, kiosque) == true, "G5d chrono fini, P2 mains vides : permis")
	check(hit(p1, kiosque) == false, "G5e P1 porte toujours son colis : refusé")
	C.Drop(p1) -- coup de batte : colis au sol
	advance(0.1)
	check(hit(p1, kiosque) == true, "G5f colis perdu : braquage fini, permis")
	p1.Parent = nil
	Players.PlayerRemoving:Fire(p1)
	advance(0.2)
	check(true, "G7b départ du joueur : aucune erreur")
	summary()
end
main()
