--!nocheck
-- zone_showcase.luau : la vitrine des magasins PNJ mise en avant, zone par zone (Clément, 2026-11-12 ; essai validé en
-- zone 1, « parfait, beaucoup plus clair »). Remplace zone1_showcase.luau. Mode Edit, relançable : une zone déjà
-- traitée (attribut Showcase sur Map/Zone_n) n'est plus touchée.
-- Ordre après une reconstruction : script de la zone → corridor_widen.luau → trees_replace.luau → ce script.
-- `_G.ShowcaseZones = { 2, 3 }` avant de lancer : seulement ces zones (sinon les 6).
-- `_G.ShowcaseDry = true` : rien ne bouge, le script dit ce qu'il ferait.
--
-- Pour chaque zone :
--  0) sauvegarde : ServerStorage/Assets/MapBackup_Z<n>_<date-heure> (Map/Zone_n et Greybox/Corridor/Zone_n, sans tags),
--     avec un dossier Removed où va tout ce qui est retiré (rien n'est supprimé) ;
--  1) trottoir élargi de W vers la chaussée : bordure, marquages du bord et décor du bord suivent, passages piétons
--     coupés à la nouvelle bordure, chaussée du greybox ±(52,5 − W) ; magasins avancés de ADV (attribut StoreAdvance) ;
--     trottoir dégagé devant les magasins (x de leur façade) : tout le petit décor posé sur le trottoir est rangé ;
--  2) tons neutres sur les façades voisines et le fond (Calm de la table) ; couleur d'origine dans ShowcaseColor ;
--     les magasins PNJ et les monuments gardent leurs couleurs ;
--  3) cadre de la vitrine (Facade/Frame_T, _B, _L, _R) en néon et lumière dirigée (STORE_*/Showcase/SpotPart) ;
--  4) fond plus simple : décor de la table Stash rangé, effets d'ambiance éteints (Off) ou moitié moins denses (Half) ;
--  5) repère au sol : tapis clair et deux chevrons vers la vitrine (STORE_*/Showcase/Mat, Chevron_*).
-- Aucun script, aucun tag ajouté, aucun nom du contrat 10.4 touché.

local W, ADV = 6, 6
local NEON_C = Color3.fromRGB(255, 232, 150)
local MAT_C, CHEVRON_C = Color3.fromRGB(255, 240, 190), Color3.fromRGB(255, 196, 40)
local DRY = _G.ShowcaseDry == true

-- Street : dossiers de la rue (trottoirs, décor du trottoir). Calm : chemins (depuis Map/Zone_n) des façades voisines et
-- du fond à passer en tons neutres. Keep : noms gardés sur le trottoir, même devant un magasin. Stash : chemins rangés
-- (fond plus simple). Off / Half : dossiers dont les ParticleEmitter sont éteints / à moitié.
local ZONES = {
	[1] = {
		Street = { "Street_Zone1" },
		Calm = { "Street_Zone1/Facades", "Neighborhood_Zone1/Buildings" },
		Keep = { "^WelcomeSign", "^TownMap", "^FlowerBed" },
		Stash = { "Neighborhood_Zone1/WaterTower" },
		Off = { "Street_Zone1/Ambience" },
	},
	[2] = { -- Londres : Big Ben (ClockTowers), la grande roue et le bus à impériale restent
		Street = { "Street_Londres" },
		Calm = { "Street_Londres/Buildings", "Street_Londres/Houses" },
		Off = { "Street_Londres/Weather" },
	},
	[3] = { -- Tokyo : temple, torii, cerisiers et distributeurs restent ; les 2 fils de fête plantés devant les
		-- magasins (x 257 et 326) partent avec leurs poteaux
		Street = { "Street_Tokyo" },
		Calm = { "Street_Tokyo/City", "Street_Tokyo/Houses" },
		StashMatch = { Props = { "^Festival%a*_257", "^Festival%a*_326" } },
	},
	[4] = { -- Los Angeles : palmiers hors des façades, enseignes et StarTower restent
		Street = { "Street_LosAngeles" },
		Calm = { "Street_LosAngeles/Boutiques", "Street_LosAngeles/Buildings", "Street_LosAngeles/Skyline", "District_LosAngeles/Buildings" },
		Off = { "Street_LosAngeles/Ambience" },
	},
	[5] = { -- Paris : tour Eiffel, dôme doré, kiosque et manège restent ; la neige reste, moins dense
		Street = { "Street_Paris" },
		Calm = { "Street_Paris/Facades", "Street_Paris/District" },
		Half = { "Street_Paris/Weather" },
	},
	[6] = { -- New York : le fond du couloir (tour, horloge) reste
		Street = { "Street_NewYork" },
		Calm = { "Street_NewYork/Buildings", "Street_NewYork/Skyline" },
	},
}
-- Dossiers du trottoir et de la rue où l'on dégage ; les autres (bâtiments, monuments, effets) ne sont jamais dégagés.
local PAVEMENT_GROUPS = { Props = true, Palms = true, Trees = true, Signs = true } -- pas Parking : mur du garage de New York
local NOT_UNITS = { Buildings = true, Houses = true, City = true, Skyline = true, Billboards = true, Boutiques = true, Landmarks = true,
	District = true, Garden = true, Backdrop = true, Land = true, ClockTowers = true, Entrance = true, Weather = true, Ambience = true,
	Gate = true, Facades = true, Parking = true }
