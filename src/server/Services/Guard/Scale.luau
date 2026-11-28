--!strict
-- Guard/Scale (serveur, a518, 27/11 ; liaison L-437) : module d'aide de GuardService (sous-dossier : le Loader ne le
-- démarre pas). Interrupteur Features.GuardScale (PROD) / GuardScaleDev (DEV et TEST) ; valeurs : Config/Guards.Scale.
--
-- Clément (27/11) : « les vigiles doivent être 1,5 fois plus gros que les joueurs ». Le clone en jeu (jamais le modèle de
-- Clément) passe à Model:ScaleTo(Size) avant d'être posé : la taille ne dépend plus du modèle (Guard_Z1 à Z6, NightGuard,
-- rig de remplacement). La HipHeight suit (remise à l'échelle ici si ScaleTo ne l'a pas fait). Tout ce que GuardService
-- calcule ensuite part du clone agrandi : hauteur du HumanoidRootPart (pose au sol), agent du chemin, rythme de Walk et de
-- Run (WalkSpeed / (référence × échelle)). Le reste ne change pas : vitesses (fixées par le code), distance de capture
-- (Balance.Guard.CatchDistance, entre les deux HumanoidRootPart), poussée. L'agent du chemin est plafonné à
-- Scale.AgentRadiusMax : sa boîte, bras compris, le croirait trop large pour les allées des magasins.
-- Vigiles de magasin et de nuit (Scale.Night) ; jamais le conducteur du camion ni le policier.
--
-- API :
--   Scale.Apply(model, night) -> boolean   met le clone à l'échelle ; false : interrupteur coupé ou échec (taille gardée)
--   Scale.Agent(agent)                     plafonne AgentRadius d'un agent calculé sur un clone mis à l'échelle

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = (ReplicatedStorage :: any).Shared.Config
local Guards = require(Config.Guards) :: any
local Switch = require(script.Parent.Switch) :: any

local SWITCH = "GuardScale"
local AGENT_RADIUS_MIN = 2 -- comme GuardService : jamais moins qu'un R15 standard

local Scale = {}

function Scale.On(): boolean
	return Switch.On(SWITCH)
end

function Scale.Apply(model: Model, night: boolean): boolean
	local cfg = Guards.Scale
	if not Scale.On() or (night and cfg.Night ~= true) then
		return false
	end
	local target = cfg.Size
	if type(target) ~= "number" or target <= 0 or target ~= target then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hipBefore = if humanoid then humanoid.HipHeight else 0
	local ok, err = pcall(function(): any
		local before = model:GetScale()
		if math.abs(before - target) >= 1e-3 then
			model:ScaleTo(target)
			-- ScaleTo met la HipHeight à l'échelle ; sinon (anciennes versions, faux Roblox) elle est corrigée ici.
			if humanoid and before > 0 and math.abs(humanoid.HipHeight - hipBefore) < 1e-4 then
				humanoid.HipHeight = hipBefore * target / before
			end
		end
		return nil
	end)
	if not ok then
		warn(`[GuardService] {model.Name} : ScaleTo({target}) a échoué ({err}), taille du modèle gardée`)
		return false
	end
	return true
end

function Scale.Agent(agent: { [string]: any })
	local max = Guards.Scale.AgentRadiusMax
	local radius = agent.AgentRadius
	if type(max) == "number" and type(radius) == "number" and radius > max then
		agent.AgentRadius = math.max(AGENT_RADIUS_MIN, max)
	end
end

return Scale
