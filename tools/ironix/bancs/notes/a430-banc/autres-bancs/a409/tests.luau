-- Banc a409 (GC6, MAJ 6) : classements hebdomadaires (Config/WeeklyLeaderboard, vrai WeeklyLeaderboardService sur un faux
-- minimal) et casse du siècle (Config/ArmoredVan, calculs purs du vrai ArmoredVanService).
local checks, fails = 0, 0
local function check(ok, label)
	checks += 1
	if not ok then
		fails += 1
		print("ÉCHEC " .. label)
	end
end
local function load(source, name, env)
	local fn = assert(loadstring(source, name))
	setfenv(fn, setmetatable(env or {}, { __index = _G }))
	return fn()
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
local identity = function(m)
	return m
end
local DeepFreeze = load(FREEZE_SOURCE, "DeepFreeze")
local cfgEnv = { script = { Parent = { DeepFreeze = DeepFreeze } }, require = identity }
local W = load(WCFG_SOURCE, "WeeklyLeaderboard", table.clone(cfgEnv))
local AVenv = table.clone(cfgEnv)
AVenv.Vector3 = { new = function(x, y, z)
	return { X = x, Y = y, Z = z }
end }
AVenv.Vector2 = { new = function(x, y)
	return { X = x, Y = y }
end }
local AV = load(AVCFG_SOURCE, "ArmoredVan", AVenv)

---------------------------------------------------------------- W1 semaines
local week = W.WeekOf(os.time())
local start = W.WeekStart(week)
check(os.date("!*t", start).wday == 2 and os.date("!*t", start).hour == 0, `W1a la semaine commence un lundi à 00:00 UTC ({os.date("!%c", start)})`)
check(W.WeekOf(start) == week and W.WeekOf(start - 1) == week - 1 and W.WeekOf(start + 7 * 86400 - 1) == week, "W1b bornes de la semaine")
check(W.WeekOf(W.WeekStart(week + 1)) == week + 1, "W1c semaine suivante")
check(W.StoreName("WeeklyIncome", false, 12) == "LeaderboardWeek_Income_W12" and W.StoreName("WeeklySteals", true, 12) == "LeaderboardWeek_Steals_DEV_W12" and W.StoreName("X", false, 1) == nil, "W1d noms des stores par semaine, suffixe DEV")
check(W.Encode("WeeklySteals", 7.9) == 7 and W.Decode("WeeklySteals", 7) == 7 and W.Encode("WeeklySteals", -1) == 0 and W.Encode("WeeklySteals", 0 / 0) == 0, "W1e vols : entiers")
check(math.abs(W.Decode("WeeklyIncome", W.Encode("WeeklyIncome", 3.2e20)) / 3.2e20 - 1) < 1e-9 and W.Encode("WeeklyIncome", 1e40) < 2 ^ 53, "W1f revenu en log, relu à 1e-9 près")
check(W.RewardFor(1).MaxRank == 3 and W.RewardFor(3).MaxRank == 3 and W.RewardFor(4).MaxRank == 10 and W.RewardFor(100).MaxRank == 100 and W.RewardFor(101) == nil and W.RewardFor(0) == nil, "W1g récompense par rang")
check(W.Top == 100, "W1h top 100")

