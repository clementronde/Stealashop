--!strict
-- GamepadController (a419, client ; demande de Cantin du 23/11 : jouable à la manette ; Config/Gamepad, Features.Gamepad,
-- aide Shared/Gamepad) : les menus à la manette. Sans Features.Gamepad, rien n'est branché.
--
-- Rôle :
--   - menu = ScreenGui allumé de PlayerGui qui porte l'attribut ScreenGroup (Config/Gamepad.MenuAttribute : le groupe
--     « Menu » de Clément, UI_Displayed compris, posé par son contrôleur), sauf s'il se ferme (Motion.GetState) ; s'il y
--     en a plusieurs, le plus haut (DisplayOrder). Sous-fenêtre : son premier descendant montré nommé dans Modals
--     (Confirm d'UI_Displayed, la confirmation YES / NO de la vente) ;
--   - à la manette seulement (Shared/Gamepad.IsActive), toutes les Tick s : si GuiService.SelectedObject n'est pas un objet
--     montré de la sous-fenêtre (sinon du menu), la sélection y revient : sur le dernier bouton choisi dans ce menu s'il
--     est encore utilisable, sinon sur son premier bouton utile (GuiButton montré, Selectable, hors Skip, le plus haut
--     puis le plus à gauche). Roblox calcule ensuite la navigation par la géométrie : aucun NextSelection* posé ici.
--     Aucun menu : une sélection restée dans un menu (fermé ou qui se ferme) ou cachée est rendue (nil), le perso
--     remarche ; une sélection ailleurs (le HUD, par le bouton Select de Roblox) est laissée. Retour au clavier, à la
--     souris ou au doigt : la sélection d'un menu est rendue ;
--   - ButtonB (ContextActionService, priorité Medium ; le receleur prend le sien plus haut, PawnShopController) : une
--     sous-fenêtre montrée → son annulation (UI_Displayed : DisplayedController.CancelSell, comme NoButton) ; sinon le
--     menu se ferme comme par sa croix (Motion.Dismiss : la fermeture de son contrôleur) et la sélection est rendue.
--     Aucun menu, ou un menu de KeepOnBack (UI_Offline, sans croix) : l'appui passe.
-- Seul est touché : GuiService.SelectedObject. Aucun visuel, rien de créé dans l'UI.
--
-- API (client ; bancs, barre de commande) :
--   GamepadController.Update()                 revoit la sélection tout de suite (comme à chaque Tick)
--   GamepadController.Back() -> boolean        comme ButtonB ; true si une confirmation ou un menu a été fermé
--   GamepadController.GetState() -> { Active: boolean, Menu: string?, Selected: string? }

local Players = game:GetService("Players")
-- GuiService et ContextActionService : pris au démarrage, et seulement avec Features.Gamepad (voir Start).
local GuiService: GuiService = nil :: any
local ContextActionService: ContextActionService = nil :: any

local Gamepad = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Gamepad"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

local BACK_ACTION = "GamepadBack"
-- Annulation de la sous-fenêtre d'un menu : contrôleur et fonction de son API (comme son bouton NO).
local CANCELS: { [string]: { module: string, fn: string } } = {
	UI_Displayed = { module = "DisplayedController", fn = "CancelSell" },
}

local GamepadController = {}

local localPlayer = Players.LocalPlayer
local settings: any = nil -- Config/Gamepad, lu au démarrage
local remembered: { [Instance]: GuiObject } = {} -- menu → dernier bouton choisi (vidé quand le menu change)
local lastMenu: ScreenGui? = nil
local siblings: { [string]: any } = {}

local function sibling(name: string): any
	local found = siblings[name]
	if found == nil then
		local module = script.Parent:FindFirstChild(name)
		local ok, result = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
		end
		found = if ok and type(result) == "table" then result else false
		siblings[name] = found
	end
	return if found then found else nil
end

-- Montré : lui et ses parents visibles, jusqu'à son écran allumé.
local function shown(object: Instance): boolean
	local current: Instance? = object
	while current do
		if current:IsA("LayerCollector") then
			return (current :: LayerCollector).Enabled
		elseif current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		current = current.Parent
	end
	return false
end

local function isMenu(gui: Instance): boolean
	local group = gui:GetAttribute(settings.MenuAttribute)
	return gui:IsA("ScreenGui") and type(group) == "string" and group ~= ""
end

local function inMenu(object: Instance): boolean
	local gui = object:FindFirstAncestorWhichIsA("ScreenGui")
	return gui ~= nil and isMenu(gui)
end

local function topMenu(): ScreenGui?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local best: ScreenGui? = nil
	for _, child in playerGui:GetChildren() do
		if isMenu(child) then
			local gui = child :: ScreenGui
			local top = best
			if gui.Enabled and Motion.GetState(gui) ~= "Closing" and (top == nil or gui.DisplayOrder >= top.DisplayOrder) then
				best = gui
			end
		end
	end
	return best
end

local function modalOf(gui: ScreenGui): GuiObject?
	for _, name in settings.Modals do
		local found = gui:FindFirstChild(name, true)
		if found and found:IsA("GuiObject") and shown(found) then
			return found :: GuiObject
		end
	end
	return nil
end

local function usable(object: Instance): boolean
	if not object:IsA("GuiButton") then
		return false
	end
	local button = object :: GuiButton
	if not button.Selectable or (button :: any).Interactable == false or table.find(settings.Skip, button.Name) ~= nil then
		return false
	end
	local size = button.AbsoluteSize
	return size.X > 0 and size.Y > 0 and shown(button)
end

-- Le premier bouton utile : le plus haut, puis le plus à gauche (même ligne à RowTolerance px près).
local function firstIn(layer: Instance): GuiButton?
	local tolerance = settings.RowTolerance
	local best: GuiButton? = nil
	local bestX, bestY = 0, 0
	for _, descendant in layer:GetDescendants() do
		if usable(descendant) then
			local point = (descendant :: GuiButton).AbsolutePosition
			if best == nil or point.Y < bestY - tolerance or (math.abs(point.Y - bestY) <= tolerance and point.X < bestX) then
				best, bestX, bestY = descendant :: GuiButton, point.X, point.Y
			end
		end
	end
	return best
end

local function select(object: GuiObject?)
	if GuiService.SelectedObject ~= object then
		GuiService.SelectedObject = object
	end
end

-- La sélection d'un menu rendue (retour au clavier, à la souris ou au doigt).
local function release()
	local selected = GuiService.SelectedObject
	if selected and inMenu(selected) then
		select(nil)
	end
end

local function update()
	if settings == nil or not Gamepad.IsActive() then
		return
	end
	local selected = GuiService.SelectedObject
	local menu = topMenu()
	if menu ~= lastMenu then
		lastMenu = menu
		table.clear(remembered) -- menu ouvert (ou changé) : son premier bouton
	end
	if menu == nil then
		if selected and (inMenu(selected) or not shown(selected)) then
			select(nil) -- menu fermé : le perso remarche
		end
		return
	end
	local layer: Instance = modalOf(menu) or menu
	if selected and selected:IsDescendantOf(layer) and shown(selected) then
		if layer == menu then
			remembered[menu] = selected
		end
		return
	end
	local last = if layer == menu then remembered[menu] else nil
	local target: GuiObject? = if last and last:IsDescendantOf(menu) and usable(last) then last else firstIn(layer)
	if target then
		select(target)
	end
end

local function back(): boolean
	if settings == nil then
		return false
	end
	local menu = topMenu()
	if menu == nil or table.find(settings.KeepOnBack, menu.Name) ~= nil then
		return false
	end
	if modalOf(menu) then
		local cancel = CANCELS[menu.Name]
		local api = if cancel then sibling(cancel.module) else nil
		local fn = if api and cancel then api[cancel.fn] else nil
		if type(fn) == "function" then
			fn()
			return true
		end
		-- Sans annulation connue : le menu se ferme (sa fermeture cache la sous-fenêtre).
	end
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(menu) then
		select(nil)
	end
	Motion.Dismiss(menu)
	return true
end

local function onBack(_action: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	return if back() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end

function GamepadController.Update()
	update()
end

function GamepadController.Back(): boolean
	return back()
end

function GamepadController.GetState(): { Active: boolean, Menu: string?, Selected: string? }
	local menu = if settings then topMenu() else nil
	local selected = if settings then GuiService.SelectedObject else nil
	return {
		Active = Gamepad.IsActive(),
		Menu = if menu then menu.Name else nil,
		Selected = if selected then selected:GetFullName() else nil,
	}
end

function GamepadController.Start()
	local wanted = Gamepad.Config()
	if wanted == nil then
		return -- Features.Gamepad coupé (ou Config/Gamepad absent) : rien de branché
	end
	local ok, message = pcall(function()
		GuiService = game:GetService("GuiService")
		ContextActionService = game:GetService("ContextActionService")
		ContextActionService:BindActionAtPriority(BACK_ACTION, onBack, false, Enum.ContextActionPriority.Medium.Value, wanted.Back)
	end)
	if not ok then
		warn(`[Gamepad] menus à la manette non branchés : {message}`)
		return
	end
	settings = wanted
	Gamepad.OnChanged(function(active: boolean)
		if active then
			update()
		else
			release()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(settings.Tick)
			local ok, message = pcall(function()
				update()
			end)
			if not ok then
				warn(`[Gamepad] sélection du menu : {message}`)
				task.wait(5) -- pas une ligne par Tick
			end
		end
	end)
end

return GamepadController
