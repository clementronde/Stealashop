--!nonstrict
-- ui_l210_pawnshop.luau (retours du test de Clément du 2026-11-16, L-210) : UI_PawnShop, le receleur.
--   - Dialog centré (au milieu de l'écran, un peu sous le centre pour ne pas cacher le receleur) au lieu d'être collé au
--     bord droit.
--   - Dans chaque choix : même taille de texte sur toutes les lignes (28 px sur PC, 18 sur téléphone) ; ChoiceLabel de
--     0,09 à 0,65 ; Price juste après (0,675, 5 à 15 px après la phrase), aligné à gauche, plus grand (39 px sur PC au
--     lieu de 26), et non plus calé au bord droit.
-- Aucun nom ne change. Sauvegarde dans ServerStorage/MapBackups/2026-11-16_L210/UI_PawnShop. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_PawnShop

local function backup(screen)
	local folder = SS.MapBackups:FindFirstChild("2026-11-16_L210")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-16_L210"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild(screen.Name) then
		local copy = screen:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end
end

local rec = CHS:TryBeginRecording("UI : receleur centré, argent plus près et plus grand (L-210)")
local ok, err = pcall(function()
	backup(gui)
	local dialog = gui.Dialog
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.6)
	-- Rapport fixe : la phrase la plus longue (« Sell the item in my hand », 10,94 fois sa hauteur) remplit sa case à la
	-- même taille que « Nevermind », sur tous les écrans ; au moins 410 × 160 (boutons de 45 px sur téléphone).
	local ratio = dialog:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 2.684
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = dialog
	local limits = dialog:FindFirstChildOfClass("UISizeConstraint")
	if limits then
		limits.MinSize = Vector2.new(410, 160)
	end
	for _, choice in dialog.Choices:GetChildren() do
		if choice:IsA("GuiButton") then
			for _, label in choice:GetChildren() do
				local limit = label:IsA("TextLabel") and label:FindFirstChildOfClass("UITextSizeConstraint")
				if limit then
					limit.MaxTextSize = 60 -- la taille suit la hauteur de la ligne
				end
			end
			local key, label, price = choice:FindFirstChild("KeyLabel"), choice:FindFirstChild("ChoiceLabel"), choice:FindFirstChild("Price")
			if key then
				key.Size = UDim2.fromScale(key.Size.X.Scale, 0.45)
			end
			if label then
				label.Size = UDim2.fromScale(if price then 0.56 else label.Size.X.Scale, 0.45)
			end
			if price then
				price.AnchorPoint = Vector2.new(0, 0.5)
				price.Position = UDim2.fromScale(0.675, 0.5)
				price.Size = UDim2.fromScale(0.325, 0.62)
				price.TextXAlignment = Enum.TextXAlignment.Left
			end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_PawnShop : centré, argent plus près et plus grand"
