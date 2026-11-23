--!strict
-- ShopBuildController (a406, vague GC4 ; liaison L-297, Clément, 2026-11-23 ; fiche vidéo de Cantin
-- docs/references/Achat-Progressif-Base.md pour ce que L-297 ne dit pas) : la partie neuve de la boutique d'un
-- joueur s'assemble « en mode Lego », pièce par pièce, côté client seulement. Le serveur pose la partie d'un coup,
-- comme avant ; ici, rien n'est répliqué et l'état final est toujours celui du serveur.
--
-- Les trois moments de L-297, vus chez tous les joueurs (attributs du propriétaire, répliqués à tous) :
--   - présentoir acheté : l'attribut DisplaySlotsLevel du propriétaire monte (achat, ShopService) ; le présentoir
--     débloqué `DisplayStand_xx` (xx = Balance.Display.StartSlots + niveau) et son `SocleDecor`, que RayonService
--     rend au même moment. Pas encore arrivé (réplication) : attendu ShopBuild.FindTimeout s ;
--   - niveau de résistance : l'attribut Skill_GlassThickness du propriétaire monte ; chaque `Look_n` de la
--     parcelle (dans la boutique et dans Floor_2). Facultatif : sans Look_n, rien ;
--   - étage acheté : un `Floor_2` arrive dans la parcelle (pas dans les ShopBuild.SettleTime s qui suivent
--     l'arrivée de la parcelle ou de son propriétaire : chargement). Facultatif.
--   Un niveau qui monte de plus de ShopBuild.MaxStep, ou depuis rien (chargement du profil), n'anime rien ; une
--   partie à plus de ShopBuild.MaxDistance de la caméra non plus ; VISUAL EFFECTS sur OFF ou « Réduire les
--   mouvements » de Roblox non plus. Dans ces cas, tout apparaît d'un coup, comme avant.
--
-- Séquence (L-297, réglages lus dans les attributs de Assets/FX/FX_ShopUpgrade_Build, repli Config/ShopBuild) :
--   1. dès le déclenchement, toutes les pièces de la partie sont cachées en local (LocalTransparencyModifier = 1,
--      pièces et Decal/Texture ; une pièce qui arrive pendant la construction aussi) ; copie locale de l'effet au
--      pied de la partie, `Bills:Emit` ;
--   2. StartDelay s après : pièces visibles (Transparency < 1) triées par le bas de leur boîte ; une pièce
--      (fantôme local sans collision, copie de la vraie) part de sa place + (±DropJitter, DropHeight, ±DropJitter),
--      penchée au hasard de ±DropTilt, et arrive à sa place en DropTime (courbe Back, BackOvershoot) ; une pièce
--      toutes les PieceDelay s (présentoir) ou BrickDelay s (look, étage) ;
--   3. à l'arrivée : le fantôme part, la vraie pièce se montre, `Burst` sous la pièce et `Puff:Emit`, un clic
--      (ShopBuild.PopSound, un demi-ton plus haut à chaque pièce, au plus ShopBuild.MaxPopsPerSecond par seconde ;
--      en 2D chez le propriétaire, sur la pièce chez les autres ; son absent : muet) ;
--   4. à la dernière : tout le reste se montre, `Burst` au sommet, `Sparks:Emit`, petit tremblement de caméra.
--   Look et étage (L-297 Q1, V0) : les ShopBuild.MaxPieces plus grosses pièces tombent, le reste arrive avec la
--   dernière, l'écart est réduit pour tenir en ShopBuild.MaxDuration s.
-- La vraie pièce garde sa place et ses collisions pendant toute l'animation (seule sa transparence locale change) ;
-- lumières, SurfaceGui et effets de la partie ne sont pas touchés.
--
-- Panneau d'achat des présentoirs (fiche vidéo, section 3) : pendant une construction et ShopBuild.SignReturnDelay s
-- après, la parcelle porte l'attribut LOCAL ShopBuild.BusyAttribute = true (posé ici, jamais répliqué) ;
-- UpgradeController y cache le panneau puis le fait revenir avec un pop.
--
-- Effet FX_ShopUpgrade_Build absent : pas de particules, la construction a lieu quand même (orange au
-- ContractChecker).
--
-- API (client) :
--   ShopBuildController.Play(plot, root, kind?) -> boolean
--       Construit `root` (pièce ou modèle de la parcelle `plot`) pièce par pièce ; kind "Stand" (défaut), "Look"
--       ou "Floor" (écarts et plafond de pièces). false si rien ne s'anime (coupé, loin, déjà en cours).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Settings = require(Config:WaitForChild("Settings"))
local ShopBuild = require(Config:WaitForChild("ShopBuild"))
local SkillTree = require(Config:WaitForChild("SkillTree"))
local ShopBuildPlan = require(Shared:WaitForChild("ShopBuildPlan"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))

type Kind = "Stand" | "Look" | "Floor"

type Params = {
	StartDelay: number,
	PieceDelay: number,
	BrickDelay: number,
	DropTime: number,
	DropHeight: number,
	DropJitter: number,
	DropTilt: number,
	BackOvershoot: number,
}

type Piece = {
	part: BasePart,
	start: number,
	offset: Vector3,
	tiltX: number,
	tiltZ: number,
	ghost: BasePart?,
	target: CFrame?,
	landed: boolean,
}

type Build = {
	plot: Instance,
	root: Instance,
	kind: Kind,
	hidden: { [Instance]: number }, -- instance cachée -> LocalTransparencyModifier d'avant
	added: RBXScriptConnection?,
	launchAt: number,
	pieces: { Piece }?,
	rest: { BasePart },
	params: Params,
	fx: Model?,
	burst: Attachment?,
	fxLife: number,
	pops: number,
	lastPop: number,
	owner: Player?,
}

local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local FX_FOLDER_NAME = "_ShopBuildFx" -- dossier local du Workspace (fantômes et copies de l'effet)
local GHOST_NAME = "ShopBuildPiece"
local SHAKE_STEP = "ShopBuildShake"
local GLASS_ATTRIBUTE = SkillTree.AttributePrefix .. ShopBuild.GlassSkill

local localPlayer = Players.LocalPlayer
local rng = Random.new()

local ShopBuildController = {}

local builds: { [Instance]: Build } = {} -- racine de la partie -> construction en cours
local busyCount: { [Instance]: number } = {}
local loop: RBXScriptConnection? = nil
local plotWatch: { [Instance]: { connections: { RBXScriptConnection }, since: number, ownerSince: number } } = {}
local pendingStands: { [Instance]: { [string]: number } } = {} -- parcelle -> nom attendu -> limite (os.clock)
local lastLevels: { [Player]: { [string]: any } } = {}
local shakeUntil, shakeStart, shakeSeed = 0, 0, 0
local shakeBound = false

------------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------------

local function reduced(): boolean
	if Settings.VfxReduced(localPlayer) then
		return true
	end
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

local function fxFolder(): Folder
	local current = Workspace:FindFirstChild(FX_FOLDER_NAME)
	if current and current:IsA("Folder") then
		return current :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = FX_FOLDER_NAME
	created.Parent = Workspace
	return created
end

local function fxTemplate(): Model?
	local current: Instance? = ReplicatedStorage
	for _, segment in ShopBuild.FxFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(ShopBuild.FxName) else nil
	return if found and found:IsA("Model") then found :: Model else nil
end

-- Réglages de L-297 : attributs du modèle de Clément, sinon Config/ShopBuild.Fallback.
local function paramsOf(template: Model?): Params
	local fallback = ShopBuild.Fallback :: any
	local out: any = {}
	for name, value in fallback do
		local read = if template then template:GetAttribute(name) else nil
		out[name] = if type(read) == "number" and read == read then read else value
	end
	return out :: Params
end

-- Pièces de la partie : `root` lui-même s'il est une pièce, et ses descendants.
local function partsOf(root: Instance): { BasePart }
	local out: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(out, root :: BasePart)
	end
	for _, inst in root:GetDescendants() do
		if inst:IsA("BasePart") then
			table.insert(out, inst :: BasePart)
		end
	end
	return out
end

-- Boîte alignée sur le monde d'une pièce : (bas, haut, centre).
local function extent(part: BasePart): (Vector3, Vector3)
	local cf, size = part.CFrame, part.Size
	local half = Vector3.new(
		(math.abs(cf.XVector.X) * size.X + math.abs(cf.YVector.X) * size.Y + math.abs(cf.ZVector.X) * size.Z) / 2,
		(math.abs(cf.XVector.Y) * size.X + math.abs(cf.YVector.Y) * size.Y + math.abs(cf.ZVector.Y) * size.Z) / 2,
		(math.abs(cf.XVector.Z) * size.X + math.abs(cf.YVector.Z) * size.Y + math.abs(cf.ZVector.Z) * size.Z) / 2
	)
	return cf.Position - half, cf.Position + half
end

-- Boîte de plusieurs pièces : (pied = bas au centre, sommet = haut au centre), ou nil.
local function footAndTop(parts: { BasePart }): (Vector3?, Vector3?)
	local low, high = nil :: Vector3?, nil :: Vector3?
	for _, part in parts do
		local a, b = extent(part)
		low = if low then low:Min(a) else a
		high = if high then high:Max(b) else b
	end
	if low == nil or high == nil then
		return nil, nil
	end
	local bottom, upper = low :: Vector3, high :: Vector3
	local center = (bottom + upper) / 2
	return Vector3.new(center.X, bottom.Y, center.Z), Vector3.new(center.X, upper.Y, center.Z)
end

local function setModifier(inst: Instance, value: number)
	(inst :: any).LocalTransparencyModifier = value
end

local function hideOne(build: Build, inst: Instance)
	if build.hidden[inst] == nil and (inst:IsA("BasePart") or inst:IsA("Decal")) then -- Decal : Texture compris
		build.hidden[inst] = (inst :: any).LocalTransparencyModifier
		setModifier(inst, 1)
	end
end

local function showOne(build: Build, inst: Instance)
	local before = build.hidden[inst]
	if before ~= nil then
		build.hidden[inst] = nil
		setModifier(inst, before)
	end
end

-- La pièce et ses Decal/Texture directs.
local function showPart(build: Build, part: BasePart)
	showOne(build, part)
	for _, child in part:GetChildren() do
		showOne(build, child)
	end
end

local function emit(build: Build, name: string, at: Vector3?)
	local burst = build.burst
	if burst == nil or burst.Parent == nil then
		return
	end
	if at then
		burst.WorldPosition = at
	end
	local emitter = burst:FindFirstChild(name)
	if emitter and emitter:IsA("ParticleEmitter") then
		local count = emitter:GetAttribute(ShopBuild.EmitCountAttribute)
		local fallback = (ShopBuild.EmitFallback :: any)[name] or 1
		local n = if type(count) == "number" and count == count then math.max(0, math.floor(count)) else fallback
		if n > 0 then
			(emitter :: ParticleEmitter):Emit(n)
		end
	end
end

-- Copie locale de l'effet de Clément au pied de la partie (sans collision, ancrée), ou nil.
local function placeFx(build: Build, foot: Vector3)
	local template = fxTemplate()
	if template == nil then
		return
	end
	local ok, copy = pcall(function()
		return template:Clone()
	end)
	if not ok or not copy then
		return
	end
	local fx = copy :: Model
	local life = 0
	for _, inst in fx:GetDescendants() do
		if inst:IsA("BasePart") then
			local part = inst :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		elseif inst:IsA("ParticleEmitter") then
			life = math.max(life, (inst :: ParticleEmitter).Lifetime.Max)
		elseif inst:IsA("LuaSourceContainer") then
			inst:Destroy()
		end
	end
	fx:PivotTo(CFrame.new(foot))
	fx.Parent = fxFolder()
	build.fx = fx
	build.fxLife = life
	local burst = fx:FindFirstChild(ShopBuild.BurstName, true)
	build.burst = if burst and burst:IsA("Attachment") then burst :: Attachment else nil
end

-- Fantôme local d'une pièce : même forme et même aspect, sans enfants (hors Decal, Texture, maillage, surface),
-- sans tag, sans collision.
local function makeGhost(part: BasePart): BasePart?
	local ok, copy = pcall(function()
		return part:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local ghost = copy :: BasePart
	for _, child in ghost:GetChildren() do
		if not (child:IsA("Decal") or child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance")) then
			child:Destroy()
		else
			setModifier(child, 0)
		end
	end
	for _, tag in ghost:GetTags() do
		ghost:RemoveTag(tag)
	end
	ghost.Name = GHOST_NAME
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	setModifier(ghost, 0)
	ghost.Parent = fxFolder()
	return ghost
end

local function playPop(build: Build, part: BasePart)
	local now = os.clock()
	if now - build.lastPop < 1 / ShopBuild.MaxPopsPerSecond then
		return
	end
	local template = MarkerSounds.find(ShopBuild.PopSound)
	if template == nil then
		return
	end
	build.lastPop = now
	build.pops += 1
	local sound = template:Clone()
	sound.PlaybackSpeed = template.PlaybackSpeed * ShopBuildPlan.pitch(build.pops, ShopBuild.PitchStep, ShopBuild.PitchMax)
	sound.Parent = if build.owner == localPlayer then SoundService else part
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 3)
	sound:Play()
end

------------------------------------------------------------------------------
-- Tremblement de caméra (fin de construction)
------------------------------------------------------------------------------

local function applyShake()
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	if now >= shakeUntil or camera == nil then
		if shakeBound then
			shakeBound = false
			RunService:UnbindFromRenderStep(SHAKE_STEP)
		end
		return
	end
	local shake = ShopBuild.Shake
	local t = (now - shakeStart) / shake.Duration
	local decay = (1 - t) * (1 - t)
	local wave = now * shake.Frequency
	local move = shake.Amplitude * decay * 2 -- math.noise reste à peu près dans ± 0,5
	local turn = shake.Angle * decay * 2
	local offset = Vector3.new(math.noise(wave, shakeSeed, 0.1), math.noise(shakeSeed, wave, 0.2), math.noise(0.3, shakeSeed, wave)) * move
	camera.CFrame = camera.CFrame
		* CFrame.new(offset)
		* CFrame.Angles(math.noise(wave, shakeSeed, 1.1) * turn, math.noise(wave, shakeSeed, 2.3) * turn, 0)
end

local function shakeNear(at: Vector3)
	local camera = Workspace.CurrentCamera
	local shake = ShopBuild.Shake
	if camera == nil or shake.Duration <= 0 or (camera.CFrame.Position - at).Magnitude > shake.Range then
		return
	end
	shakeStart = os.clock()
	shakeUntil = shakeStart + shake.Duration
	shakeSeed = rng:NextNumber(1, 1000)
	if not shakeBound then
		shakeBound = true
		RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 2, applyShake)
	end
end

------------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------------

local function setBusy(plot: Instance, delta: number)
	local count = math.max(0, (busyCount[plot] or 0) + delta)
	if count > 0 then
		busyCount[plot] = count
		plot:SetAttribute(ShopBuild.BusyAttribute, true)
	else
		busyCount[plot] = nil
		plot:SetAttribute(ShopBuild.BusyAttribute, nil)
	end
end

local function finish(build: Build)
	if builds[build.root] ~= build then
		return
	end
	builds[build.root] = nil
	local added = build.added
	if added then
		added:Disconnect()
	end
	local pieces: { Piece } = build.pieces or {}
	for _, piece in pieces do
		local ghost = piece.ghost
		if ghost then
			ghost:Destroy()
		end
	end
	for inst in table.clone(build.hidden) do
		showOne(build, inst)
	end
	local fx = build.fx
	if fx then
		Debris:AddItem(fx, build.fxLife + 0.5)
	end
	local plot = build.plot
	task.delay(ShopBuild.SignReturnDelay, function()
		setBusy(plot, -1)
	end)
end

-- Départ des pièces (StartDelay s après le déclenchement).
local function launch(build: Build)
	local items: { ShopBuildPlan.Item } = {}
	local visible: { BasePart } = {}
	for _, part in partsOf(build.root) do
		if part.Transparency < 1 then
			local low, high = extent(part)
			local size = high - low
			table.insert(visible, part)
			table.insert(items, { bottom = low.Y, volume = size.X * size.Y * size.Z })
		end
	end
	local params = build.params
	local maxPieces = if build.kind == "Stand" then ShopBuild.StandMaxPieces else ShopBuild.MaxPieces
	local delay = if build.kind == "Stand" then params.PieceDelay else params.BrickDelay
	local order, rest, step = ShopBuildPlan.plan(items, maxPieces, delay, params.DropTime, ShopBuild.MaxDuration)
	local now = os.clock()
	local pieces: { Piece } = {}
	for rank, index in order do
		local jitter, tilt = params.DropJitter, params.DropTilt
		table.insert(pieces, {
			part = visible[index],
			start = now + (rank - 1) * step,
			offset = Vector3.new(rng:NextNumber(-jitter, jitter), params.DropHeight, rng:NextNumber(-jitter, jitter)),
			tiltX = rng:NextNumber(-tilt, tilt),
			tiltZ = rng:NextNumber(-tilt, tilt),
			ghost = nil,
			target = nil,
			landed = false,
		})
	end
	for _, index in rest do
		table.insert(build.rest, visible[index])
	end
	build.pieces = pieces
end

local function land(build: Build, piece: Piece)
	piece.landed = true
	local ghost = piece.ghost
	if ghost then
		piece.ghost = nil
		ghost:Destroy()
	end
	local part = piece.part
	showPart(build, part)
	if part.Parent ~= nil then
		local low, high = extent(part)
		emit(build, ShopBuild.PuffName, Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2))
		playPop(build, part)
	end
end

local function complete(build: Build)
	for _, part in build.rest do
		showPart(build, part)
	end
	local _, top = footAndTop(partsOf(build.root))
	if top then
		emit(build, ShopBuild.SparksName, top)
		shakeNear(top)
	end
	finish(build)
end

-- Une image d'une construction. false : terminée.
local function stepBuild(build: Build, now: number): boolean
	if now < build.launchAt then
		return true
	end
	local pieces = build.pieces
	if pieces == nil then
		launch(build)
		pieces = build.pieces
	end
	local params = build.params
	local all = true
	for _, piece in pieces :: { Piece } do
		if piece.landed then
			continue
		end
		if now < piece.start then
			all = false
			continue
		end
		local part = piece.part
		if part.Parent == nil then
			land(build, piece)
			continue
		end
		local alpha = if params.DropTime > 0 then (now - piece.start) / params.DropTime else 1
		if alpha >= 1 then
			land(build, piece)
			continue
		end
		all = false
		local target = piece.target
		if target == nil then
			target = part.CFrame
			piece.target = target
			local made = makeGhost(part)
			piece.ghost = made
			if not made then
				land(build, piece) -- pièce qu'on ne peut pas copier : elle se montre à son tour
				continue
			end
		end
		local ghost = piece.ghost
		if ghost then
			local a = ShopBuildPlan.backOut(alpha, params.BackOvershoot)
			local left = 1 - a
			local goal = target :: CFrame
			ghost.CFrame = CFrame.new(goal.Position + piece.offset * left)
				* goal.Rotation
				* CFrame.Angles(piece.tiltX * left, 0, piece.tiltZ * left)
		end
	end
	if all then
		complete(build)
		return false
	end
	return true
end

local function onFrame()
	local now = os.clock()
	for _, build in table.clone(builds) do
		local ok, result = pcall(stepBuild, build, now)
		if not ok then
			warn(`[ShopBuildController] {build.root:GetFullName()} : {result} (partie montrée d'un coup)`)
			finish(build)
		end
	end
	if next(builds) == nil and loop then
		loop:Disconnect()
		loop = nil
	end
end

local function ownerOf(plot: Instance): Player?
	local id = plot:GetAttribute(OWNER_ATTRIBUTE)
	return if type(id) == "number" and id ~= 0 then Players:GetPlayerByUserId(id) else nil
end

function ShopBuildController.Play(plot: Instance, root: Instance, kind: string?): boolean
	if not ShopBuild.Enabled or builds[root] ~= nil or root.Parent == nil or reduced() then
		return false
	end
	local parts = partsOf(root)
	local foot = footAndTop(parts)
	local camera = Workspace.CurrentCamera
	if foot == nil or camera == nil or (camera.CFrame.Position - foot).Magnitude > ShopBuild.MaxDistance then
		return false
	end
	local template = fxTemplate()
	local params = paramsOf(template)
	local build: Build = {
		plot = plot,
		root = root,
		kind = if kind == "Look" or kind == "Floor" then kind else "Stand",
		hidden = {},
		added = nil,
		launchAt = os.clock() + params.StartDelay,
		pieces = nil,
		rest = {},
		params = params,
		fx = nil,
		burst = nil,
		fxLife = 0,
		pops = 0,
		lastPop = -math.huge,
		owner = ownerOf(plot),
	}
	hideOne(build, root)
	for _, inst in root:GetDescendants() do
		hideOne(build, inst)
	end
	build.added = root.DescendantAdded:Connect(function(inst: Instance)
		hideOne(build, inst) -- arrivée pendant la construction (streaming) : montrée à la fin
	end)
	builds[root] = build
	setBusy(plot, 1)
	placeFx(build, foot)
	emit(build, ShopBuild.BillsName, foot)
	if loop == nil then
		loop = RunService.RenderStepped:Connect(onFrame)
	end
	return true
end

------------------------------------------------------------------------------
-- Déclenchement
------------------------------------------------------------------------------

local function plotOf(player: Player): Instance?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId and plot:IsDescendantOf(Workspace) then
			return plot
		end
	end
	return nil
end

local function wantStand(plot: Instance, name: string)
	local found = plot:FindFirstChild(name, true)
	if found then
		ShopBuildController.Play(plot, found, "Stand")
		return
	end
	local pending = pendingStands[plot] or {}
	pendingStands[plot] = pending
	pending[name] = os.clock() + ShopBuild.FindTimeout
end

local function onLevel(player: Player, attribute: string)
	local levels = lastLevels[player]
	if levels == nil then
		return
	end
	local old, new = levels[attribute], player:GetAttribute(attribute)
	levels[attribute] = new
	if not ShopBuildPlan.isPurchase(old, new, ShopBuild.MaxStep) then
		return
	end
	local plot = plotOf(player)
	if plot == nil then
		return
	end
	local from, to = old :: number, new :: number -- nombres : vérifié par isPurchase
	if attribute == ShopBuild.SlotsAttribute then
		for _, number in ShopBuildPlan.newStands(Balance.Display.StartSlots, from, to) do
			wantStand(plot, string.format(ShopBuild.StandFormat, number))
		end
	else
		for level = math.floor(from) + 1, math.floor(to) do
			local name = string.format(ShopBuild.LookFormat, level)
			for _, inst in plot:GetDescendants() do
				if inst.Name == name then
					ShopBuildController.Play(plot, inst, "Look")
				end
			end
		end
	end
end

local function watchPlayer(player: Player)
	if lastLevels[player] then
		return
	end
	lastLevels[player] = {
		[ShopBuild.SlotsAttribute] = player:GetAttribute(ShopBuild.SlotsAttribute),
		[GLASS_ATTRIBUTE] = player:GetAttribute(GLASS_ATTRIBUTE),
	}
	for _, attribute in { ShopBuild.SlotsAttribute, GLASS_ATTRIBUTE } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			onLevel(player, attribute)
		end)
	end
