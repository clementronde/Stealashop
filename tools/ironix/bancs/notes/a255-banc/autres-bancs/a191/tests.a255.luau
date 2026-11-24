--!nocheck
-- Scénario « a255 » (vague 73, L-241 point 4, L-248 ; décision de Cantin du 18/11) : la réserve revient dans UI_Displayed
-- sous les objets exposés (ShowReserve = true), toujours montrée ; Reserve.ReserveEmpty montré seulement quand elle est vide ;
-- UI_Hotbar.Bar.InventoryButton ouvre et ferme l'écran ; sa pastille InventoryAlert s'allume pour un objet entré dans la
-- réserve écran fermé et s'éteint à l'ouverture ; Toggle suit l'écran réel (éteint par un autre code : s'ouvre au clic).
advance(1000)
startServer()
local DisplayedConfig = sharedModule("Config/Displayed")
local InventoryService = serverModule("InventoryService")

local function pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
local C1, U1, R3 = pick(1, "Common"), pick(2, "Uncommon"), pick(3, "Rare")
check(C1 and U1 and R3, `objets de test trouvés ({C1}, {U1}, {R3})`)

local function buildGui(playerGui)
	local gui = make("ScreenGui", { Name = "UI_Displayed", Enabled = true, ResetOnSpawn = false })
	local dock = make("Frame", { Name = "Dock" }, gui)
	make("TextButton", { Name = "CloseButton", Text = "X" }, dock)
	local panel = make("Frame", { Name = "Panel" }, dock)
	local count = make("Frame", { Name = "DisplayCount" }, panel)
	make("TextLabel", { Name = "CountLabel", Text = "0/0" }, count)
	local list = make("ScrollingFrame", { Name = "List" }, panel)
	local row = make("Frame", { Name = "Template", Visible = false }, list)
	make("ImageLabel", { Name = "Icon", Image = "" }, row)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, row)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, row)
	make("TextButton", { Name = "RemoveButton", Text = "" }, row)
	make("TextButton", { Name = "DisplayBestButton", Text = "" }, dock)
	local reserve = make("Frame", { Name = "Reserve", Visible = true }, panel)
	local title = make("Frame", { Name = "ReserveTitle" }, reserve)
	make("TextLabel", { Name = "TitleLabel", Text = "INVENTORY" }, title)
	local rc = make("Frame", { Name = "ReserveCount" }, reserve)
	make("TextLabel", { Name = "ReserveCountLabel", Text = "0" }, rc)
	make("TextLabel", { Name = "ReserveEmpty", Text = "No items", Visible = true }, reserve)
	local rlist = make("ScrollingFrame", { Name = "ReserveList" }, reserve)
	local rrow = make("Frame", { Name = "Template", Visible = false }, rlist)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, rrow)
	local db = make("TextButton", { Name = "DisplayButton", Text = "" }, rrow)
	make("TextLabel", { Name = "DisplayLabel", Text = "DISPLAY" }, db)
	gui.Parent = playerGui
	flush()
	return gui
end
local function buildHotbar(playerGui)
	local gui = make("ScreenGui", { Name = "UI_Hotbar", Enabled = true, ResetOnSpawn = false })
	local bar = make("Frame", { Name = "Bar" }, gui)
	local button = make("ImageButton", { Name = "InventoryButton" }, bar)
	local alert = make("Frame", { Name = "InventoryAlert", Visible = false }, button)
	gui.Parent = playerGui
	flush()
	return button, alert
end
local function reserveRows(gui)
	local n = 0
	for _, child in gui.Dock.Panel.Reserve.ReserveList:GetChildren() do
		if string.sub(child.Name, 1, 8) == "Reserve_" then
			n += 1
		end
	end
	return n
end
local function reserveHas(player, uid)
	return table.find(string.split(player:GetAttribute("DisplayReserve") or "", ","), uid) ~= nil
end
local function give(player, uid, itemId, order)
	addItem(dataOf(player), uid, itemId, nil, 3, order)
	InventoryService.Refresh(player)
	advance(1.2)
end

