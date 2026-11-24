---------------------------------------------------------------- scénarios (agent a315, 23/11, L-291)
print("== Banc a315 : intrus projeté à travers une vitre de boutique (GlassThrow)")

local v = Vector3.new

-- Faux Net : le remote GlassThrow du serveur relevé (NET_FIRES) et passé tel quel au client (un seul VM).
NET_FIRES = {}
local glassClient = newSignal()
local function muteRemote()
	local s = newSignal()
	return {
		Connect = function(_, fn) return s:Connect(fn) end,
		Fire = function() end,
		FireAll = function() end,
		FireClient = function() end,
		FireAllClients = function() end,
	}
end
local server = {
	GlassThrow = {
		FireAll = function(_, ...)
			local args = table.pack(...)
			table.insert(NET_FIRES, { t = now(), kind = args[1], pane = args[2], point = args[3], direction = args[4], victim = args[5], hitter = args[6], fresh = args[7] })
			glassClient:Fire(...)
		end,
	},
}
local client = { GlassThrow = { Connect = function(_, fn) return glassClient:Connect(fn) end } }
FAKE_NET = {
	Server = setmetatable(server, { __index = function(t, name) local r = muteRemote(); rawset(t, name, r); return r end }),
	Client = setmetatable(client, { __index = function(t, name) local r = muteRemote(); rawset(t, name, r); return r end }),
}
SOURCES["shared/Net/Net.luau"] = "return FAKE_NET"
-- Jeu DEV ou PROD (Config/ProductIds.IsDev) : Features.ShopGlassThrowDev = true, ShopGlassThrow = false.
BENCH_PRODUCT_IDS = { IsDev = true }
SOURCES["shared/Config/ProductIds.luau"] = "return BENCH_PRODUCT_IDS"
OWNERS = {} -- [plot] = Player
SOURCES["server/Services/PlotService.luau"] = "return { GetOwner = function(plot) return OWNERS[plot] end }"
ALLOWS = {}
SOURCES["server/Services/AntiCheatService.luau"] = "return { Allow = function(player, seconds, why) table.insert(ALLOWS, { player, seconds, why }) end }"
PLAYED = {}
SOURCES["client/Controllers/AnimationController.luau"] = "return { PlayPlayer = function(name) table.insert(PLAYED, name) return nil end }"

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

---------------------------------------------------------------- monde
new("Part", { Name = "Floor", Size = v(8000, 1, 8000), CFrame = CFrame.new(0, -0.5, 0), Anchored = true }, Workspace)
new("Terrain", { Name = "Terrain" }, Workspace)
local camera = new("Camera", { Name = "Camera" }, Workspace)
Workspace.CurrentCamera = camera
local map = folder(Workspace, "Map")

-- Effets et sons de Clément (mêmes noms que L-291 ; contenu factice).
local assets = folder(ReplicatedStorage, "Assets")
local fxFolder = folder(assets, "FX")
local function fxModel(name, light)
	local model = new("Model", { Name = name }, fxFolder)
	local root = new("Part", { Name = "Root", Size = v(1, 1, 1), Anchored = true, CanCollide = false, Transparency = 1 }, model)
	local emitter = new("ParticleEmitter", { Name = "Shards" }, root)
	emitter:SetAttribute("EmitCount", 30)
	local glow = new("PointLight", { Name = light, Brightness = 3 }, root)
	glow:SetAttribute("FadeTime", 0.2)
	model:SetAttribute("Duration", 1.5)
	return model
end
fxModel("FX_ShopGlass_Burst", "Flash")
fxModel("FX_ShopGlass_Reform", "Glow")
do
	local model = new("Model", { Name = "FX_ThrownTrail" }, fxFolder)
	local carrier = new("Part", { Name = "Carrier", Size = v(1, 1, 1), Anchored = true, CanCollide = false }, model)
	local top = new("Attachment", { Name = "TrailTop", Position = v(0, 1, 0) }, carrier)
	local bottom = new("Attachment", { Name = "TrailBottom", Position = v(0, -1, 0) }, carrier)
	new("Trail", { Name = "Trail", Attachment0 = top, Attachment1 = bottom, Enabled = false, Lifetime = 0.4 }, carrier)
end
local soundFolder = folder(folder(assets, "Sounds"), "Throw")
for _, name in { "Throw_Hit", "Throw_Whoosh", "Throw_GlassBurst", "Throw_GlassDebris", "Throw_GlassReform" } do
	new("Sound", { Name = name, SoundId = "rbxassetid://1" }, soundFolder)
end

-- Boutique de joueur comme plot_shop_builder (repère boutique : avant vers −Z, porte en z −40, pivot au sol au centre).
local GLASS = Color3.fromRGB(215, 238, 255)
local function box(parent, name, x0, y0, z0, x1, y1, z1, props)
	local p = new("Part", { Name = name, Size = v(x1 - x0, y1 - y0, z1 - z0), CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Anchored = true }, parent)
	for k, value in props or {} do
		if k == "CanCollide" then
			p.CanCollide = value
		end
	end
	for k, value in props or {} do
		if k ~= "CanCollide" then
			p[k] = value
		end
	end
	return p
end
local function pane(parent, name, x0, z0, x1, z1)
	return box(parent, name, x0, 1.4, z0, x1, 15.4, z1, { Material = Enum.Material.Glass, Color = GLASS, Transparency = 0.88, CastShadow = false, CanCollide = false, CanTouch = false, CanQuery = false })
