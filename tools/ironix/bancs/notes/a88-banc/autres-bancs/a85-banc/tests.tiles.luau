--!nocheck
---------------------------------------------------------------- scénario « tiles » : états, textes, prix, panneau
start85({
	Cash = 1_000_000,
	Skill_ShopLevel = 1,
	Skill_GlassThickness = 2,
	Skill_GlassRegen = 0,
	Skill_Cameras = 2,
	Skill_Bodyguards = 0,
	Skill_Curtain = 0,
	Skill_DoorGuard = 0,
	Skill_PotionTime = 0,
	Skill_Traps = 0,
	Skill_Safe = 0,
	-- Skill_PotionLuck absent : niveau 0
})

section("T1. Calques selon le niveau et OpensWhen")
check(shownLayer("Tile_Glass") == "Bought" and tileEl("Tile_Glass", "Info").Visible, "T1a Glass niveau 2 : Bought, Info visible")
check(shownLayer("Tile_GlassRegen") == "Available", "T1b Glass Regen niveau 0 (ouverte dès le départ) : Available")
check(shownLayer("Tile_Curtain") == "Available", "T1c Curtain : ouverte (Glass ≥ 1), niveau 0 : Available")
check(shownLayer("Tile_Next4") == "Locked" and not tileEl("Tile_Next4", "Info").Visible, "T1d Safe (Tile_Next4) : Glass Regen 0, Locked, Info caché")
check(shownLayer("Tile_Next1") == "Locked" and not tileEl("Tile_Next1", "Info").Visible, "T1e Traps (Tile_Next1) : Shop Level 1 < 2, Locked")
check(shownLayer("Tile_DoorGuard") == "Locked" and shownLayer("Tile_PotionTime") == "Locked", "T1f Door Guard et Potion Time : Locked")
check(shownLayer("Tile_PotionLuck") == "Available", "T1g Potion Luck : attribut absent = niveau 0, Available")
check(shownLayer("Tile_Next2") == "Locked" and not tileEl("Tile_Next2", "Info").Visible, "T1h Tile_Next2 : toujours Locked")
check(tile("RootTile").TileName.Text == "UPGRADES", "T1i RootTile : texte de Clément gardé")

section("T2. Textes des tuiles")
check(tileEl("Tile_Glass", "Info.Level").Text == "Lv 2/5", "T2a Glass : Lv 2/5")
check(tileEl("Tile_Glass", "Info.TileName").Text == "Glass ×2", "T2b Glass : « Glass ×2 »")
check(tileEl("Tile_ShopLevel", "Info.TileName").Text == "Shop", "T2c Shop Level niveau 1 : « Shop » (un mot : seul)")
check(tileEl("Tile_Cameras", "Info.TileName").Text == "Cameras II", "T2d Cameras niveau 2 : « Cameras II »")
check(tileEl("Tile_Guards", "Info.TileName").Text == "Guards", "T2e Guards niveau 0, sans Labels[0] : « Guards »")
check(tileEl("Tile_Curtain", "Info.TileName").Text == "Curtain 30s", "T2f Curtain niveau 0 : « Curtain 30s »")
check(tileEl("Tile_GlassRegen", "Info.TileName").Text == "Glass Regen 3%/s", "T2g Glass Regen : « Glass Regen 3%/s »")

section("T3. Prix : Price, PriceNeed, SOON, MAX")
local function price(name)
	local p, n = tileEl(name, "Info.PriceRow.Price"), tileEl(name, "Info.PriceRow.PriceNeed")
	if n.Visible and not p.Visible then
		return "need " .. n.Text
	elseif p.Visible and not n.Visible then
		return p.Text
	end
	return "?"
end
check(price("Tile_Glass") == "need $4M", "T3a Glass niveau 3 à $4M, argent $1M : PriceNeed « $4M », Price caché")
check(price("Tile_GlassRegen") == "$50K", "T3b Glass Regen à $50K : Price « $50K », PriceNeed caché")
check(price("Tile_ShopLevel") == "SOON", "T3c Shop Level : niveau 2 pas codé (Coded 0) : « SOON »")
check(price("Tile_Cameras") == "SOON", "T3d Cameras niveau 2 : niveau 3 pas codé (Coded 2) : « SOON »")
-- Copie d'a88 (2026-11-11, vague 28) : Potion Luck codée (niveau 1 à $20K) sur un arbre qui a ces prix.
if string.find(SOURCES["shared/Config/SkillTree.luau"] or "", "Prices = { 20_000, 400_000, 8_000_000 }", 1, true) then
	check(price("Tile_PotionLuck") == "$20K", `T3e a88 Potion Luck niveau 1 à $20K : Price « $20K » (trouvé {price("Tile_PotionLuck")})`)
else
	check(price("Tile_PotionLuck") == "SOON", "T3e Potion Luck : pas de prix : « SOON »")
end
P1:SetAttribute("Cash", 5_000_000)
step(0.1)
check(price("Tile_Glass") == "$4M", "T3f l'argent passe à $5M : Price « $4M »")
P1:SetAttribute("Skill_GlassThickness", 5)
step(0.1)
check(price("Tile_Glass") == "MAX" and tileEl("Tile_Glass", "Info.Level").Text == "Lv 5/5" and tileEl("Tile_Glass", "Info.TileName").Text == "Glass ×8", "T3g Glass niveau 5 : « MAX », Lv 5/5, « Glass ×8 »")
P1:SetAttribute("Skill_GlassThickness", 2)
P1:SetAttribute("Cash", 1_000_000)
step(0.1)

