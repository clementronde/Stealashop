-- BB_ShopInfo lisible de loin (demande de Clément, 2026-11-25 : « on ne voit plus les UI au-dessus des boutiques »).
-- Avant : 19 × 7.5 studs (taille purement en studs) : énorme de près (976 px à 15 studs sur PC), illisible de loin
-- (52 × 20 px à 100 studs sur téléphone).
-- Après : taille mixte studs + pixels, même rapport (2,53) : identique à 40 studs sur PC, plus petite de près,
-- bien plus grande de loin.
--   15 studs  PC 725 × 284   téléphone 364 × 142
--   40 studs  PC 372 × 145   téléphone 236 × 92
--   100 studs PC 244 × 96    téléphone 190 × 74
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_BB_ShopInfo_Taille. Le code (PvPController) copie le modèle
-- tel quel, tailles comprises : rien à changer côté code pour la taille.

local ui = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("UI")
local bb = ui:WaitForChild("BB_ShopInfo") :: BillboardGui

local backups = game:GetService("ServerStorage"):FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_BB_ShopInfo_Taille") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_BB_ShopInfo_Taille"
	bb:Clone().Parent = f
	f.Parent = backups
end

bb.Size = UDim2.new(11, 160, 4.3, 63)
bb:SetAttribute("SizeNote", "Studs + pixels (2026-11-25) : même taille qu'avant à 40 studs, plus petit de près, lisible de loin")
return "BB_ShopInfo : " .. tostring(bb.Size)
