--!nocheck
-- Intérieurs à thème des magasins PNJ (repasse qualité du 26/11, validée par Clément) : chaque paire de cubes de
-- rayon (corps Shelf_*_P<n> et couvercle Shelf_*_C<n>) est remplacée par un produit du kit du chef 3D
-- (ServerStorage/Previews/KITS/<Magasin>, construit par tools/clement/kit_produits_<magasin>.luau).
-- Règles de pose du chef 3D (26/11) :
--   1. produit cloné tel quel, sans ScaleTo (PrimaryPart Base, pivot en bas au centre, face avant en −Z) ;
--   2. posé au pied du corps P : PivotTo(CFrame.new(P.X, P.Y − P.Size.Y/2, P.Z) × rotation), puis P et C retirés ;
--   3. −Z vers l'allée (à l'opposé du dos du meuble : Spine pour les gondoles, Back pour les rayons muraux) ;
--   4. on alterne sans mettre deux fois le même côte à côte ; produits hauts sur l'étagère du haut, bas en dessous ;
--      une place sur trois laissée vide pour aérer (SKIP = 3 ; 0 = aucune) ;
--   5. pièces sans collision, toucher ni requête, aucun script ;
--   6. les ShelfSlot ne sont jamais touchés (le code y pose les colis).
-- Les lots longs des rayons muraux (Shelf_*_Lot) reçoivent un produit long (LOT_TALL ou LOT_LOW). Les bouteilles du frigo (FridgeItem) sont retirées
-- dans les magasins où elles n'ont rien à faire (REMOVE_FRIDGE_ITEMS) : le frigo reste, vide, comme une vitrine.
-- Les produits vont dans <Magasin>/Interior/Products. Avant : tout l'Interior copié (sans tag) dans
-- ServerStorage/MapBackups/<date>_Interieur_<Magasin>. Relançable : une relance retire Products et remet les cubes et
-- les bouteilles depuis cette copie avant de reposer.
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play), un magasin à la fois : changer STORE, rien d'autre.
-- Le kit est lu dans le dossier de MapBackups que donne KIT_FROM (versions validées), à défaut dans ServerStorage/Previews/KITS/<Magasin> (produits ENV_Z<n>_<Magasin>_<Nom>, tous fusionnés) : les
-- produits de plus de 2 studs de long sont les « longs » des lots, les autres les « courts ». Les 4 courts les plus hauts
-- vont sur l'étagère du haut (TALL), les 4 plus bas en dessous (LOW) ; le plus haut des deux longs va dans les lots
-- de LOT_MIN_H de haut ou plus. Bijouterie posée le 26/11 (v1348) ; les 11 autres après la planche validée par Clément.
-- Les 12 magasins : STORE_Z1_Superette, STORE_Z1_Kiosque, STORE_Z2_Confiserie, STORE_Z2_MagasinDeJouets,
-- STORE_Z3_Electronique, STORE_Z3_JeuxVideo, STORE_Z4_Bijouterie, STORE_Z4_Horlogerie, STORE_Z5_GalerieDArt,
-- STORE_Z5_Antiquaire, STORE_Z6_Banque, STORE_Z6_SalleDesCoffres.

local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")

local STORE = "STORE_Z4_Bijouterie"
-- Une place sur SKIP laissée vide ; magasins au-dessus du budget de triangles : une sur deux, lots longs compris
-- (Clément, 27/11 : « Une sur deux vide »). Les autres gardent une sur trois, et leurs lots sont tous posés.
-- 27/11, Clément : « On remet comme avant les boutiques » : plus aucun magasin en une sur deux (mécanisme gardé, vide).
local SKIP_BY_STORE = {}
local SKIP = SKIP_BY_STORE[STORE] or 3
local SKIP_LOTS = SKIP_BY_STORE[STORE] ~= nil
local LOT_MIN_H = 1.1
-- Les bouteilles du frigo ne restent que dans les magasins où elles ont leur place
local KEEP_FRIDGE = { STORE_Z1_Superette = true, STORE_Z1_Kiosque = true }
local REMOVE_FRIDGE_ITEMS = not KEEP_FRIDGE[STORE]

