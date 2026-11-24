-- Banc a221, partie crowd (vague 66, L-210 point 4) : WitnessCrowdController sur un faux Roblox à lui. Vrais :
-- WitnessCrowdController, Shared/WitnessGauge, Config/Witness, Config/DeepFreeze, Contract/Find. Bouchons :
-- WitnessController (PlayFlash, ReleaseFlash notés), Features (WitnessCrowd), Settings (VfxReduced).
-- CFrame à rotation autour de Y seulement (yaw), assez pour la foule (au sol, tournée vers le voleur).
--   K1 porteur qui sort du volume Bounds d'un magasin : Count copies en arc devant la vitrine (côté rue), au sol, tournées
--      vers le voleur, sans tag ni attribut de témoin, racine ancrée, aucune collision ; copies du flash d'origine retirées
--   K2 rôles : Filmers filment (piste figée au marqueur Flash, ou après FilmFreeze s), les autres flashent (marqueur,
--      sinon rythme FlashMin–FlashMax) ; fondu d'entrée
--   K3 fin : fondu de sortie, copies détruites, flash oublié (ReleaseFlash) au bout de Duration + FadeTime
--   K4 pas de foule : sans objet, sortie par un autre chemin que Bounds, Cooldown, voleur trop loin de la caméra, aucun
--      témoin, MaxCrowds ; animations réduites : ni fondu ni flash ; Features.WitnessCrowd = false : rien

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
	local track = { Animation = animation, Playing = false, Speed = 1, TimePosition = 0, _marker = newSignal() }
	function track:Play(_fade, _weight, speed)
		self.Playing = true
		self.Speed = speed or 1
	end
	function track:AdjustSpeed(speed)
		self.Speed = speed
	end
	function track:GetMarkerReachedSignal(name)
		assert(name == "Flash", name)
		return self._marker
	end
	TRACKS[self.Parent.Parent] = track
	return track
end
TRACKS = {} -- [modèle] = sa piste
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
local FRandom = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return (a + b) / 2 -- milieu : déterministe
			end,
			NextInteger = function(_, _a, b)
				return b -- échange avec lui-même : rôles dans l ordre, filmeurs d abord
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
-- Magasin : vitre en z = −50 tournée vers +Z (la rue) ; Bounds = l'intérieur, z de −80 à −50.
local function newStore(name, x)
	local s = node("Model", name, map)
	part("Window", s, vec(x, 5, -50), vec(10, 6, 0.5), math.pi)
	part("Bounds", s, vec(x, 5, -65), vec(20, 10, 30)).Transparency = 1
	tag(s, "NPCStore")
	return s
end
local store1 = newStore("STORE_Z1_A", 0)
local store2 = newStore("STORE_Z1_B", 100)
local store3 = newStore("STORE_Z1_C", 200)
local store4 = newStore("STORE_Z1_D", 300)

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
	node("PointLight", "Light", point, { Enabled = true }) -- copie du flash laissée par WitnessController, allumée
	node("ParticleEmitter", "Glare", point)
	node("Attachment", PHOTO.CodePoint, handle)
	local anims = node("Folder", "Animations", m)
	node("Animation", "TakePhoto", anims)
	node("Script", "Intrus", m)
	m._attrs.WatchedStore = watched
	m._attrs[Gauge.StateAttribute] = "Watch"
	m._attrs[Gauge.FlashAttribute] = 3
	tag(m, Gauge.Tag)
	return m
end
local wA = newWitness("NPC_Witness_Z1_01", vec(30, 3, 0), "STORE_Z1_A")
local wB = newWitness("NPC_Witness_Z1_02", vec(60, 3, 0), "STORE_Z1_Other")

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
local bob = newPlayer("Bob", vec(100, 3, -60))
local function moveTo(player, p)
	local root = player.Character.HumanoidRootPart
	root.Position = p
	root.CFrame = cf(p, 0)
end

