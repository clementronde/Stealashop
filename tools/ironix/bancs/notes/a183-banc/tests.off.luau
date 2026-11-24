--!nocheck
---------------------------------------------------------------- a183, scénario « off » : renaissance coupée (lancement)
REBIRTH_OFF183 = true
start85({
	Cash = 1e12,
	Skill_Walls = 2,
	Skill_GlassThickness = 1,
	Skill_GlassRegen = 0,
	Skill_Cameras = 0,
	Skill_Bodyguards = 1,
	Skill_PotionLuck = 1,
	Skill_Curtain = 0,
	Skill_DoorGuard = 0,
	Skill_PotionTime = 0,
	Skill_Traps = 0,
})
local GATED = { "Tile_Curtain", "Tile_PotionTime", "Tile_DoorGuard", "Tile_Next1" }
local function hiddenCount()
	local n = 0
	for _, name in GATED do
		if tile(name).Visible == false then
			n += 1
		end
	end
	return n
end

section("O1. Pas d'attribut Rebirths : tuiles à renaissance cachées")
check(P1:GetAttribute("Rebirths") == nil, "O1a pas d'attribut Rebirths")
check(hiddenCount() == 4, `O1b les 4 tuiles à renaissance sont cachées ({hiddenCount()}/4)`)
local others = true
for _, name in { "RootTile", "Tile_Glass", "Tile_ShopLevel", "Tile_Cameras", "Tile_Guards", "Tile_PotionLuck", "Tile_GlassRegen", "Tile_Next2" } do
	if not tile(name).Visible then
		others = false
	end
end
check(others, "O1c les autres tuiles restent visibles")
check(not SKILL.Select("Tile_Curtain") and not SKILL.Select("Tile_PotionTime"), "O1d une tuile cachée ne se choisit pas")
SKILL.Open()
step(1.5)
check(hiddenCount() == 4, "O1e écran ouvert, après l'animation des tuiles : toujours cachées")
local selected = SKILL.GetState().Selected
tapAt(centerOf(tile("Tile_Curtain")))
check(SKILL.GetState().Selected == selected, "O1f un appui à la place d'une tuile cachée ne choisit rien")
P1:SetAttribute("Skill_GlassThickness", 2)
step(2)
check(tile("Tile_Curtain").Visible == false and countNamed(tile("Tile_Curtain"), "FxNewBadge") == 0, "O1g achat de la voisine : la tuile reste cachée, sans badge")

section("O2. Tuile déjà achetée : montrée, jamais retirée")
P1:SetAttribute("Skill_Curtain", 1)
step(0.1)
check(tile("Tile_Curtain").Visible and shownLayer("Tile_Curtain") == "Bought" and SKILL.Select("Tile_Curtain"), "O2a Curtain niveau 1 : visible, Bought, se choisit")
check(hiddenCount() == 3, "O2b les 3 autres restent cachées")

section("O3. La renaissance s'allume, puis se coupe")
P1:SetAttribute("Rebirths", 0)
step(0.1)
check(hiddenCount() == 0 and shownLayer("Tile_PotionTime") == "RebirthLocked" and tileEl("Tile_PotionTime", "RebirthLocked.LockedName").Text == "REBIRTH 2", "O3a attribut Rebirths = 0 : tuiles montrées, RebirthLocked « REBIRTH 2 »")
P1:SetAttribute("Rebirths", nil)
step(0.1)
check(hiddenCount() == 3 and tile("Tile_Curtain").Visible, "O3b attribut retiré : de nouveau cachées (sauf Curtain, achetée)")

section("O4. Écran recréé : une tuile cachée par Clément le reste")
GUI:Destroy()
step(0.1)
local fresh = buildSkillTree(nil)
fresh.Tree.Tile_Next1.Visible = false
fresh.Parent = PLAYER_GUI
step(0.1)
P1:SetAttribute("Rebirths", 9)
step(0.1)
check(fresh.Tree.Tile_Next1.Visible == false and fresh.Tree.Tile_PotionTime.Visible == true, "O4a Visible = false posé par Clément : jamais remontré par le code")
check(not logHas("attempt to"), "O4b aucune erreur dans la sortie")

summary()
