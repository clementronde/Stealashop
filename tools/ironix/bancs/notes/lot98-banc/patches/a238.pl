# lot98-commun (petit chef 2) : a319 (L-303) retire le boost SpeedBoost : Config/Monetization.ShopBoosts = { SleepGuards }
# seul, zZz passe de la 2e à la 1re place (le banc lisait ShopBoosts[2], devenu nil : scénario v2 arrêté).
undef $/; $_ = <>;
s/Monetization\.ShopBoosts\[2\]\.Key == "SleepGuards" and Monetization\.ShopBoosts\[2\]\.DisplayName/#Monetization.ShopBoosts == 1 and Monetization.ShopBoosts[1].Key == "SleepGuards" and Monetization.ShopBoosts[1].DisplayName/g;
print;
