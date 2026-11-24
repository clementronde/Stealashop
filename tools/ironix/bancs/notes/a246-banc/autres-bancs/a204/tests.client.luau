--!nocheck
-- a204 (vague 62, L-198) : RevealController, côté client, mise en place du banc a68 (a42 copie a71).
--   R repli codé (sans rig) : ouvreur, Small ; I objet V0, billboard, mutation ; A rig + animations (Large, plafond
--   greybox, CeilingBroken du serveur, retour du plafond) ; P attribut posé avant l'Explode, éclats de CeilingFractured ;
--   L appareil faible ; M marqueurs absents ; E animation vide, rig sans AnimationController ou sans CameraPart ;
--   C classes (Large sans plafond, Colossal vue de loin, objet léger) ; S spectateur (près, loin, ouvreur parti) ;
--   D mort et personnage retiré ; T deux cinématiques en même temps, nouvelle cinématique de l'ouvreur ;
--   X plafond MaxSeconds, HoldMax ; B envois inutilisables ; J plafond pour un joueur qui n'a pas vu la scène.
local RevealCfg = sharedModule("Config/Reveal", "client")
local RaritiesCfg = sharedModule("Config/Rarities", "client")
local Logic = requireModule(CONTROLLERS.Reveal.Logic, "client")

local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
spawnCharacter(alice, Vector3.new(65, 3, -40))
spawnCharacter(bob, Vector3.new(66, 3, 40))
local hud = make("ScreenGui", { Name = "UI_HUD" }, alice.PlayerGui)
local hotbar = make("ScreenGui", { Name = "UI_Hotbar", Enabled = true }, alice.PlayerGui)
local escape = make("ScreenGui", { Name = "UI_Escape", Enabled = true }, alice.PlayerGui)
Workspace.CurrentCamera = CAMERA
local HOME = CFrame.lookAt(Vector3.new(65, 8, -25), Vector3.new(65, 3, -45))
local function homeCamera()
	CAMERA.CameraType = Enum.CameraType.Custom
	CAMERA.CameraSubject = alice.Character:FindFirstChildOfClass("Humanoid")
	CAMERA.CFrame = HOME
end
homeCamera()
startClient(alice)
local RC = clientModule("RevealController")
local Shatter = clientModule("ShatterController")
local Feel = clientModule("UiFeelController")

local function reveal(opener, store, itemId, rarity, mutation, weight, scale, class, id)
	NET.Server.RevealStarted:FireAll(opener, store.Name, store.Name .. "/03", itemId, rarity, mutation or "", weight, scale, class, id)
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
local function fx()
	return Workspace:FindFirstChild("_RevealFX")
end
local function fxNamed(name)
	local n = 0
	local f = fx()
	if f then
		for _, c in f:GetChildren() do
			if c.Name == name then
				n += 1
			end
		end
	end
	return n
end
local function ceilingHidden(store)
	local c = store:FindFirstChild("Ceiling")
	return c ~= nil and c.LocalTransparencyModifier == 1
end
local function scriptable()
	return CAMERA.CameraType == Enum.CameraType.Scriptable
end
-- Avance jusqu'à ce que `cond` soit vrai (au plus `limit` s) ; rend le temps passé.
local function advanceUntil(cond, limit)
	local start = now()
	while not cond() and now() - start < limit do
		advance(1 / 30)
	end
	return now() - start
end

section("R. Repli codé, ouvreur, Small")
dropRig()
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 4.5, 1.4, "Small", "r1")
local s = scene("r1")
check(s ~= nil and s.Opener == true and s.Rig == nil and s.Mode == "Fallback", "R1 scène de l'ouvreur, sans rig : repli")
check(s and s.Camera == true and scriptable(), "R2 caméra prise (Scriptable)")
advance(1 / 30)
check(hotbar.Enabled == false and escape.Enabled == true, "R3 HUD masqué, UI_Escape gardé")
local item = s and s.Item
check(item ~= nil and item.Parent == nil, "R4 objet pas encore montré avant le Reveal")
advance(0.45)
check(fired("r1", "Open") and not fired("r1", "Reveal"), "R5 Open à 0,45 s, pas encore Reveal")
check(select(1, playedSounds("Unbox_Open")) >= 1, "R6 son Unbox_Open joué")
advance(0.5)
check(fired("r1", "Reveal") and item.Parent == fx(), "R7 Reveal : objet dans _RevealFX")
check(BOX1.LocalTransparencyModifier == 1, "R8 colis du rayon caché en local")
check(item:FindFirstChildWhichIsA("Script", true) == nil, "R9 scripts retirés de la copie ITM")
local anyLoose = false
for _, d in item:GetDescendants() do
	if d:IsA("BasePart") and (not d.Anchored or d.CanCollide) then
		anyLoose = true
	end
