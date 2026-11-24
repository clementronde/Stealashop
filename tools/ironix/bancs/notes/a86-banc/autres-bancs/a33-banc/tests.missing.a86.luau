--!nocheck
-- P. Pistes manquantes (MusicController ; a86) : pas de dossier Assets/Music ; ni MUS_Ambient ni MUS_Hub
-- (silence) ; sans MUS_Ambient, repli sur MUS_Hub partout (jamais de musique par zone) ; MUS_Ambient qui
-- n'est pas un Sound, puis qui ne se copie pas (toujours MUS_Hub) ; MUS_Ambient livrée en cours de
-- partie, dans un sous-dossier, à un autre volume : elle remplace MUS_Hub en fondu.

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-113, 3, 0))
startClient(alice)
local Controller = clientModule("MusicController")

local function state()
	return Controller.GetState()
end
local function go(x, z, wait)
	moveTo(alice, Vector3.new(x, 3, z or 0))
	advance(wait or 0.3)
end
local function level(name)
	return state().Levels[name] or 0
end

section("P. Pas de dossier Assets/Music")
local ok, err = pcall(advance, 3)
check(ok, `P1 aucune erreur sans musique ({err})`)
check(#musicCopies() == 0 and state().Track == nil, "P2 rien ne joue")
check(logCount("ReplicatedStorage.Assets.Music absent : pas de musique (L-056)", "PRINT", "client") == 1, "P3 une seule ligne en Studio")

section("P'. Ni MUS_Ambient ni MUS_Hub : silence")
buildMusic()
MUSIC.MUS_Ambient:Destroy()
MUSIC.MUS_Hub:Destroy()
go(zoneMiddle(2), 0, 0.5)
check(state().Track == nil and #musicCopies() == 0, `P4 zone 2 : rien ne joue, pas même MUS_Z2 ({state().Track})`)
check(logCount("MUS_Hub absent de ReplicatedStorage.Assets.Music (ou pas un Sound) : pas de musique de fond", "PRINT", "client") == 1, "P5 une ligne en Studio pour MUS_Hub")

section("P''. Sans MUS_Ambient : repli sur MUS_Hub partout")
MUSIC.MUS_Hub = make("Sound", { Name = "MUS_Hub", SoundId = MUSIC_IDS.MUS_Hub, Looped = true, Volume = 0.4 }, MUSIC_FOLDER)
go(-113, 0, 0.3)
check(state().Track == "MUS_Hub", `P6 zone safe : MUS_Hub ({state().Track})`)
check(logCount("MUS_Ambient absent de ReplicatedStorage.Assets.Music (ou pas un Sound) : repli sur MUS_Hub partout", "PRINT", "client") == 1, "P7 une ligne en Studio pour MUS_Ambient")
advance(2.2)
local hub = musicCopy("MUS_Hub")
hub.TimePosition = 12
for zone = 1, 6 do
	go(zoneMiddle(zone), 0, 0.3)
	check(state().Track == "MUS_Hub" and level("MUS_Hub") == 1, `P8.{zone} zone {zone} : toujours MUS_Hub ({state().Track})`)
end
check(#musicCopies() == 1 and hub.TimePosition == 12, "P9 jamais de musique par zone, MUS_Hub jamais relancée")
check(logCount("MUS_Ambient absent", "PRINT", "client") == 1, "P10 toujours une seule ligne")

section("P'''. MUS_Ambient qui n'est pas un Sound, puis qui ne se copie pas")
local notSound = make("Folder", { Name = "MUS_Ambient" }, MUSIC_FOLDER)
advance(0.5)
check(state().Track == "MUS_Hub", "P11 MUS_Ambient qui est un Folder : MUS_Hub continue")
notSound:Destroy()
local locked = make("Sound", { Name = "MUS_Ambient", Volume = 0.4, Archivable = false }, MUSIC_FOLDER)
advance(0.5)
check(state().Track == "MUS_Hub" and logHas("MUS_Ambient ne se copie pas (Archivable = false)", "WARN", "client"), "P12 Sound qui ne se copie pas : MUS_Hub continue, un avertissement")
check(locked.Parent == MUSIC_FOLDER and locked.Archivable == false, "P13 il n'est pas touché")
locked:Destroy()

section("P''''. MUS_Ambient livrée en cours de partie, dans un sous-dossier, à 0,8")
local sub = folder(MUSIC_FOLDER, "Ambient")
local late = make("Sound", { Name = "MUS_Ambient", SoundId = MUSIC_IDS.MUS_Ambient, Looped = true, Volume = 0.8 }, sub)
advance(0.3)
check(state().Track == "MUS_Ambient", "P14 trouvée dans le sous-dossier et visée, sans relancer le jeu")
advance(2.2)
check(level("MUS_Ambient") == 1 and level("MUS_Hub") == 0 and hub.Playing == false, "P15 fondu enchaîné fini : MUS_Hub éteinte")
check(near(musicCopy("MUS_Ambient").Volume, 0.8, 1e-9), "P16 jouée au volume de Clément (0,8)")
check(late.Volume == 0.8 and late.Playing == false and late.Parent == sub, "P17 son Sound n'est pas touché")
local ok2, err2 = pcall(advance, 2)
check(ok2, `P18 aucune erreur ({err2})`)

summary("scénario pistes manquantes")
