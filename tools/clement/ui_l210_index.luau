--!nonstrict
-- ui_l210_index.luau (retours du test de Clément du 2026-11-16, L-210 et L-208 point 4) : UI_Index_v3 plus petit.
--   - Root 62 % × 54 % de l'écran (au lieu de 72 % × 63 %) ; même rapport et même minimum (660 × 324) : le téléphone ne
--     change pas. Sur PC (1920 × 1080), la fenêtre fait 994 × 583 (52 % × 54 %) au lieu de 1160 × 680.
--   - Colonne de la zone (ZoneArt, « MINI MART / KIOSK ») : 17 % de la section au lieu de 23,5 % ; Content 80,8 %.
--   - Cartes : 5 par rang au lieu de 4, plus de nom sur la carte (ItemName caché, dans le Template et les Preview_*).
--   - ListPanel 0,494 de la fenêtre au lieu de 0,547 : la liste s'arrête sous le 2e rang de cartes, aucune carte coupée
--     à l'ouverture.
--   - RewardIcon (le cadre jaune de la récompense au bout de ZoneBar) : rentré dans la barre (calé à droite, 1,3 fois sa
--     hauteur), contour dessiné à l'intérieur : il n'est plus rogné par le haut de la liste.
--   - Retirés (hors contrat, L-208 point 4) : Root.Unused (MutationTabs, MutationCaption), Categories.Unused
--     (SecretsButton), ZoneBar.ZoneItem de chaque section. UnlockedBar.ClaimAllButton reste, caché : il est encore
--     exigé par le contrat ; à retirer quand Ironix l'aura enlevé de Contract/UI.
-- Le tri des cartes du moins rare au plus rare est dans le code (IndexController, ordre de Config/Index) : demandé à
-- Ironix dans la liaison. Sauvegarde dans ServerStorage/MapBackups/2026-11-16_L210/UI_Index_v3. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_Index_v3
local root = gui.Root
local window = root.Window
local list = window.ListPanel.List

local PER_ROW, PAD = 5, 0.02

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
local function drop(parent, name)
	local x = parent and parent:FindFirstChild(name)
	if x then
		x:Destroy()
	end
end

local rec = CHS:TryBeginRecording("UI : index plus petit, 5 cartes par rang, sans nom (L-210)")
local ok, err = pcall(function()
	backup(gui)

	root.Size = UDim2.fromScale(0.62, 0.54)
	local panel = window.ListPanel
	panel.Size = UDim2.fromScale(panel.Size.X.Scale, 0.494) -- mesuré : rangs entiers seulement de 667 × 375 à 1920 × 1080

	for _, section in list:GetChildren() do
		if section.Name:find("Section$") then
			local art, content = section.ZoneArt, section.Content
			art.Size = UDim2.new(0.17, 0, art.Size.Y.Scale, art.Size.Y.Offset)
			content.Size = UDim2.new(0.808, 0, content.Size.Y.Scale, content.Size.Y.Offset)
			local grid = content.Cards.UIGridLayout
			grid.CellPadding = UDim2.new(PAD, 0, 0, 0)
			grid.CellSize = UDim2.new((1 - PAD * (PER_ROW - 1)) / PER_ROW, 0, 0, 10000)
			local bar = content.ZoneBar
			drop(bar, "ZoneItem")
			local reward = bar:FindFirstChild("RewardIcon")
			if reward then
				reward.AnchorPoint = Vector2.new(1, 0.5)
				reward.Position = UDim2.fromScale(1, 0.5)
				reward.Size = UDim2.fromScale(0.3, 1.3) -- carré par son UIAspectRatioConstraint : 1,3 fois la hauteur de la barre
				local stroke = reward:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
				end
			end
		end
	end

	-- Plus de nom sur les cartes.
	for _, d in gui:GetDescendants() do
		if d.Name == "ItemName" and d:IsA("TextLabel") and (d.Parent.Name == "Template" or d.Parent.Name:find("^Preview_")) then
			d.Visible = false
		end
	end

	drop(root, "Unused") -- MutationTabs, MutationCaption
	drop(root.Categories, "Unused") -- SecretsButton
	-- UnlockedBar.ClaimAllButton reste (caché) : il est encore au contrat d'origin (Contract/UI), malgré L-208.
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Index_v3 : plus petit, 5 cartes par rang"
