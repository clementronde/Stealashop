# a171, banc a74, scénario « slots » : objets donnés par objet-sans-colis.luau (plus de colis rapporté ni ouvert en base).
# a171-inclut: objet-sans-colis.sed
s/Slot_Box_/Slot_Item_/g
# Les cases 5 et 6 tiennent maintenant des objets sous antivol (Smartphone, Banane) : leur nom, leur icône ICON_<ItemId>
# (pas livrée dans ce faux arbre : l'image du Template) et leur revenu, au lieu de « Premium Box », ICON_BOX_<Tier> et rien.
s/slotPart\(box, "ItemName"\)\.Text == "Premium Box" and slotPart\(std, "ItemName"\)\.Text == "Standard Box", "ItemName des outils et des colis"/slotPart(box, "ItemName").Text == Items.ById.Z3_Smartphone.DisplayName and slotPart(std, "ItemName").Text == Items.ById.Z1_Banane.DisplayName, "a171 : ItemName des outils et des objets sous antivol"/
s/check\(slotPart\(box, "Icon"\)\.Image == "rbxassetid:\/\/9100" and slotPart\(std, "Icon"\)\.Image == HOTBAR_TEMPLATE_IMAGE, "ICON_BOX_Premium ; Standard pas livrée : l'image du Template"\)/check(slotPart(box, "Icon").Image == ICON_TEXTURE.Z3_Smartphone and slotPart(std, "Icon").Image == (ICON_TEXTURE.Z1_Banane or HOTBAR_TEMPLATE_IMAGE), `a171 : ICON_<ItemId> sur les objets sous antivol ({slotPart(std, "Icon").Image})`)/
s/and not slotPart\(box, "Income"\)\.Visible, "pas d'Income sur les outils ni les colis"/and slotPart(box, "Income").Visible, "a171 : pas d'Income sur les outils, Income sur l'objet sous antivol"/
