--!strict
-- InviteController (L-057, client) : le bouton InviteButton de l'écran UI_HUD de Clément (dans son
-- cadre SocialRow, en bas à droite) ouvre l'invitation d'amis de Roblox. Aucun bonus : ses valeurs
-- ne sont pas fixées (L-057). RewardsButton n'est pas branché.
--
-- Un clic : SocialService:CanSendGameInviteAsync(joueur), puis, si Roblox le permet,
-- SocialService:PromptGameInvite(joueur). Les deux dans des pcall, dans une tâche à part : l'écran
-- ne se bloque jamais pendant que Roblox répond. Un clic pendant une demande en cours est ignoré.
-- Pas permis (réglages de confidentialité du compte, par exemple) ou erreur de Roblox : rien ne
-- s'ouvre, une ligne dans la sortie en Studio, et le joueur peut réessayer.
--
-- L'élément est cherché par son nom parmi les descendants de l'écran (Contract/Find) : SocialRow est
-- un cadre décoratif. Seul Activated est écouté (2.2, « Libre pour Ironix ») : ni texte, ni
-- visibilité, ni style. Roblox copie UI_HUD de StarterGui dans PlayerGui ; un écran recréé
-- (ResetOnSpawn) est rebranché. Rien n'est envoyé au serveur. API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Find = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Contract"):WaitForChild("Find"))

local SCREEN = "UI_HUD" -- contrat 2.2
local BUTTON = "InviteButton" -- nom de Clément (L-057), au contrat UI

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local InviteController = {}

local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local pending = false -- une demande à Roblox est en cours
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		warn(`[InviteController] {message}`)
	end
end

local function canInvite(): boolean
	return SocialService:CanSendGameInviteAsync(localPlayer)
end

local function prompt(): boolean
	SocialService:PromptGameInvite(localPlayer)
	return true
end

local function invite()
	if pending then
		return
	end
	pending = true
	local ok, allowed = pcall(canInvite)
	if not ok then
		if IS_STUDIO then
			warn(`[InviteController] CanSendGameInviteAsync : {allowed}`)
		end
	elseif allowed ~= true then
		if IS_STUDIO then
			print("[InviteController] Roblox ne permet pas d'inviter depuis ce compte : rien ne s'ouvre")
		end
	else
		local shown, err = pcall(prompt)
		if not shown and IS_STUDIO then
			warn(`[InviteController] PromptGameInvite : {err}`)
		end
	end
	pending = false
end

local function bind(gui: Instance)
	if bound[gui] then
		return
	end
	local found = Find.path(gui, BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		local problem = if found then `n'est pas un bouton ({found.ClassName})` else "introuvable"
		sayOnce(`button:{problem}`, `{SCREEN}.{BUTTON} {problem} : le bouton Invite ne fait rien (L-057)`)
		return
	end
	local button = found :: GuiButton
	bound[gui] = true
	button.Activated:Connect(function()
		task.spawn(invite)
	end)
end

function InviteController.Start()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing)
	end
end

return InviteController
