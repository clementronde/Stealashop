--!nocheck
-- zone1_ambience.luau : ambiance de la zone 1 « été en banlieue » (Clément, 2026-11-17 : une ambiance propre à chaque
-- ville). Mode Edit, relançable : il refait tout ce qu'il pose (attribut Ambience = "Z1") et rien d'autre.
-- À relancer après zone1_superette.luau (qui recrée Street_Zone1). Aucun script : objets natifs seulement.
--  1) l'air : du pollen doré qui flotte au-dessus de la rue et des trottoirs (de nuit, on dirait des lucioles) ;
--  2) détails : des abeilles autour des deux jardinières, la fumée du four à bois de la pizzeria (petite cheminée
--     sur son toit) ;
--  3) son : une boucle d'oiseaux le jour et une de grillons la nuit, au milieu de la zone, qui s'éteint vers le hub
--     et vers Londres. Attribut PlayAt = "Day" ou "Night" sur chaque Sound : le code les échange à la tombée de la
--     nuit et à l'aube (liaison) ; d'ici là, les oiseaux jouent tout le temps et les grillons se taisent.
-- Sons : audio public vérifié par PreloadAsync le 2026-11-17 (oiseaux 72220890067268 « Background Birds Ambience »,
-- 8,5 s ; grillons 117579322290590 « Looping Crickets », 6,2 s). Le code range tout Sound du Workspace dans le groupe
-- SFX : le réglage de volume des effets s'applique.
-- Budget téléphone : environ 80 particules en tout (pollen ~55, abeilles ~10, fumée ~15).

local Z = workspace.Map.Zone_1
local S = Z.Street_Zone1
local TAG = "Z1"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png" -- livrée avec le client
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local rgb = Color3.fromRGB
local out = {}

-- Retire ce qu'une passe précédente a posé
for _, d in Z:GetDescendants() do
	if d:GetAttribute("Ambience") == TAG then d:Destroy() end
end

local amb = S:FindFirstChild("Ambience")
if not amb then amb = Instance.new("Model") amb.Name = "Ambience" amb.Parent = S end

local function holder(parent, name, cf, size)
	local p = Instance.new("Part")
	p.Name, p.CFrame, p.Size = name, cf, size
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p:SetAttribute("Ambience", TAG)
	p.Parent = parent
	return p
end
local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end
local NS = NumberSequence.new
local NSK = NumberSequenceKeypoint.new

-- 1) pollen : tout le couloir de la zone (x 30..118), au-dessus de la chaussée et des trottoirs
do
	local p = holder(amb, "PollenDrift", CFrame.new(74, 8, 0), Vector3.new(84, 10, 96))
	emitter(p, "Pollen", {
		Texture = SQUARE,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(rgb(255, 246, 200), rgb(255, 214, 110)),
		Size = NS({ NSK(0, 0.12), NSK(0.5, 0.22), NSK(1, 0.12) }),
		Transparency = NS({ NSK(0, 1), NSK(0.15, 0.25), NSK(0.85, 0.35), NSK(1, 1) }),
		Lifetime = NumberRange.new(9, 13),
		Rate = 5,
		Speed = NumberRange.new(0.3, 0.9),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0.12, 0.04, 0.03),
		Drag = 0.4,
		RotSpeed = NumberRange.new(-40, 40),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.35,
		LightInfluence = 0.6,
	})
	table.insert(out, "pollen au-dessus de la rue (5 par seconde, 9 à 13 s)")
end

-- 2a) abeilles autour des fleurs : les jardinières de la rue, ou à défaut (magasins agrandis le 2026-11-17, jardinières
-- rangées) les pots de fleurs devant les magasins (STORE_*/Decor/PotLeaves_*, lus seulement)
local flowers = {}
for _, n in { "FlowerBed_N2", "FlowerBed_S1" } do
	local bed = S:FindFirstChild("Props") and S.Props:FindFirstChild(n)
	if bed then local cf, sz = bed:GetBoundingBox() table.insert(flowers, { n, cf, sz }) end
