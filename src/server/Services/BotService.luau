--!strict
-- BotService (liaison L-085 point 4, L-105 point 1, L-108 point 3 ; attendu pour le lancement) : le bot
-- joueur. Règles de Clément et valeurs : Config/Bot.
--
-- Rôle :
--   - présence : tant que le serveur compte Bot.MaxRealPlayers (4) vrais joueurs ou moins depuis
--     Bot.ArriveDelay s, le bot prend une boutique libre (PlotService.ReserveForBot : celle de plus grand
--     numéro). Il part tout de suite quand un 5e vrai joueur arrive (PlayerAdded) ou quand le profil d'un
--     joueur arrive sans boutique libre (PlotService.OnShortage). Revu chaque Bot.CheckInterval s ;
--   - boutique au niveau le plus faible : pour les autres services elle reste libre (OwnerUserId = 0,
--     GetOwner = nil : rayons, machines et présentoirs de base, murs au niveau 0, aucune amélioration) ;
--     seule sa porte devient cassable, aux PV de base d'une boutique de niveau 1 (WindowService.
--     GetFreePlotHP remplacé ici : Formulas.PlayerWindowHP(Bot.StageLevel), sans Glass ni Walls,
--     régénération de base) ;
--   - objets : Bot.ItemCount (4) Communs de la zone 1 tirés au hasard (Items.Pick), sur DisplaySlot_01 à
--     _04, construits par DisplayService.BuildBotItem (même modèle, halo, billboard, tag DisplayItem
--     qu'un objet de joueur), rangés dans un dossier DisplayItems de la parcelle. Aucun profil, aucune
--     plaque, aucun revenu versé à personne. Attribut BotIncome (nombre) de la parcelle = sa valeur
--     exposée (objets tenus exclus), lue par PvPController (panneau) ;
--   - vol (PvPService, voir son en-tête) : Hold (un voleur prend l'objet : il quitte le présentoir),
--     Release (vol raté : il revient), TakeHeld (dépôt chez le voleur : il est à lui ; un autre Commun
--     de la zone 1 revient sur ce présentoir Bot.RegenDelay s plus tard ; plus d'immunité après un vol
--     subi depuis la décision de Cantin du 2026-11-12) ; découverte dans l'index du voleur (IndexService.Discover) ;
--   - avatar : modèle de Clément s'il est livré (ReplicatedStorage/Assets/<Bot.AvatarFolder>/
--     <Bot.AvatarName>, proposé, absent du contrat), sinon l'avatar R15 par défaut de Roblox
--     (Players:CreateHumanoidModelFromDescriptionAsync, préparé une fois), debout au point d'apparition
--     du propriétaire (PlotService.GetSpawnSpot), HumanoidRootPart ancré, aucune collision ni requête,
--     scripts retirés, nom Bot.DisplayName au-dessus de lui, animation Animations/Idle en boucle (celle
--     de Clément, ou l'idle par défaut de Roblox gardée du script Animate) ;
--   - défense (vague 37, a124, L-117 point 7, Config/Bot.Defense, V0 proposés) : quand un joueur casse sa porte
--     (WindowService.OnBroken) ou lui prend un objet (Hold), l'avatar se désancre (SetNetworkOwner(nil) : le
--     serveur le déplace), joue Animations/Run (celle de Clément, sinon la course par défaut de Roblox gardée du
--     script Animate) et court vers lui (Humanoid:MoveTo, 10 fois par seconde, à Defense.RunSpeed ; chemin
--     simple : entre l'intérieur et l'extérieur de sa boutique, il passe par la porte PlotDoor/Window). Cible
--     frappable comme par un propriétaire (elle porte un de ses objets, ou elle est dans sa boutique ; un casseur
--     resté devant la porte est suivi, pas frappé) et à Defense.SwingRange studs : au plus toutes les
--     Defense.SwingCooldown s, il lance SwingBat (l'animation du
--     joueur, ReplicatedStorage/Assets/Animations/Player/SwingBat, batte TOOL_Batte en main si elle est livrée
--     en Tool ou en Model avec Handle) ; au marqueur Impact (ou Bat.ImpactMaxWait s après), le son
--     SwingBat_Impact et BatService.BotSwing : mêmes règles et mêmes effets qu'un coup du propriétaire (son
--     voleur : l'objet revole sur son présentoir ; un intrus de sa boutique : étourdi), puis PvPService le sort
--     et lui interdit cette boutique PvP.KickRobCooldown s (BatService.OnBotHit). Cible : celui qui l'a
--     déclenché ; un voleur qui porte un de ses objets passe avant un casseur de porte ; perdue (partie, morte,
--     frappée, à plus de Defense.LeashDistance studs de son volume Bounds), il prend un autre voleur ou un intrus
--     dans sa boutique, sinon il rentre. Il rentre aussi Defense.GiveUpTime s après le dernier déclenchement.
--     Retour : il court à son point d'apparition, puis s'y ré-ancre (replacé d'un coup au bout de
--     Defense.ReturnTimeout s), batte rangée, Idle de nouveau. Tuto (point d'accroche IsGentle, remplacé par
--     TutorialService : le joueur poursuivi fait son tuto) : Defense.TutorialRunSpeed, et au plus
--     Defense.TutorialMaxStrikes coup réussi sur lui pendant son tuto ;
--   - départ propre : objets et avatar détruits, BotIncome retiré, porte refaite si elle est cassée
--     (WindowService.Rebuild), puis PlotService.ReleaseBot (BotName retiré, panneau vidé, la boutique sert
--     au premier joueur qui attend). Un vol en cours échoue (PvPService, « VictimLeft »).
-- Le bot n'est pas un Player : il n'entre ni dans la sauvegarde, ni dans la télémétrie, ni dans les
-- classements, ni dans les annonces, les invitations, les alertes de vol, l'Adrénaline ou la défense à la
-- batte (PvPService ne prévient que les vrais joueurs).
--
-- API (serveur ; le tuto s'en sert pour montrer le vol entre joueurs) :
--   BotService.GetBotPlot() -> Model?          boutique du bot (attributs PlotIndex et BotName), nil sans bot
--   BotService.IsBotPlot(plot) -> boolean
--   BotService.GetExposed(plot) -> { [présentoir]: { Uid, ItemId, Income } }
--       Objets exposés du bot (tenus exclus) ; vide si `plot` n'est pas sa boutique.
--   BotService.GetIncome(plot) -> number       sa valeur exposée ($/s), 0 sans bot
--   BotService.OnTheft(listener) -> déconnexion
--       listener(thief, itemId, stage) : "Grabbed" (le voleur l'a pris), "Returned" (vol raté, l'objet est
--       revenu) ou "Stolen" (déposé chez le voleur, il est à lui).
--   BotService.OnChanged(listener) -> déconnexion
--       listener(plot?) à l'arrivée du bot (sa boutique) et à son départ (nil).
--   BotService.IsChasing(player) -> boolean     vague 37 : le bot poursuit `player` (bulle du tuto)
--   BotService.IsGentle(player) -> boolean
--       Point d'accroche (comme BatService.IsIntruder) : poursuite plus douce pour `player` ? false par défaut ;
--       TutorialService le remplace (tuto en cours). Appelé sans yield, dans un pcall.
-- Pour PvPService seulement (sans yield) : Hold(plot, uid, thief) -> boolean, Release(plot, uid, thief) ->
-- boolean, IsHeld(plot, uid) -> boolean, TakeHeld(plot, uid, thief) -> boolean.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local BatConfig = require(Shared.Config.Bat)
local Bot = require(Shared.Config.Bot)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local AnimContract = require(Shared.Contract.Animations)
local Find = require(Shared.Contract.Find)

local DisplayService = require(script.Parent.DisplayService)
local PlotService = require(script.Parent.PlotService)
local WindowService = require(script.Parent.WindowService)

export type TheftStage = "Grabbed" | "Returned" | "Stolen"
type TheftListener = (thief: Player, itemId: string, stage: TheftStage) -> ()
type ChangedListener = (plot: Model?) -> ()

-- Vague 37 : ce que la défense utilise de BatService. require protégé (bancs sans lui) : sans BatService, le bot
-- court mais ne frappe pas. BatService ne requiert ni ce service ni PvPService.
type BatApi = {
	BotSwing: (plot: Model, root: BasePart, target: Player, bounds: BasePart?) -> (boolean, string),
}
local batModule = script.Parent:FindFirstChild("BatService")
local batLoaded: boolean, batResult: any = false, nil
if batModule and batModule:IsA("ModuleScript") then
	batLoaded, batResult = pcall(require, batModule)
end
local BatHooks: BatApi? = if batLoaded and type(batResult) == "table" and type(batResult.BotSwing) == "function"
	then batResult :: any
	else nil

-- Son du souffle de la batte (Shared/Anim/MarkerSounds : SwingBat/Impact), joué sur le bot. require protégé.
local soundsModule = Shared:FindFirstChild("Anim")
soundsModule = if soundsModule then soundsModule:FindFirstChild("MarkerSounds") else nil
local soundsLoaded: boolean, soundsResult: any = false, nil
if soundsModule and soundsModule:IsA("ModuleScript") then
	soundsLoaded, soundsResult = pcall(require, soundsModule)
end
local playSound: ((name: string, at: Instance?) -> any)? = if soundsLoaded
		and type(soundsResult) == "table"
		and type(soundsResult.play) == "function"
	then soundsResult.play
	else nil

type Defense = typeof(Bot.Defense)
local DEFENSE: Defense = Bot.Defense

-- Poursuite en cours (vague 37, voir l'en-tête).
type Chase = {
	Phase: "Chase" | "Return",
	Target: Player?,
	StartedAt: number, -- os.clock() du dernier déclenchement (porte cassée, objet pris)
	ReturnedAt: number, -- os.clock() du début du retour
	LastSwing: number,
	Swinging: boolean,
	Struck: { [Player]: boolean }, -- touchés pendant cette poursuite : plus visés (sauf nouveau déclenchement)
}

type BotItem = {
	Uid: string,
	ItemId: string,
	Income: number,
	Model: Model?, -- nil pendant qu'un voleur le tient
}

-- Le bot présent : sa boutique, ses objets, son avatar.
type State = {
	Plot: Model,
	Folder: Folder,
	Items: { [number]: BotItem }, -- par présentoir
	Held: { [string]: number }, -- uid tenu par un voleur -> présentoir
	Avatar: Model?,
	-- Vague 37 (défense) : voleur de chaque objet tenu, pivot de l'avatar debout au point d'apparition, pistes
	-- chargées, batte en main, poursuite en cours.
	Holders: { [string]: Player },
	Home: CFrame?,
	Tracks: { [string]: AnimationTrack },
	Bat: Tool?,
	Chase: Chase?,
}

-- Mêmes noms que DisplayService (dossier des objets exposés) et PvPController (valeur exposée du bot).
local FOLDER_NAME = "DisplayItems"
local INCOME_ATTRIBUTE = "BotIncome"
local AVATAR_NAME = "BotAvatar"
local ASSETS = "Assets"
local ANIMATIONS = "Animations" -- contrat 2.4 : <Modèle>/Animations/<Nom>
local IDLE = "Idle"
local RUN = "Run" -- vague 37 : comme les vigiles (contrat 2.4, Animations.Guard)
local SWING = "SwingBat" -- celle du joueur (Animations.Player)
local IMPACT = "Impact"
local SWING_SOUND = "SwingBat_Impact" -- MarkerSounds.Player
-- Animations par défaut de Roblox gardées du script Animate quand le modèle n'a pas les siennes.
local DEFAULT_ANIMATIONS: { { Name: string, From: { string } } } = {
	{ Name = IDLE, From = { "idle" } },
	{ Name = RUN, From = { "run", "walk" } },
}
local BOUNDS = "Bounds" -- contrat 10.4
local DOOR_WINDOW = "PlotDoor.Window" -- PLOT_Shop (L-050), comme TutorialService
local ROOT_NAME = "HumanoidRootPart"
local IS_STUDIO = RunService:IsStudio()
-- V0 proposé, absent du doc : marge entre les pieds et le sol, comme PlotService.
local SPAWN_LIFT = 0.1
-- V0 proposé, absent du doc : attente au plus de l'avatar préparé par un autre appel.
local TEMPLATE_WAIT = 10

-- PV de la porte du bot : base d'une boutique de niveau 1 (voir l'en-tête et Config/Bot).
local DOOR_HP = Formulas.PlayerWindowHP(Bot.StageLevel)

local BotService = {}
-- Après PlotService (10), DisplayService et WindowService (100 par défaut, ordre des noms : B avant
-- D et W, sans importance ici : rien n'est lu chez eux à l'Init).
BotService.Priority = 105

local state: State? = nil
-- Joueurs dont PlayerRemoving est passé (encore dans Players un instant). Clés faibles.
local leaving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local readySince: number? = nil -- os.clock() depuis lequel le serveur compte 4 vrais joueurs ou moins
local theftListeners: { TheftListener } = {}
local changedListeners: { ChangedListener } = {}
local rng = Random.new()
local avatarTemplate: Model? = nil
local avatarStatus: "None" | "Building" | "Ready" = "None"
local warned: { [string]: boolean } = {}
-- Vague 37 : coups réussis du bot sur chaque joueur pendant son tuto (Defense.TutorialMaxStrikes). Clés faibles.
local tutorialStrikes: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Outils -------------------------------------------------------------------------------------------

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[BotService] {message}`)
	end
end

local function emitTheft(thief: Player, itemId: string, stage: TheftStage)
	for _, listener in table.clone(theftListeners) do
		task.spawn(listener, thief, itemId, stage)
	end
end

local function emitChanged(plot: Model?)
	for _, listener in table.clone(changedListeners) do
		task.spawn(listener, plot)
	end
end

-- Le bot de `plot`, s'il y est.
local function stateOf(plot: Model): State?
	local current = state
	if current and current.Plot == plot then
		return current
	end
	return nil
end

-- Vrais joueurs du serveur (ceux qui partent ne comptent plus).
local function realPlayers(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if not leaving[player] then
			count += 1
		end
	end
	return count
end

-- Objets ------------------------------------------------------------------------------------------

local function incomeOf(current: State): number
	local total = 0
	for _, item in current.Items do
		if current.Held[item.Uid] == nil then
			total += item.Income
		end
	end
	return total
end

local function publish(current: State)
	current.Plot:SetAttribute(INCOME_ATTRIBUTE, incomeOf(current))
end

-- Pose le modèle de l'objet sur son présentoir ; false si le présentoir manque à la parcelle.
local function show(current: State, slot: number, item: BotItem): boolean
	local model = DisplayService.BuildBotItem(current.Plot, slot, item.Uid, item.ItemId)
	if model == nil then
		return false
	end
	model.Parent = current.Folder
	item.Model = model
	return true
end

-- Un Commun de la zone 1 tiré au hasard sur le présentoir `slot` (vide).
local function newItem(current: State, slot: number)
	local def = Items.Pick(Bot.Zone, Bot.Rarity, rng)
	if def == nil then
		warnOnce("pick", `aucun objet {Bot.Rarity} en zone {Bot.Zone} au catalogue : le bot n'expose rien`)
		return
	end
	local item: BotItem = {
		Uid = HttpService:GenerateGUID(false),
		ItemId = def.Id,
		Income = Formulas.ItemIncome(def.Zone or Bot.Zone, def.Rarity),
		Model = nil,
	}
	if show(current, slot, item) then
		current.Items[slot] = item
	end
end

-- Avatar ------------------------------------------------------------------------------------------

-- Copie du modèle de Clément (voir l'en-tête), nil s'il n'est pas livré ou pas utilisable.
local function clementAvatar(): Model?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS)
	local folder = if assets then assets:FindFirstChild(Bot.AvatarFolder) else nil
	local found = if folder then folder:FindFirstChild(Bot.AvatarName) else nil
	if found == nil or not found:IsA("Model") then
		return nil
	end
	local root = found:FindFirstChild(ROOT_NAME)
	if found:FindFirstChildOfClass("Humanoid") == nil or root == nil or not root:IsA("BasePart") then
		warnOnce("model", `{found:GetFullName()} : il faut un Humanoid et un {ROOT_NAME} (rig R15), avatar par défaut à la place`)
		return nil
	end
	local copy = found:Clone() :: Model?
	return copy
end

-- Avatar R15 par défaut de Roblox (attend) ; nil s'il ne se crée pas.
local function defaultAvatar(): Model?
	local description = Instance.new("HumanoidDescription")
	local ok, result = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if ok then
		return result
	end
	warnOnce("default", `avatar R15 par défaut impossible ({result}) : le bot n'aura pas d'avatar`)
	return nil
end

-- Prépare le modèle une fois : idle gardé, scripts retirés (aucun script dans un modèle animé, 2.4),
-- HumanoidRootPart seul ancré, ni collision, ni contact, ni requête (on le traverse, les rayons l'ignorent).
local function prepare(model: Model): Model?
	model.Name = AVATAR_NAME
	local animations: Instance? = model:FindFirstChild(ANIMATIONS)
	-- Rig de Roblox : son script Animate porte l'idle et la course par défaut (animations de Roblox, jouables
	-- partout) ; gardées pour celles que le modèle n'a pas (Run : vague 37).
	local animate = model:FindFirstChild("Animate")
	for _, entry in DEFAULT_ANIMATIONS do
		if animations and animations:FindFirstChild(entry.Name) then
			continue
		end
		local source: Instance? = nil
		for _, key in entry.From do
			local holder = if animate then animate:FindFirstChild(key) else nil
			source = if holder then holder:FindFirstChildWhichIsA("Animation") else nil
			if source then
				break
			end
		end
		if source then
			local folder: Instance? = animations
			if folder == nil then
				local created = Instance.new("Folder")
				created.Name = ANIMATIONS
				created.Parent = model
				folder = created
				animations = created
			end
			local copy = source:Clone()
			copy.Name = entry.Name
			copy.Parent = folder
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = part.Name == ROOT_NAME
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild(ROOT_NAME)
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	humanoid.DisplayName = Bot.DisplayName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	model.PrimaryPart = root :: BasePart
	return model
end

-- Le modèle préparé, construit au premier besoin (attend) ; nil sans avatar possible.
local function getTemplate(): Model?
	if avatarStatus == "Ready" then
		return avatarTemplate
	end
	if avatarStatus == "Building" then
		local deadline = os.clock() + TEMPLATE_WAIT
		while avatarStatus == "Building" and os.clock() < deadline do
			task.wait(0.1)
		end
		return avatarTemplate
	end
	avatarStatus = "Building"
	local model = clementAvatar() or defaultAvatar()
	avatarTemplate = if model then prepare(model) else nil
	avatarStatus = "Ready"
	return avatarTemplate
end

-- Piste `name` de l'avatar du bot `current`, chargée une fois : depuis `folder` (son dossier Animations par
-- défaut). nil si l'animation manque ou ne se charge pas.
local function trackOf(current: State, name: string, folder: Instance?): AnimationTrack?
	local cached = current.Tracks[name]
	if cached then
		return cached
	end
	local avatar = current.Avatar
	local humanoid = if avatar then avatar:FindFirstChildOfClass("Humanoid") else nil
	if avatar == nil or humanoid == nil then
		return nil
	end
	local source = folder or avatar:FindFirstChild(ANIMATIONS)
	local animation = if source then source:FindFirstChild(name) else nil
	if animation == nil or not animation:IsA("Animation") then
		return nil
	end
	local ok, result = pcall(function(): AnimationTrack
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator == nil then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
		return (animator :: Animator):LoadAnimation(animation :: Animation)
	end)
	if not ok then
		warnOnce(`anim-{name}`, `animation {name} du bot : {result}`)
		return nil
	end
	local track = result :: AnimationTrack
	current.Tracks[name] = track
	return track
end

local function playLooped(current: State, name: string)
	local track = trackOf(current, name)
	if track then
		track.Looped = true
		track:Play()
	end
end

local function stopTrack(current: State, name: string)
	local track = current.Tracks[name]
	if track then
		track:Stop()
	end
end

-- Dossier des animations du joueur (contrat 2.4 : ReplicatedStorage/Assets/Animations/Player), ou nil.
local function playerAnimations(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in AnimContract.PlayerFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

-- Pose l'avatar du bot `current` debout au point d'apparition de sa boutique. Peut attendre (avatar par
-- défaut de Roblox) : le bot a pu partir entre-temps.
local function spawnAvatar(current: State)
	local template = getTemplate()
	if template == nil or state ~= current then
		return
	end
	local avatar = template:Clone()
	local root = avatar:FindFirstChild(ROOT_NAME)
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	local ground, facing = PlotService.GetSpawnSpot(current.Plot)
	if root == nil or not root:IsA("BasePart") or humanoid == nil or ground == nil or facing == nil then
		avatar:Destroy()
		return
	end
	local rootPart = root :: BasePart
	-- R15 : HipHeight = du bas du HumanoidRootPart au sol (comme PlotService).
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local position = ground + Vector3.new(0, hip + rootPart.Size.Y / 2 + SPAWN_LIFT, 0)
	avatar:PivotTo(CFrame.lookAt(position, position + facing) * rootPart.CFrame:ToObjectSpace(avatar:GetPivot()))
	avatar.Parent = current.Plot
	current.Avatar = avatar
	current.Home = avatar:GetPivot()
	playLooped(current, IDLE)
end

-- Arrivée et départ -------------------------------------------------------------------------------------

local function arrive()
	local plot = PlotService.ReserveForBot(Bot.DisplayName)
	if plot == nil then
		return -- aucune boutique libre, ou un joueur en attend une
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = plot
	local current: State = {
		Plot = plot,
		Folder = folder,
		Items = {},
		Held = {},
		Avatar = nil,
		Holders = {},
		Home = nil,
		Tracks = {},
		Bat = nil,
		Chase = nil,
	}
	state = current
	for slot = 1, Bot.ItemCount do
		newItem(current, slot)
	end
	publish(current)
	local count = 0
	for _ in current.Items do
		count += 1
	end
	print(`[BotService] le bot arrive dans {plot.Name} : {count} objet(s) exposé(s), porte à {DOOR_HP} PV ({realPlayers()} vrai(s) joueur(s))`)
	task.spawn(spawnAvatar, current)
	emitChanged(plot)
end

local function leave(reason: string)
	local current = state
	if current == nil then
		return
	end
	state = nil
	readySince = nil
	current.Folder:Destroy()
	local avatar = current.Avatar
	if avatar then
		avatar:Destroy()
	end
	local plot = current.Plot
	plot:SetAttribute(INCOME_ATTRIBUTE, nil)
	-- Porte refaite tout de suite si elle est cassée ; ses PV max repassent à 0 (parcelle libre).
	local windowId = WindowService.GetWindowId(plot)
	if windowId and WindowService.IsBroken(windowId) then
		WindowService.Rebuild(windowId)
	end
	PlotService.ReleaseBot(plot) -- peut la donner tout de suite au joueur qui attend
	print(`[BotService] le bot quitte {plot.Name} ({reason})`)
	emitChanged(nil)
end

-- Présence du bot selon le nombre de vrais joueurs (voir l'en-tête). Sans yield.
local function evaluate()
	if not Bot.Enabled then
		return
	end
	if realPlayers() > Bot.MaxRealPlayers then
		readySince = nil
		leave(`plus de {Bot.MaxRealPlayers} vrais joueurs`)
		return
	end
	if state then
		return
	end
	local now = os.clock()
	local since: number = readySince or now
	readySince = since
	if now - since >= Bot.ArriveDelay then
		arrive()
	end
end

-- Défense (vague 37, voir l'en-tête) ---------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[BotService] {message}`)
	end
end

local function insideBox(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Distance à l'horizontale de `point` à l'emprise au sol de `part` (0 au-dessus d'elle).
local function distanceOutside(part: BasePart, point: Vector3): number
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	local dx = math.max(math.abs(p.X) - h.X, 0)
	local dz = math.max(math.abs(p.Z) - h.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function boundsOf(plot: Model): BasePart?
	local found = Find.path(plot, BOUNDS)
	return if found and found:IsA("BasePart") then found :: BasePart else nil
end

-- Porte de la boutique : pivot de PlotDoor/Window (au sol au milieu de l'entrée), sinon nil.
local function doorOf(plot: Model): Vector3?
	local window = Find.path(plot, DOOR_WINDOW)
	if window and window:IsA("Model") then
		return (window :: Model):GetPivot().Position
	elseif window and window:IsA("BasePart") then
		return (window :: BasePart).Position
	end
	return nil
end

-- HumanoidRootPart d'un joueur vivant, ou nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild(ROOT_NAME) else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

-- Humanoid et HumanoidRootPart de l'avatar du bot, ou nil.
local function bodyOf(current: State): (Humanoid?, BasePart?)
	local avatar = current.Avatar
	if avatar == nil or avatar.Parent == nil then
		return nil, nil
	end
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	local root = avatar:FindFirstChild(ROOT_NAME)
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root :: BasePart
end

-- Point d'accroche (voir l'en-tête), remplacé par TutorialService.
function BotService.IsGentle(_player: Player): boolean
	return false
end

local function gentle(player: Player): boolean
	local ok, value = pcall(BotService.IsGentle, player)
	return ok and value == true
end

local function carrying(current: State, player: Player): boolean
	for _, holder in current.Holders do
		if holder == player then
			return true
		end
	end
	return false
end

-- Peut-il encore frapper `player` ? (tuto : Defense.TutorialMaxStrikes coups réussis au plus)
local function canStrike(player: Player): boolean
	return not gentle(player) or (tutorialStrikes[player] or 0) < DEFENSE.TutorialMaxStrikes
end

-- `player` est-il une cible possible ? Son HumanoidRootPart, ou nil (parti, mort, touché, trop loin).
local function reach(current: State, chase: Chase, player: Player): BasePart?
	if player.Parent ~= Players or leaving[player] or chase.Struck[player] then
		return nil
	end
	local root = rootOf(player)
	local bounds = boundsOf(current.Plot)
	if root == nil or (bounds and distanceOutside(bounds, root.Position) > DEFENSE.LeashDistance) then
		return nil
	end
	return root
end

-- Une autre cible : d'abord un voleur qui porte un de ses objets, puis un intrus dans sa boutique.
local function pickTarget(current: State, chase: Chase): Player?
	for _, holder in current.Holders do
		if reach(current, chase, holder) then
			return holder
		end
	end
	local bounds = boundsOf(current.Plot)
	if bounds then
		for _, player in Players:GetPlayers() do
			local root = reach(current, chase, player)
			if root and insideBox(bounds, root.Position) then
				return player
			end
		end
	end
	return nil
end

-- Vers `goal`, par la porte si l'un est dans la boutique et l'autre dehors (chemin simple).
local function walkTowards(current: State, humanoid: Humanoid, root: BasePart, goal: Vector3)
	local bounds = boundsOf(current.Plot)
	local door = doorOf(current.Plot)
	local point = goal
	if bounds and door and insideBox(bounds, root.Position) ~= insideBox(bounds, goal) then
		local passage = Vector3.new(door.X, root.Position.Y, door.Z)
		if (passage - root.Position).Magnitude > DEFENSE.DoorPassDistance then
			point = passage
		end
	end
	humanoid:MoveTo(point)
end

-- Batte en main : TOOL_Batte de Clément (Tool, ou Model avec Handle), sans script ni collision ; sinon rien.
local function equipBat(current: State, humanoid: Humanoid)
	local avatar = current.Avatar
	if current.Bat or avatar == nil then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild(ASSETS)
	local asset = if assets then assets:FindFirstChild(BatConfig.Asset, true) else nil
	if asset == nil or not (asset:IsA("Tool") or asset:IsA("Model")) then
		return
	end
	local clone = asset:Clone()
	local tool: Tool
	if clone:IsA("Tool") then
		tool = clone
	else
		tool = Instance.new("Tool")
		for _, child in clone:GetChildren() do
			child.Parent = tool
		end
		clone:Destroy()
	end
	local handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		tool:Destroy()
		warnOnce("bat", `{asset:GetFullName()} : pas de « Handle », le bot frappe sans batte visible`)
		return
	end
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end
	tool.Name = BatConfig.DisplayName
	tool.Parent = avatar
	pcall(function()
		humanoid:EquipTool(tool)
	end)
	current.Bat = tool
end

-- Il rentre (cible perdue ou temps écoulé).
local function goHome(chase: Chase, why: string)
	if chase.Phase == "Return" then
		return
	end
	chase.Phase = "Return"
	chase.Target = nil
	chase.ReturnedAt = os.clock()
	log(`le bot rentre ({why})`)
end

-- Arrivé (ou replacé) : debout au point d'apparition, ré-ancré, batte rangée, Idle.
local function settle(current: State, humanoid: Humanoid, root: BasePart, why: string)
	local avatar = current.Avatar
	local home = current.Home
	if avatar and home then
		humanoid:MoveTo(home.Position)
		avatar:PivotTo(home)
	end
	root.Anchored = true
	stopTrack(current, RUN)
	stopTrack(current, SWING)
	playLooped(current, IDLE)
	local bat = current.Bat
	if bat then
		bat:Destroy()
		current.Bat = nil
	end
	current.Chase = nil
	log(`le bot est de nouveau à son point d'apparition ({why})`)
end

-- Un coup sur `target` : SwingBat, puis BatService.BotSwing au marqueur Impact (au plus Bat.ImpactMaxWait s après).
local function swing(current: State, chase: Chase, root: BasePart, target: Player, targetRoot: BasePart)
	chase.Swinging = true
	chase.LastSwing = os.clock()
	local look = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
	if (look - root.Position).Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
	local fired = false
	local connection: RBXScriptConnection? = nil
	local function strike()
		if fired then
			return
		end
		fired = true
		local link = connection
		if link then
			link:Disconnect()
		end
		chase.Swinging = false
		if state ~= current or current.Chase ~= chase or chase.Phase ~= "Chase" or root.Parent == nil then
			return
		end
		local sound = playSound
		if sound then
			pcall(sound, SWING_SOUND, root)
		end
		local api = BatHooks
		if api == nil then
			return
		end
		local ok, hit, usage = pcall(api.BotSwing, current.Plot, root, target, boundsOf(current.Plot))
		if not ok then
			warnOnce("swing", `BatService.BotSwing : {hit}`)
			return
		end
		if hit then
			chase.Struck[target] = true
			if chase.Target == target then
				chase.Target = nil
			end
			if gentle(target) then
				tutorialStrikes[target] = (tutorialStrikes[target] or 0) + 1
			end
			log(`le bot frappe {target.Name} ({usage})`)
		end
	end
	local track = trackOf(current, SWING, playerAnimations())
	if track then
		local ok, signal = pcall(function(): RBXScriptSignal
			return track:GetMarkerReachedSignal(IMPACT)
		end)
		if ok then
			connection = signal:Connect(function()
				strike()
			end)
		end
		track:Play()
	end
	task.delay(BatConfig.ImpactMaxWait, strike)
end

-- `player` a cassé sa porte ou pris un de ses objets : il se désancre et lui court après. Sans yield.
local function alert(current: State, player: Player, why: "Door" | "Grab")
	if not DEFENSE.Enabled or state ~= current or player.Parent ~= Players or leaving[player] then
		return
	end
	local humanoid, root = bodyOf(current)
	if humanoid == nil or root == nil then
		return -- avatar pas encore posé (avatar par défaut en préparation)
	end
	local now = os.clock()
	local chase = current.Chase
	if chase == nil then
		local created: Chase = {
			Phase = "Chase",
			Target = player,
			StartedAt = now,
			ReturnedAt = 0,
			LastSwing = -math.huge,
			Swinging = false,
			Struck = {},
		}
		current.Chase = created
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil) -- le serveur le déplace, jamais un client proche
		end)
		stopTrack(current, IDLE)
		playLooped(current, RUN)
		equipBat(current, humanoid)
	else
		local target = chase.Target
		if chase.Phase == "Return" or target == nil or (why == "Grab" and not carrying(current, target)) then
			chase.Target = player
		end
		chase.Phase = "Chase"
		chase.StartedAt = now
		chase.Struck[player] = nil
	end
	log(`le bot poursuit {player.Name} ({if why == "Door" then "porte cassée" else "objet pris"})`)
end

-- 10 fois par seconde : poursuite, coup, retour. Sans yield.
local function defenseStep()
	local current = state
	local chase = if current then current.Chase else nil
	if current == nil or chase == nil then
		return
	end
	local humanoid, root = bodyOf(current)
	if humanoid == nil or root == nil then
		current.Chase = nil
		return
	end
	local now = os.clock()
	if chase.Phase == "Chase" then
		if now - chase.StartedAt > DEFENSE.GiveUpTime then
			goHome(chase, `{DEFENSE.GiveUpTime} s de poursuite`)
		else
			local target = chase.Target
			local targetRoot = if target then reach(current, chase, target) else nil
			if target == nil or targetRoot == nil then
				target = pickTarget(current, chase)
				chase.Target = target
				targetRoot = if target then reach(current, chase, target) else nil
			end
			if target == nil or targetRoot == nil then
				goHome(chase, "plus personne à chasser")
			else
				humanoid.WalkSpeed = if gentle(target) then DEFENSE.TutorialRunSpeed else DEFENSE.RunSpeed
				walkTowards(current, humanoid, root, targetRoot.Position)
				local distance = (targetRoot.Position - root.Position).Magnitude
				-- Frappable comme par un propriétaire : il porte un objet du bot, ou il est dans sa boutique (un
				-- casseur resté devant la porte est suivi, pas frappé).
				local bounds = boundsOf(current.Plot)
				local hittable = carrying(current, target) or (bounds ~= nil and insideBox(bounds, targetRoot.Position))
				if
					hittable
					and not chase.Swinging
					and now - chase.LastSwing >= DEFENSE.SwingCooldown
					and distance <= DEFENSE.SwingRange
					and canStrike(target)
				then
					swing(current, chase, root, target, targetRoot)
				end
			end
		end
	end
	if chase.Phase == "Return" then
		local home = current.Home
		if home == nil then
			settle(current, humanoid, root, "pas de point d'apparition")
			return
		end
		local offset = home.Position - root.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= DEFENSE.HomeDistance then
			settle(current, humanoid, root, "arrivé")
		elseif now - chase.ReturnedAt > DEFENSE.ReturnTimeout then
			settle(current, humanoid, root, `pas rentré en {DEFENSE.ReturnTimeout} s, replacé`)
		else
			humanoid.WalkSpeed = DEFENSE.RunSpeed
			walkTowards(current, humanoid, root, home.Position)
		end
	end
end

-- API --------------------------------------------------------------------------------------------------------

function BotService.IsChasing(player: Player): boolean
	local current = state
	local chase = if current then current.Chase else nil
	return chase ~= nil and chase.Phase == "Chase" and chase.Target == player
end

function BotService.GetBotPlot(): Model?
	local current = state
	return if current then current.Plot else nil
end

function BotService.IsBotPlot(plot: Model): boolean
	return stateOf(plot) ~= nil
end

function BotService.GetExposed(plot: Model): { [number]: DisplayService.ExposedItem }
	local exposed: { [number]: DisplayService.ExposedItem } = {}
	local current = stateOf(plot)
	if current then
		for slot, item in current.Items do
			if current.Held[item.Uid] == nil then
				exposed[slot] = { Uid = item.Uid, ItemId = item.ItemId, Income = item.Income }
			end
		end
	end
	return exposed
end

function BotService.GetIncome(plot: Model): number
	local current = stateOf(plot)
	return if current then incomeOf(current) else 0
end

function BotService.Hold(plot: Model, uid: string, thief: Player): boolean
	local current = stateOf(plot)
	if current == nil or current.Held[uid] ~= nil then
		return false
	end
	for slot, item in current.Items do
		if item.Uid == uid then
			current.Held[uid] = slot
			current.Holders[uid] = thief
			local model = item.Model
			item.Model = nil
			if model then
				model:Destroy()
			end
			publish(current)
			emitTheft(thief, item.ItemId, "Grabbed")
			alert(current, thief, "Grab") -- vague 37 : il défend sa boutique
			return true
		end
	end
	return false
end

function BotService.Release(plot: Model, uid: string, thief: Player): boolean
	local current = stateOf(plot)
	local slot = if current then current.Held[uid] else nil
	if current == nil or slot == nil then
		return false -- le bot est parti : l'objet part avec lui
	end
	current.Held[uid] = nil
	current.Holders[uid] = nil
	local item = current.Items[slot]
	if item == nil or item.Uid ~= uid then
		return false
	end
	show(current, slot, item)
	publish(current)
	emitTheft(thief, item.ItemId, "Returned")
	return true
end

function BotService.IsHeld(plot: Model, uid: string): boolean
	local current = stateOf(plot)
	return current ~= nil and current.Held[uid] ~= nil
end

function BotService.TakeHeld(plot: Model, uid: string, thief: Player): boolean
	local current = stateOf(plot)
	local slot = if current then current.Held[uid] else nil
	if current == nil or slot == nil then
		return false
	end
	current.Held[uid] = nil
	current.Holders[uid] = nil
	local item = current.Items[slot]
	current.Items[slot] = nil
	publish(current)
	-- Un autre Commun revient sur ce présentoir plus tard, si le bot est toujours là.
	task.delay(Bot.RegenDelay, function()
		if state == current and current.Items[slot] == nil then
			newItem(current, slot)
			publish(current)
		end
	end)
	if item then
		-- Découverte dans l'index du voleur : IndexService requiert PvPService, qui requiert ce service ;
		-- il est donc chargé ici, au moment du vol, jamais au chargement des modules.
		local module = script.Parent:FindFirstChild("IndexService")
		if module and module:IsA("ModuleScript") then
			local ok, err = pcall(function()
				local index: any = require(module) :: any
				index.Discover(thief, item.ItemId)
			end)
			if not ok then
				warnOnce("index", `IndexService.Discover : {err}`)
			end
		end
		emitTheft(thief, item.ItemId, "Stolen")
	end
	return true
end

function BotService.OnTheft(listener: TheftListener): () -> ()
	return subscribe(theftListeners, listener)
end

function BotService.OnChanged(listener: ChangedListener): () -> ()
	return subscribe(changedListeners, listener)
end

function BotService.Init()
	-- Porte du bot : cassable, aux PV d'un profil neuf (voir l'en-tête).
	local previousFreePlotHP = WindowService.GetFreePlotHP
	WindowService.GetFreePlotHP = function(model: Model): number
		if stateOf(model) then
			return DOOR_HP
		end
		return previousFreePlotHP(model)
	end
	PlotService.OnShortage(function()
		leave("boutique manquante pour un vrai joueur")
	end)
	-- Vague 37 : porte du bot cassée, il poursuit celui qui l'a cassée.
	WindowService.OnBroken(function(info: WindowService.BreakInfo)
		local current = if info.Kind == "Plot" then stateOf(info.Model) else nil
		if current then
			alert(current, info.Breaker, "Door")
		end
	end)
	Players.PlayerAdded:Connect(function()
		evaluate() -- départ immédiat au 5e vrai joueur
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		leaving[player] = true
	end)
	if not Bot.Enabled then
		print("[BotService] Bot.Enabled = false : pas de bot joueur")
	end
end

function BotService.Start()
	if not Bot.Enabled then
		return
	end
	task.spawn(getTemplate) -- avatar préparé tout de suite (attend Roblox), pas à la première arrivée
	if DEFENSE.Enabled then
		task.spawn(function()
			while true do
				task.wait(DEFENSE.Tick)
				local ok, err = pcall(defenseStep :: any) -- :: any : comme le tick ci-dessous (ancien solveur)
				if not ok then
					warnOnce("defense", `défense : {err}`)
				end
			end
		end)
	end
	while true do
		local ok, err = pcall(evaluate :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warnOnce("tick", `tick : {err}`)
		end
		task.wait(Bot.CheckInterval)
	end
end

return BotService
