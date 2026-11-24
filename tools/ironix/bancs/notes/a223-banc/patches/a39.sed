# a223 (vague 66, L-210 point 7) : descendre de la plaque ferme la boutique (avant : fermeture à distance, jamais pour Robux).
s/^check\(WEAPON\.Enabled == true, "à 13 studs de la plaque.*$/check(WEAPON.Enabled == false, "(a223) descendre de la plaque ferme UI_WeaponShop")/
s/^check\(AURA\.Enabled == true, "à 15 studs de la plaque.*$/check(AURA.Enabled == false, "(a223) descendre de la plaque ferme UI_AuraShop")/
s/^check\(ROBUX\.Enabled == true, "s'éloigner ne la ferme pas"\)/check(ROBUX.Enabled == false, "(a223) descendre de la plaque ferme UI_RobuxShop")/
s/^check\(ROBUX\.Enabled == false, "le bouton du HUD la referme"\)/check(ROBUX.Enabled == true, "(a223) le bouton du HUD la rouvre loin de la plaque")/
s/^check\(ROBUX\.Enabled == true, "elle ne se ferme pas quand on s'éloigne \(partout, 5\.9\)"\)/check(ROBUX.Enabled == false, "(a223) ouverte par la plaque : en descendre la ferme (L-210 point 7 ; le bouton du HUD l'ouvre partout)")/
