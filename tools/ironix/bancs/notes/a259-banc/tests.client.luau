--!nocheck
-- a259 (vague 75) : Q sons de l’ouverture (L-261), fondu de la caméra (T-222), caméra jamais rendue en Scriptable. a257 (vague 74) : copie du banc client d’a251 sans les mots (K8). a251 (vague 73, L-236) : RevealController avec un plan (Reveal/Unbox), côté client, mise en place du banc a204.
--   U repli codé, ouvreur, sans rien de Clément : colis au sol de l'allée, perso placé, caméra, cote, améliorations,
--     éclat, silhouettes, révélation, croissance, fin, nettoyage ; durées ;
--   K avec les modèles de Clément : outils, effets (EmitCount, RarityColor, Top au point touché, EmitEvery), mots,
--     repère « ? » « ! », objets jetés, fondu des bords, zoom ;
--   A animations du joueur : Impacts par marqueur, moment fort au dernier attendu, animation trop longue coupée ;
--   S spectateur ; W mur devant la caméra ; B plan illisible ; E fin avant l'heure ; M plafond client.
local Cfg = sharedModule("Config/Unbox", "client")
local RaritiesCfg = sharedModule("Config/Rarities", "client")
local Plan = sharedModule("UnboxPlan", "client")
local New = Cfg.New

local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
local function spawn(player, position)
	local character = spawnCharacter(player, position)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.HipHeight = 2
	make("Animator", { Name = "Animator" }, humanoid)
	local hand = make("Part", { Name = "RightHand", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(position + Vector3.new(1, 0, 0)), CanCollide = false }, character)
	make("Attachment", { Name = "RightGripAttachment", CFrame = CFrame.new(0, -0.2, 0) }, hand)
	return character
end
spawn(alice, Vector3.new(65, 3, -50))
spawn(bob, Vector3.new(66, 3, 40))
local hotbar = make("ScreenGui", { Name = "UI_Hotbar", Enabled = true }, alice.PlayerGui)
make("ScreenGui", { Name = "UI_Escape", Enabled = true }, alice.PlayerGui)
local unboxScreen = make("ScreenGui", { Name = "UI_Unbox", Enabled = false }, alice.PlayerGui)
local edge = make("ImageLabel", { Name = "EdgeGlow", ImageTransparency = 1, ImageColor3 = Color3.new(1, 1, 1) }, unboxScreen)
Workspace.CurrentCamera = CAMERA
CAMERA.FieldOfView = 70
local HOME = CFrame.lookAt(Vector3.new(65, 8, -25), Vector3.new(65, 3, -45))
local function homeCamera()
	CAMERA.CameraType = Enum.CameraType.Custom
	CAMERA.CameraSubject = alice.Character:FindFirstChildOfClass("Humanoid")
	CAMERA.CFrame = HOME
end
homeCamera()
dropRig()
startClient(alice)
local RC = clientModule("RevealController")

local PLAN = "Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Rare,Hammer:Rare|37"
local function reveal(opener, store, itemId, rarity, weight, scale, class, id, plan)
	NET.Server.RevealStarted:FireAll(opener, store.Name, store.Name .. "/03", itemId, rarity, "", weight, scale, class, id, plan)
	flush()
end
local function ended(id)
	NET.Server.RevealEnded:FireAll(id)
	flush()
end
local function scene(id)
	for _, s in RC.GetState().Scenes do
		if s.Id == id then
			return s
		end
	end
	return nil
end
local function unbox(id)
	local s = scene(id)
	return s and s.Unbox
end
local function fired(id, marker)
	local s = scene(id)
	return s ~= nil and table.find(s.Fired, marker) ~= nil
end
local function doneCalls(id)
	local n = 0
	for _, c in serverCalls("RevealDone") do
		if c.args[1] == id then
			n += 1
		end
	end
	return n
end
local function advanceUntil(cond, limit)
	local start = now()
	while not cond() and now() - start < limit do
		advance(1 / 30)
	end
	return now() - start
end
local function phase(id)
	local u = unbox(id)
	return u and u.Phase
end
local function flatDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end
local function near(value, target, tolerance)
	return math.abs(value - target) <= tolerance
end

section("U. Repli codé, ouvreur, rien de Clément")
local boxLabel = make("BillboardGui", { Name = "BB_Box", Enabled = true }, BOX1)
local t0 = now()
reveal(alice, STORES[1], ITEM_A.Id, "Rare", 4.5, 1, "Small", "u1", PLAN)
local s = scene("u1")
local u = unbox("u1")
check(s ~= nil and u ~= nil and s.Stage == "Unbox" and u.Phase == "Intro", "U1 scène de l'ouvreur avec un plan : étape Unbox, phase Intro")
check(s and s.Camera == true and CAMERA.CameraType == Enum.CameraType.Scriptable, "U2 caméra prise")
check(BOX1.LocalTransparencyModifier == 1 and fxCopies("UnboxBox") == 1, "U3 colis du rayon caché en local, une copie locale")
local copy = u and u.Box
local loose = false
for _, d in copy and copy:GetDescendants() or {} do
	if d:IsA("BasePart") and (not d.Anchored or d.CanCollide) then
		loose = true
	end
