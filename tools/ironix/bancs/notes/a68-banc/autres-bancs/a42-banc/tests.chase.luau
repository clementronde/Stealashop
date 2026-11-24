--!nocheck
-- C. Poursuite (L-071, point 6) : UI_Chase allumé pendant la poursuite et éteint sinon (ChaseController,
-- Motion), musique MUS_Chase prioritaire sur celle de la zone avec le même fondu, retour à la zone,
-- reprise de la musique de zone où elle en était, MUS_Chase qui repart du début, priorité sur le camion.

local Music = sharedModule("Config/Music", "client")
local Motion = requireModule(CONTROLLERS.UI.Motion, "client")

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(zoneMiddle(1), 3, 0))
local screen = copyScreen(alice, STARTER_CHASE) -- arrivée allumée de StarterGui (Enabled = true)
startClient(alice)
local Chase = clientModule("ChaseController")
local Controller = clientModule("MusicController")

local function state()
	return Controller.GetState()
end
local function level(name)
	return state().Levels[name] or 0
end

-- Vérifications à chaque image : jamais deux pistes à fond, jamais plus qu'une piste pleine.
local maxFull, maxSum = 0, 0
ON_FRAME = function()
	local full, sum = 0, 0
	for name, part in state().Levels do
		local copy = musicCopy(name)
		if copy and copy.Playing then
			sum += part
			if part >= 0.999 then
				full += 1
			end
		end
	end
	maxFull = math.max(maxFull, full)
	maxSum = math.max(maxSum, sum)
end

-- Vigile qui poursuit Alice (GuardService : Workspace/ActiveGuards, attribut TargetUserId).
local guards = folder(Workspace, "ActiveGuards")
local guard = make("Model", { Name = "Guard_Z1" }, guards)
local guardRoot = make("Part", { Name = "HumanoidRootPart", Anchored = true, CFrame = CFrame.new(zoneMiddle(1) + 20, 3, 0) }, guard)
guard.PrimaryPart = guardRoot
guard:SetAttribute("TargetUserId", alice.UserId)

section("C. Au repos")
advance(0.3)
check(screen.Enabled == false, "C1 UI_Chase arrivé allumé de StarterGui : éteint au repos")
check(STARTER_CHASE.Enabled == true, "C2 l'écran de Clément dans StarterGui n'est pas touché")
advance(2.5)
check(state().Track == "MUS_Z1" and state().Event == nil and level("MUS_Z1") == 1, `C3 zone 1 : MUS_Z1 pleine ({state().Track})`)
local z1 = musicCopy("MUS_Z1")
z1.TimePosition = 21

section("C'. La poursuite commence")
maxFull, maxSum = 0, 0
serverFire("ChaseState", alice, true, guard)
check(Chase.IsChased(), "C4 ChaseController : poursuivi")
advance(1 / 30)
check(screen.Enabled == true, "C5 UI_Chase allumé dès l'image suivante")
check(Motion.GetState(screen) == "Open" or Motion.GetState(screen) == "Opening", `C6 par Motion.Open ({Motion.GetState(screen)})`)
advance(0.3)
check(state().Track == "MUS_Chase" and state().Event == "Chase", `C7 MUS_Chase visée, avant la zone ({state().Track}, {state().Event})`)
local chaseCopy, chaseCount = musicCopy("MUS_Chase")
check(chaseCopy ~= nil and chaseCount == 1 and chaseCopy.Looped and chaseCopy.Playing, "C8 une copie de MUS_Chase, en boucle, qui joue")
check(chaseCopy and chaseCopy.Volume < 0.2, `C9 elle monte en fondu (volume {chaseCopy and chaseCopy.Volume})`)
advance(0.7)
check(level("MUS_Chase") > 0.3 and level("MUS_Chase") < 0.8 and level("MUS_Z1") > 0.2 and level("MUS_Z1") < 0.7, `C10 fondu enchaîné à mi-chemin ({level("MUS_Z1")} → {level("MUS_Chase")})`)
advance(1.5)
check(level("MUS_Chase") == 1 and level("MUS_Z1") == 0, "C11 après FadeTime : MUS_Chase pleine, MUS_Z1 à 0")
check(near(chaseCopy.Volume, 0.5, 1e-9), `C12 au volume de Clément (0,5 : {chaseCopy.Volume})`)
check(z1.Playing == false and z1.TimePosition == 21, "C13 MUS_Z1 en pause, à 21 s")
check(maxFull <= 1 and maxSum <= 1 + 1e-6, `C14 jamais deux pistes à fond (au plus {maxFull}, somme {maxSum})`)
check(MUSIC.MUS_Chase.Playing == false and MUSIC.MUS_Chase.Volume == 0.5 and MUSIC.MUS_Chase.Parent == MUSIC_FOLDER, "C15 le Sound de Clément n'est pas touché")

