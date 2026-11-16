--!strict
-- Reveal/Shelf (client, a220 ; liaison L-210 point 3, Clément 2026-11-16 : « s'il est plus gros que l'étagère, il la
-- casse en sortant ») : le meuble d'un magasin PNJ qui casse sous un objet qui grandit dans la cinématique d'ouverture.
-- Module d'aide de RevealController (sous-dossier : le Loader ne le démarre pas). Valeurs : Config/Reveal.Shelf
-- (interrupteur Enabled). Repli codé, sans élément de Clément ; tout est local, rien ne repart au serveur.
--   - Plan(id, store, base, size, scale, lowEnd) (début de la scène `id`) : boîte de l'objet = `size` (ses dimensions
--     à la taille 1, sans rotation ; largeur = le plus grand côté horizontal, l'objet tourne sur lui-même) posée sur
--     `base` (l'emplacement du rayon), relevée de Lift. Pièces du meuble touchées par cette boîte à la taille finale
--     `scale` : voir Pick. Taille finale sous MinScale : rien.
--   - Grow(id, shown) (chaque image après le marqueur Grow) : les pièces que la boîte touche à la taille montrée
--     `shown` cassent : cachées (LocalTransparencyModifier, décalques compris), et une copie (MaxPieces au plus,
--     LowEndPieces sur appareil faible) part vers le haut et l'extérieur, tourne, retombe au sol du magasin (bas de
--     Bounds), s'efface, est détruite. Renvoie le nombre de pièces cassées à cet appel.
--   - Forget(id) (fin de la scène) : ce qui n'a pas cassé reste en place.
--   - Step(dt) : morceaux, et retour du meuble RestoreAfter s après la dernière casse dans ce magasin.
--   - Pick(store, base, size, scale) -> { BasePart } : pièces touchées (pur, pour les bancs).
--   - GetState() -> { [Model]: { Hidden, Pieces } } ; Clear() : tout remis.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Reveal = require(Shared:WaitForChild("Config"):WaitForChild("Reveal"))
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))
local CFG = Reveal.Shelf
local NO_BREAK: string = Attributes.NoShelfBreak.Name

-- Enfants du magasin qui ne sont pas un meuble (contrat 10.4, Contract/Models) ; ShelfCaps : murs invisibles du code.
local NOT_FURNITURE = {
	Bounds = true,
	Window = true,
	WindowFractured = true,
	Shutter = true,
	Door = true,
	SignPart = true,
	ShelfCaps = true,
	[Reveal.Ceiling.Name] = true,
	[Reveal.Ceiling.Fractured] = true,
}
local SKIP_TAGS = { "ShelfBox", "ShelfItem" }
local FX_FOLDER = "_RevealFX"

type Piece = {
	part: BasePart,
	velocity: Vector3,
	axis: Vector3,
	spin: number,
	age: number,
	floorY: number,
	landed: boolean,
	baseTransparency: number,
}

type StoreState = {
	hidden: { [Instance]: number }, -- pièce ou décalque caché → LocalTransparencyModifier d'avant
	pieces: { Piece },
	lastBreak: number, -- os.clock()
}

type Plan = {
	store: Model,
	base: CFrame,
	size: Vector3,
	targets: { BasePart },
	broken: number,
	limit: number,
	sound: boolean,
}

local Shelf = {}

local states: { [Model]: StoreState } = {}
local plans: { [string]: Plan } = {}
local random = Random.new()

local function fxFolder(): Instance
	local existing = Workspace:FindFirstChild(FX_FOLDER)
	if existing then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = FX_FOLDER
	f.Parent = Workspace
	return f
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- La pièce fait-elle partie d'un meuble qui peut casser ?
local function breakable(part: BasePart, store: Model): boolean
	if part.Transparency >= 1 then
		return false -- invisible : murs du code, éclats pré-fracturés, volumes
	end
	for _, prefix in Reveal.Ceiling.GreyboxAlsoHide do
		if startsWith(part.Name, prefix) then
			return false
		end
	end
	local node: Instance? = part
	while node and node ~= store do
		if NOT_FURNITURE[node.Name] or node:GetAttribute(NO_BREAK) == true then
			return false
		end
		for _, tag in SKIP_TAGS do
			if CollectionService:HasTag(node, tag) then
				return false
			end
		end
		if node ~= part and node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return false
		end
		node = node.Parent
	end
	return node == store
