--!strict
-- Reveal/Ceiling (client, vague 62, a204 ; L-198) : le plafond d'un magasin PNJ qui explose au-dessus d'un gros objet.
-- Module d'aide de RevealController (sous-dossier : le Loader ne le démarre pas). Valeurs : Config/Reveal.Ceiling.
--
-- Enfants facultatifs du magasin (Contract/Models) : Ceiling (pièce ou Model) et CeilingFractured avec Shard_01…
-- (laissés invisibles dans la map). Tout est local, rien ne repart au serveur :
--   - Explode(store, center, radius) (marqueur Explode d'une cinématique) : Ceiling caché (LocalTransparencyModifier ;
--     Ceiling d'une seule pièce, greybox : aussi les pièces GreyboxAlsoHide du magasin), copies visibles des Shard_NN
--     (MaxShards, LowEndShards sur appareil faible ; sans CeilingFractured, morceaux V0 de la couleur du plafond) qui
--     partent vers le haut et l'extérieur depuis `center`, tournent, retombent jusqu'au sol, s'effacent, sont détruites.
--     Un seul jeu d'éclats à la fois par magasin : un deuxième Explode pendant le vol ne fait que cacher.
--   - attribut CeilingBroken du magasin (serveur) : vrai = plafond caché (sans éclats si aucune cinématique de ce
--     magasin n'attend son Explode, ex. un joueur qui arrive) ; une cinématique en attente (Pending) a PendingWait s pour
--     le faire sauter. Le plafond revient (tout remis, éclats détruits) quand l'attribut est faux ET que LocalHold s sont
--     passées depuis le dernier Explode local (serveur sans l'attribut : il revient au bout de LocalHold).
--   - magasin sans Ceiling : rien n'est caché ni lancé, sans erreur.
--
-- API : Ceiling.Explode(store, center, radius, lowEnd) ; Ceiling.SetPending(store, on) ; Ceiling.Refresh(store) ;
--   Ceiling.Step(dt) ; Ceiling.IsHidden(store) -> boolean ; Ceiling.GetState() -> { [Model]: { Hidden, Shards, Pending } } ;
--   Ceiling.Clear() (tout remis).

local Workspace = game:GetService("Workspace")

local CFG = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Reveal")).Ceiling

type Shard = {
	part: BasePart,
	velocity: Vector3,
	axis: Vector3,
	spin: number,
	age: number,
	floorY: number,
	landed: boolean,
	baseTransparency: number,
}

type State = {
	store: Model,
	hidden: { [BasePart]: number }, -- pièce cachée → LocalTransparencyModifier d'avant
	shards: { Shard },
	explodedAt: number?,
	pending: number?, -- heure (os.clock) où une cinématique a commencé à attendre son Explode
}

local Ceiling = {}

local states: { [Model]: State } = {}
local random = Random.new()
local FX_FOLDER = "_RevealFX"

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

local function stateOf(store: Model): State
	local existing = states[store]
	if existing then
		return existing
	end
	local s: State = { store = store, hidden = {}, shards = {}, explodedAt = nil, pending = nil }
	states[store] = s
	return s
end

local function partsOf(root: Instance): { BasePart }
	local out: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(out, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- La pièce ou le Model Ceiling du magasin (premier trouvé parmi ses descendants), ou nil.
local function ceilingOf(store: Model): Instance?
	local found = store:FindFirstChild(CFG.Name, true)
	if found and (found:IsA("BasePart") or found:IsA("Model")) then
		return found
	end
	return nil
end

-- Ce qui se cache avec le plafond : Ceiling, et pour un Ceiling d'une seule pièce (greybox) le toit au-dessus.
local function targetsOf(store: Model, ceiling: Instance): { BasePart }
	local list = partsOf(ceiling)
	if ceiling:IsA("BasePart") then
		for _, d in store:GetDescendants() do
			if d:IsA("BasePart") and d ~= ceiling then
				for _, prefix in CFG.GreyboxAlsoHide do
					if startsWith(d.Name, prefix) then
						table.insert(list, d)
						break
					end
				end
			end
		end
	end
	return list
end

local function hide(s: State): boolean
	local ceiling = ceilingOf(s.store)
	if ceiling == nil then
		return false
	end
	for _, part in targetsOf(s.store, ceiling) do
		if s.hidden[part] == nil then
			s.hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	return true
end

local function destroyShards(s: State)
	for _, shard in s.shards do
		shard.part:Destroy()
	end
	table.clear(s.shards)
end

local function restore(s: State)
	for part, value in s.hidden do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = value
		end
	end
	table.clear(s.hidden)
	destroyShards(s)
	s.explodedAt = nil
end

local function broken(store: Model): boolean
	return store:GetAttribute(CFG.Attribute) == true
end

local function range(pair: { number }): number
	return random:NextNumber(pair[1], pair[2])
end

local function launch(s: State, part: BasePart, center: Vector3, floorY: number)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.LocalTransparencyModifier = 0
	local flat = Vector3.new(part.Position.X - center.X, 0, part.Position.Z - center.Z)
	local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)).Unit
	local axis = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1))
	table.insert(s.shards, {
		part = part,
		velocity = out * range(CFG.SpeedOut) + Vector3.new(0, range(CFG.SpeedUp), 0),
		axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.new(0, 1, 0),
		spin = random:NextNumber(-CFG.Spin, CFG.Spin),
		age = 0,
		floorY = floorY,
		landed = false,
		baseTransparency = part.Transparency,
	})
	part.Parent = fxFolder()
end

