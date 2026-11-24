---------------------------------------------------------------- a25 : compléments des bouchons
-- Ajouts à la copie des bouchons d'a22 (stubs.luau), pour StoreInfoController et le ContractChecker :
--   - UDim et UDim2 de Roblox (.X et .Y sont des UDim, avec Scale et Offset), Vector2 ;
--   - CFrame.RightVector et CFrame.UpVector ;
--   - BillboardGui : SizeOffset, StudsOffsetWorldSpace, ExtentsOffset, ResetOnSpawn ;
--   - CollectionService comme Roblox : GetTagged ne rend que les instances du DataModel, et un objet
--     taggé qui entre dans le DataModel ou en sort déclenche InstanceAdded ou InstanceRemoved
--     (streaming) ; AddTag hors du DataModel ne déclenche rien ;
--   - flush() : lance les tâches en attente (task.defer) sans avancer le temps.

local UDimMT = { __type = "UDim" }
UDimMT.__index = UDimMT
UDimMT.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UDim = {
	new = function(scale, offset)
		return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMT)
	end,
}
local UDim2MT = { __type = "UDim2" }
UDim2MT.__index = UDim2MT
UDim2MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UDim2MT.__tostring = function(u)
	return string.format("{%g, %g}, {%g, %g}", u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset)
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		local x, y = UDim.new(xs, xo), UDim.new(ys, yo)
		return setmetatable({ X = x, Y = y, XScale = x.Scale, XOffset = x.Offset, YScale = y.Scale, YOffset = y.Offset }, UDim2MT)
	end,
}
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end

local V2MT = { __type = "Vector2" }
V2MT.__index = V2MT
V2MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
V2MT.__tostring = function(v)
	return string.format("(%g, %g)", v.X, v.Y)
end
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2MT)
	end,
}
Vector2.zero = Vector2.new(0, 0)

do
	local baseIndex = CFMT.__index
	CFMT.__index = function(c, k)
		if k == "RightVector" then
			return Vector3.new(c.r[1], c.r[4], c.r[7])
		elseif k == "UpVector" then
			return Vector3.new(c.r[2], c.r[5], c.r[8])
		end
		return baseIndex(c, k)
	end
end
-- CFrame à rotation donnée (lignes de la matrice 3 × 3), pour une pièce penchée.
function cframeWithRotation(position, r)
	return setmetatable({ p = position, r = r }, CFMT)
end

do
	local baseBillboard = PROPS.BillboardGui
	PROPS.BillboardGui = function()
		local t = baseBillboard()
		t.SizeOffset = Vector2.new(0, 0)
		t.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
		t.ExtentsOffset = Vector3.new(0, 0, 0)
		t.ResetOnSpawn = true
		return t
	end
end

function inDataModel(inst)
	local current = inst
	while current do
		if current == DataModel then
			return true
		end
		current = rawget(current, "_parent")
	end
	return false
end

do
	local baseGetTagged = CollectionServiceStub.GetTagged
	CollectionServiceStub.GetTagged = function(self, tag)
		local out = {}
		for _, inst in baseGetTagged(self, tag) do
			if inDataModel(inst) then
				table.insert(out, inst)
			end
		end
		return out
	end
end

function addTag(inst, tag)
	tagsOf[inst] = tagsOf[inst] or {}
	if tagsOf[inst][tag] then
		return
	end
	tagsOf[inst][tag] = true
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], inst)
	if inDataModel(inst) then
		sig(addedSignals, tag):Fire(inst)
	end
end

do
	local baseNewIndex = InstanceMT.__newindex
	InstanceMT.__newindex = function(self, key, value)
		if key ~= "Parent" then
			return baseNewIndex(self, key, value)
		end
		local before = inDataModel(self)
		baseNewIndex(self, key, value)
		local after = inDataModel(self)
		if before == after then
			return
		end
		local moved = { self }
		for _, d in Methods.GetDescendants(self) do
			table.insert(moved, d)
		end
		for _, inst in moved do
			for tag in tagsOf[inst] or {} do
				sig(if after then addedSignals else removedSignals, tag):Fire(inst)
			end
		end
	end
end

function flush()
	runQueue(now())
end
