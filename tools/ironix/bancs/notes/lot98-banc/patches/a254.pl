# lot98-commun (petit chef 2) : a412 (textes) : le message en file de la chance du serveur devient « Bob gave the server ×2
# LUCK for 15 min! Starts after the current one. » (textes.pl d'a412 l'a déjà changé dans le banc) ; il ne contient plus
# « gave the whole server », que le cas A4 coupé cherchait pour compter les 2 Notify. Il cherche « LUCK for 15 min ».
undef $/; $_ = <>;
s/local n = notes\(t0, cara, "gave the whole server"\)/local n = notes(t0, cara, "LUCK for 15 min") -- lot98-commun : a412/;
print;
