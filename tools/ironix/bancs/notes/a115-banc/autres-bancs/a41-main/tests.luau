--!nocheck
-- Banc a41 (2026-11-08, liaison L-071, points 3 et 5). Copie d'a65 (2026-11-11, L-093) : T1, T2, T7, T11,
-- T12 et T13 suivent l'entrée par zone (tapis et banc sans invite, pas de remontée sans sortir).
--   T : TrainingService (serveur) : tapis sans invite (on s'arrête sur la bande Belt), banc avec son
--       invite, gains, sorties, propriétaire seulement ;
--   G : GuardService (serveur) et ChaseController (client) : le coup du vigile en un seul geste avec
--       Catch (poussée au marqueur Impact, délai de secours, étourdissement compté du coup).
-- Vrais Net, AnimPlayer, MarkerSounds, Config et Contract. CarryService, StatsService, DataService,
-- AntiCheatService et AnimationController sont des bouchons. Faux Roblox : stubs.luau (copie de
-- celui d'a12, complétée par a41).

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
function CarryService.Fail(player, reason) finish(player, "Failed", reason) end
function CarryService.OnCarryStarted(fn) table.insert(started, fn) return function() end end
function CarryService.OnCarryEnded(fn) table.insert(ended, fn) return function() end end
function CarryService.OnDropExpired(fn) return function() end end
return CarryService
]]

SOURCES["stub/StatsService.luau"] = [[
local StatsService = { Mods = {}, Log = {}, Adds = {}, Totals = {} }
function StatsService.SetSpeedModifier(player, key, mult)
	StatsService.Mods[player] = StatsService.Mods[player] or {}
	StatsService.Mods[player][key] = mult
	table.insert(StatsService.Log, { player = player, key = key, mult = mult, t = os.clock() })
end
local function add(player, kind, n)
	local key = kind .. ":" .. player.Name
	StatsService.Totals[key] = (StatsService.Totals[key] or 0) + n
	table.insert(StatsService.Adds, { player = player, kind = kind, n = n, t = os.clock() })
	return StatsService.Totals[key]
end
function StatsService.AddSpeed(player, n) return add(player, "Speed", n) end
function StatsService.AddStrength(player, n) return add(player, "Strength", n) end
return StatsService
]]

SOURCES["stub/DataService.luau"] = [[
local DataService = { Data = {} }
function DataService.Get(player) return DataService.Data[player] end
function DataService.IsLoaded(player) return DataService.Data[player] ~= nil end
function DataService.OnProfileLoaded(_fn) end
function DataService.OnProfileReleasing(_fn) end
return DataService
]]

SOURCES["stub/AnimationController.luau"] = [[
local A = { Calls = {}, Missing = {} }
function A.PlayPlayer(name)
	table.insert(A.Calls, { action = "Play", name = name, t = os.clock() })
	if A.Missing[name] then return nil end
	local track = { Stopped = newSignal() }
	if name == "Knockback" then
		task.delay(0.4, function() track.Stopped:Fire() end)
	elseif name == "Knockdown" then -- 2026-11-10 : la chute de Clément dure 1,2 s
		task.delay(1.2, function() track.Stopped:Fire() end)
	end
	return track
end
function A.StopPlayer(name)
	table.insert(A.Calls, { action = "Stop", name = name, t = os.clock() })
end
return A
]]

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Formulas", "Items", "Night", "PvP", "Rarities", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
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
moduleScript(Shared, "TrainingZone", "shared/TrainingZone.luau") -- a115 : zones des machines
local Services = folder(folder(ServerScriptService, "Server"), "Services")
moduleScript(Services, "AntiCheatService", "stub/AntiCheatService")
local CarryModule = moduleScript(Services, "CarryService", "stub/CarryService.luau")
local StatsModule = moduleScript(Services, "StatsService", "stub/StatsService.luau")
local DataModule = moduleScript(Services, "DataService", "stub/DataService.luau")
local GuardModule = moduleScript(Services, "GuardService", "server/Services/GuardService.luau")
local TrainingModule = moduleScript(Services, "TrainingService", "server/Services/TrainingService.luau")
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local ChaseModule = moduleScript(Controllers, "ChaseController", "client/Controllers/ChaseController.luau")
local AnimModule = moduleScript(Controllers, "AnimationController", "stub/AnimationController.luau")

local function new(class, name, parent)
	local inst = InstanceAPI.new(class)
	inst.Name = name
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function part(name, parent, size, position)
	local p = new("Part", name, parent)
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Anchored = true
	return p
end

---------------------------------------------------------------- joueurs
local nextId = 100
local function newCharacter(name, pos)
	local char = new("Model", name)
	local root = new("Part", "HumanoidRootPart", char)
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(pos)
	new("Humanoid", "Humanoid", char)
	char.PrimaryPart = root
	char.Parent = Workspace
	return char
