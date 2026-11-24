# a262 (vague 76, 2026-11-20) : banc a161 (grand socle, chance « 1 in N »). Shared/ItemOdds donne la VRAIE chance de
# l'objet (colis de sa zone, chance du joueur, classe de taille) : plus de caisse de référence (Vfx.RarestDisplay.OddsBox
# retiré, troisième argument ignoré). O5 à O10 vérifient la nouvelle forme (le calcul exact est vérifié par le banc a262) :
# chance entre 0 et 1, plus rare avec une mutation, OneIn = Formulas.UnboxOdds(chance), mutation inconnue ignorée.
if (has(q|local box = VfxCfg.RarestDisplay.OddsBox|)) {
	lit(q|local box = VfxCfg.RarestDisplay.OddsBox
local weights = ShelfOpenC.BoxRarityOdds[box]|, q|local box = nil :: any -- a262 : plus de caisse de référence (vague 76)
local weights = { Common = 1 }|, 'box');
	$t =~ s/local pc = weights\.Common.*?"O10 objet ou caisse inconnus : nil"\)/A262_O5_O10/s or die "a262 : O5-O10 introuvable\n";
	my $new = q|local FormulasC = requireModule(ReplicatedStorage.Shared.Config.Formulas, "client")
local pc = Odds.Chance(common.Id)
check(pc ~= nil and pc > 0 and pc < 1 and pc > (Odds.Chance(mythic.Id) or 1), `O5 a262 : Commun de zone 2, vraie chance entre 0 et 1, au-dessus du Mythique ({pc})`)
local plain = Odds.Chance(secret.Id)
local got = Odds.Chance(secret.Id, { Size = "Colossal", Effect = "Rainbow" })
check(got ~= nil and plain ~= nil and got < plain, `O6 a262 : Secret Colossal Rainbow plus rare que le Secret sans mutation ({got} < {plain})`)
check(Odds.OneIn(secret.Id, { Size = "Colossal", Effect = "Rainbow" }) == FormulasC.UnboxOdds(got), `O7 a262 : OneIn = Formulas.UnboxOdds(chance) ({Odds.Format(Odds.OneIn(secret.Id, { Size = "Colossal", Effect = "Rainbow" }))})`)
check(Odds.OneIn(secret.Id, { Size = "Nope" }) == Odds.OneIn(secret.Id, nil), "O8 mutation inconnue ignorée")
check(tutorial == nil or Odds.OneIn(tutorial.Id, nil) == nil, "O9 objet TutorialOnly : pas de chance")
check(Odds.OneIn("Nope", nil) == nil, "O10 a262 : objet inconnu : nil")|;
	lit(q|A262_O5_O10|, $new, 'O5-O10');
}