local shortName = STORE:gsub("^STORE_Z%d_", "")
local zone = STORE:match("^STORE_Z(%d)_")
-- Kits validés par Clément (27/11, « On remet comme avant les boutiques ») : les versions fondues d'avant le travail
-- sur les triangles, gardées dans MapBackups. Previews/KITS contient les versions en blocs, rangées, non posées.
local KIT_FROM = {
	Banque = "2026-11-27_KitsAvantBlocs", Electronique = "2026-11-27_KitsAvantBlocs", JeuxVideo = "2026-11-27_KitsAvantBlocs",
	Confiserie = "2026-11-27_KitsAvantBlocs", Antiquaire = "2026-11-27_KitsAvantBlocs",
	Superette = "2026-11-27_KitsAvantSimple", Kiosque = "2026-11-27_KitsAvantSimple", MagasinDeJouets = "2026-11-27_KitsAvantSimple",
	Horlogerie = "2026-11-27_KitsAvantSimple", GalerieDArt = "2026-11-27_KitsAvantSimple", SalleDesCoffres = "2026-11-27_KitsAvantSimple",
	Bijouterie = "2026-11-27_KitsAvantSimple",
}
local kitRoot = KIT_FROM[shortName] and game.ServerStorage.MapBackups:FindFirstChild(KIT_FROM[shortName]) or game.ServerStorage.Previews.KITS
local KITS = kitRoot and kitRoot:FindFirstChild(shortName)
assert(KITS, "kit introuvable : " .. (KIT_FROM[shortName] or "Previews/KITS") .. "/" .. shortName)
local K = "ENV_Z" .. zone .. "_" .. shortName .. "_"
local shorts, longs = {}, {}
for _, m in KITS:GetChildren() do
	if m:IsA("Model") and m.Name:sub(1, #K) == K then
		local _, sz = m:GetBoundingBox()
		local entry = { name = m.Name:sub(#K + 1), h = sz.Y }
		if math.max(sz.X, sz.Z) > 2 then table.insert(longs, entry) else table.insert(shorts, entry) end
	end
end
table.sort(shorts, function(a, b) return a.h > b.h end)
table.sort(longs, function(a, b) return a.h > b.h end)
local TALL, LOW = {}, {}
for i, e in shorts do table.insert(i <= math.ceil(#shorts / 2) and TALL or LOW, e.name) end
-- Lots longs des rayons muraux (Shelf_*_Lot, 2,39 à 3,06 de long) : un produit long par lot, grand axe le long du
-- rayon. Lot de LOT_MIN_H de haut ou plus : LOT_TALL ; sinon LOT_LOW. Sans produit long, les lots restent en cubes.
local LOT_TALL = longs[1] and longs[1].name
local LOT_LOW = (longs[2] and longs[2].name) or LOT_TALL
assert(#TALL > 0 and #LOW > 0, "kit incomplet : " .. #shorts .. " produits courts")

local store
for _, z in workspace.Map:GetChildren() do store = store or z:FindFirstChild(STORE) end
assert(store, STORE .. " introuvable dans Workspace/Map")
assert(KITS, "dossier de kits introuvable")
local int = store:FindFirstChild("Interior")

local rec = CHS:TryBeginRecording("Intérieur à thème " .. STORE, { allowNoUndo = true })

local function isCube(n)
	if not n:match("^Shelf_") then return nil end
	return (n:match("_P%d*$") and "P") or (n:match("_C%d*$") and "C") or (LOT_TALL and n:match("_Lot%d*$") and "Lot") or nil
end

-- Sauvegarde (une fois par jour) ; relance : on repart des cubes de la sauvegarde
local mb = game.ServerStorage.MapBackups
local bname = os.date("%Y-%m-%d") .. "_Interieur_" .. STORE:gsub("^STORE_", "")
local b = mb:FindFirstChild(bname)
if not b and int:FindFirstChild("Products") then
	-- déjà posé un autre jour : on repart de la sauvegarde la plus récente (jamais d'une copie sans cubes)
	local suffix = "_Interieur_" .. STORE:gsub("^STORE_", "")
	for _, f in mb:GetChildren() do
		if f.Name:sub(-#suffix) == suffix and f:FindFirstChild("Interior") and (not b or f.Name > b.Name) then b = f end
	end
	assert(b, "Products déjà posés mais aucune sauvegarde " .. suffix .. " dans MapBackups")
end
if not b then
	b = Instance.new("Folder")
	b.Name = bname
	b:SetAttribute("Note", "Interior de " .. STORE .. " avant les produits du kit (repasse du 26/11), tags retirés de la copie. Pour revenir : supprimer Interior/Products et remettre les pièces Shelf_*_P*, Shelf_*_C* et FridgeItem de cette copie.")
	local c = int:Clone()
	for _, d in c:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	c.Parent = b
	b.Parent = mb
elseif int:FindFirstChild("Products") then
	int.Products:Destroy()
	-- les cubes portent souvent le même nom : on retire ceux qui resteraient, puis on les remet tous depuis la copie
	for _, p in int:GetChildren() do
		if isCube(p.Name) or p.Name:match("^FridgeItem") then p:Destroy() end
	end
	for _, p in b.Interior:GetChildren() do
		if isCube(p.Name) or p.Name:match("^FridgeItem") then p:Clone().Parent = int end
	end
end

local products = Instance.new("Model")
products.Name = "Products"

local function frontDir(unit, p)
	local back = int:FindFirstChild(unit .. "_Spine") or int:FindFirstChild(unit .. "_Back")
	if not back then return Vector3.new(1, 0, 0) end
	local d = p.Position - back.Position
	if math.abs(d.X) >= math.abs(d.Z) then return Vector3.new(d.X >= 0 and 1 or -1, 0, 0) end
	return Vector3.new(0, 0, d.Z >= 0 and 1 or -1)
end

-- Corps P de chaque meuble, rangés par étagère (hauteur) puis le long du rayon
local bodies, topY = {}, {}
for _, p in int:GetChildren() do
	if p:IsA("BasePart") and isCube(p.Name) == "P" then
		local unit = p.Name:match("^(Shelf_%w+)_")
		if unit then
			bodies[unit] = bodies[unit] or {}
			table.insert(bodies[unit], p)
			topY[unit] = math.max(topY[unit] or -math.huge, p.Position.Y)
		end
	end
end

local placed, removed = 0, 0
for unit, list in bodies do
	table.sort(list, function(a, c)
		if math.abs(a.Position.Y - c.Position.Y) > 0.3 then return a.Position.Y > c.Position.Y end
		if math.abs(a.Position.X - c.Position.X) > 0.3 then return a.Position.X < c.Position.X end
		return a.Position.Z < c.Position.Z
	end)
	local i, n, last = 0, 0, nil
	for _, p in list do
		i += 1
		local tall = p.Position.Y >= topY[unit] - 0.3
		local pool = tall and TALL or LOW
		local skip = SKIP > 0 and (i % SKIP == 0)
		if not skip then
			-- une sur deux : on compte les places posées, sinon seuls 2 produits sur 4 sortiraient ; une sur trois :
			-- compte d'origine, pour garder les magasins déjà validés identiques à la relance
			n += 1
			local k = SKIP_LOTS and n or i
			local pick = pool[(k - 1) % #pool + 1]
			if pick == last then pick = pool[k % #pool + 1] end
			last = pick
			local kit = KITS:FindFirstChild(K .. pick)
			if kit then
				local m = kit:Clone()
				local dir = frontDir(unit, p)
				local foot = Vector3.new(p.Position.X, p.Position.Y - p.Size.Y / 2, p.Position.Z)
				m:PivotTo(CFrame.lookAt(foot, foot + dir)) -- −Z (LookVector) vers l'allée
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanTouch = false
						d.CanQuery = false
					elseif d:IsA("LuaSourceContainer") then
						d:Destroy()
					end
				end
				m.Parent = products
				placed += 1
			end
		else
			last = nil
		end
	end
end

-- Lots longs : un produit long par lot, posé au pied du lot, face vers l'allée (son X suit alors le rayon) ;
-- avec SKIP_LOTS, un lot sur SKIP reste vide, compté rayon par rayon dans l'ordre haut → bas puis le long du rayon
local lots = {}
for _, p in int:GetChildren() do
	if p:IsA("BasePart") and isCube(p.Name) == "Lot" then table.insert(lots, p) end
end
table.sort(lots, function(a, c)
	local ua, uc = a.Name:match("^(Shelf_%w+)_") or "", c.Name:match("^(Shelf_%w+)_") or ""
	if ua ~= uc then return ua < uc end
	if math.abs(a.Position.Y - c.Position.Y) > 0.3 then return a.Position.Y > c.Position.Y end
	if math.abs(a.Position.X - c.Position.X) > 0.3 then return a.Position.X < c.Position.X end
	return a.Position.Z < c.Position.Z
end)
local lotIndex = {}
for _, p in lots do
	do
		local unit = p.Name:match("^(Shelf_%w+)_")
		local kit = KITS:FindFirstChild(K .. ((p.Size.Y >= LOT_MIN_H) and LOT_TALL or LOT_LOW))
		local skipLot = false
		if unit and SKIP_LOTS then
			lotIndex[unit] = (lotIndex[unit] or 0) + 1
			skipLot = lotIndex[unit] % SKIP == 0
		end
		if unit and kit and not skipLot then
			local m = kit:Clone()
			local dir = frontDir(unit, p)
			local foot = Vector3.new(p.Position.X, p.Position.Y - p.Size.Y / 2, p.Position.Z)
			m:PivotTo(CFrame.lookAt(foot, foot + dir))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				elseif d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
			m.Parent = products
			placed += 1
		end
	end
end

-- Retrait des cubes P et C (jamais un ShelfSlot ni une pièce qui en porte un) et des bouteilles du frigo
for _, p in int:GetChildren() do
	local hasSlot = false
	for _, d in p:GetDescendants() do if d.Name:match("^ShelfSlot_") then hasSlot = true end end
	if not hasSlot and not p.Name:match("^ShelfSlot_") and (isCube(p.Name) or (REMOVE_FRIDGE_ITEMS and p.Name:match("^FridgeItem"))) then
		p:Destroy()
		removed += 1
	end
end

products.Parent = int
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _, d in products:GetDescendants() do if d:IsA("BasePart") then np += 1 end end
local slots = 0 for _, d in store:GetDescendants() do if d.Name:match("^ShelfSlot_") then slots += 1 end end
return ("%s : %d pièces retirées (cubes P/C et bouteilles), %d produits posés (%d pièces), %d ShelfSlot ; sauvegarde MapBackups/%s"):format(STORE, removed, placed, np, slots, bname)
