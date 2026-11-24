-- Banc a410 (vague GC6, MAJ 7) : colonnes de mutations de l'index (Shared/IndexMutations, IndexService) et
-- notifications Roblox (NotificationService). Faux Roblox minimal : arbre de modules d'après SOURCES (chemins
-- « shared/Config/Items »…), bouchons STUBS pour les services serveur.
--   M1 IndexMutations : Note, Encode, Decode, CountItem, Total, effets inconnus et objet du tuto ignorés
--   I1 IndexService : un objet muté possédé au chargement, puis un 2e exemplaire d'un autre effet découvert → attribut
--   N1 NotificationService : départ → OfflineFull (plafond) et SaturdayEvent planifiés ; retour → retirés
--   N2 file : une ligne due est prise une fois (deux relectures) et envoyée en Studio (sortie), joueur en jeu : rien
--   N3 vol : victime au premier plan → rien ; hors premier plan → ShopStolen, puis délai entre deux
--   N4 Features.ExperienceNotifications = false → rien de planifié
local passed, failed = 0, 0
local function check(cond, label)
	if cond then
		passed += 1
		if VERBOSE then
			print("ok " .. label)
		end
	else
		failed += 1
		print("ÉCHEC " .. label)
	end
end

NOW = 1_800_000_000
CLOCK = 1000
PRINTS = {}
local realPrint = print
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	table.insert(PRINTS, table.concat(parts, " "))
	if VERBOSE then
		realPrint(...)
	end
end
warn = function(...)
	print("WARN", ...)
end

-- Globales Roblox --------------------------------------------------------------------------------------
Color3 = {
	fromHex = function(h)
		return { hex = h }
	end,
	fromRGB = function(r, g, b)
		return { r = r, g = g, b = b }
	end,
	new = function(r, g, b)
		return { r = r, g = g, b = b }
	end,
}
Enum = setmetatable({}, {
	__index = function(_, k)
		return setmetatable({}, {
			__index = function(_, j)
				return k .. "." .. j
			end,
		})
	end,
})
local realOs = os
os = setmetatable({
	time = function()
		return NOW
	end,
	clock = function()
		return CLOCK
	end,
}, { __index = realOs })
local TASKS = {}
task = {
	spawn = function(f, ...)
		f(...)
	end,
	defer = function(f, ...)
		f(...)
	end,
	delay = function(t, f, ...)
		table.insert(TASKS, { t = t, f = f, args = { ... } })
	end,
	wait = function()
		error("task.wait dans le banc")
	end,
}
typeof = function(v)
	return type(v)
end

local function signal()
	local s = { list = {} }
	function s:Connect(f)
		table.insert(self.list, f)
		return {
			Disconnect = function() end,
		}
	end
	function s:Fire(...)
		for _, f in self.list do
			f(...)
		end
	end
	return s
end

-- Joueurs ----------------------------------------------------------------------------------------------
local Players = { list = {}, PlayerAdded = signal(), PlayerRemoving = signal() }
function Players:GetPlayers()
	return table.clone(self.list)
end
function Players:GetPlayerByUserId(id)
	for _, p in self.list do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
local function newPlayer(name, id)
	local p = { Name = name, UserId = id, attrs = {}, Parent = Players }
	function p:SetAttribute(k, v)
		self.attrs[k] = v
	end
	function p:GetAttribute(k)
		return self.attrs[k]
	end
	return p
end

-- MemoryStore ------------------------------------------------------------------------------------------
local Map = { rows = {} }
function Map:SetAsync(key, value, expiration, sortKey)
	self.rows[key] = { value = value, sortKey = sortKey, expires = NOW + expiration }
	return true
end
function Map:RemoveAsync(key)
	self.rows[key] = nil
end
function Map:GetRangeAsync(direction, count, lower, upper)
	local out = {}
	for key, row in self.rows do
		if row.expires > NOW and (upper == nil or row.sortKey < upper.sortKey) then
			table.insert(out, { key = key, value = row.value, sortKey = row.sortKey })
		end
	end
	table.sort(out, function(a, b)
		return a.sortKey < b.sortKey
	end)
	while #out > count do
		table.remove(out)
	end
	return out
end
function Map:UpdateAsync(key, transform, expiration)
	local row = self.rows[key]
	local old = if row and row.expires > NOW then row.value else nil
	local value, sortKey = transform(old, row and row.sortKey)
	if value == nil then
		return nil
	end
	self.rows[key] = { value = value, sortKey = sortKey, expires = NOW + expiration }
	return value
