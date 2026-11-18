--!nonstrict
-- ui_l216_serverluck_card.luau (demande de Clément du 2026-11-17, benchmark du genre, liaison L-216) : la chance du
-- serveur en Robux, dans la boutique Robux v3 (UI_RobuxShop_v2, ui_v5_robuxshop_v3_build.luau).
--   - BoostsSection.Grid.Preview_4 (nouvelle carte d'exemple, même gabarit que les autres boosts, copie de Preview_3) :
--     « SERVER LUCK », Effect « Luck for the whole server » (caché, comme les autres), icône et filigrane
--     UI_Icon_DP_Luck3 (86703854115395, déjà dans Assets/Icons), prix « ??? » (paliers et prix : Cantin),
--     attribut CardColor = #2FBF71.
--   - BoostsSection passe de 1 à 2 rangées de cartes, avec le même calcul que fitGrid du code (RobuxShopController) ;
--     List.Content suit (rapport et écart). Le code continue d'ajuster la grille au nombre réel de cartes.
-- Sauvegarde dans ServerStorage/MapBackups/2026-11-17_Benchmark/UI_RobuxShop_v2. À lancer en Edit, après
-- ui_l210_robuxshop.luau. Attention : relancer ui_v5_robuxshop_v3_build.luau referait List.Content sans cette carte.
-- Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

local gui = game:GetService("StarterGui").UI_RobuxShop_v2
local content = gui.Root.Window.List.Content
local section = content.BoostsSection
assert(not section.Grid:FindFirstChild("Preview_4"), "Preview_4 existe déjà")
local LUCK = Icons.UI_Icon_DP_Luck3.Texture

local rec = CHS:TryBeginRecording("UI : carte Server Luck dans la boutique Robux (L-216)")
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_Benchmark")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-17_Benchmark"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild("UI_RobuxShop_v2") then
		local copy = gui:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end

	-- 1. Carte d'exemple.
	local grid = section.Grid
	local card = grid.Preview_3:Clone()
	card.Name = "Preview_4"
	card.LayoutOrder = 4
	card:SetAttribute("CardColor", Color3.fromHex("2fbf71"))
	local gradient = card:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(Color3.fromHex("7be3a6"), Color3.fromHex("1f9c58"))
	end
	card.ItemName.Text = "SERVER LUCK"
	local effect = card:FindFirstChild("Effect")
	if effect then
		effect.Text = "Luck for the whole server"
	end
	card.Icon.Image = LUCK
	card.Icon:SetAttribute("IconAsset", "UI_Icon_DP_Luck3")
	local mark = card.Clip:FindFirstChild("Watermark")
	if mark then
		mark.Image = LUCK
	end
	local price = card.BuyButton:FindFirstChild("Price", true)
	if price then
		price.Text = "???"
	end
	card.Visible = true
	card.Parent = grid

	-- 2. Deux rangées (calcul de fitGrid), Content suit.
	local ratio = section:FindFirstChildOfClass("UIAspectRatioConstraint")
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	local height = 1 / ratio.AspectRatio
	local gridHeight = grid.Size.Y.Scale * height
	local cell = layout.CellSize.Y.Scale * gridHeight
	local gap = layout.CellPadding.Y.Scale * gridHeight
	local newGrid = 2 * cell + gap
	local newHeight = height - gridHeight + newGrid
	local k = height / newHeight
	for _, child in section:GetChildren() do
		if child:IsA("GuiObject") then
			child.Position = UDim2.new(child.Position.X.Scale, child.Position.X.Offset, child.Position.Y.Scale * k, child.Position.Y.Offset)
			child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, child.Size.Y.Scale * k, child.Size.Y.Offset)
		end
	end
	grid.Size = UDim2.new(grid.Size.X.Scale, grid.Size.X.Offset, newGrid / newHeight, grid.Size.Y.Offset)
	layout.CellSize = UDim2.new(layout.CellSize.X.Scale, 0, cell / newGrid, 0)
	layout.CellPadding = UDim2.new(layout.CellPadding.X.Scale, 0, gap / newGrid, 0)
	ratio.AspectRatio = 1 / newHeight
	local contentRatio = content:FindFirstChildOfClass("UIAspectRatioConstraint")
	local contentLayout = content:FindFirstChildOfClass("UIListLayout")
	local total = 1 / contentRatio.AspectRatio
	local contentGap = contentLayout.Padding.Scale * total
	local newTotal = total + (newHeight - height) * section.Size.X.Scale
	contentRatio.AspectRatio = 1 / newTotal
	contentLayout.Padding = UDim.new(contentGap / newTotal, 0)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "boutique Robux : carte Server Luck"
