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
--     exposée (objets tenus exclus), lue par PvPController (panneau, anti-racket) ;
--   - vol (PvPService, voir son en-tête) : Hold (un voleur prend l'objet : il quitte le présentoir),
--     Release (vol raté : il revient), TakeHeld (dépôt chez le voleur : il est à lui ; immunité de
--     Bot.TheftImmunity s, puis un autre Commun de la zone 1 revient sur ce présentoir Bot.RegenDelay s
--     plus tard) ; découverte dans l'index du voleur (IndexService.Discover) ;
--   - avatar : modèle de Clément s'il est livré (ReplicatedStorage/Assets/<Bot.AvatarFolder>/
--     <Bot.AvatarName>, proposé, absent du contrat), sinon l'avatar R15 par défaut de Roblox
--     (Players:CreateHumanoidModelFromDescriptionAsync, préparé une fois), debout au point d'apparition
--     du propriétaire (PlotService.GetSpawnSpot), HumanoidRootPart ancré, aucune collision ni requête,
--     scripts retirés, nom Bot.DisplayName au-dessus de lui, animation Animations/Idle en boucle (celle
--     de Clément, ou l'idle par défaut de Roblox gardée du script Animate). V0 : il ne bouge pas ;
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
--   BotService.GetImmunity(plot) -> number     secondes d'immunité restantes après un vol subi, 0 sinon
--   BotService.OnTheft(listener) -> déconnexion
--       listener(thief, itemId, stage) : "Grabbed" (le voleur l'a pris), "Returned" (vol raté, l'objet est
--       revenu) ou "Stolen" (déposé chez le voleur, il est à lui).
--   BotService.OnChanged(listener) -> déconnexion
--       listener(plot?) à l'arrivée du bot (sa boutique) et à son départ (nil).
-- Pour PvPService seulement (sans yield) : Hold(plot, uid, thief) -> boolean, Release(plot, uid, thief) ->
-- boolean, IsHeld(plot, uid) -> boolean, TakeHeld(plot, uid, thief) -> boolean.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bot = require(Shared.Config.Bot)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)

local DisplayService = require(script.Parent.DisplayService)
local PlotService = require(script.Parent.PlotService)
local WindowService = require(script.Parent.WindowService)

export type TheftStage = "Grabbed" | "Returned" | "Stolen"
type TheftListener = (thief: Player, itemId: string, stage: TheftStage) -> ()
type ChangedListener = (plot: Model?) -> ()

type BotItem = {
	Uid: string,
	ItemId: string,
	Income: number,
	Model: Model?, -- nil pendant qu'un voleur le tient
}

-- Le bot présent : sa boutique, ses objets, son immunité, son avatar.
type State = {
	Plot: Model,
	Folder: Folder,
	Items: { [number]: BotItem }, -- par présentoir
	Held: { [string]: number }, -- uid tenu par un voleur -> présentoir
	ImmuneUntil: number, -- os.clock()
	Avatar: Model?,
}

-- Mêmes noms que DisplayService (dossier des objets exposés) et PvPController (valeur exposée du bot).
local FOLDER_NAME = "DisplayItems"
local INCOME_ATTRIBUTE = "BotIncome"
local AVATAR_NAME = "BotAvatar"
local ASSETS = "Assets"
local ANIMATIONS = "Animations" -- contrat 2.4 : <Modèle>/Animations/<Nom>
local IDLE = "Idle"
local ROOT_NAME = "HumanoidRootPart"
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
	local animations = model:FindFirstChild(ANIMATIONS)
	if animations == nil or animations:FindFirstChild(IDLE) == nil then
		-- Rig de Roblox : son script Animate porte l'idle par défaut (animation de Roblox, jouable partout).
		local animate = model:FindFirstChild("Animate")
		local idle = if animate then animate:FindFirstChild("idle") else nil
		local source = if idle then idle:FindFirstChildWhichIsA("Animation") else nil
		if source then
			local folder: Instance? = animations
			if folder == nil then
				local created = Instance.new("Folder")
				created.Name = ANIMATIONS
				created.Parent = model
				folder = created
			end
			local copy = source:Clone()
			copy.Name = IDLE
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

local function playIdle(avatar: Model, humanoid: Humanoid)
	local folder = avatar:FindFirstChild(ANIMATIONS)
	local animation = if folder then folder:FindFirstChild(IDLE) else nil
	if animation == nil or not animation:IsA("Animation") then
		return
	end
	local ok, err = pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator == nil then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
		local track = (animator :: Animator):LoadAnimation(animation :: Animation)
		track.Looped = true
		track:Play()
	end)
	if not ok then
		warnOnce("idle", `animation {IDLE} du bot : {err}`)
	end
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
	playIdle(avatar, humanoid)
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
	local current: State = { Plot = plot, Folder = folder, Items = {}, Held = {}, ImmuneUntil = 0, Avatar = nil }
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

-- API --------------------------------------------------------------------------------------------------------

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

function BotService.GetImmunity(plot: Model): number
	local current = stateOf(plot)
	if current == nil then
		return 0
	end
	return math.max(0, current.ImmuneUntil - os.clock())
end

function BotService.Hold(plot: Model, uid: string, thief: Player): boolean
	local current = stateOf(plot)
	if current == nil or current.Held[uid] ~= nil then
		return false
	end
	for slot, item in current.Items do
		if item.Uid == uid then
			current.Held[uid] = slot
			local model = item.Model
			item.Model = nil
			if model then
				model:Destroy()
			end
			publish(current)
			emitTheft(thief, item.ItemId, "Grabbed")
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
	local item = current.Items[slot]
	current.Items[slot] = nil
	current.ImmuneUntil = os.clock() + Bot.TheftImmunity
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
	while true do
		local ok, err = pcall(evaluate :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warnOnce("tick", `tick : {err}`)
		end
		task.wait(Bot.CheckInterval)
	end
end

return BotService
