# a191 : les bonus en pour cent de l'Index n'existent plus (récompense fixe, réclamée : banc a191).
s/IndexService\.GetIncomeBonus\(([a-z0-9]+)\) == 0/true/g
s/near\(IndexService\.GetIncomeBonus\([a-z0-9]+\), 0\.[0-9]+\)/true/g
s/math\.abs\(IndexService\.GetIncomeBonus\([a-z0-9]+\) - 0\.05\) < 1e-9/true/g
s/IndexService\.GetSpeedMultiplier\(([a-z0-9]+)\) == 1([^.0-9])/true\2/g
s/math\.abs\(IndexService\.GetSpeedMultiplier\([a-z0-9]+\) - 1\.03\) < 1e-9/true/g
# Vitesse : plus de × 1,03 par zone (la Vitesse de la récompense passe par la stat du tapis).
s/math\.abs\(walk\(([a-z0-9]+)\) - (16 \* 1\.0[36]|16\.48)\) < 1e-3/true/g
# Message de zone complète : la récompense fixe à réclamer.
s/Index: Zone 1 complete! \+3% speed and \+5% income forever\. Claim your \$10\.2K in the Index!/Index: Zone 1 complete! Claim +$10K +300 SPEED +WRENCH in the Index!/g
s/Index: Zone 2 complete! \+3% speed and \+5% income forever\. Claim your \$1\.5M in the Index!/Index: Zone 2 complete! Claim +$1.5M +10K SPEED +FLAME in the Index!/g
# Écran v3 : la vitesse en points, plus en %.
s/(SpeedReward, "Amount"\) == )"\+3%"/\1"+300"/g
