---------------------------------------------------------------- a22 : compléments des bouchons
-- Random de Roblox : NextInteger(a, b) et NextNumber(), suite reproductible (graine).
local RandomMT = { __type = "Random" }
RandomMT.__index = RandomMT
Random = {}
function Random.new(seed)
	return setmetatable({ state = (seed or 12345) % 2147483647 }, RandomMT)
end
function RandomMT:NextNumber(low, high)
	self.state = (self.state * 48271) % 2147483647
	local x = self.state / 2147483647
	if low ~= nil then
		return low + x * (high - low)
	end
	return x
end
function RandomMT:NextInteger(low, high)
	return low + math.floor(self:NextNumber() * (high - low + 1))
end

-- Player:Kick (DataService) : noté dans KICKS.
KICKS = {}
function METHODS.Kick(self, message)
	table.insert(KICKS, { player = self, message = message })
end

-- Faux ProfileStore : une session s'ouvre tout de suite ; ses données sont une copie de
-- PRESET_PROFILES[clé] (profil sauvegardé préparé par le banc) ou, à défaut, du modèle. Reconcile
-- complète les champs manquants comme le vrai (copie profonde du modèle).
PRESET_PROFILES = {}
SESSIONS = {} -- [clé] = profil ouvert
SOURCES["stub/ProfileStore"] = [==[
local ProfileStore = { DataStoreState = "NoInternet", IsClosing = false }
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
local function reconcile(target, template)
	for k, v in template do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(target[k]) == "table" and type(v) == "table" then
			reconcile(target[k], v)
		end
	end
end
function ProfileStore.New(_name, template)
	local store = {}
	function store.StartSessionAsync(_self, key, _params)
		local preset = PRESET_PROFILES[key]
		local profile = { Data = deepCopy(if preset ~= nil then preset else template), Key = key, active = true, ended = false }
		function profile.IsActive(self)
			return self.active
		end
		function profile.Reconcile(self)
			reconcile(self.Data, template)
		end
		function profile.EndSession(self)
			self.active = false
			self.ended = true
		end
		function profile.AddUserId() end
		profile.OnSessionEnd = { Connect = function(_self, _fn) return { Disconnect = function() end } end }
		SESSIONS[key] = profile
		return profile
	end
	return store
end
return ProfileStore
]==]
