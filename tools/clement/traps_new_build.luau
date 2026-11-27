--!nocheck
-- Pieges de boutique, suite (L-279, decisions de Cantin du 2026-11-21) : TRAP_BananaPeel (peau de banane) et
-- TRAP_TrapDoor (trappe), dans le meme style et a la meme echelle que TRAP_GlueMat, TRAP_NetBox et TRAP_AlarmGate
-- (tools/clement/traps_build.luau) : emprise <= 3,6 x 3,6 studs, Base PrimaryPart pivot en bas au centre, face avant -Z,
-- TriggerZone invisible, Armed visible, Triggered livre cache (Transparency 1 + attribut ShownTransparency ;
-- emetteurs eteints, attribut EmitCount), attribut TrapId. Aucun script, effets natifs seulement, aucune valeur de jeu.
-- Construit d'abord dans ServerStorage/Previews/TRAPS (planche pour Clement) ; DEST = "Assets" les range dans
-- ReplicatedStorage/Assets/Traps a cote des autres, une fois la planche validee. Relancable, mode Edit.
local DEST = "Previews" -- "Previews" ou "Assets"

local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local folder
if DEST == "Assets" then
	folder = Assets:FindFirstChild("Traps") or Instance.new("Folder")
	folder.Name = "Traps"
	folder.Parent = Assets
else
	local SS = game:GetService("ServerStorage")
	local prev = SS:FindFirstChild("Previews") or Instance.new("Folder")
	prev.Name = "Previews"
	prev.Parent = SS
	folder = prev:FindFirstChild("TRAPS") or Instance.new("Folder")
	folder.Name = "TRAPS"
	folder.Parent = prev
end

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local INK = "#1B1B24"
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

-- p(parent, nom, taille, CFrame local, couleur, matiere, { studs, shape, transp, collide, reflect, wedge })
local function p(parent, name, size, cf, color, mat, o)
	o = o or {}
	local part = if o.wedge then Instance.new("WedgePart") else Instance.new("Part")
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
local function base(m, size, color)
	local b = p(m, "Base", size, CFrame.new(0, size.Y / 2, 0), color or "#3A404B", nil, { studs = true })
	b.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
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

-- 1. TRAP_BananaPeel : une grosse peau de banane posee par terre, sur un petit tapis de sol
-- Arme : la peau ouverte en 4 pans, tige brune. Declenche : la peau a glisse (couchee, ecrasee), une trainee jaune
-- de glissade au sol, des etoiles qui jaillissent.
do
	local m, armed, trig = newModel("TRAP_BananaPeel", "BananaPeel")
	base(m, Vector3.new(3.6, 0.1, 3.6), "#4A505C")
	zone(m, Vector3.new(3.2, 3, 3.2))
	local Y, YD, BR = "#FFD93B", "#E6B520", "#6B4A23"
	local h = 0.1
	-- corps de la peau (le coeur) et 4 pans qui s'ouvrent en etoile
	-- peau debout (coeur haut, tige) et 4 pans qui retombent jusqu'au sol (planche du 26/11 : a plat, on lisait une etoile)
	p(armed, "Core", Vector3.new(0.75, 0.9, 0.75), CFrame.new(0, h + 0.45, 0), Y, nil, { studs = true })
	p(armed, "CoreTop", Vector3.new(0.5, 0.25, 0.5), CFrame.new(0, h + 1.0, 0), YD, nil, { studs = true })
	p(armed, "Stem", Vector3.new(0.2, 0.3, 0.2), CFrame.new(0, h + 1.25, 0) * CFrame.Angles(0, 0, math.rad(15)), BR)
	for i = 0, 3 do
		local a = math.rad(i * 90 + 20)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local top = Vector3.new(0, h + 0.8, 0) + dir * 0.3
		local tip = Vector3.new(0, h + 0.1, 0) + dir * 1.55
		local len = (tip - top).Magnitude
		local look = CFrame.lookAt((top + tip) / 2, tip)
		p(armed, "Flap_0" .. (i + 1), Vector3.new(0.7, 0.14, len), look, if i % 2 == 0 then Y else YD, nil, { studs = true })
		p(armed, "FlapTip_0" .. (i + 1), Vector3.new(0.5, 0.15, 0.3), look * CFrame.new(0, 0.01, -len / 2 + 0.1), BR)
	end
	-- declenche : peau couchee qui a glisse vers +Z, trainee de glissade, etoiles
	p(trig, "SlidPeel", Vector3.new(1.6, 0.18, 0.9), CFrame.new(0.2, h + 0.09, 1.0) * CFrame.Angles(0, math.rad(25), 0), Y, nil, { studs = true })
	p(trig, "SlidTip", Vector3.new(0.4, 0.16, 0.5), CFrame.new(0.95, h + 0.08, 1.35) * CFrame.Angles(0, math.rad(25), 0), BR)
	p(trig, "SkidMark", Vector3.new(0.7, 0.03, 2.4), CFrame.new(-0.1, h + 0.015, -0.4) * CFrame.Angles(0, math.rad(12), 0), "#FFF2A8", nil, { transp = 0.25 })
	local fx = att(m.Base, "FX_Slip", Vector3.new(0, 0.6, 0))
	emitter(fx, "Stars", { Texture = SPARK, Color = ColorSequence.new(Color3.fromHex("#FFF6B0")), Rate = 0, Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -12, 0), Size = NS(0.6, 0.15),
		RotSpeed = NumberRange.new(-180, 180), LightEmission = 0.6 }, 14)
	emitter(fx, "Puff", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#EDE6D0")), Rate = 0, Lifetime = NumberRange.new(0.4, 0.6),
		Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(80, 10), Size = NS(0.8, 1.6), Transparency = NS(0.4, 1) }, 8)
	m.Parent = folder
	table.insert(made, m)
