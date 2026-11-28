--!strict
-- Guard/CatchRagdoll (serveur, a518, 27/11 ; liaison L-426) : module d'aide de GuardService (sous-dossier : le Loader ne
-- le démarre pas). Interrupteur Features.GuardCatchRagdoll (PROD) / GuardCatchRagdollDev (DEV et TEST) ; valeurs :
-- Config/Guards.CatchRagdoll ; articulations : celles de Config/GlassThrow (RagdollUpperAngle, RagdollTwist), comme la
-- batte (BatService, a503), avec le ragdoll commun Shared/Ragdoll.
--
-- Clément (25/11) : « quand on se fait attraper par un garde, qu'on se fasse un peu ragdoll assez loin pour qu'un autre
-- joueur puisse récupérer l'objet et que le garde parte de l'objet ; il retourne à sa base et si jamais on le récupère, il
-- revient ». À la capture par un vigile de magasin (pas la nuit, ni le policier, ni le conducteur), juste après que
-- l'objet est tombé là où le voleur était (CarryService.Fail « Caught ») : le serveur prend le personnage, coupe ses
-- Motor6D (Shared/Ragdoll), lui donne une vitesse à l'opposé du vigile (CatchRagdoll.Speed) et vers le haut (AirTime s
-- en l'air sur sol plat, Workspace.Gravity), chacune réduite pour s'arrêter à WallMargin studs du premier mur ou plafond ;
-- relevé debout, face au vigile, Time s plus tard (Motor6D, CanCollide, PlatformStand et propriétaire réseau rendus).
-- L'étourdissement (Balance.Guard.CatchStunDuration) et la mise en scène (CatchScene) ne changent pas. L'Attachment
-- GuardKnockback est posé comme avant (sans poussée) : son client joue Knockback puis Stunned (ChaseController).
-- Le retour du vigile (CatchRagdoll.GuardReturns) est décidé par GuardService à la fin de Catch.
-- a537 (L-501, Clément 28/11 « Ragdoll seul », Features.GuardCatchRagdollOnly / …Dev) : l'Attachment porte l'attribut
-- RagdollOnly (posé avant d'entrer dans le personnage, il arrive avec lui chez le client) ; ChaseController ne joue alors
-- pas Knockdown, et joue GetUp quand l'Attachment s'en va, retiré au relevé APRÈS que les Motor6D sont remis.
-- GuardService n'envoie pas non plus la mise en scène (CatchScene).
--
-- API :
--   CatchRagdoll.On() -> boolean
--   CatchRagdoll.GuardReturns() -> boolean          à la fin de Catch, il rentre au lieu de garder l'objet tombé
--   CatchRagdoll.RagdollOnly() -> boolean           a537 : à la capture en ragdoll, ni Knockdown ni CatchScene
--   CatchRagdoll.Throw(player, from, antiCheat, cue) -> boolean   false : rien fait (module, personnage, déjà au sol)
--   CatchRagdoll.IsDown(player) -> boolean

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = (ReplicatedStorage :: any).Shared
local Guards = require(Shared.Config.Guards) :: any
local GlassThrow = require(Shared.Config.GlassThrow) :: any
local Ragdoll = require(Shared.Ragdoll) :: any
local Switch = require(script.Parent.Switch) :: any

local SWITCH = "GuardCatchRagdoll"
local ONLY_SWITCH = "GuardCatchRagdollOnly" -- a537 (L-501)
local ONLY_ATTRIBUTE = "RagdollOnly" -- a537 : même nom dans ChaseController (client)
local RAGDOLL_NAME = "GuardRagdoll" -- pièces posées par Shared/Ragdoll pour ce module
local ACTIVE_GUARDS = "ActiveGuards" -- vigiles en jeu (GuardService), ignorés par les rayons
local DEFAULT_GRAVITY = 196.2 -- Workspace.Gravity illisible (faux Roblox)
local LAND_LIFT = 0.2 -- relevé posé LAND_LIFT studs au-dessus du sol (comme BatService)
local LAND_RAY_DOWN = 30

type Down = {
	Player: Player,
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Joints: { any },
	Collide: { [BasePart]: boolean },
	PlatformStand: boolean,
	Look: Vector3,
	Cue: Instance?, -- a537 : signal du client, retiré au relevé (après les Motor6D)
}

local down: { [Player]: Down } = {}

local CatchRagdoll = {}

local function cfg(): any
	return Guards.CatchRagdoll
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function gravity(): number
	local ok, g = pcall(function(): number
		return Workspace.Gravity
	end)
	return if ok and type(g) == "number" and g > 0 then g else DEFAULT_GRAVITY
end

local function rayParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list: { Instance } = { character }
	local guards = Workspace:FindFirstChild(ACTIVE_GUARDS)
	if guards then
		table.insert(list, guards)
	end
	params.FilterDescendantsInstances = list
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local function obstacle(origin: Vector3, ray: Vector3, params: RaycastParams): number?
	local hit = Workspace:Raycast(origin, ray, params)
	return if hit then (hit.Position - origin).Magnitude else nil
end

-- Vitesse de la projection : Speed à l'horizontale, et vers le haut de quoi rester AirTime s en l'air sur sol plat ;
-- chacune réduite pour s'arrêter à WallMargin du premier mur ou plafond (même calcul que la batte, a503).
function CatchRagdoll.Velocity(root: BasePart, direction: Vector3, params: RaycastParams): Vector3
	local c = cfg()
	local g = gravity()
	local air = math.max(c.AirTime, 1e-3)
	local margin = c.WallMargin
	local speed = c.Speed
	local wall = if speed > 0 then obstacle(root.Position, direction * (speed * air + margin), params) else nil
	if wall then
		speed = math.max(wall - margin, 0) / air
	end
	local up = g * air / 2
	local peak = up * up / (2 * g)
	local ceiling = if peak > 0 then obstacle(root.Position, Vector3.new(0, peak + margin, 0), params) else nil
	if ceiling then
		up = math.sqrt(2 * g * math.max(ceiling - margin, 0))
	end
	return direction * speed + Vector3.new(0, up, 0)
end

function CatchRagdoll.On(): boolean
	return Switch.On(SWITCH)
end

function CatchRagdoll.GuardReturns(): boolean
	return CatchRagdoll.On() and cfg().GuardReturns == true
end

function CatchRagdoll.RagdollOnly(): boolean
	return CatchRagdoll.On() and Switch.On(ONLY_SWITCH)
end

function CatchRagdoll.IsDown(player: Player): boolean
	return down[player] ~= nil
end

-- Relevé (`landed`) ou fin interrompue (mort, départ, personnage changé) : tout est rendu comme avant.
local function standUp(state: Down, landed: boolean, antiCheat: any)
	if down[state.Player] ~= state then
		return
	end
	down[state.Player] = nil
	local player, character, root, humanoid = state.Player, state.Character, state.Root, state.Humanoid
	Ragdoll.Restore(state)
	local alive = character.Parent ~= nil and humanoid.Health > 0
	if alive then
		humanoid.PlatformStand = state.PlatformStand
	end
	if landed and alive and player.Parent == Players and player.Character == character then
		local ground = Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -LAND_RAY_DOWN, 0), rayParams(character))
		local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
		local position = if ground then ground.Position + Vector3.new(0, hip + root.Size.Y / 2 + LAND_LIFT, 0) else root.Position
		if antiCheat then
			pcall(antiCheat.Allow, player, 0, "GuardService (relevé du ragdoll de la capture)")
		end
		local look = if state.Look.Magnitude > 1e-3 then state.Look else Vector3.new(0, 0, -1)
		character:PivotTo(CFrame.lookAt(position, position + look) * root.CFrame:ToObjectSpace(character:GetPivot()))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
	if character.Parent ~= nil then
		Ragdoll.SetOwner(character, if player.Parent == Players then player else nil)
	end
	local cue = state.Cue
	if cue then
		state.Cue = nil
		cue:Destroy() -- a537 : le client joue GetUp à ce moment (RagdollOnly), Motor6D déjà remis
	end