end
check(not anyLoose, "R10 objet ancré, sans collision")
local board = scene("r1").Board
check(board ~= nil and board.ItemName.Text == ITEM_A.DisplayName and board.Weight.Text == "4.5 kg", "R11 billboard V0 : nom, poids")
check(board and board.Rarity.Text == RaritiesCfg.ById.Common.DisplayNameUpper and board.Mutation.Visible == false, "R12 rareté, pas de mutation")
check(Feel.flashes == 0, "R13 pas de flash pour un Commun")
advance(0.8)
local cam = CAMERA.CFrame
local itemPos = SLOT1.WorldCFrame.Position
check(cam.Position.Z > itemPos.Z + 3 and cam.LookVector:Dot((itemPos - cam.Position).Unit) > 0.9, "R14 caméra devant l'objet, côté allée, qui le regarde")
local t = advanceUntil(function()
	return doneCalls("r1") > 0
end, 4)
check(doneCalls("r1") == 1 and fired("r1", "Land"), "R15 Land : RevealDone(r1) envoyé")
check(t < 2.5, "R16 Land à l'heure du repli (" .. string.format("%.2f", 1.75 + t) .. " s)")
check(not scriptable() and CAMERA.CameraSubject == alice.Character.Humanoid, "R17 caméra rendue (Custom, humanoïde)")
advance(1 / 30)
check(hotbar.Enabled == true, "R18 HUD rendu")
check(near(item:GetScale(), 1.4, 1e-3) and scene("r1").Stage == "Hold", "R19 objet à sa taille finale (1,4), en attente")
check(not ceilingHidden(STORES[1]), "R20 Small : plafond intact")
advance(0.5)
ended("r1")
check(scene("r1") == nil and isDestroyed(item) and (board == nil or isDestroyed(board)), "R21 RevealEnded : objet et billboard détruits")
check(BOX1.LocalTransparencyModifier == 0, "R22 colis remis")
advance(1)
check(doneCalls("r1") == 1, "R23 RevealDone une seule fois")

