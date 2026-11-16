--!strict
-- WitnessCrowdController (client, vague 66, a221 ; Clément, L-210 point 4) : « à la sortie du magasin avec l'objet sur
-- la tête, une petite foule de PNJ autour du magasin filme et photographie le braquage ». Proposition V0, à valider par
-- Clément ; valeurs : Config/Witness.Crowd ; interrupteur : Features.WitnessCrowd.
--
-- Purement visuel, chez chaque joueur : aucun remote, rien d'écrit sur le serveur, rien d'enregistré dans la place.
--   1. Toutes les Crowd.CheckInterval s, pour chaque joueur qui porte un objet (attribut Carrying du Player, posé par
--      CarryService) : le magasin taggé NPCStore dont le volume Bounds contient son HumanoidRootPart est noté ; dès qu'il
--      en sort en portant toujours, la foule de ce magasin se forme (au plus une par magasin toutes les Crowd.Cooldown s,
--      au plus Crowd.MaxCrowds à la fois, et seulement si le voleur est à moins de Crowd.ViewDistance studs de la caméra).
--   2. Crowd.Count copies des témoins NPC_Witness_* présents chez ce joueur (tag WitnessGauge.Tag ; d'abord ceux qui
--      regardent ce magasin, attribut WatchedStore ; même modèle, même téléphone ACC_Temoin_Telephone), rangées dans le
--      dossier Workspace/Crowd.Folder, en arc de Crowd.Arc degrés à Crowd.Distance studs devant la vitrine (normale de la
--      vitre Window, du côté du voleur), posées au sol, tournées vers le voleur (revu toutes les Crowd.TurnInterval s).
--      Sur la copie : tag et attributs du témoin retirés (pas de bulle), HumanoidRootPart ancré, aucune collision, ni
--      requête, ni contact ; les copies du flash laissées dans le téléphone du témoin d'origine sont retirées.
--   3. Chacun joue Crowd.Anim (TakePhoto de Clément, en boucle ; absente : il reste dans sa pose de repos) :
--      - les Crowd.Filmers premiers rôles (tirés au hasard) filment : la piste se fige au premier marqueur Flash (le
--        téléphone levé), sinon au bout de Crowd.FilmFreeze s ; pas de flash ;
--      - les autres photographient : à chaque marqueur Flash, le flash de FX_Witness_Flash part de leur téléphone
--        (WitnessController.PlayFlash, mêmes règles que pour un témoin) ; sans marqueur, toutes les Crowd.FlashMin à
--        Crowd.FlashMax s (au hasard).
--   4. Apparition et disparition en Crowd.FadeTime s (LocalTransparencyModifier), au bout de Crowd.Duration s ;
--      « animations réduites » (Settings.VfxReduced ou ReducedMotionEnabled de Roblox) : ni fondu, ni flash.
-- Aucun témoin chez ce joueur (nuit : ils sont retirés ; streaming) : pas de foule (une ligne en Studio).
--
-- API (client, pour un test dans Studio) :
--   WitnessCrowdController.GetCrowds() -> { { Store: Model, Thief: Player, Members: { Model } } }
--   WitnessCrowdController.GetCount() -> number      foules formées chez ce joueur depuis le début

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

type Member = {
	model: Model,
	root: BasePart,
	parts: { BasePart }, -- celles qui se voient (fondu)
	track: AnimationTrack?,
	photographer: boolean,
	markerSeen: boolean,
	frozen: boolean,
	nextFlashAt: number,
	link: RBXScriptConnection?,
}

type Crowd = {
	store: Model,
	thief: Player,
	members: { Member },
	startedAt: number,
	endsAt: number,
	nextTurnAt: number,
}

local CROWD = Witness.Crowd
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
local nextCheckAt = 0
local formed = 0
local rng = Random.new()
local said: { [string]: boolean } = {}

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

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root :: BasePart else nil
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

