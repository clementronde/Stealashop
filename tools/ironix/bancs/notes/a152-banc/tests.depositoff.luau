--!nocheck
-- Scénario « depositoff » du banc a152 (point 4, HeldItem.DepositToHand = false, pre.depositoff.luau) : l'ancien
-- déroulé, l'objet volé déposé va sur le présentoir libre le plus proche, pas en main ; inventaire plein mais
-- présentoirs libres : la prise reste permise.
STEAL152()
check(sharedModule("Config/HeldItem").DepositToHand == false, "DepositToHand = false (banc)")

section("dépôt : sur un présentoir")
check(stealAndDeposit(2), "Bob porte « loot »")
check(not CarryService.IsCarrying(bob), "déposé")
check(dataOf(bob).Items.loot ~= nil and displayedAt(bob, "loot") ~= nil, "exposé chez Bob")
check(Held.GetHeld(bob) == nil and heldTool(bob) == nil, "pas en main")
check(#notifies(bob, "You stole the Banana: ") == 1 and #notifies(bob, "in your hand") == 0 and #notifies(bob, "inventory") == 0, "Notify « You stole the Banana: <revenu>! » (présentoir)")

section("inventaire plein, présentoirs libres : prise permise, exposé")
for i = 1, Balance.Display.InventoryMax do
	addItem(dataOf(bob), "pad" .. i, "Z1_Banane", nil, 1, 100 + i)
end
check(not DisplayService.HasInventoryRoom(bob) and DisplayService.HasRoom(bob), "inventaire plein, présentoirs libres")
advance(1)
check(stealAndDeposit(3), "Bob porte « loot2 »")
check(displayedAt(bob, "loot2") ~= nil, "exposé chez Bob")

summary("scénario depositoff")
