--!nocheck
-- Banc a286 : écran UI_Displayed en une seule liste (après tools/clement/ui_displayed_une_liste.luau) et ses lignes.
function buildGui(playerGui)
	local gui = make("ScreenGui", { Name = "UI_Displayed", Enabled = true, ResetOnSpawn = false })
	local dock = make("Frame", { Name = "Dock" }, gui)
	make("TextButton", { Name = "CloseButton", Text = "X" }, dock)
	local panel = make("Frame", { Name = "Panel" }, dock)
	local count = make("Frame", { Name = "DisplayCount" }, panel)
	make("TextLabel", { Name = "CountLabel", Text = "0/0" }, count)
	local list = make("ScrollingFrame", { Name = "List" }, panel)
	local row = make("Frame", { Name = "Template", Visible = false }, list)
	make("Frame", { Name = "IconBack" }, row)
	make("ImageLabel", { Name = "Icon", Image = "" }, row)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, row)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, row)
	local remove = make("TextButton", { Name = "RemoveButton", Text = "" }, row)
	make("TextLabel", { Name = "RemoveLabel", Text = "REMOVE" }, remove)
	local db = make("TextButton", { Name = "DisplayButton", Text = "" }, row)
	make("TextLabel", { Name = "DisplayLabel", Text = "DISPLAY" }, db)
	make("TextLabel", { Name = "ListEmpty", Text = "No items yet", Visible = true }, panel)
	make("TextButton", { Name = "DisplayBestButton", Text = "" }, dock)
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

