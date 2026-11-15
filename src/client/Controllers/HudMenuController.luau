--!strict
-- HudMenuController (vague 59, a190, client) : le menu et la colonne de droite du nouveau HUD de Clément (liaison
-- L-183 `UI_HUD`, L-182 point 7 ; noms de la page Figma « 30 HUD, tapis, poursuite »). Tout est facultatif : tant
-- que Clément n'a pas construit le nouveau HUD dans Studio, rien de ce qui suit n'existe et l'ancien HUD marche
-- comme avant (ses boutons sont cherchés partout dans l'écran par leurs contrôleurs, menu ou pas).
--
--   - MenuButton (un dans LeftRail, un dans LeftRailTouch) ouvre et ferme MenuPanel (caché au départ : Visible).
--     Choisir un bouton du menu (IndexButton, RebirthButton, RewardsButton, InviteButton, SettingsButton :
--     branchés par leurs propres contrôleurs) referme le menu (Config/Hud.Menu.CloseOnPick).
--   - MenuAlert (pastille de MenuButton, Shared/AlertBadge) : allumée tant qu'une pastille « …Alert » rangée dans
--     MenuPanel est visible (IndexAlert, RebirthAlert, RewardsAlert… allumées par RailAlertController et
--     RewardsController, qui les trouvent où qu'elles soient).
--   - DisplayedButton ouvre « Mes objets exposés » (UI_Displayed) : DisplayedController (agent a191) fait tout,
--     Toggle() s'il existe, sinon Open() ; sans lui, rien (une ligne en Studio).
--   - Boutons en situation de Config/Boosts (SpeedBoostButton « x2 », SleepButton « zZz ») : cachés au départ,
--     montrés seulement quand leur règle (ShowWhen) est vraie ; Price.Amount = le prix Robux de la Config ;
--     Cooldown = la recharge restante (« 4:12 », attribut serveur CooldownAttribute), caché sans recharge. Aucun
--     achat : l'effet n'est pas codé (Ready = false) et Features.RobuxShop = false ; un clic montre « Soon ».
--     Visible n'est écrit que quand la règle change : un masquage par un autre contrôleur (poursuite) tient.
-- Seuls Visible, Text de Price.Amount et de Cooldown sont touchés (2.2, « Libre pour Ironix »), jamais un style ;
-- les animations d'ouverture (attribut Appear de Clément) sont jouées par le module d'UI commun quand Visible change.
-- HUD recréé (ResetOnSpawn) : rebranché, les connexions de l'ancien écran sont coupées.
--
-- API (client ; bancs, barre de commande en Studio) :
--   HudMenuController.IsMenuOpen() -> boolean
--   HudMenuController.SetMenuOpen(open)
--   HudMenuController.GetShown() -> { [string]: boolean }   bouton en situation (Config/Boosts.Key) → montré
--   HudMenuController.Refresh()                              recalcule les règles tout de suite

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Boosts = require(Config:WaitForChild("Boosts"))
local Features = require(Config:WaitForChild("Features"))
local HudConfig = require(Config:WaitForChild("Hud"))
local AlertBadge = require(Shared:WaitForChild("AlertBadge"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))

type Boost = Boosts.Boost
type ZoneApi = { GetZone: () -> number }
type NotifyApi = { Show: (message: string, kind: string?) -> () }

local SCREEN = "UI_HUD"
local MENU = HudConfig.Menu
local MACHINE_ATTRIBUTE = "TrainingMachine" -- TrainingService
local TREADMILL = "Treadmill"
local PRICE_PATH = "Price.Amount"
local COOLDOWN = "Cooldown"
local ALERT_SUFFIX = "Alert"
local IS_STUDIO = RunService:IsStudio()

local HudMenuController = {}

local localPlayer = Players.LocalPlayer
local zones: ZoneApi? = nil
local notify: NotifyApi? = nil
local connections: { RBXScriptConnection } = {}
local panels: { GuiObject } = {}
local menuAlerts: { GuiObject } = {}
local watchedAlerts: { GuiObject } = {}
local boostButtons: { [string]: { GuiButton } } = {}
local cooldownLabels: { [string]: { TextLabel } } = {}
local shown: { [string]: boolean } = {}
local cooldownTexts: { [string]: string } = {}
local menuOpen = false
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(message)
	end
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

local function buttonsNamed(root: Instance, name: string): { GuiButton }
	local list: { GuiButton } = {}
	for _, inst in Find.all(root, name) do
		if inst:IsA("GuiButton") then
			table.insert(list, inst :: GuiButton)
		end
	end
	return list
end

-- Menu ------------------------------------------------------------------------------------------

local function refreshMenuAlert()
	local on = false
	for _, badge in watchedAlerts do
		if badge.Parent ~= nil and badge.Visible then
			on = true
			break
		end
	end
	AlertBadge.SetAll(menuAlerts, on)
end

function HudMenuController.SetMenuOpen(open: boolean)
	menuOpen = open and #panels > 0
	for _, panel in panels do
		panel.Visible = menuOpen
	end
end

function HudMenuController.IsMenuOpen(): boolean
	return menuOpen
end

-- Boutons en situation ----------------------------------------------------------------------------

-- Heure serveur de fin de recharge de `boost`, ou nil.
local function cooldownEndsAt(boost: Boost): number?
	local name = boost.CooldownAttribute
	if name == nil then
		return nil
	end
	local holder: Instance = if boost.CooldownHolder == "Player" then localPlayer else Workspace
	local value = holder:GetAttribute(name)
	return if type(value) == "number" and value == value then value else nil
end

local function clockText(seconds: number): string
	local s = math.max(0, math.ceil(seconds - 1e-6))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function ruleHolds(boost: Boost): boolean
	if boost.ShowWhen == "OnTreadmill" then
		return localPlayer:GetAttribute(MACHINE_ATTRIBUTE) == TREADMILL
	elseif boost.ShowWhen == "InCorridor" then
		local api = zones
		if api == nil then
			return false
		end
		local ok, zone = pcall(api.GetZone)
		return ok and type(zone) == "number" and zone >= (boost.MinZone or 1)
	end
	return false
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	for _, boost in Boosts.List do
		local key = boost.Key
		local on = ruleHolds(boost)
		local buttons: { GuiButton } = boostButtons[key] or {}
		local labels: { TextLabel } = cooldownLabels[key] or {}
		if shown[key] ~= on then
			shown[key] = on
			for _, button in buttons do
				button.Visible = on
			end
		end
		local endsAt = cooldownEndsAt(boost)
		local text = if endsAt and endsAt > now then clockText(endsAt - now) else ""
		if cooldownTexts[key] ~= text then
			cooldownTexts[key] = text
			for _, label in labels do
				label.Text = text
				label.Visible = text ~= ""
			end
		end
	end
end

local function onBoost(boost: Boost)
	local endsAt = cooldownEndsAt(boost)
	local now = Workspace:GetServerTimeNow()
	local api = notify
	if endsAt and endsAt > now then
		if api then
			api.Show(`Ready in {clockText(endsAt - now)}`, "Alert")
		end
		return
	end
	-- Aucun achat tant que l'effet n'est pas codé côté serveur (Ready) et que la boutique Robux est coupée.
	if Features.RobuxShop and boost.Ready and boost.Id > 0 then
		game:GetService("MarketplaceService"):PromptProductPurchase(localPlayer, boost.Id)
		return
	end
	if api then
		api.Show(Boosts.SoonText)
	end
end

local function openDisplayed()
	local api = sibling("DisplayedController")
	local open = if api then (api.Toggle or api.Open) else nil
	if type(open) ~= "function" then
		warnOnce("displayed", "[HUD] DisplayedController.Toggle (ou Open) absent : DisplayedButton n'ouvre rien")
		return
	end
	local ok, err = pcall(open)
	if not ok then
		warnOnce("displayedError", `[HUD] DisplayedController : {err}`)
	end
end

-- Écran -------------------------------------------------------------------------------------------

local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(connections, signal:Connect(callback))
end

local function bind(gui: ScreenGui)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	menuOpen = false
	panels = {}
	watchedAlerts = {}
	for _, inst in Find.all(gui, MENU.Panel) do
		if inst:IsA("GuiObject") then
			local panel = inst :: GuiObject
			panel.Visible = false
			table.insert(panels, panel)
			for _, descendant in panel:GetDescendants() do
				if descendant:IsA("GuiButton") and MENU.CloseOnPick then
					connect((descendant :: GuiButton).Activated, function()
						HudMenuController.SetMenuOpen(false)
					end)
				elseif descendant:IsA("GuiObject") and descendant.Name ~= MENU.Alert and string.sub(descendant.Name, -#ALERT_SUFFIX) == ALERT_SUFFIX then
					table.insert(watchedAlerts, descendant :: GuiObject)
					connect(descendant:GetPropertyChangedSignal("Visible"), refreshMenuAlert)
				end
			end
		end
	end
	menuAlerts = AlertBadge.Find(gui, MENU.Alert)
	for _, button in buttonsNamed(gui, MENU.Button) do
		connect(button.Activated, function()
			HudMenuController.SetMenuOpen(not menuOpen)
		end)
	end
	refreshMenuAlert()

	for _, button in buttonsNamed(gui, "DisplayedButton") do
		connect(button.Activated, openDisplayed)
	end

	boostButtons = {}
	cooldownLabels = {}
	shown = {}
	cooldownTexts = {}
	for _, boost in Boosts.List do
		local buttons = buttonsNamed(gui, boost.Button)
		local labels: { TextLabel } = {}
		boostButtons[boost.Key] = buttons
		cooldownLabels[boost.Key] = labels
		for _, button in buttons do
			button.Visible = false -- montré par sa règle (refresh)
			local price = Find.path(button, PRICE_PATH)
			if price and price:IsA("TextLabel") then
				price.Text = Format.short(boost.Price)
			end
			local cooldown = Find.path(button, COOLDOWN)
			if cooldown and cooldown:IsA("TextLabel") then
				cooldown.Visible = false
				table.insert(labels, cooldown :: TextLabel)
			end
			connect(button.Activated, function()
				onBoost(boost)
			end)
		end
	end
	refresh()
end

function HudMenuController.GetShown(): { [string]: boolean }
	return table.clone(shown)
end

function HudMenuController.Refresh()
	refresh()
end

function HudMenuController.Start()
	zones = sibling("ZoneGateController")
	notify = sibling("NotifyController")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= HudConfig.Refresh then
			elapsed = 0
			refresh()
		end
	end)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
end

return HudMenuController
