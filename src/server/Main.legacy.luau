--!strict
-- Point d'entrée serveur de Steal a Shop (ServerScriptService/Server/Main).
-- Charge tous les services de ServerScriptService/Server/Services (DEV-002).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loader")) :: any

Loader.start(script.Parent:FindFirstChild("Services"), "Serveur")
