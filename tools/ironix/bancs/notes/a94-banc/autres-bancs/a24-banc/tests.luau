--!nocheck
-- Scénarios a24 (vague 7) : les vigiles de Clément dans GuardService, construits ici aux mesures
-- du relevé Studio (agents/wave7-studio.md, section 2) : échelle (Model:ScaleTo), boîte
-- accessoires compris, HipHeight, HumanoidRootPart, accessoires ACC_Z<n>_*, WalkSpeed 16 × échelle,
-- dossier Animations vide, aucun script.
--   B1 jour : modèle par zone, agent du PathfindingService à sa taille, HipHeight gardée,
--      accessoires sans collision ni masse, groupe Guards partout, WalkSpeed imposé, modèle intact
--   B2 capture d'un vigile à l'échelle 1,40 (HumanoidRootPart plus haut) : à 4 studs ou moins,
--      jamais de plus loin ; abandon à 120 studs
--   B3 nuit : NightGuard_Z<n> s'il existe, sinon Guard_Z<n>, agent à la taille
--   B4 dossiers Animations vides : rien ne casse, un avertissement par nom au plus
--   B5 rythme de Run et de Walk (animations livrées) : jour, retour, nuit, changements
--   B6 bornes 0,6 et 1,6 ; rig de remplacement
--   B7 AnimPlayer.AdjustSpeed

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

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "Items", "Night", "PvP", "Rarities", "Shatter", "ShelfBoxes", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
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
moduleScript(Services, "AntiCheatService", "stub/AntiCheatService") -- a36 (DEV-060) : GuardService déclare ses poussées (Allow)
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

-- Rig de remplacement rendu par CreateHumanoidModelFromDescriptionAsync (bouchon, comme a12).
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

-- Magasins comme la greybox de a12 : vitrine en X = distance de retour, côté N (Z > 0) ou S.
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
local function makeStore(name, zone, x, side)
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
	m.Parent = Workspace
	addTag(m, "NPCStore")
	return { model = m, frame = frame, spawn = spawnAt.Position, zone = zone, street = (frame * CFrame.new(0, 3.2, -26)).Position }
end
for zone = 1, 6 do
	STORES[zone] = makeStore(NAMES[zone][1], zone, DISTANCE[zone], 1)
	makeStore(NAMES[zone][2], zone, DISTANCE[zone], -1)
end

-- Zone safe : X < 0, comme la greybox.
local safe = new("Model", "SafeZone")
local bounds = new("Part", "Bounds", safe)
bounds.Size = Vector3.new(240, 40, 240)
bounds.CFrame = CFrame.new(-120, 20, 0)
safe.Parent = Workspace
addTag(safe, "SafeZone")

---------------------------------------------------------------- vigiles de Clément (relevé, section 2)
local Assets = folder(ReplicatedStorage, "Assets")
local GuardsF = folder(Assets, "Guards")

