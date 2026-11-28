--!nocheck
-- Produits des kits en paves separes (Chef de projet, 27/11 : 12 interieurs de 52 000 a 1 363 000 triangles pour un budget de
-- 15 000 ; Clement 27/11 : « Un bloc par article »). Aucune union : 12 triangles par pave, compte exact.
-- Ordre : kit_lib.luau + kit_produits_<zone>.luau (pieces separees ; Banque, SalleDesCoffres et Bijouterie : sauvegarde
-- ServerStorage/MapBackups/2026-11-26_KitsAvantFusion), puis CE script (a la place de kits_blocs.luau et kits_fusion.luau).
-- _G.KITS_SIMPLE_LIST = { "Superette", ... } avant de lancer. Pour chaque produit ENV_* de ServerStorage/Previews/KITS :
--   1. chaque cylindre et chaque boule devient UN pave ;
--   2. le socle plat « Base » (<= 0,12 de haut) est retire ; les contenants (empreinte > 40 % du produit, ou piece longue de
--      plus de 60 % de la largeur : bac, plateau, barre, rail) gardent leur pave tel quel ;
--   3. articles = pieces dont les emprises (x, z) se touchent ;
--      un seul article : ses N plus gros paves tels quels (N = 4 ; l'ecran Neon d'abord) ;
--      plusieurs articles : UN pave par article (boite englobante), a la couleur de l'article et jamais de son support
--        (coussin, socle, tissu...) ; ses ecrans Neon en plus, poses juste devant s'ils sont fins et pris dans le pave ;
--   4. le plus gros pave devient « Base » (PrimaryPart) ; pivot inchange.
-- Bijouterie : _G.KITS_GEMS = true. Chaque joyau (Glass, Reflectance > 0,2) passe en Neon pour etre garde comme un ecran,
-- puis retrouve son verre apres. Memes noms, meme pivot, emprise egale ou plus petite. Aucun script.
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
local SUPPORT = { "Cushion", "Pillow", "Stand", "Tray", "Rack", "Shelf", "Lining", "Bin", "Holder", "Post", "Foot", "Leg" }
local function isSupport(p)
	if p.Material == Enum.Material.Fabric then return true end
	for _, k in SUPPORT do if p.Name:find(k) then return true end end
	return false
end
local function itemColorSrc(piv, parts)
	local cand = {}
	for _, p in parts do if p.Material ~= Enum.Material.Neon and not isSupport(p) then table.insert(cand, p) end end
	if #cand == 0 then for _, p in parts do if p.Material ~= Enum.Material.Neon then table.insert(cand, p) end end end
	if #cand == 0 then cand = parts end
	table.sort(cand, function(a, b) return vol(a) > vol(b) end)
	local big = cand[1]
	local fb = foot(piv, big)
	for i = 2, #cand do
		local q = cand[i]
		if vol(q) >= vol(big) * 0.6 and foot(piv, q) > fb * 1.01 then return q end
	end
	return big
end
local function itemBoxes(piv, parts, m, keep, tag)
	local solid, glow = {}, {}
	for _, p in parts do table.insert(if p.Material == Enum.Material.Neon then glow else solid, p) end
	local slo, shi
	if #solid > 0 then
		local src = itemColorSrc(piv, solid)
		local lo, hi = bboxIn(piv, solid)
		slo, shi = lo, hi
		table.insert(keep, newBox(src, tag, piv, lo, hi, m))
	end
	if #glow > 0 then
		local lo, hi = bboxIn(piv, glow)
		-- ecran fin pris dans le pave : pose juste devant (un joyau epais reste a sa place)
		if slo and (hi.Z - lo.Z) <= 0.03 and lo.Z > slo.Z - 0.004 and hi.Y <= shi.Y + 0.001 and lo.Y >= slo.Y - 0.001 then
			local d = hi.Z - lo.Z lo = Vector3.new(lo.X, lo.Y, slo.Z - 0.006 - d) hi = Vector3.new(hi.X, hi.Y, slo.Z - 0.006)
		end
		table.insert(keep, newBox(glow[1], tag .. "_Glow", piv, lo, hi, m))
	end
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
	local holders, rest = {}, {}
	for _, p in body do
		local lo, hi = bboxIn(piv, { p })
		local long = (hi.X - lo.X) > (mhi.X - mlo.X) * 0.6 and (hi.X - lo.X) > 0.8
		if #body > 2 and p.Material ~= Enum.Material.Neon and ((hi.X - lo.X) * (hi.Z - lo.Z) > mfoot * 0.4 or long) then table.insert(holders, p) else table.insert(rest, p) end
	end
	local boxes = {}
	for i, p in rest do local lo, hi = bboxIn(piv, { p }) boxes[i] = { lo, hi } end
	local parent = {}
	for i = 1, #rest do parent[i] = i end
	local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]] i = parent[i] end return i end
	for i = 1, #rest do
		for j = i + 1, #rest do
			local a, b = boxes[i], boxes[j]
			if a[1].X <= b[2].X + 0.01 and b[1].X <= a[2].X + 0.01 and a[1].Z <= b[2].Z + 0.01 and b[1].Z <= a[2].Z + 0.01 then parent[find(i)] = find(j) end
		end
	end
	local groups, order = {}, {}
	for i, p in rest do
		local r = find(i)
		if not groups[r] then groups[r] = {} table.insert(order, r) end
		table.insert(groups[r], p)
	end
	local keep = {}
	local function largest(list)
		table.sort(list, function(a, b) return vol(a) > vol(b) end)
		local neon
		for _, p in list do if p.Material == Enum.Material.Neon and (not neon or vol(p) > vol(neon)) then neon = p end end
		if neon then table.insert(keep, neon) end
		for _, p in list do if #keep >= N then break end if p ~= neon then table.insert(keep, p) end end
	end
	if #order <= 1 and #holders == 0 then
		largest(body)
	else
		for _, h in holders do table.insert(keep, h) end
		if #order == 1 then
			largest(groups[order[1]])
		else
			for k, r in order do itemBoxes(piv, groups[r], m, keep, "Item" .. k) end
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
	if _G.KITS_GEMS then
		for _, d in st:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Glass and d.Reflectance > 0.2 then
				d:SetAttribute("GemReflect", d.Reflectance) d:SetAttribute("GemTransp", d.Transparency) d.Material = Enum.Material.Neon
			end
		end
	end
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
	if _G.KITS_GEMS then
		for _, d in st:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				d.Material = Enum.Material.Glass d.Reflectance = d:GetAttribute("GemReflect") or 0.35
				d.Transparency = d:GetAttribute("GemTransp") or 0 d.CastShadow = true
			end
			if d:IsA("BasePart") then d:SetAttribute("GemReflect", nil) d:SetAttribute("GemTransp", nil) end
		end
	end
	table.sort(detail)
	table.insert(lines, string.format("%s : %d ronds, %.0f tri/produit | %s", name, rounds, tot / math.max(cnt, 1), table.concat(detail, ", ")))
	task.wait()
end
return table.concat(lines, "\n")
