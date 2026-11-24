-- Jardin du hub, déco voxel (Clément, 2026-11-24 : « tu peux joindre les modèles faits par Claude Design », « j'aimais bien
-- le rendu voxel » ; puis « ne mets rien devant les boutiques », « les arbres, tu les retires, ça gêne le passage », « faut
-- plus remplir l'arrière des boutiques, le coin »). À lancer dans Studio (MCP execute_luau, mode Edit) après
-- hub_jardin.luau et garden_voxel_build.luau : pose les modèles de ServerStorage/Assets/Env/Garden dans
-- Map/Hub/Garden/Decor, refait à l'identique à chaque lancement (graine fixe).
--  - Devant les boutiques (la place, jusqu'à la sortie) : seulement 3 touffes de pâquerettes, sans collision (Front) ;
--  - massifs entre les boutiques (Beds), terrasses des coins avec une statue trophée, un banc et un lampadaire (Terraces),
--    talus (Berms), haut des murs de terre (WallTops) ;
--  - derrière les boutiques et dans les coins : bosquets serrés, arbres compris (Back).
-- Rien dans une boutique (à sa taille maximale), un stand ou une zone. Aucun script ; les modèles qui bougent au vent
-- gardent le tag WindSway (L-322).
local CS = game:GetService("CollectionService")
local hub = workspace.Map.Hub
local SRC = game.ServerStorage.Assets.Env.Garden
local rng = Random.new(2411)
local CEN, R = Vector3.new(-45, 0, 0), 125
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
-- devant les boutiques : l'intérieur de l'éventail (façades à 125 du centre) et tout l'est du hub jusqu'à la sortie
local function inFront(x, z, r)
	local d = Vector3.new(x - CEN.X, 0, z - CEN.Z).Magnitude
	return d < R + 5 + r or (x > CEN.X - 5 - r and math.abs(z) < R + 5 + r)
end
-- reliefs du jardin (massifs, terrasses, talus) : les bosquets les évitent
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
-- check : "back" (pelouse derrière les boutiques : pas devant, pas sur un relief), "raised" (sur un relief), "front"
-- (pâquerettes de la place), "none"
local function put(category, name, x, z, yaw, scale, check, y)
	local r = radiusOf(name, scale)
	if check ~= "none" then
		if inBoxes(x, z, r) or not inHub(x, z, 0) then skipped += 1; return nil end
		if check == "back" and (inFront(x, z, r) or onRaised(x, z, r + 0.5)) then skipped += 1; return nil end
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
-- 2b) terraces des coins (NO, SO : grandes, avec statue, banc et lampadaire ; NE, SE : petites, contre la sortie)
for _, s in { 1, -1 } do
	local function P(n, x, z, sc, yaw, chk) put("Terraces", n, x + J(0.5), s * z + J(0.5), yaw, sc, chk or "raised") end
	P("ENV_Nature_Tree_Oak", -262, 214, 1.25); P("ENV_Nature_Tree_Oak", -246, 225, 1.1)
	P("ENV_Nature_Bush_Cone", -270, 202, 1.1); P("ENV_Nature_Bush_Round", -242, 205, 1.2)
	P("ENV_Nature_Rock_Boulder", -222, 216, 1.15); P("ENV_Nature_Rock_Cluster", -258, 178, 1)
	P("ENV_Prop_Planter_Marble", -214, 178, 1, 0)
	P("ENV_Nature_Bush_Flower", -230, 188, 1.1); P("ENV_Nature_Bush_Berry", -268, 186, 1.1)
	P("ENV_Nature_Bush_TallGrass", -210, 227, 1.1); P("ENV_Nature_Flower_Sunflower", -232, 206, 1)
	P("ENV_Nature_Flower_Tulip", -246, 176, 1); P("ENV_Nature_Flower_Daisy", -226, 174, 1)
	P("ENV_Prop_Statue_Trophy", -224, 200, 1.1, yawFacing(-224, s * 200, CEN.X, CEN.Z))
	P("ENV_Prop_LampPost", -212, 204, 1, 0)
	P("ENV_Prop_Bench", -214, 192, 1, yawFacing(-214, s * 192, CEN.X, CEN.Z))
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
-- 2e) devant les boutiques : seulement 3 touffes de pâquerettes (sans collision, elles ne gênent pas le passage)
for _, p in { { -11, 57 }, { -11, -57 }, { -74, 0 } } do put("Front", "ENV_Nature_Flower_Daisy", p[1], p[2], nil, 1.3, "front") end
-- 2f) derrière les boutiques et dans les coins : bosquets serrés
local THEMES = {
	{ "ENV_Nature_Tree_Oak", "ENV_Nature_Bush_Round", "ENV_Nature_Bush_Berry", "ENV_Nature_Mushroom" },
	{ "ENV_Nature_Tree_Oak", "ENV_Nature_Bush_Cone", "ENV_Nature_Bush_Flower", "ENV_Nature_Flower_Daisy" },
	{ "ENV_Nature_Rock_Boulder", "ENV_Nature_Rock_Cluster", "ENV_Nature_Bush_TallGrass", "ENV_Nature_Mushroom_Cluster" },
	{ "ENV_Nature_Bush_Cone", "ENV_Nature_Bush_Cone", "ENV_Nature_Bush_Round", "ENV_Nature_Flower_Tulip" },
	{ "ENV_Nature_Tree_Oak", "ENV_Nature_Bush_Berry", "ENV_Nature_Rock_Cluster", "ENV_Nature_Flower_Daisy" },
	{ "ENV_Nature_Bush_Hedge", "ENV_Nature_Bush_Round", "ENV_Nature_Flower_Tulip", "ENV_Nature_Flower_Daisy" },
}
local centers, tries = {}, 0
while #centers < 60 and tries < 8000 do
	tries += 1
	local x, z = rng:NextNumber(X0 + 8, 18), rng:NextNumber(-Z1 + 8, Z1 - 8)
	-- au-delà de 140 du centre : le passage entre deux boutiques, près des façades, reste dégagé
	local ok = not inFront(x, z, 3) and (Vector3.new(x, 0, z) - CEN).Magnitude > 140 and not inBoxes(x, z, 3)
		and not onRaised(x, z, 3) and inHub(x, z, 2) and free(x, z, 5)
	if ok then for _, c in centers do if (c.X - x) ^ 2 + (c.Z - z) ^ 2 < 15 ^ 2 then ok = false; break end end end
	if ok then table.insert(centers, Vector3.new(x, 0, z)) end
end
for k, c in centers do
	local theme = THEMES[(k - 1) % #THEMES + 1]
	for j, n in theme do
		local a, d = rng:NextNumber(0, 2 * math.pi), (j == 1) and 0 or rng:NextNumber(3.5, 6.5)
		local s = (n:match("Rock") and rng:NextNumber(0.8, 1.3)) or (n:match("Oak") and rng:NextNumber(1.05, 1.3)) or rng:NextNumber(1, 1.3)
		put("Back", n, c.X + math.cos(a) * d, c.Z + math.sin(a) * d, nil, s, "back")
	end
end
decor.Parent = hub.Garden

-- 3) bilan
local per = {}
for n, c in cats do per[#per + 1] = n .. " " .. #c:GetChildren() end
table.sort(per)
local nTag = 0
for _, m in CS:GetTagged("WindSway") do if m:IsDescendantOf(decor) then nTag += 1 end end
return string.format("déco : %d modèles (%s), %d pièces ; %d places refusées (devant les boutiques, boutique, zone ou trop près) ; %d bosquets derrière ; WindSway dans la déco : %d",
	#placed, table.concat(per, ", "), nParts, skipped, #centers, nTag)
