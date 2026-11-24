-- Copie a134 (rééquilibrage v2) : la potion Speed est retirée ; la carte d'essai est celle de Strength (×1,5).
--!nocheck
-- Scénario « potions » (a111, vague 33) : section Potions de UI_Inventory SANS Template de potion (Studio du
-- 2026-11-13) : cartes V0 clonées du Template de ToolsSection, une par type en stock (attribut
-- PotionStock_<Id>, posé ici à la place de PotionService), ordre de Config/Potions ; ToolName « SPEED POTION
-- x2 », ToolStat « ×1.5 · 2:00 » puis « Active 1:42 » pendant l'effet, EquipButton « USE », EquippedPill caché,
-- Icon vide (pas d'ICON_POT_) ; EquipButton ou clic sur la carte → UsePotion(Id) ; CountLabel = total ; stock
-- à 0 : carte retirée ; profil sans potions : section vide, sans erreur ; les outils ne changent pas.

advance(1000)
startServer()
local data = newProfile()
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
-- Studio (2026-11-13) : PotionsSection.TitleRow.SectionCount.CountLabel existe.
local row = INV.sections.Potions.frame:FindFirstChild("TitleRow")
local sc = make("Frame", { Name = "SectionCount" }, row)
make("TextLabel", { Name = "CountLabel", Text = "9" }, sc)
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local Potions = sharedModule("Config/Potions")

section("profil sans potions")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
click(INV.invButton)
clearLog()
click(INV.tabs.Potions.button)
local _, n0 = cardsOf("Potions")
check(n0 == 0 and countLabel("Potions") == "0" and Inventory.GetState().Potions == 0, "aucune potion : section vide, CountLabel « 0 »")
check(not logHas("", "WARN", "client"), "aucune erreur côté client")
check(not INV.templates.Tools.Visible, "Template de ToolsSection toujours caché")

section("cartes V0")
ada:SetAttribute("PotionStock_Strength", 0)
ada:SetAttribute("PotionStock_Invisibility", 1)
ada:SetAttribute("PotionStock_Strength", 2)
flush()
local cards, n = cardsOf("Potions")
check(n == 2 and cards.Potion_Strength ~= nil and cards.Potion_Invisibility ~= nil, `2 cartes Potion_Strength, Potion_Invisibility (trouvé {n})`)
check(cards.Potion_Strength and cards.Potion_Strength.LayoutOrder < cards.Potion_Invisibility.LayoutOrder, "ordre de Config/Potions")
check(countLabel("Potions") == "3" and Inventory.GetState().Potions == 3, `CountLabel = total « 3 » (trouvé {countLabel("Potions")})`)
local sp = cards.Potion_Strength
check(cardPart(sp, "ToolName").Text == "STRENGTH POTION x2", `ToolName « {cardPart(sp, "ToolName").Text} »`)
check(cardPart(sp, "ToolStat").Text == "×1.5 · 2:00", `ToolStat « {cardPart(sp, "ToolStat").Text} »`)
check(cardPart(sp, "EquipButton").EquipLabel.Text == "USE" and shown(cardPart(sp, "EquipButton")) and not shown(cardPart(sp, "EquippedPill")), "EquipButton « USE », EquippedPill caché")
check(cardPart(sp, "Icon").Image == "", "pas d'ICON_POT_Strength : pas l'image d'un outil")
local inv = cards.Potion_Invisibility
check(cardPart(inv, "ToolName").Text == "INVISIBILITY POTION x1" and cardPart(inv, "ToolStat").Text == "1:00", `Invisibility : « {cardPart(inv, "ToolName").Text} », « {cardPart(inv, "ToolStat").Text} »`)
check(sp.Parent == INV.sections.Potions.cards and sp.Visible, "carte dans PotionsSection.Cards, visible")
local tools, tn = cardsOf("Tools")
check(tn == 0 or tools.Tool_Fists ~= nil, "section des outils pas touchée")

section("utiliser")
local c0 = #serverCalls("UsePotion")
click(cardPart(sp, "EquipButton"))
local calls = serverCalls("UsePotion")
check(#calls == c0 + 1 and calls[#calls].args[1] == "Strength", "EquipButton (USE) → UsePotion(« Strength »)")
click(cardPart(sp, "EquipButton"))
check(#serverCalls("UsePotion") == c0 + 1, "2e clic tout de suite : pas de double envoi")
advance(1)
click(inv)
calls = serverCalls("UsePotion")
check(#calls == c0 + 2 and calls[#calls].args[1] == "Invisibility", "clic sur la carte → UsePotion(« Invisibility »)")
Inventory.UsePotion("Beer")
check(#serverCalls("UsePotion") == c0 + 2, "Id inconnu : rien n'est envoyé")

section("effet actif, stock qui baisse")
ada:SetAttribute("PotionStock_Strength", 1)
ada:SetAttribute("Potion_Strength", Workspace:GetServerTimeNow() + 102)
flush()
advance(0.3)
cards = cardsOf("Potions")
sp = cards.Potion_Strength
check(sp and cardPart(sp, "ToolName").Text == "STRENGTH POTION x1", "stock 2 → 1 : x1")
local stat = sp and cardPart(sp, "ToolStat").Text
check(stat == "Active 1:42" or stat == "Active 1:41", `effet en cours : « {stat} »`)
check(countLabel("Potions") == "2", "CountLabel « 2 »")
ada:SetAttribute("PotionStock_Invisibility", 0)
flush()
local _, n2 = cardsOf("Potions")
check(n2 == 1 and cardsOf("Potions").Potion_Invisibility == nil, "stock 0 : carte retirée")
ada:SetAttribute("Potion_Strength", nil)
flush()
check(cardPart(cardsOf("Potions").Potion_Strength, "ToolStat").Text == "×1.5 · 2:00", "effet fini : de nouveau « ×1.5 · 2:00 »")

section("fermeture")
click(INV.close)
local _, left = cardsOf("Potions")
check(left == 0, "cartes retirées à la fermeture")
click(INV.invButton)
local _, again = cardsOf("Potions")
check(again == 1 and Inventory.GetState().Tab == "Potions", "rouvert : la carte revient")
check(not logHas("", "WARN", "client"), "aucune erreur côté client")
summary("scénario potions")
