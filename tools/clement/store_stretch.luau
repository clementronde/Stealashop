--!nocheck
--[[
	Agrandir un magasin PNJ en place (demande de Clément du 2026-11-17, liaison L-128).
	Outil de construction du Claude de Clément, exécuté dans Studio par le MCP (execute_luau, Edit).
	Il ne laisse aucun script dans les modèles.

	Chargement : envoyer tout ce fichier à execute_luau. Il pose _G.ClaudeStoreStretch = { apply, CFG }.
	Usage      : _G.ClaudeStoreStretch.apply(workspace.Map.Zone_1.STORE_Z1_Superette)
	             Sans effet sur un magasin déjà étiré (attribut StoreStretch).
	             À appeler après chaque Store.build d'un script de zone.

	Gabarit d'entrée : le magasin de store_builder.luau au scale 1.5 (60 × 72, intérieur 57 × 69, plafond 14,4,
	façade vers −Z, vitrine en z −35, rayons A et B en x ±10,5, rayons muraux en x ±27, z −22,5..13,5).
	Gabarit de sortie : 78 × 108 dehors, intérieur 75 × 105, plafond 18 ; façade, vitrine, porte et rideau
	gardent leur place dans le monde.

	Méthode (étirement par plans de coupe, dans le repère du magasin avant étirement) :
	- tout ce qui est au-delà d'un plan glisse ; une pièce qui traverse un plan s'allonge (mur, sol, plafond,
	  toit, Bounds, frigo, réserve), une petite pièce (< 3 studs sur cet axe) glisse selon son centre ;
	- x : plan en −22 (−9) et en +25,15 (+9) : les allées latérales s'élargissent, porte et vitrine ne bougent pas ;
	- z : plan en −27 (+8, entrée plus grande) et en +14 (+28, nouvelle zone de rayons au fond) ;
	- y : plan en 14 (+3,6) : plafond, toit, étages, enseigne montent ; le rideau `Shutter` ne bouge pas
	  (le code le fait descendre de sa hauteur, il doit rester juste au-dessus de la vitrine) ;
	- une pièce inclinée (auvent, avant-toit, pan de toit) s'allonge le long de son axe resté droit ;
	- l'étage de la façade (au-dessus de la devanture) est réparti régulièrement sur la nouvelle largeur au lieu
	  d'être coupé d'un seul côté (retour de Clément du 2026-11-25, « des vitres décalées ») : fenêtres et autres
	  petits ensembles glissent d'un bloc, enseigne et bandeaux s'élargissent (CFG.facade) ;
	- les produits d'un meuble coupé (frigo, rideau à lanières) sont recopiés dans le trou ;
	- dalles du sol refaites en grille régulière sur le nouveau sol ;
	- rayons en 2 colonnes × 2 rangées de même longueur (retour de Clément du 2026-11-17) : la rangée de devant
	  (A, B, rayons muraux, têtes de gondole) avance de 4 studs et perd une tranche de 6 studs (30 studs de long),
	  avec tout ce qui est posé dessus ; la rangée du fond (E, F) copie la structure de A et B, 5 studs devant le
	  premier meuble du fond, garnie de lots en pavés pris dans les produits du magasin (budget intérieur
	  ≤ 14 900 triangles) ; allée d'environ 13,4 studs entre les deux rangées ;
	- ShelfSlot_07 et ShelfSlot_08 (Premium) vont sur les rayons du fond (E côté droit, F côté gauche) ;
	- addWallShelves (appelé par apply) : chaque tronçon nu des murs gauche et droit (allée du fond, bout de
	  mur près de l'entrée) reçoit une copie du rayon mural d'origine (`Shelf_WallL2_*`, `Shelf_WallR3_*`…),
	  garnie de lots ; le budget restant est partagé à densité égale avec la rangée du fond (attribut WallShelves) ;
	- restore(nom) remet la copie d'avant (ServerStorage/MapBackups/2026-11-17_MagasinsGrands_Avant),
	  check(magasin) contrôle colis, chevauchements, murs et GuardSpawn ;
	- pivot remis en bas au centre du nouveau volume (z +18 dans l'ancien repère).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local CFG = {
	cutsX = { { at = -22.0, add = -9 }, { at = 25.15, add = 9 } },
	cutsZ = { { at = -27.0, add = 8 }, { at = 14.0, add = 28 } },
	cutsY = { { at = 14.0, add = 3.6 } },
	minStretch = 3,
	pivotShift = Vector3.new(0, 0, 18),
	triBudgetInside = 14900,
	tag = "78x108",
	row = { band = { 8.2, 14.2 }, front = -4, backAisle = 5, maxLots = 24 },
	itemPatterns = { "^FridgeItem", "^Shelf_.+_[PC]%d*$" },
	hostPattern = { "Fridge", "Shelf", "Reserve", "Counter" },
	-- étage de la façade : pièces dont l'arrière est devant z −33,5 et le bas au-dessus de y 11,9 (au-dessus du
	-- linteau de la devanture) ; centre en x multiplié par k (demi-largeur 30,6 → 39,6), largeur multipliée par k
	-- à partir de 14 studs (enseigne, bandeaux), gardée en dessous (fenêtres, plaques, balustres)
	facade = { frontZ = -33.5, minY = 11.9, k = (30.6 + 9) / 30.6, scaleWidth = 14 },
}

local function mapAxis(v, cuts)
	local r = v
	for _, c in cuts do
		if c.add > 0 and v > c.at then r += c.add elseif c.add < 0 and v < c.at then r += c.add end
	end
	return r
end

local AX = { "X", "Y", "Z" }

local function axisMap(rel)
	local map = {}
	for i, v in { rel.RightVector, rel.UpVector, rel.LookVector } do
		local ax = (math.abs(v.X) > 0.999 and "X") or (math.abs(v.Y) > 0.999 and "Y") or (math.abs(v.Z) > 0.999 and "Z")
		if not ax or map[ax] then return nil end
		map[ax] = i
	end
	return map
end

local function extents(rel, size)
	local s = size / 2
	local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
	return Vector3.new(
		math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z,
		math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z,
		math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	)
end

local function matchesAny(name, pats)
	for _, p in pats do if name:match(p) then return true end end
	return false
end

local function canResize(p)
	if p:GetAttribute("NoStretch") then return false end
	if p:IsA("Part") and (p.Shape == Enum.PartType.Ball or p.Shape == Enum.PartType.Cylinder) then return false end
	if p:FindFirstChildOfClass("SpecialMesh") then return false end
	return true
end

local function comp(v, ax) return ax == "X" and v.X or ax == "Y" and v.Y or v.Z end

local function mapPoint(v, noY)
	return Vector3.new(mapAxis(v.X, CFG.cutsX), noY and v.Y or mapAxis(v.Y, CFG.cutsY), mapAxis(v.Z, CFG.cutsZ))
end

local function cutsFor(ax, noY)
	if ax == "X" then return CFG.cutsX elseif ax == "Z" then return CFG.cutsZ end
	return noY and {} or CFG.cutsY
end

-- 1) étirement géométrique -------------------------------------------------------------------------
local function stretchGeometry(model, piv0)
	local shutter = model:FindFirstChild("Shutter")
	local parts, atts, models = {}, {}, {}
	for _, d in model:GetDescendants() do
		local noY = shutter ~= nil and (d == shutter or d:IsDescendantOf(shutter))
		if d:IsA("BasePart") then
			table.insert(parts, { p = d, rel = piv0:ToObjectSpace(d.CFrame), size = d.Size, noY = noY })
		elseif d:IsA("Attachment") then
			table.insert(atts, { a = d, rel = piv0:ToObjectSpace(d.WorldCFrame), noY = noY })
		elseif d:IsA("Model") then
			table.insert(models, { m = d, rel = piv0:ToObjectSpace(d.WorldPivot), noY = noY })
		end
	end

	local hosts = {} -- pièces « meuble » coupées : { ax, cut, lo, hi (Vector3 d'origine) }
	local upperParts = {}
	local stretched, moved = 0, 0

	-- Étage de la façade (au-dessus de la devanture, face rue) : réparti régulièrement sur la nouvelle largeur au
	-- lieu d'être coupé d'un seul côté (retour de Clément du 2026-11-25 : « des vitres décalées »). Plan fait avant
	-- de bouger quoi que ce soit :
	--   - une bande pleine largeur qui traverse les deux coupes reste étirée comme le reste ;
	--   - une grande pièce droite (≥ 14 studs : enseigne, bandeau) : centre × k, largeur × k ;
	--   - les petites pièces qui se touchent (cadre, vitre et appui d'une fenêtre, cadran et aiguilles, rampants
	--     d'un fronton) forment un ensemble qui glisse d'un bloc : centre de l'ensemble × k, tailles gardées ;
	--   - un objet compact rangé dans son propre modèle (horloge de rue, emblème, enseigne en drapeau, moins de
	--     14 studs de large) glisse avec son pied comme à l'étirement normal.
	local F = CFG.facade
	local compact = {}
	for _, c in model:GetChildren() do
		if c:IsA("Model") then
			local mn, mx = math.huge, -math.huge
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					local r = piv0:ToObjectSpace(d.CFrame)
					local ex = extents(r, d.Size)
					mn = math.min(mn, r.X - ex.X); mx = math.max(mx, r.X + ex.X)
				end
			end
			if mx - mn < F.scaleWidth then compact[c] = true end
		end
	end
	local smalls = {}
	for _, e in parts do
		local p, rel = e.p, e.rel
		local ext = extents(rel, e.size)
		local top = p
		while top.Parent ~= model do top = top.Parent end
		if rel.Z + ext.Z < F.frontZ and rel.Y - ext.Y >= F.minY and not e.noY and not p.Name:match("^Pilaster") and not compact[top] then
			local n = 0
			for _, cut in CFG.cutsX do if rel.X - ext.X < cut.at and cut.at < rel.X + ext.X then n += 1 end end
			local xa = nil
			for i, v in { rel.RightVector, rel.UpVector, rel.LookVector } do if math.abs(v.X) > 0.999 then xa = i end end
			if n == 2 and ext.X * 2 >= 40 then
				-- bande pleine largeur : étirement normal
			elseif xa and canResize(p) and ext.X * 2 >= F.scaleWidth then
				e.upper = "big"
			else
				e.upper = "small"
				e.lo, e.hi = rel.Position - ext, rel.Position + ext
				table.insert(smalls, e)
			end
		end
	end
	local link = {}
	for i = 1, #smalls do link[i] = i end
	local function root(i) while link[i] ~= i do link[i] = link[link[i]]; i = link[i] end return i end
	local M = 0.12
	for i = 1, #smalls do
		local a = smalls[i]
		for j = i + 1, #smalls do
			local b = smalls[j]
			if a.lo.X - M <= b.hi.X and b.lo.X - M <= a.hi.X and a.lo.Y - M <= b.hi.Y and b.lo.Y - M <= a.hi.Y
				and a.lo.Z - M <= b.hi.Z and b.lo.Z - M <= a.hi.Z then
				link[root(i)] = root(j)
			end
		end
	end
	local spans = {}
	for i, e in smalls do
		local r = root(i)
		spans[r] = spans[r] or { lo = math.huge, hi = -math.huge }
		spans[r].lo = math.min(spans[r].lo, e.lo.X); spans[r].hi = math.max(spans[r].hi, e.hi.X)
	end
	for i, e in smalls do
		local s = spans[root(i)]
		e.dx = (F.k - 1) * (s.lo + s.hi) / 2
	end

	for _, e in parts do
		local p, rel, size = e.p, e.rel, e.size
		local ext = extents(rel, size)
		-- pour chaque axe du magasin, l'axe de la pièce qui lui est parallèle (une pièce inclinée, comme un
		-- auvent, garde souvent un axe droit le long duquel elle peut s'allonger)
		local amap = {}
		if canResize(p) then
			for i, v in { rel.RightVector, rel.UpVector, rel.LookVector } do
				if math.abs(v.X) > 0.999 then amap.X = i elseif math.abs(v.Y) > 0.999 then amap.Y = i elseif math.abs(v.Z) > 0.999 then amap.Z = i end
			end
		end
		local upper = e.upper
		local sz = { size.X, size.Y, size.Z }
		local c = {}
		local didStretch = false
		for _, ax in AX do
			local cuts = cutsFor(ax, e.noY)
			local i = amap[ax]
			local center = comp(rel.Position, ax)
			local half = i and sz[i] / 2 or comp(ext, ax)
			local lo, hi = center - half, center + half
			if ax == "X" and upper == "big" then
				c.X = center * F.k
				sz[i] *= F.k
				didStretch = true
			elseif ax == "X" and upper == "small" then
				c.X = center + e.dx
			else
				local crossing = nil
				for _, cut in cuts do if lo < cut.at and cut.at < hi then crossing = cut end end
				local long = i ~= nil and (sz[i] >= CFG.minStretch or (ax == "Y" and p.Name:match("Chain")))
				if crossing and long then
					local nlo, nhi = mapAxis(lo, cuts), mapAxis(hi, cuts)
					c[ax] = (nlo + nhi) / 2
					sz[i] = nhi - nlo
					didStretch = true
					if ax ~= "Y" and matchesAny(p.Name, CFG.hostPattern) then
						table.insert(hosts, { ax = ax, cut = crossing, lo = rel.Position - ext, hi = rel.Position + ext })
					end
				else
					c[ax] = mapAxis(center, cuts)
				end
			end
		end
		if didStretch then p.Size = Vector3.new(sz[1], sz[2], sz[3]) end
		p.CFrame = piv0 * (CFrame.new(c.X, c.Y, c.Z) * rel.Rotation)
		if upper then upperParts[p] = true end
		if didStretch then stretched += 1 else moved += 1 end
	end
	for _, e in atts do
		-- un Attachment d'une pièce de l'étage suit sa pièce (InfoPoint de l'enseigne…)
		if not upperParts[e.a.Parent] then
			e.a.WorldCFrame = piv0 * (CFrame.new(mapPoint(e.rel.Position, e.noY)) * e.rel.Rotation)
		end
	end
	for _, e in models do
		e.m.WorldPivot = piv0 * (CFrame.new(mapPoint(e.rel.Position, e.noY)) * e.rel.Rotation)
	end

	-- 2) recopier les produits dans le trou d'un meuble coupé
	local filled = 0
	local seen = {}
	for _, e in parts do
		local p, rel = e.p, e.rel
		if p.Parent and matchesAny(p.Name, CFG.itemPatterns) then
			local ext = extents(rel, e.size)
			for _, h in hosts do
				local ax, cut = h.ax, h.cut
				local other = ax == "X" and "Z" or "X"
				local v, lo, hi = comp(rel.Position, ax), comp(rel.Position - ext, ax), comp(rel.Position + ext, ax)
				local inSource
				if cut.add > 0 then inSource = hi <= cut.at and v > cut.at - cut.add
				else inSource = lo >= cut.at and v < cut.at - cut.add end
				local o = comp(rel.Position, other)
				local onHost = o >= comp(h.lo, other) - 0.5 and o <= comp(h.hi, other) + 0.5
					and rel.Position.Y >= h.lo.Y - 0.5 and rel.Position.Y <= h.hi.Y + 6
				local key = p:GetDebugId() .. ax .. cut.at
				if inSource and onHost and not seen[key] then
					seen[key] = true
					local cl = p:Clone()
					for _, d in cl:GetDescendants() do if d:IsA("Attachment") then d:Destroy() end end
					local off = ax == "X" and Vector3.new(cut.add, 0, 0) or Vector3.new(0, 0, cut.add)
					cl.CFrame = piv0 * (CFrame.new(off) * piv0:ToObjectSpace(p.CFrame))
					cl.Parent = p.Parent
					filled += 1
				end
			end
		end
	end
	return stretched, moved, filled
end

-- 3) dalles du sol en grille régulière ---------------------------------------------------------------
local function regridTiles(model, piv0)
	local ft = model:FindFirstChild("FloorTiles")
	local bounds = model:FindFirstChild("Bounds")
	if not (ft and bounds) then return 0 end
	local tiles = {}
	for _, t in ft:GetChildren() do if t:IsA("BasePart") then table.insert(tiles, t) end end
	if #tiles < 4 then return 0 end
	local xs, zs = {}, {}
	for _, t in tiles do
		local r = piv0:PointToObjectSpace(t.Position)
		xs[math.floor(r.X * 10 + 0.5)] = true; zs[math.floor(r.Z * 10 + 0.5)] = true
	end
	local function sorted(s) local l = {} for k in s do table.insert(l, k / 10) end table.sort(l) return l end
	local lx, lz = sorted(xs), sorted(zs)
	if #lx < 2 or #lz < 2 then return 0 end
	local dx = (lx[#lx] - lx[1]) / (#lx - 1)
	local ratio = tiles[1].Size.X / dx
	local y = piv0:PointToObjectSpace(tiles[1].Position).Y
	local rb = piv0:ToObjectSpace(bounds.CFrame)
	local W, D = bounds.Size.X, bounds.Size.Z
	local step = dx * (W / (dx * #lx)) -- même nombre de dalles en largeur
	local nx = #lx
	local nz = math.max(2, math.floor(D / step + 0.5))
	local stepZ = D / nz
	local checker = #tiles <= math.ceil(#lx * #lz / 2)
	local templates = tiles
	local made = 0
	local newFolder = Instance.new("Model")
	newFolder.Name = "FloorTiles"
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			if not checker or (i + j) % 2 == 0 then
				made += 1
				local t = templates[(made - 1) % #templates + 1]:Clone()
				t.Size = Vector3.new(step * ratio, t.Size.Y, stepZ * ratio)
				local x = rb.X - W / 2 + step * (i + 0.5)
				local z = rb.Z - D / 2 + stepZ * (j + 0.5)
				t.CFrame = piv0 * CFrame.new(x, y, z)
				t.Name = "Tile"
				t.Parent = newFolder
			end
		end
	end
	for k, v in ft:GetAttributes() do newFolder:SetAttribute(k, v) end
	newFolder.Parent = model
	ft:Destroy()
	return made
end

-- 4) rayons neufs -------------------------------------------------------------------------------------
local function insideCount(model)
	local b = model.Bounds
	local blocks, other = 0, 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= b then
			local lp = b.CFrame:PointToObjectSpace(p.Position)
			if math.abs(lp.X) <= b.Size.X / 2 and math.abs(lp.Z) <= b.Size.Z / 2 and math.abs(lp.Y) <= b.Size.Y / 2 + 1 then
				if p:IsA("Part") and p.Shape == Enum.PartType.Block then blocks += 1 else other += 1 end
			end
		end
	end
	return blocks, other
end

local function gondolaParts(interior, letter)
	local structure, products = {}, {}
	for _, p in interior:GetChildren() do
		if p:IsA("BasePart") then
			local rest = p.Name:match("^Shelf_" .. letter .. "_(.+)$")
			if rest then
				-- produits : « L_P12 » sur un rayon double face, « P12 » sur un rayon mural
				if rest:match("^[LR]_[PC]%d*$") or rest:match("^[PC]%d*$") then table.insert(products, p) else table.insert(structure, p) end
			end
		end
	end
	return structure, products
end

local function bbox(list, piv0)
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in list do
		local rel = piv0:ToObjectSpace(p.CFrame)
		local e = extents(rel, p.Size)
		mn = mn:Min(rel.Position - e); mx = mx:Max(rel.Position + e)
	end
	return mn, mx
end

-- produits d'un rayon rangés par côté (L, R, ou W pour un rayon mural) et par niveau
local function levelsOf(products, letter, piv0)
	local levels = {}
	for _, p in products do
		local side = p.Name:match("^Shelf_" .. letter .. "_([LR])_") or "W"
		local rel = piv0:ToObjectSpace(p.CFrame)
		local e = extents(rel, p.Size)
		local base = math.floor((rel.Y - e.Y) * 2 + 0.5) / 2
		local key = side .. ":" .. base
		levels[key] = levels[key] or { side = side, base = base, list = {} }
		if p.Name:match("_P%d*$") then table.insert(levels[key].list, p) end
	end
	local lv = {}
	for _, l in levels do if #l.list >= 4 then table.insert(lv, l) end end
	table.sort(lv, function(a, b) if a.side ~= b.side then return a.side < b.side end return a.base < b.base end)
	return lv
end

-- copie d'un rayon (structure seule) au centre (cx, cz) avec une longueur et une largeur relatives
local function copyGondola(interior, piv0, letter, newLetter, cx, cz, lenScale, widthScale)
	local structure, products = gondolaParts(interior, letter)
	if #structure == 0 then return nil end
	local mn, mx = bbox(structure, piv0)
	local ox, oz = (mn.X + mx.X) / 2, (mn.Z + mx.Z) / 2
	local made = {}
	for _, p in structure do
		local rel = piv0:ToObjectSpace(p.CFrame)
		local amap = axisMap(rel)
		local cl = p:Clone()
		for _, d in cl:GetDescendants() do if d:IsA("Attachment") then d:Destroy() end end
		cl.Name = p.Name:gsub("^Shelf_" .. letter .. "_", "Shelf_" .. newLetter .. "_")
		if amap then
			local sz = { p.Size.X, p.Size.Y, p.Size.Z }
			if sz[amap.Z] > 2 then sz[amap.Z] *= lenScale end
			if sz[amap.X] > 0.6 then sz[amap.X] *= widthScale end
			cl.Size = Vector3.new(sz[1], sz[2], sz[3])
		end
		local pos = rel.Position
		cl.CFrame = piv0 * (CFrame.new(cx + (pos.X - ox) * widthScale, pos.Y, cz + (pos.Z - oz) * lenScale) * rel.Rotation)
		cl.Parent = interior
		made[cl.Name] = cl
	end
	return {
		letter = newLetter, cx = cx, cz = cz, ox = ox, oz = oz, lenScale = lenScale, widthScale = widthScale,
		zlo = cz + (mn.Z + 0.3 - oz) * lenScale, zhi = cz + (mx.Z - 0.3 - oz) * lenScale,
		levels = levelsOf(products, letter, piv0), parts = made,
	}
end

local function stockGondola(interior, piv0, g, perRow, keepOut)
	local made = 0
	local L = g.zhi - g.zlo
	local w = L / perRow
	for _, l in g.levels do
		for k = 0, perRow - 1 do
			local z = g.zlo + w * (k + 0.5)
			local blocked = false
			for _, ko in keepOut do
				if ko.side == l.side and math.abs(ko.base - l.base) < 1.2 and math.abs(z - ko.z) < 1.5 + w / 2 then blocked = true end
			end
			if not blocked then
				local src = l.list[(k * 7) % #l.list + 1]
				local rel = piv0:ToObjectSpace(src.CFrame)
				local amap = axisMap(rel)
				local cl = src:Clone()
				for _, d in cl:GetDescendants() do if not d:IsA("Texture") and not d:IsA("Decal") then d:Destroy() end end
				cl.Name = ("Shelf_%s_%s_Lot"):format(g.letter, l.side)
				-- un lot est toujours un pavé (une boule ou un cylindre ne s'allonge pas et coûte cher en triangles)
				if cl:IsA("Part") and cl.Shape ~= Enum.PartType.Block then cl.Shape = Enum.PartType.Block end
				if amap then
					local sz = { src.Size.X, src.Size.Y, src.Size.Z }
					sz[amap.Z] = math.max(0.4, w - 0.15)
					sz[amap.X] *= math.min(1, g.widthScale + 0.15)
					cl.Size = Vector3.new(sz[1], sz[2], sz[3])
				end
				local x = g.cx + (rel.X - g.ox) * g.widthScale
				cl.CFrame = piv0 * (CFrame.new(x, rel.Y, z) * rel.Rotation)
				cl.Parent = interior
				made += 1
			end
		end
	end
	return made
end

local function moveSlot(model, piv0, slotName, g, sideLetter, srcLetter)
	local att = model:FindFirstChild(slotName, true)
	if not (att and att:IsA("Attachment")) then return nil end
	local oldBoard = att.Parent
	local boardSuffix = oldBoard.Name:match("^Shelf_" .. srcLetter .. "_(.+)$")
	if not boardSuffix then return nil end
	local newBoard = g.parts["Shelf_" .. g.letter .. "_" .. boardSuffix]
	if not newBoard then return nil end
	local rel = piv0:ToObjectSpace(att.WorldCFrame)
	local x = g.cx + (rel.X - g.ox) * g.widthScale
	local z = (g.zlo + g.zhi) / 2
	att.Parent = newBoard
	att.WorldCFrame = piv0 * (CFrame.new(x, rel.Y, z) * rel.Rotation)
	local e = extents(piv0:ToObjectSpace(newBoard.CFrame), newBoard.Size)
	local base = math.floor((rel.Y) * 2 + 0.5) / 2
	return { side = sideLetter, base = base, z = z, board = oldBoard, oldZ = rel.Z }
end

-- rangée de devant raccourcie à 30 studs (retour de Clément du 2026-11-17 : 2 colonnes × 2 rangées, mêmes longueurs)
-- Rayons A, B, WallL, WallR et têtes de gondole Promo : tout avance de 4 studs vers l'entrée et on retire une
-- tranche de 6 studs (z 8,2..14,2 après étirement), entre les colis 05/06 et le colis 09.
local NOT_CONTENT = { "^InnerWall", "^Wall", "^Ceiling", "^Floor", "^Tile", "^Bounds$", "^Carpet", "^Plank" }
local NOT_CONTENT_ROOTS = { Facade = true, Roof = true, UpperFloors = true, FloorTiles = true, Window = true,
	WindowFractured = true, Door = true, Shutter = true, Reserve = true, Decor = true, Showcase = true, Awning = true, BladeSign = true }

local function compactFrontRow(model, interior, piv0)
	local R = CFG.row
	local B0, B1 = R.band[1], R.band[2]
	local cut = B1 - B0
	local function g(z)
		if z < B0 then return z + R.front elseif z > B1 then return z + R.front - cut end
		return B0 + R.front
	end
	local parts, atts, taken = {}, {}, {}
	local function take(p)
		if taken[p] then return end
		taken[p] = true
		table.insert(parts, { p = p, rel = piv0:ToObjectSpace(p.CFrame) })
		for _, a in p:GetDescendants() do
			if a:IsA("Attachment") then table.insert(atts, { a = a, rel = piv0:ToObjectSpace(a.WorldCFrame) }) end
		end
	end
	for _, p in interior:GetChildren() do
		if p:IsA("BasePart") and (p.Name:match("^Shelf_[AB]_") or p.Name:match("^Shelf_Wall[LR]_") or p.Name:match("^Promo")) then take(p) end
	end
	-- ce qui est posé sur un rayon de devant, quel que soit son nom (cadres de la galerie, cadrans d'horloge…)
	local racks = {}
	for _, L in { "A", "B", "WallL", "WallR" } do
		local list = {}
		for _, e in parts do if e.p.Name:match("^Shelf_" .. L .. "_") then table.insert(list, e.p) end end
		if #list > 0 then local mn, mx = bbox(list, piv0); table.insert(racks, { mn = mn, mx = mx }) end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not taken[d] and not d.Name:match("^Shelf_") and not matchesAny(d.Name, NOT_CONTENT) then
			local top = d
			while top.Parent ~= model do top = top.Parent end
			if not NOT_CONTENT_ROOTS[top.Name] then
				local r = piv0:PointToObjectSpace(d.Position)
				for _, k in racks do
					if r.X > k.mn.X - 0.3 and r.X < k.mx.X + 0.3 and r.Z > k.mn.Z and r.Z < k.mx.Z and r.Y > 0.7 and r.Y < k.mx.Y + 0.5 then
						take(d)
						break
					end
				end
			end
		end
	end
	local removed = 0
	for _, e in parts do
		local p, rel = e.p, e.rel
		local amap = axisMap(rel)
		local ext = extents(rel, p.Size)
		local lo, hi = rel.Z - ext.Z, rel.Z + ext.Z
		if amap and canResize(p) and ext.Z * 2 >= CFG.minStretch then
			local nlo, nhi = g(lo), g(hi)
			local sz = { p.Size.X, p.Size.Y, p.Size.Z }
			sz[amap.Z] = math.max(0.05, nhi - nlo)
			p.Size = Vector3.new(sz[1], sz[2], sz[3])
			p.CFrame = piv0 * (CFrame.new(rel.X, rel.Y, (nlo + nhi) / 2) * rel.Rotation)
		elseif hi > B0 and lo < B1 then
			p:Destroy()
			removed += 1
		else
			p.CFrame = piv0 * (CFrame.new(rel.X, rel.Y, g(rel.Z)) * rel.Rotation)
		end
	end
	for _, e in atts do
		if e.a.Parent then
			e.a.WorldCFrame = piv0 * (CFrame.new(e.rel.X, e.rel.Y, g(e.rel.Z)) * e.rel.Rotation)
		end
	end
	return removed
end

-- fond de la colonne : premier meuble (réserve, frigo, palette, borne…) derrière la rangée, dans la largeur du rayon
local function columnLimit(model, piv0, xlo, xhi, zFrom)
	local limit = math.huge
	for _, root in { model:FindFirstChild("Interior"), model:FindFirstChild("Reserve") } do
		if root then
			for _, p in root:GetDescendants() do
				if p:IsA("BasePart") and not p.Name:match("^Shelf_[ABEF]_") then
					local rel = piv0:ToObjectSpace(p.CFrame)
					local e = extents(rel, p.Size)
					local top = rel.Y + e.Y
					if top > 1.5 and e.Y * 2 > 0.8 and rel.X + e.X > xlo and rel.X - e.X < xhi and rel.Z - e.Z > zFrom
						and not p.Name:match("^Ceiling") and not p.Name:match("Light") and not p.Name:match("^Chandelier")
						and not p.Name:match("^InnerWall") and not p.Name:match("^Wall") then
						limit = math.min(limit, rel.Z - e.Z)
					end
				end
			end
		end
	end
	return limit
end

local function addShelves(model, piv0)
	local interior = model:FindFirstChild("Interior")
	if not interior then return "pas d'Interior" end
	local removed = compactFrontRow(model, interior, piv0)
	local blocks, other = insideCount(model)
	local allowance = math.floor((CFG.triBudgetInside - blocks * 12 - other * 60) / 12)
	local aMn, aMx = bbox((gondolaParts(interior, "A")), piv0)
	local bMn, bMx = bbox((gondolaParts(interior, "B")), piv0)
	local len = aMx.Z - aMn.Z
	local frontEnd = math.max(aMx.Z, bMx.Z)
	-- fond de la 2e rangée : 5 studs devant le premier meuble du fond, même longueur que la 1re rangée
	local limA = columnLimit(model, piv0, aMn.X - 1, aMx.X + 1, frontEnd)
	local limB = columnLimit(model, piv0, bMn.X - 1, bMx.X + 1, frontEnd)
	local backHi = math.min(limA, limB, mapAxis(CFG.cutsZ[2].at + 0.01, CFG.cutsZ) + 22) - CFG.row.backAisle
	local backLo = backHi - len
	local gap = backLo - frontEnd
	local gBL = copyGondola(interior, piv0, "A", "E", (aMn.X + aMx.X) / 2, (backLo + backHi) / 2, 1, 1)
	local gBR = copyGondola(interior, piv0, "B", "F", (bMn.X + bMx.X) / 2, (backLo + backHi) / 2, 1, 1)
	local structureParts = 0
	for _, g in { gBL, gBR } do if g then for _ in g.parts do structureParts += 1 end end end
	local keepE, keepF = {}, {}
	local s7 = gBL and moveSlot(model, piv0, "ShelfSlot_07", gBL, "R", "A")
	local s8 = gBR and moveSlot(model, piv0, "ShelfSlot_08", gBR, "L", "B")
	if s7 then table.insert(keepE, s7) end
	if s8 then table.insert(keepF, s8) end
	local levels = (gBL and #gBL.levels or 0) + (gBR and #gBR.levels or 0)
	local per = CFG.row.maxLots
	while per > 4 and levels * per > allowance - structureParts do per -= 1 end
	local lots = 0
	if gBL then lots += stockGondola(interior, piv0, gBL, per, keepE) end
	if gBR then lots += stockGondola(interior, piv0, gBR, per, keepF) end
	local b2, o2 = insideCount(model)
	return string.format("rangée 1 : z %.1f..%.1f (%d produits retirés) ; rangée 2 (E, F) : z %.1f..%.1f, allée entre les rangées %.1f ; %d lots (%d par niveau) ; slots 07 %s 08 %s ; intérieur %d blocs + %d autres ≈ %d triangles",
		aMn.Z, aMx.Z, removed, backLo, backHi, gap, lots, per, s7 and "déplacé" or "NON", s8 and "déplacé" or "NON", b2, o2, b2 * 12 + o2 * 60)
end

-- rayons muraux sur les murs restés nus (retour de Clément du 2026-11-17 : « il manque les rayons sur les murs
-- pour l'allée du fond ») : chaque tronçon libre des murs gauche et droit reçoit une copie du rayon mural
-- d'origine (même kit), garnie de lots des produits de ce rayon. Le budget restant est partagé à densité égale
-- entre ces rayons et la rangée du fond (E, F), dont les lots sont refaits.
local WALL_SKIP = { "^InnerWall", "^Ceiling", "^Floor", "^Tile", "^Bounds$", "^Carpet", "^Plank", "^WallNeon", "^WallRail", "Light", "^EntranceMat" }

local function freeWallSpans(model, piv0)
	local b = model.Bounds
	local rb = piv0:ToObjectSpace(b.CFrame)
	local x0, x1, z0, z1 = rb.X - b.Size.X / 2, rb.X + b.Size.X / 2, rb.Z - b.Size.Z / 2, rb.Z + b.Size.Z / 2
	local occ = { L = {}, R = {} }
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= b and not matchesAny(p.Name, WALL_SKIP) then
			local top = p
			while top.Parent ~= model do top = top.Parent end
			if top.Name ~= "Facade" and top.Name ~= "Roof" and top.Name ~= "UpperFloors" then
				local r = piv0:ToObjectSpace(p.CFrame)
				local e = extents(r, p.Size)
				if r.Y + e.Y > 1.5 and r.Y - e.Y < 10 then
					if r.X - e.X < x0 + 4 then table.insert(occ.L, { r.Z - e.Z, r.Z + e.Z }) end
					if r.X + e.X > x1 - 4 then table.insert(occ.R, { r.Z - e.Z, r.Z + e.Z }) end
				end
			end
		end
	end
	local spans = {}
	for side, list in occ do
		table.sort(list, function(a, c) return a[1] < c[1] end)
		local free, cur = {}, z0
		for _, o in list do
			if o[1] > cur + 6 then table.insert(free, { cur, o[1] }) end
			cur = math.max(cur, o[2])
		end
		if z1 > cur + 6 then table.insert(free, { cur, z1 }) end
		spans[side] = free
	end
	return spans
end

-- rangée du fond déjà posée : sa description pour la regarnir
local function gondolaInfo(interior, piv0, letter, srcLetter)
	local st = gondolaParts(interior, letter)
	local sst, sprod = gondolaParts(interior, srcLetter)
	if #st == 0 or #sst == 0 then return nil end
	local mnE, mxE = bbox(st, piv0)
	local mnA, _ = bbox(sst, piv0)
	local _, mxA = bbox(sst, piv0)
	return { letter = letter, cx = (mnE.X + mxE.X) / 2, ox = (mnA.X + mxA.X) / 2, widthScale = 1,
		zlo = mnE.Z + 0.3, zhi = mxE.Z - 0.3, levels = levelsOf(sprod, srcLetter, piv0) }
end

local function slotKeep(model, piv0, slotName, side)
	local a = model:FindFirstChild(slotName, true)
	if not a then return {} end
	local r = piv0:PointToObjectSpace(a.WorldPosition)
	return { { side = side, base = math.floor(r.Y * 2 + 0.5) / 2, z = r.Z } }
end

local function addWallShelves(model)
	if model:GetAttribute("WallShelves") then return model.Name .. " : rayons muraux déjà posés" end
	local piv0 = model:GetAttribute("StretchBasePivot")
	assert(piv0, model.Name .. " : pas encore étiré")
	local interior = model.Interior
	local spans = freeWallSpans(model, piv0)
	for _, p in interior:GetChildren() do
		if p:IsA("BasePart") and p.Name:match("^Shelf_[EF]_[LR]_Lot$") then p:Destroy() end
	end
	local list, structure = {}, 0
	local made = {}
	for _, side in { "L", "R" } do
		local src = side == "L" and "WallL" or "WallR"
		local st = gondolaParts(interior, src)
		if #st > 0 then
			local mn, mx = bbox(st, piv0)
			local len = mx.Z - mn.Z
			local idx = 1
			for _, sp in spans[side] do
				local lo, hi = sp[1] + 1.5, sp[2] - 1.5
				if hi - lo >= 6 then
					idx += 1
					local g = copyGondola(interior, piv0, src, src .. idx, (mn.X + mx.X) / 2, (lo + hi) / 2, (hi - lo) / len, 1)
					if g then
						for _ in g.parts do structure += 1 end
						table.insert(list, { g = g, keep = {} })
						table.insert(made, string.format("%s%d z %.0f..%.0f", src, idx, lo, hi))
					end
				end
			end
		end
	end
	local gE = gondolaInfo(interior, piv0, "E", "A")
	local gF = gondolaInfo(interior, piv0, "F", "B")
	if gE then table.insert(list, { g = gE, keep = slotKeep(model, piv0, "ShelfSlot_07", "R") }) end
	if gF then table.insert(list, { g = gF, keep = slotKeep(model, piv0, "ShelfSlot_08", "L") }) end
	local blocks, other = insideCount(model)
	local allowance = math.floor((CFG.triBudgetInside - blocks * 12 - other * 60) / 12)
	local total = 0
	for _, e in list do total += (e.g.zhi - e.g.zlo) * #e.g.levels end
	local d = total > 0 and math.max(0, allowance) / total or 0
	local lots = 0
	for _, e in list do
		local per = math.max(3, math.min(CFG.row.maxLots, math.floor((e.g.zhi - e.g.zlo) * d)))
		lots += stockGondola(interior, piv0, e.g, per, e.keep)
	end
	model:SetAttribute("WallShelves", true)
	local b2, o2 = insideCount(model)
	return string.format("%s : %d rayons muraux (%s), %d pièces de structure, %d lots (%.2f par stud) ; intérieur %d blocs + %d autres ≈ %d triangles",
		model.Name, #made, table.concat(made, ", "), structure, lots, d, b2, o2, b2 * 12 + o2 * 60)
end

-- 5) point d'entrée ------------------------------------------------------------------------------------
local function apply(model)
	assert(model and model:IsA("Model") and model.Name:match("^STORE_"), "pas un magasin STORE_*")
	if model:GetAttribute("StoreStretch") then return model.Name .. " : déjà étiré (" .. model:GetAttribute("StoreStretch") .. ")" end
	local rec = ChangeHistoryService:TryBeginRecording("StoreStretch " .. model.Name)
	local ok, res = pcall(function()
		local piv0 = model:GetPivot()
		local s, m, f = stretchGeometry(model, piv0)
		local tiles = regridTiles(model, piv0)
		local shelves = addShelves(model, piv0)
		model.WorldPivot = piv0 * CFrame.new(CFG.pivotShift)
		model:SetAttribute("StoreStretch", CFG.tag)
		model:SetAttribute("StretchBasePivot", piv0)
		local walls = addWallShelves(model)
		local _, size = model:GetBoundingBox()
		return string.format("%s : %d pièces allongées, %d déplacées, %d produits recopiés, %d dalles ; %s ; %s ; Bounds %s ; bbox %.1f × %.1f × %.1f",
			model.Name, s, m, f, tiles, shelves, walls, tostring(model.Bounds.Size), size.X, size.Y, size.Z)
	end)
	if rec then ChangeHistoryService:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
	if not ok then error(res) end
	return res
end

-- 6) outils de reprise et de contrôle -------------------------------------------------------------------
-- remettre un magasin tel qu'il était avant l'étirement (copie de ServerStorage/MapBackups)
local BACKUP = "2026-11-17_MagasinsGrands_Avant"
local function restore(name)
	local CS = game:GetService("CollectionService")
	local bk = game.ServerStorage.MapBackups[BACKUP]:FindFirstChild(name)
	assert(bk, "pas de sauvegarde pour " .. name)
	local cur
	for _, s in CS:GetTagged("NPCStore") do if s.Name == name and s:IsDescendantOf(workspace) then cur = s end end
	local c = bk:Clone()
	c:SetAttribute("BackupOf", nil)
	c:AddTag("NPCStore")
	local parent = cur.Parent
	cur:Destroy()
	c.Parent = parent
	return c
end

-- contrôle : colis libres, rangée du fond seule, produits sans chevauchement, murs fermés, GuardSpawn libre
local function check(m)
	local base = m:GetAttribute("StretchBasePivot")
	local out = {}
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Include; op.FilterDescendantsInstances = { m }
	local badSlots = {}
	for i = 1, 10 do
		local a = m:FindFirstChild(string.format("ShelfSlot_%02d", i), true)
		if not a then table.insert(badSlots, i .. " absent") else
			for _, h in workspace:GetPartBoundsInBox(a.WorldCFrame * CFrame.new(0, 0.85, 0), Vector3.new(1.9, 1.55, 1.9), op) do
				if h ~= a.Parent and h.Name ~= "Bounds" and h.CanQuery then table.insert(badSlots, i .. ":" .. h.Name) end
			end
		end
	end
	table.insert(out, "colis : " .. (#badSlots == 0 and "10 libres" or table.concat(badSlots, ",")))
	local newSet = {}
	for _, p in m.Interior:GetChildren() do if p:IsA("BasePart") and p.Name:match("^Shelf_[EF]_") then newSet[p] = true end end
	local clash = {}
	for p in newSet do
		for _, h in workspace:GetPartBoundsInBox(p.CFrame, p.Size - Vector3.new(0.1, 0.1, 0.1), op) do
			if not newSet[h] and h.Name ~= "Bounds" and h.Name ~= "FloorShop" and h.Name ~= "Floor"
				and not (m:FindFirstChild("FloorTiles") and h:IsDescendantOf(m.FloorTiles)) then
				clash[h:GetFullName():sub(#m:GetFullName() + 2)] = true
			end
		end
	end
	local cl = {}; for k in clash do table.insert(cl, k) end
	table.insert(out, "rangée 2 touche : " .. (#cl == 0 and "rien" or table.concat(cl, " ; ")))
	local prods = {}
	for _, p in m.Interior:GetChildren() do if p:IsA("BasePart") and p.Name:match("^Shelf_[AB]_[LR]_P") then prods[p] = true end end
	local pc = 0
	for p in prods do
		for _, h in workspace:GetPartBoundsInBox(p.CFrame, p.Size - Vector3.new(0.15, 0.15, 0.15), op) do if prods[h] and h ~= p then pc += 1 end end
	end
	table.insert(out, "produits qui se chevauchent : " .. pc / 2)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { m }
	local leaks = 0
	for _, x in { -36, -24, 0, 24, 36 } do for _, z in { -30, 0, 30, 60, 69 } do for _, y in { 3, 16 } do
		for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0) } do
			local wd = base:VectorToWorldSpace(d) * 150
			local r = workspace:Raycast(base * Vector3.new(x, y, z), wd, rp); local g = 0
			while r and (r.Instance.Name == "Bounds" or r.Instance.Transparency >= 1) and g < 20 do
				g += 1; r = workspace:Raycast(r.Position + wd.Unit * 0.05, wd, rp)
			end
			if not r then leaks += 1 end
		end
	end end end
	table.insert(out, "fuites : " .. leaks)
	local gs = m:FindFirstChild("GuardSpawn", true)
	local hb = {}
	for _, h in workspace:GetPartBoundsInBox(gs.WorldCFrame * CFrame.new(0, 3, 0), Vector3.new(4, 5, 4), op) do
		if h.Name ~= "Bounds" then table.insert(hb, h.Name) end
	end
	table.insert(out, "GuardSpawn : " .. (#hb == 0 and "libre" or table.concat(hb, ",")))
	return table.concat(out, " | ")
end

_G.ClaudeStoreStretch = { apply = apply, CFG = CFG, restore = restore, check = check, addWallShelves = addWallShelves, freeWallSpans = freeWallSpans }
return "ClaudeStoreStretch chargé"
