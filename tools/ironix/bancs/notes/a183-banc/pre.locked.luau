--!nocheck
-- a183, scénario locked : le réglage de Config/SkillTree passé à « montrées verrouillées ».
local changed183
SOURCES["shared/Config/SkillTree.luau"], changed183 = string.gsub(SOURCES["shared/Config/SkillTree.luau"], "HideWhenRebirthOff = true", "HideWhenRebirthOff = false")
assert(changed183 == 1, "pre.locked : HideWhenRebirthOff = true introuvable dans Config/SkillTree")
