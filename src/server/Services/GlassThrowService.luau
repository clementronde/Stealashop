--!strict
-- GlassThrowService (a315, L-291 ; règle de Cantin du 23/11) : l'intrus frappé par le propriétaire dans sa boutique
-- part en ragdoll, à pleine vitesse, à travers la vitre la plus proche dans le sens du coup (sinon la plus proche),
-- la troue à l'endroit où passe le corps, atterrit dehors et se relève (Knockback). Le trou se répare après
-- GlassThrow.HoleDuration. Réglages V0 : Shared/Config/GlassThrow. Sous Features.ShopGlassThrow (PROD) ou
-- Features.ShopGlassThrowDev dans le jeu DEV (Config/ProductIds.IsDev) ; éteint, PvPService fait comme avant
-- (sortie devant la porte).
--
-- Le serveur décide tout : qui frappe qui (appel de PvPService après un coup validé par BatService), si l'intrus est
-- dans la boutique (volume Bounds, repère de la boutique, même règle que PvPService), quelle vitre et où passe le
-- trou (Shared/ShopGlass). Il ne touche jamais aux vitres : le trou, le givre et les éclats sont dessinés par chaque
-- client (GlassThrowController) sur une copie locale, la vraie vitre cachée en local puis rendue telle quelle.
--
-- Vol : le serveur prend la main sur le personnage (SetNetworkOwner(nil)), remplace ses Motor6D par des
-- BallSocketConstraint (sauf Root et Neck), le pousse à plat (LinearVelocity en plan, GlassThrow.Speed) avec une
-- vitesse verticale de départ calculée pour passer la vitre à la hauteur du trou. Les murs invisibles de la boutique
-- (PlotBarrier, Stage_j/Barriers : GlassThrow.BarrierContainers) ne l'arrêtent pas : le corps projeté passe dans le
-- groupe de collision GlassThrow.GroupThrown et les murs de cette boutique dans GlassThrow.GroupBarrier, qui ne se
-- heurtent pas ; les deux groupes reprennent les règles de « Default » avec tous les autres groupes, donc rien
-- d'autre ne change (les autres joueurs heurtent toujours les murs). La map n'est pas modifiée : groupes d'origine
-- rendus à l'atterrissage (murs : quand plus aucun vol de cette boutique ne les traverse).
-- Le trou s'ouvre quand le corps passe le plan de la vitre (au plus tard à la fin de la poussée). La poussée s'arrête
-- hors de Bounds (ClearMargin) ou après MaxPushTime. Après RagdollTime : relevé (Motor6D rendus, debout), personnage
-- rendu au joueur, groupes rendus, puis `onDone(dehors)` : PvPService sort devant la porte un joueur resté dedans.
--
-- Remote GlassThrow (ServerToClient, fiable, à tous) : (kind, pane, point, direction, victim?, hitter?, fresh?)
--   "Throw"  au coup : sons, traînée, secousse (victime et frappeur) ;
--   "Hole"   le corps passe la vitre : trou (fresh = true) ou passage par un trou déjà ouvert (fresh = false) ;
--   "Land"   relevé : la victime joue Knockback ;
--   "Repair" le trou se referme : vitre rendue, FX_ShopGlass_Reform.
--
-- API (serveur) :
--   GlassThrowService.IsEnabled() -> boolean
--   GlassThrowService.Throw(hitter, target, plot, bounds, onDone?) -> boolean   false : rien n'est fait (refus)
--   GlassThrowService.IsThrown(player) -> boolean                              en vol ou au sol avant le relevé
--   GlassThrowService.GetHole(pane) -> (Vector3?, number?)                     trou ouvert : centre, fin (os.clock)

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local GlassThrow = require(Shared.Config.GlassThrow)
local ShopGlass = require(Shared.ShopGlass)
local Net = require(Shared.Net.Net)
local Ragdoll = require(Shared.Ragdoll) -- a503 : ragdoll commun avec BatService
-- Config/ProductIds chargé s'il est là (comme TrapService, a296) ; sans lui, IsDev faux (PROD).
local ProductIds: { IsDev: boolean? } = (function(): any
	local module = Shared.Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end)()

