--!strict
--[[
Chantier v4 (retour de Clement du 26/11 sur la v3 : « encore plus détruite et les débris bien au sol »).
A lancer en Edit apres chantier_v3_devanture.luau, sur la COPIE ServerStorage/Previews/CHANTIER/CASSE_Superette.
Pas rejouable sur la meme copie : relancer d'abord chantier_v2_build.luau puis chantier_v3_devanture.luau.
1. Plus de destruction : le trou s'agrandit (x -24 a +16, jusqu'a y 22 au milieu, bord du haut en dents de scie),
   sans toucher a la porte (x 16,7) ni au rideau ; un gros pan du haut de la facade s'effondre et s'appuie sur le tas ;
   fissures sombres qui partent du trou et petits eclats encastres sur les bords (le mur a l'air ecrase, pas decoupe).
2. Store presque arrache (il pend, un bout au sol), enseigne decrochee a gauche (13 degres), toujours lisible.
3. Plus de morceaux du mur, de 0,6 a 6 studs, en tas contre le bas du mur qui deborde sur la route. Tous les debris
   (morceaux, eclats de vitre, cadre) sont reposes au sol : face la plus large en bas, un peu de pente, et empiles par
   une carte des hauteurs (cases de 0,5 stud) qui suit le vrai sol (interieur 0,475, trottoir 0,45, route 0) : rien
   ne flotte, chaque piece repose sur le sol ou sur une autre. Les eclats de vitre sont couches a plat.
(Le calcul ne passe pas par Raycast : la copie est dans ServerStorage, hors de Workspace.)
]]

local previews = game:GetService("ServerStorage"):FindFirstChild("Previews")
assert(previews, "ServerStorage/Previews absent")
local chantier = previews:FindFirstChild("CHANTIER")
assert(chantier, "Previews/CHANTIER absent")
local m = chantier:FindFirstChild("CASSE_Superette")
assert(m and m:IsA("Model"), "CASSE_Superette absent")
local facade = m:FindFirstChild("Facade")
assert(facade, "Facade absent")
local pv = m:GetPivot()
local rng = Random.new(26114)
local report: { string } = {}
local function L(x: number, y: number, z: number): Vector3
	return pv:PointToWorldSpace(Vector3.new(x, y, z))
end
local function LCF(x: number, y: number, z: number, rz: number?): CFrame
	return CFrame.new(L(x, y, z)) * pv.Rotation * CFrame.Angles(0, 0, math.rad(rz or 0))
end
local WALL_FRONT = -53.95 -- face avant du mur de la devanture (z local)
local HOLE_X0, HOLE_X1 = -24, 16

