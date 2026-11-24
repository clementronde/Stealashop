--!nocheck
-- Bouchons Roblox minimalistes (repris du banc de a08, complétés par a13, puis par a23 : Random,
-- Vector2, Color3:Lerp, écrans et cadres avec tailles absolues, ViewportFrame, caméra et
-- projection, UIScale, UIGradient, PointLight, sons, Model:ScaleTo, RenderStepped) pour exécuter
-- UnboxService, UnboxController et ses modules d'aide (Unbox/Sequence, Screen, Reel) et le vrai
-- module Net hors de Studio. Temps simulé, un seul VM, arbre d'instances partagé entre
-- « serveur » et « client » (réplication parfaite et instantanée).
-- Une propriété lue ou écrite qui n'est pas déclarée ici lève une erreur : les noms de
-- propriétés déclarés sont ceux de l'API Roblox.

SOURCES = {}
local FAILS = 0
local CHECKS = 0
LOG = {} -- lignes de sortie des modules (PRINT / WARN)
FULL_LOG = {}
REMOTE_LOG = {} -- envois serveur → client

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
function advance(dt)
	local target = simTime + dt
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
	simTime = target
end
function now()
	return simTime
end

---------------------------------------------------------------- types de valeurs
Vector3 = {}
local V3MT = { __type = "Vector3" }
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

CFrame = {}
local CFMT = { __type = "CFrame" }
-- r = matrice 3×3 par lignes : r[1..3] ligne 1, etc.
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
CFMT.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "LookVector" then
		return v3(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			return mulRtV(self.r, v - self.p)
		end
	elseif k == "PointToWorldSpace" then
		return function(self, v)
			return self.p + mulRV(self.r, v)
		end
	-- ajouts du Claude principal (2026-11-07) : utilisés par UnboxService depuis la vague 4
	elseif k == "Inverse" then
		return function(self)
			local rt = { self.r[1], self.r[4], self.r[7], self.r[2], self.r[5], self.r[8], self.r[3], self.r[6], self.r[9] }
			return cf(mulRV(rt, v3(0, 0, 0) - self.p), rt)
		end
	elseif k == "ToObjectSpace" then
		return function(self, other)
			local rt = { self.r[1], self.r[4], self.r[7], self.r[2], self.r[5], self.r[8], self.r[3], self.r[6], self.r[9] }
			return cf(mulRV(rt, other.p - self.p), mulRR(rt, other.r))
		end
	elseif k == "ToWorldSpace" then
		return function(self, other)
			return cf(self.p + mulRV(self.r, other.p), mulRR(self.r, other.r))
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
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cf(x, IDENTITY_R)
	end
	return cf(v3(x or 0, y or 0, z or 0), IDENTITY_R)
end
function CFrame.Angles(_rx, ry, _rz)
	local c, s = math.cos(ry), math.sin(ry)
	return cf(v3(0, 0, 0), { c, 0, s, 0, 1, 0, -s, 0, c })
end
CFrame.identity = CFrame.new(0, 0, 0)
-- Ajout a23 (comme a15) : position exacte ; orientation ignorée (les vérifications ne lisent que
-- la position).
function CFrame.lookAt(eye, _target)
	return cf(eye, IDENTITY_R)
end

-- Ajout a23 : Vector2 (positions et tailles absolues des écrans).
Vector2 = {}
local V2MT = { __type = "Vector2" }
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2MT)
end
V2MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Lerp" then
		return function(a, b, t)
			return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
		end
	end
	error("Vector2 : membre inconnu " .. tostring(k), 2)
end
V2MT.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2MT.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2MT.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2MT.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
V2MT.__tostring = function(a)
	return string.format("(%.1f, %.1f)", a.X, a.Y)
end
Vector2.new = v2
Vector2.zero = v2(0, 0)

