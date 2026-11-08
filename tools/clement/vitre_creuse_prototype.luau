-- Prototype v3 validé par Clément le 2026-11-08 : « la vitre se creuse à chaque coup », sans latence pour celui qui frappe.
-- Injecté en Play côté client (execute_luau) pour le montrer : à intégrer par Ironix dans ShatterController (référence, pas du code du jeu).
-- À chaque coup validé (Remotes.WindowHit) : éclair, paillettes et nuage au point d'impact, puis
-- GeometryService:FragmentAsync arrache des éclats dans la face frappée : un creux en cuvette, plus large et
-- plus profond à chaque coup (selon les dégâts), qui ne perce jamais la vitre (88 % de l'épaisseur au plus) ;
-- les éclats arrachés partent surtout vers celui qui frappe. Les étoiles de fissure (images) sont masquées.
-- La casse finale du jeu (WindowBroken) n'est pas touchée : notre verre creusé disparaît juste avant.
local GS = game:GetService("GeometryService")
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local old = _G.VITRE
if old and old.stop then
	pcall(old.stop)
end

local CFG = {
	R0 = 0.6, RGrow = 1.6, PerHit = 0.1, RMax = 2.6, -- rayon du creux (studs)
	DepthMin = 0.22, DepthGrow = 0.68, DepthPerHit = 0.04, DepthMax = 0.88, -- profondeur, en part de l'épaisseur
	Bowl = 0.65, -- creux en cuvette : bord à 35 % de la profondeur du centre
	SitesPerArea = 5, MinSites = 8, MaxSites = 26,
	OutShare = 0.85, -- part des éclats qui sortent vers celui qui frappe
	Speed = { 6, 13 }, Up = { 3, 7 }, Side = { 1, 4 }, Spin = { 8, 22 },
	Life = 1.4, Fade = 0.5, MaxDebris = 150,
	Sparkles = 24, Puff = 5, FlashBrightness = 4, FlashRange = 10,
	FullHealDelay = 2,
}

local P = { conns = {}, states = {}, debris = {}, hp = {}, cfg = CFG, log = {} }
_G.VITRE = P
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "_PROTO_VITRE_CLAUDE"
folder.Parent = workspace
P.folder = folder

local function sparkleTexture(): string
	local assets = RS:FindFirstChild("Assets")
	local fx = assets and assets:FindFirstChild("FX")
	local d = fx and fx:FindFirstChild("FX_GlassSparkle")
	if d and d:IsA("Decal") and d.Texture ~= "" then
		return d.Texture
	end
	return "rbxasset://textures/particles/sparkles_main.dds"
end
local SPARKLE = sparkleTexture()

local function findWindow(windowId)
	for _, tag in { "NPCStore", "PlayerPlot" } do
		for _, m in CS:GetTagged(tag) do
			local w = m:FindFirstChild("Window")
			if w and w:IsA("BasePart") and w:GetAttribute("WindowId") == windowId then
				return w
			end
		end
	end
	return nil
end

local function setGlassProps(part, w)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = w.Material
	part.Color = w.Color
	part.Transparency = w.Transparency
	part.Reflectance = w.Reflectance
	part.CastShadow = false
end

function P.reset(windowId)
	local st = P.states[windowId]
	if not st then return end
	P.states[windowId] = nil
	for _, piece in st.pieces do piece:Destroy() end
	if st.conn then st.conn:Disconnect() end
	if st.window and st.window.Parent then st.window.LocalTransparencyModifier = 0 end
end

local function newState(windowId, w)
	local proxy = Instance.new("Part")
	proxy.Name = "Vitre_" .. tostring(windowId)
	proxy.Size = w.Size
	proxy.CFrame = w.CFrame
	setGlassProps(proxy, w)
	proxy.Parent = folder
	w.LocalTransparencyModifier = 1
	local st = { window = w, cf = w.CFrame, size = w.Size, pieces = { proxy }, radius = 0, depth = 0, busy = false, queue = {}, lastHit = os.clock() }
	st.conn = w:GetAttributeChangedSignal("Broken"):Connect(function()
		if w:GetAttribute("Broken") ~= true then P.reset(windowId) end
	end)
	P.states[windowId] = st
	return st
end

local function outwardOf(st, point)
	local n = st.cf.LookVector
	return if (point - st.cf.Position):Dot(n) >= 0 then n else -n
end

local function burst(point, outward)
	local holder = Instance.new("Part")
	holder.Name = "Impact"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.lookAt(point + outward * 0.15, point + outward * 2)
	holder.Parent = folder
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = SPARKLE
	sp.EmissionDirection = Enum.NormalId.Front
	sp.SpreadAngle = Vector2.new(75, 75)
	sp.Speed = NumberRange.new(8, 18)
	sp.Lifetime = NumberRange.new(0.35, 0.75)
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(1, 0) })
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 225, 255))
	sp.LightEmission = 0.7
	sp.Acceleration = Vector3.new(0, -45, 0)
	sp.Drag = 2
	sp.Rotation = NumberRange.new(0, 360)
	sp.RotSpeed = NumberRange.new(-360, 360)
	sp.Rate = 0
	sp.Parent = holder
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.EmissionDirection = Enum.NormalId.Front
	puff.SpreadAngle = Vector2.new(50, 50)
	puff.Speed = NumberRange.new(2, 6)
	puff.Lifetime = NumberRange.new(0.3, 0.5)
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 3.2) })
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	puff.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
	puff.LightEmission = 0.4
	puff.Rate = 0
	puff.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(220, 240, 255)
	light.Brightness = CFG.FlashBrightness
	light.Range = CFG.FlashRange
	light.Parent = holder
	sp:Emit(CFG.Sparkles)
	puff:Emit(CFG.Puff)
	TweenService:Create(light, TweenInfo.new(0.18), { Brightness = 0 }):Play()
	task.delay(1.2, function() holder:Destroy() end)
