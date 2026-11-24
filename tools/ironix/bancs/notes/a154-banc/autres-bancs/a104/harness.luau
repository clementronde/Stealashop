-- Faux Roblox autonome du banc a104 (vague 31, L-112, 2026-11-12) : juste ce qu'il faut pour faire tourner
-- les vrais HeistController, ShelfOpenController et ShelfOpen/Logic hors Studio. CFrame à rotation complète
-- (matrice 3 × 3), modèles (pivot, boîte englobante, ScaleTo), CollectionService avec signaux, attributs,
-- invites, temps simulé (os.clock, heure du serveur, task.wait / delay, Heartbeat image par image).
-- Variables attendues avant ce fichier : SOURCES (clé = chemin sous src), SHELF_OPEN (true / false), VERBOSE.

local CHECKS, FAILS = 0, 0
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
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end
LOG = {}

---------------------------------------------------------------- types valeur
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return V3[k]
end
V3.__type = "Vector3"
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end
function V3.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1) }

-- CFrame : position p, rotation r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 } (colonnes = axes X, Y, Z).
local CF = {}
CF.__type = "CFrame"
local function cf(p, r)
	return setmetatable({ p = p, r = r }, CF)
end
local IDR = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function rmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function rvec(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function rT(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CF.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "Rotation" then
		return cf(v3(), c.r)
	elseif k == "LookVector" then
		return rvec(c.r, v3(0, 0, -1))
	elseif k == "UpVector" then
		return rvec(c.r, v3(0, 1, 0))
	elseif k == "RightVector" then
		return rvec(c.r, v3(1, 0, 0))
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return a.p + rvec(a.r, b)
	end
	return cf(a.p + rvec(a.r, b.p), rmul(a.r, b.r))
end
function CF.Inverse(c)
	local t = rT(c.r)
	return cf(-rvec(t, c.p), t)
end
function CF.PointToObjectSpace(c, v)
	return rvec(rT(c.r), v - c.p)
end
function CF.PointToWorldSpace(c, v)
	return c.p + rvec(c.r, v)
end
function CF.ToObjectSpace(c, o)
	return CF.Inverse(c) * o
end
function CF.ToWorldSpace(c, o)
	return c * o
end
CFrame = {}
function CFrame.new(x, y, z)
	if getmetatable(x) == V3 then
		return cf(x, IDR)
	end
	return cf(v3(x or 0, y or 0, z or 0), IDR)
end
function CFrame.fromAxisAngle(axis, a)
	local u = axis.Unit
	local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
	local x, y, z = u.X, u.Y, u.Z
	return cf(v3(), {
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
function CFrame.Angles(rx, ry, rz)
	return CFrame.fromAxisAngle(v3(1, 0, 0), rx) * CFrame.fromAxisAngle(v3(0, 1, 0), ry) * CFrame.fromAxisAngle(v3(0, 0, 1), rz)
end
CFrame.identity = CFrame.new()

local C3 = {}
C3.__index = C3
C3.__type = "Color3"
C3.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-4 and math.abs(a.G - b.G) < 1e-4 and math.abs(a.B - b.B) < 1e-4
end
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
function C3.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHex = function(hex)
		hex = string.gsub(hex, "#", "")
		return c3(tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255)
	end,
}
local function kp(t, v)
	return { Time = t, Value = v }
end
ColorSequenceKeypoint = { new = kp }
NumberSequenceKeypoint = { new = kp }
ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) == nil then
			return { Keypoints = a }
		end
		return { Keypoints = { kp(0, a), kp(1, b or a) } }
	end,
}
NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then
			return { Keypoints = a }
		end
		return { Keypoints = { kp(0, a), kp(1, b or a) } }
	end,
}
UDim2 = {
	new = function(a, b, c, d)
		return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } }
	end,
	fromScale = function(a, b)
		return { X = { Scale = a, Offset = 0 }, Y = { Scale = b, Offset = 0 } }
	end,
}
local function enumTable(path)
	return setmetatable({}, {
		__index = function(_, k)
			return enumTable(path .. "." .. k)
		end,
		__tostring = function()
			return path
		end,
	})
end
Enum = enumTable("Enum")

---------------------------------------------------------------- temps
simTime = 1000
serverOffset = 50000 -- heure du serveur = simTime + serverOffset
function serverNow()
	return simTime + serverOffset
end
local scheduled = {} -- { at, fn | co, args }
local taskLib = {}
function taskLib.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("  ERREUR tâche : " .. tostring(err))
		table.insert(LOG, { kind = "ERROR", text = tostring(err) })
	end
	return co
