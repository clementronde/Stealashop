--!strict
--[[
Chantier v3 (retour de Clement du 26/11 : « la devanture n'est pas cassée sur ton exemple, elle doit l'être »).
A lancer en Edit apres chantier_v2_build.luau, sur la COPIE ServerStorage/Previews/CHANTIER/CASSE_Superette
(jamais l'original de la map). Pas rejouable sur la meme copie : relancer d'abord chantier_v2_build.luau.
1. Un grand trou dans le mur de la devanture, autour de la vitrine et plus large qu'elle (x -15 a +14, jusqu'a
   y 16, dans le bandeau du haut), bords dechiquetes : SubtractAsync des vraies pieces (FrontWall_L, FrontWall_Mid,
   Lintel, UpperFacade, Plinth_1, Plinth_2) par un bloc et six blocs penches. Couleur, materiau et MaterialVariant
   gardes. Le rideau (Shutter) reste en place pour pouvoir descendre devant l'ouverture.
2. Les morceaux du mur (memes couleurs et materiau : beige du mur, rouge du linteau, gris du soubassement) sur le
   trottoir (dessus a 0,45) et la route (0), avec les eclats et le cadre deja poses par la v2.
3. Le store (Awning) arrache a gauche, il pend, encore tenu cote porte.
4. L'enseigne (SignPart et son cadre) penche de 7 degres, toujours lisible.
]]

local previews = game:GetService("ServerStorage"):FindFirstChild("Previews")
assert(previews, "ServerStorage/Previews absent")
local chantier = previews:FindFirstChild("CHANTIER")
assert(chantier, "Previews/CHANTIER absent")
local m = chantier:FindFirstChild("CASSE_Superette")
assert(m and m:IsA("Model"), "Previews/CHANTIER/CASSE_Superette absent : lance d'abord chantier_v2_build.luau")
local facade = m:FindFirstChild("Facade")
assert(facade, "Facade absent")
local pv = m:GetPivot()
local rng = Random.new(2611)
local report: { string } = {}
local function L(x: number, y: number, z: number): Vector3
	return pv:PointToWorldSpace(Vector3.new(x, y, z))
end
local function LCF(x: number, y: number, z: number, rz: number?): CFrame
	return CFrame.new(L(x, y, z)) * pv.Rotation * CFrame.Angles(0, 0, math.rad(rz or 0))
end

-- 1. le trou
local cutters: { BasePart } = {}
for _, c in {
	{ 0, 7, 26, 14, 0 }, -- grand bloc autour de la vitrine
	{ -13.5, 10, 8, 6, 35 },
	{ 12.5, 12, 7, 5, -30 },
	{ -6, 15.2, 9, 4, 12 },
	{ 5, 15.6, 8, 4.5, -18 },
	{ -14.5, 3, 5, 5, 45 },
	{ 14, 4, 4, 4, 30 },
} do
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.new(c[3], c[4], 8)
	p.CFrame = LCF(c[1], c[2], -53.5, c[5])
	p.Parent = chantier
	table.insert(cutters, p)
end
local cut = 0
for _, n in { "FrontWall_L", "FrontWall_Mid", "Lintel", "UpperFacade", "Plinth_1", "Plinth_2" } do
	local wall = facade:FindFirstChild(n)
	if wall and wall:IsA("BasePart") then
		local ok, result = pcall(function()
			return wall:SubtractAsync(cutters)
		end)
		if ok and result then
			local u = result :: UnionOperation
			u.Name = n
			u.Anchored = true
			u.UsePartColor = true
			u.Color = wall.Color
			u.Material = wall.Material
			u.MaterialVariant = wall.MaterialVariant
			for _, child in wall:GetChildren() do
				child.Parent = u
			end
			u.Parent = facade
			wall:Destroy()
			cut += 1
		else
			table.insert(report, n .. " : SubtractAsync a echoue (" .. tostring(result) .. ")")
		end
	end
end
for _, c in cutters do
	c:Destroy()
end
table.insert(report, cut .. " pieces de la devanture creusees")

-- 2. morceaux du mur dehors
local function sample(n: string): BasePart?
	local p = facade:FindFirstChild(n)
	return if p and p:IsA("BasePart") then p else nil
end
local wallRef, lintelRef, plinthRef = sample("FrontWall_L"), sample("Lintel"), sample("Plinth_1")
local chunks = 0
local function chunk(ref: BasePart?, sx: number, sy: number, sz: number, x: number, z: number)
	if not ref then
		return
	end
	local p = Instance.new("Part")
	p.Name = "WallChunk"
	p.Size = Vector3.new(sx, sy, sz)
	p.Color = ref.Color
	p.Material = ref.Material
	p.MaterialVariant = ref.MaterialVariant
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local rot = CFrame.Angles(math.rad(rng:NextNumber(-35, 35)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-35, 35)))
	local halfY = math.abs(rot.XVector.Y) * sx / 2 + math.abs(rot.YVector.Y) * sy / 2 + math.abs(rot.ZVector.Y) * sz / 2
	local floor = if z > -61.5 then 0.45 else 0
	p.CFrame = CFrame.new(L(x, floor + halfY - 0.1, z)) * pv.Rotation * rot
	p.Parent = facade
	chunks += 1
end
for _ = 1, 14 do
	chunk(wallRef, rng:NextNumber(1.4, 3.6), rng:NextNumber(1.0, 2.6), rng:NextNumber(0.9, 1.5), rng:NextNumber(-16, 15), rng:NextNumber(-74, -55.5))
end
for _ = 1, 3 do
	chunk(lintelRef, rng:NextNumber(2, 4.5), 0.9, 0.3, rng:NextNumber(-12, 12), rng:NextNumber(-70, -57))
end
for _ = 1, 3 do
	chunk(plinthRef, rng:NextNumber(1.5, 3), 1.2, 0.45, rng:NextNumber(-14, 12), rng:NextNumber(-62, -56))
end
table.insert(report, chunks .. " morceaux du mur dehors")

-- 3. le store arrache a gauche, tenu cote porte
local awning = m:FindFirstChild("Awning")
if awning and awning:IsA("Model") then
	local hinge = CFrame.new(L(23, 12.6, -56.8)) * pv.Rotation
	local r = hinge * CFrame.Angles(math.rad(10), 0, math.rad(18)) * hinge:Inverse()
	awning:PivotTo(r * awning:GetPivot())
	table.insert(report, "store arrache (18 degres, tenu cote porte)")
end

-- 4. l'enseigne penche
local hingeS = CFrame.new(L(19.5, 18.4, -55.2)) * pv.Rotation
local rs = hingeS * CFrame.Angles(0, 0, math.rad(7)) * hingeS:Inverse()
local tilted = 0
for _, p in { m:FindFirstChild("SignPart"), facade:FindFirstChild("SignBorder_1"), facade:FindFirstChild("SignBorder_2"), facade:FindFirstChild("SignBorder_3"), facade:FindFirstChild("SignBorder_4") } do
	if p and p:IsA("BasePart") then
		p.CFrame = rs * p.CFrame
		tilted += 1
	end
end
table.insert(report, "enseigne penchee (" .. tilted .. " pieces)")

print("[chantier v3] " .. table.concat(report, " ; "))
return table.concat(report, "\n")