end

-- Points de découpe pour un creux en cuvette dans la face frappée (côté s) :
-- chaque éclat a un point à mi-profondeur et un « plancher » deux fois plus bas (groupe 1, la vitre),
-- donc le fond du creux passe à la profondeur voulue ; un anneau autour borde le creux.
local function buildCarveSites(st, lx, ly, r, D, s)
	local cf, size, t = st.cf, st.size, st.size.Z
	local z0 = s * t / 2
	local sites = { {} }
	local outer = sites[1]
	local n = math.clamp(math.floor(r * r * CFG.SitesPerArea + 0.5), CFG.MinSites, CFG.MaxSites)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = r * math.sqrt(rng:NextNumber())
		local Di = D * (1 - CFG.Bowl * (d / r) ^ 2) * rng:NextNumber(0.85, 1.1)
		Di = math.min(Di, t * 0.93)
		local x, y = lx + d * math.cos(a), ly + d * math.sin(a)
		table.insert(sites, cf:PointToWorldSpace(Vector3.new(x, y, z0 - s * Di * 0.45)))
		table.insert(outer, cf:PointToWorldSpace(Vector3.new(x + rng:NextNumber(-0.04, 0.04), y + rng:NextNumber(-0.04, 0.04), z0 - s * Di * 1.55)))
	end
	local ring = math.clamp(math.floor(r * 8 + 0.5), 10, 24)
	local rot = rng:NextNumber(0, math.pi * 2)
	local zr = z0 - s * D * (1 - CFG.Bowl) * 0.45
	for i = 1, ring do
		local a = rot + (i + rng:NextNumber(-0.35, 0.35)) / ring * math.pi * 2
		local d = r * rng:NextNumber(1.3, 1.6)
		table.insert(outer, cf:PointToWorldSpace(Vector3.new(lx + d * math.cos(a), ly + d * math.sin(a), zr)))
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		table.insert(outer, cf:PointToWorldSpace(Vector3.new(c[1] * size.X, c[2] * size.Y, 0)))
	end
	return sites
end

