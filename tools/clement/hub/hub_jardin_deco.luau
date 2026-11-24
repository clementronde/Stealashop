-- Jardin du hub, déco voxel (Clément, 2026-11-24 : « tu peux joindre les modèles faits par Claude Design », « j'aimais bien
-- le rendu voxel »). À lancer dans Studio (MCP execute_luau, mode Edit) après hub_jardin.luau et garden_voxel_build.luau :
-- pose les modèles de ServerStorage/Assets/Env/Garden dans Map/Hub/Garden/Decor, refait à l'identique à chaque lancement
-- (graine fixe). Massifs (Beds), terrasses des coins (Terraces), talus (Berms), haut des murs de terre (WallTops), statue
-- au milieu de la place (Centre), coins repos entre les portes : lampadaire, banc, jardinière (Rest), îlots plantés aux
-- endroits les plus dégagés de la place (Islands), bosquets sur le reste de la pelouse (Lawn). Passages libres : arrivée,
-- sortie, chemins vers les 6 portes et les 4 stands, anneau devant les portes ; rien dans une boutique (à sa taille
-- maximale), un stand ou une zone. Aucun script ; les modèles qui bougent au vent gardent le tag WindSway (L-321).
local CS = game:GetService("CollectionService")
local hub = workspace.Map.Hub
local SRC = game.ServerStorage.Assets.Env.Garden
local rng = Random.new(2411)
local CEN, R = Vector3.new(-45, 0, 0), 125
local FAN_A = { 90, 54, 18, -18, -54, -90 }
local X0, Z1 = -276, 232
local SPAWN = Vector3.new(-7, 0, 0)
local function dirOf(deg) local a = math.rad(deg); return Vector3.new(-math.cos(a), 0, math.sin(a)) end

local old = hub.Garden:FindFirstChild("Decor"); if old then old:Destroy() end
local decor = Instance.new("Model"); decor.Name = "Decor"
local cats = {}
local function cat(n) local c = cats[n]; if not c then c = Instance.new("Model"); c.Name = n; c.Parent = decor; cats[n] = c end return c end

-- 1) zones interdites --------------------------------------------------------------------------------------------
local boxes = {} -- { cf, hx, hz }
local function addBox(cf, hx, hz) table.insert(boxes, { cf = cf, hx = hx, hz = hz }) end
for _, sh in hub.Shops:GetChildren() do
	if sh:IsA("Model") and sh:GetAttribute("PlotIndex") then
		local pv = sh:GetPivot()
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in sh:GetDescendants() do
			if p:IsA("BasePart") then
				local l = pv:ToObjectSpace(p.CFrame)
				local hs = p.Size / 2
				for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
					local c = l * Vector3.new(sx * hs.X, 0, sz * hs.Z)
					x0 = math.min(x0, c.X); x1 = math.max(x1, c.X); z0 = math.min(z0, c.Z); z1 = math.max(z1, c.Z)
				end end
			end
		end
		x0 = math.min(x0, -32); x1 = math.max(x1, 32); z0 = math.min(z0, -40); z1 = math.max(z1, 40) -- Bounds (taille max)
		addBox(pv * CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2), (x1 - x0) / 2 + 3, (z1 - z0) / 2 + 3)
	end
end
for _, grp in { hub.Stalls, hub.Zones } do
	for _, m in grp:GetChildren() do
		if m:IsA("Model") then local cf, s = m:GetBoundingBox(); addBox(cf, s.X / 2 + 4, s.Z / 2 + 4) end
	end
end
addBox(CFrame.new(SPAWN), 13, 13) -- arrivée
addBox(CFrame.new(15, 0, 0), 15.5, 68) -- sortie vers la zone 1
local function inBoxes(x, z, r)
	for _, b in boxes do
		local l = b.cf:PointToObjectSpace(Vector3.new(x, b.cf.Y, z))
		if math.abs(l.X) <= b.hx + r and math.abs(l.Z) <= b.hz + r then return true end
	end
	return false
end
-- couloirs : arrivée -> devant chaque porte, arrivée -> chaque stand
local segs = {}
for _, deg in FAN_A do table.insert(segs, { SPAWN, CEN + dirOf(deg) * 100, 7 }) end
for _, m in hub.Stalls:GetChildren() do if m:IsA("Model") then table.insert(segs, { SPAWN, m:GetPivot().Position, 6 }) end end
local function segDist(p, a, b)
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
	return (ap - ab * t).Magnitude
