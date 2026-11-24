--!nocheck
-- Banc a66, partie heist (2026-11-11, Cantin : le magasin se ferme pour le voleur seulement) : le vrai
-- StoreHeistService (serveur) et le vrai StoreLockController (client du joueur P1), sur le faux Roblox et
-- la mise en place (jusqu'au démarrage) de la copie d'a66 du banc a17-heist, avec son bouchon de
-- GuardService (OnGuardGone, guardBack).
--   H1 prise : fermé pour lui, d'abord en sortie (pas sorti de force avec son colis), plus de prise
--   H2 sorti : rideau baissé chez lui (attribut ClosedStores), sorti s'il revient, colis gardé
--   H3 un autre joueur prend un colis dans le même magasin ; P1 ne voit plus le chrono
--   H4 client : rideau local baissé et solide, vrai rideau caché, chez P1 seulement
--   H5 son vigile rentre : rouvert pour lui, rideau local remonté puis retiré, nouvelle prise permise
--   H6 attrapé dans le magasin : sorti, fermé pour lui, plus de message « The guard knows you now »
--   H7 deux magasins fermés ; réouverture du magasin (vitrine refaite) : rouvert pour tous

local function main()
	if string.find(SOURCES["server/Services/StoreHeistService.luau"] or "", "ClosedStores", 1, true) == nil then
		print("\na66 SAUTÉ : cet arbre n'a pas encore la fermeture du magasin pour le voleur")
		summary()
		return
	end
	local LockModule = moduleScript(Controllers, "StoreLockController", "client/Controllers/StoreLockController.luau")
	clearLog()
	Heist.Init()
	GrabRemote = ReplicatedStorage.Remotes.GrabItem
	taskLib.spawn(Heist.Start)
	local Lock = requireModule(LockModule, "client")
	taskLib.spawn(Lock.Start)
	advance(0.2)

	local SUPERETTE = "STORE_Z1_Superette"
	local function closedFor(player)
		return player:GetAttribute("ClosedStores")
	end
	local function inside(store, player)
		return insideBounds(store, rootOf(player))
	end
	local function localShutter(store)
		local f = Workspace:FindFirstChild("LocalShutters")
		return f and f:FindFirstChild(`{store.Name}_LocalShutter`)
	end
	local function notifies(player, pattern)
		local n = 0
		for _, e in REMOTE_LOG do
			if e.name == "Notify" and e.to == player and string.find(tostring(e.args[1]), pattern, 1, true) then
				n += 1
			end
		end
		return n
	end
	local closedPivot = superette:GetAttribute("ShutterClosedPivot")
	local openPivot = superette.Shutter:GetPivot()
	check(typeofStub(closedPivot) == "CFrame" and math.abs(openPivot.Position.Y - closedPivot.Position.Y - 7.5) < 1e-6,
		"H0 ShutterClosedPivot posé sur le magasin : le rideau baissé (7,5 studs plus bas)")

	---------------------------------------------------------------- H1
	print("\nH1 : prise, fermé pour lui, d'abord en sortie")
	W._break(superette, p1)
	advance(Balance.Heist.BreakerHeadStart + 0.05)
	local n1 = findSlot(superette, "Standard")
	local pay1 = take(p1, superette, n1)
	check(pay1 ~= nil, "H1a P1 prend un colis")
	advance(0.3)
	check(inside(superette, p1) and C.IsCarrying(p1), "H1b encore dedans avec son colis : pas sorti de force (il sort lui-même)")
	check(closedFor(p1) == nil, "H1c pas encore de rideau chez lui tant qu'il sort")
	clearLog()
	advance(1.1)
	local n1b = findSlot(superette, "Standard")
	standNear(p1, superette, n1b)
	grab(p1, slotId(superette, n1b))
	check(logHas("magasin fermé pour lui", "WARN"), "H1d nouvelle prise refusée : magasin fermé pour lui")

	---------------------------------------------------------------- H2
	print("\nH2 : sorti, fermé pour lui, sorti s'il revient")
	moveTo(p1, P.outside)
	advance(0.2)
	check(closedFor(p1) == SUPERETTE, `H2a ClosedStores = « {SUPERETTE} » dès qu'il est sorti ({closedFor(p1)})`)
	moveTo(p1, P.center)
	advance(0.2)
	check(not inside(superette, p1) and C.IsCarrying(p1), "H2b il revient : sorti devant la vitrine, colis gardé")
	check(Heist.IsOpen(superette), "H2c le magasin reste ouvert pour les autres")

	---------------------------------------------------------------- H3
	print("\nH3 : un autre joueur braque le même magasin")
	local n2 = findSlot(superette, "Standard")
	local pay2 = take(p2, superette, n2)
	check(pay2 ~= nil and pay2.StoreId == SUPERETTE, "H3a P2 prend un colis dans le même magasin")
	check(closedFor(p2) == nil and closedFor(p1) == SUPERETTE, "H3b chacun sa fermeture : P2 en sortie, P1 fermé")
	C.Consume(p1) -- P1 range son colis
	moveTo(p1, P.outside) -- près du magasin, mains vides
	local since = #REMOTE_LOG
	advance(0.5)
	local shown = false
	for i = since + 1, #REMOTE_LOG do
		local e = REMOTE_LOG[i]
		if e.name == "HeistTimer" and e.to == p1 and e.args[1] == SUPERETTE and (e.args[2] or 0) > 0 then
			shown = true
		end
	end
	check(not shown, "H3c P1, mains vides devant le magasin fermé pour lui : pas de chrono")

	---------------------------------------------------------------- H4
	print("\nH4 : client de P1, rideau local")
	local copy = localShutter(superette)
	check(copy ~= nil, "H4a copie locale du rideau dans Workspace/LocalShutters")
	check(copy and (copy:GetPivot().Position - closedPivot.Position).Magnitude < 1e-6, "H4b baissée (ShutterClosedPivot)")
	check(copy and copy.CanCollide == true and copy.Anchored == true, "H4c solide une fois en bas")
	check(superette.Shutter.LocalTransparencyModifier == 1, "H4d vrai rideau caché chez P1")
	check((superette.Shutter:GetPivot().Position - openPivot.Position).Magnitude < 1e-6, "H4f le serveur n'a pas baissé le vrai rideau")
	local locks = Lock.GetLocks()
	check(#locks == 1 and locks[1].StoreId == SUPERETTE and locks[1].Shown, "H4g GetLocks : la Supérette, rideau posé")
	check(copy and copy.Name ~= "Shutter" and #Workspace:FindFirstChild("LocalShutters"):GetChildren() == 1, "H4h un seul rideau local, jamais nommé « Shutter »")

	---------------------------------------------------------------- H5
	print("\nH5 : son vigile rentre, rouvert pour lui")
	clearLog()
	guardBack(p1, superette)
	advance(0.05)
	check(closedFor(p1) == nil, "H5a ClosedStores retiré")
	check(logHas(`{SUPERETTE} rouvert pour P1 (son vigile est rentré)`, "PRINT"), "H5b sortie Studio : rouvert pour lui")
	check(copy and copy.CanCollide == false, "H5c le rideau local perd sa collision tout de suite")
	advance(1)
	check(localShutter(superette) == nil and superette.Shutter.LocalTransparencyModifier == 0, "H5d rideau local remonté et retiré, vrai rideau visible")
	check(#Lock.GetLocks() == 0, "H5e GetLocks vide")
	moveTo(p1, P.center)
	advance(0.3)
	check(inside(superette, p1), "H5f P1 peut rentrer")
	advance(1.1)
	local n3 = findSlot(superette, "Standard")
	local pay3 = take(p1, superette, n3)
	check(pay3 ~= nil, "H5g et reprendre un colis")

	---------------------------------------------------------------- H6
	print("\nH6 : attrapé dans le magasin")
	check(inside(superette, p1), "H6a P1 dedans avec son colis")
	C.Fail(p1, "Caught")
	advance(0.2)
	check(not inside(superette, p1), "H6b attrapé : sorti du magasin")
	check(closedFor(p1) == SUPERETTE, "H6c fermé pour lui (rideau local)")
	check(notifies(p1, "knows you") == 0 and notifies(p1, "come back when") == 0, "H6d plus de message « The guard knows you now… »")
	check(string.find(SOURCES["server/Services/StoreHeistService.luau"], "knows you now", 1, true) == nil
		and string.find(SOURCES["server/Services/StoreHeistService.luau"], "Banned", 1, true) == nil, "H6e plus de règle d'interdiction (Banned) dans le code")

	---------------------------------------------------------------- H7
	print("\nH7 : deux magasins, puis réouverture")
	W._break(kiosque, p1)
	advance(1.1)
	local nk = findSlot(kiosque, "Standard")
	local payK = take(p1, kiosque, nk)
	check(payK ~= nil, "H7a P1 prend aussi un colis au Kiosque")
	moveTo(p1, Vector3.new(300, 3, 15))
	advance(0.3)
	check(closedFor(p1) == "STORE_Z1_Kiosque,STORE_Z1_Superette", `H7b deux magasins fermés pour lui, triés ({closedFor(p1)})`)
	check(localShutter(kiosque) ~= nil and localShutter(superette) ~= nil, "H7c deux rideaux locaux")
	clearLog()
	W._rebuild(superette) -- vitrine refaite : le magasin se rouvre (sans vigile signalé)
	advance(0.2)
	check(closedFor(p1) == "STORE_Z1_Kiosque" and closedFor(p2) == nil, "H7d réouverture de la Supérette : rouverte pour P1 et P2")
	check(logHas(`{SUPERETTE} rouvert pour P1 (réouverture du magasin)`, "PRINT"), "H7e sortie Studio : réouverture")
	advance(1)
	check(localShutter(superette) == nil and localShutter(kiosque) ~= nil, "H7f le rideau local du Kiosque reste")
	C.Consume(p1)
	p1.Parent = nil
	Players.PlayerRemoving:Fire(p1)
	advance(0.3)
	check(true, "H7g départ du joueur : aucune erreur")
	summary()
end
main()
