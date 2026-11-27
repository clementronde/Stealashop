--!nocheck
-- Fonctions communes des kits de produits (chef 3D, 26/11), pour les zones 1 a 4. A coller EN TETE de chaque script
-- kit_produits_z<n>.luau quand on le lance dans la barre de commande (Studio n'a pas de require de fichier disque).
-- Regles : emprise d'un cube de rayon (1,2 x 1,5 au plus) ou 2,35 de long pour les lots muraux, pivot en bas au centre,
-- face avant -Z, PrimaryPart « Base », aucun script, ni collision ni toucher ni requete. Ce qui brille est en Neon :
-- tools/clement/kits_fusion.luau le garde a part (« Glow »).
local kits = game:GetService("ServerStorage").Previews:FindFirstChild("KITS")
local folder, PREFIX
local function p(parent, name, size, cf, color, o)
	o = o or {}
	local part = Instance.new("Part") part.Name = name
	if o.shape then part.Shape = o.shape end
	part.Size = size part.CFrame = cf part.Color = Color3.fromHex(color)
	if o.studs then part.Material = Enum.Material.Plastic part.MaterialVariant = "Studs" else part.Material = o.mat or Enum.Material.SmoothPlastic end
	if part.Material == Enum.Material.Neon then part.CastShadow = false end
	if o.reflect then part.Reflectance = o.reflect end
	if o.transp then part.Transparency = o.transp end
	part.Anchored = true part.CanCollide = false part.CanTouch = false part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function ball(parent, name, s, cf, color, o) o = o or {} o.shape = Enum.PartType.Ball return p(parent, name, Vector3.new(s, s, s), cf, color, o) end
local function cyl(parent, name, len, dia, cf, color, o) o = o or {} o.shape = Enum.PartType.Cylinder return p(parent, name, Vector3.new(len, dia, dia), cf, color, o) end
local function neon(parent, name, size, cf, color) return p(parent, name, size, cf, color, { mat = Enum.Material.Neon }) end
local UP = CFrame.Angles(0, 0, math.rad(90))
local FACE = CFrame.Angles(0, math.rad(90), 0)
local function newProp(name, baseSize, baseColor, studs)
	local m = Instance.new("Model") m.Name = PREFIX .. name
	local b = p(m, "Base", baseSize, CFrame.new(0, baseSize.Y / 2, 0), baseColor, { studs = studs })
	b.PivotOffset = CFrame.new(0, -baseSize.Y / 2, 0) m.PrimaryPart = b m.Parent = folder
	return m, baseSize.Y
end
local function store(zone, name)
	folder = kits:FindFirstChild(name) or Instance.new("Folder") folder.Name = name folder.Parent = kits folder:ClearAllChildren()
	PREFIX = "ENV_Z" .. zone .. "_" .. name .. "_"
end
local function report(names)
	local lines = {}
	for _, n in names do
		for _, m in kits[n]:GetChildren() do
			local _, s = m:GetBoundingBox()
			table.insert(lines, string.format("%s %d %.2fx%.2fx%.2f", m.Name, #m:GetChildren(), s.X, s.Y, s.Z))
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
