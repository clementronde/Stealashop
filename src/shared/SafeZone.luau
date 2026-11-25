--!strict
-- SafeZone (a157, vague 49, demande de Cantin du 2026-11-14) : « le joueur est-il en zone safe ? », un seul point
-- de vérité pour les événements des magasins PNJ (chrono de police de WindowService, chrono HEIST de
-- StoreHeistService, attente du départ des vigiles de GuardService, témoins de WitnessService). Même règle que
-- GuardService depuis DEV-018 : un objet taggé `SafeZone` (contrat 2.1), dans la map jouée (règle de Contract/Find.inMap) ;
-- son volume = la pièce elle-même, sinon son enfant direct `Bounds` (pas ceux des parcelles qu'il contient peut-être),
-- sinon la boîte englobante du modèle (gardée en cache). Serveur et client.
--
-- API :
--   SafeZone.Contains(position) -> boolean        `position` est dans une zone safe
--   SafeZone.ContainsPlayer(player) -> boolean    son HumanoidRootPart (personnage vivant) est dans une zone safe
--   SafeZone.Shares(a, b) -> boolean              a194 : une même zone safe contient `a` et `b`

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "SafeZone" -- contrat 2.1 (Contract/Tags)
local BOUNDS = "Bounds"
local WORK_PREFIX = "_" -- dossiers de travail (inMap)

local boxCache: { [Instance]: { cframe: CFrame, size: Vector3 } } = setmetatable({}, { __mode = "k" }) :: any

local SafeZone = {}

-- a436 (check-up a417 I12) : dans la map jouée, même règle que Contract/Find.inMap (dans le Workspace, aucun ancêtre en
-- « _ ») ; recopiée ici pour que SafeZone reste sans dépendance (des bancs le chargent seul).
local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local node: Instance? = instance
	while node ~= nil and node ~= Workspace do
		if string.sub(node.Name, 1, #WORK_PREFIX) == WORK_PREFIX then
			return false
		end
		node = node.Parent
	end
	return true
end

-- a282 (audit a271, point 4) : zones gardées en cache au lieu d'un GetTagged (nouveau tableau) à chaque appel. La
-- liste suit les signaux du tag (Added / Removed, mêmes règles que GetTagged : une zone sortie du jeu en est retirée) ;
-- `inMap` est gardé par zone et recalculé après son AncestryChanged (zone déplacée, dans un dossier de travail ou hors
-- de Workspace). Sans ces signaux (faux Roblox des bancs) : l'ancien parcours, inchangé. API inchangée.
type ZoneState = { inMap: boolean?, watched: boolean, conn: RBXScriptConnection? }
local zones: { [Instance]: ZoneState }? = nil
local noSignals = false

local function track(inst: Instance)
	local list = zones
	if list == nil or list[inst] ~= nil then
		return
	end
	local state: ZoneState = { inMap = nil, watched = false, conn = nil }
	local ok, conn = pcall(function(): any
		return (inst :: any).AncestryChanged:Connect(function()
			state.inMap = nil
		end)
	end)
	if ok and conn ~= nil then
		state.watched = true
		state.conn = conn
	end
	list[inst] = state
end

local function untrack(inst: Instance)
	local list = zones
	local state = if list then list[inst] else nil
	if list and state then
		if state.conn then
			state.conn:Disconnect()
		end
		list[inst] = nil
	end
end

-- La liste en cache, ou nil sans les signaux du tag (repli sur GetTagged).
local function cachedZones(): { [Instance]: ZoneState }?
	if zones or noSignals then
		return zones
	end
	local ok = pcall(function()
		local added = CollectionService:GetInstanceAddedSignal(TAG)
		local removed = CollectionService:GetInstanceRemovedSignal(TAG)
		zones = {}
		added:Connect(track)
		removed:Connect(untrack)
	end)
	if not ok then
		zones = nil
		noSignals = true
		return nil
	end
	for _, inst in CollectionService:GetTagged(TAG) do
		track(inst)
	end
	return zones
end

local function zoneInMap(inst: Instance, state: ZoneState): boolean
	local value = state.inMap
	if value == nil then
		value = inMap(inst)
		if state.watched then
			state.inMap = value
		end
	end
	return value :: boolean
end

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

local function inside(inst: Instance, position: Vector3): boolean
	local part: Instance? = if inst:IsA("BasePart") then inst else inst:FindFirstChild(BOUNDS)
	if part and part:IsA("BasePart") then
		local box = part :: BasePart
		return insideBox(box.CFrame, box.Size, position)
	end
	if inst:IsA("Model") then
		local cached = boxCache[inst]
		if cached == nil then
			local cframe, size = (inst :: Model):GetBoundingBox()
			cached = { cframe = cframe, size = size }
			boxCache[inst] = cached
		end
		return insideBox(cached.cframe, cached.size, position)
	end
	return false
end

function SafeZone.Contains(position: Vector3): boolean
	local list = cachedZones()
	if list then
		for inst, state in list do
			if zoneInMap(inst, state) and inside(inst, position) then
				return true
			end
		end
		return false
	end
	for _, inst in CollectionService:GetTagged(TAG) do
		if inMap(inst) and inside(inst, position) then
			return true
		end
	end
	return false
end

-- a194 (vague 60) : une même zone safe contient-elle `a` et `b` ? (BotService : le lobby contient la boutique du bot,
-- seule une autre zone safe arrête sa poursuite.)
function SafeZone.Shares(a: Vector3, b: Vector3): boolean
	local list = cachedZones()
	if list then
		for inst, state in list do
			if zoneInMap(inst, state) and inside(inst, a) and inside(inst, b) then
				return true
			end
		end
		return false
	end
	for _, inst in CollectionService:GetTagged(TAG) do
		if inMap(inst) and inside(inst, a) and inside(inst, b) then
			return true
		end
	end
	return false
end

function SafeZone.ContainsPlayer(player: Player): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return false
	end
	return SafeZone.Contains((root :: BasePart).Position)
end

return SafeZone