end
check(copy ~= nil and not loose and not copy:HasTag("ShelfBox"), "U4 copie ancrée, sans collision, sans le tag ShelfBox")
check(copy ~= nil and copy:FindFirstChildWhichIsA("BillboardGui", true) == nil, "U4b copie sans l'étiquette BB_Box")
local slotPos = SLOT1.WorldCFrame.Position
local base = u.Base.Position
local bounds = STORES[1]:FindFirstChild("Bounds")
local rel = bounds.CFrame:PointToObjectSpace(base)
check(near(flatDistance(base, slotPos), New.BoxOut, 0.05) and math.abs(rel.X) <= bounds.Size.X / 2 and math.abs(rel.Z) <= bounds.Size.Z / 2, "U5 colis posé à BoxOut studs du rayon, dans le magasin")
check(base.Z > slotPos.Z, "U6 … du côté de l'allée (vers le centre du magasin), pas derrière le rayon")
check(base.Y <= slotPos.Y, "U7 … au sol (pas plus haut que le rayon : y " .. tostring(base.Y) .. ")")
local root = alice.Character.HumanoidRootPart
check(near(flatDistance(root.Position, base), New.StandSide, 0.05), "U8 perso placé à StandSide studs du colis (" .. string.format("%.2f", flatDistance(root.Position, base)) .. ")")
local toBox = Vector3.new(base.X - root.Position.X, 0, base.Z - root.Position.Z).Unit
check(root.CFrame.LookVector:Dot(toBox) > 0.99, "U9 … face au colis")
check(near(root.Position.Y, base.Y + 2 + 1, 0.01), "U10 … debout sur le sol (HipHeight + demi-hauteur)")
check(u.OddsText == "1 IN 2" and u.RarityText == "COMMON" and u.Upgrade == false, "U11 billboard du code : « 1 IN 2 », COMMON, pas d'UPGRADE")
advance(1 / 30)
check(hotbar.Enabled == false, "U12 HUD masqué")
check(boxLabel.Enabled == false, "U12b étiquette BB_Box du vrai colis éteinte pendant la scène")
boxLabel.Enabled = true
advance(1 / 30)
check(boxLabel.Enabled == false, "U12c … rééteinte si ShelfBoxController la rallume")
advanceUntil(function()
	return phase("u1") == "Action"
end, 2)
check(near(now() - t0, New.Intro, 0.07) and unbox("u1").Index == 1 and unbox("u1").Mode == "Fallback", "U13 première action après l'Intro, en repli (aucune animation)")
local camFocus = base + unbox("u1").Base.LookVector * 0
check((CAMERA.CFrame.Position - base).Magnitude > 3 and CAMERA.CFrame.Position.Y > base.Y, "U14 caméra au-dessus du sol, à distance du colis")
advanceUntil(function()
	return phase("u1") == "Gap"
end, 3)
u = unbox("u1")
check(u.Impacts == 4 and u.Index == 1, "U15 scie : 4 Impacts (repli), puis la pause")
advance(New.OddsRoll + 0.05)
u = unbox("u1")
check(u.Odds > 2 and u.Odds <= 4 and u.Tier == "Common" and u.BoxScale == 1, "U16 moment fort 1 : la cote a monté dans la plage Commun (" .. tostring(u.OddsText) .. "), pas d'amélioration")
advanceUntil(function()
	local x = unbox("u1")
	return x.Index == 2 and x.Tier == "Uncommon"
end, 3)
u = unbox("u1")
check(u.Tier == "Uncommon" and near(u.BoxScale, New.UpgradeGrow, 1e-6) and u.Upgrade == true and u.RarityText == "UNCOMMON", "U17 moment fort 2 : amélioration (colis ×1,16, UPGRADE!, UNCOMMON)")
check(CAMERA.FieldOfView <= 70, "U18 zoom en cours ou à venir")
advance(0.15)
check(CAMERA.FieldOfView < 69.5, "U19 zoom : FieldOfView réduit (" .. string.format("%.1f", CAMERA.FieldOfView) .. ")")
advance(New.UpgradeShow)
u = unbox("u1")
check(u.Upgrade == false and u.Odds >= 5 and u.Odds <= 12, "U20 UPGRADE! caché ensuite, cote dans la plage Peu commun (" .. tostring(u.OddsText) .. ")")
advanceUntil(function()
	return phase("u1") == "Burst"
end, 8)
u = unbox("u1")
local burstAt = now() - t0
check(u.Index == 5 and u.Box == nil and fired("u1", "Open") and not fired("u1", "Reveal"), "U21 coup de masse : le colis éclate (marqueur Open), pas encore de Reveal")
check(u.Tier == "Rare" and near(u.BoxScale, New.UpgradeGrow ^ 2, 1e-6), "U22 deux améliorations au total (Rare)")
check(u.RarityText == nil, "U23 plus de cote ni de rareté pendant l'éclat")
check(select(1, playedSounds("Unbox_Open")) >= 1, "U24 son Unbox_Open à l'éclat")
advanceUntil(function()
	return phase("u1") == "Silhouettes"
end, 1)
u = unbox("u1")
check(u.SilhouetteIndex == 1 and u.Silhouette ~= nil and u.RarityText == "COMMON", "U25 première silhouette : COMMON")
local black = true
for _, d in u.Silhouette:GetDescendants() do
	if d:IsA("BasePart") and d.Color ~= Color3.new(0, 0, 0) then
		black = false
	end
