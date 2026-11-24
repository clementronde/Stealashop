# a158, banc a36 (anti-triche) : l aide grabShelf (prise d un colis fermé) est remplacée par celle de patches/a36.pre.luau.
s/^function grabShelf\(/function grabShelf_avant_a158(/
# D1a : ce qu Alice porte est un objet sorti d un colis (NPCItem). D1b : l objet est donné par le banc, le rayon ne perd rien.
s/check\(box ~= nil and box\.Kind == "NPCBox", "D1a Alice porte un colis du magasin"\)/check(box ~= nil and box.Kind == "NPCItem", "D1a a158 : Alice porte un objet du magasin")/
/"D1b le rayon a un colis de moins"/d
# C5b : le porteur d un objet est poursuivi sans abandon (a66, a114) ; il ne garde plus son butin 30 s au fond du magasin.
/`C5b sortie devant la vitrine, colis gardé/d