-- Sol : bordures, dalles et joints du trottoir, marquages et passages piétons
local KERB = { "^Kerb", "^RedKerb" }
local STRETCH = { "^Pavement_", "^Joint_" } -- s'allongent de W vers la chaussée
local ROWS = { "^Zebra_", "^Crosswalk_", "^Crossing_", "^EntryPaving_", "^EntryMat_", "^ExitMat_" } -- coupés à la bordure
local HALF_ROAD = { "^StopLine" } -- de l'axe à la bordure : raccourcis de W
-- Calm : jamais sur le néon ; les monuments ne sont pas dans Calm
local MONUMENTS = { "ClockTower", "ObservationWheel", "Temple", "Torii", "EiffelTower", "GoldenDome", "StarTower", "EndTower" }

local function match(name, list)
	for _, p in list or {} do
		if name:match(p) then return true end
	end
	return false
end
local function walkPath(root, path)
	local inst = root
	for seg in path:gmatch("[^/]+") do
		inst = inst and inst:FindFirstChild(seg)
	end
	return inst
end
local function sgnOf(inst)
	local z = inst:IsA("Model") and inst:GetPivot().Z or inst.Position.Z
	return z > 0 and 1 or -1
end
local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local h = Vector3.new(
		(math.abs(cf.XVector.X) * s.X + math.abs(cf.YVector.X) * s.Y + math.abs(cf.ZVector.X) * s.Z) / 2,
		(math.abs(cf.XVector.Y) * s.X + math.abs(cf.YVector.Y) * s.Y + math.abs(cf.ZVector.Y) * s.Z) / 2,
		(math.abs(cf.XVector.Z) * s.X + math.abs(cf.YVector.Z) * s.Y + math.abs(cf.ZVector.Z) * s.Z) / 2)
	return cf.Position - h, cf.Position + h
end
-- Emprise au sol (pièces dont le bas est à moins de 1,5 du sol), en |z|, et étendue en x et en hauteur
local function footprint(u)
	local zin, zout, x0, x1, top = math.huge, -math.huge, math.huge, -math.huge, -math.huge
	local any = false
	for _, d in (u:IsA("BasePart") and { u } or u:GetDescendants()) do
		if d:IsA("BasePart") then
			local a, b = aabb(d)
			x0, x1, top = math.min(x0, a.X), math.max(x1, b.X), math.max(top, b.Y)
			if a.Y < 1.5 and a.Z * b.Z >= 0 then
				any = true
				zin = math.min(zin, math.min(math.abs(a.Z), math.abs(b.Z)))
				zout = math.max(zout, math.max(math.abs(a.Z), math.abs(b.Z)))
			end
		end
	end
	if not any then -- rien au sol (guirlande accrochée aux réverbères…) : toute la boîte, si elle est d'un seul côté
		local mn, mx = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
		for _, d in (u:IsA("BasePart") and { u } or u:GetDescendants()) do
			if d:IsA("BasePart") then local a, b = aabb(d) mn, mx = mn:Min(a), mx:Max(b) end
		end
		if mn.Z * mx.Z > 0 then
			any = true
			zin, zout = math.min(math.abs(mn.Z), math.abs(mx.Z)), math.max(math.abs(mn.Z), math.abs(mx.Z))
		end
	end
	return any, zin, zout, x0, x1, top
