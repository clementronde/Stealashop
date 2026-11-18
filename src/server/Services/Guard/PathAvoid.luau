--!strict
-- Guard/PathAvoid (serveur, f70c3 ; Play de diagnostic de fusion70, Supérette) : module d'aide de GuardService
-- (sous-dossier : le Loader ne le démarre pas). Valeurs : Config/Chase.PathAvoid (interrupteur Enabled).
--
-- 1. Présentoirs bas contournés. Le chemin du vigile passait toujours par-dessus la table Promo_A (5,4 × 1,9 × 2,2) :
--    il y montait et attrapait le voleur depuis la table. Au démarrage, chaque pièce d'un magasin PNJ (tag NPCStore)
--    dont le nom, ou celui d'un de ses parents dans le magasin, commence par un des Chase.PathAvoid.Prefixes reçoit un
--    PathfindingModifier « PathAvoid » (Label = Chase.PathAvoid.Label : « la zone dans ou sur les pièces », doc de
--    Roblox) ; l'agent de chaque vigile (GuardService agentFor) paie Chase.PathAvoid.Cost fois plus cher chaque stud de
--    cette zone (Costs). Il les contourne donc, et n'y monte que s'il n'y a aucun autre passage (voleur perché dessus).
--    Pièces ajoutées plus tard dans un magasin, et magasins tagués plus tard : traités aussi. Rien de visuel : le
--    modificateur n'a ni taille ni rendu ; aucune pièce de Clément n'est déplacée, renommée ni changée.
-- 2. Saut à la hauteur de la marche. Un saut de chemin montait toujours au saut du rig (+7,2 studs), même pour une
--    marche de 2 studs. Juste avant (BeforeJump), JumpHeight = marche à monter (le plus haut du point de saut et du
--    suivant, moins les pieds du vigile) + Chase.PathAvoid.JumpMargin, au moins JumpMin, jamais plus que le saut du
--    rig (UseJumpPower coupé) ; rien à monter (trou, descente) : le saut du rig. JumpMargin = 0 : toujours le saut du rig.
-- 3. Coins coupés (GuardService farthestReachable) : avec Enabled, les rayons de ses flancs sont aussi tirés à hauteur
--    des genoux ; avant, seul le rayon du milieu y voyait une table basse, et il en rognait le coin (Play : il y
--    montait à pied, sans saut).
-- 4. f70c3b (Play de rejeu de fusion71 : 24 pièces marquées, mais le vigile sautait encore sur Promo_A, à +4,55, depuis
--    2 studs de son bord ; le modificateur d'une pièce ne couvre pas son dessus, où marche l'agent) : chaque pièce
--    marquée reçoit aussi un volume (Part « PathAvoidVolume » dans Workspace/PathAvoidVolumes, invisible, Anchored, ni
--    collision, ni rayon, ni contact) de son empreinte, de son bas à Chase.PathAvoid.Headroom studs au-dessus d'elle,
--    avec un PathfindingModifier du même Label ; avec Cost = math.huge, l'agent n'y passe jamais. Pièce retirée du jeu :
--    volume retiré. Et BeforeJump refuse un saut dont le point de saut ou le suivant est à moins de JumpNear studs
--    (à plat) d'une pièce marquée : l'appelant ne saute pas.
--
-- API :
--   PathAvoid.Start()                                         au démarrage de GuardService
--   PathAvoid.Enabled() -> boolean                             Chase.PathAvoid.Enabled (et un Label)
--   PathAvoid.Costs() -> { [string]: number }?                 Costs de l'agent du PathfindingService (nil : rien)
--   PathAvoid.BeforeJump(humanoid, waypoints, index, feet)    juste avant humanoid.Jump = true vers waypoints[index]
--     -> boolean                                               (feet : hauteur de ses pieds) ; false : ne pas sauter
--   PathAvoid.GetState() -> { Marked: number, Stores: number, Volumes: number }
--                                                              pièces marquées, magasins suivis, volumes en place

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Chase = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Chase")) :: any

local STORE_TAG = "NPCStore"
local MODIFIER_NAME = "PathAvoid"
local RIG_JUMP_HEIGHT = 7.2 -- saut d'un Humanoid de Roblox par défaut (studs), si le rig n'en donne pas

local PathAvoid = {}

local VOLUME_NAME = "PathAvoidVolume"
local VOLUME_FOLDER = "PathAvoidVolumes"

local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local rigJump: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any
local volumes: { [BasePart]: BasePart } = {} -- pièce marquée -> son volume
local marked = 0
local stores = 0
local folder: Folder? = nil

local function config(): any
	local cfg = Chase.PathAvoid
	return if type(cfg) == "table" then cfg else nil
end

local function enabled(): boolean
	local cfg = config()
	return cfg ~= nil and cfg.Enabled == true and type(cfg.Label) == "string" and cfg.Label ~= ""
end

local function matches(name: string): boolean
	local prefixes = config().Prefixes
	if type(prefixes) ~= "table" then
		return false
	end
	for _, prefix in prefixes do
		if type(prefix) == "string" and prefix ~= "" and string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

