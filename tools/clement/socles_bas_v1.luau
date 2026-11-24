--!nocheck
--[[
	socles_bas_v1.luau (Clément, 2026-11-24, validé via le chef 3D : « Tapis et objets »).
	Les présentoirs des objets exposés (DisplayStand_xx, 3 × 1,8 × 3) passent à 1 stud de corps : les objets vont être
	affichés plus grands (taille par rareté, à coder par Ironix), ils doivent rester à hauteur d'yeux.

	Le pied (Foot, FootStep, GoldBand_Low) ne bouge pas ; le corps (le socle lui-même et les GoldEdge) passe de
	1,8 à 1 de haut ; la tête (HeadStep, Head, GoldLip, GoldBand_High) et les attachments DisplaySlot_xx et
	UnboxBench_xx descendent de 0,8 ; la plaque (Plaque) reste au milieu du corps. Aucun nom ne change.
	Cible : gabarit PLOT_Shop (Rayon_01 et Floor_2), PLOT_Shop_Rayons (Rayon_02 à 05) et les 6 boutiques du hub.
	À lancer en Edit. Sauvegarde : ServerStorage/MapBackups/2026-11-24_SoclesBas. Idempotent (attribut LowStand).
]]

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local OLD_H, NEW_H = 1.8, 1.0
local DROP = OLD_H - NEW_H

local function lower(stand: BasePart): boolean
	if stand:GetAttribute("LowStand") then return false end
	local up = stand.CFrame.UpVector
	local b = stand.Position.Y - stand.Size.Y / 2 -- bas du corps
	local t = b + OLD_H
	-- attachments (DisplaySlot, UnboxBench) : sur la tête, descendent de DROP (posés après le socle, qui les entraîne)
	local atts = {}
	for _, a in stand:GetChildren() do
		if a:IsA("Attachment") then atts[a] = a.WorldPosition - Vector3.new(0, DROP, 0) end
	end
	for _, d in stand:GetDescendants() do
		if d:IsA("BasePart") then
			local y0, y1 = d.Position.Y - d.Size.Y / 2, d.Position.Y + d.Size.Y / 2
			if math.abs(d.Size.Y - OLD_H) < 0.05 and math.abs(y0 - b) < 0.1 then
				-- montant sur toute la hauteur du corps (GoldEdge)
				d.Size = Vector3.new(d.Size.X, NEW_H, d.Size.Z)
				d.Position = Vector3.new(d.Position.X, b + NEW_H / 2, d.Position.Z)
			elseif y0 >= t - 0.15 then
				-- tête : descend
				d.Position -= Vector3.new(0, DROP, 0)
			elseif y1 > b + 0.05 and y0 > b - 0.05 then
				-- dans le corps (plaque) : garde sa place relative
				local c = b + (d.Position.Y - b) * NEW_H / OLD_H
				d.Position = Vector3.new(d.Position.X, c, d.Position.Z)
			end
			-- pied : ne bouge pas
		end
	end
	stand.Size = Vector3.new(stand.Size.X, NEW_H, stand.Size.Z)
	stand.CFrame = stand.CFrame - Vector3.new(0, DROP / 2, 0)
	-- les pièces enfants ont été repositionnées à part (CFrame ne les entraîne pas) ; les attachments, si
	for a, p in atts do a.WorldPosition = p end
	stand:SetAttribute("LowStand", true)
	return true
end

local plots = RS.Assets.Plots
local roots = { plots.PLOT_Shop, plots.PLOT_Shop_Rayons }
for _, s in workspace.Map.Hub.Shops:GetChildren() do
	if s:IsA("Model") then table.insert(roots, s) end
end

local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-24_SoclesBas") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-24_SoclesBas"
	for _, r in roots do
		local g = Instance.new("Folder")
		g.Name = r.Name
		for _, d in r:GetDescendants() do
			if d:IsA("BasePart") and d.Name:match("^DisplayStand_%d+$") then
				local c = d:Clone()
				c:SetAttribute("Path", d:GetFullName())
				c.Parent = g
			end
		end
		g.Parent = f
	end
	f.Parent = backups
end

local out = {}
for _, r in roots do
	local n, slotY = 0, nil
	for _, d in r:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^DisplayStand_%d+$") and lower(d) then
			n += 1
			local a = d:FindFirstChild("DisplaySlot_01") or d:FindFirstChildWhichIsA("Attachment")
			if a and not slotY then slotY = a.WorldPosition.Y - r:GetPivot().Position.Y end
		end
	end
	table.insert(out, string.format("%s : %d socles%s", r.Name, n, slotY and string.format(", place à y %.2f", slotY) or ""))
end
print("[socles_bas_v1] " .. table.concat(out, " ; "))
return table.concat(out, "\n")