end
local function inCorridor(x, z, r)
	local p = Vector3.new(x, 0, z)
	for _, s in segs do if segDist(p, s[1], s[2]) < s[3] + r then return true end end
	local d = p - CEN
	local rad = Vector3.new(d.X, 0, d.Z).Magnitude
	local ang = math.deg(math.atan2(d.Z, -d.X))
	if rad > 80 - r and rad < 102 + r and math.abs(ang) < 100 then return true end -- anneau devant les portes
	return false
end
-- reliefs du jardin (massifs, terrasses, talus) : la pelouse les évite
local raised = {}
for _, p in hub.Garden.Beds:GetChildren() do
	if p:IsA("BasePart") and (p.Name == "BedTop" or p.Name == "TerraceTop" or p.Name == "BermTop") then
		table.insert(raised, { cf = p.CFrame, hx = p.Size.X / 2, hz = p.Size.Z / 2 })
	end
end
local function onRaised(x, z, r)
	for _, b in raised do
		local l = b.cf:PointToObjectSpace(Vector3.new(x, b.cf.Y, z))
		if math.abs(l.X) <= b.hx + r and math.abs(l.Z) <= b.hz + r then return true end
	end
	return false
end
local function inHub(x, z, r) return x > X0 + 4 + r and x < 22 - r and math.abs(z) < Z1 - 4 - r end

-- 2) pose ---------------------------------------------------------------------------------------------------------
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { hub.Ground, hub.Garden.Beds, hub.Walls }
local function groundY(x, z)
	local h = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -100, 0), rp)
	return h and h.Position.Y or 0
end
local placed, skipped, nParts = {}, 0, 0
local RADIUS = { ENV_Nature_Tree_Oak = 1.6, ENV_Nature_Rock_Boulder = 3.2, ENV_Nature_Rock_Cluster = 2.8, ENV_Prop_Bench = 2.6,
	ENV_Prop_Planter_Marble = 2.3, ENV_Prop_Statue_Trophy = 2.2, ENV_Prop_LampPost = 1, ENV_Nature_Bush_Hedge = 1.5 }
local function radiusOf(n, s) return (RADIUS[n] or 1.4) * (s or 1) end
local function free(x, z, r)
	for _, q in placed do if (q.x - x) ^ 2 + (q.z - z) ^ 2 < (q.r + r) ^ 2 then return false end end
	return true
end
-- check : "lawn" (pelouse : tout), "raised" (sur un relief : boutiques, stands, zones), "none"
local function put(category, name, x, z, yaw, scale, check, y)
	local r = radiusOf(name, scale)
	if check ~= "none" then
		if inBoxes(x, z, r) or not inHub(x, z, 0) then skipped += 1; return nil end
		if check == "lawn" and (inCorridor(x, z, r) or onRaised(x, z, r + 0.5)) then skipped += 1; return nil end
		if not free(x, z, r * 0.8) then skipped += 1; return nil end
	end
	local m = SRC[name]:Clone()
	if scale and math.abs(scale - 1) > 0.01 then m:ScaleTo(scale) end
	m:PivotTo(CFrame.new(x, y or groundY(x, z), z) * CFrame.Angles(0, yaw or rng:NextNumber(0, 2 * math.pi), 0))
	m.Parent = cat(category)
	table.insert(placed, { x = x, z = z, r = r })
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then nParts += 1 end end
	return m
end
local function yawFacing(x, z, tx, tz) return math.atan2(-(tx - x), -(tz - z)) end -- avant (-Z) vers (tx, tz)
local function J(a) return rng:NextNumber(-a, a) end

