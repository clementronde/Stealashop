--!nocheck
-- Scénarios a12 : GuardService (serveur) et ChaseController (client), avec les vrais Net,
-- AnimPlayer, MarkerSounds, Config et Contract. CarryService, StatsService et
-- AnimationController sont des bouchons. RIG_MODE = "roblox" (rig de Roblox) ou "blocks"
-- (CreateHumanoidModelFromDescriptionAsync échoue : rig en blocs).

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
moduleScript(Shared, "Format", "shared/Format.luau") -- a21 : GuardService lit Shared/Format depuis a18
local Services = folder(folder(ServerScriptService, "Server"), "Services")
moduleScript(Services, "AntiCheatService", "stub/AntiCheatService") -- a36 (DEV-060) : GuardService déclare ses poussées (Allow)
local CarryModule = moduleScript(Services, "CarryService", "stub/CarryService.luau")
local StatsModule = moduleScript(Services, "StatsService", "stub/StatsService.luau")
local GuardModule = moduleScript(Services, "GuardService", "server/Services/GuardService.luau")
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

-- Rig rendu par Players:CreateHumanoidModelFromDescriptionAsync (bouchon) : posé loin, avec
-- son script Animate, sans Animator.
local function makeRobloxRig(_description, _rigType)
	local m = new("Model", "Player")
	local root = new("Part", "HumanoidRootPart", m)
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(500, 50, 500)
	local head = new("Part", "Head", m)
	head.CFrame = CFrame.new(500, 52, 500)
	local hum = new("Humanoid", "Humanoid", m)
	hum.HipHeight = 2
	local animate = new("LocalScript", "Animate", m)
	new("Folder", "run", animate)
	m.PrimaryPart = root
	return m
end
if RIG_MODE == "roblox" then
	RIG_FACTORY = makeRobloxRig
end

-- Magasins comme la greybox : vitrine en X = distance de retour, côté N (Z > 0) ou S.
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
local function makeStore(name, zone, x, side, parent, tagged)
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
	if tagged ~= false then
		addTag(m, "NPCStore")
	end
	return { model = m, frame = frame, spawn = spawnAt.Position, zone = zone, inside = (frame * CFrame.new(0, 3, -4)).Position, street = (frame * CFrame.new(0, 3, -26)).Position }
end
for zone = 1, 6 do
	STORES[NAMES[zone][1]] = makeStore(NAMES[zone][1], zone, DISTANCE[zone], 1, Workspace)
	STORES[NAMES[zone][2]] = makeStore(NAMES[zone][2], zone, DISTANCE[zone], -1, Workspace)
end
-- Mêmes noms hors de la map : ignorés
local Assets = folder(ReplicatedStorage, "Assets")
makeStore("STORE_Z1_Superette", 1, 0, 1, Assets)
local inbox = folder(Workspace, "_INBOX_CLEMENT")
makeStore("STORE_Z1_Superette", 1, 0, 1, inbox)

-- Zone safe : X < 0, comme la greybox
local safe = new("Model", "SafeZone")
local bounds = new("Part", "Bounds", safe)
bounds.Size = Vector3.new(240, 40, 240)
bounds.CFrame = CFrame.new(-120, 20, 0)
safe.Parent = Workspace
addTag(safe, "SafeZone")

---------------------------------------------------------------- joueurs
local nextId = 100
local function addPlayer(name, pos)
	nextId += 1
	local p = new("Player", name)
	p.UserId = nextId
	p.Parent = Players
	local char = new("Model", name)
	local root = new("Part", "HumanoidRootPart", char)
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(pos)
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
local function payload(storeName, zone)
	return { Kind = "NPCBox", Tier = "Standard", Zone = zone, Rarity = "Common", ItemId = "Z1_Canette", StoreId = storeName, SlotId = "ShelfSlot_01" }
end

local alice = addPlayer("Alice", STORES.STORE_Z1_Superette.inside)
CLIENT_PLAYER = alice
Players.LocalPlayer = alice

