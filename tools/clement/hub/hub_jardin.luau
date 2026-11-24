-- Jardin du hub (Clément, 2026-11-24 : « Changes les murs, fais des murs de terres de différentes hauteur », « Oui, avec
-- les allées »). À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/hub/hub_place_du_mall.luau
-- (qui refait Map/Hub/Walls et effacerait les murs de terre). Relancer refait ce que ce script pose, à l'identique.
-- Ce qu'il fait :
--  1) murs de terre (Map/Hub/Walls/EarthWalls) : blocs de 10 à 18 de long, 20 à 38 de haut (pas de 6), damier de deux
--     bruns par rangs de 4, dessus d'herbe qui déborde, herbe qui pend, marches basses côté place ; 10 à 16 d'épaisseur
--     vers l'extérieur à l'ouest, au nord et au sud, 2,5 seulement à l'est (contre la zone 1). Terre, dessus et marches
--     pleins : ce sont les limites du hub. _G.ClaudeWallTops garde le milieu du dessus de chaque bloc (arbres, buissons) ;
--  2) jardin (Map/Hub/Garden/{Paths, Beds}) : anneau d'allée devant les 6 portes (rayon 91, pavés de sable deux tons
--     sans trou entre eux, coins comblés par des triangles), une allée vers chaque porte, la grande allée depuis la
--     sortie, la place ronde à l'arrivée ; massifs surélevés entre les boutiques, terrasses à deux niveaux dans les
--     coins, talus le long des murs, quatre massifs ronds sur la place. Allées et bordures en décor (ni collision ni
--     requête) ; massifs, terrasses et talus pleins (on monte dessus) ;
--  3) vérifie qu'aucune pièce pleine du jardin n'entre dans une boutique, un stand ou une zone.
-- Gabarit : éventail de hub_place_du_mall.luau (centre x -45, façades à 125, angles 90, 54, 18, -18, -54, -90), intérieur
-- du hub x -276..27,5, |z| <= 232. Aucun script dans la map. Déco voxel (buissons, fleurs, chênes, rochers) : plus tard.
local rgb = Color3.fromRGB
local hub = workspace.Map.Hub
local X0, X1, Z1 = -276, 27.5, 232
local CEN = Vector3.new(-45, 0, 0)
local R = 125
local FAN_A = { 90, 54, 18, -18, -54, -90 }
-- Clément, 2026-11-24 (« retire les allées et les ronds de terre au sol, c'est pas beau ») : allées et massifs ronds de la
-- place plus posés (true les remet). La déco voxel se pose ensuite avec hub_jardin_deco.luau.
local PATHS, ROUND_BEDS = false, false
local out = {}

-- 1) Murs de terre ---------------------------------------------------------------------------------------------------
do
	local W = hub.Walls
	local rng = Random.new(2314)
	local old = W:FindFirstChild("EarthWalls"); if old then old:Destroy() end
	local m = Instance.new("Model"); m.Name = "EarthWalls"; m.Parent = W
	local n = 0
	local function B(name, x0, y0, z0, x1, y1, z1, color, solid)
		local p = Instance.new("Part"); p.Name = name; p.Anchored = true
		p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		p.Color = color; p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = solid; p.CanTouch = false; p.CanQuery = solid
		p.Parent = m; n += 1
		return p
	end
	-- côté, origine, sens de la longueur, sens de l'épaisseur (vers l'extérieur = négatif), longueur, marches, épaisseur max
	local SIDES = {
		{ "W", Vector3.new(X0, 0, -Z1 - 16), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), 2 * Z1 + 32, true, 16 },
		{ "N", Vector3.new(X0, 0, Z1), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), 30 - X0, true, 16 },
		{ "S", Vector3.new(X0, 0, -Z1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), 30 - X0, true, 16 },
		{ "EN", Vector3.new(X1, 0, 64.5), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Z1 - 64.5, false, 2.5 },
		{ "ES", Vector3.new(X1, 0, -Z1), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Z1 - 64.5, false, 2.5 },
	}
	local function Wp(sd, name, s0, s1, d0, d1, y0, y1, color, solid)
		local a = sd[2] + sd[3] * s0 + sd[4] * d0
		local b = sd[2] + sd[3] * s1 + sd[4] * d1
		return B(sd[1] .. "_" .. name, math.min(a.X, b.X), y0, math.min(a.Z, b.Z), math.max(a.X, b.X), y1, math.max(a.Z, b.Z), color, solid)
	end
	local BROWN_A, BROWN_B, BROWN_C = rgb(150, 104, 66), rgb(132, 90, 56), rgb(168, 120, 78)
	local TOP, TOP_D = rgb(124, 200, 98), rgb(106, 186, 88)
	local mods = 0
	local tops = {}
	for _, sd in SIDES do
		local s, h = 0, 26
		while s < sd[5] - 0.5 do
			local L = math.min(rng:NextNumber(10, 18), sd[5] - s)
			if sd[5] - s - L < 6 then L = sd[5] - s end
			h = math.clamp(h + rng:NextInteger(-1, 1) * 6, 20, 38)
			local depth = sd[7] == 16 and rng:NextNumber(10, 16) or sd[7]
			mods += 1
			local row, y = 0, 0
			while y < h - 0.01 do
				local y1 = math.min(y + 4, h)
				local col = ((mods + row) % 2 == 0) and BROWN_A or BROWN_B
				if rng:NextNumber() < 0.08 then col = BROWN_C end
				Wp(sd, "Earth", s, s + L, -depth, 0, y, y1, col, true)
				y = y1; row += 1
			end
			Wp(sd, "EarthTop", s - 0.3, s + L + 0.3, -depth - 0.3, 0.8, h, h + 1.2, TOP, true)
			if rng:NextNumber() < 0.5 then
				local a = rng:NextNumber(0.5, L * 0.5)
				Wp(sd, "EarthTop2", s + a, s + math.min(L - 0.5, a + rng:NextNumber(3, 6)), -depth * 0.7, -1, h + 1.2, h + 1.8, TOP_D, true)
			end
			for _ = 1, rng:NextInteger(1, 3) do
				local a = rng:NextNumber(0, L - 2)
				Wp(sd, "GrassDrip", s + a, s + a + rng:NextNumber(1.2, 2.5), 0, 0.6, h - rng:NextNumber(1, 3.5), h, TOP, false)
			end
			if sd[6] and rng:NextNumber() < 0.4 then
				local lh = rng:NextNumber(2.5, 4)
				Wp(sd, "Ledge", s + 1, s + L - 1, 0, 4, 0, lh, BROWN_B, true)
				Wp(sd, "LedgeTop", s + 0.7, s + L - 0.7, 0, 4.5, lh, lh + 0.6, TOP, true)
			end
			local top = sd[2] + sd[3] * (s + L / 2) + sd[4] * (-depth / 2)
			table.insert(tops, { x = top.X, z = top.Z, y = h + 1.2, side = sd[1] })
			s += L
			if mods % 10 == 0 then task.wait() end
		end
	end
	m:SetAttribute("TopSpots", #tops)
	_G.ClaudeWallTops = tops
	table.insert(out, string.format("murs de terre : %d blocs, %d pièces (W, N, S épais ; EN, ES minces contre la zone 1)", mods, n))
end

-- 2) Jardin -----------------------------------------------------------------------------------------------------------
local RR, HW = R - 34, 5 -- rayon et demi-largeur de l'anneau
local old = hub:FindFirstChild("Garden"); if old then old:Destroy() end
local garden = Instance.new("Model"); garden.Name = "Garden"; garden.Parent = hub
local function sub(name) local m = Instance.new("Model"); m.Name = name; m.Parent = garden; return m end
local paths, beds = sub("Paths"), sub("Beds")
local n = 0
local function part(parent, name, cf, size, color, solid, shape)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CFrame = cf; p.Size = size; p.Color = color
	p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	if shape then p.Shape = shape end
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solid; p.CanTouch = false; p.CanQuery = solid; p.CastShadow = solid
	p.Parent = parent; n += 1
	return p
