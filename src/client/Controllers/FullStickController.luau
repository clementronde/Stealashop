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
-- a450 (Play de fusion101 : « non branchée ») : où est le PlayerModule. Avant : copié dans Player.PlayerScripts, lu par
-- PlayerModule:GetControls(). Depuis le PlayerModule « InputActionSystem » de Roblox (celui de la place DEV) : il reste
-- sous StarterPlayer (StarterPlayer.PlayerModule, jamais copié dans PlayerScripts), GetControls n'existe plus et le
-- ControlModule se lit par require(StarterPlayer.PlayerModule.ControlModule) (même instance que celle de Roblox : un
-- module n'est chargé qu'une fois par client). Les deux places sont cherchées, MODULE_WAIT s au plus, sans erreur s'il
-- manque. La copie de StarterPlayerScripts n'est jamais chargée d'ici (ce serait un second ControlModule).
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
local MODULE_WAIT = 30 -- s : attente, au plus, du PlayerModule de Roblox (PlayerScripts ou StarterPlayer)
local MODULE_POLL = 0.25 -- s entre deux recherches

local IS_STUDIO = RunService:IsStudio()

local FullStickController = {}

local mode = "Off"
local foundAt = "" -- a450 : où le PlayerModule a été trouvé (sortie Studio)
local failure = "PlayerModule ou ControlModule introuvable" -- a450 : pourquoi rien n'est branché

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

-- a450 : le PlayerModule de Roblox, dans Player.PlayerScripts (avant) ou sous StarterPlayer (InputActionSystem) ;
-- cherché toutes les MODULE_POLL s, MODULE_WAIT s au plus. Rend aussi true quand c'est celui de StarterPlayer.
local function findModule(player: Player): (ModuleScript?, boolean)
	local starter = game:GetService("StarterPlayer")
	local deadline = os.clock() + MODULE_WAIT
	while true do
		local scripts = player:FindFirstChild("PlayerScripts")
		local copied = if scripts then scripts:FindFirstChild("PlayerModule") else nil
		if copied and copied:IsA("ModuleScript") then
			return copied, false
		end
		local kept = starter:FindFirstChild("PlayerModule")
		if kept and kept:IsA("ModuleScript") then
			return kept, true
		end
		if os.clock() >= deadline then
			return nil, false
		end
		task.wait(MODULE_POLL)
	end
end

local function byGetControls(module: ModuleScript): any
	local ok, playerModule = pcall(require :: any, module)
	if ok and type(playerModule) == "table" and type(playerModule.GetControls) == "function" then
		local okControls, controls = pcall(playerModule.GetControls, playerModule)
		return if okControls and type(controls) == "table" then controls else nil
	end
	return nil
end

local function byChild(module: ModuleScript): any
	local child = module:FindFirstChild("ControlModule")
	if child and child:IsA("ModuleScript") then
		local ok, controls = pcall(require :: any, child)
		return if ok and type(controls) == "table" then controls else nil
	end
	return nil
end

local function install(deadZone: number): string
	local player = Players.LocalPlayer
	local module, kept = findModule(player)
	if module == nil then
		failure = `PlayerModule introuvable après {MODULE_WAIT} s, ni dans PlayerScripts ni sous StarterPlayer`
		return "Failed"
	end
	foundAt = module:GetFullName()
	-- Sous StarterPlayer : le ControlModule d'abord (GetControls n'existe plus) ; dans PlayerScripts : l'API publique.
	local controls: any = if kept then byChild(module) or byGetControls(module) else byGetControls(module) or byChild(module)
	if type(controls) ~= "table" then
		failure = `ControlModule illisible dans {foundAt}`
		return "Failed"
	end
	failure = `ni moveFunction ni GetMoveVector dans le ControlModule de {foundAt}`
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
				warn(`[FullStick] pleine vitesse au stick non branchée ({if ok then failure else tostring(result)})`)
			else
				print(`[FullStick] pleine vitesse au stick branchée ({mode}, zone morte {deadZone}) ; PlayerModule : {foundAt}`)
			end
		end
	end)
end

return FullStickController
