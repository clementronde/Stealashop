--!strict
-- ShopDefenseService (vague GC6, a408 ; MAJ 5 « Défense de la boutique », Cantin 23/11 : tout maintenant) : les tuiles
-- « Soon » de l'arbre de compétences devenues jouables, sur la boutique d'un vrai joueur (jamais celle du bot).
-- Valeurs : Config/ShopDefense (V0 proposés, Cantin, 23/11) ; prix et niveaux : Config/SkillTree ; interrupteurs :
-- Features.Bodyguards, Features.DoorGuard, Features.CameraRadar. GuardService et BotService ne sont pas touchés : l'IA
-- reprend en plus simple celle du bot qui défend (L-146 ; BotService, chemin par la porte) et la capture du vigile
-- (Balance.Guard.CatchDistance, animation Catch au marqueur Impact).
--
-- Agents (modèles proposés à Clément, facultatifs : ReplicatedStorage/Assets/Guards/NPC_Bodyguard et NPC_DoorGuard,
-- sinon le vigile commun Guard, sinon l'avatar R15 par défaut de Roblox ; scripts retirés, pièces sans collision ni
-- contact ni requête, HumanoidRootPart ancré au repos ; Idle et Run du modèle, sinon ceux du script Animate de Roblox) :
-- posés dans un dossier ShopDefense de la boutique, revus chaque ShopDefense.SyncInterval s (achat, renaissance,
-- départ, boutique libérée, porte déplacée par un nouvel étage).
--
-- Bodyguards (Partie 2, section 2) : l'agent attend à son poste dans la boutique (repère BodyguardSpot, sinon
-- PostInset studs à l'intérieur de la porte), face à la porte. Quand un voleur prend un objet du propriétaire
-- (PvPService.OnTheftStarted), il part ReactDelay s plus tard et lui court après à la vitesse de la tuile (Effects,
-- × SpeedScale), par la porte quand l'un est dedans et l'autre dehors. À CatchDistance studs, il joue Catch ; au
-- marqueur Impact (au plus ImpactMaxWait s après), si le voleur porte toujours l'objet, est à CatchDistance +
-- CatchTolerance studs et sans mur entre eux : l'objet revient sur son présentoir (CarryService.FailNoDrop,
-- « Bodyguard ») et le voleur est sorti et interdit de cette boutique comme après un coup du propriétaire
-- (PvPService.KickOut, L-115). Jamais d'invulnérabilité (L-163) : il lâche un voleur à plus de LeashDistance studs de
-- Bounds, abandonne au bout de GiveUpTime s, ne suit qu'un voleur à la fois. Retour : il court à son poste et s'y
-- ré-ancre ; replacé d'un coup au bout de ReturnTimeout s, ou tout de suite s'il est dehors et que la porte est refaite.
--
-- DoorGuard (L-163) : l'agent est debout dehors, à côté de la porte (repère DoorGuardSpot, sinon Outset studs devant et
-- Side studs à côté), face à la rue. Au plus une fois toutes les Effects[1] s, il repousse le joueur le plus proche à
-- Range studs ou moins de la porte qui la casse (WindowService.IsBreaking) ou qui entre par la porte cassée les mains
-- vides : Catch, puis au marqueur la poussée d'un coup de batte (Bat.Knockback*, × PushFactor), vers la rue, et un
-- Notify. Jamais le propriétaire, ni un voleur qui sort avec un objet.
--
-- Cameras niveau 3 (L-163, V0 de L-175, sans flèche) : rien de plus au premier coup sur la porte (SkillTreeService
-- envoie déjà CameraSpotted) ; quand un voleur prend un objet d'un propriétaire qui a Cameras 3, CameraSpotted(voleur,
-- maintenant + Effects[3]) repart vers ce propriétaire : son CameraAlertController le surligne en rouge vif et fait
-- sonner le radar tout le temps de la fuite.
--
-- API (serveur, pour les bancs et la barre de commande) :
--   ShopDefenseService.Sync()          pose ou retire tout de suite les agents
--   ShopDefenseService.Step()          un pas de poursuite et de poussée, tout de suite
--   ShopDefenseService.GetGuards(plot) -> { Body = { Phase, Target, Avatar }?, Door = { Avatar, LastPush }? }
-- Tester dans Studio (barre de commande serveur, en Play) : workspace:SetAttribute("SkillTest", "<joueur> Bodyguards 3")
-- ou "<joueur> DoorGuard 1" ou "<joueur> Cameras 3" (SkillTreeService), puis voler sa boutique avec un 2e joueur.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Bat = require(Shared.Config.Bat)
local Features = require(Shared.Config.Features)
local ShopDefense = require(Shared.Config.ShopDefense)
local CatchReach = require(Shared.CatchReach)
local Find = require(Shared.Contract.Find)
local Net = require(Shared.Net.Net)

