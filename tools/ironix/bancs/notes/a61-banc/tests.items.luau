--!nocheck
-- Scénario « items » (L-079 : on voit rareté, mutation, revenu ; L-089 point 3) : une carte par objet du
-- joueur, exposé ou non (les plus rentables d'abord) : icône ICON_<ItemId> (vide si pas livrée), nom,
-- rareté et sa couleur (Rays, Glow), mutation (cachée sans), revenu, badge « ON DISPLAY ». PlaceButton →
-- PlaceItemAuto : l'objet va sur le présentoir libre le plus proche ; UnequipButton → UnplaceItem : il
-- revient dans l'inventaire ; un clic sur la carte fait ce que montre son bouton ; un seul envoi par double
-- clic ; contour au survol ; compteurs ; Equip Best ; tous les présentoirs pris.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "low", "Z1_Banane", nil, 1, 1) -- Commun zone 1
addItem(data, "high", "Z3_Smartphone", nil, 3, 2) -- Rare zone 3, avec mutation
data.Items.high.Mutation = { Size = "Big", Effect = "Gold" }
addItem(data, "shown", "Z1_Donut", 1, 1, 3) -- exposé sur le présentoir 1
addItem(data, "broc", "Z1_Brocoli", nil, 1, 4) -- icône pas livrée
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
click(INV.invButton)

section("cartes des objets")
local cards, n = cardsOf("Items")
check(n == 4 and cards.Item_low and cards.Item_high and cards.Item_shown and cards.Item_broc, "une carte par objet, exposé compris (Item_<uid>)")
check(cards.Item_high.LayoutOrder == 1, "le plus rentable d'abord (Smartphone Big Gold)")
check(countLabel("Items") == "4" and INV.counter.Text == "3 / 30 items" and INV.displays.Text == "1 / 4 displays", `CountLabel, Counter, Displays ({countLabel("Items")} ; {INV.counter.Text} ; {INV.displays.Text})`)
local high = cards.Item_high
local rare = Rarities.ById.Rare
check(cardPart(high, "Icon").Image == ICON_TEXTURE.Z3_Smartphone, "icône ICON_Z3_Smartphone")
check(cardPart(high, "ItemName").Text == string.upper(Items.ById.Z3_Smartphone.DisplayName), `nom en capitales ({cardPart(high, "ItemName").Text})`)
check(cardPart(high, "RarityBar.Rarity").Text == rare.DisplayNameUpper, "rareté écrite")
check(cardPart(high, "Rays").ImageColor3 == rare.Color and cardPart(high, "Glow").ImageColor3 == rare.Color, "Rays et Glow à la couleur de la rareté")
check(shown(cardPart(high, "MutationTag")) and cardPart(high, "MutationLabel").Text == Mutations.Label({ Size = "Big", Effect = "Gold" }), `mutation montrée ({cardPart(high, "MutationLabel").Text})`)
local income = Formulas.ItemIncome(3, "Rare") * Mutations.IncomeMultiplier({ Size = "Big", Effect = "Gold" })
check(cardPart(high, "Income").Text == Format.income(income), `revenu mutation comprise ({cardPart(high, "Income").Text})`)
check(not shown(cardPart(high, "DisplayedBadge")) and shown(cardPart(high, "PlaceButton")) and not shown(cardPart(high, "UnequipButton")), "objet de l'inventaire : PlaceButton, pas de badge")
local shownCard = cards.Item_shown
check(shown(cardPart(shownCard, "DisplayedBadge")) and not shown(cardPart(shownCard, "PlaceButton")) and shown(cardPart(shownCard, "UnequipButton")), "objet exposé : badge « ON DISPLAY » et UnequipButton")
check(not shown(cardPart(cards.Item_low, "MutationTag")), "sans mutation : MutationTag caché")
check(cardPart(cards.Item_broc, "Icon").Image == "", "icône pas livrée : image vide")

section("survol : contour")
local outline = cardPart(high, "HoverOutline")
check(not shown(outline), "contour caché au repos")
high.MouseEnter:Fire()
check(shown(outline), "survol : contour montré")
high.MouseLeave:Fire()
check(not shown(outline), "sortie : contour caché")

