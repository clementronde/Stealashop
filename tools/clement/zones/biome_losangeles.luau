--!nocheck
-- Biome Los Angeles au couchant, 2e zone (fiche du chef DA : da-fiche-z4-losangeles.md, planche
-- StealAShop-Art/Captures/2026-11-28_biomes/Z4.jpg ; même méthode que tools/clement/zones/biome_tokyo.luau).
-- Tout en pièces, dans Studio, en Edit. Ne touche jamais : STORE_Z4_* (façades, intérieurs, contrat), Greybox/…/ZoneGate_4,
-- NightPatrol_Z4_*, TruckSpawn, points de ronde. Couloir |z| < 46,5 : seulement du plat sans collision (lignes, seuil).
-- Relançable : recolorations absolues, dossier Street_LosAngeles/Biome refait ; les pièces rangées le sont une fois.
--   1. sol : chaussée #6a5a4f, trottoirs sable #e9c48a, bordures terracotta #d9733f, marquages #fff7e6, double ligne
--      jaune #ffd23f, bandes de sable au pied des boutiques, ligne de seuil orange à x = 368 (pas de marche de 0,4 :
--      même décision que Tokyo) ;
--   2. colline à 4 gradins de 124 studs (x 465 à 541, z −188 à −242, derrière les boutiques basses et le studio) et
--      « HEIST » dans la police du chef DA (lettres_voxel.luau, à charger avant), crème à contour sombre, 66 × 18,
--      de 136 à 154, ampoules Neon #ffcc48, buissons secs, 2 palmiers ; les tours du sud
--      Skyline/Tower_S1, S2, S4 (ni tag ni script) partent dans la sauvegarde ;
--   3. les 10 boutiques en 3 modèles alternés (enseigne Neon sur toit plat, visière de tuiles, couronne Art déco), stuc
--      de 5 couleurs, auvents rayés, bandeau d'enseigne Neon ; les 4 remplissages en cabines de plage rayées ; tours du
--      nord en pastel, un bandeau sur deux en Neon orange, antenne ; hôtel rose à enseigne verticale « HOTEL » ; studio
--      blanc au grand « 7 » ; bungalows à toits de tuiles et haie ;
--   4. 4 palmiers de plus (copies de Palm_N1 / Palm_S1 et de leur fosse), 8 lampadaires californiens (les 6 anciens
--      rangés, leurs lampes NightLight refaites et taguées), bouches à incendie jaunes à chapeau rouge, noms de rue
--      « SUNSET AVE » et « HEIST BLVD », reflets dorés au ras du sol côté couchant (≈ 10 particules) ;
--   5. flèche de motel en Neon orange et rose, ampoules jaunes, au-dessus de l'enseigne à étoiles ;
--   6. places marquées pour le chef 3D (Biome/Places_Chef3D) : 8 planches de surf, 2 cabriolets, 1 food truck.
-- Avant : sauvegarde ServerStorage/MapBackups/<date>_Biome_LosAngeles (rue, quartier, sol du Greybox).
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local rgb = Color3.fromHex
local Z4 = workspace.Map.Zone_4
local SL = Z4.Street_LosAngeles
local DL = Z4.District_LosAngeles
local GB = workspace.Greybox.Corridor.Zone_4.Ground
local backup = game.ServerStorage.MapBackups:FindFirstChild(os.date("%Y-%m-%d") .. "_Biome_LosAngeles")
assert(backup, "faire la sauvegarde avant (MapBackups/<date>_Biome_LosAngeles)")

local C = {
	asphalt = rgb("77726a"), sand = rgb("e9c48a"), sandLight = rgb("f4d58d"), joint = rgb("d8b27a"), terracotta = rgb("d9733f"),
	salmon = rgb("f2b6a0"), mark = rgb("fff7e6"), yellow = rgb("ffd23f"), hill = rgb("c9a46a"), bush = rgb("8a9a5b"),
	letter = rgb("f7f3e8"), bulb = rgb("ffcc48"), orange = rgb("ff8c42"), rose = rgb("ff5d8f"), pool = rgb("3bc9db"),
	white = rgb("f7f3e8"), tile = rgb("c8553d"), dark = rgb("16161a"), red = rgb("c42c28"), warm = rgb("ffb070"),
	hedge = rgb("4f7a3a"), lampHead = rgb("fff0c8"), post = rgb("5a5550"),
}
local STUCCO = { C.orange, C.rose, C.pool, C.sandLight, C.white }
local SIGN = { C.rose, C.bulb, C.pool }

