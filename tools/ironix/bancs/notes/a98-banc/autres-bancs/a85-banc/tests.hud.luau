--!nocheck
---------------------------------------------------------------- scénario « hud » : bouton du HUD, ouverture, groupe
start85({ Cash = 250_000, Skill_Walls = 0, Skill_GlassThickness = 0, Skill_GlassRegen = 0 })
local function hudButton(hud, rail)
	return hud:FindFirstChild(rail):FindFirstChild("SkillTreeButton")
end

section("H1. SkillTreeButton montré dans les deux colonnes (PC)")
check(hudButton(HUD85, "LeftRail").Visible and hudButton(HUD85, "LeftRailTouch").Visible, "H1a les deux exemplaires sont montrés")
check(HUD85.LeftRail.Visible and not HUD85.LeftRailTouch.Visible, "H1b PC : LeftRail reste, LeftRailTouch reste caché")
check(GUI.Enabled == false and SKILL.GetState().Open == false, "H1c écran fermé au départ")

section("H2. Ouverture par LeftRail : « bop bop bop » (T.54), Motion.Open")
local soundsFrom = #SOUNDS_PLAYED
click(hudButton(HUD85, "LeftRail"))
local function scaleOf(name)
	local s = fxScale(tile(name))
	return if s then s.Scale else -1
end
check(GUI.Enabled and SKILL.GetState().Open, "H2a l'écran s'ouvre")
check(scaleOf("RootTile") >= 0 and scaleOf("RootTile") < 0.3 and scaleOf("Tile_Next1") == 0, "H2b toutes les tuiles partent de 0")
check(fxScale(TREE.SelectionGlow) and fxScale(TREE.SelectionGlow).Scale == 0, "H2c SelectionGlow aussi")
local function anyStagger()
	for _, d in GUI:GetDescendants() do
		if d.ClassName == "UIScale" and d.Name == UiMotionC.OpenStagger.ScaleName then
			return true
		end
	end
	return false
end
check(not anyStagger(), "H2d pas d'entrée une à une de Motion (OpenStagger) sur les tuiles : le « bop » s'en charge")
check(motionScale(GUI.InfoPanel) ~= nil and motionScale(TREE) == nil, "H2e Motion.Open met le panneau à l'échelle, pas Tree")
step(ST.PopStart + 0.06 - 1 / 30)
check(scaleOf("RootTile") > 0 and scaleOf("Tile_Glass") == 0 and scaleOf("Tile_Next1") == 0, "H2f la tuile centrale part la première")
step(ST.PopGap * 2)
check(scaleOf("Tile_Glass") > 0 or scaleOf("Tile_ShopLevel") > 0, "H2g puis le 1er anneau")
check(scaleOf("Tile_Next1") == 0 and scaleOf("Tile_Next4") == 0 and scaleOf("Tile_Curtain") == 0, "H2h le 2e anneau attend")
step(ST.PopStart + 13 * ST.PopGap + ST.PopTime)
local allOne = true
for name in TILE_QR do
	allOne = allOne and math.abs(scaleOf(name) - 1) < 1e-6
end
check(allOne and math.abs(fxScale(TREE.SelectionGlow).Scale - 1) < 1e-6, "H2i au bout de 0,12 + 13 × 0,055 + 0,38 s : tout à 1")
check(motionScale(GUI.InfoPanel) == nil, "H2j panneau revenu à sa taille (UIScale de Motion retiré)")
check(table.find(soundsSince(soundsFrom), "UI_Open") ~= nil, "H2k son UI_Open")
check(SKILL.GetState().Selected == "Tile_ShopLevel" and panelEl("NodeName").Text == "WALLS", "H2l tuile choisie à l'ouverture : la première ouverte (Walls, tuile Tile_ShopLevel)")
check(TREE.SelectionGlow.Position == tile("Tile_ShopLevel").Position, "H2m SelectionGlow sous elle")

section("H3. LeftRailTouch ferme le même écran (un seul état), fermeture T.28")
soundsFrom = #SOUNDS_PLAYED
click(hudButton(HUD85, "LeftRailTouch"))
check(SKILL.GetState().Open == false, "H3a 2e appui (autre exemplaire) : fermeture")
step(UiMotionC.Close.Time + 0.05)
check(GUI.Enabled == false, "H3b écran éteint après la sortie")
check(fxScale(tile("Tile_Glass")) == nil and fxScale(TREE.SelectionGlow) == nil, "H3c UIScale des tuiles retirés")
check(table.find(soundsSince(soundsFrom), "UI_Close") ~= nil, "H3d son UI_Close")
click(hudButton(HUD85, "LeftRailTouch"))
step(1.5)
check(GUI.Enabled and SKILL.GetState().Open, "H3e LeftRailTouch ouvre aussi")
click(GUI.CloseButton)
step(0.2)
check(GUI.Enabled == false and SKILL.GetState().Open == false, "H3f CloseButton ferme")

section("H4. Groupe « Menu » : un seul écran à la fois")
local other = new("ScreenGui", { Name = "UI_Inventory", Enabled = true, ResetOnSpawn = false }, PLAYER_GUI)
other:SetAttribute("ScreenGroup", "Menu")
new("Frame", { Name = "Root", Size = UDim2.fromScale(0.5, 0.5) }, other)
SKILL.Open()
step(0.3)
check(GUI.Enabled and other.Enabled == false, "H4a l'arbre ferme l'autre menu ouvert")
local Motion = requireModule(MOTION_MODULE, "client")
Motion.Open(other)
step(0.3)
check(other.Enabled and GUI.Enabled == false and SKILL.GetState().Open == false, "H4b un autre menu ferme l'arbre (Motion.SetCloser)")
Motion.Close(other)
step(0.3)

section("H5. Téléphone (L-096, version B) : LeftRailTouch à la place de LeftRail")
UserInputServiceStub.TouchEnabled = true
UserInputServiceStub.KeyboardEnabled = false
HUD85:Destroy()
local phoneHud = buildHud85(PLAYER_GUI)
step(0.1)
check(phoneHud.LeftRailTouch.Visible and not phoneHud.LeftRail.Visible, "H5a LeftRailTouch montré, LeftRail caché")
check(hudButton(phoneHud, "LeftRailTouch").Visible and hudButton(phoneHud, "LeftRail").Visible, "H5b SkillTreeButton montré dans les deux")
click(hudButton(phoneHud, "LeftRailTouch"))
step(1.5)
check(GUI.Enabled and SKILL.GetState().Open, "H5c il ouvre l'arbre")
SKILL.Close()
step(0.3)

section("H6. Écran recréé (ResetOnSpawn) : rebranché, fermé")
GUI:Destroy()
GUI = buildSkillTree(PLAYER_GUI)
TREE = GUI.Tree
step(0.1)
check(GUI.Enabled == false and GUI:FindFirstChild("NavLayer") ~= nil, "H6a nouvel écran branché (NavLayer), fermé")
click(hudButton(phoneHud, "LeftRailTouch"))
step(1.5)
check(GUI.Enabled and math.abs(fxScale(tile("Tile_Glass")).Scale - 1) < 1e-6, "H6b le bouton ouvre le nouvel écran")

section("H7. Sortie")
check(not logHas("[SkillTree]") , "H7a aucune ligne « [SkillTree] » (tous les éléments trouvés)")
check(not logHas("a déjà un UIScale"), "H7b aucune ligne de Motion sur un UIScale déjà là")

summary()
