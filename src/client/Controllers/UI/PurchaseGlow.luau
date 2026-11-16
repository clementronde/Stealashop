--!strict
-- PurchaseGlow (vague 63, a209 ; liaison L-204 point 2, L-188 B « achat Robux » ; client) : la lueur arc-en-ciel
-- d'un achat Robux. Module d'aide rangé dans Controllers/UI (le Loader ne le démarre pas) : le contrôleur qui ouvre
-- l'invite d'achat de Roblox appelle PurchaseGlow.Show() au clic sur un prix Robux (RobuxShopController, a208).
--
--   Show()  UI_PurchaseGlow (écran de Clément, trouvé par son nom dans le PlayerGui) s'allume d'un coup avec son
--           RainbowBorder ; le UIGradient de RainbowBorder (le premier trouvé dedans) tourne de TurnsPerSecond tours
--           par seconde ; les écrans du HUD (Config/ShopFx.PurchaseGlow.HideScreens) se cachent par
--           Controllers/UI/HudMask, les autres écrans restent (la boutique ne se rouvre pas : son décor ne retombe
--           pas). Rappelé pendant une lueur : elle continue (le délai de sécurité repart).
--           Sans UI_PurchaseGlow ou sans RainbowBorder : ne fait rien.
--   Hide()  tout s'efface en FadeTime s (transparences de RainbowBorder et de ce qu'il contient vers 1), puis l'écran
--           et RainbowBorder reprennent leur état de Clément et le HUD revient. Appelé tout seul à
--           MarketplaceService.PromptProductPurchaseFinished ou PromptGamePassPurchaseFinished, et au bout de
--           Timeout s (filet de sécurité).
--   GetState() -> "Idle" | "Shown" | "Fading"   (bancs)
--
-- Couleurs : celles de Clément ; seulement si le UIGradient est resté blanc, les 5 couleurs de L-204 (Config).
-- Réglage « animations réduites » (Settings.VfxReduced, ou ReducedMotionEnabled de Roblox) : la lueur ne tourne pas.
-- Ce qui est touché, le temps de la lueur seulement : Enabled de l'écran, Visible de RainbowBorder, Rotation (et
-- Color s'il était blanc) du UIGradient, transparences pendant l'effacement ; tout est remis ensuite (sauf la couleur
-- écrite sur un dégradé blanc). Une connexion Heartbeat seulement pendant la lueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ShopFx = require(Config:WaitForChild("ShopFx"))
local Settings = require(Config:WaitForChild("Settings"))
local HudMask = require(script.Parent:WaitForChild("HudMask"))

local SPEC = ShopFx.PurchaseGlow
local SCREEN_PREFIX = "UI_"

export type State = "Idle" | "Shown" | "Fading"

-- Une transparence à effacer, et sa valeur de Clément.
type Fader = { object: Instance, property: string, base: number }

type Glow = {
	gui: ScreenGui,
	border: GuiObject,
	enabled: boolean, -- Enabled de Clément
	visible: boolean, -- Visible de Clément
	gradient: UIGradient?,
	rotation: number,
	shownAt: number,
	fadeAt: number?, -- os.clock() du début de l'effacement
	faders: { Fader }, -- transparences à effacer (vide hors effacement)
	token: number,
}

local PurchaseGlow = {}

local localPlayer = Players.LocalPlayer
local current: Glow? = nil
local heartbeat: RBXScriptConnection? = nil
local listening = false
local tokens = 0
local turning = true

local HIDE: { [string]: boolean } = {}
for _, name in SPEC.HideScreens do
	HIDE[name] = true
end

