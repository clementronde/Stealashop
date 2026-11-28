--!strict
-- Reveal/Unbox (client, vague 73, a251 ; liaison L-236, L-237, L-246 et L-234 ; valeurs : Config/Unbox.New ; plan :
-- Shared/UnboxPlan) : la nouvelle ouverture du colis, jouée par RevealController à la place de son étape Open<Rareté>
-- quand le serveur envoie un plan. Module d'aide (sous-dossier : le Loader ne le démarre pas). Rien n'est décidé ici :
-- la rareté, les améliorations et la cote viennent du plan du serveur.
--
-- Déroulé (une scène = un état, Unbox.Begin puis Unbox.Step à chaque image) :
--   Intro        une copie locale du colis saute du rayon au sol de l'allée (le vrai est caché en local) ; chez
--                l'ouvreur, le perso se place à côté, face au colis, et la caméra se met côté allée (jamais dans un
--                mur : rapprochée, et ce qui reste devant devient transparent) ; BB_UnboxOdds au-dessus du colis ;
--   Action, Gap  une action du plan après l'autre : animation Unbox_* du perso (ouvreur ; ses marqueurs Impact), outil
--                TOOL_Unbox_* dans sa main, réaction du colis, effet et son à chaque Impact (plus de mot, L-253 ;
--                vague 75, L-261 : sons Assets/Sounds/Unbox de New.Sounds au lancement, au marqueur Top et aux Impacts,
--                arrêtés en fondu, Unbox_Rattle quand le colis tremble, aucun son de téléportation) ; au
--                dernier Impact attendu (le moment fort) la cote défile, et si la rareté montrée change : le colis
--                grossit, son scotch prend la couleur, FX_Unbox_Tier, « UPGRADE! », zoom et fondu des bords ; entre
--                deux actions, le colis tremble de plus en plus. Animation absente ou vide, et spectateurs : mêmes
--                Impacts aux instants de repli de la Config ;
--                vague 74 (L-258) : à côté, de l'autre côté puis debout sur le colis (Stomp, Slam au coup final), en
--                se téléportant entre deux places (nuage, disparition, réapparition, rebond) ;
--   Burst        moment fort de la dernière action : le colis éclate (FX_Unbox_Burst, FX_RevealSmash pour un objet
--                géant), le perso recule ; évènement « Burst » ;
--   Silhouettes  une silhouette noire par rareté, de la plus basse à la rareté gagnée (objets de la zone, la dernière
--                est le vrai objet, qui tremble) : FX_Unbox_Silhouette, FX_Unbox_Puff, nom de la rareté, zoom, bords ;
--   Overexpose   la dernière silhouette toute blanche, puis évènement « Reveal » (RevealController montre l'objet,
--                BB_Reveal, ses sons) ; Unbox.OnReveal : FX_Unbox_Reveal, zoom et bords plus forts, cote finale ;
--   After        évènement « Done » après AfterReveal : RevealController enchaîne sur sa croissance (Grow<Classe>).
-- a287 (2026-11-21, Cantin ; New.OddsClimb) : la cote de BB_UnboxOdds monte à chaque Impact, reste visible à
-- l'éclatement et pendant les silhouettes (un pas à chacune), puis finit sur la vraie cote à la révélation : jamais
-- vers le bas (UnboxPlan.climb). Coupé : la cote d'avant (plage de la rareté montrée, cachée pendant les silhouettes).
-- a462 (L-376, UnboxPlan.luckClimbs) : pendant les coups, BB_UnboxOdds.Odds montre la chance de l'ouvreur (« ×N LUCK », de
-- ×1 à plan.Luck, un pas par Impact) ; à l'éclatement, la cote prend sa place à Start et monte sur les silhouettes seules.
-- a462 (L-356 Q4, UnboxPlan.boxClimbs) : le colis montré prend le modèle BOX_<Rareté> de la rareté montrée.
-- Tout élément de Clément est facultatif : effet, outil, objet jeté ou billboard absent = rien (BB_UnboxOdds : un
-- billboard du code aux mêmes noms).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local UnboxConfig = require(Config:WaitForChild("Unbox"))
local RevealConfig = require(Config:WaitForChild("Reveal"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UI = require(Shared:WaitForChild("Contract"):WaitForChild("UI"))
local AnimPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("AnimPlayer"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
-- a519 (L-448, Features.StrikeFeel) : fondu court et arrêt sur image à chaque Impact, sur la piste Unbox_* seule.
-- Absent ou en erreur : comme avant.
local strikeFeel: any = (function(): any
	local module = Shared:WaitForChild("Anim"):FindFirstChild("StrikeFeel")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module :: any)
	return if ok and type(result) == "table" then result else nil
end)()
local UnboxPlan = require(Shared:WaitForChild("UnboxPlan"))
-- a494b : chance finale à décimales (ShelfOpen/Logic.finalLuck, displayLuck) ; absent (faux arbres des bancs) : valeur brute
local shelfLogicModule = script.Parent.Parent:FindFirstChild("ShelfOpen")
shelfLogicModule = if shelfLogicModule then shelfLogicModule:FindFirstChild("Logic") else nil
local ShelfLogic = if shelfLogicModule and shelfLogicModule:IsA("ModuleScript") then require(shelfLogicModule) :: any else nil
-- a523 (L-442, Features.LuckTiers) : style des paliers du compteur « ×N LUCK » (ShelfOpen/LuckTierStyle) ; absent (bancs) : rien.
local LuckTierStyle: any = (function(): any
	local found, module = pcall(function(): any
		local folder = script.Parent.Parent:FindFirstChild("ShelfOpen")
		return if folder then folder:FindFirstChild("LuckTierStyle") else nil
	end)
	if not found or module == nil then
		return nil
	end
	local ok, result = pcall(require, module :: any)
	return if ok and type(result) == "table" then result else nil
end)()
-- a491 (L-429 point 2, Features.BiggerTrophies / BiggerTrophiesDev) : hauteur du colis de l'ouverture au départ
-- (Config/DisplaySize.Trophies.OpenBoxHeight) ; nil = la hauteur de son modèle, comme avant. Module facultatif (bancs).
local OPEN_BOX_HEIGHT: number? = nil
do
	local module = Config:FindFirstChild("DisplaySize")
	if module and module:IsA("ModuleScript") then
		local ok, size = pcall(require, module :: any)
		local trophies = if ok and type(size) == "table" then (size :: any).Trophies else nil
		local height = if type(trophies) == "table" and trophies.Enabled == true then trophies.OpenBoxHeight else nil
		if type(height) == "number" and height > 0 then
			OPEN_BOX_HEIGHT = height
		end
	end
end
-- a536 : interrupteur `name` de Config/Features allumé partout, ou `name`Dev allumé dans le jeu DEV
-- (Config/ProductIds.IsDev). Module absent ou en erreur (bancs) : éteint.
local function featureOn(name: string): boolean
	local ok, on = pcall(function(): boolean
		local Features = require(Config:WaitForChild("Features")) :: any
		if Features[name] == true then
			return true
		end
		if Features[name .. "Dev"] ~= true then
			return false
		end
		local ProductIds = require(Config:WaitForChild("ProductIds")) :: any
		return ProductIds.IsDev == true
	end)
	return ok and on == true
end

local New = UnboxConfig.New
local REACT = New.React
local SOUNDS = New.Sounds -- vague 75 (a259, L-261)
local CAM = New.Camera
local UP = Vector3.new(0, 1, 0)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local KRAFT = Color3.fromRGB(176, 132, 84)
local FOV_BASE_ATTRIBUTE = "UnboxFovBase" -- vague 74 : lu par UiFeelController (début d'une poursuite)

export type Context = {
	Id: string,
	Opener: boolean, -- la scène du joueur local
	Player: Player?, -- l'ouvreur
	Store: Model?,
	SlotFrame: CFrame, -- emplacement du rayon
	AisleHint: Vector3, -- direction à plat vers le centre du magasin
	ShelfBox: Instance?, -- le colis du rayon (serveur)
	Rarity: string, -- rareté gagnée
	SizeClass: string,
	ItemId: string,
	ItemScale: number, -- taille de départ de l'objet (comme à sa révélation)
	ItemFinalScale: number?, -- a536 (L-504) : taille de l'objet à la fin de sa croissance (payload.Scale) ; nil : ItemScale
	Plan: UnboxPlan.Plan,
	LowEnd: boolean,
	Folder: Instance, -- où poser ce qui est créé (Workspace/_RevealFX)
	Hide: (part: BasePart) -> (), -- cache une pièce en local jusqu'à la fin de la scène (remise par RevealController)
	ItemTop: () -> number, -- hauteur (Y du monde) du haut de l'objet révélé, en ce moment
}

type Pulse = { value: number, target: number, hold: number }
type Muted = { property: string, off: any, was: any } -- a421 : propriété éteinte, sa valeur éteinte, celle d'avant
type Junk = { model: PVInstance, position: Vector3, velocity: Vector3, spin: number, angle: number, t: number }
type Timed = { inst: Instance, left: number }
type Fading = { sound: Sound, left: number, volume: number }

export type State = {
	ctx: Context,
	phase: string,
	t: number, -- secondes dans la phase
	events: { string },
	base: CFrame, -- pied du colis au sol de l'allée, LookVector vers l'allée (là où l'objet sortira)
	side: Vector3, -- du colis vers le perso
	stand: CFrame?, -- où se tient le perso de l'ouvreur
	-- Vague 74 (a257, L-258) : places du perso et téléportations.
	side0: Vector3, -- du colis vers la place Side (la caméra reste de ce côté)
	stands: { [string]: CFrame }, -- Side et Other (Top : calculée à chaque image, le colis grossit)
	standHeight: number, -- du sol au HumanoidRootPart
	moves: { UnboxPlan.Move },
	place: string, -- place du perso en ce moment
	teleport: boolean, -- la pause en cours est une téléportation
	teleportStage: number, -- 0 : rien encore, 1 : disparu, 2 : réapparu
	hiddenChar: { [Instance]: number }, -- pièces du perso cachées en local, et leur LocalTransparencyModifier d'avant
	camLift: number, -- montée de la caméra (studs)
	slide: number, -- glissement de BB_UnboxOdds (studs)
	boardFrom: Vector3, -- StudsOffsetWorldSpace d'origine de BB_UnboxOdds
	home: CFrame, -- pivot du colis sur son rayon
	floor: CFrame, -- pivot du colis posé au sol
	box: Model?,
	boxScale0: number,
	boxHeight: number, -- à la taille de départ
	tierScale: number,
	-- a536 (L-502, L-504, Features.UnboxSpacingV2) : espacement v2 ; grown : le colis a sa taille d'ouverture
	-- (OPEN_BOX_HEIGHT × UpgradeGrow^n), toujours vrai sans v2 ; growPending : UpgradeGrow^n gardé jusqu'au grossissement.
	spacing: boolean,
	grown: boolean,
	growPending: number,
	endT: number, -- temps depuis l'éclatement du déplacement au sol (L-504), < 0 : aucun
	endStage: number, -- 0 : rien encore, 1 : disparu, 2 : réapparu à sa place de fin
	endHold: CFrame?, -- où l'ouvreur reste jusqu'à sa disparition
	appliedScale: number,
	lid: PVInstance?,
	lidOffset: CFrame,
	tapes: { BasePart },
	anchor: BasePart,
	board: BillboardGui?,
	boardOffset: number,
	oddsLabel: TextLabel?,
	rarityLabel: TextLabel?,
	upgradeLabel: GuiObject?,
	oddsScale: UIScale?,
	odds: number, -- cote montrée
	oddsFrom: number,
	oddsTo: number,
	oddsT: number, -- avancement du défilement, < 0 : aucun
	luckShown: boolean, -- a462 (L-376) : BB_UnboxOdds.Odds montre la chance (« ×N LUCK »), pas la cote
	-- a523 (L-462) : gains des coups (plan.Hits) montrés, Impacts avant le coup final, Impacts des actions passées,
	-- billboards BB_UnboxLuckGain qui montent ; a523 (L-442) : style du palier du compteur, rebond de la cote.
	hitsShown: number,
	hitImpacts: number,
	hitOffset: number,
	gains: { { board: BillboardGui, t: number, from: Vector3 } },
	tierStyle: any,
	oddsPop: number,
	oddsTicks: number,
	upgradeLeft: number,
	finalLeft: number, -- temps restant de la cote finale, après la révélation
	tier: string, -- rareté montrée
	index: number, -- action en cours
	mode: string, -- "Anim" ou "Fallback"
	track: AnimationTrack?,
	trackStopped: boolean,
	connections: { RBXScriptConnection },
	impacts: number,
	strong: boolean, -- moment fort de l'action passé
	tool: PVInstance?,
	toolOffset: CFrame,
	toolGrip: CFrame, -- a536 (L-508, Features.UnboxToolGrip) : Grip:Inverse() d'un TOOL_Unbox_* livré en Tool, sinon identity
	toolGripOn: boolean,
	mark: BillboardGui?,
	runFx: Instance?,
	runEvery: number,
	runLeft: number,
	react: string?,
	reactT: number,
	reactForce: number,
	junk: { Junk },
	junkIndex: number,
	timed: { Timed },
	silhouette: Model?,
	silhouetteIndex: number,
	silhouetteCount: number,
	silhouetteHome: CFrame,
	spin: number,
	zoom: Pulse,
	edge: Pulse,
	edgeColor: Color3,
	edgeLabel: ImageLabel?,
	edgeScreen: ScreenGui?,
	edgeWasEnabled: boolean,
	baseFov: number?,
	seeThrough: { Instance }, -- pièces rendues transparentes devant la caméra
	ignored: { Instance }, -- pièces invisibles que la caméra traverse
	-- Étiquette, contour, arêtes… du vrai colis, éteints tant que la scène dure (a421 : tout ce que muteRule connaît,
	-- valeur d'avant gardée et remise à la fin) ; shelfAdded : ce qui y arrive pendant la scène.
	muted: { [Instance]: Muted },
	shelfAdded: RBXScriptConnection?,
	recoilLeft: number,
	revealed: boolean,
	released: boolean,
	destroyed: boolean,
	-- Vague 75 (a259, L-261) : sons en cours.
	running: { [Sound]: string }, -- son à arrêter en fondu, et quand : « Impact », « End » (fin de l'action) ou « Gap »
	fading: { Fading },
	queue: { string }, -- sons de Start encore à jouer, l'un après l'autre
	queueLeft: number,
	queueStop: string?,
	topDone: boolean, -- son du marqueur Top joué pour l'action en cours
	smoked: boolean, -- Unbox_Smoke déjà joué une fois (la fumée est apparue)
	created: { Instance },
}

local Unbox = {}

-- Aides ------------------------------------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function partsOf(root: Instance): { BasePart }
	local out: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(out, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Copie locale inerte : sans script, sans tag, sans invite, ancrée, sans collision.
local function inert(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local function untag(inst: Instance)
		pcall(function()
			for _, tag in CollectionService:GetTags(inst) do
				CollectionService:RemoveTag(inst, tag)
			end
		end)
	end
	untag(root)
	for _, d in root:GetDescendants() do
		untag(d)
	end
	for _, part in partsOf(root) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.LocalTransparencyModifier = 0
	end
end

local function asModel(inst: Instance): Model
	if inst:IsA("Model") then
		return inst
	end
	local wrapper = Instance.new("Model")
	inst.Parent = wrapper
	if inst:IsA("BasePart") then
		wrapper.PrimaryPart = inst
	end
	return wrapper
end

local function block(size: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = CFrame.new(0, size.Y / 2, 0)
	root.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
	root.Color = color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function extents(model: Model): Vector3
	local ok, size = pcall(function()
		return model:GetExtentsSize()
	end)
	if ok and typeof(size) == "Vector3" and (size :: Vector3).Y > 0 then
		return size :: Vector3
	end
	return Vector3.new(2, 1.6, 2)
end

local function scaleOf(model: Model): number
	local ok, scale = pcall(function()
		return model:GetScale()
	end)
	return if ok and type(scale) == "number" and scale > 0 then scale else 1
end

local function scaleTo(model: Model, scale: number)
	pcall(function()
		model:ScaleTo(math.max(scale, 0.01))
	end)
end

local function walk(path: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in path do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

local function rarityOf(id: string): Rarities.Rarity?
	return Rarities.ById[id]
end

local function colorOf(id: string): Color3
	local rarity = rarityOf(id)
	return if rarity then rarity.Color else WHITE
end

local function rankOf(id: string): number
	local rarity = rarityOf(id)
	return if rarity then math.max(rarity.Order - 1, 0) else 0
end

local function characterOf(state: State): Model?
	local player = state.ctx.Player
	return if player then player.Character else nil
end

local function rootOf(state: State): BasePart?
	local character = characterOf(state)
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Son de la scène : 2D chez l'ouvreur, sur l'ancre du colis chez un spectateur ; absent = muet. Rend la copie jouée.
local function sound(state: State, name: string?, pitch: number?): Sound?
	if name == nil then
		return nil
	end
	local template = MarkerSounds.find(name)
	if template == nil then
		return nil
	end
	local ok, played = pcall(MarkerSounds.playSound, template, if state.ctx.Opener then nil else state.anchor)
	if not ok or typeof(played) ~= "Instance" then
		return nil
	end
	if pitch then
		pcall(function()
			(played :: any).PlaybackSpeed = pitch
		end)
	end
	return played :: Sound
end

-- Vague 75 (a259, L-261) : sons lancés, arrêtés en fondu, joués l'un après l'autre ----------------------------------

-- Joue `name` ; `stop` : il sera arrêté en fondu à ce moment (« Impact », « End », « Gap »).
local function startSound(state: State, name: string, stop: string?): Sound?
	local played = sound(state, name)
	if played and stop then
		state.running[played] = stop
	end
	return played
end

-- Arrête en fondu (SOUNDS.StopFade) les sons lancés pour `when` (nil : tous) ; les sons de Start pas encore joués aussi.
local function stopSounds(state: State, when: string?)
	for played, stop in state.running do
		if when == nil or stop == when then
			state.running[played] = nil
			local ok, volume = pcall(function(): number
				return played.Volume
			end)
			table.insert(state.fading, { sound = played, left = SOUNDS.StopFade, volume = if ok then volume else 0 })
		end
	end
	if when == nil or state.queueStop == when then
		table.clear(state.queue)
	end
end

-- Durée (s) d'un son joué, au plus ChainMax ; inconnue : 0.
local function lengthOf(played: Sound?): number
	if played == nil then
		return 0
	end
	local ok, length = pcall(function(): number
		local any: any = played
		local speed = any.PlaybackSpeed
		return any.TimeLength / (if type(speed) == "number" and speed > 0.01 then speed else 1)
	end)
	return if ok and type(length) == "number" and length > 0 then math.min(length, SOUNDS.ChainMax) else 0
end

-- PlaybackSpeed au hasard (objets jetés, L-261).
local function junkPitch(): number
	local range = SOUNDS.JunkPitch
	return range[1] + math.random() * (range[2] - range[1])
end

-- Chaque image : le son de Start suivant, et les fondus.
local function stepSounds(state: State, dt: number)
	if #state.queue > 0 then
		state.queueLeft -= dt
		if state.queueLeft <= 0 then
			local name = table.remove(state.queue, 1) :: string
			state.queueLeft = lengthOf(startSound(state, name, state.queueStop))
		end
	end
	for index = #state.fading, 1, -1 do
		local fade = state.fading[index]
		fade.left -= dt
		local played = fade.sound
		if fade.left <= 0 then
			table.remove(state.fading, index)
			pcall(function()
				played:Stop()
				played:Destroy()
			end)
		else
			local volume = fade.volume * fade.left / math.max(SOUNDS.StopFade, 1e-3)
			pcall(function()
				played.Volume = volume
			end)
		end
	end
end

-- Coupe tout d'un coup (fin de la scène).
local function killSounds(state: State)
	stopSounds(state, nil)
	for _, fade in state.fading do
		local played = fade.sound
		pcall(function()
			played:Stop()
			played:Destroy()
		end)
	end
	table.clear(state.fading)
end

local function raycast(origin: Vector3, direction: Vector3, exclude: { Instance }, respectCollide: boolean): RaycastResult?
	local ok, result = pcall(function(): RaycastResult?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		params.RespectCanCollide = respectCollide
		return Workspace:Raycast(origin, direction, params)
	end)
	return if ok then result else nil
end

local function excluded(state: State?, ctx: Context): { Instance }
	local list: { Instance } = { ctx.Folder }
	if ctx.ShelfBox then
		table.insert(list, ctx.ShelfBox)
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(list, character)
		end
	end
	if state then
		for _, inst in state.seeThrough do
			table.insert(list, inst)
		end
		for _, inst in state.ignored do
			table.insert(list, inst)
		end
	end
	return list
end

-- Effets -----------------------------------------------------------------------------------------------------------

local function emitAll(root: Instance, color: Color3?)
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			if color and d:GetAttribute("RarityColor") then
				d.Color = ColorSequence.new(color)
			end
			local count = d:GetAttribute("EmitCount")
			d:Emit(if type(count) == "number" then count else New.FxEmit)
		end
	end
end

-- Copie d'un effet de Assets/FX posée au pied `foot` (ses Attachments FxTopAttachments au point `top`), comme
-- FX_ShelfReveal : émetteurs à Rate 0 lancés une fois (attribut EmitCount), RarityColor = couleur de la rareté,
-- détruite après son attribut Duration. `emit` faux : rien n'est lancé (effet rythmé par EmitEvery).
local function spawnFx(state: State, name: string?, foot: CFrame, top: Vector3?, color: Color3?, emit: boolean): Instance?
	if name == nil or state.ctx.LowEnd then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("FX") else nil
	local template = if folder then folder:FindFirstChild(name, true) else nil
	if template == nil or not template:IsA("PVInstance") then
		return nil
	end
	local copy = template:Clone()
	inert(copy)
	copy:PivotTo(foot)
	copy.Parent = state.ctx.Folder
	if top then
		for _, d in copy:GetDescendants() do
			if d:IsA("Attachment") and table.find(New.FxTopAttachments, d.Name) then
				local parent = d.Parent
				if parent and parent:IsA("BasePart") then
					d.Position = parent.CFrame:PointToObjectSpace(top)
				else
					d.WorldPosition = top
				end
			end
		end
	end
	if emit then
		emitAll(copy, color)
	end
	local life = copy:GetAttribute("Duration")
	table.insert(state.timed, { inst = copy, left = if type(life) == "number" and life > 0 then life else New.FxLife })
	return copy
end

-- Vague 75 (L-261) : l'effet `name` fait-il de la fumée (un émetteur SOUNDS.SmokeEmitter, L-254) ? Lu sur le modèle,
-- aussi en LowEnd où l'effet n'est pas posé.
local function fxHasSmoke(name: string?): boolean
	if name == nil then
		return false
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("FX") else nil
	local template = if folder then folder:FindFirstChild(name, true) else nil
	return template ~= nil and template:FindFirstChild(SOUNDS.SmokeEmitter, true) ~= nil
end

local function pulse(p: Pulse, target: number, hold: number)
	p.target = math.max(target, 0)
	p.hold = hold
end

local function stepPulse(p: Pulse, dt: number, rise: number, fall: number)
	if p.hold > 0 then
		p.hold -= dt
		p.value += (p.target - p.value) * math.min(1, dt / math.max(rise, 1e-3))
	else
		p.value += (0 - p.value) * math.min(1, dt / math.max(fall, 1e-3))
	end
end

-- Zoom et fondu des bords à la couleur de `rarity` (ouvreur seul). `reveal` : les valeurs de la révélation.
local function flash(state: State, rarity: string, reveal: boolean)
	if not state.ctx.Opener then
		return
	end
	local amount = (if reveal then New.ZoomReveal else New.ZoomStep) * (1 + New.ZoomRank * rankOf(rarity))
	pulse(state.zoom, math.min(amount, New.ZoomMax), New.ZoomIn + New.ZoomHold)
	pulse(state.edge, 1 - (if reveal then New.EdgeReveal else New.EdgeStep), New.EdgeIn + New.EdgeHold)
	state.edgeColor = colorOf(rarity)
end

-- Colis ------------------------------------------------------------------------------------------------------------

local function boxTop(state: State): Vector3
	local scale = state.tierScale
	local pivot = if state.phase == "Intro" then state.home:Lerp(state.floor, math.clamp(state.t / New.Intro, 0, 1)) else state.floor
	return pivot.Position + UP * (state.boxHeight * scale)
end

local function reactNow(state: State, kind: string, force: number)
	state.react = kind
	state.reactT = 0
	state.reactForce = force
end

local function poseBox(state: State, dt: number)
	local box = state.box
	if box == nil then
		return
	end
	local pivot = state.floor
	if state.phase == "Intro" then
		local f = math.clamp(state.t / New.Intro, 0, 1)
		local eased = (1 - math.cos(math.pi * f)) / 2
		pivot = state.home:Lerp(state.floor, eased) + UP * (New.BoxHop * math.sin(math.pi * f))
	end
	local offset = Vector3.zero
	local tilt, yaw, squash, lidUp = 0, 0, 0, 0
	local kind = state.react
	if kind then
		state.reactT += dt
		local duration = if kind == "Push" then REACT.Time * 2 else REACT.Time
		local f = state.reactT / duration
		if f >= 1 then
			state.react = nil
		else
			local wave = math.sin(math.pi * f) * state.reactForce
			if kind == "Jump" then
				offset = UP * (REACT.Jump * wave)
			elseif kind == "Tilt" then
				tilt = REACT.Tilt * wave
			elseif kind == "Squash" then
				squash = REACT.Squash * wave
			elseif kind == "Stomp" then
				-- Vague 74 (L-258) : sous les pieds, le colis s'écrase puis saute.
				if f < 0.5 then
					squash = REACT.Squash * math.sin(2 * math.pi * f) * state.reactForce
				else
					offset = UP * (REACT.Jump * math.sin(2 * math.pi * (f - 0.5)) * state.reactForce)
				end
			elseif kind == "Spin" then
				yaw = REACT.Spin * wave
			elseif kind == "Slide" then
				offset = -state.side * (REACT.Slide * wave)
			elseif kind == "Push" then
				offset = -state.side * (REACT.Push * wave)
			elseif kind == "Lid" then
				lidUp = wave
				offset = UP * (REACT.Jump * 0.4 * wave)
			end
		end
	end
	if state.phase == "Gap" then
		local amplitude = REACT.Tremble + REACT.TrembleStep * state.index
		offset += Vector3.new((math.random() - 0.5) * 2 * amplitude, 0, (math.random() - 0.5) * 2 * amplitude)
	end
	local scale = state.boxScale0 * state.tierScale * (1 - squash)
	if math.abs(scale - state.appliedScale) > 1e-3 then
		state.appliedScale = scale
		scaleTo(box, scale)
	end
	local frame = (pivot + offset) * CFrame.Angles(tilt, yaw, 0)
	pcall(function()
		box:PivotTo(frame)
	end)
	local lid = state.lid
	if lid and lid.Parent ~= nil then
		local ratio = scale / state.boxScale0
		local rest = CFrame.new(state.lidOffset.Position * ratio) * state.lidOffset.Rotation
		pcall(function()
			lid:PivotTo(frame * rest * CFrame.new(0, REACT.LidLift * lidUp, 0) * CFrame.Angles(REACT.LidTilt * lidUp, 0, 0))
		end)
	end
	state.anchor.CFrame = CFrame.new(pivot.Position + UP * math.max(state.boxHeight * state.tierScale - New.OddsBelowTop, 0))
end

-- a462 (L-356 Q4, UnboxPlan.boxClimbs) : modèle BOX_<Rareté> de Clément (ReplicatedStorage/Assets), ou nil.
local BOX_PREFIX = "BOX_" -- Contract/Models.Box.Prefix
local function boxTemplate(rarity: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = if assets then assets:FindFirstChild(BOX_PREFIX .. rarity, true) else nil
	if found and (found:IsA("Model") or found:IsA("BasePart")) then
		return found
	end
	return nil
end

local function copyOf(source: Instance?): Model?
	if source and (source:IsA("Model") or source:IsA("BasePart")) then
		local ok, copy = pcall(function()
			return source:Clone()
		end)
		if ok and copy then
			return asModel(copy)
		end
	end
	return nil
end

-- Prend `model` comme colis montré. `height` : sa hauteur à la taille de départ (le modèle est mis à l'échelle pour
-- l'avoir) ; nil : sa propre hauteur.
local function adoptBox(state: State, model: Model, height: number?)
	inert(model)
	model.Name = "UnboxBox"
	if height and height > 0 then
		local natural = extents(model).Y
		if natural > 0 then
			scaleTo(model, scaleOf(model) * height / natural)
		end
	end
	state.box = model
	state.boxScale0 = scaleOf(model)
	state.appliedScale = state.boxScale0
	state.boxHeight = if height and height > 0 then height else extents(model).Y
	state.lid = nil
	state.lidOffset = CFrame.identity
	table.clear(state.tapes)
	local lid = model:FindFirstChild("Lid", true)
	if lid and lid:IsA("PVInstance") then
		state.lid = lid
		state.lidOffset = model:GetPivot():ToObjectSpace(lid:GetPivot())
	end
	for _, part in partsOf(model) do
		if table.find(New.TapeNames, part.Name) then
			table.insert(state.tapes, part)
		end
	end
	model.Parent = state.ctx.Folder
	table.insert(state.created, model)
end

local function buildBox(state: State)
	local ctx = state.ctx
	local box = copyOf(ctx.ShelfBox)
	-- a462 : sans colis de rayon (caisse exclusive, colis offert), le modèle BOX_ de la rareté montrée au départ.
	if box == nil and UnboxPlan.boxClimbs() then
		box = copyOf(boxTemplate(ctx.Plan.Steps[1].Rarity))
	end
	-- a491 (L-429 point 2) : trophées plus gros allumés : le colis montré a OPEN_BOX_HEIGHT de haut (swapBox garde cette
	-- hauteur, UpgradeGrow s'y ajoute) ; le vrai colis du rayon, caché en local, ne change pas.
	-- a536 (L-502) : espacement v2 : le colis garde la taille de son modèle jusqu'au grossissement (growTarget).
	if state.grown then
		adoptBox(state, box or block(Vector3.new(2, 1.6, 2), KRAFT), OPEN_BOX_HEIGHT)
	else
		adoptBox(state, box or block(Vector3.new(2, 1.6, 2), KRAFT), nil)
	end
end

-- a536 (L-502) : tierScale du colis grossi : OPEN_BOX_HEIGHT (ou sa hauteur) × UpgradeGrow par amélioration passée.
local function growTarget(state: State): number
	local height = OPEN_BOX_HEIGHT
	local base = if height and state.boxHeight > 0 then height / state.boxHeight else 1
	return base * state.growPending
end

-- a536 (L-502) : le colis grossit de 1 à growTarget (× GrowBounce au plus fort, f de 0 à 1 puis g de 0 à 1 : retour).
local function setGrow(state: State, f: number, g: number)
	local target = growTarget(state)
	local bounce = math.max(New.GrowBounce, 1)
	local function ease(x: number): number
		local c = math.clamp(x, 0, 1)
		return (1 - math.cos(math.pi * c)) / 2
	end
	local peak = target * bounce
	state.tierScale = if g <= 0 then 1 + (peak - 1) * ease(f) else peak + (target - peak) * ease(g)
end

local function finishGrow(state: State)
	if state.grown then
		return
	end
	state.tierScale = growTarget(state)
	state.growPending = 1
	state.grown = true
end

-- a536 (L-502) : chaque image, avant la dernière action : pendant la téléportation qui la précède, de Vanish à Appear
-- (le perso est dans le nuage), puis le rebond revient jusqu'à Teleport ; sans téléportation, pendant la pause ; une
-- seule action sans téléportation : pendant l'Intro. startAction(dernière) le finit au plus tard.
local function stepGrow(state: State)
	if state.grown then
		return
	end
	local last = #state.moves
	local speed = math.max(New.ActionSpeed, 0.1)
	if state.phase == "Gap" and state.index + 1 == last then
		if state.teleport then
			local places = New.Places
			local a, b, c = places.Vanish / speed, places.Appear / speed, places.Teleport / speed
			if state.t < b then
				setGrow(state, (state.t - a) / math.max(b - a, 1e-3), 0)
			else
				setGrow(state, 1, (state.t - b) / math.max(c - b, 1e-3))
			end
		else
			setGrow(state, state.t / math.max(UnboxPlan.transition(false), 1e-3), 0)
		end
	elseif state.phase == "Intro" and last == 1 and not state.moves[1].Teleport then
		setGrow(state, state.t / math.max(New.Intro, 1e-3), 0)
	end
end

-- a462 (L-356 Q4) : la rareté montrée change : le colis prend le modèle BOX_<Rareté>, à la même hauteur de départ (la
-- croissance UpgradeGrow continue de s'appliquer). false sans modèle ou coupé : le scotch est recoloré, comme avant.
local function swapBox(state: State, rarity: string): boolean
	if not UnboxPlan.boxClimbs() then
		return false
	end
	local copy = copyOf(boxTemplate(rarity))
	local old = state.box
	if copy == nil or old == nil then
		if copy then
			copy:Destroy()
		end
		return false
	end
	-- a536 (L-502) : avant le grossissement (espacement v2), chaque BOX_ garde sa propre taille.
	local height = if state.grown then state.boxHeight else nil
	state.box = nil
	old:Destroy()
	adoptBox(state, copy, height)
	return true
end

local function dropBox(state: State)
	local box = state.box
	if box then
		state.box = nil
		box:Destroy()
	end
end

-- Billboards -------------------------------------------------------------------------------------------------------

local function billboard(name: string): BillboardGui?
	local folder = walk(UI.BillboardFolder)
	local found = if folder then folder:FindFirstChild(name) else nil
	if found and found:IsA("BillboardGui") then
		return found:Clone()
	end
	return nil
end

local function v0Board(): BillboardGui
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(6, 2.6)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	for index, name in { "Upgrade", "Odds", "Rarity" } do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, if name == "Odds" then 0.45 else 0.27)
		label.Position = UDim2.fromScale(0, if index == 1 then 0 elseif index == 2 then 0.27 else 0.72)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = WHITE
		label.TextStrokeTransparency = 0
		label.Text = if name == "Upgrade" then "UPGRADE!" else ""
		label.Parent = board
	end
	return board
end

local function label(root: Instance, name: string): TextLabel?
	local found = Find.path(root, name)
	return if found and found:IsA("TextLabel") then found else nil
end

local function popScale(parent: Instance): UIScale
	local existing = parent:FindFirstChild("UnboxPop")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "UnboxPop"
	scale.Parent = parent
	return scale
end

local function showRarity(state: State, rarity: string)
	local text = state.rarityLabel
	local info = rarityOf(rarity)
	if text then
		text.Visible = true
		text.Text = if info then info.DisplayNameUpper else string.upper(rarity)
		text.TextColor3 = colorOf(rarity)
	end
end

local function showOdds(state: State, value: number)
	state.odds = value
	local text = state.oddsLabel
	if text then
		local plan = state.ctx.Plan
		local luck = plan.Luck or 1
		if state.luckShown then
			-- a523 (L-462) : avec les gains des coups, base × (1 + gains montrés), sans décalage d'affichage (a494) ;
			-- a526 : visuel, le tirage garde la chance de base (Cantin 28/11) ; la cote (1 IN N) reste la vraie.
			local shown = if plan.Hits ~= nil or ShelfLogic == nil
				then value
				else ShelfLogic.displayLuck(value, luck, ShelfLogic.finalLuck(luck, 0, state.ctx.Id .. "|" .. state.ctx.ItemId))
			text.Text = UnboxPlan.luckText(shown)
			if state.tierStyle then
				LuckTierStyle.Set(state.tierStyle, shown) -- a523 (L-442) : palier de la chance affichée
			end
		else
			text.Text = UnboxPlan.oddsText(value)
		end
	end
end

-- La cote défile (stepOdds) de celle montrée jusqu'à `target`, jamais plus bas.
local function rollOdds(state: State, target: number)
	state.oddsFrom = math.max(state.odds, 1)
	state.oddsTo = math.max(target, state.odds)
	state.oddsT = 0
	state.oddsTicks = 0
end

-- a462 (L-376) : la chance défile comme la cote, seulement si elle monte et se voit (×1 tout du long, ou caisse sans
-- chance : ni défilement ni tics).
local function rollLuck(state: State, target: number)
	local text = state.oddsLabel
	if target > state.odds + 1e-6 and text ~= nil and text.Visible then
		rollOdds(state, target)
	end
end

local function buildBoard(state: State)
	local board = billboard(New.OddsBoard) or v0Board()
	board.Name = "UnboxOdds"
	board.Adornee = state.anchor
	state.board = board
	state.boardOffset = board.StudsOffsetWorldSpace.Y
	state.boardFrom = board.StudsOffsetWorldSpace
	state.oddsLabel = label(board, "Odds")
	state.rarityLabel = label(board, "Rarity")
	local upgrade = Find.path(board, "Upgrade")
	if upgrade and upgrade:IsA("GuiObject") then
		upgrade.Visible = false
		state.upgradeLabel = upgrade
	end
	if state.oddsLabel then
		state.oddsScale = popScale(state.oddsLabel)
	end
	showRarity(state, state.tier)
	local plan = state.ctx.Plan
	if UnboxPlan.luckClimbs() or plan.Hits ~= nil then
		-- a462 (L-376) : pendant les coups, la chance de l'ouvreur (×1 au départ) ; sans chance dans le plan (caisse
		-- exclusive, colis offert) : rien pendant les coups, la cote vient à l'éclatement.
		-- a523 (L-462) : avec les gains des coups, la chance tirée (la base) dès le départ, puis chaque gain s'y ajoute.
		state.luckShown = true
		local text = state.oddsLabel
		if text and LuckTierStyle and plan.Luck ~= nil then
			-- a523 (L-442) : éclat d'un palier franchi au-dessus du colis.
			state.tierStyle = LuckTierStyle.new(text, nil, function(): CFrame?
				return CFrame.new(boxTop(state) + UP)
			end, state.ctx.Folder)
		end
		showOdds(state, if plan.Hits ~= nil then plan.Luck or 1 else 1)
		if text and plan.Luck == nil then
			text.Visible = false
		end
	else
		showOdds(state, UnboxPlan.startOdds(state.ctx.Plan)) -- a287 : Start de New.OddsClimb, sinon la plage d'avant
	end
	board.Parent = state.ctx.Folder
	table.insert(state.created, board)
end

-- a523 (L-462) : gains des coups -------------------------------------------------------------------------------------

local HIT = New.HitLuck

-- Billboard du code aux noms proposés à Clément (BB_UnboxLuckGain : Amount, Streak, SuperLuck avec Label, Gain, Total).
local function v0GainBoard(): BillboardGui
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(5, 2.4)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	local function text(name: string, parent: Instance, y: number, h: number, color: Color3): TextLabel
		local made = Instance.new("TextLabel")
		made.Name = name
		made.BackgroundTransparency = 1
		made.Size = UDim2.fromScale(1, h)
		made.Position = UDim2.fromScale(0, y)
		made.TextScaled = true
		made.Font = Enum.Font.GothamBlack
		made.TextColor3 = color
		made.TextStrokeTransparency = 0
		made.Text = ""
		made.Parent = parent
		return made
	end
	text("Amount", board, 0.6, 0.4, Color3.fromRGB(120, 255, 140))
	text("Streak", board, 0.3, 0.3, Color3.fromRGB(255, 200, 60)).Visible = false
	local super = Instance.new("Frame")
	super.Name = "SuperLuck"
	super.BackgroundTransparency = 1
	super.Size = UDim2.fromScale(1, 1)
	super.Visible = false
	super.Parent = board
	text("Label", super, 0, 0.4, Color3.fromRGB(255, 220, 60)).Rotation = -3
	text("Gain", super, 0.4, 0.3, Color3.fromRGB(120, 255, 140))
	text("Total", super, 0.7, 0.3, WHITE)
	return board
end

local function setLabel(root: Instance, name: string, value: string?)
	local found = Find.path(root, name)
	if found and found:IsA("TextLabel") then
		found.Visible = value ~= nil
		if value then
			found.Text = value
		end
	end
end

-- « +0.2 LUCK », « x2 STREAK » et, pour un SUPER LUCK!, son cadre (« +2.0 », « ×3.40 »), FX_Unbox_SuperLuck et son son.
local function showGain(state: State, amount: number, streak: number, super: boolean, total: number)
	local board = billboard(HIT.GainBoard) or v0GainBoard()
	board.Name = "UnboxLuckGain"
	board.Adornee = state.anchor
	local from = state.boardFrom + Vector3.new(0, 1.2, 0)
	board.StudsOffsetWorldSpace = from
	local gain = UnboxPlan.gainText(amount)
	local found = Find.path(board, "SuperLuck")
	local frame = if found and found:IsA("GuiObject") then found else nil
	-- Sans cadre SuperLuck (billboard de Clément sans lui) : « SUPER LUCK! +2.0 » dans Amount.
	setLabel(board, "Amount", if super and frame then nil elseif super then `{HIT.SuperText} +{gain}` else string.format(HIT.GainText, gain))
	setLabel(board, "Streak", if streak >= 2 and not super then string.format(HIT.StreakText, streak) else nil)
	if frame then
		frame.Visible = super
		if super then
			setLabel(frame, "Label", HIT.SuperText)
			setLabel(frame, "Gain", "+" .. gain)
			setLabel(frame, "Total", "×" .. UnboxPlan.luckNumber(total))
		end
	end
	board.Parent = state.ctx.Folder
	table.insert(state.created, board)
	local timed: Timed = { inst = board :: Instance, left = HIT.GainShow * (if super then 2 else 1) }
	table.insert(state.timed, timed)
	table.insert(state.gains, { board = board, t = 0, from = from })
	if super then
		local top = boxTop(state)
		spawnFx(state, HIT.SuperFx, CFrame.new((state.floor.Position + top) / 2), nil, nil, true)
		sound(state, HIT.SuperSound)
	end
end

-- Les gains du plan à montrer une fois passé l'Impact `impact` de la scène (UnboxPlan.hitsUpTo) : ceux qui tombent ici
-- sont montrés ensemble, et la chance défile jusqu'à base × (1 + gains montrés).
local function showHits(state: State, impact: number)
	local plan = state.ctx.Plan
	local hits = plan.Hits
	if hits == nil or not state.luckShown then
		return
	end
	local upTo = UnboxPlan.hitsUpTo(#hits, impact, state.hitImpacts)
	if upTo <= state.hitsShown then
		return
	end
	local base = plan.Luck or 1
	local sum, streak, super = 0, 0, false
	for index = state.hitsShown + 1, upTo do
		local kind = hits[index]
		sum += UnboxPlan.hitFactor(kind)
		super = super or kind == "S"
		streak = math.max(streak, tonumber(kind) or 0)
	end
	state.hitsShown = upTo
	local total = UnboxPlan.hitsFinal(base, hits, upTo)
	rollLuck(state, total)
	if sum > 0 then
		showGain(state, base * sum, streak, super, total)
	end
end

local function stepGains(state: State, dt: number)
	for index = #state.gains, 1, -1 do
		local entry = state.gains[index]
		entry.t += dt
		if entry.board.Parent == nil then
			table.remove(state.gains, index)
		else
			local f = math.min(entry.t / HIT.GainShow, 1)
			entry.board.StudsOffsetWorldSpace = entry.from + Vector3.new(0, HIT.GainRise * (1 - (1 - f) * (1 - f)), 0)
		end
	end
end

local function dropMark(state: State)
	local mark = state.mark
	if mark then
		state.mark = nil
		mark:Destroy()
	end
end

local function showMark(state: State, text: string)
	local mark = state.mark
	if mark == nil then
		local character = characterOf(state)
		local head = if character then character:FindFirstChild("Head") else nil
		local board = billboard(New.MarkBoard)
		if board == nil or head == nil or not head:IsA("BasePart") then
			if board then
				board:Destroy()
			end
			return
		end
		board.Adornee = head
		board.Parent = state.ctx.Folder
		state.mark = board
		mark = board
	end
	local content = label(mark :: BillboardGui, "Mark")
	if content then
		content.Text = text
	end
end

-- Outil et objets jetés --------------------------------------------------------------------------------------------

local function dropTool(state: State)
	local tool = state.tool
	if tool then
		state.tool = nil
		tool:Destroy()
	end
end

local function poseTool(state: State)
	local tool = state.tool
	local character = characterOf(state)
	local hand = if character then character:FindFirstChild(New.ToolHand) else nil
	if tool == nil or hand == nil or not hand:IsA("BasePart") then
		return
	end
	-- Vague 74 (L-255, L-257) : comme un Tool à Grip neutre, le Handle est posé tel quel sur RightGripAttachment ; sans
	-- elle, sur la main tournée de ToolGripAngles (la prise R6).
	local grip = hand:FindFirstChild(New.ToolGrip)
	local frame: CFrame
	if grip and grip:IsA("Attachment") then
		frame = grip.WorldCFrame
	else
		local angles = New.ToolGripAngles
		frame = hand.CFrame * CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
	end
	-- a536 (L-508) : un Tool livré avec son Grip est tenu comme Roblox le tient en main (Handle = prise × Grip⁻¹).
	local target = frame * state.toolGrip * state.toolOffset
	pcall(function()
		tool:PivotTo(target)
	end)
end

-- L-255 (vague 74) : le point de l'outil qui touche le colis (Attachment HitPoint), quand l'animation joue (en repli,
-- la main ne bouge pas : le haut du colis).
local function hitPoint(state: State): Vector3?
	local tool = state.tool
	if tool == nil or state.mode ~= "Anim" then
		return nil
	end
	local found = tool:FindFirstChild(New.HitPoint, true)
	return if found and found:IsA("Attachment") then found.WorldPosition else nil
end

local function takeTool(state: State, name: string?)
	dropTool(state)
	local folder = walk(New.ToolFolder)
	local template = if folder and name then folder:FindFirstChild(name) else nil
	state.toolGrip = CFrame.identity
	local copy: PVInstance
	if template and template:IsA("Tool") and state.toolGripOn then
		-- a536 (L-508) : un Tool n'est pas un PVInstance (ni GetPivot ni PivotTo) : ses enfants passent dans un Model,
		-- pivot sur le Handle, et son Grip est gardé pour poseTool. Coupé : un Tool n'est pas posé, comme avant.
		local source = template:Clone()
		local model = Instance.new("Model")
		model.Name = source.Name
		state.toolGrip = source.Grip:Inverse()
		for _, child in source:GetChildren() do
			child.Parent = model
		end
		source:Destroy()
		local main = model:FindFirstChild("Handle", true)
		if main and main:IsA("BasePart") then
			model.PrimaryPart = main
		end
		copy = model
	elseif template and template:IsA("PVInstance") then
		copy = template:Clone()
	else
		return
	end
	inert(copy)
	local handle = copy:FindFirstChild("Handle", true)
	state.toolOffset = if handle and handle:IsA("BasePart") then handle.CFrame:ToObjectSpace(copy:GetPivot()) else CFrame.identity
	state.tool = copy
	poseTool(state)
	copy.Parent = state.ctx.Folder
end

-- Vague 75 : rend le nom du modèle jeté (pour son son, aussi en LowEnd où rien n'est jeté), ou nil.
local function throwJunk(state: State): string?
	local folder = walk(New.ToolFolder)
	if folder == nil then
		return nil
	end
	local list: { Instance } = {}
	for _, child in folder:GetChildren() do
		if string.sub(child.Name, 1, #New.JunkPrefix) == New.JunkPrefix and child:IsA("PVInstance") then
			table.insert(list, child)
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	state.junkIndex += 1
	local picked = list[(state.junkIndex + state.ctx.Plan.Odds) % #list + 1]
	if state.ctx.LowEnd then
		return picked.Name
	end
	local copy = picked:Clone()
	if not copy:IsA("PVInstance") then
		return picked.Name
	end
	inert(copy)
	local from = boxTop(state)
	copy:PivotTo(CFrame.new(from))
	copy.Parent = state.ctx.Folder
	table.insert(state.junk, {
		model = copy,
		position = from,
		velocity = UP * New.JunkSpeedUp + state.side * New.JunkSpeedBack,
		spin = New.JunkSpin * (0.6 + math.random() * 0.8),
		angle = 0,
		t = 0,
	})
	return picked.Name
end

local function stepJunk(state: State, dt: number)
	for index = #state.junk, 1, -1 do
		local junk = state.junk[index]
		junk.t += dt
		if junk.t >= New.JunkLife then
			junk.model:Destroy()
			table.remove(state.junk, index)
			continue
		end
		junk.velocity -= UP * (New.JunkGravity * dt)
		junk.position += junk.velocity * dt
		junk.angle += junk.spin * dt
		pcall(function()
			junk.model:PivotTo(CFrame.new(junk.position) * CFrame.Angles(junk.angle, junk.angle * 0.7, 0))
		end)
	end
end

-- Silhouettes ------------------------------------------------------------------------------------------------------

local function blacken(model: Model, color: Color3, material: Enum.Material)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = color
			d.Material = material
			if d:IsA("MeshPart") then
				pcall(function()
					d.TextureID = ""
				end)
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		elseif d:IsA("Decal") or d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
end

local function itemTemplate(itemId: string): Instance?
	local def = Items.ById[itemId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("Items") else nil
	local template = if folder and def then folder:FindFirstChild(def.Asset, true) else nil
	return if template and (template:IsA("Model") or template:IsA("BasePart")) then template else nil
end

-- Objet montré en silhouette pour la rareté `rarity` : un objet de la zone du magasin, sinon de n'importe quelle zone.
local function silhouetteItem(state: State, rarity: string, index: number): string?
	local store = state.ctx.Store
	local zone = if store then store:GetAttribute("Zone") else nil
	local byZone: any = if type(zone) == "number" then (Items.ByZone :: any)[zone] else nil
	local zoned: { Items.Item }? = if byZone then byZone[rarity] else nil
	local everywhere: { Items.Item }? = (Items.AllZones :: any)[rarity]
	local list: { Items.Item } = {}
	if zoned and #zoned > 0 then
		list = zoned
	elseif everywhere and #everywhere > 0 then
		list = everywhere
	else
		for _, item in Items.List do
			if item.Rarity == rarity and not item.TutorialOnly and not item.OutOfDraw then -- a497 : jamais un hors tirage
				table.insert(list, item)
			end
		end
	end
	if #list == 0 then
		return nil
	end
	return list[(state.ctx.Plan.Odds + index) % #list + 1].Id
end

local function dropSilhouette(state: State)
	local silhouette = state.silhouette
	if silhouette then
		state.silhouette = nil
		silhouette:Destroy()
	end
end

local function silhouetteTop(state: State): Vector3
	local silhouette = state.silhouette
	local height = if silhouette then extents(silhouette).Y else 2
	return state.base.Position + UP * height
end

local function showSilhouette(state: State, index: number)
	dropSilhouette(state)
	local ctx = state.ctx
	local rarity = Rarities.List[index].Id
	local last = index >= state.silhouetteCount
	local itemId = if last then ctx.ItemId else silhouetteItem(state, rarity, index)
	local template = if itemId then itemTemplate(itemId) else nil
	local model: Model
	if template then
		model = asModel(template:Clone())
	else
		model = block(Vector3.new(1.2, 1.6, 1.2), BLACK)
	end
	inert(model)
	blacken(model, BLACK, Enum.Material.SmoothPlastic)
	model.Name = "UnboxSilhouette"
	if last then
		scaleTo(model, scaleOf(model) * ctx.ItemScale)
	else
		local size = extents(model)
		local longest = math.max(size.X, size.Y, size.Z, 0.1)
		scaleTo(model, scaleOf(model) * New.SilhouetteFit * (1 + New.SilhouetteGrow * (index - 1)) / longest)
	end
	state.silhouetteIndex = index
	state.silhouetteHome = state.base
	model:PivotTo(state.base * CFrame.Angles(0, if last then 0 else state.spin, 0))
	model.Parent = ctx.Folder
	state.silhouette = model
	local top = silhouetteTop(state)
	local center = state.base.Position:Lerp(top, 0.5)
	state.anchor.CFrame = CFrame.new(top - UP * New.OddsBelowTop)
	showRarity(state, rarity)
	if UnboxPlan.climbs() then
		-- a287 (Cantin, 21/11) : la cote reste au-dessus des silhouettes et monte à chacune, vers la vraie cote.
		local text = state.oddsLabel
		if text then
			text.Visible = true
		end
		rollOdds(state, UnboxPlan.climbSilhouette(ctx.Plan, index, state.silhouetteCount))
	end
	local color = colorOf(rarity)
	spawnFx(state, New.Fx.Silhouette, CFrame.new(center), nil, color, true)
	spawnFx(state, New.Fx.Puff, CFrame.new(center), nil, color, true)
	flash(state, rarity, false)
	sound(state, New.SilhouetteSound, 1 + 0.06 * (index - 1))
	if last then
		sound(state, New.SuspenseSound)
	end
end

-- Actions ----------------------------------------------------------------------------------------------------------

local function stopTrack(state: State, fade: number)
	for _, connection in state.connections do
		connection:Disconnect()
	end
	table.clear(state.connections)
	local track = state.track
	state.track = nil
	if track then
		pcall(function()
			track:Stop(fade)
		end)
	end
end

local function stopRunFx(state: State)
	state.runFx = nil
end

local function burst(state: State)
	local ctx = state.ctx
	local giant = ctx.SizeClass == "Large" or ctx.SizeClass == "Colossal"
	local foot = CFrame.new(state.floor.Position)
	local color = colorOf(state.tier)
	if spawnFx(state, if giant then New.Fx.GiantBurst else New.Fx.Burst, foot, boxTop(state), color, true) == nil and giant then
		spawnFx(state, New.Fx.Burst, foot, boxTop(state), color, true)
	end
	dropBox(state)
	local climbs = UnboxPlan.climbs()
	local text = state.oddsLabel
	if text and not climbs then
		text.Visible = false
	end
	local rarityText = state.rarityLabel
	if rarityText then
		rarityText.Visible = false
	end
	local upgrade = state.upgradeLabel
	if upgrade then
		upgrade.Visible = false
	end
	if state.luckShown then
		-- a462 (L-376) : la chance laisse la place à la cote, qui part de Start et monte sur les silhouettes.
		state.luckShown = false
		if state.tierStyle then
			LuckTierStyle.Clear(state.tierStyle) -- a523 (L-442) : la cote reprend le style d'avant
			state.tierStyle = nil
			if state.oddsScale then
				state.oddsScale.Scale = 1
			end
		end
		state.oddsT = -1
		if text then
			text.Visible = climbs
		end
		showOdds(state, UnboxPlan.startOdds(state.ctx.Plan))
	elseif climbs then
		rollOdds(state, UnboxPlan.climbHit(state.ctx.Plan, state.index, 1, 1)) -- a287 : le coup qui casse compte aussi
	else
		state.oddsT = -1
	end
	if state.spacing then
		-- a536 (L-504) : plus de recul ; l'ouvreur va au sol face à l'objet, dans un nuage (stepEnd).
		state.endT = 0
		state.endStage = 0
		local root = rootOf(state)
		state.endHold = if root then root.CFrame else nil
	else
		state.recoilLeft = New.RecoilTime
	end
	stopSounds(state, nil) -- vague 75 (L-261) : la scie, la perceuse… s'arrêtent en fondu ; puis l'éclatement et la fumée
	for _, name in SOUNDS.Burst do
		sound(state, name)
	end
	state.smoked = true
	state.phase = "Burst"
	state.t = 0
	table.insert(state.events, "Burst")
end

-- Moment fort de l'action en cours : la cote défile, le colis s'améliore si la rareté montrée change ; à la dernière
-- action, le colis éclate.
local function momentFort(state: State)
	if state.strong then
		return
	end
	state.strong = true
	stopRunFx(state)
	local plan = state.ctx.Plan
	if state.index >= #plan.Steps then
		burst(state)
		return
	end
	-- a287 : New.OddsClimb, l'action entière sur la courbe qui finit à la vraie cote ; sinon la plage de la rareté.
	if state.luckShown and plan.Hits ~= nil then
		-- a523 (L-462) : au moment fort, tous les gains de l'action sont montrés (même si l'animation a eu moins d'Impacts).
		showHits(state, state.hitOffset + #state.moves[state.index].Action.Impacts)
	elseif state.luckShown then
		rollLuck(state, UnboxPlan.luckHit(plan, state.index, 1, 1)) -- a462 (L-376) : la chance monte
	else
		rollOdds(state, if UnboxPlan.climbs() then UnboxPlan.climbHit(plan, state.index, 1, 1) else UnboxPlan.oddsAt(plan, state.index))
	end
	local rarity = plan.Steps[state.index].Rarity
	if rarity ~= state.tier then
		state.tier = rarity
		if state.grown then
			state.tierScale *= New.UpgradeGrow
		else
			state.growPending *= New.UpgradeGrow -- a536 (L-502) : gardé pour le grossissement avant la dernière action
		end
		local color = colorOf(rarity)
		if not swapBox(state, rarity) then
			for _, tape in state.tapes do
				tape.Color = color
			end
		end
		showRarity(state, rarity)
		local upgrade = state.upgradeLabel
		if upgrade then
			upgrade.Visible = true
			state.upgradeLeft = New.UpgradeShow
		end
		spawnFx(state, New.Fx.Tier, CFrame.new(state.floor.Position), boxTop(state), color, true)
		flash(state, rarity, false)
		sound(state, New.UpgradeSound)
	end
end

local function onImpact(state: State)
	if state.phase ~= "Action" then
		return
	end
	local move = state.moves[state.index]
	if move == nil then
		return
	end
	local action = move.Action
	state.impacts += 1
	local strong = state.impacts >= #action.Impacts and not state.strong
	reactNow(state, action.React, if strong then 1 else REACT.Before)
	spawnFx(state, action.Fx, CFrame.new(state.floor.Position), hitPoint(state) or boxTop(state), colorOf(state.tier), true)
	-- Vague 75 (L-261) : les sons de Start arrêtés au 1er Impact, le son de cet Impact, la boîte qui glisse, l'objet
	-- jeté (hauteur au hasard), la fumée de l'effet (moins fort après la 1re fois ; pas au coup qui fait éclater).
	local cfg = SOUNDS.Actions[action.Id]
	stopSounds(state, "Impact")
	local hits = if cfg then cfg.Impacts else nil
	if hits and #hits > 0 then
		sound(state, hits[math.min(state.impacts, #hits)], if action.Junk then junkPitch() else nil)
	end
	if table.find(SOUNDS.SlideReacts, action.React) then
		sound(state, SOUNDS.Slide)
	end
	if action.Junk then
		local thrown = throwJunk(state)
		if thrown then
			local squeak = false
			for _, prefix in SOUNDS.SqueakJunk do
				squeak = squeak or string.sub(thrown, 1, #prefix) == prefix
			end
			sound(state, if squeak then SOUNDS.JunkSqueak else SOUNDS.JunkBoing, junkPitch())
		end
	end
	local final = strong and state.index >= #state.ctx.Plan.Steps
	if not final and not (cfg and cfg.Smoke == false) and fxHasSmoke(action.Fx) then
		local smoke = sound(state, SOUNDS.Smoke)
		if smoke and state.smoked then
			local quiet = SOUNDS.SmokeAgainVolume
			pcall(function()
				smoke.Volume = math.min(smoke.Volume, quiet)
			end)
		end
		state.smoked = state.smoked or smoke ~= nil
	end
	if action.Mark and strong then
		showMark(state, New.MarkImpact)
	end
	if strong then
		momentFort(state)
	elseif not state.strong and state.luckShown and state.ctx.Plan.Hits ~= nil then
		showHits(state, state.hitOffset + state.impacts) -- a523 (L-462) : les gains de cet Impact
	elseif not state.strong and state.luckShown then
		-- a462 (L-376) : chaque coup fait monter la chance d'un pas.
		rollLuck(state, UnboxPlan.luckHit(state.ctx.Plan, state.index, state.impacts, #action.Impacts))
	elseif not state.strong and UnboxPlan.climbs() then
		-- a287 (Cantin, 21/11 : « casser plusieurs fois la boîte pour augmenter la chance ») : chaque coup fait monter
		-- la cote d'un pas ; le moment fort finit l'action.
		rollOdds(state, UnboxPlan.climbHit(state.ctx.Plan, state.index, state.impacts, #action.Impacts))
	end
end

local function startAction(state: State, index: number)
	local ctx = state.ctx
	state.index = index
	state.hitOffset = 0 -- a523 (L-462) : Impacts attendus des actions d'avant
	for previous = 1, index - 1 do
		state.hitOffset += #state.moves[previous].Action.Impacts
	end
	state.phase = "Action"
	state.t = 0
	state.impacts = 0
	state.strong = false
	state.mode = "Fallback"
	state.trackStopped = false
	if index >= #state.moves then
		finishGrow(state) -- a536 (L-502) : la dernière action joue sur le colis grossi
	end
	local action = state.moves[index].Action
	takeTool(state, action.Tool)
	dropMark(state)
	if action.Mark then
		showMark(state, New.MarkStart)
	end
	if action.RunFx then
		local fx = spawnFx(state, action.RunFx, CFrame.new(state.floor.Position), boxTop(state), colorOf(state.tier), false)
		local every = if fx then fx:GetAttribute("EmitEvery") else nil
		state.runFx = fx
		state.runEvery = if type(every) == "number" and every > 0 then every else 0.06
		state.runLeft = 0
	end
	-- Vague 75 (L-261) : le tremblement s'arrête ; sons de lancement, l'un après l'autre (stepSounds).
	stopSounds(state, "Gap")
	state.topDone = false
	local cfg = SOUNDS.Actions[action.Id]
	local starts = if cfg then cfg.Start else nil
	table.clear(state.queue)
	state.queueStop = if cfg then cfg.Stop else nil
	if starts and #starts > 0 then
		for at = 2, #starts do
			table.insert(state.queue, starts[at])
		end
		state.queueLeft = lengthOf(startSound(state, starts[1], state.queueStop))
	end
	if not ctx.Opener then
		return
	end
	local character = characterOf(state)
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	local animation = AnimPlayer.findAnimation(AnimPlayer.playerFolder(), action.Anim)
	if animator == nil or animation == nil then
		return
	end
	local found: Animation = animation
	local ok, loaded = pcall(function(): AnimationTrack
		return animator:LoadAnimation(found)
	end)
	if not ok then
		return
	end
	local track = loaded :: AnimationTrack
	table.insert(state.connections, track:GetMarkerReachedSignal("Impact"):Connect(function()
		if state.track == track and not state.destroyed then
			if strikeFeel then
				pcall(strikeFeel.impact, action.Anim, track)
			end
			onImpact(state)
		end
	end))
	table.insert(state.connections, track:GetMarkerReachedSignal("Top"):Connect(function()
		if state.track == track and not state.destroyed and state.phase == "Action" and not state.topDone then
			state.topDone = true
			sound(state, if cfg then cfg.Top else nil)
		end
	end))
	table.insert(state.connections, track.Stopped:Connect(function()
		if state.track == track then
			state.trackStopped = true
		end
	end))
	state.track = track
	state.mode = "Anim"
	pcall(function()
		track:Play(if strikeFeel then strikeFeel.fade(action.Anim, 0.1) else 0.1)
		track:AdjustSpeed(math.max(New.ActionSpeed, 0.1))
	end)
end

-- Places (vague 74, a257, L-258) : à gauche, à droite puis sur le colis, en se téléportant ----------------------------

local function hasAnim(name: string): boolean
	local ok, found = pcall(function(): Animation?
		return (AnimPlayer.findAnimation(AnimPlayer.playerFolder(), name))
	end)
	return ok and found ~= nil
end

-- Où se tient le perso (HumanoidRootPart) à la place `place` : face au colis ; sur le couvercle, face à la caméra
-- (le haut du colis suit son grossissement).
local function standAt(state: State, place: string): CFrame?
	if place == "Top" then
		local at = boxTop(state) + UP * state.standHeight
		return CFrame.lookAt(at, at + state.base.LookVector)
	end
	return state.stands[place]
end

local function torsoOf(state: State): Vector3?
	local character = characterOf(state)
	local part = if character then character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") else nil
	if part and part:IsA("BasePart") then
		return part.Position
	end
	local root = rootOf(state)
	return if root then root.Position else nil
end

-- Hauteur (studs) des pieds au-dessus du sol de l'allée : le plus bas des deux pieds (un coup de pied ne compte pas).
local function feetHeight(state: State): number
	local character = characterOf(state)
	local low = math.huge
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = if character then character:FindFirstChild(name) else nil
		if foot and foot:IsA("BasePart") then
			low = math.min(low, foot.Position.Y - foot.Size.Y / 2)
		end
	end
	if low == math.huge then
		local root = rootOf(state)
		if root == nil then
			return 0
		end
		low = root.Position.Y - state.standHeight
	end
	return math.max(low - state.base.Position.Y, 0)
end

-- Nuage FX_Unbox_Puff au torse (sans son depuis la vague 75, L-261).
local function puff(state: State)
	local at = torsoOf(state)
	if at then
		spawnFx(state, New.Fx.Puff, CFrame.new(at), nil, nil, true)
	end
end

-- Le perso disparaît en local, chez chaque joueur (LocalTransparencyModifier), puis revient comme avant.
local function hideCharacter(state: State)
	local character = characterOf(state)
	if character == nil then
		return
	end
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and state.hiddenChar[d] == nil then
			pcall(function()
				local any: any = d
				state.hiddenChar[d] = any.LocalTransparencyModifier
				any.LocalTransparencyModifier = 1
			end)
		end
	end
end

local function showCharacter(state: State)
	for inst, before in state.hiddenChar do
		pcall(function()
			(inst :: any).LocalTransparencyModifier = before
		end)
	end
	table.clear(state.hiddenChar)
end

-- Le perso arrive à `place` : les réactions du colis prennent son sens ; l'ouvreur y est posé.
local function arrive(state: State, place: string)
	state.place = place
	state.side = if place == "Other" then -state.side0 else state.side0
	local stand = standAt(state, place)
	local root = rootOf(state)
	if state.ctx.Opener and stand and root then
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = stand
		end)
	end
end

-- Pause avant l'action `nextIndex` : à la même place (le colis tremble), ou téléportation (nuage, « swish »).
local function startGap(state: State, nextIndex: number)
	local move = state.moves[nextIndex]
	state.phase = "Gap"
	state.t = 0
	state.teleport = move ~= nil and move.Teleport
	state.teleportStage = 0
	if state.teleport then
		puff(state)
	elseif nextIndex > 1 then
		-- Vague 75 (L-261) : le colis tremble, Unbox_Rattle en boucle, plus fort et plus aigu à chaque pause.
		local step = math.max(nextIndex - 2, 0)
		local rattle = startSound(state, SOUNDS.Rattle, "Gap")
		if rattle then
			local volume = math.min(1 + SOUNDS.RattleVolumeStep * step, SOUNDS.RattleMax)
			local pitch = 1 + SOUNDS.RattlePitchStep * step
			pcall(function()
				rattle.Looped = true
				rattle.Volume *= volume
				rattle.PlaybackSpeed = pitch
			end)
		end
	end
end

-- Téléportation : disparu à Vanish, réapparu d'un coup à la nouvelle place à Appear (second nuage, « pop »), puis le
-- rebond jusqu'à la fin (Step).
local function stepTeleport(state: State)
	local places = New.Places
	local speed = math.max(New.ActionSpeed, 0.1)
	if state.teleportStage == 0 and state.t >= places.Vanish / speed then
		state.teleportStage = 1
		hideCharacter(state)
	end
	if state.teleportStage == 1 and state.t >= places.Appear / speed then
		state.teleportStage = 2
		local move = state.moves[state.index + 1]
		arrive(state, if move then move.Place else state.place)
		showCharacter(state)
		puff(state)
	end
end

-- Chaque image : l'ouvreur reste debout sur le couvercle (le colis local n'a pas de collision) et rebondit à sa
-- réapparition ; la caméra monte avec ses pieds ; BB_UnboxOdds glisse sur le côté quand il est sur le colis.
local function stepPlaces(state: State, dt: number)
	local places = New.Places
	local busy = state.phase == "Action" or state.phase == "Gap"
	if state.ctx.Opener and busy then
		local hold = if state.place == "Top" then standAt(state, "Top") else nil
		if state.phase == "Gap" and state.teleport and state.teleportStage == 2 then
			local speed = math.max(New.ActionSpeed, 0.1)
			local span = math.max((places.Teleport - places.Appear) / speed, 1e-3)
			local f = math.clamp((state.t - places.Appear / speed) / span, 0, 1)
			local base = hold or standAt(state, state.place)
			hold = if base then base + UP * (places.Bounce * math.sin(math.pi * f)) else nil
		end
		local root = rootOf(state)
		if hold and root then
			local frame = hold
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = frame
			end)
		end
	end
	if places.Enabled ~= true then
		return
	end
	if state.ctx.Opener then
		local target = math.clamp(places.CameraLift * feetHeight(state), 0, 10)
		state.camLift += (target - state.camLift) * math.min(1, dt * places.CameraLiftSpeed)
	end
	local slide = if state.place == "Top" and busy then places.OddsSlide else 0
	state.slide += (slide - state.slide) * math.min(1, dt * places.OddsSlideSpeed)
	local board = state.board
	if board and not state.revealed then
		board.StudsOffsetWorldSpace = state.boardFrom + state.side0 * state.slide
	end
end

-- a536 (L-504) : demi-largeur (studs) de l'objet à sa taille finale : plus grand côté à plat de son modèle (son
-- orientation à la révélation n'est pas connue ici) × ItemFinalScale ; sans modèle : 1.
local function itemHalfWidth(state: State): number
	local ctx = state.ctx
	local template = itemTemplate(ctx.ItemId)
	local size = Vector3.new(2, 2, 2)
	if template and template:IsA("Model") then
		size = extents(template)
	elseif template and template:IsA("BasePart") then
		size = template.Size
	end
	local scale = ctx.ItemFinalScale or ctx.ItemScale
	return math.max(size.X, size.Z) / 2 * math.max(scale, 0)
end

-- a536 (L-504) : place de fin de l'ouvreur, au sol : D = max(EndStandMin, demi-largeur + EndStandGap) du centre de
-- l'objet, du côté Side s'il a la place, sinon de l'autre ; sinon la plus grande place, au moins demi-largeur +
-- EndStandMinGap ; tourné vers l'objet (même hauteur).
local function endStand(state: State): CFrame
	local foot = state.base.Position
	local half = itemHalfWidth(state)
	local want = math.max(New.EndStandMin, half + New.EndStandGap)
	local probe = foot + UP * 2
	local exclude = excluded(state, state.ctx)
	local function room(direction: Vector3): number
		local hit = raycast(probe, direction * (want + 0.5), exclude, true)
		return if hit then (hit.Position - probe).Magnitude - 0.5 else want
	end
	local direction = state.side0
	local distance = want
	local first = room(direction)
	if first < want then
		local second = room(-direction)
		if second >= want then
			direction = -direction
		else
			if second > first then
				direction = -direction
				first = second
			end
			distance = math.max(first, half + New.EndStandMinGap)
		end
	end
	local at = foot + direction * distance + UP * state.standHeight
	return CFrame.lookAt(at, Vector3.new(foot.X, at.Y, foot.Z))
end

-- a536 (L-504) : après l'éclatement, comme une téléportation (Places : nuage, disparition à Vanish, réapparition à
-- Appear à la place de fin) ; l'ouvreur reste où il était jusqu'à sa disparition.
local function stepEnd(state: State, dt: number)
	if state.endT < 0 then
		return
	end
	state.endT += dt
	local places = New.Places
	local speed = math.max(New.ActionSpeed, 0.1)
	local root = rootOf(state)
	local opener = state.ctx.Opener
	if state.endStage == 0 then
		state.endStage = 1
		puff(state)
	end
	if state.endStage == 1 and state.endT >= places.Vanish / speed then
		state.endStage = 2
		hideCharacter(state)
	end
	if state.endStage <= 2 and opener and root and state.endHold then
		local hold = state.endHold :: CFrame
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = hold
		end)
	end
	if state.endStage == 2 and state.endT >= places.Appear / speed then
		state.endStage = 3
		state.endT = -1
		if opener and root then
			local stand = endStand(state)
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = stand
			end)
		end
		showCharacter(state)
		puff(state)
	end
end

local function endAction(state: State)
	if state.phase ~= "Action" then
		return
	end
	momentFort(state) -- au plus tard à la fin de l'action
	if state.phase ~= "Action" then
		return -- dernière action : le colis a éclaté
	end
	stopTrack(state, 0.1)
	dropTool(state)
	dropMark(state)
	stopSounds(state, nil) -- vague 75 (L-261) : les sons de l'action s'arrêtent en fondu
	startGap(state, state.index + 1)
end

local function stepAction(state: State, dt: number)
	local action = state.moves[state.index].Action
	local fx = state.runFx
	if fx then
		state.runLeft -= dt
		if state.runLeft <= 0 then
			state.runLeft = state.runEvery
			emitAll(fx, colorOf(state.tier))
		end
	end
	if state.mode == "Anim" then
		local track = state.track
		if track == nil then
			state.mode = "Fallback"
			state.t = 0
			return
		end
		if track.Length <= 0 then
			if state.t >= RevealConfig.AnimLoadWait then
				stopTrack(state, 0)
				state.mode = "Fallback"
				state.t = 0
			end
			return
		end
		if state.trackStopped or (not track.IsPlaying and state.t > 0.1) or state.t >= UnboxPlan.actionLimit(action) then
			endAction(state)
		end
		return
	end
	local duration = UnboxPlan.actionTime(action)
	local cfg = SOUNDS.Actions[action.Id]
	if cfg and cfg.Top and cfg.TopAt and not state.topDone and state.t >= cfg.TopAt * duration then
		state.topDone = true -- vague 75 (L-261) : instant de repli du marqueur Top
		sound(state, cfg.Top)
	end
	for index, at in action.Impacts do
		if state.phase == "Action" and index > state.impacts and state.t >= at * duration then
			onImpact(state)
		end
	end
	if state.phase == "Action" and state.t >= duration then
		endAction(state)
	end
end

-- Place du colis, du perso et de la caméra -------------------------------------------------------------------------

local function insideBounds(store: Model?, point: Vector3): boolean
	local bounds = if store then store:FindFirstChild("Bounds", true) else nil
	if bounds == nil or not bounds:IsA("BasePart") then
		return true
	end
	local at = bounds.CFrame:PointToObjectSpace(point)
	return math.abs(at.X) <= bounds.Size.X / 2 and math.abs(at.Z) <= bounds.Size.Z / 2
end

-- Sol sous `point` : rayon vers le bas depuis la hauteur de l'emplacement, sinon le bas de Bounds, sinon `point`.
local function floorUnder(ctx: Context, point: Vector3, exclude: { Instance }): number
	local hit = raycast(point + UP, -UP * (New.FloorProbe + 1), exclude, true)
	if hit then
		return hit.Position.Y
	end
	local store = ctx.Store
	local bounds = if store then store:FindFirstChild("Bounds", true) else nil
	if bounds and bounds:IsA("BasePart") then
		return bounds.Position.Y - bounds.Size.Y / 2
	end
	return point.Y
end

-- Où poser le colis au sol : depuis l'emplacement du rayon, la direction dégagée qui descend le plus bas, dans le
-- magasin (face avant de l'emplacement d'abord, puis vers le centre du magasin, puis les autres côtés).
local function place(ctx: Context): (Vector3, Vector3)
	local slot = ctx.SlotFrame
	local exclude = excluded(nil, ctx)
	local candidates: { Vector3 } = {}
	for _, v in { slot.LookVector, ctx.AisleHint, -slot.LookVector, slot.RightVector, -slot.RightVector } do
		local direction = flat(v)
		if direction then
			table.insert(candidates, direction)
		end
	end
	if #candidates == 0 then
		candidates = { Vector3.new(0, 0, -1) }
	end
	local need = New.BoxOut + New.BoxClear
	local origin = slot.Position + UP
	local best: Vector3? = nil
	local bestFloor = math.huge
	local widest, widestFree = candidates[1], -1
	for _, direction in candidates do
		local hit = raycast(origin, direction * (need + 4), exclude, true)
		local free = if hit then (hit.Position - origin).Magnitude else need + 4
		if free > widestFree then
			widest, widestFree = direction, free
		end
		local point = slot.Position + direction * New.BoxOut
		if free >= need and insideBounds(ctx.Store, point) then
			local y = floorUnder(ctx, point, exclude)
			if y < bestFloor - 0.25 then
				best, bestFloor = direction, y
			end
		end
	end
	local direction = best or widest
	local out = if best then New.BoxOut else math.clamp(widestFree - New.BoxClear, math.min(New.BoxOutMin, New.BoxOut), New.BoxOut)
	local point = slot.Position + direction * out
	local y = if best then bestFloor else floorUnder(ctx, point, exclude)
	return Vector3.new(point.X, y, point.Z), direction
end

-- Sphère lancée de `origin` le long de `direction` (Workspace:Spherecast), sans tenir compte de CanCollide ; nil sans
-- contact (ou dans un faux Workspace de banc qui ne la connaît pas).
local function spherecast(origin: Vector3, radius: number, direction: Vector3, exclude: { Instance }): RaycastResult?
	local ok, result = pcall(function(): RaycastResult?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		return Workspace:Spherecast(origin, radius, direction, params)
	end)
	return if ok then result else nil
end

-- a449 (testeur 1, 24/11, bande grise en haut de l'écran) : le rayon de Clear ne suit que l'axe de la vue ; il passait
-- entre deux planches du rayon d'en face et la caméra de la révélation (14 studs pour l'objet de base ×2) finissait
-- DANS ce rayon, sous sa planche du haut. Une sphère de rayon CAM.Room suit le même trajet : touchée assez loin, la
-- caméra s'arrête devant (Margin) ; plus près que MinDistance, elle reste où le rayon l'a mise (rien de plus caché).
-- a451 (Play de fusion101) : une pièce frôlée plus près que MinDistance (le sol sous un petit objet : la sphère part
-- de son point visé, à moins de Room du sol ; le bord d'un rayon) ne coupait plus seulement ce contact : elle arrêtait
-- tout le test, et le meuble d'en face, plus loin sur le trajet, n'était jamais vu. Elle est maintenant écartée comme un
-- volume invisible (la ligne de vue est déjà dégagée par clearLine), et la sphère continue.
local ROOM_TRIES = 12 -- contacts écartés au plus (sol en dalles, bords de rayon, volumes invisibles) avant d'abandonner
local function roomy(state: State, cam: Vector3, focus: Vector3): Vector3
	local radius = CAM.Room
	local offset = cam - focus
	if type(radius) ~= "number" or radius <= 0 or offset.Magnitude < 1e-3 then
		return cam
	end
	local exclude = excluded(state, state.ctx)
	for _ = 1, ROOM_TRIES do
		local hit = spherecast(focus, radius, offset, exclude)
		if hit == nil then
			return cam
		end
		local part = hit.Instance
		if part:IsA("BasePart") and part.Transparency >= 0.95 then
			table.insert(exclude, part) -- volume invisible : ne gêne pas la vue
			continue
		end
		if hit.Distance - CAM.Margin >= CAM.MinDistance then
			return focus + offset.Unit * (hit.Distance - CAM.Margin)
		end
		table.insert(exclude, part) -- frôlé tout près : ni recul, ni pièce cachée ; on cherche plus loin
	end
	return cam
end

-- Vue dégagée du point `focus` vers `from` (ouvreur) : un obstacle assez loin rapproche la caméra devant lui ; plus
-- près que MinDistance, il devient transparent pour ce joueur jusqu'à la fin de la scène (L-234). Puis (a449) la
-- caméra n'entre dans aucun meuble (roomy).
local function clearLine(state: State, from: Vector3, focus: Vector3): Vector3
	local offset = from - focus
	local distance = offset.Magnitude
	if distance < 1e-3 then
		return from
	end
	for _ = 1, 6 do
		local hit = raycast(focus, offset, excluded(state, state.ctx), false)
		if hit == nil then
			return from
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or #state.ignored + #state.seeThrough >= CAM.MaxHidden * 2 then
			return from
		end
		if part.Transparency >= 0.95 then
			table.insert(state.ignored, part) -- volume invisible : ni mur, ni rien à cacher
			continue
		end
		local reach = (hit.Position - focus).Magnitude
		if reach - CAM.Margin >= CAM.MinDistance then
			return focus + offset.Unit * (reach - CAM.Margin)
		end
		if #state.seeThrough >= CAM.MaxHidden then
			return from
		end
		table.insert(state.seeThrough, part)
		state.ctx.Hide(part)
	end
	return from
end

function Unbox.Clear(state: State, from: Vector3, focus: Vector3): Vector3
	if not state.ctx.Opener or state.destroyed then
		return from
	end
	return roomy(state, clearLine(state, from, focus), focus)
end

-- Caméra de l'ouvreur pendant l'ouverture : côté allée, le colis et le perso de profil.
function Unbox.CameraTarget(state: State): CFrame
	local aisle = state.base.LookVector
	local foot = state.base.Position
	-- Vague 74 : la caméra reste du côté de la première place, et monte avec les pieds du perso (L-258).
	local focus = foot + state.side0 * (New.StandSide * 0.5) + UP * (CAM.LookHeight + state.camLift)
	local from = focus + aisle * CAM.Distance + UP * (CAM.Height - CAM.LookHeight)
	return CFrame.lookAt(Unbox.Clear(state, from, focus), focus)
end

local function placeCharacter(state: State)
	local ctx = state.ctx
	local exclude = excluded(nil, ctx)
	local foot = state.base.Position
	local aisle = state.base.LookVector
	local right = aisle:Cross(UP)
	local side = right
	local probe = foot + UP * 2
	-- a491 (L-429 point 2) : colis de l'ouverture agrandi (OPEN_BOX_HEIGHT) : le perso se tient au moins à la moitié de
	-- sa plus grande largeur + 1 stud (la moitié du perso) du centre, pour ne pas entrer dedans. Coupé : StandSide.
	local standSide = New.StandSide
	local shownBox = state.box
	if state.spacing and shownBox ~= nil then
		-- a536 (L-502) : espacement v2 : StandSide, ou la demi-largeur du colis dans l'axe du perso + StandFaceGap.
		local ok, frame, size = pcall(function()
			return shownBox:GetBoundingBox()
		end)
		if ok and typeof(frame) == "CFrame" and typeof(size) == "Vector3" then
			local half = (math.abs(frame.RightVector:Dot(right)) * size.X
				+ math.abs(frame.UpVector:Dot(right)) * size.Y
				+ math.abs(frame.LookVector:Dot(right)) * size.Z) / 2
			standSide = math.max(standSide, half + New.StandFaceGap)
		end
	elseif OPEN_BOX_HEIGHT ~= nil and shownBox ~= nil then
		local size = extents(shownBox)
		standSide = math.max(standSide, math.max(size.X, size.Z) / 2 + 1)
	end
	local reach = standSide + 1.5
	local hitRight = raycast(probe, right * reach, exclude, true)
	local hitLeft = raycast(probe, -right * reach, exclude, true)
	local freeRight = if hitRight then (hitRight.Position - probe).Magnitude else reach
	local freeLeft = if hitLeft then (hitLeft.Position - probe).Magnitude else reach
	local free, other = freeRight, freeLeft
	if freeLeft > freeRight + 0.25 then
		side = -right
		free, other = freeLeft, freeRight
	end
	state.side = side
	state.side0 = side
	local root = rootOf(state)
	if root == nil then
		return
	end
	local character = characterOf(state)
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local height = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
	state.standHeight = height
	local function standOn(direction: Vector3, room: number): CFrame
		local at = foot + direction * math.min(standSide, math.max(room, 1.5) - 0.5) + UP * height
		return CFrame.lookAt(at, Vector3.new(foot.X, at.Y, foot.Z))
	end
	local stand = standOn(side, free)
	state.stand = stand
	state.stands = { Side = stand, Other = standOn(-side, other) } -- vague 74 (L-258) : de l'autre côté du colis
	if ctx.Opener then
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = stand
		end)
	end
end

-- a421 (L-316) : ce qui dessine le vrai colis hors de ses pièces (cachées par ctx.Hide), quel qu'en soit le nom ou la
-- forme : contour (Highlight), arêtes (SelectionBox, ou tout autre adornement GuiBase3d), étiquette (BB_Box, ou tout
-- autre Gui), effets, décalques. Propriété qui l'éteint et sa valeur éteinte ; nil : rien à éteindre.
local function muteRule(inst: Instance): (string?, any)
	if
		inst:IsA("Highlight")
		or inst:IsA("LayerCollector")
		or inst:IsA("ParticleEmitter")
		or inst:IsA("Beam")
		or inst:IsA("Trail")
		or inst:IsA("Light")
	then
		return "Enabled", false
	elseif inst:IsA("GuiBase3d") then
		return "Visible", false
	elseif inst:IsA("Decal") then -- Texture compris
		return "LocalTransparencyModifier", 1
	end
	return nil, nil
end

local function mute(state: State, inst: Instance)
	if state.muted[inst] ~= nil or state.destroyed then
		return
	end
	local property, off = muteRule(inst)
	if property == nil then
		return
	end
	local target: any = inst
	state.muted[inst] = { property = property, off = off, was = target[property] }
	target[property] = off
end

-- API --------------------------------------------------------------------------------------------------------------

function Unbox.Begin(ctx: Context): State
	local point, aisle = place(ctx)
	local anchor = Instance.new("Part")
	anchor.Name = "UnboxAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(point)
	anchor.Parent = ctx.Folder
	local first = ctx.Plan.Steps[1]
	local home = ctx.SlotFrame
	local shelfBox = ctx.ShelfBox
	if shelfBox and shelfBox:IsA("PVInstance") then
		home = shelfBox:GetPivot()
	end
	local spacing = featureOn("UnboxSpacingV2") -- a536 (L-502, L-504)
	local state: State = {
		ctx = ctx,
		phase = "Intro",
		t = 0,
		events = {},
		base = CFrame.lookAt(point, point + aisle),
		side = aisle:Cross(UP),
		stand = nil,
		side0 = aisle:Cross(UP),
		stands = {},
		standHeight = 3,
		moves = UnboxPlan.moves(ctx.Plan, hasAnim(New.Places.Stomp.Anim), hasAnim(New.Places.Slam.Anim)),
		place = "Side",
		teleport = false,
		teleportStage = 0,
		hiddenChar = {},
		camLift = 0,
		slide = 0,
		boardFrom = Vector3.zero,
		home = home,
		floor = CFrame.new(point) * home.Rotation,
		box = nil,
		boxScale0 = 1,
		boxHeight = 1.6,
		tierScale = 1,
		spacing = spacing,
		grown = not (spacing and New.GrowAt == "TopTeleport"),
		growPending = 1,
		endT = -1,
		endStage = 0,
		endHold = nil,
		appliedScale = 1,
		lid = nil,
		lidOffset = CFrame.identity,
		tapes = {},
		anchor = anchor,
		board = nil,
		boardOffset = 0,
		oddsLabel = nil,
		rarityLabel = nil,
		upgradeLabel = nil,
		oddsScale = nil,
		odds = 1,
		oddsFrom = 1,
		oddsTo = 1,
		oddsT = -1,
		luckShown = false,
		hitsShown = 0,
		hitImpacts = 0,
		hitOffset = 0,
		gains = {},
		tierStyle = nil,
		oddsPop = 1,
		oddsTicks = 0,
		upgradeLeft = 0,
		finalLeft = 0,
		tier = first.Rarity,
		index = 0,
		mode = "Fallback",
		track = nil,
		trackStopped = false,
		connections = {},
		impacts = 0,
		strong = false,
		tool = nil,
		toolOffset = CFrame.identity,
		toolGrip = CFrame.identity,
		toolGripOn = featureOn("UnboxToolGrip"),
		mark = nil,
		runFx = nil,
		runEvery = 0.06,
		runLeft = 0,
		react = nil,
		reactT = 0,
		reactForce = 1,
		junk = {},
		junkIndex = 0,
		timed = {},
		silhouette = nil,
		silhouetteIndex = 0,
		silhouetteCount = math.max((rarityOf(ctx.Rarity) or Rarities.List[1]).Order, 1),
		silhouetteHome = CFrame.new(point),
		spin = 0,
		zoom = { value = 0, target = 0, hold = 0 },
		edge = { value = 0, target = 0, hold = 0 },
		edgeColor = WHITE,
		edgeLabel = nil,
		edgeScreen = nil,
		edgeWasEnabled = false,
		baseFov = nil,
		seeThrough = {},
		ignored = {},
		muted = {},
		shelfAdded = nil,
		recoilLeft = 0,
		revealed = false,
		released = false,
		destroyed = false,
		running = {},
		fading = {},
		queue = {},
		queueLeft = 0,
		queueStop = nil,
		topDone = false,
		smoked = false,
		created = { anchor },
	}
	-- a536 (L-502) : le colis grossit dans le nuage de la téléportation sur le couvercle avant Unbox_Slam : après un
	-- Stomp sur le couvercle, la dernière action y est aussi précédée d'une téléportation (Top à Top).
	local lastMove = state.moves[#state.moves]
	if not state.grown and #state.moves >= 2 and lastMove and lastMove.Place == "Top" and not lastMove.Teleport then
		state.moves[#state.moves] = { Action = lastMove.Action, Place = lastMove.Place, Teleport = true }
	end
	-- a523 (L-462) : Impacts attendus avant le coup final (ceux de la Config : les mêmes chez tous les joueurs).
	for index = 1, #state.moves - 1 do
		state.hitImpacts += #state.moves[index].Action.Impacts
	end
	buildBox(state)
	buildBoard(state)
	placeCharacter(state)
	if shelfBox then
		-- Le vrai colis est caché en local, mais son étiquette et son contour se verraient encore sur le rayon.
		-- ShelfBoxController les rallume selon la distance : ils sont rééteints à chaque image (Unbox.Step).
		-- a421 (L-316) : tout ce qui le dessine hors de ses pièces, quel qu'en soit le nom ou la forme (muteRule), même
		-- ajouté pendant la scène ; remis à la fin (Unbox.Destroy).
		mute(state, shelfBox)
		for _, d in shelfBox:GetDescendants() do
			mute(state, d)
		end
		state.shelfAdded = shelfBox.DescendantAdded:Connect(function(d: Instance)
			mute(state, d)
		end)
	end
	if ctx.Opener then
		local camera = Workspace.CurrentCamera
		if camera then
			state.baseFov = camera.FieldOfView
		end
		local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local screen = if gui then gui:FindFirstChild(New.EdgeScreen) else nil
		local glow = if screen then Find.path(screen, New.EdgeGlow) else nil
		if screen and screen:IsA("ScreenGui") and glow and glow:IsA("ImageLabel") then
			state.edgeScreen = screen
			state.edgeLabel = glow
			state.edgeWasEnabled = screen.Enabled
			glow.ImageTransparency = 1
			screen.Enabled = true
		end
	end
	poseBox(state, 0)
	return state
end

local function stepOdds(state: State, dt: number)
	if state.oddsT >= 0 then
		state.oddsT += dt
		local f = math.min(state.oddsT / New.OddsRoll, 1)
		local ticks = math.floor(state.oddsT / New.OddsTick)
		if ticks > state.oddsTicks or f >= 1 then
			state.oddsTicks = ticks
			showOdds(state, state.oddsFrom * (state.oddsTo / state.oddsFrom) ^ f)
			if state.ctx.Opener then
				-- a462 (L-386) : OddsTickPitch à 0, aucune hauteur imposée (le PlaybackSpeed 0,8 du son de Clément reste).
				sound(state, New.OddsTickSound, if New.OddsTickPitch ~= 0 then 1 + New.OddsTickPitch * ticks else nil)
			end
		end
		local scale = state.oddsScale
		state.oddsPop = 1 + (New.OddsPop - 1) * math.sin(math.pi * f)
		if scale then
			scale.Scale = state.oddsPop
		end
		if f >= 1 then
			state.oddsT = -1
			state.oddsPop = 1
		end
	end
	local styler = state.tierStyle
	if styler then
		-- a523 (L-442) : mouvement du palier, et sa taille (TextScale × rebond) dans le même UIScale que le gonflement.
		LuckTierStyle.Step(styler, dt)
		local scale = state.oddsScale
		if scale then
			scale.Scale = state.oddsPop * LuckTierStyle.Scale(styler)
		end
	end
	stepGains(state, dt) -- a523 (L-462)
	if state.upgradeLeft > 0 then
		state.upgradeLeft -= dt
		local upgrade = state.upgradeLabel
		if state.upgradeLeft <= 0 and upgrade then
			upgrade.Visible = false
		end
	end
end

local function stepScreen(state: State, dt: number)
	if not state.ctx.Opener or state.released then
		return
	end
	stepPulse(state.zoom, dt, New.ZoomIn, New.ZoomOut)
	stepPulse(state.edge, dt, New.EdgeIn, New.EdgeOut)
	local camera = Workspace.CurrentCamera
	local fov = state.baseFov
	if camera and fov then
		camera.FieldOfView = fov * (1 - state.zoom.value)
	end
	local glow = state.edgeLabel
	if glow then
		glow.ImageColor3 = state.edgeColor
		glow.ImageTransparency = 1 - state.edge.value
	end
end

-- Appelé par RevealController quand son marqueur Reveal tombe (à l'évènement « Reveal » d'ici, ou d'un coup à son
-- plafond de temps) : tout ce qui précède l'objet disparaît, la cote finale s'affiche au-dessus de BB_Reveal.
function Unbox.OnReveal(state: State)
	if state.revealed or state.destroyed then
		return
	end
	state.revealed = true
	stopTrack(state, 0.2)
	stopSounds(state, nil) -- vague 75 (L-261)
	stopRunFx(state)
	dropBox(state)
	dropTool(state)
	dropMark(state)
	dropSilhouette(state)
	local ctx = state.ctx
	local color = colorOf(ctx.Rarity)
	local top = Vector3.new(state.base.Position.X, ctx.ItemTop(), state.base.Position.Z)
	spawnFx(state, New.Fx.Reveal, CFrame.new(state.base.Position:Lerp(top, 0.5)), nil, color, true)
	flash(state, ctx.Rarity, true)
	state.tier = ctx.Rarity
	local rarityText = state.rarityLabel
	if rarityText then
		rarityText.Visible = false
	end
	local upgrade = state.upgradeLabel
	if upgrade then
		upgrade.Visible = false
	end
	local text = state.oddsLabel
	if text then
		text.Visible = true
	end
	state.oddsFrom = math.max(state.odds, 1)
	state.oddsTo = math.max(ctx.Plan.Odds, 1)
	state.oddsT = 0
	state.oddsTicks = 0
	state.finalLeft = New.FinalOddsHold
	state.phase = "After"
	state.t = 0
end

-- Une image. Rend un évènement au plus : « Burst » (le colis éclate), « Reveal » (montrer l'objet), « Done » (suite).
function Unbox.Step(state: State, dt: number): string?
	if state.destroyed then
		return nil
	end
	state.t += dt
	stepSounds(state, dt) -- vague 75 (L-261)
	state.spin += RevealConfig.Fallback.Spin * dt
	local phase = state.phase
	stepGrow(state) -- a536 (L-502)
	if phase == "Intro" then
		if state.t >= New.Intro then
			local first = state.moves[1]
			if first and first.Teleport then
				startGap(state, 1) -- vague 74 : une seule action, sur le colis : il s'y téléporte d'abord
			else
				startAction(state, 1)
			end
		end
	elseif phase == "Action" then
		stepAction(state, dt)
	elseif phase == "Gap" then
		if state.teleport then
			stepTeleport(state)
		end
		if state.t >= UnboxPlan.transition(state.teleport) then
			startAction(state, state.index + 1)
		end
	elseif phase == "Burst" then
		if state.t >= New.BurstHold then
			dropTool(state)
			state.phase = "Silhouettes"
			state.t = 0
			showSilhouette(state, 1)
		end
	elseif phase == "Silhouettes" then
		local last = state.silhouetteIndex >= state.silhouetteCount
		if last and state.t >= New.Suspense then
			local silhouette = state.silhouette
			if silhouette then
				blacken(silhouette, WHITE, Enum.Material.Neon)
				spawnFx(state, New.Fx.Overexpose, CFrame.new(state.base.Position:Lerp(silhouetteTop(state), 0.5)), nil, colorOf(state.ctx.Rarity), true)
			end
			state.phase = "Overexpose"
			state.t = 0
		elseif not last and state.t >= New.SilhouetteStep then
			state.t = 0
			showSilhouette(state, state.silhouetteIndex + 1)
		end
	elseif phase == "Overexpose" then
		if state.t >= New.Overexpose then
			table.insert(state.events, "Reveal")
			state.phase = "Wait" -- RevealController appelle OnReveal
			state.t = 0
		end
	elseif phase == "After" then
		if state.t >= New.AfterReveal then
			table.insert(state.events, "Done")
			state.phase = "Tail"
			state.t = 0
		end
	end
	local track = state.track
	if track and state.phase ~= "Action" and New.AnimEndFade > 0 then
		-- f70c4 : la dernière action continue après son coup (le colis éclate) ; elle s'arrête en fondu juste avant sa
		-- dernière image au lieu de s'y arrêter net (vitesse : ActionSpeed).
		local ok, left = pcall(function(): number
			return if track.IsPlaying and track.Length > 0 then (track.Length - track.TimePosition) / math.max(New.ActionSpeed, 0.1) else math.huge
		end)
		if ok and left <= New.AnimEndFade then
			stopTrack(state, math.max(left, 0))
		end
	end
	for inst, entry in state.muted do
		local target: any = inst
		if target[entry.property] ~= entry.off then
			target[entry.property] = entry.off
		end
	end
	stepPlaces(state, dt)
	poseBox(state, dt)
	poseTool(state)
	stepOdds(state, dt)
	stepJunk(state, dt)
	stepScreen(state, dt)
	local silhouette = state.silhouette
	if silhouette then
		local shake = Vector3.zero
		if state.phase == "Silhouettes" and state.silhouetteIndex >= state.silhouetteCount then
			local amplitude = New.SilhouetteShake * math.min(state.t / New.Suspense, 1)
			shake = Vector3.new((math.random() - 0.5) * 2 * amplitude, 0, (math.random() - 0.5) * 2 * amplitude)
		end
		-- La dernière (le vrai objet) ne tourne pas : elle est posée comme l'objet le sera à sa révélation.
		local angle = if state.silhouetteIndex >= state.silhouetteCount then 0 else state.spin
		pcall(function()
			silhouette:PivotTo((state.silhouetteHome + shake) * CFrame.Angles(0, angle, 0))
		end)
	end
	stepEnd(state, dt) -- a536 (L-504)
	if state.recoilLeft > 0 and state.ctx.Opener then
		local slice = math.min(dt, state.recoilLeft)
		state.recoilLeft -= slice
		local root = rootOf(state)
		if root then
			pcall(function()
				root.CFrame += state.side * (New.Recoil * slice / New.RecoilTime)
			end)
		end
	end
	if state.revealed then
		local board = state.board
		if board and state.finalLeft > 0 then
			state.finalLeft -= dt
			state.anchor.CFrame = CFrame.new(
				state.base.Position.X,
				state.ctx.ItemTop() + RevealConfig.BoardOffset + New.FinalOddsAbove - state.boardOffset,
				state.base.Position.Z
			)
			if state.finalLeft <= 0 then
				state.board = nil
				board:Destroy()
			end
		end
	end
	for index = #state.timed, 1, -1 do
		local timed = state.timed[index]
		timed.left -= dt
		if timed.left <= 0 then
			timed.inst:Destroy()
			table.remove(state.timed, index)
		end
	end
	return table.remove(state.events, 1)
end

-- f70c4 : ce qu'il reste à remettre de l'écran de l'ouvreur (champ de vision, bords), de leur valeur en ce moment à
-- celle d'avant la scène ; Unbox.ScreenFade le fait avancer (0 = en ce moment, 1 = remis). Le champ de vision n'est
-- plus touché dès qu'un autre code l'a changé (2e passe, Play de fusion71 : la poursuite de UiFeelController le
-- reprend à Land, le fondu l'écrasait ensuite d'un coup) : ce code décide.
export type ScreenFade = {
	fovFrom: number?,
	fovTo: number?,
	fovLast: number?, -- dernier champ de vision écrit ici (ou lu à Release)
	edgeFrom: number,
	glow: ImageLabel?,
	screen: ScreenGui?,
	wasEnabled: boolean,
}

-- e : bords et UI_Unbox ; eFov : champ de vision (e si absent).
function Unbox.ScreenFade(fade: ScreenFade, e: number, eFov: number?)
	local f = math.clamp(e, 0, 1)
	local camera = Workspace.CurrentCamera
	local from, to = fade.fovFrom, fade.fovTo
	local fading = false
	if camera and from and to then
		local last = fade.fovLast
		if last and math.abs(camera.FieldOfView - last) > 1e-3 then
			fade.fovFrom = nil -- un autre code a pris le champ de vision
		else
			camera.FieldOfView = from + (to - from) * math.clamp(eFov or e, 0, 1)
			fade.fovLast = camera.FieldOfView
			fading = math.clamp(eFov or e, 0, 1) < 1
		end
	end
	-- Vague 74 (a257, reste de f70c4) : tant que le champ de vision revient, sa valeur d'arrivée est publiée sur la
	-- caméra (FOV_BASE_ATTRIBUTE) : une poursuite qui démarre pendant ce retour (UiFeelController) la prend pour base,
	-- au lieu de la valeur en cours de fondu (1° trop bas).
	if camera then
		local value = if fading then to else nil
		pcall(function()
			if camera:GetAttribute(FOV_BASE_ATTRIBUTE) ~= value then
				camera:SetAttribute(FOV_BASE_ATTRIBUTE, value)
			end
		end)
	end
	local glow = fade.glow
	if glow then
		glow.ImageTransparency = 1 - fade.edgeFrom * (1 - f)
	end
	local screen = fade.screen
	if f >= 1 and screen then
		screen.Enabled = fade.wasEnabled
	end
end

-- L'ouvreur reprend la main (fin, mort, autre cinématique) : champ de vision et bords remis d'un coup ; soft (f70c4,
-- fin normale) : rien n'est remis ici, le fondu est rendu à RevealController, qui le fait avancer (Unbox.ScreenFade)
-- jusqu'à 1. La scène ne touche plus à l'écran ensuite (stepScreen), même détruite.
function Unbox.Release(state: State, soft: boolean?): ScreenFade?
	if state.released then
		return nil
	end
	state.released = true
	if not state.ctx.Opener then
		return nil
	end
	local camera = Workspace.CurrentCamera
	local fade: ScreenFade = {
		fovFrom = if camera then camera.FieldOfView else nil,
		fovTo = state.baseFov,
		fovLast = if camera then camera.FieldOfView else nil,
		edgeFrom = state.edge.value,
		glow = state.edgeLabel,
		screen = state.edgeScreen,
		wasEnabled = state.edgeWasEnabled,
	}
	if soft == true and not state.destroyed then
		return fade
	end
	Unbox.ScreenFade(fade, 1)
	return nil
end

function Unbox.Destroy(state: State)
	if state.destroyed then
		return
	end
	state.destroyed = true
	Unbox.Release(state)
	killSounds(state) -- vague 75 (L-261)
	showCharacter(state)
	stopTrack(state, 0.2)
	dropBox(state)
	dropTool(state)
	dropMark(state)
	dropSilhouette(state)
	for _, junk in state.junk do
		junk.model:Destroy()
	end
	table.clear(state.junk)
	for _, timed in state.timed do
		timed.inst:Destroy()
	end
	table.clear(state.timed)
	for _, inst in state.created do
		inst:Destroy()
	end
	table.clear(state.created)
	-- a421 : ce qui a été éteint sur le vrai colis est remis (ShelfBoxController reprend ensuite la main sur les siens).
	local added = state.shelfAdded
	if added then
		state.shelfAdded = nil
		added:Disconnect()
	end
	for inst, entry in state.muted do
		if inst.Parent ~= nil then
			(inst :: any)[entry.property] = entry.was
		end
	end
	table.clear(state.muted)
end

local function countOf(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- État pour un banc ou la barre de commande.
function Unbox.GetState(state: State): { [string]: any }
	local text = state.oddsLabel
	local rarityText = state.rarityLabel
	local upgrade = state.upgradeLabel
	return {
		Phase = state.phase,
		Index = state.index,
		Mode = state.mode,
		Impacts = state.impacts,
		Tier = state.tier,
		Odds = state.odds,
		OddsText = if text then text.Text else nil,
		OddsVisible = text ~= nil and text.Visible, -- a287
		LuckShown = state.luckShown, -- a462 (L-376)
		HitsShown = state.hitsShown, -- a523 (L-462)
		HitImpacts = state.hitImpacts,
		Gains = #state.gains,
		LuckTier = if state.tierStyle then state.tierStyle.index else nil, -- a523 (L-442)
		RarityText = if rarityText and rarityText.Visible then rarityText.Text else nil,
		Upgrade = upgrade ~= nil and upgrade.Visible,
		BoxScale = state.tierScale,
		Grown = state.grown, -- a536 (L-502)
		Box = state.box,
		Tool = state.tool,
		Mark = state.mark,
		Silhouette = state.silhouette,
		SilhouetteIndex = state.silhouetteIndex,
		Base = state.base,
		Stand = state.stand,
		Place = state.place,
		Moves = state.moves,
		Hidden = next(state.hiddenChar) ~= nil,
		CamLift = state.camLift,
		Slide = state.slide,
		Zoom = state.zoom.value,
		Edge = state.edge.value,
		SeeThrough = #state.seeThrough,
		Muted = countOf(state.muted), -- a421 : éteints sur le vrai colis
		Junk = #state.junk,
		Board = state.board,
	}
end

return Unbox
