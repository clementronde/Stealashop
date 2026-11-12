--!nocheck
-- zone1_showcase.luau : essai « vitrine en avant » sur la zone 1 (Clément, 2026-11-12). Mode Edit, relançable.
-- À lancer après zone1_superette.luau, corridor_widen.luau et trees_replace.luau.
--  0) trottoir élargi de W vers la chaussée (bordure et décor du bord suivent, chaussée du greybox ±(52,5 − W)),
--     magasins avancés de ADV vers la rue (attribut StoreAdvance) ;
--  1) dégage le trottoir devant chaque magasin (x de la façade) : arbres, banc, abribus et son marquage, bornes,
--     poubelles, réverbères et leurs plaques de rue sont rangés (pas supprimés) dans le dossier Removed de la
--     sauvegarde ServerStorage/Assets/MapBackup_Zone1_* la plus récente, sans tags ;
--  2) couleurs neutres autour : petites façades des murets et maisons du quartier désaturées (couleur d'origine gardée
--     dans l'attribut ShowcaseColor) ; les magasins gardent leurs couleurs ;
--  3) vitrine éclairée : cadre de la vitrine (Facade/Frame_T, _B, _L, _R) en néon, lumière dirigée sur la vitrine
--     (STORE_*/Showcase/SpotPart) ;
--  4) fond plus simple : château d'eau rangé, feuilles qui volent (Ambience) éteintes ;
--  5) repère au sol : tapis clair devant la vitrine, deux chevrons vers elle (STORE_*/Showcase/Mat, Chevron_*).
-- Aucun script, aucun tag, aucun nom du contrat 10.4 touché (le cadre garde ses noms).

local Z = workspace.Map.Zone_1
local S = Z.Street_Zone1
local W, ADV = 6, 6
local FRONT_X0, FRONT_X1 = 43.4, 104.6 -- façade des deux magasins
local NEON_C = Color3.fromRGB(255, 232, 150)
local MAT_C, CHEVRON_C = Color3.fromRGB(255, 240, 190), Color3.fromRGB(255, 196, 40)
local out = {}

local function sgnOf(inst)
	local z = inst:IsA("Model") and inst:GetPivot().Z or inst.Position.Z
	return z > 0 and 1 or -1
end
local function shift(inst, dz)
	if inst:IsA("Model") then inst:PivotTo(inst:GetPivot() + Vector3.new(0, 0, dz)) else inst.CFrame = inst.CFrame + Vector3.new(0, 0, dz) end
end
local function box(c)
	if c:IsA("Model") then return c:GetBoundingBox() end
	return c.CFrame, c.Size
end

-- Dossier où ranger ce qui est enlevé
local A = game.ServerStorage:FindFirstChild("Assets")
local backup
for _, c in A:GetChildren() do
	if c.Name:match("^MapBackup_Zone1_") and (not backup or c.Name > backup.Name) then backup = c end
end
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "MapBackup_Zone1_" .. os.date("!%Y-%m-%d")
	backup.Parent = A
end
local removed = backup:FindFirstChild("Removed") or Instance.new("Folder")
removed.Name = "Removed"
removed.Parent = backup
local function stash(inst)
	inst:SetAttribute("Path", inst:GetFullName())
	for _, d in inst:GetDescendants() do for _, t in d:GetTags() do d:RemoveTag(t) end end
	for _, t in inst:GetTags() do inst:RemoveTag(t) end
	inst.Parent = removed
end

-- 0) trottoir élargi, magasins avancés --------------------------------------------------------------------------
if Z:GetAttribute("PavementWiden") ~= W then
	for _, c in S.Ground:GetChildren() do
		local n = c.Name
		if n:match("^Kerb_") or n:match("^EdgeLine_") or n:match("^BusZigZag_") then
			shift(c, -sgnOf(c) * W)
		elseif n:match("^Pavement_") then
			local s = sgnOf(c)
			c.Size = Vector3.new(c.Size.X, c.Size.Y, c.Size.Z + W)
			c.CFrame = c.CFrame + Vector3.new(0, 0, -s * W / 2)
		elseif n:match("^Zebra_") or n:match("^EntryMat_") or n:match("^ExitMat_") then
			if math.abs(c.Position.Z) + c.Size.Z / 2 > 52.5 - W - 0.3 then stash(c) end
		end
	end
	for _, grp in { S.Props, S.Signs } do
		for _, c in grp:GetChildren() do
			local cf, sz = box(c)
			local zin = math.abs(cf.Z) - sz.Z / 2
			local x0, x1 = cf.X - sz.X / 2, cf.X + sz.X / 2
			local kerbSide = c.Name:match("^Lamp_") or c.Name:match("^Hydrant_") or c.Name:match("^TrashBin_") or c.Name:match("^StreetNamePlate_")
			local inFront = x1 > FRONT_X0 and x0 < FRONT_X1 and zin > 45 and not c.Name:match("^FlowerBed") and not c.Name:match("^TownMap") and not c.Name:match("^WelcomeSign")
			if kerbSide or inFront then shift(c, -sgnOf(c) * W) end
		end
	end
	local G = workspace.Greybox.Corridor.Zone_1.Ground
	G.Street.Size = Vector3.new(G.Street.Size.X, G.Street.Size.Y, G.Street.Size.Z - 2 * W)
	for _, n in { "Side_N", "Side_S" } do
		local p = G[n]
		local s = p.Position.Z > 0 and 1 or -1
		p.Size = Vector3.new(p.Size.X, p.Size.Y, p.Size.Z + W)
		p.CFrame = p.CFrame + Vector3.new(0, 0, -s * W / 2)
	end
	Z:SetAttribute("PavementWiden", W)
	table.insert(out, "trottoir élargi de " .. W)