end
local function addPlayer(name, pos)
	nextId += 1
	local p = new("Player", name)
	p.UserId = nextId
	p.Parent = Players
	local char = newCharacter(name, pos)
	p.Character = char
	p.CharacterAdded:Fire(char)
	return p
end
local function rootOf(p)
	return p.Character:FindFirstChild("HumanoidRootPart")
end
local function humOf(p)
	return p.Character:FindFirstChildOfClass("Humanoid")
end
local function respawn(p, pos)
	local old = p.Character
	p.CharacterRemoving:Fire(old)
	old:Destroy()
	local char = newCharacter(p.Name, pos)
	p.Character = char
	p.CharacterAdded:Fire(char)
	return char
end
local function payload(storeName, zone)
	return { Kind = "NPCBox", Tier = "Standard", Zone = zone, Rarity = "Common", ItemId = "Z1_CanetteDeSoda", StoreId = storeName, SlotId = "ShelfSlot_01" }
end

---------------------------------------------------------------- simulation
local DT = 1 / 30
local motion = {} -- [player] = function(position, dt) -> nouvelle position, vitesse

local function activeFolder()
	return Workspace:FindFirstChild("ActiveGuards")
end
local function guards()
	local f = activeFolder()
	return if f then f:GetChildren() else {}
end
local function guardOf(player)
	for _, g in guards() do
		if g:GetAttribute("TargetUserId") == player.UserId then
			return g
		end
	end
	return nil
end
local function stepGuards(dt)
	for _, model in guards() do
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if hum and root then
			local target = rawget(hum, "_moveTarget")
			if target then
				local pos = root.Position
				local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
				local m = d.Magnitude
				local len = hum.WalkSpeed * dt
				if m > 1e-3 and len > 0 then
					local nextPos = pos + (if m <= len then d else d.Unit * len)
					root.CFrame = root.CFrame + (nextPos - pos)
				end
			end
		end
	end
end
local function runFor(seconds, every)
	local steps = math.floor(seconds / DT + 0.5)
	for _ = 1, steps do
		for player, fn in motion do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local p, v = fn(root.Position, DT)
				if p then
					root.CFrame = CFrame.new(p)
				end
				if v then
					root.AssemblyLinearVelocity = v
				end
			end
		end
		stepGuards(DT)
		HEARTBEAT:Fire(DT)
		advance(DT)
		if every then
			every()
		end
	end
end
local function runUntilEmpty(maxSeconds)
	local t = 0
	while #guards() > 0 and t < maxSeconds do
		runFor(0.1)
		t += 0.1
	end
	return #guards() == 0
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
local function f2(x)
	return if x then string.format("%.2f", x) else "nil"
end

---------------------------------------------------------------- parcelles
-- Comme la greybox : tapis (Belt 3 × 0,15 × 6,5, UsePoint sur le dessus de la bande, axe −Z vers
-- l'avant) et banc (UsePoint sur l'assise), dans une parcelle taggée PlayerPlot.
local function makePlot(name, owner, origin, withBelt)
	local plot = new("Model", name)
	plot:SetAttribute("OwnerUserId", if owner then owner.UserId else 0)
	local treadmill = new("Model", "Treadmill", plot)
	local frame = part("Frame", treadmill, Vector3.new(4, 0.5, 8), origin + Vector3.new(0, 0.25, 0))
	local holder = frame
	if withBelt then
		holder = part("Belt", treadmill, Vector3.new(3, 0.15, 6.5), origin + Vector3.new(0, 0.575, 0))
	end
	local use = new("Attachment", "UsePoint", holder)
	use.CFrame = CFrame.new(0, holder.Size.Y / 2, 0)
	local bench = new("Model", "Bench", plot)
	local pad = part("Pad", bench, Vector3.new(2, 1, 5), origin + Vector3.new(10, 0.5, 0))
	local benchUse = new("Attachment", "UsePoint", pad)
	benchUse.CFrame = CFrame.new(0, 0.5, 0)
	plot.Parent = Workspace
	addTag(plot, "PlayerPlot")
	addTag(treadmill, "Treadmill")
	addTag(bench, "Bench")
	return { plot = plot, treadmill = treadmill, belt = holder, use = use, bench = bench, benchUse = benchUse }
end

---------------------------------------------------------------- chargement
local Balance = requireModule(ConfigF:FindFirstChild("Balance"), "server")
local Training = requireModule(ConfigF:FindFirstChild("Training"), "server")
local CarryService = requireModule(CarryModule, "server")
local StatsService = requireModule(StatsModule, "server")
local DataService = requireModule(DataModule, "server")
local AntiCheat = requireModule(Services:FindFirstChild("AntiCheatService"), "server")