end

-- Coins (min, max) de la boîte de `part` dans le repère `frame`.
local function localBox(frame: CFrame, part: BasePart): (Vector3, Vector3)
	local rel = frame:ToObjectSpace(part.CFrame)
	local half = part.Size / 2
	local r, u, b = rel.RightVector, rel.UpVector, rel.LookVector
	local extent = Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(b.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(b.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(b.Z) * half.Z
	)
	return rel.Position - extent, rel.Position + extent
end

-- Repère de l'emplacement, à plat (axe Y vertical), même position.
local function flatFrame(base: CFrame): CFrame
	local look = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = -Vector3.zAxis
	end
	return CFrame.lookAt(base.Position, base.Position + look.Unit)
end

-- La boîte de l'objet (taille `scale`) touche-t-elle la pièce (coins dans le repère de `base`) ?
local function touches(low: Vector3, high: Vector3, size: Vector3, scale: number): boolean
	local half = math.max(size.X, size.Z) * scale / 2 + CFG.Margin
	local bottom = CFG.Lift
	local top = CFG.Lift + size.Y * scale + CFG.Margin
	return high.X > -half and low.X < half and high.Z > -half and low.Z < half and high.Y > bottom and low.Y < top
end

function Shelf.Pick(store: Model, base: CFrame, size: Vector3, scale: number): { BasePart }
	local out: { BasePart } = {}
	if scale < CFG.MinScale then
		return out
	end
	local flat = flatFrame(base)
	for _, d in store:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local part = d :: BasePart
		local low, high = localBox(flat, part)
		local extent = high - low
		if math.max(extent.X, extent.Z) > CFG.MaxPieceLength or extent.Y > CFG.MaxPieceHeight then
			continue -- sol, mur, pilier, plafond
		end
		if touches(low, high, size, scale) and breakable(part, store) then
			table.insert(out, part)
		end
	end
	return out
end

local function stateOf(store: Model): StoreState
	local existing = states[store]
	if existing then
		return existing
	end
	local s: StoreState = { hidden = {}, pieces = {}, lastBreak = os.clock() }
	states[store] = s
	return s
end

local function hideOne(s: StoreState, inst: Instance)
	if s.hidden[inst] == nil then
		s.hidden[inst] = tonumber((inst :: any).LocalTransparencyModifier) or 0
	end
	(inst :: any).LocalTransparencyModifier = 1
end

local function range(pair: { number }): number
	return random:NextNumber(pair[1], pair[2])
end

local function floorOf(store: Model, fallback: number): number
	local bounds = store:FindFirstChild("Bounds", true)
	if bounds and bounds:IsA("BasePart") then
		return bounds.Position.Y - bounds.Size.Y / 2
	end
	return fallback
end

-- Copie de `part` qui tombe en morceau, depuis l'axe de l'objet `center`.
local function launch(s: StoreState, part: BasePart, center: Vector3, floorY: number)
	local ok, copy = pcall(function(): BasePart?
		return part:Clone()
	end)
	if not ok or copy == nil then
		return
	end
	local piece = copy :: BasePart
	for _, d in piece:GetDescendants() do
		if not (d:IsA("Decal") or d:IsA("SpecialMesh") or d:IsA("SurfaceAppearance")) then
			d:Destroy()
		end
	end
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.LocalTransparencyModifier = 0
	local flat = Vector3.new(part.Position.X - center.X, 0, part.Position.Z - center.Z)
	local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)).Unit
	local axis = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1))
	table.insert(s.pieces, {
		part = piece,
		velocity = out * range(CFG.SpeedOut) + Vector3.new(0, range(CFG.SpeedUp), 0),
		axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.yAxis,
		spin = random:NextNumber(-CFG.Spin, CFG.Spin),
		age = 0,
		floorY = floorY,
		landed = false,
		baseTransparency = piece.Transparency,
	})
	piece.Parent = fxFolder()
end

