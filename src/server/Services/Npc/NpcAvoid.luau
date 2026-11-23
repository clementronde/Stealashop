--!strict
-- Npc/NpcAvoid (serveur, a269 ; Cantin, 20/11 : « il faut que les PNJ dans les zones arrêtent de se rentrer dedans ») :
-- module d'aide de WitnessService et de GuardService (sous-dossier : le Loader ne le démarre pas). Valeurs :
-- Config/Witness.Avoid (interrupteur Enabled). Absent (faux arbres des bancs plus anciens) : la marche d'avant.
--
-- Avant : les deux témoins d'une zone (NPC_Witness_Z<n>_01 et _02) font le même circuit WitnessPaths, le second dans
-- l'autre sens. Ils se croisaient de face sur la même ligne et se percutaient (aucun évitement ; Witness.StuckTime 3 s
-- de blocage avant de viser le point suivant). Les deux vigiles de nuit d'une zone font la même ronde en aller-retour :
-- ils passaient l'un à travers l'autre (groupe de collision Guards, qui ne se heurte pas lui-même).
--
-- 1. Écart. Chaque PNJ suivi (Track : témoins, vigiles, policiers, conducteurs) est un obstacle pour les autres. Un PNJ
--    qui marche (Aim : témoin en balade ; vigile en ronde, en retour ou qui garde un objet tombé, jamais en poursuite)
--    regarde, avant chaque MoveTo, les PNJ suivis devant lui : à Avoid.Detect studs ou moins (à plat), à moins de
--    Avoid.Gap studs de sa ligne (vers son but), à Avoid.MaxRise studs ou moins en hauteur, et dont il se rapproche
--    (sa vitesse voulue moins celle de l'autre, le long de sa ligne, au moins Avoid.MinClosing studs/s ; un PNJ qui va
--    dans son sens aussi vite que lui n'est pas évité). Le plus proche : il s'écarte sur SA droite pour passer avec
--    l'autre à Gap studs sur sa gauche (décalage = écart latéral de l'autre + Gap, entre 0 et 2 × Gap, recalculé à
--    chaque pas dans son repère du moment : un virage du circuit ne le fait pas couper vers l'autre) ; il vise un point
--    Avoid.Look studs devant lui. Deux PNJ face à face s'écartent donc chacun de son côté et passent côte à côte, sans
--    s'arrêter ni faire demi-tour. Un PNJ arrêté (moins de Avoid.StillSpeed studs/s ; a269b) est évité avec le même
--    écart, du côté où il n'est pas, même s'il est déjà à côté (jusqu'à PassBehind studs derrière). L'écart finit
--    quand l'autre est Avoid.PassBehind studs derrière lui (ou parti, ou plus loin que Detect + 2 × Gap, ou qu'il ne
--    s'en rapproche plus) : il revise son but, et revient sur son circuit. Point visé derrière un mur (rayon à hauteur
--    du centre) : pas d'écart (le groupe de collision suffit). À moins de Detect studs de son but final (`final`) : pas
--    d'écart (il le rejoindrait mal ; ex. deux vigiles au même GuardSpawn).
--    a269b (Play fusion81 : témoins enfoncés dans des lampadaires à 2 studs du circuit) : chaque écart essayé est
--    balayé (sphère de Avoid.Clearance studs, à hauteur de la racine et Avoid.LowDrop studs plus bas) vers le point visé
--    et sur toute la bande entre sa ligne et l'écart, Look + Detect studs devant lui (l'aller et le retour). Bouché :
--    la moitié de l'écart, puis (PNJ arrêté) l'autre côté, puis tout droit (l'autre, s'il marche, s'écarte seul), puis
--    un peu à gauche tant que l'autre reste à Gap studs de côté ; sinon aucun écart. Filet : pendant un écart, sans
--    avancer de Avoid.StuckMove studs en Avoid.StuckTime s, il l'abandonne, vise son point et n'évite plus ce PNJ
--    pendant Avoid.RetryAfter s.
-- 2. Collision (Avoid.NoCollide). Les pièces des témoins passent dans le groupe Avoid.Group (seules celles du groupe
--    Default), qui ne heurte ni lui-même ni le groupe Guards des vigiles : deux PNJ ne se poussent jamais. Les joueurs
--    (Default) restent bloqués par eux comme avant. Rien n'est enregistré dans la place.
-- 3. Joueurs (a269b, Avoid.Players ; Play fusion81 : un joueur traversait de face un témoin qui marche, jamais un
--    témoin arrêté) : PlayerAhead dit si un joueur vient sur la ligne d'un témoin (PlayerStop studs devant, moins de
--    PlayerLane studs de côté) ; WitnessService arrête alors le témoin (arrêté, il bloque le joueur), et le témoin
--    repart quand la ligne est libre (ou vers son autre point, Witness.StuckTime).
--
-- API :
--   NpcAvoid.Track(root)                          ce PNJ est un obstacle pour les autres (sans effet s'il l'est déjà)
--   NpcAvoid.Untrack(root)                        il ne l'est plus (retiré ; pièce détruite : oublié tout seul)
--   NpcAvoid.Aim(root, goal, speed, final?) -> (Vector3, boolean)
--                                                 point à donner à MoveTo vers `goal` à `speed` studs/s ; true : il
--                                                 s'écarte (le redonner à chaque pas) ; false : `goal` tel quel
--   NpcAvoid.Clear(root)                          oublie son écart en cours (il ne marche plus)
--   NpcAvoid.PlayerAhead(root, goal, speed) -> boolean   un joueur vient sur sa ligne, tout près (a269b)
--   NpcAvoid.GuardAim(guard, position) -> Vector3 pour GuardService.moveTo (états Patrol, Return, Follow ; sinon suivi seul)
--   NpcAvoid.Collide(model)                       met les pièces d'un témoin dans le groupe Avoid.Group
--   NpcAvoid.GetState(root) -> { Avoiding: boolean, Tracked: number, Other: BasePart? }   pour un test

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Witness = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Witness")) :: any

