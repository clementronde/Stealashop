---------------------------------------------------------------- bouchons des voisins
SOURCES["stub/HeistController"] = [==[
local H = {}
function H.OnTimer(_fn) return function() end end
function H.GetTimers() return {} end
return H
]==]
SOURCES["stub/ChaseController"] = [==[
local C = {}
function C.IsChased() return false end
function C.GetDistance() return nil end
function C.IsClose() return false end
return C
]==]

---------------------------------------------------------------- montage de la place
local sharedRoot = folder(ReplicatedStorage, "Shared")
local dirs = { [""] = sharedRoot }
local function dirFor(path)
	if dirs[path] then
		return dirs[path]
	end
	local parentPath, name = string.match(path, "^(.-)/?([^/]+)$")
	local f = folder(dirFor(parentPath), name)
	dirs[path] = f
	return f
end
for key in SOURCES do
	local rest = string.match(key, "^shared/(.+)%.luau$")
	if rest then
		local dir, name = string.match(rest, "^(.-)/?([^/]+)$")
		moduleScript(dirFor(dir), name, key)
	end
end
local client = folder(StarterPlayerScripts, "Client")
local controllers = folder(client, "Controllers")
moduleScript(folder(controllers, "UI"), "Motion", "client/Controllers/UI/Motion.luau") -- a37 (DEV-052) : module d'aide des contrôleurs
local hudModule = moduleScript(controllers, "HudController", "client/Controllers/HudController.luau")
local skyModule = moduleScript(controllers, "SkyController", "client/Controllers/SkyController.luau")
moduleScript(controllers, "HeistController", "stub/HeistController")
moduleScript(controllers, "ChaseController", "stub/ChaseController")

