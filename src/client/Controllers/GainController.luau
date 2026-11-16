--!strict
-- GainController (client, liaison L-091 point 3) : les gains qui s'affichent, puis volent vers le total.
--
-- Rôle :
--   - Entraînement : à chaque gain du tapis, « +2 Speed/s » au-dessus du joueur ; à chaque gain du
--     banc, « +X Power » (textes de L-091). Une copie de ReplicatedStorage/Assets/UI/BB_Gain de Clément
--     (Row.Amount, Row.Icon), posée sur le HumanoidRootPart, qui monte et s'efface (UiMotion.FloatGain),
--     puis détruite. Source : les attributs Speed (points d'entraînement) et Strength du Player, posés
--     par StatsService, quand ils montent pendant que l'attribut TrainingMachine vaut « Treadmill » ou
--     « Bench » (TrainingService). Gains rapprochés : un BB_Gain au plus par FloatGain.MinGap s, les
--     gains entre deux s'additionnent dans le suivant. Sans son (Train_Gain retiré, L-118 point 7).
--     Vague 59 (a190, L-182 point 8) : sur le tapis, le gain d'une seconde s'affiche en Config/Hud.TreadmillGain
--     .Pieces morceaux (« +0.4 Speed », un toutes les 0,2 s, même total, chacun vit Life s ; le « ×2 » en exposant
--     d'a178 reste), et le compteur Speed du HUD pulse à chaque morceau (Config/Hud.SpeedPulse, Motion.Pop).
--     a200 (décision de Cantin, 2026-11-15) : Config/Hud.TreadmillGain.ChunksPerSecond = 1 : de nouveau un seul
--     « +2 Speed/s » par seconde avec le gain entier (exposant « ×2 » gardé), et le compteur Speed pulse une fois
--     (SpeedPulse.Max) ; ChunksPerSecond = 5 rend les morceaux d'a190.
--     Vague 60 (a196, T-097) : sans Row.Multiplier, le « ×2 » du trail est un petit TextLabel (UiMotion.FloatGain
--     .TrailExponent) posé par le code au coin haut droit du nombre, dans Row.Amount ; Mode = "Unicode" : celui d'a178.
--   - Argent : quand l'attribut Cash du Player monte (DataService), Cash est retenu au HUD
--     (HudController.HoldCash) et le gain est classé à la fin de l'image (task.defer) :
--       * ramassage : l'attribut CashCollected du Player (DisplayService, il ne fait que monter) est
--         monté en même temps → « +$X » au-dessus du joueur (BB_Gain), et la case part de là ;
--       * récompense : l'écran UI_Rewards est ouvert (RewardsController.GetState().Open) → la case
--         part du centre de l'écran (UiMotion.CashFly.From) ;
--       * autre gain (camion…) : pas de case, le compteur sursaute seulement (CashBump).
--       * vague 59 (a192, L-184 point 3) : récompense (UI_Rewards ouvert) ou prime de l'index (un écran UI_Index*
--         allumé), jamais un ramassage, l'encaissement automatique ni les gains hors ligne : « +$X » qui monte au
--         centre, pause, billets qui volent vers Cash, qui ne défile qu'à leur arrivée (billFly, Config/HeistFeel
--         .BillFly ; avant le cas « récompense » ci-dessus). Le compteur n'a qu'un point d'entrée : HudController
--         (attribut Cash → son écriture qui défile, HoldCash pour retenir) ; GainController ne fait que retenir et
--         relâcher, la baisse après un achat (CashSpent) se fait là-bas aussi.
--     La case est une copie de UI_HUD.CashFly.Template de Clément (Icon, FlyerAmount = « $X »), rangée
--     à la racine de UI_HUD comme dans son prototype (tools/clement/gain_proto.luau) : elle surgit,
--     attend, puis vole jusqu'au nombre Cash en rapetissant (UiMotion.CashFly). À l'arrivée : Cash est
--     relâché et défile (Motion.Roll, HudController), CashRow sursaute (Motion.Pop, CashBump), une copie
--     de CashFly.CounterPop (« +$X ») apparaît à droite du nombre, puis monte et s'efface
--     (UiMotion.CounterPop), et le son CashFly.Sound part. Gains rapprochés : tant que la case attend
--     encore au départ, un nouveau gain s'y ajoute (montant cumulé) ; une seule copie de CounterPop à
--     la fois.
-- Gains hors ligne (vague 22, L-092 3f) : au Claim de l'écran UI_Offline (OfflineController.GetState().Open,
-- vrai jusqu'au versement), la case part du centre de l'écran, comme pour une récompense, avant même le
-- cas du ramassage (CashCollected monte aussi : le versement passe par DisplayService.AddOfflineEarnings).
-- Rien n'est laissé : chaque BB_Gain, case et « +$X » est une copie détruite à la fin de son
-- animation, et les modèles de Clément (BB_Gain, Template, CounterPop) ne sont jamais modifiés. Seuls
-- leur Text, Visible, Position, Adornee, StudsOffset et transparences changent, sur les copies.
-- Couleur de Row.Amount et image de Row.Icon (vague 24) : d'abord les attributs de Clément sur le
-- modèle BB_Gain (SpeedColor, PowerColor, CashColor en Color3 ; SpeedIcon, PowerIcon, CashIcon en
-- rbxassetid). S'ils manquent : la couleur de Config/UiMotion.FloatGain.Colors, et l'image de l'icône
-- de la ligne du HUD du même chiffre (SpeedRow, StrengthRow, CashRow : la première ImageLabel de la
-- ligne), sinon celle du modèle BB_Gain.
--
-- Vague 63 (a206, L-192 Q2) : « +$X/s » qui vole. Quand un objet arrive sur un présentoir (l'état de l'inventaire,
-- attribut InventoryState, lui donne un présentoir qu'il n'avait pas : posé à la main, par « Exposer les meilleurs »
-- ou depuis la réserve), son revenu « +$X/s » (Format.income) part de son modèle sur le présentoir (tag DisplayItem,
-- ItemUid, OwnerUserId ; attendu Config/Displayed.IncomeFly.ModelWait s, sinon au-dessus du joueur, sinon du centre
-- de l'écran) et vole jusqu'au nombre Cash du HUD : copie de UI_HUD.CashFly.GainPop de Clément, sinon de CounterPop,
-- sinon un texte vert simple fait ici ; à l'arrivée, CashRow sursaute et le son part (l'argent ne change pas). Un
-- seul vol par pose (première lecture de l'état : rien), plusieurs poses à la fois décalées de Stagger s, aucun
-- pendant une poursuite (ChaseController.IsChased) ni rattrapé après.
--
-- Vague 64 (a213, Cantin : « les gains de vitesse se déplacent vers lui ») : sur le tapis, le « +X Speed/s » de chaque
-- seconde (un seul, a200) jaillit du joueur dans UI_HUD, reste un instant, puis le nombre Speed du HUD l'aspire
-- (Config/Hud.TrainGainFly : 0,08 s, jet 0,33 s Quint Out, pause 0,7 s, aspiration 0,15 s Quad In jusqu'à × 0,3).
-- Le nombre reste à la valeur d'avant (HudController.HoldSpeed, base = Formulas.ShownSpeed de la Vitesse d'avant) et
-- monte à l'arrivée, avec la pulsation SpeedPulse. Copie de UI_HUD.TrainGainFly.Template de Clément (facultatif),
-- sinon de BB_Gain.Row dans un cadre fait ici ; « ×2 » du trail comme au-dessus du joueur. Animations réduites,
-- poursuite en cours, plafond MaxInFlight, joueur hors de l'écran ou Enabled = false : l'ancien « +X » sur place.
-- Avec ChunksPerSecond > 1, chaque morceau vole de même.
--
-- API (client) :
--   GainController.FlyGain(text, fromWorld, kind) -> boolean   vague 64 : un « +X » qui jaillit de `fromWorld` et vole
--       jusqu'au compteur du HUD de `kind` ("Speed"), qui pulse à l'arrivée (sans retenir son nombre : l'appelant ne
--       dit pas ce qu'il ajoute) ; false s'il n'a pas pu voler (animations réduites, poursuite, rien à l'écran…).
-- Pour un test dans Studio (barre de commande côté client) :
--   GainController.GetActive() -> { Gains: number, Flyers: number, Pops: number, Bills: number, IncomeFlies: number, TrainFlies: number }
--   GainController.Superscript(text) -> string   « ×2 » en exposant Unicode (a178)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiMotion = require(Shared:WaitForChild("Config"):WaitForChild("UiMotion"))
local HeistFeel = require(Shared:WaitForChild("Config"):WaitForChild("HeistFeel"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))
local Formulas = require(Shared:WaitForChild("Config"):WaitForChild("Formulas"))

-- Ce que ce contrôleur utilise de HudController et de RewardsController.
type HudApi = { HoldCash: (base: number) -> () -> (), HoldSpeed: ((base: number) -> () -> ())? }
type RewardsApi = { GetState: () -> { Open: boolean } }

type Kind = {
	Name: string,
	Attribute: string, -- attribut du Player qui monte
	Machine: string?, -- TrainingMachine requis (nil : argent)
	HudLabel: string, -- nombre du HUD dont la ligne donne l'icône
	Text: (amount: number) -> string,
}

type Burst = { pending: number, lastAt: number, scheduled: boolean }
type Rise = { amount: number, release: (() -> ())? }
type Flyer = { object: GuiObject, amount: number, releases: { () -> () }, leaving: boolean, label: TextLabel? }
type Fade = { object: Instance, property: string, from: number }

-- Contrat (L-091, livré par Clément le 2026-11-10 ; relevé de la vague 21).
local GAIN_TEMPLATE = "BB_Gain"
local HUD_SCREEN = "UI_HUD"
local CASH_FLY = "CashFly"
local CASH_LABEL = "Cash"
local CASH_ROW = "CashRow"
-- Attributs du Player (mêmes noms dans StatsService, TrainingService et DisplayService).
local MACHINE_ATTRIBUTE = "TrainingMachine"
local COLLECTED_ATTRIBUTE = "CashCollected"
local TRAIL_ATTRIBUTE = "TrailMultiplier" -- posé par StatsService (serveur), vague 47

local SPEED: Kind = {
	Name = "Speed",
	Attribute = "Speed",
	Machine = "Treadmill",
	HudLabel = "Speed",
	Text = function(amount: number): string
		return `+{Format.short(amount)} Speed/s` -- L-091 : « +2 Speed/s »
	end,
}
local CASH: Kind = {
	Name = "Cash",
	Attribute = "Cash",
	Machine = nil,
	HudLabel = "Cash",
	Text = function(amount: number): string
		return `+{Format.money(amount)}` -- L-091 : « +$… »
	end,
}

local FLOAT = UiMotion.FloatGain
local FLY = UiMotion.CashFly
local POP = UiMotion.CounterPop
local GAIN_POP_INFO = TweenInfo.new(FLOAT.PopTime, FLOAT.PopStyle, Enum.EasingDirection.Out)
local GAIN_RISE_INFO = TweenInfo.new(FLOAT.Time, FLOAT.Style, FLOAT.Direction)
local FLY_POP_INFO = TweenInfo.new(FLY.PopTime, FLY.PopStyle, Enum.EasingDirection.Out)
local FLY_INFO = TweenInfo.new(FLY.Time, FLY.Style, FLY.Direction)
local BUMP_INFO = TweenInfo.new(UiMotion.CashBump.Time, UiMotion.CashBump.Style, UiMotion.CashBump.Direction)
local COUNTER_POP_INFO = TweenInfo.new(POP.Time, POP.Style, POP.Direction)
local COUNTER_FADE_INFO = TweenInfo.new(POP.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Vague 59 (a190) : morceaux du tapis et pulsation du compteur Speed (Config/Hud, facultatif : bancs plus anciens).
local hudConfigModule = Shared:WaitForChild("Config"):FindFirstChild("Hud")
local HudConfig: any = if hudConfigModule and hudConfigModule:IsA("ModuleScript") then require(hudConfigModule) :: any else nil
local TREAD: any = if HudConfig then HudConfig.TreadmillGain else nil
-- a200 : morceaux par seconde (Config/Hud.TreadmillGain.ChunksPerSecond ; 1 sans Config/Hud).
local CHUNKS: number = if TREAD and type(TREAD.ChunksPerSecond) == "number"
	then math.max(1, math.floor(TREAD.ChunksPerSecond))
	else 1
local SPEED_PULSE: any = if HudConfig then HudConfig.SpeedPulse else nil
local PIECE_RISE_INFO: TweenInfo? = if TREAD then TweenInfo.new(TREAD.Life, FLOAT.Style, FLOAT.Direction) else nil
local PULSE_INFO: TweenInfo? = if SPEED_PULSE
	then TweenInfo.new(SPEED_PULSE.Time, SPEED_PULSE.Style, SPEED_PULSE.Direction)
	else nil
-- Vague 64 (a213) : gains du tapis qui volent jusqu'au compteur Speed (Config/Hud.TrainGainFly ; facultatif : bancs
-- plus anciens) ; réglage « animations réduites » (Config/Settings.VfxReduced).
local TRAIN_FLY: any = if HudConfig then HudConfig.TrainGainFly else nil
local settingsModule = Shared:WaitForChild("Config"):FindFirstChild("Settings")
local SettingsConfig: any = if settingsModule and settingsModule:IsA("ModuleScript") then require(settingsModule) :: any else nil
-- Vague 63 (a206) : « +$X/s » qui vole à chaque pose (Config/Displayed.IncomeFly ; facultatif : bancs plus anciens).
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local displayedModule = Shared:WaitForChild("Config"):FindFirstChild("Displayed")
local DisplayedConfig: any = if displayedModule and displayedModule:IsA("ModuleScript") then require(displayedModule) :: any else nil
local INCOME_FLY: any = if DisplayedConfig then DisplayedConfig.IncomeFly else nil
local DISPLAY_TAG = "DisplayItem" -- tag de code des objets exposés (DisplayService)
type ChaseApi = { IsChased: () -> boolean }

-- Vague 59 (a192) : gains ponctuels qui volent (Config/HeistFeel.BillFly).
local BILL = HeistFeel.BillFly
local BILL_RISE_INFO = TweenInfo.new(BILL.RiseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- V0
local BILL_FADE_INFO = TweenInfo.new(BILL.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BILL_FLY_INFO = TweenInfo.new(BILL.FlyTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
-- V0 proposé, absent du doc : nom des UIScale posés sur les copies (détruits avec elles).
local COPY_SCALE = "GainScale"

local IS_STUDIO = RunService:IsStudio()

local GainController = {}

-- a178 : « ×12 » → « ˣ¹² » (chiffres et × en exposant Unicode ; « . » → « · » ; tout autre caractère gardé).
local SUPERSCRIPT: { [string]: string } = {
	["×"] = "ˣ", ["0"] = "⁰", ["1"] = "¹", ["2"] = "²", ["3"] = "³", ["4"] = "⁴",
	["5"] = "⁵", ["6"] = "⁶", ["7"] = "⁷", ["8"] = "⁸", ["9"] = "⁹", ["."] = "·",
}
function GainController.Superscript(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		table.insert(out, SUPERSCRIPT[char] or char)
	end
	return table.concat(out)
end

local localPlayer = Players.LocalPlayer
local random = Random.new()
local hud: HudApi? = nil
local rewards: RewardsApi? = nil
local offline: RewardsApi? = nil -- OfflineController : même GetState().Open
local bursts: { [Kind]: Burst } = {}
local lastValues: { [string]: number } = {}
local rises: { Rise } = {}
local collected = 0
local classifyQueued = false
local flyer: Flyer? = nil -- case qui attend encore au départ (un nouveau gain s'y ajoute)
local counterPop: GuiObject? = nil
-- Bills : gains ponctuels en vol (vague 59) ; IncomeFlies : « +$X/s » d'une pose en vol (vague 63)
local active = { Gains = 0, Flyers = 0, Pops = 0, Bills = 0, IncomeFlies = 0, TrainFlies = 0 }
local chase: ChaseApi? = nil
local placed: { [string]: boolean }? = nil -- vague 63 : uids exposés à la dernière lecture (nil : pas encore lu)
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(message)
	end
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

local function playerGui(): PlayerGui?
	return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function hudScreen(): ScreenGui?
	local gui = playerGui()
	local screen = if gui then gui:FindFirstChild(HUD_SCREEN) else nil
	return if screen and screen:IsA("ScreenGui") then screen :: ScreenGui else nil
end

local function typed(root: Instance?, path: string, class: string): any
	if root == nil then
		return nil
	end
	local found = Find.path(root, path)
	return if found and found:IsA(class) then found else nil
end

-- Image de l'icône de la ligne du HUD qui porte le nombre `labelName` (SpeedRow/SpeedIcon…), ou nil.
local function hudIcon(labelName: string): string?
	local screen = hudScreen()
	local label = typed(screen, labelName, "TextLabel") :: TextLabel?
	local row = if label then label.Parent else nil
	if row == nil or row:IsA("ScreenGui") then
		return nil
	end
	for _, child in row:GetDescendants() do
		if child:IsA("ImageLabel") and (child :: ImageLabel).Image ~= "" then
			return (child :: ImageLabel).Image
		end
	end
	return nil
end

local function rootPart(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root :: BasePart else nil
end

------------------------------------------------------------------------------
-- Gain au-dessus du joueur (FloatGain)
------------------------------------------------------------------------------

-- a196 : largeur relative de `text` dans la police de `label` (TextService, taille 100) ; sans TextService ou
-- police inconnue : le nombre de caractères.
local function textWidth(label: TextLabel, text: string): number
	local ok, width = pcall(function(): number
		local font = label.Font
		assert(font ~= Enum.Font.Unknown)
		local service = game:GetService("TextService") :: TextService
		return service:GetTextSize(text, 100, font, Vector2.new(1e5, 1e5)).X
	end)
	if ok and type(width) == "number" and width > 0 then
		return width
	end
	return (utf8.len(text) or #text) * 50
end

-- a196 (Cantin, T-097) : « ×2 » en exposant au coin haut droit du nombre `head` de Row.Amount : un petit TextLabel
-- (FloatGain.TrailExponent) dans `amountLabel`, replacé quand le texte prend sa taille (TextBounds). Le texte de
-- Row.Amount reçoit des espaces à la place de l'exposant. Renvoie le TextLabel créé.
local function addExponent(amountLabel: TextLabel, head: string, tail: string, trailText: string): TextLabel
	local spec = FLOAT.TrailExponent
	local space = textWidth(amountLabel, " ")
	local gap = math.clamp(math.ceil(textWidth(amountLabel, trailText) * spec.Size / math.max(space, 1)), 1, 8)
	amountLabel.Text = head .. string.rep(" ", gap) .. tail
	local label = Instance.new("TextLabel")
	label.Name = spec.Name
	label.BackgroundTransparency = 1
	label.Text = trailText
	label.TextColor3 = FLOAT.TrailMultiplierColor
	label.FontFace = amountLabel.FontFace
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTransparency = amountLabel.TextTransparency
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.ZIndex = amountLabel.ZIndex + 1
	local stroke = amountLabel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke:Clone().Parent = label
	end
	local ratio = textWidth(amountLabel, head) / math.max(textWidth(amountLabel, amountLabel.Text), 1)
	local function layout()
		local size = amountLabel.AbsoluteSize
		local bounds = amountLabel.TextBounds
		if size.X <= 0 or size.Y <= 0 then
			size = Vector2.new(100, 100) -- pas encore à l'écran : en proportions seulement
			bounds = size
		elseif bounds.X <= 0 or bounds.Y <= 0 then
			bounds = size -- avant le premier rendu : le texte remplit le cadre (TextScaled)
		end
		local alignX = amountLabel.TextXAlignment
		local left = if alignX == Enum.TextXAlignment.Left
			then 0
			elseif alignX == Enum.TextXAlignment.Right then size.X - bounds.X
			else (size.X - bounds.X) / 2
		local alignY = amountLabel.TextYAlignment
		local top = if alignY == Enum.TextYAlignment.Top
			then 0
			elseif alignY == Enum.TextYAlignment.Bottom then size.Y - bounds.Y
			else (size.Y - bounds.Y) / 2
		local height = spec.Size * bounds.Y
		label.Position = UDim2.fromScale((left + ratio * bounds.X) / size.X, (top + spec.Raise * bounds.Y) / size.Y)
		label.Size = UDim2.fromScale(height * 3 / size.X, height / size.Y)
	end
	layout()
	pcall(function() -- liens coupés quand la copie du billboard est détruite
		amountLabel:GetPropertyChangedSignal("TextBounds"):Connect(layout)
		amountLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	end)
	label.Parent = amountLabel
	return label
end

-- Habille une copie (BB_Gain, sa Row, ou UI_HUD.TrainGainFly.Template de la vague 64) : texte, couleur, icône et « ×2 »
-- du trail. `source` est le modèle qui porte les attributs <Sorte>Color et <Sorte>Icon de Clément.
type Dressed = { amount: TextLabel?, icon: ImageLabel?, multiplier: TextLabel?, exponent: TextLabel? }
local function dressGain(copy: Instance, source: Instance, kind: Kind, amount: number, text: string?): Dressed
	local amountLabel = typed(copy, "Amount", "TextLabel") :: TextLabel?
	local icon = typed(copy, "Icon", "ImageLabel") :: ImageLabel?
	local multiplierLabel = typed(copy, "Multiplier", "TextLabel") :: TextLabel?
	-- Vague 47 (a155) : multiplicateur du trail (Speed seulement), même format que la boutique (« ×2 »).
	local trailText: string? = nil
	if kind == SPEED then
		local trail = localPlayer:GetAttribute(TRAIL_ATTRIBUTE)
		if type(trail) == "number" and trail == trail and trail > 1 and trail < math.huge then
			trailText = `×{string.format("%g", trail)}`
		end
	end
	if multiplierLabel then
		multiplierLabel.Text = trailText or ""
		multiplierLabel.Visible = trailText ~= nil
	end
	local exponentLabel: TextLabel? = nil -- a196 : le « ×2 » du code, sans Row.Multiplier
	-- L-092 3e : un seul BB_Gain ; la copie dit sa sorte (GainKind) et Amount prend sa couleur.
	copy:SetAttribute(FLOAT.KindAttribute, kind.Name)
	if amountLabel then
		amountLabel.Text = text or kind.Text(amount)
		-- Vague 24 : la couleur posée par Clément sur BB_Gain (attribut <Sorte>Color, Color3) passe
		-- avant celle de Config/UiMotion.FloatGain.Colors.
		local attributeColor = source:GetAttribute(`{kind.Name}Color`)
		local color: Color3? = if typeof(attributeColor) == "Color3"
			then attributeColor
			else (FLOAT.Colors :: { [string]: Color3 })[kind.Name]
		if color then
			amountLabel.TextColor3 = color
		end
		if trailText and multiplierLabel == nil then
			local text = amountLabel.Text
			local cut = string.find(text, " ", 1, true) or (#text + 1)
			-- a196 (Cantin, T-097) : plus haut, au coin haut droit du nombre (petit TextLabel du code) ; en cas
			-- d'erreur, l'exposant Unicode d'a178.
			local ok: boolean, made: any = false, nil
			if FLOAT.TrailExponent.Mode == "Label" then
				ok, made = pcall(addExponent, amountLabel, string.sub(text, 1, cut - 1), string.sub(text, cut), trailText)
			end
			if ok then
				exponentLabel = made
			else
				-- a178 (Cantin, 15/11) : en exposant, juste après le nombre (« +1ˣ² Speed/s »), en caractères
				-- Unicode en exposant (un BillboardGui ne sait pas monter un texte au-dessus de la ligne).
				amountLabel.RichText = true
				local hex = (FLOAT.TrailMultiplierColor :: Color3):ToHex()
				local sup = `<font color="#{hex}">{GainController.Superscript(trailText)}</font>`
				amountLabel.Text = string.sub(text, 1, cut - 1) .. sup .. string.sub(text, cut)
			end
		end
	end
	-- Vague 24 : l'icône posée par Clément sur BB_Gain (attribut <Sorte>Icon, rbxassetid) passe avant
	-- celle de la ligne du HUD.
	local attributeIcon = source:GetAttribute(`{kind.Name}Icon`)
	local image: string? = if type(attributeIcon) == "string" and attributeIcon ~= ""
		then attributeIcon
		else hudIcon(kind.HudLabel)
	if icon and image then
		icon.Image = image
	end
	return { amount = amountLabel, icon = icon, multiplier = multiplierLabel, exponent = exponentLabel }
end

-- `info` et `text` (vague 59, morceaux du tapis) : une autre montée et un autre texte que FloatGain et kind.Text.
local function floatGain(kind: Kind, amount: number, info: TweenInfo?, text: string?)
	local root = rootPart()
	local gui = playerGui()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("UI") else nil
	local template = if folder then folder:FindFirstChild(GAIN_TEMPLATE) else nil
	if template == nil or not template:IsA("BillboardGui") then
		warnOnce("template", `[Gains] ReplicatedStorage/Assets/UI/{GAIN_TEMPLATE} absent : pas de gain au-dessus du joueur`)
		return
	end
	if root == nil or gui == nil then
		return
	end
	local billboard = (template :: BillboardGui):Clone()
	local row = typed(billboard, "Row", "GuiObject") :: GuiObject?
	local dressed = dressGain(billboard, template, kind, amount, text)
	local amountLabel, icon, multiplierLabel, exponentLabel = dressed.amount, dressed.icon, dressed.multiplier, dressed.exponent
	local base = billboard.StudsOffset
	if base.Magnitude < 1e-3 then
		base = Vector3.new(0, FLOAT.Height, 0)
	end
	local spread = (random:NextNumber() * 2 - 1) * FLOAT.SpreadX
	billboard.Adornee = root
	billboard.StudsOffset = base + Vector3.new(spread, 0, 0)

	-- Ce qui s'efface : le texte, l'icône et leurs contours, depuis leur transparence d'origine.
	local fades: { Fade } = {}
	if amountLabel then
		table.insert(fades, { object = amountLabel :: Instance, property = "TextTransparency", from = amountLabel.TextTransparency })
	end
	if icon then
		table.insert(fades, { object = icon :: Instance, property = "ImageTransparency", from = icon.ImageTransparency })
	end
	if multiplierLabel then
		table.insert(fades, { object = multiplierLabel :: Instance, property = "TextTransparency", from = multiplierLabel.TextTransparency })
	end
	if exponentLabel then
		table.insert(fades, { object = exponentLabel :: Instance, property = "TextTransparency", from = exponentLabel.TextTransparency })
	end
	for _, descendant in billboard:GetDescendants() do
		if descendant:IsA("UIStroke") then
			table.insert(fades, { object = descendant :: Instance, property = "Transparency", from = (descendant :: UIStroke).Transparency })
		end
	end

	billboard.Parent = gui
	active.Gains += 1
	if row then
		local scale = Instance.new("UIScale")
		scale.Name = COPY_SCALE
		scale.Scale = FLOAT.PopFrom
		scale.Parent = row
		TweenService:Create(scale, GAIN_POP_INFO, { Scale = 1 }):Play()
	end
	local progress = Instance.new("NumberValue")
	progress.Value = 0
	progress:GetPropertyChangedSignal("Value"):Connect(function()
		local a = progress.Value
		billboard.StudsOffset = base + Vector3.new(spread, FLOAT.Rise * a, 0)
		local fade = math.clamp((a - FLOAT.FadeAt) / (1 - FLOAT.FadeAt), 0, 1)
		for _, item in fades do
			(item.object :: any)[item.property] = item.from + (1 - item.from) * fade
		end
	end)
	local rise = TweenService:Create(progress, info or GAIN_RISE_INFO, { Value = 1 })
	rise.Completed:Connect(function()
		active.Gains -= 1
		billboard:Destroy()
		progress:Destroy()
	end)
	rise:Play()
end

-- Un BB_Gain au plus par FloatGain.MinGap s et par sorte : les gains entre deux s'additionnent.
local function showGain(kind: Kind, amount: number)
	local burst = bursts[kind]
	if burst == nil then
		burst = { pending = 0, lastAt = -math.huge, scheduled = false }
		bursts[kind] = burst
	end
	local current: Burst = burst
	current.pending += amount
	if current.scheduled then
		return
	end
	local function flush()
		current.scheduled = false
		local total = current.pending
		current.pending = 0
		current.lastAt = os.clock()
		if total > 0 then
			floatGain(kind, total) -- sans son : Train_Gain retiré (L-118 point 7)
		end
	end
	local wait = current.lastAt + (if kind == CASH then FLOAT.CashMinGap else FLOAT.MinGap) - os.clock()
	if wait <= 0 then
		flush()
	else
		current.scheduled = true
		task.delay(wait, flush)
	end
end

------------------------------------------------------------------------------
-- Case qui vole vers l'argent (CashFly, CashBump, CounterPop)
------------------------------------------------------------------------------

type HudRefs = { screen: ScreenGui, label: TextLabel, row: GuiObject, fly: Instance? }

local function hudRefs(): HudRefs?
	local screen = hudScreen()
	local label = typed(screen, CASH_LABEL, "TextLabel") :: TextLabel?
	if screen == nil or label == nil then
		return nil
	end
	local row: GuiObject = label
	local ancestor = label:FindFirstAncestor(CASH_ROW)
	if ancestor and ancestor:IsA("GuiObject") then
		row = ancestor :: GuiObject
	end
	return { screen = screen, label = label, row = row, fly = Find.path(screen, CASH_FLY) }
end

local function bump(refs: HudRefs?)
	if refs then
		Motion.Pop(refs.row, UiMotion.CashBump.From, BUMP_INFO)
	end
end

local function releaseAll(releases: { () -> () })
	for _, release in releases do
		release()
	end
end

-- « +$X » à droite du nombre Cash : une copie de CashFly.CounterPop (une seule à la fois).
local function showCounterPop(refs: HudRefs, amount: number)
	local template = typed(refs.fly, "CounterPop", "TextLabel") :: TextLabel?
	if template == nil then
		return
	end
	local previous = counterPop
	if previous then
		counterPop = nil
		active.Pops -= 1
		previous:Destroy()
	end
	local pop = template:Clone()
	pop.Text = CASH.Text(amount)
	pop.Visible = true
	local label = refs.label
	local origin = refs.screen.AbsolutePosition
	pop.Position = UDim2.fromOffset(
		label.AbsolutePosition.X - origin.X + label.TextBounds.X + POP.OffsetX,
		label.AbsolutePosition.Y - origin.Y + label.AbsoluteSize.Y / 2
	)
	local scale = Instance.new("UIScale")
	scale.Name = COPY_SCALE
	scale.Scale = POP.From
	scale.Parent = pop
	pop.Parent = refs.screen
	counterPop = pop
	active.Pops += 1
	TweenService:Create(scale, COUNTER_POP_INFO, { Scale = 1 }):Play()
	task.delay(POP.Time + POP.Hold, function()
		if counterPop ~= pop then
			return -- remplacée entre-temps
		end
		local fade = TweenService:Create(pop, COUNTER_FADE_INFO, {
			TextTransparency = 1,
			Position = pop.Position - UDim2.fromOffset(0, POP.Rise),
		})
		for _, descendant in pop:GetDescendants() do
			if descendant:IsA("UIStroke") then
				TweenService:Create(descendant, COUNTER_FADE_INFO, { Transparency = 1 }):Play()
			end
		end
		fade.Completed:Connect(function()
			if counterPop == pop then
				counterPop = nil
				active.Pops -= 1
			end
			pop:Destroy()
		end)
		fade:Play()
	end)
end

local function arrive(amount: number, releases: { () -> () })
	releaseAll(releases) -- Cash défile (HudController)
	local refs = hudRefs()
	if refs == nil then
		return
	end
	bump(refs)
	showCounterPop(refs, amount)
	Motion.PlaySound(FLY.Sound)
end

-- Point de départ (pixels, repère de UI_HUD) : au-dessus du joueur, ou nil s'il n'est pas à l'écran.
local function worldStart(refs: HudRefs): Vector2?
	local root = rootPart()
	local camera = Workspace.CurrentCamera
	if root == nil or camera == nil then
		return nil
	end
	local point = root.Position + Vector3.new(0, FLOAT.Height, 0)
	local screenPoint, onScreen
	if refs.screen.IgnoreGuiInset then
		screenPoint, onScreen = camera:WorldToViewportPoint(point)
	else
		screenPoint, onScreen = camera:WorldToScreenPoint(point)
	end
	if not onScreen then
		return nil
	end
	local origin = refs.screen.AbsolutePosition
	return Vector2.new(screenPoint.X - origin.X, screenPoint.Y - origin.Y)
end

local function fly(amount: number, releases: { () -> () }, fromPlayer: boolean)
	local waiting = flyer
	if waiting and not waiting.leaving and waiting.object.Parent ~= nil then
		-- Gain rapproché : il s'ajoute à la case qui attend encore. Sa retenue tombe : celle de la
		-- case (la plus ancienne) garde l'argent d'avant les deux gains jusqu'à l'arrivée.
		waiting.amount += amount
		if waiting.label then
			waiting.label.Text = Format.money(waiting.amount)
		end
		releaseAll(releases)
		return
	end
	local refs = hudRefs()
	local template = if refs then typed(refs.fly, "Template", "GuiObject") :: GuiObject? else nil
	if refs == nil or template == nil then
		warnOnce("flyer", `[Gains] UI_HUD.{CASH_FLY}.Template absent : l'argent défile sans case qui vole`)
		releaseAll(releases)
		bump(refs)
		return
	end
	local copy = template:Clone()
	local label = typed(copy, "FlyerAmount", "TextLabel") :: TextLabel?
	if label then
		label.Text = Format.money(amount)
	end
	local start = if fromPlayer then worldStart(refs) else nil
	copy.Position = if start then UDim2.fromOffset(start.X, start.Y) else UDim2.fromScale(FLY.From.X, FLY.From.Y)
	copy.Visible = true
	local scale = Instance.new("UIScale")
	scale.Name = COPY_SCALE
	scale.Scale = 0
	scale.Parent = copy
	copy.Parent = refs.screen
	local current: Flyer = { object = copy, amount = amount, releases = table.clone(releases), leaving = false, label = label }
	flyer = current
	active.Flyers += 1
	TweenService:Create(scale, FLY_POP_INFO, { Scale = FLY.PopTo }):Play()
	task.delay(FLY.PopTime + FLY.Hold, function()
		current.leaving = true
		if flyer == current then
			flyer = nil
		end
		local now = hudRefs()
		if now == nil or copy.Parent == nil then
			active.Flyers -= 1
			copy:Destroy()
			arrive(current.amount, current.releases)
			return
		end
		local target = now.label
		local origin = now.screen.AbsolutePosition
		local goal = UDim2.fromOffset(
			target.AbsolutePosition.X - origin.X + FLY.TargetOffsetX,
			target.AbsolutePosition.Y - origin.Y + target.AbsoluteSize.Y / 2
		)
		local move = TweenService:Create(copy, FLY_INFO, { Position = goal })
		TweenService:Create(scale, FLY_INFO, { Scale = FLY.EndScale }):Play()
		move.Completed:Connect(function()
			active.Flyers -= 1
			copy:Destroy()
			arrive(current.amount, current.releases)
		end)
		move:Play()
	end)
end

------------------------------------------------------------------------------
-- Sources des gains
------------------------------------------------------------------------------

-- L'écran de `api` (RewardsController, OfflineController) est ouvert.
local function screenOpen(api: RewardsApi?): boolean
	if api == nil then
		return false
	end
	local ok, state = pcall(api.GetState)
	return ok and type(state) == "table" and state.Open == true
end

-- Vague 59 : un écran de l'index (UI_Index, UI_Index_v3…) est allumé (réclamation d'une prime de zone).
local function indexOpen(): boolean
	local gui = playerGui()
	if gui == nil then
		return false
	end
	local prefix = BILL.IndexPrefix
	for _, child in gui:GetChildren() do
		if child:IsA("ScreenGui") and string.sub(child.Name, 1, #prefix) == prefix and (child :: ScreenGui).Enabled then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Gains ponctuels qui volent (vague 59, a192, L-184 point 3)
------------------------------------------------------------------------------

-- « +$X » qui monte au centre (BillFly.RiseTime), courte pause, puis BillFly.Bills billets qui volent vers le
-- nombre Cash (FlyTime, décalés de Stagger) ; à l'arrivée du premier : Cash relâché (il défile, HudController),
-- sursaut, « +$X » à côté du compteur et un seul son (arrive). Éléments facultatifs de UI_HUD.CashFly proposés à
-- Clément : GainPop (TextLabel du « +$X ») et Bill (le billet) ; sans eux, CounterPop et Template de CashFly ; sans
-- rien : l'argent défile tout de suite et le compteur sursaute (comme avant).
local function billFly(amount: number, releases: { () -> () })
	local refs = hudRefs()
	local billTemplate = if refs then (typed(refs.fly, "Bill", "GuiObject") or typed(refs.fly, "Template", "GuiObject")) :: GuiObject? else nil
	local popTemplate = if refs then (typed(refs.fly, "GainPop", "TextLabel") or typed(refs.fly, "CounterPop", "TextLabel")) :: TextLabel? else nil
	if refs == nil or (billTemplate == nil and popTemplate == nil) then
		warnOnce("bill", `[Gains] UI_HUD.{CASH_FLY} (Bill, GainPop) absent : l'argent défile sans billets qui volent`)
		releaseAll(releases)
		bump(refs)
		return
	end
	local screen = refs.screen
	local size = screen.AbsoluteSize
	local start = Vector2.new(size.X * BILL.From.X, size.Y * BILL.From.Y)
	active.Bills += 1
	local pop: TextLabel? = nil
	if popTemplate then
		local copy = popTemplate:Clone()
		copy.Text = CASH.Text(amount)
		copy.Visible = true
		copy.AnchorPoint = Vector2.new(0.5, 0.5)
		copy.Position = UDim2.fromOffset(start.X, start.Y)
		copy.Parent = screen
		pop = copy
		TweenService:Create(copy, BILL_RISE_INFO, { Position = UDim2.fromOffset(start.X, start.Y - BILL.Rise) }):Play()
	end
	task.delay(BILL.RiseTime + BILL.Pause, function()
		local label = pop
		if label then
			local fade = TweenService:Create(label, BILL_FADE_INFO, { TextTransparency = 1 })
			fade.Completed:Connect(function()
				label:Destroy()
			end)
			fade:Play()
		end
		local arrived = false
		local function land()
			if not arrived then
				arrived = true
				active.Bills -= 1
				arrive(amount, releases)
			end
		end
		local now = hudRefs()
		if now == nil or billTemplate == nil then
			task.delay(BILL.FlyTime, land)
			return
		end
		local target = now.label
		local origin = now.screen.AbsolutePosition
		local goal = UDim2.fromOffset(
			target.AbsolutePosition.X - origin.X + BILL.TargetOffsetX,
			target.AbsolutePosition.Y - origin.Y + target.AbsoluteSize.Y / 2
		)
		local from = Vector2.new(start.X, start.Y - BILL.Rise)
		local template = billTemplate :: GuiObject -- non nil : vérifié plus haut
		for i = 1, BILL.Bills do
			task.delay((i - 1) * BILL.Stagger, function()
				local bill = template:Clone()
				bill.Visible = true
				bill.AnchorPoint = Vector2.new(0.5, 0.5)
				bill.Position = UDim2.fromOffset(
					from.X + (random:NextNumber() * 2 - 1) * BILL.Spread,
					from.Y + (random:NextNumber() * 2 - 1) * BILL.Spread / 2
				)
				local scale = Instance.new("UIScale")
				scale.Name = COPY_SCALE
				scale.Parent = bill
				bill.Parent = now.screen
				TweenService:Create(scale, BILL_FLY_INFO, { Scale = BILL.EndScale }):Play()
				local move = TweenService:Create(bill, BILL_FLY_INFO, { Position = goal })
				move.Completed:Connect(function()
					bill:Destroy()
					land()
				end)
				move:Play()
			end)
		end
	end)
end

------------------------------------------------------------------------------
-- « +$X/s » qui vole à chaque pose (vague 63, a206, L-192 Q2)
------------------------------------------------------------------------------

local function isChased(): boolean
	local api = chase
	if api == nil then
		return false
	end
	local ok, result = pcall(api.IsChased)
	return ok and result == true
end

-- Modèle de l'objet `uid` exposé chez le joueur local (tag DisplayItem de DisplayService), ou nil.
local function displayModel(uid: string): Instance?
	for _, model in CollectionService:GetTagged(DISPLAY_TAG) do
		if model:GetAttribute("ItemUid") == uid and model:GetAttribute("OwnerUserId") == localPlayer.UserId then
			return model
		end
	end
	return nil
end

-- Point du monde → pixels du repère de `screen`, ou nil s'il n'est pas à l'écran.
local function projectTo(screen: ScreenGui, point: Vector3): Vector2?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local screenPoint, onScreen
	if screen.IgnoreGuiInset then
		screenPoint, onScreen = camera:WorldToViewportPoint(point)
	else
		screenPoint, onScreen = camera:WorldToScreenPoint(point)
	end
	if not onScreen then
		return nil
	end
	local origin = screen.AbsolutePosition
	return Vector2.new(screenPoint.X - origin.X, screenPoint.Y - origin.Y)
end

-- Point du monde → pixels du repère de UI_HUD, ou nil s'il n'est pas à l'écran.
local function toScreen(refs: HudRefs, point: Vector3): Vector2?
	return projectTo(refs.screen, point)
end

-- Le texte qui vole : copie de CashFly.GainPop, sinon de CashFly.CounterPop, sinon un texte vert simple.
local function incomeLabel(refs: HudRefs): TextLabel
	local template = (typed(refs.fly, "GainPop", "TextLabel") or typed(refs.fly, "CounterPop", "TextLabel")) :: TextLabel?
	if template then
		return template:Clone()
	end
	warnOnce("incomeFly", `[Gains] UI_HUD.{CASH_FLY}.GainPop absent : « +$/s » qui vole en texte simple`)
	local label = Instance.new("TextLabel")
	label.Name = "IncomeFly"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(160, 36)
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.TextScaled = true
	label.TextColor3 = INCOME_FLY.Color
	label.TextStrokeTransparency = 0
	return label
end

local function incomeFly(uid: string, income: number)
	local spec = INCOME_FLY
	local refs = hudRefs()
	if spec == nil or refs == nil then
		return
	end
	active.IncomeFlies += 1
	task.spawn(function()
		-- Départ : le modèle posé (il arrive juste après l'état de l'inventaire), sinon le joueur, sinon le centre.
		local model = displayModel(uid)
		local waited = 0
		while model == nil and waited < spec.ModelWait do
			task.wait(0.1)
			waited += 0.1
			model = displayModel(uid)
		end
		local now = hudRefs()
		if now == nil then
			active.IncomeFlies -= 1
			return
		end
		local start: Vector2? = nil
		if model and model:IsA("Model") then
			start = toScreen(now, (model :: Model):GetPivot().Position + Vector3.new(0, spec.Lift, 0))
		end
		start = start or worldStart(now)
		local size = now.screen.AbsoluteSize
		local from = start or Vector2.new(size.X * FLY.From.X, size.Y * FLY.From.Y)
		local label = incomeLabel(now)
		label.Text = Format.income(income)
		label.Visible = true
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromOffset(from.X, from.Y)
		local scale = Instance.new("UIScale")
		scale.Name = COPY_SCALE
		scale.Scale = spec.PopFrom
		scale.Parent = label
		label.Parent = now.screen
		TweenService:Create(scale, TweenInfo.new(spec.PopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.wait(spec.PopTime + spec.Hold)
		local target = hudRefs()
		if target == nil or label.Parent == nil then
			active.IncomeFlies -= 1
			label:Destroy()
			return
		end
		local cash = target.label
		local origin = target.screen.AbsolutePosition
		local goal = UDim2.fromOffset(
			cash.AbsolutePosition.X - origin.X + spec.TargetOffsetX,
			cash.AbsolutePosition.Y - origin.Y + cash.AbsoluteSize.Y / 2
		)
		local info = TweenInfo.new(spec.FlyTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(scale, info, { Scale = spec.EndScale }):Play()
		local move = TweenService:Create(label, info, { Position = goal })
		move.Completed:Connect(function()
			active.IncomeFlies -= 1
			label:Destroy()
			bump(hudRefs())
			Motion.PlaySound(spec.Sound)
		end)
		move:Play()
	end)
end

-- L'état de l'inventaire a changé : chaque objet qui vient d'arriver sur un présentoir fait voler son revenu.
local function onInventory()
	local text = localPlayer:GetAttribute(InventoryState.Attribute)
	if type(text) ~= "string" then
		return
	end
	local now: { [string]: boolean } = {}
	local arrived: { InventoryState.ItemEntry } = {}
	local before = placed
	for _, entry in InventoryState.Decode(text).Items do
		if entry.Slot ~= nil then
			now[entry.Uid] = true
			if before and not before[entry.Uid] then
				table.insert(arrived, entry)
			end
		end
	end
	placed = now
	if #arrived == 0 or INCOME_FLY == nil or isChased() then
		return
	end
	table.sort(arrived, function(a: InventoryState.ItemEntry, b: InventoryState.ItemEntry): boolean
		return (a.Slot or 0) < (b.Slot or 0)
	end)
	for index, entry in arrived do
		local uid, income = entry.Uid, entry.Income
		if index == 1 then
			incomeFly(uid, income)
		else
			task.delay((index - 1) * INCOME_FLY.Stagger, function()
				if not isChased() then
					incomeFly(uid, income)
				end
			end)
		end
	end
end

-- Fin d'image : les montées de Cash de l'image sont classées ensemble (voir l'en-tête).
local function classify()
	classifyQueued = false
	local list = rises
	rises = {}
	local fromPad = collected > 0
	collected = 0
	if #list == 0 then
		return
	end
	local total = 0
	local releases: { () -> () } = {}
	for _, rise in list do
		total += rise.amount
		if rise.release then
			table.insert(releases, rise.release)
		end
	end
	-- Vague 59 (L-184 point 3) : récompense ou prime de l'index, jamais un revenu de la base (plaque, encaissement
	-- automatique : CashCollected monte aussi ; gains hors ligne) : billets qui volent, avec ou sans FLY.Enabled.
	if not fromPad and not screenOpen(offline) and (screenOpen(rewards) or indexOpen()) then
		billFly(total, releases)
		return
	end
	if not FLY.Enabled then
		-- Sans case qui vole (L-091, retour de Clément) : l'argent défile tout de suite, le compteur sursaute,
		-- et un ramassage, des gains hors ligne réclamés ou une récompense montrent « +$X » au-dessus du joueur.
		releaseAll(releases)
		bump(hudRefs())
		if fromPad then
			Motion.PlaySound(FLY.Sound) -- L-117 point 4 : Cash_Collect à chaque ramassage, même sans case
		end
		if fromPad or screenOpen(offline) or screenOpen(rewards) then
			showGain(CASH, total)
		end
		return
	end
	if screenOpen(offline) then
		fly(total, releases, false) -- gains hors ligne réclamés : du centre de l'écran
	elseif fromPad then
		showGain(CASH, total)
		fly(total, releases, true)
	elseif screenOpen(rewards) then
		fly(total, releases, false)
	else
		releaseAll(releases)
		bump(hudRefs())
	end
end

local function queueClassify()
	if not classifyQueued then
		classifyQueued = true
		task.defer(classify)
	end
end

-- Hausse d'un attribut numérique du Player depuis la dernière valeur vue (0 au premier passage).
local function riseOf(attribute: string): (number, number?)
	local value = localPlayer:GetAttribute(attribute)
	local previous = lastValues[attribute]
	if type(value) ~= "number" or value ~= value then
		lastValues[attribute] = nil
		return 0, nil
	end
	lastValues[attribute] = value
	if previous == nil or value <= previous then
		return 0, previous
	end
	return value - previous, previous
end

-- Vague 59 (a190, L-182 point 8) : le compteur Speed du HUD (SpeedRow s'il existe) pulse au morceau `rank`.
local function pulseSpeed(rank: number, pieces: number)
	local pulse = SPEED_PULSE
	local info: TweenInfo? = PULSE_INFO
	local label = typed(hudScreen(), SPEED.HudLabel, "TextLabel") :: TextLabel?
	if pulse == nil or info == nil or label == nil then
		return
	end
	local target: GuiObject = label
	local row = label:FindFirstAncestor(pulse.Row)
	if row and row:IsA("GuiObject") then
		target = row :: GuiObject
	end
	local t = if pieces > 1 then (rank - 1) / (pieces - 1) else 1
	Motion.Pop(target, pulse.Min + (pulse.Max - pulse.Min) * t, info)
end

------------------------------------------------------------------------------
-- Gains du tapis qui volent jusqu'au compteur Speed (vague 64, a213 ; Config/Hud.TrainGainFly)
------------------------------------------------------------------------------

-- Animations réduites : VISUAL EFFECTS sur OFF (Settings.VfxReduced) ou « Réduire les mouvements » de Roblox.
local function reducedMotion(): boolean
	local settings = SettingsConfig
	if settings and type(settings.VfxReduced) == "function" then
		local ok, reduced = pcall(settings.VfxReduced, localPlayer)
		if ok and reduced == true then
			return true
		end
	end
	local ok, value = pcall(function(): any
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- Un gain peut voler maintenant ; sinon (réglage coupé, animations réduites, poursuite, plafond atteint) : l'ancien
-- « +X » qui monte sur place. Pendant une poursuite, rien ne traverse l'écran (lecture du danger d'abord).
local function canFly(): boolean
	local spec = TRAIN_FLY
	return spec ~= nil
		and spec.Enabled == true
		and active.TrainFlies < spec.MaxInFlight
		and not reducedMotion()
		and not isChased()
end

-- La copie qui vole : le modèle facultatif de Clément (UI_HUD.TrainGainFly.Template), sinon une copie de BB_Gain.Row
-- dans un cadre transparent fait ici ; renvoie aussi le modèle qui porte les attributs <Sorte>Color et <Sorte>Icon.
local function makeFlyer(screen: ScreenGui): (GuiObject?, Instance?)
	local spec = TRAIN_FLY
	local template = typed(screen, spec.Template, "GuiObject") :: GuiObject?
	if template then
		local copy = template:Clone()
		copy.Name = spec.Name
		copy.Visible = true
		return copy, template
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("UI") else nil
	local billboard = if folder then folder:FindFirstChild(GAIN_TEMPLATE) else nil
	local row = if billboard then typed(billboard, "Row", "GuiObject") :: GuiObject? else nil
	if billboard == nil or row == nil then
		return nil, nil
	end
	local height = screen.AbsoluteSize.Y * spec.Height
	local holder = Instance.new("Frame")
	holder.Name = spec.Name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(height * spec.Aspect, height)
	holder.ZIndex = spec.ZIndex
	local copy = row:Clone()
	copy.AnchorPoint = Vector2.new(0, 0)
	copy.Position = UDim2.fromScale(0, 0)
	copy.Size = UDim2.fromScale(1, 1)
	copy.Visible = true
	copy.Parent = holder
	return holder, billboard
end

-- Le « +X » jaillit de `fromWorld` (au-dessus du joueur sans lui) : taille pleine en PopTime, jet de JetMin à JetMax
-- de la largeur de l'écran vers le haut en JetTime (Quint Out), pause Hold, puis le nombre `kind.HudLabel` du HUD
-- l'aspire en SuckTime (Quad In) en le rétrécissant à EndScale. À l'arrivée : `releases` (le nombre monte) et la
-- pulsation du compteur (rang `rank` sur `pieces`, SpeedPulse). false, sans rien créer, si le gain ne peut pas voler
-- (pas de HUD, de nombre visé ni de modèle, départ hors de l'écran) : à l'appelant de faire l'ancien affichage.
local function flyGain(
	kind: Kind,
	amount: number,
	text: string?,
	fromWorld: Vector3?,
	releases: { () -> () },
	rank: number,
	pieces: number
): boolean
	local spec = TRAIN_FLY
	local screen = hudScreen()
	if spec == nil or screen == nil then
		return false
	end
	local target = typed(screen, kind.HudLabel, "TextLabel") :: TextLabel?
	local point: Vector3? = fromWorld
	if point == nil then
		local root = rootPart()
		point = if root then root.Position + Vector3.new(0, FLOAT.Height, 0) else nil
	end
	local start: Vector2? = if point then projectTo(screen, point) else nil
	if target == nil or start == nil then
		return false
	end
	local flyer, source = makeFlyer(screen)
	if flyer == nil or source == nil then
		warnOnce("trainFly", `[Gains] UI_HUD.{spec.Template} et {GAIN_TEMPLATE}.Row absents : le gain monte sur place`)
		return false
	end
	local from = start :: Vector2
	dressGain(flyer, source, kind, amount, text)
	local size = screen.AbsoluteSize
	flyer.AnchorPoint = Vector2.new(0.5, 0.5)
	flyer.Position = UDim2.fromOffset(from.X, from.Y)
	local scale = Instance.new("UIScale")
	scale.Name = COPY_SCALE
	scale.Scale = spec.PopFrom
	scale.Parent = flyer
	flyer.Parent = screen
	active.TrainFlies += 1
	local angle = math.rad((random:NextNumber() * 2 - 1) * spec.JetAngle)
	local distance = size.X * (spec.JetMin + random:NextNumber() * (spec.JetMax - spec.JetMin))
	local edgeX, edgeY = size.X * spec.Edge, size.Y * spec.Edge
	local jetX = math.clamp(from.X + math.sin(angle) * distance, edgeX, math.max(edgeX, size.X - edgeX))
	local jetY = math.clamp(from.Y - math.cos(angle) * distance, edgeY, math.max(edgeY, size.Y - edgeY))
	TweenService:Create(scale, TweenInfo.new(spec.PopTime, spec.PopStyle, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(flyer, TweenInfo.new(spec.JetTime, spec.JetStyle, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(jetX, jetY),
	}):Play()
	local landed = false
	local function land()
		if landed then
			return
		end
		landed = true
		active.TrainFlies -= 1
		flyer:Destroy()
		releaseAll(releases)
		if kind == SPEED then
			pulseSpeed(rank, pieces)
		end
	end
	task.delay(spec.JetTime + spec.Hold, function()
		local now = hudScreen()
		local label = if now then typed(now, kind.HudLabel, "TextLabel") :: TextLabel? else nil
		if now == nil or label == nil or flyer.Parent ~= now then
			land() -- HUD recréé (réapparition) ou nombre retiré : le compteur monte tout de suite
			return
		end
		local origin = now.AbsolutePosition
		local goal = UDim2.fromOffset(
			label.AbsolutePosition.X - origin.X + label.AbsoluteSize.X / 2,
			label.AbsolutePosition.Y - origin.Y + label.AbsoluteSize.Y / 2
		)
		local info = TweenInfo.new(spec.SuckTime, spec.SuckStyle, Enum.EasingDirection.In)
		TweenService:Create(scale, info, { Scale = spec.EndScale }):Play()
		local move = TweenService:Create(flyer, info, { Position = goal })
		move.Completed:Connect(land)
		move:Play()
	end)
	return true
end

-- Speed affichée par le HUD pour `speed` points d'entraînement, avec le trail porté (Formulas.ShownSpeed, comme
-- StatsService pour l'attribut ShownSpeed).
local function shownSpeed(speed: number): number
	local trail = localPlayer:GetAttribute(TRAIL_ATTRIBUTE)
	return Formulas.ShownSpeed(speed, if type(trail) == "number" and trail == trail and trail > 0 then trail else nil)
end

-- Retient le nombre Speed du HUD à `base` (HudController.HoldSpeed) ; sans lui : une fonction sans effet.
local function holdSpeed(base: number): () -> ()
	local api = hud
	local hold = if api then api.HoldSpeed else nil
	if hold then
		local ok, result = pcall(hold, base)
		if ok and type(result) == "function" then
			return result
		end
	end
	return function() end
end

-- Le gain d'une seconde du tapis (un seul « +X Speed/s », a200) vole jusqu'au compteur, dont le nombre reste à la
-- valeur d'avant jusqu'à l'arrivée. false : rien n'a volé (l'ancien affichage prend le relais).
local function flyTreadmill(amount: number, previous: number): boolean
	if not canFly() then
		return false
	end
	local release = holdSpeed(shownSpeed(previous))
	if flyGain(SPEED, amount, nil, nil, { release }, 1, 1) then
		return true
	end
	release()
	return false
end

-- Vague 64 : un « +X » qui jaillit de `fromWorld` et vole jusqu'au compteur Speed, qui pulse à l'arrivée (pour a214,
-- les bulles du tapis ; pas encore appelé). Le nombre n'est pas retenu : l'appelant ne dit pas ce qu'il ajoute.
function GainController.FlyGain(text: string, fromWorld: Vector3, kind: "Speed"): boolean
	if kind ~= SPEED.Name or not canFly() then
		return false
	end
	return flyGain(SPEED, 0, text, fromWorld, {}, 1, 1)
end

-- Le gain d'une seconde du tapis en CHUNKS « +X » répartis sur Period s, même total (le dernier morceau prend le
-- reste des arrondis). Chaque morceau vit Life s. Vague 64 : chaque morceau vole jusqu'au compteur ; le nombre Speed
-- est retenu morceau par morceau (bases prises tout de suite, depuis `previous`, la Vitesse d'avant le gain).
local function showPieces(amount: number, previous: number)
	local tread = TREAD :: any
	local pieces = CHUNKS
	local gap = tread.Period / pieces
	local piece = amount / pieces
	local releases: { [number]: () -> () } = {}
	if canFly() then
		for rank = 1, pieces do
			releases[rank] = holdSpeed(shownSpeed(previous + piece * (rank - 1)))
		end
	end
	for rank = 1, pieces do
		local value = if rank == pieces then amount - piece * (pieces - 1) else piece
		local release = releases[rank]
		local function show()
			local text = string.format(tread.Text, Format.short(value))
			if release then
				if canFly() and flyGain(SPEED, value, text, nil, { release }, rank, pieces) then
					return
				end
				release()
			end
			floatGain(SPEED, value, PIECE_RISE_INFO, text)
			pulseSpeed(rank, pieces)
		end
		if rank == 1 then
			show()
		else
			task.delay(gap * (rank - 1), show)
		end
	end
end

local function onTraining(kind: Kind)
	local amount, previous = riseOf(kind.Attribute)
	if amount > 0 and localPlayer:GetAttribute(MACHINE_ATTRIBUTE) == kind.Machine then
		local before: number = previous or 0 -- une hausse a toujours une valeur d'avant
		if kind == SPEED and TREAD ~= nil and CHUNKS > 1 then
			showPieces(amount, before)
		elseif kind == SPEED and flyTreadmill(amount, before) then
			return -- vague 64 : il vole ; le compteur pulse à son arrivée
		else
			-- a200 (Cantin) : un seul « +X Speed/s » par seconde, le gain entier ; le compteur pulse une fois.
			showGain(kind, amount)
			if kind == SPEED then
				pulseSpeed(1, 1)
			end
		end
	end
end

local function onCash()
	local amount, previous = riseOf(CASH.Attribute)
	if amount <= 0 or previous == nil then
		return
	end
	-- Retenu tout de suite (avant que le HUD ne fasse défiler la hausse), relâché à l'arrivée.
	local api = hud
	local release: (() -> ())? = nil
	if api then
		local ok, result = pcall(api.HoldCash, previous)
		if ok and type(result) == "function" then
			release = result
		end
	end
	table.insert(rises, { amount = amount, release = release })
	queueClassify()
end

local function onCollected()
	local amount = riseOf(COLLECTED_ATTRIBUTE)
	if amount > 0 then
		collected += amount
		queueClassify()
	end
end

function GainController.GetActive(): { Gains: number, Flyers: number, Pops: number, Bills: number, IncomeFlies: number, TrainFlies: number }
	return table.clone(active)
end

function GainController.Start()
	hud = sibling("HudController")
	rewards = sibling("RewardsController")
	offline = sibling("OfflineController")
	chase = sibling("ChaseController") -- vague 63 : aucun « +$/s » qui vole pendant une poursuite
	onInventory() -- première lecture : rien ne vole
	localPlayer:GetAttributeChangedSignal(InventoryState.Attribute):Connect(onInventory)
	for _, kind in { SPEED } do -- v2 : plus de banc, plus de « +X Power »
		riseOf(kind.Attribute)
		localPlayer:GetAttributeChangedSignal(kind.Attribute):Connect(function()
			onTraining(kind)
		end)
	end
	riseOf(CASH.Attribute)
	riseOf(COLLECTED_ATTRIBUTE)
	localPlayer:GetAttributeChangedSignal(CASH.Attribute):Connect(onCash)
	localPlayer:GetAttributeChangedSignal(COLLECTED_ATTRIBUTE):Connect(onCollected)
end

return GainController