local alice = addPlayer("Alice", Vector3.new(0, 3, 40))
local bob = addPlayer("Bob", Vector3.new(0, 3, 50))
local carl = addPlayer("Carl", Vector3.new(0, 3, 60))
local dana = addPlayer("Dana", Vector3.new(0, 3, 70)) -- joueur local : vigile (G)
for _, p in { alice, bob, carl, dana } do
	DataService.Data[p] = { Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 } }
end
CLIENT_PLAYER = alice
Players.LocalPlayer = dana

local A = makePlot("PLOT_A", alice, Vector3.new(-200, 0, 0), true)
local B = makePlot("PLOT_B", bob, Vector3.new(-200, 0, 100), true)

local TrainingService = requireModule(TrainingModule, "server")
TrainingService.Init()
-- Après Init : tapis sans Belt (repli et avertissement), tapis hors parcelle (ignoré).
clearLog()
local C = makePlot("PLOT_C", carl, Vector3.new(-200, 0, 200), false)
local inbox = folder(Workspace, "_INBOX_CLEMENT")
local looseTreadmill = new("Model", "Treadmill", inbox)
local looseBelt = part("Belt", looseTreadmill, Vector3.new(3, 0.15, 6.5), Vector3.new(-300, 0.575, 0))
new("Attachment", "UsePoint", looseBelt).CFrame = CFrame.new(0, 0.075, 0)
addTag(looseTreadmill, "Treadmill")
runFor(DT)

local GuardService = requireModule(GuardModule, "server")
GuardService.Start()
local AnimationController = requireModule(AnimModule, "client")
local ChaseController = requireModule(ChaseModule, "client")
taskLib.spawn(ChaseController.Start)
local NetClient = requireModule(NetF:FindFirstChild("Net"), "client")
runFor(0.5)

-- Debout, pieds sur le UsePoint (HumanoidRootPart à HipHeight 2 + 1 au-dessus), immobile.
local function standAt(player, P, offset)
	motion[player] = nil
	local root = rootOf(player)
	root.CFrame = CFrame.new(P.use.WorldPosition + Vector3.new(0, 3, 0) + (offset or Vector3.zero))
	root.AssemblyLinearVelocity = Vector3.zero
end
local function moveTo(player, position, velocity)
	motion[player] = nil
	local root = rootOf(player)
	root.CFrame = CFrame.new(position)
	root.AssemblyLinearVelocity = velocity or Vector3.zero
end
local function machineOf(player)
	return player:GetAttribute("TrainingMachine")
end
local function speedAdds(player, since)
	local n, total = 0, 0
	for _, e in StatsService.Adds do
		if e.player == player and e.kind == "Speed" and e.t >= since then
			n += 1
			total += e.n
		end
	end
	return n, total
end
local function notifies(player, text)
	local n = 0
	for _, e in remotesTo("Notify", player) do
		if e.args[1] == text then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- T1 invites
