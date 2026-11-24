--!nocheck
-- Compléments aux bouchons de a08 (stubs.luau, copié tel quel) pour StoreHeistService et
-- HeistController (a10) : Vector3 et CFrame plus complets, Attachments, pivots, Heartbeat,
-- rayon vers un sol plat en Y = 0, ProximityPrompt, Random pilotable, ServerStorage, TweenService.

-- Vector3 -------------------------------------------------------------------------------------
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
Vector3.one = v3(1, 1, 1)
local baseV3Index = V3MT.__index
V3MT.__index = function(v, k)
	if k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	return baseV3Index(v, k)
end

-- CFrame --------------------------------------------------------------------------------------
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
local baseCFIndex = CFMT.__index
CFMT.__index = function(c, k)
	if k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "RightVector" then
		return v3(c.r[1], c.r[4], c.r[7])
	elseif k == "UpVector" then
		return v3(c.r[2], c.r[5], c.r[8])
	elseif k == "Rotation" then
		return cf(v3(0, 0, 0), c.r)
	elseif k == "Inverse" then
		return function(self)
			local rt = transpose(self.r)
			return cf(-mulRV(rt, self.p), rt)
		end
	elseif k == "ToObjectSpace" then
		return function(self, other)
			return self:Inverse() * other
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return cf(a.p + (b.p - a.p) * t, if t >= 1 then b.r else a.r)
		end
	end
	return baseCFIndex(c, k)
end
CFMT.__add = function(a, b)
	return cf(a.p + b, a.r)
end
CFMT.__sub = function(a, b)
	return cf(a.p - b, a.r)
end
CFMT.__tostring = function(c)
	return "CFrame" .. tostring(c.p)
end
function CFrame.lookAt(pos, target)
	local f = (target - pos).Unit
	local right = f:Cross(Vector3.yAxis).Unit
	local up = right:Cross(f)
	return cf(pos, { right.X, up.X, -f.X, right.Y, up.Y, -f.Y, right.Z, up.Z, -f.Z })
end

Color3.fromHex = function(hex)
	return { Hex = hex }
end

-- Instances -----------------------------------------------------------------------------------
for k, v in {
	TopSurface = "Enum.SurfaceType.Smooth",
	BottomSurface = "Enum.SurfaceType.Smooth",
	CastShadow = true,
	PivotOffset = CFrame.identity,
	AssemblyLinearVelocity = Vector3.zero,
	AssemblyAngularVelocity = Vector3.zero,
} do
	BASEPART_PROPS[k] = v
end
PROPS.Attachment = { CFrame = CFrame.identity }
PROPS.Folder = {}
PROPS.ProximityPrompt = {
	ActionText = "",
	ObjectText = "",
	HoldDuration = 0,
	MaxActivationDistance = 10,
	RequiresLineOfSight = true,
	Enabled = true,
}
PROPS.Humanoid.HipHeight = 2
PROPS.Humanoid.RigType = "Enum.HumanoidRigType.R15"
PROPS.Player.Name = "Player"
ISA.Attachment = {}
ISA.Folder = {}
ISA.ProximityPrompt = {}
EVENTS.PromptButtonHoldBegan = true
EVENTS.Triggered = true

local baseInstanceIndex = InstanceMT.__index
InstanceMT.__index = function(self, key)
	if rawget(self, "_class") == "Attachment" and (key == "WorldCFrame" or key == "WorldPosition") then
		local parent = rawget(self, "_parent")
		local base = if parent and isA(parent, "BasePart") then parent.CFrame else CFrame.identity
		local world = base * rawget(self, "_props").CFrame
		return if key == "WorldCFrame" then world else world.Position
	end
	return baseInstanceIndex(self, key)
end

function Methods.GetPivot(self)
	if isA(self, "BasePart") then
		return self.CFrame * self.PivotOffset
	end
	local primary = self.PrimaryPart
	if primary then
		return Methods.GetPivot(primary)
	end
	return self.WorldPivot
end
function Methods.PivotTo(self, target)
	if isA(self, "BasePart") then
		self.CFrame = target * self.PivotOffset:Inverse()
		return
	end
	local current = Methods.GetPivot(self)
	local delta = target * current:Inverse()
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	if self.PrimaryPart == nil then
		self.WorldPivot = target
	end
end
-- Sol plat en Y = 0 sous tout le monde.
function Methods.Raycast(_self, origin, direction, _params)
	if origin.Y >= 0 and origin.Y + direction.Y <= 0 then
		return { Position = v3(origin.X, 0, origin.Z) }
	end
	return nil
end
function Methods.GetServerTimeNow(_self)
	return simTime
end
RaycastParams = {
	new = function()
		return {}
	end,
}

-- Random pilotable : RANDOM_VALUES force les prochains NextNumber, dans l'ordre.
RANDOM_VALUES = {}
local FakeRandomMT = {}
FakeRandomMT.__index = FakeRandomMT
function FakeRandomMT.NextNumber(_self)
	if #RANDOM_VALUES > 0 then
		return table.remove(RANDOM_VALUES, 1)
	end
	return math.random()
end
function FakeRandomMT.NextInteger(_self, a, b)
	return math.random(a, b)
end
Random = {
	new = function()
		return setmetatable({}, FakeRandomMT)
	end,
}

-- Heartbeat : advance() avance image par image (1/60 s) et déclenche HEARTBEAT à chaque image.
HEARTBEAT = newSignal()
local FRAME = 1 / 60
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
end
function advance(dt)
	local target = simTime + dt
	while simTime < target - 1e-9 do
		local frameEnd = math.min(simTime + FRAME, target)
		runUntil(frameEnd)
		simTime = frameEnd
		HEARTBEAT:Fire(FRAME)
	end
	runUntil(target)
	simTime = target
end

-- Services en plus ----------------------------------------------------------------------------
ServerStorage = service("ServerStorage")
local TweenServiceStub = {
	GetValue = function(_, alpha)
		return alpha
	end,
}
local function makeGame2(side)
	local runService = makeRunService(side)
	runService.Heartbeat = HEARTBEAT
	local services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		RunService = runService,
		CollectionService = CollectionService,
		Workspace = Workspace,
		ServerStorage = ServerStorage,
		TweenService = TweenServiceStub,
	}
	return {
		GetService = function(_, name)
			return services[name] or error("service bouchonné absent : " .. name)
		end,
	}
end
games.server = makeGame2("server")
games.client = makeGame2("client")
