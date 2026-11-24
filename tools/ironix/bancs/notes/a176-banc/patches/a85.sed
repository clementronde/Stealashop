# a176 (vague 54), banc a85 (écran de l'arbre) : plus de tuile Safe ; Tile_Next4 (encore dans l'écran construit par le banc)
# est cachée par le code et n'est plus branchée. La voisine découverte du scénario buy devient Potion Time (achat de Potion Luck
# en même temps que Glass Regen).
s/^local safe = tile\("Tile_Next4"\)$/local safe = tile("Tile_PotionTime")/
s/^P1:SetAttribute\("Skill_GlassRegen", 1\)$/P1:SetAttribute("Skill_GlassRegen", 1) P1:SetAttribute("Skill_PotionLuck", 1)/
s/countNamed\(TREE, "FxSpark"\) == ST\.SparkCount, `B2d/countNamed(TREE, "FxSpark") >= ST.SparkCount, `(a176, deux achats) B2d/
s/shownLayer\("Tile_Next4"\) == "Locked", "B2e Safe/shownLayer("Tile_PotionTime") == "Locked", "(a176) B2e Potion Time/
s/shownLayer\("Tile_Next4"\) == "Locked", "B2i Safe/shownLayer("Tile_PotionTime") == "Locked", "(a176) B2i Potion Time/
s/shownLayer\("Tile_Next4"\) == "Available" and tileEl\("Tile_Next4", "Info"\)\.Visible, "B2j Safe/shownLayer("Tile_PotionTime") == "Available" and tileEl("Tile_PotionTime", "Info").Visible, "(a176) B2j Potion Time/
s/SKILL\.Select\("Tile_Next4"\) and panelEl\("NodeName"\)\.Text == "SAFE"/SKILL.Select("Tile_PotionTime") and panelEl("NodeName").Text == "POTION TIME"/
s/^check\(shownLayer\("Tile_Next4"\) == "Locked" and not tileEl\("Tile_Next4", "Info"\)\.Visible, "T1d .*$/check(tile("Tile_Next4") and tile("Tile_Next4").Visible == false, "(a176) T1d Tile_Next4 (ancien coffre-fort) cachée par le code")/
s/^check\(shownLayer\("Tile_Next4"\) == "Available" .*"T5a Safe ouverte : Available, « Safe 1 »"\)$/check(tile("Tile_Next4").Visible == false, "(a176) T5a Glass Regen 1 : Tile_Next4 reste cachée")/
s/scaleOf\("Tile_Next4"\) == 0 and scaleOf\("Tile_Curtain"\)/scaleOf("Tile_PotionTime") == 0 and scaleOf("Tile_Curtain")/
s/^for name in TILE_QR do$/for name in TILE_QR do if name == "Tile_Next4" then continue end -- a176 : tuile cachée, plus branchée/
s/^local edge = tile\("Tile_Next4"\)$/local edge = tile("Tile_Next1") -- a176 : Tile_Next4 n'est plus branchée/
