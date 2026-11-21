--!strict
-- HelpInviteController (client, vague 73, a256 ; liaison L-242 point 6 ; valeurs : Config/HelpInvite) : le conseil
-- après une capture, dans l'écran UI_HelpInvite de Clément (facultatif : sans lui, rien).
--
-- Remote CatchScene (GuardService, au seul joueur attrapé) : on attend la fin de la scène de capture
-- (CatchSceneController.GetState().Active, HelpInvite.MaxWait s au plus), puis Delay s. Le magasin PNJ (tag NPCStore,
-- attribut Zone) le plus proche du joueur au moment de la capture donne la zone ; Shared/AdvicePanel.levels compare
-- la force (Damage) et la vitesse (ShownSpeed) du joueur à celles conseillées : force pas « vert » → StrengthText,
-- sinon vitesse pas « vert » → SpeedText, sinon rien. Pas de carte de nuit (HelpInvite.Night), ni deux en moins de
-- Cooldown s. Card.Message reçoit le texte ; InviteButton ouvre l'invitation de Roblox (InviteController.Prompt) et
-- éteint l'écran ; CloseButton l'éteint ; seul, il s'éteint après Duration s. Fermeture par Controllers/UI/Motion.Close
-- (Card a Appear = Pop : UiMotionController joue l'entrée). Seuls Enabled de l'écran et Text de Message sont touchés.
--
-- API (client, bancs et barre de commande) :
--   HelpInviteController.Show(kind)  kind = "Strength" ou "Speed" : montre la carte tout de suite (sans Cooldown)
--   HelpInviteController.KindFor(zone) -> "Strength" | "Speed" | nil   le conseil pour cette zone, chez ce joueur
--   HelpInviteController.GetState() -> { Shown: boolean, Kind: string?, Count: number }

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local HelpInvite = require(Config:WaitForChild("HelpInvite"))
local Zones = require(Config:WaitForChild("Zones"))
local AdvicePanel = require(Shared:WaitForChild("AdvicePanel"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

type InviteApi = { Prompt: () -> () }
type SceneApi = { GetState: () -> { Active: boolean } }

local STORE_TAG = "NPCStore"
local ZONE_ATTRIBUTE = "Zone"

local HelpInviteController = {}

-- a290 (L-270) : signal de clic de Controllers/UI/Motion.Activated (relâché dans le bord du bouton écrasé par
-- Press = Squash compris, un seul clic par appui) ; sans Motion (banc), l'Activated de Roblox.
local function clicked(button: GuiButton): RBXScriptSignal
	local ui = script.Parent:FindFirstChild("UI")
	local module = if ui then ui:FindFirstChild("Motion") else nil
	if module and module:IsA("ModuleScript") then
		local ok, motion = pcall(require, module)
		if ok and type(motion) == "table" and type((motion :: any).Activated) == "function" then
			return (motion :: any).Activated(button)
		end
	end
	return button.Activated
end


local localPlayer = Players.LocalPlayer
local shownKind: string? = nil
local count = 0
local lastShown = -math.huge
local token = 0
local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

local function screen(): ScreenGui?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(HelpInvite.Screen) else nil
	return if gui and gui:IsA("ScreenGui") then gui :: ScreenGui else nil
end

local function hide()
	token += 1
	shownKind = nil
	local gui = screen()
	if gui == nil or not gui.Enabled then
		return
	end
	-- Controllers/UI/Motion s'il est là (fermeture courte), sinon d'un coup.
	local motion: any = nil
	local ui = script.Parent:FindFirstChild("UI")
	local module = if ui then ui:FindFirstChild("Motion") else nil
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		motion = if ok and type(result) == "table" then result else nil
	end
	if motion then
		motion.Close(gui)
	else
		gui.Enabled = false
	end
end

local function bind(gui: ScreenGui)
	if bound[gui] then
		return
	end
	bound[gui] = true
	local invite = Find.path(gui, HelpInvite.InviteButton)
	if invite and invite:IsA("GuiButton") then
		clicked(invite :: GuiButton):Connect(function()
			local api: InviteApi? = sibling("InviteController")
			if api then
				api.Prompt()
			end
			hide()
		end)
	end
	local close = Find.path(gui, HelpInvite.CloseButton)
	if close and close:IsA("GuiButton") then
		clicked(close :: GuiButton):Connect(hide)
	end
end

function HelpInviteController.Show(kind: string)
	local gui = screen()
	if gui == nil then
		return
	end
	bind(gui)
	local message = Find.path(gui, HelpInvite.Message)
	if message and (message:IsA("TextLabel") or message:IsA("TextButton")) then
		(message :: any).Text = if kind == "Speed" then HelpInvite.SpeedText else HelpInvite.StrengthText
	end
	shownKind = kind
	count += 1
	lastShown = os.clock()
	token += 1
	local mine = token
	gui.Enabled = true
	if HelpInvite.Duration > 0 then
		task.delay(HelpInvite.Duration, function()
			if token == mine then
				hide()
			end
		end)
	end
end

function HelpInviteController.KindFor(zone: number): string?
	local def = Zones[zone]
	if def == nil then
		return nil
	end
	local damage, speed = AdvicePanel.levels(localPlayer, def)
	if damage ~= "Green" then
		return "Strength"
	elseif speed ~= "Green" then
		return "Speed"
	end
	return nil
end

-- Zone du magasin PNJ le plus proche du joueur, ou nil.
local function nearestZone(): number?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position
	local best: number? = nil
	local bestDistance = math.huge
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		local zone = store:GetAttribute(ZONE_ATTRIBUTE)
		if type(zone) == "number" and store:IsA("PVInstance") then
			local distance = ((store :: PVInstance):GetPivot().Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = zone, distance
			end
		end
	end
	return best
end

local function onCatch(night: boolean)
	if not HelpInvite.Enabled or (night and not HelpInvite.Night) then
		return
	end
	if os.clock() - lastShown < HelpInvite.Cooldown or screen() == nil then
		return
	end
	local zone = nearestZone()
	if zone == nil then
		return
	end
	local kind = HelpInviteController.KindFor(zone)
	if kind == nil then
		return
	end
	task.spawn(function()
		local scene: SceneApi? = sibling("CatchSceneController")
		local started = os.clock()
		task.wait() -- la scène démarre sur le même remote
		while scene and scene.GetState().Active
			and os.clock() - started < HelpInvite.MaxWait do
			task.wait(0.1)
		end
		task.wait(HelpInvite.Delay)
		HelpInviteController.Show(kind)
	end)
end

function HelpInviteController.GetState(): { Shown: boolean, Kind: string?, Count: number }
	local gui = screen()
	return { Shown = gui ~= nil and gui.Enabled, Kind = shownKind, Count = count }
end

function HelpInviteController.Start()
	if not HelpInvite.Enabled then
		return
	end
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	Net.Client.CatchScene:Connect(function(night: any)
		onCatch(night == true)
	end)
end

return HelpInviteController