local AntiCheatService = require(script.Parent.AntiCheatService)
local PlotService = require(script.Parent.PlotService)

local IS_STUDIO = RunService:IsStudio()
local DEFAULT_GROUP = "Default"
local PART_NAME = "GlassThrow" -- Attachment, LinearVelocity et pièces du ragdoll posés par ce service
local LAND_LIFT = 0.2
-- Réglages du ragdoll (Shared/Ragdoll) : ceux de Config/GlassThrow, sous le nom PART_NAME (comme avant a503).
local RAGDOLL_SETTINGS: Ragdoll.Settings = {
	Name = PART_NAME,
	UpperAngle = GlassThrow.RagdollUpperAngle,
	Twist = GlassThrow.RagdollTwist,
}

type Joint = Ragdoll.Joint

type Throw = {
	Victim: Player,
	Hitter: Player,
	Plot: Model,
	Bounds: BasePart,
	Choice: ShopGlass.Choice,
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Started: number,
	Crossed: boolean,
	Pushing: boolean,
	Done: boolean,
	Groups: { [BasePart]: string },
	Collide: { [BasePart]: boolean },
	Barriers: { BasePart },
	Joints: { Joint },
	Push: { Instance },
	PlatformStand: boolean,
	OnDone: ((outside: boolean) -> ())?,
}

type Hole = { Point: Vector3, Until: number }

local GlassThrowService = {}
GlassThrowService.Priority = 115 -- avant PvPService (120), qui l'appelle

