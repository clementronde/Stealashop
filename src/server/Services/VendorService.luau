--!strict
-- VendorService (vague 39, liaison L-011 : « vendeur Idle et Wave, branché avec son service » ; DEV-006) :
-- les vendeurs des comptoirs du hub (ENV_*Stall* de Clément : armes, auras, Robux, receleur). Valeurs :
-- Config/Vendors (V0 proposées, absentes du doc) ; noms des animations : Contract/Animations.Vendor
-- (contrat 3.2 de la liaison).
--
-- Un vendeur = un Model de la map dont le nom commence par Vendors.NamePrefix (Vendor_), avec un Humanoid,
-- son Animator et son dossier Animations (<Vendeur>/Animations/Idle et Wave, livrés par Clément). Hors des
-- dossiers de travail du Workspace (_INBOX_CLEMENT, _SHOWROOM_CLEMENT… : nom commençant par « _ »).
--   - Idle : jouée en boucle dès que le dossier et l'Animator sont là (relus à chaque tour tant qu'ils
--     manquent : marche dès la livraison) ;
--   - Wave : une fois quand un joueur vivant arrive à moins de WaveDistance studs (de la tête du vendeur à
--     son HumanoidRootPart) ; il doit repasser au-delà de WaveDistance + WaveHysteresis pour la relancer ;
--     au plus une par vendeur toutes les WaveCooldown s (une arrivée pendant ce délai ne salue pas).
--   Jouées côté serveur (comme l'Idle des conducteurs du camion) : tout le monde voit le même salut.
-- Sans dossier Animations ou sans Animator : rien, aucune erreur ni avertissement (le ContractChecker dit
-- déjà ce qui n'est pas livré). Une animation manquante dans un dossier livré : un avertissement en
-- Studio (AnimPlayer). Aucun script dans les modèles de Clément : tout part d'ici. API : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Vendors = require(Shared.Config.Vendors)
local Animations = require(Shared.Contract.Animations)
local AnimPlayer = require(Shared.Anim.AnimPlayer)

type Vendor = {
	Model: Model,
	Anims: AnimPlayer.AnimPlayer?,
	Near: { [Player]: boolean },
	LastWave: number, -- os.clock()
}

local IDLE = "Idle"
local WAVE = "Wave"
local HEAD_NAME = "Head"

local VendorService = {}
VendorService.Priority = 230 -- V0 proposé, absent du doc : rien ne dépend de lui

local vendors: { [Model]: Vendor } = {}

-- Dans la map jouée : dans le Workspace, hors des dossiers de travail (nom commençant par « _ »).
local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local node: Instance? = instance
	while node ~= nil and node.Parent ~= Workspace do
		node = node.Parent
	end
	return node ~= nil and string.sub(node.Name, 1, 1) ~= "_"
end

local function consider(instance: Instance)
	if not instance:IsA("Model") or vendors[instance :: Model] ~= nil then
		return
	end
	if string.sub(instance.Name, 1, #Vendors.NamePrefix) ~= Vendors.NamePrefix or not inMap(instance) then
		return
	end
	local model = instance :: Model
	vendors[model] = { Model = model, Anims = nil, Near = {}, LastWave = -math.huge }
end

local function forget(vendor: Vendor)
	vendors[vendor.Model] = nil
	local anims = vendor.Anims
	if anims then
		anims:Destroy()
	end
end

-- Idle lancée dès que le dossier Animations et l'Animator sont là ; nil tant qu'il manque quelque chose.
local function animsOf(vendor: Vendor): AnimPlayer.AnimPlayer?
	local anims = vendor.Anims
	if anims then
		return anims
	end
	local folder = AnimPlayer.modelFolder(vendor.Model)
	local humanoid = vendor.Model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if folder == nil or animator == nil then
		return nil
	end
	local created = AnimPlayer.new(animator, folder, Animations.Vendor, `Vendeur {vendor.Model.Name}`)
	vendor.Anims = created
	created:Play(IDLE)
	return created
end

local function headPosition(model: Model): Vector3
	local head = model:FindFirstChild(HEAD_NAME)
	if head and head:IsA("BasePart") then
		return (head :: BasePart).Position
	end
	return model:GetPivot().Position
end

-- Position du HumanoidRootPart d'un joueur vivant, sinon nil.
local function playerPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return (root :: BasePart).Position
end

local function stepVendor(vendor: Vendor, now: number)
	if not inMap(vendor.Model) then
		forget(vendor)
		return
	end
	local anims = animsOf(vendor)
	if anims == nil then
		return
	end
	local head = headPosition(vendor.Model)
	local arrived = false
	local near = vendor.Near
	for player in near do
		if player.Parent ~= Players then
			near[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local position = playerPosition(player)
		local distance = if position then (position - head).Magnitude else math.huge
		if distance <= Vendors.WaveDistance then
			if not near[player] then
				near[player] = true
				arrived = true
			end
		elseif distance > Vendors.WaveDistance + Vendors.WaveHysteresis then
			near[player] = nil
		end
	end
	if arrived and now - vendor.LastWave >= Vendors.WaveCooldown and not anims:IsPlaying(WAVE) then
		vendor.LastWave = now
		anims:Play(WAVE)
	end
end

local function step()
	local now = os.clock()
	for _, vendor in vendors do
		stepVendor(vendor, now)
	end
end

function VendorService.Init()
	Workspace.DescendantAdded:Connect(consider)
end

function VendorService.Start()
	for _, instance in Workspace:GetDescendants() do
		consider(instance)
	end
	local count = 0
	for _ in vendors do
		count += 1
	end
	print(`[VendorService] {count} vendeur(s) {Vendors.NamePrefix}* : Idle en boucle, Wave à moins de {Vendors.WaveDistance} studs`)
	while true do
		task.wait(Vendors.Tick)
		xpcall(step, function(err: any)
			warn(`[VendorService] tick : {err}\n{debug.traceback()}`)
		end)
	end
end

return VendorService
