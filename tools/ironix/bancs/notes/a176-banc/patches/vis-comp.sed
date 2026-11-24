# a176 (vague 54), banc vis-competences : la compétence Safe n'existe plus ; l'attribut ShowFromSkill est vérifié sur PotionTime (2 niveaux).
s/SetAttribute\("ShowFromSkill", "Safe"\)/SetAttribute("ShowFromSkill", "PotionTime")/
s/SetAttribute\("ShowFromSkill", "Safe 2"\)/SetAttribute("ShowFromSkill", "PotionTime 2")/
s/SetAttribute\("SkillTest", "Ada Safe ([12])"\)/SetAttribute("SkillTest", "Ada PotionTime \1")/
s/"\\"Safe\\" \(niveau 1 par défaut\) avec Safe 0/"(a176, PotionTime) \\"Safe\\" (niveau 1 par défaut) avec Safe 0/
