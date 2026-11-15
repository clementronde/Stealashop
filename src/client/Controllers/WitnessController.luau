--!strict
-- WitnessController (client, liaison L-111) : la bulle des témoins, BB_Witness de Clément (« ? » qui se
-- remplit, puis « ! » pendant l'appel). Animations d'UI T.50 à T.52 de
-- docs/claude/notes/ui-motion-skilltree.md ; valeurs : Config/Witness.
--
-- Le serveur décide de tout (WitnessService) et n'écrit que quatre attributs sur chaque témoin (tag et
-- attributs : Shared/WitnessGauge). Ici, à chaque image et seulement pour les témoins qui ne se baladent
-- pas : une copie de ReplicatedStorage/Assets/UI/BB_Witness, rangée dans le PlayerGui, accrochée à
-- l'Attachment WitnessHead du témoin (sinon sa Head, sinon son HumanoidRootPart). La copie est créée quand
-- le témoin se met à regarder et détruite quand il reprend sa balade.
--   - « ? » (T.50 WitnessFill) : Mark visible, Alert caché ; Mark.Fill.Size Y = le remplissage (0 à 1, du
--     bas vers le haut) ; Fill.FillMark.TextColor3 jaune, orange dès 50 %, rouge dès 80 % ; à chaque
--     changement de couleur, Mark saute de 1,1 à 1 en 0,15 s (Back Out). Si Clément a taillé FillMark en
--     Scale dans Fill, sa hauteur est compensée (÷ le remplissage) pour que le « ? » ne s'écrase pas.
--   - « ! » (T.51 WitnessAlert) : Mark caché, Alert visible : 0 → 1,3 en 0,12 s (Back Out), puis 1 en
--     0,1 s (Quad Out) ; tremblement de ± 8°, 4 allers-retours en 0,3 s.
--   - pendant l'appel (T.52 WitnessCall) : Alert bat de 1 à 1,12 deux fois par seconde ; Alert.PhoneIcon
--     sonne (± 12° autour de −12°, 6 fois par seconde), jusqu'à la fin de l'appel.
-- Les effets d'échelle passent par un UIScale Witness.Motion.ScaleName créé sur Mark et Alert de la copie ;
-- un cadre qui a déjà un UIScale de Clément n'est pas mis à l'échelle. Rien n'est changé dans le gabarit
-- de Clément, rien n'est envoyé au serveur. BB_Witness absent : pas de bulle (une ligne en Studio).
--
-- Flash des photos (L-172, Clément : « le flash part du téléphone ») : à chaque hausse de l'attribut WitnessFlash
-- d'un témoin (écrit par WitnessService). Une fois par témoin, les enfants de l'Attachment Flash de
-- ReplicatedStorage/Assets/FX/FX_Witness_Flash (PointLight Light, ParticleEmitter Glare, Glint, Specks) sont copiés,
-- chez ce joueur seulement, dans l'Attachment FlashPoint du Handle de ACC_Temoin_Telephone : le flash suit le
-- téléphone pendant TakePhoto. À chaque flash : Emit(EmitCount) de chaque ParticleEmitter, Light allumée
-- LightTime s ; jamais deux à moins de Duration s. La Part Root du modèle ne sert pas. Sans FlashPoint : un
-- Attachment du code dans le Handle, posé Photo.Forward stud devant le témoin ; sans téléphone : à la
-- RightHand. FX_Witness_Flash ou son Attachment Flash absent : pas de flash (une ligne en Studio).
--
-- API (client, pour un test dans Studio) :
--   WitnessController.GetState() -> { { Witness, State, Fill, Bubble } }
--   WitnessController.GetFlashes() -> (flashs joués, témoins équipés du flash)   L-172

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Witness = require(Shared:WaitForChild("Config"):WaitForChild("Witness"))
local WitnessGauge = require(Shared:WaitForChild("WitnessGauge"))

export type State = {
	Witness: Model,
	State: string, -- "Stroll", "Watch" ou "Call" (WitnessGauge.State)
	Fill: number,
	Bubble: BillboardGui?,
}