-- Échelle, boîte (L × H × P, accessoires compris), HipHeight, accessoires. hat : l'accessoire qui
-- dépasse de la tête (la boîte monte jusqu'à H) ; deep : celui qui donne la profondeur P.
local RELEVE = {
	{ scale = 1.00, box = { 3.95, 5.64, 1.73 }, hip = 2.19, acc = { "Casquette", "Gilet", "Cafe", "Ceinture" }, hat = "Casquette", deep = "Cafe" },
	{ scale = 1.08, box = { 4.26, 7.71, 1.40 }, hip = 2.37, acc = { "Bonnet", "Tunique" }, hat = "Bonnet", deep = "Tunique" },
	{ scale = 1.16, box = { 4.58, 6.53, 2.52 }, hip = 2.54, acc = { "Casquette", "Baudrier", "Baton" }, hat = "Casquette", deep = "Baton" },
	{ scale = 1.24, box = { 4.89, 6.99, 2.22 }, hip = 2.72, acc = { "Casquette", "Lunettes", "Gilet", "Ceinture" }, hat = "Casquette", deep = "Gilet" },
	{ scale = 1.32, box = { 5.21, 7.73, 2.12 }, hip = 2.89, acc = { "Kepi", "Veste", "EpauletteGauche", "EpauletteDroite", "Moustache" }, hat = "Kepi", deep = "Veste" },
	{ scale = 1.40, box = { 5.52, 7.64, 1.72 }, hip = 3.07, acc = { "Chemise", "Lunettes", "Oreillette" }, hat = nil, deep = "Chemise" },
}
-- Agent attendu : rayon = moitié de max(L, P), hauteur = H, au dixième au-dessus, plancher 2 et 5.
local AGENT = { { 2, 5.7 }, { 2.2, 7.8 }, { 2.3, 6.6 }, { 2.5, 7 }, { 2.7, 7.8 }, { 2.8, 7.7 } }

local function gpart(name, parent, center, size)
	local p = new("Part", name, parent)
	p.Size = size
	p.CFrame = CFrame.new(center)
	return p
end

-- Un R15 simplifié aux mesures du relevé, pieds en `base` : HumanoidRootPart (PrimaryPart),
-- torse, tête, bras (ils donnent la largeur L), pieds (profondeur du corps 1,2 × échelle) ;
-- accessoires Accessory + Handle, collisions et masse laissées par défaut ; Humanoid avec
-- Animator ; dossier Animations vide ; échelle posée comme par Model:ScaleTo.
local function buildGuard(name, spec, base, accPrefix)
	local s = spec.scale
	local L, H, P = spec.box[1], spec.box[2], spec.box[3]
	local body = if spec.hat then 5.46 * s else H -- haut de la tête
	local m = new("Model", name)
	local root = gpart("HumanoidRootPart", m, base + Vector3.new(0, spec.hip + s, 0), Vector3.new(2 * s, 2 * s, s))
	gpart("LowerTorso", m, base + Vector3.new(0, spec.hip + 0.5 * s, 0), Vector3.new(2 * s, 0.8 * s, s))
	gpart("UpperTorso", m, base + Vector3.new(0, spec.hip + 1.6 * s, 0), Vector3.new(2 * s, 1.6 * s, s))
	gpart("Head", m, base + Vector3.new(0, body - 0.6 * s, 0), Vector3.new(1.2 * s, 1.2 * s, 1.2 * s))
	for _, side in { { "Left", -1 }, { "Right", 1 } } do
		local sx = side[2]
		gpart(`{side[1]}UpperArm`, m, base + Vector3.new(sx * (L / 2 - 0.5 * s), spec.hip + 1.5 * s, 0), Vector3.new(s, 2 * s, 0.9 * s))
		gpart(`{side[1]}Foot`, m, base + Vector3.new(sx * 0.5 * s, 0.2 * s, 0), Vector3.new(0.9 * s, 0.4 * s, 1.2 * s))
	end
	for _, acc in spec.acc do
		local a = new("Accessory", `{accPrefix}_{acc}`, m)
		local size, center
		if acc == spec.hat then
			size = Vector3.new(1.3 * s, H - body + 0.3 * s, 1.2 * s)
			center = Vector3.new(0, (body - 0.3 * s + H) / 2, 0)
		elseif acc == spec.deep then
			size = Vector3.new(0.8 * s, 0.8 * s, P)
			center = Vector3.new(0, spec.hip + s, 0)
		else
			size = Vector3.new(0.5 * s, 0.5 * s, 0.5 * s)
			center = Vector3.new(0, spec.hip + 1.5 * s, 0)
		end
		gpart("Handle", a, base + center, size)
	end
	local hum = new("Humanoid", "Humanoid", m)
	hum.HipHeight = spec.hip
	hum.WalkSpeed = 16 * s
	hum.DisplayDistanceType = "Enum.HumanoidDisplayDistanceType.None"
	new("Animator", "Animator", hum)
	folder(m, "Animations")
	m.PrimaryPart = root
	setScale(m, s)
	return m
end

local TEMPLATES = {}
for zone = 1, 6 do
	local m = buildGuard(`Guard_Z{zone}`, RELEVE[zone], Vector3.new(1000 + 20 * zone, 0, 0), `ACC_Z{zone}`)
	m.Parent = GuardsF
	TEMPLATES[zone] = m
end

---------------------------------------------------------------- joueurs
local nextId = 300
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
local function removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	local char = p.Character
	if char then
		char:Destroy()
	end
	p.Parent = nil
end
local function payload(storeName, zone)
	return { Kind = "NPCBox", Tier = "Standard", Zone = zone, Rarity = "Common", ItemId = "Z1_Canette", StoreId = storeName, SlotId = "ShelfSlot_01" }
end

---------------------------------------------------------------- simulation
local DT = 1 / 30
local motion = {} -- [player] = function(position, dt) -> nouvelle position

local function activeFolder()
	return Workspace:FindFirstChild("ActiveGuards")
end
local function guards()
	local f = activeFolder()
	return if f then f:GetChildren() else {}
end
local function guardOf(player)
	for _, g in guards() do
		if g:GetAttribute("TargetUserId") == player.UserId and string.sub(g.Name, 1, 11) ~= "NightGuard_" then
			return g
		end
	end
	return nil
end
local function guardNamed(name)
	local f = activeFolder()
	return f and f:FindFirstChild(name)
end
local function nightCount()
	local n = 0
	for _, g in guards() do
		if string.sub(g.Name, 1, 11) == "NightGuard_" then
			n += 1
		end
	end
	return n
end

-- Les vigiles avancent vers leur MoveTo à leur WalkSpeed et se tournent dans le sens de la
-- marche (AutoRotate) ; seul le HumanoidRootPart bouge (les mesures se font sur lui).
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

local function countWarn(pattern)
	local n = 0
	for _, line in FULL_LOG do
		if line.kind == "WARN" and string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end
local function fullLogHas(pattern, kind)
	for _, line in FULL_LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, pattern, 1, true) then
			return true
		end
	end
	return false
end

-- La dernière piste `name` chargée pour ce vigile.
local function trackOf(model, name)
	for i = #ALL_TRACKS, 1, -1 do
		local t = ALL_TRACKS[i]
		if t.Name == name and t.Animation:IsDescendantOf(model) then
			return t
		end
	end
	return nil
