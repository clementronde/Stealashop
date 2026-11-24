---------------------------------------------------------------- scénarios a157, partie window (2026-11-14)
-- Vrai WindowService et vrai Shared/SafeZone : chrono de police (HeistTimer, police = true) et zone safe.
local function main()
	print("== Banc a157, partie window : chrono de police et zone safe")
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
	-- Zone safe : de z = 3 à z = 15,5, devant la vitrine A (le joueur à z = 16 est dehors, à z = 14 dedans).
	local safe = new("Part", { Name = "SafeZone", Size = Vector3.new(60, 20, 12.5), CFrame = CFrame.new(0, 5, 9.25), Transparency = 1, CanCollide = false }, map)
	addTag(safe, "SafeZone")
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
	local OTHER = addPlayer("Clement", 2, Vector3.new(3, 3, 16))
	local function moveTo(player, position)
		player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
	end

	local WS = requireModule(MODULES["server/Services/WindowService.luau"], "server")
	WS.Init()
	taskLib.spawn(WS.Start)
	step(0.2)
	local hits = 0
	WS.OnHit(function()
		hits += 1
	end)
	local handlers = FAKE_REMOTES.HitWindow.serverHandlers
	local function serverHit(player, windowId)
		for _, handler in handlers do
			taskLib.spawn(handler, player, windowId)
		end
	end
	local function sent(name, player, since, pred)
		local n = 0
		for _, e in FAKE_REMOTES[name].sent do
			if e.to == player and e.t >= since and (pred == nil or pred(e.args)) then
				n += 1
			end
		end
		return n
	end
	local function timerShown(args)
		return args[2] ~= 0
	end
	local function timerHidden(args)
		return args[2] == 0
	end

	print("\nZ1 : coup sur une vitrine PNJ depuis la zone safe")
	moveTo(LOCAL, Vector3.new(0, 3, 14))
	local t0 = now()
	serverHit(LOCAL, "STORE_Z1_Superette")
	step(0.2)
	check(sent("HeistTimer", LOCAL, t0) == 0, "Z1a aucun chrono de police")
	check(sent("WindowHit", LOCAL, t0) == 0 and hits == 0, `Z1b coup refusé : ni WindowHit ni OnHit ({hits})`)

	print("\nZ2 : frappe dehors, puis à l'abri")
	moveTo(LOCAL, Vector3.new(0, 3, 16))
	local t1 = now()
	serverHit(LOCAL, "STORE_Z1_Superette")
	serverHit(OTHER, "STORE_Z1_Superette")
	step(0.2)
	check(sent("HeistTimer", LOCAL, t1, timerShown) == 1 and sent("HeistTimer", OTHER, t1, timerShown) == 1, "Z2a deux chronos de police")
	check(hits == 2, `Z2b OnHit pour les deux coups ({hits})`)
	moveTo(LOCAL, Vector3.new(0, 3, 10))
	local t2 = now()
	step(0.3)
	check(sent("HeistTimer", LOCAL, t2, timerHidden) == 1, "Z2c à l'abri : chrono masqué tout de suite")
	check(sent("HeistTimer", OTHER, t2) == 0, "Z2d l'autre frappeur garde le sien")
	local t3 = now()
	step(9) -- Balance.Window.BreakTimer = 8
	check(sent("Notify", LOCAL, t3) == 0 and sent("HeistTimer", LOCAL, t3) == 0, "Z2e à la fin : rien pour celui à l'abri")
	check(sent("Notify", OTHER, t3) == 1 and sent("HeistTimer", OTHER, t3, timerHidden) == 1, "Z2f l'autre : chrono masqué et « too slow »")

	print("\nZ3 : sorti de la zone safe, il peut refrapper")
	moveTo(LOCAL, Vector3.new(0, 3, 16))
	local t4 = now()
	serverHit(LOCAL, "STORE_Z1_Superette")
	step(0.2)
	check(sent("HeistTimer", LOCAL, t4, timerShown) == 1, "Z3a nouveau chrono de police")
	summary()
end
main()
