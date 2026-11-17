--!nocheck
-- Pièges de boutique (Claude de Clément, 2026-11-17) : 3 modèles à poser sur un TrapSlot_0n de PLOT_Shop
-- (Attachment au sol, points espacés de 4 studs : emprise ≤ 3,6 × 3,6 studs).
-- Rangés dans ReplicatedStorage/Assets/Traps. Noms proposés dans la liaison, pas encore figés.
--
-- Chaque piège :
--   Base            PrimaryPart, pivot en bas au centre (le pivot se pose sur le TrapSlot), face avant -Z
--   TriggerZone     pièce invisible, sans collision : le volume où un voleur déclenche le piège
--   Armed           Model : ce qu'on voit tant que le piège attend (visible à la livraison)
--   Triggered       Model : ce qu'on voit une fois déclenché, livré caché :
--                     pièces en Transparency 1 (attribut ShownTransparency = transparence à remettre),
--                     ParticleEmitter, Beam et lumières éteints (attribut EmitCount = gerbe à lancer)
--   attribut TrapId (GlueMat, NetBox, AlarmGate)
-- Aucun script, effets natifs seulement. Aucune valeur de jeu (durée, ralentissement, prix) : Cantin.
-- Relançable : remplace les modèles existants. Mode Edit, annulable.
local CHS = game:GetService("ChangeHistoryService")
local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local rec = CHS:TryBeginRecording("Pièges de boutique")

local folder = Assets:FindFirstChild("Traps") or Instance.new("Folder")
folder.Name = "Traps"
folder.Parent = Assets

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local INK = Color3.fromHex("#1B1B24")
local function NS(a, b) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end

local function newModel(name, trapId)
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("TrapId", trapId)
	local armed = Instance.new("Model") armed.Name = "Armed" armed.Parent = m
	local trig = Instance.new("Model") trig.Name = "Triggered" trig.Parent = m
	return m, armed, trig
end

-- p(parent, nom, taille, CFrame local, couleur, matiere, { studs, shape, transp, collide })
local function p(parent, name, size, cf, color, mat, o)
	o = o or {}
	local part = Instance.new("Part")
	part.Name = name
	if o.shape then part.Shape = o.shape end
	part.Size = size
	part.CFrame = cf
	part.Color = Color3.fromHex(color)
	if o.studs then
		part.Material = Enum.Material.Plastic
		part.MaterialVariant = "Studs"
	else
		part.Material = mat or Enum.Material.SmoothPlastic
	end
	part.Anchored = true
	part.CanCollide = o.collide == true
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if part.Material == Enum.Material.Neon then part.CastShadow = false end
	if o.reflect then part.Reflectance = o.reflect end
	local t = o.transp or 0
	if parent.Name == "Triggered" or parent:FindFirstAncestor("Triggered") then
		if t > 0 then part:SetAttribute("ShownTransparency", t) end
		part.Transparency = 1
	else
		part.Transparency = t
	end
	part.Parent = parent
	return part
end

local function base(m, size)
	local b = p(m, "Base", size, CFrame.new(0, size.Y / 2, 0), "#3A404B", nil, { studs = true })
	b.PivotOffset = CFrame.new(0, -size.Y / 2, 0) -- pivot du modèle en bas au centre
	m.PrimaryPart = b
	return b
end

local function zone(m, size)
	local z = p(m, "TriggerZone", size, CFrame.new(0, size.Y / 2, 0), "#FF3B5C", nil, { transp = 1 })
	z.CastShadow = false
	return z
end