end
local SIDE_PLANES = { -16.4, -12, -4, 4, 8, 16, 24, 32, 38.7 }
-- stage = 1 : niveau 1 (Stage_2 caché, fond du niveau 1 montré) ; 2 : boutique agrandie.
local function shop(name, frame, stage)
	local model = new("Model", { Name = name })
	model:SetAttribute("PlotIndex", 1)
	local bounds = box(model, "Bounds", -32, 0.3, -40, 32, 30, 40, { Transparency = 1, CanCollide = false, CanQuery = false })
	local pb = new("Model", { Name = "PlotBarrier" }, model)
	for _, w in {
		{ "Barrier_L", -32, 0.3, -40, -31.6, 30, 40 }, { "Barrier_R", 31.6, 0.3, -40, 32, 30, 40 },
		{ "Barrier_B", -32, 0.3, 39.6, 32, 30, 40 }, { "Barrier_Lid", -32, 30, -40, 32, 30.5, 40 },
		{ "Barrier_FL", -32, 0.3, -40, -9, 30, -39.6 }, { "Barrier_FR", 9, 0.3, -40, 32, 30, -39.6 },
	} do
		box(pb, w[1], w[2], w[3], w[4], w[5], w[6], w[7], { Transparency = 1, CanTouch = false })
	end
	local s1 = folder(model, "Stage_1")
	local f1 = new("Model", { Name = "Frame" }, s1)
	pane(f1, "Pane_L", -23.75, -38.8, -23.45, -16.4)
	pane(f1, "Pane_R", 23.45, -38.8, 23.75, -16.4)
	pane(f1, "Pane_FL", -22.7, -39.7, -10, -39.4)
	pane(f1, "Pane_FR", 10, -39.7, 22.7, -39.4)
	local back1 = new("Model", { Name = "Back_L1" }, f1)
	local backPane = pane(back1, "Pane_B", -22.7, -17.1, 22.7, -16.8)
	local s2 = folder(model, "Stage_2")
	local barriers = new("Model", { Name = "Barriers" }, s2)
	box(barriers, "Wall_Back", -31, 0.3, 38, 31, 30, 38.4, { Transparency = 1 })
	local f2 = new("Model", { Name = "Frame" }, s2)
	local stage2Panes = {}
	for i = 1, #SIDE_PLANES - 1 do
		table.insert(stage2Panes, pane(f2, "Pane_L", -23.75, SIDE_PLANES[i], -23.45, SIDE_PLANES[i + 1]))
		table.insert(stage2Panes, pane(f2, "Pane_R", 23.45, SIDE_PLANES[i], 23.75, SIDE_PLANES[i + 1]))
	end
	table.insert(stage2Panes, pane(f2, "Pane_B", -22.7, 39.4, 22.7, 39.7))
	if stage == 1 then
		for _, p in stage2Panes do
			p.Transparency = 1
		end
	else
		backPane.Transparency = 1
	end
	model.WorldPivot = CFrame.identity
	model:PivotTo(frame)
	model.Parent = map
	return model, bounds
end

local function frameFor(k, angle)
	return CFrame.new(400 * k, 0, 0) * CFrame.Angles(0, math.rad(angle), 0)
end
local ANGLES = { 0, -74, -170 }
local PLOTS = {}
for k, angle in ANGLES do
	local frame = frameFor(k, angle)
	local model, bounds = shop(`PLOT_{k}`, frame, 2)
	PLOTS[k] = { Model = model, Bounds = bounds, Frame = frame, Angle = angle }
end
local small = { Frame = frameFor(5, -74) }
small.Model, small.Bounds = shop("PLOT_Small", small.Frame, 1)