function Shelf.Plan(id: string, store: Model?, base: CFrame, size: Vector3, scale: number, lowEnd: boolean): number
	plans[id] = nil
	if CFG.Enabled ~= true or store == nil then
		return 0
	end
	local ok, targets = pcall(Shelf.Pick, store, base, size, scale)
	if not ok or #targets == 0 then
		return 0
	end
	plans[id] = {
		store = store,
		base = base,
		size = size,
		targets = targets,
		broken = 0,
		limit = if lowEnd then CFG.LowEndPieces else CFG.MaxPieces,
		sound = false,
	}
	return #targets
end

-- Casse ce que la boîte touche à la taille `shown`. Renvoie le nombre de pièces cassées à cet appel ; `true` en second
-- au premier morceau de la scène (le son se joue alors).
function Shelf.Grow(id: string, shown: number): (number, boolean)
	local plan = plans[id]
	if plan == nil or #plan.targets == 0 or plan.store.Parent == nil then
		return 0, false
	end
	local s = stateOf(plan.store)
	local flat = flatFrame(plan.base)
	local center = plan.base.Position
	local floorY = floorOf(plan.store, center.Y)
	local count = 0
	local index = 1
	while index <= #plan.targets do
		local part = plan.targets[index]
		local low, high = localBox(flat, part)
		if part.Parent == nil or touches(low, high, plan.size, shown) then
			table.remove(plan.targets, index)
			if part.Parent ~= nil and s.hidden[part] == nil then
				if plan.broken < plan.limit then
					launch(s, part, center, floorY)
				end
				plan.broken += 1
				count += 1
				hideOne(s, part)
				for _, d in part:GetChildren() do
					if d:IsA("Decal") then
						hideOne(s, d)
					end
				end
			end
		else
			index += 1
		end
	end
	local first = false
	if count > 0 then
		s.lastBreak = os.clock()
		if not plan.sound then
			plan.sound = true
			first = true
		end
	end
	return count, first
end

function Shelf.Forget(id: string)
	plans[id] = nil
end

local function restore(s: StoreState)
	for inst, value in s.hidden do
		if inst.Parent ~= nil then
			(inst :: any).LocalTransparencyModifier = value
		end
	end
	table.clear(s.hidden)
	for _, piece in s.pieces do
		piece.part:Destroy()
	end
	table.clear(s.pieces)
end

function Shelf.Step(dt: number)
	local now = os.clock()
	for store, s in states do
		local index = 1
		while index <= #s.pieces do
			local piece = s.pieces[index]
			piece.age += dt
			local part = piece.part
			if not piece.landed then
				piece.velocity += Vector3.new(0, -CFG.Gravity * dt, 0)
				local position = part.Position + piece.velocity * dt
				local half = part.Size.Y / 2
				if position.Y - half <= piece.floorY and piece.velocity.Y < 0 then
					position = Vector3.new(position.X, piece.floorY + half, position.Z)
					piece.landed = true
				end
				part.CFrame = CFrame.new(position) * part.CFrame.Rotation * CFrame.fromAxisAngle(piece.axis, piece.spin * dt)
			end
			if piece.age >= CFG.Life + CFG.Fade then
				part:Destroy()
				table.remove(s.pieces, index)
				continue
			elseif piece.age >= CFG.Life then
				local f = (piece.age - CFG.Life) / CFG.Fade
				part.Transparency = piece.baseTransparency + (1 - piece.baseTransparency) * f
			end
			index += 1
		end
		if store.Parent == nil or now - s.lastBreak >= CFG.RestoreAfter then
			local busy = false
			for _, plan in plans do
				if plan.store == store and plan.broken > 0 and #plan.targets > 0 then
					busy = true -- une scène de ce magasin casse encore
				end
			end
			if not busy then
				restore(s)
				states[store] = nil
			end
		end
	end
end

function Shelf.GetState(): { [Model]: { Hidden: number, Pieces: number } }
	local out = {}
	for store, s in states do
		local hidden = 0
		for _ in s.hidden do
			hidden += 1
		end
		out[store] = { Hidden = hidden, Pieces = #s.pieces }
	end
	return out
end

function Shelf.Clear()
	for store, s in states do
		restore(s)
		states[store] = nil
	end
	table.clear(plans)
end

return Shelf
