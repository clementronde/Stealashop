# a183 (vague 56, L-173), banc a84 (arbre, serveur), après les correctifs d'a176 : les tuiles Curtain, PotionTime, DoorGuard et
# Traps demandent 1, 2, 3 et 4 renaissances (attribut Rebirths du Player, posé en jeu par RebirthService). Les joueurs des
# scénarios d'avant reçoivent Rebirths = 10 (toutes les tuiles ouvertes, comme avant) ; les refus et l'ouverture par la
# renaissance sont dans la section ajoutée au scénario buy.
s/^(local ([A-Za-z0-9_]+) = join\("[A-Za-z0-9_]+", [A-Za-z0-9_]+\))$/\1 \2:SetAttribute("Rebirths", 10) -- a183 : toutes les renaissances faites/
/^section\("débit de Net et profil absent"\)$/i\
section("(a183) tuiles à renaissance (L-173)")\
local ST183 = sharedModule("Config/SkillTree")\
check(ST183.ById.Curtain.RequiresRebirth == 1 and ST183.ById.PotionTime.RequiresRebirth == 2 and ST183.ById.DoorGuard.RequiresRebirth == 3 and ST183.ById.Traps.RequiresRebirth == 4, "(a183) G0 tableau V0 : Curtain 1, PotionTime 2, DoorGuard 3, Traps 4")\
local open183 = 0\
for _, skill in ST183.List do\
	if skill.RequiresRebirth == nil then\
		open183 += 1\
	end\
end\
check(open183 == 6, `(a183) G0b les 6 tuiles du premier anneau ne demandent aucune renaissance ({open183})`)\
local zedData = newProfile()\
zedData.Cash = 1e12\
local zed = (join("Zed", zedData))\
advance(0.5)\
check(zed:GetAttribute("Rebirths") == nil, "(a183) G1 renaissance coupée : pas d'attribut Rebirths")\
buy(zed, "GlassThickness")\
buy(zed, "PotionLuck")\
check(zed:GetAttribute("Skill_GlassThickness") == 1 and zed:GetAttribute("Skill_PotionLuck") == 1, "(a183) G2 renaissance coupée : les tuiles sans renaissance s'achètent")\
local cash183 = zedData.Cash\
buy(zed, "Curtain")\
msg, kind = lastNotify(zed)\
check(msg == "Locked: reach Rebirth 1 first." and kind == "Warning", `(a183) G3 renaissance coupée, Curtain (ouverte par Glass 1) : « {msg} » ({kind})`)\
check(zed:GetAttribute("Skill_Curtain") == 0 and zedData.Cash == cash183 and zedData.SkillTree.Curtain == nil, "(a183) G4 refus : ni niveau ni argent")\
zed:SetAttribute("Rebirths", 0)\
buy(zed, "Curtain")\
msg = lastNotify(zed)\
check(msg == "Locked: reach Rebirth 1 first." and zed:GetAttribute("Skill_Curtain") == 0, `(a183) G5 renaissance ouverte, profil sans renaissance : refusé (« {msg} »)`)\
buy(zed, "PotionTime")\
msg = lastNotify(zed)\
check(msg == "Locked: reach Rebirth 2 first.", `(a183) G6 PotionTime : « {msg} »`)\
buy(zed, "DoorGuard")\
msg = lastNotify(zed)\
check(msg == "Locked: reach Rebirth 3 first.", `(a183) G7 DoorGuard : « {msg} »`)\
buy(zed, "Traps")\
msg = lastNotify(zed)\
check(msg == "Locked: reach Rebirth 4 first." and zedData.Cash == cash183, `(a183) G8 Traps : « {msg} », argent intact`)\
zed:SetAttribute("Rebirths", 1)\
buy(zed, "Curtain")\
msg, kind = lastNotify(zed)\
check(msg == "Lock upgraded: 45s!" and kind == "Success" and zed:GetAttribute("Skill_Curtain") == 1 and zedData.Cash == cash183 - 50000, `(a183) G9 après la 1re renaissance : Curtain achetée (« {msg} »)`)\
buy(zed, "PotionTime")\
msg = lastNotify(zed)\
check(msg == "Locked: reach Rebirth 2 first." and zed:GetAttribute("Skill_PotionTime") == 0, "(a183) G10 1 renaissance : PotionTime toujours refusée")\
zed:SetAttribute("Rebirths", 2)\
buy(zed, "PotionTime")\
check(zed:GetAttribute("Skill_PotionTime") == 1, "(a183) G11 après la 2e : PotionTime achetée")\
zed:SetAttribute("Rebirths", 4)\
buy(zed, "Traps")\
msg = lastNotify(zed)\
check(msg == "Locked: get Walls level 2 first.", `(a183) G12 4 renaissances : Traps n'est plus fermée par la renaissance, OpensWhen s'applique (« {msg} »)`)\
zed:SetAttribute("Rebirths", nil)\
buy(zed, "Curtain")\
msg = lastNotify(zed)\
check(msg == "Lock upgraded: 60s!" and zed:GetAttribute("Skill_Curtain") == 2, `(a183) G13 renaissance recoupée : une tuile déjà achetée reste achetable (« {msg} »)`)\
check(SkillTreeService.GetEffect(zed, "Curtain") == 60 and SkillTreeService.GetEffect(zed, "PotionTime") == 1.25, "(a183) G14 renaissance coupée : les niveaux achetés gardent leur effet")\
for _, bad in { -1, 0 / 0, math.huge, "3", true } do\
	zed:SetAttribute("Rebirths", bad)\
	check(ST183.RebirthsOf(zed:GetAttribute("Rebirths")) == nil, `(a183) G15 attribut illisible ({tostring(bad)}) : comme coupée`)\
end\
zed:SetAttribute("Rebirths", 2.9)\
check(ST183.RebirthsOf(zed:GetAttribute("Rebirths")) == 2 and ST183.NeedsRebirth(ST183.ById.DoorGuard, 0, 2) == 3 and ST183.NeedsRebirth(ST183.ById.DoorGuard, 0, 3) == nil and ST183.NeedsRebirth(ST183.ById.DoorGuard, 1, nil) == nil and ST183.NeedsRebirth(ST183.ById.Walls, 0, nil) == nil, "(a183) G16 RebirthsOf et NeedsRebirth")\
local old183 = newProfile()\
old183.SkillTree = { Curtain = 1, GlassThickness = 1 }\
local yan = (join("Yan", old183))\
advance(0.5)\
check(yan:GetAttribute("Skill_Curtain") == 1 and old183.SkillTree.Curtain == 1 and SkillTreeService.GetEffect(yan, "Curtain") == 45, "(a183) G17 profil avec Curtain 1 et sans renaissance : niveau et effet gardés au chargement")\
zed:SetAttribute("Rebirths", nil)