-- Ajout a23 : Random de Roblox, déterministe (générateur de Lehmer, 48271 modulo 2³¹ − 1). Sans
-- graine, chaque Random.new() prend la suivante d'une suite fixe : le banc rejoue à l'identique.
Random = {}
local RandomMT = { __type = "Random" }
RandomMT.__index = RandomMT
local nextSeed = 12345
function Random.new(seed)
	local s
	if seed == nil then
		nextSeed += 7919
		s = nextSeed
	else
		s = math.floor(seed)
	end
	s = s % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ s = s }, RandomMT)
end
function RandomMT.NextNumber(self, a, b)
	self.s = (self.s * 48271) % 2147483647
	local u = (self.s - 1) / 2147483646
	if a ~= nil then
		return a + (b - a) * u
	end
	return u
end
function RandomMT.NextInteger(self, a, b)
	return a + math.floor(RandomMT.NextNumber(self) * (b - a + 1))
end

-- Couleurs avec Lerp (ajout a23) ; `hex` (fromHex) reste lisible pour les vérifications.
local C3MT = { __type = "Color3" }
local function color3(r, g, b, hex)
	return setmetatable({ R = r, G = g, B = b, hex = hex }, C3MT)
end
C3MT.__index = function(c, k)
	if k == "Lerp" then
		return function(a, b, t)
			return color3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	elseif k == "hex" then
		return nil
	end
	error("Color3 : membre inconnu " .. tostring(k), 2)
end
C3MT.__tostring = function(c)
	return string.format("Color3(%.3f, %.3f, %.3f)", c.R, c.G, c.B)
end
Color3 = {
	fromRGB = function(r, g, b)
		return color3(r / 255, g / 255, b / 255)
	end,
	new = function(r, g, b)
		return color3(r or 0, g or 0, b or 0)
	end,
	fromHex = function(hex)
		local h = string.gsub(hex, "#", "")
		return color3(
			tonumber(string.sub(h, 1, 2), 16) / 255,
			tonumber(string.sub(h, 3, 4), 16) / 255,
			tonumber(string.sub(h, 5, 6), 16) / 255,
			string.upper(h)
		)
	end,
}
function sameColor(a, b)
	return a ~= nil and b ~= nil and math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end

local function udim(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = udim(xs, xo), Y = udim(ys, yo) }
	end,
	fromScale = function(x, y)
		return { X = udim(x, 0), Y = udim(y, 0) }
	end,
	fromOffset = function(x, y)
		return { X = udim(0, x), Y = udim(0, y) }
	end,
}
Font = {
	fromEnum = function(e)
		return { Enum = e }
	end,
}
-- Heure Unix simulée : GetServerTimeNow() = EPOCH + temps simulé ; os.time() en est la partie entière.
EPOCH = 1_793_000_000.4
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
-- Ajout a23 (Sound.Ended:Once dans MarkerSounds).
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function SignalMT:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

