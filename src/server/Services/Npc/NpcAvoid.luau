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
--    dans son sens aussi vite que lui n'est pas évité). Le plus proche : il s'écarte sur SA droite, d'une ligne parallèle
--    à sa ligne de départ, pour passer avec l'autre à Gap studs sur sa gauche (décalage = écart latéral de l'autre au
--    départ + Gap, entre 0 et 2 × Gap) ; il vise un point Avoid.Look studs devant lui sur cette ligne. Deux PNJ face à
--    face s'écartent donc chacun de son côté et passent côte à côte, sans s'arrêter ni faire demi-tour. L'écart finit
--    quand l'autre est Avoid.PassBehind studs derrière lui (ou parti, ou plus loin que Detect + 2 × Gap, ou qu'il ne
--    s'en rapproche plus) : il revise son but, et revient sur son circuit. Point visé derrière un mur (rayon à hauteur
--    du centre) : pas d'écart (le groupe de collision suffit). À moins de Detect studs de son but final (`final`) : pas
--    d'écart (il le rejoindrait mal ; ex. deux vigiles au même GuardSpawn).
-- 2. Collision (Avoid.NoCollide). Les pièces des témoins passent dans le groupe Avoid.Group (seules celles du groupe
--    Default), qui ne heurte ni lui-même ni le groupe Guards des vigiles : deux PNJ ne se poussent jamais. Les joueurs
--    (Default) restent bloqués par eux comme avant. Rien n'est enregistré dans la place.
--
-- API :
--   NpcAvoid.Track(root)                          ce PNJ est un obstacle pour les autres (sans effet s'il l'est déjà)
--   NpcAvoid.Untrack(root)                        il ne l'est plus (retiré ; pièce détruite : oublié tout seul)
--   NpcAvoid.Aim(root, goal, speed, final?) -> (Vector3, boolean)
--                                                 point à donner à MoveTo vers `goal` à `speed` studs/s ; true : il
--                                                 s'écarte (le redonner à chaque pas) ; false : `goal` tel quel
--   NpcAvoid.Clear(root)                          oublie son écart en cours (il ne marche plus)
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
	baseX: number, -- sa position au début de l'écart (la ligne de départ)
	baseZ: number,
	rightX: number, -- sa droite au début de l'écart (à plat, unitaire)
	rightZ: number,
	shift: number, -- décalage voulu à droite de la ligne de départ (studs)
}

local NpcAvoid = {}

local walkers: { [BasePart]: Walker } = {}
local groupsReady: boolean? = nil

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
	local w: Walker = { root = root, other = nil, baseX = 0, baseZ = 0, rightX = 0, rightZ = 0, shift = 0 }
	walkers[root] = w
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

-- Un mur entre `from` et `to` ? Rayon qui ignore les PNJ suivis ; sans Raycast (faux Roblox) : non.
local function blocked(from: Vector3, to: Vector3): boolean
	local ok, hit = pcall(function(): boolean
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = {}
		for root in walkers do
			local model = root.Parent
			if model then
				table.insert(ignore, model)
			end
		end
		params.FilterDescendantsInstances = ignore
		local result = Workspace:Raycast(from, to - from, params)
		return result ~= nil and result.Instance.CanCollide
	end)
	return ok and hit == true
end

function NpcAvoid.Track(root: BasePart)
	walkerOf(root)
end

function NpcAvoid.Untrack(root: BasePart)
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

-- Le plus proche PNJ devant lui à éviter, et son écart latéral ; nil s'il n'y en a pas.
local function conflict(cfg: any, f: Frame, root: BasePart): (BasePart?, number)
	local best: BasePart? = nil
	local bestAlong = math.huge
	local bestLateral = 0
	local minClosing = number(cfg.MinClosing, 1)
	for other in walkers do
		if other == root or not inGame(other) then
			continue
		end
		local along, lateral, distance, rise, closing = relative(f, other)
		if along > 0 and along < bestAlong and distance <= cfg.Detect and math.abs(lateral) < cfg.Gap
			and rise <= cfg.MaxRise and closing >= minClosing
		then
			best = other
			bestAlong = along
			bestLateral = lateral
		end
	end
	return best, bestLateral
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
	local other = w.other
	if other and not keeps(cfg, f, other) then
		w.other = nil
		other = nil
	end
	if other == nil then
		local found, lateral = conflict(cfg, f, root)
		if found == nil then
			return goal, false
		end
		w.other = found
		w.baseX, w.baseZ = f.px, f.pz
		w.rightX, w.rightZ = f.rx, f.rz
		w.shift = math.clamp(lateral + cfg.Gap, 0, 2 * cfg.Gap) -- toujours sur sa droite
	end
	-- Sur la ligne parallèle à sa ligne de départ, w.shift studs à droite, cfg.Look studs devant lui.
	local current = (f.px - w.baseX) * w.rightX + (f.pz - w.baseZ) * w.rightZ
	local correction = math.clamp(w.shift - current, -2 * cfg.Gap, 2 * cfg.Gap)
	local aim = Vector3.new(f.px + ux * cfg.Look + w.rightX * correction, goal.Y, f.pz + uz * cfg.Look + w.rightZ * correction)
	if blocked(position, Vector3.new(aim.X, position.Y, aim.Z)) then
		w.other = nil -- un mur de ce côté : pas d'écart (le groupe de collision suffit)
		return goal, false
	end
	return aim, true
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
