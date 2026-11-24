--!nocheck
-- Mise en place commune des scénarios du banc a33 : arbre du jeu (modules sous Shared,
-- Server/Services et Client/Controllers, comme Script Sync), carte du relevé wave11-studio (zone
-- safe, arches, route), assets de Clément (Assets/Music, BB_TruckHP, BB_WindowHP, UI_HUD),
-- joueurs et personnages, script de sons de Roblox simulé, démarrage par le vrai Loader.
--
-- Avant ce fichier, un scénario peut poser : MUSIC_DELIVERED (true), TRUCK_BAR_DELIVERED (true),
-- WINDOW_BAR_DELIVERED (true), HUD_DELIVERED (true).

---------------------------------------------------------------- bouchons
-- Net côté client : les remotes du serveur ne sont pas là ; un envoi est noté dans SERVER_CALLS.
SOURCES["shared/Net/Net.luau"] = [==[
local function remote(name)
	return {
		Fire = function(_, ...)
			table.insert(SERVER_CALLS, { t = os.clock(), name = name, args = table.pack(...) })
		end,
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
end
return { Client = setmetatable({}, { __index = function(_, name) return remote(name) end }) }
]==]

---------------------------------------------------------------- arbre du jeu
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
SHARED = sharedRoot

local server = folder(ServerScriptService, "Server")
SERVICES = folder(server, "Services")
if SOURCES["server/Services/ContractChecker.luau"] then
	moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")
end
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = folder(sps, "Client")
CONTROLLERS = folder(clientFolder, "Controllers")
for key in SOURCES do
	local name = string.match(key, "^client/Controllers/([^/]+)%.luau$")
	if name then
		moduleScript(CONTROLLERS, name, key)
	end
end

function serverModule(name)
	return requireModule(SERVICES:FindFirstChild(name), "server")
end
function clientModule(name)
	return requireModule(CONTROLLERS:FindFirstChild(name), "client")
end
function sharedModule(path)
	local current = SHARED
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
	end
	return requireModule(current, "client")
end

---------------------------------------------------------------- carte (relevé wave11-studio, section 4)
MAP = folder(Workspace, "Map")
ROAD = make("Part", { Name = "Road", Anchored = true, Size = Vector3.new(760, 1, 45), CFrame = CFrame.new(330, -0.5, 0) }, MAP)
GATE_X = { 30, 100, 190, 300, 430, 580 }
END_X = 700
GATES = {}
for zone, x in GATE_X do
	local gate = make("Model", { Name = `ZoneGate_{zone}` }, MAP)
	local arch = make("Part", { Name = "Arch", Anchored = true, CanCollide = false, Size = Vector3.new(2, 24, 50), CFrame = CFrame.new(x, 12, 0), PivotOffset = CFrame.new(0, -12, 0) }, gate)
	gate.PrimaryPart = arch
	gate:SetAttribute("Zone", zone)
	addTag(gate, "ZoneGate")
	GATES[zone] = gate
end
-- Zone safe : une pièce 274 × 170 × 500 centrée en (−113, 75, 0) ; mur de nuit vers x = 27.
SAFE_ZONE = make("Part", { Name = "SafeZoneVolume", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(274, 170, 500), CFrame = CFrame.new(-113, 75, 0) }, MAP)
addTag(SAFE_ZONE, "SafeZone")
local wall = make("Part", { Name = "NightWall", Anchored = true, Size = Vector3.new(2, 40, 69), CFrame = CFrame.new(27, -20, 0) }, MAP)
addTag(wall, "NightWall")

-- Milieu de chaque zone (entre son arche et la suivante, ou le fond du couloir).
function zoneMiddle(zone)
	local from = GATE_X[zone]
	local to = GATE_X[zone + 1] or END_X
	return (from + to) / 2
end

---------------------------------------------------------------- assets de Clément (relevé wave11-studio, sections 2 et 3)
ASSETS = folder(ReplicatedStorage, "Assets")
UI_FOLDER = folder(ASSETS, "UI")

MUSIC_IDS = {
	MUS_Hub = "rbxassetid://1836135091",
	MUS_Z1 = "rbxassetid://9038762524",
	MUS_Z2 = "rbxassetid://1844942024",
	MUS_Z3 = "rbxassetid://9047128188",
	MUS_Z4 = "rbxassetid://1835540319",
	MUS_Z5 = "rbxassetid://1842283695",
	MUS_Z6 = "rbxassetid://9038506583",
}
MUSIC_NAMES = { "MUS_Hub", "MUS_Z1", "MUS_Z2", "MUS_Z3", "MUS_Z4", "MUS_Z5", "MUS_Z6" }
MUSIC = {}
function buildMusic()
	MUSIC_FOLDER = folder(ASSETS, "Music")
	for _, name in MUSIC_NAMES do
		MUSIC[name] = make("Sound", { Name = name, SoundId = MUSIC_IDS[name], Looped = true, Volume = 0.4 }, MUSIC_FOLDER)
	end
end
if MUSIC_DELIVERED ~= false then
	buildMusic()
end

-- BB_TruckHP : {9, 200} × {2.4, 80}, MaxDistance 250 ; UIListLayout, Label, Bar avec Fill (UIGradient).
function buildTruckBar(parent)
	local bar = make("BillboardGui", { Name = "BB_TruckHP", Size = UDim2.new(9, 200, 2.4, 80), MaxDistance = 250, StudsOffset = Vector3.new(0, 1, 0) }, parent or UI_FOLDER)
	make("UIListLayout", { Name = "UIListLayout" }, bar)
	make("TextLabel", { Name = "Label", Text = "800 / 1K", Size = UDim2.fromScale(1, 0.45) }, bar)
	local frame = make("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 0.4) }, bar)
	local fill = make("Frame", { Name = "Fill", Size = UDim2.new(0.8, 0, 1, 0) }, frame)
	make("UIGradient", { Name = "UIGradient" }, fill)
	return bar
end
-- BB_WindowHP (la barre des vitrines), comme dans le banc a27.
function buildWindowBar(parent)
	local bar = make("BillboardGui", { Name = "BB_WindowHP", Size = UDim2.new(4, 0, 0.6, 0), MaxDistance = 60 }, parent or UI_FOLDER)
	local frame = make("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 0.6) }, bar)
	make("Frame", { Name = "Fill", Size = UDim2.new(1, 0, 1, 0) }, frame)
	make("TextLabel", { Name = "Label", Size = UDim2.fromScale(1, 0.4) }, bar)
	return bar
end
if TRUCK_BAR_DELIVERED ~= false then
	TRUCK_BAR = buildTruckBar()
end
if WINDOW_BAR_DELIVERED ~= false then
	WINDOW_BAR = buildWindowBar()
end

-- UI_HUD de Clément : le cadre SocialRow en bas à droite, avec InviteButton et RewardsButton (L-057).
function buildHud(parent, inviteClass)
	local gui = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = true }, parent)
	for _, name in { "Cash", "Income", "Speed", "Strength", "Damage", "HeistTimer", "NightCountdown" } do
		make("TextLabel", { Name = name }, gui)
	end
	local meter = make("Frame", { Name = "GuardMeter" }, gui)
	make("Frame", { Name = "Fill" }, meter)
	for _, name in { "ReturnBaseButton", "RobuxShopButton", "IndexButton", "RebirthButton" } do
		make("TextButton", { Name = name }, gui)
	end
	local row = make("Frame", { Name = "SocialRow" }, gui)
	local invite = make(inviteClass or "ImageButton", { Name = "InviteButton" }, row)
	make("ImageLabel", { Name = "InviteIcon" }, invite)
	make("TextLabel", { Name = "InviteLabel", Text = "INVITE" }, invite)
	local rewards = make("ImageButton", { Name = "RewardsButton" }, row)
	make("ImageLabel", { Name = "RewardsIcon" }, rewards)
	make("TextLabel", { Name = "RewardsLabel", Text = "REWARDS" }, rewards)
	make("Frame", { Name = "RewardsAlert", Visible = false }, rewards)
	return gui
end
if HUD_DELIVERED ~= false then
	STARTER_HUD = buildHud(StarterGui)
end

---------------------------------------------------------------- joueurs
local userIds = 0
function newPlayer(name)
	userIds += 1
	local player = make("Player", { Name = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	make("PlayerGui", { Name = "PlayerGui" }, player)
	Players.PlayerAdded:Fire(player)
	return player
end
function removePlayer(player)
	Players.PlayerRemoving:Fire(player)
	local character = player.Character
	if character then
		character:Destroy()
	end
	player.Parent = nil
end

-- Sons créés par le script de sons de Roblox (RbxCharacterSounds) dans le HumanoidRootPart.
ROBLOX_SOUNDS = { "Climbing", "Died", "FreeFalling", "GettingUp", "Jumping", "Landing", "Running", "Splash", "Swimming" }
LOOPED_SOUNDS = { Climbing = true, FreeFalling = true, Running = true, Swimming = true }
-- Simule le script de Roblox sur `character` : crée ses Sound et rend la table nom → Sound (comme
-- lui, il garde ses références et continue de régler Playing, même sur un son détruit).
function robloxSounds(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local sounds = {}
	for _, name in ROBLOX_SOUNDS do
		local sound = newInstance("Sound")
		sound.Name = name
		sound.SoundId = "rbxasset://sounds/" .. string.lower(name) .. ".mp3"
		sound.Volume = 0.65
		sound.Looped = LOOPED_SOUNDS[name] == true
		sound.Archivable = false
		sound.Parent = root
		sounds[name] = sound
	end
	return sounds
end

-- Personnage R15 simplifié en `position` (centre du HumanoidRootPart). `withSounds` (vrai par
-- défaut) : le script de Roblox crée ses sons juste après l'arrivée du personnage.
function spawnCharacter(player, position, withSounds)
	local old = player.Character
	if old then
		old:Destroy()
	end
	local character = make("Model", { Name = player.Name })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position), CanCollide = false }, character)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)), CanCollide = false }, character)
	make("Humanoid", { Name = "Humanoid" }, character)
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	local sounds = nil
	if withSounds ~= false then
		sounds = robloxSounds(character)
	end
	return character, sounds
