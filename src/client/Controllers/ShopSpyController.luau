--!strict
-- ShopSpyController (client, a301 ; demande de Cantin du 21/11) : « espionner » la boutique d'un autre joueur depuis
-- la rue. Près de sa boutique, dehors, on lit les étiquettes de tous les objets posés sur ses présentoirs, comme de
-- l'intérieur.
--
-- Avant : le billboard BB_Item de chaque objet exposé est créé par le serveur (DisplayService, copie du modèle de
-- Clément) et répliqué à tous les joueurs, MaxDistance 160 (Clément), AlwaysOnTop false. Aucun code ne le cache aux
-- autres joueurs ni selon la distance ; il est dessiné dans la scène 3D, donc caché par la façade (vitres Glass des
-- Stage_j/Frame, vantaux de PlotDoor/Window, murs).
--
-- Ici, sous Features.ShopSpy et Config/ShopSpy :
--   - toutes les ShopSpy.Interval s, pour chaque boutique taggée PlayerPlot qui n'est pas celle du joueur local
--     (OwnerUserId, bot compris) : le personnage local est-il dehors (hors du volume Bounds, contrat 10.4) et à
--     ShopSpy.Range studs ou moins de ce volume ?
--   - oui : AlwaysOnTop = true sur le BB_Item de chaque objet du dossier DisplayItems de la boutique (tag
--     DisplayItem) : il se voit à travers la façade. Revu à chaque passage (objets posés, arrivés par le streaming).
--     Les objets posés au sol (FloorItem, ailleurs) et l'inventaire ne sont pas touchés ;
--   - non (on entre, on s'éloigne, la boutique devient la sienne ou disparaît, plus de personnage) : la valeur
--     d'origine est rendue à chaque billboard touché.
-- Seule la propriété AlwaysOnTop de la copie de BB_Item, dans le Workspace du joueur local, change ; le modèle de
-- Clément (ReplicatedStorage/Assets/UI/BB_Item), sa MaxDistance, sa taille et son style ne sont jamais touchés.
-- Chez le propriétaire, rien ne change. Rien n'est envoyé au serveur : on n'affiche que ce qui est déjà répliqué.
-- Features.ShopSpy = false : le contrôleur ne fait rien (comme avant).
--
-- API (client ; Play, bancs) :
--   ShopSpyController.IsSpying(plot) -> boolean   la boutique est-elle espionnée en ce moment
--   ShopSpyController.Refresh()                   une revue tout de suite (sans attendre Interval)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any
local SpyConfig = require(Config:WaitForChild("ShopSpy")) :: any

local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local BOUNDS = "Bounds" -- contrat 10.4
local FOLDER = "DisplayItems" -- DisplayService
local DISPLAY_TAG = "DisplayItem" -- DisplayService
local BILLBOARD = "BB_Item"

local localPlayer = Players.LocalPlayer

local ShopSpyController = {}

-- Boutique espionnée → billboards touchés (valeur d'AlwaysOnTop d'origine).
local spied: { [Instance]: { [BillboardGui]: boolean } } = {}
local clock = 0

local function rootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- Distance de `point` au pavé `part` (0 dedans), comme PvPController.
local function distanceTo(part: BasePart, point: Vector3): number
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	local dx = math.max(math.abs(p.X) - h.X, 0)
	local dy = math.max(math.abs(p.Y) - h.Y, 0)
	local dz = math.max(math.abs(p.Z) - h.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function shouldSpy(plot: Instance, root: BasePart?): boolean
	if root == nil or not plot:IsDescendantOf(Workspace) then
		return false
	end
	local owner = plot:GetAttribute(OWNER_ATTRIBUTE)
	if type(owner) ~= "number" or owner == localPlayer.UserId then
		return false
	end
	local bounds = plot:FindFirstChild(BOUNDS)
	if bounds == nil or not bounds:IsA("BasePart") then
		return false
	end
	local distance = distanceTo(bounds :: BasePart, root.Position)
	return distance > 0 and distance <= SpyConfig.Range
end

local function restore(gui: BillboardGui, original: boolean)
	if gui.AlwaysOnTop ~= original then
		gui.AlwaysOnTop = original
	end
end

-- Allume tous les BB_Item exposés de `plot` ; rend leur valeur à ceux qui n'y sont plus.
local function spyOn(plot: Instance)
	local touched = spied[plot]
	if touched == nil then
		touched = {}
		spied[plot] = touched
	end
	local current: { [BillboardGui]: boolean } = {}
	local folder = plot:FindFirstChild(FOLDER)
	if folder ~= nil then
		for _, model in folder:GetChildren() do
			if CollectionService:HasTag(model, DISPLAY_TAG) then
				local gui = model:FindFirstChild(BILLBOARD)
				if gui ~= nil and gui:IsA("BillboardGui") then
					local billboard = gui :: BillboardGui
					current[billboard] = true
					if touched[billboard] == nil then
						touched[billboard] = billboard.AlwaysOnTop
					end
					if not billboard.AlwaysOnTop then
						billboard.AlwaysOnTop = true
					end
				end
			end
		end
	end
	for billboard, original in touched do
		if not current[billboard] then
			touched[billboard] = nil
			restore(billboard, original)
		end
	end
end

local function spyOff(plot: Instance)
	local touched = spied[plot]
	if touched == nil then
		return
	end
	spied[plot] = nil
	for billboard, original in touched do
		restore(billboard, original)
	end
end

function ShopSpyController.Refresh()
	if Features.ShopSpy ~= true then
		return
	end
	local root = rootPart()
	local seen: { [Instance]: boolean } = {}
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		seen[plot] = true
		if shouldSpy(plot, root) then
			spyOn(plot)
		else
			spyOff(plot)
		end
	end
	for plot in spied do
		if not seen[plot] then
			spyOff(plot) -- tag retiré ou boutique sortie du streaming
		end
	end
end

function ShopSpyController.IsSpying(plot: Instance): boolean
	return spied[plot] ~= nil
end

function ShopSpyController.Start()
	if Features.ShopSpy ~= true then
		return
	end
	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < SpyConfig.Interval then
			return
		end
		clock = 0
		ShopSpyController.Refresh()
	end)
end

return ShopSpyController
