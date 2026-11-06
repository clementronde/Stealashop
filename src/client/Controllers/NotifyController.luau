--!strict
-- NotifyController (client) : reçoit les messages `Notify` du serveur.
--
-- L'écran `UI_Notify` de Clément (contrat 2.2) n'est pas encore livré : en attendant
-- (DEV-021), le message est écrit dans la sortie, en Studio seulement. Sans écouteur,
-- Roblox jetait ces messages avec une erreur rouge dans la sortie du client.
--
-- API (client) :
--   NotifyController.OnNotify(fn(message, kind?)) -> déconnexion

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

type Listener = (message: string, kind: string?) -> ()

local NotifyController = {}

local listeners: { Listener } = {}

function NotifyController.OnNotify(listener: Listener): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function NotifyController.Start()
	local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Net")) :: any

	Net.Client.Notify:Connect(function(message: string, kind: string?)
		if RunService:IsStudio() then
			print(`[Notify{if kind then " " .. kind else ""}] {message}`)
		end
		for _, listener in table.clone(listeners) do
			task.spawn(listener, message, kind)
		end
	end)
end

return NotifyController