local function touchesFrame(st, piece)
	local hx, hy = st.size.X / 2 - 0.08, st.size.Y / 2 - 0.08
	local half = piece.Size / 2
	for i = 0, 7 do
		local corner = piece.CFrame:PointToWorldSpace(Vector3.new(
			if i % 2 == 0 then -half.X else half.X,
			if (i // 2) % 2 == 0 then -half.Y else half.Y,
			if i // 4 == 0 then -half.Z else half.Z
		))
		local l = st.cf:PointToObjectSpace(corner)
		if math.abs(l.X) >= hx or math.abs(l.Y) >= hy then return true end
	end
	return false
end

local function launch(chip, center, outward, soft)
	chip.Anchored = false
	chip.CanCollide = true
	chip.CanQuery = false
	chip.CanTouch = false
	chip.CastShadow = false
	chip.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.4, 0.3)
	chip.Parent = folder
	local side = if rng:NextNumber() < CFG.OutShare then outward else -outward
	local radial = chip.Position - center
	radial -= outward * radial:Dot(outward)
	radial = if radial.Magnitude > 1e-3 then radial.Unit else Vector3.zero
	local k = if soft then 0.25 else 1
	chip.AssemblyLinearVelocity = side * rng:NextNumber(CFG.Speed[1], CFG.Speed[2]) * k
		+ radial * rng:NextNumber(CFG.Side[1], CFG.Side[2]) * k
		+ Vector3.new(0, rng:NextNumber(CFG.Up[1], CFG.Up[2]) * k, 0)
	chip.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(CFG.Spin[1], CFG.Spin[2])
	table.insert(P.debris, chip)
	while #P.debris > CFG.MaxDebris do
		local oldest = table.remove(P.debris, 1)
		if oldest then oldest:Destroy() end
	end
	task.delay(CFG.Life, function()
		if chip.Parent then
			TweenService:Create(chip, TweenInfo.new(CFG.Fade), { Transparency = 1 }):Play()
			task.delay(CFG.Fade, function() chip:Destroy() end)
		end
	end)
end