end
check(black, "U26 silhouette noire")
local item = scene("u1").Item
check(item ~= nil and item.Parent == nil, "U27 le vrai objet n'est pas encore montré")
advance(New.SilhouetteStep + 0.04)
check(unbox("u1").SilhouetteIndex == 2 and unbox("u1").RarityText == "UNCOMMON" and fxCopies("UnboxSilhouette") == 1, "U28 deuxième silhouette : UNCOMMON, une seule à la fois")
advance(New.SilhouetteStep + 0.04)
check(unbox("u1").SilhouetteIndex == 3 and unbox("u1").RarityText == "RARE", "U29 dernière silhouette : RARE (le vrai objet en noir)")
local revealIn = advanceUntil(function()
	return fired("u1", "Reveal")
end, 3)
local revealAt = now() - t0
-- a257 : 0,3 s de marge (0,25 avant) : chaque phase repart à t = 0 et perd le reste de son image de 1/30 s, deux
-- téléportations de 0,34 s (10,2 images) en perdent un peu plus que deux pauses de 0,25 s.
check(near(revealAt, Plan.revealAt(Plan.parse(PLAN), "Rare"), 0.3), string.format("U30 objet révélé à %.2f s (prévu %.2f s)", revealAt, Plan.revealAt(Plan.parse(PLAN), "Rare")))
u = unbox("u1")
check(item.Parent == Workspace:FindFirstChild("_RevealFX") and u.Silhouette == nil and fxCopies("UnboxSilhouette") == 0, "U31 Reveal : l'objet en couleurs, plus de silhouette")
check(scene("u1").Board ~= nil and scene("u1").Board.Rarity.Text == RaritiesCfg.ById.Rare.DisplayNameUpper, "U32 BB_Reveal (repli du code) posé")
advance(New.OddsRoll + 0.05)
u = unbox("u1")
check(u.OddsText == "1 IN 37" and u.RarityText == nil and u.Board ~= nil, "U33 cote finale « 1 IN 37 » au-dessus de l'objet")
advanceUntil(function()
	return scene("u1") == nil or scene("u1").Stage ~= "Unbox"
end, 2)
check(scene("u1") and scene("u1").Stage == "Grow", "U34 puis l'étape Grow d'avant")
advanceUntil(function()
	return doneCalls("u1") > 0
end, 6)
local doneAt = now() - t0
check(doneCalls("u1") == 1 and fired("u1", "Land"), "U35 Land : RevealDone envoyé une fois")
check(near(doneAt, revealAt + Plan.tailTime("Small"), 0.3), string.format("U36 fin à %.2f s (prévu %.2f s)", doneAt, revealAt + Plan.tailTime("Small")))
check(CAMERA.CameraType == Enum.CameraType.Custom and CAMERA.FieldOfView == 70, "U37 caméra rendue, FieldOfView remis à 70")
advance(1 / 30)
check(hotbar.Enabled == true, "U38 HUD revenu")
ended("u1")
check(scene("u1") == nil and fxCopies("UnboxBox") == 0 and fxCopies("UnboxOdds") == 0 and fxCopies("UnboxAnchor") == 0 and fxCopies("UnboxSilhouette") == 0, "U39 RevealEnded : tout est retiré")
check(BOX1.LocalTransparencyModifier == 0, "U40 colis du rayon remis")

section("K. Avec les modèles de Clément")
for _, name in { "TOOL_Unbox_Sledgehammer", "TOOL_Unbox_Saw", "TOOL_Unbox_Crowbar", "TOOL_Unbox_Drill", "TOOL_Unbox_Magnifier" } do
	buildTool(name)
end
buildJunk("ENV_Unbox_Junk_Duck")
buildJunk("ENV_Unbox_Junk_Sock")
buildFx("FX_Unbox_Hit", 7)
buildFx("FX_Unbox_Sawdust", 3)
buildFx("FX_Unbox_Chips", 2, { EmitEvery = 0.1 })
buildFx("FX_Unbox_Burst", 20)
buildFx("FX_Unbox_Tier", 9)
buildFx("FX_Unbox_Silhouette", 4)
buildFx("FX_Unbox_Puff", 5)
buildFx("FX_Unbox_Overexpose", 6)
buildFx("FX_Unbox_Reveal", 11)
buildBoards()
for _, name in { "Unbox_Tier", "Unbox_Silhouette", "Unbox_Suspense", "UI_Click", "Unbox_Impact" } do
	make("Sound", { Name = name, SoundId = "rbxassetid://9" }, SOUNDS_FOLDER)