end

-- 2. TRAP_TrapDoor : une trappe en bois dans le sol, cadre metal, poignee en anneau
-- Arme : la trappe fermee (planches, charnieres, anneau). Declenche : les deux battants ouverts vers le haut, le trou
-- noir au milieu, une bouffee de poussiere.
do
	local m, armed, trig = newModel("TRAP_TrapDoor", "TrapDoor")
	base(m, Vector3.new(3.6, 0.1, 3.6), "#2F343D")
	zone(m, Vector3.new(3.0, 3, 3.0))
	local WOOD, WOOD2, METAL = "#9A6A3C", "#84582F", "#5A6270"
	local h = 0.1
	-- cadre metal (reste visible arme ou declenche)
	for i, s in { { 0, 1.62, 3.4, 0.2 }, { 0, -1.62, 3.4, 0.2 }, { 1.62, 0, 0.2, 3.4 }, { -1.62, 0, 0.2, 3.4 } } do
		p(m, "Frame_0" .. i, Vector3.new(s[3], 0.14, s[4]), CFrame.new(s[1], h + 0.07, s[2]), METAL, Enum.Material.Metal)
	end
	-- arme : 2 battants fermes, en planches, charnieres et anneau
	for side = -1, 1, 2 do
		for k = 0, 2 do
			p(armed, string.format("Plank_%s%d", if side < 0 then "L" else "R", k + 1), Vector3.new(1.48, 0.12, 0.98),
				CFrame.new(side * 0.76, h + 0.06, -0.99 + k * 0.99), if k % 2 == 0 then WOOD else WOOD2, Enum.Material.Wood)
		end
		p(armed, "Hinge_" .. (if side < 0 then "L" else "R"), Vector3.new(0.18, 0.06, 2.6), CFrame.new(side * 1.42, h + 0.15, 0), METAL, Enum.Material.Metal)
	end
	p(armed, "Seam", Vector3.new(0.05, 0.13, 2.95), CFrame.new(0, h + 0.065, 0), INK)
	p(armed, "RingBase", Vector3.new(0.3, 0.06, 0.3), CFrame.new(0.3, h + 0.15, 0), "#2B2F36", Enum.Material.Metal)
	p(armed, "Ring", Vector3.new(0.08, 0.5, 0.5), CFrame.new(0.3, h + 0.17, 0) * CFrame.Angles(0, 0, math.rad(90)), "#2B2F36", nil, { shape = Enum.PartType.Cylinder })
	-- declenche : trou noir, battants releves de chaque cote
	p(trig, "Hole", Vector3.new(3.0, 0.04, 3.0), CFrame.new(0, h + 0.02, 0), "#050507")
	for side = -1, 1, 2 do
		local hinge = CFrame.new(side * 1.5, h + 0.12, 0)
		local flap = hinge * CFrame.Angles(0, 0, math.rad(side * -100)) * CFrame.new(-side * 0.75, 0, 0)
		p(trig, "OpenFlap_" .. (if side < 0 then "L" else "R"), Vector3.new(1.48, 0.12, 2.95), flap, WOOD, Enum.Material.Wood)
	end
	local fx = att(m.Base, "FX_Dust", Vector3.new(0, 0.2, 0))
	emitter(fx, "Dust", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#B9A88A")), Rate = 0, Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(25, 25), Size = NS(1, 2.4), Transparency = NS(0.3, 1), Acceleration = Vector3.new(0, 2, 0) }, 12)
	emitter(fx, "Splinters", { Texture = SQUARE, Color = ColorSequence.new(Color3.fromHex(WOOD)), Rate = 0, Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(8, 12), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -40, 0), Size = NS(0.3, 0.15),
		RotSpeed = NumberRange.new(-300, 300) }, 16)
	m.Parent = folder
	table.insert(made, m)
end

local lines = {}
for _, m in made do
	local _, s = m:GetBoundingBox()
	local n = 0
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	table.insert(lines, string.format("%s : %d pieces, %.1f x %.1f x %.1f", m.Name, n, s.X, s.Y, s.Z))
end
print("[pieges] " .. table.concat(lines, " ; "))
return table.concat(lines, "\n")