local throws: { [Player]: Throw } = {}
local holes: { [BasePart]: Hole } = {}
local barrierUse: { [BasePart]: { Saved: string, Count: number } } = {}
local warned: { [string]: boolean } = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[GlassThrowService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[GlassThrowService] {message}`)
	end
end

function GlassThrowService.IsEnabled(): boolean
	return Features.ShopGlassThrow == true or (Features.ShopGlassThrowDev == true and ProductIds.IsDev == true)
end

function GlassThrowService.IsThrown(player: Player): boolean
	return throws[player] ~= nil
end

function GlassThrowService.GetHole(pane: BasePart): (Vector3?, number?)
	local hole = holes[pane]
	if hole == nil then
		return nil, nil
	end
	return hole.Point, hole.Until
end

local function fire(kind: string, choice: ShopGlass.Choice, point: Vector3, victim: Player?, hitter: Player?, fresh: boolean?)
	Net.Server.GlassThrow:FireAll(kind, choice.Pane, point, choice.Direction, victim, hitter, fresh)
end

-- Groupes de collision ------------------------------------------------------------------------------------------

-- Les deux groupes, avec les règles de « Default » envers tous les groupes déjà déclarés ; seuls GroupThrown et
-- GroupBarrier ne se heurtent pas. Refait à chaque vol (un service peut avoir déclaré un groupe depuis).
local function setupGroups(): boolean
	local thrown, barrier = GlassThrow.GroupThrown, GlassThrow.GroupBarrier
	local ok, err = pcall(function()
		for _, name in { thrown, barrier } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
		for _, info in PhysicsService:GetRegisteredCollisionGroups() do
			local other = info.name
			if other == thrown or other == barrier then
				continue
			end
			local collides = PhysicsService:CollisionGroupsAreCollidable(DEFAULT_GROUP, other)
			PhysicsService:CollisionGroupSetCollidable(thrown, other, collides)
			PhysicsService:CollisionGroupSetCollidable(barrier, other, collides)
		end
		local same = PhysicsService:CollisionGroupsAreCollidable(DEFAULT_GROUP, DEFAULT_GROUP)
		PhysicsService:CollisionGroupSetCollidable(thrown, thrown, same)
		PhysicsService:CollisionGroupSetCollidable(barrier, barrier, same)
		PhysicsService:CollisionGroupSetCollidable(thrown, barrier, false)
	end)
	if not ok then
		warnOnce("groups", `groupes de collision impossibles ({err}) : le corps projeté sera arrêté par PlotBarrier`)
	end
	return ok
end

local function barrierParts(plot: Model): { BasePart }
	local parts: { BasePart } = {}
	local names = GlassThrow.BarrierContainers
	for _, instance in plot:GetDescendants() do
		if table.find(names, instance.Name) == nil then
			continue
		end
		if instance:IsA("BasePart") then
			table.insert(parts, instance :: BasePart)
		end
		for _, part in instance:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part :: BasePart)
			end
		end
	end
	return parts
end

-- Murs de la boutique dans GroupBarrier (comptés : plusieurs vols en même temps). Seuls ceux de « Default ».
local function takeBarriers(plot: Model): { BasePart }
	local taken: { BasePart } = {}
	for _, part in barrierParts(plot) do
		local use = barrierUse[part]
		if use == nil then
			if part.CollisionGroup ~= DEFAULT_GROUP then
				warnOnce(`barrier:{part:GetFullName()}`, `{part:GetFullName()} est dans le groupe {part.CollisionGroup} : pas traversé`)
				continue
			end
			use = { Saved = part.CollisionGroup, Count = 0 }
			barrierUse[part] = use
			part.CollisionGroup = GlassThrow.GroupBarrier
		end
		use.Count += 1
		table.insert(taken, part)
	end
	return taken
end

local function releaseBarriers(parts: { BasePart })
	for _, part in parts do
		local use = barrierUse[part]
		if use == nil then
			continue
		end
		use.Count -= 1
		if use.Count <= 0 then
			barrierUse[part] = nil
			if part.Parent ~= nil and part.CollisionGroup == GlassThrow.GroupBarrier then
				part.CollisionGroup = use.Saved
			end
		end
	end
end

-- Ragdoll -------------------------------------------------------------------------------------------------------

-- a503 : le ragdoll est dans Shared/Ragdoll (commun avec BatService), sorti tel quel d'ici.
local function ragdoll(throw: Throw)
	if not GlassThrow.Ragdoll then
		return
	end
	Ragdoll.Apply(throw.Character, throw.Root, RAGDOLL_SETTINGS, throw)
end

local function unragdoll(throw: Throw)
	Ragdoll.Restore(throw)
end

local function setOwner(character: Model, owner: Player?)
	Ragdoll.SetOwner(character, owner)
end

-- Poussée -------------------------------------------------------------------------------------------------------

local function stopPush(throw: Throw)
	if not throw.Pushing then
		return
	end
	throw.Pushing = false
	for _, instance in throw.Push do
		instance:Destroy()
	end
	table.clear(throw.Push)
end

local function startPush(throw: Throw)
	local root = throw.Root
	local choice = throw.Choice
	local speed = GlassThrow.Speed
	local horizontal = choice.Direction * speed
	-- Vitesse verticale pour passer le plan de la vitre à la hauteur du trou (chute libre, Workspace.Gravity).
	local up = throw.Bounds.CFrame.UpVector
	local frame = choice.Frame
	local toPlane = (choice.Point - root.Position):Dot(frame.N)
	local along = choice.Direction:Dot(frame.N)
	local t1 = if along > 1e-3 then math.max(toPlane / along / speed, 0.05) else 0.2
	local rise = (choice.Point - root.Position):Dot(up)
	local gravity = Workspace.Gravity
	local vy = math.clamp((rise + 0.5 * gravity * t1 * t1) / t1, GlassThrow.MinLift, GlassThrow.MaxLift)

	local attachment = Instance.new("Attachment")
	attachment.Name = PART_NAME
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = PART_NAME
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	local a = choice.Direction
	local b = up:Cross(a)
	velocity.PrimaryTangentAxis = a
	velocity.SecondaryTangentAxis = b
	velocity.PlaneVelocity = Vector2.new(speed, 0)
	velocity.MaxForce = math.huge
	velocity.Parent = root
	throw.Push = { velocity, attachment }
	throw.Pushing = true
	root.AssemblyLinearVelocity = horizontal + up * vy
end

-- Trou ----------------------------------------------------------------------------------------------------------

local function scheduleRepair(pane: BasePart, hole: Hole, choice: ShopGlass.Choice)
	task.delay(math.max(hole.Until - os.clock(), 0), function()
		if holes[pane] ~= hole then
			return
		end
		if os.clock() + 1e-6 < hole.Until then
			scheduleRepair(pane, hole, choice) -- prolongé par une autre projection
			return
		end
		holes[pane] = nil
		fire("Repair", choice, hole.Point, nil, nil, nil)
		log(`{pane:GetFullName()} réparée`)
	end)
end

local function openHole(throw: Throw)
	if throw.Crossed then
		return
	end
	throw.Crossed = true
	local choice = throw.Choice
	local pane = choice.Pane
	local hole = holes[pane]
	local fresh = hole == nil
	if hole == nil then
		local made: Hole = { Point = choice.Point, Until = os.clock() + GlassThrow.HoleDuration }
		holes[pane] = made
		scheduleRepair(pane, made, choice)
		hole = made
	else
		hole.Until = math.max(hole.Until, os.clock() + GlassThrow.HoleDuration)
	end
	fire("Hole", choice, (hole :: Hole).Point, throw.Victim, throw.Hitter, fresh)
	log(`{throw.Victim.Name} passe {pane.Name} ({choice.Side}{if fresh then "" else ", trou déjà ouvert"})`)
end

-- Fin du vol ----------------------------------------------------------------------------------------------------

local function restoreGroups(throw: Throw)
	for part, group in throw.Groups do
		if part.Parent ~= nil and part.CollisionGroup == GlassThrow.GroupThrown then
			part.CollisionGroup = group
		end
	end
	table.clear(throw.Groups)
	releaseBarriers(throw.Barriers)
	table.clear(throw.Barriers)
end

-- Fin du vol : `landed` = relevé normal (sinon mort, départ, personnage changé).
local function finish(throw: Throw, landed: boolean)
	if throw.Done then
		return
	end
	throw.Done = true
	if throws[throw.Victim] == throw then
		throws[throw.Victim] = nil
	end
	stopPush(throw)
	unragdoll(throw)
	restoreGroups(throw)
	local alive = throw.Character.Parent ~= nil and throw.Humanoid.Health > 0
	if alive then
		throw.Humanoid.PlatformStand = throw.PlatformStand
	end
	if landed and alive and throw.Victim.Parent == Players then
		-- Debout, face au sens du vol, les pieds au sol.
		local root = throw.Root
		local up = throw.Bounds.CFrame.UpVector
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { throw.Character }
		local hit = Workspace:Raycast(root.Position + up * 2, -up * 30, params)
		local hip = if throw.Humanoid.RigType == Enum.HumanoidRigType.R15 then throw.Humanoid.HipHeight else 2
		local position = if hit then hit.Position + up * (hip + root.Size.Y / 2 + LAND_LIFT) else root.Position
		local look = throw.Choice.Direction
		AntiCheatService.Allow(throw.Victim, 0, "GlassThrowService (relevé)")
		local target = CFrame.lookAt(position, position + look, up)
		throw.Character:PivotTo(target * root.CFrame:ToObjectSpace(throw.Character:GetPivot()))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		pcall(function()
			throw.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
	if throw.Character.Parent ~= nil then
		setOwner(throw.Character, if throw.Victim.Parent == Players then throw.Victim else nil)
	end
	if landed then
		fire("Land", throw.Choice, throw.Root.Position, throw.Victim, throw.Hitter, nil)
	end
	local outside = not ShopGlass.Inside(throw.Bounds, throw.Root.Position)
	local onDone = throw.OnDone
	if onDone then
		task.spawn(onDone, outside)
	end
end

local function step(throw: Throw)
	if throw.Done then
		return
	end
	local root = throw.Root
	if root.Parent == nil or throw.Humanoid.Health <= 0 or throw.Victim.Character ~= throw.Character then
		finish(throw, false)
		return
	end
	local elapsed = os.clock() - throw.Started
	local choice = throw.Choice
	if not throw.Crossed and (root.Position - choice.Point):Dot(choice.Frame.N) >= 0 then
		openHole(throw)
	end
	if throw.Pushing then
		local out = ShopGlass.OutsideBy(throw.Bounds, root.Position) >= GlassThrow.ClearMargin
		if (throw.Crossed and out) or elapsed >= GlassThrow.MaxPushTime then
			stopPush(throw)
			openHole(throw) -- bloqué avant la vitre : le trou s'ouvre quand même (même image pour tous)
		end
	end
	if elapsed >= GlassThrow.RagdollTime then
		finish(throw, true)
	end
end

-- API -----------------------------------------------------------------------------------------------------------

local function bodyOf(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root :: BasePart, humanoid
end

-- Projette `target`, frappé par `hitter` dans la boutique `plot` (volume `bounds`). Refus (false, rien n'est
-- fait) : interrupteur éteint, `hitter` pas propriétaire de `plot`, `target` pas dans Bounds, déjà en vol, aucune
-- vitre qui donne dehors. `onDone(dehors)` est appelé au relevé (ou à la fin du vol interrompu).
function GlassThrowService.Throw(
	hitter: Player,
	target: Player,
	plot: Model,
	bounds: BasePart,
	onDone: ((outside: boolean) -> ())?
): boolean
	if not GlassThrowService.IsEnabled() then
		return false
	end
	if hitter == target or throws[target] ~= nil or PlotService.GetOwner(plot) ~= hitter then
		return false
	end
	local character, root, humanoid = bodyOf(target)
	local _, hitterRoot = bodyOf(hitter)
	if character == nil or root == nil or humanoid == nil or hitterRoot == nil then
		return false
	end
	if not ShopGlass.Inside(bounds, root.Position) then
		return false
	end
	local direction = root.Position - hitterRoot.Position
	local up = bounds.CFrame.UpVector
	if (direction - up * direction:Dot(up)).Magnitude < 1e-3 then
		direction = hitterRoot.CFrame.LookVector
	end
	local panes = ShopGlass.Collect(plot, CollectionService:GetTagged(ShopGlass.Tag))
	local open: { [BasePart]: Vector3 } = {}
	for pane, hole in holes do
		open[pane] = hole.Point
	end
	local choice = ShopGlass.Choose(bounds, panes, root.Position, direction, GlassThrow, open)
	if choice == nil then
		warnOnce(`panes:{plot:GetFullName()}`, `{plot:GetFullName()} : aucune vitre qui donne dehors, sortie devant la porte`)
		return false
	end

	local throw: Throw = {
		Victim = target,
		Hitter = hitter,
		Plot = plot,
		Bounds = bounds,
		Choice = choice,
		Character = character,
		Root = root,
		Humanoid = humanoid,
		Started = os.clock(),
		Crossed = false,
		Pushing = false,
		Done = false,
		Groups = {},
		Collide = {},
		Barriers = {},
		Joints = {},
		Push = {},
		PlatformStand = humanoid.PlatformStand,
		OnDone = onDone,
	}
	throws[target] = throw
	AntiCheatService.Allow(target, GlassThrow.RagdollTime + 0.5, "GlassThrowService (projection à travers la vitre)")
	if setupGroups() then
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				local p = part :: BasePart
				throw.Groups[p] = p.CollisionGroup
				p.CollisionGroup = GlassThrow.GroupThrown
			end
		end
		throw.Barriers = takeBarriers(plot)
	end
	ragdoll(throw)
	humanoid.PlatformStand = true
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end)
	setOwner(character, nil)
	startPush(throw)
	fire("Throw", choice, choice.Point, target, hitter, nil)
	log(`{hitter.Name} projette {target.Name} vers {choice.Pane.Name} ({choice.Side}, {if choice.ByRay then "sens du coup" else "la plus proche"})`)
	step(throw)
	return true
end

function GlassThrowService.Init() end

function GlassThrowService.Start()
	RunService.Heartbeat:Connect(function()
		for _, throw in table.clone(throws) do
			step(throw)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local throw = throws[player]
		if throw then
			finish(throw, false)
		end
	end)
end

return GlassThrowService
