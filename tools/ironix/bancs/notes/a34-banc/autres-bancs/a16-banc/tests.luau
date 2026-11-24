---------------------------------------------------------------- scénarios (agent a16, DEV-016)
-- Copie a34 (vague 12, DEV-053) : le coup qui casse envoie lui aussi WindowHit, avec ses dégâts, juste
-- avant WindowBroken (chiffre de dégâts flottant). Deux vérifications changent : « WindowHit aussi
-- pour le coup qui casse » (au lieu de « pas de WindowHit ») et la reconstruction en cours de route,
-- attendue 0,2 s plus tard (les mini-éclats de ce coup, 0,6 s de vie, ne sont pas ceux de la casse).
print("== Banc a16 : casse de vitrine (DEV-016)")

-- Faux Net : pas de vrai réseau. Routage serveur ↔ client local avec LATENCY de retard ; chaque
-- envoi est contrôlé avec le vrai Definitions + Validate.
LATENCY = 0.05
SOURCES["shared/Net/Net.luau"] = "return FAKE_NET"
-- Faux ToolService : dégâts réglables par joueur, outil toujours en main.
DAMAGE = {}
SOURCES["server/Services/ToolService.luau"] = [[
local ToolService = {}
function ToolService.GetHitDamage(player) return DAMAGE[player] or 5 end
function ToolService.IsHoldingTool(_player) return true end
return ToolService
]]
-- Faux AnimationController : rend une piste factice (marqueur Impact déclenché par le test).
-- Les modules écrivent dans leur propre environnement : l'état partagé passe par une table.
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
			table.insert(r.sent, { t = now(), to = player, args = args })
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
			table.insert(r.sent, { t = now(), to = "all", args = args })
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
new("Part", { Name = "Floor", Size = Vector3.new(400, 1, 400), CFrame = CFrame.new(0, -0.5, 0) }, Workspace)
local camera = new("Camera", { Name = "Camera", CFrame = CFrame.new(-3, 6, 10) }, Workspace)
Workspace.CurrentCamera = camera
new("Terrain", { Name = "Terrain" }, Workspace)

-- Assets de Clément
local assets = folder(ReplicatedStorage, "Assets")
local fx = folder(assets, "FX")
new("Decal", { Name = "WIN_Crack_75", Texture = "rbxassetid://75" }, fx)
new("Decal", { Name = "WIN_Crack_50", Texture = "rbxassetid://50" }, fx)
new("Decal", { Name = "WIN_Crack_25", Texture = "rbxassetid://25" }, fx)
new("Decal", { Name = "FX_GlassSparkle", Texture = "rbxassetid://9" }, fx)
local sounds = folder(folder(assets, "Sounds"), "Glass")
for _, name in { "Glass_Hit", "Glass_BreakThud", "Glass_BreakShatter", "Glass_BreakDebris" } do
	new("Sound", { Name = name, PlaybackSpeed = 1 }, sounds)
end
local ui = folder(assets, "UI")
local bb = new("BillboardGui", { Name = "BB_WindowHP", Size = UDim2.new(6, 0, 1.6, 0), StudsOffset = Vector3.new(0, 4.5, 0), MaxDistance = 80 }, ui)
new("TextLabel", { Name = "Label", Text = "300 / 400" }, bb)
local bar = new("Frame", { Name = "Bar" }, bb)
new("Frame", { Name = "Fill", Size = UDim2.new(0.75, 0, 1, 0) }, bar)

-- Vitres fracturées M (12 × 7 × 0,4, pivot en bas au centre), rangées à une position et une
-- orientation quelconques : l'alignement ne doit dépendre que de leur boîte englobante.
local windows = folder(assets, "Windows")
local TEMPLATE_PIVOT = CFrame.new(100, 50, -70) * CFrame.Angles(0, math.rad(90), 0)
local function fracturedM(name, count, impact, pivot, transparency)
	local model = new("Model", { Name = name })
	model.WorldPivot = pivot
	new("MeshPart", {
		Name = "Shard_01",
		Size = Vector3.new(0.8, 0.8, 0.4),
		CFrame = pivot * CFrame.new(impact),
		Material = Enum.Material.Glass,
		Transparency = transparency,
		Color = GLASS,
	}, model)
	local cols, rows = 8, 5
	local cw, ch = 12 / cols, 7 / rows
	for i = 1, count - 1 do
		local c, r = (i - 1) % cols, (i - 1) // cols
		new("MeshPart", {
			Name = string.format("Shard_%02d", i + 1),
			Size = Vector3.new(cw, ch, 0.4),
			CFrame = pivot * CFrame.new(-6 + (c + 0.5) * cw, (r + 0.5) * ch, 0),
			Material = Enum.Material.Glass,
			Transparency = transparency,
			Color = GLASS,
		}, model)
	end
	return model
end
fracturedM("WIN_M_Fractured", 36, Vector3.new(0.24, 3.86, 0), TEMPLATE_PIVOT, 0.55).Parent = windows
fracturedM("WIN_M_Fractured_Left", 35, Vector3.new(3.86, 3.08, 0), TEMPLATE_PIVOT * CFrame.new(30, 0, 0), 0.55).Parent = windows
fracturedM("WIN_M_Fractured_Right", 38, Vector3.new(-4.33, 3.71, 0), TEMPLATE_PIVOT * CFrame.new(-30, 0, 0), 0.55).Parent = windows

