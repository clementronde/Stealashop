# a262 (vague 76, 2026-11-19) : banc a28 (tutoriel). Plus de Tutorial.FirstBoxTier ni de type de colis (le payload de
# l'objet sorti n'a plus de Tier) : le colis garanti reste le Pot de nouilles (Rare).
return unless has(q{"Pot de nouilles : TutorialOnly, zone 1, Rare ; colis Premium"});
lit(q{ and Tutorial.FirstBoxTier == "Premium", "Pot de nouilles : TutorialOnly, zone 1, Rare ; colis Premium"}, q{, "Pot de nouilles : TutorialOnly, zone 1, Rare (a262 : plus de type de colis)"}, 'FirstBoxTier');
lit(q{check(payload.Tier == "Premium" and payload.ItemId}, q{check(payload.ItemId}, 'payload');
lit(q{check(p.Tier == "Premium" and p.ItemId == "Z1_PotDeNouilles"}, q{check(p.ItemId == "Z1_PotDeNouilles"}, 'kiosque');
