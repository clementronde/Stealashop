--!nocheck
-- Scénarios a21 : cycle jour/nuit (NightCycleService), vigiles de nuit (GuardService), Retour base
-- (ReturnBaseService). Vrais : Net, Config, Contract, Format, AnimPlayer, MarkerSounds,
-- ChaseController. Bouchons : DataService, PlotService, StoreHeistService, WindowService,
-- CarryService, StatsService, AnimationController.

SOURCES["stub/CarryService.luau"] = [[
local CarryService = { Calls = {} }
local started, ended, carrying = {}, {}, {}
function CarryService.StartCarry(player, payload)
	if carrying[player] then return false end
	carrying[player] = payload
	for _, fn in started do task.spawn(fn, player, payload) end
	return true
end
function CarryService.IsCarrying(player) return carrying[player] ~= nil end
function CarryService.GetPayload(player) return carrying[player] end
local function finish(player, result, reason)
	local payload = carrying[player]
	if payload == nil then return nil end
	carrying[player] = nil
	table.insert(CarryService.Calls, { player = player, result = result, reason = reason, t = os.clock() })
	for _, fn in ended do task.spawn(fn, player, payload, result, reason) end
	return payload
end
function CarryService.Consume(player) return finish(player, "Consumed", "Placed") end
function CarryService.Fail(player, reason) return finish(player, "Failed", reason) ~= nil end
function CarryService.OnCarryStarted(fn) table.insert(started, fn) return function() end end
function CarryService.OnCarryEnded(fn) table.insert(ended, fn) return function() end end
-- a30 (vague 10) : GuardService suit aussi les colis tombés au sol (DEV-048).
function CarryService.OnDropExpired(fn) return function() end end
return CarryService
]]

SOURCES["stub/StatsService.luau"] = [[
local StatsService = { Mods = {}, Log = {} }
function StatsService.SetSpeedModifier(player, key, mult)
	StatsService.Mods[player] = StatsService.Mods[player] or {}
	StatsService.Mods[player][key] = mult
	table.insert(StatsService.Log, { player = player, key = key, mult = mult, t = os.clock() })
end
return StatsService
]]

SOURCES["stub/AnimationController.luau"] = [[
local A = { Calls = {} }
function A.PlayPlayer(name)
	table.insert(A.Calls, { action = "Play", name = name, t = os.clock() })
	return { Stopped = newSignal() }
end
function A.StopPlayer(name)
	table.insert(A.Calls, { action = "Stop", name = name, t = os.clock() })
end
return A
]]

SOURCES["stub/DataService.luau"] = [[
local DataService = { Data = {}, Listeners = {} }
function DataService.Get(player) return DataService.Data[player] end
function DataService.OnProfileLoaded(fn)
	table.insert(DataService.Listeners, fn)
	for player in DataService.Data do task.spawn(fn, player) end
	return function() end
end
-- Test : profil chargé avec `playSeconds` de jeu des sessions passées.
function DataService.Load(player, playSeconds)
	DataService.Data[player] = { Lifetime = { PlaySeconds = playSeconds or 0 } }
	for _, fn in DataService.Listeners do task.spawn(fn, player) end
end
return DataService
]]

SOURCES["stub/PlotService.luau"] = [[
local PlotService = { Calls = {}, Homes = {}, Wait = 0 }
function PlotService.GetPlot(player) return if PlotService.Homes[player] then "plot" else nil end
function PlotService.TeleportHome(player, canMove)
	local call = { player = player, t = os.clock(), check = canMove ~= nil, moved = false }
	table.insert(PlotService.Calls, call)
	local home = PlotService.Homes[player]
	local character = player.Character
	if home == nil or character == nil then return false end
	if PlotService.Wait > 0 then task.wait(PlotService.Wait) end
	if canMove and not canMove() then return false end
	character:PivotTo(CFrame.new(home))
	call.moved = true
	return true
end
return PlotService
]]

SOURCES["stub/StoreHeistService.luau"] = [[
local S = { Refills = {} }
function S.RefillAll() table.insert(S.Refills, os.clock()) return 120 end
return S
]]