end
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
local PLAN2 = "Saw:Common,Inspect:Common,Drill:Epic,Search:Epic,Hammer:Epic|120"
local mark = #EMITS
t0 = now()
reveal(alice, STORES[1], ITEM_A.Id, "Epic", 4.5, 1, "Small", "k1", PLAN2)
u = unbox("k1")
check(u ~= nil and u.Board ~= nil and u.Board.Odds.Text == "1 IN 2" and u.Board.Rarity.Text == "COMMON" and u.Board.Upgrade.Visible == false, "K1 BB_UnboxOdds de Clément : Odds, Rarity, Upgrade caché")
check(unboxScreen.Enabled == true and edge.ImageTransparency == 1, "K2 UI_Unbox allumé, EdgeGlow transparent au repos")
advanceUntil(function()
	return phase("k1") == "Action"
end, 2)
u = unbox("k1")
local tool = u.Tool
check(tool ~= nil and tool.Name == "TOOL_Unbox_Saw" and tool:FindFirstChildWhichIsA("Script", true) == nil, "K3 scie en main (copie sans script)")
local hand = alice.Character.RightHand
local handle = tool and tool:FindFirstChild("Handle")
check(handle ~= nil and (handle.CFrame.Position - hand.RightGripAttachment.WorldCFrame.Position).Magnitude < 0.01, "K4 poignée Handle posée sur la prise de la main droite")
advanceUntil(function()
	return unbox("k1").Impacts >= 1
end, 1)
local boxTopY = unbox("k1").Base.Position.Y + 1.6
check(emitsOf("FX_Unbox_Sawdust", "Dust", mark, 3) >= 1 and emitsOf("FX_Unbox_Sawdust", "Bits", mark, 4) >= 1, "K5 FX_Unbox_Sawdust à l'Impact : Emit(EmitCount) sur chaque émetteur")
local sawFx = Workspace._RevealFX:FindFirstChild("FX_Unbox_Sawdust")
check(sawFx ~= nil and near(sawFx.Root.Top.WorldPosition.Y, boxTopY, 0.05) and near(sawFx.Root.Base.WorldPosition.Y, unbox("k1").Base.Position.Y, 0.05), "K6 Attachment Top au point touché (haut du colis), Base au pied : " .. tostring(sawFx and sawFx.Root.Top.WorldPosition) .. " ; " .. tostring(sawFx and sawFx.Root.Base.WorldPosition) .. " ; attendu y " .. tostring(boxTopY))
local commonColor = RaritiesCfg.ById.Common.Color
check(sawFx and sawFx.Root.Top.Bits.Color.Keypoints[1].Value == commonColor, "K7 émetteur RarityColor : couleur de la rareté montrée")
check(unbox("k1").Words == nil and fxCopies("BB_UnboxWord") == 0, "K8 plus aucun mot BB_UnboxWord à l’Impact (L-253 point 3)")
advance(0.65) -- l’ancien WordTime + 0,1
advanceUntil(function()
	return unbox("k1").Index == 2 and phase("k1") == "Action"
end, 3)
advance(0.5)
check(fxCopies("FX_Unbox_Sawdust") == 0, "K10 effets retirés après leur Duration")
u = unbox("k1")
check(u.Tool ~= nil and u.Tool.Name == "TOOL_Unbox_Magnifier" and fxCopies("TOOL_Unbox_Saw") == 0, "K11 loupe en main, la scie est rangée")
check(u.Mark ~= nil and u.Mark.Mark.Text == "?" and u.Mark.Adornee == alice.Character.Head, "K12 repère « ? » au-dessus de la tête")
advanceUntil(function()
	return unbox("k1").Impacts >= 1 or unbox("k1").Index ~= 2
end, 2)
check(unbox("k1").Mark ~= nil and unbox("k1").Mark.Mark.Text == "!", "K13 repère « ! » au moment fort")
advanceUntil(function()
	return unbox("k1").Index == 3 and phase("k1") == "Action"
end, 3)
check(unbox("k1").Mark == nil and unbox("k1").Tool.Name == "TOOL_Unbox_Drill", "K14 perceuse en main, repère retiré")
mark = #EMITS
advance(0.45)
check(emitsOf("FX_Unbox_Chips", "Dust", mark, 2) >= 3, "K15 FX_Unbox_Chips lancé toutes les EmitEvery s pendant que la perceuse tourne")
local before = edge.ImageTransparency
advanceUntil(function()
	return unbox("k1").Tier == "Epic"
end, 2)
mark = #EMITS - 40
check(emitsOf("FX_Unbox_Tier", "Dust", math.max(mark, 0), 9) >= 1, "K16 FX_Unbox_Tier à l'amélioration")
check(unbox("k1").Board.Upgrade.Visible == true and unbox("k1").Board.Rarity.Text == "EPIC" and unbox("k1").Board.Rarity.TextColor3 == RaritiesCfg.ById.Epic.Color, "K17 UPGRADE! visible, EPIC à sa couleur")
check(select(1, playedSounds("Unbox_Tier")) >= 1, "K18 son Unbox_Tier")
advance(0.12)
check(before == 1 and edge.ImageTransparency < 0.9 and edge.ImageColor3 == RaritiesCfg.ById.Epic.Color, "K19 fondu des bords à la couleur de la rareté (ImageTransparency " .. string.format("%.2f", edge.ImageTransparency) .. ")")
check(CAMERA.FieldOfView < 70 * (1 - New.ZoomStep), "K20 zoom plus fort pour une rareté haute (" .. string.format("%.1f", CAMERA.FieldOfView) .. ")")
advanceUntil(function()
	return unbox("k1").Index == 4 and unbox("k1").Impacts >= 1
end, 3)
check(unbox("k1").Junk >= 1 and unbox("k1").Tool == nil, "K21 fouille : un objet jeté, pas d'outil")
mark = #EMITS
advanceUntil(function()
	return phase("k1") == "Burst"
end, 4)
check(emitsOf("FX_Unbox_Burst", "Dust", mark, 20) == 1 and emitsOf("FX_Unbox_Hit", "Dust", mark, 7) >= 1, "K23 FX_Unbox_Burst au coup de masse (et FX_Unbox_Hit)")
check(unbox("k1").Tool ~= nil and unbox("k1").Tool.Name == "TOOL_Unbox_Sledgehammer", "K24 la masse encore en main à l'éclat")
mark = #EMITS
advanceUntil(function()
	return fired("k1", "Reveal")
end, 5)
check(emitsOf("FX_Unbox_Silhouette", "Dust", mark, 4) == 4 and emitsOf("FX_Unbox_Puff", "Dust", mark, 5) == 4, "K25 FX_Unbox_Silhouette et FX_Unbox_Puff à chacune des 4 silhouettes (Commun à Épique) : " .. emitsOf("FX_Unbox_Silhouette", "Dust", mark, 4) .. " et " .. emitsOf("FX_Unbox_Puff", "Dust", mark, 5) .. ", phase " .. tostring(phase("k1")) .. ", index " .. tostring(unbox("k1").SilhouetteIndex))
check(emitsOf("FX_Unbox_Overexpose", "Dust", mark, 6) == 1 and emitsOf("FX_Unbox_Reveal", "Dust", mark, 11) == 1, "K26 FX_Unbox_Overexpose puis FX_Unbox_Reveal")
check(select(1, playedSounds("Unbox_Silhouette")) >= 4 and select(1, playedSounds("Unbox_Suspense")) >= 1, "K27 sons Unbox_Silhouette et Unbox_Suspense")
check(unbox("k1").Tool == nil and fxCopies("TOOL_Unbox_Sledgehammer") == 0, "K28 masse rangée à la révélation")
check(unbox("k1").Junk == 0 and fxCopies("ENV_Unbox_Junk_Duck") + fxCopies("ENV_Unbox_Junk_Sock") == 0, "K22 objets jetés retirés après JunkLife")
advance(0.12)
check(CAMERA.FieldOfView < 70 * (1 - New.ZoomReveal), "K29 zoom de la révélation plus fort (" .. string.format("%.1f", CAMERA.FieldOfView) .. ")")
advanceUntil(function()
	return doneCalls("k1") > 0
end, 8)
check(doneCalls("k1") == 1 and CAMERA.FieldOfView == 70 and edge.ImageTransparency == 1 and unboxScreen.Enabled == false, "K30 fin : RevealDone, zoom et bords remis, UI_Unbox rééteint")
ended("k1")
check(fxCopies("UnboxBox") + fxCopies("UnboxOdds") + fxCopies("BB_UnboxWord") + fxCopies("BB_UnboxMark") == 0, "K31 rien ne reste")