local function new(class, props, parent)
	local inst = InstanceAPI.new(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function el(screen, name)
	return screen:FindFirstChild(name, true)
end

-- UI_HUD habillé par Clément (L-038) : le texte « BASE » est dans BaseLabel, sous ReturnBaseButton.
local function makeHud(playerGui, withCooldown)
	local hud = new("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
	local rail = new("Frame", { Name = "LeftRail" }, hud)
	for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
		local button = new("TextButton", { Name = name, Text = "" }, rail)
		new("TextLabel", { Name = "Label", Text = name }, button)
	end
	local panel = new("Frame", { Name = "StatsPanel" }, hud)
	for _, name in { "Strength", "Damage", "Speed", "Cash", "Income" } do
		new("TextLabel", { Name = name, Text = "0" }, panel)
	end
	local base = new("TextButton", { Name = "ReturnBaseButton", Text = "" }, hud)
	new("Frame", { Name = "Icon" }, base)
	new("TextLabel", { Name = "BaseLabel", Text = "BASE" }, base)
	if withCooldown then
		new("TextLabel", { Name = "Cooldown", Text = "1:30" }, base)
	end
	new("TextLabel", { Name = "NightCountdown", Text = "Night in 4:28" }, hud)
	new("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false }, hud)
	local meter = new("Frame", { Name = "GuardMeter", Visible = false }, hud)
	new("Frame", { Name = "Fill", Size = UDim2.new(0.6, 0, 1, 0) }, meter)
	hud.Parent = playerGui
	return hud
end

---------------------------------------------------------------- démarrage
local P1 = new("Player", { Name = "Alice", UserId = 101, DisplayName = "Alice" })
local character = new("Model", { Name = "Alice" })
new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(0, 3, 0) }, character)
character.Parent = Workspace
P1.Character = character
local playerGui = new("PlayerGui", { Name = "PlayerGui" }, P1)
P1.Parent = Players
local hud = makeHud(playerGui, false)

-- Lampadaire taggé NightLight (proposition à Clément) : lumière éteinte, plastique.
local lamp = new("Part", { Name = "LampGlow", Material = "Enum.Material.SmoothPlastic" }, Workspace)
local bulb = new("PointLight", { Name = "Bulb", Enabled = false }, lamp)
addTag(lamp, "NightLight")

local NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Night = requireModule(ReplicatedStorage.Shared.Config.Night, "server")
local pressed = 0
NetS.Server.ReturnToBase:Connect(function(player)
	if player == P1 then
		pressed += 1
	end
end)

CLIENT_PLAYER = P1
Players.LocalPlayer = P1
local Hud = requireModule(hudModule, "client")
local Sky = requireModule(skyModule, "client")
taskLib.spawn(Hud.Start)
taskLib.spawn(Sky.Start)
step(0.1)

local function T(name)
	return el(hud, name).Text
end
local function serverNow()
	return Workspace:GetServerTimeNow()
end
local function setPhase(phase, endsIn, fallsIn)
	Workspace:SetAttribute("NightPhase", phase)
	Workspace:SetAttribute("NightPhaseEndsAt", serverNow() + endsIn)
	Workspace:SetAttribute("NightFallsAt", if fallsIn then serverNow() + fallsIn else nil)
end
local BASE = {
	Clock = 14,
	Brightness = 2,
	Ambient = Color3.fromRGB(70, 70, 70),
	Outdoor = Color3.fromRGB(128, 128, 128),
}
local function lightingIs(look, eps)
	eps = eps or 1e-6
	return math.abs(Lighting.ClockTime - look.Clock) <= eps
		and math.abs(Lighting.Brightness - look.Brightness) <= eps
		and sameColor(Lighting.Ambient, look.Ambient)
		and sameColor(Lighting.OutdoorAmbient, look.Outdoor)
end

print("\n== H1. Interrupteurs (Config/Features)")
for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
	check(el(hud, name).Visible == false, `H1 {name} toujours caché`)
end
check(el(hud, "NightCountdown").Visible == true, "H1 NightCountdown affiché (Features.NightCycle)")
check(el(hud, "ReturnBaseButton").Visible == true, "H1 ReturnBaseButton affiché (Features.ReturnToBase)")

print("\n== H2. Compte à rebours NightCountdown")
check(T("NightCountdown") == "…", "H2 phase pas encore posée : « … »")
setPhase("Day", 450, 480)
step(0.1)
check(T("NightCountdown") == "Night in 8:00", `H2 jour : « Night in 8:00 » ({T("NightCountdown")})`)
step(30)
check(T("NightCountdown") == "Night in 7:30", `H2 « Night in 7:30 » 30 s plus tard ({T("NightCountdown")})`)
setPhase("Day", 15, 45)
step(0.1)
check(T("NightCountdown") == "Night in 45s", `H2 sous une minute : « Night in 45s » ({T("NightCountdown")})`)
setPhase("Day", 450, nil)
step(0.1)
check(T("NightCountdown") == "Night in 8:00", "H2 sans NightFallsAt : fin du jour + 30 s d'alerte")
setPhase("Warning", 30)
step(0.1)
check(T("NightCountdown") == "NIGHT FALLS IN 30s" and T("NightCountdown") == Night.WarningText, `H2 alerte : « NIGHT FALLS IN 30s » = Night.WarningText ({T("NightCountdown")})`)
step(10.5)
check(T("NightCountdown") == "NIGHT FALLS IN 20s", `H2 l'alerte décompte : « NIGHT FALLS IN 20s » ({T("NightCountdown")})`)
setPhase("Night", 120)
step(0.1)
check(T("NightCountdown") == "Dawn in 2:00", `H2 nuit : « Dawn in 2:00 » ({T("NightCountdown")})`)
step(61)
check(T("NightCountdown") == "Dawn in 59s", `H2 « Dawn in 59s » ({T("NightCountdown")})`)

print("\n== H3. ReturnBaseButton, sans enfant Cooldown (texte du bouton)")
local button = el(hud, "ReturnBaseButton")
local baseLabel = el(hud, "BaseLabel")
button.Activated:Fire()
step(0.1)
check(pressed == 1, "H3 clic : ReturnToBase envoyé au serveur")
check(button.Text == "" and baseLabel.Text == "BASE", "H3 prêt : bouton et BaseLabel intacts")
P1:SetAttribute("ReturnBaseReadyAt", serverNow() + 90)
step(0.1)
check(button.Text == "90s", `H3 recharge écrite dans le texte du bouton : « 90s » ({button.Text})`)
check(baseLabel.Text == "BASE", "H3 BaseLabel jamais touché")
step(30)
check(button.Text == "60s", `H3 « 60s » 30 s plus tard ({button.Text})`)
step(60)
check(button.Text == "", "H3 prêt de nouveau : texte d'origine remis")
check(baseLabel.Text == "BASE", "H3 BaseLabel toujours « BASE »")

print("\n== H4. ReturnBaseButton avec enfant Cooldown (proposé à Clément)")
hud:Destroy()
hud = makeHud(playerGui, true)
step(0.1)
local button2 = el(hud, "ReturnBaseButton")
local cooldown = el(hud, "Cooldown")
check(cooldown.Visible == false, "H4 Cooldown caché tant que le bouton est prêt")
P1:SetAttribute("ReturnBaseReadyAt", serverNow() + 45.5)
step(0.1)
check(cooldown.Visible == true and cooldown.Text == "46s", `H4 recharge dans Cooldown : « 46s » ({cooldown.Text})`)
check(button2.Text == "" and el(hud, "BaseLabel").Text == "BASE", "H4 bouton et BaseLabel intacts")
button2.Activated:Fire()
step(0.1)
check(pressed == 2, "H4 clic pendant la recharge : envoyé quand même (le serveur décide et répond par Notify)")
step(46)
check(cooldown.Visible == false, "H4 prêt : Cooldown caché")
check(T("NightCountdown") ~= "Night in 4:28", "H4 nouvel écran : NightCountdown rebranché")

print("\n== H5. Ciel et lumière (SkyController), lampadaires")
-- H2 a laissé la nuit : le jour revient en TransitionTime s.
setPhase("Day", 450, 480)
step(Night.Sky.TransitionTime + 0.2)
check(lightingIs(BASE), "H5 jour : réglages de Clément inchangés")
check(lamp.Material == "Enum.Material.SmoothPlastic" and bulb.Enabled == false, "H5 jour : lampadaire éteint")
setPhase("Warning", 30)
step(15)
local dusk = BASE.Outdoor:Lerp(Night.Sky.DuskTint, Night.Sky.DuskTintAmount)
check(math.abs(Lighting.ClockTime - (14 + (Night.Sky.DuskClockTime - 14) * 0.5)) < 0.02, `H5 alerte, à mi-chemin : soleil qui descend ({string.format("%.2f", Lighting.ClockTime)})`)
check(sameColor(Lighting.Ambient, BASE.Ambient) and Lighting.Brightness == 2, "H5 alerte : ambiance et luminosité de Clément gardées")
local half = BASE.Outdoor:Lerp(dusk, 0.5)
check(math.abs(Lighting.OutdoorAmbient.R - half.R) < 0.01 and math.abs(Lighting.OutdoorAmbient.G - half.G) < 0.01, "H5 alerte : ambiance extérieure qui rougit")
step(15.5)
check(math.abs(Lighting.ClockTime - Night.Sky.DuskClockTime) < 1e-6, "H5 fin de l'alerte : coucher du soleil (DuskClockTime)")
setPhase("Night", 120)
step(1.5)
local mid = Lighting.ClockTime
check(mid > Night.Sky.DuskClockTime and mid < 24, `H5 la nuit tombe par le soir ({string.format("%.2f", mid)})`)
check(lamp.Material == "Enum.Material.Neon" and bulb.Enabled == true, "H5 nuit : lampadaire allumé (Neon, lumière)")
local late = new("Part", { Name = "LampLate", Material = "Enum.Material.Glass" }, Workspace)
local lateBulb = new("PointLight", { Name = "Bulb", Enabled = false }, late)
addTag(late, "NightLight")
step(1.6)
check(lightingIs({ Clock = Night.Sky.NightClockTime, Brightness = Night.Sky.NightBrightness, Ambient = Night.Sky.NightAmbient, Outdoor = Night.Sky.NightOutdoorAmbient }), "H5 nuit : réglages de nuit après TransitionTime")
check(late.Material == "Enum.Material.Neon" and lateBulb.Enabled == true, "H5 lampadaire arrivé en pleine nuit (streaming) : allumé")
setPhase("Day", 450, 480)
step(1.5)
check(math.abs(Lighting.ClockTime - (Night.Sky.NightClockTime + 14 * 0.5)) < 0.05, `H5 l'aube passe par le matin ({string.format("%.2f", Lighting.ClockTime)})`)
check(lamp.Material == "Enum.Material.SmoothPlastic" and bulb.Enabled == false, "H5 aube : lampadaire éteint, état livré")
check(late.Material == "Enum.Material.Glass" and lateBulb.Enabled == false, "H5 aube : l'autre aussi, avec son matériau")
step(1.6)
check(lightingIs(BASE), "H5 jour : de nouveau les réglages de Clément, exactement")

print("\n== H6. Revenu retenu pendant une ouverture de colis (HudController.HoldIncome, copie a26)")
local Format = requireModule(ReplicatedStorage.Shared.Format, "server")
local function I()
	return T("Income")
end
P1:SetAttribute("Income", 100)
step(0.05)
check(I() == Format.income(100), `H6 revenu affiché : {I()}`)
local release1 = Hud.HoldIncome()
P1:SetAttribute("Income", 143)
step(0.05)
check(I() == Format.income(100), "H6a retenu : la hausse ne s'affiche pas")
release1()
check(I() == Format.income(143), "H6b relâché : la nouvelle valeur tout de suite")
release1()
check(I() == Format.income(143), "H6c relâcher deux fois : sans effet")
-- Deux ouvertures d'affilée : chacune montre la hausse de son objet.
local r1 = Hud.HoldIncome()
P1:SetAttribute("Income", 200)
local r2 = Hud.HoldIncome()
P1:SetAttribute("Income", 260)
step(0.05)
check(I() == Format.income(143), "H6d deux retenues : la valeur d'avant la première")
r1()
check(I() == Format.income(200), "H6e première relâchée : la hausse de son objet seulement")
r2()
check(I() == Format.income(260), "H6f seconde relâchée : la valeur réelle")
local r3 = Hud.HoldIncome()
P1:SetAttribute("Income", 300)
local r4 = Hud.HoldIncome()
P1:SetAttribute("Income", 350)
r4()
check(I() == Format.income(260), "H6g la plus récente relâchée d'abord : la plus ancienne retient encore")
r3()
check(I() == Format.income(350), "H6h toutes relâchées : la valeur réelle")
-- Événements différés de Roblox : la valeur est déjà posée sur le Player quand UnboxReveal est
-- traité, mais le HUD n'a pas encore vu passer le changement.
rawget(P1, "_attrs").Income = 420
local r5 = Hud.HoldIncome()
check(I() == Format.income(350), "H6i retenue prise avant que le HUD ait traité la hausse déjà posée")
P1:GetAttributeChangedSignal("Income"):Fire()
step(0.05)
check(I() == Format.income(350), "H6j la hausse traitée ensuite reste retenue")
r5()
check(I() == Format.income(420), "H6k relâchée : la nouvelle valeur")
-- Les autres valeurs ne sont jamais retenues.
local r6 = Hud.HoldIncome()
P1:SetAttribute("Cash", 1234)
step(0.05)
check(T("Cash") == Format.money(1234), "H6l Cash n'est pas retenu")
-- Écran recréé pendant une retenue.
P1:SetAttribute("Income", 500)
hud:Destroy()
hud = makeHud(playerGui, true)
step(0.1)
check(I() == Format.income(420), "H6m écran recréé pendant la retenue : valeur retenue")
r6()
check(I() == Format.income(500), "H6n puis relâchée : à jour")
-- Filet de sécurité : une retenue oubliée se relâche toute seule.
clearLog()
Hud.HoldIncome()
P1:SetAttribute("Income", 600)
step(59)
check(I() == Format.income(500), "H6o retenue oubliée : toujours retenue à 59 s")
step(1.2)
check(I() == Format.income(600) and logHas("revenu retenu plus de 60 s", "WARN"), "H6p relâchée toute seule après 60 s, avec un avertissement")

summary()
