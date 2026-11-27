--!nocheck
-- Produits des kits a ~40 triangles (Chef de projet, 27/11 : les 12 interieurs depassaient les 15 000 triangles de 3,5 a
-- 90 fois, presque tout venait des produits fondus ; « vise 40 triangles par produit »). Une union de petits paves qui se
-- chevauchent coute encore des centaines de triangles : ici AUCUNE union, des paves separes (12 triangles chacun, compte exact).
-- Ordre : kit_lib.luau + kit_produits_<zone>.luau (pieces encore separees ; pour Banque et SalleDesCoffres, la sauvegarde
-- ServerStorage/MapBackups/2026-11-26_KitsAvantFusion), puis CE script, A LA PLACE de kits_blocs.luau et kits_fusion.luau.
-- _G.KITS_SIMPLE_LIST = { "Superette", ... } avant de lancer. Pour chaque produit ENV_* de ServerStorage/Previews/KITS :
--   1. chaque cylindre et chaque boule devient UN pave (pas de prisme a 8 faces : le budget ne le permet pas) ;
--   2. articles = pieces dont les centres (x, z) sont a moins de 0,1 ;
--      un seul article (sac, boite, peluche...) : ses N plus gros paves tels quels (l'ecran Neon d'abord) ;
--      2 a N articles : un pave par article, a la couleur de son etiquette (piece qui l'entoure et pese >= 60 %) ;
--      plus de N articles (rangees, packs) : le contenant (empreinte > 40 % : bac, plateau) garde son pave, puis chaque ligne
--        d'articles (meme z) est coupee en segments de couleur, dans la limite de N paves ;
--   3. le socle plat « Base » (<= 0,12 de haut) est retire ; le plus gros pave devient « Base » (PrimaryPart), pivot inchange.
-- N = 4 par defaut : 48 triangles au plus par produit (quelques rangees a ecrans 60 a 72). Memes noms de produits, meme
-- pivot, emprise egale ou plus petite. Aucun script. Fait le 27/11 sur les 12 magasins. Bijouterie : avant de lancer, chaque
-- joyau (Glass, Reflectance > 0,2) passe en Neon pour etre garde en priorite comme un ecran, puis retrouve son verre apres.
local kits = game:GetService("ServerStorage").Previews.KITS
local function vol(p) return p.Size.X * p.Size.Y * p.Size.Z end
local function bboxIn(piv, parts)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in parts do
		local cf, s = piv:ToObjectSpace(p.CFrame), p.Size / 2
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			local w = cf * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z)
			lo, hi = lo:Min(w), hi:Max(w)
		end end end
	end
	return lo, hi
end
local function newBox(src, name, piv, lo, hi, parent, color)
	local b = Instance.new("Part")
	b.Name = name b.Size = (hi - lo):Max(Vector3.new(0.02, 0.02, 0.02)) b.CFrame = piv * CFrame.new((lo + hi) / 2)
	b.Color = color or src.Color b.Material = src.Material b.MaterialVariant = src.MaterialVariant
	b.Reflectance = src.Reflectance b.Transparency = src.Transparency b.CastShadow = src.CastShadow
	b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery = true, false, false, false
	b.TopSurface, b.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	b.Parent = parent
	return b
end
local function foot(piv, p) local lo, hi = bboxIn(piv, { p }) return (hi.X - lo.X) * (hi.Z - lo.Z) end
local function itemColorSrc(piv, parts)
	table.sort(parts, function(a, b) return vol(a) > vol(b) end)
	local big = parts[1]
	local fb = foot(piv, big)
	for i = 2, #parts do
		local q = parts[i]
		if vol(q) >= vol(big) * 0.6 and foot(piv, q) > fb * 1.01 then return q end
	end
	return big
end
local function dominant(piv, its)
	local count, firstSrc = {}, nil
	for _, it in its do
		local src = itemColorSrc(piv, it.parts)
		firstSrc = firstSrc or src
		local k = src.Color:ToHex()
		count[k] = (count[k] or 0) + 1
	end
	local best, bn = nil, -1
	for k, n in count do if n > bn then best, bn = k, n end end
	return Color3.fromHex(best), firstSrc
end
local function block1(st)
	local n = 0
	for _, d in st:GetDescendants() do
		if d:IsA("Part") and (d.Shape == Enum.PartType.Cylinder or d.Shape == Enum.PartType.Ball) then
			local s = d.Size
			local size = if d.Shape == Enum.PartType.Cylinder then Vector3.new(s.X, math.min(s.Y, s.Z) * 0.88, math.min(s.Y, s.Z) * 0.88)
				else Vector3.one * math.min(s.X, s.Y, s.Z) * 0.82
			local b = newBox(d, d.Name, CFrame.new(), Vector3.zero, Vector3.zero, d.Parent)
			b.Size, b.CFrame = size, d.CFrame
			d:Destroy()
			n += 1
		end
	end
	return n
