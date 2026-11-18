--!nonstrict
-- ui_l218_inventory.luau (réponse de Clément du 2026-11-17) : « on garde l'onglet display, on voit tout ce qui est
-- affiché et en dessous les objets non mis dans la boutique, donc dans l'inventaire, et un bouton Inventory au bout de
-- la barre du bas ».
--   1. UI_Displayed : la réserve devient l'inventaire, sous les objets exposés. Seuls les textes changent :
--      Reserve.ReserveTitle « IN RESERVE » → « INVENTORY », Reserve.ReserveEmpty → « Items not in your shop show up
--      here ». Les noms lus par le code (Panel.Reserve, ReserveList.Template…) ne changent pas.
--   2. UI_Hotbar.Bar.InventoryButton (nouveau) : une case de plus, la dernière de la barre (LayoutOrder 1000, après les
--      Slot_* du code), même allure que les cases (copie du Template) : Icon (le sac de l'ancien bouton d'inventaire,
--      87821404848234), InventoryLabel « Inventory », InventoryAlert caché. Le code l'ouvre comme
--      RightRail.DisplayedButton : il ouvre UI_Displayed.
-- Sauvegardes dans ServerStorage/MapBackups/2026-11-17_Benchmark. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local SG = game:GetService("StarterGui")

local BAG = "rbxassetid://87821404848234"

local function backup(screen)
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_Benchmark")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-17_Benchmark"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild(screen.Name) then
		local copy = screen:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end
end
local function drop(parent, name)
	local x = parent:FindFirstChild(name)
	if x then
		x:Destroy()
	end
end

local rec = CHS:TryBeginRecording("UI : inventaire sous les objets exposés, bouton Inventory dans la barre")
local ok, err = pcall(function()
	local displayed = SG.UI_Displayed
	local hotbar = SG.UI_Hotbar
	backup(displayed)
	backup(hotbar)

	local reserve = displayed.Dock.Panel.Reserve
	reserve.ReserveTitle.Text = "INVENTORY"
	local empty = reserve:FindFirstChild("ReserveEmpty")
	if empty then
		empty.Text = "Items not in your shop show up here"
	end

	local bar = hotbar.Bar
	if not bar:FindFirstChild("InventoryButton") then
		local button = bar.Template:Clone()
		button.Name = "InventoryButton"
		button.LayoutOrder = 1000
		button.Visible = true
		drop(button, "KeyLabel")
		drop(button, "Income")
		drop(button, "AntiTheft")
		drop(button, "Equipped")
		button.Icon.Image = BAG
		button.ItemName.Name = "InventoryLabel"
		button.InventoryLabel.Text = "Inventory"
		local alert = button:FindFirstChild("SlotAlert")
		if alert then
			alert.Name = "InventoryAlert"
			alert.Visible = false
		end
		button.Parent = bar
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "inventaire sous les objets exposés, bouton Inventory"
