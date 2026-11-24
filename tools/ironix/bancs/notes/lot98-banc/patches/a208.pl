# lot98-commun (petit chef 2) : banc a208 (boutique Robux v2, copie a294) sur le lot 98. a319 (L-303, décision de Cantin) :
# « ×2 Speed » n'est plus le boost SpeedBoost de 10 min (retiré de Config/Boosts et de ShopBoosts) mais le gamepass
# permanent DoubleSpeed (Order 3, 149 R$, UI_Icon_SpeedBoost, CardColor F2553A, HudButton SpeedBoostButton).
#  - ShopBoosts : zZz seul ; l'onglet Boosts : SleepGuards puis Ouvrir maintenant ; 6 gamepasses codés.
#  - La carte « ×2 Speed » est cherchée sous la clé DoubleSpeed (onglet Gamepasses) : nom, « Soon » à l'Id 0, Effect,
#    couleur F2553A, clic en vitrine sans achat.
#  - live, « boosts du HUD : pas codés » : seul zZz reste un boost ; plus de carte SpeedBoost.
undef $/; $_ = <>;
s/local sameProduct = #Monetization\.ShopBoosts == 2/local sameProduct = #Monetization.ShopBoosts == 1 -- lot98-commun : a319, zZz seul/;
s/check\(Monetization\.ShopBoosts\[1\]\.Key == "SpeedBoost" and Monetization\.ShopBoosts\[1\]\.Boost\.Price == 29 and Monetization\.ShopBoosts\[1\]\.Icon == "UI_Icon_SpeedBoost", "×2 Speed : 29 R\$, UI_Icon_SpeedBoost"\)/do -- lot98-commun : a319\n\tlocal ds = Monetization.PassByKey.DoubleSpeed\n\tcheck(ds ~= nil and ds.Order == 3 and ds.Price == 149 and ds.Icon == "UI_Icon_SpeedBoost" and ds.HudButton == "SpeedBoostButton", "×2 Speed : gamepass DoubleSpeed, 3e, 149 R\$, UI_Icon_SpeedBoost (a319)")\nend/;
s/Monetization\.ShopBoosts\[2\]\.Key == "SleepGuards" and Monetization\.ShopBoosts\[2\]\.Boost\.Price == 79 and Monetization\.ShopBoosts\[2\]\.Icon == "UI_Icon_Sleep"/Monetization.ShopBoosts[1].Key == "SleepGuards" and Monetization.ShopBoosts[1].Boost.Price == 79 and Monetization.ShopBoosts[1].Icon == "UI_Icon_Sleep"/;
s/v2Keys\(V2, "BoostsSection"\) == "SpeedBoost,SleepGuards,OpenNow"/v2Keys(V2, "BoostsSection") == "SleepGuards,OpenNow"/;
s/offerKeys\(OLD\) == "DoubleCash,DoubleTraining,AutoCollect,FastOpen,ExtraStands"/offerKeys(OLD) == "DoubleCash,DoubleTraining,DoubleSpeed,AutoCollect,FastOpen,ExtraStands"/g;
s/offerKeys\(OLD\) == "SpeedBoost,SleepGuards,OpenNow"/offerKeys(OLD) == "SleepGuards,OpenNow"/;
s/click\(v2Card\(V2, "SpeedBoost"\):FindFirstChild\("BuyButton"\)\)(\r?\nclick\(v2Card\(V2, "SleepGuards"\):FindFirstChild\("BuyButton"\)\)\r?\n)check\(textOf\(v2Card\(V2, "SpeedBoost"\), "Price"\) == "Soon" and textOf\(v2Card\(V2, "SleepGuards"\), "Price"\) == "Soon", "×2 Speed et zZz : « Soon »"\)/-- lot98-commun : a319, ×2 Speed n'est plus un boost du HUD (gamepass DoubleSpeed)$1check(v2Card(V2, "Speed" .. "Boost") == nil and textOf(v2Card(V2, "SleepGuards"), "Price") == "Soon", "zZz : « Soon » ; plus de carte SpeedBoost (a319)")/;
s/v2Card\(V2, "SpeedBoost"\)/v2Card(V2, "DoubleSpeed")/g;
print;
