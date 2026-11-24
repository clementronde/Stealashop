--!nocheck
---------------------------------------------------------------- a183, scénario « locked » : HideWhenRebirthOff = false
REBIRTH_OFF183 = true
start85({ Cash = 1e12, Skill_GlassThickness = 1, Skill_Walls = 2, Skill_Curtain = 0, Skill_PotionTime = 0, Skill_DoorGuard = 0, Skill_Traps = 0 })

section("L1. Renaissance coupée, réglage « montrées verrouillées »")
check(SkillTreeC.HideWhenRebirthOff == false, "L1a Config/SkillTree.HideWhenRebirthOff = false (pre.locked.luau)")
for name, n in { Tile_Curtain = 1, Tile_PotionTime = 2, Tile_DoorGuard = 3, Tile_Next1 = 4 } do
	check(tile(name).Visible and shownLayer(name) == "RebirthLocked" and tileEl(name, "RebirthLocked.LockedName").Text == `REBIRTH {n}`, `L1b {name} : visible, RebirthLocked « REBIRTH {n} »`)
end
check(not SKILL.Select("Tile_Curtain"), "L1c ne se choisit pas")

summary()
