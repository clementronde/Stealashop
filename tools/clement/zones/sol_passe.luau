--!nocheck
-- Passe « sol » des zones (fiche du chef DA : da-sol-zones.md ; retour de Clément du 28/11), les 6 zones.
-- Charger d'abord tools/clement/zones/sol_zones.luau (fonctions communes). À lancer en Edit, après les biomes
-- (biome_londres.luau, biome_tokyo.luau), qui ne posent plus de flaques ni de grilles devant les maisons Terrace.
-- Pour chaque zone : sauvegarde ServerStorage/MapBackups/<date>_Sol_<zone> (sol d'avant, une fois), trottoirs et
-- bordures à 0,48, le passage piéton commun (25 bandes de 9 × 1,8 à +0,03), marquages à +0,03 coupés à 1 stud du
-- passage, puis le propre de la zone :
--   zone 1 : 4 taches mouillées sur les trottoirs (z ±51, au pied des arroseurs du chef VFX) ;
--   Londres : zigzags jaunes sur deux hauteurs (+0,03 / +0,06, ils se croisent aux angles) ; 14 flaques en cases de
--     0,5 (eau SmoothPlastic #2b3038 Reflectance 0,35 à +0,06, auréole à +0,03) avec, dans chacune, une copie de
--     FX_Z2_RondsFlaque (chef VFX, côté 0,55 × le diamètre ; petites flaques : Ring 1, Splash 0,8) ; anciennes flaques
--     Puddle_* (Cylinder en Glass) et PuddleFX_* rangées ;
--   Tokyo : les 50 EntryPaving posés sur la chaussée rangés (le parvis viendra en Texture) ; bande podotactile
--     enfoncée ; fosses et mousse des cerisiers à 0,51, pétales à 0,54 ; 8 flaques à reflets néon (rose, cyan).
-- Écarts à la fiche : marquages et auréoles à +0,03 et eau à +0,06 (la fiche dit +0,02, +0,015 et +0,03 : relevé pour
-- tenir sa propre règle des 0,03 entre deux couches). Les Texture (joints, pavés, usure…) viennent après la
-- publication des images du chef 3D.
-- Contrôle à la fin : SolZones.controle doit rendre une liste vide.

local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")
local SZ = _G.SolZones
assert(SZ, "charger d'abord tools/clement/zones/sol_zones.luau")
local mb = game.ServerStorage.MapBackups

local function backup(name, sources)
	local bname = os.date("%Y-%m-%d") .. "_Sol_" .. name
	local bk = mb:FindFirstChild(bname)
	if not bk then
		bk = Instance.new("Folder")
		bk.Name = bname
		for _, src in sources do
			local c = src:Clone()
			c.Name = src.Name .. "_avant"
			for _, d in c:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
			c.Parent = bk
		end
		bk.Parent = mb
	end
	return bk
end
local function stashByName(folder, patterns, bk)
	local n = 0
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") then
			for _, pat in patterns do if p.Name:match(pat) then SZ.ranger(p, bk) n += 1 break end end
		end
	end
	return n
end
local function crossing(G, xc, bk, patterns)
	stashByName(G, patterns, bk)
	local prev = G:FindFirstChild("PassagePieton")
	if prev then prev:Destroy() end
	SZ.passage(G, xc, 0)
	SZ.marquages(G, { xc }, 0, bk)
end
local function freshFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then f:Destroy() end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local rec = CHS:TryBeginRecording("Sol des 6 zones", { allowNoUndo = true })
local report = {}

-- zone 1
do
	local Z = workspace.Map.Zone_1
	local G = Z.Street_Zone1.Ground
	local bk = backup("Zone1", { G })
	SZ.hauteurs(G)
	crossing(G, 74, bk, { "^Zebra" })
	local T = freshFolder(G, "TachesMouillees")
	for i, s in { { 48, 51 }, { 70, -51 }, { 90, 51 }, { 104, -51 } } do
		SZ.tache(T, s[1], s[2], 4, 2.5, { haut = SZ.TROTTOIR, sol = Color3.fromHex("f0e8d6"), seed = 100 + i, nom = "TacheMouillee_" .. i })
	end
	table.insert(report, "zone 1 : " .. #SZ.controle({ Z, workspace.Greybox.Corridor.Zone_1 }) .. " superpositions")
end

-- Londres
do
	local Z = workspace.Map.Zone_2
	local SL = Z.Street_Londres
	local G = SL.Ground
	local bk = backup("Londres", { G, SL.Weather })
	SZ.hauteurs(G)
	stashByName(G, { "^Puddle" }, bk)
	crossing(G, 168, bk, { "^Zebra" })
	for _, p in G:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^ZigZag") then
			local k = tonumber(p.Name:match("_(%d+)$")) or 0
			local top = (k % 2 == 0) and 0.03 or 0.06
			p.Size = Vector3.new(p.Size.X, top + 0.05, p.Size.Z)
			p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, (top - 0.05) / 2, p.Position.Z)
		end
	end
	stashByName(SL.Weather, { "^PuddleFX" }, bk)
	local F = freshFolder(SL.Biome.Sol, "Flaques")
	local ring = game.ServerStorage:FindFirstChild("_PREVIEW_FX_BIOMES")
	ring = ring and ring:FindFirstChild("FX_Z2_RondsFlaque", true)
	local sol = workspace.Greybox.Corridor.Zone_2.Ground.Street.Color
	local spots = { { 128, -41, 5, 3 }, { 140, 40.5, 6, 3.5 }, { 152, -38, 4, 2.5 }, { 158, 24, 3.5, 2.5 }, { 178, -26, 4, 3 }, { 186, 41, 6, 3 }, { 196, -40.5, 5, 3 }, { 204, 30, 3.5, 2.5 }, { 212, -34, 4.5, 3 }, { 220, 41, 5, 3 }, { 146, 12, 3, 2 }, { 190, -12, 3.5, 2.5 }, { 132, 28, 4, 2.5 }, { 224, -18, 3.5, 2.5 } }
	for i, s in spots do
		-- bord entre l'eau et le pavé mouillé (#42454c, reflet 0,05) : l'ancien (chaussée × 0,75) ressortait en bleu foncé sur les pavés (28/11)
		local m = SZ.flaque(F, s[1], s[2], s[3], s[4], { sol = sol, bord = Color3.fromHex("42454c"), seed = 200 + i, nom = ("Flaque_%02d"):format(i) })
		for _, a in m:GetChildren() do if a:IsA("BasePart") and a.Name == "Aureole" then a.Reflectance = 0.05 end end
		if ring then
			local d = math.min(s[3], s[4])
			local r = ring:Clone()
			r.Name = "FX_Z2_RondsFlaque"
			r.Size = Vector3.new(0.55 * d, 0.05, 0.55 * d)
			r.CFrame = CFrame.new(s[1], 0.06 + 0.05 + 0.025, s[2])
			r.Transparency = 1
			r.CanCollide = false
			r.CanQuery = false
			r.CanTouch = false
			r.CastShadow = false
			if d < 3.5 then
				for _, e in r:GetChildren() do
					if e:IsA("ParticleEmitter") then if e.Name == "Ring" then e.Rate = 1 elseif e.Name == "Splash" then e.Rate = 0.8 end end
				end
			end
			r.Parent = m
		end
	end
	table.insert(report, "Londres : " .. #SZ.controle({ Z, workspace.Greybox.Corridor.Zone_2 }) .. " superpositions")
end

-- Tokyo
do
	local Z = workspace.Map.Zone_3
	local ST = Z.Street_Tokyo
	local G = ST.Ground
	local bk = backup("Tokyo", { G, ST.Trees })
	SZ.hauteurs(G)
	stashByName(G, { "^EntryPaving" }, bk)
	crossing(G, 292, bk, { "^Crosswalk" })
	for _, p in G:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^TactileStrip") then
			p.Size = Vector3.new(p.Size.X, 0.08, p.Size.Z)
			p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, 0.47, p.Position.Z)
		end
	end
	for _, p in ST.Trees:GetDescendants() do
		if p:IsA("BasePart") then
			local top
			if p.Name:match("^Pit") or p.Name:match("^Moss") then top = 0.51 elseif p.Name:match("^Petal") then top = 0.54 end
			if top then
				local h = math.max(p.Size.Y, 0.08)
				p.Size = Vector3.new(p.Size.X, h, p.Size.Z)
				p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, top - h / 2, p.Position.Z)
			end
		end
	end
	local F = freshFolder(ST.Biome.Sol, "Flaques")
	local sol = workspace.Greybox.Corridor.Zone_3.Ground.Street.Color
	local neon = { Color3.fromHex("ff3ea5"), Color3.fromHex("18e0ff") }
	-- la 7e en z −26 : en z −40, elle touchait le reflet de néon Reflet_10
	local spots = { { 245, -30, 4, 2.5 }, { 258, 20, 5, 3 }, { 272, -38, 4, 3 }, { 306, 36, 5, 3 }, { 330, -30, 4.5, 3 }, { 342, 14, 3.5, 2.5 }, { 350, -26, 4, 2.5 }, { 362, 32, 4, 3 } }
	for i, s in spots do SZ.flaque(F, s[1], s[2], s[3], s[4], { sol = sol, seed = 300 + i, neon = neon, nom = ("Flaque_%02d"):format(i) }) end
	table.insert(report, "Tokyo : " .. #SZ.controle({ Z, workspace.Greybox.Corridor.Zone_3 }) .. " superpositions")
end

-- Los Angeles : bordures et bordures rouges à 0,48 ; joints du trottoir à 0,51 ; étoiles et fosses des palmiers à 0,54
-- (au-dessus des joints) ; StarTile_N10 déplacée en x 517 (le palmier ajouté en x 524 la recouvrait) ; pas de flaque
do
	local Z = workspace.Map.Zone_4
	local SL = Z.Street_LosAngeles
	local G = SL.Ground
	local bk = backup("LosAngeles", { G, SL.Palms })
	local function setTop(p, top, bottom)
		p.Size = Vector3.new(p.Size.X, top - bottom, p.Size.Z)
		p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, (top + bottom) / 2, p.Position.Z)
	end
	SZ.hauteurs(G)
	for _, p in G:GetChildren() do if p:IsA("BasePart") and p.Name:match("^RedKerb") then setTop(p, SZ.TROTTOIR, p.Position.Y - p.Size.Y / 2) end end
	crossing(G, 376.5, bk, { "^Crosswalk" })
	for _, p in G:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^Joint") then setTop(p, 0.51, 0.43)
		elseif p:IsA("BasePart") and p.Name:match("^StarTile") then setTop(p, 0.54, 0.43) end
	end
	local star = G:FindFirstChild("StarTile_N10")
	if star then star.CFrame = star.CFrame + Vector3.new(517 - star.Position.X, 0, 0) end
	for _, root in { SL.Palms, SL.Biome:FindFirstChild("PalmiersEnPlus") } do
		if root then for _, p in root:GetDescendants() do if p:IsA("BasePart") and p.Name:match("^TreeWell") then setTop(p, 0.54, 0.43) end end end
	end
	table.insert(report, "LA : " .. #SZ.controle({ Z, workspace.Greybox.Corridor.Zone_4 }) .. " superpositions")
end

-- Paris : plus aucune neige (relevé du chef VFX, neige-restante-paris.md) ; neige au sol, stalactites, flocons de
-- l'entrée, sapins Fir_N et Fir_S et neige du dôme rangés ; le reste repeint (toits en zinc #6f7f8f, lanternes vert
-- bronze #3b5245, bornes #2e3a34, trottoirs calcaire #d8cfbf, pelouse #6b8f4e, assises en bois, kiosque, manège,
-- colonnes Morris, fontaine) ; les deux magasins PNJ : couleur seule ; attribut CouleurAvant sur chaque pièce
-- repeinte ; Weather/SnowCloud laissé au chef VFX (ses feuilles la remplacent)
do
	local Z = workspace.Map.Zone_5
	local SP = Z.Street_Paris
	local bk = backup("Paris", { SP })
	local rgb = Color3.fromHex
	local snow = rgb("ecf2f8")
	local function isSnow(p)
		if p.Material == Enum.Material.Snow or p.Material == Enum.Material.Ice or p.Material == Enum.Material.Glacier then return true end
		if p.Name:match("Snow") or p.Name:match("Icicle") then return true end
		local c = p.Color
		return math.abs(c.R - snow.R) < 0.02 and math.abs(c.G - snow.G) < 0.02 and math.abs(c.B - snow.B) < 0.02
	end
	local REMOVE = { "^RoadSnow", "^SnowBank", "^Boulevard_Snow", "^Hedge_%d+_Snow", "^Icicle", "^PillarSnow", "^ArchSnow", "^Snowflake_", "^DomeSnow" }
	local COLOR = {
		{ "^Mansard", "6f7f8f" }, { "^RoofTop", "6f7f8f" }, { "^DormerCap", "6f7f8f" }, { "^ChimneyBackCap", "6f7f8f" }, { "^ChimneyCap", "6f7f8f" }, { "^AtticTop", "6f7f8f" },
		{ "^LanternRoof", "3b5245" }, { "_Top$", "2e3a34" }, { "^CampanileRoof", "6e5a46" },
		{ "^ChampDeMars", "6b8f4e" }, { "^DistrictGround", "cfc6b4" }, { "^Pavement", "d8cfbf" }, { "^Yard", "c9bfa8" }, { "^Boulevard_Sidewalk", "d8cfbf" },
		{ "^Seat$", "7a4f2e" }, { "_Seat$", "b5824a" }, { "^TableTop", "d9d2c3" },
	}
	for _, n in { "Fir_N", "Fir_S" } do local f = SP:FindFirstChild(n, true) if f then SZ.ranger(f, bk) end end
	local list = {}
	for _, p in Z:GetDescendants() do
		if p:IsA("BasePart") and not (p:FindFirstAncestor("Interior") or p:FindFirstAncestor("Witnesses") or p:FindFirstAncestor("Reserve")) and isSnow(p) and p.Name ~= "SnowCloud" then table.insert(list, p) end
	end
	for _, p in list do
		local done = false
		for _, pat in REMOVE do if p.Name:match(pat) then SZ.ranger(p, bk) done = true break end end
		if not done then
			local col
			for _, c in COLOR do if p.Name:match(c[1]) then col = c[2] break end end
			if not col then
				local par = p.Parent.Name
				if par:match("Bandstand") then col = (p.Name == "Floor") and "8b6a4a" or "6f7f8f"
				elseif par:match("Carousel") then col = "b23a3a"
				elseif par:match("MorrisColumn") then col = "3f6b52"
				elseif par:match("Fountain") then col = "c9c2b0" end
			end
			if col then
				p:SetAttribute("CouleurAvant", p.Color:ToHex())
				p.Color = rgb(col)
				if p.Material == Enum.Material.Snow or p.Material == Enum.Material.Ice or p.Material == Enum.Material.Glacier then p.Material = Enum.Material.Plastic end
			end
		end
	end
	local G = SP.Ground
	SZ.hauteurs(G)
	crossing(G, 668, bk, { "^Crossing" })
	table.insert(report, "Paris : " .. #SZ.controle({ Z, workspace.Greybox.Corridor.Zone_5 }) .. " superpositions")
end

-- New York : neige au sol en matériau Snow #eef3f8 : une couche par trottoir (dessus 0,62), devant les magasins de la
-- bordure à |z| 49,2 hors paillassons (x 809,5 à 826,5), autour de la bouche de métro ; congères en 3 marches
-- (2,4 / 1,6 / 0,8 ; 0,3 / 0,25 / 0,2) contre les murets, hors perrons ; neige sale #c9cbc8 le long des bordures
-- côté chaussée (+0,08), coupée au passage ; chaussée #5d6470 ; couloirs de bus à +0,03 et leurs bords à +0,06 ;
-- chapeaux de neige sur les bouches à incendie et les taxis (les murets ont déjà leur WallTop) ; 6 flaques de gadoue
-- (#6b6a66, Reflectance 0,15, bord de neige sale) ; anciennes bandes SnowCover/Sidewalk* rangées.
-- À dire au chef VFX : ses Parts FX_Z6_NeigeSePose des trottoirs montent à 0,62.
do
	local rgb = Color3.fromHex
	local Z = workspace.Map.Zone_6
	local SN = Z.Street_NewYork
	local G = SN.Ground
	local cover = Z:FindFirstChild("SnowCover", true)
	local bk = backup("NewYork", { G, cover })
	local function setTop(p, top, bottom)
		p.Size = Vector3.new(p.Size.X, top - bottom, p.Size.Z)
		p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, (top + bottom) / 2, p.Position.Z)
	end
	SZ.hauteurs(G)
	workspace.Greybox.Corridor.Zone_6.Ground.Street.Color = rgb("5d6470")
	for _, p in G:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^BusLaneEdge") then setTop(p, 0.06, -0.05)
		elseif p:IsA("BasePart") and p.Name:match("^BusLane") then setTop(p, 0.03, -0.05) end
	end
	local xc = 731.5
	crossing(G, xc, bk, { "^Crosswalk" })
	if cover then stashByName(cover, { "^Sidewalk" }, bk) end
	local N = freshFolder(SN, "NeigeSol")
	local SNOW, DIRTY = rgb("eef3f8"), rgb("c9cbc8")
	local function snowPart(name, x0, x1, z0, z1, top, bottom, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Size = Vector3.new(x1 - x0, top - bottom, z1 - z0)
		p.CFrame = CFrame.new((x0 + x1) / 2, (top + bottom) / 2, (z0 + z1) / 2)
		p.Material = Enum.Material.Snow
		p.Color = color or SNOW
		p.Parent = N
		return p
	end
	local TOP, BOT = 0.62, 0.40
	for _, s in { 1, -1 } do
		local spans = {
			{ 718, 730.5, 47.3, 59.9 }, { 730.5, 740.5, s > 0 and 51 or 47.3, 59.9 }, { 740.5, 777, 47.3, 59.9 },
			{ 777, 809.5, 47.3, 49.2 }, { 826.5, 859, 47.3, 49.2 }, { 859, 868, 47.3, 59.9 },
		}
		for i, sp in spans do
			local z0, z1 = sp[3], sp[4]
			if s < 0 then z0, z1 = -sp[4], -sp[3] end
			snowPart(("NeigeTrottoir_%s%d"):format(s > 0 and "N" or "S", i), sp[1], sp[2], z0, z1, TOP, BOT)
		end
		local runs = { { 718, 760 }, { s > 0 and 865.6 or 859, 868 } }
		for ri, r in runs do
			local y = TOP
			for k, st in { { 2.4, 0.3 }, { 1.6, 0.25 }, { 0.8, 0.2 } } do
				local za, zb = 59.9 - st[1], 59.9
				if s < 0 then za, zb = -59.9, -59.9 + st[1] end
				snowPart(("Congere_%s%d_%d"):format(s > 0 and "N" or "S", ri, k), r[1], r[2], za, zb, y + st[2], y - 0.05)
				y += st[2]
			end
		end
		for i, r in { { 718, xc - 5.5 }, { xc + 5.5, 868 } } do
			local za, zb = 45.5, 46.5
			if s < 0 then za, zb = -46.5, -45.5 end
			snowPart(("NeigeSale_%s%d"):format(s > 0 and "N" or "S", i), r[1], r[2], za, zb, 0.08, -0.05, DIRTY)
		end
	end
	for _, m in SN:GetDescendants() do
		if m:IsA("Model") and (m.Name:match("^Hydrant") or m.Name:match("^Taxi")) then
			local cf, sz = m:GetBoundingBox()
			local t = cf.Y + sz.Y / 2
			local k = m.Name:match("^Hydrant") and 0.25 or 0.4 -- bouche à incendie : petit chapeau sur le bouton (vue du 28/11)
			snowPart("Chapeau_" .. m.Name, cf.X - sz.X * k, cf.X + sz.X * k, cf.Z - sz.Z * k, cf.Z + sz.Z * k, t + 0.3, t - 0.05)
		end
	end
	local F = freshFolder(N, "Gadoue")
	local spots = { { 750, -20, 4, 2.5 }, { 770, 28, 5, 3 }, { 795, -30, 4, 3 }, { 820, 12, 3.5, 2.5 }, { 845, -12, 4, 2.5 }, { 860, 30, 4, 3 } }
	for i, s in spots do SZ.flaque(F, s[1], s[2], s[3], s[4], { sol = rgb("5d6470"), eau = rgb("6b6a66"), reflet = 0.15, bord = DIRTY, seed = 600 + i, nom = ("Gadoue_%02d"):format(i) }) end
	table.insert(report, "New York : " .. #SZ.controle({ Z, workspace.Greybox.Corridor.Zone_6 }) .. " superpositions")
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(report, " ; ")
