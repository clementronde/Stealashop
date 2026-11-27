--!nocheck
-- 25 tapis (Clement 26/11) : Gold v2 en pieces Studio (methode A), a comparer avec le Gold actuel (GLB Claude Design)
-- et la version Blender (methode B). References : 05_angel_gold.png (colonnes ivoire, torches dorees, ailes),
-- tapis_bifrost_dore.webp (grand portique dore, montants epais a runes lumineuses, liseré a damier),
-- 13 « +4 / Etape » (portique devant le coureur, chevrons blancs sur la bande).
-- Meme repere et meme bande que le Gold actuel : Belt (Part 5,16 x 0,05 x 6,3, dessus a 0,865, z 0,95) et BeltEnds
-- copies de l'actuel avec BeltTexture, UsePoint, RunBurstPoint ; Frame (BasePart) porte UpgradePoint (8,4 ; 0 ; -4) ;
-- GoldFX (effets du chef VFX) recopie et recale sur les nouveaux piliers ; GoldGlow = une seule union Neon (le code la
-- fait pulser), Halo1 a Halo4 tournent (code). Emprise <= 12,8 x 13,1 (z -7,3 a +5,8), hauteur <= 10. Aucun script.
-- Range dans ServerStorage/Previews/TREADMILLS/PLOT_Treadmill_Gold_v2. Relancable, mode Edit.

local SS = game:GetService("ServerStorage")
local src = game:GetService("ReplicatedStorage").Assets.Plots.PLOT_Treadmill_Gold
local folder = SS.Previews:FindFirstChild("TREADMILLS") or Instance.new("Folder")
folder.Name = "TREADMILLS"
folder.Parent = SS.Previews
local NAME = "PLOT_Treadmill_Gold_v2"
local old = folder:FindFirstChild(NAME)
if old then old:Destroy() end

-- comparaison du 26/11 : neon presque blanc sur or plus fonce et piliers bleu nuit (bifrost), sinon le neon ne ressortait pas
local GOLD, GOLD2, IVORY, DARK, GLOW, WHITE, NAVY, GOLD3 = "#FFC21A", "#C98A0B", "#F5F1E6", "#23242A", "#FFF7CF", "#FFFFFF", "#33406B", "#E8A812"

local m = Instance.new("Model")
m.Name = NAME
m:SetAttribute("WidthScale", 1.5)
m.Parent = folder -- UnionAsync demande des pieces dans le DataModel

local function group(name)
	local g = Instance.new("Model")
	g.Name = name
	g.Parent = m
	return g
end
local trim, columns, wings, glowSrc = group("Trim"), group("Columns"), group("Wings"), {}

local function p(parent, name, size, cf, color, o)
	o = o or {}
	local part = Instance.new(o.wedge and "WedgePart" or "Part")
	part.Name = name
	if o.shape then part.Shape = o.shape end
	part.Size = size
	part.CFrame = cf
	part.Color = Color3.fromHex(color)
	if o.studs then
		part.Material = Enum.Material.Plastic
		part.MaterialVariant = "Studs"
	elseif o.neon then
		part.Material = Enum.Material.Neon
		part.CastShadow = false
	else
		part.Material = Enum.Material.SmoothPlastic
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function box(parent, name, x0, x1, y0, y1, z0, z1, color, o)
	return p(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, o)
end
-- piece qui brille : rangee a part, fondue en une seule union GoldGlow a la fin
local function glow(name, x0, x1, y0, y1, z0, z1)
	local g = box(m, name, x0, x1, y0, y1, z0, z1, GLOW, { neon = true })
	table.insert(glowSrc, g)
	return g