SOURCES["stub/WindowService.luau"] = [[
local W = { Broken = {}, Rebuilt = {} }
function W.GetWindowId(model) return model.Name end
function W.IsBroken(id) return W.Broken[id] == true end
function W.Rebuild(id)
	if not W.Broken[id] then return false end
	W.Broken[id] = nil
	table.insert(W.Rebuilt, id)
	return true
end
return W
]]

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "Items", "Night", "PvP", "Rarities", "ShelfBoxes", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
	moduleScript(ConfigF, n, `shared/Config/{n}.luau`)
end
local ContractF = folder(Shared, "Contract")
for _, n in { "Animations", "Attributes", "Find", "Models", "Tags", "UI" } do
	moduleScript(ContractF, n, `shared/Contract/{n}.luau`)
end
local NetF = folder(Shared, "Net")
for _, n in { "Definitions", "Net", "RateLimiter", "Validate" } do
	moduleScript(NetF, n, `shared/Net/{n}.luau`)
end
local AnimF = folder(Shared, "Anim")
for _, n in { "AnimPlayer", "MarkerSounds" } do
	moduleScript(AnimF, n, `shared/Anim/{n}.luau`)
end
moduleScript(Shared, "Format", "shared/Format.luau")
local Services = folder(folder(ServerScriptService, "Server"), "Services")
local M = {}
for name, key in {
	CarryService = "stub/CarryService.luau",
	StatsService = "stub/StatsService.luau",
	DataService = "stub/DataService.luau",
	PlotService = "stub/PlotService.luau",
	StoreHeistService = "stub/StoreHeistService.luau",
	WindowService = "stub/WindowService.luau",
	GuardService = "server/Services/GuardService.luau",
	NightCycleService = "server/Services/NightCycleService.luau",
	ReturnBaseService = "server/Services/ReturnBaseService.luau",
} do
	M[name] = moduleScript(Services, name, key)
end
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local ChaseModule = moduleScript(Controllers, "ChaseController", "client/Controllers/ChaseController.luau")
moduleScript(Controllers, "AnimationController", "stub/AnimationController.luau")

local function new(class, name, parent)
	local inst = InstanceAPI.new(class)
	inst.Name = name
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function part(name, parent, center, size)
	local p = new("Part", name)
	p.Size = size
	p.CFrame = CFrame.new(center)
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Rig rendu par CreateHumanoidModelFromDescriptionAsync (bouchon) : avec une tête (lampe torche).
RIG_FACTORY = function()
	local m = new("Model", "Player")
	local root = new("Part", "HumanoidRootPart", m)
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(500, 50, 500)
	local head = new("Part", "Head", m)
	head.CFrame = CFrame.new(500, 52, 500)
	local hum = new("Humanoid", "Humanoid", m)
	hum.HipHeight = 2
	new("LocalScript", "Animate", m)
	m.PrimaryPart = root
	return m
end

-- Monde comme la greybox : zone safe X < 0, mur de nuit en X = 12 (épaisseur 2, haut 24, livré
-- baissé : le haut à −0,2), points de ronde au quart et aux trois quarts de chaque tronçon.
local safe = new("Model", "SafeZone")
part("Bounds", safe, Vector3.new(-120, 20, 0), Vector3.new(240, 40, 240))
safe.Parent = Workspace
addTag(safe, "SafeZone")
local floor = part("Floor", Workspace, Vector3.new(300, -1, 0), Vector3.new(1400, 2, 600))
table.insert(WALLS, { cframe = floor.CFrame, size = floor.Size, part = floor })

local nightWall = new("Model", "NightWall")
local wallPart = part("Wall", nightWall, Vector3.new(12, -12.2, 0), Vector3.new(2, 24, 42))
nightWall.PrimaryPart = wallPart
nightWall.Parent = Workspace
addTag(nightWall, "NightWall")

local GATES = { 30, 100, 190, 300, 430, 580, 700 }
local PATROL = {} -- [zone] = { A, B }
for zone = 1, 6 do
	local x0, x1 = GATES[zone], GATES[zone + 1]
	PATROL[zone] = {}
	for k, f in { 0.25, 0.75 } do
		local p = part(string.format("NightPatrol_Z%d_%s", zone, if k == 1 then "A" else "B"), Workspace, Vector3.new(x0 + (x1 - x0) * f, 0.015, 0), Vector3.new(3, 0.13, 3))
		p:SetAttribute("Zone", zone)
		addTag(p, "NightPatrol")
		PATROL[zone][k] = p.Position
	end
