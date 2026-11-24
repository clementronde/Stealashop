--!nocheck
-- Faux Roblox du banc a27 (événement camion), hors Studio. Repris du faux d'a17-carry (instances
-- permissives, CFrame complet, Clone qui recâble les références, tags qui suivent l'arbre du jeu) et
-- de celui d'a24 (remotes, heure serveur), complété pour le camion : boîte englobante orientée,
-- rayons contre de vraies pièces (pavés orientés), CFrame.fromAxisAngle, Random, Heartbeat par
-- images, ProximityPrompt, TweenService, HttpService.
-- Un seul VM, un seul arbre d'instances partagé par le « serveur » et le « client » (réplication
-- parfaite et instantanée), temps simulé. Un seul client : CLIENT_PLAYER.

SOURCES = {}
LOG = {}
FAILS = 0
CHECKS = 0
REMOTE_LOG = {} -- envois serveur → client : { t, name, to?, args }
SERVER_CALLS = {} -- envois client → serveur : { t, name, args }

---------------------------------------------------------------- temps et tâches
local simTime = 0
local queue = {}
local seq = 0
local cancelled = {}
local function schedule(t, co, ...)
	seq += 1
	table.insert(queue, { t = t, seq = seq, co = co, args = table.pack(...) })
end
local function resume(co, ...)
	if cancelled[co] or coroutine.status(co) == "dead" then
		return
	end
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
	local co = if type(f) == "thread" then f else coroutine.create(f)
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
function taskLib.cancel(co)
	cancelled[co] = true
end
local function runUntil(t)
	while true do
		local best, bestIndex = nil, nil
		for i, e in queue do
			if e.t <= t and (best == nil or e.t < best.t or (e.t == best.t and e.seq < best.seq)) then
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
	simTime = math.max(simTime, t)
end
FRAME = 1 / 30
ON_FRAME = nil -- fonction appelée après chaque image (vérifications continues des tests)
-- Avance de `dt` secondes, image par image (`frame`, défaut FRAME) : tâches dues, puis Heartbeat.
function advance(dt, frame)
	local step = frame or FRAME
	local target = simTime + dt
	while simTime + step <= target + 1e-9 do
		runUntil(simTime + step)
		HEARTBEAT:Fire(step)
		if ON_FRAME then
			ON_FRAME()
		end
	end
	runUntil(target)
end
function flush()
	runUntil(simTime)
end
function now()
	return simTime
end

---------------------------------------------------------------- types de valeurs
local function typed(name)
	return { __type = name }
end

Vector3 = {}
local V3MT = typed("Vector3")
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3MT)
end
local V3Methods = {}
function V3Methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3Methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3Methods.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
V3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	local m = V3Methods[k]
	if m then
		return m
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
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

-- CFrame : position + matrice de rotation 3×3 (par lignes).
CFrame = {}
local CFMT = typed("CFrame")
local function cf(p, r)
	return setmetatable({ p = p, r = r }, CFMT)
