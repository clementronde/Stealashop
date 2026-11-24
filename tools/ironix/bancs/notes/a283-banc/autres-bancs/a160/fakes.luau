-- Banc a160 (vague 50, hub) : faux Roblox minimal, commun aux trois scénarios. SOURCES[...] est écrit avant ce
-- fichier par run.sh (vraies sources du dépôt, sans \r).
checks, fails = 0, 0
function check(ok, label)
	checks += 1
	if not ok then
		fails += 1
		print("ÉCHEC " .. label)
	elseif VERBOSE then
		print("ok " .. label)
	end
end

-- Vector3 et CFrame (translation seule ; la rotation est gardée à part, pour le cadeau).
local V = {}
V.__index = V
function V.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__add = function(a, b) return V.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return V.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	return V[k]
end
Vector3 = { new = V.new }

local C = {}
C.__index = C
local function cf(p, angle) return setmetatable({ Position = p, Angle = angle or 0 }, C) end
C.__mul = function(a, b) return cf(a.Position + b.Position, a.Angle + b.Angle) end
function C:PointToObjectSpace(v) return v - self.Position end
CFrame = {
	new = function(x, y, z) return cf(V.new(x, y, z), 0) end,
	Angles = function(_, y, _) return cf(V.new(0, 0, 0), y) end,
}

function signal()
	local s = { list = {} }
	function s:Connect(f)
		table.insert(self.list, f)
		-- a283 : Disconnect retire vraiment la fonction (étiquette sortie du Workspace)
		return { Disconnect = function() local i = table.find(self.list, f); if i then table.remove(self.list, i) end end }
	end
	function s:Fire(...)
		for _, f in self.list do f(...) end
	end
	return s
end

-- Instance factice : Name, Parent, enfants, attributs, IsA par une liste de classes.
function inst(className, name, classes)
	local o = { ClassName = className, Name = name, Parent = nil, _children = {}, _attrs = {}, _attrSignals = {} }
	o.AncestryChanged = signal() -- a283 (ajout pur)
	local isa = { Instance = true, [className] = true }
	for _, c in classes or {} do isa[c] = true end
	function o:IsA(c) return isa[c] == true end
	function o:GetChildren() return self._children end
	function o:GetDescendants()
		local out = {}
		local function walk(n) for _, c in n._children do table.insert(out, c); walk(c) end end
		walk(self)
		return out
	end
	function o:FindFirstChild(n, recursive)
		for _, c in self._children do if c.Name == n then return c end end
		if recursive then
			for _, c in self._children do local f = c:FindFirstChild(n, true); if f then return f end end
		end
		return nil
	end
	function o:WaitForChild(n) return self:FindFirstChild(n) end
	function o:FindFirstChildOfClass(c) for _, ch in self._children do if ch.ClassName == c then return ch end end return nil end
	function o:FindFirstAncestorOfClass(c)
		local p = self.Parent
		while p do if p.ClassName == c then return p end p = p.Parent end
		return nil
	end
	function o:IsDescendantOf(a)
		local p = self.Parent
		while p do if p == a then return true end p = p.Parent end
		return false
	end
	function o:GetFullName() return (self.Parent and self.Parent ~= GAME and (self.Parent:GetFullName() .. ".") or "") .. self.Name end
	function o:GetAttribute(k) return self._attrs[k] end
	function o:SetAttribute(k, v)
		self._attrs[k] = v
		local s = self._attrSignals[k]
		if s then s:Fire() end
	end
	function o:GetAttributeChangedSignal(k)
		self._attrSignals[k] = self._attrSignals[k] or signal()
		return self._attrSignals[k]
	end
	return o
end

function parent(child, p)
	child.Parent = p
	table.insert(p._children, child)
	return child
end

-- Chargeur : la source du dépôt, exécutée dans un environnement donné (require = la valeur elle-même).
function load(path, env)
	local src = assert(SOURCES[path], "source absente : " .. path)
	local fn = assert(loadstring(src, path))
	setfenv(fn, setmetatable(env, { __index = getfenv(1) })) -- les faux Vector3 et CFrame de ce fichier
	return fn()
end

-- Config/Hub et Shared/HubZone, réels.
function realHub()
	local deepFreeze = load("shared/Config/DeepFreeze.luau", { script = {} })
	local Hub = load("shared/Config/Hub.luau", { script = { Parent = { DeepFreeze = deepFreeze } }, require = function(m) return m end })
	local configFolder = { WaitForChild = function(_, n) return ({ Hub = Hub })[n] end }
	local HubZone = load("shared/HubZone.luau", {
		script = { Parent = { WaitForChild = function(_, n) return ({ Config = configFolder })[n] end } },
		require = function(m) return m end,
	})
	return Hub, HubZone
end
