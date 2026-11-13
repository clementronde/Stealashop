--!strict
-- RailAlertController (vague 34, L-127 point 3, client) : les pastilles « ! » des boutons de la colonne de
-- gauche du HUD, posées cachées par Clément dans UI_HUD.LeftRail (PC) et LeftRailTouch (téléphone) ; les
-- deux exemplaires de chaque pastille suivent la même règle. Allumage et battement : UI/AlertBadge (Visible,
-- UIScale Pulse 1 → 1,15 → 1 en 0,8 s). Une pastille s'éteint quand l'action est faite, pas à l'ouverture
-- de l'écran. Rien n'est envoyé au serveur : tout est lu sur ce qu'il publie.
--
--   IndexButton.IndexAlert         une prime de zone de l'Index à réclamer : zone complète (attribut
--                                  IndexDiscovered) pas encore réclamée (IndexClaimed) ; Config/Index,
--                                  IndexService. Éteinte si Features.Index est coupé.
--   InventoryButton.InventoryAlert un objet à poser ou prêt à exposer :
--                                    - un objet de l'inventaire sous antivol, à poser au sol de sa boutique
--                                      (champ AntiTheft de l'attribut InventoryState, Shared/InventoryState) ;
--                                    - un colis de l'inventaire pas encore posé, ou posé et prêt à ouvrir
--                                      (ReadyAt passé ; ancien déroulé, Features.ShelfOpen à false) ;
--                                    - un objet à lui posé au sol dont l'antivol est fini (« UNLOCKED! ») :
--                                      Model taggé FloorItem, OwnerUserId = son UserId, UnlockAt passé (heure
--                                      serveur ; UnboxService), à reprendre pour l'exposer.
--   RebirthButton.RebirthAlert     une renaissance possible : la renaissance n'est pas codée (DEV-120,
--                                  Features.Rebirth à false ; UI_Rebirth est un aperçu sans confirmation) et
--                                  le client ne voit ni l'inventaire complet ni le coffre-fort : toujours
--                                  éteinte pour l'instant.
--   SkillTreeButton.SkillTreeAlert une amélioration achetable : une compétence ouverte (OpensWhen), niveau
--                                  suivant codé (Coded), avec un prix, pas au maximum, et l'argent du joueur
--                                  (attribut Cash) au moins égal à ce prix. Même règle que l'écran
--                                  (SkillTreeController : prix blanc, BuyButton) et que SkillTreeService.
-- Recalcul : à chaque changement d'un attribut du joueur ou d'un tag FloorItem (une fois par image au plus),
-- et toutes les REFRESH s (fin d'un antivol ou d'une attente de colis). HUD recréé (ResetOnSpawn) : rebranché.
--
-- API (client ; bancs, barre de commande en Studio) :
--   RailAlertController.GetState() -> { Index: boolean, Inventory: boolean, Rebirth: boolean, SkillTree: boolean }
--   RailAlertController.Refresh()   recalcule tout de suite

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Index = require(Config:WaitForChild("Index"))
local SkillTree = require(Config:WaitForChild("SkillTree"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local AlertBadge = require(Shared:WaitForChild("AlertBadge"))

type AlertState = { Index: boolean, Inventory: boolean, Rebirth: boolean, SkillTree: boolean }

local HUD = "UI_HUD"
-- Pastilles de Clément (L-127 point 3), une par bouton de la colonne, dans LeftRail et LeftRailTouch.
local INDEX_ALERT = "IndexAlert"
local INVENTORY_ALERT = "InventoryAlert"
local REBIRTH_ALERT = "RebirthAlert"
local SKILL_TREE_ALERT = "SkillTreeAlert"
local CASH_ATTRIBUTE = "Cash" -- DataService
-- Objet sous antivol posé au sol (UnboxService, vague 31).
local FLOOR_ITEM_TAG = "FloorItem"
local OWNER_ATTRIBUTE = "OwnerUserId"
local UNLOCK_AT_ATTRIBUTE = "UnlockAt"
-- V0 proposé, absent du doc : cadence (s) du recalcul de ce qui dépend de l'heure (antivol, colis).
local REFRESH = 0.5

local RailAlertController = {}

local localPlayer = Players.LocalPlayer
local hud: ScreenGui? = nil
local badges: { [string]: { GuiObject } } = {}
local state: AlertState = { Index = false, Inventory = false, Rebirth = false, SkillTree = false }
local dirty = true

------------------------------------------------------------------------------
-- Règles
------------------------------------------------------------------------------

local function indexPending(): boolean
	if not Features.Index then
		return false
	end
	local discovered = Index.Decode(localPlayer:GetAttribute(Index.Attribute))
	local claimed = Index.DecodeZones(localPlayer:GetAttribute(Index.ClaimedAttribute))
	return #Index.ClaimableZones(discovered, claimed) > 0
end

local function inventoryPending(now: number): boolean
	local inventory = InventoryState.Decode(localPlayer:GetAttribute(InventoryState.Attribute))
	for _, item in inventory.Items do
		if item.AntiTheft == true and item.Slot == nil then
			return true -- à poser au sol de sa boutique
		end
	end
	for _, box in inventory.Boxes do
		local readyAt = box.ReadyAt
		if not box.Placed or (readyAt ~= nil and readyAt <= now) then
			return true -- colis à poser, ou posé et prêt à ouvrir
		end
	end
	for _, model in CollectionService:GetTagged(FLOOR_ITEM_TAG) do
		if model:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId then
			local unlockAt = model:GetAttribute(UNLOCK_AT_ATTRIBUTE)
			if type(unlockAt) == "number" and unlockAt <= now then
				return true -- antivol fini : à reprendre et exposer
			end
		end
	end
	return false
end

local function levelOf(id: string): number
	local value = localPlayer:GetAttribute(SkillTree.AttributePrefix .. id)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function skillTreePending(): boolean
	local cash = localPlayer:GetAttribute(CASH_ATTRIBUTE)
	if type(cash) ~= "number" or cash ~= cash then
		return false -- profil pas encore chargé
	end
	for _, skill in SkillTree.List do
		local opens = skill.OpensWhen
		if opens == nil or levelOf(opens.Id) >= opens.Level then
			local level = levelOf(skill.Id)
			local price = skill.Prices[level + 1]
			if level < skill.MaxLevel and level + 1 <= skill.Coded and price ~= nil and cash >= price then
				return true
			end
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Pastilles
------------------------------------------------------------------------------

local function bind(gui: ScreenGui)
	hud = gui
	badges = {}
	for _, name in { INDEX_ALERT, INVENTORY_ALERT, REBIRTH_ALERT, SKILL_TREE_ALERT } do
		badges[name] = AlertBadge.Find(gui, name)
	end
	dirty = true
end

local function refresh()
	dirty = false
	local now = Workspace:GetServerTimeNow()
	state = {
		Index = indexPending(),
		Inventory = inventoryPending(now),
		Rebirth = false, -- renaissance pas codée (DEV-120) : voir l'en-tête
		SkillTree = skillTreePending(),
	}
	local gui = hud
	if gui == nil or gui.Parent == nil then
		return
	end
	local function set(name: string, on: boolean)
		local list = badges[name]
		if list then
			AlertBadge.SetAll(list, on)
		end
	end
	set(INDEX_ALERT, state.Index)
	set(INVENTORY_ALERT, state.Inventory)
	set(REBIRTH_ALERT, state.Rebirth)
	set(SKILL_TREE_ALERT, state.SkillTree)
end

function RailAlertController.Refresh()
	refresh()
end

function RailAlertController.GetState(): AlertState
	return table.clone(state)
end

function RailAlertController.Start()
	localPlayer.AttributeChanged:Connect(function()
		dirty = true
	end)
	CollectionService:GetInstanceAddedSignal(FLOOR_ITEM_TAG):Connect(function()
		dirty = true
	end)
	CollectionService:GetInstanceRemovedSignal(FLOOR_ITEM_TAG):Connect(function()
		dirty = true
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if dirty or elapsed >= REFRESH then
			elapsed = 0
			refresh()
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == HUD and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		end
	end)
	local existing = playerGui:FindFirstChild(HUD)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
	refresh()
end

return RailAlertController
