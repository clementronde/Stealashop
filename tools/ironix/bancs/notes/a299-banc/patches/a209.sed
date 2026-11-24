# a299 : les cases ne bougent plus (OddBob = 0) ; S3 lit le réglage au lieu de ± 4 px en dur.
s/near\(p0\.OddY\[2\], 4 \* math\.sin\(0\.9\), 1e-9\) and near\(p0\.OddY\[3\], 4 \* math\.sin\(1\.8\), 1e-9\)/near(p0.OddY[2], ShopFx.Crate.OddBob * math.sin(0.9), 1e-9) and near(p0.OddY[3], ShopFx.Crate.OddBob * math.sin(1.8), 1e-9)/