---------------------------------------------------------------- simulation
local DT = 1 / 30
local motion = {} -- [player] = function(position, dt) -> nouvelle position
local guardTrack = {} -- [model] = { minX }

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
					-- Collision grossière : pas d'avance dans un mur (rayon 1 stud).
					local blocked = false
					for _, wall in WALLS do
						local l = wall.cframe:PointToObjectSpace(nextPos)
						if math.abs(l.X) <= wall.size.X / 2 + 1 and math.abs(l.Y) <= wall.size.Y / 2 + 1 and math.abs(l.Z) <= wall.size.Z / 2 + 1 then
							blocked = true
						end
					end
					if not blocked then
						root.CFrame = root.CFrame + (nextPos - pos)
					end
				end
			end
			local track = guardTrack[model] or { minX = math.huge }
			guardTrack[model] = track
			track.minX = math.min(track.minX, root.Position.X)
		end
	end
end

local function runFor(seconds, every)
	local steps = math.floor(seconds / DT + 0.5)
	for _ = 1, steps do
		for player, fn in motion do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local p = fn(root.Position, DT)
				if p then
					root.CFrame = CFrame.new(p)
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

-- Court vers `goal` à `speed` studs/s (horizontalement).
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
local function animPlays(name, since)
	local n = 0
	for _, e in ANIM_LOG do
		if e.name == name and e.action == "Play" and e.t >= (since or 0) then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- chargement
local Balance = requireModule(ConfigF:FindFirstChild("Balance"), "server")
local CarryService = requireModule(CarryModule, "server")
local StatsService = requireModule(StatsModule, "server")
local GuardService = requireModule(GuardModule, "server")
GuardService.Start()
local AnimationController = requireModule(AnimModule, "client")
local ChaseController = requireModule(ChaseModule, "client")
taskLib.spawn(ChaseController.Start)
runFor(0.5) -- le rig de remplacement se construit

print(`\n== Mode du rig de remplacement : {RIG_MODE}`)

