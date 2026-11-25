--!nocheck
--[[
	verre_porte_v1.luau (Clément, 2026-11-25, test avec Ironix : « la vitre qu'on peut casser a des reflets buggés
	de notre propre boutique »).

	Cause : le verre de la porte (PlotDoor/Window/Leaf_L et Leaf_R/Glass) était le seul de la boutique en matériau
	Glass. Le Glass de Roblox réfracte l'image de l'écran derrière lui : on y voit une copie déformée de l'intérieur
	de la boutique (sol violet, socles). Les 82 autres vitres (Pane_*) sont en SmoothPlastic transparent, sans ce
	défaut. ShatterController copie le verre de la vitre (matériau, couleur, transparence, reflet) pour le creux :
	la copie suit d'elle-même.

	Correction : le verre de la porte et les éclats de WindowFractured passent en SmoothPlastic, Reflectance 0,15,
	comme les Pane_* ; la porte garde sa couleur et sa transparence (0,55, plus sombre que les vitres à 0,65 : elle
	reste distincte, L-217). Aucun nom ne change. Gabarit PLOT_Shop et 6 boutiques du hub.
	À lancer en Edit. Sauvegarde : ServerStorage/MapBackups/2026-11-25_VerrePorte. Relançable.
]]

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local REFLECT = 0.15 -- comme les Pane_*

local shops = { RS.Assets.Plots.PLOT_Shop }
for _, s in workspace.Map.Hub.Shops:GetChildren() do
	if s:IsA("Model") then table.insert(shops, s) end
end

local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_VerrePorte") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_VerrePorte"
	for _, s in shops do
		local door = s:FindFirstChild("PlotDoor")
		if door then
			local c = door:Clone()
			c.Name = s.Name .. ".PlotDoor"
			c.Parent = f
		end
	end
	f.Parent = backups
end

local out = {}
for _, s in shops do
	local door = s:FindFirstChild("PlotDoor")
	local n = 0
	for _, name in { "Window", "WindowFractured" } do
		local w = door and door:FindFirstChild(name)
		if w then
			for _, p in w:GetDescendants() do
				if p:IsA("BasePart") and p.Material == Enum.Material.Glass then
					p.Material = Enum.Material.SmoothPlastic
					p.Reflectance = REFLECT
					n += 1
				end
			end
		end
	end
	table.insert(out, s.Name .. " : " .. n)
end
print("[verre_porte_v1] " .. table.concat(out, ", "))
return table.concat(out, ", ")