section("I. Objet V0, billboard de Clément, mutation, flash")
local tpl = make("BillboardGui", { Name = "BB_Reveal" }, UI_FOLDER)
make("TextLabel", { Name = "ItemName" }, tpl)
make("TextLabel", { Name = "Rarity" }, tpl)
make("TextLabel", { Name = "Mutation" }, tpl)
local fxModel = make("Model", { Name = "FX_ShelfReveal" }, folder(ASSETS, "FX"))
local fxPart = make("Part", { Name = "P" }, fxModel)
fxModel.PrimaryPart = fxPart
make("ParticleEmitter", { Name = "Burst" }, fxPart)
reveal(alice, STORES[1], ITEM_B.Id, "Epic", "Golden", 1250, 1, "Small", "i1")
advance(1)
s = scene("i1")
check(s.Item.PrimaryPart and s.Item.PrimaryPart.Name == "Root" and s.Item.PrimaryPart.Color == RaritiesCfg.ById.Epic.Color, "I1 sans ITM : bloc V0 à la couleur de la rareté")
check(s.Board and s.Board.Mutation.Text == "GOLDEN" and s.Board.Rarity.Text == RaritiesCfg.ById.Epic.DisplayNameUpper, "I2 BB_Reveal de Clément cloné (mutation, rareté)")
check(s.Board:FindFirstChild("Weight") == nil, "I3 Weight absent du billboard : rien d'ajouté, pas d'erreur")
check(#EMITS >= 1 and EMITS[#EMITS].n == RevealCfg.RevealEmit, "I4 FX_ShelfReveal lancé au Reveal")
check(Feel.flashes == 1, "I5 flash d'UI_Escape pour un Épique (ouvreur)")
check(Logic.formatWeight(1250) == "1 250 kg" and Logic.formatWeight(5) == "5 kg", "I6 poids : « 1 250 kg », « 5 kg »")
advance(3)
ended("i1")
tpl:Destroy()

section("A. Rig et animations, Large, plafond greybox")
buildRig({
	OpenCommon = { 1.0, "Open=0.2,Reveal=0.5" },
	GrowLarge = { 2.0, "Grow=0.2,Explode=1.0,Top=1.4,Land=1.8", true },
})
local logStart = #ANIM_LOG
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 300, 3, "Large", "a1")
s = scene("a1")
check(s.Rig ~= nil and s.Mode == "Anim" and ANIM_LOG[logStart + 1] and ANIM_LOG[logStart + 1].name == "OpenCommon", "A1 rig copié, OpenCommon jouée")
advance(0.3)
check(fired("a1", "Open") and not fired("a1", "Reveal"), "A2 marqueur Open de l'animation")
advance(0.3)
check(fired("a1", "Reveal"), "A3 marqueur Reveal")
advance(0.5)
local last = ANIM_LOG[#ANIM_LOG]
check(last.name == "GrowLarge" and scene("a1").Mode == "Anim", "A4 fin d'OpenCommon : GrowLarge jouée")
advanceUntil(function()
	return BENCH_TRACKS[1] ~= nil and BENCH_TRACKS[1].TimePosition >= 0.8
end, 2)
local mid = scene("a1").Scale
check(mid > 1.6 and mid < 2.4, "A5 croissance au fil de la piste, Grow → Top (" .. string.format("%.2f", mid) .. ")")
local anchorPos = SLOT1.WorldCFrame.Position
local expected = Vector3.new(0, 3, -8).Magnitude * math.max(mid, RevealCfg.Camera.MinScale)
check(near((CAMERA.CFrame.Position - anchorPos).Magnitude, expected, 0.05), "A6 caméra sur CameraPart, écart × taille de l'objet")
check(not ceilingHidden(STORES[1]), "A7 plafond encore là avant Explode")
advanceUntil(function()
	return fired("a1", "Explode")
end, 2)
check(ceilingHidden(STORES[1]) and STORES[1].RoofSlab.LocalTransparencyModifier == 1 and STORES[1].CeilingLight_01.LocalTransparencyModifier == 1, "A8 Explode : Ceiling, RoofSlab, CeilingLight_ cachés")
check(fxNamed("CeilingChunk") == RevealCfg.Ceiling.V0Chunks, "A9 sans CeilingFractured : 16 morceaux V0")
check(select(1, playedSounds("Glass_BreakShatter")) + select(1, playedSounds("Ceiling_Crash")) >= 1, "A10 son de l'explosion (Ceiling_Crash depuis a246)")
STORES[1]:SetAttribute("CeilingBroken", true)
local explodedAt = now()
advance(1)
local ok = true
for _, c in fx():GetChildren() do
	if c.Name == "CeilingChunk" and c.Position.Y - c.Size.Y / 2 < 0.5 - 1e-3 then
		ok = false
	end
end
check(ok, "A11 morceaux jamais sous le sol du magasin")
advanceUntil(function()
	return doneCalls("a1") > 0
end, 2)
check(doneCalls("a1") == 1 and not scriptable(), "A12 Land (marqueur) : RevealDone, caméra rendue")
ended("a1")
advance(3)
check(fxNamed("CeilingChunk") == 0, "A13 morceaux effacés puis détruits")
STORES[1]:SetAttribute("CeilingBroken", false)
advance(1 / 30)
check(ceilingHidden(STORES[1]), "A14 attribut faux mais LocalHold pas passé : plafond toujours ouvert")
advance(explodedAt + RevealCfg.Ceiling.LocalHold + 0.1 - now())
check(not ceilingHidden(STORES[1]) and STORES[1].RoofSlab.LocalTransparencyModifier == 0, "A15 plafond revenu (LocalHold passé, attribut faux)")

section("P. Attribut posé dès le début, éclats de CeilingFractured")
STORES[2]:SetAttribute("CeilingBroken", true)
reveal(alice, STORES[2], ITEM_A.Id, "Rare", "", 300, 3, "Large", "p1")
check(not ceilingHidden(STORES[2]), "P0 attribut arrivé avant RevealStarted : plafond remis pour la scène")
advance(2)
check(not ceilingHidden(STORES[2]), "P1 attribut vrai mais scène en attente : plafond gardé jusqu'à l'Explode")
advanceUntil(function()
	return fired("p1", "Explode")
end, 2)
local shards, visible = 0, true
for _, c in fx():GetChildren() do
	if string.sub(c.Name, 1, 6) == "Shard_" then
		shards += 1
		visible = visible and c.Transparency == 0
	end
end
check(shards == 12 and visible, "P2 12 copies visibles des Shard_NN")
check(STORES[2].CeilingFractured.Shard_01.Transparency == 1 and STORES[2].CeilingFractured.Shard_01.Parent ~= nil, "P3 éclats de la map intacts (invisibles)")
check(ceilingHidden(STORES[2]), "P4 plafond caché")
advance(4)
ended("p1")
STORES[2]:SetAttribute("CeilingBroken", false)
advance(RevealCfg.Ceiling.LocalHold)
check(not ceilingHidden(STORES[2]), "P5 plafond revenu")

section("L. Appareil faible")
Shatter.low = true
local emitsBefore = #EMITS
reveal(alice, STORES[2], ITEM_A.Id, "Common", "", 300, 3, "Large", "l1")
advanceUntil(function()
	return fired("l1", "Explode")
end, 5)
shards = 0
for _, c in fx():GetChildren() do
	if string.sub(c.Name, 1, 6) == "Shard_" then
		shards += 1
	end
end
check(shards == RevealCfg.Ceiling.LowEndShards, "L1 8 éclats au plus")
check(#EMITS == emitsBefore, "L2 pas de FX_ShelfReveal")
advance(4)
ended("l1")
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 300, 3, "Large", "l2")
advanceUntil(function()
	return fired("l2", "Explode")
end, 5)
check(fxNamed("CeilingChunk") == RevealCfg.Ceiling.V0ChunksLowEnd, "L3 5 morceaux V0")
advance(4)
ended("l2")
Shatter.low = false
advance(RevealCfg.Ceiling.LocalHold)

section("M. Marqueurs absents")
buildRig({
	OpenRare = { 0.8, "" },
	GrowColossal = { 1.5, "Grow=0.1" },
})
reveal(alice, STORES[2], ITEM_A.Id, "Rare", "", 9000, 6, "Colossal", "m1")
advance(0.5)
check(not fired("m1", "Open"), "M1 rien avant la fin de l'animation sans marqueurs")
advanceUntil(function()
	return fired("m1", "Reveal")
end, 1)
check(fired("m1", "Open") and fired("m1", "Reveal"), "M2 fin d'OpenRare : Open puis Reveal")
advanceUntil(function()
	return fired("m1", "Grow")
end, 1)
advance(0.7)
check(not fired("m1", "Explode") and scene("m1").Scale > 1 and scene("m1").Scale < 6, "M3 croissance jusqu'à la fin de la piste (Top absent)")
advanceUntil(function()
	return doneCalls("m1") > 0
end, 2)
check(fired("m1", "Explode") and fired("m1", "Top") and fired("m1", "Land") and ceilingHidden(STORES[2]), "M4 fin de GrowColossal : Explode, Top, Land")
check(near(scene("m1").Scale, 6, 1e-3), "M5 taille finale à Land")
ended("m1")
advance(RevealCfg.Ceiling.LocalHold + 1)

section("E. Animation vide, rig incomplet")
buildRig({ OpenEpic = { 0, "" } })
Feel.flashes = 0
reveal(alice, STORES[1], ITEM_A.Id, "Epic", "", 10, 1, "Small", "e1")
check(scene("e1").Mode == "Anim", "E1 OpenEpic chargée")
advance(RevealCfg.AnimLoadWait + 0.05)
check(scene("e1").Mode == "Fallback", "E2 toujours vide après AnimLoadWait : repli")
advanceUntil(function()
	return doneCalls("e1") > 0
end, 5)
check(doneCalls("e1") == 1 and Feel.flashes == 1, "E3 GrowSmall absente : repli jusqu'à Land, flash Épique")
ended("e1")
buildRig({ OpenCommon = { 1, "Open=0.1,Reveal=0.2" } }, true)
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "e2")
check(scene("e2").Rig ~= nil and scene("e2").Mode == "Fallback", "E4 rig sans AnimationController : repli, rig gardé")
advanceUntil(function()
	return doneCalls("e2") > 0
end, 5)
check(doneCalls("e2") == 1, "E5 jusqu'à Land")
ended("e2")
local rig = buildRig({ OpenCommon = { 1, "Open=0.1,Reveal=0.2" } })
rig.CameraPart:Destroy()
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "e3")
check(scene("e3").Rig == nil and scene("e3").Mode == "Fallback", "E6 rig sans CameraPart : ignoré, repli")
advanceUntil(function()
	return doneCalls("e3") > 0
end, 5)
ended("e3")
dropRig()
check(fx() == nil or #fx():GetChildren() == 0, "E7 rien ne reste dans _RevealFX")

section("C. Classes en repli")
reveal(alice, STORES[3], ITEM_A.Id, "Common", "", 300, 3, "Large", "c1")
advanceUntil(function()
	return doneCalls("c1") > 0
end, 6)
check(fired("c1", "Explode") and fxNamed("CeilingChunk") == 0, "C1 Large sans plafond : Explode sans rien casser")
ended("c1")
reveal(alice, STORES[2], ITEM_A.Id, "Mythic", "", 20000, 8, "Colossal", "c2")
advanceUntil(function()
	return fired("c2", "Explode")
end, 5)
advance(1.4)
local itemBase = SLOT2.WorldCFrame.Position
check(CAMERA.CFrame.Position.Z < 30.75 - 20 and (CAMERA.CFrame.Position - itemBase).Magnitude > RevealCfg.Camera.FarBack, "C2 Colossal après Explode : vue de loin devant la vitrine")
check(CAMERA.CFrame.LookVector:Dot((itemBase - CAMERA.CFrame.Position).Unit) > 0.8, "C3 qui regarde l'objet")
t = advanceUntil(function()
	return doneCalls("c2") > 0
end, 3)
check(doneCalls("c2") == 1, "C4 Land du Colossal")
ended("c2")
advance(RevealCfg.Ceiling.LocalHold + 1)
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 0.4, 0.6, "Small", "c3")
advance(1.2)
check(near(scene("c3").Scale, 0.6, 0.05), "C4b objet léger : montré à sa taille (0,6), sans grandir")
advanceUntil(function()
	return doneCalls("c3") > 0
end, 4)
check(near(scene("c3").Item:GetScale(), 0.6, 1e-3), "C5 taille finale 0,6")
ended("c3")

