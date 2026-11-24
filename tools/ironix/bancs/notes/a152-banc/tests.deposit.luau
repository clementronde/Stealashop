--!nocheck
-- Scénario « deposit » du banc a152 (point 4, HeldItem.DepositToHand = true, réponse de Cantin : « oui en main ») :
-- l'objet volé déposé va dans la main du voleur (mains libres), sinon dans son inventaire ; jamais tout seul sur un
-- présentoir ; inventaire plein : la prise est refusée (rien de perdu).
STEAL152()
check(sharedModule("Config/HeldItem").DepositToHand == true, "DepositToHand = true par défaut")

section("mains libres : en main")
check(DisplayService.HasRoom(bob) and countKeys(dataOf(bob).Display) == 0, "Bob a des présentoirs libres")
check(stealAndDeposit(2), "Bob porte « loot »")
check(not CarryService.IsCarrying(bob), "déposé")
check(dataOf(ada).Items.loot == nil and dataOf(bob).Items.loot ~= nil and dataOf(bob).Items.loot.Source == "PvP", "transféré chez Bob (Source PvP)")
check(countKeys(dataOf(bob).Display) == 0, "pas posé sur un présentoir")
check(Held.GetHeld(bob) == "loot" and heldTool(bob) ~= nil, "dans la main de Bob")
check(#notifies(bob, "it's in your hand") == 1, "Notify « You stole the Banana: it's in your hand… »")
check(#notifies(ada, "stole your") == 1, "Ada est prévenue")

section("mains prises : inventaire")
Held.Stow(bob)
check(stealAndDeposit(3, function()
	local tool = bob.Backpack:FindFirstChildWhichIsA("Tool")
	if tool then
		tool.Parent = bob.Character
	end
end), "Bob porte « loot2 »")
check(not CarryService.IsCarrying(bob), "déposé")
check(dataOf(bob).Items.loot2 ~= nil and countKeys(dataOf(bob).Display) == 0, "chez Bob, pas sur un présentoir")
check(Held.GetHeld(bob) == nil, "pas en main (outil tenu)")
check(#notifies(bob, "it went to your inventory") == 1, "Notify « …it went to your inventory. »")
local tool = bob.Character:FindFirstChildWhichIsA("Tool")
if tool then
	tool.Parent = bob.Backpack
end

section("inventaire plein : prise refusée, rien de perdu")
for i = 1, Balance.Display.InventoryMax do
	addItem(dataOf(bob), "pad" .. i, "Z1_Banane", nil, 1, 100 + i)
end
check(not DisplayService.HasInventoryRoom(bob) and DisplayService.HasRoom(bob), "inventaire plein, présentoirs libres")
advance(1)
check(not stealAndDeposit(4), "prise refusée")
check(dataOf(ada).Display["4"] == "loot3" and dataOf(ada).Items.loot3 ~= nil, "loot3 reste chez Ada")
check(#notifies(bob, "Your inventory is full") >= 1, "Notify « Your inventory is full… »")

summary("scénario deposit")