end
local function B(parent, name, x0, y0, z0, x1, y1, z1, color, solid)
	return part(parent, name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, solid)
end
local function OB(parent, name, x, z, dir, w, y0, y1, l, color, solid)
	local c = Vector3.new(x, (y0 + y1) / 2, z)
	return part(parent, name, CFrame.lookAt(c, c + dir), Vector3.new(w, y1 - y0, l), color, solid)
end
local function cyl(parent, name, x, z, r, y0, y1, color, solid)
	return part(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, 2 * r, 2 * r), color, solid, Enum.PartType.Cylinder)
end
-- triangle plein à plat (sommets A, B, C au sol en x, z), de y0 à y1 : deux WedgeParts
local function flatTri(parent, name, A, Bv, Cv, y0, y1, color)
	local thick = y1 - y0
	local a, b, c = Vector3.new(A.X, (y0 + y1) / 2, A.Z), Vector3.new(Bv.X, (y0 + y1) / 2, Bv.Z), Vector3.new(Cv.X, (y0 + y1) / 2, Cv.Z)
	local bc = c - b
	local M = b + bc * ((a - b):Dot(bc) / bc:Dot(bc))
	for _, Ept in { b, c } do
		local s, h = (Ept - M).Magnitude, (a - M).Magnitude
		if s > 0.01 and h > 0.01 then
			local zAx, yAx = (M - a).Unit, (Ept - M).Unit
			local w = Instance.new("WedgePart"); w.Name = name; w.Anchored = true
			w.Size = Vector3.new(thick, s, h)
			w.CFrame = CFrame.fromMatrix((a + Ept) / 2, yAx:Cross(zAx), yAx, zAx)
			w.Color = color; w.Material = Enum.Material.Plastic; w.MaterialVariant = "Studs"
			w.CanCollide = false; w.CanTouch = false; w.CanQuery = false; w.CastShadow = false
			w.Parent = parent; n += 1
		end
	end