section("S. Spectateur")
homeCamera()
local homeCF = CAMERA.CFrame
local doneBefore = #serverCalls("RevealDone")
local flashesBefore = Feel.flashes
reveal(bob, STORES[1], ITEM_A.Id, "Legendary", "", 50, 1.2, "Small", "s1")
s = scene("s1")
check(s ~= nil and s.Opener == false and s.Camera == false, "S1 scène vue par un spectateur, caméra non prise")
advance(1)
check(fired("s1", "Reveal") and s.Item.Parent == fx(), "S2 objet montré dans le monde")
check(CAMERA.CameraType == Enum.CameraType.Custom and CAMERA.CFrame == homeCF and hotbar.Enabled == true, "S3 caméra et HUD du spectateur intacts")
local _, on3d = playedSounds("Unbox_UpgradePop")
check(on3d >= 1, "S4 sons sur l'objet (3D)")
check(Feel.flashes == flashesBefore, "S5 pas de flash chez le spectateur")
advance(3)
check(#serverCalls("RevealDone") == doneBefore and fired("s1", "Land"), "S6 Land sans RevealDone (pas l'ouvreur)")
ended("s1")
CAMERA.CFrame = CFrame.new(600, 10, 0)
local skipped = RC.GetState().Skipped
reveal(bob, STORES[1], ITEM_A.Id, "Common", "", 50, 1, "Small", "s2")
check(scene("s2") == nil and RC.GetState().Skipped == skipped + 1, "S7 trop loin : rien")
homeCamera()
reveal(bob, STORES[1], ITEM_A.Id, "Common", "", 50, 1, "Small", "s3")
advance(1)
local s3item = scene("s3").Item
Players.PlayerRemoving:Fire(bob)
flush()
check(scene("s3") == nil and isDestroyed(s3item) and BOX1.LocalTransparencyModifier == 0, "S8 ouvreur parti : scène finie, tout remis")

section("D. Mort et personnage retiré")
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "d1")
advance(1.2)
local dItem = scene("d1").Item
alice.Character.Humanoid.Died:Fire()
flush()
advance(1 / 30)
check(scene("d1") == nil and not scriptable() and CAMERA.CameraSubject == alice.Character.Humanoid, "D1 mort : scène finie, caméra rendue")
check(hotbar.Enabled == true and isDestroyed(dItem) and BOX1.LocalTransparencyModifier == 0, "D2 HUD rendu, objet détruit, colis remis")
check(doneCalls("d1") == 0, "D3 pas de RevealDone")
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "d2")
advance(0.5)
alice.CharacterRemoving:Fire(alice.Character)
flush()
advance(1 / 30)
check(scene("d2") == nil and not scriptable() and hotbar.Enabled == true, "D4 personnage retiré : caméra et HUD rendus")
spawnCharacter(alice, Vector3.new(65, 3, -40))
homeCamera()

