--!nocheck
-- Sol des zones : fonctions communes (fiche du chef DA : da-sol-zones.md, 28/11, retour de Clément : « les flaques font
-- un cercle plat, les rues piétonnes sont buggées, les passages piétons aussi »).
-- À charger dans Studio (MCP execute_luau, Edit) ; il ne pose rien lui-même, il remplit _G.SolZones :
--   SolZones.hauteurs(racine)                    trottoirs (Pavement_*) et bordures (Kerb_*) : dessus à 0,48
--   SolZones.passage(parent, xc, haut)           le passage piéton commun : 25 bandes de 9 × 1,8, dessus à +0,03
--   SolZones.marquages(racine, passages, haut)   pointillés et lignes : dessus à +0,03, coupés à 1 stud des passages
--   SolZones.flaque(parent, x, z, w, h, opts)    tache d'eau en cases de 0,5, avec son auréole mouillée
--   SolZones.tache(parent, x, y, z, w, h, opts)  auréole seule (sol mouillé sans eau)
--   SolZones.controle(racines)                   faces de sol superposées à moins de 0,03 → liste
-- Règles (fiche, section 1) : chaussée à 0 ; trottoir et bordure à 0,48 ; toute couche posée dépasse d'au moins 0,03
-- et s'enfonce de 0,05 ; deux couches qui se croisent ne sont jamais au même niveau ; pas de pièce de collision.
-- Les pièces retirées ou coupées sont rangées par l'appelant (SolZones.ranger) dans sa sauvegarde, attribut Path.

local CS = game:GetService("CollectionService")
local SZ = {}
local rgb = Color3.fromHex
SZ.TROTTOIR = 0.48
SZ.BLANC = rgb("f2f0ea")

local function flat(parent, name, x0, x1, z0, z1, top, color, mat, refl)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	local bottom = top - 0.08 -- s'enfonce de 0,05 sous une couche posée à +0,03
	p.Size = Vector3.new(x1 - x0, top - bottom, z1 - z0)
	p.CFrame = CFrame.new((x0 + x1) / 2, (top + bottom) / 2, (z0 + z1) / 2)
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Reflectance = refl or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
SZ.flat = flat

function SZ.ranger(inst, backup)
	inst:SetAttribute("Path", inst:GetFullName())
	for _, d in inst:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	inst.Parent = backup
end

-- 1. hauteurs : dessus à 0,48, le dessous ne bouge pas
function SZ.hauteurs(root)
	local n = 0
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and (p.Name:match("^Pavement") or p.Name:match("^Kerb")) then
			local bottom = p.Position.Y - p.Size.Y / 2
			if math.abs(p.Position.Y + p.Size.Y / 2 - SZ.TROTTOIR) > 0.001 then
				p.Size = Vector3.new(p.Size.X, SZ.TROTTOIR - bottom, p.Size.Z)
				p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, (SZ.TROTTOIR + bottom) / 2, p.Position.Z)
				n += 1
			end
		end
	end
	return n
end

-- 2. le passage piéton commun : 25 bandes de 9 × 1,8, la première et la dernière à 0,6 de la bordure (|z| 46,5)
function SZ.passage(parent, xc, haut, opts)
	opts = opts or {}
	local f = Instance.new("Folder")
	f.Name = opts.nom or "PassagePieton"
	local zEdge = 46.5 - 0.6 - 0.9 -- centre de la bande du bord
	for k = 0, 24 do
		local zc = -zEdge + k * (2 * zEdge / 24)
		local b = flat(f, ("Zebra_%02d"):format(k + 1), xc - 4.5, xc + 4.5, zc - 0.9, zc + 0.9, haut + 0.03, opts.couleur or SZ.BLANC)
		b:SetAttribute("UsureOffset", (k * 7) % 6) -- pour la Texture Sol_Usure (décalage différent par bande)
	end
	f.Parent = parent
	return f
end

