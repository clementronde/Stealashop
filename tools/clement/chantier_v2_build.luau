--!strict
--[[
Chantier v2 (retour de Clement du 26/11 : « J'aurais aimé que ce soit les vrais débris des bâtiments, les outils ne
sont pas bien placés dans les mains »). A lancer en Edit apres chantier_planche_build.luau et
chantier_outils_debris_build.luau. Tout va dans ServerStorage/Previews/CHANTIER ; l'original de la map n'est jamais touche.
1. Outils refaits, tenus par le bas : Tool, Grip par defaut, la Handle est la partie DANS le poing (centree sur
   RightGripAttachment), l'outil s'allonge en +Y. Marteau : tete en haut, a 1,1 du poing ; tournevis : lame en +Y ;
   planche : tenue au quart de sa longueur.
2. Trois ouvriers differents : NPC_Worker_01 a _03 (peau, t-shirt, gilet, casque).
3. Maquette de la casse sur une COPIE de STORE_Z1_Superette (CASSE_Superette) : les vraies pieces du magasin, avec
   leurs couleurs et leurs materiaux, deplacees comme apres le passage d'un objet geant : rayon A renverse, produits
   par terre, rayon B casse, trou dans le plafond et dalles tombees, vitrine et cadre de la devanture eclates sur le
   trottoir et la route. Tags et scripts retires de la copie. Les ENV_StoreDebris_* de la v1 restent dans Debris (pas
   supprimes) mais ne servent plus.
]]

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local previews = ServerStorage:FindFirstChild("Previews")
assert(previews, "ServerStorage/Previews absent : lance d'abord chantier_planche_build.luau")
local chantier = previews:FindFirstChild("CHANTIER")
assert(chantier, "Previews/CHANTIER absent : lance d'abord chantier_planche_build.luau")
local function need(parent: Instance, name: string): Instance
	local c = parent:FindFirstChild(name)
	assert(c, parent:GetFullName() .. "/" .. name .. " absent")
	return c
end
local report: { string } = {}
local rng = Random.new(26112026)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = parent
	return p
end

