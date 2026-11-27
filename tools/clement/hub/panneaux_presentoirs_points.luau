--!nocheck
-- Points des panneaux d'amélioration des présentoirs (demande de Clément du 27/11 : « les panneaux d'amélioration de
-- la boutique doivent se trouver là où l'amélioration se fera, et pas rester au fond de la boutique tout le temps »).
-- Un Attachment `DisplayUpgradePoint` devant chaque présentoir acheté (DisplaySlot_01 à _20, et _31 à _38 de l'étage),
-- dans l'allée, à côté de sa plaque d'encaissement : x ±13,2 (la plaque CollectPad va de 16,8 à 21,4), même z que la
-- place, au sol, face vers la porte (−z de la boutique), comme le DisplayUpgradePoint d'origine qui reste en place.
-- Chaque point porte l'attribut `ForSlot` (numéro de la place). Le code (UpgradeController) cherche déjà tous les
-- DisplayUpgradePoint de la boutique et prend le plus proche du prochain présentoir verrouillé ; il doit encore les
-- préférer au StageUpgradePoint_n du fond tant que ce présentoir est dans la boutique (ligne de liaison pour Cantin).
-- Où : PlotFloor du gabarit ReplicatedStorage/Assets/Plots/PLOT_Shop et des 6 boutiques Map/Hub/Shops/PLOT_Shop_0n ;
-- places de l'étage : Floor_2/Floor2_A du gabarit seulement (les boutiques du hub n'ont pas de Floor_2 dans Studio,
-- le serveur le copie du gabarit). Les places bonus du gamepass (21 à 24) n'ont pas de panneau d'achat : rien.
-- Deux places à moins de 1,5 stud l'une de l'autre (07 et 09) partagent un point.
-- Avant : PlotFloor et Floor2_A copiés (sans tag) dans ServerStorage/MapBackups/<date>_PointsPanneauxPresentoirs.
-- Relançable : les points qui portent ForSlot sont retirés puis reposés. Aucun script, aucun tag.
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")

local AISLE_X = 13.2
local MERGE = 1.5
local POINT = "DisplayUpgradePoint"

local template = game.ReplicatedStorage.Assets.Plots.PLOT_Shop
local plots = { template }
for i = 1, 6 do
	local p = workspace.Map.Hub.Shops:FindFirstChild(("PLOT_Shop_%02d"):format(i))
	assert(p, "PLOT_Shop_0" .. i .. " introuvable")
	table.insert(plots, p)
end

local rec = CHS:TryBeginRecording("Points des panneaux de présentoirs", { allowNoUndo = true })

local mb = game.ServerStorage.MapBackups
local bname = os.date("%Y-%m-%d") .. "_PointsPanneauxPresentoirs"
local backup = mb:FindFirstChild(bname)
local function save(part, label)
	if backup:FindFirstChild(label) then return end
	local c = part:Clone()
	c.Name = label
	for _, d in c:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	for _, t in CS:GetTags(c) do CS:RemoveTag(c, t) end
	c.Parent = backup
end
if not backup then
	backup = Instance.new("Folder")
	backup.Name = bname
	backup:SetAttribute("Note", "PlotFloor (gabarit et 6 boutiques du hub) et Floor_2/Floor2_A du gabarit avant les DisplayUpgradePoint par présentoir (27/11). Pour revenir : retirer les DisplayUpgradePoint qui portent l'attribut ForSlot.")
	backup.Parent = mb
end

local function clearPoints(part)
	for _, a in part:GetChildren() do
		if a:IsA("Attachment") and a.Name == POINT and a:GetAttribute("ForSlot") ~= nil then a:Destroy() end
	end
end

-- Pose les points des places `first`..`last` de `plot` sur `carrier`, au niveau de son dessus
local function placeRow(plot, carrier, first, last)
	local pv = plot:GetPivot()
	local topY = pv:PointToObjectSpace(carrier.Position + Vector3.new(0, carrier.Size.Y / 2, 0)).Y
	local placed = {}
	for n = first, last do
		local slot
		for _, d in plot:GetDescendants() do
			if d:IsA("Attachment") and d.Name == ("DisplaySlot_%02d"):format(n) then slot = d break end
		end
		if slot then
			local l = pv:PointToObjectSpace(slot.WorldPosition)
			local at = Vector3.new((l.X >= 0 and 1 or -1) * AISLE_X, topY, l.Z)
			local near = false
			for _, q in placed do if (q - at).Magnitude < MERGE then near = true end end
			if not near then
				local a = Instance.new("Attachment")
				a.Name = POINT
				a:SetAttribute("ForSlot", n)
				a.Parent = carrier
				-- face vers la porte : LookVector = −z de la boutique
				a.WorldCFrame = pv * CFrame.new(at)
				table.insert(placed, at)
			end
		end
	end
	return #placed
end

local report = {}
for _, plot in plots do
	local pf = plot:FindFirstChild("PlotFloor")
	assert(pf, plot:GetFullName() .. " sans PlotFloor")
	save(pf, plot.Name .. "_PlotFloor")
	clearPoints(pf)
	local n = placeRow(plot, pf, 1, 20)
	local m = 0
	local f2 = plot:FindFirstChild("Floor_2")
	local floor = f2 and f2:FindFirstChild("Floor2_A")
	if floor then
		save(floor, plot.Name .. "_Floor2_A")
		clearPoints(floor)
		m = placeRow(plot, floor, 31, 38)
	end
	table.insert(report, ("%s : %d points au rez-de-chaussée, %d à l'étage"):format(plot.Name, n, m))
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(report, "\n") .. "\nSauvegarde MapBackups/" .. bname