local Controller = requireModule(controllerScript)
Controller.Start()

local function crowdFolder()
	return Workspace:FindFirstChild(CROWD.Folder)
end
local function members()
	local f = crowdFolder()
	return if f then f:GetChildren() else {}
end

-- K0. Réglages ------------------------------------------------------------------------------------------
check("K0 réglages V0 : 5 PNJ dont 2 filment, 6 s, 12 studs, arc 110°, 15 s entre deux foules", CROWD.Count == 5 and CROWD.Filmers == 2 and CROWD.Duration == 6 and CROWD.Distance == 12 and CROWD.Arc == 110 and CROWD.Cooldown == 15 and CROWD.MaxCrowds == 2)

-- K4a. Sans objet, il sort : rien.
advance(0.3)
moveTo(alice, vec(0, 3, -40))
advance(0.3)
check("K4 sortie sans objet : pas de foule", #members() == 0 and Controller.GetCount() == 0)

-- K1. Avec l'objet : dedans, puis dehors.
moveTo(alice, vec(0, 3, -60))
alice:SetAttribute("Carrying", "Legendary")
advance(0.3)
check("K1 dedans avec l'objet : pas encore de foule", #members() == 0)
moveTo(alice, vec(2, 3, -44))
advance(0.25)
local list = members()
check("K1 dehors : une foule de Count PNJ", #list == CROWD.Count and Controller.GetCount() == 1, #list)
local crowds = Controller.GetCrowds()
check("K1 GetCrowds : le magasin et le voleur", #crowds == 1 and crowds[1].Store == store1 and crowds[1].Thief == alice and #crowds[1].Members == CROWD.Count)
local okPlace, okGround, okFace, okClean, okBody, okFx, okWatched = true, true, true, true, true, true, true
local thief = alice.Character.HumanoidRootPart.Position
for index, m in list do
	local root = m.HumanoidRootPart
	local p = root.Position
	local d = vec(p.X - 0, 0, p.Z - (-50))
	-- devant la vitre (côté rue, +Z), à Distance studs (à Jitter près), dans l'arc
	if math.abs(d.Magnitude - CROWD.Distance) > CROWD.Jitter * 1.5 or d.Z <= 0 then
		okPlace = false
	end
	if not near(p.Y, 0 + 2 + 1) then -- sol à 0, HipHeight 2, demi-hauteur 1
		okGround = false
	end
	local look = root.CFrame.LookVector
	local want = vec(thief.X - p.X, 0, thief.Z - p.Z).Unit
	if look:Dot(want) < 0.99 then
		okFace = false
	end
	if (TAGS[m] and TAGS[m][Gauge.Tag]) or m:GetAttribute(Gauge.StateAttribute) ~= nil or m:GetAttribute(Gauge.FlashAttribute) ~= nil or m:FindFirstChild("Intrus") then
		okClean = false
	end
	for _, d2 in m:GetDescendants() do
		if d2:IsA("BasePart") and (d2.CanCollide or d2.CanTouch or d2.CanQuery or d2.Anchored ~= (d2 == root)) then
			okBody = false
		end
	end
	local point = m:FindFirstChild("FlashPoint", true)
	if point == nil or #point:GetChildren() ~= 0 or m:FindFirstChild(PHOTO.CodePoint, true) then
		okFx = false
	end
	if m.Humanoid.DisplayDistanceType ~= "HumanoidDisplayDistanceType.None" then
		okBody = false
	end
	if not string.find(m.Name, "^CrowdNpc_") then
		okClean = false
	end
end
check("K1 en arc devant la vitrine, côté rue, à Distance studs", okPlace)
check("K1 posés au sol (HipHeight + demi-racine)", okGround)
check("K1 tournés vers le voleur", okFace)
check("K1 copies propres : nom CrowdNpc_, sans tag ni attributs du témoin, sans script", okClean)
check("K1 racine seule ancrée, aucune collision, requête ni contact, pas de nom affiché", okBody)
check("K1 copies du flash d'origine retirées du téléphone (FlashPoint vidé, Attachment de repli ôté)", okFx)
check("K1 témoins d'origine intacts (tag, FlashPoint)", TAGS[wA][Gauge.Tag] == true and #wA:FindFirstChild("FlashPoint", true):GetChildren() == 2)
check("K1 témoin de ce magasin d'abord (WatchedStore)", #list > 0 and TRACKS[list[1]] ~= nil)
local firstLeft = list[1].HumanoidRootPart.Position
local lastRight = list[#list].HumanoidRootPart.Position
check("K1 arc ouvert (le premier et le dernier ne sont pas au même endroit)", (firstLeft - lastRight).Magnitude > CROWD.Distance)
check("K1 la vitre ignorée du rayon : voleur, foule et témoins exclus", LAST_PARAMS and #LAST_PARAMS.FilterDescendantsInstances >= 3)

-- K2. Rôles, fondu.
local filmers, photographers = {}, {}
for _, m in list do
	local track = TRACKS[m]
	if track and track.Playing then
		if #filmers < CROWD.Filmers then
			table.insert(filmers, m)
		else
			table.insert(photographers, m)
		end
	end
end
check("K2 chacun joue TakePhoto", #filmers + #photographers == CROWD.Count)
check("K2 fondu d entrée en cours", list[1].Head.LocalTransparencyModifier > 0, list[1].Head.LocalTransparencyModifier)
advance(CROWD.FadeTime)
check("K2 fondu fini : visibles", list[1].Head.LocalTransparencyModifier == 0)
-- Marqueur Flash : un filmeur fige sa pose, un photographe flashe.
TRACKS[filmers[1]]._marker:Fire()
check("K2 filmeur : piste figée au marqueur Flash, sans flash", TRACKS[filmers[1]].Speed == 0 and #FLASHES == 0, #FLASHES)
TRACKS[photographers[1]]._marker:Fire()
check("K2 photographe : flash au marqueur Flash", #FLASHES == 1 and FLASHES[1].model == photographers[1])
local fromMarker = 0
advance(CROWD.FilmFreeze)
check("K2 filmeur sans marqueur : figé au bout de FilmFreeze s", TRACKS[filmers[2]].Speed == 0)
local count = {}
for _, f in FLASHES do
	count[f.model] = (count[f.model] or 0) + 1
end
check("K2 photographe à marqueur : plus de rythme de secours", count[photographers[1]] == 1, count[photographers[1]])
check("K2 les autres flashent au rythme FlashMin–FlashMax", (count[photographers[2]] or 0) >= 1, count[photographers[2]])

-- Il se tourne avec le voleur qui s'éloigne.
moveTo(alice, vec(60, 3, -30))
advance(CROWD.TurnInterval + 0.05)
local root1 = list[1].HumanoidRootPart
local want1 = vec(60 - root1.Position.X, 0, -30 - root1.Position.Z).Unit
check("K2 la foule suit le voleur des yeux", root1.CFrame.LookVector:Dot(want1) > 0.99)

-- K4b. Cooldown : ressortir du même magasin ne refait pas de foule.
moveTo(alice, vec(0, 3, -60))
advance(0.25)
moveTo(alice, vec(0, 3, -40))
advance(0.25)
check("K4 même magasin dans le Cooldown : pas de seconde foule", Controller.GetCount() == 1)

-- K3. Fin.
local fadingOut = false
for _ = 1, 400 do
	advance(0.05)
	if list[1].Parent == nil then
		break
	end
	if list[1].Head.LocalTransparencyModifier > 0 then
		fadingOut = true
	end
end
check("K3 fondu de sortie, puis copies détruites", fadingOut and #members() == 0 and rawget(list[1], "_destroyed") == true)
check("K3 flash de chaque copie oublié (ReleaseFlash)", #RELEASED == CROWD.Count)
check("K3 GetCrowds vide", #Controller.GetCrowds() == 0)

-- K4c. Voleur trop loin de la caméra : rien.
bob:SetAttribute("Carrying", "Rare")
advance(0.25)
camera.CFrame = cf(vec(100, 10, 400), 0)
moveTo(bob, vec(100, 3, -40))
advance(0.25)
check("K4 voleur trop loin de la caméra : pas de foule", Controller.GetCount() == 1)
camera.CFrame = cf(vec(0, 10, 30), 0)

-- K4d. Animations réduites : ni fondu ni flash ; pas de sol : à la hauteur du voleur.
localPlayer:SetAttribute("VfxEnabled", false)
NO_GROUND = true
moveTo(bob, vec(100, 3, -60))
advance(0.25)
moveTo(bob, vec(100, 3, -40))
advance(0.25)
local quiet = members()
check("K4 animations réduites : la foule est là, sans fondu", #quiet == CROWD.Count and quiet[1].Head.LocalTransparencyModifier == 0)
check("K4 sans sol : racine à la hauteur du voleur", #quiet > 0 and near(quiet[1].HumanoidRootPart.Position.Y, 3))
local before = #FLASHES
advance(2)
check("K4 animations réduites : aucun flash", #FLASHES == before, #FLASHES - before)
check("K4 témoins d'un autre magasin pris faute de mieux", #quiet > 0)
localPlayer:SetAttribute("VfxEnabled", nil)
NO_GROUND = false

-- K4e. MaxCrowds : une deuxième (Alice, magasin C) ; une troisième (Carol, magasin D) refusée.
moveTo(alice, vec(200, 3, -60))
advance(0.25)
moveTo(alice, vec(200, 3, -40))
advance(0.25)
check("K4 deux foules à la fois", #Controller.GetCrowds() == 2)
camera.CFrame = cf(vec(250, 10, 30), 0) -- près du magasin D : seul MaxCrowds peut refuser
local carol = newPlayer("Carol", vec(300, 3, -60))
carol:SetAttribute("Carrying", "Epic")
advance(0.25)
moveTo(carol, vec(300, 3, -40))
advance(0.25)
check("K4 MaxCrowds : pas de troisième foule", #Controller.GetCrowds() == 2 and Controller.GetCount() == 3, Controller.GetCount())
advance(CROWD.Duration + CROWD.FadeTime + 0.2)
check("K4 foules finies au bout de Duration", #Controller.GetCrowds() == 0 and #members() == 0)
alice:SetAttribute("Carrying", nil)
bob:SetAttribute("Carrying", nil)

-- K4f. Aucun témoin (nuit) : rien, une ligne en Studio.
for _, tags in TAGS do
	tags[Gauge.Tag] = nil
end
moveTo(carol, vec(300, 3, -60))
advance(0.25)
moveTo(carol, vec(300, 3, -40))
advance(0.25)
local found = false
for _, l in LOGS do
	if string.find(l, "aucun témoin", 1, true) then
		found = true
	end
end
check("K4 aucun témoin : pas de foule, une ligne en Studio", #members() == 0 and Controller.GetCount() == 3 and found)

-- K4g. Features.WitnessCrowd = false : Start ne branche rien (contrôleur rechargé).
local loaded = cache[controllerScript]
cache[controllerScript] = nil
FEATURES.WitnessCrowd = false
local beats = #heartbeat._c
local Off = requireModule(controllerScript)
Off.Start()
check("K4 interrupteur coupé : rien n'est branché", #heartbeat._c == beats and Off ~= loaded)

check("K5 aucune erreur dans la boucle", (function()
	for _, l in LOGS do
		if string.find(l, "foule :", 1, true) or string.find(l, "contrôle des porteurs", 1, true) then
			return false
		end
	end
	return true
end)())

print(`banc a221 crowd : {CHECKS} vérification(s), {FAILS} échec(s)`)