section("T4. Panneau de la tuile choisie")
check(SKILL.Select("Tile_Glass") == true and SKILL.GetState().Selected == "Tile_Glass", "T4a Select(Tile_Glass)")
check(panelEl("NodeName").Text == "GLASS" and panelEl("NodeLevel").Text == "Level 2 / 5" and panelEl("NodeStat").Text == "Window HP", "T4b NodeName GLASS, Level 2 / 5, Window HP")
check(panelEl("NodeEffect").Text == "×2  ▶  ×3", "T4c NodeEffect « ×2  ▶  ×3 »")
check(panelEl("NodePrice").Text == "$4M", "T4d NodePrice $4M")
check(not panelEl("BuyButton").Visible and panelEl("NeedButton").Visible and panelEl("NeedLabel").Text == "Need $4M", "T4e argent qui manque : NeedButton « Need $4M », BuyButton caché")
check(panelEl("NodeIcon").Image == TILE_ICONS.Tile_Glass, "T4f NodeIcon : l'icône de la tuile")
P1:SetAttribute("Cash", 4_000_000)
step(0.1)
check(panelEl("BuyButton").Visible and not panelEl("NeedButton").Visible, "T4g argent suffisant : BuyButton, NeedButton caché")
check(SKILL.Select("Tile_Curtain") and panelEl("NodePrice").Text == "SOON" and panelEl("NeedLabel").Text == "Coming soon" and panelEl("NeedButton").Visible and not panelEl("BuyButton").Visible, "T4h Curtain pas codé : SOON, « Coming soon »")
check(panelEl("NodeEffect").Text == "30s  ▶  60s", "T4i Curtain : « 30s  ▶  60s »")
check(SKILL.Select("Tile_Next4") == false and SKILL.GetState().Selected == "Tile_Curtain", "T4j une tuile Locked ne se choisit pas")
check(SKILL.Select("RootTile") == false and SKILL.Select("Tile_Next2") == false, "T4k RootTile et Tile_Next2 ne se choisissent pas")
P1:SetAttribute("Skill_GlassThickness", 5)
step(0.1)
SKILL.Select("Tile_Glass")
check(panelEl("NodePrice").Text == "MAX" and panelEl("NeedLabel").Text == "MAX LEVEL" and panelEl("NodeEffect").Text == "×8  (MAX)" and not panelEl("BuyButton").Visible, "T4l niveau max : MAX, « MAX LEVEL », « ×8  (MAX) »")
SKILL.Select("Tile_Cameras")
check(panelEl("NodeEffect").Text == "II  ▶  III" and panelEl("NodeName").Text == "CAMERAS", "T4m Cameras : « II  ▶  III »")
SKILL.Select("Tile_Guards")
check(panelEl("NodeEffect").Text == "—  ▶  I", "T4n Guards niveau 0 sans Labels[0] : « —  ▶  I »")
SKILL.Select("Tile_ShopLevel")
check(panelEl("NodeName").Text == "SHOP" and panelEl("NodeEffect").Text == "Shop  ▶  Store" and panelEl("NodeLevel").Text == "Level 1 / 4", "T4o Shop Level : SHOP, « Shop  ▶  Store »")

section("T5. Voisine ouverte écran fermé : tout de suite, sans effet")
P1:SetAttribute("Skill_GlassRegen", 1)
step(0.1)
check(shownLayer("Tile_Next4") == "Available" and tileEl("Tile_Next4", "Info").Visible and tileEl("Tile_Next4", "Info.TileName").Text == "Safe 1", "T5a Safe ouverte : Available, « Safe 1 »")
check(countNamed(GUI, "FxNewBadge") == 0 and countNamed(GUI, "FxSpark") == 0, "T5b écran fermé : ni badge ni étincelles")

section("T6. Rien d'autre que textes et visibilités (écran fermé)")
-- Écran neuf (copie de StarterGui) : instantané, puis un changement de niveau et d'argent.
GUI:Destroy()
step(0.1)
local fresh = buildSkillTree(nil)
local snap = snapshot(fresh)
fresh.Parent = PLAYER_GUI
step(0.1)
P1:SetAttribute("Cash", 123_456)
P1:SetAttribute("Skill_Bodyguards", 1)
step(0.1)
local allowed = {}
for _, d in fresh:GetDescendants() do
	allowed[d] = { Visible = true, Text = true }
end
allowed[fresh] = { Enabled = true }
allowed[fresh.InfoPanel:FindFirstChild("NodeIcon", true)] = { Image = true }
allowed[fresh.Tree.SelectionGlow] = { Position = true }
local diff = nil
for inst, saved in snap do
	local props = rawget(inst, "_props")
	local skip = allowed[inst] or {}
	for k, v in saved.props do
		if not skip[k] and props[k] ~= v then
			diff = `{inst.Name}.{k}`
		end
	end
end
check(diff == nil, `T6a seuls Visible, Text, Enabled (et NodeIcon.Image, SelectionGlow.Position) changent ({diff or "rien d'autre"})`)
local extra = {}
for _, d in fresh:GetDescendants() do
	if snap[d] == nil then
		table.insert(extra, d.Name)
	end
end
table.sort(extra)
check(table.concat(extra, ",") == "NavLayer,SkillTreeZoom", `T6b objets ajoutés : NavLayer et le zoom de Tree seulement ({table.concat(extra, ",")})`)
check(fresh.Enabled == false and fresh.Tree.Tile_DoorGuard.Locked.Visible == false and fresh.Tree.Tile_DoorGuard.Available.Visible, "T6c écran recréé : rebranché, fermé, Door Guard ouverte (Bodyguards 1)")
check(fresh:FindFirstChild("CashPill").Cash.Text == "$123K", "T6d CashPill.Cash « $123K » (Format.money)")

summary()
