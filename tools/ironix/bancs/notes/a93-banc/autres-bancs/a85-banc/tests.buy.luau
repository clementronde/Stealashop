--!nocheck
---------------------------------------------------------------- scénario « buy » : achat, refus, effets
start85({
	Cash = 1_000_000,
	Skill_Walls = 1,
	Skill_GlassThickness = 2,
	Skill_GlassRegen = 0,
	Skill_Cameras = 0,
	Skill_Bodyguards = 0,
	Skill_PotionLuck = 0,
	Skill_Curtain = 0,
	Skill_DoorGuard = 0,
	Skill_PotionTime = 0,
	Skill_Traps = 0,
	Skill_Safe = 0,
})
SKILL.Open()
step(1.6)
local buy, need = panelEl("BuyButton"), panelEl("NeedButton")

section("B1. Achat envoyé, 2e clic ignoré tant que le serveur n'a pas répondu")
check(SKILL.Select("Tile_GlassRegen") and buy.Visible and not need.Visible, "B1a Glass Regen à $50K, argent $1M : BuyButton")
local soundsFrom = #SOUNDS_PLAYED
click(buy)
check(table.concat(sentOf("BuySkill"), ",") == "GlassRegen", "B1b BUY envoie BuySkill(\"GlassRegen\") (seulement l'Id)")
click(buy)
check(#sentOf("BuySkill") == 1, "B1c 2e clic juste après : ignoré (réponse pas encore arrivée)")
step(0.3)
check(table.find(soundsSince(soundsFrom), "UI_Success") == nil, "B1d pas de UI_Success au clic (SkipScreens) : seulement quand le niveau monte")

section("B2. Le serveur accepte : le niveau monte, l'argent baisse")
soundsFrom = #SOUNDS_PLAYED
local regen = tile("Tile_GlassRegen")
local safe = tile("Tile_Next4")
P1:SetAttribute("Cash", 950_000)
P1:SetAttribute("Skill_GlassRegen", 1)
check(shownLayer("Tile_GlassRegen") == "Bought" and tileEl("Tile_GlassRegen", "Info.Level").Text == "Lv 1/5", "B2a Glass Regen : Bought, Lv 1/5")
check(countNamed(regen.Bought, "Flash") == 1, "B2b éclat : une copie « Flash » du corps dans le calque Bought (T.59)")
local flash = regen.Bought:FindFirstChild("Flash")
check(flash and flash.ImageTransparency == 0 and sameColor(flash.ImageColor3, Color3.new(1, 1, 1)), "B2c éclat blanc, opaque au départ")
check(countNamed(TREE, "FxSpark") == ST.SparkCount, `B2d {ST.SparkCount} étincelles dans Tree (T.60)`)
check(shownLayer("Tile_Next4") == "Locked", "B2e Safe (voisine) : encore Locked au moment de l'achat")
local peak, cash = 0, GUI.CashPill.Cash
local texts, popSeen = { cash.Text }, false
for _ = 1, 9 do
	step(1 / 30)
	peak = math.max(peak, fxScale(regen).Scale)
	if cash.Text ~= texts[#texts] then
		table.insert(texts, cash.Text)
	end
	popSeen = popSeen or scaleNamed(GUI.CashPill, UiMotionC.PopScaleName) ~= nil
end
check(peak > 1.25 and peak <= ST.PunchTo + 1e-6, `B2f la tuile gonfle jusqu'à ~{ST.PunchTo} (vu {string.format("%.2f", peak)}, T.57)`)
check(popSeen, "B2g CashPill sursaute (CashBump, T.16)")
check(table.find(soundsSince(soundsFrom), "UI_Success") ~= nil, "B2h UI_Success 0,12 s après (T.33)")
check(shownLayer("Tile_Next4") == "Locked", "B2i Safe : Locked pendant l'attente (0,30 s)")
step(0.2)
check(shownLayer("Tile_Next4") == "Available" and tileEl("Tile_Next4", "Info").Visible, "B2j Safe se découvre : Available (T.61)")
check(countNamed(safe, "FxNewBadge") == 1, "B2k badge NEW! créé par le code sur la tuile découverte")
local badge = safe:FindFirstChild("FxNewBadge")
check(badge and badge.Text == "NEW!", "B2l badge « NEW! »")
step(0.5)
check(regen.Bought:FindFirstChild("Flash") == nil, "B2m éclat détruit après 0,35 s")
for _ = 1, 30 do
	step(1 / 30)
	if cash.Text ~= texts[#texts] then
		table.insert(texts, cash.Text)
	end
end
check(#texts >= 3 and texts[#texts] == "$950K", `B2n l'argent défile jusqu'à $950K (T.15 : {#texts} valeurs vues)`)
step(2)
check(countNamed(GUI, "FxSpark") == 0 and countNamed(GUI, "FxNewBadge") == 0 and countNamed(GUI, "Flash") == 0, "B2o rien de laissé (étincelles, badge, éclat)")
check(math.abs(fxScale(regen).Scale - 1) < 1e-3 and math.abs(fxScale(safe).Scale - 1) < 1e-3, "B2p les deux tuiles reviennent à 1 (Elastic, puis pop)")
check(SKILL.Select("Tile_Next4") and panelEl("NodeName").Text == "SAFE", "B2q la tuile découverte se choisit")
SKILL.Select("Tile_GlassRegen")
check(buy.Visible and panelEl("NodePrice").Text == "$500K" and panelEl("NodeEffect").Text == "4%/s  ▶  5%/s", "B2r panneau : niveau suivant $500K, « 4%/s  ▶  5%/s »")
click(buy)
check(#sentOf("BuySkill") == 2, "B2s le niveau a changé : un nouveau clic part tout de suite")

section("B3. Refus : l'argent manque (T.18)")
SKILL.Select("Tile_Glass")
step(0.3)
check(need.Visible and not buy.Visible and panelEl("NeedLabel").Text == "Need $4M", "B3a Glass à $4M : NeedButton « Need $4M »")
local base = need.Position
soundsFrom = #SOUNDS_PLAYED
local sent = #SENT
click(need)
local moved = false
for _ = 1, 8 do
	step(1 / 30)
	moved = moved or not sameUDim2(need.Position, base)
end
check(moved, "B3b NeedButton tremble")
step(0.5)
check(sameUDim2(need.Position, base) and need.Position == base, "B3c puis revient exactement à sa Position")
check(table.find(soundsSince(soundsFrom), "UI_Deny") ~= nil, "B3d son UI_Deny")
check(#SENT == sent, "B3e rien n'est envoyé")

section("B4. Le serveur ne répond pas (refus côté serveur) : nouvel essai après l'attente")
P1:SetAttribute("Cash", 5_000_000)
step(0.1)
check(buy.Visible, "B4a argent $5M : BuyButton")
click(buy)
click(buy)
check(#sentOf("BuySkill") == 3, "B4b un seul envoi pendant l'attente")
step(1.1)
click(buy)
check(#sentOf("BuySkill") == 4 and sentOf("BuySkill")[4] == "GlassThickness", "B4c après 1 s sans réponse : le clic repart")

section("B5. BUY sur une tuile qui ne s'achète pas : refus, rien d'envoyé")
SKILL.Select("Tile_Curtain")
step(0.3)
check(not buy.Visible and need.Visible and panelEl("NeedLabel").Text == "Coming soon", "B5a Curtain pas codé : « Coming soon »")
soundsFrom = #SOUNDS_PLAYED
sent = #SENT
click(buy)
step(0.5)
check(#SENT == sent and table.find(soundsSince(soundsFrom), "UI_Deny") ~= nil, "B5b BuyButton (caché) cliqué quand même : UI_Deny, rien d'envoyé")

section("B6. Niveau qui monte écran fermé : pas d'effet")
SKILL.Close()
step(0.5)
P1:SetAttribute("Skill_Walls", 2)
step(0.1)
check(countNamed(GUI, "FxSpark") == 0 and countNamed(GUI, "Flash") == 0 and countNamed(GUI, "FxNewBadge") == 0, "B6a ni éclat, ni étincelles, ni badge")
check(shownLayer("Tile_Next1") == "Available", "B6b Traps ouverte (Walls 2) tout de suite")

summary()
