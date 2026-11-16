--!strict
-- CatchSceneController (client, vague 59, a192 ; liaison L-184 points 1 et 4 ; valeurs : Config/HeistFeel) : la
-- capture mise en scène et la carte « ITEM SECURED! ».
--
-- 1. Capture (remote CatchScene de GuardService, envoyé au seul joueur attrapé, au coup du vigile : marqueur Impact
--    de Catch, délai de secours sans marqueur, tout de suite sans Catch ; arrestation de nuit : à son début). Aucune
--    règle de jeu ne change (l'étourdissement reste celui du serveur) ; tout se joue dans HeistFeel.Catch.SceneTime :
--      - tout le HUD coupé (Controllers/UI/HudMask, masque « Catch » : seul l'écran de capture reste ; jamais les
--        messages du serveur, HeistFeel.NeverMask), rendu à la fin ;
--      - MUS_Chase coupée d'un coup (MusicController.CutChase) ; claquement HeistFeel.Catch.SlamSound SlamDelay s
--        après le contact (facultatif) ; poussière HeistFeel.Catch.Dust aux pieds du joueur (facultative, Assets/FX) ;
--      - caméra (Scriptable) qui plonge vers le joueur en DiveTime s jusqu'à un plan bas (DiveDistance studs devant
--        la caméra d'avant, DiveHeight sous le HumanoidRootPart), qui avance encore de LowDrift studs pendant
--        LowHold s ; rendue (CameraType et CameraSubject d'avant) à la fin ;
--      - écran « CAUGHT! » (UI_Caught de Clément, facultatif ; sans lui, UI_Caught_V0 fait par le code, mêmes noms) :
--        Title tamponné (Stamp : StampFrom → 1, StampTilt° → sa Rotation, par un UIScale passager), ItemIcon =
--        l'icône de l'objet (ICON_<ItemId>) qui repart vers le haut et s'efface (« Shelf » : il revole sur son rayon)
--        ou tombe (« Drop ») ; caché sans objet ;
--      - renvoi à la base (nuit, policier : homeIn > 0) : BarTop et BarBottom passent de 0 à la taille de Clément
--        (BandsClose s) juste avant le renvoi, restent BandsHold s (la caméra est rendue dans le noir), puis s'ouvrent
--        (BandsOpen s) ; « CAUGHT! » vient après. Sans renvoi : bandes cachées.
--    Une nouvelle capture arrête la scène en cours ; la mort du personnage ou son retrait aussi (tout est rendu).
--    Tout ce qui est changé dans l'écran de Clément (Visible, Rotation, Position, Size, Image, transparence) est
--    remis à la fin ; l'écran V0 est détruit.
-- 2. Carte « ITEM SECURED! » (remote ItemSecured, en plus de UiFeelController.Escape qui joue l'écran) : dans
--    UI_Escape, les éléments facultatifs Card.ItemIcon (icône), Card.ItemName, Card.Rarity (« LEGENDARY »),
--    Card.Income (« +$1.2K/s », revenu de base de l'objet dans sa zone ; caché pour un Secret) et Card.NewBadge
--    (montré à la première fois : objet entré dans l'index, attribut IndexDiscovered, moins de HeistFeel.Card.NewWindow
--    s avant ou après). Sans Card : rien. Vague 63 (a207) : ItemName et Rarity passent par Controllers/UI/RarityFx
--    (dégradé de la rareté, reflet du Légendaire, arc-en-ciel du Mythique et du Secret).
--
-- API (client, pour un banc ou la barre de commande) :
--   CatchSceneController.Play(night, outcome, homeIn, itemId?)   joue une capture (comme le remote)
--   CatchSceneController.GetState() -> { Scenes, Active, Phase, Outcome, HomeIn, Cards, LastNew }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local HeistFeel = require(Config:WaitForChild("HeistFeel"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Formulas = require(Config:WaitForChild("Formulas"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local HudMask = require(script.Parent:WaitForChild("UI"):WaitForChild("HudMask"))
local RarityFx = require(script.Parent:WaitForChild("UI"):WaitForChild("RarityFx"))

type MusicApi = { CutChase: () -> () }

export type State = {
	Scenes: number,
	Active: boolean,
	Phase: string, -- "Idle", "Dive", "Low", "Bands", "Stamp"
	Outcome: string?,
	HomeIn: number,
	Cards: number,
	LastNew: boolean?,
}

type Scene = {
	token: number,
	outcome: string,
	homeIn: number,
	screen: ScreenGui?,
	v0: boolean,
	saved: { { object: Instance, property: string, value: any } },
	temps: { Instance },
	tweens: { Tween },
	cameraType: Enum.CameraType?,
	cameraSubject: Instance?,
	cameraTaken: boolean,
	connections: { RBXScriptConnection },
}

local CATCH = HeistFeel.Catch
local MASK_KEY = "Catch"
local STAMP_SCALE = "CaughtStampScale" -- V0 : UIScale passager de Title
local IS_STUDIO = RunService:IsStudio()

local CatchSceneController = {}

local localPlayer = Players.LocalPlayer
local scene: Scene? = nil
local token = 0
local scenes = 0
local cards = 0
local phase = "Idle"
local lastOutcome: string? = nil
local lastHomeIn = 0
local lastNew: boolean? = nil
local said: { [string]: boolean } = {}
local discovered: { [string]: boolean } = {}
local discoveredAt: { [string]: number } = {}
local indexModule: any = nil

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[CatchScene] {message}`)
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

local function rootPart(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root :: BasePart else nil
end

local function iconOf(itemId: string?): string?
	if itemId == nil or itemId == "" then
		return nil
	end
	local ok, texture = pcall(function()
		local Icons = require(Shared:WaitForChild("Contract"):WaitForChild("Icons")) :: any
		return Icons.get(itemId)
	end)
	return if ok and type(texture) == "string" then texture else nil
end

local function playSound(name: string)
	local template = MarkerSounds.find(name)
	if template == nil then
		sayOnce(`sound:{name}`, `son « {name} » absent de ReplicatedStorage.Assets.Sounds : pas joué (L-184)`)
		return
	end
	MarkerSounds.playSound(template, nil)
end

-- Scène : valeurs à remettre, tweens --------------------------------------------------------------------------

local function save(current: Scene, object: Instance, property: string)
	for _, entry in current.saved do
		if entry.object == object and entry.property == property then
			return
		end
	end
	table.insert(current.saved, { object = object, property = property, value = (object :: any)[property] })
end

local function setProp(current: Scene, object: Instance, property: string, value: any)
	save(current, object, property)
	;(object :: any)[property] = value
end

local function play(current: Scene, object: Instance, info: TweenInfo, goal: { [string]: any })
	for property in goal do
		save(current, object, property)
	end
	local tween = TweenService:Create(object, info, goal)
	table.insert(current.tweens, tween)
	tween:Play()
end

local function later(current: Scene, delay: number, fn: () -> ())
	task.delay(math.max(delay, 0), function()
		if scene == current then
			fn()
		end
	end)
end

-- Écran « CAUGHT! » ------------------------------------------------------------------------------------------

-- Écran V0 du code, mêmes noms que celui proposé à Clément (UI_Caught).
local function buildV0(playerGui: PlayerGui): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = CATCH.V0Screen
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 50
	screen.Enabled = false
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.4)
	title.Size = UDim2.fromScale(0.5, 0.14)
	title.BackgroundTransparency = 1
	title.Text = "CAUGHT!"
	title.Rotation = 0
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Parent = screen
	local icon = Instance.new("ImageLabel")
	icon.Name = "ItemIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.58)
	icon.Size = UDim2.fromScale(0.12, 0.2)
	icon.BackgroundTransparency = 1
	icon.Parent = screen
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = icon
	for _, name in { "BarTop", "BarBottom" } do
		local edge = if name == "BarTop" then 0 else 1
		local bar = Instance.new("Frame")
		bar.Name = name
		bar.AnchorPoint = Vector2.new(0, edge)
		bar.Position = UDim2.fromScale(0, edge)
		bar.Size = UDim2.fromScale(1, 0.5)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 10
		bar.Parent = screen
	end
	screen.Parent = playerGui
	return screen
end

local function element(screen: ScreenGui, name: string, class: string): any
	local found = Find.path(screen, name)
	return if found and found:IsA(class) then found else nil
end

local function bars(screen: ScreenGui): { GuiObject }
	local out: { GuiObject } = {}
	for _, name in { "BarTop", "BarBottom" } do
		local bar = element(screen, name, "GuiObject")
		if bar then
			table.insert(out, bar)
		end
	end
	return out
end

local function stamp(current: Scene, itemId: string?)
	local screen = current.screen
	if screen == nil then
		return
	end
	phase = "Stamp"
	local title = element(screen, "Title", "GuiObject") :: GuiObject?
	if title then
		setProp(current, title, "Visible", true)
		local rotation = title.Rotation
		setProp(current, title, "Rotation", rotation + CATCH.StampTilt)
		local info = TweenInfo.new(CATCH.StampTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		play(current, title, info, { Rotation = rotation })
		if title:FindFirstChildOfClass("UIScale") == nil then
			local scale = Instance.new("UIScale")
			scale.Name = STAMP_SCALE
			scale.Scale = CATCH.StampFrom
			scale.Parent = title
			table.insert(current.temps, scale)
			play(current, scale, info, { Scale = 1 })
		end
	end
	local icon = element(screen, "ItemIcon", "ImageLabel") :: ImageLabel?
	if icon then
		local image = iconOf(itemId)
		if image == nil or current.outcome == "None" then
			setProp(current, icon, "Visible", false)
		else
			setProp(current, icon, "Image", image)
			setProp(current, icon, "Visible", true)
			local from = icon.Position
			local shift = if current.outcome == "Shelf" then -CATCH.ItemFlyRise else CATCH.ItemDropFall
			local info = TweenInfo.new(CATCH.ItemFlyTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			later(current, CATCH.StampTime, function()
				play(current, icon, info, {
					Position = UDim2.new(from.X.Scale, from.X.Offset, from.Y.Scale + shift, from.Y.Offset),
					ImageTransparency = 1,
				})
			end)
		end
	end
end

-- Caméra ---------------------------------------------------------------------------------------------------------

local function takeCamera(current: Scene)
	local camera = Workspace.CurrentCamera
	local root = rootPart()
	if camera == nil or root == nil then
		return
	end
	local ok = pcall(function()
		current.cameraType = camera.CameraType
		current.cameraSubject = camera.CameraSubject
		local from = camera.CFrame
		local flat = Vector3.new(from.Position.X - root.Position.X, 0, from.Position.Z - root.Position.Z)
		local away = if flat.Magnitude > 1e-3 then flat.Unit else -root.CFrame.LookVector
		local target = root.Position + Vector3.new(0, CATCH.LookHeight, 0)
		local low = root.Position + away * CATCH.DiveDistance + Vector3.new(0, CATCH.DiveHeight, 0)
		local closer = root.Position + away * (CATCH.DiveDistance - CATCH.LowDrift) + Vector3.new(0, CATCH.DiveHeight, 0)
		camera.CameraType = Enum.CameraType.Scriptable
		current.cameraTaken = true
		phase = "Dive"
		local dive = TweenService:Create(camera, TweenInfo.new(CATCH.DiveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(low, target),
		})
		table.insert(current.tweens, dive)
		dive:Play()
		later(current, CATCH.DiveTime, function()
			phase = "Low"
			local drift = TweenService:Create(camera, TweenInfo.new(CATCH.LowHold, Enum.EasingStyle.Linear), {
				CFrame = CFrame.lookAt(closer, target),
			})
			table.insert(current.tweens, drift)
			drift:Play()
		end)
	end)
	if not ok then
		sayOnce("camera", "caméra indisponible : pas de plongeon")
	end
end

local function giveCamera(current: Scene)
	if not current.cameraTaken then
		return
	end
	current.cameraTaken = false
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	pcall(function()
		camera.CameraType = current.cameraType or Enum.CameraType.Custom
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local subject = current.cameraSubject
		camera.CameraSubject = (if subject and subject.Parent ~= nil then subject else humanoid) :: any
	end)
end

-- Poussière (facultative) -------------------------------------------------------------------------------------

local function dust()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local fx = if assets then assets:FindFirstChild("FX") else nil
	local template = if fx then fx:FindFirstChild(CATCH.Dust, true) else nil
	local root = rootPart()
	if template == nil then
		sayOnce("dust", `{CATCH.Dust} absent de ReplicatedStorage.Assets.FX : pas de poussière (L-184)`)
		return
	end
	if root == nil then
		return
	end
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + 2, 0)
	local copy = template:Clone()
	if copy:IsA("Attachment") then
		(copy :: Attachment).WorldPosition = feet
		copy.Parent = Workspace.Terrain
	elseif copy:IsA("PVInstance") then
		(copy :: PVInstance):PivotTo(CFrame.new(feet))
		for _, part in copy:GetDescendants() do
			if part:IsA("BasePart") then
				(part :: BasePart).Anchored = true
				;(part :: BasePart).CanCollide = false
			end
		end
		if copy:IsA("BasePart") then
			(copy :: BasePart).Anchored = true
			;(copy :: BasePart).CanCollide = false
		end
		copy.Parent = Workspace
	else
		copy:Destroy()
		return
	end
	local emitters = copy:GetDescendants()
	table.insert(emitters, copy)
	for _, emitter in emitters do
		if emitter:IsA("ParticleEmitter") then
			local count = emitter:GetAttribute("EmitCount")
			;(emitter :: ParticleEmitter):Emit(if type(count) == "number" then count else CATCH.DustEmit)
		end
	end
	task.delay(CATCH.DustLife, function()
		copy:Destroy()
	end)
end

-- Déroulé ----------------------------------------------------------------------------------------------------------

local function finish(current: Scene)
	if scene ~= current then
		return
	end
	scene = nil
	phase = "Idle"
	for _, connection in current.connections do
		connection:Disconnect()
	end
	for _, tween in current.tweens do
		tween:Cancel()
	end
	giveCamera(current)
	for i = #current.saved, 1, -1 do
		local entry = current.saved[i]
		if entry.object.Parent ~= nil then
			(entry.object :: any)[entry.property] = entry.value
		end
	end
	for _, temp in current.temps do
		temp:Destroy()
	end
	local screen = current.screen
	if screen then
		if current.v0 then
			screen:Destroy()
		elseif screen.Parent ~= nil then
			screen.Enabled = false
		end
	end
	HudMask.Pop(MASK_KEY)
end

function CatchSceneController.Play(night: boolean, outcome: string, homeIn: number, itemId: string?)
	local previous = scene
	if previous then
		finish(previous)
	end
	token += 1
	scenes += 1
	lastOutcome = outcome
	lastHomeIn = homeIn
	local current: Scene = {
		token = token,
		outcome = outcome,
		homeIn = math.clamp(homeIn, 0, CATCH.SafetyMax),
		screen = nil,
		v0 = false,
		saved = {},
		temps = {},
		tweens = {},
		cameraType = nil,
		cameraSubject = nil,
		cameraTaken = false,
		connections = {},
	}
	scene = current
	-- UI_Chase n'est pas masqué : ChaseController l'éteint lui-même à la fin de la poursuite (capture) ; masqué, il
	-- serait rallumé au retour du HUD.
	HudMask.Push(MASK_KEY, { KeepScreens = { CATCH.Screen, CATCH.V0Screen, "UI_Chase" } })

	local music = sibling("MusicController") :: MusicApi?
	if music and type(music.CutChase) == "function" then
		pcall(music.CutChase)
	end
	later(current, CATCH.SlamDelay, function()
		playSound(CATCH.SlamSound)
	end)
	pcall(dust)
	takeCamera(current)

	-- Écran de capture : celui de Clément, sinon le V0.
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local found = if playerGui then playerGui:FindFirstChild(CATCH.Screen) else nil
	if found and found:IsA("ScreenGui") then
		current.screen = found :: ScreenGui
	elseif playerGui then
		sayOnce("screen", `{CATCH.Screen} pas encore livré : écran V0 du code (L-184)`)
		current.screen = buildV0(playerGui)
		current.v0 = true
	end
	local screen = current.screen
	if screen then
		local title = element(screen, "Title", "GuiObject")
		if title then
			setProp(current, title, "Visible", false)
		end
		local icon = element(screen, "ItemIcon", "GuiObject")
		if icon then
			setProp(current, icon, "Visible", false)
		end
		for _, bar in bars(screen) do
			if current.homeIn > 0 then
				local size = bar.Size
				setProp(current, bar, "Size", UDim2.new(size.X.Scale, size.X.Offset, 0, 0))
				setProp(current, bar, "Visible", true)
			else
				setProp(current, bar, "Visible", false)
			end
		end
		screen.Enabled = true
	end

	local stampAt = CATCH.DiveTime + CATCH.LowHold
	local endAt = CATCH.SceneTime
	if current.homeIn > 0 then
		local home = current.homeIn
		local closeAt = math.max(home - CATCH.BandsClose, 0)
		local openAt = home + CATCH.BandsHold
		stampAt = math.max(stampAt, openAt)
		endAt = math.min(openAt + CATCH.BandsOpen + CATCH.StampHold, CATCH.SafetyMax)
		later(current, closeAt, function()
			phase = "Bands"
			local s = current.screen
			if s == nil then
				return
			end
			for _, bar in bars(s) do
				local goal: UDim2 = (function()
					for _, entry in current.saved do
						if entry.object == bar and entry.property == "Size" then
							return entry.value
						end
					end
					return bar.Size
				end)()
				play(current, bar, TweenInfo.new(home - closeAt, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = goal })
			end
		end)
		later(current, openAt, function()
			giveCamera(current) -- dans le noir, à la base
			local s = current.screen
			if s == nil then
				return
			end
			for _, bar in bars(s) do
				local size = bar.Size
				play(current, bar, TweenInfo.new(CATCH.BandsOpen, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 0),
				})
			end
		end)
	end
	later(current, stampAt, function()
		stamp(current, itemId)
	end)
	later(current, endAt - CATCH.OutTime, function()
		local s = current.screen
		local title = if s then element(s, "Title", "TextLabel") else nil
		if title then
			play(current, title, TweenInfo.new(CATCH.OutTime), { TextTransparency = 1 })
		end
	end)
	later(current, endAt, function()
		finish(current)
	end)

	-- Mort ou personnage retiré : tout est rendu tout de suite.
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		table.insert(current.connections, humanoid.Died:Connect(function()
			finish(current)
		end))
	end
	table.insert(current.connections, localPlayer.CharacterRemoving:Connect(function()
		finish(current)
	end))
	if IS_STUDIO then
		print(`[CatchScene] capture mise en scène ({if night then "nuit" else "jour"}, {outcome}, renvoi dans {homeIn} s)`)
	end
end

-- Carte « ITEM SECURED! » ----------------------------------------------------------------------------------------

local function readDiscovered()
	local index = indexModule
	if index == nil then
		return
	end
	local ok, set = pcall(index.Decode, localPlayer:GetAttribute(index.Attribute))
	if not ok or type(set) ~= "table" then
		return
	end
	local now = os.clock()
	for id in set do
		if not discovered[id] then
			discoveredAt[id] = now
		end
	end
	discovered = set
end

local function isNew(itemId: string): boolean
	if indexModule == nil then
		return false
	end
	if not discovered[itemId] then
		return true -- la découverte arrive juste après (IndexService.Discover suit ItemSecured)
	end
	local at = discoveredAt[itemId]
	return at ~= nil and os.clock() - at <= HeistFeel.Card.NewWindow
end

local function fillCard(itemId: string)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if playerGui then playerGui:FindFirstChild("UI_Escape") else nil
	if screen == nil or not screen:IsA("ScreenGui") then
		return
	end
	local escape = screen :: ScreenGui
	if Find.path(escape, "Card") == nil then
		return -- carte pas encore livrée
	end
	local def = Items.ById[itemId]
	if def == nil then
		return
	end
	cards += 1
	local fresh = isNew(itemId)
	lastNew = fresh
	local icon = element(escape, "Card.ItemIcon", "ImageLabel") :: ImageLabel?
	local image = iconOf(itemId)
	if icon and image then
		icon.Image = image
	end
	local name = element(escape, "Card.ItemName", "TextLabel") :: TextLabel?
	if name then
		name.Text = def.DisplayName
		RarityFx.Apply(name, def.Rarity) -- vague 63 (a207) : la rareté qui bouge, comme les autres écrans
	end
	local rarity = Rarities.ById[def.Rarity]
	local rarityLabel = element(escape, "Card.Rarity", "TextLabel") :: TextLabel?
	if rarityLabel and rarity then
		rarityLabel.Text = rarity.DisplayNameUpper
		RarityFx.Apply(rarityLabel, def.Rarity)
	end
	local income = element(escape, "Card.Income", "TextLabel") :: TextLabel?
	if income then
		local zone = def.Zone
		if zone ~= nil then
			local zoneNumber: number = zone
			local ok, value = pcall(function(): number
				return Formulas.ItemIncome(zoneNumber, def.Rarity)
			end)
			income.Text = if ok then `+{Format.money(value)}/s` else ""
			income.Visible = ok
		else
			income.Visible = false -- Secret : toutes zones, pas de revenu de base unique
		end
	end
	local badge = element(escape, "Card.NewBadge", "GuiObject") :: GuiObject?
	if badge then
		badge.Visible = fresh
	end
end

-- API ----------------------------------------------------------------------------------------------------------

function CatchSceneController.GetState(): State
	return {
		Scenes = scenes,
		Active = scene ~= nil,
		Phase = phase,
		Outcome = lastOutcome,
		HomeIn = lastHomeIn,
		Cards = cards,
		LastNew = lastNew,
	}
end

function CatchSceneController.Start()
	local indexScript = Config:FindFirstChild("Index")
	if indexScript and indexScript:IsA("ModuleScript") then
		local ok, result = pcall(require, indexScript)
		if ok and type(result) == "table" and type((result :: any).Decode) == "function" then
			indexModule = result
			for id in (result :: any).Decode(localPlayer:GetAttribute((result :: any).Attribute)) do
				discovered[id] = true -- déjà là au départ : pas nouveau
			end
			localPlayer:GetAttributeChangedSignal((result :: any).Attribute):Connect(readDiscovered)
		end
	end
	local ok, err = pcall(function()
		local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
		Net.Client.CatchScene:Connect(function(night: boolean, outcome: string, homeIn: number, itemId: string?)
			CatchSceneController.Play(night == true, tostring(outcome), if type(homeIn) == "number" then homeIn else 0, itemId)
		end)
		Net.Client.ItemSecured:Connect(function(itemId: string)
			if type(itemId) == "string" then
				fillCard(itemId)
			end
		end)
	end)
	if not ok then
		sayOnce("net", `remotes CatchScene ou ItemSecured absents : {err}`)
	end
end

return CatchSceneController
