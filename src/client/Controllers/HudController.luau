--!strict
-- HudController (DEV-021, client) : branche l'écran UI_HUD de Clément (contrat 2.2 ; liaison L-026
-- et L-027 ; Partie 1, sections 5.3, 5.5 et 7.1).
--
-- Rôle :
--   - Cash (« $11.1B »), Income (« +$1.2K/s »), Speed, Strength et Damage (« 1.4K ») : écrits au
--     format court (Shared/Format) depuis les attributs du Player posés par le serveur : Cash
--     (DataService), Income (DisplayService), Speed et Strength (StatsService), Damage
--     (ToolService). Le client n'envoie rien. Attribut pas encore posé (profil en cours de
--     chargement) : « … ».
--   - HeistTimer : chrono du braquage (« HEIST: 7s »), visible pendant un vol, masqué le reste du
--     temps. Piloté par le remote HeistTimer(storeId, endsAt) que HeistController relaie (endsAt
--     en heure serveur, workspace:GetServerTimeNow() ; 0 = masquer). Plusieurs chronos à la fois
--     (deux magasins proches) : celui qui finit le plus tard, donc le plus récent.
--   - GuardMeter et son enfant Fill : visibles pendant une poursuite (ChaseController, remote
--     ChaseState). Largeur de Fill = proximité du vigile : pleine à la distance de capture
--     (Balance.Guard.CatchDistance), vide à l'avance qui fait abandonner le vigile
--     (Balance.Guard.GiveUpLead), linéaire entre les deux. Seule la largeur en Scale change.
--   - Battements de cœur sous Balance.Guard.HeartbeatDistance (ChaseController.IsClose) : le son
--     HEARTBEAT_SOUND de ReplicatedStorage/Assets/Sounds, en boucle ; silence s'il manque.
--   - Cache les éléments des fonctions pas encore livrées (Config/Features) : RobuxShopButton,
--     IndexButton, RebirthButton, NightCountdown, ReturnBaseButton.
-- Les éléments sont cherchés par leur nom parmi les descendants de l'écran (Contract/Find) : les
-- cadres autour (LeftRail, StatsPanel…) sont décoratifs et peuvent changer. Seuls les textes, la
-- visibilité et la largeur de Fill sont touchés (2.2, « Libre pour Ironix »), jamais un style.
-- Roblox copie UI_HUD de StarterGui dans PlayerGui ; un écran recréé (ResetOnSpawn) est rebranché.
--
-- API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Features = require(Config:WaitForChild("Features"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))

-- Ce que ce contrôleur utilise de HeistController (a10) et de ChaseController (a12).
type HeistApi = {
	OnTimer: (listener: (storeId: string, endsAt: number) -> ()) -> () -> (),
	GetTimers: () -> { [string]: number },
}
type ChaseApi = {
	IsChased: () -> boolean,
	GetDistance: () -> number?,
	IsClose: () -> boolean,
}

type Stat = {
	Attribute: string, -- attribut du Player, posé par le serveur
	Element: string, -- TextLabel du contrat 2.2
	Write: (value: number) -> string,
}

-- Écran branché.
type Hud = {
	gui: ScreenGui,
	stats: { [Stat]: TextLabel },
	heistTimer: TextLabel?,
	guardMeter: GuiObject?,
	fill: GuiObject?,
	fillSize: UDim2, -- taille de Fill posée par Clément : seule la largeur en Scale change
}

local SCREEN = "UI_HUD"

local STATS: { Stat } = {
	{ Attribute = "Cash", Element = "Cash", Write = Format.money },
	{ Attribute = "Income", Element = "Income", Write = Format.income },
	{ Attribute = "Speed", Element = "Speed", Write = Format.short },
	{ Attribute = "Strength", Element = "Strength", Write = Format.short },
	{ Attribute = "Damage", Element = "Damage", Write = Format.short },
}

