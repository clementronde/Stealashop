--!nocheck
-- Zone 1 : décor dégagé autour des magasins agrandis (décision de Clément du 2026-11-17 : magasins PNJ de 60 × 72 à
-- 78 × 108, étirés en place par tools/clement/store_stretch.luau). Nouvelle emprise des deux magasins :
-- x 34,4..113,6 ; Superette z 52,4..162,1 ; Kiosque z −162,1..−52,4 ; plancher x 35..113, |z| 54..162.
-- Ce script ne touche à aucun STORE_*. Il range, décale ou raccourcit seulement le décor de la zone 1 qui entre dans
-- cette emprise, et raccourcit les murets du greybox de la zone 1.
-- À lancer dans Studio (mode Edit) après zone1_superette.luau, corridor_widen.luau, trees_replace.luau,
-- zone_showcase.luau et l'étirement des magasins ; puis zone1_ambience.luau (les abeilles vont aux pots des magasins).
-- Relançable : l'attribut StoreStretchFit (sur Map/Zone_1) empêche de refaire le décalage ; tout ce qui est retiré
-- est rangé, sans tags, dans le dossier Removed de ServerStorage/Assets/MapBackup_Z1_StoreFit_<date-heure>.

local Z = workspace.Map.Zone_1
local S, NB = Z.Street_Zone1, Z.Neighborhood_Zone1
local G = workspace.Greybox.Corridor.Zone_1.Ground
local X0, X1 = 34.4, 113.6 -- côtés des magasins
local FRONT, BACK = 52.4, 162.1 -- avant et fond des magasins (|z|)
local FLOOR = 54 -- début du plancher : les dalles du trottoir s'arrêtent là sous la façade
local NB_SHIFT = 36 -- le quartier recule d'autant (le magasin s'est allongé de 36)
local MARK = "StoreStretchFit"
local log = {}

if Z:GetAttribute(MARK) then return "déjà fait" end

-- 0) sauvegarde de la zone avant tout
local t = os.date("!*t")
local bk = Instance.new("Folder")
bk.Name = string.format("MapBackup_Z1_StoreFit_%04d-%02d-%02d_%02dh%02d", t.year, t.month, t.day, (t.hour + 1) % 24, t.min)
local function strip(r)
	for _, d in r:GetDescendants() do for _, tg in d:GetTags() do d:RemoveTag(tg) end end
	for _, tg in r:GetTags() do r:RemoveTag(tg) end
end
local zc = Z:Clone() strip(zc) zc.Parent = bk
local gc = workspace.Greybox.Corridor.Zone_1:Clone() gc.Name = "Greybox_Zone_1" strip(gc) gc.Parent = bk
local removed = Instance.new("Folder") removed.Name = "Removed" removed.Parent = bk
bk.Parent = game.ServerStorage.Assets
table.insert(log, "sauvegarde " .. bk.Name)

local function stash(inst)
	if not inst then return end
	inst:SetAttribute("Path", inst:GetFullName())
	strip(inst)
	inst.Parent = removed
end
local function setX(p, a, b) -- pièce droite : bornes en x
	p.Size = Vector3.new(b - a, p.Size.Y, p.Size.Z)
	p.CFrame = CFrame.new((a + b) / 2, p.Position.Y, p.Position.Z) * (p.CFrame - p.Position)
end
local function setZ(p, a, b) -- pièce droite : bornes en z (a < b)
	p.Size = Vector3.new(p.Size.X, p.Size.Y, b - a)
	p.CFrame = CFrame.new(p.Position.X, p.Position.Y, (a + b) / 2) * (p.CFrame - p.Position)
end

-- 1) murets du greybox : seulement les bouts entre l'arche et le magasin
for _, n in { "SideWall_N1", "SideWall_S1" } do local w = G:FindFirstChild(n) if w then setX(w, 31.5, X0) end end
for _, n in { "SideWall_N2", "SideWall_S2" } do local w = G:FindFirstChild(n) if w then setX(w, X1, 116.5) end end
table.insert(log, "murets raccourcis à x 31,5..34,4 et 113,6..116,5")

-- 2) dans l'emprise : les 4 petites façades, les jardinières et le banc sud sont rangés
local nOut = 0
for _, n in { "Facade_N1_Barber", "Facade_N2_Pizza", "Facade_S1_Books", "Facade_S2_Laundry" } do
	local f = S.Facades:FindFirstChild(n) if f then stash(f) nOut += 1 end
end
for _, n in { "FlowerBed_N2", "FlowerBed_S1", "ParkBench_S2" } do
	local p = S.Props:FindFirstChild(n) if p then stash(p) nOut += 1 end