end

local function processZone(n)
	local cfg = ZONES[n]
	local Z = workspace.Map:FindFirstChild("Zone_" .. n)
	local GZ = workspace.Greybox.Corridor:FindFirstChild("Zone_" .. n)
	if not cfg or not Z or not GZ then return "Zone " .. n .. " : introuvable" end
	if Z:GetAttribute("Showcase") then return "Zone " .. n .. " : déjà faite" end
	local log = { moved = 0, stretched = 0, cut = 0, cleared = {}, calm = 0, stores = 0, stash = {}, fx = {} }

	-- 0) sauvegarde
	local removed
	if not DRY then
		local t = os.date("!*t")
		local stamp = string.format("%04d-%02d-%02d_%02dh%02d", t.year, t.month, t.day, (t.hour + 1) % 24, t.min)
		local bk = Instance.new("Folder")
		bk.Name = "MapBackup_Z" .. n .. "_" .. stamp
		bk:SetAttribute("Source", "Workspace/Map/Zone_" .. n .. " + Workspace/Greybox/Corridor/Zone_" .. n)
		local function strip(r)
			for _, d in r:GetDescendants() do for _, tg in d:GetTags() do d:RemoveTag(tg) end end
			for _, tg in r:GetTags() do r:RemoveTag(tg) end
		end
		local zc = Z:Clone() strip(zc) zc.Parent = bk
		task.wait()
		local gc = GZ:Clone() gc.Name = "Greybox_Zone_" .. n strip(gc) gc.Parent = bk
		removed = Instance.new("Folder") removed.Name = "Removed" removed.Parent = bk
		bk.Parent = game.ServerStorage.Assets
		log.backup = bk.Name
	end
	local function stash(inst, list)
		table.insert(list, inst.Name)
		if DRY then return end
		inst:SetAttribute("Path", inst:GetFullName())
		for _, d in inst:GetDescendants() do for _, tg in d:GetTags() do d:RemoveTag(tg) end end
		for _, tg in inst:GetTags() do inst:RemoveTag(tg) end
		inst.Parent = removed
	end
	local function shift(inst, dz)
		log.moved += 1
		if DRY then return end
		if inst:IsA("Model") then inst:PivotTo(inst:GetPivot() + Vector3.new(0, 0, dz)) else inst.CFrame = inst.CFrame + Vector3.new(0, 0, dz) end
	end
	local function grow(p, dsize, dcenter) -- en z du monde (pièces à plat, non tournées en z)
		log.stretched += 1
		if DRY then return end
		local axis = math.abs(p.CFrame.ZVector.Z) > 0.9 and "Z" or "X"
		local s = p.Size
		p.Size = axis == "Z" and Vector3.new(s.X, s.Y, s.Z + dsize) or Vector3.new(s.X + dsize, s.Y, s.Z)
		p.CFrame = p.CFrame + Vector3.new(0, 0, dcenter)
	end

	-- façade des magasins (même x des deux côtés de la rue)
	local stores = {}
	local F0, F1 = math.huge, -math.huge
	for _, s in Z:GetChildren() do
		if s:IsA("Model") and s.Name:match("^STORE_") then
			table.insert(stores, s)
			local cf, sz = s:GetBoundingBox()
			F0, F1 = math.min(F0, cf.X - sz.X / 2), math.max(F1, cf.X + sz.X / 2)
		end
	end
	local function inFront(x0, x1) return x1 > F0 + 1 and x0 < F1 - 1 end

	-- 1) trottoir élargi, dégagé, magasins avancés
	local units = {}
	for _, sname in cfg.Street do
		local S = Z:FindFirstChild(sname)
		for _, c in (S and S:GetChildren() or {}) do
			if c.Name == "Ground" then
				for _, g in c:GetChildren() do table.insert(units, { inst = g, ground = true }) end
			elseif PAVEMENT_GROUPS[c.Name] then
				for _, u in c:GetChildren() do table.insert(units, { inst = u }) end
			elseif c:IsA("Model") and not NOT_UNITS[c.Name] and not match(c.Name, MONUMENTS) and c:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(units, { inst = c }) -- objet posé à la racine de la rue (terrasse, tapis rouge…)
			end
		end
	end
	if Z:GetAttribute("PavementWiden") ~= W then
		for _, u in units do
			local inst = u.inst
			local any, zin, zout, x0, x1, top = footprint(inst)
			if not any then continue end
			local sg = sgnOf(inst)
			if u.ground and inst:IsA("BasePart") then
				if match(inst.Name, KERB) then
					shift(inst, -sg * W)
				elseif match(inst.Name, STRETCH) and zin >= 52 then
					grow(inst, W, -sg * W / 2)
				elseif match(inst.Name, ROWS) then
					if zout > 52.5 - W - 0.3 then stash(inst, log.cleared) log.cut += 1 end
				elseif match(inst.Name, HALF_ROAD) and zin < 3 then
					grow(inst, -W, -sg * W / 2)
				elseif top <= 0.15 and zout > 52.5 - W - 1 and zout <= 52.6 then
					shift(inst, -sg * W) -- marquage du bord de la chaussée
				elseif zin >= 52.4 and zout <= 61 then -- décor à plat sur le trottoir (étoiles, bande podotactile…)
					if inFront(x0, x1) and (x1 - x0) < (F1 - F0) * 0.8 then stash(inst, log.cleared)
					elseif zin < 56 then shift(inst, -sg * W) end
				end
			elseif zin >= 52 and zout <= 62 and not match(inst.Name, cfg.Keep) then
				if inFront(x0, x1) then stash(inst, log.cleared)
				elseif zin < 56 then shift(inst, -sg * W) end
			elseif zin < 52.5 and zout > 52.5 - W and zout <= 62 and not match(inst.Name, cfg.Keep) then
				-- posé au bord de la chaussée (véhicule garé…) : il serait sous le nouveau trottoir
				if inFront(x0, x1) then stash(inst, log.cleared) else shift(inst, -sgnOf(inst) * W) end
			end
		end
		if not DRY then
			local G = GZ.Ground
			G.Street.Size = Vector3.new(G.Street.Size.X, G.Street.Size.Y, G.Street.Size.Z - 2 * W)
			for _, nm in { "Side_N", "Side_S" } do
				local p = G:FindFirstChild(nm)
				if p then
					local s = p.Position.Z > 0 and 1 or -1
					p.Size = Vector3.new(p.Size.X, p.Size.Y, p.Size.Z + W)
					p.CFrame = p.CFrame + Vector3.new(0, 0, -s * W / 2)
				end
			end
			Z:SetAttribute("PavementWiden", W)
		end
	end
	for _, st in stores do
		local done = st:GetAttribute("StoreAdvance") or 0
		if done ~= ADV and not DRY then
			st:PivotTo(st:GetPivot() + Vector3.new(0, 0, -sgnOf(st) * (ADV - done)))
			st:SetAttribute("StoreAdvance", ADV)
		end
	end

	-- 2) tons neutres
	local function neutral(c)
		local h, s, v = c:ToHSV()
		return Color3.fromHSV(h, s * 0.18, 0.6 + v * 0.32)
	end
	for _, path in cfg.Calm or {} do
		local root = walkPath(Z, path)
		for _, d in (root and root:GetDescendants() or {}) do
			local mon = false
			local a = d.Parent
			while a and a ~= Z do if match(a.Name, MONUMENTS) then mon = true break end a = a.Parent end
			if mon then continue end
			if d:IsA("BasePart") and d.Material ~= Enum.Material.Neon and d:GetAttribute("ShowcaseColor") == nil then
				log.calm += 1
				if not DRY then d:SetAttribute("ShowcaseColor", d.Color) d.Color = neutral(d.Color) end
			elseif (d:IsA("TextLabel") or d:IsA("Frame")) and d:GetAttribute("ShowcaseColor") == nil and not DRY then
				d:SetAttribute("ShowcaseColor", d.BackgroundColor3)
				d.BackgroundColor3 = neutral(d.BackgroundColor3)
				if d:IsA("TextLabel") then d.TextColor3 = neutral(d.TextColor3) end
			end
		end
	end

	-- 3) et 5) vitrine : cadre néon, lumière dirigée, tapis et chevrons
	local function part(parent, name, size, cf, color)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	for _, st in stores do
		if st:FindFirstChild("Showcase") or DRY then
			if DRY then log.stores += 1 end
			continue
		end
		local win = st.Window
		local sg = sgnOf(st)
		local front = math.abs(win.Position.Z) - win.Size.Z / 2
		for _, nm in { "Frame_T", "Frame_B", "Frame_L", "Frame_R" } do
			local f = st:FindFirstChild("Facade") and st.Facade:FindFirstChild(nm)
			if f then
				f:SetAttribute("ShowcaseColor", f.Color)
				f:SetAttribute("ShowcaseMaterial", f.Material.Name)
				f.Material = Enum.Material.Neon
				f.Color = NEON_C
			end
		end
		local sc = Instance.new("Model")
		sc.Name = "Showcase"
		local x, ytop = win.Position.X, win.Position.Y + win.Size.Y / 2
		local from = Vector3.new(x, ytop + 1.2, sg * (front - 3.5))
		local to = Vector3.new(x, win.Position.Y, sg * front)
		local spot = part(sc, "SpotPart", Vector3.new(0.4, 0.4, 0.4), CFrame.lookAt(from, to), NEON_C)
		spot.Transparency = 1
		local L = Instance.new("SpotLight")
		L.Face, L.Angle, L.Range, L.Brightness, L.Color, L.Shadows = Enum.NormalId.Front, 80, 18, 3, NEON_C, false
		L.Parent = spot
		local y = 0.45 + 0.025
		local matZ0, matZ1 = 52.5 - W + 1.2, front - 0.9
		local mz = sg * (matZ0 + matZ1) / 2
		part(sc, "Mat", Vector3.new(win.Size.X - 2, 0.05, matZ1 - matZ0), CFrame.new(x, y, mz), MAT_C)
		for i, d in { 1.6, -1.4 } do
			local cz = mz + sg * d
			for _, side in { -1, 1 } do
				part(sc, "Chevron_" .. i, Vector3.new(4.2, 0.06, 0.8),
					CFrame.new(x + side * 1.45, y + 0.01, cz) * CFrame.Angles(0, math.rad(side * sg * 35), 0), CHEVRON_C)
			end
		end
		sc.Parent = st
		log.stores += 1
	end

	-- 4) fond plus simple
	for _, path in cfg.Stash or {} do
		local inst = walkPath(Z, path)
		if inst then stash(inst, log.stash) end
	end
	for group, pats in cfg.StashMatch or {} do
		for _, sname in cfg.Street do
			local g = walkPath(Z, sname .. "/" .. group)
			for _, c in (g and g:GetChildren() or {}) do
				if match(c.Name, pats) then stash(c, log.stash) end
			end
		end
	end
	for _, kind in { "Off", "Half" } do
		for _, path in cfg[kind] or {} do
			local root = walkPath(Z, path)
			for _, d in (root and root:GetDescendants() or {}) do
				if d:IsA("ParticleEmitter") and d:GetAttribute("ShowcaseRate") == nil then
					table.insert(log.fx, d.Parent.Name .. (kind == "Off" and " éteint" or " ×0,5"))
					if not DRY then
						d:SetAttribute("ShowcaseRate", d.Rate)
						if kind == "Off" then d.Enabled = false else d.Rate = d.Rate * 0.5 end
					end
				end
			end
		end
	end
	if not DRY then Z:SetAttribute("Showcase", true) end

	return string.format("Zone %d%s : %d déplacés, %d allongés, %d rangés devant les magasins (%s), %d pièces en tons neutres, %d vitrines, fond : %s%s",
		n, log.backup and (" (sauvegarde " .. log.backup .. ")") or "", log.moved, log.stretched, #log.cleared,
		table.concat(log.cleared, ", ", 1, math.min(#log.cleared, 40)), log.calm, log.stores,
		#log.stash > 0 and table.concat(log.stash, ", ") or "rien de rangé", #log.fx > 0 and ("; effets " .. table.concat(log.fx, ", ")) or "")
end

-- zone 1 faite à la main avec zone1_showcase.luau : marquée faite si ses vitrines sont déjà là
local z1 = workspace.Map:FindFirstChild("Zone_1")
if z1 and not z1:GetAttribute("Showcase") and z1:FindFirstChild("STORE_Z1_Superette") and z1.STORE_Z1_Superette:FindFirstChild("Showcase") and not DRY then
	z1:SetAttribute("Showcase", true)
end
local out = {}
for _, n in (_G.ShowcaseZones or { 1, 2, 3, 4, 5, 6 }) do
	table.insert(out, processZone(n))
	task.wait()
end
return (DRY and "ESSAI (rien n'a bougé)\n" or "") .. table.concat(out, "\n")