section("T. Deux cinématiques en même temps")
spawnCharacter(bob, Vector3.new(66, 3, 40))
CAMERA.CFrame = CFrame.lookAt(Vector3.new(65, 8, 0), Vector3.new(65, 3, -45))
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "t1")
reveal(bob, STORES[2], ITEM_B.Id, "Common", "", 300, 3, "Large", "t2")
check(scene("t1").Camera == true and scene("t2").Camera == false and #RC.GetState().Scenes == 2, "T1 deux scènes, caméra prise pour la sienne seulement")
advance(1)
ended("t2")
check(scene("t2") == nil and scene("t1") ~= nil and scriptable(), "T2 fin de l'autre : la sienne continue")
advanceUntil(function()
	return doneCalls("t1") > 0
end, 4)
check(doneCalls("t1") == 1 and doneCalls("t2") == 0, "T3 RevealDone pour la sienne seulement")
ended("t1")
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "t3")
advance(0.5)
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "t4")
check(scene("t3") == nil and scene("t4") ~= nil and scriptable(), "T4 nouvelle cinématique de l'ouvreur : l'ancienne finie")
advanceUntil(function()
	return doneCalls("t4") > 0
end, 4)
check(not scriptable() and CAMERA.CameraType == Enum.CameraType.Custom, "T5 caméra rendue en Custom (pas Scriptable)")
ended("t4")
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "t4")
check(#RC.GetState().Scenes == 1, "T6 même id renvoyé : une scène neuve, pas de doublon")
ended("t4")

section("X. MaxSeconds, HoldMax")
buildRig({
	OpenCommon = { 0.5, "Open=0.1,Reveal=0.2" },
	GrowSmall = { 20, "" },
})
reveal(alice, STORES[1], ITEM_A.Id, "Common", "", 10, 1, "Small", "x1")
advance(RevealCfg.MaxSeconds.Small - 0.2)
check(doneCalls("x1") == 0, "X1 avant MaxSeconds : rien de forcé")
advance(0.3)
check(doneCalls("x1") == 1 and fired("x1", "Land") and not scriptable(), "X2 MaxSeconds : Land forcé, RevealDone, caméra rendue")
advance(RevealCfg.HoldMax + 0.1)
check(scene("x1") == nil, "X3 sans RevealEnded : fin au bout de HoldMax")
dropRig()

section("B. Envois inutilisables")
local started = RC.GetState().Started
RC.Play({ ShopId = "x", ItemId = ITEM_A.Id })
check(RC.GetState().Started == started, "B1 sans RevealId : ignoré")
reveal(alice, { Name = "STORE_Inconnu" }, ITEM_A.Id, "Common", "", 10, 1, "Small", "b1")
check(scene("b1") ~= nil, "B2 magasin inconnu : scène devant l'ouvreur")
ended("b1")
skipped = RC.GetState().Skipped
RC.Play({ ShopId = "STORE_Inconnu", SlotName = "x/01", ItemId = ITEM_A.Id, RevealId = "b2" })
check(scene("b2") == nil and RC.GetState().Skipped == skipped + 1, "B3 magasin inconnu sans ouvreur : rien")
check(logCount("Controllers/Reveal") == 0, "B4 aucune erreur des modules Reveal")

section("J. Joueur qui n'a pas vu la scène")
STORES[3]:SetAttribute("CeilingBroken", true)
make("Part", { Name = "Ceiling", Anchored = true, Size = Vector3.new(30, 0.1, 28), CFrame = CFrame.new(240, 9.95, -45) }, STORES[3])
STORES[3]:SetAttribute("CeilingBroken", false)
STORES[3]:SetAttribute("CeilingBroken", true)
flush()
check(ceilingHidden(STORES[3]) and fxNamed("CeilingChunk") == 0, "J1 CeilingBroken sans scène : plafond caché, sans éclats")
STORES[3]:SetAttribute("CeilingBroken", false)
flush()
check(not ceilingHidden(STORES[3]), "J2 attribut faux : plafond revenu")

summary("scénario client")
