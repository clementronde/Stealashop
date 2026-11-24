---------------------------------------------------------------- scénarios (agent a44, L-081)
print("== Banc a44 : la vitre se creuse à chaque coup (L-081)")

-- Faux Net (repris d'a16 et a34) : routage serveur ↔ client local avec LATENCY de retard ; chaque
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
			table.insert(r.serverHandlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, player, ...)
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
			return r.clientSignal:Connect(fn)
		end,
		Fire = function(_, ...)
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

---------------------------------------------------------------- monde (repris d'a16, sans les images WIN_Crack_*)
local GLASS = Color3.fromRGB(191, 230, 255)
new("Part", { Name = "Floor", Size = Vector3.new(400, 1, 400), CFrame = CFrame.new(0, -0.5, 0) }, Workspace)
local camera = new("Camera", { Name = "Camera", CFrame = CFrame.new(-3, 6, 10) }, Workspace)
Workspace.CurrentCamera = camera
new("Terrain", { Name = "Terrain" }, Workspace)

local assets = folder(ReplicatedStorage, "Assets")
local fxAssets = folder(assets, "FX")
new("Decal", { Name = "FX_GlassSparkle", Texture = "rbxassetid://9" }, fxAssets)
local sounds = folder(folder(assets, "Sounds"), "Glass")
for _, name in { "Glass_Hit", "Glass_BreakThud", "Glass_BreakShatter", "Glass_BreakDebris" } do
	new("Sound", { Name = name, PlaybackSpeed = 1 }, sounds)
end
local ui = folder(assets, "UI")
local bb = new("BillboardGui", { Name = "BB_WindowHP", Size = UDim2.new(6, 0, 1.6, 0), StudsOffset = Vector3.new(0, 4.5, 0), MaxDistance = 80 }, ui)
new("TextLabel", { Name = "Label", Text = "300 / 400" }, bb)
local bar = new("Frame", { Name = "Bar" }, bb)
new("Frame", { Name = "Fill", Size = UDim2.new(0.75, 0, 1, 0) }, bar)

local windows = folder(assets, "Windows")
local TEMPLATE_PIVOT = CFrame.new(100, 50, -70) * CFrame.Angles(0, math.rad(90), 0)
local function fracturedM(name, count, impact, pivot, transparency)
	local model = new("Model", { Name = name })
	model.WorldPivot = pivot
	new("MeshPart", { Name = "Shard_01", Size = Vector3.new(0.8, 0.8, 0.4), CFrame = pivot * CFrame.new(impact), Material = Enum.Material.Glass, Transparency = transparency, Color = GLASS }, model)
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

local map = folder(Workspace, "Map")
local function clementStore(name, pivot)
	local model = new("Model", { Name = name })
	model.WorldPivot = pivot
	new("MeshPart", { Name = "Window", Size = Vector3.new(12, 7, 0.4), CFrame = pivot * CFrame.new(0, 4, 0), Material = Enum.Material.Glass, Transparency = 0.55, Color = GLASS, Reflectance = 0.1 }, model)
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
local windowA, windowB, windowC = storeA.Window, storeB.Window, storeC.Window
local A, B, C = "STORE_Z1_Superette", "STORE_Z1_Kiosque", "STORE_Z2_Jouets"
-- Ce que Clément a posé : ne doit jamais changer (le code ne fait que cacher la vitre en local).
local function look(w)
	return { w.Transparency, w.Color, w.Material, w.Size, w.CFrame.Position, w.Reflectance, w.CanCollide }
end
local LOOK_A, LOOK_B, LOOK_C = look(windowA), look(windowB), look(windowC)

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
local otherRoot = OTHER.Character.HumanoidRootPart
local localAnimator = LOCAL.Character.Humanoid.Animator
rawset(localAnimator, "_tracks", { newTrack("Walk") })
local playerGui = LOCAL.PlayerGui

---------------------------------------------------------------- outils du banc
local function fxFolder()
	return Workspace:FindFirstChild("_ShatterFX")
end
local function fxNamed(name)
	local out = {}
	local f = fxFolder()
	for _, d in if f then f:GetChildren() else {} do
		if d.Name == name then
			table.insert(out, d)
		end
	end
	return out
end
local function carved(id)
	return fxNamed("CarvedGlass_" .. id)
end
local function chips()
	return fxNamed("GlassChip")
end
local function callsFor(id, since)
	local out = {}
	for _, call in GEOMETRY.Calls do
		if call.id == id and call.t >= (since or -1) then
			table.insert(out, call)
		end
	end
	return out
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
local function emitsSince(since)
	local out = {}
	for _, e in EMIT_LOG do
		if e.t >= since then
			table.insert(out, e)
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
local hitHandlers = FAKE_REMOTES.HitWindow.serverHandlers
local function serverHit(player, windowId)
	for _, handler in hitHandlers do
		taskLib.spawn(handler, player, windowId)
	end
end
local function injectHit(windowId, point, hitter, damage)
	FAKE_REMOTES.WindowHit.clientSignal:Fire(windowId, point, hitter, damage or 1)
end
local function place(root, position)
	root.CFrame = CFrame.new(position) * CFrame.Angles(0, math.pi, 0)
end
-- Analyse d'un appel à FragmentAsync dans le repère de la vitre `window` (épaisseur t) : côté des
-- éclats, centre approché, plus grande profondeur de la limite entre un éclat et son plancher.
local function analyze(call, window)
	local cf, t = window.CFrame, window.Size.Z
	local res = { chips = #call.sites - 1, ring = 0, side = nil, sameSide = true, paired = true, maxBoundary = 0, cx = 0, cy = 0, maxChipDepth = 0 }
	local floors = {}
	for _, q in call.sites[1] do
		table.insert(floors, cf:PointToObjectSpace(q))
	end
	for i = 2, #call.sites do
		local p = cf:PointToObjectSpace(call.sites[i])
		local side = if p.Z >= 0 then 1 else -1
		res.side = res.side or side
		if side ~= res.side then
			res.sameSide = false
		end
		res.cx += p.X / res.chips
		res.cy += p.Y / res.chips
		local best, bestD = nil, math.huge
		for _, q in floors do
			local dxy = math.sqrt((q.X - p.X) ^ 2 + (q.Y - p.Y) ^ 2)
			if dxy < bestD then
				best, bestD = q, dxy
			end
		end
		if bestD > 0.1 then
			res.paired = false
		end
		local face = res.side * t / 2
		local dChip = math.abs(face - p.Z)
		res.maxChipDepth = math.max(res.maxChipDepth, dChip)
		if best then
			res.maxBoundary = math.max(res.maxBoundary, (dChip + math.abs(face - best.Z)) / 2)
		end
	end
	-- anneau : points du groupe 1 au niveau du bord du creux (ni planchers, ni coins lointains)
	for _, q in floors do
		if math.abs(q.Z) < t / 2 and math.abs(q.X) < window.Size.X and math.abs(q.Y) < window.Size.Y then
			local isFloor = false
			for i = 2, #call.sites do
				local p = cf:PointToObjectSpace(call.sites[i])
				if math.sqrt((q.X - p.X) ^ 2 + (q.Y - p.Y) ^ 2) < 0.06 then
					isFloor = true
				end
			end
			if not isFloor then
				res.ring += 1
			end
		end
	end
	return res
end
local function attr(piece, name)
	return if piece then piece:GetAttribute(name) else nil
end

---------------------------------------------------------------- démarrage
print("\n== Démarrage : WindowService (serveur), WindowController, ShatterController, HitController (client)")
local WS = requireModule(MODULES["server/Services/WindowService.luau"], "server")
WS.Init()
taskLib.spawn(WS.Start)
local WC = requireModule(MODULES["client/Controllers/WindowController.luau"], "client")
local SC = requireModule(MODULES["client/Controllers/ShatterController.luau"], "client")
local HC = requireModule(MODULES["client/Controllers/HitController.luau"], "client")
requireModule(MODULES["client/Controllers/AnimationController.luau"], "client")
local Shatter = requireModule(MODULES["shared/Config/Shatter.luau"], "client")
local Carve = Shatter.Carve
WC.Init()
taskLib.spawn(WC.Start)
taskLib.spawn(SC.Start)
taskLib.spawn(HC.Start)
step(0.5)
check(windowA:GetAttribute("MaxHP") == 27 and windowC:GetAttribute("MaxHP") == 272, "serveur : vitres A (27 PV) et C (272 PV) enregistrées (a134)")
check(logHas("assets de la casse : tous présents", "PRINT", "client"), "Studio : assets tous présents, sans aucune image WIN_Crack_* dans Assets/FX")
check(Shatter.Cracks == nil and Shatter.Assets.CrackDecals == nil, "Config/Shatter : plus de réglages d'étoiles (Cracks, CrackDecals)")
check(Carve.R0 == 0.6 and Carve.RMax == 2.6 and Carve.DepthMax == 0.88 and Carve.MaxDebris == 150 and Carve.Light.MaxDebris == 40, "réglages du creux : valeurs du prototype de Clément, version mobile V0")

---------------------------------------------------------------- A. coup d'un autre joueur
print("\n== A. Coup d'un autre joueur : la vitre se creuse à l'écho WindowHit")
local t0 = now()
serverHit(OTHER, A)
step(LATENCY + 0.005)
local callsA = callsFor(A, t0)
check(#callsA == 1, `écho reçu : un calcul FragmentAsync (lu : {#callsA})`)
check(windowA.LocalTransparencyModifier == 1, "la vraie vitre est cachée en local (LocalTransparencyModifier)")
check(windowA.Transparency == 0.55, "… sans toucher à sa Transparency (visuel de Clément)")
local proxy = carved(A)[1]
check(proxy ~= nil and callsA[1] and callsA[1].part == proxy, "le calcul part d'une simple Part locale, CarvedGlass_<Id>, pas du MeshPart de Clément")
if proxy then
	check(proxy.ClassName == "Part" and proxy.Size == windowA.Size and (proxy.Position - windowA.Position).Magnitude < 1e-9, "Part à la taille et à la place de la vitre")
	check(proxy.Material == Enum.Material.Glass and proxy.Color == GLASS and proxy.Transparency == 0.55 and proxy.Reflectance == 0.1, "même verre : matériau, couleur, transparence, reflet")
	check(proxy.Anchored and not proxy.CanCollide and not proxy.CanQuery and not proxy.CanTouch and not proxy.CastShadow, "ancrée, sans collision, sans requête, sans ombre")
	check(proxy.Parent == fxFolder(), "rangée dans le dossier local _ShatterFX")
end
check(callsA[1] and callsA[1].options and callsA[1].options.CollisionFidelity == Enum.CollisionFidelity.Box, "FragmentAsync avec CollisionFidelity = Box (prototype)")
local an = analyze(callsA[1], windowA)
check(an.side == -1 and an.sameSide, "éclats arrachés dans la face frappée (côté rue, celui du frappeur)")
check(an.paired, "chaque éclat a son plancher juste derrière lui")
check(an.maxBoundary < windowA.Size.Z * Carve.DepthCap + 1e-6, `fond du creux à {string.format("%.3f", an.maxBoundary)} stud au plus (épaisseur 0,4) : la vitre n'est pas percée`)
check(an.chips >= Carve.MinSites and an.chips <= Carve.MaxSites, `éclats par coup entre MinSites et MaxSites (lu : {an.chips})`)
check(math.abs(an.cx - 4) < 0.6 and math.abs(an.cy - (3 - 4)) < 0.6, `creux centré sur le point de frappe du serveur (x {string.format("%.2f", an.cx)}, y {string.format("%.2f", an.cy)})`)
check(an.ring >= Carve.RingMin and an.ring <= Carve.RingMax, `anneau de {an.ring} points autour du creux`)
check(#chips() == 0, "pendant le calcul (asynchrone), aucun éclat encore")
step(GEOMETRY.Delay + 0.01)
local chipsA = chips()
check(#chipsA == an.chips, `calcul fini : {an.chips} éclats arrachés (lu : {#chipsA})`)
check(#carved(A) == 1 and carved(A)[1] ~= proxy and proxy.Parent == nil, "le verre qui reste remplace la Part de départ, détruite")
local keptA = carved(A)[1]
check(keptA and keptA.Transparency == 0.55 and keptA.Anchored and not keptA.CanCollide and not keptA.CanQuery, "verre creusé : même verre, sans collision")
check(attr(keptA, "CarveHits") == 1 and attr(keptA, "CarveRadius") >= 0.6 - 1e-9 and attr(keptA, "CarveDepth") >= 0.22 - 1e-9, `attributs Studio : 1 coup, rayon {attr(keptA, "CarveRadius")}, profondeur {attr(keptA, "CarveDepth")}`)
check(fxFolder():GetAttribute("CarveCount") == 1 and type(fxFolder():GetAttribute("CarveLastMs")) == "number", "mesure du calcul sur _ShatterFX (CarveCount, CarveLastMs)")
local chipOk = #chipsA > 0
for _, c in chipsA do
	if not (c.Anchored and not c.CanCollide and not c.CanQuery and not c.CanTouch and c.Material == Enum.Material.Glass) then
		chipOk = false
	end
end
check(chipOk, "éclats ancrés, sans collision (ils ignorent les joueurs), en verre")
check(#fxNamed("GlassCube") == 5, "mini-éclats du coup toujours là (5)")
check(soundCount("Glass_Hit", t0) == 1, "son Glass_Hit au coup")
local sparkle, puff = 0, 0
for _, e in emitsSince(t0) do
	if e.texture == "rbxassetid://9" then
		sparkle += e.count
	elseif e.texture == "rbxasset://textures/particles/smoke_main.dds" then
		puff += e.count
	end
end
check(sparkle == 24 and puff == 5, `paillettes (24) et petit nuage (5) du prototype (lus : {sparkle}, {puff})`)
check(Workspace.Terrain:FindFirstChild("HitLight") ~= nil, "éclair au point de frappe")
local below, outward, samples = false, 0, 0
for _ = 1, 18 do
	step(1 / 60)
	for _, c in chips() do
		if c.Position.Y < -0.01 then
			below = true
		end
	end
end
for _, c in chips() do
	samples += 1
	if c.Position.Z < 19.75 then
		outward += 1
	end
end
check(samples > 0 and outward >= samples * 0.9, `éclats partis vers celui qui frappe, côté rue ({outward}/{samples})`)
step(1.8)
for _, c in chipsA do
	if c.Position.Y < -0.01 then
		below = true
	end
end
check(not below, "aucun éclat sous le sol")
check(#chips() == 0, "éclats retirés après Life + Fade (1,4 + 0,5 s)")
check(#carved(A) == 1, "le creux, lui, reste (PV pas encore pleins)")

---------------------------------------------------------------- B. croissance et régénération
print("\n== B. Le creux grandit à chaque coup ; la régénération ne le rétrécit pas ; PV pleins : vitre neuve")
local r1, d1 = attr(carved(A)[1], "CarveRadius"), attr(carved(A)[1], "CarveDepth")
local tb = now()
serverHit(OTHER, A)
step(LATENCY + GEOMETRY.Delay + 0.02)
local k2 = carved(A)[1]
local r2, d2 = attr(k2, "CarveRadius"), attr(k2, "CarveDepth")
check(#callsFor(A, tb) == 1 and attr(k2, "CarveHits") == 2, "2e coup : 2e calcul sur le verre déjà creusé")
check(callsFor(A, tb)[1].part == keptA, "il part du morceau qui reste (le creux s'empile)")
check(r2 >= r1 + Carve.PerHit - 1e-6 and d2 >= d1 + Carve.DepthPerHit - 1e-6, `plus large et plus profond (rayon {r1} → {r2}, profondeur {d1} → {d2})`)
check(r2 <= Carve.RMax and d2 <= Carve.DepthMax, "sans dépasser RMax ni DepthMax")
local lost = 1 - WC.GetFraction(A)
check(lost > 0.1, `PV perdus côté client : {string.format("%.0f", lost * 100)} %`)
step(2.5)
local fracMid = WC.GetFraction(A)
check(fracMid < 0.999 and fracMid > 1 - lost, `régénération en cours ({string.format("%.0f", fracMid * 100)} %)`)
check(#carved(A) == 1 and attr(carved(A)[1], "CarveRadius") == r2, "le creux ne rétrécit pas quand les PV remontent")
local tweensBefore = #TWEENS
local healedAt = nil
for _ = 1, 120 do
	step(0.1)
	if #carved(A) == 0 or windowA.LocalTransparencyModifier == 0 then
		healedAt = now()
		break
	end
end
local fadeTween = false
for i = tweensBefore + 1, #TWEENS do
	if TWEENS[i].Instance == k2 and TWEENS[i].Goals.Transparency == 1 then
		fadeTween = true
	end
end
check(healedAt ~= nil and WC.GetFraction(A) >= 0.999, "PV pleins : la vitre redevient pleine")
check(windowA.LocalTransparencyModifier == 0, "la vraie vitre est remontrée")
check(fadeTween, "le verre creusé s'efface en fondu (HealFade)")
step(Carve.HealFade + 0.2)
check(#carved(A) == 0 and k2.Parent == nil, "verre creusé retiré après le fondu")

---------------------------------------------------------------- C. coup du joueur local, sans animation
print("\n== C. Coup du joueur local : creusé tout de suite, l'écho est ignoré")
local tool = new("Tool", { Name = "Poings" })
tool:SetAttribute("ToolId", "Fists")
tool.Parent = LOCAL.Character
step(0.05)
local tc = now()
tool.Activated:Fire()
local localCalls = callsFor(A, tc)
check(#localCalls == 1, "sans animation : creux au clic, sans attendre le serveur")
local al = analyze(localCalls[1], windowA)
check(math.abs(al.cx + 3) < 0.6 and math.abs(al.cy + 1) < 0.6 and al.side == -1, `au point visé par HitController (x {string.format("%.2f", al.cx)}, y {string.format("%.2f", al.cy)}), face rue`)
step(2 * LATENCY + 0.05)
local echo = nil
for _, e in FAKE_REMOTES.WindowHit.sent do
	if e.to == LOCAL and e.t >= tc and e.args[3] == LOCAL then
		echo = e
	end
end
check(echo ~= nil, "le serveur a validé et renvoyé l'écho (frappeur = joueur local)")
check(#callsFor(A, tc) == 1, "son écho ne creuse pas une 2e fois")
check(soundCount("Glass_Hit", tc) == 1, "son Glass_Hit une seule fois")
step(0.3)

print("\n== D. Coup local avec animation : creux au marqueur Impact")
ANIM.NoTrack = false
local td = now()
tool.Activated:Fire()
step(0.1)
check(#callsFor(A, td) == 0, "avant le marqueur : pas de creux")
ANIM.Last:FireMarker("Impact")
check(#callsFor(A, td) == 1, "marqueur Impact : le creux part aussitôt")
step(2 * LATENCY + 0.1)
check(#callsFor(A, td) == 1, "l'écho de ce coup est ignoré")
local te = now()
tool.Activated:Fire()
step(0.2)
check(#callsFor(A, te) == 0, "marqueur jamais atteint : on attend…")
step(0.15)
check(#callsFor(A, te) == 1, "… au plus 0,3 s (ImpactMaxWait)")
step(2 * LATENCY + 0.1)
check(#callsFor(A, te) == 1, "son écho est ignoré lui aussi")
-- Écho arrivé avant l'impact (injecté ; le serveur, lui, refuse ce coup : dégâts nuls) : le creux
-- se fait une seule fois, à l'impact, et ne laisse rien qui ferait ignorer un écho suivant.
DAMAGE[LOCAL] = 0
local tf = now()
tool.Activated:Fire()
step(0.05)
injectHit(A, windowA.Position + Vector3.new(-3, -1, -0.2), LOCAL)
step(0.01)
check(#callsFor(A, tf) == 0, "écho reçu avant l'impact : il attend le marqueur")
ANIM.Last:FireMarker("Impact")
step(2 * LATENCY + 0.1)
check(#callsFor(A, tf) == 1, "un seul creux, au marqueur")
local tf2 = now()
injectHit(A, windowA.Position + Vector3.new(3, 1, -0.2), LOCAL)
step(0.01)
check(#callsFor(A, tf2) == 1, "l'écho suivant, sans retour local, creuse bien (rien d'oublié en attente)")
DAMAGE[LOCAL] = nil
ANIM.NoTrack = true
-- Écho de son propre coup sans retour local (LocalHit jamais appelé) : le creux suit l'écho.
step(1.6)
local tg = now()
injectHit(A, windowA.Position + Vector3.new(2, 2, -0.2), LOCAL)
step(0.01)
check(#callsFor(A, tg) == 1, "écho de son coup sans retour local : creusé à l'écho")
step(1)

---------------------------------------------------------------- F. un seul calcul à la fois
print("\n== F. Un seul calcul à la fois par vitre ; les coups suivants attendent")
GEOMETRY.Delay = 0.2
local tq = now()
for i = 1, 7 do
	injectHit(B, windowB.Position + Vector3.new(i * 0.3 - 1, 0, 0.2), OTHER)
	step(0.005)
end
check(#callsFor(B, tq) == 1, "7 coups en 35 ms : un seul calcul en cours")
step(2)
check(GEOMETRY.MaxActive[B] == 1, "jamais deux calculs en même temps sur la même vitre")
check(#callsFor(B, tq) == 1 + Carve.MaxQueued, `puis les coups en attente, MaxQueued ({Carve.MaxQueued}) au plus : {#callsFor(B, tq)} calculs`)
local kB = carved(B)[1]
check(attr(kB, "CarveHits") == 1 + Carve.MaxQueued, "chaque calcul s'applique sur le précédent")
check(math.abs((attr(kB, "CarveRadius") or 0) - (Carve.R0 + 6 * Carve.PerHit)) < 1e-6, `coups fusionnés comptés quand même : rayon {attr(kB, "CarveRadius")} (0,6 + 6 × 0,1)`)
local ordered = true
local qc = callsFor(B, tq)
for i = 2, #qc do
	if qc[i].t < qc[i - 1].done - 1e-9 then
		ordered = false
	end
end
check(ordered, "chaque calcul commence après la fin du précédent")
check(callsFor(B, tq)[1].id == B and callsFor(A, tq)[1] == nil, "les autres vitres ne sont pas touchées")
GEOMETRY.Delay = 0.03
-- Vitre B pleine côté serveur (coups injectés) : sans nouvelle de WindowHP, elle redevient neuve
-- FullHealDelay après le dernier coup (cas d'un coup refusé par le serveur).
step(0.15)
check(windowB.LocalTransparencyModifier == 0, "PV restés pleins : vitre B neuve 2 s après le dernier coup, sans WindowHP")
step(0.6)
check(#carved(B) == 0, "son verre creusé est parti après le fondu")

---------------------------------------------------------------- G. plafond de débris (PC)
print("\n== G. Plafond de débris : 150 éclats au plus (PC)")
step(1)
local maxChips, maxSites = 0, 0
for i = 1, 40 do
	injectHit(C, windowC.Position + Vector3.new((i % 3) * 0.2 - 0.2, (i % 2) * 0.2, -0.2), OTHER)
	for _ = 1, 6 do
		step(1 / 60)
		maxChips = math.max(maxChips, #chips())
	end
end
for _, call in callsFor(C) do
	maxSites = math.max(maxSites, #call.sites - 1)
end
check(maxChips <= Carve.MaxDebris and maxChips >= Carve.MaxDebris - 5, `plafond atteint sans être dépassé (max {maxChips})`)
check(maxSites == Carve.MaxSites, `au plus fort, {maxSites} éclats par coup (MaxSites)`)
check(attr(carved(C)[1], "CarveRadius") == Carve.RMax, "rayon plafonné à RMax")
check(attr(carved(C)[1], "CarveDepth") == Carve.DepthMax, "profondeur plafonnée à DepthMax")
local pierced = false
for _, call in callsFor(C) do
	if analyze(call, windowC).maxBoundary >= windowC.Size.Z then
		pierced = true
	end
end
check(not pierced, "aucun coup ne perce la vitre, même au plus profond")
step(2.5)
check(#chips() == 0, "tous les éclats retirés")

print("\n== H. Version mobile : moins d'éclats, 40 au plus")
UIS_STUB.TouchEnabled = true
UIS_STUB.KeyboardEnabled = false
local th = now()
maxChips = 0
for i = 1, 40 do
	injectHit(C, windowC.Position + Vector3.new((i % 3) * 0.2 - 0.2, 0, -0.2), OTHER)
	for _ = 1, 6 do
		step(1 / 60)
		maxChips = math.max(maxChips, #chips())
	end
end
local lightSites, lightRing = 0, 0
for _, call in callsFor(C, th) do
	local a = analyze(call, windowC)
	lightSites = math.max(lightSites, a.chips)
	lightRing = math.max(lightRing, a.ring)
end
check(lightSites == Carve.Light.MaxSites, `tactile sans clavier : {lightSites} éclats par coup au plus (Light.MaxSites)`)
check(lightRing <= Carve.Light.RingMax, `anneau de {lightRing} points au plus (Light.RingMax)`)
check(maxChips <= Carve.Light.MaxDebris and maxChips >= Carve.Light.MaxDebris - 5, `plafond mobile atteint sans être dépassé (max {maxChips})`)
UIS_STUB.TouchEnabled = false
UIS_STUB.KeyboardEnabled = true
step(3)
check(#carved(C) == 0, "vitre C redevenue neuve (PV pleins, plus de coup)")
-- Petit creux neuf : PC = MinSites (8) éclats, mobile = Light.MinSites (5).
local tl = now()
injectHit(C, windowC.Position + Vector3.new(0, 0, -0.2), OTHER)
step(0.01)
check(callsFor(C, tl)[1] and #callsFor(C, tl)[1].sites - 1 == Carve.MinSites, "clavier revenu : version PC (8 éclats au premier coup)")
step(0.1)
QUALITY.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel2
local tq2 = now()
injectHit(C, windowC.Position + Vector3.new(0, 0, -0.2), OTHER)
step(0.01)
check(callsFor(C, tq2)[1] and #callsFor(C, tq2)[1].sites - 1 == Carve.Light.MinSites, "appareil faible (qualité 2) : version mobile aussi (5 éclats)")
QUALITY.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
step(2.5)

---------------------------------------------------------------- I. casse
print("\n== I. Casse : le verre creusé disparaît, la casse finale ne change pas")
DAMAGE[LOCAL] = 5
local ti = now()
tool.Activated:Fire()
step(0.1)
check(#carved(A) == 1 and windowA.LocalTransparencyModifier == 1, "vitre A creusée")
step(2.2) -- ses éclats sont retombés et partis
GEOMETRY.Delay = 0.3
DAMAGE[LOCAL] = 1000
local tbk = now()
tool.Activated:Fire() -- creux du coup local lancé (calcul de 0,3 s), le serveur casse la vitre
step(0.01)
check(#callsFor(A, tbk) == 1, "le coup qui casse se creuse lui aussi à l'impact (calcul en cours)")
step(2 * LATENCY + 0.01)
check(WS.IsBroken(A) and windowA.Transparency == 1, "serveur : vitre cassée et cachée")
check(#carved(A) == 0, "WindowBroken : le verre creusé disparaît tout de suite")
check(windowA.LocalTransparencyModifier == 0, "la vraie vitre retrouve son réglage (cachée par le serveur)")
local shards = 0
for _, d in fxFolder():GetChildren() do
	if string.match(d.Name, "^Shard_%d+$") then
		shards += 1
	end
end
check(shards == 35, `casse inchangée : éclats de la variante la plus proche du coup (lu : {shards})`)
check(soundCount("Glass_BreakThud", tbk) == 1 and soundCount("Glass_BreakShatter", tbk) == 1, "sons Glass_BreakThud et Glass_BreakShatter")
check(playerGui:FindFirstChild("ShatterText_V0") ~= nil and playerGui.ShatterText_V0.Label.Visible, "« SMASHED! »")
step(0.35)
check(#carved(A) == 0 and #chips() == 0, "le calcul fini après la casse est jeté : ni verre creusé ni éclats")
check(soundCount("Glass_BreakDebris", tbk) == 1, "son Glass_BreakDebris")
GEOMETRY.Delay = 0.03
local late = #callsFor(A)
injectHit(A, windowA.Position + Vector3.new(0, 0, -0.2), OTHER)
step(0.05)
check(#callsFor(A) == late and #carved(A) == 0, "WindowHit en retard sur la vitre cassée : pas de creux")
step(3)

---------------------------------------------------------------- J. reconstruction
print("\n== J. Reconstruction : vitre neuve, le creux repart de zéro")
DAMAGE[LOCAL] = 5
WS.Rebuild(A)
step(0.2)
check(windowA.Transparency == 0.55 and windowA.LocalTransparencyModifier == 0, "vitre reconstruite, visible")
local tj = now()
serverHit(OTHER, A)
step(LATENCY + GEOMETRY.Delay + 0.02)
local kj = carved(A)[1]
check(#callsFor(A, tj) == 1 and attr(kj, "CarveHits") == 1 and math.abs(attr(kj, "CarveRadius") - Carve.R0) < 0.3, "nouveau creux, petit, sur une nouvelle Part")
check(windowA.LocalTransparencyModifier == 1, "vitre cachée à nouveau pendant qu'elle est creusée")
-- Reconstruction vue du client seul (Broken true puis false) avec un creux en place.
windowA:SetAttribute("Broken", true)
step(0.02)
windowA:SetAttribute("Broken", false)
step(0.05)
check(#carved(A) == 0 and windowA.LocalTransparencyModifier == 0, "OnRebuilt : verre creusé retiré, vraie vitre remontrée")
step(2.5)

---------------------------------------------------------------- K. FragmentAsync en panne, morceau détaché
print("\n== K. FragmentAsync en panne : la vraie vitre reste, un seul avertissement")
GEOMETRY.Fail = true
local tk = now()
injectHit(B, windowB.Position + Vector3.new(1, 0, 0.2), OTHER)
step(GEOMETRY.Delay + 0.02)
check(#callsFor(B, tk) == 1 and #carved(B) == 0 and windowB.LocalTransparencyModifier == 0, "calcul raté au premier coup : vraie vitre remontrée, rien de creusé")
check(soundCount("Glass_Hit", tk) == 1, "le reste du retour de frappe joue quand même")
injectHit(B, windowB.Position + Vector3.new(1, 0, 0.2), OTHER)
step(GEOMETRY.Delay + 0.02)
local fragWarns = 0
for _, line in warnings() do
	if string.find(line, "FragmentAsync", 1, true) then
		fragWarns += 1
	end
end
check(fragWarns == 1, `un seul avertissement « FragmentAsync » (lu : {fragWarns})`)
GEOMETRY.Fail = false
step(2.5)
GEOMETRY.Island = true
local ti2 = now()
injectHit(B, windowB.Position + Vector3.new(-1, 1, 0.2), OTHER)
step(GEOMETRY.Delay + 0.02)
local ai = analyze(callsFor(B, ti2)[1], windowB)
check(#carved(B) == 1 and #chips() == ai.chips + 1, "un morceau détaché du cadre tombe avec les éclats ; le verre accroché reste")
GEOMETRY.Island = false
step(2.5)

---------------------------------------------------------------- L. sons absents
print("\n== L. Sons absents : rien ne joue, sans erreur")
sounds.Parent = nil
local ts = #SOUND_LOG
injectHit(C, windowC.Position + Vector3.new(0, 0, -0.2), OTHER)
step(0.2)
FAKE_REMOTES.WindowBroken.clientSignal:Fire(B, windowB.Position + Vector3.new(0, 0, 0.2))
step(1)
check(#SOUND_LOG == ts, "ni Glass_Hit ni sons de casse")
sounds.Parent = assets.Sounds
step(3)
windowB:SetAttribute("Broken", true)
step(0.02)
windowB:SetAttribute("Broken", false)
step(0.5)

---------------------------------------------------------------- M. sortie du streaming
print("\n== M. Vitre sortie du streaming : remise à neuf")
local tm = now()
injectHit(C, windowC.Position + Vector3.new(0, 0, -0.2), OTHER)
step(GEOMETRY.Delay + 0.02)
check(#carved(C) == 1 and windowC.LocalTransparencyModifier == 1, "vitre C creusée")
windowC.Parent = nil
step(0.05)
check(#carved(C) == 0 and windowC.LocalTransparencyModifier == 0, "OnRemoved : verre creusé retiré, réglage de la vitre rendu")
windowC.Parent = storeC
step(2.5)

---------------------------------------------------------------- bilan
print("\n== Plus aucune recherche de WIN_Crack_*, visuels de Clément intacts")
local crackLookups = 0
for name, count in FIND_LOG do
	if string.match(name, "^WIN_Crack") then
		crackLookups += count
	end
end
check(crackLookups == 0, `aucun FindFirstChild / WaitForChild de WIN_Crack_* (lu : {crackLookups})`)
local surfaceGuis = 0
for _, d in fxFolder():GetDescendants() do
	if d.ClassName == "SurfaceGui" or string.sub(d.Name, 1, 7) == "Cracks_" then
		surfaceGuis += 1
	end
end
check(surfaceGuis == 0, "aucun support d'étoile (Cracks_, SurfaceGui) créé")
local function sameLook(a, b)
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end
check(sameLook(look(windowA), LOOK_A) and sameLook(look(windowB), LOOK_B) and sameLook(look(windowC), LOOK_C), "vitres de Clément : transparence, couleur, matériau, taille, place, reflet inchangés")
check(windowA.LocalTransparencyModifier == 0 and windowB.LocalTransparencyModifier == 0 and windowC.LocalTransparencyModifier == 0, "plus aucune vitre cachée en local à la fin")
print("\n== Avertissements de la sortie (hors panne voulue de FragmentAsync)")
local others = 0
for _, line in warnings() do
	if not string.find(line, "FragmentAsync en panne", 1, true) then
		print("    " .. line)
		others += 1
	end
end
check(others == 0, "aucun autre avertissement (aucune erreur attrapée dans les effets)")
print(string.format("calculs FragmentAsync : %d, rayons lancés : %d", #GEOMETRY.Calls, RAYCASTS))
summary()