section("A. Animations du joueur")
buildAnim("Unbox_Saw", 1.0, "Impact=0.2,Impact=0.4,Impact=0.6,Impact=0.8")
buildAnim("Unbox_Kick", 5.0, "Impact=4.5")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
t0 = now()
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "a1", "Saw:Common,Kick:Common,Saw:Common,Kick:Common,Hammer:Common|3")
advanceUntil(function()
	return phase("a1") == "Action"
end, 2)
check(unbox("a1").Mode == "Anim", "A1 Unbox_Saw jouée sur le perso de l'ouvreur")
advance(0.3)
check(unbox("a1").Impacts == 1, "A2 un Impact au premier marqueur (0,2 s), pas avant")
local sawStart = now()
advanceUntil(function()
	return phase("a1") == "Gap"
end, 3)
check(unbox("a1").Impacts == 4 and near(now() - sawStart, 0.7, 0.1), "A3 4 Impacts, action finie avec l'animation (1,0 s)")
advanceUntil(function()
	return unbox("a1").Index == 2 and phase("a1") == "Action"
end, 2)
local kickStart = now()
advanceUntil(function()
	return phase("a1") == "Gap"
end, 6)
local limit = Plan.actionLimit(Plan.action("Kick"))
check(near(now() - kickStart, limit, 0.1) and unbox("a1").Impacts == 0, string.format("A4 animation trop longue (5 s) coupée à %.1f s, sans son Impact", limit))
advance(New.OddsRoll + 0.05)
check(unbox("a1").Odds > 2, "A5 … le moment fort tombe quand même à la coupure (la cote a monté)")
ended("a1")
check(scene("a1") == nil and CAMERA.CameraType == Enum.CameraType.Custom and CAMERA.FieldOfView == 70, "A6 RevealEnded en pleine action : caméra et zoom rendus")
check(fxCopies("UnboxBox") + fxCopies("UnboxOdds") + fxCopies("UnboxAnchor") == 0 and BOX1.LocalTransparencyModifier == 0, "A7 … tout retiré, colis du rayon remis")
check(doneCalls("a1") == 0, "A8 … sans RevealDone")

section("S. Spectateur")
homeCamera()
moveTo(alice, Vector3.new(65, 3, 30))
local alicePos = alice.Character.HumanoidRootPart.Position
reveal(bob, STORES[2], ITEM_A.Id, "Uncommon", 4.5, 1, "Small", "s1", "Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Uncommon,Hammer:Uncommon|8")
s = scene("s1")
check(s ~= nil and s.Opener == false and s.Unbox ~= nil and s.Camera == false and CAMERA.CameraType == Enum.CameraType.Custom, "S1 spectateur : la scène joue, caméra intacte")
check(alice.Character.HumanoidRootPart.Position == alicePos, "S2 le perso du spectateur ne bouge pas")
advanceUntil(function()
	return phase("s1") == "Action"
end, 2)
check(unbox("s1").Mode == "Fallback" and unbox("s1").Tool ~= nil, "S3 actions en repli, outil dans la main de l'ouvreur")
local bobHand = bob.Character.RightHand
check((unbox("s1").Tool.Handle.CFrame.Position - bobHand.RightGripAttachment.WorldCFrame.Position).Magnitude < 0.01, "S4 … la main de Bob")
advanceUntil(function()
	return fired("s1", "Reveal")
end, 14)
check(fired("s1", "Reveal") and CAMERA.FieldOfView == 70 and edge.ImageTransparency == 1, "S5 révélation vue, ni zoom ni fondu des bords chez le spectateur")
advanceUntil(function()
	return fired("s1", "Land")
end, 6)
check(doneCalls("s1") == 0, "S6 pas de RevealDone d'un spectateur")
ended("s1")

