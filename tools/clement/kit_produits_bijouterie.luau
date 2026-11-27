--!nocheck
-- Kit de produits de la Bijouterie (repasse qualite, choix 6 de Clement du 26/11 : « kits de produits par magasin a la
-- place des cubes, en commencant par la Bijouterie » ; le chef Map les pose). Aujourd'hui les 12 magasins ont les cubes
-- d'une superette (Shelf_*_P* + Shelf_*_C*, FridgeItem). Ce kit : 8 produits de bijouterie en pieces, dans la palette
-- des cubes actuels (velours rouge 7A162C, velours nuit 181A40, or E6BE46, argent D6DAE2, rubis DC2846, saphir 285ADC,
-- emeraude 28AA64, diamant C8F0FF), tenons sur les dessus plats, aucun script. Chaque produit tient dans l'emprise d'un
-- cube de rayon (1,2 x 1,5 au plus, 0,5 a 1,7 de haut) : pivot en bas au centre, face avant -Z, PrimaryPart « Base ».
-- Range dans ServerStorage/Previews/KITS/Bijouterie (ENV_Z4_Bijouterie_<Nom>). Relancable, mode Edit.

local SS = game:GetService("ServerStorage")
local prev = SS:FindFirstChild("Previews")
local kits = prev:FindFirstChild("KITS") or Instance.new("Folder")
kits.Name = "KITS"
kits.Parent = prev
local folder = kits:FindFirstChild("Bijouterie") or Instance.new("Folder")
folder.Name = "Bijouterie"
folder.Parent = kits
folder:ClearAllChildren()

local VELVET, NIGHT, GOLD, SILVER = "#7A162C", "#181A40", "#F5C842", "#D6DAE2" -- planche du 26/11 : Foil rendait l'or verdatre, plastique lisse brillant
local RUBY, SAPPHIRE, EMERALD, DIAMOND, PEARL = "#DC2846", "#285ADC", "#28AA64", "#C8F0FF", "#F6F2EC"

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
	else
		part.Material = o.mat or Enum.Material.SmoothPlastic
	end
	if o.reflect then part.Reflectance = o.reflect end
	if o.transp then part.Transparency = o.transp end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = o.shadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function gem(parent, name, s, cf, color)
	-- pierre taillee : un cube pose sur la pointe, brillant
	return p(parent, name, Vector3.new(s, s, s), cf * CFrame.Angles(math.rad(45), 0, math.rad(45)), color, { mat = Enum.Material.Glass, reflect = 0.35 })