local function readReduced(): boolean
	if Settings.VfxReduced(localPlayer) then
		return true
	end
	local ok, value = pcall(function(): any
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- Le dégradé est resté blanc (pas de couleurs de Clément) : les 5 couleurs de L-204.
local function paint(gradient: UIGradient)
	local keys = gradient.Color.Keypoints
	for _, key in keys do
		local c = key.Value
		if c.R < 0.999 or c.G < 0.999 or c.B < 0.999 then
			return
		end
	end
	local list: { ColorSequenceKeypoint } = {}
	local count = #SPEC.Colors
	for index, hex in SPEC.Colors do
		table.insert(list, ColorSequenceKeypoint.new(if count > 1 then (index - 1) / (count - 1) else 0, Color3.fromHex(hex)))
	end
	gradient.Color = ColorSequence.new(list)
end

local function faders(border: GuiObject): { Fader }
	local list: { Fader } = {}
	local function add(object: Instance, property: string)
		local value = (object :: any)[property]
		if type(value) == "number" and value < 1 then
			table.insert(list, { object = object, property = property, base = value })
		end
	end
	local all = border:GetDescendants()
	table.insert(all, 1, border)
	for _, object in all do
		if object:IsA("GuiObject") then
			add(object, "BackgroundTransparency")
		end
		if object:IsA("ImageLabel") or object:IsA("ImageButton") then
			add(object, "ImageTransparency")
		end
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			add(object, "TextTransparency")
		end
		if object:IsA("UIStroke") then
			add(object, "Transparency")
		end
	end
	return list
end

local function stopHeartbeat()
	local connection = heartbeat
	heartbeat = nil
	if connection then
		connection:Disconnect()
	end
end

-- Tout reprend l'état de Clément, le HUD revient.
local function finish(glow: Glow)
	if current == glow then
		current = nil
	end
	stopHeartbeat()
	for _, fader in glow.faders do
		(fader.object :: any)[fader.property] = fader.base
	end
	local gradient = glow.gradient
	if gradient then
		gradient.Rotation = glow.rotation
	end
	glow.border.Visible = glow.visible
	glow.gui.Enabled = glow.enabled
	HudMask.Pop(SPEC.MaskKey)
end

local function step()
	local glow = current
	if glow == nil then
		stopHeartbeat()
		return
	end
	if glow.gui.Parent == nil or glow.border.Parent == nil then
		finish(glow)
		return
	end
	local now = os.clock()
	local gradient = glow.gradient
	if gradient and turning then
		gradient.Rotation = (glow.rotation + 360 * SPEC.TurnsPerSecond * (now - glow.shownAt)) % 360
	end
	local fadeAt = glow.fadeAt
	if fadeAt ~= nil then
		local u = if SPEC.FadeTime > 0 then math.clamp((now - fadeAt) / SPEC.FadeTime, 0, 1) else 1
		if u >= 1 then
			finish(glow)
			return
		end
		for _, fader in glow.faders do
			(fader.object :: any)[fader.property] = fader.base + (1 - fader.base) * u
		end
	end
end

local function listen()
	if listening then
		return
	end
	listening = true
	local market = game:GetService("MarketplaceService")
	market.PromptProductPurchaseFinished:Connect(function()
		PurchaseGlow.Hide()
	end)
	market.PromptGamePassPurchaseFinished:Connect(function()
		PurchaseGlow.Hide()
	end)
end

function PurchaseGlow.Show()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local found = if playerGui then playerGui:FindFirstChild(SPEC.Screen) else nil
	if found == nil or not found:IsA("ScreenGui") then
		return
	end
	local gui = found :: ScreenGui
	local borderFound = gui:FindFirstChild(SPEC.Element, true)
	if borderFound == nil or not borderFound:IsA("GuiObject") then
		return
	end
	local border = borderFound :: GuiObject
	listen()
	tokens += 1
	local token = tokens
	local glow = current
	if glow ~= nil and (glow.gui ~= gui or glow.border ~= border) then
		finish(glow) -- copie neuve de l'écran : l'ancienne lueur s'arrête
		glow = nil
	end
	if glow == nil then
		local gradientFound = border:FindFirstChildWhichIsA("UIGradient", true)
		local gradient: UIGradient? = if gradientFound then gradientFound :: UIGradient else nil
		local created: Glow = {
			gui = gui,
			border = border,
			enabled = gui.Enabled,
			visible = border.Visible,
			gradient = gradient,
			rotation = if gradient then gradient.Rotation else 0,
			shownAt = os.clock(),
			fadeAt = nil,
			faders = {},
			token = token,
		}
		if gradient then
			paint(gradient)
		end
		current = created
		glow = created
	else
		-- rappelée pendant une lueur, ou pendant l'effacement : elle reste allumée
		for _, fader in glow.faders do
			(fader.object :: any)[fader.property] = fader.base
		end
		glow.faders = {}
		glow.fadeAt = nil
		glow.token = token
	end
	turning = not readReduced()
	gui.Enabled = true
	border.Visible = true
	-- Le HUD se cache ; les autres écrans UI_* restent (dont celui de l'achat et la boutique ouverte).
	local keep: { string } = { SPEC.Screen }
	for _, child in (playerGui :: PlayerGui):GetChildren() do
		if child:IsA("ScreenGui") and string.sub(child.Name, 1, #SCREEN_PREFIX) == SCREEN_PREFIX and not HIDE[child.Name] then
			table.insert(keep, child.Name)
		end
	end
	HudMask.Push(SPEC.MaskKey, { KeepScreens = keep })
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
	task.delay(SPEC.Timeout, function()
		local shown = current
		if shown ~= nil and shown.token == token then
			PurchaseGlow.Hide()
		end
	end)
end

function PurchaseGlow.Hide()
	local glow = current
	if glow == nil or glow.fadeAt ~= nil then
		return
	end
	glow.faders = faders(glow.border)
	glow.fadeAt = os.clock()
	if SPEC.FadeTime <= 0 then
		finish(glow)
	end
end

function PurchaseGlow.GetState(): State
	local glow = current
	if glow == nil then
		return "Idle"
	end
	return if glow.fadeAt ~= nil then "Fading" else "Shown"
end

return PurchaseGlow