section("W. Mur devant la caméra")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
-- La caméra voulue est à Distance studs côté allée : un mur à 3 studs du point visé (plus près que MinDistance) devient
-- transparent, un mur à 8 studs rapproche la caméra.
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "w0", "Saw:Common,Kick:Common,Saw:Common,Kick:Common,Hammer:Common|3")
local wBase = unbox("w0").Base
local aisle = wBase.LookVector
ended("w0")
local focus = wBase.Position + Vector3.new(0, New.Camera.LookHeight, 0)
local nearWall = make("Part", { Name = "NearWall", Anchored = true, Size = Vector3.new(40, 12, 0.4), CFrame = CFrame.lookAt(focus + aisle * 3, focus + aisle * 4) }, Workspace)
homeCamera()
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "w1", "Saw:Common,Kick:Common,Saw:Common,Kick:Common,Hammer:Common|3")
advance(1.5)
check(nearWall.LocalTransparencyModifier == 1 and unbox("w1").SeeThrough >= 1, "W1 mur trop près : transparent pour l'ouvreur")
ended("w1")
check(nearWall.LocalTransparencyModifier == 0, "W2 … remis à la fin")
nearWall:Destroy()
local farWall = make("Part", { Name = "FarWall", Anchored = true, Size = Vector3.new(40, 12, 0.4), CFrame = CFrame.lookAt(focus + aisle * 8, focus + aisle * 9) }, Workspace)
homeCamera()
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "w2", "Saw:Common,Kick:Common,Saw:Common,Kick:Common,Hammer:Common|3")
advance(2.5)
local camSide = (CAMERA.CFrame.Position - focus):Dot(aisle)
check(farWall.LocalTransparencyModifier == 0 and camSide < 8 and camSide > New.Camera.MinDistance - 1, string.format("W3 mur plus loin : la caméra reste devant lui (%.1f studs)", camSide))
ended("w2")
farWall:Destroy()

section("B. Plan illisible, plan absent")
homeCamera()
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "b1", "Fly:Common|3")
s = scene("b1")
check(s ~= nil and s.Unbox == nil and s.Stage == "Open", "B1 plan illisible : la cinématique d'avant")
advance(0.5)
check(fired("b1", "Open"), "B2 … son marqueur Open à 0,45 s")
ended("b1")
homeCamera()
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "b2", nil)
check(scene("b2") ~= nil and scene("b2").Unbox == nil and scene("b2").Stage == "Open", "B3 sans plan : la cinématique d'avant")
ended("b2")

section("M. Plafond client, objet géant")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
buildFx("FX_RevealSmash", 30)
mark = #EMITS
t0 = now()
reveal(alice, STORES[1], ITEM_A.Id, "Common", 600, 3, "Large", "m1", "Saw:Common,Kick:Common,Saw:Common,Kick:Common,Hammer:Common|3")
advanceUntil(function()
	return phase("m1") == "Burst"
end, 20)
check(emitsOf("FX_RevealSmash", "Dust", mark, 30) == 1 and emitsOf("FX_Unbox_Burst", "Dust", mark, 20) == 0, "M1 objet géant : FX_RevealSmash à la place de FX_Unbox_Burst")
advanceUntil(function()
	return fired("m1", "Land")
end, 30)
check(fired("m1", "Explode") and doneCalls("m1") == 1, "M2 Large : le plafond saute pendant la croissance, puis Land")
check(now() - t0 < Plan.clientMaxSeconds("Common", "Large", 5), "M3 fini avant le plafond client (5 actions)")
ended("m1")
STORES[1]:SetAttribute("CeilingBroken", false)
flush()

