---------------------------------------------------------------- scénario « hud » : le vrai HudController
-- Voisins bouchonnés et pilotables : chrono du braquage (HeistController) et poursuite
-- (ChaseController), comme dans le banc a21-hud.
SOURCES["stub/HeistController"] = [==[
local H = { listeners = {}, timers = {} }
function H.OnTimer(fn)
	table.insert(H.listeners, fn)
	return function() end
end
function H.GetTimers()
	return H.timers
end
function H.Emit(storeId, endsAt)
	for _, fn in H.listeners do
		fn(storeId, endsAt)
	end
end
return H
]==]
SOURCES["stub/ChaseController"] = [==[
local C = { chased = false, distance = nil }
function C.IsChased()
	return C.chased
end
function C.GetDistance()
	return C.distance
end
function C.IsClose()
	return false
end
return C
]==]
local hudModule = moduleScript(CONTROLLERS, "HudController", "client/Controllers/HudController.luau")
local heistModule = moduleScript(CONTROLLERS, "HeistController", "stub/HeistController")
local chaseModule = moduleScript(CONTROLLERS, "ChaseController", "stub/ChaseController")

-- UI_HUD comme celui de Clément (arbre lu dans Studio le 2026-11-08) : StatsPanel > CashRow avec
-- Cash et Income (UIStroke, UIGradient), HeistTimer et GuardMeter cachés au départ, à la racine.
local function makeHud()
	local hud = new("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
	local rail = new("Frame", { Name = "LeftRail", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.021, 0.4), Size = UDim2.fromScale(0.155, 0.256) }, hud)
	for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
		local button = new("TextButton", { Name = name, Text = "" }, rail)
		new("TextLabel", { Name = "Label", Text = name }, button)
	end
	local panel = new("Frame", { Name = "StatsPanel", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.021, 0.975), Size = UDim2.fromScale(0.32, 0.23) }, hud)
	for _, name in { "Strength", "Damage", "Speed" } do
		new("TextLabel", { Name = name, Text = "1.4K" }, panel)
	end
	local row = new("Frame", { Name = "CashRow", Size = UDim2.fromScale(1, 0.4) }, panel)
	local cash = new("TextLabel", { Name = "Cash", Text = "$11.1B", TextScaled = true, Size = UDim2.fromScale(0.6, 1) }, row)
	new("UIStroke", { Thickness = 3.7 }, cash)
	new("UIGradient", {}, cash)
	local income = new("TextLabel", { Name = "Income", Text = "+$1.2K/s", TextScaled = true, Size = UDim2.fromScale(0.4, 1) }, row)
	new("UIStroke", { Thickness = 3.7 }, income)
	local base = new("TextButton", { Name = "ReturnBaseButton", Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.979, 0.483), Size = UDim2.fromScale(0.07, 0.115) }, hud)
	new("TextLabel", { Name = "BaseLabel", Text = "BASE" }, base)
	new("TextLabel", { Name = "NightCountdown", Text = "Night in 4:28", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.984, 0.926), Size = UDim2.fromScale(0.217, 0.05) }, hud)
	local timer = new("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.24, 0.066) }, hud)
	new("UIStroke", { Thickness = 3 }, timer)
	new("UIAspectRatioConstraint", { AspectRatio = 5 }, timer)
	local meter = new("Frame", { Name = "GuardMeter", Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.105, 12), Size = UDim2.fromScale(0.267, 0.026) }, hud)
	new("Frame", { Name = "Fill", Size = UDim2.new(0.6, 0, 1, 0) }, meter)
	new("UICorner", {}, meter)
	new("TextLabel", { Name = "GuardLabel", Text = "GUARD" }, meter)
	hud.Parent = PLAYER_GUI
	return hud
end

local NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Balance = requireModule(ReplicatedStorage.Shared.Config.Balance, "client")
P1:SetAttribute("Cash", 1500)
P1:SetAttribute("Income", 10)
local hud = makeHud()
local hudSnap = snapshot(hud)
local Motion = requireModule(MOTION_MODULE, "client")
local Heist = requireModule(heistModule, "client")
local Chase = requireModule(chaseModule, "client")
local Hud = requireModule(hudModule, "client")
local created0 = TWEEN_STATS.created
taskLib.spawn(Hud.Start)
step(0.1)
local cash, income = el(hud, "Cash"), el(hud, "Income")
local timer, meter = el(hud, "HeistTimer"), el(hud, "GuardMeter")

print("\n== H1. Premier remplissage")
check(cash.Text == "$1.5K" and income.Text == "+$10/s", "H1a Cash et Income écrits au branchement : « $1.5K », « +$10/s »")
check(TWEEN_STATS.created == created0, "H1b premier remplissage : aucun défilement (aucun tween)")

