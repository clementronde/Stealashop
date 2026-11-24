--!nocheck
-- Scénarios a45 (L-077, point 1) : retour du vigile de jour au magasin. RETURN_END (run.sh) :
-- "Reserve" (V0, b), "Door" (a) ou "Bogus" (valeur fausse : comme "Reserve", avec un avertissement).
--
-- Le magasin du banc, vu de dessus (X vers la droite, Z vers le fond ; la rue est en Z < 0) :
--   murs de 0 à 10 studs de haut ; façade en Z = 0 avec l'ouverture de la vitrine (X de −5 à 5) et
--   la porte `Door` (pleine, X de 8 à 11) ; côtés en X = ±15 ; fond en Z = 30 ; un rayon (étagère)
--   de X = −15 à 5 en Z = 15 ; GuardSpawn en (−10, 25), derrière l'étagère ; Bounds = l'intérieur.
--   Dans la rue, un kiosque (mur W1) de X = −25 à 25 en Z = −20 : depuis P = (0, −40), il faut le
--   contourner (|X| ≥ 25) pour rejoindre la vitrine ou la porte. Vitre intacte, rideau baissé : des
--   murs de plus dans l'ouverture. Un second magasin sans murs ni Door ni Bounds en X = 300.
--   R1 b) retour par un chemin, passage ouvert : autour du kiosque, par la vitrine, jusqu'au
--      GuardSpawn ; jamais contre un mur ; Tired puis Walk à 10 ; fondu au GuardSpawn
--   R2 b) rideau baissé, puis vitrine reconstruite : arrêt devant la porte, fondu avec un dernier pas
--   R3 réouverture pendant le retour : nouveaux vigiles tout de suite, l'ancien continue (pas de
--      doublon, MaxPerStore) ; vitrine reconstruite pendant le retour vers la réserve : la porte
--   R4 échec du chemin : il attend sur place (jamais contre un mur), puis s'efface ; nouvel essai
--   R5 rideau (règle de StoreHeistService, L-064, rejouée ici) : capture dedans, il va au
--      GuardSpawn et libère le rideau ; bloqué dedans, il s'efface et le libère ; dehors, le rideau
--      tombe tout de suite et il va à la porte
--   R6 fondu : fin du portage pendant le délai de réaction ; plafond du serveur (place libérée en fondu)
--   D1 a) la porte : autour du kiosque, jamais dans le magasin ; D3 magasin sans Door : la vitrine
--   N1 vigiles de nuit : retour à la ronde, jamais de fondu ; retirés d'un coup à l'aube (inchangé)

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

-- Avant la fusion d'a45 (arbre sans Balance.Guard.ReturnFadeTime) : rien à tester, banc sauté.
if string.find(SOURCES["shared/Config/Balance.luau"] or "", "ReturnFadeTime", 1, true) == nil then
	print(`\na45 SAUTÉ ({RETURN_END}) : cet arbre n'a pas encore le retour du vigile de L-077`)
	summary()
	return
end

-- Le mode du retour : la source de Balance est changée avant son chargement.
do
	local key = "shared/Config/Balance.luau"
	local source = SOURCES[key]
	check(string.find(source, 'ReturnEnd = "Reserve"', 1, true) ~= nil, 'Balance.Guard.ReturnEnd vaut "Reserve" (V0) dans le dépôt')
	if RETURN_END ~= "Reserve" then
		local patched, n = string.gsub(source, 'ReturnEnd = "Reserve"', `ReturnEnd = "{RETURN_END}"`)
		assert(n == 1, "ReturnEnd introuvable dans Balance")
		SOURCES[key] = patched
	end
end
print(`\n=== Balance.Guard.ReturnEnd = "{RETURN_END}" ===`)
local DOOR_MODE = RETURN_END == "Door"

---------------------------------------------------------------- arbre
-- Tous les modules de Shared présents dans SOURCES, à leur place.
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
moduleScript(Services, "StatsService", "stub/StatsService.luau")
local GuardModule = moduleScript(Services, "GuardService", "server/Services/GuardService.luau")

local function new(class, name, parent)
	local inst = InstanceAPI.new(class)
	inst.Name = name
	if parent then
		inst.Parent = parent
	end
	return inst
end

RIG_FACTORY = function()
	local m = new("Model", "Player")
	local root = new("Part", "HumanoidRootPart", m)
	root.Size = Vector3.new(2, 2, 1)
	local hum = new("Humanoid", "Humanoid", m)
	hum.HipHeight = 2
	m.PrimaryPart = root
	return m
end

---------------------------------------------------------------- murs
local GROUND = 0.2
local function wallEntry(name, x0, z0, x1, z1)
	local part = new("Part", name, nil)
	part.Size = Vector3.new(x1 - x0, 10, z1 - z0)
	part.CFrame = CFrame.new((x0 + x1) / 2, 5, (z0 + z1) / 2)
	return { cframe = part.CFrame, size = part.Size, part = part, name = name }
