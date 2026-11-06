--!strict
-- WindowController (client) : écoute l'état des vitrines envoyé par WindowService.
--
-- Garde en mémoire les derniers PV reçus de chaque vitrine (`WindowHP`, non fiable, au
-- plus 10 fois/s) et les casses (`WindowBroken`). Il n'affiche rien pour l'instant : la
-- barre de PV `BB_WindowHP` (UI-001, Clément) et la casse côté client (DEV-016,
-- ShatterController) se brancheront sur son API. Sans écouteur, Roblox jetait ces
-- messages avec une erreur rouge dans la sortie du client.
--
-- API (client) :
--   WindowController.GetHP(windowId) -> (hp: number?, maxHp: number?)
--   WindowController.OnHP(fn(windowId, hp, maxHp)) -> déconnexion
--   WindowController.OnBroken(fn(windowId, impactPoint)) -> déconnexion

local ReplicatedStorage = game:GetService("ReplicatedStorage")

type HPListener = (windowId: string, hp: number, maxHp: number) -> ()
type BrokenListener = (windowId: string, impactPoint: Vector3) -> ()

local WindowController = {}

local hpById: { [string]: { hp: number, maxHp: number } } = {}
local hpListeners: { HPListener } = {}
local brokenListeners: { BrokenListener } = {}

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

function WindowController.GetHP(windowId: string): (number?, number?)
	local entry = hpById[windowId]
	if entry == nil then
		return nil, nil
	end
	return entry.hp, entry.maxHp
end

function WindowController.OnHP(listener: HPListener): () -> ()
	return subscribe(hpListeners, listener)
end

function WindowController.OnBroken(listener: BrokenListener): () -> ()
	return subscribe(brokenListeners, listener)
end

function WindowController.Start()
	local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Net")) :: any

	Net.Client.WindowHP:Connect(function(windowId: string, hp: number, maxHp: number)
		hpById[windowId] = { hp = hp, maxHp = maxHp }
		for _, listener in table.clone(hpListeners) do
			task.spawn(listener, windowId, hp, maxHp)
		end
	end)

	Net.Client.WindowBroken:Connect(function(windowId: string, impactPoint: Vector3)
		local entry = hpById[windowId]
		if entry then
			entry.hp = 0
		end
		for _, listener in table.clone(brokenListeners) do
			task.spawn(listener, windowId, impactPoint)
		end
	end)
end

return WindowController