-- 3. marquages de chaussée : dessus à +0,03 (la fiche dit +0,02, sous la règle des 0,03 : ils ne croisent plus les
--    bandes, qui sont aussi à +0,03) ; coupés à 1 stud des passages (x des centres) ; ceux en biais qui
--    touchent un passage sont rangés. Rend le nombre de pièces abaissées, coupées et rangées.
local MARKS = { "CentreDash", "CenterDash", "LaneDash", "EdgeLine", "YellowLine", "Diamond", "StopLine", "Dash" }
local function isMark(n) for _, m in MARKS do if n:match("^" .. m) then return true end end return false end
function SZ.marquages(root, passages, haut, backup)
	local low, cut, gone = 0, 0, 0
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and isMark(p.Name) and p.Position.Y < 0.2 then
			local straight = math.abs(p.CFrame.RightVector.X) > 0.999 or math.abs(p.CFrame.RightVector.Z) > 0.999
			local alongX = math.abs(p.CFrame.RightVector.X) > 0.999
			local ex = alongX and p.Size.X / 2 or p.Size.Z / 2
			local ez = alongX and p.Size.Z / 2 or p.Size.X / 2
			if not straight then ex, ez = math.max(p.Size.X, p.Size.Z) / 2, math.max(p.Size.X, p.Size.Z) / 2 end
			local x0, x1 = p.Position.X - ex, p.Position.X + ex
			local hit
			for _, xc in passages do
				if x0 < xc + 5.5 and x1 > xc - 5.5 and math.abs(p.Position.Z) - ez < 46 then hit = xc break end
			end
			if hit and not straight then
				SZ.ranger(p, backup)
				gone += 1
			else
				local top, bottom = haut + 0.03, haut - 0.05
				local sz = p.Size
				p.Size = Vector3.new(sz.X, top - bottom, sz.Z)
				p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, (top + bottom) / 2, p.Position.Z)
				low += 1
				if hit then
					-- garder les morceaux hors de [xc − 5,5 ; xc + 5,5]
					local a, b = hit - 5.5, hit + 5.5
					local pieces = {}
					if x0 < a - 0.2 then table.insert(pieces, { x0, a }) end
					if x1 > b + 0.2 then table.insert(pieces, { b, x1 }) end
					for i, pc in pieces do
						local c = p:Clone()
						c.Name = p.Name .. "_" .. i
						local len = pc[2] - pc[1]
						c.Size = alongX and Vector3.new(len, c.Size.Y, c.Size.Z) or Vector3.new(c.Size.X, c.Size.Y, len)
						c.CFrame = c.CFrame - c.Position + Vector3.new((pc[1] + pc[2]) / 2, c.Position.Y, c.Position.Z)
						c.Parent = p.Parent
					end
					SZ.ranger(p, backup)
					cut += 1
				end
			end
		end
	end
	return low, cut, gone
end