local AntiCheatService = require(script.Parent.AntiCheatService)
local CarryService = require(script.Parent.CarryService)
local PlotService = require(script.Parent.PlotService)
local PvPService = require(script.Parent.PvPService)
local SkillTreeService = require(script.Parent.SkillTreeService)
local WindowService = require(script.Parent.WindowService)

type Kind = "Body" | "Door"

type Guard = {
	Kind: Kind,
	Plot: Model,
	Owner: Player,
	Avatar: Model?,
	Home: CFrame?, -- pivot de l'avatar à son poste
	Tracks: { [string]: AnimationTrack },
	Phase: "Idle" | "Chase" | "Return",
	Target: Player?,
	StartedAt: number, -- os.clock() du dernier vol qui l'a lancé
	ReactAt: number, -- os.clock() de son départ
	ReturnedAt: number,
	Acting: boolean, -- Catch en cours (capture ou poussée)
	LastPush: number,
	Dropped: { [Player]: boolean }, -- voleurs lâchés (laisse, temps) jusqu'au prochain vol
	Removed: boolean,
}

type Entry = { Body: Guard?, Door: Guard? }

local B = ShopDefense.Bodyguard
local D = ShopDefense.DoorGuard
local R = ShopDefense.CameraRadar

local BOUNDS = "Bounds" -- contrat 10.4
local DOOR_WINDOW = "PlotDoor.Window" -- PLOT_Shop (L-050), comme BotService
local ROOT_NAME = "HumanoidRootPart"
local ANIMATIONS = "Animations" -- contrat 2.4
local IDLE, RUN, CATCH, IMPACT = "Idle", "Run", "Catch", "Impact" -- Contract/Animations.ShopGuard
local FOLDER_NAME = "ShopDefense" -- dossier des agents dans la boutique
local AVATAR_NAMES: { [Kind]: string } = { Body = "Bodyguard", Door = "DoorGuard" }
local SKILL_OF: { [Kind]: string } = { Body = "Bodyguards", Door = "DoorGuard" }
local CAUGHT_REASON = "Bodyguard" -- raison du portage raté (CarryService, PvPService le rend au présentoir)
local PUSH_NAME = "DoorGuardPush"
-- Animations par défaut de Roblox gardées du script Animate quand le modèle n'a pas les siennes (comme BotService).
local DEFAULT_ANIMATIONS: { { Name: string, From: { string } } } = {
	{ Name = IDLE, From = { "idle" } },
	{ Name = RUN, From = { "run", "walk" } },
}
local SPAWN_LIFT = 0.1 -- comme PlotService et BotService
local GROUND_RAY_UP = 3
local GROUND_RAY_DOWN = 20
local TEMPLATE_WAIT = 10
local MOVED_EPSILON = 1 -- studs : poste déplacé (nouvel étage), l'agent au repos y est replacé
local IS_STUDIO = RunService:IsStudio()

local ShopDefenseService = {}
-- Après PvPService (120) et SkillTreeService (100), dont il écoute les signaux.
ShopDefenseService.Priority = 125

