--!nocheck
-- Accessoires de la nouvelle ouverture du colis (L-236, L-237), Claude de Clément, 2026-11-18.
-- Rangés dans ReplicatedStorage/Assets/Unbox (proposé, à confirmer avec Ironix dans la liaison).
--
-- 5 outils tenus en main :
--   Model, PrimaryPart `Handle` = petite MeshPart invisible au centre du poing, sans rotation ; pivot du
--   modèle sur `Handle`, soudé sur RightGripAttachment. Prise du jeu (comme TOOL_Masse, TOOL_Marteau) : manche
--   le long de +Y de `Handle`, face qui frappe vers −Z ; la scie garde sa lame vers −Z (voir TURN).
--   Les autres pièces sont soudées à `Handle` (WeldConstraint `WeldToHandle`), toutes ancrées, Massless,
--   sans collision ni contact ni requête (le code les désancre en les mettant en main, comme les TOOL_).
--   Attachment `HitPoint` dans `Handle` : la partie qui touche le colis.
--   Masse et pied-de-biche : Attachment `GripLeft` dans `Handle`, l'endroit de la main gauche.
-- 5 objets jetés pendant la fouille (ENV_Unbox_Junk_*) : Model, PrimaryPart `Body`, pivot en bas au centre,
--   pièces soudées à `Body`, ancrées, Massless, sans collision.
-- Aucun script. Parts en style studs (les Parts n'ont pas de CollisionFidelity : leur collision est déjà
-- leur boîte). Triangles comptés : 12 par bloc, 76 par cylindre. Relançable. Mode Edit, annulable.
local CHS = game:GetService("ChangeHistoryService")
local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local rec = CHS:TryBeginRecording("Accessoires de l'ouverture du colis")

local folder = Assets:FindFirstChild("Unbox") or Instance.new("Folder")
folder.Name = "Unbox"
folder.Parent = Assets

local INK, STEEL, STEEL_D = "#1B1B24", "#C9CFD8", "#6B7280"
local RED, YELLOW, WOOD = "#E8413C", "#FFC52E", "#B07A47"

local function newModel(name)
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- p(modèle, nom, taille, CFrame local, couleur, matière, options { studs, shape, transp, reflect })
local function p(m, name, size, cf, color, mat, o)
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
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = o.transp or 0
	if o.reflect then part.Reflectance = o.reflect end
	if part.Material == Enum.Material.Neon or part.Transparency > 0.3 then part.CastShadow = false end
	part.Parent = m
	return part
end

-- Poignée `Handle` : petite MeshPart invisible (0,3 stud) au centre du poing, sans rotation. Le ContractChecker
-- veut un MeshPart pour un TOOL_ : maillage de poignée de TOOL_Marteau.Handle, CollisionFidelity Box.
local GRIP_MESH = Assets.Tools.TOOL_Marteau.Handle
local function handle(m)
	local h = GRIP_MESH:Clone()
	for _, c in h:GetChildren() do c:Destroy() end
	h.Name = "Handle"
	h.Size = Vector3.new(0.3, 0.3, 0.3)
	h.CFrame = CFrame.new(0, 0, 0)
	h.Transparency = 1
	h.CastShadow = false
	h.Anchored, h.Massless = true, true
	h.CanCollide, h.CanTouch, h.CanQuery = false, false, false
	h.CollisionFidelity = Enum.CollisionFidelity.Box
	h.Parent = m
	return h
end

-- Prise du jeu (validée par Clément le 2026-11-18) : comme tous les outils du jeu (TOOL_Masse, TOOL_Marteau,
-- TOOL_Batte…), le manche le long de +Y du Handle (il traverse le poing) et la face qui frappe vers −Z. Les outils
-- sont décrits plus bas manche le long de −Z, puis tournés ici d'un quart de tour autour du Handle (new = N * old).
-- La scie ne tourne pas : sa lame le long de l'avant-bras est la bonne prise.
local Q = CFrame.Angles(math.rad(90), 0, 0) -- (x, y, z) → (x, −z, y)
local TURN = {
	TOOL_Unbox_Sledgehammer = Q,
	TOOL_Unbox_Crowbar = Q,
	TOOL_Unbox_Magnifier = Q,
	TOOL_Unbox_Drill = Q * CFrame.Angles(0, 0, math.pi), -- (x, y, z) → (−x, −z, −y) : poignée le long de +Y, mèche vers −Z
}