end
function taskLib.defer(f, ...)
	return taskLib.spawn(f, ...)
end
function taskLib.delay(t, f, ...)
	table.insert(scheduled, { at = simTime + (t or 0), fn = f, args = table.pack(...) })
end
function taskLib.wait(t)
	local co = coroutine.running()
	table.insert(scheduled, { at = simTime + (t or 0), co = co })
	coroutine.yield()
	return t or 0
end
local function runDue()
	local again = true
	while again do
		again = false
		for i, s in scheduled do
			if s.at <= simTime + 1e-9 then
				table.remove(scheduled, i)
				if s.co then
					taskLib.spawn(s.co)
				else
					taskLib.spawn(s.fn, table.unpack(s.args, 1, s.args.n))
				end
				again = true
				break
			end
		end
	end
end

---------------------------------------------------------------- signaux
local function newSignal()
	local sig = { list = {} }
	function sig:Connect(fn)
		local c = { fn = fn, Connected = true }
		table.insert(sig.list, c)
		function c:Disconnect()
			c.Connected = false
			local i = table.find(sig.list, c)
			if i then
				table.remove(sig.list, i)
			end
		end
		return c
	end
	function sig:Once(fn)
		local c
		c = sig:Connect(function(...)
			c:Disconnect()
			fn(...)
		end)
		return c
	end
	function sig:Fire(...)
		for _, c in table.clone(sig.list) do
			if c.Connected then
				local ok, err = pcall(c.fn, ...)
				if not ok then
					print("  ERREUR signal : " .. tostring(err))
					table.insert(LOG, { kind = "ERROR", text = tostring(err) })
				end
			end
		end
	end
	return sig
end

---------------------------------------------------------------- instances
local SUPER = {
	Part = "BasePart",
	MeshPart = "BasePart",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiObject",
	ImageLabel = "GuiObject",
	Texture = "Decal",
	BillboardGui = "LayerCollector",
	ScreenGui = "LayerCollector",
}
local DEFAULTS = {
	BasePart = { Transparency = 0, LocalTransparencyModifier = 0, Anchored = true, CanCollide = true, CanQuery = true, CanTouch = true },
	Decal = { LocalTransparencyModifier = 0, Transparency = 0 },
	Highlight = { FillTransparency = 0.5, OutlineTransparency = 0, Enabled = true },
	SelectionBox = { Visible = true },
	GuiObject = { Visible = true, Rotation = 0, BackgroundTransparency = 0 },
	LayerCollector = { Enabled = true },
	UIScale = { Scale = 1 },
	ProximityPrompt = { Enabled = true, HoldDuration = 0, MaxActivationDistance = 10, ActionText = "", ObjectText = "" },
	ParticleEmitter = { Rate = 5, Enabled = true },
	Beam = { Enabled = true, Width0 = 1, Width1 = 1 },
	PointLight = { Brightness = 1, Enabled = true },
	Sound = { PlaybackSpeed = 1 },
	Attachment = { Position = Vector3.zero },
}
local SIGNALS = { ChildAdded = true, ChildRemoved = true, Triggered = true, PromptButtonHoldBegan = true, Ended = true, DescendantAdded = true }

local Inst = {}
local Methods = {}
local function isA(class, want)
	if want == "Instance" then
		return true
	end
	local c = class
	while c do
		if c == want then
			return true
		end
		c = SUPER[c]
	end
	return false
end
local function defaultOf(class, key)
	local c = class
	while c do
		local d = DEFAULTS[c]
		if d and d[key] ~= nil then
			return d[key]
		end
		c = SUPER[c]
	end
	return nil
end

ROOT = nil -- DataModel
local tags = {} -- [inst] = { [tag] = true }
local tagAdded, tagRemoved = {}, {}
local function tagSignal(map, tag)
	map[tag] = map[tag] or newSignal()
	return map[tag]
end
local function inGame(inst)
	local c = inst
	while c do
		if c == ROOT then
			return true
		end
		c = rawget(c, "_parent")
	end
	return false
end
local function eachSelfAndDescendant(inst, fn)
	fn(inst)
	for _, child in rawget(inst, "_children") do
		eachSelfAndDescendant(child, fn)
	end
end

