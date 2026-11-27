--!nocheck
-- Kits de produits de la zone 5 : Galerie d'art et Antiquaire (suite des kits, ordre du chef Map). Memes regles que
-- kit_produits_bijouterie.luau et kit_produits_z6.luau : emprise d'un cube de rayon (1,2 x 1,5 au plus) ou 2,35 de long
-- pour les lots muraux, pivot en bas au centre, face avant -Z, PrimaryPart « Base », aucun script. A fusionner ensuite par
-- tools/clement/kits_fusion.luau (MAGASINS = { "GalerieDArt", "Antiquaire" }). Ranges dans
-- ServerStorage/Previews/KITS/<Magasin> (ENV_Z5_<Magasin>_<Nom>). Relancable, mode Edit.

local kits = game:GetService("ServerStorage").Previews:FindFirstChild("KITS")
local GOLD, GOLD2, DARK, WOOD, WOOD2, CREAM = "#F5C842", "#C99A1E", "#2B2F36", "#8A5A33", "#5E3B22", "#F2E9D0"
local MARBLE, BLUE, RED, GREEN, TEAL, PINK = "#EFE9DE", "#2D5BD7", "#D8343C", "#3FAE5A", "#2BB3A8", "#F07AA8"
local folder, PREFIX
local function p(parent, name, size, cf, color, o)
	o = o or {}
	local part = Instance.new("Part")
	part.Name = name
	if o.shape then part.Shape = o.shape end
	part.Size = size
	part.CFrame = cf
	part.Color = Color3.fromHex(color)
	if o.studs then part.Material = Enum.Material.Plastic part.MaterialVariant = "Studs" else part.Material = o.mat or Enum.Material.SmoothPlastic end
	if o.reflect then part.Reflectance = o.reflect end
	if o.transp then part.Transparency = o.transp end
	part.Anchored = true part.CanCollide = false part.CanTouch = false part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function ball(parent, name, s, cf, color) return p(parent, name, Vector3.new(s, s, s), cf, color, { shape = Enum.PartType.Ball }) end
local function cyl(parent, name, len, dia, cf, color, o) o = o or {} o.shape = Enum.PartType.Cylinder return p(parent, name, Vector3.new(len, dia, dia), cf, color, o) end
local UP = CFrame.Angles(0, 0, math.rad(90))
local FACE = CFrame.Angles(0, math.rad(90), 0)
local function newProp(name, baseSize, baseColor, studs)
	local m = Instance.new("Model") m.Name = PREFIX .. name
	local b = p(m, "Base", baseSize, CFrame.new(0, baseSize.Y / 2, 0), baseColor, { studs = studs })
	b.PivotOffset = CFrame.new(0, -baseSize.Y / 2, 0) m.PrimaryPart = b m.Parent = folder
	return m, baseSize.Y
end
local function store(name)
	folder = kits:FindFirstChild(name) or Instance.new("Folder") folder.Name = name folder.Parent = kits folder:ClearAllChildren()
	PREFIX = "ENV_Z5_" .. name .. "_"
end
-- tableau encadre : cadre dore, toile en 3 aplats de couleur (abstrait, lisible de loin)
local function painting(m, cf, w, h, cols)
	p(m, "Frame", Vector3.new(w, h, 0.08), cf, GOLD2)
	p(m, "Canvas", Vector3.new(w - 0.14, h - 0.14, 0.02), cf * CFrame.new(0, 0, -0.05), cols[1])
	p(m, "Shape1", Vector3.new((w - 0.14) * 0.45, (h - 0.14) * 0.5, 0.02), cf * CFrame.new(-w * 0.15, h * 0.1, -0.065), cols[2])
	p(m, "Shape2", Vector3.new((w - 0.14) * 0.3, (h - 0.14) * 0.3, 0.02), cf * CFrame.new(w * 0.2, -h * 0.15, -0.07), cols[3])
end