end
local function cyl(parent, name, len, dia, cf, color, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	return p(parent, name, Vector3.new(len, dia, dia), cf, color, o)
end
local UP = CFrame.Angles(0, 0, math.rad(90))

-- ===== bande : copiee de l'actuel (meme longueur, meme hauteur, meme texture qui defile) =====
for _, n in { "Belt", "BeltEnds" } do
	src[n]:Clone().Parent = m
end

-- ===== socle et longerons =====
m.Belt.BeltTexture.Color3 = Color3.fromHex("FFE07A") -- bande teintee or (references 17, 18 : bande du theme)
local DECK_Z0, DECK_Z1 = -3.2, 5.1
local frame = box(m, "Frame", -3.7, 3.7, 0, 0.62, DECK_Z0, DECK_Z1, GOLD, { studs = true })
local up = Instance.new("Attachment")
up.Name = "UpgradePoint"
up.WorldPosition = Vector3.new(8.4, 0, -4)
-- points d'attache communs aux 25 tapis (plan du chef VFX, 26/11) ; l'arche est a l'avant, au-dessus de la console
for name, pos in { PostTop_L = Vector3.new(-3.75, 7.6, -3.95), PostTop_R = Vector3.new(3.75, 7.6, -3.95), ArchTop = Vector3.new(0, 10.0, -3.95), FloorCenter = Vector3.new(0, 0, 0.95) } do
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = frame
	a.WorldCFrame = CFrame.new(pos)
end
up.Parent = frame
box(trim, "DeckLip", -3.85, 3.85, 0, 0.25, DECK_Z0 - 0.15, DECK_Z1 + 0.15, GOLD2)
for side = -1, 1, 2 do
	local xi, xo = side * 2.62, side * 3.7
	box(trim, "Rail" .. side, math.min(xi, xo), math.max(xi, xo), 0.62, 1.25, DECK_Z0, DECK_Z1, GOLD, { studs = true })
	box(trim, "RailCap" .. side, math.min(xi, xo) - 0.02, math.max(xi, xo) + 0.02, 1.25, 1.4, DECK_Z0, DECK_Z1, GOLD2)
	-- liseré neon le long du bord interieur du longeron
	local gx = side * 2.68
	glow("RailGlow" .. side, gx - 0.07, gx + 0.07, 1.4, 1.5, DECK_Z0 + 0.3, DECK_Z1 - 0.3)
	-- damier or / ivoire sur la face exterieure (bifrost)
	local x = side * 3.86
	for k = 0, 15 do
		local z0 = DECK_Z0 + 0.1 + k * 0.5
		local col = if k % 2 == 0 then NAVY else GOLD2
		box(trim, "Checker" .. side .. "_" .. k, x - 0.06, x + 0.06, 0.3, 0.6, z0, z0 + 0.5, col)
	end
end
-- marche a l'arriere
box(trim, "RearStep", -3.7, 3.7, 0, 0.4, DECK_Z1, DECK_Z1 + 0.6, GOLD2, { studs = true })

-- ===== chevrons sur la bande (blancs, neon doux) =====
-- pas de chevrons en pieces : ceux de la BeltTexture defilent deja (teinte or)

-- ===== grand portique a l'avant (au-dessus de la console) =====
local PZ0, PZ1 = -4.7, -3.2
for side = -1, 1, 2 do
	local x0, x1 = side * 3.0, side * 4.5
	local lo, hi = math.min(x0, x1), math.max(x0, x1)
	box(trim, "PillarBase" .. side, lo - 0.2, hi + 0.2, 0, 0.9, PZ0 - 0.2, PZ1 + 0.2, GOLD2, { studs = true })
	box(columns, "Pillar" .. side, lo, hi, 0.9, 7.6, PZ0, PZ1, NAVY)
	for _, y in { 2.6, 5.0 } do
		box(trim, "PillarBand" .. side .. "_" .. y, lo - 0.08, hi + 0.08, y, y + 0.3, PZ0 - 0.08, PZ1 + 0.08, GOLD)
	end
	-- runes lumineuses sur la face interieure et la face arriere (vers le coureur)
	local fx = side * 3.0 - side * 0.03
	glow("RuneIn" .. side .. "_1", fx - 0.04, fx + 0.04, 1.3, 2.3, -4.2, -3.7)
	glow("RuneIn" .. side .. "_2", fx - 0.04, fx + 0.04, 3.1, 4.6, -4.35, -4.05)
	glow("RuneIn" .. side .. "_3", fx - 0.04, fx + 0.04, 5.5, 7.1, -4.1, -3.8)
	local cx = (lo + hi) / 2
	glow("RuneBack" .. side .. "_1", cx - 0.12, cx + 0.12, 1.3, 2.3, PZ1 - 0.04, PZ1 + 0.04)
	glow("RuneBack" .. side .. "_2", cx - 0.35, cx + 0.35, 3.3, 3.42, PZ1 - 0.04, PZ1 + 0.04)
	glow("RuneBack" .. side .. "_3", cx - 0.12, cx + 0.12, 5.5, 7.1, PZ1 - 0.04, PZ1 + 0.04)
end
-- linteau dore a studs, frise neon dessous
box(trim, "Lintel", -4.9, 4.9, 7.6, 8.5, PZ0 - 0.25, PZ1 + 0.25, GOLD3, { studs = true })
box(trim, "LintelBand", -5.0, 5.0, 7.45, 7.65, PZ0 - 0.3, PZ1 + 0.3, GOLD2)
glow("LintelGlow", -3.0, 3.0, 7.36, 7.45, PZ0, PZ1) -- dessous du linteau lumineux
-- contour neon de l'arche vu par le coureur (reference 4)
for side = -1, 1, 2 do
	glow("ArchEdge" .. side, math.min(side * 3.0, side * 3.14), math.max(side * 3.0, side * 3.14), 0.9, 7.45, PZ1, PZ1 + 0.06)
	glow("ArchInner" .. side, math.min(side * 2.97, side * 3.03), math.max(side * 2.97, side * 3.03), 0.9, 7.4, PZ0 + 0.1, PZ0 + 0.3)
end
-- embleme : disque solaire dore au centre, anneau neon
local emb = CFrame.new(0, 9.05, -3.95)
cyl(trim, "SunDisc", 0.5, 1.9, emb * CFrame.Angles(0, math.rad(90), 0), GOLD2)
cyl(trim, "SunCore", 0.6, 1.2, emb * CFrame.Angles(0, math.rad(90), 0), GOLD)
local ring = cyl(m, "SunRing", 0.12, 1.55, emb * CFrame.new(0, 0, 0.32) * CFrame.Angles(0, math.rad(90), 0), GLOW, { neon = true })
table.insert(glowSrc, ring)
-- ailes : 4 plumes en escalier de chaque cote, qui montent et s'ouvrent depuis l'embleme
for side = -1, 1, 2 do
	for k = 1, 4 do
		local len = 1.6 + k * 0.35
		local x = side * (0.9 + k * 0.62)
		local y = 8.75 + (5 - k) * 0.18
		local feather = p(wings, "Feather" .. side .. "_" .. k, Vector3.new(len, 0.42, 0.5),
			CFrame.new(x, y, -3.95) * CFrame.Angles(0, 0, math.rad(side * (18 + k * 7))), IVORY)
		if k == 4 then
			glow("WingEdge" .. side, 0, 0, 0, 0, 0, 0).CFrame = feather.CFrame * CFrame.new(0, 0.24, 0)
			glowSrc[#glowSrc].Size = Vector3.new(len, 0.08, 0.52)
		end
	end
end

-- ===== console entre les piliers, face au coureur =====
box(trim, "ConsolePost", -0.45, 0.45, 0.62, 3.6, -3.75, -3.15, GOLD2)
box(trim, "ConsoleBox", -2.3, 2.3, 3.6, 4.45, -3.9, -3.0, GOLD3, { studs = true })
box(trim, "ConsoleLip", -2.4, 2.4, 4.45, 4.6, -3.95, -2.95, GOLD2)
local screen = box(m, "ConsoleScreen", -1.05, 1.05, 3.88, 4.18, -3.0, -2.97, DARK)
local buttons = Instance.new("Model")
buttons.Name = "ConsoleButtons"
buttons.Parent = m
for i, x in { -1.7, -1.35, 1.35, 1.7 } do
	cyl(buttons, "Button_" .. i, 0.12, 0.26, CFrame.new(x, 4.03, -2.95) * CFrame.Angles(0, math.rad(90), 0), GLOW, { neon = true })
end
-- rambardes de la console vers les piliers
for side = -1, 1, 2 do
	box(trim, "Handrail" .. side, side * 2.3, side * 3.0, 4.0, 4.3, -3.6, -3.3, GOLD2)
	if side < 0 then
		trim["Handrail" .. side].Size = Vector3.new(0.7, 0.3, 0.3)
		trim["Handrail" .. side].CFrame = CFrame.new(-2.65, 4.15, -3.45)
	else
		trim["Handrail" .. side].Size = Vector3.new(0.7, 0.3, 0.3)
		trim["Handrail" .. side].CFrame = CFrame.new(2.65, 4.15, -3.45)
	end
end

-- ===== deux colonnes-torches a l'arriere (angel gold) =====
for side = -1, 1, 2 do
	local x, z = side * 4.75, 4.4
	box(trim, "TorchBase" .. side, x - 0.75, x + 0.75, 0, 0.5, z - 0.75, z + 0.75, GOLD2, { studs = true })
	cyl(columns, "TorchColumn" .. side, 3.2, 1.0, CFrame.new(x, 2.1, z) * UP, NAVY)
	cyl(trim, "TorchRing" .. side, 0.25, 1.15, CFrame.new(x, 1.0, z) * UP, GOLD)
	box(trim, "TorchCap" .. side, x - 0.7, x + 0.7, 3.7, 4.05, z - 0.7, z + 0.7, GOLD, { studs = true })
	box(trim, "Bowl" .. side, x - 0.55, x + 0.55, 4.05, 4.45, z - 0.55, z + 0.55, GOLD2)
	local flame = glow("Flame" .. side, x - 0.3, x + 0.3, 4.45, 5.15, z - 0.3, z + 0.3)
	flame.CFrame = flame.CFrame * CFrame.Angles(0, math.rad(45), 0)
	-- petite colonne a l'avant aussi, pour la symetrie des 4 halos (devant les piliers du portique)
end

-- ===== GoldGlow : une seule union Neon =====
local union = glowSrc[1]:UnionAsync({ table.unpack(glowSrc, 2) })
union.Name = "GoldGlow"
union.UsePartColor = true
union.Color = Color3.fromHex(GLOW)
union.Material = Enum.Material.Neon
union.CastShadow = false
union.Anchored = true
union.CanCollide = false
union.CanTouch = false
union.CanQuery = false
union.Parent = m
for _, g in glowSrc do g:Destroy() end

-- ===== collisions invisibles et zone d'usage =====
local function collider(name, x0, x1, y0, y1, z0, z1, solid)
	local c = box(m, name, x0, x1, y0, y1, z0, z1, "#A3A2A5")
	c.Transparency = 1
	c.CanCollide = solid ~= false
	return c
end
collider("Collision_Base", -3.85, 3.85, 0, 0.83, DECK_Z0, DECK_Z1 + 0.6)
collider("Collision_Front", -4.9, 4.9, 0, 8.5, PZ0 - 0.25, -3.0)
collider("Collision_Rear", -3.85, 3.85, 0.83, 1.25, DECK_Z1 - 0.05, DECK_Z1)
collider("Collision_TorchL", -5.5, -4.0, 0, 4.45, 3.65, 5.15)
collider("Collision_TorchR", 4.0, 5.5, 0, 4.45, 3.65, 5.15)
local useZone = src.UseZone:Clone()
useZone.Parent = m

-- ===== effets du chef VFX : GoldFX recopie, recale sur les nouveaux elements =====
local fx = src.GoldFX:Clone()
fx.Parent = m
local function moveTo(part, pos)
	if part then part.CFrame = CFrame.new(pos) end
end
moveTo(fx.Halo1, Vector3.new(-3.75, 10.0, -3.95)) -- au-dessus des piliers... sous le plafond de 10
moveTo(fx.ColSparkle1, Vector3.new(-3.75, 8.8, -3.95))
moveTo(fx.Halo2, Vector3.new(3.75, 10.0, -3.95))
moveTo(fx.ColSparkle2, Vector3.new(3.75, 8.8, -3.95))
moveTo(fx.Halo3, Vector3.new(-4.75, 5.4, 4.4))
moveTo(fx.ColSparkle3, Vector3.new(-4.75, 4.9, 4.4))
moveTo(fx.Halo4, Vector3.new(4.75, 5.4, 4.4))
moveTo(fx.ColSparkle4, Vector3.new(4.75, 4.9, 4.4))
moveTo(fx.WingFX, Vector3.new(0, 9.2, -3.95))
fx.Halo1.CFrame = CFrame.new(-3.75, 9.0, -3.95)
fx.Halo2.CFrame = CFrame.new(3.75, 9.0, -3.95)

m.WorldPivot = CFrame.new()

local n, tris = 0, 0
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		n += 1
		if d:IsA("Part") then
			tris += if d.Shape == Enum.PartType.Cylinder then 48 elseif d.Shape == Enum.PartType.Ball then 200 else 12
		elseif d:IsA("WedgePart") then
			tris += 8
		elseif d:IsA("MeshPart") then
			tris += 80
		elseif d:IsA("UnionOperation") then
			tris += 12 * #glowSrc
		end
	end
end
local _, s = m:GetBoundingBox()
local r = string.format("%s : %d pieces visibles, ~%d triangles, %.1f x %.1f x %.1f", NAME, n, tris, s.X, s.Y, s.Z)
print("[gold v2] " .. r)
return r
