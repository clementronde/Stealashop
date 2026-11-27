--!nocheck
-- Range ReplicatedStorage/Assets/Items par zone (demande de Clement du 26/11 : « voir le nombre d'objets par zone et
-- trier »). Le code trouve les ITM_ par FindFirstChild(nom, true) (DisplayService, CarryService, Reveal, ContractChecker
-- par GetDescendants) : les sous-dossiers ne changent rien en jeu. Rangement :
--   Zone_1 .. Zone_6, Secret : les objets du catalogue ACTIF (Config/Items.List : v3 en DEV)
--   Exclusive                : les objets de la caisse exclusive (Items.Exclusives)
--   _Catalogue_v2            : les modeles de l'autre catalogue (Items.OtherAssets ; c'est le catalogue de PROD tant
--                              que Features.ItemsV3 est coupe : ne pas les supprimer)
--   _Hors_catalogue          : tout le reste
-- Sauvegarde legere : ServerStorage/MapBackups/2026-11-26_ItemsParZone garde la liste des noms (tous etaient enfants
-- directs de Assets/Items). RESTORE = true remet tout a plat. Relancable, mode Edit.
local RESTORE = false

local Items = require(game.ReplicatedStorage.Shared.Config.Items)
local folder = game.ReplicatedStorage.Assets.Items

local function sub(name)
	local f = folder:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = folder
	end
	return f
end

if RESTORE then
	local n = 0
	for _, d in folder:GetDescendants() do
		if d.Name:sub(1, 4) == "ITM_" and d.Parent:IsA("Folder") and d.Parent ~= folder and d.Parent:IsDescendantOf(folder) then
			d.Parent = folder
			n += 1
		end
	end
	for _, f in folder:GetChildren() do
		if f:IsA("Folder") and #f:GetChildren() == 0 then
			f:Destroy()
		end
	end
	return "remis a plat : " .. n
end

-- sauvegarde de la liste
local backups = game.ServerStorage:FindFirstChild("MapBackups") or Instance.new("Folder")
backups.Name = "MapBackups"
backups.Parent = game.ServerStorage
if not backups:FindFirstChild("2026-11-26_ItemsParZone") then
	local b = Instance.new("Folder")
	b.Name = "2026-11-26_ItemsParZone"
	local names = {}
	for _, m in folder:GetChildren() do
		if m.Name:sub(1, 4) == "ITM_" then
			table.insert(names, m.Name)
		end
	end
	table.sort(names)
	local v = Instance.new("StringValue")
	v.Name = "EnfantsDirectsDeAssetsItems"
	v.Value = table.concat(names, "\n")
	v.Parent = b
	b.Parent = backups
end

local active, excl = {}, {}
for _, it in Items.List do
	active[it.Asset] = it
end
for _, it in (Items.Exclusives or {}) do
	excl[it.Asset] = true
end
local other = Items.OtherAssets or {}
local counts = {}
for _, m in folder:GetChildren() do
	if m.Name:sub(1, 4) == "ITM_" then
		local dest
		local it = active[m.Name]
		if it then
			dest = if it.Rarity == "Secret" or it.Zone == nil then "Secret" else "Zone_" .. tostring(it.Zone)
		elseif excl[m.Name] then
			dest = "Exclusive"
		elseif other[m.Name] then
			dest = "_Catalogue_v2"
		else
			dest = "_Hors_catalogue"
		end
		m.Parent = sub(dest)
		counts[dest] = (counts[dest] or 0) + 1
	end
end
local out = {}
for k, v in counts do
	table.insert(out, k .. " = " .. v)
end
table.sort(out)
print("[items par zone] " .. table.concat(out, " ; "))
return table.concat(out, "\n")