local function finish(m, primary, pivotOffset)
	local N = TURN[m.Name]
	if N then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d ~= primary then
				d.CFrame = primary.CFrame * N * primary.CFrame:ToObjectSpace(d.CFrame)
			end
		end
		for _, a in primary:GetChildren() do
			if a:IsA("Attachment") then a.CFrame = N * a.CFrame end
		end
	end
	m.PrimaryPart = primary
	primary.PivotOffset = pivotOffset or CFrame.identity
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Name = "WeldToHandle"
			w.Part0 = primary
			w.Part1 = d
			w.Parent = d
		end
	end
	m.Parent = folder
	return m
end

local function att(part, name, pos, axis)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	if axis then a.Axis = axis end
	a.Parent = part
	return a
end

local made = {}

-- Outils ---------------------------------------------------------------------------------------------
-- Repère de chaque outil = celui de `Handle` (CFrame sans rotation, au centre du poing), convention des Tool
-- Roblox, celle des 7 animations Unbox_* (L-246) : `Handle` est soudé sur RightGripAttachment, l'outil part
-- vers −Z de `Handle` et son dessus est vers +Y. Mesures de la session des animations (prototype validé).

-- Masse à deux mains : manche de z +0,35 à −2,25, tête 0,6 × 1,15 × 0,6 en (0, 0, −2,15), face en −Y.
do
	local m = newModel("TOOL_Unbox_Sledgehammer")
	local h = handle(m)
	p(m, "GripLow", Vector3.new(0.3, 0.3, 0.7), CFrame.new(0, 0, 0), INK, Enum.Material.Fabric)
	p(m, "Shaft", Vector3.new(0.22, 0.22, 2.6), CFrame.new(0, 0, -0.95), WOOD, Enum.Material.Wood)
	p(m, "GripHigh", Vector3.new(0.28, 0.28, 0.45), CFrame.new(0, 0, -0.62), INK, Enum.Material.Fabric)
	p(m, "Pommel", Vector3.new(0.34, 0.34, 0.12), CFrame.new(0, 0, 0.41), RED)
	p(m, "Head", Vector3.new(0.6, 1.15, 0.6), CFrame.new(0, 0, -2.15), "#3A404B", nil, { studs = true })
	p(m, "HeadBand", Vector3.new(0.64, 0.4, 0.64), CFrame.new(0, 0, -2.15), RED)
	p(m, "FaceStrike", Vector3.new(0.5, 0.08, 0.5), CFrame.new(0, -0.58, -2.15), STEEL, Enum.Material.Metal)
	p(m, "FaceBack", Vector3.new(0.5, 0.08, 0.5), CFrame.new(0, 0.58, -2.15), STEEL, Enum.Material.Metal)
	att(h, "HitPoint", Vector3.new(0, -0.575, -2.15))
	att(h, "GripLeft", Vector3.new(0, 0, -0.62))
	table.insert(made, finish(m, h))
end

-- Scie : poignée au poing, lame de z −0,2 à −2,1, haute de 0,5, dents en y −0,45.
do
	local m = newModel("TOOL_Unbox_Saw")
	local h = handle(m)
	p(m, "GripBar", Vector3.new(0.24, 0.34, 0.7), CFrame.new(0, 0, 0.05), RED, nil, { studs = true })
	p(m, "GripLoopTop", Vector3.new(0.24, 0.14, 0.72), CFrame.new(0, 0.3, 0.05), RED, nil, { studs = true })
	p(m, "GripLoopBack", Vector3.new(0.24, 0.44, 0.14), CFrame.new(0, 0.15, 0.4), RED, nil, { studs = true })
	p(m, "GripFront", Vector3.new(0.26, 0.62, 0.22), CFrame.new(0, -0.05, -0.3), RED, nil, { studs = true })
	p(m, "Screw_1", Vector3.new(0.3, 0.1, 0.1), CFrame.new(0, 0.12, -0.3), YELLOW, Enum.Material.Metal)
	p(m, "Screw_2", Vector3.new(0.3, 0.1, 0.1), CFrame.new(0, -0.2, -0.3), YELLOW, Enum.Material.Metal)
	p(m, "Blade", Vector3.new(0.05, 0.5, 1.9), CFrame.new(0, -0.2, -1.15), STEEL, Enum.Material.Metal, { reflect = 0.1 })
	p(m, "BladeSpine", Vector3.new(0.08, 0.08, 1.9), CFrame.new(0, 0.05, -1.15), STEEL_D, Enum.Material.Metal)
	p(m, "BladeTip", Vector3.new(0.05, 0.36, 0.36), CFrame.new(0, -0.2, -2.05) * CFrame.Angles(math.rad(45), 0, 0), STEEL, Enum.Material.Metal)
	for i = 1, 8 do
		p(m, string.format("Tooth_%02d", i), Vector3.new(0.05, 0.12, 0.12),
			CFrame.new(0, -0.45, -0.4 - (i - 1) * 0.22) * CFrame.Angles(math.rad(45), 0, 0), STEEL_D, Enum.Material.Metal)
	end
	att(h, "HitPoint", Vector3.new(0, -0.45, -1.15))
	table.insert(made, finish(m, h))
