--!nocheck
-- Scénario « tools » (L-079, décision de Clément du 2026-11-10 : l'écran remplace toute la barre Roblox,
-- outil et batte compris) : une carte par outil possédé (ordre de Config/Tools) puis la batte : icône
-- ICON_TOOL_<Id> (l'image du Template si elle n'est pas livrée), ToolName, ToolStat (« Power 3 », batte
-- « Stun 2s ») ; EquippedPill sur l'outil tenu, EquipButton sur les autres. EquipButton : l'outil de casse
-- donné va en main ; un autre outil possédé passe par EquipTool puis va en main à son arrivée ; la batte ;
-- clic sur la carte de l'outil tenu : rangé. Touches 1 et 2 (traitées par l'UI : rien) ; rien pendant un
-- portage. Barre Roblox coupée à chaque apparition ; le Backpack n'a que l'outil de casse et la batte.

advance(1000)
startServer()
local data = newProfile()
data.Tools = { Owned = { "Fists", "Wrench" }, Equipped = "Fists" }
addItem(data, "a", "Z1_Banane", nil, 1, 1)
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local function held()
	return ada.Character:FindFirstChildWhichIsA("Tool")
end
click(INV.invButton)
click(INV.tabs.Tools.button)

section("cartes des outils")
local cards, n = cardsOf("Tools")
check(n == 3 and cards.Tool_Fists and cards.Tool_Wrench and cards.Tool_Bat and countLabel("Tools") == "3", "poings, clé à molette, batte (Tool_<Id>, Tool_Bat)")
check(cards.Tool_Fists.LayoutOrder == 1 and cards.Tool_Wrench.LayoutOrder == 2 and cards.Tool_Bat.LayoutOrder == 3, "ordre de Config/Tools, la batte à la fin")
check(cardPart(cards.Tool_Wrench, "ToolName").Text == "WRENCH" and cardPart(cards.Tool_Wrench, "ToolStat").Text == "Power " .. Format.short(ToolsConfig.ById.Wrench.Power), `nom et puissance ({cardPart(cards.Tool_Wrench, "ToolStat").Text})`)
check(cardPart(cards.Tool_Bat, "ToolName").Text == "BAT" and cardPart(cards.Tool_Bat, "ToolStat").Text == `Stun {Format.short(BatConfig.StunDuration)}s`, `batte : « {cardPart(cards.Tool_Bat, "ToolStat").Text} »`)
check(cardPart(cards.Tool_Fists, "Icon").Image == "rbxassetid://9201" and cardPart(cards.Tool_Wrench, "Icon").Image == "rbxassetid://9202" and cardPart(cards.Tool_Bat, "Icon").Image == TEMPLATE_IMAGE.Tools, "ICON_TOOL_<Id> ; ICON_TOOL_Bat pas livrée : l'image du Template")
check(held() == nil and shown(cardPart(cards.Tool_Fists, "EquipButton")) and not shown(cardPart(cards.Tool_Fists, "EquippedPill")) and shown(cardPart(cards.Tool_Bat, "EquipButton")), "rien en main : EQUIP partout")

section("EquipButton : en main")
click(cardPart(cards.Tool_Fists, "EquipButton"))
check(held() and held():GetAttribute("ToolId") == "Fists", "les poings en main")
check(shown(cardPart(cards.Tool_Fists, "EquippedPill")) and not shown(cardPart(cards.Tool_Fists, "EquipButton")) and shown(cardPart(cards.Tool_Bat, "EquipButton")), "EquippedPill sur les poings")
click(cardPart(cards.Tool_Bat, "EquipButton"))
check(held() and held():GetAttribute("BatTool") == true, "la batte en main")
check(shown(cardPart(cards.Tool_Bat, "EquippedPill")) and shown(cardPart(cards.Tool_Fists, "EquipButton")) and not shown(cardPart(cards.Tool_Fists, "EquippedPill")), "EquippedPill passé sur la batte")

section("autre outil possédé : EquipTool, puis en main")
local sent = #serverCalls("EquipTool")
click(cardPart(cards.Tool_Wrench, "EquipButton"))
check(#serverCalls("EquipTool") == sent + 1 and serverCalls("EquipTool")[sent + 1].args[1] == "Wrench", "EquipTool(\"Wrench\")")
advance(0.3)
check(dataOf(ada).Tools.Equipped == "Wrench" and held() and held():GetAttribute("ToolId") == "Wrench", "le serveur donne la clé à molette, elle va en main")
check(shown(cardPart(cards.Tool_Wrench, "EquippedPill")) and shown(cardPart(cards.Tool_Bat, "EquipButton")), "EquippedPill sur la clé à molette")
click(cards.Tool_Wrench)
check(held() ~= nil, "un 2e clic aussitôt (le bouton puis sa carte) : rien, l'outil reste en main")
advance(0.6)
click(cards.Tool_Wrench)
check(held() == nil, "clic sur la carte de l'outil tenu : rangé")
advance(0.6)
click(cards.Tool_Fists)
advance(0.3)
check(dataOf(ada).Tools.Equipped == "Fists" and held() and held():GetAttribute("ToolId") == "Fists", "clic sur la carte des poings : rééquipés, en main")

section("touches 1 et 2")
click(INV.close)
pressKey("One")
check(held() == nil, "1 : l'outil tenu est rangé")
pressKey("One")
check(held() and held():GetAttribute("ToolId") == "Fists", "1 : l'outil de casse en main")
pressKey("Two")
check(held() and held():GetAttribute("BatTool") == true, "2 : la batte en main")
pressKey("Two")
check(held() == nil, "2 : rangée")
pressKey("One", true)
check(held() == nil, "touche traitée par l'UI (chat) : rien")
ada:SetAttribute("Carrying", "Rare")
pressKey("One")
check(held() == nil, "pendant un portage : rien en main")
ada:SetAttribute("Carrying", nil)

section("barre Roblox coupée, Backpack réduit à l'outil et la batte")
local calls = #COREGUI_CALLS
spawnCharacter(ada, refsOfShop(shopOf(ada)).center)
advance(0.5)
check(#COREGUI_CALLS > calls and COREGUI_CALLS[#COREGUI_CALLS].enabled == false, "réapparition : barre recoupée")
local backpack = backpackOrder(ada)
check(#backpack == 2 and backpack[1]:GetAttribute("ToolId") == "Fists" and backpack[2]:GetAttribute("BatTool") == true, "Backpack : l'outil de casse et la batte seulement (colis et objets ne sont plus des Tools)")
pressKey("Two")
check(held() and held():GetAttribute("BatTool") == true, "après la réapparition : 2 met la batte en main")
check(Inventory.GetState().Tools == 3, "GetState : 3 cartes d'outils")

summary("scénario tools")
