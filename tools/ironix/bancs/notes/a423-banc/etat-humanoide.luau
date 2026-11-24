--!nocheck
-- a423 (24/11) : état du Humanoid, d'après le relevé en Play du 24/11 (serveur, NPC_Bodyguard préparé comme
-- ShopDefenseService : pièces sans collision, HumanoidRootPart seul ancré, posé dans le Workspace) :
--   * à l'image qui suit son entrée dans le Workspace, un Humanoid dont le HumanoidRootPart est ancré passe en
--     FallingDown, si cet état est permis (relevé : Running -> FallingDown 0,03 s après la pose) ;
--   * désancré en FallingDown, il ne bouge pas (MoveTo sans effet) pendant HUMANOID_STATE.Duration = 3 s (relevé :
--     3,0 s), puis GettingUp -> Running et il part ;
--   * FallingDown coupé (SetStateEnabled) avant cette image : il reste Running et part tout de suite.
-- Le faux Roblox d'avant : SetStateEnabled et ChangeState muets, aucun état. Ne suit que les Humanoid rendus par
-- HUMANOID_STATE.Watch() (posé par le test), à chaque Heartbeat.
HUMANOID_STATE = {
	Duration = 3,
	Watch = nil, -- function() -> { Humanoid }
	Fell = setmetatable({}, { __mode = "k" }), -- Humanoid passé au moins une fois en FallingDown
}
local FALLING = "FallingDown"
local enabledOf = setmetatable({}, { __mode = "k" })
local stateOf = setmetatable({}, { __mode = "k" })
local fallClock = setmetatable({}, { __mode = "k" })
local seen = setmetatable({}, { __mode = "k" })

local function stateKey(s)
	local text = tostring(s)
	return string.match(text, "([%w]+)$") or text
end
Methods.SetStateEnabled = function(self, s, on)
	local flags = enabledOf[self] or {}
	enabledOf[self] = flags
	flags[stateKey(s)] = on == true
end
Methods.GetStateEnabled = function(self, s)
	local flags = enabledOf[self]
	return not (flags ~= nil and flags[stateKey(s)] == false)
end
function HUMANOID_STATE.of(humanoid)
	return stateOf[humanoid] or "Running"
end

-- MoveTo sans effet tant qu'il est par terre (le but d'avant est oublié, comme s'il n'avait jamais été donné).
local plainMoveTo = Methods.MoveTo
Methods.MoveTo = function(self, goal)
	if stateOf[self] == FALLING then
		if MOVE_GOALS then
			MOVE_GOALS[self] = nil
		end
		rawset(self, "_moveTarget", nil)
		return
	end
	return plainMoveTo(self, goal)
end

local function inWorkspace(instance)
	local node = instance
	while node ~= nil do
		if node == Workspace then
			return true
		end
		node = node.Parent
	end
	return false
end

HEARTBEAT:Connect(function(dt)
	local watch = HUMANOID_STATE.Watch
	if watch == nil then
		return
	end
	for _, humanoid in watch() do
		local model = humanoid and humanoid.Parent
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if root and inWorkspace(model) then
			if not seen[humanoid] then
				seen[humanoid] = true
				if root.Anchored and Methods.GetStateEnabled(humanoid, "FallingDown") then
					stateOf[humanoid] = FALLING
					HUMANOID_STATE.Fell[humanoid] = true
					if MOVE_GOALS then
						MOVE_GOALS[humanoid] = nil
					end
					rawset(humanoid, "_moveTarget", nil)
				end
			elseif stateOf[humanoid] == FALLING and not root.Anchored then
				fallClock[humanoid] = (fallClock[humanoid] or 0) + dt
				if fallClock[humanoid] >= HUMANOID_STATE.Duration then
					fallClock[humanoid] = nil
					stateOf[humanoid] = if Methods.GetStateEnabled(humanoid, "GettingUp") then "Running" else FALLING
				end
			end
		end
	end
end)
