--[[
	Aperçu en Edit, v6 (L-112, retours de Clément du 2026-11-12) : l'ouverture du colis, puis l'antivol.
	1. Le colis s'ouvre comme un carton : son couvercle se sépare en deux rabats qui se lèvent.
	2. Une lumière blanche sort du colis (faisceau, lumière, étincelles).
	3. La chance : « ×N LUCK » en vert avec le trèfle (l'ancienne DA, sans pastille), qui monte à
	   chaque tic (0,1 s, de plus en plus vite, rythme de la vidéo de référence). Le colis grandit
	   avec la chance : plus elle monte, plus il grossit. Sans chance, il s'ouvre tout de suite.
	4. La révélation : éclatement (famille de FX_Escape), l'objet sort à la place du colis, face à la
	   rue, blanc puis à ses couleurs ; au-dessus, BB_Item (nom, rareté, mutation, $/s).
	5. En base : au-dessus de l'objet posé, seulement un timer dans le style de BB_OpenTimer (pastille
	   sombre) avec un petit cadenas, visible de près seulement (MaxDistance 25, pas AlwaysOnTop).
	   À la fin, le cadenas saute et « UNLOCKED! » s'affiche.
	_G.OpenProto.Replay() rejoue, _G.OpenProto.Stop() retire tout. Copies dans CoreGui (_PROTO_*) et
	Workspace/_PREVIEW_ShelfOpen. Aucun script laissé.
]]

local CG = game:GetService("CoreGui")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

if _G.OpenProto then pcall(_G.OpenProto.Stop) end
for _, n in { "_PROTO_ShelfOpen", "_PROTO_HoldButton", "_PROTO_AntiTheft", "_PROTO_ItemInfo", "_PROTO_RevealTint" } do
	local o = CG:FindFirstChild(n)
	if o then o:Destroy() end
