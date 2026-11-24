-- a219 (vague 66, L-210 point 2, 2026-11-16) : outils communs des scénarios a219 et a219off (lus avant le scénario).
-- Faux InventoryController : seul PlaceItem est lu par DisplayedController (objet sous antivol de la réserve).
SOURCES["stub/InventoryControllerA219"] = [==[
local M = { Calls = {} }
function M.PlaceItem(uid)
	table.insert(M.Calls, uid)
end
return M
]==]
moduleScript(CONTROLLERS, "InventoryController", "stub/InventoryControllerA219")
function a219Pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
function a219Reserve(player)
	return table.concat(dataOf(player).Reserve or {}, ",")
end
function a219Displayed(player)
	local out = {}
	for key, uid in dataOf(player).Display do
		out[uid] = tonumber(key)
	end
	return out
end
-- Écran UI_Displayed de Clément avec Panel.Reserve (comme le scénario displayed).
function a219Gui(playerGui)
	local gui = make("ScreenGui", { Name = "UI_Displayed", Enabled = true, ResetOnSpawn = false })
	local panel = make("Frame", { Name = "Panel" }, gui)
	local header = make("Frame", { Name = "Header" }, panel)
	make("TextLabel", { Name = "Title", Text = "MY DISPLAYS" }, header)
	make("TextButton", { Name = "CloseButton", Text = "X" }, panel)
	local count = make("Frame", { Name = "DisplayCount" }, panel)
	make("TextLabel", { Name = "CountLabel", Text = "0/0" }, count)
	local list = make("ScrollingFrame", { Name = "List" }, panel)
	local row = make("Frame", { Name = "Template", Visible = false }, list)
	make("ImageLabel", { Name = "Icon", Image = "" }, row)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, row)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, row)
	make("TextButton", { Name = "RemoveButton", Text = "" }, row)
	local best = make("TextButton", { Name = "DisplayBestButton", Text = "" }, panel)
	make("TextLabel", { Name = "DisplayBestLabel", Text = "DISPLAY BEST" }, best)
	local reserve = make("Frame", { Name = "Reserve" }, panel)
	local rc = make("Frame", { Name = "ReserveCount" }, reserve)
	make("TextLabel", { Name = "ReserveCountLabel", Text = "0" }, rc)
	local rlist = make("ScrollingFrame", { Name = "ReserveList" }, reserve)
	local rrow = make("Frame", { Name = "Template", Visible = false }, rlist)
	make("ImageLabel", { Name = "Icon", Image = "" }, rrow)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, rrow)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, rrow)
	local db = make("TextButton", { Name = "DisplayButton", Text = "" }, rrow)
	make("TextLabel", { Name = "DisplayLabel", Text = "DISPLAY" }, db)
	gui.Parent = playerGui
	flush()
	return gui
end
function a219Row(gui, uid)
	for _, child in gui.Panel.Reserve.ReserveList:GetChildren() do
		if string.match(child.Name, "^Reserve_%d+_(.+)$") == uid then
			return child
		end
	end
	return nil
end
function a219Rows(gui)
	local n = 0
	for _, child in gui.Panel.Reserve.ReserveList:GetChildren() do
		if string.sub(child.Name, 1, 8) == "Reserve_" then
			n += 1
		end
	end
	return n
end
-- Profil : 4 présentoirs pleins (e3, u1, puis deux Communs à revenu égal en 3 et 4), un Commun libre (c2), un objet
-- sous antivol pas encore posé (at1).
function a219Profile()
	local C1, U1, R3, E3 = a219Pick(1, "Common"), a219Pick(2, "Uncommon"), a219Pick(3, "Rare"), a219Pick(3, "Epic")
	local data = newProfile()
	addItem(data, "e3", E3, 1, 3, 1)
	addItem(data, "u1", U1, 2, 2, 2)
	addItem(data, "c1a", C1, 3, 1, 3)
	addItem(data, "c1", C1, 4, 1, 4)
	addItem(data, "c2", C1, nil, 1, 5)
	addItem(data, "at1", R3, nil, 3, 6)
	data.Items.at1.AntiTheft = true
	data.Items.at1.UnlockAt = 4102444800
	data.Reserve = {}
	return data, C1, E3
end
