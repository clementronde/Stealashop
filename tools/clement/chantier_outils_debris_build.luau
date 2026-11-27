--!strict
--[[
Chantier du magasin PNJ casse par un objet geant, suite de la planche validee par Clement le 26/11 (« oui ça me va »).
A lancer en Edit APRES chantier_planche_build.luau (il complete ServerStorage/Previews/CHANTIER). Rejouable.
1. Pancarte : rayures du cadre regulieres tout autour (une couleur sur deux le long du tour du cadre, coins compris).
2. Outils des ouvriers, en Tool avec une Handle (Grip par defaut, comme la batte, pour les poses du chef animation) :
   le manche est la Handle, centre dans le poing, son grand axe le long du +Y de RightGripAttachment.
     TOOL_Worker_Hammer       petit marteau (tete en haut du manche)
     TOOL_Worker_Screwdriver  tournevis (lame vers le haut)
     TOOL_Worker_Plank        planche a porter sur l'epaule (CarryPlank), grand axe en +Y
   Le marteau tenu par l'ouvrier de la planche (accessoire ACC_Worker_Hammer) est retire : le code lui donne le Tool.
3. Debris qui restent apres la casse, en 3 niveaux (paquet Map : BreakLevel 1 decor, 2 plafond, 3 devanture) plus la
   route. Des Models a pivot en bas au centre, ancres, sans collision (on marche dedans), sans requete ni script ;
   peu de pieces, gros morceaux lisibles depuis la rue.
     ENV_StoreDebris_Decor_01..03     planches de rayon cassees, cartons ecrases, colis renverses
     ENV_StoreDebris_Ceiling_01..03   platre, morceaux de dalle du plafond, poussiere au sol
     ENV_StoreDebris_Front_01..02     eclats de vitre et morceaux du cadre, devant le magasin
     ENV_StoreDebris_Street_01..02    gros tas sur la route : beton, cadre tordu, vitre, carton
Tout est range dans ServerStorage/Previews/CHANTIER (Outils, Debris), rien dans Assets avant la validation de la
planche des debris.
]]

local ServerStorage = game:GetService("ServerStorage")
local previews = ServerStorage:FindFirstChild("Previews")
assert(previews, "ServerStorage/Previews absent : lance d'abord chantier_planche_build.luau")
local chantier = previews:FindFirstChild("CHANTIER")
assert(chantier, "Previews/CHANTIER absent : lance d'abord chantier_planche_build.luau")

local YELLOW = Color3.fromHex("F7C51E")
local BLACK = Color3.fromHex("1A1A1F")
local report: { string } = {}

-- ===== 1. rayures regulieres du cadre de la pancarte =====
do
	local sign = chantier:FindFirstChild("ENV_Construction_Sign")
	if sign and sign:IsA("Model") and sign.PrimaryPart then
		local W, H, B = 12, 3.6, 0.6
		local cols = math.floor(W / B + 0.5) -- 20
		local rowsN = math.floor((H - 2 * B) / B + 0.5) -- 4 sur les cotes, sans les coins
		local base = sign.PrimaryPart.CFrame
		local n = 0
		for _, p in sign:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Frame" then
				local lp = base:PointToObjectSpace(p.Position)
				local ix = math.floor((lp.X + W / 2 - B / 2) / B + 0.5)
				local iy = math.floor((lp.Y - B / 2) / B + 0.5) -- 0 en bas, rowsN + 1 en haut
				local idx
				if iy == rowsN + 1 then
					idx = ix -- haut, de gauche a droite
				elseif ix == cols - 1 and iy >= 1 and iy <= rowsN then
					idx = cols + (rowsN - iy) -- cote droit, de haut en bas
				elseif iy == 0 then
					idx = cols + rowsN + (cols - 1 - ix) -- bas, de droite a gauche
				else
					idx = 2 * cols + rowsN + (iy - 1) -- cote gauche, de bas en haut
				end
				p.Color = if idx % 2 == 0 then BLACK else YELLOW
				n += 1
			end
		end
		table.insert(report, "pancarte : " .. n .. " blocs du cadre recolores le long du tour")
	end
end

-- ===== pieces =====
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, kind: string?): BasePart
	local p: BasePart
	if kind == "Wedge" then
		p = Instance.new("WedgePart")
	elseif kind == "Cylinder" then
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		p = c
	else
		p = Instance.new("Part")
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function inert(p: BasePart, anchored: boolean)
	p.Anchored = anchored
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = not anchored
end

-- ===== 2. outils (Tool + Handle, Grip par defaut) =====
local outils = chantier:FindFirstChild("Outils")
if outils then
	outils:Destroy()