end
if #flowers == 0 then
	for _, st in Z:GetChildren() do
		local dec = st:IsA("Model") and st.Name:match("^STORE_") and st:FindFirstChild("Decor")
		for _, c in (dec and dec:GetChildren() or {}) do
			if c:IsA("BasePart") and c.Name:match("^PotLeaves_%d+$") then
				table.insert(flowers, { st.Name:gsub("^STORE_Z1_", "") .. "_" .. c.Name, c.CFrame, c.Size + Vector3.new(1, 0, 1) })
			end
		end
	end
end
for _, f in flowers do
	local n, cf, sz = f[1], f[2], f[3]
	do
		local p = holder(amb, "Bees_" .. n, CFrame.new(cf.X, cf.Y + sz.Y / 2 + 0.9, cf.Z), Vector3.new(sz.X, 1.4, sz.Z))
		emitter(p, "Bees", {
			Texture = SQUARE,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(rgb(255, 205, 40), rgb(60, 45, 20)),
			Size = NS(0.13),
			Transparency = NS({ NSK(0, 1), NSK(0.1, 0), NSK(0.9, 0), NSK(1, 1) }),
			Lifetime = NumberRange.new(1.5, 2.5),
			Rate = 2.5,
			Speed = NumberRange.new(0.8, 1.6),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1.5,
			LightInfluence = 1,
		})
		table.insert(out, "abeilles : " .. n)
	end
end

-- 2b) four à bois de la pizzeria : petite cheminée de brique sur son toit, fumée légère
do
	local pz = S:FindFirstChild("Facades") and S.Facades:FindFirstChild("Facade_N2_Pizza")
	if pz then
		local cf, sz = pz:GetBoundingBox()
		local top = cf.Y + sz.Y / 2
		local zc = cf.Z - math.sign(cf.Z) * (sz.Z / 2 - 0.8) -- sur le devant du toit, loin des peupliers derrière le muret
		local stack = Instance.new("Part")
		stack.Name = "OvenChimney"
		stack.Size = Vector3.new(1.4, 2.4, 1.4)
		stack.CFrame = CFrame.new(cf.X + sz.X / 2 - 2.2, top + 1.2, zc)
		stack.Color = rgb(150, 70, 50)
		stack.Material = Enum.Material.Brick
		stack.Anchored, stack.CanCollide, stack.CastShadow = true, false, true
		stack:SetAttribute("Ambience", TAG)
		stack.Parent = pz
		local cap = holder(pz, "OvenSmokePoint", CFrame.new(stack.Position + Vector3.new(0, 1.3, 0)), Vector3.new(0.8, 0.2, 0.8))
		emitter(cap, "OvenSmoke", {
			Texture = SMOKE,
			EmissionDirection = Enum.NormalId.Top,
			Color = ColorSequence.new(rgb(235, 230, 225), rgb(190, 185, 180)),
			Size = NS({ NSK(0, 0.8), NSK(1, 3.2) }),
			Transparency = NS({ NSK(0, 0.55), NSK(1, 1) }),
			Lifetime = NumberRange.new(4, 6),
			Rate = 3,
			Speed = NumberRange.new(1.5, 2.5),
			SpreadAngle = Vector2.new(8, 8),
			Acceleration = Vector3.new(0.5, 0.3, 0),
			RotSpeed = NumberRange.new(-20, 20),
			Rotation = NumberRange.new(0, 360),
			LightInfluence = 1,
		})
		table.insert(out, "cheminée et fumée du four de la pizzeria")
	end
end

-- 3) sons d'ambiance, au milieu de la zone
do
	local p = holder(amb, "AmbienceSound", CFrame.new(74, 12, 0), Vector3.new(1, 1, 1))
	local function sound(name, id, phase, volume, playing)
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = "rbxassetid://" .. id
		s.Looped = true
		s.Volume = volume
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 35
		s.RollOffMaxDistance = 75
		s.Playing = playing
		s:SetAttribute("PlayAt", phase)
		s.Parent = p
	end
	sound("AMB_Z1_Birds", 72220890067268, "Day", 0.4, true)
	sound("AMB_Z1_Crickets", 117579322290590, "Night", 0.35, false)
	table.insert(out, "sons : oiseaux le jour (en lecture), grillons la nuit (à lancer par le code)")
end

return table.concat(out, "\n")