end

-- Pied-de-biche : 2 studs, main gauche en z −0,5, crochet au bout vers −Y, pointe en (0, −0,34, −1,9).
do
	local m = newModel("TOOL_Unbox_Crowbar")
	local h = handle(m)
	p(m, "Grip", Vector3.new(0.24, 0.24, 0.6), CFrame.new(0, 0, 0), INK, Enum.Material.Fabric)
	p(m, "Bar", Vector3.new(0.18, 0.18, 2.0), CFrame.new(0, 0, -0.7), RED, Enum.Material.Metal)
	p(m, "Chisel", Vector3.new(0.18, 0.1, 0.3), CFrame.new(0, 0.04, 0.42) * CFrame.Angles(math.rad(-20), 0, 0), STEEL, Enum.Material.Metal)
	p(m, "Hook_1", Vector3.new(0.18, 0.18, 0.3), CFrame.new(0, -0.08, -1.78) * CFrame.Angles(math.rad(40), 0, 0), RED, Enum.Material.Metal)
	p(m, "Hook_2", Vector3.new(0.18, 0.18, 0.26), CFrame.new(0, -0.24, -1.86) * CFrame.Angles(math.rad(80), 0, 0), RED, Enum.Material.Metal)
	p(m, "ClawL", Vector3.new(0.07, 0.14, 0.12), CFrame.new(-0.05, -0.33, -1.9), STEEL, Enum.Material.Metal)
	p(m, "ClawR", Vector3.new(0.07, 0.14, 0.12), CFrame.new(0.05, -0.33, -1.9), STEEL, Enum.Material.Metal)
	att(h, "HitPoint", Vector3.new(0, -0.34, -1.9))
	att(h, "GripLeft", Vector3.new(0, 0, -0.5))
	table.insert(made, finish(m, h))
end

-- Perceuse : poignée au poing, corps en z −0,62, mèche vers +Y, pointe en (0, 1,27, −0,62).
do
	local m = newModel("TOOL_Unbox_Drill")
	local h = handle(m)
	p(m, "Grip", Vector3.new(0.32, 0.38, 0.8), CFrame.new(0, 0, -0.1), INK)
	p(m, "Battery", Vector3.new(0.56, 0.56, 0.3), CFrame.new(0, 0, 0.42), INK, nil, { studs = true })
	p(m, "BatteryStripe", Vector3.new(0.58, 0.58, 0.07), CFrame.new(0, 0, 0.3), YELLOW)
	p(m, "Trigger", Vector3.new(0.12, 0.12, 0.2), CFrame.new(0, 0.24, -0.38), RED)
	p(m, "Body", Vector3.new(0.5, 1.0, 0.55), CFrame.new(0, 0.12, -0.62), YELLOW, nil, { studs = true })
	p(m, "MotorCap", Vector3.new(0.46, 0.22, 0.5), CFrame.new(0, -0.48, -0.62), INK)
	p(m, "Vent", Vector3.new(0.52, 0.1, 0.57), CFrame.new(0, -0.2, -0.62), INK)
	p(m, "Chuck", Vector3.new(0.3, 0.26, 0.3), CFrame.new(0, 0.75, -0.62), STEEL_D, Enum.Material.Metal)
	p(m, "ChuckNose", Vector3.new(0.2, 0.1, 0.2), CFrame.new(0, 0.92, -0.62), STEEL, Enum.Material.Metal)
	p(m, "Bit", Vector3.new(0.07, 0.3, 0.07), CFrame.new(0, 1.12, -0.62), STEEL, Enum.Material.Metal, { reflect = 0.15 })
	att(h, "HitPoint", Vector3.new(0, 1.27, -0.62))
	table.insert(made, finish(m, h))
end

