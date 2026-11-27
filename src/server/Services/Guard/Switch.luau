--!strict
-- Guard/Switch (serveur, a518, 27/11) : module d'aide de GuardService (sous-dossier : le Loader ne le démarre pas).
-- Un interrupteur de Config/Features allumé dans ce jeu : `X` partout, ou `XDev` dans le jeu DEV et TEST
-- (Config/ProductIds.IsDev, comme BatFreePvPDev). Lu à chaque appel (Config/LiveFeatures.Hot : rallumable sans republier).
--
-- API :
--   Switch.On(name) -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = (ReplicatedStorage :: any).Shared.Config
local Features = require(Config.Features) :: any

-- Config/ProductIds chargé s'il est là ; sans lui, IsDev faux (PROD).
local isDev = (function(): boolean
	local module = Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return (result :: any).IsDev == true
		end
	end
	return false
end)()

local Switch = {}

function Switch.On(name: string): boolean
	return Features[name] == true or (isDev and Features[name .. "Dev"] == true)
end

return Switch
