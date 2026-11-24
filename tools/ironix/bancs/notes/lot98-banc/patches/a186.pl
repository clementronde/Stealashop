# lot98-commun (petit chef 2) : a407 ajoute BatteringRam (Order 9) à Config/Tools ; Shared/ShopCardTier borne le rang au
# nombre de raretés (math.clamp, 8 = Divine), mais la table TIERS du banc n'a que 8 paliers : TIERS[9] = nil et le banc
# s'arrêtait (« attempt to index nil with 'Id' »). Même borne que le jeu.
undef $/; $_ = <>;
s/checkTier\(rowOf\(wlist, "_" \.\. tool\.Id\), TIERS\[tool\.Order\], "W" \.\. tool\.Order/checkTier(rowOf(wlist, "_" .. tool.Id), TIERS[math.min(tool.Order, #TIERS)], "W" .. tool.Order/;
print;
