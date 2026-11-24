# a183 (vague 56, L-173 et L-168 Q4), banc a39 (aperçu et écran UI_Rebirth), après les correctifs d'a176 : la récompense d'un
# palier = les tuiles de l'arbre qu'il ouvre (RewardText), plus d'Effect, de Reward, de Value, de TreadmillMultiplier ni de
# HasReward ; « Owned! » à la couleur de l'attribut OwnedColor de Status.
s/^(\t\{ 20e9, "Z6_DiamantGeant", "Rare", 6, )"Aura"(, 494 \},)$/\1"New skill: Lock"\2/
s/^(\t\{ 500e9, "Z6_TroneEnOr", "Epic", 6, )"None"(, 956 \},)$/\1"New skill: Potion Time"\2/
s/^(\t\{ 1\.3e12, "Z6_StatueDeLaLiberte", "Epic", 6, )"Treadmill"(, 1369 \},)$/\1"New skill: Door Guard"\2/
s/^(\t\{ 2e12, "Z2_PelucheGeante", "Legendary", 2, )"Trail"(, 1808 \},)$/\1"New skill: Traps"\2/
s/^(\t\{ 2\.6e12, "Z3_PcGamer", "Legendary", 3, )"Tool"(, 2195 \},)$/\1""\2/
s/^(\t\{ 3\.2e12, "Z4_Couronne", "Legendary", 4, )"Treadmill"(, 2530 \},)$/\1""\2/
s/^(\t\{ 5e12, "Z5_MasqueAncien", "Legendary", 5, )"Tool"(, 2991 \},)$/\1""\2/
s/^(\t\{ 7e12, "Z6_CoffreDeDiamants", "Legendary", 6, )"Guard"(, 3359 \},)$/\1""\2/
s/^(\t\{ 7\.5e12, "Z6_CleDuCoffreUltime", "Mythic", 6, )"Aura"(, 3846 \},)$/\1""\2/
s/^(\t\{ 9e12, "Z6_CleDuCoffreUltime", "Mythic", 6, )"Title"(, 4207 \},)$/\1""\2/
s/ and tier\.Effect == row\[5\] and / and tier.RewardText == row[5] and tier.Effect == nil and tier.Reward == nil and tier.Value == nil and /
s/ and \(tier\.RewardText ~= "" or level == 2\) and type\(tier\.Reward\) == "string", / and tier.RewardText == Rebirths.RewardText(level), /
s/^check\(Rebirths\.Tiers\[1\]\.RewardText == "Rebirth Aura", .*$/check(Rebirths.Tiers[1].RewardText == "New skill: Lock" and Rebirths.Get(11).RewardText == "", "(a183) renaissance 1 : la tuile Lock ; au-delà du tableau : aucune tuile")/
s/^check\(Rebirths\.TreadmillMultiplier\(2\) == 1 .*$/check(Rebirths.TreadmillMultiplier == nil and Rebirths.HasReward == nil, "(a183) plus de Tapis ×1,5 ni de récompense notée : TreadmillMultiplier et HasReward retirés")/
s/^check\(Rebirths\.HasReward\(4, "Trail"\) .*$/check(Rebirths.TitleText(0) == nil and Rebirths.TitleText(1) == "REBIRTH 1" and Rebirths.Title.Billboard == "BB_RebirthTitle" and Rebirths.Title.Label == "TitleLabel", "(a183) titre dès la 1re renaissance : BB_RebirthTitle, TitleLabel, REBIRTH n")/
s/^check\(el\("GainList\.Row2\.RowLabel"\)\.Text == "Rebirth Aura", .*$/check(el("GainList.Row2.RowLabel").Text == "New skill: Lock", `(a183) GainList : la tuile ouverte par le palier ({el("GainList.Row2.RowLabel").Text})`)/
/^\t\[el\("Hint"\)\] = \{ Text = true \},$/a\
	[el("GainList.Row2.RowLabel")] = { Text = true }, -- a183 : la tuile de l'arbre du palier
/^local REBIRTH = buildRebirth\(PLAYER_GUI\)$/a\
OWNED183 = Color3.fromRGB(92, 255, 74) -- a183, L-168 Q4 : attribut OwnedColor posé par Clément sur Status\
rebirthEl(REBIRTH, "ItemRequirement.Status"):SetAttribute("OwnedColor", OWNED183)\
STATUS_COLOR183 = rebirthEl(REBIRTH, "ItemRequirement.Status").TextColor3
s/^(check\(el\("ItemRequirement\.Status"\)\.Text == "Owned!" and shown\(\) == "Disabled", .*)$/\1\
check(el("ItemRequirement.Status").TextColor3 == OWNED183 and OWNED183 ~= STATUS_COLOR183, "(a183) « Owned! » à la couleur OwnedColor (vert)")/
s/^(check\(shown\(\) == "Disabled" and el\("ItemRequirement\.Status"\)\.Text == "Not owned yet", "Disabled, « Not owned yet »"\))$/\1\
check(el("ItemRequirement.Status").TextColor3 == STATUS_COLOR183, "(a183) objet perdu : la couleur de Clément revient")/
s/el\("GainList\.Row2"\)\.Visible == false and shown\(\) == "Disabled", "\(a176\) [^"]*"\)$/el("GainList.Row2").Visible ~= false and el("GainList.Row2.RowLabel").Text == "New skill: Potion Time" and shown() == "Disabled", "(a183) palier 2 : New skill: Potion Time, Disabled")\
P1:SetAttribute("Rebirths", 4)\
flush()\
check(el("Level").Text == "Level 4 → 5" and el("GainList.Row2").Visible == false, "(a183) palier 5 : aucune tuile, ligne Row2 cachée")\
P1:SetAttribute("Rebirths", 2)\
flush()\
check(el("GainList.Row2").Visible == true and el("GainList.Row2.RowLabel").Text == "New skill: Door Guard", "(a183) palier 3 : ligne remontrée, New skill: Door Guard")\
local noColor183 = buildRebirth(PLAYER_GUI)\
flush()\
P1:SetAttribute("RebirthItemOwned", true)\
flush()\
check(rebirthEl(noColor183, "ItemRequirement.Status").Text == "Owned!" and rebirthEl(noColor183, "ItemRequirement.Status").TextColor3 == STATUS_COLOR183, "(a183) Status sans attribut OwnedColor : « Owned! », couleur inchangée")\
noColor183:Destroy()\
flush()/
