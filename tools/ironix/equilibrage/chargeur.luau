--!nocheck
-- Chargeur du simulateur d'équilibrage (tools/ironix/equilibrage/run.sh le place à la fin du fichier
-- assemblé, après SOURCES et OPTIONS). Il exécute les vraies sources de src/shared/Config, sans les
-- modifier : chaque module reçoit un faux `script` (script.Parent.<Nom>) et un faux `require`.
-- Du Roblox, les modules de Config n'utilisent que Color3 (couleurs, sans effet sur l'équilibrage).

Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
	fromHex = function(hex)
		return { Hex = hex }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}

local RefMT = {}
local function ref(path)
	return setmetatable({ __path = path }, RefMT)
end
RefMT.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		return ref((string.gsub(path, "/?[^/]*$", "")))
	end
	return ref(if path == "" then key else path .. "/" .. key)
end

local loaded = {}
local loading = {}

-- charge("Config/Balance") : exécute la source une fois et garde son résultat.
function charge(path)
	if loaded[path] ~= nil then
		return loaded[path]
	end
	local source = SOURCES[path]
	if source == nil then
		error(`module absent des sources assemblées : {path}`, 2)
	end
	if loading[path] then
		error(`require en boucle : {path}`, 2)
	end
	loading[path] = true
	local chunk, problem = loadstring(source, "=" .. path)
	if chunk == nil then
		error(`{path} ne compile pas : {problem}`, 2)
	end
	local env = setmetatable({
		script = ref(path),
		require = function(target)
			local targetPath = if type(target) == "table" then rawget(target, "__path") else nil
			if targetPath == nil then
				error(`{path} : require d'autre chose qu'un module voisin`, 2)
			end
			return charge(targetPath)
		end,
	}, { __index = getfenv(0) })
	setfenv(chunk, env)
	local result = chunk()
	loading[path] = nil
	loaded[path] = result
	return result
end

-- Config.Balance, Config.Zones… : chargés à la demande.
Config = setmetatable({}, {
	__index = function(self, name)
		local module = charge("Config/" .. name)
		rawset(self, name, module)
		return module
	end,
})
Format = charge("Format")

charge("Outil/rapport")
