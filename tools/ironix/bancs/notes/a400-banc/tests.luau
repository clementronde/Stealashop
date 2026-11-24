-- Banc a400 : PlayerCollisionService (faux Roblox minimal, SOURCES[chemin] = texte des modules, posé par run.sh).

local CHECKS, FAILS = 0, 0
local function check(cond, label)
	CHECKS += 1
	if not cond then
		FAILS += 1
		REAL_PRINT("ÉCHEC : " .. label)
	elseif VERBOSE then
		REAL_PRINT("ok : " .. label)
	end
end

---------------------------------------------------------------- signaux
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local c = { fn = fn, connected = true }
		function c:Disconnect()
			c.connected = false
		end
		table.insert(s.handlers, c)
		return c
	end
	function s:Fire(...)
		for _, c in table.clone(s.handlers) do
			if c.connected then
				c.fn(...)
			end
		end
	end
	return s
end

---------------------------------------------------------------- instances
GROUP_WRITES = {}
local I = {}
local BASE_PARTS = { Part = true, MeshPart = true, UnionOperation = true }
local function subtree(o, out)
	table.insert(out, o)
	for _, c in rawget(o, "_children") do
		subtree(c, out)
	end
	return out
end
I.__index = function(o, k)
	if k == "Parent" then
		return rawget(o, "_parent")
	elseif k == "CollisionGroup" then
		local g = rawget(o, "_group")
		if g == nil then
			error("CollisionGroup is not a valid member of " .. rawget(o, "ClassName"))
		end
		return g
	end
	if I[k] ~= nil then
		return I[k]
	end
	for _, c in rawget(o, "_children") do
		if rawget(c, "Name") == k then
			return c
		end
	end
	return nil
end
I.__newindex = function(o, k, v)
	if k == "CollisionGroup" then
		assert(rawget(o, "_group") ~= nil, "CollisionGroup sur une non-BasePart")
		rawset(o, "_group", v)
		table.insert(GROUP_WRITES, { part = o, group = v })
		return
	end
	if k ~= "Parent" then
		rawset(o, k, v)
		return
	end
	local old = rawget(o, "_parent")
	if old == v then
		return
	end
	if old then
		local moved = subtree(o, {})
		local a = old
		while a do
			for _, d in moved do
				rawget(a, "DescendantRemoving"):Fire(d)
			end
			a = rawget(a, "_parent")
		end
		local list = rawget(old, "_children")
		for i, c in list do
			if c == o then
				table.remove(list, i)
				break
			end
		end
	end
	rawset(o, "_parent", v)
	if v then
		table.insert(rawget(v, "_children"), o)
		local moved = subtree(o, {})
		local a = v
		while a do
			for _, d in moved do
				rawget(a, "DescendantAdded"):Fire(d)
			end
			a = rawget(a, "_parent")
		end
	end
end
function I:IsA(class)
	if class == "BasePart" then
		return BASE_PARTS[self.ClassName] == true
	end
	return self.ClassName == class
end
function I:GetDescendants()
	local all = subtree(self, {})
	table.remove(all, 1)
	return all
end

local function inst(class, name, parent)
	local o = setmetatable({
		ClassName = class,
		Name = name or class,
		_children = {},
		DescendantAdded = signal(),
		DescendantRemoving = signal(),
	}, I)
	if BASE_PARTS[class] then
		rawset(o, "_group", "Default")
	end
	if parent then
		o.Parent = parent
	end
	return o
end