end

local function onPlotDescendant(plot: Instance, inst: Instance)
	local pending = pendingStands[plot]
	local limit: number = if pending then pending[inst.Name] or -1 else -1
	if pending and limit >= 0 then
		pending[inst.Name] = nil
		if next(pending) == nil then
			pendingStands[plot] = nil
		end
		if os.clock() <= limit then
			ShopBuildController.Play(plot, inst, "Stand")
		end
		return
	end
	local watch = plotWatch[plot]
	if inst.Name == ShopBuild.FloorName and watch and ownerOf(plot) ~= nil then
		local now = os.clock()
		if now - watch.since >= ShopBuild.SettleTime and now - watch.ownerSince >= ShopBuild.SettleTime then
			ShopBuildController.Play(plot, inst, "Floor")
		end
	end
end

local function watchPlot(plot: Instance)
	if plotWatch[plot] then
		return
	end
	local now = os.clock()
	local watch = { connections = {} :: { RBXScriptConnection }, since = now, ownerSince = now }
	plotWatch[plot] = watch
	table.insert(
		watch.connections,
		plot.DescendantAdded:Connect(function(inst: Instance)
			onPlotDescendant(plot, inst)
		end)
	)
	table.insert(
		watch.connections,
		plot:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(function()
			watch.ownerSince = os.clock()
		end)
	)
end

local function unwatchPlot(plot: Instance)
	local watch = plotWatch[plot]
	if watch then
		for _, connection in watch.connections do
			connection:Disconnect()
		end
		plotWatch[plot] = nil
	end
	pendingStands[plot] = nil
end

function ShopBuildController.Start()
	if not ShopBuild.Enabled then
		return
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(plot)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastLevels[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return ShopBuildController