-- ===== 1. outils tenus par le bas =====
do
	local old = chantier:FindFirstChild("Outils")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Outils"
	local function tool(name: string): Tool
		local t = Instance.new("Tool")
		t.Name = name
		t.RequiresHandle = true
		t.CanBeDropped = false
		t.ManualActivationOnly = true
		t.Parent = folder
		return t
	end
	local function weld(h: BasePart, p: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = h
		w.Part1 = p
		w.Parent = p
	end
	local RED = Color3.fromHex("E23B3B")
	local WOOD = Color3.fromHex("A0703C")
	local METAL = Color3.fromHex("5A6270")
	local STEEL = Color3.fromHex("C9CED6")
	do -- marteau : poignee rouge dans le poing, manche bois au-dessus, tete en haut (frappe vers -Z)
		local t = tool("TOOL_Worker_Hammer")
		local h = part(t, "Handle", Vector3.new(0.24, 0.55, 0.24), CFrame.new(), RED)
		for _, p in {
			part(t, "Shaft", Vector3.new(0.18, 0.75, 0.18), CFrame.new(0, 0.65, 0), WOOD),
			part(t, "Head", Vector3.new(0.3, 0.3, 0.7), CFrame.new(0, 1.12, -0.05), METAL, Enum.Material.Metal),
			part(t, "Face", Vector3.new(0.34, 0.34, 0.1), CFrame.new(0, 1.12, -0.42), METAL, Enum.Material.Metal),
			part(t, "Claw", Vector3.new(0.22, 0.2, 0.28), CFrame.new(0, 1.18, 0.4) * CFrame.Angles(math.rad(-25), 0, 0), METAL, Enum.Material.Metal),
		} do
			weld(h, p)
		end
	end
	do -- tournevis : manche rouge dans le poing, lame en +Y
		local t = tool("TOOL_Worker_Screwdriver")
		t.Grip = CFrame.Angles(math.rad(90), 0, 0) -- chef animation 26/11 : lame dans le prolongement du poing (poignets <= 55 deg)
		local h = part(t, "Handle", Vector3.new(0.26, 0.55, 0.26), CFrame.new(), RED)
		for _, p in {
			part(t, "Ring", Vector3.new(0.28, 0.08, 0.28), CFrame.new(0, 0.3, 0), Color3.fromHex("F7C51E")),
			part(t, "Shaft", Vector3.new(0.07, 0.62, 0.07), CFrame.new(0, 0.64, 0), STEEL, Enum.Material.Metal),
			part(t, "Tip", Vector3.new(0.13, 0.1, 0.03), CFrame.new(0, 0.99, 0), STEEL, Enum.Material.Metal),
		} do
			weld(h, p)
		end
	end
	do -- planche portee sur la tranche au-dessus de l'epaule (accord du chef animation, 26/11) : tenue par son bord du
		-- bas, au milieu de sa longueur ; longueur 5 en Y centree sur le poing, largeur 0,9 du poing vers -Z, epaisseur 0,3 en X
		local t = tool("TOOL_Worker_Plank")
		t.Grip = CFrame.Angles(math.rad(21), math.rad(-6), math.rad(169)) -- chef animation 26/11 (coude a l'envers corrige) : planche a plat sur l'epaule, d'avant en arriere, Board vers le haut
		local h = part(t, "Handle", Vector3.new(0.3, 0.8, 0.14), CFrame.new(), Color3.fromHex("C8955A"))
		for _, p in {
			part(t, "Board", Vector3.new(0.3, 5, 0.9), CFrame.new(0, 0, -0.4), Color3.fromHex("C8955A")),
			part(t, "Grain", Vector3.new(0.32, 4.6, 0.08), CFrame.new(0, 0.1, -0.2), Color3.fromHex("A97A45")),
			part(t, "Grain", Vector3.new(0.32, 4.2, 0.08), CFrame.new(0, -0.1, -0.62), Color3.fromHex("A97A45")),
		} do
			weld(h, p)
		end
	end
	folder.Parent = chantier
	table.insert(report, "outils refaits : Handle = partie dans le poing, outil en +Y")
end

-- ===== 2. trois ouvriers =====
do
	local base = chantier:FindFirstChild("NPC_Worker_01")
	assert(base and base:IsA("Model"), "NPC_Worker_01 absent")
	for _, n in { "NPC_Worker_02", "NPC_Worker_03" } do
		local old = chantier:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local LOOKS = {
		NPC_Worker_01 = { skin = "D9A066", shirt = "3E6FB0", legs = "2C3E66", vest = "FF7A1A", vest2 = "E2650F", hat = "F7C51E", hat2 = "E0AE12" },
		NPC_Worker_02 = { skin = "8D5524", shirt = "6B7280", legs = "3A3F4A", vest = "D7F21E", vest2 = "B9D213", hat = "F4F5F7", hat2 = "D8DBE0" },
		NPC_Worker_03 = { skin = "F1C7A5", shirt = "2F6B4F", legs = "4A3A2A", vest = "E8452C", vest2 = "C2351F", hat = "FF8C1A", hat2 = "E0700A" },
	}
	local SKIN = { "Head", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand" }
	local SHIRT = { "UpperTorso", "LeftUpperArm", "RightUpperArm" }
	local LEGS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }
	for name, look in LOOKS do
		local m = if name == "NPC_Worker_01" then base else base:Clone()
		m.Name = name
		local function paint(list: { string }, hex: string)
			for _, pn in list do
				local p = m:FindFirstChild(pn)
				if p and p:IsA("BasePart") then
					p.Color = Color3.fromHex(hex)
				end
			end
		end
		paint(SKIN, look.skin)
		paint(SHIRT, look.shirt)
		paint(LEGS, look.legs)
		for _, acc in m:GetChildren() do
			if acc:IsA("Accessory") then
				for _, p in acc:GetDescendants() do
					if p:IsA("BasePart") then
						local vestBody = p.Name:match("^Front") ~= nil or p.Name == "Back" or p.Name:match("^Side") ~= nil
						if acc.Name == "ACC_Worker_Gilet" and vestBody then
							p.Color = Color3.fromHex(look.vest)
						elseif acc.Name == "ACC_Worker_Gilet" and p.Name == "Pocket" then
							p.Color = Color3.fromHex(look.vest2)
						elseif acc.Name == "ACC_Worker_HardHat" then
							p.Color = if p.Name == "Band" then Color3.fromHex("1A1A1F") elseif p.Name == "Brim" or p.Name == "Ridge" then Color3.fromHex(look.hat2) else Color3.fromHex(look.hat)
						end
					end
				end
			end
		end
		m.Parent = chantier
	end
	table.insert(report, "ouvriers : NPC_Worker_01, _02, _03")
end

-- ===== 3. maquette de la casse sur une copie de la Superette =====
do
	local old = chantier:FindFirstChild("CASSE_Superette")
	if old then
		old:Destroy()
	end
	local src = need(need(need(workspace, "Map"), "Zone_1"), "STORE_Z1_Superette")
	assert(src:IsA("Model"), "STORE_Z1_Superette n'est pas un Model")
	local m = src:Clone()
	m.Name = "CASSE_Superette"
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		else
			for _, tag in CollectionService:GetTags(d) do
				CollectionService:RemoveTag(d, tag)
			end
		end
	end
	for _, tag in CollectionService:GetTags(m) do
		CollectionService:RemoveTag(m, tag)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.Parent = chantier -- dans le DataModel avant SubtractAsync
	local pv = m:GetPivot()
	local function L(x: number, y: number, z: number): Vector3
		return pv:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local function rotateAround(p: BasePart, pivotLocal: Vector3, rot: CFrame)
		local pivotW = CFrame.new(L(pivotLocal.X, pivotLocal.Y, pivotLocal.Z)) * pv.Rotation
		p.CFrame = pivotW * rot * pivotW:Inverse() * p.CFrame
	end
	local function dropToFloor(p: BasePart, spread: number, zMin: number?, zMax: number?)
		local lp = pv:PointToObjectSpace(p.Position)
		local x = lp.X + rng:NextNumber(-spread, spread)
		local z = math.clamp(lp.Z + rng:NextNumber(-spread, spread), zMin or -50, zMax or 50)
		local rot = CFrame.Angles(math.rad(rng:NextNumber(-90, 90)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-90, 90)))
		local h = math.min(p.Size.X, p.Size.Y, p.Size.Z) / 2
		p.CFrame = CFrame.new(L(x, 0.5 + h, z)) * pv.Rotation * rot
	end
	local interior = need(m, "Interior")
	-- rayon A renverse vers -X (il pivote sur son arete au sol), ses produits tombent autour
	local fallen = 0
	for _, p in interior:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^Shelf_A_") then
			if p.Name:match("_P%d+$") or p.Name:match("_C%d+$") then
				dropToFloor(p, 4)
			else
				rotateAround(p, Vector3.new(-13.6, 0.5, -21.5), CFrame.Angles(0, 0, math.rad(78)))
			end
			fallen += 1
		end
	end
	-- rayon B casse : ses planches penchent, la moitie de ses produits par terre
	local broken = 0
	for _, p in interior:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^Shelf_B_") then
			if (p.Name:match("_P%d+$") or p.Name:match("_C%d+$")) and rng:NextNumber() < 0.5 then
				dropToFloor(p, 3)
				broken += 1
			elseif p.Name:match("Board%d$") then
				rotateAround(p, pv:PointToObjectSpace(p.Position) + Vector3.new(0, 0, -15), CFrame.Angles(math.rad(-14), 0, 0))
			elseif p.Name == "Shelf_B_Top" or p.Name == "Shelf_B_Header" then
				rotateAround(p, Vector3.new(13.5, 7.4, -36.5), CFrame.Angles(math.rad(-9), 0, math.rad(-6)))
			end
		end
	end
	-- plafond : un trou au-dessus du rayon A, trois dalles tombees, une lampe qui pend
	local ceiling = interior:FindFirstChild("Ceiling")
	local holeOk = false
	if ceiling and ceiling:IsA("BasePart") then
		local cutter = Instance.new("Part")
		cutter.Size = Vector3.new(16, 2, 14)
		cutter.Anchored = true
		cutter.CFrame = CFrame.new(L(-9, 18.5, -24)) * pv.Rotation * CFrame.Angles(0, math.rad(17), 0)
		cutter.Parent = chantier
		local ok, result = pcall(function()
			return ceiling:SubtractAsync({ cutter })
		end)
		cutter:Destroy()
		if ok and result then
			local union = result :: UnionOperation
			union.Name = "Ceiling"
			union.Anchored = true
			union.Parent = interior
			ceiling:Destroy()
			holeOk = true
			for i, spec in { { -12, -28, 5.5, 4.5, 34 }, { -6, -19, 4.5, 4, -22 }, { -3, -30, 3.5, 3, 58 } } do
				local slab = part(interior, "CeilingFallen_" .. i, Vector3.new(spec[3], 0.15, spec[4]), CFrame.new(), union.Color, union.Material)
				slab.Anchored = true
				slab.CFrame = CFrame.new(L(spec[1], 1.2 + i * 0.4, spec[2])) * pv.Rotation * CFrame.Angles(math.rad(spec[5]), math.rad(i * 37), math.rad(-spec[5] / 2))
			end
		end
	end
	for _, p in interior:GetChildren() do
		if p:IsA("BasePart") and p.Name == "CeilingLight_Front" then
			rotateAround(p, pv:PointToObjectSpace(p.Position) + Vector3.new(2, 0.3, 0), CFrame.Angles(0, 0, math.rad(-35)))
		end
	end
	-- devanture : la vitre est en morceaux, les eclats et le cadre sur le trottoir et la route
	local window = m:FindFirstChild("Window")
	local glassColor = Color3.fromHex("BFE3F2")
	if window and window:IsA("BasePart") then
		glassColor = window.Color
		window.Transparency = 1
	end
	local shards = 0
	local fractured = m:FindFirstChild("WindowFractured")
	if fractured then
		for _, s in fractured:GetChildren() do
			if s:IsA("BasePart") then
				s.Transparency = 0.3
				s.Color = glassColor
				local x = rng:NextNumber(-12, 12)
				local z = rng:NextNumber(-70, -56)
				local h = math.min(s.Size.X, s.Size.Y, s.Size.Z) / 2
				s.CFrame = CFrame.new(L(x, h + 0.05, z)) * pv.Rotation * CFrame.Angles(math.rad(90 + rng:NextNumber(-15, 15)), math.rad(rng:NextNumber(0, 360)), 0)
				shards += 1
			end
		end
	end
	local facade = need(m, "Facade")
	local frameT = need(facade, "Frame_T") :: BasePart
	frameT.CFrame = CFrame.new(L(1.5, 0.35, -60)) * pv.Rotation * CFrame.Angles(0, math.rad(-14), math.rad(90))
	local frameR = need(facade, "Frame_R") :: BasePart
	rotateAround(frameR, Vector3.new(9.5, 0.5, -53.2), CFrame.Angles(math.rad(-38), 0, math.rad(-12)))
	local frameL = need(facade, "Frame_L") :: BasePart
	frameL.CFrame = CFrame.new(L(-7, 0.5, -64)) * pv.Rotation * CFrame.Angles(0, math.rad(62), math.rad(90))
	local frameB = need(facade, "Frame_B") :: BasePart
	frameB.CFrame = CFrame.new(L(-1, 0.25, -57.5)) * pv.Rotation * CFrame.Angles(0, math.rad(9), 0)
	table.insert(report, string.format("CASSE_Superette : %d pieces du rayon A renversees, %d produits du rayon B par terre, trou du plafond %s, %d eclats de vitre dehors, cadre (Frame_T, _L, _B) a terre, Frame_R penche",
		fallen, broken, if holeOk then "creuse" else "ECHEC", shards))
end

print("[chantier v2] " .. table.concat(report, " ; "))
return table.concat(report, "\n")