-- Bas du magasin (sol des éclats) : bas de son volume Bounds, sinon `fallback`.
local function floorOf(store: Model, fallback: number): number
	local bounds = store:FindFirstChild("Bounds", true)
	if bounds and bounds:IsA("BasePart") then
		return bounds.Position.Y - bounds.Size.Y / 2
	end
	return fallback
end

function Ceiling.Explode(store: Model, center: Vector3, radius: number, lowEnd: boolean): boolean
	local s = stateOf(store)
	s.pending = nil
	local ceiling = ceilingOf(store)
	if ceiling == nil then
		return false
	end
	hide(s)
	s.explodedAt = os.clock()
	if #s.shards > 0 then
		return true -- un seul jeu d'éclats à la fois par magasin
	end
	local height = if ceiling:IsA("BasePart") then ceiling.Position.Y else (ceiling :: Model):GetPivot().Position.Y
	local origin = Vector3.new(center.X, height, center.Z)
	local floorY = floorOf(store, center.Y)
	local fractured = store:FindFirstChild(CFG.Fractured, true)
	local count = 0
	local limit = if lowEnd then CFG.LowEndShards else CFG.MaxShards
	if fractured then
		for _, d in fractured:GetDescendants() do
			if count >= limit then
				break
			end
			if d:IsA("BasePart") and startsWith(d.Name, CFG.ShardPrefix) then
				local copy = d:Clone()
				if copy then
					count += 1
					copy.Transparency = 0
					launch(s, copy, origin, floorY)
				end
			end
		end
	end
	if count == 0 and ceiling:IsA("BasePart") then
		-- Morceaux V0 de la couleur du plafond, autour de l'objet.
		local source = ceiling :: BasePart
		local chunks = if lowEnd then CFG.V0ChunksLowEnd else CFG.V0Chunks
		for _ = 1, chunks do
			local chunk = Instance.new("Part")
			chunk.Name = "CeilingChunk"
			local size = range(CFG.V0ChunkSize)
			chunk.Size = Vector3.new(size, math.max(source.Size.Y, 0.2), size * random:NextNumber(0.6, 1.2))
			chunk.Color = source.Color
			chunk.Material = source.Material
			local angle = random:NextNumber(0, 2 * math.pi)
			local distance = random:NextNumber(0, radius)
			chunk.CFrame = CFrame.new(origin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
				* CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0)
			launch(s, chunk, origin, floorY)
		end
	end
	return true
end

-- Une cinématique de ce magasin attend (ou n'attend plus) son Explode.
function Ceiling.SetPending(store: Model, on: boolean)
	local s = stateOf(store)
	s.pending = if on then os.clock() else nil
	if on and s.explodedAt == nil and next(s.hidden) ~= nil then
		-- Attribut arrivé juste avant RevealStarted : le plafond, caché sans éclats, revient pour que la scène le fasse
		-- sauter.
		restore(s)
	end
	Ceiling.Refresh(store)
end

-- Relit CeilingBroken : caché, ou remis.
function Ceiling.Refresh(store: Model)
	local s = stateOf(store)
	local now = os.clock()
	local localBroken = s.explodedAt ~= nil and now - (s.explodedAt :: number) < CFG.LocalHold
	if broken(store) then
		local waiting = s.pending ~= nil and now - (s.pending :: number) < CFG.PendingWait
		if not waiting and next(s.hidden) == nil then
			hide(s)
		end
	elseif not localBroken and (next(s.hidden) ~= nil or #s.shards > 0) then
		restore(s)
	end
end

function Ceiling.Step(dt: number)
	for store, s in states do
		if store.Parent == nil then
			restore(s)
			states[store] = nil
			continue
		end
		local index = 1
		while index <= #s.shards do
			local shard = s.shards[index]
			shard.age += dt
			local part = shard.part
			if not shard.landed then
				shard.velocity += Vector3.new(0, -CFG.Gravity * dt, 0)
				local position = part.Position + shard.velocity * dt
				local half = part.Size.Y / 2
				if position.Y - half <= shard.floorY and shard.velocity.Y < 0 then
					position = Vector3.new(position.X, shard.floorY + half, position.Z)
					shard.landed = true
				end
				local rotation = part.CFrame.Rotation * CFrame.fromAxisAngle(shard.axis, shard.spin * dt)
				part.CFrame = CFrame.new(position) * rotation
			end
			local fadeStart = CFG.ShardLife
			if shard.age >= fadeStart + CFG.ShardFade then
				part:Destroy()
				table.remove(s.shards, index)
				continue
			elseif shard.age >= fadeStart then
				local f = (shard.age - fadeStart) / CFG.ShardFade
				part.Transparency = shard.baseTransparency + (1 - shard.baseTransparency) * f
			end
			index += 1
		end
		if s.explodedAt ~= nil or s.pending ~= nil or next(s.hidden) ~= nil then
			Ceiling.Refresh(store)
		end
		if s.explodedAt == nil and s.pending == nil and next(s.hidden) == nil and #s.shards == 0 and not broken(store) then
			states[store] = nil
		end
	end
end

function Ceiling.IsHidden(store: Model): boolean
	local s = states[store]
	return s ~= nil and next(s.hidden) ~= nil
end

function Ceiling.GetState(): { [Model]: { Hidden: number, Shards: number, Pending: boolean } }
	local out = {}
	for store, s in states do
		local hidden = 0
		for _ in s.hidden do
			hidden += 1
		end
		out[store] = { Hidden = hidden, Shards = #s.shards, Pending = s.pending ~= nil }
	end
	return out
end

function Ceiling.Clear()
	for store, s in states do
		restore(s)
		states[store] = nil
	end
end

return Ceiling