-- 2a) massifs entre les boutiques
for _, deg in { 72, 36, 0, -36, -72 } do
	local dir = dirOf(deg)
	local c = CEN + dir * (R + 65)
	local cf = CFrame.lookAt(c, c + dir)
	local function at(u, v) local p = cf * Vector3.new(u, 0, -v); return p.X, p.Z end -- v > 0 : vers le fond (le mur)
	local toC = math.atan2(dir.X, dir.Z) -- avant tourné vers la place
	local function P(n, u, v, s, yaw) local x, z = at(u + J(0.6), v + J(0.6)); put("Beds", n, x, z, yaw or (toC + J(0.5)), s, "raised") end
	P("ENV_Nature_Tree_Oak", 0, 8, 1.15 + J(0.1))
	P("ENV_Nature_Bush_Cone", -7.5, 14, 1); P("ENV_Nature_Bush_Cone", 7.5, 14, 1)
	P("ENV_Nature_Bush_Round", -6.5, 1, 1.1); P("ENV_Nature_Bush_Flower", 6.5, 0, 1.05); P("ENV_Nature_Bush_Berry", 0, -5, 1.1)
	P("ENV_Nature_Flower_Sunflower", -9, 7, 1); P("ENV_Nature_Flower_Sunflower", 9, 6, 1)
	P("ENV_Nature_Bush_TallGrass", -8.5, -8, 1); P("ENV_Nature_Bush_TallGrass", 8.5, -9, 1)
	local fl = { "ENV_Nature_Flower_Tulip", "ENV_Nature_Flower_Daisy", "ENV_Nature_Flower_Tulip", "ENV_Nature_Flower_Daisy" }
	for i, u in { -7, -2.5, 2.5, 7 } do P(fl[i], u, -15.5, 1) end
	P("ENV_Nature_Mushroom", 3.5, 4.5, 0.9)
end
-- 2b) terrasses des coins (NO, SO : grandes ; NE, SE : petites, contre la sortie)
for _, s in { 1, -1 } do
	local function P(n, x, z, sc, yaw, chk) put("Terraces", n, x + J(0.5), s * z + J(0.5), yaw, sc, chk or "raised") end
	P("ENV_Nature_Tree_Oak", -262, 214, 1.25); P("ENV_Nature_Tree_Oak", -246, 225, 1.1)
	P("ENV_Nature_Bush_Cone", -270, 202, 1.1); P("ENV_Nature_Bush_Round", -242, 205, 1.2)
	P("ENV_Nature_Rock_Boulder", -222, 216, 1.15); P("ENV_Nature_Rock_Cluster", -258, 178, 1)
	P("ENV_Prop_Planter_Marble", -214, 178, 1, 0)
	P("ENV_Nature_Bush_Flower", -230, 188, 1.1); P("ENV_Nature_Bush_Berry", -268, 186, 1.1)
	P("ENV_Nature_Bush_TallGrass", -210, 227, 1.1); P("ENV_Nature_Flower_Sunflower", -232, 206, 1)
	P("ENV_Nature_Flower_Tulip", -246, 176, 1); P("ENV_Nature_Flower_Daisy", -226, 174, 1)
	-- clôtures au bord de la terrasse basse, ouvertes au milieu
	for z = 172, 228, 4.8 do if z < 194 or z > 206 then put("Terraces", "ENV_Prop_Fence", -205.2, s * (z + 2.4), math.pi / 2, 1, "raised") end end
	for x = -272, -208, 4.8 do if x < -246 or x > -236 then put("Terraces", "ENV_Prop_Fence", x + 2.4, s * 168.8, s > 0 and 0 or math.pi, 1, "raised") end end
	-- petite terrasse contre la sortie
	P("ENV_Nature_Tree_Oak", 12, 226, 1.05); P("ENV_Nature_Bush_Round", -6, 224, 1.1)
	P("ENV_Nature_Bush_Flower", -8, 212, 1); P("ENV_Nature_Rock_Cluster", 2, 210, 0.9)
