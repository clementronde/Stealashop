---------------------------------------------------------------- scénarios a70, partie window (2026-11-11)
-- Vrai WindowService, faux Net et faux ToolService de la copie a44 du banc a16 (en-tête lu jusqu'à
-- « monde ») : WindowService.AddHitGate. Un point d'accroche qui refuse = aucun dégât, ni WindowHit,
-- ni chrono de casse ; qui accepte = coup normal ; qui plante = coup laissé passer, un avertissement.
local function main()
	print("== Banc a70, partie window : WindowService.AddHitGate")
	local WSsrc = SOURCES["server/Services/WindowService.luau"] or ""
	if string.find(WSsrc, "AddHitGate", 1, true) == nil then
		print("\na70 window SAUTÉ : cet arbre n'a pas encore WindowService.AddHitGate")
		summary()
		return
	end
	new("Part", { Name = "Floor", Size = Vector3.new(400, 1, 400), CFrame = CFrame.new(0, -0.5, 0) }, Workspace)
	local map = folder(Workspace, "Map")
	local function store(name, x)
		local pivot = CFrame.new(x, 0, 20)
		local model = new("Model", { Name = name })
		model.WorldPivot = pivot
		new("Part", { Name = "Window", Size = Vector3.new(12, 7, 0.4), CFrame = pivot * CFrame.new(0, 4, 0) }, model)
		new("Part", { Name = "Bounds", Size = Vector3.new(20, 10, 22), CFrame = pivot * CFrame.new(0, 5, 12), Transparency = 1, CanCollide = false }, model)
		model:SetAttribute("Zone", 1)
		model.Parent = map
		addTag(model, "NPCStore")
		return model
	end
	local storeA = store("STORE_Z1_Superette", 0)
	local storeB = store("STORE_Z1_Kiosque", 100)
	local function addPlayer(name, id, position)
		local player = new("Player", { Name = name, UserId = id }, Players)
		local model = new("Model", { Name = name })
		new("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position) }, model)
		new("Humanoid", {}, model)
		model.Parent = Workspace
		player.Character = model
		return player
	end
	LOCAL = addPlayer("Ironix", 1, Vector3.new(0, 3, 16))
	local OTHER = addPlayer("Clement", 2, Vector3.new(100, 3, 16))

	local WS = requireModule(MODULES["server/Services/WindowService.luau"], "server")
	WS.Init()
	taskLib.spawn(WS.Start)
	step(0.2)
	local maxA = storeA.Window:GetAttribute("MaxHP")
	check(type(maxA) == "number" and maxA > 0, `vitre A enregistrée ({maxA} PV)`)

	local calls = {}
	local verdict = { [LOCAL] = false }
	WS.AddHitGate(function(player, windowId, kind, model)
		table.insert(calls, { player = player, id = windowId, kind = kind, model = model })
		if verdict[player] == "error" then
			error("panne de test")
		end
		return verdict[player] ~= false
	end)
	local handlers = FAKE_REMOTES.HitWindow.serverHandlers
	local function serverHit(player, windowId)
		for _, handler in handlers do
			taskLib.spawn(handler, player, windowId)
		end
	end
	local function sentTo(name, player, since)
		local n = 0
		for _, e in FAKE_REMOTES[name].sent do
			if e.to == player and e.t >= since then
				n += 1
			end
		end
		return n
	end

	print("\nW1 : point d'accroche qui refuse")
	local t0 = now()
	for _ = 1, 20 do
		serverHit(LOCAL, "STORE_Z1_Superette")
		step(0.12)
	end
	check(#calls == 20, `W1a appelé à chaque coup ({#calls})`)
	local c = calls[1]
	check(c and c.player == LOCAL and c.id == "STORE_Z1_Superette" and c.kind == "NPC" and c.model == storeA, "W1b arguments : joueur, id, « NPC », magasin")
	check(storeA.Window:GetAttribute("Broken") ~= true, "W1c 20 coups refusés : vitre entière (aucun dégât)")
	check(sentTo("WindowHit", LOCAL, t0) == 0, "W1d aucun WindowHit")
	check(sentTo("HeistTimer", LOCAL, t0) == 0, "W1e pas de chrono de casse")

	print("\nW2 : point d'accroche qui accepte")
	local t1 = now()
	serverHit(OTHER, "STORE_Z1_Kiosque")
	step(0.1)
	check(sentTo("WindowHit", OTHER, t1) == 1 and sentTo("HeistTimer", OTHER, t1) == 1, "W2a coup normal : WindowHit et chrono de casse")
	DAMAGE[OTHER] = 1e9
	serverHit(OTHER, "STORE_Z1_Kiosque")
	step(0.2)
	check(storeB.Window:GetAttribute("Broken") == true, "W2b et la vitre casse")

	print("\nW3 : point d'accroche qui plante")
	verdict[LOCAL] = "error"
	DAMAGE[LOCAL] = 1e9
	serverHit(LOCAL, "STORE_Z1_Superette")
	step(0.2)
	check(storeA.Window:GetAttribute("Broken") == true, "W3a erreur : coup laissé passer")
	local warns = 0
	for _, line in LOG do
		if line.kind == "WARN" and string.find(line.text, "AddHitGate", 1, true) then
			warns += 1
		end
	end
	check(warns == 1, `W3b un avertissement ({warns})`)
	summary()
end
main()
