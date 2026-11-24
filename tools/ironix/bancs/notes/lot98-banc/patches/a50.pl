# lot98-commun (petit chef 2) : a407 (outils de renaissance, Features.RebirthTools) ajoute Jackhammer et BatteringRam à
# Config/Tools ; la boutique d'armes en montre 9 (« Rebirth n » sur les deux derniers), et leurs icônes ICON_TOOL_ ne
# sont pas livrées (2 lignes « pas encore dans Assets/Icons » de plus). I10, S6 et S14 ne faisaient que compter ces échecs.
undef $/; $_ = <>;
s/logCount\("\[WeaponShop\] UI_WeaponShop branché : 7 outil\(s\)", "PRINT", "client"\) == 1, "I1 écran branché : 7 outils"\)/logCount("[WeaponShop] UI_WeaponShop branché : 9 outil(s)", "PRINT", "client") == 1, "I1 écran branché : 9 outils (a407 : Jackhammer et BatteringRam)")/;
s/check\(missing == 4, "I9 une ligne par icône manquante \(Crowbar, Sledgehammer, FireAxe, AngleGrinder\) : "/check(missing == 6, "I9 une ligne par icône manquante (Crowbar, Sledgehammer, FireAxe, AngleGrinder, Jackhammer, BatteringRam) : "/;
s/(logCount\("pas encore dans ReplicatedStorage\/Assets\/Icons", "PRINT", "client"\) == )4(, "I12 écran recréé)/${1}6$2/;
print;
