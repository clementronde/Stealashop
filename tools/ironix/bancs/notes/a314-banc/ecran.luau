--!nocheck
-- Banc a314 : PawnShopService monté, et l'écran UI_Displayed de la maquette de Clément (tools/clement/ui_displayed_v2.luau,
-- 22-23/11) : liste unique, boutons rangés dans Template.Buttons, SellButton caché dans le gabarit, Dock.Confirm caché.
moduleScript(SERVICES, "PawnShopService", "server/Services/PawnShopService.luau")

function buildGui(playerGui)
	local gui = make("ScreenGui", { Name = "UI_Displayed", Enabled = true, ResetOnSpawn = false })
	local dock = make("Frame", { Name = "Dock" }, gui)
	local panel = make("Frame", { Name = "Panel" }, dock)
	local header = make("Frame", { Name = "Header" }, panel)
	local count = make("Frame", { Name = "DisplayCount" }, header)
	make("TextLabel", { Name = "CountLabel", Text = "0/0" }, count)
	make("TextButton", { Name = "CloseButton", Text = "" }, header)
	local list = make("ScrollingFrame", { Name = "List" }, panel)
	local row = make("Frame", { Name = "Template", Visible = false }, list)
	local slot = make("Frame", { Name = "IconSlot" }, row)
	make("Frame", { Name = "IconBack" }, slot)
	make("ImageLabel", { Name = "Icon", Image = "" }, slot)
	local info = make("Frame", { Name = "Info" }, row)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, info)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, info)
	local chip = make("Frame", { Name = "RarityChip" }, info)
	make("TextLabel", { Name = "RarityLabel", Text = "RARITY" }, chip)
	local buttons = make("Frame", { Name = "Buttons" }, row)
	local remove = make("TextButton", { Name = "RemoveButton", Text = "" }, buttons)
	make("TextLabel", { Name = "RemoveLabel", Text = "REMOVE" }, remove)
	local db = make("TextButton", { Name = "DisplayButton", Text = "", Visible = false }, buttons)
	make("TextLabel", { Name = "DisplayLabel", Text = "DISPLAY" }, db)
	local sell = make("TextButton", { Name = "SellButton", Text = "", Visible = false }, buttons)
	make("TextLabel", { Name = "SellLabel", Text = "SELL" }, sell)
	make("TextLabel", { Name = "ListEmpty", Text = "No items yet", Visible = false }, panel)
	make("TextButton", { Name = "DisplayBestButton", Text = "" }, dock)
	local conf = make("Frame", { Name = "Confirm", Visible = false }, dock)
	local ch = make("Frame", { Name = "Header" }, conf)
	make("TextLabel", { Name = "Title", Text = "SELL ITEM?" }, ch)
	make("TextLabel", { Name = "TitleShadow", Text = "SELL ITEM?" }, ch)
	local is = make("Frame", { Name = "ItemSlot" }, conf)
	make("ImageLabel", { Name = "ItemIcon", Image = "" }, is)
	make("TextLabel", { Name = "ItemRarity", Text = "RARITY" }, conf)
	make("TextLabel", { Name = "ItemName", Text = "Item Name" }, conf)
	make("TextLabel", { Name = "SellPrice", Text = "for $0" }, conf)
	local yes = make("TextButton", { Name = "YesButton", Text = "" }, conf)
	make("TextLabel", { Name = "YesLabel", Text = "YES" }, yes)
	local no = make("TextButton", { Name = "NoButton", Text = "" }, conf)
	make("TextLabel", { Name = "NoLabel", Text = "NO" }, no)
	gui.Parent = playerGui
	flush()
	return gui
end
function rowsIn(list, prefix)
	local out = {}
	for _, child in list:GetChildren() do
		if prefix == nil or string.sub(child.Name, 1, #prefix) == prefix then
			if child.Name ~= "Template" and child:IsA("GuiObject") then
				table.insert(out, child)
			end
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
function rowOf(list, uid)
	for _, child in list:GetChildren() do
		if child.Name ~= "Template" and string.sub(child.Name, -#uid - 1) == "_" .. uid then
			return child
		end
	end
	return nil
end
