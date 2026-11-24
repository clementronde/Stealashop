# a262 (vague 76, 2026-11-19) : banc a169. Plus de Tutorial.FirstBoxTier (les colis du rayon n'ont plus de type).
return unless has(q{"gardés : FirstBoxTier, GuaranteedItemId, AntiTheftDelay 5 s"});
lit(q{check(Tutorial.FirstBoxTier == "Premium" and Tutorial.GuaranteedItemId}, q{check(Tutorial.FirstBoxTier == nil and Tutorial.GuaranteedItemId}, 'FirstBoxTier');
lit(q{"gardés : FirstBoxTier, GuaranteedItemId, AntiTheftDelay 5 s"}, q{"gardés : GuaranteedItemId, AntiTheftDelay 5 s (a262 : FirstBoxTier retiré)"}, 'msg');