end

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local EPIC = Color3.fromHex("A855F7")
local GOLD = Color3.fromHex("ffc21a")
local LUCK_GREEN = Color3.fromHex("5cff4a")
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local SHOCKWAVE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local STREAK = "rbxassetid://108815534391966" -- RunStreak (tapis Void)
local SHAFT = "rbxassetid://136889032474760" -- rayon de ColSparkle (tapis Gold)
local STUDS = "rbxassetid://3014551673"
local ICON_LOCK = "rbxassetid://112359396081383" -- UI_Icon_Lock
local ICON_LUCK = "rbxassetid://82423065290603" -- UI_Icon_PotionLuck, en attendant une icône de trèfle

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", o, { CornerRadius = r or UDim.new(0, 10) }) end
local function label(p, name, text, color, maxSize, props)
	local t = make("TextLabel", p, { Name = name, Text = text, FontFace = FONT, TextColor3 = color, BackgroundTransparency = 1, TextScaled = true, TextWrapped = true })
	make("UITextSizeConstraint", t, { MaxTextSize = maxSize, MinTextSize = 8 })
	make("UIStroke", t, { Thickness = 2.6, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	for k, v in props or {} do t[k] = v end
	return t
end
local function scaleOf(o)
	local s = o:FindFirstChild("ProtoScale")
	if not s then s = Instance.new("UIScale"); s.Name = "ProtoScale"; s.Parent = o end
	return s
end
local function pop(o, from, t)
	local s = scaleOf(o)
	s.Scale = from
	TS:Create(s, TweenInfo.new(t or 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
local function anchorAll(m) for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end end

local cam = workspace.CurrentCamera
local function lookAt(pos, target)
	cam.CFrame = CFrame.lookAt(pos, target)
	cam.Focus = CFrame.new(target)
end

local folder = workspace:FindFirstChild("_PREVIEW_ShelfOpen") or make("Folder", workspace, { Name = "_PREVIEW_ShelfOpen" })
local store = workspace.Map.Zone_1.STORE_Z1_Superette
local slot = store:FindFirstChild("ShelfSlot_01", true)

-- objet « Big Gold Giant TV » : taille × 1,5, doré, halo violet (Epic)
local function makeItem(cf)
	local m = RS.Assets.Items.ITM_Z3_TeleGeante:Clone()
	anchorAll(m)
	m:ScaleTo(1.5)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then p.Material = Enum.Material.Foil; p.Color = GOLD end
		if p:IsA("MeshPart") then p.TextureID = "" end
		if p:IsA("SurfaceAppearance") or p:IsA("Decal") or p:IsA("Texture") then p:Destroy() end
	end
	local _, size = m:GetBoundingBox()
	m:PivotTo(cf)
	local halo = make("Highlight", m, { Name = "RarityHalo", FillColor = WHITE, FillTransparency = 0, OutlineColor = EPIC, OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.Occluded })
	local core = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	make("PointLight", core, { Name = "HaloLight", Color = EPIC, Brightness = 3, Range = 12 })
	m.Parent = folder
	return m, size, halo
end

-- billboard d'infos (copie de BB_Item + ligne Mutation)
local function itemInfo(m, size)
	local bb = RS.Assets.UI.BB_Item:Clone()
	bb.Name = "_PROTO_ItemInfo"
	bb.Adornee = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	bb.StudsOffset = Vector3.new(0, size.Y / 2 + 1.6, 0)
	bb.AlwaysOnTop = true
	local n = bb:FindFirstChild("ItemName", true); if n then n.Text = "Giant TV" end
	local r = bb:FindFirstChild("Rarity", true); if r then r.Text = "EPIC"; r.TextColor3 = EPIC end
	local inc = bb:FindFirstChild("Income", true); if inc then inc.Text = "+$7.2K/s" end
	if r and n and inc then
		bb.Size = UDim2.new(5, 120, 1.6, 62)
		local mu = r:Clone(); mu.Name = "Mutation"; mu.Text = "BIG GOLD"; mu.TextColor3 = GOLD
		n.Size = UDim2.fromScale(1, 0.29); r.Size = UDim2.fromScale(1, 0.23); mu.Size = UDim2.fromScale(1, 0.23); inc.Size = UDim2.fromScale(1, 0.25)
		n.LayoutOrder = 1; r.LayoutOrder = 2; mu.LayoutOrder = 3; inc.LayoutOrder = 4
		mu.Parent = r.Parent
	end
	bb.Parent = CG
	return bb
end

-- BB_ShelfOpen : trèfle + « ×N LUCK » en vert, contour noir, sans fond (l'ancienne DA)
local LUCK_GREEN = Color3.fromHex("5cff4a")
local function luckBoard(adornee)
	local bb = make("BillboardGui", CG, { Name = "_PROTO_ShelfOpen", Adornee = adornee, Size = UDim2.fromOffset(300, 70), StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, MaxDistance = 60, LightInfluence = 0 })
	local row = make("Frame", bb, { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	make("UIListLayout", row, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local icon = make("TextLabel", row, { Name = "LuckIcon", Text = "🍀", BackgroundTransparency = 1, TextScaled = true, Size = UDim2.fromOffset(52, 52), LayoutOrder = 1 })
	local luck = label(row, "Luck", "×1.00 LUCK", LUCK_GREEN, 44, { Size = UDim2.fromOffset(236, 60), LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left })
	return bb, luck, row, icon
end

-- BB_AntiTheft : timer dans le style de BB_OpenTimer (pastille sombre 3a404b), petit cadenas à gauche,
-- visible de près seulement
local function antiTheft(adornee, height)
	local at = make("BillboardGui", CG, { Name = "_PROTO_AntiTheft", Adornee = adornee, Size = UDim2.new(2.6, 60, 0.8, 22), StudsOffset = Vector3.new(0, height, 0), AlwaysOnTop = false, MaxDistance = 25, LightInfluence = 0 })
	local pillF = make("Frame", at, { Name = "Pill", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("3a404b"), BackgroundTransparency = 0.05 })
	corner(pillF, UDim.new(0.5, 0))
	make("UIStroke", pillF, { Thickness = 0.08, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local lock = make("ImageLabel", at, { Name = "Lock", Image = ICON_LOCK, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.16, 0.5), Size = UDim2.fromScale(0.26, 1.25), ZIndex = 3 })
	make("UIAspectRatioConstraint", lock, { AspectRatio = 1 })
	local timeL = make("TextLabel", at, { Name = "Label", Text = "0:10", FontFace = FONT, TextColor3 = WHITE, BackgroundTransparency = 1, TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.32, 0.5), Size = UDim2.fromScale(0.62, 0.8), ZIndex = 3 })
	make("UIStroke", timeL, { Thickness = 0.1, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	return at, lock, timeL
end

-- éclatement de la révélation, dans la famille de FX_Escape : onde au sol, confettis, étoiles,
-- traits blancs, faisceau d'en haut, éclair de lumière ; à partir d'Épique, l'écran se teinte
local function burst(at, rarityColor)
	local p = make("Part", folder, { Name = "Burst", Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at) })
	local a0 = make("Attachment", p, { Name = "Center" })
	local ground = make("Attachment", p, { Name = "Ground", Position = Vector3.new(0, -0.55, 0) })
	make("ParticleEmitter", ground, { Name = "Ring", Texture = SHOCKWAVE, Color = ColorSequence.new(rarityColor, WHITE), LightEmission = 1, Size = NumberSequence.new(1.5, 13), Transparency = NumberSequence.new(0.1, 1), Speed = NumberRange.new(0), Lifetime = NumberRange.new(0.55), Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top, Rate = 0 }):Emit(1)
	make("ParticleEmitter", a0, { Name = "Streaks", Texture = STREAK, Color = ColorSequence.new(WHITE), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }), Squash = NumberSequence.new(2), Orientation = Enum.ParticleOrientation.VelocityParallel, Speed = NumberRange.new(26, 38), SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(0.22, 0.4), Drag = 5, Rate = 0 }):Emit(34)
	make("ParticleEmitter", a0, { Name = "Confetti", Texture = SQUARE, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("ffd84a")), ColorSequenceKeypoint.new(0.5, rarityColor), ColorSequenceKeypoint.new(1, Color3.fromHex("4fd2ff")) }), Size = NumberSequence.new(0.35, 0.25), Speed = NumberRange.new(16, 26), SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -28, 0), Lifetime = NumberRange.new(1, 1.6), RotSpeed = NumberRange.new(-360, 360), Rotation = NumberRange.new(0, 360), Rate = 0 }):Emit(60)
	make("ParticleEmitter", a0, { Name = "Stars", Texture = SPARKLE, Color = ColorSequence.new(Color3.fromHex("fff2a8"), rarityColor:Lerp(WHITE, 0.3)), LightEmission = 0.9, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(7, 14), SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(0.5, 0.9), Drag = 2, RotSpeed = NumberRange.new(-180, 180), Rate = 0 }):Emit(22)
	local light = make("PointLight", p, { Name = "Flash", Color = rarityColor:Lerp(WHITE, 0.4), Brightness = 9, Range = 20 })
	TS:Create(light, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	local top = make("Attachment", p, { Name = "Top", Position = Vector3.new(0, 24, 0) })
	local bottom = make("Attachment", p, { Name = "Bottom", Position = Vector3.new(0, -0.5, 0) })
	local beam = make("Beam", p, { Name = "Shaft", Attachment0 = top, Attachment1 = bottom, Texture = SHAFT, TextureMode = Enum.TextureMode.Stretch, Width0 = 6, Width1 = 3.4, FaceCamera = true, LightEmission = 1, Color = ColorSequence.new(rarityColor:Lerp(WHITE, 0.35)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.3), NumberSequenceKeypoint.new(1, 0.1) }), Segments = 1 })
	task.delay(0.55, function()
		local t0 = os.clock()
		while beam.Parent and os.clock() - t0 < 0.6 do
			local q = (os.clock() - t0) / 0.6
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.3 + 0.7 * q), NumberSequenceKeypoint.new(1, 0.1 + 0.9 * q) })
			task.wait()
		end
		beam.Enabled = false
	end)
	local g = make("ScreenGui", CG, { Name = "_PROTO_RevealTint", IgnoreGuiInset = true, DisplayOrder = 60 })
	local f = make("Frame", g, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rarityColor, BackgroundTransparency = 0.62, BorderSizePixel = 0 })
	make("UIGradient", f, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0.2) }) })
	TS:Create(f, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.delay(0.65, function() g:Destroy() end)
	return p
end

local running, made = true, {}
local status = {}
local LUCK_MAX = 3.2 -- aperçu : chance finale de la démo (en jeu, celle du serveur)

-- couvercle en deux rabats (aperçu : le couvercle du modèle est caché, deux rabats le remplacent ;
-- pour le vrai modèle, Clément ajoute deux pièces FlapL et FlapR dans BOX_*/Lid)
local function makeFlaps(box)
	local lid = box:FindFirstChild("Lid")
	local slab = lid and lid:FindFirstChild("Slab")
	if not slab then return nil end
	local w, t, d = slab.Size.X, slab.Size.Y, slab.Size.Z
	local flaps = {}
	for i, side in { -1, 1 } do
		local f = make("Part", box, { Name = i == 1 and "FlapL" or "FlapR", Anchored = true, CanCollide = false, Size = Vector3.new(w / 2, t, d), Color = slab.Color, Material = slab.Material, TopSurface = Enum.SurfaceType.Smooth })
		-- charnière : le bord extérieur du rabat
		local hinge = slab.CFrame * CFrame.new(side * w / 2, 0, 0)
		f.CFrame = hinge * CFrame.new(-side * w / 4, 0, 0)
		table.insert(flaps, { part = f, hinge = hinge, side = side, offset = CFrame.new(-side * w / 4, 0, 0) })
	end
	for _, d2 in lid:GetDescendants() do if d2:IsA("BasePart") then d2.Transparency = 1 end end
	return flaps
end

local function play()
	folder:ClearAllChildren()
	for _, o in made do if o.Parent then o:Destroy() end end
	table.clear(made)

	local box = RS.Assets.Boxes.BOX_Rare:Clone()
	anchorAll(box)
	local home = CFrame.new(slot.WorldPosition)
	box:PivotTo(home)
	box.Parent = folder
	local core = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart", true)
	local toStreet = Vector3.new(0, 0, -math.sign((store:FindFirstChild("Window", true) :: any):GetPivot().Position.Z))
	lookAt(slot.WorldPosition + Vector3.new(5, 3, -5), slot.WorldPosition + Vector3.new(0, 1.6, 0))
	task.wait(0.4)

	-- 1. le couvercle s'ouvre en deux rabats qui se lèvent (0,35 s, Back Out)
	local flaps = makeFlaps(box) or {}
	local t0 = os.clock()
	while running and os.clock() - t0 < 0.35 do
		local q = TS:GetValue((os.clock() - t0) / 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for _, f in flaps do f.part.CFrame = f.hinge * CFrame.Angles(0, 0, -f.side * math.rad(115) * q) * f.offset end
		task.wait()
	end
	if not running then return end

	-- 2. une lumière blanche sort du colis
	local mouth = make("Attachment", core, { Name = "Mouth", Position = Vector3.new(0, core.Size.Y / 2, 0) })
	local up = make("Attachment", core, { Name = "Up", Position = Vector3.new(0, core.Size.Y / 2 + 7, 0) })
	local shaft = make("Beam", core, { Name = "InnerLight", Attachment0 = mouth, Attachment1 = up, Texture = SHAFT, TextureMode = Enum.TextureMode.Stretch, Width0 = 1.2, Width1 = 3.4, FaceCamera = true, LightEmission = 1, Color = ColorSequence.new(WHITE), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }), Segments = 1 })
	local glow = make("ParticleEmitter", mouth, { Name = "Sparkles", Texture = SPARKLE, Color = ColorSequence.new(WHITE, Color3.fromHex("fff2a8")), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.5, 0.9), Rate = 14 })
	local light = make("PointLight", core, { Name = "InnerGlow", Color = WHITE, Brightness = 0, Range = 9 })
	TS:Create(light, TweenInfo.new(0.25), { Brightness = 3 }):Play()
	task.wait(0.3)

	-- 3. la chance : « ×N LUCK » monte à chaque tic, le colis grandit avec elle
	local bb, luck, row, icon = luckBoard(core)
	table.insert(made, bb)
	pop(row, 0, 0.25)
	local value, ticks = 1, 0
	local TICK = 0.1
	local t1 = os.clock()
	while running and value < LUCK_MAX do
		local e = os.clock() - t1
		local n = math.floor(e / TICK)
		if n ~= ticks then
			ticks = n
			value = math.min(LUCK_MAX, value * 1.03)
			luck.Text = string.format("×%.2f LUCK", value)
			pop(row, 1.12, 0.1)
			icon.Rotation = math.sin(n) * 10
		end
		local k = (value - 1) / (LUCK_MAX - 1) -- 0 sans chance, 1 au plus haut
		local beat = 1 + 0.04 * math.max(0, math.cos((e % TICK) / TICK * math.pi))
		box:ScaleTo((1 + 0.6 * k) * beat)
		box:PivotTo(home * CFrame.new(math.sin(e * 53) * 0.02 * k, 0, math.cos(e * 47) * 0.02 * k))
		shaft.Width1 = 3.4 + 3 * k
		light.Brightness = 3 + 4 * k
		glow.Rate = 14 + 40 * k
		task.wait()
	end
	if not running then return end

	-- 4. révélation : éclatement, l'objet sort à la place du colis, face à la rue
	local center = core.Position + Vector3.new(0, 0.6, 0)
	for _, d in box:GetDescendants() do if d:IsA("BasePart") then d.Transparency = 1 end end
	shaft.Enabled = false; glow.Enabled = false; light.Enabled = false
	TS:Create(scaleOf(bb), TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
	burst(center, EPIC)
	status.opened = true
	status.luck = value

	local place = CFrame.lookAt(slot.WorldPosition, slot.WorldPosition + toStreet)
	local item, size, halo = makeItem(place)
	local pivot = item:GetPivot()
	item:ScaleTo(1.5 * 0.2)
	local t2 = os.clock()
	while running and os.clock() - t2 < 0.35 do
		local q = (os.clock() - t2) / 0.35
		local s2 = 0.2 + (1.15 - 0.2) * TS:GetValue(q, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		item:ScaleTo(1.5 * s2); item:PivotTo(pivot)
		task.wait()
	end
	item:ScaleTo(1.5); item:PivotTo(pivot)
	TS:Create(halo, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 0.82, FillColor = EPIC }):Play()
	local info = itemInfo(item, size)
	table.insert(made, info)
	pop(info, 0, 0.3)
	status.revealed = true
	status.facing = item:GetPivot().LookVector
	task.wait(3.5)
	if not running then return end

	-- 5. en base : posé au sol, face à l'entrée ; timer d'antivol visible de près
	if info.Parent then info:Destroy() end
	local floorPos = Vector3.new(-106, 0.4, 185)
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(floorPos + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
	if hit then floorPos = hit.Position end
	item:PivotTo(CFrame.lookAt(floorPos, floorPos + Vector3.new(1, 0, 0)))
	lookAt(floorPos + Vector3.new(8, 5, 0), floorPos + Vector3.new(0, 2, 0))
	local at, lock, timeL = antiTheft(item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true), size.Y / 2 + 1.6)
	table.insert(made, at)
	status.base = true
	for left = 10, 1, -1 do
		if not running then return end
		timeL.Text = string.format("0:%02d", left)
		task.wait(1)
	end
	timeL.Text = "UNLOCKED!"; timeL.TextColor3 = LUCK_GREEN
	pop(timeL, 1.35, 0.3)
	TS:Create(scaleOf(lock), TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.4 }):Play()
	TS:Create(lock, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.16, 10, 0.5, -34), Rotation = 35, ImageTransparency = 1 }):Play()
	status.done = true
end

_G.OpenProto = {
	Replay = function() running = true; task.spawn(play) end,
	Stop = function()
		running = false
		for _, o in made do if o.Parent then o:Destroy() end end
		local t = CG:FindFirstChild("_PROTO_RevealTint"); if t then t:Destroy() end
		if folder.Parent then folder:Destroy() end
		_G.OpenProto = nil
	end,
	Status = status,
}
task.spawn(play)
return "déroulé v6 lancé"
