--!strict
-- DisguiseController (client, a411, vague GC6 ; liaison L-113, cabine d'essayage). Derrière Features.FittingRoom.
-- Rien n'est décidé ici : DisguiseService (serveur) vérifie tout et répond par des Notify et des attributs du Player
-- (Config/Disguise.Attributes : Disguised, DisguiseUntil, DisguiseReadyAt, DisguiseCanCall).
--
--   1. Cabine : une invite « Fitting Room » (touche F) vue par moi seul, sur le modèle FittingRoom de MA boutique
--      (Clément, facultatif), sinon sur sa porte (PlotDoor/Window, au-dessus de l'invite du verrou). Elle ouvre
--      l'écran de choix de zone.
--   2. Écran de choix : UI_FittingRoom de Clément s'il existe (Contract/UI), sinon une liste de repli construite par
--      le code avec les mêmes noms (FittingRoomV0). Une ligne par zone (copie de ZoneList.Template nommée Zone_<n>) :
--      ZoneName = « ZONE n · Thème », ou « ZONE n · REBIRTH k » et Locked montré tant que la zone demande k
--      renaissances. Clic : remote Disguise(n). UnlockButton (compétence pas achetée) : remote BuySkill.
--   3. Déguisé : chrono (UI_Disguise.Timer de Clément, sinon un texte de repli en bas de l'écran), et sur la vitrine
--      de chaque magasin PNJ de ma zone une invite « Call the police » à maintenir Disguise.DenounceTime s tant que
--      DisguiseCanCall est vrai : remote Denounce(nom du magasin, "Begin" / "End" / "Cancel").
--   4. Chez chaque client, le personnage de tout joueur déguisé (moi compris) perd ce qui le trahit : billboards
--      (titre de renaissance…), particules, rayons, traînées et lumières (aura, trail) sont éteints, puis rallumés
--      à la fin. Son nom est déjà caché par le serveur ; le « ? » de la dénonciation est affiché par WitnessController.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Disguise = require(Config:WaitForChild("Disguise"))
local Features = require(Config:WaitForChild("Features"))
local SkillTree = require(Config:WaitForChild("SkillTree"))
local Zones = require(Config:WaitForChild("Zones"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))

local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

local PLOT_TAG = "PlayerPlot"
local STORE_TAG = "NPCStore"
local OWNER_ATTRIBUTE = "OwnerUserId"
local ZONE_ATTRIBUTE = "Zone"
local DOOR_NAME = "PlotDoor"
local WINDOW_NAME = "Window"
local CABIN_PROMPT = "FittingRoomPrompt"
local DENOUNCE_PROMPT = "DenouncePrompt"
local FALLBACK_SCREEN = "FittingRoomV0"
local FALLBACK_TIMER = "DisguiseV0"
local DOOR_OFFSET = Vector2.new(0, -72) -- V0 : l'invite de la cabine au-dessus de celle du verrou, sur la porte
local RANGE_MARGIN = 5 -- studs retirés à la portée du serveur pour l'invite de dénonciation (V0)

local ATTR = Disguise.Attributes
local CLIENT = Disguise.Client
local SKILL_ATTRIBUTE = SkillTree.AttributePrefix .. Disguise.SkillId

local player = Players.LocalPlayer

type Picker = {
	gui: ScreenGui,
	fallback: boolean,
	list: GuiObject,
	template: GuiButton,
	rows: { [number]: GuiButton },
	unlock: GuiButton?,
	price: TextLabel?,
}
type Mask = { character: Model, switches: { Instance } }

local DisguiseController = {}

local net: any = nil
local picker: Picker? = nil
local pickerOpen = false
local cabinPrompt: ProximityPrompt? = nil
local storePrompts: { [Instance]: ProximityPrompt } = {}
local timerGui: ScreenGui? = nil
local masks: { [Player]: Mask } = {}

local function numberAttribute(name: string): number?
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

local function partOf(instance: Instance?): BasePart?
	if instance == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

------------------------------------------------------------------------------
-- Écran de choix de zone
------------------------------------------------------------------------------

local function label(parent: Instance, name: string, text: string): TextLabel
	local created = Instance.new("TextLabel")
	created.Name = name
	created.BackgroundTransparency = 1
	created.Size = UDim2.fromScale(1, 1)
	created.Font = Enum.Font.GothamBold
	created.TextScaled = true
	created.TextColor3 = Color3.new(1, 1, 1)
	created.Text = text
	created.Parent = parent
	return created
end

local function button(parent: Instance, name: string, height: number, color: Color3): TextButton
	local created = Instance.new("TextButton")
	created.Name = name
	created.Size = UDim2.fromScale(1, height)
	created.BackgroundColor3 = color
	created.AutoButtonColor = true
	created.Text = ""
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(0, 44) -- boutons d'au moins 44 px (règle UI)
	constraint.Parent = created
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.Parent = created
	created.Parent = parent
	return created
end

local function listLayout(parent: Instance)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.015, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = parent
end

-- Repli sans UI_FittingRoom : une fenêtre grise au centre, mêmes noms que le contrat.
local function buildFallback(playerGui: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = FALLBACK_SCREEN
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 20
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.34, 0.8)
	window.BackgroundColor3 = Color3.fromRGB(32, 34, 40)
	window.BorderSizePixel = 0
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(260, 0)
	minimum.Parent = window
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.02, 0)
	padding.PaddingBottom = UDim.new(0.02, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = window
	listLayout(window)
	local title = label(window, "Title", CLIENT.Title)
	title.Size = UDim2.fromScale(1, 0.08)
	local list = Instance.new("Frame")
	list.Name = "ZoneList"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 0.56)
	list.LayoutOrder = 1
	-- Deux colonnes de trois zones : des boutons d'au moins 44 px sur un téléphone couché.
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.48, 0.3)
	grid.CellPadding = UDim2.fromScale(0.04, 0.04)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local template = button(list, "Template", 0.3, Color3.fromRGB(64, 110, 190))
	template.Visible = false
	label(template, "ZoneName", "")
	local locked = Instance.new("Frame")
	locked.Name = "Locked"
	locked.Size = UDim2.fromScale(1, 1)
	locked.BackgroundColor3 = Color3.new(0, 0, 0)
	locked.BackgroundTransparency = 0.45
	locked.BorderSizePixel = 0
	locked.Visible = false
	locked.Parent = template
	list.Parent = window
	local unlock = button(window, "UnlockButton", 0.13, Color3.fromRGB(70, 160, 90))
	unlock.LayoutOrder = 2
	label(unlock, "PriceLabel", "")
	local close = button(window, "CloseButton", 0.13, Color3.fromRGB(150, 60, 60))
	close.LayoutOrder = 3
	label(close, "CloseLabel", "CLOSE")
	window.Parent = gui
	gui.Parent = playerGui
	return gui
end

local function closePicker()
	local current = picker
	if pickerOpen and current then
		pickerOpen = false
		if current.fallback then
			current.gui.Enabled = false
		else
			Motion.Close(current.gui)
		end
	end
end

local function clicked(target: GuiButton, fallback: boolean): RBXScriptSignal
	return if fallback then target.Activated else Motion.Activated(target)
end

-- L'écran en place dans PlayerGui (celui de Clément, sinon le repli), branché une fois par copie.
local function currentPicker(): Picker?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local found = playerGui:FindFirstChild(CLIENT.Screen)
	local fallback = found == nil or not found:IsA("ScreenGui")
	local current = picker
	if current and current.gui.Parent == playerGui and current.fallback == fallback then
		return current
	end
	local gui: ScreenGui = if fallback then (playerGui:FindFirstChild(FALLBACK_SCREEN) :: ScreenGui?) or buildFallback(playerGui) else found :: ScreenGui
	local list = Find.path(gui, "ZoneList")
	local template = if list then Find.path(list, "Template") else nil
	local close = Find.path(gui, "CloseButton")
	if list == nil or not list:IsA("GuiObject") or template == nil or not template:IsA("GuiButton") then
		return nil
	end
	(template :: GuiButton).Visible = false
	local unlock = Find.path(gui, "UnlockButton")
	local price = if unlock then Find.path(unlock, "PriceLabel") else nil
	local created: Picker = {
		gui = gui,
		fallback = fallback,
		list = list :: GuiObject,
		template = template :: GuiButton,
		rows = {},
		unlock = if unlock and unlock:IsA("GuiButton") then unlock :: GuiButton else nil,
		price = if price and price:IsA("TextLabel") then price :: TextLabel else nil,
	}
	if not fallback then
		gui.Enabled = false
		Motion.SetCloser(gui, closePicker)
	end
	pickerOpen = false
	if close and close:IsA("GuiButton") then
		clicked(close :: GuiButton, fallback):Connect(closePicker)
	end
	local unlockButton = created.unlock
	if unlockButton then
		clicked(unlockButton, fallback):Connect(function()
			if net then
				net.Client.BuySkill:Fire(Disguise.SkillId)
			end
		end)
	end
	for zone = 1, #Zones do
		local row = created.template:Clone()
		row.Name = `Zone_{zone}`
		row.LayoutOrder = zone
		row.Visible = true
		row.Parent = created.list
		created.rows[zone] = row
		clicked(row, fallback):Connect(function()
			if net then
				net.Client.Disguise:Fire(zone)
			end
			closePicker()
		end)
	end
	picker = created
	return created
end

local function refreshPicker(current: Picker)
	local owned = (numberAttribute(SKILL_ATTRIBUTE) or 0) >= 1
	local rebirths = SkillTree.RebirthsOf(player:GetAttribute(SkillTree.RebirthsAttribute)) or 0
	for zone, row in current.rows do
		local needed = zone - Disguise.ZoneRebirthOffset
		local isLocked = rebirths < needed
		local name = Find.path(row, "ZoneName")
		if name and name:IsA("TextLabel") then
			(name :: TextLabel).Text = if isLocked then string.format(CLIENT.ZoneLockedText, zone, needed) else string.format(CLIENT.ZoneText, zone, string.upper(Zones[zone].Theme))
		end
		local locked = Find.path(row, "Locked")
		if locked and locked:IsA("GuiObject") then
			(locked :: GuiObject).Visible = isLocked
			local lockedLabel = Find.path(locked, "LockedLabel")
			if lockedLabel and lockedLabel:IsA("TextLabel") then
				(lockedLabel :: TextLabel).Text = string.format(SkillTree.RebirthNameText, needed)
			end
		end
		row.Visible = owned or current.unlock == nil
	end
	local unlock = current.unlock
	if unlock then
		unlock.Visible = not owned
		local skill = SkillTree.ById[Disguise.SkillId]
		local price = if skill then skill.Prices[1] else nil
		if current.price and price then
			current.price.Text = string.format(CLIENT.UnlockText, Format.money(price))
		end
	end
end

local function togglePicker()
	if pickerOpen then
		closePicker()
		return
	end
	local current = currentPicker()
	if current == nil then
		return
	end
	refreshPicker(current)
	pickerOpen = true
	if current.fallback then
		current.gui.Enabled = true
	else
		Motion.Open(current.gui)
	end
end

------------------------------------------------------------------------------
-- Invites : cabine et dénonciation
------------------------------------------------------------------------------

local function myPlot(): Model?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId then
			return plot :: Model
		end
	end
	return nil
end

-- Pièce qui porte l'invite de la cabine, et vrai si c'est la porte (repli sans modèle de cabine).
local function cabinAnchor(): (BasePart?, boolean)
	local plot = myPlot()
	if plot == nil then
		return nil, false
	end
	local model = plot:FindFirstChild(Disguise.Cabin.ModelName, true)
	-- L-326 : la pièce PromptPart de la cabine livrée, sinon sa première pièce.
	local cabin = partOf(if model then model:FindFirstChild(Disguise.Cabin.PromptPart) or model else nil)
	if cabin then
		return cabin, false
	end
	local door = plot:FindFirstChild(DOOR_NAME)
	return partOf(if door then door:FindFirstChild(WINDOW_NAME) else nil), true
end

local function refreshCabin(disguised: boolean)
	local anchor, onDoor = cabinAnchor()
	local current = cabinPrompt
	if anchor == nil or disguised then
		if current then
			current:Destroy()
			cabinPrompt = nil
		end
		if disguised then
			closePicker()
		end
		return
	end
	if current == nil or current.Parent ~= anchor then
		if current then
			current:Destroy()
		end
		local created = Instance.new("ProximityPrompt")
		created.Name = CABIN_PROMPT
		created.ObjectText = CLIENT.CabinPrompt
		created.KeyboardKeyCode = Enum.KeyCode.F
		created.GamepadKeyCode = Enum.KeyCode.ButtonY
		created.HoldDuration = 0
		created.MaxActivationDistance = CLIENT.CabinPromptRange
		created.RequiresLineOfSight = false
		created.UIOffset = if onDoor then DOOR_OFFSET else Vector2.zero
		created.Triggered:Connect(togglePicker)
		created.Parent = anchor
		cabinPrompt = created
		current = created
	end
	local left = (numberAttribute(ATTR.ReadyAt) or 0) - Workspace:GetServerTimeNow()
	local seconds = math.ceil(left)
	local text = if left > 0 then string.format(CLIENT.CabinActionCooldown, seconds // 60, seconds % 60) else CLIENT.CabinAction
	if (current :: ProximityPrompt).ActionText ~= text then
		(current :: ProximityPrompt).ActionText = text
	end
end

local function denouncePrompt(store: Instance, anchor: BasePart): ProximityPrompt
	local created = Instance.new("ProximityPrompt")
	created.Name = DENOUNCE_PROMPT
	created.ActionText = CLIENT.DenouncePrompt
	created.KeyboardKeyCode = Enum.KeyCode.E
	created.HoldDuration = Disguise.DenounceTime
	created.MaxActivationDistance = math.max(Disguise.DenounceRange - RANGE_MARGIN, 1)
	created.RequiresLineOfSight = false
	local done = false
	created.PromptButtonHoldBegan:Connect(function()
		done = false
		if net then
			net.Client.Denounce:Fire(store.Name, "Begin")
		end
	end)
	created.Triggered:Connect(function()
		done = true
		if net then
			net.Client.Denounce:Fire(store.Name, "End")
		end
	end)
	created.PromptButtonHoldEnded:Connect(function()
		if not done and net then
			net.Client.Denounce:Fire(store.Name, "Cancel")
		end
	end)
	created.Parent = anchor
	return created
end

-- Une invite par magasin PNJ de ma zone tant qu'une dénonciation reste ; aucune sinon.
local function refreshStores(zone: number?)
	local wanted: { [Instance]: BasePart } = {}
	if zone and player:GetAttribute(ATTR.CanCall) == true then
		for _, store in CollectionService:GetTagged(STORE_TAG) do
			if store:GetAttribute(ZONE_ATTRIBUTE) == zone and store:IsDescendantOf(Workspace) then
				local anchor = partOf(Find.path(store, WINDOW_NAME))
				if anchor then
					wanted[store] = anchor
				end
			end
		end
	end
	for store, prompt in storePrompts do
		if wanted[store] ~= prompt.Parent then
			prompt:Destroy()
			storePrompts[store] = nil
		end
	end
	for store, anchor in wanted do
		local existing: ProximityPrompt? = storePrompts[store]
		if existing == nil then
			storePrompts[store] = denouncePrompt(store, anchor)
		end
	end
end

------------------------------------------------------------------------------
-- Chrono
------------------------------------------------------------------------------

-- a508 (L-461) : Controllers/UI/HudMask, lu au premier besoin s'il est là (banc sans lui : Enabled écrit comme avant).
type HudMaskApi = { SetShown: (ScreenGui, boolean) -> () }
local hudMaskApi: HudMaskApi | false | nil = nil

local function hudMask(): HudMaskApi?
	if hudMaskApi == nil then
		hudMaskApi = false
		local ui = script.Parent:FindFirstChild("UI")
		local module = if ui then ui:FindFirstChild("HudMask") else nil
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module :: any)
			if ok and type(result) == "table" and type((result :: any).SetShown) == "function" then
				hudMaskApi = result :: any
			end
		end
	end
	return if hudMaskApi then hudMaskApi else nil
end

local function refreshTimer(disguised: boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local gui = timerGui
	if gui == nil or gui.Parent ~= playerGui then
		local found = playerGui:FindFirstChild(CLIENT.TimerScreen) or playerGui:FindFirstChild(FALLBACK_TIMER)
		if found and found:IsA("ScreenGui") then
			gui = found
		elseif disguised then
			local created = Instance.new("ScreenGui")
			created.Name = FALLBACK_TIMER
			created.ResetOnSpawn = false
			local text = label(created, "Timer", "")
			text.AnchorPoint = Vector2.new(0.5, 1)
			text.Position = UDim2.fromScale(0.5, 0.8) -- rien en haut de l'écran
			text.Size = UDim2.fromScale(0.3, 0.045)
			text.TextStrokeTransparency = 0.4
			created.Parent = playerGui
			gui = created
		end
		timerGui = gui
	end
	if gui == nil then
		return
	end
	-- a508 (L-461 point 2) : sous une fenêtre ouverte (PanelFocus), UI_Disguise est masqué comme le HUD : son état est
	-- gardé par HudMask (rendu à la fermeture) au lieu d'être rallumé ici à chaque tour.
	local mask = hudMask()
	if mask then
		mask.SetShown(gui, disguised)
	elseif gui.Enabled ~= disguised then
		gui.Enabled = disguised
	end
	local timer = if disguised then Find.path(gui, "Timer") else nil
	if timer and timer:IsA("TextLabel") then
		local left = math.max(math.ceil((numberAttribute(ATTR.Until) or 0) - Workspace:GetServerTimeNow()), 0);
		(timer :: TextLabel).Text = string.format(CLIENT.TimerText, left // 60, left % 60)
	end
end

------------------------------------------------------------------------------
-- Masque des joueurs déguisés
------------------------------------------------------------------------------

local function unmask(who: Player)
	local mask = masks[who]
	if mask then
		masks[who] = nil
		for _, inst in mask.switches do
			if inst.Parent ~= nil then
				(inst :: any).Enabled = true
			end
		end
	end
end

local function refreshMasks()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local mask = masks[other]
		if type(other:GetAttribute(ATTR.Zone)) ~= "number" or character == nil then
			unmask(other)
			continue
		end
		if mask == nil or mask.character ~= character then
			unmask(other)
			mask = { character = character, switches = {} }
			masks[other] = mask
		end
		for _, inst in character:GetDescendants() do
			if
				(inst:IsA("LayerCollector") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Light"))
				and (inst :: any).Enabled == true
			then
				(inst :: any).Enabled = false
				table.insert((mask :: Mask).switches, inst)
			end
		end
	end
	for other in masks do
		if other.Parent ~= Players then
			unmask(other)
		end
	end
end

local function refresh()
	local zone = numberAttribute(ATTR.Zone)
	local disguised = zone ~= nil
	refreshCabin(disguised)
	refreshStores(zone)
	refreshTimer(disguised)
	refreshMasks()
	local current = picker
	if pickerOpen and current then
		refreshPicker(current)
	end
end

function DisguiseController.Start()
	if not Features.FittingRoom then
		return
	end
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	while true do
		local ok, err = pcall(refresh :: any)
		if not ok then
			warn(`[DisguiseController] {err}`)
		end
		task.wait(CLIENT.Refresh)
	end
end

return DisguiseController
