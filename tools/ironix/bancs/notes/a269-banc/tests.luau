-- Banc a269 (Cantin, 20/11 : « les PNJ dans les zones arrêtent de se rentrer dedans »), refait pour a269c (Play f81b,
-- 22/11 : voies fixes des témoins) et a269d (Play f81c : passages étroits, renfoncements, poteaux sans collision, bosses).
-- Harnais a100 (copie a151) : les Humanoid avancent à leur WalkSpeed ; ici, une boucle à part (run) note aussi leur
-- vitesse (AssemblyLinearVelocity) et pilote les faux vigiles par le vrai NpcAvoid.GuardAim (comme GuardService.moveTo),
-- toutes les 0,1 s. Faux Spherecast et GetPartBoundsInRadius : poteaux (cylindres), filtres Exclude et RespectCanCollide
-- suivis ; comme Roblox, le Spherecast ne voit pas ce que sa sphère touche au départ ; un corps (rayon 1) qui entrerait
-- dans un poteau qui heurte y reste coincé (un poteau sans collision se traverse, comme en jeu). Points du circuit au
-- sol (Y 0,65), racines des témoins à Y 3,2 (comme dans la place).
-- Partie « on » (Witness.Avoid.Enabled = true) :
--   L0 réglages V0 ; L1 deux témoins en sens inverse sur une boucle, pause à chaque point : toujours à 2,5 studs ou
--   plus, chacun sur SA voie (un volume invisible sans collision posé sur le circuit est ignoré) ; L2 voies corrigées
--   devant un lampadaire (StreetLamp_N4 de la zone 6, coordonnées du Play f81b), une borne à 0,85 stud d'un segment
--   (Bollard_4), une colonne sans collision (Column_4_Shaft), un mur collé au circuit (zone 9), une bosse autour d'un
--   poteau (zone 3) : aucun segment de voie qui touche un poteau ni qui revient en arrière, les témoins n'y entrent
--   jamais ; L3 un témoin poussé contre un poteau repart en 1,5 s ou moins et reprend le même point ; L4 Avoid.Players
--   coupé ; L5 passage étroit (zone 10) : un seul témoin dedans à la fois, l'autre attend à l'entrée ; L6 laisse :
--   jamais à plus de LaneMax + LaneLeash studs de sa voie, et un témoin posé loin revient au point le plus proche ; L8
--   filet : jamais un point dans un renfoncement ; A4 vigiles de nuit (écart dynamique gardé) ; A5 module ; A6 groupe
--   de collision Witnesses ; A7 aucune alerte. a269e (Play f81d) : comme en jeu, Humanoid.MoveTo s'arrête à 0,9 stud
--   de son but (STOP_SHORT) ; L7 arrivée et enchaînement des points sans arrêt ni pas de côté ; L9 point de voie dans
--   une colonne sans collision (aucun décalage libre) : déplacé hors de la colonne ; L10 passage étroit tenu par un
--   témoin bloqué dedans : l'autre attend au plus NarrowWait s en Idle puis passe, le bloqué change de point.
-- a269g (Play f81f) : ordonnanceur coopératif (task.spawn, task.defer, task.wait reprennent au pas suivant, avant
--   Heartbeat) ; L13 les voies ne se calculent ni dans Start ni dans Heartbeat, jamais plus de LaneStepQueries requêtes
--   sans rendre la main, les témoins attendent leurs voies sur place, un calcul coupé donne les mêmes voies ; L14 aucune
--   pause au hasard près de l'autre témoin (PauseClearance) ni au bout d'un passage étroit ; L15 aucun virage de voie de
--   plus de LaneTurnMax degrés, celui du coin de la zone 15 est lissé.
-- a269h (Play f81g) : L13a avant les voies de sa zone, le témoin marche sur le circuit, puis passe sur sa voie au point
--   suivant ; L15b zone 16 : une épingle qu'aucun point seul ne lisse est lissée en alignant deux points ; L16 rattrapage :
--   des témoins figés ensemble en marche redonnent leur MoveTo, une ligne dans la sortie.
-- Partie « off » (AVOID_OFF, Enabled = false) : O1 les deux témoins se superposent sur le circuit (comme avant a269) ;
-- O2 aucun groupe de collision ; O3 le témoin ne vise que des points du circuit (pas de voie) ; O4 (a269h) aucun rattrapage.

local vec = Vector3.new
if AVOID_OFF then
	local src, n = string.gsub(SOURCES["shared/Config/Witness.luau"], "(Avoid = {%s*Enabled = )true", "%1false")
	assert(n == 1, "Avoid.Enabled introuvable")
	SOURCES["shared/Config/Witness.luau"] = src
end
RNG_VALUE = 0.2 -- pause à chaque point du circuit (PauseChance 0,25), de 2,8 s
local Witness = requireShared("Shared.Config.Witness")
local AV = Witness.Avoid

-- Faux PhysicsService : note les groupes et les paires.
local PAIRS = {}
local REGISTERED = {}
SERVICES.PhysicsService = {
	IsCollisionGroupRegistered = function(_, name)
		return REGISTERED[name] == true
	end,
	RegisterCollisionGroup = function(_, name)
		REGISTERED[name] = true
	end,
	CollisionGroupSetCollidable = function(_, a, b, on)
		table.insert(PAIRS, { a = a, b = b, on = on })
	end,
}

local npcFolder = node("Folder", "Npc", Services)
local avoidScript = module("NpcAvoid", npcFolder, "server/Services/Npc/NpcAvoid.luau")
local lanesScript = module("WitnessLanes", npcFolder, "server/Services/Npc/WitnessLanes.luau")

if not AVOID_OFF then
	check("L0 réglages V0 : Lanes, Lane 1,5, LaneClearance 1,2, LaneLowDrop 0,8, LaneStep 0,25, LaneMax 4, LaneReach 0,5, UnstickTime 1, UnstickMove 1, UnstickSide 2,5, LaneVisibleMax 0,5, LaneLeash 2, NarrowWait 8, LaneOvershoot 1, LaneGoalSlack 4, NarrowHold 6, LaneDetourMax 8, NarrowStandOff 2, LaneStepQueries 1500, LaneStepBudget 0,01, LaneTurnMax 120, LaneCurbSlack 2, WalkRetry 2, WalkRetryMove 0,25, PauseClearance 10, Players coupé ; Guards, NoCollide, Witnesses",
		AV.Enabled == true and AV.Lanes == true and AV.Lane == 1.5 and AV.LaneClearance == 1.2 and AV.LaneLowDrop == 0.8
			and AV.LaneStep == 0.25 and AV.LaneMax == 4 and AV.LaneReach == 0.5 and AV.UnstickTime == 1 and AV.UnstickMove == 1
			and AV.UnstickSide == 2.5 and AV.LaneVisibleMax == 0.5 and AV.LaneLeash == 2 and AV.NarrowWait == 8
			and AV.LaneOvershoot == 1 and AV.LaneGoalSlack == 4 and AV.NarrowHold == 6 and AV.LaneDetourMax == 8 and AV.NarrowStandOff == 2
			and AV.LaneStepQueries == 1500 and AV.LaneStepBudget == 0.01 and AV.LaneTurnMax == 120 and AV.LaneCurbSlack == 2
			and AV.WalkRetry == 2 and AV.WalkRetryMove == 0.25
			and Witness.PauseClearance == 10
			and AV.Players == false and AV.Guards == true and AV.NoCollide == true and AV.Group == "Witnesses")
end

local GROUND, BODY_Y = 0.65, 3.2
local HEIGHT = BODY_Y - GROUND
local function g(x, z)
	return vec(x, GROUND, z)
end
local map = node("Folder", "Map", Workspace)
local function zone(n, points)
	local folder = node("Folder", "Zone_" .. n, map)
	local w = node("Folder", "Witnesses", folder)
	newPaths(folder, points)
	return w, folder
end
local function witness(name, parent, x, z)
	local m = newWitness(name, parent, vec(x, BODY_Y, z), nil)
	m.HumanoidRootPart.CollisionGroup = "Default"
	m.Head.CollisionGroup = "Default"
	m.Head.Kept = true
	return m
end

-- Poteaux : cylindres de rayon r, de y0 à y1. solid : CanCollide ; ghost : invisible (Transparency 1) et sans collision.
local BODY = 1
local POLES = {}
local function pole(model, name, x, z, r, y0, y1, solid, ghost)
	local p = node("Part", name, model)
	p.Position = vec(x, (y0 + y1) / 2, z)
	p.CanCollide = solid ~= false
	p.Transparency = if ghost then 1 else 0
	table.insert(POLES, { part = p, x = x, z = z, r = r, y0 = y0, y1 = y1, solid = solid ~= false, ghost = ghost == true })
	return p
end
local function segDist(px, pz, ax, az, bx, bz)
	local abx, abz = bx - ax, bz - az
	local l2 = abx * abx + abz * abz
	local t = if l2 > 1e-9 then math.clamp(((px - ax) * abx + (pz - az) * abz) / l2, 0, 1) else 0
	local dx, dz = px - ax - abx * t, pz - az - abz * t
	return math.sqrt(dx * dx + dz * dz), t
end
local function excluded(part, params)
	for _, inst in (params and params.FilterDescendantsInstances) or {} do
		if part == inst or part:IsDescendantOf(inst) then
			return true
		end
	end
	return false
end
local function skipped(p, params)
	return (params and params.RespectCanCollide and not p.part.CanCollide) or excluded(p.part, params)
end
SPHERECASTS = 0
QUERIES = 0 -- a269g : Spherecast et GetPartBoundsInRadius
QUERY_TIME = 0 -- a269h : ce que NOW avance à chaque requête (au démarrage seulement)
RaycastParams = { new = function()
	return {}
end }
OverlapParams = { new = function()
	return {}
end }
function Workspace.Spherecast(_, origin, radius, direction, params)
	SPHERECASTS += 1
	QUERIES += 1
	NOW += QUERY_TIME
	local best, bestT = nil, math.huge
	for _, p in POLES do
		if not skipped(p, params) and origin.Y + radius >= p.y0 and origin.Y - radius <= p.y1 then
			local d, t = segDist(p.x, p.z, origin.X, origin.Z, origin.X + direction.X, origin.Z + direction.Z)
			local ox, oz = origin.X - p.x, origin.Z - p.z
			local touching = math.sqrt(ox * ox + oz * oz) < radius + p.r -- comme Roblox : pas ce que la sphère touche au départ
			if d < radius + p.r and t < bestT and not touching then
				best, bestT = p, t
			end
		end
	end
	if best then
		return { Instance = best.part, Position = vec(best.x, origin.Y, best.z) }
	end
	return nil