end
local MemoryStoreService = {
	GetSortedMap = function(_, name)
		Map.name = name
		return Map
	end,
}

local HTTP = {}
local HttpService = {
	GetSecret = function()
		return "SECRET"
	end,
	JSONEncode = function(_, v)
		return v
	end,
	RequestAsync = function(_, req)
		table.insert(HTTP, req)
		return { Success = true, StatusCode = 200, Body = "{}" }
	end,
}
local Workspace = { attrs = {}, sigs = {} }
function Workspace:GetAttribute(k)
	return self.attrs[k]
end
function Workspace:GetAttributeChangedSignal(k)
	self.sigs[k] = self.sigs[k] or signal()
	return self.sigs[k]
end
local RunService = {
	IsStudio = function()
		return true
	end,
}

-- Arbre de modules -------------------------------------------------------------------------------------
STUBS = {}
local cache = {}
local proxies = {}
local function proxy(path)
	if proxies[path] then
		return proxies[path]
	end
	local p = setmetatable({ _key = path }, {
		__index = function(self, k)
			if k == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$")
				return if parent then proxy(parent) else nil
			elseif k == "Name" then
				return string.match(path, "([^/]+)$")
			elseif k == "WaitForChild" or k == "FindFirstChild" then
				return function(s, n)
					return proxy(path .. "/" .. n)
				end
			end
			return proxy(path .. "/" .. k)
		end,
	})
	proxies[path] = p
	return p
end
local Shared = proxy("shared")
local ReplicatedStorage = { Shared = Shared }
local services = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	Workspace = Workspace,
	HttpService = HttpService,
	MemoryStoreService = MemoryStoreService,
}
game = {
	GameId = 4242,
	JobId = "job-A",
	GetService = function(_, name)
		return assert(services[name], "service " .. name)
	end,
}
function requireModule(m)
	local key = m._key
	if STUBS[key] ~= nil then
		return STUBS[key]
	end
	if cache[key] ~= nil then
		return cache[key]
	end
	local fn = assert(loadstring(assert(SOURCES[key], "source absente : " .. key), key))
	local env = setmetatable({ script = proxy(key), require = requireModule }, { __index = getfenv(1) })
	setfenv(fn, env)
	local result = fn()
	cache[key] = result
	return result
end
local function fresh()
	cache = {}
end

-- M1 IndexMutations --------------------------------------------------------------------------------------
local IM = requireModule(proxy("shared/IndexMutations"))
local Items = requireModule(proxy("shared/Config/Items"))
local Mutations = requireModule(proxy("shared/Config/Mutations"))
local normal, tutorial = nil, nil
for _, item in Items.List do
	if item.TutorialOnly then
		tutorial = tutorial or item
	elseif normal == nil then
		normal = item
	end
