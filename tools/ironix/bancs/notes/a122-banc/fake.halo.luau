--!nocheck
-- Faux Roblox minimal du banc a122 (halo) : instances qui gardent toutes leurs propriétés, Vector3, CFrame
-- (translations seules, assez pour les centres du banc), couleurs, séquences, NumberRange, Vector2, Enum.
local function typed(name, fields)
	return setmetatable(fields, { __type = name })
end
local V3 = { __type = "Vector3" }
V3.__index = function(self, key)
	if key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	end
	return nil
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
V3.__div = function(a, b)
	return Vector3.new(a.X / b, a.Y / b, a.Z / b)
end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	end,
}
Vector3.one = Vector3.new(1, 1, 1)
Vector3.zero = Vector3.new(0, 0, 0)
local CF = { __type = "CFrame" }
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		return CFrame.new(a.Position + b.Position)
	end
	return a.Position + b
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return setmetatable({ Position = x }, CF)
		end
		return setmetatable({ Position = Vector3.new(x or 0, y or 0, z or 0) }, CF)
	end,
}
Color3 = {
	new = function(r, g, b)
		return typed("Color3", { R = r, G = g, B = b })
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
Color3.fromHex = function(hex)
	hex = string.gsub(hex, "#", "")
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end
ColorSequenceKeypoint = {
	new = function(t, c)
		return typed("ColorSequenceKeypoint", { Time = t, Value = c })
	end,
}
ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) == nil then
			return typed("ColorSequence", { Keypoints = a })
		end
		return typed("ColorSequence", { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } })
	end,
}
NumberSequenceKeypoint = {
	new = function(t, v)
		return typed("NumberSequenceKeypoint", { Time = t, Value = v })
	end,
}
NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then
			return typed("NumberSequence", { Keypoints = a })
		end
		return typed("NumberSequence", { Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, if b == nil then a else b) } })
	end,
}
NumberRange = {
	new = function(a, b)
		return typed("NumberRange", { Min = a, Max = b or a })
	end,
}
Vector2 = {
	new = function(x, y)
		return typed("Vector2", { X = x, Y = y })
	end,
}
Enum = setmetatable({}, {
	__index = function(_, family)
		return setmetatable({}, {
			__index = function(_, item)
				return "Enum." .. family .. "." .. item
			end,
		})
	end,
})

local CLASSES = {
	Part = { "BasePart" },
	Model = {},
	Attachment = {},
	PointLight = { "Light" },
	ParticleEmitter = {},
	Sparkles = {},
	Beam = {},
}
local IMT = { __type = "Instance" }
local Methods = {}
IMT.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "ClassName" then
		return rawget(self, "_class")
	elseif Methods[key] then
		return Methods[key]
	end
	local v = rawget(self, "_props")[key]
	if v == nil and key == "Name" then
		return rawget(self, "_class")
	end
	return v
end
IMT.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local list = rawget(old, "_children")
			for i, c in list do
				if c == self then
					table.remove(list, i)
					break
				end
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	rawget(self, "_props")[key] = value
end
function Methods.IsA(self, class)
	local own = rawget(self, "_class")
	if own == class then
		return true
	end
	for _, base in CLASSES[own] do
		if base == class then
			return true
		end
	end
	return false
end
function Methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in rawget(i, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
Instance = {
	new = function(class)
		assert(CLASSES[class], "classe inconnue du faux : " .. class)
		return setmetatable({ _class = class, _props = {}, _children = {} }, IMT)
	end,
}

-- Texte stable d'un arbre : classe, nom, toutes les propriétés posées (triées), références par chemin.
local function value(v, root)
	if type(v) == "number" then
		return string.format("%.6f", v)
	elseif type(v) ~= "table" then
		return tostring(v)
	end
	local mt = getmetatable(v)
	if mt == IMT then
		local path = {}
		local i = v
		while i and i ~= root do
			table.insert(path, 1, i.Name)
			i = i.Parent
		end
		return "@" .. table.concat(path, "/")
	end
	local keys = {}
	for k in v do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, k in keys do
		table.insert(parts, tostring(k) .. "=" .. value(v[k], root))
	end
	return (if mt and mt.__type then mt.__type else "") .. "{" .. table.concat(parts, ",") .. "}"
end
function dumpTree(root)
	local lines = {}
	local function walk(i, depth)
		local props = rawget(i, "_props")
		local keys = {}
		for k in props do
			table.insert(keys, k)
		end
		table.sort(keys)
		local parts = {}
		for _, k in keys do
			table.insert(parts, k .. "=" .. value(props[k], root))
		end
		table.insert(lines, string.rep("  ", depth) .. rawget(i, "_class") .. " " .. i.Name .. " [" .. table.concat(parts, "; ") .. "]")
		for _, c in rawget(i, "_children") do
			walk(c, depth + 1)
		end
	end
	walk(root, 0)
	return table.concat(lines, "\n")
end
dumpValue = value

local checks, fails = 0, 0
function check(ok, label)
	checks += 1
	if not ok then
		fails += 1
		print("  ÉCHEC : " .. label)
	elseif VERBOSE then
		print("  ok : " .. label)
	end
end
function finish(name)
	print("scénario " .. name .. " : " .. checks .. " vérification(s), " .. fails .. " échec(s)")
end
