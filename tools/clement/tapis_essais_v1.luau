--!nocheck
-- 25 tapis (demande de Clement du 26/11) : 3 essais pour la planche, Cardboard (simple), Pirate (milieu), Royal (rare).
-- Chaque essai est une copie de ReplicatedStorage/Assets/Plots/PLOT_Treadmill_Base (meme repere, memes enfants :
-- Belt avec BeltTexture et UsePoint, BeltArrows, BeltEnds, Frame avec UpgradePoint, Console*, collisions, UseZone,
-- WidthScale), recoloree, avec un decor en pieces (studs) surtout a l'arriere (+Z, arche) et sur les cotes, rien sur
-- la bande. Collisions invisibles de l'arche comme Candy (Collision_RearL, _RearR, _RearTop). Aucun script.
-- Range dans ServerStorage/Previews/TREADMILLS : rien dans Assets avant la validation de la liste par Clement.
-- La version finale passera en MeshPart par Blender. Relancable, mode Edit.

local SS = game:GetService("ServerStorage")
local src = game:GetService("ReplicatedStorage").Assets.Plots.PLOT_Treadmill_Base
local prev = SS:FindFirstChild("Previews") or Instance.new("Folder")
prev.Name = "Previews"
prev.Parent = SS
local folder = prev:FindFirstChild("TREADMILLS") or Instance.new("Folder")
folder.Name = "TREADMILLS"
folder.Parent = prev

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
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if part.Material == Enum.Material.Neon then part.CastShadow = false end
	if o.reflect then part.Reflectance = o.reflect end
	if o.transp then part.Transparency = o.transp end
	part.Parent = parent
	return part
