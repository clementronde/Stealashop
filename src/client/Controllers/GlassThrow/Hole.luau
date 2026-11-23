--!strict
-- GlassThrow/Hole (a315, L-291) : le trou d'une vitre de boutique traversée par un joueur projeté, dessiné sur ce
-- client seulement (GlassThrowController). La vraie vitre n'est jamais modifiée : elle est cachée en local
-- (LocalTransparencyModifier, réglage d'avant gardé) et une copie givrée prend sa place ; GeometryService:FragmentAsync
-- y découpe le trou (Shared/ShopGlass.Sites : le morceau 1 = le reste de la vitre, givré, les autres = les éclats).
-- Les éclats partent dans le sens du vol, retombent dehors et s'effacent. À la réparation (Repair), tout ce que ce
-- module a créé est retiré et la vraie vitre est remontrée telle qu'elle était.
--
-- API :
--   Hole.Begin(pane, point, direction, settings) -> State
--     tout de suite : la vraie vitre est cachée en local (à garder aussitôt : un second trou ou une réparation
--     peut arriver pendant que FragmentAsync calcule).
--   Hole.Carve(state, settings, fragment, parent, random) -> State
--     la copie givrée trouée et les éclats ; fragment(part, sites) -> { { Instance: Instance, Index: number } }? (GeometryService:FragmentAsync, ou un
--     faux dans les bancs) ; peut attendre. Un échec : la vitre reste cachée jusqu'à la réparation (le corps est
--     passé, pas de verre intact devant lui).
--   Hole.Repair(state)       retire le trou ; la vitre d'origine revient telle quelle.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ShopGlass = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopGlass"))

local UP = Vector3.new(0, 1, 0)

export type Settings = {
	HoleHalfWidth: number,
	HoleHalfHeight: number,
	EdgeMargin: number,
	InnerPoints: number,
	RingPoints: number,
	RingScaleMin: number,
	RingScaleMax: number,
	FarPoints: number,
	FrostColor: Color3,
	FrostMaterial: Enum.Material,
	FrostTransparency: number,
	ShardSpeedMin: number,
	ShardSpeedMax: number,
	ShardUpMin: number,
	ShardUpMax: number,
	ShardSpin: number,
	ShardLife: number,
	ShardFade: number,
}

export type Fragment = (part: BasePart, sites: { any }) -> { any }?

export type State = {
	Pane: BasePart,
	Modifier: number,
	Point: Vector3,
	Direction: Vector3, -- sens du vol, à plat
	Frame: ShopGlass.Frame?,
	HalfWidth: number,
	HalfHeight: number,
	Pieces: { BasePart },
	Shards: { BasePart },
	Closed: boolean,
}

local Hole = {}

local function frost(part: BasePart, settings: Settings)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = settings.FrostMaterial
	part.Color = settings.FrostColor
	part.Transparency = settings.FrostTransparency
end

local function launch(part: BasePart, direction: Vector3, settings: Settings, random: () -> number)
	local function between(a: number, b: number): number
		return a + (b - a) * random()
	end
	part.Anchored = false
	part.CanTouch = false
	part.CanCollide = true -- retombe et rebondit sur le trottoir (CanQuery reste vrai : Roblox l'exige avec CanCollide)
	part.CastShadow = false
	local spin = settings.ShardSpin
	part.AssemblyLinearVelocity = direction * between(settings.ShardSpeedMin, settings.ShardSpeedMax)
		+ UP * between(settings.ShardUpMin, settings.ShardUpMax)
	part.AssemblyAngularVelocity = Vector3.new(between(-spin, spin), between(-spin, spin), between(-spin, spin))
	local fadeAt = math.max(settings.ShardLife - settings.ShardFade, 0)
	task.delay(fadeAt, function()
		if part.Parent ~= nil then
			TweenService:Create(part, TweenInfo.new(settings.ShardFade), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(part, settings.ShardLife + 0.1)
end

local function discard(result: { any }?)
	if result == nil then
		return
	end
	for _, item in result do
		local instance = if type(item) == "table" then item.Instance else nil
		if typeof(instance) == "Instance" then
			instance:Destroy()
		end
	end
end

function Hole.Begin(pane: BasePart, point: Vector3, direction: Vector3, settings: Settings): State
	local flat = direction - UP * direction:Dot(UP)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else pane.CFrame.LookVector
	local frame = ShopGlass.FrameAlong(pane, UP, dir)
	local edge = settings.EdgeMargin
	local hw = if frame then math.max(math.min(settings.HoleHalfWidth, frame.HalfWidth - edge), 0.1) else settings.HoleHalfWidth
	local hh = if frame then math.max(math.min(settings.HoleHalfHeight, frame.HalfHeight - edge), 0.1) else settings.HoleHalfHeight
	local state: State = {
		Pane = pane,
		Modifier = pane.LocalTransparencyModifier,
		Point = point,
		Direction = dir,
		Frame = frame,
		HalfWidth = hw,
		HalfHeight = hh,
		Pieces = {},
		Shards = {},
		Closed = false,
	}
	pane.LocalTransparencyModifier = 1
	return state
end

function Hole.Carve(state: State, settings: Settings, fragment: Fragment, parent: Instance, random: () -> number): State
	local pane, point, frame, hw, hh = state.Pane, state.Point, state.Frame, state.HalfWidth, state.HalfHeight
	if frame == nil or state.Closed then
		return state -- vitre couchée : cachée jusqu'à la réparation
	end
	local dir = state.Direction
	local copy = Instance.new("Part")
	copy.Name = `GlassHole_{pane.Name}`
	copy.Size = pane.Size
	copy.CFrame = pane.CFrame
	frost(copy, settings)
	copy.Parent = parent
	local sites = ShopGlass.Sites(frame, point, hw, hh, settings, random)
	local ok, result = pcall(fragment, copy, sites)
	copy:Destroy()
	if state.Closed then
		discard(if ok then result else nil)
		return state
	end
	if not ok or type(result) ~= "table" then
		warn(`[GlassThrowController] FragmentAsync : {result}`)
		return state
	end
	for _, item in result do
		local instance = if type(item) == "table" then item.Instance else nil
		if typeof(instance) ~= "Instance" or not instance:IsA("BasePart") then
			continue
		end
		local part = instance :: BasePart
		if item.Index == 1 then
			part.Name = `GlassFrost_{pane.Name}`
			frost(part, settings)
			part.Parent = parent
			table.insert(state.Pieces, part)
		else
			part.Name = `GlassShard_{pane.Name}`
			part.Material = settings.FrostMaterial
			part.Color = settings.FrostColor
			part.Transparency = settings.FrostTransparency
			part.Parent = parent
			launch(part, dir, settings, random)
			table.insert(state.Shards, part)
		end
	end
	return state
end

function Hole.Repair(state: State)
	if state.Closed then
		return
	end
	state.Closed = true
	for _, part in state.Pieces do
		part:Destroy()
	end
	for _, part in state.Shards do
		part:Destroy()
	end
	table.clear(state.Pieces)
	table.clear(state.Shards)
	if state.Pane.Parent ~= nil then
		state.Pane.LocalTransparencyModifier = state.Modifier
	end
end

return Hole