-- Loupe : manche de 0,75, verre de 0,8 de diamètre centré en (0, 0, −1,0), tourné vers ±Y.
do
	local m = newModel("TOOL_Unbox_Magnifier")
	local h = handle(m)
	p(m, "HandleBar", Vector3.new(0.22, 0.22, 0.75), CFrame.new(0, 0, -0.075), INK, nil, { studs = true })
	p(m, "Collar", Vector3.new(0.28, 0.28, 0.14), CFrame.new(0, 0, -0.5), YELLOW, Enum.Material.Metal)
	p(m, "Neck", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, 0, -0.6), STEEL_D, Enum.Material.Metal)
	local CZ, R = -1.0, 0.4
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local len = 2 * R * math.sin(math.pi / 12) + 0.04
		p(m, string.format("Rim_%02d", k + 1), Vector3.new(len, 0.12, 0.1),
			CFrame.new(math.cos(a) * R, 0, CZ + math.sin(a) * R) * CFrame.Angles(0, -(a + math.pi / 2), 0), RED, Enum.Material.Metal)
	end
	p(m, "Lens", Vector3.new(0.05, 0.8, 0.8), CFrame.new(0, 0, CZ) * CFrame.Angles(0, 0, math.rad(90)), "#BFE6FF", Enum.Material.Glass,
		{ shape = Enum.PartType.Cylinder, transp = 0.45, reflect = 0.2 })
	p(m, "Glint", Vector3.new(0.24, 0.07, 0.06), CFrame.new(-0.12, 0.04, CZ - 0.14) * CFrame.Angles(0, math.rad(35), 0), "#FFFFFF", Enum.Material.Neon, { transp = 0.2 })
	att(h, "HitPoint", Vector3.new(0, 0, CZ))
	table.insert(made, finish(m, h))
end

-- Objets jetés pendant la fouille ----------------------------------------------------------------------

local function junk(name, build)
	local m = newModel(name)
	local body = build(m)
	local _, size = m:GetBoundingBox()
	local cf = m:GetBoundingBox()
	-- pivot en bas au centre : décalage depuis Body vers le bas de la boîte
	local bottom = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	table.insert(made, finish(m, body, body.CFrame:ToObjectSpace(bottom)))
end

junk("ENV_Unbox_Junk_Sock", function(m)
	local body = p(m, "Body", Vector3.new(0.36, 0.8, 0.32), CFrame.new(0, 0.62, 0.12), "#F0F2F5", Enum.Material.Fabric)
	p(m, "Foot", Vector3.new(0.36, 0.3, 0.62), CFrame.new(0, 0.15, -0.03), "#F0F2F5", Enum.Material.Fabric)
	p(m, "Toe", Vector3.new(0.37, 0.31, 0.16), CFrame.new(0, 0.15, -0.3), RED, Enum.Material.Fabric)
	p(m, "Heel", Vector3.new(0.37, 0.22, 0.12), CFrame.new(0, 0.18, 0.25), RED, Enum.Material.Fabric)
	p(m, "Stripe_1", Vector3.new(0.37, 0.1, 0.33), CFrame.new(0, 0.82, 0.12), RED, Enum.Material.Fabric)
	p(m, "Stripe_2", Vector3.new(0.37, 0.1, 0.33), CFrame.new(0, 0.62, 0.12), "#2F9BFF", Enum.Material.Fabric)
	p(m, "Cuff", Vector3.new(0.4, 0.12, 0.36), CFrame.new(0, 1.0, 0.12), "#E3E8EF", Enum.Material.Fabric)
	p(m, "Hole", Vector3.new(0.38, 0.08, 0.08), CFrame.new(0, 0.12, -0.12), INK, Enum.Material.Fabric)
	return body
end)

junk("ENV_Unbox_Junk_Duck", function(m)
	local body = p(m, "Body", Vector3.new(0.62, 0.48, 0.78), CFrame.new(0, 0.24, 0.05), YELLOW)
	p(m, "Head", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 0.66, -0.18), YELLOW)
	p(m, "Beak", Vector3.new(0.26, 0.1, 0.22), CFrame.new(0, 0.6, -0.48), "#FF8C1A")
	p(m, "EyeL", Vector3.new(0.06, 0.1, 0.06), CFrame.new(-0.13, 0.72, -0.4), INK)
	p(m, "EyeR", Vector3.new(0.06, 0.1, 0.06), CFrame.new(0.13, 0.72, -0.4), INK)
	p(m, "Tail", Vector3.new(0.3, 0.22, 0.2), CFrame.new(0, 0.42, 0.46) * CFrame.Angles(math.rad(-30), 0, 0), YELLOW)
	p(m, "WingL", Vector3.new(0.06, 0.22, 0.4), CFrame.new(-0.33, 0.3, 0.08), "#E8A800")
	p(m, "WingR", Vector3.new(0.06, 0.22, 0.4), CFrame.new(0.33, 0.3, 0.08), "#E8A800")
	return body
end)