Inst.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "_parent")
	elseif k == "ClassName" then
		return rawget(self, "_class")
	end
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	local class = rawget(self, "_class")
	if k == "Position" and isA(class, "BasePart") then
		return props.CFrame.p
	elseif k == "WorldPosition" and class == "Attachment" then
		local parent = rawget(self, "_parent")
		local pos = props.Position or Vector3.zero
		return if parent and isA(rawget(parent, "_class"), "BasePart") then parent.CFrame * pos else pos
	elseif k == "WorldCFrame" and class == "Attachment" then
		local parent = rawget(self, "_parent")
		local c = CFrame.new(props.Position or Vector3.zero)
		return if parent and isA(rawget(parent, "_class"), "BasePart") then parent.CFrame * c else c
	end
	if SIGNALS[k] then
		local s = newSignal()
		props[k] = s
		return s
	end
	local m = Methods[k]
	if m then
		return m
	end
	local d = defaultOf(class, k)
	if d ~= nil then
		return d
	end
	return Methods.FindFirstChild(self, k)
end
Inst.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old == v then
			return
		end
		local wasIn = inGame(self)
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
			old.ChildRemoved:Fire(self)
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), self)
			v.ChildAdded:Fire(self)
		end
		local nowIn = inGame(self)
		if wasIn ~= nowIn then
			eachSelfAndDescendant(self, function(d)
				for tag in tags[d] or {} do
					tagSignal(if nowIn then tagAdded else tagRemoved, tag):Fire(d)
				end
			end)
		end
		return
	elseif k == "Position" and isA(rawget(self, "_class"), "BasePart") then
		local props = rawget(self, "_props")
		props.CFrame = cf(v, props.CFrame.r)
		return
	end
	rawget(self, "_props")[k] = v
end
Inst.__tostring = function(self)
	return self.Name
end
Inst.__type = "Instance"

function newInstance(class)
	local o = setmetatable({ _class = class, _props = { Name = class }, _children = {}, _attrs = {}, _attrSignals = {} }, Inst)
	if isA(class, "BasePart") then
		o._props.CFrame = CFrame.identity
		o._props.Size = v3(1, 1, 1)
	end
	if class == "Model" then
		o._props.Scale = 1
	end
	return o
end

function Methods.IsA(self, want)
	return isA(rawget(self, "_class"), want)
end
function Methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in rawget(i, "_children") do
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
		for _, c in rawget(self, "_children") do
			local f = Methods.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Methods.WaitForChild(self, name)
	local f = Methods.FindFirstChild(self, name)
	assert(f, "WaitForChild : " .. tostring(name) .. " absent de " .. tostring(self))
	return f
end
function Methods.FindFirstChildWhichIsA(self, class, recursive)
	for _, c in rawget(self, "_children") do
		if isA(rawget(c, "_class"), class) then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local f = Methods.FindFirstChildWhichIsA(c, class, true)
			if f then
				return f
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
function Methods.FindFirstAncestorWhichIsA(self, class)
	local c = rawget(self, "_parent")
	while c do
		if isA(rawget(c, "_class"), class) then
			return c
		end
		c = rawget(c, "_parent")
	end
	return nil
end
function Methods.IsDescendantOf(self, other)
	local c = rawget(self, "_parent")
	while c do
		if c == other then
			return true
		end
		c = rawget(c, "_parent")
	end
	return false
end
function Methods.GetAttribute(self, k)
	return rawget(self, "_attrs")[k]
end
function Methods.GetAttributes(self)
	return table.clone(rawget(self, "_attrs"))
end
function Methods.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
	local s = rawget(self, "_attrSignals")[k]
	if s then
		s:Fire()
	end
end
function Methods.GetAttributeChangedSignal(self, k)
	local map = rawget(self, "_attrSignals")
	map[k] = map[k] or newSignal()
	return map[k]
end
function Methods.Destroy(self)
	self.Parent = nil
	rawset(self, "_destroyed", true)
	for _, c in table.clone(rawget(self, "_children")) do
		Methods.Destroy(c)
	end
end
function Methods.ClearAllChildren(self)
	for _, c in table.clone(rawget(self, "_children")) do
		Methods.Destroy(c)
	end
end
function Methods.Clone(self)
	local o = newInstance(rawget(self, "_class"))
	for k, v in rawget(self, "_props") do
		if not (type(v) == "table" and v.list and v.Fire) then -- pas les signaux
			rawget(o, "_props")[k] = v
		end
	end
	for k, v in rawget(self, "_attrs") do
		rawget(o, "_attrs")[k] = v
	end
	if tags[self] then
		tags[o] = table.clone(tags[self])
	end
	for _, c in rawget(self, "_children") do
		Methods.Clone(c).Parent = o
	end
	return o
end
-- Pièces
function Methods.Emit(self, n)
	rawset(self, "_emitted", (rawget(self, "_emitted") or 0) + n)
end
function Methods.Play(self)
	rawset(self, "_playing", true)
