-- Banc a413 (vague GC7, 23/11) : badges du jeu. Vrai BadgeService, vrais Config/Badges, Items, Rarities, Features
-- (lus dans SOURCES, ajouté par run.sh) sur un petit faux Roblox : DataService, Players, BadgeService de Roblox,
-- task (coroutines avancées à la main), os.clock réglable, ProductIds bouchonné (IsDev).
--   B0 Config/Badges : 6 à 10 badges, clés uniques, Id et DevId à 0, textes et image remplis, règles valides
--   B1 Earned : chaque règle (seuils, rareté « ou plus rare », exclusifs Robux ignorés, zone 6, profil abîmé)
--   B2 Id tous à 0 : aucune requête à Roblox, aucun relevé
--   B3 Id posés : Welcome à l'arrivée, une seule fois ; FirstHeist au relevé suivant ; déjà possédé : pas d'AwardBadge
--   B4 erreurs de Roblox : rattrapées, nouvel essai après RetryDelay, abandon après MaxTries (un avertissement)
--   B5 AwardBadge répond false : un avertissement, plus d'essai
--   B6 jeu DEV : DevId lu (0 = sauté) ; B7 Features.Badges coupé : rien ; B8 départ : plus de requête
--   aucune erreur

CHECKS, FAILS = 0, 0
local function check(label, cond, detail)
	CHECKS += 1
	if cond then
		if VERBOSE then
			print("ok    " .. label)
		end
	else
		FAILS += 1
		print("ÉCHEC " .. label .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

local NOW = 0
local LOGS = {}
local SLEEPERS = {}

-- Arbre d'instances minimal : un nœud par nom, enfants par index.
local function node(name, parent, key)
	local n = { Name = name, _children = {}, _key = key }
	setmetatable(n, {
		__index = function(t, k)
			local c = rawget(t, "_children")[k]
			if c ~= nil then
				return c
			end
			error("enfant absent : " .. tostring(k) .. " dans " .. tostring(rawget(t, "Name")))
		end,
	})
	n.FindFirstChild = function(self, k)
		return rawget(self, "_children")[k]
	end
	n.IsA = function(_, class)
		return class == "ModuleScript" and rawget(n, "_key") ~= nil or false
	end
	if parent then
		rawget(parent, "_children")[name] = n
		n.Parent = parent
	end
	return n
end

local function signal()
	local s = { list = {} }
	function s:Connect(f)
		table.insert(self.list, f)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, f in self.list do
			f(...)
		end
	end
	return s
end

local function spawnThread(f, ...)
	local co = coroutine.create(f)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(err)
	end
	if coroutine.status(co) == "suspended" then
		table.insert(SLEEPERS, co)
	end
end

local FTask = {
	spawn = spawnThread,
	wait = function(s)
		coroutine.yield(s)
	end,
}

-- Une boucle de relevé : chaque fil endormi repart une fois.
local function tick(seconds)
	NOW += seconds or 2
	local list = SLEEPERS
	SLEEPERS = {}
	for _, co in list do
		local ok, err = coroutine.resume(co)
		if not ok then
			error(err)
		end
		if coroutine.status(co) == "suspended" then
			table.insert(SLEEPERS, co)
		end
	end
end

local FColor3 = {
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

local World

local function boot(opts)
	opts = opts or {}
	NOW = 100
	LOGS = {}
	SLEEPERS = {}
	local cache = {}
	local W = {
		calls = {}, -- { kind, userId, id }
		owned = {}, -- [userId .. ":" .. id] = true
		hasError = 0, -- nombre d'erreurs à lever sur UserHasBadgeAsync
		awardResult = true,
		data = {},
		loaded = signal(),
		removing = signal(),
		players = {},
	}
	World = W

	local game = node("game")
	local RS = node("ReplicatedStorage", game)
	local Shared = node("Shared", RS)
	local Config = node("Config", Shared)
	local Types = node("Types", Shared)
	local SSS = node("ServerScriptService", game)
	local Services = node("Services", SSS)

	local fixed = {}
	local function module(name, parent, key, value)
		local m = node(name, parent, key or ("fixed:" .. name))
		if value ~= nil then
			fixed[m] = value
		end
		return m
	end
	module("DeepFreeze", Config, "shared/Config/DeepFreeze.luau")
	module("Rarities", Config, "shared/Config/Rarities.luau")
	module("Items", Config, "shared/Config/Items.luau")
	module("Badges", Config, "shared/Config/Badges.luau")
	if opts.features then
		module("Features", Config, nil, opts.features)
	else
		module("Features", Config, "shared/Config/Features.luau")
	end
	module("ProductIds", Config, nil, { IsDev = opts.dev == true })
	module("Profile", Types, nil, {})
	module("DataService", Services, nil, {
		Get = function(player)
			return W.data[player]
		end,
		OnProfileLoaded = function(f)
			return W.loaded:Connect(f)
		end,
	})
	local serviceScript = module("BadgeService", Services, "server/Services/BadgeService.luau")

	local FPlayers = {
		PlayerRemoving = W.removing,
		GetPlayers = function()
			local out = {}
			for _, p in W.players do
				table.insert(out, p)
			end
			return out
		end,
	}
	local FBadges = {
		UserHasBadgeAsync = function(_, userId, id)
			table.insert(W.calls, { "Has", userId, id })
			if W.hasError > 0 then
				W.hasError -= 1
				error("HTTP 503 (faux)")
			end
			return W.owned[userId .. ":" .. id] == true
		end,
		AwardBadge = function(_, userId, id)
			table.insert(W.calls, { "Award", userId, id })
			if W.awardResult then
				W.owned[userId .. ":" .. id] = true
			end
			return W.awardResult
		end,
	}
	local FRunService = {
		IsStudio = function()
			return true
		end,
	}
	game.GetService = function(_, name)
		if name == "Players" then
			return FPlayers
		elseif name == "ReplicatedStorage" then
			return RS
		elseif name == "RunService" then
			return FRunService
		elseif name == "BadgeService" then
			return FBadges
		end
		error("service absent du faux : " .. name)
	end
	W.Players = FPlayers

	local function requireModule(m)
		if fixed[m] ~= nil then
			return fixed[m]
		end
		if cache[m] ~= nil then
			return cache[m]
		end
		local key = rawget(m, "_key")
		local src = assert(SOURCES[key], key)
		if key == "shared/Config/Badges.luau" and opts.patchBadges then
			src = opts.patchBadges(src)
		end
		local fn = assert(loadstring(src, key))
		setfenv(fn, setmetatable({
			script = m,
			require = requireModule,
			game = game,
			Color3 = FColor3,
			task = FTask,
			os = setmetatable({
				clock = function()
					return NOW
				end,
			}, { __index = os }),
			print = function(...)
				table.insert(LOGS, table.concat({ ... }, " "))
			end,
			warn = function(...)
				table.insert(LOGS, "WARN " .. table.concat({ ... }, " "))
			end,
		}, { __index = getfenv(1) }))
		local v = fn()
		cache[m] = v
		return v
	end
	W.require = requireModule
	W.Badges = requireModule(Config.Badges)
	W.Items = requireModule(Config.Items)
	W.Service = requireModule(serviceScript)
	return W
end

local nextUser = 1000
local function newPlayer(W)
	nextUser += 1
	local p = { Name = "P" .. nextUser, UserId = nextUser }
	p.Parent = W.Players
	table.insert(W.players, p)
	return p
end

local function freshData()
	return {
		Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 0 },
		Index = {},
		Rebirths = 0,
	}
end

local function join(W, data)
	local p = newPlayer(W)
	W.data[p] = data or freshData()
	W.loaded:Fire(p)
	return p
end

local function count(W, kind, id)
	local n = 0
	for _, c in W.calls do
		if c[1] == kind and (id == nil or c[3] == id) then
			n += 1
		end
	end
	return n
end

local function warns()
	local n = 0
	for _, l in LOGS do
		if string.sub(l, 1, 5) == "WARN " then
			n += 1
		end
	end
	return n
end

-- Ids de test : Id = 100 + rang, DevId = 0 sauf FirstHeist (500).
local function withIds(dev)
	return function(src)
		local rank = 0
		src = string.gsub(src, "\n(\t+)Id = 0,", function(tabs)
			rank += 1
			return "\n" .. tabs .. "Id = " .. tostring(100 + rank) .. ","
		end)
		if dev then
			src = string.gsub(src, '(Key = "FirstHeist",%s*Id = %d+,%s*)DevId = 0,', "%1DevId = 500,")
		end
		return src
	end
end

local function itemOf(W, pred)
	for id, item in W.Items.ById do
		if pred(item) and not string.find(id, "^Exclusive_") then
			return id
		end
	end
	return nil
end

------------------------------------------------------------------------------
-- B0
------------------------------------------------------------------------------
do
	local W = boot()
	local list = W.Badges.List
	check("B0 6 à 10 badges", #list >= 6 and #list <= 10, #list)
	local keys, rules = {}, { Join = 1, Heists = 1, Steals = 1, Rarity = 1, ZoneItem = 1, Rebirths = 1, BestIncome = 1 }
	for _, b in list do
		check("B0 clé unique " .. b.Key, keys[b.Key] == nil)
		keys[b.Key] = true
		check("B0 Id et DevId à 0 " .. b.Key, b.Id == 0 and b.DevId == 0)
		check("B0 règle connue " .. b.Key, rules[b.Rule] ~= nil, b.Rule)
		check("B0 textes " .. b.Key, type(b.Name) == "string" and #b.Name > 0 and #b.Name <= 50
			and type(b.Description) == "string" and #b.Description > 0 and type(b.Image) == "string" and #b.Image > 0)
		if b.Rule == "Rarity" then
			local found = false
			for _, item in W.Items.ById do
				if item.Rarity == b.Rarity then
					found = true
				end
			end
			check("B0 rareté existante " .. b.Key, found, b.Rarity)
		end
	end
	check("B0 réglages", W.Badges.CheckInterval > 0 and W.Badges.RetryDelay > 0 and W.Badges.MaxTries >= 1)
end

------------------------------------------------------------------------------
-- B1
------------------------------------------------------------------------------
do
	local W = boot()
	local S = W.Service
	local by = {}
	for _, b in W.Badges.List do
		by[b.Key] = b
	end
	local function earned(data)
		local out = {}
		for _, b in W.Badges.List do
			if S.Earned(data, b) then
				table.insert(out, b.Key)
			end
		end
		table.sort(out)
		return table.concat(out, ",")
	end
	check("B1 profil neuf : Welcome seul", earned(freshData()) == "Welcome", earned(freshData()))
	local d = freshData()
	d.Lifetime.Heists = 1
	check("B1 Heists 1", S.Earned(d, by.FirstHeist))
	d.Lifetime.Steals = 1
	check("B1 Steals 1", S.Earned(d, by.FirstSteal))
	d.Rebirths = 1
	check("B1 Rebirths 1", S.Earned(d, by.Reborn))
	d.Lifetime.BestIncome = 999_999
	check("B1 BestIncome 999 999 : non", not S.Earned(d, by.Millionaire))
	d.Lifetime.BestIncome = 1_000_000
	check("B1 BestIncome 1M", S.Earned(d, by.Millionaire))

	-- Légendaire de zone 5 (sans Zone6) ; Mythique où qu'il soit (zone 6 : Zone6 aussi).
	local legendary = itemOf(W, function(i) return i.Rarity == "Legendary" and i.Zone == 5 end)
	local mythic = itemOf(W, function(i) return i.Rarity == "Mythic" end)
	local secret = itemOf(W, function(i) return i.Rarity == "Secret" end)
	local zone6 = itemOf(W, function(i) return i.Zone == 6 and i.Rarity == "Rare" end)
	check("B1 objets du catalogue trouvés", legendary and mythic and secret and zone6,
		tostring(legendary) .. " " .. tostring(mythic) .. " " .. tostring(secret) .. " " .. tostring(zone6))
	if not (legendary and mythic and secret and zone6) then
		error("objets du catalogue introuvables")
	end

	local e = freshData()
	e.Index[legendary] = 1
	check("B1 Légendaire de zone 5 : pas Zone6", earned(e) == "Legendary,Welcome", earned(e))
	e = freshData()
	e.Index[mythic] = 1
	local mythicZone6 = if W.Items.ById[mythic].Zone == 6 then ",Zone6" else ""
	check("B1 Mythique : Légendaire aussi", earned(e) == "Legendary,Mythic,Welcome" .. mythicZone6, earned(e))
	e = freshData()
	e.Index[secret] = 1
	check("B1 Secret : les trois", earned(e) == "Legendary,Mythic,Secret,Welcome", earned(e))
	e = freshData()
	e.Index.Exclusive_GoldenRocket = 1
	e.Index.Exclusive_NeonJukebox = 1
	check("B1 exclusifs Robux ignorés", earned(e) == "Welcome", earned(e))
	e = freshData()
	e.Index[zone6] = 1
	check("B1 objet de zone 6", earned(e) == "Welcome,Zone6", earned(e))
	e = freshData()
	e.Index.ObjetInconnu = 1
	check("B1 ItemId inconnu ignoré", earned(e) == "Welcome", earned(e))
	local broken = { Lifetime = "x", Index = 5, Rebirths = "?" }
	local ok, res = pcall(earned, broken)
	check("B1 profil abîmé : sans erreur", ok and res == "Welcome", res)
	local nan = freshData()
	nan.Lifetime.Heists = 0 / 0
	check("B1 NaN : non", not S.Earned(nan, by.FirstHeist))
end

------------------------------------------------------------------------------
-- B2 : Id à 0
------------------------------------------------------------------------------
do
	local W = boot()
	W.Service.Start()
	local d = freshData()
	d.Lifetime.Heists = 3
	join(W, d)
	tick()
	tick()
	check("B2 Id à 0 : aucune requête", #W.calls == 0, #W.calls)
	check("B2 Id à 0 : aucune boucle", #SLEEPERS == 0, #SLEEPERS)
	check("B2 aucun avertissement", warns() == 0, warns())
end

------------------------------------------------------------------------------
-- B3 : Id posés
------------------------------------------------------------------------------
do
	local W = boot({ patchBadges = withIds(false) })
	local ids = {}
	for _, b in W.Badges.List do
		ids[b.Key] = b.Id
	end
	check("B3 Id posés par le banc", ids.Welcome == 101 and ids.FirstHeist == 102)
	W.Service.Start()
	local d = freshData()
	local p = join(W, d)
	check("B3 Welcome demandé et donné à l'arrivée", count(W, "Has", 101) == 1 and count(W, "Award", 101) == 1)
	check("B3 rien d'autre", #W.calls == 2, #W.calls)
	check("B3 noté", W.Service.HasNoted(p, "Welcome"))
	tick()
	tick()
	check("B3 Welcome pas redemandé", #W.calls == 2, #W.calls)
	d.Lifetime.Heists = 1
	tick()
	check("B3 FirstHeist au relevé suivant", count(W, "Award", 102) == 1)
	tick()
	check("B3 FirstHeist une fois", count(W, "Award", 102) == 1 and count(W, "Has", 102) == 1)
	-- Déjà possédé (session d'avant) : pas d'AwardBadge.
	W.owned[p.UserId .. ":" .. ids.FirstSteal] = true
	d.Lifetime.Steals = 2
	tick()
	check("B3 déjà possédé : Has seul", count(W, "Has", ids.FirstSteal) == 1 and count(W, "Award", ids.FirstSteal) == 0)
	check("B3 déjà possédé : noté", W.Service.HasNoted(p, "FirstSteal"))
	-- Deuxième joueur : ses badges à lui.
	local q = join(W)
	check("B3 2e joueur : son Welcome", count(W, "Award", 101) == 2)
	check("B3 2e joueur : pas de FirstHeist", not W.Service.HasNoted(q, "FirstHeist"))
	check("B3 aucun avertissement", warns() == 0, warns())
end

------------------------------------------------------------------------------
-- B4 : erreurs
------------------------------------------------------------------------------
do
	local W = boot({ patchBadges = withIds(false) })
	local B = W.Badges
	W.Service.Start()
	W.hasError = 1
	local ok = pcall(join, W)
	check("B4 erreur rattrapée", ok)
	local p = W.players[1]
	check("B4 pas noté après l'erreur", not W.Service.HasNoted(p, "Welcome"))
	tick(B.CheckInterval)
	check("B4 pas de nouvel essai avant RetryDelay", count(W, "Has", 101) == 1, count(W, "Has", 101))
	tick(B.RetryDelay)
	check("B4 nouvel essai après RetryDelay, donné", count(W, "Has", 101) == 2 and count(W, "Award", 101) == 1)
	check("B4 noté", W.Service.HasNoted(p, "Welcome"))
	-- Erreurs sans fin : abandon après MaxTries.
	W.hasError = 1000
	local q = join(W)
	for _ = 1, B.MaxTries + 3 do
		tick(B.RetryDelay + 1)
	end
	local tries = 0
	for _, c in W.calls do
		if c[1] == "Has" and c[2] == q.UserId and c[3] == 101 then
			tries += 1
		end
	end
	check("B4 abandon après MaxTries", tries == B.MaxTries, tries)
	check("B4 un avertissement d'abandon", warns() == 1, warns())
end

------------------------------------------------------------------------------
-- B5 : AwardBadge répond false
------------------------------------------------------------------------------
do
	local W = boot({ patchBadges = withIds(false) })
	W.Service.Start()
	W.awardResult = false
	local p = join(W)
	tick()
	tick()
	check("B5 un seul AwardBadge", count(W, "Award", 101) == 1)
	check("B5 un avertissement", warns() == 1, warns())
	check("B5 noté (plus d'essai)", W.Service.HasNoted(p, "Welcome"))
end

------------------------------------------------------------------------------
-- B6 : jeu DEV
------------------------------------------------------------------------------
do
	local W = boot({ patchBadges = withIds(true), dev = true })
	W.Service.Start()
	local d = freshData()
	d.Lifetime.Heists = 1
	join(W, d)
	check("B6 DEV : DevId de FirstHeist", count(W, "Award", 500) == 1)
	check("B6 DEV : Id PROD jamais demandé", count(W, "Has", 101) == 0 and count(W, "Has", 102) == 0)
	check("B6 DEV : une seule requête Has", count(W, "Has") == 1, count(W, "Has"))
end

------------------------------------------------------------------------------
-- B7 : interrupteur coupé
------------------------------------------------------------------------------
do
	local W = boot({ patchBadges = withIds(false), features = { Badges = false } })
	W.Service.Start()
	join(W)
	tick()
	check("B7 coupé : aucune requête", #W.calls == 0, #W.calls)
	check("B7 Features.Badges vrai dans le dépôt", string.find(SOURCES["shared/Config/Features.luau"], "\n\tBadges = true,", 1, true) ~= nil)
end

------------------------------------------------------------------------------
-- B8 : départ
------------------------------------------------------------------------------
do
	local W = boot({ patchBadges = withIds(false) })
	W.Service.Start()
	local d = freshData()
	local p = join(W, d)
	W.players = {}
	p.Parent = nil
	W.removing:Fire(p)
	d.Lifetime.Heists = 5
	tick()
	check("B8 parti : plus de requête", count(W, "Has", 102) == 0)
	check("B8 parti : plus noté", not W.Service.HasNoted(p, "Welcome"))
end

print(string.format("banc a413 : %d vérification(s), %d échec(s)", CHECKS, FAILS))