---------------------------------------------------------------- faux monde du service
local playerList = {}
local function newPlayer(name, userId)
	local attrs, changed = {}, {}
	local p = { Name = name, UserId = userId, _income = 0 }
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
local orderedData, opened, writes = {}, {}, {}
local odsBroken = false
local DataStoreService = {
	GetOrderedDataStore = function(_, name)
		if odsBroken then
			error("Studio access to API services is disabled")
		end
		table.insert(opened, name)
		orderedData[name] = orderedData[name] or {}
		local data = orderedData[name]
		return {
			SetAsync = function(_, key, value)
				assert(type(value) == "number" and value == math.floor(value), "valeur entière")
				data[key] = value
				table.insert(writes, { store = name, key = key, value = value })
			end,
			GetSortedAsync = function(_, ascending, size)
				assert(size <= 100, "page de 100 au plus")
				local list = {}
				for k, v in data do
					table.insert(list, { key = k, value = v })
				end
				table.sort(list, function(a, b)
					return a.value > b.value
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
local profiles = {}
local loaded, releasing = {}, {}
local DataService = {
	Get = function(p)
		return profiles[p]
	end,
	OnProfileLoaded = function(fn)
		table.insert(loaded, fn)
	end,
	OnProfileReleasing = function(fn)
		table.insert(releasing, fn)
	end,
	GetStoreName = function()
		return "PlayerData"
	end,
}
local boards = {}
local LeaderboardService = {
	RecordIncome = function(p)
		return p._income
	end,
	AddBoard = function(stat, b)
		boards[stat] = b
	end,
}
local gifts = {}
local full = {}
local UnboxService = {
	GiveZoneBoxItem = function(p, rule, zone)
		if full[p] then
			return nil, "InventoryFull", nil, nil
		end
		table.insert(gifts, { player = p, rule = rule, zone = zone })
		local uid = "u" .. #gifts
		profiles[p].Items[uid] = { Id = "ITM_Test" }
		return uid, nil, "ITM_Test", {}
	end,
}
local shows = {} -- a430 : [classement] = UserId donné à LeaderboardStatueService.Show
local LeaderboardStatueService = { Show = function(stat, userId)
	shows[stat] = userId
end }
local notes = {}
local now = os.time()
local function freshWeekly(enabled)
	table.clear(loaded)
	table.clear(releasing)
	local services = {
		DataStoreService = DataStoreService,
		Players = { GetPlayers = function()
			return table.clone(playerList)
		end },
		ReplicatedStorage = { Shared = {
			Config = {
				Balance = { Profiles = { StoreName = "PlayerData" } },
				Features = { WeeklyLeaderboards = enabled },
				Items = { ById = { ITM_Test = { Id = "ITM_Test", DisplayName = "Test", Rarity = "Rare", Zone = 3 } } },
				Mutations = { ItemName = function(n)
					return n
				end },
				Rarities = { ById = { Rare = { DisplayName = "Rare" } } },
				WeeklyLeaderboard = W,
				Zones = { {}, {}, {}, {}, {}, {} },
			},
			Format = { money = function(v)
				return "$" .. v
			end, short = function(v)
				return tostring(v)
			end },
			Net = { Net = { Server = { Notify = { Fire = function(_, p, msg, kind)
				table.insert(notes, { player = p, msg = msg, kind = kind })
			end } } } },
		} },
		RunService = { IsStudio = function()
			return true
		end },
		Workspace = {},
	}
	return load(WL_SOURCE, "WeeklyLeaderboardService", {
		game = { GetService = function(_, n)
			return services[n]
		end },
		script = { Parent = { DataService = DataService, LeaderboardService = LeaderboardService, LeaderboardStatueService = LeaderboardStatueService, UnboxService = UnboxService } },
		require = identity,
		Enum = { DataStoreRequestType = { SetIncrementSortedAsync = 1, GetSortedAsync = 2 } },
		os = { time = function()
			return now
		end, clock = os.clock, date = os.date },
		print = function() end,
		warn = function() end,
		task = { spawn = function(fn, ...)
			fn(...)
		end, wait = function() end },
	})
end
local function loadProfile(p, data)
	profiles[p] = data
	table.insert(playerList, p)
	for _, fn in loaded do
		fn(p)
	end
end
local function giftsOf(p)
	local list = {}
	for _, g in gifts do
		if g.player == p then
			table.insert(list, g)
		end
	end
	return list
end

---------------------------------------------------------------- S1 compteurs de la semaine
local S = freshWeekly(true)
S.Init()
check(boards.WeeklyIncome ~= nil and boards.WeeklySteals ~= nil and boards.WeeklySteals.MaxRows == 100, "S1a deux panneaux ajoutés à LeaderboardService")
local alice, bob, cy = newPlayer("Alice", 11), newPlayer("Bob", 12), newPlayer("Cy", 13)
alice._income = 500
loadProfile(alice, { Items = {}, Lifetime = { Heists = 5, Steals = 2 } }) -- profil sans WeeklyBoard
local wb = profiles[alice].WeeklyBoard
check(type(wb) == "table" and wb.Week == week and wb.StealsAt == 2 and wb.BestIncome == 500 and type(wb.Pending) == "table" and #wb.Pending == 0, "S1b WeeklyBoard créé : semaine, point de départ des vols, revenu du moment, Pending vide")
check(S.ValueOf(alice, "WeeklySteals") == 0, "S1c aucun vol cette semaine")
profiles[alice].Lifetime.Heists = 8
profiles[alice].Lifetime.Steals = 3
check(S.ValueOf(alice, "WeeklySteals") == 1, "S1d a430 (L-325 (1)) : vols = vols chez un autre joueur depuis lundi, braquages exclus")
alice._income = 200
check(S.ValueOf(alice, "WeeklyIncome") == 500, "S1e revenu qui baisse : record de la semaine gardé")
alice._income = 900
alice:SetAttribute("Income", 1)
check(profiles[alice].WeeklyBoard.BestIncome == 900, "S1f suivi au changement de l'attribut Income")
check(alice:GetAttribute("WeeklyBoardEndsAt") == W.WeekStart(week + 1), "S1g WeeklyBoardEndsAt = lundi suivant")
bob._income = 300
loadProfile(bob, { Items = {}, Lifetime = { Heists = 1, Steals = 0 } })
profiles[bob].Lifetime.Heists = 10
profiles[bob].Lifetime.Steals = 9 -- a430 : 9 vols chez un autre joueur (ses 9 braquages ne comptent pas)
cy._income = 10
loadProfile(cy, { Items = {}, Lifetime = { Heists = 0, Steals = 0 } })
-- 120 autres joueurs absents, plus forts en revenu que les présents
local wName = W.StoreName("WeeklyIncome", false, week)
orderedData[wName] = {}
for i = 1, 120 do
	orderedData[wName][tostring(1000 + i)] = W.Encode("WeeklyIncome", 1000 + i)
end

---------------------------------------------------------------- S2 écritures et lecture
S.Step(0)
local sName = W.StoreName("WeeklySteals", false, week)
check(orderedData[wName]["11"] == W.Encode("WeeklyIncome", 900) and orderedData[sName]["11"] == 1 and orderedData[sName]["12"] == 9, "S2a écrit dans les stores de la semaine")
check(orderedData[sName]["13"] == nil, "S2b valeur 0 : rien d'écrit")
local before = #writes
S.Step(W.WriteInterval + 1)
check(#writes == before, "S2c rien de changé : aucune écriture")
check(alice:GetAttribute("WeeklyStealsRank") == 2 and bob:GetAttribute("WeeklyStealsRank") == 1 and cy:GetAttribute("WeeklyStealsRank") == 0, "S2d rangs des vols (0 hors du classement)")
check(cy:GetAttribute("WeeklyIncomeRank") == 0 and alice:GetAttribute("WeeklyIncomeRank") == 0, "S2e hors du top 100 en revenu : 0")
local rows = boards.WeeklyIncome.Rows()
check(#rows == 100 and rows[1].UserId == 1120 and rows[100].Rank == 100, `S2f classement de la semaine : top 100 ({#rows})`)
check(boards.WeeklyIncome.Text(5) == "$5/s" and boards.WeeklySteals.Text(5) == "5", "S2g textes des valeurs")
check(#gifts == 0, "S2h aucune récompense sans semaine finie lue")
check(shows.WeeklyIncome == 1120 and shows.WeeklySteals == 12, `A430a n° 1 donné aux statues ({tostring(shows.WeeklyIncome)}, {tostring(shows.WeeklySteals)})`)

---------------------------------------------------------------- S3 lundi : récompenses
profiles[cy].Lifetime.Heists = 500 -- a430 : braquages ignorés
profiles[cy].Lifetime.Steals = 50
S.Step(3 * W.WriteInterval)
check(cy:GetAttribute("WeeklyStealsRank") == 1, "S3a Cy 1er des vols")
full[bob] = true
now += 7 * 86400
S.Step(10 * W.ReadInterval)
local ga, gb, gc = giftsOf(alice), giftsOf(bob), giftsOf(cy)
check(#gc == 1 and gc[1].rule.TopCount == 2 and gc[1].zone == 1, `S3b 1er des vols : colis Top 3 depuis sa meilleure zone ({#gc})`)
check(#ga == 1 and ga[1].rule.ZoneStep == 1, `S3c Alice 3e des vols : colis Top 3, rien en revenu (hors top 100) ({#ga})`)
check(#gb == 0 and profiles[bob].WeeklyBoard.Rewarded.WeeklySteals ~= week, "S3d Bob inventaire plein : la semaine finie n est pas notée")
check(table.find(profiles[bob].WeeklyBoard.Pending, week) ~= nil, "S3d2 a430 : la semaine de Bob reste dans Pending")
local function fullNotes()
	local n = 0
	for _, note in notes do
		if note.player == bob and note.msg == W.Messages.Full then
			n += 1
		end
	end
	return n
end
check(fullNotes() == 1, "S3e un Notify d'inventaire plein")
check(profiles[alice].WeeklyBoard.Rewarded.WeeklySteals == week and profiles[alice].WeeklyBoard.Rewarded.WeeklyIncome == week, "S3f Alice : deux classements réglés pour la semaine finie")
check(#profiles[alice].WeeklyBoard.Pending == 0, "S3f2 a430 : semaine réglée retirée de Pending")
check(profiles[alice].WeeklyBoard.Week == week + 1 and profiles[alice].WeeklyBoard.StealsAt == 3 and S.ValueOf(alice, "WeeklySteals") == 0, "S3g nouvelle semaine : compteurs remis à zéro")
check(table.find(opened, W.StoreName("WeeklyIncome", false, week + 1)) ~= nil, "S3h nouveau store pour la nouvelle semaine")
local rewardNote = false
for _, n in notes do
	if n.player == cy and n.kind == "Success" and string.find(n.msg, "#1", 1, true) then
		rewardNote = true
	end
end
check(rewardNote, "S3i Notify de la récompense avec le rang")
S.Step(20 * W.ReadInterval)
check(#giftsOf(alice) == 1 and #giftsOf(cy) == 1, "S3j pas de deuxième récompense")
check(fullNotes() == 1, "S3k pas de deuxième Notify d'inventaire plein dans la session")
full[bob] = nil
S.Step(30 * W.ReadInterval)
check(#giftsOf(bob) == 1 and profiles[bob].WeeklyBoard.Rewarded.WeeklySteals == week, "S3l place faite : Bob reçoit son colis")
check(#profiles[bob].WeeklyBoard.Pending == 0, "S3l2 a430 : Pending de Bob vide")

---------------------------------------------------------------- S4 joueur qui arrive la semaine suivante
local dan = newPlayer("Dan", 1120) -- 1er du revenu la semaine finie, absent jusque-là
loadProfile(dan, { Items = {}, Lifetime = { Heists = 0, Steals = 0 }, WeeklyBoard = { Week = week, BestIncome = 2000, StealsAt = 0, Rewarded = {}, Pending = {} } }) -- a430 : il a joué la semaine finie
check(#giftsOf(dan) == 1 and giftsOf(dan)[1].rule.TopCount == 2, "S4 arrivée après le lundi : récompense tout de suite (top déjà lu)")

---------------------------------------------------------------- S5 départ et Studio sans API
before = #writes
profiles[dan].Lifetime.Steals = 3
for _, fn in releasing do
	fn(dan)
end
check(#writes == before + 1 and orderedData[W.StoreName("WeeklySteals", false, week + 1)]["1120"] == 3, "S5a départ : vols écrits")

---------------------------------------------------------------- P (a430, L-325 (3)) : la récompense attend le joueur
-- (inséré dans autres-bancs/a409/tests.luau après S5a ; gardé ici pour la relecture)
table.clear(playerList)
now += 14 * 86400 -- trois semaines après la semaine récompensée
local SP = freshWeekly(true)
SP.Init()
local fen = newPlayer("Fen", 1119) -- 2e du revenu de la semaine `week`, absent depuis
loadProfile(fen, { Items = {}, Lifetime = { Heists = 0, Steals = 0 }, WeeklyBoard = { Week = week, BestIncome = 2000, StealsAt = 0, Rewarded = {}, Pending = {} } })
local fb = profiles[fen].WeeklyBoard
check(#giftsOf(fen) == 0 and #fb.Pending == 1 and fb.Pending[1] == week and fb.Week == W.WeekOf(now), "P1a absent 3 semaines : la semaine jouée attend dans Pending (top pas encore lu)")
SP.Step(0)
check(#giftsOf(fen) == 1 and giftsOf(fen)[1].rule.TopCount == 2 and #fb.Pending == 0 and fb.Rewarded.WeeklyIncome == week and fb.Rewarded.WeeklySteals == week, "P1b récompense donnée des semaines plus tard, semaine retirée de Pending")
SP.Step(5 * W.ReadInterval)
check(#giftsOf(fen) == 1, "P1c pas de deuxième récompense")
local gus = newPlayer("Gus", 1118) -- 3e du revenu de la semaine `week`
full[gus] = true
loadProfile(gus, { Items = {}, Lifetime = { Heists = 0, Steals = 0 }, WeeklyBoard = { Week = week, BestIncome = 1, StealsAt = 0, Rewarded = {}, Pending = {} } })
SP.Step(10 * W.ReadInterval)
local gub = profiles[gus].WeeklyBoard
check(#giftsOf(gus) == 0 and gub.Pending[1] == week and gub.Rewarded.WeeklyIncome == nil and gub.Rewarded.WeeklySteals == week, "P2a inventaire plein : la semaine reste dans Pending (vols réglés : hors du top)")
for _, fn in releasing do
	fn(gus)
end
table.remove(playerList, table.find(playerList, gus))
now += 7 * 86400 -- il revient la semaine d'après, place faite
full[gus] = nil
-- tops lus une fois par serveur : les données de Hal (plus bas) sont là avant la première lecture de SQ
orderedData[W.StoreName("WeeklyIncome", false, week)]["4242"] = W.Encode("WeeklyIncome", 1110.5) -- 11e du revenu de `week` (sous Fen et Gus : leurs rangs ne bougent pas)
local sw1 = W.StoreName("WeeklySteals", false, week + 1)
orderedData[sw1] = orderedData[sw1] or {}
orderedData[sw1]["4242"] = 99 -- 1er des vols de la semaine d après
local SQ = freshWeekly(true)
SQ.Init()
loadProfile(gus, profiles[gus])
SQ.Step(0)
check(#giftsOf(gus) == 1 and giftsOf(gus)[1].rule.TopCount == 2 and #gub.Pending == 0 and gub.Rewarded.WeeklyIncome == week, "P2b retour une semaine plus tard, place faite : récompense donnée")
-- deux semaines qui attendent : réglées dans l'ordre
local hal = newPlayer("Hal", 4242)
loadProfile(hal, { Items = {}, Lifetime = { Heists = 0, Steals = 99 }, WeeklyBoard = { Week = week + 1, BestIncome = 0, StealsAt = 0, Rewarded = {}, Pending = { week } } })
local hb = profiles[hal].WeeklyBoard
check(#giftsOf(hal) == 1 and giftsOf(hal)[1].rule.TopBoost == 1.5 and #hb.Pending == 1 and hb.Pending[1] == week + 1, "P3a deux semaines attendent : la plus ancienne (top déjà lu) réglée tout de suite, la suivante attend sa lecture")
SQ.Step(5 * W.ReadInterval)
check(#giftsOf(hal) == 2 and #hb.Pending == 0 and hb.Rewarded.WeeklyIncome == week + 1 and hb.Rewarded.WeeklySteals == week + 1, `P3b deux récompenses, une par semaine ({#giftsOf(hal)})`)
SQ.Step(9 * W.ReadInterval)
check(#giftsOf(hal) == 2, "P3c rien de plus")
local ivy = newPlayer("Ivy", 5151)
loadProfile(ivy, { Items = {}, Lifetime = { Heists = 40, Steals = 0 }, WeeklyBoard = { Week = 0, BestIncome = 0, StealsAt = 0, Rewarded = {}, Pending = {} } })
check(#profiles[ivy].WeeklyBoard.Pending == 0 and profiles[ivy].WeeklyBoard.StealsAt == 0 and SQ.ValueOf(ivy, "WeeklySteals") == 0, "P4 gabarit (Week = 0) : rien en attente, compteurs posés")
profiles[ivy].Lifetime.Heists = 90
check(SQ.ValueOf(ivy, "WeeklySteals") == 0, "P5 braquages seuls : 0 vol de la semaine")
table.clear(playerList)
odsBroken = true
table.clear(playerList)
local S2 = freshWeekly(true)
S2.Init()
local ed = newPlayer("Ed", 77)
ed._income = 5
loadProfile(ed, { Items = {}, Lifetime = { Heists = 0, Steals = 0 } })
local ok = pcall(S2.Step, 0)
check(ok and boards.WeeklyIncome.Rows()[1].UserId == 77, "S5b sans API : pas d'erreur, joueurs présents classés")
check(shows.WeeklyIncome == 77 and shows.WeeklySteals == 0, "S5c a430 : statues, n° 1 présent ; aucun vol : 0 (statue dorée)")
odsBroken = false

---------------------------------------------------------------- S6 coupé
table.clear(boards)
table.clear(playerList)
before = #writes
local S3 = freshWeekly(false)
S3.Init()
S3.Step(0)
check(next(boards) == nil and #writes == before, "S6 Features.WeeklyLeaderboards = false : rien")

---------------------------------------------------------------- A casse du siècle (calculs purs du vrai service)
local function stub()
	return setmetatable({}, { __index = function()
		return function() end
	end })
end
local V = load(AV_SOURCE, "ArmoredVanService", {
	game = { GetService = function(_, n)
		if n == "ReplicatedStorage" then
			return { Shared = {
				Config = { ArmoredVan = AV, Features = { ArmoredVan = true }, Items = { ById = {} }, Mutations = {}, Rarities = { ById = {} }, Zones = {} },
				Announce = stub(),
				Format = stub(),
				Net = { Net = stub() },
			} }
		elseif n == "RunService" then
			return { IsStudio = function()
				return false
			end }
		end
		return stub()
	end },
	script = { Parent = { DataService = stub(), NightCycleService = stub(), ToolService = stub(), UnboxService = stub(), WindowService = stub() } },
	require = identity,
	print = function() end,
	warn = function() end,
})
check(V.NextDeparture(0) == 1800 and V.NextDeparture(1799) == 1800 and V.NextDeparture(1800) == 3600, "A1a départ à heure fixe, toutes les 30 min")
check(AV.Period == 1800 and AV.Offset == 0, "A1b toutes les 30 min (Partie 2), à l'heure pile et à la demie")
check(V.MaxHP({}) == AV.MinHP and V.MaxHP({ 100, 200 }) == AV.HPPerDamage * 300 and V.MaxHP({ 0 / 0, -5, math.huge, 10 }) == math.max(AV.MinHP, AV.HPPerDamage * 10), "A2 PV selon les dégâts du serveur, au moins MinHP, valeurs invalides ignorées")
local places = V.Ranking({ [1] = 500, [2] = 300, [3] = 100, [4] = 90, [5] = 10 }, 1000)
check(#places == 5 and places[1].UserId == 1 and places[5].UserId == 5 and places[1].Rank == 1, "A3a classement par dégâts")
check(places[1].Tier.MaxRank == 3 and places[3].Tier.MaxRank == 3 and places[3].Tier.Rule.ZoneStep == 1, "A3b top 3 : meilleur colis (zone suivante)")
check(places[4].Tier and places[4].Tier.Label == "Box" and places[5].Tier == nil, "A3c au-delà : colis de sa zone ; moins de 2 % : rien")
places = V.Ranking({ [1] = 400, [2] = 300, [3] = 250, [4] = 200 }, 1000)
check(places[4].Tier.Label == "Big Box", "A3d 4e avec 20 % des dégâts : Big Box")
places = V.Ranking({ [1] = 980, [2] = 10, [3] = 0, [4] = 0 / 0 }, 1000)
check(#places == 2 and places[2].Tier == nil, "A3e 2e du top 3 sous 2 % : rien ; dégâts nuls ou invalides ignorés")
places = V.Ranking({ [7] = 50, [3] = 50 }, 100)
check(places[1].UserId == 3 and places[2].UserId == 7, "A3f égalité : ordre stable (UserId)")
check(V.IsActive() == false, "A4 aucun fourgon au chargement")

print(`{checks} vérification(s), {fails} échec(s)`)
