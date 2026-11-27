--!strict
-- PanelFocus (client, a492 ; liaison L-430, Clément 26/11 : « Quand un panneau est ouvert, tous les autres UI doivent
-- disparaître. ») : quelles fenêtres cachent tout le reste, et ce qui reste à l'écran. Module d'aide (sous-dossier UI :
-- le Loader ne le démarre pas), lu par UiMotionController (le masque, à la place de HudHide.Hide) et par UI/Motion (une
-- seule fenêtre à la fois). Réglages : Config/UiMotion.PanelFocus. Rien n'est touché ici : le masque passe par
-- Controllers/UI/HudMask, qui ne change que Enabled et Visible et remet ensuite chaque valeur d'origine.
--
-- Allumé : Features.PanelFocus partout, ou Features.PanelFocusDev dans le jeu DEV (Config/ProductIds.IsDev) ; en Studio,
-- workspace:SetAttribute(PanelFocus.TestAttribute, true ou false) force la réponse (lue à chaque appel). Éteint : rien ne
-- change (HudHide d'avant, groupes ScreenGroup d'avant).
--
-- API (client) :
--   PanelFocus.Enabled() -> boolean
--   PanelFocus.Compute(features, isDev) -> boolean          la règle seule (bancs)
--   PanelFocus.IsPanel(gui) -> boolean                      fenêtre de L-430 (liste ou attribut)
--   PanelFocus.Spec(open, known) -> HudMask.Spec            le masque quand `open` (fenêtres allumées, au moins une)
--                                                            le sont ; `known` : noms de toutes les fenêtres suivies

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any
local UiMotion = require(Config:WaitForChild("UiMotion"))

local SETTINGS = UiMotion.PanelFocus
local HIDE = UiMotion.HudHide

local isDev = (function(): boolean
	local module = Config:FindFirstChild("ProductIds")
	if module ~= nil and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return (result :: any).IsDev == true
		end
	end
	return false
end)()

local isStudio = (function(): boolean
	local ok, result = pcall(function(): boolean
		return RunService:IsStudio()
	end)
	return ok and result == true
end)()

local PANELS: { [string]: boolean } = {}
for _, name in HIDE.Screens do
	PANELS[name] = true
end
for _, name in SETTINGS.Extra do
	PANELS[name] = true
end

local PanelFocus = {}

function PanelFocus.Compute(features: any, dev: boolean): boolean
	return features.PanelFocus == true or (features.PanelFocusDev == true and dev)
end

function PanelFocus.Enabled(): boolean
	if isStudio then
		local forced = Workspace:GetAttribute(SETTINGS.TestAttribute)
		if type(forced) == "boolean" then
			return forced
		end
	end
	return PanelFocus.Compute(Features, isDev)
end

function PanelFocus.IsPanel(gui: Instance): boolean
	if not gui:IsA("ScreenGui") then
		return false
	end
	return PANELS[gui.Name] == true or gui:GetAttribute(SETTINGS.Attribute) == true
		or gui:GetAttribute(HIDE.Attribute) == true
end

local function add(list: { string }, name: string)
	if table.find(list, name) == nil then
		table.insert(list, name)
	end
end

-- Reste à l'écran : toutes les fenêtres (l'ouverte, et les autres pour qu'elles puissent s'ouvrir sans être recachées),
-- Keep, et les écrans que HudHide.Keep garde pour TOUTES les fenêtres ouvertes (UI_Displayed garde UI_Hotbar).
-- HeistFeel.NeverMask n'est jamais touché par HudMask. Le masque ne compte pas pendant un masque de YieldTo.
-- a508 (L-461) : Also = UiMotion.PanelFocus.Also, écrans de NeverMask cachés aussi par ce masque (bandeau du tuto).
function PanelFocus.Spec(open: { ScreenGui }, known: { string }): { KeepScreens: { string }, YieldTo: { string }, Also: { string } }
	local keep: { string } = {}
	for name in PANELS do
		add(keep, name)
	end
	for _, name in known do
		add(keep, name)
	end
	for _, gui in open do
		add(keep, gui.Name)
	end
	for _, name in SETTINGS.Keep do
		add(keep, name)
	end
	local shared: { [string]: number } = {}
	for _, gui in open do
		local kept = HIDE.Keep[gui.Name]
		if kept then
			for _, name in kept do
				shared[name] = (shared[name] or 0) + 1
			end
		end
	end
	for name, count in shared do
		if count == #open then
			add(keep, name)
		end
	end
	table.sort(keep)
	return { KeepScreens = keep, YieldTo = table.clone(SETTINGS.YieldTo), Also = table.clone(SETTINGS.Also) }
end

return PanelFocus
