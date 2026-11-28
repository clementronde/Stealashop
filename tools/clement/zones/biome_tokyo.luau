--!nocheck
-- Biome Tokyo néon, zone pilote (Clément, 28/11 ; fiche du chef DA : da-fiche-tokyo-neon.md, planche
-- StealAShop-Art/Captures/2026-11-28_biomes/Z3.jpg). Tout en pièces, dans Studio, en Edit.
-- Ne touche jamais : les magasins STORE_Z3_* (ni façade, ni intérieur, ni pièce du contrat), Greybox/…/ZoneGate_3,
-- les repères NightPatrol, le TruckSpawn, les points de ronde. Le couloir de course (|z| < 46,5) ne reçoit que des
-- pièces plates sans collision (reflets, ligne de seuil) et, en hauteur, des guirlandes et des câbles (au-dessus de 17).
-- Ce que fait le script (relançable : les recolorations sont absolues, le dossier Street_Tokyo/Biome est refait) :
--   1. sol : chaussée encre violette mouillée (Reflectance 0,12), trottoirs, bordures, marquages et terre-pleins aux
--      couleurs de la fiche ; liseré Neon cyan au nord, rose au sud, posé sur la bordure ; murets du sanctuaire encre à
--      chaperon rouge (ceux du couloir, cachés derrière, juste recolorés) ; 10 reflets de néon (bandes Neon à 85 % de transparence) ; ligne de seuil rose et cyan à x = 230 (la
--      marche de 0,4 de la fiche demanderait de rehausser tout le sol, seuils des magasins compris : pas faite) ;
--   2. pagode à 5 toits d'environ 94 studs, effilée pour passer entre Londres et le toit du magasin (l'ancienne part
--      dans la sauvegarde), toits soulignés de Neon rose,
--      20 lanternes rouges à PointLight, flèche dorée ;
--   3. tours, halls, maisons : couleurs de la fiche (les fenêtres taguées NightLight gardent les leurs), une fenêtre
--      sur trois en Neon papier, enseignes verticales en rose, cyan, violet ; tour radio en rouge et blanc à feux ;
--   4. torii vermillon et encre, Neon rose sous la poutre ; allée de lanternes (7 neuves + 2 d'origine de chaque côté,
--      jusqu'à x 249 : au-delà, le pilastre des magasins) ; bannières nobori ;
--   5. 4 guirlandes de lanternes de papier d'une façade à l'autre (24 studs, creux de 4), reliées par des Beam ;
--   6. 6 poteaux électriques à transformateur devant les tours (les façades des magasins couvrent le trottoir), câbles
--      Beam emmêlés, un câble qui traverse la rue (les 4 anciens partent dans la sauvegarde) ;
--   7. cerisiers : feuillage en rose #ff8fc8 (SurfaceAppearance.Color) ;
--   8. brume violette au ras du sol (≈ 20 particules) et poussière lumineuse près des enseignes (≈ 16) ;
--   9. places marquées pour le chef 3D : 8 distributeurs et 2 chats porte-bonheur (pièces invisibles, attribut Pour).
-- Avant : sauvegarde ServerStorage/MapBackups/<date>_Biome_Tokyo (Street_Tokyo, Ambience_Tokyo, sol du Greybox).
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local rgb = Color3.fromHex
local Z3 = workspace.Map.Zone_3
local ST = Z3.Street_Tokyo
local GB = workspace.Greybox.Corridor.Zone_3.Ground
local mb = game.ServerStorage.MapBackups
local backup = mb:FindFirstChild(os.date("%Y-%m-%d") .. "_Biome_Tokyo")
assert(backup, "faire la sauvegarde avant (MapBackups/<date>_Biome_Tokyo)")

local C = {
	ink = rgb("22203a"), inkDeep = rgb("12122a"), street = rgb("1c1830"), walk = rgb("2a2440"), kerb = rgb("3a3358"),
	red = rgb("b8322c"), vermilion = rgb("e8452c"), paper = rgb("f6e7c8"), pink = rgb("ff3ea5"), cyan = rgb("18e0ff"),
	violet = rgb("6b2bd9"), lantern = rgb("e63946"), gold = rgb("d4a72c"), mark = rgb("f2eefc"), yellow = rgb("ffd23f"),
	stone = rgb("3a3550"), dark = rgb("2f2b4a"), cable = rgb("141420"), sakura = rgb("ff8fc8"), mist = rgb("7a3fa8"),
}

local rec = CHS:TryBeginRecording("Biome Tokyo néon", { allowNoUndo = true })
local old = ST:FindFirstChild("Biome")
if old then old:Destroy() end
local B = Instance.new("Folder")
B.Name = "Biome"
B.Parent = ST
local function folder(name) local f = Instance.new("Folder") f.Name = name f.Parent = B return f end

local function part(parent, name, size, cf, color, mat, opts)
	local p = Instance.new("Part")
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
local count = { recolor = 0 }
-- ce qu'on range dans la sauvegarde ne doit plus être trouvé par le code (NightLight)
local function stash(inst)
	for _, d in inst:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	for _, t in CS:GetTags(inst) do CS:RemoveTag(inst, t) end
	inst.Parent = backup
end
local function paint(p, color, mat)
	if not p:IsA("BasePart") then return end
	if CS:HasTag(p, "NightLight") then return end
	p.Color = color
	if mat then p.Material = mat end
	count.recolor += 1
end

---------------------------------------------------------------- 1. sol
local G = ST.Ground
local street = GB:FindFirstChild("Street")
if street then street.Color = C.street street.Material = Enum.Material.Plastic street.Reflectance = 0.12 end
for _, n in { "Side_N", "Side_S" } do local p = GB:FindFirstChild(n) if p then p.Color = C.walk end end
-- murets : ceux du couloir (Greybox SideWall_*) sont recouverts par le mur du sanctuaire et les maisons ; on les
-- recolore, et le chaperon rouge va sur les murets visibles, ceux du sanctuaire (Entrance/ShrineWall*)
for _, n in { "SideWall_N1", "SideWall_N2", "SideWall_S1", "SideWall_S2" } do
	local w = GB:FindFirstChild(n)
	if w then w.Color = C.inkDeep w.Material = Enum.Material.Plastic end
end
for _, p in ST.Entrance:GetChildren() do
	if p:IsA("BasePart") then
		if p.Name:match("^ShrineWall_[NS]$") then p.Color = C.inkDeep p.Material = Enum.Material.Plastic
		elseif p.Name:match("^ShrineWallCoping") then p.Color = C.red
		elseif p.Name:match("^ShrineWallBand") then p.Color = C.vermilion
		elseif p.Name:match("^ShrineWallBase") then p.Color = C.stone end
	end
end
for _, p in G:GetDescendants() do
	if p:IsA("BasePart") then
		local n = p.Name
		if n:match("^Pavement") or n:match("^Land") then paint(p, C.walk)
		elseif n:match("^Kerb") or n:match("^EntryPaving") then paint(p, C.kerb)
		elseif n:match("^Crosswalk") or n:match("^CenterDash") or n:match("^EdgeLine") or n:match("^Diamond") or n:match("^StopLine") then paint(p, C.mark)
		elseif n:match("^TactileStrip") then paint(p, C.yellow) end
	end
end
local F = folder("Sol")
for _, side in { { "N", 1, C.cyan }, { "S", -1, C.pink } } do
	local kerb = G:FindFirstChild("Kerb_" .. side[1])
	if kerb then
		local top = kerb.Position.Y + kerb.Size.Y / 2
		part(F, "Liseret_" .. side[1], Vector3.new(kerb.Size.X, 0.06, 0.4), CFrame.new(kerb.Position.X, top + 0.03 + 0.03, kerb.Position.Z), side[3], Enum.Material.Neon)
	end
end
-- reflets de néon sur la chaussée (dessus de la chaussée à y = 0, marquages jusqu'à 0,04)
local k = 0
for _, x in { 262, 279, 296, 313, 343 } do
	for _, s in { 1, -1 } do
		k += 1
		part(F, "Reflet_" .. k, Vector3.new(2.5, 0.05, 16), CFrame.new(x + (s > 0 and 0 or 6), 0.055, s * 36), (k % 2 == 1) and C.pink or C.cyan, Enum.Material.Neon, { transp = 0.85, shadow = false })
	end
end
-- ligne de seuil Londres → Tokyo, au ras du sol
part(F, "Seuil_Rose", Vector3.new(0.8, 0.05, 91), CFrame.new(230.6, 0.055, 0), C.pink, Enum.Material.Neon)
part(F, "Seuil_Cyan", Vector3.new(0.8, 0.05, 91), CFrame.new(231.8, 0.055, 0), C.cyan, Enum.Material.Neon)

---------------------------------------------------------------- 2. pagode
local oldPagoda = ST.Temple:FindFirstChild("Pagoda")
if oldPagoda then
	oldPagoda.Name = "Pagoda_avant_biome"
	stash(oldPagoda)
end
local PG = Instance.new("Model")
PG.Name = "Pagoda"
PG.Parent = B
-- Place libre mesurée le 28/11 (z 62 à 92) : jusqu'à y 34, x 229,9 (Londres) à 252,9 (magasin) ; de y 34 à 46, le toit
-- de temple de STORE_Z3_Electronique avance jusqu'à x 246 ; au-dessus de 54, libre. D'où une pagode qui s'affine vite
-- (corps 15 → 7, toits 20 → 12), centrée en x 240,5, sans rien toucher du magasin ni de Londres.
local cx, cz = 240.5, 74.5 -- z 74,5 : le premier toit frôle encore le bord du feuillage de SakuraBig_N246_63
local front = -1 -- face vers la rue (−z)
local y = 0
part(PG, "Platform", Vector3.new(18, 1.8, 18), CFrame.new(cx, 0.9, cz), C.stone, Enum.Material.Plastic, { collide = true, studs = true })
part(PG, "Steps", Vector3.new(8, 0.9, 2.4), CFrame.new(cx, 0.45, cz + front * 10.2), C.stone, Enum.Material.Plastic, { collide = true, studs = true })
y = 1.8
-- w : corps ; ew : toit ; et : dessus du toit ; tip : hauteur des coins relevés au-dessus du centre du toit ; rail : balustrade
local floors = {
	{ w = 15, h = 16, ew = 20, et = 17, tip = 1.0, rail = false },
	{ w = 13, h = 14, ew = 18, et = 10, tip = 0.5, rail = true },
	{ w = 9, h = 12, ew = 14, et = 11, tip = 1.0, rail = false },
	{ w = 8, h = 10, ew = 13, et = 10, tip = 1.0, rail = true },
	{ w = 7, h = 8, ew = 12, et = 9, tip = 1.0, rail = true },
}
local lanterns = 0
for i, f in floors do
	local w, h = f.w, f.h
	local m = Instance.new("Model")
	m.Name = "Floor_" .. i
	m.Parent = PG
	part(m, "Body", Vector3.new(w, h, w), CFrame.new(cx, y + h / 2, cz), C.paper, Enum.Material.Plastic, { collide = true, studs = true })
	for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
		part(m, "Post", Vector3.new(1.2, h, 1.2), CFrame.new(cx + sx * (w / 2 - 0.4), y + h / 2, cz + sz * (w / 2 - 0.4)), C.vermilion, Enum.Material.Plastic, { collide = true })
	end end
	part(m, "Beam", Vector3.new(w + 0.6, 0.8, w + 0.6), CFrame.new(cx, y + h - 0.4, cz), C.vermilion, Enum.Material.Plastic)
	part(m, "Sill", Vector3.new(w + 0.6, 0.6, w + 0.6), CFrame.new(cx, y + 0.3, cz), C.vermilion, Enum.Material.Plastic)
	-- fenêtres treillis sur les 4 faces (porte au rez-de-chaussée, côté rue)
	for _, dir in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
		local isDoor = (i == 1 and dir.Z == front)
		local pw, ph = isDoor and 4 or w * 0.36, isDoor and 7 or h * 0.45
		local py = isDoor and (y + 0.6 + ph / 2) or (y + h * 0.5)
		local c = Vector3.new(cx, py, cz) + dir * (w / 2 + 0.1)
		local size = (dir.X ~= 0) and Vector3.new(0.2, ph, pw) or Vector3.new(pw, ph, 0.2)
		part(m, isDoor and "Door" or "Lattice", size, CFrame.new(c), isDoor and C.ink or C.ink, Enum.Material.Plastic)
		if not isDoor then
			local bar = (dir.X ~= 0) and Vector3.new(0.3, ph + 0.4, 0.3) or Vector3.new(0.3, ph + 0.4, 0.3)
			for _, off in { -pw / 4, pw / 4 } do
				local bc = c + dir * 0.2 + ((dir.X ~= 0) and Vector3.new(0, 0, off) or Vector3.new(off, 0, 0))
				part(m, "LatticeBar", bar, CFrame.new(bc), C.red, Enum.Material.Plastic)
			end
		end
	end
	-- balustrade (étages 2 à 5)
	if f.rail then
		local r = w / 2 + 1.1
		for _, s in { -1, 1 } do
			part(m, "Rail", Vector3.new(w + 2.5, 0.3, 0.3), CFrame.new(cx, y + 1.1, cz + s * r), C.vermilion, Enum.Material.Plastic)
			part(m, "Rail", Vector3.new(0.3, 0.3, w + 2.5), CFrame.new(cx + s * r, y + 1.1, cz), C.vermilion, Enum.Material.Plastic)
		end
	end
	-- toit : dalle encre, coins relevés, liseré Neon rose, 4 lanternes rouges
	local ew = f.ew
	local ey = y + h - 0.4 + 0.7 -- centre de la dalle (épaisseur 1,4)
	part(m, "Eave", Vector3.new(ew, 1.4, ew), CFrame.new(cx, ey, cz), C.ink, Enum.Material.Plastic, { collide = true, studs = true })
	part(m, "EaveTop", Vector3.new(f.et, 0.8, f.et), CFrame.new(cx, ey + 1.1, cz), C.ink, Enum.Material.Plastic, { studs = true })
	for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
		part(m, "EaveTip", Vector3.new(1.6, 0.8, 1.6), CFrame.new(cx + sx * (ew / 2 - 0.6), ey + f.tip, cz + sz * (ew / 2 - 0.6)), C.ink, Enum.Material.Plastic)
		local lx, lz = cx + sx * (ew / 2 - 1.2), cz + sz * (ew / 2 - 1.2)
		part(m, "LanternCord", Vector3.new(0.15, 0.8, 0.15), CFrame.new(lx, ey - 1.1, lz), C.cable, Enum.Material.Plastic)
		local L = part(m, "Lantern", Vector3.new(1.2, 1.6, 1.2), CFrame.new(lx, ey - 2.3, lz), C.lantern, Enum.Material.SmoothPlastic)
		local light = Instance.new("PointLight")
		light.Range = 10
		light.Color = rgb("ff7a7a")
		light.Brightness = 1.2
		light.Parent = L
		lanterns += 1
	end end
	for _, s in { -1, 1 } do
		part(m, "EaveNeon", Vector3.new(ew + 0.2, 0.3, 0.3), CFrame.new(cx, ey - 0.35, cz + s * (ew / 2 + 0.05)), C.pink, Enum.Material.Neon)
		part(m, "EaveNeon", Vector3.new(0.3, 0.3, ew + 0.2), CFrame.new(cx + s * (ew / 2 + 0.05), ey - 0.35, cz), C.pink, Enum.Material.Neon)
	end
	y = y + h + 1.0
end
-- flèche (sorin)
local spireBase = y + 0.9
part(PG, "SpireBase", Vector3.new(3, 1.2, 3), CFrame.new(cx, spireBase, cz), C.gold, Enum.Material.Plastic)
part(PG, "Spire", Vector3.new(1.2, 24, 1.2), CFrame.new(cx, spireBase + 12.6, cz), C.gold, Enum.Material.Plastic)
for r = 1, 9 do part(PG, "SpireRing", Vector3.new(3, 0.5, 3), CFrame.new(cx, spireBase + 2 + r * 2, cz), C.gold, Enum.Material.Plastic) end
part(PG, "SpireJewel", Vector3.new(2, 2, 2), CFrame.new(cx, spireBase + 25.6, cz) * CFrame.Angles(0, math.rad(45), 0), C.gold, Enum.Material.Neon)
local _, psz = PG:GetBoundingBox()

---------------------------------------------------------------- 3. tours, halls, maisons
local MAPCOL = { ["344664"] = C.ink, ["3a4254"] = C.ink, ["96928a"] = C.kerb, ["787874"] = C.dark, ["f5f5f0"] = C.paper, ["8099bb"] = C.inkDeep, ["1e6ec8"] = C.red }
local tops = { C.pink, C.cyan, C.violet }
local ti = 0
for _, m in ST.City:GetChildren() do
	ti += 1
	local topCol = tops[(ti - 1) % 3 + 1]
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and not CS:HasTag(p, "NightLight") then
			local hex = p.Color:ToHex()
			if m.Name == "RadioTower" then
				local band = math.floor(p.Position.Y / 10) % 2
				paint(p, band == 0 and C.vermilion or C.mark)
			elseif p.Name:match("^Windows_(%d+)") then
				local n = tonumber(p.Name:match("^Windows_(%d+)"))
				if n % 3 == 0 then paint(p, C.paper, Enum.Material.Neon) else paint(p, C.dark) end
			elseif p.Name == "Parapet" then paint(p, topCol, Enum.Material.Neon)
			elseif p.Name:match("^BladeNeon") then paint(p, topCol, Enum.Material.Neon)
			elseif MAPCOL[hex] then paint(p, MAPCOL[hex]) end
		end
	end
end
-- tour radio : feux rouges à chaque étage (10 studs), aux 2 coins avant
do
	local r = ST.City:FindFirstChild("RadioTower")
	if r then
		local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
		for _, p in r:GetDescendants() do if p:IsA("BasePart") then lo = lo:Min(p.Position - p.Size / 2) hi = hi:Max(p.Position + p.Size / 2) end end
		local RF = folder("RadioTowerFeux")
		local cxr, czr = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
		for yy = lo.Y + 10, hi.Y - 2, 10 do
			part(RF, "Feu", Vector3.new(0.8, 0.8, 0.8), CFrame.new(cxr, yy, czr + 1.2), rgb("ff2828"), Enum.Material.Neon)
		end
		part(RF, "FeuSommet", Vector3.new(1.2, 1.2, 1.2), CFrame.new(cxr, hi.Y + 0.7, czr), rgb("ff2828"), Enum.Material.Neon)
	end
end
for _, m in ST.Houses:GetChildren() do
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then local hex = p.Color:ToHex() if MAPCOL[hex] then paint(p, MAPCOL[hex]) end end
	end
end

---------------------------------------------------------------- 4. entrée : torii, lanternes, nobori
local E = ST.Entrance
local T = E:FindFirstChild("Torii")
if T then
	for _, p in T:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name:match("^Pillar_") or p.Name == "Nuki" or p.Name == "Shimaki" then paint(p, C.vermilion)
			elseif p.Name:match("^Kasagi") then paint(p, C.ink) end
		end
	end
	local nuki = T:FindFirstChild("Nuki", true)
	if nuki then
		part(folder("ToriiNeon"), "NukiNeon", Vector3.new(nuki.Size.X + 0.1, 0.25, nuki.Size.Z - 1), CFrame.new(nuki.Position.X, nuki.Position.Y - nuki.Size.Y / 2 - 0.03 - 0.125, nuki.Position.Z), C.pink, Enum.Material.Neon)
	end
end
local LF = folder("AlleeLanternes")
local src = E:FindFirstChild("StreetLantern_N1")
if src then
	local base = src:GetPivot()
	local i = 0
	for _, s in { 1, -1 } do
		for x = 232.5, 250, 2.9 do -- 7 par côté, entre le trottoir de Londres (x 230) et le pilastre des magasins (x 252)
			i += 1
			local c = src:Clone()
			c.Name = ("AllLantern_%s%02d"):format(s > 0 and "N" or "S", i)
			c:PivotTo(CFrame.new(x, base.Y, s * 52) * (base - base.Position))
			for _, p in c:GetDescendants() do if p:IsA("BasePart") and p.Name ~= "Glow" then p.Color = C.ink end end
			c.Parent = LF
		end
	end
end
local nob = E:FindFirstChild("Nobori_N1")
local nk = 0
for _, n in E:GetChildren() do
	if n.Name:match("^Nobori") then
		nk += 1
		local b = n:FindFirstChild("Banner", true)
		if b then b.Color = (nk % 2 == 1) and C.pink or C.cyan end
	end
end
if nob then
	local base = nob:GetPivot()
	local j = 0
	for _, s in { 1, -1 } do
		for _, x in { 232.5, 238.5, 244.5, 250.5 } do
			j += 1
			local c = nob:Clone()
			c.Name = ("AllNobori_%02d"):format(j)
			local rot = base - base.Position
			if s < 0 then rot = CFrame.Angles(0, math.pi, 0) * rot end
			c:PivotTo(CFrame.new(x, base.Y, s * 49.6) * rot)
			local b = c:FindFirstChild("Banner", true)
			if b then b.Color = (j % 2 == 1) and C.cyan or C.pink end
			c.Parent = LF
		end
	end
end

---------------------------------------------------------------- 5. guirlandes
local GF = folder("Guirlandes")
local nLanterns = 0
for gi, x in ipairs({ 266, 286, 306, 324 }) do
	local g = Instance.new("Model")
	g.Name = "Guirlande_" .. gi
	g.Parent = GF
	-- la façade haute des magasins avance jusqu'à |z| = 49,34 à partir de 18 studs : accroches à 49,0
	local z0, z1, top, sag = -48.7, 48.7, 24, 4
	local function yAt(z) local t = (z - z0) / (z1 - z0) return top - sag * 4 * t * (1 - t) end
	for _, zz in { z0 - 0.3, z1 + 0.3 } do part(g, "Bracket", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, top, zz), C.ink, Enum.Material.Plastic) end
	local prev
	local n = math.floor((z1 - z0) / 4)
	for i2 = 0, n do
		local zz = z0 + (z1 - z0) * i2 / n
		local L = part(g, "PaperLantern", Vector3.new(1.0, 1.4, 1.0), CFrame.new(x, yAt(zz) - 0.9, zz), (i2 % 2 == 0) and C.lantern or C.paper, Enum.Material.Neon, { transp = 0.3 })
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0.9, 0)
		a.Parent = L
		if prev then
			local bm = Instance.new("Beam")
			bm.Attachment0 = prev
			bm.Attachment1 = a
			bm.Width0, bm.Width1 = 0.12, 0.12
			bm.Color = ColorSequence.new(C.cable)
			bm.FaceCamera = true
			bm.Segments = 1
			bm.Parent = L
		end
		prev = a
		nLanterns += 1
	end
