--!nocheck
-- Scénario « load » (a84) : champ SkillTree nettoyé au chargement (Id inconnu retiré, niveau entier borné à
-- MaxLevel, niveau ≤ 0 ou illisible retiré), attributs Skill_<Id> posés pour chaque Id, crochet de test Studio.
startSkills()

section("profil abîmé")
local data = newProfile()
data.SkillTree = { GlassThickness = 9, Cameras = 1.7, Unknown = 3, Safe = -1, GlassRegen = "x", Curtain = 0, [4] = 2 }
local ada = join("Ada", data)
advance(0.3)
local tree = data.SkillTree
check(tree and tree.GlassThickness == 5 and tree.Cameras == 1, "Glass borné à 5, Cameras 1,7 → 1")
local keys = 0
for _ in tree or {} do
	keys += 1
end
check(keys == 2, `Unknown, Safe −1, GlassRegen « x », Curtain 0 et la clé numérique retirés ({keys} entrée(s) gardée(s))`)
check(ada:GetAttribute("Skill_GlassThickness") == 5 and ada:GetAttribute("Skill_Cameras") == 1 and ada:GetAttribute("Skill_Safe") == 0 and ada:GetAttribute("Skill_GlassRegen") == 0, "attributs : 5, 1, 0, 0")
local all = true
for _, id in SKILL_IDS do
	if type(ada:GetAttribute("Skill_" .. id)) ~= "number" then
		all = false
	end
end
check(all and ada:GetAttribute("Skill_Unknown") == nil, "un attribut par Id de Config/SkillTree, rien pour Unknown")
check(logHas("entrée(s) de SkillTree corrigée(s)", "WARN", "server"), "nettoyage signalé en Studio")

section("champ qui n'est pas une table, champ vide")
local bobData = newProfile()
bobData.SkillTree = "oops"
local bob = join("Bob", bobData)
advance(0.3)
check(bobData.SkillTree == nil and bob:GetAttribute("Skill_GlassThickness") == 0, "texte : champ retiré, attributs à 0")
local cyData = newProfile()
cyData.SkillTree = { Curtain = 0 }
local cy = join("Cy", cyData)
advance(0.3)
check(cyData.SkillTree == nil and cy:GetAttribute("Skill_Curtain") == 0, "table sans niveau ≥ 1 : champ retiré")

section("crochet de test Studio (SkillTest)")
Workspace:SetAttribute("SkillTest", "Bob cash 500000")
advance(0.1)
check(bobData.Cash == 501000 and Workspace:GetAttribute("SkillTest") == nil, "« Bob cash 500000 » : argent ajouté, attribut effacé")
Workspace:SetAttribute("SkillTest", "Bob Cameras 7")
advance(0.1)
check(bobData.SkillTree and bobData.SkillTree.Cameras == 3 and bob:GetAttribute("Skill_Cameras") == 3, "« Bob Cameras 7 » : borné à MaxLevel (3)")
Workspace:SetAttribute("SkillTest", "Bob reset")
advance(0.1)
check(bobData.SkillTree == nil and bob:GetAttribute("Skill_Cameras") == 0, "« Bob reset » : arbre à 0")
Workspace:SetAttribute("SkillTest", "Zed cash 5")
advance(0.1)
check(logHas("joueur introuvable", "WARN", "server"), "joueur inconnu : un avertissement")

section("migration ShopLevel → Walls (copie a93, vague 29)")
local dData = newProfile()
dData.SkillTree = { ShopLevel = 3, GlassThickness = 1 }
local dee = join("Dee", dData)
advance(0.3)
check(dData.SkillTree and dData.SkillTree.Walls == 3 and dData.SkillTree.ShopLevel == nil and dData.SkillTree.GlassThickness == 1, "ShopLevel 3 relu comme Walls 3, Glass gardé")
check(dee:GetAttribute("Skill_Walls") == 3 and dee:GetAttribute("Skill_ShopLevel") == nil, "attribut Skill_Walls = 3, pas de Skill_ShopLevel")
local eData = newProfile()
eData.SkillTree = { ShopLevel = 9, Walls = 2 }
local eve = join("Eve", eData)
advance(0.3)
check(eData.SkillTree and eData.SkillTree.Walls == 4 and eData.SkillTree.ShopLevel == nil, "ShopLevel 9 et Walls 2 : le plus haut gagne, borné à 4")
check(eve:GetAttribute("Skill_Walls") == 4, "attribut Skill_Walls = 4")

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
summary("scénario load")