-- Magasin de Clément : vitre MeshPart 12 × 7 × 0,4, WindowFractured = copie de WIN_M_Fractured
-- (invisible), Bounds à l'intérieur, façade percée, mur du fond.
local map = folder(Workspace, "Map")
local function clementStore(name, pivot)
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
	local fractured = fracturedM("WindowFractured", 36, Vector3.new(0.24, 3.86, 0), pivot * CFrame.new(0, 0.5, 0), 1)
	for _, shard in fractured:GetDescendants() do
		shard.CanCollide = false
		shard.CanQuery = false
	end
	fractured.Parent = model
	new("Part", { Name = "Bounds", Size = Vector3.new(20, 10, 22), CFrame = pivot * CFrame.new(0, 5, 12), Transparency = 1, CanCollide = false, CanQuery = false }, model)
	new("Part", { Name = "FrontWall_L", Size = Vector3.new(6, 10, 1), CFrame = pivot * CFrame.new(-9, 5, 0) }, model)
	new("Part", { Name = "FrontWall_R", Size = Vector3.new(6, 10, 1), CFrame = pivot * CFrame.new(9, 5, 0) }, model)
	new("Part", { Name = "FrontWall_Top", Size = Vector3.new(12, 3, 1), CFrame = pivot * CFrame.new(0, 9, 0) }, model)
	new("Part", { Name = "BackWall", Size = Vector3.new(24, 12, 1), CFrame = pivot * CFrame.new(0, 6, 24) }, model)
	model:SetAttribute("Zone", 1)
	model.Parent = map
	addTag(model, "NPCStore")
	return model
end
local storeA = clementStore("STORE_Z1_Superette", CFrame.new(0, 0, 20))
local storeB = clementStore("STORE_Z1_Kiosque", CFrame.new(0, 0, -20) * CFrame.Angles(0, math.pi, 0))
-- Magasin de la greybox, vitre S (8 × 6), 40 éclats en grille, pivot au centre.
local storeC = new("Model", { Name = "STORE_Z2_Jouets" })
do
	local pivot = CFrame.new(40, 0, 20)
	storeC.WorldPivot = pivot
	new("Part", { Name = "Window", Size = Vector3.new(8, 6, 0.4), CFrame = pivot * CFrame.new(0, 3.5, 0), Material = Enum.Material.Glass, Transparency = 0.5, Color = GLASS }, storeC)
	local fractured = new("Model", { Name = "WindowFractured" })
	for r = 0, 4 do
		for c = 0, 7 do
			new("Part", {
				Name = string.format("Shard_%02d", r * 8 + c + 1),
				Size = Vector3.new(1, 1.2, 0.4),
				CFrame = pivot * CFrame.new(-3.5 + c, 0.5 + 0.6 + r * 1.2, 0),
				Material = Enum.Material.Glass,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				Color = GLASS,
			}, fractured)
		end
	end
	fractured.WorldPivot = pivot * CFrame.new(0, 3.5, 0)
	fractured.Parent = storeC
	new("Part", { Name = "Bounds", Size = Vector3.new(14, 8, 16), CFrame = pivot * CFrame.new(0, 4, 9), Transparency = 1, CanCollide = false, CanQuery = false }, storeC)
	storeC:SetAttribute("Zone", 2)
	storeC.Parent = map
	addTag(storeC, "NPCStore")
end
local windowA = storeA.Window
local windowB = storeB.Window
local windowC = storeC.Window

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
local FAR = addPlayer("Loin", 3, Vector3.new(0, 3, -300))
local NOCHAR = addPlayer("SansPerso", 4, nil)
local localAnimator = LOCAL.Character.Humanoid.Animator
local walkTrack = newTrack("Walk")
rawset(localAnimator, "_tracks", { walkTrack })

local playerGui = LOCAL.PlayerGui
local function fxFolder()
	return Workspace:FindFirstChild("_ShatterFX")