section("Config/Displayed (V0)")
check(DisplayedConfig.ShowReserve == true, "ShowReserve = true (décision de Cantin du 18/11)")
check(DisplayedConfig.InventoryAlert == true and DisplayedConfig.InventoryAlertGrace == 3, "InventoryAlert = true, grâce de 3 s")

local data = newProfile()
addItem(data, "c1", C1, 1, 1, 1) -- exposé
addItem(data, "u1", U1, 2, 2, 2) -- exposé
data.Reserve = {}
local ada = join("Ada", data)
advance(1.5)
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local gui = buildGui(playerGui)
local button, alert = buildHotbar(playerGui)
startClient(ada)
advance(0.6)
local Displayed = clientModule("DisplayedController")

section("branché : inventaire vide, montré")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(gui.Enabled == false and not Displayed.IsOpen(), "écran éteint jusqu'au clic")
check(ada:GetAttribute("DisplayReserve") == "", `réserve vide côté serveur (« {ada:GetAttribute("DisplayReserve")} »)`)
check(gui.Dock.Panel.Reserve.Visible == true and gui.Dock.Panel.Reserve.ReserveEmpty.Visible == true, "Panel.Reserve montré, ReserveEmpty montré")
check(not Displayed.IsAlertOn() and alert.Visible == false, "pastille éteinte à l'arrivée")

section("InventoryButton de la barre du bas")
click(button)
check(gui.Enabled == true and Displayed.IsOpen() and reserveRows(gui) == 0, "1er clic : écran ouvert, aucune ligne de réserve")
check(gui.Dock.Panel.DisplayCount.CountLabel.Text == "2/4", `compte « {gui.Dock.Panel.DisplayCount.CountLabel.Text} »`)
click(button)
check(gui.Enabled == false and not Displayed.IsOpen(), "2e clic : écran fermé")

section("objet entré écran fermé : pastille allumée")
advance(4) -- après la grâce d'arrivée
give(ada, "k1", R3, 3)
check(reserveHas(ada, "k1"), `k1 entré dans la réserve (« {ada:GetAttribute("DisplayReserve")} »)`)
check(Displayed.IsAlertOn() and alert.Visible == true, "pastille InventoryAlert allumée")
check(gui.Dock.Panel.Reserve.ReserveEmpty.Visible == false and gui.Dock.Panel.Reserve.Visible == true, "ReserveEmpty caché, réserve montrée")
check(gui.Dock.Panel.Reserve.ReserveCount.ReserveCountLabel.Text == "1", "compte de la réserve « 1 »")

section("ouverture : pastille éteinte, objet listé")
click(button)
check(gui.Enabled == true and reserveRows(gui) == 1, `écran ouvert, 1 ligne de réserve ({reserveRows(gui)})`)
check(not Displayed.IsAlertOn() and alert.Visible == false, "pastille éteinte à l'ouverture")
click(button)
check(gui.Enabled == false and not Displayed.IsAlertOn(), "refermé : la pastille reste éteinte (objet vu)")

section("objet entré écran ouvert : pas de pastille")
Displayed.Open()
flush()
give(ada, "k2", R3, 4)
check(reserveHas(ada, "k2") and reserveRows(gui) == 2, `k2 entré et listé ({reserveRows(gui)})`)
check(not Displayed.IsAlertOn(), "écran ouvert : pastille éteinte")
Displayed.Close()
flush()
check(not Displayed.IsAlertOn(), "fermé : toujours éteinte")

section("écran éteint par un autre code : le clic l'ouvre")
Displayed.Open()
flush()
gui.Enabled = false
click(button)
check(gui.Enabled == true and Displayed.IsOpen(), "un seul clic suffit")
Displayed.Close()
flush()

section("UI_Hotbar recréé : rebranché")
button.Parent.Parent:Destroy()
flush()
local button2, alert2 = buildHotbar(playerGui)
advance(0.3)
give(ada, "k3", R3, 5)
check(reserveHas(ada, "k3") and Displayed.IsAlertOn() and alert2.Visible == true, "nouvelle pastille allumée")
click(button2)
check(gui.Enabled == true and alert2.Visible == false, "nouveau bouton : ouvre, pastille éteinte")
Displayed.Close()
flush()
check(not logHas("Displayed", "ERR") and not logHas("attempt to", ""), "aucune erreur")

summary("scénario a255")
