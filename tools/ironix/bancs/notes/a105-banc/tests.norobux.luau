--!nocheck
-- Scénario « norobux » (décision de Cantin du 2026-11-12) : boutique Robux coupée (Features.RobuxShop = false) →
-- Fast Open et Ouvrir maintenant n'agissent pas sur l'antivol (aucune accroche posée).

advance(1000)
startServer()
check(sharedModule("Config/Features").RobuxShop == false, "Features.RobuxShop = false")
local ada = join("Ada", nil)
advance(1.5)
Workspace:SetAttribute("MonetizationTest", "Ada FastOpen")
flush()
local uid = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
local t0 = serverTime()
local e = placeItemAt(ada, uid, 6, 0)
check(e.Spot ~= nil and math.abs(e.UnlockAt - (t0 + 0.35 + antiTheftOf("Epic"))) < 0.5, "Fast Open sans effet : antivol complet")
check(UnboxService.GetAntiTheftDelay(ada, "Z3_TeleGeante") == antiTheftOf("Epic"), "GetAntiTheftDelay non remplacé")
summary("scénario norobux")
