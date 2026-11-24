# lot98-commun (petit chef 2) : a319 (L-303, décision de Cantin) : DoubleSpeed est le 3e gamepass (6 cartes codées) et le
# boost SpeedBoost est retiré de Config/Boosts : l'onglet Boosts montre SleepGuards puis Ouvrir maintenant. Le cas a218
# (Ouvrir maintenant sans palier créé) ne changeait que par cette liste ; le reste de son contrôle est gardé tel quel.
undef $/; $_ = <>;
s/offerKeys\(ROBUX\) == "DoubleCash,DoubleTraining,AutoCollect,FastOpen,ExtraStands"/offerKeys(ROBUX) == "DoubleCash,DoubleTraining,DoubleSpeed,AutoCollect,FastOpen,ExtraStands"/g;
s/offerKeys\(ROBUX\) == "SpeedBoost,SleepGuards,OpenNow" and textOf\(openNow, "Effect"\) == "No item is waiting"/offerKeys(ROBUX) == "SleepGuards,OpenNow" and textOf(openNow, "Effect") == "No item is waiting"/;
s/#cardsOf\(ROBUX\) == 5, "la plaque ouvre UI_RobuxShop en vitrine \(5 gamepasses\)"\)/#cardsOf(ROBUX) == 6, "la plaque ouvre UI_RobuxShop en vitrine (6 gamepasses, DoubleSpeed d'a319)")/;
s/#cardsOf\(ROBUX\) == 5, "rester sur la plaque, écran ouvert : rien ne change"\)/#cardsOf(ROBUX) == 6, "rester sur la plaque, écran ouvert : rien ne change")/;
print;