local function process(windowId, st, point)
	local w = st.window
	local lp = st.cf:PointToObjectSpace(point)
	local s = if lp.Z >= 0 then 1 else -1
	local hx, hy = st.size.X / 2, st.size.Y / 2
	local lx = math.clamp(lp.X, -hx + 0.3, hx - 0.3)
	local ly = math.clamp(lp.Y, -hy + 0.3, hy - 0.3)
	local dmg = math.clamp(1 - (P.hp[windowId] or 1), 0, 1)
	local r = math.min(math.max(CFG.R0 + CFG.RGrow * dmg ^ 0.8, st.radius + CFG.PerHit), CFG.RMax)
	local t = st.size.Z
	local D = math.clamp(CFG.DepthMin + CFG.DepthGrow * dmg ^ 0.9, CFG.DepthMin, CFG.DepthMax) * t
	D = math.min(math.max(D, st.depth + CFG.DepthPerHit * t), CFG.DepthMax * t)
	st.radius, st.depth = r, D
	local center = st.cf:PointToWorldSpace(Vector3.new(lx, ly, s * t / 2))
	local outward = outwardOf(st, point)
	local sites = buildCarveSites(st, lx, ly, r, D, s)
	local kept, chips = {}, {}
	local t0 = os.clock()
	for _, piece in st.pieces do
		local rel = piece.CFrame:PointToObjectSpace(center)
		local half = piece.Size / 2 + Vector3.one * (1.7 * r)
		if math.abs(rel.X) > half.X or math.abs(rel.Y) > half.Y or math.abs(rel.Z) > half.Z then
			table.insert(kept, piece)
			continue
		end
		local ok, res = pcall(function()
			return GS:FragmentAsync(piece, sites, { CollisionFidelity = Enum.CollisionFidelity.Box })
		end)
		if not ok or not res then
			table.insert(kept, piece)
			table.insert(P.log, "FragmentAsync : " .. tostring(res))
			continue
		end
		for _, item in res do
			local inst = item.Instance
			if item.Index == 1 then
				setGlassProps(inst, w)
				inst.Parent = folder
				table.insert(kept, inst)
			else
				table.insert(chips, inst)
			end
		end
		piece:Destroy()
	end
	local attached, falling = {}, 0
	for _, k in kept do
		if touchesFrame(st, k) then
			table.insert(attached, k)
		else
			falling += 1
			launch(k, center, outward, true)
		end
	end
	st.pieces = attached
	for _, c in chips do launch(c, center, outward, false) end
	table.insert(P.log, string.format("%s coup r=%.2f prof=%.2f : %d gardés, %d éclats, %d îlots, %.0f ms", tostring(windowId), r, D, #attached, #chips, falling, (os.clock() - t0) * 1000))
end

local function hitWindow(windowId, w, point)
	if w:GetAttribute("Broken") == true then return end
	local st = P.states[windowId] or newState(windowId, w)
	st.lastHit = os.clock()
	burst(point, outwardOf(st, point))
	table.insert(st.queue, point)
	if st.busy then return end
	st.busy = true
	while #st.queue > 0 and P.states[windowId] == st do
		local p = table.remove(st.queue, 1)
		local ok, err = pcall(process, windowId, st, p)
		if not ok then table.insert(P.log, "erreur : " .. tostring(err)) end
	end
	st.busy = false
end
P.hitWindow = hitWindow
P.findWindow = findWindow

local function onBroken(windowId)
	local st = P.states[windowId]
	if st then
		for _, piece in st.pieces do piece:Destroy() end
		st.pieces = {}
		table.insert(P.log, tostring(windowId) .. " cassée : la casse du jeu prend le relais")
	end
end

local function hideStar(inst)
	if inst:IsA("SurfaceGui") then inst.Enabled = false end
end
local function watchShatterFx(f)
	for _, d in f:GetDescendants() do hideStar(d) end
	table.insert(P.conns, f.DescendantAdded:Connect(hideStar))
end

function P.stop()
	for _, c in P.conns do c:Disconnect() end
	for id in P.states do P.reset(id) end
	for _, d in P.debris do d:Destroy() end
	folder:Destroy()
	local sfx = workspace:FindFirstChild("_ShatterFX")
	if sfx then
		for _, d in sfx:GetDescendants() do
			if d:IsA("SurfaceGui") then d.Enabled = true end
		end
	end
	if _G.VITRE == P then _G.VITRE = nil end
end

-- v3 : sans latence pour celui qui frappe. Son coup est creusé tout de suite, au marqueur Impact de
-- son animation, au point que calcule aussi le jeu (HitController : vitrine la plus proche devant
-- lui, à 8 studs au plus, point de sa boîte le plus proche du personnage). L'écho du serveur
-- (WindowHit, hitter = lui) est alors ignoré ; les coups des autres joueurs suivent l'écho.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RANGE, FRONT_MIN_DOT, MIN_INTERVAL, ECHO_WINDOW = 8, 0, 0.1, 1.5
P.pendingLocal = {}
local lastActivated = 0

local function closestPoint(cf, size, point)
	local p = cf:PointToObjectSpace(point)
	local h = size / 2
	return cf:PointToWorldSpace(Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z)))
end

local function predictTarget(root)
	local origin = root.Position
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local bestId, bestW, bestPoint, bestD = nil, nil, nil, RANGE
	for _, tag in { "NPCStore", "PlayerPlot" } do
		for _, m in CS:GetTagged(tag) do
			local w = m:FindFirstChild("Window")
			if not (w and w:IsA("BasePart")) then continue end
			local id, maxHP = w:GetAttribute("WindowId"), w:GetAttribute("MaxHP")
			if type(id) ~= "string" or type(maxHP) ~= "number" or maxHP <= 0 or w:GetAttribute("Broken") == true then continue end
			if tag == "PlayerPlot" and m:GetAttribute("OwnerUserId") == player.UserId then continue end
			local p = closestPoint(w.CFrame, w.Size, origin)
			local off = p - origin
			local d = off.Magnitude
			if d > bestD then continue end
			local flat = Vector3.new(off.X, 0, off.Z)
			if flat.Magnitude > 0.01 and flatLook.Magnitude > 0.01 and flat.Unit:Dot(flatLook.Unit) < FRONT_MIN_DOT then continue end
			bestId, bestW, bestPoint, bestD = id, w, p, d
		end
	end
	return bestId, bestW, bestPoint
