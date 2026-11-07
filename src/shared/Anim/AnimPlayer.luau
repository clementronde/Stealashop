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
