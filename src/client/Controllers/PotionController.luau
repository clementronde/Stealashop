--!strict
-- PotionController (vague 28, client) : les potions côté joueur (liaison L-085 point 2, L-097 point 4).
-- Contrat : Config/Potions (en-tête) et les remotes PotionSpawned, PotionRemoved et PickPotion de
-- Net/Definitions. Le serveur (PotionService) décide tout : où et quelle potion apparaît, si le ramassage
-- compte, l'effet et sa durée (attribut Potion_<Id> du Player = heure serveur de fin). Ce contrôleur montre et
-- détecte le contact ; il n'envoie que PickPotion(uid).
--
--   1. Potions du joueur local : à PotionSpawned(uid, potionId, position), une copie locale du modèle de Clément
--      ReplicatedStorage/Assets/Potions/<Model> (Config/Potions) est posée au sol à `position` (le bas de sa
--      boîte sur le sol, quel que soit son pivot), dans Workspace/LocalPotions, vue de ce joueur seul :
--      pièces ancrées, sans collision, ni contact ni requête. Elle bouge selon l'attribut Idle du modèle
--      (« SpinBob ») avec le calcul des objets exposés (ItemIdleController.ModelMotion, Config/ItemIdle) ; sans
--      ItemIdleController, elle reste immobile. Retirée à PotionRemoved(uid). Modèle absent : une ligne en
--      Studio, rien d'autre (ni copie ni contact).
--   2. Contact : quand le HumanoidRootPart du joueur local passe à Potions.PickupRadius studs (à plat) d'une de
--      ses potions, et à VERTICAL_REACH studs au plus en hauteur, PickPotion(uid) part une fois ; il repart au
--      plus toutes les RESEND_DELAY s tant que la potion est là et le joueur à portée (le serveur peut avoir
--      refusé : trop loin à son goût, débit). PotionRemoved d'une potion demandée = ramassée : son UI_Success
--      (sons d'interface, UI/Motion.PlaySound ; aucun son de potion livré) et la copie grossit en montant
--      (POP_TIME), puis disparaît. Retirée sans demande (expirée) : elle disparaît tout de suite.
--   3. Effets actifs : chaque attribut Potion_<Id> du joueur local encore dans le futur donne une ligne, retirée
--      à la fin. Écran de Clément s'il existe : UI_HUD.PotionBar et son Template caché (Icon, Timer), une copie
--      par effet (Potion_<Id>) ; image d'Icon = attribut <Id>Icon de PotionBar (« rbxassetid://… »), sinon le
--      nom va dans Timer (« Speed 1:42 »). Sinon, affichage V0 fait par le code : ScreenGui PotionStatus, petites
--      lignes « Speed 1:42 » collées sous l'argent (UI_HUD.Cash ; au-dessus s'il est dans la moitié basse de
--      l'écran), à gauche au milieu de l'écran sans Cash. Rien en haut de l'écran.
--   4. Invisibilité (Potion_Invisibility) : chez ce client, chaque AUTRE joueur qui l'a devient presque
--      transparent (LocalTransparencyModifier INVISIBLE_OTHERS sur pièces et décalques, accessoires et outils
--      compris), nom caché (Humanoid.DisplayDistanceType = None, billboards, particules, traînées, rayons et
--      lumières de son personnage éteints), puis tout revient à la fin, à son départ ou sur son nouveau
--      personnage. Les contours (Highlight : alerte de vol, caméras) restent. Chez lui-même : un voile léger sur
--      tout l'écran (ScreenGui PotionVeil, sous le HUD), retiré à la fin.
--   5. VISUAL EFFECTS sur OFF (Settings.VfxReduced) : ParticleEmitter et lumières des potions éteints (rallumés à
--      leur état d'origine au retour sur ON) ; le reste ne change pas.
-- Valeurs V0 proposées, absentes du doc (à valider par Clément) : plus bas, « V0 ».
--
-- API (client) :
--   PotionController.GetState() -> { Shown, Popping, Effects, Cloaked, Veil }   (banc, barre de commande)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Potions = require(Config:WaitForChild("Potions"))
local Settings = require(Config:WaitForChild("Settings"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

local IS_STUDIO = RunService:IsStudio()

-- V0 proposés, absents du doc :
local VERTICAL_REACH = 6 -- studs entre le HumanoidRootPart et le sol de la potion (saut compris)
local RESEND_DELAY = 1 -- s entre deux PickPotion de la même potion
local POP_TIME = 0.25 -- s : la potion ramassée grossit en montant, puis disparaît
local POP_SCALE = 1.6
local POP_RISE = 1.5 -- studs
local PICK_SOUND = "UI_Success" -- son d'interface de Clément, en attendant un son de potion
local INVISIBLE_OTHERS = 0.85 -- transparence d'un autre joueur invisible
local VEIL_COLOR = Color3.fromHex("9DB4FF")
local VEIL_TRANSPARENCY = 0.85
local REFRESH_INTERVAL = 0.2 -- s : lignes d'effets et invisibilité des autres
local LINE_HEIGHT = 20 -- px, affichage V0
local LINE_WIDTH = 140
local LINE_GAP = 4

-- Noms (code) :
local FOLDER_NAME = "LocalPotions" -- Workspace, copies locales
local STATUS_SCREEN = "PotionStatus" -- ScreenGui de l'affichage V0
local VEIL_SCREEN = "PotionVeil"
local HUD_SCREEN = "UI_HUD"
local CASH_LABEL = "Cash" -- UI_HUD.Cash (contrat 2.2)
local BAR_NAME = "PotionBar" -- proposé à Clément : UI_HUD.PotionBar, Template (Icon, Timer)
local IDLE_ATTRIBUTE = "Idle" -- Contract/Attributes.Idle
local INVISIBILITY_ID = "Invisibility"

type Shown = {
	Uid: string,
	Model: Model,
	Ground: Vector3, -- position au sol reçue du serveur
	Base: CFrame, -- pivot au repos
	Mode: string?, -- attribut Idle
	Phase: number,
	Effects: { [Instance]: boolean }, -- particules et lumières : Enabled d'origine
	SentAt: number?, -- horloge du dernier PickPotion
	PopAge: number?, -- ramassée : temps écoulé depuis PotionRemoved
	Scale: number,
}

type Cloak = {
	Character: Model,
	Modifiers: { [Instance]: number }, -- pièces et décalques : LocalTransparencyModifier d'avant
	Switches: { Instance }, -- éteints ici (Enabled était true)
	Humanoid: Humanoid?,
	Display: Enum.HumanoidDisplayDistanceType?,
	Added: RBXScriptConnection?,
}

type Row = { Object: GuiObject, Timer: TextLabel? }

type Active = { Id: string, Name: string, Left: number, Order: number }

export type State = { Shown: number, Popping: number, Effects: number, Cloaked: number, Veil: boolean }

local PotionController = {}

local localPlayer = Players.LocalPlayer
local shown: { [string]: Shown } = {}
local popping: { Shown } = {}
local cloaks: { [Player]: Cloak } = {}
local rows: { [string]: Row } = {}
local rowsParent: Instance? = nil
local statusGui: ScreenGui? = nil
local statusList: Frame? = nil
local veilGui: ScreenGui? = nil
local net: any = nil
local itemIdle: any = nil
local motion: any = nil
local said: { [string]: boolean } = {}
local clock = 0
local sinceRefresh = math.huge

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[PotionController] {message}`)
	end
end

local function sibling(parent: Instance?, name: string): any
	local module = if parent then parent:FindFirstChild(name) else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	local value: any = result
	return if ok and type(value) == "table" then value else nil
end

local function reduced(): boolean
	local ok, result = pcall(Settings.VfxReduced, localPlayer)
	return ok and result == true
end

local function endsAtOf(player: Player, id: string): number?
	local value = player:GetAttribute(Potions.AttributePrefix .. id)
	return if type(value) == "number" and value == value then value else nil
end

------------------------------------------------------------------------------
-- 1. Copies locales des potions
------------------------------------------------------------------------------

local function folder(): Instance
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	return created
end

local function template(modelName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local potions = if assets then assets:FindFirstChild("Potions") else nil
	local found = if potions then potions:FindFirstChild(modelName, true) else nil
	if found == nil or not found:IsA("Model") then
		sayOnce(modelName, `ReplicatedStorage/Assets/Potions/{modelName} introuvable : potion pas montrée`)
		return nil
	end
	return found :: Model
end

-- Particules et lumières de la copie : éteintes à VISUAL EFFECTS OFF, sinon à leur état d'origine.
local function applyVfx(entry: Shown, off: boolean)
	for effect, original in entry.Effects do
		(effect :: any).Enabled = if off then false else original
	end
end

local function motionAt(entry: Shown, t: number): (number, number)
	local idle = itemIdle
	if entry.Mode == nil or idle == nil or type(idle.ModelMotion) ~= "function" then
		return 0, 0
	end
	local ok, angle, height = pcall(idle.ModelMotion, entry.Mode, t + entry.Phase)
	if ok and type(angle) == "number" and type(height) == "number" then
		return angle, height
	end
	return 0, 0
end

local function place(entry: Shown, extraHeight: number)
	local angle, height = motionAt(entry, clock)
	local base = entry.Base
	entry.Model:PivotTo(
		CFrame.new(base.Position + Vector3.new(0, height + extraHeight, 0)) * CFrame.Angles(0, angle, 0) * base.Rotation
	)
end

local function destroyShown(entry: Shown)
	entry.Model:Destroy()
end

local function removeShown(uid: string)
	local entry = shown[uid]
	if entry then
		shown[uid] = nil
		destroyShown(entry)
	end
end

local function onSpawned(uid: string, potionId: string, position: Vector3)
	if type(uid) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	removeShown(uid) -- même uid reçu deux fois : la dernière place compte
	local potion = Potions.ById[potionId]
	if potion == nil then
		sayOnce("id:" .. tostring(potionId), `potion inconnue « {potionId} » (Config/Potions) : pas montrée`)
		return
	end
	local source = template(potion.Model)
	if source == nil then
		return
	end
	local model = source:Clone()
	local effects: { [Instance]: boolean } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
			effects[descendant] = (descendant :: any).Enabled == true
		end
	end
	-- Le bas de la boîte du modèle sur le sol, quel que soit son pivot (pivot en bas au centre : 0).
	local pivot = model:GetPivot()
	local box, size = model:GetBoundingBox()
	local lift = pivot.Position.Y - (box.Position.Y - size.Y / 2)
	local raw = model:GetAttribute(IDLE_ATTRIBUTE)
	local entry: Shown = {
		Uid = uid,
		Model = model,
		Ground = position,
		Base = CFrame.new(position + Vector3.new(0, lift, 0)) * pivot.Rotation,
		Mode = if type(raw) == "string" then raw else nil,
		Phase = (position.X * 0.37 + position.Z * 0.61) % 10, -- comme ItemIdleController : voisines décalées
		Effects = effects,
		SentAt = nil,
		PopAge = nil,
		Scale = 1,
	}
	local okScale, scale = pcall(function(): number
		return model:GetScale()
	end)
	if okScale and type(scale) == "number" and scale > 0 then
		entry.Scale = scale
	end
	applyVfx(entry, reduced())
	place(entry, 0)
	model.Parent = folder()
	shown[uid] = entry
end

local function onRemoved(uid: string)
	local entry = shown[uid]
	if entry == nil then
		return
	end
	shown[uid] = nil
	if entry.SentAt == nil then
		destroyShown(entry) -- expirée ou retirée par le serveur
		return
	end
	-- Ramassée : petit effet.
	local play = motion
	if play and type(play.PlaySound) == "function" then
		pcall(play.PlaySound, PICK_SOUND)
	end
	entry.PopAge = 0
	table.insert(popping, entry)
end

local function stepPopping(dt: number)
	for index = #popping, 1, -1 do
		local entry = popping[index]
		local age = (entry.PopAge or 0) + dt
		entry.PopAge = age
		if age >= POP_TIME then
			table.remove(popping, index)
			destroyShown(entry)
		else
			local k = age / POP_TIME
			pcall(function()
				entry.Model:ScaleTo(entry.Scale * (1 + (POP_SCALE - 1) * k))
			end)
			place(entry, POP_RISE * k)
		end
	end
end

------------------------------------------------------------------------------
-- 2. Contact
------------------------------------------------------------------------------

local function rootPosition(): Vector3?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

local function checkContact()
	local at = rootPosition()
	if at == nil or net == nil then
		return
	end
	for uid, entry in shown do
		local delta = entry.Ground - at
		local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local sentAt = entry.SentAt
		if
			flat <= Potions.PickupRadius
			and math.abs(delta.Y) <= VERTICAL_REACH
			and (sentAt == nil or clock - sentAt >= RESEND_DELAY)
		then
			entry.SentAt = clock
			net.Client.PickPotion:Fire(uid)
		end
	end
end

------------------------------------------------------------------------------
-- 3. Effets actifs à l'écran
------------------------------------------------------------------------------

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function playerGui(): Instance?
	return localPlayer:FindFirstChild("PlayerGui")
end

local function hudOf(gui: Instance?): Instance?
	local hud = if gui then gui:FindFirstChild(HUD_SCREEN) else nil
	return if hud and hud:IsA("ScreenGui") then hud else nil
end

local function clearRows()
	for _, row in rows do
		row.Object:Destroy()
	end
	rows = {}
end

-- Affichage V0 : petites lignes sous (ou au-dessus de) l'argent.
local function ensureStatus(gui: Instance, hud: Instance?): Frame
	local screen = statusGui
	local list = statusList
	if screen == nil or list == nil or screen.Parent ~= gui then
		if screen then
			screen:Destroy()
		end
		local newScreen = Instance.new("ScreenGui")
		newScreen.Name = STATUS_SCREEN
		newScreen.ResetOnSpawn = false
		newScreen.Parent = gui
		local newList = Instance.new("Frame")
		newList.Name = "List"
		newList.BackgroundTransparency = 1
		newList.Size = UDim2.fromOffset(LINE_WIDTH, LINE_HEIGHT * #Potions.List)
		newList.Parent = newScreen
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = newList
		screen, list = newScreen, newList
		statusGui, statusList = newScreen, newList
	end
	local finalScreen = screen :: ScreenGui
	local finalList = list :: Frame
	local cash = if hud then hud:FindFirstChild(CASH_LABEL, true) else nil
	if hud and cash and cash:IsA("GuiObject") then
		local label = cash :: GuiObject
		finalScreen.IgnoreGuiInset = (hud :: ScreenGui).IgnoreGuiInset -- mêmes coordonnées que le HUD
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 0
		local top = label.AbsolutePosition.Y
		local below = top + label.AbsoluteSize.Y / 2 < height / 2
		local layout = finalList:FindFirstChildWhichIsA("UIListLayout")
		if below then
			finalList.AnchorPoint = Vector2.new(0, 0)
			finalList.Position = UDim2.fromOffset(label.AbsolutePosition.X, top + label.AbsoluteSize.Y + LINE_GAP)
			if layout then
				(layout :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Top
			end
		else
			finalList.AnchorPoint = Vector2.new(0, 1)
			finalList.Position = UDim2.fromOffset(label.AbsolutePosition.X, top - LINE_GAP)
			if layout then
				(layout :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Bottom
			end
		end
	else
		finalList.AnchorPoint = Vector2.new(0, 0.5)
		finalList.Position = UDim2.fromScale(0.01, 0.5)
	end
	return finalList
end

local function newV0Row(list: Frame, order: number): Row
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(LINE_WIDTH, LINE_HEIGHT)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = order
	label.Parent = list
	return { Object = label, Timer = label }
end

local function newBarRow(templateObject: GuiObject, order: number): Row
	local copy = templateObject:Clone()
	copy.LayoutOrder = order
	copy.Visible = true
	copy.Parent = templateObject.Parent
	local timer = Find.path(copy, "Timer")
	return { Object = copy, Timer = if timer and timer:IsA("TextLabel") then timer :: TextLabel else nil }
end

local function refreshEffects(now: number): number
	local active: { Active } = {}
	for order, potion in Potions.List do
		local id: string = potion.Id -- locale typée : l'ancien solveur suit mal l'union PotionId
		local endsAt = endsAtOf(localPlayer, id)
		if endsAt and endsAt > now then
			local effect: Active = { Id = id, Name = potion.DisplayName, Left = endsAt - now, Order = order }
			table.insert(active, effect)
		end
	end

	local gui = playerGui()
	local hud = hudOf(gui)
	local bar = if hud then Find.path(hud, BAR_NAME) else nil
	local barTemplate = if bar then Find.path(bar, "Template") else nil
	local templateObject: GuiObject? = if barTemplate and barTemplate:IsA("GuiObject")
		then barTemplate :: GuiObject
		else nil

	local container: Instance? = nil
	if #active > 0 and gui then
		if templateObject then
			container = templateObject.Parent
		else
			container = ensureStatus(gui, hud)
		end
	end
	if container ~= rowsParent then
		clearRows()
		rowsParent = container
	end
	if statusGui and templateObject then -- l'écran de Clément est arrivé : plus de V0
		statusGui:Destroy()
		statusGui, statusList = nil, nil
	end

	local keep: { [string]: boolean } = {}
	for _, effect in active do
		keep[effect.Id] = true
		local row = rows[effect.Id]
		if row == nil and container then
			if templateObject then
				row = newBarRow(templateObject, effect.Order)
			elseif statusList then
				row = newV0Row(statusList, effect.Order)
			end
			if row then
				row.Object.Name = Potions.AttributePrefix .. effect.Id
				rows[effect.Id] = row
				local icon = if templateObject then Find.path(row.Object, "Icon") else nil
				local image = if bar then bar:GetAttribute(effect.Id .. "Icon") else nil
				if icon and icon:IsA("ImageLabel") and type(image) == "string" then
					(icon :: ImageLabel).Image = image
				end
			end
		end
		if row and row.Timer then
			local hasIcon = templateObject ~= nil and bar ~= nil and type(bar:GetAttribute(effect.Id .. "Icon")) == "string"
			local text = formatTime(effect.Left)
			row.Timer.Text = if hasIcon then text else `{effect.Name} {text}`
		end
	end
	for id, row in rows do
		if not keep[id] then
			row.Object:Destroy()
			rows[id] = nil
		end
	end
	if #active == 0 and statusGui then
		statusGui:Destroy()
		statusGui, statusList = nil, nil
	end
	return #active
end

------------------------------------------------------------------------------
-- 4. Invisibilité
------------------------------------------------------------------------------

local function cloakOne(cloak: Cloak, inst: Instance)
	if inst:IsA("BasePart") or inst:IsA("Decal") then -- Decal : Texture compris
		local target = inst :: any
		if cloak.Modifiers[inst] == nil then
			cloak.Modifiers[inst] = target.LocalTransparencyModifier
		end
		target.LocalTransparencyModifier = INVISIBLE_OTHERS
	elseif
		inst:IsA("LayerCollector")
		or inst:IsA("ParticleEmitter")
		or inst:IsA("Beam")
		or inst:IsA("Trail")
		or inst:IsA("Light")
	then
		local target = inst :: any
		if target.Enabled == true then
			target.Enabled = false
			table.insert(cloak.Switches, inst)
		end
	elseif inst:IsA("Humanoid") and cloak.Humanoid == nil then
		local humanoid = inst :: Humanoid
		cloak.Humanoid = humanoid
		cloak.Display = humanoid.DisplayDistanceType
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function uncloak(cloak: Cloak)
	local added = cloak.Added
	if added then
		added:Disconnect()
	end
	for inst, value in cloak.Modifiers do
		if inst.Parent ~= nil then
			(inst :: any).LocalTransparencyModifier = value
		end
	end
	for _, inst in cloak.Switches do
		if inst.Parent ~= nil then
			(inst :: any).Enabled = true
		end
	end
	local humanoid = cloak.Humanoid
	local display = cloak.Display
	if humanoid and display and humanoid.Parent ~= nil then
		humanoid.DisplayDistanceType = display
	end
end

local function cloak(character: Model): Cloak
	local record: Cloak = {
		Character = character,
		Modifiers = {},
		Switches = {},
		Humanoid = nil,
		Display = nil,
		Added = nil,
	}
	for _, descendant in character:GetDescendants() do
		cloakOne(record, descendant)
	end
	record.Added = character.DescendantAdded:Connect(function(descendant: Instance)
		cloakOne(record, descendant)
	end)
	return record
end

local function refreshCloaks(now: number): number
	local wanted: { [Player]: Model } = {}
	for _, player in Players:GetPlayers() do
		local endsAt = endsAtOf(player, INVISIBILITY_ID)
		local character = player.Character
		if player ~= localPlayer and endsAt and endsAt > now and character then
			wanted[player] = character
		end
	end
	for player, record in cloaks do
		if wanted[player] ~= record.Character then
			uncloak(record)
			cloaks[player] = nil
		end
	end
	local count = 0
	for player, character in wanted do
		if cloaks[player] == nil then
			cloaks[player] = cloak(character)
		end
		count += 1
	end
	return count
end

local function refreshVeil(now: number)
	local endsAt = endsAtOf(localPlayer, INVISIBILITY_ID)
	local on = endsAt ~= nil and endsAt > now
	local gui = playerGui()
	local screen = veilGui
	if on and gui and (screen == nil or screen.Parent ~= gui) then
		if screen then
			screen:Destroy()
		end
		local newScreen = Instance.new("ScreenGui")
		newScreen.Name = VEIL_SCREEN
		newScreen.ResetOnSpawn = false
		newScreen.IgnoreGuiInset = true
		newScreen.DisplayOrder = -10 -- sous le HUD et les écrans
		local frame = Instance.new("Frame")
		frame.Name = "Veil"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = VEIL_COLOR
		frame.BackgroundTransparency = VEIL_TRANSPARENCY
		frame.Active = false
		frame.Parent = newScreen
		newScreen.Parent = gui
		veilGui = newScreen
		screen = newScreen
	end
	if screen then
		screen.Enabled = on
	end
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	refreshEffects(now)
	refreshCloaks(now)
	refreshVeil(now)
end

------------------------------------------------------------------------------

local function step(dt: number)
	clock += dt
	for _, entry in shown do
		place(entry, 0)
	end
	stepPopping(dt)
	checkContact()
	sinceRefresh += dt
	if sinceRefresh >= REFRESH_INTERVAL then
		sinceRefresh = 0
		refresh()
	end
end

function PotionController.GetState(): State
	local count, effects, cloaked = 0, 0, 0
	for _ in shown do
		count += 1
	end
	for _ in rows do
		effects += 1
	end
	for _ in cloaks do
		cloaked += 1
	end
	local veil = veilGui
	return {
		Shown = count,
		Popping = #popping,
		Effects = effects,
		Cloaked = cloaked,
		Veil = veil ~= nil and veil.Enabled and veil.Parent ~= nil,
	}
end

function PotionController.Start()
	itemIdle = sibling(script.Parent, "ItemIdleController")
	motion = sibling(script.Parent:FindFirstChild("UI"), "Motion")
	localPlayer:GetAttributeChangedSignal(Settings.VfxAttribute):Connect(function()
		local off = reduced()
		for _, entry in shown do
			applyVfx(entry, off)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, function(err: any)
			if not said.step then
				said.step = true
				warn(`[PotionController] {err}`)
			end
		end, dt)
	end)
	local ok, result = pcall(function(): any
		return require(Shared:WaitForChild("Net"):WaitForChild("Net"))
	end)
	if not ok or type(result) ~= "table" then
		sayOnce("net", `Net : require impossible ({result}) ; potions coupées`)
		return
	end
	local wired = pcall(function()
		result.Client.PotionSpawned:Connect(onSpawned)
		result.Client.PotionRemoved:Connect(onRemoved)
		local _ = result.Client.PickPotion
	end)
	if wired then
		net = result
	else
		sayOnce("remotes", "remotes PotionSpawned, PotionRemoved ou PickPotion absents : potions coupées")
	end
end

return PotionController
