---------------------------------------------------------------- défilement (a430, L-330 (3)) : vrai LeaderboardScrollController
local LB = load(LB_SOURCE, "Leaderboard", table.clone(cfgEnv))
local world = new("Workspace", { Name = "Workspace" })
local storage2 = new("ServerStorage", { Name = "ServerStorage" })
local playerGui = new("PlayerGui", { Name = "PlayerGui" })
local localPlayer = new("Player", { Name = "Me" })
playerGui.Parent = localPlayer
local configFolder = new("Folder", { Name = "Config" })
local shared = new("Folder", { Name = "Shared" })
configFolder.Parent = shared
local rs = new("ReplicatedStorage", { Name = "ReplicatedStorage" })
shared.Parent = rs
-- require(<instance>) : la config chargée qui porte ce nom
local configs = { Leaderboard = LB, WeeklyLeaderboard = W }
new("ModuleScript", { Name = "Leaderboard" }, configFolder)
new("ModuleScript", { Name = "WeeklyLeaderboard" }, configFolder)
local function panel(stat, scrolling, parent, rows)
	local model = new("Model", { Name = "ENV_Hub_Leaderboard" }, parent)
	model:SetAttribute("Stat", stat)
	local screen = new("Part", { Name = "Screen" }, model)
	local gui = new("SurfaceGui", { Name = "Board", Enabled = true }, screen)
	local header = new("Frame", { Name = "Header" }, gui)
	new("TextLabel", { Name = "Title", Text = "" }, header)
	local list = new(if scrolling then "ScrollingFrame" else "Frame", { Name = "List", CanvasPosition = { X = 0, Y = 0 } }, gui)
	new("Frame", { Name = "Template", Visible = false }, list)
	for i = 1, rows do
		local row = new("Frame", { Name = string.format("Row_%02d", i), Visible = true }, list)
		row:SetAttribute("LeaderboardRow", true)
	end
	tagged.Leaderboard = tagged.Leaderboard or {}
	table.insert(tagged.Leaderboard, model)
	return model, gui, list, screen
end
local function copiesIn()
	local out = {}
	for _, c in playerGui:GetChildren() do
		if string.sub(c.Name, 1, 18) == "LeaderboardScroll_" then
			table.insert(out, c)
		end
	end
	return out
end
local function rowCount(list)
	local n = 0
	for _, c in list:GetChildren() do
		if c:GetAttribute("LeaderboardRow") == true then
			n += 1
		end
	end
	return n
end
local weeklyModel, weeklyGui, weeklyList, weeklyScreen = panel("WeeklySteals", true, world, 30)
local _, incomeGui = panel("Income", false, world, 10)
local _, backupGui = panel("WeeklyIncome", true, storage2, 5)
local Sc = load(SCROLL_SOURCE, "LeaderboardScrollController", {
	game = { GetService = function(_, n)
		if n == "CollectionService" then
			return CollectionService
		elseif n == "Players" then
			return { LocalPlayer = localPlayer }
		elseif n == "ReplicatedStorage" then
			return rs
		elseif n == "Workspace" then
			return world
		end
		error("service " .. n)
	end },
	require = function(m)
		return configs[m.Name]
	end,
	task = { wait = coroutine.yield, defer = function(fn, ...)
		fn(...)
	end },
	warn = function(m)
		print("ERREUR " .. tostring(m))
	end,
})
local co = coroutine.create(Sc.Start)
local function tick()
	local ok, problem = coroutine.resume(co)
	if not ok then
		print("ERREUR " .. tostring(problem))
	end
end
tick()
local list = copiesIn()
check(#list == 1 and list[1].Name == "LeaderboardScroll_WeeklySteals", `C1a une copie, pour le seul panneau à défilement du Workspace ({#list})`)
local copy = list[1]
check(copy and copy.Adornee == weeklyScreen and copy.Enabled == true and copy.ResetOnSpawn == false, "C1b copie dans le PlayerGui : Adornee = Screen, allumée, gardée à la réapparition")
check(copy and rowCount(copy:FindFirstChild("List", true)) == 30, "C1c les 30 lignes copiées")
check(weeklyGui.Enabled == false and incomeGui.Enabled == true and backupGui.Enabled == true, "C1d Board d'origine éteint en local ; panneau sans défilement et copie de ServerStorage pas touchés")
copy:FindFirstChild("List", true).CanvasPosition = { X = 0, Y = 300 }
tick()
check(copiesIn()[1] == copy, "C2 rien de changé : copie gardée")
-- le serveur réécrit les lignes (40 cette fois)
for _, c in weeklyList:GetChildren() do
	if c:GetAttribute("LeaderboardRow") == true then
		c:Destroy()
	end
end
for i = 1, 40 do
	local row = new("Frame", { Name = string.format("Row_%02d", i) }, weeklyList)
	row:SetAttribute("LeaderboardRow", true)
end
tick()
list = copiesIn()
local newList = list[1] and list[1]:FindFirstChild("List", true)
check(#list == 1 and list[1] ~= copy and rawget(copy, "_dead") == true, "C3a lignes changées : copie refaite, l'ancienne retirée")
check(newList and rowCount(newList) == 40 and newList.CanvasPosition.Y == 300, "C3b nouvelles lignes, même position de défilement")
weeklyModel.Parent = nil -- parti (StreamingEnabled)
tick()
check(#copiesIn() == 0, "C4 panneau parti : copie retirée")
weeklyModel.Parent = world
tick()
check(#copiesIn() == 1 and copiesIn()[1].Adornee == weeklyScreen, "C5 panneau revenu : recopié")