-- Éléments cachés tant que leur fonction n'existe pas (Config/Features, liaison L-026).
local GATED: { { Element: string, Enabled: boolean } } = {
	{ Element = "RobuxShopButton", Enabled = Features.RobuxShop },
	{ Element = "IndexButton", Enabled = Features.Index },
	{ Element = "RebirthButton", Enabled = Features.Rebirth },
	{ Element = "NightCountdown", Enabled = Features.NightCycle },
	{ Element = "ReturnBaseButton", Enabled = Features.ReturnToBase },
}

-- V0 proposé, absent du doc : nom du son des battements de cœur (DEV-051), cherché comme les sons
-- des marqueurs (MarkerSounds.find : ReplicatedStorage/Assets/Sounds, sous-dossiers compris).
local HEARTBEAT_SOUND = "Chase_Heartbeat"
-- V0 proposé, absent du doc : texte d'une valeur pas encore posée par le serveur.
local UNKNOWN_TEXT = "…"

-- V0 proposé, absent du doc : texte du chrono « HEIST: 7s », en anglais (L-036).
local function timerText(seconds: number): string
	return `HEIST: {seconds}s`
end

local IS_STUDIO = RunService:IsStudio()
local CATCH_DISTANCE: number = Balance.Guard.CatchDistance
local GIVE_UP_LEAD: number = Balance.Guard.GiveUpLead

local HudController = {}

local localPlayer = Players.LocalPlayer
local heist: HeistApi? = nil
local chase: ChaseApi? = nil
local hud: Hud? = nil
local timers: { [string]: number } = {} -- storeId → endsAt (heure serveur)
local shownSeconds: number? = nil -- secondes affichées par HeistTimer ; nil = masqué
local chased = false -- GuardMeter affiché
local heartbeatOn = false
local heartbeatSound: Sound? = nil
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(message)
	end
end

-- Contrôleur voisin (même dossier), ou nil s'il manque.
local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		warnOnce(name, `[HUD] {name} absent : la partie du HUD qui en dépend reste cachée`)
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result
	end
	warnOnce(name, `[HUD] {name} : require impossible ({result}) ; la partie du HUD qui en dépend reste cachée`)
	return nil
end

-- Élément `name` de `root`, de la classe `class`, ou nil (un avertissement par élément, en Studio ;
-- le ContractChecker le signale aussi).
local function element(root: Instance, name: string, class: string): Instance?
	local found = Find.path(root, name)
	if found ~= nil and found:IsA(class) then
		return found
	end
	local where = `{root.Name}.{name}`
	warnOnce(where, if found then `[HUD] {where} n'est pas un {class} : ignoré` else `[HUD] {where} introuvable : ignoré`)
	return nil
end

-- Valeurs -------------------------------------------------------------------------------------

local function writeStat(stat: Stat)
	local current = hud
	local label = if current then current.stats[stat] else nil
	if label == nil then
		return
	end
	local value = localPlayer:GetAttribute(stat.Attribute)
	label.Text = if type(value) == "number" then stat.Write(value) else UNKNOWN_TEXT
end

-- Chrono du braquage --------------------------------------------------------------------------

local function onTimer(storeId: string, endsAt: number)
	if endsAt > 0 then
		timers[storeId] = endsAt
	else
		timers[storeId] = nil
	end
end

local function updateHeistTimer(current: Hud)
	local label = current.heistTimer
	if label == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local endsAt: number? = nil
	for storeId, at in timers do
		if at <= now then
			timers[storeId] = nil -- fini : le rideau est tombé
		elseif endsAt == nil or at > endsAt then
			endsAt = at
		end
	end
	local seconds = if endsAt then math.ceil(endsAt - now) else nil
	if seconds == shownSeconds then
		return
	end
	shownSeconds = seconds
	if seconds then
		label.Text = timerText(seconds)
		label.Visible = true
	else
		label.Visible = false
	end
end

-- Poursuite -----------------------------------------------------------------------------------