end
local STATIC = {
	wallEntry("FrontL", -15, -0.3, -5, 0.3),
	wallEntry("FrontR", 5, -0.3, 15, 0.3),
	wallEntry("SideL", -15.3, 0, -14.7, 30),
	wallEntry("SideR", 14.7, 0, 15.3, 30),
	wallEntry("Back", -15, 29.7, 15, 30.3),
	wallEntry("Shelf", -15, 14.5, 5, 15.5),
	wallEntry("Kiosk", -25, -20.5, 25, -19.5),
}
local WINDOW_WALL = wallEntry("WindowIntact", -5, -0.2, 5, 0.2)
local SHUTTER_WALL = wallEntry("ShutterDown", -5.5, -0.8, 5.5, -0.4)
local windowIntact, shutterDown = false, false
local function rebuildWalls()
	table.clear(WALLS)
	for _, w in STATIC do
		table.insert(WALLS, w)
	end
	if windowIntact then
		table.insert(WALLS, WINDOW_WALL)
	end
	if shutterDown then
		table.insert(WALLS, SHUTTER_WALL)
	end
end
local function setWindow(intact)
	windowIntact = intact
	rebuildWalls()
end
local function setShutter(down)
	shutterDown = down
	rebuildWalls()
end
rebuildWalls()

NAV_NODES = {
	Vector3.new(-30, GROUND, -30), Vector3.new(-30, GROUND, -10), Vector3.new(30, GROUND, -30), Vector3.new(30, GROUND, -10),
	Vector3.new(0, GROUND, -6), Vector3.new(9.5, GROUND, -7), Vector3.new(0, GROUND, 4), Vector3.new(10, GROUND, 8),
	Vector3.new(10, GROUND, 22), Vector3.new(-5, GROUND, 22),
	Vector3.new(300, GROUND, -6), Vector3.new(300, GROUND, 10),
}

---------------------------------------------------------------- magasins
local SPAWN = Vector3.new(-10, GROUND, 25)
local function makeStore(name, x, withDoor, withBounds)
	local m = new("Model", name)
	m:SetAttribute("Zone", 1)
	local floor = new("Part", "Floor", m)
	floor.Size = Vector3.new(30, 1, 30)
	floor.CFrame = CFrame.new(x, GROUND - 0.5, 15)
	floor.Anchored = true
	local spawnPos = Vector3.new(SPAWN.X + x, GROUND, SPAWN.Z)
	local a = new("Attachment", "GuardSpawn", floor)
	a.CFrame = floor.CFrame:ToObjectSpace(CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, -1)))
	local window = new("Part", "Window", m)
	window.Size = Vector3.new(10, 7, 0.4)
	window.CFrame = CFrame.new(x, 3.5, 0)
	window:SetAttribute("WindowId", name)
	if withDoor then
		local door = new("Model", "Door", m)
		local glass = new("Part", "DoorGlass", door)
		glass.Size = Vector3.new(3, 7, 0.6)
		glass.CFrame = CFrame.new(x + 9.5, 3.5, 0)
	end
	if withBounds then
		local bounds = new("Part", "Bounds", m)
		bounds.Size = Vector3.new(30, 10, 30)
		bounds.CFrame = CFrame.new(x, 5, 15)
		bounds.CanCollide = false
	end
	m.WorldPivot = CFrame.new(x, 0, 15)
	m.Parent = Workspace
	addTag(m, "NPCStore")
	return m
end
local STORE = makeStore("STORE_Z1_Test", 0, true, true)
local FAR = makeStore("STORE_Z1_Far", 300, false, false)
local FAR_SPAWN = Vector3.new(290, GROUND, 25)
local P = Vector3.new(0, 0, -40) -- derrière le kiosque
local DOOR_SPOT = Vector3.new(9.5, GROUND, -4) -- 2 + rayon d'agent (2) devant la porte
local DOOR_STEP = Vector3.new(9.5, GROUND, -2)

local function inBounds(p)
	return math.abs(p.X) <= 15 and p.Z >= 0 and p.Z <= 30
end

---------------------------------------------------------------- vigile de Clément (look commun)
local Assets = folder(ReplicatedStorage, "Assets")
local GuardsF = folder(Assets, "Guards")
do
	local m = new("Model", "Guard")
	local base = Vector3.new(1000, 0, 0)
	local function gpart(name, center, size)
		local p = new("Part", name, m)
		p.Size = size
		p.CFrame = CFrame.new(base + center)
		return p
	end
	local root = gpart("HumanoidRootPart", Vector3.new(0, 3.19, 0), Vector3.new(2, 2, 1))
	root.Transparency = 1
	gpart("LowerTorso", Vector3.new(0, 2.7, 0), Vector3.new(2, 0.8, 1))
	gpart("UpperTorso", Vector3.new(0, 3.8, 0), Vector3.new(2, 1.6, 1))
	local head = gpart("Head", Vector3.new(0, 5.04, 0), Vector3.new(1.2, 1.2, 1.2))
	new("Decal", "face", head)
	gpart("LeftUpperArm", Vector3.new(-1.475, 3.7, 0), Vector3.new(1, 2, 0.9))
	gpart("RightUpperArm", Vector3.new(1.475, 3.7, 0), Vector3.new(1, 2, 0.9))
	local hum = new("Humanoid", "Humanoid", m)
	hum.HipHeight = 2.19
	new("Animator", "Animator", hum)
	local anims = folder(m, "Animations")
	for i, name in { "Idle", "Walk", "Run", "Catch", "Tired" } do
		local a = new("Animation", name, anims)
		a.AnimationId = "rbxassetid://" .. tostring(450 + i)
	end
	m.PrimaryPart = root
	m.Parent = GuardsF