end
local ID = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mulRV(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
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
local function inverse(c)
	local rt = transpose(c.r)
	return cf(-mulRV(rt, c.p), rt)
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
	elseif k == "Rotation" then
		return cf(v3(0, 0, 0), c.r)
	elseif k == "LookVector" then
		return v3(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "RightVector" or k == "XVector" then
		return v3(c.r[1], c.r[4], c.r[7])
	elseif k == "UpVector" or k == "YVector" then
		return v3(c.r[2], c.r[5], c.r[8])
	elseif k == "ZVector" then
		return v3(c.r[3], c.r[6], c.r[9])
	elseif k == "Inverse" then
		return inverse
	elseif k == "ToObjectSpace" then
		return function(self, other)
			return inverse(self) * other
		end
	elseif k == "ToWorldSpace" then
		return function(self, other)
			return self * other
		end
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			return mulRV(transpose(self.r), v - self.p)
		end
	elseif k == "PointToWorldSpace" then
		return function(self, v)
			return self.p + mulRV(self.r, v)
		end
	elseif k == "VectorToObjectSpace" then
		return function(self, v)
			return mulRV(transpose(self.r), v)
		end
	elseif k == "Lerp" then
		-- Position interpolée ; rotation de la cible à la fin (suffisant pour les tests).
		return function(self, other, t)
			return cf(self.p + (other.p - self.p) * t, if t >= 1 then other.r else self.r)
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
CFMT.__add = function(a, v)
	return cf(a.p + v, a.r)
end
CFMT.__sub = function(a, v)
	return cf(a.p - v, a.r)
end
CFMT.__tostring = function(c)
	return "CFrame" .. tostring(c.p)
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cf(x, ID)
	end
	return cf(v3(x or 0, y or 0, z or 0), ID)
end
-- Colonnes de r : droite, haut, arrière (LookVector = −arrière). `up` du monde par défaut.
function CFrame.lookAt(pos, target)
	local look = (target - pos).Unit
	local up = v3(0, 1, 0)
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = v3(1, 0, 0)
	else
		right = right.Unit
	end
	local realUp = right:Cross(look)
	local back = -look
	return cf(pos, { right.X, realUp.X, back.X, right.Y, realUp.Y, back.Y, right.Z, realUp.Z, back.Z })
end
local function rotX(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
function CFrame.Angles(rx, ry, rz)
	return cf(v3(0, 0, 0), mulRR(mulRR(rotX(rx or 0), rotY(ry or 0)), rotZ(rz or 0)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(v3(0, 0, 0), {
		t * x * x + c,
		t * x * y - s * z,
		t * x * z + s * y,
		t * x * y + s * z,
		t * y * y + c,
		t * y * z - s * x,
		t * x * z - s * y,
		t * y * z + s * x,
		t * z * z + c,
	})
end
CFrame.identity = CFrame.new(0, 0, 0)
function cfClose(a, b, eps)
	eps = eps or 1e-6
	if (a.p - b.p).Magnitude > eps then
		return false
	end
	for i = 1, 9 do
		if math.abs(a.r[i] - b.r[i]) > eps then
			return false
		end
	end
	return true
end
-- Rotation orthonormée ? (contrôle des rotations accumulées)
function isOrthonormal(c, eps)
	eps = eps or 1e-6
	local r = c.r
	local m = mulRR(r, transpose(r))
	for i = 1, 9 do
		if math.abs(m[i] - ID[i]) > eps then
			return false
		end
	end
	return true
end

local C3MT = typed("Color3")
C3MT.__index = {
	Lerp = function(a, b, t)
		return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3MT)
	end,
}
C3MT.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
C3MT.__tostring = function(c)
	return string.format("RGB(%d, %d, %d)", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3MT)
end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHex = function(hex)
		hex = string.gsub(hex, "#", "")
		return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}
ColorSequenceKeypoint = {
	new = function(t, color)
		return setmetatable({ Time = t, Value = color }, typed("ColorSequenceKeypoint"))
	end,
}
ColorSequence = {
	new = function(a, b)
		local keypoints
		if type(a) == "table" and getmetatable(a) == C3MT then
			keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) }
		else
			keypoints = a
		end
		return setmetatable({ Keypoints = keypoints }, typed("ColorSequence"))
	end,
}
NumberSequence = {
	new = function(a, b)
		return setmetatable({ Start = a, End = if b == nil then a else b }, typed("NumberSequence"))
	end,
}
NumberRange = {
	new = function(a, b)
		return setmetatable({ Min = a, Max = b or a }, typed("NumberRange"))
	end,
}
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, typed("Vector2"))
	end,
}
local UDMT = typed("UDim")
UDim = {
	new = function(s, o)
		return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDMT)
	end,
}
local UD2MT = typed("UDim2")
UD2MT.__eq = function(a, b)
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end
UD2MT.__tostring = function(u)
	return string.format("{%g, %g}, {%g, %g}", u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset)
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2MT)
	end,
	fromScale = function(x, y)
		return setmetatable({ X = UDim.new(x, 0), Y = UDim.new(y, 0) }, UD2MT)
	end,
	fromOffset = function(x, y)
		return setmetatable({ X = UDim.new(0, x), Y = UDim.new(0, y) }, UD2MT)
	end,
}
TweenInfo = {
	new = function(t, ...)
		return setmetatable({ Time = t or 1 }, typed("TweenInfo"))
	end,
}
Font = {
	fromEnum = function(e)
		return setmetatable({ Family = e }, typed("Font"))
	end,
	new = function(family, weight, style)
		return setmetatable({ Family = family, Weight = weight, Style = style }, typed("Font"))
	end,
}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return `Enum.{enumName}.{item}`
			end,
		})
	end,
})

