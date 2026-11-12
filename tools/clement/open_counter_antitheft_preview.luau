--[[
	Aperçu en Edit, v5 (L-112, 2026-11-12 ; DA du jeu : pastilles à studs, vraies icônes, effets de la famille FX_Escape) : l'ouverture du colis d'après la vidéo de référence de
	Clément (docs/claude/notes/ui-reference-ouverture-oeuf.md), puis l'antivol en base.
	1. Les secousses (2 s) : le colis Rare du rayon de STORE_Z1_Superette gigote, et sa couleur part
	   vers le blanc à chaque secousse.
	2. La chance (4 s) : le colis devient une silhouette blanche unie, grossit de 1 à 1,3 et palpite à
	   chaque tic. Au-dessus, BB_ShelfOpen : trèfle + « ×1.00 LUCK », qui monte de 3 % à chaque tic
	   (toutes les 0,1 s : la montée accélère). En jeu, le tic sonne en même temps, une note qui monte
	   d'une octave (Edit ne joue pas les sons).
	3. La révélation (1 s) : une image aux vraies couleurs, puis l'éclatement (traits blancs, étoiles
	   de couleur, faisceau de lumière d'en haut à la couleur de la rareté, écran teinté pour Épique et
	   plus). L'objet sort à la place du colis, tout blanc, puis prend ses couleurs (pop 0 → 1,15 → 1).
	   Au-dessus : BB_Item avec le nom, la rareté, la mutation et le $/s.
	4. En base, posé au sol dans PLOT_Shop_01 : l'antivol bloque l'objet 10 s (« UNLOCKING », cadenas,
	   anneau, temps), puis le cadenas saute et « UNLOCKED! » s'affiche.
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

-- BB_ShelfOpen v4 : pastille verte à studs (style des boutons), icône de chance, « ×N LUCK »
local LUCK_STEPS = { { 1, "91f630", "31dd22" }, { 2, "ffe45c", "ff9a1a" }, { 3, "ff9a1a", "ff3b5c" } }
local function pill(parent, name, a, b)
	local shadow = make("Frame", parent, { Name = name .. "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.55, ZIndex = 1 })
	corner(shadow, UDim.new(0.5, 0))
	local f = make("Frame", parent, { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 2 })
	corner(f, UDim.new(0.5, 0))
	make("UIStroke", f, { Thickness = 3, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local g = make("UIGradient", f, { Rotation = 90, Color = ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b)) })
	local st = make("ImageLabel", f, { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = STUDS, ImageTransparency = 0.72, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(34, 34), ZIndex = 2 })
	corner(st, UDim.new(0.5, 0))
	return f, g
end
local function luckBoard(adornee)
	local bb = make("BillboardGui", CG, { Name = "_PROTO_ShelfOpen", Adornee = adornee, Size = UDim2.fromOffset(250, 84), StudsOffset = Vector3.new(0, 3.6, 0), AlwaysOnTop = true, MaxDistance = 60, LightInfluence = 0 })
	local holder = make("Frame", bb, { Name = "LuckPill", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 14, 0.5, 0), Size = UDim2.new(1, -40, 0, 56), BackgroundTransparency = 1 })
	local body, grad = pill(holder, "Pill", "91f630", "31dd22")
	local luck = label(body, "Luck", "×1.00 LUCK", WHITE, 40, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 46, 0.5, 0), Size = UDim2.new(1, -58, 0.78, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	local icon = make("ImageLabel", bb, { Name = "LuckIcon", BackgroundTransparency = 1, Image = ICON_LUCK, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 0.5, 0), Size = UDim2.fromOffset(78, 78), Rotation = -10, ZIndex = 5, ScaleType = Enum.ScaleType.Fit })
	return bb, luck, holder, grad, icon
end

-- antivol : déverrouillage (BB_AntiTheft), pastille d'état + anneau + cadenas du jeu
local function antiTheft(adornee, height)
	local at = make("BillboardGui", CG, { Name = "_PROTO_AntiTheft", Adornee = adornee, Size = UDim2.fromOffset(150, 186), StudsOffset = Vector3.new(0, height, 0), AlwaysOnTop = true, MaxDistance = 90, LightInfluence = 0 })
	local tagHolder = make("Frame", at, { Name = "Tag", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(140, 34), BackgroundTransparency = 1 })
	local tagBody, tagGrad = pill(tagHolder, "TagPill", "ffc23a", "ff7a00")
	local tag = label(tagBody, "TagLabel", "UNLOCKING", WHITE, 22, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 0.76, 0), ZIndex = 4 })
	local ring = make("Frame", at, { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(112, 112), BackgroundTransparency = 1 })
	local disc = make("Frame", ring, { Name = "Disc", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = Color3.fromHex("1b1f27"), BackgroundTransparency = 0.15, ZIndex = 1 })
	corner(disc, UDim.new(1, 0)); make("UIStroke", disc, { Thickness = 3, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local segs = {}
	for i = 1, 10 do
		local a = math.rad((i - 1) * 36)
		local s = make("Frame", ring, { Name = string.format("Seg_%02d", i), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(a) * 46, 0.5, -math.cos(a) * 46), Size = UDim2.fromOffset(15, 26), Rotation = (i - 1) * 36, BackgroundColor3 = WHITE, ZIndex = 2 })
		corner(s, UDim.new(1, 0))
		make("UIStroke", s, { Thickness = 2.5, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		make("UIGradient", s, { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("ffd84a"), Color3.fromHex("ff7a00")) })
		segs[i] = s
	end
	local lock = make("ImageLabel", ring, { Name = "Lock", Image = ICON_LOCK, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(54, 54), ZIndex = 3 })
	local timeL = label(at, "TimeLabel", "0:10", WHITE, 30, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 154), Size = UDim2.new(1, 0, 0, 32) })
	return at, tag, segs, lock, timeL, tagGrad
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
local function play()
	folder:ClearAllChildren()
	for _, o in made do if o.Parent then o:Destroy() end end
	table.clear(made)

	local box = RS.Assets.Boxes.BOX_Rare:Clone()
	anchorAll(box)
	local home = CFrame.new(slot.WorldPosition)
	box:PivotTo(home)
	box.Parent = folder
	local white = make("Highlight", box, { Name = "WhiteOut", FillColor = WHITE, FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded })
	local core = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart", true)
	lookAt(slot.WorldPosition + Vector3.new(5, 3, -5), slot.WorldPosition + Vector3.new(0, 2, 0))

	-- 1. secousses (2 s) : il gigote et blanchit à chaque secousse
	local SHAKE = 2
	local t0 = os.clock()
	local hits = 0
	while running and os.clock() - t0 < SHAKE do
		local e = os.clock() - t0
		local p = e / SHAKE
		local hopRate = 3 + p * 3
		local hop = math.abs(math.sin(e * math.pi * hopRate)) * (0.12 + p * 0.35)
		local tilt = math.sin(e * math.pi * hopRate) * math.rad(8 + p * 14)
		box:PivotTo(home * CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(e * 3.3) * math.rad(14), tilt))
		local h = math.floor(e * hopRate)
		if h ~= hits then
			hits = h
			-- chaque secousse : un cran de plus vers le blanc, et un éclair bref
			local base = 1 - p * 0.75
			white.FillTransparency = math.max(0, base - 0.35)
			TS:Create(white, TweenInfo.new(0.12), { FillTransparency = base }):Play()
		end
		task.wait()
	end
	if not running then return end

	-- 2. la chance (4 s) : silhouette blanche qui grossit et palpite, « ×N LUCK » qui monte
	white.FillTransparency = 0
	local bb, luck, luckHolder, luckGrad, luckIcon = luckBoard(core)
	table.insert(made, bb)
	pop(luckHolder, 0, 0.25)
	local glowAtt = make("Attachment", core, { Name = "ChanceGlow" })
	local glow = make("ParticleEmitter", glowAtt, { Name = "Sparkles", Texture = SPARKLE, Color = ColorSequence.new(WHITE, Color3.fromHex("fff2a8")), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(0.4, 0.8), Rate = 8 })
	local glowLight = make("PointLight", core, { Name = "ChanceLight", Color = WHITE, Brightness = 0.5, Range = 8 })
	local step = 1
	local CHANCE, TICK = 4, 0.1
	local value, ticks = 1, 0
	local t1 = os.clock()
	while running and os.clock() - t1 < CHANCE do
		local e = os.clock() - t1
		local p = e / CHANCE
		local n = math.floor(e / TICK)
		if n ~= ticks then
			ticks = n; value *= 1.03
			luck.Text = string.format("×%.2f LUCK", value)
			pop(luckHolder, 1.08, 0.1)
			luckIcon.Rotation = -10 + math.sin(n) * 8
			-- palier franchi (×2, ×3) : la pastille change de couleur avec un gros pop
			local nextStep = LUCK_STEPS[step + 1]
			if nextStep and value >= nextStep[1] then
				step += 1
				luckGrad.Color = ColorSequence.new(Color3.fromHex(nextStep[2]), Color3.fromHex(nextStep[3]))
				pop(luckHolder, 1.3, 0.3)
			end
		end
		glow.Rate = 8 + 40 * p
		glowLight.Brightness = 0.5 + 4 * p
		local grow = 1 + 0.3 * p
		local beat = 1 + 0.05 * math.max(0, math.cos((e % TICK) / TICK * math.pi))
		box:ScaleTo(grow * beat)
		box:PivotTo(home * CFrame.new(math.sin(e * 53) * 0.03 * p, 0, math.cos(e * 47) * 0.03 * p))
		task.wait()
	end
	if not running then return end

	-- 3. révélation : une image aux vraies couleurs, puis l'éclatement
	white.FillTransparency = 1
	task.wait(0.05)
	white.FillTransparency = 0
	local center = core.Position + Vector3.new(0, 0.6, 0)
	for _, d in box:GetDescendants() do if d:IsA("BasePart") then d.Transparency = 1 end end
	white.Enabled = false
	TS:Create(scaleOf(bb), TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
	burst(center, EPIC)
	status.opened = true

	local item, size, halo = makeItem(home * CFrame.Angles(0, math.rad(180), 0))
	local pivot = item:GetPivot()
	item:ScaleTo(1.5 * 0.2)
	local t2 = os.clock()
	while running and os.clock() - t2 < 0.35 do
		local q = (os.clock() - t2) / 0.35
		local s = 0.2 + (1.15 - 0.2) * TS:GetValue(q, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		item:ScaleTo(1.5 * s); item:PivotTo(pivot)
		task.wait()
	end
	item:ScaleTo(1.5); item:PivotTo(pivot)
	-- l'objet sort blanc, puis prend ses couleurs ; le halo garde la couleur de la rareté
	TS:Create(halo, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 0.82, FillColor = EPIC }):Play()
	local info = itemInfo(item, size)
	table.insert(made, info)
	pop(info, 0, 0.3)
	status.revealed = true
	task.wait(3.5)
	if not running then return end

	-- 4. en base : posé au sol, antivol qui le bloque 10 s
	if info.Parent then info:Destroy() end
	local floorPos = Vector3.new(-106, 0.4, 185)
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(floorPos + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
	if hit then floorPos = hit.Position end
	item:PivotTo(CFrame.new(floorPos) * CFrame.Angles(0, math.rad(90), 0))
	lookAt(floorPos + Vector3.new(9, 7, 0), floorPos + Vector3.new(0, 2.5, 0))
	local at, tag, segs, lock, timeL, tagGrad = antiTheft(item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true), size.Y / 2 + 3)
	table.insert(made, at)
	status.base = true
	for left = 10, 1, -1 do
		if not running then return end
		timeL.Text = string.format("0:%02d", left)
		task.wait(1)
		TS:Create(segs[11 - left], TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	end
	timeL.Text = "0:00"
	TS:Create(scaleOf(lock), TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.4 }):Play()
	TS:Create(lock, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 30, 0.5, -54), Rotation = 35, ImageTransparency = 1 }):Play()
	tag.Text = "UNLOCKED!"
	tagGrad.Color = ColorSequence.new(Color3.fromHex("91f630"), Color3.fromHex("31dd22"))
	pop(tag.Parent.Parent, 1.35, 0.3)
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
return "déroulé v4 lancé"