---------------------------------------------------------------- monde
local function makeWorld(opts)
	opts = opts or {}
	GROUP_WRITES = {}
	local W = { warns = {} }
	local registered = { Default = true }
	local collide = {}
	local function key(a, b)
		return if a < b then a .. "|" .. b else b .. "|" .. a
	end
	local physics = {}
	function physics:IsCollisionGroupRegistered(n)
		return registered[n] == true
	end
	function physics:RegisterCollisionGroup(n)
		if opts.failRegister then
			error("trop de groupes")
		end
		registered[n] = true
	end
	function physics:CollisionGroupSetCollidable(a, b, v)
		assert(registered[a] and registered[b], "groupe pas enregistré : " .. a .. " / " .. b)
		collide[key(a, b)] = v
	end
	function physics:CollisionGroupsAreCollidable(a, b)
		return collide[key(a, b)] ~= false
	end
	W.physics = physics
	local players = { PlayerAdded = signal(), PlayerRemoving = signal(), list = {} }
	function players:GetPlayers()
		return table.clone(self.list)
	end
	W.players = players
	W.workspace = inst("Workspace", "Workspace")
	local config = {}
	config.DeepFreeze = { path = "shared/Config/DeepFreeze.luau", Parent = config }
	config.Features = { path = "shared/Config/Features.luau", Parent = config }
	W.config = config
	local services = {
		Players = players,
		PhysicsService = physics,
		ReplicatedStorage = { Shared = { Config = config } },
		Workspace = W.workspace,
	}
	W.game = {
		GetService = function(_, n)
			return assert(services[n], "service inconnu " .. n)
		end,
	}
	local cache = {}
	local function load(token)
		if cache[token.path] ~= nil then
			return cache[token.path]
		end
		local src = SOURCES[token.path]
		if token.path == "shared/Config/Features.luau" and opts.featureOn then
			local n
			src, n = string.gsub(src, "PlayerCollision = false", "PlayerCollision = true")
			W.featurePatched = n == 1
		end
		local fn, err = loadstring(src, "=" .. token.path)
		assert(fn, err)
		setfenv(fn, setmetatable({
			game = W.game,
			script = token,
			require = load,
			warn = function(...)
				table.insert(W.warns, table.concat({ ... }, " "))
			end,
		}, { __index = getfenv(0) }))
		local m = fn()
		cache[token.path] = m
		return m
	end
	W.load = load
	W.service = function()
		return load({ path = "server/Services/PlayerCollisionService.luau" })
	end
	return W
end

local function character(name)
	local c = inst("Model", name)
	for _, n in { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "LeftFoot" } do
		inst("Part", n, c)
	end
	inst("Humanoid", "Humanoid", c)
	local hat = inst("Accessory", "Hat", c)
	inst("MeshPart", "Handle", hat)
	return c
end

local function addPlayer(W, name, withCharacter)
	local p = { Name = name, CharacterAdded = signal(), Backpack = inst("Backpack", "Backpack") }
	if withCharacter then
		p.Character = character(name)
		p.Character.Parent = W.workspace
	end
	table.insert(W.players.list, p)
	return p
end

local function respawn(W, p)
	local c = character(p.Name)
	c.Parent = W.workspace
	p.Character = c
	p.CharacterAdded:Fire(c)
	return c
end

local function allIn(model, group)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.CollisionGroup ~= group then
			return false
		end
	end
	return true
end

local function tool(name)
	local t = inst("Tool", name)
	inst("Part", "Handle", t)
	local m = inst("Model", "Item", t)
	inst("MeshPart", "Body", m)
	return t
end

---------------------------------------------------------------- A : interrupteur dans le dépôt
do
	local W = makeWorld()
	local Features = W.load(W.config.Features)
	check(Features.PlayerCollision == false, "A1 Features.PlayerCollision = false dans le dépôt (joueurs qui se traversent)")
end