local GUARD_GROUP = "Guards" -- le groupe de collision des vigiles (GuardService GUARD_GROUP)
local DEFAULT_GROUP = "Default"

type Walker = {
	root: BasePart,
	other: BasePart?, -- le PNJ qu'il évite ; nil : il n'évite personne
	side: number, -- a269b : 1, il passe l'autre à sa droite (l'autre à sa gauche) ; −1, à sa gauche ; 0 : pas encore choisi
	checkAt: number, -- a269b : heure (os.clock) et position du dernier contrôle d'avancée pendant l'écart
	checkX: number,
	checkZ: number,
	skip: BasePart?, -- a269b : PNJ qu'il n'évite plus jusqu'à skipUntil (écart abandonné)
	skipUntil: number,
}

local NpcAvoid = {}

local walkers: { [BasePart]: Walker } = {}
local groupsReady: boolean? = nil
-- a284 (audit a271 point 13) : paramètres des rayons partagés, refaits seulement quand la liste des PNJ suivis change
-- (Track d'un nouveau, Untrack) ou qu'un PNJ suivi n'avait pas encore de modèle au dernier calcul.
local ignoreDirty = true
local rayParams: RaycastParams? = nil -- blocked : rayon simple
local sweepParams: RaycastParams? = nil -- swept : RespectCanCollide

local function positive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

-- Les réglages, ou nil si l'écart est coupé ou incomplet.
local function settings(): any
	local cfg = Witness.Avoid
	if type(cfg) ~= "table" or cfg.Enabled ~= true then
		return nil
	end
	if not (positive(cfg.Detect) and positive(cfg.Gap) and positive(cfg.Look) and positive(cfg.MaxRise)) then
		return nil
	end
	return cfg
end

local function number(value: any, default: number): number
	return if type(value) == "number" and value == value then value else default
end

local function walkerOf(root: BasePart): Walker
	local found = walkers[root]
	if found then
		return found
	end
	local w: Walker = { root = root, other = nil, side = 0, checkAt = 0, checkX = 0, checkZ = 0, skip = nil, skipUntil = 0 }
	walkers[root] = w
	ignoreDirty = true
	return w
end

-- Dans le jeu (pas caché la nuit, pas détruit).
local function inGame(root: BasePart): boolean
	local ok, inside = pcall(function(): boolean
		return root:IsDescendantOf(Workspace)
	end)
	return ok and inside == true
end

-- Vitesse au sol (X, Z) d'une pièce ; 0, 0 si elle ne se lit pas.
local function velocityOf(root: BasePart): (number, number)
	local ok, x, z = pcall(function(): (number, number)
		local v = root.AssemblyLinearVelocity
		return v.X, v.Z
	end)
	if ok and type(x) == "number" and type(z) == "number" then
		return x, z
	end
	return 0, 0
end

-- a284 : les deux RaycastParams (Exclude, modèles des PNJ suivis), refaits si la liste a changé. À appeler dans un
-- pcall (sans RaycastParams, faux Roblox : erreur rattrapée par l'appelant, comme avant).
local function sharedParams(sweep: boolean): RaycastParams
	if ignoreDirty or rayParams == nil or sweepParams == nil then
		local ignore: { Instance } = {}
		local complete = true
		for root in walkers do
			local model = root.Parent
			if model then
				table.insert(ignore, model)
			else
				complete = false
			end
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = ignore
		local sweepRay = RaycastParams.new()
		sweepRay.FilterType = Enum.RaycastFilterType.Exclude
		sweepRay.FilterDescendantsInstances = ignore
		sweepRay.RespectCanCollide = true
		rayParams, sweepParams = ray, sweepRay
		ignoreDirty = not complete
	end
	return (if sweep then sweepParams else rayParams) :: RaycastParams
end

-- Un mur entre `from` et `to` ? Rayon qui ignore les PNJ suivis ; sans Raycast (faux Roblox) : non.
local function blocked(from: Vector3, to: Vector3): boolean
	local ok, hit = pcall(function(): boolean
		local params = sharedParams(false)
		local result = Workspace:Raycast(from, to - from, params)
		return result ~= nil and result.Instance.CanCollide
	end)
	return ok and hit == true
end

function NpcAvoid.Track(root: BasePart)
	walkerOf(root)
end

function NpcAvoid.Untrack(root: BasePart)
	if walkers[root] ~= nil then
		ignoreDirty = true
	end
	walkers[root] = nil
	for _, w in walkers do
		if w.other == root then
			w.other = nil
		end
	end
end

function NpcAvoid.Clear(root: BasePart)
	local w = walkers[root]
	if w then
		w.other = nil
	end
end

-- Repère de sa marche : position, direction (ux, uz) vers le but et sa droite (rx, rz).
type Frame = { px: number, py: number, pz: number, ux: number, uz: number, rx: number, rz: number, speed: number }

-- Écart de `other` vu de `f` : le long de sa ligne, sur sa droite, à plat, en hauteur, et vitesse de rapprochement.
local function relative(f: Frame, other: BasePart): (number, number, number, number, number)
	local p = other.Position
	local ox, oz = p.X - f.px, p.Z - f.pz
	local along = ox * f.ux + oz * f.uz
	local lateral = ox * f.rx + oz * f.rz
	local vx, vz = velocityOf(other)
	local closing = f.speed - (vx * f.ux + vz * f.uz)
	return along, lateral, math.sqrt(ox * ox + oz * oz), math.abs(p.Y - f.py), closing
end

local function prune()
	for root in walkers do
		if root.Parent == nil then
			NpcAvoid.Untrack(root)
		end
	end
end

-- a269b : un PNJ arrêté (plus lent que Avoid.StillSpeed) : un obstacle fixe, évité du côté où il n'est pas.
local function still(cfg: any, other: BasePart): boolean
	local vx, vz = velocityOf(other)
	local limit = number(cfg.StillSpeed, 0.5)
	return vx * vx + vz * vz < limit * limit
end

-- L'écart en cours tient-il encore ?
local function keeps(cfg: any, f: Frame, other: BasePart): boolean
	if walkers[other] == nil or not inGame(other) then
		return false
	end
	local along, _lateral, distance, rise, closing = relative(f, other)
	if along < -number(cfg.PassBehind, 1.5) or distance > cfg.Detect + 2 * cfg.Gap or rise > cfg.MaxRise then
		return false
	end
	return along <= 0 or closing >= number(cfg.MinClosing, 1)
end

-- Le plus proche PNJ à éviter : devant lui (ou à côté, jusqu'à PassBehind studs derrière : un virage du circuit le met
-- à côté), à moins de Gap studs de sa ligne, dont il se rapproche ; nil s'il n'y en a pas.
local function conflict(cfg: any, f: Frame, w: Walker, now: number): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	local minClosing = number(cfg.MinClosing, 1)
	local behind = -number(cfg.PassBehind, 1.5)
	for other in walkers do
		if other == w.root or not inGame(other) or (other == w.skip and now < w.skipUntil) then
			continue
		end
		local along, lateral, distance, rise, closing = relative(f, other)
		if along > behind and distance < bestDistance and distance <= cfg.Detect and math.abs(lateral) < cfg.Gap
			and rise <= cfg.MaxRise and closing >= minClosing
		then
			best = other
			bestDistance = distance
		end
	end
	return best
end

-- a269b : une sphère de `radius` studs balayée de `from` à `to` touche-t-elle une pièce qui heurte (poteau, borne) ?
-- PNJ suivis ignorés ; sans Spherecast (faux Roblox des bancs plus anciens) : non.
local function swept(from: Vector3, to: Vector3, radius: number): boolean
	local ok, hit = pcall(function(): boolean
		local direction = to - from
		if direction.Magnitude < 1e-3 then
			return false
		end
		local params = sharedParams(true)
		local result = Workspace:Spherecast(from, radius, direction, params)
		return result ~= nil and result.Instance.CanCollide
	end)
	return ok and hit == true
end

-- a269b : la place est-elle libre pour son corps s'il s'écarte de `shift` studs sur sa droite (négatif : sa gauche) ?
-- Balayages de Clearance studs de rayon, à hauteur de sa racine et LowDrop studs plus bas : jusqu'au point visé (Look
-- studs devant, décalé de shift), puis toute la bande entre sa ligne et l'écart (à shift / 2 et à shift) sur `reach`
-- studs devant lui, là où il marche jusqu'à son retour sur sa ligne une fois l'autre croisé (un poteau dans la bande
-- l'arrêterait à l'aller ou au retour).
local function room(cfg: any, f: Frame, shift: number, reach: number): boolean
	local radius = number(cfg.Clearance, 0)
	if radius <= 0 then
		return true
	end
	local look = cfg.Look
	local far = math.max(reach, look)
	local bands: { number } = if math.abs(shift) < 1e-3 then { 0 } else { 0.5, 1 }
	for _, drop in { 0, number(cfg.LowDrop, 0) } do
		local y = f.py - drop
		local from = Vector3.new(f.px, y, f.pz)
		local aim = Vector3.new(f.px + f.ux * look + f.rx * shift, y, f.pz + f.uz * look + f.rz * shift)
		if swept(from, aim, radius) then
			return false
		end
		for _, k in bands do
			local sx, sz = f.px + f.rx * shift * k, f.pz + f.rz * shift * k
			if swept(Vector3.new(sx, y, sz), Vector3.new(sx + f.ux * far, y, sz + f.uz * far), radius) then
				return false
			end
		end
	end
	return true
end

function NpcAvoid.Aim(root: BasePart, goal: Vector3, speed: number, final: Vector3?): (Vector3, boolean)
	local w = walkerOf(root)
	local cfg = settings()
	if cfg == nil then
		w.other = nil
		return goal, false
	end
	prune()
	local position = root.Position
	local dx, dz = goal.X - position.X, goal.Z - position.Z
	local length = math.sqrt(dx * dx + dz * dz)
	local nearFinal = false
	if final then
		local fx, fz = final.X - position.X, final.Z - position.Z
		nearFinal = math.sqrt(fx * fx + fz * fz) < cfg.Detect
	end
	if length < 1 or nearFinal then
		w.other = nil
		return goal, false
	end
	local ux, uz = dx / length, dz / length
	local f: Frame = {
		px = position.X,
		py = position.Y,
		pz = position.Z,
		ux = ux,
		uz = uz,
		rx = -uz, -- sa droite (Y en haut) : (−uz, ux)
		rz = ux,
		speed = math.max(number(speed, 0), 0),
	}
	local now = os.clock()
	local other = w.other
	if other and not keeps(cfg, f, other) then
		w.other = nil
		other = nil
	end
	if other == nil then
		local found = conflict(cfg, f, w, now)
		if found == nil then
			return goal, false
		end
		other = found
		w.other = found
		w.side = 0
		w.checkAt, w.checkX, w.checkZ = now, f.px, f.pz
	end
	local avoided = other :: BasePart
	-- a269b : filet. Il n'avance plus pendant l'écart (un poteau, un joueur) : il l'abandonne et vise son point.
	local stuckTime = number(cfg.StuckTime, 0)
	if stuckTime > 0 and now - w.checkAt >= stuckTime then
		local mx, mz = f.px - w.checkX, f.pz - w.checkZ
		if mx * mx + mz * mz < number(cfg.StuckMove, 1) ^ 2 then
			w.other = nil
			w.skip = avoided
			w.skipUntil = now + number(cfg.RetryAfter, 2)
			return goal, false
		end
		w.checkAt, w.checkX, w.checkZ = now, f.px, f.pz
	end
	-- Recalculé à chaque pas dans son repère du moment (un virage du circuit ne le fait pas couper vers l'autre) : il
	-- veut l'autre de côté : à Gap studs s'il est arrêté, à 2 × Gap s'il marche (chacun en fait la moitié s'il s'écarte
	-- aussi). Côté choisi une fois par écart : un PNJ qui marche est passé à droite (les deux font pareil) ; un PNJ
	-- arrêté, du côté où il n'est pas.
	local _along, lateral = relative(f, avoided)
	local isStill = still(cfg, avoided)
	if w.side == 0 then
		w.side = if isStill and lateral > 0 then -1 else 1
	end
	local target = if isStill then cfg.Gap else 2 * cfg.Gap
	local want = math.clamp(w.side * lateral + target, 0, 2 * cfg.Gap) -- vers son côté, au plus 2 × Gap
	-- Place libre (poteau, borne) balayée pour chaque essai, dans l'ordre : l'écart entier, la moitié ; un PNJ arrêté :
	-- l'autre côté ; puis tout droit (un PNJ qui marche s'écarte de lui-même ; un PNJ arrêté : s'il est à Gap studs de
	-- côté), puis un peu de l'autre côté (Gap / 2, Gap) tant que l'autre reste à Gap studs de côté (un poteau sur sa
	-- droite : il passe entre le poteau et l'autre). La place se juge jusqu'à son retour sur sa ligne, Look + Detect studs
	-- devant lui. Aucun essai libre : pas d'écart (le groupe de collision suffit entre témoins ; le filet le débloque).
	local shifts = { w.side * want, w.side * want / 2 }
	if isStill then
		table.insert(shifts, -w.side * math.clamp(-w.side * lateral + target, 0, 2 * cfg.Gap))
	end
	local primary = #shifts
	local reach = math.min(cfg.Look + cfg.Detect, length)
	for _, s in { 0, -w.side * cfg.Gap / 2, -w.side * cfg.Gap } do
		table.insert(shifts, s)
	end
	for i, shift in shifts do
		if i > primary and (isStill or math.abs(shift) >= 1e-3) and math.abs(lateral - shift) < cfg.Gap then
			continue
		end
		local x = f.px + ux * cfg.Look + f.rx * shift
		local z = f.pz + uz * cfg.Look + f.rz * shift
		if room(cfg, f, shift, reach) and not blocked(position, Vector3.new(x, position.Y, z)) then
			if i <= primary and math.abs(shift) >= 1e-3 then
				w.side = if shift > 0 then 1 else -1
			end
			return Vector3.new(x, goal.Y, z), true
		end
	end
	return goal, false
end

-- a269b (Play fusion81 : un joueur traversait de face un témoin qui marche, jamais un témoin arrêté) : un joueur vient-il
-- sur sa ligne vers `goal`, à Avoid.PlayerStop studs devant lui ou moins, à moins de Avoid.PlayerLane studs de la ligne,
-- et s'en rapproche-t-il ? Le témoin s'arrête alors : arrêté, il le bloque.
function NpcAvoid.PlayerAhead(root: BasePart, goal: Vector3, speed: number): boolean
	local cfg = settings()
	if cfg == nil or cfg.Players ~= true then
		return false
	end
	local stop, lane = number(cfg.PlayerStop, 0), number(cfg.PlayerLane, 0)
	if stop <= 0 or lane <= 0 then
		return false
	end
	local position = root.Position
	local dx, dz = goal.X - position.X, goal.Z - position.Z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then
		return false
	end
	local f: Frame = {
		px = position.X,
		py = position.Y,
		pz = position.Z,
		ux = dx / length,
		uz = dz / length,
		rx = -dz / length,
		rz = dx / length,
		speed = math.max(number(speed, 0), 0),
	}
	local ok, found = pcall(function(): boolean
		for _, player in game:GetService("Players"):GetPlayers() do
			local character = player.Character
			local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if part and part:IsA("BasePart") then
				local along, lateral, _distance, rise, closing = relative(f, part :: BasePart)
				if along > 0 and along <= stop and math.abs(lateral) < lane and rise <= cfg.MaxRise
					and closing >= number(cfg.MinClosing, 1)
				then
					return true
				end
			end
		end
		return false
	end)
	return ok and found == true
end

-- GuardService.moveTo : écart en ronde (Patrol), en retour (Return) et en garde d'un objet tombé (Follow) ; jamais en
-- poursuite ni pendant Catch, Tired, Wait ou Fade (il reste suivi : un obstacle pour les témoins et les autres vigiles).
function NpcAvoid.GuardAim(guard: any, position: Vector3): Vector3
	local root = guard.root :: BasePart?
	if root == nil then
		return position
	end
	NpcAvoid.Track(root)
	local cfg = settings()
	local state = guard.state
	if cfg == nil or cfg.Guards ~= true or not (state == "Patrol" or state == "Return" or state == "Follow") then
		NpcAvoid.Clear(root)
		return position
	end
	local final: any = nil
	if state == "Patrol" then
		final = if type(guard.patrol) == "table" then guard.patrol[guard.patrolIndex] else nil
	elseif state == "Follow" then
		final = guard.followPosition
	elseif guard.store ~= nil then
		final = guard.returnGoal
	else
		final = guard.home
	end
	local humanoid = guard.humanoid
	local speed = number(if humanoid then humanoid.WalkSpeed else nil, 0)
	local aim = NpcAvoid.Aim(root, position, speed, final)
	return aim
end

-- Les groupes de collision, enregistrés au premier besoin ; false s'ils sont indisponibles.
local function groups(group: string): boolean
	if groupsReady == nil then
		local ok = pcall(function()
			local physics = game:GetService("PhysicsService")
			for _, name in { group, GUARD_GROUP } do
				if not physics:IsCollisionGroupRegistered(name) then
					physics:RegisterCollisionGroup(name)
				end
			end
			physics:CollisionGroupSetCollidable(group, group, false)
			physics:CollisionGroupSetCollidable(group, GUARD_GROUP, false)
		end)
		groupsReady = ok
		if not ok then
			warn(`[NpcAvoid] groupe de collision {group} indisponible : les témoins peuvent se pousser entre eux`)
		end
	end
	return groupsReady == true
end

function NpcAvoid.Collide(model: Model)
	local cfg = Witness.Avoid
	if type(cfg) ~= "table" or cfg.Enabled ~= true or cfg.NoCollide ~= true or type(cfg.Group) ~= "string" then
		return
	end
	local group = cfg.Group :: string
	if not groups(group) then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			pcall(function()
				local part = descendant :: BasePart
				if part.CollisionGroup == DEFAULT_GROUP then
					part.CollisionGroup = group
				end
			end)
		end
	end
end

function NpcAvoid.GetState(root: BasePart): { Avoiding: boolean, Tracked: number, Other: BasePart? }
	local count = 0
	for _ in walkers do
		count += 1
	end
	local w = walkers[root]
	return { Avoiding = w ~= nil and w.other ~= nil, Tracked = count, Other = if w then w.other else nil }
end

return NpcAvoid
