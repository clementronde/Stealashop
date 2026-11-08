--!strict
-- ShopPadController (L-071, client) : les plaques ShopPad des comptoirs du hub. Une BasePart nommée
-- ShopPad dans un comptoir taggé WeaponShop, AuraShop ou RobuxShop (nom proposé par Clément le
-- 2026-11-08 ; enfant facultatif de ces comptoirs au contrat 10.4, Contract/Models) : quand le joueur
-- local monte dessus, l'écran du comptoir s'ouvre (UI_WeaponShop, UI_AuraShop, ou UI_RobuxShop, en
-- vitrine tant que la boutique Robux est coupée), par l'API Open du contrôleur de la boutique.
--
-- Règles :
--   - une seule ouverture par montée : rester sur la plaque ne rouvre pas un écran qu'on a fermé ; il
--     faut en descendre puis y remonter (comme l'encaissement au CashPad, DisplayService) ;
--   - « sur la plaque » : le HumanoidRootPart du joueur dans le même volume que celui du CashPad
--     (DisplayService) : l'emprise de la plaque élargie de PAD_MARGIN, de PAD_BELOW sous sa face du
--     haut à PAD_ABOVE au-dessus. La face du haut est celle de l'axe de la plaque le plus proche de la
--     verticale : une plaque posée à plat marche quelle que soit sa rotation (cylindre couché compris) ;
--   - l'écran se ferme ensuite selon les règles de sa boutique : à distance de la plaque pour les
--     armes et les auras, jamais pour la boutique Robux ; l'invite « Shop » des comptoirs reste ;
--   - comptoirs rangés dans _INBOX_CLEMENT ignorés ; comptoir sans plaque : rien (le ContractChecker
--     le signale) ; plaque qui arrive ou repart avec le streaming : suivie.
-- Côté client seulement : ouvrir un écran n'a rien de sensible, le serveur revérifie chaque achat.
--
-- API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Find = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Contract"):WaitForChild("Find"))

-- Ce que ce contrôleur utilise des contrôleurs de boutique (WeaponShopController, AuraShopController,
-- RobuxShopController).
type ShopApi = {
	Open: (anchor: BasePart) -> (),
}

-- Un comptoir suivi.
type Counter = {
	inst: Instance,
	shop: ShopApi,
	pad: BasePart?, -- nil : pas (encore) de plaque, ou sortie du streaming
	on: boolean, -- le joueur était sur la plaque à l'image d'avant
	connections: { RBXScriptConnection },
}

-- Contrat (2.1 et 10.4, Contract/Tags et Contract/Models).
local PAD_NAME = "ShopPad"
local SHOPS: { { Tag: string, Controller: string } } = {
	{ Tag = "WeaponShop", Controller = "WeaponShopController" },
	{ Tag = "AuraShop", Controller = "AuraShopController" },
	{ Tag = "RobuxShop", Controller = "RobuxShopController" },
}
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées
local ROOT_PART = "HumanoidRootPart"

-- V0 proposé, absent du doc : volume de la plaque, le même que celui du CashPad de DisplayService
-- (le HumanoidRootPart d'un R15 debout est à environ 3 studs du sol).
local PAD_MARGIN = 0.5
local PAD_BELOW = 1
local PAD_ABOVE = 6

local IS_STUDIO = RunService:IsStudio()

local ShopPadController = {}

local localPlayer = Players.LocalPlayer
local counters: { [Instance]: Counter } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(message)
	end
end

-- Contrôleur de boutique voisin (même dossier) avec son API Open, ou nil.
local function sibling(name: string): ShopApi?
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		warnOnce(name, `[ShopPad] {name} absent : ses plaques ShopPad n'ouvrent rien`)
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type(result.Open) == "function" then
		return result :: any
	end
	local why = if ok then "pas d'API Open" else `require impossible ({result})`
	warnOnce(name, `[ShopPad] {name} : {why} ; ses plaques ShopPad n'ouvrent rien`)
	return nil
end

local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
end

-- La plaque du comptoir (le premier descendant nommé ShopPad, s'il est une pièce), ou nil.
local function padOf(inst: Instance): BasePart?
	local found = Find.path(inst, PAD_NAME)
	if found == nil then
		return nil
	end
	if not found:IsA("BasePart") then
		warnOnce(found:GetFullName(), `[ShopPad] {found:GetFullName()} n'est pas une pièce (BasePart) : ignorée`)
		return nil
	end
	return found :: BasePart
end

-- Composante `axis` (1 = X, 2 = Y, 3 = Z) d'un Vector3.
local function component(v: Vector3, axis: number): number
	return if axis == 1 then v.X elseif axis == 2 then v.Y else v.Z
end

-- `position` (HumanoidRootPart) est-elle au-dessus de la plaque, dans son volume ?
local function isOn(pad: BasePart, position: Vector3): boolean
	local cframe = pad.CFrame
	local p = cframe:PointToObjectSpace(position)
	local half = pad.Size / 2
	-- Composante verticale de chaque axe de la plaque : le plus vertical porte la face du haut.
	local vertical = { cframe.XVector.Y, cframe.YVector.Y, cframe.ZVector.Y }
	local up = 1
	for axis = 2, 3 do
		if math.abs(vertical[axis]) > math.abs(vertical[up]) then
			up = axis
		end
	end
	local height = component(p, up) * (if vertical[up] < 0 then -1 else 1)
	local top = component(half, up)
	if height < top - PAD_BELOW or height > top + PAD_ABOVE then
		return false
	end
	for axis = 1, 3 do
		if axis ~= up and math.abs(component(p, axis)) > component(half, axis) + PAD_MARGIN then
			return false
		end
	end
	return true
end

local function rootPosition(): Vector3?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild(ROOT_PART) else nil
	if root and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

local function attach(shop: ShopApi, inst: Instance)
	if counters[inst] or not inMap(inst) then
		return
	end
	local counter: Counter = { inst = inst, shop = shop, pad = padOf(inst), on = false, connections = {} }
	counters[inst] = counter
	-- Plaque posée plus tard, ou revenue avec le streaming.
	table.insert(counter.connections, inst.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == PAD_NAME and counter.pad == nil then
			counter.pad = padOf(inst)
		end
	end))
end

local function detach(inst: Instance)
	local counter = counters[inst]
	if counter == nil then
		return
	end
	counters[inst] = nil
	for _, connection in counter.connections do
		connection:Disconnect()
	end
end

local function onHeartbeat()
	local position = rootPosition()
	for _, counter in counters do
		local pad = counter.pad
		if pad and not pad:IsDescendantOf(counter.inst) then
			pad = nil -- retirée, ou sortie du streaming : DescendantAdded la reprendra
			counter.pad = nil
		end
		local on = pad ~= nil and position ~= nil and isOn(pad, position)
		local was = counter.on
		counter.on = on
		if on and not was then
			-- Dans sa propre tâche : une erreur de la boutique n'arrête pas les autres plaques.
			task.spawn(counter.shop.Open, pad :: BasePart)
		end
	end
end

function ShopPadController.Start()
	for _, entry in SHOPS do
		local shop = sibling(entry.Controller)
		if shop then
			local api: ShopApi = shop
			CollectionService:GetInstanceAddedSignal(entry.Tag):Connect(function(inst: Instance)
				attach(api, inst)
			end)
			CollectionService:GetInstanceRemovedSignal(entry.Tag):Connect(detach)
			for _, inst in CollectionService:GetTagged(entry.Tag) do
				attach(api, inst)
			end
		end
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return ShopPadController
