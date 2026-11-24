--!nocheck
-- a147 : aides communes. ReturnBaseService (vrai) ajouté aux services ; profils aux uid distincts.
moduleScript(SERVICES, "ReturnBaseService", "server/Services/ReturnBaseService.luau")
function plainProfile(prefix, n)
	local data = newProfile()
	data.Items = {}
	data.Display = {}
	for i = 1, (n or 2) do
		addItem(data, `{prefix}-{i}`, "Z3_Ecouteurs", nil)
		data.Items[`{prefix}-{i}`].Zone = 3
	end
	return data
end
-- Arches ZoneGate de la map (Model, pivot), le long de +X à partir de x0 tous les `step` studs.
GATES = {}
function makeGates(x0, step, count, parent)
	for zone = 1, count or 6 do
		local gate = make("Model", { Name = `ENV_ZoneGate_{zone}` })
		local post = make("Part", { Name = "Post", Anchored = true, Size = Vector3.new(2, 10, 2), CFrame = CFrame.new(x0 + (zone - 1) * step, 5, 0) }, gate)
		gate.PrimaryPart = post
		gate:SetAttribute("Zone", zone)
		addTag(gate, "ZoneGate")
		gate.Parent = parent or MAP
		GATES[zone] = gate
	end
end
