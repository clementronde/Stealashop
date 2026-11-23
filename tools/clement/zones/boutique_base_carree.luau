--!nocheck
-- Boutique du joueur : base carrée de 48 × 48 au départ (Clément, 2026-11-21, option A).
-- Note : docs/claude/notes/boutique-base-carree-2026-11-21.md
-- À coller dans la barre de commande de Studio (place DEV), en mode Edit. Rejouable : ne refait rien
-- si c'est déjà fait. Aucun script laissé, aucun nom changé.
--
-- Repère du gabarit PLOT_Shop : porte en z −40, avant vers −Z. Le fond du niveau 1 passe de z −16 à z 8.
--  1. Sauvegarde du gabarit et des 6 PLOT_Shop_0n dans ServerStorage/MapBackups/2026-11-21_BoutiqueCarree
--     (tags retirés des copies, gardés dans l'attribut OrigTags, chemin d'origine dans OrigPath).
--  2. Gabarit : les tronçons de Stage_2 entre z −16,5 et z 8 passent dans le niveau 1 (même nom) :
--     PlotFloorExt → Stage_1, FloorTilesExt/* → FloorTiles, Frame/* (côtés) → Stage_1/Frame.
--  3. Gabarit et hub : Stage_1/Frame/Back_L1 et PlotBarrier/Barrier_B1 reculent de 24 studs ;
--     Barrier_L1, Barrier_R1 et Barrier_Lid1 passent de 24 à 48 de long (HideFromStage = 2 gardé).
--  4. Hub : les pièces déplacées en 2 sont copiées dans chaque PLOT_Shop_0n (même pose relative),
--     les pièces Accent prennent la couleur AccentColor de la boutique.

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local tmpl = game.ReplicatedStorage.Assets.Plots.PLOT_Shop
local shops = workspace.Map.Hub.Shops
local SHIFT = 24 -- z −16 → z 8
local Z_MIN, Z_MAX = -16.5, 8.05
local log = {}
local function say(s) table.insert(log, s) end

local function zRange(root: Model, part: BasePart)
	local cf = root:GetPivot():ToObjectSpace(part.CFrame)
	local hz = math.abs(cf:VectorToWorldSpace(part.Size).Z) / 2
	return cf.Z - hz, cf.Z + hz
end

-- 1. Sauvegarde
local backups = SS:FindFirstChild("MapBackups")
if not backups then
	backups = Instance.new("Folder")
	backups.Name = "MapBackups"
	backups.Parent = SS
end
if not backups:FindFirstChild("2026-11-21_BoutiqueCarree") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-21_BoutiqueCarree"
	local list = { tmpl }
	for _, m in shops:GetChildren() do if m.Name:match("^PLOT_Shop_0%d$") then table.insert(list, m) end end
	for _, m in list do
		local c = m:Clone()
		c:SetAttribute("OrigPath", m:GetFullName())
		local tags = CS:GetTags(c)
		if #tags > 0 then c:SetAttribute("OrigTags", table.concat(tags, ",")) end
		for _, d in { c, table.unpack(c:GetDescendants()) } do
			for _, tg in CS:GetTags(d) do CS:RemoveTag(d, tg) end
		end
		c.Parent = f
	end
	f.Parent = backups
	say("sauvegarde : " .. #list .. " modèles")
end

-- 2. Gabarit : tronçons de Stage_2 → niveau 1
local moved = {} -- pièces déplacées dans le gabarit (pour les copier dans le hub)
local s1, s2 = tmpl.Stage_1, tmpl:FindFirstChild("Stage_2")
local targets = {
	FloorTilesExt = tmpl.FloorTiles,
	Frame = s1.Frame,
}
if s2 then
	for _, d in s2:GetDescendants() do
		if d:IsA("BasePart") then
			local z0, z1 = zRange(tmpl, d)
			if z0 >= Z_MIN and z1 <= Z_MAX then
				local dest
				if d.Parent == s2 and d.Name == "PlotFloorExt" then dest = s1
				elseif d.Parent.Parent == s2 then dest = targets[d.Parent.Name] end
				if dest then table.insert(moved, { part = d, dest = dest }) end
			end
		end
	end
	for _, m in moved do m.part.Parent = m.dest end
	say("gabarit : " .. #moved .. " tronçons de Stage_2 passés au niveau 1")
end
-- liste complète des pièces du niveau 1 entre z −16,5 et 8 (déplacées maintenant ou avant)
local ext = {}
for _, root in { s1, tmpl.FloorTiles } do
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Parent.Name ~= "Back_L1" then
			local z0, z1 = zRange(tmpl, d)
			if z0 >= Z_MIN and z1 <= Z_MAX then table.insert(ext, d) end
		end
	end
end

-- 3. Fond du niveau 1 et champ de force (gabarit et hub)
local function moveBack(plot: Model)
	local back = plot.Stage_1.Frame:FindFirstChild("Back_L1")
	local bar = plot.PlotBarrier
	local piv = plot:GetPivot()
	local plinth = back and back:FindFirstChild("Plinth_B")
	if not plinth then say(plot.Name .. " : pas de Back_L1/Plinth_B, rien fait") return false end
	local z = piv:ToObjectSpace(plinth.CFrame).Z
	if z > 0 then return false end -- déjà fait
	local off = piv:VectorToWorldSpace(Vector3.new(0, 0, SHIFT))
	back:PivotTo(back:GetPivot() + off)
	local b = bar:FindFirstChild("Barrier_B1")
	if b then b.CFrame += off end
	for _, n in { "Barrier_L1", "Barrier_R1", "Barrier_Lid1" } do
		local p = bar:FindFirstChild(n)
		if p then
			local local_ = piv:ToObjectSpace(p.CFrame)
			p.Size = Vector3.new(p.Size.X, p.Size.Y, p.Size.Z + SHIFT) -- les 3 sont alignées sur l'axe Z de la boutique
			p.CFrame = piv * (local_ + Vector3.new(0, 0, SHIFT / 2))
		end
	end
	return true
end
if moveBack(tmpl) then say("gabarit : fond du niveau 1 en z 8") end

-- 4. Hub
local tpiv = tmpl:GetPivot()
for _, plot in shops:GetChildren() do
	if plot.Name:match("^PLOT_Shop_0%d$") then
		local done = plot.Stage_1:FindFirstChild("PlotFloorExt") ~= nil
		local n = 0
		if not done then
			local rel = plot:GetPivot() * tpiv:Inverse()
			local accent = plot:GetAttribute("AccentColor")
			for _, src in ext do
				local c = src:Clone()
				for _, s in c:GetDescendants() do if s:IsA("LuaSourceContainer") then s:Destroy() end end
				c.CFrame = rel * src.CFrame
				if accent and c:GetAttribute("Accent") then c.Color = accent end
				local dest = if src.Parent == s1 then plot.Stage_1
					elseif src.Parent == tmpl.FloorTiles then plot.FloorTiles
					else plot.Stage_1.Frame
				c.Parent = dest
				n += 1
			end
		end
		local b = moveBack(plot)
		say(plot.Name .. " : " .. n .. " pièces ajoutées, fond " .. (b and "reculé" or "déjà en z 8"))
	end
end

-- Contrôle : aucun script dans les boutiques
for _, root in { tmpl, table.unpack(shops:GetChildren()) } do
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then say("SCRIPT TROUVÉ : " .. d:GetFullName()) end
	end
end
print(table.concat(log, "\n"))
return table.concat(log, "\n")

-- =====================================================================================================
-- 2e partie (Clément, 2026-11-22 : « Mets le panneau d'amélioration de la boutique au fond de la boutique,
-- écarter le treadmill de la boutique avec son panneau d'amélioration car là c'est trop près »).
-- À lancer après la 1re partie. Rejouable : ne refait rien si c'est déjà fait.
--  a. Sauvegarde : ServerStorage/MapBackups/2026-11-22_PanneauxTapis (gabarit, 6 boutiques, aperçus).
--  b. PlotFloor/StageUpgradePoint (panneau « Display Stands » au niveau 1) : z −18,6 → z 5,6 (au fond du
--     carré, même écart au fond que StageUpgradePoint_2), même orientation (vers la porte).
--  c. Treadmill entier (zone d'usage et Frame/UpgradePoint compris) : 10 studs vers l'avant (−Z).
--  d. Aperçus Edit Workspace/_PREVIEW_UpgradeSigns/PLOT_Shop_0n : Preview_ShopUpgrade et Preview_Treadmill suivent.
do
	local STAGE_POINT_Z = 5.6
	local TREADMILL_SHIFT = -10
	local log2 = {}
	local previews = workspace:FindFirstChild("_PREVIEW_UpgradeSigns")
	local backups2 = game:GetService("ServerStorage"):FindFirstChild("MapBackups")
	if backups2 and not backups2:FindFirstChild("2026-11-22_PanneauxTapis") then
		local f = Instance.new("Folder")
		f.Name = "2026-11-22_PanneauxTapis"
		local list = { tmpl }
		for _, m in shops:GetChildren() do if m.Name:match("^PLOT_Shop_0%d$") then table.insert(list, m) end end
		if previews then table.insert(list, previews) end
		for _, m in list do
			local c = m:Clone()
			c:SetAttribute("OrigPath", m:GetFullName())
			local tags = CS:GetTags(c)
			if #tags > 0 then c:SetAttribute("OrigTags", table.concat(tags, ",")) end
			for _, d in { c, table.unpack(c:GetDescendants()) } do
				for _, tg in CS:GetTags(d) do CS:RemoveTag(d, tg) end
			end
			c.Parent = f
		end
		f.Parent = backups2
		table.insert(log2, "sauvegarde : " .. #list .. " modèles")
	end
	local function apply(plot: Model)
		local piv = plot:GetPivot()
		local floor = plot:FindFirstChild("PlotFloor")
		local point = floor and floor:FindFirstChild("StageUpgradePoint")
		local pv = previews and previews:FindFirstChild(plot.Name)
		if point and point:IsA("Attachment") then
			local here = piv:PointToObjectSpace(point.WorldPosition)
			if math.abs(here.Z - STAGE_POINT_Z) > 0.05 then
				local delta = piv:VectorToWorldSpace(Vector3.new(0, 0, STAGE_POINT_Z - here.Z))
				point.WorldPosition += delta
				local p = pv and pv:FindFirstChild("Preview_ShopUpgrade")
				if p then p:PivotTo(p:GetPivot() + delta) end
				table.insert(log2, plot.Name .. " : StageUpgradePoint au fond")
			end
		end
		local tm = plot:FindFirstChild("Treadmill")
		local frame = tm and tm:FindFirstChild("Frame")
		if frame then
			local z = piv:PointToObjectSpace(frame.Position).Z
			if z > -50 then -- avant : −46 ; après : −56
				local delta = piv:VectorToWorldSpace(Vector3.new(0, 0, TREADMILL_SHIFT))
				tm:PivotTo(tm:GetPivot() + delta)
				local p = pv and pv:FindFirstChild("Preview_Treadmill")
				if p then p:PivotTo(p:GetPivot() + delta) end
				table.insert(log2, plot.Name .. " : tapis avancé de 10")
			end
		end
	end
	apply(tmpl)
	for _, plot in shops:GetChildren() do
		if plot.Name:match("^PLOT_Shop_0%d$") then apply(plot) end
	end
	print(table.concat(log2, "\n"))
end
