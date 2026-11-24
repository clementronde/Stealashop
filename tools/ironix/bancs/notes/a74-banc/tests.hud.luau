--!nocheck
-- Scénario « hud » (L-095) : InventoryButton des deux colonnes de UI_HUD (LeftRail sur PC, LeftRailTouch
-- sur téléphone) ouvre et ferme l'inventaire, un bouton arrivé plus tard aussi ; sans UI_Hotbar, les
-- touches 1 et 2 d'origine marchent toujours (et la barre se branche quand l'écran arrive).

advance(1000)
startServer()
local ada = join("Ada", nil)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada, { noHotbar = true })
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local Hotbar = clientModule("HotbarController")
local function held()
	return ada.Character:FindFirstChildWhichIsA("Tool")
end

section("deux colonnes, deux boutons")
click(INV.invButton)
check(Inventory.GetState().Open, "LeftRail.InventoryButton : ouvert")
click(INV.invButton)
check(not Inventory.GetState().Open, "LeftRail.InventoryButton encore : fermé")
click(HB.touchButton)
check(Inventory.GetState().Open, "LeftRailTouch.InventoryButton : ouvert")
click(HB.touchButton)
check(not Inventory.GetState().Open, "LeftRailTouch.InventoryButton encore : fermé")
local late = make("TextButton", { Name = "InventoryButton", Text = "" }, make("Frame", { Name = "OtherRail" }, INV.hud))
advance(0.1)
click(late)
check(Inventory.GetState().Open, "un InventoryButton arrivé plus tard : branché")
click(late)

section("sans UI_Hotbar : touches 1 et 2 d'origine")
check(not Hotbar.GetState().Bound, "pas de barre")
pressKey("One")
check(held() and held():GetAttribute("ToolId") == "Fists", "1 : outil en main")
pressKey("Two")
check(held() and held():GetAttribute("BatTool") == true, "2 : batte en main")
pressKey("Two")
check(held() == nil, "2 : rangée")

section("l'écran arrive : la barre prend les touches")
local screen = makeHotbarScreen(false)
screen.Parent = ada:FindFirstChild("PlayerGui")
HB.screen = screen
advance(0.5)
check(Hotbar.GetState().Bound and screen.Enabled == true and select(2, slotsOf()) == 2, "branchée et allumée (outil et batte)")
pressKey("One")
advance(0.05)
check(held() and held():GetAttribute("ToolId") == "Fists" and slotPart(slotsOf().Slot_Tool, "Equipped").Visible, "1 : outil en main, une fois, Equipped")

summary("scénario hud")