end
-- 2c) talus le long des murs (ouest, nord, sud)
local pattern = { "ENV_Nature_Bush_Hedge", "ENV_Nature_Tree_Oak", "ENV_Nature_Bush_Hedge", "ENV_Nature_Bush_Cone", "ENV_Nature_Bush_Hedge", "ENV_Nature_Bush_TallGrass" }
local i = 0
for z = -160, 160, 14 do
	i += 1
	local n = pattern[(i - 1) % #pattern + 1]
	put("Berms", n, -270.5 + J(0.4), z + J(1), n == "ENV_Nature_Bush_Hedge" and math.pi / 2 or nil, n == "ENV_Nature_Tree_Oak" and 1.1 + J(0.15) or 1, "raised")
	if n == "ENV_Nature_Bush_TallGrass" then put("Berms", "ENV_Nature_Flower_Sunflower", -268, z + 4, nil, 1, "raised") end
end
for _, s in { 1, -1 } do
	i = 0
	for x = -196, -26, 14 do
		i += 1
		local n = pattern[(i + 2) % #pattern + 1]
		put("Berms", n, x + J(1), s * 226.5 + J(0.4), n == "ENV_Nature_Bush_Hedge" and 0 or nil, n == "ENV_Nature_Tree_Oak" and 1.1 + J(0.15) or 1, "raised")
		if n == "ENV_Nature_Bush_TallGrass" then put("Berms", "ENV_Nature_Flower_Daisy", x + 4, s * 224, nil, 1, "raised") end
	end
end
-- 2d) haut des murs de terre (ouest, nord, sud) : un chêne sur trois blocs, un buisson sur un autre
local tops = {}
for _, p in hub.Walls.EarthWalls:GetChildren() do
	local side = p.Name:match("^(%u+)_EarthTop$")
	if side == "W" or side == "N" or side == "S" then table.insert(tops, p) end
end
table.sort(tops, function(a, b) return (a.Position.X + a.Position.Z * 1000) < (b.Position.X + b.Position.Z * 1000) end)
for k, p in tops do
	local y = p.Position.Y + p.Size.Y / 2
	if k % 3 == 0 then put("WallTops", "ENV_Nature_Tree_Oak", p.Position.X, p.Position.Z, nil, 1.1 + J(0.2), "none", y)
	elseif k % 3 == 1 then put("WallTops", rng:NextNumber() < 0.5 and "ENV_Nature_Bush_Cone" or "ENV_Nature_Bush_Round", p.Position.X + J(2), p.Position.Z + J(2), nil, 1.3, "none", y) end
end
-- 2e) statue au milieu de la place, jardinières et fleurs autour
put("Centre", "ENV_Prop_Statue_Trophy", -92, 0, yawFacing(-92, 0, SPAWN.X, SPAWN.Z), 1.3, "lawn")
for _, o in { { 0, 9 }, { 0, -9 }, { -9, 0 }, { 9, 0 } } do put("Centre", "ENV_Prop_Planter_Marble", -92 + o[1], o[2], 0, 1, "lawn") end
for _, o in { { 6.5, 6.5 }, { 6.5, -6.5 }, { -6.5, 6.5 }, { -6.5, -6.5 } } do put("Centre", "ENV_Nature_Flower_Tulip", -92 + o[1], o[2], nil, 1, "lawn") end
-- 2f) coins repos entre les portes : lampadaire, banc tourné vers la place, jardinière
for _, deg in { 72, 36, 0, -36, -72 } do
	local dir = dirOf(deg)
	local tan = Vector3.new(dir.Z, 0, -dir.X)
	local p = CEN + dir * 74
	put("Rest", "ENV_Prop_LampPost", p.X, p.Z, 0, 1, "lawn")
	local b = p + tan * 5
	put("Rest", "ENV_Prop_Bench", b.X, b.Z, yawFacing(b.X, b.Z, CEN.X, CEN.Z), 1, "lawn")
	local q = p - tan * 5
	put("Rest", "ENV_Prop_Planter_Marble", q.X, q.Z, 0, 1, "lawn")
end
-- 2g) îlots plantés sur la place : aux points les plus dégagés entre les passages (chêne au milieu si la place le permet)
local function clearance(x, z)
	if not inHub(x, z, 0) then return 0 end
	for r = 15, 6, -1 do
		if not inBoxes(x, z, r) and not inCorridor(x, z, r) and not onRaised(x, z, r) then return r end
	end
	return 0
end
local cands = {}
for x = -200, 16, 3 do
	for z = -222, 222, 3 do
		local c = clearance(x, z)
		if c >= 7 and (Vector3.new(x, 0, z) - CEN).Magnitude < 125 then table.insert(cands, { x = x, z = z, c = c }) end
	end
end
table.sort(cands, function(a, b) if a.c ~= b.c then return a.c > b.c end return (a.x - SPAWN.X) ^ 2 + a.z ^ 2 < (b.x - SPAWN.X) ^ 2 + b.z ^ 2 end)
local islands = {}
for _, q in cands do
	local ok = free(q.x, q.z, q.c * 0.7) and (q.x + 92) ^ 2 + q.z ^ 2 > 30 ^ 2 -- la statue reste visible depuis l'arrivée
	if ok then for _, s in islands do if (s.x - q.x) ^ 2 + (s.z - q.z) ^ 2 < (s.c + q.c + 8) ^ 2 then ok = false; break end end end
	if ok then table.insert(islands, q) end
	if #islands >= 14 then break end
