-- f70c4 (Cantin, 18/11 : « retour au jeu fluide car fin anim trop brusque ») : après l'en-tête du scénario client
-- d'a251 (Alice, Bob, HUD, UI_Unbox, caméra HOME, RevealController démarré).
--   F retour à Land : glissement depuis le dernier plan, pas de coupure, HUD, colis caché jusqu'au bout, RevealEnded
--     pendant le retour, champ de vision et bords en fondu, caméra derrière le perso, fin en fondu de la masse ;
--   G mur derrière le perso : la caméra reste devant pendant le retour ;
--   H nouvelle scène pendant le retour : coupé, caméra reprise ;
--   D mort pendant le retour : coupé d'un coup.
local Reveal = sharedModule("Config/Reveal", "client")
local R = Reveal.Return
check(R.Time > 0, "F0 Config/Reveal.Return.Time > 0 (" .. tostring(R.Time) .. ")")

-- Arrêts des pistes d'animation : nom, fondu, position.
STOPS = {}
local loadBefore = Methods.LoadAnimation
function Methods.LoadAnimation(self, animation)
	local track = loadBefore(self, animation)
	local stop = track.Stop
	function track.Stop(t, fade)
		table.insert(STOPS, { name = t.Name, fade = fade, pos = t.TimePosition, length = t.Length })
		stop(t, fade)
	end
	return track
end

-- Fausse caméra du jeu (priorité Camera, comme ClassicCamera) : garde la direction de la caméra, à 12 studs de la tête.
local FAKE_DISTANCE = 12
local function head()
	local h = alice.Character:FindFirstChild("Head")
	return if h then h.Position else alice.Character.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0)
end
-- 2e passe (Play de fusion71) : Camera.Focus encore celui d'avant la scène, loin, à la première image.
CAMERA.Focus = CFrame.new(200, -30, 200)
BENCH_BIND("FakeCameraModule", 200, function()
	if CAMERA.CameraType ~= Enum.CameraType.Custom or alice.Character == nil then
		return
	end
	local focus = head()
	local look = CAMERA.CFrame.LookVector
	if not FAKE_STALE_FOCUS then
		CAMERA.Focus = CFrame.new(focus)
	end
	CAMERA.CFrame = CFrame.lookAt(focus - look * FAKE_DISTANCE, focus)
end)
local function returning()
	return RC.GetState().Returning
end
local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-6 then f.Unit else f
end
local SIMPLE = "Saw:Common,Kick:Common,Saw:Common,Kick:Common,Hammer:Common|3"
local function toLand(id)
	advanceUntil(function()
		return doneCalls(id) > 0
	end, 20)
	return doneCalls(id) > 0
end

section("F. Retour au jeu en douceur")
buildAnim("Unbox_Hammer", 1.0, "Impact=0.3")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "f1", SIMPLE)
check(scene("f1") ~= nil and CAMERA.CameraType == Enum.CameraType.Scriptable, "F1 scène lancée, caméra prise")
local landed = toLand("f1")
check(landed and returning() ~= nil, "F2 Land : le retour commence")
local hammer = nil
for _, s in STOPS do
	if s.name == "Unbox_Hammer" then
		hammer = s
	end
end
check(hammer ~= nil and (hammer.fade or 0) > 0.1 and hammer.pos < hammer.length, string.format("F3 la masse finit en fondu avant sa dernière image (fondu %s, à %s / %s s)", tostring(hammer and hammer.fade), tostring(hammer and hammer.pos), tostring(hammer and hammer.length)))
local lastShot = CAMERA.CFrame
local fovAtLand = CAMERA.FieldOfView
local edgeAtLand = edge.ImageTransparency
-- Un rayon entre la tête et le dernier plan (Play de fusion71 : le rayon touchait Shelf_A_L_C10), Focus périmé.
FAKE_STALE_FOCUS = true
CAMERA.Focus = CFrame.new(200, -30, 200)
local shelfBit = make("Part", { Name = "ShelfBit", Anchored = true, CanCollide = true, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(head():Lerp(lastShot.Position, 0.3)) }, Workspace)
advance(1 / 30)
FAKE_STALE_FOCUS = false
check(CAMERA.CameraType == Enum.CameraType.Custom, "F4 caméra du jeu rendue dès la première image")
check(hotbar.Enabled == true, "F5 HUD revenu")
check((CAMERA.CFrame.Position - lastShot.Position).Magnitude < 0.5, string.format("F6 première image au dernier plan : pas de coupure (%.2f studs)", (CAMERA.CFrame.Position - lastShot.Position).Magnitude))
check(BOX1.LocalTransparencyModifier == 1, "F7 colis du rayon encore caché pendant le retour")
shelfBit:Destroy()
ended("f1")
check(scene("f1") == nil and returning() ~= nil, "F8 RevealEnded pendant le retour : scène finie, le retour continue")
check(BOX1.LocalTransparencyModifier == 1, "F9 … colis toujours caché")
local maxStep, prev, fovOk, prevFov = 0, CAMERA.CFrame.Position, true, CAMERA.FieldOfView
local frames = 0
local fovAtFovTime = nil
while returning() ~= nil and frames < 200 do
	advance(1 / 30)
	frames += 1
	if fovAtFovTime == nil and (frames + 1) / 30 >= R.FovTime + 0.02 then
		fovAtFovTime = CAMERA.FieldOfView
	end
	maxStep = math.max(maxStep, (CAMERA.CFrame.Position - prev).Magnitude)
	prev = CAMERA.CFrame.Position
	if fovAtLand < 70 and (CAMERA.FieldOfView < prevFov - 1e-6 or CAMERA.FieldOfView > 70 + 1e-6) then
		fovOk = false
	end
	prevFov = CAMERA.FieldOfView
