--!nocheck
-- Textures du sol des 6 zones (chef Map, 28/11), d'après la fiche du chef DA da-sol-zones.md (sections 3, 4 et 6) et
-- StealAShop-Art/Env/Sol/_LISEZMOI.md (images du chef 3D, publiées par Clément au nom du groupe).
-- À lancer en Edit, après sol_passe.luau (hauteurs, passages piétons, flaques, neige). Relançable : les Texture
-- « Sol_* » et les dossiers PlaquesGrilles sont refaits à chaque fois.
--   - chaussée (Greybox/Corridor/Zone_N/Ground/Street, face Top) : Z1 fissures + taches ; Z2 pavés + fissures ;
--     Z3 taches ; Z4 traces de pneus + fissures + taches ; Z5 pavés gris-beige ; Z6 gadoue + traces de pneus ;
--   - trottoirs (Pavement_*, face Top) : joints teintés de la zone (Z1 4, Z2 joints décalés 8 × 6, Z3 2, Z4 7,5,
--     Z5 3, Z6 5) + taches (Z1), feuilles (Z2, Z5), pétales (Z3). À LA, 7,5 au lieu de 6 : une ligne sur deux tombe
--     sur les joints en relief Joint_* (tous les 15 studs), gardés ;
--   - parvis de Tokyo : la chaussée est coupée en x 261 (là où commencent les lignes de rive), sans chevauchement ;
--     la pièce Street_Parvis (x 230 à 261, encre #3a3358 des anciennes EntryPaving) porte des joints de 6 × 6 ;
--   - usure : une Texture Sol_Usure sur chacune des 25 bandes de chaque passage, OffsetStudsU = attribut UsureOffset,
--     de la couleur que la chaussée a à l'écran ;
--   - plaques d'égout et grilles : une pièce invisible carrée par plaque (2,4 ou 2), un Decal sur le dessus, dans
--     <Street>/Ground/PlaquesGrilles. Dessus à +0,03 sur la chaussée nue ; une grille posée sur une ligne peinte passe
--     0,03 au-dessus d'elle ; jamais sur une flaque, une bande, la neige ou un autre décor plat.
-- Sauvegarde : ServerStorage/MapBackups/<date>_SolTextures (la chaussée de Tokyo avant la coupe).

local CHS = game:GetService("ChangeHistoryService")
local WHITE = Color3.new(1, 1, 1)
local rgb = Color3.fromHex
local IMG = {
	Sol_Feuilles = "rbxassetid://110526173673460",
	Sol_Fissures = "rbxassetid://96178544051686",
	Sol_Gadoue = "rbxassetid://99170412355511",
	Sol_Grille = "rbxassetid://95815912194020",
	Sol_Joints = "rbxassetid://111655191809957",
	Sol_JointsDecales = "rbxassetid://73319352502767",
	Sol_Paves = "rbxassetid://92864411745988",
	Sol_Petales = "rbxassetid://130575835020156",
	Sol_PlaqueEgout = "rbxassetid://122409300405232",
	Sol_PlaqueEgout_Sakura = "rbxassetid://111821637848649",
	Sol_Taches = "rbxassetid://71389620618795",
	Sol_TracesPneus = "rbxassetid://127024265546735",
	Sol_Usure = "rbxassetid://80483888751093",
}

local rec = CHS:TryBeginRecording("Textures du sol", { allowNoUndo = true })
local mb = game.ServerStorage.MapBackups
local bname = os.date("%Y-%m-%d") .. "_SolTextures"
local bk = mb:FindFirstChild(bname)
if not bk then bk = Instance.new("Folder") bk.Name = bname bk.Parent = mb end
local report = {}

local function clean(part)
	for _, c in part:GetChildren() do if c:IsA("Texture") and c.Name:match("^Sol_") then c:Destroy() end end
end
-- t = { image, tuile U, tuile V (défaut = U), couleur, offset U, offset V, z }
local function tex(part, t)
	local x = Instance.new("Texture")
	x.Name = t[1]
	x.Texture = IMG[t[1]]
	x.Face = Enum.NormalId.Top
	x.StudsPerTileU = t[2]
	x.StudsPerTileV = t[3] or t[2]
	x.Color3 = t[4] or WHITE
	x.OffsetStudsU = t[5] or 0
	x.OffsetStudsV = t[6] or 0
	x.ZIndex = t[7] or 1
	x.Parent = part
	return x
end
local function dress(part, list)
	clean(part)
	for _, t in list do tex(part, t) end
end
local function streetOf(i) return workspace.Greybox.Corridor["Zone_" .. i].Ground end
local function groundOf(i)
	for _, c in workspace.Map["Zone_" .. i]:GetChildren() do
		if c.Name:match("^Street") and c:FindFirstChild("Ground") then return c.Ground end
	end
end
local function pavements(G)
	local l = {}
	for _, p in G:GetChildren() do if p:IsA("BasePart") and p.Name:match("^Pavement") then table.insert(l, p) end end
	return l
end

-- Couleur que la chaussée a à l'écran (pour l'usure des bandes) : Sol_Paves est opaque, gris moyen #b7b7b7
local PAVE_Z2, PAVE_Z5 = rgb("767b83"), rgb("948c80") -- Paris foncé après la vue (le passage se perdait)
local function mul(a, b) return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B) end
local PAVE_AVG = rgb("b7b7b7")

