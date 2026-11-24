--!nocheck
-- Ajouts côté client au faux de pc-cantin-banc (pc-l140) : WaitForChild, Position d'une Part, Players.LocalPlayer et son
-- CharacterAdded, Humanoid (SetStateEnabled, GetStateEnabled, GetState, ChangeState), Enum, task (wait =
-- yield de la coroutine de Start, defer = file vidée à chaque TICK).

local mt = getmetatable(WORKSPACE)
local oldIndex = mt.__index
mt.__index = function(inst, k)
	if k == "WaitForChild" then
		return function(self, name) return assert(self:FindFirstChild(name), "WaitForChild sans enfant : " .. name) end
	end
	if k == "Position" and inst:IsA("BasePart") then
		return inst.CFrame.Position
	end
	return oldIndex(inst, k)
end

Enum = { HumanoidStateType = { Climbing = "Climbing", Freefall = "Freefall", Running = "Running" } }

local deferred = {}
task = {
	wait = function() return coroutine.yield() end,
	defer = function(fn, ...) table.insert(deferred, { fn, ... }) end,
}

local characterAdded = {}
LOCAL_PLAYER = {
	Name = "IRONIX01",
	Character = nil,
	CharacterAdded = {
		Connect = function(_, fn)
			table.insert(characterAdded, fn)
			return { Disconnect = function() end }
		end,
	},
}
local Players = { LocalPlayer = LOCAL_PLAYER }
local oldGetService = game.GetService
game.GetService = function(self, name)
	if name == "Players" then return Players end
	return oldGetService(self, name)
end

-- Perso : Model avec Humanoid et HumanoidRootPart (position en monde).
function MAKE_CHARACTER(position)
	local c = NEW("Model", "IRONIX01")
	local h = NEW("Humanoid", "Humanoid")
	h.States = { Climbing = true }
	h.Current = "Running"
	h.Changes = {}
	h.SetStateEnabled = function(self, s, v) self.States[s] = v; table.insert(self.Changes, { s, v }) end
	h.GetStateEnabled = function(self, s) return self.States[s] ~= false end
	h.GetState = function(self) return self.Current end
	h.ChangeState = function(self, s) self.Current = s end
	h.Parent = c
	local root = NEW("Part", "HumanoidRootPart")
	root.CanCollide = false
	root.CFrame = CFrame.new(position)
	root.Parent = c
	c.Parent = WORKSPACE
	return c, h, root
end

function SPAWN(position)
	local c, h, root = MAKE_CHARACTER(position)
	LOCAL_PLAYER.Character = c
	for _, fn in characterAdded do fn(c) end
	return c, h, root
end

local co = nil
function START_CONTROLLER(controller)
	co = coroutine.create(controller.Start)
	local ok, err = coroutine.resume(co)
	assert(ok, err)
end
-- Un tour de boucle du contrôleur (task.wait rendu), après les task.defer en attente.
function TICK()
	local list = deferred
	deferred = {}
	for _, d in list do d[1](table.unpack(d, 2)) end
	local ok, err = coroutine.resume(co)
	assert(ok, err)
end

-- Charge le contrôleur avec un environnement qui voit Enum et task (REQUIRE du faux ne passe que _G, en
-- lecture seule).
function CLIENT_REQUIRE(key)
	local m = NEW("ModuleScript", "StoreClimbController")
	local fn, err = loadstring(assert(SOURCES[key], "source absente : " .. key), "=StoreClimbController")
	assert(fn, err)
	local here = getfenv()
	setfenv(fn, setmetatable({
		game = game, script = m, Vector3 = Vector3, CFrame = CFrame, Instance = Instance, Enum = Enum, task = task,
		require = REQUIRE,
		print = function(...) table.insert(LOG, { kind = "PRINT", text = table.concat({ ... }, " ") }) end,
		warn = function(...) table.insert(LOG, { kind = "WARN", text = table.concat({ ... }, " ") }) end,
	}, { __index = here }))
	return fn()
end
