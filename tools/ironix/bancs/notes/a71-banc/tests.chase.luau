--!nocheck
-- a71 (vague 24, Play de Cantin du 2026-11-11) : sons du départ espacés, bulle entière, LeftRailTouch.
buildFeelAssets()
local Feel = sharedModule("Config/ChaseFeel", "client")
local MusicCfg = sharedModule("Config/Music", "client")
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(zoneMiddle(1), 3, 0))
copyScreen(alice, STARTER_CHASE)
local rail, hotbar, touch = buildScreens(alice, true, true, true)
startClient(alice)
local Controller = clientModule("ChaseFeelController")
local Music = clientModule("MusicController")
local guard = buildGuard(alice, zoneMiddle(1) + 20)
advance(2.5)
check(touch.Visible and rail.Visible, "A0 colonnes affichées au repos")

section("A1. Sons du départ espacés")
local first = {}
local mismatch, shownFrames, hiddenFrames = 0, 0, 0
local started
ON_FRAME = function()
	if started == nil then
		return
	end
	local t = now() - started
	for _, name in { "Heist_Grab", "Chase_Whistle", "Chase_Siren" } do
		if first[name] == nil and #sfx(name) > 0 then
			first[name] = t
		end
	end
	if first.Music == nil and Music.GetState().Track == "MUS_Chase" then
		first.Music = t
	end
	local bb = bubbleOf(alice)
	if bb then
		local a, b, c = partShown(bb.Bubble), partShown(bb.Tail), partShown(bb.Bang)
		if a ~= b or a ~= c then
			mismatch += 1
		elseif a then
			shownFrames += 1
		else
			hiddenFrames += 1
		end
	end
end
serverFire("ChaseState", alice, true, guard)
started = now()
advance(1 / 30)
check(touch.Visible == false and rail.Visible == false and hotbar.Enabled == false, "A1 LeftRail, LeftRailTouch et UI_Hotbar cachés")
advance(Feel.MusicDelay + MusicCfg.CheckInterval + 0.2)
local frame = 2 / 30 + 1e-6 -- départ vu à l'image suivante, son vu à l'image d'après
check(first.Heist_Grab ~= nil and first.Heist_Grab <= frame, `A2 Heist_Grab au départ ({first.Heist_Grab})`)
check(first.Chase_Whistle ~= nil and first.Chase_Whistle >= Feel.WhistleDelay - 1e-6 and first.Chase_Whistle <= Feel.WhistleDelay + frame, `A3 Chase_Whistle à {Feel.WhistleDelay} s ({first.Chase_Whistle})`)
check(first.Chase_Siren ~= nil and first.Chase_Siren >= Feel.SirenDelay - 1e-6 and first.Chase_Siren <= Feel.SirenDelay + frame, `A4 Chase_Siren à {Feel.SirenDelay} s ({first.Chase_Siren})`)
check(first.Music ~= nil and first.Music >= Feel.MusicDelay - 1e-6 and first.Music <= Feel.MusicDelay + MusicCfg.CheckInterval + frame, `A5 MUS_Chase visée à {Feel.MusicDelay} s ({first.Music})`)
check(Feel.WhistleDelay >= 0.3 and Feel.SirenDelay - Feel.WhistleDelay >= 0.3 and Feel.MusicDelay - Feel.SirenDelay >= 0.3, "A6 au moins 0,3 s entre deux sons")

section("A2. Bulle entière")
advance(Feel.ShoutEvery * 2)
check(shownFrames > 10 and hiddenFrames > 10, `A7 bulle ouverte puis fermée plusieurs fois ({shownFrames} / {hiddenFrames} images)`)
check(mismatch == 0, `A8 Bubble, Tail et Bang toujours ensemble (images en désaccord : {mismatch})`)
local bb = bubbleOf(alice)
check(Controller.GetState().Shouts >= 2, "A9 plusieurs phrases")

section("A3. Fin")
serverFire("ChaseState", alice, false)
advance(0.5)
check(touch.Visible and rail.Visible and hotbar.Enabled, "A10 LeftRailTouch, LeftRail et UI_Hotbar remis")
ON_FRAME = nil

section("A4. Poursuite courte : ni sirène ni musique de poursuite")
advance(3)
local sirens = #sfx("Chase_Siren")
local whistles = #sfx("Chase_Whistle")
serverFire("ChaseState", alice, true, guard)
advance(0.3)
serverFire("ChaseState", alice, false)
local sawMusic = false
ON_FRAME = function()
	if Music.GetState().Track == "MUS_Chase" then
		sawMusic = true
	end
end
advance(Feel.MusicDelay + 0.5)
ON_FRAME = nil
check(#sfx("Chase_Siren") == 0, `A11 pas de sirène après la fin (avant : {sirens})`)
check(#sfx("Chase_Whistle") <= whistles, "A12 pas de sifflet après la fin")
check(not sawMusic, "A13 MUS_Chase pas visée")

section("A5. LeftRailTouch déjà caché")
touch.Visible = false
serverFire("ChaseState", alice, true, guard)
advance(0.5)
check(touch.Visible == false, "A14 caché pendant")
serverFire("ChaseState", alice, false)
advance(0.5)
check(touch.Visible == false and rail.Visible, "A15 resté caché après (état d'origine), LeftRail remis")
check(not logHas("[ChaseFeel]", nil, "client"), "A16 aucune ligne ni erreur")
summary("scénario a71 chase")
