# a158, banc a54 (conducteurs du camion) : plus de colis du camion au sol à ramasser. L aide grab du scénario donne
# directement au joueur un objet sorti d une caisse de ce camion (payload NPCItem, StoreId « Truck_<n> »), que les
# conducteurs poursuivent (TruckEventService.carriesBoxOf).
s/^local function grab\(player, number\)$/local function grab(player, number) -- a158 : objet du camion donné directement\n\tlocal payload = { Kind = "NPCItem", ItemId = "Z1_Banane", Rarity = "Common", Zone = 1, StoreId = `Truck_{number}`, SlotId = `Truck_{number}\/{player.Name}`, Luck = 1 }\n\tif Carry.StartCarry(player, payload) then\n\t\treturn payload\n\tend\n\treturn nil\nend\nlocal function grab_avant_a158(player, number)/
# Scénario « sans GuardService » (N) : même chose, l objet du camion est donné directement à Alice.
s/^local grabbed = false$/local grabbed = Carry.StartCarry(alice, { Kind = "NPCItem", ItemId = "Z1_Banane", Rarity = "Common", Zone = 1, StoreId = `Truck_{number}`, SlotId = `Truck_{number}\/Alice`, Luck = 1 }) -- a158/
