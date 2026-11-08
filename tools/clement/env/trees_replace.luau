--!nocheck
-- Nouveaux arbres de la map (demandes de Clément du 2026-11-07 et 08) : tous les arbres remplacés par ceux du pack
-- « Yasu's Stylized Tree Pack » (Creator Store, importé par Clément, aucun script), feuillage teinté selon la zone.
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relançable.
--  1) range le pack : Workspace/Yasu's_Stylized_Tree_Pack → ServerStorage/Assets/Env (tel quel) ;
--  2) gabarits : les arbres du pack sous le budget de 1 500 triangles (MOD-028 ; comptes lus sur les étiquettes du
--     pack) : Tree_01 à _05 et Tree_12 à _18. Pied de chaque arbre = pivot de son tronc (posé par l'auteur au niveau
--     du sol, au centre du dessus du socle ; les racines descendent dessous et restent sous le sol) ;
--  3) remplace chaque arbre de Workspace/Map : modèles Tree_*, BigTree_*, Poplar_*, Sakura*_*, BoulevardTree_*,
--     YardTree_*. Les palmiers (Palm_*, palmiers de toit RoofPalm_<n>_*) ne sont PAS des arbres du pack : on n'y touche
--     pas (demande de Clément, 2026-11-08). Garde le pied (bac, terre, grille, fosse, mousse, pétales au sol, puits) et
--     le modèle conteneur (même nom, même place). Prend l'arbre du pack à la silhouette la plus proche (tiré du nom
--     parmi les 5 plus proches), à la hauteur de l'ancien (26 studs au plus), **proportions du pack gardées** (jamais
--     resserré en largeur : Clément trouvait les arbres serrés), orientation tirée du nom. Pièces renommées Trunk et Canopy ;
--  4) teinte du feuillage (SurfaceAppearance.Color du Canopy) selon la zone : TINTS ; le tronc garde la teinte du pack ;
--  5) range l'ancien arbre tel quel dans ServerStorage/_ARBRES_REMPLACES (attribut Path = chemin d'origine) : une
--     relance repart de là, et on peut tout remettre.
-- Les scripts des zones (tools/clement/zones/*) et du hub reconstruisent leurs anciens arbres : relancer ce script
-- après eux. Aucun script, aucun tag, aucun attribut du contrat.

local SS = game:GetService("ServerStorage")
local rgb = Color3.fromRGB
local out = {}

local PACK_NAME = "Yasu's_Stylized_Tree_Pack"
local KEEP_TREES = { 1, 2, 3, 4, 5, 12, 13, 14, 15, 16, 17, 18 } -- <= 1 500 triangles
local TINTS = { -- teinte du feuillage par zone (le pack : 93, 107, 28)
	Hub = rgb(110, 170, 50),
	Zone_1 = rgb(120, 165, 45),
	Zone_2 = rgb(70, 125, 50),
	Zone_3 = rgb(255, 150, 195), -- Tokyo : cerisiers
	Zone_4 = rgb(165, 120, 230), -- Los Angeles : jacarandas
	Zone_5 = rgb(225, 236, 242), -- Paris : givre et neige
}
local MAX_H, MAX_W = 26, 1.8

local function folderAt(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end

-- 1) Pack -----------------------------------------------------------------------------------------------------------
local env = folderAt(folderAt(SS, "Assets"), "Env")
local inWorkspace = workspace:FindFirstChild(PACK_NAME)
if inWorkspace then
	local old = env:FindFirstChild(PACK_NAME)
	if old then old:Destroy() end
	inWorkspace.Parent = env
	table.insert(out, "Pack rangé : Workspace → ServerStorage/Assets/Env/" .. PACK_NAME)
end
local pack = env:FindFirstChild(PACK_NAME)
assert(pack, "pack d'arbres introuvable (Workspace ou ServerStorage/Assets/Env/" .. PACK_NAME .. ")")
local trees = pack:FindFirstChild("Models_Trees")
local models = trees and trees:FindFirstChild("Models")
assert(models, "structure du pack inattendue (Models_Trees/Models)")

-- 2) Gabarits --------------------------------------------------------------------------------------------------------
local TEMPLATES = {}
for _, k in KEEP_TREES do
	local m = models:FindFirstChild(string.format("Tree_%02d", k))
	if m then
		local trunk, canopy
		for _, p in m:GetChildren() do
			if p:IsA("MeshPart") and p.Name:match("^Trunk") then trunk = p end
			if p:IsA("MeshPart") and p.Name:match("^Canopy") then canopy = p end
		end
		if trunk and canopy then
			local cf, size = m:GetBoundingBox()
			local base = trunk:GetPivot().Position
			local tilted = false
			for _, p in { trunk, canopy } do
				if math.abs(p.CFrame.UpVector.Y) < 0.999 then tilted = true end
			end
			table.insert(TEMPLATES, { name = m.Name, trunk = trunk, canopy = canopy, base = base, tilted = tilted,
				height = (cf.Y + size.Y / 2) - base.Y, width = math.max(size.X, size.Z) })
		end
	end
end
assert(#TEMPLATES > 0, "aucun arbre gabarit trouvé dans le pack")

-- 3) Arbres de la map ------------------------------------------------------------------------------------------------
local map = workspace:FindFirstChild("Map")
assert(map, "Workspace/Map introuvable")
local stash = folderAt(SS, "_ARBRES_REMPLACES")
local PATTERNS = { "^Tree_", "^BigTree_", "^Poplar_", "^SakuraBig_", "^Sakura_", "^BoulevardTree_", "^YardTree_" } -- pas les palmiers
local REPLACE_ROOF_PALMS = false -- palmiers de toit gardés tels quels
local KEEP = { "Planter", "Soil", "Grate", "Pit", "Moss", "Well", "Base", "Pot" }
local NEW_PARTS = { Trunk = "MeshPart", Canopy = "MeshPart" }

local function isTreeModel(m)
	if not m:IsA("Model") then return false end
	for _, p in PATTERNS do if m.Name:match(p) then return true end end
	return false
end
local function zoneOf(inst)
	local z = inst
	while z.Parent and z.Parent ~= map do z = z.Parent end
	return z.Name
end
local function hash(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end
	return h
end
local function isNewPart(p) return NEW_PARTS[p.Name] ~= nil and p.ClassName == NEW_PARTS[p.Name] end
-- Boîte d'une pièce dans les axes du monde (les troncs cylindriques sont couchés sur leur axe X)
local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local h = Vector3.new(
		(math.abs(cf.XVector.X) * s.X + math.abs(cf.YVector.X) * s.Y + math.abs(cf.ZVector.X) * s.Z) / 2,
		(math.abs(cf.XVector.Y) * s.X + math.abs(cf.YVector.Y) * s.Y + math.abs(cf.ZVector.Y) * s.Z) / 2,
		(math.abs(cf.XVector.Z) * s.X + math.abs(cf.YVector.Z) * s.Y + math.abs(cf.ZVector.Z) * s.Z) / 2)
	return cf.Position - h, cf.Position + h
end
local function keepPart(p, baseY)
	for _, k in KEEP do if p.Name:find(k) then return true end end
	local _, top = aabb(p)
	return top.Y < baseY + 1.2 -- décor au sol (pétales…)
end
-- Mesure d'un arbre d'origine (liste de pièces) : pied du tronc, hauteur et largeur de ce qui sera retiré
local function measure(parts)
	local trunk, trunkBottom
	for _, p in parts do
		if p.Name:find("Trunk") then
			local bottom = aabb(p)
			if not trunk or bottom.Y < trunkBottom then trunk, trunkBottom = p, bottom.Y end
		end
	end
	if not trunk then return nil end
	local baseY = trunkBottom
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	local removed = {}
	for _, p in parts do
		if not keepPart(p, baseY) then
			table.insert(removed, p)
			local a, b = aabb(p)
			mn = mn:Min(a)
			mx = mx:Max(b)
		end
	end
	return {
		base = Vector3.new(trunk.Position.X, baseY, trunk.Position.Z),
		height = mx.Y - baseY,
		width = math.max(mx.X - mn.X, mx.Z - mn.Z),
		removed = removed,
	}
end
-- Arbre du pack à la silhouette (largeur / hauteur) la plus proche, tiré du nom parmi les 5 plus proches (variété)
local function pick(ratio, seed)
	local list = table.clone(TEMPLATES)
	table.sort(list, function(a, b) return math.abs(a.width / a.height - ratio) < math.abs(b.width / b.height - ratio) end)
	return list[(seed % math.min(5, #list)) + 1]
end
-- Nouvel arbre : tronc et ramure du gabarit, mis à l'échelle, ramure teintée, tourné, posé au pied.
-- hsMul, hMul : resserrement et raccourcissement en plus, pour dégager une façade (1 par défaut)
local function plant(container, info, tpl, zone, seedName, hsMul, hMul)
	local targetH = math.min(info.height, MAX_H) * (hMul or 1)
	local s = targetH / tpl.height
	local hs = hsMul or 1 -- proportions du pack : la largeur suit la hauteur, jamais resserrée seule
	local S = Vector3.new(s * hs, s, s * hs)
	local place = CFrame.new(info.base) * CFrame.Angles(0, math.rad(hash(seedName) % 360), 0)
	for _, p in { tpl.trunk, tpl.canopy } do
		local c = p:Clone()
		c.Name = (p == tpl.trunk) and "Trunk" or "Canopy"
		c.Size = p.Size * S
		c.CFrame = place * CFrame.new((p.Position - tpl.base) * S) * (p.CFrame - p.Position)
		c.Anchored = true
		if c.Name == "Canopy" then
			c.CanCollide = false
			c.CanTouch = false
			c.CanQuery = false
			local sa = c:FindFirstChildWhichIsA("SurfaceAppearance")
			if sa then sa.Color = TINTS[zone] or TINTS.Hub end
		end
		c.Parent = container
	end
	return tpl.name
end

-- Le cœur de la ramure (boîte réduite à 65 % : la ramure est arrondie, le bout des feuilles peut effleurer) touche-t-il
-- un bâtiment (façade, mur, auvent, vitre, toit, arche…) ? Sinon on resserre, puis on raccourcit (arbres de trottoir
-- sous les auvents de LA, cerisiers sous l'avancée d'un toit à Tokyo)
local BUILDING = { "Boutique", "Facade", "UpperFloors", "House", "Terrace", "Building", "Apartment", "STORE_", "Shop_",
	"Tenement", "Bungalow", "BackRow", "Shrine", "Mall", "Kiosk", "Parking", "Tower", "ZoneGate" }
local BUILDING_PART = { "Wall", "Awning", "Facade", "Glass", "Window", "Roof", "Cornice", "Sill", "Pillar", "Pilaster", "Mullion", "Valance" }
local function isBuilding(p)
	if isNewPart(p) then return false end -- un autre arbre neuf
	local a = p.Parent
	while a and a ~= map do -- les pièces d'un autre arbre (bac, grille…) ne comptent pas
		if isTreeModel(a) or a.Name:match("^RoofTree_") then return false end
		a = a.Parent
	end
	for _, k in BUILDING_PART do if p.Name:find(k) then return true end end
	a = p.Parent
	while a and a ~= map do -- modèles de bâtiment seulement (pas les dossiers comme « Buildings »)
		if a:IsA("Model") then
			for _, k in BUILDING do if a.Name:find(k, 1, true) then return true end end
		end
		a = a.Parent
	end
	return false
end
local function clashes(container)
	local canopy
	for _, p in container:GetChildren() do if p.Name == "Canopy" and p:IsA("MeshPart") then canopy = p end end
	if not canopy then return false end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { container }
	for _, h in workspace:GetPartBoundsInBox(canopy.CFrame, canopy.Size * 0.65, op) do
		if h.Transparency < 1 and h:IsDescendantOf(map) and isBuilding(h) then return true end
	end
	return false
end
-- arbre qui touche une façade : on le réduit en entier (largeur et hauteur ensemble), sans le déformer
local TRIES = { { 0.9, 0.9 }, { 0.8, 0.8 }, { 0.7, 0.7 }, { 0.6, 0.6 }, { 0.5, 0.5 }, { 0.42, 0.42 } }

-- Arbres-modèles et palmiers de toit (pièces RoofPalm_<n>_* d'un même parent)
local jobs = {}
for _, d in map:GetDescendants() do
	if isTreeModel(d) then table.insert(jobs, { kind = "model", inst = d, path = d:GetFullName() }) end
end
local roofGroups = {}
for _, d in (REPLACE_ROOF_PALMS and map:GetDescendants() or {}) do
	if d:IsA("BasePart") then
		local n = d.Name:match("^RoofPalm_(%d+)_")
		if n then
			local key = d.Parent:GetFullName() .. "/RoofPalm_" .. n
			roofGroups[key] = roofGroups[key] or { parent = d.Parent, n = n, parts = {} }
			table.insert(roofGroups[key].parts, d)
		end
	end
end
for key, g in roofGroups do table.insert(jobs, { kind = "roof", group = g, path = key }) end
for _, d in (REPLACE_ROOF_PALMS and map:GetDescendants() or {}) do
	if d:IsA("Model") and d.Name:match("^RoofTree_%d+$") then
		table.insert(jobs, { kind = "rooftree", inst = d, path = d.Parent:GetFullName() .. "/RoofPalm_" .. d.Name:match("%d+$") })
	end
end

local stashByPath = {}
for _, s in stash:GetDescendants() do
	local p = s:GetAttribute("Path")
	if p then stashByPath[p] = s end
end
local counts, used, done, skipped = {}, {}, 0, {}
local narrowed, stillClash = 0, {}
for _, job in jobs do
	local zone, container, info
	if job.kind == "model" then
		container = job.inst
		zone = zoneOf(container)
		local already = false
		for _, p in container:GetChildren() do if isNewPart(p) then already = true end end
		local s = stashByPath[job.path]
		if already then
			-- relance : on remet l'arbre d'origine rangé, puis on le refait ; sans ancien rangé, on n'y touche pas
			if not s then continue end
			container:ClearAllChildren()
			for _, c in s:GetChildren() do c:Clone().Parent = container end
		end
		local parts = {}
		for _, p in container:GetDescendants() do if p:IsA("BasePart") then table.insert(parts, p) end end
		info = measure(parts)
		if info then
			if not already then -- arbre d'origine (premier passage, ou reconstruit par le script de sa zone) : on le range
				if s then s:Destroy() end
				local copy = container:Clone()
				copy:SetAttribute("Path", job.path)
				copy.Parent = folderAt(stash, zone)
				stashByPath[job.path] = copy
			end
			for _, p in info.removed do p:Destroy() end
		end
	elseif job.kind == "roof" then
		zone = zoneOf(job.group.parent)
		info = measure(job.group.parts)
		if info then
			local old = stashByPath[job.path]
			if old then old:Destroy() end
			local copy = Instance.new("Model")
			copy.Name = "RoofPalm_" .. job.group.n
			for _, p in job.group.parts do p:Clone().Parent = copy end
			copy:SetAttribute("Path", job.path)
			copy.Parent = folderAt(stash, zone)
			stashByPath[job.path] = copy
			for _, p in info.removed do p:Destroy() end
			container = Instance.new("Model")
			container.Name = "RoofTree_" .. job.group.n
			container.Parent = job.group.parent
		end
	else -- rooftree : relance d'un arbre de toit, refait depuis les pièces d'origine rangées
		container = job.inst
		zone = zoneOf(container)
		local s = stashByPath[job.path]
		if not s then table.insert(skipped, container.Name .. " (pas d'ancien rangé)"); continue end
		local parts = {}
		for _, p in s:GetChildren() do
			local c = p:Clone()
			c.Parent = container.Parent
			table.insert(parts, c)
		end
		for _, p in container:GetChildren() do if isNewPart(p) then p:Destroy() end end
		info = measure(parts)
		if info then for _, p in info.removed do p:Destroy() end end
	end
	if not info or not container then
		table.insert(skipped, job.path .. " (pas de tronc)")
		continue
	end
	if job.kind ~= "model" then -- arbre de toit : la réserve ne garde parfois que le pied du tronc
		info.height = math.max(info.height, 10)
		info.width = math.max(info.width, 6)
	end
	local tpl = pick(info.width / math.max(info.height, 0.1), hash(job.path))
	local name = plant(container, info, tpl, zone, job.path)
	if job.kind == "model" and clashes(container) then
		for _, t in TRIES do
			for _, p in container:GetChildren() do if isNewPart(p) then p:Destroy() end end
			plant(container, info, tpl, zone, job.path, t[1], t[2])
			if not clashes(container) then break end
		end
		narrowed = (narrowed or 0) + 1
		if clashes(container) then table.insert(stillClash, container.Name) end
	end
	used[name] = (used[name] or 0) + 1
	counts[zone] = (counts[zone] or 0) + 1
	done += 1
	if done % 20 == 0 then task.wait() end
end

local zl, ul = {}, {}
for z, n in counts do table.insert(zl, z .. " " .. n) end
for t, n in used do table.insert(ul, t .. "×" .. n) end
table.sort(zl)
table.sort(ul)
table.insert(out, string.format("Arbres remplacés : %d (%s)", done, table.concat(zl, ", ")))
table.insert(out, "Arbres du pack utilisés : " .. table.concat(ul, ", "))
table.insert(out, string.format("Resserrés pour dégager une façade : %d%s", narrowed,
	#stillClash > 0 and (" ; touchent encore : " .. table.concat(stillClash, ", ")) or " ; plus aucun ne touche un bâtiment"))
if #skipped > 0 then table.insert(out, "Sautés : " .. table.concat(skipped, ", ")) end
-- vérification : plus aucune ancienne ramure dans les arbres (les fleurs au sol restent, comme les bacs), aucun
-- script dans la map ni dans le pack
local leftovers, scripts, stashed = 0, 0, 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("MeshPart") and d.Parent and (isTreeModel(d.Parent) or d.Name:match("^RoofPalm"))
		and (d.Name:match("^Foliage") or d.Name:match("^Frond") or d.Name:match("^Crown") or d.Name:match("^Leaves")) then
		leftovers += 1
	end
	if d:IsA("LuaSourceContainer") then scripts += 1 end
end
for _, d in pack:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end
for _, s in stash:GetDescendants() do if s:GetAttribute("Path") then stashed += 1 end end
table.insert(out, string.format("Restes d'anciennes ramures : %d ; scripts (map et pack) : %d ; anciens arbres rangés : %d", leftovers, scripts, stashed))
return table.concat(out, "\n")
