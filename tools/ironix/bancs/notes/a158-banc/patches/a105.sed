# a158, banc a105 (antivol en base) : un colis porté (NPCBox) n est plus rangé dans Boxes ni posé au sol.
# Scénario « off » retiré (Features.ShelfOpen = false : l ancien déroulé du colis, qui n existe plus).
s/check\(boxUid ~= nil and dataOf\(ada\)\.Boxes\[boxUid\] ~= nil and dataOf\(ada\)\.Boxes\[boxUid\]\.Spot == nil, "colis rangé dans Boxes, comme avant"\)/check(boxUid == nil and next(dataOf(ada).Boxes) == nil, "a158 : un colis porté (NPCBox) n est plus rangé dans Boxes")/
/^local boxUid = bringBox\(ada, "Common", "Z1_Banane", "Standard", 1\)$/d
/^local box = placeAt\(ada, boxUid, 6, 0\)$/d
/"colis au même point : refusé \(Blocked\)"/d
