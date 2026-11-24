SRC = {}
SRC["Contract/Animations"] = [==========[
--!strict
-- Contrat d'animations (doc, section 2.4 ; liaison, section 3.2) : 21 animations, plus l'Idle facultatif des
-- conducteurs du camion (Animations.Driver, L-071) ; témoins, foule (Animations.Witness, Animations.Crowd).
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

-- 25 animations du joueur (15 avant le retrait d'Unbox et de Celebrate, vague 52 ; BenchLift et BenchIdle
-- retirés en v2 ; HoldItem ajoutée en vague 56 ; TrapStuck et TrapNetted en vague 72 ; les 7 Unbox_* de L-237 ;
-- Unbox_Stomp et Unbox_Slam en vague 74).
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
	-- Vague 72 (a243, L-218, noms proposés par Clément) : joueur pris par un piège de boutique (TrapController),
	-- en boucle tant que l'effet dure. Pas encore livrées : orange au ContractChecker, Stunned se joue à leur place.
	{ Name = "TrapStuck", Loop = true, Priority = "Action" },
	{ Name = "TrapNetted", Loop = true, Priority = "Action" },
	-- L-237 (Clément, livrées pour la nouvelle ouverture du colis, L-236) : corps entier, sans boucle, marqueur Impact à
	-- chaque moment fort (Unbox_Hammer : Top, masse en l'air, puis Impact). Pas encore jouées par le code.
	{ Name = "Unbox_Hammer", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Unbox_Saw", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Unbox_Crowbar", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Unbox_Drill", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Unbox_Kick", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Unbox_Search", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Unbox_Inspect", Loop = false, Priority = "Action", Marker = "Impact" },
	-- Vague 74 (a257, L-258, noms proposés par Clément) : debout sur le colis. Unbox_Stomp : deux sauts à pieds joints,
	-- Impact à chaque atterrissage ; Unbox_Slam, le coup final : Top en haut du bond, Impact au coup qui casse le colis.
	-- Pas encore livrées : orange au ContractChecker, l'action tirée et Unbox_Hammer se jouent à côté du colis.
	{ Name = "Unbox_Stomp", Loop = false, Priority = "Action", Marker = "Impact" },
	{ Name = "Unbox_Slam", Loop = false, Priority = "Action", Marker = "Impact" },
} :: { Anim }

-- 5 animations dans chaque modèle de vigile, de jour comme de nuit (mêmes noms) ; plus PickUp pour les vigiles de
-- magasin (a252, plus bas).
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

-- a252 (L-244, Clément, 2026-11-18) : vigiles de magasin seulement (pas les vigiles de nuit) : après la capture, il
-- ramasse l'objet tombé au sol ; au marqueur Grab, l'objet passe dans sa main (Guard/CatchPickUp). Pas encore livrée :
-- orange au ContractChecker, l'objet passe dans sa main Chase.CatchPickUp.GrabFallback s après le début du geste.
table.insert(Animations.Guard, { Name = "PickUp", Loop = false, Priority = "Action", Marker = "Grab" })

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

-- Vague 70 (a231, L-223, Clément, publiées le 2026-11-17) : la foule qui regarde le braquage,
-- ReplicatedStorage/Assets/Crowd/Models/NPC_Crowd_01 à _12, <Modèle>/Animations/<Nom>. Toutes en boucle, priorité
-- Action. Marqueur Shout : le cri (son de foule) ; TakePhoto : celle des témoins (même ID, marqueur Flash). Rôles :
-- pour le voleur Cheer, ou HoldSign avec une pancarte Side = "For" ; contre Boo, ou HoldSign avec une pancarte
-- "Against" ; crieur Shout ; photographe TakePhoto. Pas encore jouées par le code (WitnessCrowdController).
Animations.Crowd = {
	{ Name = "Cheer", Loop = true, Priority = "Action", Marker = "Shout" },
	{ Name = "Boo", Loop = true, Priority = "Action", Marker = "Shout" },
	{ Name = "Shout", Loop = true, Priority = "Action", Marker = "Shout" },
	{ Name = "HoldSign", Loop = true, Priority = "Action" },
	{ Name = "TakePhoto", Loop = true, Priority = "Action", Marker = "Flash" },
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
-- Faux monde Roblox minimal pour exécuter AnimPlayer, MarkerSounds, AnimTest et
-- AnimationController hors Studio (banc d'essai de l'agent a09, pas livré).
-- SRC est défini avant ce fichier par run.sh (sources des modules).

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

-- Instances ---------------------------------------------------------------------
local ISA = {
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
	end
	return i
end

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
	local controller = rawNew("ModuleScript", "AnimationController")
	rawset(controller, "_source", SRC["AnimationController"])

	return {
		dm = dm,
		RS = RS,
		WS = WS,
		player = player,
		shared = shared,
		anim = anim,
		controllerModule = controller,
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
-- Scénarios du banc d'essai a09 (après fake.luau).

local function marker(name, time, value)
	return { name = name, time = time, value = value or "" }
end

---------------------------------------------------------------------------------
section("AnimPlayer : dossier absent, noms absents, ID vides")
do
	local w = newWorld(true)
	local AnimPlayer = w.require("AnimPlayer")
	local Animations = w.require("Animations")
	local character, humanoid, animator = newCharacter()
	character.Parent = w.WS
	clearLog()
	local anims = AnimPlayer.new(animator, nil, Animations.Player, "Joueur")
	check(anims:Play("HitWindow") == nil, "dossier absent : Play renvoie nil")
	check(anims:Play("HitWindow") == nil, "dossier absent : 2e Play renvoie nil")
	check(countLog("« HitWindow » non jouée", "warn") == 1, "un seul avertissement pour HitWindow")
	check(anims:OnMarker("HitWindow", "Impact", function() end) ~= nil, "OnMarker sans dossier : pas d'erreur")
	anims:Stop("HitWindow")
	anims:StopAll()
	check(anims:IsPlaying("HitWindow") == false, "IsPlaying faux")

	local folder = newFolder(w.RS, "Animations")
	addAnimation(folder, "A", "rbxassetid://1", { length = 1, loop = false, markers = {} })
	addAnimation(folder, "Vide", "rbxassetid://", nil)
	addAnimation(folder, "Vide2", "http://www.roblox.com/asset/?id=", nil)
	addAnimation(folder, "Vide3", "", nil)
	newFolder(folder, "PasUneAnim")
	local p = AnimPlayer.new(animator, folder, nil, "Essai")
	clearLog()
	check(p:Play("Vide") == nil and p:Play("Vide2") == nil and p:Play("Vide3") == nil, "ID vides : rien")
	check(countLog("AnimationId vide", "warn") == 3, "3 avertissements ID vide")
	check(p:Play("PasUneAnim") == nil, "objet pas Animation : rien")
	check(countLog("pas un objet Animation", "warn") == 1, "avertissement mauvaise classe")
	check(p:Play("A") ~= nil, "A se joue")
	check(animator._loads == 1, "une seule piste chargée")
	p:Play("A")
	check(animator._loads == 1, "cache : pas de second chargement")
end

---------------------------------------------------------------------------------
section("AnimPlayer : boucle continue, sans boucle repart, marqueurs, Destroy")
do
	local w = newWorld(true)
	local AnimPlayer = w.require("AnimPlayer")
	local Animations = w.require("Animations")
	local character, humanoid, animator = newCharacter()
	character.Parent = w.WS
	local folder = newFolder(w.RS, "Animations")
	addAnimation(folder, "TreadmillRun", "rbxassetid://10", { length = 1, loop = true, markers = {} })
	addAnimation(folder, "BenchLift", "rbxassetid://11", { length = 1, loop = false, markers = { marker("Top", 0.5, "haut") } })
	local anims = AnimPlayer.new(animator, folder, Animations.Player, "Joueur")

	local hits, lastParam = 0, nil
	local off = anims:OnMarker("BenchLift", "Top", function(param)
		hits += 1
		lastParam = param
	end)
	check(animator._loads == 1, "OnMarker charge la piste")

	local tr = anims:Play("TreadmillRun")
	runFor(0.3)
	local pos = tr.TimePosition
	anims:Play("TreadmillRun")
	check(tr.TimePosition == pos and tr.IsPlaying, "boucle déjà en cours : continue")

	local bl = anims:Play("BenchLift")
	runFor(0.6)
	check(hits == 1 and lastParam == "haut", "marqueur Top reçu avec sa valeur")
	check(bl.IsPlaying and bl.TimePosition > 0.5, "BenchLift en cours")
	anims:Play("BenchLift")
	check(bl.TimePosition == 0, "sans boucle déjà en cours : repart du début")
	runFor(0.6)
	check(hits == 2, "marqueur repassé après le redémarrage")
	runFor(0.6)
	check(not bl.IsPlaying, "BenchLift finie")
	off()
	anims:Play("BenchLift")
	runFor(1.2)
	check(hits == 2, "débranché : plus d'appel")

	-- Branchement avant l'arrivée de l'animation.
	local late = 0
	anims:OnMarker("Unbox", "Open", function() late += 1 end)
	addAnimation(folder, "Unbox", "rbxassetid://12", { length = 0.5, loop = false, markers = { marker("Open", 0.2) } })
	local ub = anims:Play("Unbox")
	runFor(0.6)
	check(late == 1, `marqueur branché avant livraison : reçu au premier chargement (reçu {late}, piste {ub and ub._plays}, signaux {ub and ub._markerSignals.Open and ub._markerSignals.Open:count()})`)

	anims:StopAll()
	check(not tr.IsPlaying, "StopAll arrête la boucle")

	-- Destruction de l'Animator : Destroy automatique.
	local after = 0
	anims:OnMarker("BenchLift", "Top", function() after += 1 end)
	animator:Destroy()
	check(anims:Play("BenchLift") == nil, "Animator détruit : Play ne fait rien")
	anims:Destroy()
	check(true, "Destroy deux fois : sans erreur")
end

---------------------------------------------------------------------------------
section("AnimPlayer : préchargement et waitForAnimator")
do
	local w = newWorld(true)
	local AnimPlayer = w.require("AnimPlayer")
	local Animations = w.require("Animations")
	local folder = newFolder(w.RS, "Animations")
	addAnimation(folder, "HitWindow", "rbxassetid://20", { length = 1, loop = false, markers = {} })
	addAnimation(folder, "Grab", "rbxassetid://21", nil) -- ID illisible (compte perso)
	addAnimation(folder, "Place", "rbxassetid://", nil)
	clearLog()
	local n = AnimPlayer.preload(folder, { "HitWindow", "Grab", "Place", "Absente" })
	check(n == 1, `préchargées sans erreur : 1 (obtenu {n})`)
	check(countLog("chargement refusé pour Grab", "warn") == 1, "échec de préchargement signalé")
	check(#PRELOADED == 2, "Place (ID vide) et Absente ne sont pas envoyées")
	local all = AnimPlayer.preload(folder, nil)
	check(all == 1, "préchargement du dossier entier")

	local w2 = newWorld(false)
	local AnimPlayerServer = w2.require("AnimPlayer")
	check(AnimPlayerServer.preload(newFolder(w2.RS, "F"), nil) == 0, "serveur : pas de préchargement")

	local character, humanoid, animator = newCharacter()
	local got
	runTask(function()
		got = AnimPlayer.waitForAnimator(character, 1)
	end, 3)
	check(got == nil, "personnage hors du jeu : nil après le délai")
	character.Parent = w.WS
	runTask(function()
		got = AnimPlayer.waitForAnimator(character, 1)
	end, 3)
	check(got == animator, "personnage dans le jeu : Animator trouvé")

	local bare = Instance.new("Model")
	bare.Parent = w.WS
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	runTask(function()
		got = AnimPlayer.waitForAnimator(bare, 0.5)
	end, 3)
	check(got == nil, "sans Humanoid : nil")
	hum.Parent = bare
	runTask(function()
		got = AnimPlayer.waitForAnimator(bare, 0.5)
	end, 3)
	check(got == nil, "sans Animator : nil, jamais créé")
	check(hum:FindFirstChildOfClass("Animator") == nil, "aucun Animator créé")

	check(AnimPlayer.playerFolder() == nil, "dossier joueur absent : nil")
	local assets = newFolder(w.RS, "Assets")
	local anims = newFolder(assets, "Animations")
	local pf = newFolder(anims, "Player")
	check(AnimPlayer.playerFolder() == pf, "dossier joueur trouvé")
	local guard = Instance.new("Model")
	local gf = newFolder(guard, "Animations")
	check(AnimPlayer.modelFolder(guard) == gf, "dossier d'un modèle animé")
end

---------------------------------------------------------------------------------
section("MarkerSounds : registre, recherche, lecture")
do
	local w = newWorld(true)
	local MarkerSounds = w.require("MarkerSounds")
	local Animations = w.require("Animations")
	clearLog()
	check(MarkerSounds.check(MarkerSounds.Player, Animations.Player, "Player") == 0, "registre joueur conforme au contrat")
	check(MarkerSounds.check(MarkerSounds.Guard, Animations.Guard, "Guard") == 0, "registre vigile conforme au contrat")
	check(
		MarkerSounds.check({ { Anim = "HitWindow", Marker = "Impakt", Sound = "x" } }, Animations.Player, "Essai") == 1,
		"faute de frappe détectée"
	)
	local withMarker = 0
	for _, spec in Animations.Player do
		if spec.Marker and spec.Name ~= "BenchLift" and string.sub(spec.Name, 1, 6) ~= "Unbox_" then -- L-118 point 7 : plus de son au marqueur Top du banc
			withMarker += 1
		end
	end
	check(#MarkerSounds.Player == withMarker, `registre : une entrée par marqueur du joueur ({withMarker})`)

	clearLog()
	check(MarkerSounds.play("Unbox_Open", nil) == nil, "son absent : rien")
	MarkerSounds.play("Unbox_Open", nil)
	check(countLog("son « Unbox_Open » absent", "warn") == 1, "un seul avertissement par son absent")

	local assets = newFolder(w.RS, "Assets")
	local sounds = newFolder(assets, "Sounds")
	local sub = newFolder(sounds, "Joueur")
	SOUND_LENGTH["rbxassetid://500"] = 0.3
	addSound(sub, "BenchLift_Top", "rbxassetid://500")
	local part = Instance.new("Part")
	part.Name = "HumanoidRootPart"
	part.Parent = w.WS
	local played = MarkerSounds.play("BenchLift_Top", part)
	check(played ~= nil and played.Parent == part and played.IsPlaying, "son trouvé en sous-dossier, joué sur la Part")
	runFor(0.6)
	check(played.Parent == nil, "copie supprimée à la fin du son")
	local flat = MarkerSounds.play("BenchLift_Top", nil)
	check(flat.Parent and flat.Parent.Name == "SoundService", "sans Part : SoundService")
end

---------------------------------------------------------------------------------
section("AnimationController : entraînement, marqueurs, portage, réapparition")
do
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local animsFolder = newFolder(assets, "Animations")
	local pf = newFolder(animsFolder, "Player")
	addAnimation(pf, "TreadmillRun", "rbxassetid://30", { length = 1, loop = true, markers = {} })
	-- Copie a134 : BenchLift (marqueur Top) n'est plus au contrat ; le marqueur d'essai est celui de Place (Release).
	addAnimation(pf, "Place", "rbxassetid://31", { length = 0.8, loop = false, markers = { marker("Release", 0.4) } })
	addAnimation(pf, "CarryIdle", "rbxassetid://32", { length = 1, loop = true, markers = {} })
	addAnimation(pf, "CarryRun", "rbxassetid://33", { length = 1, loop = true, markers = {} })
	local sounds = newFolder(assets, "Sounds")
	SOUND_LENGTH["rbxassetid://600"] = 0.2
	addSound(sounds, "Place_Release", "rbxassetid://600")

	local character, humanoid, animator, hrp = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.player:SetAttribute("BenchReps", 4)

	local AC = require(w.controllerModule)
	check(AC.PlayPlayer("TreadmillRun") == nil, "avant Start : PlayPlayer renvoie nil sans erreur")
	local early = 0
	AC.OnMarker("Place", "Release", function() early += 1 end)

	clearLog()
	local done = runTask(function()
		AC.Start()
	end, 5)
	check(done, "Start se termine")
	runFor(0.2)
	check(countLog("4/25 animation(s) préchargée(s)", "print") == 1, "préchargement : 4/13 (a170 : 15 moins Unbox et Celebrate)")
	check(animator._loads == 4, `à l'apparition : les 4 animations livrées chargées tout de suite (obtenu {animator._loads})`)
	check(countLog("MarkerSounds", "warn") == 0, "registre sans faute")

	-- Tapis
	w.player:SetAttribute("TrainingMachine", "Treadmill")
	local tr = AC.PlayPlayer("TreadmillRun")
	check(tr and tr.IsPlaying, "TreadmillRun joue sur le tapis")
	runFor(0.3)
	w.player:SetAttribute("TrainingMachine", nil)
	check(tr and not tr.IsPlaying, "TreadmillRun s'arrête en quittant le tapis")

	-- Banc
	-- a134 : plus de banc. TrainingMachine = "Bench" et BenchReps ne jouent plus rien, BenchLift et BenchIdle
	-- ne sont plus au contrat.
	w.player:SetAttribute("TrainingMachine", "Bench")
	w.player:SetAttribute("BenchReps", 5)
	runFor(0.5)
	check(AC.PlayPlayer("BenchLift") == nil and AC.PlayPlayer("BenchIdle") == nil, "a134 : BenchLift et BenchIdle hors contrat, rien ne joue au banc")
	w.player:SetAttribute("TrainingMachine", nil)
	local before = #SOUND_LOG
	local bl = AC.PlayPlayer("Place")
	runFor(0.5)
	check(bl and bl._plays == 1, "Place jouée une fois")
	check(early == 1, "branchement fait avant Start : reçu")
	check(#SOUND_LOG == before + 1, "son Place_Release joué au marqueur Release")
	runFor(1)

	-- Marqueur sans son livré
	clearLog()
	addAnimation(pf, "Knockback", "rbxassetid://34", { length = 0.5, loop = false, markers = { marker("Land", 0.2) } })
	AC.PlayPlayer("Knockback")
	runFor(0.4)
	check(countLog("son « Knockback_Land » absent", "warn") == 1, "son absent signalé au passage du marqueur (a170 : Knockback/Land)")

	-- Animation non livrée
	clearLog()
	check(AC.PlayPlayer("HitWindow") == nil, "HitWindow non livrée : nil")
	AC.PlayPlayer("HitWindow")
	check(countLog("« HitWindow » non jouée", "warn") == 1, "un seul avertissement")

	-- Portage
	AC.SetCarrying(true)
	local idle = AC.PlayPlayer("CarryIdle")
	check(idle and idle.IsPlaying, "à l'arrêt : CarryIdle")
	humanoid.Running:Fire(12)
	local run = AC.PlayPlayer("CarryRun")
	check(run and run.IsPlaying and not idle.IsPlaying, "en mouvement : CarryRun à la place de CarryIdle")
	humanoid.Running:Fire(0)
	check(idle.IsPlaying and not run.IsPlaying, "arrêt : retour à CarryIdle")
	AC.SetCarrying(false)
	check(not idle.IsPlaying and not run.IsPlaying, "fin du portage : les deux arrêtées")
	humanoid.Running:Fire(12)
	check(not run.IsPlaying, "hors portage : Running ne joue rien")

	-- Réapparition : nouveau personnage, branchements suivis, portage rejoué
	local count = 0
	local off = AC.OnMarker("Place", "Release", function() count += 1 end)
	AC.SetCarrying(true)
	local c2, h2, a2, hrp2 = spawnCharacter(w, "Ironix2")
	runFor(0.2)
	check(a2._loads > 0, "nouveau personnage : pistes chargées sur le nouvel Animator")
	local idle2 = AC.PlayPlayer("CarryIdle")
	check(idle2 and idle2.IsPlaying and idle2 ~= idle, "portage rejoué sur le nouveau personnage")
	AC.PlayPlayer("Place")
	-- a41 (L-071) : un BenchLift en cours n'est plus relancé par la hausse suivante de BenchReps ;
	-- on laisse donc finir celui-ci (0,8 s) avant la répétition suivante (avant : 0,6 s).
	runFor(0.9)
	check(count == 1 and early == 2, "branchements suivis d'une vie à l'autre")
	off()
	AC.PlayPlayer("Place")
	runFor(0.9)
	check(count == 1 and early == 3, "débranché : plus d'appel ; l'autre continue")
	local loadsOld = animator._loads
	check(character.Parent == nil, "ancien personnage parti")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("AnimTest : animation de remplacement (Test pas livrée)")
do
	local w = newWorld(true)
	local character, humanoid, animator = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(12)
	check(countLog("animation « Test » : de remplacement", "print") == 1, "remplacement fabriqué en code")
	if countLog("marqueur « Test » atteint (valeur", "print") ~= 3 then dumpLog() end
	check(countLog("marqueur « Test » atteint (valeur", "print") == 3, `marqueur atteint 3 fois (obtenu {countLog("marqueur « Test » atteint (valeur", "print")})`)
	check(countLog("[Anim test] OK", "print") == 1, "verdict OK")
	if countLog("[Anim test] OK", "print") ~= 1 then
		dumpLog()
	end
	check(countLog("ÉCHEC", "warn") == 0, "aucun échec")
	w.WS:SetAttribute("AnimTest", nil)
	runFor(1)
end

section("AnimTest : animation Test livrée, sans puis avec marqueur ; refus du remplacement")
do
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local animsFolder = newFolder(assets, "Animations")
	local pf = newFolder(animsFolder, "Player")
	addAnimation(pf, "Test", "rbxassetid://77", { length = 1, loop = false, markers = { marker("Test", 0.5, "clement") } })
	addAnimation(pf, "CarryIdle", "rbxassetid://78", { length = 1, loop = true, markers = {} })
	addAnimation(pf, "Grab", "rbxassetid://79", { length = 0.6, loop = false, markers = {} })
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	local AC = require(w.controllerModule)
	runTask(function()
		AC.Start()
	end, 5)
	clearLog()
	w.WS:SetAttribute("AnimTest", true)
	runFor(10)
	check(countLog("livrée, ReplicatedStorage.Assets.Animations.Player.Test", "print") == 1, "Test livrée utilisée")
	check(countLog("valeur « clement »", "print") == 3, "marqueur de Clément atteint 3 fois")
	check(countLog("[Anim test] OK", "print") == 1, "verdict OK avec la vraie animation")

	clearLog()
	w.WS:SetAttribute("AnimTest", "CarryIdle")
	runFor(25)
	check(countLog("pas de marqueur au contrat", "print") == 1, "boucle sans marqueur : fini sans son")

	clearLog()
	w.WS:SetAttribute("AnimTest", "Grab")
	runFor(10)
	check(countLog("n'a jamais été atteint", "warn") == 1, "marqueur Grab absent de l'animation : ÉCHEC")

	clearLog()
	w.WS:SetAttribute("AnimTest", "HitWindow")
	runFor(2)
	check(countLog("« HitWindow » introuvable", "warn") == 1, "animation absente : ÉCHEC clair")

	-- Interruption : on change l'attribut pendant un test
	clearLog()
	w.WS:SetAttribute("AnimTest", true)
	runFor(1)
	w.WS:SetAttribute("AnimTest", nil)
	runFor(10)
	check(countLog("interrompu", "print") == 1, "test interrompu proprement")
	check(countLog("[Anim test] OK", "print") == 0, "pas de verdict après interruption")
end

section("AnimTest : Studio refuse RegisterKeyframeSequence")
do
	local w = newWorld(true)
	KSP_REFUSE = true
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(2)
	check(countLog("Studio refuse l'animation de remplacement", "warn") == 1, "refus signalé avec la marche à suivre")
	KSP_REFUSE = false
end

section("AnimTest : en attente du personnage, puis réapparition")
do
	local w = newWorld(true)
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	check(countLog("en attente du personnage", "print") == 1, "pas de personnage : attente")
	spawnCharacter(w, "Ironix")
	runFor(10)
	check(countLog("[Anim test] OK", "print") == 1, "test lancé à l'apparition")
end

section("AnimTest : animation Test illisible (publiée hors du groupe)")
do
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local pf = newFolder(newFolder(assets, "Animations"), "Player")
	addAnimation(pf, "Test", "rbxassetid://404", nil)
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(30)
	check(countLog("chargement refusé pour Test", "warn") == 1, "préchargement refusé signalé")
	check(countLog("jamais chargée (durée 0 s)", "warn") == 1, "verdict : animation jamais chargée")
	check(countLog("[Anim test] OK", "print") == 0, "pas de faux OK")
end

section("Hors Studio : aucun avertissement, aucun mode test")
do
	local w = newWorld(true)
	rawset(w.dm:GetService("RunService"), "IsStudio", function() return false end)
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(3)
	check(AC.PlayPlayer("HitWindow") == nil, "animation absente : nil")
	check(#LOG == 0, `rien dans la sortie hors Studio (obtenu {#LOG} ligne(s))`)
end

report()
