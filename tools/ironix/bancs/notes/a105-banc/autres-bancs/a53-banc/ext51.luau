--!nocheck
---------------------------------------------------------------- a51 : compléments du faux Roblox d'a46 (L-089)
-- Colis dans l'inventaire et posés au sol de la boutique (UnboxService, InventoryService,
-- InventoryController) :
--   - Workspace:GetPartBoundsInBox(cframe, size, params) et OverlapParams.new() : pièces du Workspace
--     dont la boîte englobante (alignée sur les axes du monde) touche celle du volume demandé, avec les
--     filtres Include / Exclude, RespectCanCollide et CanQuery (comme Roblox : boîtes englobantes) ;
--   - Workspace:Raycast garde la normale +Y du faux d'a36 : les sols du banc sont plats ;
--   - Player:GetMouse() (MOUSE : X, Y) et Workspace.CurrentCamera:ScreenPointToRay(x, y), qui renvoie le
--     rayon AIM_RAY (posé par le banc : { Origin, Direction }) ;
--   - Humanoid:EquipTool déjà là (a30) ; Tool.Activated est un signal comme les autres.

OVERLAPS = 0
function OverlapParamsNew()
	return { FilterType = "Enum.RaycastFilterType.Exclude", FilterDescendantsInstances = {}, RespectCanCollide = false, MaxParts = 0 }
end
OverlapParams = { new = OverlapParamsNew }

local function aabbOf(cframe, size)
	local h = size / 2
	local lo, hi
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cframe * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
				lo = if lo then Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z)) else p
				hi = if hi then Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z)) else p
			end
		end
	end
	return lo, hi
end

function Methods.GetPartBoundsInBox(self, cframe, size, params)
	OVERLAPS += 1
	local filter = if params then params.FilterDescendantsInstances or {} else {}
	local include = params and params.FilterType == "Enum.RaycastFilterType.Include"
	local function filtered(part)
		for _, f in filter do
			if part == f or Methods.IsDescendantOf(part, f) then
				return not include
			end
		end
		return include
	end
	local qlo, qhi = aabbOf(cframe, size)
	local out = {}
	for _, d in Methods.GetDescendants(self) do
		if not isA(d, "BasePart") or d.CanQuery == false then
			continue
		end
		if params and params.RespectCanCollide and d.CanCollide == false then
			continue
		end
		if filtered(d) then
			continue
		end
		local lo, hi = aabbOf(d.CFrame, d.Size)
		if lo.X < qhi.X and hi.X > qlo.X and lo.Y < qhi.Y and hi.Y > qlo.Y and lo.Z < qhi.Z and hi.Z > qlo.Z then
			table.insert(out, d)
		end
	end
	return out
end

-- Visée du client (InventoryController) : la souris ne bouge pas, le rayon est celui que le banc pose.
MOUSE = { X = 400, Y = 300 }
AIM_RAY = nil
function Methods.GetMouse(_self)
	return MOUSE
end
CAMERA = {
	ScreenPointToRay = function(_self, _x, _y)
		return AIM_RAY or { Origin = Vector3.new(0, 1000, 0), Direction = Vector3.new(0, -1, 0) }
	end,
}
-- Visée vers un point du monde : rayon vertical qui tombe dessus depuis 50 studs plus haut.
function aimAt(point)
	AIM_RAY = { Origin = point + Vector3.new(0, 50, 0), Direction = Vector3.new(0, -1, 0) }
end