section("C''. Écran recréé pendant la poursuite (ResetOnSpawn)")
local respawned = copyScreen(alice, STARTER_CHASE)
advance(0.3)
check(respawned.Enabled == true, "C16 nouvelle copie allumée pendant la poursuite")
check(respawned.RedEdge.Size == STARTER_CHASE.RedEdge.Size and respawned.Warning.WarningLabel.Text == "THE GUARD IS CHASING YOU!", "C17 seul Enabled est touché : tailles et textes de Clément gardés")
screen = respawned

section("C'''. Fin de la poursuite")
chaseCopy.TimePosition = 9
serverFire("ChaseState", alice, false)
check(not Chase.IsChased(), "C18 ChaseController : plus poursuivi")
advance(1 / 30)
check(screen.Enabled == false, "C19 UI_Chase éteint (Motion.Close)")
advance(0.3)
check(state().Track == "MUS_Z1" and state().Event == nil, `C20 retour à la musique de la zone ({state().Track})`)
advance(2.2)
check(level("MUS_Z1") == 1 and level("MUS_Chase") == 0, "C21 MUS_Z1 pleine, MUS_Chase à 0")
check(z1.Playing and z1.TimePosition == 21, "C22 MUS_Z1 reprend où elle en était (21 s)")
check(chaseCopy.Playing == false, "C23 MUS_Chase en pause")

section("C''''. Deuxième poursuite : MUS_Chase repart du début")
serverFire("ChaseState", alice, true, guard)
advance(0.3)
-- a68 (L-095) : MUS_Chase part de Config/ChaseFeel.MusicStartAt (1,5 s) si le module est là, sinon de 0 s.
local chaseStartAt = if SOURCES["shared/Config/ChaseFeel.luau"] then sharedModule("Config/ChaseFeel", "client").MusicStartAt else 0
check(state().Track == "MUS_Chase" and chaseCopy.TimePosition == chaseStartAt and chaseCopy.Playing, `C24 MUS_Chase repart de {chaseStartAt} s ({chaseCopy.TimePosition})`)
advance(1)
chaseCopy.TimePosition = 4
serverFire("ChaseState", alice, false)
advance(0.6) -- MUS_Chase encore audible (fondu de sortie en cours)
serverFire("ChaseState", alice, true, guard)
advance(0.3)
check(state().Track == "MUS_Chase" and chaseCopy.TimePosition == 4, `C25 reprise pendant le fondu de sortie : pas de saut ({chaseCopy.TimePosition})`)

section("C'''''. Poursuite près du camion : MUS_Chase passe avant MUS_Truck")
local truck = make("Model", { Name = "EventTruck" })
local truckRoot = make("Part", { Name = "Root", Anchored = true, Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(zoneMiddle(1) + 30, 0.5, 0) }, truck)
truck.PrimaryPart = truckRoot
truck.Parent = Workspace
addTag(truck, "EventTruck")
advance(2.5)
check(state().Track == "MUS_Chase" and state().Event == "Chase", `C26 poursuivi à 30 studs du camion : MUS_Chase ({state().Track})`)
serverFire("ChaseState", alice, false)
advance(0.3)
check(state().Track == "MUS_Truck" and state().Event == "Truck", `C27 fin de la poursuite, toujours près du camion : MUS_Truck ({state().Track})`)
advance(2.2)
check(level("MUS_Truck") == 1 and screen.Enabled == false, "C28 MUS_Truck pleine, UI_Chase éteint")
truck:Destroy()
advance(0.3)
check(state().Track == "MUS_Z1", `C29 camion parti : MUS_Z1 ({state().Track})`)
check(not logHas("[Poursuite] UI_Chase", "PRINT", "client"), "C30 écran présent : pas de ligne « pas encore livré »")

section("C''''''. Écran retiré pendant la poursuite")
serverFire("ChaseState", alice, true, guard)
advance(0.3)
screen:Destroy()
advance(0.5)
serverFire("ChaseState", alice, false)
serverFire("ChaseState", alice, true, guard)
advance(0.5)
check(FAILS == 0 or not logHas("ERREUR", nil, nil), "C31 écran retiré pendant la poursuite : aucune erreur")
check(logCount("[Poursuite] UI_Chase pas encore livré", "PRINT", "client") == 1, "C32 écran absent : une ligne en Studio, une seule fois")
serverFire("ChaseState", alice, false)
advance(0.5)
check(maxFull <= 1 and maxSum <= 1 + 1e-6, "C33 sur tout le scénario, jamais deux pistes à fond")
check(not logHas("[MusicController]", "WARN", "client") and not logHas("[Poursuite]", "WARN", "client"), "C34 aucun avertissement")

summary("scénario poursuite")
