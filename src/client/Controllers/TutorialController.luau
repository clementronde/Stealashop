--!strict
-- TutorialController (DEV-046, client) : bulle et flèche au sol du tutoriel (Partie 1, sections 3,
-- 5.11 et 5.12 ; contrat UI 2.2 : `UI_Tutorial` avec `Bubble`, son `Label`, et `NextButton`).
--
-- Le serveur décide tout (TutorialService) et envoie TutorialStep(step, hint?, target?) : l'étape
-- (0 = plus de tuto : tout est caché), l'indice à afficher (clé de Config/Tutorial.Hints, nil = la
-- bulle de l'étape) et le point visé par la flèche (nil = pas de flèche). Ce contrôleur affiche, et
-- n'envoie que TutorialSkip (le serveur vérifie l'étape).
--
-- Bulle :
--   - texte : Hints[hint] s'il est donné, sinon Steps[step].Bubble (rien à l'étape 10, sauf un
--     indice ; vague 52 : plus de ShelfBubble, la bulle de l'étape est celle du rayon). Seul choix fait ici : EquipFists aux étapes 1 et 2, quand le serveur n'envoie pas
--     d'indice, que la cible est la vitrine d'un magasin PNJ (pas la porte de la boutique, par où la
--     flèche passe d'abord), que le joueur en est à EQUIP_HINT_RADIUS studs et qu'il n'a pas son
--     outil de casse en main (Tool avec l'attribut ToolId de ToolService) ;
--   - écran de Clément, s'il est livré : PlayerGui/UI_Tutorial (copié depuis StarterGui), texte dans
--     Bubble.Label. Seuls Enabled de l'écran, le texte et la visibilité du bouton Passer sont
--     touchés (2.2, « Libre pour Ironix ») ;
--   - repli V0 tant que UI_Tutorial manque (ou n'a pas de Bubble.Label) : un écran gris fait par le
--     code, TutorialV0 dans le PlayerGui, avec les noms du contrat (Bubble, Label, NextButton),
--     clairement provisoire et sans style. Il est détruit dès que UI_Tutorial arrive ;
--   - bouton Passer : SkipButton de UI_Tutorial s'il existe (nom proposé à Clément), sinon
--     NextButton ; visible à partir de l'étape SkipFromStep (5), avec la bulle ;
--   - la bulle et la flèche se cachent pendant que UI_Unbox, UI_WeaponShop ou UI_AuraShop est ouvert
--     (Enabled), pour ne rien recouvrir.
--
-- Flèche au sol, côté client seulement, dans un dossier TutorialArrow de la caméra (rien n'est
-- répliqué) : un Beam entre les pieds du joueur et la cible, plus un repère au-dessus de la cible.
-- Beam : copie de Config.Tutorial.ArrowAsset (FX_Tutorial_Arrow, un Beam de Clément, UI-006) cherché
-- dans ReplicatedStorage/Assets, sous-dossiers compris, sinon un Beam V0 doré qui s'affine vers la
-- cible. Repère : copie de MarkerAsset (FX_Tutorial_Marker, Model ou pièce, pivot posé sur la cible),
-- sinon une boule V0 qui flotte. La flèche se cache à ARRIVE_RADIUS studs de la cible.
--
-- Liste des tâches (vague 60, a197 ; Cantin : « je savais pas qu'est-ce qu'il fallait qu'on fasse, où on en était et
-- pourquoi ») : TutorialStep porte aussi la progression (have, need) ; Shared/TutorialTasks en fait les lignes (but,
-- ce qu'il faut faire avec la progression, raison, tâches faites cochées). Écran de Clément avec `Tasks.Template`
-- (noms proposés, facultatifs : Goal, Check, Progress, Why) : une copie par tâche montrée, dans Tasks ; sans lui, la
-- tâche et sa progression s'écrivent sous la bulle, dans Bubble.Label (« Buy the Wrench (5/10): Earn cash: $100 /
-- $300 to buy the Wrench »). Le repli V0 du code a son propre panneau Tasks gris, aux mêmes noms. ProtectShop (fin du
-- tuto) : toutes les tâches cochées. Passer (vague 60) : une étape à la fois (le serveur choisit la suivante) ; sans
-- réponse du serveur en SkipReplyTimeout s, la bulle revient.
--
-- Vague 73 (a256, L-242 point 5) : le repère de Clément rebondit (Tutorial.MarkerBob, MarkerPeriod) ; aux étapes de
-- Tutorial.Focus.Targets (7 : la clé à molette, 8 : la première aura), quand la boutique est ouverte et la carte
-- visible, UI_TutorialFocus de Clément s'allume : Focus posé sur le BuyButton (Margin px autour, barre de Roblox
-- comprise), sans voile sur le reste (vague 75, L-262 point 2 : Focus.Veil) ; Pointer se montre après HesitateTime s.
-- Seuls Enabled de l'écran, Position et Size de Focus, Enabled de son UIStroke Veil et Visible de Pointer sont
-- touchés. Écran absent : rien.
--
-- API (client) :
--   TutorialController.GetState() -> { Step, Hint, Text, Target, Shown, Fallback, Arrow, Have, Need, Tasks }
--       Ce qui est affiché, pour un test dans Studio (barre de commande côté client). Tasks : les lignes de la
--       liste (Shared/TutorialTasks.Row), vide sans tuto.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared:WaitForChild("Config"):WaitForChild("Tutorial"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local TutorialTasks = require(Shared:WaitForChild("TutorialTasks"))

-- Écran de Clément et ses éléments (contrat 2.2). SkipButton : nom proposé, pas encore au contrat.
local SCREEN_NAME = "UI_Tutorial"
local LABEL_PATH = "Bubble.Label"
local SKIP_BUTTON = "SkipButton"
local NEXT_BUTTON = "NextButton"
-- Vague 60 (a197) : liste des tâches, noms proposés à Clément (Contract/UI, facultatifs).
local TASKS_PATH = "Tasks"
local TASK_TEMPLATE = "Template"
local TASK_GOAL = "Goal"
local TASK_CHECK = "Check"
local TASK_PROGRESS = "Progress"
local TASK_WHY = "Why"
local TASK_ROW_ATTRIBUTE = "TutorialTaskRow" -- posé sur les copies du Template (pour les retrouver)
local OUTRO_HINT = "ProtectShop" -- fin du tuto : toutes les tâches cochées
local FALLBACK_ROW_HEIGHT = 0.18 -- V0 : hauteur d'une ligne du panneau Tasks du repli (part de la liste)
local FALLBACK_ROW_GAP = 0.02 -- V0 : écart entre deux lignes
-- Écrans qui cachent la bulle et la flèche quand ils sont ouverts.
local COVERING_SCREENS = { "UI_WeaponShop", "UI_AuraShop" } -- vague 53 : UI_Unbox n'existe plus
-- Attribut posé par ToolService sur le Tool de casse.
local TOOL_ID_ATTRIBUTE = "ToolId"
local ASSETS = "Assets"
-- Vitrine d'un magasin PNJ (contrat 2.1 et 10.4) : seule cible où EquipFists a un sens.
local STORE_TAG = "NPCStore"
local WINDOW_NAME = "Window"
local SAME_POINT = 1 -- studs : la cible reçue est cette vitrine (le serveur vise son centre)

-- Étapes où le joueur doit frapper la vitrine (Config/Tutorial.Steps).
local STEP_ARRIVE = 1
local STEP_HIT = 2

-- V0 proposés, absents du doc :
local FALLBACK_NAME = "TutorialV0" -- écran de repli, fait par le code tant que UI_Tutorial manque
local SKIP_TEXT = "Skip" -- texte du bouton Passer du repli (anglais, L-036)
local EQUIP_HINT_RADIUS = 20 -- studs : EquipFists près de la vitrine sans outil en main
local ARRIVE_RADIUS = 6 -- studs : la flèche se cache près de la cible
local REFRESH_INTERVAL = 0.2 -- s entre deux mises à jour de la bulle
local ARROW_COLOR = Color3.fromRGB(255, 197, 46) -- or de la planche 10.6 (#FFC52E)
local MARKER_HEIGHT = 3.5 -- studs au-dessus de la cible (repère V0)
local MARKER_BOB = Tutorial.MarkerBob -- studs d'amplitude (vague 73 : repère V0 et repère de Clément, L-242 point 5)
local MARKER_PERIOD = Tutorial.MarkerPeriod -- s
-- Vague 73 (a256, L-242 point 5) : écran UI_TutorialFocus de Clément (facultatif).
local FOCUS = Tutorial.Focus
local FOCUS_FRAME = "Focus"
local FOCUS_POINTER = "Pointer"
local FOCUS_VEIL = "Veil" -- vague 75 : UIStroke de Focus qui assombrissait le reste de l'écran (L-242 point 5)

type View = {
	gui: ScreenGui,
	label: Instance, -- TextLabel ou TextButton : a un Text
	skip: GuiButton?,
	fallback: boolean,
	tasks: Instance?, -- vague 60 : Tasks, s'il a un Template (GuiObject)
	template: GuiObject?,
}

type Arrow = {
	folder: Folder,
	from: Attachment,
	to: Attachment,
	beam: Beam,
	marker: PVInstance,
	markerV0: boolean,
}

local TutorialController = {}

local localPlayer = Players.LocalPlayer
local state = {
	step = 0,
	hint = nil :: string?,
	target = nil :: Vector3?,
	have = nil :: number?, -- vague 60 : progression de l'étape
	need = nil :: number?,
	skipping = false, -- Passer envoyé : tout reste caché jusqu'à la réponse du serveur
	skippedAt = 0, -- os.clock() de l'envoi de Passer
}
local shownRows: { TutorialTasks.Row } = {}
local tasksList: Instance? = nil -- liste remplie la dernière fois, et sa signature (rien ne change : rien n'est refait)
local tasksSignature = ""
local shownText: string? = nil
local shown = false
local fallback: View? = nil
local arrow: Arrow? = nil
local arrowShown = false
local boundButton: GuiButton? = nil
local skipConnection: RBXScriptConnection? = nil
local skipRemote: any = nil
local focusButton: GuiObject? = nil -- vague 73 : bouton mis en avant (UI_TutorialFocus), depuis focusSince
local focusSince = 0
local focusShown = false

------------------------------------------------------------------------------
-- Lecture du monde
------------------------------------------------------------------------------

local function playerGui(): Instance?
	return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function rootOf(): (BasePart?, Humanoid?)
	local character = localPlayer.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root :: BasePart, humanoid
end

local function holdingTool(): boolean
	local character = localPlayer.Character
	if character == nil then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(TOOL_ID_ATTRIBUTE) ~= nil then
			return true
		end
	end
	return false
end

-- La cible est-elle la vitrine d'un magasin PNJ ? Aux étapes 1 et 2, la flèche passe d'abord par la
-- porte de la boutique du joueur (TutorialService, L-050) : près de cette porte, pas d'EquipFists.
-- Même point que le serveur : le centre de la pièce Window, ou le pivot si c'est un Model.
local function isStoreWindow(target: Vector3): boolean
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		local window = Find.path(store, WINDOW_NAME)
		local position: Vector3? = nil
		if window and window:IsA("BasePart") then
			position = (window :: BasePart).Position
		elseif window and window:IsA("Model") then
			position = (window :: Model):GetPivot().Position
		end
		if position and (position - target).Magnitude <= SAME_POINT then
			return true
		end
	end
	return false
end

local function covered(): boolean
	local gui = playerGui()
	if gui == nil then
		return false
	end
	for _, name in COVERING_SCREENS do
		local screen = gui:FindFirstChild(name)
		if screen and screen:IsA("ScreenGui") and (screen :: ScreenGui).Enabled then
			return true
		end
	end
	return false
end

-- Premier objet de ce nom dans ReplicatedStorage/Assets (sous-dossiers compris).
local function asset(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS)
	return if assets then assets:FindFirstChild(name, true) else nil
end

------------------------------------------------------------------------------
-- Bulle
------------------------------------------------------------------------------

local function currentText(): string?
	if state.step <= 0 or state.skipping then
		return nil
	end
	local hint = state.hint
	if hint == nil and (state.step == STEP_ARRIVE or state.step == STEP_HIT) then
		local root = rootOf()
		local target = state.target
		if
			root
			and target
			and (root.Position - target).Magnitude <= EQUIP_HINT_RADIUS
			and not holdingTool()
			and isStoreWindow(target)
		then
			hint = "EquipFists"
		end
	end
	if hint then
		local text = Tutorial.Hints[hint]
		if text then
			return text
		end
	end
	local def = Tutorial.Steps[state.step]
	return if def then def.Bubble else nil
end

-- Vague 60 : la liste Tasks d'un écran et son Template (GuiObject), sinon nil, nil.
local function tasksOf(screen: Instance): (Instance?, GuiObject?)
	local list = Find.path(screen, TASKS_PATH)
	local template = if list then list:FindFirstChild(TASK_TEMPLATE) else nil
	if list and template and template:IsA("GuiObject") then
		return list, template :: GuiObject
	end
	return nil, nil
end

-- Écran de Clément s'il a au moins Bubble.Label.
local function clementView(gui: Instance): View?
	local screen = gui:FindFirstChild(SCREEN_NAME)
	if screen == nil or not screen:IsA("ScreenGui") then
		return nil
	end
	local label = Find.path(screen, LABEL_PATH)
	if label == nil or not (label:IsA("TextLabel") or label:IsA("TextButton")) then
		return nil
	end
	local skip = Find.path(screen, SKIP_BUTTON) or Find.path(screen, NEXT_BUTTON)
	local tasks, template = tasksOf(screen)
	return {
		gui = screen :: ScreenGui,
		label = label :: Instance,
		skip = if skip and skip:IsA("GuiButton") then skip :: GuiButton else nil,
		fallback = false,
		tasks = tasks,
		template = template,
	}
end

-- Vague 60 : panneau Tasks gris du repli V0 (mêmes noms que ceux proposés à Clément), à gauche, au milieu de l'écran
-- (rien d'important en haut, 2.2). Une ligne : Check (carré vert), Goal, Progress, Why.
local function makeFallbackTasks(screen: ScreenGui)
	local list = Instance.new("Frame")
	list.Name = TASKS_PATH
	list.AnchorPoint = Vector2.new(0, 0.5)
	list.Position = UDim2.fromScale(0.01, 0.5)
	list.Size = UDim2.fromScale(0.24, 0.4)
	list.BackgroundTransparency = 1
	list.Parent = screen

	-- Lignes empilées par fillTasks (Position), sans UIListLayout.
	local row = Instance.new("Frame")
	row.Name = TASK_TEMPLATE
	row.Visible = false
	row.Size = UDim2.fromScale(1, FALLBACK_ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	row.BackgroundTransparency = 0.25
	row.BorderSizePixel = 0
	row.Parent = list
	local check = Instance.new("Frame")
	check.Name = TASK_CHECK
	check.Position = UDim2.fromScale(0.02, 0.1)
	check.Size = UDim2.fromScale(0.07, 0.35)
	check.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
	check.BorderSizePixel = 0
	check.Visible = false
	check.Parent = row
	local function text(name: string, y: number, height: number, bold: boolean): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.fromScale(0.12, y)
		label.Size = UDim2.fromScale(0.86, height)
		label.BackgroundTransparency = 1
		label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		label.Parent = row
		return label
	end
	text(TASK_GOAL, 0.05, 0.4, true)
	text(TASK_PROGRESS, 0.47, 0.27, false)
	text(TASK_WHY, 0.74, 0.22, false).TextColor3 = Color3.fromRGB(200, 200, 200)
end

-- Repli V0 (voir l'en-tête) : gris, sans style, aux noms du contrat.
local function makeFallback(gui: Instance): View
	local screen = Instance.new("ScreenGui")
	screen.Name = FALLBACK_NAME
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.Enabled = false

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.Position = UDim2.fromScale(0.5, 0.8)
	bubble.Size = UDim2.fromScale(0.46, 0.085)
	bubble.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	bubble.BackgroundTransparency = 0.15
	bubble.BorderSizePixel = 0
	bubble.Parent = screen
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 7
	ratio.Parent = bubble

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.92, 0.75)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = bubble

	local skip = Instance.new("TextButton")
	skip.Name = NEXT_BUTTON
	skip.AnchorPoint = Vector2.new(0, 0.5)
	skip.Position = UDim2.new(1, 8, 0.5, 0)
	skip.Size = UDim2.fromScale(0.2, 0.9)
	skip.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
	skip.BorderSizePixel = 0
	skip.Font = Enum.Font.GothamBold
	skip.TextScaled = true
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Text = SKIP_TEXT
	skip.Visible = false
	skip.Parent = bubble
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(88, 44) -- 2.2 : boutons d'au moins 44 px de haut sur téléphone
	minimum.Parent = skip

	makeFallbackTasks(screen)
	local tasks, template = tasksOf(screen)

	screen.Parent = gui
	return { gui = screen, label = label, skip = skip, fallback = true, tasks = tasks, template = template }
end

-- L'écran à remplir : celui de Clément (le repli est alors détruit), sinon le repli, créé seulement
-- quand il y a quelque chose à montrer.
local function resolveView(needed: boolean): View?
	local gui = playerGui()
	if gui == nil then
		return nil
	end
	local view = clementView(gui)
	if view then
		if fallback then
			fallback.gui:Destroy()
			fallback = nil
		end
		return view
	end
	if fallback and fallback.gui.Parent == nil then
		fallback = nil
	end
	if fallback == nil and needed then
		fallback = makeFallback(gui)
	end
	return fallback
end

local function onSkip()
	if state.step < Tutorial.SkipFromStep or state.skipping or skipRemote == nil then
		return
	end
	state.skipping = true
	state.skippedAt = os.clock()
	skipRemote:Fire()
end

local function bindSkip(button: GuiButton?)
	if button == boundButton then
		return
	end
	if skipConnection then
		skipConnection:Disconnect()
		skipConnection = nil
	end
	boundButton = button
	if button then
		skipConnection = button.Activated:Connect(onSkip)
	end
end

------------------------------------------------------------------------------
-- Flèche
------------------------------------------------------------------------------

-- Pièces d'un repère copié : jamais de collision ni de requête (réglage du clone, pas du modèle).
local function makeInert(root: Instance)
	local parts: { Instance } = root:GetDescendants()
	table.insert(parts, root)
	for _, inst in parts do
		if inst:IsA("BasePart") then
			local part = inst :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function makeArrow(): Arrow?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "TutorialArrow"

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

	local beam: Beam
	local template = asset(Tutorial.ArrowAsset)
	if template and template:IsA("Beam") then
		beam = template:Clone() :: Beam
	else
		beam = Instance.new("Beam")
		beam.Color = ColorSequence.new(ARROW_COLOR)
		beam.LightEmission = 0.6
		beam.Transparency = NumberSequence.new(0.15, 0.4)
		beam.Width0 = 1.2
		beam.Width1 = 0.3
		beam.FaceCamera = true
		beam.Segments = 10
	end
	beam.Name = "Beam"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Enabled = false
	beam.Parent = anchor

	local marker: PVInstance
	local markerV0 = false
	local markerTemplate = asset(Tutorial.MarkerAsset)
	if markerTemplate and (markerTemplate:IsA("Model") or markerTemplate:IsA("BasePart")) then
		marker = markerTemplate:Clone() :: PVInstance
		makeInert(marker)
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(1.2, 1.2, 1.2)
		ball.Material = Enum.Material.Neon
		ball.Color = ARROW_COLOR
		ball.CastShadow = false
		makeInert(ball)
		marker = ball
		markerV0 = true
	end
	marker.Name = "Marker"

	folder.Parent = camera
	return { folder = folder, from = from, to = to, beam = beam, marker = marker, markerV0 = markerV0 }
end

local function hideArrow()
	if arrow then
		arrow.beam.Enabled = false
		arrow.marker.Parent = nil
	end
	arrowShown = false
end

local function updateArrow()
	local target = state.target
	local root, humanoid = rootOf()
	if state.step <= 0 or state.skipping or target == nil or root == nil or covered() then
		hideArrow()
		return
	end
	if (root.Position - target).Magnitude <= ARRIVE_RADIUS then
		hideArrow()
		return
	end
	if arrow == nil or arrow.folder.Parent == nil then
		if arrow then
			arrow.folder:Destroy()
		end
		arrow = makeArrow()
	end
	local current = arrow
	if current == nil then
		return
	end
	local hip = if humanoid then humanoid.HipHeight else 2
	current.from.Position = root.Position - Vector3.new(0, hip + root.Size.Y / 2 - 0.2, 0)
	current.to.Position = target
	current.beam.Enabled = true
	if current.marker.Parent == nil then
		current.marker.Parent = current.folder
	end
	-- Vague 73 (L-242 point 5) : le repère de Clément (FX_Tutorial_Marker, grand V à 3,2 studs) rebondit aussi.
	local bob = MARKER_BOB * math.sin(os.clock() * 2 * math.pi / MARKER_PERIOD)
	local height = if current.markerV0 then MARKER_HEIGHT + bob elseif Tutorial.MarkerBobClement then bob else 0
	current.marker:PivotTo(CFrame.new(target + Vector3.new(0, height, 0)))
	arrowShown = true
end

------------------------------------------------------------------------------
-- Bouton mis en avant (vague 73, a256, L-242 point 5 : UI_TutorialFocus de Clément, Config/Tutorial.Focus)
------------------------------------------------------------------------------

-- Visible jusqu'à son écran, et allumé.
local function shownOnScreen(object: GuiObject): boolean
	local current: Instance? = object
	while current ~= nil do
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		if current:IsA("LayerCollector") then
			return (current :: LayerCollector).Enabled
		end
		current = current.Parent
	end
	return false
end

-- Le bouton à mettre en avant à cette étape : celui de la carte visée, dans la boutique ouverte, ou nil.
local function focusTarget(): GuiObject?
	if not FOCUS.Enabled or state.step <= 0 or state.skipping then
		return nil
	end
	local spec = FOCUS.Targets[state.step]
	local gui = playerGui()
	if spec == nil or gui == nil then
		return nil
	end
	local screen = gui:FindFirstChild(spec.Screen)
	if screen == nil or not screen:IsA("ScreenGui") or not (screen :: ScreenGui).Enabled then
		return nil
	end
	local suffix: string = spec.CardSuffix
	for _, card in screen:GetDescendants() do
		if card:IsA("GuiObject") and card.Name ~= TASK_TEMPLATE and string.sub(card.Name, -#suffix) == suffix then
			local button = Find.path(card, spec.Button)
			if button and button:IsA("GuiObject") and shownOnScreen(button :: GuiObject) then
				return button :: GuiObject
			end
		end
	end
	return nil
end

local function focusView(): (ScreenGui?, GuiObject?, GuiObject?)
	local gui = playerGui()
	local screen = if gui then gui:FindFirstChild(FOCUS.Screen) else nil
	if screen == nil or not screen:IsA("ScreenGui") then
		return nil, nil, nil
	end
	local focus = Find.path(screen, FOCUS_FRAME)
	if focus == nil or not focus:IsA("GuiObject") then
		return nil, nil, nil
	end
	local pointer = Find.path(focus, FOCUS_POINTER)
	return screen :: ScreenGui, focus :: GuiObject, if pointer and pointer:IsA("GuiObject") then pointer :: GuiObject else nil
end

-- Décalage du haut de l'écran (barre de Roblox) : un bouton d'un écran qui ne l'ignore pas est plus bas d'autant
-- dans UI_TutorialFocus, qui l'ignore.
local function insetOf(button: GuiObject): Vector2
	local current: Instance? = button
	while current ~= nil and not current:IsA("ScreenGui") do
		current = current.Parent
	end
	if current == nil or (current :: ScreenGui).IgnoreGuiInset then
		return Vector2.zero
	end
	local ok, topLeft = pcall(function(): any
		return (game:GetService("GuiService") :: any):GetGuiInset()
	end)
	return if ok and typeof(topLeft) == "Vector2" then topLeft else Vector2.zero
end

local function hideFocus()
	if focusShown then
		local screen, _, pointer = focusView()
		if screen and screen.Enabled then
			screen.Enabled = false
		end
		if pointer and pointer.Visible then
			pointer.Visible = false
		end
	end
	focusShown = false
end

-- À chaque image tant qu'un bouton est visé : Focus suit le bouton (fenêtre qui grandit, défilement).
local function placeFocus()
	local button = focusButton
	if button == nil or button.Parent == nil or not shownOnScreen(button) then
		hideFocus()
		return
	end
	local screen, focus, pointer = focusView()
	if screen == nil or focus == nil then
		focusShown = false
		return
	end
	local margin = FOCUS.Margin
	local size = button.AbsoluteSize + Vector2.new(margin * 2, margin * 2)
	local topLeft = button.AbsolutePosition + insetOf(button) - Vector2.new(margin, margin)
	local parent = focus.Parent
	if parent and parent:IsA("GuiObject") then
		topLeft -= (parent :: GuiObject).AbsolutePosition
	end
	local anchored = topLeft + focus.AnchorPoint * size
	focus.Position = UDim2.fromOffset(anchored.X, anchored.Y)
	focus.Size = UDim2.fromOffset(size.X, size.Y)
	-- Vague 75 (a260, L-262 point 2 : « on ne grise pas les autres boutons ») : le UIStroke Veil de Clément suit FOCUS.Veil.
	local veil = focus:FindFirstChild(FOCUS_VEIL)
	if veil and veil:IsA("UIStroke") and (veil :: UIStroke).Enabled ~= FOCUS.Veil then
		(veil :: UIStroke).Enabled = FOCUS.Veil
	end
	if not screen.Enabled then
		screen.Enabled = true
	end
	focusShown = true
	if pointer then
		local wanted = os.clock() - focusSince >= FOCUS.HesitateTime
		if pointer.Visible ~= wanted then
			pointer.Visible = wanted
		end
	end
end

local function updateFocus()
	local button = focusTarget()
	if button ~= focusButton then
		focusButton = button
		focusSince = os.clock() -- nouveau bouton : le joueur hésite à partir de maintenant
		local _, _, pointer = focusView()
		if pointer and pointer.Visible then
			pointer.Visible = false
		end
	end
	placeFocus()
end

------------------------------------------------------------------------------
-- Affichage
------------------------------------------------------------------------------

-- Vague 60 : lignes de la liste des tâches (Shared/TutorialTasks) ; vide sans tuto ou pendant un Passer.
local function taskRows(): { TutorialTasks.Row }
	if state.step <= 0 or state.skipping or not Tutorial.TaskList then
		return {}
	end
	local rows = TutorialTasks.Rows(state.step, state.have, state.need)
	if state.hint == OUTRO_HINT then
		for _, row in rows do
			if row.Current then
				row.Done = true
				row.Line = nil
			end
		end
	end
	return rows
end

local function setText(inst: Instance?, text: string)
	if inst and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then
		local label = inst :: any
		if label.Text ~= text then
			label.Text = text
		end
	end
end

local function setVisible(inst: Instance?, visible: boolean)
	if inst and inst:IsA("GuiObject") and (inst :: GuiObject).Visible ~= visible then
		(inst :: GuiObject).Visible = visible
	end
end

-- Vague 60 : une copie du Template par ligne, refaites seulement quand une ligne change.
local function fillTasks(view: View, rows: { TutorialTasks.Row })
	local list, template = view.tasks, view.template
	if list == nil or template == nil then
		return
	end
	local parts: { string } = {}
	for _, row in rows do
		table.insert(parts, `{row.Index}|{row.Done}|{row.Current}|{row.Line or ""}`)
	end
	local signature = table.concat(parts, "\n")
	if list == tasksList and signature == tasksSignature then
		return
	end
	tasksList, tasksSignature = list, signature
	for _, child in list:GetChildren() do
		if child:GetAttribute(TASK_ROW_ATTRIBUTE) then
			child:Destroy()
		end
	end
	for order, row in rows do
		local copy = template:Clone()
		copy.Name = `Task_{row.Index}`
		copy:SetAttribute(TASK_ROW_ATTRIBUTE, true)
		if view.fallback then
			copy.Position = UDim2.fromScale(0, (order - 1) * (FALLBACK_ROW_HEIGHT + FALLBACK_ROW_GAP))
		else
			copy.LayoutOrder = row.Index -- l'UIListLayout de Clément range les lignes
		end
		setText(copy:FindFirstChild(TASK_GOAL, true), row.Goal)
		setVisible(copy:FindFirstChild(TASK_CHECK, true), row.Done)
		local progress = copy:FindFirstChild(TASK_PROGRESS, true)
		setText(progress, row.Line or "")
		setVisible(progress, row.Current and row.Line ~= nil)
		local why = copy:FindFirstChild(TASK_WHY, true)
		setText(why, row.Why)
		setVisible(why, row.Current)
		copy.Visible = true
		copy.Parent = list
	end
end

local function render()
	if state.skipping and os.clock() - state.skippedAt >= Tutorial.SkipReplyTimeout then
		state.skipping = false -- vague 60 : pas de réponse du serveur, la bulle revient
	end
	local bubble = currentText()
	local rows = taskRows()
	shownRows = rows
	-- Vague 60 : sans panneau Tasks, la tâche et sa progression s'écrivent sous la bulle (Bubble.Label) ; avec lui,
	-- la bulle garde son texte, ou, sans bulle à cette étape (étape 10), ce qu'il faut faire.
	local gui = playerGui()
	local clement = if gui then clementView(gui) else nil
	local hasPanel = clement == nil or clement.tasks ~= nil -- le repli V0 a toujours son panneau
	local text: string? = bubble
	if #rows > 0 and state.hint ~= OUTRO_HINT then
		if hasPanel then
			if text == nil then
				for _, row in rows do
					if row.Current then
						text = row.Line
					end
				end
			end
		else
			local compact = TutorialTasks.Compact(state.step, state.have, state.need)
			if compact then
				text = if text then `{text}\n{compact}` else compact
			end
		end
	end
	local visible = text ~= nil and not covered()
	local view = resolveView(text ~= nil)
	if view then
		fillTasks(view, rows)
		local label = view.label :: any
		if text and label.Text ~= text then
			label.Text = text
		end
		if view.gui.Enabled ~= visible then
			view.gui.Enabled = visible
		end
		local skip = view.skip
		if skip then
			local skipVisible = visible and state.step >= Tutorial.SkipFromStep
			if skip.Visible ~= skipVisible then
				skip.Visible = skipVisible
			end
		end
		bindSkip(skip)
	end
	shownText = if visible then text else nil
	shown = visible
	updateArrow()
	updateFocus()
end

local function onStep(step: number, hint: string?, target: Vector3?, have: number?, need: number?)
	state.step = step
	state.hint = hint
	state.target = target
	state.have = have
	state.need = need
	state.skipping = false
	render()
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function TutorialController.GetState(): { [string]: any }
	return {
		Step = state.step,
		Hint = state.hint,
		Text = shownText,
		Target = state.target,
		Shown = shown,
		Fallback = fallback ~= nil,
		Arrow = arrowShown,
		Have = state.have,
		Need = state.need,
		Tasks = shownRows,
		Focus = focusShown,
	}
end

function TutorialController.Start()
	if not Tutorial.Enabled then
		return
	end
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	skipRemote = Net.Client.TutorialSkip
	Net.Client.TutorialStep:Connect(onStep)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			render()
		elseif arrowShown then
			updateArrow()
		end
		if focusButton ~= nil then
			placeFocus() -- vague 73 : Focus suit le bouton à chaque image
		end
	end)
end

return TutorialController