local rec = CHS:TryBeginRecording("Biome Los Angeles", { allowNoUndo = true })
local old = SL:FindFirstChild("Biome")
if old then old:Destroy() end
local B = Instance.new("Folder")
B.Name = "Biome"
B.Parent = SL
local function folder(name, parent) local f = Instance.new("Folder") f.Name = name f.Parent = parent or B return f end
local function part(parent, name, size, cf, color, mat, opts)
	local p = Instance.new((opts and opts.wedge) and "WedgePart" or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	opts = opts or {}
	p.CanCollide = opts.collide == true
	p.CanTouch = false
	p.CanQuery = opts.collide == true
	p.CastShadow = opts.shadow ~= false and mat ~= Enum.Material.Neon
	if opts.transp then p.Transparency = opts.transp end
	if opts.studs then p.MaterialVariant = "Studs" end
	p.Parent = parent
	return p
end
local function stash(inst)
	for _, d in inst:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	for _, t in CS:GetTags(inst) do CS:RemoveTag(inst, t) end
	inst.Parent = backup
end
local nPaint = 0
local function paint(p, color, mat)
	if not p:IsA("BasePart") or CS:HasTag(p, "NightLight") then return end
	p.Color = color
	if mat then p.Material = mat end
	nPaint += 1
end
local function bbox(m)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in (m:IsA("BasePart") and { m } or m:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf, s = p.CFrame, p.Size
			local e = Vector3.new(
				math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
				math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
				math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z) / 2
			lo = lo:Min(p.Position - e)
			hi = hi:Max(p.Position + e)
		end
	end
	return lo, hi
end
local function gui(p, face, text, color, font)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.TextWrapped = true
	t.Font = font or Enum.Font.FredokaOne
	t.TextColor3 = color
	t.Parent = g
	return g
end

---------------------------------------------------------------- 1. sol
local street = GB:FindFirstChild("Street")
if street then street.Color = C.asphalt street.Material = Enum.Material.Plastic end
for _, n in { "Side_N", "Side_S" } do local p = GB:FindFirstChild(n) if p then p.Color = C.sand p.Material = Enum.Material.Plastic end end
for _, n in { "SideWall_N1", "SideWall_N2", "SideWall_S1", "SideWall_S2" } do local p = GB:FindFirstChild(n) if p then p.Color = C.salmon p.Material = Enum.Material.Plastic end end
for _, p in SL.Ground:GetDescendants() do
	if p:IsA("BasePart") then
		local n = p.Name
		if n:match("^Pavement") then paint(p, C.sand)
		elseif n:match("^Kerb") then paint(p, C.terracotta)
		elseif n:match("^Joint") then paint(p, C.joint)
		elseif n:match("^LaneDash") or n:match("^Crosswalk") then paint(p, C.mark)
		elseif n:match("^YellowLine") then paint(p, C.yellow) end
	end
end
local F = folder("Sol")
part(F, "Seuil_Orange", Vector3.new(0.8, 0.05, 91), CFrame.new(368.9, 0.055, 0), C.orange, Enum.Material.Neon)

---------------------------------------------------------------- 2. colline et lettres
for _, n in { "Tower_S1", "Tower_S2", "Tower_S4" } do
	local t = SL.Skyline:FindFirstChild(n)
	if t then stash(t) end
end
local H = Instance.new("Model")
H.Name = "Colline_HEIST"
H.Parent = B
local flip = CFrame.Angles(0, math.pi, 0) -- pente du coin tournée vers la rue (+z)
-- À l'est (x 466 à 532), derrière les boutiques basses et le studio : en x 420 à 464, Tower_S3 (145 studs) cacherait
-- les lettres. L'Horlogerie (52 studs, au bord de la chaussée) cache le bas du ciel depuis la sortie de Tokyo : d'où le
-- 4e gradin (28/11) et les lettres de 136 à 158.
local HX = 503 -- 28/11 : colline élargie à 76 (fiche police : environ 75), décalée vers l'est (Tower_S3)
local tiers = {
	{ w = 76, h = 36, z0 = -200, z1 = -242, wd = 12 },
	{ w = 74, h = 30, z0 = -210, z1 = -240, wd = 9 },
	{ w = 72, h = 28, z0 = -217, z1 = -239, wd = 7 },
	{ w = 68, h = 30, z0 = -227, z1 = -240, wd = 6 }, -- 28/11 : socle des lettres voxel, sommet 124
}
local yb = 0
for i, t in tiers do
	local d = t.z0 - t.z1
	part(H, "Gradin_" .. i, Vector3.new(t.w, t.h, d), CFrame.new(HX, yb + t.h / 2, (t.z0 + t.z1) / 2), C.hill, Enum.Material.Plastic, { collide = true, studs = true })
	part(H, "Pente_" .. i, Vector3.new(t.w, t.h, t.wd), CFrame.new(HX, yb + t.h / 2, t.z0 + t.wd / 2) * flip, C.hill, Enum.Material.Plastic, { collide = true, studs = true, wedge = true })
	yb += t.h
end
local top = yb -- 124 : lettres voxel de 136 à 158
-- buissons secs
local rnd = Random.new(428)
for i = 1, 10 do
	local ti = (i % 3) + 1
	local t = tiers[ti]
	local base = 0 for k = 1, ti do base += tiers[k].h end
	part(H, "Buisson_" .. i, Vector3.new(rnd:NextNumber(2, 4), rnd:NextNumber(1.5, 2.5), rnd:NextNumber(2, 3.5)), CFrame.new(rnd:NextNumber(HX - t.w / 2 + 3, HX + t.w / 2 - 3), base + 0.9, rnd:NextNumber(t.z1 + 3, t.z0 - 8)), C.bush, Enum.Material.Plastic)
end
-- lettres pixel (12 × 18), barres de 2,4
-- buissons pris dans le 4e gradin : posés sur son sommet
do
	local t4 = tiers[4]
	for _, b in H:GetChildren() do
		if b:IsA("BasePart") and b.Name:match("^Buisson") and math.abs(b.Position.X - HX) < t4.w / 2 and b.Position.Z < t4.z0 + t4.wd and b.Position.Z > t4.z1 and b.Position.Y < top then
			b.CFrame = b.CFrame + Vector3.new(0, top + b.Size.Y / 2 - b.Position.Y, 0)
		end
	end
end
-- HEIST dans la police du chef DA (da-police-voxel.md ; lettres_voxel.luau, à charger avant) : cubes de 2 (66 × 18),
-- crème #f7f3e8, contour sombre, biseau ; chaque lettre est un modèle à part, sur 2 pieds, de biais (±4°), avec sa
-- barre d'ampoules Neon #ffcc48 ; de 136 à 154, sur le 4e gradin. Vus depuis la sortie de Tokyo (x 368, à 6 de haut,
-- 15 points) : 12 côté nord, 5 au milieu de la rue, rien depuis le trottoir sud (l'Horlogerie).
do
	local LV = _G.LettresVoxel
	assert(LV and LV.textGrid, "charger d'abord tools/clement/zones/lettres_voxel.luau")
	local px, bottom, cx, lz = 2.0, 136, HX, -229
	local word = "HEIST"
	local _, Wpx = LV.textGrid(word)
	local col = 0
	for i = 1, #word do
		local ch = word:sub(i, i)
		local gw = #LV.FONT[ch][1]
		if i > 1 then col += 1 end
		local center = (col + gw / 2) - Wpx / 2
		col += gw
		local yaw = math.rad((i % 2 == 0) and 4 or -4)
		local frame = LV.face(Vector3.new(cx + center * px, bottom + 9 * px / 2, lz + ((i % 2 == 0) and 0.3 or 0)), CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(0, 0, 1)))
		local L = Instance.new("Model")
		L.Name = ("Lettre_%d_%s"):format(i, ch)
		L.Parent = H
		LV.mot(L, ch, frame, { px = px, couleur = C.letter, nom = "Mot_" .. ch })
		local lw = (gw + 2) * px
		for _, o in { -0.3, 0.3 } do
			local p = (frame * CFrame.new(o * lw, -9 * px / 2, -1.2)).Position
			part(L, "Pied", Vector3.new(0.9, bottom - top + 0.5, 0.9), CFrame.new(p.X, (bottom + top) / 2, p.Z), C.post, Enum.Material.Plastic)
		end
		part(L, "BarreAmpoules", Vector3.new(lw - px, 0.4, 0.4), frame * CFrame.new(0, -9 * px / 2 - 0.4, 1.0), C.post, Enum.Material.Plastic)
		for x = -(lw - px) / 2 + 0.6, (lw - px) / 2 - 0.5, 2.2 do
			part(L, "Ampoule", Vector3.new(0.8, 0.8, 0.8), frame * CFrame.new(x, -9 * px / 2 - 0.4, 1.3), C.bulb, Enum.Material.Neon)
		end
	end
end
-- 3 palmiers sur et autour de la colline (copies d'un palmier du quartier)
local pb = DL.Palms:FindFirstChild("Palm_B1")
if pb then
	local pv = pb:GetPivot()
	local lo = bbox(pb) -- bas du palmier
	for i, pos in ipairs({ Vector3.new(461, 0, -212), Vector3.new(503, top, -235) }) do
		local c = pb:Clone()
		c.Name = "PalmierColline_" .. i
		c:PivotTo(CFrame.new(pos + (pv.Position - Vector3.new(pv.Position.X, lo.Y, pv.Position.Z))) * (pv - pv.Position))
		for _, d in c:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
		c.Parent = H
	end
end

---------------------------------------------------------------- 3. boutiques, tours, hôtel, studio, bungalows
local BF = folder("Boutiques")
local names = { "Boutique_N1", "Boutique_N2", "Boutique_N5", "Boutique_N6", "Boutique_N7", "Boutique_S1", "Boutique_S2", "Boutique_S5", "Boutique_S6", "Boutique_S7" }
local WORDS = { "SURF", "TACOS", "SODA", "SUNSET", "DINER", "VIDEO", "MOTEL", "PIZZA", "JUICE", "BEACH" }
for i, n in ipairs(names) do
	local b = SL.Boutiques:FindFirstChild(n)
	if b then
		local north = n:match("_N") ~= nil
		local s = north and 1 or -1 -- côté de la rue : −z au nord, +z au sud
		local stucco = STUCCO[(i - 1) % #STUCCO + 1]
		local signCol = SIGN[(i - 1) % #SIGN + 1]
		for _, p in b:GetDescendants() do
			if p:IsA("BasePart") then
				if p.Name == "Wall" then paint(p, stucco)
				elseif p.Name == "Valance" then paint(p, stucco)
				elseif p.Name == "Awning" then paint(p, C.white)
				elseif p.Name == "SignBand" then paint(p, signCol, Enum.Material.Neon)
				elseif p.Name == "Cornice" or p.Name == "Sill" or p.Name == "Divider" then paint(p, C.white) end
			end
		end
		local lo, hi = bbox(b)
		local w = hi.X - lo.X
		local cx = (lo.X + hi.X) / 2
		local cornice = b:FindFirstChild("Cornice", true)
		local topY = cornice and (cornice.Position.Y + cornice.Size.Y / 2) or hi.Y
		local wall = b:FindFirstChild("Wall", true)
		local zc = wall and wall.Position.Z or (lo.Z + hi.Z) / 2
		local zFront = wall and (wall.Position.Z - s * wall.Size.Z / 2) or zc
		local m = Instance.new("Model")
		m.Name = n
		m.Parent = BF
		-- rayures de l'auvent (même repère que l'auvent, débordent de 0,03 dessus et dessous)
		local aw = b:FindFirstChild("Awning", true)
		if aw then
			local nStripes = math.floor(aw.Size.X / 2.2)
			for k = 0, nStripes - 1 do
				if k % 2 == 0 then
					local off = -aw.Size.X / 2 + (k + 0.5) * (aw.Size.X / nStripes)
					part(m, "Rayure", Vector3.new(aw.Size.X / nStripes, aw.Size.Y + 0.06, aw.Size.Z + 0.06), aw.CFrame * CFrame.new(off, 0, 0), stucco, Enum.Material.Plastic)
				end
			end
		end
		local kind = (i - 1) % 3
		if kind == 0 then -- toit plat, grande enseigne
			local bw = w - 2
			for _, px in { -bw / 2 + 1, bw / 2 - 1 } do part(m, "SignPost", Vector3.new(0.4, 2, 0.4), CFrame.new(cx + px, topY + 1, zc), C.dark, Enum.Material.Plastic) end
			local board = part(m, "SignBoard", Vector3.new(bw, 4.5, 0.5), CFrame.new(cx, topY + 2 + 2.25, zc - s * 0.3), C.dark, Enum.Material.Plastic)
			gui(board, north and Enum.NormalId.Front or Enum.NormalId.Back, WORDS[i], signCol)
			for _, e in { { 0, 2.25 }, { 0, -2.25 } } do part(m, "SignNeon", Vector3.new(bw + 0.2, 0.25, 0.25), CFrame.new(cx, topY + 4.25 + e[2], zc - s * 0.65), signCol, Enum.Material.Neon) end
			for _, e in { -1, 1 } do part(m, "SignNeon", Vector3.new(0.25, 4.7, 0.25), CFrame.new(cx + e * (bw / 2 + 0.05), topY + 4.25, zc - s * 0.65), signCol, Enum.Material.Neon) end
		elseif kind == 1 then -- visière de tuiles à l'espagnole
			local rot = north and CFrame.new() or flip
			part(m, "Tuiles", Vector3.new(w - 0.3, 2.4, 3.2), CFrame.new(cx, topY + 1.2, zc - s * 0.6) * rot, C.tile, Enum.Material.Plastic, { wedge = true, studs = true })
			part(m, "Faitage", Vector3.new(w - 0.3, 0.5, 0.6), CFrame.new(cx, topY + 2.45, zc + s * 0.75), C.tile, Enum.Material.Plastic)
			for k = 1, math.floor(w / 3) - 1 do
				part(m, "Tuile", Vector3.new(0.5, 0.35, 3.4), CFrame.new(lo.X + k * 3 - 1, topY + 1.25, zc - s * 0.6) * rot * CFrame.Angles(-math.atan2(2.4, 3.2), 0, 0), rgb("a8442f"), Enum.Material.Plastic)
			end
		else -- couronne Art déco à gradins
			local hs = { 3, 2.5, 2 }
			local ws = { 0.8, 0.55, 0.3 }
			local yy = topY
			for k = 1, 3 do
				part(m, "Gradin", Vector3.new(w * ws[k], hs[k], 2 - (k - 1) * 0.2), CFrame.new(cx, yy + hs[k] / 2, zc), stucco, Enum.Material.Plastic, { studs = true })
				part(m, "Liseret", Vector3.new(w * ws[k] + 0.1, 0.3, 2.1 - (k - 1) * 0.2), CFrame.new(cx, yy + hs[k] - 0.15, zc), C.bulb, Enum.Material.Neon)
				yy += hs[k]
			end
			part(m, "Fleche", Vector3.new(0.6, 3, 0.6), CFrame.new(cx, yy + 1.5, zc), C.bulb, Enum.Material.Plastic)
		end
		-- bande de sable au pied
		part(m, "Sable", Vector3.new(w - 0.4, 0.1, 1.6), CFrame.new(cx, 0.48 + 0.03 + 0.05, zFront - s * 1.4), C.sandLight, Enum.Material.Sand)
	end
end
-- remplissages : cabines de plage rayées
for _, n in { "Boutique_Filler_NE", "Boutique_Filler_NW", "Boutique_Filler_SE", "Boutique_Filler_SW" } do
	local f = SL.Boutiques:FindFirstChild(n)
	if f then
		local wall = f:FindFirstChild("Wall", true)
		if wall then
			paint(wall, C.white)
			local s = n:match("_N") and 1 or -1
			local zf = wall.Position.Z - s * (wall.Size.Z / 2 + 0.04)
			local m = Instance.new("Model") m.Name = n m.Parent = BF
			for k = 0, 2 do
				part(m, "Rayure", Vector3.new(wall.Size.X / 5, wall.Size.Y - 2.5, 0.06), CFrame.new(wall.Position.X - wall.Size.X / 2 + (2 * k + 0.5) * wall.Size.X / 5, wall.Position.Y + 0.25, zf), (k % 2 == 0) and C.pool or C.rose, Enum.Material.Plastic)
			end
		end
	end
end
-- tours du nord en pastel
local TOWER = { Tower_N1 = C.rose, Tower_N2 = C.sandLight, Tower_N3 = C.pool }
for n, col in TOWER do
	local t = SL.Skyline:FindFirstChild(n)
	if t then
		local bands = {}
		for _, p in t:GetDescendants() do
			if p:IsA("BasePart") then
				if p.Name:match("^Core") then paint(p, col)
				elseif p.Name:match("^Column") or p.Name:match("^Crown") then paint(p, C.white)
				elseif p.Name:match("^Band") then table.insert(bands, p) end
			end
		end
		table.sort(bands, function(a, b) return a.Position.Y < b.Position.Y end)
		for k, p in bands do if k % 2 == 0 then paint(p, C.warm, Enum.Material.Neon) else paint(p, C.white, Enum.Material.Plastic) end end
		if n ~= "Tower_N2" then
			local lo, hi = bbox(t)
			part(folder("Antennes"), "Antenne_" .. n, Vector3.new(0.4, 9, 0.4), CFrame.new((lo.X + hi.X) / 2 + 2, hi.Y + 4.5, (lo.Z + hi.Z) / 2 + 2), C.post, Enum.Material.Plastic)
		end
	end
end
-- hôtel rose à enseigne verticale
local hotel = DL.Buildings:FindFirstChild("Hotel_N")
if hotel then
	for _, p in hotel:GetDescendants() do
		if p:IsA("BasePart") and (p.Name:match("^Spandrel") or p.Name:match("^Parapet") or p.Name:match("^Roof")) then paint(p, C.rose) end
	end
	local lo, hi = bbox(hotel)
	local HS = folder("Hotel")
	local board = part(HS, "EnseigneHOTEL", Vector3.new(4.6, 26, 0.8), CFrame.new(lo.X + 4, 34, lo.Z - 0.8), C.dark, Enum.Material.Plastic)
	gui(board, Enum.NormalId.Front, "H\nO\nT\nE\nL", C.rose)
	for _, e in { -1, 1 } do part(HS, "Neon", Vector3.new(0.3, 26.2, 0.3), CFrame.new(lo.X + 4 + e * 2.35, 34, lo.Z - 1.25), C.rose, Enum.Material.Neon) end
	for _, e in { -1, 1 } do part(HS, "Neon", Vector3.new(4.9, 0.3, 0.3), CFrame.new(lo.X + 4, 34 + e * 13.05, lo.Z - 1.25), C.rose, Enum.Material.Neon) end
	part(HS, "Potence", Vector3.new(0.5, 0.5, 1.2), CFrame.new(lo.X + 4, 46, lo.Z - 0.2), C.post, Enum.Material.Plastic)
end
-- studio blanc au grand chiffre
local stage = DL.Buildings:FindFirstChild("SoundStage_S")
if stage then
	local hall
	for _, p in stage:GetDescendants() do
		if p:IsA("BasePart") and p.Name:match("^Hall") then paint(p, C.white) hall = hall or p end
	end
	if hall then
		local hz = hall.Position.Z + hall.Size.Z / 2
		-- à gauche de la porte et de l'enseigne du studio
		local g = part(folder("Studio"), "Chiffre7", Vector3.new(9, 18, 0.1), CFrame.new(hall.Position.X - hall.Size.X / 2 + 5.5, 11, hz + 0.08), C.white, Enum.Material.Plastic, { transp = 1, shadow = false })
		gui(g, Enum.NormalId.Back, "7", C.orange, Enum.Font.LuckiestGuy)
	end
end
-- bungalows : toits de tuiles, corps sable ou blanc, haie
for i, n in ipairs({ "Bungalow_S1", "Bungalow_S2" }) do
	local b = DL.Buildings:FindFirstChild(n)
	if b then
		for _, p in b:GetDescendants() do
			if p:IsA("BasePart") then
				if p.Name:match("^Roof") then paint(p, C.tile)
				elseif p.Name:match("^Body") then paint(p, i == 1 and C.sandLight or C.white) end
			end
		end
		local lo, hi = bbox(b)
		part(folder("Haies"), "Haie_" .. n, Vector3.new(hi.X - lo.X - 2, 1.6, 0.9), CFrame.new((lo.X + hi.X) / 2, 0.8, hi.Z + 0.8), C.hedge, Enum.Material.Grass)
	end
end

---------------------------------------------------------------- 4. palmiers, lampadaires, bouches, panneaux, reflets
local PF = folder("PalmiersEnPlus")
local nPalms = 0
-- hors des bouches à incendie (N1 en x 391-393, S2 en x 491-493)
for _, sp in { { "Palm_N1", "TreeWell_N1", 395.5 }, { "Palm_N1", "TreeWell_N1", 524 }, { "Palm_S1", "TreeWell_S1", 393 }, { "Palm_S1", "TreeWell_S1", 488.8 } } do
	local pm, wm = SL.Palms:FindFirstChild(sp[1]), SL.Palms:FindFirstChild(sp[2])
	if pm and wm then
		local dx = sp[3] - wm.Position.X
		for _, srcM in { pm, wm } do
			local c = srcM:Clone()
			c.Name = srcM.Name .. "_x" .. math.floor(sp[3])
			if c:IsA("BasePart") then c.CFrame = c.CFrame + Vector3.new(dx, 0, 0) else c:PivotTo(c:GetPivot() + Vector3.new(dx, 0, 0)) end
			for _, d in c:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
			c.Parent = PF
		end
		nPalms += 1
	end
end
for _, p in SL.Props:GetChildren() do if p.Name:match("^Lamp_") then stash(p) end end
local LF = folder("Lampadaires")
local lamps = { { 386, 1 }, { 398.5, 1 }, { 494, 1 }, { 520.5, 1 }, { 372, -1 }, { 389.5, -1 }, { 485, -1 }, { 514.5, -1 } }
for i, l in ipairs(lamps) do
	local x, s = l[1], l[2]
	local m = Instance.new("Model")
	m.Name = "LampadaireCalifornien_" .. i
	m.Parent = LF
	local zp = s * 48.2
	part(m, "Socle", Vector3.new(1.2, 1, 1.2), CFrame.new(x, 0.48 + 0.5, zp), C.post, Enum.Material.Plastic, { collide = true })
	part(m, "Mat", Vector3.new(0.5, 22, 0.5), CFrame.new(x, 0.48 + 11, zp), C.post, Enum.Material.Plastic, { collide = true })
	-- col courbé vers la rue : 3 segments
	local pivot = CFrame.new(x, 22.4, zp)
	local angles = { 25, 30, 30 } -- angles cumulés : 25°, 55°, 85° depuis la verticale
	local cur = pivot
	for k, a in ipairs(angles) do
		local seg = cur * CFrame.Angles(math.rad(-s * a), 0, 0) * CFrame.new(0, 0.9, 0) -- vers la rue
		part(m, "Col_" .. k, Vector3.new(0.4, 1.9, 0.4), seg, C.post, Enum.Material.Plastic)
		cur = seg * CFrame.new(0, 0.9, 0)
	end
	local head = part(m, "LampHead", Vector3.new(0.9, 0.5, 1.4), CFrame.new(cur.Position + Vector3.new(0, -0.35, 0)), C.lampHead, Enum.Material.Neon)
	CS:AddTag(head, "NightLight")
end
for _, h in SL.Props:GetChildren() do
	if h.Name:match("^Hydrant") then
		for _, p in h:GetDescendants() do
			if p:IsA("BasePart") then
				if p.Name == "Bonnet" or p.Name == "Nut" then paint(p, C.red) else paint(p, C.yellow) end
			end
		end
	end
end
for _, sgn in { { "StreetSign_N", "SUNSET AVE", "HEIST BLVD" }, { "StreetSign_S", "HEIST BLVD", "SUNSET AVE" } } do
	local m = SL.Props:FindFirstChild(sgn[1])
	if m then
		local main, cross = m:FindFirstChild("BladeMain", true), m:FindFirstChild("BladeCross", true)
		for _, g in (main and main:GetChildren() or {}) do if g:IsA("SurfaceGui") then g:Destroy() end end
		for _, g in (cross and cross:GetChildren() or {}) do if g:IsA("SurfaceGui") then g:Destroy() end end
		if main then gui(main, Enum.NormalId.Front, sgn[2], C.white, Enum.Font.GothamBold) gui(main, Enum.NormalId.Back, sgn[2], C.white, Enum.Font.GothamBold) end
		if cross then gui(cross, Enum.NormalId.Right, sgn[3], C.white, Enum.Font.GothamBold) gui(cross, Enum.NormalId.Left, sgn[3], C.white, Enum.Font.GothamBold) end
	end
end
do
	local p = part(folder("Ambiance"), "RefletsDores", Vector3.new(40, 1, 80), CFrame.new(392, 1, 0), C.bulb, Enum.Material.Plastic, { transp = 1, shadow = false })
	local e = Instance.new("ParticleEmitter")
	e.Name = "RefletsDores"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 3
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.SpreadAngle = Vector2.new(180, 20)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(rgb("ffd27a"), rgb("ff9a4a"))
	e.LightEmission = 1
	e.Parent = p
end

---------------------------------------------------------------- 5. flèche de motel
do
	local sign = SL.Entrance:FindFirstChild("CrownSign", true)
	local x = sign and (sign.Position.X + sign.Size.X / 2 + 0.6) or 372.2
	local ytop = sign and (sign.Position.Y + sign.Size.Y / 2) or 45
	local M = folder("FlecheMotel")
	local yb = ytop + 5
	part(M, "Barre", Vector3.new(0.6, 2.4, 26), CFrame.new(x, yb, -3), C.orange, Enum.Material.Neon)
	part(M, "Descente", Vector3.new(0.6, 6, 2.4), CFrame.new(x, yb - 1.8, 10 - 1.2), C.rose, Enum.Material.Neon)
	part(M, "Pointe_A", Vector3.new(0.6, 2.6, 2.6), CFrame.new(x, yb - 6.1, 8.8) * CFrame.Angles(math.rad(45), 0, 0), C.rose, Enum.Material.Neon)
	-- supports au-dessus du néon de l'enseigne (CrownNeon, jusqu'à ytop + 0,4)
	part(M, "Support_1", Vector3.new(0.3, 4.2, 0.3), CFrame.new(x - 0.3, ytop + 2.9, -12), C.post, Enum.Material.Plastic)
	part(M, "Support_2", Vector3.new(0.3, 4.2, 0.3), CFrame.new(x - 0.3, ytop + 2.9, 4), C.post, Enum.Material.Plastic)
	for z = -15, 9, 2 do part(M, "Ampoule", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x + 0.45, yb + 1.5, z), C.bulb, Enum.Material.Neon) end
end

---------------------------------------------------------------- 6. places du chef 3D
local SF = folder("Places_Chef3D")
local spots = {}
local sk = 0
for _, n in { "Boutique_N1", "Boutique_N2", "Boutique_N5", "Boutique_N7", "Boutique_S1", "Boutique_S2", "Boutique_S6", "Boutique_S7" } do
	local b = SL.Boutiques:FindFirstChild(n)
	if b then
		sk += 1
		local lo, hi = bbox(b)
		local s = n:match("_N") and 1 or -1
		local p = part(SF, ("Spot_Surf_%02d"):format(sk), Vector3.new(0.8, 7, 2.4), CFrame.new(hi.X - 2.5, 0.48 + 3.5, s * 58.6), C.pool, Enum.Material.Plastic, { transp = 1, shadow = false })
		p:SetAttribute("Pour", "chef 3D : planche de surf en voxel, debout contre la vitrine, face vers la rue (" .. (s > 0 and "−z" or "+z") .. ")")
	end
end
for _, s in { { "Spot_Cabriolet_N", Vector3.new(515, 0.48, 52), "le long de la rue (x)" }, { "Spot_Cabriolet_S", Vector3.new(383.5, 0.48, -52), "le long de la rue (x)" } } do
	local p = part(SF, s[1], Vector3.new(9, 3.5, 4.5), CFrame.new(s[2] + Vector3.new(0, 1.75, 0)), C.rose, Enum.Material.Plastic, { transp = 1, shadow = false })
	p:SetAttribute("Pour", "chef 3D : cabriolet rose et turquoise en voxel, garé " .. s[3])
end
do
	local p = part(SF, "Spot_FoodTruck", Vector3.new(14, 9, 6), CFrame.new(455, 0.48 + 4.5, 52), C.orange, Enum.Material.Plastic, { transp = 1, shadow = false })
	p:SetAttribute("Pour", "chef 3D : food truck de tacos en voxel, devant la Bijouterie, guichet vers la rue (−z)")
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _, d in B:GetDescendants() do if d:IsA("BasePart") then np += 1 end end
local _, hhi = bbox(H)
return ("Biome LA : %d pièces neuves, %d recolorées, colline et lettres jusqu'à y %.0f, %d palmiers en plus, %d lampadaires"):format(np, nPaint, hhi.Y, nPalms, #lamps)
