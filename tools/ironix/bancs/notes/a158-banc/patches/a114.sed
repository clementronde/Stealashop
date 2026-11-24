# a158, banc a114 (objet lié au vigile), L7 : plus de colis du camion posé au sol (PlaceDrop) ; Bob porte directement
# l objet d un camion (NPCItem, StoreId « Truck_1 », par patches/commun.sed). Scénario « oldflow » retiré.
s/^local truckId = Carry\.PlaceDrop\(truck, Vector3\.new\(120, 0, 0\)\)$/local truckId = Carry.StartCarry(B, truck) -- a158 : objet du camion porté directement/
s/check\(truckId ~= nil, "L7 \(banc\) colis du camion posé au sol"\)/check(truckId == true, "L7 (banc, a158) Bob porte un objet du camion")/
/"L7 \(banc\) Bob le ramasse \(PickUpDrop, comme TruckEventService\)"/d
