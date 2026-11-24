--!nocheck
-- Chargeur commun des outils tools/ironix/tableaux.sh et tools/ironix/orphelins.sh : faux Roblox (Color3, Vector3,
-- UDim2, Enum) et charge("Config/Balance"), qui exécute une source de SOURCES avec un faux `script` et un faux
-- `require` (script.Parent.<Nom>), comme tools/ironix/equilibrage/chargeur.luau. Les scripts .sh le placent après
-- SOURCES et OPTIONS, avant le fichier propre à l'outil.

-- Valeurs Roblox factices : marquées par la métatable FAUX (orphelins/extraire.luau ne les prend pas pour des réglages).
FAUX = { __type = "FauxRoblox" }
local function faux(t)
	return setmetatable(t, FAUX)
end
Color3 = {
	fromRGB = function(r, g, b)
		return faux({ R = r / 255, G = g / 255, B = b / 255 })
	end,
	fromHex = function(hex)
		return faux({ Hex = hex })
	end,
	new = function(r, g, b)
		return faux({ R = r, G = g, B = b })
	end,
}
Vector3 = {
	new = function(x, y, z)
		return faux({ X = x, Y = y, Z = z })
	end,
}
Vector2 = Vector3
UDim2 = {
	new = function(...)
		return faux({ ... })
	end,
	fromScale = function(...)
		return faux({ ... })
	end,
	fromOffset = function(...)
		return faux({ ... })
	end,
}
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })

-- Faux `script` et `require` (comme tools/ironix/equilibrage/chargeur.luau) : script.Parent.<Nom>, et
-- script.Parent:FindFirstChild("<Nom>") / :WaitForChild (nil si le module n'est pas dans SOURCES).
local RefMT = {}
local function ref(path)
	return setmetatable({ __path = path }, RefMT)
end
RefMT.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		return ref((string.gsub(path, "/?[^/]*$", "")))
	end
	if key == "FindFirstChild" or key == "WaitForChild" then
		return function(_, name)
			local child = if path == "" then name else path .. "/" .. name
			return if SOURCES[child] ~= nil then ref(child) else nil
		end
	end
	return ref(if path == "" then key else path .. "/" .. key)
end

local loaded = {}
function charge(path)
	if loaded[path] ~= nil then
		return loaded[path]
	end
	local source = SOURCES[path]
	if source == nil then
		error(`module absent des sources assemblées : {path}`, 2)
	end
	local chunk, problem = loadstring(source, "=" .. path)
	if chunk == nil then
		error(`{path} ne compile pas : {problem}`, 2)
	end
	setfenv(chunk, setmetatable({
		script = ref(path),
		require = function(target)
			return charge(rawget(target, "__path"))
		end,
	}, { __index = getfenv(0) }))
	local result = chunk()
	loaded[path] = result
	return result
end

