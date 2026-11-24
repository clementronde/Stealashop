--!nocheck
---------------------------------------------------------------- a51 (L-089) : compléments du faux Roblox d'a13 / a23
-- Pour les copies d'a51 des bancs qui gardent le faux Roblox d'a13 (a13, a23, a43…), concaténé juste après
-- leur stubs.luau (même bloc : Methods, isA, CFMT, cf, v3 y sont visibles) :
--   - CFrame.Rotation (UnboxService : colis tourné comme la parcelle) ;
--   - Instance:FindFirstAncestorWhichIsA (UnboxController : pièce d'un colis posé arrivée après lui) ;
--   - Workspace:Raycast (premier contact des pièces du Workspace, boîtes alignées sur les axes, normale +Y),
--     Workspace:GetPartBoundsInBox (boîtes englobantes alignées), RaycastParams et OverlapParams, avec
--     les filtres Include / Exclude, RespectCanCollide et CanQuery.

do
	local baseIndex = CFMT.__index
	CFMT.__index = function(c, k)
		if k == "Rotation" then
			return cf(v3(0, 0, 0), c.r)
		end
		return baseIndex(c, k)
	end
end

function Methods.FindFirstAncestorWhichIsA(self, class)
	local current = rawget(self, "_parent")
	while current do
		if isA(current, class) then
			return current
		end
		current = rawget(current, "_parent")
	end
	return nil
end

RaycastParams = {
	new = function()
		return { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = {}, RespectCanCollide = false }
	end,
}
OverlapParams = {
	new = function()
		return { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = {}, RespectCanCollide = false, MaxParts = 0 }
	end,
}

local function keep51(part, params)
	if part.CanQuery == false then
		return false
	end
	if params and params.RespectCanCollide and part.CanCollide == false then
		return false
	end
	local filter = if params then params.FilterDescendantsInstances or {} else {}
	local include = params and string.find(tostring(params.FilterType), "Include", 1, true) ~= nil
	for _, f in filter do
		if part == f or Methods.IsDescendantOf(part, f) then
			return include -- dans la liste : gardée si Include, écartée si Exclude
		end
	end
	return not include
end

-- Boîte alignée d'une pièce (son orientation est ignorée, comme le reste de ce faux Roblox).
local function box51(part)
	local p, h = part.CFrame.Position, part.Size / 2
	return p - h, p + h
end

function Methods.Raycast(self, origin, direction, params)
	local bestT, bestPart = math.huge, nil
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") and keep51(d, params) then
			local lo, hi = box51(d)
			local tmin, tmax = 0, 1
			local ok = true
			for _, axis in { "X", "Y", "Z" } do
				local o, dir = origin[axis], direction[axis]
				if math.abs(dir) < 1e-12 then
					if o < lo[axis] or o > hi[axis] then
						ok = false
						break
					end
				else
					local t1, t2 = (lo[axis] - o) / dir, (hi[axis] - o) / dir
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
				bestT, bestPart = tmin, d
			end
		end
	end
	if bestPart == nil then
		return nil
	end
	return { Position = origin + direction * bestT, Instance = bestPart, Distance = direction.Magnitude * bestT, Normal = Vector3.new(0, 1, 0) }
end

function Methods.GetPartBoundsInBox(self, cframe, size, params)
	local center, h = cframe.Position, size / 2
	local qlo, qhi = center - h, center + h
	local out = {}
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") and keep51(d, params) then
			local lo, hi = box51(d)
			if lo.X < qhi.X and hi.X > qlo.X and lo.Y < qhi.Y and hi.Y > qlo.Y and lo.Z < qhi.Z and hi.Z > qlo.Z then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- Part.PivotOffset (UnboxService : pivot du bloc V0 en bas au centre). Ce faux Roblox ne le lit pas dans
-- GetPivot (repères sans décalage) : la propriété est seulement acceptée.
BASEPART_PROPS.PivotOffset = CFrame.identity
