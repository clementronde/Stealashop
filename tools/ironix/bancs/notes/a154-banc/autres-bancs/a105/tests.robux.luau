--!nocheck
-- Scénario « robux » (décision de Cantin du 2026-11-12, soir) : avec Features.ShelfOpen, la boutique Robux agit
-- sur l'ANTIVOL par le même chemin que sur l'attente des colis : GetWaiting compte l'objet au sol, « Ouvrir
-- maintenant » (reçu, PurchaseId idempotent) retire l'antivol, son crédit raccourcit l'objet posé ensuite, Fast
-- Open (DelayFactor 0,5) divise la durée à la pose et l'antivol restant à l'achat. pre.on.luau : RobuxShop = true.
do
	local key = "shared/Config/Monetization.luau"
	local source = SOURCES[key]
	local from = "{ Id = 0, Price = 19, Skip = 60 }"
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. "{ Id = 8101, Price = 19, Skip = 60 }" .. string.sub(source, last + 1)
end

advance(1000)
startServer()

local ada = join("Ada", nil)
advance(1.5)

section("GetWaiting : l'objet sous antivol au sol attend")
local uid = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
check(UnboxService.GetWaiting(ada)[uid] == nil, "dans l'inventaire : rien n'attend")
local entry = placeItemAt(ada, uid, 6, 0)
check(near(UnboxService.GetWaiting(ada)[uid] or 0, entry.UnlockAt), "posé : GetWaiting[uid] = UnlockAt")
advance(1.2)
check(near(ada:GetAttribute("OpenNowReadyAt") or 0, entry.UnlockAt), "OpenNowReadyAt = l'antivol de l'objet")

section("« Ouvrir maintenant » : l'antivol est retiré tout de suite")
local receiptEntry = receipt(ada, 8101, "PA1")
check(settle(receiptEntry) == Enum.ProductPurchaseDecision.PurchaseGranted, "reçu accordé")
check(entry.UnlockAt <= serverTime() + 1e-6, "UnlockAt = maintenant (Skip 60 s ≥ 30 s d'antivol)")
check(near(floorItemOf(ada, uid):GetAttribute("UnlockAt"), entry.UnlockAt), "attribut UnlockAt du modèle à jour")
check(not UnboxService.IsStealable(ada, uid), "plus volable")
check(#notifies(ada, "Anti-theft removed") == 1, "Notify « Anti-theft removed: your item is UNLOCKED! »")
check(#notifies(ada, "UNLOCKED! Put it on a display") == 1, "Notify de fin d'antivol (une fois)")
local again = receipt(ada, 8101, "PA1")
check(settle(again) == Enum.ProductPurchaseDecision.PurchaseGranted and (dataOf(ada).Monetization.OpenNowCredit or 0) == 0, "même PurchaseId : rien de plus (idempotent)")

section("crédit : sans attente, retiré de l'objet posé ensuite")
check(next(UnboxService.GetWaiting(ada)) == nil, "plus rien n'attend")
local credit = receipt(ada, 8101, "PA2")
check(settle(credit) == Enum.ProductPurchaseDecision.PurchaseGranted and dataOf(ada).Monetization.OpenNowCredit == 60, "60 s de crédit")
local uid2 = bringItem(ada, "Z3_Smartphone", "Rare", 3)
local t0 = serverTime()
local e2 = placeItemAt(ada, uid2, -6, 0)
flush()
check(e2.UnlockAt <= t0 + 0.5 + 1e-6, "posé : l'antivol (20 s) retiré par le crédit")
check(dataOf(ada).Monetization.OpenNowCredit == 40, "reste 40 s de crédit")
check(#notifies(ada, "new item's anti-theft is") == 1, "Notify « Open Now: your new item's anti-theft is … shorter! »")

section("Fast Open : antivol × 0,5 à la pose, et l'antivol restant à l'achat")
dataOf(ada).Monetization.OpenNowCredit = 0
local uid3 = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
local e3 = placeItemAt(ada, uid3, 0, 16)
check(e3.Spot ~= nil, "objet posé sans Fast Open")
advance(10)
local before = e3.UnlockAt - serverTime()
Workspace:SetAttribute("MonetizationTest", "Ada FastOpen")
flush()
advance(0.1)
local afterLeft = e3.UnlockAt - serverTime()
check(before > 15 and math.abs(afterLeft - before / 2) < 0.3, `à l'achat : antivol restant divisé par 2 ({string.format("%.1f", before)} → {string.format("%.1f", afterLeft)} s)`)
local uid4 = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
local t4 = serverTime()
local e4 = placeItemAt(ada, uid4, -20, 16)
check(e4.Spot ~= nil and math.abs(e4.UnlockAt - (t4 + 0.35 + antiTheftOf("Epic") * 0.5)) < 0.5, "posé avec Fast Open : antivol de l'Épique × 0,5")

summary("scénario robux")