end
local took = (frames + 1) / 30
check(math.abs(took - R.Time) <= 0.1, string.format("F10 retour fini en %.2f s (Return.Time %.2f)", took, R.Time))
check(maxStep < 2, string.format("F11 aucun saut d'une image à l'autre (au plus %.2f studs)", maxStep))
check(fovOk, string.format("F12 champ de vision remonté en fondu (de %.1f)", fovAtLand))
check(fovAtFovTime == 70, string.format("F12b … revenu à 70 en FovTime (%s)", tostring(fovAtFovTime)))
check(CAMERA.FieldOfView == 70 and edge.ImageTransparency == 1 and unboxScreen.Enabled == false, string.format("F13 fin : FieldOfView 70, bords transparents (%.2f à Land), UI_Unbox éteint", edgeAtLand))
check(BOX1.LocalTransparencyModifier == 0, "F14 colis du rayon remis à la fin du retour")
local root = alice.Character.HumanoidRootPart
check(flat(CAMERA.CFrame.LookVector):Dot(flat(root.CFrame.LookVector)) > 0.95, "F15 caméra derrière le perso, tournée comme lui")
local pitch = math.asin(CAMERA.CFrame.LookVector.Y)
check(pitch >= R.PitchMin - 1e-3 and pitch <= R.PitchMax + 1e-3, string.format("F16 inclinaison bornée (%.2f rad)", pitch))
local still = CAMERA.CFrame
advance(1 / 30)
check(#RENDER_BOUND == 1, "F17 plus rien de lié au rendu (seule la fausse caméra)")
check((CAMERA.CFrame.Position - still.Position).Magnitude < 0.01 and CAMERA.CFrame.LookVector:Dot(still.LookVector) > 0.9999, "F18 la caméra du jeu ne bouge plus d'elle-même")

section("G. Mur derrière le perso")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "g1", SIMPLE)
toLand("g1")
local focus = head()
local back = -flat(alice.Character.HumanoidRootPart.CFrame.LookVector)
local WALL = 5
local shotSide = (CAMERA.CFrame.Position - focus):Dot(back)
local wall = make("Part", { Name = "BackWall", Anchored = true, CanCollide = true, Size = Vector3.new(60, 60, 0.4), CFrame = CFrame.lookAt(focus + back * WALL, focus + back * (WALL + 1)) }, Workspace)
check(shotSide < WALL - R.Margin, string.format("G0 dernier plan devant le mur (%.1f studs)", shotSide))
local worst = -math.huge
local gFrames = 0
while returning() ~= nil and gFrames < 100 do
	advance(1 / 30)
	gFrames += 1
	if returning() ~= nil then
		worst = math.max(worst, (CAMERA.CFrame.Position - focus):Dot(back))
	end
end
check(worst < WALL - 0.2, string.format("G1 pendant le retour, la caméra reste devant la face du mur (au plus %.2f studs, face à %.1f ; Margin compté le long du rayon)", worst, WALL - 0.2))
check(returning() == nil and (gFrames + 1) / 30 <= R.Time + R.Settle + 0.1, string.format("G2 mur resté entre la tête et la caméra du jeu : retour fini au plus Settle s après Time (%.2f s)", (gFrames + 1) / 30))
ended("g1")
wall:Destroy()

section("N. PNJ et obstacle qui passent pendant le retour")
-- Play de fusion71 : à +0,65 s la caméra s'est collée à la tête 0,14 s puis est repartie d'un coup.
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "n1", SIMPLE)
toLand("n1")
local function distance()
	return (CAMERA.CFrame.Position - head()).Magnitude
