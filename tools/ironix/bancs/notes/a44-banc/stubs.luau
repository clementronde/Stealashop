--!nocheck
-- Banc d'essai hors Studio de la casse de vitrine (agent a16, DEV-016) : WindowService (diffusion
-- des coups), WindowController (registre, BB_WindowHP), HitController (retour local) et
-- ShatterController (fissures, casse, éclats). Bouchons Roblox repris du banc d'a14, étendus :
-- rotations quelconques, rayons contre des boîtes orientées, tweens, sons, particules, Enum avec
-- valeurs. Temps simulé, un seul VM, arbre d'instances partagé entre « serveur » et « client ».
-- Les propriétés écrites doivent exister dans PROPS : une faute de frappe dans le code lève une
-- erreur, comme dans Roblox (« X is not a valid member of … »).
-- Copie a34 (vague 12, DEV-053, retours de frappe) : + Workspace:GetServerTimeNow (TruckController),
-- CollectionService:RemoveTag (WindowService.RemoveTarget, camion retiré) et la classe Explosion.

SOURCES = {}
FAILS = 0
CHECKS = 0
LOG = {} -- { side, kind, text }

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
local V3METHODS = {
	Dot = function(a, b)
		return a.X * b.X + a.Y * b.Y + a.Z * b.Z
	end,
	Cross = function(a, b)
		return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
	end,
	Min = function(a, b)
		return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	end,
	Max = function(a, b)
		return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	end,
	Lerp = function(a, b, t)
		return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
	end,
}
V3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	local method = V3METHODS[k]
	if method then
		return method
	end
	error("Vector3 : membre inconnu " .. tostring(k), 2)
end
V3MT.__add = function(a, b)
	assert(getmetatable(a) == V3MT and getmetatable(b) == V3MT, "Vector3 + : opérande invalide")
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3MT.__sub = function(a, b)
	assert(getmetatable(a) == V3MT and getmetatable(b) == V3MT, "Vector3 - : opérande invalide")
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

local V2MT = { __type = "Vector2" }
V2MT.__index = V2MT
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2MT)
	end,
}

---------------------------------------------------------------- CFrame (rotations quelconques)
-- r = matrice 3×3 par lignes ; colonnes = axes X, Y, Z du repère.
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
local function axisAngleR(axis, angle)
	local m = axis.Magnitude
	local x, y, z = axis.X / m, axis.Y / m, axis.Z / m
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	return {
		t * x * x + c,
		t * x * y - s * z,
		t * x * z + s * y,
		t * x * y + s * z,
		t * y * y + c,
		t * y * z - s * x,
		t * x * z - s * y,
		t * y * z + s * x,
		t * z * z + c,
	}
end
-- Axe et angle d'une matrice de rotation.
local function toAxisAngle(r)
	local trace = r[1] + r[5] + r[9]
	local angle = math.acos(math.clamp((trace - 1) / 2, -1, 1))
	if angle < 1e-6 then
		return v3(0, 1, 0), 0
	end
	local axis = v3(r[8] - r[6], r[3] - r[7], r[4] - r[2])
	if axis.Magnitude < 1e-6 then
		-- angle ≈ π : axe = colonne dominante de (R + I) / 2
		local xx, yy, zz = (r[1] + 1) / 2, (r[5] + 1) / 2, (r[9] + 1) / 2
		if xx >= yy and xx >= zz then
			axis = v3(math.sqrt(xx), r[2] / 2 / math.sqrt(xx), r[3] / 2 / math.sqrt(xx))
		elseif yy >= zz then
			axis = v3(r[2] / 2 / math.sqrt(yy), math.sqrt(yy), r[6] / 2 / math.sqrt(yy))
		else
			axis = v3(r[3] / 2 / math.sqrt(zz), r[6] / 2 / math.sqrt(zz), math.sqrt(zz))
		end
	end
	return axis.Unit, angle