-- 1 = le vigile vous attrape, 0 = il abandonne.
local function proximity(distance: number): number
	return math.clamp((GIVE_UP_LEAD - distance) / (GIVE_UP_LEAD - CATCH_DISTANCE), 0, 1)
end

local function setFill(current: Hud, fraction: number)
	local fill = current.fill
	if fill then
		local size = current.fillSize
		fill.Size = UDim2.new(fraction, size.X.Offset, size.Y.Scale, size.Y.Offset)
	end
end

local function updateGuardMeter(current: Hud)
	local api = chase
	local active = api ~= nil and api.IsChased()
	if active ~= chased then
		chased = active
		local meter = current.guardMeter
		if meter then
			meter.Visible = active
		end
		if active then
			setFill(current, 0) -- jusqu'à la première mesure
		end
	end
	if api == nil or not active then
		return
	end
	local distance = api.GetDistance()
	if distance then
		setFill(current, proximity(distance))
	end
end

-- Battements de cœur, en boucle tant que le vigile est tout près.
local function setHeartbeat(on: boolean)
	if on == heartbeatOn then
		return
	end
	heartbeatOn = on
	if on and heartbeatSound == nil then
		local template = MarkerSounds.find(HEARTBEAT_SOUND)
		if template then
			local sound = template:Clone() :: Sound
			sound.Looped = true
			sound.Parent = SoundService -- son 2D, pour le joueur local seulement
			heartbeatSound = sound
		else
			warnOnce(
				HEARTBEAT_SOUND,
				`[HUD] son « {HEARTBEAT_SOUND} » absent de ReplicatedStorage/Assets/Sounds (DEV-051) : battements de cœur muets`
			)
		end
	end
	local sound = heartbeatSound
	if sound == nil then
		return
	end
	if on then
		sound:Play()
	else
		sound:Stop()
	end
end

-- Écran ---------------------------------------------------------------------------------------

local function bind(gui: ScreenGui)
	local stats: { [Stat]: TextLabel } = {}
	for _, stat in STATS do
		local label = element(gui, stat.Element, "TextLabel")
		if label then
			stats[stat] = label :: TextLabel
		end
	end
	local heistTimer = element(gui, "HeistTimer", "TextLabel") :: TextLabel?
	local meter = element(gui, "GuardMeter", "GuiObject") :: GuiObject?
	local fill = if meter then element(meter, "Fill", "GuiObject") :: GuiObject? else nil

	for _, gate in GATED do
		local target = if gate.Enabled then nil else Find.path(gui, gate.Element)
		if target and target:IsA("GuiObject") then
			target.Visible = false
		end
	end

	-- Chrono et jauge masqués jusqu'à la prochaine image (update les affiche s'il le faut).
	if heistTimer then
		heistTimer.Visible = false
	end
	if meter then
		meter.Visible = false
	end
	shownSeconds = nil
	chased = false

	hud = {
		gui = gui,
		stats = stats,
		heistTimer = heistTimer,
		guardMeter = meter,
		fill = fill,
		fillSize = if fill then fill.Size else UDim2.new(),
	}
	for _, stat in STATS do
		writeStat(stat)
	end
end

local function update()
	local api = chase
	setHeartbeat(api ~= nil and api.IsClose())
	local current = hud
	if current == nil or current.gui.Parent == nil then
		return
	end
	updateHeistTimer(current)
	updateGuardMeter(current)
end

function HudController.Start()
	heist = sibling("HeistController")
	chase = sibling("ChaseController")

	for _, stat in STATS do
		localPlayer:GetAttributeChangedSignal(stat.Attribute):Connect(function()
			writeStat(stat)
		end)
	end

	local heistApi = heist
	if heistApi then
		heistApi.OnTimer(onTimer)
		for storeId, endsAt in heistApi.GetTimers() do
			onTimer(storeId, endsAt)
		end
	end

	RunService.Heartbeat:Connect(update)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing)
	end
end

return HudController