-- ===== 1. trou plus grand, bord du haut en dents de scie =====
local cutters: { BasePart } = {}
local function cutter(x: number, y: number, sx: number, sy: number, rz: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.new(sx, sy, 8)
	p.CFrame = LCF(x, y, -53.5, rz)
	p.Parent = chantier
	table.insert(cutters, p)
end
cutter(-4, 8, 38, 16, 0) -- coeur du trou, de x -23 a 15
for _, c in {
	{ -20, 15, 7, 6, 28 }, { -13, 18, 8, 6, -15 }, { -5, 20.5, 9, 5, 9 }, { 3, 19.5, 8, 5, -22 },
	{ 10, 16.5, 7, 6, 33 }, { 14.5, 11, 3.2, 7, -12 }, { -23.5, 7, 5, 9, 18 }, { -22, 1.5, 6, 4, -30 },
} do
	cutter(c[1], c[2], c[3], c[4], c[5])
end
local cut = 0
for _, wall in facade:GetChildren() do
	if (wall:IsA("BasePart")) and (wall.Name == "FrontWall_L" or wall.Name == "FrontWall_Mid" or wall.Name == "Lintel" or wall.Name == "UpperFacade" or wall.Name == "Plinth_1" or wall.Name == "Plinth_2") then
		local ok, result = pcall(function()
			return wall:SubtractAsync(cutters)
		end)
		if ok and result then
			local u = result :: UnionOperation
			u.Name = wall.Name
			u.Anchored = true
			u.UsePartColor = true
			u.Color = wall.Color
			u.Material = wall.Material
			u.MaterialVariant = wall.MaterialVariant
			u.Parent = facade
			wall:Destroy()
			cut += 1
		end
	end
end
for _, c in cutters do
	c:Destroy()
end
table.insert(report, cut .. " pieces recreusees")

local function ref(n: string): BasePart
	local p = facade:FindFirstChild(n)
	assert(p and p:IsA("BasePart"), "Facade/" .. n .. " absent")
	return p
end
local wallRef = ref("FrontWall_L")
local upperRef = ref("UpperFacade")
local lintelRef = ref("Lintel")
local plinthRef = ref("Plinth_1")
local function newPart(name: string, ref: BasePart, size: Vector3, cf: CFrame, darker: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	local c = ref.Color
	local k = darker or 1
	p.Color = Color3.new(c.R * k, c.G * k, c.B * k)
	p.Material = ref.Material
	p.MaterialVariant = ref.MaterialVariant
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = facade
	return p
end

-- bord du trou (approche) : pour un x, la hauteur du haut du trou ; sert aux fissures et aux eclats
local function holeTop(x: number): number
	if x < HOLE_X0 or x > HOLE_X1 then
		return 0
	end
	local t = (x - HOLE_X0) / (HOLE_X1 - HOLE_X0)
	return 15 + 6 * math.sin(t * math.pi) + 1.5 * math.sin(t * 17)
end
-- fissures : traits sombres qui partent du bord du trou
local cracks = 0
for _ = 1, 26 do
	local onSide = rng:NextNumber() < 0.35
	local x, y, ang
	if onSide then
		local left = rng:NextNumber() < 0.6
		x = if left then HOLE_X0 - 0.3 else HOLE_X1 + 0.3
		y = rng:NextNumber(1.5, 14)
		ang = if left then rng:NextNumber(150, 210) else rng:NextNumber(-30, 30)
	else
		x = rng:NextNumber(HOLE_X0 + 1, HOLE_X1 - 1)
		y = holeTop(x) + 0.3
		ang = rng:NextNumber(30, 150)
	end
	local len = rng:NextNumber(1.5, 5)
	local dir = Vector3.new(math.cos(math.rad(ang)), math.sin(math.rad(ang)), 0)
	local mid = Vector3.new(x, y, 0) + dir * (len / 2)
	local front = if mid.Y > 12 then -54.95 else WALL_FRONT - 0.02
	local ref = if mid.Y > 12 then upperRef else wallRef
	newPart("Crack", ref, Vector3.new(len, rng:NextNumber(0.12, 0.25), 0.08), LCF(mid.X, mid.Y, front, ang), 0.45)
	cracks += 1
end
-- eclats encastres sur les bords du trou
local bits = 0
for _ = 1, 22 do
	local x = rng:NextNumber(HOLE_X0, HOLE_X1)
	local y = holeTop(x)
	if rng:NextNumber() < 0.3 then
		x = if rng:NextNumber() < 0.6 then HOLE_X0 else HOLE_X1
		y = rng:NextNumber(1, 14)
	end
	local s = rng:NextNumber(0.6, 1.6)
	local front = if y > 12 then -54.4 else -53.6
	newPart("EdgeBit", if y > 12 then upperRef else wallRef, Vector3.new(s, s * rng:NextNumber(0.6, 1.2), rng:NextNumber(0.8, 1.6)),
		LCF(x, y, front, rng:NextNumber(0, 90)) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), math.rad(rng:NextNumber(-20, 20)), 0), rng:NextNumber(0.85, 1))
	bits += 1
end
table.insert(report, cracks .. " fissures, " .. bits .. " eclats sur les bords")