-- ================= GALERIE D'ART =================
store("GalerieDArt")
do -- 1. chevalet avec un tableau
	local m, h = newProp("EaselPainting", Vector3.new(0.8, 0.06, 0.6), DARK)
	for s = -1, 1, 2 do p(m, "Leg" .. s, Vector3.new(0.06, 1.3, 0.06), CFrame.new(s * 0.28, h + 0.65, 0.05) * CFrame.Angles(math.rad(-8), 0, math.rad(s * -6)), WOOD) end
	p(m, "BackLeg", Vector3.new(0.06, 1.2, 0.06), CFrame.new(0, h + 0.58, 0.28) * CFrame.Angles(math.rad(18), 0, 0), WOOD)
	p(m, "Ledge", Vector3.new(0.7, 0.05, 0.12), CFrame.new(0, h + 0.42, -0.02), WOOD2)
	painting(m, CFrame.new(0, h + 0.8, -0.04) * CFrame.Angles(math.rad(-8), 0, 0), 0.7, 0.6, { CREAM, BLUE, RED })
end
do -- 2. toile encadree posee contre le mur
	local m, h = newProp("FramedCanvas", Vector3.new(1.0, 0.05, 0.35), DARK)
	painting(m, CFrame.new(0, h + 0.5, 0.05) * CFrame.Angles(math.rad(-10), 0, 0), 0.95, 0.95, { "#F3D35A", TEAL, PINK })
end
do -- 3. buste en marbre sur socle
	local m, h = newProp("MarbleBust", Vector3.new(0.6, 0.35, 0.6), DARK)
	p(m, "Chest", Vector3.new(0.5, 0.3, 0.3), CFrame.new(0, h + 0.15, 0), MARBLE, { mat = Enum.Material.Marble })
	p(m, "Neck", Vector3.new(0.16, 0.12, 0.16), CFrame.new(0, h + 0.36, 0), MARBLE, { mat = Enum.Material.Marble })
	p(m, "Head", Vector3.new(0.3, 0.34, 0.32), CFrame.new(0, h + 0.59, 0), MARBLE, { mat = Enum.Material.Marble })
	p(m, "Nose", Vector3.new(0.06, 0.08, 0.06), CFrame.new(0, h + 0.58, -0.18), MARBLE, { mat = Enum.Material.Marble })
	p(m, "Plaque", Vector3.new(0.3, 0.08, 0.02), CFrame.new(0, h - 0.17, -0.31), GOLD)
end
do -- 4. sculpture abstraite (formes empilees)
	local m, h = newProp("AbstractSculpture", Vector3.new(0.7, 0.2, 0.7), MARBLE, true)
	p(m, "Block", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0.05, h + 0.175, 0) * CFrame.Angles(0, math.rad(20), 0), RED)
	ball(m, "Sphere", 0.32, CFrame.new(-0.02, h + 0.51, 0), BLUE)
	p(m, "Ring", Vector3.new(0.06, 0.42, 0.42), CFrame.new(0.05, h + 0.86, 0) * CFrame.Angles(0, math.rad(30), 0), GOLD, { shape = Enum.PartType.Cylinder })
end
do -- 5. boite de peinture ouverte (tubes)
	local m, h = newProp("PaintBox", Vector3.new(1.0, 0.05, 0.7), DARK)
	p(m, "Box", Vector3.new(0.95, 0.16, 0.65), CFrame.new(0, h + 0.08, 0), WOOD)
	p(m, "Lid", Vector3.new(0.95, 0.06, 0.65), CFrame.new(0, h + 0.42, 0.36) * CFrame.Angles(math.rad(-70), 0, 0), WOOD2)
	local cols = { RED, BLUE, "#F3D35A", GREEN, PINK, TEAL }
	for i = 0, 5 do cyl(m, "Tube_" .. i, 0.4, 0.09, CFrame.new(-0.36 + i * 0.145, h + 0.2, -0.03) * FACE, cols[i + 1]) end
end
do -- 6. vase moderne
	local m, h = newProp("ModernVase", Vector3.new(0.55, 0.06, 0.55), DARK)
	cyl(m, "Body", 0.6, 0.42, CFrame.new(0, h + 0.3, 0) * UP, TEAL)
	cyl(m, "Neck", 0.25, 0.24, CFrame.new(0, h + 0.72, 0) * UP, TEAL)
	cyl(m, "Stripe", 0.08, 0.44, CFrame.new(0, h + 0.42, 0) * UP, GOLD)
