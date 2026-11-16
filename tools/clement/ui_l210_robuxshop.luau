--!nonstrict
-- ui_l210_robuxshop.luau (retours du test de Clément du 2026-11-16, L-210) : UI_RobuxShop_v2 plus petite et centrée.
--   - Root ne porte plus que la fenêtre : 65,5 % de la largeur et 72 % de la hauteur de l'écran, comme la boutique de la
--     référence (a2_boutique_pleine_58s.jpg : 1252 × 692 sur 1910 × 1002), centrée (40 px à gauche du milieu, pour que
--     les onglets tiennent à droite sur téléphone), au moins 680 × 300 (téléphone), au plus 1360 × 740 ;
--   - Window et WindowShadow remplissent Root ; Tabs passe à l'extérieur, à droite de la fenêtre, 10 % de sa largeur
--     (onglets de 126 × 110 px sur PC au lieu de 175 × 152) ;
--   - Clip.Watermark des Template de BoostsSection et GamepassesSection vidé : le code ne recopie pas l'icône de l'offre
--     dans le filigrane, toutes les cartes montraient la basket ou le cash du modèle (L-210 : « Open Now : son icône,
--     pas la basket »). Les cartes Preview_* gardent leur filigrane.
-- Aucun nom ne change. Sauvegarde dans ServerStorage/MapBackups/2026-11-16_L210/UI_RobuxShop_v2. À lancer en Edit,
-- après ui_v5_robuxshop_v3_build.luau (qui referait List.Content et Decor). Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_RobuxShop_v2
local root = gui.Root

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

local rec = CHS:TryBeginRecording("UI : boutique Robux plus petite et centrée (L-210)")
local ok, err = pcall(function()
	backup(gui)

	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, -40, 0.47, 0)
	root.Size = UDim2.fromScale(0.655, 0.72)
	local limits = root:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(680, 300)
	limits.MaxSize = Vector2.new(1360, 740)
	limits.Parent = root

	local window, shadow = root.Window, root.WindowShadow
	window.Position = UDim2.fromScale(0, 0)
	window.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromScale(0, 0.012)
	shadow.Size = UDim2.fromScale(1, 1)

	local tabs = root.Tabs
	tabs.AnchorPoint = Vector2.new(0, 0)
	tabs.Position = UDim2.new(1, 8, 0.05, 0)
	tabs.Size = UDim2.fromScale(0.1, 0.86)

	local content = window.List.Content
	for _, section in { "BoostsSection", "GamepassesSection" } do
		local mark = content[section].Grid.Template.Clip:FindFirstChild("Watermark")
		if mark then
			mark.Image = ""
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_RobuxShop_v2 : plus petite et centrée"