-- 4. flaques : tache irrégulière (3 ou 4 lobes) en cases de 0,5 ; eau à +0,06, auréole d'une case à +0,03 (la fiche
--    dit +0,03 et +0,015 : relevé pour tenir la règle des 0,03 au-dessus du sol) (une
--    deuxième case par endroits) ; cases fusionnées en rectangles. opts : sol (couleur de la chaussée), haut (dessus du
--    sol, 0 par défaut), seed, eau (couleur), reflet (0,35), neon (liste de couleurs pour quelques cases de l'auréole),
--    sansEau (tache mouillée seule).
local CELL = 0.5
local function rects(get, w, h)
	local used, out = {}, {}
	for r = 1, h do for c = 1, w do
		local k = get(r, c)
		if k and not used[r * 1000 + c] then
			local c1 = c
			while c1 + 1 <= w and get(r, c1 + 1) == k and not used[r * 1000 + c1 + 1] do c1 += 1 end
			local r1 = r
			while r1 + 1 <= h do
				local ok = true
				for cc = c, c1 do if get(r1 + 1, cc) ~= k or used[(r1 + 1) * 1000 + cc] then ok = false break end end
				if not ok then break end
				r1 += 1
			end
			for rr = r, r1 do for cc = c, c1 do used[rr * 1000 + cc] = true end end
			table.insert(out, { c0 = c, c1 = c1, r0 = r, r1 = r1, k = k })
		end
	end end
	return out
end
function SZ.flaque(parent, x, z, w, h, opts)
	opts = opts or {}
	local rnd = Random.new(opts.seed or math.floor(x * 7 + z * 13))
	local base = opts.haut or 0
	local sol = opts.sol or rgb("3b3f48")
	local wet = Color3.new(sol.R * 0.75, sol.G * 0.75, sol.B * 0.75)
	local W, H = math.floor(w / CELL) + 4, math.floor(h / CELL) + 4
	local cx, cy = (W + 1) / 2, (H + 1) / 2
	local lobes = rnd:NextInteger(3, 4)
	local ph = rnd:NextNumber(0, math.pi * 2)
	local water = {}
	for r = 1, H do
		water[r] = {}
		for c = 1, W do
			local dx, dy = (c - cx) / ((W - 4) / 2), (r - cy) / ((H - 4) / 2)
			local a = math.atan2(dy, dx)
			local rr = 1 + 0.22 * math.sin(lobes * a + ph) + 0.08 * math.sin(7 * a + ph * 2)
			water[r][c] = (dx * dx + dy * dy) <= rr * rr * 0.95
		end
	end
	local grid = {}
	for r = 1, H do
		grid[r] = {}
		for c = 1, W do
			if water[r][c] and not opts.sansEau then
				grid[r][c] = "e"
			else
				local near = false
				for dr = -1, 1 do for dc = -1, 1 do local row = water[r + dr] if row and row[c + dc] then near = true end end end
				if water[r][c] or near then grid[r][c] = "a"
				else
					local near2 = false
					for dr = -2, 2 do for dc = -2, 2 do local row = water[r + dr] if row and row[c + dc] then near2 = true end end end
					if near2 and rnd:NextNumber() < 0.3 then grid[r][c] = "a" end
				end
			end
		end
	end
	-- quelques cases de reflet néon dans l'auréole (Tokyo)
	if opts.neon then
		for r = 1, H do for c = 1, W do
			if grid[r][c] == "a" and rnd:NextNumber() < 0.18 then grid[r][c] = "n" .. rnd:NextInteger(1, #opts.neon) end
		end end
	end
	local m = Instance.new("Model")
	m.Name = opts.nom or "Flaque"
	local x0, z0 = x - W * CELL / 2, z - H * CELL / 2
	for _, o in rects(function(r, c) return grid[r] and grid[r][c] end, W, H) do
		local ax0, ax1 = x0 + (o.c0 - 1) * CELL, x0 + o.c1 * CELL
		local az0, az1 = z0 + (o.r0 - 1) * CELL, z0 + o.r1 * CELL
		if o.k == "e" then
			flat(m, "Eau", ax0, ax1, az0, az1, base + 0.06, opts.eau or rgb("2b3038"), Enum.Material.SmoothPlastic, opts.reflet or 0.35)
		elseif o.k == "a" then
			flat(m, "Aureole", ax0, ax1, az0, az1, base + 0.03, opts.bord or wet, Enum.Material.SmoothPlastic, 0.1)
		else
			local p = flat(m, "Reflet", ax0, ax1, az0, az1, base + 0.03, opts.neon[tonumber(o.k:sub(2))], Enum.Material.Neon, 0)
			p.Transparency = 0.7
		end
	end
	m:SetAttribute("Diametre", math.min(w, h))
	m.Parent = parent
	return m
end
function SZ.tache(parent, x, z, w, h, opts)
	opts = opts or {}
	opts.sansEau = true
	return SZ.flaque(parent, x, z, w, h, opts)
end

-- 5. contrôle : dessus de sol à moins de 0,03 l'un de l'autre qui se chevauchent (hors magasins PNJ et personnages)
function SZ.controle(roots)
	local flats = {}
	for _, r in roots do
		for _, p in r:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 0.95 and not p:FindFirstAncestorWhichIsA("Humanoid") then
				local a, inStore = p.Parent, false
				while a and a ~= workspace do
					if a.Name:match("^STORE_") or a:FindFirstChildOfClass("Humanoid") then inStore = true break end
					a = a.Parent
				end
				local straight = math.abs(p.CFrame.UpVector.Y) > 0.999
				if not inStore and straight then
					local ex = math.abs(p.CFrame.RightVector.X) * p.Size.X / 2 + math.abs(p.CFrame.LookVector.X) * p.Size.Z / 2
					local ez = math.abs(p.CFrame.RightVector.Z) * p.Size.X / 2 + math.abs(p.CFrame.LookVector.Z) * p.Size.Z / 2
					local top = p.Position.Y + p.Size.Y / 2
					if top < 1.2 and top > -0.5 and p.Size.Y < 2.5 and math.abs(p.Position.Z) < 100 then
						table.insert(flats, { p = p, top = top, x0 = p.Position.X - ex, x1 = p.Position.X + ex, z0 = p.Position.Z - ez, z1 = p.Position.Z + ez })
					end
				end
			end
		end
	end
	local out = {}
	for i = 1, #flats do
		local a = flats[i]
		for j = i + 1, #flats do
			local b = flats[j]
			if math.abs(a.top - b.top) < 0.029 and a.x0 < b.x1 - 0.01 and b.x0 < a.x1 - 0.01 and a.z0 < b.z1 - 0.01 and b.z0 < a.z1 - 0.01 then
				if a.p.Parent ~= b.p.Parent or not (a.p.Parent and a.p.Parent:IsA("Model")) then
					table.insert(out, ("%s (%.3f) ↔ %s (%.3f)"):format(a.p:GetFullName():gsub("Workspace%.Map%.", ""), a.top, b.p:GetFullName():gsub("Workspace%.Map%.", ""), b.top))
				end
			end
		end
	end
	return out
end

_G.SolZones = SZ
return "SolZones chargé"
