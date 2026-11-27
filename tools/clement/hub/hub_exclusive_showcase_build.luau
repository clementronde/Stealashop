--[[
Construction du socle de l'objet exclusif geant de la zone safe (idee 7 de la video « pousser un oeuf », validee par
Clement le 26/11, paquet H, A7 point 5). Modele seul, par le chef 3D ; la place est choisie par le chef Map : centre au
sol (12 ; 0 ; -38), face avant vers +z (vers le passage), symetrique du noob d'invitation. La pose dans la map est le
script du chef Map, tools/clement/hub/hub_exclusive_showcase.luau (ne pas confondre).
Construit dans ServerStorage/Previews/ENV_Hub_ExclusiveShowcase, deja a sa place et dans son orientation. Aucun script ;
aucun tag (ExclusiveShowcase sera pose quand il sera au contrat).
Enfants lus par le code (noms proposes) :
  Root        PrimaryPart invisible, pivot en bas au centre
  ItemPoint   Attachment dans Root, sur le dessus du socle : l'objet exclusif pose en grand (son pivot ici)
  LabelPoint  Attachment dans Root, 12 studs au-dessus du dessus : l'etiquette (le code peut la monter selon l'objet)
  PromptPart  Part invisible devant le socle (cote +z), sans collision, CanTouch : marcher dessus ouvre l'achat
Rejouable : remplace le modele de Previews s'il existe deja (jamais celui de la map).
]]

local CENTER = Vector3.new(12, 0, -38)
local FRONT = Vector3.new(0, 0, 1) -- face avant vers +z

local PURPLE = Color3.fromRGB(96, 44, 160)
local PURPLE_DARK = Color3.fromRGB(70, 30, 120)
local GOLD = Color3.fromRGB(245, 190, 40)
local GOLD_DARK = Color3.fromRGB(215, 155, 25)
local VELVET = Color3.fromRGB(205, 35, 70)

local SS = game:GetService("ServerStorage")
local previews = SS:FindFirstChild("Previews") or Instance.new("Folder")
previews.Name = "Previews"
previews.Parent = SS
local old = previews:FindFirstChild("ENV_Hub_ExclusiveShowcase")
if old then
	old:Destroy()
end

local origin = CFrame.lookAt(CENTER, CENTER + FRONT)
local model = Instance.new("Model")
model.Name = "ENV_Hub_ExclusiveShowcase"

local count = 0
local function part(name: string, size: Vector3, pos: Vector3, color: Color3, cyl: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if cyl then
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = origin * CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	else
		p.CFrame = origin * CFrame.new(pos)
	end
	p.Parent = model
	count += 1
	return p
end

-- Root : invisible, pivot en bas au centre
local root = part("Root", Vector3.new(8, 0.2, 8), Vector3.new(0, 0.1, 0), PURPLE)
root.Transparency = 1
root.CanCollide = false
root.CanQuery = false
root.CanTouch = false
root.PivotOffset = CFrame.new(0, -0.1, 0) -- pivot du modele au ras du sol (bas du Root)
model.PrimaryPart = root

-- marches : base violette 8 x 8, marche doree 6,5 x 6,5, dessus en velours rouge 5 x 5
local h1, h2, h3 = 1, 1, 0.4
part("Step_Base", Vector3.new(8, h1, 8), Vector3.new(0, h1 / 2, 0), PURPLE)
part("Step_Base_Band", Vector3.new(8.1, 0.2, 8.1), Vector3.new(0, 0.1, 0), PURPLE_DARK)
part("Step_Gold", Vector3.new(6.5, h2, 6.5), Vector3.new(0, h1 + h2 / 2, 0), GOLD)
part("Step_Gold_Band", Vector3.new(6.6, 0.2, 6.6), Vector3.new(0, h1 + h2 - 0.1, 0), GOLD_DARK)
local topY = h1 + h2 + h3
part("Top_Velvet", Vector3.new(5, h3, 5), Vector3.new(0, h1 + h2 + h3 / 2, 0), VELVET)

-- tenons sur les bords visibles des deux marches (style des briques du hub)
local STUD = Vector3.new(0.15, 0.4, 0.4)
local function ring(half: number, y: number, n: number, color: Color3)
	local step = 2 * half / (n - 1)
	for i = 0, n - 1 do
		local t = -half + i * step
		part("Stud", STUD, Vector3.new(t, y, -half), color, true)
		part("Stud", STUD, Vector3.new(t, y, half), color, true)
		if i > 0 and i < n - 1 then
			part("Stud", STUD, Vector3.new(-half, y, t), color, true)
			part("Stud", STUD, Vector3.new(half, y, t), color, true)
		end
	end
end
ring(3.6, h1 + 0.075, 8, PURPLE) -- couronne de la base (entre 8 et 6,5)
ring(2.9, h1 + h2 + 0.075, 6, GOLD) -- couronne de la marche doree (entre 6,5 et 5)

-- coins dores de la base
for _, x in { -3.6, 3.6 } do
	for _, z in { -3.6, 3.6 } do
		part("Corner", Vector3.new(1, 1.4, 1), Vector3.new(x, 0.7, z), GOLD)
	end
end

-- points lus par le code
local item = Instance.new("Attachment")
item.Name = "ItemPoint"
item.Position = Vector3.new(0, topY - 0.1, 0) -- Root est centre a y 0,1
item.Parent = root
local label = Instance.new("Attachment")
label.Name = "LabelPoint"
label.Position = Vector3.new(0, topY + 12 - 0.1, 0)
label.Parent = root

-- zone de marche devant (cote +z) : un tapis dore a ras du sol et la piece invisible qui detecte le joueur
local padZ = 4 + 2.5
part("Pad", Vector3.new(7, 0.12, 4), Vector3.new(0, 0.06, -padZ), GOLD).CanCollide = false
local prompt = part("PromptPart", Vector3.new(7, 5, 4), Vector3.new(0, 2.5, -padZ), GOLD)
prompt.Transparency = 1
prompt.CanCollide = false
prompt.CanQuery = false
prompt.CanTouch = true
prompt.CastShadow = false

model.Parent = previews
local _, size = model:GetBoundingBox()
local msg = string.format("ENV_Hub_ExclusiveShowcase : %d pieces, %.1f x %.1f x %.1f studs, pivot %s, ItemPoint a %.2f, PromptPart a %s",
	count, size.X, size.Y, size.Z, tostring(model:GetPivot().Position), item.WorldPosition.Y, tostring(prompt.Position))
print("[socle exclusif] " .. msg)
return msg
