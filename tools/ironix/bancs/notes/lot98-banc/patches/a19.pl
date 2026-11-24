# lot98-commun (petit chef 2) : a412 (textes en anglais, mot « display ») : l'invite d'achat d'un présentoir dit
# « Unlock display ($500) » (TEXT.UnlockStand = "Unlock display (%s)") ; textes.pl d'a412 ne changeait que « "Unlock stand" »
# entre guillemets, pas la phrase avec le prix. Sans Floor_2 dans le faux arbre, a280 ne change rien (« Displays 4/20 »).
# U25 et F7 ne faisaient que compter ces deux échecs.
undef $/; $_ = <>;
s/sp\.ActionText == "Unlock stand \(\$500\)"/sp.ActionText == "Unlock display (\$500)"/;
s/sp\.ActionText == "Unlock stand \(\$1\.2K\)"/sp.ActionText == "Unlock display (\$1.2K)"/;
print;