local function att(part, name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = part
	return a
end

local function emitter(parent, name, props, emitCount)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do e[k] = v end
	e.Enabled = false
	if emitCount then e:SetAttribute("EmitCount", emitCount) end
	e.Parent = parent
	return e
end

local made = {}

-- 1. TRAP_GlueMat : tapis de colle, un bac à colle déguisé en paillasson « WELCOME » ----------------------
-- Armé : un paillasson rayé posé sur une fine flaque brillante. Déclenché : la colle déborde, des fils de colle
-- montent autour des pieds, des bulles éclatent.
do
	local m, armed, trig = newModel("TRAP_GlueMat", "GlueMat")
	local b = base(m, Vector3.new(3.6, 0.12, 3.6))
	b.Color = Color3.fromHex("#6B4A2E")
	zone(m, Vector3.new(3.2, 3, 3.2))
	-- bac (rebord)
	for i, s in { { 0, 1.72, 3.6, 0.16 }, { 0, -1.72, 3.6, 0.16 }, { 1.72, 0, 0.16, 3.6 }, { -1.72, 0, 0.16, 3.6 } } do
		p(m, "Rim_0" .. i, Vector3.new(s[3], 0.22, s[4]), CFrame.new(s[1], 0.23, s[2]), "#8A6240", nil, { studs = true })
	end
	p(m, "GlueSheen", Vector3.new(3.28, 0.06, 3.28), CFrame.new(0, 0.15, 0), "#FFE08A", Enum.Material.Glass, { transp = 0.15, reflect = 0.25 })
	-- armé : paillasson rayé (déguisement)
	p(armed, "Mat", Vector3.new(2.9, 0.1, 2.3), CFrame.new(0, 0.23, 0), "#B5452F", Enum.Material.Fabric)
	for i = 1, 4 do
		p(armed, "MatStripe_0" .. i, Vector3.new(2.9, 0.11, 0.18), CFrame.new(0, 0.235, -0.85 + (i - 1) * 0.57), "#E7C26A", Enum.Material.Fabric)
	end
	p(armed, "MatBorder", Vector3.new(3.0, 0.08, 2.4), CFrame.new(0, 0.2, 0), INK, Enum.Material.Fabric)
	-- déclenché : la colle monte
	local glue = "#FFD23F"
	p(trig, "GlueFlood", Vector3.new(3.3, 0.18, 3.3), CFrame.new(0, 0.3, 0), glue, Enum.Material.Glass, { transp = 0.1, reflect = 0.3 })
	local rnd = Random.new(4)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local r = rnd:NextNumber(0.6, 1.3)
		local h = rnd:NextNumber(0.9, 1.9)
		p(trig, string.format("Strand_%02d", i), Vector3.new(0.22, h, 0.22),
			CFrame.new(math.cos(a) * r, 0.3 + h / 2, math.sin(a) * r) * CFrame.Angles(rnd:NextNumber(-0.25, 0.25), 0, rnd:NextNumber(-0.25, 0.25)),
			glue, Enum.Material.Glass, { transp = 0.15, reflect = 0.3 })
		p(trig, string.format("Drop_%02d", i), Vector3.new(0.4, 0.4, 0.4),
			CFrame.new(math.cos(a) * r, 0.3 + h, math.sin(a) * r) * CFrame.Angles(math.rad(45), math.rad(45), 0), glue, Enum.Material.Glass, { transp = 0.15, reflect = 0.3 })
	end
	local fx = att(b, "FX_Glue", Vector3.new(0, 0.3, 0))
	emitter(fx, "Bubbles", { Texture = SPARK, Color = ColorSequence.new(Color3.fromHex(glue)), Rate = 8, Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, 2, 0), Size = NS(0.5, 0.1),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume })
	emitter(fx, "Splat", { Texture = SQUARE, Color = ColorSequence.new(Color3.fromHex(glue)), Rate = 0, Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -40, 0), Size = NS(0.35, 0.15),
		RotSpeed = NumberRange.new(-200, 200) }, 24)
	m.Parent = folder
	table.insert(made, m)
end

