--!strict
-- HudMenuController (vague 59, a190, client) : les boutons du nouveau HUD de Clément qui ne sont à aucun autre
-- contrôleur (liaison L-183 `UI_HUD`, L-182 point 7 ; noms de la page Figma « 30 HUD, tapis, poursuite »). Tout est
-- facultatif : sans le nouveau HUD, rien de ce qui suit n'existe et l'ancien HUD marche comme avant (ses boutons sont
-- cherchés partout dans l'écran par leurs contrôleurs).
--
--   - Vague 63 (a205, L-202 point 1, L-192 Q1, décision de Clément) : plus de bouton « More ». MenuButton, MenuAlert,
--     MenuArea et MenuPanel ne sont plus lus (encore là dans un ancien HUD : ignorés, aucune erreur). Les gros
--     boutons de LeftRail et LeftRailTouch (RobuxShopButton, IndexButton, SkillTreeButton, deux exemplaires) et les
--     petites icônes de TopLeftRow (RewardsButton, InviteButton, SettingsButton, RebirthButton, un exemplaire) sont
--     branchés par leurs propres contrôleurs, qui les cherchent par leur nom dans tout UI_HUD.
--   - TopLeftRow avec l'attribut FollowTopbarInset = true (Config/Hud.TopLeftRow) : calé sur la place libre de la
--     barre de Roblox, bord gauche à GuiService.TopbarInset.Min.X + Gap px, centré en hauteur dans la barre ;
--     recalculé quand TopbarInset, sa taille ou la place de son parent changent. Seul Position est écrit (en px).
--     Barre de hauteur nulle (barre de Roblox coupée) ou attribut absent : la place de Clément est gardée.
--   - RebirthButton : caché par Clément tant que la renaissance est coupée ; montré quand elle est ouverte
--     (attribut Rebirths du Player, posé par RebirthService). Jamais caché ici (l'aperçu L-071 de l'ancien HUD tient).
--   - DisplayedButton ouvre « Mes objets exposés » (UI_Displayed) : DisplayedController (agent a191) fait tout,
--     Toggle() s'il existe, sinon Open() ; sans lui, rien (une ligne en Studio).
--   - Boutons en situation de Config/Boosts (SpeedBoostButton « x2 », SleepButton « zZz ») : cachés au départ,
--     montrés seulement quand leur règle (ShowWhen) est vraie ; Price.Amount = le prix Robux de la Config ;
--     Cooldown = la recharge restante (« 4:12 », attribut serveur CooldownAttribute), caché sans recharge. Aucun
--     achat : l'effet n'est pas codé (Ready = false) et Features.RobuxShop = false ; un clic montre « Soon ».
--     Visible n'est écrit que quand la règle change : un masquage par un autre contrôleur (poursuite) tient.
--   - Vague 70 (a230, L-189 point 6) : les 4 bonus de BottomRow (FriendBoost, VipBoost, CashBoost, TrainingBoost),
--     règles et textes dans Config/Hud.BottomRow, lus dans les attributs que le serveur publie déjà (FriendBonus,
--     Pass<Clé>, CashBoostEndsAt). Visible et textes écrits seulement quand ils changent.
-- Seuls Visible, Position de TopLeftRow, Text de Price.Amount et de Cooldown sont touchés (2.2, « Libre pour
-- Ironix » ; la place de TopLeftRow est demandée par Clément, L-202), jamais un style ; les animations d'ouverture
-- (attribut Appear de Clément) sont jouées par le module d'UI commun quand Visible change.
-- HUD recréé (ResetOnSpawn) : rebranché, les connexions de l'ancien écran sont coupées.
--
-- API (client ; bancs, barre de commande en Studio) :
--   HudMenuController.GetShown() -> { [string]: boolean }   bouton en situation (Config/Boosts.Key) → montré
--   HudMenuController.Refresh()                              recalcule les règles tout de suite
--   HudMenuController.PlaceTopLeftRow()                      recale TopLeftRow tout de suite
--   HudMenuController.GetBonuses() -> { [nom]: { Shown, Amount, Timer } }   vague 70 : pastilles de BottomRow

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Boosts = require(Config:WaitForChild("Boosts"))
local Features = require(Config:WaitForChild("Features"))
local HudConfig = require(Config:WaitForChild("Hud"))
local Hub = require(Config:WaitForChild("Hub"))
local Monetization = require(Config:WaitForChild("Monetization"))
local SkillTree = require(Config:WaitForChild("SkillTree"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))

type Boost = Boosts.Boost
type ZoneApi = { GetZone: () -> number }
type NotifyApi = { Show: (message: string, kind: string?) -> () }

local SCREEN = "UI_HUD"
local ROW = HudConfig.TopLeftRow
local REBIRTH_BUTTON = "RebirthButton"
local REBIRTHS_ATTRIBUTE: string = SkillTree.RebirthsAttribute -- RebirthService : absent = renaissance coupée
local MACHINE_ATTRIBUTE = "TrainingMachine" -- TrainingService
local TREADMILL = "Treadmill"
local PRICE_PATH = "Price.Amount"
local COOLDOWN = "Cooldown"
local IS_STUDIO = RunService:IsStudio()

local HudMenuController = {}

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
local zones: ZoneApi? = nil
local notify: NotifyApi? = nil
local connections: { RBXScriptConnection } = {}
local boostButtons: { [string]: { GuiButton } } = {}
local cooldownLabels: { [string]: { TextLabel } } = {}
local shown: { [string]: boolean } = {}
local cooldownTexts: { [string]: string } = {}
local rows: { GuiObject } = {}
local rebirthButtons: { GuiObject } = {}
local warned: { [string]: boolean } = {}

-- Vague 70 (a230) : pastilles de BottomRow, par nom (Config/Hud.BottomRow), et ce qui y est écrit.
local BONUS = HudConfig.BottomRow
local BONUS_KEYS = { BONUS.Friend, BONUS.Vip, BONUS.Cash, BONUS.Training }
local PASS_PREFIX = "Pass" -- MonetizationService : attribut Pass<Clé> du Player
local CASH_BOOST_ATTRIBUTE = "CashBoostEndsAt" -- MonetizationService : fin du boost ×2 argent (heure serveur)
type Pill = { frame: GuiObject, amount: TextLabel?, timer: TextLabel? }
local pills: { [string]: { Pill } } = {}
local pillWritten: { [string]: { shown: boolean, amount: string, timer: string } } = {}

local function warnOnce(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(message)
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

local function buttonsNamed(root: Instance, name: string): { GuiButton }
	local list: { GuiButton } = {}
	for _, inst in Find.all(root, name) do
		if inst:IsA("GuiButton") then
			table.insert(list, inst :: GuiButton)
		end
	end
	return list
end

-- TopLeftRow (vague 63, L-202) ------------------------------------------------------------------

-- Cale `row` sur la place libre de la barre de Roblox (GuiService.TopbarInset, en px de l'écran entier) :
-- bord gauche à Min.X + Gap, centre vertical au milieu de la barre. Position est écrite en px dans le
-- repère du parent (sa place à l'écran est retirée), en tenant compte de l'AnchorPoint de Clément.
local function placeRow(row: GuiObject, guiService: GuiService)
	local inset = guiService.TopbarInset
	if inset.Max.Y - inset.Min.Y <= 0 then
		return -- pas de barre de Roblox : la place de Clément tient
	end
	local parent = row.Parent
	local origin = if parent and parent:IsA("GuiBase2d") then (parent :: GuiBase2d).AbsolutePosition else Vector2.new(0, 0)
	-- fusion57 (vu en Play) : sous un ScreenGui qui garde la place de la barre (IgnoreGuiInset = false, cas d'UI_HUD),
	-- AbsolutePosition part du bas de la barre ; TopbarInset est en px de l'écran entier : on ajoute ce décalage.
	local screenGui: Instance? = parent
	while screenGui and not screenGui:IsA("ScreenGui") do
		screenGui = screenGui.Parent
	end
	if screenGui and not (screenGui :: ScreenGui).IgnoreGuiInset then
		origin += guiService:GetGuiInset()
	end
	local size = row.AbsoluteSize
	local anchor = row.AnchorPoint
	local left = inset.Min.X + ROW.Gap
	local top = (inset.Min.Y + inset.Max.Y) / 2 - size.Y / 2
	local position = UDim2.fromOffset(
		math.round(left + anchor.X * size.X - origin.X),
		math.round(top + anchor.Y * size.Y - origin.Y)
	)
	if row.Position ~= position then
		row.Position = position
	end
end

function HudMenuController.PlaceTopLeftRow()
	if #rows == 0 then
		return
	end
	local guiService = game:GetService("GuiService")
	for _, row in rows do
		if row.Parent ~= nil then
			placeRow(row, guiService)
		end
	end
end

-- RebirthButton : montré quand la renaissance est ouverte (attribut Rebirths), jamais caché ici.
local function refreshRebirth()
	if type(localPlayer:GetAttribute(REBIRTHS_ATTRIBUTE)) ~= "number" then
		return
	end
	for _, button in rebirthButtons do
		if not button.Visible then
			button.Visible = true
		end
	end
end

-- Boutons en situation ----------------------------------------------------------------------------

-- Heure serveur de fin de recharge de `boost`, ou nil.
local function cooldownEndsAt(boost: Boost): number?
	local name = boost.CooldownAttribute
	if name == nil then
		return nil
	end
	local holder: Instance = if boost.CooldownHolder == "Player" then localPlayer else Workspace
	local value = holder:GetAttribute(name)
	return if type(value) == "number" and value == value then value else nil
end

-- « 4:12 » ; vague 70 : « 1:04:12 » à partir d'une heure (boost ×2 argent du pack de départ).
local function clockText(seconds: number): string
	local s = math.max(0, math.ceil(seconds - 1e-6))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Bonus de BottomRow (vague 70, a230, L-189 point 6) --------------------------------------------------

local function hasPass(key: string): boolean
	return localPlayer:GetAttribute(PASS_PREFIX .. key) == true
end

local function passMultiplier(key: string): number
	local pass = Monetization.PassByKey[key]
	local value = if pass then pass.Multiplier else nil
	return if type(value) == "number" and value == value then value else 1
end

-- Bonus `key` (nom de sa pastille) : montré, texte d'Amount, texte de Timer (« » sans temps restant).
local function bonusState(key: string, now: number): (boolean, string, string)
	if key == BONUS.Friend then
		local raw = localPlayer:GetAttribute(Hub.FriendBonus.BonusAttribute)
		local bonus = if type(raw) == "number" and raw == raw then math.max(raw, 0) else 0
		return bonus > 0 or BONUS.FriendAtZero, string.format(BONUS.FriendText, math.round(bonus * 100)), ""
	elseif key == BONUS.Vip then
		return hasPass("VIP"), BONUS.VipText, ""
	elseif key == BONUS.Cash then
		local endsAt = localPlayer:GetAttribute(CASH_BOOST_ATTRIBUTE)
		local left = if type(endsAt) == "number" and endsAt == endsAt then endsAt - now else 0
		local multiplier = if hasPass("DoubleCash") then passMultiplier("DoubleCash") else 1
		if left > 0 then
			multiplier *= Monetization.CashBoost.Multiplier
		end
		return multiplier > 1, string.format(BONUS.MultiplierText, multiplier), if left > 0 then clockText(left) else ""
	end
	local multiplier = if hasPass("DoubleTraining") then passMultiplier("DoubleTraining") else 1
	return multiplier > 1, string.format(BONUS.MultiplierText, multiplier), ""
end

local function refreshBonuses(now: number)
	for key, list in pills do
		local shownNow, amount, timer = bonusState(key, now)
		local written = pillWritten[key]
		if written == nil then
			written = { shown = not shownNow, amount = "", timer = "" }
			pillWritten[key] = written
		end
		for _, pill in list do
			if written.shown ~= shownNow then
				pill.frame.Visible = shownNow
			end
			local amountLabel = pill.amount
			if amountLabel and written.amount ~= amount then
				amountLabel.Text = amount
			end
			local timerLabel = pill.timer
			if timerLabel and written.timer ~= timer then
				timerLabel.Text = timer
				timerLabel.Visible = timer ~= ""
			end
		end
		written.shown = shownNow
		written.amount = amount
		written.timer = timer
	end
end

local function ruleHolds(boost: Boost): boolean
	if boost.ShowWhen == "OnTreadmill" then
		return localPlayer:GetAttribute(MACHINE_ATTRIBUTE) == TREADMILL
	elseif boost.ShowWhen == "InCorridor" then
		local api = zones
		if api == nil then
			return false
		end
		local ok, zone = pcall(api.GetZone)
		return ok and type(zone) == "number" and zone >= (boost.MinZone or 1)
	end
	return false
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	for _, boost in Boosts.List do
		local key = boost.Key
		local on = ruleHolds(boost)
		local buttons: { GuiButton } = boostButtons[key] or {}
		local labels: { TextLabel } = cooldownLabels[key] or {}
		if shown[key] ~= on then
			shown[key] = on
			for _, button in buttons do
				button.Visible = on
			end
		end
		local endsAt = cooldownEndsAt(boost)
		local text = if endsAt and endsAt > now then clockText(endsAt - now) else ""
		if cooldownTexts[key] ~= text then
			cooldownTexts[key] = text
			for _, label in labels do
				label.Text = text
				label.Visible = text ~= ""
			end
		end
	end
	refreshBonuses(now)
end

local function onBoost(boost: Boost)
	local endsAt = cooldownEndsAt(boost)
	local now = Workspace:GetServerTimeNow()
	local api = notify
	if endsAt and endsAt > now then
		if api then
			api.Show(`Ready in {clockText(endsAt - now)}`, "Alert")
		end
		return
	end
	-- Aucun achat tant que l'effet n'est pas codé côté serveur (Ready) et que la boutique Robux est coupée.
	if Features.RobuxShop and boost.Ready and boost.Id > 0 then
		game:GetService("MarketplaceService"):PromptProductPurchase(localPlayer, boost.Id)
		return
	end
	if api then
		api.Show(Boosts.SoonText)
	end
end

local function openDisplayed()
	local api = sibling("DisplayedController")
	local open = if api then (api.Toggle or api.Open) else nil
	if type(open) ~= "function" then
		warnOnce("displayed", "[HUD] DisplayedController.Toggle (ou Open) absent : DisplayedButton n'ouvre rien")
		return
	end
	local ok, err = pcall(open)
	if not ok then
		warnOnce("displayedError", `[HUD] DisplayedController : {err}`)
	end
end

-- Écran -------------------------------------------------------------------------------------------

local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(connections, signal:Connect(callback))
end

local function bind(gui: ScreenGui)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)

	-- Vague 63 : TopLeftRow calé sur la barre de Roblox (attribut de Clément), petites icônes cherchées par leurs
	-- contrôleurs ; RebirthButton montré si la renaissance est ouverte.
	rows = {}
	for _, inst in Find.all(gui, ROW.Frame) do
		if inst:IsA("GuiObject") and inst:GetAttribute(ROW.Attribute) == true then
			table.insert(rows, inst :: GuiObject)
		end
	end
	if #rows > 0 then
		local guiService = game:GetService("GuiService")
		connect(guiService:GetPropertyChangedSignal("TopbarInset"), HudMenuController.PlaceTopLeftRow)
		for _, row in rows do
			connect(row:GetPropertyChangedSignal("AbsoluteSize"), HudMenuController.PlaceTopLeftRow)
			local parent = row.Parent
			if parent and parent:IsA("GuiBase2d") then
				connect(parent:GetPropertyChangedSignal("AbsolutePosition"), HudMenuController.PlaceTopLeftRow)
			end
		end
		HudMenuController.PlaceTopLeftRow()
	end
	rebirthButtons = {}
	for _, inst in Find.all(gui, REBIRTH_BUTTON) do
		if inst:IsA("GuiObject") then
			table.insert(rebirthButtons, inst :: GuiObject)
		end
	end
	refreshRebirth()

	for _, button in buttonsNamed(gui, "DisplayedButton") do
		connect(clicked(button), openDisplayed)
	end

	boostButtons = {}
	cooldownLabels = {}
	shown = {}
	cooldownTexts = {}
	for _, boost in Boosts.List do
		local buttons = buttonsNamed(gui, boost.Button)
		local labels: { TextLabel } = {}
		boostButtons[boost.Key] = buttons
		cooldownLabels[boost.Key] = labels
		for _, button in buttons do
			button.Visible = false -- montré par sa règle (refresh)
			local price = Find.path(button, PRICE_PATH)
			if price and price:IsA("TextLabel") then
				price.Text = Format.short(boost.Price)
			end
			local cooldown = Find.path(button, COOLDOWN)
			if cooldown and cooldown:IsA("TextLabel") then
				cooldown.Visible = false
				table.insert(labels, cooldown :: TextLabel)
			end
			connect(clicked(button), function()
				onBoost(boost)
			end)
		end
	end

	-- Vague 70 (L-189 point 6) : pastilles de BottomRow (absentes : rien).
	pills = {}
	pillWritten = {}
	for _, key in BONUS_KEYS do
		local list: { Pill } = {}
		for _, inst in Find.all(gui, key) do
			if inst:IsA("GuiObject") then
				local amount = Find.path(inst, BONUS.Amount)
				local timer = Find.path(inst, BONUS.Timer)
				local amountLabel: TextLabel? = if amount and amount:IsA("TextLabel") then amount :: TextLabel else nil
				local timerLabel: TextLabel? = if timer and timer:IsA("TextLabel") then timer :: TextLabel else nil
				if timerLabel then
					timerLabel.Visible = false
				end
				table.insert(list, { frame = inst :: GuiObject, amount = amountLabel, timer = timerLabel })
			end
		end
		if #list > 0 then
			pills[key] = list
		end
	end
	refresh()
end

function HudMenuController.GetShown(): { [string]: boolean }
	return table.clone(shown)
end

-- Vague 70 : ce qui est écrit dans chaque pastille de BottomRow présente (nom → Shown, Amount, Timer).
function HudMenuController.GetBonuses(): { [string]: { Shown: boolean, Amount: string, Timer: string } }
	local result = {}
	for key, written in pillWritten do
		result[key] = { Shown = written.shown, Amount = written.amount, Timer = written.timer }
	end
	return result
end

function HudMenuController.Refresh()
	refresh()
end

function HudMenuController.Start()
	zones = sibling("ZoneGateController")
	notify = sibling("NotifyController")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= HudConfig.Refresh then
			elapsed = 0
			refresh()
		end
	end)
	localPlayer:GetAttributeChangedSignal(REBIRTHS_ATTRIBUTE):Connect(refreshRebirth)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
end

return HudMenuController