end
local guard = make("Model", { Name = "Guard" }, Workspace)
make("Humanoid", { Name = "Humanoid" }, guard)
local torso = make("Part", { Name = "UpperTorso", Anchored = true, CanCollide = true, Size = Vector3.new(2, 2, 1) }, guard)
local nFrames, nWorstIn, nWorstOut, last = 0, 0, 0, nil
local post = nil
while returning() ~= nil and nFrames < 100 do
	nFrames += 1
	local t = nFrames / 30
	if t >= 0.4 and t < 0.55 then -- le vigile passe entre la tête et la caméra
		torso.CFrame = CFrame.new(head():Lerp(CAMERA.CFrame.Position, 0.5))
	else
		torso.CFrame = CFrame.new(0, -500, 0)
	end
	if t >= 0.6 and t < 0.7 and post == nil then -- un poteau (pas un PNJ) apparaît puis disparaît
		post = make("Part", { Name = "Post", Anchored = true, CanCollide = true, Size = Vector3.new(1.5, 20, 1.5), CFrame = CFrame.new(head():Lerp(CAMERA.CFrame.Position, 0.5)) }, Workspace)
	elseif t >= 0.7 and post and post.Parent then
		post:Destroy()
	end
	advance(1 / 30)
	local d = distance()
	if last and t < 0.6 then
		nWorstIn = math.max(nWorstIn, last - d)
	end
	if last and t >= 0.7 then
		nWorstOut = math.max(nWorstOut, d - last)
	end
	last = d
end
guard:Destroy()
check(nWorstIn < 1.5, string.format("N1 le vigile entre la tête et la caméra est ignoré : pas de bond vers la tête (au plus %.2f studs)", nWorstIn))
check(nWorstOut <= R.OutSpeed / 30 + 1, string.format("N2 obstacle disparu : la caméra s'éloigne sans bond (au plus %.2f studs par image)", nWorstOut))
check(returning() == nil and (nFrames + 1) / 30 <= R.Time + R.Settle + 0.1, string.format("N3 retour fini (%.2f s)", (nFrames + 1) / 30))
ended("n1")

section("V. Un autre code reprend le champ de vision (poursuite)")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "v1", SIMPLE)
toLand("v1")
local f0 = CAMERA.FieldOfView
local writer = 0
local conn = HEARTBEAT:Connect(function(dt)
	writer += dt
	if writer >= 0.05 and writer <= 0.4 then -- comme le TweenService de UiFeelController (poursuite : base + 6)
		CAMERA.FieldOfView = f0 + 6 * math.min((writer - 0.05) / 0.3, 1)
	end
end)
local vJump = 0
local vPrev = CAMERA.FieldOfView
for _ = 1, math.ceil((R.Time + 0.2) * 30) do
	advance(1 / 30)
	vJump = math.max(vJump, math.abs(CAMERA.FieldOfView - vPrev))
	vPrev = CAMERA.FieldOfView
end
conn:Disconnect()
check(math.abs(CAMERA.FieldOfView - (f0 + 6)) < 1e-6, string.format("V1 le champ de vision de la poursuite est gardé (%.1f)", CAMERA.FieldOfView))
check(vJump <= 1.5, string.format("V2 aucun à-coup du champ de vision (au plus %.2f° par image)", vJump))
check(returning() == nil and edge.ImageTransparency == 1, "V3 retour fini, bords remis")
CAMERA.FieldOfView = 70
ended("v1")

section("H. Nouvelle scène pendant le retour")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "h1", SIMPLE)
toLand("h1")
advance(0.2)
check(returning() ~= nil, "H0 retour en cours")
ended("h1")
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "h2", SIMPLE)
check(returning() == nil and scene("h2") ~= nil and CAMERA.CameraType == Enum.CameraType.Scriptable, "H1 nouvelle scène : retour coupé, caméra reprise")
advance(0.2)
check(CAMERA.CameraType == Enum.CameraType.Scriptable and #RENDER_BOUND == 1, "H2 … et gardée (rien du retour ne tourne)")
ended("h2")
check(CAMERA.CameraType == Enum.CameraType.Custom and CAMERA.FieldOfView == 70 and returning() == nil, "H3 RevealEnded avant Land : caméra rendue d'un coup")

section("D. Mort pendant le retour")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(alice, STORES[1], ITEM_A.Id, "Common", 4.5, 1, "Small", "d1", SIMPLE)
toLand("d1")
advance(0.2)
check(returning() ~= nil and BOX1.LocalTransparencyModifier == 1, "D0 retour en cours")
alice.Character.Humanoid.Died:Fire()
flush()
check(returning() == nil and CAMERA.CameraType == Enum.CameraType.Custom and CAMERA.FieldOfView == 70 and edge.ImageTransparency == 1, "D1 mort : retour coupé, caméra, champ de vision et bords remis d'un coup")
check(BOX1.LocalTransparencyModifier == 0 and #RENDER_BOUND == 1, "D2 … colis remis, plus rien de lié au rendu")
ended("d1")

summary("scénario retour")
