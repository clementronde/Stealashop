--!nonstrict
-- bb_item_compact.luau (Clément, 2026-11-24, validé avec l'agrandissement des objets exposés ; relayé par le chef UI) :
-- à lancer en Edit. Le billboard des objets exposés, ReplicatedStorage/Assets/UI/BB_Item, passe de 6,5 × 3 studs à
-- 5 × 2,4 studs, et ses lignes changent d'ordre (aucun nom changé) : de haut en bas ItemName (blanc, gros), Rarity (en
-- couleur), Income (vert), puis Mutation et Weight en petit. La liste reste alignée en bas (au plus près de
-- l'objet) : une ligne cachée par le code (Mutation sans mutation, Weight sans poids) ne laisse pas de trou. Weight
-- est caché par défaut (le code le montre avec le vrai poids). L'ancrage au-dessus de l'objet et la taille selon la
-- rareté restent au code. Sauvegarde : ServerStorage/MapBackups/2026-11-24_BBItem.

local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

-- ordre (LayoutOrder) et hauteur de chaque ligne, en fraction du billboard (somme 1)
local ROWS = {
	{ "ItemName", 0.27 },
	{ "Rarity", 0.19 },
	{ "Income", 0.24 },
	{ "Mutation", 0.15 },
	{ "Weight", 0.15 },
}

local function apply(bb)
	bb.Size = UDim2.new(5, 0, 2.4, 0)
	for order, row in ROWS do
		local label = bb:FindFirstChild(row[1])
		assert(label, "BB_Item." .. row[1] .. " introuvable")
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, row[2], 0)
		label.TextScaled = false
		label.TextWrapped = true
		label.TextScaled = true
	end
	bb.Weight.Visible = false
	local layout = bb:FindFirstChildOfClass("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
end

local rec = CHS:TryBeginRecording("UI : BB_Item en 5 × 2,4 studs, lignes nom, rareté, revenu, mutation, poids")
local ok, err = pcall(function()
	local bb = RS.Assets.UI.BB_Item
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_BBItem")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_BBItem"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("BB_Item") then
		bb:Clone().Parent = backups
	end
	apply(bb)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "BB_Item : 5 × 2,4 studs, ordre ItemName, Rarity, Income, Mutation, Weight"