-- 1. Parvis de Tokyo : coupe de la chaussée en x 261
do
	local G3 = streetOf(3)
	local st = G3.Street
	local pv = G3:FindFirstChild("Street_Parvis")
	if not pv then
		local copy = st:Clone()
		copy:SetAttribute("Path", st:GetFullName())
		copy.Parent = bk
		local x0, x1 = st.Position.X - st.Size.X / 2, st.Position.X + st.Size.X / 2
		local cut = 261
		pv = st:Clone()
		for _, c in pv:GetChildren() do c:Destroy() end
		pv.Name = "Street_Parvis"
		pv.Size = Vector3.new(cut - x0, st.Size.Y, st.Size.Z)
		pv.CFrame = st.CFrame - st.Position + Vector3.new((x0 + cut) / 2, st.Position.Y, st.Position.Z)
		pv.Color = rgb("3a3358")
		pv.Parent = G3
		st.Size = Vector3.new(x1 - cut, st.Size.Y, st.Size.Z)
		st.CFrame = st.CFrame - st.Position + Vector3.new((cut + x1) / 2, st.Position.Y, st.Position.Z)
		table.insert(report, ("Tokyo : chaussée coupée en x %d (parvis %.0f × %.0f)"):format(cut, pv.Size.X, pv.Size.Z))
	end
	dress(pv, { { "Sol_Joints", 6, 6, rgb("1c1830") }, { "Sol_Taches", 23, 23, WHITE, 9.1, 4.2, 2 } })
end