end
local GTOP = rgb(124, 200, 98)
local DIRT, DIRT_D = rgb(150, 104, 66), rgb(126, 86, 54)
local SAND_A, SAND_B, KERB = rgb(234, 204, 156), rgb(218, 184, 134), rgb(176, 180, 188)
local PY, KY = 0.35, 0.5 -- dessus des pavés, dessus des bordures
local function near(deg, list, tol) for _, a in list do if math.abs(deg - a) < tol then return true end end return false end

local nFill = 0
if PATHS then
-- 2a) anneau : pavés trapézoïdaux approchés par des rectangles qui se touchent sur le bord intérieur, coins comblés
local STEP = 5
local segs = {}
for a = -105, 100, STEP do
	local am = math.rad(a + STEP / 2)
	local dir = Vector3.new(-math.cos(am), 0, math.sin(am))
	local tan = Vector3.new(math.sin(am), 0, math.cos(am))
	local h = (RR - HW) * math.tan(math.rad(STEP / 2))
	local c = CEN + dir * RR
	local col = ((a / STEP) % 2 == 0) and SAND_A or SAND_B
	OB(paths, "Path", c.X, c.Z, tan, 2 * HW, -0.05, PY, 2 * h, col, false)
	table.insert(segs, { c = c, dir = dir, tan = tan, h = h, col = col, a = a })
	-- bordures : pas devant les allées des portes (dehors) ni devant la grande allée (dedans)
	for _, sgn in { -1, 1 } do
		local r = RR + sgn * (HW + 0.4)
		local mid = a + STEP / 2
		local skip = (sgn > 0 and near(mid, FAN_A, 3.5)) or (sgn < 0 and math.abs(mid) < 4.5)
		if not skip then
			local e = CEN + dir * r
			OB(paths, "Kerb", e.X, e.Z, tan, 0.8, -0.05, KY, 2 * r * math.tan(math.rad(STEP / 2)) + 0.15, KERB, false)
		end
	end
end
for i = 1, #segs - 1 do
	local s1, s2 = segs[i], segs[i + 1]
	local P = s1.c + s1.tan * s1.h - s1.dir * HW -- coin intérieur commun
	local A = s1.c + s1.tan * s1.h + s1.dir * HW -- coin extérieur de fin du pavé i
	local Bp = s2.c - s2.tan * s2.h + s2.dir * HW -- coin extérieur de début du pavé i + 1
	flatTri(paths, "PathFill", P, A, Bp, -0.05, PY, s1.col)
	nFill += 1
end
-- 2b) allées vers les portes
local spurL = R - (RR + HW)
for _, deg in FAN_A do
	local a = math.rad(deg)
	local dir = Vector3.new(-math.cos(a), 0, math.sin(a))
	local side = Vector3.new(dir.Z, 0, -dir.X)
	local nSeg = math.max(1, math.round(spurL / 4.4))
	for k = 0, nSeg - 1 do
		local c = CEN + dir * (RR + HW + (k + 0.5) * spurL / nSeg)
		OB(paths, "Path", c.X, c.Z, dir, 8, -0.05, PY, spurL / nSeg + 0.02, (k % 2 == 0) and SAND_B or SAND_A, false)
	end
	for _, s in { -1, 1 } do
		local c = CEN + dir * (RR + HW + spurL / 2) + side * s * 4.4
		OB(paths, "Kerb", c.X, c.Z, dir, 0.8, -0.05, KY, spurL, KERB, false)
	end
end
-- 2c) grande allée depuis la sortie et place ronde à l'arrivée
local wx0 = CEN.X - (RR - HW)
local nW = math.round(-wx0 / 6)
for k = 0, nW - 1 do
	local x0 = wx0 + k * (-wx0 / nW)
	for j = 0, 1 do B(paths, "Path", x0, -0.05, -6 + j * 6, x0 + (-wx0 / nW) + 0.02, PY, j * 6, ((k + j) % 2 == 0) and SAND_A or SAND_B, false) end
