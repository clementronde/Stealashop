--!strict
-- LeaderboardScrollController (a430, L-330 (3) ; client) : défilement des panneaux de classement du hub dont List est
-- une ScrollingFrame (les deux panneaux de la semaine, top 100). Une ScrollingFrame dans un SurfaceGui du Workspace
-- s'affiche mais ne reçoit pas les entrées du joueur : il faut le SurfaceGui dans le PlayerGui, avec Adornee.
--
--   - Toutes les WeeklyLeaderboard.ScrollRefresh s : pour chaque panneau taggé Leaderboard du Workspace (pas les copies
--     de ServerStorage/MapBackups) dont Board (SurfaceGui) a une List en ScrollingFrame, une copie de Board est posée
--     dans le PlayerGui (nom « LeaderboardScroll_<Stat> », Adornee = la pièce de Board, Screen) et le Board d'origine
--     est éteint chez ce joueur seulement (Enabled = false, en local : rien n'est répliqué).
--   - Le serveur (LeaderboardService) réécrit les lignes du Board d'origine à chaque lecture : dès qu'elles changent,
--     la copie est refaite au contrôle suivant, à la même position de défilement.
--   - Panneau parti (StreamingEnabled) : sa copie est retirée ; revenu : recopié.
-- Aucun visuel de Clément modifié (la copie est identique), rien n'est envoyé au serveur.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Leaderboard = require(Config:WaitForChild("Leaderboard"))
local Weekly = require(Config:WaitForChild("WeeklyLeaderboard"))

type Copy = {
	copy: SurfaceGui,
	dirty: boolean,
	connections: { RBXScriptConnection },
}

local LeaderboardScrollController = {}

local copies: { [SurfaceGui]: Copy } = {}

local function listOf(gui: Instance): ScrollingFrame?
	local list = gui:FindFirstChild(Leaderboard.List, true)
	return if list and list:IsA("ScrollingFrame") then list else nil
end

-- Board à copier d'un panneau taggé, et la pièce où l'afficher ; nil s'il n'y a rien à faire défiler.
local function sourceOf(board: Instance): (SurfaceGui?, BasePart?)
	if not board:IsDescendantOf(Workspace) then
		return nil, nil
	end
	local gui = board:FindFirstChild(Leaderboard.Gui, true)
	if gui == nil or not gui:IsA("SurfaceGui") or listOf(gui) == nil then
		return nil, nil
	end
	local part = gui.Adornee or gui.Parent
	if part == nil or not part:IsA("BasePart") then
		return nil, nil
	end
	return gui, part
end

local function drop(gui: SurfaceGui)
	local entry = copies[gui]
	if entry == nil then
		return
	end
	copies[gui] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.copy:Destroy()
	if gui.Parent ~= nil then
		gui.Enabled = true
	end
end

local function build(gui: SurfaceGui, part: BasePart, playerGui: Instance, stat: string)
	local old = copies[gui]
	local fresh = gui:Clone()
	fresh.Name = `LeaderboardScroll_{stat}`
	fresh.Enabled = true
	fresh.Adornee = part
	fresh.ResetOnSpawn = false
	local oldList = if old then listOf(old.copy) else nil
	local canvas: Vector2? = if oldList then oldList.CanvasPosition else nil
	fresh.Parent = playerGui
	gui.Enabled = false
	if old then
		old.copy:Destroy()
	end
	local newList = listOf(fresh)
	if canvas and newList then
		newList.CanvasPosition = canvas
		task.defer(function()
			if newList.Parent ~= nil then
				newList.CanvasPosition = canvas -- après le calcul du canevas automatique
			end
		end)
	end
	local entry: Copy = old or { copy = fresh, dirty = false, connections = {} }
	entry.copy = fresh
	entry.dirty = false
	if old == nil then
		local function mark()
			entry.dirty = true
		end
		table.insert(entry.connections, gui.DescendantAdded:Connect(mark))
		table.insert(entry.connections, gui.DescendantRemoving:Connect(mark))
		copies[gui] = entry
	end
end

local function step(playerGui: Instance)
	local seen: { [SurfaceGui]: boolean } = {}
	for _, board in CollectionService:GetTagged(Leaderboard.Tag) do
		local gui, part = sourceOf(board)
		if gui and part then
			seen[gui] = true
			local entry = copies[gui]
			if entry == nil or entry.dirty or entry.copy.Parent ~= playerGui then
				local stat = board:GetAttribute(Leaderboard.StatAttribute)
				build(gui, part, playerGui, tostring(stat))
			elseif entry.copy.Adornee ~= part then
				entry.copy.Adornee = part
			end
		end
	end
	for gui in copies do
		if not seen[gui] then
			drop(gui)
		end
	end
end

function LeaderboardScrollController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	while true do
		local ok, problem = pcall(function()
			step(playerGui)
		end)
		if not ok then
			warn(`[LeaderboardScrollController] {tostring(problem)}`)
			task.wait(10)
		end
		task.wait(Weekly.ScrollRefresh)
	end
end

return LeaderboardScrollController
