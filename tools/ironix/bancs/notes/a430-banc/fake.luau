-- Banc a430 : faux Roblox minimal (Vector3, CFrame en translation seule, instances avec Parent, attributs, signaux
-- DescendantAdded / DescendantRemoving, Clone qui recâble les références internes, Model:PivotTo / ScaleTo).
local checks, fails = 0, 0
local function check(ok, label)
	checks += 1
	if not ok then
		fails += 1
		print("ÉCHEC " .. label)
	end
end
local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function()
				local i = table.find(list, fn)
				if i then
					table.remove(list, i)
				end
			end }
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(list) do
				fn(...)
			end
		end,
		Wait = function() end,
	}
end
local function load(source, name, env)
	local fn = assert(loadstring(source, name))
	setfenv(fn, setmetatable(env or {}, { __index = _G }))
	return fn()
end

local V3MT = {}
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3MT)
end
V3MT.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3MT.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3MT.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	end
	return v3(a.X * b, a.Y * b, a.Z * b)
end
V3MT.__div = function(a, n)
	return v3(a.X / n, a.Y / n, a.Z / n)
end
local CFMT = {}
local function cf(x, y, z)
	return setmetatable({ Position = v3(x, y, z), X = x, Y = y, Z = z, RightVector = v3(1, 0, 0), UpVector = v3(0, 1, 0), LookVector = v3(0, 0, -1) }, CFMT)
end
CFMT.__index = { Inverse = function(self)
	return cf(-self.X, -self.Y, -self.Z)
end }
CFMT.__mul = function(a, b)
	return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
CFMT.__add = function(a, v)
	return cf(a.X + v.X, a.Y + v.Y, a.Z + v.Z)
end
CFMT.__sub = function(a, v)
	return cf(a.X - v.X, a.Y - v.Y, a.Z - v.Z)
end

local SUPER = {
	Part = { BasePart = true },
	MeshPart = { BasePart = true },
	Script = { LuaSourceContainer = true },
	LocalScript = { LuaSourceContainer = true },
	ScrollingFrame = { GuiObject = true },
	Frame = { GuiObject = true },
	TextLabel = { GuiObject = true },
	SurfaceGui = { LayerCollector = true },
}
local Inst = {}
local MT = {}
local function sigOf(self, name)
	local s = rawget(self, "_s")
	s[name] = s[name] or signal()
	return s[name]
end
MT.__index = function(self, k)
	local m = Inst[k]
	if m then
		return m
	end
	local p = rawget(self, "_p")
	if k == "WorldCFrame" then
		return p.Parent.CFrame * p.CFrame
	elseif k == "Position" and p.CFrame then
		return p.CFrame.Position
	elseif k == "DescendantAdded" or k == "DescendantRemoving" then
		return sigOf(self, k)
	end
	return p[k]
end
MT.__newindex = function(self, k, v)
	local p = rawget(self, "_p")
	if k == "Parent" then
		local old = p.Parent
		if old == v then
			return
		end
		if old then
			local a = old
			while a do
				local s = rawget(a, "_s").DescendantRemoving
				if s then
					s:Fire(self)
				end
				a = rawget(a, "_p").Parent
			end
			local list = rawget(old, "_c")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		p.Parent = v
		if v then
			table.insert(rawget(v, "_c"), self)
			local a = v
			while a do
				local s = rawget(a, "_s").DescendantAdded
				if s then
					s:Fire(self)
				end
				a = rawget(a, "_p").Parent
			end
		end
		return
	end
	p[k] = v
end
local function new(class, props, parent)
	local self = setmetatable({ _p = { ClassName = class, Name = class }, _c = {}, _a = {}, _s = {} }, MT)
	for k, v in props or {} do
		self[k] = v
	end
	if parent then
		self.Parent = parent
	end
	return self
end
local function isInst(v)
	return type(v) == "table" and getmetatable(v) == MT
end
function Inst.IsA(self, c)
	return self.ClassName == c or (SUPER[self.ClassName] or {})[c] == true
end
function Inst.GetChildren(self)
	return table.clone(rawget(self, "_c"))
end
function Inst.GetDescendants(self)
	local out = {}
	for _, c in rawget(self, "_c") do
		table.insert(out, c)
		for _, d in c:GetDescendants() do
			table.insert(out, d)
		end
	end
	return out
end
function Inst.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_c") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_c") do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Inst.WaitForChild(self, name)
	return assert(self:FindFirstChild(name), "WaitForChild " .. name)
end
function Inst.FindFirstChildOfClass(self, class)
	for _, c in rawget(self, "_c") do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function Inst.IsDescendantOf(self, other)
	local a = self.Parent
	while a do
		if a == other then
			return true
		end
		a = a.Parent
	end
	return false
end
function Inst.Destroy(self)
	for _, c in self:GetChildren() do
		c:Destroy()
	end
	self.Parent = nil
	rawset(self, "_dead", true)
end
function Inst.GetFullName(self)
	return self.Name
end
function Inst.SetAttribute(self, k, v)
	rawget(self, "_a")[k] = v
	local s = rawget(self, "_s")["attr:" .. k]
	if s then
		s:Fire()
	end
end
function Inst.GetAttribute(self, k)
	return rawget(self, "_a")[k]
end
function Inst.GetAttributeChangedSignal(self, k)
	return sigOf(self, "attr:" .. k)
end
function Inst.Clone(self)
	local map = {}
	local function copy(o)
		local c = setmetatable({ _p = {}, _c = {}, _a = table.clone(rawget(o, "_a")), _s = {} }, MT)
		map[o] = c
		for k, v in rawget(o, "_p") do
			if k ~= "Parent" then
				rawget(c, "_p")[k] = v
			end
		end
		for _, child in rawget(o, "_c") do
			local cc = copy(child)
			rawget(cc, "_p").Parent = c
			table.insert(rawget(c, "_c"), cc)
		end
		return c
	end
	local root = copy(self)
	for _, c in map do
		local p = rawget(c, "_p")
		for k, v in p do
			if k ~= "Parent" and isInst(v) and map[v] then
				p[k] = map[v]
			end
		end
	end
	return root
end
function Inst.GetPivot(self)
	local root = self:FindFirstChild("HumanoidRootPart")
	return if root then root.CFrame else cf(0, 0, 0)
end
function Inst.PivotTo(self, target)
	local d = target.Position - self:GetPivot().Position
	for _, item in self:GetDescendants() do
		if item:IsA("BasePart") then
			item.CFrame = item.CFrame + d
		end
	end
end
function Inst.GetScale(self)
	return rawget(self, "_p").Scale or 1
end
function Inst.ScaleTo(self, s)
	local f = s / self:GetScale()
	local piv = self:GetPivot().Position
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local np = piv + (d.CFrame.Position - piv) * f
			d.CFrame = cf(np.X, np.Y, np.Z)
			d.Size = d.Size * f
		elseif d.ClassName == "Attachment" then
			local p = d.CFrame.Position * f
			d.CFrame = cf(p.X, p.Y, p.Z)
		end
	end
	rawget(self, "_p").Scale = s
end
local function fakeTypeof(v)
	if isInst(v) then
		return "Instance"
	end
	return typeof(v)
end
local tagged = {}
local CollectionService = {
	GetTagged = function(_, tag)
		return table.clone(tagged[tag] or {})
	end,
}
local DeepFreeze = load(FREEZE_SOURCE, "DeepFreeze")
local cfgEnv = { script = { Parent = { DeepFreeze = DeepFreeze } }, require = function(m)
	return m
end }
local W = load(WCFG_SOURCE, "WeeklyLeaderboard", table.clone(cfgEnv))
