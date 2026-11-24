
-- a146 (2026-11-14, vague 41, audit de sécurité) : OverlapParams et Workspace:GetPartsInPart, lus par
-- shared/CatchReach (capture et batte : HumanoidRootPart dans un mur). Ajout pur, sans changer le reste.
-- Approximation : les pièces (filtres Exclude/Include, CanQuery, RespectCanCollide) dont la boîte contient
-- le centre de la pièce cherchée.
OverlapParams = {
	new = function()
		return { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = {}, RespectCanCollide = false }
	end,
}
function Methods.GetPartsInPart(self, query, params)
	local filter = if params then params.FilterDescendantsInstances or {} else {}
	local include = params and params.FilterType == "Enum.RaycastFilterType.Include"
	local center = query.CFrame.Position
	local out = {}
	for _, part in partsOf(self) do
		if part == query or part.CanQuery == false then
			continue
		end
		if params and params.RespectCanCollide and part.CanCollide == false then
			continue
		end
		local listed = false
		for _, f in filter do
			if part == f or Methods.IsDescendantOf(part, f) then
				listed = true
				break
			end
		end
		if listed ~= (include == true) then
			continue
		end
		local p = part.CFrame:PointToObjectSpace(center)
		local h = part.Size / 2
		if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
			table.insert(out, part)
		end
	end
	return out
end
