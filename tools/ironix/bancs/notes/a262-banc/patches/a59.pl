# a262 (vague 76, 2026-11-19) : banc a59 = scénarios d'a14 (patches/a14.pl), puis les siens (tests.a59.luau) : le smartphone
# (Peu commun, 11 $/s) laisse sa place à la Console de salon (Rare de zone 3, 60 $/s) ; montants des plaques × 61 / 301.
inc('a14');
return unless has(q{"Income = 301 $/s"});
lit(q{give(data, "Z3_Smartphone")}, q{give(data, "Z3_ConsoleDeSalon")}, 'phone');
lit(q{alice:GetAttribute("Income") == 301,}, q{alice:GetAttribute("Income") == 61,}, '301');
lit(q{v1 >= 600 and v1 <= 920}, q{v1 >= 121 and v1 <= 187}, 'v1');
lit(q{v5 >= 1500 and v5 <= 2800}, q{v5 >= 300 and v5 <= 560}, 'v5');
lit(q{(lastOut().amount or 0) >= 290}, q{(lastOut().amount or 0) >= 58}, 'amount');
lit(q{v1c ~= nil and v1c >= 500}, q{v1c ~= nil and v1c >= 101}, 'v1c');
lit(q{v1d ~= nil and v1d <= 340}, q{v1d ~= nil and v1d <= 69}, 'v1d');
