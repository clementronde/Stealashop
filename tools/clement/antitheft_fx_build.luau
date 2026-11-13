-- FX_AntiTheft v2 : kit de chaînes qui entourent l'objet sous antivol, et cadenas (Clément, 2026-11-13 :
-- « les chaînes doivent entrelacer les objets »). À lancer en Edit (CSG). Relançable. Aucun script.
--
-- ReplicatedStorage/Assets/FX/FX_AntiTheft (Model) :
--   Link (UnionOperation) : un maillon ovale (normale = X local, grand axe = Z local), à l'échelle 1.
--   Padlock (Model) : cadenas doré, face avant vers −Z ; son pivot est en haut de l'anse, là où il
--                     s'accroche au croisement des chaînes.
--   Attributs : FitSize = 2 (k = √(largeur × hauteur de l'objet) / FitSize × 1,1 : échelle des
--               maillons et du cadenas), LinkPitch = 0,225 (pas entre deux maillons à l'échelle 1),
--               LinkWidth = 0,2, WrapAngle = 0,85 (part de l'angle de la diagonale de la face avant).
-- Le code fait le tour de l'objet avec ces maillons : tools/clement/antitheft_proto.luau (fonction
-- wrap) montre comment, et pose l'aperçu Workspace/_PREVIEW_AntiTheft.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LINK_LENGTH = 0.34
local LINK_WIDTH = 0.2
local WIRE = 0.055
local PITCH = LINK_LENGTH - 2 * WIRE - 0.005
local STEEL = Color3.fromRGB(167, 175, 186)
local GOLD = Color3.fromRGB(242, 185, 43)
local DARK = Color3.fromRGB(38, 38, 48)

local recording = ChangeHistoryService:TryBeginRecording("FX_AntiTheft v2")

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function finish(u: UnionOperation, color: Color3, material: Enum.Material): UnionOperation
	u.Anchored = true
	u.CanCollide = false
	u.CanQuery = false
	u.CanTouch = false
	u.CastShadow = false
	u.UsePartColor = true
	u.Color = color
	u.Material = material
	return u
end

-- Anneau : cylindre (axe X) moins un cylindre plus fin.
local function ring(outer: number, inner: number, thickness: number, color: Color3, material: Enum.Material): UnionOperation
	local a = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, outer, outer) })
	local b = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness * 3, inner, inner) })
	local result = GeometryService:SubtractAsync(a, { b }, { CollisionFidelity = Enum.CollisionFidelity.Box, SplitApart = false })
	a:Destroy()
	b:Destroy()
	return finish(result[1] :: UnionOperation, color, material)
end

local fxFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("FX")
assert(fxFolder, "ReplicatedStorage/Assets/FX introuvable")
local old = fxFolder:FindFirstChild("FX_AntiTheft")
if old then
	old:Destroy()
end

local fx = Instance.new("Model")
fx.Name = "FX_AntiTheft"
fx:SetAttribute("FitSize", 2)
fx:SetAttribute("LinkPitch", PITCH)
fx:SetAttribute("LinkWidth", LINK_WIDTH)
fx:SetAttribute("WrapAngle", 0.85)

-- Maillon
local link = ring(1, 1 - 2 * WIRE / LINK_WIDTH, WIRE, STEEL, Enum.Material.Metal)
link.Size = Vector3.new(WIRE, LINK_WIDTH, LINK_LENGTH)
link.Name = "Link"
link.CFrame = CFrame.new()
link.Parent = fx

-- Cadenas
local padlock = Instance.new("Model")
padlock.Name = "Padlock"
local z = -0.16
local body = part({ Name = "Body", Size = Vector3.new(0.56, 0.46, 0.2), CFrame = CFrame.new(0, -0.1, z), Color = GOLD, Material = Enum.Material.SmoothPlastic })
body.Parent = padlock
local full = ring(0.42, 0.26, 0.08, STEEL, Enum.Material.Metal)
full.CFrame = CFrame.new(0, 0.22, z) * CFrame.Angles(0, math.rad(90), 0)
local cutter = part({ Size = Vector3.new(0.6, 0.3, 0.6), CFrame = CFrame.new(0, 0.07, z) })
local shackle = finish(GeometryService:SubtractAsync(full, { cutter }, { SplitApart = false })[1] :: UnionOperation, STEEL, Enum.Material.Metal)
full:Destroy()
cutter:Destroy()
shackle.Name = "Shackle"
shackle.Parent = padlock
for i, x in { -0.17, 0.17 } do
	part({ Name = "ShackleLeg_" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.08, 0.08),
		CFrame = CFrame.new(x, 0.175, z) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = Enum.Material.Metal }).Parent = padlock
end
part({ Name = "Keyhole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.03, 0.12, 0.12),
	CFrame = CFrame.new(0, -0.06, z - 0.1) * CFrame.Angles(0, math.rad(90), 0), Color = DARK, Material = Enum.Material.SmoothPlastic }).Parent = padlock
part({ Name = "KeySlot", Size = Vector3.new(0.05, 0.12, 0.03), CFrame = CFrame.new(0, -0.15, z - 0.1), Color = DARK, Material = Enum.Material.SmoothPlastic }).Parent = padlock
padlock.PrimaryPart = body
-- pivot : en haut de l'anse, côté arrière du cadenas (il s'accroche là au croisement des chaînes)
padlock.WorldPivot = CFrame.new(0, 0.33, -0.06)
padlock.Parent = fx

fx.WorldPivot = CFrame.new()
fx.Parent = fxFolder

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("FX_AntiTheft v2 (kit Link + Padlock) construit")