end
table.insert(log, nOut .. " objets rangés (4 petites façades, 2 jardinières, banc sud)")

-- 3) panneaux de l'entrée : dans la bande entre l'arche et le magasin (x 30..34,4)
for _, n in { "WelcomeSign", "TownMap" } do
	local m = S.Signs:FindFirstChild(n)
	if m then
		local cf, sz = m:GetBoundingBox()
		local dx = (X0 - 0.1) - (cf.X + sz.X / 2)
		if dx < 0 then m:PivotTo(m:GetPivot() + Vector3.new(dx, 0, 0)) table.insert(log, string.format("%s décalé de %.1f en x", n, dx)) end
	end
end

-- 4) dalles du trottoir : sous la façade, elles s'arrêtent au plancher du magasin
local nTile = 0
for _, p in S.Ground:GetChildren() do
	if p.Name:match("^Pavement_") then
		local a, b = p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2
		local s = p.Position.Z > 0 and 1 or -1
		local zin = math.abs(p.Position.Z) - p.Size.Z / 2
		local zout = math.abs(p.Position.Z) + p.Size.Z / 2
		if b > X0 and a < X1 and zout > FLOOR then
			local function shallow(q) -- même dalle, de la bordure au plancher
				if s > 0 then setZ(q, zin, FLOOR) else setZ(q, -FLOOR, -zin) end
			end
			if a < X0 then -- dalle à cheval sur le côté ouest : la part hors du magasin garde toute sa profondeur
				local q = p:Clone() q.Name = p.Name .. "_Front" q.Parent = p.Parent
				setX(p, a, X0) setX(q, X0, b) shallow(q)
			elseif b > X1 then -- côté est
				local q = p:Clone() q.Name = p.Name .. "_Front" q.Parent = p.Parent
				setX(p, X1, b) setX(q, a, X1) shallow(q)
			else
				shallow(p)
			end
			nTile += 1
		end
	end
end
table.insert(log, nTile .. " dalles du trottoir arrêtées au plancher des magasins")

-- 5) quartier : les peupliers des bandes latérales n'ont plus de place ; le reste recule de NB_SHIFT
local nPop, nMove = 0, 0
for _, c in NB.Parks:GetChildren() do
	if c.Name:match("^Poplar_") then stash(c) nPop += 1 end
end
for _, grp in { NB.Buildings, NB.Parks } do
	for _, c in grp:GetChildren() do
		local s = (c:IsA("Model") and c:GetPivot().Z or c.Position.Z) > 0 and 1 or -1
		if c:IsA("Model") then c:PivotTo(c:GetPivot() + Vector3.new(0, 0, s * NB_SHIFT)) else c.CFrame = c.CFrame + Vector3.new(0, 0, s * NB_SHIFT) end
		nMove += 1
	end
end
for _, p in NB.Ground:GetChildren() do
	if p:IsA("BasePart") then
		local s = p.Position.Z > 0 and 1 or -1
		if p.Name:match("^Lawn_") then -- la pelouse garde son bord côté rue et s'allonge vers l'arrière
			local zin = math.abs(p.Position.Z) - p.Size.Z / 2
			local zout = math.abs(p.Position.Z) + p.Size.Z / 2 + NB_SHIFT
			if s > 0 then setZ(p, zin, zout) else setZ(p, -zout, -zin) end
		else
			p.CFrame = p.CFrame + Vector3.new(0, 0, s * NB_SHIFT)
		end
		nMove += 1
	end
end
-- arbres d'origine rangés par trees_replace.luau : ils suivent (sinon une relance replanterait au mauvais endroit)
local st = game.ServerStorage:FindFirstChild("_ARBRES_REMPLACES")
local nStash = 0
for _, m in (st and st:GetDescendants() or {}) do
	local path = m:IsA("Model") and m:GetAttribute("Path")
	if path and path:match("^Workspace%.Map%.Zone_1%.Neighborhood_Zone1%.Parks%.") and not path:match("Poplar_") then
		local s = m:GetPivot().Z > 0 and 1 or -1
		m:PivotTo(m:GetPivot() + Vector3.new(0, 0, s * NB_SHIFT))
		nStash += 1
	end
end
table.insert(log, string.format("%d peupliers rangés ; %d éléments du quartier reculés de %d (pelouses allongées) ; %d arbres rangés par trees_replace suivis", nPop, nMove, NB_SHIFT, nStash))

Z:SetAttribute(MARK, true)
return table.concat(log, "\n")
