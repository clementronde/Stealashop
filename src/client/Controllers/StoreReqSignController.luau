--!strict
-- StoreReqSignController (client ; liaison L-108 point 5, Clément, 2026-11-12) : panneau planté devant
-- chaque magasin PNJ, qui annonce la vitesse et la force requises pour y entrer, comme les panneaux
-- d'amélioration UpgradeSign des boutiques (UpgradeController).
--
--   - modèle : StoreReqSign de Clément (ReplicatedStorage/Assets/UI ou un sous-dossier, 2.2), avec
--     Board (pièce), SignGui (SurfaceGui) et les textes StoreName, SpeedReq, StrengthReq ;
--   - point de pose : l'Attachment ReqSignPoint du magasin (tag NPCStore, Zone 1 à 6, hors
--     _INBOX_CLEMENT ; posé par Clément dans <magasin>/Bounds). Facultatif : sans lui, pas de panneau ;
--   - pose (Shared/SignPose, la règle d'UpgradeSign ; même pied Foot et même pivot chez Clément) :
--     le bas de la boîte du panneau au point, la face de Board tournée comme le LookVector du point, mis à l'horizontale (pour tourner un panneau, Clément
--     tourne son point). Pièces ancrées ; ni taille, ni couleur de fond, ni position d'élément
--     changées. Copie locale, rangée dans le dossier Workspace/StoreReqSigns (côté client seulement :
--     chaque joueur a ses couleurs) ;
--   - textes, en anglais (L-036), mêmes valeurs que le panneau BB_StoreInfo (Config/Zones, section 4) :
--     StoreName = nom du magasin (StoreInfoController.StoreNameOf), SpeedReq = « Speed 16 »
--     (AdvicePanel.speedText : AdvisedSpeed), StrengthReq = « Strength 1 » (AdvicePanel.strengthText :
--     AdvisedDamage, comme Damage sur BB_StoreInfo) ;
--   - couleur du texte de SpeedReq et de StrengthReq, chez le joueur local : vert, orange ou rouge, la
--     règle de BB_StoreInfo (AdvicePanel.levels, 5.3), refaite dès que les attributs Damage ou
--     WalkSpeed du Player changent ;
--   - streaming : un magasin qui part emporte son panneau, refait à son retour ; l'arrivée ou le
--     départ de ReqSignPoint refait la pose.
-- Un élément absent du modèle est ignoré (une ligne en Studio) ; sans le modèle, rien n'est posé.
-- Les aperçus de Clément `Workspace/_PREVIEW_StoreReqSigns` (12 panneaux posés au même endroit pour
-- voir la pose en édition) sont retirés en jeu, côté client seulement, comme _PREVIEW_UpgradeSigns.
-- ReqCaption (« REQUIRED TO BREAK IN ») est un texte fixe de Clément : pas touché.
--
-- API (client) :
--   StoreReqSignController.GetSigns() -> { SignInfo }
--       Panneaux posés chez le joueur local, triés par nom de magasin, pour un test dans Studio :
--       { Store, Zone, Speed ("Green", "Orange", "Red"), Strength (idem) }.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Contract = Shared:WaitForChild("Contract")
local Zones = require(Config:WaitForChild("Zones"))
local Attributes = require(Contract:WaitForChild("Attributes"))
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local AdvicePanel = require(Shared:WaitForChild("AdvicePanel"))
local SignPose = require(Shared:WaitForChild("SignPose"))
local StoreInfoController = require(script.Parent:WaitForChild("StoreInfoController"))

type Level = AdvicePanel.Level

export type SignInfo = {
	Store: string,
	Zone: number,
	Speed: Level?,
	Strength: Level?,
}

type Sign = {
	Store: Model,
	Zone: number,
	Model: Model?,
	Point: Attachment?,
	Speed: TextLabel?,
	Strength: TextLabel?,
	SpeedLevel: Level?,
	StrengthLevel: Level?,
	Pending: boolean,
	Connections: { RBXScriptConnection },
}

local STORE_TAG = "NPCStore" -- contrat 2.1
local INBOX_NAME = "_INBOX_CLEMENT"
local SIGN_NAME = "StoreReqSign" -- modèle de Clément (L-108)
local POINT_NAME = "ReqSignPoint" -- Attachment du magasin, dans Bounds (L-108)
local BOARD_NAME = "Board"
local STORE_NAME = "StoreName"
local SPEED_NAME = "SpeedReq"
local STRENGTH_NAME = "StrengthReq"
local SIGN_FOLDER = "StoreReqSigns" -- dossier local du Workspace
local PREVIEW_FOLDER = "_PREVIEW_StoreReqSigns" -- aperçus de Clément, retirés en jeu (L-108)

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local StoreReqSignController = {}

local signs: { [Instance]: Sign } = {}
local signFolder: Folder? = nil
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string, isProblem: boolean?)
	if not IS_STUDIO or said[key] then
		return
	end
	said[key] = true
	if isProblem then
		warn(message)
	else
		print(message)
	end
end

-- Modèle StoreReqSign de Clément, ou nil.
local function template(): Model?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(SIGN_NAME, true) else nil
	if found and found:IsA("Model") then
		return found
	end
	sayOnce(
		"template",
		`[StoreReqSignController] {SIGN_NAME} absent de ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")} : pas de panneau devant les magasins (L-108)`
	)
	return nil
end

local function textOf(root: Instance, name: string): TextLabel?
	local found = Find.path(root, name)
	if found and found:IsA("TextLabel") then
		return found :: TextLabel
	end
	sayOnce(`element:{name}`, `[StoreReqSignController] {SIGN_NAME}.{name} introuvable ou pas un TextLabel : ignoré`, true)
	return nil
end