end
local function cyl(parent, name, len, dia, cf, color, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	return p(parent, name, Vector3.new(len, dia, dia), cf, color, o)
end
local UP = CFrame.Angles(0, 0, math.rad(90))
local FACE = CFrame.Angles(0, math.rad(90), 0)

local function newProp(name, baseSize, baseColor, studs)
	local m = Instance.new("Model")
	m.Name = "ENV_Z4_Bijouterie_" .. name
	local b = p(m, "Base", baseSize, CFrame.new(0, baseSize.Y / 2, 0), baseColor, { studs = studs })
	b.PivotOffset = CFrame.new(0, -baseSize.Y / 2, 0)
	m.PrimaryPart = b
	m.Parent = folder
	return m, baseSize.Y
end

-- 1. Ecrin ouvert avec une bague (0,9 x 0,9 au sol)
do
	local m, h = newProp("RingBox", Vector3.new(0.9, 0.4, 0.9), VELVET)
	p(m, "Cushion", Vector3.new(0.72, 0.1, 0.72), CFrame.new(0, h + 0.05, 0), NIGHT, { mat = Enum.Material.Fabric })
	p(m, "Lid", Vector3.new(0.9, 0.12, 0.9), CFrame.new(0, h + 0.4, 0.5) * CFrame.Angles(math.rad(-70), 0, 0), VELVET)
	p(m, "LidLining", Vector3.new(0.75, 0.02, 0.75), CFrame.new(0, h + 0.4, 0.44) * CFrame.Angles(math.rad(-70), 0, 0), "#E9D9B0", { mat = Enum.Material.Fabric })
	cyl(m, "Ring", 0.08, 0.36, CFrame.new(0, h + 0.28, 0) * FACE, GOLD, { reflect = 0.12 })
	gem(m, "Gem", 0.16, CFrame.new(0, h + 0.5, 0), RUBY)
end

-- 2. Buste en velours avec un collier et son pendentif (0,75 x 0,6 au sol, 1,2 de haut)
do
	local m, h = newProp("NecklaceBust", Vector3.new(0.7, 0.12, 0.55), NIGHT, true)
	p(m, "Neck", Vector3.new(0.22, 0.6, 0.22), CFrame.new(0, h + 0.3, 0), NIGHT, { mat = Enum.Material.Fabric })
	p(m, "Chest", Vector3.new(0.7, 0.42, 0.3), CFrame.new(0, h + 0.75, 0), NIGHT, { mat = Enum.Material.Fabric })
	p(m, "Head", Vector3.new(0.3, 0.16, 0.26), CFrame.new(0, h + 1.02, 0), NIGHT, { mat = Enum.Material.Fabric })
	for i = -3, 3 do
		local a = math.rad(i * 17)
		local x, y = math.sin(a) * 0.3, h + 0.92 - (1 - math.cos(a)) * 0.55
		p(m, "Chain_" .. (i + 4), Vector3.new(0.1, 0.06, 0.06), CFrame.new(x, y, -0.17) * CFrame.Angles(0, 0, a), GOLD, { reflect = 0.12 })
	end
	gem(m, "Pendant", 0.16, CFrame.new(0, h + 0.7, -0.19), SAPPHIRE)
end

-- 3. Plateau de pierres taillees (1,2 x 1,0)
do
	local m, h = newProp("GemTray", Vector3.new(1.2, 0.12, 1.0), GOLD, true)
	p(m, "Velvet", Vector3.new(1.04, 0.05, 0.84), CFrame.new(0, h + 0.025, 0), NIGHT, { mat = Enum.Material.Fabric })
	local cols = { RUBY, SAPPHIRE, EMERALD, DIAMOND, RUBY, EMERALD }
	for i = 0, 5 do
		local x, z = (i % 3 - 1) * 0.34, (math.floor(i / 3) - 0.5) * 0.36
		gem(m, "Gem_" .. (i + 1), 0.17, CFrame.new(x, h + 0.16, z), cols[i + 1])
	end
end

-- 4. Coussin avec une montre (1,0 x 0,8)
do
	local m, h = newProp("WatchCushion", Vector3.new(1.0, 0.1, 0.8), GOLD, true)
	p(m, "Cushion", Vector3.new(0.86, 0.3, 0.66), CFrame.new(0, h + 0.15, 0), VELVET, { mat = Enum.Material.Fabric })
	p(m, "Strap", Vector3.new(0.18, 0.04, 0.7), CFrame.new(0, h + 0.32, 0), "#281A1E", { mat = Enum.Material.Fabric })
	cyl(m, "Case", 0.12, 0.42, CFrame.new(0, h + 0.36, -0.02) * UP, GOLD, { reflect = 0.12 })
	cyl(m, "Dial", 0.02, 0.32, CFrame.new(0, h + 0.43, -0.02) * UP, PEARL)
	p(m, "HandH", Vector3.new(0.03, 0.01, 0.11), CFrame.new(0, h + 0.445, -0.06), "#141418")
	p(m, "HandM", Vector3.new(0.13, 0.01, 0.025), CFrame.new(0.05, h + 0.445, -0.02), "#141418")
end

-- 5. Vitrine en verre avec un gros diamant (0,9 x 0,9, 1,1 de haut)
do
	local m, h = newProp("DiamondCase", Vector3.new(0.9, 0.25, 0.9), GOLD, true)
	p(m, "Pad", Vector3.new(0.5, 0.08, 0.5), CFrame.new(0, h + 0.04, 0), VELVET, { mat = Enum.Material.Fabric })
	gem(m, "Diamond", 0.34, CFrame.new(0, h + 0.36, 0), DIAMOND)
	p(m, "Glass", Vector3.new(0.82, 0.8, 0.82), CFrame.new(0, h + 0.4, 0), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.75, shadow = false })
	p(m, "Cap", Vector3.new(0.9, 0.06, 0.9), CFrame.new(0, h + 0.83, 0), GOLD, { reflect = 0.12 })
end

-- 6. Support en T avec un rang de perles (0,75 x 0,5, 1,3 de haut)
do
	local m, h = newProp("PearlStand", Vector3.new(0.6, 0.1, 0.45), SILVER, true)
	p(m, "Post", Vector3.new(0.1, 1.0, 0.1), CFrame.new(0, h + 0.5, 0), SILVER, { reflect = 0.12 })
	p(m, "Bar", Vector3.new(0.7, 0.08, 0.1), CFrame.new(0, h + 1.0, 0), SILVER, { reflect = 0.12 })
	for i = -4, 4 do
		local a = math.rad(i * 15)
		local x, y = math.sin(a) * 0.3, h + 0.96 - (1 - math.cos(a)) * 0.9
		p(m, "Pearl_" .. (i + 5), Vector3.new(0.09, 0.09, 0.09), CFrame.new(x, y, -0.07), PEARL, { shape = Enum.PartType.Ball, reflect = 0.15 })
	end
