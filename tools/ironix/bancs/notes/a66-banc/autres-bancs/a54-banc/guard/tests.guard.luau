--!nocheck
-- Scénarios a54-guard (L-083 point 3) : GuardService.StartDriverChase, la poursuite d'un conducteur du
-- camion avec le vrai GuardService. Rue sans murs (ligne droite), zone safe en X < −100.
--   G1 lancement : copie du modèle de Clément dans ActiveGuards, cible, ChaseState, Idle ; un seul par cible
--   G2 vitesse : WalkSpeed de la cible × 1,2 (plancher 20), relue en route ; Run joué
--   G3 capture : colis perdu (Fail « Caught »), Catch, coup au marqueur Impact, étourdi, message, fondu sans Tired
--   G4 zone safe : abandon, fondu, pas de capture
--   G5 la cible ne porte plus le colis du camion (Keeps faux) : abandon
--   G6 jamais d'abandon pour l'avance prise ; abandon après GiveUpAfter s
--   G7 départ du joueur : abandon ; G8 modèle sans HumanoidRootPart : nil, avertissement
--   G9 les vigiles de jour ne sont pas touchés (IsChased, plafond du serveur)

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

-- Avant la fusion d'a54 (GuardService sans StartDriverChase) : rien à tester, banc sauté.
if string.find(SOURCES["server/Services/GuardService.luau"] or "", "StartDriverChase", 1, true) == nil then
	print("\na54-guard SAUTÉ : cet arbre n'a pas encore la poursuite des conducteurs (L-083 point 3)")
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
-- Suit le conducteur jusqu'à sa disparition (au plus maxSeconds) : début du fondu (torse qui pâlit).
local function watchFade(model, maxSeconds, every)
	local torso = model:FindFirstChild("UpperTorso")
	local rec = {}
	local t = 0
	while t < maxSeconds do
		runFor(DT, every)
		t += DT
		if model.Parent == nil then
			rec.goneAt = now()
			break
		end
		if torso.Transparency > 0 and rec.fadeAt == nil then
			rec.fadeAt = now()
		end
	end
	return rec
end