local entries: { [Model]: Entry } = {}
local templates: { [Kind]: Model? } = {}
local templateStatus: { [Kind]: "None" | "Building" | "Ready" } = { Body = "None", Door = "None" }
local warned: { [string]: boolean } = {}
local sinceSync = 0

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[ShopDefenseService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[ShopDefenseService] {message}`)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warnOnce("notify", `Notify vers {player.Name} : {err}`)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function level(owner: Player, id: string): number
	local ok, value = pcall(SkillTreeService.GetLevel, owner, id)
	return if ok and type(value) == "number" then value else 0
end

local function effect(owner: Player, id: string): number?
	local ok, value = pcall(SkillTreeService.GetEffect, owner, id)
	return if ok and type(value) == "number" and value == value then value else nil
end

local function enabled(kind: Kind): boolean
	return if kind == "Body" then Features.Bodyguards == true else Features.DoorGuard == true
end

local function isThief(player: Player, owner: Player): boolean
	local ok, value = pcall(PvPService.IsThiefOf, player, owner)
	return ok and value == true
end

local function insideBox(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Distance à l'horizontale de `point` à l'emprise au sol de `part` (0 au-dessus d'elle), comme BotService.
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

-- Vers la rue : du centre de Bounds vers la porte, à l'horizontale ; nil sans l'un des deux.
local function outwardOf(plot: Model): Vector3?
	local bounds, door = boundsOf(plot), doorOf(plot)
	if bounds == nil or door == nil then
		return nil
	end
	local v = flat(door - bounds.Position)
	return if v.Magnitude > 1e-3 then v.Unit else nil
end

local function doorBroken(plot: Model): boolean
	local ok, value = pcall(function(): boolean
		local id = WindowService.GetWindowId(plot)
		return id ~= nil and WindowService.IsBroken(id)
	end)
	return ok and value == true
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

local function bodyOf(guard: Guard): (Humanoid?, BasePart?)
	local avatar = guard.Avatar
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

-- Rayons de la ligne de vue : les personnages et les agents ne bloquent pas.
local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- volumes Bounds, vitre cassée, objet porté : ne cachent rien (comme GuardService)
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, entry in entries do
		for _, guard in { entry.Body, entry.Door } :: { Guard? } do
			if guard and guard.Avatar then
				table.insert(ignore, guard.Avatar)
			end
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

------------------------------------------------------------------------------
-- Modèle
------------------------------------------------------------------------------

-- Le modèle `name` du dossier Guards de Clément (ReplicatedStorage/Assets, puis ServerStorage/Assets), rig utilisable.
local function findModel(name: string): Model?
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild("Assets")
		local folder = if assets then assets:FindFirstChild(ShopDefense.GuardsFolder) else nil
		local model = if folder then folder:FindFirstChild(name) else nil
		if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			local root = model:FindFirstChild(ROOT_NAME)
			if root and root:IsA("BasePart") then
				return model :: Model
			end
		end
	end
	return nil
end

local function defaultAvatar(): Model?
	local description = Instance.new("HumanoidDescription")
	local ok, result = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if ok then
		return result
	end
	warnOnce("default", `avatar R15 par défaut impossible ({result}) : pas d'agent visible`)
	return nil
end

-- Prépare une copie une fois (comme BotService.prepare) : animations par défaut gardées, scripts retirés, pièces
-- sans collision, ni contact, ni requête, HumanoidRootPart seul ancré.
local function prepare(model: Model, kind: Kind): Model?
	model.Name = AVATAR_NAMES[kind]
	local animations: Instance? = model:FindFirstChild(ANIMATIONS)
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
			if animations == nil then
				local created = Instance.new("Folder")
				created.Name = ANIMATIONS
				created.Parent = model
				animations = created
			end
			local copy = source:Clone()
			copy.Name = entry.Name
			copy.Parent = animations
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
	humanoid.DisplayName = if kind == "Body" then B.DisplayName else D.DisplayName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	model.PrimaryPart = root :: BasePart
	return model
end

-- Le modèle préparé de ce genre d'agent, construit au premier besoin (peut attendre) ; nil sans modèle possible.
local function getTemplate(kind: Kind): Model?
	if templateStatus[kind] == "Ready" then
		return templates[kind]
	end
	if templateStatus[kind] == "Building" then
		local deadline = os.clock() + TEMPLATE_WAIT
		while templateStatus[kind] == "Building" and os.clock() < deadline do
			task.wait(0.1)
		end
		return templates[kind]
	end
	templateStatus[kind] = "Building"
	local source: Model? = nil
	for _, name in (if kind == "Body" then B.Models else D.Models) :: { string } do
		local found = findModel(name)
		if found then
			source = found:Clone()
			break
		end
	end
	local model = source or defaultAvatar()
	templates[kind] = if model then prepare(model, kind) else nil
	templateStatus[kind] = "Ready"
	return templates[kind]
end

local function trackOf(guard: Guard, name: string): AnimationTrack?
	local cached = guard.Tracks[name]
	if cached then
		return cached
	end
	local avatar = guard.Avatar
	local humanoid = if avatar then avatar:FindFirstChildOfClass("Humanoid") else nil
	local folder = if avatar then avatar:FindFirstChild(ANIMATIONS) else nil
	local animation = if folder then folder:FindFirstChild(name) else nil
	if humanoid == nil or animation == nil or not animation:IsA("Animation") then
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
		warnOnce(`anim-{name}`, `animation {name} de l'agent : {result}`)
		return nil
	end
	guard.Tracks[name] = result
	return result
end

local function playLooped(guard: Guard, name: string)
	local track = trackOf(guard, name)
	if track then
		track.Looped = true
		track:Play()
	end
end

local function stopTrack(guard: Guard, name: string)
	local track = guard.Tracks[name]
	if track then
		track:Stop()
	end
end

------------------------------------------------------------------------------
-- Poste
------------------------------------------------------------------------------

-- Sol sous `point` (rayon vers le bas, personnages et agents ignorés), sinon `fallbackY`.
local function groundAt(point: Vector3, fallbackY: number): Vector3
	local origin = Vector3.new(point.X, point.Y + GROUND_RAY_UP, point.Z)
	local ok, result = pcall(function(): RaycastResult?
		return Workspace:Raycast(origin, Vector3.new(0, -(GROUND_RAY_UP + GROUND_RAY_DOWN), 0), rayParams())
	end)
	if ok and result then
		return result.Position
	end
	return Vector3.new(point.X, fallbackY, point.Z)
end

local function spotOf(plot: Model, name: string): Vector3?
	local found = Find.path(plot, name)
	if found == nil then
		return nil
	elseif found:IsA("Attachment") then
		return (found :: Attachment).WorldPosition
	elseif found:IsA("BasePart") then
		local part = found :: BasePart
		return part.Position - Vector3.new(0, part.Size.Y / 2, 0)
	end
	return nil
end

-- Point au sol et direction du regard du poste de ce genre d'agent, ou nil (porte ou Bounds absents).
local function postOf(kind: Kind, plot: Model): (Vector3?, Vector3?)
	local door = doorOf(plot)
	local outward = outwardOf(plot)
	if door == nil or outward == nil then
		return nil, nil
	end
	local spot: Vector3?
	local facing: Vector3
	if kind == "Body" then
		spot = spotOf(plot, B.SpotName) or (door - outward * B.PostInset)
		local look = flat(door - (spot :: Vector3))
		facing = if look.Magnitude > 1e-3 then look.Unit else outward
	else
		local side = outward:Cross(Vector3.new(0, 1, 0))
		spot = spotOf(plot, D.SpotName) or (door + outward * D.Outset + side * D.Side)
		facing = outward
	end
	return groundAt(spot :: Vector3, door.Y), facing
end

-- Pivot de l'avatar debout à son poste, ou nil.
local function homeFor(guard: Guard, avatar: Model): CFrame?
	local ground, facing = postOf(guard.Kind, guard.Plot)
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	local root = avatar:FindFirstChild(ROOT_NAME)
	if ground == nil or facing == nil or humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local rootPart = root :: BasePart
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local position = ground + Vector3.new(0, hip + rootPart.Size.Y / 2 + SPAWN_LIFT, 0)
	return CFrame.lookAt(position, position + facing) * rootPart.CFrame:ToObjectSpace(avatar:GetPivot())
end

local function folderOf(plot: Model): Folder
	local found = plot:FindFirstChild(FOLDER_NAME)
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = plot
	return folder
end

-- Pose l'avatar (peut attendre : avatar par défaut de Roblox) ; l'agent a pu être retiré entre-temps.
local function spawnAvatar(guard: Guard)
	local template = getTemplate(guard.Kind)
	if guard.Removed or template == nil then
		return
	end
	local avatar = template:Clone()
	local home = homeFor(guard, avatar)
	if home == nil then
		avatar:Destroy()
		warnOnce(`post-{guard.Plot.Name}`, `{guard.Plot.Name} : ni porte PlotDoor/Window ni Bounds, pas d'agent`)
		return
	end
	avatar:PivotTo(home)
	avatar.Parent = folderOf(guard.Plot)
	guard.Avatar = avatar
	guard.Home = home
	playLooped(guard, IDLE)
	log(`{AVATAR_NAMES[guard.Kind]} posé dans la boutique de {guard.Owner.Name}`)
end

local function removeGuard(guard: Guard)
	guard.Removed = true
	local avatar = guard.Avatar
	guard.Avatar = nil
	if avatar then
		avatar:Destroy()
	end
end

------------------------------------------------------------------------------
-- Gestes
------------------------------------------------------------------------------

-- Joue Catch et appelle `fn` au marqueur Impact, ou `maxWait` s après (une seule fois).
local function act(guard: Guard, maxWait: number, fn: () -> ())
	guard.Acting = true
	local fired = false
	local connection: RBXScriptConnection? = nil
	local function go()
		if fired then
			return
		end
		fired = true
		local link = connection
		if link then
			link:Disconnect()
		end
		guard.Acting = false
		if not guard.Removed then
			fn()
		end
	end
	local track = trackOf(guard, CATCH)
	if track then
		pcall(function()
			connection = track:GetMarkerReachedSignal(IMPACT):Connect(go)
		end)
		track:Play()
	end
	task.delay(maxWait, go)
end

local function face(root: BasePart, at: Vector3)
	local look = Vector3.new(at.X, root.Position.Y, at.Z)
	if (look - root.Position).Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
end

-- Arrivé (ou replacé) : à son poste, ré-ancré, Idle.
local function settle(guard: Guard, why: string)
	local humanoid, root = bodyOf(guard)
	local avatar, home = guard.Avatar, guard.Home
	if avatar and home then
		avatar:PivotTo(home)
	end
	if humanoid and root and home then
		humanoid:MoveTo(root.Position)
	end
	if root then
		root.Anchored = true
	end
	stopTrack(guard, RUN)
	playLooped(guard, IDLE)
	guard.Phase = "Idle"
	guard.Target = nil
	guard.Dropped = {}
	log(`l'agent de {guard.Owner.Name} est à son poste ({why})`)
end

local function goHome(guard: Guard, why: string)
	local _, root = bodyOf(guard)
	if root == nil or root.Anchored then
		settle(guard, why) -- jamais parti (départ pas encore donné)
		return
	end
	guard.Phase = "Return"
	guard.Target = nil
	guard.ReturnedAt = os.clock()
	log(`l'agent de {guard.Owner.Name} rentre ({why})`)
end

-- Vers `goal`, par la porte si l'un est dans la boutique et l'autre dehors (chemin simple, comme le bot).
local function walkTowards(guard: Guard, humanoid: Humanoid, root: BasePart, goal: Vector3)
	local bounds = boundsOf(guard.Plot)
	local door = doorOf(guard.Plot)
	local point = goal
	if bounds and door and insideBox(bounds, root.Position) ~= insideBox(bounds, goal) then
		local passage = Vector3.new(door.X, root.Position.Y, door.Z)
		if (passage - root.Position).Magnitude > B.DoorPassDistance then
			point = passage
		end
	end
	humanoid:MoveTo(point)
end

------------------------------------------------------------------------------
-- Bodyguards
------------------------------------------------------------------------------

-- Le HumanoidRootPart de `player` s'il est encore une cible de l'agent (il porte un objet du propriétaire, il n'a pas
-- été lâché, il est dans la laisse), sinon nil (lâché pour ce vol s'il est hors de la laisse).
local function quarryRoot(guard: Guard, player: Player): BasePart?
	if player.Parent ~= Players or guard.Dropped[player] or not isThief(player, guard.Owner) then
		return nil
	end
	local root = rootOf(player)
	if root == nil then
		return nil
	end
	local bounds = boundsOf(guard.Plot)
	if bounds and distanceOutside(bounds, root.Position) > B.LeashDistance then
		guard.Dropped[player] = true
		log(`l'agent de {guard.Owner.Name} lâche {player.Name} (plus de {B.LeashDistance} studs de la boutique)`)
		return nil
	end
	return root
end

local function pickQuarry(guard: Guard): (Player?, BasePart?)
	for _, player in Players:GetPlayers() do
		if player ~= guard.Owner then
			local root = quarryRoot(guard, player)
			if root then
				return player, root
			end
		end
	end
	return nil, nil
end

local function catch(guard: Guard, target: Player)
	act(guard, B.ImpactMaxWait, function()
		if guard.Phase ~= "Chase" or guard.Target ~= target then
			return
		end
		local _, root = bodyOf(guard)
		local targetRoot = rootOf(target)
		if root == nil or targetRoot == nil or not isThief(target, guard.Owner) then
			return
		end
		if not CatchReach.InRange(root.Position, targetRoot.Position, B.CatchDistance + B.CatchTolerance) then
			return
		end
		local seen = CatchReach.CanTouch(root.Position, targetRoot, rayParams())
		if not seen then
			return
		end
		pcall(CarryService.FailNoDrop, target, CAUGHT_REASON)
		local ok, err = pcall(PvPService.KickOut, guard.Plot, target, "attrapé par l'agent de sécurité")
		if not ok then
			warnOnce("kick", `PvPService.KickOut : {err}`)
		end
		if guard.Owner.Parent == Players then
			notify(guard.Owner, string.format(ShopDefense.Messages.OwnerCaught, target.DisplayName), "Success")
		end
		log(`l'agent de {guard.Owner.Name} attrape {target.Name} : l'objet revient`)
		goHome(guard, "voleur attrapé")
	end)
end

local function bodyStep(guard: Guard, now: number)
	if guard.Phase == "Idle" or guard.Acting then
		return
	end
	local humanoid, root = bodyOf(guard)
	if humanoid == nil or root == nil then
		guard.Phase = "Idle"
		guard.Target = nil
		return
	end
	if guard.Phase == "Chase" then
		local target = guard.Target
		local targetRoot = if target then quarryRoot(guard, target) else nil
		if targetRoot == nil then
			target, targetRoot = pickQuarry(guard)
			guard.Target = target
		end
		if target == nil or targetRoot == nil then
			goHome(guard, "plus de voleur")
		elseif now - guard.StartedAt > B.GiveUpTime then
			guard.Dropped[target] = true
			goHome(guard, `{B.GiveUpTime} s de poursuite`)
		elseif now < guard.ReactAt then
			if root.Anchored then
				face(root, targetRoot.Position)
			end
		else
			if root.Anchored then
				root.Anchored = false
				pcall(function()
					root:SetNetworkOwner(nil) -- le serveur le déplace, jamais un client proche
				end)
				stopTrack(guard, IDLE)
				playLooped(guard, RUN)
			end
			humanoid.WalkSpeed = (effect(guard.Owner, "Bodyguards") or 0) * B.SpeedScale
			walkTowards(guard, humanoid, root, targetRoot.Position)
			if CatchReach.InRange(root.Position, targetRoot.Position, B.CatchDistance) then
				catch(guard, target)
			end
		end
	end
	if guard.Phase == "Return" then
		local home = guard.Home
		if home == nil then
			settle(guard, "pas de poste")
			return
		end
		local bounds = boundsOf(guard.Plot)
		local offset = home.Position - root.Position
		if flat(offset).Magnitude <= B.HomeDistance then
			settle(guard, "arrivé")
		elseif now - guard.ReturnedAt > B.ReturnTimeout then
			settle(guard, `pas rentré en {B.ReturnTimeout} s, replacé`)
		elseif bounds and not insideBox(bounds, root.Position) and not doorBroken(guard.Plot) then
			settle(guard, "dehors et porte refaite, replacé")
		else
			humanoid.WalkSpeed = B.ReturnSpeed * B.SpeedScale
			walkTowards(guard, humanoid, root, home.Position)
		end
	end
end

-- Un voleur a pris un objet de `victim` : l'agent de sa boutique part après lui ; Cameras 3 relance le radar.
local function onTheftStarted(thief: Player, victim: Player, _itemId: string)
	if Features.CameraRadar == true and level(victim, "Cameras") >= R.Level then
		local duration = effect(victim, "Cameras")
		if duration and duration > 0 then
			local ok, err = pcall(function()
				Net.Server.CameraSpotted:Fire(victim, thief, Workspace:GetServerTimeNow() + duration)
			end)
			if not ok then
				warnOnce("spotted", `CameraSpotted vers {victim.Name} : {err}`)
			end
		end
	end
	local plot = PlotService.GetPlot(victim)
	local entry = if plot then entries[plot] else nil
	local guard = if entry then entry.Body else nil
	if guard == nil or guard.Avatar == nil or guard.Owner ~= victim then
		return
	end
	local now = os.clock()
	guard.Dropped[thief] = nil
	guard.StartedAt = now
	if guard.Phase ~= "Chase" then
		guard.Phase = "Chase"
		guard.Target = thief
		local _, root = bodyOf(guard)
		guard.ReactAt = if root and root.Anchored then now + B.ReactDelay else now
	elseif guard.Target == nil or quarryRoot(guard, guard.Target :: Player) == nil then
		guard.Target = thief
	end
	log(`l'agent de {victim.Name} poursuit {thief.Name}`)
end

------------------------------------------------------------------------------
-- DoorGuard
------------------------------------------------------------------------------

local function breaking(plot: Model, player: Player): boolean
	local ok, value = pcall(WindowService.IsBreaking, plot, player)
	return ok and value == true
end

-- Poussée d'un coup de batte (comme BatService.knockback), × PushFactor, dans le sens `direction`.
local function push(player: Player, root: BasePart, direction: Vector3)
	AntiCheatService.Allow(player, Bat.KnockbackDuration, "ShopDefenseService (garde de la porte)") -- poussée du code (DEV-060)
	local attachment = Instance.new("Attachment")
	attachment.Name = PUSH_NAME
	local mover = Instance.new("LinearVelocity")
	mover.Name = PUSH_NAME
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.MaxForce = math.huge
	mover.VectorVelocity = direction * (Bat.KnockbackHorizontalSpeed * D.PushFactor)
		+ Vector3.new(0, Bat.KnockbackVerticalSpeed, 0)
	mover.Parent = attachment
	attachment.Parent = root
	Debris:AddItem(attachment, Bat.KnockbackDuration)
end

-- Le joueur que le garde doit repousser (le plus proche de la porte), ou nil.
local function pushTarget(guard: Guard, door: Vector3): (Player?, BasePart?)
	local broken = doorBroken(guard.Plot)
	local best: Player?, bestRoot: BasePart?, bestDistance = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		if player == guard.Owner then
			continue
		end
		local root = rootOf(player)
		if root == nil then
			continue
		end
		local distance = flat(root.Position - door).Magnitude
		if distance > D.Range or distance >= bestDistance then
			continue
		end
		local entering = broken and not isThief(player, guard.Owner) and not CarryService.IsCarrying(player)
		if breaking(guard.Plot, player) or entering then
			best, bestRoot, bestDistance = player, root, distance
		end
	end
	return best, bestRoot
end

local function doorStep(guard: Guard, now: number)
	if guard.Acting then
		return
	end
	local _, root = bodyOf(guard)
	if root == nil then
		return
	end
	local interval = effect(guard.Owner, "DoorGuard") or 0
	if interval <= 0 or now - guard.LastPush < interval then
		return
	end
	local door = doorOf(guard.Plot)
	if door == nil then
		return
	end
	local target, targetRoot = pushTarget(guard, door)
	if target == nil or targetRoot == nil then
		return
	end
	guard.LastPush = now
	face(root, targetRoot.Position)
	act(guard, D.ImpactMaxWait, function()
		local again = rootOf(target)
		local doorNow = doorOf(guard.Plot)
		if again == nil or doorNow == nil or flat(again.Position - doorNow).Magnitude > D.Range + 2 then
			return
		end
		local direction = outwardOf(guard.Plot) or flat(again.Position - doorNow)
		if direction.Magnitude < 1e-3 then
			return
		end
		push(target, again, direction.Unit)
		notify(target, ShopDefense.Messages.DoorPushed, "Alert")
		log(`le garde de la porte de {guard.Owner.Name} repousse {target.Name}`)
		local home = guard.Home
		if home and guard.Avatar then
			task.delay(1, function()
				local avatar = guard.Avatar
				if not guard.Removed and not guard.Acting and avatar then
					avatar:PivotTo(home) -- reprend son regard vers la rue
				end
			end)
		end
	end)
end

------------------------------------------------------------------------------
-- Pose et retrait
------------------------------------------------------------------------------

local function newGuard(kind: Kind, plot: Model, owner: Player): Guard
	return {
		Kind = kind,
		Plot = plot,
		Owner = owner,
		Avatar = nil,
		Home = nil,
		Tracks = {},
		Phase = "Idle",
		Target = nil,
		StartedAt = 0,
		ReactAt = 0,
		ReturnedAt = 0,
		Acting = false,
		LastPush = -math.huge,
		Dropped = {},
		Removed = false,
	}
end

-- L'agent `kind` de `plot` : posé, retiré ou replacé selon le propriétaire, son niveau et l'interrupteur.
local function syncKind(plot: Model, owner: Player?, entry: Entry, kind: Kind)
	local want = owner ~= nil and owner.Parent == Players and enabled(kind) and level(owner, SKILL_OF[kind]) >= 1
	local current = if kind == "Body" then entry.Body else entry.Door
	if current and (not want or current.Owner ~= owner) then
		removeGuard(current)
		current = nil
	end
	if current == nil and want and owner then
		local guard = newGuard(kind, plot, owner)
		current = guard
		task.spawn(spawnAvatar, guard)
	elseif current and current.Phase == "Idle" and not current.Acting and current.Avatar then
		local avatar = current.Avatar :: Model
		local home = homeFor(current, avatar)
		local old = current.Home
		if home and (old == nil or (home.Position - old.Position).Magnitude > MOVED_EPSILON) then
			current.Home = home
			avatar:PivotTo(home) -- nouvel étage de la boutique : la porte a bougé
		end
	end
	if kind == "Body" then
		entry.Body = current
	else
		entry.Door = current
	end
end

local function sync()
	local seen: { [Model]: boolean } = {}
	for _, plot in PlotService.GetPlots() do
		seen[plot] = true
		local owner = PlotService.GetOwner(plot)
		local entry: Entry = entries[plot] or { Body = nil, Door = nil }
		entries[plot] = entry
		syncKind(plot, owner, entry, "Body")
		syncKind(plot, owner, entry, "Door")
	end
	for plot, entry in entries do
		if not seen[plot] or plot.Parent == nil then
			if entry.Body then
				removeGuard(entry.Body)
			end
			if entry.Door then
				removeGuard(entry.Door)
			end
			entries[plot] = nil
		end
	end
end

local function step()
	local now = os.clock()
	for _, entry in entries do
		local body, door = entry.Body, entry.Door
		if body and not body.Removed then
			bodyStep(body, now)
		end
		if door and not door.Removed then
			doorStep(door, now)
		end
	end
end

------------------------------------------------------------------------------
-- API et démarrage
------------------------------------------------------------------------------

function ShopDefenseService.Sync()
	sync()
end

function ShopDefenseService.Step()
	step()
end

function ShopDefenseService.GetGuards(plot: Model): { [string]: { [string]: any } }
	local entry = entries[plot]
	local result: { [string]: { [string]: any } } = {}
	if entry and entry.Body then
		local body = entry.Body
		result.Body = { Phase = body.Phase, Target = body.Target, Avatar = body.Avatar }
	end
	if entry and entry.Door then
		local door = entry.Door
		result.Door = { Avatar = door.Avatar, LastPush = door.LastPush }
	end
	return result
end

function ShopDefenseService.Init()
	PvPService.OnTheftStarted(onTheftStarted)
	PlotService.OnPlotReleased(function(_player: Player, plot: Model)
		local entry = entries[plot]
		if entry then
			if entry.Body then
				removeGuard(entry.Body)
			end
			if entry.Door then
				removeGuard(entry.Door)
			end
			entries[plot] = nil
		end
	end)
	SkillTreeService.OnChanged(function(_player: Player, id: string, _level: number)
		if id == "Bodyguards" or id == "DoorGuard" then
			task.defer(sync)
		end
	end)
	log(
		`agents : Bodyguards {if Features.Bodyguards then "allumé" else "coupé"}, DoorGuard {if Features.DoorGuard
			then "allumé"
			else "coupé"}, radar des caméras {if Features.CameraRadar then "allumé" else "coupé"}`
	)
end

function ShopDefenseService.Start()
	while true do
		local dt = task.wait(ShopDefense.Tick)
		sinceSync += dt
		if sinceSync >= ShopDefense.SyncInterval then
			sinceSync = 0
			xpcall(sync, function(err: any)
				warn(`[ShopDefenseService] sync : {err}`)
			end)
		end
		xpcall(step, function(err: any)
			warn(`[ShopDefenseService] pas : {err}`)
		end)
	end
end

return ShopDefenseService
