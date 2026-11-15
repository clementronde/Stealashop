--!strict
-- HudMask (client, vague 59, a192 ; L-182 point 9, L-184 point 1) : masque le HUD pendant la poursuite et la
-- capture, puis le rend tel qu'il était. Module d'aide des contrôleurs (sous-dossier UI : le Loader ne le démarre pas).
--
-- Un masque (clé au choix de l'appelant) dit ce qui RESTE à l'écran ; tout le reste est masqué :
--   KeepScreens : écrans UI_* gardés entiers ;
--   Partial     : { [écran] = { noms } } écrans gardés, mais seulement ces éléments (cherchés parmi les
--                 descendants, Contract/Find), leurs ancêtres et leurs descendants ; le reste de l'écran est caché.
-- Plusieurs masques à la fois (poursuite, puis capture) : une chose reste à l'écran seulement si TOUS la gardent.
-- Jamais touchés : les écrans de Config/HeistFeel.NeverMask (messages du serveur, alertes, tutoriel, admin) et tout
-- ce qui n'est pas un ScreenGui « UI_* » du PlayerGui (billboards, écrans V0 du code).
-- Ce qui est touché, et rien d'autre : ScreenGui.Enabled d'un écran masqué, GuiObject.Visible d'un élément masqué.
-- Chaque valeur d'origine est gardée et remise quand plus aucun masque ne la masque. Un autre code qui rallume une
-- chose masquée pendant ce temps : elle est recachée tout de suite (et toutes les HeistFeel.MaskRefresh s), et
-- c'est sa valeur à lui (allumée) qui sera remise à la fin. Copie neuve d'un écran (ResetOnSpawn) : masquée à son
-- tour ; l'ancienne, partie, est oubliée.
--
-- API (client) :
--   HudMask.Push(key, spec)    spec = { KeepScreens = { string }?, Partial = { [string]: { string } }? }
--   HudMask.Pop(key)           retire ce masque (rien s'il n'y est pas) ; plus aucun masque : tout est rendu
--   HudMask.IsActive(key?) -> boolean
--   HudMask.Refresh()          revoit les écrans tout de suite (fait aussi à chaque Push et Pop)
--   HudMask.GetHidden() -> (écrans masqués, éléments masqués)   pour un banc

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeistFeel = require(Shared:WaitForChild("Config"):WaitForChild("HeistFeel"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

export type Spec = {
	KeepScreens: { string }?,
	Partial: { [string]: { string } }?,
}

type Saved = { value: boolean, connection: RBXScriptConnection? }

local SCREEN_PREFIX = "UI_"

local NEVER: { [string]: boolean } = {}
for _, name in HeistFeel.NeverMask do
	NEVER[name] = true
end

local HudMask = {}

local localPlayer = Players.LocalPlayer
local masks: { [string]: Spec } = {}
local order: { string } = {}
local screens: { [ScreenGui]: Saved } = {}
local objects: { [GuiObject]: Saved } = {}
local writing = false
local sinceRefresh = 0
local heartbeat: RBXScriptConnection? = nil

local function anyMask(): boolean
	return #order > 0
end

-- Écoute une propriété d'une chose masquée : rallumée par un autre code, elle est recachée et sa valeur gardée.
local function watch(instance: Instance, property: string, saved: Saved)
	local ok, signal = pcall(function()
		return instance:GetPropertyChangedSignal(property)
	end)
	if not ok or signal == nil then
		return
	end
	saved.connection = signal:Connect(function()
		if writing then
			return
		end
		local value = (instance :: any)[property]
		if value == true then
			saved.value = true
			writing = true
			;(instance :: any)[property] = false
			writing = false
		end
	end)
end

local function hideScreen(screen: ScreenGui)
	if screens[screen] == nil then
		local saved: Saved = { value = screen.Enabled, connection = nil }
		screens[screen] = saved
		watch(screen, "Enabled", saved)
	end
	if screen.Enabled then
		writing = true
		screen.Enabled = false
		writing = false
	end
end

local function hideObject(object: GuiObject)
	if objects[object] == nil then
		local saved: Saved = { value = object.Visible, connection = nil }
		objects[object] = saved
		watch(object, "Visible", saved)
	end
	if object.Visible then
		writing = true
		object.Visible = false
		writing = false
	end
end

local function restoreScreen(screen: ScreenGui)
	local saved = screens[screen]
	if saved == nil then
		return
	end
	screens[screen] = nil
	if saved.connection then
		saved.connection:Disconnect()
	end
	if screen.Parent ~= nil then
		writing = true
		screen.Enabled = saved.value
		writing = false
	end
end

local function restoreObject(object: GuiObject)
	local saved = objects[object]
	if saved == nil then
		return
	end
	objects[object] = nil
	if saved.connection then
		saved.connection:Disconnect()
	end
	if object.Parent ~= nil then
		writing = true
		object.Visible = saved.value
		writing = false
	end
end

local function restoreAll()
	for screen in screens do
		restoreScreen(screen)
	end
	for object in objects do
		restoreObject(object)
	end
end

-- Ce que les masques veulent pour cet écran : "Hide", "Keep" ou une liste de noms gardés (intersection).
local function wanted(name: string): ("Hide" | "Keep" | "Partial", { string }?)
	local lists: { { string } } = {}
	for _, key in order do
		local spec = masks[key]
		local keepList: { string } = spec.KeepScreens or {}
		local kept = table.find(keepList, name) ~= nil
		local partial = if spec.Partial then spec.Partial[name] else nil
		if partial then
			table.insert(lists, partial)
		elseif not kept then
			return "Hide", nil
		end
	end
	if #lists == 0 then
		return "Keep", nil
	end
	local result: { string } = {}
	for _, candidate in lists[1] do
		local inAll = true
		for i = 2, #lists do
			if table.find(lists[i], candidate) == nil then
				inAll = false
			end
		end
		if inAll then
			table.insert(result, candidate)
		end
	end
	return "Partial", result
end

-- Les éléments à cacher dans `screen` : tout ce qui n'est ni gardé, ni ancêtre, ni descendant d'un élément gardé.
local function toHide(screen: ScreenGui, keepNames: { string }): { [GuiObject]: boolean }
	local kept: { [Instance]: boolean } = {}
	local ancestors: { [Instance]: boolean } = {}
	for _, name in keepNames do
		local found = Find.path(screen, name)
		if found then
			kept[found] = true
			local parent = found.Parent
			while parent and parent ~= screen do
				ancestors[parent] = true
				parent = parent.Parent
			end
		end
	end
	local out: { [GuiObject]: boolean } = {}
	local function walk(container: Instance)
		for _, child in container:GetChildren() do
			if kept[child] then
				continue
			end
			if ancestors[child] or not child:IsA("GuiObject") then
				walk(child)
			else
				out[child :: GuiObject] = true
			end
		end
	end
	walk(screen)
	return out
end

local function apply()
	if not anyMask() then
		restoreAll()
		return
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local hideSet: { [GuiObject]: boolean } = {}
	if playerGui then
		for _, child in playerGui:GetChildren() do
			if not child:IsA("ScreenGui") or string.sub(child.Name, 1, #SCREEN_PREFIX) ~= SCREEN_PREFIX or NEVER[child.Name] then
				continue
			end
			local screen = child :: ScreenGui
			local mode, names = wanted(screen.Name)
			if mode == "Hide" then
				hideScreen(screen)
			else
				restoreScreen(screen)
				if mode == "Partial" and names then
					for object in toHide(screen, names) do
						hideSet[object] = true
					end
				end
			end
		end
	end
	for object in objects do
		if not hideSet[object] or object.Parent == nil then
			restoreObject(object)
		end
	end
	for object in hideSet do
		hideObject(object)
	end
	for screen in screens do
		if screen.Parent == nil then
			restoreScreen(screen)
		end
	end
end

local function step(dt: number)
	if not anyMask() then
		return
	end
	sinceRefresh += dt
	if sinceRefresh >= HeistFeel.MaskRefresh then
		sinceRefresh = 0
		apply()
	end
end

function HudMask.Refresh()
	sinceRefresh = 0
	apply()
end

function HudMask.Push(key: string, spec: Spec)
	if masks[key] == nil then
		table.insert(order, key)
	end
	masks[key] = spec
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
	HudMask.Refresh()
end

function HudMask.Pop(key: string)
	if masks[key] == nil then
		return
	end
	masks[key] = nil
	local index = table.find(order, key)
	if index then
		table.remove(order, index)
	end
	HudMask.Refresh()
end

function HudMask.IsActive(key: string?): boolean
	if key then
		return masks[key] ~= nil
	end
	return anyMask()
end

function HudMask.GetHidden(): ({ ScreenGui }, { GuiObject })
	local s: { ScreenGui } = {}
	for screen in screens do
		table.insert(s, screen)
	end
	local o: { GuiObject } = {}
	for object in objects do
		table.insert(o, object)
	end
	return s, o
end

return HudMask
