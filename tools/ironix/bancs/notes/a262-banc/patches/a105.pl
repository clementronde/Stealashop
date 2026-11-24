# a262 (vague 76, 2026-11-20) : banc a105 (antivol en base). Raretés du catalogue réattribuées : la Télé géante est
# Peu commune ; l'Épique du banc devient le Diamant brut, Épique de la zone 4 (même antivol, celui de l'Épique).
# Code du banc seulement (après le dernier bloc SOURCES : Config/Items cite aussi la Télé géante).
{
	my $cut = rindex($t, "]==========]");
	$cut = $cut < 0 ? 0 : $cut;
	my $head = substr($t, 0, $cut);
	my $tail = substr($t, $cut);
	$tail =~ s/"Z3_TeleGeante", "Epic", 3/"Z4_DiamantBrut", "Epic", 4/g;
	$tail =~ s/Id = "Z3_TeleGeante", Source = "NPC", At = 1, Zone = 3,/Id = "Z4_DiamantBrut", Source = "NPC", At = 1, Zone = 4,/g;
	$tail =~ s/"Z3_TeleGeante"/"Z4_DiamantBrut"/g;
	$t = $head . $tail;
}
# Nom affiché : « Big Rough Diamond ». Scénario robux : le Smartphone est Peu commun (antivol plus court) ; le Rare de
# 20 s du banc devient la Console de salon (Rare de la zone 3).
lit(q|view.ItemText == "Big Giant TV"|, q|view.ItemText == "Big Rough Diamond"|, 'nom') if has(q|view.ItemText == "Big Giant TV"|);
lit(q|local uid2 = bringItem(ada, "Z3_Smartphone", "Rare", 3)|, q|local uid2 = bringItem(ada, "Z3_ConsoleDeSalon", "Rare", 3) -- a262|, 'Rare 20 s') if has(q|"reste 40 s de crédit"|);
