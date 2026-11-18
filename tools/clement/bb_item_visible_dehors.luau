--!nonstrict
-- bb_item_visible_dehors.luau (Clément, 2026-11-18 : « l'UI des items doit être vue de dehors ») : l'étiquette de chaque
-- objet exposé (ReplicatedStorage/Assets/UI/BB_Item) se voit depuis le hub, pour donner envie de braquer.
--   - MaxDistance 60 → 160 studs (on la voyait seulement de près, à l'intérieur ou devant la vitrine).
--   - Taille inchangée (5 studs + 120 px de large, 1,6 stud + 62 px de haut) : la part en px la garde lisible de loin.
--   - Income (« +$5/s ») devient la plus grosse ligne et passe en vert argent #3BE15A ; ItemName, Rarity et Mutation
--     un peu plus petits. Ordre des lignes inchangé (UIListLayout), mêmes noms.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-18_ShopInfo/BB_Item. Peut se relancer, en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local rec = CHS:TryBeginRecording("UI : BB_Item visible depuis le hub, revenu en plus gros")
local ok, err = pcall(function()
	local bb = RS.Assets.UI.BB_Item
	local folder = SS.MapBackups:FindFirstChild("2026-11-18_ShopInfo")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-18_ShopInfo"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild(bb.Name) then
		bb:Clone().Parent = folder
	end
	bb.MaxDistance = 160
	local SIZES = { ItemName = 0.26, Rarity = 0.2, Income = 0.34, Mutation = 0.2 }
	for name, h in SIZES do
		local label = bb:FindFirstChild(name)
		if label then
			label.Size = UDim2.fromScale(1, h)
		end
	end
	bb.Income.TextColor3 = Color3.fromHex("3be15a")
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "BB_Item visible depuis le hub"