-- La pièce, ou un de ses parents jusqu'au magasin (exclu), porte-t-elle un nom de la liste ?
local function listed(store: Instance, part: BasePart): boolean
	local current: Instance? = part
	while current ~= nil and current ~= store do
		if matches(current.Name) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function consider(store: Instance, instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChild(MODIFIER_NAME) ~= nil then
		return
	end
	local part = instance :: BasePart
	if not listed(store, part) then
		return
	end
	local modifier = Instance.new("PathfindingModifier")
	modifier.Name = MODIFIER_NAME
	modifier.Label = config().Label
	modifier.PassThrough = false
	modifier.Parent = part
	marked += 1
	-- f70c3b : volume de l'empreinte de la pièce, de son bas à Headroom studs au-dessus (son dessus compris).
	local headroom = config().Headroom
	if type(headroom) ~= "number" or headroom < 0 or not part:IsDescendantOf(Workspace) then
		return
	end
	if folder == nil or folder.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = VOLUME_FOLDER
		made.Parent = Workspace
		folder = made
	end
	local volume = Instance.new("Part")
	volume.Name = VOLUME_NAME
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.CastShadow = false
	volume.Transparency = 1
	volume.Size = Vector3.new(part.Size.X, part.Size.Y + headroom, part.Size.Z)
	volume.CFrame = part.CFrame * CFrame.new(0, headroom / 2, 0)
	local label = Instance.new("PathfindingModifier")
	label.Name = MODIFIER_NAME
	label.Label = config().Label
	label.PassThrough = false
	label.Parent = volume
	volume.Parent = folder
	volumes[part] = volume
	part.AncestryChanged:Connect(function()
		if volumes[part] == volume and not part:IsDescendantOf(Workspace) then
			volumes[part] = nil
			volume:Destroy()
		end
	end)
end

local function watch(store: Instance)
	if watched[store] then
		return
	end
	watched[store] = true
	stores += 1
	for _, descendant in store:GetDescendants() do
		consider(store, descendant)
	end
	store.DescendantAdded:Connect(function(descendant: Instance)
		consider(store, descendant)
	end)
end

function PathAvoid.Start()
	if not enabled() then
		return
	end
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		watch(store)
	end
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(watch)
end

-- Interrupteur (GuardService : flancs à hauteur des genoux dans farthestReachable, pour ne pas couper le coin d'une
-- table basse en suivant un chemin qui la contourne).
function PathAvoid.Enabled(): boolean
	return enabled()
end

function PathAvoid.Costs(): { [string]: number }?
	if not enabled() then
		return nil
	end
	local cost = config().Cost
	if type(cost) ~= "number" or cost <= 1 then
		return nil
	end
	return { [config().Label :: string] = cost }
end

-- Le saut du rig, lu une fois par Humanoid (avant qu'on y touche).
local function rigJumpOf(humanoid: Humanoid): number
	local known = rigJump[humanoid]
	if known ~= nil then
		return known
	end
	local height: number? = nil
	if humanoid.UseJumpPower then
		local power = humanoid.JumpPower
		if type(power) == "number" and power > 0 then
			height = power * power / (2 * Workspace.Gravity)
		end
	else
		local value = humanoid.JumpHeight
		if type(value) == "number" and value > 0 then
			height = value
		end
	end
	local result = height or RIG_JUMP_HEIGHT
	rigJump[humanoid] = result
	return result
end

-- f70c3b : `point` à moins de `near` studs (à plat) de l'empreinte d'une pièce marquée, entre son bas (- 1) et
-- Headroom (+ 1) studs au-dessus d'elle ?
local function nearMarked(point: Vector3, near: number): boolean
	local headroom = config().Headroom
	local above = if type(headroom) == "number" and headroom > 0 then headroom else 0
	for part in volumes do
		local here = part.CFrame:PointToObjectSpace(point)
		local half = part.Size / 2
		if math.abs(here.X) <= half.X + near and math.abs(here.Z) <= half.Z + near
			and here.Y >= -half.Y - 1 and here.Y <= half.Y + above + 1
		then
			return true
		end
	end
	return false
end

function PathAvoid.BeforeJump(humanoid: Humanoid, waypoints: { PathWaypoint }, index: number, feet: number): boolean
	local cfg = config()
	if enabled() and type(cfg.JumpNear) == "number" and cfg.JumpNear > 0 and index >= 1 and index <= #waypoints then
		-- f70c3b : jamais un saut vers une pièce marquée ou à son pied.
		if nearMarked(waypoints[index].Position, cfg.JumpNear)
			or (index < #waypoints and nearMarked(waypoints[index + 1].Position, cfg.JumpNear))
		then
			return false
		end
	end
	local margin = if cfg ~= nil then cfg.JumpMargin else nil
	if type(margin) ~= "number" or margin <= 0 then
		return true
	end
	local rig = rigJumpOf(humanoid)
	local height = rig
	if index >= 1 and index <= #waypoints then
		-- Points de chemin au niveau du sol : le plus haut du point de saut et du suivant, moins ses pieds.
		local top = waypoints[index].Position.Y
		if index < #waypoints then
			top = math.max(top, waypoints[index + 1].Position.Y)
		end
		local rise = top - feet
		if rise > 0 then
			local minimum = if type(cfg.JumpMin) == "number" then cfg.JumpMin else 0
			height = math.clamp(rise + margin, math.min(minimum, rig), rig)
		end
	end
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = height
	return true
end

function PathAvoid.GetState(): { Marked: number, Stores: number, Volumes: number }
	local count = 0
	for _ in volumes do
		count += 1
	end
	return { Marked = marked, Stores = stores, Volumes = count }
end

return PathAvoid
