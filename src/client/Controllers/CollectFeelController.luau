--!strict
-- CollectFeelController (client, a401, vague GC4) : l'encaissement sur une plaque comme dans la vidéo de Cantin
-- (fiche docs/references/Encaissement-Base.md, sections 3, 7, 8 et 10 ; valeurs : Config/UiMotion.CollectFeel, V0).
--
-- Rôle (joueur local, sur ses plaques seulement) :
--   - au contact (DisplayController.OnCollect, remote CashCollect) : son Cash_Pad (facultatif) et vignette plein écran
--     UI_HUD.CollectGlow (ImageLabel facultatif de Clément : monte, tient, s'efface ; coupée par VISUAL EFFECTS sur OFF ;
--     Visible et ImageTransparency d'origine remis à la fin ; un 2e ramassage repart de l'opacité du moment) ;
--   - départ des billets (VfxController.OnCollectStart) : son Cash_Whoosh (facultatif) ;
--   - chiffre Cash : GainController le retient au contact (HudController.HoldCash) et le confie à Hold ; il est relâché
--     (il défile, HudController) à la 1re arrivée de billet (VfxController.OnCollectArrive), avec le groupe argent CashRow
--     qui grossit (PopTo) et Cash_Collect ; chaque arrivée suivante : ressaut d'environ 1 % (BounceTo) et tic Cash_Tick
--     (facultatif) de plus en plus aigu (TickSemitones en tout, PlaybackSpeed sur une copie) ; EndDelay s après la
--     dernière arrivée, CashRow revient à 1 ;
--   - ordre des messages : l'attribut Cash (Hold) et le remote CashCollect (billets) arrivent à peu près ensemble, dans
--     un ordre ou dans l'autre : le premier arrivé attend l'autre. Aucun billet annoncé FallbackDelay s après la hausse
--     (VISUAL EFFECTS sur OFF, compteur ou modèles absents, encaissement automatique) : comme avant, le chiffre défile
--     tout de suite, CashRow sursaute (CashBump) et Cash_Collect part. Billets annoncés mais aucun arrivé en MaxWait s :
--     relâché quand même (et HudController relâche de toute façon une retenue oubliée).
-- Rien n'est créé dans l'UI ; les éléments de Clément ne sont changés que pendant l'animation (UIScale passager de
-- Motion sur CashRow, Visible et ImageTransparency de CollectGlow remis à la fin).
--
-- API (client) :
--   CollectFeelController.Hold(total, releases) -> boolean
--       GainController : hausse de Cash venue d'une plaque, `releases` relâchent le chiffre. false : pas pris en charge
--       (CollectFeel.Enabled = false, billets absents du jeu) : l'appelant fait comme avant.
--   CollectFeelController.GetState() -> { Sessions: number, Waiting: boolean, Popped: boolean, Glows: number }   (banc)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiMotion = require(Shared:WaitForChild("Config"):WaitForChild("UiMotion"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

local FEEL: any = (UiMotion :: any).CollectFeel
local IS_STUDIO = RunService:IsStudio()
local HUD_SCREEN = "UI_HUD" -- contrat 2.2
local CASH_LABEL = "Cash"
local CASH_ROW = "CashRow"
local SOUND_LIFETIME = 5 -- V0 : s de vie au plus d'une copie de son (si son Ended ne vient pas)

-- Une hausse de Cash d'une plaque et/ou une vague de billets, liées l'une à l'autre dès que les deux sont là.
type Session = {
	releases: { () -> () },
	released: boolean,
	rise: boolean, -- la hausse de Cash est arrivée (Hold)
	wave: number?, -- la vague de billets est arrivée (OnCollectStart)
}

local CollectFeelController = {}

local localPlayer = Players.LocalPlayer
local settingsApi: any = nil -- Config/Settings (VfxReduced)
local markerSounds: any = nil -- Shared/Anim/MarkerSounds (find, playSound)
local vfxApi: any = nil
local sessions: { [number]: Session } = {} -- [vague] = session
local waitingRise: Session? = nil -- chiffre retenu, billets pas encore annoncés
local waitingWave: Session? = nil -- billets annoncés, hausse de Cash pas encore vue
local popToken = 0
local popped = false -- CashRow grossi par une arrivée (jusqu'au retour à 1)
local glowToken = 0
local glowTween: Tween? = nil
local glows = 0 -- vignette en cours (0 ou 1)
type Origin = { visible: boolean, transparency: number }
local glowOrigin: { [ImageLabel]: Origin } = setmetatable({}, { __mode = "k" }) :: any
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[CollectFeel] {message}`)
	end
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	local value: any = result
	return if ok and type(value) == "table" then value else nil
end

local function optionalModule(parent: Instance, name: string): any
	local module = parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	local value: any = result
	return if ok and type(value) == "table" then value else nil
end

local function hudScreen(): ScreenGui?
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if gui then gui:FindFirstChild(HUD_SCREEN) else nil
	return if screen and screen:IsA("ScreenGui") then screen :: ScreenGui else nil
end

-- Le groupe argent : CashRow (ancêtre du nombre Cash), sinon le nombre lui-même ; nil sans HUD.
local function cashRow(): GuiObject?
	local screen = hudScreen()
	local label = if screen then Find.path(screen, CASH_LABEL) else nil
	if label == nil or not label:IsA("GuiObject") then
		return nil
	end
	local ancestor = label:FindFirstAncestor(CASH_ROW)
	if ancestor and ancestor:IsA("GuiObject") then
		return ancestor :: GuiObject
	end
	return label :: GuiObject
end

-- Son facultatif `name` (Assets/Sounds), joué en 2D à `speed` × sa vitesse ; absent : muet (une ligne en Studio).
local function playOptional(name: string, speed: number)
	local sounds = markerSounds
	if sounds == nil then
		return
	end
	local ok, template = pcall(sounds.find, name)
	if not ok or template == nil then
		sayOnce(name, `son « {name} » absent de ReplicatedStorage/Assets/Sounds : muet (facultatif)`)
		return
	end
	-- Une copie à la hauteur voulue, comme MarkerSounds.playSound (son 2D, détruite à la fin).
	local source = template :: Sound
	local copy = source:Clone()
	copy.PlaybackSpeed = source.PlaybackSpeed * speed
	copy.Parent = SoundService
	copy.Ended:Once(function()
		copy:Destroy()
	end)
	Debris:AddItem(copy, SOUND_LIFETIME)
	copy:Play()
end

local function reducedVfx(): boolean
	local api = settingsApi
	if api == nil or type(api.VfxReduced) ~= "function" then
		return false
	end
	local ok, result = pcall(api.VfxReduced, localPlayer)
	return ok and result == true
end

------------------------------------------------------------------------------
-- Groupe argent du HUD
------------------------------------------------------------------------------

local function scaleRow(to: number, time: number, style: Enum.EasingStyle)
	local row = cashRow()
	if row then
		Motion.ScaleTo(row, to, TweenInfo.new(time, style, Enum.EasingDirection.Out))
	end
end

-- Retour de CashRow à 1, EndDelay s après la dernière arrivée (chaque arrivée repousse le retour).
local function scheduleEnd()
	popToken += 1
	local token = popToken
	task.delay(FEEL.EndDelay, function()
		if popToken == token then
			popped = false
			scaleRow(1, FEEL.EndTime, Enum.EasingStyle.Quad)
		end
	end)
end

local function release(session: Session)
	if session.released then
		return
	end
	session.released = true
	for _, fn in session.releases do
		pcall(fn)
	end
	session.releases = {}
end

-- Comme avant a401 : chiffre relâché tout de suite, CashRow sursaute, Cash_Collect.
local function releaseNow(session: Session)
	release(session)
	local row = cashRow()
	if row then
		local bump = UiMotion.CashBump
		Motion.Pop(row, bump.From, TweenInfo.new(bump.Time, bump.Style, bump.Direction))
	end
	Motion.PlaySound(FEEL.Sounds.Arrive)
end

function CollectFeelController.Hold(total: number, releases: { () -> () }): boolean
	if FEEL == nil or FEEL.Enabled ~= true or vfxApi == nil or type(total) ~= "number" then
		return false
	end
	local session = waitingWave
	if session then
		-- Billets déjà partis : la hausse s'y accroche ; déjà arrivés (rare) : relâchée tout de suite.
		waitingWave = nil
		session.rise = true
		if session.released then
			for _, fn in releases do
				pcall(fn)
			end
		else
			for _, fn in releases do
				table.insert(session.releases, fn)
			end
		end
		return true
	end
	local previous = waitingRise
	if previous then
		-- Deux hausses avant les billets : elles attendent ensemble.
		for _, fn in releases do
			table.insert(previous.releases, fn)
		end
		return true
	end
	local created: Session = { releases = table.clone(releases), released = false, rise = true, wave = nil }
	waitingRise = created
	task.delay(FEEL.FallbackDelay, function()
		if waitingRise == created then
			waitingRise = nil
			releaseNow(created)
		end
	end)
	return true
end

local function onStart(total: number, wave: number)
	playOptional(FEEL.Sounds.Whoosh, 1)
	local session = waitingRise
	if session and not session.released then
		waitingRise = nil
	else
		local created: Session = { releases = {}, released = false, rise = false, wave = nil }
		session = created
		waitingWave = created
	end
	local current: Session = session :: Session
	current.wave = wave
	sessions[wave] = current
	task.delay(FEEL.MaxWait, function()
		if sessions[wave] == current and not current.released then
			sessions[wave] = nil
			if waitingWave == current then
				waitingWave = nil
			end
			releaseNow(current)
		end
	end)
end

local function onArrive(rank: number, total: number, wave: number)
	local session = sessions[wave]
	if rank >= total then
		sessions[wave] = nil
		if session and waitingWave == session then
			waitingWave = nil -- hausse jamais vue : une hausse plus tardive fera comme avant (FallbackDelay)
		end
	end
	scheduleEnd() -- avant le ressaut : son retour à PopTo est annulé par une arrivée plus récente
	if session and not session.released then
		-- 1re arrivée : le chiffre défile, le groupe argent grossit, Cash_Collect.
		release(session)
		Motion.PlaySound(FEEL.Sounds.Arrive)
		popped = true
		scaleRow(FEEL.PopTo, FEEL.PopTime, Enum.EasingStyle.Quad)
	else
		-- Arrivée suivante : ressaut et tic plus aigu.
		local step = if total > 1 then (rank - 1) / (total - 1) else 0
		playOptional(FEEL.Sounds.Tick, 2 ^ (FEEL.TickSemitones * step / 12))
		if popped then
			scaleRow(FEEL.BounceTo, FEEL.BounceUp, Enum.EasingStyle.Quad)
			local token = popToken
			task.delay(FEEL.BounceUp, function()
				if popped and popToken == token then
					scaleRow(FEEL.PopTo, FEEL.BounceDown, Enum.EasingStyle.Quad)
				end
			end)
		else
			popped = true
			scaleRow(FEEL.PopTo, FEEL.PopTime, Enum.EasingStyle.Quad)
		end
	end
end

------------------------------------------------------------------------------
-- Vignette UI_HUD.CollectGlow
------------------------------------------------------------------------------

local function glow()
	if reducedVfx() then
		return
	end
	local screen = hudScreen()
	if screen == nil or not screen.Enabled then
		return
	end
	local found = Find.path(screen, FEEL.Glow)
	if found == nil or not found:IsA("ImageLabel") then
		sayOnce("glow", `UI_HUD.{FEEL.Glow} (ImageLabel) absent : pas de vignette au ramassage (facultatif)`)
		return
	end
	local image = found :: ImageLabel
	local origin = glowOrigin[image]
	if origin == nil then
		local saved: Origin = { visible = image.Visible, transparency = image.ImageTransparency }
		origin = saved
		glowOrigin[image] = saved
	end
	local rest: Origin = origin :: Origin
	local previous = glowTween
	if previous then
		previous:Cancel()
	else
		glows += 1
	end
	glowToken += 1
	local token = glowToken
	image.Visible = true
	local function finish()
		if glowToken ~= token then
			return
		end
		glowTween = nil
		glows -= 1
		image.Visible = rest.visible
		image.ImageTransparency = rest.transparency
		glowOrigin[image] = nil
	end
	local rise = TweenService:Create(
		image,
		TweenInfo.new(FEEL.GlowIn, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ ImageTransparency = FEEL.GlowPeak }
	)
	glowTween = rise
	rise:Play()
	task.delay(FEEL.GlowIn + FEEL.GlowHold, function()
		if glowToken ~= token then
			return
		end
		local fade = TweenService:Create(
			image,
			TweenInfo.new(FEEL.GlowOut, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ ImageTransparency = 1 }
		)
		glowTween = fade
		fade.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				finish()
			end
		end)
		fade:Play()
	end)
end

local function onCollect()
	playOptional(FEEL.Sounds.Pad, 1)
	glow()
end

------------------------------------------------------------------------------

function CollectFeelController.GetState(): { Sessions: number, Waiting: boolean, Popped: boolean, Glows: number }
	local count = 0
	for _ in sessions do
		count += 1
	end
	return { Sessions = count, Waiting = waitingRise ~= nil or waitingWave ~= nil, Popped = popped, Glows = glows }
end

function CollectFeelController.Start()
	if FEEL == nil or FEEL.Enabled ~= true then
		return
	end
	local config = Shared:WaitForChild("Config")
	settingsApi = optionalModule(config, "Settings")
	local anim = Shared:FindFirstChild("Anim")
	markerSounds = if anim then optionalModule(anim, "MarkerSounds") else nil
	local display = sibling("DisplayController")
	if display and type(display.OnCollect) == "function" then
		local subscribe: any = display.OnCollect
		subscribe(onCollect)
	end
	local vfx = sibling("VfxController")
	if vfx and type(vfx.OnCollectStart) == "function" and type(vfx.OnCollectArrive) == "function" then
		local onStartOf: any = vfx.OnCollectStart
		onStartOf(onStart)
		local onArriveOf: any = vfx.OnCollectArrive
		onArriveOf(onArrive)
		vfxApi = vfx
	else
		sayOnce("vfx", "VfxController.OnCollectArrive absent : le chiffre défile au contact, comme avant")
	end
end

return CollectFeelController
