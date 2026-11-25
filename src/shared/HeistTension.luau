--!strict
-- HeistTension (a465 ; liaison L-340) : la tension du braquage est-elle allumée chez ce client ?
-- Lu par TensionController, VfxController, ChaseFeelController et UiFeelController (même réponse partout).
--   Features.HeistTension = true                    : partout (PROD comprise) ;
--   Features.HeistTensionDev = true, dans le jeu DEV : Config/ProductIds.IsDev (comme ChaseV3Dev) ;
--   en Studio, workspace:SetAttribute("HeistTensionTest", true ou false) force la réponse (lu à chaque appel), pour
--   comparer avant et après dans le même Play sans toucher à Config/Features.
-- Réglages : Config/HeistTension. Éteinte : tout reste comme avant.
--
--   HeistTension.Enabled() -> boolean

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Features = require(script.Parent.Config.Features) :: any

local TEST_ATTRIBUTE = "HeistTensionTest"

-- Config/ProductIds chargé s'il est là ; sans lui, IsDev faux (PROD).
local isDev = (function(): boolean
	local module = script.Parent.Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return (result :: any).IsDev == true
		end
	end
	return false
end)()

local isStudio = (function(): boolean
	local ok, result = pcall(function(): boolean
		return RunService:IsStudio()
	end)
	return ok and result == true
end)()

local base = Features.HeistTension == true or (Features.HeistTensionDev == true and isDev)

local HeistTension = {}

HeistTension.TestAttribute = TEST_ATTRIBUTE

function HeistTension.Enabled(): boolean
	if isStudio then
		local forced = Workspace:GetAttribute(TEST_ATTRIBUTE)
		if type(forced) == "boolean" then
			return forced
		end
	end
	return base
end

return HeistTension
