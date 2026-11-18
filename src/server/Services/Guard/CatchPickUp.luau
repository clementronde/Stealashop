--!strict
-- Guard/CatchPickUp (serveur, a252 ; liaison L-244, Clément 2026-11-18 : « on voit notre personnage tomber, et après le
-- vigile récupère l'objet ») : module d'aide de GuardService (sous-dossier : le Loader ne le démarre pas). Valeurs :
-- Config/Chase.CatchPickUp (interrupteur Enabled). Aucune règle de jeu ne change : l'objet revole sur son rayon comme
-- avant (CarryService.FailNoDrop « Caught »), seulement plus tard, depuis la main du vigile.
--
-- Déroulé, pour le vigile d'un magasin PNJ qui attrape un porteur d'objet NPCItem dont l'objet revole sur son rayon
-- (capture dans son magasin, ou Chase.ReturnToShelfAfterCatches-ième capture ; toutes les captures avec Always) :
--   1. Begin, à la capture : le portage continue (le joueur est déjà immobilisé) ; attribut CatchPickUp = true sur le
--      Player (ChaseController : le joueur reste au sol tant qu'il est là).
--   2. Impact, au coup (marqueur Impact de Catch, ou délai de secours) : le visuel porté (CarryVisual) quitte la tête du
--      joueur et tombe au sol en FallTime s, à Reach studs devant le vigile, vers le joueur. PickUpDelay s après le coup,
--      le vigile se tourne vers l'objet et joue PickUp.
--   3. Au marqueur Grab de PickUp (sans lui : à la fin de PickUp ; sans PickUp : GrabFallback s), l'objet passe dans sa
--      main droite (réduit à HandMaxSize studs s'il est plus grand) et le suit HoldTime s.
--   4. Fin : payload.ReturnFrom = position de l'objet (StoreHeistService le fait revoler de là), FailNoDrop, attribut
--      retiré (le joueur se relève : GetUp). Au plus tard MaxAfterImpact s après le coup, ou MaxAfterCatch s après la
--      capture sans coup (joueur protégé par sa cinématique) : jamais après la fin de l'étourdissement (2,4 s).
--   Portage fini autrement entre-temps (mort, départ, coup de batte) : CarryService a déjà détruit le visuel ; la fin
--   ne fait plus rien. Vigile retiré entre-temps : l'objet revole de là où il est.
--
-- API :
--   CatchPickUp.Attribute                                    nom de l'attribut du Player (« CatchPickUp »)
--   CatchPickUp.Wants(player, backToShelf, carry) -> boolean  ce porteur doit-il passer par la main du vigile ?
--   CatchPickUp.Begin(player, guard, carry) -> boolean        à la capture (guard : voir GuardInfo)
--   CatchPickUp.Impact(player)                                au coup
--   CatchPickUp.NightSendHome(player, hooks, root) -> ((Player) -> boolean)?   L-245 : renvoi après une capture de nuit
--   CatchPickUp.IsPending(player) -> boolean ; CatchPickUp.GetState() -> { Pending, Done, Grabbed, LastFrom }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Chase = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Chase")) :: any

export type CarryApi = {
	IsCarrying: (player: Player) -> boolean,
	GetPayload: (player: Player) -> any,
	FailNoDrop: (player: Player, reason: string) -> boolean,
}

-- Ce que GuardService donne du vigile.
export type GuardInfo = {
	model: Model,
	root: BasePart,
	play: (name: string) -> AnimationTrack?, -- guard.anims:Play
	extend: (untilClock: number) -> (), -- garde le vigile dans l'état Catch jusque-là
}

export type NightHooks = {
	InCorridor: (position: Vector3) -> boolean,
	SendHome: (player: Player) -> boolean,
}

type Pending = {
	token: number,
	player: Player,
	guard: GuardInfo,
	carry: CarryApi,
	visual: Model?,
	impacted: boolean,
	grabbed: boolean,
	done: boolean,
	connections: { RBXScriptConnection },
}

local VISUAL_NAME = "CarryVisual" -- CarryService
local CAUGHT = "Caught"
local PICKUP = "PickUp"
local GRAB = "Grab"
local IS_STUDIO = RunService:IsStudio()

local CatchPickUp = {}
CatchPickUp.Attribute = "CatchPickUp"

local pending: { [Player]: Pending } = {}
local counter = 0
local stats = { Done = 0, Grabbed = 0, LastFrom = nil :: Vector3? }

local function cfg(): any
	local value = Chase.CatchPickUp
	return if type(value) == "table" then value else nil
end

local function number(value: any, default: number): number
	return if type(value) == "number" and value == value then value else default
end

local function log(message: string)
	if IS_STUDIO then
		print(`[CatchPickUp] {message}`)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function CatchPickUp.Wants(player: Player, backToShelf: boolean, carry: CarryApi): boolean
	local c = cfg()
	if c == nil or c.Enabled ~= true then
		return false
	end
	if not backToShelf and c.Always ~= true then
		return false
	end
	local ok, payload = pcall(carry.GetPayload, player)
	return ok and type(payload) == "table" and payload.Kind == "NPCItem"
end

function CatchPickUp.IsPending(player: Player): boolean
	return pending[player] ~= nil
end

-- Fin : l'objet revole depuis là où il est (CarryService.FailNoDrop). Une seule fois.
local function finish(p: Pending, why: string)
	if p.done then
		return
	end
	p.done = true
	if pending[p.player] == p then
		pending[p.player] = nil
	end
	for _, connection in p.connections do
		connection:Disconnect()
	end
	pcall(function()
		p.player:SetAttribute(CatchPickUp.Attribute, nil)
	end)
	local from: Vector3? = nil
	local visual = p.visual
	if visual and visual.Parent ~= nil then
		local model: Model = visual
		local ok, box = pcall(function(): CFrame
			return (model:GetBoundingBox())
		end)
		if ok then
			from = box.Position
		end
	end
	local okPayload, payload = pcall(p.carry.GetPayload, p.player)
	local bag: any = if okPayload and type(payload) == "table" then payload else nil
	if bag and from then
		bag.ReturnFrom = from -- lu (et effacé) par StoreHeistService à la fin du portage
	end
	stats.Done += 1
	stats.LastFrom = from
	local ok, result = pcall(p.carry.FailNoDrop, p.player, CAUGHT)
	if bag then
		bag.ReturnFrom = nil
	end
	if not ok then
		warn(`[CatchPickUp] FailNoDrop({p.player.Name}) : {result}`)
	end
	log(`{p.player.Name} : l'objet revole sur son rayon ({why}{if p.grabbed then ", depuis la main du vigile" else ""})`)
end

local function later(p: Pending, delay: number, fn: () -> ())
	local token = p.token
	task.delay(math.max(delay, 0), function()
		if not p.done and p.token == token then
			fn()
		end
	end)
end

function CatchPickUp.Begin(player: Player, guard: GuardInfo, carry: CarryApi): boolean
	local previous = pending[player]
	if previous then
		finish(previous, "nouvelle capture")
	end
	counter += 1
	local p: Pending = {
		token = counter,
		player = player,
		guard = guard,
		carry = carry,
		visual = nil,
		impacted = false,
		grabbed = false,
		done = false,
		connections = {},
	}
	pending[player] = p
	pcall(function()
		player:SetAttribute(CatchPickUp.Attribute, true)
	end)
	local c = cfg() or {}
	later(p, number(c.MaxAfterCatch, 2.2), function()
		if not p.impacted then
			finish(p, "sans coup")
		end
	end)
	return true
end

-- Le visuel porté quitte la tête du joueur : soudures vers le personnage retirées, pièces ancrées et sans collision,
-- rangé dans Workspace (CarryService le détruit toujours à la fin du portage, où qu'il soit).
local function detach(player: Player): Model?
	local character = player.Character
	local found = if character then character:FindFirstChild(VISUAL_NAME) else nil
	if found == nil or not found:IsA("Model") then
		return nil
	end
	local model = found :: Model
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a = (d :: any).Part0
			local b = (d :: any).Part1
			if (a and not a:IsDescendantOf(model)) or (b and not b:IsDescendantOf(model)) then
				d:Destroy()
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	model.Parent = Workspace
	return model
end

-- Point de chute : Reach studs devant le vigile, vers le joueur, posé sur le sol (lancer de rayon vers le bas).
local function dropPoint(p: Pending, model: Model): Vector3
	local c = cfg() or {}
	local guardRoot = p.guard.root
	local from = guardRoot.Position
	local body = rootOf(p.player)
	local toward = if body then flat(body.Position - from) else Vector3.zero
	if toward.Magnitude < 1e-3 then
		toward = flat(guardRoot.CFrame.LookVector)
	end
	local dir = if toward.Magnitude > 1e-3 then toward.Unit else Vector3.new(0, 0, -1)
	local reach = math.min(number(c.Reach, 2.5), if body then toward.Magnitude else math.huge)
	local point = from + dir * reach
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { model, p.guard.model }
	if p.player.Character then
		table.insert(exclude, p.player.Character :: Instance)
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
	local floorY = if hit then hit.Position.Y else from.Y - 3
	return Vector3.new(point.X, floorY, point.Z)
end

local function fall(p: Pending, model: Model)
	local c = cfg() or {}
	local duration = math.max(number(c.FallTime, 0.3), 0.01)
	local arc = number(c.FallArc, 1.5)
	local start = model:GetPivot()
	local box, size = model:GetBoundingBox()
	local lift = start.Position.Y - (box.Position.Y - size.Y / 2) -- du bas de l'objet à son pivot
	local ground = dropPoint(p, model)
	local goal = Vector3.new(ground.X, ground.Y + lift, ground.Z)
	local spin = CFrame.Angles(0, math.rad(90), 0)
	local t = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if p.done or p.grabbed or model.Parent == nil then
			connection:Disconnect()
			return
		end
		t = math.min(t + dt, duration)
		local a = t / duration
		local position = start.Position:Lerp(goal, a) + Vector3.new(0, arc * 4 * a * (1 - a), 0)
		model:PivotTo(CFrame.new(position) * start.Rotation:Lerp(start.Rotation * spin, a))
		if a >= 1 then
			connection:Disconnect()
		end
	end)
	table.insert(p.connections, connection)
end

local function handOf(guard: GuardInfo): BasePart
	for _, name in { "RightHand", "Right Arm", "RightLowerArm" } do
		local part = guard.model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return guard.root
end

local function grab(p: Pending)
	if p.grabbed then
		return
	end
	p.grabbed = true
	stats.Grabbed += 1
	local c = cfg() or {}
	local model = p.visual
	if model and model.Parent ~= nil and p.guard.model.Parent ~= nil then
		local hand = handOf(p.guard)
		local maxSize = number(c.HandMaxSize, 3)
		local extents = model:GetExtentsSize()
		local biggest = math.max(extents.X, extents.Y, extents.Z)
		if maxSize > 0 and biggest > maxSize then
			pcall(function()
				model:ScaleTo(model:GetScale() * maxSize / biggest)
			end)
		end
		local box, size = model:GetBoundingBox()
		local pivotFromBox = box:ToObjectSpace(model:GetPivot())
		local function follow()
			if not hand.Parent or not model.Parent then
				return
			end
			local center = hand.CFrame * CFrame.new(0, -(hand.Size.Y / 2 + size.Y / 2), 0)
			model:PivotTo(center * pivotFromBox)
		end
		follow()
		table.insert(p.connections, RunService.Heartbeat:Connect(follow))
	end
	later(p, number(c.HoldTime, 0.4), function()
		finish(p, "tenu")
	end)
end

function CatchPickUp.Impact(player: Player)
	local p = pending[player]
	if p == nil or p.impacted then
		return
	end
	p.impacted = true
	local c = cfg() or {}
	later(p, number(c.MaxAfterImpact, 1.6), function()
		finish(p, "délai")
	end)
	local okDetach, model = pcall(detach, player)
	p.visual = if okDetach then model else nil
	if p.visual then
		local falling: Model = p.visual :: Model
		local okFall, err = pcall(function()
			fall(p, falling)
		end)
		if not okFall then
			warn(`[CatchPickUp] chute de l'objet de {player.Name} : {err}`)
		end
	end
	later(p, number(c.PickUpDelay, 0.2), function()
		local guard = p.guard
		if guard.model.Parent == nil then
			finish(p, "vigile retiré")
			return
		end
		local root = guard.root
		local visual = p.visual
		local target = if visual and visual.Parent ~= nil then visual:GetPivot().Position else nil
		if target then
			local look = flat(target - root.Position)
			if look.Magnitude > 1e-3 then
				pcall(function()
					root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
				end)
			end
		end
		local okPlay, track = pcall(guard.play, PICKUP)
		local played: AnimationTrack? = if okPlay then track else nil
		local fallback = number(c.GrabFallback, 0.5)
		local hold = number(c.HoldTime, 0.4)
		if played then
			local length = played.Length
			table.insert(p.connections, played:GetMarkerReachedSignal(GRAB):Connect(function()
				grab(p)
			end))
			later(p, if length > 0 then length else fallback, function()
				grab(p)
			end)
			guard.extend(os.clock() + (if length > 0 then math.max(length, fallback + hold) else fallback + hold))
		else
			later(p, fallback, function()
				grab(p)
			end)
			guard.extend(os.clock() + fallback + hold)
		end
	end)
	log(`{player.Name} : l'objet tombe, le vigile le ramasse`)
end

-- L-245 : capture par le vigile d'un magasin, la nuit (hooks de NightCycleService présents), joueur dans le couloir :
-- la fonction de renvoi à la boutique, si Chase.DayCatchAtNightSendsHome ; nil sinon.
function CatchPickUp.NightSendHome(player: Player, hooks: NightHooks?, position: Vector3?): ((player: Player) -> boolean)?
	if Chase.DayCatchAtNightSendsHome ~= true or hooks == nil then
		return nil
	end
	local where = position
	if where == nil then
		local root = rootOf(player)
		where = if root then root.Position else nil
	end
	if where == nil then
		return nil
	end
	local ok, inside = pcall(hooks.InCorridor, where)
	if not ok or inside ~= true then
		return nil
	end
	return hooks.SendHome
end

function CatchPickUp.NightSendHomeDelay(): number
	return number(Chase.DayCatchAtNightDelay, 2)
end

function CatchPickUp.GetState(): { Pending: number, Done: number, Grabbed: number, LastFrom: Vector3? }
	local count = 0
	for _ in pending do
		count += 1
	end
	return { Pending = count, Done = stats.Done, Grabbed = stats.Grabbed, LastFrom = stats.LastFrom }
end

Players.PlayerRemoving:Connect(function(player: Player)
	local p = pending[player]
	if p then
		finish(p, "départ")
	end
end)

return CatchPickUp
