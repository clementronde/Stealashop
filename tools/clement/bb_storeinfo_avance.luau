-- Lot C des retours de test du 2026-11-25 (L-072 rouverte) : BB_StoreInfo, le panneau au-dessus des magasins PNJ,
-- entrait dans la façade quand on le regarde de biais depuis la rue (InfoPoint à 0 à 1,4 stud devant la façade).
-- Le panneau avance de 8 studs vers la caméra (StudsOffset en Z, repère de la caméra) : il reste devant le mur sous
-- tous les angles. StoreInfoController garde le StudsOffset du modèle (avec InfoPoint) ou l'ajoute à son décalage de
-- repli (sans InfoPoint) : rien à changer dans le code.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_LotC/BB_StoreInfo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local assets = ReplicatedStorage:FindFirstChild("Assets")
local ui = assets and assets:FindFirstChild("UI")
local bb = ui and ui:FindFirstChild("BB_StoreInfo")
assert(bb and bb:IsA("BillboardGui"), "Assets/UI/BB_StoreInfo introuvable")

local backups = ServerStorage:FindFirstChild("MapBackups")
assert(backups, "MapBackups introuvable")
local folder = backups:FindFirstChild("2026-11-25_LotC")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "2026-11-25_LotC"
	folder.Parent = backups
end
if not folder:FindFirstChild("BB_StoreInfo") then
	bb:Clone().Parent = folder
end

bb.StudsOffset = Vector3.new(0, 0, 8)
print("[bb_storeinfo_avance] fait")