end
local toolsFolder = Instance.new("Folder")
toolsFolder.Name = "Outils"
local WOOD = Color3.fromHex("A0703C")
local METAL = Color3.fromHex("5A6270")
local function newTool(name: string, handleSize: Vector3, handleColor: Color3, handleMat: Enum.Material?): (Tool, BasePart)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	local h = part(tool, "Handle", handleSize, CFrame.new(), handleColor, handleMat)
	inert(h, false)
	return tool, h
end
local function weldTo(handle: BasePart, p: BasePart)
	inert(p, false)
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
	p.Parent = handle.Parent
end
do -- marteau : manche de 1,3 le long de +Y, tete en haut, perpendiculaire (le long de Z, la frappe vers -Z)
	local tool, h = newTool("TOOL_Worker_Hammer", Vector3.new(0.2, 1.3, 0.2), WOOD)
	weldTo(h, part(tool, "Head", Vector3.new(0.28, 0.28, 0.6), CFrame.new(0, 0.7, -0.08), METAL, Enum.Material.Metal))
	weldTo(h, part(tool, "Claw", Vector3.new(0.2, 0.18, 0.26), CFrame.new(0, 0.74, 0.32) * CFrame.Angles(math.rad(-25), 0, 0), METAL, Enum.Material.Metal))
	weldTo(h, part(tool, "GripTape", Vector3.new(0.22, 0.4, 0.22), CFrame.new(0, -0.35, 0), Color3.fromHex("E23B3B")))
	tool.Parent = toolsFolder
end
do -- tournevis : manche rouge dans le poing, lame metal vers +Y
	local tool, h = newTool("TOOL_Worker_Screwdriver", Vector3.new(0.24, 0.5, 0.24), Color3.fromHex("E23B3B"))
	weldTo(h, part(tool, "Ring", Vector3.new(0.26, 0.08, 0.26), CFrame.new(0, 0.27, 0), YELLOW))
	weldTo(h, part(tool, "Shaft", Vector3.new(0.07, 0.6, 0.07), CFrame.new(0, 0.6, 0), Color3.fromHex("C9CED6"), Enum.Material.Metal))
	weldTo(h, part(tool, "Tip", Vector3.new(0.12, 0.1, 0.03), CFrame.new(0, 0.93, 0), Color3.fromHex("C9CED6"), Enum.Material.Metal))
	tool.Parent = toolsFolder
end
do -- planche a porter : 5 de long le long de +Y (la Handle), deux veines plus foncees
	local tool, h = newTool("TOOL_Worker_Plank", Vector3.new(0.3, 5, 0.9), Color3.fromHex("C8955A"))
	weldTo(h, part(tool, "Grain", Vector3.new(0.32, 4.6, 0.08), CFrame.new(0, 0, -0.2), Color3.fromHex("A97A45")))
	weldTo(h, part(tool, "Grain", Vector3.new(0.32, 4.2, 0.08), CFrame.new(0, 0.1, 0.22), Color3.fromHex("A97A45")))
	tool.Parent = toolsFolder
end
toolsFolder.Parent = chantier
table.insert(report, "outils : TOOL_Worker_Hammer, TOOL_Worker_Screwdriver, TOOL_Worker_Plank (Handle = manche, axe +Y)")

-- l'ouvrier ne tient plus le marteau en accessoire : le code lui donne le Tool
local worker = chantier:FindFirstChild("NPC_Worker_01")
if worker then
	local acc = worker:FindFirstChild("ACC_Worker_Hammer")
	if acc then
		acc:Destroy()
		table.insert(report, "NPC_Worker_01 : ACC_Worker_Hammer retire (remplace par TOOL_Worker_Hammer)")
	end
end

-- ===== 3. debris =====
local old = chantier:FindFirstChild("Debris")
if old then
	old:Destroy()
end
local debrisFolder = Instance.new("Folder")
debrisFolder.Name = "Debris"

local KRAFT = Color3.fromHex("C9955B")
local KRAFT_DARK = Color3.fromHex("A8773F")
local SHELF = Color3.fromHex("8E9AA8")
local PLASTER = Color3.fromHex("EDEAE3")
local PLASTER_DARK = Color3.fromHex("CFC8BC")
local TILE = Color3.fromHex("F5F3EE")
local DUST = Color3.fromHex("D8D2C6")
local GLASS = Color3.fromHex("BFE3F2")
local FRAME = Color3.fromHex("2F3440")
local CONCRETE = Color3.fromHex("9A9C9E")
local CONCRETE_DARK = Color3.fromHex("7C7E82")

