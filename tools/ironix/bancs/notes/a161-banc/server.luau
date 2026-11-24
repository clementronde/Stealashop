-- Scénario server (a161) : vrai LeaderboardService (SOURCE), vraie Config/Leaderboard, vrai Format, sur un faux minimal.
local checks, fails = 0, 0
local function check(ok, label)
	checks += 1
	if not ok then
		fails += 1
		print("ÉCHEC " .. label)
	elseif os.getenv and false then
		print("ok " .. label)
	end
end
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in list do
				fn(...)
			end
		end,
	}
end

---------------------------------------------------------------- mini-instances
local GUI = { Frame = true, TextLabel = true, ImageLabel = true, TextButton = true, ImageButton = true, TextBox = true }
local Inst = {}
Inst.__index = function(self, key)
	local method = Inst[key]
	if method then
		return method
	end
	local child = rawget(self, "_props")[key]
	if child ~= nil then
		return child
	end
	for _, c in rawget(self, "_children") do
		if c.Name == key then
			return c
		end
	end
	return nil
end
Inst.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_props").Parent
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		rawget(self, "_props").Parent = value
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	rawget(self, "_props")[key] = value
end
local function new(class, props, parent)
	local self = setmetatable({ _props = { ClassName = class, Name = class }, _children = {}, _attrs = {} }, Inst)
	for k, v in props or {} do
		self[k] = v
	end
	if parent then
		self.Parent = parent
	end
	return self
end
function Inst.IsA(self, class)
	local c = self.ClassName
	return c == class or (class == "GuiObject" and GUI[c] == true) or (class == "LayerCollector" and c == "SurfaceGui")
end
function Inst.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function Inst.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local found = c:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Inst.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
end
function Inst.GetAttribute(self, k)
	return rawget(self, "_attrs")[k]
end
function Inst.Destroy(self)
	self.Parent = nil
end
function Inst.GetFullName(self)
	return self.Name
end
function Inst.Clone(self)
	local copy = new(self.ClassName)
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" then
			rawget(copy, "_props")[k] = v
		end
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, c in rawget(self, "_children") do
		c:Clone().Parent = copy
	end
	return copy
end

---------------------------------------------------------------- services
local tagged = {}
local CollectionService = {
	GetTagged = function(_, tag)
		return table.clone(tagged[tag] or {})
	end,
	GetInstanceAddedSignal = function()
		return signal()
	end,
}
local playerList = {}
local function newPlayer(name, userId)
	local attrs, changed = {}, {}
	local p = { Name = name, UserId = userId }
	function p.SetAttribute(_, k, v)
		attrs[k] = v
		if changed[k] then
			changed[k]:Fire()
		end
	end
	function p.GetAttribute(_, k)
		return attrs[k]
	end
	function p.GetAttributeChangedSignal(_, k)
		changed[k] = changed[k] or signal()
		return changed[k]
	end
	return p
end
local nameCalls, thumbCalls = 0, 0
local Players = {
	GetPlayers = function()
		return table.clone(playerList)
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in playerList do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(_, id)
		nameCalls += 1
		return "Offline" .. id
	end,
	GetUserThumbnailAsync = function(_, id)
		thumbCalls += 1
		return "thumb://" .. id, true
	end,
}
-- OrderedDataStore en mémoire.
local storesOpened, writes = {}, {}
local odsBroken = false
local orderedData = {}
local DataStoreService = {
	GetOrderedDataStore = function(_, name)
		if odsBroken then
			error("Studio access to API services is disabled")
		end
		table.insert(storesOpened, name)
		orderedData[name] = orderedData[name] or {}
		local data = orderedData[name]
		return {
			SetAsync = function(_, key, value)
				assert(type(value) == "number" and value == math.floor(value), "valeur entière")
				data[key] = value
				table.insert(writes, { store = name, key = key, value = value })
			end,
			GetSortedAsync = function(_, ascending, size)
				local list = {}
				for k, v in data do
					table.insert(list, { key = k, value = v })
				end
				table.sort(list, function(a, b)
					return if ascending then a.value < b.value else a.value > b.value
				end)
				while #list > size do
					table.remove(list)
				end
				return { GetCurrentPage = function()
					return list
				end }
			end,
		}
	end,
	GetRequestBudgetForRequestType = function()
		return 100
	end,
}

---------------------------------------------------------------- modules réels
local function load(source, name, env)
	local fn = assert(loadstring(source, name))
	setfenv(fn, setmetatable(env or {}, { __index = _G }))
	return fn()
end
local DeepFreeze = load(FREEZE_SOURCE, "DeepFreeze")
local LB = load(LB_SOURCE, "Leaderboard", { script = { Parent = { DeepFreeze = DeepFreeze } }, require = function(m)
	return m
end })
local Format = load(FORMAT_SOURCE, "Format")
local profiles = {}
local storeName = "PlayerData"
local DataService = {
	Get = function(_, p)
		return nil
	end,
}
DataService.Get = function(p)
	return profiles[p]