end
TRACK_LENGTH.Tired = 2
TRACK_LENGTH.Catch = 1

---------------------------------------------------------------- joueurs
local nextId = 4500
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
local function removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	if p.Character then
		p.Character:Destroy()
	end
	p.Parent = nil
end
local function payload(storeName)
	return { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_Canette", StoreId = storeName, SlotId = "ShelfSlot_01" }
end

---------------------------------------------------------------- simulation
local DT = 1 / 30
local BODY = 1 -- rayon du corps du vigile pour les collisions du banc (studs)
local function activeFolder()
	return Workspace:FindFirstChild("ActiveGuards")
end
local function guards()
	local f = activeFolder()
	return if f then f:GetChildren() else {}
end
local function dayGuards()
	local out = {}
	for _, g in guards() do
		if string.sub(g.Name, 1, 11) ~= "NightGuard_" then
			table.insert(out, g)
		end
	end
	return out
end
local function guardOf(player)
	for _, g in guards() do
		if g:GetAttribute("TargetUserId") == player.UserId then
			return g
		end
	end
	return nil
end

-- Trace de chaque vigile : pas refusés par un mur (il marchait contre), plus grand |X|, passé dans
-- le magasin, distance parcourue.
local TRACE = {}
local function traceOf(model)
	local t = TRACE[model]
	if t == nil then
		t = { blocked = 0, maxAbsX = 0, inBounds = false, moved = 0, outAfter = false }
		TRACE[model] = t
	end
	return t
end
local function resetTrace(model)
	TRACE[model] = nil
	return traceOf(model)
end
local function hitsWall(pos)
	for _, wall in WALLS do
		local l = wall.cframe:PointToObjectSpace(pos)
		if math.abs(l.X) <= wall.size.X / 2 + BODY and math.abs(l.Z) <= wall.size.Z / 2 + BODY then
			return true
		end
	end
	return false
end
local function stepGuards(dt)
	for _, model in guards() do
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if hum and root then
			local tr = traceOf(model)
			local target = rawget(hum, "_moveTarget")
			if target then
				local pos = root.Position
				local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
				local m = d.Magnitude
				local len = hum.WalkSpeed * dt
				if m > 1e-3 and len > 0 then
					local nextPos = pos + (if m <= len then d else d.Unit * len)
					if hitsWall(nextPos) then
						tr.blocked += 1
					else
						root.CFrame = CFrame.lookAt(nextPos, nextPos + d.Unit)
						tr.moved += (nextPos - pos).Magnitude
					end
				end
			end
			local p = root.Position
			tr.maxAbsX = math.max(tr.maxAbsX, math.abs(p.X))
			tr.inBounds = tr.inBounds or inBounds(p)
		end
	end
end

-- Le rideau du magasin, règle de StoreHeistService (L-064) : en attente, il tombe dès qu'aucun
-- vigile (dossier ActiveGuards) n'est dans Bounds.
local SHUT = { pending = false, loweredAt = nil, heldWhileInside = false }
local function guardInside()
	for _, g in guards() do
		local r = g:FindFirstChild("HumanoidRootPart")
		if r and inBounds(r.Position) then
			return true
		end
	end
	return false
end
local function shutterTick()
	if SHUT.pending then
		if guardInside() then
			SHUT.heldWhileInside = true
		else
			SHUT.pending = false
			SHUT.loweredAt = now()
			setShutter(true)
		end
	end
end

local function runFor(seconds, every)
	local steps = math.floor(seconds / DT + 0.5)
	for _ = 1, steps do
		stepGuards(DT)
		HEARTBEAT:Fire(DT)
		advance(DT)
		shutterTick()
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
local function place(model, pos)
	local root = model:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new(pos.X, root.Position.Y, pos.Z)
end
local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function fullLogHas(pattern, kind)
	for _, line in FULL_LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, pattern, 1, true) then
			return true
		end
	end
	return false
end
local function countFull(pattern)
	local n = 0
	for _, line in FULL_LOG do
		if string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
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
local function f2(x)
	return if x then string.format("%.2f", x) else "?"
end

