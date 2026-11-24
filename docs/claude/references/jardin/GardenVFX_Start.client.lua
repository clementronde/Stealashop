-- LocalScript (StarterPlayer > StarterPlayerScripts) — starts the garden animations and VFX.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GardenVFX = require(ReplicatedStorage:WaitForChild("GardenVFX"))
GardenVFX.Start()