-- ===== 2. store presque arrache, enseigne decrochee a gauche =====
local awning = m:FindFirstChild("Awning")
if awning and awning:IsA("Model") then
	local hinge = CFrame.new(L(23, 12.6, -56.8)) * pv.Rotation
	awning:PivotTo(hinge * CFrame.Angles(math.rad(14), math.rad(-8), math.rad(14)) * hinge:Inverse() * awning:GetPivot())
end
local hingeS = CFrame.new(L(19.5, 18.4, -55.2)) * pv.Rotation
local rs = hingeS * CFrame.Angles(math.rad(-4), 0, math.rad(6)) * hingeS:Inverse() -- 7 + 6 = 13 degres en tout
for _, p in { m:FindFirstChild("SignPart"), facade:FindFirstChild("SignBorder_1"), facade:FindFirstChild("SignBorder_2"), facade:FindFirstChild("SignBorder_3"), facade:FindFirstChild("SignBorder_4") } do
	if p and p:IsA("BasePart") then
		p.CFrame = rs * p.CFrame
	end
end
table.insert(report, "store presque arrache, enseigne a 13 degres")

-- ===== 3. debris au sol, empiles =====
-- nouveaux morceaux du mur, de petits a tres gros, et le pan du haut effondre
for _, old in facade:GetChildren() do
	if old.Name == "WallChunk" then
		old:Destroy()
	end
end
local loose: { BasePart } = {}
local function addChunk(ref: BasePart, sx: number, sy: number, sz: number, name: string?)
	table.insert(loose, newPart(name or "WallChunk", ref, Vector3.new(sx, sy, sz), CFrame.new(), rng:NextNumber(0.9, 1)))
end
addChunk(upperRef, 13, 5.5, 2.4, "FacadeSlab") -- le pan du haut effondre
for _ = 1, 6 do
	addChunk(wallRef, rng:NextNumber(3.5, 6), rng:NextNumber(2.5, 4), rng:NextNumber(1.2, 1.6))
end
for _ = 1, 14 do
	addChunk(wallRef, rng:NextNumber(1.6, 3.4), rng:NextNumber(1.2, 2.6), rng:NextNumber(0.9, 1.5))
end
for _ = 1, 18 do
	local s = rng:NextNumber(0.6, 1.4)
	addChunk(wallRef, s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.6, 1))
end
for _ = 1, 4 do
	addChunk(upperRef, rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), 1.2)
end
for _ = 1, 4 do
	addChunk(lintelRef, rng:NextNumber(2, 5), 0.9, 0.3)
end
for _ = 1, 3 do
	addChunk(plinthRef, rng:NextNumber(1.5, 3), 1.2, 0.45)
end
-- eclats de vitre et morceaux du cadre deja la
local fractured = m:FindFirstChild("WindowFractured")
if fractured then
	for _, s in fractured:GetChildren() do
		if s:IsA("BasePart") then
			table.insert(loose, s)
		end
	end
end
for _, n in { "Frame_T", "Frame_L", "Frame_B" } do
	local p = facade:FindFirstChild(n)
	if p and p:IsA("BasePart") then
		table.insert(loose, p)
	end
end

-- carte des hauteurs, en coordonnees locales du magasin
local CELL = 0.5
local heights: { [number]: number } = {}
local function key(ix: number, iz: number): number
	return ix * 100000 + iz
end
local function groundAt(x: number, z: number): number
	if z > WALL_FRONT then
		return 0.475 -- sol du magasin (dans le trou)
	elseif z > -61.5 then
		return 0.45 -- trottoir
	end
	return 0 -- route
end
local function heightAt(x: number, z: number): number
	local ix, iz = math.floor(x / CELL), math.floor(z / CELL)
	return math.max(groundAt(x, z), heights[key(ix, iz)] or -1)
end
-- la plus petite dimension devient la hauteur ; renvoie la taille posee (largeur X, hauteur Y, profondeur Z) et la rotation
local function lieFlat(p: BasePart): (Vector3, CFrame)
	local s = p.Size
	if s.X <= s.Y and s.X <= s.Z then
		return Vector3.new(s.Y, s.X, s.Z), CFrame.Angles(0, 0, math.rad(90))
	elseif s.Z <= s.X and s.Z <= s.Y then
		return Vector3.new(s.X, s.Z, s.Y), CFrame.Angles(math.rad(90), 0, 0)
	end
	return s, CFrame.new()
