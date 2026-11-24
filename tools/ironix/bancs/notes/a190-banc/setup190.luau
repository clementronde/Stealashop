-- Faux Roblox : RichText des TextLabel (le « ×2 » en exposant d a178 passe par le texte enrichi).
PROPS.TextLabel.RichText = false
---------------------------------------------------------------- montage a190 (après setup.luau et setup-a60.luau d'a60)
-- Voisins bouchonnés : ZoneGateController (zone pilotable), NotifyController (messages relevés),
-- DisplayedController (agent a191 : Toggle compté). Vrai HudMenuController.
SOURCES["stub/ZoneGateController"] = [==[
local Z = { zone = 0 }
function Z.GetZone()
	return Z.zone
end
return Z
]==]
SOURCES["stub/NotifyController"] = [==[
local N = { shown = {} }
function N.Show(message, kind)
	table.insert(N.shown, { message = message, kind = kind })
end
return N
]==]
SOURCES["stub/DisplayedController"] = [==[
local D = { toggles = 0 }
function D.Toggle()
	D.toggles += 1
end
return D
]==]
MENU_MODULE = moduleScript(CONTROLLERS, "HudMenuController", "client/Controllers/HudMenuController.luau")
ZONE_MODULE = moduleScript(CONTROLLERS, "ZoneGateController", "stub/ZoneGateController")
NOTIFY_MODULE = moduleScript(CONTROLLERS, "NotifyController", "stub/NotifyController")
HudCfgC = requireModule(ReplicatedStorage.Shared.Config.Hud, "client")
BoostsC = requireModule(ReplicatedStorage.Shared.Config.Boosts, "client")

-- Le nouveau HUD de la page Figma « 30 » (L-183), ajouté au HUD de makeHud : MenuButton (+ MenuAlert, Pulse) dans
-- LeftRail et LeftRailTouch, un MenuPanel (IndexButton + IndexAlert, RewardsButton + RewardsAlert, InviteButton),
-- RightRail (DisplayedButton, SpeedBoostButton, SleepButton), CashSpent.
function makeNewHud()
	local hud = makeHud()
	hud.Parent = nil
	local touch = new("Frame", { Name = "LeftRailTouch" }, hud)
	for _, rail in { el(hud, "LeftRail"), touch } do
		local button = new("TextButton", { Name = "MenuButton", Text = "" }, rail)
		local alert = new("Frame", { Name = "MenuAlert", Visible = false }, button)
		new("UIScale", { Name = "Pulse" }, alert)
	end
	local index = el(hud, "IndexButton")
	index.Parent = nil
	local panel = new("Frame", { Name = "MenuPanel", Visible = true }, hud)
	index.Parent = panel
	new("Frame", { Name = "IndexAlert", Visible = false }, index)
	local rewards = new("TextButton", { Name = "RewardsButton", Text = "" }, panel)
	new("Frame", { Name = "RewardsAlert", Visible = false }, rewards)
	new("TextButton", { Name = "InviteButton", Text = "" }, panel)
	local right = new("Frame", { Name = "RightRail" }, hud)
	new("TextButton", { Name = "DisplayedButton", Text = "" }, right)
	for _, name in { "SpeedBoostButton", "SleepButton" } do
		local button = new("TextButton", { Name = name, Text = "", Visible = true }, right)
		new("TextLabel", { Name = "Label", Text = "x2" }, button)
		local price = new("Frame", { Name = "Price" }, button)
		new("TextLabel", { Name = "Amount", Text = "0" }, price)
		if name == "SleepButton" then
			new("TextLabel", { Name = "Hint", Text = "60s" }, button)
			new("TextLabel", { Name = "Cooldown", Text = "", Visible = true }, button)
		end
	end
	new("TextLabel", { Name = "CashSpent", Text = "-$0", Visible = false }, el(hud, "CashRow"))
	hud.Parent = PLAYER_GUI
	return hud
end
function click(button)
	button.Activated:Fire()
	step(1 / 30)
end