end
do -- 7. pile de cadres dores
	local m, h = newProp("FrameStack", Vector3.new(1.1, 0.05, 0.6), DARK)
	for i = 0, 3 do
		local w = 0.95 - i * 0.15
		p(m, "Frame_" .. i, Vector3.new(w, 0.08, 0.55 - i * 0.06), CFrame.new(0, h + 0.04 + i * 0.08, 0) * CFrame.Angles(0, math.rad(i * 7 - 10), 0), if i % 2 == 0 then GOLD else GOLD2)
	end
end
do -- 8. pot a pinceaux
	local m, h = newProp("BrushJar", Vector3.new(0.5, 0.05, 0.5), DARK)
	cyl(m, "Jar", 0.4, 0.34, CFrame.new(0, h + 0.2, 0) * UP, "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.35 })
	local cols = { RED, BLUE, "#F3D35A", GREEN }
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		local cf = CFrame.new(math.cos(a) * 0.07, h + 0.45, math.sin(a) * 0.07) * CFrame.Angles(math.sin(a) * 0.18, 0, -math.cos(a) * 0.18)
		p(m, "Handle_" .. i, Vector3.new(0.04, 0.6, 0.04), cf, WOOD2)
		p(m, "Tip_" .. i, Vector3.new(0.06, 0.1, 0.06), cf * CFrame.new(0, 0.33, 0), cols[i + 1])
	end
end
do -- 9. long : rangee de 3 tableaux debout (2,35 x 0,4)
	local m, h = newProp("PaintingRow", Vector3.new(2.35, 0.05, 0.4), DARK)
	local sets = { { CREAM, RED, BLUE }, { "#1E2A4A", "#F3D35A", PINK }, { "#D9EFE6", GREEN, RED } }
	for i = 0, 2 do painting(m, CFrame.new(-0.78 + i * 0.78, h + 0.38, 0.05) * CFrame.Angles(math.rad(-10), 0, 0), 0.7, 0.72, sets[i + 1]) end
end
do -- 10. long : trois petites sculptures sur un socle (2,35 x 0,6)
	local m, h = newProp("SculptureRow", Vector3.new(2.35, 0.25, 0.6), MARBLE, true)
	ball(m, "S1", 0.4, CFrame.new(-0.75, h + 0.2, 0), RED)
	p(m, "S2a", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, h + 0.3, 0) * CFrame.Angles(0, math.rad(45), 0), BLUE)
	cyl(m, "S3", 0.08, 0.5, CFrame.new(0.75, h + 0.25, 0) * FACE, GOLD)
end

-- ================= ANTIQUAIRE =================
store("Antiquaire")
do -- 1. pendule de cheminee
	local m, h = newProp("MantelClock", Vector3.new(0.9, 0.1, 0.45), WOOD2)
	p(m, "Body", Vector3.new(0.8, 0.6, 0.38), CFrame.new(0, h + 0.3, 0), WOOD)
	p(m, "Top", Vector3.new(0.5, 0.15, 0.36), CFrame.new(0, h + 0.67, 0), WOOD2)
	cyl(m, "Face", 0.03, 0.42, CFrame.new(0, h + 0.33, -0.2) * FACE, CREAM)
	cyl(m, "Bezel", 0.02, 0.48, CFrame.new(0, h + 0.33, -0.19) * FACE, GOLD)
	p(m, "HandH", Vector3.new(0.03, 0.13, 0.01), CFrame.new(0, h + 0.38, -0.225), DARK)
	p(m, "HandM", Vector3.new(0.16, 0.025, 0.01), CFrame.new(0.06, h + 0.33, -0.225), DARK)
end
do -- 2. lampe a huile
	local m, h = newProp("OilLamp", Vector3.new(0.5, 0.06, 0.5), GOLD2)
	cyl(m, "Foot", 0.12, 0.36, CFrame.new(0, h + 0.06, 0) * UP, GOLD)
	ball(m, "Tank", 0.36, CFrame.new(0, h + 0.3, 0), GOLD)
	cyl(m, "Chimney", 0.45, 0.2, CFrame.new(0, h + 0.68, 0) * UP, "#FFF1C9", { mat = Enum.Material.Glass, transp = 0.4 })
	p(m, "Flame", Vector3.new(0.06, 0.12, 0.06), CFrame.new(0, h + 0.6, 0), "#FFB13B", { mat = Enum.Material.Neon })