junk("ENV_Unbox_Junk_FishBone", function(m)
	local BONE = "#F0EDE4"
	local body = p(m, "Body", Vector3.new(0.07, 0.07, 1.0), CFrame.new(0, 0.18, 0), BONE)
	p(m, "Head", Vector3.new(0.12, 0.34, 0.32), CFrame.new(0, 0.18, -0.62), BONE)
	p(m, "Eye", Vector3.new(0.14, 0.08, 0.08), CFrame.new(0, 0.24, -0.66), INK)
	p(m, "Jaw", Vector3.new(0.1, 0.12, 0.2), CFrame.new(0, 0.06, -0.72) * CFrame.Angles(math.rad(25), 0, 0), BONE)
	for i = 1, 4 do
		local z = -0.3 + (i - 1) * 0.2
		local hgt = 0.34 - (i - 1) * 0.05
		p(m, "RibUp_" .. i, Vector3.new(0.05, hgt, 0.05), CFrame.new(0, 0.18 + hgt / 2, z) * CFrame.Angles(math.rad(15), 0, 0), BONE)
		p(m, "RibDown_" .. i, Vector3.new(0.05, hgt, 0.05), CFrame.new(0, 0.18 - hgt / 2, z) * CFrame.Angles(math.rad(-15), 0, 0), BONE)
	end
	p(m, "TailUp", Vector3.new(0.05, 0.26, 0.12), CFrame.new(0, 0.28, 0.58) * CFrame.Angles(math.rad(-40), 0, 0), BONE)
	p(m, "TailDown", Vector3.new(0.05, 0.26, 0.12), CFrame.new(0, 0.08, 0.58) * CFrame.Angles(math.rad(40), 0, 0), BONE)
	return body
end)

junk("ENV_Unbox_Junk_BananaPeel", function(m)
	local PEEL, DARK = "#FFD84A", "#8A6A2E"
	local body = p(m, "Body", Vector3.new(0.34, 0.26, 0.34), CFrame.new(0, 0.13, 0), PEEL)
	p(m, "Stem", Vector3.new(0.12, 0.3, 0.12), CFrame.new(0, 0.4, 0), DARK)
	p(m, "StemTip", Vector3.new(0.14, 0.06, 0.14), CFrame.new(0, 0.56, 0), INK)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.rad(20)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = dir * 0.42 + Vector3.new(0, 0.05, 0)
		p(m, "Flap_" .. (k + 1), Vector3.new(0.2, 0.05, 0.58), CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.rad(-8), 0, 0), PEEL)
		p(m, "FlapTip_" .. (k + 1), Vector3.new(0.12, 0.06, 0.1), CFrame.lookAt(dir * 0.72 + Vector3.new(0, 0.04, 0), dir * 2), DARK)
	end
	return body
end)

junk("ENV_Unbox_Junk_Boot", function(m)
	local LEATHER, SOLE = "#7A4B2A", "#2B2E3A"
	local body = p(m, "Body", Vector3.new(0.5, 0.75, 0.5), CFrame.new(0, 0.55, 0.18), LEATHER, Enum.Material.Leather)
	p(m, "Foot", Vector3.new(0.5, 0.32, 0.92), CFrame.new(0, 0.24, -0.05), LEATHER, Enum.Material.Leather)
	p(m, "ToeCap", Vector3.new(0.52, 0.28, 0.2), CFrame.new(0, 0.22, -0.46), "#5E3820", Enum.Material.Leather)
	p(m, "Sole", Vector3.new(0.54, 0.1, 0.98), CFrame.new(0, 0.05, -0.05), SOLE)
	p(m, "Heel", Vector3.new(0.52, 0.12, 0.3), CFrame.new(0, 0.06, 0.3), SOLE)
	p(m, "Lace_1", Vector3.new(0.4, 0.06, 0.06), CFrame.new(0, 0.48, -0.08), "#F0F2F5")
	p(m, "Lace_2", Vector3.new(0.4, 0.06, 0.06), CFrame.new(0, 0.66, -0.08), "#F0F2F5")
	p(m, "Patch", Vector3.new(0.06, 0.2, 0.2), CFrame.new(0.26, 0.6, 0.18), "#C8935A", Enum.Material.Fabric)
	return body
end)

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end

-- bilan
local out = {}
for _, m in made do
	local n, tris, scripts = 0, 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			local shape = d:IsA("Part") and d.Shape or nil
			tris += (shape == Enum.PartType.Cylinder and 76) or (shape == Enum.PartType.Ball and 380) or 12
		end
		if d:IsA("LuaSourceContainer") then scripts += 1 end
	end
	local _, size = m:GetBoundingBox()
	table.insert(out, string.format("%s : %d pieces, ~%d triangles, %d scripts, %.2f x %.2f x %.2f studs",
		m.Name, n, tris, scripts, size.X, size.Y, size.Z))
end
return table.concat(out, "\n")