end

---------------------------------------------------------------- 6. poteaux et câbles
local PF = folder("Poteaux")
local props = ST.Props
for _, p in props:GetChildren() do
	if p.Name:match("^Pole_") then stash(p) end
end
local poles = {}
-- les façades des magasins couvrent le trottoir jusqu'à |z| = 47,5 (auvents) entre x 251 et 332 : poteaux devant les
-- tours seulement (le nord à 340, hors du cerisier Sakura_N333)
for _, s in { 1, -1 } do
	for _, x in (s > 0 and { 340, 350, 364 } or { 336, 350, 364 }) do
		local m = Instance.new("Model")
		m.Name = ("Poteau_%s%d"):format(s > 0 and "N" or "S", x)
		m.Parent = PF
		local zp = s * 48.6
		part(m, "Post", Vector3.new(1, 22, 1), CFrame.new(x, 0.475 + 11, zp), rgb("6b6880"), Enum.Material.Plastic, { collide = true })
		-- traverses le long de la rue : la façade haute des magasins est à |z| = 49,34 au-dessus de 18 studs
		part(m, "CrossArm", Vector3.new(4.2, 0.4, 0.4), CFrame.new(x, 20.5, zp), rgb("4a4760"), Enum.Material.Plastic)
		part(m, "CrossArm2", Vector3.new(3.2, 0.4, 0.4), CFrame.new(x, 18.9, zp), rgb("4a4760"), Enum.Material.Plastic)
		part(m, "Transformer", Vector3.new(1.6, 2.2, 1.6), CFrame.new(x + 1.35, 15.6, zp - s * 0.3), rgb("8a8a96"), Enum.Material.Plastic)
		part(m, "LampArm", Vector3.new(0.25, 0.25, 2.4), CFrame.new(x, 13.4, zp - s * 1.6), rgb("4a4760"), Enum.Material.Plastic)
		local head = part(m, "LampHead", Vector3.new(0.9, 0.45, 0.9), CFrame.new(x, 13.1, zp - s * 2.8), rgb("f0faff"), Enum.Material.Neon)
		CS:AddTag(head, "NightLight")
		local att = {}
		for ai, off in ipairs({ -1.9, 0, 1.9 }) do
			local a = Instance.new("Attachment")
			a.Name = "Cable_" .. ai
			a.CFrame = CFrame.new(off, (ai == 2) and -1.6 or 0, 0) * CFrame.Angles(0, 0, -math.pi / 2) -- axe X vers le bas
			a.Parent = m:FindFirstChild("CrossArm")
			att[ai] = a
		end
		table.insert(poles, { x = x, s = s, att = att, m = m })
	end
