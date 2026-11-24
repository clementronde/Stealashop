--!nocheck
-- F. Poursuite complète (L-095) : sons au départ, sirène en boucle puis arrêtée, MUS_Chase à 1,5 s, bulle du
-- vigile (Bang, phrases toutes les 2,4 s, Guard_Radio une fois sur deux) puis détruite, barres cachées puis
-- remises.

buildFeelAssets()
local Feel = sharedModule("Config/ChaseFeel", "client")
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(zoneMiddle(1), 3, 0))
copyScreen(alice, STARTER_CHASE)
local rail, hotbar = buildScreens(alice, true, true)
startClient(alice)
local Controller = clientModule("ChaseFeelController")
local Music = clientModule("MusicController")
local guard, head = buildGuard(alice, zoneMiddle(1) + 20)

section("F. Au repos")
advance(2.5)
check(#sfx("Chase_Siren") == 0 and #sfx("Heist_Grab") == 0, "F1 aucun son de poursuite au repos")
check(bubbleOf(alice) == nil and rail.Visible and hotbar.Enabled, "F2 pas de bulle, barres affichées")


-- a71 (vague 24) : sons du départ espacés (sirène après SirenDelay, MUS_Chase après MusicDelay) ; Bubble, Tail et
-- Bang ouverts et fermés ensemble à chaque phrase.
section("F1. Départ de la poursuite")
local maxRotation = 0
ON_FRAME = function()
	local bb = bubbleOf(alice)
	local bang = bb and bb:FindFirstChild("Bang")
	if bang then
		maxRotation = math.max(maxRotation, math.abs(bang.Rotation or 0))
	end
end
serverFire("ChaseState", alice, true, guard)
advance(1 / 30)
local started = now()
check(Controller.GetState().Active, "F3 ambiance active dès l'image suivante")
check(#sfx("Heist_Grab") == 1 and sfx("Heist_Grab")[1].Playing, "F4 Heist_Grab joué une fois")
check(#sfx("Chase_Whistle") == 0, "F5 pas encore de sifflet")
check(#sfx("Chase_Siren") == 0, "F6 pas encore de sirène")
check(SIREN.Playing == false and SIREN.Looped == false, "F7 le Sound de Clément n'est pas touché")
check(rail.Visible == false and hotbar.Enabled == false, "F8 LeftRail et UI_Hotbar cachés")
local bb = bubbleOf(alice)
check(bb ~= nil and bb.Adornee == head, "F10 bulle BB_GuardShout sur la tête du vigile, dans le PlayerGui")
check(BB.Parent == UI_FOLDER and BB:FindFirstChild("Bubble"):FindFirstChildOfClass("UIScale") == nil, "F11 le modèle de Clément n'est pas touché")
check(not partShown(bb.Bubble) and not partShown(bb.Tail) and not partShown(bb.Bang), "F12 bulle fermée avant la première phrase (Bubble, Tail et Bang)")
advance(Feel.WhistleDelay)
check(#sfx("Chase_Whistle") == 1, `F9 Chase_Whistle {Feel.WhistleDelay} s après`)

section("F3. Phrases")
advance(started + Feel.FirstShoutDelay + 0.05 - now())
check(scaleValue(bb.Bubble) == 1 and partShown(bb.Tail) and partShown(bb.Bang), "F16 première phrase : Bubble, Tail et Bang ouverts")
local line1 = bb.Bubble.ShoutLabel.Text
check(table.find(Feel.Lines, line1) ~= nil, `F17 phrase de la liste ({line1})`)
check(#sfx("Guard_Radio") == 1, "F18 Guard_Radio avec la première phrase")
advance(started + 1.25 - now())
check(#sfx("Chase_Siren") == 0, "F6b plus de Chase_Siren (Clément, L-117 point 5)")
check(scaleValue(bb.Bang) == 1 and maxRotation >= 10, `F13 Bang a grossi puis est revenu à 1, et a tremblé ({maxRotation} degrés)`)
check(bb.Bang.Rotation == 0, "F14 Bang droit à la fin du tremblement")
advance(started + Feel.FirstShoutDelay + Feel.ShoutHold + Feel.ShoutOutTime + 0.1 - now())
check(not partShown(bb.Bubble) and not partShown(bb.Tail) and not partShown(bb.Bang), "F19 bulle entière refermée après 1,6 s")

section("F2. Musique")
local state = Music.GetState()
local chaseCopy = musicCopy("MUS_Chase")
check(state.Track == "MUS_Chase" and chaseCopy ~= nil and chaseCopy.TimePosition == Feel.MusicStartAt, `F15 MUS_Chase part de {Feel.MusicStartAt} s ({chaseCopy and chaseCopy.TimePosition})`)

section("F3'. Phrases suivantes")
advance(started + Feel.FirstShoutDelay + Feel.ShoutEvery + 0.05 - now())
check(scaleValue(bb.Bubble) == 1 and Controller.GetState().Shouts == 2, `F20 deuxième phrase 2,4 s après la première ({Controller.GetState().Shouts})`)
check(bb.Bubble.ShoutLabel.Text ~= line1, "F21 pas deux fois la même phrase d'affilée")
check(#sfx("Guard_Radio") == 1, "F22 pas de radio avec la deuxième phrase")
advance(Feel.ShoutEvery)
check(Controller.GetState().Shouts == 3 and #sfx("Guard_Radio") == 2, "F23 radio avec la troisième")
section("F4. Barre remise par un autre code pendant la poursuite")
rail.Visible = true
advance(Feel.BarsRefresh + 0.05)
check(rail.Visible == false, "F24 LeftRail recaché")

section("F5. Fin de la poursuite")
local radios = #sfx("Guard_Radio")
serverFire("ChaseState", alice, false)
advance(1 / 30)
check(not Controller.GetState().Active, "F25 ambiance arrêtée")
check(bubbleOf(alice) == nil and bb.Parent == nil, "F26 bulle détruite")
check(rail.Visible == true and hotbar.Enabled == true, "F28 barres revenues dans leur état d'origine")
advance(0.55)
check(#sfx("Chase_Siren") == 0, "F29 toujours aucune sirène")
advance(6)
check(#sfx("Guard_Radio") == radios, "F30 plus de phrase ni de radio après la fin")
check(rail.Visible and hotbar.Enabled, "F31 barres toujours là")

section("F6. Deuxième poursuite, vigile pas encore arrivé (streaming)")
local guards = guard.Parent
guard.Parent = nil
serverFire("ChaseState", alice, true, nil)
advance(1.3)
check(Controller.GetState().Active and bubbleOf(alice) == nil, "F32 pas de vigile : pas de bulle")
check(#sfx("Chase_Siren") == 0 and #sfx("Heist_Grab") == 2, "F33 sons de départ quand même (sans sirène)")
guard.Parent = guards
advance(0.3)
check(bubbleOf(alice) ~= nil and bubbleOf(alice).Adornee == head, "F34 vigile arrivé : bulle posée")
guard.Parent = nil
advance(0.2)
check(bubbleOf(alice) == nil, "F35 vigile reparti : bulle retirée")
guard.Parent = guards
advance(0.3)
check(bubbleOf(alice) ~= nil, "F36 il revient : la bulle aussi")
local count = 0
for _, child in alice.PlayerGui:GetChildren() do
	if child.Name == "BB_GuardShout" then
		count += 1
	end
end
check(count == 1, "F37 une seule bulle")
serverFire("ChaseState", alice, false)
advance(1)
check(bubbleOf(alice) == nil and #sfx("Chase_Siren") == 0 and rail.Visible and hotbar.Enabled, "F38 fin : tout est rangé")
check(not logHas("[ChaseFeel]", nil, "client"), "F39 aucune ligne en Studio (tout est livré)")

summary("scénario feel")
