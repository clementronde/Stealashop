--!nocheck
-- M. Musique par zone (MusicController, Config/Music, L-056) : piste selon la position (zone safe,
-- chaque zone, fond du couloir, entre deux arches, marge sous une arche), fondu enchaîné sans deux
-- pistes à fond, copies seulement (les Sound de Clément ne bougent pas), reprise d'une piste,
-- réglage du volume (attribut MusicVolume), arches sorties du streaming, _INBOX_CLEMENT ignoré.

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

-- Vérifications continues, à chaque image : jamais deux pistes à fond, jamais plus qu'une piste
-- pleine, et le volume écrit sur chaque copie = volume de Clément × part du fondu × réglage.
local maxFull, maxSum, mismatches = 0, 0, 0
local volumeScale = 1
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
		if copy == nil or math.abs(copy.Volume - FULL * part * volumeScale) > 1e-9 then
			mismatches += 1
		end
	end
	maxFull = math.max(maxFull, full)
	maxSum = math.max(maxSum, sum)
end

section("M. Démarrage dans la zone safe")
advance(1 / 30)
local hubCopy, hubCount = musicCopy("MUS_Hub")
check(state().Zone == 0 and state().Track == "MUS_Hub", `M1 zone safe : MUS_Hub visée (zone {state().Zone}, piste {state().Track})`)
check(hubCopy ~= nil and hubCount == 1 and hubCopy.Parent == SoundService, "M2 une copie de MUS_Hub, dans SoundService (son 2D, local)")
check(hubCopy and hubCopy.Playing and hubCopy.Looped and hubCopy.SoundId == MUSIC_IDS.MUS_Hub, "M3 la copie joue, en boucle, la musique de Clément")
check(hubCopy and hubCopy.Volume < 0.05, `M4 elle commence presque muette ({hubCopy and hubCopy.Volume})`)
advance(0.97)
check(hubCopy and near(hubCopy.Volume, FULL / 2, 0.03), `M5 à mi-fondu (1 s), la moitié du volume de Clément ({hubCopy and hubCopy.Volume})`)
advance(1.2)
check(hubCopy and near(hubCopy.Volume, FULL, 1e-9), `M6 après FadeTime (2 s), le volume de départ de Clément : 0,4 ({hubCopy and hubCopy.Volume})`)
check(untouched("MUS_Hub"), "M7 le Sound de Clément n'a pas bougé (volume, boucle, à l'arrêt, à sa place)")

section("M'. Piste selon la position")
go(24.5, 0)
check(state().Track == "MUS_Hub", "M8 juste hors du volume safe, avant l'arche 1 (mur de nuit) : MUS_Hub")
go(33, 0)
check(state().Zone == 1 and state().Track == "MUS_Z1", `M9 3 studs après l'arche 1 : MUS_Z1 ({state().Track})`)
local z1 = musicCopy("MUS_Z1")
advance(0.7) -- environ 1 s après le changement
check(z1 and z1.Playing and hubCopy.Playing and level("MUS_Z1") > 0.3 and level("MUS_Hub") < 0.7, `M10 fondu enchaîné : les deux pistes à mi-chemin ({level("MUS_Hub")}, {level("MUS_Z1")})`)
advance(2)
check(level("MUS_Z1") == 1 and level("MUS_Hub") == 0, "M11 fondu fini : MUS_Z1 pleine, MUS_Hub à 0")
check(hubCopy.Playing == false and not isDestroyed(hubCopy), "M12 MUS_Hub en pause (pas détruite)")
for zone = 1, 6 do
	go(zoneMiddle(zone), 0, 0.3)
	local ok = state().Zone == zone and state().Track == `MUS_Z{zone}`
	check(ok, `M13.{zone} milieu de la zone {zone} (x = {zoneMiddle(zone)}) : MUS_Z{zone} ({state().Track})`)
	advance(2.2)
	check(level(`MUS_Z{zone}`) == 1, `M14.{zone} MUS_Z{zone} pleine après le fondu`)