end
local function cyl(parent, name, len, dia, cf, color, mat, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	return p(parent, name, Vector3.new(len, dia, dia), cf, color, mat, o)
end
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylindre debout (axe X -> Y)
local FACE = CFrame.Angles(0, math.rad(90), 0) -- cylindre face a l'avant (axe X -> Z)

local function collider(m, name, size, pos)
	local c = Instance.new("Part")
	c.Name = name
	c.Size = size
	c.CFrame = CFrame.new(pos)
	c.Anchored = true
	c.CanCollide = true
	c.CanTouch = false
	c.CanQuery = false
	c.Transparency = 1
	c.Parent = m
end

local function newTreadmill(theme, colors)
	local name = "PLOT_Treadmill_" .. theme
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local m = src:Clone()
	m.Name = name
	m.Frame.Color = Color3.fromHex(colors.frame)
	m.Trim.Color = Color3.fromHex(colors.trim)
	m.BeltEnds.Color = Color3.fromHex(colors.ends)
	m.BeltArrows.Color = Color3.fromHex(colors.arrows)
	m.ConsoleButtons.Color = Color3.fromHex(colors.buttons)
	m.ConsoleScreen.Color = Color3.fromHex(colors.screen)
	if colors.frameMat then m.Frame.Material = colors.frameMat end
	if colors.trimMat then m.Trim.Material = colors.trimMat end
	if colors.trimReflect then m.Trim.Reflectance = colors.trimReflect end
	local deco = Instance.new("Model")
	deco.Name = "Decor"
	deco.Parent = m
	local fx = Instance.new("Folder")
	fx.Name = theme .. "FX"
	fx.Parent = m
	-- collisions de l'arche arriere (memes noms que Candy)
	collider(m, "Collision_RearL", Vector3.new(1.6, 6.8, 0.8), Vector3.new(-2.55, 4.2, 3.9))
	collider(m, "Collision_RearR", Vector3.new(1.6, 6.8, 0.8), Vector3.new(2.55, 4.2, 3.9))
	collider(m, "Collision_RearTop", Vector3.new(6.7, 0.8, 0.8), Vector3.new(0, 7.2, 3.9))
	return m, deco, fx
end
local function fxPart(fx, name, size, pos)
	local a = Instance.new("Part")
	a.Name = name
	a.Size = size
	a.CFrame = CFrame.new(pos)
	a.Anchored = true
	a.CanCollide = false
	a.CanTouch = false
	a.CanQuery = false
	a.Transparency = 1
	a.Parent = fx
	return a
end
local function NS(a, b) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local made = {}

-- ===== Cardboard (niveau 2) : carton kraft et scotch, comme nos colis =====
do
	-- planche du 26/11 : la matiere Cardboard rendait olive et sombre, on reste en plastique lisse
	local KRAFT, KRAFT2, KRAFT3, TAPE, RED = "#D7A066", "#C28A52", "#E0AE72", "#A8743A", "#D8343C"
	local m, d = newTreadmill("Cardboard", { frame = "#C99561", trim = "#8B5E34", ends = "#5A3D24", arrows = "#F3E2B8",
		buttons = "#E9D49A", screen = "#3B2A1C" })
	-- deux piles de 3 cartons a l'arriere (l'arche) et un carton couche dessus
	local function box(name, size, cf, col)
		local b = p(d, name, size, cf, col)
		-- bande de scotch verticale au milieu (dessus, avant, dessous, arriere)
		p(d, name .. "_Tape", Vector3.new(size.X * 0.2, size.Y + 0.04, size.Z + 0.04), cf, TAPE, nil, { reflect = 0.08 })
		return b
	end
	for side = -1, 1, 2 do
		local x = side * 2.55
		box("Stack" .. side .. "_1", Vector3.new(1.7, 1.9, 1.4), CFrame.new(x, 0.95, 3.9) * CFrame.Angles(0, math.rad(4 * side), 0), KRAFT)
		box("Stack" .. side .. "_2", Vector3.new(1.55, 1.8, 1.3), CFrame.new(x + side * 0.05, 2.85, 3.9) * CFrame.Angles(0, math.rad(-6 * side), 0), KRAFT2)
		box("Stack" .. side .. "_3", Vector3.new(1.6, 1.85, 1.35), CFrame.new(x - side * 0.05, 4.7, 3.9) * CFrame.Angles(0, math.rad(5 * side), 0), KRAFT3)
	end
	box("TopBox", Vector3.new(6.7, 1.3, 1.5), CFrame.new(0, 6.3, 3.9) * CFrame.Angles(0, 0, math.rad(-2)), KRAFT)
	-- etiquette FRAGILE (pastille rouge et verre stylise) sur le carton du haut, cote avant
	p(d, "FragileLabel", Vector3.new(2.2, 0.8, 0.05), CFrame.new(0, 6.3, 3.12), RED)
	p(d, "FragileGlass", Vector3.new(0.3, 0.5, 0.06), CFrame.new(-0.75, 6.33, 3.1), "#FFFFFF")
	p(d, "FragileText", Vector3.new(1.2, 0.18, 0.06), CFrame.new(0.3, 6.3, 3.1), "#FFFFFF")
	-- fleches de sens (comme sur un carton) sur les piles
	for side = -1, 1, 2 do
		p(d, "UpArrow" .. side, Vector3.new(0.18, 0.7, 0.05), CFrame.new(side * 2.55, 2.85, 3.22), "#3B2A1C")
		p(d, "UpArrowHead" .. side, Vector3.new(0.5, 0.5, 0.05), CFrame.new(side * 2.55, 3.3, 3.22) * CFrame.Angles(0, 0, math.rad(45)), "#3B2A1C")
	end
	-- cartons poses au sol sur les cotes, rouleau de scotch sur la console
	box("SideBox_L", Vector3.new(1.6, 1.3, 1.6), CFrame.new(-4.6, 0.65, 1.5) * CFrame.Angles(0, math.rad(18), 0), KRAFT2)
	box("SideBox_L2", Vector3.new(1.1, 0.9, 1.1), CFrame.new(-4.4, 1.75, 1.4) * CFrame.Angles(0, math.rad(-10), 0), KRAFT3)
	box("SideBox_R", Vector3.new(1.8, 1.0, 1.4), CFrame.new(4.7, 0.5, -1.2) * CFrame.Angles(0, math.rad(-14), 0), KRAFT)
	local roll = CFrame.new(4.7, 1.18, -1.2) * CFrame.Angles(0, math.rad(20), 0) * UP -- pose sur SideBox_R
	cyl(d, "TapeRoll", 0.35, 0.9, roll, "#B98345")
	cyl(d, "TapeRollCore", 0.37, 0.45, roll, "#8A6B45")
	m.Parent = folder
	table.insert(made, m)
end

