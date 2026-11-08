--!strict
-- RebirthController (UI-120, client) : l'écran UI_Rebirth de Clément, en aperçu (Partie 2, section
-- 3.2 ; noms validés par Ironix en L-047 ; décision de Clément du 2026-11-08 : les boutons Shop, Index
-- et Rebirth du HUD sont visibles dès maintenant, L-071). La renaissance elle-même (DEV-120, MAJ 3)
-- n'est pas codée : l'écran montre la prochaine renaissance du tableau (Config/Rebirths), sans rien
-- pouvoir confirmer. Seulement si Features.RebirthPreview (ou Features.Rebirth) : sinon rien n'est
-- branché et HudController cache le bouton.
--
-- Rôle :
--   - UI_HUD.RebirthButton ouvre l'écran (un 2e appui le ferme) ; CloseButton le ferme. Ouverture et
--     fermeture animées par UI/Motion (DEV-052), comme les boutiques ;
--   - la prochaine renaissance : aucun joueur n'en a encore (rien dans le profil, 9.5), donc la 1re
--     pour tous :
--       Level          « Level 0 → 1 »
--       CashAmount     argent requis (Format.money : « $10K »)
--       CashLabel      « $6.4K / $10K » : argent du joueur (attribut Cash du Player, DataService) sur
--                      l'argent requis ; « … » tant que l'attribut n'est pas posé
--       CashBar.Fill   largeur = argent du joueur / argent requis, au plus 1 ; seule la largeur en
--                      Scale change (comme GuardMeter.Fill du HUD)
--       ItemName       nom de l'objet requis (Config/Items) ; Rarity : sa rareté (Config/Rarities)
--       Icon           l'icône ICON_<ItemId> de l'objet (Contract/Icons) quand elle est livrée, sinon
--                      l'image posée par Clément
--       GainList       dans la ligne TIER_ROW (« Rebirth Aura » sur la maquette), la récompense propre
--                      au palier (Config/Rebirths, RewardText) ; ses autres lignes et les colonnes Lose
--                      et Keep gardent les textes de Clément
--       Status         texte de Clément gardé (« Not owned yet ») : le client ne peut pas savoir si le
--                      joueur a l'objet (son inventaire et son coffre-fort ne lui sont pas envoyés, et
--                      ses présentoirs peuvent être hors du streaming) ; il faudra un attribut ou un
--                      remote du serveur avec DEV-120
--       ConfirmButton  reste dans l'état Disabled (Ready et Confirm cachés) ; un clic ne fait rien
--       Hint           HINT_TEXT (« Coming soon ») à la place de « Tap twice to confirm »
--     Les textes de l'argent suivent l'attribut Cash tant que l'écran est ouvert.
-- Textes en capitales si le texte d'exemple de Clément l'est (« INSTANT NOODLES », « RARE »), comme
-- dans les boutiques. Éléments cherchés par leur nom parmi les descendants (Contract/Find) ; un
-- élément absent est sauté (le ContractChecker le signale). Seuls sont touchés : Enabled de l'écran,
-- les textes, la visibilité des états du bouton, la largeur de Fill et l'image de Icon (2.2, « Libre
-- pour Ironix ») ; jamais un style, ni la couleur de Rarity. Un écran recréé (ResetOnSpawn) est
-- rebranché, fermé.
--
-- API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Rebirths = require(Config:WaitForChild("Rebirths"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	fill: GuiObject?, -- CashBar.Fill
	fillSize: UDim2, -- taille de Fill posée par Clément : seule la largeur en Scale change
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Rebirth"
local HUD = "UI_HUD"
local HUD_BUTTON = "RebirthButton"
local CASH_ATTRIBUTE = "Cash" -- posé par DataService sur le Player

-- Aucune renaissance n'est codée (DEV-120, MAJ 3) : tous les joueurs sont au niveau 0.
local CURRENT_LEVEL = 0

-- V0 proposés, absents du doc : textes de l'écran, en anglais (L-036).
local LEVEL_TEXT = "Level %d → %d" -- niveau actuel, niveau suivant
local CASH_TEXT = "%s / %s" -- argent du joueur, argent requis
local HINT_TEXT = "Coming soon"
local UNKNOWN_TEXT = "…" -- argent pas encore posé par le serveur (comme le HUD)
-- V0 proposé, absent du contrat : la ligne de GainList (nom relevé dans Studio le 2026-11-08) qui
-- montre la récompense propre au palier, et le TextLabel de chaque ligne.
local TIER_ROW = "Row2"
local ROW_LABEL = "RowLabel"
-- États du bouton en 2 temps (L-047) : seul Disabled est montré tant que la renaissance n'est pas codée.
local BUTTON_STATES: { { Name: string, Shown: boolean } } = {
	{ Name = "Disabled", Shown = true },
	{ Name = "Ready", Shown = false },
	{ Name = "Confirm", Shown = false },
}

local IS_STUDIO = RunService:IsStudio()

local RebirthController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local reported: { [string]: boolean } = {}

-- Une ligne de sortie par sujet, en Studio seulement.
local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

-- Textes ---------------------------------------------------------------------------------------

-- En capitales si le texte d'exemple de Clément l'est (« INSTANT NOODLES »), sinon tel quel.
local function matchCase(sample: string, text: string): string
	if string.find(sample, "%a") ~= nil and sample == string.upper(sample) then
		return string.upper(text)
	end
	return text
end

-- Écrit `text` dans l'élément `path` de `root` s'il affiche un texte, à la casse de son texte actuel ;
-- élément absent : rien.
local function setText(root: Instance, path: string, text: string)
	local found = Find.path(root, path)
	if found and (found:IsA("TextLabel") or found:IsA("TextButton")) then
		local label = found :: any
		local written = matchCase(label.Text, text)
		if label.Text ~= written then
			label.Text = written
		end
	end
end

local function guiObject(root: Instance, path: string): GuiObject?
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function setVisible(element: GuiObject?, visible: boolean)
	if element and element.Visible ~= visible then
		element.Visible = visible
	end
end

local function cashOf(): number?
	local value = localPlayer:GetAttribute(CASH_ATTRIBUTE)
	return if type(value) == "number" and value == value then value else nil
end

-- Écran -----------------------------------------------------------------------------------------

local function nextTier(): Rebirths.Tier?
	return Rebirths.Get(CURRENT_LEVEL + 1)
end

-- Argent : CashAmount, CashLabel et la largeur de CashBar.Fill.
local function refreshCash(current: Screen)
	local tier = nextTier()
	if tier == nil then
		return
	end
	local cash = cashOf()
	setText(current.gui, "CashRequirement.CashAmount", Format.money(tier.Cash))
	setText(current.gui, "CashRequirement.CashLabel", string.format(CASH_TEXT, if cash then Format.money(cash) else UNKNOWN_TEXT, Format.money(tier.Cash)))
	local fill = current.fill
	if fill then
		local size = current.fillSize
		local fraction = if cash and tier.Cash > 0 then math.clamp(cash / tier.Cash, 0, 1) else 0
		local wanted = UDim2.new(fraction, size.X.Offset, size.Y.Scale, size.Y.Offset)
		if fill.Size ~= wanted then
			fill.Size = wanted
		end
	end
end

-- Tout l'écran : niveau, argent, objet, récompense, bouton et indication.
local function refresh(current: Screen)
	local gui = current.gui
	local tier = nextTier()
	if tier == nil then
		return
	end
	setText(gui, "Level", string.format(LEVEL_TEXT, CURRENT_LEVEL, tier.Level))
	refreshCash(current)

	local item = Items.ById[tier.ItemId]
	if item then
		setText(gui, "ItemRequirement.ItemName", item.DisplayName)
		local rarity = Rarities.ById[item.Rarity]
		if rarity then
			setText(gui, "ItemRequirement.Rarity", rarity.DisplayName)
		end
		local texture = Icons.get(item.Id)
		local icon = Find.path(gui, "ItemRequirement.Icon")
		if texture and icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and (icon :: any).Image ~= texture then
			(icon :: any).Image = texture
		end
	end
	setText(gui, `GainList.{TIER_ROW}.{ROW_LABEL}`, tier.RewardText)

	local button = Find.path(gui, "ConfirmButton")
	if button then
		for _, state in BUTTON_STATES do
			setVisible(guiObject(button, state.Name), state.Shown)
		end
	end
	setText(gui, "Hint", HINT_TEXT)
end

local function close()
	isOpen = false
	local current = screen
	if current then
		Motion.Close(current.gui)
	end
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
	end
	isOpen = false
	gui.Enabled = false -- fermé jusqu'au bouton du HUD

	local fill = guiObject(gui, "CashRequirement.CashBar.Fill")
	local current: Screen = { gui = gui, fill = fill, fillSize = if fill then fill.Size else UDim2.new(), connections = {} }
	screen = current
	local closeButton = Find.path(gui, "CloseButton")
	if closeButton and closeButton:IsA("GuiButton") then
		table.insert(current.connections, (closeButton :: GuiButton).Activated:Connect(close))
	end
	refresh(current)
end

-- Écran branché encore présent, ou celui de PlayerGui (branché au passage), ou nil.
local function currentScreen(): Screen?
	local current = screen
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if gui and gui:IsA("ScreenGui") then
		bind(gui :: ScreenGui)
		return screen
	end
	return nil
end

local function open()
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `[Rebirth] écran {SCREEN} absent de PlayerGui : le bouton Rebirth n'ouvre rien`)
		return
	end
	isOpen = true
	refresh(current)
	Motion.Open(current.gui)
end

local function toggle()
	if isOpen then
		close()
	else
		open()
	end
end

-- Bouton du HUD ---------------------------------------------------------------------------------

local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	local found = Find.path(gui, HUD_BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce("hud", `[Rebirth] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : l'écran {SCREEN} ne s'ouvre pas`)
		return
	end
	hudBound[gui] = true
	(found :: GuiButton).Activated:Connect(toggle)
end

function RebirthController.Start()
	if not (Features.RebirthPreview or Features.Rebirth) then
		return -- ni aperçu ni renaissance : rien n'est branché
	end
	localPlayer:GetAttributeChangedSignal(CASH_ATTRIBUTE):Connect(function()
		local current = screen
		if isOpen and current and current.gui.Parent ~= nil then
			refreshCash(current)
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		elseif child.Name == HUD and child:IsA("ScreenGui") then
			bindHud(child)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end
end

return RebirthController
