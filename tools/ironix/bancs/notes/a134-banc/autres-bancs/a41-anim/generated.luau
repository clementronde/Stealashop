SRC = {}
SRC["Contract/Animations"] = [==========[
--!strict
-- Contrat d'animations (doc, section 2.4 ; liaison, section 3.2) : 21 animations, plus l'Idle facultatif des
-- conducteurs du camion (Animations.Driver, L-071).
-- Le code cherche chaque objet Animation par son nom, jamais par un ID.
--
-- Où : joueur dans ReplicatedStorage/Assets/Animations/Player/<Nom> ; modèle animé
-- (vigile, vigile de nuit, vendeur) dans <Modèle>/Animations/<Nom>.
-- Priority = nom d'un Enum.AnimationPriority. Marker = marqueur posé par Clément sur
-- l'image clé concernée, auquel le code accroche sons et effets.

export type Anim = {
	Name: string,
	Loop: boolean,
	Priority: string,
	Marker: string?,
	UpperBodyOnly: boolean?, -- n'anime que le haut du corps
}

local Animations = {}

-- Dossier d'un modèle animé, et chemin du dossier du joueur depuis ReplicatedStorage.
Animations.FolderName = "Animations"
Animations.PlayerFolder = { "Assets", "Animations", "Player" }

-- 14 animations du joueur (15 avant le retrait d'Unbox et de Celebrate, vague 52 ; BenchLift et BenchIdle
-- retirés en v2 ; HoldItem ajoutée en vague 56).
Animations.Player = {
	{ Name = "HitWindow", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "HitWindowHeavy", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Grab", Loop = false, Priority = "Action", Marker = "Grab" },
	{ Name = "CarryIdle", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "CarryRun", Loop = true, Priority = "Action", UpperBodyOnly = true },
	{ Name = "Place", Loop = false, Priority = "Action", Marker = "Release" },
	{ Name = "TreadmillRun", Loop = true, Priority = "Movement" },
	-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de banc. BenchLift (marqueur Top) et BenchIdle sortent du
	-- contrat : le code ne les charge plus ; les objets Animation de Clément peuvent rester dans le dossier.
	-- Vague 52 (a170) : Unbox (marqueur Open) et Celebrate sortent du contrat avec l'ouverture des colis en base
	-- (écran UI_Unbox) : le code ne les joue plus (Animations.Retired).
	{ Name = "SwingBat", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Stunned", Loop = true, Priority = "Action" },
	{ Name = "Knockback", Loop = false, Priority = "Action", Marker = "Land" },
	-- Chute et arrestation (Clément, liaison L-076, livrées le 2026-11-10 ; réglages relevés dans Studio) :
	-- pas encore jouées par le code.
	{ Name = "Knockdown", Loop = false, Priority = "Action", Marker = "Land" },
	{ Name = "GetUp", Loop = false, Priority = "Action" },
	{ Name = "Arrested", Loop = false, Priority = "Action", Marker = "Grab" },
	-- Vague 56 (a181, L-162, Clément) : objet Big, Huge ou Colossal tenu à deux mains (HeldItemService), haut du
	-- corps seulement. Pas encore livrée : orange au ContractChecker, la pose « outil » de Roblox reste.
	{ Name = "HoldItem", Loop = true, Priority = "Action", UpperBodyOnly = true },
} :: { Anim }

-- 5 animations dans chaque modèle de vigile, de jour comme de nuit (mêmes noms).
Animations.Guard = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Run", Loop = true, Priority = "Movement" },
	{ Name = "Catch", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Tired", Loop = false, Priority = "Action" },
} :: { Anim }

-- Vigile de nuit (modèle NightGuard) : celles des vigiles, plus Arrest (L-076, livrée le 2026-11-10 ;
-- pas encore jouée par le code).
Animations.NightGuard = table.clone(Animations.Guard)
table.insert(Animations.NightGuard, { Name = "Arrest", Loop = false, Priority = "Action", Marker = "Grab" })

-- 2 animations dans chaque vendeur (Vendor_* des comptoirs du hub). Jouées par VendorService (vague 39) :
-- Idle en boucle, Wave quand un joueur approche (Config/Vendors).
Animations.Vendor = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Wave", Loop = false, Priority = "Action" },
} :: { Anim }

-- Témoins NPC_Witness_Z<n>_0<k> (Clément, liaison L-111, publiées le 2026-11-12 ; réglages relevés dans Studio) :
-- pas encore jouées par le code. CallPolice revient en boucle, le code ne réagira qu'au premier marqueur Call.
Animations.Witness = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Look", Loop = true, Priority = "Action" },
	{ Name = "CallPolice", Loop = true, Priority = "Action", Marker = "Call" },
	-- L-118 point 10 (Clément, en cours) : course paniquée à la casse. Boucle et priorité V0, comme Run des vigiles.
	{ Name = "Flee", Loop = true, Priority = "Movement" },
	-- L-172 (Clément, 2026-11-15, pas encore publiée : orange tant qu'elle manque) : photos au flash après l'appel ;
	-- à chaque marqueur Flash, WitnessService fait partir le flash de FX_Witness_Flash. Sans elle, le témoin garde
	-- sa pose et le flash part toutes les Witness.Photo.Interval s.
	{ Name = "TakePhoto", Loop = true, Priority = "Action", Marker = "Flash" },
} :: { Anim }

-- Conducteurs du camion de l'événement (liaison L-071, point 7 ; a42) : des modèles avec un Humanoid,
-- rangés par Clément dans ENV_Event_Truck. Idle, jouée en boucle par TruckEventService tant que le
-- camion est là ; sans elle, le conducteur reste immobile. Walk, Run et Catch (livrées par Clément le
-- 2026-11-10, liaison L-083 point 3) : pour la poursuite des conducteurs à la fin du chrono du camion
-- (GuardService.StartDriverChase : Run en poursuite, Catch et son marqueur Impact à la capture ; Walk
-- n'est pas jouée en V0) ; mêmes réglages que les vigiles.
Animations.Driver = {
	{ Name = "Idle", Loop = true, Priority = "Idle" },
	{ Name = "Walk", Loop = true, Priority = "Movement" },
	{ Name = "Run", Loop = true, Priority = "Movement" },
	{ Name = "Catch", Loop = false, Priority = "Action", Marker = "Impact" },
} :: { Anim }

-- Animations du joueur sorties du contrat : le code ne les lit plus. Laissées dans le dossier de Clément, le
-- ContractChecker les signale en note, pas en problème ; il peut les retirer quand il veut (liaison L-157).
Animations.Retired = {
	BenchLift = "banc retiré du jeu (rééquilibrage v2, 2026-11-14)",
	BenchIdle = "banc retiré du jeu (rééquilibrage v2, 2026-11-14)",
	Unbox = "ouverture des colis en base retirée (fin du colis porté, 2026-11-15)",
	Celebrate = "ouverture des colis en base retirée (fin du colis porté, 2026-11-15)",
} :: { [string]: string }

-- Vague 62 (a204, L-198 ; noms proposés à Clément, tous facultatifs) : la cinématique d'ouverture d'un colis, jouée
-- par RevealController sur une copie locale du rig de caméra ReplicatedStorage/Assets/Cinematics/CAM_Reveal (un
-- AnimationController et son Animator, les pièces CameraPart et ItemAnchor, son dossier Animations ; Config/Reveal).
-- D'abord Open<Rareté> (une par Id de Config/Rarities : OpenCommon … OpenSecret, OpenDivine ; une rareté ajoutée =
-- une ligne ici), puis Grow<Classe>
-- (classe de taille du serveur). Marqueurs, chacun sur son image clé : Open (le colis s'ouvre), Reveal (l'objet
-- apparaît), Grow et Top (début et fin de la croissance : le code agrandit l'objet entre les deux), Explode (le plafond
-- saute : GrowLarge et GrowColossal), Land (fin). Un marqueur absent tombe à la fin de son animation (Explode : à Top) ;
-- une animation absente = repli codé, mêmes étapes. La caméra est animée pour un objet de taille 1 : le code multiplie
-- l'écart CameraPart ↔ ItemAnchor par la taille de l'objet. Priorité Action, sans boucle.
Animations.RigPath = { "Assets", "Cinematics", "CAM_Reveal" }
Animations.RevealMarkers = { "Open", "Reveal", "Grow", "Top", "Explode", "Land" }
Animations.Reveal = {
	{ Name = "OpenCommon", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenUncommon", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenRare", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenEpic", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenLegendary", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenMythic", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenSecret", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "OpenDivine", Loop = false, Priority = "Action", Marker = "Reveal" },
	{ Name = "GrowSmall", Loop = false, Priority = "Action", Marker = "Land" },
	{ Name = "GrowLarge", Loop = false, Priority = "Action", Marker = "Explode" },
	{ Name = "GrowColossal", Loop = false, Priority = "Action", Marker = "Explode" },
} :: { Anim }

return Animations

]==========]
SRC["Anim/AnimPlayer"] = [==========[
--!strict
-- AnimPlayer (DEV-006) : joue les animations d'un Animator par leur nom. Commun au client
-- (personnage du joueur : AnimationController) et au serveur (vigiles et vendeurs : GuardService).
--
-- Contrat (doc, section 2.4 ; liaison, section 3.2) : le code cherche l'objet Animation par son
-- nom dans un dossier `Animations`, jamais par un ID écrit dans le code. Clément règle la
-- priorité, la boucle et les marqueurs dans l'éditeur : ce module ne les retouche pas (le
-- ContractChecker les vérifie). Noms attendus : Shared/Contract/Animations.
--
--   local anims = AnimPlayer.new(animator, AnimPlayer.modelFolder(guard), Animations.Guard, "Vigile")
--   anims:LoadAll()               -- facultatif : charge tout de suite les pistes livrées
--   anims:Play("Run")             -- sinon, piste chargée au premier besoin ; puis gardée en cache
--   anims:AdjustSpeed("Run", 1.3) -- vitesse de lecture d'une piste en cours (rien si elle ne joue pas)
--   local off = anims:OnMarker("Catch", "Impact", function(param) ... end)
--   anims:Stop("Run") ; anims:StopAll() ; off()
--   anims:Destroy()               -- appelé tout seul si l'Animator est détruit
--
-- Un nom absent, un objet qui n'est pas une Animation ou un AnimationId vide ne font rien, sans
-- erreur : un seul avertissement par nom, en Studio seulement, au premier Play.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(script.Parent.Parent:WaitForChild("Contract"):WaitForChild("Animations"))

type Anim = Animations.Anim

-- Un branchement sur un marqueur, gardé même tant que l'animation n'est pas chargée.
type Sub = {
	anim: string,
	marker: string,
	callback: (param: string) -> (),
	connection: RBXScriptConnection?,
}

type Fields = {
	animator: Animator,
	folder: Instance?,
	label: string,
	specs: { [string]: Anim },
	tracks: { [string]: AnimationTrack },
	subs: { Sub },
	destroyed: boolean,
	destroying: RBXScriptConnection?,
}

local AnimPlayer = {}
AnimPlayer.__index = AnimPlayer

export type AnimPlayer = typeof(setmetatable({} :: Fields, AnimPlayer))

local IS_STUDIO = RunService:IsStudio()
local WAIT_TIMEOUT = 10 -- V0 proposé, absent du doc : attente max (s) du Humanoid et de l'Animator

local warned: { [string]: boolean } = {}

-- Avertit une seule fois par clé, et seulement en Studio.
local function warnOnce(key: string, message: string)
	if not IS_STUDIO or warned[key] then
		return
	end
	warned[key] = true
	warn(`[Anim] {message}`)
end

-- Un AnimationId est vide s'il n'a rien après son préfixe ("", "rbxassetid://", "…?id=").
local function isEmptyId(id: string): boolean
	local tail = string.match(id, "[^/=]*$") or ""
	return string.match(tail, "%w") == nil
end

-- L'objet Animation nommé `name` dans `folder`, prêt à charger ; sinon nil et la raison.
function AnimPlayer.findAnimation(folder: Instance?, name: string): (Animation?, string?)
	if folder == nil then
		return nil, "dossier Animations absent (pas encore livré)"
	end
	local inst = folder:FindFirstChild(name)
	if inst == nil then
		return nil, `{folder:GetFullName()}.{name} absent (pas encore livrée)`
	end
	if not inst:IsA("Animation") then
		return nil, `{inst:GetFullName()} est un {inst.ClassName}, pas un objet Animation`
	end
	local animation = inst :: Animation
	if isEmptyId(animation.AnimationId) then
		return nil, `{animation:GetFullName()} : AnimationId vide`
	end
	return animation, nil
end

-- Le dossier des animations du joueur (contrat : ReplicatedStorage/Assets/Animations/Player), ou nil.
function AnimPlayer.playerFolder(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in Animations.PlayerFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

-- Le dossier Animations d'un modèle animé (vigile, vigile de nuit, vendeur), ou nil.
function AnimPlayer.modelFolder(model: Instance): Instance?
	return model:FindFirstChild(Animations.FolderName)
end

-- L'Animator du Humanoid de `model`, une fois le modèle dans le jeu (LoadAnimation l'exige).
-- Attend au plus `timeout` secondes. Ne crée jamais d'Animator : côté client, un Animator créé
-- localement ne réplique pas les animations du personnage.
function AnimPlayer.waitForAnimator(model: Instance, timeout: number?): Animator?
	local deadline = os.clock() + (timeout or WAIT_TIMEOUT)
	while not model:IsDescendantOf(game) do
		if os.clock() >= deadline then
			return nil
		end
		task.wait()
	end
	local humanoid: Instance? = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil and os.clock() < deadline then
		humanoid = model:WaitForChild("Humanoid", deadline - os.clock())
	end
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return nil
	end
	local animator: Instance? = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil and os.clock() < deadline then
		animator = humanoid:WaitForChild("Animator", deadline - os.clock())
	end
	if animator == nil or not animator:IsA("Animator") then
		return nil
	end
	return animator :: Animator
end

-- `animator` : l'Animator du modèle animé. `folder` : son dossier d'objets Animation (nil s'il
-- n'est pas encore livré : rien ne se joue). `specs` : la liste du contrat (Animations.Player,
-- .Guard ou .Vendor), qui dit lesquelles bouclent et lesquelles précharger. `label` : nom court
-- pour les avertissements (« Joueur », « Vigile »…).
function AnimPlayer.new(animator: Animator, folder: Instance?, specs: { Anim }?, label: string?): AnimPlayer
	local byName: { [string]: Anim } = {}
	for _, spec in specs or {} do
		byName[spec.Name] = spec
	end
	local fields: Fields = {
		animator = animator,
		folder = folder,
		label = label or animator:GetFullName(),
		specs = byName,
		tracks = {},
		subs = {},
		destroyed = false,
		destroying = nil,
	}
	local self = setmetatable(fields, AnimPlayer)
	fields.destroying = animator.Destroying:Connect(function()
		self:Destroy()
	end)
	return self
end

local function connectSub(track: AnimationTrack, sub: Sub)
	sub.connection = track:GetMarkerReachedSignal(sub.marker):Connect(sub.callback)
end

-- La piste de `name`, chargée au premier besoin puis gardée en cache. Un manque est signalé une
-- fois (en Studio) si `warnIfMissing`.
local function load(self: AnimPlayer, name: string, warnIfMissing: boolean): AnimationTrack?
	if self.destroyed then
		return nil
	end
	local cached = self.tracks[name]
	if cached then
		return cached
	end
	local animation, why = AnimPlayer.findAnimation(self.folder, name)
	if animation == nil then
		if warnIfMissing then
			warnOnce(`{self.label}:{name}`, `{self.label} : « {name} » non jouée : {why}`)
		end
		return nil
	end
	local found: Animation = animation
	local animator = self.animator
	local ok, result = pcall(function(): AnimationTrack
		return animator:LoadAnimation(found)
	end)
	if not ok then
		warnOnce(`{self.label}:{name}:load`, `{self.label} : « {name} » non chargée : {result}`)
		return nil
	end
	local track = result :: AnimationTrack
	self.tracks[name] = track
	for _, sub in self.subs do
		if sub.anim == name and sub.connection == nil then
			connectSub(track, sub)
		end
	end
	return track
end

-- Une animation boucle-t-elle ? Le contrat le dit ; hors contrat, la piste chargée.
local function isLooped(self: AnimPlayer, name: string, track: AnimationTrack): boolean
	local spec = self.specs[name]
	if spec then
		return spec.Loop
	end
	return track.Looped
end

-- Joue `name` (fondu `fadeTime`, sinon celui de Roblox). Une animation en boucle déjà en cours
-- continue ; une animation sans boucle déjà en cours repart du début. Renvoie la piste, ou nil
-- si l'animation manque.
function AnimPlayer.Play(
	self: AnimPlayer,
	name: string,
	fadeTime: number?,
	weight: number?,
	speed: number?
): AnimationTrack?
	local track = load(self, name, true)
	if track == nil then
		return nil
	end
	if track.IsPlaying then
		if not isLooped(self, name, track) then
			track.TimePosition = 0
		end
		if weight then
			track:AdjustWeight(weight, fadeTime)
		end
		if speed then
			track:AdjustSpeed(speed)
		end
		return track
	end
	track:Play(fadeTime, weight, speed)
	return track
end

-- Arrête `name` si elle joue (fondu `fadeTime`). Ne charge rien.
function AnimPlayer.Stop(self: AnimPlayer, name: string, fadeTime: number?)
	local track = self.tracks[name]
	if track and track.IsPlaying then
		track:Stop(fadeTime)
	end
end

-- Arrête les animations jouées par cet AnimPlayer (pas celles du script Animate de Roblox).
function AnimPlayer.StopAll(self: AnimPlayer, fadeTime: number?)
	for _, track in self.tracks do
		if track.IsPlaying then
			track:Stop(fadeTime)
		end
	end
end

-- Change la vitesse de lecture de `name` si elle joue déjà (AnimationTrack:AdjustSpeed), sans la
-- relancer ni rien charger : pour une boucle dont le rythme suit une vitesse qui change en cours
-- de route (Run et Walk des vigiles). Renvoie true si une piste a été réglée.
function AnimPlayer.AdjustSpeed(self: AnimPlayer, name: string, speed: number): boolean
	local track = self.tracks[name]
	if track and track.IsPlaying then
		track:AdjustSpeed(speed)
		return true
	end
	return false
end

function AnimPlayer.IsPlaying(self: AnimPlayer, name: string): boolean
	local track = self.tracks[name]
	return track ~= nil and track.IsPlaying
end

-- La piste de `name` (chargée si besoin), sans la jouer ; nil si l'animation manque.
function AnimPlayer.GetTrack(self: AnimPlayer, name: string): AnimationTrack?
	return load(self, name, false)
end

-- Les noms que cet AnimPlayer sert : ceux du contrat, ou tous les objets Animation du dossier.
local function namesOf(self: AnimPlayer): { string }
	local names: { string } = {}
	local folder = self.folder
	if next(self.specs) ~= nil then
		for name in self.specs do
			table.insert(names, name)
		end
	elseif folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Animation") then
				table.insert(names, child.Name)
			end
		end
	end
	return names
end

-- Charge tout de suite les pistes de toutes les animations livrées (sans avertir pour les
-- manquantes), au lieu d'attendre leur premier Play. Renvoie le nombre de pistes prêtes.
function AnimPlayer.LoadAll(self: AnimPlayer): number
	local count = 0
	for _, name in namesOf(self) do
		if load(self, name, false) then
			count += 1
		end
	end
	return count
end

-- Appelle `callback(param)` à chaque passage du marqueur `marker` de l'animation `name` (posé
-- par Clément sur l'image clé ; `param` = sa valeur). Renvoie une fonction qui débranche. Si
-- l'animation manque encore, le branchement se fait à son premier chargement.
function AnimPlayer.OnMarker(
	self: AnimPlayer,
	name: string,
	marker: string,
	callback: (param: string) -> ()
): () -> ()
	if self.destroyed then
		return function() end
	end
	local sub: Sub = { anim = name, marker = marker, callback = callback, connection = nil }
	table.insert(self.subs, sub)
	local track = load(self, name, false)
	if track and sub.connection == nil then
		connectSub(track, sub)
	end
	return function()
		local connection = sub.connection
		if connection then
			connection:Disconnect()
			sub.connection = nil
		end
		local index = table.find(self.subs, sub)
		if index then
			table.remove(self.subs, index)
		end
	end
end

-- Précharge (ContentProvider:PreloadAsync) les animations `names` de `folder`, ou tous ses objets
-- Animation si `names` est nil, pour que le premier Play soit immédiat. Client seulement : ne
-- fait rien côté serveur. Attend la fin du téléchargement, donc à appeler dans une tâche.
-- Renvoie le nombre d'animations préchargées sans erreur.
function AnimPlayer.preload(folder: Instance?, names: { string }?): number
	if folder == nil or not RunService:IsClient() then
		return 0
	end
	local path = folder:GetFullName()
	local list: { Instance } = {}
	local nameOf: { [string]: string } = {}
	local function add(animation: Animation)
		table.insert(list, animation)
		nameOf[animation.AnimationId] = animation.Name
	end
	if names then
		for _, name in names do
			local animation = AnimPlayer.findAnimation(folder, name)
			if animation then
				add(animation)
			end
		end
	else
		for _, child in folder:GetChildren() do
			if child:IsA("Animation") and not isEmptyId((child :: Animation).AnimationId) then
				add(child :: Animation)
			end
		end
	end
	if #list == 0 then
		return 0
	end
	local failed: { string } = {}
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(failed, nameOf[contentId] or contentId)
			end
		end)
	end)
	if not ok then
		warnOnce(`preload:{path}`, `préchargement de {path} impossible : {err}`)
		return 0
	end
	if #failed > 0 then
		warnOnce(
			`preload-failed:{path}`,
			`{path} : chargement refusé pour {table.concat(failed, ", ")} (ID faux, ou animation publiée hors du groupe du studio ?)`
		)
	end
	return #list - #failed
