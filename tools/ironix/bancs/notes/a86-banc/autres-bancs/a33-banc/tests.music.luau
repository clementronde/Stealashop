--!nocheck
-- M. Playlist de fond (MusicController, Config/Music ; a87, demande de Cantin du 2026-11-11) : les 6
-- morceaux de Music.AmbientTracks dans l'ordre, Morning Mood d'abord, partout (zone safe, chaque zone,
-- couloir, nuit), jamais relancés en changeant de zone ; à la fin d'un morceau (Ended), le suivant
-- monte en fondu ; après le 6e, retour au premier ; copies sans boucle (les Sound de Clément ne bougent
-- pas) ; réglage du volume (attribut MusicVolume) ; pas de personnage.

local Music = sharedModule("Config/Music")
local FULL = PLAYLIST_VOLUME -- Volume des Sound de la playlist (0,2 dans Studio)

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
-- Fin naturelle d'un morceau, comme Roblox : la copie s'arrête et lance Ended.
local function finish(name)
	local copy = musicCopy(name)
	copy.TimePosition = 200
	copy.Playing = false
	copy.Ended:Fire(copy.SoundId)
end

-- À chaque image : le volume écrit sur chaque copie = volume de Clément × part du fondu × réglage.
local mismatches = 0
local volumeScale = 1
ON_FRAME = function()
	for name, part in state().Levels do
		local copy = musicCopy(name)
		if copy == nil or math.abs(copy.Volume - MUSIC_VOLUME[name] * part * volumeScale) > 1e-9 then
			mismatches += 1
		end
	end
end

local FIRST = PLAYLIST[1]

