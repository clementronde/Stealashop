--!nocheck
-- Scénario « pvp » du banc a158 (vague 50, point 3 a) : l'arrivée en zone safe (remote ItemSecured(itemId), UI_Escape,
-- a154) part aussi pour un objet volé à un joueur et déposé chez soi (PvPService, dépôt), une fois par dépôt ; pas à
-- la prise, pas à la victime, pas pour un vol qui échoue. Mise en place du banc a152 (STEAL152, stealAndDeposit).
STEAL152()
local function secured(player, itemId)
	return #remotes("ItemSecured", function(e)
		return e.to == player and (itemId == nil or e.args[1] == itemId)
	end)
end

section("dépôt d'un objet volé : ItemSecured au voleur, une fois")
check(secured(bob) == 0 and secured(ada) == 0, "avant le vol : aucun ItemSecured")
moveTo(bob, refsOfShop(shopOf(ada)).slots[2] + Vector3.new(0, -0.8, 2))
advance(0.05)
fireAs(bob, "StealItem", plotIndex, 2)
flush()
advance(PvP.StealGrabTime + 0.05)
fireAs(bob, "StealItem", plotIndex, 2)
flush()
check(CarryService.IsCarrying(bob) and secured(bob) == 0, "à la prise : Bob porte « loot », pas encore d'ItemSecured")
advance(20)
moveTo(bob, refsOfShop(shopOf(bob)).deposit)
advance(0.5)
check(not CarryService.IsCarrying(bob) and dataOf(bob).Items.loot ~= nil, "déposé chez Bob")
check(secured(bob, "Z1_Banane") == 1 and secured(bob) == 1, "ItemSecured(« Z1_Banane ») au voleur, une seule fois")
check(secured(ada) == 0, "rien à la victime")
advance(2)
check(secured(bob) == 1, "pas renvoyé ensuite")

section("deuxième dépôt : un deuxième ItemSecured")
Held.Stow(bob)
check(stealAndDeposit(3), "Bob porte « loot2 »")
check(dataOf(bob).Items.loot2 ~= nil and secured(bob) == 2, "déposé : ItemSecured une fois de plus")

section("vol raté (inventaire plein) : aucun ItemSecured")
for i = 1, Balance.Display.InventoryMax do
	addItem(dataOf(bob), "pad" .. i, "Z1_Banane", nil, 1, 100 + i)
end
advance(1)
stealAndDeposit(4)
check(dataOf(ada).Items.loot3 ~= nil and secured(bob) == 2, "loot3 reste chez Ada, pas d'ItemSecured")

summary("scénario pvp")