end
local function cable(a0, a1, sag, parent)
	local bm = Instance.new("Beam")
	bm.Attachment0 = a0
	bm.Attachment1 = a1
	bm.CurveSize0 = sag
	bm.CurveSize1 = -sag
	bm.Width0, bm.Width1 = 0.1, 0.1
	bm.Color = ColorSequence.new(C.cable)
	bm.FaceCamera = true
	bm.Segments = 12
	bm.Parent = parent
end
for _, s in { 1, -1 } do
	local line = {}
	for _, p in poles do if p.s == s then table.insert(line, p) end end
	table.sort(line, function(a, b) return a.x < b.x end)
	for i = 1, #line - 1 do
		for ai, sag in ipairs({ 2.5, 4, 3 }) do cable(line[i].att[ai], line[i + 1].att[ai], sag, line[i].m) end
	end
end
-- un câble qui traverse la rue (bas du creux vers 17 studs)
do
	local n, sth = nil, nil
	for _, p in poles do if p.x == 350 then if p.s > 0 then n = p else sth = p end end end
	if n and sth then cable(n.att[1], sth.att[3], 3.5, n.m) end
end

---------------------------------------------------------------- 7. cerisiers
local sak = 0
for _, t in ST.Trees:GetChildren() do
	if t.Name:match("^Sakura") then
		for _, sa in t:GetDescendants() do
			if sa:IsA("SurfaceAppearance") and sa.Parent and not sa.Parent.Name:match("Trunk") and not sa.Parent.Name:match("Moss") then
				sa.Color = C.sakura
				sak += 1
			end
		end
		for _, p in t:GetDescendants() do
			if p:IsA("BasePart") and (p.Name:match("Canopy") or p.Name:match("Petal") or p.Name:match("Leaves")) and not p:FindFirstChildOfClass("SurfaceAppearance") then p.Color = C.sakura sak += 1 end
		end
	end
