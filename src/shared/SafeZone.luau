--!strict
-- SafeZone (a157, vague 49, demande de Cantin du 2026-11-14) : « le joueur est-il en zone safe ? », un seul point
-- de vérité pour les événements des magasins PNJ (chrono de police de WindowService, chrono HEIST de
-- StoreHeistService, attente du départ des vigiles de GuardService, témoins de WitnessService). Même règle que
-- GuardService depuis DEV-018 : un objet taggé `SafeZone` (contrat 2.1), dans la map (Workspace, hors
-- _INBOX_CLEMENT) ; son volume = la pièce elle-même, sinon son enfant direct `Bounds` (pas ceux des parcelles
-- qu'il contient peut-être), sinon la boîte englobante du modèle (gardée en cache). Serveur et client.
--
-- API :
--   SafeZone.Contains(position) -> boolean        `position` est dans une zone safe
--   SafeZone.ContainsPlayer(player) -> boolean    son HumanoidRootPart (personnage vivant) est dans une zone safe
--   SafeZone.Shares(a, b) -> boolean              a194 : une même zone safe contient `a` et `b`

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "SafeZone" -- contrat 2.1 (Contract/Tags)
local BOUNDS = "Bounds"
local INBOX_NAME = "_INBOX_CLEMENT"

local boxCache: { [Instance]: { cframe: CFrame, size: Vector3 } } = setmetatable({}, { __mode = "k" }) :: any

local SafeZone = {}

local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
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
