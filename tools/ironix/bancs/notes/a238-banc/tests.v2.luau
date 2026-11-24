--!nocheck
-- Scénario « v2 » d'a238 (vitrine, Config du dépôt) : canvas de List, filigrane, nom de zZz.
addGlow()
startClient()
section("a238 v2")
check(Monetization.ShopBoosts[2].Key == "SleepGuards" and Monetization.ShopBoosts[2].DisplayName == "Sleeping Guards 60s", "1d zZz : DisplayName « Sleeping Guards 60s »")
openShop()
check(V2.Enabled == true, "v2 ouverte")
check(textOf(v2Card(V2, "SleepGuards"), "ItemName") == "Sleeping Guards 60s", `1d carte zZz : {textOf(v2Card(V2, "SleepGuards"), "ItemName")}`)
check(LIST.AutomaticCanvasSize == Enum.AutomaticSize.None, `1a AutomaticCanvasSize = None ({tostring(LIST.AutomaticCanvasSize)})`)
check(LIST.CanvasSize.Y.Offset == 1660 and LIST.CanvasSize.Y.Scale == 0, `1a CanvasSize = Content (1 644) + 4 + 12 = 1 660 ({LIST.CanvasSize.Y.Offset})`)
CONTENT.AbsoluteSize = Vector2.new(400, 1800)
flush()
check(LIST.CanvasSize.Y.Offset == 1816, `1a Content plus haut (1 800) : canvas refait à 1 816 ({LIST.CanvasSize.Y.Offset})`)
CONTENT.AbsoluteSize = Vector2.new(300, 1200.4)
flush()
check(LIST.CanvasSize.Y.Offset == 1217, `1a Content moins haut (1 200,4) : canvas à 1 217 ({LIST.CanvasSize.Y.Offset})`)
local all, same = 0, 0
for _, section in { "GamepassesSection", "BoostsSection", "CashSection" } do
	for _, card in v2El(V2, section .. ".Grid"):GetChildren() do
		if string.sub(card.Name, 1, 6) == "Offer_" then
			all += 1
			local watermark = card:FindFirstChild("Clip"):FindFirstChild("Watermark")
			if watermark.Image == card:FindFirstChild("Icon").Image then
				same += 1
			end
		end
	end
end
check(all > 0 and same == all, `1c filigrane = image de l'Icon sur chaque carte ({same}/{all})`)
local sleep = v2Card(V2, "SleepGuards")
check(sleep:FindFirstChild("Icon").Image == SLEEP_ICON and sleep:FindFirstChild("Clip"):FindFirstChild("Watermark").Image == SLEEP_ICON, "1c zZz : filigrane = UI_Icon_Sleep (plus la basket)")
check(v2El(V2, "BoostsSection.Grid.Template"):FindFirstChild("Clip"):FindFirstChild("Watermark").Image == BASKET, "Template de Clément pas touché")
-- Vitrine, aucun palier créé : Ouvrir maintenant garde « Soon » (a218).
local openNow = v2Card(V2, "OpenNow")
check(openNow:FindFirstChild("BuyButton").Visible == true and textOf(openNow, "Price") == "Soon", "1b vitrine, paliers à l'Id 0 : bouton « Soon » (inchangé)")
summary("scénario v2")
