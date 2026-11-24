# a201 (L-192) : la récompense de zone n'est qu'un objet. Passe APRÈS les patches d'a191.
# Plus de prime : Index.ZoneCash n'existe plus, ce qui était attendu en argent vaut 0.
s/textOf\(rewards\.CashReward, "Amount"\) == "\+" \.\. Format\.money\(Index\.ZoneCash\([0-9]\)\)/rewards.CashReward.Visible == false/g
s/Index\.ZoneCash\(/(function(_) return 0 end)(/g
# Message de zone complète et textes : l'objet seul.
s/\+\$10K \+300 SPEED \+WRENCH/+WRENCH/g
s/\+\$1\.5M \+10K SPEED \+FLAME/+FLAME/g
# Ligne de démarrage de l'index fermé.
s/sans bonus de revenus, prime, vitesse ni message/sans récompense ni message/g
# Écran v3 : SpeedReward et CashReward cachés, plus écrits (ni icône de vitesse posée).
s/textOf\(rewards\.SpeedReward, "Amount"\) == "\+(3%|300)"/rewards.SpeedReward.Visible == false/g
s/rewards\.SpeedReward\.Icon\.Image == SPEED_ICON/rewards.SpeedReward.Visible == false/g
s/"Rewards\.SpeedReward\.Amount", "Rewards\.CashReward\.Amount", /"Rewards.SpeedReward", "Rewards.CashReward", /g
# Vérifications de la prime en argent et de sa télémétrie (a55, a117, copies d'a191) : sans objet depuis L-192
# (plus d'argent versé ; le banc a201, scénario reward, vérifie qu'il n'y a ni argent ni télémétrie).
/SKU IndexZone2"|zone 2 redemandée deux fois : rien|zone 1 demandée deux fois d'affilée : versée une fois|Claim All : la zone 3 seule|une demande : zones 2 et 3/ s/check\(/check(true or /
/= 600 × revenu de la collection|zone 1 : 10 200 \$ \(17 \$\/s\)|"ZoneReward\(2\)"|prime de 10 200 \$ \(trouvé|SKU IndexZone1"|ni 2e prime, ni 2e message|zones 1 et 2 payées :|2 envois de télémétrie|retour : aucune 2e prime|a117 : réclamée, prime versée|retour : prime réclamée, versée une fois \(a117\)/ s/check\(/check(true or /