-- Joueurs R15 simplifiés (racine, torse, tête, bras, jambes et leurs Motor6D).
local function addPlayer(name, id)
	local player = new("Player", { Name = name, UserId = id }, Players)
	local model = new("Model", { Name = name })
	local root = new("Part", { Name = "HumanoidRootPart", Size = v(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, model)
	local function limb(n, offset, size)
		return new("Part", { Name = n, Size = size, CFrame = CFrame.new(offset + v(0, 3, 0)), CanCollide = false }, model)
	end
	local lower = limb("LowerTorso", v(0, -0.6, 0), v(2, 0.4, 1))
	local upper = limb("UpperTorso", v(0, 0.4, 0), v(2, 1.6, 1))
	local head = limb("Head", v(0, 1.8, 0), v(1.2, 1.2, 1.2))
	local la = limb("LeftUpperArm", v(-1.5, 0.5, 0), v(1, 1.2, 1))
	local ra = limb("RightUpperArm", v(1.5, 0.5, 0), v(1, 1.2, 1))
	local ll = limb("LeftUpperLeg", v(-0.5, -1.6, 0), v(1, 1.4, 1))
	local rl = limb("RightUpperLeg", v(0.5, -1.6, 0), v(1, 1.4, 1))
	local function motor(n, p0, p1)
		new("Motor6D", { Name = n, Part0 = p0, Part1 = p1, C0 = p0.CFrame:ToObjectSpace(p1.CFrame), C1 = CFrame.identity }, p1)
	end
	motor("Root", root, lower)
	motor("Waist", lower, upper)
	motor("Neck", upper, head)
	motor("LeftShoulder", upper, la)
	motor("RightShoulder", upper, ra)
	motor("LeftHip", lower, ll)
	motor("RightHip", lower, rl)
	new("Humanoid", { Name = "Humanoid" }, model)
	model.PrimaryPart = root
	model.Parent = Workspace
	player.Character = model
	return player
end
local OWNER = addPlayer("Proprio", 1)
local INTRUS = addPlayer("Intrus", 2)
local INTRUS2 = addPlayer("Intrus2", 3)
local AUTRE = addPlayer("Autre", 4)
Players.LocalPlayer = INTRUS
OWNERS[PLOTS[1].Model] = OWNER
OWNERS[PLOTS[2].Model] = INTRUS -- boutique d'INTRUS (joueur local) : il frappe
OWNERS[PLOTS[3].Model] = AUTRE
OWNERS[small.Model] = OWNER

local function placeAt(player, frame, x, y, z)
	local character = player.Character
	character:PivotTo(frame * CFrame.new(x, y, z))
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
		end
	end
end
local function localOf(frame, point)
	return frame:PointToObjectSpace(point)
end
local function close(a, b, eps)
	return a ~= nil and b ~= nil and (a - b).Magnitude <= (eps or 1e-3)
end
local function fmt(p)
	return if p == nil then "nil" else string.format("(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
end

-- Physique minimale : la poussée (LinearVelocity en plan) tient la vitesse à plat, la gravité agit, sol en y = 3
-- (racine), frottement au sol. Rien d'autre ne bouge (les éclats gardent leur vitesse de départ).
HEARTBEAT:Connect(function(dt)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil then
			continue
		end
		local push = root:FindFirstChildOfClass("LinearVelocity")
		local vel = root.AssemblyLinearVelocity
		if push == nil and vel.Magnitude < 1e-3 then
			continue
		end
		if push then
			local h = push.PrimaryTangentAxis * push.PlaneVelocity.X
			vel = v(h.X, vel.Y, h.Z)
		end
		vel -= v(0, Workspace.Gravity * dt, 0)
		local pos = root.Position + vel * dt
		if pos.Y < 3 then
			pos = v(pos.X, 3, pos.Z)
			vel = if push then v(vel.X, 0, vel.Z) else v(vel.X * 0.7, 0, vel.Z * 0.7)
			if vel.Magnitude < 0.5 then
				vel = Vector3.zero
			end
		end
		local delta = pos - root.Position
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = part.CFrame + delta
			end
		end
		root.AssemblyLinearVelocity = vel
	end
end)

---------------------------------------------------------------- modules
local ShopGlass = requireModule(MODULES["shared/ShopGlass.luau"], "server")
local GlassThrow = requireModule(MODULES["shared/Config/GlassThrow.luau"], "server")
local Service = requireModule(MODULES["server/Services/GlassThrowService.luau"], "server")
Service.Init()
Service.Start()
local Controller = requireModule(MODULES["client/Controllers/GlassThrowController.luau"], "client")
Controller.Start()
local CollectionService = CollectionServiceStub

local function choose(plot, victimLocal, hitterLocal, holes)
	local frame = plot.Frame
	local panes = ShopGlass.Collect(plot.Model, CollectionService:GetTagged(ShopGlass.Tag))
	local from = frame:PointToWorldSpace(victimLocal)
	local dir = frame:PointToWorldSpace(victimLocal) - frame:PointToWorldSpace(hitterLocal)
	return ShopGlass.Choose(plot.Bounds, panes, from, dir, GlassThrow, holes)
end
local function paneIn(choice, plot)
	return choice and choice.Pane:IsDescendantOf(plot.Model)
end

---------------------------------------------------------------------------------------------------------------
print("-- 1. Choix de la vitre (Shared/ShopGlass.Choose), boutique tournée à 0°, −74° et −170°")
for k, plot in PLOTS do
	local tag = `[{plot.Angle}°]`
	local frame = plot.Frame
	-- Coup vers la gauche : Pane_L du niveau 1, dans le sens du coup, trou à la hauteur du corps (bornée).
	local c = choose(plot, v(-15, 3, -20), v(-5, 3, -20))
	local p = c and localOf(frame, c.Point)
	check(c ~= nil and c.Pane.Name == "Pane_L" and c.ByRay and c.Side == "Left" and paneIn(c, plot), `{tag} coup vers la gauche : Pane_L, sens du coup, Left`)
	check(p ~= nil and near(p.X, -23.6, 1e-3) and near(p.Z, -20, 1e-3) and near(p.Y, 4.4, 1e-3), `{tag} trou au droit du corps sur Pane_L {fmt(p)} (attendu (-23.60, 4.40, -20.00))`)
	check(c ~= nil and close(frame:VectorToObjectSpace(c.Frame.N), v(-1, 0, 0)) and close(frame:VectorToObjectSpace(c.Direction), v(-1, 0, 0)), `{tag} normale et sens du vol vers l'extérieur (−X boutique)`)
	-- Vers l'avant : Pane_FL.
	c = choose(plot, v(-15, 3, -30), v(-15, 3, -20))
	check(c ~= nil and c.Pane.Name == "Pane_FL" and c.ByRay and c.Side == "Front", `{tag} coup vers l'avant : Pane_FL, Front`)
	-- Vers la porte (pas de vitre dans l'axe) : la plus proche, Pane_FL.
	c = choose(plot, v(-3, 3, -30), v(-3, 3, -20))
	check(c ~= nil and c.Pane.Name == "Pane_FL" and not c.ByRay, `{tag} coup vers la porte : la plus proche (Pane_FL), pas le sens du coup`)
	p = c and localOf(frame, c.Point)
	check(p ~= nil and p.X <= -10 - c.HoleHalfWidth - GlassThrow.EdgeMargin + 1e-3 and near(p.Z, -39.55, 1e-3), `{tag} trou gardé dans la vitre, bord compris {fmt(p)}`)
	-- Vers le fond (niveau 2) : Pane_B du fond.
	c = choose(plot, v(5, 3, 30), v(5, 3, 20))
	check(c ~= nil and c.Pane.Name == "Pane_B" and c.ByRay and c.Side == "Back" and near(localOf(frame, c.Point).Z, 39.55, 1e-3), `{tag} coup vers le fond : Pane_B du niveau 2, Back`)
	-- En diagonale : la première vitre sur le rayon (Pane_FR, pas Pane_R).
	c = choose(plot, v(15, 3, -34), v(10, 3, -29))
	check(c ~= nil and c.Pane.Name == "Pane_FR" and c.ByRay, `{tag} coup en diagonale : première vitre coupée (Pane_FR)`)
	-- Vers la droite depuis le segment z 8..16 du niveau 2 : ce segment-là.
	c = choose(plot, v(10, 3, 12), v(0, 3, 12))
	p = c and localOf(frame, c.Point)
	check(c ~= nil and c.Pane.Name == "Pane_R" and c.Side == "Right" and p ~= nil and near(p.Z, 12, 1e-3) and near(p.X, 23.6, 1e-3), `{tag} coup vers la droite au niveau 2 : segment de Pane_R en face {fmt(p)}`)
end
do
	-- Niveau 1 : le fond du niveau 1 (Back_L1/Pane_B, à 23 de Bounds) ne donne pas dehors ; Stage_2 caché ignoré.
	local plot = { Model = small.Model, Bounds = small.Bounds, Frame = small.Frame }
	local c = choose(plot, v(5, 3, -20), v(5, 3, -30))
	check(c ~= nil and c.Pane.Name == "Pane_R" and not c.ByRay and c.Pane.Parent.Name == "Frame", "[niveau 1] coup vers le fond : pas le fond du niveau 1 (dedans), la plus proche (Pane_R)")
	local panes = ShopGlass.Collect(small.Model, {})
	check(#panes == 5, `[niveau 1] vitres montrées seulement (5 : L, R, FL, FR, fond du niveau 1) : {#panes}`)
	-- Seul le fond du niveau 1 en lice : aucune vitre (le service sort alors devant la porte, comme avant).
	local back = small.Model.Stage_1.Frame.Back_L1.Pane_B
	check(ShopGlass.Choose(small.Bounds, { back }, small.Frame:PointToWorldSpace(v(5, 3, -20)), small.Frame:VectorToWorldSpace(v(0, 0, 1)), GlassThrow) == nil, "[niveau 1] seul le fond du niveau 1 : aucune vitre")
end

---------------------------------------------------------------------------------------------------------------
print("-- 2. Vitres par tag ShopGlass, repli par nom, côté")
do
	local plot = PLOTS[1]
	local panes, byTag = ShopGlass.Collect(plot.Model, CollectionService:GetTagged(ShopGlass.Tag))
	check(not byTag and #panes == 4 + 16 + 1, `sans tag : repli par nom Pane_* (21 vitres montrées, fond du niveau 1 caché) : {#panes}`)
	local fl = plot.Model.Stage_1.Frame.Pane_FL
	local r = plot.Model.Stage_1.Frame.Pane_R
	addTag(fl, "ShopGlass")
	fl:SetAttribute("GlassSide", "Front")
	addTag(r, "ShopGlass")
	r:SetAttribute("GlassSide", "Back") -- attribut voulu par Clément : il gagne sur le nom
	addTag(PLOTS[2].Model.Stage_1.Frame.Pane_L, "ShopGlass") -- autre boutique : ne compte pas ici
	panes, byTag = ShopGlass.Collect(plot.Model, CollectionService:GetTagged(ShopGlass.Tag))
	check(byTag and #panes == 2 and table.find(panes, fl) ~= nil and table.find(panes, r) ~= nil, `avec tag : seulement les vitres taguées de cette boutique ({#panes})`)
	local c = choose(plot, v(-15, 3, -20), v(-5, 3, -20))
	check(c ~= nil and c.Pane ~= plot.Model.Stage_1.Frame.Pane_L and not c.ByRay, "avec tag : Pane_L pas taguée, pas choisie (la plus proche parmi les taguées)")
	c = choose(plot, v(15, 3, -20), v(5, 3, -20))
	check(c ~= nil and c.Pane == r and c.Side == "Back", "GlassSide lu sur la vitre (Back gagne sur la lettre R)")
	check(ShopGlass.SideOf(plot.Bounds, plot.Model.Stage_1.Frame.Pane_L) == "Left", "sans GlassSide : côté par la lettre (Pane_L = Left)")
	local odd = pane(plot.Model, "Pane_Glass", 23.45, -30, 23.75, -20)
	odd.CFrame = plot.Frame * odd.CFrame
	check(ShopGlass.SideOf(plot.Bounds, odd) == "Right", "nom sans lettre connue : côté par la place dans Bounds (Right)")
	odd:Destroy()
	-- Retirer les tags (la suite du banc travaille par nom).
	for _, inst in CollectionService:GetTagged("ShopGlass") do
		CollectionService:RemoveTag(inst, "ShopGlass")
	end
	r:SetAttribute("GlassSide", nil)
	fl:SetAttribute("GlassSide", nil)
	panes, byTag = ShopGlass.Collect(plot.Model, CollectionService:GetTagged(ShopGlass.Tag))
	check(not byTag and #panes == 21, "tags retirés : de nouveau par nom")
end

---------------------------------------------------------------------------------------------------------------
-- Relevés
local function partsOf(player)
	local out = {}
	for _, part in player.Character:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(out, part)
		end
	end
	return out
end
local function allGroups(parts, group)
	for _, part in parts do
		if part.CollisionGroup ~= group then
			return false
		end
	end
	return true
end
local function barriersOf(plot)
	local out = {}
	for _, d in plot.Model:GetDescendants() do
		if d:IsA("BasePart") and (d:IsDescendantOf(plot.Model.PlotBarrier) or d:IsDescendantOf(plot.Model.Stage_2.Barriers)) then
			table.insert(out, d)
		end
	end
	return out
end
local function count(player, class)
	local n = 0
	for _, d in player.Character:GetDescendants() do
		if d:IsA(class) then
			n += 1
		end
	end
	return n
end
local function motorsOn(player)
	local on, off = {}, {}
	for _, d in player.Character:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(if d.Enabled then on else off, d.Name)
		end
	end
	return on, off
end
local function fires(kind, since)
	local out = {}
	for _, f in NET_FIRES do
		if f.kind == kind and f.t >= (since or -1) then
			table.insert(out, f)
		end
	end
	return out
end
local PANE_PROPS = { "CFrame", "Size", "Color", "Material", "Transparency", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Anchored", "LocalTransparencyModifier", "Parent", "Name" }
local function snapshot(part)
	local s = {}
	for _, k in PANE_PROPS do
		s[k] = part[k]
	end
	s.children = #part:GetChildren()
	return s
end
local function same(part, s)
	for _, k in PANE_PROPS do
		if part[k] ~= s[k] then
			return false, k
		end
	end
	return #part:GetChildren() == s.children, "enfants"
end
local function fxPieces(prefix)
	local fx = Workspace:FindFirstChild("_GlassThrowFX")
	local out = {}
	for _, d in if fx then fx:GetChildren() else {} do
		if string.sub(d.Name, 1, #prefix) == prefix then
			table.insert(out, d)
		end
	end
	return out
end
local function emitsSince(t)
	local n = 0
	for _, e in EMIT_LOG do
		if e.t >= t then
			n += 1
		end
	end
	return n
end
local function soundsSince(t, name)
	local n = 0
	for _, s in SOUND_LOG do
		if s.t >= t and s.name == name then
			n += 1
		end
	end
	return n
end
local function resetWorld()
	step(12) -- trous réparés, effets retirés
	for _, player in { OWNER, INTRUS, INTRUS2, AUTRE } do
		placeAt(player, CFrame.new(-900 - player.UserId * 10, 0, -900), 0, 3, 0)
	end
	table.clear(NET_FIRES)
end

---------------------------------------------------------------------------------------------------------------
print("-- 3. Refus : rien n'est fait")
do
	local plot = PLOTS[1]
	local before = #NET_FIRES
	local function untouched(label)
		check(#NET_FIRES == before and allGroups(partsOf(INTRUS), "Default") and NETWORK_OWNER[INTRUS.Character.HumanoidRootPart] == nil
			and count(INTRUS, "BallSocketConstraint") == 0 and not Service.IsThrown(INTRUS) and not INTRUS.Character.Humanoid.PlatformStand, label)
	end
	placeAt(OWNER, plot.Frame, -5, 3, -20)
	placeAt(INTRUS, plot.Frame, -15, 3, -60) -- devant la façade, hors de Bounds
	check(Service.Throw(OWNER, INTRUS, plot.Model, plot.Bounds) == false, "intrus hors de la boutique : refus")
	untouched("  … rien n'a bougé")
	placeAt(INTRUS, plot.Frame, -15, 3, -20)
	check(Service.Throw(AUTRE, INTRUS, plot.Model, plot.Bounds) == false, "le frappeur n'est pas le propriétaire : refus")
	untouched("  … rien n'a bougé")
	check(Service.Throw(OWNER, OWNER, plot.Model, plot.Bounds) == false, "le propriétaire lui-même : refus")
	BENCH_PRODUCT_IDS.IsDev = false
	check(Service.IsEnabled() == false, "jeu PROD (IsDev faux, ShopGlassThrow = false) : interrupteur éteint")
	check(Service.Throw(OWNER, INTRUS, plot.Model, plot.Bounds) == false, "interrupteur éteint : refus")
	untouched("  … rien n'a bougé")
	BENCH_PRODUCT_IDS.IsDev = true
	check(Service.IsEnabled() == true, "jeu DEV (ShopGlassThrowDev) : allumé")
	step(0.1)
	check(#NET_FIRES == before and #ALLOWS == 0, "aucun remote, aucune permission AntiCheat")
end

---------------------------------------------------------------------------------------------------------------
print("-- 4. Projection complète, boutique tournée à 0°, −74° et −170°")
local PLAYERS_OF = {
	{ victim = INTRUS, hitter = OWNER, role = "victime locale" },
	{ victim = OWNER, hitter = INTRUS, role = "frappeur local" },
	{ victim = INTRUS2, hitter = AUTRE, role = "spectateur local" },
}
for k, plot in PLOTS do
	local tag = `[{plot.Angle}°]`
	local who = PLAYERS_OF[k]
	local victim, hitter = who.victim, who.hitter
	local frame = plot.Frame
	local target = plot.Model.Stage_1.Frame.Pane_L
	local paneBefore = snapshot(target)
	local otherBarriers = barriersOf(PLOTS[(k % 3) + 1])
	local t0 = now()
	local fragBefore = #FRAGMENT_CALLS
	table.clear(PLAYED)
	placeAt(hitter, frame, -5, 3, -20)
	placeAt(victim, frame, -15, 3, -20)
	local doneWith = nil
	local camBefore = camera.CFrame
	local ok = Service.Throw(hitter, victim, plot.Model, plot.Bounds, function(outside)
		doneWith = outside
	end)
	check(ok == true and Service.IsThrown(victim), `{tag} projection acceptée ({who.role})`)
	local throwFire = fires("Throw", t0)[1]
	check(throwFire ~= nil and throwFire.pane == target and throwFire.victim == victim and throwFire.hitter == hitter, `{tag} remote Throw (vitre, victime, frappeur)`)
	check(allGroups(partsOf(victim), "GlassThrown") and allGroups(barriersOf(plot), "GlassThrowBarrier") and allGroups(otherBarriers, "Default"), `{tag} groupes : corps GlassThrown, murs de cette boutique GlassThrowBarrier, autres murs Default`)
	check(not PhysicsServiceStub:CollisionGroupsAreCollidable("GlassThrown", "GlassThrowBarrier") and PhysicsServiceStub:CollisionGroupsAreCollidable("GlassThrown", "Default")
		and PhysicsServiceStub:CollisionGroupsAreCollidable("GlassThrowBarrier", "Default") and PhysicsServiceStub:CollisionGroupsAreCollidable("GlassThrowBarrier", "GlassThrowBarrier"), `{tag} seuls corps projeté et murs de la boutique ne se heurtent pas`)
	local on, off = motorsOn(victim)
	table.sort(on)
	check(#off == 5 and #on == 2 and on[1] == "Neck" and on[2] == "Root" and count(victim, "BallSocketConstraint") == 5, `{tag} ragdoll : 5 rotules, Root et Neck gardés`)
	check(NETWORK_OWNER[victim.Character.HumanoidRootPart] == false and victim.Character.Humanoid.PlatformStand, `{tag} serveur propriétaire du corps, PlatformStand`)
	check(#ALLOWS > 0 and ALLOWS[#ALLOWS][1] == victim, `{tag} AntiCheat prévenu`)
	check(SOUND_LOG[#SOUND_LOG] ~= nil and soundsSince(t0, "Throw_Hit") == 1 and soundsSince(t0, "Throw_Whoosh") == 1, `{tag} sons Throw_Hit et Throw_Whoosh`)
	local torso = victim.Character.UpperTorso
	check(torso:FindFirstChildOfClass("Trail") ~= nil and torso:FindFirstChildOfClass("Trail").Enabled, `{tag} traînée FX_ThrownTrail sur UpperTorso`)

	step(0.3)
	local hole = fires("Hole", t0)[1]
	local root = victim.Character.HumanoidRootPart
	check(hole ~= nil and hole.pane == target and hole.fresh == true, `{tag} remote Hole (trou neuf) quand le corps passe la vitre`)
	local n = ShopGlass.FrameOf(plot.Bounds, target).N
	check(hole ~= nil and (root.Position - hole.point):Dot(n) > 0, `{tag} le corps est passé de l'autre côté de la vitre`)
	check(target.LocalTransparencyModifier == 1, `{tag} vraie vitre cachée en local`)
	check(#FRAGMENT_CALLS == fragBefore + 1 and FRAGMENT_CALLS[#FRAGMENT_CALLS].Part ~= target, `{tag} FragmentAsync une fois, sur une copie (jamais la vraie vitre)`)
	local call = FRAGMENT_CALLS[#FRAGMENT_CALLS]
	check(call ~= nil and #call.Sites == 1 + GlassThrow.InnerPoints and type(call.Sites[1]) == "table" and #call.Sites[1] == GlassThrow.RingPoints + GlassThrow.FarPoints, `{tag} points : groupe (anneau + loin) puis {GlassThrow.InnerPoints} dans le trou`)
	local frost = fxPieces("GlassFrost_")
	local shards = fxPieces("GlassShard_")
	check(#frost == 1 and frost[1].Color == GlassThrow.FrostColor and frost[1].Material == GlassThrow.FrostMaterial and near(frost[1].Transparency, GlassThrow.FrostTransparency) and frost[1].Anchored and not frost[1].CanCollide, `{tag} reste de la vitre givré (#D6EEFA, SmoothPlastic, 0,55), ancré, sans collision`)
	check(#frost == 1 and close(frost[1].CFrame.Position, target.CFrame.Position) and close(frost[1].Size, target.Size), `{tag} givre à la place de la vitre`)
	local outward = 0
	for _, s in shards do
		if s.AssemblyLinearVelocity:Dot(n) > 0 and not s.Anchored then
			outward += 1
		end
	end
	check(#shards == GlassThrow.InnerPoints and outward == #shards, `{tag} {#shards} éclats lancés vers l'extérieur`)
	check(emitsSince(t0) >= 1 and soundsSince(t0, "Throw_GlassBurst") == 1 and soundsSince(t0, "Throw_GlassDebris") == 1, `{tag} FX_ShopGlass_Burst émis, sons GlassBurst et GlassDebris`)
	local burst = nil
	for _, e in EMIT_LOG do
		if e.t >= t0 then
			burst = e
		end
	end
	check(burst ~= nil and close(burst.at, hole.point, 1e-3), `{tag} éclat de verre posé au trou {fmt(burst and burst.at)}`)
	if who.role == "spectateur local" then
		check(camera.CFrame == camBefore, `{tag} pas de secousse pour un spectateur`)
	else
		check(camera.CFrame ~= camBefore, `{tag} secousse de caméra ({who.role})`)
	end

	step(GlassThrow.RagdollTime)
	local land = fires("Land", t0)[1]
	check(land ~= nil and land.victim == victim and not Service.IsThrown(victim), `{tag} relevé : remote Land, plus en vol`)
	check(allGroups(partsOf(victim), "Default") and allGroups(barriersOf(plot), "Default"), `{tag} groupes rendus (corps et murs)`)
	on, off = motorsOn(victim)
	check(#off == 0 and count(victim, "BallSocketConstraint") == 0 and count(victim, "LinearVelocity") == 0 and root:FindFirstChild("GlassThrow") == nil, `{tag} Motor6D rendus, plus de rotule ni de poussée`)
	check(NETWORK_OWNER[root] == victim and not victim.Character.Humanoid.PlatformStand, `{tag} corps rendu au joueur, PlatformStand rendu`)
	local outBy = ShopGlass.OutsideBy(plot.Bounds, root.Position)
	check(outBy > 0 and doneWith == true, `{tag} atterri dehors ({string.format("%.1f", outBy)} studs hors de Bounds), onDone(true)`)
	local lp = localOf(frame, root.Position)
	check(lp.X < -32, `{tag} sorti par le côté gauche de la boutique {fmt(lp)}`)
	check(close(root.CFrame.UpVector, v(0, 1, 0), 1e-3) and near(root.Position.Y, 3.2, 1e-3), `{tag} debout, pieds au sol (y {string.format("%.2f", root.Position.Y)})`)
	local states = {}
	for _, s in HUMANOID_STATES do
		if s[1] == victim.Character.Humanoid then
			table.insert(states, s[2].Name)
		end
	end
	check(states[#states] == "GettingUp" and table.find(states, "Physics") ~= nil, `{tag} états Physics puis GettingUp`)
	if victim == INTRUS then
		check(#PLAYED == 1 and PLAYED[1] == "Knockback", `{tag} la victime locale joue Knockback`)
	else
		check(#PLAYED == 0, `{tag} Knockback seulement chez la victime`)
	end
	step(1)
	check(torso:FindFirstChildOfClass("Trail") == nil and torso:FindFirstChildOfClass("Attachment") == nil, `{tag} traînée retirée`)
	check(#fxPieces("GlassShard_") == 0, `{tag} éclats retirés après ShardLife`)

	-- Réparation après HoleDuration.
	check(target.LocalTransparencyModifier == 1 and #fires("Repair", t0) == 0, `{tag} trou encore ouvert avant HoleDuration`)
	local hp, untilAt = Service.GetHole(target)
	check(hp ~= nil and near(untilAt, hole.t + GlassThrow.HoleDuration, 1e-6), `{tag} GetHole : centre et fin du trou`)
	step(GlassThrow.HoleDuration)
	local repairs = fires("Repair", t0)
	check(#repairs == 1 and near(repairs[1].t, hole.t + GlassThrow.HoleDuration, 1 / 30), `{tag} un seul Repair, HoleDuration après le trou`)
	local okSame, what = same(target, paneBefore)
	check(okSame, `{tag} vitre rendue exactement comme avant (écart : {if okSame then "aucun" else what})`)
	check(#fxPieces("GlassFrost_") == 0 and Service.GetHole(target) == nil, `{tag} givre retiré, plus de trou`)
	check(soundsSince(repairs[1].t, "Throw_GlassReform") == 1 and emitsSince(repairs[1].t) >= 1, `{tag} FX_ShopGlass_Reform et son GlassReform`)
	resetWorld()
end

---------------------------------------------------------------------------------------------------------------
print("-- 5. Deux projections rapprochées dans la même vitre")
do
	local plot = PLOTS[1]
	local target = plot.Model.Stage_1.Frame.Pane_L
	local before = snapshot(target)
	local t0 = now()
	local fragBefore = #FRAGMENT_CALLS
	placeAt(OWNER, plot.Frame, -5, 3, -20)
	placeAt(INTRUS, plot.Frame, -15, 3, -20)
	placeAt(INTRUS2, plot.Frame, -12, 3, -24)
	local doneA, doneB = nil, nil
	check(Service.Throw(OWNER, INTRUS, plot.Model, plot.Bounds, function(o) doneA = o end), "première projection")
	check(Service.Throw(OWNER, INTRUS, plot.Model, plot.Bounds) == false, "la même victime pendant son vol : refus")
	step(0.4)
	local firstHole = fires("Hole", t0)[1]
	check(Service.Throw(OWNER, INTRUS2, plot.Model, plot.Bounds, function(o) doneB = o end), "seconde projection 0,4 s après")
	local sChoice = fires("Throw", t0)[2]
	check(sChoice ~= nil and sChoice.pane == target and close(sChoice.point, firstHole.point), "même vitre, visée au trou déjà ouvert")
	step(0.4)
	local holes = fires("Hole", t0)
	check(#holes == 2 and holes[1].fresh == true and holes[2].fresh == false and close(holes[2].point, holes[1].point), "second Hole : trou déjà ouvert (fresh = false), même centre")
	check(#FRAGMENT_CALLS == fragBefore + 1 and #fxPieces("GlassFrost_") == 1, "un seul découpage, un seul givre")
	check(soundsSince(holes[2].t, "Throw_GlassDebris") == 1 and soundsSince(holes[2].t, "Throw_GlassBurst") == 0, "second passage : son GlassDebris seul")
	local _, untilAt = Service.GetHole(target)
	check(near(untilAt, holes[2].t + GlassThrow.HoleDuration, 1e-6), "trou prolongé jusqu'à HoleDuration après le second passage")
	-- La première victime se relève pendant que la seconde vole : les murs restent traversables.
	step(GlassThrow.RagdollTime - 0.8 + 0.05)
	check(not Service.IsThrown(INTRUS) and Service.IsThrown(INTRUS2), "première relevée, seconde encore en vol")
	check(allGroups(barriersOf(plot), "GlassThrowBarrier") and allGroups(partsOf(INTRUS), "Default") and allGroups(partsOf(INTRUS2), "GlassThrown"), "murs gardés pour le second vol, premier corps rendu")
	step(0.5)
	check(not Service.IsThrown(INTRUS2) and allGroups(barriersOf(plot), "Default") and doneA == true and doneB == true, "les deux relevés dehors, murs rendus")
	step(holes[1].t + GlassThrow.HoleDuration + 0.2 - now())
	check(#fires("Repair", t0) == 0 and target.LocalTransparencyModifier == 1, "pas de réparation à la fin du premier délai (prolongé)")
	step(holes[2].t + GlassThrow.HoleDuration + 0.1 - now())
	local repairs = fires("Repair", t0)
	check(#repairs == 1, `une seule réparation ({#repairs})`)
	local okSame, what = same(target, before)
	check(okSame and #fxPieces("GlassFrost_") == 0, `vitre rendue telle quelle (écart : {if okSame then "aucun" else what})`)
	resetWorld()
end

---------------------------------------------------------------------------------------------------------------
print("-- 6. Courses côté client (FragmentAsync qui attend ou échoue)")
do
	local plot = PLOTS[3]
	local target = plot.Model.Stage_1.Frame.Pane_L
	local before = snapshot(target)
	-- Réparation arrivée avant la fin de FragmentAsync : le résultat est jeté, la vitre rendue.
	FRAGMENT_DELAY = GlassThrow.HoleDuration + 2
	local t0 = now()
	placeAt(AUTRE, plot.Frame, -5, 3, -20)
	placeAt(INTRUS2, plot.Frame, -15, 3, -20)
	check(Service.Throw(AUTRE, INTRUS2, plot.Model, plot.Bounds), "projection (FragmentAsync lent)")
	step(GlassThrow.HoleDuration + 1)
	check(#fires("Repair", t0) == 1 and target.LocalTransparencyModifier == 0, "réparé pendant le découpage : vitre remontrée")
	step(2)
	local okSame, what = same(target, before)
	check(okSame and #fxPieces("GlassFrost_") == 0 and #fxPieces("GlassShard_") == 0 and #fxPieces("GlassHole_") == 0, `découpage arrivé après : jeté, vitre telle quelle (écart : {if okSame then "aucun" else what})`)
	resetWorld()
	-- Second Hole pendant le découpage : pas de second découpage.
	FRAGMENT_DELAY = 1
	t0 = now()
	local fragBefore = #FRAGMENT_CALLS
	placeAt(AUTRE, plot.Frame, -5, 3, -20)
	placeAt(INTRUS2, plot.Frame, -15, 3, -20)
	placeAt(OWNER, plot.Frame, -12, 3, -24)
	Service.Throw(AUTRE, INTRUS2, plot.Model, plot.Bounds)
	step(0.3)
	Service.Throw(AUTRE, OWNER, plot.Model, plot.Bounds)
	step(0.4)
	check(#fires("Hole", t0) == 2 and #FRAGMENT_CALLS == fragBefore + 1 and target.LocalTransparencyModifier == 1, "second trou pendant le découpage : un seul FragmentAsync, vitre cachée")
	step(1)
	check(#fxPieces("GlassFrost_") == 1, "découpage fini : un givre")
	step(GlassThrow.HoleDuration + 1)
	okSame, what = same(target, before)
	check(#fires("Repair", t0) == 1 and okSame and #fxPieces("GlassFrost_") == 0, `réparé : vitre telle quelle (écart : {if okSame then "aucun" else what})`)
	resetWorld()
	-- FragmentAsync en erreur : une ligne, vitre cachée jusqu'à la réparation, puis rendue.
	FRAGMENT_DELAY = 0.05
	FRAGMENT_FAIL = true
	clearLog()
	t0 = now()
	placeAt(AUTRE, plot.Frame, -5, 3, -20)
	placeAt(INTRUS2, plot.Frame, -15, 3, -20)
	Service.Throw(AUTRE, INTRUS2, plot.Model, plot.Bounds)
	step(0.5)
	check(logHas("FragmentAsync", "WARN", "client") and target.LocalTransparencyModifier == 1 and #fxPieces("GlassFrost_") == 0, "FragmentAsync en erreur : avertissement, vitre cachée, pas de givre")
	step(GlassThrow.HoleDuration + 1)
	okSame, what = same(target, before)
	check(okSame, `puis réparée telle quelle (écart : {if okSame then "aucun" else what})`)
	FRAGMENT_FAIL = false
	resetWorld()
end

---------------------------------------------------------------------------------------------------------------
print("-- 7. Effets visuels coupés, départ en vol")
do
	local plot = PLOTS[1]
	local target = plot.Model.Stage_1.Frame.Pane_L
	INTRUS:SetAttribute("VfxEnabled", false)
	local Settings = requireModule(MODULES["shared/Config/Settings.luau"], "client")
	check(Settings.VfxReduced(INTRUS), "VISUAL EFFECTS sur OFF chez le joueur local")
	local t0 = now()
	local camBefore = camera.CFrame
	placeAt(OWNER, plot.Frame, -5, 3, -20)
	placeAt(INTRUS, plot.Frame, -15, 3, -20)
	Service.Throw(OWNER, INTRUS, plot.Model, plot.Bounds)
	check(camera.CFrame == camBefore and INTRUS.Character.UpperTorso:FindFirstChildOfClass("Trail") == nil, "effets coupés : ni secousse ni traînée")
	step(0.3)
	check(emitsSince(t0) == 0 and #fxPieces("GlassFrost_") == 1 and target.LocalTransparencyModifier == 1, "effets coupés : pas de particules, le trou reste")
	INTRUS:SetAttribute("VfxEnabled", nil)
	resetWorld()

	-- Le joueur quitte en plein vol : tout est rendu, pas de Land.
	t0 = now()
	placeAt(OWNER, plot.Frame, -5, 3, -20)
	placeAt(INTRUS2, plot.Frame, -15, 3, -20)
	OWNERS[plot.Model] = OWNER
	Service.Throw(OWNER, INTRUS2, plot.Model, plot.Bounds)
	step(0.1)
	Players.PlayerRemoving:Fire(INTRUS2)
	check(not Service.IsThrown(INTRUS2) and allGroups(partsOf(INTRUS2), "Default") and allGroups(barriersOf(plot), "Default") and count(INTRUS2, "BallSocketConstraint") == 0, "départ en vol : groupes, murs et Motor6D rendus")
	check(#fires("Land", t0) == 0, "départ en vol : pas de Land")
	resetWorld()
end

---------------------------------------------------------------------------------------------------------------
print("-- 8. Vitres posées par Clément (L-298) : noms uniques, tag ShopGlass et GlassSide, boutique à −74°")
do
	-- Comme L-298 : Stage_1/Frame/Pane_FL, Pane_FR, Pane_L_01…_05 et Pane_R_01…_05 (z −38,8 à 8), Back_L1/Pane_B
	-- (fond du niveau 1, z 8) ; Stage_2/Frame/Pane_L_06…_09, Pane_R_06…_09 (z 8 à 38,7) et Pane_B (fond, z 39,55).
	local PLANES = { -38.8, -16.4, -12, -4, 4, 8, 16, 24, 32, 38.7 }
	local function build(name, frame, stage)
		local model = new("Model", { Name = name })
		local bounds = box(model, "Bounds", -32, 0.3, -40, 32, 30, 40, { Transparency = 1, CanCollide = false, CanQuery = false })
		local pb = new("Model", { Name = "PlotBarrier" }, model)
		box(pb, "Barrier_L", -32, 0.3, -40, -31.6, 30, 40, { Transparency = 1 })
		box(pb, "Barrier_R", 31.6, 0.3, -40, 32, 30, 40, { Transparency = 1 })
		box(pb, "Barrier_B", -32, 0.3, 39.6, 32, 30, 40, { Transparency = 1 })
		local f1 = new("Model", { Name = "Frame" }, folder(model, "Stage_1"))
		local f2 = new("Model", { Name = "Frame" }, folder(model, "Stage_2"))
		local all = {}
		local function glass(parent, n, side, x0, z0, x1, z1)
			local p = pane(parent, n, x0, z0, x1, z1)
			addTag(p, "ShopGlass")
			p:SetAttribute("GlassSide", side)
			table.insert(all, p)
			return p
		end
		glass(f1, "Pane_FL", "Front", -22.7, -39.7, -10, -39.4)
		glass(f1, "Pane_FR", "Front", 10, -39.7, 22.7, -39.4)
		for i = 1, #PLANES - 1 do
			local parent = if i <= 5 then f1 else f2
			glass(parent, string.format("Pane_L_%02d", i), "Left", -23.75, PLANES[i], -23.45, PLANES[i + 1])
			glass(parent, string.format("Pane_R_%02d", i), "Right", 23.45, PLANES[i], 23.75, PLANES[i + 1])
		end
		local back1 = glass(new("Model", { Name = "Back_L1" }, f1), "Pane_B", "Back", -22.7, 7.85, 22.7, 8.15)
		local back2 = glass(f2, "Pane_B", "Back", -22.7, 39.4, 22.7, 39.7)
		-- Une vieille pièce Pane_* sans tag : ignorée dès qu'une vitre est taguée.
		pane(f1, "Pane_Old", -23.75, -30, -23.45, -20)
		if stage == 1 then
			for _, p in f2:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = 1
				end
			end
		else
			back1.Transparency = 1
		end
		model.WorldPivot = CFrame.identity
		model:PivotTo(frame)
		model.Parent = map
		return { Model = model, Bounds = bounds, Frame = frame, Back1 = back1, Back2 = back2, All = all }
	end
	local big = build("PLOT_L298", frameFor(7, -74), 2)
	local first = build("PLOT_L298_N1", frameFor(8, -74), 1)
	OWNERS[big.Model] = OWNER
	OWNERS[first.Model] = OWNER
	local panes, byTag = ShopGlass.Collect(big.Model, CollectionService:GetTagged(ShopGlass.Tag))
	check(byTag and #panes == 2 + 18 + 1, `par tag : 21 vitres montrées, Pane_Old sans tag ignorée ({#panes})`)
	local c = choose(big, v(-15, 3, -20), v(-5, 3, -20))
	check(c ~= nil and c.Pane.Name == "Pane_L_01" and c.Side == "Left" and c.ByRay, "coup vers la gauche en z −20 : Pane_L_01 (Left)")
	c = choose(big, v(10, 3, 20), v(0, 3, 20))
	check(c ~= nil and c.Pane.Name == "Pane_R_07" and c.Side == "Right" and c.ByRay, "coup vers la droite en z 20 (niveau 2) : Pane_R_07 (Right)")
	c = choose(big, v(5, 3, 30), v(5, 3, 20))
	check(c ~= nil and c.Pane == big.Back2 and c.Side == "Back", "coup vers le fond au niveau 2 : Pane_B de Stage_2 (Back)")
	c = choose(first, v(5, 3, 0), v(5, 3, -10))
	check(c ~= nil and c.Pane ~= first.Back1 and c.Side ~= "Back", `niveau 1 : le fond Back_L1 (z 8, donne encore dans Bounds) n'est pas choisi ({c and c.Pane.Name})`)

	-- Projection complète vers le fond (niveau 2), par tag.
	local before = snapshot(big.Back2)
	local t0 = now()
	placeAt(OWNER, big.Frame, 5, 3, 20)
	placeAt(INTRUS2, big.Frame, 5, 3, 30)
	local doneWith = nil
	check(Service.Throw(OWNER, INTRUS2, big.Model, big.Bounds, function(o) doneWith = o end), "projection vers le fond acceptée")
	step(0.3)
	local hole = fires("Hole", t0)[1]
	check(hole ~= nil and hole.pane == big.Back2 and hole.fresh, "trou dans Pane_B du fond")
	step(GlassThrow.RagdollTime)
	local root = INTRUS2.Character.HumanoidRootPart
	local lp = localOf(big.Frame, root.Position)
	check(doneWith == true and lp.Z > 40 and near(root.Position.Y, 3.2, 1e-3), `atterri dehors derrière la boutique {fmt(lp)}`)
	step(GlassThrow.HoleDuration)
	local okSame, what = same(big.Back2, before)
	check(#fires("Repair", t0) == 1 and okSame, `réparé : Pane_B rendue telle quelle (écart : {if okSame then "aucun" else what})`)
	resetWorld()
end

summary()