end
local function gait(speed, reference, scale)
	return math.clamp(speed / (reference * scale), 0.6, 1.6)
end
local function f3(x)
	return if x then string.format("%.3f", x) else "?"
end

---------------------------------------------------------------- chargement
local Balance = requireModule(ConfigF:FindFirstChild("Balance"), "server")
local Night = requireModule(ConfigF:FindFirstChild("Night"), "server")
local Zones = requireModule(ConfigF:FindFirstChild("Zones"), "server")
-- a94 (2026-11-12, L-108 point 2) : vigiles de nuit à Night.ChaseSpeed (au moins vitesse conseillée + 4),
-- Run bornée à Night.GaitSpeedMax ; sans ces champs, l'ancienne règle (vitesse conseillée + 4, 1,6).
local function nightSpeed(zone: number): number
	local base = Zones[zone].AdvisedSpeed + Night.ChaseSpeedBonus
	return if type(Night.ChaseSpeed) == "number" then math.max(Night.ChaseSpeed, base) else base
end
local NIGHT_GAIT_MAX = if type(Night.GaitSpeedMax) == "number" then Night.GaitSpeedMax else 1.6
local function nightRun(zone: number, scale: number): number
	return math.clamp(nightSpeed(zone) / (20 * scale), 0.6, NIGHT_GAIT_MAX)
end
local FormatM = requireModule(Shared:FindFirstChild("Format"), "server")
local AnimPlayerM = requireModule(AnimF:FindFirstChild("AnimPlayer"), "server")
local CarryService = requireModule(CarryModule, "server")
local StatsService = requireModule(StatsModule, "server")
local GuardService = requireModule(GuardModule, "server")
GuardService.Start()
runFor(0.5) -- le rig de remplacement se construit

-- Le relevé est bien reproduit : boîtes, HipHeight, échelles.
do
	local ok = true
	for zone = 1, 6 do
		local _, size = TEMPLATES[zone]:GetBoundingBox()
		local box = RELEVE[zone].box
		ok = ok and near(size.X, box[1], 1e-6) and near(size.Y, box[2], 1e-6) and near(size.Z, box[3], 1e-6)
		ok = ok and TEMPLATES[zone]:GetScale() == RELEVE[zone].scale
	end
	check(ok, "modèles du banc aux mesures du relevé (boîtes accessoires compris, échelles)")
end

