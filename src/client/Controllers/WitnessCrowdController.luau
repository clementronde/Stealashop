--!strict
-- WitnessCrowdController (client, vague 66, a221 ; Clément, L-210 point 4) : « à la sortie du magasin avec l'objet sur
-- la tête, une foule de PNJ autour du magasin regarde le braquage ». Vague 71 (a236 ; Clément, L-219 point 1, L-220
-- point 2, L-223) : les personnes de Clément, leurs rôles et leurs accessoires, rangées des deux côtés du passage qui
-- part de la vitrine. Valeurs : Config/Witness.Crowd (V0) ; interrupteur : Features.WitnessCrowd.
--
-- Purement visuel, chez chaque joueur : aucun remote, rien d'écrit sur le serveur, rien d'enregistré dans la place.
--   1. Toutes les Crowd.CheckInterval s, pour chaque joueur qui porte un objet (attribut Carrying du Player, posé par
--      CarryService) : le magasin taggé NPCStore dont le volume Bounds contient son HumanoidRootPart est noté ; dès qu'il
--      en sort en portant toujours, la foule de ce magasin se forme (au plus une par magasin toutes les Crowd.Cooldown s,
--      au plus Crowd.MaxCrowds à la fois, seulement si le voleur est à moins de Crowd.ViewDistance studs de la caméra,
--      et pas la nuit sauf Crowd.AtNight).
--   2. Les personnes : des copies des modèles ReplicatedStorage/Assets/Crowd/Models/NPC_Crowd_* de Clément (L-223),
--      mélangées ; sans eux, des copies des témoins NPC_Witness_* présents chez ce joueur (tag WitnessGauge.Tag ; d'abord
--      ceux qui regardent ce magasin, attribut WatchedStore), comme avant. Rangées dans Workspace/Crowd.Folder.
--   3. Placement (L-219 point 1, L-220 point 2) : personne devant la vitrine ; Crowd.PerSide personnes de chaque côté
--      du passage qui part de la vitrine (largeur : celle de la vitrine, entre Crowd.PassageMin et Crowd.PassageMax),
--      de Crowd.Start à Crowd.Start + Crowd.Length studs, plus serrées en s'éloignant (Crowd.Spread), une sur deux un
--      rang derrière (Crowd.RowGap) ; posées au sol, tournées vers le voleur (revu toutes les Crowd.TurnInterval s).
--      Aucun tapis, aucune barrière. Sur la copie : tag et attributs du témoin retirés, scripts retirés, racine ancrée,
--      ni collision, ni requête, ni contact (joueurs et vigile passent à travers), machine d'états du Humanoid coupée.
--   4. Rôles (Crowd.Roles, tirés au hasard selon leur poids) : pour le voleur (Cheer, ou HoldSign + une pancarte Side
--      "For" de Assets/Crowd/Props), contre (Boo, ou HoldSign + pancarte "Against"), crieur (Shout), photographe
--      (TakePhoto + ACC_Temoin_Telephone ; flash FX_Witness_Flash à chaque marqueur Flash, par
--      WitnessController.PlayFlash ; sans marqueur, toutes les Crowd.FlashMin à Crowd.FlashMax s). L'animation est lue
--      par son nom dans le dossier Animations du modèle ; absente (ou pancarte absente) : photographe ; sans TakePhoto
--      non plus : pose de repos. Le marqueur Shout (Crowd.ShoutMarker) est exposé par OnShout (son : point 7).
--   5. Apparition et disparition en Crowd.FadeTime s (LocalTransparencyModifier), au bout de Crowd.Duration s ;
--      « animations réduites » (Settings.VfxReduced ou ReducedMotionEnabled de Roblox) : ni fondu, ni flash.
--   6. Coût : appareil faible (ShatterController.IsLowEnd : effets coupés, moins de 40 i/s ou qualité graphique ≤ 3) :
--      Crowd.PerSideLow par côté, Crowd.MaxCrowdsLow foule à la fois, regard revu toutes les Crowd.TurnIntervalLow s.
--      Vague 72 (a240) : les places et les rôles sont tirés d'un coup, mais les personnes sont créées sur plusieurs
--      images (au plus Crowd.BuildPerFrame par image, arrêt dès Crowd.BuildBudget s dépensées, au moins une) ; chacune
--      fait son fondu d'entrée depuis sa création. La plus longue image de création : GetStats().FrameMs.
--   7. Sons (vague 72, a240, L-229 ; Crowd.Sounds, 3D sur la racine de la personne, MarkerSounds.find, absent = muet) :
--      au marqueur Shout, un son de Roles[].Sounds ; à chaque flash d'un photographe, Sounds.Photo (parfois
--      Sounds.Burst) ; à la casse d'une vitrine de magasin PNJ (WindowController.OnBroken), Sounds.Gasp sur la vitrine.
--      Au plus Sounds.Voices cris et Sounds.PhotoVoices photos à la fois ; rien sur une personne dont le son joue encore.
--   8. Écart (a269, Cantin, 20/11 ; Crowd.Spacing, V0) : deux personnes jamais plus proches que la largeur réelle des
--      modèles tirés (empreinte au sol de GetExtentsSize) + Spacing.Margin. Une place trop proche d'une personne de
--      cette foule ou d'une foule voisine, d'un témoin vu chez ce joueur ou du circuit WitnessPaths de la zone recule
--      vers la rue (ou un rang derrière) par pas de Spacing.Step, au plus Spacing.MaxPush studs ; sinon elle reste vide.
--
-- API (client, pour un test dans Studio) :
--   WitnessCrowdController.GetCrowds() -> { { Store: Model, Thief: Player, Members: { Model } } }
--   WitnessCrowdController.GetCount() -> number      foules formées chez ce joueur depuis le début
--   WitnessCrowdController.GetStats() -> { Members, Parts, Tracks, Shouts, Pending, FrameMax, FrameMs, Voices, Sounds, Gap }
--     Pending : personnes encore à créer ; FrameMax et FrameMs : le plus de personnes et de millisecondes passées à en
--     créer en une image ; Voices : sons de foule en cours ; Sounds : sons de foule lancés depuis le début ;
--     Gap : écart (studs) entre deux personnes de la dernière foule (a269, 0 sans Crowd.Spacing)
--   WitnessCrowdController.OnShout(callback: (model: Model, role: string) -> ())   à chaque marqueur Shout

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Witness = require(Config:WaitForChild("Witness"))
local Features = require(Config:WaitForChild("Features"))
local Settings = require(Config:WaitForChild("Settings"))
local WitnessGauge = require(Shared:WaitForChild("WitnessGauge"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local WitnessController = require(script.Parent:WaitForChild("WitnessController"))

export type CrowdInfo = { Store: Model, Thief: Player, Members: { Model } }
export type CrowdStats = {
	Members: number,
	Parts: number,
	Tracks: number,
	Shouts: number,
	Pending: number,
	FrameMax: number,
	FrameMs: number,
	Voices: number,
	Sounds: number,
	Gap: number,
}

type Role = Witness.CrowdRole

type Member = {
	model: Model,
	root: BasePart,
	parts: { BasePart }, -- celles qui se voient (fondu)
	role: string,
	sounds: { string }?, -- a240 : ceux de son rôle (marqueur Shout)
	voice: Sound?, -- a240 : son dernier son lancé
	bornAt: number, -- a240 : créée à cette heure (son fondu d'entrée)
	track: AnimationTrack?,
	photographer: boolean,
	markerSeen: boolean,
	nextFlashAt: number,
	links: { RBXScriptConnection },
}

-- a240 : une personne encore à créer (place et rôle déjà tirés).
type Pending = { template: Model, index: number, at: Vector3, role: Role? }

type Crowd = {
	store: Model,
	thief: Player,
	members: { Member },
	pending: { Pending }, -- a240 : créées sur plusieurs images, dans l'ordre
	nextPending: number,
	ignore: { Instance },
	startedAt: number,
	endsAt: number,
	nextTurnAt: number,
	turnInterval: number,
	opaque: boolean, -- fondu d'entrée fini et appliqué : plus rien à écrire jusqu'à la sortie
}

local CROWD = Witness.Crowd
local SOUNDS = CROWD.Sounds
local PHOTO = Witness.Photo
local IS_STUDIO = RunService:IsStudio()

-- Noms du contrat lus ici.
local STORE_TAG = "NPCStore"
local BOUNDS = "Bounds"
local WINDOW = "Window"
local CARRYING = "Carrying" -- attribut du Player (CarryService)
local WATCHED = "WatchedStore"
local FLASH_MARKER = "Flash"
local ANIMATIONS = "Animations"
local NIGHT_PHASE = "NightPhase" -- attribut du Workspace (NightCycleService)
local PATHS_NAME = "WitnessPaths" -- a269 : les circuits des témoins (Clément), comme WitnessService
local PATH_POINT_PATTERN = "^WitnessPath_(%d+)$"
local GAUGE_ATTRIBUTES = {
	WitnessGauge.StateAttribute,
	WitnessGauge.FillAttribute,
	WitnessGauge.RateAttribute,
	WitnessGauge.AtAttribute,
	WitnessGauge.FlashAttribute,
}

local WitnessCrowdController = {}

local localPlayer = Players.LocalPlayer
local crowds: { Crowd } = {}
local lastAt: { [Model]: number } = {} -- dernière foule de chaque magasin (os.clock)
local insideOf: { [Player]: Model } = {} -- le magasin où le porteur se trouvait au dernier contrôle
local boundsCache: { [Model]: BasePart } = {}
local shoutListeners: { (Model, string) -> () } = {}
local nextCheckAt = 0
local formed = 0
local shouts = 0
local rng = Random.new()
local said: { [string]: boolean } = {}
local frameMax = 0 -- a240 : le plus de personnes créées en une image
local frameMs = 0 -- a240 : le plus de ms passées à en créer en une image
local cries: { Sound } = {} -- a240 : cris de foule en cours
local photos: { Sound } = {} -- a240 : sons de photo en cours
local soundsPlayed = 0
local lastGap = 0 -- a269 : écart (studs) de la dernière foule formée avec Crowd.Spacing

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[WitnessCrowd] {message}`)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function reduced(): boolean
	if Settings.VfxReduced(localPlayer) then
		return true
	end
	local ok, value = pcall(function(): any
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- Appareil faible : la règle des éclats de vitrine (ShatterController.IsLowEnd), chargée à la demande.
local shatter: any = nil
local function lowEnd(): boolean
	if shatter == nil then
		shatter = false
		local found = script.Parent:FindFirstChild("ShatterController")
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

-- Sons (a240, L-229) ----------------------------------------------------------------------------------

-- Shared/Anim/MarkerSounds, chargé à la demande (absent : muet).
local markers: any = nil
local function markerSounds(): any
	if markers == nil then
		markers = false
		local anim = Shared:FindFirstChild("Anim")
		local found = if anim then anim:FindFirstChild("MarkerSounds") else nil
		if found and found:IsA("ModuleScript") then
			local ok, loaded = pcall(require, found :: any)
			if ok and type(loaded) == "table" then
				markers = loaded
			end
		end
	end
	return markers
end

local function playing(sound: Sound?): boolean
	return sound ~= nil and sound.Parent ~= nil and sound.IsPlaying
end

-- Les sons de `pool` encore en cours (les autres sont oubliés).
local function busy(pool: { Sound }): number
	for index = #pool, 1, -1 do
		if not playing(pool[index]) then
			table.remove(pool, index)
		end
	end
	return #pool
end

-- Joue le son `name` (3D sur `at`) si `pool` a une place ; renvoie la copie jouée, ou nil (absent, plein, coupé).
local function playIn(pool: { Sound }?, limit: number, name: string, at: Instance): Sound?
	if not SOUNDS.Enabled or name == "" then
		return nil
	end
	if pool and busy(pool) >= limit then
		return nil
	end
	local module = markerSounds()
	if not module then
		return nil
	end
	local ok, result = pcall(function(): Sound?
		local template = module.find(name)
		if template == nil then
			return nil
		end
		return module.playSound(template, at)
	end)
	local sound: Sound? = if ok then result else nil
	if sound == nil then
		sayOnce(`sound:{name}`, `son « {name} » absent de Assets/Sounds (L-229) : muet`)
		return nil
	end
	soundsPlayed += 1
	if pool then
		table.insert(pool, sound)
	end
	return sound
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root :: BasePart else nil
end

local function pathFrom(segments: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in segments do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

-- Magasins ------------------------------------------------------------------------------------------

local function boundsOf(store: Model): BasePart?
	local cached = boundsCache[store]
	if cached and cached:IsDescendantOf(store) then
		return cached
	end
	local found = store:FindFirstChild(BOUNDS, true)
	if found and found:IsA("BasePart") then
		boundsCache[store] = found :: BasePart
		return found :: BasePart
	end
	return nil
end

local function inside(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function storeAt(position: Vector3): Model?
	for _, inst in CollectionService:GetTagged(STORE_TAG) do
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) then
			local bounds = boundsOf(inst :: Model)
			if bounds and inside(bounds, position) then
				return inst :: Model
			end
		end
	end
	return nil
end

-- Le centre de la vitrine, sa normale horizontale du côté de `toward` (comme WitnessService.photoSpot) et sa largeur.
local function windowFrame(store: Model, toward: Vector3): (Vector3, Vector3?, number)
	local window = Find.path(store, WINDOW)
	local center = store:GetPivot().Position
	local axis: Vector3? = nil
	local width = 0
	if window and window:IsA("BasePart") then
		local part = window :: BasePart
		center = part.Position
		local a = flat(if part.Size.X <= part.Size.Z then part.CFrame.RightVector else part.CFrame.LookVector)
		axis = if a.Magnitude > 1e-3 then a.Unit else nil
		width = math.max(part.Size.X, part.Size.Z)
	elseif window and window:IsA("Model") then
		local frame, size = (window :: Model):GetBoundingBox()
		center = frame.Position
		local a = flat(if size.X <= size.Z then frame.RightVector else frame.LookVector)
		axis = if a.Magnitude > 1e-3 then a.Unit else nil
		width = math.max(size.X, size.Z)
	end
	local side = flat(toward - center)
	local out: Vector3
	if axis then
		out = axis
	elseif side.Magnitude > 1e-3 then
		out = side.Unit
	else
		return center, nil, width
	end
	if out:Dot(side) < 0 then
		out = out * -1
	end
	return center, out, width
end

-- Les modèles de Clément (Assets/Crowd/Models/NPC_Crowd_*), dans l'ordre des noms.
local function crowdModels(): { Model }
	local list: { Model } = {}
	local folder = pathFrom(CROWD.Models)
	if folder == nil then
		return list
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, #CROWD.ModelPrefix) == CROWD.ModelPrefix then
			if child:FindFirstChildOfClass("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
				table.insert(list, child :: Model)
			end
		end
	end
	table.sort(list, function(a: Model, b: Model): boolean
		return a.Name < b.Name
	end)
	return list
end

-- Repli d'avant L-223 : les témoins de ce joueur à copier, d'abord ceux qui regardent ce magasin, sinon tous.
local function witnessTemplates(store: Model): { Model }
	local mine: { Model } = {}
	local others: { Model } = {}
	for _, inst in CollectionService:GetTagged(WitnessGauge.Tag) do
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) and inst:FindFirstChildOfClass("Humanoid") then
			if inst:GetAttribute(WATCHED) == store.Name then
				table.insert(mine, inst :: Model)
			else
				table.insert(others, inst :: Model)
			end
		end
	end
	return if #mine > 0 then mine else others
end

-- Accessoires de rôle ---------------------------------------------------------------------------------

local function props(): Instance?
	return pathFrom(CROWD.Props)
end

local function signFor(side: string): Accessory?
	local folder = props()
	if folder == nil then
		return nil
	end
	local list: { Accessory } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute(CROWD.SideAttribute) == side then
			table.insert(list, child :: Accessory)
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a: Accessory, b: Accessory): boolean
		return a.Name < b.Name
	end)
	return list[rng:NextInteger(1, #list)]
end

local function phone(): Accessory?
	local folder = props()
	local found = if folder then folder:FindFirstChild(PHOTO.Phone) else nil
	return if found and found:IsA("Accessory") then found :: Accessory else nil
end

local function wear(model: Model, accessory: Accessory)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local ok, result = pcall(function(): Instance?
		return accessory:Clone()
	end)
	local made: Instance? = if ok then result else nil
	if made == nil or not made:IsA("Accessory") then
		return
	end
	local copy = made :: Accessory
	local worn = pcall(function()
		humanoid:AddAccessory(copy)
	end)
	if not worn then
		copy:Destroy()
	end
end

-- Rôles ------------------------------------------------------------------------------------------------

local function roleNamed(name: string): Role?
	for _, role in CROWD.Roles do
		if role.Name == name then
			return role
		end
	end
	return nil
end

local function drawRole(): Role?
	local total = 0
	for _, role in CROWD.Roles do
		total += math.max(role.Weight, 0)
	end
	if total <= 0 then
		return roleNamed(CROWD.Photographer)
	end
	local pick = rng:NextNumber(0, total)
	for _, role in CROWD.Roles do
		local weight = math.max(role.Weight, 0)
		if pick < weight then
			return role
		end
		pick -= weight
	end
	return CROWD.Roles[#CROWD.Roles]
end

local function animationOf(model: Model, name: string): Animation?
	local animations = model:FindFirstChild(ANIMATIONS)
	local animation = if animations then animations:FindFirstChild(name) else nil
	return if animation and animation:IsA("Animation") then animation :: Animation else nil
end

-- Le rôle tenu par `model` : celui tiré s'il a son animation et sa pancarte, sinon photographe, sinon aucun.
local function settle(model: Model, wanted: Role?): (Role?, Animation?, Accessory?)
	if wanted then
		local animation = animationOf(model, wanted.Anim)
		local sign: Accessory? = nil
		local side = wanted.Sign
		if side then
			sign = signFor(side)
		end
		if animation and (side == nil or sign ~= nil) then
			return wanted, animation, sign
		end
		if animation and side then
			sayOnce(`sign:{side}`, `aucune pancarte Side = "{side}" dans Assets/Crowd/Props (L-223) : photographe à la place`)
		end
	end
	local fallback = roleNamed(CROWD.Photographer)
	local animation = if fallback then animationOf(model, fallback.Anim) else nil
	if fallback and animation then
		return fallback, animation, nil
	end
	sayOnce(`anim:{model.Name}`, `{model.Name} : ni l'animation de son rôle ni TakePhoto : pose de repos`)
	return nil, nil, nil
end

-- Copies -------------------------------------------------------------------------------------------

local function folder(): Folder
	local found = Workspace:FindFirstChild(CROWD.Folder)
	if found and found:IsA("Folder") then
		return found :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = CROWD.Folder
	made.Parent = Workspace
	return made
end

-- Une copie propre : ni tag, ni attributs de jauge, ni copie de flash, ni script ; rien qui touche le jeu.
local function cleanCopy(template: Model, index: number): (Model?, BasePart?)
	local ok, result = pcall(function(): Instance?
		return template:Clone()
	end)
	local copy: Instance? = if ok then result else nil
	if copy == nil or not copy:IsA("Model") then
		return nil, nil
	end
	local model = copy :: Model
	model.Name = `CrowdNpc_{index}`
	CollectionService:RemoveTag(model, WitnessGauge.Tag)
	for _, name in GAUGE_ATTRIBUTES do
		model:SetAttribute(name, nil)
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil, nil
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			inst:Destroy()
		elseif inst.Name == PHOTO.CodePoint and inst:IsA("Attachment") then
			inst:Destroy() -- l'Attachment de repli du flash du témoin d'origine
		elseif (inst:IsA("Light") or inst:IsA("ParticleEmitter")) and inst.Parent and inst.Parent.Name == PHOTO.PhonePoint then
			inst:Destroy() -- les copies du flash laissées dans le téléphone du témoin d'origine
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function()
			humanoid.EvaluateStateMachine = false -- racine ancrée : rien à calculer (coût)
		end)
	end
	return model, root :: BasePart
end

-- Toutes les pièces, accessoires compris : racine seule ancrée, ni collision, ni requête, ni contact.
local function ghost(model: Model, root: BasePart): { BasePart }
	local parts: { BasePart } = {}
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			local part = inst :: BasePart
			part.Anchored = part == root
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part.Transparency < 1 then
				table.insert(parts, part)
			end
		end
	end
	return parts
end

local function setFade(member: Member, value: number)
	for _, part in member.parts do
		part.LocalTransparencyModifier = value
	end
end

local function destroyMember(member: Member)
	for _, link in member.links do
		link:Disconnect()
	end
	table.clear(member.links)
	WitnessController.ReleaseFlash(member.model)
	member.model:Destroy()
end

-- Le sol sous `position` (le voleur et la foule ignorés) ; sans sol, la hauteur `fallback`.
local function groundY(position: Vector3, fromY: number, fallback: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(Vector3.new(position.X, fromY + 4, position.Z), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position.Y else fallback
end

-- a240 : le son de `member` (cri ou photo), jamais par-dessus le sien.
local function voice(member: Member, pool: { Sound }, limit: number, name: string)
	if playing(member.voice) or member.root.Parent == nil then
		return
	end
	local sound = playIn(pool, limit, name, member.root)
	if sound then
		member.voice = sound
	end
end

-- Un flash du photographe : l'effet (sauf animations réduites) et le son de la photo, parfois la rafale.
local function flash(member: Member)
	if reduced() then
		return
	end
	WitnessController.PlayFlash(member.model)
	local name = if rng:NextNumber(0, 1) < SOUNDS.BurstChance then SOUNDS.Burst else SOUNDS.Photo
	voice(member, photos, SOUNDS.PhotoVoices, name)
end

local function shout(member: Member)
	shouts += 1
	local list = member.sounds
	if list and #list > 0 then
		voice(member, cries, SOUNDS.Voices, list[rng:NextInteger(1, #list)])
	end
	for _, listener in shoutListeners do
		if not pcall(listener, member.model, member.role) then
			sayOnce("shout", "OnShout : une fonction a échoué")
		end
	end
end

local function startTrack(member: Member, animation: Animation)
	local model = member.model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local found: Animator = animator :: Animator
	local ok, result = pcall(function(): AnimationTrack
		return found:LoadAnimation(animation)
	end)
	if not ok then
		return
	end
	local track = result :: AnimationTrack
	member.track = track
	track:Play(0, 1, rng:NextNumber(0.9, 1.1)) -- chacun à son rythme
	track.TimePosition = rng:NextNumber(0, 0.4) -- pas tous en même temps
	if member.photographer then
		table.insert(
			member.links,
			track:GetMarkerReachedSignal(FLASH_MARKER):Connect(function()
				member.markerSeen = true
				flash(member)
			end)
		)
	else
		table.insert(
			member.links,
			track:GetMarkerReachedSignal(CROWD.ShoutMarker):Connect(function()
				shout(member)
			end)
		)
	end
end

local function addMember(crowd: Crowd, template: Model, index: number, at: Vector3, wanted: Role?, now: number, ignore: { Instance })
	local model, root = cleanCopy(template, index)
	if model == nil or root == nil then
		return
	end
	local role, animation, sign = settle(model, wanted)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local height = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	local thiefRoot = rootOf(crowd.thief)
	local thiefY = if thiefRoot then thiefRoot.Position.Y else at.Y
	local y = groundY(at, thiefY, thiefY - height, ignore) + height
	local position = Vector3.new(at.X, y, at.Z)
	local look = if thiefRoot then flat(thiefRoot.Position - position) else Vector3.zero
	local target = if look.Magnitude > 1e-3 then CFrame.lookAt(position, position + look.Unit) else CFrame.new(position)
	model:PivotTo(target * root.CFrame:ToObjectSpace(model:GetPivot()))
	model.Parent = folder()
	-- L'accessoire du rôle, une fois la personne à sa place : la pancarte, ou le téléphone s'il ne l'a pas déjà.
	if sign then
		wear(model, sign)
	elseif role and role.Phone and model:FindFirstChild(PHOTO.Phone, true) == nil then
		local found = phone()
		if found then
			wear(model, found)
		else
			sayOnce("phone", `{PHOTO.Phone} absent de Assets/Crowd/Props (L-223) : le flash part de la main`)
		end
	end
	local member: Member = {
		model = model,
		root = root,
		parts = ghost(model, root),
		role = if role then role.Name else "",
		sounds = if role then role.Sounds else nil,
		voice = nil,
		bornAt = now,
		track = nil,
		photographer = role ~= nil and role.Phone == true,
		markerSeen = false,
		nextFlashAt = now + rng:NextNumber(CROWD.FlashMin, CROWD.FlashMax),
		links = {},
	}
	if not reduced() then
		setFade(member, 1)
	end
	table.insert(crowd.members, member)
	if animation then
		startTrack(member, animation)
	end
end

-- a269 : l'écart entre deux personnes (Crowd.Spacing) ------------------------------------------------------------
-- Ce qu'une place doit éviter, au sol : les personnes déjà placées, les témoins et le circuit de la zone.
type Keep = { gap: number, points: { Vector3 }, circuit: { Vector3 } }

local function spacing(): any
	local value: any = (CROWD :: any).Spacing
	return if type(value) == "table" and value.Enabled == true then value else nil
end

-- La largeur réelle d'une personne : la plus grande empreinte au sol (X ou Z de GetExtentsSize) des modèles tirés,
-- au plus Spacing.WidthMax ; aucune mesure : Spacing.WidthFallback. L'écart = cette largeur + Spacing.Margin.
local function gapOf(templates: { Model }, settings: any): number
	local widest = 0
	for _, template in templates do
		local ok, size = pcall(function(): any
			return template:GetExtentsSize()
		end)
		local x = if ok and size ~= nil then (size :: any).X else nil
		local z = if ok and size ~= nil then (size :: any).Z else nil
		if type(x) == "number" and type(z) == "number" then
			widest = math.max(widest, x, z)
		end
	end
	if widest <= 0 then
		widest = settings.WidthFallback
	end
	return math.min(widest, settings.WidthMax) + settings.Margin
end

-- Les points du circuit WitnessPaths le plus proche au-dessus du magasin (comme WitnessService.pathOf), en ordre.
local function circuitOf(store: Model): { Vector3 }
	local parent = store.Parent
	local paths: Instance? = nil
	while parent and parent ~= Workspace and paths == nil do
		paths = parent:FindFirstChild(PATHS_NAME)
		parent = parent.Parent
	end
	type Point = { number: number, position: Vector3 }
	local points: { Point } = {}
	if paths then
		for _, inst in paths:GetDescendants() do
			local digits = string.match(inst.Name, PATH_POINT_PATTERN)
			local number = if digits then tonumber(digits) else nil
			if number and inst:IsA("Attachment") then
				table.insert(points, { number = number, position = (inst :: Attachment).WorldPosition })
			end
		end
	end
	table.sort(points, function(a: Point, b: Point): boolean
		return a.number < b.number
	end)
	local list: { Vector3 } = {}
	for _, point in points do
		table.insert(list, point.position)
	end
	return list
end

-- Ce que la foule de `store` doit éviter : les personnes des autres foules (créées ou à créer) et, avec
-- Spacing.Witnesses, les témoins vus chez ce joueur et le circuit de la zone du magasin.
local function keepOf(store: Model, gap: number, settings: any): Keep
	local keep: Keep = { gap = gap, points = {}, circuit = {} }
	for _, crowd in crowds do
		for _, member in crowd.members do
			table.insert(keep.points, member.root.Position)
		end
		for index = crowd.nextPending, #crowd.pending do
			table.insert(keep.points, crowd.pending[index].at)
		end
	end
	if settings.Witnesses == true then
		for _, inst in CollectionService:GetTagged(WitnessGauge.Tag) do
			local root = if inst:IsA("Model") then inst:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
				table.insert(keep.points, (root :: BasePart).Position)
			end
		end
		keep.circuit = circuitOf(store)
	end
	return keep
end

-- Distance au sol de `p` au segment `a`–`b`.
local function toSegment(p: Vector3, a: Vector3, b: Vector3): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local apx, apz = p.X - a.X, p.Z - a.Z
	local length2 = abx * abx + abz * abz
	local t = if length2 > 1e-9 then math.clamp((apx * abx + apz * abz) / length2, 0, 1) else 0
	local dx, dz = apx - abx * t, apz - abz * t
	return math.sqrt(dx * dx + dz * dz)
end

local function free(p: Vector3, placed: { Vector3 }, keep: Keep): boolean
	for _, list in { placed, keep.points } do
		for _, q in list do
			local dx, dz = p.X - q.X, p.Z - q.Z
			if dx * dx + dz * dz < keep.gap * keep.gap then
				return false
			end
		end
	end
	local circuit = keep.circuit
	if #circuit >= 2 then
		for index = 1, #circuit do
			if toSegment(p, circuit[index], circuit[index % #circuit + 1]) < keep.gap then
				return false -- le circuit tourne en boucle
			end
		end
	end
	return true
end

-- Les places : Crowd.PerSide de chaque côté du passage, plus serrées en s'éloignant de la vitrine. a269 : avec
-- `keep`, une place trop proche recule par pas de Spacing.Step (vers la rue, sinon un rang derrière) jusqu'à
-- Spacing.MaxPush studs ; au-delà, elle reste vide.
local function spots(center: Vector3, out: Vector3, width: number, perSide: number, keep: Keep?, settings: any?): { Vector3 }
	local list: { Vector3 } = {}
	local half = math.clamp(width / 2 + CROWD.PassageMargin, CROWD.PassageMin / 2, CROWD.PassageMax / 2)
	local across = Vector3.new(-out.Z, 0, out.X)
	for _, sideSign in { -1, 1 } do
		for index = 1, perSide do
			local along = CROWD.Start + CROWD.Length * ((index - 0.5) / perSide) ^ CROWD.Spread
			local lateral = half + (if index % 2 == 0 then CROWD.RowGap else 0)
			local jitterAlong = rng:NextNumber(-1, 1) * CROWD.Jitter
			local jitterAcross = rng:NextNumber(0, 1) * CROWD.Jitter -- jamais vers le passage
			local a, l = along + jitterAlong, lateral + jitterAcross
			if keep == nil or settings == nil then
				table.insert(list, center + out * a + across * (sideSign * l))
				continue
			end
			local push = 0
			while push <= settings.MaxPush do
				local further = center + out * (a + push) + across * (sideSign * l)
				if free(further, list, keep) then
					table.insert(list, further)
					break
				end
				local behind = center + out * a + across * (sideSign * (l + push))
				if push > 0 and free(behind, list, keep) then
					table.insert(list, behind)
					break
				end
				push += settings.Step
			end
		end
	end
	return list
end

-- La foule de `store`, pour `thief` qui vient d'en sortir avec l'objet.
local function form(store: Model, thief: Player, now: number)
	local last = lastAt[store]
	if last and now - last < CROWD.Cooldown then
		return
	end
	local low = lowEnd()
	if #crowds >= (if low then CROWD.MaxCrowdsLow else CROWD.MaxCrowds) then
		return
	end
	if not CROWD.AtNight and Workspace:GetAttribute(NIGHT_PHASE) == "Night" then
		return
	end
	local thiefRoot = rootOf(thief)
	local camera = Workspace.CurrentCamera
	if thiefRoot == nil or camera == nil or (camera.CFrame.Position - thiefRoot.Position).Magnitude > CROWD.ViewDistance then
		return
	end
	local templates = crowdModels()
	local fromWitnesses = #templates == 0
	if fromWitnesses then
		templates = witnessTemplates(store)
		sayOnce("models", "aucun NPC_Crowd_* dans Assets/Crowd/Models (L-223) : copies des témoins")
	end
	if #templates == 0 then
		sayOnce("templates", "aucun témoin NPC_Witness_* chez ce joueur (nuit ou streaming) : pas de foule")
		return
	end
	local center, out, width = windowFrame(store, thiefRoot.Position)
	if out == nil then
		return
	end
	lastAt[store] = now
	formed += 1
	local crowd: Crowd = {
		store = store,
		thief = thief,
		members = {},
		pending = {},
		nextPending = 1,
		ignore = {},
		startedAt = now,
		endsAt = now + CROWD.Duration,
		nextTurnAt = now,
		turnInterval = if low then CROWD.TurnIntervalLow else CROWD.TurnInterval,
		opaque = false,
	}
	table.insert(crowds, crowd)
	-- Tenues mélangées : chaque modèle une fois avant d'en revoir un.
	local order = table.clone(templates)
	for index = #order, 2, -1 do
		local other = rng:NextInteger(1, index)
		order[index], order[other] = order[other], order[index]
	end
	local ignore: { Instance } = { folder() }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(ignore, character)
		end
	end
	if fromWitnesses then
		for _, template in templates do
			table.insert(ignore, template)
		end
	end
	crowd.ignore = ignore
	-- a240 : places et rôles tirés tout de suite (même foule qu'avant) ; les personnes, créées par build.
	local perSide = math.max(math.floor(if low then CROWD.PerSideLow else CROWD.PerSide), 0)
	local settings = spacing()
	local keep: Keep? = nil
	if settings then
		keep = keepOf(store, gapOf(templates, settings), settings)
		lastGap = (keep :: Keep).gap
	end
	for index, at in spots(center, out, width, perSide, keep, settings) do
		table.insert(crowd.pending, { template = order[(index - 1) % #order + 1], index = index, at = at, role = drawRole() })
	end
end

-- a240 : crée les personnes en attente de `crowd`, au plus BuildPerFrame, et plus aucune une fois BuildBudget s
-- dépensées dans l'image (au moins une par image) ; `room` = places restantes dans l'image. Renvoie le nombre créé.
local function build(crowd: Crowd, now: number, started: number, room: number, first: boolean): number
	local made = 0
	while crowd.nextPending <= #crowd.pending and made < room do
		if not (first and made == 0) and os.clock() - started >= CROWD.BuildBudget then
			break
		end
		local entry = crowd.pending[crowd.nextPending]
		crowd.nextPending += 1
		addMember(crowd, entry.template, entry.index, entry.at, entry.role, now, crowd.ignore)
		made += 1
	end
	if crowd.nextPending > #crowd.pending then
		table.clear(crowd.pending)
		crowd.nextPending = 1
		table.clear(crowd.ignore)
	end
	return made
end

-- Boucle -----------------------------------------------------------------------------------------------

local function checkCarriers(now: number)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if player:GetAttribute(CARRYING) == nil or root == nil then
			insideOf[player] = nil
			continue
		end
		local store = storeAt(root.Position)
		if store then
			insideOf[player] = store
		else
			local left = insideOf[player]
			if left then
				insideOf[player] = nil
				form(left, player, now)
			end
		end
	end
end

-- Renvoie true quand la foule est finie (copies détruites).
local function updateCrowd(crowd: Crowd, now: number): boolean
	local fadeTime = if reduced() then 0 else CROWD.FadeTime
	if now >= crowd.endsAt + fadeTime then
		for _, member in crowd.members do
			destroyMember(member)
		end
		table.clear(crowd.members)
		table.clear(crowd.pending)
		return true
	end
	-- a240 : fondu d'entrée de chacun depuis sa création (bornAt) ; fondu de sortie commun.
	local outFade = if fadeTime > 0 and now >= crowd.endsAt then math.clamp((now - crowd.endsAt) / fadeTime, 0, 1) else 0
	local turn = now >= crowd.nextTurnAt
	if turn then
		crowd.nextTurnAt = now + crowd.turnInterval
	end
	local fading = not crowd.opaque or now >= crowd.endsAt
	local allIn = #crowd.pending == 0
	local thiefRoot = rootOf(crowd.thief)
	local quiet = reduced()
	for _, member in crowd.members do
		if fading then
			local fade = outFade
			if now < crowd.endsAt and fadeTime > 0 then
				fade = 1 - math.clamp((now - member.bornAt) / fadeTime, 0, 1)
			end
			if fade > 0 then
				allIn = false
			end
			setFade(member, fade)
		end
		if turn and thiefRoot and member.root.Parent ~= nil then
			local position = member.root.Position
			local look = flat(thiefRoot.Position - position)
			if look.Magnitude > 1e-3 then
				member.root.CFrame = CFrame.lookAt(position, position + look.Unit)
			end
		end
		if member.photographer and not member.markerSeen and now >= member.nextFlashAt and now < crowd.endsAt then
			member.nextFlashAt = now + rng:NextNumber(CROWD.FlashMin, CROWD.FlashMax)
			if not quiet then
				flash(member)
			end
		end
	end
	if fading and allIn and now < crowd.endsAt then
		crowd.opaque = true -- tous créés et ce dernier passage a écrit 0 : visibles
	end
	return false
end

local function step()
	local now = os.clock()
	if now >= nextCheckAt then
		nextCheckAt = now + CROWD.CheckInterval
		local ok, err = pcall(checkCarriers :: any, now)
		if not ok then
			sayOnce(`check:{err}`, `contrôle des porteurs : {err}`)
		end
	end
	-- a240 : les personnes en attente, sur un budget commun à toutes les foules de l'image.
	local started = os.clock()
	local room = math.max(math.floor(CROWD.BuildPerFrame), 1)
	local made = 0
	for _, crowd in crowds do
		if room - made <= 0 then
			break
		end
		if #crowd.pending > 0 then
			local ok, result = pcall(build, crowd, now, started, room - made, made == 0)
			if ok then
				made += result
			else
				sayOnce(`build:{result}`, `foule : {result}`)
				table.clear(crowd.pending)
				crowd.nextPending = 1
			end
		end
	end
	if made > 0 then
		frameMax = math.max(frameMax, made)
		frameMs = math.max(frameMs, (os.clock() - started) * 1000)
	end
	for index = #crowds, 1, -1 do
		local crowd = crowds[index]
		local ok, result = pcall(updateCrowd, crowd, now)
		if not ok or result == true then
			if not ok then
				sayOnce(`update:{result}`, `foule : {result}`)
				for _, member in crowd.members do
					pcall(destroyMember, member)
				end
			end
			table.remove(crowds, index)
		end
	end
end

-- a240 (L-229) : Crowd_Gasp sur la vitrine cassée d'un magasin PNJ (pas une boutique de joueur), mêmes refus que la
-- foule pour la nuit (Crowd.AtNight) et la distance (Crowd.ViewDistance).
local function gasp(windows: any, windowId: string, impactPoint: Vector3)
	local ok, window, store = pcall(windows.GetWindow, windowId)
	if not ok or window == nil or store == nil or not CollectionService:HasTag(store, STORE_TAG) then
		return
	end
	if not CROWD.AtNight and Workspace:GetAttribute(NIGHT_PHASE) == "Night" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil or (camera.CFrame.Position - impactPoint).Magnitude > CROWD.ViewDistance then
		return
	end
	local at: Instance? = nil
	if window:IsA("BasePart") then
		at = window
	elseif window:IsA("Model") then
		at = (window :: Model).PrimaryPart or window:FindFirstChildWhichIsA("BasePart", true)
	end
	if at then
		playIn(nil, 0, SOUNDS.Gasp, at)
	end
end

function WitnessCrowdController.GetCrowds(): { CrowdInfo }
	local list: { CrowdInfo } = {}
	for _, crowd in crowds do
		local members: { Model } = {}
		for _, member in crowd.members do
			table.insert(members, member.model)
		end
		table.insert(list, { Store = crowd.store, Thief = crowd.thief, Members = members })
	end
	return list
end

function WitnessCrowdController.GetCount(): number
	return formed
end

-- La mesure du coût chez ce joueur (L-219 point 1) : personnes, pièces, pistes d'animation en cours, cris entendus.
function WitnessCrowdController.GetStats(): CrowdStats
	local stats: CrowdStats = {
		Members = 0,
		Parts = 0,
		Tracks = 0,
		Shouts = shouts,
		Pending = 0,
		FrameMax = frameMax,
		FrameMs = frameMs,
		Voices = busy(cries) + busy(photos),
		Sounds = soundsPlayed,
		Gap = lastGap,
	}
	for _, crowd in crowds do
		if #crowd.pending > 0 then
			stats.Pending += #crowd.pending - crowd.nextPending + 1
		end
		for _, member in crowd.members do
			stats.Members += 1
			for _, inst in member.model:GetDescendants() do
				if inst:IsA("BasePart") then
					stats.Parts += 1
				end
			end
			if member.track then
				stats.Tracks += 1
			end
		end
	end
	return stats
end

-- Chaque marqueur Shout (L-223 : Cheer, Boo et Shout) ; le son de L-229 est déjà joué par ce contrôleur (a240).
function WitnessCrowdController.OnShout(callback: (Model, string) -> ())
	table.insert(shoutListeners, callback)
end

function WitnessCrowdController.Start()
	if not Features.WitnessCrowd then
		return
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		insideOf[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
	-- a240 (L-229) : Crowd_Gasp une fois à la casse d'une vitrine de magasin PNJ (WindowController, chargé à la demande).
	local found = script.Parent:FindFirstChild("WindowController")
	if found and found:IsA("ModuleScript") then
		local ok, windows = pcall(require, found :: any)
		if ok and type(windows) == "table" and type((windows :: any).OnBroken) == "function" then
			(windows :: any).OnBroken(function(windowId: string, impactPoint: Vector3)
				gasp(windows, windowId, impactPoint)
			end)
		end
	end
end

return WitnessCrowdController