---------------------------------------------------------------- instances
local ISA = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance" },
	Tool = { "BackpackItem" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	RemoteEvent = { "BaseRemoteEvent" },
	UnreliableRemoteEvent = { "BaseRemoteEvent" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	TextLabel = { "GuiLabel", "GuiObject", "GuiBase2d" },
	-- ajouts a23
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiLabel", "GuiObject", "GuiBase2d" },
	ImageButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	ViewportFrame = { "GuiObject", "GuiBase2d" },
	UIGradient = { "UIComponent" },
	UIScale = { "UIComponent" },
	UIStroke = { "UIComponent" },
	UICorner = { "UIComponent" },
	UIAspectRatioConstraint = { "UIConstraint", "UIComponent" },
	UISizeConstraint = { "UIConstraint", "UIComponent" },
	UIListLayout = { "UIGridStyleLayout", "UILayout", "UIComponent" },
	PointLight = { "Light" },
	Camera = { "PVInstance" },
}
local BASEPART_PROPS = {
	Anchored = false,
	CanCollide = true,
	CanQuery = true,
	CanTouch = true,
	Massless = false,
	Transparency = 0,
	Size = v3(4, 1, 2),
	CFrame = CFrame.identity,
	Color = Color3.new(0.6, 0.6, 0.6),
	Material = "Enum.Material.Plastic",
	-- ajouts a23
	Shape = "Enum.PartType.Block",
	CastShadow = true,
	AssemblyLinearVelocity = v3(0, 0, 0),
}
-- Ajout a23 : propriétés communes des GuiObject.
local function guiProps(extra)
	local props = {
		Visible = true,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0, 0),
		AnchorPoint = v2(0, 0),
		Rotation = 0,
		ZIndex = 1,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return props
end
local TEXT_PROPS = {
	TextScaled = false,
	FontFace = Font.fromEnum("Enum.Font.Legacy"),
	TextColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 1,
	TextTransparency = 0,
	Text = "Label",
}
local IMAGE_PROPS = { Image = "", ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0 }
local NONE = setmetatable({}, { __tostring = function() return "nil" end }) -- propriété Instance? vide
local PROPS = {
	Part = BASEPART_PROPS,
	MeshPart = BASEPART_PROPS,
	Tool = { RequiresHandle = true, CanBeDropped = true, ToolTip = "", Enabled = true, ManualActivationOnly = false },
	WeldConstraint = { Part0 = NONE, Part1 = NONE },
	Model = { PrimaryPart = NONE, WorldPivot = CFrame.identity },
	Humanoid = { Health = 100 },
	Player = { UserId = 0, Character = NONE, DisplayName = "" },
	Players = { LocalPlayer = NONE },
	Attachment = { CFrame = CFrame.identity },
	BillboardGui = {
		Size = UDim2.fromScale(0, 0),
		StudsOffset = Vector3.zero,
		StudsOffsetWorldSpace = Vector3.zero,
		MaxDistance = math.huge,
		LightInfluence = 1,
		Adornee = NONE,
		AlwaysOnTop = false,
		Enabled = true,
	},
	TextLabel = guiProps(TEXT_PROPS),
	ProximityPrompt = {
		ObjectText = "",
		ActionText = "Interact",
		MaxActivationDistance = 10,
		RequiresLineOfSight = true,
		HoldDuration = 0,
		Enabled = true,
	},
	-- ajouts a23
	Workspace = { CurrentCamera = NONE },
	ScreenGui = { Enabled = true, ResetOnSpawn = true, IgnoreGuiInset = false },
	Frame = guiProps(),
	TextButton = guiProps((function()
		local p = table.clone(TEXT_PROPS)
		p.Text = "Button"
		p.AutoButtonColor = true
		return p
	end)()),
	ImageLabel = guiProps(IMAGE_PROPS),
	ImageButton = guiProps(IMAGE_PROPS),
	ViewportFrame = guiProps({
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0,
		CurrentCamera = NONE,
		Ambient = Color3.new(0.78, 0.78, 0.78),
		LightColor = Color3.new(0.55, 0.55, 0.55),
		LightDirection = v3(-1, -1, -1),
	}),
	UIGradient = { Enabled = true, Rotation = 0 },
	UIScale = { Scale = 1 },
	UIStroke = { Thickness = 1, Color = Color3.new(0, 0, 0) },
	UICorner = {},
	UIAspectRatioConstraint = { AspectRatio = 1 },
	UISizeConstraint = {},
	UIListLayout = {},
	Camera = { CFrame = CFrame.identity, FieldOfView = 70 },
	PointLight = { Brightness = 1, Range = 8, Color = Color3.new(1, 1, 1), Shadows = false, Enabled = true },
	Sound = { Looped = false, IsPlaying = false, Volume = 0.5, PlaybackSpeed = 1, SoundId = "" },
}
PROPS.Humanoid.FloorMaterial = "Enum.Material.Plastic" -- ajout a23
local EVENTS = {
	ChildAdded = true,
	ChildRemoved = true,
	AncestryChanged = true,
	Activated = true,
	CharacterAdded = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Triggered = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	Ended = true, -- ajout a23 (Sound)
	Destroying = true,
	MouseEnter = true, -- ajout 2026-11-10 (Motion.Hover)
	MouseLeave = true,
	MouseButton1Down = true, -- ajout a60 2026-11-10 (Motion.Button : appui et relâché)
	MouseButton1Up = true,
	InputBegan = true, -- copie d'a62 2026-11-11 (Motion.Button : fin du toucher, L-092 3g)
	InputEnded = true,
}

local Methods = {}
local InstanceMT = { __type = "Instance" }
local ALL = {} -- toutes les instances créées (pour GetJoints)
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

local function defaultsFor(class)
	local props = { Name = class }
	for k, v in PROPS[class] or {} do
		props[k] = v
	end
	return props
end

-- Ajout a23 : tailles et positions absolues des écrans (écran de 1280 × 720 px), sans contrainte
-- de proportions ni mise en page.
SCREEN_SIZE = v2(1280, 720)
local function absSize(inst)
	if rawget(inst, "_class") == "ScreenGui" then
		return SCREEN_SIZE
	end
	local parent = rawget(inst, "_parent")
	local base = if parent and isA(parent, "GuiBase2d") then absSize(parent) else SCREEN_SIZE
	local size = rawget(inst, "_props").Size
	return v2(base.X * size.X.Scale + size.X.Offset, base.Y * size.Y.Scale + size.Y.Offset)
end
local function absPos(inst)
	if rawget(inst, "_class") == "ScreenGui" then
		return v2(0, 0)
	end
	local parent = rawget(inst, "_parent")
	local origin = if parent and isA(parent, "GuiBase2d") then absPos(parent) else v2(0, 0)
	local base = if parent and isA(parent, "GuiBase2d") then absSize(parent) else SCREEN_SIZE
	local props = rawget(inst, "_props")
	local size = absSize(inst)
	local anchor = props.AnchorPoint or v2(0, 0)
	return v2(
		origin.X + base.X * props.Position.X.Scale + props.Position.X.Offset - size.X * anchor.X,
		origin.Y + base.Y * props.Position.Y.Scale + props.Position.Y.Offset - size.Y * anchor.Y
	)
end

InstanceMT.__index = function(self, key)
	local m = Methods[key]
	if m ~= nil then
		return m
	end
	if (key == "AbsoluteSize" or key == "AbsolutePosition") and isA(self, "GuiBase2d") then
		return if key == "AbsoluteSize" then absSize(self) else absPos(self)
	end
	if key == "ClassName" then
		return rawget(self, "_class")
	elseif key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "Position" and isA(self, "BasePart") then
		return rawget(self, "_props").CFrame.Position
	elseif (key == "WorldCFrame" or key == "WorldPosition") and rawget(self, "_class") == "Attachment" then
		local parent = rawget(self, "_parent")
		local local_ = rawget(self, "_props").CFrame
		local world = if parent and isA(parent, "BasePart") then parent.CFrame * local_ else local_
		return if key == "WorldCFrame" then world else world.Position
	end
	local props = rawget(self, "_props")
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
	error(`{rawget(self, "_class")} « {props.Name} » : membre inconnu « {key} »`, 2)
end

-- `inst` et ses descendants, dans l'ordre de l'arbre.
local function subtree(inst)
	local out = { inst }
	local function walk(i)
		for _, c in rawget(i, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(inst)
	return out
end

-- Signale DescendantAdded / DescendantRemoving à chaque ancêtre de `from`, `from` compris.
local function fireAncestors(from, eventName, list)
	local ancestor = from
	while ancestor do
		local signal = rawget(ancestor, "_signals")[eventName]
		if signal then
			for _, inst in list do
				signal:Fire(inst)
			end
		end
		ancestor = rawget(ancestor, "_parent")
	end
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
		fireAncestors(old, "DescendantRemoving", subtree(self))
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
		fireAncestors(parent, "DescendantAdded", subtree(self))
	end
end

InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	local props = rawget(self, "_props")
	local class = rawget(self, "_class")
	local known = key == "Name" or (PROPS[class] and PROPS[class][key] ~= nil)
	if not known then
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
	local self = setmetatable({
		_class = class,
		_props = defaultsFor(class),
		_children = {},
		_attrs = {},
		_attrSignals = {},
		_signals = {},
		_parent = nil,
		_destroyed = false,
	}, InstanceMT)
	table.insert(ALL, self)
	return self
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
end
-- Comme Roblox : les références internes (PrimaryPart, Adornee…) pointent vers la copie.
function Methods.Clone(self)
	local map = {}
	local function copyOf(inst)
		local copy = newInstance(rawget(inst, "_class"))
		map[inst] = copy
		for k, v in rawget(inst, "_props") do
			rawget(copy, "_props")[k] = v
		end
		for k, v in rawget(inst, "_attrs") do
			rawget(copy, "_attrs")[k] = v
		end
		for _, c in rawget(inst, "_children") do
			local child = copyOf(c)
			rawset(child, "_parent", copy)
			table.insert(rawget(copy, "_children"), child)
		end
		return copy
	end
	local root = copyOf(self)
	for _, copy in map do
		local props = rawget(copy, "_props")
		for k, v in props do
			if map[v] then
				props[k] = map[v]
			end
		end
	end
	return root
end
function Methods.GetPivot(self)
	if rawget(self, "_class") == "Model" then
		local primary = self.PrimaryPart
		return if primary then primary.CFrame else self.WorldPivot
	end
	return self.CFrame
end
-- Déplacement en translation seulement (suffisant ici : repères sans rotation).
function Methods.PivotTo(self, target)
	local pivot = Methods.GetPivot(self)
	local delta = target.Position - pivot.Position
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			d.CFrame = CFrame.new(d.CFrame.Position + delta)
		end
	end
	if rawget(self, "_class") == "Model" then
		rawget(self, "_props").WorldPivot = target
	elseif isA(self, "BasePart") then -- ajout a23 : une pièce seule se déplace aussi
		rawget(self, "_props").CFrame = CFrame.new(rawget(self, "_props").CFrame.Position + delta)
	end
	PIVOTS = (PIVOTS or 0) + 1
end
-- Ajouts a23 ---------------------------------------------------------------
-- Model:ScaleTo : tailles et écarts au pivot multipliés (translation seulement, comme PivotTo).
function Methods.ScaleTo(self, scale)
	local old = rawget(self, "_scale") or 1
	local factor = scale / old
	local pivot = Methods.GetPivot(self).Position
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			local props = rawget(d, "_props")
			props.Size = props.Size * factor
			props.CFrame = CFrame.new(pivot + (props.CFrame.Position - pivot) * factor)
		end
	end
	rawset(self, "_scale", scale)
end
function Methods.GetScale(self)
	return rawget(self, "_scale") or 1
end
function Methods.FindFirstChildWhichIsA(self, class, recursive)
	for _, c in rawget(self, "_children") do
		if isA(c, class) then
			return c
		end
	end
	if recursive then
		for _, d in Methods.GetDescendants(self) do
			if isA(d, class) then
				return d
			end
		end
	end
	return nil
end
-- Caméra : projection simple (20 px par stud autour du centre de l'écran), toujours devant.
function Methods.WorldToScreenPoint(_self, p)
	return Vector3.new(640 + 20 * p.X, 360 - 20 * p.Y, 10), true
end
function Methods.WorldToViewportPoint(_self, p)
	return Vector3.new(640 + 20 * p.X, 396 - 20 * p.Y, 10), true
end
-- Sons.
SOUNDS_PLAYED = {} -- noms des sons joués, dans l'ordre
function Methods.Play(self)
	rawget(self, "_props").IsPlaying = true
	table.insert(SOUNDS_PLAYED, { name = self.Name, t = simTime, speed = self.PlaybackSpeed })
end
function Methods.Stop(self)
	rawget(self, "_props").IsPlaying = false
end
function Methods.GetServerTimeNow(_self)
	return EPOCH + simTime
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
function Methods.GetJoints(self)
	local out = {}
	for _, inst in ALL do
		if rawget(inst, "_class") == "WeldConstraint" and not rawget(inst, "_destroyed") then
			if inst.Part0 == self or inst.Part1 == self then
				table.insert(out, inst)
			end
		end
	end
	return out
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
	return CFrame.new((lo + hi) / 2), hi - lo
end
function Methods.EquipTool(self, tool)
	tool.Parent = rawget(self, "_parent")
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
FIRE_SERVER = {} -- [nom du remote] = nombre d'envois du client
function Methods.FireServer(self, ...)
	FIRE_SERVER[self.Name] = (FIRE_SERVER[self.Name] or 0) + 1
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
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], inst)
	tagsOf[inst] = tagsOf[inst] or {}
	tagsOf[inst][tag] = true
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
local CollectionService = {
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
ServerStorage = service("ServerStorage")
StarterPlayerScripts = service("StarterPlayerScripts")
Players = service("Players")
SoundService = service("SoundService") -- ajout a23 (MarkerSounds)
-- Caméra du client (ajout a23) : Workspace.CurrentCamera.
do
	local camera = newInstance("Camera")
	camera.Name = "Camera"
	camera.Parent = Workspace
	rawget(Workspace, "_props").CurrentCamera = camera
end

local guidCount = 0
HttpService = {
	GenerateGUID = function(_, braces)
		guidCount += 1
		local core = string.format("%08x-0000-4000-8000-%012x", guidCount, guidCount)
		return if braces == false then core else "{" .. core .. "}"
	end,
}
Heartbeat = newSignal()
-- Avance le temps simulé par pas d'image (1/30 s) en émettant Heartbeat à chaque pas.
function step(seconds)
	local frame = 1 / 30
	local done = 0
	while done < seconds - 1e-9 do
		local dt = math.min(frame, seconds - done)
		advance(dt)
		done += dt
		Heartbeat:Fire(dt)
	end
end

function folder(parent, name)
	local f = newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
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
		Heartbeat = Heartbeat,
		RenderStepped = Heartbeat, -- ajout a23 : même pas d'image que Heartbeat
	}
end
local games = {}
local caches = { server = {}, client = {} }
-- Ajout a23 : oublie les modules déjà chargés d'un côté (pour recharger une source modifiée).
function resetCache(side)
	table.clear(caches[side])
end
local function makeGame(side)
	local runService = makeRunService(side)
	local services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		RunService = runService,
		CollectionService = CollectionService,
		Workspace = Workspace,
		HttpService = HttpService,
		ServerStorage = if side == "server" then ServerStorage else nil,
		SoundService = SoundService, -- ajouts a23
		Debris = { AddItem = function() end },
	}
	return {
		GetService = function(_, name)
			return services[name] or error("service bouchonné absent : " .. name)
		end,
	}
