-- Banc a414 (vague GC7, 23/11) : FunnelService et Config/Funnels, hors Studio. Faux Roblox minimal écrit ici :
-- arbre d'instances, require, task (pollLoop pas à pas), signaux, AnalyticsService qui note chaque appel,
-- HttpService (GUID numérotés), MarketplaceService, Players. Services voisins bouchonnés (DataService, Net,
-- WindowService, CarryService, DisplayService, ShopService, PvPService, PlotService, TelemetryService).
-- Vrais : FunnelService, Config/Funnels, Config/Features, Config/Telemetry, Config/DeepFreeze, Contract/Find.
-- SOURCES[...] est rempli par run.sh avant ce fichier.

local checks, fails = 0, 0
local function check(cond: any, label: string)
	checks += 1
	if not cond then
		fails += 1
		print("ÉCHEC " .. label)
	elseif VERBOSE then
		print("ok " .. label)
	end
end

------------------------------------------------------------------------------
-- Faux Roblox
------------------------------------------------------------------------------

local Vec = {}
Vec.__index = Vec
local function V3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, Vec)
end
Vec.__sub = function(a, b)
	return V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vec.__div = function(a, n)
	return V3(a.X / n, a.Y / n, a.Z / n)
end

local function signal()
	local s = { fns = {} }
	function s:Connect(fn)
		table.insert(self.fns, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.fns do
			fn(...)
		end
	end
	return s
end

local NodeMethods = {}
local NodeMT = {
	__index = function(t, k)
		local c = rawget(t, "_children")[k]
		if c ~= nil then
			return c
		end
		return NodeMethods[k]
	end,
}
local function node(name: string, parent: any?, extra: any?)
	local n = { Name = name, Parent = parent, _children = {}, _class = "Folder" }
	if extra then
		for k, v in extra do
			n[k] = v
		end
	end
	setmetatable(n, NodeMT)
	if parent then
		rawget(parent, "_children")[name] = n
	end
	return n
end
function NodeMethods:FindFirstChild(name, recursive)
	local c = rawget(self, "_children")[name]
	if c or not recursive then
		return c
	end
	for _, child in rawget(self, "_children") do
		local found = child:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end
function NodeMethods:IsA(class)
	return rawget(self, "_class") == class
end
function NodeMethods:GetAttribute(name)
	local attrs = rawget(self, "_attrs")
	return if attrs then attrs[name] else nil
end

local warnings = {}
local function fakeWarn(...)
	table.insert(warnings, table.concat({ ... }, " "))
end

-- task : spawn lance la tâche jusqu'à son premier wait ; tick() la reprend une fois (un tour de pollLoop).
local spawned = {}
local fakeTask = {
	wait = function(_t)
		return coroutine.yield()
	end,
	spawn = function(f, ...)
		local co = coroutine.create(f)
		table.insert(spawned, co)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err)
		end
		return co
	end,
	defer = function(f, ...)
		f(...)
	end,
	delay = function() end,
}
local function tick()
	for _, co in spawned do
		if coroutine.status(co) == "suspended" then
			local ok, err = coroutine.resume(co)
			if not ok then
				error(err)
			end
		end
	end
end

