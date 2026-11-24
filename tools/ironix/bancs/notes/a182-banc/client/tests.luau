-- Banc a182, partie client (2026-11-15, vague 56, L-172) : le flash des photos dans WitnessController, sur un faux
-- Roblox minimal à lui. Vrais : WitnessController, Shared/WitnessGauge, Config/Witness, Config/DeepFreeze.
--   C1 « le flash part du téléphone » : à la première hausse de WitnessFlash, les enfants de Flash (Light, Glare, Glint,
--      Specks) copiés dans le FlashPoint du Handle de ACC_Temoin_Telephone ; Emit(EmitCount) ; Light allumée LightTime s ;
--      FX_Witness_Flash sans Part Root
--   C2 copies faites une seule fois ; jamais deux flashs à moins de Duration s
--   C3 sans FlashPoint : Attachment du code au Handle, Forward stud devant ; sans téléphone : à la RightHand ; sans FX : rien
--   C4 témoin retiré (streaming) : copies et Attachment du code détruits, plus d'écoute ; revenu : refait ;
--      téléphone changé : refait dans le nouveau FlashPoint

NOW = 0
local TIMERS = {}

-- Valeurs -----------------------------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V)
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	return nil
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
local FVector3 = { new = vec, zero = vec(0, 0, 0) }
local FCFrame = {
	lookAt = function(from, to)
		return { Position = from, LookVector = (to - from).Unit }
	end,
	new = function(p)
		return { Position = p, LookVector = vec(0, 0, -1) }
	end,
}
local FColor3 = {
	fromHex = function(h)
		return { Hex = h }
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
local CLASSES = { Part = "BasePart", BasePart = "PVInstance", Model = "PVInstance", PointLight = "Light" }
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
	local o = setmetatable({ ClassName = class, Name = name, _children = {}, _attrs = {}, _signals = {} }, I)
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
	local s = self._signals[k]
	if s then
		s:Fire()
	end
end
function methods.GetAttributeChangedSignal(self, k)
	self._signals[k] = self._signals[k] or newSignal()
	return self._signals[k]
end
function methods.Destroy(self)
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function methods.Emit(self, n)
	rawset(self, "_emitted", (rawget(self, "_emitted") or 0) + n)
	table.insert(EMITS, { emitter = self, count = n, t = NOW })
end
function methods.Clone(self)
	local copy = node(self.ClassName, self.Name)
	for k, v in self do
		if k ~= "_children" and k ~= "_parent" and k ~= "_attrs" and k ~= "_signals" and k ~= "ClassName" and k ~= "Name" then
			rawset(copy, k, v)
		end
	end
	for k, v in self._attrs do
		copy._attrs[k] = v
	end
	for _, child in self._children do
		child:Clone().Parent = copy
	end
	return copy
end
EMITS = {}

-- Services ----------------------------------------------------------------------------------------
local game = node("DataModel", "game")
local Workspace = node("Workspace", "Workspace", game)
function Workspace.GetServerTimeNow()
	return NOW + 1000
end
local ReplicatedStorage = node("ReplicatedStorage", "ReplicatedStorage", game)
local localPlayer = node("Player", "Alice")
node("PlayerGui", "PlayerGui", localPlayer)
local Players = { LocalPlayer = localPlayer }
local added, removed = newSignal(), newSignal()
local TAGGED = {}
local CollectionService = {
	GetInstanceAddedSignal = function()
		return added
	end,
	GetInstanceRemovedSignal = function()
		return removed
	end,
	GetTagged = function()
		return table.clone(TAGGED)
	end,
}
local heartbeat = newSignal()
local RunService = {
	Heartbeat = heartbeat,
	IsStudio = function()
		return true
	end,
}
local TweenService = {
	GetValue = function(_, a)
		return a
	end,
}
local SERVICES = {
	CollectionService = CollectionService,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	TweenService = TweenService,
	Workspace = Workspace,
}
function game.GetService(_, name)
	return assert(SERVICES[name], name)
end
local fakeTask = {
	delay = function(t, fn)
		table.insert(TIMERS, { at = NOW + t, fn = fn })
	end,
}
local LOGS = {}

-- Modules ------------------------------------------------------------------------------------------
local Shared = node("Folder", "Shared", ReplicatedStorage)
local Config = node("Folder", "Config", Shared)
local cache = {}
local function module(name, parent, key)
	local m = node("ModuleScript", name, parent)
	rawset(m, "_key", key)
	return m
end
module("Witness", Config, "shared/Config/Witness.luau")
module("DeepFreeze", Config, "shared/Config/DeepFreeze.luau")
module("WitnessGauge", Shared, "shared/WitnessGauge.luau")
local controllerScript = module("WitnessController", node("Folder", "Controllers"), "client/Controllers/WitnessController.luau")
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
		Color3 = FColor3,
		UDim2 = { new = function() return {} end },
		Enum = FEnum,
		Instance = { new = function(c) return node(c, c) end },
		task = fakeTask,
		os = setmetatable({ clock = function() return NOW end }, { __index = os }),
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
		for _, timer in table.clone(TIMERS) do
			if timer.at <= NOW + 1e-9 then
				table.remove(TIMERS, table.find(TIMERS, timer))
				timer.fn()
			end
		end
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
local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- Monde ----------------------------------------------------------------------------------------------
local Witness = requireModule(Config.Witness)
local Gauge = requireModule(Shared.WitnessGauge)
local PHOTO = Witness.Photo
local Assets = node("Folder", "Assets", ReplicatedStorage)
local FXFolder = node("Folder", "FX", Assets)
-- FX_Witness_Flash sans Part Root (Clément : elle ne sert plus au code) : Flash directement dans le modèle.
local fx = node("Model", "FX_Witness_Flash", FXFolder)
fx._attrs.LightTime = 0.1
fx._attrs.Duration = 0.5
local source = node("Attachment", "Flash", fx)
node("PointLight", "Light", source, { Enabled = false, Brightness = 2, Range = 10 })
for name, count in { Glare = 1, Glint = 1, Specks = 6 } do
	local e = node("ParticleEmitter", name, source, { Rate = 0 })
	e._attrs.EmitCount = count
end

local function newWitness(name, position, phone)
	local m = node("Model", name, Workspace)
	node("Part", "HumanoidRootPart", m, { Position = position, CFrame = { Position = position, LookVector = vec(0, 0, -1) } })
	node("Part", "RightHand", m, { Position = position + vec(1, 0, -0.5) })
	if phone then
		local acc = node("Accessory", "ACC_Temoin_Telephone", m)
		local handle = node("Part", "Handle", acc, { Position = position + vec(0.8, 1, -0.6) })
		if phone == "point" then
			node("Attachment", "FlashPoint", handle)
		end
	end
	m._attrs[Gauge.StateAttribute] = "Stroll"
	table.insert(TAGGED, m)
	return m
end
local w1 = newWitness("NPC_Witness_Z1_01", vec(10, 3, 0), "point")
local w2 = newWitness("NPC_Witness_Z1_02", vec(30, 3, 0), "handle")
local w3 = newWitness("NPC_Witness_Z1_03", vec(50, 3, 0), nil)

local Controller = requireModule(controllerScript)
Controller.Start()

local function bump(model)
	model:SetAttribute(Gauge.FlashAttribute, (model:GetAttribute(Gauge.FlashAttribute) or 0) + 1)
end
local function pointOf(model)
	return model:FindFirstChild("FlashPoint", true) or model:FindFirstChild(PHOTO.CodePoint, true)
end
local function emitted(point, name)
	local e = point and point:FindFirstChild(name)
	return e and (rawget(e, "_emitted") or 0) or 0
end
local function names(point)
	local list = {}
	for _, child in point._children do
		table.insert(list, child.Name)
	end
	table.sort(list)
	return table.concat(list, ",")
end
local function inWorkspace()
	local n = 0
	for _, child in Workspace._children do
		if child.Name == "FX_Witness_Flash" then
			n += 1
		end
	end
	return n
end

-- C1 ---------------------------------------------------------------------------------------------------
local point1 = w1.ACC_Temoin_Telephone.Handle.FlashPoint
do
	check("C1 rien avant le premier flash", #point1._children == 0)
	bump(w1)
	check("C1 enfants de Flash copiés dans le FlashPoint du téléphone", names(point1) == "Glare,Glint,Light,Specks", names(point1))
	check("C1 Emit(EmitCount) : Glare 1, Glint 1, Specks 6", emitted(point1, "Glare") == 1 and emitted(point1, "Glint") == 1 and emitted(point1, "Specks") == 6)
	check("C1 Light allumée", point1.Light.Enabled == true)
	advance(0.05)
	check("C1 encore allumée à 0,05 s", point1.Light.Enabled == true)
	advance(0.1)
	check("C1 éteinte après LightTime", point1.Light.Enabled == false)
	check("C1 rien dans Workspace, gabarit de Clément intact", inWorkspace() == 0 and fx.Parent == FXFolder and #source._children == 4 and rawget(source.Specks, "_emitted") == nil and source.Light.Enabled == false)
	check("C1 FlashPoint de Clément pas déplacé", rawget(point1, "WorldPosition") == nil)
	check("C1 compteur du contrôleur", (select(1, Controller.GetFlashes())) == 1)
end

-- C2 ---------------------------------------------------------------------------------------------------
do
	advance(0.8) -- 0,95 s après le premier
	bump(w1)
	check("C2 copies faites une fois : mêmes enfants, second flash", names(point1) == "Glare,Glint,Light,Specks" and emitted(point1, "Specks") == 12)
	advance(0.3)
	bump(w1)
	check("C2 à 0,3 s (moins que Duration) : pas de flash", emitted(point1, "Specks") == 12)
	advance(0.3)
	bump(w1)
	check("C2 à 0,6 s : flash", emitted(point1, "Specks") == 18)
end

-- C3 ---------------------------------------------------------------------------------------------------
do
	bump(w2)
	local handle = w2.ACC_Temoin_Telephone.Handle
	local made = handle:FindFirstChild(PHOTO.CodePoint)
	local want = handle.Position + vec(0, 0, -1) * PHOTO.Forward
	check("C3 sans FlashPoint : Attachment du code au Handle", made ~= nil and made.ClassName == "Attachment" and names(made) == "Glare,Glint,Light,Specks")
	check("C3 posé Forward stud devant le témoin", made and made.WorldPosition and near(made.WorldPosition.X, want.X) and near(made.WorldPosition.Y, want.Y) and near(made.WorldPosition.Z, want.Z))
	check("C3 il flashe", emitted(made, "Specks") == 6)
	bump(w3)
	local hand = w3.RightHand
	local hm = hand:FindFirstChild(PHOTO.CodePoint)
	check("C3 sans téléphone : à la RightHand, sans décalage", hm ~= nil and emitted(hm, "Specks") == 6 and rawget(hm, "WorldPosition") == nil)
	local _, rigs = Controller.GetFlashes()
	check("C3 trois témoins équipés", rigs == 3)
	advance(1)
	fx.Parent = nil
	local before = emitted(point1, "Specks")
	bump(w1)
	check("C3 FX_Witness_Flash absent : pas de flash, une ligne", emitted(point1, "Specks") == before and (function()
		for _, l in LOGS do
			if string.find(l, "FX_Witness_Flash absent", 1, true) then
				return true
			end
		end
		return false
	end)())
	fx.Parent = FXFolder
end

-- C4 ---------------------------------------------------------------------------------------------------
do
	removed:Fire(w1)
	removed:Fire(w2)
	check("C4 témoin retiré : copies détruites dans le FlashPoint", #point1._children == 0)
	check("C4 Attachment du code détruit", w2.ACC_Temoin_Telephone.Handle:FindFirstChild(PHOTO.CodePoint) == nil)
	advance(1)
	bump(w1)
	check("C4 plus d'écoute", #point1._children == 0)
	added:Fire(w1)
	bump(w1)
	check("C4 revenu : refait", names(point1) == "Glare,Glint,Light,Specks" and emitted(point1, "Specks") == 6)
	advance(1)
	point1.Parent = nil -- téléphone changé
	local fresh = node("Attachment", "FlashPoint", w1.ACC_Temoin_Telephone.Handle)
	bump(w1)
	check("C4 nouveau FlashPoint : flash refait dedans", names(fresh) == "Glare,Glint,Light,Specks" and emitted(fresh, "Specks") == 6)
end

print(`banc a182 client : {CHECKS} vérification(s), {FAILS} échec(s)`)