end

---------------------------------------------------------------- 8. brume et poussière lumineuse
local AF = folder("Ambiance")
local function emitterPart(name, cf, size)
	local p = part(AF, name, size, cf, C.mist, Enum.Material.Plastic, { transp = 1, shadow = false })
	return p
end
for i, pos in ipairs({ Vector3.new(258, 1, 28), Vector3.new(258, 1, -28), Vector3.new(318, 1, 30), Vector3.new(318, 1, -30) }) do
	local p = emitterPart("Brume_" .. i, CFrame.new(pos), Vector3.new(36, 1, 30))
	local e = Instance.new("ParticleEmitter")
	e.Name = "Brume"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0.7
	e.Lifetime = NumberRange.new(6, 8)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 18) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(C.mist)
	e.LightEmission = 0.2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-5, 5)
	e.Parent = p
end
for i, pos in ipairs({ Vector3.new(292, 30, 51), Vector3.new(292, 30, -51) }) do
	local p = emitterPart("Poussiere_" .. i, CFrame.new(pos), Vector3.new(30, 6, 3))
	local e = Instance.new("ParticleEmitter")
	e.Name = "PoussiereLumineuse"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 4
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(C.pink, C.cyan)
	e.LightEmission = 1
	e.Parent = p
end

---------------------------------------------------------------- 9. places du chef 3D
local SF = folder("Places_Chef3D")
local spots = {
	{ "Spot_Vending_01", Vector3.new(338.4, 0.475, 58.2) }, { "Spot_Vending_02", Vector3.new(341.8, 0.475, 58.2) },
	{ "Spot_Vending_03", Vector3.new(355.0, 0.475, 58.2) }, { "Spot_Vending_04", Vector3.new(358.4, 0.475, 58.2) },
	{ "Spot_Vending_05", Vector3.new(347.6, 0.475, -58.2) }, { "Spot_Vending_06", Vector3.new(351.0, 0.475, -58.2) },
	{ "Spot_Vending_07", Vector3.new(334.0, 0.475, -58.2) }, { "Spot_Vending_08", Vector3.new(337.4, 0.475, -58.2) },
}
for _, s in spots do
	local p = part(SF, s[1], Vector3.new(2.8, 6, 2), CFrame.new(s[2] + Vector3.new(0, 3, 0)), C.cyan, Enum.Material.Plastic, { transp = 1, shadow = false })
	p:SetAttribute("Pour", "chef 3D : distributeur lumineux en voxel, face avant vers la rue (" .. (s[2].Z > 0 and "−z" or "+z") .. ")")
end
for _, s in { { "Spot_LuckyCat_Electronique", Vector3.new(296, 0.475, 50.5), "−z" }, { "Spot_LuckyCat_JeuxVideo", Vector3.new(288, 0.475, -50.5), "+z" } } do
	local p = part(SF, s[1], Vector3.new(3, 5, 3), CFrame.new(s[2] + Vector3.new(0, 2.5, 0)), C.paper, Enum.Material.Plastic, { transp = 1, shadow = false })
	p:SetAttribute("Pour", "chef 3D : chat porte-bonheur géant en voxel, patte levée, tourné vers la rue (" .. s[3] .. ")")
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _, d in B:GetDescendants() do if d:IsA("BasePart") then np += 1 end end
return ("Biome Tokyo : %d pièces neuves dans Street_Tokyo/Biome, %d pièces recolorées, pagode %.0f studs (%d lanternes), %d lanternes de guirlande, %d poteaux, %d feuillages roses"):format(np, count.recolor, psz.Y, lanterns, nLanterns, #poles, sak)
