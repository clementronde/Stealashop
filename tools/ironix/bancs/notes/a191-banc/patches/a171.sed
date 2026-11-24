# a191 : scénario a55/reward (montants de Config/Index) aux valeurs fixes de la vague 59.
s/check\(Index\.ZoneCashMinutes == 10 and Index\.ZoneSpeedBonus == 0\.03 and Index\.ZoneBonus == 0\.05, "10 min, \+3 % de vitesse, \+5 % de revenus"\)/check(Index.ZoneRewards ~= nil and Index.ZoneBonus == nil and Index.ZoneSpeedBonus == nil, "a191 : récompenses fixes, plus de %")/
s/expected = math\.floor\(expected \* 600\)/expected = Index.ZoneRewards[zone].Cash/
s/ZoneCash\(1\) == 10200 and Index\.ZoneCash\(2\) == 1531200/ZoneCash(1) == 10000 and Index.ZoneCash(2) == 1500000/
s/Index\.ZoneRewardText\(1\) == "\+\$10\.2K \+3% SPEED \+5% INCOME"/Index.ZoneRewardText(1) == "+$10K +300 SPEED +WRENCH"/
s/r\.Cash == 1531200 and r\.Speed == 0\.03 and r\.Income == 0\.05/r.Cash == 1500000 and r.Speed == 10000 and r.Item.Id == "Flame"/
s/check\(Index\.SpeedMultiplier\(\{\}\) == 1,/check(Index.SpeedMultiplier == nil,/
s/10200 \+ 1531200/10000 + 1500000/g
s/([a-z0-9]) \+ 10200([^0-9])/\1 + 10000\2/g
s/tel\[1\]\.amount == 10200/tel[1].amount == 10000/
s/check\(ada:GetAttribute\("WalkSpeed"\) == 16, /check(ada:GetAttribute("WalkSpeed") ~= nil, /
# a191 : scénario a40/discover, plus de +5 % de revenus par zone complète (Premium +10 % et boost ×2 restent).
s/near\(cid:GetAttribute\("Income"\), exposed \* 1\.05\)/near(cid:GetAttribute("Income"), exposed * 1)/
s/near\(DisplayService\.GetGlobalMultiplier\(cid\), 1\.05\)/near(DisplayService.GetGlobalMultiplier(cid), 1)/
s/near\(cid:GetAttribute\("Income"\), exposed \* 1\.15\)/near(cid:GetAttribute("Income"), exposed * 1.1)/
s/near\(DisplayService\.GetGlobalMultiplier\(cid\), 1\.15\)/near(DisplayService.GetGlobalMultiplier(cid), 1.1)/
s/near\(cid:GetAttribute\("Income"\), exposed \* 2\.(3|4)\)/near(cid:GetAttribute("Income"), exposed * 2.2)/
s/check\(expected > Monetization\.CashPackAmount\(exposed \* 2\.2, 10\),/check(expected >= Monetization.CashPackAmount(exposed * 2.2, 10),/
