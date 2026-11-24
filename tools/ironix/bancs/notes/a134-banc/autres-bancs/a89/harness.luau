-- Faux Roblox autonome pour PotionController (banc a89, vague 28, 2026-11-11). check, Vector3 et CFrame repris
-- du banc a82 (harness.luau), plus : Color3, Vector2, UDim2, Enum, signaux, instances (GetDescendants,
-- DescendantAdded, Clone, PivotTo, GetBoundingBox, ScaleTo, attributs), Players (LocalPlayer, PlayerGui,
-- personnages), heure serveur, faux Net, ItemIdleController et UI/Motion simulés, vrais modules Config.

CHECKS, FAILS = 0, 0
function check(label, cond, detail)
	CHECKS += 1
	if cond then
		if VERBOSE then print("ok    " .. label) end
	else
		FAILS += 1
		print("ÉCHEC " .. label .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

-- Vector3 ---------------------------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V)
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	elseif k == "Cross" then
		return function(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	end
	return nil
end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__tostring = function(v) return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z) end
Vector3 = { new = function(x, y, z) return vec(x or 0, y or 0, z or 0) end, zero = vec(0, 0, 0), xAxis = vec(1, 0, 0), yAxis = vec(0, 1, 0), zAxis = vec(0, 0, 1) }

-- CFrame ----------------------------------------------------------------------------------------
local C = {}
local function cfr(p, rx, ry, rz)
	return setmetatable({ _p = p, _x = rx, _y = ry, _z = rz }, C)
end
local function rot(c, v) return c._x * v.X + c._y * v.Y + c._z * v.Z end
local function invRot(c, v) return vec(c._x:Dot(v), c._y:Dot(v), c._z:Dot(v)) end
local function mul(a, b) return cfr(a._p + rot(a, b._p), rot(a, b._x), rot(a, b._y), rot(a, b._z)) end
local function inverse(c)
	local x, y, z = invRot(c, Vector3.xAxis), invRot(c, Vector3.yAxis), invRot(c, Vector3.zAxis)
	local inv = cfr(vec(0, 0, 0), x, y, z)
	return cfr(-rot(inv, c._p), x, y, z)
end
C.__index = function(c, k)
	if k == "Position" then return c._p
	elseif k == "Rotation" then return cfr(vec(0, 0, 0), c._x, c._y, c._z)
	elseif k == "LookVector" then return -c._z
	elseif k == "ToObjectSpace" then return function(a, b) return mul(inverse(a), b) end
	elseif k == "Inverse" then return inverse
	end
	return nil
end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a._p + rot(a, b) end
	return mul(a, b)
end
C.__eq = function(a, b) return a._p == b._p and a._x == b._x and a._y == b._y and a._z == b._z end
C.__tostring = function(c) return "CFrame" .. tostring(c._p) end
local function axisAngle(axis, angle)
	local u = axis.Unit
	local co, s = math.cos(angle), math.sin(angle)
	local function r(v) return v * co + u:Cross(v) * s + u * (u:Dot(v) * (1 - co)) end
	return cfr(vec(0, 0, 0), r(Vector3.xAxis), r(Vector3.yAxis), r(Vector3.zAxis))
end
CFrame = {
	new = function(x, y, z)
		local p = if type(x) == "number" then vec(x, y, z) else (x or vec(0, 0, 0))
		return cfr(p, vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1))
	end,
	fromAxisAngle = axisAngle,
	Angles = function(x, y, z) -- Roblox : Rx * Ry * Rz
		return mul(mul(axisAngle(Vector3.xAxis, x), axisAngle(Vector3.yAxis, y)), axisAngle(Vector3.zAxis, z))
	end,
}
function nearV(a, b, eps) return (a - b).Magnitude <= (eps or 1e-3) end
function nearCF(a, b, eps)
	eps = eps or 1e-3
	return nearV(a._p, b._p, eps) and nearV(a._x, b._x, eps) and nearV(a._y, b._y, eps) and nearV(a._z, b._z, eps)
end
