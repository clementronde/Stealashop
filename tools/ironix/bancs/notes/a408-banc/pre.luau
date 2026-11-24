---------------------------------------------------------------- a408 : interrupteurs et marche des agents
-- Scénario « off » : les trois interrupteurs d'a408 à false dans le source assemblé (le dépôt les garde à true).
if SCENARIO == "off" then
	local key = "shared/Config/Features.luau"
	local src = SOURCES[key]
	for _, name in { "Bodyguards", "DoorGuard", "CameraRadar" } do
		local n
		src, n = string.gsub(src, "\n\t" .. name .. " = true,", "\n\t" .. name .. " = false,")
		assert(n == 1, "a408 : ligne " .. name .. " = true introuvable dans Config/Features")
	end
	SOURCES[key] = src
end

-- Humanoid:MoveTo : but noté ; à chaque Heartbeat, le modèle d'un Humanoid dont le HumanoidRootPart n'est pas ancré
-- avance vers son but à WalkSpeed (à l'horizontale), comme le ferait Roblox sur un sol plat.
MOVE_GOALS = setmetatable({}, { __mode = "k" })
Methods.MoveTo = function(self, goal)
	MOVE_GOALS[self] = goal
end
Methods.SetNetworkOwner = function() end
HEARTBEAT:Connect(function(dt)
	for humanoid, goal in MOVE_GOALS do
		local model = humanoid.Parent
		local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
		if root and not root.Anchored and model.Parent ~= nil then
			local d = goal - root.Position
			d = Vector3.new(d.X, 0, d.Z)
			local stepLength = math.min(d.Magnitude, (humanoid.WalkSpeed or 16) * dt)
			if stepLength > 1e-3 then
				model:PivotTo(model:GetPivot() + d.Unit * stepLength)
			end
		end
	end
end)

-- CatchReach.CanTouch (capture par l'agent) demande OverlapParams et Workspace:GetPartsInPart, absents du faux
-- Roblox d'a29 : aucune pièce ne contient le voleur (les sols du banc sont plats et dégagés).
if OverlapParams == nil then
	OverlapParams = {
		new = function()
			return { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = {}, RespectCanCollide = false, MaxParts = 0 }
		end,
	}
end
if Methods.GetPartsInPart == nil then
	Methods.GetPartsInPart = function()
		return {}
	end
end