end
local CFMETHODS = {
	PointToObjectSpace = function(self, v)
		return mulRtV(self.r, v - self.p)
	end,
	PointToWorldSpace = function(self, v)
		return self.p + mulRV(self.r, v)
	end,
	VectorToObjectSpace = function(self, v)
		return mulRtV(self.r, v)
	end,
	VectorToWorldSpace = function(self, v)
		return mulRV(self.r, v)
	end,
	Inverse = function(self)
		local rt = transpose(self.r)
		return cf(-mulRV(rt, self.p), rt)
	end,
	ToObjectSpace = function(self, other)
		return self:Inverse() * other
	end,
	ToWorldSpace = function(self, other)
		return self * other
	end,
	Lerp = function(a, b, t)
		local rel = mulRR(transpose(a.r), b.r)
		local axis, angle = toAxisAngle(rel)
		local r = if angle < 1e-9 then a.r else mulRR(a.r, axisAngleR(axis, angle * t))
		return cf(a.p:Lerp(b.p, t), r)
	end,
}
CFMT.__index = function(c, k)
	local r = c.r
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "RightVector" or k == "XVector" then
		return v3(r[1], r[4], r[7])
	elseif k == "UpVector" or k == "YVector" then
		return v3(r[2], r[5], r[8])
	elseif k == "ZVector" then
		return v3(r[3], r[6], r[9])
	elseif k == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif k == "Rotation" then
		return cf(v3(0, 0, 0), r)
	end
	local method = CFMETHODS[k]
	if method then
		return method
	end
	error("CFrame : membre inconnu " .. tostring(k), 2)
end
CFMT.__mul = function(a, b)
	if getmetatable(b) == V3MT then
		return a.p + mulRV(a.r, b)
	end
	assert(getmetatable(b) == CFMT, "CFrame * : opérande invalide")
	return cf(a.p + mulRV(a.r, b.p), mulRR(a.r, b.r))
end
CFMT.__add = function(a, b)
	assert(getmetatable(b) == V3MT, "CFrame + : Vector3 attendu")
	return cf(a.p + b, a.r)
end
CFMT.__sub = function(a, b)
	assert(getmetatable(b) == V3MT, "CFrame - : Vector3 attendu")
	return cf(a.p - b, a.r)
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
-- Comme Roblox : CFrame.Angles(rx, ry, rz) = Rx · Ry · Rz.
function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx or 0), math.sin(rx or 0)
	local cy, sy = math.cos(ry or 0), math.sin(ry or 0)
	local cz, sz = math.cos(rz or 0), math.sin(rz or 0)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(v3(0, 0, 0), mulRR(mulRR(Rx, Ry), Rz))