-- Le centre de la vitrine et sa normale horizontale du côté de `toward` (comme WitnessService.photoSpot).
local function windowFrame(store: Model, toward: Vector3): (Vector3, Vector3?)
	local window = Find.path(store, WINDOW)
	local center = store:GetPivot().Position
	local axis: Vector3? = nil
	if window and window:IsA("BasePart") then
		local part = window :: BasePart
		center = part.Position
		local a = flat(if part.Size.X <= part.Size.Z then part.CFrame.RightVector else part.CFrame.LookVector)
		axis = if a.Magnitude > 1e-3 then a.Unit else nil
	elseif window and window:IsA("Model") then
		local frame, size = (window :: Model):GetBoundingBox()
		center = frame.Position
		local a = flat(if size.X <= size.Z then frame.RightVector else frame.LookVector)
		axis = if a.Magnitude > 1e-3 then a.Unit else nil
	end
	local side = flat(toward - center)
	local out: Vector3
	if axis then
		out = axis
	elseif side.Magnitude > 1e-3 then
		out = side.Unit
	else
		return center, nil
	end
	if out:Dot(side) < 0 then
		out = out * -1
	end
	return center, out
end

-- Les témoins de ce joueur à copier : d'abord ceux qui regardent ce magasin, sinon tous.
local function templatesFor(store: Model): { Model }
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

-- Une copie propre du témoin : ni tag, ni attributs de jauge, ni copie de flash, ni script ; rien qui touche le jeu.
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
		elseif inst:IsA("BasePart") then
			local part = inst :: BasePart
			part.Anchored = part == root
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		elseif inst.Name == PHOTO.CodePoint and inst:IsA("Attachment") then
			inst:Destroy() -- l'Attachment de repli du flash du témoin d'origine
		elseif (inst:IsA("Light") or inst:IsA("ParticleEmitter")) and inst.Parent and inst.Parent.Name == PHOTO.PhonePoint then
			inst:Destroy() -- les copies du flash laissées dans le téléphone du témoin d'origine
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return model, root :: BasePart
end

local function setFade(member: Member, value: number)
	for _, part in member.parts do
		part.LocalTransparencyModifier = value
	end
end

local function destroyMember(member: Member)
	local link = member.link
	if link then
		link:Disconnect()
		member.link = nil
	end
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

local function startTrack(member: Member, now: number)
	local model = member.model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animations = model:FindFirstChild(ANIMATIONS)
	local animation = if animations then animations:FindFirstChild(CROWD.Anim) else nil
	if humanoid == nil or animation == nil or not animation:IsA("Animation") then
		sayOnce("anim", `{CROWD.Anim} absente des témoins : la foule garde sa pose de repos`)
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
		return found:LoadAnimation(animation :: Animation)
	end)
	if not ok then
		return
	end
	local track = result :: AnimationTrack
	member.track = track
	track:Play(0, 1, rng:NextNumber(0.9, 1.1)) -- chacun à son rythme
	track.TimePosition = rng:NextNumber(0, 0.4) -- pas tous en même temps
	member.link = track:GetMarkerReachedSignal(FLASH_MARKER):Connect(function()
		member.markerSeen = true
		if not member.photographer then
			if not member.frozen then
				member.frozen = true
				track:AdjustSpeed(0) -- il filme : téléphone levé, immobile
			end
		elseif not reduced() then
			WitnessController.PlayFlash(model)
		end
	end)
end

local function addMember(crowd: Crowd, template: Model, index: number, at: Vector3, photographer: boolean, now: number, ignore: { Instance })
	local model, root = cleanCopy(template, index)
	if model == nil or root == nil then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local height = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	local thiefRoot = rootOf(crowd.thief)
	local thiefY = if thiefRoot then thiefRoot.Position.Y else at.Y
	local y = groundY(at, thiefY, thiefY - height, ignore) + height
	local position = Vector3.new(at.X, y, at.Z)
	local look = if thiefRoot then flat(thiefRoot.Position - position) else Vector3.zero
	local target = if look.Magnitude > 1e-3 then CFrame.lookAt(position, position + look.Unit) else CFrame.new(position)
	model:PivotTo(target * root.CFrame:ToObjectSpace(model:GetPivot()))
	local parts: { BasePart } = {}
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") and (inst :: BasePart).Transparency < 1 then
			table.insert(parts, inst :: BasePart)
		end
	end
	local member: Member = {
		model = model,
		root = root,
		parts = parts,
		track = nil,
		photographer = photographer,
		markerSeen = false,
		frozen = false,
		nextFlashAt = now + rng:NextNumber(CROWD.FlashMin, CROWD.FlashMax),
		link = nil,
	}
	if not reduced() then
		setFade(member, 1)
	end
	model.Parent = folder()
	table.insert(crowd.members, member)
	startTrack(member, now)
