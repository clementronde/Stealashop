--!strict
-- NightCycleService (DEV-047) : cycle jour / nuit, une seule horloge pour tout le serveur
-- (Partie 1, section 5.12 ; tags NightWall et NightPatrol : 2.1 et 10.4 ; valeurs : Config/Night ;
-- interrupteur : Config/Features.NightCycle).
--
-- Phases, dans l'ordre (durées de Config/Night) :
--   Day      DayDuration − WarningDuration (7 min 30 s) : magasins ouverts.
--   Warning  les WarningDuration (30) dernières secondes du jour : Notify Night.WarningText à tous ;
--            le HUD décompte (HudController), le ciel rougit (SkyController). Sirène : DEV-051.
--   Night    NightDuration (2 min). À la tombée de la nuit, dans cet ordre : les joueurs encore dans
--            le couloir reçoivent le passage (mur à sens unique, plus bas) ; le mur `NightWall` monte
--            depuis la position où il est livré (de sa hauteur, ou de son attribut RiseHeight) ;
--            nouveau tirage de tous les rayons (StoreHeistService.RefillAll, 5.12) ; vigiles de nuit
--            en ronde (GuardService.StartNightPatrol) ; Notify.
--   Aube     instantanée, de Night à Day : vigiles de nuit partis (GuardService.StopNightPatrol), mur
--            redescendu, passages retirés, toutes les vitrines cassées des magasins PNJ reconstruites
--            (WindowService.Rebuild) ; Notify.
-- Course en cours (5.12) : rien n'arrête un portage à la tombée de la nuit. Le porteur garde son
-- colis, son vigile de jour le poursuit toujours, et il reçoit le passage s'il est dans le couloir :
-- s'il atteint la zone safe, le colis est à lui. Son magasin a été rempli entre-temps : s'il échoue,
-- le colis ne revient pas sur le rayon (StoreHeistService : nouveau tirage, pas de doublon).
--
-- Mur à sens unique (5.12, « passage géré par le serveur ») : le mur et les joueurs qui ont le
-- passage sont dans deux groupes de collision qui ne se touchent pas (PhysicsService : WALL_GROUP
-- et PASS_GROUP). Le mur reste solide pour tous les autres : joueurs, vigiles, rayons de vue.
--   - Le mur coupe le monde en deux. Côté couloir = du côté opposé à la zone safe (tag SafeZone)
--     par rapport au plan du mur, son axe le plus mince (la rue est droite, section 4). Un seul mur
--     sert à ce calcul (contrat : 1), le premier par nom ; tous les murs taggés montent et descendent.
--   - Un joueur est « côté couloir » à plus de Night.WallSideMargin studs au-delà de la face du mur,
--     « côté safe » à plus de cette marge de l'autre côté, sinon « au mur ».
--   - À la tombée de la nuit, tout joueur qui n'est pas côté safe (couloir, ou au mur, là où le mur
--     va monter) est autorisé dans le couloir pour la nuit et reçoit le passage : il peut rentrer à
--     travers le mur.
--   - Pendant la nuit, 10 fois par seconde : un joueur autorisé qui passe côté safe perd le passage
--     et l'autorisation (il ne peut plus ressortir). Un joueur côté couloir sans autorisation (mur
--     contourné, sauté, glitch) est renvoyé chez lui (SendHome), avec un Notify : personne n'entre
--     la nuit. Un personnage qui réapparaît perd son passage (il réapparaît chez lui).
--   - Renvoyé chez lui la nuit (entré sans autorisation, ou attrapé par un vigile de nuit) : ce qu'il
--     porte est perdu juste avant (CarryService.Fail, raison « NightClosed » ; GuardService l'a déjà
--     fait, « Caught », pour un joueur attrapé), comme le dit 5.12 pour un joueur attrapé : le colis
--     retourne au magasin, l'objet volé à son présentoir. Sinon le renvoi le poserait chez lui avec
--     son colis, sans course (DEV-060).
--   - Les pièces ajoutées au personnage pendant la nuit (accessoires, colis porté) prennent le
--     passage ; à la fin, chaque pièce retrouve son groupe d'avant.
--   - Sans mur dans la map : avertissement, la nuit a lieu quand même ; « côté couloir » = hors des
--     volumes SafeZone, et seuls les renvois empêchent d'entrer.
--
-- Vigiles de nuit : GuardService (ronde, détection au cône de lampe torche, poursuite, capture).
-- Ce service lui donne les règles de la nuit : IsInCorridor (la cible est-elle encore dans le
-- couloir ?), les joueurs ignorés (bouclier débutant) et SendHome (attrapé : renvoyé chez lui).
--
-- Bouclier débutant (6.4 : 10 premières minutes de jeu cumulées, PvP.BeginnerShieldDuration) :
-- NightCycleService.IsShielded(player), point d'accroche que PvPService (DEV-044) pourra remplacer
-- (NightCycleService.IsShielded = function(player) ... end). Par défaut : temps des sessions passées
-- (profil, Lifetime.PlaySeconds, ajouté par DataService au départ du joueur) + temps depuis le
-- chargement du profil dans cette session ; profil pas encore chargé = protégé (choix V0). Les
-- vigiles de nuit ignorent les joueurs protégés si Night.IgnoreShieldedPlayers.
--
-- Posé par ce service, lu par les clients (aucun remote) :
--   attributs du Workspace : NightPhase ("Day", "Warning" ou "Night"), NightPhaseEndsAt (heure
--   serveur de la fin de la phase, workspace:GetServerTimeNow()) et NightFallsAt (heure serveur de
--   la prochaine tombée de la nuit ; pendant la nuit : celle du cycle suivant) ;
--   attribut du Player : NightPass (true tant qu'il a le passage, nil sinon), pour les tests.
--
-- API (serveur) :
--   NightCycleService.GetPhase() -> Phase                 "Day", "Warning" ou "Night"
--   NightCycleService.GetPhaseEndsAt() -> number          heure serveur de la fin de la phase
--   NightCycleService.IsNight() -> boolean
--   NightCycleService.OnPhaseChanged(listener) -> déconnexion
--       listener(phase, previous) après chaque changement (effets de la tombée de la nuit et de
--       l'aube déjà appliqués). Peut yield.
--   NightCycleService.IsInCorridor(position) -> boolean   pas côté safe (côté couloir ou au mur)
--   NightCycleService.IsShielded(player) -> boolean       point d'accroche, voir plus haut
--   NightCycleService.SendHome(player) -> boolean
--       Renvoie le joueur sur sa parcelle (PlotService.TeleportHome), sinon juste derrière le mur,
--       côté safe. Peut yield (2 s au plus). false s'il n'a pu aller nulle part.
--   NightCycleService.SkipTo(phase, duration?) -> boolean   STUDIO SEULEMENT (test)
--       Passe tout de suite à `phase` ("Day", "Warning", "Night", ou "Dawn" = "Day"), pour `duration`
--       secondes si elle est donnée (sinon la durée de Config). Applique les effets comme le vrai
--       cycle : quitter la nuit = aube, entrer dans la nuit = tombée de la nuit (même depuis la
--       nuit : nouvelle nuit complète). Hors de Studio : ne fait rien, avertit et renvoie false.
--   Même chose sans require, STUDIO SEULEMENT : la barre de commande serveur a son propre cache de
--   modules (un require y relancerait le service et Net, note a10). En Play, barre serveur :
--         workspace:SetAttribute("NightSkipTo", "Night 20")    -- ou "Warning 5", "Day", "Dawn"
--   Le service lit l'attribut, l'efface et appelle SkipTo. Hors de Studio, l'attribut n'est pas écouté.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Night = require(Shared.Config.Night)
local PvP = require(Shared.Config.PvP)
local Net = require(Shared.Net.Net)

local AntiCheatService = require(script.Parent.AntiCheatService)
local DataService = require(script.Parent.DataService)
local GuardService = require(script.Parent.GuardService)

-- Ce que ce service utilise de CarryService (DEV-017) : le portage perdu au renvoi.
type CarryApi = {
	IsCarrying: (player: Player) -> boolean,
	Fail: (player: Player, reason: string) -> boolean,
}
local CarryService: CarryApi = require(script.Parent.CarryService) :: any
local PlotService = require(script.Parent.PlotService)
local StoreHeistService = require(script.Parent.StoreHeistService)
local WindowService = require(script.Parent.WindowService)

export type Phase = Night.Phase
export type PhaseListener = (phase: Phase, previous: Phase) -> ()

-- Où est un joueur par rapport au mur (voir l'en-tête).
type Side = "Safe" | "Wall" | "Corridor"

type Wall = {
	Instance: PVInstance,
	Lowered: CFrame, -- pivot livré : état jour
	Raised: CFrame, -- état nuit
	Center: Vector3, -- centre de la boîte englobante, état livré
	Normal: Vector3, -- horizontal, unitaire, du côté safe vers le côté couloir
	Lateral: Vector3, -- horizontal, unitaire, le long du mur
	HalfThickness: number,
	HalfWidth: number,
	Raising: boolean,
	Stop: (() -> ())?,
}

type Pass = {
	Character: Model,
	Saved: { [BasePart]: string }, -- groupe de collision d'avant, par pièce
	Connection: RBXScriptConnection?,
}

-- Noms du contrat (2.1) lus ici.
local WALL_TAG = "NightWall"
local SAFE_ZONE_TAG = "SafeZone"
local PLOT_TAG = "PlayerPlot"
local STORE_TAG = "NPCStore"
local BOUNDS = "Bounds"
local INBOX_NAME = "_INBOX_CLEMENT"
local SANDBOX_NAME = "_SANDBOX_IRONIX"

-- V0 proposé, absent du doc et du contrat : attribut facultatif du mur, hauteur de sa montée
-- (studs). Sans lui : la hauteur de sa boîte englobante (livré baissé, le haut au ras du sol).
local RISE_HEIGHT_ATTRIBUTE = "RiseHeight"

-- Posés par ce service (voir l'en-tête). Mêmes noms dans HudController et SkyController.
local PHASE_ATTRIBUTE = "NightPhase"
local ENDS_AT_ATTRIBUTE = "NightPhaseEndsAt"
local FALLS_AT_ATTRIBUTE = "NightFallsAt"
local PASS_ATTRIBUTE = "NightPass"
local SKIP_ATTRIBUTE = "NightSkipTo" -- Studio seulement (test), voir l'en-tête
-- Groupes de collision créés par ce service.
local WALL_GROUP = "NightWall"
local PASS_GROUP = "NightPass"

-- V0 proposé, absent du doc : cadence des contrôles de la nuit (phase, passages, entrées).
local TICK = 0.1
-- V0 proposé, absent du doc : après StoreHeistService (110), qui enregistre les magasins à l'Init.
local PRIORITY = 120
-- V0 proposé, absent du doc : un joueur renvoyé derrière le mur (sans parcelle) est posé à
-- 2 studs de plus que la marge, côté safe ; sol cherché de 4 studs au-dessus à 12 en dessous.
local SAFE_SIDE_EXTRA = 2
local GROUND_RAY_UP = 4
local GROUND_RAY_DOWN = 12
local MOVE_LIFT = 0.1

-- Messages lus par le joueur (Notify), en anglais (L-036).
local MESSAGES = {
	NightfallCorridor = "Night guards are out: get back to the safe zone!",
	NightfallSafe = "Night has fallen: the corridor is closed.",
	Dawn = "Dawn: the corridor is open and the stores are full!",
	Closed = "The corridor is closed at night.",
}

local IS_STUDIO = RunService:IsStudio()
local ENABLED: boolean = Features.NightCycle

local NightCycleService = {}
NightCycleService.Priority = PRIORITY

local phase: Phase = "Day"
local phaseEndsAt = 0 -- os.clock() de la fin de la phase
local serverEndsAt = 0 -- même instant, en heure serveur
local walls: { Wall } = {}
local wallOf: { [Instance]: Wall } = {}
local mainWall: Wall? = nil -- le mur qui sert au calcul du côté
local allowed: { [Player]: boolean } = {} -- autorisés dans le couloir pour cette nuit
local passes: { [Player]: Pass } = {}
local sending: { [Player]: boolean } = {} -- renvoi en cours (SendHome attend)
local loadedAt: { [Player]: number } = {} -- os.time() du chargement du profil (bouclier débutant)
local listeners: { PhaseListener } = {}
local groupsReady = false
local started = false
local warned: { [string]: boolean } = {}

-- Outils ------------------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[NightCycleService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[NightCycleService] {message}`)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function notify(player: Player, message: string, kind: string)
	if player.Parent ~= Players then
		return
	end
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[NightCycleService] Notify vers {player.Name} : {err}`)
	end
end

-- Dans la map : Workspace, hors des dossiers de dépôt et de test (2.1).
local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	for _, name in { INBOX_NAME, SANDBOX_NAME } do
		local folder = Workspace:FindFirstChild(name)
		if folder and instance:IsDescendantOf(folder) then
			return false
		end
	end
	return true
end

-- HumanoidRootPart d'un joueur vivant, ou nil.
local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root :: BasePart, humanoid
end

-- Boîte orientée d'une pièce ou d'un modèle.
local function boxOf(object: PVInstance): (CFrame, Vector3)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	return (object :: Model):GetBoundingBox()
end

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Volume d'un objet taggé SafeZone : la pièce elle-même, sinon son enfant direct Bounds, sinon la
-- boîte englobante du modèle (même règle que GuardService).
local function safeVolume(instance: Instance): (CFrame?, Vector3?)
	local part: Instance? = if instance:IsA("BasePart") then instance else instance:FindFirstChild(BOUNDS)
	if part and part:IsA("BasePart") then
		return (part :: BasePart).CFrame, (part :: BasePart).Size
	end
	if instance:IsA("Model") then
		return (instance :: Model):GetBoundingBox()
	end
	return nil, nil
end

local function inSafeZone(position: Vector3): boolean
	for _, instance in CollectionService:GetTagged(SAFE_ZONE_TAG) do
		if inMap(instance) then
			local cframe, size = safeVolume(instance)
			if cframe and size and insideBox(cframe, size, position) then
				return true
			end
		end
	end
	return false
end

-- Un point de la zone safe : le centre de son volume, sinon le centre des parcelles.
local function safePoint(): Vector3?
	for _, instance in CollectionService:GetTagged(SAFE_ZONE_TAG) do
		if inMap(instance) then
			local cframe = safeVolume(instance)
			if cframe then
				return cframe.Position
			end
		end
	end
	local sum, count = Vector3.zero, 0
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("PVInstance") and inMap(plot) then
			sum += (plot :: PVInstance):GetPivot().Position
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

-- Hauteur du sol sous `position`, autour de `referenceY` ; personnages et pièces sans collision ignorés.
local function groundY(position: Vector3, referenceY: number): number
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(characters, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local origin = Vector3.new(position.X, referenceY + GROUND_RAY_UP, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_RAY_UP + GROUND_RAY_DOWN), 0), params)
	return if result then result.Position.Y else referenceY
end

-- Déplace `target` sur la trajectoire path(alpha), alpha de 0 à 1 en `duration` s, à chaque
-- Heartbeat (comme le rideau de StoreHeistService). Renvoie une fonction qui arrête le mouvement.
local function animate(target: PVInstance, path: (alpha: number) -> CFrame, duration: number): () -> ()
	local startedAt = os.clock()
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		if target.Parent == nil then
			stop()
			return
		end
		local alpha = if duration > 0 then math.min((os.clock() - startedAt) / duration, 1) else 1
		target:PivotTo(path(alpha))
		if alpha >= 1 then
			stop()
		end
	end)
	return stop
end

-- Mur ---------------------------------------------------------------------------------------------

local function setupGroups(): boolean
	local ok, err = pcall(function()
		for _, name in { WALL_GROUP, PASS_GROUP } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
		PhysicsService:CollisionGroupSetCollidable(WALL_GROUP, PASS_GROUP, false)
	end)
	if not ok then
		warn(`[NightCycleService] groupes de collision impossibles ({err}) : le mur bloquera aussi les joueurs du couloir`)
	end
	return ok
end

local function wallParts(instance: Instance): { BasePart }
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function pickMainWall()
	local best: Wall? = nil
	for _, wall in walls do
		if best == nil or wall.Instance:GetFullName() < best.Instance:GetFullName() then
			best = wall
		end
	end
	mainWall = best
end

local function registerWall(instance: Instance)
	if wallOf[instance] or not instance:IsA("PVInstance") or not inMap(instance) then
		return
	end
	local object = instance :: PVInstance
	local parts = wallParts(object)
	if #parts == 0 then
		warnOnce(`empty:{object:GetFullName()}`, `{object:GetFullName()} : mur de nuit sans pièce, ignoré`)
		return
	end
	local cframe, size = boxOf(object)
	-- L'axe horizontal le plus mince de la boîte est l'épaisseur du mur.
	local normal, halfThickness, halfWidth = flat(cframe.RightVector), size.X / 2, size.Z / 2
	if size.Z < size.X then
		normal, halfThickness, halfWidth = flat(cframe.LookVector), size.Z / 2, size.X / 2
	end
	normal = if normal.Magnitude > 1e-3 then normal.Unit else Vector3.xAxis
	local safe = safePoint()
	if safe == nil then
		warnOnce("nosafe", `aucune zone safe (tag {SAFE_ZONE_TAG}) ni parcelle : côté couloir du mur deviné (devant lui, −Z)`)
		local front = flat(cframe.LookVector)
		if front.Magnitude > 1e-3 and front.Unit:Dot(normal) < 0 then
			normal = -normal
		end
	elseif (safe - cframe.Position):Dot(normal) > 0 then
		normal = -normal -- la normale va du côté safe vers le couloir
	end
	local rise = object:GetAttribute(RISE_HEIGHT_ATTRIBUTE)
	local height = if type(rise) == "number" and rise > 0 and rise < math.huge then rise else size.Y
	local lowered = object:GetPivot()
	local wall: Wall = {
		Instance = object,
		Lowered = lowered,
		Raised = lowered + Vector3.new(0, height, 0),
		Center = cframe.Position,
		Normal = normal,
		Lateral = Vector3.yAxis:Cross(normal).Unit,
		HalfThickness = halfThickness,
		HalfWidth = halfWidth,
		Raising = false,
		Stop = nil,
	}
	if groupsReady then
		for _, part in parts do
			part.CollisionGroup = WALL_GROUP
		end
	end
	table.insert(walls, wall)
	wallOf[object] = wall
	pickMainWall()
	log(
		`mur {object:GetFullName()} : épaisseur {math.round(halfThickness * 20) / 10}, largeur {math.round(halfWidth * 20) / 10}, monte de {math.round(height * 10) / 10} studs la nuit`
	)
	if phase == "Night" then
		-- Arrivé en pleine nuit : il se lève tout de suite.
		wall.Raising = true
		object:PivotTo(wall.Raised)
	end
end

local function unregisterWall(instance: Instance)
	local wall = wallOf[instance]
	if wall == nil then
		return
	end
	wallOf[instance] = nil
	local stop = wall.Stop
	if stop then
		stop()
	end
	local index = table.find(walls, wall)
	if index then
		table.remove(walls, index)
	end
	pickMainWall()
end

-- Monte (`up`) ou descend tous les murs, depuis leur position du moment.
local function moveWalls(up: boolean)
	for _, wall in walls do
		if wall.Raising ~= up then
			wall.Raising = up
			local stop = wall.Stop
			if stop then
				stop()
			end
			local from = wall.Instance:GetPivot()
			local to = if up then wall.Raised else wall.Lowered
			local direction = if up then Enum.EasingDirection.Out else Enum.EasingDirection.In
			wall.Stop = animate(wall.Instance, function(alpha: number): CFrame
				return from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, direction))
			end, if up then Night.WallRiseTime else Night.WallLowerTime)
		end
	end
