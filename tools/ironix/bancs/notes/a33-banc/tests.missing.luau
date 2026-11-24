--!nocheck
-- P. Pistes manquantes (MusicController, L-056 : « tant qu'un son manque, rien ne joue ») : pas de
-- dossier Assets/Music, une piste absente, un objet qui n'est pas un Sound, une piste qui arrive en
-- cours de partie, une piste rangée dans un sous-dossier, un Sound qui ne se copie pas, un volume de
-- Clément différent ; arche dont les pièces arrivent après coup (streaming).

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(-113, 3, 0))
-- Arche 3 reçue sans ses pièces (streaming) : le Model et son tag sont là, pas sa pièce.
local arch3 = GATES[3].Arch
arch3.Parent = nil
GATES[3].PrimaryPart = nil
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
local function allSilent()
	for _, copy in musicCopies() do
		if copy.Playing or copy.Volume > 0 then
			return false
		end
	end
	return true
end

section("P. Pas de dossier Assets/Music")
local ok, err = pcall(advance, 3)
check(ok, `P1 aucune erreur sans musique ({err})`)
check(#musicCopies() == 0 and state().Track == nil and state().Zone == 0, "P2 rien ne joue, zone safe repérée quand même")
check(logCount("ReplicatedStorage.Assets.Music absent : pas de musique (L-056)", "PRINT", "client") == 1, "P3 une seule ligne en Studio")

section("P'. Arche sans pièces (streaming), puis ses pièces arrivent")
go(zoneMiddle(3), 0)
check(state().Zone == 2, `P4 arche 3 sans pièce : en x = 245, zone 2 (la dernière arche lisible passée) ({state().Zone})`)
arch3.Parent = GATES[3]
GATES[3].PrimaryPart = arch3
advance(0.3)
check(state().Zone == 3, `P5 ses pièces arrivent : zone 3 ({state().Zone})`)
go(-113, 0)

section("P''. Clément livre la musique en cours de partie, sauf MUS_Z3")
buildMusic()
MUSIC.MUS_Z3:Destroy()
MUSIC.MUS_Z4.Volume = 0.8 -- un volume de départ différent, réglé avant la première écoute
advance(0.3)
check(state().Track == "MUS_Hub" and musicCopy("MUS_Hub") ~= nil, "P6 la musique arrive : MUS_Hub joue sans relancer le jeu")
advance(2.2)
go(zoneMiddle(2), 0, 2.5)
check(level("MUS_Z2") == 1, "P7 zone 2 : MUS_Z2")
go(zoneMiddle(3), 0, 2.5)
check(state().Zone == 3 and state().Track == nil, "P8 zone 3 sans MUS_Z3 : aucune piste visée")
check(allSilent(), "P9 … et tout s'est éteint en fondu : silence")
check(logCount("MUS_Z3 absent de ReplicatedStorage.Assets.Music", "PRINT", "client") == 1, "P10 une ligne en Studio")
go(zoneMiddle(2), 0, 2.5)
go(zoneMiddle(3), 0, 2.5)
check(allSilent() and logCount("MUS_Z3 absent", "PRINT", "client") == 1, "P11 de retour en zone 3 : silence, toujours une seule ligne")
local late = make("Sound", { Name = "MUS_Z3", SoundId = MUSIC_IDS.MUS_Z3, Looped = true, Volume = 0.4 }, MUSIC_FOLDER)
MUSIC.MUS_Z3 = late
advance(0.3)
check(state().Track == "MUS_Z3", "P12 MUS_Z3 livrée pendant qu'on est en zone 3 : elle joue")
advance(2.2)
check(level("MUS_Z3") == 1 and near(musicCopy("MUS_Z3").Volume, 0.4, 1e-9), "P13 … à son volume")

section("P'''. Volume de départ = le Volume du Sound de Clément")
go(zoneMiddle(4), 0, 2.5)
check(near(musicCopy("MUS_Z4").Volume, 0.8, 1e-9), `P14 MUS_Z4 réglée à 0,8 par Clément : jouée à 0,8 ({musicCopy("MUS_Z4").Volume})`)
check(MUSIC.MUS_Z4.Volume == 0.8 and MUSIC.MUS_Z4.Playing == false, "P15 son Sound n'est pas touché")

section("P''''. Objet qui n'est pas un Sound, sous-dossier, Sound qui ne se copie pas")
MUSIC.MUS_Z5:Destroy()
local notSound = make("Folder", { Name = "MUS_Z5" }, MUSIC_FOLDER)
go(zoneMiddle(5), 0, 2.5)
check(state().Track == nil and allSilent(), "P16 MUS_Z5 qui est un Folder : silence")
check(logHas("MUS_Z5 absent de ReplicatedStorage.Assets.Music (ou pas un Sound)", "PRINT", "client"), "P17 une ligne en Studio")
local sub = folder(MUSIC_FOLDER, "Corridor")
MUSIC.MUS_Z6.Parent = sub
go(zoneMiddle(6), 0, 0.3)
check(state().Track == "MUS_Z6", "P18 MUS_Z6 rangée dans un sous-dossier de Music : trouvée")
local locked = make("Sound", { Name = "MUS_Z5", Volume = 0.4, Archivable = false }, sub)
notSound:Destroy()
go(zoneMiddle(5), 0, 0.3)
check(state().Track == nil and logHas("MUS_Z5 ne se copie pas (Archivable = false)", "WARN", "client"), "P19 Sound qui ne se copie pas (Archivable = false) : silence et un avertissement")
check(locked.Parent == sub and locked.Archivable == false, "P20 il n'est pas touché")
local ok2, err2 = pcall(advance, 2)
check(ok2, `P21 aucune erreur ({err2})`)

summary("scénario pistes manquantes")
