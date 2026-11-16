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
-- Vague 26 (L-097 point 1) : les effets complets de Clément (modèles FX_Aura_<Nom> et FX_Trail_<Nom>)
-- sont copiés par CosmeticService en Attachments sur les pièces du personnage : chaque Attachment
-- d'aura porte le tag CosmeticAura (sa distance = WorldPosition), et tout émetteur, lumière, Beam ou
-- Trail sous un Attachment marqué CosmeticFx (aura ou trail) est éteint à VISUAL EFFECTS OFF.
-- Vague 63 (a210, L-206) : pièces soudées des auras de Clément (clones taggés CosmeticPiece par CosmeticService,
-- soudés par une Weld CosmeticWeld). Attributs facultatifs, lus sur le clone : Spin (rad/s, autour de l'axe Y local
-- de la pièce), Orbit (rad/s, autour de l'axe vertical de la pièce WeldTo), Tumble (rad/s, culbute sur elle-même, axe
-- tiré par pièce), Period (s, cycle d'une bulle : gonfle, enfle, disparaît, repart ailleurs sur la flaque). Une seule
-- boucle Heartbeat pour tous les porteurs, branchée tant qu'il y a des pièces, débranchée sans pièce ; elle change en
-- local le C0 de la Weld (et la taille d'une bulle), jamais au-delà de Cosmetics.PieceMotion.MaxDistance de la caméra.
-- Pièce retirée (aura changée, porteur parti, streaming) : oubliée. VISUAL EFFECTS OFF : pièces cachées en local
-- (LocalTransparencyModifier), mouvement arrêté ; leurs émetteurs, lumières et Beams s'éteignent comme le reste.
--
-- API (client) : CosmeticController.CutCount() -> number (effets natifs éteints, pour un banc).
--   CosmeticController.PieceCount() -> (number, boolean) : pièces soudées suivies, boucle de mouvement branchée.

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
local FX_ATTRIBUTE = "CosmeticFx" -- sur chaque Attachment copié d'un modèle FX_ de Clément

local CUT_DISTANCE: number = Cosmetics.RemoteParticleCutDistance
local CUT_FACTOR: number = Cosmetics.RemoteParticleCutFactor
local CHECK_INTERVAL: number = Cosmetics.RemoteParticleCheckInterval
-- Écart toléré entre le débit lu et le débit voulu (la propriété est stockée en simple précision).
local TOLERANCE = 1e-3

local CosmeticController = {}

local localPlayer = Players.LocalPlayer
local auras: { [Instance]: boolean } = {} -- pièce d'aura V0 (BasePart) ou Attachment copié d'un modèle FX_
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

local function positionOf(aura: Instance): Vector3
	if aura:IsA("Attachment") then
		return (aura :: Attachment).WorldPosition
	end
	return (aura :: BasePart).Position
end

local function setRates(aura: Instance, factor: number)
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
		local far = not mine and (positionOf(aura) - from).Magnitude > CUT_DISTANCE
		setRates(aura, if reduced then Settings.VfxOff.AuraFactor elseif far then CUT_FACTOR else 1)
	end
end

-- VISUAL EFFECTS sur OFF (vague 24, retour de Cantin) : en plus des auras à débit nul, ces effets
-- natifs posés par le serveur sont éteints localement (Enabled = false), puis rallumés à leur état
-- d'origine quand le joueur remet ON. Rien d'autre n'est touché (contours Highlight, panneaux, textes).
--   - trail du joueur (Trail CosmeticTrail, CosmeticService), de tous les joueurs ;
--   - lumière de l'aura (les lumières dans une pièce taggée CosmeticAura) ;
--   - halo de rareté du colis porté ou au sol (tout émetteur, lumière ou rayon sous l'Attachment
--     HaloPoint, CarryService) et des objets exposés (sous la pièce RarityHalo, DisplayService) ;
--   - effets de Clément dans un colis BOX_<Rareté> (émetteur ou lumière dans une pièce voisine de Tint,
--     a79) : sur le rayon, porté, au sol.
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
	local parent = inst.Parent
	-- Effet complet de Clément (aura ou trail), copié par CosmeticService (vague 26) ; vague 63 : aussi sous une pièce
	-- soudée (BasePart marquée CosmeticFx).
	if parent ~= nil and (parent:IsA("Attachment") or parent:IsA("BasePart")) and parent:GetAttribute(FX_ATTRIBUTE) ~= nil then
		return true
	end
	if inst:IsA("Trail") then
		return inst.Name == TRAIL_NAME
	end
	if parent == nil then
		return false
	end
	if HALO_HOLDERS[parent.Name] then
		return true
	end
	-- a79 (L-097 point 3) : étincelles et lumière posées par Clément dans un colis BOX_<Rareté> (dans Body,
	-- une pièce voisine d'une pièce Tint) : elles remplacent le halo du code, elles s'éteignent comme lui.
	local box = parent.Parent
	if parent:IsA("BasePart") and box and box:IsA("Model") and not inst:IsA("Beam") then
		local tint = box:FindFirstChild("Tint")
		if tint and tint:IsA("BasePart") then
			return true
		end
	end
	-- Lumière de l'aura (ses émetteurs passent par setRates).
	return inst:IsA("Light") and parent:IsA("BasePart") and auras[parent] == true
end

local function cutOne(inst: Instance)
	if cut[inst] ~= nil or not isCuttable(inst) then
		return
	end
	local effect = inst :: any
	cut[inst] = effect.Enabled == true
	effect.Enabled = false
end

-- Pièces soudées des auras de Clément (vague 63, a210, L-206) -------------------------------------------------
local PIECE_TAG = "CosmeticPiece" -- CosmeticService
local PIECE_WELD = "CosmeticWeld" -- CosmeticService
local MOTION = Cosmetics.PieceMotion

type Piece = {
	weld: Weld?, -- Weld CosmeticWeld, trouvée à la première image où elle est là (streaming)
	base: CFrame, -- C0 posé par le serveur
	part: BasePart?, -- Part1 de la Weld (taille d'une bulle)
	size: Vector3, -- taille livrée de Part1
	spin: number,
	orbit: number,
	tumble: number,
	period: number,
	axis: Vector3, -- axe de culbute, tiré par pièce
	seed: number, -- décalage de cycle et endroits des bulles, dans [0, 1[
}

local pieces: { [Instance]: Piece } = {}
local motionConnection: RBXScriptConnection? = nil
local motionClock = 0
local pieceCount = 0

-- Nombre pseudo-aléatoire dans [0, 1[ tiré de n (même suite à chaque partie, sans Random).
local function hash01(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

local function numberAttribute(inst: Instance, name: string): number
	local value = inst:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function isMoving(piece: Piece): boolean
	return piece.spin ~= 0 or piece.orbit ~= 0 or piece.tumble ~= 0 or piece.period > 0
end

-- VISUAL EFFECTS OFF : la pièce (et un Model, toutes ses pièces) cachée en local, rien ne change pour les autres.
local function setPieceHidden(inst: Instance, hidden: boolean)
	local modifier = if hidden then 1 else 0
	if inst:IsA("BasePart") then
		(inst :: BasePart).LocalTransparencyModifier = modifier
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).LocalTransparencyModifier = modifier
		end
	end
end

local function resolveWeld(inst: Instance, piece: Piece): Weld?
	local found = inst:FindFirstChild(PIECE_WELD, true)
	if found == nil or not found:IsA("Weld") then
		return nil
	end
	local weld = found :: Weld
	piece.weld = weld
	piece.base = weld.C0
	local part = weld.Part1
	piece.part = part
	if part ~= nil then
		piece.size = part.Size
	end
	return weld
end

-- Bulle (Period) : C0 de son cycle (endroit tiré sur la flaque, autour de l'axe de la pièce d'accroche) ; sa taille
-- et sa visibilité suivent la phase du cycle.
local function bubbleC0(piece: Piece, part: BasePart, t: number): CFrame
	local time = t / piece.period + piece.seed
	local cycle = math.floor(time)
	local phase = time - cycle
	local scale: number
	local hidden = false
	if phase < MOTION.BubbleGrowShare then
		scale = math.max(MOTION.BubbleMinScale, phase / MOTION.BubbleGrowShare)
	elseif phase < MOTION.BubbleGrowShare + MOTION.BubblePopShare then
		scale = 1 + (MOTION.BubblePopScale - 1) * (phase - MOTION.BubbleGrowShare) / MOTION.BubblePopShare
	else
		scale = MOTION.BubbleMinScale
		hidden = true
	end
	part.Size = piece.size * scale
	part.LocalTransparencyModifier = if hidden then 1 else 0
	local angle = 2 * math.pi * hash01(piece.seed * 1000 + cycle)
	local radius = MOTION.BubbleSpread * math.sqrt(hash01(piece.seed * 2000 + cycle + 0.5))
	local base = piece.base.Position
	return CFrame.new(radius * math.cos(angle) - base.X, 0, radius * math.sin(angle) - base.Z) * piece.base
end

local function stopMotion()
	local connection = motionConnection
	if connection ~= nil then
		connection:Disconnect()
		motionConnection = nil
	end
end

-- Une image : chaque pièce mobile, assez proche, prend son C0 du moment (en local).
local function stepPieces(dt: number)
	motionClock += dt
	local from = viewPoint()
	for inst, piece in pieces do
		if inst.Parent == nil then
			pieces[inst] = nil
			continue
		end
		if vfxReduced or not isMoving(piece) then
			continue
		end
		local weld = piece.weld or resolveWeld(inst, piece)
		local anchor = if weld ~= nil then weld.Part0 else nil
		if weld == nil or anchor == nil then
			continue
		end
		if from ~= nil and (anchor.Position - from).Magnitude > MOTION.MaxDistance then
			continue
		end
		local t = motionClock
		local c0 = piece.base
		local part = piece.part
		if piece.period > 0 and part ~= nil then
			c0 = bubbleC0(piece, part, t)
		end
		if piece.orbit ~= 0 then
			c0 = CFrame.Angles(0, piece.orbit * t, 0) * c0
		end
		if piece.spin ~= 0 then
			c0 = c0 * CFrame.Angles(0, piece.spin * t, 0)
		end
		if piece.tumble ~= 0 then
			c0 = c0 * CFrame.fromAxisAngle(piece.axis, piece.tumble * t)
		end
		weld.C0 = c0
	end
	if next(pieces) == nil then
		stopMotion()
	end
end

local function trackPiece(inst: Instance)
	if pieces[inst] ~= nil or not (inst:IsA("BasePart") or inst:IsA("Model")) then
		return
	end
	pieceCount += 1
	local axis = Vector3.new(hash01(pieceCount + 0.1) - 0.5, hash01(pieceCount + 0.2) - 0.5, hash01(pieceCount + 0.3) - 0.5)
	local length = axis.Magnitude
	local piece: Piece = {
		weld = nil,
		base = CFrame.identity,
		part = nil,
		size = Vector3.new(1, 1, 1),
		spin = numberAttribute(inst, "Spin"),
		orbit = numberAttribute(inst, "Orbit"),
		tumble = numberAttribute(inst, "Tumble"),
		period = numberAttribute(inst, "Period"),
		axis = if length > 1e-3 then axis / length else Vector3.new(0, 1, 0),
		seed = hash01(pieceCount),
	}
	pieces[inst] = piece
	resolveWeld(inst, piece)
	if vfxReduced then
		setPieceHidden(inst, true)
	end
	if motionConnection == nil then
		motionConnection = RunService.Heartbeat:Connect(stepPieces)
	end
end

local function untrackPiece(inst: Instance)
	pieces[inst] = nil
	if next(pieces) == nil then
		stopMotion()
	end
end

-- Pièces soudées suivies et boucle de mouvement branchée (banc, Studio).
function CosmeticController.PieceCount(): (number, boolean)
	local n = 0
	for _ in pieces do
		n += 1
	end
	return n, motionConnection ~= nil
end

local function applyVfx()
	local reduced = Settings.VfxReduced(localPlayer)
	if reduced == vfxReduced then
		return
	end
	vfxReduced = reduced
	for inst in pieces do
		setPieceHidden(inst, reduced)
	end
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
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		auras[inst] = true
	end
end

function CosmeticController.Start()
	CollectionService:GetInstanceAddedSignal(AURA_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(AURA_TAG):Connect(function(inst: Instance)
		auras[inst] = nil
	end)
	for _, inst in CollectionService:GetTagged(AURA_TAG) do
		track(inst)
	end
	-- Vague 63 (a210) : pièces soudées des auras de Clément (mouvement, VISUAL EFFECTS OFF).
	CollectionService:GetInstanceAddedSignal(PIECE_TAG):Connect(trackPiece)
	CollectionService:GetInstanceRemovedSignal(PIECE_TAG):Connect(untrackPiece)
	for _, inst in CollectionService:GetTagged(PIECE_TAG) do
		trackPiece(inst)
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
