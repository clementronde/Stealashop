# a262 (vague 76, 2026-11-19) : banc a139 (copie du banc a104). Le client lit la BoxRarity du colis (invite « <Rareté> Box »,
# maintien de sa rareté) : faux colis avec la rareté du même temps de prise (patches/boxtier.pl).
return unless has(q{"une invite sur le colis"});
inc('boxtier');
lit(q{p1.ObjectText == std.DisplayName .. " Box"}, q{p1.ObjectText == "Common Box"}, 'ObjectText') if has(q{p1.ObjectText == std.DisplayName .. " Box"});
lit(q|makeItem(4, { Rarity = "Rare", Tier = "Premium", ShelfReservedBy = 1|, q|makeItem(4, { Rarity = "Rare", Tier = "Premium", BoxRarity = "Rare", ShelfReservedBy = 1|, 'objet réservé') if has(q|makeItem(4, { Rarity = "Rare", Tier = "Premium", ShelfReservedBy = 1|);