---------------------------------------------------------------- S1 apparition
print("\nS1 : apparition au GuardSpawn, délai de réaction, vitesse de la zone")
clearLog()
local superette = STORES.STORE_Z1_Superette
check(CarryService.StartCarry(alice, payload("STORE_Z1_Superette", 1)), "portage démarré (bouchon)")
runFor(DT)
local g1 = guardOf(alice)
check(g1 ~= nil and #guards() == 1, "un vigile en jeu, dans Workspace.ActiveGuards")
local root1 = g1 and g1:FindFirstChild("HumanoidRootPart")
local hum1 = g1 and g1:FindFirstChildOfClass("Humanoid")
check(g1 and g1.Name == "Guard_Fallback", "rig de remplacement (pas de modèle de Clément)")
check(g1 and g1:GetAttribute("TargetUserId") == alice.UserId, "attribut TargetUserId = joueur poursuivi")
check(g1 and g1.ModelStreamingMode == "Enum.ModelStreamingMode.PersistentPerPlayer" and rawget(g1, "_persistent")[alice], "persistant pour le joueur poursuivi")
check(root1 and rawget(root1, "_networkOwnerSet") and rawget(root1, "_networkOwner") == nil, "physique au serveur (SetNetworkOwner(nil))")
local states = hum1 and rawget(hum1, "_states") or {}
check(states["Enum.HumanoidStateType.Swimming"] == false and states["Enum.HumanoidStateType.Climbing"] == false, "nage et escalade coupées (9.7)")
check(states["Enum.HumanoidStateType.Seated"] == false and states["Enum.HumanoidStateType.Ragdoll"] == false, "assis et ragdoll coupés")
check(hum1 and hum1.BreakJointsOnDeath == false, "BreakJointsOnDeath coupé")
check(hum1 and hum1:FindFirstChildOfClass("Animator") ~= nil, "Animator présent dans le Humanoid")
check(root1 and near(root1.Position.X, superette.spawn.X, 1e-6) and near(root1.Position.Z, superette.spawn.Z, 1e-6), "posé sur le GuardSpawn")
check(root1 and hum1 and near(root1.Position.Y, superette.spawn.Y + hum1.HipHeight + root1.Size.Y / 2, 1e-6), "pieds au niveau du GuardSpawn")
check(root1 and not root1.Anchored, "HumanoidRootPart désancré")
check(g1 and g1:FindFirstChild("Animate", true) == nil, "aucun script dans le vigile en jeu")
if RIG_MODE == "blocks" then
	check(g1 and g1:FindFirstChild("UpperTorso") ~= nil and hum1.RequiresNeck == false, "rig en blocs (RequiresNeck coupé)")
	local warnedBlocks = false
	for _, line in FULL_LOG do
		if line.kind == "WARN" and string.find(line.text, "vigile en blocs", 1, true) then
			warnedBlocks = true
		end
	end
	check(warnedBlocks, "avertissement : rig de Roblox impossible")
else
	check(hum1 and hum1.DisplayDistanceType == "Enum.HumanoidDisplayDistanceType.None", "pas de nom au-dessus du rig de remplacement")
end
local cs = lastRemote("ChaseState", alice)
check(cs and cs.args[1] == true and cs.args[2] == g1, "ChaseState(true, vigile) envoyé au voleur")
check(hum1 and hum1.WalkSpeed == 0, "immobile pendant le délai de réaction")
check(logHas("[Poursuite] un vigile te poursuit", "PRINT"), "client : début de poursuite écrit dans la sortie")
runFor(0.45)
check(hum1 and hum1.WalkSpeed == 0, "toujours immobile à 0,47 s")
runFor(0.1)
check(hum1 and hum1.WalkSpeed == 13.4, "s'élance à 13,4 (vitesse du vigile, zone 1)")

---------------------------------------------------------------- S2 capture
print("\nS2 : capture à ≤ 4 studs, colis, étourdissement, coup, message, retour")
local caughtAt = nil
local minDistance = math.huge
local knockSeen = nil
runFor(3, function()
	if caughtAt == nil and #CarryService.Calls > 0 then
		caughtAt = now()
	end
	local r = root1
	if r and r.Parent then
		minDistance = math.min(minDistance, (r.Position - rootOf(alice).Position).Magnitude)
	end
	local k = rootOf(alice):FindFirstChild("GuardKnockback")
	if k and knockSeen == nil then
		knockSeen = { t = now(), mover = k:FindFirstChild("GuardKnockback") }
	end
end)
local call = CarryService.Calls[1]
check(call and call.player == alice and call.result == "Failed" and call.reason == "Caught", "CarryService.Fail(player, \"Caught\")")
check(minDistance <= Balance.Guard.CatchDistance + 0.5 and minDistance > Balance.Guard.CatchDistance - 0.5, `rattrapé à ≈ 4 studs (plus courte distance {string.format("%.2f", minDistance)})`)
local notify = lastRemote("Notify", alice)
check(notify and notify.args[1] == "Caught! Recommended speed: 16" and notify.args[2] == "Warning", "Notify « Caught! Recommended speed: 16 »")
local csEnd = lastRemote("ChaseState", alice)
check(csEnd and csEnd.args[1] == false and csEnd.args.n == 1, "ChaseState(false) à la capture")
check(knockSeen ~= nil and caughtAt ~= nil and math.abs(knockSeen.t - caughtAt) < 0.05, "poussée tout de suite (Catch pas livrée)")
local mover = knockSeen and knockSeen.mover
if mover then
	local v = mover.VectorVelocity
	check(near(v.Y, 25, 1e-6) and near(Vector3.new(v.X, 0, v.Z).Magnitude, 40, 1e-6), "LinearVelocity : 40 studs/s à l'horizontale, 25 vers le haut")
	check(v.Z < 0, "projeté à l'opposé du vigile (vers la rue)")
	check(mover.MaxForce == math.huge and mover.RelativeTo == "Enum.ActuatorRelativeTo.World", "force illimitée, repère monde")
else
	check(false, "LinearVelocity GuardKnockback trouvée")
end
check(rootOf(alice):FindFirstChild("GuardKnockback") == nil, "poussée retirée ensuite (Debris)")
local stunLog = StatsService.Log
check(stunLog[1] and stunLog[1].key == "GuardStun" and stunLog[1].mult == 0, "étourdi : modificateur GuardStun = 0")
check(stunLog[2] and stunLog[2].mult == nil and near(stunLog[2].t - stunLog[1].t, Balance.Guard.CatchStunDuration, 1e-6), "étourdissement levé après CatchStunDuration")
local calls = AnimationController.Calls
-- 2026-11-10 (L-076) : la chute de Clément (Knockdown 1,2 s, puis GetUp) remplace Knockback puis Stunned.
check(calls[1] and calls[1].name == "Knockdown" and calls[1].action == "Play", "client : Knockdown joué")
check(calls[2] and calls[2].name == "GetUp" and calls[2].action == "Play" and near(calls[2].t - calls[1].t, 1.2, 0.05), "client : GetUp à la fin de Knockdown")
check(logHas("♥ vigile à moins de 10 studs", "PRINT"), "client : repère sous HeartbeatDistance")
check(not logHas("[Poursuite] vigile à ", "PRINT"), "client : distance plus écrite dans la sortie (a15 : jauge GuardMeter du HUD)")
check(logHas("[Poursuite] fin de la poursuite", "PRINT"), "client : fin de poursuite écrite")
check(ChaseController.IsChased() == false and ChaseController.GetDistance() == nil, "client : plus de poursuite")
check(GuardService.IsChased(alice) == false, "serveur : IsChased = false")
check(runUntilEmpty(5), "le vigile rentre et disparaît")
check(logHas("parti (rentré)", "PRINT"), "disparu une fois rentré au GuardSpawn")

---------------------------------------------------------------- S3 zone safe
print("\nS3 : abandon en zone safe, sans jamais la franchir")
clearLog()
local bob = addPlayer("Bob", superette.inside)
CarryService.StartCarry(bob, payload("STORE_Z1_Superette", 1))
runFor(DT)
local g3 = guardOf(bob)
local hum3 = g3 and g3:FindFirstChildOfClass("Humanoid")
motion[bob] = runTo(Vector3.new(-30, 3, 0), 20)
local gaveUpAt = nil
runFor(8, function()
	if gaveUpAt == nil and logHas("abandonne Bob (zone safe)", "PRINT") then
		gaveUpAt = now()
	end
end)
motion[bob] = nil
check(gaveUpAt ~= nil, "abandon : le joueur est en zone safe")
check(g3 and guardTrack[g3] and guardTrack[g3].minX >= 0, `le vigile reste hors de la zone safe (X min {g3 and guardTrack[g3] and string.format("%.2f", guardTrack[g3].minX)})`)
local cs3 = lastRemote("ChaseState", bob)
check(cs3 and cs3.args[1] == false, "ChaseState(false) à l'abandon")
check(CarryService.IsCarrying(bob), "le voleur garde son colis")
check(runUntilEmpty(25), "le vigile rentre en marchant puis disparaît")
check(hum3 and hum3.WalkSpeed == 10, "retour à 10 (marche)")
CarryService.Consume(bob)

---------------------------------------------------------------- S4 20 s
print("\nS4 : abandon après 20 s de poursuite")
clearLog()
local carl = addPlayer("Carl", superette.inside)
local startedAt = now()
CarryService.StartCarry(carl, payload("STORE_Z1_Superette", 1))
motion[carl] = runTo(Vector3.new(650, 3, 0), 13.4) -- même vitesse que le vigile : l'écart ne bouge plus
local gaveUp4 = nil
runFor(22, function()
	if gaveUp4 == nil and logHas("abandonne Carl (20 s de poursuite)", "PRINT") then
		gaveUp4 = now()
	end
end)
motion[carl] = nil
check(gaveUp4 ~= nil and near(gaveUp4 - startedAt, 20, 0.1), `abandon à 20 s ({gaveUp4 and string.format("%.2f", gaveUp4 - startedAt)} s)`)
CarryService.Consume(carl)
check(runUntilEmpty(30), "puis disparaît")

---------------------------------------------------------------- S5 120 studs
print("\nS5 : abandon à 120 studs d'avance")
clearLog()
local dana = addPlayer("Dana", superette.inside)
CarryService.StartCarry(dana, payload("STORE_Z1_Superette", 1))
runFor(DT)
local g5 = guardOf(dana)
motion[dana] = runTo(Vector3.new(650, 3, 0), 60)
local lead = nil
runFor(5, function()
	if lead == nil and logHas("abandonne Dana (120 studs d'avance)", "PRINT") then
		local r = g5:FindFirstChild("HumanoidRootPart")
		lead = (r.Position - rootOf(dana).Position).Magnitude
	end
end)
motion[dana] = nil
check(lead ~= nil and lead >= 120 and lead < 125, `abandon à ≥ 120 studs ({lead and string.format("%.1f", lead)})`)
CarryService.Consume(dana)
check(runUntilEmpty(30), "puis disparaît")

---------------------------------------------------------------- S6 fin de portage
print("\nS6 : le portage finit autrement (colis posé) : abandon, essoufflé")
clearLog()
local eve = addPlayer("Eve", Vector3.new(60, 3, 0))
CarryService.StartCarry(eve, payload("STORE_Z1_Superette", 1))
runFor(1)
CarryService.Consume(eve)
runFor(DT)
check(logHas("abandonne Eve (portage fini : Consumed (Placed))", "PRINT"), "abandon sur OnCarryEnded")
local cs6 = lastRemote("ChaseState", eve)
check(cs6 and cs6.args[1] == false, "ChaseState(false)")
check(runUntilEmpty(10), "puis disparaît")

-- Fin du portage pendant le délai de réaction : retour direct, sans essoufflement
clearLog()
local finn = addPlayer("Finn", superette.inside)
CarryService.StartCarry(finn, payload("STORE_Z1_Superette", 1))
runFor(0.2)
CarryService.Consume(finn)
runFor(0.2)
-- a45 (L-077) : il s'efface en fondu (Balance.Guard.ReturnFadeTime, 0,6 s), plus d'un coup. Sur un
-- arbre sans ce réglage (avant la fusion d'a45), l'attente d'avant.
A45_FADE = string.find(SOURCES["shared/Config/Balance.luau"] or "", "ReturnFadeTime", 1, true) ~= nil
if A45_FADE then
	check(#guards() == 1 and logHas("s'efface en 0.6 s (rentré)", "PRINT") and not logHas("parti (rentré)", "PRINT"), "fin pendant le délai : il s'efface sur place, en fondu")
	runFor(0.6)
	check(#guards() == 0 and logHas("parti (rentré)", "PRINT"), "fin pendant le délai : parti une fois le fondu fini")
else
	check(#guards() == 0 and logHas("parti (rentré)", "PRINT"), "fin pendant le délai : il disparaît sur place")
end

---------------------------------------------------------------- S7 plafonds
print("\nS7 : 3 vigiles par magasin, 6 sur le serveur")
clearLog()
local crowd = {}
for i = 1, 4 do
	local p = addPlayer(`Z1_{i}`, superette.street)
	table.insert(crowd, p)
	CarryService.StartCarry(p, payload("STORE_Z1_Superette", 1))
end
runFor(DT)
check(#guards() == 3, `3 vigiles pour 4 voleurs du même magasin ({#guards()})`)
check(logHas("déjà 3 vigiles en poursuite", "PRINT"), "le 4e voleur n'a pas de vigile")
local spawnSpots = {}
for _, g in guards() do
	local r = g:FindFirstChild("HumanoidRootPart")
	spawnSpots[string.format("%.1f", r.Position.Z)] = true
end
local spots = 0
for _ in spawnSpots do
	spots += 1
end
check(spots == 3, "vigiles simultanés décalés, pas superposés")
local others = {}
for i, name in { "STORE_Z1_Kiosque", "STORE_Z2_MagasinDeJouets", "STORE_Z2_Confiserie", "STORE_Z3_Electronique" } do
	local p = addPlayer(`O_{i}`, STORES[name].street)
	table.insert(others, p)
	CarryService.StartCarry(p, payload(name, STORES[name].zone))
end
runFor(DT)
check(#guards() == 6, `6 vigiles au plus sur le serveur ({#guards()})`)
check(logHas("déjà 6 vigiles en poursuite sur le serveur", "PRINT"), "le 7e n'a pas de vigile (9.7)")
-- Un vigile abandonne (essoufflé) : il laisse sa place au suivant
runFor(0.6)
CarryService.Consume(others[1])
runFor(DT)
local late = addPlayer("Late", STORES.STORE_Z4_Bijouterie.street)
CarryService.StartCarry(late, payload("STORE_Z4_Bijouterie", 4))
runFor(DT)
-- a45 (L-077) : celui qui rentre s'efface en fondu (0,6 s) ; il ne compte plus dans le plafond.
if A45_FADE then
	check(#guards() == 7 and guardOf(late) ~= nil, "un vigile qui rentre s'efface (fondu) pour le nouveau")
else
	check(#guards() == 6 and guardOf(late) ~= nil, "un vigile qui rentre disparaît pour le nouveau")
end
check(logHas("place libérée pour un nouveau vigile", "PRINT"), "raison écrite dans la sortie")
local g7 = guardOf(late)
runFor(0.6)
check(g7 and g7:FindFirstChildOfClass("Humanoid").WalkSpeed == 29.6, "zone 4 : 29,6")
runFor(0.1)
check(#guards() == 6, `6 vigiles en jeu ({#guards()})`)
for _, p in crowd do
	CarryService.Consume(p)
end
for _, p in others do
	CarryService.Consume(p)
end
CarryService.Consume(late)
check(runUntilEmpty(30), "tous rentrés")

---------------------------------------------------------------- S8 modèle de Clément
print("\nS8 : modèle de Clément (Guard_Z3), animations, coup au marqueur Impact")
clearLog()
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
	local a = new("Animation", n, animsF)
	a.AnimationId = "rbxassetid://123"
end
new("Script", "Junk", tpl)
tpl.PrimaryPart = tRoot
tpl.Parent = GuardsF
TRACK_LENGTH.Catch = 1.2
TRACK_LENGTH.Tired = 2
MARKER_AT.Catch = { "Impact", 0.3 }
local elec = STORES.STORE_Z3_Electronique
local gus = addPlayer("Gus", elec.inside)
local t0 = now()
CarryService.StartCarry(gus, payload("STORE_Z3_Electronique", 3))
runFor(DT)
local g8 = guardOf(gus)
check(g8 and g8.Name == "Guard_Z3", "clone de ReplicatedStorage.Assets.Guards.Guard_Z3")
check(g8 and g8:FindFirstChild("Junk") == nil and tpl:FindFirstChild("Junk") ~= nil, "script retiré du clone, pas du modèle de Clément")
check(logHas("script « Junk » retiré", "WARN"), "avertissement pour le script")
check(g8 and not g8:FindFirstChild("HumanoidRootPart").Anchored, "clone désancré")
local r8 = g8 and g8:FindFirstChild("HumanoidRootPart")
check(r8 and near(r8.Position.Y, elec.spawn.Y + 1.5 + 1, 1e-6), "posé selon la HipHeight du modèle")
check(animPlays("Idle", t0) == 1, "Idle joué à l'apparition")
runFor(0.6)
check(animPlays("Run", t0) == 1 and g8:FindFirstChildOfClass("Humanoid").WalkSpeed == 24.2, "Run joué, vitesse 24,2 (zone 3)")
local caught8, knock8 = nil, nil
runFor(3, function()
	if caught8 == nil and #CarryService.Calls > 0 and CarryService.Calls[#CarryService.Calls].player == gus then
		caught8 = now()
	end
	if knock8 == nil and rootOf(gus):FindFirstChild("GuardKnockback") then
		knock8 = now()
	end
end)
check(caught8 ~= nil and animPlays("Catch", t0) == 1, "rattrapé, Catch joué")
check(caught8 and knock8 and near(knock8 - caught8, 0.3, 0.05), "poussée au marqueur Impact de Catch (0,3 s)")
check(logHas("son « Catch_Impact » absent", "WARN"), "son du marqueur cherché (Catch_Impact)")
local n8 = lastRemote("Notify", gus)
check(n8 and n8.args[1] == "Caught! Recommended speed: 28", "Notify avec la vitesse conseillée de la zone 3 (28)")
check(animPlays("Walk", t0) == 1, "Walk au retour")
check(runUntilEmpty(10), "rentré")

-- Marqueur jamais atteint : la poussée part à la fin de Catch (1,2 s ici). a41 (L-071, point 5) :
-- une Catch chargée attend son marqueur Impact jusqu'à sa fin (avant : 0,6 s au plus, ce qui
-- devançait un Impact posé plus tard dans la Catch refaite par Clément).
clearLog()
MARKER_AT.Catch = nil
local hal = addPlayer("Hal", elec.inside)
CarryService.StartCarry(hal, payload("STORE_Z3_Electronique", 3))
local caught9, knock9 = nil, nil
runFor(3, function()
	if caught9 == nil and #CarryService.Calls > 0 and CarryService.Calls[#CarryService.Calls].player == hal then
		caught9 = now()
	end
	if knock9 == nil and rootOf(hal):FindFirstChild("GuardKnockback") then
		knock9 = now()
	end
end)
check(caught9 and knock9 and near(knock9 - caught9, 1.2, 0.05), "sans marqueur, poussée à la fin de Catch (1,2 s)")
check(runUntilEmpty(10), "rentré")

-- Abandon avec le modèle de Clément : Tired joué, pause de sa durée, puis Walk
clearLog()
local ivy = addPlayer("Ivy", elec.street)
local t10 = now()
CarryService.StartCarry(ivy, payload("STORE_Z3_Electronique", 3))
runFor(0.8)
check(CarryService.IsCarrying(ivy), "Ivy pas encore rattrapée")
CarryService.Consume(ivy)
runFor(DT)
check(animPlays("Tired", t10) == 1, "Tired joué à l'abandon")
runFor(1.8)
check(animPlays("Walk", t10) == 0, "essoufflé pendant la durée de Tired (2 s)")
runFor(0.4)
check(animPlays("Walk", t10) == 1, "puis Walk")
check(runUntilEmpty(10), "rentré")
tpl.Parent = nil

---------------------------------------------------------------- S9 chemin
print("\nS9 : sans ligne de vue, PathfindingService recalculé toutes les 0,3 s")
clearLog()
local jo = addPlayer("Jo", Vector3.new(60, 3, -60))
local wall = new("Part", "Wall", Workspace)
table.insert(WALLS, { cframe = CFrame.new(100, 5, 0), size = Vector3.new(200, 10, 1), part = wall })
local paths0 = PATHS_COMPUTED
CarryService.StartCarry(jo, payload("STORE_Z1_Superette", 1))
runFor(0.5 + 1.0) -- délai de réaction, puis 1 s derrière le mur
local computed = PATHS_COMPUTED - paths0
check(computed >= 3 and computed <= 4, `chemins calculés en 1 s : {computed} (≈ 1 / 0,3)`)
local g9 = guardOf(jo)
local r9 = g9 and g9:FindFirstChild("HumanoidRootPart")
check(r9 and r9.Position.Z < superette.spawn.Z - 5, "le vigile avance en suivant le chemin")
table.clear(WALLS)
local rays0 = RAYCASTS
runFor(9)
check(#CarryService.Calls > 0 and CarryService.Calls[#CarryService.Calls].player == jo, "rattrapé une fois la vue dégagée")
check(RAYCASTS > rays0, "ligne de vue testée par rayons")
check(runUntilEmpty(15), "rentré")

-- Un mur entre eux à moins de 4 studs : pas de capture à travers le mur
clearLog()
local kim = addPlayer("Kim", Vector3.new(60, 3, 30))
local wall2 = new("Part", "Wall2", Workspace)
table.insert(WALLS, { cframe = CFrame.new(60, 5, 32.5), size = Vector3.new(30, 10, 0.5), part = wall2 })
PATH_FAILS = true -- le chemin ne passe pas : il pousse droit contre le mur
CarryService.StartCarry(kim, payload("STORE_Z1_Superette", 1))
runFor(3)
local g10 = guardOf(kim)
local d10 = g10 and (g10:FindFirstChild("HumanoidRootPart").Position - rootOf(kim).Position).Magnitude
check(CarryService.IsCarrying(kim), `pas de capture à travers un mur (distance {d10 and string.format("%.1f", d10)})`)
table.clear(WALLS)
PATH_FAILS = false
CarryService.Consume(kim)
check(runUntilEmpty(10), "rentré")

---------------------------------------------------------------- S10 cas limites
print("\nS10 : départ du joueur, colis d'un autre type, magasin inconnu, vitesse du tuto")
clearLog()
local leo = addPlayer("Leo", superette.street)
CarryService.StartCarry(leo, payload("STORE_Z1_Superette", 1))
runFor(0.8)
Players.PlayerRemoving:Fire(leo)
leo.Parent = nil
runFor(DT)
check(logHas("abandonne Leo (départ du joueur)", "PRINT"), "départ du joueur : abandon")
check(runUntilEmpty(10), "rentré")

clearLog()
local mia = addPlayer("Mia", superette.street)
CarryService.StartCarry(mia, { Kind = "StolenItem", StoreId = "STORE_Z1_Superette", Zone = 1 })
runFor(0.2)
check(#guards() == 0, "objet volé à un joueur : pas de vigile")
CarryService.Consume(mia)
CarryService.StartCarry(mia, payload("STORE_Inconnu", 1))
runFor(0.2)
check(#guards() == 0 and logHas("magasin « STORE_Inconnu »", "WARN"), "magasin inconnu : pas de vigile, avertissement")
CarryService.Consume(mia)
CarryService.StartCarry(mia, { Kind = "NPCBox", StoreId = "STORE_Z2_Confiserie" })
runFor(DT)
local g11 = guardOf(mia)
runFor(0.6)
check(g11 and g11:FindFirstChildOfClass("Humanoid").WalkSpeed == 18.8, "zone absente du colis : celle du magasin (zone 2, 18,8)")
CarryService.Consume(mia)
check(runUntilEmpty(10), "rentré")

GuardService.GetSpeedOverride = function(_player, _zone)
	return 12
end
CarryService.StartCarry(mia, payload("STORE_Z1_Superette", 1))
runFor(0.6)
local g12 = guardOf(mia)
check(g12 and g12:FindFirstChildOfClass("Humanoid").WalkSpeed == 12, "GetSpeedOverride : vigile lent du tuto (12)")
CarryService.Consume(mia)
check(runUntilEmpty(10), "rentré")
GuardService.GetSpeedOverride = function()
	return "vite"
end
clearLog()
CarryService.StartCarry(mia, payload("STORE_Z1_Superette", 1))
runFor(0.6)
local g13 = guardOf(mia)
check(g13 and g13:FindFirstChildOfClass("Humanoid").WalkSpeed == 13.4 and logHas("invalide", "WARN"), "GetSpeedOverride invalide : vitesse de la zone")
CarryService.Consume(mia)
check(runUntilEmpty(10), "rentré")
GuardService.GetSpeedOverride = function()
	return nil
end

-- Vigile tué (tombé du monde) : nettoyé, ChaseState(false)
clearLog()
CarryService.StartCarry(mia, payload("STORE_Z1_Superette", 1))
runFor(0.3)
local g14 = guardOf(mia)
g14:FindFirstChild("HumanoidRootPart"):Destroy()
runFor(DT)
check(#guards() == 0 and logHas("parti (sorti du jeu)", "PRINT"), "vigile sans HumanoidRootPart : retiré")
local cs14 = lastRemote("ChaseState", mia)
check(cs14 and cs14.args[1] == false, "ChaseState(false) au joueur")
CarryService.Consume(mia)

---------------------------------------------------------------- S11 client sans le vigile
print("\nS11 : ChaseState arrive sans le vigile (streaming) : le client le retrouve")
clearLog()
local before = #REMOTE_LOG
CarryService.StartCarry(alice, payload("STORE_Z1_Kiosque", 1))
runFor(DT)
local g15 = guardOf(alice)
local remote = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("ChaseState")
remote.OnClientEvent:Fire(true, nil)
runFor(0.2)
check(ChaseController.GetGuard() == g15, "retrouvé par l'attribut TargetUserId")
check(ChaseController.GetDistance() ~= nil, "distance calculée")
CarryService.Consume(alice)
runFor(DT)
check(ChaseController.IsChased() == false, "fin de poursuite côté client")
check(runUntilEmpty(10), "rentré")

summary()
