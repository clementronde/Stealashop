-- Banc a425 (lot100, L-318, L-324, L-325) : le camion et le fourgon blindé jamais ensemble (règles pures et horaire du vrai
-- ArmoredVanService sur un faux monde, Start joué pas à pas), écarts des colis tombés, valeurs de Config/ArmoredVan.
local checks, fails = 0, 0
local function check(ok, label)
	checks += 1
	if not ok then
		fails += 1
		print("ÉCHEC " .. label)
	end
end
local function load(source, name, env)
	local fn = assert(loadstring(source, name))
	setfenv(fn, setmetatable(env or {}, { __index = _G }))
	return fn()
end
local function signal()
	return { Connect = function()
		return { Disconnect = function() end }
	end }
end
local identity = function(m)
	return m
end
local function stub()
	return setmetatable({}, { __index = function()
		return function() end
	end })
end

local DeepFreeze = load(FREEZE_SOURCE, "DeepFreeze")
local AV = load(AVCFG_SOURCE, "ArmoredVan", {
	script = { Parent = { DeepFreeze = DeepFreeze } },
	require = identity,
	Vector3 = { new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end },
	Vector2 = { new = function(x, y)
		return { X = x, Y = y }
	end },
})
local TE = load(TRUCK_SOURCE, "TruckEvent", {
	script = { Parent = { DeepFreeze = DeepFreeze, Balance = { Stats = { RealSpeedScale = 1 } } } },
	require = identity,
})