-- ===== Pirate (niveau 15) : bois sombre, or, voile noire, coffre au tresor, gouvernail =====
do
	local WOOD, WOOD2, GOLD, SAIL, ROPE = "#5B3A22", "#734A2B", "#E8B640", "#1F1D24", "#C9A76A"
	local m, d, fx = newTreadmill("Pirate", { frame = WOOD2, trim = GOLD, ends = "#2E1E12", arrows = "#FFD35A",
		buttons = GOLD, screen = "#1A120B", frameMat = Enum.Material.Wood, trimReflect = 0.1 })
	-- deux mats a l'arriere, une vergue, une voile noire avec un embleme blanc
	for side = -1, 1, 2 do
		cyl(d, "Mast" .. side, 7.4, 0.7, CFrame.new(side * 2.6, 3.7, 3.9) * UP, WOOD, Enum.Material.Wood)
		cyl(d, "MastRing" .. side, 0.25, 0.85, CFrame.new(side * 2.6, 2.2, 3.9) * UP, GOLD, Enum.Material.Metal)
		cyl(d, "MastRingTop" .. side, 0.25, 0.85, CFrame.new(side * 2.6, 5.4, 3.9) * UP, GOLD, Enum.Material.Metal)
	end
	cyl(d, "Yard", 6.8, 0.45, CFrame.new(0, 7.3, 3.9), WOOD, Enum.Material.Wood)
	p(d, "Sail", Vector3.new(4.4, 3.4, 0.12), CFrame.new(0, 5.5, 4.05) * CFrame.Angles(math.rad(-6), 0, 0), SAIL, Enum.Material.Fabric)
	cyl(d, "SailEmblem", 0.06, 1.3, CFrame.new(0, 5.7, 3.96) * FACE, "#F2EEE4", Enum.Material.SmoothPlastic)
	p(d, "SailEmblemBar1", Vector3.new(2.0, 0.22, 0.05), CFrame.new(0, 5.1, 3.95) * CFrame.Angles(0, 0, math.rad(30)), "#F2EEE4")
	p(d, "SailEmblemBar2", Vector3.new(2.0, 0.22, 0.05), CFrame.new(0, 5.1, 3.95) * CFrame.Angles(0, 0, math.rad(-30)), "#F2EEE4")
	for side = -1, 1, 2 do
		p(d, "Rope" .. side, Vector3.new(0.1, 4.6, 0.1), CFrame.new(side * 2.0, 5.2, 4.2) * CFrame.Angles(math.rad(-8), 0, math.rad(side * 12)), ROPE, Enum.Material.Fabric)
	end
	-- gouvernail devant la console
	local wheelCF = CFrame.new(0, 5.35, -3.95)
	cyl(d, "WheelHub", 0.35, 0.55, wheelCF * FACE, GOLD, Enum.Material.Metal)
	p(d, "WheelPost", Vector3.new(0.35, 1.0, 0.35), CFrame.new(0, 4.85, -3.9), WOOD, Enum.Material.Wood)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		p(d, "Spoke_" .. i, Vector3.new(0.16, 2.3, 0.16), wheelCF * CFrame.Angles(0, 0, a), WOOD, Enum.Material.Wood)
		p(d, "Rim_" .. i, Vector3.new(0.62, 0.2, 0.2), wheelCF * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.82, 0), WOOD2, Enum.Material.Wood)
		p(d, "Handle_" .. i, Vector3.new(0.2, 0.3, 0.2), wheelCF * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.25, 0), GOLD, Enum.Material.Metal)
	end
	-- coffre ouvert au sol a droite, pieces d'or qui debordent, lumiere chaude
	local chest = CFrame.new(4.7, 0, 1.2) * CFrame.Angles(0, math.rad(-20), 0)
	p(d, "ChestBody", Vector3.new(2.2, 1.2, 1.4), chest * CFrame.new(0, 0.6, 0), WOOD, Enum.Material.Wood)
	p(d, "ChestBand1", Vector3.new(0.18, 1.24, 1.44), chest * CFrame.new(-0.7, 0.6, 0), GOLD, Enum.Material.Metal)
	p(d, "ChestBand2", Vector3.new(0.18, 1.24, 1.44), chest * CFrame.new(0.7, 0.6, 0), GOLD, Enum.Material.Metal)
	p(d, "ChestLid", Vector3.new(2.2, 0.3, 1.4), chest * CFrame.new(0, 1.55, 0.95) * CFrame.Angles(math.rad(-70), 0, 0), WOOD2, Enum.Material.Wood)
	p(d, "ChestGold", Vector3.new(2.0, 0.35, 1.2), chest * CFrame.new(0, 1.3, 0), GOLD, Enum.Material.Metal, { reflect = 0.15 })
	local rng = Random.new(1515)
	for i = 1, 9 do
		local cf = chest * CFrame.new(rng:NextNumber(-1.6, 1.4), 0.05, rng:NextNumber(-1.6, -0.8)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		cyl(d, "Coin_" .. i, 0.08, 0.45, cf * UP, GOLD, Enum.Material.Metal)
	end
	for i = 1, 4 do
		local cf = chest * CFrame.new(rng:NextNumber(-0.8, 0.8), 1.5 + i * 0.05, rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
		cyl(d, "TopCoin_" .. i, 0.08, 0.45, cf * UP, GOLD, Enum.Material.Metal)
	end
	-- tonneau a gauche
	cyl(d, "Barrel", 1.6, 1.3, CFrame.new(-4.6, 0.8, -0.6) * UP, WOOD2, Enum.Material.Wood)
	cyl(d, "BarrelHoop1", 0.15, 1.36, CFrame.new(-4.6, 0.35, -0.6) * UP, "#3A3A40", Enum.Material.Metal)
	cyl(d, "BarrelHoop2", 0.15, 1.36, CFrame.new(-4.6, 1.25, -0.6) * UP, "#3A3A40", Enum.Material.Metal)
	-- eclat dore du tresor (effet natif)
	local glow = fxPart(fx, "TreasureGlow", Vector3.new(1.8, 0.4, 1.0), (chest * CFrame.new(0, 1.5, 0)).Position)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FFC94A")
	light.Range = 8
	light.Brightness = 1.2
	light.Parent = glow
	local e = Instance.new("ParticleEmitter")
	e.Name = "Glint"
	e.Texture = SPARK
	e.Color = ColorSequence.new(Color3.fromHex("FFE28A"))
	e.Rate = 4
	e.Lifetime = NumberRange.new(0.6, 1.0)
	e.Speed = NumberRange.new(0.5, 1.2)
	e.Size = NS(0.5, 0)
	e.LightEmission = 0.7
	e.Parent = glow
	m.Parent = folder
	table.insert(made, m)
end

-- ===== Royal (niveau 24) : blanc et or, velours rouge, couronne geante, joyaux =====
do
	-- planche du 26/11 : Metal rendait l'or kaki et Marble les colonnes bleu glace, tout passe en plastique lisse
	local WHITE, GOLD, VELVET, RUBY, SAPPHIRE, EMERALD = "#F7F3EA", "#F5C542", "#9E1B30", "#E0213F", "#2F6BFF", "#1FC46A"
	local m, d, fx = newTreadmill("Royal", { frame = "#F4F0E6", trim = GOLD, ends = VELVET, arrows = "#FFE08A",
		buttons = GOLD, screen = "#2A0E16" })
	m.BeltEnds.Material = Enum.Material.Fabric
	-- deux colonnes blanches a chapiteau dore
	for side = -1, 1, 2 do
		local x = side * 2.6
		p(d, "ColumnBase" .. side, Vector3.new(1.4, 0.5, 1.4), CFrame.new(x, 0.25, 3.9), GOLD)
		cyl(d, "Column" .. side, 5.2, 1.0, CFrame.new(x, 3.1, 3.9) * UP, WHITE)
		p(d, "ColumnCap" .. side, Vector3.new(1.4, 0.45, 1.4), CFrame.new(x, 5.9, 3.9), GOLD)
	end
	-- linteau dore et rideaux de velours
	p(d, "Lintel", Vector3.new(6.8, 0.6, 1.2), CFrame.new(0, 6.4, 3.9), GOLD)
	for side = -1, 1, 2 do
		p(d, "Curtain" .. side, Vector3.new(1.2, 4.6, 0.25), CFrame.new(side * 1.55, 3.85, 4.15) * CFrame.Angles(0, 0, math.rad(side * -6)), VELVET, Enum.Material.Fabric)
		p(d, "CurtainTie" .. side, Vector3.new(1.0, 0.18, 0.3), CFrame.new(side * 1.45, 3.0, 4.0), GOLD)
	end
	p(d, "Valance", Vector3.new(5.0, 0.6, 0.3), CFrame.new(0, 5.85, 4.2), VELVET, Enum.Material.Fabric)
	-- couronne geante sur le linteau : bandeau, 5 pointes avec perles, joyaux
	local crown = CFrame.new(0, 6.9, 3.9) -- tout reste sous 8 studs (hauteur de UseZone)
	p(d, "CrownBand", Vector3.new(3.2, 0.5, 1.0), crown, GOLD)
	p(d, "CrownVelvet", Vector3.new(2.6, 0.35, 0.7), crown * CFrame.new(0, 0.35, 0), VELVET, Enum.Material.Fabric)
	for i = -2, 2 do
		local h = if i == 0 then 0.55 elseif math.abs(i) == 1 then 0.45 else 0.35
		p(d, "CrownSpike_" .. i, Vector3.new(0.32, h, 0.32), crown * CFrame.new(i * 0.72, 0.3 + h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), GOLD)
		p(d, "CrownPearl_" .. i, Vector3.new(0.3, 0.3, 0.3), crown * CFrame.new(i * 0.72, 0.35 + h, 0), "#FFFFFF", Enum.Material.SmoothPlastic, { shape = Enum.PartType.Ball })
	end
	for i, c in { { -1, RUBY }, { 0, SAPPHIRE }, { 1, EMERALD } } do
		p(d, "CrownJewel_" .. i, Vector3.new(0.38, 0.38, 0.12), crown * CFrame.new(c[1] * 1.0, 0, -0.52) * CFrame.Angles(0, 0, math.rad(45)), c[2], Enum.Material.Glass, { reflect = 0.2 })
	end
	-- coussins de velours et joyaux sur les cotes (pas de tapis au sol : il sortait de UseZone)
	for side = -1, 1, 2 do
		local x = side * 4.6
		p(d, "Pedestal" .. side, Vector3.new(1.2, 1.6, 1.2), CFrame.new(x, 0.8, 2.6), WHITE)
		p(d, "PedestalTop" .. side, Vector3.new(1.35, 0.2, 1.35), CFrame.new(x, 1.7, 2.6), GOLD)
		p(d, "Cushion" .. side, Vector3.new(1.0, 0.3, 1.0), CFrame.new(x, 1.95, 2.6), VELVET, Enum.Material.Fabric)
		p(d, "Gem" .. side, Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, 2.35, 2.6) * CFrame.Angles(math.rad(45), 0, math.rad(45)), if side < 0 then RUBY else SAPPHIRE, Enum.Material.Glass, { reflect = 0.25 })
	end
	-- petit blason sur la console
	p(d, "ConsoleCrest", Vector3.new(0.9, 0.9, 0.12), CFrame.new(0, 4.8, -3.95) * CFrame.Angles(0, 0, math.rad(45)), GOLD)
	p(d, "ConsoleCrestGem", Vector3.new(0.4, 0.4, 0.14), CFrame.new(0, 4.8, -3.97) * CFrame.Angles(0, 0, math.rad(45)), RUBY, Enum.Material.Glass)
	-- scintillement de la couronne (effet natif)
	local glow = fxPart(fx, "CrownSparkle", Vector3.new(3.2, 1.0, 1.0), (crown * CFrame.new(0, 0.5, 0)).Position)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkle"
	e.Texture = SPARK
	e.Color = ColorSequence.new(Color3.fromHex("FFF1B0"))
	e.Rate = 5
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.Size = NS(0.6, 0)
	e.LightEmission = 0.8
	e.Parent = glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FFD970")
	light.Range = 9
	light.Brightness = 1
	light.Parent = glow
	m.Parent = folder
	table.insert(made, m)
end

local lines = {}
for _, m in made do
	local _, s = m:GetBoundingBox()
	local n = 0
	for _, x in m:GetDescendants() do if x:IsA("BasePart") then n += 1 end end
	table.insert(lines, string.format("%s : %d pieces, %.1f x %.1f x %.1f", m.Name, n, s.X, s.Y, s.Z))
end
print("[tapis essais] " .. table.concat(lines, " ; "))
return table.concat(lines, "\n")
