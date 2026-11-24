--!nocheck
-- Partie commune des scénarios deposit et depositoff du banc a152 : Ada expose « keep » (le plus rentable : à
-- l'abri, coffre-fort V0), « loot », « loot2 » et « loot3 » ; Bob casse sa porte et vole (vrai PvPService).
function STEAL152()
advance(1000)
startServer()
PvPService = serverModule("PvPService")
PvP = sharedModule("Config/PvP")
Held = serverModule("HeldItemService")
local data = newProfile()
data.Upgrades.DisplaySlots = 4 -- 8 présentoirs
addItem(data, "keep", "Z3_Smartphone", 1, 3, 1)
addItem(data, "loot", "Z1_Banane", 2, 1, 2)
addItem(data, "loot2", "Z1_Banane", 3, 1, 3)
addItem(data, "loot3", "Z1_Banane", 4, 1, 4)
ada = join("Ada", data)
bob = join("Bob", newProfile())
advance(1.5)
plotIndex = shopOf(ada):GetAttribute("PlotIndex")
breakDoor(ada, bob)
end

-- Bob prend l'objet du présentoir `slot` d'Ada (deux appels), puis l'emporte jusqu'à sa DepositZone. `beforeDeposit`
-- est appelé juste avant le dépôt. Renvoie true si Bob portait l'objet.
function stealAndDeposit(slot, beforeDeposit)
	moveTo(bob, refsOfShop(shopOf(ada)).slots[slot] + Vector3.new(0, -0.8, 2))
	advance(0.05)
	fireAs(bob, "StealItem", plotIndex, slot)
	flush()
	advance(PvP.StealGrabTime + 0.05)
	fireAs(bob, "StealItem", plotIndex, slot)
	flush()
	local carried = CarryService.IsCarrying(bob)
	if not carried then
		return false
	end
	advance(20) -- contrôle du dépôt : le porteur va à vitesse fixe
	if beforeDeposit then
		beforeDeposit()
	end
	moveTo(bob, refsOfShop(shopOf(bob)).deposit)
	advance(0.5)
	return true
end
