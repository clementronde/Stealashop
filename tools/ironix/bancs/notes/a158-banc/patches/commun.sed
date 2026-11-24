# a158 : un colis porté des scénarios (« Kind = "NPCBox", Tier = "…", ») devient un objet sorti d un colis (NPCItem, Luck = 1).
s/Kind = "NPCBox", Tier = "[A-Za-z]+",/Kind = "NPCItem", Luck = 1,/g
