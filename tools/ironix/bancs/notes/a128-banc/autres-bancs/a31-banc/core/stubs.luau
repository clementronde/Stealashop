--!nocheck
-- Copie par a31 (vague 11) des bouchons d'a22 (a22-banc/core/stubs.luau), complétés (lignes marquées
-- « a31 ») : CFrame.Angles sur les trois axes, UpVector et RightVector, classe Decal, service
-- ContentProvider (préchargements notés dans PRELOADS).
-- Banc hors Studio de l'agent a22 (catalogue v2, migration, ContractChecker, ItemIdleController), sur la
-- base des bouchons d'a14 (DisplayService), complétés par a22 (lignes marquées « a22 »). Bouchons Roblox
-- minimalistes, sur le modèle du banc de a08 : temps simulé, un seul VM, arbre
-- d'instances partagé entre « serveur » et « client » (réplication parfaite et instantanée).
-- Les propriétés écrites doivent exister dans PROPS : une faute de frappe dans le code lève une
-- erreur, comme dans Roblox (« X is not a valid member of … »).

SOURCES = {}
FAILS = 0
CHECKS = 0
LOG = {} -- { side, kind, text }
PRELOADS = {} -- a31 : appels de ContentProvider:PreloadAsync { side, list }

---------------------------------------------------------------- temps et tâches
local simTime = 0
local queue = {}
local seq = 0
local function schedule(t, co, ...)
	seq += 1
	table.insert(queue, { t = t, seq = seq, co = co, args = table.pack(...) })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		FAILS += 1
		print("ERREUR dans une tâche : " .. tostring(err))
		print(debug.traceback(co))
	end
end
taskLib = {}
function taskLib.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, ...)
	return co
end
function taskLib.defer(f, ...)
	local co = coroutine.create(f)
	schedule(simTime, co, ...)
	return co
end
function taskLib.delay(d, f, ...)
	local co = coroutine.create(f)
	schedule(simTime + (d or 0), co, ...)
	return co
end
function taskLib.wait(d)
	local co = coroutine.running()
	local start = simTime
	schedule(simTime + math.max(d or 0, 1 / 60), co)
	coroutine.yield()
	return simTime - start
end
local function runQueue(target)
	while true do
		local best, bestIndex = nil, nil
		for i, e in queue do
			if e.t <= target and (best == nil or e.t < best.t or (e.t == best.t and e.seq < best.seq)) then
				best, bestIndex = e, i
			end
		end
		if best == nil then
			break
		end
		table.remove(queue, bestIndex)
		simTime = math.max(simTime, best.t)
		resume(best.co, table.unpack(best.args, 1, best.args.n))
	end
end
function now()
	return simTime
end

---------------------------------------------------------------- Vector3
Vector3 = {}
V3MT = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3MT)
end
V3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	error("Vector3 : membre inconnu " .. tostring(k), 2)
end
V3MT.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3MT.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3MT.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3MT.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3MT.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3MT.__tostring = function(a)
	return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)

---------------------------------------------------------------- CFrame (rotations quelconques)
CFrame = {}
CFMT = { __type = "CFrame" }
local function cf(p, r)
	return setmetatable({ p = p, r = r }, CFMT)