---------------------------------------------------------------- B à H : interrupteur à false
do
	local W = makeWorld()
	local early = addPlayer(W, "Early", true)
	local badge = inst("Part", "Badge", early.Character)
	badge.CollisionGroup = "Guards" -- groupe posé par un autre service
	local svc = W.service()
	check(svc.Init == nil, "B0 aucun Init (tout se fait dans Start)")
	svc.Start()
	local ph = W.physics
	check(ph:IsCollisionGroupRegistered("Players"), "B1 groupe Players enregistré")
	check(ph:CollisionGroupsAreCollidable("Players", "Players") == false, "B2 Players ne touche pas Players")
	check(ph:CollisionGroupsAreCollidable("Players", "Default") == true, "B3 Players touche toujours Default (décor, vitrines, portes)")
	check(ph:CollisionGroupsAreCollidable("Players", "NightPass") == false, "B4 Players ne touche pas NightPass (passage du mur)")
	check(ph:CollisionGroupsAreCollidable("NightPass", "NightPass") == false, "B5 NightPass ne touche pas NightPass")
	check(ph:CollisionGroupsAreCollidable("NightPass", "Default") == true, "B6 NightPass touche toujours Default")
	for _, g in { "Guards", "Bot", "BotDoor", "WitnessAvoid", "NightWall" } do
		check(ph:CollisionGroupsAreCollidable("Players", g) == true, "B7 Players touche toujours " .. g)
	end

	-- C : joueur déjà là avec son personnage au Start
	local ok = true
	for _, d in early.Character:GetDescendants() do
		if d:IsA("BasePart") and d ~= badge and d.CollisionGroup ~= "Players" then
			ok = false
		end
	end
	check(ok, "C1 personnage déjà là : toutes ses pièces (accessoire compris) dans Players")
	check(badge.CollisionGroup == "Guards", "C2 un groupe posé par un autre service n'est pas écrasé")

	-- D : apparition après Start
	local late = addPlayer(W, "Late", false)
	W.players.PlayerAdded:Fire(late)
	local c1 = respawn(W, late)
	check(allIn(c1, "Players"), "D1 personnage apparu après Start : pièces dans Players")
	local hat = inst("Accessory", "LateHat")
	inst("MeshPart", "Handle", hat)
	hat.Parent = c1
	check(hat.Handle.CollisionGroup == "Players", "D2 accessoire chargé après coup : Players")

	-- E : outil ajouté, rangé, ressorti ; objet porté
	local t = tool("Bat")
	t.Parent = late.Backpack
	check(t.Handle.CollisionGroup == "Default", "E0 outil dans le sac : Default")
	t.Parent = c1
	check(t.Handle.CollisionGroup == "Players" and t.Item.Body.CollisionGroup == "Players", "E1 outil équipé : poignée et modèle dans Players")
	t.Parent = late.Backpack
	check(t.Handle.CollisionGroup == "Default" and t.Item.Body.CollisionGroup == "Default", "E2 outil rangé : revenu à Default")
	t.Parent = c1
	check(t.Handle.CollisionGroup == "Players", "E3 outil ressorti : Players")
	local carried = inst("Model", "Carry")
	inst("Part", "Anchor", carried)
	inst("MeshPart", "Mesh", carried)
	carried.Parent = c1
	check(allIn(carried, "Players"), "E4 objet porté ajouté au personnage : Players")
	carried.Parent = W.workspace
	check(allIn(carried, "Default"), "E5 objet porté sorti du personnage : Default")

	-- F : passage de nuit (NightCycleService) gardé
	local pass = inst("Part", "Passing")
	pass.CollisionGroup = "NightPass"
	pass.Parent = c1
	check(pass.CollisionGroup == "NightPass", "F1 pièce déjà en NightPass ajoutée : groupe gardé")
	pass.Parent = nil
	check(pass.CollisionGroup == "NightPass", "F2 pièce en NightPass retirée : groupe gardé")

	-- G : réapparition, anciens écouteurs coupés
	local c2 = respawn(W, late)
	check(allIn(c2, "Players"), "G1 nouveau personnage : Players")
	local stray = inst("Part", "Stray")
	stray.Parent = c1
	check(stray.CollisionGroup == "Default", "G2 ancien personnage plus suivi après réapparition")

	-- H : départ du joueur
	W.players.PlayerRemoving:Fire(late)
	local after = inst("Part", "AfterLeave")
	after.Parent = c2
	check(after.CollisionGroup == "Default", "H1 joueur parti : plus suivi")
	check(#W.warns == 0, "H2 aucun avertissement")
end

---------------------------------------------------------------- I : interrupteur à true
do
	local W = makeWorld({ featureOn = true })
	local p = addPlayer(W, "On", true)
	local svc = W.service()
	svc.Start()
	check(W.featurePatched == true, "I0 ligne PlayerCollision = false trouvée et passée à true")
	check(not W.physics:IsCollisionGroupRegistered("Players"), "I1 interrupteur à true : aucun groupe enregistré")
	check(allIn(p.Character, "Default"), "I2 interrupteur à true : personnage laissé en Default")
	check(#GROUP_WRITES == 0, "I3 interrupteur à true : aucun groupe écrit")
end

---------------------------------------------------------------- J : groupes indisponibles
do
	local W = makeWorld({ failRegister = true })
	local p = addPlayer(W, "Full", true)
	local svc = W.service()
	local ok = pcall(svc.Start)
	check(ok, "J1 groupes indisponibles : Start ne lève pas d'erreur")
	check(#W.warns == 1, "J2 un avertissement")
	check(allIn(p.Character, "Default"), "J3 personnage laissé en Default")
end

REAL_PRINT(`banc a400 : {CHECKS} vérification(s), {FAILS} échec(s)`)
