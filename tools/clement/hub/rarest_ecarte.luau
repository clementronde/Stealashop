-- Socle du plus rare (RarestDisplay, « RAREST PULL ») écarté de la façade (Clément, 2026-11-24 : « écarte le Rarest Pull des
-- boutiques, il est trop proche du mur de la vitre »). À lancer dans Studio (MCP execute_luau, mode Edit), après
-- tools/clement/grande_boutique_v1.luau si celui-ci est relancé. Idempotent : pose le socle à z = -53 dans le repère de
-- chaque boutique (dos à 7,8 studs de la façade au lieu de 1,3), x, hauteur et rotation inchangés, sur le gabarit
-- ReplicatedStorage/Assets/Plots/PLOT_Shop et sur les 6 boutiques du hub. Le code retrouve le socle par son nom et lit
-- ses points LabelPoint et ItemPoint (VfxController) : rien à changer chez Ironix. Ancienne position :
-- ServerStorage/MapBackups/2026-11-24_RarestEcarte (attributs).
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Z_TARGET = -53
local bk = SS.MapBackups
local NAME = "2026-11-24_RarestEcarte"
if not bk:FindFirstChild(NAME) then
	local f = Instance.new("Folder"); f.Name = NAME
	f:SetAttribute("Note", "RarestDisplay avant d'être avancé à z -53 (repère de la boutique) : position locale dans les attributs.")
	f.Parent = bk
end
local save = bk[NAME]
local out = {}
local list = { RS.Assets.Plots.PLOT_Shop }
for _, m in workspace.Map.Hub.Shops:GetChildren() do if m:IsA("Model") and m:GetAttribute("PlotIndex") then table.insert(list, m) end end
for _, shop in list do
	local rar = shop:FindFirstChild("RarestDisplay")
	if rar then
		local pv = shop:GetPivot()
		local l = pv:ToObjectSpace(rar:GetPivot())
		if save:GetAttribute(shop.Name .. "_Local") == nil then save:SetAttribute(shop.Name .. "_Local", l) end
		local target = CFrame.new(l.X, l.Y, Z_TARGET) * (l - l.Position)
		rar:PivotTo(pv * target)
		table.insert(out, string.format("%s : z %.1f -> %.1f", shop:GetFullName():gsub("^Workspace%.Map%.Hub%.Shops%.", ""), l.Z, Z_TARGET))
	end
end
return table.concat(out, "\n")