end
function moveTo(player, position)
	player.Character:PivotTo(CFrame.new(position))
end

-- Copie de UI_HUD dans le PlayerGui, comme Roblox au démarrage et à chaque réapparition (ResetOnSpawn).
function copyHud(player)
	local gui = player.PlayerGui
	local old = gui:FindFirstChild("UI_HUD")
	if old then
		old:Destroy()
	end
	local copy = STARTER_HUD:Clone()
	copy.Parent = gui
	return copy
end

---------------------------------------------------------------- démarrage
function startClient(player)
	CLIENT_PLAYER = player
	Players.LocalPlayer = player
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "client")
	Loader.start(CONTROLLERS, "Client")
	flush()
end
function startServer()
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "server")
	Loader.start(SERVICES, "Serveur")
	flush()
end

-- Copies de musique jouées par MusicController (dans SoundService).
function musicCopies()
	local out = {}
	for _, child in SoundService:GetChildren() do
		if child:IsA("Sound") and string.sub(child.Name, 1, 4) == "MUS_" then
			table.insert(out, child)
		end
	end
	return out
end
function musicCopy(name)
	local found = nil
	local count = 0
	for _, child in SoundService:GetChildren() do
		if child.Name == name and child:IsA("Sound") then
			found = child
			count += 1
		end
	end
	return found, count
end
-- Clément's Sound inchangé (volume, boucle, lecture, place).
function untouched(name)
	local sound = MUSIC[name]
	return sound ~= nil
		and sound.Volume == 0.4
		and sound.Looped == true
		and sound.Playing == false
		and sound.Parent == MUSIC_FOLDER
		and sound.SoundId == MUSIC_IDS[name]
end