---------------------------------------------------------------- C valeurs
check(AV.TruckGap == 60 and AV.TruckLead >= TE.Lifetime + AV.TruckGap, `C1 TruckLead ({AV.TruckLead}) couvre un camion entier ({TE.Lifetime} s) + la pause ({AV.TruckGap} s)`)
check(AV.RemoveDelay >= TE.DebrisLifetime + TE.DebrisFadeTime, "C2 le fourgon reste jusqu'à l'effacement des pièces (RemoveDelay)")
check(string.format(AV.Messages.Full, "Top 3 Box") == "Heist of the century: inventory full! Your Top 3 Box fell behind the van, anyone can grab it!", "C3 message d'inventaire plein : le colis tombe")
check(type(AV.Messages.Lost) == "string" and type(AV.Messages.DelayedTruck) == "string", "C4 messages Lost et DelayedTruck")
check(AV.Banner.Soon.Title ~= nil and AV.Banner.Road.Effect ~= nil and AV.StateAttribute == "ArmoredVanState" and AV.EndsAtAttribute == "ArmoredVanEndsAt", "C5 bannière : textes et attributs")
check(#AV.Beacons.Left == 2 and #AV.Beacons.Right == 2 and AV.CashJet.Asset == "FX_Collect_Bill" and AV.DropLifetime > 0, "C6 gyrophares, jet de billets, durée au sol")
check(string.find(TRUCKSVC_SOURCE, "fortuneInPlay() or vanHolds()", 1, true) ~= nil and string.find(TRUCKSVC_SOURCE, 'FindFirstChild("ArmoredVanService")', 1, true) ~= nil, "C7 TruckEventService demande HoldsTruck avant chaque camion")

---------------------------------------------------------------- faux monde
local SLOT = 1800 * 1000 -- un départ à l'horaire (multiple de 30 min)
local function world(startBefore, phaseName)
	local w = { clock = 0, base = SLOT - startBefore, attrs = {}, trucks = {}, gateCalls = 0, announces = {}, warns = {}, phase = phaseName or "Day" }
	local fakeOs = setmetatable({
		time = function()
			return math.floor(w.base + w.clock)
		end,
		clock = function()
			return w.clock
		end,
	}, { __index = os })
	local Workspace = {
		GetServerTimeNow = function()
			return w.base + w.clock
		end,
		SetAttribute = function(_, k, v)
			w.attrs[k] = v
		end,
		GetAttribute = function(_, k)
			return w.attrs[k]
		end,
		GetAttributeChangedSignal = function()
			return signal()
		end,
		FindFirstChild = function() end,
	}
	local services = {
		CollectionService = {
			GetTagged = function(_, tag)
				if tag == "EventTruck" then
					return w.trucks
				elseif tag == "ZoneGate" then
					w.gateCalls += 1 -- un essai de départ (spawnVan cherche son trajet)
				end
				return {}
			end,
			AddTag = function() end,
		},
		Players = { GetPlayers = function()
			return {}
		end, GetPlayerByUserId = function() end },
		ReplicatedStorage = {
			Shared = {
				Config = { ArmoredVan = AV, Features = { ArmoredVan = true }, Items = { ById = {} }, Mutations = {}, Rarities = { ById = {} }, Zones = {} },
				Announce = { send = function(message)
					table.insert(w.announces, message)
				end },
				Format = stub(),
				Net = { Net = stub() },
			},
			FindFirstChild = function() end,
		},
		RunService = { IsStudio = function()
			return false
		end, Heartbeat = signal() },
		ServerStorage = { FindFirstChild = function() end },
		Workspace = Workspace,
	}
	local night = {
		GetPhase = function()
			return w.phase
		end,
		GetPhaseEndsAt = function()
			return w.base + w.clock + 10000
		end,
		OnPhaseChanged = function() end,
	}
	local S = load(AV_SOURCE, "ArmoredVanService", {
		game = { GetService = function(_, n)
			return services[n] or stub()
		end },
		script = { Parent = { DataService = stub(), NightCycleService = night, ToolService = stub(), UnboxService = stub(), WindowService = stub(), FindFirstChild = function() end } },
		require = identity,
		os = fakeOs,
		Random = { new = function()
			return { NextNumber = function()
				return 0.5
			end }
		end },
		task = {
			wait = function(dt)
				w.clock += dt
				coroutine.yield()
			end,
			delay = function() end,
		},
		print = function() end,
		warn = function(message)
			table.insert(w.warns, tostring(message))
		end,
	})
	S.Init()
	local co = coroutine.create(S.Start)
	assert(coroutine.resume(co))
	w.S = S
	-- Avance le faux temps jusqu'à `at` s après le départ à l'horaire (négatif : avant), un pas de 0,5 s à la fois.
	function w.to(at)
		while w.base + w.clock < SLOT + at do
			local ok, err = coroutine.resume(co)
			assert(ok, err)
		end
	end
	function w.said(message)
		for _, m in w.announces do
			if m == message then
				return true
			end
		end
		return false
	end
	function w.errors()
		for _, m in w.warns do
			if string.find(m, "tick", 1, true) then
				return m
			end
		end
		return nil
	end
	return w
end

---------------------------------------------------------------- P règles pures
local P = world(1000)
local S = P.S
check(S.BlocksTruck(1000, false, false, math.huge) == false, "P1a rien en vue : le camion peut venir")
check(S.BlocksTruck(1000, true, false, math.huge) and S.BlocksTruck(1000, false, true, math.huge), "P1b fourgon en jeu ou en attente : pas de camion")
check(S.BlocksTruck(1000, false, false, AV.TruckGap - 1) and not S.BlocksTruck(1000, false, false, AV.TruckGap), "P1c pause de TruckGap s après le fourgon")
check(S.BlocksTruck(AV.TruckLead, false, false, math.huge) and not S.BlocksTruck(AV.TruckLead + 1, false, false, math.huge), "P1d pas de camion dans les TruckLead s avant un départ")
check(S.TruckAllowsVan(false, AV.TruckGap) and not S.TruckAllowsVan(true, math.huge) and not S.TruckAllowsVan(false, AV.TruckGap - 0.5), "P2 le fourgon attend le camion, puis la pause")
local function same(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if math.abs(a[i] - b[i]) > 1e-9 then
			return false
		end
	end
	return true
end
local g = AV.DropSpacing
check(same(S.DropOffsets(1), { 0 }) and same(S.DropOffsets(2), { -g / 2, g / 2 }) and same(S.DropOffsets(3), { -g, 0, g }) and #S.DropOffsets(0) == 0, "P3 colis tombés côte à côte, centrés")

---------------------------------------------------------------- H horaire : un camion au moment du départ
local W = world(300)
W.trucks = { { IsDescendantOf = function()
	return true
end } }
W.to(-245)
check(W.S.HoldsTruck() == false, "H1 245 s avant le départ : un camion peut encore venir")
W.to(-235)
check(W.S.HoldsTruck() == true, "H2 moins de TruckLead s avant le départ : plus de camion")
W.to(-59)
check(W.said(string.format(AV.Messages.Soon, 60)) or W.said(string.format(AV.Messages.Soon, 59)), "H3a annonce 60 s avant")
check(W.attrs.ArmoredVanState == nil, "H3b camion en jeu : pas de minuteur « Soon » dans la bannière")
W.to(1)
check(W.said(AV.Messages.DelayedTruck) and W.gateCalls == 0, "H4 départ dû pendant le camion : il attend (DelayedTruck), aucun départ")
check(W.S.HoldsTruck() == true, "H5 départ en attente : toujours pas de camion")
W.trucks = {}
W.to(55)
check(W.gateCalls == 0, "H6 camion parti : la pause de TruckGap s n'est pas finie")
W.to(65)
check(W.gateCalls == 1, `H7 après la pause : le fourgon part (essais : {W.gateCalls})`)
check(W.S.HoldsTruck() == false, "H8 plus rien en attente, prochain départ loin : le camion peut revenir")
check(W.errors() == nil, `H9 aucune erreur dans l'horaire ({tostring(W.errors())})`)

---------------------------------------------------------------- R horaire : voie libre
local R = world(100)
R.to(-59)
check(R.attrs.ArmoredVanState == "Soon" and R.attrs.ArmoredVanEndsAt == SLOT, `R1 annonce : bannière « Soon » jusqu'au départ ({tostring(R.attrs.ArmoredVanState)}, {tostring(R.attrs.ArmoredVanEndsAt)})`)
R.to(1)
check(R.gateCalls == 1 and not R.said(AV.Messages.DelayedTruck) and not R.said(AV.Messages.Delayed), "R2 départ à l'heure, sans attente")
check(R.attrs.ArmoredVanState == nil and R.attrs.ArmoredVanEndsAt == nil, "R3 départ raté (pas d'arches dans le faux monde) : la bannière s'éteint")

---------------------------------------------------------------- N nuit au moment du départ
local N = world(100, "Warning")
N.to(1)
check(N.said(AV.Messages.Delayed) and not N.said(AV.Messages.DelayedTruck) and N.gateCalls == 0, "N1 alerte de la nuit : il attend le jour (Delayed)")
check(N.attrs.ArmoredVanState == nil, "N2 nuit : pas de minuteur « Soon »")
check(N.S.HoldsTruck() == true, "N3 départ en attente : pas de camion")

print(`{checks} vérification(s), {fails} échec(s)`)
