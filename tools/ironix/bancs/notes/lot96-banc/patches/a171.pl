# lot96 (a274, audit a272 H1) : la fin d'achat d'un gamepass ne donne plus rien sur le seul signal, le serveur demande
# d'abord à Roblox (UserOwnsGamePassAsync). Scénario a38/client (copie dans a171) : Ada possède le pass chez Roblox
# (MARKET.owns) avant le signal, et le temps avance pour la réponse.
undef $/; $_ = <>;
s/(\n)(finishPassPurchase\(ada, PASS_IDS\.DoubleCash, true\) -- côté serveur : l'attribut PassDoubleCash suit\r?\n)(flush\(\))/$1MARKET.owns[ada.UserId] = MARKET.owns[ada.UserId] or {}\nMARKET.owns[ada.UserId][PASS_IDS.DoubleCash] = true\n$2advance(2)\n$3/;
print;
