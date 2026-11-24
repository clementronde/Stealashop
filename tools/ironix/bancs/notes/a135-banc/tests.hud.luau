--!nocheck
-- a135 U. Texte du chrono dans UI_HUD.HeistTimer (vague 40) : « POLICE IN 13s » pour le chrono de police
-- (HeistTimer avec police = true), « HEIST: 6s » pour celui d'après la casse ; le passage de l'un à l'autre
-- change le texte même à secondes égales ; un chrono de police déjà là au démarrage du HUD (IsPoliceTimer).
-- Faux Roblox : celui du banc a21-hud (copie a126) et ext-motion.luau (a62).

SOURCES["stub/HeistController"] = [==[
local H = { listeners = {}, timers = {}, police = {} }
function H.OnTimer(fn) table.insert(H.listeners, fn) return function() end end
function H.GetTimers() return table.clone(H.timers) end
function H.IsPoliceTimer(id) return H.police[id] == true end
function H._fire(id, endsAt, police)
	H.timers[id] = if endsAt > 0 then endsAt else nil
	H.police[id] = if endsAt > 0 and police then true else nil
	for _, fn in H.listeners do fn(id, endsAt, police == true) end
end
return H
]==]
SOURCES["stub/ChaseController"] = [==[
local C = {}
function C.IsChased() return false end
function C.GetDistance() return nil end
function C.IsClose() return false end
return C
]==]

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
moduleScript(folder(controllers, "UI"), "Motion", "client/Controllers/UI/Motion.luau")
local hudModule = moduleScript(controllers, "HudController", "client/Controllers/HudController.luau")
local heistModule = moduleScript(controllers, "HeistController", "stub/HeistController")
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

local P1 = new("Player", { Name = "Alice", UserId = 101, DisplayName = "Alice" })
local character = new("Model", { Name = "Alice" })
new("Part", { Name = "HumanoidRootPart", CFrame = CFrame.new(0, 3, 0) }, character)
character.Parent = Workspace
P1.Character = character
local playerGui = new("PlayerGui", { Name = "PlayerGui" }, P1)
P1.Parent = Players
local hud = new("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
local panel = new("Frame", { Name = "StatsPanel" }, hud)
for _, name in { "Strength", "Damage", "Speed", "Cash", "Income" } do
	new("TextLabel", { Name = name, Text = "0" }, panel)
end
new("TextLabel", { Name = "NightCountdown", Text = "Night in 4:28" }, hud)
local timer = new("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false }, hud)
hud.Parent = playerGui

CLIENT_PLAYER = P1
Players.LocalPlayer = P1
local Heist = requireModule(heistModule, "client")
local function serverNow()
	return Workspace:GetServerTimeNow()
end
-- U4 : un chrono de police déjà reçu avant le démarrage du HUD.
Heist._fire("STORE_Z1_Kiosque", serverNow() + 9.5, true)
local Hud = requireModule(hudModule, "client")
taskLib.spawn(Hud.Start)
step(0.1)

print("\n== U4. Chrono de police reçu avant le démarrage du HUD")
check(timer.Text == "POLICE IN 10s", "U4a « POLICE IN 10s » (IsPoliceTimer au démarrage) : " .. timer.Text)
Heist._fire("STORE_Z1_Kiosque", 0)
step(0.1)

print("\n== U1. Chrono de police")
Heist._fire("STORE_Z1_Superette", serverNow() + 13, true)
step(0.1)
check(timer.Text == "POLICE IN 13s", "U1a « POLICE IN 13s » : " .. timer.Text)
check(Hud.IsHeistTimerShown(), "U1b affiché")
step(1)
check(timer.Text == "POLICE IN 12s", "U1c il descend : " .. timer.Text)

print("\n== U2. Casse : chrono HEIST")
Heist._fire("STORE_Z1_Superette", 0)
Heist._fire("STORE_Z1_Superette", serverNow() + 6)
step(0.1)
check(timer.Text == "HEIST: 6s", "U2a « HEIST: 6s » : " .. timer.Text)
step(5)
check(timer.Text == "HEIST: 1s", "U2b « HEIST: 1s » : " .. timer.Text)
step(1)
check(not Hud.IsHeistTimerShown(), "U2c masqué à la fin")

print("\n== U3. Même nombre de secondes, autre chrono : le texte change")
local t = serverNow()
Heist._fire("STORE_Z1_Superette", t + 5.5, true)
step(0.1)
check(timer.Text == "POLICE IN 6s", "U3a « POLICE IN 6s » : " .. timer.Text)
Heist._fire("STORE_Z1_Superette", t + 5.5)
step(0.05)
check(timer.Text == "HEIST: 6s", "U3b « HEIST: 6s » à secondes égales : " .. timer.Text)

summary()