end

-- Précharge les animations du contrat de cet AnimPlayer (tout son dossier s'il n'a pas de contrat).
function AnimPlayer.Preload(self: AnimPlayer): number
	return AnimPlayer.preload(self.folder, namesOf(self))
end

-- Débranche les marqueurs et arrête les animations de cet AnimPlayer. Appelé tout seul quand
-- l'Animator est détruit ; sans effet la deuxième fois.
function AnimPlayer.Destroy(self: AnimPlayer)
	if self.destroyed then
		return
	end
	self.destroyed = true
	local destroying = self.destroying
	if destroying then
		destroying:Disconnect()
		self.destroying = nil
	end
	for _, sub in self.subs do
		local connection = sub.connection
		if connection then
			connection:Disconnect()
			sub.connection = nil
		end
	end
	table.clear(self.subs)
	for _, track in self.tracks do
		pcall(function()
			track:Stop(0)
		end)
	end
	table.clear(self.tracks)
end

return AnimPlayer

]==========]
SRC["Anim/MarkerSounds"] = [==========[
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
	-- Unbox/Open : retiré avec l'animation (vague 52, a170) ; le son Unbox_Open reste (ShelfOpenController).
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

]==========]
SRC["Anim/AnimTest"] = [==========[
--!strict
-- Mode test Studio de DEV-006. Fini quand (doc, 2.4) : « l'animation test se lance et son
-- marqueur déclenche un son ». Démarré par AnimationController ; ne fait rien hors de Studio.
--
-- Lancer, dans la barre de commande de Studio (en Edit avant Play, ou pendant le test côté
-- serveur) :
--   workspace:SetAttribute("AnimTest", true)         -- animation « Test », marqueur « Test »
--   workspace:SetAttribute("AnimTest", "BenchLift")  -- ou une animation livrée du joueur, avec
--                                                    -- le marqueur du contrat 2.4
-- Arrêter et nettoyer (en Edit, après le test) : workspace:SetAttribute("AnimTest", nil)
--
-- Déroulé : 3 lectures sur le personnage local ; à chaque passage du marqueur, un son de test est
-- joué sur le personnage. Tout s'écrit dans la sortie (filtre « [Anim test] ») et finit par une
-- ligne « OK » ou « ÉCHEC ». Relancer : changer l'attribut, ou réapparaître.
--
-- Animation : l'objet de ce nom dans ReplicatedStorage/Assets/Animations/Player. Pour « Test »,
-- c'est l'animation test de Clément (ANI-001 ; étape A1 de son parcours : publiée au nom du
-- groupe, avec un marqueur « Test »). Tant qu'elle n'est pas livrée, une animation de
-- remplacement est fabriquée en code : le bras droit se lève puis redescend en 0,8 s, marqueur
-- « Test » au sommet (KeyframeSequenceProvider:RegisterKeyframeSequence, Studio seulement).
-- Son : l'objet Sound « Test » du dossier des sons (Shared/Anim/MarkerSounds) s'il existe, sinon
-- un son livré avec Roblox (fichier local du client, aucun asset publié).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimPlayer = require(script.Parent:WaitForChild("AnimPlayer"))
local MarkerSounds = require(script.Parent:WaitForChild("MarkerSounds"))
local Animations = require(script.Parent.Parent:WaitForChild("Contract"):WaitForChild("Animations"))

local AnimTest = {}

local ATTRIBUTE = "AnimTest" -- attribut du Workspace qui lance le test
local TEST_NAME = "Test" -- animation test de Clément (ANI-001)
local TEST_MARKER = "Test" -- marqueur posé dans l'animation test
local PLAYS = 3 -- lectures par test
local PAUSE = 1 -- secondes entre deux lectures
local PLAY_TIMEOUT = 6 -- secondes d'attente au plus d'une lecture (une boucle ne finit jamais)
local SOUND_TIMEOUT = 3 -- secondes d'attente au plus du chargement d'un son
local FALLBACK_SOUND = "rbxasset://sounds/volume_slider.ogg" -- livré avec Roblox (content/sounds)

local generation = 0 -- change à chaque relance : le test en cours s'arrête

local function say(message: string)
	print(`[Anim test] {message}`)
end

-- Un échec s'écrit en orange, pour se voir dans la sortie.
local function fail(message: string)
	warn(`[Anim test] ÉCHEC : {message}`)
end

-- Une image clé de l'animation de remplacement : la chaîne de poses R15 jusqu'à l'épaule droite.
local function addKeyframe(sequence: KeyframeSequence, time: number, armDegrees: number): Keyframe
	local frame = Instance.new("Keyframe")
	frame.Time = time
	local root = Instance.new("Pose")
	root.Name = "HumanoidRootPart"
	local lower = Instance.new("Pose")
	lower.Name = "LowerTorso"
	lower.Parent = root
	local upper = Instance.new("Pose")
	upper.Name = "UpperTorso"
	upper.Parent = lower
	local arm = Instance.new("Pose")
	arm.Name = "RightUpperArm"
	arm.CFrame = CFrame.Angles(0, 0, math.rad(armDegrees))
	arm.Parent = upper
	root.Parent = frame
	frame.Parent = sequence
	return frame
end

-- Fabrique l'animation de remplacement « Test ». Renvoie un dossier hors de la place qui la
-- contient, ou nil et la raison.
local function buildStandIn(): (Instance?, string?)
	local ok, result = pcall(function(): Instance
		local sequence = Instance.new("KeyframeSequence")
		sequence.Name = TEST_NAME
		sequence.Loop = false
		sequence.Priority = Enum.AnimationPriority.Action
		addKeyframe(sequence, 0, 0)
		local top = addKeyframe(sequence, 0.4, 150)
		addKeyframe(sequence, 0.8, 0)
		local marker = Instance.new("KeyframeMarker")
		marker.Name = TEST_MARKER
		marker.Value = "remplacement"
		top:AddMarker(marker)

		local folder = Instance.new("Folder")
		folder.Name = Animations.FolderName
		local animation = Instance.new("Animation")
		animation.Name = TEST_NAME
		local provider = game:GetService("KeyframeSequenceProvider")
		animation.AnimationId = provider:RegisterKeyframeSequence(sequence)
		animation.Parent = folder
		return folder
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

-- Le son de test : l'objet Sound « Test » du dossier des sons, sinon un son livré avec Roblox.
local function testSound(): (Sound, string)
	local found = MarkerSounds.find(TEST_NAME)
	if found then
		return found, found:GetFullName()
	end
	local sound = Instance.new("Sound")
	sound.Name = "AnimTestSound"
	sound.SoundId = FALLBACK_SOUND
	return sound, `son livré avec Roblox ({FALLBACK_SOUND})`
end

-- Vrai si le son se charge (durée connue) en SOUND_TIMEOUT secondes au plus.
local function waitLoaded(sound: Sound): boolean
	local deadline = os.clock() + SOUND_TIMEOUT
	while not sound.IsLoaded and os.clock() < deadline do
		task.wait(0.05)
	end
	return sound.IsLoaded and sound.TimeLength > 0
end

-- Le marqueur attendu : « Test » pour l'animation test, sinon celui du contrat 2.4 (ou aucun).
local function markerOf(animName: string): string?
	if animName == TEST_NAME then
		return TEST_MARKER
	end
	for _, spec in Animations.Player do
		if spec.Name == animName then
			return spec.Marker
		end
	end
	return nil
end

local function run(token: number, character: Model, animName: string)
	local animator = AnimPlayer.waitForAnimator(character)
	if token ~= generation then
		return
	end
	if animator == nil then
		fail("pas d'Animator dans le Humanoid du personnage")
		return
	end

	local folder = AnimPlayer.playerFolder()
	local animation, why = AnimPlayer.findAnimation(folder, animName)
	local source = ""
	if animation then
		source = `livrée, {animation:GetFullName()}`
		AnimPlayer.preload(folder, { animName })
	elseif animName == TEST_NAME then
		local standIn, err = buildStandIn()
		if standIn == nil then
			fail(
				`l'animation test n'est pas livrée ({why}) et Studio refuse l'animation de remplacement ({err}). Il faut l'animation « Test » de Clément (ANI-001), avec un marqueur « Test »`
			)
			return
		end
		folder = standIn
		source = "de remplacement, fabriquée en code (l'animation « Test » de Clément, ANI-001, n'est pas encore livrée)"
	else
		fail(`« {animName} » introuvable : {why}`)
		return
	end
	if token ~= generation then
		return
	end

	local marker = markerOf(animName)
	local template, soundSource = testSound()
	local anims = AnimPlayer.new(animator, folder, Animations.Player, "Test")
	local hits, loaded, pending = 0, 0, 0
	local soundLength = 0
	local off: (() -> ())? = nil
	if marker then
		local markerName: string = marker
		off = anims:OnMarker(animName, markerName, function(param: string)
			hits += 1
			local sound = MarkerSounds.playSound(template, character:FindFirstChild("HumanoidRootPart"))
			say(`marqueur « {markerName} » atteint (valeur « {param} ») : son de test lancé`)
			pending += 1
			task.spawn(function()
				if waitLoaded(sound) then
					loaded += 1
					soundLength = sound.TimeLength
				end
				pending -= 1
			end)
		end)
	end

	say(`animation « {animName} » : {source}`)
	say(`son : {soundSource}`)
	local played = 0
	local trackLength = 0
	for i = 1, PLAYS do
		if token ~= generation or not character:IsDescendantOf(Workspace) then
			break
		end
		local track = anims:Play(animName)
		if track == nil then
			break
		end
		played += 1
		local stopped = false
		local connection = track.Stopped:Once(function()
			stopped = true
		end)
		local deadline = os.clock() + PLAY_TIMEOUT
		while not stopped and os.clock() < deadline and token == generation do
			task.wait(0.1)
		end
		connection:Disconnect()
		trackLength = math.max(trackLength, track.Length)
		say(`lecture {i}/{PLAYS} finie (durée de la piste {string.format("%.2f", track.Length)} s)`)
		task.wait(PAUSE)
	end
	local deadline = os.clock() + SOUND_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if off then
		off()
	end
	anims:Destroy()

	if token ~= generation then
		say("interrompu (attribut changé ou personnage réapparu)")
	elseif played == 0 then
		fail(`« {animName} » ne se lance pas (voir la ligne [Anim] plus haut)`)
	elseif trackLength == 0 and hits == 0 then
		fail(
			`« {animName} » lancée mais jamais chargée (durée 0 s) : ID illisible ou animation publiée hors du groupe ; si c'est l'animation de remplacement, Studio ne la joue pas et il faut l'animation « Test » de Clément (ANI-001)`
		)
	elseif marker == nil then
		say(`fini : « {animName} » lancée {played} fois ; pas de marqueur au contrat 2.4, aucun son attendu`)
	elseif hits == 0 then
		fail(
			`« {animName} » lancée {played} fois, mais le marqueur « {marker} » n'a jamais été atteint (absent de l'animation, mal nommé, ou nom d'image clé au lieu d'un marqueur ?)`
		)
	elseif loaded == 0 then
		fail(`marqueur « {marker} » atteint {hits} fois, mais le son de test ne s'est pas chargé ({soundSource})`)
	else
		say(
			`OK : « {animName} » lancée {played} fois, marqueur « {marker} » atteint {hits} fois, son joué {loaded} fois (durée {string.format("%.2f", soundLength)} s)`
		)
	end
end

-- Écoute l'attribut AnimTest du Workspace et relance le test à chaque changement et à chaque
-- apparition du personnage. Client, Studio seulement.
function AnimTest.start()
	if not RunService:IsStudio() or not RunService:IsClient() then
		return
	end
	local player = Players.LocalPlayer
	local function relaunch()
		generation += 1
		local token = generation
		local value = Workspace:GetAttribute(ATTRIBUTE)
		local name: string? = nil
		if value == true then
			name = TEST_NAME
		elseif type(value) == "string" and value ~= "" then
			name = value
		end
		if name == nil then
			return
		end
		local character = player.Character
		if character == nil then
			say(`« {name} » : en attente du personnage`)
			return
		end
		say(`lancé pour « {name} » (attribut {ATTRIBUTE} du Workspace)`)
		task.spawn(run, token, character, name)
	end
	Workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(relaunch)
	player.CharacterAdded:Connect(relaunch)
	relaunch()
end

return AnimTest

]==========]
SRC["Config/DeepFreeze"] = [==========[
--!strict
-- Gel en profondeur d'une table de configuration (DEV-002, Config).
-- Chaque module de Config renvoie sa table passée par cette fonction : toute
-- écriture, même dans une sous-table, lève une erreur au lieu de changer une
-- valeur de jeu en douce.

local function deepFreeze<T>(value: T): T
	local t = value :: any
	if type(t) == "table" and not table.isfrozen(t) then
		for _, child in t do
			deepFreeze(child)
		end
		table.freeze(t)
	end
	return value
end

return deepFreeze

]==========]
SRC["Config/Balance"] = [==========[
--!strict
-- Constantes d'équilibrage générales (Partie 1, sections 5.1 à 5.8, 6.2, 9.4, 9.6, 9.7).
-- Durées en secondes, distances en studs, vitesses en WalkSpeed, fractions
-- entre 0 et 1 (0.03 = 3 %). Les valeurs propres à un domaine vivent dans
-- leur module : Training, Night, Bat, PvP, Tutorial, Upgrades.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type BoxTier = "Standard" | "Premium" | "Luxe"

export type BoxTierInfo = {
	DisplayName: string, -- nom affiché, en anglais (L-036) ; la clé reste le Tier (Luxe)
	Look: string, -- aspect sur le rayon, avant la révélation de la rareté (7.3) ; description, jamais affichée
	Count: number, -- colis de ce type par magasin (5.3)
	GrabTime: number, -- durée de maintien pour le prendre (5.3)
}

local TIER_ORDER: { BoxTier } = { "Standard", "Premium", "Luxe" }

-- Clé = BoxTier (valeur de l'attribut `Tier` des ShelfSlot, 10.4)
local BOX_TIERS: { [string]: BoxTierInfo } = {
	Standard = { DisplayName = "Standard", Look = "Carton brun", Count = 6, GrabTime = 0.3 },
	Premium = { DisplayName = "Premium", Look = "Carton bleu scellé", Count = 3, GrabTime = 0.6 },
	Luxe = { DisplayName = "Luxury", Look = "Caisse en bois cerclée d'or", Count = 1, GrabTime = 1.0 },
}

-- Vague 61 (a198, Cantin : « x2 la vitesse réelle par rapport à la fausse vitesse écrite en bas à gauche ») :
-- facteur unique de la vitesse RÉELLE (studs/s). La Speed affichée (HUD, panneaux, seuils des zones) ne change
-- pas ; la marche du joueur (Formulas.WalkSpeed, base et plafond compris : 16 → 32, 70 → 140) et tout ce qui court
-- contre lui (vigiles, vigiles de nuit, policier, conducteur du camion, bot, porteur, anti-triche) en sont
-- multipliés, chacun dans son Config (Zones, Chase, Night, Bot, TruckEvent, AntiCheat) ou, pour la vitesse imposée
-- par le tutoriel (Tutorial.GuardSpeed, à l'échelle 1), dans GuardService et WitnessService. Les distances et les
-- durées ne changent pas. 1 = tout comme avant. V0.
local REAL_SPEED_SCALE = 2

local Balance = {
	-- Rééquilibrage v2 (Cantin, 2026-11-14 ; docs/claude/notes/equilibrage-v2-proposition.md, section 3) :
	--   Speed affichée = Vitesse entraînée × M trail
	--   WalkSpeed      = min(70, 16 + 4 × log10(1 + Speed affichée / 100)) : « un zéro de plus = +4 de marche »
	--   Plus de banc ni de Force : dégâts d'un coup = P arme × M aura (× potion de force). Formulas.
	--   Ces nombres sont à l'échelle 1 : marche réelle = RealSpeedScale × la formule (32 au départ, 140 au plus).
	Stats = {
		RealSpeedScale = REAL_SPEED_SCALE, -- vague 61, voir plus haut (V0)
		BaseWalkSpeed = 16, -- à l'échelle 1
		MaxWalkSpeed = 70, -- à l'échelle 1 (plafond réel : 70 × RealSpeedScale) ; une sécurité : Speed 3,2Qa
		WalkPerDecade = 4, -- V0 proposé (note v2) : WalkSpeed gagné chaque fois que la Speed affichée est multipliée par 10
		SpeedScale = 100, -- V0 proposé (note v2) : Speed affichée à partir de laquelle la marche commence à monter
	},

	-- 5.2 : slot 1 = outil de casse équipé, slot 2 = batte
	Hotbar = {
		ToolSlot = 1,
		BatSlot = 2,
	},

	-- 5.2 et 9.4 : un tap = un coup
	Hit = {
		Range = 8, -- portée d'un coup (5.2)
		ServerMaxDistance = 10, -- distance acceptée par le serveur pour HitWindow (9.4)
		-- Plafond du serveur, pour tout le monde et pour toutes les cibles (vitrines, portes, camion, tour) :
		-- 5 coups par seconde (Cantin, 2026-11-14 ; avant : 10). C'est aussi le débit du remote HitWindow
		-- (Net/Definitions) et la cadence du client (HitController). Les PV des vitrines en dépendent (Zones).
		MaxHitsPerSecond = 5,
	},

	-- 5.3, 5.4, 9.4, 9.7 : vitrines PNJ et joueurs (WindowService)
	Window = {
		RegenPerSecond = 0.03, -- fraction des PV max régénérée chaque seconde
		-- Chrono de casse (Clément, liaison L-074, 2026-11-10 ; V0 à tester) : au premier coup sur une
		-- vitrine de magasin PNJ, il faut la casser en BreakTimer s, sinon elle revient à ses PV max.
		BreakTimer = 8, -- chrono de police (Cantin, 2026-11-14, passe 3 du rééquilibrage v2 ; avant : 13)
		CrackThresholds = { 0.75, 0.5, 0.25 }, -- fissures visibles à ces fractions des PV
		RebuildDelay = 20, -- reconstruction après la fermeture du rideau
		HPSyncHz = 10, -- WindowHP envoyé en non fiable, 10 fois par seconde au plus
	},

	-- PV des vitrines des magasins PNJ (rééquilibrage v2, passe 3 du 2026-11-14 : chrono de police de 8 s ;
	-- V0 proposés, note equilibrage-v2-proposition.md, « Passe 3 du 14/11 (8 s) »). LES TROIS NOMBRES À
	-- REMPLACER quand la règle change (chrono de police, temps de casse) : Config/Zones en déduit tous les PV,
	-- rien d'autre à toucher.
	--   PV = dégâts du panneau (arme × aura du kit de la zone) × joueurs × temps × Hit.MaxHitsPerSecond
	--        / (1 + Window.RegenPerSecond × temps)
	--   zones 1 à 5 : 1 joueur, SoloBreakTime        → 27,197 × dégâts (27, 272, 3 264, 40 795, 543 933)
	--   dernière zone : LastZoneTeamSize joueurs, LastZoneBreakTime → 54,393 × dégâts (108 786 611)
	--   (passe 2, chrono de 13 s : 11 s partout, soit 41,35 et 82,7 × dégâts : 41, 414, 4 962, 62 030, 827 068, 165.4M)
	-- À garder vrai : un joueur seul au panneau ne casse pas la dernière zone dans le chrono de police
	-- (Window.BreakTimer, 8 s en passe 3), même avec la potion de force : 16,2 s seul, 9,3 s avec la potion.
	WindowHP = {
		SoloBreakTime = 6.5, -- s : zones 1 à 5, un joueur seul au niveau du panneau casse en ce temps
		LastZoneBreakTime = 6.5, -- s : dernière zone, l'équipe au niveau du panneau casse en ce temps
		LastZoneTeamSize = 2, -- joueurs de cette équipe (jamais seul)
	},

	-- 5.3 : panneau au-dessus de la vitrine. Vert si le joueur atteint la valeur
	-- conseillée, orange de 50 à 99 %, rouge en dessous.
	StorePanel = {
		OrangeFrom = 0.5,
	},

	-- 5.3 et 9.4 : braquage d'un magasin PNJ
	Heist = {
		-- Chrono « HEIST » après la casse (Cantin, 2026-11-14, rééquilibrage v2 : 10 → 6 s). Il part à la casse
		-- (il ne reprend plus la fin du chrono de police, Balance.Window.BreakTimer) ; le rideau tombe à la fin.
		Duration = 6,
		BreakerHeadStart = 1, -- avance exclusive du casseur (5.3, point 8 : proposition à valider en section 15)
		MaxCarried = 1, -- un seul colis porté à la fois
		GrabMaxDistance = 8, -- GrabItem (9.4)
		-- Portée tolérée pendant un maintien (début et revérifications, pas la fin ; Cantin, 2026-11-14) : le serveur
		-- voit le perso en retard d'environ vitesse × latence. Tolérance = min(WalkSpeed × (ping + ReachLatencyPad), plafond),
		-- plafond = max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds), en plus de GrabMaxDistance et autour du volume Bounds. Aussi pour les colis au sol.
		ReachLatencyPad = 0.8, -- s, V0 (0,1 puis 0,3 puis 0,5 ; en Play le 14/11, jusqu'à 0,37 s de retard à ping 0 ; 0,8 s couvre aussi environ 400 ms de ping en ligne ; la télémétrie RemoteRefused dira s'il faut régler)
		-- Plafond qui suit la vitesse (Cantin, 2026-11-14, « une ouverture très clean ») : un plafond fixe de 8 studs
		-- était trop juste en courant vite (en Play le 14/11, à 65 studs/s, le serveur voyait le perso jusqu'à 15,7 studs
		-- pour une limite de 16). À 65 studs/s le plafond vaut 32,5 studs ; à 16 studs/s il reste 8. La fin du maintien
		-- reste stricte. La télémétrie RemoteRefused dira en ligne combien de « trop loin » restent, pour régler 0,5 s.
		ReachToleranceMin = 8, -- studs, V0 (plafond minimal, l'ancien ReachToleranceMax)
		ReachToleranceSeconds = 0.8, -- s, V0 (plafond = WalkSpeed × 0,8 s quand c'est plus que ReachToleranceMin ; 0,5 au départ)
		ShelfSlots = 10, -- ShelfSlot_01 à ShelfSlot_10 (10.4)
		TierOrder = TIER_ORDER,
		BoxTiers = BOX_TIERS,
		-- Un seul braquage à la fois (Cantin, 2026-11-11, L-099 point 3) : un joueur dont le braquage n'est
		-- pas fini ne fait aucun dégât à la vitrine d'un autre magasin PNJ. V0 proposés, absents du doc :
		-- le message (anglais, L-036 ; Clément choisira le texte final) et son délai minimal entre deux
		-- envois au même joueur (s).
		OneAtATimeMessage = "Easy there, greedy! Finish your heist first.",
		OneAtATimeCooldown = 3,
	},

	-- 9.5 : DataStore des profils joueurs (DataService), choisie selon le jeu Roblox (game.GameId).
	-- Remise à zéro des profils de la place DEV (Cantin, 2026-11-14, rééquilibrage v2) : le jeu DEV lit une
	-- autre DataStore, vide ; le jeu PROD (GameId 10774998269) et tout autre jeu gardent StoreName, à ne
	-- jamais changer. L'ancienne DataStore « PlayerData » du jeu DEV n'est ni effacée ni modifiée : pour y
	-- revenir, DevStoreName = "PlayerData". Pour une nouvelle remise à zéro du DEV : un nouveau nom.
	Profiles = {
		StoreName = "PlayerData", -- PROD : ne jamais le changer (un autre nom = profils vides)
		DevGameId = 10774974820, -- « Steal a Shop [DEV] » (liaison, L-001)
		DevStoreName = "PlayerData_DEV_20261114",
	},

	-- 5.4 : séquence de casse, simulée côté client
	Shatter = {
		FreezeFrame = 0.06, -- arrêt sur image
		FlashDuration = 0.08, -- flash blanc
		CameraShakeDuration = 0.25,
		ShardFadeDelay = 1.5, -- les éclats restent au sol avant de s'effacer
		ShardFadeDuration = 1.2,
		MaxShards = 40, -- version pré-fracturée : 30 à 40 éclats
		LowEndShards = 10, -- mobile faible, ou au-delà de MaxFullShattersAtOnce
		MaxFullShattersAtOnce = 2,
		SoundPitchVariation = 0.1, -- ±10 %
	},

	-- 5.5 et 9.7 : vigile de jour (GuardService). Vitesses par zone : Zones.
	Guard = {
		PerThief = 1,
		MaxPerStore = 3,
		MaxActivePerServer = 6, -- 9.7
		PathRecomputeInterval = 0.3, -- PathfindingService sans ligne de vue : au plus un calcul toutes les 0,3 s (L-091)
		CatchDistance = 4, -- vérifiée côté serveur
		-- 2,4 s (Cantin, 2026-11-10 ; le doc disait 1,5) : le temps des animations de Clément, Knockdown
		-- (1,2 s) puis GetUp (1,2 s), pour que le joueur ne reparte pas en glissant pendant qu'il se relève.
		CatchStunDuration = 2.4,
		-- Poursuite sans fin (Cantin, 2026-11-11) : le vigile n'abandonne plus au bout de 20 s ni à 120 studs
		-- d'avance, seulement à la zone safe (ou à la fin du portage). Cette distance ne sert plus qu'à
		-- l'échelle de la jauge GuardMeter du HUD (HudController) : vide à cette distance, pleine à CatchDistance.
		GiveUpLead = 120,
		-- Seule exception à la poursuite sans fin (Cantin, 2026-11-13, « environ 10 secondes ») : le vigile sorti à
		-- la fin du chrono pour un intrus resté sans objet (ChaseIntruder) abandonne au bout de ce temps de
		-- poursuite (s). Si l'intrus prend un objet entre-temps, c'est une poursuite de porteur, sans fin.
		IntruderChaseTime = 10,
		HeartbeatDistance = 10, -- battements de cœur sous cette distance
		-- V0 proposé, absent du doc (liaison L-077, question posée à Clément) : où s'arrête le retour
		-- du vigile de jour, qui s'y efface en fondu. "Reserve" (b) : il traverse le magasin jusqu'à
		-- son GuardSpawn ; "Door" (a) : il s'arrête à la porte du magasin (`Door`, sinon la vitrine),
		-- côté rue. Passage fermé (rideau baissé, vitrine reconstruite) : devant la porte, dans les
		-- deux cas. Déjà dans le magasin quand il rentre : jusqu'au GuardSpawn, dans les deux cas.
		ReturnEnd = "Reserve",
		ReturnFadeTime = 0.6, -- V0 proposé, absent du doc : durée du fondu de sa disparition (s)
		-- Décision d'Ironix (2026-11-08) : le magasin ne se rouvre (vitrine reconstruite, rideau levé)
		-- qu'une fois tous ses vigiles de jour rentrés, puis ce nombre de secondes (V0).
		ReopenAfterReturn = 3,
	},

	-- 5.6 et 6.1 : porter un colis ou un objet volé
	Carry = {
		NPCBoxSpeedMultiplier = 0.9, -- −10 % avec un colis PNJ
		-- Objet volé à un joueur (ou au bot) : vitesse FIXE, la même pour tous, quels que soient la Vitesse,
		-- le trail, l'Adrénaline ou la potion du voleur (Cantin, 2026-11-13 : contre les voleurs trop rapides ;
		-- remplace le −25 % du doc, 6.1). V0 proposé : 16 = la vitesse d'un joueur neuf, à régler en test.
		StolenItemWalkSpeed = 16 * REAL_SPEED_SCALE, -- vague 61 : 16 à l'échelle 1 (32 à × 2)
		CanJump = true,
		-- V0 proposé, absent du doc (L-071, point 4) : espace (studs) entre le haut de la tête et le
		-- dessous du colis ou de l'objet porté (CarryAttachment), soudé à la tête. À régler sur la
		-- hauteur des mains de CarryIdle et CarryRun (bras levés), quand Clément les livre.
		HeadGap = 0.25,
	},

	-- 5.7 et 7.5 : établis et révélation. Attente par rareté : Rarities.
	Unbox = {
		-- Plus lus par le code depuis L-086 (2026-11-08) : les colis s'ouvrent sur les présentoirs, sans
		-- établi. Gardés pour la trace des anciens profils (Upgrades.UnboxBenches).
		StartBenches = 1,
		MaxBenches = 4,
		FullRevealDuration = 4, -- version complète (Rare et plus), jusqu'à l'objet
		TensionEnd = 1.5, -- étape 2 : de 0 à 1,5 s
		ExplosionAt = 2.2, -- étape 3 : de 1,5 à 2,2 s, puis explosion
		FlashDuration = 0.1,
		ShortRevealDuration = 2, -- version courte (Commun, Peu commun)
		SecretSlowMotionDuration = 0.5,
	},

	-- 5.8 : présentoirs, inventaire, receleur. Améliorations : Upgrades.
	Display = {
		StartSlots = 4,
		MaxSlots = 20,
		InventoryMax = 30, -- objets non exposés
		FenceIncomeMultiplier = 120, -- le receleur rachète un objet 120 × son $/s
	},

	-- 6.2 et 9.4 : bouton Retour base
	ReturnToBase = {
		Cooldown = 90,
		AllowedWhileCarrying = false,
	},

	-- 9.6 : contrôle des déplacements (AntiCheatService)
	AntiCheat = {
		CheckInterval = 0.25,
		SpeedTolerance = 1.25, -- distance acceptée = vitesse autorisée × 1,25
		MaxAnomalies = 3, -- 3 anomalies…
		AnomalyWindow = 5, -- … en 5 s : retour à la dernière position valide, colis rendu
		TeleportDistance = 30, -- saut entre deux contrôles qui rend le colis ou l'objet
	},
}

export type Balance = typeof(Balance)

return DeepFreeze(Balance)

]==========]
SRC["Config/Rarities"] = [==========[
--!strict
-- Raretés, attente d'ouverture et probabilités par type de colis (Partie 1, sections 7.3, 5.6, 5.7 et 2.4).
-- L'Id est la valeur stockée dans la sauvegarde (Boxes[..].Rarity, 9.5), par exemple "Epic".
-- Divine (8e rareté, au-dessus de Secret) : décidée par Clément (doc section 15, 2026-11-08 et
-- 2026-11-12 ; liaison L-106 point 1), couleur #FFE9A8. Ses autres valeurs sont des V0 proposés,
-- absents du doc (table 7.3). Comme le Secret, elle est tirée toutes zones confondues
-- (Items.AllZones). Tant que le catalogue n'a aucun objet Divine, sa chance de tirage reste à 0
-- (BoxOdds, plus bas).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret" | "Divine"

-- Halo de rareté autour d'un colis porté ou d'un objet exposé (5.6)
export type Halo = "None" | "Light" | "Clear" | "Rays" | "Rainbow" | "Divine"

export type Rarity = {
	Id: RarityId,
	Order: number, -- 1 = Commun … 7 = Secret, 8 = Divine, pour comparer deux raretés
	DisplayName: string,
	DisplayNameUpper: string, -- string.upper ne met pas les lettres accentuées en majuscules
	ColorName: string, -- couleur écrite dans le doc (7.3)
	Color: Color3, -- planche de style de Clément (doc 10.6, MOD-002), validée à deux le 2026-11-06 (liaison L-018)
	Rainbow: boolean, -- couleur animée arc-en-ciel (Secret)
	RainbowColors: { Color3 }?, -- suite de couleurs de l'arc-en-ciel animé (Secret, doc 10.6)
	IncomeMultiplier: number, -- M rareté de la formule du revenu (7.1)
	OpenDelay: number, -- attente d'ouverture d'un colis PNJ, en secondes
	Halo: Halo,
	FullReveal: boolean, -- storyboard complet (Rare et plus), sinon version courte de 2 s (5.7)
	Confetti: boolean, -- confettis plein écran (Épique et plus)
	Announce: boolean, -- annonce à tout le serveur et animation Celebrate (Légendaire et plus)
	SlowMotion: boolean, -- ralenti et musique unique (Secret, Divine) ; l'arc-en-ciel, c'est Rainbow
}

local List: { Rarity } = {
	{
		Id = "Common",
		Order = 1,
		DisplayName = "Common",
		DisplayNameUpper = "COMMON",
		ColorName = "Gris",
		Color = Color3.fromHex("#B0B7C3"),
		Rainbow = false,
		IncomeMultiplier = 1,
		OpenDelay = 10,
		Halo = "None",
		FullReveal = false,
		Confetti = false,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Uncommon",
		Order = 2,
		DisplayName = "Uncommon",
		DisplayNameUpper = "UNCOMMON",
		ColorName = "Vert",
		Color = Color3.fromHex("#2FE08F"), -- vert menthe : ne disparaît pas sur l'herbe
		Rainbow = false,
		IncomeMultiplier = 2,
		OpenDelay = 20,
		Halo = "Light",
		FullReveal = false,
		Confetti = false,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Rare",
		Order = 3,
		DisplayName = "Rare",
		DisplayNameUpper = "RARE",
		ColorName = "Bleu",
		Color = Color3.fromHex("#2F9BFF"),
		Rainbow = false,
		IncomeMultiplier = 5,
		OpenDelay = 45,
		Halo = "Clear",
		FullReveal = true,
		Confetti = false,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Epic",
		Order = 4,
		DisplayName = "Epic",
		DisplayNameUpper = "EPIC",
		ColorName = "Violet",
		Color = Color3.fromHex("#A855F7"),
		Rainbow = false,
		IncomeMultiplier = 15,
		OpenDelay = 90,
		Halo = "Clear",
		FullReveal = true,
		Confetti = true,
		Announce = false,
		SlowMotion = false,
	},
	{
		Id = "Legendary",
		Order = 5,
		DisplayName = "Legendary",
		DisplayNameUpper = "LEGENDARY",
		ColorName = "Or",
		Color = Color3.fromHex("#FFC21A"),
		Rainbow = false,
		IncomeMultiplier = 50,
		OpenDelay = 3 * 60,
		Halo = "Rays",
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = false,
	},
	{
		Id = "Mythic",
		Order = 6,
		DisplayName = "Mythic",
		DisplayNameUpper = "MYTHIC",
		ColorName = "Rouge",
		Color = Color3.fromHex("#FF3B5C"),
		Rainbow = false,
		IncomeMultiplier = 200,
		OpenDelay = 8 * 60,
		Halo = "Rays",
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = false,
	},
	{
		Id = "Secret",
		Order = 7,
		DisplayName = "Secret",
		DisplayNameUpper = "SECRET",
		ColorName = "Arc-en-ciel animé",
		Color = Color3.fromHex("#FF3B3B"), -- première couleur de l'arc-en-ciel, pour un affichage fixe
		Rainbow = true,
		RainbowColors = {
			Color3.fromHex("#FF3B3B"),
			Color3.fromHex("#FFC21A"),
			Color3.fromHex("#3BE15A"),
			Color3.fromHex("#2F9BFF"),
			Color3.fromHex("#A855F7"),
		},
		IncomeMultiplier = 1_000,
		OpenDelay = 15 * 60,
		Halo = "Rainbow",
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = true,
	},
	{
		-- L-106 point 1 : Id, couleur et place au-dessus de Secret. Le reste : V0 proposé, absent du doc.
		Id = "Divine",
		Order = 8,
		DisplayName = "Divine",
		DisplayNameUpper = "DIVINE",
		ColorName = "Or pâle",
		Color = Color3.fromHex("#FFE9A8"), -- L-106 : couleur choisie par Clément
		Rainbow = false, -- couleur fixe
		IncomeMultiplier = 5_000, -- V0 : ×5 du Secret (Mythique → Secret fait déjà ×5)
		OpenDelay = 30 * 60, -- V0 : 30 min, le double du Secret (la suite double presque à chaque palier)
		Halo = "Divine", -- V0 : rayons plus nombreux et plus lumineux que ceux du Secret, or pâle
		FullReveal = true,
		Confetti = true,
		Announce = true,
		SlowMotion = true, -- V0 : même ralenti que le Secret ; son Unbox_Reveal_Divine s'il est livré
	},
}

local ById: { [string]: Rarity } = {}
for _, rarity in List do
	ById[rarity.Id] = rarity
end

-- Probabilités de tirage par type de colis, en pour cent (chaque colonne fait 100).
-- BoxOdds[BoxTier][RarityId] = pourcentage.
-- Divine : 0 partout tant que le catalogue n'a aucun objet Divine (Items.AllZones.Divine vide).
-- V0 proposé, absent du doc, à poser quand Clément livre les premiers objets Divine : Luxe = 0,02 %
-- (1 colis Luxe sur 5 000, le dixième du Secret), pris sur Rare (40 → 39,98) ; Standard et Premium 0.
-- Une chance > 0 sans objet ne casserait rien (repli de StoreHeistService et de TruckEventService :
-- la rareté tirable la plus proche en dessous, donc un Secret), mais elle augmenterait en silence la
-- chance du Secret au-delà de la table 7.3 : d'où le 0.
local BoxOdds: { [string]: { [string]: number } } = {
	Standard = { Common = 70, Uncommon = 22, Rare = 7, Epic = 1, Legendary = 0, Mythic = 0, Secret = 0, Divine = 0 },
	Premium = { Common = 35, Uncommon = 35, Rare = 20, Epic = 8, Legendary = 1.8, Mythic = 0.2, Secret = 0, Divine = 0 },
	Luxe = { Common = 0, Uncommon = 25, Rare = 40, Epic = 25, Legendary = 8, Mythic = 1.8, Secret = 0.2, Divine = 0 },
}

local Rarities = {
	List = List, -- dans l'ordre, de Commun à Divine
	ById = ById,
	BoxOdds = BoxOdds,
}

export type Rarities = typeof(Rarities)

return DeepFreeze(Rarities)

]==========]
SRC["AnimationController"] = [==========[
--!strict
-- AnimationController (DEV-006) : les animations du personnage local, jouées par leur nom.
--
-- À chaque apparition du personnage, prépare les 14 animations du joueur
-- (ReplicatedStorage/Assets/Animations/Player, contrat 2.4) sur son Animator, rebranche les
-- marqueurs (sons de Shared/Anim/MarkerSounds et branchements des autres contrôleurs) et rejoue
-- l'état en cours. Préchargement une fois par session. Déjà branché, sans autre service :
--   - TreadmillRun en boucle tant que l'attribut TrainingMachine du Player vaut "Treadmill" (posé
--     par TrainingService quand le joueur s'arrête sur la bande du tapis, L-071) ;
--   - (plus de BenchLift ni de BenchIdle depuis le rééquilibrage v2 du 2026-11-14 : plus de banc) ;
--   - portage : SetCarrying(true), appelé par CarryController quand l'attribut Carrying du joueur
--     arrive (CarryService), joue CarryIdle à l'arrêt et CarryRun en mouvement ; SetCarrying(false)
--     les arrête. Grab pose le colis sur la tête, puis CarryIdle et CarryRun le tiennent (L-071,
--     point 4) : si Grab joue encore (lancé au ramassage par HeistController, PvPController,
--     TruckController ou BatController), la boucle attend que Grab ait posé le colis (AfterGrab),
--     puis prend sa suite en fondu (GRAB_BLEND) : les deux pistes, en Action, ne se mélangent pas.
-- En Studio, mode test de DEV-006 : voir Shared/Anim/AnimTest.
--
-- « Grab a posé le colis » (AfterGrab) : au marqueur Grab de l'animation Grab (Clément le pose sur
-- l'image où le colis arrive sur la tête), sinon à la fin de Grab, au plus tard GRAB_MAX_WAIT s
-- (ou la durée de Grab, si elle est plus longue) après son lancement. Côté client seulement, pour le
-- joueur local : le serveur a déjà décidé la prise, rien ne l'attend.
--
-- API (les autres contrôleurs le requièrent avec pcall et continuent sans lui) :
--   AnimationController.PlayPlayer(name, fadeTime?) -> AnimationTrack?
--   AnimationController.StopPlayer(name, fadeTime?)
--   AnimationController.OnMarker(animName, markerName, callback) -> débrancher
--     (le branchement suit le joueur d'une vie à l'autre)
--   AnimationController.SetCarrying(carrying)
--   AnimationController.NeedsTwoHands(character) -> boolean   objet tenu Big, Huge ou Colossal (HoldItem, vague 56)
--   AnimationController.AfterGrab(callback) -> boolean
--     callback(fromGrab) quand le Grab en cours a posé le colis (voir plus haut) : fromGrab = true.
--     Sans Grab en cours, tout de suite, avant le retour : callback(false), et AfterGrab renvoie
--     false. Renvoie true si l'appel est différé (CarryController cache le colis en attendant).
-- Une animation pas encore livrée ne fait rien, sans erreur (un avertissement en Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimFolder = Shared:WaitForChild("Anim")
local AnimPlayer = require(AnimFolder:WaitForChild("AnimPlayer"))
local MarkerSounds = require(AnimFolder:WaitForChild("MarkerSounds"))
local Animations = require(Shared:WaitForChild("Contract"):WaitForChild("Animations"))

type AnimPlayer = AnimPlayer.AnimPlayer

-- Branchement d'un autre contrôleur sur un marqueur, rebranché à chaque vie du personnage.
type Sub = { anim: string, marker: string, callback: () -> (), off: (() -> ())? }

local AnimationController = {}

-- Attributs du Player posés par TrainingService, lus ici sans require.
local TRAINING_MACHINE = "TrainingMachine"

-- V0 proposé, absent du doc : vitesse (studs/s) au-dessus de laquelle le porteur court
-- (CarryRun) ; en dessous, CarryIdle. Même seuil que le script Animate de Roblox.
local CARRY_RUN_SPEED = 0.75

-- Prise d'un colis (contrat 2.4) : animation Grab et son marqueur.
local GRAB_ANIMATION = "Grab"
local GRAB_MARKER = "Grab"
for _, spec in Animations.Player do
	local marker = spec.Marker
	if spec.Name == GRAB_ANIMATION and marker then
		GRAB_MARKER = marker
	end
end
-- V0 proposé, absent du doc : au plus tard ce délai (s) après le lancement de Grab, le colis est
-- tenu pour posé (Grab sans marqueur dont la fin ne vient pas : piste pas encore chargée…).
local GRAB_MAX_WAIT = 1.5
-- V0 proposé, absent du doc : fondu (s) entre Grab et la boucle de portage (CarryIdle ou CarryRun).
local GRAB_BLEND = 0.2

-- Vague 56 (a181, L-162, Clément) : objet tenu en main (Tool de HeldItemService, attribut HeldItemUid ; son modèle
-- HeldItem porte MutationSize, DisplayService) de taille Big, Huge ou Colossal : HoldItem (deux mains, boucle) tant
-- qu'il est en main. Pas encore livrée, ou autre taille : la pose « outil » de Roblox reste. Noms de Config/HeldItem
-- et DisplayService, lus ici sans require.
local HOLD_ANIMATION = "HoldItem"
local HELD_TOOL_ATTRIBUTE = "HeldItemUid"
local HELD_MODEL_NAME = "HeldItem"
local SIZE_ATTRIBUTE = "MutationSize"
local TWO_HAND_SIZES: { [string]: boolean } = { Big = true, Huge = true, Colossal = true }
-- Vague 62 (a203) : avec le poids, attribut Weight (kg) du modèle (DisplayService) : deux mains dès TWO_HANDS_FROM kg (mêmes
-- valeurs que Config/Weight.Attribute et .TwoHandsFrom, lues ici sans require, comme les noms ci-dessus).
local WEIGHT_ATTRIBUTE = "Weight"
local TWO_HANDS_FROM = 50

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer
local playerFolder: Instance? = nil
local current: AnimPlayer? = nil
local currentCharacter: Model? = nil
local characterConnections: { RBXScriptConnection } = {}
local subs: { Sub } = {}
local carrying = false
local carryReady = false -- la boucle de portage peut jouer (Grab a posé le colis, ou pas de Grab)
local carryToken = 0 -- change à chaque SetCarrying : périme une attente de Grab d'avant
local carryAnim: string? = nil
-- Grab lancés (PlayPlayer) et dernier Grab qui a posé son colis ; appels d'AfterGrab en attente.
local grabPlays = 0
local grabDone = 0
local grabWaiters: { (fromGrab: boolean) -> () } = {}

local function bindSub(anims: AnimPlayer, sub: Sub)
	sub.off = anims:OnMarker(sub.anim, sub.marker, function(_param: string)
		sub.callback()
	end)
end

-- Prise d'un colis -----------------------------------------------------------------

-- Le Grab n° `id` a posé son colis (marqueur, fin ou délai) : les attentes d'AfterGrab partent.
-- Sans effet pour un Grab dépassé par un plus récent, ou déjà compté.
local function grabReached(id: number)
	if id ~= grabPlays or grabDone >= id then
		return
	end
	grabDone = id
	local waiters = grabWaiters
	grabWaiters = {}
	for _, waiter in waiters do
		task.spawn(waiter, true)
	end
end

-- Un Grab vient d'être lancé (piste rendue par PlayPlayer) : sa fin, ou au plus tard GRAB_MAX_WAIT
-- (sa durée, si elle est plus longue : un marqueur tardif n'est jamais devancé), tiendra lieu de
-- marqueur s'il n'en a pas.
local function onGrabStarted(track: AnimationTrack)
	grabPlays += 1
	local id = grabPlays
	track.Stopped:Once(function()
		grabReached(id)
	end)
	task.delay(math.max(GRAB_MAX_WAIT, track.Length), grabReached, id)
end

-- Un Grab joue et n'a pas encore posé son colis.
local function grabPending(): boolean
	local anims = current
	return grabDone < grabPlays and anims ~= nil and anims:IsPlaying(GRAB_ANIMATION)
end

-- Joue une animation du joueur. Renvoie sa piste, ou nil si elle n'est pas encore livrée ou si le
-- personnage n'est pas là.
function AnimationController.PlayPlayer(name: string, fadeTime: number?): AnimationTrack?
	local anims = current
	if anims == nil then
		return nil
	end
	local track = anims:Play(name, fadeTime)
	if track and name == GRAB_ANIMATION then
		onGrabStarted(track)
	end
	return track
end

-- Voir l'en-tête.
function AnimationController.AfterGrab(callback: (fromGrab: boolean) -> ()): boolean
	if not grabPending() then
		callback(false)
		return false
	end
	table.insert(grabWaiters, callback)
	return true
end

function AnimationController.StopPlayer(name: string, fadeTime: number?)
	local anims = current
	if anims then
		anims:Stop(name, fadeTime)
	end
end

-- Appelle `callback` à chaque passage du marqueur `markerName` de l'animation `animName` du
-- joueur, d'une vie à l'autre. Renvoie une fonction qui débranche.
function AnimationController.OnMarker(animName: string, markerName: string, callback: () -> ()): () -> ()
	local sub: Sub = { anim = animName, marker = markerName, callback = callback, off = nil }
	table.insert(subs, sub)
	local anims = current
	if anims then
		bindSub(anims, sub)
	end
	return function()
		local index = table.find(subs, sub)
		if index then
			table.remove(subs, index)
		end
		local off = sub.off
		if off then
			sub.off = nil
			off()
		end
	end
end

local function rootPart(): BasePart?
	local character = currentCharacter
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

local function horizontalSpeed(): number
	local root = rootPart()
	if root == nil then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

-- Portage ----------------------------------------------------------------------

local function setCarryAnim(name: string?, fadeTime: number?)
	if name == carryAnim then
		return
	end
	local previous = carryAnim
	carryAnim = name
	if previous then
		AnimationController.StopPlayer(previous, fadeTime)
	end
	if name then
		AnimationController.PlayPlayer(name, fadeTime)
	end
end

local function updateCarry(speed: number, fadeTime: number?)
	if carrying and carryReady then
		setCarryAnim(if speed > CARRY_RUN_SPEED then "CarryRun" else "CarryIdle", fadeTime)
	else
		setCarryAnim(nil)
	end
end

-- Colis ou objet porté (DEV-017) : true joue CarryIdle ou CarryRun selon la vitesse, et suit les
-- changements de vitesse ; false les arrête. Pendant un Grab, la boucle attend qu'il ait posé le
-- colis, puis prend sa suite en fondu (voir l'en-tête).
function AnimationController.SetCarrying(on: boolean)
	carrying = on
	carryToken += 1
	carryReady = false
	if not on then
		updateCarry(0)
		return
	end
	local token = carryToken
	AnimationController.AfterGrab(function(fromGrab: boolean)
		if token ~= carryToken or not carrying then
			return -- portage fini ou recommencé entre-temps
		end
		carryReady = true
		if fromGrab then
			AnimationController.StopPlayer(GRAB_ANIMATION, GRAB_BLEND)
		end
		updateCarry(horizontalSpeed(), if fromGrab then GRAB_BLEND else nil)
	end)
end

-- Entraînement (attributs du Player tenus par TrainingService) ------------------

local function applyTreadmill()
	local machine = player:GetAttribute(TRAINING_MACHINE)
	if machine == "Treadmill" then
		AnimationController.PlayPlayer("TreadmillRun")
	else
		AnimationController.StopPlayer("TreadmillRun")
	end
	-- Rééquilibrage v2 (2026-11-14) : plus de banc, donc plus de BenchIdle ni de BenchLift joués ici.
end

-- Objet tenu (vague 56, voir HOLD_ANIMATION) -----------------------------------

local holdPlaying = false

-- true si `character` tient en main un objet de l'inventaire assez gros pour les deux mains.
function AnimationController.NeedsTwoHands(character: Instance): boolean
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(HELD_TOOL_ATTRIBUTE) ~= nil then
			local model = child:FindFirstChild(HELD_MODEL_NAME)
			local weight = if model then model:GetAttribute(WEIGHT_ATTRIBUTE) else nil
			if type(weight) == "number" then
				return weight >= TWO_HANDS_FROM
			end
			local size = if model then model:GetAttribute(SIZE_ATTRIBUTE) else nil
			return type(size) == "string" and TWO_HAND_SIZES[size] == true
		end
	end
	return false
end

local function applyHold()
	local character = currentCharacter
	local want = character ~= nil and AnimationController.NeedsTwoHands(character)
	if want == holdPlaying then
		return
	end
	holdPlaying = want
	if want then
		AnimationController.PlayPlayer(HOLD_ANIMATION)
	else
		AnimationController.StopPlayer(HOLD_ANIMATION)
	end
end

-- Personnage -------------------------------------------------------------------

local function clearCharacter()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	for _, sub in subs do
		sub.off = nil
	end
	local anims = current
	current = nil
	if anims then
		anims:Destroy()
	end
	carryAnim = nil
	holdPlaying = false
end

local function onCharacter(character: Model)
	if currentCharacter == character then
		return -- déjà en cours pour ce personnage
	end
	clearCharacter()
	currentCharacter = character
	local animator = AnimPlayer.waitForAnimator(character)
	if currentCharacter ~= character then
		return -- un autre personnage est arrivé entre-temps
	end
	if animator == nil then
		if IS_STUDIO then
			warn("[Anim] Joueur : pas d'Animator dans le Humanoid du personnage, aucune animation jouée")
		end
		return
	end
	local anims = AnimPlayer.new(animator, playerFolder, Animations.Player, "Joueur")
	current = anims
	anims:LoadAll()
	for _, sub in subs do
		bindSub(anims, sub)
	end
	local humanoid = animator.Parent
	if humanoid and humanoid:IsA("Humanoid") then
		table.insert(
			characterConnections,
			(humanoid :: Humanoid).Running:Connect(function(speed: number)
				if carrying then
					updateCarry(speed)
				end
			end)
		)
	end
	-- Objet tenu : un Tool arrive dans le personnage ou en sort (task.defer : son modèle et ses attributs d'abord).
	table.insert(characterConnections, character.ChildAdded:Connect(function()
		task.defer(applyHold)
	end))
	table.insert(characterConnections, character.ChildRemoved:Connect(function()
		task.defer(applyHold)
	end))
	applyTreadmill()
	updateCarry(horizontalSpeed())
	applyHold()
end

local function onCharacterRemoving(character: Model)
	if currentCharacter == character then
		clearCharacter()
		currentCharacter = nil
	end
end

local function preloadOnce()
	local names: { string } = {}
	for _, spec in Animations.Player do
		table.insert(names, spec.Name)
	end
	local count = AnimPlayer.preload(playerFolder, names)
	if not IS_STUDIO then
		return
	end
	if playerFolder == nil then
		print(
			`[Anim] Joueur : ReplicatedStorage.{table.concat(Animations.PlayerFolder, ".")} absent, aucune des {#names} animations n'est encore livrée`
		)
	else
		print(`[Anim] Joueur : {count}/{#names} animation(s) préchargée(s)`)
	end
end

function AnimationController.Start()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	playerFolder = AnimPlayer.playerFolder()

	-- Sons des marqueurs (registre Shared/Anim/MarkerSounds), joués sur le personnage local.
	if IS_STUDIO then
		MarkerSounds.check(MarkerSounds.Player, Animations.Player, "Player")
	end
	for _, entry in MarkerSounds.Player do
		AnimationController.OnMarker(entry.Anim, entry.Marker, function()
			MarkerSounds.play(entry.Sound, rootPart())
		end)
	end
	-- Grab a posé le colis sur la tête : la boucle de portage et le colis du porteur suivent (L-071).
	AnimationController.OnMarker(GRAB_ANIMATION, GRAB_MARKER, function()
		grabReached(grabPlays)
	end)

	player:GetAttributeChangedSignal(TRAINING_MACHINE):Connect(applyTreadmill)

	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(onCharacterRemoving)
	local character = player.Character
	if character then
		task.spawn(onCharacter, character)
	end

	task.spawn(preloadOnce)

	-- Mode test de DEV-006, chargé en Studio seulement (Shared/Anim/AnimTest).
	if IS_STUDIO then
		local ok, err = pcall(function()
			require(AnimFolder:WaitForChild("AnimTest")).start()
		end)
		if not ok then
			warn(`[Anim] mode test indisponible : {err}`)
		end
	end
end

return AnimationController

]==========]
SRC["CarryController"] = [==========[
--!strict
-- CarryController (DEV-017, client) : le portage côté joueur (Partie 1, section 5.6).
--
-- Rôle :
--   - suit l'attribut Carrying du joueur local (posé par CarryService : Id de la rareté portée,
--     nil sinon) et appelle AnimationController.SetCarrying(true/false), qui joue CarryIdle à
--     l'arrêt et CarryRun en courant (après Grab, s'il joue encore). Sans AnimationController,
--     rien, sans erreur ;
--   - colis posé sur la tête au geste de Grab (L-071, point 4), pour le porteur seulement : si Grab
--     joue encore quand le colis arrive (AnimationController.AfterGrab), son visuel CarryVisual
--     (soudé à la tête par CarryService dès que le serveur a accepté la prise) est caché en local
--     jusqu'à ce que Grab l'ait posé : marqueur Grab, sinon fin de Grab, sinon délai de secours
--     (GRAB_MAX_WAIT d'AnimationController). Pièces et décalques : LocalTransparencyModifier ;
--     étiquette, halo et contours : Enabled (Visible pour une SelectionBox). Rien n'attend côté
--     serveur, et les autres joueurs voient le colis dès la prise ;
--   - pendant le portage, range tout outil que le joueur sort (5.6 : ni outil ni batte en main).
--     Le serveur fait de même et fait foi ; ici, c'est pour que l'outil ne s'affiche pas en main ;
--   - saut : autorisé (Balance.Carry.CanJump = true, 5.6), rien à faire. Si CanJump passe à false,
--     le saut est coupé pendant le portage ;
--   - colis et objets Secret, portés ou au sol (tag CarryRainbow posé par CarryService) : anime en
--     local leur arc-en-ciel (RainbowColors de la rareté) sur les pièces Tint, la lumière du halo
--     et le texte Rarity de l'étiquette (BB_Box ou BB_Carry). Colis Secret d'un rayon : le tag est
--     posé sur son étiquette BB_Box seule (CarryService.AttachBoxLabel), seul le texte Rarity
--     change, le colis garde l'aspect de son type.
-- Aucun remote, aucune UI créée.
--
-- API (client) :
--   CarryController.IsCarrying() -> boolean   le joueur local porte un colis ou un objet

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Rarities = require(Config:WaitForChild("Rarities"))

type AnimationApi = {
	SetCarrying: (carrying: boolean) -> (),
	-- Absent d'un AnimationController plus ancien : le colis n'est jamais caché.
	AfterGrab: ((callback: (fromGrab: boolean) -> ()) -> boolean)?,
}

-- Mêmes noms que CarryService.
local CARRYING_ATTRIBUTE = "Carrying"
local RAINBOW_TAG = "CarryRainbow"
local TINT = "Tint"
local RARITY_LABEL = "Rarity"
local VISUAL_NAME = "CarryVisual"
-- V0 proposé, absent du doc : durée d'un tour complet de l'arc-en-ciel, en secondes.
local RAINBOW_PERIOD = 2

type Rainbow = {
	tints: { BasePart },
	lights: { Light },
	labels: { TextLabel },
	added: RBXScriptConnection?, -- descendants arrivés après le tag (streaming) : ajoutés à leur arrivée
}

-- Visuel du colis caché en local en attendant que Grab l'ait posé : valeurs à remettre.
type Switch = { inst: Instance, prop: string } -- propriété (Enabled ou Visible) passée de true à false
type Hidden = {
	modifiers: { [Instance]: number }, -- pièces et décalques : LocalTransparencyModifier d'avant
	switches: { Switch }, -- étiquettes, halo, contours (Highlight, SelectionBox) éteints ici
	added: RBXScriptConnection?, -- descendants arrivés après coup, cachés aussi
}

local CarryController = {}

local localPlayer = Players.LocalPlayer
local animation: AnimationApi? = nil
local carrying = false
local characterConnection: RBXScriptConnection? = nil
local rainbowColors: { Color3 } = {}
local rainbows: { [Instance]: Rainbow } = {}
local rainbowConnection: RBXScriptConnection? = nil
local holding = false -- colis du joueur local caché jusqu'à ce que Grab l'ait posé
local holdToken = 0 -- change à chaque début ou fin de portage : périme une attente d'avant
local hidden: { [Instance]: Hidden } = {}

local function loadAnimationController(): AnimationApi?
	local folder = script.Parent
	local module = if folder then folder:FindFirstChild("AnimationController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type((result :: any).SetCarrying) == "function" then
		return result :: any
	end
	return nil
end

-- Portage du joueur local ----------------------------------------------------------

local function humanoidOf(): Humanoid?
	local character = localPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function stowTools()
	local humanoid = humanoidOf()
	if carrying and humanoid then
		humanoid:UnequipTools()
	end
end

-- Colis caché jusqu'au geste de Grab ----------------------------------------------

-- Éteint `prop` (Enabled ou Visible) de `inst` s'il est allumé, et le note pour revealAll.
local function switchOff(record: Hidden, inst: Instance, prop: string)
	local target = inst :: any
	if target[prop] == true then
		target[prop] = false
		table.insert(record.switches, { inst = inst, prop = prop })
	end
end

local function hideOne(record: Hidden, descendant: Instance)
	if descendant:IsA("BasePart") then
		local part = descendant :: BasePart
		if record.modifiers[part] == nil then -- déjà caché (déplacé dans le visuel) : garder sa valeur d'avant
			record.modifiers[part] = part.LocalTransparencyModifier
		end
		part.LocalTransparencyModifier = 1
	elseif descendant:IsA("Decal") then -- Texture compris
		local decal = descendant :: Decal
		if record.modifiers[decal] == nil then
			record.modifiers[decal] = decal.LocalTransparencyModifier
		end
		decal.LocalTransparencyModifier = 1
	elseif
		descendant:IsA("LayerCollector")
		or descendant:IsA("ParticleEmitter")
		or descendant:IsA("Beam")
		or descendant:IsA("Trail")
		or descendant:IsA("Light")
		or descendant:IsA("Highlight")
	then
		switchOff(record, descendant, "Enabled")
	elseif descendant:IsA("GuiBase3d") then -- SelectionBox des arêtes noires (BOX_*, L-031)
		switchOff(record, descendant, "Visible")
	end
end

-- Cache en local le visuel `model` du colis porté (pièces, étiquette BB_Box ou BB_Carry, halo,
-- contours), jusqu'à revealAll.
local function hideVisual(model: Instance)
	if hidden[model] then
		return
	end
	local record: Hidden = { modifiers = {}, switches = {}, added = nil }
	hidden[model] = record
	for _, descendant in model:GetDescendants() do
		hideOne(record, descendant)
	end
	record.added = model.DescendantAdded:Connect(function(descendant: Instance)
		hideOne(record, descendant)
	end)
end

-- Remet tout ce que hideVisual a caché (sur un visuel encore là ; un colis déjà retiré est oublié).
local function revealAll()
	holding = false
	for _, record in hidden do
		local added = record.added
		if added then
			added:Disconnect()
		end
		for inst, value in record.modifiers do
			if inst.Parent ~= nil then
				(inst :: any).LocalTransparencyModifier = value
			end
		end
		for _, switch in record.switches do
			if switch.inst.Parent ~= nil then
				(switch.inst :: any)[switch.prop] = true
			end
		end
	end
	table.clear(hidden)
end

-- Début du portage : si Grab joue encore, le colis reste caché jusqu'à ce qu'il l'ait posé.
local function holdUntilGrab()
	local anim = animation
	local afterGrab = if anim then anim.AfterGrab else nil
	if afterGrab == nil then
		return
	end
	local token = holdToken
	local deferred = afterGrab(function(_fromGrab: boolean)
		if token == holdToken then
			revealAll()
		end
	end)
	if not deferred then
		return -- pas de Grab en cours : le colis se voit tout de suite
	end
	holding = true
	local character = localPlayer.Character
	local visual = if character then character:FindFirstChild(VISUAL_NAME) else nil
	if visual then
		hideVisual(visual)
	end
end

local function applyJump()
	if Balance.Carry.CanJump then
		return -- saut autorisé pendant le portage (5.6) : on ne touche à rien
	end
	local humanoid = humanoidOf()
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not carrying)
	end
end

local function watchCharacter(character: Model)
	if characterConnection then
		characterConnection:Disconnect()
	end
	characterConnection = character.ChildAdded:Connect(function(child: Instance)
		if carrying and child:IsA("Tool") then
			task.defer(stowTools) -- pas pendant l'événement : Roblox refuse de changer le parent
		elseif holding and child.Name == VISUAL_NAME then
			hideVisual(child) -- le colis arrive après l'attribut Carrying
		end
	end)
	applyJump()
end

local function onCarryingChanged()
	local now = localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
	if now == carrying then
		return
	end
	carrying = now
	holdToken += 1
	local anim = animation
	if anim then
		anim.SetCarrying(now)
	end
	if now then
		stowTools()
		holdUntilGrab()
	else
		revealAll()
	end
	applyJump()
end

-- Arc-en-ciel des Secrets ----------------------------------------------------------

local function rainbowAt(clock: number): Color3
	local count = #rainbowColors
	local position = (clock / RAINBOW_PERIOD) % 1 * count
	local index = math.floor(position)
	local from = rainbowColors[index + 1]
	local to = rainbowColors[(index + 1) % count + 1]
	return from:Lerp(to, position - index)
end

-- Vague 39 (optimisation téléphone, audit perf-telephone.md, correction 3) : avant, un modèle tagué
-- sans rien à colorer était relu (GetDescendants) à chaque image. Désormais il est lu une fois au tag,
-- puis chaque descendant qui arrive après coup (streaming) est ajouté à son arrivée ; la boucle
-- d'image ne tourne que s'il y a quelque chose à colorer (aucun travail par image sinon).
local colorable = 0 -- pièces Tint, lumières et textes Rarity suivis, tous modèles confondus

local function addOne(rainbow: Rainbow, descendant: Instance): boolean
	if descendant:IsA("BasePart") and descendant.Name == TINT then
		table.insert(rainbow.tints, descendant)
	elseif descendant:IsA("Light") then
		table.insert(rainbow.lights, descendant)
	elseif descendant:IsA("TextLabel") and descendant.Name == RARITY_LABEL then
		table.insert(rainbow.labels, descendant)
	else
		return false
	end
	colorable += 1
	return true
end

local function collect(model: Instance): Rainbow
	local rainbow: Rainbow = { tints = {}, lights = {}, labels = {}, added = nil }
	for _, descendant in model:GetDescendants() do
		addOne(rainbow, descendant)
	end
	return rainbow
end

local function updateRainbows()
	local color = rainbowAt(os.clock())
	for _, rainbow in rainbows do
		for _, part in rainbow.tints do
			part.Color = color
		end
		for _, light in rainbow.lights do
			light.Color = color
		end
		for _, label in rainbow.labels do
			label.TextColor3 = color
		end
	end
end

-- Boucle d'image branchée seulement quand il y a quelque chose à colorer.
local function syncRainbowLoop()
	local connection = rainbowConnection
	if colorable > 0 and connection == nil then
		rainbowConnection = RunService.RenderStepped:Connect(updateRainbows)
	elseif colorable == 0 and connection then
		connection:Disconnect()
		rainbowConnection = nil
	end
end

local function forget(rainbow: Rainbow)
	colorable -= #rainbow.tints + #rainbow.lights + #rainbow.labels
	local added = rainbow.added
	if added then
		added:Disconnect()
	end
end

local function addRainbow(model: Instance)
	local old = rainbows[model]
	if old then
		forget(old) -- tag annoncé deux fois : relu une seule fois
	end
	local rainbow = collect(model)
	rainbow.added = model.DescendantAdded:Connect(function(descendant: Instance)
		if rainbows[model] == rainbow and addOne(rainbow, descendant) then
			syncRainbowLoop()
		end
	end)
	rainbows[model] = rainbow
	syncRainbowLoop()
end

local function removeRainbow(model: Instance)
	local rainbow = rainbows[model]
	if rainbow == nil then
		return
	end
	rainbows[model] = nil
	forget(rainbow)
	syncRainbowLoop()
end

function CarryController.IsCarrying(): boolean
	return carrying
end

function CarryController.Start()
	animation = loadAnimationController()

	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(onCarryingChanged)
	localPlayer.CharacterAdded:Connect(watchCharacter)
	local character = localPlayer.Character
	if character then
		watchCharacter(character)
	end
	onCarryingChanged()

	for _, rarity in Rarities.List do
		local colors = rarity.RainbowColors
		if rarity.Rainbow and colors and #colors >= 2 then
			rainbowColors = colors
			break
		end
	end
	if #rainbowColors >= 2 then
		CollectionService:GetInstanceAddedSignal(RAINBOW_TAG):Connect(addRainbow)
		CollectionService:GetInstanceRemovedSignal(RAINBOW_TAG):Connect(removeRainbow)
		for _, model in CollectionService:GetTagged(RAINBOW_TAG) do
			addRainbow(model)
		end
	end
end

return CarryController

]==========]
-- Faux monde Roblox minimal pour exécuter AnimPlayer, MarkerSounds, AnimTest et
-- AnimationController hors Studio (banc d'essai de l'agent a09, pas livré).
-- SRC est défini avant ce fichier par run.sh (sources des modules).
-- Copie d'a41 (2026-11-08, L-071) : CarryController en plus (Config Balance, Rarities, DeepFreeze ;
-- Color3 ; enfants trouvés par leur nom ; DescendantAdded ; classes du visuel du colis et leurs
-- Enabled / Visible / LocalTransparencyModifier ; CollectionService ; Humanoid:UnequipTools).

local realOs = os
local now = 0
os = { clock = function() return now end, time = realOs.time, date = realOs.date }

LOG = {}
local realPrint = print
local VERBOSE = false
local function log(kind, ...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local line = table.concat(parts, " ")
	table.insert(LOG, { kind = kind, text = line })
	if VERBOSE then
		realPrint(`  [{kind}] {line}`)
	end
end
print = function(...) log("print", ...) end
warn = function(...) log("warn", ...) end

function setVerbose(v) VERBOSE = v end
function clearLog() LOG = {} end
function countLog(pattern, kind)
	local n = 0
	for _, e in LOG do
		if (kind == nil or e.kind == kind) and string.find(e.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end
function dumpLog()
	for _, e in LOG do
		realPrint(`    [{e.kind}] {e.text}`)
	end
end

-- Planificateur -----------------------------------------------------------------
local sleepers = {}
local tickers = {} -- objets mis à jour à chaque pas (pistes, sons)
local DT = 0.05

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		log("error", "ERREUR : " .. tostring(err))
		realPrint("ERREUR dans une tâche : " .. tostring(err))
	end
end

task = {}
function task.spawn(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.wait(dt)
	local co = coroutine.running()
	table.insert(sleepers, { t = now + (dt or 0), co = co })
	coroutine.yield()
	return dt or 0
end
function task.defer(fn, ...)
	local co = coroutine.create(fn)
	local args = table.pack(...)
	table.insert(sleepers, { t = now, co = co, args = args })
end
-- a41 : AnimationController (délai de secours de Grab).
function task.delay(dt, fn, ...)
	local co = coroutine.create(fn)
	local args = table.pack(...)
	table.insert(sleepers, { t = now + (dt or 0), co = co, args = args })
	return co
end

local function tick()
	now += DT
	local snapshot = {}
	for obj in tickers do
		table.insert(snapshot, obj)
	end
	for _, obj in snapshot do
		if tickers[obj] then
			obj:_tick(DT)
		end
	end
	local ready = {}
	local keep = {}
	for _, s in sleepers do
		if s.t <= now then
			table.insert(ready, s)
		else
			table.insert(keep, s)
		end
	end
	sleepers = keep
	for _, s in ready do
		if coroutine.status(s.co) == "suspended" then
			if s.args then
				resume(s.co, table.unpack(s.args, 1, s.args.n))
			else
				resume(s.co)
			end
		end
	end
end

function runFor(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		tick()
	end
end

-- Lance `fn` dans une tâche et fait avancer le temps jusqu'à sa fin (ou `limit` s).
function runTask(fn, limit)
	local co = coroutine.create(fn)
	resume(co)
	local stop = now + (limit or 60)
	while coroutine.status(co) ~= "dead" and now < stop do
		tick()
	end
	return coroutine.status(co) == "dead"
end

-- Signaux -----------------------------------------------------------------------
Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ _conns = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true, _fn = fn }
	function conn.Disconnect(c)
		c.Connected = false
	end
	table.insert(self._conns, conn)
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Fire(...)
	local list = table.clone(self._conns)
	for _, conn in list do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
	local alive = {}
	for _, conn in self._conns do
		if conn.Connected then
			table.insert(alive, conn)
		end
	end
	self._conns = alive
end
function Signal:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		resume(co, ...)
	end)
	return coroutine.yield()
end
function Signal:count()
	local n = 0
	for _, c in self._conns do
		if c.Connected then
			n += 1
		end
	end
	return n
end

-- Enum, CFrame, Vector3 ---------------------------------------------------------
Enum = {
	AnimationPriority = { Idle = { Name = "Idle" }, Movement = { Name = "Movement" }, Action = { Name = "Action" }, Core = { Name = "Core" } },
	AssetFetchStatus = { Success = { Name = "Success" }, Failure = { Name = "Failure" } },
}
CFrame = { Angles = function(x, y, z) return { kind = "CFrame", x = x, y = y, z = z } end }
Vector3 = {}
function Vector3.new(x, y, z)
	x, y, z = x or 0, y or 0, z or 0
	return { X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z) }
end
-- a41 : Config/Rarities (Color3.fromHex).
Color3 = {
	new = function(r, g, b) return { R = r, G = g, B = b } end,
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
	fromHex = function(hex)
		local h = string.gsub(hex, "#", "")
		return { R = tonumber(string.sub(h, 1, 2), 16) / 255, G = tonumber(string.sub(h, 3, 4), 16) / 255, B = tonumber(string.sub(h, 5, 6), 16) / 255 }
	end,
}

-- Instances ---------------------------------------------------------------------
local ISA = {
	-- a41 : visuel du colis porté (CarryController le cache pendant Grab).
	BillboardGui = { LayerCollector = true, GuiBase2d = true },
	TextLabel = { GuiObject = true, GuiBase2d = true },
	PointLight = { Light = true },
	ParticleEmitter = {},
	Beam = {},
	Highlight = {},
	SelectionBox = { GuiBase3d = true, PVAdornment = true },
	Decal = { FaceInstance = true },
	Texture = { Decal = true, FaceInstance = true },
	Attachment = {},
	Tool = { BackpackItem = true },
	Part = { BasePart = true, PVInstance = true },
	Model = { PVInstance = true },
	Folder = {},
	ModuleScript = { LuaSourceContainer = true },
	Animation = {},
	Animator = {},
	Humanoid = {},
	Sound = {},
	KeyframeSequence = { AnimationClip = true },
	Keyframe = {},
	Pose = { PoseBase = true },
	KeyframeMarker = {},
	AnimationTrack = {},
	DataModel = { ServiceProvider = true },
	Service = {},
	Player = {},
}

local Inst = {}
local methods = {}

local function rawNew(className, name)
	local data = {
		ClassName = className,
		Name = name or className,
		_children = {},
		_parent = nil,
		_attrs = {},
		_attrSignals = {},
		_destroyed = false,
		Destroying = Signal.new(),
		AncestryChanged = Signal.new(),
		ChildAdded = Signal.new(), ChildRemoved = Signal.new(),
		DescendantAdded = Signal.new(), -- a41
		Archivable = true,
	}
	return setmetatable(data, Inst)
end

Inst.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	local m = methods[key]
	if m then
		return m
	end
	local getter = rawget(self, "_get_" .. key)
	if getter then
		return getter(self)
	end
	-- a41 : un enfant par son nom (script.Parent.DeepFreeze).
	for _, c in rawget(self, "_children") or {} do
		if c.Name == key then
			return c
		end
	end
	return nil
end
Inst.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old == value then
			return
		end
		if rawget(self, "_destroyed") and value ~= nil then
			error("The Parent property of " .. self.Name .. " is locked")
		end
		if old then
			local i = table.find(old._children, self)
			if i then
				table.remove(old._children, i)
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(value._children, self)
			value.ChildAdded:Fire(self)
			-- a41 : DescendantAdded sur chaque ancêtre, pour l'objet et ses descendants.
			local added = { self }
			for _, d in self:GetDescendants() do
				table.insert(added, d)
			end
			local ancestor = value
			while ancestor do
				for _, d in added do
					ancestor.DescendantAdded:Fire(d)
				end
				ancestor = rawget(ancestor, "_parent")
			end
		end
		self.AncestryChanged:Fire(self, value)
		return
	end
	rawset(self, key, value)
end
Inst.__tostring = function(self)
	return self.Name
end

function methods.GetChildren(self)
	return table.clone(self._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in i._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in self._children do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in self._children do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, class)
	for _, c in self._children do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function methods.WaitForChild(self, name, timeout)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	if timeout == nil then
		error(`WaitForChild infini sur {self:GetFullName()}.{name}`)
	end
	local stop = now + timeout
	while now < stop do
		task.wait(DT)
		found = self:FindFirstChild(name)
		if found then
			return found
		end
	end
	return nil
end
function methods.IsA(self, class)
	return self.ClassName == class or class == "Instance" or (ISA[self.ClassName] or {})[class] == true
end
function methods.IsDescendantOf(self, ancestor)
	local p = self.Parent
	while p do
		if p == ancestor then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.GetFullName(self)
	local names = {}
	local i = self
	while i and i.ClassName ~= "DataModel" do
		table.insert(names, 1, i.Name)
		i = i.Parent
	end
	return table.concat(names, ".")
end
function methods.Destroy(self)
	if rawget(self, "_destroyed") then
		return
	end
	self.Destroying:Fire()
	for _, c in table.clone(self._children) do
		c:Destroy()
	end
	self.Parent = nil
	rawset(self, "_destroyed", true)
	tickers[self] = nil
end
function methods.Clone(self)
	local copy = rawNew(self.ClassName, self.Name)
	for k, v in pairs(self) do
		if type(k) == "string" and not string.match(k, "^_") and k ~= "Destroying" and k ~= "AncestryChanged" and k ~= "ChildAdded" then
			rawset(copy, k, v)
		end
	end
	for k, v in pairs(self) do
		if type(k) == "string" and string.match(k, "^_get_") then
			rawset(copy, k, v)
		end
	end
	local init = rawget(self, "_onClone")
	if init then
		init(copy)
	end
	for _, c in self._children do
		c:Clone().Parent = copy
	end
	return copy
end
function methods.GetAttribute(self, name)
	return self._attrs[name]
end
function methods.SetAttribute(self, name, value)
	self._attrs[name] = value
	local s = self._attrSignals[name]
	if s then
		s:Fire()
	end
end
function methods.GetAttributeChangedSignal(self, name)
	local s = self._attrSignals[name]
	if not s then
		s = Signal.new()
		self._attrSignals[name] = s
	end
	return s
end

-- Pistes d'animation ------------------------------------------------------------
ASSETS = {} -- [AnimationId] = { length, loop, markers = { { name, time, value } } }
local tempSequences = {}
local tempCount = 0

local function newTrack(animator, animation)
	local asset = ASSETS[animation.AnimationId] or tempSequences[animation.AnimationId]
	local track = rawNew("AnimationTrack", animation.Name)
	track.Animation = animation
	track.IsPlaying = false
	track.TimePosition = 0
	track.Length = if asset then asset.length else 0
	track.Looped = if asset then asset.loop else false
	track.Speed = 1
	track.WeightTarget = 1
	track.Stopped = Signal.new()
	track._asset = asset
	track._markerSignals = {}
	track._plays = 0
	function track.Play(t, fade, weight, speed)
		if t._asset == nil then
			return -- animation illisible : ne se joue pas
		end
		t._plays += 1
		t.IsPlaying = true
		t.TimePosition = 0
		if weight then
			t.WeightTarget = weight
		end
		if speed then
			t.Speed = speed
		end
		tickers[t] = true
	end
	function track.Stop(t, fade)
		if t.IsPlaying then
			t.IsPlaying = false
			tickers[t] = nil
			t.Stopped:Fire()
		end
	end
	function track.AdjustWeight(t, w)
		t.WeightTarget = w
	end
	function track.AdjustSpeed(t, s)
		t.Speed = s
	end
	function track.GetMarkerReachedSignal(t, name)
		local s = t._markerSignals[name]
		if not s then
			s = Signal.new()
			t._markerSignals[name] = s
		end
		return s
	end
	function track._tick(t, dt)
		if not t.IsPlaying then
			return
		end
		local before = t.TimePosition
		local after = before + dt * t.Speed
		for _, m in t._asset.markers do
			if (m.time > before or (before == 0 and m.time == 0)) and m.time <= after then
				local s = t._markerSignals[m.name]
				if s then
					s:Fire(m.value or "")
				end
			end
		end
		if after >= t.Length then
			if t.Looped then
				t.TimePosition = after - t.Length
			else
				t.TimePosition = t.Length
				t.IsPlaying = false
				tickers[t] = nil
				t.Stopped:Fire()
			end
		else
			t.TimePosition = after
		end
	end
	return track
end

-- Sons --------------------------------------------------------------------------
SOUND_LENGTH = { ["rbxasset://sounds/volume_slider.ogg"] = 0.2 }
SOUND_LOG = {}
local function soundTick(s, dt)
	s._age += dt
	local len = SOUND_LENGTH[s.SoundId or ""]
	if not s.IsLoaded and len and s._age >= 0.1 then
		s.IsLoaded = true
		s.TimeLength = len
	end
	if s.IsPlaying and s.IsLoaded then
		s._playAge = (s._playAge or 0) + dt
		if s._playAge >= s.TimeLength then
			s.IsPlaying = false
			s.Playing = false
			s.Ended:Fire()
		end
	end
end
local function setupSound(s)
	rawset(s, "_age", 0)
	rawset(s, "_tick", soundTick)
	rawset(s, "_played", 0)
	s.IsLoaded = false
	s.TimeLength = 0
	s.Playing = false
	s.IsPlaying = false
	s.Ended = Signal.new()
	tickers[s] = true
end
function methods.Play(self)
	if self.ClassName ~= "Sound" then
		error("Play sur " .. self.ClassName)
	end
	self.Playing = true
	self.IsPlaying = true
	rawset(self, "_played", self._played + 1)
	rawset(self, "_playAge", 0)
	table.insert(SOUND_LOG, { name = self.Name, parent = self.Parent and self.Parent.Name or "nil", sound = self })
end

-- Instance.new ------------------------------------------------------------------
Instance = {}
function Instance.new(className)
	local i = rawNew(className)
	if className == "Sound" then
		setupSound(i)
		rawset(i, "_onClone", setupSound)
		rawset(i, "SoundId", "")
	elseif className == "Animation" then
		rawset(i, "AnimationId", "")
	elseif className == "Keyframe" then
		rawset(i, "Time", 0)
		rawset(i, "AddMarker", function(k, marker)
			marker.Parent = k
		end)
	elseif className == "Pose" then
		rawset(i, "CFrame", nil)
	elseif className == "KeyframeSequence" then
		rawset(i, "Loop", true)
	elseif className == "Animator" then
		rawset(i, "_loads", 0)
		rawset(i, "LoadAnimation", function(a, animation)
			if not a:IsDescendantOf(game) then
				error("LoadAnimation requires the Animator object to be a descendant of the game object")
			end
			a._loads += 1
			return newTrack(a, animation)
		end)
	elseif className == "Humanoid" then
		rawset(i, "Running", Signal.new())
	elseif className == "Part" then
		rawset(i, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
		rawset(i, "LocalTransparencyModifier", 0) -- a41
	elseif className == "Decal" or className == "Texture" then -- a41
		rawset(i, "LocalTransparencyModifier", 0)
	elseif className == "BillboardGui" or className == "PointLight" or className == "ParticleEmitter" or className == "Beam" or className == "Highlight" then -- a41
		rawset(i, "Enabled", true)
	elseif className == "SelectionBox" then -- a41
		rawset(i, "Visible", true)
	end
	return i
end
-- a41 : CarryController range les outils au début du portage.
function methods.UnequipTools(_self) end

-- Monde -------------------------------------------------------------------------
local moduleCache = {}
local realRequire = require
require = function(inst)
	if type(inst) ~= "table" or inst.ClassName ~= "ModuleScript" then
		error("require : pas un ModuleScript")
	end
	local cached = moduleCache[inst]
	if cached ~= nil then
		return cached
	end
	local fn, err = loadstring(inst._source, "=" .. inst.Name)
	if not fn then
		error(err)
	end
	-- a41 : chaque module garde son `script` (CarryController le lit dans Start, après le require).
	setfenv(fn, setmetatable({ script = inst }, { __index = getfenv(1) }))
	local previous = script
	script = inst
	local result = fn()
	script = previous
	moduleCache[inst] = result
	return result
end

local function module(parent, name, source)
	local m = rawNew("ModuleScript", name)
	rawset(m, "_source", source)
	m.Parent = parent
	return m
end

function newFolder(parent, name)
	local f = rawNew("Folder", name)
	f.Parent = parent
	return f
end

function addAnimation(folder, name, id, asset)
	local a = Instance.new("Animation")
	a.Name = name
	a.AnimationId = id
	a.Parent = folder
	if asset then
		ASSETS[id] = asset
	end
	return a
end

function addSound(folder, name, soundId)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Parent = folder
	return s
end

-- Personnage R15 minimal : Humanoid + Animator + HumanoidRootPart.
function newCharacter(name)
	local character = rawNew("Model", name or "Ironix")
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Parent = character
	local animator = Instance.new("Animator")
	animator.Name = "Animator"
	animator.Parent = humanoid
	return character, humanoid, animator, hrp
end

-- Construit un DataModel neuf avec les modules ; `isClient` pour RunService:IsClient().
function newWorld(isClient)
	moduleCache = {}
	tickers = {}
	sleepers = {}
	ASSETS = {}
	tempSequences = {}
	SOUND_LOG = {}
	local dm = rawNew("DataModel", "Game")
	game = dm
	local services = {}
	local function service(name)
		local s = rawNew("Service", name)
		s.Parent = dm
		services[name] = s
		return s
	end
	local RS = service("ReplicatedStorage")
	local WS = service("Workspace")
	local Players = service("Players")
	local RunService = service("RunService")
	rawset(RunService, "IsStudio", function() return true end)
	rawset(RunService, "IsClient", function() return isClient end)
	local ContentProvider = service("ContentProvider")
	PRELOADED = {}
	rawset(ContentProvider, "PreloadAsync", function(_, list, cb)
		for _, inst in list do
			table.insert(PRELOADED, inst.Name)
			local status = if ASSETS[inst.AnimationId] then Enum.AssetFetchStatus.Success else Enum.AssetFetchStatus.Failure
			if cb then
				cb(inst.AnimationId, status)
			end
		end
	end)
	local Debris = service("Debris")
	rawset(Debris, "AddItem", function(_, inst, t)
		local co = coroutine.create(function()
			task.wait(t)
			inst:Destroy()
		end)
		resume(co)
	end)
	service("SoundService")
	local KSP = service("KeyframeSequenceProvider")
	rawset(KSP, "RegisterKeyframeSequence", function(_, seq)
		if KSP_REFUSE then
			error("RegisterKeyframeSequence refusé (bouchon)")
		end
		tempCount += 1
		local id = "rbxtemp://" .. tempCount
		local length, markers = 0, {}
		for _, frame in seq:GetChildren() do
			if frame.ClassName == "Keyframe" then
				length = math.max(length, frame.Time)
				for _, m in frame:GetChildren() do
					if m.ClassName == "KeyframeMarker" then
						table.insert(markers, { name = m.Name, time = frame.Time, value = m.Value })
					end
				end
			end
		end
		tempSequences[id] = { length = length, loop = seq.Loop, markers = markers }
		return id
	end)
	rawset(dm, "GetService", function(_, name)
		local s = services[name]
		if not s then
			error("service inconnu " .. name)
		end
		return s
	end)
	rawset(dm, "IsLoaded", function() return true end)
	rawset(dm, "Loaded", Signal.new())

	local player = rawNew("Player", "Ironix")
	player.Parent = Players
	rawset(player, "CharacterAdded", Signal.new())
	rawset(player, "CharacterRemoving", Signal.new())
	rawset(Players, "LocalPlayer", player)

	local shared = newFolder(RS, "Shared")
	local contract = newFolder(shared, "Contract")
	module(contract, "Animations", SRC["Contract/Animations"])
	local anim = newFolder(shared, "Anim")
	module(anim, "AnimPlayer", SRC["Anim/AnimPlayer"])
	module(anim, "MarkerSounds", SRC["Anim/MarkerSounds"])
	module(anim, "AnimTest", SRC["Anim/AnimTest"])
	-- a41 : Config lue par CarryController, et les deux contrôleurs dans un même dossier (CarryController
	-- trouve AnimationController à côté de lui).
	local config = newFolder(shared, "Config")
	module(config, "DeepFreeze", SRC["Config/DeepFreeze"])
	module(config, "Balance", SRC["Config/Balance"])
	module(config, "Rarities", SRC["Config/Rarities"])
	local controllers = newFolder(newFolder(dm, "Client"), "Controllers")
	local controller = module(controllers, "AnimationController", SRC["AnimationController"])
	local carryController = module(controllers, "CarryController", SRC["CarryController"])
	rawset(RunService, "RenderStepped", Signal.new())
	local CS = service("CollectionService")
	local tagged, addedSignals, removedSignals = {}, {}, {}
	local function sig(map, tag)
		map[tag] = map[tag] or Signal.new()
		return map[tag]
	end
	rawset(CS, "GetTagged", function(_, tag) return table.clone(tagged[tag] or {}) end)
	rawset(CS, "GetInstanceAddedSignal", function(_, tag) return sig(addedSignals, tag) end)
	rawset(CS, "GetInstanceRemovedSignal", function(_, tag) return sig(removedSignals, tag) end)
	rawset(CS, "AddTag", function(_, inst, tag)
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], inst)
		sig(addedSignals, tag):Fire(inst)
	end)

	return {
		dm = dm,
		RS = RS,
		WS = WS,
		player = player,
		shared = shared,
		anim = anim,
		controllerModule = controller,
		carryModule = carryController,
		require = function(path)
			return require(shared:FindFirstChild(path, true))
		end,
	}
end

-- Pose un personnage dans le Workspace et prévient comme Roblox.
function spawnCharacter(world, name)
	local old = world.player.Character
	if old then
		world.player.CharacterRemoving:Fire(old)
		old:Destroy()
	end
	local character, humanoid, animator, hrp = newCharacter(name)
	rawset(world.player, "Character", character)
	character.Parent = world.WS
	world.player.CharacterAdded:Fire(character)
	return character, humanoid, animator, hrp
end

-- Assertions --------------------------------------------------------------------
PASS, FAIL = 0, 0
function check(cond, label)
	if cond then
		PASS += 1
	else
		FAIL += 1
		realPrint("  ÉCHEC : " .. label)
	end
end
function section(name)
	realPrint("== " .. name)
end
function report()
	realPrint(`Résultat : {PASS} vérification(s) OK, {FAIL} échec(s)`)
end
realPrintFn = realPrint
-- Banc a41 (2026-11-08, liaison L-071, points 3 et 4), partie animations :
--   AnimationController : Grab pose le colis, puis CarryIdle / CarryRun prennent sa suite (AfterGrab),
--   BenchLift pas relancé en pleine répétition, TreadmillRun suit TrainingMachine ;
--   CarryController : le colis du porteur reste caché jusqu'au geste de Grab (marqueur Grab).
-- Faux Roblox : fake.luau (copie de celui d'a09, complétée par a41).

local function marker(name, time, value)
	return { name = name, time = time, value = value }
end

-- Monde neuf, dossier des animations du joueur, et un personnage dont on suit les pistes chargées
-- (tracks[nom] = dernière piste chargée pour ce nom), sans rien jouer.
local function setup(animations)
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local pf = newFolder(newFolder(assets, "Animations"), "Player")
	for name, spec in animations do
		addAnimation(pf, name, spec.id, spec)
	end
	w.tracks = {}
	return w
end
local function spawnTracked(w, name)
	local old = w.player.Character
	if old then
		w.player.CharacterRemoving:Fire(old)
		old:Destroy()
	end
	local character, humanoid, animator, hrp = newCharacter(name or "Ironix")
	local load = animator.LoadAnimation
	rawset(animator, "LoadAnimation", function(a, animation)
		local t = load(a, animation)
		w.tracks[animation.Name] = t
		return t
	end)
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.player.CharacterAdded:Fire(character)
	return character, humanoid, animator, hrp
end
local function startAC(w)
	local AC = require(w.controllerModule)
	check(runTask(function()
		AC.Start()
	end, 5), "AnimationController.Start se termine")
	runFor(0.1)
	return AC
end
local function playing(w, name)
	local t = w.tracks[name]
	return t ~= nil and t.IsPlaying
end

local GRAB_MARKED = { id = "rbxassetid://40", length = 0.6, loop = false, markers = { marker("Grab", 0.3) } }
local CARRY_IDLE = { id = "rbxassetid://32", length = 1, loop = true, markers = {} }
local CARRY_RUN = { id = "rbxassetid://33", length = 1, loop = true, markers = {} }

---------------------------------------------------------------------------------
section("A1 Sans Grab en cours : AfterGrab tout de suite, portage comme avant")
do
	local w = setup({ CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	local _, humanoid, _, hrp = spawnTracked(w)
	local AC = startAC(w)
	local called, from = 0, nil
	local deferred = AC.AfterGrab(function(f)
		called += 1
		from = f
	end)
	check(deferred == false and called == 1 and from == false, "AfterGrab sans Grab : appelé tout de suite, avec false, renvoie false")
	AC.SetCarrying(true)
	check(playing(w, "CarryIdle"), "SetCarrying(true) : CarryIdle tout de suite")
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(12, 0, 0))
	humanoid.Running:Fire(12)
	check(playing(w, "CarryRun") and not playing(w, "CarryIdle"), "en courant : CarryRun")
	AC.SetCarrying(false)
	check(not playing(w, "CarryRun") and not playing(w, "CarryIdle"), "SetCarrying(false) : tout s'arrête")
	-- Grab pas livrée : PlayPlayer rend nil, le portage n'attend rien.
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	check(AC.PlayPlayer("Grab") == nil, "Grab pas livrée : nil")
	AC.SetCarrying(true)
	check(playing(w, "CarryIdle"), "Grab pas livrée : CarryIdle tout de suite")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A2 Grab avec marqueur Grab (0,3 s) : la boucle de portage attend le marqueur")
do
	local w = setup({ Grab = GRAB_MARKED, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	local grab = AC.PlayPlayer("Grab")
	check(grab ~= nil and grab.IsPlaying, "Grab joue (lancé au ramassage)")
	runFor(0.05)
	local calls = {}
	local deferred = AC.AfterGrab(function(f)
		table.insert(calls, { t = os.clock(), from = f })
	end)
	check(deferred == true and #calls == 0, "AfterGrab pendant Grab : différé")
	AC.SetCarrying(true) -- l'attribut Carrying arrive (le serveur a accepté la prise)
	check(not playing(w, "CarryIdle"), "pendant Grab : pas encore de CarryIdle (pas de mélange de deux pistes Action)")
	local t0 = os.clock()
	runFor(0.15)
	check(not playing(w, "CarryIdle") and #calls == 0, "toujours en attente avant le marqueur")
	runFor(0.15)
	check(playing(w, "CarryIdle"), "au marqueur Grab : CarryIdle")
	check(not grab.IsPlaying, "Grab s'efface (fondu) quand la boucle prend sa suite")
	check(#calls == 1 and calls[1].from == true, "AfterGrab appelé une fois, au marqueur (fromGrab = true)")
	check(#calls == 1 and math.abs(calls[1].t - (t0 + 0.25)) <= 0.051, `au marqueur : 0,3 s après le lancement de Grab ({#calls > 0 and calls[1].t - t0 + 0.05})`)
	local again = 0
	check(AC.AfterGrab(function() again += 1 end) == false and again == 1, "après le marqueur : AfterGrab tout de suite")
	runFor(2)
	check(#calls == 1, "pas de second appel (fin de Grab, délai)")
	AC.SetCarrying(false)
	check(not playing(w, "CarryIdle"), "fin du portage")
end

---------------------------------------------------------------------------------
section("A3 Grab sans marqueur : la boucle part à la fin de Grab")
do
	local w = setup({ Grab = { id = "rbxassetid://41", length = 0.5, loop = false, markers = {} }, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(0.35)
	check(not playing(w, "CarryIdle"), "à 0,4 s : Grab joue encore, pas de CarryIdle")
	runFor(0.15)
	check(playing(w, "CarryIdle"), "à la fin de Grab (0,5 s) : CarryIdle")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A4 Grab qui ne finit pas (durée inconnue) : délai de secours GRAB_MAX_WAIT (1,5 s)")
do
	-- Durée 0 et une piste qui ne s'arrête jamais : comme une animation pas encore chargée.
	local w = setup({ Grab = { id = "rbxassetid://42", length = 0, loop = true, markers = {} }, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(1.35)
	check(not playing(w, "CarryIdle"), "à 1,4 s : toujours en attente")
	runFor(0.15)
	check(playing(w, "CarryIdle") and not playing(w, "Grab"), "à 1,5 s : CarryIdle, Grab arrêtée")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A4b Grab long (2,5 s), marqueur tardif (2 s) : pas devancé par GRAB_MAX_WAIT")
do
	local w = setup({ Grab = { id = "rbxassetid://43", length = 2.5, loop = false, markers = { marker("Grab", 2) } }, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(1.85)
	check(not playing(w, "CarryIdle"), "à 1,9 s : toujours en attente (le marqueur est à 2 s)")
	runFor(0.15)
	check(playing(w, "CarryIdle"), "au marqueur tardif : CarryIdle")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A5 Portage fini pendant Grab, colis arrivé après Grab, course pendant l'attente")
do
	local w = setup({ Grab = GRAB_MARKED, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	local _, humanoid, _, hrp = spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(0.05)
	AC.SetCarrying(false) -- rattrapé, colis perdu avant la fin du geste
	runFor(0.4)
	check(not playing(w, "CarryIdle") and not playing(w, "CarryRun"), "portage fini avant le marqueur : rien ne part au marqueur")
	runFor(0.5)
	-- Le colis arrive après Grab (latence) : tout de suite.
	AC.PlayPlayer("Grab")
	runFor(0.7)
	AC.SetCarrying(true)
	check(playing(w, "CarryIdle"), "attribut arrivé après la fin de Grab : CarryIdle tout de suite")
	AC.SetCarrying(false)
	-- Course pendant l'attente : CarryRun au marqueur, pas avant.
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(14, 0, 0))
	humanoid.Running:Fire(14)
	check(not playing(w, "CarryRun") and not playing(w, "CarryIdle"), "il court pendant Grab : rien encore")
	runFor(0.3)
	check(playing(w, "CarryRun") and not playing(w, "CarryIdle"), "au marqueur, en courant : CarryRun")
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	humanoid.Running:Fire(0)
	check(playing(w, "CarryIdle") and not playing(w, "CarryRun"), "arrêté : CarryIdle")
	AC.SetCarrying(false)
	-- Deux Grab de suite : le second relance l'attente, le marqueur du second libère.
	AC.PlayPlayer("Grab")
	runFor(0.1)
	AC.PlayPlayer("Grab") -- relancé du début
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(0.2)
	check(not playing(w, "CarryIdle"), "Grab relancé : on attend son marqueur à lui")
	runFor(0.1)
	check(playing(w, "CarryIdle"), "marqueur du Grab relancé : CarryIdle")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A6 BenchLift : pas relancé en pleine répétition ; TreadmillRun suit TrainingMachine")
do
	local w = setup({
		BenchLift = { id = "rbxassetid://31", length = 0.8, loop = false, markers = { marker("Top", 0.4) } },
		BenchIdle = { id = "rbxassetid://35", length = 2, loop = true, markers = {} },
		TreadmillRun = { id = "rbxassetid://30", length = 1, loop = true, markers = {} },
	})
	spawnTracked(w)
	w.player:SetAttribute("BenchReps", 0)
	local AC = startAC(w)
	local tops = 0
	AC.OnMarker("BenchLift", "Top", function()
		tops += 1
	end)
	-- Copie a134 (rééquilibrage v2) : plus de banc. Ni TrainingMachine = "Bench" ni BenchReps ne jouent quoi que
	-- ce soit ; BenchLift et BenchIdle ne sont plus au contrat ni jouées par le contrôleur, même livrées.
	w.player:SetAttribute("TrainingMachine", "Bench")
	check(not playing(w, "BenchIdle"), "a134 : au banc : BenchIdle ne joue plus")
	w.player:SetAttribute("BenchReps", 1)
	runFor(0.9)
	w.player:SetAttribute("BenchReps", 2)
	runFor(1)
	check(tops == 0 and not playing(w, "BenchLift") and not playing(w, "BenchIdle"), `a134 : hausses de BenchReps : rien ne joue, aucun marqueur Top ({tops})`)
	w.player:SetAttribute("TrainingMachine", nil)
	w.player:SetAttribute("TrainingMachine", "Treadmill")
	check(playing(w, "TreadmillRun"), "sur le tapis (attribut posé par TrainingService) : TreadmillRun")
	spawnTracked(w, "Ironix2")
	runFor(0.1)
	check(playing(w, "TreadmillRun"), "nouveau personnage, toujours sur le tapis : TreadmillRun rejouée")
	w.player:SetAttribute("TrainingMachine", nil)
	check(not playing(w, "TreadmillRun"), "descendu du tapis : TreadmillRun arrêtée")
end

---------------------------------------------------------------------------------
section("A7 CarryController : colis du porteur caché jusqu'au marqueur Grab")
local function makeVisual(parent)
	local model = Instance.new("Model")
	model.Name = "CarryVisual"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Parent = model
	local tint = Instance.new("Part")
	tint.Name = "Tint"
	tint.Parent = model
	local decal = Instance.new("Decal")
	decal.Name = "Tape"
	decal.Parent = box
	local label = Instance.new("Attachment")
	label.Name = "LabelPoint"
	label.Parent = box
	local gui = Instance.new("BillboardGui")
	gui.Name = "BB_Box"
	gui.Parent = label
	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.Parent = gui
	local halo = Instance.new("Attachment")
	halo.Name = "HaloPoint"
	halo.Parent = box
	local light = Instance.new("PointLight")
	light.Parent = halo
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Parent = halo
	local ray = Instance.new("Beam")
	ray.Parent = halo
	local outline = Instance.new("Highlight")
	outline.Name = "OutlineHighlight"
	outline.Parent = model
	local edges = Instance.new("SelectionBox")
	edges.Name = "Edges"
	edges.Parent = model
	local off = Instance.new("Beam") -- éteint par Clément : doit le rester
	off.Name = "OffBeam"
	off.Enabled = false
	off.Parent = halo
	model.Parent = parent
	return { model = model, parts = { box, tint }, decal = decal, gui = gui, light = light, sparkles = sparkles, ray = ray, outline = outline, edges = edges, off = off }
end
local function isHidden(v)
	return v.parts[1].LocalTransparencyModifier == 1
		and v.parts[2].LocalTransparencyModifier == 1
		and v.decal.LocalTransparencyModifier == 1
		and v.gui.Enabled == false
		and v.light.Enabled == false
		and v.sparkles.Enabled == false
		and v.ray.Enabled == false
		and v.outline.Enabled == false
		and v.edges.Visible == false
end
local function isShown(v)
	return v.parts[1].LocalTransparencyModifier == 0
		and v.parts[2].LocalTransparencyModifier == 0
		and v.decal.LocalTransparencyModifier == 0
		and v.gui.Enabled
		and v.light.Enabled
		and v.sparkles.Enabled
		and v.ray.Enabled
		and v.outline.Enabled
		and v.edges.Visible
		and v.off.Enabled == false
end
do
	local w = setup({ Grab = GRAB_MARKED, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	local character = spawnTracked(w)
	local AC = startAC(w)
	local CC = require(w.carryModule)
	check(runTask(function()
		CC.Start()
	end, 5), "CarryController.Start se termine")

	-- 1. Le colis arrive dans le personnage, puis l'attribut Carrying (ordre du serveur).
	AC.PlayPlayer("Grab")
	runFor(0.05)
	local v = makeVisual(character)
	w.player:SetAttribute("Carrying", "Rare")
	check(CC.IsCarrying(), "CarryController : porte")
	check(isHidden(v), "pendant Grab : colis, étiquette, halo et contours cachés en local")
	check(v.off.Enabled == false, "un Beam déjà éteint reste éteint")
	-- Une pièce ajoutée au colis pendant l'attente est cachée aussi.
	local late = Instance.new("Part")
	late.Name = "Late"
	late.Parent = v.model
	check(late.LocalTransparencyModifier == 1, "pièce arrivée après coup : cachée aussi")
	runFor(0.3)
	check(isShown(v) and late.LocalTransparencyModifier == 0, "au marqueur Grab : tout réapparaît (et ce qui était éteint le reste)")
	check(playing(w, "CarryIdle"), "et CarryIdle tient le colis")
	w.player:SetAttribute("Carrying", nil)
	v.model:Destroy()
	runFor(0.2)

	-- 2. L'attribut d'abord, le colis ensuite (réplication dans l'autre ordre).
	AC.PlayPlayer("Grab")
	runFor(0.05)
	w.player:SetAttribute("Carrying", "Common")
	runFor(0.05)
	local v2 = makeVisual(character)
	check(isHidden(v2), "colis arrivé après l'attribut : caché à son arrivée")
	runFor(0.25)
	check(isShown(v2), "au marqueur : visible")
	w.player:SetAttribute("Carrying", nil)
	v2.model:Destroy()
	runFor(0.2)

	-- 3. Sans Grab en cours (colis du camion ramassé sans animation, Grab pas livrée…) : jamais caché.
	local v3 = makeVisual(character)
	w.player:SetAttribute("Carrying", "Epic")
	check(isShown(v3), "sans Grab en cours : le colis se voit tout de suite")
	w.player:SetAttribute("Carrying", nil)
	v3.model:Destroy()
	runFor(0.2)

	-- 4. Portage fini pendant l'attente (rattrapé) : rien ne reste caché, le suivant repart propre.
	clearLog()
	AC.PlayPlayer("Grab")
	runFor(0.05)
	local v4 = makeVisual(character)
	w.player:SetAttribute("Carrying", "Rare")
	check(isHidden(v4), "caché pendant Grab")
	runFor(0.05)
	w.player:SetAttribute("Carrying", nil)
	check(isShown(v4), "fin du portage pendant l'attente : tout est remis")
	v4.model:Destroy()
	runFor(0.5)
	check(countLog("ERREUR", nil) == 0, "aucune erreur (colis retiré)")
	local v5 = makeVisual(character)
	w.player:SetAttribute("Carrying", "Rare")
	check(isShown(v5), "portage suivant, sans Grab : visible")
	w.player:SetAttribute("Carrying", nil)
	v5.model:Destroy()
end

report()