---------------------------------------------------------------- B1 jour
print("\nB1 : vigiles de jour Guard_Z1 à Guard_Z6, à la taille de Clément (Animations vides)")
do
	local params = {}
	for zone = 1, 6 do
		local spec, tpl, store = RELEVE[zone], TEMPLATES[zone], STORES[zone]
		local s = spec.scale
		local p = addPlayer(`Day{zone}`, store.street)
		clearLog()
		local pathsBefore = #PATH_PARAMS
		CarryService.StartCarry(p, payload(store.model.Name, zone))
		runFor(DT)
		local g = guardOf(p)
		local hum = g and g:FindFirstChildOfClass("Humanoid")
		local root = g and g:FindFirstChild("HumanoidRootPart")
		check(g ~= nil and g.Name == `Guard_Z{zone}`, `zone {zone} : clone de ReplicatedStorage.Assets.Guards.Guard_Z{zone}`)
		if g then
			local exp = AGENT[zone]
			local pp = PATH_PARAMS[#PATH_PARAMS]
			params[zone] = pp
			check(
				#PATH_PARAMS == pathsBefore + 1 and near(pp.AgentRadius, exp[1], 1e-9) and near(pp.AgentHeight, exp[2], 1e-9),
				`zone {zone} : chemin créé avec AgentRadius {pp.AgentRadius}, AgentHeight {pp.AgentHeight} (boîte {spec.box[1]} × {spec.box[2]} × {spec.box[3]})`
			)
			check(pp.AgentCanJump == true and pp.AgentCanClimb == false and pp.WaypointSpacing == 4, `zone {zone} : saut permis, escalade coupée, un point tous les 4 studs`)
			check(hum.HipHeight == spec.hip, `zone {zone} : HipHeight de Clément gardée ({hum.HipHeight})`)
			check(near(root.Position.Y, store.spawn.Y + spec.hip + s, 1e-6), `zone {zone} : pieds sur le GuardSpawn (HipHeight + demi-HumanoidRootPart)`)
			local accCount, accOk, bodyOk = 0, true, true
			for _, d in g:GetDescendants() do
				if d:IsA("BasePart") then
					if d.Parent:IsA("Accoutrement") then
						accCount += 1
						accOk = accOk and d.CanCollide == false and d.Massless == true and d.CollisionGroup == "Guards" and d.Anchored == false
					else
						bodyOk = bodyOk and d.CollisionGroup == "Guards" and d.CanCollide == true and d.Massless == false and d.Anchored == false
					end
				end
			end
			check(accCount == #spec.acc and accOk, `zone {zone} : {accCount} accessoire(s) sans collision ni masse, dans le groupe Guards`)
			check(bodyOk, `zone {zone} : corps dans le groupe Guards, collisions et masse inchangées`)
			local tplOk = true
			for _, d in tpl:GetDescendants() do
				if d:IsA("BasePart") then
					tplOk = tplOk and d.CollisionGroup == "Default" and d.CanCollide == true and d.Massless == false
				end
			end
			local tplHum = tpl:FindFirstChildOfClass("Humanoid")
			check(
				tplOk and tplHum.WalkSpeed == 16 * s and tplHum.HipHeight == spec.hip and #tpl:FindFirstChild("Animations"):GetChildren() == 0 and tpl.Parent == GuardsF,
				`zone {zone} : modèle de Clément intact (pièces, WalkSpeed {16 * s}, HipHeight, Animations vide, rangé)`
			)
			check(hum.WalkSpeed == 0, `zone {zone} : WalkSpeed 0 pendant le délai de réaction (le modèle a {16 * s})`)
			local text = `zone {zone}, vitesse {FormatM.short(Zones[zone].GuardSpeed)}, échelle {string.format("%.2f", s)}, agent {FormatM.short(exp[1])} × {FormatM.short(exp[2])}`
			check(logHas(text, "PRINT"), `sortie : « …{text}… »`)
			runFor(0.55)
			check(hum.WalkSpeed == Zones[zone].GuardSpeed, `zone {zone} : poursuite à {Zones[zone].GuardSpeed}, la vitesse de la zone`)
		end
		CarryService.Consume(p)
		check(runUntilEmpty(15), `zone {zone} : abandon, retour, parti`)
		removePlayer(p)
	end
	local distinct = true
	for a = 1, 6 do
		for b = a + 1, 6 do
			distinct = distinct and params[a] ~= nil and params[b] ~= nil and params[a] ~= params[b]
		end
	end
	check(distinct, "un jeu de paramètres par vigile, pas un seul pour tous")
end

---------------------------------------------------------------- B2 capture et abandon
print("\nB2 : capture d'un vigile à l'échelle 1,40 (HumanoidRootPart 1,47 plus haut que celui du joueur)")
do
	-- Le joueur attend, pieds au sol, 10 studs devant le GuardSpawn ; mesures à chaque image.
	local function chase(zone, name, dy)
		local store = STORES[zone]
		local p = addPlayer(name, (store.frame * CFrame.new(0, store.spawn.Y + 3 + (dy or 0), -3)).Position)
		local before = #CarryService.Calls
		CarryService.StartCarry(p, payload(store.model.Name, zone))
		runFor(DT)
		local g = guardOf(p)
		local r = g and g:FindFirstChild("HumanoidRootPart")
		local samples, caught = {}, nil
		runFor(4, function()
			if caught == nil and r and r.Parent then
				local offset = r.Position - rootOf(p).Position
				local sample = { d3 = offset.Magnitude, dh = Vector3.new(offset.X, 0, offset.Z).Magnitude, dy = offset.Y }
				table.insert(samples, sample)
				if #CarryService.Calls > before then
					caught = sample
					caught.index = #samples
				end
			end
		end)
		return p, samples, caught
	end
	local catchDistance = Balance.Guard.CatchDistance
	for _, case in { { zone = 6, name = "Bank" }, { zone = 1, name = "Mini" } } do
		local spec = RELEVE[case.zone]
		local p, samples, caught = chase(case.zone, case.name)
		local expectedDy = spec.hip + spec.scale - 3
		check(caught ~= nil, `zone {case.zone} (échelle {spec.scale}) : le joueur immobile est attrapé`)
		if caught then
			local farther = true
			for i = 1, caught.index - 1 do
				farther = farther and samples[i].d3 > catchDistance
			end
			check(caught.d3 <= catchDistance, `zone {case.zone} : capture à {f3(caught.d3)} studs entre les HumanoidRootPart (≤ {catchDistance})`)
			check(farther, `zone {case.zone} : aucune capture tant que la distance dépasse {catchDistance}`)
			check(near(caught.dy, expectedDy, 1e-6), `zone {case.zone} : écart de hauteur des HumanoidRootPart {f3(caught.dy)}`)
			local reach = math.sqrt(catchDistance ^ 2 - expectedDy ^ 2)
			check(caught.dh <= reach + 1e-9, `zone {case.zone} : à l'horizontale, {f3(caught.dh)} studs (portée {f3(reach)})`)
		end
		check(runUntilEmpty(10), `zone {case.zone} : rentré`)
		removePlayer(p)
	end

	-- Joueur perché : 4,2 studs au-dessus du HumanoidRootPart du vigile. Le vigile arrive juste
	-- dessous, mais la distance ne passe jamais sous 4 : pas de capture.
	local spec = RELEVE[6]
	local high, samples, caught = chase(6, "High", spec.hip + spec.scale - 3 + 4.2)
	local minD3, minDh = math.huge, math.huge
	for _, sample in samples do
		minD3 = math.min(minD3, sample.d3)
		minDh = math.min(minDh, sample.dh)
	end
	check(caught == nil and CarryService.IsCarrying(high), "joueur 4,2 studs au-dessus du vigile : jamais attrapé")
	check(minDh < 0.5 and minD3 >= 4.2 - 1e-6, `le vigile passe dessous (horizontale {f3(minDh)}), distance jamais sous {f3(minD3)}`)
	CarryService.Consume(high)
	check(runUntilEmpty(15), "rentré")
	removePlayer(high)

	-- Abandon à 120 studs d'avance, comptés entre les HumanoidRootPart.
	clearLog()
	local store = STORES[6]
	local far = addPlayer("Far", store.street)
	CarryService.StartCarry(far, payload(store.model.Name, 6))
	runFor(DT)
	local g = guardOf(far)
	local r = g and g:FindFirstChild("HumanoidRootPart")
	motion[far] = runTo(store.street + Vector3.new(600, 0, 0), 90)
	local lead = nil
	runFor(6, function()
		if lead == nil and r and logHas("abandonne Far (120 studs d'avance)", "PRINT") then
			lead = (r.Position - rootOf(far).Position).Magnitude
		end
	end)
	motion[far] = nil
	-- a66 (Cantin, 2026-11-11) : poursuite sans fin, plus d'abandon pour l'avance prise (Balance.Guard sans
	-- GiveUpChaseDuration). Avant a66 : l'ancien contrôle.
	if string.find(SOURCES["shared/Config/Balance.luau"] or "", "GiveUpChaseDuration", 1, true) == nil then
		local gap = if r then (r.Position - rootOf(far).Position).Magnitude else 0
		check(lead == nil and guardOf(far) == g and gap > Balance.Guard.GiveUpLead + 4, `a66 : toujours poursuivi à {f3(gap)} studs d'avance (poursuite sans fin)`)
	else
		check(lead ~= nil and lead >= Balance.Guard.GiveUpLead and lead < Balance.Guard.GiveUpLead + 4, `abandon à {f3(lead)} studs (≥ 120)`)
	end
	CarryService.Consume(far)
	check(runUntilEmpty(30), "rentré")
	removePlayer(far)
end

---------------------------------------------------------------- B3 nuit
print("\nB3 : vigiles de nuit : NightGuard_Z<n> s'il existe, sinon Guard_Z<n>")
local GATES = { 30, 100, 190, 300, 430, 580, 700 }
local PATROL = {}
for zone = 1, 6 do
	local x0, x1 = GATES[zone], GATES[zone + 1]
	PATROL[zone] = {}
	for k, f in { 0.25, 0.75 } do
		local p = new("Part", string.format("NightPatrol_Z%d_%s", zone, if k == 1 then "A" else "B"), Workspace)
		p.Size = Vector3.new(3, 0.13, 3)
		p.CFrame = CFrame.new(x0 + (x1 - x0) * f, 0.015, 0)
		p.Anchored = true
		p:SetAttribute("Zone", zone)
		addTag(p, "NightPatrol")
		PATROL[zone][k] = p.Position
	end
end
local HOOKS = {
	InCorridor = function(position)
		return position.X > 12
	end,
	Ignores = function()
		return false
	end,
	SendHome = function()
		return true
	end,
}
do
	clearLog()
	local planned = GuardService.StartNightPatrol(HOOKS)
	runFor(DT)
	check(planned == 12 and nightCount() == 12, `12 vigiles de nuit ({nightCount()})`)
	for zone = 1, 6 do
		local spec = RELEVE[zone]
		local okLook, okAgent, okSize = true, true, true
		for k = 1, 2 do
			local g = guardNamed(string.format("NightGuard_Z%d_%d", zone, k))
			local root = g and g:FindFirstChild("HumanoidRootPart")
			local hum = g and g:FindFirstChildOfClass("Humanoid")
			okLook = okLook and g ~= nil and g:FindFirstChild(`ACC_Z{zone}_{spec.acc[1]}`) ~= nil
			okSize = okSize and hum ~= nil and hum.HipHeight == spec.hip and hum.WalkSpeed == Night.PatrolSpeed and near(root.Position.Y, PATROL[zone][k].Y + spec.hip + spec.scale, 1e-6)
			if g then
				for _, d in g:GetDescendants() do
					if d:IsA("BasePart") and d.Parent:IsA("Accoutrement") then
						okSize = okSize and d.CanCollide == false and d.Massless == true and d.CollisionGroup == "Guards"
					end
				end
			end
			local text = string.format(
				"NightGuard_Z%d_%d (ReplicatedStorage.Assets.Guards.Guard_Z%d) en ronde, zone %d, 2 point(s), poursuite à %s, échelle %.2f, agent %s × %s",
				zone, k, zone, zone, FormatM.short(nightSpeed(zone)), spec.scale, FormatM.short(AGENT[zone][1]), FormatM.short(AGENT[zone][2])
			)
			okAgent = okAgent and logHas(text, "PRINT")
		end
		check(okLook, `zone {zone} : les 2 vigiles de nuit portent le look de Guard_Z{zone} (pas de NightGuard livré)`)
		check(okSize and okAgent, `zone {zone} : HipHeight, ronde à {Night.PatrolSpeed} (pas 16 × {spec.scale}), pieds sur le point, accessoires, agent {FormatM.short(AGENT[zone][1])} × {FormatM.short(AGENT[zone][2])}`)
	end
	check(not fullLogHas("NightFlashlight", nil) and Workspace:FindFirstChild("NightFlashlight", true) == nil, "aucune lampe ajoutée au look de Clément (L-043 : sa lampe viendra avec NightGuard)")
	GuardService.StopNightPatrol()
	runFor(DT)
	check(nightCount() == 0, "aube : partis")

	-- Clément livre NightGuard_Z2 : la zone 2 le prend, les autres gardent Guard_Z<n>.
	local ng = buildGuard("NightGuard_Z2", { scale = 1.10, box = { 4.35, 6.2, 2.0 }, hip = 2.41, acc = { "Casquette", "Lampe" }, hat = "Casquette", deep = "Lampe" }, Vector3.new(1300, 0, 0), "ACC_N2")
	ng.Parent = GuardsF
	clearLog()
	GuardService.StartNightPatrol(HOOKS)
	runFor(DT)
	local g21 = guardNamed("NightGuard_Z2_1")
	local g31 = guardNamed("NightGuard_Z3_1")
	check(g21 and g21:FindFirstChild("ACC_N2_Lampe") ~= nil and g21:FindFirstChild("ACC_Z2_Bonnet") == nil, "zone 2 : NightGuard_Z2 livré, il est pris")
	check(g31 and g31:FindFirstChild("ACC_Z3_Casquette") ~= nil, "zone 3 : toujours Guard_Z3")
	check(logHas("NightGuard_Z2_1 (ReplicatedStorage.Assets.Guards.NightGuard_Z2) en ronde, zone 2, 2 point(s), poursuite à " .. FormatM.short(nightSpeed(2)) .. ", échelle 1.10, agent 2.2 × 6.2", "PRINT"), "NightGuard_Z2 : agent à sa taille (2,2 × 6,2)")
	GuardService.StopNightPatrol()
	runFor(DT)
	ng:Destroy()
end

---------------------------------------------------------------- B4 Animations vides
print("\nB4 : dossiers Animations vides (état de Studio) : rien ne casse, un avertissement par nom")
do
	local counts, line = {}, {}
	for _, name in { "Idle", "Walk", "Run", "Catch", "Tired" } do
		counts[name] = countWarn(`« {name} » non jouée`)
		table.insert(line, `{name} {counts[name]}`)
	end
	check(counts.Idle == 1 and counts.Walk == 1 and counts.Run == 1 and counts.Catch == 1 and counts.Tired == 1, `un avertissement par nom, jour et nuit compris : {table.concat(line, ", ")}`)
	check(countWarn("[Anim]") == 5, `5 avertissements d'animation en tout ({countWarn("[Anim]")}) pour 10 vigiles de jour et 24 de nuit`)
	check(fullLogHas("Guard_Z1.Animations.Idle absent (pas encore livrée)", "WARN"), "l'avertissement dit ce qui manque")
	check(not fullLogHas("parti (erreur)", nil) and not fullLogHas("non créé", nil), "aucun vigile en erreur ni refusé")
end

---------------------------------------------------------------- B5 rythme
print("\nB5 : rythme de Run et de Walk, animations livrées (L-048)")
for zone = 1, 6 do
	for _, name in { "Idle", "Walk", "Run", "Catch", "Tired" } do
		local a = new("Animation", name, TEMPLATES[zone]:FindFirstChild("Animations"))
		a.AnimationId = "rbxassetid://" .. tostring(100 + zone)
	end
end
TRACK_LENGTH.Catch = 1.4
TRACK_LENGTH.Tired = 3.3
MARKER_AT.Catch = { "Impact", 0.3 }
do
	for zone = 1, 6 do
		local s = RELEVE[zone].scale
		local store = STORES[zone]
		local p = addPlayer(`Gait{zone}`, store.street)
		CarryService.StartCarry(p, payload(store.model.Name, zone))
		runFor(DT)
		local g = guardOf(p)
		motion[p] = runTo(store.street + Vector3.new(400, 0, 0), 50) -- il s'éloigne sans se faire prendre
		runFor(0.55)
		local run = g and trackOf(g, "Run")
		local expRun = gait(Zones[zone].GuardSpeed, 20, s)
		check(run and run.IsPlaying and near(run.Speed, expRun, 1e-9), `zone {zone} : Run à {f3(run and run.Speed)} = {Zones[zone].GuardSpeed} / (20 × {s})`)
		runFor(1)
		CarryService.Consume(p)
		motion[p] = nil
		runFor(DT)
		local tired = g and trackOf(g, "Tired")
		check(run and not run.IsPlaying and tired and tired.IsPlaying, `zone {zone} : abandon, Run arrêtée, Tired`)
		runFor(3.4)
		local walk = g and trackOf(g, "Walk")
		local expWalk = gait(10, 10, s)
		check(walk and walk.IsPlaying and near(walk.Speed, expWalk, 1e-9) and g:FindFirstChildOfClass("Humanoid").WalkSpeed == 10, `zone {zone} : retour en marchant à 10, Walk à {f3(walk and walk.Speed)} = 10 / (10 × {s})`)
		check(runUntilEmpty(20), `zone {zone} : rentré`)
		removePlayer(p)
	end
	check(near(gait(Zones[1].GuardSpeed, 20, 1), 0.67, 1e-9) and near(gait(Zones[6].GuardSpeed, 20, 1.4), 42.2 / 28, 1e-9), "repères : 0,67 en zone 1, 1,51 en zone 6")

	-- La nuit : ronde en Walk, poursuite en Run à la vitesse conseillée + 4. Chaque vigile marque
	-- d'abord la pause de son point de départ (Night.PatrolPause), puis marche vers le suivant.
	clearLog()
	GuardService.StartNightPatrol(HOOKS)
	runFor(Night.PatrolPause + 0.1)
	local okWalk = true
	for zone = 1, 6 do
		for k = 1, 2 do
			local g = guardNamed(string.format("NightGuard_Z%d_%d", zone, k))
			local walk = g and trackOf(g, "Walk")
			okWalk = okWalk and walk ~= nil and walk.IsPlaying and near(walk.Speed, gait(Night.PatrolSpeed, 10, RELEVE[zone].scale), 1e-9)
		end
	end
	check(okWalk, "ronde : Walk de chaque vigile de nuit à 10 / (10 × échelle)")

	-- Le vigile de nuit qui poursuit ce joueur (l'un ou l'autre de la zone).
	local function nightChaserOf(player)
		for _, g in guards() do
			if string.sub(g.Name, 1, 11) == "NightGuard_" and g:GetAttribute("TargetUserId") == player.UserId then
				return g
			end
		end
		return nil
	end

	-- Zone 6 : repérée, Nina est poursuivie à 52, Run bornée à 1,6 ; elle quitte le couloir.
	local r61 = guardNamed("NightGuard_Z6_1"):FindFirstChild("HumanoidRootPart")
	local nina = addPlayer("Nina", Vector3.new(r61.Position.X + 20, 3.015, 0))
	runFor(0.2)
	local g61 = nightChaserOf(nina)
	check(g61 ~= nil and string.sub(g61.Name, 1, 13) == "NightGuard_Z6", `zone 6 : Nina repérée à 20 studs ({g61 and g61.Name})`)
	runFor(0.5)
	local run61 = trackOf(g61, "Run")
	check(g61:FindFirstChildOfClass("Humanoid").WalkSpeed == nightSpeed(6), `poursuite à {nightSpeed(6)}`)
	check(run61 and run61.IsPlaying and near(run61.Speed, nightRun(6, 1.4), 1e-9) and not trackOf(g61, "Walk").IsPlaying, `zone 6 la nuit : Run à {f3(run61 and run61.Speed)} (attendu {f3(nightRun(6, 1.4))})`)
	local mark = #SPEED_LOG
	rootOf(nina).CFrame = CFrame.new(5, 3, 0) -- hors du couloir
	runFor(DT)
	check(logHas(`{g61.Name} : abandonne Nina (sorti du couloir)`, "PRINT"), "Nina sort du couloir : il lâche")
	runFor(3.4) -- Tired (3,3 s), puis retour vers le point de ronde le plus proche
	local walk61 = trackOf(g61, "Walk")
	check(walk61 and walk61.IsPlaying and near(walk61.Speed, gait(10, 10, 1.4), 1e-9), `retour vers la ronde : Walk à {f3(walk61 and walk61.Speed)}`)
	-- Arrivé : il reprend sa ronde (startPatrol → setWalkSpeed) ; la Walk en cours est réglée, pas relancée.
	local adjusted, plays, waited = nil, 0, 0
	while adjusted == nil and waited < 5 do
		runFor(DT)
		waited += DT
		plays = 0
		for i = mark + 1, #SPEED_LOG do
			local e = SPEED_LOG[i]
			if e.track == walk61 then
				if e.via == "Play" then
					plays += 1
				elseif adjusted == nil then
					adjusted = e
					break
				end
			end
		end
	end
	check(
		adjusted ~= nil and near(adjusted.speed, gait(10, 10, 1.4), 1e-9) and plays == 1,
		`reprise de la ronde : Walk réglée en cours de lecture à {f3(adjusted and adjusted.speed)} (setWalkSpeed), lancée {plays} fois`
	)
	removePlayer(nina)

	-- Zone 1 : Omar attend 15 studs devant un vigile : Run à 1,0, attrapé dès 4 studs, pas avant.
	local r11 = guardNamed("NightGuard_Z1_1"):FindFirstChild("HumanoidRootPart")
	local look = r11.CFrame.LookVector
	local omar = addPlayer("Omar", Vector3.new(r11.Position.X, 3.015, r11.Position.Z) + Vector3.new(look.X, 0, look.Z).Unit * 15)
	runFor(0.2)
	local g1 = nightChaserOf(omar)
	local r1 = g1 and g1:FindFirstChild("HumanoidRootPart")
	check(g1 ~= nil and string.sub(g1.Name, 1, 13) == "NightGuard_Z1", `zone 1 : Omar repéré ({g1 and g1.Name})`)
	local statsBefore = #StatsService.Log
	local caught, promptly, runSpeed = nil, true, nil
	runFor(3, function()
		if caught == nil and r1 and r1.Parent then
			local run = trackOf(g1, "Run")
			if run and run.IsPlaying then
				runSpeed = run.Speed
			end
			local d = (r1.Position - rootOf(omar).Position).Magnitude
			for i = statsBefore + 1, #StatsService.Log do
				local e = StatsService.Log[i]
				if e.player == omar and e.key == "GuardStun" then
					caught = d
				end
			end
			if caught == nil and d <= Night.CatchDistance then
				promptly = false -- à portée sans être attrapé
			end
		end
	end)
	check(runSpeed ~= nil and near(runSpeed, nightRun(1, 1), 1e-9), `zone 1 la nuit : Run à {f3(runSpeed)} (attendu {f3(nightRun(1, 1))})`)
	check(caught ~= nil and caught <= Night.CatchDistance and promptly, `zone 1 la nuit : attrapé à {f3(caught)} studs, dès qu'il est à {Night.CatchDistance} ou moins`)
	removePlayer(omar)
	GuardService.StopNightPatrol()
	runFor(DT)
end

---------------------------------------------------------------- B6 bornes et rig de remplacement
print("\nB6 : bornes 0,6 et 1,6 ; rig de remplacement")
do
	local store = STORES[1]
	for _, case in { { speed = 8, expected = 0.6, label = "8 / 20 = 0,4" }, { speed = 40, expected = 1.6, label = "40 / 20 = 2" } } do
		GuardService.GetSpeedOverride = function()
			return case.speed
		end
		local p = addPlayer(`Clamp{case.speed}`, store.street)
		CarryService.StartCarry(p, payload(store.model.Name, 1))
		runFor(DT)
		local g = guardOf(p)
		runFor(0.55)
		local run = g and trackOf(g, "Run")
		check(run and run.IsPlaying and near(run.Speed, case.expected, 1e-9), `vigile à {case.speed} (tuto) : Run à {f3(run and run.Speed)} ({case.label}, bornée)`)
		CarryService.Consume(p)
		check(runUntilEmpty(15), "rentré")
		removePlayer(p)
	end
	GuardService.GetSpeedOverride = function()
		return nil
	end

	-- Sans les modèles de Clément : rig de remplacement, échelle 1, agent d'un R15 standard.
	GuardsF.Parent = nil
	clearLog()
	local p = addPlayer("Fallback", STORES[6].street)
	local before = #PATH_PARAMS
	CarryService.StartCarry(p, payload(STORES[6].model.Name, 6))
	runFor(DT)
	local g = guardOf(p)
	local pp = PATH_PARAMS[#PATH_PARAMS]
	check(g and g.Name == "Guard_Fallback" and #PATH_PARAMS == before + 1 and pp.AgentRadius == 2 and pp.AgentHeight == 5, "rig de remplacement : agent 2 × 5 (plancher)")
	check(logHas("vitesse 42.2, échelle 1.00, agent 2 × 5", "PRINT"), "sortie : échelle 1.00, agent 2 × 5")
	CarryService.Consume(p)
	check(runUntilEmpty(15), "rentré")
	removePlayer(p)
	GuardsF.Parent = Assets
end

---------------------------------------------------------------- B7 AnimPlayer.AdjustSpeed
print("\nB7 : AnimPlayer.AdjustSpeed")
do
	local rig = new("Model", "UnitRig", Workspace)
	local hum = new("Humanoid", "Humanoid", rig)
	local animator = new("Animator", "Animator", hum)
	local anims = folder(rig, "Animations")
	local a = new("Animation", "Run", anims)
	a.AnimationId = "rbxassetid://7"
	local ap = AnimPlayerM.new(animator, anims, nil, "Banc")
	check(ap:AdjustSpeed("Run", 1.2) == false, "pas encore chargée : rien")
	local track = ap:Play("Run", nil, nil, 0.8)
	check(track and track.Speed == 0.8, "Play(nom, nil, nil, 0,8) : jouée à 0,8")
	check(ap:AdjustSpeed("Run", 1.3) == true and track.Speed == 1.3 and track.IsPlaying, "en cours : vitesse changée, sans relance")
	ap:Stop("Run")
	check(ap:AdjustSpeed("Run", 1.5) == false and track.Speed == 1.3, "arrêtée : rien")
	clearLog()
	check(ap:AdjustSpeed("Absente", 1) == false and not logHas("Absente", nil), "nom absent : rien, sans avertissement")
	ap:Destroy()
	check(ap:AdjustSpeed("Run", 1) == false, "après Destroy : rien")
	rig:Destroy()
end

summary()