end
do -- 3. theiere en porcelaine
	local m, h = newProp("Teapot", Vector3.new(0.75, 0.04, 0.5), DARK)
	ball(m, "Body", 0.46, CFrame.new(0, h + 0.25, 0), "#F7F5F0")
	cyl(m, "Lid", 0.06, 0.24, CFrame.new(0, h + 0.5, 0) * UP, "#F7F5F0")
	ball(m, "Knob", 0.08, CFrame.new(0, h + 0.56, 0), BLUE)
	p(m, "Spout", Vector3.new(0.26, 0.07, 0.07), CFrame.new(-0.3, h + 0.3, 0) * CFrame.Angles(0, 0, math.rad(35)), "#F7F5F0")
	p(m, "Handle", Vector3.new(0.05, 0.22, 0.07), CFrame.new(0.27, h + 0.28, 0), "#F7F5F0")
	cyl(m, "Band", 0.06, 0.47, CFrame.new(0, h + 0.25, 0) * UP, BLUE)
end
do -- 4. chandelier a trois branches
	local m, h = newProp("Candelabra", Vector3.new(0.6, 0.06, 0.45), GOLD2)
	cyl(m, "Stem", 0.6, 0.07, CFrame.new(0, h + 0.3, 0) * UP, GOLD)
	p(m, "Arms", Vector3.new(0.55, 0.05, 0.06), CFrame.new(0, h + 0.58, 0), GOLD)
	for i = -1, 1 do
		cyl(m, "Cup" .. i, 0.06, 0.12, CFrame.new(i * 0.25, h + 0.62, 0) * UP, GOLD)
		cyl(m, "Candle" .. i, 0.3, 0.07, CFrame.new(i * 0.25, h + 0.8, 0) * UP, CREAM)
		p(m, "Flame" .. i, Vector3.new(0.05, 0.08, 0.05), CFrame.new(i * 0.25, h + 0.99, 0), "#FFB13B", { mat = Enum.Material.Neon })
	end
end
do -- 5. pile de vieux livres
	local m, h = newProp("OldBooks", Vector3.new(0.9, 0.04, 0.6), DARK)
	local cols = { "#7A2E2E", "#2E4A7A", "#3E6B3A", "#6B4A23" }
	for i = 0, 3 do
		p(m, "Book_" .. i, Vector3.new(0.75 - i * 0.06, 0.14, 0.5 - i * 0.03), CFrame.new(0, h + 0.07 + i * 0.14, 0) * CFrame.Angles(0, math.rad(i * 8 - 12), 0), cols[i + 1])
		p(m, "Pages_" .. i, Vector3.new(0.72 - i * 0.06, 0.1, 0.02), CFrame.new(0, h + 0.07 + i * 0.14, 0) * CFrame.Angles(0, math.rad(i * 8 - 12), 0) * CFrame.new(0, 0, -(0.25 - i * 0.015)), CREAM)
	end
end
do -- 6. globe ancien
	local m, h = newProp("Globe", Vector3.new(0.6, 0.06, 0.6), WOOD2)
	cyl(m, "Stand", 0.35, 0.08, CFrame.new(0, h + 0.17, 0) * UP, WOOD)
	ball(m, "Sphere", 0.52, CFrame.new(0, h + 0.62, 0), "#D9C38A")
	p(m, "Land1", Vector3.new(0.2, 0.16, 0.1), CFrame.new(-0.1, h + 0.7, -0.22), "#8C6A3A")
	p(m, "Land2", Vector3.new(0.14, 0.22, 0.1), CFrame.new(0.12, h + 0.55, -0.22), "#8C6A3A")
	-- meridien en anneau carre de 4 barres (blocs, 27/11 : les disques fondus coutent trop de triangles)
	local c = CFrame.new(0, h + 0.62, 0) * CFrame.Angles(0, 0, math.rad(20))
	for _, y in { 0.3, -0.3 } do p(m, "Meridian", Vector3.new(0.04, 0.04, 0.6), c * CFrame.new(0, y, 0), GOLD) end
	for _, z in { 0.3, -0.3 } do p(m, "Meridian", Vector3.new(0.04, 0.64, 0.04), c * CFrame.new(0, 0, z), GOLD) end
