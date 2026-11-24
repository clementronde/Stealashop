---------------------------------------------------------------- scénarios (agent a34, DEV-053)
print("== Banc a34 : retours de frappe (DEV-053)")

-- Faux Net (repris d'a16) : routage serveur ↔ client local avec LATENCY de retard ; chaque envoi est
-- contrôlé avec le vrai Definitions + Validate. SEQ numérote tous les envois, dans l'ordre.
LATENCY = 0.05
SEQ = 0
SOURCES["shared/Net/Net.luau"] = "return FAKE_NET"
-- Faux ToolService : dégâts réglables par joueur ; outil en main sauf HOLDING[joueur] == false.
DAMAGE = {}
HOLDING = {}
SOURCES["server/Services/ToolService.luau"] = [[
local ToolService = {}
function ToolService.GetHitDamage(player) return DAMAGE[player] or 5 end
function ToolService.IsHoldingTool(player) return HOLDING[player] ~= false end
return ToolService
]]
-- Faux AnimationController : rend une piste factice (marqueur Impact déclenché par le test).
ANIM = { NoTrack = true, Last = nil }
SOURCES["client/Controllers/AnimationController.luau"] = [[
local AnimationController = {}
function AnimationController.PlayPlayer(name)
	if ANIM.NoTrack then return nil end
	ANIM.Last = newTrack(name)
	return ANIM.Last
end
return AnimationController
]]

-- Arbre des modules : shared → ReplicatedStorage/Shared, server → ServerScriptService/Server,
-- client → StarterPlayerScripts/Client (comme Script Sync).
local ROOTS = { shared = { ReplicatedStorage, "Shared" }, server = { ServerScriptService, "Server" }, client = { StarterPlayerScripts, "Client" } }
MODULES = {}
local keys = {}
for key in SOURCES do
	table.insert(keys, key)
end
table.sort(keys)
local function child(parent, name)
	return parent:FindFirstChild(name) or folder(parent, name)
end
for _, key in keys do
	local parts = string.split(key, "/")
	local root = ROOTS[parts[1]]
	local current = child(root[1], root[2])
	for i = 2, #parts - 1 do
		current = child(current, parts[i])
	end
	local name = string.gsub(parts[#parts], "%.luau$", "")
	MODULES[key] = moduleScript(current, name, key)
end

local Definitions = requireModule(MODULES["shared/Net/Definitions.luau"], "server")
local Validate = requireModule(MODULES["shared/Net/Validate.luau"], "server")
local DEFS = {}
for _, def in Definitions.List do
	DEFS[def.Name] = def
end

FAKE_REMOTES = {}
FAKE_NET = { Server = {}, Client = {} }
local function checkArgs(name, ...)
	local reason, detail = Validate.check(DEFS[name].Args, ...)
	if reason then
		FAILS += 1
		print(`  ÉCHEC envoi {name} mal formé : {detail}`)
	end
end
for name, def in DEFS do
	local r = { clientSignal = newSignal(), serverHandlers = {}, sent = {} }
	FAKE_REMOTES[name] = r
	FAKE_NET.Server[name] = {
		Name = name,
		Connect = function(_, fn)
			assert(def.Direction == "ClientToServer", "Connect serveur sur un remote serveur → client : " .. name)
			table.insert(r.serverHandlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, player, ...)
			assert(def.Direction == "ServerToClient", "Fire serveur sur un remote client → serveur : " .. name)
			checkArgs(name, ...)
			local args = table.pack(...)
			SEQ += 1
			table.insert(r.sent, { t = now(), seq = SEQ, to = player, args = args })
			if player == LOCAL then
				taskLib.delay(LATENCY, function()
					r.clientSignal:Fire(table.unpack(args, 1, args.n))
				end)
			end
		end,
		FireAll = function(_, ...)
			assert(def.Direction == "ServerToClient", "FireAll sur un remote client → serveur : " .. name)
			checkArgs(name, ...)
			local args = table.pack(...)
			SEQ += 1
			table.insert(r.sent, { t = now(), seq = SEQ, to = "all", args = args })
			taskLib.delay(LATENCY, function()
				r.clientSignal:Fire(table.unpack(args, 1, args.n))
			end)
		end,
	}
	FAKE_NET.Client[name] = {
		Name = name,
		Connect = function(_, fn)
			assert(def.Direction == "ServerToClient", "Connect client sur un remote client → serveur : " .. name)
			return r.clientSignal:Connect(fn)
		end,
		Fire = function(_, ...)
			assert(def.Direction == "ClientToServer", "Fire client sur un remote serveur → client : " .. name)
			checkArgs(name, ...)
			local args = table.pack(...)
			SEQ += 1
			taskLib.delay(LATENCY, function()
				for _, handler in r.serverHandlers do
					taskLib.spawn(handler, LOCAL, table.unpack(args, 1, args.n))
				end
			end)
		end,
	}
end

---------------------------------------------------------------- monde
local GLASS = Color3.fromRGB(191, 230, 255)
new("Part", { Name = "Floor", Size = Vector3.new(600, 1, 600), CFrame = CFrame.new(0, -0.5, 0) }, Workspace)
local camera = new("Camera", { Name = "Camera", CFrame = CFrame.new(-3, 6, 10) }, Workspace)
Workspace.CurrentCamera = camera
local terrain = new("Terrain", { Name = "Terrain" }, Workspace)

-- Assets de Clément
local assets = folder(ReplicatedStorage, "Assets")
local fx = folder(assets, "FX")
new("Decal", { Name = "WIN_Crack_75", Texture = "rbxassetid://75" }, fx)
new("Decal", { Name = "WIN_Crack_50", Texture = "rbxassetid://50" }, fx)
new("Decal", { Name = "WIN_Crack_25", Texture = "rbxassetid://25" }, fx)
new("Decal", { Name = "FX_GlassSparkle", Texture = "rbxassetid://9" }, fx)
local soundsFolder = folder(assets, "Sounds")
local glassSounds = folder(soundsFolder, "Glass")
for _, name in { "Glass_Hit", "Glass_BreakThud", "Glass_BreakShatter", "Glass_BreakDebris" } do
	new("Sound", { Name = name, PlaybackSpeed = 1 }, glassSounds)
end
-- Son du coup sur le camion (nom proposé à Clément), rangé dans un sous-dossier, hauteur de Clément 1,1.
local truckHitSound = new("Sound", { Name = "Truck_Hit", PlaybackSpeed = 1.1 }, folder(soundsFolder, "Truck"))
local ui = folder(assets, "UI")
local bb = new("BillboardGui", { Name = "BB_WindowHP", Size = UDim2.new(6, 0, 1.6, 0), StudsOffset = Vector3.new(0, 4.5, 0), MaxDistance = 80 }, ui)
new("TextLabel", { Name = "Label", Text = "300 / 400" }, bb)
local bar = new("Frame", { Name = "Bar" }, bb)
new("Frame", { Name = "Fill", Size = UDim2.new(0.75, 0, 1, 0) }, bar)

-- Magasins PNJ de la zone 1 (35 PV) : vitre M 12 × 7 × 0,4. A face à la rue (+Z), B tourné de 180°.
local map = folder(Workspace, "Map")
local function store(name, pivot)
	local model = new("Model", { Name = name })
	model.WorldPivot = pivot
	new("MeshPart", {
		Name = "Window",
		Size = Vector3.new(12, 7, 0.4),
		CFrame = pivot * CFrame.new(0, 4, 0),
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Color = GLASS,
	}, model)
	new("Part", { Name = "Bounds", Size = Vector3.new(20, 10, 22), CFrame = pivot * CFrame.new(0, 5, 12), Transparency = 1, CanCollide = false, CanQuery = false }, model)
	model:SetAttribute("Zone", 1)
	model.Parent = map
	addTag(model, "NPCStore")
	return model
end
local storeA = store("STORE_Z1_Superette", CFrame.new(0, 0, 20))
local storeB = store("STORE_Z1_Kiosque", CFrame.new(0, 0, -20) * CFrame.Angles(0, math.pi, 0))
local windowA = storeA.Window
local windowB = storeB.Window

-- Joueurs : le joueur local devant la vitre A, un autre près d'elle, un loin, un sans personnage.
local function addPlayer(name, id, position)
	local player = new("Player", { Name = name, UserId = id }, Players)
	if position then
		local model = new("Model", { Name = name })
		new("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position) * CFrame.Angles(0, math.pi, 0) }, model)
		local humanoid = new("Humanoid", {}, model)
		new("Animator", {}, humanoid)
		model.Parent = Workspace
		player.Character = model
	end
	return player
end
LOCAL = addPlayer("Ironix", 1, Vector3.new(-3, 3, 15))
Players.LocalPlayer = LOCAL
new("PlayerGui", { Name = "PlayerGui" }, LOCAL)
local OTHER = addPlayer("Clement", 2, Vector3.new(4, 3, 14))
local FAR = addPlayer("Loin", 3, Vector3.new(0, 3, -400))
local NOCHAR = addPlayer("SansPerso", 4, nil)

-- Boutiques des joueurs (PLOT_Shop) : la porte à casser est PlotDoor/Window. Plot_1 à Clement, Plot_2 au joueur local.
local function plot(index, owner, x)
	local model = new("Model", { Name = string.format("PLOT_Shop_%02d", index) })
	local door = new("Model", { Name = "PlotDoor" }, model)
	new("Part", { Name = "Window", Size = Vector3.new(8, 8, 0.5), CFrame = CFrame.new(x, 4, 20) }, door)
	new("Part", { Name = "Bounds", Size = Vector3.new(20, 10, 20), CFrame = CFrame.new(x, 5, 31), Transparency = 1, CanCollide = false, CanQuery = false }, model)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", owner.UserId)
	model.Parent = map
	addTag(model, "PlayerPlot")
	return model
end
local plot1 = plot(1, OTHER, -40)
local plot2 = plot(2, LOCAL, -80)
local door1 = plot1.PlotDoor.Window

-- Camion de l'événement : copie posée par TruckEventService (Model taggé EventTruck), cible de
-- WindowService (AddTarget, plus bas). Boîte x 94..106, y 0..10, z −15..15.
local truck = new("Model", { Name = "EventTruck" })
local truckBody = new("Part", { Name = "Body", Size = Vector3.new(12, 10, 30), CFrame = CFrame.new(100, 5, 0) }, truck)
truck.PrimaryPart = truckBody
new("Attachment", { Name = "HealthBarPoint", CFrame = CFrame.new(0, 8, 0) }, truckBody)
folder(truck, "Pieces")

local playerGui = LOCAL.PlayerGui
local root = LOCAL.Character.HumanoidRootPart
local otherRoot = OTHER.Character.HumanoidRootPart
-- Debout en `position`, regard vers +Z (CFrame.Angles(0, π, 0) dans ce faux Roblox, comme addPlayer).
local function place(r, position)
	r.CFrame = CFrame.new(position) * CFrame.Angles(0, math.pi, 0)
end

---------------------------------------------------------------- outils d'observation
local function numbers()
	local out = {}
	for _, c in terrain:GetChildren() do
		if c.Name == "DamageNumber" then
			table.insert(out, c)
		end
	end
	return out
end
local function lastNumber()
	local list = numbers()
	return list[#list]
end
local function guiOf(holder)
	return if holder then holder:FindFirstChildWhichIsA("BillboardGui") else nil
end
local function labelOf(holder)
	local gui = guiOf(holder)
	return if gui then gui:FindFirstChild("Label", true) else nil
end
local function textOf(holder)
	local label = labelOf(holder)
	return if label then label.Text else nil
end
-- Cible du tween `prop` lancé sur `inst` (le dernier), ou nil.
local function tweenGoal(inst, prop)
	for i = #TWEENS, 1, -1 do
		local tw = TWEENS[i]
		if tw.Instance == inst and tw.Goals[prop] ~= nil then
			return tw.Goals[prop], tw
		end
	end
	return nil
end
local function popTarget(holder)
	local label = labelOf(holder)
	local scale = if label then label:FindFirstChildOfClass("UIScale") else nil
	return if scale then tweenGoal(scale, "Scale") else nil, scale
end
local function soundCount(name, since)
	local n = 0
	for _, entry in SOUND_LOG do
		if entry.name == name and entry.t >= (since or 0) then
			n += 1
		end
	end
	return n
end
local function lastSound(name)
	for i = #SOUND_LOG, 1, -1 do
		if SOUND_LOG[i].name == name then
			return SOUND_LOG[i]
		end
	end
	return nil
end
local function sentTo(remote, player, id)
	local out = {}
	for _, e in FAKE_REMOTES[remote].sent do
		if (player == nil or e.to == player) and (id == nil or e.args[1] == id) then
			table.insert(out, e)
		end
	end
	return out
end
local function stars(windowId)
	local f = Workspace:FindFirstChild("_ShatterFX")
	local canvas = if f then f:FindFirstChild("Cracks_" .. windowId) else nil
	if canvas == nil then
		return nil, {}
	end
	return canvas, canvas.Front.Clip:GetChildren()
end
local function glassCubes()
	local n = 0
	local f = Workspace:FindFirstChild("_ShatterFX")
	for _, d in if f then f:GetDescendants() else {} do
		if d.Name == "GlassCube" then
			n += 1
		end
	end
	return n
end
local function within(value, center, jitter)
	return type(value) == "number" and value >= center * (1 - jitter) - 1e-9 and value <= center * (1 + jitter) + 1e-9
end
local hitHandlers = nil
local function serverHit(player, windowId)
	for _, handler in hitHandlers do
		taskLib.spawn(handler, player, windowId)
	end
end
local function injectHit(windowId, point, hitter, damage)
	FAKE_REMOTES.WindowHit.clientSignal:Fire(windowId, point, hitter, damage)
end

---------------------------------------------------------------- démarrage
print("\n== Démarrage : WindowService (serveur) ; WindowController, ShatterController, HitController, TruckController, DamageNumberController (client)")
local WS = requireModule(MODULES["server/Services/WindowService.luau"], "server")
WS.Init()
taskLib.spawn(WS.Start)
truck.Parent = Workspace
addTag(truck, "EventTruck")
local truckId = WS.AddTarget(truck, 1000)
check(truckId == "EventTruck" and truck:GetAttribute("MaxHP") == 1000 and truck:GetAttribute("HP") == 1000, "serveur : camion cible d'événement, 1000 PV")
check(windowA:GetAttribute("MaxHP") == 35 and door1:GetAttribute("WindowId") == "Plot_1" and door1:GetAttribute("MaxHP") == 250, "serveur : vitre A à 35 PV, porte de Plot_1 à 250 PV (50 × 5)")
hitHandlers = FAKE_REMOTES.HitWindow.serverHandlers

local WC = requireModule(MODULES["client/Controllers/WindowController.luau"], "client")
local SC = requireModule(MODULES["client/Controllers/ShatterController.luau"], "client")
local HC = requireModule(MODULES["client/Controllers/HitController.luau"], "client")
local TC = requireModule(MODULES["client/Controllers/TruckController.luau"], "client")
local DNC = requireModule(MODULES["client/Controllers/DamageNumberController.luau"], "client")
requireModule(MODULES["client/Controllers/AnimationController.luau"], "client")
local HitFeedback = requireModule(MODULES["shared/Config/HitFeedback.luau"], "client")
local Shatter = requireModule(MODULES["shared/Config/Shatter.luau"], "client")
WC.Init()
taskLib.spawn(WC.Start)
taskLib.spawn(SC.Start)
taskLib.spawn(HC.Start)
taskLib.spawn(TC.Start)
taskLib.spawn(DNC.Start)
step(0.5)
check(playerGui:FindFirstChild("BB_WindowHP_EventTruck") ~= nil, "TruckController suit le camion (sa barre de vie)")
check(type(TC.LocalHit) == "function", "TruckController.LocalHit existe (retour local du coup sur le camion)")
local D = HitFeedback.Damage
local T = HitFeedback.Truck
check(D.Prefix == "-" and D.Template == "BB_Damage" and T.HitSound == "Truck_Hit", "Config/HitFeedback : préfixe « - », BB_Damage, Truck_Hit")
check(table.isfrozen(HitFeedback) and table.isfrozen(D) and table.isfrozen(T), "Config/HitFeedback gelée")

local tool = new("Tool", { Name = "Poings" })
tool:SetAttribute("ToolId", "Fists")
tool.Parent = LOCAL.Character
step(0.05)

---------------------------------------------------------------- dégâts flottants : coup d'un autre joueur
print("\n== Dégâts flottants : coup validé d'un autre joueur sur une vitrine")
local t0 = now()
serverHit(OTHER, "STORE_Z1_Superette")
local echoes = sentTo("WindowHit", nil, "STORE_Z1_Superette")
check(#echoes == 2, `WindowHit au frappeur et au joueur proche ({#echoes})`)
local toLocal = sentTo("WindowHit", LOCAL, "STORE_Z1_Superette")[1]
check(toLocal and toLocal.args.n == 4 and toLocal.args[3] == OTHER and toLocal.args[4] == 5, "arguments : id, point, frappeur, dégâts (5)")
local hitPoint = toLocal.args[2]
check(#numbers() == 0, "rien avant que le message n'arrive")
step(LATENCY + 0.01)
local n1 = lastNumber()
check(#numbers() == 1 and textOf(n1) == "-5", `un chiffre « -5 » (lu : {textOf(n1)})`)
check(n1 and (n1.Position - (hitPoint + Vector3.new(0, 0.5, 0))).Magnitude < 1e-6, "il part du point de frappe calculé par le serveur, un demi-stud au-dessus")
local g1 = guiOf(n1)
check(g1 and g1.Name == "DamageNumber_V0" and g1.Adornee == n1 and g1.AlwaysOnTop == true and g1.LightInfluence == 0, "chiffre V0 : accroché au point, toujours devant le décor")
check(g1 and g1.Size.X.Scale == 0 and g1.Size.Y.Scale == 0 and g1.Size.Y.Offset == 44 and g1.Size.X.Offset == 200, "taille fixe à l'écran : 44 px de haut (lisible sur téléphone), 200 de large")
local l1 = labelOf(n1)
check(l1 and l1.TextScaled == true and l1.Font == Enum.Font.GothamBlack and l1.TextColor3 == Color3.fromRGB(255, 255, 255) and l1:FindFirstChildOfClass("UIStroke") ~= nil, "blanc, cerclé de sombre, police GothamBlack")
local target1, scale1 = popTarget(n1)
check(near(target1, 0.7) and near(scale1.Scale, 0.7 * 0.4), `coup d'un autre : 70 % de la taille, apparaît à 40 % (cible {target1})`)
local rise = tweenGoal(g1, "StudsOffsetWorldSpace")
check(rise and near(rise.Y, 3.5) and math.abs(rise.X) <= 1.2 + 1e-6 and math.abs(rise.Z) <= 1.2 + 1e-6, `il jaillit de 3,5 studs vers le haut, ±1,2 sur le côté ({rise})`)
check(logHas("[DamageNumber] BB_Damage absent de ReplicatedStorage.Assets.UI : chiffres de dégâts V0 du code", "PRINT", "client"), "Studio : une ligne, modèle BB_Damage pas livré")
step(0.6)
check(tweenGoal(l1, "TextTransparency") == 1 and tweenGoal(l1:FindFirstChildOfClass("UIStroke"), "Transparency") == 1, "s'efface sur la fin (texte et contour)")
step(0.5)
check(#numbers() == 0 and n1.Parent == nil, "retiré après sa vie (0,9 s)")

---------------------------------------------------------------- dégâts flottants : coup du joueur local
print("\n== Dégâts flottants : coup du joueur local (HitController), à la réponse du serveur")
DAMAGE[LOCAL] = 4.5
step(0.2)
local tc = now()
tool.Activated:Fire()
step(0.02)
check(soundCount("Glass_Hit", tc) == 1, "retour local tout de suite : son de verre")
check(#numbers() == 0, "pas de chiffre au clic : il attend la validation du serveur")
step(2 * LATENCY + 0.01)
local n2 = lastNumber()
check(#numbers() == 1 and textOf(n2) == "-4.5", `chiffre « -4.5 » à l'écho du serveur (lu : {textOf(n2)})`)
local target2 = popTarget(n2)
check(near(target2, 1), `son propre coup : en grand (cible {target2})`)
step(1.2)

print("\n== Format du nombre (Shared/Format, comme les dégâts du HUD)")
local cases = { { 4.5, "-4.5" }, { 12, "-12" }, { 999, "-999" }, { 1234, "-1.2K" }, { 12_400, "-12.4K" }, { 2_500_000, "-2.5M" }, { 0.3, "-0.3" }, { 100.7, "-100" } }
for _, case in cases do
	injectHit("STORE_Z1_Superette", windowA.Position, LOCAL, case[1])
	step(0.02)
	local text = textOf(lastNumber())
	check(text == case[2], `{case[1]} → « {case[2]} » (lu : {text})`)
end
step(1.2)
local before = #numbers()
injectHit("STORE_Z1_Superette", windowA.Position, LOCAL, nil)
injectHit("STORE_Z1_Superette", windowA.Position, LOCAL, 0)
injectHit("STORE_Z1_Superette", windowA.Position, LOCAL, 0 / 0)
step(0.02)
check(#numbers() == before, "sans dégâts (ancien serveur), 0 ou NaN : pas de chiffre")
-- Vrai serveur, gros dégâts.
DAMAGE[OTHER] = 1234
serverHit(OTHER, "STORE_Z1_Superette")
step(LATENCY + 0.01)
check(textOf(lastNumber()) == "-1.2K", "serveur : 1234 dégâts → « -1.2K »")
DAMAGE[OTHER] = 5
step(1.2)
WS.Rebuild("STORE_Z1_Superette")
step(0.2)

---------------------------------------------------------------- coups refusés : aucun chiffre
print("\n== Coups refusés par le serveur : aucun chiffre")
step(1.1)
local function noNumberFor(label, fn)
	local sentBefore = #FAKE_REMOTES.WindowHit.sent
	local numbersBefore = #numbers()
	fn()
	step(2 * LATENCY + 0.05)
	check(#FAKE_REMOTES.WindowHit.sent == sentBefore and #numbers() == numbersBefore, label)
end
place(root, Vector3.new(-3, 3, 8)) -- 11,8 studs de la vitre A
noNumberFor("trop loin (11,8 studs, 10 au plus) : ni WindowHit ni chiffre", function()
	serverHit(LOCAL, "STORE_Z1_Superette")
end)
place(root, Vector3.new(-3, 3, 15))
HOLDING[LOCAL] = false
noNumberFor("outil de casse pas en main : rien", function()
	serverHit(LOCAL, "STORE_Z1_Superette")
end)
HOLDING[LOCAL] = nil
local canBeHit = WS.CanBeHit
WS.CanBeHit = function()
	return false
end
noNumberFor("CanBeHit refuse (bouclier, immunité) : rien", function()
	serverHit(LOCAL, "STORE_Z1_Superette")
end)
WS.CanBeHit = canBeHit
noNumberFor("sa propre porte de boutique (Plot_2) : rien", function()
	serverHit(LOCAL, "Plot_2")
end)
noNumberFor("vitrine inconnue : rien", function()
	serverHit(LOCAL, "Inconnue")
end)
DAMAGE[LOCAL] = 0
noNumberFor("dégâts nuls (profil pas chargé) : rien", function()
	serverHit(LOCAL, "STORE_Z1_Superette")
end)
DAMAGE[LOCAL] = 4.5

---------------------------------------------------------------- coup qui casse
print("\n== Coup qui casse : son chiffre part avant WindowBroken")
DAMAGE[LOCAL] = 1000
local brokenBefore = #FAKE_REMOTES.WindowBroken.sent
local hitsBefore = #FAKE_REMOTES.WindowHit.sent
step(0.2)
tool.Activated:Fire()
step(LATENCY + 0.01)
check(#FAKE_REMOTES.WindowBroken.sent == brokenBefore + 1 and WS.IsBroken("STORE_Z1_Superette"), "le serveur casse la vitre")
local lastHits = {}
for i = hitsBefore + 1, #FAKE_REMOTES.WindowHit.sent do
	table.insert(lastHits, FAKE_REMOTES.WindowHit.sent[i])
end
local broken = FAKE_REMOTES.WindowBroken.sent[brokenBefore + 1]
local allBefore = #lastHits == 2
for _, e in lastHits do
	if e.seq > broken.seq or e.args[4] ~= 1000 then
		allBefore = false
	end
end
check(allBefore, `WindowHit (1000 dégâts) au frappeur et au joueur proche, envoyé avant WindowBroken ({#lastHits})`)
step(LATENCY + 0.01)
check(textOf(lastNumber()) == "-1K", `chiffre du coup qui casse : « -1K » (lu : {textOf(lastNumber())})`)
check(stars("STORE_Z1_Superette") == nil, "pas d'étoile qui reste : elle part avec la casse")
step(1.2)
noNumberFor("vitre cassée : un coup de plus n'affiche rien", function()
	serverHit(OTHER, "STORE_Z1_Superette")
end)
DAMAGE[LOCAL] = 4.5
WS.Rebuild("STORE_Z1_Superette")
step(0.3)

-- WindowHit en retard, après WindowBroken (non fiable) : ignoré par ShatterController, chiffre quand même.
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z1_Kiosque", windowB.Position + Vector3.new(0, 0, -0.2))
step(0.02)
injectHit("STORE_Z1_Kiosque", windowB.Position + Vector3.new(0, 0, -0.2), OTHER, 7)
step(0.02)
check(stars("STORE_Z1_Kiosque") == nil and textOf(lastNumber()) == "-7", "WindowHit arrivé après la casse : pas d'étoile, le chiffre s'affiche")
step(3)
-- La vitre B n'était cassée que chez le client : Broken repasse par true puis false (WindowController
-- la voit reconstruite, ShatterController l'oublie).
windowB:SetAttribute("Broken", true)
step(0.05)
windowB:SetAttribute("Broken", false)
step(1)

---------------------------------------------------------------- porte de boutique
print("\n== Porte de boutique d'un autre joueur (PlotDoor/Window)")
place(root, Vector3.new(-40, 3, 14)) -- devant la porte de Plot_1 (Clement)
step(0.2)
local tp = now()
tool.Activated:Fire()
step(2 * LATENCY + 0.01)
local toMe = sentTo("WindowHit", LOCAL, "Plot_1")
check(#toMe == 1 and toMe[1].args[4] == 4.5, "le serveur valide le coup sur la porte : WindowHit avec 4,5 dégâts")
check(textOf(lastNumber()) == "-4.5" and near(popTarget(lastNumber()), 1), "chiffre « -4.5 » en grand au-dessus de la porte")
check(soundCount("Glass_Hit", tp) == 1, "la porte garde son retour de verre (comme avant)")
step(1.2)

---------------------------------------------------------------- son du coup sur la vitre : il monte
-- Vitre B pleine côté serveur (aucun WindowHP ne vient contredire ceux du test).
print("\n== Son du coup sur la vitre : plus aigu quand les PV baissent")
local pitches = {}
for _, f in { 1, 0.5, 0.1 } do
	FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z1_Kiosque", f * 35, 35)
	step(0.05)
	injectHit("STORE_Z1_Kiosque", windowB.Position + Vector3.new(0, 0, -0.2), OTHER, 1)
	step(0.05)
	local s = lastSound("Glass_Hit")
	table.insert(pitches, s and s.speed)
	check(within(s and s.speed, 0.9 + 0.45 * (1 - f), 0.03), `PV à {f * 100} % : hauteur {string.format("%.3f", s and s.speed or 0)} (attendu {0.9 + 0.45 * (1 - f)} ± 3 %)`)
end
check(pitches[1] < pitches[2] and pitches[2] < pitches[3], "le son monte à mesure que les PV baissent")
FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z1_Kiosque", 35, 35) -- pleine : ses étoiles s'effacent
step(1.5)

---------------------------------------------------------------- fissures aux trois seuils
print("\n== Fissures aux trois seuils (75, 50, 25 % des PV), par le vrai serveur")
check(stars("STORE_Z1_Kiosque") == nil, "vitre B sans étoile au départ")
place(otherRoot, Vector3.new(2, 3, -25)) -- devant la vitre B (35 PV)
DAMAGE[OTHER] = 1
step(0.2)
serverHit(OTHER, "STORE_Z1_Kiosque") -- 35 → 34 (97 %)
step(0.2)
local _, front = stars("STORE_Z1_Kiosque")
check(#front == 1 and front[1].Image == "rbxassetid://75" and near(front[1].ImageTransparency, 0.35) and near(front[1].Size.Y.Scale, 1.4 / 7), "97 % : petite étoile discrète (niveau 0)")
DAMAGE[OTHER] = 9.5
-- Un coup, puis le temps que WindowHP arrive (tick de 0,1 s + latence) et que l'étoile grandisse
-- (tween de Cracks.PopTime, 0,12 s).
local function hitB()
	serverHit(OTHER, "STORE_Z1_Kiosque")
	step(0.35)
	local _, labels = stars("STORE_Z1_Kiosque")
	return labels[1], WC.GetFraction("STORE_Z1_Kiosque")
end
local label, fraction = hitB() -- ≈ 70 %
check(label.Image == "rbxassetid://75" and label.ImageTransparency == 0 and near(label.Size.Y.Scale, 2.4 / 7), `sous 75 % ({string.format("%.1f", fraction * 100)} %) : WIN_Crack_75, 2,4 studs`)
label, fraction = hitB() -- ≈ 43 %
check(label.Image == "rbxassetid://50" and near(label.Size.Y.Scale, 3.4 / 7), `sous 50 % ({string.format("%.1f", fraction * 100)} %) : WIN_Crack_50, 3,4 studs`)
label, fraction = hitB() -- ≈ 16 %
check(label.Image == "rbxassetid://25" and near(label.Size.Y.Scale, 4.6 / 7), `sous 25 % ({string.format("%.1f", fraction * 100)} %) : WIN_Crack_25, 4,6 studs`)
check(Shatter.Cracks.Thresholds[1] == 0.75 and Shatter.Cracks.Thresholds[2] == 0.5 and Shatter.Cracks.Thresholds[3] == 0.25, "seuils lus dans Balance.Window.CrackThresholds (doc : 75, 50, 25 %)")
DAMAGE[OTHER] = 5
step(0.5)
-- Seuils exacts : PV injectés côté client sur la vitre A (pleine côté serveur : aucun WindowHP ne
-- vient les contredire).
injectHit("STORE_Z1_Superette", windowA.Position + Vector3.new(0, 0, -0.2), OTHER, 1)
step(0.05)
local function imageAt(f)
	FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z1_Superette", f * 35, 35)
	step(0.2)
	local _, labels = stars("STORE_Z1_Superette")
	local l = labels[1]
	return if l then `{l.Image} {l.ImageTransparency}` else "aucune"
end
local exact = {
	{ 0.7501, "rbxassetid://75 0.35" },
	{ 0.75, "rbxassetid://75 0" },
	{ 0.5001, "rbxassetid://75 0" },
	{ 0.5, "rbxassetid://50 0" },
	{ 0.2501, "rbxassetid://50 0" },
	{ 0.25, "rbxassetid://25 0" },
}
for _, case in exact do
	local got = imageAt(case[1])
	check(got == case[2], `PV à {case[1] * 100} % : {case[2]} (lu : {got})`)
end
FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z1_Superette", 35, 35)
step(0.6)

---------------------------------------------------------------- camion
print("\n== Camion : coup du joueur local (son tout de suite, chiffre à l'écho), pas d'effet de verre")
place(root, Vector3.new(100, 3, -20)) -- à 5 studs du camion, face à lui
place(otherRoot, Vector3.new(106, 3, -20))
camera.CFrame = CFrame.new(100, 8, -35)
step(1.1)
local cubesBefore = glassCubes()
local th = now()
local glassBefore = soundCount("Glass_Hit")
tool.Activated:Fire()
step(0.01)
local th1 = lastSound("Truck_Hit")
check(soundCount("Truck_Hit", th) == 1, "son du coup sur le camion tout de suite (pas d'animation : au clic)")
check(th1 and th1.at and (th1.at - Vector3.new(100, 3, -15)).Magnitude < 1e-6, "joué au point de frappe (point de la boîte du camion le plus proche)")
check(th1 and within(th1.speed, 1.1 * 0.9, 0.03), `hauteur à PV pleins : 1,1 (Clément) × 0,9 ± 3 % (lu : {th1 and th1.speed})`)
check(#numbers() == 0, "pas encore de chiffre")
step(2 * LATENCY + 0.01)
local truckEcho = sentTo("WindowHit", LOCAL, truckId)
check(#truckEcho == 1 and truckEcho[1].args[4] == 4.5 and truckEcho[1].args[3] == LOCAL, "WindowHit du camion : 4,5 dégâts, frappeur = joueur local")
check(textOf(lastNumber()) == "-4.5" and near(popTarget(lastNumber()), 1), "chiffre « -4.5 » en grand")
check(soundCount("Truck_Hit", th) == 1, "l'écho de son propre coup ne rejoue pas le son")
step(0.12)
check(truck:GetAttribute("HP") == 995.5, `PV du camion au tick suivant : 995,5 ({truck:GetAttribute("HP")})`)
check(stars(truckId) == nil and soundCount("Glass_Hit") == glassBefore and glassCubes() == cubesBefore, "aucun effet de verre sur le camion (ni étoile, ni son de verre, ni mini-éclats)")
check(#sentTo("WindowHP", nil, truckId) == 0 and #sentTo("WindowBroken", nil, truckId) == 0, "ni WindowHP ni WindowBroken pour le camion")
step(1.2)

print("\n== Camion, avec l'animation : le son part au marqueur Impact, avec le coup")
ANIM.NoTrack = false
local ta = now()
tool.Activated:Fire()
step(0.1)
check(soundCount("Truck_Hit", ta) == 0 and #sentTo("WindowHit", LOCAL, truckId) == 1, "avant le marqueur : ni son, ni coup")
ANIM.Last:FireMarker("Impact")
step(0.01)
check(soundCount("Truck_Hit", ta) == 1, "marqueur Impact : son du coup")
step(2 * LATENCY + 0.01)
check(#sentTo("WindowHit", LOCAL, truckId) == 2 and textOf(lastNumber()) == "-4.5", "le coup part au marqueur : écho et chiffre")
local tm = now()
tool.Activated:Fire()
step(0.35)
check(soundCount("Truck_Hit", tm) == 1, "marqueur jamais atteint : le son part au délai max (0,3 s), avec le coup")
ANIM.NoTrack = true
step(1.2)

print("\n== Camion : coup d'un autre joueur")
local to = now()
serverHit(OTHER, truckId)
step(LATENCY + 0.01)
check(soundCount("Truck_Hit", to) == 1, "son du coup d'un autre, à la réponse du serveur")
check(textOf(lastNumber()) == "-5" and near(popTarget(lastNumber()), 0.7), "chiffre « -5 », plus petit (70 %)")
step(1.2)
camera.CFrame = CFrame.new(100, 8, -300) -- caméra à 285 studs : trop loin
local tf = now()
local farBefore = #numbers()
serverHit(OTHER, truckId)
step(LATENCY + 0.01)
check(#sentTo("WindowHit", LOCAL, truckId) == 5 and soundCount("Truck_Hit", tf) == 0 and #numbers() == farBefore, "caméra trop loin : ni son (100 studs) ni chiffre (60 studs) pour le coup d'un autre")
camera.CFrame = CFrame.new(100, 8, -35)
step(1.2)

print("\n== Camion : le son monte quand les PV baissent (attributs HP et MaxHP)")
local truckPitches = {}
for _, hp in { 1000, 500, 100, 0 } do
	truck:SetAttribute("HP", hp)
	TC.LocalHit(truckId, Vector3.new(100, 3, -15))
	local s = lastSound("Truck_Hit")
	table.insert(truckPitches, s and s.speed)
	local expected = 1.1 * (0.9 + 0.4 * (1 - hp / 1000))
	check(within(s and s.speed, expected, 0.03), `{hp} PV : hauteur {string.format("%.3f", s and s.speed or 0)} (attendu {string.format("%.3f", expected)} ± 3 %)`)
end
check(truckPitches[1] < truckPitches[2] and truckPitches[2] < truckPitches[3], "le son du camion monte avec les dégâts")
local nBefore = soundCount("Truck_Hit")
TC.LocalHit("STORE_Z1_Superette", windowA.Position)
TC.LocalHit("Inconnu", Vector3.zero)
check(soundCount("Truck_Hit") == nBefore, "LocalHit sur un id qui n'est pas un camion : rien")
step(0.1)

print("\n== Camion : coup qui casse, puis plus rien")
DAMAGE[LOCAL] = 2000
local tk = now()
tool.Activated:Fire()
step(2 * LATENCY + 0.01)
check(truck:GetAttribute("Broken") == true and truck:GetAttribute("HP") == 0, "serveur : camion cassé (Broken, HP = 0)")
check(textOf(lastNumber()) == "-2K", `chiffre du coup qui casse le camion : « -2K » (lu : {textOf(lastNumber())})`)
check(soundCount("Truck_Hit", tk) == 1, "son du coup qui casse")
step(0.2)
local sentBeforeEnd = #FAKE_REMOTES.WindowHit.sent
local numbersBeforeEnd = #numbers()
tool.Activated:Fire()
serverHit(OTHER, truckId)
step(2 * LATENCY + 0.05)
check(#FAKE_REMOTES.WindowHit.sent == sentBeforeEnd and #numbers() == numbersBeforeEnd, "camion cassé : plus de coup, plus de chiffre")
truck:SetAttribute("ExplodedAt", Workspace:GetServerTimeNow())
step(0.05)
TC.LocalHit(truckId, Vector3.new(100, 3, -15))
check(soundCount("Truck_Hit", tk) == 1, "camion explosé : plus de son de coup")
DAMAGE[LOCAL] = 4.5
step(1.2)

---------------------------------------------------------------- modèle de Clément
print("\n== Modèle BB_Damage de Clément (sous-dossier d'Assets/UI) : sa taille et son style gardés")
camera.CFrame = CFrame.new(-40, 8, 5) -- devant la porte de Plot_1
local combat = folder(ui, "Combat")
local template = new("BillboardGui", { Name = "BB_Damage", Size = UDim2.new(3, 0, 1.2, 0), MaxDistance = 50, AlwaysOnTop = false, StudsOffsetWorldSpace = Vector3.new(0, 1, 0) }, combat)
local back = new("Frame", { Name = "Back", BackgroundTransparency = 0.5 }, template)
local tl = new("TextLabel", { Name = "Label", Text = "-123", TextColor3 = Color3.fromRGB(255, 220, 0), BackgroundTransparency = 1 }, back)
new("UIScale", { Name = "UIScale", Scale = 1.25 }, tl)
injectHit("Plot_1", door1.Position, LOCAL, 8)
step(0.02)
local nc = lastNumber()
local gc = guiOf(nc)
check(gc and gc.Name == "BB_Damage" and gc.Size.X.Scale == 3 and gc.Size.Y.Scale == 1.2 and gc.MaxDistance == 50 and gc.AlwaysOnTop == false, "copie de BB_Damage : taille, portée et réglages de Clément")
local lc = labelOf(nc)
check(lc and lc.Text == "-8" and lc.TextColor3 == Color3.fromRGB(255, 220, 0), "le code n'écrit que le texte : « -8 », couleur de Clément gardée")
check(near(popTarget(nc), 1.25), "UIScale de Clément gardé (1,25) pour son propre coup")
local riseC = tweenGoal(gc, "StudsOffsetWorldSpace")
check(riseC and near(riseC.Y, 1 + 3.5), "montée ajoutée au décalage de Clément")
check(tl.Text == "-123" and tl.Parent == back and template.Parent == combat and tl.UIScale.Scale == 1.25, "le modèle de Clément n'a pas bougé")
step(0.6)
check(tweenGoal(gc.Back, "BackgroundTransparency") == 1 and tweenGoal(lc, "TextTransparency") == 1, "effacement : son fond et son texte")
injectHit("Plot_1", door1.Position, OTHER, 8)
step(0.02)
check(near(popTarget(lastNumber()), 1.25 * 0.7), "coup d'un autre : 70 % de sa taille")
step(1.2)
tl.Name = "Texte"
injectHit("Plot_1", door1.Position, LOCAL, 9)
step(0.02)
check(guiOf(lastNumber()).Name == "DamageNumber_V0" and textOf(lastNumber()) == "-9", "BB_Damage sans TextLabel Label : chiffre V0 du code")
check(logHas("BB_Damage sans TextLabel Label", "WARN", "client"), "Studio : un avertissement")
template.Parent = nil
step(1.2)

---------------------------------------------------------------- au plus 16 chiffres
print("\n== Au plus 16 chiffres à la fois")
for i = 1, 20 do
	injectHit("Plot_1", door1.Position, LOCAL, i)
end
step(0.02)
local list = numbers()
check(#list == 16 and textOf(list[1]) == "-5" and textOf(list[16]) == "-20", `les 16 plus récents restent ({#list}, du « {textOf(list[1])} » au « {textOf(list[#list])} »)`)
step(1.2)
check(#numbers() == 0, "tous retirés")

---------------------------------------------------------------- sons pas livrés
print("\n== Sons pas livrés : rien ne joue, sans erreur")
soundsFolder.Parent = nil
local ts = #SOUND_LOG
local watchTruck = new("Model", { Name = "EventTruck2" })
new("Part", { Name = "Body", Size = Vector3.new(12, 10, 30), CFrame = CFrame.new(100, 5, 60) }, watchTruck)
watchTruck.Parent = Workspace
addTag(watchTruck, "EventTruck")
local id2 = WS.AddTarget(watchTruck, 1000)
step(0.3)
TC.LocalHit(id2, Vector3.new(100, 3, 45))
injectHit("STORE_Z1_Kiosque", windowB.Position, OTHER, 3)
step(0.3)
check(#SOUND_LOG == ts, "ni son de camion ni son de verre")
check(logHas("[TruckController] Truck_Hit absent de ReplicatedStorage.Assets.Sounds : coups sur le camion muets (L-052)", "PRINT", "client"), "Studio : une ligne pour Truck_Hit")
check(textOf(lastNumber()) == "-3", "le chiffre, lui, s'affiche")
soundsFolder.Parent = assets
watchTruck:Destroy()
step(0.2)
check(truckHitSound.Parent ~= nil, "son rendu")

---------------------------------------------------------------- bilan
print("\n== Avertissements de la sortie")
local bad = 0
for _, line in LOG do
	if line.kind == "WARN" and not string.find(line.text, "[WindowService] coup de", 1, true) and not string.find(line.text, "BB_Damage sans TextLabel", 1, true) then
		bad += 1
		print("    " .. `[{line.side}] {line.text}`)
	end
end
check(bad == 0, "aucun avertissement imprévu (seuls les refus de WindowService en Studio et le modèle mal nommé)")
summary()
