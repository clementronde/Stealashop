# a238 (vague 71, L-213 point 3a) : les cartes de l'Index vont du moins rare au plus rare (Rarities.Order),
# dans l'ordre du catalogue à égalité ; l'ordre attendu du scénario v2 suit.
s#^(\t)for index, item in Index\.ByZone\[zone\] do(\r?)$#\1for index, item in (function(l) local s = table.clone(l); local p = {}; for i, it in l do p[it] = i end; table.sort(s, function(a, b) local ra, rb = Rarities.ById[a.Rarity].Order, Rarities.ById[b.Rarity].Order; if ra ~= rb then return ra < rb end; return p[a] < p[b] end); return s end)(Index.ByZone[zone]) do\2#
s#cartes dans Zone\{zone\}Section\.Cards, ordre du catalogue#cartes dans Zone{zone}Section.Cards, du moins rare au plus rare (a238)#
