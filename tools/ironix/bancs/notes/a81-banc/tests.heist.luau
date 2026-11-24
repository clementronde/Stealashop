--!nocheck
-- a81 (vague 26) : MUS_Heist tant qu'un chrono de braquage est affiché (HeistTimer), avant la zone, après la
-- poursuite ; Heist_Breath en boucle avec elle (volume = son volume × la part de MUS_Heist), coupée ensuite.
local Music = sharedModule("Config/Music", "client")
addMusic("MUS_Heist", 0.4)
local breathTemplate = make("Sound", { Name = "Heist_Breath", Volume = 1, SoundId = "rbxassetid://9" }, folder(SOUNDS_FOLDER, "Heist"))
local alice = newPlayer("Alice")
local X = zoneMiddle(2)
spawnCharacter(alice, Vector3.new(X, 3, 0))
startClient(alice)
local Controller = clientModule("MusicController")
local function state() return Controller.GetState() end
local function level(name) return state().Levels[name] or 0 end
advance(Music.FadeTime + 0.5)
check(state().Track == "MUS_Z2" and state().Event == nil, `H1 au repos : MUS_Z2 ({state().Track})`)
check(Music.HeistTrack == "MUS_Heist" and Music.HeistBreath == "Heist_Breath", "H2 noms de Clément")

section("H. Chrono du braquage")
serverFire("HeistTimer", alice, "Store_Z2_1", Workspace:GetServerTimeNow() + 10)
advance(Music.CheckInterval + 0.05)
check(state().Track == "MUS_Heist" and state().Event == "Heist", `H3 MUS_Heist visée ({state().Track}, {state().Event})`)
advance(Music.FadeTime + 0.2)
check(level("MUS_Heist") == 1 and level("MUS_Z2") == 0, "H4 fondu : MUS_Heist pleine, la zone se tait")
local breath, count = musicCopy("Heist_Breath")
check(count == 1 and breath.Playing and breath.Looped, "H5 une respiration en boucle qui joue")
check(breath and math.abs(breath.Volume - breathTemplate.Volume) < 1e-6, `H6 respiration au volume de Clément ({breath and breath.Volume})`)
check(breathTemplate.Looped == false and breathTemplate.Volume == 1, "H7 le Sound de Clément n'est pas touché")

section("H'. Poursuite par-dessus")
local guards = folder(Workspace, "ActiveGuards")
local guard = make("Model", { Name = "Guard_Z2" }, guards)
local gr = make("Part", { Name = "HumanoidRootPart", Anchored = true, CFrame = CFrame.new(X + 20, 3, 0) }, guard)
guard.PrimaryPart = gr
serverFire("ChaseState", alice, true, guard)
local delay = if SOURCES["shared/Config/ChaseFeel.luau"] then sharedModule("Config/ChaseFeel", "client").MusicDelay or 0 else 0
advance(delay + Music.CheckInterval + 0.1)
check(state().Track == "MUS_Chase", `H8 la poursuite passe avant le braquage ({state().Track})`)
serverFire("ChaseState", alice, false)
advance(Music.CheckInterval + 0.05)
check(state().Track == "MUS_Heist", `H9 fin de poursuite, chrono encore là : MUS_Heist ({state().Track})`)

section("H''. Fin du chrono")
serverFire("HeistTimer", alice, "Store_Z2_1", 0)
advance(Music.CheckInterval + 0.05)
check(state().Track == "MUS_Z2", `H10 chrono masqué : retour à MUS_Z2 ({state().Track})`)
advance(Music.FadeTime * 0.5)
breath = musicCopy("Heist_Breath")
check(breath and breath.Volume > 0 and breath.Volume < breathTemplate.Volume, `H11 la respiration descend avec le fondu ({breath and breath.Volume})`)
advance(Music.FadeTime)
breath = musicCopy("Heist_Breath")
check(breath and not breath.Playing and level("MUS_Heist") == 0, "H12 silence : respiration arrêtée")

section("H'''. Chrono déjà fini (endsAt passé)")
serverFire("HeistTimer", alice, "Store_Z2_2", Workspace:GetServerTimeNow() - 1)
advance(Music.CheckInterval + 0.05)
check(state().Track == "MUS_Z2", "H13 chrono passé : pas de tension")
check(not logHas("[MusicController]", "WARN", "client"), "H14 aucune ligne d'erreur")
summary("scénario a81 heist")
