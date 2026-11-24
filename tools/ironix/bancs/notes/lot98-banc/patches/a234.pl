# lot98-commun (petit chef 2) : a317 (L-304 Q2, validé par Cantin) retire la hauteur du flottement (DisplayMotion.Headroom,
# 1,8 stud, plus ItemIdle.BobHeight pour Bob et SpinBob) au FitSize lu : la réduction se calcule sur fitBox, toujours
# avant le halo et le billboard. Le contrôle de texte cherche la nouvelle ligne et la marge.
undef $/; $_ = <>;
s/local fitAt = string\.find\(text, "local fit = if fitSize then fitFactor\(display, pivot, fitSize\) else 1", 1, true\)/local fitAt = string.find(text, "local fit = if fitBox then fitFactor(display, pivot, fitBox) else 1", 1, true) -- lot98-commun : a317\n\tif fitAt and not string.find(text, "local room = fitBox.Y - DisplayMotion.Headroom - bob", 1, true) then fitAt = nil end/;
print;