end
local loadedListeners, releasingListeners = {}, {}
DataService.OnProfileLoaded = function(fn)
	table.insert(loadedListeners, fn)
end
DataService.OnProfileReleasing = function(fn)
	table.insert(releasingListeners, fn)
end
DataService.GetStoreName = function()
	return storeName
end
local services = {
	CollectionService = CollectionService,
	DataStoreService = DataStoreService,
	Players = Players,
	RunService = { IsStudio = function()
		return true
	end },
	ReplicatedStorage = { Shared = { Config = { Leaderboard = LB, Balance = { Profiles = { StoreName = "PlayerData" } } }, Format = Format } },
}
local said = {}
local FakeEnum = {
	DataStoreRequestType = { SetIncrementSortedAsync = "SetIncrementSortedAsync", GetSortedAsync = "GetSortedAsync" },
	ThumbnailType = { HeadShot = "HeadShot" },
	ThumbnailSize = { Size150x150 = "Size150x150" },
}
local function freshService()
	return load(SOURCE, "LeaderboardService", {
		game = { GetService = function(_, n)
			return services[n]
		end },
		script = { Parent = { DataService = DataService } },
		require = function(m)
			return m
		end,
		Enum = FakeEnum,
		print = function(msg)
			table.insert(said, msg)
		end,
		warn = function(msg)
			table.insert(said, msg)
		end,
		task = { spawn = function(fn, ...)
			fn(...)
		end, wait = function() end },
	})
end
local function loadProfile(p, data)
	profiles[p] = data
	table.insert(playerList, p)
	for _, fn in loadedListeners do
		fn(p)
	end
end

---------------------------------------------------------------- panneaux
local function board(stat)
	local model = new("Model", { Name = "ENV_Hub_Leaderboard_" .. tostring(stat) })
	if stat then
		model:SetAttribute("Stat", stat)
	end
	local part = new("Part", { Name = "Screen" }, model)
	local gui = new("SurfaceGui", { Name = "Board" }, part)
	new("TextLabel", { Name = "Title", Text = "" }, gui)
	local list = new("Frame", { Name = "List" }, gui)
	local tpl = new("Frame", { Name = "Template", Visible = false }, list)
	new("TextLabel", { Name = "Rank" }, tpl)
	new("ImageLabel", { Name = "Avatar" }, tpl)
	new("TextLabel", { Name = "PlayerName" }, tpl)
	new("TextLabel", { Name = "Value" }, tpl)
	tagged.Leaderboard = tagged.Leaderboard or {}
	table.insert(tagged.Leaderboard, model)
	return model, gui, list, tpl
end
local function rowsOf(list)
	local out = {}
	for _, c in list:GetChildren() do
		if c.Name ~= "Template" then
			table.insert(out, c)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end

---------------------------------------------------------------- L1 meilleur revenu, profil sans le champ
local S = freshService()
S.Init()
local alice = newPlayer("Alice", 101)
local bob = newPlayer("Bob", 102)
loadProfile(alice, { Lifetime = { Heists = 0 }, Stats = { Speed = 40.7 } }) -- profil sans BestIncome
check(alice and profiles[alice].Lifetime.BestIncome == nil, "L1a profil sans BestIncome : rien d'écrit sans revenu")
check(S.ValueOf(alice, "Income") == 0, "L1b sans revenu : 0")
alice:SetAttribute("Income", 1500)
check(profiles[alice].Lifetime.BestIncome == 1500, `L1c revenu 1500 : BestIncome monte ({profiles[alice].Lifetime.BestIncome})`)
alice:SetAttribute("Income", 200)
check(profiles[alice].Lifetime.BestIncome == 1500 and S.ValueOf(alice, "Income") == 1500, "L1d revenu qui baisse : record gardé")
alice:SetAttribute("Income", 0 / 0)
check(profiles[alice].Lifetime.BestIncome == 1500, "L1e revenu NaN ignoré")
check(S.ValueOf(alice, "Speed") == 40.7, "L1f Fastest = Stats.Speed")
loadProfile(bob, { Lifetime = { BestIncome = "x" }, Stats = { Speed = 90 } })
check(profiles[bob].Lifetime.BestIncome == 0, "L1g BestIncome illisible : repart de 0")
bob:SetAttribute("Income", 50)

