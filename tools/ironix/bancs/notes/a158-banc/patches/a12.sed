# a158, banc a12 (vigile) : le vigile sort pour le porteur d un objet (NPCItem) ; payload minimal du scénario S11.
s/CarryService\.StartCarry\(mia, \{ Kind = "NPCBox", StoreId = "STORE_Z2_Confiserie" \}\)/CarryService.StartCarry(mia, { Kind = "NPCItem", StoreId = "STORE_Z2_Confiserie" })/
