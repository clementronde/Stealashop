--!strict
-- LoadingGate (a532, Cantin 28/11) : « le jeu a commencé » pour les écrans qui attendaient la fin du chargement (le
-- tuto, TutorialController ; les gains hors ligne, OfflineController). Le signal est l'attribut LoadingDone du Player,
-- posé à true par l'écran de chargement (ReplicatedFirst/First/LoadingScreen) quand il se ferme : fin du chargement,
-- Skip, garde-fou de LoadingConfig.MaxWait, ou écran UI_Loading absent.
-- Seulement avec Features.LoadingReal (partout) ou LoadingRealDev (jeu DEV et TEST) : éteint, rien n'attend (comme
-- avant a532). Secours : passé TimeoutSeconds de jeu (time()), plus rien n'attend, même sans l'attribut (script de
-- chargement en erreur) : jamais de blocage.
--
-- API (client) :
--   LoadingGate.Attribute = "LoadingDone"     (même nom que LoadingConfig.DoneAttribute)
--   LoadingGate.TimeoutSeconds
--   LoadingGate.Enabled() -> boolean
--   LoadingGate.IsDone(player, now?) -> boolean   vrai : plus rien à attendre (now : time() par défaut)

local Config = script.Parent:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any

-- Config/ProductIds chargé s'il est là ; sans lui, IsDev faux (PROD), comme BoxZoneTag.
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

local LoadingGate = {}

LoadingGate.Attribute = "LoadingDone"
LoadingGate.TimeoutSeconds = 60 -- V0 : MaxWait (45 s) + le fondu, avec de la marge

function LoadingGate.Enabled(): boolean
	return Features.LoadingReal == true or (Features.LoadingRealDev == true and isDev)
end

function LoadingGate.IsDone(player: Player, now: number?): boolean
	if not LoadingGate.Enabled() then
		return true
	end
	if player:GetAttribute(LoadingGate.Attribute) == true then
		return true
	end
	return (now or time()) >= LoadingGate.TimeoutSeconds
end

return table.freeze(LoadingGate)
