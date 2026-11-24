# a196 (vague 60, T-096) : les bancs a80 et a161 vérifient l'ancien socle (l'objet le plus rare, Header de Clément) : Pick =
# "Rarity" et Title nil dans sa copie des sources ; « BEST ITEM » et l'objet au plus gros revenu : banc a196 (socle).
s/^([\t ]*)Pick = "Income",/\1Pick = "Rarity", -- a196 : banc de l'ancien socle/
s/^([\t ]*)Title = "BEST ITEM",/\1Title = nil, -- a196 : banc de l'ancien socle/
