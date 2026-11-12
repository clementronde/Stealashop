--!strict
-- ZoneBannerController (client) : le bandeau d'entrée de zone de Clément, UI_ZoneBanner (liaison L-110,
-- contrat UI 2.2). Quand le joueur local passe une arche ZoneGate vers une autre zone (dans un sens
-- comme dans l'autre : ZoneGateController.OnZoneChanged), l'écran s'allume quelques secondes avec un
-- fondu, puis s'éteint. Rien pour le hub (zone 0), rien à l'arrivée dans le jeu. Rien n'est envoyé au
-- serveur.
--
-- Textes, en anglais, valeurs de Config/Zones (section 4) :
--   Banner.ZoneName  la ville de la zone (Zones[n].City : « LONDON », « TOKYO »…) ; zone sans ville
--                    (la zone 1, en attendant le nom de Clément) : son Theme en capitales (« MINI MART ») ;
--   Advice.Speed     « Speed 28 »    } mêmes textes, même règle et mêmes couleurs que les panneaux des
--   Advice.Damage    « Strength 80 » } magasins (Shared/AdvicePanel ; la force se lit « Strength N »
--                                      depuis L-108 point 5) ;
--   Difficulty       « Easy », « Medium » ou « Hard » : la moins bonne des deux couleurs du joueur
--                    (vert, orange, rouge), et le texte prend cette couleur.
-- Les couleurs sont refaites si les attributs Damage ou WalkSpeed du joueur changent pendant que le
-- bandeau est allumé.
--
-- Fondu (Config/UiMotion.ZoneBanner : FadeIn, Hold, FadeOut) : l'écran n'a pas de CanvasGroup, donc
-- chaque transparence de l'écran (fond, texte, contour du texte, image, UIStroke) va de 1 à la valeur
-- de Clément, y reste, puis repart à 1 ; à la fin l'écran est éteint (Enabled = false) et toutes les
-- transparences sont remises comme Clément les a faites. Un nouveau passage pendant que le bandeau est
-- allumé change les textes et repart pour une durée complète depuis l'opacité en cours.
-- Seuls Enabled, ces transparences pendant le fondu, les 4 textes et la couleur du texte de Speed,
-- Damage et Difficulty sont touchés : ni taille, ni position, ni style de Clément.
--
-- API (client) :
--   ZoneBannerController.Show(zone)   allume le bandeau de la zone (1 à 6), comme un passage d'arche
--                                     (essai dans Studio, barre de commande côté client).
--   ZoneBannerController.GetState() -> { Zone: number?, Shown: boolean, Alpha: number, Difficulty: Level? }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Zones = require(Config:WaitForChild("Zones"))
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local AdvicePanel = require(Shared:WaitForChild("AdvicePanel"))
local ZoneGateController = require(script.Parent:WaitForChild("ZoneGateController"))

export type Level = AdvicePanel.Level

export type BannerState = {
	Zone: number?,
	Shown: boolean,
	Alpha: number,
	Difficulty: Level?,
}

type Fade = {
	Object: Instance,
	Property: string,
	Shown: number, -- transparence de Clément
}

type Screen = {
	Gui: ScreenGui,
	Fades: { Fade },
	ZoneName: TextLabel?,
	Speed: TextLabel?,
	Damage: TextLabel?,
	Difficulty: TextLabel?,
}

local SETTINGS = UiMotion.ZoneBanner
local SCREEN_NAME: string = SETTINGS.Screen
local FADE_IN: number = SETTINGS.FadeIn
local HOLD: number = SETTINGS.Hold
local FADE_OUT: number = SETTINGS.FadeOut

-- Textes de L-110.
local DIFFICULTY_TEXT: { [Level]: string } = { Green = "Easy", Orange = "Medium", Red = "Hard" }
local RANK: { [Level]: number } = { Green = 1, Orange = 2, Red = 3 }

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local ZoneBannerController = {}

local playerGui: Instance? = nil
local screen: Screen? = nil
local shownZone: number? = nil
local difficulty: Level? = nil
local alpha = 0 -- 0 : transparent, 1 : comme Clément l'a fait
local fadeFrom = 0 -- opacité au départ du fondu d'entrée en cours
local elapsed = 0 -- s depuis le dernier Show
local connection: RBXScriptConnection? = nil
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string)
	if not IS_STUDIO or said[key] then
		return
	end
	said[key] = true
	warn(`[ZoneBannerController] {message}`)
end

local function label(gui: Instance, path: string): TextLabel?
	local found = Find.path(gui, path)
	if found and found:IsA("TextLabel") then
		return found
	end
	sayOnce(`element:{path}`, `{SCREEN_NAME}.{path} introuvable ou pas un TextLabel : ignoré`)
	return nil
end

-- Note une transparence à fondre (rien pour une valeur déjà à 1 : elle ne bouge pas).
local function addFade(fades: { Fade }, object: Instance, property: string)
	local value = (object :: any)[property]
	if type(value) == "number" and value < 1 then
		table.insert(fades, { Object = object, Property = property, Shown = value })
	end
end

