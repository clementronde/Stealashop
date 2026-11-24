--!nocheck
-- P. Morceaux manquants (MusicController ; a87) : pas de dossier Assets/Music ; ni playlist ni MUS_Hub
-- (silence) ; aucun morceau de la playlist : repli sur MUS_Hub en boucle partout (une ligne, jamais de
-- musique par zone) ; morceaux livrés en cours de partie (sous-dossier, autre volume) : ils
-- remplacent MUS_Hub en fondu ; un morceau absent est sauté (une ligne chacun), un Folder ou un Sound
-- qui ne se copie pas aussi.

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
local function finish(name)
	local copy = musicCopy(name)
	copy.Playing = false
	copy.Ended:Fire(copy.SoundId)
end
local function skipLines(name)
	return logCount(`{name} absent de ReplicatedStorage.Assets.Music (ou pas un Sound) : morceau sauté dans la playlist de fond`, "PRINT", "client")
end
local NONE_LINE = "aucun morceau de la playlist de fond dans ReplicatedStorage.Assets.Music : repli sur MUS_Hub partout"

section("P. Pas de dossier Assets/Music")
local ok, err = pcall(advance, 3)
check(ok, `P1 aucune erreur sans musique ({err})`)
check(#musicCopies() == 0 and state().Track == nil, "P2 rien ne joue")
check(logCount("ReplicatedStorage.Assets.Music absent : pas de musique (L-056)", "PRINT", "client") == 1, "P3 une seule ligne en Studio pour le dossier")

section("P'. Ni playlist ni MUS_Hub : silence")
buildMusic()
for _, name in PLAYLIST do
	MUSIC[name]:Destroy()
end
MUSIC.MUS_Hub:Destroy()
go(zoneMiddle(2), 0, 0.5)
check(state().Track == nil and #musicCopies() == 0, `P4 zone 2 : rien ne joue, ni MUS_Z2 ni l'ancien MUS_Ambient ({state().Track})`)
check(logCount("MUS_Hub absent de ReplicatedStorage.Assets.Music (ou pas un Sound) : pas de musique de fond", "PRINT", "client") == 1, "P5 une ligne en Studio pour MUS_Hub")

section("P''. Aucun morceau de la playlist : repli sur MUS_Hub en boucle partout")
MUSIC.MUS_Hub = make("Sound", { Name = "MUS_Hub", SoundId = MUSIC_IDS.MUS_Hub, Looped = true, Volume = 0.4 }, MUSIC_FOLDER)
go(-113, 0, 0.3)
check(state().Track == "MUS_Hub", `P6 zone safe : MUS_Hub ({state().Track})`)
check(logCount(NONE_LINE, "PRINT", "client") == 1, "P7 une ligne en Studio pour le repli")
check(skipLines(PLAYLIST[1]) == 0, "P8 pas de ligne par morceau quand aucun n'est là")
advance(2.2)
local hub = musicCopy("MUS_Hub")
check(hub.Looped == true, "P9 MUS_Hub jouée en boucle")
hub.TimePosition = 12
for zone = 1, 6 do
	go(zoneMiddle(zone), 0, 0.3)
	check(state().Track == "MUS_Hub" and level("MUS_Hub") == 1, `P10.{zone} zone {zone} : toujours MUS_Hub ({state().Track})`)
end
check(#musicCopies() == 1 and hub.TimePosition == 12, "P11 jamais de musique par zone, MUS_Hub jamais relancée")
check(logCount("repli sur MUS_Hub", "PRINT", "client") == 1, "P12 toujours une seule ligne")

section("P'''. Folder, puis Sound qui ne se copie pas : sautés, MUS_Hub continue")
local notSound = make("Folder", { Name = PLAYLIST[1] }, MUSIC_FOLDER)
advance(0.5)
check(state().Track == "MUS_Hub", "P13 Morning Mood qui est un Folder : MUS_Hub continue")
notSound:Destroy()
local locked = make("Sound", { Name = PLAYLIST[1], Volume = 0.2, Archivable = false }, MUSIC_FOLDER)
advance(0.5)
check(state().Track == "MUS_Hub" and logHas(`{PLAYLIST[1]} ne se copie pas (Archivable = false) : morceau sauté`, "WARN", "client"), "P14 Sound qui ne se copie pas : MUS_Hub continue, un avertissement")
check(locked.Parent == MUSIC_FOLDER and locked.Archivable == false, "P15 il n'est pas touché")
locked:Destroy()

section("P''''. Le Printemps livré en cours de partie, dans un sous-dossier, à 0,8")
local sub = folder(MUSIC_FOLDER, "Ambient")
local spring = addPlaylistSound(PLAYLIST[2], sub, 0.8)
advance(0.3)
check(state().Track == PLAYLIST[2], `P16 trouvé dans le sous-dossier et visé, sans relancer le jeu ({state().Track})`)
check(skipLines(PLAYLIST[1]) == 1, "P17 Morning Mood absent : sauté, une ligne en Studio")
advance(2.2)
check(level(PLAYLIST[2]) == 1 and level("MUS_Hub") == 0 and hub.Playing == false, "P18 fondu enchaîné fini : MUS_Hub éteinte")
check(near(musicCopy(PLAYLIST[2]).Volume, 0.8, 1e-9), "P19 joué au volume de Clément (0,8)")
check(spring.Volume == 0.8 and spring.Playing == false and spring.Parent == sub, "P20 son Sound n'est pas touché")

section("P'''''. Morceaux absents sautés à la fin d'un morceau")
addPlaylistSound(PLAYLIST[5]) -- Clair de lune ; 3, 4, 6 et 1 manquent
finish(PLAYLIST[2])
advance(0.3)
check(state().Track == PLAYLIST[5], `P21 après Le Printemps : Marche turque et Gymnopédie sautées, Clair de lune ({state().Track})`)
check(skipLines(PLAYLIST[3]) == 1 and skipLines(PLAYLIST[4]) == 1, "P22 une ligne pour chaque morceau sauté")
advance(2.2)
finish(PLAYLIST[5])
advance(0.3)
check(state().Track == PLAYLIST[2], `P23 après Clair de lune : Classic Easter et Morning Mood sautés, retour au Printemps ({state().Track})`)
check(musicCopy(PLAYLIST[2]).TimePosition == 0 and musicCopy(PLAYLIST[2]).Playing, "P24 Le Printemps repart du début")
advance(2.2)
finish(PLAYLIST[2])
advance(0.3)
check(state().Track == PLAYLIST[5], "P25 un tour de plus : Clair de lune")
check(skipLines(PLAYLIST[1]) == 1 and skipLines(PLAYLIST[3]) == 1 and skipLines(PLAYLIST[6]) == 1, "P26 toujours une seule ligne par morceau absent")
check(state().Track ~= "MUS_Hub" and logCount("repli sur MUS_Hub", "PRINT", "client") == 1, "P27 MUS_Hub reste éteinte")
local ok2, err2 = pcall(advance, 2)
check(ok2, `P28 aucune erreur ({err2})`)

summary("scénario pistes manquantes")
