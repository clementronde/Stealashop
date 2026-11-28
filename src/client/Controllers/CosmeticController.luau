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
-- Vague GC3 (a283, audit a271 point 5) : une pièce hors de l'écran reste figée (PieceMotion.OnScreenOnly), et sur
-- appareil faible (ShatterController.IsLowEnd, relu toutes les RemoteParticleCheckInterval s) la distance est
-- PieceMotion.MaxDistanceLow. Pièce retirée (aura changée, porteur parti, streaming) : oubliée. VISUAL EFFECTS OFF : pièces cachées en local
-- (LocalTransparencyModifier), mouvement arrêté ; leurs émetteurs, lumières et Beams s'éteignent comme le reste.
-- a541 (L-511, piste A, Features.AuraCarryMode / AuraCarryModeDev) : pendant le port d'un joueur (attribut Carrying du
-- Player), les Attachments de son aura marqués CarryMode par Clément s'éteignent (« Off ») ou baissent (« Dim »), chez
-- tous les joueurs ; tout revient à la fin du port (voir applyCarry).
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

-- a541 (L-511, piste A) : aura pendant le port -------------------------------------------------------------------
-- Allumé par Features.AuraCarryMode partout, ou AuraCarryModeDev dans le jeu DEV (Config/ProductIds.IsDev). Pendant
-- qu'un joueur porte (attribut Carrying du Player, posé par CarryService et répliqué à tous), chaque Attachment de son
-- aura qui porte CarryMode : "Off" = ses émetteurs, lumières et Beams éteints ; "Dim" = débit × CarryAura.DimRate
-- (dans setRates) et Brightness des lumières × CarryAura.DimLight. À la fin du port, tout revient à l'état d'avant.
-- Pièces soudées et trails : inchangés. Avec VISUAL EFFECTS OFF : la coupure du joueur garde la main (table cut).
local CARRY = Cosmetics.CarryAura
-- VISUAL EFFECTS OFF (vague 24, plus bas) : [effet éteint] = Enabled d'origine.
local cut: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local CARRYING_ATTRIBUTE = "Carrying" -- CarryService, sur le Player
local OFF_CLASSES = { "ParticleEmitter", "Light", "Beam" }
local carryLive = false
local carryModes: { [Instance]: string } = {} -- [Attachment d'aura] = mode appliqué ("Off" ou "Dim")
local carryOff: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- [effet éteint] = Enabled d'origine
local carryLights: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any -- [lumière baissée] = Brightness d'origine

local function optionalConfig(name: string): any
	local config = ReplicatedStorage:FindFirstChild("Shared")
	config = if config then config:FindFirstChild("Config") else nil
	local module = if config then config:FindFirstChild(name) else nil
	if module == nil or not module:IsA("ModuleScript") then
		return {}
	end
	local ok, result = pcall(require, module :: any)
	return if ok and type(result) == "table" then result else {}
end

local function carryFactor(aura: Instance): number
	return if carryModes[aura] == "Dim" then CARRY.DimRate else 1
end

local function isOffClass(inst: Instance): boolean
	for _, class in OFF_CLASSES do
		if inst:IsA(class) then
			return true
		end
	end
	return false
end

-- Mode voulu pour cet Attachment d'aura : celui de Clément si son porteur porte un objet, sinon aucun.
local function wantedMode(aura: Instance): string?
	if not carryLive or not aura:IsA("Attachment") or aura:GetAttribute(FX_ATTRIBUTE) == nil then
		return nil
	end
	local mode = aura:GetAttribute(CARRY.Attribute)
	if mode ~= "Off" and mode ~= "Dim" then
		return nil
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil and aura:IsDescendantOf(character) then
			return if player:GetAttribute(CARRYING_ATTRIBUTE) ~= nil then mode :: string else nil
		end
	end
	return nil
end

local function carryOffOne(inst: Instance)
	if carryOff[inst] ~= nil or not isOffClass(inst) then
		return
	end
	local effect = inst :: any
	local was = cut[inst]
	carryOff[inst] = if was ~= nil then was else effect.Enabled == true
	effect.Enabled = false
end

local function applyCarry(aura: Instance)
	local mode = wantedMode(aura)
	local was = carryModes[aura]
	if mode == was then
		return
	end
	for _, child in aura:GetChildren() do
		local original = carryOff[child]
		if original ~= nil then
			carryOff[child] = nil
			if cut[child] ~= nil then
				cut[child] = original -- VISUAL EFFECTS OFF : reste éteint, rallumé à son état d'origine plus tard
			else
				(child :: any).Enabled = original
			end
		end
		local brightness = carryLights[child]
		if brightness ~= nil then
			carryLights[child] = nil;
			(child :: any).Brightness = brightness
		end
	end
	if mode ~= nil then
		carryModes[aura] = mode
	else
		carryModes[aura] = nil
	end
	for _, child in aura:GetChildren() do
		if mode == "Off" then
			carryOffOne(child)
		elseif mode == "Dim" and child:IsA("Light") and carryLights[child] == nil then
			local light = child :: Light
			carryLights[child] = light.Brightness
			light.Brightness = light.Brightness * CARRY.DimLight
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
			carryModes[aura] = nil
			continue
		end
		if carryLive then
			applyCarry(aura) -- a541 : rattrape une copie taggée avant d'être rangée dans le perso
		end
		local mine = own ~= nil and aura:IsDescendantOf(own)
		local far = not mine and (positionOf(aura) - from).Magnitude > CUT_DISTANCE
		setRates(aura, (if reduced then Settings.VfxOff.AuraFactor elseif far then CUT_FACTOR else 1) * carryFactor(aura))
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
-- cut : déclaré plus haut (a541 : lu aussi par l'aura pendant le port).
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
	local carried = carryOff[inst] -- a541 : éteint par le port, on garde l'état d'avant le port
	cut[inst] = if carried ~= nil then carried else effect.Enabled == true
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
local pieceMaxDistance: number = MOTION.MaxDistance -- a283 : MaxDistanceLow sur appareil faible (relu dans Start)

-- Appareil faible : la règle des éclats de vitrine (ShatterController.IsLowEnd), chargée à la demande (même repli
-- que WitnessCrowdController : absente, appareil normal).
local shatter: any = nil
local function lowEnd(): boolean
	if shatter == nil then
		shatter = false
		local parent = script.Parent
		local found = if parent then parent:FindFirstChild("ShatterController") else nil
		if found and found:IsA("ModuleScript") then
			local ok, loaded = pcall(require, found :: any)
			if ok and type(loaded) == "table" and type((loaded :: any).IsLowEnd) == "function" then
				shatter = loaded
			end
		end
	end
	if not shatter then
		return false
	end
	local ok, result = pcall(shatter.IsLowEnd)
	return ok and result == true
end

-- a283 : la sphère (center, radius) coupe le champ de la caméra (même test que ItemIdleController.isOnScreen).
-- Caméra sans taille d'écran (pas encore prête) : à l'écran.
local function sphereOnScreen(camera: Camera, center: Vector3, radius: number): boolean
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return true
	end
	local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
	local tanH = tanV * viewport.X / viewport.Y
	local inCamera = camera.CFrame:PointToObjectSpace(center)
	local depth = -inCamera.Z
	if depth < -radius then
		return false -- derrière la caméra
	end
	return math.abs(inCamera.X) <= depth * tanH + radius * math.sqrt(1 + tanH * tanH)
		and math.abs(inCamera.Y) <= depth * tanV + radius * math.sqrt(1 + tanV * tanV)
end

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
	local camera = if MOTION.OnScreenOnly then Workspace.CurrentCamera else nil
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
		if from ~= nil and (anchor.Position - from).Magnitude > pieceMaxDistance then
			continue
		end
		-- a283 : hors de l'écran, figée (sphère : écart de la pièce à son accroche, sa taille, la marge).
		local reach = piece.base.Position.Magnitude + piece.size.Magnitude + MOTION.ScreenMargin
		if camera ~= nil and not sphereOnScreen(camera, anchor.Position, reach) then
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
			if inst.Parent ~= nil and carryOff[inst] == nil then -- a541 : pendant le port, il reste éteint
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
		applyCarry(inst) -- a541 : aura arrivée pendant un port (streaming, aura changée)
	end
end

-- a541 : port commencé ou fini chez ce joueur : ses Attachments d'aura prennent ou rendent leur CarryMode.
local function refreshCarry()
	for aura in auras do
		if aura.Parent ~= nil then
			applyCarry(aura)
		end
	end
	update()
end

local function watchCarry(player: Player)
	player:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshCarry)
end

function CosmeticController.Start()
	-- a541 (L-511) : aura pendant le port, lu une fois au démarrage.
	local features = optionalConfig("Features")
	carryLive = features.AuraCarryMode == true or (features.AuraCarryModeDev == true and optionalConfig("ProductIds").IsDev == true)
	if carryLive then
		Players.PlayerAdded:Connect(watchCarry)
		for _, player in Players:GetPlayers() do
			watchCarry(player)
		end
	end
	CollectionService:GetInstanceAddedSignal(AURA_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(AURA_TAG):Connect(function(inst: Instance)
		auras[inst] = nil
		carryModes[inst] = nil
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
		-- a541 : effet arrivé sous un Attachment éteint pendant le port.
		local parent = inst.Parent
		if parent ~= nil and carryModes[parent] == "Off" then
			carryOffOne(inst)
		end
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
			if motionConnection ~= nil then
				pieceMaxDistance = if lowEnd() then MOTION.MaxDistanceLow else MOTION.MaxDistance -- a283
			end
		end
	end)
end

return CosmeticController
