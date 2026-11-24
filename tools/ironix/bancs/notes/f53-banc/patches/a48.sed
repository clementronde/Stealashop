# fusion53 (a191, vague 59, L-183) : la récompense de zone de l'Index est fixe, plus de +5 % de revenus par zone
# complète : le revenu permanent du scénario « bonus » n'a plus que Premium (+10 %) et ×2 Argent.
s/^local permanent = exposedB \* \(1 \+ 0\.1 \+ 0\.05\) \* 2(\r?)$/local permanent = exposedB * (1 + 0.1) * 2 -- fusion53 : plus de +5 % d'index (a191)\1/