end

-- Le voleur attrapé part en ragdoll à l'opposé de `from` (la place du vigile). `cue` : nom de l'Attachment posé dans
-- son HumanoidRootPart pour son client (GuardKnockback), retiré au relevé.
function CatchRagdoll.Throw(player: Player, from: Vector3, antiCheat: any, cue: string?): boolean
	local character = player.Character
	if character == nil or down[player] ~= nil or player.Parent ~= Players then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local body = root :: BasePart
	local away = flat(body.Position - from)
	if away.Magnitude < 1e-3 then
		away = flat(body.CFrame.LookVector)
	end
	local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(0, 0, 1)
	local c = cfg()
	local state: Down = {
		Player = player,
		Character = character,
		Root = body,
		Humanoid = humanoid,
		Joints = {},
		Collide = {},
		PlatformStand = humanoid.PlatformStand,
		Look = -direction,
	}
	down[player] = state
	if antiCheat then
		pcall(antiCheat.Allow, player, c.Time + 0.5, "GuardService (ragdoll de la capture)") -- déplacement du code (DEV-060)
	end
	Ragdoll.Apply(character, body, {
		Name = RAGDOLL_NAME,
		UpperAngle = GlassThrow.RagdollUpperAngle,
		Twist = GlassThrow.RagdollTwist,
	}, state)
	humanoid.PlatformStand = true
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end)
	Ragdoll.SetOwner(character, nil) -- le serveur simule le vol
	local velocity = CatchRagdoll.Velocity(body, direction, rayParams(character))
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not (part :: BasePart).Anchored then
			(part :: BasePart).AssemblyLinearVelocity = velocity
		end
	end
	if cue then
		local signal = Instance.new("Attachment")
		signal.Name = cue
		if CatchRagdoll.RagdollOnly() then
			signal:SetAttribute(ONLY_ATTRIBUTE, true)
		end
		signal.Parent = body
		state.Cue = signal -- retiré par standUp (relevé, mort, départ), après les Motor6D
	end
	task.delay(c.Time, function()
		standUp(state, true, antiCheat)
	end)
	return true
end

Players.PlayerRemoving:Connect(function(player: Player)
	local state = down[player]
	if state then
		standUp(state, false, nil)
	end
end)

return CatchRagdoll
