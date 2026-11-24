--!strict
-- ChaseV3 (a443 ; Cantin, 2026-11-24, refonte de la poursuite) : la poursuite « V3 » est-elle allumée dans ce jeu ?
-- Lu par le serveur (GuardService) et par le client (GuardViewController) : la même réponse des deux côtés.
--   Features.ChaseV3 = true                      : partout (PROD comprise) ;
--   Features.ChaseV3Dev = true, dans le jeu DEV  : Config/ProductIds.IsDev (comme NewTrapsDev, ShopGlassThrowDev) ;
--   en Studio, workspace:SetAttribute("ChaseV3Test", true ou false) force la réponse (lu à chaque appel) : pour
--   comparer les deux poursuites dans le même Play, sans toucher à Config/Features.
-- Règle et valeurs : Config/Chase.V3. Éteinte : la poursuite d'avant, intacte.
--
--   ChaseV3.Enabled() -> boolean

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Features = require(script.Parent.Config.Features) :: any

local TEST_ATTRIBUTE = "ChaseV3Test"

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

local base = Features.ChaseV3 == true or (Features.ChaseV3Dev == true and isDev)

local ChaseV3 = {}

function ChaseV3.Enabled(): boolean
	if isStudio then
		local forced = Workspace:GetAttribute(TEST_ATTRIBUTE)
		if type(forced) == "boolean" then
			return forced
		end
	end
	return base
end

return ChaseV3
