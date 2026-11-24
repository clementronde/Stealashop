# a431 (L-332) : Labels chiffrés ; Cameras niveau 1 = « hit alert » (alerte seule, Effects[1] = 0) au lieu de « I ».
undef $/; $_ = <>;
s/msg == "Cameras upgraded: I!"/msg == "Cameras upgraded: hit alert!" --[[ a431 ]]/g;
print;
