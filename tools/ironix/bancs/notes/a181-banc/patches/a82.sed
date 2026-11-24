# a181 (L-161, Clément : Min 0,6) : WingLight du tapis Gold pulse de 0,6 à 1,2.
s/check\("4 Gold : WingLight à 1,2 \(L-142 : Min = Max = 1,2\)", math\.abs\(gold\.GoldFX\.WingFX\.WingLight\.Brightness - 1\.2\) < 1e-6\)/check("4 Gold : WingLight entre 0,6 et 1,2 (L-161, a181)", gold.GoldFX.WingFX.WingLight.Brightness >= 0.6 - 1e-6 and gold.GoldFX.WingFX.WingLight.Brightness <= 1.2 + 1e-6)/
