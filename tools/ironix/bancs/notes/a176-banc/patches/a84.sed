# a176 (vague 54), banc a84 (arbre, serveur) : plus de tuile Safe ni de coffre-fort ; un Safe sauvegardé est ignoré.
s/"PotionTime", "Traps", "Safe" \}/"PotionTime", "Traps" }/
s/"Skill_<Id> = 0 pour les 11 compétences"/"(a176) Skill_<Id> = 0 pour les 10 compétences"/
s/^check\(msg == "Locked: get Door Repair level 1 first\.", `tuile fermée \(Safe\).*$/check(msg == "Locked: get Reinforced Door level 1 first." and ada:GetAttribute("Skill_Safe") == nil, "(a176) Safe n'existe plus : Id inconnu, ignoré sans message")/
s/^check\(ada:GetAttribute\("Skill_Safe"\) == 2, "Safe ouverte par Glass Regen 1 : niveaux 1 et 2"\)$/check(ada:GetAttribute("Skill_Safe") == nil and adaData.SkillTree.Safe == nil, "(a176) plus de tuile Safe : rien acheté")/
s/^check\(msg == "Safe is already at max level\." .*$/check(adaData.Cash == cash and ada:GetAttribute("Skill_Safe") == nil, "(a176) Safe toujours ignoré, argent intact")/
s/ \+ 250000 \+ 25000000 \+ / + /
s/ada:GetAttribute\("Skill_Safe"\) == 0 and ada:GetAttribute\("Skill_GlassRegen"\) == 0, "attributs : 5, 1, 0, 0"/ada:GetAttribute("Skill_Safe") == nil and ada:GetAttribute("Skill_GlassRegen") == 0, "(a176) attributs : 5, 1, aucun Skill_Safe, 0"/
s/^check\(n0 == 1 and t0 == "3", .*$/check(n0 == 0, `(a176) base : aucun présentoir à l'abri (trouvé {t0})`)/
s/^check\(n1 == 2, .*$/check(n1 == 0, `(a176) Safe ignoré : toujours aucun à l'abri (trouvé {t1})`)/
s/^check\(n2 == 3 and t2 == "1,2,3", .*$/check(n2 == 0, `(a176) toujours aucun à l'abri (trouvé {t2})`)/
s/^check\(PvPService\.GetVaultSlots\(ada\) == 3 .*$/check(PvPService.GetVaultSlots == nil, "(a176) PvPService.GetVaultSlots retiré")/
s/^check\(not steal\(bob, adaShop, 1\), "présentoir 1 à l'abri : prise refusée"\)$/check(steal(bob, adaShop, 1), "(a176) présentoir 1 : prise acceptée, plus de coffre-fort")/
s/^check\(#notifies\(bob, "This item is in the safe"\) >= 1, .*$/check(#notifies(bob, "This item is in the safe") == 0, "(a176) aucun refus « Safe »")/
s/^check\(steal\(bob, adaShop, 4\), "présentoir 4 \(pas à l'abri\) : prise acceptée"\)$/check(CarryService.IsCarrying(bob), "(a176) Bob porte l'objet du présentoir 1")/
/^check\(logHas\("entrée\(s\) de SkillTree corrigée\(s\)", "WARN", "server"\), "nettoyage signalé en Studio"\)$/a\
section("(a176) profil avec des niveaux de Safe (coffre-fort retiré)")\
local deeData = newProfile()\
deeData.SkillTree = { Safe = 2, Cameras = 1 }\
local dee = join("Dee", deeData)\
advance(0.3)\
check(deeData.SkillTree and deeData.SkillTree.Safe == nil and deeData.SkillTree.Cameras == 1, "(a176) Safe 2 retiré du profil, Cameras 1 gardé")\
check(dee:GetAttribute("Skill_Safe") == nil and dee:GetAttribute("Skill_Cameras") == 1, "(a176) aucun attribut Skill_Safe")\
check(not logHas("Dee :", "WARN", "server") and not logHas("Dee :", "ERROR", "server"), "(a176) ignoré sans avertissement ni erreur")\
local eveData = newProfile()\
eveData.SkillTree = { Safe = 1 }\
join("Eve", eveData)\
advance(0.3)\
check(eveData.SkillTree == nil, "(a176) seulement Safe : champ SkillTree retiré")
