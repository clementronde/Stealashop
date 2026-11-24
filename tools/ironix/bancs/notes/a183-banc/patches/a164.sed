# a183 (vague 56, L-173), banc a164 (renaissance), après les correctifs d'a176 : plus de « Tapis ×1,5 » (RebirthService ne
# remplace plus TrainingService.GetGainMultiplier), plus de récompense cosmétique ni d'outil dans Config/Rebirths.
s/GetGainMultiplier\(P1, "Treadmill"\) == 1\.5 and FAKES\.PvPService\.GetVaultSlots\(P1\) == 1, "\(a176\) S6 [^"]*"/GetGainMultiplier(P1, "Treadmill") == 1 and FAKES.PvPService.GetVaultSlots(P1) == 1, "(a183) S6 allumé : revenus ×2,5, tapis ×1 (plus de Tapis ×1,5)"/
s/and math\.abs\(gain - c\[3\]\) < 1e-9 and vault == 3, `\(a176, coffres toujours 3\) B /and gain == 2 and vault == 3, `(a183 : tapis toujours ×2, celui d'avant) B /
/"B2 le bonus de tapis ne touche que le tapis"\)$/a\
	local R183 = Config.Rebirths\
	check(R183.TreadmillMultiplier == nil and R183.HasReward == nil and R183.ExtraSafes == nil, "(a183) R1 plus de TreadmillMultiplier, HasReward ni ExtraSafes")\
	local bare183 = true\
	for _, tier in R183.Tiers do\
		if tier.Effect ~= nil or tier.Value ~= nil or tier.Reward ~= nil then\
			bare183 = false\
		end\
	end\
	check(bare183, "(a183) R2 aucun palier n'a plus d'Effect, de Value ni de Reward (aura, trail, outil, agent)")\
	check(R183.IncomeMultiplier(0) == 1 and R183.IncomeMultiplier(1) == 1.5 and R183.IncomeMultiplier(2) == 2 and R183.IncomeMultiplier(10) == 6, "(a183) R3 multiplicateur d'argent : ×1, ×1,5, ×2, ×6 à la 10e")\
	check(R183.Tiers[1].RewardText == "New skill: Lock" and R183.Tiers[2].RewardText == "New skill: Potion Time" and R183.Tiers[3].RewardText == "New skill: Door Guard" and R183.Tiers[4].RewardText == "New skill: Traps", "(a183) R4 paliers 1 à 4 : une tuile de l'arbre chacun")\
	check(R183.Tiers[5].RewardText == "" and R183.Tiers[10].RewardText == "" and R183.Get(11).RewardText == "", "(a183) R5 paliers 5 et suivants : aucune tuile")\
	check(R183.TitleText(0) == nil and R183.TitleText(1) == "REBIRTH 1" and R183.TitleText(12) == "REBIRTH 12" and R183.TitleText(0 / 0) == nil, "(a183) R6 titre dès la 1re : REBIRTH n")\
	check(R183.Title.Billboard == "BB_RebirthTitle" and R183.Title.Label == "TitleLabel", "(a183) R7 noms du titre : BB_RebirthTitle, TitleLabel")
