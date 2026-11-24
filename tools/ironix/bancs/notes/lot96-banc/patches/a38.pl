# lot96 : a275 passe Receipts.History de 100 à 500 ; le cas « historique borné » remplissait 100 achats en dur.
undef $/; $_ = <>;
s/(local eve = newProfile\(\)\r?\nfor index = 1, )100( do)/$1Monetization.Receipts.History$2/;
print;
