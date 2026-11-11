--!strict
-- SkillTree/Fx (vague 27, L-096 point 2, client) : effets de l'écran UI_SkillTree, valeurs dans
-- Config/UiMotion (SkillTree, Shake ; tableau « Propres à l'arbre de compétences » de
-- docs/claude/notes/ui-motion-skilltree.md, T.18, T.54 à T.61). Module d'aide de SkillTreeController, rangé
-- dans un sous-dossier : le Loader ne le démarre pas.
--
-- Ce qui est touché, et rien d'autre :
--   - un UIScale UiMotion.SkillTree.ScaleName sur chaque tuile et sur SelectionGlow (Fx.scaleOf), créé à
--     l'ouverture et détruit à la fermeture (Fx.dropScale) ;
--   - Position de SelectionGlow (sous la tuile choisie) et ImageTransparency de ses images, remise à la valeur
--     de Clément à la fin de chaque effet ;
--   - Position d'un bouton qui refuse (Fx.shake), remise exactement à la fin ;
--   - des objets créés ici puis détruits : éclat (copie de Body), étincelles, badge NEW! (s'il n'y a pas de
--     NewBadge de Clément dans la tuile ; s'il y en a un, il est montré puis caché).
-- Animations par TweenService : un seul tween à la fois par objet et par propriété (le nouveau remplace
-- l'ancien), rien ne tourne quand rien ne bouge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiMotion"))

local M = UiMotion.SkillTree
local SHAKE = UiMotion.Shake
local OUT = Enum.EasingDirection.Out
local IN = Enum.EasingDirection.In
local QUAD = Enum.EasingStyle.Quad

-- V0 proposés, absents du doc (prototype tools/clement/skilltree_proto.luau, fonction badge) : place, taille,
-- inclinaison et couleurs du badge NEW! créé par le code ; nom du badge facultatif de Clément.
local BADGE_NAME = "NewBadge"
local BADGE_FX_NAME = "FxNewBadge"
local BADGE_POSITION = UDim2.fromScale(0.78, 0.14)
local BADGE_SIZE = UDim2.fromScale(0.46, 0.17)
local BADGE_ROTATION = 12
local BADGE_TEXT_COLOR = Color3.fromHex("1B1B24")
local BADGE_COLOR = Color3.fromHex("FFD23F")
local FX_ZINDEX = 30 -- étincelles et badge au-dessus des tuiles (prototype : 30 et 12)
local FLASH_NAME = "Flash"
local SPARK_NAME = "FxSpark"

local Fx = {}

-- Tween en cours, par objet et par propriété : un nouveau remplace l'ancien.
local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any
-- Fin du dernier effet d'achat ou de découverte, par tuile (os.clock) : le survol attend.
local busyUntil: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
-- Position d'origine d'un élément qui tremble, et jeton de la secousse en cours.
local shaking: { [Instance]: { base: UDim2, token: number } } = setmetatable({}, { __mode = "k" }) :: any
-- Contour de sélection : jeton du déplacement en cours, transparences d'origine de ses images.
local glowTokens: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local glowBase: { [Instance]: { [ImageLabel]: number } } = setmetatable({}, { __mode = "k" }) :: any
local random = Random.new()

-- Joue un tween de `goals` sur `object` après avoir arrêté ceux des mêmes propriétés.
function Fx.tween(object: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local current = running[object]
	if current == nil then
		current = {}
		running[object] = current
	end
	local slots = current :: { [string]: Tween }
	local tween = TweenService:Create(object, info, goals)
	for key in goals do
		local previous = slots[key]
		if previous then
			previous:Cancel()
		end
		slots[key] = tween
	end
	tween.Completed:Connect(function()
		for key in goals do
			if slots[key] == tween then
				slots[key] = nil
			end
		end
	end)
	tween:Play()
	return tween
end

-- Arrête le tween en cours de la propriété `key` de `object` (la valeur reste où elle en est).
function Fx.stop(object: Instance, key: string)
	local slots = running[object]
	local tween = if slots then slots[key] else nil
	if tween then
		tween:Cancel()
	end
end

local function info(time: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(time, style or QUAD, direction or OUT)
end

------------------------------------------------------------------------------
-- Échelle des tuiles et du contour
------------------------------------------------------------------------------

-- Le UIScale de l'effet sur `object` (créé à `initial` s'il manque).
function Fx.scaleOf(object: GuiObject, initial: number?): UIScale
	local found = object:FindFirstChild(M.ScaleName)
	if found and found:IsA("UIScale") then
		return found :: UIScale
	end
	local scale = Instance.new("UIScale")
	scale.Name = M.ScaleName
	scale.Scale = initial or 1
	scale.Parent = object
	return scale
end

-- Retire le UIScale de l'effet : l'objet retrouve sa taille de Studio.
function Fx.dropScale(object: GuiObject)
	local found = object:FindFirstChild(M.ScaleName)
	if found and found:IsA("UIScale") then
		running[found] = nil
		found:Destroy()
	end
	busyUntil[object] = nil
end

function Fx.isBusy(tile: GuiObject): boolean
	local untilTime = busyUntil[tile]
	return untilTime ~= nil and os.clock() < untilTime
end

local function setBusy(tile: GuiObject, seconds: number)
	busyUntil[tile] = math.max(busyUntil[tile] or 0, os.clock() + seconds)
end

-- Survol, appui, relâché d'une tuile (T.30 à T.32, échelles du prototype).
function Fx.hover(tile: GuiObject, over: boolean)
	if Fx.isBusy(tile) then
		return
	end
	Fx.tween(Fx.scaleOf(tile), info(UiMotion.Hover.Time), { Scale = if over then M.TileHover else 1 })
end

function Fx.press(tile: GuiObject)
	if Fx.isBusy(tile) then
		return
	end
	Fx.tween(Fx.scaleOf(tile), info(UiMotion.Press.Time), { Scale = M.TilePress })
end

function Fx.release(tile: GuiObject, over: boolean)
	if Fx.isBusy(tile) then
		return
	end
	local release = UiMotion.Release
	Fx.tween(Fx.scaleOf(tile), info(release.Time, release.Style, release.Direction), { Scale = if over then M.TileHover else 1 })
end

-- Ouverture « bop bop bop » (T.54) : `ordered` (de la tuile centrale vers les anneaux) passe à 0 tout de
-- suite, puis chacun à 1, PopGap s après le précédent ; `last` (SelectionGlow) arrive après la dernière.
function Fx.bop(ordered: { GuiObject }, last: GuiObject?)
	local popInfo = info(M.PopTime, M.PopStyle, OUT)
	local list = table.clone(ordered)
	if last then
		table.insert(list, last)
	end
	for index, object in list do
		local scale = Fx.scaleOf(object, 0)
		Fx.stop(scale, "Scale")
		scale.Scale = 0
		local delay = M.PopStart + (index - 1) * M.PopGap
		setBusy(object, delay + M.PopTime)
		task.delay(delay, function()
			if scale.Parent == object then
				Fx.tween(scale, popInfo, { Scale = 1 })
			end
		end)
	end
end

-- Fermeture (T.28) : tuiles et contour à 0 avec la fenêtre.
function Fx.shrink(objects: { GuiObject })
	local close = UiMotion.Close
	local closeInfo = info(close.Time, close.Style, close.Direction)
	for _, object in objects do
		busyUntil[object] = nil
		local found = object:FindFirstChild(M.ScaleName)
		if found and found:IsA("UIScale") then
			Fx.tween(found, closeInfo, { Scale = close.To })
		end
	end
end

------------------------------------------------------------------------------
-- Contour de sélection (T.55)
------------------------------------------------------------------------------

-- Les images de SelectionGlow et leur transparence posée par Clément (relevée une fois).
local function glowImages(glow: GuiObject): { [ImageLabel]: number }
	local known = glowBase[glow]
	if known then
		return known
	end
	local images: { [ImageLabel]: number } = {}
	for _, child in glow:GetDescendants() do
		if child:IsA("ImageLabel") then
			images[child :: ImageLabel] = (child :: ImageLabel).ImageTransparency
		end
	end
	glowBase[glow] = images
	return images
end

-- Remet le contour à sa transparence d'origine, sous `position`, sans animation (ouverture).
function Fx.placeGlow(glow: GuiObject, position: UDim2)
	glowTokens[glow] = (glowTokens[glow] or 0) + 1
	for image, base in glowImages(glow) do
		Fx.stop(image, "ImageTransparency")
		image.ImageTransparency = base
	end
	glow.Position = position
end

-- Le contour s'efface, se pose sous `position`, puis apparaît en douceur ; la tuile ne bouge pas.
function Fx.moveGlow(glow: GuiObject, position: UDim2)
	local token = (glowTokens[glow] or 0) + 1
	glowTokens[glow] = token
	local images = glowImages(glow)
	for image in images do
		Fx.tween(image, info(M.SelectOut), { ImageTransparency = 1 })
	end
	task.delay(M.SelectOut, function()
		if glowTokens[glow] ~= token or glow.Parent == nil then
			return
		end
		glow.Position = position
		local scale = Fx.scaleOf(glow)
		scale.Scale = M.SelectFrom
		Fx.tween(scale, info(M.SelectIn), { Scale = 1 })
		for image, base in images do
			Fx.tween(image, info(M.SelectIn), { ImageTransparency = base })
		end
	end)
end

------------------------------------------------------------------------------
-- Achat (T.57 à T.61)
------------------------------------------------------------------------------

-- Éclat (T.59) : copie blanche de `body` posée au-dessus de son calque, qui s'efface puis disparaît.
function Fx.flash(body: GuiObject)
	if not body:IsA("ImageLabel") or body.Parent == nil then
		return
	end
	local top = 0
	for _, sibling in (body.Parent :: Instance):GetChildren() do
		if sibling:IsA("GuiObject") then
			top = math.max(top, (sibling :: GuiObject).ZIndex)
		end
	end
	local copy = body:Clone() :: ImageLabel
	copy.Name = FLASH_NAME
	copy.ImageColor3 = Color3.new(1, 1, 1)
	copy.ImageTransparency = 0
	copy.ZIndex = top + 1
	copy.Parent = body.Parent
	Fx.tween(copy, info(M.FlashTime), { ImageTransparency = 1 })
	task.delay(M.FlashTime, function()
		copy:Destroy()
	end)
end

-- Étincelles (T.60) autour du centre de `tile`, posées dans `tree` (elles suivent le zoom). `width` = largeur
-- de la tuile en px avant le zoom (les décalages de Tree sont ceux d'avant son UIScale).
function Fx.sparks(tree: GuiObject, tile: GuiObject, width: number)
	if width <= 0 then
		return
	end
	local anchor = tile.AnchorPoint
	local height = width * (if tile.AbsoluteSize.X > 0 then tile.AbsoluteSize.Y / tile.AbsoluteSize.X else 1)
	local center = tile.Position + UDim2.fromOffset((0.5 - anchor.X) * width, (0.5 - anchor.Y) * height)
	local side = width * M.SparkSize
	for index = 1, M.SparkCount do
		local spark = Instance.new("Frame")
		spark.Name = SPARK_NAME
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BorderSizePixel = 0
		spark.ZIndex = FX_ZINDEX
		spark.BackgroundColor3 = if index % 3 == 0 then M.SparkWhite else M.SparkGold
		spark.Size = UDim2.fromOffset(side, side)
		spark.Rotation = 45
		spark.Position = center
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = M.SparkStroke
		stroke.Parent = spark
		spark.Parent = tree
		local angle = (index / M.SparkCount) * math.pi * 2 + random:NextNumber() * 0.3
		local distance = width * M.SparkDistance * (1 + (random:NextNumber() * 2 - 1) * M.SparkSpread)
		local goal = center + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance)
		Fx.tween(spark, info(M.SparkTime), { Position = goal, Rotation = 45 + 180, BackgroundTransparency = 1 })
		Fx.tween(stroke, info(M.SparkTime), { Transparency = 1 })
		task.delay(M.SparkTime, function()
			spark:Destroy()
		end)
	end
end

-- Achat (T.57 et T.58) : la tuile gonfle, puis revient avec un rebond élastique.
function Fx.punch(tile: GuiObject)
	setBusy(tile, M.PunchTime + M.SettleTime)
	local scale = Fx.scaleOf(tile)
	Fx.tween(scale, info(M.PunchTime), { Scale = M.PunchTo })
	task.delay(M.PunchTime, function()
		if scale.Parent == tile then
			Fx.tween(scale, info(M.SettleTime, M.SettleStyle, OUT), { Scale = 1 })
		end
	end)
end

-- Badge NEW! (T.61) : celui de Clément s'il existe (NewBadge, caché), sinon un badge créé ici.
function Fx.badge(tile: GuiObject, font: Font?)
	local own = tile:FindFirstChild(BADGE_NAME)
	local badge: GuiObject
	local created = false
	if own and own:IsA("GuiObject") then
		badge = own :: GuiObject
	else
		local label = Instance.new("TextLabel")
		label.Name = BADGE_FX_NAME
		label.Text = M.BadgeText
		label.TextScaled = true
		if font then
			label.FontFace = font
		end
		label.TextColor3 = BADGE_TEXT_COLOR
		label.BackgroundColor3 = BADGE_COLOR
		label.BorderSizePixel = 0
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = BADGE_POSITION
		label.Size = BADGE_SIZE
		label.Rotation = BADGE_ROTATION
		label.ZIndex = FX_ZINDEX
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = tile
		badge = label
		created = true
	end
	local scale = Fx.scaleOf(badge, 0)
	scale.Scale = 0
	badge.Visible = true
	Fx.tween(scale, info(M.BadgeIn, Enum.EasingStyle.Back, OUT), { Scale = 1 })
	task.delay(M.BadgeIn + M.BadgeHold, function()
		if badge.Parent == nil then
			return
		end
		Fx.tween(scale, info(M.BadgeOut, QUAD, IN), { Scale = 0 })
		task.delay(M.BadgeOut, function()
			if created then
				badge:Destroy()
			elseif badge.Parent then
				badge.Visible = false
				Fx.dropScale(badge)
			end
		end)
	end)
end

-- Tuile voisine qui se découvre (T.61) : après RevealDelay, elle se retourne (1 → 0), `uncover()` change son
-- calque (Locked → Available), puis elle revient avec un pop, des étincelles et le badge NEW!.
function Fx.reveal(tree: GuiObject, tile: GuiObject, width: number, font: Font?, uncover: () -> ())
	setBusy(tile, M.RevealDelay + M.RevealShrink + M.RevealPop)
	task.delay(M.RevealDelay, function()
		if tile.Parent == nil then
			uncover()
			return
		end
		local scale = Fx.scaleOf(tile)
		Fx.tween(scale, info(M.RevealShrink, QUAD, IN), { Scale = 0 })
		task.delay(M.RevealShrink, function()
			uncover()
			if scale.Parent ~= tile then
				return
			end
			Fx.tween(scale, info(M.RevealPop, Enum.EasingStyle.Back, OUT), { Scale = 1 })
			Fx.sparks(tree, tile, width)
			Fx.badge(tile, font)
		end)
	end)
end

------------------------------------------------------------------------------
-- Refus (T.18)
------------------------------------------------------------------------------

-- L'élément tremble de ±Amplitude px, Count allers-retours en Time s, puis revient à sa Position exacte.
function Fx.shake(object: GuiObject)
	local state = shaking[object]
	local base = if state then state.base else object.Position
	local token = (if state then state.token else 0) + 1
	shaking[object] = { base = base, token = token }
	local step = SHAKE.Time / SHAKE.Count
	local stepInfo = info(step / 2, SHAKE.Style, SHAKE.Direction)
	for index = 1, SHAKE.Count do
		task.delay((index - 1) * step, function()
			local current = shaking[object]
			if current and current.token == token then
				local side = if index % 2 == 1 then SHAKE.Amplitude else -SHAKE.Amplitude
				Fx.tween(object, stepInfo, { Position = base + UDim2.fromOffset(side, 0) })
			end
		end)
	end
	task.delay(SHAKE.Time, function()
		local current = shaking[object]
		if current == nil or current.token ~= token then
			return
		end
		local tween = Fx.tween(object, stepInfo, { Position = base })
		tween.Completed:Connect(function()
			local last = shaking[object]
			if last and last.token == token then
				shaking[object] = nil
				object.Position = base
			end
		end)
	end)
end

-- Position d'origine d'un élément en train de trembler (sinon sa Position) : pour un test.
function Fx.basePosition(object: GuiObject): UDim2
	local state = shaking[object]
	return if state then state.base else object.Position
end

return Fx