end
for _, st in Z:GetChildren() do
	if st:IsA("Model") and st.Name:match("^STORE_") then
		local done = st:GetAttribute("StoreAdvance") or 0
		if done ~= ADV then
			st:PivotTo(st:GetPivot() + Vector3.new(0, 0, -sgnOf(st) * (ADV - done)))
			st:SetAttribute("StoreAdvance", ADV)
			table.insert(out, st.Name .. " avancé à " .. ADV)
		end
	end
end

-- 1) trottoir dégagé devant les magasins ------------------------------------------------------------------------
local CLEAR = { "^Tree_", "^ParkBench_", "^BusStop", "^Hydrant_", "^TrashBin_", "^Lamp_", "^StreetNamePlate_" }
local nClear = 0
for _, grp in { S.Props, S.Signs } do
	for _, c in grp:GetChildren() do
		local cf, sz = box(c)
		local x0, x1 = cf.X - sz.X / 2, cf.X + sz.X / 2
		if x1 > FRONT_X0 + 1 and x0 < FRONT_X1 - 1 then
			for _, p in CLEAR do
				if c.Name:match(p) then stash(c) nClear += 1 break end
			end
		end
	end
end
for _, c in S.Ground:GetChildren() do
	if c.Name:match("^BusZigZag_") then stash(c) nClear += 1 end
end
if nClear > 0 then table.insert(out, nClear .. " objets du trottoir rangés") end

-- 2) couleurs neutres autour -------------------------------------------------------------------------------------
local function neutral(c)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * 0.18, 0.6 + v * 0.32)
end
local nCol = 0
local function calm(root)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Material ~= Enum.Material.Neon and d:GetAttribute("ShowcaseColor") == nil then
			d:SetAttribute("ShowcaseColor", d.Color)
			d.Color = neutral(d.Color)
			nCol += 1
		elseif (d:IsA("TextLabel") or d:IsA("Frame")) and d:GetAttribute("ShowcaseColor") == nil then
			d:SetAttribute("ShowcaseColor", d.BackgroundColor3)
			d.BackgroundColor3 = neutral(d.BackgroundColor3)
			if d:IsA("TextLabel") then d.TextColor3 = neutral(d.TextColor3) end
		end
	end
end
calm(S.Facades)
calm(Z.Neighborhood_Zone1.Buildings)
if nCol > 0 then table.insert(out, nCol .. " pièces du décor en couleurs neutres") end

-- 3) et 5) vitrine éclairée et repère au sol, dans chaque magasin --------------------------------------------------
local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
for _, st in Z:GetChildren() do
	if st:IsA("Model") and st.Name:match("^STORE_") and not st:FindFirstChild("Showcase") then
		local win = st.Window
		local sg = sgnOf(st)
		local front = math.abs(win.Position.Z) - win.Size.Z / 2 -- face de la vitrine côté rue
		for _, n in { "Frame_T", "Frame_B", "Frame_L", "Frame_R" } do
			local f = st.Facade:FindFirstChild(n)
			if f then
				f:SetAttribute("ShowcaseColor", f.Color)
				f:SetAttribute("ShowcaseMaterial", f.Material.Name)
				f.Material = Enum.Material.Neon
				f.Color = NEON_C
			end
		end
		local sc = Instance.new("Model")
		sc.Name = "Showcase"
		-- lumière dirigée : sous le linteau, vers le milieu de la vitrine
		local x, ytop = win.Position.X, win.Position.Y + win.Size.Y / 2
		local from = Vector3.new(x, ytop + 1.2, sg * (front - 3.5))
		local to = Vector3.new(x, win.Position.Y, sg * front)
		local spot = part(sc, "SpotPart", Vector3.new(0.4, 0.4, 0.4), CFrame.lookAt(from, to), NEON_C)
		spot.Transparency = 1
		local L = Instance.new("SpotLight")
		L.Face = Enum.NormalId.Front
		L.Angle = 80
		L.Range = 18
		L.Brightness = 3
		L.Color = NEON_C
		L.Shadows = false
		L.Parent = spot
		-- tapis et chevrons sur le trottoir, devant la vitrine
		local y = 0.45 + 0.025
		local matZ0, matZ1 = 52.5 - W + 1.2, front - 0.9 -- de la bordure à la vitrine
		local mz = sg * (matZ0 + matZ1) / 2
		part(sc, "Mat", Vector3.new(win.Size.X - 2, 0.05, matZ1 - matZ0), CFrame.new(x, y, mz), MAT_C)
		for i, d in { 1.6, -1.4 } do -- deux chevrons, pointe vers la vitrine
			local cz = mz + sg * d
			for _, side in { -1, 1 } do
				local arm = part(sc, "Chevron_" .. i, Vector3.new(4.2, 0.06, 0.8),
					CFrame.new(x + side * 1.45, y + 0.01, cz) * CFrame.Angles(0, math.rad(side * sg * 35), 0), CHEVRON_C)
				arm.Name = "Chevron_" .. i
			end
		end
		sc.Parent = st
		table.insert(out, st.Name .. " : cadre néon, lumière dirigée, tapis et chevrons")
	end
end

-- 4) fond plus simple ---------------------------------------------------------------------------------------------
local wt = Z.Neighborhood_Zone1:FindFirstChild("WaterTower")
if wt then stash(wt) table.insert(out, "château d'eau rangé") end
for _, d in S:FindFirstChild("Ambience") and S.Ambience:GetDescendants() or {} do
	if d:IsA("ParticleEmitter") and d.Enabled then
		d:SetAttribute("ShowcaseEnabled", true)
		d.Enabled = false
		table.insert(out, "feuilles éteintes : " .. d.Parent.Name)
	end
end

return #out > 0 and table.concat(out, "\n") or "rien à faire : déjà appliqué"