end
do -- 7. montre a gousset sur son presentoir
	local m, h = newProp("PocketWatch", Vector3.new(0.55, 0.08, 0.45), "#7A162C")
	p(m, "Post", Vector3.new(0.05, 0.5, 0.05), CFrame.new(0, h + 0.25, 0.1), GOLD)
	p(m, "Hook", Vector3.new(0.2, 0.04, 0.04), CFrame.new(0, h + 0.5, 0.02), GOLD)
	cyl(m, "Case", 0.08, 0.34, CFrame.new(0, h + 0.3, -0.06) * FACE, GOLD, { reflect = 0.12 })
	cyl(m, "Dial", 0.02, 0.27, CFrame.new(0, h + 0.3, -0.105) * FACE, CREAM)
end
do -- 8. vase bleu et blanc
	local m, h = newProp("BlueVase", Vector3.new(0.55, 0.06, 0.55), WOOD2)
	ball(m, "Belly", 0.5, CFrame.new(0, h + 0.3, 0), "#F7F5F0")
	cyl(m, "Neck", 0.3, 0.22, CFrame.new(0, h + 0.65, 0) * UP, "#F7F5F0")
	cyl(m, "Lip", 0.05, 0.3, CFrame.new(0, h + 0.8, 0) * UP, BLUE)
	cyl(m, "Band1", 0.07, 0.51, CFrame.new(0, h + 0.3, 0) * UP, BLUE)
	cyl(m, "Band2", 0.04, 0.42, CFrame.new(0, h + 0.47, 0) * UP, BLUE)
end
do -- 9. long : rangee de vieux livres debout (2,35 x 0,5)
	local m, h = newProp("BookRow", Vector3.new(2.35, 0.04, 0.5), DARK)
	local cols = { "#7A2E2E", "#2E4A7A", "#3E6B3A", "#6B4A23", "#4A2E5A" }
	local x = -1.1
	for i = 0, 12 do -- 13 livres : tient dans 2,35
		local th = 0.12 + (i % 3) * 0.03
		local hh = 0.6 + ((i * 7) % 4) * 0.06
		p(m, "Book_" .. i, Vector3.new(th, hh, 0.44), CFrame.new(x + th / 2, h + hh / 2, 0), cols[i % 5 + 1])
		p(m, "Spine_" .. i, Vector3.new(th + 0.005, 0.04, 0.445), CFrame.new(x + th / 2, h + hh * 0.75, 0), GOLD)
		x += th + 0.02
	end
end
do -- 10. long : service a the en porcelaine (2,35 x 0,6)
	local m, h = newProp("ChinaSet", Vector3.new(2.35, 0.05, 0.6), "#7A162C")
	for i = 0, 3 do
		local x = -0.9 + i * 0.6
		cyl(m, "Saucer_" .. i, 0.03, 0.34, CFrame.new(x, h + 0.015, 0) * UP, "#F7F5F0")
		cyl(m, "Cup_" .. i, 0.18, 0.2, CFrame.new(x, h + 0.12, 0) * UP, "#F7F5F0")
		cyl(m, "Rim_" .. i, 0.03, 0.21, CFrame.new(x, h + 0.2, 0) * UP, BLUE)
	end
end

local lines = {}
for _, n in { "GalerieDArt", "Antiquaire" } do
	for _, m in kits[n]:GetChildren() do
		local _, s = m:GetBoundingBox()
		table.insert(lines, string.format("%s %d %.2fx%.2fx%.2f", m.Name, #m:GetChildren(), s.X, s.Y, s.Z))
	end
end
table.sort(lines)
print("[kits z5] " .. #lines .. " produits")
return table.concat(lines, "\n")