end
function Workspace.GetPartBoundsInRadius(_, point, radius, params)
	QUERIES += 1
	NOW += QUERY_TIME
	local found = {}
	for _, p in POLES do
		if not skipped(p, params) and point.Y + radius >= p.y0 and point.Y - radius <= p.y1 then
			local dx, dz = point.X - p.x, point.Z - p.z
			if math.sqrt(dx * dx + dz * dz) < radius + p.r then
				table.insert(found, p.part)
			end
		end
	end
	return found
end
local function inPole(position)
	for _, p in POLES do
		if p.solid then
			local dx, dz = position.X - p.x, position.Z - p.z
			if math.sqrt(dx * dx + dz * dz) < BODY + p.r - 1e-9 and position.Y + BODY >= p.y0 and position.Y - 2.5 <= p.y1 then
				return true
			end
		end
	end
	return false
end
local function poleDist(position)
	local best = math.huge
	for _, p in POLES do
		if not p.ghost then
			local dx, dz = position.X - p.x, position.Z - p.z
			best = math.min(best, math.sqrt(dx * dx + dz * dz) - p.r)
		end
	end
	return best
end

-- Zone 1 : boucle de 14 points (rectangle 60 × 24, un point tous les 12 studs) ; 01 (sens +1) et 02 (sens −1) ; un
-- volume invisible sans collision (déclencheur) posé sur le circuit : ignoré.
local LOOP1 = { g(0, 0), g(12, 0), g(24, 0), g(36, 0), g(48, 0), g(60, 0), g(60, 12), g(60, 24), g(48, 24), g(36, 24),
	g(24, 24), g(12, 24), g(0, 24), g(0, 12) }
local z1, z1folder = zone(1, LOOP1)
pole(node("Model", "Trigger", z1folder), "Volume", 24, 0, 3, 0, 10, false, true)
local w1a = witness("NPC_Witness_Z1_01", z1, 0, 0)
local w1b = witness("NPC_Witness_Z1_02", z1, 60, 24)
-- Zone 6 : le coin du Play f81b (WitnessPath_12 à _15 et StreetLamp_N4, poteau et socle), refermé en boucle au sud.
local LOOP6 = { g(835, 48), g(847, 48), g(853, 51.2), g(855, 51.2), g(863, 48.5), g(875, 48.5), g(875, 20), g(835, 20) }
local z6, z6folder = zone(6, LOOP6)
local lamp = node("Model", "StreetLamp_N4", z6folder)
pole(lamp, "Pole", 854, 48.5, 0.5, 0, 14)
pole(lamp, "Base", 854, 48.5, 1, 0, 1.6)
local w6a = witness("NPC_Witness_Z6_01", z6, 835, 20)
local w6b = witness("NPC_Witness_Z6_02", z6, 875, 48.5)
-- Zone 7 : une borne (Bollard_4, rayon 0,6, 3 studs de haut) à 0,85 stud du segment 2→3, côté sud ; une colonne SANS
-- collision (Column_4_Shaft) à 0,85 stud du segment 4→5, côté de la voie du sens +1.
local LOOP7 = { g(760, -49.55), g(775, -49.55), g(792, -49.55), g(805, -49.55), g(805, -80), g(760, -80) }
local z7, z7folder = zone(7, LOOP7)
local facade = node("Model", "FacadeNY", z7folder)
pole(facade, "Bollard_4", 783.5, -50.4, 0.6, 0, 3.65)
pole(facade, "Column_4_Shaft", 805.85, -65, 0.6, 0, 14, false)
local w7a = witness("NPC_Witness_Z7_01", z7, 760, -80)
local w7b = witness("NPC_Witness_Z7_02", z7, 805, -49.55)
-- Zone 8 : un témoin seul sur une boucle, un poteau au milieu (loin de la voie) : on l'y pousse (L3).
local z8, z8folder = zone(8, { g(0, 1600), g(40, 1600), g(40, 1630), g(0, 1630) })
local w8 = witness("NPC_Witness_Z8_01", z8, 0, 1600)
pole(node("Model", "Pole_Test", z8folder), "Pole", 20, 1615, 0.5, 0, 14)
-- Zone 9 : un mur de façade collé au circuit (face à 1 stud des points 2 et 3, côté de la voie du sens +1).
local LOOP9 = { g(2000, 0), g(2010, 0), g(2020, 0), g(2030, 0), g(2030, -20), g(2000, -20) }
local z9, z9folder = zone(9, LOOP9)
local wall = node("Model", "Facade", z9folder)
for i = 0, 28 do
	pole(wall, "FrontWall_L", 2008 + i * 0.5, 1.5, 0.5, 0, 14)
end
local w9a = witness("NPC_Witness_Z9_01", z9, 2000, -20)
local w9b = witness("NPC_Witness_Z9_02", z9, 2030, 0)
-- Zone 3 : une bosse serrée du circuit autour d'un poteau (Pole_N360 du Play f81c).
local LOOP3 = { g(2400, 0), g(2410, 0), g(2412, 1.5), g(2414, 2.2), g(2416, 1.5), g(2418, 0), g(2430, 0), g(2430, -20),
	g(2400, -20) }
