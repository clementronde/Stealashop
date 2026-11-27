--!strict
--[[
Chantier v4b : les deux corrections validees par Clement le 26/11 (« Oui, corrige-les ») sur la v4.
A lancer en Edit apres chantier_v4_devanture.luau, sur la copie ServerStorage/Previews/CHANTIER/CASSE_Superette.
1. Fissures : chaque fissure (Crack) est testee contre les blocs qui ont creuse le trou (v3 et v4, rectangles dans le
   plan du mur). La partie qui passe dans le vide est retiree ; une fissure de moins de 0,8 stud est supprimee.
2. Tas resserre contre le bas du mur, plus haut et plus massif : tous les debris (morceaux, eclats, cadre, pan de
   facade) sont reposes par la carte des hauteurs, a 0 - 12 studs du mur au lieu de 0 - 26, et plus serres en x.
   Rien ne flotte : chaque piece repose sur le sol (interieur 0,475, trottoir 0,45, route 0) ou sur une autre.
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
local function L(x: number, y: number, z: number): Vector3
	return pv:PointToWorldSpace(Vector3.new(x, y, z))
end
local report: { string } = {}
local WALL_FRONT = -53.95
local HOLE_X0, HOLE_X1 = -24, 16

-- ===== 1. fissures hors du vide =====
-- blocs qui ont creuse le trou : { x, y, largeur, hauteur, angle } (v3 puis v4)
local CUTTERS = {
	{ 0, 7, 26, 14, 0 }, { -13.5, 10, 8, 6, 35 }, { 12.5, 12, 7, 5, -30 }, { -6, 15.2, 9, 4, 12 },
	{ 5, 15.6, 8, 4.5, -18 }, { -14.5, 3, 5, 5, 45 }, { 14, 4, 4, 4, 30 },
	{ -4, 8, 38, 16, 0 }, { -20, 15, 7, 6, 28 }, { -13, 18, 8, 6, -15 }, { -5, 20.5, 9, 5, 9 },
	{ 3, 19.5, 8, 5, -22 }, { 10, 16.5, 7, 6, 33 }, { 14.5, 11, 3.2, 7, -12 }, { -23.5, 7, 5, 9, 18 }, { -22, 1.5, 6, 4, -30 },
}
local function inVoid(x: number, y: number): boolean
	for _, c in CUTTERS do
		local a = math.rad(-c[5])
		local dx, dy = x - c[1], y - c[2]
		local lx, ly = dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a)
		if math.abs(lx) <= c[3] / 2 + 0.1 and math.abs(ly) <= c[4] / 2 + 0.1 then
			return true
		end
	end
	return false
end
local trimmed, removed = 0, 0
for _, p in facade:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Crack" then
		local cf = pv:ToObjectSpace(p.CFrame)
		local dir = cf.XVector
		local center = cf.Position
		local half = p.Size.X / 2
		-- garde le plus long morceau continu hors du vide, echantillonne tous les 0,1 stud
		local bestA, bestB, a = 0, -1, nil :: number?
		local steps = math.max(2, math.floor(p.Size.X / 0.1))
		for i = 0, steps do
			local t = -half + p.Size.X * i / steps
			local q = center + dir * t
			local ok = not inVoid(q.X, q.Y)
			if ok and a == nil then
				a = t
			end
			if (not ok or i == steps) and a ~= nil then
				local b = if ok then t else t - p.Size.X / steps
				if b - a > bestB - bestA then
					bestA, bestB = a, b
				end
				a = nil
			end
		end
		local len = bestB - bestA
		if len < 0.8 then
			p:Destroy()
			removed += 1
		elseif len < p.Size.X - 0.05 then
			local mid = (bestA + bestB) / 2
			p.Size = Vector3.new(len, p.Size.Y, p.Size.Z)
			p.CFrame = pv * (cf.Rotation + (center + dir * mid))
			trimmed += 1
		end
	end
end
table.insert(report, string.format("fissures : %d raccourcies, %d supprimees", trimmed, removed))

-- ===== 2. tas resserre contre le mur =====
-- Pour chaque piece (de la plus grosse a la plus petite) : 6 places tirees pres du mur (0 a 12 studs, tres dense au
-- pied), on garde la plus basse (penalite legere pour l'eloignement) : le tas s'elargit avant de monter, sans tour.
local rng = Random.new(261143)
local loose: { BasePart } = {}
local fractured = m:FindFirstChild("WindowFractured")
for _, p in facade:GetChildren() do
	if p:IsA("BasePart") and (p.Name == "WallChunk" or p.Name == "FacadeSlab" or p.Name == "Frame_T" or p.Name == "Frame_L" or p.Name == "Frame_B") then
		table.insert(loose, p)
	end
end
if fractured then
	for _, s in fractured:GetChildren() do
		if s:IsA("BasePart") then
			table.insert(loose, s)
		end
	end
end
local CELL = 0.5
local heights: { [number]: number } = {}
local function key(ix: number, iz: number): number
	return ix * 100000 + iz
end
local function groundAt(z: number): number
	if z > WALL_FRONT then
		return 0.475
	elseif z > -61.5 then
		return 0.45
	end
	return 0
end
local function heightAt(x: number, z: number): number
	return math.max(groundAt(z), heights[key(math.floor(x / CELL), math.floor(z / CELL))] or -1)
end
local function lieFlat(p: BasePart): (Vector3, CFrame)
	local s = p.Size
	if s.X <= s.Y and s.X <= s.Z then
		return Vector3.new(s.Y, s.X, s.Z), CFrame.Angles(0, 0, math.rad(90))
	elseif s.Z <= s.X and s.Z <= s.Y then
		return Vector3.new(s.X, s.Z, s.Y), CFrame.Angles(math.rad(90), 0, 0)
	end
	return s, CFrame.new()
end
local function footprint(flat: Vector3, x: number, z: number, yaw: number): (number, { number }, number)
	local c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	local hx, hz = flat.X / 2, flat.Z / 2
	local ex = math.abs(c) * hx + math.abs(s) * hz
	local ez = math.abs(s) * hx + math.abs(c) * hz
	if x - ex < HOLE_X0 + 0.5 or x + ex > HOLE_X1 - 0.5 then
		z = math.min(z, WALL_FRONT - ez - 0.05) -- hors du trou : devant le mur, sans le traverser
	end
	local base, cells = 0, {}
	for gx = math.floor((x - ex) / CELL), math.floor((x + ex) / CELL) do
		for gz = math.floor((z - ez) / CELL), math.floor((z + ez) / CELL) do
			local cx, cz = (gx + 0.5) * CELL - x, (gz + 0.5) * CELL - z
			local lx, lz = c * cx - s * cz, s * cx + c * cz
			if math.abs(lx) <= hx and math.abs(lz) <= hz then
				base = math.max(base, heightAt((gx + 0.5) * CELL, (gz + 0.5) * CELL))
				table.insert(cells, key(gx, gz))
			end
		end
	end
	if #cells == 0 then
		base = heightAt(x, z)
	end
	return base, cells, z
end
table.sort(loose, function(a, b)
	return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
end)
local placed, maxTop = 0, 0
for _, p in loose do
	local isGlass = p.Parent == fractured
	if p.Name == "FacadeSlab" then
		p.CFrame = CFrame.new(L(-4, 0.45 + 2.7, WALL_FRONT - 1.6)) * pv.Rotation * CFrame.Angles(math.rad(62), math.rad(5), math.rad(4))
		for gx = math.floor(-10.5 / CELL), math.floor(2.5 / CELL) do
			for gz = math.floor((WALL_FRONT - 4.2) / CELL), math.floor(WALL_FRONT / CELL) do
				heights[key(gx, gz)] = 3.4
			end
		end
	else
		local flat, lieRot = lieFlat(p)
		local best: { score: number, x: number, z: number, yaw: number, base: number, cells: { number } }? = nil
		for _ = 1, 6 do
			local x = rng:NextNumber(HOLE_X0 + 1, HOLE_X1 - 1)
			local z = WALL_FRONT - 0.3 - (rng:NextNumber() ^ 2) * 12 + (if rng:NextNumber() < 0.12 then rng:NextNumber(1.5, 4) else 0)
			local yaw = rng:NextNumber(0, 360)
			local base, cells, z2 = footprint(flat, x, z, yaw)
			local score = base + (WALL_FRONT - z2) * 0.12
			if best == nil or score < best.score then
				best = { score = score, x = x, z = z2, yaw = yaw, base = base, cells = cells }
			end
		end
		local b = best :: { score: number, x: number, z: number, yaw: number, base: number, cells: { number } }
		local tilt = if isGlass then 3 else 12
		local rot = CFrame.Angles(0, math.rad(b.yaw), 0) * CFrame.Angles(math.rad(rng:NextNumber(-tilt, tilt)), 0, math.rad(rng:NextNumber(-tilt, tilt))) * lieRot
		local halfY = math.abs(rot.XVector.Y) * p.Size.X / 2 + math.abs(rot.YVector.Y) * p.Size.Y / 2 + math.abs(rot.ZVector.Y) * p.Size.Z / 2
		p.CFrame = CFrame.new(L(b.x, b.base + halfY - 0.03, b.z)) * pv.Rotation * rot
		local top = b.base + 2 * halfY - 0.05
		for _, k in b.cells do
			heights[k] = math.max(heights[k] or -1, top)
		end
		maxTop = math.max(maxTop, top)
		if isGlass then
			p.Transparency = 0.3
		end
	end
	placed += 1
end
table.insert(report, string.format("%d debris reposes contre le mur, sommet du tas a %.1f studs", placed, maxTop))

print("[chantier v4b] " .. table.concat(report, " ; "))
return table.concat(report, "\n")