end
function Methods.Stop(self)
	rawset(self, "_playing", false)
end
-- Modèles
local function partsOf(model)
	local out = {}
	for _, d in Methods.GetDescendants(model) do
		if isA(rawget(d, "_class"), "BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
local function modelsOf(model)
	local out = {}
	for _, d in Methods.GetDescendants(model) do
		if rawget(d, "_class") == "Model" then
			table.insert(out, d)
		end
	end
	return out
end
function Methods.GetPivot(self)
	if rawget(self, "_class") ~= "Model" then
		return self.CFrame
	end
	local props = rawget(self, "_props")
	if props.WorldPivot then
		return props.WorldPivot
	end
	local primary = props.PrimaryPart
	if primary then
		return primary.CFrame
	end
	local p = Methods.FindFirstChildWhichIsA(self, "BasePart", true)
	return if p then p.CFrame else CFrame.identity
end
function Methods.PivotTo(self, target)
	if rawget(self, "_class") ~= "Model" then
		self.CFrame = target
		return
	end
	local delta = target * Methods.GetPivot(self):Inverse()
	for _, part in partsOf(self) do
		part.CFrame = delta * part.CFrame
	end
	for _, m in modelsOf(self) do
		local wp = rawget(m, "_props").WorldPivot
		if wp then
			rawget(m, "_props").WorldPivot = delta * wp
		end
	end
	rawget(self, "_props").WorldPivot = target
end
function Methods.GetBoundingBox(self)
	local pivot = Methods.GetPivot(self)
	local lo = v3(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, part in partsOf(self) do
		local h = part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = pivot:PointToObjectSpace(part.CFrame:PointToWorldSpace(v3(sx * h.X, sy * h.Y, sz * h.Z)))
					lo = lo:Min(p)
					hi = hi:Max(p)
				end
			end
		end
	end
	return pivot * CFrame.new((lo + hi) / 2), hi - lo
end
function Methods.GetScale(self)
	return rawget(self, "_props").Scale or 1
end
function Methods.ScaleTo(self, s)
	assert(s > 0, "ScaleTo : échelle ≤ 0")
	local props = rawget(self, "_props")
	local factor = s / (props.Scale or 1)
	local pivot = Methods.GetPivot(self)
	for _, part in partsOf(self) do
		local rel = pivot:ToObjectSpace(part.CFrame)
		part.CFrame = pivot * cf(rel.p * factor, rel.r)
		part.Size = part.Size * factor
	end
	for _, d in Methods.GetDescendants(self) do
		if rawget(d, "_class") == "Attachment" then
			d.Position = (d.Position or Vector3.zero) * factor
		end
	end
	for _, m in modelsOf(self) do
		local wp = rawget(m, "_props").WorldPivot
		if wp then
			local rel = pivot:ToObjectSpace(wp)
			rawget(m, "_props").WorldPivot = pivot * cf(rel.p * factor, rel.r)
		end
		rawget(m, "_props").Scale = (rawget(m, "_props").Scale or 1) * factor
	end
	props.Scale = s
	props.WorldPivot = pivot
end
-- Workspace
function Methods.GetServerTimeNow(_self)
	return serverNow()
end

InstanceAPI = { new = newInstance }

---------------------------------------------------------------- services
ROOT = newInstance("DataModel")
ROOT.Name = "game"
Workspace = newInstance("Workspace")
Workspace.Name = "Workspace"
Workspace.Parent = ROOT
ReplicatedStorage = newInstance("ReplicatedStorage")
ReplicatedStorage.Name = "ReplicatedStorage"
ReplicatedStorage.Parent = ROOT
PlayersService = newInstance("Players")
PlayersService.Name = "Players"
PlayersService.Parent = ROOT
SoundService = newInstance("SoundService")
SoundService.Parent = ROOT
local camera = newInstance("Camera")
camera.CFrame = CFrame.new(0, 10, 20)
camera.Parent = Workspace
Workspace.CurrentCamera = camera

CollectionService = {}
function CollectionService:AddTag(inst, tag)
	tags[inst] = tags[inst] or {}
	if tags[inst][tag] then
		return
	end
	tags[inst][tag] = true
	if inGame(inst) then
		tagSignal(tagAdded, tag):Fire(inst)
	end
end
function CollectionService:RemoveTag(inst, tag)
	if tags[inst] and tags[inst][tag] then
		tags[inst][tag] = nil
		if inGame(inst) then
			tagSignal(tagRemoved, tag):Fire(inst)
		end
	end
end
function CollectionService:HasTag(inst, tag)
	return tags[inst] ~= nil and tags[inst][tag] == true
end
function CollectionService:GetTagged(tag)
	local out = {}
	for inst, set in tags do
		if set[tag] and inGame(inst) then
			table.insert(out, inst)
		end
	end
	return out
end
function CollectionService:GetInstanceAddedSignal(tag)
	return tagSignal(tagAdded, tag)
end
function CollectionService:GetInstanceRemovedSignal(tag)
	return tagSignal(tagRemoved, tag)
end

HEARTBEAT = newSignal()
local RunService = {
	Heartbeat = HEARTBEAT,
	RenderStepped = newSignal(),
	IsStudio = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsServer = function()
		return false
	end,
}
local Debris = {
	AddItem = function() end,
}
local TweenService = {
	GetValue = function(_, t)
		return t
	end,
}
local services = {
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
	Players = PlayersService,
	CollectionService = CollectionService,
	RunService = RunService,
	Debris = Debris,
	SoundService = SoundService,
	TweenService = TweenService,
}
local game = setmetatable({
	GetService = function(_, name)
		return services[name] or error("service bouchonné absent : " .. name)
	end,
}, { __index = function(_, k)
	return services[k]
end })

-- Pas de temps : une image de 1/60 s, Heartbeat, puis les tâches dues.
function advance(seconds)
	local frames = math.max(1, math.floor(seconds * 60 + 0.5))
	for _ = 1, frames do
		simTime += 1 / 60
		runDue()
		HEARTBEAT:Fire(1 / 60)
	end
end

---------------------------------------------------------------- modules
local moduleSource = {} -- [ModuleScript] = clé de SOURCES ou { value = table }
function moduleScript(parent, name, key)
	local m = newInstance("ModuleScript")
	m.Name = name
	m.Parent = parent
	moduleSource[m] = key
	return m
end
local cache = {}
local function typeofStub(v)
	local mt = getmetatable(v)
	if type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
end
function requireModule(m)
	if cache[m] ~= nil then
		return cache[m]
	end
	local key = moduleSource[m]
	assert(key ~= nil, "require d'un objet qui n'est pas un ModuleScript du banc : " .. tostring(m))
	if type(key) == "table" then
		cache[m] = key.value
		return key.value
	end
	local source = SOURCES[key]
	assert(source, "source absente : " .. key)
	local fn, err = loadstring(source, key)
	assert(fn, err)
	local env = setmetatable({
		game = game,
		workspace = Workspace,
		script = m,
		require = requireModule,
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
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		UDim2 = UDim2,
		Enum = Enum,
		Instance = InstanceAPI,
		typeof = typeofStub,
		warn = function(...)
			local parts = table.pack(...)
			for i = 1, parts.n do
				parts[i] = tostring(parts[i])
			end
			table.insert(LOG, { kind = "WARN", text = table.concat(parts, " ") })
		end,
		print = function(...)
			local parts = table.pack(...)
			for i = 1, parts.n do
				parts[i] = tostring(parts[i])
			end
			table.insert(LOG, { kind = "PRINT", text = table.concat(parts, " ") })
		end,
	}, { __index = _G })
	setfenv(fn, env)
	local result = fn()
	cache[m] = result
	return result
end
function logHas(text, kind)
	for _, l in LOG do
		if (kind == nil or l.kind == kind) and string.find(l.text, text, 1, true) then
			return true
		end
	end
	return false
end
function errorsInLog()
	local n = 0
	for _, l in LOG do
		if l.kind == "ERROR" or (l.kind == "WARN" and string.find(l.text, "Controller]", 1, true)) then
			n += 1
			print("    " .. l.text)
		end
	end
	return n
end

function finish(name)
	print(string.format("%s : %d vérification(s), %d échec(s)", name, CHECKS, FAILS))
end

function folder(parent, name)
	local f = newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- pc-steal (2026-11-14) : GetPropertyChangedSignal(nom) au faux Roblox du banc a104 (HeistController s'en sert
-- pour garder la portée de l'invite de l'objet sorti), déclenché quand la propriété change vraiment.
local propSignals = setmetatable({}, { __mode = "k" })
function Methods.GetPropertyChangedSignal(self, k)
	local map = propSignals[self]
	if map == nil then
		map = {}
		propSignals[self] = map
	end
	map[k] = map[k] or newSignal()
	return map[k]
end
local baseNewindexSignal = Inst.__newindex
Inst.__newindex = function(self, k, v)
	local old = self[k]
	baseNewindexSignal(self, k, v)
	local map = propSignals[self]
	if map and map[k] and old ~= v then
		map[k]:Fire()
	end
end