local function newDebris(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	local root = part(m, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	inert(root, true)
	root.PivotOffset = CFrame.new(0, -0.1, 0)
	m.PrimaryPart = root
	return m
end
-- une piece posee au sol : tournee, puis montee de sa demi-hauteur reelle (apres rotation) pour toucher le sol
local function piece(m: Model, name: string, size: Vector3, x: number, z: number, rx: number, ry: number, rz: number, color: Color3, mat: Enum.Material?, kind: string?, lift: number?)
	local rot = CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
	local halfY = math.abs(rot.XVector.Y) * size.X / 2 + math.abs(rot.YVector.Y) * size.Y / 2 + math.abs(rot.ZVector.Y) * size.Z / 2
	local cf = CFrame.new(x, halfY + (lift or 0), z) * rot
	local p = part(m, name, size, cf, color, mat, kind)
	inert(p, true)
	p.CastShadow = true
	if mat == Enum.Material.Glass then
		p.Transparency = 0.35
	elseif name == "Dust" then
		p.Transparency = 0.55 -- opaque, la poussiere faisait des tapis blancs (capture du 26/11)
	end
	return p
end

local defs: { [string]: (Model) -> () } = {
	ENV_StoreDebris_Decor_01 = function(m) -- planches de rayon cassees en travers
		piece(m, "Board", Vector3.new(3.2, 0.2, 0.9), 0, 0, 0, 20, 4, SHELF)
		piece(m, "Board", Vector3.new(2.4, 0.2, 0.9), 0.4, 0.5, 0, -35, -8, SHELF, nil, nil, 0.18)
		piece(m, "Bracket", Vector3.new(0.2, 1.2, 0.2), -1.1, -0.4, 0, 0, 70, Color3.fromHex("5A6270"), Enum.Material.Metal)
		piece(m, "BoxCrushed", Vector3.new(1.1, 0.6, 1.0), 1.2, -0.7, 0, 25, 6, KRAFT)
	end,
	ENV_StoreDebris_Decor_02 = function(m) -- cartons ecrases et colis renverse
		piece(m, "Box", Vector3.new(1.4, 1.1, 1.2), 0, 0, 0, 15, 12, KRAFT)
		piece(m, "Box", Vector3.new(1.0, 0.5, 1.0), 1.3, 0.6, 0, -20, 0, KRAFT_DARK)
		piece(m, "Flap", Vector3.new(1.2, 0.08, 0.8), -1.1, 0.5, 0, 40, 0, KRAFT)
		piece(m, "Tape", Vector3.new(1.42, 0.05, 0.2), 0, 0, 0, 15, 12, Color3.fromHex("E9D9A6"), nil, nil, 1.08)
	end,
	ENV_StoreDebris_Decor_03 = function(m) -- tas de petits morceaux de meuble
		piece(m, "Chunk", Vector3.new(0.9, 0.5, 0.7), 0, 0, 10, 30, 0, SHELF)
		piece(m, "Chunk", Vector3.new(0.7, 0.4, 0.6), 0.9, 0.3, 0, -10, 15, KRAFT)
		piece(m, "Stick", Vector3.new(2.0, 0.18, 0.18), -0.4, 0.7, 0, 55, 3, Color3.fromHex("6B4422"))
		piece(m, "Chunk", Vector3.new(0.6, 0.35, 0.5), -0.9, -0.5, 0, 70, -10, SHELF)
	end,
	ENV_StoreDebris_Ceiling_01 = function(m) -- gros morceaux de platre
		piece(m, "Plaster", Vector3.new(1.6, 0.6, 1.3), 0, 0, 8, 20, -6, PLASTER)
		piece(m, "Plaster", Vector3.new(1.0, 0.45, 0.9), 1.3, 0.4, -10, -25, 8, PLASTER_DARK)
		piece(m, "Plaster", Vector3.new(0.7, 0.35, 0.6), -1.1, 0.7, 0, 45, 12, PLASTER)
		piece(m, "Dust", Vector3.new(4.2, 0.05, 3.4), 0, 0, 0, 10, 0, DUST)
	end,
	ENV_StoreDebris_Ceiling_02 = function(m) -- dalles du plafond cassees, une pointe en l'air
		piece(m, "Tile", Vector3.new(2.4, 0.16, 2.4), 0, 0, 0, 12, 3, TILE)
		piece(m, "TileHalf", Vector3.new(2.4, 0.16, 1.2), 1.4, 1.2, 0, -18, -14, TILE, nil, "Wedge", 0.25)
		piece(m, "TileBit", Vector3.new(1.0, 0.16, 0.8), -1.4, 0.9, 0, 40, 0, PLASTER_DARK)
		piece(m, "Grid", Vector3.new(2.6, 0.12, 0.12), 0.2, -1.2, 0, 8, 6, Color3.fromHex("B8BDC4"), Enum.Material.Metal)
	end,
	ENV_StoreDebris_Ceiling_03 = function(m) -- tas de gravats de platre
		piece(m, "Chunk", Vector3.new(1.1, 0.7, 1.0), 0, 0, 12, 0, 8, PLASTER)
		piece(m, "Chunk", Vector3.new(0.8, 0.5, 0.7), 0.8, 0.5, -8, 30, 0, PLASTER_DARK)
		piece(m, "Chunk", Vector3.new(0.7, 0.45, 0.8), -0.7, 0.6, 0, -20, 10, PLASTER)
		piece(m, "Chunk", Vector3.new(0.5, 0.35, 0.5), 0.2, -0.9, 6, 50, 0, PLASTER)
		piece(m, "Dust", Vector3.new(3.4, 0.05, 3.0), 0, 0, 0, 25, 0, DUST)
	end,
	ENV_StoreDebris_Front_01 = function(m) -- eclats de vitre a plat et un montant du cadre
		piece(m, "Shard", Vector3.new(0.12, 1.4, 1.8), 0, 0, 0, 20, 90, GLASS, Enum.Material.Glass, "Wedge")
		piece(m, "Shard", Vector3.new(0.12, 1.0, 1.2), 1.4, 0.7, 0, -40, 90, GLASS, Enum.Material.Glass, "Wedge")
		piece(m, "Shard", Vector3.new(0.12, 0.8, 1.0), -1.3, 0.5, 0, 75, 90, GLASS, Enum.Material.Glass, "Wedge")
		piece(m, "FrameBar", Vector3.new(3.4, 0.3, 0.3), 0.2, -0.9, 0, -12, 3, FRAME, Enum.Material.Metal)
	end,
	ENV_StoreDebris_Front_02 = function(m) -- coin du cadre plie et vitre
		piece(m, "FrameBar", Vector3.new(2.6, 0.3, 0.3), 0, 0, 0, 25, 0, FRAME, Enum.Material.Metal)
		piece(m, "FrameBar", Vector3.new(0.3, 0.3, 1.8), 1.15, 0.9, 0, 25, 0, FRAME, Enum.Material.Metal)
		piece(m, "Shard", Vector3.new(0.12, 1.2, 1.6), -0.6, 0.8, 0, -15, 90, GLASS, Enum.Material.Glass, "Wedge")
		piece(m, "Shard", Vector3.new(0.12, 0.7, 0.9), 0.6, -0.9, 0, 60, 90, GLASS, Enum.Material.Glass, "Wedge")
	end,
	ENV_StoreDebris_Street_01 = function(m) -- gros tas sur la route : beton, cadre, vitre
		piece(m, "Concrete", Vector3.new(2.0, 1.0, 1.6), 0, 0, 6, 15, -8, CONCRETE)
		piece(m, "Concrete", Vector3.new(1.4, 0.8, 1.2), 1.7, 0.6, -10, -30, 6, CONCRETE_DARK)
		piece(m, "Concrete", Vector3.new(1.0, 0.6, 1.0), -1.6, 0.8, 8, 40, 0, CONCRETE)
		piece(m, "FrameBar", Vector3.new(4.0, 0.32, 0.32), 0.3, -1.3, 0, 10, 8, FRAME, Enum.Material.Metal)
		piece(m, "Shard", Vector3.new(0.12, 1.2, 1.6), -0.6, -1.6, 0, 30, 90, GLASS, Enum.Material.Glass, "Wedge")
		piece(m, "Dust", Vector3.new(5.6, 0.05, 4.6), 0, 0, 0, 12, 0, DUST)
	end,
	ENV_StoreDebris_Street_02 = function(m) -- tas plus long : planches, carton, beton
		piece(m, "Concrete", Vector3.new(1.6, 0.9, 1.4), 0, 0, -6, 20, 10, CONCRETE)
		piece(m, "Board", Vector3.new(3.6, 0.2, 0.8), 1.6, 0.4, 0, -25, 6, SHELF, nil, nil, 0.4)
		piece(m, "Box", Vector3.new(1.2, 0.9, 1.1), -1.7, 0.3, 0, 35, 14, KRAFT)
		piece(m, "Concrete", Vector3.new(0.9, 0.5, 0.8), 0.6, -1.4, 10, 0, -6, CONCRETE_DARK)
		piece(m, "Shard", Vector3.new(0.12, 0.9, 1.2), -0.4, 1.4, 0, -60, 90, GLASS, Enum.Material.Glass, "Wedge")
		piece(m, "Dust", Vector3.new(6.0, 0.05, 4.0), 0.2, 0, 0, -8, 0, DUST)
	end,
}
local names = {}
for name in defs do
	table.insert(names, name)
end
table.sort(names)
for i, name in names do
	local m = newDebris(name)
	defs[name](m)
	m:PivotTo(CFrame.new((i - 1) * 7, 0, 0))
	m.Parent = debrisFolder
	local _, size = m:GetBoundingBox()
	table.insert(report, string.format("%s : %d pieces, %.1f x %.1f x %.1f", name, #m:GetChildren() - 1, size.X, size.Y, size.Z))
end
debrisFolder.Parent = chantier

print("[chantier outils et debris] " .. table.concat(report, " ; "))
return table.concat(report, "\n")
