--!strict
-- DropController (vague 33, Cantin 2026-11-13, agent a113, client) : lâcher ce qu'on porte au-dessus de la tête.
--
-- Pendant le portage seulement (attribut Carrying du joueur local, posé par CarryService) :
--   - touche G sur PC (V0 proposé, absent du doc ; ContextActionService, action DROP_ACTION) ;
--   - sur téléphone : le bouton UI_HUD.DropButton de Clément s'il existe (montré pendant le portage, caché
--     sinon ; le code ne touche qu'à son Visible) ; sinon le bouton tactile de ContextActionService, titre
--     « Drop », TOUCH_SIZE px de côté (V0), créé par Roblox dans sa propre interface tactile, rien dans l'UI
--     de Clément.
-- Un appui envoie DropCarried (au plus un toutes les SEND_INTERVAL s) ; le serveur décide de tout
-- (DropService : portage, personnage vivant, pas étourdi par une capture ni par la batte).
--
-- API (client) : aucune.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

-- Même nom que CarryService.
local CARRYING_ATTRIBUTE = "Carrying"
-- Bouton de Clément (nom proposé, pas encore au contrat 2.2).
local HUD = "UI_HUD"
local HUD_BUTTON = "DropButton"
local DROP_ACTION = "DropCarried"
-- V0 proposé, absent du doc : touche, titre et taille du bouton tactile de repli.
local DROP_KEY = Enum.KeyCode.G
local TOUCH_TITLE = "Drop"
local TOUCH_SIZE = 70 -- px, au moins 44 (règle UI du projet)
-- V0 proposé, absent du doc : deux envois au plus par seconde (le débit de Net est de 2).
local SEND_INTERVAL = 0.5

local DropController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local hudButton: GuiButton? = nil
local bound = false
local boundWithTouch = false
local lastSentAt = -math.huge

local function isCarrying(): boolean
	return localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
end

local function send()
	local now = os.clock()
	if now - lastSentAt < SEND_INTERVAL or not isCarrying() or net == nil then
		return
	end
	lastSentAt = now
	net.Client.DropCarried:Fire()
end

local function onAction(_action: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		send()
	end
	return Enum.ContextActionResult.Sink
end

-- Lie ou délie la touche (et le bouton tactile de repli) selon le portage et la présence du bouton de Clément.
local function refresh()
	local carrying = isCarrying()
	local wantTouch = hudButton == nil
	if bound and (not carrying or boundWithTouch ~= wantTouch) then
		ContextActionService:UnbindAction(DROP_ACTION)
		bound = false
	end
	if carrying and not bound then
		ContextActionService:BindAction(DROP_ACTION, onAction, wantTouch, DROP_KEY)
		bound = true
		boundWithTouch = wantTouch
		if wantTouch then
			ContextActionService:SetTitle(DROP_ACTION, TOUCH_TITLE)
			local touch = ContextActionService:GetButton(DROP_ACTION)
			if touch then
				touch.Size = UDim2.fromOffset(TOUCH_SIZE, TOUCH_SIZE)
			end
		end
	end
	local button = hudButton
	if button then
		button.Visible = carrying
	end
end

local function bindHud(gui: Instance)
	local found = Find.path(gui, HUD_BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		return -- pas encore livré : bouton tactile de repli
	end
	local button = found :: GuiButton
	if hudButton == button then
		return
	end
	hudButton = button
	button.Activated:Connect(send)
	button.Destroying:Connect(function()
		if hudButton == button then
			hudButton = nil
			refresh()
		end
	end)
	refresh()
end

function DropController.Start()
	local ok, result = pcall(function()
		return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	end)
	if ok then
		net = result
	else
		warn(`[DropController] Net indisponible : {result}`)
	end
	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refresh)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child:IsA("ScreenGui") and child.Name == HUD then
			bindHud(child)
		end
	end)
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end
	refresh()
end

return DropController
