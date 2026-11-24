-- Banc a240, partie crowd (vague 72, L-229 partie Foule, mesure de fusion65) : WitnessCrowdController sur le faux Roblox
-- du banc a236 crowd (copie a240). Bouchons en plus : Shared/Anim/MarkerSounds (find, playSound notés),
-- Controllers/WindowController (OnBroken, GetWindow), CollectionService:HasTag.
--   B1 création étalée : au plus Crowd.BuildPerFrame personnes par image, toutes là au bout, GetStats (Pending, FrameMax)
--   S1 cris au marqueur Shout (sons du rôle), pas de relance tant que le son joue, au plus Sounds.Voices à la fois
--   S2 photo au flash (Witness_Photo ou Crowd_PhotoBurst), au plus Sounds.PhotoVoices ; son absent : muet, une ligne
--   S3 Crowd_Gasp à la casse d'une vitrine de magasin PNJ (3D sur la vitre) ; boutique de joueur, nuit, loin : rien
NOW = 0

-- Vecteurs ---------------------------------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V)
end
local methodsV = {}
function methodsV.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	return methodsV[k]
end
V.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V.__mul = function(a, b)
	if type(a) == "number" then
		return vec(a * b.X, a * b.Y, a * b.Z)
	end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V.__div = function(a, b)
	return vec(a.X / b, a.Y / b, a.Z / b)
end
V.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end
local FVector3 = { new = vec, zero = vec(0, 0, 0) }

-- CFrame : position + angle autour de Y (Roblox : LookVector = (−sin θ, 0, −cos θ)).
local C = {}
local function cf(p, yaw)
	return setmetatable({ Position = p, _yaw = yaw or 0 }, C)