-- Monde neuf : services faux, arbre, cache de require. features = surcharge de Config/Features (nil : le vrai).
local function world(features: any?)
	spawned = {}
	local W: any = {}
	W.analytics = {} -- { kind, player, funnel, session, step, name }
	W.events = {} -- LogEvent de TelemetryService
	local guid = 0
	local players = {}
	W.players = players
	local playerRemoving = signal()
	local productFinished = signal()
	local passFinished = signal()
	local services = {
		AnalyticsService = {
			LogFunnelStepEvent = function(_self, player, funnelName, sessionId, step, stepName)
				table.insert(W.analytics, { player = player, funnel = funnelName, session = sessionId, step = step, name = stepName })
			end,
			LogOnboardingFunnelStepEvent = function(_self, player, step, stepName)
				table.insert(W.analytics, { player = player, funnel = "ONBOARDING", step = step, name = stepName })
			end,
		},
		HttpService = {
			GenerateGUID = function(_self, _braces)
				guid += 1
				return "guid-" .. guid
			end,
		},
		MarketplaceService = { PromptProductPurchaseFinished = productFinished, PromptGamePassPurchaseFinished = passFinished },
		Players = {
			GetPlayers = function()
				return table.clone(players)
			end,
			GetPlayerByUserId = function(_self, id)
				for _, p in players do
					if p.UserId == id then
						return p
					end
				end
				return nil
			end,
			PlayerRemoving = playerRemoving,
		},
		RunService = { IsStudio = function() return false end },
	}
	W.productFinished = productFinished
	W.passFinished = passFinished
	local game = { GetService = function(_self, name) return services[name] end }
	services.ReplicatedStorage = node("ReplicatedStorage")
	local RS = services.ReplicatedStorage
	local Shared = node("Shared", RS)
	local Config = node("Config", Shared)
	local Contract = node("Contract", Shared)
	local Types = node("Types", Shared)
	local NetF = node("Net", Shared)
	local Services = node("Services", nil)
	local function src(parent, name, path)
		return node(name, parent, { _class = "ModuleScript", _source = SOURCES[path], _path = path })
	end
	local function stub(parent, name, value)
		return node(name, parent, { _class = "ModuleScript", _stub = value })
	end
	src(Config, "DeepFreeze", "shared/Config/DeepFreeze.luau")
	src(Config, "Funnels", "shared/Config/Funnels.luau")
	src(Config, "Telemetry", "shared/Config/Telemetry.luau")
	if features then
		stub(Config, "Features", features)
	else
		src(Config, "Features", "shared/Config/Features.luau")
	end
	src(Contract, "Find", "shared/Contract/Find.luau")
	stub(Types, "Carry", {})
	stub(Types, "Profile", {})
	-- Bouchons des services
	W.profiles = {}
	W.loaded = signal()
	W.funnelStep = signal()
	W.broken = signal()
	W.carry = signal()
	W.cashOut = signal()
	W.purchase = signal()
	W.theftStarted = signal()
	W.theftEnded = signal()
	W.intruders = {} -- [victime] = { voleurs }
	W.thefts = {} -- [voleur] = TheftInfo
	W.plots = {} -- [victime] = plot
	stub(NetF, "Net", { Server = { FunnelStep = W.funnelStep } })
	stub(Services, "DataService", {
		Get = function(p) return W.profiles[p] end,
		OnProfileLoaded = function(fn) W.loaded:Connect(fn) end,
	})
	stub(Services, "WindowService", { OnBroken = function(fn) W.broken:Connect(fn) end })
	stub(Services, "CarryService", { OnCarryStarted = function(fn) W.carry:Connect(fn) end })
	stub(Services, "DisplayService", { OnCashOut = function(fn) W.cashOut:Connect(fn) end })
	stub(Services, "ShopService", { OnPurchase = function(fn) W.purchase:Connect(fn) end })
	stub(Services, "PvPService", {
		OnTheftStarted = function(fn) W.theftStarted:Connect(fn) end,
		OnTheftEnded = function(fn) W.theftEnded:Connect(fn) end,
		GetIntruders = function(v) return table.clone(W.intruders[v] or {}) end,
		GetTheft = function(t) return W.thefts[t] end,
	})
	stub(Services, "PlotService", { GetPlot = function(v) return W.plots[v] end })
	stub(Services, "TelemetryService", {
		LogEvent = function(p, key, fields, value)
			table.insert(W.events, { player = p, key = key, fields = fields, value = value })
			return true
		end,
	})
	local fs = src(Services, "FunnelService", "server/Services/FunnelService.luau")
	local cache = {}
	local function req(m)
		if m == nil then
			error("require(nil)")
		end
		if cache[m] ~= nil then
			return cache[m]
		end
		local value
		if rawget(m, "_stub") ~= nil then
			value = rawget(m, "_stub")
		else
			local code = rawget(m, "_source")
			assert(code, "source absente : " .. tostring(rawget(m, "_path")))
			local fn, err = loadstring("local script, game, require, task, warn = ... " .. code, rawget(m, "_path"))
			assert(fn, err)
			value = fn(m, game, req, fakeTask, fakeWarn)
		end
		cache[m] = value
		return value
	end
	W.FunnelService = req(fs)
	W.Funnels = req(Config.Funnels)
	W.newPlayer = function(name, userId)
		local p = node(name, nil, { _class = "Player", UserId = userId, _attrs = {} })
		table.insert(players, p)
		return p
	end
	W.setRoot = function(p, x, y, z)
		local character = node("Character", nil, { _class = "Model" })
		node("HumanoidRootPart", character, { _class = "BasePart", Position = V3(x, y, z) })
		p.Character = character
	end
	W.newPlot = function(victim, x, y, z, sx, sy, sz)
		local plot = node("PLOT", nil, { _class = "Model" })
		local center = V3(x, y, z)
		node("Bounds", plot, {
			_class = "BasePart",
			Size = V3(sx, sy, sz),
			CFrame = { PointToObjectSpace = function(_self, point) return point - center end },
		})
		W.plots[victim] = plot
	end
	W.remove = function(p)
		local i = table.find(players, p)
		if i then
			table.remove(players, i)
		end
		playerRemoving:Fire(p)
	end
	return W