---------------------------------------------------------------- G1 lancement
print("\n--- G1 lancement")
local alice = addPlayer("Alice", Vector3.new(60, 3, 0))
CarryService.StartCarry(alice, truckBox(1))
runFor(0.2)
check(#guards() == 0, "G1a colis du camion porté : aucun vigile de jour")
local t0 = now()
local model = GuardService.StartDriverChase(chaseOf(alice, 1))
check(model ~= nil and model.Parent == activeFolder(), "G1b une copie du conducteur dans Workspace/ActiveGuards")
check(model and model ~= DRIVER and model.Name == "TruckDriver_01_T1" and model:GetAttribute("TargetUserId") == alice.UserId, "G1c nommée comme demandé, attribut TargetUserId = Alice")
check(DRIVER.Parent == TruckAsset and DRIVER.UpperTorso.Anchored == true, "G1d le modèle de Clément n'est pas touché (toujours dans le camion, ancré)")
check(model and model.UpperTorso.Anchored == false and model.HumanoidRootPart.Anchored == false, "G1e la copie est désancrée (le Humanoid la déplace)")
local root = model and model:FindFirstChild("HumanoidRootPart")
check(root and near(root.Position.X, 0, 0.01) and near(root.Position.Y, GROUND + 2.19 + 1, 0.01), "G1f pieds sur le point d'apparition")
check(root and root.CFrame.LookVector.X > 0.99, "G1g tourné vers sa cible")
local states = chaseStates(alice)
check(#states == 1 and states[1].args[1] == true and states[1].args[2] == model, "G1h ChaseState(true, conducteur) au joueur poursuivi (UI_Chase, MUS_Chase)")
check(#animEvents("Idle", "Play", t0) == 1, "G1i Idle jouée")
check(GuardService.StartDriverChase(chaseOf(alice, 1, { Name = "Second" })) == nil and #guards() == 1, "G1j un seul conducteur par porteur")
check(GuardService.IsChased(alice) == false, "G1k IsChased (vigile de jour) reste faux")

---------------------------------------------------------------- G2 vitesse
print("\n--- G2 vitesse")
local hum = model:FindFirstChildOfClass("Humanoid")
check(hum.WalkSpeed == 0, "G2a immobile pendant le délai de réaction")
runFor(0.6)
check(near(hum.WalkSpeed, 20, 1e-6), `G2b porteur à 16 : 16 × 1,2 = 19,2, plancher 20 ({hum.WalkSpeed})`)
check(#animEvents("Run", "Play", t0) >= 1, "G2c Run jouée en poursuite")
humOf(alice).WalkSpeed = 40
runFor(0.2)
check(near(hum.WalkSpeed, 48, 1e-6), `G2d porteur passé à 40 : 48 ({hum.WalkSpeed})`)
humOf(alice).WalkSpeed = 30
runFor(0.2)
check(near(hum.WalkSpeed, 36, 1e-6), `G2e porteur à 30 : 36 ({hum.WalkSpeed})`)

---------------------------------------------------------------- G3 capture
print("\n--- G3 capture en fuite")
RUNNERS[alice] = Vector3.new(1, 0, 0)
local caughtAt, knockAt
local tCatch = now()
local rec = watchFade(model, 30, function()
	if caughtAt == nil and #CarryService.Calls > 0 then
		caughtAt = now()
	end
	if knockAt == nil and rootOf(alice):FindFirstChild("GuardKnockback") then
		knockAt = now()
	end
end)
RUNNERS[alice] = nil
runFor(3) -- fin de l'étourdissement (2,4 s après le coup)
local call = CarryService.Calls[1]
check(call and call.player == alice and call.result == "Failed" and call.reason == "Caught", "G3a rattrapée en fuite (60 studs d'avance, 30 contre 36) : CarryService.Fail(« Caught »), le colis est perdu")
check(caughtAt and caughtAt - tCatch < 12, `G3b en moins de 12 s ({caughtAt and string.format("%.1f", caughtAt - tCatch)} s)`)
check(#animEvents("Catch", "Play", tCatch) == 1, "G3c Catch jouée")
check(knockAt and caughtAt and knockAt - caughtAt >= 0.35 and knockAt - caughtAt <= 0.5, `G3d poussée au marqueur Impact de Catch (0,4 s après : {knockAt and caughtAt and string.format("%.2f", knockAt - caughtAt)})`)
local stunLog = {}
for _, e in Stats.Log do
	if e.player == alice and e.key == "GuardStun" then
		table.insert(stunLog, e)
	end
end
check(#stunLog >= 2 and stunLog[1].mult == 0 and stunLog[#stunLog].mult == nil, "G3e immobilisée puis relâchée (GuardStun)")
check(stunLog[#stunLog] and knockAt and near(stunLog[#stunLog].t - knockAt, Balance.Guard.CatchStunDuration, 0.1), `G3f étourdie CatchStunDuration s ({Balance.Guard.CatchStunDuration}) après le coup`)
check(notified(alice, CAUGHT), "G3g Notify « Caught by a truck driver! The box is lost. »")
states = chaseStates(alice)
check(#states == 2 and states[2].args[1] == false, "G3h ChaseState(false) à la capture")
check(#animEvents("Tired", "Play", tCatch) == 0 and not fullLogHas("Tired", "WARN"), "G3i jamais Tired (pas à son contrat), aucun avertissement")
check(rec.fadeAt and rec.goneAt and rec.goneAt - rec.fadeAt >= Balance.Guard.ReturnFadeTime - 2 * DT, "G3j après Catch, il s'efface en fondu sur place, puis disparaît")
check(rec.fadeAt and caughtAt and rec.fadeAt - caughtAt >= TRACK_LENGTH.Catch - 2 * DT, "G3k le fondu attend la fin de Catch")

---------------------------------------------------------------- G4 zone safe
print("\n--- G4 zone safe")
local bob = addPlayer("Bob", Vector3.new(-80, 3, 0))
CarryService.StartCarry(bob, truckBox(2))
local function caughtCount()
	local n = 0
	for _, c in CarryService.Calls do
		if c.reason == "Caught" then
			n += 1
		end
	end
	return n
end
local calls = caughtCount()
local m2 = GuardService.StartDriverChase(chaseOf(bob, 2, { Spawn = CFrame.new(-40, GROUND, 0) }))
RUNNERS[bob] = Vector3.new(-1, 0, 0)
rec = watchFade(m2, 15)
RUNNERS[bob] = nil
check(rootOf(bob).Position.X < -100, "G4a Bob est entré en zone safe")
check(caughtCount() == calls, "G4b pas de capture, colis gardé")
check(rec.goneAt ~= nil and rec.fadeAt ~= nil, "G4c le conducteur abandonne et s'efface")
check(fullLogHas("zone safe", "PRINT"), "G4d raison « zone safe » dans la sortie")
check(chaseStates(bob)[#chaseStates(bob)].args[1] == false, "G4e ChaseState(false)")

---------------------------------------------------------------- G5 colis rangé
print("\n--- G5 la cible ne porte plus le colis du camion")
local carol = addPlayer("Carol", Vector3.new(200, 3, 0))
CarryService.StartCarry(carol, truckBox(3))
local m3 = GuardService.StartDriverChase(chaseOf(carol, 3, { Spawn = CFrame.new(150, GROUND, 0) }))
runFor(1)
CarryService.Consume(carol)
rec = watchFade(m3, 5)
check(rec.goneAt ~= nil and fullLogHas("ne porte plus le colis du camion", "PRINT"), "G5a colis rangé (Consume) : abandon, fondu, disparition")
local dave = addPlayer("Dave", Vector3.new(300, 3, 0))
CarryService.StartCarry(dave, truckBox(9))
local m3b = GuardService.StartDriverChase(chaseOf(dave, 4, { Spawn = CFrame.new(250, GROUND, 0) }))
rec = watchFade(m3b, 3)
check(rec.goneAt ~= nil and fullLogHas("plus de colis du camion avant le départ", "PRINT"), "G5b colis d'un autre camion (Keeps faux) : abandon dès le délai de réaction")
CarryService.Fail(dave, "Died")

---------------------------------------------------------------- G6 avance et durée
print("\n--- G6 avance et durée")
local eve = addPlayer("Eve", Vector3.new(800, 3, 0))
CarryService.StartCarry(eve, truckBox(5))
local m4 = GuardService.StartDriverChase(chaseOf(eve, 5, { Spawn = CFrame.new(400, GROUND, 0), GiveUpAfter = 3 }))
runFor(2)
check(m4.Parent ~= nil and m4:GetAttribute("TargetUserId") == eve.UserId, `G6a à {math.floor(flatDist(m4.HumanoidRootPart.Position, rootOf(eve).Position))} studs (> GiveUpLead {Balance.Guard.GiveUpLead}) : il poursuit toujours`)
rec = watchFade(m4, 3)
-- a66 (2026-11-11, poursuite sans fin) : DriverChase sans GiveUpAfter ; avant a66, l'ancien contrôle.
if string.find(SOURCES["server/Services/GuardService.luau"] or "", "GiveUpAfter", 1, true) == nil then
	check(rec.goneAt == nil and m4.Parent ~= nil and m4:GetAttribute("TargetUserId") == eve.UserId and not fullLogHas("s de poursuite", "PRINT"), "G6b a66 : pas d'abandon au bout d'un temps (GiveUpAfter = 3 ignoré), il poursuit toujours")
else
	check(rec.goneAt ~= nil and fullLogHas("3 s de poursuite", "PRINT"), "G6b abandon après GiveUpAfter s (3 ici)")
end
check(caughtCount() == calls, "G6c pas de capture")
CarryService.Fail(eve, "Died")

---------------------------------------------------------------- G7 départ, G8 modèle cassé
print("\n--- G7 départ du joueur, G8 modèle sans HumanoidRootPart")
local fred = addPlayer("Fred", Vector3.new(1000, 3, 0))
CarryService.StartCarry(fred, truckBox(6))
local m5 = GuardService.StartDriverChase(chaseOf(fred, 6, { Spawn = CFrame.new(950, GROUND, 0) }))
runFor(0.7)
Players.PlayerRemoving:Fire(fred)
rec = watchFade(m5, 3)
check(rec.goneAt ~= nil and fullLogHas("départ du joueur", "PRINT"), "G7 départ du joueur : abandon, fondu")
local gina = addPlayer("Gina", Vector3.new(1200, 3, 0))
CarryService.StartCarry(gina, truckBox(7))
local count = #guards()
check(GuardService.StartDriverChase(chaseOf(gina, 7, { Template = NO_ROOT })) == nil and #guards() == count, "G8a modèle sans HumanoidRootPart : nil, rien créé")
check(fullLogHas("conducteur non créé", "WARN"), "G8b un avertissement")
check(NO_ROOT.Parent == TruckAsset, "G8c le modèle n'est pas touché")

---------------------------------------------------------------- G9 vigiles de jour
print("\n--- G9 plafonds des vigiles de jour")
local list = {}
for i = 1, Balance.Guard.MaxActivePerServer + 1 do
	local p = addPlayer(`Runner{i}`, Vector3.new(1500 + i * 50, 3, 0))
	CarryService.StartCarry(p, truckBox(100 + i))
	table.insert(list, GuardService.StartDriverChase(chaseOf(p, 100 + i, { Spawn = CFrame.new(1500 + i * 50 - 40, GROUND, 0) })))
end
local all = true
for _, m in list do
	all = all and m ~= nil
end
check(all, `G9 {#list} conducteurs à la fois : hors du plafond des vigiles de jour ({Balance.Guard.MaxActivePerServer})`)

local others = 0
for _, line in FULL_LOG do
	if line.kind == "WARN" and string.find(string.lower(line.text), "conducteur", 1, true) and not string.find(line.text, "conducteur non créé", 1, true) then
		others += 1
		print("    " .. line.text)
	end
end
check(others == 0, `G10 aucun autre avertissement sur les conducteurs (hors rig de remplacement et sons pas livrés, communs à tous les vigiles) ({others})`)
summary()
