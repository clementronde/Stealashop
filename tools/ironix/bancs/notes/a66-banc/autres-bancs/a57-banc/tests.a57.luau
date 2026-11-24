--!nocheck
-- Scénarios a57 (2026-11-10, vague 21, L-091 point 1) : une poursuite qui réagit tout de suite. Le vrai
-- GuardService, poursuivi par un conducteur du camion (StartDriverChase : même chaseStep que les vigiles
-- de jour et de nuit, sans magasin à monter). Faux Roblox et préambule d'a54-guard. Chemins calculés
-- avec PATH_LATENCY s de retard (0,25 s, comme un vrai ComputeAsync), le joueur envoie sa vitesse au sol
-- (AssemblyLinearVelocity, comme un vrai personnage).
--   R1 joueur qui tourne à angle droit en ligne de vue : le vigile change de direction en moins de 0,2 s
--      (au moins 20° vers la nouvelle direction, V0), premier changement en moins de 0,1 s ; témoin
--      sans vitesse envoyée (l'ancienne poursuite, droit sur la position) : tourne moins ; capture
--   R2 obstacle : le joueur passe derrière un bâtiment ; chemin calculé (au plus un toutes les 0,3 s),
--      jamais de demi-tour sur un point de chemin dépassé, jamais dans le bâtiment ; dès que la vue
--      revient, droit sur le joueur, plus aucun calcul de chemin ; capture
--   R3 coût : rayons et calculs de chemin par seconde de poursuite, bornés

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


-- Avant la fusion d'a57 (GuardService sans aimPoint) : banc sauté, sauf FORCE=1 (montre l'ancienne poursuite).
local SRC_GUARD = SOURCES["server/Services/GuardService.luau"] or ""
-- Copie d'a66 (2026-11-11, Cantin : trajet le plus court, sans anticipation, sans recopier nos zigzags) :
-- aussi lancé sur un arbre avec chaseInSight (a66). R1 y vérifie la nouvelle règle (voir plus bas).
local A66 = string.find(SRC_GUARD, "chaseInSight", 1, true) ~= nil
if string.find(SRC_GUARD, "StartDriverChase", 1, true) == nil
	or (string.find(SRC_GUARD, "aimPoint", 1, true) == nil and not A66 and not A57_FORCE) then
	print("\na57 SAUTÉ : cet arbre n'a pas encore la poursuite qui réagit tout de suite (L-091 point 1)")
	summary()
	return