end

local function newProfile(played: number?)
	return {
		Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = played or 0 },
		Items = {},
		Display = {},
	}
end

local function sent(W, player, funnel)
	local list = {}
	for _, a in W.analytics do
		if a.player == player and (funnel == nil or a.funnel == funnel) then
			table.insert(list, a)
		end
	end
	return list
end

local function steps(list)
	local out = {}
	for _, a in list do
		table.insert(out, tostring(a.step))
	end
	return table.concat(out, ",")
end

------------------------------------------------------------------------------
-- A. Config/Funnels
------------------------------------------------------------------------------
print("== A. Config/Funnels")
do
	local W = world()
	local F = W.Funnels
	local count = 0
	local bad = {}
	for key, funnel in F.Funnels do
		count += 1
		check(funnel.Mode == "Once" or funnel.Mode == "Session", `A1 {key} : mode Once ou Session`)
		check(#funnel.Steps >= 2 and #funnel.Steps <= 100, `A2 {key} : 2 à 100 étapes`)
		local seen = {}
		for _, step in funnel.Steps do
			for _, token in { ",", '"', "'", "’" } do
				if string.find(step.Name, token, 1, true) or string.find(funnel.Name, token, 1, true) then
					table.insert(bad, `{key}/{step.Name}`)
				end
			end
			check(not seen[step.Key], `A3 {key} : clé {step.Key} unique`)
			seen[step.Key] = true
		end
	end
	check(count + 1 <= 10, `A4 {count} entonnoirs + onboarding du tuto ≤ 10 (limite de Roblox)`)
	check(#bad == 0, "A5 noms sans virgule, guillemet ni apostrophe " .. table.concat(bad, " "))
	for key, entry in F.ClientSteps do
		local funnel = F.Funnels[entry.Funnel]
		local found = false
		if funnel then
			for _, step in funnel.Steps do
				found = found or step.Key == entry.Step
			end
		end
		check(found, `A6 étape client {key} → {entry.Funnel}/{entry.Step} existe`)
		check(#key <= 24, `A7 clé client {key} tient dans le remote (24)`)
	end
	check(F.Funnels.FirstSteps.NewOnly == true and F.Funnels.Progression.NewOnly ~= true, "A8 FirstSteps NewOnly, Progression pour tous")
end

------------------------------------------------------------------------------
-- B. Premiers pas (nouveau profil)
------------------------------------------------------------------------------
print("== B. FirstSteps")
do
	local W = world()
	W.FunnelService.Init()
	check(W.FunnelService.IsEnabled(), "B0 entonnoirs allumés (Analytics et Telemetry.Enabled)")
	local alice = W.newPlayer("Alice", 1)
	W.funnelStep:Fire(alice, "Loaded", 12.34) -- avant le profil : gardé
	check(#sent(W, alice) == 0, "B1 Loaded avant le profil : rien encore")
	check(#W.events == 1 and W.events[1].key == "LoadingTime" and W.events[1].value == 12.3, "B2 LoadingTime envoyé, arrondi à 0,1 s")
	W.profiles[alice] = newProfile(0)
	W.loaded:Fire(alice)
	local list = sent(W, alice, "FirstSteps")
	check(steps(list) == "1,2", "B3 Arrive puis Loaded au chargement (" .. steps(list) .. ")")
	check(list[1].session == "FirstSteps" and list[1].name == "Arrivée en jeu", "B4 session fixe FirstSteps, nom de l'étape")
	check(W.profiles[alice].Funnels.New == true, "B5 profil nouveau marqué New")
	W.funnelStep:Fire(alice, "Loaded", 3)
	check(#W.events == 1 and #sent(W, alice) == 2, "B6 Loaded une 2e fois : ni étape ni LoadingTime")
	alice._attrs.TrainingMachine = "Treadmill"
	tick()
	check(steps(sent(W, alice, "FirstSteps")) == "1,2,3", "B7 tapis vu au relevé : étape 3")
	W.broken:Fire({ Kind = "Plot", Breaker = alice })
	check(#sent(W, alice, "FirstSteps") == 3, "B8 porte d'une boutique : pas l'étape vitrine")
	W.broken:Fire({ Kind = "NPC", Breaker = alice })
	W.carry:Fire(alice, { Kind = "PlayerItem" })
	check(steps(sent(W, alice, "FirstSteps")) == "1,2,3,4", "B9 vitrine PNJ : étape 4 ; objet de joueur porté : pas l'étape 5")
	W.carry:Fire(alice, { Kind = "NPCItem" })
	W.profiles[alice].Display["1"] = "uid1"
	tick()
	W.cashOut:Fire(alice, 50, "Leave")
	W.cashOut:Fire(alice, 50, "Offline")
	check(steps(sent(W, alice, "FirstSteps")) == "1,2,3,4,5,6", "B10 objet PNJ porté, présentoir occupé : 5 et 6 ; départ et hors ligne : pas d'encaissement")
	W.cashOut:Fire(alice, 50, "Pad")
	W.purchase:Fire(alice, "Tool", "Wrench", 100, nil)
	W.purchase:Fire(alice, "Upgrade", "Treadmill", 100, 1)
	W.purchase:Fire(alice, "Upgrade", "Treadmill", 200, 2)
	tick()
	check(steps(sent(W, alice, "FirstSteps")) == "1,2,3,4,5,6,7,8", "B11 encaissement puis amélioration : 7 et 8, une seule fois")
	check(W.profiles[alice].Funnels["FirstSteps/8"] == true, "B12 étapes notées dans le profil")
	-- Retour : profil avec Funnels déjà là, rien n'est renvoyé.
	W.loaded:Fire(alice)
	tick()
	check(#sent(W, alice, "FirstSteps") == 8, "B13 rechargement : rien de renvoyé")
	check(#sent(W, alice, "ONBOARDING") == 0, "B14 l'onboarding de Roblox n'est jamais utilisé ici (tuto)")
end

------------------------------------------------------------------------------
-- C. Ancien profil et progression
------------------------------------------------------------------------------
print("== C. Progression")
do
	local W = world()
	W.FunnelService.Init()
	local bob = W.newPlayer("Bob", 2)
	local data = newProfile(500)
	data.ZonesReached = { ["1"] = 10, ["2"] = 50 }
	W.profiles[bob] = data
	W.loaded:Fire(bob)
	check(#sent(W, bob, "FirstSteps") == 0 and data.Funnels.New == nil, "C1 ancien profil : jamais FirstSteps")
	W.funnelStep:Fire(bob, "Loaded", 4)
	check(#sent(W, bob, "FirstSteps") == 0, "C2 ancien profil : Loaded ne compte pas")
	tick()
	local list = sent(W, bob, "Progression")
	check(steps(list) == "1,2", "C3 zones 1 et 2 déjà atteintes : étapes 1 et 2 (" .. steps(list) .. ")")
	check(list[1].session == "Progression", "C4 session fixe Progression")
	data.ZonesReached["4"] = 80
	data.Rebirths = 1
	tick()
	tick()
	check(steps(sent(W, bob, "Progression")) == "1,2,4,7", "C5 zone 4 et 1re renaissance, une seule fois")
	local carl = W.newPlayer("Carl", 3)
	local fresh = newProfile(0)
	fresh.Items = { u = { Id = "X" } }
	W.profiles[carl] = fresh
	W.loaded:Fire(carl)
	check(#sent(W, carl, "FirstSteps") == 0, "C6 profil avec objets : pas nouveau")
end

------------------------------------------------------------------------------
-- D. Boutiques (sessions)
------------------------------------------------------------------------------
print("== D. Boutiques")
do
	local W = world()
	W.FunnelService.Init()
	local p = W.newPlayer("Dan", 4)
	W.profiles[p] = newProfile(10)
	W.loaded:Fire(p)
	W.funnelStep:Fire(p, "RobuxView")
	W.productFinished:Fire(4, 111, true)
	check(#sent(W, p, "RobuxShop") == 0, "D1 sans ouverture : ni View ni Bought")
	W.funnelStep:Fire(p, "RobuxOpen")
	W.funnelStep:Fire(p, "RobuxView")
	W.funnelStep:Fire(p, "RobuxView")
	W.funnelStep:Fire(p, "RobuxBuy")
	W.productFinished:Fire(4, 111, false)
	local list = sent(W, p, "RobuxShop")
	check(steps(list) == "1,2,3", "D2 Open, View une fois, Buy ; achat annulé : rien (" .. steps(list) .. ")")
	W.productFinished:Fire(4, 111, true)
	list = sent(W, p, "RobuxShop")
	check(steps(list) == "1,2,3,4" and list[4].session == list[1].session, "D3 achat fait : étape 4 dans la même session")
	W.funnelStep:Fire(p, "RobuxOpen")
	W.passFinished:Fire(p, 222, true)
	list = sent(W, p, "RobuxShop")
	check(#list == 6 and list[5].session ~= list[1].session and list[6].step == 4 and list[6].session == list[5].session, "D4 réouverture : nouvelle session ; gamepass acheté : étape 4")
	check(string.sub(list[1].session, 1, 5) == "guid-", "D5 session = GUID")
	W.purchase:Fire(p, "Tool", "Wrench", 10, nil)
	check(#sent(W, p, "WeaponShop") == 0, "D6 outil acheté sans boutique ouverte : rien")
	W.funnelStep:Fire(p, "WeaponOpen")
	W.funnelStep:Fire(p, "WeaponBuy")
	W.purchase:Fire(p, "Tool", "Wrench", 10, nil)
	W.funnelStep:Fire(p, "AuraOpen")
	W.purchase:Fire(p, "Trail", "Dust", 10, nil)
	check(steps(sent(W, p, "WeaponShop")) == "1,2,3", "D7 boutique d'armes : 1, 2, 3")
	check(steps(sent(W, p, "AuraShop")) == "1,3", "D8 trail acheté : étape 3 de la boutique d'auras")
	W.funnelStep:Fire(p, "Hack")
	check(#warnings >= 1, "D9 étape inconnue : ignorée, un avertissement")
end

------------------------------------------------------------------------------
-- E. Débit du client
------------------------------------------------------------------------------
print("== E. Débit")
do
	local W = world()
	W.FunnelService.Init()
	local p = W.newPlayer("Eve", 5)
	W.profiles[p] = newProfile(10)
	W.loaded:Fire(p)
	for _ = 1, 40 do
		W.funnelStep:Fire(p, "WeaponOpen")
	end
	check(#sent(W, p, "WeaponShop") == W.Funnels.ClientStepsPerMinute, `E1 au plus {W.Funnels.ClientStepsPerMinute} étapes du client par minute`)
end

------------------------------------------------------------------------------
-- F. Vol chez un joueur
------------------------------------------------------------------------------
print("== F. PlayerTheft")
do
	local W = world()
	W.FunnelService.Init()
	local thief = W.newPlayer("Thief", 6)
	local victim = W.newPlayer("Victim", 7)
	W.profiles[thief] = newProfile(10)
	W.profiles[victim] = newProfile(10)
	W.newPlot(victim, 0, 0, 0, 20, 10, 20)
	W.setRoot(thief, 0, 0, 0)
	W.intruders[victim] = { thief }
	tick()
	tick()
	local list = sent(W, thief, "PlayerTheft")
	check(steps(list) == "1", "F1 intrus : Enter une fois (" .. steps(list) .. ")")
	W.theftStarted:Fire(thief, victim, "Z1_X")
	W.intruders[victim] = {} -- un porteur n'est plus compté en intrus
	W.thefts[thief] = { Victim = victim }
	tick()
	list = sent(W, thief, "PlayerTheft")
	check(steps(list) == "1,2" and list[2].session == list[1].session, "F2 prise : Grab dans la même session, encore dedans : pas d'Exit")
	W.setRoot(thief, 30, 0, 0)
	tick()
	tick()
	check(steps(sent(W, thief, "PlayerTheft")) == "1,2,3", "F3 hors de Bounds avec l'objet : Exit une fois")
	W.thefts[thief] = nil
	W.theftEnded:Fire(thief, victim, "Z1_X", "Stolen", "Deposited")
	list = sent(W, thief, "PlayerTheft")
	check(steps(list) == "1,2,3,4" and list[4].session == list[1].session, "F4 dépôt : Deposit, même session")
	-- Nouvelle visite, repartie sans rien prendre, puis revenue : deux sessions.
	W.setRoot(thief, 0, 0, 0)
	W.intruders[victim] = { thief }
	tick()
	W.intruders[victim] = {}
	tick()
	W.intruders[victim] = { thief }
	tick()
	list = sent(W, thief, "PlayerTheft")
	check(#list == 6 and list[5].session ~= list[1].session and list[6].session ~= list[5].session, "F5 nouvelle visite, sortie sans objet puis retour : nouvelles sessions")
	-- Prise sans entrée vue, puis vol raté : Grab seul, pas de Deposit.
	W.intruders[victim] = {}
	tick()
	W.theftStarted:Fire(thief, victim, "Z1_X")
	W.theftEnded:Fire(thief, victim, "Z1_X", "Returned", "Bat")
	list = sent(W, thief, "PlayerTheft")
	check(#list == 7 and list[7].step == 2 and list[7].session ~= list[6].session, "F6 prise sans entrée vue : session neuve à l'étape 2 ; échec : pas de Deposit")
	W.remove(thief)
	tick()
	check(true, "F7 départ du voleur : pas d'erreur")
end

------------------------------------------------------------------------------
-- G. Interrupteur
------------------------------------------------------------------------------
print("== G. Features.Analytics = false")
do
	local W = world({ Analytics = false })
	W.FunnelService.Init()
	check(not W.FunnelService.IsEnabled(), "G1 coupé")
	check(#W.loaded.fns == 0 and #W.funnelStep.fns == 0 and #W.carry.fns == 0, "G2 rien n'est branché")
	local p = W.newPlayer("Gus", 8)
	W.profiles[p] = newProfile(0)
	W.loaded:Fire(p)
	tick()
	check(#W.analytics == 0 and W.profiles[p].Funnels == nil, "G3 aucun envoi, profil inchangé")
end

print(`scénario a414 : {checks} vérification(s), {fails} échec(s)`)