end

-- Où est `position` par rapport au mur (voir l'en-tête).
local function sideOf(position: Vector3): Side
	local wall = mainWall
	if wall == nil then
		return if inSafeZone(position) then "Safe" else "Corridor"
	end
	local distance = (position - wall.Center):Dot(wall.Normal)
	local limit = wall.HalfThickness + Night.WallSideMargin
	if distance > limit then
		return "Corridor"
	elseif distance < -limit then
		return "Safe"
	end
	return "Wall"
end

-- Passage -------------------------------------------------------------------------------------------

local function takePass(pass: Pass, instance: Instance)
	if instance:IsA("BasePart") and pass.Saved[instance] == nil then
		pass.Saved[instance] = instance.CollisionGroup
		instance.CollisionGroup = PASS_GROUP
	end
end

local function revokePass(player: Player)
	local pass = passes[player]
	if pass == nil then
		return
	end
	passes[player] = nil
	local connection = pass.Connection
	if connection then
		connection:Disconnect()
	end
	for part, group in pass.Saved do
		if part.Parent ~= nil and part.CollisionGroup == PASS_GROUP then
			part.CollisionGroup = group
		end
	end
	if player.Parent == Players then
		player:SetAttribute(PASS_ATTRIBUTE, nil)
	end
end

local function grantPass(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local current = passes[player]
	if current and current.Character == character then
		return
	end
	revokePass(player)
	local pass: Pass = { Character = character, Saved = {}, Connection = nil }
	for _, descendant in character:GetDescendants() do
		takePass(pass, descendant)
	end
	pass.Connection = character.DescendantAdded:Connect(function(descendant: Instance)
		takePass(pass, descendant)
	end)
	passes[player] = pass
	player:SetAttribute(PASS_ATTRIBUTE, true)
end

-- Renvois -------------------------------------------------------------------------------------------

-- Pose le joueur juste derrière le mur, côté safe, en face de l'endroit où il est.
local function moveToSafeSide(player: Player): boolean
	local root, humanoid = rootOf(player)
	local character = player.Character
	if root == nil or humanoid == nil or character == nil then
		return false
	end
	local wall = mainWall
	local spot: Vector3
	local facing: Vector3
	if wall then
		local along = math.clamp((root.Position - wall.Center):Dot(wall.Lateral), -wall.HalfWidth + 2, math.max(wall.HalfWidth - 2, -wall.HalfWidth + 2))
		local back = wall.HalfThickness + Night.WallSideMargin + SAFE_SIDE_EXTRA
		spot = wall.Center + wall.Lateral * along - wall.Normal * back
		facing = -wall.Normal
	else
		local safe = safePoint()
		if safe == nil then
			return false
		end
		spot = safe
		facing = Vector3.new(0, 0, -1)
	end
	-- R15 : HipHeight = du bas du HumanoidRootPart au sol ; R6 : jambes de 2 studs. Le sol est cherché
	-- autour de la hauteur des pieds du joueur (la rue est plate, section 4).
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local feet = root.Position.Y - hip - root.Size.Y / 2
	local ground = groundY(spot, feet)
	local position = Vector3.new(spot.X, ground + hip + root.Size.Y / 2 + MOVE_LIFT, spot.Z)
	AntiCheatService.Allow(player, 0, "NightCycleService (renvoi derrière le mur)") -- déplacement du code (DEV-060)
	character:PivotTo(CFrame.lookAt(position, position + facing) * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function sendHome(player: Player): boolean
	-- Le portage est perdu avant le renvoi (voir l'en-tête), jamais posé chez lui par le code.
	local carryOk, carryErr = pcall(function()
		if CarryService.IsCarrying(player) then
			CarryService.Fail(player, "NightClosed")
		end
	end)
	if not carryOk then
		warn(`[NightCycleService] CarryService.Fail({player.Name}, "NightClosed") : {carryErr}`)
	end
	local ok, moved = pcall(PlotService.TeleportHome, player, nil)
	if not ok then
		warn(`[NightCycleService] TeleportHome({player.Name}) : {moved}`)
	elseif moved then
		return true
	end
	return moveToSafeSide(player)
end

-- Entré dans le couloir la nuit sans y avoir été à la tombée de la nuit : renvoyé chez lui.
local function sendBack(player: Player)
	if sending[player] then
		return
	end
	sending[player] = true
	task.spawn(function()
		local moved = sendHome(player)
		sending[player] = nil
		if moved then
			notify(player, MESSAGES.Closed, "Warning")
		end
		log(`{player.Name} entré dans le couloir pendant la nuit : {if moved then "renvoyé chez lui" else "renvoi impossible"}`)
	end)
end

-- Bouclier débutant ---------------------------------------------------------------------------------

function NightCycleService.IsShielded(player: Player): boolean
	local data = DataService.Get(player)
	if data == nil then
		return true -- profil pas encore chargé : bénéfice du doute (V0)
	end
	local now = os.time()
	local played = data.Lifetime.PlaySeconds + math.max(0, now - (loadedAt[player] or now))
	return played < PvP.BeginnerShieldDuration
end

-- Ignoré par les vigiles de nuit (Night.IgnoreShieldedPlayers).
local function ignoredByGuards(player: Player): boolean
	if not Night.IgnoreShieldedPlayers then
		return false
	end
	local ok, shielded = pcall(NightCycleService.IsShielded, player)
	if not ok then
		warnOnce("shield", `IsShielded : {shielded} (joueur considéré comme protégé)`)
		return true
	end
	return shielded == true
end

-- Phases --------------------------------------------------------------------------------------------

local function lengthOf(target: Phase): number
	if target == "Day" then
		return math.max(Night.DayDuration - Night.WarningDuration, 0)
	elseif target == "Warning" then
		return math.max(math.min(Night.WarningDuration, Night.DayDuration), 0)
	end
	return math.max(Night.NightDuration, 0)
end

local function publish(nightFallsAt: number)
	Workspace:SetAttribute(PHASE_ATTRIBUTE, phase)
	Workspace:SetAttribute(ENDS_AT_ATTRIBUTE, serverEndsAt)
	Workspace:SetAttribute(FALLS_AT_ATTRIBUTE, nightFallsAt)
end

local function rebuildWindows(): number
	local count = 0
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		if inMap(store) then
			local windowId = WindowService.GetWindowId(store)
			if windowId and WindowService.IsBroken(windowId) then
				local ok, rebuilt = pcall(WindowService.Rebuild, windowId)
				if not ok then
					warn(`[NightCycleService] Rebuild({windowId}) : {rebuilt}`)
				elseif rebuilt then
					count += 1
				end
			end
		end
	end
	return count
end

local function onWarning()
	for _, player in Players:GetPlayers() do
		notify(player, Night.WarningText, "Alert")
	end
end

local function nightfall()
	table.clear(allowed)
	local inCorridor = 0
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and sideOf(root.Position) ~= "Safe" then
			allowed[player] = true
			grantPass(player)
			inCorridor += 1
		end
	end
	moveWalls(true)
	local ok, boxes = pcall(StoreHeistService.RefillAll)
	if not ok then
		warn(`[NightCycleService] RefillAll : {boxes}`)
	end
	local guardsOk, guards = pcall(GuardService.StartNightPatrol, {
		InCorridor = NightCycleService.IsInCorridor,
		Ignores = ignoredByGuards,
		SendHome = sendHome,
	})
	if not guardsOk then
		warn(`[NightCycleService] StartNightPatrol : {guards}`)
	end
	for _, player in Players:GetPlayers() do
		notify(player, if allowed[player] then MESSAGES.NightfallCorridor else MESSAGES.NightfallSafe, "Alert")
	end
	log(
		`la nuit tombe : mur levé, {inCorridor} joueur(s) dans le couloir avec le passage, {if ok then boxes else "?"} colis en rayon, {if guardsOk then guards else "?"} vigile(s) de nuit`
	)
end

local function dawn()
	local ok, err = pcall(GuardService.StopNightPatrol)
	if not ok then
		warn(`[NightCycleService] StopNightPatrol : {err}`)
	end
	moveWalls(false)
	for player in table.clone(passes) do
		revokePass(player)
	end
	table.clear(allowed)
	local rebuilt = rebuildWindows()
	for _, player in Players:GetPlayers() do
		notify(player, MESSAGES.Dawn, "Info")
	end
	log(`aube : mur baissé, {rebuilt} vitrine(s) reconstruite(s)`)
end

-- Quitte la phase en cours et entre dans `target` pour `duration` s (sinon la durée de Config).
local function enter(target: Phase, duration: number?)
	local previous: Phase = phase
	if previous == "Night" then
		dawn()
	end
	local length = duration or lengthOf(target)
	phase = target
	phaseEndsAt = os.clock() + length
	serverEndsAt = Workspace:GetServerTimeNow() + length
	local nightFallsAt = if target == "Day"
		then serverEndsAt + lengthOf("Warning")
		elseif target == "Warning" then serverEndsAt
		else serverEndsAt + lengthOf("Day") + lengthOf("Warning")
	publish(nightFallsAt)
	log(`phase {target} pour {math.round(length * 10) / 10} s`)
	if target == "Warning" then
		onWarning()
	elseif target == "Night" then
		nightfall()
	end
	for _, listener in table.clone(listeners) do
		task.spawn(function()
			listener(target, previous)
		end)
	end
end

-- Nuit raccourcie (liaison L-078, décision d'Ironix du 2026-11-08) : la nuit sert surtout aux
-- joueurs restés dans le couloir (finir un vol, rentrer). Dès qu'il n'y en a plus aucun (passage de
-- nuit : allowed, tenu à jour à chaque tick par guardCorridor, donc capture, renvoi chez soi, mort,
-- déconnexion, bouton Retour base ou retour à pied derrière le mur), il ne reste au plus que
-- Night.EmptyCorridorRemaining s. Le couloir ne se remplit plus de la nuit (mur à sens unique) : le
-- raccourci ne se défait jamais.
local function shortenIfCorridorEmpty()
	local limit = Night.EmptyCorridorRemaining
	if type(limit) ~= "number" or limit < 0 or next(allowed) ~= nil then
		return
	end
	local remaining = phaseEndsAt - os.clock()
	if remaining <= limit + 0.05 then
		return
	end
	phaseEndsAt = os.clock() + limit
	serverEndsAt = Workspace:GetServerTimeNow() + limit
	publish(serverEndsAt + lengthOf("Day") + lengthOf("Warning"))
	log(`plus personne dans le couloir : la nuit finit dans {limit} s (au lieu de {math.round(remaining)} s)`)
end

local function nextPhase(): Phase
	if phase == "Day" then
		return "Warning"
	elseif phase == "Warning" then
		return "Night"
	end
	return "Day"
end

-- La nuit : passages et entrées (voir l'en-tête).
local function guardCorridor()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local side = sideOf(root.Position)
			if side == "Safe" then
				allowed[player] = nil
				revokePass(player)
			elseif allowed[player] then
				grantPass(player) -- nouveau personnage, ou passage perdu
			elseif side == "Corridor" then
				sendBack(player)
			end
		end
	end
end

local function step()
	if os.clock() >= phaseEndsAt then
		enter(nextPhase())
	end
	if phase == "Night" then
		guardCorridor()
		shortenIfCorridorEmpty()
	end
end

-- API ---------------------------------------------------------------------------------------------

function NightCycleService.GetPhase(): Phase
	return phase
end

function NightCycleService.GetPhaseEndsAt(): number
	return serverEndsAt
end

function NightCycleService.IsNight(): boolean
	return phase == "Night"
end

function NightCycleService.OnPhaseChanged(listener: PhaseListener): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function NightCycleService.IsInCorridor(position: Vector3): boolean
	return sideOf(position) ~= "Safe"
end

function NightCycleService.SendHome(player: Player): boolean
	return sendHome(player)
end

function NightCycleService.SkipTo(target: string, duration: number?): boolean
	if not IS_STUDIO then
		warn("[NightCycleService] SkipTo est réservé aux tests dans Studio : ignoré")
		return false
	end
	if not ENABLED or not started then
		warn("[NightCycleService] SkipTo : cycle jour/nuit coupé (Features.NightCycle) ou pas encore démarré")
		return false
	end
	local phaseName: Phase
	if target == "Day" or target == "Dawn" then
		phaseName = "Day"
	elseif target == "Warning" then
		phaseName = "Warning"
	elseif target == "Night" then
		phaseName = "Night"
	else
		warn(`[NightCycleService] SkipTo : phase « {target} » inconnue (Day, Warning, Night, Dawn)`)
		return false
	end
	if duration ~= nil and not (type(duration) == "number" and duration >= 0 and duration < math.huge) then
		warn(`[NightCycleService] SkipTo : durée invalide ({duration})`)
		return false
	end
	enter(phaseName, duration)
	return true
end

function NightCycleService.Init()
	if not ENABLED then
		return
	end
	groupsReady = setupGroups()
	for _, instance in CollectionService:GetTagged(WALL_TAG) do
		registerWall(instance)
	end
	CollectionService:GetInstanceAddedSignal(WALL_TAG):Connect(registerWall)
	CollectionService:GetInstanceRemovedSignal(WALL_TAG):Connect(unregisterWall)
	if #walls == 0 then
		warn(`[NightCycleService] aucun mur de nuit (tag {WALL_TAG}) dans la map : la nuit ne fermera pas le couloir, seuls les renvois l'empêcheront`)
	end

	DataService.OnProfileLoaded(function(player: Player)
		loadedAt[player] = os.time()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		revokePass(player)
		allowed[player] = nil
		sending[player] = nil
		loadedAt[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			revokePass(player) -- le nouveau personnage réapparaît chez lui
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			revokePass(player)
		end)
	end

	-- Phase posée dès l'Init : un client qui arrive tôt la lit déjà.
	phase = "Day"
	local length = lengthOf("Day")
	phaseEndsAt = os.clock() + length
	serverEndsAt = Workspace:GetServerTimeNow() + length
	publish(serverEndsAt + lengthOf("Warning"))
end

function NightCycleService.Start()
	if not ENABLED then
		print("[NightCycleService] cycle jour/nuit coupé (Features.NightCycle = false) : jamais de nuit, rayons jamais remplis")
		return
	end
	started = true
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(SKIP_ATTRIBUTE):Connect(function()
			local value = Workspace:GetAttribute(SKIP_ATTRIBUTE)
			if type(value) ~= "string" or value == "" then
				return
			end
			Workspace:SetAttribute(SKIP_ATTRIBUTE, nil)
			local name, seconds = string.match(value, "^%s*(%a+)%s*([%d%.]*)%s*$")
			NightCycleService.SkipTo(name or value, if seconds and seconds ~= "" then tonumber(seconds) else nil)
		end)
	end
	print(
		`[NightCycleService] cycle jour/nuit : jour {lengthOf("Day")} s, alerte {lengthOf("Warning")} s, nuit {lengthOf("Night")} s ; {#walls} mur(s) de nuit`
	)
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[NightCycleService] tick : {err}\n{debug.traceback()}`)
		end)
	end
end

return NightCycleService