section("PlaceButton : sur le présentoir libre le plus proche")
local S = refsOfShop(shopOf(ada))
moveTo(ada, S.slots[4] + Vector3.new(0, 1, 2))
advance(0.3)
local sent = #serverCalls("PlaceItemAuto")
click(cardPart(high, "PlaceButton"))
click(cardPart(high, "PlaceButton")) -- double clic
check(#serverCalls("PlaceItemAuto") == sent + 1 and serverCalls("PlaceItemAuto")[sent + 1].args[1] == "high", "PlaceItemAuto(\"high\"), une seule fois au double clic")
advance(0.3)
check(dataOf(ada).Display["4"] == "high", "posé sur le présentoir libre le plus proche (4)")
check(#notifies(ada, "placed on a display!") == 1 and string.find(notifies(ada, "placed on a display!")[1].args[1], "Big Gold " .. Items.ById.Z3_Smartphone.DisplayName, 1, true) ~= nil, "Notify « Big Gold … placed on a display! »")
check(shown(cardPart(high, "DisplayedBadge")) and shown(cardPart(high, "UnequipButton")) and not shown(cardPart(high, "PlaceButton")), "la carte suit : badge et UnequipButton")
check(INV.counter.Text == "2 / 30 items" and INV.displays.Text == "2 / 4 displays", "compteurs à jour")

section("clic sur la carte : ce que montre son bouton")
advance(0.6)
click(cards.Item_low)
advance(0.3)
local lowSlot = invItem(ada, "low") and invItem(ada, "low").Slot
check(lowSlot ~= nil and dataOf(ada).Display[tostring(lowSlot)] == "low", "carte d'un objet de l'inventaire : posé")
advance(0.6)
click(cards.Item_low)
advance(0.3)
check(invItem(ada, "low").Slot == nil and dataOf(ada).Display[tostring(lowSlot)] == nil, "carte d'un objet exposé : repris")

section("UnequipButton : retour dans l'inventaire")
local sentUn = #serverCalls("UnplaceItem")
click(cardPart(shownCard, "UnequipButton"))
check(#serverCalls("UnplaceItem") == sentUn + 1 and serverCalls("UnplaceItem")[sentUn + 1].args[1] == "shown", "UnplaceItem(\"shown\")")
advance(0.3)
check(dataOf(ada).Display["1"] == nil and dataOf(ada).Items.shown ~= nil, "plus exposé, toujours dans Items")
check(#notifies(ada, "removed from its display") >= 1, "Notify « … removed from its display »")
check(not shown(cardPart(shownCard, "DisplayedBadge")) and shown(cardPart(shownCard, "PlaceButton")), "la carte suit : PlaceButton")

section("Equip Best")
local eb = #serverCalls("EquipBest")
click(INV.equipBest)
check(#serverCalls("EquipBest") == eb + 1, "EquipBestButton → EquipBest")
advance(0.3)
local displayed = 0
for _, item in invState(ada).Items do
	if item.Slot then
		displayed += 1
	end
end
check(displayed == 4 and INV.displays.Text == "4 / 4 displays" and INV.counter.Text == "0 / 30 items", `4 meilleurs objets exposés (displays : {INV.displays.Text})`)
check(#notifies(ada, "Your best items are now on display!") == 1, "Notify d'Equip Best")

section("tous les présentoirs pris : refusé")
local extra = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
placeAt(ada, extra, 18, 20)
local newItem = openPlaced(ada, extra)
advance(revealDelay("Common") + 0.6)
check(newItem ~= nil and invOf(ada)["Item:" .. newItem] ~= nil, "un 5e objet dans l'inventaire")
local fresh = cardsOf("Items")["Item_" .. newItem]
check(fresh ~= nil and shown(cardPart(fresh, "PlaceButton")), "sa carte arrive, avec PlaceButton")
advance(0.6)
click(cardPart(fresh, "PlaceButton"))
advance(0.3)
check(invItem(ada, newItem).Slot == nil and #notifies(ada, "All your displays are full!") == 1, "Notify « All your displays are full! », objet gardé")

section("fermé : rien n'est peint, l'état suit quand même")
click(INV.close)
DisplayService.Unplace(ada, "high")
advance(0.6)
click(INV.invButton)
check(shown(cardPart(cardsOf("Items").Item_high, "PlaceButton")), "rouvert : carte à jour")

summary("scénario items")