---------------------------------------------------------------- L2 écritures
S.Step(0)
check(#storesOpened == 2 and table.find(storesOpened, "Leaderboard_Income") and table.find(storesOpened, "Leaderboard_Speed"), `L2a deux OrderedDataStore, sans suffixe hors DEV ({table.concat(storesOpened, ", ")})`)
check(#writes == 4, `L2b 2 joueurs × 2 stats écrits ({#writes})`)
local incomeA = orderedData.Leaderboard_Income["101"]
check(incomeA == LB.Encode("Income", 1500) and orderedData.Leaderboard_Speed["101"] == 40, "L2c valeurs codées (revenu en log, vitesse entière)")
S.Step(LB.WriteInterval + 1)
check(#writes == 4, `L2d rien de changé : aucune nouvelle écriture ({#writes})`)
profiles[bob].Stats.Speed = 95
S.Step(2 * LB.WriteInterval + 2)
check(#writes == 5 and orderedData.Leaderboard_Speed["102"] == 95, "L2e vitesse changée : une écriture")

---------------------------------------------------------------- L3 classement et panneaux
orderedData.Leaderboard_Income["900"] = LB.Encode("Income", 1e9) -- joueur absent, meilleur
local incomeBoard, incomeGui, incomeList, incomeTpl = board("Income")
local speedBoard, _, speedList = board("Speed")
S.Step(10 * LB.ReadInterval)
local rows = S.Rows("Income")
check(#rows == 3 and rows[1].UserId == 900 and rows[2].UserId == 101 and rows[3].UserId == 102, "L3a classement trié, absent compris")
check(math.abs(rows[1].Value / 1e9 - 1) < 1e-9 and rows[1].Rank == 1, "L3b valeur relue de l'OrderedDataStore")
check(incomeGui.Title.Text == "Most money/s", `L3c Title « Most money/s » ({incomeGui.Title.Text})`)
local shown = rowsOf(incomeList)
check(#shown == 3 and shown[1].Name == "Row_01" and shown[1].Visible == true and incomeTpl.Visible == false, "L3d une copie visible de Template par ligne, Template invisible")
check(shown[1].Rank.Text == "#1" and shown[1].PlayerName.Text == "Offline900" and shown[1].Value.Text == Format.money(1e9) .. "/s", `L3e ligne 1 : #1, nom de l'absent, $/s ({shown[1].Value.Text})`)
check(shown[2].PlayerName.Text == "Alice" and shown[2].Avatar.Image == "thumb://101", "L3f joueur présent : son nom, avatar GetUserThumbnailAsync")
local speedRows = rowsOf(speedList)
check(speedBoard:GetAttribute("Stat") == "Speed" and #speedRows == 2 and speedRows[1].PlayerName.Text == "Bob" and speedRows[1].Value.Text == "95", "L3g panneau Fastest : Bob 95 en tête")
S.Step(20 * LB.ReadInterval)
check(#rowsOf(incomeList) == 3, "L3h nouvel affichage : pas de lignes en double")
check(nameCalls == 1 and thumbCalls == 3, `L3i noms et avatars en cache ({nameCalls}, {thumbCalls})`)
-- Record en direct, avant la prochaine lecture.
alice:SetAttribute("Income", 5e9)
check(S.Rows("Income")[1].UserId == 101, "L3j joueur présent : sa valeur du moment compte avant la lecture")

---------------------------------------------------------------- L4 nombre de lignes
for i = 1, 12 do
	orderedData.Leaderboard_Speed[tostring(2000 + i)] = i
end
S.Step(30 * LB.ReadInterval)
check(#rowsOf(speedList) == LB.Rows, `L4 {LB.Rows} lignes au plus ({#rowsOf(speedList)})`)

---------------------------------------------------------------- L5 panneau incomplet ou sans Stat
board(nil)
local broken = new("Model", { Name = "Broken" })
broken:SetAttribute("Stat", "Income")
table.insert(tagged.Leaderboard, broken)
local ok = pcall(S.Step, 40 * LB.ReadInterval)
check(ok and #rowsOf(incomeList) == 3, "L5 panneau sans Stat ou sans Board : ignoré, les autres remplis")

---------------------------------------------------------------- L6 départ
local before = #writes
alice:SetAttribute("Income", 6e9)
for _, fn in releasingListeners do
	fn(alice)
end
check(#writes == before + 1 and orderedData.Leaderboard_Income["101"] == LB.Encode("Income", 6e9), "L6 départ : record écrit")

---------------------------------------------------------------- L7 Studio sans API, jeu DEV
table.clear(storesOpened)
table.clear(writes)
odsBroken = true
table.clear(playerList)
table.clear(tagged)
local S2 = freshService()
S2.Init()
local cy = newPlayer("Cy", 301)
loadProfile(cy, { Lifetime = {}, Stats = { Speed = 12 } })
cy:SetAttribute("Income", 77)
local _, g2, l2 = board("Income")
ok = pcall(S2.Step, 0)
local r2 = rowsOf(l2)
check(ok and #writes == 0 and #r2 == 1 and r2[1].PlayerName.Text == "Cy" and g2.Title.Text == "Most money/s", "L7a sans accès aux API : pas d'erreur, joueurs présents affichés")
local warned = false
for _, msg in said do
	if string.find(msg, "indisponible", 1, true) then
		warned = true
	end
end
check(warned, "L7b une ligne dans la sortie")
odsBroken = false
storeName = "PlayerData_DEV_20261114"
local S3 = freshService()
S3.Step(0)
check(table.find(storesOpened, "Leaderboard_Income_DEV") ~= nil and table.find(storesOpened, "Leaderboard_Speed_DEV") ~= nil, `L7c jeu DEV : stores suffixés _DEV ({table.concat(storesOpened, ", ")})`)

print(`{checks} vérification(s), {fails} échec(s)`)