end

-- La foule de `store`, pour `thief` qui vient d'en sortir avec l'objet.
local function form(store: Model, thief: Player, now: number)
	local last = lastAt[store]
	if last and now - last < CROWD.Cooldown then
		return
	end
	if #crowds >= CROWD.MaxCrowds then
		return
	end
	local thiefRoot = rootOf(thief)
	local camera = Workspace.CurrentCamera
	if thiefRoot == nil or camera == nil or (camera.CFrame.Position - thiefRoot.Position).Magnitude > CROWD.ViewDistance then
		return
	end
	local templates = templatesFor(store)
	if #templates == 0 then
		sayOnce("templates", "aucun témoin NPC_Witness_* chez ce joueur (nuit ou streaming) : pas de foule")
		return
	end
	local center, out = windowFrame(store, thiefRoot.Position)
	if out == nil then
		return
	end
	lastAt[store] = now
	formed += 1
	local crowd: Crowd = {
		store = store,
		thief = thief,
		members = {},
		startedAt = now,
		endsAt = now + CROWD.Duration,
		nextTurnAt = now,
	}
	table.insert(crowds, crowd)
	-- Rôles tirés au hasard : Crowd.Filmers filmeurs, les autres photographes.
	local count = math.max(math.floor(CROWD.Count), 0)
	local roles: { boolean } = {}
	for index = 1, count do
		roles[index] = index > CROWD.Filmers
	end
	for index = count, 2, -1 do
		local other = rng:NextInteger(1, index)
		roles[index], roles[other] = roles[other], roles[index]
	end
	local ignore: { Instance } = { folder() }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(ignore, character)
		end
	end
	for _, template in templates do
		table.insert(ignore, template)
	end
	local offset = rng:NextInteger(0, #templates - 1)
	for index = 1, count do
		local angle = if count > 1 then -CROWD.Arc / 2 + CROWD.Arc * (index - 1) / (count - 1) else 0
		local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(out)
		local jitter = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * CROWD.Jitter
		local at = center + direction * CROWD.Distance + jitter
		local template = templates[(index - 1 + offset) % #templates + 1]
		addMember(crowd, template, index, at, roles[index], now, ignore)
	end
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
		return true
	end
	local fade = 0
	if fadeTime > 0 then
		if now >= crowd.endsAt then
			fade = math.clamp((now - crowd.endsAt) / fadeTime, 0, 1)
		else
			fade = 1 - math.clamp((now - crowd.startedAt) / fadeTime, 0, 1)
		end
	end
	local turn = now >= crowd.nextTurnAt
	if turn then
		crowd.nextTurnAt = now + CROWD.TurnInterval
	end
	local thiefRoot = rootOf(crowd.thief)
	local quiet = reduced()
	for _, member in crowd.members do
		setFade(member, fade)
		if turn and thiefRoot and member.root.Parent ~= nil then
			local position = member.root.Position
			local look = flat(thiefRoot.Position - position)
			if look.Magnitude > 1e-3 then
				member.root.CFrame = CFrame.lookAt(position, position + look.Unit)
			end
		end
		if not member.photographer then
			local track = member.track
			if track and not member.frozen and now - crowd.startedAt >= CROWD.FilmFreeze then
				member.frozen = true -- pas de marqueur Flash : il fige sa pose là où elle est
				track:AdjustSpeed(0)
			end
		elseif not member.markerSeen and now >= member.nextFlashAt and now < crowd.endsAt then
			member.nextFlashAt = now + rng:NextNumber(CROWD.FlashMin, CROWD.FlashMax)
			if not quiet then
				WitnessController.PlayFlash(member.model)
			end
		end
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

function WitnessCrowdController.Start()
	if not Features.WitnessCrowd then
		return
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		insideOf[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return WitnessCrowdController
