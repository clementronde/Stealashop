# a262 (vague 76, 2026-11-20) : banc a154 (objet ramené, flash de la révélation). Le Smartphone est devenu Peu commun
# (raretés du catalogue réattribuées) : I1 prend la Console de salon, objet Rare de la zone 3 sans icône livrée.
if (has(q{I1d Subtitle « Rare Smartphone »})) {
	lit(q{NetServer.Server.ItemSecured:Fire(P1, "Z3_Smartphone")}, q{NetServer.Server.ItemSecured:Fire(P1, "Z3_ConsoleDeSalon") -- a262 : objet Rare}, 'I1 objet');
	lit(q{check(subtitle.Text == "Rare Smartphone", `I1d Subtitle « Rare Smartphone » ({subtitle.Text})`)}, q{check(subtitle.Text == "Rare Home Console", `I1d a262 : Subtitle « Rare Home Console » ({subtitle.Text})`)}, 'I1d');
}