end

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
do
	local keys = {}
	for key in SOURCES do
		if string.sub(key, 1, 7) == "shared/" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for _, key in keys do
		local parts = string.split(string.sub(key, 8), "/")
		local parent = Shared
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i]) or folder(parent, parts[i])
		end
		moduleScript(parent, string.gsub(parts[#parts], "%.luau$", ""), key)
	end
end
local Services = folder(folder(ServerScriptService, "Server"), "Services")
moduleScript(Services, "AntiCheatService", "stub/AntiCheatService")
local CarryModule = moduleScript(Services, "CarryService", "stub/CarryService.luau")
local StatsModule = moduleScript(Services, "StatsService", "stub/StatsService.luau")
local GuardModule = moduleScript(Services, "GuardService", "server/Services/GuardService.luau")

local function new(class, name, parent)
	local inst = InstanceAPI.new(class)
	inst.Name = name
	if parent then
		inst.Parent = parent
	end
	return inst
end

---------------------------------------------------------------- carte : sol, zone safe en X < −100
local GROUND = 0.2
local safe = new("Part", "SafeVolume", Workspace)
safe.Size = Vector3.new(200, 50, 400)
safe.CFrame = CFrame.new(-200, 10, 0)
safe.CanCollide = false
addTag(safe, "SafeZone")

---------------------------------------------------------------- conducteurs de Clément (dans le camion)
local Assets = folder(ReplicatedStorage, "Assets")
local Events = folder(Assets, "Events")
local TruckAsset = new("Model", "ENV_Event_Truck", Events)
local function makeDriver(name, withRoot)
	local m = new("Model", name)
	local base = Vector3.new(2000, 0, 0)
	local function gpart(pname, center, size)
		local p = new("Part", pname, m)
		p.Size = size
		p.CFrame = CFrame.new(base + center)
		p.Anchored = true -- livré ancré dans la cabine
		return p
	end
	local root = if withRoot then gpart("HumanoidRootPart", Vector3.new(0, 3.19, 0), Vector3.new(2, 2, 1)) else nil
	if root then
		root.Transparency = 1
	end
	gpart("LowerTorso", Vector3.new(0, 2.7, 0), Vector3.new(2, 0.8, 1))
	local torso = gpart("UpperTorso", Vector3.new(0, 3.8, 0), Vector3.new(2, 1.6, 1))
	local head = gpart("Head", Vector3.new(0, 5.04, 0), Vector3.new(1.2, 1.2, 1.2))
	new("Decal", "face", head)
	local hum = new("Humanoid", "Humanoid", m)
	hum.HipHeight = 2.19
	new("Animator", "Animator", hum)
	local anims = folder(m, "Animations")
	for i, aname in { "Idle", "Walk", "Run", "Catch" } do
		local a = new("Animation", aname, anims)
		a.AnimationId = "rbxassetid://" .. tostring(770 + i)
	end
	m.PrimaryPart = root or torso
	m.Parent = TruckAsset
	return m
end
local DRIVER = makeDriver("TruckDriver_01", true)
local NO_ROOT = makeDriver("TruckDriver_Broken", false)
TRACK_LENGTH.Catch = 1.2
MARKER_AT.Catch = { "Impact", 0.4 }

---------------------------------------------------------------- joueurs
local nextId = 5400
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
	return p
end
local function rootOf(p)
	return p.Character:FindFirstChild("HumanoidRootPart")
end
local function humOf(p)
	return p.Character:FindFirstChildOfClass("Humanoid")
end
local function truckBox(n)
	return { Kind = "NPCBox", Tier = "Premium", Zone = 3, Rarity = "Rare", ItemId = "Z1_Canette", StoreId = `Truck_{n}`, SlotId = `Truck_{n}/01` }
end

---------------------------------------------------------------- simulation
local DT = 1 / 30
local function activeFolder()
	return Workspace:FindFirstChild("ActiveGuards")
end
local function guards()
	local f = activeFolder()
	return if f then f:GetChildren() else {}
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
					root.CFrame = CFrame.lookAt(nextPos, nextPos + d.Unit)
				end
			end
		end
	end
end
-- Fuyards : chaque joueur de RUNNERS court tout droit vers +X à sa WalkSpeed (la vraie vitesse du
-- joueur), sauf s'il est immobilisé (StatsService : GuardStun = 0).
local RUNNERS = {}
local Stats
local function stepRunners(dt)
	for player, dir in RUNNERS do
		local mods = Stats.Mods[player]
		local stunned = mods and mods.GuardStun == 0
		local root = player.Character and rootOf(player)
		if root and not stunned then
			local p = root.Position + dir * humOf(player).WalkSpeed * dt
			root.CFrame = CFrame.new(p)
		end
	end
end
local function runFor(seconds, every)
	local steps = math.floor(seconds / DT + 0.5)
	for _ = 1, steps do
		stepGuards(DT)
		stepRunners(DT)
		HEARTBEAT:Fire(DT)
		advance(DT)
		if every then
			every()
		end
	end
end
local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function animEvents(name, action, since)
	local out = {}
	for _, e in ANIM_LOG do
		if e.name == name and e.action == action and e.t >= since then
			table.insert(out, e)
		end
	end
	return out
end
local function chaseStates(player)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == "ChaseState" and e.to == player then
			table.insert(out, e)
		end
	end
	return out
end
local function notified(player, text)
	for _, e in REMOTE_LOG do
		if e.name == "Notify" and e.to == player and e.args[1] == text then
			return true
		end
	end
	return false
end
local function fullLogHas(pattern, kind)
	for _, line in FULL_LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, pattern, 1, true) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- chargement
local Balance = requireModule(Shared.Config.Balance, "server")
local CarryService = requireModule(CarryModule, "server")
Stats = requireModule(StatsModule, "server")
local GuardService = requireModule(GuardModule, "server")
GuardService.Start()
runFor(0.5)

local CAUGHT = "Caught by a truck driver! The box is lost."
local function chaseOf(player, n, overrides)
	local chase = {
		Template = DRIVER,
		Name = `TruckDriver_01_T{n}`,
		Target = player,
		Spawn = CFrame.new(0, GROUND, 0),
		Zone = 3,
		SpeedMultiplier = 1.2,
		MinSpeed = 20,
		GiveUpAfter = 30,
		Keeps = function(p)
			local payload = CarryService.GetPayload(p)
			return payload ~= nil and payload.StoreId == `Truck_{n}`
		end,
		CaughtMessage = CAUGHT,
	}
	for k, v in overrides or {} do
		chase[k] = v
	end
	return chase
end

---------------------------------------------------------------- a57 : outils
-- Un vrai ComputeAsync prend du temps : le vigile avance pendant le calcul.
PATH_LATENCY = 0.25
do
	local baseCreate = PathfindingService.CreatePath
	PathfindingService.CreatePath = function(service, params)
		local path = baseCreate(service, params)
		local compute = path.ComputeAsync
		path.ComputeAsync = function(p, a, b)
			taskLib.wait(PATH_LATENCY)
			return compute(p, a, b)
		end
		return path
	end
end

local RUN = {} -- joueur -> vitesse au sol (studs/s)
local SEND_VELOCITY = true
local function stepRun(dt)
	for player, vel in RUN do
		local root = player.Character and rootOf(player)
		if root then
			local mods = Stats.Mods[player]
			if mods and mods.GuardStun == 0 then
				root.AssemblyLinearVelocity = Vector3.zero
			else
				root.CFrame = CFrame.new(root.Position + vel * dt)
				root.AssemblyLinearVelocity = if SEND_VELOCITY then vel else Vector3.zero
			end
		end
	end
end
local function frame(every)
	stepGuards(DT)
	stepRun(DT)
	HEARTBEAT:Fire(DT)
	advance(DT)
	if every then
		every()
	end
end
local function frames(seconds, every)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		frame(every)
	end
end
local function moveTarget(model)
	return rawget(model:FindFirstChildOfClass("Humanoid"), "_moveTarget")
end
local function heading(model)
	local target = moveTarget(model)
	if target == nil then
		return nil
	end
	local pos = model.HumanoidRootPart.Position
	local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	return if d.Magnitude > 1e-3 then d.Unit else nil
end
local function angleDeg(a, b)
	if a == nil or b == nil then
		return 0
	end
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end
local function caughtAt(player)
	for _, call in CarryService.Calls do
		if call.player == player and call.reason == "Caught" then
			return call.t
		end
	end
	return nil
end
local function sees(model, player)
	local a, b = model.HumanoidRootPart.Position, rootOf(player).Position
	return Workspace:Raycast(a, b - a) == nil
end

---------------------------------------------------------------- R1 virage à angle droit en ligne de vue
print("\n--- R1 virage à angle droit en ligne de vue")
table.clear(WALLS)
local function rightTurn(n, x0, sendVelocity)
	SEND_VELOCITY = sendVelocity
	local p = addPlayer(`Turner{n}`, Vector3.new(x0 + 12, 3, 0))
	humOf(p).WalkSpeed = 16
	CarryService.StartCarry(p, truckBox(n))
	local model = GuardService.StartDriverChase(chaseOf(p, n, { Spawn = CFrame.new(x0, GROUND, 0) }))
	RUN[p] = Vector3.new(16, 0, 0)
	frames(1.6) -- délai de réaction (0,5 s), puis 1,1 s tout droit
	local rec = { before = heading(model), gap = flatDist(model.HumanoidRootPart.Position, rootOf(p).Position) }
	RUN[p] = Vector3.new(0, 0, 16) -- virage à droite
	local turnAt = now()
	local t = 0
	local window = if A66 then 0.35 else 0.2 -- a66 : reprise de la position au plus toutes les 0,25 s (deux reprises au moins)
	while t < window - 1e-6 do
		frame()
		t += DT
		local h = heading(model)
		if rec.first == nil and angleDeg(h, rec.before) > 1 then
			rec.first = now() - turnAt
		end
	end
	rec.after = heading(model)
	rec.angle = angleDeg(rec.after, rec.before)
	rec.aim = moveTarget(model)
	rec.at = rootOf(p).Position
	frames(8)
	rec.caught = caughtAt(p)
	rec.caughtIn = if rec.caught then rec.caught - turnAt else nil
	RUN[p] = nil
	return rec
end
local lead = rightTurn(201, 200, true)
local plain = rightTurn(202, 600, false)
print(string.format("    écart au virage %.1f studs ; anticipation : %.0f° à 0,2 s (1er changement %.3f s), capture %.2f s après ; témoin sans vitesse : %.0f°, capture %s",
	lead.gap, lead.angle, lead.first or -1, lead.caughtIn or -1, plain.angle, if plain.caughtIn then string.format("%.2f s", plain.caughtIn) else "aucune"))
check(lead.before and lead.before.X > 0.99, "R1a tout droit derrière le joueur avant le virage")
if A66 then
	-- a66 : droit sur la position du joueur, reprise au plus toutes les 0,25 s, sans anticipation.
	check(lead.first ~= nil and lead.first <= 0.25 + DT + 1e-6, `R1b a66 : premier changement de direction en 0,25 s au plus ({lead.first})`)
	check(lead.angle >= 10 and lead.after.Z > 0, `R1c a66 : en 0,35 s, il a tourné vers le joueur ({string.format("%.1f", lead.angle)}°)`)
	check(lead.aim ~= nil and flatDist(lead.aim, lead.at) <= 16 * 0.25 + 0.6 and lead.aim.Z <= lead.at.Z + 1e-3,
		"R1d a66 : il vise où est le joueur (jamais devant lui : pas d'anticipation)")
	check(math.abs(lead.angle - plain.angle) < 1, `R1e a66 : la vitesse du joueur ne change rien ({string.format("%.1f", lead.angle)}° contre {string.format("%.1f", plain.angle)}°)`)
	check(lead.caught ~= nil, "R1f le joueur qui a tourné est rattrapé")
else
	check(lead.first ~= nil and lead.first <= 0.1 + 1e-6, `R1b premier changement de direction en moins de 0,1 s ({lead.first})`)
	check(lead.angle >= 20 and lead.after.Z > 0, `R1c en 0,2 s, au moins 20° vers la nouvelle direction ({string.format("%.1f", lead.angle)}°)`)
	check(lead.angle > plain.angle + 5, `R1d plus vif que la poursuite droit sur la position (témoin : {string.format("%.1f", plain.angle)}°)`)
	check(lead.caught ~= nil, "R1e le joueur qui a tourné est rattrapé")
	check(lead.caughtIn and plain.caughtIn and lead.caughtIn <= plain.caughtIn + 1e-6, "R1f rattrapé au moins aussi vite que par le témoin")
end

---------------------------------------------------------------- R2 obstacle : chemin, puis direct dès que la vue revient
print("\n--- R2 obstacle")
SEND_VELOCITY = true
local X0 = 1000
local function wallEntry(name, x0, z0, x1, z1)
	local part = new("Part", name, nil)
	part.Size = Vector3.new(x1 - x0, 10, z1 - z0)
	part.CFrame = CFrame.new((x0 + x1) / 2, 5, (z0 + z1) / 2)
	return { cframe = part.CFrame, size = part.Size, part = part, name = name }
end
-- Bâtiment à droite de la rue (z ≥ 3), de x = 20 à 60 ; le joueur tourne à droite juste après.
local BUILDING = { x0 = X0 + 20, z0 = 3, x1 = X0 + 60, z1 = 40 }
table.clear(WALLS)
table.insert(WALLS, wallEntry("Building", BUILDING.x0, BUILDING.z0, BUILDING.x1, BUILDING.z1))
NAV_NODES = { Vector3.new(X0 + 62, GROUND, 1), Vector3.new(X0 + 62, GROUND, 42), Vector3.new(X0 + 18, GROUND, 1) }
local function insideBuilding(pos)
	return pos.X > BUILDING.x0 and pos.X < BUILDING.x1 and pos.Z > BUILDING.z0 and pos.Z < BUILDING.z1
end
local bob = addPlayer("Bob", Vector3.new(X0 + 40, 3, 0))
humOf(bob).WalkSpeed = 16
CarryService.StartCarry(bob, truckBox(301))
local driver = GuardService.StartDriverChase(chaseOf(bob, 301, { Spawn = CFrame.new(X0, GROUND, 0), SpeedMultiplier = 1.5, MinSpeed = 20 }))
RUN[bob] = Vector3.new(16, 0, 0)
local rec = { hiddenFrames = 0, uTurns = 0, inside = false, pathsHidden = 0, lost = nil, back = nil }
local prevPos, prevStep = nil, nil
local turned = false
local pathsAtLoss, pathsAtBack = nil, nil
local backTarget = nil
local wasSeen = true
local t = 0
while t < 8 and caughtAt(bob) == nil do
	frame()
	t += DT
	local pos = driver.HumanoidRootPart.Position
	local bobPos = rootOf(bob).Position
	if not turned and bobPos.X >= X0 + 64 then
		turned = true
		RUN[bob] = Vector3.new(0, 0, 16)
	end
	if insideBuilding(pos) then
		rec.inside = true
	end
	local seen = sees(driver, bob)
	if not seen then
		rec.hiddenFrames += 1
		if rec.lost == nil then
			rec.lost = now()
			pathsAtLoss = PATHS_COMPUTED
		end
	elseif rec.lost and rec.back == nil then
		rec.back = now()
		pathsAtBack = PATHS_COMPUTED
	end
	-- Sur un chemin : jamais de demi-tour (pas plus de 120° entre deux pas).
	if prevPos then
		local stepVec = Vector3.new(pos.X - prevPos.X, 0, pos.Z - prevPos.Z)
		if stepVec.Magnitude > 1e-3 then
			if prevStep and angleDeg(stepVec.Unit, prevStep) > 120 then
				rec.uTurns += 1
			end
			prevStep = stepVec.Unit
		end
	end
	prevPos = pos
	-- 0,1 s après le retour de la vue : où il va.
	if rec.back and backTarget == nil and now() - rec.back >= 0.1 - 1e-6 then
		backTarget = moveTarget(driver)
		rec.backBob = bobPos
		rec.backPos = pos
		rec.pathsBack01 = PATHS_COMPUTED
	end
	if rec.back and rec.pathsLate == nil and now() - rec.back >= 0.6 - 1e-6 then
		rec.pathsLate = PATHS_COMPUTED
	end
	wasSeen = seen
end
local hiddenTime = if rec.lost and rec.back then rec.back - rec.lost else 0
local pathsHidden = if pathsAtLoss and pathsAtBack then pathsAtBack - pathsAtLoss else 0
print(string.format("    caché %.2f s, %d calcul(s) de chemin pendant ce temps, demi-tours %d, rattrapé : %s",
	hiddenTime, pathsHidden, rec.uTurns, tostring(caughtAt(bob) ~= nil)))
check(turned, "R2a le joueur tourne derrière le bâtiment")
check(rec.lost ~= nil and rec.back ~= nil and hiddenTime > 0.1, `R2b le bâtiment cache le joueur, puis la vue revient ({string.format("%.2f", hiddenTime)} s)`)
check(pathsHidden >= 1 and pathsHidden <= math.ceil(hiddenTime / Balance.Guard.PathRecomputeInterval) + 1,
	`R2c caché : chemin calculé, au plus un toutes les {Balance.Guard.PathRecomputeInterval} s ({pathsHidden})`)
check(rec.uTurns == 0, `R2d aucun demi-tour vers un point de chemin dépassé ({rec.uTurns})`)
check(not rec.inside, "R2e jamais dans le bâtiment")
check(backTarget ~= nil and flatDist(backTarget, rec.backBob) <= 8 + 0.5
	and Workspace:Raycast(rec.backPos, backTarget - rec.backPos) == nil,
	"R2f 0,1 s après le retour de la vue : droit sur le joueur (à 8 studs d'anticipation au plus), en ligne de vue")
check(rec.pathsLate ~= nil and rec.pathsBack01 ~= nil and rec.pathsLate - rec.pathsBack01 <= 0,
	"R2g en vue : plus aucun calcul de chemin")
frames(4)
check(caughtAt(bob) ~= nil, "R2h rattrapé après le bâtiment")
RUN[bob] = nil

---------------------------------------------------------------- R3 coût
print("\n--- R3 coût")
table.clear(WALLS)
local carl = addPlayer("Carl", Vector3.new(3012, 3, 0))
humOf(carl).WalkSpeed = 16
CarryService.StartCarry(carl, truckBox(401))
GuardService.StartDriverChase(chaseOf(carl, 401, { Spawn = CFrame.new(3000, GROUND, 0), MinSpeed = 16, SpeedMultiplier = 0.5 }))
RUN[carl] = Vector3.new(16, 0, 0)
frames(0.6)
local rays0, paths0 = RAYCASTS, PATHS_COMPUTED
frames(2)
local raysPerSecond = (RAYCASTS - rays0) / 2
print(string.format("    un vigile en vue : %.0f rayons/s, %d calcul(s) de chemin", raysPerSecond, PATHS_COMPUTED - paths0))
check(PATHS_COMPUTED - paths0 == 0, "R3a en vue : aucun calcul de chemin")
check(raysPerSecond <= 120, `R3b au plus 120 rayons/s par vigile en vue (6 vigiles : 720/s) ({raysPerSecond})`)
RUN[carl] = nil

summary()
