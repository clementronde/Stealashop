-- Compléments du faux Roblox d'a104 pour le banc a119 (ajouts purs, rien de changé dans le harnais).

-- Random déterministe (graine fixe).
Random = {
	new = function(seed)
		local state = (seed or 12345) % 2147483647
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 48271) % 2147483647
			local x = state / 2147483647
			if a ~= nil then
				return a + (b - a) * x
			end
			return x
		end
		return r
	end,
}

local V2 = {}
V2.__index = V2
V2.__type = "Vector2"
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2)
	end,
}
Vector2.zero = Vector2.new(0, 0)

NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b or a }
	end,
}
NumberSequenceKeypoint.new = function(t, v, e)
	return { Time = t, Value = v, Envelope = e or 0 }
end

-- HSV (formules de Roblox).
local C3mt = getmetatable(Color3.new(0, 0, 0))
function C3mt.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local d = max - min
	local h = 0
	if d > 0 then
		if max == r then
			h = ((g - b) / d) % 6
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	local s = if max > 0 then d / max else 0
	return h, s, max
end
Color3.fromHSV = function(h, s, v)
	h = (h % 1) * 6
	local i = math.floor(h)
	local f = h - i
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	local rgb = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1]
	return Color3.new(rgb[1], rgb[2], rgb[3])
end

-- CFrame : VectorToWorldSpace, ==, + Vector3.
local CFmt = getmetatable(CFrame.new())
local CFmethods = {}
local oldIndex = CFmt.__index
CFmt.__index = function(c, k)
	if CFmethods[k] then
		return CFmethods[k]
	end
	return oldIndex(c, k)
end
function CFmethods.VectorToWorldSpace(c, v)
	return c:PointToWorldSpace(v) - c.Position
end
CFmt.__eq = function(a, b)
	if a.p ~= b.p then
		return false
	end
	for i = 1, 9 do
		if a.r[i] ~= b.r[i] then
			return false
		end
	end
	return true
end
CFmt.__add = function(a, v)
	return CFrame.new(a.Position + v) * a.Rotation
end

-- Workspace:BulkMoveTo.
rawget(Workspace, "_props").BulkMoveTo = function(_self, parts, cframes)
	BULK_MOVES = (BULK_MOVES or 0) + 1
	for i, part in parts do
		part.CFrame = cframes[i]
	end
end

-- CollectionService:GetTags (noms de tags vus par AddTag, vérifiés avec HasTag : copies comprises).
local seenTags = {}
local oldAddTag = CollectionService.AddTag
function CollectionService:AddTag(inst, tag)
	seenTags[tag] = true
	return oldAddTag(self, inst, tag)
end
function CollectionService:GetTags(inst)
	local out = {}
	for tag in seenTags do
		if CollectionService:HasTag(inst, tag) then
			table.insert(out, tag)
		end
	end
	return out
end


-- Les modules du banc reçoivent leur environnement de requireModule (harnais) : on y ajoute ce qui manque
-- (_G est en lecture seule dans luau.exe).
local baseSetfenv = setfenv
setfenv = function(fn, env)
	if type(env) == "table" then
		env.Random = Random
		env.Vector2 = Vector2
		env.NumberRange = NumberRange
	end
	return baseSetfenv(fn, env)
end
