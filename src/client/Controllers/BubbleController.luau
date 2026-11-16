--!strict
-- BubbleController (vague 64, a214 ; client) : les bulles ×N du tapis à l'écran (fiche
-- docs/claude/notes/2026-11-16_video-bulles-multiplicateur.md ; valeurs : Config/Bubbles ; serveur : BubbleService).
--
-- Rôle :
--   - BubbleSpawn(id, N, lifetime) : une bulle « ×N » autour du joueur sur son tapis. C'est un BillboardGui rangé dans
--     le PlayerGui avec Adornee = HumanoidRootPart (dans Workspace, son bouton ne recevrait pas le clic : piège de la
--     fiche), décalé de StudsOffsetWorldSpace au hasard (Bubbles.Client.RadiusMin à RadiusMax studs autour, HeightMin
--     à HeightMax au-dessus, deux bulles écartées d'au moins MinAngleGap degrés), AlwaysOnTop, taille fixe à l'écran
--     (ScreenFraction de la hauteur, au moins MinPixels). Rendu : une copie de ReplicatedStorage/Assets/UI/
--     BB_TrainBubble de Clément s'il existe avec un bouton Button (MultiplierLabel reçoit « ×N », Shine est visible
--     à partir de ShineFrom ; la taille est la sienne) ; sinon un repli construit ici (disque à dégradé, anneau,
--     « ×N »). Apparition : Appear (0,35 → 1, Back Out) sur le UIScale PopScale du bouton (repris ou créé) ;
--   - clic (Activated) : la bulle gonfle (Claim, 1 → 1,2) et ClaimBubble(id) part au serveur, qui décide. Sans
--     réponse après ClaimTimeout s, elle redevient cliquable ;
--   - BubbleGone(id, "Claimed", gain) : « +gain Speed » (GainText, notre propre texte, pas celui de GainController)
--     monte à sa place, la bulle s'écrase (Squash) et le son Bubble_Pop part (absent : muet) ;
--     BubbleGone(id, "Expired" ou "Cleared") : elle gonfle un peu puis rétrécit (Expire, Shrink), sans son ;
--   - grosses valeurs (N ≥ ShineFrom) : le premier UIGradient du bouton tourne (ShineDegreesPerSecond) ;
--   - « animations réduites » (Settings.VfxReduced ou ReducedMotionEnabled de Roblox) : aucun tween ni rotation, la
--     bulle apparaît et part d'un coup, le texte reste en place puis disparaît ;
--   - poursuite : rien de caché. Les bulles n'existent qu'en séance sur le tapis de sa propre boutique (zone safe),
--     où aucun vigile ne poursuit ; la séance finie, le serveur les retire toutes.
-- Rien n'est laissé : chaque bulle et chaque texte est une copie détruite à la fin. Le modèle de Clément n'est jamais
-- modifié. Bubbles.Enabled = false : rien.
--
-- API (bancs, barre de commande en Studio) :
--   BubbleController.GetCount() -> number      bulles à l'écran

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bubbles = require(Config:WaitForChild("Bubbles"))
local Settings = require(Config:WaitForChild("Settings"))
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Format = require(Shared:WaitForChild("Format"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))

local SPEC = Bubbles.Client
local FALLBACK = SPEC.Fallback
local IS_STUDIO = RunService:IsStudio()

local SCALE_NAME = "PopScale"
local BUTTON_NAME = "Button"
local LABEL_NAME = "MultiplierLabel"
local SHINE_NAME = "Shine"
local MULTIPLIER_TEXT = "×%d"
-- Essais de place pour une nouvelle bulle (la première assez loin des autres est gardée).
local PLACE_TRIES = 12

type Phase = "Idle" | "Claiming" | "Leaving"

type View = {
	id: string,
	multiplier: number,
	gui: BillboardGui,
	button: GuiButton,
	scale: UIScale,
	gradient: UIGradient?, -- tourne si shine
	shine: boolean,
	angle: number, -- degrés autour du joueur
	phase: Phase,
	token: number, -- change à chaque clic (délai de ClaimTimeout)
	tween: Tween?,
}

local BubbleController = {}