end
local function named(prefix)
	local out = {}
	local f = fxFolder()
	for _, d in if f then f:GetDescendants() else {} do
		if string.sub(d.Name, 1, #prefix) == prefix then
			table.insert(out, d)
		end
	end
	return out
end
local function shardsInFx()
	local out = {}
	local f = fxFolder()
	for _, d in if f then f:GetChildren() else {} do
		if string.match(d.Name, "^Shard_%d+$") then
			table.insert(out, d)
		end
	end
	return out
end
local function stars(windowId)
	local f = fxFolder()
	local canvas = if f then f:FindFirstChild("Cracks_" .. windowId) else nil
	if canvas == nil then
		return nil, {}, {}
	end
	local front, back = {}, {}
	for _, d in canvas.Front.Clip:GetChildren() do
		table.insert(front, d)
	end
	for _, d in canvas.Back.Clip:GetChildren() do
		table.insert(back, d)
	end
	return canvas, front, back
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
local function emits(since)
	local out = {}
	for _, entry in EMIT_LOG do
		if entry.t >= since then
			table.insert(out, entry)
		end
	end
	return out
end
local function warnings()
	local out = {}
	for _, line in LOG do
		if line.kind == "WARN" then
			table.insert(out, `[{line.side}] {line.text}`)
		end
	end
	return out
end

---------------------------------------------------------------- démarrage
print("\n== Démarrage : WindowService (serveur), WindowController, ShatterController, HitController (client)")
local WS = requireModule(MODULES["server/Services/WindowService.luau"], "server")
WS.Init()
taskLib.spawn(WS.Start)
check(windowA:GetAttribute("WindowId") == "STORE_Z1_Superette" and windowA:GetAttribute("MaxHP") == 35, "serveur : vitre A enregistrée, 35 PV")
check(windowC:GetAttribute("MaxHP") == 350, "serveur : vitre C (zone 2) à 350 PV")

local WC = requireModule(MODULES["client/Controllers/WindowController.luau"], "client")
local SC = requireModule(MODULES["client/Controllers/ShatterController.luau"], "client")
local HC = requireModule(MODULES["client/Controllers/HitController.luau"], "client")
requireModule(MODULES["client/Controllers/AnimationController.luau"], "client")
WC.Init()
taskLib.spawn(WC.Start)
taskLib.spawn(SC.Start)
taskLib.spawn(HC.Start)
step(0.5)

local w, m = WC.GetWindow("STORE_Z1_Superette")
check(w == windowA and m == storeA, "GetWindow : vitre A et son magasin")
check(WC.GetWindow("inconnue") == nil, "GetWindow : id inconnu → nil")
check(near(WC.GetFraction("STORE_Z1_Superette"), 1), "GetFraction : 1 sans nouvelles")
check(logHas("assets de la casse : tous présents", "PRINT", "client"), "Studio : assets de la casse tous trouvés")
check(RENDER_STEPS.ShatterCameraShake ~= nil and RENDER_STEPS.ShatterCameraShake.priority == 201, "tremblement branché après la caméra (priorité Camera + 1)")

---------------------------------------------------------------- BB_WindowHP
print("\n== Barre de PV BB_WindowHP")
local barA = playerGui:FindFirstChild("BB_WindowHP_STORE_Z1_Superette")
local barB = playerGui:FindFirstChild("BB_WindowHP_STORE_Z1_Kiosque")
local barC = playerGui:FindFirstChild("BB_WindowHP_STORE_Z2_Jouets")
check(barA ~= nil and barB ~= nil and barC ~= nil, "une copie de BB_WindowHP par vitre, dans le PlayerGui")
check(barA and barA.Adornee == windowA and barA.ResetOnSpawn == false, "accrochée à la vitre, gardée à la réapparition")
check(barA and barA.StudsOffset == Vector3.new(0, 4.5, 0) and barA.MaxDistance == 80, "taille et décalage du modèle gardés")
check(barA and barA.Enabled == true, "vitre A pleine mais joueur à moins de 20 studs : visible")
check(barB and barB.Enabled == false, "vitre B pleine et loin : cachée")
check(barA and barA.Label.Text == "35 / 35", `texte « 35 / 35 » (lu : {barA and barA.Label.Text})`)
check(barA and near(barA.Bar.Fill.Size.X.Scale, 1) and barA.Bar.Fill.Size.Y.Scale == 1, "Fill pleine largeur, hauteur du modèle")
FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z2_Jouets", 123.4, 350)
step(0.3)
check(barC.Enabled == true and barC.Label.Text == "124 / 350", `vitre C entamée et loin : visible, « 124 / 350 » (lu : {barC.Label.Text})`)
check(near(barC.Bar.Fill.Size.X.Scale, 123.4 / 350, 1e-6), "Fill à la largeur des PV")
windowC:SetAttribute("MaxHP", 1_400_000)
FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z2_Jouets", 21_000, 1_400_000)
step(0.3)
check(barC.Label.Text == "21K / 1.4M", `grands nombres abrégés (lu : {barC.Label.Text})`)
windowC:SetAttribute("MaxHP", 350)
FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z2_Jouets", 350, 350)
step(0.3)
check(barC.Enabled == false, "vitre C revenue pleine, loin : cachée")

---------------------------------------------------------------- coup d'un autre joueur (serveur → WindowHit)
print("\n== Coup d'un autre joueur : WindowService diffuse, le client pose une étoile")
local hitHandlers = FAKE_REMOTES.HitWindow.serverHandlers
check(#hitHandlers == 1, "WindowService écoute HitWindow")
local function serverHit(player, windowId)
	for _, handler in hitHandlers do
		taskLib.spawn(handler, player, windowId)
	end
end
local t0 = now()
serverHit(OTHER, "STORE_Z1_Superette")
local sent = FAKE_REMOTES.WindowHit.sent
local recipients = {}
for _, e in sent do
	recipients[e.to] = e
end
check(#sent == 2 and recipients[OTHER] ~= nil and recipients[LOCAL] ~= nil, "WindowHit au frappeur et au joueur proche…")
check(recipients[FAR] == nil and recipients[NOCHAR] == nil, "… ni au joueur loin, ni à celui sans personnage")
local hitPoint = recipients[LOCAL].args[2]
check(recipients[LOCAL].args[1] == "STORE_Z1_Superette" and recipients[LOCAL].args[3] == OTHER, "arguments : id, point, frappeur")
check((hitPoint - Vector3.new(4, 3, 19.8)).Magnitude < 1e-6, `point de frappe = point de la vitre le plus proche du frappeur ({hitPoint})`)
step(0.1)
local canvas, front, back = stars("STORE_Z1_Superette")
check(canvas ~= nil and #front == 1 and #back == 1, "une étoile, sur les deux faces")
if canvas then
	check(canvas.CanCollide == false and canvas.CanQuery == false and canvas.CanTouch == false and canvas.Transparency == 1, "support des étoiles invisible et sans collision")
	check(canvas.Front.Face == Enum.NormalId.Front and canvas.Back.Face == Enum.NormalId.Back, "SurfaceGui sur la face avant et la face arrière")
	check(canvas.Front.Clip.ClipsDescendants == true, "étoiles découpées au bord du verre")
	check((canvas.CFrame.Position - windowA.Position).Magnitude < 1e-6 and near(canvas.Size.Z, 0.46, 1e-6), "support à la place du verre, 0,03 de plus de chaque côté")
	check(orthoError(canvas.CFrame) < 1e-9, "repère du support orthonormé direct")
end
if front[1] then
	local f, b = front[1], back[1]
	check(f.Image == "rbxassetid://75" and near(f.ImageTransparency, 0.35), "niveau 0 (PV > 75 %) : image WIN_Crack_75, plus discrète")
	check(near(f.Position.X.Scale, 0.5 - 4 / 12) and near(f.Position.Y.Scale, 0.5 + 1 / 7), `face avant : x = +4 → gauche du canevas vu de la rue (u = {f.Position.X.Scale})`)
	check(near(b.Position.X.Scale, 0.5 + 4 / 12) and near(b.Position.Y.Scale, 0.5 + 1 / 7), "face arrière : position miroir")
	check(near(f.Size.X.Scale, 1.4 / 12) and near(f.Size.Y.Scale, 1.4 / 7), "taille 1,4 stud, carrée")
	check(near(f.Rotation, -b.Rotation), "rotation miroir sur la face arrière")
end
local cubes = named("GlassCube")
check(#cubes == 5, `5 mini-éclats (petits cubes de verre) pour le coup d'un autre (lu : {#cubes})`)
check(soundCount("Glass_Hit", t0) == 1, "son de verre joué")
local hitSound = lastSound("Glass_Hit")
check(hitSound and hitSound.speed >= 0.9 * 0.97 - 1e-9 and hitSound.speed <= 0.9 * 1.03 + 1e-9, `hauteur à PV pleins : 0,9 ± 3 % (lu : {hitSound and hitSound.speed})`)
check(hitSound and hitSound.at and (hitSound.at - hitPoint).Magnitude < 1e-6, "son joué au point de frappe")
local hitEmits = emits(t0)
check(#hitEmits == 1 and hitEmits[1].count == 4 and hitEmits[1].texture == "rbxassetid://9", "4 paillettes FX_GlassSparkle")
check(hitEmits[1] and hitEmits[1].up.Z < -0.99, "paillettes vers la rue (côté du frappeur)")
step(1)
check(#named("GlassCube") == 0, "mini-éclats retirés après leur vie")
local cubeFloor = true
for _, cube in cubes do
	if cube.Position.Y < -0.01 then
		cubeFloor = false
	end
end
check(cubeFloor, "mini-éclats jamais sous le sol")

print("\n== Étoiles : réutilisation et maximum")
serverHit(OTHER, "STORE_Z1_Superette")
step(0.15)
_, front = stars("STORE_Z1_Superette")
check(#front == 1, "deuxième coup au même endroit : étoile réutilisée")
local function injectHit(windowId, point, hitter)
	FAKE_REMOTES.WindowHit.clientSignal:Fire(windowId, point, hitter)
end
-- Vitre B (tournée de 180°) : étoiles injectées côté client, PV pleins côté serveur.
local centerB = windowB.Position
for i, x in { -5, -3, -1, 1, 3, 5 } do
	injectHit("STORE_Z1_Kiosque", centerB + Vector3.new(x, 0, 0.2), OTHER)
	step(0.05)
end
_, front = stars("STORE_Z1_Kiosque")
check(#front == 6, `6 étoiles écartées de 2 studs (lu : {#front})`)
injectHit("STORE_Z1_Kiosque", centerB + Vector3.new(-1.2, 0.5, 0.2), OTHER)
step(0.05)
_, front = stars("STORE_Z1_Kiosque")
check(#front == 6, "coup à 0,86 stud d'une étoile : réutilisée, toujours 6")
injectHit("STORE_Z1_Kiosque", centerB + Vector3.new(0, 3, 0.2), OTHER)
step(0.05)
local canvasB
canvasB, front = stars("STORE_Z1_Kiosque")
check(#front == 6, "7e endroit : toujours 6 étoiles (la plus ancienne retirée)")
local hasOldest = false
for _, label in front do
	-- vitre B tournée de 180° : x monde −5 = x local +5 → u = 0,5 − 5/12
	if near(label.Position.X.Scale, 0.5 - 5 / 12, 1e-6) then
		hasOldest = true
	end
end
check(not hasOldest, "l'étoile touchée il y a le plus longtemps (x = −5) a disparu")
check(canvasB and orthoError(canvasB.CFrame) < 1e-9 and canvasB.CFrame.ZVector.Z < -0.99, "vitre tournée : normale du support vers l'intérieur (−Z monde)")

print("\n== Étoiles : niveaux de PV (75, 50, 25 %), régénération")
local function hpB(fraction)
	FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z1_Kiosque", fraction * 35, 35)
	step(0.2)
	local _, labels = stars("STORE_Z1_Kiosque")
	return labels[1]
end
local label = hpB(0.7)
check(label.Image == "rbxassetid://75" and label.ImageTransparency == 0 and near(label.Size.X.Scale, 2.4 / 12), "70 % : WIN_Crack_75, 2,4 studs")
label = hpB(0.45)
check(label.Image == "rbxassetid://50" and near(label.Size.X.Scale, 3.4 / 12), "45 % : WIN_Crack_50, 3,4 studs")
label = hpB(0.2)
check(label.Image == "rbxassetid://25" and near(label.Size.X.Scale, 4.6 / 12), "20 % : WIN_Crack_25, 4,6 studs")
label = hpB(0.28)
check(label.Image == "rbxassetid://25", "régénération à 28 % (moins de 25 + 5 %) : reste au niveau 3")
label = hpB(0.31)
check(label.Image == "rbxassetid://50", "31 % : redescend au niveau 2")
label = hpB(0.9)
check(label.Image == "rbxassetid://75" and near(label.ImageTransparency, 0.35), "90 % : niveau 0")
local _, all = stars("STORE_Z1_Kiosque")
check(#all == 6, "toutes les étoiles suivent les PV, aucune perdue")
local tweensBefore = #TWEENS
FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z1_Kiosque", 35, 35)
step(0.1)
local fadeTweens = 0
for i = tweensBefore + 1, #TWEENS do
	if TWEENS[i].Goals.ImageTransparency == 1 then
		fadeTweens += 1
	end
end
check(fadeTweens == 12, `PV pleins : les 6 étoiles (2 faces) s'effacent (lu : {fadeTweens} tweens)`)
step(0.5)
check(canvasB.Parent == nil, "support détruit après l'effacement")
injectHit("STORE_Z1_Kiosque", centerB + Vector3.new(2, 0, 0.2), OTHER)
step(0.05)
local canvasB2
canvasB2, front = stars("STORE_Z1_Kiosque")
check(canvasB2 ~= nil and canvasB2 ~= canvasB and #front == 1, "coup suivant : nouveau support, une seule étoile")
FAKE_REMOTES.WindowHP.clientSignal:Fire("STORE_Z1_Kiosque", 35, 35)
step(0.6)

---------------------------------------------------------------- coup du joueur local (HitController)
print("\n== Coup du joueur local : retour immédiat, étoile à l'écho du serveur")
local tool = new("Tool", { Name = "Poings" })
tool:SetAttribute("ToolId", "Fists")
tool.Parent = LOCAL.Character
step(0.05)
local t1 = now()
local before = #FAKE_REMOTES.WindowHit.sent
tool.Activated:Fire()
check(#named("GlassCube") == 5, "sans animation : mini-éclats tout de suite")
check(soundCount("Glass_Hit", t1) == 1, "son de verre tout de suite")
step(0.04)
check(#named("GlassCube") == 5, "rien n'attend le serveur pour le retour local")
step(0.12)
local echo = FAKE_REMOTES.WindowHit.sent[before + 1]
check(echo ~= nil and echo.args[3] == LOCAL, "le serveur a validé le coup et renvoyé WindowHit (frappeur = joueur local)")
_, front = stars("STORE_Z1_Superette")
check(#front == 2, `étoile du coup local posée à l'écho (lu : {#front} étoiles)`)
check(soundCount("Glass_Hit", t1) == 1, "l'écho de son propre coup ne rejoue ni son ni mini-éclats")

print("\n== Coup local avec animation : calé sur le marqueur Impact")
ANIM.NoTrack = false
step(0.2)
local t2 = now()
tool.Activated:Fire()
check(ANIM.Last ~= nil and ANIM.Last.Name == "HitWindow", "piste HitWindow passée à ShatterController")
check(soundCount("Glass_Hit", t2) == 0, "avant le marqueur : pas encore de son")
step(0.15)
_, front = stars("STORE_Z1_Superette")
local starsBefore = #front
check(starsBefore == 2, "l'écho arrive avant l'impact : l'étoile attend")
ANIM.Last:FireMarker("Impact")
step(0.02)
check(soundCount("Glass_Hit", t2) == 1, "marqueur Impact : son et mini-éclats")
_, front = stars("STORE_Z1_Superette")
check(#front == 2, "l'étoile attendue est posée (même endroit : réutilisée)")
step(0.3)
local t3 = now()
tool.Activated:Fire()
step(0.2)
check(soundCount("Glass_Hit", t3) == 0, "marqueur jamais atteint : on attend…")
step(0.15)
check(soundCount("Glass_Hit", t3) == 1, "… au plus 0,3 s")
ANIM.NoTrack = true
step(1)

---------------------------------------------------------------- casse par le joueur local
print("\n== Casse par le joueur local (participant)")
DAMAGE[LOCAL] = 1000
clearLog()
local brokenBefore = #FAKE_REMOTES.WindowBroken.sent
local hitsBefore = #FAKE_REMOTES.WindowHit.sent
local tb = now()
tool.Activated:Fire()
step(0.06)
check(#FAKE_REMOTES.WindowBroken.sent == brokenBefore + 1, "le serveur casse la vitre et envoie WindowBroken")
-- Copie a34 (DEV-053) : WindowHit aussi pour le coup qui casse, au frappeur et au joueur proche.
local breakHits = {}
for i = hitsBefore + 1, #FAKE_REMOTES.WindowHit.sent do
	table.insert(breakHits, FAKE_REMOTES.WindowHit.sent[i])
end
check(#breakHits == 2 and breakHits[1].args[4] == 1000 and breakHits[2].args[4] == 1000, "WindowHit aussi pour le coup qui casse, avec ses dégâts (a34, DEV-053)")
check(windowA.Transparency == 1 and windowA.CanCollide == false, "serveur : vitre intacte cachée")
local impact = FAKE_REMOTES.WindowBroken.sent[brokenBefore + 1].args[2]
step(0.05)
check(stars("STORE_Z1_Superette") == nil, "étoiles retirées à la casse")
local shards = shardsInFx()
check(#shards == 35, `variante WIN_M_Fractured_Left (35 éclats), la plus proche du coup (lu : {#shards})`)
local shard01
for _, s in shards do
	if s.Name == "Shard_01" then
		shard01 = s
	end
end
-- coup à x = −3 du centre ; _Left retournée a son impact à x = −3,86, y = −0,42
check(shard01 and (shard01.Position - (windowA.Position + Vector3.new(-3.86, -0.42, 0))).Magnitude < 1e-6, `retournée : impact du côté du coup ({shard01 and shard01.Position})`)
local allGood = true
for _, s in shards do
	if s.Anchored ~= true or s.CanCollide ~= false or s.CanQuery ~= false or s.CanTouch ~= false or not near(s.Transparency, 0.55) then
		allGood = false
	end
end
check(allGood, "éclats ancrés, sans collision, transparence de Clément (0,55)")
local flash = camera:FindFirstChild("ShatterFlash")
check(flash ~= nil and flash.Enabled == true, "flash : ColorCorrection active sur la caméra")
check(walkTrack.Speed == 0, "arrêt sur image : animations du joueur figées")
local text = playerGui:FindFirstChild("ShatterText_V0")
check(text ~= nil and text.Label.Visible == true and text.Label.Text == "SMASHED!", "« SMASHED! » affiché (texte V0)")
check(soundCount("Glass_BreakThud", tb) == 1 and soundCount("Glass_BreakShatter", tb) == 1, "couches 1 et 2 du son à la casse")
local thud, shatter = lastSound("Glass_BreakThud"), lastSound("Glass_BreakShatter")
check(thud.speed >= 0.9 - 1e-9 and thud.speed <= 1.1 + 1e-9 and shatter.speed >= 0.9 - 1e-9 and shatter.speed <= 1.1 + 1e-9, "hauteur ± 10 %")
check(Workspace.Terrain:FindFirstChild("ShatterLight") ~= nil, "éclair au point d'impact")
-- arrêt sur image : les éclats n'ont pas bougé
local moved = false
for _, s in shards do
	if s.Name == "Shard_01" and (s.Position - (windowA.Position + Vector3.new(-3.86, -0.42, 0))).Magnitude > 1e-6 then
		moved = true
	end
end
check(not moved, "pendant l'arrêt sur image, les éclats restent en place")
step(0.1)
check(walkTrack.Speed == 1, "après 60 ms : animations reprises")
check(near(flash.Brightness, 0) and flash.Enabled == false, "flash éteint après 80 ms")
check(#named("GlassCube") >= 18, "petits cubes de verre de la casse")
local breakEmits = emits(tb)
local sparkles, dust = 0, 0
for _, e in breakEmits do
	if e.texture == "rbxassetid://9" then
		sparkles += e.count
	elseif e.texture == "rbxasset://textures/particles/smoke_main.dds" then
		dust += e.count
	end
end
check(sparkles >= 30 and dust == 10, `paillettes ({sparkles}) et poussière ({dust}, texture de secours)`)
step(0.5)
check(soundCount("Glass_BreakDebris", tb) == 1, "couche 3 : cliquetis quand les morceaux retombent")
check(text.Label.Visible == true, "« SMASHED! » encore là")
step(0.6)
check(text.Label.Visible == false, "« SMASHED! » reparti")
local inside, floor, flat, total = 0, 0, 0, 0
for _, s in shards do
	total += 1
	if s.Position.Z > 20.3 then
		inside += 1
	end
	if s.Position.Y >= -0.01 then
		floor += 1
	end
	if s.Position.Y < 0.6 and math.abs(s.CFrame.ZVector.Y) > 0.99 then
		flat += 1
	end
end
check(inside >= total * 0.9, `éclats poussés vers l'intérieur du magasin ({inside}/{total})`)
check(floor == total, "aucun éclat sous le sol")
check(flat >= total * 0.8, `éclats couchés à plat au sol ({flat}/{total})`)
local farthest = 0
for _, s in shards do
	farthest = math.max(farthest, s.Position.Z)
end
check(farthest < 44, `aucun éclat à travers le mur du fond (z max {string.format("%.1f", farthest)})`)
check(barA.Enabled == false, "barre de PV cachée, vitre cassée")
check(near(WC.GetFraction("STORE_Z1_Superette"), 0), "GetFraction : 0 cassée")
step(0.45)
local fading = shards[1]
check(fading.Transparency > 0.55 and fading.Transparency < 1, `effacement commencé après 1,5 s (transparence {string.format("%.2f", fading.Transparency)})`)
step(1.2)
check(#shardsInFx() == 0 and #named("GlassCube") == 0, "tous les éclats retirés après 1,5 + 1,2 s")
injectHit("STORE_Z1_Superette", impact, OTHER)
step(0.05)
check(stars("STORE_Z1_Superette") == nil, "un WindowHit en retard sur une vitre cassée est ignoré")

print("\n== Reconstruction (serveur, 30 s après la casse)")
step(27.5)
check(windowA:GetAttribute("Broken") == false and windowA.Transparency == 0.55 and windowA.CanCollide == true, "serveur : vitre reconstruite")
step(0.3)
check(barA.Enabled == true and barA.Label.Text == "35 / 35", "barre revenue, PV pleins")
check(near(WC.GetFraction("STORE_Z1_Superette"), 1), "GetFraction : 1 après reconstruction")
DAMAGE[LOCAL] = 5
tool.Activated:Fire()
step(0.2)
_, front = stars("STORE_Z1_Superette")
check(#front == 1, "nouvelle étoile après la reconstruction")

---------------------------------------------------------------- casse d'un autre, reconstruction en cours de route
print("\n== Casse par un autre joueur, puis reconstruction avant la fin des éclats")
step(3.5) -- le joueur local n'a plus frappé depuis plus de 3 s : il ne participe pas
DAMAGE[OTHER] = 1000
clearLog()
camera.CFrame = CFrame.new(0, 6, -10) -- à 30 studs du point d'impact
local tc = now()
serverHit(OTHER, "STORE_Z1_Superette")
step(0.1)
shards = shardsInFx()
-- coup du point le plus proche d'OTHER : x = +4 → _Left (impact à +3,86) sans la retourner
check(#shards == 35, `variante _Left posée telle quelle pour un coup à droite vu de la rue (lu : {#shards})`)
for _, s in shards do
	if s.Name == "Shard_01" then
		check((s.Position - (windowA.Position + Vector3.new(3.86, -0.42, 0))).Magnitude < 0.05 + 1e-6, "impact de la variante au plus près du coup")
	end
end
check(playerGui.ShatterText_V0.Label.Visible == false, "pas de « SMASHED! » pour un joueur qui n'a pas frappé")
check(soundCount("Glass_BreakThud", tc) == 1, "les autres entendent quand même la casse")
local flashB = camera:FindFirstChild("ShatterFlash")
check(flashB.Enabled == false or flashB.Brightness < 0.45 * 0.7, "flash atténué à 30 studs")
camera.CFrame = CFrame.new(-3, 6, 10)
-- Copie a34 (DEV-053) : 0,6 s au lieu de 0,4. Le coup qui casse arrive aussi par WindowHit : ses
-- mini-éclats de coup (0,6 s de vie, pas liés à la casse) sont partis ; les éclats et les cubes de la
-- casse volent encore, et c'est eux que la reconstruction doit retirer.
step(0.6)
WS.Rebuild("STORE_Z1_Superette")
step(0.02)
check(#shardsInFx() == 0, "reconstruction : aucun éclat ne traîne")
check(#named("GlassCube") == 0, "reconstruction : aucun petit cube ne traîne")

---------------------------------------------------------------- vitre tournée, greybox, version légère
print("\n== Vitre tournée de 180° (Kiosque) et vitre S de la greybox")
local tk = now()
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z1_Kiosque", windowB.Position + Vector3.new(0, 0, 0.2))
step(1)
shards = shardsInFx()
check(#shards == 36, `impact au centre : WIN_M_Fractured (36 éclats) (lu : {#shards})`)
local inwardB = 0
for _, s in shards do
	if s.Position.Z < -20.3 then
		inwardB += 1
	end
end
check(inwardB >= #shards * 0.9, `éclats poussés vers l'intérieur du Kiosque, côté −Z ({inwardB}/{#shards})`)
step(2)
check(#shardsInFx() == 0, "éclats du Kiosque retirés")
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z2_Jouets", windowC.Position + Vector3.new(2, 1, -0.2))
step(0.1)
shards = shardsInFx()
check(#shards == 40, `vitre S : pas de variante M, ses 40 éclats à elle (lu : {#shards})`)
check(shards[1] and near(shards[1].Transparency, 0.5), "éclats de la greybox (invisibles) rendus visibles à 0,5")
step(3)
check(#shardsInFx() == 0, "éclats de la greybox retirés")

-- Copie a26 (vague 8) : HitController n'envoie plus HitWindow au clic mais au marqueur Impact de
-- l'animation. Le coup qui casse arrive donc au serveur après l'impact : la casse se joue dès
-- WindowBroken, une latence aller-retour après l'impact (le retour local du coup est déjà passé).
-- Le cas « WindowBroken avant le marqueur » ne vient plus que d'un autre joueur (section suivante).
print("\n== Casse par le joueur local avec animation : le coup part au marqueur Impact (a26)")
step(3.5)
ANIM.NoTrack = false
DAMAGE[LOCAL] = 5
-- Échos WindowHit reçus par le joueur local (le serveur en envoie aussi aux joueurs proches).
local function echoesToLocal()
	local n = 0
	for _, e in FAKE_REMOTES.WindowHit.sent do
		if e.to == LOCAL then
			n += 1
		end
	end
	return n
end
local echoesBefore = echoesToLocal()
tool.Activated:Fire()
step(0.15)
check(echoesToLocal() == echoesBefore, "avant le marqueur : le coup n'est pas encore parti (aucun écho)")
ANIM.Last:FireMarker("Impact")
step(2 * LATENCY + 0.02)
local _, starsBeforeBreak = stars("STORE_Z1_Superette")
check(echoesToLocal() == echoesBefore + 1 and #starsBeforeBreak >= 1, `au marqueur : un seul coup part, une étoile à son écho ({echoesToLocal() - echoesBefore} écho(s))`)
DAMAGE[LOCAL] = 1000
local tw = now()
tool.Activated:Fire()
step(0.15)
check(windowA.Transparency ~= 1 and not WS.IsBroken("STORE_Z1_Superette"), "le coup qui casse attend son marqueur : vitre encore intacte")
check(#shardsInFx() == 0 and soundCount("Glass_BreakThud", tw) == 0 and playerGui.ShatterText_V0.Label.Visible == false, "ni éclats, ni son de casse, ni texte avant l'impact")
local _, starsWaiting = stars("STORE_Z1_Superette")
check(#starsWaiting >= 1, "les étoiles restent jusqu'à la casse")
ANIM.Last:FireMarker("Impact")
step(0.01)
check(soundCount("Glass_Hit", tw) == 1, "marqueur Impact : retour local du coup (son de verre)")
step(LATENCY)
check(windowA.Transparency == 1 and WS.IsBroken("STORE_Z1_Superette"), "serveur : vitre cassée une latence après l'impact")
step(LATENCY + 0.01)
local frozen = shardsInFx()
check(#frozen == 35, `WindowBroken reçu : éclats de la variante la plus proche du coup (lu : {#frozen})`)
check(soundCount("Glass_BreakThud", tw) == 1 and camera.ShatterFlash.Enabled == true, "casse jouée dès WindowBroken (le retour local est déjà passé) : son, flash")
check(playerGui.ShatterText_V0.Label.Visible == true, "« SMASHED! » à la casse")
check(stars("STORE_Z1_Superette") == nil, "étoiles retirées à la casse")
local firstPositions = {}
for _, s in frozen do
	firstPositions[s] = s.Position
end
step(0.3)
local movedCount = 0
for _, s in frozen do
	if s.Parent and (s.Position - firstPositions[s]).Magnitude > 0.5 then
		movedCount += 1
	end
end
check(movedCount >= #frozen * 0.9, `éclats partis après l'arrêt sur image ({movedCount}/{#frozen})`)
step(3)
check(#shardsInFx() == 0, "éclats retirés")
WS.Rebuild("STORE_Z1_Superette")
step(0.2)

print("\n== Casse par un autre joueur pendant le coup du joueur local : WindowBroken avant son marqueur Impact")
DAMAGE[LOCAL] = 5
DAMAGE[OTHER] = 1000
local brokenSent = #FAKE_REMOTES.WindowBroken.sent
local tw2 = now()
tool.Activated:Fire() -- le joueur local frappe : son retour local et son coup attendent le marqueur
step(0.03)
serverHit(OTHER, "STORE_Z1_Superette")
step(LATENCY + 0.02)
check(WS.IsBroken("STORE_Z1_Superette") and #FAKE_REMOTES.WindowBroken.sent == brokenSent + 1, "l'autre joueur casse la vitre")
local frozen2 = shardsInFx()
check(#frozen2 == 35, `éclats posés tout de suite à la place du verre, pas de trou (lu : {#frozen2})`)
local firstPositions2 = {}
for _, s in frozen2 do
	firstPositions2[s] = s.Position
end
step(0.05)
local still = true
for _, s in frozen2 do
	if (s.Position - firstPositions2[s]).Magnitude > 1e-9 then
		still = false
	end
end
check(still, "immobiles en attendant l'impact du joueur local")
check(soundCount("Glass_BreakThud", tw2) == 0 and playerGui.ShatterText_V0.Label.Visible == false, "ni son de casse ni texte avant son impact")
ANIM.Last:FireMarker("Impact")
step(0.02)
check(soundCount("Glass_BreakThud", tw2) == 1 and camera.ShatterFlash.Enabled == true, "son marqueur Impact : casse, flash")
check(playerGui.ShatterText_V0.Label.Visible == true, "« SMASHED! » à son impact (il participait)")
step(LATENCY + 0.05)
check(#FAKE_REMOTES.WindowBroken.sent == brokenSent + 1, "son coup, parti au marqueur sur une vitre déjà cassée, ne recasse rien")
step(3)
check(#shardsInFx() == 0, "éclats retirés")
ANIM.NoTrack = true
DAMAGE[LOCAL] = 5
WS.Rebuild("STORE_Z1_Superette")
step(0.2)

print("\n== Vitre sans éclats (ni WindowFractured, ni variante à sa taille)")
local fracturedC = storeC.WindowFractured
fracturedC.Parent = nil
local tn = now()
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z2_Jouets", windowC.Position)
step(0.6)
check(#shardsInFx() == 0, "aucun éclat")
check(soundCount("Glass_BreakThud", tn) == 1 and soundCount("Glass_BreakDebris", tn) == 1, "les 3 couches du son quand même")
fracturedC.Parent = storeC
step(3)

print("\n== Version légère : qualité graphique basse, images lentes, casses simultanées")
QUALITY.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel2
check(SC.IsLowEnd() == true, "qualité réglée à 2 : appareil faible")
local tl = now()
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z1_Kiosque", windowB.Position + Vector3.new(-3, 1, 0.2))
step(0.1)
check(#shardsInFx() == 10, `10 éclats (lu : {#shardsInFx()})`)
check(#named("GlassCube") == 6, "6 petits cubes")
step(3)
QUALITY.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
check(SC.IsLowEnd() == false, "qualité automatique à 60 images/s : appareil normal")
step(2, 20)
check(SC.IsLowEnd() == true, "20 images/s : appareil faible")
step(3, 60)
check(SC.IsLowEnd() == false, "retour à 60 images/s")
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z1_Kiosque", windowB.Position + Vector3.new(0, 0, 0.2))
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z1_Superette", windowA.Position + Vector3.new(0, 0, -0.2))
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z2_Jouets", windowC.Position + Vector3.new(0, 0, -0.2))
step(0.02)
check(#shardsInFx() == 36 + 36 + 10, `2 casses complètes, la 3e en version légère (lu : {#shardsInFx()})`)
step(3)
check(#shardsInFx() == 0, "tout est retiré")

---------------------------------------------------------------- sons absents, mouvement réduit
print("\n== Sons absents et réglage « réduire les mouvements »")
sounds.Parent = nil
GuiServiceStub.ReducedMotionEnabled = true
local ts = #SOUND_LOG
FAKE_REMOTES.WindowBroken.clientSignal:Fire("STORE_Z1_Kiosque", windowB.Position)
injectHit("STORE_Z2_Jouets", windowC.Position, OTHER)
step(1)
check(#SOUND_LOG == ts, "sons absents : rien n'est joué…")
step(3)

---------------------------------------------------------------- bilan
print("\n== Avertissements de la sortie")
local warns = warnings()
for _, line in warns do
	print("    " .. line)
end
check(#warns == 0, "aucun avertissement (aucune erreur attrapée dans les effets)")
print(string.format("rayons lancés : %d, déplacements groupés : %d", RAYCASTS, BULK_MOVES))
summary()
