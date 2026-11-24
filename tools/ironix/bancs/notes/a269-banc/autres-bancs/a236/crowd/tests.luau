-- Banc a236, partie crowd (vague 71, L-219 point 1, L-220 point 2, L-223) : WitnessCrowdController sur un faux Roblox
-- (celui du banc a221 crowd, étendu : Accessory, Humanoid:AddAccessory, marqueurs par nom, hasard qui varie). Vrais :
-- WitnessCrowdController, Shared/WitnessGauge, Config/Witness, Config/DeepFreeze, Contract/Find. Bouchons :
-- WitnessController (PlayFlash, ReleaseFlash notés), Features, Settings (VfxReduced), ShatterController (IsLowEnd).
--   P1 porteur qui sort du volume Bounds : 2 × PerSide copies des NPC_Crowd_* (mélangées), personne devant la vitrine,
--      PerSide de chaque côté du passage (largeur de la vitrine), plus serrées en s éloignant ; au sol, tournées vers
--      le voleur, propres, racine seule ancrée, aucune collision (accessoires compris), machine d états coupée
--   P2 rôles : animation lue par son nom dans le modèle ; pancarte du bon Side pour HoldSign ; téléphone et flash au
--      marqueur Flash pour le photographe ; marqueur Shout -> OnShout ; animation ou pancarte absente : photographe
--   P3 fin (fondu, copies détruites, ReleaseFlash) ; nuit ; appareil faible (PerSideLow, MaxCrowdsLow) ; repli sur les
--      témoins sans NPC_Crowd_* ; Cooldown, caméra, sans objet ; animations réduites ; interrupteur coupé

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

-- P0. Réglages ------------------------------------------------------------------------------------------
check("P0 au moins 10 par côté (Clément), même sur appareil faible", CROWD.PerSide >= 10 and CROWD.PerSideLow >= 10)
local roleNames = {}
for _, r in CROWD.Roles do
	roleNames[r.Name] = r.Anim
end
check("P0 rôles de L-223", roleNames.Cheer == "Cheer" and roleNames.SignFor == "HoldSign" and roleNames.Boo == "Boo" and roleNames.SignAgainst == "HoldSign" and roleNames.Shouter == "Shout" and roleNames.Photographer == "TakePhoto")

