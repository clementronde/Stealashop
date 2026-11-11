--!strict
-- CosmeticController (DEV-032, client) : allège les auras lointaines des autres joueurs
-- (Partie 1, sections 5.10 et 9.7).
--
-- Rôle : les auras des autres joueurs perdent la moitié de leurs particules au-delà de 60 studs
-- (5.10 ; Config/Cosmetics : RemoteParticleCutDistance, RemoteParticleCutFactor). Toutes les
-- RemoteParticleCheckInterval s, pour chaque pièce d'aura taggée « CosmeticAura » (posée par
-- CosmeticService) qui n'est pas dans le personnage du joueur local, on mesure sa distance à la
-- caméra : au-delà, chaque ParticleEmitter de l'aura passe à FullRate × facteur ; en deçà, il
-- revient à FullRate (attribut posé par le serveur sur chaque émetteur). Le changement est local :
-- ni le serveur ni les autres joueurs ne le voient. Les auras suivent le streaming (tag ajouté,
-- tag retiré). Le trail n'est pas touché. Effets visuels coupés dans les réglages du joueur
-- (VfxEnabled = false, L-095) : toutes les auras, la sienne comprise, à FullRate × Settings.VfxOff.AuraFactor.
--
-- API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cosmetics"))
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Settings"))

-- Posés par CosmeticService (mêmes noms là-bas).
local AURA_TAG = "CosmeticAura"
local FULL_RATE_ATTRIBUTE = "FullRate"
local ROOT_PART = "HumanoidRootPart"

local CUT_DISTANCE: number = Cosmetics.RemoteParticleCutDistance
local CUT_FACTOR: number = Cosmetics.RemoteParticleCutFactor
local CHECK_INTERVAL: number = Cosmetics.RemoteParticleCheckInterval
-- Écart toléré entre le débit lu et le débit voulu (la propriété est stockée en simple précision).
local TOLERANCE = 1e-3

local CosmeticController = {}

local localPlayer = Players.LocalPlayer
local auras: { [BasePart]: boolean } = {}
local elapsed = 0

-- D'où l'on regarde : la caméra, sinon le perso du joueur local.
local function viewPoint(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild(ROOT_PART) else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function setRates(aura: BasePart, factor: number)
	for _, child in aura:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local full = child:GetAttribute(FULL_RATE_ATTRIBUTE)
			if type(full) == "number" then
				local rate = full * factor
				if math.abs(child.Rate - rate) > TOLERANCE then
					child.Rate = rate
				end
			end
		end
	end
end

local function update()
	local from = viewPoint()
	if from == nil then
		return
	end
	local own = localPlayer.Character
	local reduced = Settings.VfxReduced(localPlayer) -- effets visuels coupés : toutes les auras allégées
	for aura in auras do
		if aura.Parent == nil then
			auras[aura] = nil
			continue
		end
		local mine = own ~= nil and aura:IsDescendantOf(own)
		local far = not mine and (aura.Position - from).Magnitude > CUT_DISTANCE
		setRates(aura, if reduced then Settings.VfxOff.AuraFactor elseif far then CUT_FACTOR else 1)
	end
end

local function track(inst: Instance)
	if inst:IsA("BasePart") then
		auras[inst :: BasePart] = true
	end
end

function CosmeticController.Start()
	CollectionService:GetInstanceAddedSignal(AURA_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(AURA_TAG):Connect(function(inst: Instance)
		if inst:IsA("BasePart") then
			auras[inst :: BasePart] = nil
		end
	end)
	for _, inst in CollectionService:GetTagged(AURA_TAG) do
		track(inst)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			update()
		end
	end)
end

return CosmeticController