-- 2. TRAP_NetBox : le colis piégé. Un faux colis « FRAGILE » qui s'ouvre d'un coup et lance un filet --------
-- Armé : un carton scotché, appât parfait dans une boutique pleine de colis. Déclenché : les rabats s'ouvrent,
-- un ressort sort, un filet en cloche retombe sur le voleur, des confettis de carton volent.
do
	local m, armed, trig = newModel("TRAP_NetBox", "NetBox")
	local b = base(m, Vector3.new(1.8, 0.1, 1.8))
	b.Color = Color3.fromHex("#8A6240")
	zone(m, Vector3.new(3.4, 3.5, 3.4))
	local CARD, TAPE = "#C8935A", "#E9D9A8"
	-- le carton (toujours là)
	p(m, "Box", Vector3.new(1.6, 1.15, 1.6), CFrame.new(0, 0.1 + 0.575, 0), CARD, Enum.Material.Cardboard)
	p(m, "Label", Vector3.new(0.9, 0.42, 0.04), CFrame.new(0, 0.75, -0.82), "#F6F0E0")
	p(m, "LabelText", Vector3.new(0.7, 0.12, 0.05), CFrame.new(0, 0.8, -0.835), "#D8322E")
	p(m, "LabelBar", Vector3.new(0.7, 0.06, 0.05), CFrame.new(0, 0.64, -0.835), INK)
	-- armé : couvercle fermé et scotch
	p(armed, "Lid", Vector3.new(1.64, 0.08, 1.64), CFrame.new(0, 1.29, 0), CARD, Enum.Material.Cardboard)
	p(armed, "Tape", Vector3.new(0.36, 0.1, 1.66), CFrame.new(0, 1.3, 0), TAPE)
	p(armed, "TapeFront", Vector3.new(0.36, 0.4, 0.04), CFrame.new(0, 1.1, -0.82), TAPE)
	-- déclenché : rabats ouverts, ressort, filet en cloche
	for i, s in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local dx, dz = s[1], s[2]
		local cf = CFrame.new(dx * 1.05, 1.25 + 0.1, dz * 1.05)
		if dz ~= 0 then cf = cf * CFrame.Angles(math.rad(-60) * dz, 0, 0) else cf = cf * CFrame.Angles(0, 0, math.rad(60) * dx) end
		p(trig, "Flap_0" .. i, Vector3.new(dz ~= 0 and 1.6 or 0.06, 0.06, dz ~= 0 and 0.06 or 1.6) + Vector3.new(0, 0.7, 0), cf, CARD, Enum.Material.Cardboard)
	end
	for k = 1, 5 do
		p(trig, "Spring_0" .. k, Vector3.new(0.7, 0.1, 0.7), CFrame.new(0, 1.3 + k * 0.22, 0), "#C9CFD8", Enum.Material.Metal)
	end
	p(trig, "SpringCap", Vector3.new(0.9, 0.16, 0.9), CFrame.new(0, 2.5, 0), "#D8322E")
	-- filet : une cloche de 3,4 studs de large, 8 côtes et 3 anneaux de cordelette
	local NET = "#2B2E3A"
	local R, H = 1.65, 3.2
	local function domePoint(t, ang) -- t = 0 au sommet, 1 au bord
		local rr = R * math.sin(t * math.pi / 2)
		local y = H * math.cos(t * math.pi / 2) * 0.85 + 0.15
		return Vector3.new(math.cos(ang) * rr, y, math.sin(ang) * rr)
	end
	local function rope(name, a, c)
		local mid, len = (a + c) / 2, (c - a).Magnitude
		p(trig, name, Vector3.new(0.08, 0.08, len), CFrame.lookAt(mid, c), NET, Enum.Material.Fabric)
	end
	local SEG = 4
	for k = 0, 7 do
		local ang = k / 8 * math.pi * 2
		for s = 0, SEG - 1 do
			rope(string.format("NetRib_%d_%d", k, s), domePoint(s / SEG, ang), domePoint((s + 1) / SEG, ang))
		end
	end
	for r, t in { 0.4, 0.7, 1.0 } do
		for k = 0, 11 do
			rope(string.format("NetRing_%d_%02d", r, k), domePoint(t, k / 12 * math.pi * 2), domePoint(t, (k + 1) / 12 * math.pi * 2))
		end
	end
	for k = 0, 7 do -- lests au bord du filet
		local pnt = domePoint(1, k / 8 * math.pi * 2)
		p(trig, "NetWeight_0" .. k, Vector3.new(0.22, 0.22, 0.22), CFrame.new(pnt), "#C9CFD8", Enum.Material.Metal)
	end
	local fx = att(b, "FX_Burst", Vector3.new(0, 1.3, 0))
	emitter(fx, "Confetti", { Texture = SQUARE, Color = ColorSequence.new(Color3.fromHex(CARD), Color3.fromHex(TAPE)), Rate = 0,
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, -30, 0),
		Size = NS(0.3, 0.2), RotSpeed = NumberRange.new(-300, 300), Rotation = NumberRange.new(0, 360) }, 30)
	emitter(fx, "Puff", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#E9E2D0")), Rate = 0, Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(180, 180), Size = NS(1.2, 3), Transparency = NS(0.3, 1) }, 8)
	m.Parent = folder
	table.insert(made, m)
end

-- 3. TRAP_AlarmGate : le portique antivol de la boutique, qui se referme sur le voleur -----------------------
-- Armé : deux bornes blanches, une petite lumière verte. Déclenché : bandes rouges, gyrophare, trois barreaux laser
-- (Beam) entre les bornes, étincelles.
do
	local m, armed, trig = newModel("TRAP_AlarmGate", "AlarmGate")
	local b = base(m, Vector3.new(3.6, 0.1, 1.0))
	zone(m, Vector3.new(2.6, 4.5, 1.2))
	local H = 4.6
	local posts = {}
	for i, x in { -1.5, 1.5 } do
		local post = p(m, "Post_0" .. i, Vector3.new(0.4, H, 0.8), CFrame.new(x, 0.1 + H / 2, 0), "#F0F2F5", nil, { studs = true, collide = true })
		posts[i] = post
		p(m, "PostCap_0" .. i, Vector3.new(0.46, 0.2, 0.86), CFrame.new(x, 0.1 + H + 0.1, 0), "#3A404B")
		p(m, "PostFoot_0" .. i, Vector3.new(0.6, 0.25, 1.0), CFrame.new(x, 0.225, 0), "#3A404B")
		p(m, "PostPanel_0" .. i, Vector3.new(0.06, H - 1.2, 0.5), CFrame.new(x - 0.23 * (x > 0 and 1 or -1), 0.1 + H / 2, 0), "#C9CFD8", Enum.Material.Glass, { transp = 0.3 })
		-- armé : voyant vert
		p(armed, "LedGreen_0" .. i, Vector3.new(0.12, 0.3, 0.3), CFrame.new(x - 0.23 * (x > 0 and 1 or -1), 0.1 + H - 0.4, 0), "#2FE08F", Enum.Material.Neon)
		-- déclenché : bandes rouges et voyant rouge
		for k = 1, 3 do
			p(trig, string.format("RedStrip_%d_%d", i, k), Vector3.new(0.08, 0.18, 0.62), CFrame.new(x - 0.23 * (x > 0 and 1 or -1), 0.1 + k * 1.2, 0), "#FF2A3D", Enum.Material.Neon)
		end
		p(trig, "LedRed_0" .. i, Vector3.new(0.14, 0.32, 0.32), CFrame.new(x - 0.23 * (x > 0 and 1 or -1), 0.1 + H - 0.4, 0), "#FF2A3D", Enum.Material.Neon)
	end
	-- gyrophare sur la borne de droite
	local siren = p(trig, "Siren", Vector3.new(0.36, 0.4, 0.36), CFrame.new(1.5, 0.1 + H + 0.4, 0), "#FF2A3D", Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Name = "AlarmLight"
	light.Color = Color3.fromHex("#FF2A3D")
	light.Range = 14
	light.Brightness = 3
	light.Enabled = false
	light.Parent = siren
	-- barreaux laser entre les bornes
	for k = 1, 3 do
		local y = 0.1 + k * 1.2
		local a0 = att(posts[1], "Laser_" .. k .. "_A", Vector3.new(0.2, y - (0.1 + H / 2), 0))
		local a1 = att(posts[2], "Laser_" .. k .. "_B", Vector3.new(-0.2, y - (0.1 + H / 2), 0))
		local beam = Instance.new("Beam")
		beam.Name = "Laser_0" .. k
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(Color3.fromHex("#FF2A3D"))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Width0 = 0.18
		beam.Width1 = 0.18
		beam.FaceCamera = true
		beam.Transparency = NumberSequence.new(0.05)
		beam.Enabled = false
		beam.Parent = trig
	end
	local fx = att(b, "FX_Sparks", Vector3.new(0, 2.5, 0))
	emitter(fx, "Sparks", { Texture = SPARK, Color = ColorSequence.new(Color3.fromHex("#FF8A8A")), LightEmission = 1, Rate = 0,
		Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -30, 0), Size = NS(0.35, 0.05) }, 25)
	m.Parent = folder
	table.insert(made, m)
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end

-- bilan : pièces, scripts, emprise, triangles estimés (bloc 12, cylindre 76, boule 380, valeurs de Roblox)
local out = {}
for _, m in made do
	local n, scripts, tris = 0, 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			tris += (d.Shape == Enum.PartType.Ball and 380) or (d.Shape == Enum.PartType.Cylinder and 76) or 12
		end
		if d:IsA("LuaSourceContainer") then scripts += 1 end
	end
	local _, size = m:GetBoundingBox()
	table.insert(out, string.format("%s : %d pièces, ~%d triangles, %d scripts, emprise %.1f × %.1f × %.1f",
		m.Name, n, tris, scripts, size.X, size.Y, size.Z))
end
return table.concat(out, "\n")