end
games.server = makeGame("server")
games.client = makeGame("client")

local function typeofStub(v)
	local mt = getmetatable(v)
	if type(v) == "table" and type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
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
				return math.floor(EPOCH + simTime)
			end,
		},
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		UDim2 = UDim2,
		Font = Font,
		Enum = Enum,
		Instance = InstanceAPI,
		typeof = typeofStub,
		warn = function(...)
			local parts = table.pack(...)
			for i = 1, parts.n do
				parts[i] = tostring(parts[i])
			end
			table.insert(LOG, { side = side, kind = "WARN", text = table.concat(parts, " ") })
			table.insert(FULL_LOG, { side = side, kind = "WARN", text = table.concat(parts, " ") })
		end,
		print = function(...)
			local parts = table.pack(...)
			for i = 1, parts.n do
				parts[i] = tostring(parts[i])
			end
			table.insert(LOG, { side = side, kind = "PRINT", text = table.concat(parts, " ") })
			table.insert(FULL_LOG, { side = side, kind = "PRINT", text = table.concat(parts, " ") })
		end,
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
	return math.abs(a - b) <= (eps or 1e-6)
end
function logHas(pattern, kind)
	for _, line in LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, pattern, 1, true) then
			return true
		end
	end
	return false
end
function clearLog()
	table.clear(LOG)
end
function remotes(name, id)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == name and (id == nil or e.args[1] == id) then
			table.insert(out, e)
		end
	end
	return out
end
function summary()
	print(string.format("\n%d vérification(s), %d échec(s)", CHECKS, FAILS))
end
