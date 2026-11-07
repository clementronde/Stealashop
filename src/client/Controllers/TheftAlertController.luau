--!strict
-- TheftAlertController (DEV-042, client) : l'alerte de la victime d'un vol entre joueurs (Partie 1,
-- section 6.2, usage 1 : « bannière rouge plein écran, sirène, flèche permanente vers le voleur,
-- voleur surligné à travers les murs » ; contrat UI 2.2 : `UI_TheftAlert` avec `Banner`, `ThiefName`,
-- `ItemName` et `Arrow`, une ImageLabel). Le serveur décide tout : PvPService envoie TheftAlert(true,
-- voleur, itemId) quand un joueur prend un objet exposé dans la boutique du joueur local, et
-- TheftAlert(false) à la fin du vol (dépôt ou échec) ; s'il reste d'autres vols chez lui,
-- TheftAlertService les réannonce aussitôt (true, …). Ce contrôleur affiche et n'envoie rien.
--
-- Pendant un vol (s'il y en a plusieurs : le dernier annoncé est affiché, les MAX_HIGHLIGHTS plus
-- récents sont surlignés) :
--   - bannière : écran de Clément s'il est livré, PlayerGui/UI_TheftAlert (copié depuis StarterGui) :
--     ThiefName = pseudo du voleur, ItemName = nom de l'objet, tous deux en capitales (la bannière
--     crie, 6.2). Seuls Enabled de l'écran, ces deux textes, Visible de Banner, ThiefName, ItemName et
--     Arrow, et Arrow.Rotation sont touchés (2.2, « Libre pour Ironix ») ; une nouvelle copie de
--     l'écran (ResetOnSpawn) est reprise dans les REFRESH_INTERVAL s. Sinon un repli V0 fait par le
--     code, TheftAlertV0 dans le PlayerGui, clairement provisoire et sans style : un voile rouge sur
--     tout l'écran qui pulse et un bandeau rouge au tiers de la hauteur (rien d'important en haut,
--     2.2) : « BOB IS STEALING YOUR SODA CAN! » puis « HIT THEM! ». Détruit dès que UI_TheftAlert
--     arrive ;
--   - sirène : copie du Sound PvP.AlertSirenSound, cherché dans le dossier des sons
--     (MarkerSounds.Folder, DEV-051), jouée en 2D (SoundService) au début de l'alerte et arrêtée à
--     la fin ; boucle ou non au choix de Clément (Looped). Pas encore livrée : alerte muette, une
--     ligne dans la sortie (Studio, une fois) ;
--   - flèche permanente vers le voleur : Arrow de Clément, tournée à chaque image comme une boussole
--     vue de la caméra, à l'horizontale : 0° = droit devant (haut de l'écran), 90° = à droite,
--     180° = derrière. L'image pointe vers le haut : la Rotation posée par Clément sert de départ (une
--     image qui pointe ailleurs se corrige ainsi). Sans Arrow : un Beam V0 rouge au sol, des pieds du
--     joueur à ceux du voleur, qui s'affine vers lui (comme la flèche du tuto), dans un dossier
--     TheftAlertArrow de la caméra. Cachée tant que le personnage du voleur n'est pas là (streaming) ;
--   - voleur surligné à travers les murs : un Highlight AlwaysOnTop dans son personnage, créé par ce
--     client (vu de lui seul), pour MAX_HIGHLIGHTS voleurs au plus. Roblox n'affiche que 31 Highlight
--     à la fois (ShelfBoxController en garde 25 pour les colis, la marge de 6 sert aux autres) : le
--     voleur porte déjà le contour rouge StolenOutline de CarryService (sur l'objet volé, vu de tous) ;
--     ce client le coupe tant que sa surbrillance est là (elle couvre tout le personnage, objet
--     compris) et le rallume après. Le nombre de Highlight affichés ne bouge donc pas.
-- Tout disparaît à TheftAlert(false), à la mort ou au départ du voleur (vérifiés à chaque image). Les
-- messages sont appliqués à l'image suivante : un false suivi d'une réannonce ne fait ni clignoter la
-- bannière ni repartir la sirène.
-- La batte s'équipe toute seule à l'alerte (6.2) : c'est BatController (PvP.AutoEquipBatOnAlert).
--
-- API (client) :
--   TheftAlertController.GetState() -> { Active, Thefts, Thief, ItemId, ThiefName, ItemName,
--       Headline, Fallback, Arrow, ArrowRotation, Beam, Highlights, Siren }
--       Ce qui est affiché, pour un test dans Studio (barre de commande côté client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local PvP = require(Config:WaitForChild("PvP"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))

-- Un vol en cours chez le joueur local, tel qu'annoncé par le serveur.
type Theft = {
	Thief: Player,
	ItemId: string,
}

type View = {
	gui: ScreenGui,
	banner: GuiObject?,
	thiefName: GuiObject?, -- TextLabel ou TextButton
	itemName: GuiObject?,
	arrow: GuiObject?, -- ImageLabel au contrat : seules sa Rotation et sa visibilité changent
	headline: TextLabel?, -- repli V0 seulement : la phrase entière
	veil: Frame?, -- repli V0 seulement : le voile rouge qui pulse
	fallback: boolean,
}

type ArrowV0 = {
	folder: Folder,
	from: Attachment,
	to: Attachment,
	beam: Beam,
}

type Glow = {
	highlight: Highlight,
	character: Model,
	outline: Highlight?, -- StolenOutline de CarryService trouvé dans le personnage
	outlineOff: boolean, -- coupé par ce client (à rallumer)
}

-- Écran de Clément et ses éléments (contrat 2.2).
local SCREEN_NAME = "UI_TheftAlert"
local BANNER = "Banner"
local THIEF_NAME = "ThiefName"
local ITEM_NAME = "ItemName"
local ARROW = "Arrow"
-- Posé par CarryService sur l'objet volé (même nom là-bas).
local STOLEN_OUTLINE = "StolenOutline"

-- Textes lus par le joueur, en anglais (L-036), en capitales : la bannière crie (6.2).
local HEADLINE = "%s IS STEALING YOUR %s!"
local ACTION_TEXT = "HIT THEM!"
local UNKNOWN_ITEM = "item"

-- V0 proposés, absents du doc :
local FALLBACK_NAME = "TheftAlertV0" -- écran de repli, fait par le code tant que UI_TheftAlert manque
local HIGHLIGHT_NAME = "TheftAlertHighlight"
local ARROW_FOLDER = "TheftAlertArrow"
local SIREN_NAME = "TheftAlertSiren"
local DISPLAY_ORDER = 20 -- au-dessus du HUD et des autres écrans
local ALERT_RED = Color3.fromHex("#E8413C") -- rouge « fermer » de la planche 10.6, celui de StolenOutline
local TEXT_COLOR = Color3.new(1, 1, 1)
local BANNER_Y = 0.3 -- centre du bandeau, en part de la hauteur de l'écran
local BANNER_HEIGHT = 0.16
local VEIL_TRANSPARENCY = 0.85 -- voile rouge plein écran : transparence moyenne, ± VEIL_PULSE
local VEIL_PULSE = 0.07
local VEIL_PERIOD = 0.7 -- s
local MAX_HIGHLIGHTS = 3 -- voleurs surlignés à la fois au plus (les plus récents)
local HIGHLIGHT_FILL_TRANSPARENCY = 0.55
local BEAM_WIDTH_FROM = 1.2 -- studs, aux pieds du joueur
local BEAM_WIDTH_TO = 0.3 -- studs, aux pieds du voleur
local REFRESH_INTERVAL = 0.2 -- s : écran repris, surbrillances revues
local ERROR_INTERVAL = 10 -- s : une erreur écrite au plus toutes les 10 s, pas une par image

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local TheftAlertController = {}

local thefts: { Theft } = {} -- ordre d'arrivée ; le dernier est affiché
local dirty = false -- un message est arrivé : appliqué à la prochaine image
local shown = false
local view: View? = nil
local fallback: View? = nil
local arrowV0: ArrowV0? = nil
local glows: { [Player]: Glow } = {}
local siren: Sound? = nil
-- Rotation posée par Clément sur chaque copie de l'Arrow (relue sur une nouvelle copie).
local arrowBase: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local arrowShown = false
local arrowRotation: number? = nil
local beamShown = false
local sinceRefresh = 0
local lastError = -math.huge
local noticed: { [string]: boolean } = {}

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

-- Une ligne dans la sortie, une seule fois par clé (Studio).
local function once(key: string, message: string)
	if IS_STUDIO and not noticed[key] then
		noticed[key] = true
		print(`[TheftAlertController] {message}`)
	end
end

local function playerGui(): Instance?
	return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local part = if root and root:IsA("BasePart") then root :: BasePart else nil
	return part, character:FindFirstChildOfClass("Humanoid")
end

-- Pieds d'un personnage (au ras du sol), sous son HumanoidRootPart.
local function feetOf(root: BasePart, humanoid: Humanoid?): Vector3
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, hip + root.Size.Y / 2 - 0.2, 0)
end

-- Le vol de `thief` s'affiche-t-il encore ? Parti ou mort : non. Personnage absent (streaming) : oui.
local function stillThere(thief: Player): boolean
	if thief.Parent ~= Players then
		return false
	end
	local character = thief.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid == nil or humanoid.Health > 0
end

local function itemName(itemId: string): string
	local def = Items.ById[itemId]
	return if def then def.DisplayName else UNKNOWN_ITEM
end

local function keysOf<K, V>(map: { [K]: V }): { K }
	local list: { K } = {}
	for key in map do
		table.insert(list, key)
	end
	return list
end

local function setText(element: GuiObject?, text: string)
	if element and (element:IsA("TextLabel") or element:IsA("TextButton")) then
		local label = element :: any
		if label.Text ~= text then
			label.Text = text
		end
	end
end

local function textOf(element: GuiObject?): string?
	if element and (element:IsA("TextLabel") or element:IsA("TextButton")) then
		return (element :: any).Text
	end
	return nil
end

local function setVisible(element: GuiObject?, visible: boolean)
	if element and element.Visible ~= visible then
		element.Visible = visible
	end
end

------------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------------

local function guiObject(root: Instance, name: string): GuiObject?
	local found = Find.path(root, name)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function clementView(screen: ScreenGui): View
	return {
		gui = screen,
		banner = guiObject(screen, BANNER),
		thiefName = guiObject(screen, THIEF_NAME),
		itemName = guiObject(screen, ITEM_NAME),
		arrow = guiObject(screen, ARROW),
		headline = nil,
		veil = nil,
		fallback = false,
	}
end

local function fallbackLabel(name: string, parent: Instance, y: number, height: number, maxSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(0.94, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = TEXT_COLOR
	label.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	label.Parent = parent
	return label
end

-- Repli V0 (voir l'en-tête) : rouge, sans style, rien de cliquable (le voile laisse passer les touches).
local function makeFallback(gui: Instance): View
	local screen = Instance.new("ScreenGui")
	screen.Name = FALLBACK_NAME
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = DISPLAY_ORDER
	screen.Enabled = false

	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = ALERT_RED
	veil.BackgroundTransparency = VEIL_TRANSPARENCY
	veil.BorderSizePixel = 0
	veil.Active = false -- les clics et les touches passent : la batte doit pouvoir frapper
	veil.Parent = screen

	local banner = Instance.new("Frame")
	banner.Name = BANNER
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, BANNER_Y)
	banner.Size = UDim2.fromScale(1, BANNER_HEIGHT)
	banner.BackgroundColor3 = ALERT_RED
	banner.BorderSizePixel = 0
	banner.Active = false
	banner.Parent = screen

	local headline = fallbackLabel("Headline", banner, 0.08, 0.56, 64)
	local action = fallbackLabel("Action", banner, 0.66, 0.28, 40)
	action.Text = ACTION_TEXT

	screen.Parent = gui
	return {
		gui = screen,
		banner = banner,
		thiefName = nil,
		itemName = nil,
		arrow = nil,
		headline = headline,
		veil = veil,
		fallback = true,
	}
end

-- L'écran à remplir : celui de Clément (le repli est alors détruit), sinon le repli, créé seulement
-- quand il y a quelque chose à montrer.
local function resolveView(needed: boolean): View?
	local gui = playerGui()
	if gui == nil then
		return nil
	end
	local screen = gui:FindFirstChild(SCREEN_NAME)
	if screen and screen:IsA("ScreenGui") then
		if fallback then
			fallback.gui:Destroy()
			fallback = nil
		end
		local current = view
		if current and current.gui == screen then
			return current
		end
		return clementView(screen :: ScreenGui)
	end
	if fallback and fallback.gui.Parent == nil then
		fallback = nil
	end
	if fallback == nil and needed then
		fallback = makeFallback(gui)
	end
	return fallback
end

local function showView(target: View, theft: Theft)
	local thiefText = string.upper(theft.Thief.DisplayName)
	local itemText = string.upper(itemName(theft.ItemId))
	setText(target.thiefName, thiefText)
	setText(target.itemName, itemText)
	local headline = target.headline
	if headline then
		setText(headline, string.format(HEADLINE, thiefText, itemText))
	end
	setVisible(target.banner, true)
	setVisible(target.thiefName, true)
	setVisible(target.itemName, true)
	if not target.gui.Enabled then
		target.gui.Enabled = true
	end
end

-- Rien à montrer : l'écran de Clément (qui peut arriver allumé de StarterGui, ou revenir à chaque
-- réapparition) et le repli restent éteints.
local function hideScreens()
	local gui = playerGui()
	local screen = if gui then gui:FindFirstChild(SCREEN_NAME) else nil
	if screen and screen:IsA("ScreenGui") and screen.Enabled then
		screen.Enabled = false
	end
	if fallback and fallback.gui.Enabled then
		fallback.gui.Enabled = false
	end
end

------------------------------------------------------------------------------
-- Sirène
------------------------------------------------------------------------------

local function stopSiren()
	local sound = siren
	siren = nil
	if sound then
		sound:Stop()
		sound:Destroy()
	end
end

local function startSiren()
	stopSiren()
	local name = PvP.AlertSirenSound
	local template = MarkerSounds.find(name)
	if template == nil then
		once("siren", `son « {name} » absent de ReplicatedStorage.{table.concat(MarkerSounds.Folder, ".")} (DEV-051) : alerte muette`)
		return
	end
	local sound = template:Clone()
	sound.Name = SIREN_NAME
	sound.Parent = SoundService
	sound.Ended:Once(function()
		if siren == sound then
			siren = nil
		end
		sound:Destroy()
	end)
	sound:Play()
	siren = sound
end

------------------------------------------------------------------------------
-- Surbrillance
------------------------------------------------------------------------------

local function removeGlow(thief: Player)
	local glow = glows[thief]
	if glow == nil then
		return
	end
	glows[thief] = nil
	glow.highlight:Destroy()
	local outline = glow.outline
	if glow.outlineOff and outline and outline.Parent ~= nil then
		outline.Enabled = true -- le contour de CarryService revient (l'objet est encore porté)
	end
end

-- Surbrillance de `thief` : créée sur son personnage actuel, et son StolenOutline coupé dès qu'il
-- arrive (le visuel porté peut arriver après l'alerte, avec le streaming).
local function keepGlow(thief: Player)
	local character = thief.Character
	local existing: Glow? = glows[thief]
	if existing and (existing.character ~= character or existing.highlight.Parent == nil) then
		removeGlow(thief)
		existing = nil
	end
	if character == nil then
		return
	end
	local glow: Glow
	if existing then
		glow = existing
	else
		local highlight = Instance.new("Highlight")
		highlight.Name = HIGHLIGHT_NAME
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = ALERT_RED
		highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
		highlight.OutlineColor = ALERT_RED
		highlight.OutlineTransparency = 0
		highlight.Adornee = character
		highlight.Parent = character
		local created: Glow = { highlight = highlight, character = character, outline = nil, outlineOff = false }
		glows[thief] = created
		glow = created
	end
	local outline = glow.outline
	if outline == nil or not outline:IsDescendantOf(character) then
		local found = character:FindFirstChild(STOLEN_OUTLINE, true)
		outline = if found and found:IsA("Highlight") then found :: Highlight else nil
		glow.outline = outline
		glow.outlineOff = false
	end
	if outline and outline.Enabled then
		outline.Enabled = false
		glow.outlineOff = true
	end
end

-- Les MAX_HIGHLIGHTS voleurs les plus récents sont surlignés, les autres plus.
local function syncGlows()
	local wanted: { [Player]: boolean } = {}
	local count = 0
	for index = #thefts, 1, -1 do
		local thief = thefts[index].Thief
		if count < MAX_HIGHLIGHTS and not wanted[thief] then
			wanted[thief] = true
			count += 1
		end
	end
	for _, thief in keysOf(glows) do
		if not wanted[thief] then
			removeGlow(thief)
		end
	end
	for thief in wanted do
		keepGlow(thief)
	end
end

------------------------------------------------------------------------------
-- Flèche
------------------------------------------------------------------------------

local function hideArrowV0()
	if arrowV0 then
		arrowV0.beam.Enabled = false
	end
	beamShown = false
end

local function makeArrowV0(): ArrowV0?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = ARROW_FOLDER

	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(0, 0, 0)
	anchor.Parent = folder
	local from = Instance.new("Attachment")
	from.Name = "From"
	from.Parent = anchor
	local to = Instance.new("Attachment")
	to.Name = "To"
	to.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Name = "Beam"
	beam.Color = ColorSequence.new(ALERT_RED)
	beam.LightEmission = 0.6
	beam.Transparency = NumberSequence.new(0.1, 0.35)
	beam.Width0 = BEAM_WIDTH_FROM
	beam.Width1 = BEAM_WIDTH_TO
	beam.FaceCamera = true
	beam.Segments = 10
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Enabled = false
	beam.Parent = anchor

	folder.Parent = camera
	return { folder = folder, from = from, to = to, beam = beam }
end

-- Angle (degrés, sens des aiguilles d'une montre) de `target` vu de la caméra, à l'horizontale :
-- 0 = droit devant, 90 = à droite, ±180 = derrière. nil si la cible est à l'aplomb de la caméra.
local function compassAngle(camera: Camera, target: Vector3): number?
	local frame = camera.CFrame
	local offset = target - frame.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local look = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(frame.UpVector.X, 0, frame.UpVector.Z) -- caméra à la verticale : le haut de l'écran
	end
	if flat.Magnitude < 1e-3 or look.Magnitude < 1e-3 then
		return nil
	end
	local ahead = look.Unit
	local right = Vector3.new(-ahead.Z, 0, ahead.X)
	return math.deg(math.atan2(flat:Dot(right), flat:Dot(ahead)))
end

local function updateArrow()
	local current = thefts[#thefts]
	local target = view
	if current == nil or target == nil then
		hideArrowV0()
		arrowShown = false
		return
	end
	local root, humanoid = bodyOf(current.Thief)
	local arrow = target.arrow
	if arrow then
		hideArrowV0()
		local camera = Workspace.CurrentCamera
		if root == nil or camera == nil then
			setVisible(arrow, false)
			arrowShown = false
			return
		end
		local angle = compassAngle(camera, root.Position)
		if angle then
			local base = arrowBase[arrow]
			if base == nil then
				base = arrow.Rotation
				arrowBase[arrow] = base
			end
			local rotation = (base :: number) + angle
			if math.abs(arrow.Rotation - rotation) > 0.05 then
				arrow.Rotation = rotation
			end
			arrowRotation = angle
		end
		setVisible(arrow, true)
		arrowShown = true
		return
	end
	arrowShown = false
	local mine, myHumanoid = bodyOf(localPlayer)
	if root == nil or mine == nil then
		hideArrowV0()
		return
	end
	local existing = arrowV0
	if existing == nil or existing.folder.Parent == nil then
		if existing then
			existing.folder:Destroy()
		end
		arrowV0 = makeArrowV0()
	end
	local beam = arrowV0
	if beam == nil then
		return
	end
	beam.from.Position = feetOf(mine, myHumanoid)
	beam.to.Position = feetOf(root, humanoid)
	beam.beam.Enabled = true
	beamShown = true
end

------------------------------------------------------------------------------
-- Affichage
------------------------------------------------------------------------------

local function hideAll()
	shown = false
	stopSiren()
	for _, thief in keysOf(glows) do
		removeGlow(thief)
	end
	hideArrowV0()
	arrowShown = false
	arrowRotation = nil
	hideScreens()
end

-- Applique l'état (vols en cours) : sans effet s'il n'a pas changé.
local function apply()
	local current = thefts[#thefts]
	if current == nil then
		if shown then
			hideAll()
		else
			hideScreens()
		end
		return
	end
	local target = resolveView(true)
	view = target
	if target then
		showView(target, current)
		if target.fallback then
			once("fallback", "UI_TheftAlert pas encore livré : bannière et flèche V0")
		else
			once("screen", "bannière : écran UI_TheftAlert de Clément")
		end
	end
	if not shown then
		shown = true
		startSiren()
	end
	syncGlows()
end

local function pulse()
	local target = view
	local veil = if target then target.veil else nil
	if veil then
		veil.BackgroundTransparency = VEIL_TRANSPARENCY + VEIL_PULSE * math.sin(os.clock() * 2 * math.pi / VEIL_PERIOD)
	end
end

local function step(deltaTime: number)
	for index = #thefts, 1, -1 do
		if not stillThere(thefts[index].Thief) then
			table.remove(thefts, index) -- mort ou départ du voleur : le serveur va aussi l'annoncer
			dirty = true
		end
	end
	sinceRefresh += deltaTime
	if dirty or sinceRefresh >= REFRESH_INTERVAL then
		dirty = false
		sinceRefresh = 0
		apply()
	end
	if shown then
		updateArrow()
		pulse()
	end
end

-- TheftAlert(active, thief?, itemId?) (Net/Definitions). Un voleur nil : il est parti entre l'envoi
-- et l'arrivée du message (le false suit).
local function onTheftAlert(active: boolean, thief: Player?, itemId: string?)
	if active ~= true then
		table.clear(thefts)
		dirty = true
		return
	end
	if thief == nil or thief == localPlayer then
		once("thief", "TheftAlert(true) sans voleur valable : ignoré")
		return
	end
	for index = #thefts, 1, -1 do
		if thefts[index].Thief == thief then
			table.remove(thefts, index)
		end
	end
	table.insert(thefts, { Thief = thief, ItemId = itemId or "" })
	dirty = true
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function TheftAlertController.GetState(): { [string]: any }
	local current = if shown then thefts[#thefts] else nil
	local target = if shown then view else nil
	local count = 0
	for _ in glows do
		count += 1
	end
	return {
		Active = shown,
		Thefts = #thefts,
		Thief = if current then current.Thief else nil,
		ItemId = if current then current.ItemId else nil,
		ThiefName = if target then textOf(target.thiefName) else nil,
		ItemName = if target then textOf(target.itemName) else nil,
		Headline = if target and target.headline then target.headline.Text else nil,
		Fallback = target ~= nil and target.fallback,
		Arrow = arrowShown,
		ArrowRotation = if arrowShown then arrowRotation else nil,
		Beam = beamShown,
		Highlights = count,
		Siren = siren ~= nil,
	}
end

function TheftAlertController.Start()
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	Net.Client.TheftAlert:Connect(onTheftAlert)
	hideScreens()
	RunService.Heartbeat:Connect(function(deltaTime: number)
		xpcall(step, function(err: any)
			if os.clock() - lastError >= ERROR_INTERVAL then
				lastError = os.clock()
				warn(`[TheftAlertController] {err}`)
			end
		end, deltaTime)
	end)
end

return TheftAlertController
