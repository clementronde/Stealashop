--!nocheck
-- Scénario « twins » (L-099 point 1) : UI_HUD.LeftRail (PC) et UI_HUD.LeftRailTouch (téléphone) ont les
-- mêmes boutons. Les deux exemplaires de RobuxShopButton et RebirthButton ouvrent et ferment leur écran ;
-- HudController ne cache aucun des deux (aperçus L-071) ; le ContractChecker accepte ces doublons voulus
-- (UI.Twins), pas les autres ; UI_Toast et UI_Escape sont facultatifs au contrat.

-- Instance:FindFirstAncestor(name) (Roblox), absent du faux Roblox d'a39 : le ContractChecker s'en sert
-- pour reconnaître le cadre d'un doublon voulu.
if Methods.FindFirstAncestor == nil then
	function Methods.FindFirstAncestor(self, name)
		local current = self.Parent
		while current ~= nil do
			if current.Name == name then
				return current
			end
			current = current.Parent
		end
		return nil
	end
end

local RAIL_BUTTONS = { "RobuxShopButton", "IndexButton", "RebirthButton", "InventoryButton" }
local function buildHud2(parent)
	local gui = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
	for _, railName in { "LeftRail", "LeftRailTouch" } do
		local rail = make("Frame", { Name = railName, Visible = railName == "LeftRail" }, gui)
		for _, name in RAIL_BUTTONS do
			local button = make("TextButton", { Name = name, Text = "" }, rail)
			make("ImageLabel", { Name = "Icon" }, button)
			make("TextLabel", { Name = "Label", Text = name }, button)
		end
	end
	local panel = make("Frame", { Name = "StatsPanel" }, gui)
	for _, name in { "Strength", "Damage", "Speed", "Cash", "Income" } do
		make("TextLabel", { Name = name, Text = "0" }, panel)
	end
	local base = make("TextButton", { Name = "ReturnBaseButton", Text = "" }, gui)
	make("TextLabel", { Name = "Cooldown", Text = "84s" }, base)
	make("TextLabel", { Name = "NightCountdown", Text = "Night in 4:28" }, gui)
	make("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false }, gui)
	local meter = make("Frame", { Name = "GuardMeter", Visible = false }, gui)
	make("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1) }, meter)
	gui.Parent = parent
	return gui
end
local function railButton(hud, rail, name)
	return hud:FindFirstChild(rail):FindFirstChild(name)
end

local HUD = buildHud2(PLAYER_GUI)
local ROBUX = buildRobuxShopGui(PLAYER_GUI)
local REBIRTH = buildRebirth(PLAYER_GUI)
P1:SetAttribute("Cash", 6400)
startClient()

section("les deux exemplaires restent visibles (aperçus L-071)")
for _, rail in { "LeftRail", "LeftRailTouch" } do
	for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
		check(railButton(HUD, rail, name).Visible == true, `{rail}.{name} visible`)
	end
end

section("boutique Robux : par LeftRailTouch comme par LeftRail")
click(railButton(HUD, "LeftRailTouch", "RobuxShopButton"))
check(ROBUX.Enabled == true, "LeftRailTouch.RobuxShopButton ouvre UI_RobuxShop")
click(railButton(HUD, "LeftRailTouch", "RobuxShopButton"))
check(ROBUX.Enabled == false, "un 2e appui la ferme")
click(railButton(HUD, "LeftRail", "RobuxShopButton"))
check(ROBUX.Enabled == true, "LeftRail.RobuxShopButton l'ouvre aussi")
click(railButton(HUD, "LeftRailTouch", "RobuxShopButton"))
check(ROBUX.Enabled == false, "et l'autre exemplaire la ferme (un seul état)")

section("renaissance : par LeftRailTouch comme par LeftRail")
click(railButton(HUD, "LeftRailTouch", "RebirthButton"))
check(REBIRTH.Enabled == true, "LeftRailTouch.RebirthButton ouvre UI_Rebirth")
click(railButton(HUD, "LeftRail", "RebirthButton"))
check(REBIRTH.Enabled == false, "LeftRail.RebirthButton le ferme")
check(not logHas("RebirthButton introuvable", nil, "client") and not logHas("RobuxShopButton introuvable", nil, "client"), "aucune ligne « introuvable »")

section("Contract/UI : doublons voulus, UI_Toast et UI_Escape")
local UI = sharedModule("Contract/UI", "server")
local twins = UI.Twins and UI.Twins.UI_HUD
check(twins ~= nil and table.concat(twins.Containers, ",") == "LeftRail,LeftRailTouch", "UI.Twins.UI_HUD : LeftRail et LeftRailTouch")
local namesSeen = if twins then table.concat(twins.Names, ",") else ""
check(namesSeen == table.concat(RAIL_BUTTONS, ",") or namesSeen == table.concat(RAIL_BUTTONS, ",") .. ",SkillTreeButton", "les 4 boutons de la colonne (5 avec SkillTreeButton, vague 27 : a85)")
local byName = {}
for _, screen in UI.Screens do
	byName[screen.Name] = screen
end
check(byName.UI_Toast and byName.UI_Toast.Optional == true and byName.UI_Escape and byName.UI_Escape.Optional == true, "UI_Toast et UI_Escape au contrat, facultatifs")
local paths = {}
for _, name in { "UI_Toast", "UI_Escape" } do
	for _, element in (byName[name] and byName[name].Elements or {}) do
		paths[`{name}.{element.Path}`] = element
	end
end
check(paths["UI_Toast.Stack.Template"] and paths["UI_Toast.Stack.Template"].Template == true and paths["UI_Toast.Stack.Template"].Class == "TextLabel", "UI_Toast.Stack.Template : TextLabel caché, cloné")
check(paths["UI_Escape.Flash"] and paths["UI_Escape.Banner.Title"] and paths["UI_Escape.Banner.Subtitle"] and paths["UI_Escape.Banner.BoxIcon"], "UI_Escape : Flash, Banner.Title, Banner.Subtitle, Banner.BoxIcon")

section("ContractChecker")
local checkerHud = buildHud2(StarterGui)
local Checker = requireModule(CHECKER_MODULE, "server")
local function run()
	clearLog()
	Checker.Start()
	flush()
end
run()
for _, name in RAIL_BUTTONS do
	check(not logHas(`UI_HUD.{name} : 2 éléments`, nil, "server"), `{name} dans LeftRail et LeftRailTouch : aucune ligne`)
end
check(not logHas("UI_Toast", nil, "server") and not logHas("UI_Escape", nil, "server"), "UI_Toast et UI_Escape absents : rien à dire (facultatifs)")

-- Un doublon qui n'est pas voulu : signalé comme avant.
make("TextLabel", { Name = "Cash", Text = "0" }, checkerHud.LeftRailTouch)
-- Deux exemplaires dans le même cadre : signalé.
make("TextButton", { Name = "IndexButton", Text = "" }, checkerHud.LeftRail)
-- UI_Toast livré avec son Template visible : signalé.
local toast = make("ScreenGui", { Name = "UI_Toast", Enabled = false }, StarterGui)
local stack = make("Frame", { Name = "Stack" }, toast)
make("TextLabel", { Name = "Template", Visible = true }, stack)
run()
check(logHas("UI_HUD.Cash : 2 éléments portent ce nom", nil, "server"), "Cash en double : toujours signalé")
check(logHas("UI_HUD.IndexButton : 3 éléments portent ce nom", nil, "server"), "IndexButton deux fois dans LeftRail : signalé")
check(not logHas("UI_HUD.RobuxShopButton : 2 éléments", nil, "server"), "RobuxShopButton : toujours rien")
check(logHas("UI_Toast.Stack.Template doit être caché", nil, "server"), "UI_Toast.Stack.Template visible : signalé")

summary("scénario twins")