section("L. Places, téléportations, Stomp et Slam (a257, L-258)")
buildAnim("Unbox_Stomp", 1.1, "Impact=0.5,Impact=1.0")
buildAnim("Unbox_Slam", 1.35, "Impact=1.1")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
mark = #EMITS
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "l1", "Saw:Common,Kick:Common,Hammer:Common|3")
u = unbox("l1")
check(u ~= nil and #u.Moves == 3 and u.Moves[1].Place == "Side" and u.Moves[2].Place == "Other" and u.Moves[3].Place == "Top" and u.Moves[3].Action.Id == "Slam", "L1 trois actions : à côté, de l'autre côté, Unbox_Slam sur le colis")
advanceUntil(function()
	return phase("l1") == "Action"
end, 2)
local lBase = unbox("l1").Base.Position
local first = alice.Character.HumanoidRootPart.Position - lBase
check(unbox("l1").Place == "Side" and near(flatDistance(first + lBase, lBase), New.StandSide, 0.05), "L2 première action à la place Side")
advanceUntil(function()
	return phase("l1") == "Gap"
end, 6)
mark = #EMITS
advance(New.Places.Vanish + 0.04)
check(unbox("l1").Hidden == true and alice.Character.Head.LocalTransparencyModifier == 1, "L3 téléportation : le perso disparaît")
advance(New.Places.Appear - New.Places.Vanish + 0.02)
local second = alice.Character.HumanoidRootPart.Position - lBase
check(unbox("l1").Hidden == false and (alice.Character.Head.LocalTransparencyModifier or 0) == 0 and unbox("l1").Place == "Other", "L4 … et réapparaît à la place Other")
check(Vector3.new(first.X, 0, first.Z):Dot(Vector3.new(second.X, 0, second.Z)) < 0, "L5 … de l'autre côté du colis")
check(emitsOf("FX_Unbox_Puff", "Dust", mark, 5) >= 1, "L6 nuage FX_Unbox_Puff à la téléportation")
advanceUntil(function()
	return unbox("l1").Index == 3 and phase("l1") == "Action"
end, 8)
advance(0.3)
u = unbox("l1")
local onTop = alice.Character.HumanoidRootPart.Position
check(u.Place == "Top" and u.Mode == "Anim" and onTop.Y > lBase.Y + 2.5 and flatDistance(onTop, lBase) < 0.5, string.format("L7 Unbox_Slam debout sur le couvercle (y %.2f, colis %.2f)", onTop.Y, lBase.Y))
check(u.CamLift > 0.3, string.format("L8 la caméra monte avec les pieds (%.2f studs)", u.CamLift))
check(u.Slide > 1, string.format("L9 BB_UnboxOdds glisse sur le côté (%.2f studs)", u.Slide))
advanceUntil(function()
	return fired("l1", "Reveal")
end, 8)
check(unbox("l1").Hidden == false and (alice.Character.Head.LocalTransparencyModifier or 0) == 0, "L10 perso visible à la révélation")
ended("l1")
check(scene("l1") == nil and (alice.Character.Head.LocalTransparencyModifier or 0) == 0 and CAMERA:GetAttribute("UnboxFovBase") == nil, "L11 RevealEnded : perso visible, aucune base de champ de vision laissée")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "l2", "Hammer:Common|2")
u = unbox("l2")
check(u ~= nil and #u.Moves == 1 and u.Moves[1].Place == "Top" and u.Moves[1].Teleport == true, "L12 une seule action : sur le colis, en s'y téléportant")
ended("l2")

section("Q. Sons de l'ouverture, fondu de la caméra, caméra rendue (a259, vague 75, L-261, T-222)")
local PLAYS, STOPS, AT = {}, {}, {}
local oldPlay, oldStop = Methods.Play, Methods.Stop
function Methods.Play(self, ...)
	local ok, isSound = pcall(function()
		return self:IsA("Sound")
	end)
	if ok and isSound then
		table.insert(PLAYS, self)
		local q = scene("q1") or scene("q2")
		AT[self] = q and q.Unbox and q.Unbox.Index
	end
	return oldPlay(self, ...)
end
function Methods.Stop(self, ...)
	STOPS[self] = true
	return oldStop(self, ...)
end
local function plays(name)
	local list = {}
	for _, s in PLAYS do
		if s.Name == name then
			table.insert(list, s)
		end
	end
	return list
end
local function indexOf(name)
	for i, s in PLAYS do
		if s.Name == name then
			return i
		end
	end
	return nil
end
for _, name in { "Unbox_Windup", "Unbox_Swing", "Unbox_HammerHit", "Unbox_Saw", "Unbox_CrowbarWedge", "Unbox_CrowbarCreak", "Unbox_CrowbarCrack", "Unbox_Drill", "Unbox_DrillThrough", "Unbox_KickWhoosh", "Unbox_Kick", "Unbox_Rummage", "Unbox_Toss", "Unbox_InspectHmm", "Unbox_InspectScan", "Unbox_InspectDing", "Unbox_Burst", "Unbox_Smoke", "Unbox_BoxSlide", "Unbox_JunkSqueak", "Unbox_JunkBoing", "Unbox_Rattle", "Unbox_TeleportOut", "Unbox_TeleportIn" } do
	if SOUNDS_FOLDER:FindFirstChild(name) == nil then
		make("Sound", { Name = name, SoundId = "rbxassetid://9", Volume = 1 }, SOUNDS_FOLDER)
	end
end
-- Fumée de L-254 : émetteur Smoke dans FX_Unbox_Hit (et dans FX_Unbox_Sawdust : la scie n'a pas de son de fumée).
for _, fxName in { "FX_Unbox_Hit", "FX_Unbox_Sawdust" } do
	local fx = FX_FOLDER_251:FindFirstChild(fxName)
	make("ParticleEmitter", { Name = "Smoke", Rate = 0 }, fx.Root.Base)
end
buildAnim("Unbox_Slam", 1.35, "Top=0.7,Impact=1.1")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
CAMERA.CameraType = Enum.CameraType.Scriptable -- comme si une autre cinématique (la capture) tenait la caméra
local camStart = CAMERA.CFrame.Position
reveal(alice, STORES[1], ITEM_A.Id, "Epic", 4.5, 1, "Small", "q1", PLAN2)
local steps, last = {}, camStart
for _ = 1, math.ceil(New.Camera.BlendIn * 30) do
	advance(1 / 30)
	table.insert(steps, (CAMERA.CFrame.Position - last).Magnitude)
	last = CAMERA.CFrame.Position
end
local moved = (last - camStart).Magnitude
local biggest = 0
for _, s in steps do
	biggest = math.max(biggest, s)
end
check(moved > 2 and steps[1] <= 0.05 * moved and biggest <= 0.15 * moved, string.format("Q1 T-222 : la caméra part en douceur vers l'ouverture (%.2f studs en %.1f s ; 1re image %.2f, plus grand pas %.2f)", moved, New.Camera.BlendIn, steps[1], biggest))
advanceUntil(function()
	return doneCalls("q1") > 0
end, 40)
local u1 = unbox("q1")
local teleports = 0
for _, move in (u1 and u1.Moves) or {} do
	teleports += if move.Teleport then 1 else 0
end
ended("q1")
check(CAMERA.CameraType == Enum.CameraType.Custom, "Q2 caméra prise en Scriptable : rendue en Custom (jamais laissée en Scriptable) : " .. tostring(CAMERA.CameraType))
local missing = {}
for _, name in { "Unbox_Saw", "Unbox_InspectHmm", "Unbox_InspectScan", "Unbox_InspectDing", "Unbox_Rummage", "Unbox_Toss", "Unbox_Windup", "Unbox_Swing", "Unbox_HammerHit", "Unbox_Burst", "Unbox_Smoke" } do
	if #plays(name) == 0 then
		table.insert(missing, name)
	end
end
check(#missing == 0, "Q3 sons de la scie, de la loupe, de la fouille, de la masse et de l'éclatement joués" .. (if #missing > 0 then " ; manquent : " .. table.concat(missing, ", ") else ""))
check(teleports >= 2 and #plays("Unbox_TeleportOut") + #plays("Unbox_TeleportIn") == 0, "Q4 " .. teleports .. " téléportations, aucun son de téléportation (même présent)")
check((indexOf("Unbox_InspectHmm") or math.huge) < (indexOf("Unbox_InspectScan") or 0), "Q5 Unbox_InspectHmm puis Unbox_InspectScan, l'un après l'autre")
local notStopped = {}
for _, name in { "Unbox_Saw", "Unbox_InspectHmm", "Unbox_InspectScan", "Unbox_Rummage" } do
	for _, s in plays(name) do
		if not STOPS[s] or s.Parent ~= nil then
			table.insert(notStopped, name)
		end
	end
end
local saw = plays("Unbox_Saw")[1]
check(#notStopped == 0 and saw ~= nil and saw.Volume < 1, "Q6 scie, loupe et fouille arrêtées en fondu puis retirées (volume de la scie à l'arrêt " .. tostring(saw and saw.Volume) .. ")" .. (if #notStopped > 0 then " ; pas arrêtés : " .. table.concat(notStopped, ", ") else ""))
local inRange = #plays("Unbox_Toss") > 0
for _, name in { "Unbox_Toss", "Unbox_JunkSqueak", "Unbox_JunkBoing" } do
	for _, s in plays(name) do
		local p = s.PlaybackSpeed
		inRange = inRange and type(p) == "number" and p >= 0.9 and p <= 1.15
	end
end
check(inRange and #plays("Unbox_JunkSqueak") + #plays("Unbox_JunkBoing") >= 1, "Q7 objet jeté : son du canard ou boing, hauteur au hasard entre 0,9 et 1,15 (avec Unbox_Toss)")
local smokes = plays("Unbox_Smoke")
local middleQuiet, fromSaw = true, 0
for i, s in smokes do
	if i > 1 and i < #smokes then
		middleQuiet = middleQuiet and s.Volume <= New.Sounds.SmokeAgainVolume + 1e-6
	end
	fromSaw += if AT[s] == 1 then 1 else 0
end
check(#smokes >= 2 and smokes[1].Volume == 1 and smokes[#smokes].Volume == 1 and middleQuiet and fromSaw == 0, "Q8 Unbox_Smoke : plein la 1re fois et à l'éclatement, " .. New.Sounds.SmokeAgainVolume .. " au plus entre les deux, jamais pour la scie (" .. #smokes .. " fois)")
-- Sans Unbox_Stomp ni Unbox_Slam : 5 actions à Side, Other, Side, Side, Side : deux pauses à la même place.
for _, name in { "Unbox_Stomp", "Unbox_Slam" } do
	local a = ASSETS.Animations.Player:FindFirstChild(name)
	if a then
		a:Destroy()
	end
end
buildAnim("Unbox_Kick", 0.8, "Impact=0.5") -- la section A la fait trop longue (5 s) : son Impact y est coupé
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "q2", "Kick:Common,Kick:Common,Kick:Common,Kick:Common,Hammer:Common|5")
local u2 = unbox("q2")
local samePlace = 0
for i, move in (u2 and u2.Moves) or {} do
	samePlace += if i > 1 and not move.Teleport then 1 else 0
end
advanceUntil(function()
	return doneCalls("q2") > 0
end, 60)
ended("q2")
local rattles = plays("Unbox_Rattle")
local rising = samePlace >= 2 and #rattles == samePlace
for _, s in rattles do
	rising = rising and s.Looped == true and STOPS[s] == true and AT[s] ~= nil and math.abs(s.PlaybackSpeed - (1 + New.Sounds.RattlePitchStep * (AT[s] - 1))) < 1e-6
end
check(rising, "Q9 Unbox_Rattle à chaque pause à la même place, en boucle, plus aigu à chaque action faite, arrêté à l'action suivante (" .. #rattles .. " sur " .. samePlace .. ")")
check(#plays("Unbox_KickWhoosh") >= 4 and #plays("Unbox_Kick") >= 4 and #plays("Unbox_BoxSlide") >= 4, "Q10 coup de pied : Unbox_KickWhoosh, Unbox_Kick et Unbox_BoxSlide (le colis glisse) : " .. #plays("Unbox_KickWhoosh") .. ", " .. #plays("Unbox_Kick") .. ", " .. #plays("Unbox_BoxSlide"))
Methods.Play, Methods.Stop = oldPlay, oldStop


summary("scénario client")