end
local IDENTITY_R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mulRV(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function mulRtV(r, v)
	return v3(r[1] * v.X + r[4] * v.Y + r[7] * v.Z, r[2] * v.X + r[5] * v.Y + r[8] * v.Z, r[3] * v.X + r[6] * v.Y + r[9] * v.Z)
end
local function mulRR(a, b)
	local out = {}
	for i = 0, 2 do
		for j = 0, 2 do
			out[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return out
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CFMT.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "LookVector" then
		return v3(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "UpVector" then -- a31
		return v3(c.r[2], c.r[5], c.r[8])
	elseif k == "RightVector" then -- a31
		return v3(c.r[1], c.r[4], c.r[7])
	elseif k == "Rotation" then
		return cf(v3(0, 0, 0), c.r)
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			return mulRtV(self.r, v - self.p)
		end
	elseif k == "PointToWorldSpace" then
		return function(self, v)
			return self.p + mulRV(self.r, v)
		end
	elseif k == "Inverse" then
		return function(self)
			local rt = transpose(self.r)
			return cf(-mulRV(rt, self.p), rt)
		end
	elseif k == "ToObjectSpace" then
		return function(self, other)
			return self:Inverse() * other
		end
	end
	error("CFrame : membre inconnu " .. tostring(k), 2)
end
CFMT.__mul = function(a, b)
	if getmetatable(b) == V3MT then
		return a.p + mulRV(a.r, b)
	end
	return cf(a.p + mulRV(a.r, b.p), mulRR(a.r, b.r))
end
CFMT.__tostring = function(c)
	return "CFrame" .. tostring(c.p)
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cf(x, IDENTITY_R)
	end
	return cf(v3(x or 0, y or 0, z or 0), IDENTITY_R)
end
-- a31 : les trois axes, comme Roblox (CFrame.Angles = fromEulerAnglesXYZ : Rx × Ry × Rz). Le code
-- ne tourne qu'autour de Y ; les autres axes servent au banc pour orienter des pivots.
function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx or 0), math.sin(rx or 0)
	local cy, sy = math.cos(ry or 0), math.sin(ry or 0)
	local cz, sz = math.cos(rz or 0), math.sin(rz or 0)
	local x = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	if (rx or 0) == 0 and (rz or 0) == 0 then
		return cf(v3(0, 0, 0), y) -- exactement comme le bouchon d'a22 pour une rotation en Y
	end
	return cf(v3(0, 0, 0), mulRR(mulRR(x, y), z))
end
CFrame.identity = CFrame.new(0, 0, 0)

---------------------------------------------------------------- autres types de valeurs
local C3MT = { __type = "Color3" }
C3MT.__index = function(c, k)
	if k == "Lerp" then
		return function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	elseif k == "ToHex" then
		return function(a)
			return string.format("%02X%02X%02X", math.round(a.R * 255), math.round(a.G * 255), math.round(a.B * 255))
		end
	end
	error("Color3 : membre inconnu " .. tostring(k), 2)
end
C3MT.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3MT)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
function Color3.fromHex(hex)
	hex = string.gsub(hex, "#", "")
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	if m == 0 then
		return Color3.new(v, t, p)
	elseif m == 1 then
		return Color3.new(q, v, p)
	elseif m == 2 then
		return Color3.new(p, v, t)
	elseif m == 3 then
		return Color3.new(p, q, v)
	elseif m == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end

local function valueType(name, fields)
	local mt = { __type = name }
	mt.__index = mt
	return function(...)
		local t = fields(...)
		return setmetatable(t, mt)
	end
end
NumberRange = { new = valueType("NumberRange", function(a, b)
	return { Min = a, Max = b or a }
end) }
NumberSequenceKeypoint = { new = valueType("NumberSequenceKeypoint", function(t, v)
	return { Time = t, Value = v }
end) }
NumberSequence = { new = valueType("NumberSequence", function(a, b)
	if type(a) == "table" then
		return { Keypoints = a }
	end
	return { Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } }
end) }
ColorSequenceKeypoint = { new = valueType("ColorSequenceKeypoint", function(t, c)
	return { Time = t, Value = c }
end) }
ColorSequence = { new = valueType("ColorSequence", function(a, b)
	if getmetatable(a) == C3MT then
		return { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } }
	end
	return { Keypoints = a }
end) }
UDim2 = {
	fromScale = valueType("UDim2", function(x, y)
		return { XScale = x, YScale = y, XOffset = 0, YOffset = 0 }
	end),
	new = valueType("UDim2", function(xs, xo, ys, yo)
		return { XScale = xs, XOffset = xo, YScale = ys, YOffset = yo }
	end),
}
Font = { fromEnum = valueType("Font", function(e)
	return { Family = e }
end) }
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return `Enum.{enumName}.{item}`
			end,
		})
	end,
})