print("\nT1 : plus aucune invite, ni au tapis ni au banc (copie a65, L-093)")
local function promptsIn(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d.ClassName == "ProximityPrompt" then
			table.insert(list, d)
		end
	end
	return list
end
check(#promptsIn(A.treadmill) == 0 and #promptsIn(B.treadmill) == 0 and #promptsIn(C.treadmill) == 0, "aucune invite sur les tapis")
check(#promptsIn(A.bench) == 0 and A.benchUse:FindFirstChild("TrainingPrompt") == nil, "aucune invite sur le banc (a65 : entrée par la zone)")
check(Training.Treadmill.Prompt == nil and Training.Bench.Prompt == nil, "Config.Training : plus de texte d'invite")
check(logHas("PLOT_C.Treadmill : pas de pièce Belt", "WARN"), "tapis sans Belt : avertissement (zone de repli)")
check(not logHas("_INBOX_CLEMENT", "WARN"), "tapis hors parcelle : ignoré, sans avertissement")

---------------------------------------------------------------- T2 traverser
print("\nT2 : traverser la zone en courant fait monter (a65, L-093 : plus besoin de s'arrêter)")
local P = A.use.WorldPosition
do
	local y = P.Y + 3
	-- En largeur, à 16 studs/s.
	moveTo(alice, Vector3.new(P.X - 5, y, P.Z))
	motion[alice] = function(pos, dt)
		return pos + Vector3.new(16 * dt, 0, 0), Vector3.new(16, 0, 0)
	end
	local seen = false
	runFor(0.7, function()
		seen = seen or machineOf(alice) ~= nil
	end)
	check(seen, "en largeur à 16 studs/s : monte sur le tapis")
	motion[alice] = nil
	moveTo(alice, Vector3.new(P.X - 8, y, P.Z))
	runFor(0.6)
	check(machineOf(alice) == nil, "sorti de la zone : descendu")
	-- En longueur, à 16 studs/s.
	moveTo(alice, Vector3.new(P.X, y, P.Z + 7))
	motion[alice] = function(pos, dt)
		return pos + Vector3.new(0, 0, -16 * dt), Vector3.new(0, 0, -16)
	end
	seen = false
	runFor(0.8, function()
		seen = seen or machineOf(alice) ~= nil
	end)
	check(seen, "en longueur à 16 studs/s : monte sur le tapis")
	motion[alice] = nil
	moveTo(alice, Vector3.new(P.X - 8, y, P.Z))
	runFor(0.3)
end

---------------------------------------------------------------- T3 s'arrêter dessus
print("\nT3 : s'arrêter sur la bande fait s'entraîner")
moveTo(alice, Vector3.new(P.X, P.Y + 30, P.Z - 40)) -- loin du tapis
runFor(0.2)
local allowsBefore = #AntiCheat.allows
clearLog()
standAt(alice, A, Vector3.new(0.6, 0, 1.2)) -- un peu à côté du centre
local t3 = now()
runFor(0.15)
check(machineOf(alice) == "Treadmill", "a115 : monté tout de suite (START_DWELL 0)")
runFor(0.35)
check(machineOf(alice) == "Treadmill", `séance commencée en 0,5 s au plus (TrainingMachine = {machineOf(alice)})`)
local r = rootOf(alice)
check((r.Position - (P + Vector3.new(0, 3, 0))).Magnitude < 1e-6, `placé sur le UsePoint, debout ({r.Position})`)
check(math.abs(r.CFrame.LookVector.Z + 1) < 1e-6, "tourné vers l'axe −Z du UsePoint")
check(humOf(alice).AutoRotate == false, "a115 : rotation coupée au tapis aussi")
check(StatsService.Mods[alice] ~= nil and StatsService.Mods[alice].Training == 0, "a115 : figé au tapis (modificateur Training à 0, il descend en bougeant)")
check(#AntiCheat.allows == allowsBefore + 1 and AntiCheat.allows[#AntiCheat.allows].player == alice, "placement déclaré à l'anti-triche (Allow)")
check(logHas("Alice monte sur le tapis", "PRINT"), "sortie : monte sur le tapis")

---------------------------------------------------------------- T4 gains
print("\nT4 : gains du tapis (AFK, puis tap)")
local t4 = now()
runFor(3.05)
local n4, total4 = speedAdds(alice, t4)
check(n4 == 3 and math.abs(total4 - 3) < 1e-6, `3 s sans rien faire : +3 Vitesse ({n4} crédits, {total4})`)
local t4b = now()
NetClient.Client.TrainTap:Fire()
runFor(1.0)
local _, total4b = speedAdds(alice, t4b)
check(math.abs(total4b - 1.5) < 1e-6, `un tap dans la seconde : +1,5 ({total4b})`)

---------------------------------------------------------------- T5 saut sur place
print("\nT5 : sauter sur place ne coupe pas la séance")
do
	local hum = humOf(alice)
	setState(hum, "Enum.HumanoidStateType.Jumping")
	moveTo(alice, rootOf(alice).Position + Vector3.new(0, 7, 0), Vector3.new(0, 30, 0))
	runFor(0.3)
	setState(hum, "Enum.HumanoidStateType.Freefall")
	runFor(0.3)
	check(machineOf(alice) == "Treadmill", "en l'air au-dessus de la bande (7 studs) : toujours à l'entraînement")
	moveTo(alice, P + Vector3.new(0, 3, 0))
	setState(hum, "Enum.HumanoidStateType.Landed")
	setState(hum, "Enum.HumanoidStateType.Running")
	runFor(0.3)
	check(machineOf(alice) == "Treadmill", "retombé sur la bande : toujours à l'entraînement")
end

---------------------------------------------------------------- T6 descendre
print("\nT6 : descendre de la bande arrête la séance")
clearLog()
moveTo(alice, P + Vector3.new(2, 3, 0), Vector3.new(8, 0, 0)) -- un pas de côté, encore sur la marge
runFor(0.1)
check(machineOf(alice) == "Treadmill", "un pas de côté (bord + 0,5) : séance gardée (LEAVE_MARGIN 1)")
moveTo(alice, P + Vector3.new(3, 3, 0), Vector3.new(8, 0, 0))
runFor(DT)
check(machineOf(alice) == nil, "descendu (bord + 1,5) : séance finie")
check(humOf(alice).AutoRotate == true, "rotation toujours là")
check(logHas("quitte le tapis (descendu du tapis)", "PRINT"), "sortie : quitte le tapis (descendu du tapis)")
local t6 = now()
runFor(1.2)
check(speedAdds(alice, t6) == 0, "plus de gain une fois descendu")

---------------------------------------------------------------- T7 remonter
print("\nT7 : sortir de la zone puis revenir : nouvelle séance (a65 : pas de remontée sans sortir)")
runFor(0.5)
check(machineOf(alice) == nil, "descendu mais encore dans la zone : ne remonte pas")
moveTo(alice, P + Vector3.new(4, 3, 0))
runFor(0.2)
standAt(alice, A)
runFor(0.5)
check(machineOf(alice) == "Treadmill", "nouvelle séance")

---------------------------------------------------------------- T8 Stop d'un service
print("\nT8 : TrainingService.Stop sur la bande : il faut descendre puis remonter")
TrainingService.Stop(alice)
check(machineOf(alice) == nil, "Stop : séance finie")
runFor(1.0)
check(machineOf(alice) == nil, "resté immobile sur la bande 1 s : pas de reprise")
moveTo(alice, P + Vector3.new(4, 3, 0))
runFor(0.2)
standAt(alice, A)
runFor(0.5)
check(machineOf(alice) == "Treadmill", "descendu puis remonté : reprise")
-- Stop pendant l'attente (arrêté sur la bande, pas encore en séance).
moveTo(alice, P + Vector3.new(4, 3, 0))
runFor(0.2)
standAt(alice, A)
runFor(0.1)
TrainingService.Stop(alice)
runFor(0.8)
check(machineOf(alice) == nil, "Stop avant le début : pas de séance tant qu'il ne redescend pas")

---------------------------------------------------------------- T9 sauter hors du tapis
print("\nT9 : sauter hors du tapis arrête la séance")
moveTo(alice, P + Vector3.new(4, 3, 0))
runFor(0.2)
standAt(alice, A)
runFor(1.0) -- au-delà de SETTLE_TIME (0,5 s après le début)
check(machineOf(alice) == "Treadmill", "en séance")
clearLog()
setState(humOf(alice), "Enum.HumanoidStateType.Jumping")
moveTo(alice, P + Vector3.new(0, 6, -6), Vector3.new(0, 20, -16))
runFor(DT)
check(machineOf(alice) == nil and logHas("quitte le tapis (descendu du tapis)", "PRINT"), "sauté devant le tapis : séance finie")
setState(humOf(alice), "Enum.HumanoidStateType.Running")

---------------------------------------------------------------- T10 assis, mort
print("\nT10 : assis sur le tapis, puis mort")
moveTo(alice, P + Vector3.new(4, 3, 0))
runFor(0.2)
standAt(alice, A)
runFor(1.2)
check(machineOf(alice) == "Treadmill", "en séance")
setState(humOf(alice), "Enum.HumanoidStateType.Seated")
runFor(DT)
check(machineOf(alice) == nil, "état Seated : séance finie")
setState(humOf(alice), "Enum.HumanoidStateType.Running")
runFor(0.8)
check(machineOf(alice) == nil, "toujours sur la bande après : pas de reprise sans descendre")
moveTo(alice, P + Vector3.new(4, 3, 0))
runFor(0.2)
standAt(alice, A)
runFor(0.5)
check(machineOf(alice) == "Treadmill", "redescendu, remonté : reprise")
clearLog()
local hum10 = humOf(alice)
hum10.Health = 0
hum10.Died:Fire()
runFor(DT)
check(machineOf(alice) == nil and logHas("quitte le tapis (mort)", "PRINT"), "mort sur le tapis : séance finie")
respawn(alice, Vector3.new(0, 3, 40))
runFor(0.3)
standAt(alice, A)
runFor(0.5)
check(machineOf(alice) == "Treadmill", "nouveau personnage, posé sur la bande : séance")
moveTo(alice, P + Vector3.new(4, 3, 0))
runFor(0.2)

---------------------------------------------------------------- T11 tapis d'un autre
print("\nT11 : le tapis d'un autre : refusé, un message au plus toutes les 10 s (a65)")
local refusal = "You can only train in your own shop."
standAt(bob, A)
runFor(1.5)
check(machineOf(bob) == nil, "Bob sur le tapis d'Alice : pas d'entraînement")
check(notifies(bob, refusal) == 1, `un seul message en 1,5 s ({notifies(bob, refusal)})`)
moveTo(bob, P + Vector3.new(4, 3, 0))
runFor(0.2)
standAt(bob, A)
runFor(0.5)
check(machineOf(bob) == nil and notifies(bob, refusal) == 1, "sorti, revenu dans les 10 s : refusé, pas de second message (a65)")
moveTo(bob, Vector3.new(0, 3, 50))
standAt(alice, A)
standAt(bob, B)
runFor(0.5)
check(machineOf(alice) == "Treadmill" and machineOf(bob) == "Treadmill", "chacun sur son tapis : deux séances")
moveTo(alice, P + Vector3.new(4, 3, 0))
moveTo(bob, Vector3.new(0, 3, 50))
runFor(0.2)

---------------------------------------------------------------- T12 tapis sans Belt
print("\nT12 : tapis sans Belt : on monte par la zone (boîte du modèle), on reste sur 3 × 3 studs autour du UsePoint")
local PC = C.use.WorldPosition
moveTo(carl, PC + Vector3.new(2.2, 3, 0))
runFor(1.0) -- au-delà de SETTLE_TIME après la montée
check(machineOf(carl) == "Treadmill", "à 2,2 studs du UsePoint, dans la boîte du tapis : séance (a65, zone)")
check((rootOf(carl).Position - (PC + Vector3.new(0, 3, 0))).Magnitude < 1e-6, "placé sur le UsePoint")
moveTo(carl, PC + Vector3.new(4, 3, 0))
runFor(DT)
check(machineOf(carl) == nil, "sorti de la zone de repli : fin")
-- Tapis hors parcelle : rien.
moveTo(carl, looseBelt.Position + Vector3.new(0, 3, 0))
runFor(0.6)
check(machineOf(carl) == nil, "tapis hors parcelle (_INBOX_CLEMENT) : rien")
moveTo(carl, Vector3.new(0, 3, 60))

---------------------------------------------------------------- T13 banc
print("\nT13 : banc : on y monte en entrant dans sa zone (a65, L-093), immobilisé, on descend en sautant")
moveTo(alice, A.benchUse.WorldPosition + Vector3.new(0, 3, 3))
runFor(0.4)
check(machineOf(alice) == "Bench", "au banc, sans invite")
check(StatsService.Mods[alice].Training == 0 and humOf(alice).AutoRotate == false, "immobilisé (modificateur Training = 0), sans rotation")
check(A.benchUse:FindFirstChild("TrainingPrompt") == nil, "toujours aucune invite")
local reps0 = alice:GetAttribute("BenchReps") or 0
NetClient.Client.TrainTap:Fire()
runFor(DT)
check((alice:GetAttribute("BenchReps") or 0) == reps0 + 1, "un tap : une répétition")
runFor(0.6)
setState(humOf(alice), "Enum.HumanoidStateType.Jumping")
runFor(DT)
check(machineOf(alice) == nil and StatsService.Mods[alice].Training == nil and humOf(alice).AutoRotate == true, "saut : descendu, libre, rotation rendue")
setState(humOf(alice), "Enum.HumanoidStateType.Running")
runFor(1)
check(machineOf(alice) == nil, "resté dans la zone : ne remonte pas")
moveTo(bob, A.benchUse.WorldPosition + Vector3.new(1, 3, -2))
runFor(0.5)
check(machineOf(bob) == nil and logHas("Bob ne peut pas s'entraîner", "PRINT"), "Bob au banc d'Alice : refusé")
moveTo(bob, Vector3.new(0, 3, 50))
-- Du banc au tapis : pas de séance au tapis tant qu'il est au banc.
moveTo(alice, A.benchUse.WorldPosition + Vector3.new(0, 3, 6))
runFor(0.2)
moveTo(alice, A.benchUse.WorldPosition + Vector3.new(0, 3, 2))
runFor(0.4)
check(machineOf(alice) == "Bench", "sortie puis retour dans la zone : de nouveau au banc")
runFor(1)
check(machineOf(alice) == "Bench", "le contrôle des zones ne le prend pas")
TrainingService.Stop(alice)
runFor(DT)
moveTo(alice, Vector3.new(0, 3, 40))
runFor(0.2)

---------------------------------------------------------------- T14 départ
print("\nT14 : départ en pleine séance")
local erin = addPlayer("Erin", Vector3.new(0, 3, 80))
DataService.Data[erin] = { Upgrades = { Treadmill = 2, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 } }
local E = makePlot("PLOT_E", erin, Vector3.new(-200, 0, 300), true)
runFor(DT)
standAt(erin, E)
runFor(0.5)
check(machineOf(erin) == "Treadmill", "Erin en séance (tapis posé après Init)")
local t14 = now()
runFor(1.0)
local _, total14 = speedAdds(erin, t14)
check(math.abs(total14 - 2) < 1e-6, `niveau 2 : +2 par seconde (× 1 + 0,5 × 2) ({total14})`)
clearLog()
Players.PlayerRemoving:Fire(erin)
erin.Parent = nil
runFor(0.3)
check(logHas("Erin quitte le tapis (départ)", "PRINT"), "sortie : départ")
check(not logHas("ERREUR", nil), "aucune erreur")

---------------------------------------------------------------- G vigiles
print("\nG : coup du vigile en un seul geste (Catch puis Knockback)")
local NAMES = {
	{ "STORE_Z1_Superette", "STORE_Z1_Kiosque" },
	{ "STORE_Z2_MagasinDeJouets", "STORE_Z2_Confiserie" },
	{ "STORE_Z3_Electronique", "STORE_Z3_JeuxVideo" },
	{ "STORE_Z4_Bijouterie", "STORE_Z4_Horlogerie" },
	{ "STORE_Z5_GalerieDArt", "STORE_Z5_Antiquaire" },
	{ "STORE_Z6_Banque", "STORE_Z6_SalleDesCoffres" },
}
local DISTANCE = { 60, 140, 240, 360, 500, 660 }
local STORES = {}
local function makeStore(name, zone, x, side, parent)
	local m = new("Model", name)
	m:SetAttribute("Zone", zone)
	local frame = CFrame.new(x, 0, side * 34) * (if side > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0))
	local floor = new("Part", "Floor", m)
	floor.Size = Vector3.new(23, 1.2, 27)
	floor.CFrame = frame * CFrame.new(0, -0.4, 0)
	floor.Anchored = true
	local spawnAt = frame * CFrame.new(0, 0.2, 7)
	local a = new("Attachment", "GuardSpawn", floor)
	a.CFrame = floor.CFrame:ToObjectSpace(spawnAt)
	local window = new("Part", "Window", m)
	window.Size = Vector3.new(8, 6, 0.4)
	window.CFrame = frame * CFrame.new(0, 3.5, -13.5)
	window:SetAttribute("WindowId", name)
	m.WorldPivot = frame
	m.Parent = parent
	addTag(m, "NPCStore")
	return { model = m, frame = frame, spawn = spawnAt.Position, zone = zone, inside = (frame * CFrame.new(0, 3, -4)).Position }
end
for zone = 1, 6 do
	STORES[NAMES[zone][1]] = makeStore(NAMES[zone][1], zone, DISTANCE[zone], 1, Workspace)
	STORES[NAMES[zone][2]] = makeStore(NAMES[zone][2], zone, DISTANCE[zone], -1, Workspace)
end
local safe = new("Model", "SafeZone")
local bounds = new("Part", "Bounds", safe)
bounds.Size = Vector3.new(240, 40, 240)
bounds.CFrame = CFrame.new(-120, 20, 0)
safe.Parent = Workspace
addTag(safe, "SafeZone")

-- Modèle de Clément pour la zone 3 (comme le S8 d'a12) ; les autres zones : rig de remplacement en
-- blocs, sans animation (Catch pas livrée).
local Assets = folder(ReplicatedStorage, "Assets")
local GuardsF = folder(Assets, "Guards")
local tpl = new("Model", "Guard_Z3")
local tRoot = new("Part", "HumanoidRootPart", tpl)
tRoot.Size = Vector3.new(2, 2, 1)
tRoot.CFrame = CFrame.new(0, 3, 0)
tRoot.Anchored = true
local tHead = new("Part", "Head", tpl)
tHead.CFrame = CFrame.new(0, 5, 0)
tHead.Anchored = true
local tHum = new("Humanoid", "Humanoid", tpl)
tHum.HipHeight = 1.5
new("Animator", "Animator", tHum)
local animsF = folder(tpl, "Animations")
for _, n in { "Idle", "Walk", "Run", "Catch", "Tired" } do
	new("Animation", n, animsF).AnimationId = "rbxassetid://123"
end
tpl.PrimaryPart = tRoot
tpl.Parent = GuardsF
TRACK_LENGTH.Tired = 2

-- Capture du joueur local (Dana) dans `store` ; renvoie les instants de la capture et du coup, et
-- ce que StatsService a reçu pour elle (GuardStun) pendant ce temps.
local function catchDana(store, seconds)
	moveTo(dana, store.inside)
	local statsBefore = #StatsService.Log
	local callsBefore = #AnimationController.Calls
	local notifyBefore = #remotesTo("Notify", dana)
	local t0 = now()
	CarryService.StartCarry(dana, payload(store.model.Name, store.zone))
	local caught, knock, notified = nil, nil, nil
	-- 2026-11-10 : +1 s, l'étourdissement passe de 1,5 à 2,4 s (chute Knockdown puis GetUp, L-076).
	runFor(seconds + 1, function()
		local last = CarryService.Calls[#CarryService.Calls]
		if caught == nil and last and last.player == dana and last.t >= t0 then
			caught = last.t
		end
		if knock == nil and rootOf(dana):FindFirstChild("GuardKnockback") then
			knock = now()
		end
		if notified == nil and #remotesTo("Notify", dana) > notifyBefore then
			notified = now()
		end
	end)
	local stuns = {}
	for i = statsBefore + 1, #StatsService.Log do
		local e = StatsService.Log[i]
		if e.player == dana and e.key == "GuardStun" then
			table.insert(stuns, e)
		end
	end
	local calls = {}
	for i = callsBefore + 1, #AnimationController.Calls do
		table.insert(calls, AnimationController.Calls[i])
	end
	return { caught = caught, knock = knock, notified = notified, stuns = stuns, calls = calls }
end
local function release(stuns)
	local last = stuns[#stuns]
	return if last and last.mult == nil then last.t else nil
end
local function clientCall(calls, name, action)
	for _, c in calls do
		if c.name == name and c.action == action then
			return c.t
		end
	end
	return nil
end

print("\nG1 : Catch livrée, Impact tardif (0,8 s) : la poussée l'attend (avant : 0,6 s au plus)")
TRACK_LENGTH.Catch = 1.4
MARKER_AT.Catch = { "Impact", 0.8 }
local elec = STORES.STORE_Z3_Electronique
local g1 = catchDana(elec, 4)
check(g1.caught ~= nil and g1.knock ~= nil, `rattrapée et poussée ({f2(g1.caught)}, {f2(g1.knock)})`)
if g1.caught and g1.knock then
	check(near(g1.knock - g1.caught, 0.8, 0.05), `poussée au marqueur Impact : {f2(g1.knock - g1.caught)} s après la capture`)
	check(g1.notified and near(g1.notified, g1.caught, 0.05), "Notify à la capture, pas au coup")
	local s = g1.stuns
	check(s[1] and s[1].mult == 0 and near(s[1].t, g1.caught, 0.05), "immobilisée dès la capture")
	check(s[2] and s[2].mult == 0 and near(s[2].t, g1.knock, 0.05), "étourdissement relancé au coup")
	local rel = release(s)
	check(rel and near(rel - g1.knock, Balance.Guard.CatchStunDuration, 0.05), `libérée {Balance.Guard.CatchStunDuration} s après le coup ({f2(rel and rel - g1.knock)})`)
	-- 2026-11-10 (L-076) : la chute de Clément remplace Knockback puis Stunned.
	local kd = clientCall(g1.calls, "Knockdown", "Play")
	local up = clientCall(g1.calls, "GetUp", "Play")
	check(kd and near(kd, g1.knock, 0.05), "client : Knockdown joué au coup")
	check(up and kd and up >= kd, "client : GetUp après Knockdown")
	check(clientCall(g1.calls, "Knockback", "Play") == nil and clientCall(g1.calls, "Stunned", "Play") == nil, "client : plus de Knockback ni de Stunned")
end
check(runUntilEmpty(10), "vigile rentré")
runFor(0.5)

print("\nG2 : Catch livrée sans marqueur : poussée à la fin de Catch")
TRACK_LENGTH.Catch = 1.2
MARKER_AT.Catch = nil
local g2 = catchDana(elec, 4)
check(g2.caught and g2.knock and near(g2.knock - g2.caught, 1.2, 0.05), `poussée à la fin de Catch (1,2 s) : {f2(g2.knock and g2.caught and g2.knock - g2.caught)}`)
local rel2 = release(g2.stuns)
check(rel2 and g2.knock and near(rel2 - g2.knock, Balance.Guard.CatchStunDuration, 0.05), "libérée à la fin de l'étourdissement après le coup")
check(runUntilEmpty(10), "vigile rentré")
runFor(0.5)

print("\nG3 : Catch pas encore chargée (durée 0) : poussée après 0,6 s")
TRACK_LENGTH.Catch = 0
local g3 = catchDana(elec, 3)
check(g3.caught and g3.knock and near(g3.knock - g3.caught, 0.6, 0.05), `poussée après KNOCKBACK_MAX_WAIT : {f2(g3.knock and g3.caught and g3.knock - g3.caught)}`)
check(runUntilEmpty(10), "vigile rentré")
runFor(0.5)

print("\nG4 : Impact à 0,3 s (la Catch d'aujourd'hui) : inchangé")
TRACK_LENGTH.Catch = 1.4
MARKER_AT.Catch = { "Impact", 0.3 }
local g4 = catchDana(elec, 3)
check(g4.caught and g4.knock and near(g4.knock - g4.caught, 0.3, 0.05), `poussée à 0,3 s : {f2(g4.knock and g4.caught and g4.knock - g4.caught)}`)
local rel4 = release(g4.stuns)
check(rel4 and g4.knock and near(rel4 - g4.knock, Balance.Guard.CatchStunDuration, 0.05), "libérée à la fin de l'étourdissement après le coup")
check(runUntilEmpty(10), "vigile rentré")
runFor(0.5)

print("\nG5 : Catch pas livrée (rig de remplacement, zone 1) : poussée tout de suite")
local sup = STORES.STORE_Z1_Superette
local g5 = catchDana(sup, 3)
check(g5.caught and g5.knock and math.abs(g5.knock - g5.caught) < 0.05, "poussée à la capture")
check(#g5.stuns == 2 and g5.stuns[1].mult == 0 and release(g5.stuns) and near(release(g5.stuns) - g5.caught, Balance.Guard.CatchStunDuration, 0.05), "un seul étourdissement, compté depuis la capture")
check(runUntilEmpty(10), "vigile rentré")

check(not logHas("ERREUR", nil), "aucune erreur")
summary()