end
go(END_X, 0)
check(state().Track == "MUS_Z6", "M15 au fond du couloir (x = 700) : MUS_Z6")
go(END_X + 60, 0)
check(state().Track == "MUS_Z6", "M16 au-delà du fond : MUS_Z6")
go(245, 45)
check(state().Track == "MUS_Z3", "M17 dans un magasin de la zone 3 (hors de la chaussée) : MUS_Z3")
go(120, 0)
check(state().Track == "MUS_Z2", "M18 entre l'arche 2 et l'arche 3 : MUS_Z2")
go(-113, 3)
check(state().Track == "MUS_Hub", "M19 retour dans la zone safe : MUS_Hub")
local copyCount = #musicCopies()
check(copyCount == 7, `M20 une seule copie par piste, faite une fois (7 : {copyCount})`)
local allUntouched = true
for _, name in MUSIC_NAMES do
	allUntouched = allUntouched and untouched(name)
end
check(allUntouched, "M21 aucun des 7 Sound de Clément n'a été modifié")
local allLooped = true
for _, copy in musicCopies() do
	allLooped = allLooped and copy.Looped
end
check(allLooped, "M22 toutes les copies en boucle")

section("M''. Marge sous une arche (GateMargin = 2)")
go(zoneMiddle(1), 0, 2.5)
go(101, 0)
check(state().Track == "MUS_Z1", "M23 1 stud après l'arche 2, en venant de la zone 1 : toujours MUS_Z1")
go(103, 0)
check(state().Track == "MUS_Z2", "M24 3 studs après : MUS_Z2")
go(99, 0)
check(state().Track == "MUS_Z2", "M25 1 stud avant l'arche 2, en revenant : toujours MUS_Z2")
go(97, 0)
check(state().Track == "MUS_Z1", "M26 3 studs avant : MUS_Z1")
go(29, 0)
check(state().Track == "MUS_Z1", "M27 1 stud avant l'arche 1, en revenant de la zone 1 : toujours MUS_Z1")
go(27, 0)
check(state().Track == "MUS_Hub", "M28 3 studs avant : MUS_Hub")

section("M'''. Changements rapides : jamais deux pistes à fond")
go(-113, 0, 2.5)
maxFull, maxSum = 0, 0
go(zoneMiddle(1), 0, 0.5)
go(zoneMiddle(2), 0, 0.5)
go(zoneMiddle(3), 0, 0.5)
go(zoneMiddle(2), 0, 0.5)
go(-113, 0, 3)
check(maxFull <= 1, `M29 jamais deux pistes à fond en même temps (au plus {maxFull})`)
check(maxSum <= 1 + 1e-6, `M30 parts additionnées jamais au-dessus d'une piste pleine ({maxSum})`)
check(level("MUS_Hub") == 1 and level("MUS_Z1") == 0 and level("MUS_Z2") == 0 and level("MUS_Z3") == 0, "M31 à la fin, seule MUS_Hub joue")
local playing = 0
for _, copy in musicCopies() do
	if copy.Playing then
		playing += 1
	end
end
check(playing == 1, `M32 une seule copie en lecture, les autres en pause ({playing})`)

section("M''''. Une piste reprend où elle en était")
go(zoneMiddle(1), 0, 2.5)
local z1Copy = musicCopy("MUS_Z1")
z1Copy.TimePosition = 42 -- la piste a avancé
go(-113, 0, 2.5)
check(z1Copy.Playing == false and z1Copy.TimePosition == 42, "M33 MUS_Z1 éteinte : en pause à 42 s")
go(zoneMiddle(1), 0, 0.3)
check(z1Copy.Playing == true and z1Copy.TimePosition == 42 and musicCopy("MUS_Z1") == z1Copy, "M34 de retour en zone 1 : la même copie reprend à 42 s")