end
B(paths, "Kerb", wx0, -0.05, 6, 0, KY, 6.8, KERB, false)
B(paths, "Kerb", wx0, -0.05, -6.8, 0, KY, -6, KERB, false)
cyl(paths, "Plaza_Kerb", -7, 0, 18, -0.05, KY, KERB, false)
cyl(paths, "Plaza", -7, 0, 17.2, 0, 0.6, SAND_A, false)
cyl(paths, "Plaza_In", -7, 0, 10, 0, 0.64, SAND_B, false)
task.wait()
else
	paths:Destroy()
end

-- 2d) massifs, terrasses, talus, massifs ronds (pleins : on monte dessus)
local function bed(x, z, dir, w, l, h)
	OB(beds, "BedDirt", x, z, dir, w, -0.05, h, l, DIRT, true)
	OB(beds, "BedDirtBand", x, z, dir, w + 0.1, h * 0.35, h * 0.45, l + 0.1, DIRT_D, false)
	OB(beds, "BedTop", x, z, dir, w + 0.6, h, h + 0.5, l + 0.6, GTOP, true)
end
for _, deg in { 72, 36, 0, -36, -72 } do -- entre deux boutiques, derrière l'anneau
	local a = math.rad(deg)
	local dir = Vector3.new(-math.cos(a), 0, math.sin(a))
	local c = CEN + dir * (R + 65)
	bed(c.X, c.Z, dir, 22, 40, 1.8)
end
local function slab(a0, b0, a1, b1, y0, y1)
	B(beds, "TerraceDirt", a0, -0.05, b0, a1, y1, b1, DIRT, true)
	B(beds, "TerraceBand", a0 - 0.05, y0 + (y1 - y0) * 0.35, b0 - 0.05, a1 + 0.05, y0 + (y1 - y0) * 0.45, b1 + 0.05, DIRT_D, false)
	B(beds, "TerraceTop", a0 - 0.3, y1, b0 - 0.3, a1 + 0.3, y1 + 0.5, b1 + 0.3, GTOP, true)
end
local function terrace(x0, z0, x1, z1, x2, z2, x3, z3) slab(x0, z0, x1, z1, 0, 2.2); slab(x2, z2, x3, z3, 2.2, 4.4) end
terrace(X0, 168, -204, Z1, X0, 198, -236, Z1)
terrace(X0, -Z1, -204, -168, X0, -Z1, -236, -198)
terrace(-12, 206, 22, Z1, 2, 216, 22, Z1)
terrace(-12, -Z1, 22, -206, 2, -Z1, 22, -216)
local function berm(x0, z0, x1, z1)
	B(beds, "BermDirt", x0, -0.05, z0, x1, 2.4, z1, DIRT, true)
	B(beds, "BermTop", x0 - 0.3, 2.4, z0 - 0.3, x1 + 0.3, 2.9, z1 + 0.3, GTOP, true)
end
berm(X0, -168, X0 + 11, 168)
berm(-204, Z1 - 11, -16, Z1)
berm(-204, -Z1, -16, -Z1 + 11)
if ROUND_BEDS then
	for _, c in { { -62, 40 }, { -62, -40 }, { -102, 46 }, { -102, -46 } } do
		cyl(beds, "RoundBedRim", c[1], c[2], 10.6, -0.05, 1.1, DIRT, true)
		cyl(beds, "RoundBed", c[1], c[2], 10, 0, 1.3, GTOP, true)
	end
end
table.insert(out, string.format("jardin : %d pièces (%s5 massifs, 4 terrasses, 3 talus%s)", n,
	PATHS and string.format("anneau avec %d coins comblés, 6 allées de porte, grande allée, place ronde, ", nFill) or "",
	ROUND_BEDS and ", 4 massifs ronds" or ""))

-- 3) rien de plein du jardin dans l'emprise d'une boutique, d'un stand ou d'une zone
local hits = {}
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Include; op.FilterDescendantsInstances = { beds }
for _, grp in { hub.Shops, hub.Stalls, hub.Zones } do
	for _, mdl in grp:GetChildren() do
		if mdl:IsA("Model") then
			local cf, s = mdl:GetBoundingBox()
			local k = #workspace:GetPartBoundsInBox(cf, s, op)
			if k > 0 then table.insert(hits, mdl.Name .. " (" .. k .. ")") end
		end
	end
end
table.insert(out, "massifs dans une boutique, un stand ou une zone : " .. (#hits > 0 and table.concat(hits, ", ") or "aucun"))
return table.concat(out, "\n")