end
function CFrame.fromAxisAngle(axis, angle)
	return cf(v3(0, 0, 0), axisAngleR(axis, angle))
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return cf(pos, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
CFrame.identity = CFrame.new(0, 0, 0)

-- Écart d'orthonormalité d'une CFrame (contrôle des calculs du code).
function orthoError(c)
	local x, y, z = c.RightVector, c.UpVector, c.ZVector
	return math.max(
		math.abs(x.Magnitude - 1),
		math.abs(y.Magnitude - 1),
		math.abs(z.Magnitude - 1),
		math.abs(x:Dot(y)),
		math.abs(y:Dot(z)),
		math.abs(x:Dot(z)),
		(x:Cross(y) - z).Magnitude
	)
end

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
	assert(type(a) == "number", "NumberRange.new : nombre attendu")
	return { Min = a, Max = b or a }
end) }
NumberSequenceKeypoint = { new = valueType("NumberSequenceKeypoint", function(t, v)
	return { Time = t, Value = v }
end) }
NumberSequence = { new = valueType("NumberSequence", function(a, b)
	if type(a) == "table" then
		assert(#a >= 2 and a[1].Time == 0 and a[#a].Time == 1, "NumberSequence : il faut des points en 0 et en 1")
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
UDim = { new = valueType("UDim", function(s, o)
	return { Scale = s or 0, Offset = o or 0 }
end) }
local function udim2(xs, xo, ys, yo)
	local x, y = UDim.new(xs, xo), UDim.new(ys, yo)
	return { X = x, Y = y, Width = x, Height = y }
end
UDim2 = {
	new = valueType("UDim2", udim2),
	fromScale = valueType("UDim2", function(x, y)
		return udim2(x, 0, y, 0)
	end),
	fromOffset = valueType("UDim2", function(x, y)
		return udim2(0, x, 0, y)
	end),
}
TweenInfo = { new = valueType("TweenInfo", function(t, style, direction)
	return { Time = t or 1, EasingStyle = style, EasingDirection = direction }
end) }
Font = { fromEnum = valueType("Font", function(e)
	return { Family = e }
end) }

-- Enum : chaque valeur est unique (comparable) et porte Name et Value.
local ENUM_VALUES = {
	RenderPriority = { First = 0, Input = 100, Camera = 200, Character = 300, Last = 2000 },
	SavedQualitySetting = { Automatic = 0 },
}
for i = 1, 10 do
	ENUM_VALUES.SavedQualitySetting["QualityLevel" .. i] = i
end
local enumItems = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				local key = enumName .. "." .. item
				local existing = enumItems[key]
				if existing then
					return existing
				end
				local values = ENUM_VALUES[enumName]
				local entry = setmetatable(
					{ Name = item, EnumType = enumName, Value = if values then values[item] or 0 else 0 },
					{ __tostring = function()
						return "Enum." .. key
					end, __type = "EnumItem" }
				)
				enumItems[key] = entry
				return entry
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
RENDER_STEPS = {} -- [nom] = { priority, fn }
-- Avance le temps de `seconds`, image par image (étapes de rendu, puis Heartbeat).
function step(seconds, fps)
	local dt = 1 / (fps or 60)
	local frames = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, frames do
		local target = simTime + dt
		runQueue(target)
		simTime = target
		local steps = {}
		for _, entry in RENDER_STEPS do
			table.insert(steps, entry)
		end
		table.sort(steps, function(a, b)
			return a.priority < b.priority
		end)
		for _, entry in steps do
			taskLib.spawn(entry.fn, dt)
		end
		HEARTBEAT:Fire(dt)
	end
	runQueue(simTime)
end

---------------------------------------------------------------- instances
local ISA = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance", "TriangleMeshPart" },
	Terrain = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance", "WorldRoot" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	SurfaceGui = { "SurfaceGuiBase", "LayerCollector", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiObject", "GuiBase2d" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	UIScale = { "UIComponent" },
	UIStroke = { "UIComponent" },
	PointLight = { "Light" },
	ColorCorrectionEffect = { "PostEffect" },
	Decal = { "FaceInstance" },
	Texture = { "Decal", "FaceInstance" },
	Weld = { "JointInstance" },
	WeldConstraint = {},
	Tool = { "BackpackItem" },
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
		LocalTransparencyModifier = 0,
		Size = v3(4, 1, 2),
		CFrame = CFrame.identity,
		PivotOffset = CFrame.identity,
		Color = Color3.new(0.6, 0.6, 0.6),
		Material = Enum.Material.Plastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}
end
local function meshPart()
	local t = basePart()
	t.MeshId = ""
	t.TextureID = ""
	t.CollisionFidelity = Enum.CollisionFidelity.Box
	return t
end
local function guiObject(extra)
	local t = {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0, 0),
		Rotation = 0,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 1,
		Visible = true,
		ZIndex = 1,
		ClipsDescendants = false,
		LayoutOrder = 0,
	}
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end
local TEXT = {
	Text = "Label",
	TextScaled = false,
	TextSize = 14,
	TextWrapped = false,
	Font = Enum.Font.SourceSans,
	FontFace = Font.fromEnum(Enum.Font.SourceSans),
	TextColor3 = Color3.new(0, 0, 0),
	TextTransparency = 0,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 1,
}
local function layerCollector(extra)
	local t = { Enabled = true, ResetOnSpawn = true }
	for k, v in extra do
		t[k] = v
	end
	return t
end
local PROPS = {
	Part = basePart,
	MeshPart = meshPart,
	Terrain = basePart,
	Model = function()
		return { PrimaryPart = NONE, WorldPivot = CFrame.identity }
	end,
	Folder = function()
		return {}
	end,
	Attachment = function()
		return { CFrame = CFrame.identity, Visible = false }
	end,
	PointLight = function()
		return { Color = Color3.new(1, 1, 1), Brightness = 1, Range = 8, Shadows = false, Enabled = true }
	end,
	ParticleEmitter = function()
		return {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			LightEmission = 0,
			LightInfluence = 1,
			Brightness = 1,
			Rate = 5,
			Lifetime = NumberRange.new(5, 10),
			Speed = NumberRange.new(5, 5),
			SpreadAngle = Vector2.new(0, 0),
			Acceleration = v3(0, 0, 0),
			Drag = 0,
			Size = NumberSequence.new(1),
			Transparency = NumberSequence.new(0),
			Rotation = NumberRange.new(0, 0),
			RotSpeed = NumberRange.new(0, 0),
			EmissionDirection = Enum.NormalId.Top,
			LockedToPart = false,
			ZOffset = 0,
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Enabled = true,
		}
	end,
	BillboardGui = function()
		return layerCollector({
			Size = UDim2.fromScale(0, 0),
			StudsOffset = v3(0, 0, 0),
			StudsOffsetWorldSpace = v3(0, 0, 0),
			MaxDistance = math.huge,
			LightInfluence = 1,
			Adornee = NONE,
			AlwaysOnTop = false,
		})
	end,
	SurfaceGui = function()
		return layerCollector({
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
			PixelsPerStud = 50,
			CanvasSize = Vector2.new(800, 600),
			LightInfluence = 1,
			Brightness = 1,
			MaxDistance = 0,
			Adornee = NONE,
			AlwaysOnTop = false,
			ZOffset = 0,
		})
	end,
	ScreenGui = function()
		return layerCollector({ IgnoreGuiInset = false, DisplayOrder = 0, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	end,
	Frame = function()
		return guiObject()
	end,
	ImageLabel = function()
		return guiObject({
			Image = "",
			ImageTransparency = 0,
			ImageColor3 = Color3.new(1, 1, 1),
			ScaleType = Enum.ScaleType.Stretch,
		})
	end,
	TextLabel = function()
		return guiObject(TEXT)
	end,
	TextButton = function()
		return guiObject(TEXT)
	end,
	UIScale = function()
		return { Scale = 1 }
	end,
	UIStroke = function()
		return { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0 }
	end,
	ColorCorrectionEffect = function()
		return { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1), Enabled = true }
	end,
	Sound = function()
		return { SoundId = "", Volume = 0.5, PlaybackSpeed = 1, Playing = false, Looped = false, TimePosition = 0 }
	end,
	Decal = function()
		return { Texture = "", Transparency = 0, Face = Enum.NormalId.Front, Color3 = Color3.new(1, 1, 1) }
	end,
	Humanoid = function()
		return { Health = 100, WalkSpeed = 16 }
	end,
	Animator = function()
		return {}
	end,
	Player = function()
		return { UserId = 0, Character = NONE, DisplayName = "" }
	end,
	PlayerGui = function()
		return {}
	end,
	Players = function()
		return { LocalPlayer = NONE }
	end,
	Workspace = function()
		return { CurrentCamera = NONE, Gravity = 196.2 }
	end,
	Camera = function()
		return { CFrame = CFrame.identity, FieldOfView = 70 }
	end,
	Tool = function()
		return { RequiresHandle = false, CanBeDropped = false, ToolTip = "" }
	end,
	WeldConstraint = function()
		return { Part0 = NONE, Part1 = NONE }
	end,
	-- a34 : explosion native du camion (TruckController, ExplosionFx).
	Explosion = function()
		return { Position = v3(0, 0, 0), BlastRadius = 4, BlastPressure = 500000, DestroyJointRadiusPercent = 1, ExplosionType = Enum.ExplosionType.Craters }
	end,
}
local EVENTS = {
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	AncestryChanged = true,
	Destroying = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	Activated = true,
	Ended = true,
	Touched = true,
	OnServerEvent = true,
	OnClientEvent = true,
}

local Methods = {}
InstanceMT = { __type = "Instance" }
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

local function descendantsOf(inst)
	local out = {}
	local function walk(i)
		for _, c in rawget(i, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(inst)
	return out
end

local function setParent(self, parent)
	if rawget(self, "_destroyed") then
		error("Parent verrouillé : instance détruite", 3)
	end
	local old = rawget(self, "_parent")
	if old == parent then
		return
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
	self.AncestryChanged:Fire(self, parent)
	for _, d in descendantsOf(self) do
		rawget(d, "_signals").AncestryChanged = rawget(d, "_signals").AncestryChanged or newSignal()
		rawget(d, "_signals").AncestryChanged:Fire(self, parent)
	end
	if parent then
		parent.ChildAdded:Fire(self)
		local added = { self }
		for _, d in descendantsOf(self) do
			table.insert(added, d)
		end
		local ancestor = parent
		while ancestor do
			for _, d in added do
				ancestor.DescendantAdded:Fire(d)
			end
			ancestor = rawget(ancestor, "_parent")
		end
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
	if key == "CanQuery" and value == false and props.CanCollide == true then
		error(`{class} : CanQuery ne passe à false que si CanCollide est déjà false (comme Roblox)`, 2)
	end
	if key == "Size" and getmetatable(value) == V3MT and (value.X < 0.001 or value.Y < 0.001 or value.Z < 0.001) then
		error(`{class} : taille trop petite {value}`, 2)
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
	return descendantsOf(self)
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, d in descendantsOf(self) do
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
	local list = if recursive then descendantsOf(self) else rawget(self, "_children")
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
	if rawget(self, "_props").Archivable == false then
		return nil
	end
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
-- Boîte dans l'orientation du pivot du modèle (comme Studio).
function Methods.GetBoundingBox(self)
	local rot = Methods.GetPivot(self).Rotation
	local lo, hi
	for _, d in descendantsOf(self) do
		if isA(d, "BasePart") then
			local c, h = d.CFrame, d.Size / 2
			for i = 0, 7 do
				local corner = v3(if i % 2 == 0 then -h.X else h.X, if (i // 2) % 2 == 0 then -h.Y else h.Y, if i // 4 == 0 then -h.Z else h.Z)
				local p = rot:PointToObjectSpace(c:PointToWorldSpace(corner))
				lo = if lo then lo:Min(p) else p
				hi = if hi then hi:Max(p) else p
			end
		end
	end
	if lo == nil then
		return Methods.GetPivot(self), v3(0, 0, 0)
	end
	return rot + rot:PointToWorldSpace((lo + hi) / 2), hi - lo
end
function Methods.PivotTo(self, target)
	local delta = target * Methods.GetPivot(self):Inverse()
	if isA(self, "BasePart") then
		self.CFrame = delta * self.CFrame
		return
	end
	for _, d in descendantsOf(self) do
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
-- Sons et particules : journal des lectures.
SOUND_LOG = {}
EMIT_LOG = {}
function Methods.Play(self)
	assert(rawget(self, "_class") == "Sound", "Play sur un objet qui n'est pas un Sound")
	local parent = rawget(self, "_parent")
	table.insert(SOUND_LOG, {
		t = simTime,
		name = self.Name,
		speed = self.PlaybackSpeed,
		at = if parent and rawget(parent, "_class") == "Attachment" then parent.Position else nil,
	})
	taskLib.delay(0.5, function()
		if not rawget(self, "_destroyed") then
			self.Ended:Fire(self.SoundId)
		end
	end)
end
function Methods.Stop(_self) end
function Methods.Emit(self, count)
	assert(rawget(self, "_class") == "ParticleEmitter", "Emit sur un objet qui n'est pas un ParticleEmitter")
	local parent = rawget(self, "_parent")
	table.insert(EMIT_LOG, {
		t = simTime,
		texture = self.Texture,
		count = count,
		at = if parent then parent.Position else nil,
		up = if parent then parent.CFrame.UpVector else nil,
	})
end
-- Animator du personnage : pistes factices.
function Methods.GetPlayingAnimationTracks(self)
	local out = {}
	for _, track in rawget(self, "_tracks") or {} do
		if track.IsPlaying then
			table.insert(out, track)
		end
	end
	return out
end
function newTrack(name)
	local markers = {}
	local track = { Name = name, Speed = 1, IsPlaying = true, Length = 0.6 }
	function track.AdjustSpeed(selfTrack, speed)
		selfTrack.Speed = speed
	end
	function track.GetMarkerReachedSignal(_selfTrack, marker)
		markers[marker] = markers[marker] or newSignal()
		return markers[marker]
	end
	function track.FireMarker(_selfTrack, marker)
		if markers[marker] then
			markers[marker]:Fire("")
		end
	end
	return track
end

---------------------------------------------------------------- Workspace : rayons et déplacements groupés
local RPMT = { __type = "RaycastParams" }
local RP_KNOWN = { FilterType = true, FilterDescendantsInstances = true, RespectCanCollide = true, IgnoreWater = true, CollisionGroup = true }
RPMT.__index = function(_, k)
	error("RaycastParams : membre inconnu " .. tostring(k), 2)
end
RPMT.__newindex = function(t, k, v)
	if not RP_KNOWN[k] then
		error("RaycastParams : propriété inconnue " .. tostring(k), 2)
	end
	rawset(t, k, v)
end
RaycastParams = {
	new = function()
		local t = setmetatable({}, RPMT)
		rawset(t, "FilterType", Enum.RaycastFilterType.Exclude)
		rawset(t, "FilterDescendantsInstances", {})
		rawset(t, "RespectCanCollide", false)
		rawset(t, "IgnoreWater", false)
		rawset(t, "CollisionGroup", "Default")
		return t
	end,
}
RAYCASTS = 0

-- Rayon (origine, direction unitaire) contre la boîte orientée (c, size) : distance et normale.
local function rayBox(origin, dir, c, size)
	local o = c:PointToObjectSpace(origin)
	local v = c:VectorToObjectSpace(dir)
	local h = size / 2
	local tmin, tmax = -math.huge, math.huge
	local normal = nil
	for _, axis in { "X", "Y", "Z" } do
		local oa, va, ha = o[axis], v[axis], h[axis]
		if math.abs(va) < 1e-12 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local t1, t2 = (-ha - oa) / va, (ha - oa) / va
			local n1 = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				n1 = 1
			end
			if t1 > tmin then
				tmin = t1
				normal = v3(if axis == "X" then n1 else 0, if axis == "Y" then n1 else 0, if axis == "Z" then n1 else 0)
			end
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	if tmin < 0 or normal == nil then
		return nil -- rayon parti de l'intérieur (Roblox ne détecte pas cette pièce) ou derrière
	end
	return tmin, c:VectorToWorldSpace(normal)
end

local function excluded(part, list)
	for _, item in list do
		if part == item or Methods.IsDescendantOf(part, item) then
			return true
		end
	end
	return false
end

function Methods.Raycast(self, origin, direction, params)
	assert(getmetatable(origin) == V3MT and getmetatable(direction) == V3MT, "Raycast : Vector3 attendus")
	RAYCASTS += 1
	local length = direction.Magnitude
	if length < 1e-9 then
		return nil
	end
	local dir = direction / length
	local list = if params then rawget(params, "FilterDescendantsInstances") else {}
	local respect = params ~= nil and rawget(params, "RespectCanCollide") == true
	local best = nil
	for _, d in descendantsOf(self) do
		if isA(d, "BasePart") and rawget(d, "_class") ~= "Terrain" then
			local usable = if respect then d.CanCollide else d.CanQuery
			if usable and not excluded(d, list) then
				local t, normal = rayBox(origin, dir, d.CFrame, d.Size)
				if t and t <= length and (best == nil or t < best.t) then
					best = { t = t, normal = normal, part = d }
				end
			end
		end
	end
	if best == nil then
		return nil
	end
	return { Position = origin + dir * best.t, Normal = best.normal, Instance = best.part, Distance = best.t }
end
-- Heure serveur : le temps simulé (un seul VM, horloges confondues).
function Methods.GetServerTimeNow(_self)
	return simTime
end
BULK_MOVES = 0
function Methods.BulkMoveTo(self, parts, cframes, _mode)
	assert(#parts == #cframes, "BulkMoveTo : listes de tailles différentes")
	BULK_MOVES += 1
	for i, part in parts do
		assert(isA(part, "BasePart"), "BulkMoveTo : pas une BasePart")
		assert(getmetatable(cframes[i]) == CFMT, "BulkMoveTo : pas une CFrame")
		rawget(part, "_props").CFrame = cframes[i]
	end
end

-- Remotes : pas de vrai réseau, voir le faux Net plus bas.
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
	RemoveTag = function(_, inst, tag)
		if tagsOf[inst] and tagsOf[inst][tag] then
			tagsOf[inst][tag] = nil
			CollectionServiceRemoved(inst, tag)
		end
	end,
	HasTag = function(_, inst, tag)
		return tagsOf[inst] ~= nil and tagsOf[inst][tag] == true
	end,
}

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
SoundServiceStub = service("Folder")
SoundServiceStub.Name = "SoundService"

function folder(parent, name)
	local f = newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
function new(class, props, parent)
	local inst = newInstance(class)
	props = props or {}
	if props.CanCollide ~= nil then
		inst.CanCollide = props.CanCollide -- avant CanQuery, comme l'exige Roblox
	end
	for k, v in props do
		if k ~= "CanCollide" then
			inst[k] = v
		end
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

---------------------------------------------------------------- services bouchonnés
TWEENS = {}
TweenServiceStub = {
	Create = function(_, inst, info, goals)
		assert(getmetatable(inst) == InstanceMT, "TweenService:Create : instance attendue")
		for k in goals do
			if rawget(inst, "_known")[k] == nil then
				error(`TweenService:Create : propriété inconnue « {k} » sur {rawget(inst, "_class")}`, 2)
			end
		end
		local tween = { Completed = newSignal(), Instance = inst, Goals = goals, Info = info }
		function tween.Play(t)
			table.insert(TWEENS, t)
			taskLib.delay(info.Time, function()
				if rawget(inst, "_destroyed") then
					return
				end
				for k, v in goals do
					inst[k] = v
				end
				t.Completed:Fire(Enum.PlaybackState.Completed)
			end)
		end
		function tween.Cancel(_t) end
		return tween
	end,
}
DebrisStub = {
	AddItem = function(_, inst, lifetime)
		taskLib.delay(lifetime or 10, function()
			inst:Destroy()
		end)
	end,
}
GuiServiceStub = { ReducedMotionEnabled = false }
QUALITY = { SavedQualityLevel = Enum.SavedQualitySetting.Automatic }
function UserSettings()
	return {
		GetService = function(_, name)
			assert(name == "UserGameSettings", "UserSettings : service inconnu " .. tostring(name))
			return QUALITY
		end,
	}
end

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
		BindToRenderStep = function(_, name, priority, fn)
			assert(side == "client", "BindToRenderStep côté serveur")
			assert(type(priority) == "number", "BindToRenderStep : priorité numérique attendue")
			RENDER_STEPS[name] = { priority = priority, fn = fn }
		end,
		UnbindFromRenderStep = function(_, name)
			RENDER_STEPS[name] = nil
		end,
	}
end
local LOADED = newSignal()
local function makeGame(side)
	local services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		RunService = makeRunService(side),
		CollectionService = CollectionServiceStub,
		Workspace = Workspace,
		TweenService = TweenServiceStub,
		Debris = DebrisStub,
		GuiService = GuiServiceStub,
		SoundService = SoundServiceStub,
	}
	return {
		GetService = function(_, name)
			return services[name] or error("service bouchonné absent : " .. name)
		end,
		IsLoaded = function()
			return true
		end,
		Loaded = LOADED,
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

-- Aléatoire reproductible (même suite à chaque lancement).
local RandomMT = { __type = "Random" }
RandomMT.__index = RandomMT
local seedState = 12345
local function nextUniform()
	seedState = (seedState * 1103515245 + 12345) % 2147483648
	return seedState / 2147483648
end
function RandomMT.NextNumber(_self, min, max)
	min = min or 0
	max = max or 1
	return min + (max - min) * nextUniform()
end
function RandomMT.NextInteger(_self, min, max)
	return min + math.floor((max - min + 1) * nextUniform())
end
function RandomMT.NextUnitVector(_self)
	local z = 2 * nextUniform() - 1
	local a = 2 * math.pi * nextUniform()
	local r = math.sqrt(1 - z * z)
	return v3(r * math.cos(a), r * math.sin(a), z)
end
RandomStub = {
	new = function(_seed)
		return setmetatable({}, RandomMT)
	end,
}

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
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		UDim = UDim,
		UDim2 = UDim2,
		TweenInfo = TweenInfo,
		NumberRange = NumberRange,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		ColorSequence = ColorSequence,
		RaycastParams = RaycastParams,
		Random = RandomStub,
		UserSettings = UserSettings,
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
function clearLog()
	table.clear(LOG)
end
function dumpLog()
	for _, line in LOG do
		print(`    [{line.side} {line.kind}] {line.text}`)
	end
end
function summary()
	print(string.format("\n%d vérification(s), %d échec(s)", CHECKS, FAILS))
end
