--!nocheck
-- Chargeur minimal des modules de src/shared (banc a262) : arbre d'objets à partir des chemins de SOURCES,
-- script.Parent, enfants par nom, WaitForChild et FindFirstChild ; Color3 factice. Rien d'autre de Roblox.

WARNS = {}
local children = {}
local NodeMT = {}
NodeMT.__index = function(t, k)
	if k == "WaitForChild" then
		return function(self, name)
			local c = children[self][name]
			assert(c ~= nil, "WaitForChild : pas d'enfant " .. tostring(name) .. " dans " .. rawget(self, "Name"))
			return c
		end
	elseif k == "FindFirstChild" then
		return function(self, name)
			return children[self][name]
		end
	end
	local c = children[t][k]
	if c == nil then
		error("pas d'enfant " .. tostring(k) .. " dans " .. tostring(rawget(t, "Name")), 2)
	end
	return c
end
local function mk(name, parent)
	local n = setmetatable({}, NodeMT)
	rawset(n, "Name", name)
	rawset(n, "Parent", parent)
	children[n] = {}
	if parent then
		children[parent][name] = n
	end
	return n
end

SHARED = mk("Shared", mk("ReplicatedStorage", nil))
local keyOf = {}
for key in SOURCES do
	local parts = string.split((key:gsub("%.luau$", "")), "/")
	local cur = SHARED
	for i, part in parts do
		if i == #parts then
			if part == "init" then
				keyOf[cur] = key
			else
				local m = children[cur][part] or mk(part, cur)
				keyOf[m] = key
			end
		else
			cur = children[cur][part] or mk(part, cur)
		end
	end
end

local Color3Stub = {
	fromHex = function(h)
		return { Hex = h }
	end,
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}

-- Types de données Roblox factices (tables), juste pour charger les Config : jamais lus par les scénarios.
local function dataType(name)
	return setmetatable({}, {
		__index = function(_, k)
			return function(...)
				return { Type = name, Ctor = k, Args = { ... } }
			end
		end,
	})
end
local function enumProxy(path)
	return setmetatable({ Path = path }, {
		__index = function(_, k)
			return enumProxy(path .. "." .. tostring(k))
		end,
	})
end
local ROBLOX = { Enum = enumProxy("Enum") }
for _, name in { "Vector3", "Vector2", "UDim", "UDim2", "CFrame", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "TweenInfo", "Rect", "BrickColor" } do
	ROBLOX[name] = dataType(name)
end

local cache = {}
function req(m)
	local hit = cache[m]
	if hit ~= nil then
		return hit
	end
	local key = keyOf[m]
	assert(key, "require d'un objet sans source : " .. tostring(rawget(m, "Name")))
	local fn, err = loadstring(SOURCES[key], key)
	assert(fn, err)
	setfenv(
		fn,
		setmetatable({
			script = m,
			require = req,
			Color3 = Color3Stub,
			Vector3 = ROBLOX.Vector3, Vector2 = ROBLOX.Vector2, UDim = ROBLOX.UDim, UDim2 = ROBLOX.UDim2, CFrame = ROBLOX.CFrame,
			NumberRange = ROBLOX.NumberRange, NumberSequence = ROBLOX.NumberSequence, NumberSequenceKeypoint = ROBLOX.NumberSequenceKeypoint,
			ColorSequence = ROBLOX.ColorSequence, ColorSequenceKeypoint = ROBLOX.ColorSequenceKeypoint, TweenInfo = ROBLOX.TweenInfo,
			Rect = ROBLOX.Rect, BrickColor = ROBLOX.BrickColor, Enum = ROBLOX.Enum,
			warn = function(...)
				table.insert(WARNS, table.concat({ ... }, " "))
			end,
		}, { __index = getfenv(1) })
	)
	local value = fn()
	cache[m] = value
	return value
end

function shared(path)
	local cur = SHARED
	for _, part in string.split(path, "/") do
		cur = cur:WaitForChild(part)
	end
	return req(cur)
end
