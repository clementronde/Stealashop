--!strict
-- HubController (L-165 points 1, 2 et 6, vague 50, a160 ; client) : zones du hub et étiquettes des stands.
-- Valeurs : Config/Hub (V0, noms de Clément proposés en L-165) ; calculs : Shared/HubZone.
--
--   - zone du cadeau (pièce taggée RewardsZone, dans ENV_Hub_FreeGift) : y entrer ouvre UI_Rewards, comme
--     RewardsButton (RewardsController.Open), une fois par entrée ;
--   - zone du noob (pièce taggée InviteZone, dans ENV_Hub_InviteNoob) : y entrer ouvre l'invitation de Roblox
--     (InviteController.Prompt), une fois par entrée. Idle et Wave du noob : HubService (serveur) ;
--   - zone de la roue (pièce taggée WheelZone, dans ENV_Hub_Wheel ; vague 80, a266) : y entrer ouvre UI_Wheel
--     (WheelController.Open), une fois par entrée ;
--   - entrée et sortie : HubZone.step sur le HumanoidRootPart du joueur, toutes les Hub.Tick s. Un personnage
--     qui apparaît déjà dans une zone (réapparition) n'ouvre rien : il doit en sortir puis y revenir ;
--   - cadeau (Gift, Model ou pièce, du modèle de la zone RewardsZone) : flotte et tourne sur l'axe Y de son
--     pivot (Hub.Gift), en local seulement, autour de la place posée par Clément ;
--   - étiquettes : chaque BillboardGui BB_ZoneLabel du Workspace reçoit dans son TextLabel Label le texte
--     anglais de son attribut LabelKey (Hub.Labels ; attribut lu sur le billboard, sinon sur son parent).
--     Clé absente ou inconnue : le texte de Clément reste (un avertissement en Studio).
--     Couleur : l'attribut LabelColor du LabelPoint de Clément, posé sur Label.TextColor3 (vague 56, a181).
-- Seuls sont touchés : le pivot local du cadeau, le texte de Label et sa couleur LabelColor ; jamais une taille ni une
-- position de Clément. Avec StreamingEnabled, zones, cadeaux et étiquettes arrivent et repartent : suivis par
-- tag et par DescendantAdded. Rien n'est envoyé au serveur.
--
-- API (client) :
--   HubController.GetState() -> { Inside: { string }, Gifts: number, Labels: number }   pour un test

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hub = require(Shared:WaitForChild("Config"):WaitForChild("Hub"))
local HubZone = require(Shared:WaitForChild("HubZone"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

type Gift = {
	target: Instance, -- Model ou BasePart
	base: CFrame, -- place posée par Clément
	phase: number,
}

local HubController = {}

-- Joueur dans chaque zone (par pièce taggée) ; root = HumanoidRootPart pour qui l'état a été posé.
local inside: { [BasePart]: boolean } = {}
local stateRoot: BasePart? = nil
local gifts: { [Instance]: Gift } = {}
local labels: { [BillboardGui]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		warn(`[HubController] {message}`)
	end
end

------------------------------------------------------------------------------
-- Zones
------------------------------------------------------------------------------

local considerGift: (zone: Instance) -> () -- plus bas (Cadeau)

local function onEnter(tag: string)
	if tag == Hub.RewardsZoneTag then
		local RewardsController = require(script.Parent:WaitForChild("RewardsController")) :: any
		RewardsController.Open()
	elseif tag == Hub.InviteZoneTag then
		local InviteController = require(script.Parent:WaitForChild("InviteController")) :: any
		InviteController.Prompt()
	elseif tag == Hub.WheelZoneTag then
		-- Vague 80 (a266, L-165 point 3) : la roue du hub ouvre UI_Wheel (rien si la roue est coupée ou l'écran absent).
		local WheelController = require(script.Parent:WaitForChild("WheelController")) :: any
		WheelController.Open()
	end
end

local function rootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

local function stepZones()
	local root = rootPart()
	local position = if root then root.Position else nil
	-- Nouveau personnage : l'état est posé sans rien ouvrir (réapparition dans une zone).
	local prime = root ~= nil and root ~= stateRoot
	stateRoot = root
	local seen: { [BasePart]: boolean } = {}
	for _, tag in { Hub.RewardsZoneTag, Hub.InviteZoneTag, Hub.WheelZoneTag } do
		for _, tagged in CollectionService:GetTagged(tag) do
			if not tagged:IsA("BasePart") or seen[tagged :: BasePart] then
				continue
			end
			local zone = tagged :: BasePart
			seen[zone] = true
			local isIn, entered = HubZone.step(inside[zone] == true, zone.CFrame, zone.Size, position)
			if isIn then
				inside[zone] = true
			else
				inside[zone] = nil
			end
			if entered and not prime then
				onEnter(tag)
			end
			if tag == Hub.RewardsZoneTag then
				considerGift(zone) -- un cadeau arrivé après sa zone (StreamingEnabled)
			end
		end
	end
	for zone in inside do
		if not seen[zone] then
			inside[zone] = nil
		end
	end
end

------------------------------------------------------------------------------
-- Cadeau
------------------------------------------------------------------------------

local function pivotOf(target: Instance): CFrame?
	if target:IsA("Model") then
		return (target :: Model):GetPivot()
	elseif target:IsA("BasePart") then
		return (target :: BasePart).CFrame
	end
	return nil
end

considerGift = function(zone: Instance)
	local holder = zone:FindFirstAncestorOfClass("Model")
	local target = if holder then holder:FindFirstChild(Hub.GiftName, true) else nil
	if target == nil or gifts[target] ~= nil then
		return
	end
	local base = pivotOf(target)
	if base == nil then
		sayOnce(`gift:{target:GetFullName()}`, `{target:GetFullName()} n'est ni un Model ni une pièce : le cadeau ne flotte pas`)
		return
	end
	gifts[target] = { target = target, base = base, phase = 0 }
end

local function stepGifts(dt: number)
	local period = math.max(Hub.Gift.FloatPeriod, 0.1)
	for target, gift in gifts do
		if target.Parent == nil then
			gifts[target] = nil
			continue
		end
		gift.phase += dt
		local lift = Hub.Gift.FloatHeight * math.sin(gift.phase * 2 * math.pi / period)
		local angle = math.rad(Hub.Gift.SpinSpeed * gift.phase)
		local cframe = gift.base * CFrame.new(0, lift, 0) * CFrame.Angles(0, angle, 0)
		if target:IsA("Model") then
			(target :: Model):PivotTo(cframe)
		elseif target:IsA("BasePart") then
			(target :: BasePart).CFrame = cframe
		end
	end
end

------------------------------------------------------------------------------
-- Étiquettes
------------------------------------------------------------------------------

local function paintLabel(gui: BillboardGui)
	local key = gui:GetAttribute(Hub.LabelKeyAttribute)
	-- LabelKey peut être sur le billboard ou sur un ancêtre (Clément le pose sur le modèle ENV_Hub_*, Play du 2026-11-15) :
	-- le premier qui le porte gagne, sans dépasser le Workspace.
	local node = gui.Parent
	while key == nil and node ~= nil and node ~= workspace do
		key = node:GetAttribute(Hub.LabelKeyAttribute)
		node = node.Parent
	end
	local text = HubZone.labelText(key)
	if text == nil then
		sayOnce(`key:{gui:GetFullName()}`, `{gui:GetFullName()} : LabelKey {tostring(key)} absent ou inconnu (Config/Hub.Labels), texte de Clément gardé`)
		return
	end
	local found = Find.path(gui, Hub.LabelElement)
	if found == nil or not found:IsA("TextLabel") then
		sayOnce(`label:{gui:GetFullName()}`, `{gui:GetFullName()}.{Hub.LabelElement} introuvable ou pas un TextLabel : étiquette pas écrite`)
		return
	end
	(found :: TextLabel).Text = text
	-- Vague 56 (a181, L-165) : couleur du nom = attribut LabelColor (Color3) du LabelPoint de Clément (le billboard,
	-- son Adornee, puis ses ancêtres jusqu'au Workspace) ; sans l'attribut, la couleur du modèle reste.
	local color = gui:GetAttribute(Hub.LabelColorAttribute)
	local adornee: Instance? = gui.Adornee
	if color == nil and adornee ~= nil then
		color = adornee:GetAttribute(Hub.LabelColorAttribute)
	end
	local holder = gui.Parent
	while color == nil and holder ~= nil and holder ~= workspace do
		color = holder:GetAttribute(Hub.LabelColorAttribute)
		holder = holder.Parent
	end
	if typeof(color) == "Color3" then
		(found :: TextLabel).TextColor3 = color
	end
end

local function considerLabel(instance: Instance)
	if instance.Name ~= Hub.LabelBillboard or not instance:IsA("BillboardGui") then
		return
	end
	local gui = instance :: BillboardGui
	if labels[gui] then
		return
	end
	labels[gui] = true
	gui:GetAttributeChangedSignal(Hub.LabelKeyAttribute):Connect(function()
		paintLabel(gui)
	end)
	paintLabel(gui)
end

function HubController.GetState(): { Inside: { string }, Gifts: number, Labels: number }
	local names: { string } = {}
	for zone in inside do
		table.insert(names, zone:GetFullName())
	end
	local giftCount, labelCount = 0, 0
	for _ in gifts do
		giftCount += 1
	end
	for _ in labels do
		labelCount += 1
	end
	return { Inside = names, Gifts = giftCount, Labels = labelCount }
end

function HubController.Start()
	Workspace.DescendantAdded:Connect(considerLabel)
	for _, instance in Workspace:GetDescendants() do
		considerLabel(instance)
	end
	CollectionService:GetInstanceAddedSignal(Hub.RewardsZoneTag):Connect(considerGift)
	for _, zone in CollectionService:GetTagged(Hub.RewardsZoneTag) do
		considerGift(zone)
	end

	RunService.RenderStepped:Connect(stepGifts)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Hub.Tick then
			return
		end
		elapsed = 0
		local ok, err = pcall(stepZones :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			sayOnce("zones", `zones du hub : {err}`)
		end
	end)
end

return HubController
