--!nocheck
-- M. Musique de fond (MusicController, Config/Music ; a86, demande de Cantin du 2026-11-11) : une seule
-- piste, MUS_Ambient, partout (zone safe, chaque zone, fond du couloir, sous une arche, magasin, nuit),
-- jamais relancée en changeant de zone ; MUS_Hub et MUS_Z1 à Z6 jamais jouées ; copies seulement (les
-- Sound de Clément ne bougent pas) ; réglage du volume (attribut MusicVolume) ; pas de personnage.

local Music = sharedModule("Config/Music")
local FULL = 0.4 -- volume des Sound de Clément (relevé §2)

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

-- À chaque image : le volume écrit sur chaque copie = volume de Clément × part du fondu × réglage.
local mismatches = 0
local volumeScale = 1
ON_FRAME = function()
	for name, part in state().Levels do
		local copy = musicCopy(name)
		if copy == nil or math.abs(copy.Volume - FULL * part * volumeScale) > 1e-9 then
			mismatches += 1
		end
	end
end

section("M. Démarrage dans la zone safe")
advance(1 / 30)
local amb, ambCount = musicCopy("MUS_Ambient")
check(state().Track == "MUS_Ambient" and state().Event == nil, `M1 zone safe : MUS_Ambient visée ({state().Track})`)
check(amb ~= nil and ambCount == 1 and amb.Parent == SoundService, "M2 une copie de MUS_Ambient, dans SoundService (son 2D, local)")
check(amb and amb.Playing and amb.Looped and amb.SoundId == MUSIC_IDS.MUS_Ambient, "M3 la copie joue, en boucle, Morning Mood")
check(amb and amb.Volume < 0.05, `M4 elle commence presque muette ({amb and amb.Volume})`)
advance(0.97)
check(amb and near(amb.Volume, FULL / 2, 0.03), `M5 à mi-fondu (1 s), la moitié du volume de Clément ({amb and amb.Volume})`)
advance(1.2)
check(amb and near(amb.Volume, FULL, 1e-9), `M6 après FadeTime (2 s), le volume de Clément ({amb and amb.Volume})`)
check(untouched("MUS_Ambient"), "M7 le Sound de Clément n'a pas bougé")
check(musicCopy("MUS_Hub") == nil, "M8 MUS_Hub n'est pas jouée dans la zone safe")

section("M'. Partout la même piste, sans redémarrage")
amb.TimePosition = 30 -- la piste a avancé
go(33, 0)
check(state().Track == "MUS_Ambient", `M9 3 studs après l'arche 1 : toujours MUS_Ambient ({state().Track})`)
for zone = 1, 6 do
	go(zoneMiddle(zone), 0, 0.3)
	check(state().Track == "MUS_Ambient" and level("MUS_Ambient") == 1, `M10.{zone} milieu de la zone {zone} : MUS_Ambient pleine ({state().Track})`)
end
go(END_X, 0)
check(state().Track == "MUS_Ambient", "M11 au fond du couloir : MUS_Ambient")
go(END_X + 60, 0)
check(state().Track == "MUS_Ambient", "M12 au-delà du fond : MUS_Ambient")
go(245, 45)
check(state().Track == "MUS_Ambient", "M13 dans un magasin de la zone 3 : MUS_Ambient")
go(101, 0)
go(99, 0)
check(state().Track == "MUS_Ambient", "M14 sous une arche, aller-retour : MUS_Ambient")
go(-113, 3)
check(state().Track == "MUS_Ambient", "M15 retour dans la zone safe : MUS_Ambient")
check(amb.TimePosition == 30 and amb.Playing and musicCopy("MUS_Ambient") == amb, "M16 la même copie a joué tout du long, jamais relancée (TimePosition gardée)")
local copies = musicCopies()
check(#copies == 1, `M17 une seule copie de musique en tout ({#copies})`)
local noZone = true
for _, name in { "MUS_Hub", "MUS_Z1", "MUS_Z2", "MUS_Z3", "MUS_Z4", "MUS_Z5", "MUS_Z6" } do
	noZone = noZone and musicCopy(name) == nil
end
check(noZone, "M18 MUS_Hub et MUS_Z1 à MUS_Z6 jamais jouées")
local allUntouched = true
for _, name in MUSIC_NAMES do
	allUntouched = allUntouched and untouched(name)
end
check(allUntouched, "M19 aucun des Sound de Clément n'a été modifié")
check(Music.AmbientTrack == "MUS_Ambient" and Music.FallbackTrack == "MUS_Hub", "M20 Config/Music : AmbientTrack et FallbackTrack")
check(rawget(Music, "HubTrack") == nil and rawget(Music, "ZoneTrack") == nil and rawget(Music, "GateMargin") == nil, "M21 plus de piste par zone dans Config/Music")

section("M''. Nuit : mur levé, même musique")
local nightWall = MAP:FindFirstChild("NightWall")
nightWall.CFrame = CFrame.new(27, 20, 0)
go(-50, 0, 0.3)
check(state().Track == "MUS_Ambient", "M22 de nuit, dans la zone safe : MUS_Ambient")
go(zoneMiddle(2), 0, 0.3)
check(state().Track == "MUS_Ambient", "M23 de nuit, dans le couloir : MUS_Ambient")
nightWall.CFrame = CFrame.new(27, -20, 0)

section("M'''. Réglage du volume : attribut MusicVolume du Player local")
check(Music.VolumeAttribute == "MusicVolume", "M24 point d'accroche : attribut MusicVolume")
alice:SetAttribute("MusicVolume", 0.5)
volumeScale = 0.5
advance(0.1)
check(near(amb.Volume, 0.2, 1e-9), `M25 MusicVolume = 0,5 : la moitié du volume de Clément ({amb.Volume})`)
alice:SetAttribute("MusicVolume", 0)
volumeScale = 0
advance(0.1)
check(amb.Volume == 0, "M26 MusicVolume = 0 : muet")
alice:SetAttribute("MusicVolume", 2)
volumeScale = 1
advance(0.1)
check(near(amb.Volume, FULL, 1e-9), "M27 MusicVolume = 2 : borné à 1")
alice:SetAttribute("MusicVolume", "loud")
advance(0.1)
check(near(amb.Volume, FULL, 1e-9), "M28 MusicVolume pas un nombre : 1")
alice:SetAttribute("MusicVolume", 0 / 0)
advance(0.1)
check(near(amb.Volume, FULL, 1e-9), "M29 MusicVolume NaN : 1")
alice:SetAttribute("MusicVolume", nil)
advance(0.1)
check(mismatches == 0, `M30 à chaque image, volume écrit = volume de Clément × fondu × réglage ({mismatches} écart(s))`)

section("M''''. Pas de personnage")
alice.Character:Destroy()
alice.Character = nil
advance(1)
check(state().Track == "MUS_Ambient" and amb.Playing, "M31 pas de personnage (mort) : MUS_Ambient continue")
spawnCharacter(alice, Vector3.new(-100, 3, 20))
advance(0.3)
check(state().Track == "MUS_Ambient" and musicCopy("MUS_Ambient") == amb, "M32 réapparition : la même piste continue")
check(not logHas("[MusicController]", "WARN", "client"), "M33 aucun avertissement du contrôleur")
check(not logHas("[MusicController]", "PRINT", "client"), "M34 aucune ligne en Studio (tout est livré)")

summary("scénario musique")