end
-- Un point de ronde hors de la map (dépôt de Clément) et un sans Zone : ignorés.
local inbox = folder(Workspace, "_INBOX_CLEMENT")
local stray = part("NightPatrol_Inbox", inbox, Vector3.new(50, 0, 0), Vector3.new(3, 0.1, 3))
stray:SetAttribute("Zone", 1)
addTag(stray, "NightPatrol")
local noZone = part("NightPatrol_NoZone", Workspace, Vector3.new(60, 0, 5), Vector3.new(3, 0.1, 3))
addTag(noZone, "NightPatrol")

-- Magasins (vitrines reconstruites à l'aube).
local STORE_NAMES = { "STORE_Z1_Superette", "STORE_Z1_Kiosque", "STORE_Z2_MagasinDeJouets", "STORE_Z3_Electronique" }
for _, name in STORE_NAMES do
	local m = new("Model", name, Workspace)
	addTag(m, "NPCStore")
end
local grey = new("Model", "STORE_Z1_Superette", inbox) -- même nom hors de la map : ignoré
addTag(grey, "NPCStore")

---------------------------------------------------------------- joueurs
local nextId = 200
local function addPlayer(name, pos, userId)
	nextId += 1
	local p = new("Player", name)
	p.UserId = userId or nextId
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	local char = new("Model", name)
	local root = part("HumanoidRootPart", char, pos, Vector3.new(2, 2, 1))
	root.Anchored = false
	local torso = part("UpperTorso", char, pos + Vector3.new(0, 0.5, 0), Vector3.new(2, 2, 1))
	torso.Anchored = false
	new("Humanoid", "Humanoid", char)
	char.PrimaryPart = root
	char.Parent = Workspace
	p.Character = char
	p.CharacterAdded:Fire(char)
	return p
end
local function rootOf(p)
	return p.Character:FindFirstChild("HumanoidRootPart")
end
local function place(p, pos)
	p.Character:PivotTo(CFrame.new(pos))
end
local function groupsOf(p)
	local out = {}
	for _, d in p.Character:GetDescendants() do
		if d:IsA("BasePart") then
			out[d.CollisionGroup] = (out[d.CollisionGroup] or 0) + 1
		end
	end
	return out
end
local function allIn(p, group)
	local groups = groupsOf(p)
	local only = true
	for g in groups do
		if g ~= group then
			only = false
		end
	end
	return only and groups[group] ~= nil
end

---------------------------------------------------------------- simulation
local DT = 1 / 30
local motion = {}

local function activeFolder()
	return Workspace:FindFirstChild("ActiveGuards")
end
local function guards()
	local f = activeFolder()
	return if f then f:GetChildren() else {}
end
local function nightGuards()
	local out = {}
	for _, g in guards() do
		if string.sub(g.Name, 1, 11) == "NightGuard_" then
			table.insert(out, g)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end
local function guardNamed(name)
	local f = activeFolder()
	return f and f:FindFirstChild(name)
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Les vigiles avancent vers leur MoveTo et se tournent dans le sens de la marche (AutoRotate).
local function stepGuards(dt)
	for _, model in guards() do
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if hum and root then
			local target = rawget(hum, "_moveTarget")
			if target then
				local pos = root.Position
				local d = flat(target - pos)
				local m = d.Magnitude
				local len = hum.WalkSpeed * dt
				if m > 1e-3 and len > 0 then
					local nextPos = pos + (if m <= len then d else d.Unit * len)
					local blocked = false
					for _, wall in WALLS do
						if wall.part ~= floor then
							local l = wall.cframe:PointToObjectSpace(nextPos)
							if math.abs(l.X) <= wall.size.X / 2 + 1 and math.abs(l.Y) <= wall.size.Y / 2 + 1 and math.abs(l.Z) <= wall.size.Z / 2 + 1 then
								blocked = true
							end
						end
					end
					if not blocked then
						root.CFrame = CFrame.lookAt(nextPos, nextPos + d.Unit)
					end
				end
			end
		end
	end
end

local function runFor(seconds, every, dt)
	local step = dt or DT
	local steps = math.floor(seconds / step + 0.5)
	for _ = 1, steps do
		for player, fn in motion do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local p = fn(root.Position, step)
				if p then
					player.Character:PivotTo(CFrame.new(p))
				end
			end
		end
		stepGuards(step)
		HEARTBEAT:Fire(step)
		advance(step)
		if every then
			every()
		end
	end
end

local function runTo(goal, speed)
	return function(pos, dt)
		local d = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
		local len = speed * dt
		if d.Magnitude <= len then
			return Vector3.new(goal.X, pos.Y, goal.Z)
		end
		return pos + d.Unit * len
	end
end

local function remotesTo(name, player)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == name and e.to == player then
			table.insert(out, e)
		end
	end
	return out
end
local function lastRemote(name, player)
	local list = remotesTo(name, player)
	return list[#list]
end
local function notifiedSince(player, text, since)
	for _, e in remotesTo("Notify", player) do
		if e.t >= (since or 0) and e.args[1] == text then
			return e
		end
	end
	return nil
end
local function serverNow()
	return Workspace:GetServerTimeNow()
end
local function attr(name)
	return Workspace:GetAttribute(name)
end

---------------------------------------------------------------- chargement
local Night = requireModule(ConfigF:FindFirstChild("Night"), "server")
local Balance = requireModule(ConfigF:FindFirstChild("Balance"), "server")
local Zones = requireModule(ConfigF:FindFirstChild("Zones"), "server")
local Features = requireModule(ConfigF:FindFirstChild("Features"), "server")
local S = {}
for name, module in M do
	S[name] = requireModule(module, "server")
end
local Carry, Stats, Data, Plot, Heist, Window = S.CarryService, S.StatsService, S.DataService, S.PlotService, S.StoreHeistService, S.WindowService
local GuardService, NightCycle, ReturnBase = S.GuardService, S.NightCycleService, S.ReturnBaseService

local alice = addPlayer("Alice", Vector3.new(-60, 3, 0)) -- zone safe
CLIENT_PLAYER = alice
Players.LocalPlayer = alice
Plot.Homes[alice] = Vector3.new(-100, 3, 60)

GuardService.Start()
NightCycle.Init()
ReturnBase.Init()
taskLib.spawn(NightCycle.Start)
local ChaseController = requireModule(ChaseModule, "client")
taskLib.spawn(ChaseController.Start)
runFor(0.5)

check(Features.NightCycle == true and Features.ReturnToBase == true, "Features : NightCycle et ReturnToBase réactivés")

---------------------------------------------------------------- N1 démarrage
print("\nN1 : démarrage, attributs, mur et groupes de collision")
do
	check(attr("NightPhase") == "Day", "NightPhase = Day au démarrage")
	local endsAt = attr("NightPhaseEndsAt")
	check(type(endsAt) == "number" and near(endsAt - serverNow(), 450 - 0.5, 0.15), "NightPhaseEndsAt = heure serveur + 7 min 30 (jour sans l'alerte)")
	check(near(attr("NightFallsAt") - endsAt, 30, 1e-6), "NightFallsAt = fin du jour + 30 s d'alerte")
	check(COLLISION_GROUPS.NightWall and COLLISION_GROUPS.NightPass, "groupes NightWall et NightPass enregistrés")
	check(COLLIDABLE["NightWall|NightPass"] == false, "NightWall et NightPass ne se touchent pas")
	check(COLLIDABLE["NightWall|Default"] == nil, "le mur reste solide pour les autres (Default)")
	check(wallPart.CollisionGroup == "NightWall", "pièces du mur dans le groupe NightWall")
	check(near(wallPart.Position.Y, -12.2, 1e-6), "mur laissé baissé, comme livré")
	check(logHas("monte de 24 studs la nuit", "PRINT"), "le mur montera de sa hauteur (24)")
	check(NightCycle.GetPhase() == "Day" and not NightCycle.IsNight(), "GetPhase / IsNight")
	check(NightCycle.IsInCorridor(Vector3.new(60, 3, 0)) and not NightCycle.IsInCorridor(Vector3.new(-30, 3, 0)), "IsInCorridor : couloir oui, zone safe non")
	check(not NightCycle.IsInCorridor(Vector3.new(5, 3, 0)), "IsInCorridor : entre la ligne safe et le mur = côté safe")
	check(NightCycle.IsInCorridor(Vector3.new(12, 3, 0)), "IsInCorridor : au mur = pas côté safe")
end

