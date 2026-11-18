--!nonstrict
-- ui_l218_shop_size.luau (retour de Clément du 2026-11-17 : « le shop et l'index n'ont pas la même taille ») :
-- UI_RobuxShop_v2 et UI_DiamondShop prennent la taille de la fenêtre de UI_Index_v3.
--   L'index : Root 62 % × 54 % de l'écran entier (IgnoreGuiInset), rapport 2,038, fenêtre = 83,7 % de Root, soit une
--   fenêtre de rapport 1,706 (994 × 583 sur 1920 × 1080). Les boutiques sont sous la barre de Roblox (58 px) : leur Root
--   (la fenêtre seule, onglets à l'extérieur) prend 51,9 % × 57,1 % de leur zone, rapport 1,706, centrée au même niveau
--   que l'index (0,493), au moins 495 × 290 px (téléphone), au plus 1360 × 740.
-- Mesuré : 995 × 583 sur PC (index 994 × 583), 761 × 446 à 1618 × 840 (index 773 × 453), 494 × 290 sur téléphone
-- (index 552 × 323, l'index a toute la hauteur) ; onglets dans l'écran, boutons d'au moins 44 px.
-- Sauvegardes dans ServerStorage/MapBackups/2026-11-17_Benchmark (<écran>_avantTailleIndex). Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local SG = game:GetService("StarterGui")

local rec = CHS:TryBeginRecording("UI : boutique Robux et Diamond Shop à la taille de l'index")
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_Benchmark")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-17_Benchmark"
		folder.Parent = SS.MapBackups
	end
	for _, name in { "UI_RobuxShop_v2", "UI_DiamondShop" } do
		local gui = SG[name]
		if not folder:FindFirstChild(name .. "_avantTailleIndex") then
			local copy = gui:Clone()
			copy.Name = name .. "_avantTailleIndex"
			copy.Enabled = false
			copy.Parent = folder
		end
		local root = gui.Root
		root.Size = UDim2.fromScale(0.519, 0.571)
		root.Position = UDim2.new(0.5, -30, 0.493, 0)
		local ratio = root:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1.706
		ratio.AspectType = Enum.AspectType.FitWithinMaxSize
		ratio.DominantAxis = Enum.DominantAxis.Width
		ratio.Parent = root
		local limits = root:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
		limits.MinSize = Vector2.new(495, 290)
		limits.MaxSize = Vector2.new(1360, 740)
		limits.Parent = root
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "boutiques à la taille de l'index"
