# lot98-commun (petit chef 2) : a411 (cabine d'essayage, L-113) ajoute la tuile FittingRoom sans RequiresRebirth
# (Config/SkillTree, voulu : « la tuile elle-même n'en demande aucune ») : 7 tuiles au premier anneau au lieu de 6.
undef $/; $_ = <>;
s/check\(open183 == 6, `\(a183\) G0b les 6 tuiles/check(open183 == 7, `(a183, lot98 a411) G0b les 7 tuiles (FittingRoom comprise)/;
print;