end
local other = Items.List[#Items.List]
check(normal ~= nil and other ~= nil and other.Id ~= normal.Id, "M1 catalogue lu")
check(IM.PerItem == #Mutations.Effects and IM.PerItem == 7, "M1 sept colonnes (effets)")
local book = {}
check(IM.Note(book, normal.Id, { Effect = "Gold" }, 5) == true, "M1 effet noté")
check(IM.Note(book, normal.Id, { Effect = "Gold", Size = "Huge" }, 6) == false, "M1 même effet : pas deux fois")
check(book[normal.Id].Gold == 5, "M1 date de la 1re obtention gardée")
check(IM.Note(book, normal.Id, { Size = "Huge" }, 7) == false, "M1 taille seule : pas une colonne")
check(IM.Note(book, normal.Id, { Effect = "Plaid" }, 7) == false, "M1 effet inconnu ignoré")
check(IM.Note(book, "NoSuchItem", { Effect = "Gold" }, 7) == false, "M1 objet inconnu ignoré")
if tutorial then
	check(IM.Note(book, tutorial.Id, { Effect = "Gold" }, 7) == false, "M1 objet du tuto : pas de colonnes")
end
IM.Note(book, normal.Id, { Effect = "Rainbow" }, 8)
IM.Note(book, other.Id, { Effect = "Shiny" }, 9)
local text = IM.Encode(book)
check(text == `{normal.Id}:Gold|Rainbow,{other.Id}:Shiny` or text == `{other.Id}:Shiny,{normal.Id}:Gold|Rainbow`, "M1 Encode : " .. text)
local decoded = IM.Decode(text .. ",Bogus:Gold," .. normal.Id .. "x:Neon")
check(decoded[normal.Id].Gold and decoded[normal.Id].Rainbow and not decoded[normal.Id].Shiny, "M1 Decode")
check(decoded.Bogus == nil, "M1 Decode : objet inconnu ignoré")
check(IM.CountItem(decoded, normal.Id) == 2 and IM.CountItem(decoded, "Nope") == 0, "M1 CountItem")
local countable = 0
for _, item in Items.List do
	if not item.TutorialOnly then
		countable += 1
	end
end
check(IM.Total() == countable * 7, "M1 Total")
check(next(IM.Decode(nil)) == nil and next(IM.Decode("")) == nil, "M1 Decode vide")

-- I1 IndexService ------------------------------------------------------------------------------------------
local PROFILES = {}
local loadedListeners, releasingListeners, theftListeners = {}, {}, {}
STUBS["server/Services/DataService"] = {
	Get = function(p)
		return PROFILES[p]
	end,
	OnProfileLoaded = function(f)
		table.insert(loadedListeners, f)
	end,
	OnProfileReleasing = function(f)
		table.insert(releasingListeners, f)
	end,
}
STUBS["server/Services/PvPService"] = {
	OnTheftEnded = function(f)
		table.insert(theftListeners, f)
	end,
}
local netServer = setmetatable({}, {
	__index = function(t, k)
		local r = { handlers = {}, fired = {} }
		function r:Connect(f)
			table.insert(self.handlers, f)
		end
		function r:Fire(...)
			table.insert(self.fired, { ... })
		end
		rawset(t, k, r)
		return r
	end,
})
STUBS["shared/Net/Net"] = { Server = netServer }
local IndexService = requireModule(proxy("server/Services/IndexService"))
IndexService.Init()
local alice = newPlayer("Alice", 11)
table.insert(Players.list, alice)
PROFILES[alice] = {
	Items = {
		u1 = { Id = normal.Id, At = 100, Mutation = { Effect = "Neon" } },
		u2 = { Id = other.Id, At = 101 },
	},
	Index = {},
}
for _, f in loadedListeners do
	f(alice)
end
local attr = alice:GetAttribute(IM.Attribute)
check(attr == `{normal.Id}:Neon`, "I1 attribut au chargement : " .. tostring(attr))
check(PROFILES[alice].IndexMutations[normal.Id].Neon == 100, "I1 date = obtention de l'objet")
PROFILES[alice].Items.u3 = { Id = normal.Id, At = 200, Mutation = { Effect = "Glitch" } }
check(IndexService.Discover(alice, normal.Id) == false, "I1 objet déjà découvert : Discover = false")
check(alice:GetAttribute(IM.Attribute) == `{normal.Id}:Neon|Glitch`, "I1 2e exemplaire, autre effet : colonne ajoutée")
PROFILES[alice].Items.u3 = nil
IndexService.Discover(alice, other.Id)
check(PROFILES[alice].IndexMutations[normal.Id].Glitch == 200, "I1 effet gardé après la vente de l'objet")
local bob = newPlayer("Bob", 12)
PROFILES[bob] = { Items = {}, Index = {}, IndexMutations = "abîmé" }
for _, f in loadedListeners do
	f(bob)
end
check(type(PROFILES[bob].IndexMutations) == "table" and bob:GetAttribute(IM.Attribute) == "", "I1 champ illisible : repart vide")

-- N NotificationService ------------------------------------------------------------------------------------
local Features = requireModule(proxy("shared/Config/Features"))
local function loadNotifications(on)
	fresh()
	loadedListeners, releasingListeners, theftListeners = {}, {}, {}
	Players.PlayerAdded = signal()
	Players.PlayerRemoving = signal()
	Map.rows = {}
	local f = table.clone(Features)
	f.ExperienceNotifications = on
	STUBS["shared/Config/Features"] = f
	local service = requireModule(proxy("server/Services/NotificationService"))
	service.Init()
	return service
end
local Notifications = requireModule(proxy("shared/Config/Notifications"))
local Offline = requireModule(proxy("shared/Config/Offline"))
local LiveEvents = requireModule(proxy("shared/Config/LiveEvents"))
local NS = loadNotifications(true)
check(Map.name == Notifications.MapName, "N1 carte MemoryStore ouverte")
local carl = newPlayer("Carl", 33)
PROFILES[carl] = { Offline = { Income = 10, LastSeenAt = NOW } }
for _, f in releasingListeners do
	f(carl)
end
local full = Map.rows["OfflineFull:33"]
check(full ~= nil and full.sortKey == NOW + Offline.MaxHours * 3600, "N1 OfflineFull au plafond")
check(full ~= nil and full.value.p.amount ~= nil and full.value.u == 33, "N1 OfflineFull : montant et joueur")
local nextEvent = LiveEvents.NextWeeklyStart(NOW)
local event = Map.rows["SaturdayEvent:33"]
if nextEvent and nextEvent - Notifications.LeadSeconds > NOW then
	check(event ~= nil and event.sortKey == nextEvent - Notifications.LeadSeconds, "N1 SaturdayEvent avant le rendez-vous")
	check(event ~= nil and type(event.value.p.event) == "string" and #event.value.p.event > 0, "N1 SaturdayEvent : nom de l'événement")
else
	check(event == nil, "N1 rendez-vous trop proche : rien")
end
local dave = newPlayer("Dave", 44)
PROFILES[dave] = { Offline = { Income = 0 } }
for _, f in releasingListeners do
	f(dave)
end
check(Map.rows["OfflineFull:44"] == nil, "N1 boutique sans revenu : pas d'OfflineFull")
Players.PlayerAdded:Fire(carl)
check(Map.rows["OfflineFull:33"] == nil and Map.rows["SaturdayEvent:33"] == nil, "N1 retour du joueur : notifications retirées")

-- N2 file
for _, f in releasingListeners do
	f(carl)
end
PRINTS = {}
NOW += Offline.MaxHours * 3600 + 1
local polled = false
-- poll est local : on le rejoue par le Start bouché (task.wait) ; à défaut, Send direct. On passe par la boucle :
task.wait = function()
	if polled then
		error("fin")
	end
	polled = true
end
pcall(NS.Start)
local sent = 0
for _, line in PRINTS do
	if string.find(line, "OfflineFull → 33", 1, true) then
		sent += 1
	end
end
check(sent == 1, "N2 ligne due envoyée une fois (sortie Studio)")
check(Map.rows["OfflineFull:33"] ~= nil and Map.rows["OfflineFull:33"].value.c == "job-A", "N2 ligne prise par ce serveur")
PRINTS = {}
polled = false
pcall(NS.Start)
sent = 0
for _, line in PRINTS do
	if string.find(line, "OfflineFull → 33", 1, true) then
		sent += 1
	end
end
check(sent == 0, "N2 relecture : jamais deux fois")
-- joueur revenu sur ce serveur : pas d'envoi
Map.rows = {}
-- clé hors des moments retirés au retour (Start les retire pour les joueurs présents) : seul le contrôle « en jeu » joue
Map:SetAsync("Other:55", { u = 55, m = "OfflineFull", p = { amount = "$1" } }, 100, NOW - 1)
local eve = newPlayer("Eve", 55)
table.insert(Players.list, eve)
PRINTS = {}
polled = false
pcall(NS.Start)
local any = false
for _, line in PRINTS do
	if string.find(line, "→ 55", 1, true) then
		any = true
	end
end
check(not any, "N2 joueur en jeu : rien envoyé")

-- N3 vol
local reportFocus = netServer.ReportFocus.handlers[#netServer.ReportFocus.handlers]
PRINTS = {}
for _, f in theftListeners do
	f(carl, eve, normal.Id, "Stolen", "")
end
check(#PRINTS == 0, "N3 victime au premier plan : rien")
reportFocus(eve, false)
for _, f in theftListeners do
	f(carl, eve, normal.Id, "Returned", "")
end
check(#PRINTS == 0, "N3 objet rendu : rien")
for _, f in theftListeners do
	f(carl, eve, normal.Id, "Stolen", "")
end
check(#PRINTS == 1 and string.find(PRINTS[1], "ShopStolen → 55", 1, true) ~= nil and string.find(PRINTS[1], normal.DisplayName, 1, true) ~= nil, "N3 hors premier plan : ShopStolen avec le nom de l'objet")
for _, f in theftListeners do
	f(carl, eve, normal.Id, "Stolen", "")
end
check(#PRINTS == 1, "N3 délai entre deux")
CLOCK += Notifications.StolenCooldown + 1
for _, f in theftListeners do
	f(carl, eve, normal.Id, "Stolen", "")
end
check(#PRINTS == 2, "N3 après le délai : de nouveau")
reportFocus(eve, true)
CLOCK += Notifications.StolenCooldown + 1
for _, f in theftListeners do
	f(carl, eve, normal.Id, "Stolen", "")
end
check(#PRINTS == 2, "N3 revenu au premier plan : rien")

-- N4 coupé
loadNotifications(false)
check(#releasingListeners == 0 and #theftListeners == 0, "N4 coupé : aucun crochet")

print = realPrint
print(`banc a410 : {passed} vérification(s), {failed} échec(s)`)
