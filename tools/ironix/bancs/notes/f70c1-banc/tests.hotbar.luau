--!nocheck
-- Scénario « hotbar » de f70c1 (correctif f70, B2) : une grande fenêtre masque UI_Hotbar par HudMask (HideScreens,
-- comme UiMotionController) ; la boucle de HotbarController (0,25 s) ne la rallume plus, même un instant ; le masque
-- retiré, la barre revient et reste ; la poursuite garde sa règle.

advance(1000)
startServer()
local data = newProfile()
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
local maskModule = moduleScript(CONTROLLERS:FindFirstChild("UI"), "HudMask", "client/Controllers/UI/HudMask.luau")
startClient(ada)
advance(0.5)
local HudMask = requireModule(maskModule, "client")

section("sans masque")
check(HB.screen.Enabled == true, "barre allumée")

section("masquée par une grande fenêtre")
local writes = 0
local conn = HB.screen:GetPropertyChangedSignal("Enabled"):Connect(function()
	writes += 1
end)
HudMask.Push("WindowHud", { HideScreens = { "UI_Hotbar" } })
check(HB.screen.Enabled == false and (HudMask.IsMasked == nil or HudMask.IsMasked(HB.screen)), "éteinte à l'image même, IsMasked vrai")
local before = writes
advance(3)
check(writes == before, "jamais rallumée par HotbarController pendant 3 s (" .. (writes - before) .. " écriture(s))")
check(HB.screen.Enabled == false, "toujours éteinte")

section("masque retiré")
HudMask.Pop("WindowHud")
check(HB.screen.Enabled == true and (HudMask.IsMasked == nil or not HudMask.IsMasked(HB.screen)), "rendue à l'image même")
advance(1)
check(HB.screen.Enabled == true, "et elle reste")
conn:Disconnect()

section("poursuite (règle inchangée)")
CHASED = true
advance(0.5)
check(HB.screen.Enabled == false, "cachée pendant la poursuite")
CHASED = false
advance(1)
check(HB.screen.Enabled == true, "revenue après la poursuite")

summary("scénario hotbar")