end
table.sort(loose, function(a, b)
	return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
end)
local placed = 0
for i, p in loose do
	local flat, lieRot = lieFlat(p)
	local isGlass = p.Parent == fractured
	-- position : en tas contre le bas du mur (le pan du haut le plus pres du mur), puis de plus en plus loin, jusque sur la route
	local x, z
	if p.Name == "FacadeSlab" then
		x, z = -4, WALL_FRONT - 3.2
	else
		x = rng:NextNumber(HOLE_X0 - 2, HOLE_X1 + 1)
		local reach = rng:NextNumber() ^ 1.6 -- plus dense pres du mur
		z = WALL_FRONT - 0.6 - reach * 26 + (if rng:NextNumber() < 0.15 then rng:NextNumber(2, 5) else 0) -- quelques-uns tombes dedans
	end
	local yaw = rng:NextNumber(0, 360)
	local tilt = if isGlass then 3 elseif p.Name == "FacadeSlab" then 0 else 9
	local tiltRot = CFrame.Angles(math.rad(rng:NextNumber(-tilt, tilt)), 0, math.rad(rng:NextNumber(-tilt, tilt)))
	-- empreinte au sol apres le tour sur Y
	local c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	local hx, hz = flat.X / 2, flat.Z / 2
	local ex = math.abs(c) * hx + math.abs(s) * hz
	local ez = math.abs(s) * hx + math.abs(c) * hz
	-- hors du trou, la piece reste devant le mur (elle s'y appuie, sans le traverser)
	if x - ex < HOLE_X0 + 0.5 or x + ex > HOLE_X1 - 0.5 then
		z = math.min(z, WALL_FRONT - ez - 0.05)
	end
	local base = 0
	local cells = {}
	for gx = math.floor((x - ex) / CELL), math.floor((x + ex) / CELL) do
		for gz = math.floor((z - ez) / CELL), math.floor((z + ez) / CELL) do
			local cx, cz = (gx + 0.5) * CELL - x, (gz + 0.5) * CELL - z
			local lx, lz = c * cx - s * cz, s * cx + c * cz -- dans le repere de la piece
			if math.abs(lx) <= hx and math.abs(lz) <= hz then
				base = math.max(base, heightAt((gx + 0.5) * CELL, (gz + 0.5) * CELL))
				table.insert(cells, key(gx, gz))
			end
		end
	end
	if #cells == 0 then
		base = heightAt(x, z)
	end
	local rot = CFrame.Angles(0, math.rad(yaw), 0) * tiltRot * lieRot
	-- demi-hauteur reelle apres la pente (pour que le bas touche juste la surface)
	local halfY = math.abs(rot.XVector.Y) * p.Size.X / 2 + math.abs(rot.YVector.Y) * p.Size.Y / 2 + math.abs(rot.ZVector.Y) * p.Size.Z / 2
	p.CFrame = CFrame.new(L(x, base + halfY - 0.03, z)) * pv.Rotation * rot
	if p.Name == "FacadeSlab" then
		-- le pan du haut s'appuie contre le mur : penche vers la rue, le haut contre la facade
		p.CFrame = CFrame.new(L(x, base + 2.7, WALL_FRONT - 1.6)) * pv.Rotation * CFrame.Angles(math.rad(62), math.rad(rng:NextNumber(-8, 8)), math.rad(4))
	end
	local top = base + (if p.Name == "FacadeSlab" then 3.6 else 2 * halfY) - 0.05
	for _, k in cells do
		heights[k] = math.max(heights[k] or -1, top)
	end
	if isGlass then
		p.Transparency = 0.3
	end
	placed += 1
end
table.insert(report, placed .. " debris poses au sol et empiles (dont le pan du haut de la facade)")

print("[chantier v4] " .. table.concat(report, " ; "))
return table.concat(report, "\n")
