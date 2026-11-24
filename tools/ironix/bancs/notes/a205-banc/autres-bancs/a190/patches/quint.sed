# a190 (vague 59, L-182 point 4) : le décompte de Cash après un achat est en Quint Out : courbe ajoutée au faux
# TweenService (ext-motion.luau), juste avant Quart (ajout pur ; un doublon de clé ne change rien).
s/^([\t ]*)\["Enum\.EasingStyle\.Quart"\] = function\(u\)(\r?)$/\1["Enum.EasingStyle.Quint"] = function(u) return u * u * u * u * u end, -- a190\2\n\1["Enum.EasingStyle.Quart"] = function(u)\2/