local z3, z3folder = zone(3, LOOP3)
pole(node("Model", "Pole_N360", z3folder), "Pole", 2414, 0, 0.5, 0, 14)
local w3a = witness("NPC_Witness_Z3_01", z3, 2400, -20)
local w3b = witness("NPC_Witness_Z3_02", z3, 2430, 0)
-- Zone 10 : passage étroit (un pilastre et un lampadaire à 2,4 studs de part et d'autre du point 3).
local LOOP10 = { g(3000, 0), g(3014, 0), g(3020, 0), g(3026, 0), g(3040, 0), g(3040, -16), g(3000, -16) }
local z10, z10folder = zone(10, LOOP10)
pole(node("Model", "Facade", z10folder), "Pilaster_R", 3020, 2.4, 0.5, 0, 14)
pole(node("Model", "Lamp_N4", z10folder), "Pole", 3020, -2.4, 0.5, 0, 14)
local w10a = witness("NPC_Witness_Z10_01", z10, 3014, 0) -- aux deux entrées du passage dès le départ
local w10b = witness("NPC_Witness_Z10_02", z10, 3026, 0)
-- Zone 13 (a269f, Play f81e) : le coin de la zone 6 où les points 3 et 4 du circuit (WitnessPath_13 et _14) tombent dans
-- Column_4_Shaft (rayon 1,5, collision), façade à 1,05 stud derrière, socle de StreetLamp_N4 à 1,05 stud devant : un
-- seul passage libre, côté rue, sous le lampadaire (décalé de 6165 studs en X).
local DX13 = 6165
local LOOP13 = { g(835 + DX13, 48), g(847 + DX13, 48), g(853 + DX13, 51.25), g(855 + DX13, 51.25), g(863 + DX13, 48.5),
	g(875 + DX13, 48.5), g(875 + DX13, 20), g(835 + DX13, 20) }
local z13, z13folder = zone(13, LOOP13)
local ny13 = node("Model", "FacadeNY", z13folder)
pole(ny13, "Column_4_Shaft", 852.5 + DX13, 51.45, 1.5, 0, 14)
local wall13 = node("Model", "Facade", z13folder)
for i = 0, 60 do
	pole(wall13, "FrontWall_R", 840 + DX13 + i * 0.5, 54.5, 0.5, 0, 14)
end
local lamp13 = node("Model", "StreetLamp_N4", z13folder)
pole(lamp13, "Pole", 854 + DX13, 48.45, 0.5, 0, 14)
pole(lamp13, "Base", 854 + DX13, 48.45, 0.8, 0, 1.6)
local w13a = witness("NPC_Witness_Z13_01", z13, 835 + DX13, 20)
local w13b = witness("NPC_Witness_Z13_02", z13, 875 + DX13, 48.5)
-- Zone 14 (a269f, Play f81e) : FacadeNY.Bollard_4 sur la voie du sens −1 (rue au nord, façade au sud) ; entre la borne
-- et la façade, la place d'une seule voie ; côté rue, StreetLamp_S3 près du point 3 (décalé de 7000 studs en X).
local DX14 = 7000
local LOOP14 = { g(805 + DX14, -51.75), g(790 + DX14, -51.75), g(785.8 + DX14, -51.75), g(775 + DX14, -51.75),
	g(760 + DX14, -51.75), g(760 + DX14, -20), g(805 + DX14, -20) }
local z14, z14folder = zone(14, LOOP14)
pole(node("Model", "FacadeNY", z14folder), "Bollard_4", 783.5 + DX14, -50.4, 0.6, 0, 3.65)
local wall14 = node("Model", "Facade", z14folder)
for i = 0, 70 do
	pole(wall14, "FrontWall_R", 765 + DX14 + i * 0.5, -55.15, 0.5, 0, 14)
end
pole(node("Model", "StreetLamp_S3", z14folder), "Pole", 787 + DX14, -48.6, 0.5, 0, 14)
pole(wall14, "Pilaster_R", 775 + DX14, -53.6, 0.5, 0, 14)
local w14a = witness("NPC_Witness_Z14_01", z14, 760 + DX14, -20)
local w14b = witness("NPC_Witness_Z14_02", z14, 805 + DX14, -51.75)
-- Hors circuit : un témoin dont le groupe de collision vient de Clément (jamais changé).
local wOwn = witness("NPC_Witness_Z5_01", zone(5, { g(0, 1200), g(60, 1200), g(60, 1220) }), 0, 1200)
wOwn.Head.CollisionGroup = "Clement"
-- Zone 11 (sans témoin) : poteaux du filet (L8).
local z11folder = select(2, zone(11, { g(5000, 100), g(5010, 100) }))
local recess = node("Model", "Facade", z11folder)
-- Joueurs (laneIgnore, PlayerAhead).
function Players.GetPlayers(self)
	local list = {}
	for _, c in self:GetChildren() do
		if c.ClassName == "Player" then
			table.insert(list, c)
		end
	end
	return list
end
local runner = newPlayer("Runner", vec(500, BODY_Y, 500))

local guardFolder = node("Folder", "ActiveGuards", Workspace)
local function guard(name, position, state, goal, speed, fields)
	local m = node("Model", name, guardFolder)
	local hum = node("Humanoid", "Humanoid", m)
	hum.Health = 100
	hum.WalkSpeed = speed
	local root = node("Part", "HumanoidRootPart", m)
	root.Position = position
	root.CFrame = CFrame.new(position)
	table.insert(HUMANOIDS, { humanoid = hum, root = root })
	local gd = { model = m, root = root, humanoid = hum, state = state, goal = goal, store = nil }
	for k, v in fields or {} do
		gd[k] = v
	end
	return gd
end
-- Zone 4 : deux vigiles de nuit en ronde face à face (patrol, patrolIndex : point visé).
local g4a = guard("NightGuard_Z4_1", vec(0, 3, 600), "Patrol", vec(60, 3, 600), 8, { patrol = { vec(0, 3, 600), vec(60, 3, 600) }, patrolIndex = 2 })
local g4b = guard("NightGuard_Z4_2", vec(60, 3, 600), "Patrol", vec(0, 3, 600), 8, { patrol = { vec(0, 3, 600), vec(60, 3, 600) }, patrolIndex = 1 })
local GUARDS = { g4a, g4b }

local function flatDist2(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
-- Zone 15 (a269g, Play f81f : épingle au coin de la zone 1) : un coin du circuit (il monte au nord par le passage piéton
-- puis tourne vers l'est sur le trottoir), un lampadaire et un pot contre les points 1 à 3 : avant a269g, la voie du
-- sens +1 y faisait un virage de 136° (sans témoin : voies seulement).
local LOOP15 = { g(9040, 48), g(9041.5, 48.3), g(9043, 48.3), g(9049, 48), g(9070, 48), g(9070, -48), g(9038, -48), g(9038, 34) }
local z15folder = select(2, zone(15, LOOP15))
pole(node("Model", "Lamp_N4", z15folder), "Pole", 9041, 49.9, 0.5, 0, 14)
pole(node("Model", "Decor", z15folder), "PotLeaves_1", 9044, 47.2, 1.3, 0, 2.5)
-- Zone 16 (a269h, Play f81g : « P2 retour virage de 162° : non lissé » au coin de la zone 1) : un coin trouvé par
-- recherche où a269g laisse « P2 retour virage de 158° : non lissé » (P1 et P2 retour poussés de 4 studs vers
-- l'intérieur par un poteau sur le circuit) : aucun point seul ne lisse le virage sans en créer un au voisin.
local LOOP16 = { g(10039, 48), g(10040.25, 47.5), g(10041.5, 47.5), g(10050, 47.25), g(10070, 47.25), g(10070, -48), g(10038, -48), g(10038, 34.6) }
local z16folder = select(2, zone(16, LOOP16))
pole(node("Model", "Obj1", z16folder), "Part", 10038.75, 48, 1, 0, 14)
pole(node("Model", "Obj2", z16folder), "Part", 10040.5, 49.75, 0.5, 0, 14)
pole(node("Model", "Obj3", z16folder), "Part", 10047.75, 45.25, 0.5, 0, 14)

-- a269g (Play f81f : « Script timeout » au démarrage du Loader) : ordonnanceur coopératif, comme en jeu. task.spawn
-- lance tout de suite ; un fil différé (task.defer) ou qui attend (task.wait) reprend au pas suivant, avant Heartbeat.
-- PUMP_ROUNDS : tours de reprise par pas (nil : jusqu'à ce que plus rien n'attende, comme plusieurs images par pas).
-- Chaque reprise note ses requêtes (une « tranche » de calcul sans rendre la main).
local READY = {}
local TASK_ERRORS = {}
local SLICES, SLICE_MAX = 0, 0
local PUMP_ROUNDS = nil
local function resumeTask(co, ...)
	local q0 = QUERIES
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(TASK_ERRORS, tostring(err))
	end
	local used = QUERIES - q0
	if used > 0 then
		SLICES += 1
		SLICE_MAX = math.max(SLICE_MAX, used)
	end
end
fakeTask.spawn = function(fn, ...)
	resumeTask(coroutine.create(fn), ...)
end
fakeTask.defer = function(fn, ...)
	table.insert(READY, { co = coroutine.create(fn), args = table.pack(...) })
end
fakeTask.wait = function()
	table.insert(READY, { co = coroutine.running(), args = table.pack() })
	coroutine.yield()
	return 0
end
local function pumpTasks()
	local rounds = 0
	while #READY > 0 and (PUMP_ROUNDS == nil or rounds < PUMP_ROUNDS) and rounds < 100000 do
		rounds += 1
		local batch = READY
		READY = {}
		for _, t in batch do
			resumeTask(t.co, table.unpack(t.args, 1, t.args.n))
		end
	end
end
-- a269g : chaque pause au hasard (Random:NextNumber(PauseMin, PauseMax), puis stopWalking : MoveTo sur sa position) :
-- qui, où, et à quelle distance de l'autre témoin de son circuit.
local PAUSE_PENDING = false
local PAUSES = {}
-- a269h : les mesures de la balade sur les voies (écarts, poteaux, laisse, passage étroit, pauses, buts) ne comptent
-- qu'une fois chaque témoin passé sur sa voie ; avant, il marche sur le circuit comme avant a269 (L13a le vérifie).
MEASURING = true
-- a269h : chaque MoveTo des témoins (pas du démarrage, but, position) ; HOOK_STEP : le pas en cours du démarrage.
local GOAL_LOG = {}
HOOK_STEP = 0
local PARTNER = {
	[w1a] = { w1b, 1, 1 }, [w1b] = { w1a, 1, -1 }, [w3a] = { w3b, 3, 1 }, [w3b] = { w3a, 3, -1 },
	[w6a] = { w6b, 6, 1 }, [w6b] = { w6a, 6, -1 }, [w7a] = { w7b, 7, 1 }, [w7b] = { w7a, 7, -1 },
	[w9a] = { w9b, 9, 1 }, [w9b] = { w9a, 9, -1 }, [w10a] = { w10b, 10, 1 }, [w10b] = { w10a, 10, -1 },
	[w13a] = { w13b, 13, 1 }, [w13b] = { w13a, 13, -1 }, [w14a] = { w14b, 14, 1 }, [w14b] = { w14a, 14, -1 },
}
do
	local baseNew = FakeRandom.new
	FakeRandom.new = function(...)
		local r = baseNew(...)
		local nextNumber = r.NextNumber
		r.NextNumber = function(self, a, b)
			if a ~= nil and a == Witness.PauseMin and b == Witness.PauseMax then
				PAUSE_PENDING = true
			end
			return nextNumber(self, a, b)
		end
		return r
	end
	for _, h in HUMANOIDS do
		local model = h.root.Parent
		if model and string.sub(model.Name, 1, 12) == "NPC_Witness_" then
			rawset(h.humanoid, "MoveTo", function(self, goal)
				if PAUSE_PENDING then
					PAUSE_PENDING = false
					local partner = PARTNER[model]
					table.insert(if MEASURING then PAUSES else {}, {
						model = model,
						position = h.root.Position,
						other = if partner then flatDist2(rootOf(partner[1]).Position, h.root.Position) else math.huge,
					})
				end
				self._goal = goal
				self._moves = (rawget(self, "_moves") or 0) + 1
				local list = GOAL_LOG[model]
				if list == nil then
					list = {}
					GOAL_LOG[model] = list
				end
				if #list < 4000 then
					table.insert(list, { step = HOOK_STEP, goal = goal, pos = h.root.Position })
				end
			end)
		end
	end
end
local QUERIES_BEFORE_START = QUERIES

local Service = loadWitness()
local START_QUERIES = QUERIES - QUERIES_BEFORE_START -- a269g : requêtes faites par Start (0 : aucun calcul de voies au démarrage)
local Avoid = requireModule(avoidScript)
local Lanes = requireModule(lanesScript)
local warnsAtStart = 0
for _, l in LOGS do
	if string.sub(l, 1, 4) == "WARN" and not string.find(l, "se balade seulement", 1, true) then
		warnsAtStart += 1
	end
end

-- Voies calculées directement (même module, mêmes réglages, même hauteur que le service).
local BUILT = {}
local function build(key, loop)
	local f, b, fixes, narrow = Lanes.Build(loop, HEIGHT, {})
	BUILT[key] = { loop = loop, f = f, b = b, fixes = fixes, narrow = narrow }
	return BUILT[key]
end
local L1, L3, L6, L7, L9, L10 = build(1, LOOP1), build(3, LOOP3), build(6, LOOP6), build(7, LOOP7), build(9, LOOP9), build(10, LOOP10)
local L13, L14, L15, L16 = build(13, LOOP13), build(14, LOOP14), build(15, LOOP15), build(16, LOOP16)

-- Mesures pendant la course.
local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
local function laneDist(lane, position)
	local best = math.huge
	for k = 1, #lane do
		local a, b = lane[k], lane[k % #lane + 1]
		best = math.min(best, (segDist(position.X, position.Z, a.X, a.Z, b.X, b.Z)))
	end
	return best
end
local PAIRS_WATCH = {
	{ key = "1", a = rootOf(w1a), b = rootOf(w1b) },
	{ key = "3", a = rootOf(w3a), b = rootOf(w3b) },
	{ key = "4", a = g4a.root, b = g4b.root },
	{ key = "6", a = rootOf(w6a), b = rootOf(w6b) },
	{ key = "7", a = rootOf(w7a), b = rootOf(w7b) },
	{ key = "9", a = rootOf(w9a), b = rootOf(w9b) },
	{ key = "10", a = rootOf(w10a), b = rootOf(w10b) },
	{ key = "13", a = rootOf(w13a), b = rootOf(w13b) },
	{ key = "14", a = rootOf(w14a), b = rootOf(w14b) },
}
local MIN, MEET, MEET_PAUSED = {}, {}, {}
local NEAR = {} -- la paire était à moins de 6 studs au pas d'avant (une rencontre de plus en y repassant)
local POLE_MIN = {}
local POLE_WATCH = { w6a = rootOf(w6a), w6b = rootOf(w6b), w7a = rootOf(w7a), w7b = rootOf(w7b), w8 = rootOf(w8),
	w9a = rootOf(w9a), w9b = rootOf(w9b), w3a = rootOf(w3a), w3b = rootOf(w3b), w10a = rootOf(w10a), w10b = rootOf(w10b),
	w13a = rootOf(w13a), w13b = rootOf(w13b), w14a = rootOf(w14a), w14b = rootOf(w14b) }
-- Laisse : distance de chaque témoin à sa voie (sens +1 : forward, −1 : backward).
local OWN_LANE = {
	[rootOf(w1a)] = L1.f, [rootOf(w1b)] = L1.b, [rootOf(w3a)] = L3.f, [rootOf(w3b)] = L3.b, [rootOf(w6a)] = L6.f,
	[rootOf(w6b)] = L6.b, [rootOf(w7a)] = L7.f, [rootOf(w7b)] = L7.b, [rootOf(w9a)] = L9.f, [rootOf(w9b)] = L9.b,
	[rootOf(w10a)] = L10.f, [rootOf(w10b)] = L10.b,
	[rootOf(w13a)] = L13.f, [rootOf(w13b)] = L13.b, [rootOf(w14a)] = L14.f, [rootOf(w14b)] = L14.b,
}
-- a269f : immobilité hors Idle (Walk joué, arrêté) et écart à sa voie des témoins des zones 13 et 14.
local STILL_WATCH = { w13a = w13a, w13b = w13b, w14a = w14a, w14b = w14b }
local STILL_FOR, STILL_MAX, LANE_BY = {}, {}, {}
local LANE_MAX = 0
local TRACK_LANE = true
-- Passage étroit de la zone 10 : dedans = près d'un segment étroit du circuit, loin de ses deux bouts.
local NARROW_SEGS, ENDS = {}, {}
do
	local count = #LOOP10
	local seen = {}
	for k in L10.narrow do
		table.insert(NARROW_SEGS, k)
		local k2 = k % count + 1
		seen[k] = (seen[k] or 0) + 1
		seen[k2] = (seen[k2] or 0) + 1
	end
	for k, n in seen do
		if n == 1 then
			table.insert(ENDS, LOOP10[k])
		end
	end
end
local function inside(position)
	local near = false
	for _, k in NARROW_SEGS do
		local a, b = LOOP10[k], LOOP10[k % #LOOP10 + 1]
		if segDist(position.X, position.Z, a.X, a.Z, b.X, b.Z) < 3 then
			near = true
		end
	end
	if not near then
		return false
	end
	for _, e in ENDS do
		if flatDist(e, position) < 3 then
			return false
		end
	end
	return true
end
local BOTH_INSIDE, WAITED, INSIDE_SEEN = 0, false, 0
local WAIT_CLEAR = math.huge -- a269f : écart de celui qui attend à la voie de celui qui passe
local GOALS = {} -- [racine] = { buts MoveTo vus }
local SIDE = {}
local AVOIDED = {}
local function watchSide(key, root, z0, dirX)
	-- Regard +X : sa droite = (−uz, ux) = (0, 1) en (X, Z), soit +Z ; regard −X : −Z (NpcAvoid).
	local right = (root.Position.Z - z0) * dirX
	SIDE[key] = math.max(SIDE[key] or -math.huge, right)
end
local SIDES = {
	{ key = "g4a", root = g4a.root, z0 = 600, dirX = 1 },
	{ key = "g4b", root = g4b.root, z0 = 600, dirX = -1 },
}
local nextGuardAt = 0
local STOP_SHORT = 0.9
local HB_MAX = 0 -- a269g : requêtes faites dans un même Heartbeat (au plus)
local FROZEN = {}
local function run(seconds)
	local dt = 0.05
	for _ = 1, math.floor(seconds / dt + 0.5) do
		NOW += dt
		if NOW >= nextGuardAt then
			nextGuardAt = NOW + 0.1 - 1e-9
			for _, gd in GUARDS do
				gd.humanoid._goal = Avoid.GuardAim(gd, gd.goal)
			end
		end
		for _, h in HUMANOIDS do
			local before = h.root.Position
			local goal = rawget(h.humanoid, "_goal")
			if goal then
				local set = GOALS[h.root]
				if not MEASURING then
					set = {} -- a269h : buts du circuit pendant le calcul des voies, hors mesure
				end
				if set == nil then
					set = {}
					GOALS[h.root] = set
				end
				if flatDist(goal, before) > 1e-3 then -- MoveTo(sa position) : un arrêt, pas un but
					set[goal] = true
				end
				local offset = vec(goal.X - before.X, 0, goal.Z - before.Z)
				local distance = offset.Magnitude
				-- a269e : comme en jeu (Play f81d), MoveTo s'arrête à STOP_SHORT studs de son but ; FROZEN : bloqué sur place.
				local move = math.min(h.humanoid.WalkSpeed * dt, math.max(distance - STOP_SHORT, 0))
				if move > 1e-6 and not FROZEN[h.root] then
					local nextPosition = before + offset.Unit * move
					if not inPole(nextPosition) then -- enfoncé dans un poteau, il reste sur place
						h.root.Position = nextPosition
					end
				end
			end
			local after = h.root.Position
			h.root.AssemblyLinearVelocity = vec((after.X - before.X) / dt, 0, (after.Z - before.Z) / dt)
		end
		pumpTasks() -- a269g : fils en attente (calcul des voies), comme entre deux images
		local q0 = QUERIES
		RunService.Heartbeat:Fire(dt)
		HB_MAX = math.max(HB_MAX, QUERIES - q0)
		for _, s in SIDES do -- les vigiles : mesurés dès le début
			watchSide(s.key, s.root, s.z0, s.dirX)
			if Avoid.GetState(s.root).Avoiding then
				AVOIDED[s.key] = true
			end
		end
		if not MEASURING then
			continue -- a269h : démarrage, témoins encore sur le circuit
		end
		for key, root in POLE_WATCH do
			POLE_MIN[key] = math.min(POLE_MIN[key] or math.huge, poleDist(root.Position))
		end
		for key, m in STILL_WATCH do
			local root = rootOf(m)
			local anim = ANIM_PLAYERS[m]
			if root.AssemblyLinearVelocity.Magnitude < 0.1 and anim and anim.playing.Walk then
				STILL_FOR[key] = (STILL_FOR[key] or 0) + dt
				STILL_MAX[key] = math.max(STILL_MAX[key] or 0, STILL_FOR[key])
			else
				STILL_FOR[key] = 0
			end
			if TRACK_LANE then
				LANE_BY[key] = math.max(LANE_BY[key] or 0, laneDist(OWN_LANE[root], root.Position))
			end
		end
		if TRACK_LANE then
			for root, lane in OWN_LANE do
				LANE_MAX = math.max(LANE_MAX, laneDist(lane, root.Position))
			end
		end
		for _, p in PAIRS_WATCH do
			local d = flatDist(p.a.Position, p.b.Position)
			MIN[p.key] = math.min(MIN[p.key] or math.huge, d)
			local near = d < 6
			if near and not NEAR[p.key] then
				MEET[p.key] = (MEET[p.key] or 0) + 1
			end
			NEAR[p.key] = near
			if near then
				local va, vb = p.a.AssemblyLinearVelocity.Magnitude, p.b.AssemblyLinearVelocity.Magnitude
				if (va < 0.1 and vb > 1) or (vb < 0.1 and va > 1) then
					MEET_PAUSED[p.key] = true
				end
			end
		end
		local ra, rb = rootOf(w10a), rootOf(w10b)
		local ia, ib = inside(ra.Position), inside(rb.Position)
		if ia and ib then
			BOTH_INSIDE += 1
		end
		if ia or ib then
			INSIDE_SEEN += 1
			local waiter = if ia then rb else ra
			if not (ia and ib) and waiter.AssemblyLinearVelocity.Magnitude < 0.1 then
				for _, e in ENDS do
					if flatDist(e, waiter.Position) < 3 then
						WAITED = true
						local passer = if ia then ra else rb
						WAIT_CLEAR = math.min(WAIT_CLEAR, laneDist(OWN_LANE[passer], waiter.Position))
					end
				end
			end
		end
	end
end

local function onCircuit(points, position)
	for _, p in points do
		if flatDist(p, position) < 1e-6 then
			return true
		end
	end
	return false
end
local function goalsOn(root, points)
	local on, off = 0, 0
	for goal in GOALS[root] or {} do
		if onCircuit(points, goal) then
			on += 1
		else
			off += 1
		end
	end
	return on, off
end
-- Plus courte distance entre un segment de voie et un poteau visible (bord du poteau), sur une voie.
local function laneClear(lane)
	local best = math.huge
	for k = 1, #lane do
		local a, b = lane[k], lane[k % #lane + 1]
		for _, p in POLES do
			if not p.ghost then
				best = math.min(best, (segDist(p.x, p.z, a.X, a.Z, b.X, b.Z)) - p.r)
			end
		end
	end
	return best
end
-- Segments de voie qui reviennent en arrière par rapport au circuit.
local function backtracks(lane, loop)
	local n = 0
	for k = 1, #lane do
		local k2 = k % #lane + 1
		local a, b, pa, pb = lane[k], lane[k2], loop[k], loop[k2]
		if (b.X - a.X) * (pb.X - pa.X) + (b.Z - a.Z) * (pb.Z - pa.Z) <= 0 then
			n += 1
		end
	end
	return n
end

-- a269g : démarrage, une reprise par pas (une image) : les voies se calculent par tranches, hors de Start ; un témoin
-- dont la zone n'a pas encore ses voies attend sur place (ni Walk ni pas), puis marche.
local function builtZones()
	local set = {}
	for _, l in LOGS do
		local z, q = string.match(l, "voies des témoins de la zone %d+ %(NPC_Witness_Z(%d+)_%d+%) : (%d+) requêtes")
		if z then
			set[tonumber(z)] = tonumber(q)
		end
	end
	return set
end
local WATCHED_START = { w1a, w1b, w3a, w3b, w6a, w6b, w7a, w7b, w9a, w9b, w10a, w10b, w13a, w13b, w14a, w14b }
local WALK_BEFORE, WAITED_START, STEPS_START = {}, 0, 0
local BUILT_STEP = {} -- a269h : le pas où chaque zone a eu ses voies
local ALL_BUILT = false
-- a269h : os.clock (NOW) n'avance pas pendant un calcul du banc ; à 1500 requêtes par tranche, toutes les voies
-- tiendraient en moins d'une seconde, sous la pause de départ (PauseMin). Au démarrage, chaque requête coûte
-- QUERY_TIME_START s (NOW avance) : le budget LaneStepBudget coupe les tranches, comme dans Studio, le calcul dure
-- plusieurs secondes et l'on voit les témoins marcher.
local QUERY_TIME_START = 0.0005
QUERY_TIME = QUERY_TIME_START
MEASURING = false
PUMP_ROUNDS = 1
for _ = 1, if AVOID_OFF then 0 else 600 do
	HOOK_STEP = STEPS_START + 1
	run(0.05)
	STEPS_START += 1
	local built = builtZones()
	for z in built do
		BUILT_STEP[z] = BUILT_STEP[z] or STEPS_START
	end
	ALL_BUILT = true
	for _, m in WATCHED_START do
		local anim = ANIM_PLAYERS[m]
		local walking = (anim ~= nil and anim.playing.Walk == true) or rootOf(m).AssemblyLinearVelocity.Magnitude > 0.1
		if built[PARTNER[m][2]] == nil then
			ALL_BUILT = false
			if walking then
				WALK_BEFORE[m] = true
			else
				WAITED_START += 1
			end
		end
	end
	if ALL_BUILT then
		break
	end
end
PUMP_ROUNDS = nil
HOOK_STEP = math.huge
QUERY_TIME = 0
-- a269h : puis chacun passe sur sa voie au point suivant (son premier but hors du circuit après ses voies) ; les
-- mesures commencent quand tous y sont.
local START_LOOPS = { [1] = LOOP1, [3] = LOOP3, [6] = LOOP6, [7] = LOOP7, [9] = LOOP9, [10] = LOOP10, [13] = LOOP13, [14] = LOOP14 }
local function onLane(m): boolean
	local zoneKey = PARTNER[m][2]
	local builtAt = BUILT_STEP[zoneKey] or math.huge
	for _, mv in GOAL_LOG[m] or {} do
		if mv.step >= builtAt and flatDist(mv.goal, mv.pos) >= 1e-3 then
			local best = math.huge
			for _, q in START_LOOPS[zoneKey] do
				best = math.min(best, flatDist(q, mv.goal))
			end
			if best >= 1e-3 then
				return true
			end
		end
	end
	return false
end
local SWITCH_WAIT = 0
while not AVOID_OFF and SWITCH_WAIT < 60 do
	local all = true
	for _, m in WATCHED_START do
		all = all and onLane(m)
	end
	if all then
		break
	end
	run(0.25)
	SWITCH_WAIT += 0.25
end
MEASURING = true
local ZONE_QUERIES = builtZones()
local SLICES_START = SLICES
run(90)
-- a269h : la pause de départ et la marche sur le circuit décalent les rencontres ; la zone 10 doit montrer une attente
-- à l'entrée du passage étroit : au plus 120 s de plus, par 5 s, jusqu'à la première.
local EXTRA_WAIT = 0
while not AVOID_OFF and not WAITED and EXTRA_WAIT < 120 do
	run(5)
	EXTRA_WAIT += 5
end
TRACK_LANE = false
if VERBOSE then
	for k, v in MIN do
		print(`écart minimal {k} : {math.round(v * 100) / 100} ; rencontres {MEET[k]}`)
	end
	for key, v in STILL_MAX do
		print(`immobilité hors Idle {key} : {math.round(v * 100) / 100} s ; écart max à sa voie {math.round((LANE_BY[key] or 0) * 100) / 100}`)
	end
	print(`attente : écart à la voie de celui qui passe {WAIT_CLEAR}`)
	for key, l in BUILT do
		print(`voies z{key} : {table.concat(l.fixes, " ; ")}`)
	end
	for _, l in LOGS do
		print(l)
	end
end
local PASS = 2.5 -- deux R15 de 2 studs de large ne se touchent pas à plus de 2 studs entre leurs centres ; marge

if not AVOID_OFF then
	check(`L1a deux témoins en sens inverse sur la boucle (pause à chaque point) : jamais plus près que {PASS} studs`, MIN["1"] >= PASS, MIN["1"])
	check("L1b ils se sont croisés au moins 2 fois, dont une avec l'un des deux en pause", (MEET["1"] or 0) >= 2 and MEET_PAUSED["1"] == true,
		`{MEET["1"]} {MEET_PAUSED["1"]}`)
	local onA, offA = goalsOn(rootOf(w1a), LOOP1)
	local onB, offB = goalsOn(rootOf(w1b), LOOP1)
	check("L1c chacun sur SA voie : jamais un point du circuit visé", onA == 0 and onB == 0 and offA >= 10 and offB >= 10, `{onA} {offA} {onB} {offB}`)
	check("L1d un volume invisible sans collision sur le circuit est ignoré (aucune correction en zone 1)", #L1.fixes == 0,
		table.concat(L1.fixes, " ; "))
	local clear, back, backBy = math.huge, 0, {}
	for key, l in BUILT do
		clear = math.min(clear, laneClear(l.f), laneClear(l.b))
		-- a269h : la zone 16 (épingle : le point d'après reculé derrière les deux d'avant) garde un segment un peu
		-- en arrière une fois alignée ; il est vérifié par L15b (angle au circuit au plus LaneTurnMax).
		local n = backtracks(l.f, l.loop) + backtracks(l.b, l.loop)
		if n > 0 then
			table.insert(backBy, `z{key} {n}`)
		end
		if key ~= 16 then
			back += n
		end
	end
	check(`L2a aucun segment de voie qui touche un poteau (bord à {AV.LaneClearance} studs ou plus du centre de la voie), 6 zones`,
		clear >= AV.LaneClearance - 1e-6, clear)
	check("L2b le lampadaire, la borne, la colonne et le mur corrigent leurs points", #L6.fixes >= 1 and #L7.fixes >= 1 and #L9.fixes >= 1
		and string.find(table.concat(L6.fixes), "StreetLamp_N4", 1, true) ~= nil, `{table.concat(L6.fixes, " ; ")} | {table.concat(L9.fixes, " ; ")}`)
	local fix7 = table.concat(L7.fixes, " ; ")
	check("L2c borne à 0,85 stud : la voie du sens −1 la contourne juste assez (points 2 et 3 : 1,5 / 2,75), l'autre voie inchangée",
		string.find(fix7, "P2 FacadeNY.Bollard_4 : 1.5 / 2.75", 1, true) ~= nil and string.find(fix7, "P3 FacadeNY.Bollard_4 : 1.5 / 2.75", 1, true) ~= nil, fix7)
	check("L2d colonne sans collision à 0,85 stud : vue et contournée", string.find(fix7, "Column_4_Shaft", 1, true) ~= nil, fix7)
	local sep = math.huge
	for _, key in { 1, 3, 6, 7, 9 } do
		local l = BUILT[key]
		for k = 1, #l.f do
			sep = math.min(sep, flatDist(l.f[k], l.b[k]))
		end
	end
	check("L2e hors passage étroit, les deux voies restent à 2 × Lane studs ou plus l'une de l'autre (points de pause compris)",
		sep >= 2 * AV.Lane - 1e-6, sep)
	check("L2f aucun segment de voie qui revient en arrière (bosse serrée de la zone 3 lissée)", back == 0, `{back} ({table.concat(backBy, ", ")}) | {table.concat(L3.fixes, " ; ")}`)
	local wallSide = true
	for _, lane in { L9.f, L9.b } do
		for _, p in lane do
			if p.Z > 1 - AV.LaneClearance + 1e-6 then
				wallSide = false
			end
		end
	end
	check("L2g mur collé au circuit : les points de voie passent devant le mur (côté rue)", wallSide, table.concat(L9.fixes, " ; "))
	local poleOk = true
	local detail = {}
	for key, v in POLE_MIN do
		table.insert(detail, `{key} {math.round(v * 100) / 100}`)
		if v < BODY - 1e-6 then
			poleOk = false
		end
	end
	check("L2h les témoins n'entrent jamais dans un poteau, même sans collision (lampadaire, borne, colonne, mur, bosse, passage)", poleOk,
		table.concat(detail, " "))
	check(`L2i croisements en zones 3, 6, 7 et 9 : jamais plus près que {PASS} studs`, MIN["3"] >= PASS and MIN["6"] >= PASS
		and MIN["7"] >= PASS and MIN["9"] >= PASS and (MEET["6"] or 0) >= 1 and (MEET["7"] or 0) >= 1,
		`{MIN["3"]} {MIN["6"]} {MIN["7"]} {MIN["9"]}`)
	local printed = false
	for _, l in LOGS do
		if string.find(l, "segments corrigés", 1, true) and string.find(l, "StreetLamp_N4", 1, true) then
			printed = true
		end
	end
	check("L2j segments corrigés écrits dans la sortie (zone 6 : StreetLamp_N4)", printed)
	-- L9 (a269e, Play f81d : point 13 de la zone 6 dans Column_4_Shaft) : une colonne SANS collision de 1,5 stud de rayon
	-- près du point 2, entre deux rangs de mur : aucun décalage libre ; le point est déplacé hors de la colonne.
	local LOOP12 = { g(6000, 0), g(6012, 0), g(6024, 0), g(6036, 0), g(6036, -20), g(6000, -20) }
	local z12folder = select(2, zone(12, { g(6000, 100), g(6010, 100) }))
	local front = node("Model", "FacadeNY", z12folder)
	pole(front, "Column_4_Shaft", 6012.3, 0.4, 1.5, 0, 14, false)
	for _, x in { 6011, 6012, 6013 } do
		pole(front, "Wall_N", x, 3, 0.5, 0, 14)
		pole(front, "Wall_S", x, -3, 0.5, 0, 14)
	end
	local f12, b12, fixes12 = Lanes.Build(LOOP12, HEIGHT, {})
	local inColumn = math.huge
	for _, lane in { f12, b12 } do
		for _, p in lane do
			inColumn = math.min(inColumn, flatDist(p, vec(6012.3, GROUND, 0.4)) - 1.5)
		end
	end
	local fix12 = table.concat(fixes12, " ; ")
	check("L9 point de voie dans une colonne sans collision (aucun décalage libre) : déplacé hors de la colonne",
		inColumn >= AV.LaneClearance - 1e-6 and string.find(fix12, "Column_4_Shaft : déplacé", 1, true) ~= nil, `{inColumn} | {fix12}`)
	-- L11 et L12 (a269f, Play f81e) : segments encore bouchés après les décalages, contournés par un détour.
	local function still(a, b)
		return `{math.round((STILL_MAX[a] or 0) * 100) / 100} {math.round((STILL_MAX[b] or 0) * 100) / 100} | voie {math.round((LANE_BY[a] or 0) * 100) / 100} {math.round((LANE_BY[b] or 0) * 100) / 100}`
	end
	local function walked(a, b)
		return (STILL_MAX[a] or 0) <= 2 + 1e-6 and (STILL_MAX[b] or 0) <= 2 + 1e-6 and (LANE_BY[a] or math.huge) <= 6
			and (LANE_BY[b] or math.huge) <= 6
	end
	local fix13 = table.concat(L13.fixes, " ; ")
	check("L11a colonne sur le circuit, un seul passage libre côté rue (zone 13) : le segment bouché est contourné (ligne « détour de »), aucune voie dans un poteau",
		string.find(fix13, "Column_4_Shaft : détour de", 1, true) ~= nil and math.min(laneClear(L13.f), laneClear(L13.b)) >= AV.LaneClearance - 1e-6,
		`{math.min(laneClear(L13.f), laneClear(L13.b))} | {fix13}`)
	check("L11b zone 13 : les deux témoins passent sans buter (au plus 2 s arrêtés hors Idle), jamais à plus de 6 studs de leur voie, jamais dans un poteau",
		walked("w13a", "w13b") and POLE_MIN.w13a >= BODY - 1e-6 and POLE_MIN.w13b >= BODY - 1e-6,
		`{still("w13a", "w13b")} | poteaux {POLE_MIN.w13a} {POLE_MIN.w13b}`)
	check(`L11c zone 13 : ils se croisent, jamais plus près que {PASS} studs`, (MEET["13"] or 0) >= 1 and MIN["13"] >= PASS, `{MIN["13"]} {MEET["13"]}`)
	local fix14 = table.concat(L14.fixes, " ; ")
	check("L12a borne qui ne laisse la place qu'à une voie (zone 14) : le segment bouché est contourné (ligne « détour de »), aucune voie sur la borne",
		string.find(fix14, "Bollard_4 : détour de", 1, true) ~= nil and math.min(laneClear(L14.f), laneClear(L14.b)) >= AV.LaneClearance - 1e-6,
		`{math.min(laneClear(L14.f), laneClear(L14.b))} | {fix14}`)
	check("L12b zone 14 : les deux témoins passent sans buter (au plus 2 s arrêtés hors Idle), jamais à plus de 6 studs de leur voie, jamais dans un poteau",
		walked("w14a", "w14b") and POLE_MIN.w14a >= BODY - 1e-6 and POLE_MIN.w14b >= BODY - 1e-6,
		`{still("w14a", "w14b")} | poteaux {POLE_MIN.w14a} {POLE_MIN.w14b}`)
	check(`L12c zone 14 : ils se croisent, jamais plus près que {PASS} studs`, (MEET["14"] or 0) >= 1 and MIN["14"] >= PASS, `{MIN["14"]} {MEET["14"]}`)
	-- L13 (a269g, Play f81f : « Script timeout » dans le Loader serveur) : le calcul des voies ne bloque jamais.
	local zones, maxZone, sumZone, detailZone = 0, 0, 0, {}
	for z, q in ZONE_QUERIES do
		zones += 1
		maxZone = math.max(maxZone, q)
		sumZone += q
		table.insert(detailZone, `z{z} {q}`)
	end
	table.sort(detailZone)
	local zoneText = table.concat(detailZone, ", ")
	-- a269h (Play f81g : 22 à 35 s plantés en Idle au lancement) : avant ses voies, chaque témoin marche sur le circuit
	-- (ses MoveTo visent des points du circuit, ou sa position : une pause) ; il passe sur sa voie au point suivant
	-- (son premier but hors du circuit, donné près d'un point du circuit), puis ne vise plus le circuit.
	local LOOP_OF = { [1] = LOOP1, [3] = LOOP3, [6] = LOOP6, [7] = LOOP7, [9] = LOOP9, [10] = LOOP10, [13] = LOOP13, [14] = LOOP14 }
	local function circuitGap(loop, p)
		local best = math.huge
		for _, q in loop do
			best = math.min(best, flatDist(q, p))
		end
		return best
	end
	local walkedBefore, offBefore, notSwitched, farSwitch, backOnCircuit, circuitMoves, switchFar = 0, {}, {}, {}, {}, 0, 0
	for _, m in WATCHED_START do
		local zoneKey = PARTNER[m][2]
		local loop, builtAt = LOOP_OF[zoneKey], BUILT_STEP[zoneKey] or math.huge
		local switched = false
		for _, mv in GOAL_LOG[m] or {} do
			local own = flatDist(mv.goal, mv.pos) < 1e-3
			local onCircuit = circuitGap(loop, mv.goal) < 1e-3
			if mv.step < builtAt then
				if onCircuit then
					circuitMoves += 1
				elseif not own then
					table.insert(offBefore, m.Name)
				end
			elseif not own then
				if not switched and not onCircuit then
					switched = true
					local gap = circuitGap(loop, mv.pos)
					switchFar = math.max(switchFar, gap)
					if gap > Witness.PointReached + 1 then
						table.insert(farSwitch, `{m.Name} {math.round(gap * 100) / 100}`)
					end
				elseif switched and onCircuit then
					table.insert(backOnCircuit, m.Name)
				end
			end
		end
		if WALK_BEFORE[m] then
			walkedBefore += 1
		end
		if not switched then
			table.insert(notSwitched, m.Name)
		end
	end
	check("L13a Start ne fait aucune requête de voies ; au démarrage, avant les voies de sa zone, chaque témoin marche sur le circuit (Walk, MoveTo vers ses points), puis passe sur sa voie près d'un point du circuit et n'y revient plus ; toutes les zones ont leurs voies",
		START_QUERIES == 0 and ALL_BUILT and walkedBefore >= #WATCHED_START / 2 and circuitMoves >= #WATCHED_START
			and #offBefore == 0 and #notSwitched == 0 and #farSwitch == 0 and #backOnCircuit == 0 and SWITCH_WAIT < 60,
		`Start {START_QUERIES} | marché avant {walkedBefore}/{#WATCHED_START}, {circuitMoves} buts du circuit | hors circuit avant {table.concat(offBefore, " ")} | pas passés {table.concat(notSwitched, " ")} | loin {table.concat(farSwitch, " ")} (pire {math.round(switchFar * 100) / 100}) | revenus {table.concat(backOnCircuit, " ")} | attentes {WAITED_START} | {STEPS_START} pas, tous sur leur voie {SWITCH_WAIT} s après | {zoneText}`)
	if VERBOSE then
		print(`MESURE a269h : démarrage : {STEPS_START} pas de 0,05 s pour toutes les voies ({QUERY_TIME_START} s par requête), marché avant {walkedBefore}/{#WATCHED_START}, {circuitMoves} buts du circuit, pire passage à {math.round(switchFar * 100) / 100} stud d'un point, tous sur leur voie {SWITCH_WAIT} s après ; attente en zone 10 vue à 90 + {EXTRA_WAIT} s`)
	end
	check(`L13b jamais plus de LaneStepQueries ({AV.LaneStepQueries}) requêtes sans rendre la main ; un calcul plus long que LaneStepBudget ({AV.LaneStepBudget} s ; ici {QUERY_TIME_START} s par requête) est coupé en plusieurs tranches ; Heartbeat n'en calcule aucune`,
		SLICE_MAX <= AV.LaneStepQueries and SLICES_START > zones and HB_MAX < AV.LaneStepQueries
			and #TASK_ERRORS == 0,
		`tranche max {SLICE_MAX}, {SLICES_START} tranches pour {zones} zones, zone max {maxZone}, total {sumZone}, Heartbeat max {HB_MAX} | {table.concat(TASK_ERRORS, " ; ")}`)
	do
		local yields, since, worst = 0, QUERIES, 0
		local co = coroutine.create(function()
			return Lanes.Build(LOOP13, HEIGHT, {}, function()
				coroutine.yield()
			end)
		end)
		local ok, f, b = coroutine.resume(co)
		local q0 = QUERIES
		since = q0
		while ok and coroutine.status(co) == "suspended" do
			yields += 1
			worst = math.max(worst, QUERIES - since)
			since = QUERIES
			ok, f, b = coroutine.resume(co)
		end
		worst = math.max(worst, QUERIES - since)
		local same = ok and type(f) == "table" and #f == #L13.f
		if same then
			for k = 1, #f do
				if flatDist(f[k], L13.f[k]) > 1e-9 or flatDist(b[k], L13.b[k]) > 1e-9 then
					same = false
				end
			end
		end
		check("L13c un calcul de voies coupé par des pauses (zone 13) donne exactement les mêmes voies, au plus LaneStepQueries requêtes par tranche",
			same and yields >= 1 and yields == Lanes.LastPauses and worst <= AV.LaneStepQueries,
			`{ok} {same} | {yields} pauses ({Lanes.LastPauses}), tranche max {worst}, {Lanes.LastQueries} requêtes`)
	end
	-- L14 (a269g, Play f81f : croisements à 0,77 et 0,88 en zone 1, pause au bout d'un passage étroit) : aucune pause au
	-- hasard à moins de PauseClearance studs de l'autre témoin, ni sur un point qui touche un passage étroit.
	local nearOther, atNarrow, minOther = {}, {}, math.huge
	for _, p in PAUSES do
		local partner = PARTNER[p.model]
		if partner then
			minOther = math.min(minOther, p.other)
			if p.other < Witness.PauseClearance - 1e-6 then
				table.insert(nearOther, `{p.model.Name} {math.round(p.other * 100) / 100}`)
			end
			local l = BUILT[partner[2]]
			local lane = if partner[3] > 0 then l.f else l.b
			local r, best = 1, math.huge
			for k, q in lane do
				local d = flatDist(q, p.position)
				if d < best then
					r, best = k, d
				end
			end
			if l.narrow[r] ~= nil or l.narrow[(r - 2) % #lane + 1] ~= nil then
				table.insert(atNarrow, `{p.model.Name} P{r}`)
			end
		end
	end
	check(`L14a pauses au hasard : jamais à moins de PauseClearance ({Witness.PauseClearance}) studs de l'autre témoin (pauses reportées)`,
		#PAUSES >= 20 and #nearOther == 0, `{#PAUSES} pauses, au plus près {math.round(minOther * 100) / 100} | {table.concat(nearOther, ", ")}`)
	check("L14b pauses au hasard : jamais sur un point qui touche un passage étroit (bouts compris)", #atNarrow == 0,
		table.concat(atNarrow, ", "))
	-- L15 (a269g, Play f81f : épingle au coin de la zone 1) : aucun virage de voie de plus de LaneTurnMax degrés (hors
	-- virage du circuit même), dans toutes les zones ; celui du coin de la zone 15 est lissé.
	local function turnOf(a, b, c)
		local ux, uz, vx, vz = b.X - a.X, b.Z - a.Z, c.X - b.X, c.Z - b.Z
		local lu, lv = math.sqrt(ux * ux + uz * uz), math.sqrt(vx * vx + vz * vz)
		if lu < 1e-3 or lv < 1e-3 then
			return 0
		end
		return math.deg(math.acos(math.clamp((ux * vx + uz * vz) / (lu * lv), -1, 1)))
	end
	local sharp, worstTurn = {}, 0
	for key, l in BUILT do
		local n = #l.f
		for k = 1, n do
			local k0, k2 = (k - 2) % n + 1, k % n + 1
			if turnOf(l.loop[k0], l.loop[k], l.loop[k2]) <= AV.LaneTurnMax then
				for side, lane in { l.f, l.b } do
					local t = turnOf(lane[k0], lane[k], lane[k2])
					worstTurn = math.max(worstTurn, t)
					if t > AV.LaneTurnMax then
						table.insert(sharp, `z{key} P{k} voie {side} {math.floor(t)}°`)
					end
				end
			end
		end
	end
	local fix15 = table.concat(L15.fixes, " ; ")
	check(`L15 aucun virage de voie de plus de LaneTurnMax ({AV.LaneTurnMax}°) hors circuit, toutes zones ; le coin de la zone 15 est lissé`,
		#sharp == 0 and string.find(fix15, "virage de", 1, true) ~= nil and string.find(fix15, "lissé", 1, true) ~= nil,
		`pire {math.floor(worstTurn)}° | {table.concat(sharp, ", ")} | {fix15}`)
	local fix16 = table.concat(L16.fixes, " ; ")
	check("L15b zone 16 (coin où a269g laissait « P2 retour virage de 158° : non lissé ») : virage lissé en alignant le point et un voisin, aucun « non lissé »",
		string.find(fix16, "alignés", 1, true) ~= nil and string.find(fix16, "non lissé", 1, true) == nil, fix16)
	if VERBOSE then
		print(`MESURE a269g : Start {START_QUERIES} requêtes ; {STEPS_START} pas d'une image pour toutes les voies ; tranche max {SLICE_MAX}, {SLICES_START} tranches ; Heartbeat max {HB_MAX} ; {zoneText}`)
		print(`MESURE a269g : {#PAUSES} pauses, au plus près de l'autre {math.round(minOther * 100) / 100} ; pire virage {math.floor(worstTurn)}° ; z15 : {fix15}`)
		print(`MESURE a269h : z16 : {fix16}`)
	end
	-- L5 : passage étroit.
	check("L5a passage étroit trouvé en zone 10 (aucun sur les lignes droites des zones 1, 6 et 7)", #NARROW_SEGS >= 1 and #ENDS == 2 and next(L1.narrow) == nil
		and next(L6.narrow) == nil and next(L7.narrow) == nil,
		`{#NARROW_SEGS} {#ENDS} | {table.concat(L10.fixes, " ; ")}`)
	check("L5b un seul témoin dedans à la fois ; l'autre a attendu à l'entrée", BOTH_INSIDE == 0 and WAITED and INSIDE_SEEN > 100,
		`{BOTH_INSIDE} {WAITED} {INSIDE_SEEN} (90 + {EXTRA_WAIT} s)`)
	check(`L5c zone 10 : jamais plus près que {PASS} studs`, MIN["10"] >= PASS, MIN["10"])
	check(`L5d (a269f) celui qui attend reste à {PASS} studs ou plus de la voie de celui qui passe (attente NarrowStandOff studs avant l'entrée)`,
		WAIT_CLEAR >= PASS, WAIT_CLEAR)
	-- L6 : laisse.
	local leash = AV.LaneMax + AV.LaneLeash
	check(`L6a en balade, jamais à plus de LaneMax + LaneLeash ({leash}) studs de sa voie (12 témoins, 90 s)`, LANE_MAX <= leash + 1e-6, LANE_MAX)

	-- L3 : plus de pause ; un poteau apparaît sur sa voie, entre lui et le point qu'il vise, et on le pousse contre.
	RNG_VALUE = 0.99
	run(Witness.PauseMax + 1)
	local root8 = rootOf(w8)
	local hum8 = w8.Humanoid
	for _ = 1, 100 do
		local goal = rawget(hum8, "_goal")
		if goal and flatDist(goal, root8.Position) > 6 then
			break
		end
		run(0.05)
	end
	local aim = rawget(hum8, "_goal")
	-- a269e : il vise LaneOvershoot studs au-delà du point de voie, dans l'axe de son approche : le point visé est le
	-- point de voie le plus proche de son but.
	local f8, b8 = Lanes.Build({ g(0, 1600), g(40, 1600), g(40, 1630), g(0, 1630) }, HEIGHT, {})
	local function lanePointOf(goal)
		local best, bestD = nil, math.huge
		for _, lane in { f8, b8 } do
			for _, p in lane do
				local d = flatDist(goal, p)
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
		return if bestD <= AV.LaneOvershoot + 1e-3 then best else nil
	end
	local target = lanePointOf(aim)
	local u = vec(aim.X - root8.Position.X, 0, aim.Z - root8.Position.Z).Unit
	local block = pole(z8folder, "Block", root8.Position.X + u.X * 2, root8.Position.Z + u.Z * 2, 0.5, 0, 14)
	local p8 = POLES[#POLES]
	local spot = vec(p8.x - u.X * (BODY + p8.r + 0.02), BODY_Y, p8.z - u.Z * (BODY + p8.r + 0.02))
	root8.Position = spot
	local pushedAt, freedAt, backOnAim = NOW, nil, false
	for _ = 1, 100 do
		run(0.05)
		if freedAt == nil and flatDist(root8.Position, spot) >= 1 then
			freedAt = NOW
		end
		local goal = rawget(hum8, "_goal")
		if freedAt and goal and target and lanePointOf(goal) == target then
			backOnAim = true
		end
	end
	local took = if freedAt then freedAt - pushedAt else math.huge
	check("L3 poussé contre un poteau : il repart en 1,5 s ou moins (point libre à côté)", took <= 1.5 + 1e-6, took)
	check("L3b puis il reprend le même point visé (pas le suivant)", backOnAim)
	table.remove(POLES, table.find(POLES, p8))
	block.Parent = nil
	run(10)
	check("L3c puis il reprend sa voie, sans plus se coincer", POLE_MIN.w8 >= BODY - 1e-6 and root8.AssemblyLinearVelocity.Magnitude > 1,
		`{POLE_MIN.w8} {root8.AssemblyLinearVelocity.Magnitude}`)

	-- L7 (a269e) : arrivée et enchaînement : zone 1, sans pause, MoveTo qui s'arrête à STOP_SHORT de son but.
	local r1a, r1b = rootOf(w1a), rootOf(w1b)
	GOALS[r1a], GOALS[r1b] = nil, nil
	local stopFor, stopMax = {}, 0
	for _ = 1, 400 do
		run(0.05)
		for _, r in { r1a, r1b } do
			if r.AssemblyLinearVelocity.Magnitude < 0.1 then
				stopFor[r] = (stopFor[r] or 0) + 0.05
				stopMax = math.max(stopMax, stopFor[r])
			else
				stopFor[r] = 0
			end
		end
	end
	check("L7a arrivée aux points de voie (MoveTo arrêté à 0,9 stud de son but) : jamais arrêté plus de 0,25 s, 20 s sans pause",
		stopMax <= 0.25 + 1e-6, stopMax)
	local goalsSeen, offLane = 0, 0
	for _, pair in { { r1a, L1.f }, { r1b, L1.b } } do
		for goal in GOALS[pair[1]] or {} do
			goalsSeen += 1
			local near = math.huge
			for _, p in pair[2] do
				near = math.min(near, flatDist(goal, p))
			end
			if near > AV.LaneOvershoot + 1e-3 then
				offLane += 1
			end
		end
	end
	check("L7b il enchaîne les points de sa voie (but à LaneOvershoot au plus d'un point de voie), sans pas de côté",
		goalsSeen >= 8 and offLane == 0, `{goalsSeen} {offLane}`)

	-- L10 (a269e) : un témoin bloqué dans le passage étroit de la zone 10 (figé sur place) ; l'autre attend au plus
	-- NarrowWait s à l'entrée, en Idle, puis passe ; le bloqué ne vise pas le même point sans fin.
	local ra, rb = rootOf(w10a), rootOf(w10b)
	for _ = 1, 1200 do
		run(0.05)
		if inside(ra.Position) and not inside(rb.Position) then
			break
		end
	end
	local frozeInside = inside(ra.Position)
	FROZEN[ra] = true
	local waitStart, waitMax, walkWhileWait, passes, wasInside, walkTicks = nil, 0, false, 0, inside(rb.Position), 0
	local lastGoal, goalChanges = rawget(w10a.Humanoid, "_goal"), 0
	for _ = 1, 800 do
		run(0.05)
		local atEnd = false
		for _, e in ENDS do
			if flatDist(e, rb.Position) < 3 then
				atEnd = true
			end
		end
		if atEnd and rb.AssemblyLinearVelocity.Magnitude < 0.1 then
			waitStart = waitStart or NOW
			waitMax = math.max(waitMax, NOW - waitStart)
			local anim = ANIM_PLAYERS[w10b]
			-- Walk encore joué deux pas de suite à l'arrêt (au pas où il repart, Walk précède son premier mouvement)
			walkTicks = if anim and anim.playing.Walk then walkTicks + 1 else 0
			if walkTicks >= 2 then
				walkWhileWait = true
			end
		else
			waitStart = nil
			walkTicks = 0
		end
		local isInside = inside(rb.Position)
		if isInside and not wasInside then
			passes += 1
		end
		wasInside = isInside
		local goal = rawget(w10a.Humanoid, "_goal")
		if goal ~= lastGoal then
			goalChanges += 1
			lastGoal = goal
		end
	end
	FROZEN[ra] = nil
	check("L10a passage tenu par un témoin bloqué dedans : l'autre attend au plus NarrowWait s à l'entrée, en Idle, et passe (40 s)",
		frozeInside and waitMax <= AV.NarrowWait + 0.3 and not walkWhileWait and passes >= 2, `{frozeInside} {waitMax} {walkWhileWait} {passes}`)
	check("L10b le témoin bloqué ne vise pas le même point sans fin (plafond LaneGoalSlack : point suivant)", goalChanges >= 2, goalChanges)
	run(5)

	-- L16 (a269h, Play f81g : les 12 témoins figés 4,7 à 11,4 s en Walk d'un coup, cause inconnue) : rattrapage. Jusqu'ici,
	-- aucune ligne « rattrapage » (un seul témoin bloqué n'en écrit pas) ; puis tous ceux qui marchent sont figés 3 s
	-- ensemble : une seule ligne, qui les nomme, et ils repartent.
	local function retryLines()
		local found = {}
		for _, l in LOGS do
			if string.find(l, "rattrapage :", 1, true) then
				table.insert(found, l)
			end
		end
		return found
	end
	local retryBefore = #retryLines()
	local victims = {}
	for _ = 1, 200 do
		run(0.05)
		table.clear(victims)
		for _, m in WATCHED_START do
			local anim = ANIM_PLAYERS[m]
			if PARTNER[m][2] ~= 10 and anim and anim.playing.Walk and rootOf(m).AssemblyLinearVelocity.Magnitude > 0.1 then
				table.insert(victims, m)
			end
		end
		if #victims >= 4 then
			break
		end
	end
	local frozenAt = {}
	for _, m in victims do
		FROZEN[rootOf(m)] = true
		frozenAt[m] = rootOf(m).Position
	end
	run(3)
	for _, m in victims do
		FROZEN[rootOf(m)] = nil
	end
	local lines = retryLines()
	local named = 0
	local line = lines[#lines] or ""
	for _, m in victims do
		if string.find(line, m.Name, 1, true) then
			named += 1
		end
	end
	local restarted = {}
	for _ = 1, 120 do
		run(0.05)
		for _, m in victims do
			if flatDist(rootOf(m).Position, frozenAt[m]) >= 1 then
				restarted[m] = true
			end
		end
	end
	local back = 0
	for _ in restarted do
		back += 1
	end
	check("L16a rattrapage : aucune ligne « rattrapage » avant ; figés ensemble 3 s en marche, une seule ligne qui en nomme au moins 3 (MoveTo redonné après WalkRetry s), et tous repartent",
		retryBefore == 0 and #victims >= 4 and #lines == 1 and named >= 3 and back == #victims,
		`avant {retryBefore} | figés {#victims} | lignes {#lines}, nommés {named} | repartis {back} | {line}`)
	run(2)

	-- L6b : posé à 10 studs et plus de sa voie (au milieu de la boucle), il revient au point le plus proche de sa voie.
	local root1 = rootOf(w1a)
	root1.Position = vec(30, BODY_Y, 12)
	local start = laneDist(L1.f, root1.Position)
	run(0.2)
	local first = rawget(w1a.Humanoid, "_goal")
	-- a269e : son but est LaneOvershoot studs au-delà de ce point, dans l'axe de son retour
	local onLane = first ~= nil and math.abs(laneDist(L1.f, first) - AV.LaneOvershoot) < 1e-3
		and math.abs(flatDist(first, vec(30, GROUND, 12)) - (start + AV.LaneOvershoot)) < 0.05
	run(start / Witness.WalkSpeed + 1)
	local now1 = laneDist(L1.f, root1.Position)
	check("L6b posé loin de sa voie : il vise le point le plus proche de sa voie et y est revenu", start > leash and onLane and now1 < 1,
		`{start} {first and `{first.X},{first.Z}` or "nil"} {now1}`)

	-- L4 : Avoid.Players coupé (V0 false) : comme avant a269, un joueur sur sa ligne ne l'arrête pas.
	local probe = node("Part", "Probe_Player", Workspace)
	probe.Position = vec(0, BODY_Y, 3000)
	runner.Character.HumanoidRootPart.Position = vec(5, BODY_Y, 3000)
	check("L4 Avoid.Players coupé : PlayerAhead faux même pour un joueur juste devant, sur la ligne",
		not Avoid.PlayerAhead(probe, vec(50, BODY_Y, 3000), 6))

	-- L8 : filet (module) : jamais un point dans un renfoncement d'où il ne voit pas son point visé.
	local from = vec(5000, BODY_Y, 0)
	pole(recess, "Pilaster_L", 5005, 2.2, 0.8, 0, 14)
	local s1 = Lanes.Sidestep(from, vec(1, 0, 0), vec(5010, GROUND, 0), vec(4995, GROUND, 0), {})
	check("L8a renfoncement à droite (le point visé caché) : il se dégage à gauche", s1 ~= nil and s1.Z < -2 and math.abs(s1.X - 5000) < 1e-6,
		s1 and `{s1.X},{s1.Z}` or "nil")
	pole(recess, "Pilaster_R", 5005, -2.2, 0.8, 0, 14)
	local s2 = Lanes.Sidestep(from, vec(1, 0, 0), vec(5010, GROUND, 0), vec(4995, GROUND, 0), {})
	check("L8b les deux côtés cachés : il revient à son point d'avant", s2 ~= nil and math.abs(s2.X - 4995) < 1e-6 and math.abs(s2.Z) < 1e-6,
		s2 and `{s2.X},{s2.Z}` or "nil")

	check(`A4a deux vigiles en ronde face à face : jamais plus près que {PASS} studs`, MIN["4"] >= PASS, MIN["4"])
	check("A4b chacun sur sa droite (écart dynamique gardé pour les vigiles)", AVOIDED.g4a and AVOIDED.g4b and SIDE.g4a >= 1.5 and SIDE.g4b >= 1.5,
		`{SIDE.g4a} {SIDE.g4b}`)

	-- A5 : directement sur le module (vigiles).
	local fa = guard("Probe_A", vec(0, 3, 1000), "Return", vec(-1, 3, 1000), 6, { store = {}, returnGoal = vec(100, 3, 1000) })
	local fb = guard("Probe_B", vec(4, 3, 1000), "Return", vec(-1, 3, 1000), 6, { store = {}, returnGoal = vec(100, 3, 1000) })
	Avoid.Track(fb.root)
	fb.root.AssemblyLinearVelocity = vec(6, 0, 0)
	local same = Avoid.GuardAim(fa, vec(50, 3, 1000))
	check("A5a même sens, même pas, devant lui : pas d'écart", flatDist(same, vec(50, 3, 1000)) < 1e-6, `{same}`)
	fb.root.AssemblyLinearVelocity = vec(0, 0, 0)
	local still = Avoid.GuardAim(fa, vec(50, 3, 1000))
	check("A5b arrêté devant lui : écart sur sa droite (+Z en allant vers +X)", still.Z > 1000.5, `{still}`)
	fa.state = "Chase"
	local chase = Avoid.GuardAim(fa, vec(50, 3, 1000))
	check("A5c en poursuite : jamais d'écart (capture inchangée)", flatDist(chase, vec(50, 3, 1000)) < 1e-6 and not Avoid.GetState(fa.root).Avoiding)
	fa.state = "Return"
	fa.returnGoal = vec(6, 3, 1000)
	local nearGoal = Avoid.GuardAim(fa, vec(50, 3, 1000))
	check("A5d à moins de Detect studs de son but final : pas d'écart", flatDist(nearGoal, vec(50, 3, 1000)) < 1e-6)
	fb.root.Position = vec(4, 12, 1000)
	fa.returnGoal = vec(100, 3, 1000)
	local upstairs = Avoid.GuardAim(fa, vec(50, 3, 1000))
	check("A5e un autre étage (plus de MaxRise studs) : pas d'écart", flatDist(upstairs, vec(50, 3, 1000)) < 1e-6)

	local function pair(a, b)
		for _, p in PAIRS do
			if ((p.a == a and p.b == b) or (p.a == b and p.b == a)) and p.on == false then
				return true
			end
		end
		return false
	end
	local default = false
	for _, p in PAIRS do
		if p.a == "Default" or p.b == "Default" then
			default = true
		end
	end
	check("A6a groupe Witnesses sans choc avec lui-même ni avec Guards ; Default jamais touché (joueurs inchangés)",
		REGISTERED.Witnesses and REGISTERED.Guards and pair("Witnesses", "Witnesses") and pair("Witnesses", "Guards") and not default)
	check("A6b pièces des témoins dans Witnesses ; un groupe posé par Clément gardé",
		w1a.HumanoidRootPart.CollisionGroup == "Witnesses" and w1b.Head.CollisionGroup == "Witnesses" and wOwn.Head.CollisionGroup == "Clement"
			and wOwn.HumanoidRootPart.CollisionGroup == "Witnesses")
	local warns = 0
	for _, l in LOGS do
		if string.sub(l, 1, 4) == "WARN" and not string.find(l, "se balade seulement", 1, true) then
			warns += 1
		end
	end
	check("A7 aucune alerte", warns == warnsAtStart and warnsAtStart == 0, warns)
else
	check("O1 coupé : les deux témoins se superposent sur le circuit (comme avant a269)", MIN["1"] < 0.5, MIN["1"])
	check("O2 coupé : aucun groupe de collision", #PAIRS == 0 and w1a.HumanoidRootPart.CollisionGroup == "Default")
	local onA, offA = goalsOn(rootOf(w1a), LOOP1)
	check("O3 coupé : il ne vise que des points du circuit (pas de voie)", offA == 0 and onA >= 10, `{onA} {offA}`)
	local retries = 0
	for _, l in LOGS do
		if string.find(l, "rattrapage :", 1, true) then
			retries += 1
		end
	end
	check("O4 coupé (a269h) : aucun rattrapage, aucune ligne « rattrapage » (comme avant a269)", retries == 0, retries)
end

print(`banc a269 {if AVOID_OFF then "off" else "on"} : {CHECKS} vérification(s), {FAILS} échec(s)`)