section("M. Démarrage dans la zone safe : Morning Mood")
advance(1 / 30)
local first, firstCount = musicCopy(FIRST)
check(state().Track == FIRST and state().Event == nil, `M1 zone safe : {FIRST} visée ({state().Track})`)
check(first ~= nil and firstCount == 1 and first.Parent == SoundService, "M2 une copie de Morning Mood, dans SoundService (son 2D, local)")
check(first and first.Playing and first.Looped == false and first.SoundId == MUSIC_IDS[FIRST], "M3 la copie joue, sans boucle (playlist)")
check(first and first.Volume < 0.05, `M4 elle commence presque muette ({first and first.Volume})`)
advance(0.97)
check(first and near(first.Volume, FULL / 2, 0.02), `M5 à mi-fondu (1 s), la moitié du volume de Clément ({first and first.Volume})`)
advance(1.2)
check(first and near(first.Volume, FULL, 1e-9), `M6 après FadeTime (2 s), le volume de Clément ({first and first.Volume})`)
check(untouched(FIRST), "M7 le Sound de Clément n'a pas bougé")
check(musicCopy("MUS_Hub") == nil and musicCopy("MUS_Ambient") == nil, "M8 ni MUS_Hub ni l'ancien MUS_Ambient ne sont joués")
check(#musicCopies() == 1, `M9 un seul morceau copié tant que le premier joue ({#musicCopies()})`)

section("M'. Partout le même morceau, sans redémarrage")
first.TimePosition = 30 -- le morceau a avancé
for zone = 1, 6 do
	go(zoneMiddle(zone), 0, 0.3)
	check(state().Track == FIRST and level(FIRST) == 1, `M10.{zone} milieu de la zone {zone} : Morning Mood pleine ({state().Track})`)
end
go(END_X + 60, 0)
check(state().Track == FIRST, "M11 au-delà du fond du couloir : Morning Mood")
go(245, 45)
check(state().Track == FIRST, "M12 dans un magasin de la zone 3 : Morning Mood")
local nightWall = MAP:FindFirstChild("NightWall")
nightWall.CFrame = CFrame.new(27, 20, 0)
go(zoneMiddle(2), 0, 0.3)
check(state().Track == FIRST, "M13 de nuit, dans le couloir : Morning Mood")
nightWall.CFrame = CFrame.new(27, -20, 0)
go(-113, 3)
check(first.TimePosition == 30 and first.Playing and musicCopy(FIRST) == first, "M14 la même copie a joué tout du long, jamais relancée (TimePosition gardée)")
local noZone = true
for _, name in { "MUS_Hub", "MUS_Z1", "MUS_Z2", "MUS_Z3", "MUS_Z4", "MUS_Z5", "MUS_Z6" } do
	noZone = noZone and musicCopy(name) == nil
end
check(noZone, "M15 MUS_Hub et MUS_Z1 à MUS_Z6 jamais jouées")

section("M''. Config/Music : la playlist")
local same = #Music.AmbientTracks == #PLAYLIST
for i, name in PLAYLIST do
	same = same and Music.AmbientTracks[i] == name
end
check(same, "M16 Config/Music.AmbientTracks : les 6 morceaux, dans l'ordre (Morning Mood d'abord)")
check(rawget(Music, "AmbientTrack") == nil and Music.FallbackTrack == "MUS_Hub", "M17 plus de AmbientTrack ; repli MUS_Hub")

section("M'''. Fin d'un morceau : le suivant en fondu, dans l'ordre, puis retour au premier")
advance(0.3)
check(state().Track == FIRST, "M18 Morning Mood toujours en cours")
finish(FIRST)
advance(1 / 30)
check(state().Track == PLAYLIST[2], `M19 fin de Morning Mood : Le Printemps visé ({state().Track})`)
check(level(FIRST) == 0 and first.Playing == false and first.TimePosition == 0, "M20 Morning Mood se tait, remise au début")
local second = musicCopy(PLAYLIST[2])
check(second and second.Playing and second.Looped == false and second.Volume < 0.05, "M21 Le Printemps part presque muet")
advance(0.97)
check(near(level(PLAYLIST[2]), 0.5, 0.03), `M22 à mi-fondu : la moitié ({level(PLAYLIST[2])})`)
advance(1.2)
check(level(PLAYLIST[2]) == 1 and near(second.Volume, FULL, 1e-9), "M23 après FadeTime : Le Printemps plein")
musicCopy(PLAYLIST[2]).Ended:Fire("x") -- un Ended en double (ancien morceau) ne saute pas un morceau de plus
musicCopy(PLAYLIST[2]).Ended:Fire("x")
advance(0.3)
local doubleOk = state().Track == PLAYLIST[3]
check(doubleOk, `M24 deux Ended du même morceau : un seul pas en avant ({state().Track})`)
local order = { state().Track }
for i = 3, 6 do
	advance(2.2)
	finish(PLAYLIST[i])
	advance(0.3)
	table.insert(order, state().Track)
end
check(order[1] == PLAYLIST[3] and order[2] == PLAYLIST[4] and order[3] == PLAYLIST[5] and order[4] == PLAYLIST[6] and order[5] == FIRST,
	`M25 ordre : Marche turque, Gymnopédie, Clair de lune, Classic Easter, puis Morning Mood ({table.concat(order, ", ")})`)
check(musicCopy(FIRST) == first and first.Playing and first.TimePosition == 0, "M26 après le 6e : la même copie de Morning Mood repart du début")
local copies = musicCopies()
check(#copies == 6, `M27 une copie par morceau, jamais deux ({#copies})`)
advance(2.2)
local others = 0
for _, name in PLAYLIST do
	if name ~= FIRST and (level(name) ~= 0 or musicCopy(name).Playing) then
		others += 1
	end
end
check(level(FIRST) == 1 and others == 0, "M28 un seul morceau joue à la fois")
local allUntouched = true
for _, name in MUSIC_NAMES do
	allUntouched = allUntouched and untouched(name)
end
check(allUntouched, "M29 aucun des Sound de Clément n'a été modifié")

section("M''''. Réglage du volume : attribut MusicVolume du Player local")
check(Music.VolumeAttribute == "MusicVolume", "M30 point d'accroche : attribut MusicVolume")
alice:SetAttribute("MusicVolume", 0.5)
volumeScale = 0.5
advance(0.1)
check(near(first.Volume, FULL / 2, 1e-9), `M31 MusicVolume = 0,5 : la moitié du volume de Clément ({first.Volume})`)
alice:SetAttribute("MusicVolume", 0)
volumeScale = 0
advance(0.1)
check(first.Volume == 0, "M32 MusicVolume = 0 : muet")
finish(FIRST)
advance(2.5)
check(state().Track == PLAYLIST[2] and musicCopy(PLAYLIST[2]).Volume == 0, "M33 muet : le morceau suivant reste muet")
alice:SetAttribute("MusicVolume", 2)
volumeScale = 1
advance(0.1)
check(near(musicCopy(PLAYLIST[2]).Volume, FULL, 1e-9), "M34 MusicVolume = 2 : borné à 1")
alice:SetAttribute("MusicVolume", "loud")
advance(0.1)
check(near(musicCopy(PLAYLIST[2]).Volume, FULL, 1e-9), "M35 MusicVolume pas un nombre : 1")
alice:SetAttribute("MusicVolume", nil)
advance(0.1)
check(mismatches == 0, `M36 à chaque image, volume écrit = volume de Clément × fondu × réglage ({mismatches} écart(s))`)

section("M'''''. Pas de personnage")
alice.Character:Destroy()
alice.Character = nil
advance(1)
check(state().Track == PLAYLIST[2] and musicCopy(PLAYLIST[2]).Playing, "M37 pas de personnage (mort) : le morceau continue")
spawnCharacter(alice, Vector3.new(-100, 3, 20))
advance(0.3)
check(state().Track == PLAYLIST[2], "M38 réapparition : le même morceau continue")
check(not logHas("[MusicController]", "WARN", "client"), "M39 aucun avertissement du contrôleur")
check(not logHas("[MusicController]", "PRINT", "client"), "M40 aucune ligne en Studio (tout est livré)")

summary("scénario musique")
