# a238 (vague 71, L-213 point 3a) : les cartes de l'Index vont du moins rare au plus rare (Rarities.Order),
# dans l'ordre du catalogue à égalité ; l'ordre attendu du scénario client suit.
s#^for index, item in Index\.ByZone\[1\] do(\r?)$#for index, item in (function(l) local s = table.clone(l); local p = {}; for i, it in l do p[it] = i end; table.sort(s, function(a, b) local ra, rb = Rarities.ById[a.Rarity].Order, Rarities.ById[b.Rarity].Order; if ra ~= rb then return ra < rb end; return p[a] < p[b] end); return s end)(Index.ByZone[1]) do\1#
s#13 cartes, dans l'ordre du catalogue \(#13 cartes, du moins rare au plus rare (a238) (#