local localPlayer = Players.LocalPlayer
local views: { [string]: View } = {}
local net: any = nil
local spinner: RBXScriptConnection? = nil
local warnedTemplate = false

local function reduced(): boolean
	if Settings.VfxReduced(localPlayer) then
		return true
	end
	local ok, value = pcall(function(): any
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

local function viewportHeight(): number
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize.Y else 720
end

local function diameter(): number
	return math.clamp(math.floor(viewportHeight() * SPEC.ScreenFraction), SPEC.MinPixels, SPEC.MaxPixels)
end

local function rootPart(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Écart (degrés, 0 à 180) entre deux angles.
local function angleGap(a: number, b: number): number
	local d = math.abs(a - b) % 360
	return if d > 180 then 360 - d else d
end

-- Angle (degrés) d'une nouvelle bulle, assez loin des autres si possible.
local function pickAngle(): number
	local angle = 0
	for _ = 1, PLACE_TRIES do
		angle = math.random() * 360
		local free = true
		for _, view in views do
			if angleGap(angle, view.angle) < SPEC.MinAngleGap then
				free = false
				break
			end
		end
		if free then
			break
		end
	end
	return angle
end

local function offsetFor(angle: number): Vector3
	local radius = SPEC.RadiusMin + math.random() * (SPEC.RadiusMax - SPEC.RadiusMin)
	local height = SPEC.HeightMin + math.random() * (SPEC.HeightMax - SPEC.HeightMin)
	local radians = math.rad(angle)
	return Vector3.new(math.cos(radians) * radius, height, math.sin(radians) * radius)
end

local function tween(object: Instance, info: { Time: number, Style: Enum.EasingStyle, Direction: Enum.EasingDirection }, goal: { [string]: any }): Tween
	local t = TweenService:Create(object, TweenInfo.new(info.Time, info.Style, info.Direction), goal)
	t:Play()
	return t
end

local function playTween(view: View, t: Tween)
	local previous = view.tween
	if previous then
		previous:Cancel()
	end
	view.tween = t
end

-- Le modèle de Clément (BillboardGui avec un bouton Button), ou nil.
local function template(): BillboardGui?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = if assets then assets:FindFirstChild("UI") else nil
	local model = if ui then ui:FindFirstChild(SPEC.Template) else nil
	if model and model:IsA("BillboardGui") then
		local button = model:FindFirstChild(BUTTON_NAME, true)
		if button and button:IsA("GuiButton") then
			return model
		end
		if IS_STUDIO and not warnedTemplate then
			warnedTemplate = true
			warn(`[BubbleController] {SPEC.Template} sans bouton {BUTTON_NAME} : bulle de repli construite par le code`)
		end
	end
	return nil
end

-- Repli construit par le code : disque à dégradé, anneau sombre, « ×N » en bas à droite.
local function buildFallback(multiplier: number, size: number, shine: boolean): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = SPEC.Template
	-- De la place autour du disque pour le « ×N » qui déborde et pour le gonflement.
	gui.Size = UDim2.fromOffset(math.ceil(size * 1.5), math.ceil(size * 1.5))
	gui.ClipsDescendants = false

	local button = Instance.new("TextButton")
	button.Name = BUTTON_NAME
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BorderSizePixel = 0
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90 -- clair en haut, saturé en bas
	gradient.Color = if shine
		then ColorSequence.new(FALLBACK.ShineTop, FALLBACK.ShineBottom)
		else ColorSequence.new(FALLBACK.Top, FALLBACK.Bottom)
	gradient.Parent = button

	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = math.max(2, size * FALLBACK.StrokeFraction)
	ring.Color = if shine then FALLBACK.ShineStroke else FALLBACK.Stroke
	ring.Parent = button

	local labelHeight = math.max(14, math.floor(size * FALLBACK.LabelFraction))
	local label = Instance.new("TextLabel")
	label.Name = LABEL_NAME
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, math.floor(labelHeight * 0.6), 1, math.floor(labelHeight * 0.3))
	label.Size = UDim2.fromOffset(labelHeight * 3, labelHeight)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = FALLBACK.LabelColor
	label.Rotation = FALLBACK.LabelRotation
	label.Text = string.format(MULTIPLIER_TEXT, multiplier)
	label.Parent = button

	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Thickness = math.max(1.5, labelHeight * 0.1)
	outline.Color = FALLBACK.LabelStroke
	outline.Parent = label

	return gui
end

local function firstGradient(root: Instance): UIGradient?
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("UIGradient") then
			return descendant
		end
	end
	return nil
end

local function stopSpinnerIfIdle()
	for _, view in views do
		if view.shine and view.gradient then
			return
		end
	end
	local connection = spinner
	if connection then
		connection:Disconnect()
		spinner = nil
	end
end

local function startSpinner()
	if spinner ~= nil or reduced() then
		return
	end
	spinner = RunService.RenderStepped:Connect(function(dt: number)
		if reduced() then
			return
		end
		for _, view in views do
			local gradient = view.gradient
			if view.shine and gradient then
				gradient.Rotation = (gradient.Rotation + SPEC.ShineDegreesPerSecond * dt) % 360
			end
		end
	end)
end

local function destroyView(view: View)
	local t = view.tween
	if t then
		t:Cancel()
	end
	view.gui:Destroy()
end

-- « +gain Speed » qui monte à la place de la bulle puis s'efface (fiche : vie environ 1 s).
local function showGain(view: View, gain: number)
	local root = rootPart()
	if root == nil or gain <= 0 then
		return
	end
	local text = SPEC.GainText
	local screen = viewportHeight()
	local height = math.max(text.MinPixels, math.floor(screen * text.HeightFraction))
	local rise = math.floor(screen * text.RiseFraction)
	local calm = reduced()

	local gui = Instance.new("BillboardGui")
	gui.Name = "BubbleGain"
	gui.Size = UDim2.fromOffset(height * 8, height + rise)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	gui.Adornee = root
	gui.StudsOffsetWorldSpace = view.gui.StudsOffsetWorldSpace

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = UiMotion.FloatGain.Colors.Speed
	label.Text = string.format(text.Text, Format.short(gain))
	label.TextTransparency = if calm then 0 else 1
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = math.max(1.5, height * 0.1)
	stroke.Color = text.StrokeColor
	stroke.Transparency = if calm then 0 else 1
	stroke.Parent = label

	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	if not calm then
		local fadeIn = { Time = text.FadeIn, Style = Enum.EasingStyle.Linear, Direction = Enum.EasingDirection.Out }
		tween(label, fadeIn, { TextTransparency = 0 })
		tween(stroke, fadeIn, { Transparency = 0 })
		tween(
			label,
			{ Time = text.Life, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
			{ Position = UDim2.new(0.5, 0, 1, -rise) }
		)
		task.delay(math.max(0, text.Life - text.FadeOut), function()
			if gui.Parent == nil then
				return
			end
			local fadeOut = { Time = text.FadeOut, Style = Enum.EasingStyle.Linear, Direction = Enum.EasingDirection.In }
			tween(label, fadeOut, { TextTransparency = 1 })
			tween(stroke, fadeOut, { Transparency = 1 })
		end)
	end
	task.delay(text.Life, function()
		gui:Destroy()
	end)
end

local function playPop()
	local sound = MarkerSounds.find(SPEC.Sound)
	if sound then
		MarkerSounds.playSound(sound, nil)
	end
end

-- La bulle part : prise (écrasement et son) ou expirée / retirée (petit gonflement puis rétrécissement).
local function leave(view: View, claimed: boolean)
	if views[view.id] == view then
		views[view.id] = nil
	end
	if view.phase == "Leaving" then
		return
	end
	view.phase = "Leaving"
	view.button.Active = false
	stopSpinnerIfIdle()
	if claimed then
		playPop()
	end
	if reduced() then
		destroyView(view)
		return
	end
	if claimed then
		local t = tween(view.scale, SPEC.Squash, { Scale = 0 })
		playTween(view, t)
		t.Completed:Once(function()
			view.gui:Destroy()
		end)
		return
	end
	local grow = tween(view.scale, SPEC.Expire, { Scale = SPEC.Expire.To })
	playTween(view, grow)
	grow.Completed:Once(function(state: Enum.PlaybackState)
		if state ~= Enum.PlaybackState.Completed or view.gui.Parent == nil then
			return
		end
		local shrink = tween(view.scale, SPEC.Shrink, { Scale = 0 })
		view.tween = shrink
		shrink.Completed:Once(function()
			view.gui:Destroy()
		end)
	end)
end

local function claim(view: View)
	if view.phase ~= "Idle" or views[view.id] ~= view then
		return
	end
	view.phase = "Claiming"
	view.token += 1
	local token = view.token
	if not reduced() then
		playTween(view, tween(view.scale, SPEC.Claim, { Scale = SPEC.Claim.To }))
	end
	if net then
		net.Client.ClaimBubble:Fire(view.id)
	end
	task.delay(SPEC.ClaimTimeout, function()
		local phase: Phase = view.phase -- relu après le délai (l'ancien solveur garde l'affinage d'avant)
		if phase == "Claiming" and view.token == token and views[view.id] == view then
			-- Pas de réponse (refus de débit, appel perdu) : elle redevient cliquable.
			view.phase = "Idle"
			if reduced() then
				view.scale.Scale = 1
			else
				playTween(view, tween(view.scale, SPEC.Claim, { Scale = 1 }))
			end
		end
	end)
end

local function onSpawn(id: string, multiplier: number, lifetime: number)
	if not Bubbles.Enabled or views[id] ~= nil then
		return
	end
	local root = rootPart()
	if root == nil then
		return -- pas de perso : le serveur la fera expirer
	end
	local size = diameter()
	local shine = multiplier >= SPEC.ShineFrom
	local model = template()
	local gui: BillboardGui
	if model then
		gui = model:Clone()
		local label = gui:FindFirstChild(LABEL_NAME, true)
		if label and label:IsA("TextLabel") then
			label.Text = string.format(MULTIPLIER_TEXT, multiplier)
		end
		local shineObject = gui:FindFirstChild(SHINE_NAME, true)
		if shineObject and shineObject:IsA("GuiObject") then
			shineObject.Visible = shine
		end
	else
		gui = buildFallback(multiplier, size, shine)
	end
	local button = gui:FindFirstChild(BUTTON_NAME, true) :: GuiButton
	button.Active = true
	local scale: UIScale
	local existing = button:FindFirstChild(SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		scale = existing
	else
		scale = Instance.new("UIScale")
		scale.Name = SCALE_NAME
		scale.Parent = button
	end

	local angle = pickAngle()
	gui.Adornee = root
	gui.StudsOffsetWorldSpace = offsetFor(angle)
	gui.AlwaysOnTop = true
	gui.Active = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local view: View = {
		id = id,
		multiplier = multiplier,
		gui = gui,
		button = button,
		scale = scale,
		gradient = if shine then firstGradient(button) else nil,
		shine = shine,
		angle = angle,
		phase = "Idle",
		token = 0,
		tween = nil,
	}
	views[id] = view
	button.Activated:Connect(function()
		claim(view)
	end)

	if reduced() then
		scale.Scale = 1
	else
		scale.Scale = SPEC.Appear.From
		playTween(view, tween(scale, SPEC.Appear, { Scale = 1 }))
	end
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	if view.shine and view.gradient then
		startSpinner()
	end

	-- Filet de sécurité : le serveur dit quand elle part ; sans nouvelles, elle part un peu après sa fin.
	task.delay(lifetime + 1, function()
		if views[id] == view then
			leave(view, false)
		end
	end)
end

local function onGone(id: string, reason: string, gain: number?)
	local view = views[id]
	if view == nil then
		return
	end
	if reason == "Claimed" then
		showGain(view, gain or 0)
		leave(view, true)
	else
		leave(view, false)
	end
end

-- Perso retiré (mort, réapparition) : tout part d'un coup ; le serveur retire aussi les bulles.
local function clearAll()
	for id, view in views do
		views[id] = nil
		destroyView(view)
	end
	stopSpinnerIfIdle()
end

function BubbleController.GetCount(): number
	local count = 0
	for _ in views do
		count += 1
	end
	return count
end

function BubbleController.Start()
	if not Bubbles.Enabled then
		return
	end
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	net.Client.BubbleSpawn:Connect(onSpawn)
	net.Client.BubbleGone:Connect(onGone)
	localPlayer.CharacterRemoving:Connect(clearAll)
end

return BubbleController