print("\n== H2. Cash qui défile")
P1:SetAttribute("Cash", 2500)
step(1 / 30)
local first = parseMoney(cash.Text)
check(first ~= nil and first > 1500 and first < 2500, `H2a une image après la hausse : valeur intermédiaire ({cash.Text})`)
local seen = watchTexts(cash, UiMotionC.Roll.Time)
check(cash.Text == "$2.5K", "H2b arrivée exacte : « $2.5K » (format Shared/Format inchangé)")
check(#seen >= 3, `H2c plusieurs valeurs affichées ({table.concat(seen, " ")})`)
P1:SetAttribute("Cash", 900)
step(0.2)
check(parseMoney(cash.Text) < 2500 and parseMoney(cash.Text) > 900, `H2d une dépense défile aussi, vers le bas ({cash.Text})`)
step(UiMotionC.Roll.Time)
check(cash.Text == "$900", "H2e … jusqu'à « $900 »")

print("\n== H3. Valeur inconnue, puis de retour")
P1:SetAttribute("Cash", 5000)
step(0.1)
P1:SetAttribute("Cash", nil)
check(cash.Text == "…", "H3a attribut retiré en plein défilement : « … » tout de suite")
step(1)
check(cash.Text == "…", "H3b le défilement arrêté ne réécrit rien")
local created = TWEEN_STATS.created
P1:SetAttribute("Cash", 3000)
check(cash.Text == "$3K" and TWEEN_STATS.created == created, "H3c valeur revenue : écrite d'un coup (nouveau premier remplissage)")

print("\n== H4. Income qui défile, et le revenu retenu (DEV-050)")
P1:SetAttribute("Income", 20)
step(UiMotionC.Roll.Time + 0.05)
check(income.Text == "+$20/s", "H4a Income défile jusqu'à « +$20/s »")
local release = Hud.HoldIncome()
P1:SetAttribute("Income", 50)
step(1)
check(income.Text == "+$20/s", "H4b retenu : Income ne bouge pas pendant l'ouverture du colis")
release()
step(1 / 30)
local mid = parseMoney(income.Text)
check(mid ~= nil and mid > 20 and mid < 50, `H4c relâché à la révélation : il défile ({income.Text})`)
step(UiMotionC.Roll.Time)
check(income.Text == "+$50/s", "H4d puis « +$50/s » exactement")
-- Deux retenues : chacune montre sa hausse, dans l'ordre.
local r1 = Hud.HoldIncome()
P1:SetAttribute("Income", 60)
local r2 = Hud.HoldIncome()
P1:SetAttribute("Income", 75)
step(0.2)
check(income.Text == "+$50/s", "H4e deux retenues : rien ne bouge")
r1()
step(UiMotionC.Roll.Time + 0.05)
check(income.Text == "+$60/s", "H4f la première relâchée : défile jusqu'à « +$60/s »")
r2()
step(UiMotionC.Roll.Time + 0.05)
check(income.Text == "+$75/s", "H4g la seconde : « +$75/s »")

print("\n== H5. HeistTimer : apparition et disparition")
local endsAt = Workspace:GetServerTimeNow() + 10
Heist.Emit("STORE_Z1_Superette", endsAt)
step(1 / 30)
check(timer.Visible and timer.Text == "HEIST: 10s" and Motion.GetState(timer) == "Opening" and motionScale(timer) ~= nil, "H5a vol lancé : « HEIST: 10s » apparaît, avec son UIScale passager")
step(UiMotionC.Show.Time + 0.05)
check(timer.Visible and motionScale(timer) == nil and Motion.GetState(timer) == "Open", "H5b apparu : UIScale retiré")
step(2)
check(timer.Text == "HEIST: 8s" and timer.Visible and motionScale(timer) == nil, "H5c le chrono avance sans rejouer l'apparition")
Heist.Emit("STORE_Z1_Superette", 0)
step(1 / 30)
check(timer.Visible and Motion.GetState(timer) == "Closing", "H5d vol fini : sortie en cours, encore visible")
step(UiMotionC.Hide.Time + 0.05)
check(timer.Visible == false and motionScale(timer) == nil, "H5e puis caché, UIScale retiré")
Heist.Emit("STORE_Z1_Superette", Workspace:GetServerTimeNow() + 5)
step(0.05)
Heist.Emit("STORE_Z1_Superette", 0)
step(0.05)
Heist.Emit("STORE_Z1_Superette", Workspace:GetServerTimeNow() + 5)
step(1 / 30)
check(timer.Visible and (Motion.GetState(timer) == "Opening" or Motion.GetState(timer) == "Open"), "H5f nouveau vol pendant la sortie : le chrono revient")
Heist.Emit("STORE_Z1_Superette", 0)
step(0.3)
check(timer.Visible == false, "H5g et repart à la fin")

print("\n== H6. GuardMeter : apparition et disparition")
Chase.chased = true
Chase.distance = Balance.Guard.GiveUpLead
step(1 / 30)
check(meter.Visible and Motion.GetState(meter) == "Opening" and motionScale(meter) ~= nil, "H6a poursuite : la jauge apparaît, avec son UIScale passager")
step(UiMotionC.Show.Time + 0.05)
check(meter.Visible and motionScale(meter) == nil, "H6b apparue : UIScale retiré")
Chase.chased = false
step(1 / 30)
check(meter.Visible and Motion.GetState(meter) == "Closing", "H6c fin de la poursuite : sortie en cours")
step(UiMotionC.Hide.Time + 0.05)
check(meter.Visible == false and motionScale(meter) == nil, "H6d puis cachée")

print("\n== H7. Aucun changement durable des propriétés de Clément")
local allowed = {
	[timer] = { Visible = true, Text = true },
	[meter] = { Visible = true },
	[el(meter, "Fill")] = { Size = true }, -- largeur de Fill : la proximité du vigile (déjà avant DEV-052)
	[cash] = { Text = true },
	[income] = { Text = true },
	[el(hud, "Speed")] = { Text = true },
	[el(hud, "Strength")] = { Text = true },
	[el(hud, "Damage")] = { Text = true },
	[el(hud, "NightCountdown")] = { Text = true, Visible = true },
	[el(hud, "ReturnBaseButton")] = { Text = true, Visible = true },
	[el(hud, "RobuxShopButton")] = { Visible = true },
	[el(hud, "IndexButton")] = { Visible = true },
	[el(hud, "RebirthButton")] = { Visible = true },
}
local ok, why = sameAs(hudSnap, hud, allowed)
check(ok, `H7 seuls textes, visibilité et largeur de Fill ont changé ; aucun objet laissé ({why})`)
check(ACTIVE_TWEENS() == 0, "H7b plus aucun tween en cours")

summary()
