--!strict
-- StoreClimbController (client, Cantin 2026-11-14, liaison L-140) : pas de grimpe dans un magasin PNJ.
--
-- Play du 14/11 : en sautant contre une gondole, le perso passait en état Climbing (les planches du rayon
-- servaient d'échelle) et restait accroché à la face du rayon, sous le bloc invisible de ShelfCapService.
-- C'est le client qui pilote son propre Humanoid : ici, l'état Climbing du perso du joueur local est coupé
-- (Humanoid:SetStateEnabled) tant que son HumanoidRootPart est dans le volume `Bounds` (contrat 10.4) d'un
-- magasin taggé `NPCStore` (dans la map, hors _INBOX_CLEMENT), et rendu dès qu'il en sort. S'il grimpait
-- déjà au moment de la coupure, il passe en chute (Freefall). Partout ailleurs (échelles, treillis de la
-- map), la grimpe reste normale. À la réapparition, le nouveau perso a la grimpe (valeur de Roblox) et la
-- vérification reprend tout de suite. Rien n'est envoyé au serveur ; aucun modèle n'est modifié.
-- Valeurs : Config/ShelfCaps (NoClimbInStores, ClimbCheckInterval).
--
-- API (client) :
--   StoreClimbController.IsClimbBlocked() -> boolean   (la grimpe du perso local est coupée par ce contrôleur)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShelfCaps = require(Shared:WaitForChild("Config"):WaitForChild("ShelfCaps"))

local STORE_TAG = "NPCStore" -- contrat 2.1
local BOUNDS_NAME = "Bounds" -- contrat 10.4
local INBOX_NAME = "_INBOX_CLEMENT"
local CLIMBING = Enum.HumanoidStateType.Climbing

local localPlayer = Players.LocalPlayer

local StoreClimbController = {}

local blocked: Humanoid? = nil -- Humanoid dont ce contrôleur a coupé la grimpe
local boundsCache: { [Instance]: BasePart } = setmetatable({}, { __mode = "k" }) :: any

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function boundsOf(store: Instance): BasePart?
	local cached = boundsCache[store]
	if cached and cached:IsDescendantOf(store) then
		return cached
	end
	local found = store:FindFirstChild(BOUNDS_NAME, true)
	if found and found:IsA("BasePart") then
		boundsCache[store] = found
		return found
	end
	boundsCache[store] = nil
	return nil
end

local function inStore(point: Vector3): boolean
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		if store:IsDescendantOf(Workspace) and not (inbox and store:IsDescendantOf(inbox)) then
			local bounds = boundsOf(store)
			if bounds and inside(bounds, point) then
				return true
			end
		end
	end
	return false
end

local function refresh()
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local previous = blocked
	if previous and not rawequal(previous, humanoid) then
		-- Ancien perso (réapparition) : on lui rend la grimpe s'il existe encore, et on l'oublie.
		if previous.Parent then
			previous:SetStateEnabled(CLIMBING, true)
		end
		blocked = nil
	end
	if character == nil or humanoid == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local want = ShelfCaps.NoClimbInStores and root ~= nil and root:IsA("BasePart") and inStore(root.Position)
	if want and blocked == nil then
		humanoid:SetStateEnabled(CLIMBING, false)
		if humanoid:GetState() == CLIMBING then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		blocked = humanoid
	elseif not want and blocked then
		humanoid:SetStateEnabled(CLIMBING, true)
		blocked = nil
	end
end

function StoreClimbController.IsClimbBlocked(): boolean
	return blocked ~= nil
end

function StoreClimbController.Start()
	localPlayer.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)
	while true do
		xpcall(refresh, function(err: any)
			warn(`[StoreClimbController] {err}`)
		end)
		task.wait(ShelfCaps.ClimbCheckInterval)
	end
end

return StoreClimbController