end
local function rot(yaw, v)
	local c, s = math.cos(yaw), math.sin(yaw)
	return vec(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end
local methodsC = {}
function methodsC.VectorToWorldSpace(self, v)
	return rot(self._yaw, v)
end
function methodsC.PointToObjectSpace(self, p)
	return rot(-self._yaw, p - self.Position)
end
function methodsC.ToObjectSpace(self, other)
	return cf(rot(-self._yaw, other.Position - self.Position), other._yaw - self._yaw)
end
C.__index = function(self, k)
	if k == "LookVector" then
		return rot(rawget(self, "_yaw"), vec(0, 0, -1))
	elseif k == "RightVector" then
		return rot(rawget(self, "_yaw"), vec(1, 0, 0))
	elseif k == "X" or k == "Y" or k == "Z" then
		return rawget(self, "Position")[k]
	end
	return methodsC[k]
end
C.__mul = function(a, b)
	return cf(a.Position + rot(a._yaw, b.Position), a._yaw + b._yaw)
end
local function yawOf(direction)
	return math.atan2(-direction.X, -direction.Z)
end
local FCFrame = {
	new = function(p)
		return cf(p, 0)
	end,
	lookAt = function(from, to)
		local d = vec(to.X - from.X, 0, to.Z - from.Z)
		return cf(from, if d.Magnitude > 1e-9 then yawOf(d) else 0)
	end,
	Angles = function(_, y, _)
		return cf(vec(0, 0, 0), y)
	end,
}
local FEnum = setmetatable({}, {
	__index = function(_, a)
		return setmetatable({}, {
			__index = function(_, b)
				return a .. "." .. b
			end,
		})
	end,
})

-- Signaux et instances ----------------------------------------------------------------------------
local function newSignal()
	local s = { _c = {} }
	function s:Connect(fn)
		local link = { fn = fn, on = true }
		table.insert(self._c, link)
		return {
			Disconnect = function()
				link.on = false
			end,
		}
	end
	function s:Fire(...)
		for _, link in table.clone(self._c) do
			if link.on then
				link.fn(...)
			end
		end
	end
	return s
end
local CLASSES = {
	Part = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	PointLight = "Light",
	Script = "LuaSourceContainer",
}
local TAGS = {} -- [instance] = { [tag] = true }
local I = {}
local methods = {}
I.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	if methods[k] then
		return methods[k]
	end
	for _, child in rawget(self, "_children") do
		if child.Name == k then
			return child
		end
	end
	return nil
end
I.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local at = table.find(old._children, self)
			if at then
				table.remove(old._children, at)
			end
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(v._children, self)
		end
		return
	end
	rawset(self, k, v)
end
local function node(class, name, parent, props)
	local o = setmetatable({ ClassName = class, Name = name, _children = {}, _attrs = {} }, I)
	for k, v in props or {} do
		rawset(o, k, v)
	end
	if parent then
		o.Parent = parent
	end
	return o
end
function methods.IsA(self, c)
	local k = self.ClassName
	while k do
		if k == c then
			return true
		end
		k = CLASSES[k]
	end
	return c == "Instance"
end
function methods.FindFirstChild(self, name, recursive)
	for _, child in self._children do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	return assert(self:FindFirstChild(name), name)
end
function methods.FindFirstChildOfClass(self, class)
	for _, child in self._children do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function methods.GetChildren(self)
	return table.clone(self._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, child in o._children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods.IsDescendantOf(self, other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.GetAttribute(self, k)
	return self._attrs[k]
end
function methods.SetAttribute(self, k, v)
	self._attrs[k] = v
end
function methods.Destroy(self)
	for _, child in table.clone(self._children) do
		child:Destroy()
	end
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function methods.Clone(self)
	if rawget(self, "Archivable") == false then
		return nil
	end
	local copy = node(self.ClassName, self.Name)
	for k, v in self do
		if k ~= "_children" and k ~= "_parent" and k ~= "_attrs" and k ~= "ClassName" and k ~= "Name" and k ~= "_tracks" then
			rawset(copy, k, v)
		end
	end
	for k, v in self._attrs do
		copy._attrs[k] = v
	end
	if TAGS[self] then
		TAGS[copy] = table.clone(TAGS[self])
	end
	for _, child in self._children do
		local c = child:Clone()
		if c then
			c.Parent = copy
		end
	end
	return copy
end
-- Modèle : pivot = celui de sa racine ; PivotTo déplace toutes ses pièces (même décalage, même rotation).
function methods.GetPivot(self)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then
		return root.CFrame
	end
	return rawget(self, "_pivot") or cf(vec(0, 0, 0), 0)
end
function methods.PivotTo(self, target)
	local from = self:GetPivot()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = from:ToObjectSpace(d.CFrame)
			d.CFrame = target * rel
			d.Position = d.CFrame.Position
		end
	end
	rawset(self, "_pivot", target)
end
function methods.LoadAnimation(self, animation)
	local track = { Animation = animation, Playing = false, Speed = 1, TimePosition = 0, _markers = {} }
	function track:Play(_fade, _weight, speed)
		self.Playing = true
		self.Speed = speed or 1
	end
	function track:AdjustSpeed(speed)
		self.Speed = speed
	end
	function track:GetMarkerReachedSignal(name)
		table.insert(MARKERS_ASKED, name)
		self._markers[name] = self._markers[name] or newSignal()
		return self._markers[name]
	end
	TRACKS[self.Parent.Parent] = track
	return track
end
TRACKS = {} -- [modèle] = sa piste
MARKERS_ASKED = {}
ACCESSORIES = {} -- [modèle] = { accessoires ajoutés par AddAccessory }
function methods.AddAccessory(self, accessory)
	local model = self.Parent
	accessory.Parent = model
	ACCESSORIES[model] = ACCESSORIES[model] or {}
	table.insert(ACCESSORIES[model], accessory)
end
local function setPos(part, p)
	part.Position = p
	part.CFrame = cf(p, part.CFrame and part.CFrame._yaw or 0)
end
-- Les écritures de CFrame d'une pièce tiennent Position à jour.
local partMeta = {}

-- Services ----------------------------------------------------------------------------------------
local game = node("DataModel", "game")
local Workspace = node("Workspace", "Workspace", game)
local camera = { CFrame = cf(vec(0, 10, 30), 0) }
Workspace.CurrentCamera = camera
GROUND_Y = 0
RAYCASTS = 0
function Workspace.Raycast(_, origin, direction, params)
	RAYCASTS += 1
	LAST_PARAMS = params
	if NO_GROUND then
		return nil
	end
	if origin.Y >= GROUND_Y and origin.Y + direction.Y <= GROUND_Y then
		return { Position = vec(origin.X, GROUND_Y, origin.Z) }
	end
	return nil
end
local ReplicatedStorage = node("ReplicatedStorage", "ReplicatedStorage", game)
local PLAYERS = {}
local localPlayer = node("Player", "Alice")
table.insert(PLAYERS, localPlayer)
local Players = {
	LocalPlayer = localPlayer,
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		return table.clone(PLAYERS)
	end,
}
local CollectionService = {
	GetTagged = function(_, tag)
		local out = {}
		for inst, tags in TAGS do
			if tags[tag] then
				table.insert(out, inst)
			end
		end
		table.sort(out, function(a, b)
			return a.Name < b.Name
		end)
		return out
	end,
	RemoveTag = function(_, inst, tag)
		if TAGS[inst] then
			TAGS[inst][tag] = nil
		end
	end,
}
local function tag(inst, t)
	TAGS[inst] = TAGS[inst] or {}
	TAGS[inst][t] = true
end
local heartbeat = newSignal()
local RunService = {
	Heartbeat = heartbeat,
	IsStudio = function()
		return true
	end,
}
local GuiService = { ReducedMotionEnabled = false }
local SERVICES = {
	CollectionService = CollectionService,
	GuiService = GuiService,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	Workspace = Workspace,
}
function game.GetService(_, name)
	return assert(SERVICES[name], name)
end
local LOGS = {}
local RNG_STEP = 0
local FRACTION = 0
local function nextFraction()
	FRACTION = (FRACTION + 0.6180339887) % 1
	return FRACTION
end
local FRandom = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + (b - a) * nextFraction() -- suite déterministe qui varie
			end,
			NextInteger = function(_, a, b)
				return math.min(a + math.floor(nextFraction() * (b - a + 1)), b)
			end,
		}
	end,
}
local FRaycastParams = {
	new = function()
		return {}
	end,
}

-- Modules ------------------------------------------------------------------------------------------
local Shared = node("Folder", "Shared", ReplicatedStorage)
local Config = node("Folder", "Config", Shared)
local Contract = node("Folder", "Contract", Shared)
local Controllers = node("Folder", "Controllers")
local cache = {}
local function module(name, parent, key, value)
	local m = node("ModuleScript", name, parent)
	rawset(m, "_key", key)
	if value ~= nil then
		cache[m] = value
	end
	return m
end
FLASHES, RELEASED = {}, {}
FEATURES = { WitnessCrowd = true }
module("Witness", Config, "shared/Config/Witness.luau")
module("DeepFreeze", Config, "shared/Config/DeepFreeze.luau")
module("Features", Config, nil, FEATURES)
module("Settings", Config, nil, {
	VfxReduced = function(player)
		return player ~= nil and player:GetAttribute("VfxEnabled") == false
	end,
})
module("WitnessGauge", Shared, "shared/WitnessGauge.luau")
module("Find", Contract, "shared/Contract/Find.luau")
module("WitnessController", Controllers, nil, {
	PlayFlash = function(model)
		table.insert(FLASHES, { model = model, t = NOW })
	end,
	ReleaseFlash = function(model)
		table.insert(RELEASED, model)
	end,
})
LOW = false
module("ShatterController", Controllers, nil, {
	IsLowEnd = function()
		return LOW
	end,
})
local controllerScript = module("WitnessCrowdController", Controllers, "client/Controllers/WitnessCrowdController.luau")
local function requireModule(m)
	if cache[m] ~= nil then
		return cache[m]
	end
	local fn = assert(loadstring(assert(SOURCES[m._key], m._key), m._key))
	setfenv(fn, setmetatable({
		script = m,
		require = requireModule,
		game = game,
		workspace = Workspace,
		Vector3 = FVector3,
		CFrame = FCFrame,
		Enum = FEnum,
		Color3 = { fromHex = function(h) return { Hex = h } end },
		Random = FRandom,
		RaycastParams = FRaycastParams,
		Instance = {
			new = function(c)
				return node(c, c)
			end,
		},
		os = setmetatable({
			clock = function()
				return NOW
			end,
		}, { __index = os }),
		print = function(...)
			table.insert(LOGS, table.concat({ ... }, " "))
		end,
		warn = function(...)
			table.insert(LOGS, "WARN " .. table.concat({ ... }, " "))
		end,
	}, { __index = getfenv(1) }))
	local v = fn()
	cache[m] = v
	return v
end
local function advance(seconds)
	local steps = math.floor(seconds / 0.05 + 0.5)
	for _ = 1, steps do
		NOW += 0.05
		heartbeat:Fire(0.05)
	end
end

CHECKS, FAILS = 0, 0
local function check(label, cond, detail)
	CHECKS += 1
	if cond then
		if VERBOSE then
			print("ok    " .. label)
		end
	else
		FAILS += 1
		print("ÉCHEC " .. label .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- Monde ----------------------------------------------------------------------------------------------
local Witness = requireModule(Config.Witness)
local Gauge = requireModule(Shared.WitnessGauge)
local CROWD = Witness.Crowd
local PHOTO = Witness.Photo

local function part(name, parent, p, size, yaw)
	local o = node("Part", name, parent, { Size = size or vec(1, 1, 1), Transparency = 0, Anchored = true, CanCollide = true, CanTouch = true, CanQuery = true, LocalTransparencyModifier = 0 })
	o.CFrame = cf(p, yaw or 0)
	o.Position = p
	return o
end
local map = node("Folder", "Map", Workspace)
-- Magasin : vitre de 10 studs en z = −50 tournée vers +Z (la rue) ; Bounds = l'intérieur, z de −80 à −50.
local function newStore(name, x)
	local s = node("Model", name, map)
	part("Window", s, vec(x, 5, -50), vec(10, 6, 0.5), math.pi)
	part("Bounds", s, vec(x, 5, -65), vec(20, 10, 30)).Transparency = 1
	tag(s, "NPCStore")
	return s
end
local stores = {}
for index = 1, 7 do
	stores[index] = newStore("STORE_Z1_" .. index, (index - 1) * 200)
end

-- Les personnes de Clément (L-223) : 01 et 02 ont les 5 animations, 03 seulement TakePhoto.
local Assets = node("Folder", "Assets", ReplicatedStorage)
local CrowdFolder = node("Folder", "Crowd", Assets)
local Models = node("Folder", "Models", CrowdFolder)
local Props = node("Folder", "Props", CrowdFolder)
local ALL = { "Cheer", "Boo", "Shout", "HoldSign", "TakePhoto" }
local function newCrowdModel(name, anims)
	local m = node("Model", name, Models)
	local hum = node("Humanoid", "Humanoid", m, { HipHeight = 2, DisplayDistanceType = "None" })
	node("Animator", "Animator", hum)
	part("HumanoidRootPart", m, vec(500, 50, 500), vec(2, 2, 1)).Anchored = false
	part("Head", m, vec(500, 51.5, 500), vec(1, 1, 1)).Anchored = false
	local folderA = node("Folder", "Animations", m)
	for _, a in anims do
		node("Animation", a, folderA)
	end
	m._attrs.Outfit = name
	return m
end
newCrowdModel("NPC_Crowd_01", ALL)
newCrowdModel("NPC_Crowd_02", ALL)
newCrowdModel("NPC_Crowd_03", { "TakePhoto" })
node("Model", "Autre", Models) -- pas un NPC_Crowd_ : ignoré
local function accessory(name, parent, side)
	local acc = node("Accessory", name, parent)
	local handle = part("Handle", acc, vec(0, 0, 0), vec(0.2, 0.4, 0.1))
	handle.Anchored = false
	node("Attachment", "RightGripAttachment", handle)
	if side then
		acc._attrs.Side = side
	end
	return acc
end
local phoneProp = accessory("ACC_Temoin_Telephone", Props)
node("Attachment", "FlashPoint", phoneProp.Handle)
local signs = {
	accessory("ACC_Crowd_SignFor_01", Props, "For"),
	accessory("ACC_Crowd_SignFor_02", Props, "For"),
	accessory("ACC_Crowd_SignAgainst_01", Props, "Against"),
}

-- Un témoin (repli d'avant L-223).
local function newWitness(name, p, watched)
	local m = node("Model", name, map)
	local hum = node("Humanoid", "Humanoid", m, { HipHeight = 2, DisplayDistanceType = "Viewer" })
	node("Animator", "Animator", hum)
	part("HumanoidRootPart", m, p, vec(2, 2, 1)).Anchored = false
	part("Head", m, p + vec(0, 1.5, 0), vec(1, 1, 1)).Anchored = false
	local acc = node("Accessory", "ACC_Temoin_Telephone", m)
	local handle = part("Handle", acc, p + vec(0.8, 1, -0.6), vec(0.2, 0.4, 0.1))
	handle.Anchored = false
	local point = node("Attachment", "FlashPoint", handle)
	node("PointLight", "Light", point, { Enabled = true })
	node("Attachment", PHOTO.CodePoint, handle)
	local anims = node("Folder", "Animations", m)
	node("Animation", "TakePhoto", anims)
	node("Script", "Intrus", m)
	m._attrs.WatchedStore = watched
	m._attrs[Gauge.StateAttribute] = "Watch"
	tag(m, Gauge.Tag)
	return m
end
local wA = newWitness("NPC_Witness_Z1_01", vec(30, 3, 0), "STORE_Z1_5")

local NEXT_ID = 1
local function newPlayer(name, p, isLocal)
	local pl = isLocal and localPlayer or node("Player", name)
	pl.UserId = NEXT_ID
	NEXT_ID += 1
	local ch = node("Model", name, Workspace)
	part("HumanoidRootPart", ch, p, vec(2, 2, 1))
	pl.Character = ch
	if not isLocal then
		table.insert(PLAYERS, pl)
	end
	return pl
end
local alice = newPlayer("Alice", vec(0, 3, -60), true)
local function moveTo(player, p)
	local root = player.Character.HumanoidRootPart
	root.Position = p
	root.CFrame = cf(p, 0)
end

-- a240 : bouchons des sons et des vitrines.
CollectionService.HasTag = function(_, inst, t)
	return TAGS[inst] ~= nil and TAGS[inst][t] == true
end
local Anim = node("Folder", "Anim", Shared)
HAVE = { Crowd_Cheer = true, Crowd_Clap = true, Crowd_Boo = true, Crowd_Shout = true, Crowd_Scream = true, Witness_Photo = true, Crowd_PhotoBurst = true, Crowd_Gasp = true }
PLAYED = {}
module("MarkerSounds", Anim, nil, {
	find = function(name)
		return if HAVE[name] then { Name = name } else nil
	end,
	playSound = function(template, at)
		local s = node("Sound", template.Name, at, { IsPlaying = true })
		table.insert(PLAYED, { name = template.Name, at = at, sound = s })
		return s
	end,
})
BROKEN = {}
WINDOWS = {}
module("WindowController", Controllers, nil, {
	OnBroken = function(fn)
		table.insert(BROKEN, fn)
		return function() end
	end,
	GetWindow = function(id)
		local w = WINDOWS[id]
		if w then
			return w[1], w[2]
		end
		return nil, nil
	end,
})
local function stopAll()
	for _, p in PLAYED do
		p.sound.IsPlaying = false
	end
end
local Controller = requireModule(controllerScript)
SHOUTS = {}
Controller.OnShout(function(model, role)
	table.insert(SHOUTS, { model = model, role = role })
end)
Controller.OnShout(function()
	error("écouteur cassé") -- n'empêche pas les autres
end)
Controller.Start()

local function members()
	local f = Workspace:FindFirstChild(CROWD.Folder)
	return if f then f:GetChildren() else {}
end
-- Le voleur `player` sort du magasin `index` avec l'objet (caméra posée devant).
local function heist(player, index)
	local x = (index - 1) * 200
	camera.CFrame = cf(vec(x, 10, 30), 0)
	player:SetAttribute("Carrying", "Legendary")
	moveTo(player, vec(x, 3, -60))
	advance(0.25)
	moveTo(player, vec(x + 2, 3, -44))
	advance(0.25)
	-- a240 : la foule se crée sur plusieurs images (Crowd.BuildPerFrame) ; on attend qu elle soit complète.
	for _ = 1, 60 do
		local s = Controller.GetStats()
		if (s.Pending or 0) == 0 then
			break
		end
		advance(0.05)
	end
end
local function animOf(m)
	local track = TRACKS[m]
	return if track then track.Animation.Name else nil
end
local function finish()
	advance(CROWD.Duration + CROWD.FadeTime + 0.3)
end

-- B1. Création étalée ---------------------------------------------------------------------------------------
local N = 2 * CROWD.PerSide
local perFrame, lastCount = {}, 0
local counter = heartbeat:Connect(function()
	local n = #members()
	if n > lastCount then
		table.insert(perFrame, n - lastCount)
	end
	lastCount = n
end)
camera.CFrame = cf(vec(0, 10, 30), 0)
alice:SetAttribute("Carrying", "Legendary")
moveTo(alice, vec(0, 3, -60))
advance(0.25)
moveTo(alice, vec(2, 3, -44))
advance(1)
counter.Disconnect()
local most = 0
for _, k in perFrame do
	most = math.max(most, k)
end
print(`MESURE plus longue image de création : {most} personne(s) sur {N}, en {#perFrame} image(s)`)
check("B1 toutes créées au bout", #members() == N, #members())
check("B1 au plus BuildPerFrame personnes par image", CROWD.BuildPerFrame ~= nil and most <= CROWD.BuildPerFrame and most >= 1, most)
check("B1 plusieurs images", #perFrame >= math.ceil(N / (CROWD.BuildPerFrame or N)), #perFrame)
local st = Controller.GetStats()
check("B1 GetStats : Pending 0, FrameMax", st.Pending == 0 and st.FrameMax == most and type(st.FrameMs) == "number", `{st.Pending} {st.FrameMax}`)
local list = members()
local shouters, photographers = {}, {}
for _, m in list do
	local track = TRACKS[m]
	local a = track and track.Animation.Name
	if a == "Cheer" or a == "Boo" or a == "Shout" then
		table.insert(shouters, m)
	elseif a == "TakePhoto" then
		table.insert(photographers, m)
	end
end
check("B1 des crieurs et des photographes", #shouters > CROWD.Sounds.Voices and #photographers > CROWD.Sounds.PhotoVoices, `{#shouters} {#photographers}`)

-- S1. Cris -----------------------------------------------------------------------------------------------------
local WANT = { Cheer = { Crowd_Cheer = true, Crowd_Clap = true }, Boo = { Crowd_Boo = true }, Shout = { Crowd_Shout = true, Crowd_Scream = true } }
table.clear(PLAYED)
local m1 = shouters[1]
TRACKS[m1]._markers.Shout:Fire()
check("S1 marqueur Shout : un son du rôle, 3D sur la racine", #PLAYED == 1 and WANT[TRACKS[m1].Animation.Name][PLAYED[1].name] == true and PLAYED[1].at == m1.HumanoidRootPart, PLAYED[1] and PLAYED[1].name)
TRACKS[m1]._markers.Shout:Fire()
check("S1 pas de relance tant que son son joue", #PLAYED == 1)
for i = 2, #shouters do
	TRACKS[shouters[i]]._markers.Shout:Fire()
end
check("S1 au plus Sounds.Voices cris à la fois", #PLAYED == CROWD.Sounds.Voices, #PLAYED)
check("S1 GetStats().Voices", Controller.GetStats().Voices == CROWD.Sounds.Voices)
stopAll()
TRACKS[m1]._markers.Shout:Fire()
check("S1 son fini : il peut crier de nouveau", #PLAYED == CROWD.Sounds.Voices + 1)
stopAll()

-- S2. Photos ---------------------------------------------------------------------------------------------------
table.clear(PLAYED)
for _, p in photographers do
	TRACKS[p]._markers.Flash:Fire()
end
local okPhoto = #PLAYED == CROWD.Sounds.PhotoVoices
for _, p in PLAYED do
	if p.name ~= "Witness_Photo" and p.name ~= "Crowd_PhotoBurst" then
		okPhoto = false
	end
end
check("S2 flash : Witness_Photo ou rafale, au plus PhotoVoices à la fois", okPhoto, #PLAYED)
local kinds = {}
for _ = 1, 40 do
	stopAll()
	TRACKS[photographers[1]]._markers.Flash:Fire()
	kinds[PLAYED[#PLAYED].name] = true
end
check("S2 parfois la rafale, surtout la photo", kinds.Witness_Photo == true and kinds.Crowd_PhotoBurst == true)
stopAll()
HAVE.Witness_Photo, HAVE.Crowd_PhotoBurst = nil, nil
local before = #PLAYED
local okMute = pcall(function()
	TRACKS[photographers[2]]._markers.Flash:Fire()
end)
local logged = false
for _, l in LOGS do
	if string.find(l, "absent de Assets/Sounds", 1, true) then
		logged = true
	end
end
check("S2 son absent : muet, sans erreur, une ligne en Studio", okMute and #PLAYED == before and logged)
HAVE.Witness_Photo, HAVE.Crowd_PhotoBurst = true, true

-- S3. Gasp à la casse ----------------------------------------------------------------------------------------
check("S3 branché sur WindowController.OnBroken", #BROKEN == 1)
table.clear(PLAYED)
local w2 = stores[2].Window
WINDOWS.S2 = { w2, stores[2] }
camera.CFrame = cf(vec(200, 10, 30), 0)
BROKEN[1]("S2", vec(200, 5, -50))
check("S3 vitrine de magasin PNJ : Crowd_Gasp sur la vitre", #PLAYED == 1 and PLAYED[1].name == "Crowd_Gasp" and PLAYED[1].at == w2)
local plot = node("Model", "Plot", map)
local door = part("Window", plot, vec(200, 5, 0), vec(10, 6, 0.5))
WINDOWS.P = { door, plot }
BROKEN[1]("P", vec(200, 5, 0))
check("S3 boutique de joueur : rien", #PLAYED == 1)
Workspace:SetAttribute("NightPhase", "Night")
BROKEN[1]("S2", vec(200, 5, -50))
check("S3 la nuit (AtNight = false) : rien", #PLAYED == 1)
Workspace:SetAttribute("NightPhase", "Day")
camera.CFrame = cf(vec(2000, 10, 30), 0)
BROKEN[1]("S2", vec(200, 5, -50))
check("S3 trop loin de la caméra : rien", #PLAYED == 1)
BROKEN[1]("inconnue", vec(0, 0, 0))
check("S3 vitrine inconnue : rien", #PLAYED == 1)

finish()
check("S4 fin : foule détruite, sons avec elle", #members() == 0 and rawget(m1, "_destroyed") == true)
check("S4 aucune erreur dans la boucle", (function()
	for _, l in LOGS do
		if string.find(l, "foule :", 1, true) or string.find(l, "contrôle des porteurs", 1, true) then
			print("   " .. l)
			return false
		end
	end
	return true
end)())

print(`banc a240 crowd : {CHECKS} vérification(s), {FAILS} échec(s)`)
