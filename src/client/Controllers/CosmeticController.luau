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
-- tag retiré). Effets visuels coupés dans les réglages du joueur (VfxEnabled = false, L-095) : toutes
-- les auras, la sienne comprise, à FullRate × Settings.VfxOff.AuraFactor (0 : coupées) ; et, depuis la
-- vague 24, trails, lumière des auras et halos de rareté éteints (voir applyVfx).
--
-- API (client) : CosmeticController.CutCount() -> number (effets natifs éteints, pour un banc).

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

-- VISUAL EFFECTS sur OFF (vague 24, retour de Cantin) : en plus des auras à débit nul, ces effets
-- natifs posés par le serveur sont éteints localement (Enabled = false), puis rallumés à leur état
-- d'origine quand le joueur remet ON. Rien d'autre n'est touché (contours Highlight, panneaux, textes).
--   - trail du joueur (Trail CosmeticTrail, CosmeticService), de tous les joueurs ;
--   - lumière de l'aura (les lumières dans une pièce taggée CosmeticAura) ;
--   - halo de rareté du colis porté ou au sol (tout émetteur, lumière ou rayon sous l'Attachment
--     HaloPoint, CarryService) et des objets exposés (sous la pièce RarityHalo, DisplayService).
local CUT_CLASSES = { "ParticleEmitter", "Light", "Beam", "Trail" }
local TRAIL_NAME = "CosmeticTrail" -- CosmeticService
local HALO_HOLDERS = { HaloPoint = true, RarityHalo = true } -- CarryService, DisplayService
local cut: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- [effet éteint] = Enabled d'origine
local vfxReduced = false

local function isCuttable(inst: Instance): boolean
	local native = false
	for _, class in CUT_CLASSES do
		if inst:IsA(class) then
			native = true
			break
		end
	end
	if not native then
		return false
	end
	if inst:IsA("Trail") then
		return inst.Name == TRAIL_NAME
	end
	local parent = inst.Parent
	if parent == nil then
		return false
	end
	if HALO_HOLDERS[parent.Name] then
		return true
	end
	-- Lumière de l'aura (ses émetteurs passent par setRates).
	return inst:IsA("Light") and parent:IsA("BasePart") and auras[parent :: BasePart] == true
end

local function cutOne(inst: Instance)
	if cut[inst] ~= nil or not isCuttable(inst) then
		return
	end
	local effect = inst :: any
	cut[inst] = effect.Enabled == true
	effect.Enabled = false
end

local function applyVfx()
	local reduced = Settings.VfxReduced(localPlayer)
	if reduced == vfxReduced then
		return
	end
	vfxReduced = reduced
	if reduced then
		for _, inst in Workspace:GetDescendants() do
			cutOne(inst)
		end
	else
		for inst, was in cut do
			if inst.Parent ~= nil then
				(inst :: any).Enabled = was
			end
		end
		table.clear(cut)
	end
end

-- Effets coupés en ce moment (banc, Studio) : nombre d'effets natifs éteints.
function CosmeticController.CutCount(): number
	local n = 0
	for _ in cut do
		n += 1
	end
	return n
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

	-- VISUAL EFFECTS (vague 24) : trails, lumière d'aura et halos de rareté éteints tant que c'est OFF.
	Workspace.DescendantAdded:Connect(function(inst: Instance)
		if vfxReduced then
			cutOne(inst)
		end
	end)
	localPlayer:GetAttributeChangedSignal(Settings.VfxAttribute):Connect(function()
		applyVfx()
		update()
	end)
	applyVfx()

	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			update()
		end
	end)
end

return CosmeticController
