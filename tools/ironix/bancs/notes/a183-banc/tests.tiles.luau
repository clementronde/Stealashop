--!nocheck
---------------------------------------------------------------- a183, scénario « tiles » : renaissance ouverte (L-173)
start85({
	Cash = 1e12,
	Rebirths = 0,
	Skill_Walls = 2,
	Skill_GlassThickness = 1,
	Skill_GlassRegen = 0,
	Skill_Cameras = 0,
	Skill_Bodyguards = 0,
	Skill_PotionLuck = 0,
	Skill_Curtain = 0,
	Skill_DoorGuard = 0,
	Skill_PotionTime = 0,
	Skill_Traps = 0,
})
local GATED = { Tile_Curtain = 1, Tile_PotionTime = 2, Tile_DoorGuard = 3, Tile_Next1 = 4 }

section("R1. Aucune renaissance faite : calque RebirthLocked")
for name, n in GATED do
	check(tile(name).Visible and shownLayer(name) == "RebirthLocked" and not tileEl(name, "Info").Visible, `R1a {name} : RebirthLocked seul, Info caché, tuile visible ({shownLayer(name)})`)
	check(tileEl(name, "RebirthLocked.LockedName").Text == `REBIRTH {n}` and tileEl(name, "RebirthLocked.LockedLabel").Text == "TO UNLOCK", `R1b {name} : « REBIRTH {n} » / « TO UNLOCK » ({tileEl(name, "RebirthLocked.LockedName").Text})`)
	check(tileEl(name, "Locked.LockedName").Text == "???" and tileEl(name, "Locked.LockedLabel").Text == "LOCKED", `R1c {name} : textes du calque Locked de Clément gardés`)
	check(tile(name):GetAttribute("RequiresRebirth") == n, `R1d {name} : attribut RequiresRebirth = {n}`)
end
check(tile("Tile_Glass"):GetAttribute("RequiresRebirth") == nil and tile("Tile_Next2"):GetAttribute("RequiresRebirth") == nil and tile("RootTile"):GetAttribute("RequiresRebirth") == nil, "R1e pas d'attribut sur les autres tuiles")
check(shownLayer("Tile_Glass") == "Bought" and shownLayer("Tile_PotionLuck") == "Available" and shownLayer("Tile_Next2") == "Locked", "R1f les autres tuiles : Bought, Available, Locked comme avant")
check(not SKILL.Select("Tile_Curtain") and not SKILL.Select("Tile_Next1"), "R1g une tuile RebirthLocked ne se choisit pas")
SKILL.Open()
step(1.5)
local selected = SKILL.GetState().Selected
tapAt(centerOf(tile("Tile_Curtain")))
check(SKILL.GetState().Selected == selected and selected ~= "Tile_Curtain", `R1h un appui sur la tuile ne la choisit pas (choisie : {tostring(selected)})`)
check(#sentOf("BuySkill") == 0, "R1i rien d'envoyé")

section("R2. Après la 1re renaissance : Curtain s'ouvre, les suivantes restent fermées")
P1:SetAttribute("Rebirths", 1)
step(0.1)
check(shownLayer("Tile_Curtain") == "Available" and tileEl("Tile_Curtain", "Info").Visible, `R2a Curtain : Available (Glass 1), Info visible ({shownLayer("Tile_Curtain")})`)
check(shownLayer("Tile_PotionTime") == "RebirthLocked" and shownLayer("Tile_DoorGuard") == "RebirthLocked" and shownLayer("Tile_Next1") == "RebirthLocked", "R2b Potion Time, Door Guard et Traps : toujours RebirthLocked")
check(SKILL.Select("Tile_Curtain") and panelEl("NodeName").Text == "LOCK", "R2c Curtain se choisit : panneau « LOCK »")
click(panelEl("BuyButton"))
local sent = sentOf("BuySkill")
check(#sent == 1 and sent[1] == "Curtain", "R2d BUY envoie BuySkill(Curtain)")

section("R3. Achat de la voisine : pas de « NEW! » sur une tuile encore fermée par la renaissance")
P1:SetAttribute("Skill_PotionLuck", 1)
step(2)
check(shownLayer("Tile_PotionLuck") == "Bought" and shownLayer("Tile_PotionTime") == "RebirthLocked", "R3a Potion Luck 1 : Potion Time reste RebirthLocked")
check(countNamed(tile("Tile_PotionTime"), "FxNewBadge") == 0, "R3b aucun badge NEW! sur Potion Time")
P1:SetAttribute("Rebirths", 2)
step(0.1)
check(shownLayer("Tile_PotionTime") == "Available" and tileEl("Tile_PotionTime", "Info").Visible, "R3c après la 2e renaissance : Potion Time Available")

section("R4. 4 renaissances : la renaissance n'est plus le verrou, OpensWhen s'applique")
P1:SetAttribute("Rebirths", 4)
step(0.1)
check(shownLayer("Tile_Next1") == "Available", `R4a Traps : Available (Walls 2) ({shownLayer("Tile_Next1")})`)
check(shownLayer("Tile_DoorGuard") == "Locked", `R4b Door Guard : Locked (Guards 0), plus RebirthLocked ({shownLayer("Tile_DoorGuard")})`)

section("R5. Une tuile déjà achetée n'est jamais refermée")
P1:SetAttribute("Skill_Curtain", 1)
P1:SetAttribute("Rebirths", 0)
step(0.1)
check(shownLayer("Tile_Curtain") == "Bought" and tile("Tile_Curtain").Visible and SKILL.Select("Tile_Curtain"), "R5a Curtain niveau 1, 0 renaissance : Bought, se choisit")
check(shownLayer("Tile_PotionTime") == "RebirthLocked" and tileEl("Tile_PotionTime", "RebirthLocked.LockedName").Text == "REBIRTH 2", "R5b Potion Time (niveau 0) : de nouveau RebirthLocked « REBIRTH 2 »")
check(not logHas("attempt to"), "R5c aucune erreur dans la sortie")

summary()
