# lot98-commun (petit chef 2) : a407 (outils de renaissance) ajoute Jackhammer et BatteringRam : la boutique d'armes en montre 9 (comme a50).
undef $/; $_ = <>;
s/logCount\("\[WeaponShop\] UI_WeaponShop branché : 7 outil\(s\)", "PRINT", "client"\) >= 1, "E0 écran branché : 7 outils"\)/logCount("[WeaponShop] UI_WeaponShop branché : 9 outil(s)", "PRINT", "client") >= 1, "E0 écran branché : 9 outils (a407)")/ or die "a304.pl : E0 absent\n";
print;
