# a218 (vague 66, L-210 point 8) : Features.NewAuras passe à true. Ces bancs testent les 6 anciennes auras (Spark à
# Royal, achat, équipement, télémétrie, effets) : on les fait tourner avec NewAuras = false, chemin toujours dans le
# code ; le chemin des 8 auras est couvert par le banc a210 (les deux valeurs).
s/^([[:space:]]*)NewAuras = true,/\1NewAuras = false, -- a218 : banc des anciennes auras/
