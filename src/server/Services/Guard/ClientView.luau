--!strict
-- Guard/ClientView (serveur, a416 ; Cantin, 2026-11-23 : « le vigile attrape de hyper loin le joueur », « surtout dans les
-- zones rapides ») : module d'aide de GuardService (sous-dossier : le Loader ne le démarre pas). Valeurs, cause et règle
-- complète : Config/Chase.ClientView (interrupteur Enabled).
--
-- L'écran du joueur poursuivi montre son personnage à sa vraie place (il le simule) et le vigile là où le serveur
-- l'avait un « retard descendant » plus tôt. Le serveur, lui, a son vigile à sa vraie place et le personnage là où il
-- était un « retard montant » plus tôt. Retard = les deux (Lag). Avant, la capture se mesurait entre le vrai vigile et
-- la copie en retard : à l'écran, le vigile était encore à 3 studs + vitesse × retard. Ce module donne à GuardService :
--   Active(targetRoot) -> boolean
--       Ce voleur suit-il la règle ? Interrupteur allumé, et les vigiles le traversent (groupe « Guards » sans collision
--       avec le groupe de son HumanoidRootPart). Pose une fois les groupes ; un personnage encore en « Default » passe
--       en « Players » (au plus un essai par GHOST_RETRY s). false : la règle d'avant (a193), il n'est jamais inoffensif.
--   Lag(player) -> number
--       Retard compensé (s) : BaseSeconds + GetNetworkPing × Chase.LagPingFactor, au plus MaxSeconds.
--   Estimate(player, targetRoot, targetHumanoid, params) -> Vector3
--       Où ce joueur sera sur son écran quand la place actuelle du vigile s'y affichera : position reçue + vitesse au sol
--       (bornée à sa WalkSpeed, donnée par le serveur) × retard, arrêtée WallMargin studs avant un mur.
--   Seen(guardRoot, player, now) -> Vector3
--       Relève la place du vigile (à chaque pas de poursuite) et rend celle d'il y a Lag(player) s : là où ce joueur
--       voyait le vigile quand il était à la position que le serveur reçoit maintenant. La capture se mesure entre les deux.
--   Imminent(guardRoot, player, targetRoot, targetHumanoid, targetAt, now, reach, params) -> boolean
--       La capture aura-t-elle lieu dans DisplaySeconds s si le voleur continue tout droit (même mesure, avancée
--       d'autant, même portée et même test de mur) ? Alors le vigile s'arrête net tout de suite (son élan est coupé ici,
--       GuardService arrête sa marche) : le joueur le verra s'arrêter au moment où il est immobilisé, au lieu de le
--       dépasser pendant que son arrêt arrive à l'écran. Voleur qui tourne entre-temps : le vigile repart. Seulement
--       s'il est déjà à portée de la position estimée `targetAt` (un voleur qui s'arrête net est dépassé : il revient).
--   Caught(guardRoot, targetRoot, now) ; Settle(guardRoot, now) -> (Vector3?, number?)
--       Après la capture, pendant SettleSeconds s : le joueur immobilisé glisse encore sur son élan. Settle rend le
--       point où le vigile doit aller (StandOff studs avant le joueur, de son côté, jamais à travers lui) et sa
--       vitesse (SettleSpeed), ou nil s'il est déjà assez près ou que c'est fini ; GuardService le déplace.
--   StandOff(guardRoot, targetRoot, aim, targetAt) -> Vector3
--       Le vigile allait droit sur le voleur (à l'arrêt, ou rejoint) : il vise StandOff studs avant lui ; arrivé, il
--       reste là, et sur un voleur à l'arrêt son élan est coupé (il ne bute plus sur le joueur, il le traverserait).
--   GetState() -> { Ready: boolean, Ghosted: number }   pour les bancs
-- Rien ne vient du client : positions et vitesses répliquées par Roblox, ping mesuré par Roblox, relevé tenu ici.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chase = require(Shared:WaitForChild("Config"):WaitForChild("Chase")) :: any
local CatchReach = require(Shared:WaitForChild("CatchReach"))

-- Mêmes noms que GUARD_GROUP (GuardService), PLAYERS_GROUP (PlayerCollisionService) et PASS_GROUP (NightCycleService) :
-- les changer dans tous ces fichiers.
local GUARD_GROUP = "Guards"
local PLAYERS_GROUP = "Players"
local NIGHT_PASS_GROUP = "NightPass"
local DEFAULT_GROUP = "Default"

local PASS_CHECK = 0.2 -- le test « les vigiles le traversent » est gardé ce temps par personnage (s)
local GHOST_RETRY = 1 -- au plus un passage en « Players » par personnage dans ce temps (s)
local TRAIL_GAP = 0.5 -- trou du relevé au-delà duquel le vigile compte pour immobile avant (départ de poursuite) (s)
local TRAIL_MARGIN = 0.25 -- relevé gardé ce temps au-delà de MaxSeconds (s)
local SETTLE_SLACK = 0.5 -- après la capture, il ne bouge plus à moins de StandOff + ceci du joueur (studs)

local ClientView = {}

type Sample = { at: number, position: Vector3 }
type Pass = { at: number, value: boolean, ghostAt: number }
type Settling = { root: BasePart, endsAt: number }

local trails: { [BasePart]: { Sample } } = setmetatable({}, { __mode = "k" }) :: any
local passes: { [BasePart]: Pass } = setmetatable({}, { __mode = "k" }) :: any
local settles: { [BasePart]: Settling } = setmetatable({}, { __mode = "k" }) :: any
local halts: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- arrêtés avant la capture attendue
local groupsReady: boolean? = nil
local ghosted = 0

local function positive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Les groupes de collision, posés au premier besoin ; false s'ils sont indisponibles.
local function setup(): boolean
	if groupsReady == nil then
		local ok, err = pcall(function()
			local physics = game:GetService("PhysicsService")
			for _, name in { GUARD_GROUP, PLAYERS_GROUP, NIGHT_PASS_GROUP } do
				if not physics:IsCollisionGroupRegistered(name) then
					physics:RegisterCollisionGroup(name)
				end
			end
			physics:CollisionGroupSetCollidable(GUARD_GROUP, PLAYERS_GROUP, false)
			physics:CollisionGroupSetCollidable(GUARD_GROUP, NIGHT_PASS_GROUP, false)
		end)
		groupsReady = ok
		if not ok then
			warn(`[Guard/ClientView] groupes de collision indisponibles ({err}) : la capture garde la règle d'avant`)
		end
	end
	return groupsReady == true
end

-- Les vigiles traversent-ils ce personnage ? Lecture protégée : sans la méthode (faux Roblox des bancs plus anciens),
-- non, donc la règle d'avant.
local function passable(targetRoot: BasePart): boolean
	local ok, collide = pcall(function(): boolean
		return game:GetService("PhysicsService"):CollisionGroupsAreCollidable(GUARD_GROUP, targetRoot.CollisionGroup)
	end)
	return ok and collide == false
end

-- Les pièces du personnage encore en « Default » passent en « Players » (ce que fait PlayerCollisionService pour tous
-- les joueurs quand il est là ; « Players » touche le décor comme « Default »). true si une pièce a changé.
local function ghost(targetRoot: BasePart): boolean
	local character = targetRoot.Parent
	if character == nil then
		return false
	end
	local moved = false
	pcall(function()
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") and (descendant :: BasePart).CollisionGroup == DEFAULT_GROUP then
				(descendant :: BasePart).CollisionGroup = PLAYERS_GROUP
				moved = true
			end
		end
	end)
	if moved then
		ghosted += 1
	end
	return moved
end

-- Vitesse au sol reçue du voleur, bornée à la WalkSpeed que le serveur lui donne (une poussée ne compte pas).
local function groundVelocity(targetRoot: BasePart, targetHumanoid: Humanoid): Vector3
	local velocity = flat(targetRoot.AssemblyLinearVelocity)
	local speed = velocity.Magnitude
	local cap = targetHumanoid.WalkSpeed
	if not positive(speed) or not positive(cap) then
		return Vector3.zero
	end
	return if speed > cap then velocity * (cap / speed) else velocity
end

-- Place relevée du vigile à l'instant `at` (entre deux relevés : en ligne droite ; avant le premier : le premier).
local function placeAt(trail: { Sample }, at: number): Vector3
	local older = trail[1]
	if at <= older.at then
		return older.position
	end
	for index = 2, #trail do
		local newer = trail[index]
		if at <= newer.at then
			local span = newer.at - older.at
			return older.position + (newer.position - older.position) * (if span > 1e-6 then (at - older.at) / span else 1)
		end
		older = newer
	end
	return older.position
end

-- Son élan à l'horizontale est coupé : il s'arrête net (le Humanoid glisserait de plusieurs studs).
local function halt(guardRoot: BasePart)
	local velocity = guardRoot.AssemblyLinearVelocity
	guardRoot.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
end

function ClientView.Active(targetRoot: BasePart): boolean
	local cfg = Chase.ClientView
	if type(cfg) ~= "table" or cfg.Enabled ~= true or Chase.LagCompensation ~= true then
		return false
	end
	local now = os.clock()
	local pass = passes[targetRoot]
	if pass == nil then
		local fresh: Pass = { at = -math.huge, value = false, ghostAt = -math.huge }
		passes[targetRoot] = fresh
		pass = fresh
	end
	local current = pass :: Pass
	if now >= current.at and now - current.at < PASS_CHECK then
		return current.value
	end
	current.at = now
	current.value = false
	if setup() then
		current.value = passable(targetRoot)
		if not current.value and now - current.ghostAt >= GHOST_RETRY then
			current.ghostAt = now
			if ghost(targetRoot) then
				current.value = passable(targetRoot)
			end
		end
	end
	return current.value
end

function ClientView.Lag(player: Player): number
	local cfg = Chase.ClientView
	local base = if positive(cfg.BaseSeconds) then cfg.BaseSeconds else 0
	local ok, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	local network = if ok and positive(ping) and positive(Chase.LagPingFactor) then ping * Chase.LagPingFactor else 0
	return math.min(base + network, if positive(cfg.MaxSeconds) then cfg.MaxSeconds else math.huge)
end

function ClientView.Estimate(player: Player, targetRoot: BasePart, targetHumanoid: Humanoid, params: RaycastParams): Vector3
	local position = targetRoot.Position
	local lead = groundVelocity(targetRoot, targetHumanoid) * ClientView.Lag(player)
	local ahead = lead.Magnitude
	if ahead < 1e-3 then
		return position
	end
	-- Un mur sur le trajet : le joueur n'ira pas plus loin tout droit, l'avance s'arrête juste avant.
	local hit = Workspace:Raycast(position, lead, params)
	if hit then
		local margin = if positive(Chase.ClientView.WallMargin) then Chase.ClientView.WallMargin else 0
		local free = math.max(math.min(flat(hit.Position - position).Magnitude - margin, ahead), 0)
		return position + lead * (free / ahead)
	end
	return position + lead
end

function ClientView.Seen(guardRoot: BasePart, player: Player, now: number): Vector3
	local position = guardRoot.Position
	local trail = trails[guardRoot]
	if trail == nil then
		trail = {}
		trails[guardRoot] = trail
	end
	local keep = (if positive(Chase.ClientView.MaxSeconds) then Chase.ClientView.MaxSeconds else 0) + TRAIL_MARGIN
	local last = trail[#trail]
	if last == nil or now - last.at > TRAIL_GAP or now < last.at then
		-- Départ de poursuite (il attendait sur place, sans relevé) : il était déjà là.
		table.clear(trail)
		table.insert(trail, { at = now - keep, position = position })
	end
	table.insert(trail, { at = now, position = position })
	while #trail > 2 and trail[2].at <= now - keep do
		table.remove(trail, 1)
	end
	return placeAt(trail, now - ClientView.Lag(player))
end

function ClientView.Imminent(
	guardRoot: BasePart,
	player: Player,
	targetRoot: BasePart,
	targetHumanoid: Humanoid,
	targetAt: Vector3,
	now: number,
	reach: number,
	params: RaycastParams
): boolean
	local trail = trails[guardRoot]
	local lag = ClientView.Lag(player)
	local shown = Chase.ClientView.DisplaySeconds
	if trail == nil or #trail == 0 or not positive(shown) or lag <= 0 then
		return false
	end
	-- Jamais plus que la moitié du retard : le relevé lu reste celui d'avant son arrêt jusqu'à la capture.
	local ahead = math.min(shown, lag / 2)
	local seenSoon = placeAt(trail, now - (lag - ahead))
	local soon = targetRoot.Position + groundVelocity(targetRoot, targetHumanoid) * ahead
	if not CatchReach.InRange(seenSoon, soon, reach) or not CatchReach.CanTouch(seenSoon, targetRoot, params) then
		halts[guardRoot] = nil
		return false
	end
	if halts[guardRoot] ~= true then
		-- Il ne s'arrête que s'il est déjà à portée de la place où ce joueur sera immobilisé (`targetAt`, voleur qui court
		-- tout droit). Voleur qui vient de s'arrêter net : le vigile l'a dépassé, il revient d'abord vers lui.
		if not CatchReach.InRange(guardRoot.Position, targetAt, reach) then
			return false
		end
		halts[guardRoot] = true
	end
	halt(guardRoot)
	return true
end

function ClientView.Caught(guardRoot: BasePart, targetRoot: BasePart, now: number)
	local seconds = Chase.ClientView.SettleSeconds
	if positive(seconds) then
		local settling: Settling = { root = targetRoot, endsAt = now + seconds }
		settles[guardRoot] = settling
	else
		settles[guardRoot] = nil
	end
end

function ClientView.Settle(guardRoot: BasePart, now: number): (Vector3?, number?)
	local settling = settles[guardRoot]
	if settling == nil then
		return nil, nil
	end
	local cfg = Chase.ClientView
	if now >= settling.endsAt or settling.root.Parent == nil or not positive(cfg.StandOff) or not positive(cfg.SettleSpeed) then
		settles[guardRoot] = nil
		return nil, nil
	end
	local to = settling.root.Position
	local offset = flat(to - guardRoot.Position)
	if offset.Magnitude <= cfg.StandOff + SETTLE_SLACK then
		return nil, nil
	end
	return Vector3.new(to.X, guardRoot.Position.Y, to.Z) - offset.Unit * cfg.StandOff, cfg.SettleSpeed
end

function ClientView.StandOff(guardRoot: BasePart, targetRoot: BasePart, aim: Vector3, targetAt: Vector3): Vector3
	local cfg = Chase.ClientView
	if not ClientView.Active(targetRoot) then
		return aim
	end
	local keep = cfg.StandOff
	if not positive(keep) or flat(aim - targetAt).Magnitude > keep then
		return aim -- interrupteur coupé, ou il vise un point devant le voleur (interception, poteau contourné)
	end
	local from = guardRoot.Position
	local offset = flat(targetAt - from)
	if offset.Magnitude > keep then
		return Vector3.new(targetAt.X, aim.Y, targetAt.Z) - offset.Unit * keep
	end
	if flat(targetRoot.AssemblyLinearVelocity).Magnitude < (if positive(cfg.StillSpeed) then cfg.StillSpeed else 0) then
		halt(guardRoot)
	end
	return from
end

function ClientView.GetState(): { Ready: boolean, Ghosted: number }
	return { Ready = groupsReady == true, Ghosted = ghosted }
end

return ClientView
