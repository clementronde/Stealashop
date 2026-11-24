--!nocheck
-- Scénario « chase » (L-095 point 6 : la barre se cache pendant la poursuite) : ChaseFeelController (ici
-- son bouchon, même règle : Enabled d'avant gardé, remis à la fin) cache UI_Hotbar ; la barre ne se
-- rallume pas tant que la poursuite dure, même quand elle se repeint (outil pris, état changé) ou quand
-- une nouvelle copie de l'écran arrive ; après la poursuite, elle revient, nouvelle copie comprise.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "high", "Z3_Smartphone", nil, 3, 2)
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Hotbar = clientModule("HotbarController")
local Inventory = clientModule("InventoryController")

section("avant la poursuite")
check(HB.screen.Enabled == true, "barre allumée")

section("pendant la poursuite")
CHASED = true
advance(0.5)
check(HB.screen.Enabled == false and Hotbar.GetState().Enabled == false, "cachée")
pressKey("Two")
advance(0.3)
check(ada.Character:FindFirstChildWhichIsA("Tool") ~= nil, "les touches marchent encore (batte en main)")
pressKey("Two")
Inventory.PlaceItem("high")
advance(2)
check(HB.screen.Enabled == false, "repeinte (outil, objet exposé) : toujours cachée")
local enabledSeen = false
local conn = HB.screen:GetPropertyChangedSignal("Enabled"):Connect(function()
	if HB.screen.Enabled then
		enabledSeen = true
	end
end)
advance(3)
check(not enabledSeen, "jamais rallumée, même un instant, pendant 3 s")
conn:Disconnect()

section("nouvelle copie de l'écran pendant la poursuite (ResetOnSpawn)")
local old = HB.screen
old:Destroy()
local fresh = makeHotbarScreen(false)
fresh.Parent = ada:FindFirstChild("PlayerGui")
HB.screen = fresh
advance(1)
check(fresh.Enabled == false and Hotbar.GetState().Bound, "branchée, mais cachée")
check(select(2, slotsOf(fresh)) == 6, "ses cases sont là (outil, batte et 4 cases vides ; copie a76)")

section("fin de la poursuite")
CHASED = false
advance(1)
check(fresh.Enabled == true, "la barre revient (même arrivée pendant la poursuite)")
advance(2)
check(fresh.Enabled == true, "et elle reste")

summary("scénario chase")
