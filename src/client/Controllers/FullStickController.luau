--!strict
-- FullStickController (a443, client ; Cantin, 2026-11-24 : « qu'on ne puisse pas être ralenti », pareil sur PC, téléphone
-- et manette) : dès que le stick sort de la zone morte, le personnage marche à sa pleine WalkSpeed ; dans la zone morte,
-- il s'arrête. Le clavier ne change pas (sa direction a déjà une longueur de 1). Calcul : Shared/FullStick ; valeurs :
-- Config/Gamepad.FullStick ; interrupteur : Features.FullSpeedStick (partout) ou FullSpeedStickDev (jeu DEV,
-- Config/ProductIds.IsDev). Éteint : rien n'est branché.
--
-- Méthode, sans copier le PlayerModule de Roblox : le ControlModule (PlayerModule:GetControls()) appelle à chaque image
-- sa fonction de marche `moveFunction` (Player.Move par défaut) avec la direction voulue. Elle est remplacée par la même
-- fonction, direction remise à longueur 1 (FullStick.Wrap). `moveFunction` est un champ interne du ControlModule : s'il
-- n'existe plus, repli sur l'API publique : après le pas du ControlModule (BindToRenderStep, priorité Input + 1), la
-- direction lue par GetMoveVector est rejouée à pleine longueur par Player:Move (relative à la caméra). Si rien de cela
-- n'existe : un avertissement en Studio, et la marche de Roblox telle quelle.
-- Le serveur ne reçoit rien de plus : la WalkSpeed reste posée par le serveur, seule la part du stick change.
--
-- API (client) :
--   FullStickController.GetMode() -> "Off" | "MoveFunction" | "RenderStep" | "Failed"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FullStick = require(Shared:WaitForChild("FullStick"))

local STEP_NAME = "FullStickMove"
local MODULE_WAIT = 30 -- s : attente du PlayerModule de Roblox dans PlayerScripts

local IS_STUDIO = RunService:IsStudio()

local FullStickController = {}

local mode = "Off"

local function enabled(): boolean
	local config = Shared:WaitForChild("Config")
	local features = require(config:WaitForChild("Features") :: ModuleScript) :: any
	if features.FullSpeedStick == true then
		return true
	end
	if features.FullSpeedStickDev ~= true then
		return false
	end
	local module = config:FindFirstChild("ProductIds")
	if module == nil then
		return false
	end
	local ok, result = pcall(require, module :: any)
	return ok and type(result) == "table" and (result :: any).IsDev == true
end

local function install(deadZone: number): string
	local player = Players.LocalPlayer
	local scripts = player:WaitForChild("PlayerScripts", MODULE_WAIT)
	local module = if scripts then scripts:WaitForChild("PlayerModule", MODULE_WAIT) else nil
	if module == nil or not module:IsA("ModuleScript") then
		return "Failed"
	end
	local playerModule: any = (require :: any)(module)
	local controls: any = nil
	if type(playerModule) == "table" and type(playerModule.GetControls) == "function" then
		controls = (playerModule.GetControls :: any)(playerModule)
	end
	if type(controls) ~= "table" then
		return "Failed"
	end
	if type(controls.moveFunction) == "function" then
		controls.moveFunction = FullStick.Wrap(controls.moveFunction, deadZone)
		return "MoveFunction"
	end
	if type(controls.GetMoveVector) == "function" then
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Input.Value + 1, function()
			local ok, direction = pcall(controls.GetMoveVector, controls)
			if ok and typeof(direction) == "Vector3" and direction.Magnitude > 1e-4 then
				player:Move(FullStick.Scale(direction, deadZone), true)
			end
		end)
		return "RenderStep"
	end
	return "Failed"
end

function FullStickController.GetMode(): string
	return mode
end

function FullStickController.Start()
	if not enabled() then
		return -- interrupteur coupé : la marche de Roblox
	end
	task.spawn(function()
		local gamepad = require(Shared:WaitForChild("Config"):WaitForChild("Gamepad") :: ModuleScript) :: any
		local cfg = gamepad.FullStick
		local deadZone = if type(cfg) == "table" and type(cfg.DeadZone) == "number" then cfg.DeadZone else 0
		local ok, result = pcall(install, deadZone)
		mode = if ok then result else "Failed"
		if IS_STUDIO then
			if mode == "Failed" then
				warn(`[FullStick] pleine vitesse au stick non branchée ({if ok then "PlayerModule ou ControlModule introuvable" else tostring(result)})`)
			else
				print(`[FullStick] pleine vitesse au stick branchée ({mode}, zone morte {deadZone})`)
			end
		end
	end)
end

return FullStickController