end
local RING = { "ENV_Nature_Bush_Round", "ENV_Nature_Bush_Flower", "ENV_Nature_Bush_Berry", "ENV_Nature_Bush_Cone" }
local FLOW = { "ENV_Nature_Flower_Tulip", "ENV_Nature_Flower_Daisy" }
for k, s in islands do
	local c = s.c - 1.5
	if c >= 8 then put("Islands", "ENV_Nature_Tree_Oak", s.x, s.z, nil, 1.2 + J(0.12), "lawn")
	else put("Islands", "ENV_Nature_Bush_Cone", s.x, s.z, nil, 1.45, "lawn") end
	local a0 = rng:NextNumber(0, 2 * math.pi)
	for j = 0, 2 do
		local a = a0 + j * 2 * math.pi / 3 + J(0.3)
		put("Islands", RING[(k + j) % #RING + 1], s.x + math.cos(a) * c * 0.5, s.z + math.sin(a) * c * 0.5, nil, 1.35 + J(0.1), "lawn")
	end
	for j = 0, 4 do
		local a = a0 + math.pi / 3 + j * 2 * math.pi / 5 + J(0.25)
		put("Islands", FLOW[(j % 2) + 1], s.x + math.cos(a) * c * 0.85, s.z + math.sin(a) * c * 0.85, nil, 1.15, "lawn")
	end
	local a = a0 + math.pi + J(0.4)
	put("Islands", (k % 3 == 0) and "ENV_Nature_Rock_Boulder" or "ENV_Nature_Rock_Cluster", s.x + math.cos(a) * c * 0.75, s.z + math.sin(a) * c * 0.75, nil, (k % 3 == 0) and 0.9 or 1.1, "lawn")
end
-- 2h) bosquets sur le reste de la pelouse (coins, bords)
local THEMES = {
	{ "ENV_Nature_Rock_Boulder", "ENV_Nature_Rock_Cluster", "ENV_Nature_Bush_TallGrass", "ENV_Nature_Mushroom" },
	{ "ENV_Nature_Bush_Round", "ENV_Nature_Flower_Tulip", "ENV_Nature_Flower_Daisy", "ENV_Nature_Flower_Tulip" },
	{ "ENV_Nature_Bush_Berry", "ENV_Nature_Bush_Flower", "ENV_Nature_Bush_TallGrass" },
	{ "ENV_Nature_Rock_Cluster", "ENV_Nature_Mushroom_Cluster", "ENV_Nature_Mushroom", "ENV_Nature_Bush_TallGrass" },
	{ "ENV_Nature_Tree_Oak", "ENV_Nature_Bush_Round", "ENV_Nature_Rock_Cluster" },
}
local centers, tries = {}, 0
while #centers < 18 and tries < 4000 do
	tries += 1
	local x, z = rng:NextNumber(X0 + 10, 16), rng:NextNumber(-Z1 + 10, Z1 - 10)
	local ok = not inBoxes(x, z, 4) and not inCorridor(x, z, 4) and not onRaised(x, z, 4) and free(x, z, 6)
	if ok then for _, c in centers do if (c.X - x) ^ 2 + (c.Z - z) ^ 2 < 20 ^ 2 then ok = false; break end end end
	if ok then table.insert(centers, Vector3.new(x, 0, z)) end
end
for k, c in centers do
	local theme = THEMES[(k - 1) % #THEMES + 1]
	for j, n in theme do
		local a, d = rng:NextNumber(0, 2 * math.pi), (j == 1) and 0 or rng:NextNumber(3.5, 6.5)
		local s = (n:match("Rock") and rng:NextNumber(0.8, 1.3)) or (n:match("Oak") and rng:NextNumber(0.95, 1.2)) or rng:NextNumber(0.9, 1.2)
		put("Lawn", n, c.X + math.cos(a) * d, c.Z + math.sin(a) * d, nil, s, "lawn")
	end
end
decor.Parent = hub.Garden

-- 3) bilan
local per = {}
for n, c in cats do per[#per + 1] = n .. " " .. #c:GetChildren() end
table.sort(per)
local nTag = #CS:GetTagged("WindSway")
return string.format("déco : %d modèles (%s), %d pièces ; %d places refusées (passage, boutique, zone ou trop près) ; %d îlots, %d bosquets ; WindSway taggés dans le jeu : %d",
	#placed, table.concat(per, ", "), nParts, skipped, #islands, #centers, nTag)