local function folder(): Folder
	local current = signFolder
	if current and current.Parent == Workspace then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = SIGN_FOLDER
	created.Parent = Workspace
	signFolder = created
	return created
end

-- Copie du modèle, debout au point, face de Board tournée comme le LookVector du point (UpgradeSign).
local function placeModel(source: Model, point: Attachment, store: Model): Model
	local model = source:Clone()
	model.Name = `{SIGN_NAME}_{store.Name}`
	local found = Find.path(model, BOARD_NAME)
	local board: BasePart? = if found and found:IsA("BasePart") then found else nil
	SignPose.place(model, board, point, store:GetPivot().LookVector) -- même règle qu'UpgradeSign
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	return model
end

local function recolor(sign: Sign)
	-- Même règle et mêmes couleurs que BB_StoreInfo (StoreInfoController) : AdvicePanel.levels.
	local strengthLevel: Level, speedLevel: Level = AdvicePanel.levels(localPlayer, Zones[sign.Zone])
	sign.SpeedLevel, sign.StrengthLevel = speedLevel, strengthLevel
	local speed, strength = sign.Speed, sign.Strength
	if speed then
		speed.TextColor3 = AdvicePanel.Colors[speedLevel]
	end
	if strength then
		strength.TextColor3 = AdvicePanel.Colors[strengthLevel]
	end
end

local function recolorAll()
	for _, sign in signs do
		recolor(sign)
	end
end

local function clearModel(sign: Sign)
	local model = sign.Model
	sign.Model, sign.Point, sign.Speed, sign.Strength = nil, nil, nil, nil
	sign.SpeedLevel, sign.StrengthLevel = nil, nil
	if model then
		model:Destroy()
	end
end

-- Pose ou refait le panneau d'un magasin.
local function place(sign: Sign)
	sign.Pending = false
	local store = sign.Store
	if signs[store] ~= sign then
		return -- magasin oublié entre-temps (sorti du streaming)
	end
	local found = store:FindFirstChild(POINT_NAME, true)
	local point: Attachment? = if found and found:IsA("Attachment") then found else nil
	local source = template()
	if point == nil or source == nil then
		clearModel(sign)
		return
	end
	local current = sign.Model
	if current and current.Parent ~= nil and sign.Point == point then
		recolor(sign)
		return
	end
	clearModel(sign)
	local zone = Zones[sign.Zone]
	local model = placeModel(source, point, store)
	local storeName = textOf(model, STORE_NAME)
	if storeName then
		storeName.Text = StoreInfoController.StoreNameOf(store, zone)
	end
	local speed = textOf(model, SPEED_NAME)
	if speed then
		speed.Text = AdvicePanel.speedText(zone)
	end
	local strength = textOf(model, STRENGTH_NAME)
	if strength then
		strength.Text = AdvicePanel.strengthText(zone)
	end
	sign.Model, sign.Point, sign.Speed, sign.Strength = model, point, speed, strength
	recolor(sign)
	model.Parent = folder()
end

local function schedule(sign: Sign)
	if not sign.Pending then
		sign.Pending = true
		task.defer(place, sign)
	end
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

local function track(instance: Instance)
	if signs[instance] ~= nil or not instance:IsA("Model") or not inMap(instance) then
		return
	end
	local zone = instance:GetAttribute(Attributes.Zone.Name)
	if type(zone) ~= "number" or Zones[zone] == nil then
		return -- StoreInfoController le signale déjà
	end
	local sign: Sign = {
		Store = instance :: Model,
		Zone = zone,
		Model = nil,
		Point = nil,
		Speed = nil,
		Strength = nil,
		SpeedLevel = nil,
		StrengthLevel = nil,
		Pending = false,
		Connections = {},
	}
	signs[instance] = sign
	local function onDescendant(descendant: Instance)
		if descendant.Name == POINT_NAME then
			schedule(sign)
		end
	end
	table.insert(sign.Connections, instance.DescendantAdded:Connect(onDescendant))
	table.insert(sign.Connections, instance.DescendantRemoving:Connect(onDescendant))
	place(sign)
end

local function untrack(instance: Instance)
	local sign = signs[instance]
	if sign == nil then
		return
	end
	signs[instance] = nil
	for _, connection in sign.Connections do
		connection:Disconnect()
	end
	table.clear(sign.Connections)
	clearModel(sign)
end

function StoreReqSignController.GetSigns(): { SignInfo }
	local list: { SignInfo } = {}
	for store, sign in signs do
		if sign.Model then
			table.insert(list, {
				Store = store.Name,
				Zone = sign.Zone,
				Speed = sign.SpeedLevel,
				Strength = sign.StrengthLevel,
			})
		end
	end
	table.sort(list, function(a: SignInfo, b: SignInfo): boolean
		return a.Store < b.Store
	end)
	return list
end

-- Aperçus de Clément au même endroit que les panneaux : retirés en jeu, ici seulement.
local function dropPreview(child: Instance)
	if child.Name == PREVIEW_FOLDER then
		child:Destroy()
	end
end

function StoreReqSignController.Start()
	for _, child in Workspace:GetChildren() do
		dropPreview(child)
	end
	Workspace.ChildAdded:Connect(dropPreview)
	for _, attribute in { AdvicePanel.DamageAttribute, AdvicePanel.WalkSpeedAttribute } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(recolorAll)
	end
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(STORE_TAG):Connect(untrack)
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		track(store)
	end
	if IS_STUDIO then
		local shown = 0
		for _, sign in signs do
			if sign.Model then
				shown += 1
			end
		end
		print(`[StoreReqSignController] {shown} panneau(x) {SIGN_NAME} posé(s) devant les magasins`)
	end
end

return StoreReqSignController