-- P1. Placement ------------------------------------------------------------------------------------------
heist(alice, 1)
local list = members()
local N = 2 * CROWD.PerSide
check("P1 une foule de 2 × PerSide personnes", #list == N and Controller.GetCount() == 1, #list)
local okOutfit, outfits, firstOutfits = true, {}, {}
for index, m in list do
	local o = m:GetAttribute("Outfit")
	if type(o) ~= "string" or string.sub(o, 1, 10) ~= "NPC_Crowd_" then
		okOutfit = false
	else
		outfits[o] = true
		if index <= 3 then
			firstOutfits[o] = true
		end
	end
end
local distinct, firstDistinct = 0, 0
for _ in outfits do
	distinct += 1
end
for _ in firstOutfits do
	firstDistinct += 1
end
check("P1 copies des NPC_Crowd_* de Clément (Autre ignoré)", okOutfit and distinct == 3, distinct)
check("P1 tenues mélangées : chaque modèle une fois avant d'en revoir un", firstDistinct == 3, firstDistinct)
local half = math.clamp(10 / 2 + CROWD.PassageMargin, CROWD.PassageMin / 2, CROWD.PassageMax / 2)
local left, right = {}, {}
local okFront, okAlong, okGround, okFace, okBody, okClean = true, true, true, true, true, true
local thief = alice.Character.HumanoidRootPart.Position
for _, m in list do
	local root = m.HumanoidRootPart
	local p = root.Position
	local along, across = p.Z + 50, p.X
	-- a269 : avec Crowd.Spacing, une place trop proche recule (vers la rue ou un rang derrière) d au plus MaxPush studs.
	local push = if CROWD.Spacing and CROWD.Spacing.Enabled then CROWD.Spacing.MaxPush else 0
	if math.abs(across) < half - 1e-6 or math.abs(across) > half + CROWD.RowGap + CROWD.Jitter + push + 1e-6 then
		okFront = false
	end
	if along < CROWD.Start - CROWD.Jitter - 1e-6 or along > CROWD.Start + CROWD.Length + CROWD.Jitter + push + 1e-6 then
		okAlong = false
	end
	table.insert(if across < 0 then left else right, along)
	if not near(p.Y, 3) then
		okGround = false
	end
	local want = vec(thief.X - p.X, 0, thief.Z - p.Z).Unit
	if root.CFrame.LookVector:Dot(want) < 0.99 then
		okFace = false
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and (d.CanCollide or d.CanTouch or d.CanQuery or d.Anchored ~= (d == root)) then
			okBody = false
		end
	end
	if m.Humanoid.EvaluateStateMachine ~= false or m.Humanoid.DisplayDistanceType ~= "HumanoidDisplayDistanceType.None" then
		okBody = false
	end
	if not string.find(m.Name, "^CrowdNpc_") or m:FindFirstChild("Intrus") then
		okClean = false
	end
end
check("P1 personne devant la vitrine : tous hors du passage (demi-largeur " .. half .. ")", okFront)
check("P1 de Start à Start + Length studs devant la vitrine", okAlong)
check("P1 PerSide de chaque côté", #left == CROWD.PerSide and #right == CROWD.PerSide, `{#left}/{#right}`)
local function denser(alongs)
	table.sort(alongs)
	local n = #alongs
	local mid = math.floor(n / 2)
	local nearGap = (alongs[mid] - alongs[1]) / (mid - 1)
	local farGap = (alongs[n] - alongs[mid + 1]) / (n - mid - 1)
	return farGap < nearGap, `{nearGap} puis {farGap}`
end
local d1, why1 = denser(left)
local d2, why2 = denser(right)
check("P1 plus serrés en s'éloignant (gauche)", d1, why1)
check("P1 plus serrés en s'éloignant (droite)", d2, why2)
check("P1 posés au sol (HipHeight + demi-racine)", okGround)
check("P1 tournés vers le voleur", okFace)
check("P1 racine seule ancrée, ni collision, ni requête, ni contact (accessoires compris), machine d'états coupée", okBody)
check("P1 copies nommées CrowdNpc_, sans script", okClean)

-- P2. Rôles ------------------------------------------------------------------------------------------------
local byAnim, okSign, okPhone, okNone, ok03 = {}, true, true, true, true
local photographers, shouters = {}, {}
for _, m in list do
	local a = animOf(m)
	byAnim[a or "aucune"] = (byAnim[a or "aucune"] or 0) + 1
	local added = ACCESSORIES[m] or {}
	if a == "HoldSign" then
		local side = added[1] and added[1]:GetAttribute("Side")
		if #added ~= 1 or (side ~= "For" and side ~= "Against") then
			okSign = false
		end
	elseif a == "TakePhoto" then
		table.insert(photographers, m)
		if #added ~= 1 or added[1].Name ~= "ACC_Temoin_Telephone" or not m:FindFirstChild("FlashPoint", true) then
			okPhone = false
		end
	else
		if #added ~= 0 then
			okNone = false
		end
		if a == "Cheer" or a == "Boo" or a == "Shout" then
			table.insert(shouters, m)
		end
	end
	if m:GetAttribute("Outfit") == "NPC_Crowd_03" and a ~= "TakePhoto" then
		ok03 = false
	end
end
local kinds = 0
for _ in byAnim do
	kinds += 1
end
check("P2 chacun joue l'animation de son rôle, plusieurs rôles tirés", byAnim.aucune == nil and kinds >= 4, kinds)
check("P2 HoldSign : une pancarte Side For ou Against", okSign)
check("P2 photographe : le téléphone ACC_Temoin_Telephone (FlashPoint)", okPhone)
check("P2 Cheer, Boo, Shout : aucun accessoire", okNone)
check("P2 animation du rôle absente : photographe (NPC_Crowd_03)", ok03)
check("P2 fondu d'entrée (accessoires compris)", list[#list].Head.LocalTransparencyModifier > 0 and (function()
	for _, p in photographers do -- a240 : un photographe encore en fondu a son téléphone en fondu aussi
		if p.Head.LocalTransparencyModifier > 0 then
			return ACCESSORIES[p][1].Handle.LocalTransparencyModifier > 0
		end
	end
	return ACCESSORIES[photographers[1]][1].Handle.LocalTransparencyModifier > 0
end)())
advance(CROWD.FadeTime)
check("P2 fondu fini : visibles", list[1].Head.LocalTransparencyModifier == 0 and list[#list].Head.LocalTransparencyModifier == 0)
local before = #FLASHES
TRACKS[photographers[1]]._markers.Flash:Fire()
check("P2 photographe : flash au marqueur Flash", #FLASHES == before + 1 and FLASHES[#FLASHES].model == photographers[1])
check("P2 photographe : pas de cri branché", TRACKS[photographers[1]]._markers.Shout == nil)
check("P2 crieur : pas de flash branché", #shouters > 0 and TRACKS[shouters[1]]._markers.Flash == nil)
TRACKS[shouters[1]]._markers.Shout:Fire()
local wantRole = ({ Cheer = "Cheer", Boo = "Boo", Shout = "Shouter" })[animOf(shouters[1])]
check("P2 marqueur Shout : OnShout reçoit la personne et son rôle (écouteur cassé ignoré)", #SHOUTS == 1 and SHOUTS[1].model == shouters[1] and SHOUTS[1].role == wantRole, SHOUTS[1] and SHOUTS[1].role)
advance(CROWD.FlashMax + 0.1)
local count = {}
for _, f in FLASHES do
	count[f.model] = (count[f.model] or 0) + 1
end
check("P2 photographe à marqueur : plus de rythme de secours", count[photographers[1]] == 1, count[photographers[1]])
check("P2 les autres photographes flashent au rythme FlashMin–FlashMax", #photographers < 2 or (count[photographers[2]] or 0) >= 1)
local stats = Controller.GetStats()
check("P2 GetStats : personnes, pièces, pistes, cris", stats.Members == N and stats.Tracks == N and stats.Parts >= 2 * N and stats.Shouts == 1, `{stats.Members} {stats.Parts} {stats.Tracks} {stats.Shouts}`)
moveTo(alice, vec(60, 3, -30))
advance(CROWD.TurnInterval + 0.05)
local root1 = list[1].HumanoidRootPart
check("P2 la foule suit le voleur des yeux", root1.CFrame.LookVector:Dot(vec(60 - root1.Position.X, 0, -30 - root1.Position.Z).Unit) > 0.99)

-- P3. Fin, puis refus et variantes ---------------------------------------------------------------------------
heist(alice, 1)
check("P3 même magasin dans le Cooldown : pas de seconde foule", Controller.GetCount() == 1)
local released = #RELEASED
finish()
check("P3 fin : copies détruites, flashs oubliés, GetCrowds vide", #members() == 0 and rawget(list[1], "_destroyed") == true and #RELEASED - released == N and #Controller.GetCrowds() == 0)
alice:SetAttribute("Carrying", nil)
moveTo(alice, vec(200, 3, -60))
advance(0.25)
moveTo(alice, vec(200, 3, -40))
advance(0.25)
check("P3 sortie sans objet : pas de foule", Controller.GetCount() == 1)

Workspace:SetAttribute("NightPhase", "Night")
heist(alice, 2)
check("P3 la nuit (AtNight = false) : pas de foule", Controller.GetCount() == 1 and CROWD.AtNight == false)
Workspace:SetAttribute("NightPhase", "Day")

LOW = true
heist(alice, 2)
check("P3 appareil faible : PerSideLow de chaque côté", #members() == 2 * CROWD.PerSideLow and Controller.GetCount() == 2, #members())
local bob = newPlayer("Bob", vec(400, 3, -60))
heist(bob, 3)
check("P3 appareil faible : MaxCrowdsLow foule à la fois", #Controller.GetCrowds() == CROWD.MaxCrowdsLow and Controller.GetCount() == 2)
LOW = false
bob:SetAttribute("Carrying", nil)
finish()

-- Pancartes absentes : HoldSign devient photographe (magasin 4, hors Cooldown).
for _, s in signs do
	s.Parent = nil
end
heist(alice, 4)
local noSign = true
for _, m in members() do
	if animOf(m) == "HoldSign" then
		noSign = false
	end
end
check("P3 pas de pancarte livrée : personne ne tient HoldSign", #members() == N and noSign, #members())
finish()

-- Animations réduites : ni fondu ni flash.
localPlayer:SetAttribute("VfxEnabled", false)
heist(alice, 6)
local quiet = members()
local flashes = #FLASHES
advance(2)
check("P3 animations réduites : là tout de suite, sans flash", #quiet == N and quiet[1].Head.LocalTransparencyModifier == 0 and #FLASHES == flashes, #quiet)
localPlayer:SetAttribute("VfxEnabled", nil)
finish()

-- Voleur trop loin de la caméra.
camera.CFrame = cf(vec(1200, 10, 900), 0)
alice:SetAttribute("Carrying", "Rare")
moveTo(alice, vec(1200, 3, -60))
advance(0.25)
moveTo(alice, vec(1200, 3, -40))
advance(0.25)
check("P3 voleur trop loin de la caméra : pas de foule", #members() == 0)

-- Repli : sans NPC_Crowd_*, les copies des témoins (toutes photographes, téléphone déjà porté).
Models.Parent = nil
heist(alice, 5)
local fromW = members()
local okW = #fromW == N
for _, m in fromW do
	if animOf(m) ~= "TakePhoto" or ACCESSORIES[m] ~= nil or (TAGS[m] and TAGS[m][Gauge.Tag]) or m:GetAttribute(Gauge.StateAttribute) ~= nil then
		okW = false
	end
end
check("P3 sans NPC_Crowd_* : copies propres des témoins, photographes", okW, #fromW)
check("P3 témoin d'origine intact", TAGS[wA][Gauge.Tag] == true and #wA:FindFirstChild("FlashPoint", true):GetChildren() == 1)
finish()
for _, tags in TAGS do
	tags[Gauge.Tag] = nil
end
advance(CROWD.Cooldown)
heist(alice, 1)
local logged = false
for _, l in LOGS do
	if string.find(l, "aucun témoin", 1, true) then
		logged = true
	end
end
check("P3 ni NPC_Crowd_* ni témoin : pas de foule, une ligne en Studio", #members() == 0 and logged)

-- Interrupteur coupé : Start ne branche rien.
local loaded = cache[controllerScript]
cache[controllerScript] = nil
FEATURES.WitnessCrowd = false
local beats = #heartbeat._c
local Off = requireModule(controllerScript)
Off.Start()
check("P3 interrupteur coupé : rien n'est branché", #heartbeat._c == beats and Off ~= loaded)

check("P4 aucune erreur dans la boucle", (function()
	for _, l in LOGS do
		if string.find(l, "foule :", 1, true) or string.find(l, "contrôle des porteurs", 1, true) then
			print("   " .. l)
			return false
		end
	end
	return true
end)())

print(`banc a236 crowd : {CHECKS} vérification(s), {FAILS} échec(s)`)