end
local function simplify(m, N)
	local piv = m:GetPivot()
	local all = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then if d.Transparency >= 1 then d:Destroy() else table.insert(all, d) end end
	end
	local base = m:FindFirstChild("Base")
	local plate = base and base:IsA("BasePart") and base.Size.Y <= 0.12 and #all > 1
	local body = {}
	for _, p in all do if not (plate and p == base) then table.insert(body, p) end end
	local mlo, mhi = bboxIn(piv, body)
	local mfoot = (mhi.X - mlo.X) * (mhi.Z - mlo.Z)
	local items = {}
	for _, p in body do
		local c = piv:PointToObjectSpace(p.Position)
		local found
		for _, it in items do if math.abs(it.x - c.X) < 0.1 and math.abs(it.z - c.Z) < 0.1 then found = it break end end
		if not found then found = { x = c.X, z = c.Z, parts = {} } table.insert(items, found) end
		table.insert(found.parts, p)
	end
	local keep = {}
	if #items == 1 or #body <= N then
		local neon
		for _, p in body do if p.Material == Enum.Material.Neon and (not neon or vol(p) > vol(neon)) then neon = p end end
		table.sort(body, function(a, b) return vol(a) > vol(b) end)
		if neon then table.insert(keep, neon) end
		for _, p in body do if #keep >= N then break end if p ~= neon then table.insert(keep, p) end end
	elseif #items <= N then
		for i, it in items do
			local src = itemColorSrc(piv, it.parts)
			local lo, hi = bboxIn(piv, it.parts)
			table.insert(keep, newBox(src, "Item" .. i, piv, lo, hi, m))
		end
	else
		local rest = {}
		for _, it in items do
			local lo, hi = bboxIn(piv, it.parts)
			if (hi.X - lo.X) * (hi.Z - lo.Z) > mfoot * 0.4 and #keep < N - 1 then
				table.insert(keep, newBox(itemColorSrc(piv, it.parts), "Holder" .. (#keep + 1), piv, lo, hi, m))
			else
				table.insert(rest, it)
			end
		end
		local lines = {}
		for _, it in rest do
			local found
			for _, L in lines do if math.abs(L.z - it.z) < 0.12 then found = L break end end
			if not found then found = { z = it.z, items = {} } table.insert(lines, found) end
			table.insert(found.items, it)
		end
		local budget = math.max(1, N - #keep)
		if #lines > budget then lines = { { z = 0, items = rest } } end
		local per = math.max(1, math.floor(budget / #lines))
		for li, L in lines do
			table.sort(L.items, function(a, b) return a.x < b.x end)
			local segs = math.min(per, #L.items)
			for s = 1, segs do
				local i0 = math.floor((s - 1) * #L.items / segs) + 1
				local i1 = math.floor(s * #L.items / segs)
				local its, parts, glow = {}, {}, {}
				for i = i0, i1 do
					table.insert(its, L.items[i])
					for _, p in L.items[i].parts do table.insert(if p.Material == Enum.Material.Neon then glow else parts, p) end
				end
				if #parts > 0 then
					local col, src = dominant(piv, its)
					local lo, hi = bboxIn(piv, parts)
					table.insert(keep, newBox(src, "Line" .. li .. "_" .. s, piv, lo, hi, m, col))
				end
				if #glow > 0 and #keep < N + 1 then local lo, hi = bboxIn(piv, glow) table.insert(keep, newBox(glow[1], "Glow" .. li .. "_" .. s, piv, lo, hi, m)) end
			end
		end
	end
	local set = {}
	for _, p in keep do set[p] = true end
	for _, p in body do if not set[p] then p:Destroy() end end
	for _, p in keep do if p.Parent ~= m then p.Parent = m end end
	if plate then base:Destroy() end
	local main
	for _, p in keep do if p.Material ~= Enum.Material.Neon and (not main or vol(p) > vol(main)) then main = p end end
	main = main or keep[1]
	if main then
		if main.Name ~= "Base" then local other = m:FindFirstChild("Base") if other and other ~= main then other.Name = "Base2" end main.Name = "Base" end
		m.PrimaryPart = main
		main.PivotOffset = main.CFrame:Inverse() * piv
	end
	local n = 0
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	return n * 12
end
local N = _G.KITS_SIMPLE_N or 4
local lines = {}
for _, name in _G.KITS_SIMPLE_LIST or {} do
	local st = kits:FindFirstChild(name)
	if not st then table.insert(lines, name .. " : absent") continue end
	local rounds = block1(st)
	local tot, cnt, detail = 0, 0, {}
	for _, m in st:GetChildren() do
		if m:IsA("Model") then
			local t = simplify(m, N)
			tot += t cnt += 1
			local short = m.Name:gsub("^ENV_Z%d_[^_]+_", "")
			table.insert(detail, short .. " " .. t)
		end
	end
	table.sort(detail)
	table.insert(lines, string.format("%s : %d ronds, %d produits, %.0f tri/produit | %s", name, rounds, cnt, tot / math.max(cnt, 1), table.concat(detail, ", ")))
	task.wait()
end
return table.concat(lines, "\n")
