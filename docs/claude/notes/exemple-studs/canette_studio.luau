-- Exemple « style Exclusive Crate » construit dans Studio en Parts (pas de maillage).
-- Crée Workspace/_EXEMPLE_STUDS avec :
--   EX_Studio_CanetteDeSoda  : la canette refaite en blocs + variant Studs
--   EX_Ref_ExclusiveCrate    : copie du colis de référence
--   EX_Avant_CanetteDeSoda   : l'objet actuel (maillage lisse), pour comparer
-- À lancer dans la barre de commande de Studio, en Edit. Ne touche à rien d'autre.

local ORIGIN = Vector3.new(0, 200, 0) -- loin de la carte, dans le ciel
local folder = workspace:FindFirstChild("_EXEMPLE_STUDS")
if folder then folder:Destroy() end
folder = Instance.new("Folder")
folder.Name = "_EXEMPLE_STUDS"
folder.Parent = workspace

-- socle blanc pour la capture
local floor = Instance.new("Part")
floor.Name = "Fond"
floor.Anchored = true
floor.Size = Vector3.new(14, 0.2, 8)
floor.Position = ORIGIN + Vector3.new(0, -0.1, 0)
floor.Color = Color3.fromHex("F4F4F4")
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = folder

local RED = Color3.fromHex("E8413C")
local WHITE = Color3.fromHex("F5F7FA")
local GOLD = Color3.fromHex("FFC21A") -- cadre or des colis
local GREY = Color3.fromHex("C9CFD8")

local function block(model, name, size, offset, color, studs)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = model:GetAttribute("_base") and (CFrame.new(model:GetAttribute("_base")) * CFrame.new(offset)) or CFrame.new(offset)
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if studs then
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = "Studs"
	else
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Parent = model
	return p
end

-- un « cylindre en blocs » : deux pavés croisés (octogone grossier), comme l'escalier de l'œuf
local function plus(model, name, w, h, y, color, studs)
	local inner = w * 0.7
	block(model, name .. "_A", Vector3.new(w, h, inner), Vector3.new(0, y, 0), color, studs)
	block(model, name .. "_B", Vector3.new(inner, h, w), Vector3.new(0, y, 0), color, studs)
end

-- 1. la canette en blocs
local can = Instance.new("Model")
can.Name = "EX_Studio_CanetteDeSoda"
can:SetAttribute("_base", ORIGIN + Vector3.new(-4, 0, 0))
can.Parent = folder

-- grille de 0,125 stud ; même taille que l'objet du jeu (1,0 × 1,6)
plus(can, "RimBottom", 1.0, 0.25, 0.125, GOLD, false) -- cadre lisse, comme FrameBody du colis
plus(can, "Body", 0.875, 1.125, 0.8125, RED, true) -- corps à studs, comme Body du colis
plus(can, "Band", 0.9, 0.375, 0.8125, WHITE, true) -- bande blanche
plus(can, "RimTop", 1.0, 0.25, 1.5, GOLD, false)
block(can, "Tab", Vector3.new(0.375, 0.125, 0.25), Vector3.new(0, 1.6875, 0.125), GREY, false)

local root = block(can, "Root", Vector3.new(1, 1.75, 1), Vector3.new(0, 0.875, 0), GREY, false)
root.Transparency = 1
can.PrimaryPart = root
can:SetAttribute("_base", nil)

local hl = Instance.new("Highlight")
hl.Name = "OutlineHighlight"
hl.FillTransparency = 1
hl.OutlineColor = Color3.new(0, 0, 0)
hl.DepthMode = Enum.HighlightDepthMode.Occluded
hl.Parent = can

-- 2. la même, à × 2,5 (taille d'un objet lourd), pour voir les studs
local big = can:Clone()
big.Name = "EX_Studio_CanetteDeSoda_x2_5"
big:ScaleTo(2.5)
big:PivotTo(CFrame.new(ORIGIN + Vector3.new(-1, 2.1875, 0)))
big.Parent = folder

-- 3. le colis de référence
local crate = game.ReplicatedStorage.Assets.UI.BOX_Shop_ExclusiveCrate:Clone()
crate.Name = "EX_Ref_ExclusiveCrate"
crate:PivotTo(CFrame.new(ORIGIN + Vector3.new(4, 2.1, 0)) * CFrame.Angles(0, math.pi, 0))
for _, d in crate:GetDescendants() do
	if d:IsA("BasePart") then d.Anchored = true end
end
crate.Parent = folder

-- 4. l'objet actuel
local old = game.ReplicatedStorage.Assets.Items.ITM_Z1_CanetteDeSoda:Clone()
old.Name = "EX_Avant_CanetteDeSoda"
old:PivotTo(CFrame.new(ORIGIN + Vector3.new(-6, 0, 0))) -- pivot en bas au centre
for _, d in old:GetDescendants() do
	if d:IsA("BasePart") then d.Anchored = true end
end
old.Parent = folder

return "ok"
