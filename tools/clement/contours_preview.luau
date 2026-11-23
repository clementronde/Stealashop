-- Aperçu des contours des éléments interactifs (L-305, validé par Clément le 2026-11-23).
-- À coller dans la barre de commande de Studio, en Edit. Crée Workspace/_PREVIEW_Contours :
-- des copies de ReplicatedStorage/Assets/FX/FX_Outline posées par Adornee sur les vrais objets,
-- plus quelques objets et colis copiés sur les présentoirs et les rayons. Aucun script.
-- Le modèle ne bouge pas. Relancer le script efface l'ancien aperçu. Pour l'effacer sans le refaire :
-- workspace._PREVIEW_Contours:Destroy(). À effacer avant un Play (sinon il part dans le test).

local FX = game.ReplicatedStorage.Assets.FX
local OUTLINE = FX:WaitForChild("FX_Outline")
local FOCUS = FX:WaitForChild("FX_OutlineFocus")

local old = workspace:FindFirstChild("_PREVIEW_Contours")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "_PREVIEW_Contours"

local function outline(target: Instance?, name: string, template: Highlight?)
	if not target then
		return
	end
	local h = ((template or OUTLINE) :: Highlight):Clone()
	h.Name = name
	h.Adornee = target
	h.Parent = root
end

local map = workspace.Map
local hub = map.Hub

-- Hub : cadeau, noob, roue (pas les classements), comptoirs et vendeurs.
for _, zone in hub.Zones:GetChildren() do
	if zone.Name ~= "ENV_Hub_Leaderboard" then
		outline(zone, "Outline_" .. zone.Name)
	end
end
for _, stall in hub.Stalls:GetChildren() do
	outline(stall, "Outline_" .. stall.Name)
	for _, child in stall:GetChildren() do
		if child:IsA("Model") and child.Name:match("^Vendor_") then
			outline(child, "Outline_" .. child.Name)
		end
	end
end

-- Boutiques : porte et tapis.
for _, plot in hub.Shops:GetChildren() do
	outline(plot:FindFirstChild("PlotDoor"), "Outline_" .. plot.Name .. "_PlotDoor")
	outline(plot:FindFirstChild("Treadmill"), "Outline_" .. plot.Name .. "_Treadmill")
end

-- PLOT_Shop_02 : 4 objets copiés sur les présentoirs du Rayon_01 ; la pastèque est « visée » (blanc).
local plot = hub.Shops:FindFirstChild("PLOT_Shop_02")
local rayon = plot and plot:FindFirstChild("Rayon_01")
local items = { "ITM_Z1_CanetteDeSoda", "ITM_Z1_Pasteque", "ITM_Z1_Banane", "ITM_Z1_Donut" }
for index, itemId in items do
	local stand = rayon and rayon:FindFirstChild(string.format("DisplayStand_%02d", index))
	local slot = stand and stand:FindFirstChild(string.format("DisplaySlot_%02d", index), true)
	local source = game.ReplicatedStorage.Assets.Items:FindFirstChild(itemId)
	if slot and slot:IsA("Attachment") and source then
		local copy = source:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		copy:PivotTo(slot.WorldCFrame)
		copy.Parent = root
		outline(copy, "Outline_" .. itemId, if itemId == "ITM_Z1_Pasteque" then FOCUS else OUTLINE)
	end
end

-- Couloir : vitrine des 12 magasins ; 6 colis copiés sur les rayons de la Superette.
for _, zone in map:GetChildren() do
	if zone.Name:match("^Zone_") then
		for _, store in zone:GetChildren() do
			if store.Name:match("^STORE_") then
				outline(store:FindFirstChild("Window", true), "Outline_" .. store.Name .. "_Window")
			end
		end
	end
end
local superette = map:FindFirstChild("Zone_1") and map.Zone_1:FindFirstChild("STORE_Z1_Superette")
local boxes = { "BOX_Standard", "BOX_Premium", "BOX_Luxe", "BOX_Standard", "BOX_Rare", "BOX_Standard" }
for index, boxName in boxes do
	local slot = superette and superette:FindFirstChild(string.format("ShelfSlot_%02d", index), true)
	local source = game.ReplicatedStorage.Assets.Boxes:FindFirstChild(boxName)
	if slot and source then
		local copy = source:Clone()
		copy.Name = "Preview_" .. boxName .. "_" .. index
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Highlight") then
				d:Destroy() -- le contour vient de FX_Outline, comme en jeu
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
		copy:PivotTo(if slot:IsA("Attachment") then slot.WorldCFrame else (slot :: BasePart).CFrame)
		copy.Parent = root
		outline(copy, "Outline_" .. copy.Name)
	end
end

root.Parent = workspace
local count = 0
for _, d in root:GetChildren() do
	if d:IsA("Highlight") then
		count += 1
	end
end
print(`_PREVIEW_Contours : {count} contours`)