-- La copie de BB_Witness d'un témoin et ce que le code y règle.
type Bubble = {
	gui: BillboardGui,
	mark: GuiObject?,
	fill: GuiObject?,
	fillMark: GuiObject?,
	fillMarkSize: UDim2?, -- taille d'origine de FillMark (compensée s'il est taillé en Scale)
	alert: GuiObject?,
	alertRotation: number,
	phone: GuiObject?,
	phoneRotation: number,
	markScale: UIScale?,
	alertScale: UIScale?,
	stage: number, -- rang de la couleur affichée ; 0 = pas encore
	popAt: number, -- début du saut de Mark (os.clock) ; 0 = aucun
}

-- Les copies du flash dans le téléphone d'un témoin (L-172).
type FlashRig = {
	point: Attachment, -- FlashPoint de Clément, ou l'Attachment du code
	moved: boolean, -- Attachment du code au Handle : replacé devant le témoin à chaque flash
	made: { Instance }, -- ce que le code a créé (détruit avec le témoin)
	light: Light?,
	emitters: { ParticleEmitter },
	lastAt: number, -- os.clock du dernier flash
}

local MOTION = Witness.Motion
local PHOTO = Witness.Photo
local IS_STUDIO = RunService:IsStudio()

local WitnessController = {}

local localPlayer = Players.LocalPlayer
local tracked: { [Model]: boolean } = {} -- témoins présents chez ce joueur (tag WitnessGauge.Tag)
local bubbles: { [Model]: Bubble } = {}
local said: { [string]: boolean } = {}
local flashLinks: { [Model]: RBXScriptConnection } = {} -- L-172 : écoute de WitnessFlash
local flashRigs: { [Model]: FlashRig } = {}
local flashTotal = 0 -- flashs joués (pour un test)

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[Witness] {message}`)
	end
end

local function ease(alpha: number, style: Enum.EasingStyle): number
	return TweenService:GetValue(math.clamp(alpha, 0, 1), style, Enum.EasingDirection.Out)
end

local function guiChild(parent: Instance?, name: string): GuiObject?
	local found = if parent then parent:FindFirstChild(name, true) else nil
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function template(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in Witness.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(Witness.Billboard) else nil
	if found and found:IsA("BillboardGui") then
		return found :: BillboardGui
	end
	sayOnce("template", `{Witness.Billboard} absent de ReplicatedStorage.Assets.UI : pas de bulle sur les témoins (L-111)`)
	return nil
end

-- Où accrocher la bulle : l'Attachment WitnessHead, sinon la Head, sinon le HumanoidRootPart.
local function adorneeOf(model: Model): Instance?
	local head = model:FindFirstChild(Witness.HeadAttachment, true)
	if head and head:IsA("Attachment") then
		return head
	end
	for _, name in { "Head", "HumanoidRootPart" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- UIScale du code sur ce cadre de la copie ; nil si Clément y a déjà posé le sien (on n'y touche pas).
local function scaleFor(object: GuiObject?): UIScale?
	if object == nil or object:FindFirstChildOfClass("UIScale") then
		return nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = MOTION.ScaleName
	scale.Parent = object
	return scale
end

local function destroyBubble(model: Model)
	local bubble = bubbles[model]
	if bubble then
		bubbles[model] = nil
		bubble.gui:Destroy()
	end
end

local function createBubble(model: Model): Bubble?
	local source = template()
	local adornee = adorneeOf(model)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if source == nil or adornee == nil or playerGui == nil then
		return nil
	end
	local gui = source:Clone()
	local mark = guiChild(gui, "Mark")
	local fill = guiChild(mark, "Fill")
	local fillMark = guiChild(fill, "FillMark")
	local alert = guiChild(gui, "Alert")
	local phone = guiChild(alert, "PhoneIcon")
	if mark == nil or fill == nil or alert == nil then
		sayOnce("parts", `{Witness.Billboard} : Mark, Mark.Fill ou Alert introuvable (L-111)`)
	end
	local bubble: Bubble = {
		gui = gui,
		mark = mark,
		fill = fill,
		fillMark = fillMark,
		fillMarkSize = if fillMark then fillMark.Size else nil,
		alert = alert,
		alertRotation = if alert then alert.Rotation else 0,
		phone = phone,
		phoneRotation = if phone then phone.Rotation else 0,
		markScale = scaleFor(mark),
		alertScale = scaleFor(alert),
		stage = 0,
		popAt = 0,
	}
	gui.Adornee = adornee
	gui.Enabled = true
	gui.Parent = playerGui
	bubbles[model] = bubble
	return bubble
end

-- « ? » : remplissage, couleur, saut au changement de couleur (T.50).
local function showMark(bubble: Bubble, value: number, clock: number)
	local mark, fill, fillMark, alert = bubble.mark, bubble.fill, bubble.fillMark, bubble.alert
	if alert then
		alert.Visible = false
	end
	if mark then
		mark.Visible = true
	end
	if fill then
		local size = fill.Size
		fill.Size = UDim2.new(size.X.Scale, size.X.Offset, value, 0)
	end
	local base = bubble.fillMarkSize
	if fillMark and base and base.Y.Scale ~= 0 then
		-- Taillé en Scale dans Fill : sa hauteur suivrait celle de Fill, on la compense.
		fillMark.Size = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale / math.max(value, 0.01), base.Y.Offset)
	end
	local stage = WitnessGauge.stage(value)
	if stage ~= bubble.stage then
		if bubble.stage ~= 0 then
			bubble.popAt = clock
		end
		bubble.stage = stage
		if fillMark and (fillMark:IsA("TextLabel") or fillMark:IsA("TextButton")) then
			(fillMark :: TextLabel).TextColor3 = Witness.Colors[stage].Color
		end
	end
	local markScale = bubble.markScale
	if markScale then
		local elapsed = if bubble.popAt > 0 then clock - bubble.popAt else MOTION.StagePopTime
		if elapsed >= MOTION.StagePopTime then
			bubble.popAt = 0
			markScale.Scale = 1
		else
			local alpha = ease(elapsed / MOTION.StagePopTime, Enum.EasingStyle.Back)
			markScale.Scale = MOTION.StagePopFrom + (1 - MOTION.StagePopFrom) * alpha
		end
	end
end

-- « ! » : entrée, tremblement (T.51), puis battement et téléphone qui sonne (T.52). `elapsed` = temps
-- depuis le début de l'appel.
local function showAlert(bubble: Bubble, elapsed: number)
	local mark, alert, phone = bubble.mark, bubble.alert, bubble.phone
	if mark then
		mark.Visible = false
	end
	if alert == nil then
		return
	end
	alert.Visible = true
	local scale: number
	local settleAt = MOTION.AlertPopTime + MOTION.AlertSettleTime
	if elapsed < MOTION.AlertPopTime then
		scale = MOTION.AlertPopTo * ease(elapsed / MOTION.AlertPopTime, Enum.EasingStyle.Back)
	elseif elapsed < settleAt then
		local alpha = ease((elapsed - MOTION.AlertPopTime) / MOTION.AlertSettleTime, Enum.EasingStyle.Quad)
		scale = MOTION.AlertPopTo + (1 - MOTION.AlertPopTo) * alpha
	else
		local phase = (elapsed - settleAt) * MOTION.CallPulseRate * 2 * math.pi
		scale = 1 + (MOTION.CallPulseTo - 1) * (0.5 - 0.5 * math.cos(phase))
	end
	local alertScale = bubble.alertScale
	if alertScale then
		alertScale.Scale = scale
	end
	local shake = 0
	if elapsed < MOTION.AlertShakeTime then
		shake = MOTION.AlertShakeAngle * math.sin(elapsed / MOTION.AlertShakeTime * MOTION.AlertShakeCount * 2 * math.pi)
	end
	alert.Rotation = bubble.alertRotation + shake
	if phone then
		phone.Rotation = bubble.phoneRotation + MOTION.PhoneAngle + MOTION.PhoneSwing * math.sin(elapsed * MOTION.PhoneRate * 2 * math.pi)
	end
end

local function update()
	if next(tracked) == nil then
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	local clock = os.clock()
	for model in tracked do
		local state, value = WitnessGauge.read(model, serverNow)
		local bubble: Bubble? = bubbles[model]
		if state == "Stroll" or not model:IsDescendantOf(Workspace) then
			if bubble then
				destroyBubble(model)
			end
			continue
		end
		if bubble then
			local adornee: Instance? = bubble.gui.Adornee
			if bubble.gui.Parent == nil or not (adornee and adornee:IsDescendantOf(Workspace)) then
				destroyBubble(model) -- PlayerGui remis à neuf, ou tête partie (streaming) : une copie neuve
				bubble = nil
			end
		end
		local current = bubble or createBubble(model)
		if current == nil then
			continue
		end
		if state == "Call" then
			local at = model:GetAttribute(WitnessGauge.AtAttribute)
			showAlert(current, if type(at) == "number" then math.max(serverNow - at, 0) else 0)
		else
			showMark(current, value, clock)
		end
	end
end

-- Flash des photos (L-172) -----------------------------------------------------------------------

local function positiveAttribute(inst: Instance, name: string, default: number): number
	local value = inst:GetAttribute(name)
	if type(value) == "number" and value == value and value > 0 and value < math.huge then
		return value
	end
	return default
end

-- Le modèle FX_Witness_Flash de Clément et son Attachment Flash (sa Part Root ne sert pas au code).
local function flashTemplate(): (Model?, Attachment?)
	local current: Instance? = ReplicatedStorage
	for _, segment in PHOTO.FxFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(PHOTO.Fx) else nil
	if found == nil or not found:IsA("Model") then
		sayOnce("flash", `{PHOTO.Fx} absent de ReplicatedStorage.Assets.FX : pas de flash sur les photos des témoins (L-172)`)
		return nil, nil
	end
	local source = found:FindFirstChild(PHOTO.FxSource, true)
	if source == nil or not source:IsA("Attachment") then
		sayOnce("flashSource", `{PHOTO.Fx} : Attachment {PHOTO.FxSource} introuvable (L-172)`)
		return found :: Model, nil
	end
	return found :: Model, source :: Attachment
end

-- Où part le flash : l'Attachment FlashPoint du Handle de ACC_Temoin_Telephone (Clément) ; sinon un Attachment
-- du code, posé à chaque flash Photo.Forward stud devant le témoin au Handle, ou à la RightHand. `moved` : un
-- Attachment du code, à replacer à chaque flash.
local function flashPoint(model: Model): (Attachment?, boolean)
	local phone = model:FindFirstChild(PHOTO.Phone, true)
	local handle = if phone then phone:FindFirstChild(PHOTO.PhonePart) else nil
	if handle and handle:IsA("BasePart") then
		local point = handle:FindFirstChild(PHOTO.PhonePoint)
		if point and point:IsA("Attachment") then
			return point :: Attachment, false
		end
	else
		local hand = model:FindFirstChild(PHOTO.Hand, true)
		handle = if hand and hand:IsA("BasePart") then hand else nil
	end
	if handle == nil then
		return nil, false
	end
	local made = handle:FindFirstChild(PHOTO.CodePoint)
	if made == nil or not made:IsA("Attachment") then
		local created = Instance.new("Attachment")
		created.Name = PHOTO.CodePoint
		created.Parent = handle
		made = created
	end
	return made :: Attachment, handle.Name == PHOTO.PhonePart
end

local function destroyFlash(model: Model)
	local rig = flashRigs[model]
	if rig then
		flashRigs[model] = nil
		for _, inst in rig.made do
			inst:Destroy()
		end
	end
end

-- Les copies des enfants de Flash dans le point du témoin, faites une fois (refaites si le téléphone a changé).
local function rigOf(model: Model, source: Attachment): FlashRig?
	local point, moved = flashPoint(model)
	if point == nil then
		sayOnce(`flashPoint:{model.Name}`, `{model.Name} : ni {PHOTO.Phone}.{PHOTO.PhonePart} ni {PHOTO.Hand} : pas de flash (L-172)`)
		return nil
	end
	local rig = flashRigs[model]
	if rig and rig.point == point and point.Parent ~= nil then
		return rig
	end
	destroyFlash(model)
	local made: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	local light: Light? = nil
	for _, child in source:GetChildren() do
		local copy = child:Clone()
		if copy:IsA("ParticleEmitter") then
			table.insert(emitters, copy :: ParticleEmitter)
		elseif light == nil and copy:IsA("Light") then
			light = copy :: Light
			(copy :: Light).Enabled = false
		end
		copy.Parent = point
		table.insert(made, copy)
	end
	if point.Name == PHOTO.CodePoint then
		table.insert(made, point) -- l'Attachment du code part avec les copies
	end
	local fresh: FlashRig = { point = point, moved = moved, light = light, emitters = emitters, made = made, lastAt = -math.huge }
	flashRigs[model] = fresh
	return fresh
end

-- Un flash du témoin `model` (pas deux à moins de Duration s).
local function playFlash(model: Model)
	local template, source = flashTemplate()
	if template == nil or source == nil then
		return
	end
	local rig = rigOf(model, source)
	if rig == nil then
		return
	end
	local now = os.clock()
	if now - rig.lastAt < positiveAttribute(template, "Duration", 0.5) then
		return
	end
	if rig.moved then
		-- Pas de FlashPoint : Photo.Forward stud devant le témoin, au Handle.
		local rootInst = model:FindFirstChild("HumanoidRootPart")
		local parent = rig.point.Parent
		if rootInst and rootInst:IsA("BasePart") and parent and parent:IsA("BasePart") then
			rig.point.WorldPosition = (parent :: BasePart).Position + (rootInst :: BasePart).CFrame.LookVector * PHOTO.Forward
		end
	end
	for _, emitter in rig.emitters do
		emitter:Emit(math.max(math.floor(positiveAttribute(emitter, "EmitCount", 1)), 1))
	end
	rig.lastAt = now
	flashTotal += 1
	local light = rig.light
	if light then
		light.Enabled = true
		task.delay(positiveAttribute(template, "LightTime", 0.1), function()
			if rig.lastAt == now then
				light.Enabled = false
			end
		end)
	end
end

local function track(inst: Instance)
	if inst:IsA("Model") then
		local model = inst :: Model
		tracked[model] = true
		if not flashLinks[model] then
			flashLinks[model] = model:GetAttributeChangedSignal(WitnessGauge.FlashAttribute):Connect(function()
				playFlash(model)
			end)
		end
	end
end

-- Témoin retiré du jeu (streaming) : sa bulle part avec lui.
local function untrack(inst: Instance)
	if inst:IsA("Model") then
		local model = inst :: Model
		tracked[model] = nil
		destroyBubble(model)
		local link = flashLinks[model]
		if link then
			flashLinks[model] = nil
			link:Disconnect()
		end
		destroyFlash(model)
	end
end

function WitnessController.GetState(): { State }
	local list: { State } = {}
	local serverNow = Workspace:GetServerTimeNow()
	for model in tracked do
		local state, value = WitnessGauge.read(model, serverNow)
		local bubble: Bubble? = bubbles[model]
		local gui: BillboardGui? = if bubble then bubble.gui else nil
		table.insert(list, { Witness = model, State = state, Fill = value, Bubble = gui })
	end
	return list
end

-- L-172 : flashs joués chez ce joueur depuis le début, et témoins équipés du flash.
function WitnessController.GetFlashes(): (number, number)
	local copies = 0
	for _ in flashRigs do
		copies += 1
	end
	return flashTotal, copies
end

function WitnessController.Start()
	CollectionService:GetInstanceAddedSignal(WitnessGauge.Tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(WitnessGauge.Tag):Connect(untrack)
	for _, inst in CollectionService:GetTagged(WitnessGauge.Tag) do
		track(inst)
	end
	RunService.Heartbeat:Connect(update)
end

return WitnessController
