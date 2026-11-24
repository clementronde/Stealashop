--!nocheck
-- Scénario « a242 » (vague 72, L-219 point 4, L-231, 2026-11-17) : Config/Displayed.ShowReserve = false. L'écran des
-- objets exposés (UI_Displayed, ouvert par le bouton inventaire du HUD) ne montre plus la réserve : Panel.Reserve caché,
-- jamais rempli ; le serveur la garde (ReserveCatchAll, Exposer les meilleurs). CloseArrowButton (la flèche, facultative)
-- ferme comme CloseButton. Les lignes ne sont refaites que si ce qu'elles montrent change (un clic n'est plus perdu).
advance(1000)
startServer()
local Format = sharedModule("Format")
local DisplayedConfig = sharedModule("Config/Displayed")

local function pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
local C1, U1, R3, E3 = pick(1, "Common"), pick(2, "Uncommon"), pick(3, "Rare"), pick(3, "Epic")
check(C1 and U1 and R3 and E3, `objets de test trouvés ({C1}, {U1}, {R3}, {E3})`)

local function buildGui(playerGui, withArrow)
	local gui = make("ScreenGui", { Name = "UI_Displayed", Enabled = true, ResetOnSpawn = false })
	local dock = make("Frame", { Name = "Dock" }, gui)
	local close = make("TextButton", { Name = "CloseButton", Text = "X" }, dock)
	if withArrow then
		make("TextButton", { Name = "CloseArrowButton", Text = ">" }, dock)
	end
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
	make("TextButton", { Name = "DisplayBestButton", Text = "" }, dock)
	local reserve = make("Frame", { Name = "Reserve", Visible = true }, panel)
	local rc = make("Frame", { Name = "ReserveCount" }, reserve)
	make("TextLabel", { Name = "ReserveCountLabel", Text = "0" }, rc)
	local rlist = make("ScrollingFrame", { Name = "ReserveList" }, reserve)
	local rrow = make("Frame", { Name = "Template", Visible = false }, rlist)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, rrow)
	local db = make("TextButton", { Name = "DisplayButton", Text = "" }, rrow)
	make("TextLabel", { Name = "DisplayLabel", Text = "DISPLAY" }, db)
	gui.Parent = playerGui
	flush()
	return gui, close
end
local function rowsIn(list, prefix)
	local out = {}
	for _, child in list:GetChildren() do
		if string.sub(child.Name, 1, #prefix) == prefix then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
local function rowsOf(gui)
	return rowsIn(gui.Dock.Panel.List, "Row_")
end
local function reserveRows(gui)
	return rowsIn(gui.Dock.Panel.Reserve.ReserveList, "Reserve_")
end

section("interrupteur")
check(DisplayedConfig.ShowReserve == false, "Config/Displayed.ShowReserve = false (V0, L-231)")

local data = newProfile()
addItem(data, "c1", C1, 1, 1, 1) -- exposé
addItem(data, "u1", U1, 2, 2, 2) -- exposé
addItem(data, "r3", R3, nil, 3, 3) -- hors présentoir
addItem(data, "e3", E3, nil, 3, 4) -- hors présentoir
local ada = join("Ada", data)
advance(1.5)
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local gui = buildGui(playerGui, true)
startClient(ada)
advance(0.6)
local Displayed = clientModule("DisplayedController")

section("branché : la réserve est cachée, le serveur la garde")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(gui.Enabled == false and not Displayed.IsOpen(), "écran éteint jusqu'au HUD")
check(gui.Dock.Panel.Reserve.Visible == false, "Panel.Reserve caché dès le branchement")
check(ada:GetAttribute("DisplayReserve") == "e3,r3", `serveur : réserve gardée (« {ada:GetAttribute("DisplayReserve")} »)`)
check(not logHas("Reserve introuvable", ""), "aucune ligne « Reserve introuvable » dans la sortie")

section("ouvert : les exposés seuls")
Displayed.Toggle()
flush()
local rows = rowsOf(gui)
check(gui.Enabled == true and #rows == 2, `2 lignes d'exposés (trouvé {#rows})`)
check(rows[1] and rows[1].Name == "Row_01_u1" and rows[1].Income.Text == Format.income(Formulas.ItemIncome(2, "Uncommon")), "Peu commun d'abord, revenu écrit")
check(gui.Dock.Panel.Reserve.Visible == false and #reserveRows(gui) == 0, "réserve : cachée, aucune ligne")
check(gui.Dock.Panel.DisplayCount.CountLabel.Text == "2/4", `compte « {gui.Dock.Panel.DisplayCount.CountLabel.Text} »`)

section("lignes gardées quand rien ne change")
local first = rows[1]
Displayed.Open() -- rafraîchit sans changement
flush()
ada:SetAttribute("DisplayReserve", "r3,e3") -- réserve réordonnée : les exposés ne changent pas
flush()
local again = rowsOf(gui)
check(#again == 2 and again[1] == first and first.Parent ~= nil, "même ligne (pas détruite ni recréée)")
local calls = #serverCalls("UnplaceItem")
click(first.RemoveButton)
check(#serverCalls("UnplaceItem") == calls + 1 and serverCalls("UnplaceItem")[calls + 1].args[1] == "u1", "RemoveButton de la ligne gardée : UnplaceItem(u1)")
advance(1.2)
again = rowsOf(gui)
check(#again == 1 and again[1].Name == "Row_01_c1" and first.Parent == nil, `exposés changés : lignes refaites ({#again})`)
check(gui.Dock.Panel.Reserve.Visible == false and #reserveRows(gui) == 0, "réserve toujours cachée")

section("Exposer les meilleurs : sort les objets de la réserve cachée")
click(gui.Dock.DisplayBestButton)
advance(1.2)
again = rowsOf(gui)
check(#again == 4 and again[1].Name == "Row_01_e3", `4 exposés, l'Épique en tête ({#again})`)
check(#reserveRows(gui) == 0, "aucune ligne de réserve")

section("la flèche ferme")
click(gui.Dock.CloseArrowButton)
check(gui.Enabled == false and not Displayed.IsOpen() and #rowsOf(gui) == 0, "CloseArrowButton : éteint, lignes retirées")
Displayed.Toggle()
flush()
check(gui.Enabled == true and #rowsOf(gui) == 4, "rouvert : lignes refaites")

section("sans flèche : la croix (repli)")
gui:Destroy()
local gui2, close2 = buildGui(playerGui, false)
advance(0.3)
Displayed.Toggle()
flush()
check(gui2.Enabled == true and #rowsOf(gui2) == 4 and gui2.Dock.Panel.Reserve.Visible == false, "écran neuf : 4 lignes, réserve cachée")
click(close2)
check(gui2.Enabled == false and not Displayed.IsOpen(), "CloseButton : éteint")
check(not logHas("Displayed", "ERR") and not logHas("attempt to", ""), "aucune erreur")

summary("scénario a242")
