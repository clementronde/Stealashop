# a262 (vague 76, 2026-11-19) : banc a96 (bot). Les Communs de la zone 1 rapportent de 1 à 2,853 $/s selon leur rang
# (1,1^(rang − 1)) : la valeur exposée du bot est la somme des revenus de ses objets, plus 4 ou 3 $/s.
inc('near');
$t = "A262_BOTSUM = function(models: any): number\n\tlocal sum = 0\n\tfor _, m in models do\n\t\tsum += m:GetAttribute(\"Income\") or 0\n\tend\n\treturn sum\nend\nA262_COMMON1 = function(v: any): boolean\n\treturn type(v) == \"number\" and v >= 1 - 1e-9 and v < 2.86\nend\n" . $t unless has('A262_BOTSUM = function');
if (has(q{"chaque objet : un Commun de la zone 1 du catalogue, 1 $/s, OwnerUserId = 0"})) {
	lit(q{model:GetAttribute("OwnerUserId") ~= 0 or model:GetAttribute("Income") ~= 1 then}, q{model:GetAttribute("OwnerUserId") ~= 0 or not A262_COMMON1(model:GetAttribute("Income")) then}, 'objets');
	lit(q{"chaque objet : un Commun de la zone 1 du catalogue, 1 $/s, OwnerUserId = 0"}, q{"chaque objet : un Commun de la zone 1 du catalogue, 1 à 2,853 $/s (a262), OwnerUserId = 0"}, 'objets msg');
	lit(q{exposed[1] and exposed[1].Income == 1, "GetExposed : 4 objets, 1 $/s chacun")}, q{exposed[1] and A262_COMMON1(exposed[1].Income), "GetExposed : 4 objets, 1 à 2,853 $/s chacun (a262)")}, 'exposed') if has(q{exposed[1] and exposed[1].Income == 1, "GetExposed});
	lit(q{check(plot:GetAttribute("BotIncome") == 4 and BotService.GetIncome(plot) == 4, "valeur exposée du bot : 4 $/s (attribut BotIncome)")}, q{check(A262_NEAR(plot:GetAttribute("BotIncome"), A262_BOTSUM(botModels(plot))) and A262_NEAR(BotService.GetIncome(plot), A262_BOTSUM(botModels(plot))), "valeur exposée du bot : somme de ses 4 objets (attribut BotIncome, a262)")}, 'bot 4');
}
if (has(q{"le présentoir 2 du bot se vide, valeur exposée 3 $/s"})) {
	lit(q{check(panel.Income == "+$4/s", `panneau : valeur exposée « +$4/s »}, q{check(string.match(panel.Income or "", "^%+%$[%d%.]+/s$") ~= nil, `panneau : valeur exposée « +$x/s » (a262)}, 'panneau');
	lit(q{check(#botModels(plot) == 3 and plot:GetAttribute("BotIncome") == 3, "le présentoir 2 du bot se vide, valeur exposée 3 $/s"}, q{check(#botModels(plot) == 3 and A262_NEAR(plot:GetAttribute("BotIncome"), A262_BOTSUM(botModels(plot))), "le présentoir 2 du bot se vide, valeur exposée : ses 3 objets (a262)"}, 'bot 3');
	lit(q{check(placed and bob:GetAttribute("Income") == 1, `exposé tout de suite chez Bob, 1 $/s}, q{check(placed and A262_COMMON1(bob:GetAttribute("Income")), `exposé tout de suite chez Bob, 1 à 2,853 $/s}, 'bob');
	lit(q{check(#botModels(plot) == 4 and plot:GetAttribute("BotIncome") == 4, "4 objets exposés, 4 $/s")}, q{check(#botModels(plot) == 4 and A262_NEAR(plot:GetAttribute("BotIncome"), A262_BOTSUM(botModels(plot))), "4 objets exposés, leur somme (a262)")}, 'bot 4b');
}