---------------------------------------------------------------- signaux
local SignalMT = { __type = "RBXScriptSignal" }
SignalMT.__index = SignalMT
function newSignal()
	return setmetatable({ handlers = {}, waiting = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	local handlers = self.handlers
	local conn = { Connected = true }
	conn.fn = fn
	function conn.Disconnect(c)
		c.Connected = false
		local i = table.find(handlers, c)
		if i then
			table.remove(handlers, i)
		end
	end
	table.insert(handlers, conn)
	return conn
end
function SignalMT:Fire(...)
	for _, c in table.clone(self.handlers) do
		if c.Connected then
			taskLib.spawn(c.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in waiting do
		resume(co, ...)
	end
end
function SignalMT:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

HEARTBEAT = newSignal()
-- Avance le temps de `seconds`, image par image (Heartbeat à chaque image).
function step(seconds, fps)
	local dt = 1 / (fps or 30)
	local frames = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, frames do
		local target = simTime + dt
		runQueue(target)
		simTime = target
		HEARTBEAT:Fire(dt)
	end
	runQueue(simTime)
end

---------------------------------------------------------------- instances
local ISA = {
	-- a22 : classes du ContractChecker et du faux ProfileStore
	Weld = { "JointInstance" },
	Motor6D = { "JointInstance" },
	WeldConstraint = {},
	Accessory = { "Accoutrement" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	RemoteEvent = { "BaseRemoteEvent" },
	UnreliableRemoteEvent = { "BaseRemoteEvent" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	PointLight = { "Light" },
	Decal = { "FaceInstance" }, -- a31 : icônes ICON_ (Contract/Icons)
}
local NONE = setmetatable({}, { __tostring = function()
	return "nil"
end })
local function basePart()
	return {
		Anchored = false,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		CastShadow = true,
		Massless = false,
		Transparency = 0,
		Size = v3(4, 1, 2),
		CFrame = CFrame.identity,
		PivotOffset = CFrame.identity,
		Color = Color3.new(0.6, 0.6, 0.6),
		Material = "Enum.Material.Plastic",
		TopSurface = "Enum.SurfaceType.Smooth",
		BottomSurface = "Enum.SurfaceType.Smooth",
	}
end
local function guiObject(extra)
	local t = {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 0,
		Visible = true,
	}
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end
local TEXT = {
	Text = "Label",
	TextScaled = false,
	FontFace = Font.fromEnum("Enum.Font.SourceSans"),
	TextColor3 = Color3.new(0, 0, 0),
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 1,
}
local PROPS = {
	-- a22
	Weld = function()
		return { Part0 = NONE, Part1 = NONE, C0 = CFrame.identity, C1 = CFrame.identity }
	end,
	WeldConstraint = function()
		return { Part0 = NONE, Part1 = NONE }
	end,
	Part = basePart,
	MeshPart = basePart,
	Model = function()
		return { PrimaryPart = NONE, WorldPivot = CFrame.identity, ModelStreamingMode = "Default" } -- a22 : ModelStreamingMode (DisplayService)
	end,
	Folder = function()
		return {}
	end,
	Attachment = function()
		return { CFrame = CFrame.identity }
	end,
	Decal = function() -- a31
		return { Texture = "", Transparency = 0, Color3 = Color3.new(1, 1, 1), Face = "Enum.NormalId.Front" }
	end,
	PointLight = function()
		return { Color = Color3.new(1, 1, 1), Brightness = 1, Range = 8, Shadows = false, Enabled = true }
	end,
	ParticleEmitter = function()
		return {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			LightEmission = 0,
			LightInfluence = 1,
			Rate = 5,
			Lifetime = NumberRange.new(5, 10),
			Speed = NumberRange.new(5, 5),
			Acceleration = v3(0, 0, 0),
			Size = NumberSequence.new(1),
			Transparency = NumberSequence.new(0),
			Rotation = NumberRange.new(0, 0),
			RotSpeed = NumberRange.new(0, 0),
			Shape = "Enum.ParticleEmitterShape.Box",
			ShapeStyle = "Enum.ParticleEmitterShapeStyle.Volume",
			ShapeInOut = "Enum.ParticleEmitterShapeInOut.Outward",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Enabled = true,
		}
	end,
	Beam = function()
		return {
			Attachment0 = NONE,
			Attachment1 = NONE,
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Width0 = 1,
			Width1 = 1,
			Transparency = NumberSequence.new(0.5),
			LightEmission = 0,
			LightInfluence = 0,
			FaceCamera = false,
			Segments = 10,
			Texture = "",
			Enabled = true,
		}
	end,
	BillboardGui = function()
		return {
			Size = UDim2.fromScale(0, 0),
			StudsOffset = v3(0, 0, 0),
			MaxDistance = math.huge,
			LightInfluence = 1,
			Adornee = NONE,
			AlwaysOnTop = false,
			Enabled = true,
		}
	end,
	Frame = function()
		return guiObject()
	end,
	TextLabel = function()
		return guiObject(TEXT)
	end,
	TextButton = function()
		return guiObject(TEXT)
	end,
	UIGradient = function()
		return { Color = ColorSequence.new(Color3.new(1, 1, 1)), Rotation = 0 }
	end,
	Humanoid = function()
		return { Health = 100 }
	end,
	Player = function()
		return { UserId = 0, Character = NONE, DisplayName = "" }
	end,
	Players = function()
		return { LocalPlayer = NONE }
	end,
	Workspace = function()
		return { CurrentCamera = NONE }
	end,
	Camera = function()
		-- a128 (vague 39, 2026-11-14) : FieldOfView et ViewportSize (faux Vector2 : X et Y), lus par ItemIdleController.
		return { CFrame = CFrame.identity, FieldOfView = 70, ViewportSize = { X = 1280, Y = 720 } }
	end,
}
local EVENTS = {
	ChildAdded = true,
	DescendantAdded = true, -- a22
	DescendantRemoving = true, -- a22
	ChildRemoved = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	Touched = true,
	OnServerEvent = true,
	OnClientEvent = true,
}

local Methods = {}
METHODS = Methods -- a22 : pour ext.luau
local InstanceMT = { __type = "Instance" }
local tagsOf = {} -- [instance] = { [tag] = true }

local function isA(self, class)
	if rawget(self, "_class") == class or class == "Instance" then
		return true
	end
	for _, c in ISA[rawget(self, "_class")] or {} do
		if c == class then
			return true
		end
	end
	return false
end

local function attachmentParentCFrame(self)
	local parent = rawget(self, "_parent")
	if parent and isA(parent, "BasePart") then
		return rawget(parent, "_props").CFrame
	end
	return CFrame.identity
end

InstanceMT.__index = function(self, key)
	local m = Methods[key]
	if m ~= nil then
		return m
	end
	local class = rawget(self, "_class")
	if key == "ClassName" then
		return class
	elseif key == "Parent" then
		return rawget(self, "_parent")
	end
	local props = rawget(self, "_props")
	if isA(self, "BasePart") and key == "Position" then
		return props.CFrame.Position
	elseif class == "Attachment" then
		if key == "Position" then
			return props.CFrame.Position
		elseif key == "WorldPosition" then
			return attachmentParentCFrame(self) * props.CFrame.Position
		elseif key == "WorldCFrame" then
			return attachmentParentCFrame(self) * props.CFrame
		end
	end
	local v = props[key]
	if v ~= nil then
		if v == NONE then
			return nil
		end
		return v
	end
	if EVENTS[key] then
		local signals = rawget(self, "_signals")
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	for _, child in rawget(self, "_children") do
		if child.Name == key then
			return child
		end
	end
	error(`{class} « {props.Name} » : membre inconnu « {key} »`, 2)
end

local function setParent(self, parent)
	if rawget(self, "_destroyed") then
		error("Parent verrouillé : instance détruite", 3)
	end
	local old = rawget(self, "_parent")
	if old == parent then
		return
	end
	-- a22 : DescendantRemoving (avant le retrait) et DescendantAdded (après l'ajout) sur les ancêtres,
	-- pour l'instance et chacun de ses descendants, comme Roblox.
	local moved = { self }
	for _, d in Methods.GetDescendants(self) do
		table.insert(moved, d)
	end
	local ancestor = old
	while ancestor do
		for _, d in moved do
			ancestor.DescendantRemoving:Fire(d)
		end
		ancestor = rawget(ancestor, "_parent")
	end
	if old then
		local list = rawget(old, "_children")
		local i = table.find(list, self)
		if i then
			table.remove(list, i)
		end
	end
	rawset(self, "_parent", parent)
	if parent then
		table.insert(rawget(parent, "_children"), self)
	end
	if old then
		old.ChildRemoved:Fire(self)
	end
	if parent then
		parent.ChildAdded:Fire(self)
	end
	ancestor = parent
	while ancestor do
		for _, d in moved do
			ancestor.DescendantAdded:Fire(d)
		end
		ancestor = rawget(ancestor, "_parent")
	end
end

InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	local props = rawget(self, "_props")
	local class = rawget(self, "_class")
	if class == "Attachment" and key == "Position" then
		props.CFrame = CFrame.new(value) * props.CFrame.Rotation
		return
	elseif class == "Attachment" and key == "WorldPosition" then
		local local_ = attachmentParentCFrame(self):PointToObjectSpace(value)
		props.CFrame = CFrame.new(local_) * props.CFrame.Rotation
		return
	end
	if key ~= "Name" and rawget(self, "_known")[key] == nil then
		error(`{class} : propriété inconnue « {key} » (écriture)`, 2)
	end
	if value == nil then
		value = NONE
	end
	props[key] = value
end
InstanceMT.__tostring = function(self)
	return rawget(self, "_props").Name
end

local function newInstance(class)
	local defaults = if PROPS[class] then PROPS[class]() else {}
	local known = {}
	for k in defaults do
		known[k] = true
	end
	defaults.Name = class
	return setmetatable({
		_class = class,
		_props = defaults,
		_known = known,
		_children = {},
		_attrs = {},
		_attrSignals = {},
		_signals = {},
		_parent = nil,
		_destroyed = false,
	}, InstanceMT)
end

function Methods.IsA(self, class)
	return isA(self, class)
end
function Methods.IsDescendantOf(self, ancestor)
	local inst = rawget(self, "_parent")
	while inst do
		if inst == ancestor then
			return true
		end
		inst = rawget(inst, "_parent")
	end
	return false
end
function Methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(inst)
		for _, c in rawget(inst, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, d in Methods.GetDescendants(self) do
			if d.Name == name then
				return d
			end
		end
	end
	return nil
end
function Methods.FindFirstChildOfClass(self, class)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == class then
			return c
		end
	end
	return nil
end
function Methods.FindFirstChildWhichIsA(self, class, recursive)
	local list = if recursive then Methods.GetDescendants(self) else rawget(self, "_children")
	for _, c in list do
		if isA(c, class) then
			return c
		end
	end
	return nil
end
function Methods.WaitForChild(self, name, timeout)
	local deadline = simTime + (timeout or 5)
	while true do
		local c = Methods.FindFirstChild(self, name)
		if c then
			return c
		end
		if simTime >= deadline then
			return nil
		end
		taskLib.wait(0.03)
	end
end
function Methods.SetAttribute(self, name, value)
	local attrs = rawget(self, "_attrs")
	if attrs[name] == value then
		return
	end
	attrs[name] = value
	local s = rawget(self, "_attrSignals")[name]
	if s then
		s:Fire()
	end
end
function Methods.GetAttribute(self, name)
	return rawget(self, "_attrs")[name]
end
function Methods.GetAttributeChangedSignal(self, name)
	local signals = rawget(self, "_attrSignals")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
function Methods.Destroy(self)
	if rawget(self, "_destroyed") then
		return
	end
	for _, c in Methods.GetChildren(self) do
		Methods.Destroy(c)
	end
	setParent(self, nil)
	rawset(self, "_destroyed", true)
	for tag in tagsOf[self] or {} do
		CollectionServiceRemoved(self, tag)
	end
	tagsOf[self] = nil
end
function Methods.Clone(self)
	local copy = newInstance(rawget(self, "_class"))
	for k, v in rawget(self, "_props") do
		rawget(copy, "_props")[k] = v
	end
	for k, v in rawget(self, "_known") do
		rawget(copy, "_known")[k] = v
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	local map = { [self] = copy }
	local function cloneChildren(from, to)
		for _, c in rawget(from, "_children") do
			local cc = newInstance(rawget(c, "_class"))
			for k, v in rawget(c, "_props") do
				rawget(cc, "_props")[k] = v
			end
			for k, v in rawget(c, "_known") do
				rawget(cc, "_known")[k] = v
			end
			for k, v in rawget(c, "_attrs") do
				rawget(cc, "_attrs")[k] = v
			end
			map[c] = cc
			cc.Parent = to
			cloneChildren(c, cc)
		end
	end
	cloneChildren(self, copy)
	-- Les références internes (PrimaryPart, Attachment0…) pointent vers les copies.
	for _, inst in map do
		local props = rawget(inst, "_props")
		for k, v in props do
			if type(v) == "table" and getmetatable(v) == InstanceMT and map[v] then
				props[k] = map[v]
			end
		end
	end
	return copy
end
function Methods.GetFullName(self)
	local names = {}
	local inst = self
	while inst and rawget(inst, "_class") ~= "DataModel" do
		table.insert(names, 1, inst.Name)
		inst = rawget(inst, "_parent")
	end
	return table.concat(names, ".")
end
function Methods.GetBoundingBox(self)
	local lo, hi
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			local p, h = d.CFrame.Position, d.Size / 2
			local a, b = p - h, p + h
			lo = if lo then v3(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
			hi = if hi then v3(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
		end
	end
	if lo == nil then
		return Methods.GetPivot(self), v3(0, 0, 0)
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end
function Methods.GetPivot(self)
	if isA(self, "BasePart") then
		return self.CFrame * self.PivotOffset
	end
	local primary = self.PrimaryPart
	if primary then
		return primary.CFrame * primary.PivotOffset
	end
	return self.WorldPivot
end
function Methods.PivotTo(self, target)
	local delta = target * Methods.GetPivot(self):Inverse()
	if isA(self, "BasePart") then
		self.CFrame = delta * self.CFrame
		return
	end
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	if self.PrimaryPart == nil then
		self.WorldPivot = delta * self.WorldPivot
	end
end
-- Players
function Methods.GetPlayers(self)
	local out = {}
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
function Methods.GetPlayerByUserId(self, id)
	for _, p in Methods.GetPlayers(self) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
-- Remotes (réseau simulé : un seul client, CLIENT_PLAYER)
CLIENT_PLAYER = nil
REMOTE_LOG = {} -- envois serveur → client
function Methods.FireServer(self, ...)
	self.OnServerEvent:Fire(CLIENT_PLAYER, ...)
end
function Methods.FireAllClients(self, ...)
	table.insert(REMOTE_LOG, { t = simTime, name = self.Name, args = table.pack(...) })
	self.OnClientEvent:Fire(...)
end
function Methods.FireClient(self, player, ...)
	table.insert(REMOTE_LOG, { t = simTime, name = self.Name, to = player, args = table.pack(...) })
	if player == CLIENT_PLAYER then
		self.OnClientEvent:Fire(...)
	end
end

InstanceAPI = {
	new = function(class)
		return newInstance(class)
	end,
}

---------------------------------------------------------------- CollectionService
local tagged = {} -- [tag] = { instances }
local addedSignals, removedSignals = {}, {}
local function sig(map, tag)
	map[tag] = map[tag] or newSignal()
	return map[tag]
end
function addTag(inst, tag)
	tagsOf[inst] = tagsOf[inst] or {}
	if tagsOf[inst][tag] then
		return
	end
	tagsOf[inst][tag] = true
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], inst)
	sig(addedSignals, tag):Fire(inst)
end
function CollectionServiceRemoved(inst, tag)
	local list = tagged[tag]
	local i = list and table.find(list, inst)
	if i then
		table.remove(list, i)
	end
	sig(removedSignals, tag):Fire(inst)
end
CollectionServiceStub = {
	GetTagged = function(_, tag)
		return table.clone(tagged[tag] or {})
	end,
	GetInstanceAddedSignal = function(_, tag)
		return sig(addedSignals, tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return sig(removedSignals, tag)
	end,
	AddTag = function(_, inst, tag)
		addTag(inst, tag)
	end,
	HasTag = function(_, inst, tag)
		return tagsOf[inst] ~= nil and tagsOf[inst][tag] == true
	end,
	-- a22 : pour le ContractChecker
	GetAllTags = function()
		local out = {}
		for tag, list in tagged do
			if #list > 0 then
				table.insert(out, tag)
			end
		end
		return out
	end,
}
-- a22 : inst:HasTag(tag) (ContractChecker)
function Methods.HasTag(self, tag)
	return tagsOf[self] ~= nil and tagsOf[self][tag] == true
end

---------------------------------------------------------------- arbre du jeu
DataModel = newInstance("DataModel")
local function service(class)
	local s = newInstance(class)
	s.Name = class
	s.Parent = DataModel
	return s
end
Workspace = service("Workspace")
ReplicatedStorage = service("ReplicatedStorage")
ServerScriptService = service("ServerScriptService")
StarterPlayerScripts = service("StarterPlayerScripts")
Players = service("Players")
StarterGui = service("StarterGui") -- a22 : ContractChecker
ServerStorage = service("ServerStorage") -- a22 : ContractChecker

function folder(parent, name)
	local f = newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
function new(class, props, parent)
	local inst = newInstance(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- ModuleScript factice relié à une source
local moduleSource = {} -- [ModuleScript] = clé de SOURCES
function moduleScript(parent, name, key)
	local m = newInstance("ModuleScript")
	m.Name = name
	m.Parent = parent
	moduleSource[m] = key
	return m
end

---------------------------------------------------------------- require par côté
local function makeRunService(side)
	return {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return side == "server"
		end,
		IsClient = function()
			return side == "client"
		end,
		IsRunning = function()
			return true
		end,
		Heartbeat = HEARTBEAT,
	}
end
local function makeGame(side)
	local services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		RunService = makeRunService(side),
		CollectionService = CollectionServiceStub,
		Workspace = Workspace,
		-- a22 : ContractChecker (aucune animation dans ce banc : AnimationClipProvider n'est pas appelé)
		StarterGui = StarterGui,
		ServerStorage = ServerStorage,
		AnimationClipProvider = {},
		-- a31 : Icons.preload (client) ; chaque appel noté dans PRELOADS.
		ContentProvider = {
			PreloadAsync = function(_, list)
				table.insert(PRELOADS, { side = side, list = table.clone(list) })
			end,
		},
		-- a51 : DataService (migration v7) donne un uid neuf à chaque colis.
		HttpService = {
			GenerateGUID = function(_self, _braces)
				GUID_COUNT = (GUID_COUNT or 0) + 1
				return string.format("00000000-0000-4000-8000-%012d", GUID_COUNT)
			end,
		},
	}
	return {
		GetService = function(_, name)
			return services[name] or error("service bouchonné absent : " .. name)
		end,
	}
end
local games = { server = makeGame("server"), client = makeGame("client") }
local caches = { server = {}, client = {} }

local function typeofStub(v)
	local mt = getmetatable(v)
	if type(v) == "table" and type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
end

local function logger(side, kind)
	return function(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		local text = table.concat(parts, " ")
		table.insert(LOG, { side = side, kind = kind, text = text })
		if VERBOSE then
			print(`    [{side} {kind}] {text}`)
		end
	end
end

function requireModule(m, side)
	local cache = caches[side]
	if cache[m] ~= nil then
		return cache[m]
	end
	local key = moduleSource[m]
	assert(key, "require d'un objet qui n'est pas un ModuleScript bouchonné : " .. tostring(m))
	local source = SOURCES[key]
	assert(source, "source absente : " .. key)
	local fn, err = loadstring(source, key)
	assert(fn, err)
	local env = setmetatable({
		game = games[side],
		workspace = Workspace,
		script = m,
		require = function(target)
			return requireModule(target, side)
		end,
		task = taskLib,
		os = {
			clock = function()
				return simTime
			end,
			time = function()
				return math.floor(simTime)
			end,
		},
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		Instance = InstanceAPI,
		typeof = typeofStub,
		warn = logger(side, "WARN"),
		print = logger(side, "PRINT"),
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	local result = fn()
	cache[m] = result
	return result
end

---------------------------------------------------------------- vérifications
function check(cond, label)
	CHECKS += 1
	if cond then
		print("  ok   " .. label)
	else
		FAILS += 1
		print("  ÉCHEC " .. label)
	end
end
function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end
function logHas(pattern, kind, side)
	for _, line in LOG do
		if (kind == nil or line.kind == kind) and (side == nil or line.side == side) and string.find(line.text, pattern, 1, true) then
			return true
		end
	end
	return false
end
function logCount(pattern, kind, side)
	local n = 0
	for _, line in LOG do
		if (kind == nil or line.kind == kind) and (side == nil or line.side == side) and string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end
function clearLog()
	table.clear(LOG)
end
function dumpLog()
	for _, line in LOG do
		print(`    [{line.side} {line.kind}] {line.text}`)
	end
end
function notifies(player)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == "Notify" and (player == nil or e.to == player) then
			table.insert(out, e.args[1])
		end
	end
	return out
end
function clearRemotes()
	table.clear(REMOTE_LOG)
end
function summary()
	print(string.format("\n%d vérification(s), %d échec(s)", CHECKS, FAILS))
end
