--!strict
-- Point d'entrée client de Steal a Shop (StarterPlayerScripts/Client/Main).
-- Charge tous les contrôleurs de StarterPlayerScripts/Client/Controllers (DEV-002).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loader")) :: any

Loader.start(script.Parent:FindFirstChild("Controllers"), "Client")
