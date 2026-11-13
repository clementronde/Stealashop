--!strict
-- Registre « animation + marqueur → son » (DEV-006). Quand une animation passe un marqueur posé
-- par Clément (contrat 2.4 : Impact, Grab, Release, Top, Open, Land), le son inscrit ici est joué
-- sur le personnage ou le modèle animé.
--
-- Les sons définitifs viendront avec DEV-051 (sélection Creator Store) : il suffira de poser un
-- objet Sound du nom indiqué dans le dossier des sons ; jamais d'ID dans le code. Tant qu'un son
-- manque, son marqueur ne joue rien (un avertissement par son, en Studio, au passage du marqueur).
--
-- AnimationController (client) branche MarkerSounds.Player sur le personnage local. GuardService
-- (serveur, plus tard) branchera MarkerSounds.Guard sur chaque vigile, sur son AnimPlayer :
--   for _, entry in MarkerSounds.Guard do
--       anims:OnMarker(entry.Anim, entry.Marker, function()
--           MarkerSounds.play(entry.Sound, guard.PrimaryPart)
--       end)
--   end

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Animations = require(script.Parent.Parent:WaitForChild("Contract"):WaitForChild("Animations"))

export type Entry = { Anim: string, Marker: string, Sound: string }

local MarkerSounds = {}

-- V0 proposé, absent du doc : dossier des objets Sound, chemin depuis ReplicatedStorage (à fixer
-- avec DEV-051 et à écrire dans la liaison). Les sous-dossiers sont permis.
MarkerSounds.Folder = { "Assets", "Sounds" }

-- V0 proposé, absent du doc : durée de vie max (s) d'un son joué, si son Ended ne vient jamais.
local SOUND_MAX_LIFETIME = 10

-- Joueur : les 8 marqueurs du contrat 2.4. Noms de sons V0 proposés, absents du doc, sur le
-- modèle <Animation>_<Marqueur> ; DEV-051 peut faire pointer plusieurs entrées vers le même son.
MarkerSounds.Player = {
	{ Anim = "HitWindow", Marker = "Impact", Sound = "HitWindow_Impact" },
	{ Anim = "HitWindowHeavy", Marker = "Impact", Sound = "HitWindowHeavy_Impact" },
	{ Anim = "Grab", Marker = "Grab", Sound = "Grab_Grab" },
	{ Anim = "Place", Marker = "Release", Sound = "Place_Release" },
	-- BenchLift/Top : plus de son (L-118 point 7, Clément : rien ne sonne à l'entraînement).
	{ Anim = "Unbox", Marker = "Open", Sound = "Unbox_Open" },
	{ Anim = "SwingBat", Marker = "Impact", Sound = "SwingBat_Impact" },
	{ Anim = "Knockback", Marker = "Land", Sound = "Knockback_Land" },
	-- Chute et arrestation (L-076, 2026-11-10) : sons à choisir avec le reste de DEV-051.
	{ Anim = "Knockdown", Marker = "Land", Sound = "Knockdown_Land" },
	{ Anim = "Arrested", Marker = "Grab", Sound = "Arrested_Grab" },
} :: { Entry }

-- Vigiles, de jour comme de nuit (mêmes noms d'animations) : pour GuardService.
MarkerSounds.Guard = {
	{ Anim = "Catch", Marker = "Impact", Sound = "Catch_Impact" },
} :: { Entry }

local IS_STUDIO = RunService:IsStudio()
local warned: { [string]: boolean } = {}

local function folderPath(): string
	return `ReplicatedStorage.{table.concat(MarkerSounds.Folder, ".")}`
end

local function soundsFolder(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in MarkerSounds.Folder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

-- L'objet Sound nommé `name` dans le dossier des sons (sous-dossiers compris), ou nil.
function MarkerSounds.find(name: string): Sound?
	local folder = soundsFolder()
	local inst = if folder then folder:FindFirstChild(name, true) else nil
	if inst and inst:IsA("Sound") then
		return inst :: Sound
	end
	return nil
end

-- Joue une copie de `template` sur `at` (une Part : son 3D ; nil : SoundService, son 2D), puis la
-- supprime à la fin. Renvoie la copie.
function MarkerSounds.playSound(template: Sound, at: Instance?): Sound
	local sound = template:Clone()
	sound.Parent = at or SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, SOUND_MAX_LIFETIME)
	sound:Play()
	return sound
end

-- Joue le son inscrit `name` sur `at`. Un son absent ne fait rien (un avertissement par son, en
-- Studio). Renvoie la copie jouée, ou nil.
function MarkerSounds.play(name: string, at: Instance?): Sound?
	local template = MarkerSounds.find(name)
	if template == nil then
		if IS_STUDIO and not warned[name] then
			warned[name] = true
			warn(`[Anim] son « {name} » absent de {folderPath()} (sons à venir avec DEV-051) : marqueur sans son`)
		end
		return nil
	end
	return MarkerSounds.playSound(template, at)
end

-- En Studio : signale une entrée dont l'animation ou le marqueur ne sont pas au contrat 2.4 (faute
-- de frappe dans ce registre). Renvoie le nombre d'entrées fautives.
function MarkerSounds.check(entries: { Entry }, specs: { Animations.Anim }, label: string): number
	local markerOf: { [string]: string } = {}
	for _, spec in specs do
		local marker = spec.Marker
		if marker then
			markerOf[spec.Name] = marker
		end
	end
	local bad = 0
	for _, entry in entries do
		if markerOf[entry.Anim] ~= entry.Marker then
			bad += 1
			if IS_STUDIO then
				warn(`[Anim] MarkerSounds.{label} : {entry.Anim}/{entry.Marker} n'est pas un marqueur du contrat 2.4`)
			end
		end
	end
	return bad
end

return MarkerSounds
