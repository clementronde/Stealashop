# a158, banc a53 (récompenses) : les colis d un profil deviennent toujours des objets au chargement (convertBoxes sans
# condition) et UnboxService.GiveBox est retiré.
/"aucun colis de plus ; le colis déjà dans le profil reste \(rien de retiré ni converti\)"/d
s/^local boxUid = UnboxService\.GiveBox\(bob, "Luxe", 2, "Epic"\)$/check(UnboxService.GiveBox == nil, "a158 : UnboxService.GiveBox retiré (plus de colis rangé)")/
/"GiveBox marche toujours \(admin, autres sources\)"/d
/^dataOf\(bob\)\.Boxes\[boxUid or ""\] = nil$/d
s/countKeys\(db\.Boxes\) == 1 and db\.Rewards ~= nil, "v6 → v8 : colis rangé \(v7\), Rewards ajouté \(v8\)"/countKeys(db.Boxes) == 0 and db.Rewards ~= nil and (function() for _, it in db.Items do if it.Id == "Z2_YoYo" then return true end end return false end)(), "a158 : v6 → v8 : colis devenu objet (convertBoxes), Rewards ajouté (v8)"/
# « full » : les 50 colis du profil deviennent 50 objets au chargement ; l inventaire plein refuse alors le cadeau du jour.
/"J2 donne un objet ; les 50 colis restent"/d