-- Random déterministe (Park et Miller) : chaque Random.new reçoit une graine différente.
local seedCounter = 0
local RandomMT = typed("Random")
RandomMT.__index = RandomMT
local function nextFloat(self)
	self._state = (self._state * 16807) % 2147483647
	return self._state / 2147483647
end
function RandomMT:NextNumber(a, b)
	local x = nextFloat(self)
	if a ~= nil then
		return a + x * (b - a)
	end
	return x
end
function RandomMT:NextInteger(a, b)
	local x = nextFloat(self)
	return math.min(b, a + math.floor(x * (b - a + 1)))
end
function RandomMT:NextUnitVector()
	local z = nextFloat(self) * 2 - 1
	local t = nextFloat(self) * 2 * math.pi
	local s = math.sqrt(math.max(1 - z * z, 0))
	return v3(s * math.cos(t), s * math.sin(t), z)
end
Random = {
	new = function(seed)
		seedCounter += 1
		local state = seed or (seedCounter * 7919 + (RANDOM_SEED or 1))
		state = math.max(1, math.floor(state) % 2147483647)
		return setmetatable({ _state = state }, RandomMT)
	end,
}

---------------------------------------------------------------- signaux
local SignalMT = typed("RBXScriptSignal")
SignalMT.__index = SignalMT
function newSignal()
	return setmetatable({ handlers = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	local handlers = self.handlers
	local conn = { Connected = true, fn = fn }
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
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function SignalMT:Fire(...)
	for _, c in table.clone(self.handlers) do
		if c.Connected then
			taskLib.spawn(c.fn, ...)
		end
	end
end
function SignalMT:ConnectionCount()
	return #self.handlers
end
HEARTBEAT = newSignal()

---------------------------------------------------------------- instances
local SUPER = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	WedgePart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "WorldRoot", "Model", "PVInstance" },
	Tool = { "BackpackItem" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	RemoteEvent = { "BaseRemoteEvent" },
	UnreliableRemoteEvent = { "BaseRemoteEvent" },
	PointLight = { "Light" },
	SpotLight = { "Light" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiObject", "GuiBase2d" },
	ImageButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	PlayerGui = { "BasePlayerGui" },
	Weld = { "JointInstance" },
}
local function isAClass(own, class)
	if own == class or class == "Instance" then
		return true
	end
	for _, c in SUPER[own] or {} do
		if c == class then
			return true
		end
	end
	return false
end
local DEFAULTS = {
	BasePart = function()
		return {
			Anchored = false,
			CanCollide = true,
			CanQuery = true,
			CanTouch = true,
			Massless = false,
			Transparency = 0,
			LocalTransparencyModifier = 0,
			Size = v3(4, 1, 2),
			CFrame = CFrame.identity,
			PivotOffset = CFrame.identity,
			Color = c3(0.64, 0.64, 0.64),
			AssemblyLinearVelocity = Vector3.zero,
			AssemblyAngularVelocity = Vector3.zero,
		}
	end,
	Attachment = function()
		return { CFrame = CFrame.identity }
	end,
	Model = function()
		return { WorldPivot = CFrame.identity }
	end,
	Humanoid = function()
		return { Health = 100, HipHeight = 2, RigType = "Enum.HumanoidRigType.R15", WalkSpeed = 16 }
	end,
	GuiObject = function()
		return { Visible = true, Text = "", Size = UDim2.new(0, 0, 0, 0), TextColor3 = c3(0, 0, 0) }
	end,
	LayerCollector = function()
		return { Enabled = true, Size = UDim2.new(0, 0, 0, 0), MaxDistance = math.huge, ResetOnSpawn = true }
	end,
	Trail = function()
		return { Enabled = true, Lifetime = 2 }
	end,
	Highlight = function()
		return { Enabled = true }
	end,
	ProximityPrompt = function()
		return { Enabled = true, HoldDuration = 0, MaxActivationDistance = 10, ActionText = "", ObjectText = "" }
	end,
	Player = function()
		return { UserId = 0 }
	end,
}
local CLASS_EVENTS = {
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	AncestryChanged = true,
	Destroying = true,
	Died = true,
	Activated = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	OnServerEvent = true,
	OnClientEvent = true,
	PromptButtonHoldBegan = true,
	PromptButtonHoldEnded = true,
	Triggered = true,
	Completed = true,
}

Methods = {}
local InstanceMT = { __type = "Instance" }
local tagsOf = {} -- [instance] = { [tag] = true }
DataModel = nil

local function isA(self, class)
	return isAClass(rawget(self, "_class"), class)
end

InstanceMT.__index = function(self, key)
	local m = Methods[key]
	if m ~= nil then
		return m
	end
	if key == "ClassName" then
		return rawget(self, "_class")
	elseif key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "Position" and isA(self, "BasePart") then
		return rawget(self, "_props").CFrame.Position
	elseif key == "Orientation" and isA(self, "BasePart") then
		return Vector3.zero
	elseif key == "WorldCFrame" and isA(self, "Attachment") then
		local parent = rawget(self, "_parent")
		local base = if parent and isA(parent, "BasePart") then parent.CFrame else CFrame.identity
		return base * rawget(self, "_props").CFrame
	elseif key == "WorldPosition" and isA(self, "Attachment") then
		return self.WorldCFrame.Position
	elseif key == "Position" and isA(self, "Attachment") then
		return rawget(self, "_props").CFrame.Position
	end
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	if CLASS_EVENTS[key] then
		local signals = rawget(self, "_signals")
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	for _, child in rawget(self, "_children") do
		if rawget(child, "_props").Name == key then
			return child
		end
	end
	return nil -- permissif : propriété jamais écrite
end

local function inGame(inst)
	local current = inst
	while current do
		if current == DataModel then
			return true
		end
		current = rawget(current, "_parent")
	end
	return false
end

local addedSignals, removedSignals = {}, {}
local function tagSignal(map, tag)
	map[tag] = map[tag] or newSignal()
	return map[tag]
end

local function subtree(inst)
	local out = { inst }
	for _, d in Methods.GetDescendants(inst) do
		table.insert(out, d)
	end
	return out
end

local function setParent(self, parent)
	if rawget(self, "_destroyed") then
		error(`Parent verrouillé : {rawget(self, "_props").Name} est détruit`, 3)
	end
	if parent and rawget(parent, "_destroyed") then
		error(`Parent verrouillé : {rawget(parent, "_props").Name} est détruit`, 3)
	end
	local old = rawget(self, "_parent")
	if old == parent then
		return
	end
	local wasInGame = inGame(self)
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
	local isInGame = inGame(self)
	local list = subtree(self)
	for _, d in list do
		d.AncestryChanged:Fire(self, parent)
	end
	if old then
		old.ChildRemoved:Fire(self)
	end
	if parent then
		parent.ChildAdded:Fire(self)
		local anc = parent
		while anc do
			local signal = rawget(anc, "_signals").DescendantAdded
			if signal then
				for _, d in list do
					signal:Fire(d)
				end
			end
			anc = rawget(anc, "_parent")
		end
	end
	if wasInGame ~= isInGame then
		for _, d in list do
			for tag in tagsOf[d] or {} do
				tagSignal(if isInGame then addedSignals else removedSignals, tag):Fire(d)
			end
		end
	end
end

InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	if key == "Position" and isA(self, "Attachment") then
		local props = rawget(self, "_props")
		props.CFrame = CFrame.new(value) * props.CFrame.Rotation
		return
	end
	if key == "Position" and isA(self, "BasePart") then
		local props = rawget(self, "_props")
		props.CFrame = CFrame.new(value) * props.CFrame.Rotation
		return
	end
	if key == "CFrame" and isA(self, "Attachment") and rawget(self, "_props").CFrame == nil then
		rawget(self, "_props").CFrame = value
		return
	end
	rawget(self, "_props")[key] = value
end
InstanceMT.__tostring = function(self)
	return rawget(self, "_props").Name
end

function newInstance(class)
	local props = { Name = class }
	for base, make in DEFAULTS do
		if isAClass(class, base) then
			for k, v in make() do
				props[k] = v
			end
		end
	end
	return setmetatable({
		_class = class,
		_props = props,
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
function Methods.HasTag(self, tag)
	return (tagsOf[self] or {})[tag] == true
end
function Methods.GetTags(self)
	local out = {}
	for tag in tagsOf[self] or {} do
		table.insert(out, tag)
	end
	return out
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
function Methods.IsAncestorOf(self, descendant)
	return Methods.IsDescendantOf(descendant, self)
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
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, d in Methods.GetDescendants(self) do
			if rawget(d, "_props").Name == name then
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
function Methods.FindFirstAncestorWhichIsA(self, class)
	local inst = rawget(self, "_parent")
	while inst do
		if isA(inst, class) then
			return inst
		end
		inst = rawget(inst, "_parent")
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
		if coroutine.isyieldable() == false or simTime >= deadline then
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
function Methods.GetAttributes(self)
	return table.clone(rawget(self, "_attrs"))
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
	local destroying = rawget(self, "_signals").Destroying
	if destroying then
		destroying:Fire()
	end
	setParent(self, nil)
	for _, c in Methods.GetChildren(self) do
		Methods.Destroy(c)
	end
	rawset(self, "_destroyed", true)
end
function Methods.ClearAllChildren(self)
	for _, c in Methods.GetChildren(self) do
		Methods.Destroy(c)
	end
end
function Methods.Clone(self)
	if rawget(self, "_props").Archivable == false then
		return nil
	end
	local map = {}
	local function deep(src)
		local dst = newInstance(rawget(src, "_class"))
		map[src] = dst
		for k, v in rawget(src, "_props") do
			rawget(dst, "_props")[k] = v
		end
		for k, v in rawget(src, "_attrs") do
			rawget(dst, "_attrs")[k] = v
		end
		for tag in tagsOf[src] or {} do
			tagsOf[dst] = tagsOf[dst] or {}
			tagsOf[dst][tag] = true
		end
		for _, c in rawget(src, "_children") do
			if rawget(c, "_props").Archivable ~= false then
				local cc = deep(c)
				rawset(cc, "_parent", dst)
				table.insert(rawget(dst, "_children"), cc)
			end
		end
		return dst
	end
	local copy = deep(self)
	-- Références internes (PrimaryPart, Attachment0, Adornee, Part0…) : vers les copies, comme Roblox.
	for _, dst in map do
		for k, v in rawget(dst, "_props") do
			if type(v) == "table" and getmetatable(v) == InstanceMT and map[v] then
				rawget(dst, "_props")[k] = map[v]
			end
		end
	end
	return copy
end
function Methods.GetFullName(self)
	local names = {}
	local inst = self
	while inst and inst ~= DataModel do
		table.insert(names, 1, inst.Name)
		inst = rawget(inst, "_parent")
	end
	return table.concat(names, ".")
end
-- Model / PVInstance
local function partsOf(model)
	local out = {}
	if isA(model, "BasePart") then
		table.insert(out, model)
	end
	for _, d in Methods.GetDescendants(model) do
		if isA(d, "BasePart") then
			table.insert(out, d)
		end
	end
	return out
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
	for _, p in partsOf(self) do
		p.CFrame = delta * p.CFrame
	end
	if not isA(self, "BasePart") and self.PrimaryPart == nil then
		self.WorldPivot = target
	end
end
-- Boîte englobante orientée comme le pivot (PrimaryPart, sinon WorldPivot), comme Roblox.
function Methods.GetBoundingBox(self)
	local pivot = Methods.GetPivot(self)
	local frame = pivot.Rotation + pivot.Position
	local lo, hi
	for _, p in partsOf(self) do
		local h = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local world = p.CFrame * v3(sx * h.X, sy * h.Y, sz * h.Z)
					local q = frame:PointToObjectSpace(world)
					lo = if lo then v3(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z)) else q
					hi = if hi then v3(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z)) else q
				end
			end
		end
	end
	if lo == nil then
		return frame, Vector3.zero
	end
	local center = (lo + hi) / 2
	return frame * CFrame.new(center), hi - lo
end
function Methods.GetExtentsSize(self)
	local _, size = Methods.GetBoundingBox(self)
	return size
end
-- Humanoid
function Methods.UnequipTools(self)
	local character = rawget(self, "_parent")
	for _, player in Methods.GetChildren(Players) do
		if player.Character == character then
			local backpack = Methods.FindFirstChild(player, "Backpack")
			for _, c in Methods.GetChildren(character) do
				if rawget(c, "_class") == "Tool" then
					c.Parent = backpack
				end
			end
		end
	end
end
function Methods.SetStateEnabled() end
function Methods.ChangeState() end
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
-- Remotes (un seul client : CLIENT_PLAYER)
CLIENT_PLAYER = nil
function Methods.FireServer(self, ...)
	table.insert(SERVER_CALLS, { t = simTime, name = self.Name, args = table.pack(...) })
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
-- Heure serveur (décalée de os.clock, comme en vrai)
SERVER_TIME_OFFSET = 5000
function Methods.GetServerTimeNow(_self)
	return simTime + SERVER_TIME_OFFSET
end
-- Workspace:Raycast : vraies pièces du Workspace (pavés orientés), filtres Exclude/Include,
-- RespectCanCollide, CanQuery. Renvoie le premier contact.
RAYCASTS = 0
function Methods.Raycast(self, origin, direction, params)
	RAYCASTS += 1
	local filter = if params then params.FilterDescendantsInstances or {} else {}
	local include = params and params.FilterType == "Enum.RaycastFilterType.Include"
	local function filtered(part)
		for _, f in filter do
			if part == f or Methods.IsDescendantOf(part, f) then
				return not include
			end
		end
		return include
	end
	local best, bestT, bestPart = nil, math.huge, nil
	for _, part in partsOf(self) do
		if part.CanQuery == false then
			continue
		end
		if params and params.RespectCanCollide and part.CanCollide == false then
			continue
		end
		if filtered(part) then
			continue
		end
		local inv = part.CFrame:Inverse()
		local o = inv * origin
		local d = inv.Rotation * direction
		local h = part.Size / 2
		local tmin, tmax = 0, 1
		local ok = true
		for _, axis in { "X", "Y", "Z" } do
			local oa, da, ha = o[axis], d[axis], h[axis]
			if math.abs(da) < 1e-12 then
				if oa < -ha or oa > ha then
					ok = false
					break
				end
			else
				local t1, t2 = (-ha - oa) / da, (ha - oa) / da
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
				if tmin > tmax then
					ok = false
					break
				end
			end
		end
		if ok and tmin < bestT then
			bestT, bestPart = tmin, part
		end
	end
	if bestPart == nil then
		return nil
	end
	best = { Position = origin + direction * bestT, Instance = bestPart, Distance = direction.Magnitude * bestT, Normal = Vector3.yAxis }
	return best
end

InstanceAPI = { new = newInstance }

---------------------------------------------------------------- services
CollectionService = {
	AddTag = function(_, inst, tag)
		tagsOf[inst] = tagsOf[inst] or {}
		if tagsOf[inst][tag] then
			return
		end
		tagsOf[inst][tag] = true
		if inGame(inst) then
			tagSignal(addedSignals, tag):Fire(inst)
		end
	end,
	RemoveTag = function(_, inst, tag)
		local tags = tagsOf[inst]
		if tags == nil or not tags[tag] then
			return
		end
		tags[tag] = nil
		if inGame(inst) then
			tagSignal(removedSignals, tag):Fire(inst)
		end
	end,
	HasTag = function(_, inst, tag)
		return (tagsOf[inst] or {})[tag] == true
	end,
	GetTagged = function(_, tag)
		local out = {}
		for inst, tags in tagsOf do
			if tags[tag] and inGame(inst) then
				table.insert(out, inst)
			end
		end
		table.sort(out, function(a, b)
			return Methods.GetFullName(a) < Methods.GetFullName(b)
		end)
		return out
	end,
	GetAllTags = function(_)
		local seen, out = {}, {}
		for _, tags in tagsOf do
			for tag in tags do
				if not seen[tag] then
					seen[tag] = true
					table.insert(out, tag)
				end
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		return tagSignal(addedSignals, tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return tagSignal(removedSignals, tag)
	end,
}
function addTag(inst, tag)
	CollectionService:AddTag(inst, tag)
end

DataModel = newInstance("DataModel")
local function service(class)
	local s = newInstance(class)
	s.Name = class
	s.Parent = DataModel
	return s
end
Workspace = service("Workspace")
Workspace.Gravity = 196.2
ReplicatedStorage = service("ReplicatedStorage")
ServerScriptService = service("ServerScriptService")
ServerStorage = service("ServerStorage")
StarterPlayer = service("StarterPlayer")
StarterGui = service("StarterGui")
Players = service("Players")
AnimationClipProvider = service("AnimationClipProvider")

function make(class, props, parent)
	local inst = newInstance(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
function folder(parent, name)
	return make("Folder", { Name = name }, parent)
end

local TweenService = {
	Create = function(_, inst, _info, props)
		local tween = { Completed = newSignal() }
		function tween.Play(t)
			for k, v in props do
				inst[k] = v
			end
			t.Completed:Fire("Enum.PlaybackState.Completed")
		end
		function tween.Cancel() end
		return tween
	end,
	GetValue = function(_, alpha)
		return alpha
	end,
}
local guidCount = 0
local HttpService = {
	GenerateGUID = function(_, braces)
		guidCount += 1
		return string.format("00000000-0000-4000-8000-%012d", guidCount)
	end,
	JSONEncode = function()
		return "{}"
	end,
}

---------------------------------------------------------------- modules
local moduleSource = {}
function moduleScript(parent, name, key)
	local m = make("ModuleScript", { Name = name }, parent)
	moduleSource[m] = key
	return m
end

local caches = { server = {}, client = {}, prod = {} }
local function makeRunService(side)
	return {
		Heartbeat = HEARTBEAT,
		RenderStepped = HEARTBEAT,
		PreRender = HEARTBEAT,
		Stepped = HEARTBEAT,
		IsStudio = function()
			return side ~= "prod" -- côté « prod » = serveur hors Studio
		end,
		IsServer = function()
			return side ~= "client"
		end,
		IsClient = function()
			return side == "client"
		end,
		IsRunning = function()
			return true
		end,
		BindToRenderStep = function() end,
	}
end
local function makeGame(side)
	local services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		RunService = makeRunService(side),
		CollectionService = CollectionService,
		Workspace = Workspace,
		ServerStorage = ServerStorage,
		ServerScriptService = ServerScriptService,
		StarterGui = StarterGui,
		StarterPlayer = StarterPlayer,
		TweenService = TweenService,
		HttpService = HttpService,
		AnimationClipProvider = AnimationClipProvider,
		ContentProvider = { PreloadAsync = function() end }, -- a79 (2026-11-11) : AnimPlayer, conducteurs repris par un camion par rareté
	}
	return {
		GetService = function(_, name)
			return services[name] or error("service absent du faux Roblox : " .. name)
		end,
		IsLoaded = function()
			return true
		end,
		Loaded = newSignal(),
	}
end
local games = { server = makeGame("server"), client = makeGame("client"), prod = makeGame("prod") }

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
		table.insert(LOG, { side = side, kind = kind, text = text, t = simTime })
		if VERBOSE then
			print(`    [{side} {kind}] {text}`)
		end
	end
end

local RaycastParamsAPI = {
	new = function()
		return { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = {}, RespectCanCollide = false, IgnoreWater = false }
	end,
}

function requireModule(m, side)
	local cache = caches[side]
	if cache[m] ~= nil then
		return cache[m]
	end
	local key = moduleSource[m]
	assert(key, "require d'un objet qui n'est pas un ModuleScript du banc : " .. tostring(m))
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
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence,
		NumberRange = NumberRange,
		UDim = UDim,
		UDim2 = UDim2,
		TweenInfo = TweenInfo,
		Font = Font,
		Enum = Enum,
		Instance = InstanceAPI,
		Random = Random,
		RaycastParams = RaycastParamsAPI,
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
		if VERBOSE then
			print("  ok   " .. label)
		end
	else
		FAILS += 1
		print("  ÉCHEC " .. label)
	end
end
function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
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
function logHas(pattern, kind, side)
	return logCount(pattern, kind, side) > 0
end
function clearLog()
	table.clear(LOG)
end
function dumpLog(filter)
	for _, line in LOG do
		if filter == nil or string.find(line.text, filter, 1, true) then
			print(`    [{line.side} {line.kind} {string.format("%.2f", line.t)}] {line.text}`)
		end
	end
end
function remotes(name, filter)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == name and (filter == nil or filter(e)) then
			table.insert(out, e)
		end
	end
	return out
end
function serverCalls(name)
	local out = {}
	for _, e in SERVER_CALLS do
		if e.name == name then
			table.insert(out, e)
		end
	end
	return out
end
function isDestroyed(inst)
	return rawget(inst, "_destroyed") == true
end
function hasTag(inst, tag)
	return (tagsOf[inst] or {})[tag] == true
end
function section(name)
	print("--- " .. name)
end
function summary(label)
	print(string.format("%s : %d vérification(s), %d échec(s)", label or "banc a27", CHECKS, FAILS))
end