local function collectFades(gui: ScreenGui): { Fade }
	local fades: { Fade } = {}
	for _, descendant in gui:GetDescendants() do
		if descendant:IsA("GuiObject") then
			addFade(fades, descendant, "BackgroundTransparency")
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
				addFade(fades, descendant, "TextTransparency")
				addFade(fades, descendant, "TextStrokeTransparency")
			elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				addFade(fades, descendant, "ImageTransparency")
			end
		elseif descendant:IsA("UIStroke") then
			addFade(fades, descendant, "Transparency")
		end
	end
	return fades
end

local function applyAlpha(target: Screen, value: number)
	for _, fade in target.Fades do
		(fade.Object :: any)[fade.Property] = if value >= 1 then fade.Shown else 1 - (1 - fade.Shown) * value
	end
end

-- L'écran du PlayerGui (refait par Roblox à la réapparition s'il a ResetOnSpawn), lu au repos : ses
-- transparences sont alors celles de Clément.
local function currentScreen(): Screen?
	local existing = screen
	if existing and existing.Gui.Parent ~= nil then
		return existing
	end
	screen = nil
	local parent = playerGui
	local gui = if parent then parent:FindFirstChild(SCREEN_NAME) else nil
	if gui == nil or not gui:IsA("ScreenGui") then
		sayOnce("screen", `{SCREEN_NAME} absent du PlayerGui : pas de bandeau d'entrée de zone (L-110)`)
		return nil
	end
	local built: Screen = {
		Gui = gui,
		Fades = collectFades(gui),
		ZoneName = label(gui, "Banner.ZoneName"),
		Speed = label(gui, "Advice.Speed"),
		Damage = label(gui, "Advice.Damage"),
		Difficulty = label(gui, "Difficulty"),
	}
	screen = built
	return built
end

local function recolor()
	local target = screen
	local zoneIndex = shownZone
	if target == nil or zoneIndex == nil then
		return
	end
	local damageLevel: Level, speedLevel: Level = AdvicePanel.levels(localPlayer, Zones[zoneIndex])
	local worst: Level = if RANK[damageLevel] >= RANK[speedLevel] then damageLevel else speedLevel
	difficulty = worst
	local damage, speed, difficultyLabel = target.Damage, target.Speed, target.Difficulty
	if damage then
		damage.TextColor3 = AdvicePanel.Colors[damageLevel]
	end
	if speed then
		speed.TextColor3 = AdvicePanel.Colors[speedLevel]
	end
	if difficultyLabel then
		difficultyLabel.Text = DIFFICULTY_TEXT[worst]
		difficultyLabel.TextColor3 = AdvicePanel.Colors[worst]
	end
end

local function stop()
	local running = connection
	connection = nil
	if running then
		running:Disconnect()
	end
	local target = screen
	if target then
		if target.Gui.Parent ~= nil then
			target.Gui.Enabled = false
		end
		applyAlpha(target, 1) -- au repos : comme Clément l'a fait
	end
	alpha, elapsed, fadeFrom = 0, 0, 0
	shownZone, difficulty = nil, nil
end

local function step(dt: number)
	local target = screen
	if target == nil or target.Gui.Parent == nil then
		screen = nil -- écran refait par Roblox (réapparition) : la copie neuve est au repos
		stop()
		return
	end
	elapsed += dt
	local fadeIn = FADE_IN * (1 - fadeFrom)
	if elapsed < fadeIn then
		alpha = fadeFrom + (1 - fadeFrom) * (elapsed / fadeIn)
	elseif elapsed < fadeIn + HOLD then
		alpha = 1
	elseif elapsed < fadeIn + HOLD + FADE_OUT then
		alpha = 1 - (elapsed - fadeIn - HOLD) / FADE_OUT
	else
		stop()
		return
	end
	applyAlpha(target, alpha)
end

-- API -----------------------------------------------------------------------------------------------

function ZoneBannerController.Show(zoneIndex: number)
	local zone = Zones[zoneIndex]
	if zone == nil then
		return
	end
	local target = currentScreen()
	if target == nil then
		return
	end
	shownZone = zoneIndex
	local zoneName, speed, damage = target.ZoneName, target.Speed, target.Damage
	if zoneName then
		local city: string? = zone.City
		zoneName.Text = if city then city else string.upper(zone.Theme)
	end
	if speed then
		speed.Text = AdvicePanel.speedText(zone)
	end
	if damage then
		damage.Text = AdvicePanel.strengthText(zone)
	end
	recolor()
	-- Repart pour une durée complète, depuis l'opacité en cours (0 si le bandeau était éteint).
	fadeFrom, elapsed = alpha, 0
	applyAlpha(target, alpha)
	target.Gui.Enabled = true
	if connection == nil then
		connection = RunService.Heartbeat:Connect(step)
	end
end

function ZoneBannerController.GetState(): BannerState
	return {
		Zone = shownZone,
		Shown = connection ~= nil,
		Alpha = alpha,
		Difficulty = difficulty,
	}
end

function ZoneBannerController.Start()
	playerGui = localPlayer:WaitForChild("PlayerGui")
	for _, attribute in { AdvicePanel.DamageAttribute, AdvicePanel.WalkSpeedAttribute } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(recolor)
	end
	ZoneGateController.OnZoneChanged(function(zone: number, _previous: number)
		if zone >= 1 then
			ZoneBannerController.Show(zone)
		end
	end)
end

return ZoneBannerController
