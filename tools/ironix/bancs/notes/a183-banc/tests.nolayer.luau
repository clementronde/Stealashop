--!nocheck
---------------------------------------------------------------- a183, scénario « nolayer » : calque RebirthLocked pas encore livré
NO_LAYER183 = { Tile_Curtain = true, Tile_PotionTime = true, Tile_DoorGuard = true, Tile_Next1 = true }
start85({ Cash = 1e12, Rebirths = 0, Skill_GlassThickness = 1, Skill_Walls = 2, Skill_Curtain = 0, Skill_PotionTime = 0, Skill_DoorGuard = 0, Skill_Traps = 0 })

section("N1. Sans calque RebirthLocked : Locked à sa place")
check(tile("Tile_Curtain"):FindFirstChild("RebirthLocked") == nil, "N1a l'écran n'a pas le calque")
for _, name in { "Tile_Curtain", "Tile_PotionTime", "Tile_DoorGuard", "Tile_Next1" } do
	check(tile(name).Visible and shownLayer(name) == "Locked" and not tileEl(name, "Info").Visible, `N1b {name} : Locked, Info caché ({shownLayer(name)})`)
	check(tileEl(name, "Locked.LockedName").Text == "???" and tileEl(name, "Locked.LockedLabel").Text == "LOCKED", `N1c {name} : textes de Locked pas touchés`)
end
check(not SKILL.Select("Tile_Curtain"), "N1d ne se choisit pas")
P1:SetAttribute("Rebirths", 1)
step(0.1)
check(shownLayer("Tile_Curtain") == "Available" and SKILL.Select("Tile_Curtain"), "N1e après la 1re renaissance : Available, se choisit")
check(not logHas("attempt to"), "N1f aucune erreur dans la sortie")

summary()
