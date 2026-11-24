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
---------------------------------------------------------------- ajouts a205 (vague 63, L-202 point 1)
-- Faux GuiService (game:GetService("GuiService"), des deux côtés) : TopbarInset (Rect : Min, Max en px de l'écran
-- entier) et son signal de changement. setTopbarInset(minX, maxX, height) le change et prévient.
GUI_SERVICE = { TopbarInset = { Min = Vector2.new(0, 0), Max = Vector2.new(0, 0) }, _changed = newSignal() }
function GUI_SERVICE.GetPropertyChangedSignal(self, key)
	assert(key == "TopbarInset", "faux GuiService : propriété " .. tostring(key))
	return self._changed
end
function setTopbarInset(minX, maxX, height)
	GUI_SERVICE.TopbarInset = { Min = Vector2.new(minX, 0), Max = Vector2.new(maxX, height) }
	GUI_SERVICE._changed:Fire()
end
for side, old in table.clone(games) do
	games[side] = {
		GetService = function(_, name)
			if name == "GuiService" then
				return GUI_SERVICE
			end
			return old:GetService(name)
		end,
	}
end
-- HUD v3 de Clément (tools/clement/refonte_ui_hud_v3.luau) : pas de MenuButton ni de MenuPanel ; LeftRail et
-- LeftRailTouch avec RobuxShopButton, IndexButton (+ IndexAlert) et SkillTreeButton (+ SkillTreeAlert) ; TopLeftRow
-- (200 × 44 px, attribut FollowTopbarInset sauf `follow == false`, dans `holder` s'il est donné) avec RewardsButton
-- (+ RewardsAlert), InviteButton, SettingsButton, RebirthButton (+ RebirthAlert, caché) ; RightRail, CashSpent.
function makeV3Hud(opts)
	opts = opts or {}
	local hud = makeHud()
	hud.Parent = nil
	for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
		local old = el(hud, name)
		old.Parent = nil
	end
	local touch = new("Frame", { Name = "LeftRailTouch" }, hud)
	for _, rail in { el(hud, "LeftRail"), touch } do
		new("TextButton", { Name = "RobuxShopButton", Text = "" }, rail)
		local index = new("TextButton", { Name = "IndexButton", Text = "" }, rail)
		new("Frame", { Name = "IndexAlert", Visible = false }, index)
		local skill = new("TextButton", { Name = "SkillTreeButton", Text = "" }, rail)
		new("Frame", { Name = "SkillTreeAlert", Visible = false }, skill)
	end
	local holder = hud
	if opts.holder then
		holder = new("Frame", { Name = "TopHolder", Position = opts.holder, Size = UDim2.fromScale(1, 1) }, hud)
	end
	local row = new("Frame", {
		Name = "TopLeftRow",
		AnchorPoint = opts.anchor or Vector2.new(0, 0),
		Position = UDim2.new(0, 120, 0, -51),
		Size = UDim2.fromOffset(4 * 44 + 3 * 8, 44),
		BackgroundTransparency = 1,
	}, holder)
	if opts.follow ~= false then
		row:SetAttribute("FollowTopbarInset", true)
	end
	local rewards = new("TextButton", { Name = "RewardsButton", Text = "" }, row)
	new("Frame", { Name = "RewardsAlert", Visible = false }, rewards)
	new("TextButton", { Name = "InviteButton", Text = "" }, row)
	new("TextButton", { Name = "SettingsButton", Text = "" }, row)
	local rebirth = new("TextButton", { Name = "RebirthButton", Text = "", Visible = false }, row)
	new("Frame", { Name = "RebirthAlert", Visible = false }, rebirth)
	local right = new("Frame", { Name = "RightRail" }, hud)
	new("TextButton", { Name = "DisplayedButton", Text = "" }, right)
	new("TextLabel", { Name = "CashSpent", Text = "-$0", Visible = false }, el(hud, "CashRow"))
	hud.Parent = PLAYER_GUI
	return hud, row
end
