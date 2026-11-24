# a294 (21/11, L-276) : les chances validées par Cantin ({ 30, 30, 25, 10, 4, 1 }) remplacent celles d'a218 dans Config :
# le scénario crate d'a208 pose toujours les siennes à leur place.
s/replaceSource\(M, "Odds = \{ 45, 28, 15, 7, 4, 1 \} :: \{ number \},", /replaceSource(M, "Odds = { 30, 30, 25, 10, 4, 1 } :: { number }, -- validé par Cantin, 21\/11", /