-- 2. Chaussées, trottoirs et usure, zone par zone
local Z = {
	[1] = {
		road = { { "Sol_Fissures", 37, 37, WHITE, 5.3, 2.7 }, { "Sol_Taches", 23, 23, WHITE, 11.2, 6.1, 2 } },
		walk = { { "Sol_Joints", 4, 4, rgb("b9b2a3") }, { "Sol_Taches", 23, 23, WHITE, 3.7, 1.9, 2 } },
	},
	[2] = {
		road = { { "Sol_Paves", 4, 4, PAVE_Z2 }, { "Sol_Fissures", 37, 37, WHITE, 10.6, 5.4, 2 } },
		walk = { { "Sol_JointsDecales", 8, 6, rgb("4e4b47") }, { "Sol_Feuilles", 17, 17, WHITE, 7.4, 3.8, 2 } },
		usure = mul(PAVE_AVG, PAVE_Z2),
	},
	[3] = {
		road = { { "Sol_Taches", 23, 23, WHITE, 15.9, 8.1 } },
		walk = { { "Sol_Joints", 2, 2, rgb("1c1830") }, { "Sol_Petales", 13, 13, WHITE, 5.1, 2.3, 2 } },
	},
	[4] = {
		road = { { "Sol_TracesPneus", 30, 93 }, { "Sol_Fissures", 37, 37, WHITE, 21.2, 10.8, 2 }, { "Sol_Taches", 23, 23, WHITE, 14.8, 7.6, 3 } },
		walk = { { "Sol_Joints", 7.5, 7.5, rgb("c9a46a"), 3 } }, -- OffsetStudsU 3 : lignes sur les Joint_* (vérifié en vue de dessus)
	},
	[5] = {
		road = { { "Sol_Paves", 4, 4, PAVE_Z5 } },
		walk = { { "Sol_Joints", 3, 3, rgb("b8af9f") }, { "Sol_Feuilles", 17, 17, WHITE, 12.3, 6.2, 2 } },
		usure = mul(PAVE_AVG, PAVE_Z5),
	},
	[6] = {
		road = { { "Sol_Gadoue", 40, 40, WHITE, 26.5, 13.5 }, { "Sol_TracesPneus", 30, 93, WHITE, 12, 0, 2 } },
		walk = { { "Sol_Joints", 5, 5, rgb("9a9893") } },
	},
}
for i, cfg in Z do
	local road = streetOf(i).Street
	dress(road, cfg.road)
	local G = groundOf(i)
	local nw = 0
	for _, p in pavements(G) do dress(p, cfg.walk) nw += 1 end
	local pp = G:FindFirstChild("PassagePieton")
	local nb = 0
	if pp then
		local col = cfg.usure or road.Color
		for k, b in pp:GetChildren() do
			if b:IsA("BasePart") and b.Name:match("^Zebra_") then
				clean(b)
				local n = tonumber(b.Name:match("%d+")) or k
				tex(b, { "Sol_Usure", 6, 6, col, b:GetAttribute("UsureOffset") or n * 1.7, (n * 2.3) % 6 })
				nb += 1
			end
		end
	end
	table.insert(report, ("Z%d : chaussée %d textures, %d trottoirs, %d bandes usées"):format(i, #cfg.road, nw, nb))
end

-- 3. Plaques d'égout et grilles
local function flatsOf(i)
	local flats = {}
	for _, r in { workspace.Map["Zone_" .. i], workspace.Greybox.Corridor["Zone_" .. i] } do
		for _, p in r:GetDescendants() do
			if p:IsA("BasePart") and math.abs(p.CFrame.UpVector.Y) > 0.999 and not p.Name:match("^Street") and not p:FindFirstAncestor("PlaquesGrilles") then
				local top = p.Position.Y + p.Size.Y / 2
				if top < 1.2 and top > -0.5 and p.Size.Y < 2.5 and math.abs(p.Position.Z) < 47 then
					local ex = math.abs(p.CFrame.RightVector.X) * p.Size.X / 2 + math.abs(p.CFrame.LookVector.X) * p.Size.Z / 2
					local ez = math.abs(p.CFrame.RightVector.Z) * p.Size.X / 2 + math.abs(p.CFrame.LookVector.Z) * p.Size.Z / 2
					table.insert(flats, { p = p, top = top, x0 = p.Position.X - ex, x1 = p.Position.X + ex, z0 = p.Position.Z - ez, z1 = p.Position.Z + ez })
				end
			end
		end
	end
	return flats
end
local function isPaint(n) return n:match("Line") or n:match("ZigZag") or n:match("Dash") end
-- renvoie le dessus à donner, ou nil si la place est prise
local function fit(flats, x, z, w, allowPaint)
	local top = 0.03
	for _, f in flats do
		if f.x0 < x + w / 2 + 0.3 and x - w / 2 - 0.3 < f.x1 and f.z0 < z + w / 2 + 0.3 and z - w / 2 - 0.3 < f.z1 then
			if f.p.Transparency >= 0.95 or f.p.Name:match("Kerb") then
				-- pièce invisible (point de patrouille, zone) ou bordure (plus haute, à côté) : on l'ignore
			elseif allowPaint and isPaint(f.p.Name) then
				if f.x0 < x + w / 2 and x - w / 2 < f.x1 and f.z0 < z + w / 2 and z - w / 2 < f.z1 then top = math.max(top, f.top + 0.03) end
			else
				return nil
			end
		end
	end
	return top
end
local function carrier(folder, name, img, x, z, w, top)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(w, 0.08, w)
	p.CFrame = CFrame.new(x, top - 0.04, z)
	p.Parent = folder
	local d = Instance.new("Decal")
	d.Name = img
	d.Texture = IMG[img]
	d.Face = Enum.NormalId.Top
	d.Parent = p
	return p
end
local PLAQUES = {
	[1] = { n = 3, img = "Sol_PlaqueEgout", grilles = 4 },
	[2] = { n = 3, img = "Sol_PlaqueEgout", grilles = 6 },
	[3] = { n = 4, img = "Sol_PlaqueEgout_Sakura", grilles = 0, x0 = 262 },
	[4] = { n = 2, img = "Sol_PlaqueEgout", grilles = 4 },
	[5] = { n = 3, img = "Sol_PlaqueEgout", grilles = 0 },
	[6] = { n = 4, img = "Sol_PlaqueEgout", grilles = 0 },
}
local LANES = { 11, -23, 25, -9 }
local placed = {}
for i, cfg in PLAQUES do
	local road = streetOf(i).Street
	local xa = cfg.x0 or (road.Position.X - road.Size.X / 2)
	local xb = road.Position.X + road.Size.X / 2
	local G = groundOf(i)
	local old = G:FindFirstChild("PlaquesGrilles")
	if old then old:Destroy() end
	local F = Instance.new("Folder")
	F.Name = "PlaquesGrilles"
	F.Parent = G
	local flats = flatsOf(i)
	local miss = 0
	local function put(name, img, w, xs, zs, allowPaint)
		for _, dx in { 0, 3, -3, 6, -6, 9, -9, 12, -12, 15, -15 } do
			for _, z in zs do
				local x = xs + dx
				if x - w / 2 > xa + 3 and x + w / 2 < xb - 3 then
					local top = fit(flats, x, z, w, false) or (allowPaint and fit(flats, x, z, w, true))
					if top then
						local p = carrier(F, name, img, x, z, w, top)
						local a, b = p.Position - p.Size / 2, p.Position + p.Size / 2
						table.insert(flats, { p = p, top = top, x0 = a.X - 0.3, x1 = b.X + 0.3, z0 = a.Z - 0.3, z1 = b.Z + 0.3 })
						table.insert(placed, ("%s/%s x %.1f z %.1f dessus %.2f"):format("Z" .. i, name, x, z, top))
						return
					end
				end
			end
		end
		miss += 1
	end
	for k = 1, cfg.n do
		local x = xa + (k - 0.5) * (xb - xa) / cfg.n
		local zp = LANES[(k + i) % #LANES + 1]
		put(("PlaqueEgout_%02d"):format(k), cfg.img, 2.4, x, { zp, -zp, zp * 0.6, -zp * 0.6 }, false)
	end
	for k = 1, cfg.grilles do
		local x = xa + (k - 0.3) * (xb - xa) / cfg.grilles
		local s = (k % 2 == 0) and 1 or -1
		put(("Grille_%02d"):format(k), "Sol_Grille", 2, x, { 45.4 * s, -45.4 * s }, true)
	end
	table.insert(report, ("Z%d : %d plaques et grilles posées%s"):format(i, #F:GetChildren(), miss > 0 and (", " .. miss .. " sans place") or ""))
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local counts = {}
for i = 1, 6 do
	local n = 0
	for _, d in workspace.Map["Zone_" .. i]:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	table.insert(counts, ("Z%d %d"):format(i, n))
end
return table.concat(report, "\n") .. "\nPièces : " .. table.concat(counts, ", ") .. "\n" .. table.concat(placed, "\n")