end

local function onLocalImpact(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local id, w, point = predictTarget(root)
	if id and w and point then
		P.pendingLocal[id] = P.pendingLocal[id] or {}
		table.insert(P.pendingLocal[id], os.clock())
		task.spawn(hitWindow, id, w, point)
	end
end

local hooked = {}
local function hookTool(tool)
	if not tool:IsA("Tool") or hooked[tool] then return end
	hooked[tool] = true
	table.insert(P.conns, tool.Activated:Connect(function()
		if tool:GetAttribute("ToolId") == nil or tool:GetAttribute("BatTool") then return end
		local now = os.clock()
		if now - lastActivated < MIN_INTERVAL then return end
		lastActivated = now
		local character = player.Character
		if not character or tool.Parent ~= character then return end
		local fired = false
		local function go()
			if fired then return end
			fired = true
			onLocalImpact(character)
		end
		task.defer(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if not animator then return end
			for _, track in animator:GetPlayingAnimationTracks() do
				local name = if track.Animation then track.Animation.Name else ""
				if name == "HitWindow" or name == "HitWindowHeavy" then
					local ok, signal = pcall(function() return track:GetMarkerReachedSignal("Impact") end)
					if ok and signal then
						local c
						c = signal:Connect(function()
							c:Disconnect()
							go()
						end)
						task.delay(0.35, function() if c.Connected then c:Disconnect() end end)
					end
				end
			end
		end)
		task.delay(0.3, go) -- comme le jeu : au plus tard 0,3 s après le clic
	end))
end
local function hookContainer(container)
	if not container then return end
	for _, c in container:GetChildren() do hookTool(c) end
	table.insert(P.conns, container.ChildAdded:Connect(hookTool))
end
hookContainer(player:FindFirstChildOfClass("Backpack"))
hookContainer(player.Character)
table.insert(P.conns, player.CharacterAdded:Connect(function(character)
	hookContainer(character)
	hookContainer(player:WaitForChild("Backpack", 5))
end))

local remotes = RS:WaitForChild("Remotes", 20)
local hitRE = remotes and remotes:FindFirstChild("WindowHit")
local brokenRE = remotes and remotes:FindFirstChild("WindowBroken")
local hpRE = remotes and remotes:FindFirstChild("WindowHP")
if not (hitRE and brokenRE and hpRE) then
	return "Remotes introuvables"
end
table.insert(P.conns, hitRE.OnClientEvent:Connect(function(windowId, point, hitter)
	local w = findWindow(windowId)
	if not (w and typeof(point) == "Vector3") then return end
	if hitter == player then
		local list = P.pendingLocal[windowId]
		if list then
			local now = os.clock()
			while #list > 0 and now - list[1] > ECHO_WINDOW do table.remove(list, 1) end
			if #list > 0 then
				table.remove(list, 1)
				return -- déjà creusé à l'impact
			end
		end
	end
	task.spawn(hitWindow, windowId, w, point)
end))
table.insert(P.conns, brokenRE.OnClientEvent:Connect(onBroken))
table.insert(P.conns, hpRE.OnClientEvent:Connect(function(windowId, hp, maxHp)
	if type(hp) == "number" and type(maxHp) == "number" and maxHp > 0 then
		local f = math.clamp(hp / maxHp, 0, 1)
		P.hp[windowId] = f
		local st = P.states[windowId]
		if st and f >= 0.999 and not st.busy and os.clock() - st.lastHit > CFG.FullHealDelay then
			P.reset(windowId)
		end
	end
end))
local sfx = workspace:FindFirstChild("_ShatterFX")
if sfx then watchShatterFx(sfx) end
table.insert(P.conns, workspace.ChildAdded:Connect(function(c)
	if c.Name == "_ShatterFX" then watchShatterFx(c) end
end))
return "prototype v3 (creux, sans latence pour celui qui frappe) actif"