-- Suit un vigile jusqu'à sa disparition (au plus maxSeconds) : début du fondu (déduit de la
-- transparence du torse, qui part de 0), position à ce moment, transparences à mi-fondu, fin.
local FADE = 0.6
local function watch(model, maxSeconds, every)
	local rec = { values = {} }
	local torso = model:FindFirstChild("UpperTorso")
	local face = model:FindFirstChild("Head"):FindFirstChild("face")
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local t = 0
	while t < maxSeconds do
		runFor(DT, every)
		t += DT
		if model.Parent == nil then
			rec.goneAt = now()
			break
		end
		rec.lastPos = root.Position
		local alpha = torso.Transparency
		if alpha > 0 then
			if rec.fadeAt == nil then
				rec.fadeAt = now() - DT - alpha * FADE -- dernier Heartbeat, moins le fondu déjà fait
				rec.fadePos = root.Position
			end
			table.insert(rec.values, alpha)
			if rec.mid == nil and now() - DT - rec.fadeAt >= FADE / 2 - 1e-6 then
				rec.mid = { torso = alpha, face = face.Transparency, root = root.Transparency }
			end
		elseif rec.fadeAt == nil then
			rec.walkSpeed = hum.WalkSpeed
		end
	end
	rec.lastValue = rec.values[#rec.values]
	return rec
end
local function gradual(rec)
	local n, rising = #rec.values, true
	for i = 2, n do
		rising = rising and rec.values[i] >= rec.values[i - 1]
	end
	return n >= 10 and rising and rec.fadeAt ~= nil and rec.goneAt ~= nil and rec.goneAt - rec.fadeAt >= FADE - 2 * DT
end
local function fadeText(rec)
	return `fondu en {f2(rec.fadeAt and rec.goneAt and rec.goneAt - rec.fadeAt)} s, {#rec.values} paliers`
end

---------------------------------------------------------------- chargement
local Balance = requireModule(Shared.Config.Balance, "server")
local CarryService = requireModule(CarryModule, "server")
local GuardService = requireModule(GuardModule, "server")
GuardService.Start()
runFor(0.5)
check(Balance.Guard.ReturnFadeTime == FADE, `fondu de {Balance.Guard.ReturnFadeTime} s (V0)`)

-- Un vigile pour un voleur posé dans le magasin, lancé (fin du délai de réaction) ; il est ensuite
-- posé en `at` et le voleur en `thiefAt`, loin de lui (rien ne l'attrape).
local function launch(name, at, thiefAt, storeName)
	local startX = if storeName == "STORE_Z1_Far" then 300 else 0
	local thief = addPlayer(name, Vector3.new(startX, 3, 8))
	CarryService.StartCarry(thief, payload(storeName or "STORE_Z1_Test"))
	runFor(0.6)
	local g = guardOf(thief)
	if g and at then
		place(g, at)
	end
	if thiefAt then
		rootOf(thief).CFrame = CFrame.new(thiefAt)
	end
	return thief, g
end

-- R1 et R2 ont la même forme : abandon derrière le kiosque, puis retour.
local function abandonBehindKiosk(name)
	local thief, g = launch(name, P, Vector3.new(0, 3, -70))
	local tr = resetTrace(g)
	local t0 = now()
	local paths0 = PATHS_COMPUTED
	CarryService.Consume(thief)
	return thief, g, tr, t0, paths0
end

if not DOOR_MODE then
	-------------------------------------------------------------- R1
	print("\nR1 : b) passage ouvert : autour du kiosque, par la vitrine, jusqu'au GuardSpawn, puis fondu")
	do
		setWindow(false)
		setShutter(false)
		clearLog()
		local thief, g, tr, t0, paths0 = abandonBehindKiosk("Rita")
		local rec = watch(g, 40)
		check(logHas("abandonne Rita (portage fini", "PRINT"), "abandon (portage fini)")
		local tired = animEvents("Tired", "Play", t0)
		local walk = animEvents("Walk", "Play", t0)
		check(#tired == 1 and #walk >= 1 and walk[1].t >= tired[1].t + 2 - 1e-6, `Tired (2 s), puis Walk ({#tired} Tired, Walk à +{f2(walk[1] and tired[1] and walk[1].t - tired[1].t)} s)`)
		check(rec.walkSpeed == 10, `retour en marchant à 10 ({rec.walkSpeed})`)
		check(logHas("rentre en marchant vers la réserve (GuardSpawn)", "PRINT"), "but : la réserve (GuardSpawn)")
		check(PATHS_COMPUTED > paths0, `chemin calculé ({PATHS_COMPUTED - paths0} calculs) : le kiosque cache la vitrine`)
		check(tr.blocked == 0, `jamais contre un mur ({tr.blocked} pas refusés)`)
		check(tr.maxAbsX >= 25, `il contourne le kiosque, pas en ligne droite à travers (|X| max {f2(tr.maxAbsX)})`)
		check(tr.inBounds, "il entre dans le magasin par la vitrine")
		check(rec.fadePos and flatDist(rec.fadePos, SPAWN) <= 3, `fondu au GuardSpawn ({rec.fadePos and f2(flatDist(rec.fadePos, SPAWN))} studs)`)
		check(gradual(rec), `jamais d'un coup : {fadeText(rec)}`)
		check(rec.mid and rec.mid.torso > 0.3 and rec.mid.torso < 0.7 and math.abs(rec.mid.face - rec.mid.torso) < 1e-6 and rec.mid.root == 1,
			`à mi-fondu : torse {f2(rec.mid and rec.mid.torso)}, visage {f2(rec.mid and rec.mid.face)}, HumanoidRootPart {f2(rec.mid and rec.mid.root)}`)
		check(rec.lastPos and rec.fadePos and flatDist(rec.lastPos, rec.fadePos) < 0.05, "au GuardSpawn, il s'efface sur place")
		check(#animEvents("Walk", "Stop", rec.fadeAt or 0) >= 1, "Walk arrêtée pour le fondu (Idle)")
		check(logHas("s'efface en 0.6 s (rentré)", "PRINT") and logHas("vigile de STORE_Z1_Test parti (rentré)", "PRINT"), "sortie : « s'efface en 0.6 s (rentré) », puis « parti (rentré) »")
		removePlayer(thief)
	end

	-------------------------------------------------------------- R2
	print("\nR2 : b) rideau baissé, puis vitrine reconstruite : arrêt devant la porte, fondu")
	for _, case in { { name = "Sam", shutter = true, window = false, label = "rideau baissé" }, { name = "Tom", shutter = false, window = true, label = "vitrine reconstruite" } } do
		setWindow(case.window)
		setShutter(case.shutter)
		clearLog()
		local goals0 = #PATH_GOALS
		local thief, g, tr = abandonBehindKiosk(case.name)
		local rec = watch(g, 40)
		local triedReserve, triedDoor = false, false
		for i = goals0 + 1, #PATH_GOALS do
			local goal = PATH_GOALS[i].goal
			triedReserve = triedReserve or flatDist(goal, SPAWN) < 0.1
			triedDoor = triedDoor or (flatDist(goal, DOOR_SPOT) < 0.1 and math.abs(goal.Y - GROUND) < 1e-6)
		end
		check(triedReserve and triedDoor, `{case.label} : chemin vers la réserve essayé, puis vers la porte`)
		check(logHas("pas de chemin jusqu'à la réserve (passage fermé), il s'arrête devant la porte", "PRINT"), `{case.label} : « passage fermé » dans la sortie`)
		check(tr.blocked == 0 and not tr.inBounds and tr.maxAbsX >= 25, `{case.label} : jamais contre un mur ni dans le magasin, autour du kiosque ({tr.blocked} refus, |X| max {f2(tr.maxAbsX)})`)
		check(rec.fadePos and flatDist(rec.fadePos, DOOR_SPOT) <= 1.5, `{case.label} : fondu devant la porte ({rec.fadePos and tostring(rec.fadePos)})`)
		check(rec.lastPos and flatDist(rec.lastPos, DOOR_STEP) < 0.6 and rec.lastPos.Z > rec.fadePos.Z, `{case.label} : un dernier pas vers la porte pendant le fondu ({rec.lastPos and tostring(rec.lastPos)})`)
		check(gradual(rec), `{case.label} : {fadeText(rec)}`)
		check(logHas("parti (rentré)", "PRINT"), `{case.label} : parti (rentré)`)
		removePlayer(thief)
	end
	setWindow(false)
	setShutter(false)

	-------------------------------------------------------------- R3
	print("\nR3 : réouverture pendant le retour")
	do
		setShutter(true)
		clearLog()
		local thief, old, tr = abandonBehindKiosk("Uma")
		runFor(3) -- Tired, puis en route vers la porte
		check(logHas("passage fermé", "PRINT") and old.Parent ~= nil, "rideau baissé : il rentre vers la porte")
		-- Réouverture : rideau levé, vitrine cassée, trois voleurs dans le magasin, puis un quatrième.
		setShutter(false)
		local thieves = {}
		for i = 1, 4 do
			local p = addPlayer(`New{i}`, Vector3.new(-6 + 4 * i, 3, 6))
			table.insert(thieves, p)
			CarryService.StartCarry(p, payload("STORE_Z1_Test"))
		end
		runFor(DT)
		local news, distinct = 0, {}
		for i = 1, 3 do
			local g = GuardService.GetGuard(thieves[i])
			if g and g ~= old and not distinct[g] then
				news += 1
				distinct[g] = true
			end
		end
		check(news == 3, `3 nouveaux vigiles tout de suite, un par voleur ({news}) : celui qui rentre ne compte pas dans MaxPerStore`)
		check(GuardService.GetGuard(thieves[4]) == nil and logHas("déjà 3 vigiles en poursuite, pas de vigile pour New4", "PRINT"), "le 4e voleur n'a pas de vigile (MaxPerStore = 3)")
		check(old.Parent ~= nil and old:GetAttribute("TargetUserId") == 0, "l'ancien continue, sans cible : pas de doublon de poursuite")
		local rec = watch(old, 30)
		check(rec.fadePos and flatDist(rec.fadePos, DOOR_SPOT) <= 1.5 and gradual(rec), `l'ancien s'efface en fondu à l'arrivée, devant la porte ({fadeText(rec)})`)
		check(tr.blocked == 0, `l'ancien n'a jamais marché contre un mur ({tr.blocked})`)
		for _, p in thieves do
			if CarryService.IsCarrying(p) then
				CarryService.Consume(p)
			end
		end
		check(runUntilEmpty(30), "les nouveaux rentrent aussi et s'effacent")
		for _, p in thieves do
			removePlayer(p)
		end
		removePlayer(thief)
	end
	do
		setWindow(false)
		setShutter(false)
		clearLog()
		local thief, g, tr = abandonBehindKiosk("Vic")
		runFor(2 + 1) -- Tired, puis 1 s en route vers la réserve (autour du kiosque)
		local r = g:FindFirstChild("HumanoidRootPart")
		check(not logHas("passage fermé", "PRINT") and r.Position.Z < -10, `en route vers la réserve, encore dans la rue ({tostring(r.Position)})`)
		setWindow(true) -- vitrine reconstruite pendant son retour
		local rec = watch(g, 30)
		check(logHas("pas de chemin jusqu'à la réserve (passage fermé)", "PRINT"), "vitrine reconstruite : le chemin ne passe plus, il va à la porte")
		check(rec.fadePos and flatDist(rec.fadePos, DOOR_SPOT) <= 1.5 and gradual(rec), `fondu devant la porte ({fadeText(rec)})`)
		check(tr.blocked == 0 and not tr.inBounds, `jamais contre un mur ni dans le magasin ({tr.blocked})`)
		setWindow(false)
		removePlayer(thief)
	end

	-------------------------------------------------------------- R4
	print("\nR4 : échec du chemin")
	do
		clearLog()
		PATH_FAILS = true
		local thief, g, tr, t0 = abandonBehindKiosk("Wes")
		local rec = watch(g, 30)
		PATH_FAILS = false
		local returnAt = t0 + 2 -- fin de Tired
		check(tr.blocked == 0 and tr.moved < 0.5, `il attend sur place, jamais contre un mur (parcouru {f2(tr.moved)} studs, {tr.blocked} refus)`)
		check(#animEvents("Walk", "Play", t0) == 0, "pas de Walk tant qu'il n'a pas de chemin (Idle)")
		check(logHas("passage fermé", "PRINT"), "réserve sans chemin : il essaie la porte")
		check(rec.fadeAt and rec.fadeAt - returnAt >= 3 - 1e-6 and rec.fadeAt - returnAt <= 3.6, `puis s'efface sur place au bout de 3 s sans chemin (V0) ({f2(rec.fadeAt and rec.fadeAt - returnAt)} s)`)
		check(gradual(rec) and logHas("parti (aucun chemin pour rentrer)", "PRINT"), `en fondu, pas d'un coup ({fadeText(rec)})`)
		removePlayer(thief)
	end
	do
		clearLog()
		PATH_FAILS = true
		local thief, g, tr, t0 = abandonBehindKiosk("Xan")
		runFor(2 + 1) -- Tired, puis 1 s sans chemin
		PATH_FAILS = false -- le calcul suivant réussit
		local rec = watch(g, 30)
		check(rec.fadePos and flatDist(rec.fadePos, DOOR_SPOT) <= 1.5 and not logHas("aucun chemin", "PRINT"), "nouvel essai réussi : il rejoint la porte et s'y efface")
		check(tr.blocked == 0, `jamais contre un mur ({tr.blocked})`)
		removePlayer(thief)
	end
end

-------------------------------------------------------------- R5 (les deux modes)
print("\nR5 : rideau (règle de L-064) : un vigile qui rentre ne le retient pas longtemps et n'est jamais enfermé")
do
	-- Capture dans le magasin, pendant le chrono ; puis fin du chrono : rideau en attente.
	setWindow(false)
	setShutter(false)
	clearLog()
	local thief = addPlayer("Yan", Vector3.new(0, 3, 8))
	CarryService.StartCarry(thief, payload("STORE_Z1_Test"))
	runFor(0.6)
	local g = guardOf(thief)
	place(g, Vector3.new(0, 0, 11))
	local tr = resetTrace(g)
	runFor(DT * 2)
	check(#CarryService.Calls > 0 and CarryService.Calls[#CarryService.Calls].player == thief, "rattrapé dans le magasin")
	SHUT.pending, SHUT.loweredAt, SHUT.heldWhileInside = true, nil, false
	local t0 = now()
	local rec = watch(g, 20)
	runFor(0.2)
	check(logHas("rentre en marchant vers la réserve (GuardSpawn), déjà dans le magasin", "PRINT"), "déjà dans le magasin : il va au GuardSpawn, dans les deux modes")
	check(tr.blocked == 0 and rec.fadePos and flatDist(rec.fadePos, SPAWN) <= 3, `autour du rayon jusqu'au GuardSpawn, jamais contre un mur ({tr.blocked})`)
	check(SHUT.heldWhileInside, "pendant ce temps, il retient le rideau (il n'est pas enfermé)")
	check(SHUT.loweredAt and rec.goneAt and SHUT.loweredAt >= rec.goneAt - 1e-6 and SHUT.loweredAt - rec.goneAt <= DT + 1e-6, `le rideau tombe dès qu'il a disparu ({f2(SHUT.loweredAt and SHUT.loweredAt - t0)} s après la fin du chrono)`)
	check(SHUT.loweredAt and SHUT.loweredAt - t0 < 8, "retenu moins de 8 s")
	removePlayer(thief)
end
do
	-- Bloqué dans le magasin, sans chemin : il s'efface et libère le rideau.
	setShutter(false)
	clearLog()
	local thief = addPlayer("Zoe", Vector3.new(0, 3, 8))
	CarryService.StartCarry(thief, payload("STORE_Z1_Test"))
	runFor(0.6)
	local g = guardOf(thief)
	place(g, Vector3.new(0, 0, 11))
	runFor(DT * 2)
	PATH_FAILS = true
	SHUT.pending, SHUT.loweredAt = true, nil
	local t0 = now()
	local rec = watch(g, 20)
	runFor(0.2)
	PATH_FAILS = false
	check(rec.goneAt and gradual(rec) and logHas("parti (aucun chemin pour rentrer)", "PRINT"), `sans chemin dans le magasin : il s'efface sur place ({fadeText(rec)})`)
	check(SHUT.loweredAt and SHUT.loweredAt - t0 <= 1 + 0.2 + 3 + FADE + 0.3, `le rideau tombe ensuite, retenu {f2(SHUT.loweredAt and SHUT.loweredAt - t0)} s (Catch 1 s + 3 s sans chemin + fondu)`)
	removePlayer(thief)
end
do
	-- Dehors au moment de la fin du chrono : le rideau tombe tout de suite, il ne rentre pas dedans.
	setShutter(false)
	clearLog()
	local thief, g, tr = launch("Abe", P, Vector3.new(0, 3, -70))
	resetTrace(g)
	tr = traceOf(g)
	SHUT.pending, SHUT.loweredAt = true, nil
	local t0 = now()
	runFor(DT)
	check(SHUT.loweredAt ~= nil and SHUT.loweredAt - t0 <= DT + 1e-6, "vigile dehors : le rideau tombe tout de suite")
	CarryService.Consume(thief)
	local rec = watch(g, 40)
	check(rec.fadePos and flatDist(rec.fadePos, DOOR_SPOT) <= 1.5 and not tr.inBounds and tr.blocked == 0, `il rentre devant la porte, jamais enfermé ni contre un mur ({rec.fadePos and tostring(rec.fadePos)})`)
	setShutter(false)
	removePlayer(thief)
end

-------------------------------------------------------------- R6 (les deux modes)
print("\nR6 : jamais de disparition d'un coup")
do
	clearLog()
	local thief = addPlayer("Bea", Vector3.new(0, 3, 8))
	CarryService.StartCarry(thief, payload("STORE_Z1_Test"))
	runFor(0.2)
	local g = guardOf(thief)
	CarryService.Consume(thief) -- pendant le délai de réaction : il n'a pas bougé
	runFor(0.25)
	check(g and g.Parent ~= nil and g.UpperTorso.Transparency > 0 and g.UpperTorso.Transparency < 1, `fin du portage pendant le délai : encore là à 0,25 s, en fondu ({f2(g and g.UpperTorso.Transparency)})`)
	runFor(0.5)
	check(g and g.Parent == nil and logHas("parti (rentré)", "PRINT"), "parti (rentré) une fois le fondu fini")
	removePlayer(thief)
end
do
	-- Plafond du serveur (9.7) : 3 vigiles par magasin, 2 magasins = 6 ; un abandonne ; un 7e voleur.
	clearLog()
	local list = {}
	for i = 1, 6 do
		local storeName = if i <= 3 then "STORE_Z1_Test" else "STORE_Z1_Far"
		local p = addPlayer(`Cap{i}`, if i <= 3 then Vector3.new(-30, 3, -60) else Vector3.new(330, 3, -60))
		CarryService.StartCarry(p, payload(storeName))
		table.insert(list, p)
	end
	runFor(0.6)
	check(#dayGuards() == 6, `6 vigiles de jour ({#dayGuards()})`)
	local leaving = guardOf(list[1])
	CarryService.Consume(list[1]) -- il abandonne : essoufflé, ne compte plus dans MaxPerStore
	runFor(DT)
	local late = addPlayer("Cap7", Vector3.new(-30, 3, -60))
	CarryService.StartCarry(late, payload("STORE_Z1_Test"))
	runFor(DT)
	check(guardOf(late) ~= nil and logHas("place libérée pour un nouveau vigile", "PRINT"), "au plafond, le vigile essoufflé laisse sa place au 7e")
	check(leaving.Parent ~= nil and leaving.UpperTorso.Transparency >= 0 and #dayGuards() == 7, `il s'efface en fondu, encore là ({#dayGuards()} modèles)`)
	runFor(0.7)
	check(leaving.Parent == nil and #dayGuards() == 6, `puis parti : 6 vigiles en jeu ({#dayGuards()})`)
	for _, p in list do
		if CarryService.IsCarrying(p) then
			CarryService.Consume(p)
		end
	end
	CarryService.Consume(late)
	check(runUntilEmpty(40), "tous rentrés, en fondu")
	for _, p in list do
		removePlayer(p)
	end
	removePlayer(late)
end

if DOOR_MODE then
	-------------------------------------------------------------- D1
	print("\nD1 : a) la porte du magasin, même vitrine cassée")
	do
		setWindow(false)
		setShutter(false)
		clearLog()
		local thief, g, tr, t0 = abandonBehindKiosk("Cid")
		local rec = watch(g, 40)
		check(logHas("rentre en marchant vers la porte du magasin", "PRINT"), "but : la porte du magasin")
		check(#animEvents("Tired", "Play", t0) == 1 and #animEvents("Walk", "Play", t0) >= 1, "Tired, puis Walk")
		check(tr.blocked == 0 and not tr.inBounds and tr.maxAbsX >= 25, `autour du kiosque, jamais contre un mur ni dans le magasin ({tr.blocked} refus, |X| max {f2(tr.maxAbsX)})`)
		check(rec.fadePos and flatDist(rec.fadePos, DOOR_SPOT) <= 1.5, `fondu devant la porte ({rec.fadePos and tostring(rec.fadePos)})`)
		check(rec.lastPos and flatDist(rec.lastPos, DOOR_STEP) < 0.6, `dernier pas vers la porte ({rec.lastPos and tostring(rec.lastPos)})`)
		check(gradual(rec) and logHas("parti (rentré)", "PRINT"), `{fadeText(rec)}, parti (rentré)`)
		removePlayer(thief)
	end
	-------------------------------------------------------------- D3
	print("\nD3 : magasin sans Door : devant la vitrine")
	do
		clearLog()
		local thief, g = launch("Dee", Vector3.new(330, 0, -30), Vector3.new(330, 3, -90), "STORE_Z1_Far")
		CarryService.Consume(thief)
		local rec = watch(g, 40)
		local spot = Vector3.new(300, GROUND, -4)
		check(rec.fadePos and flatDist(rec.fadePos, spot) <= 1.5, `fondu devant la vitrine ({rec.fadePos and tostring(rec.fadePos)})`)
		removePlayer(thief)
	end
	-------------------------------------------------------------- D4
	print("\nD4 : a) chemin raté vers la porte : il attend, puis s'efface")
	do
		clearLog()
		PATH_FAILS = true
		local thief, g, tr, t0 = abandonBehindKiosk("Eli")
		local rec = watch(g, 30)
		PATH_FAILS = false
		check(tr.blocked == 0 and tr.moved < 0.5, `sur place, jamais contre un mur ({f2(tr.moved)} studs)`)
		check(rec.fadeAt and rec.fadeAt - (t0 + 2) >= 3 - 1e-6 and rec.fadeAt - (t0 + 2) <= 3.4 and gradual(rec), `s'efface au bout de 3 s ({f2(rec.fadeAt and rec.fadeAt - t0 - 2)} s)`)
		removePlayer(thief)
	end
end

if RETURN_END == "Bogus" then
	check(countFull('Balance.Guard.ReturnEnd = Bogus : "Reserve" ou "Door" attendu, "Reserve" utilisé') == 1, "valeur fausse : un seul avertissement, et la réserve (R1 à R4 joués comme en b)")
end

-------------------------------------------------------------- N1 (une fois)
if RETURN_END == "Reserve" then
	print("\nN1 : vigiles de nuit inchangés : retour à la ronde, jamais de fondu")
	do
		for k, x in { 100, 160 } do
			local p = new("Part", `NightPatrol_Z1_{k}`, Workspace)
			p.Size = Vector3.new(3, 0.1, 3)
			p.CFrame = CFrame.new(x, GROUND, -50)
			p:SetAttribute("Zone", 1)
			addTag(p, "NightPatrol")
		end
		local hooks = {
			InCorridor = function(position)
				return position.X > 80
			end,
			Ignores = function()
				return false
			end,
			SendHome = function()
				return true
			end,
		}
		clearLog()
		GuardService.StartNightPatrol(hooks)
		runFor(DT * 2)
		local nights = {}
		for _, g in guards() do
			if string.sub(g.Name, 1, 11) == "NightGuard_" then
				table.insert(nights, g)
			end
		end
		check(#nights == 2, `2 vigiles de nuit en zone 1 ({#nights})`)
		local nora = addPlayer("Nora", Vector3.new(130, 3, -50))
		runFor(0.3)
		local chaser = guardOf(nora)
		check(chaser ~= nil and string.sub(chaser.Name, 1, 11) == "NightGuard_", "Nora repérée par un vigile de nuit")
		runFor(0.5)
		rootOf(nora).CFrame = CFrame.new(60, 3, -50) -- hors du couloir
		runFor(DT * 2)
		check(chaser and logHas(`{chaser.Name} : abandonne Nora (sorti du couloir)`, "PRINT"), "elle sort du couloir : il lâche")
		runFor(8)
		check(chaser and chaser.Parent ~= nil and chaser.UpperTorso.Transparency == 0, "8 s plus tard, toujours là, opaque (il a repris sa ronde)")
		local nightFades = 0
		for _, line in FULL_LOG do
			if string.find(line.text, "vigile de nuit", 1, true) and string.find(line.text, "s'efface", 1, true) then
				nightFades += 1
			end
		end
		check(nightFades == 0, "aucun fondu pour les vigiles de nuit")
		local removed = GuardService.StopNightPatrol()
		check(removed == 2 and #guards() == 0 and logHas("parti (aube)", "PRINT"), "à l'aube : retirés tout de suite, comme avant")
		removePlayer(nora)
	end
end

check(not fullLogHas("parti (erreur)", nil), "aucun vigile parti en erreur")
summary()
