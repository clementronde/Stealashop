# a262 (vague 76, 2026-11-19) : banc a40 (index). Raretés réattribuées V0 : la Peluche géante et la Figurine holographique
# sont Peu communes en zone 2 (plus de Légendaire ni de Mythique en zone 2).
return unless has(q{"Peluche géante : rayons dorés (Légendaire)"});
lit(q{"Z2_PelucheGeante").Clip.Glow.ImageColor3, Rarities.ById.Legendary.Color), "Peluche géante : rayons dorés (Légendaire)"}, q{"Z2_PelucheGeante").Clip.Glow.ImageColor3, Rarities.ById.Uncommon.Color), "Peluche géante : rayons de sa rareté (a262 : Peu commun)"}, 'peluche');
lit(q{"Z2_FigurineHolographique").Clip.Rays.ImageColor3, Rarities.ById.Mythic.Color), "Figurine holographique : rayons rouges (Mythique)"}, q{"Z2_FigurineHolographique").Clip.Rays.ImageColor3, Rarities.ById.Uncommon.Color), "Figurine holographique : rayons de sa rareté (a262 : Peu commun)"}, 'figurine');
