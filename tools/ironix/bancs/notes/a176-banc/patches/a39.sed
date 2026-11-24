# a176 (vague 54), banc a39 : 2e renaissance sans récompense (Effect « None », RewardText vide, ligne Row2 cachée), plus d'ExtraSafes.
s/\{ 500e9, "Z6_TroneEnOr", "Epic", 6, "Safe", 956 \}/{ 500e9, "Z6_TroneEnOr", "Epic", 6, "None", 956 }/
s/tier\.RewardText ~= "" and type\(tier\.Reward\)/(tier.RewardText ~= "" or level == 2) and type(tier.Reward)/
s/^check\(Rebirths\.ExtraSafes\(1\) == 0 .*$/check(Rebirths.ExtraSafes == nil, "(a176) plus de coffre-fort : Rebirths.ExtraSafes retiré")/
s/el\("GainList\.Row2\.RowLabel"\)\.Text == "\+1 Safe" and shown\(\) == "Disabled", "récompense « \+1 Safe », Disabled"/el("GainList.Row2").Visible == false and shown() == "Disabled", "(a176) palier 2 sans récompense : ligne Row2 cachée, Disabled"/