end

-- 7. Lingots d'or empiles (1,05 x 0,75)
do
	local m, h = newProp("GoldBars", Vector3.new(1.05, 0.06, 0.75), NIGHT)
	for i, t in { { -0.25, 0, 0 }, { 0.25, 0, 0 }, { 0, 1, 90 } } do
		p(m, "Bar_" .. i, Vector3.new(0.45, 0.2, 0.7), CFrame.new(t[1], h + 0.1 + t[2] * 0.2, 0) * CFrame.Angles(0, math.rad(t[3]), 0), GOLD, { reflect = 0.12 })
	end
end

-- 8. Carte de boucles d'oreilles debout (0,75 x 0,45, 0,9 de haut)
do
	local m, h = newProp("EarringCard", Vector3.new(0.6, 0.08, 0.35), GOLD, true)
	p(m, "Card", Vector3.new(0.55, 0.75, 0.04), CFrame.new(0, h + 0.38, 0) * CFrame.Angles(math.rad(-8), 0, 0), NIGHT, { mat = Enum.Material.Fabric })
	for s = -1, 1, 2 do
		cyl(m, "Hoop" .. s, 0.03, 0.2, CFrame.new(s * 0.14, h + 0.5, -0.06) * FACE, GOLD, { reflect = 0.12 })
		gem(m, "Drop" .. s, 0.1, CFrame.new(s * 0.14, h + 0.33, -0.07), EMERALD)
	end
end

-- 9. Lots longs des rayons muraux (Shelf_*_Lot, 2,4 a 3 de long ; demande du chef Map) : grand axe en X, face avant -Z
-- 9a. Presentoir long a colliers (2,35 x 0,6, 1,15 de haut)
do
	local m, h = newProp("NecklaceRail", Vector3.new(2.35, 0.1, 0.6), GOLD, true)
	for s = -1, 1, 2 do
		p(m, "Post" .. s, Vector3.new(0.1, 0.95, 0.1), CFrame.new(s * 1.08, h + 0.475, 0), GOLD, { reflect = 0.12 })
	end
	p(m, "Bar", Vector3.new(2.3, 0.08, 0.08), CFrame.new(0, h + 0.96, 0), GOLD, { reflect = 0.12 })
	local gems = { RUBY, SAPPHIRE, EMERALD, DIAMOND, RUBY }
	for k = 1, 5 do
		local cx = -0.88 + (k - 1) * 0.44
		for i = -2, 2 do
			local a = math.rad(i * 22)
			p(m, string.format("Chain_%d_%d", k, i + 3), Vector3.new(0.08, 0.05, 0.05),
				CFrame.new(cx + math.sin(a) * 0.15, h + 0.92 - (1 - math.cos(a)) * 0.45, -0.05) * CFrame.Angles(0, 0, a), GOLD, { reflect = 0.12 })
		end
		gem(m, "Pendant_" .. k, 0.12, CFrame.new(cx, h + 0.73, -0.06), gems[k])
	end
end
-- 9b. Rangee d'ecrins ouverts sur un chemin de velours (2,35 x 0,65, 0,65 de haut)
do
	local m, h = newProp("RingBoxRow", Vector3.new(2.35, 0.08, 0.65), NIGHT)
	local gems = { RUBY, DIAMOND, SAPPHIRE, EMERALD }
	for k = 1, 4 do
		local x = -0.84 + (k - 1) * 0.56
		p(m, "Box_" .. k, Vector3.new(0.44, 0.22, 0.44), CFrame.new(x, h + 0.11, 0.02), VELVET)
		p(m, "Lid_" .. k, Vector3.new(0.44, 0.07, 0.44), CFrame.new(x, h + 0.36, 0.25) * CFrame.Angles(math.rad(-75), 0, 0), VELVET)
		cyl(m, "Ring_" .. k, 0.05, 0.2, CFrame.new(x, h + 0.3, 0.02) * FACE, if k % 2 == 0 then SILVER else GOLD, { reflect = 0.12 })
		gem(m, "Gem_" .. k, 0.09, CFrame.new(x, h + 0.42, 0.02), gems[k])
	end
end

local lines = {}
for _, m in folder:GetChildren() do
	local _, s = m:GetBoundingBox()
	table.insert(lines, string.format("%s %d pieces %.2f x %.2f x %.2f", m.Name, #m:GetChildren(), s.X, s.Y, s.Z))
end
table.sort(lines)
print("[kit bijouterie] " .. #lines .. " produits")
return table.concat(lines, "\n")