section("M'''''. Réglage du volume : attribut MusicVolume du Player local")
go(zoneMiddle(1), 0, 2.5)
check(Music.VolumeAttribute == "MusicVolume", "M35 point d'accroche : attribut MusicVolume")
alice:SetAttribute("MusicVolume", 0.5)
volumeScale = 0.5
advance(0.1)
check(near(z1Copy.Volume, 0.2, 1e-9), `M36 MusicVolume = 0,5 : la moitié du volume de Clément ({z1Copy.Volume})`)
alice:SetAttribute("MusicVolume", 0)
volumeScale = 0
advance(0.1)
check(z1Copy.Volume == 0, "M37 MusicVolume = 0 : muet")
alice:SetAttribute("MusicVolume", 2)
volumeScale = 1
advance(0.1)
check(near(z1Copy.Volume, FULL, 1e-9), "M38 MusicVolume = 2 : borné à 1 (jamais plus fort que Clément)")
alice:SetAttribute("MusicVolume", "loud")
advance(0.1)
check(near(z1Copy.Volume, FULL, 1e-9), "M39 MusicVolume pas un nombre : 1")
alice:SetAttribute("MusicVolume", 0 / 0)
advance(0.1)
check(near(z1Copy.Volume, FULL, 1e-9), "M40 MusicVolume NaN : 1")
alice:SetAttribute("MusicVolume", 0.25)
volumeScale = 0.25
go(-113, 0, 2.5)
check(near(hubCopy.Volume, 0.1, 1e-9), "M41 le réglage vaut pour toutes les pistes (MUS_Hub à 0,1)")
alice:SetAttribute("MusicVolume", nil)
volumeScale = 1
advance(0.1)
check(near(hubCopy.Volume, FULL, 1e-9), "M42 attribut retiré : retour au volume de Clément")
check(mismatches == 0, `M43 à chaque image, volume écrit = volume de Clément × fondu × réglage ({mismatches} écart(s))`)

section("M''''''. Streaming : arches sorties du jeu, gardées une fois vues")
for zone = 2, 5 do
	GATES[zone].Parent = nil
end
go(zoneMiddle(4), 0, 0.3)
check(state().Track == "MUS_Z4", "M44 arches 2 à 5 sorties du streaming : la zone 4 est toujours MUS_Z4")
go(zoneMiddle(2), 0, 0.3)
check(state().Track == "MUS_Z2", "M45 … et la zone 2, MUS_Z2")
SAFE_ZONE.Parent = nil
go(-113, 0, 0.3)
check(state().Track == "MUS_Hub", "M46 volume de la zone safe sorti lui aussi : MUS_Hub dans la zone safe")
SAFE_ZONE.Parent = MAP
for zone = 2, 5 do
	GATES[zone].Parent = MAP
end

section("M'''''''. _INBOX_CLEMENT ignoré, pas de personnage")
local inbox = folder(Workspace, "_INBOX_CLEMENT")
local stray = make("Model", { Name = "ZoneGate_Test" }, inbox)
local strayArch = make("Part", { Name = "Arch", Anchored = true, Size = Vector3.new(2, 24, 50), CFrame = CFrame.new(50, 12, 0) }, stray)
stray.PrimaryPart = strayArch
stray:SetAttribute("Zone", 3)
addTag(stray, "ZoneGate")
go(65, 0, 0.3)
check(state().Track == "MUS_Z1", "M47 une arche « zone 3 » dans _INBOX_CLEMENT (x = 50) ne compte pas : MUS_Z1 en x = 65")
alice.Character:Destroy()
alice.Character = nil
advance(1)
check(state().Track == "MUS_Z1", "M48 pas de personnage (mort) : la piste ne change pas")
spawnCharacter(alice, Vector3.new(-100, 3, 20))
advance(0.3)
check(state().Track == "MUS_Hub", "M49 réapparition chez lui : MUS_Hub")
check(not logHas("[MusicController]", "WARN", "client"), "M50 aucun avertissement du contrôleur")

summary("scénario musique")
