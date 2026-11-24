--!nocheck
-- Scénario « potionsui » (a111, vague 33) : section Potions AVEC le Template demandé à Clément
-- (PotionsSection.Cards.Template : Icon, PotionName, Count, PotionStat, UseButton, ActivePill.TimerLabel,
-- HoverOutline) et l'icône ICON_POT_Money livrée : ce Template est pris (pas celui des outils), textes posés
-- dans les bons éléments, ActivePill pendant l'effet, UseButton → UsePotion.

advance(1000)
startServer()
local data = newProfile()
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
local cardsFrame = INV.sections.Potions.cards
local t = make("TextButton", { Name = "Template", Visible = false, Text = "" }, cardsFrame)
make("ImageLabel", { Name = "Icon", Image = "rbxassetid://9" }, t)
make("TextLabel", { Name = "PotionName", Text = "POTION" }, t)
make("TextLabel", { Name = "Count", Text = "x0" }, t)
make("TextLabel", { Name = "PotionStat", Text = "" }, t)
local useB = make("TextButton", { Name = "UseButton", Text = "" }, t)
make("TextLabel", { Name = "UseLabel", Text = "DRINK" }, useB)
local pillF = make("Frame", { Name = "ActivePill", Visible = false }, t)
make("TextLabel", { Name = "TimerLabel", Text = "0:00" }, pillF)
make("Frame", { Name = "HoverOutline", Visible = false }, t)
-- Icône livrée (Contract/Icons : Decal ICON_POT_Money dans Assets/Icons).
local assets = ReplicatedStorage:FindFirstChild("Assets") or make("Folder", { Name = "Assets" }, ReplicatedStorage)
local icons = assets:FindFirstChild("Icons") or make("Folder", { Name = "Icons" }, assets)
make("Decal", { Name = "ICON_POT_Money", Texture = "rbxassetid://777" }, icons)
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")

click(INV.invButton)
click(INV.tabs.Potions.button)
ada:SetAttribute("PotionStock_Money", 3)
flush()

section("Template de Clément")
local cards, n = cardsOf("Potions")
local m = cards.Potion_Money
check(n == 1 and m ~= nil and not t.Visible, "une carte Potion_Money clonée de SON Template (resté caché)")
check(m and cardPart(m, "PotionName").Text == "MONEY POTION" and cardPart(m, "Count").Text == "x3", `PotionName « {m and cardPart(m, "PotionName").Text} », Count « {m and cardPart(m, "Count").Text} »`)
check(m and cardPart(m, "PotionStat").Text == "×2 · 2:00", `PotionStat « {m and cardPart(m, "PotionStat").Text} »`)
check(m and cardPart(m, "Icon").Image == "rbxassetid://777", "Icon = ICON_POT_Money")
check(m and cardPart(m, "UseButton.UseLabel").Text == "DRINK" and shown(cardPart(m, "UseButton")), "UseButton visible, son texte gardé (celui de Clément)")
check(m and not shown(cardPart(m, "ActivePill")), "pas d'effet : ActivePill caché")

section("UseButton, effet")
local c0 = #serverCalls("UsePotion")
click(cardPart(m, "UseButton"))
local calls = serverCalls("UsePotion")
check(#calls == c0 + 1 and calls[#calls].args[1] == "Money", "UseButton → UsePotion(« Money »)")
ada:SetAttribute("PotionStock_Money", 2)
ada:SetAttribute("Potion_Money", Workspace:GetServerTimeNow() + 65)
flush()
advance(0.3)
local timer = cardPart(m, "ActivePill.TimerLabel").Text
check(shown(cardPart(m, "ActivePill")) and (timer == "1:05" or timer == "1:04"), `ActivePill « {timer} »`)
check(cardPart(m, "Count").Text == "x2" and cardPart(m, "PotionStat").Text == "×2 · 2:00", "Count x2, PotionStat inchangé")
check(not logHas("", "WARN", "client"), "aucune erreur côté client")
summary("scénario potionsui")
