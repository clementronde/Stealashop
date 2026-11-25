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
--       * a401 (vague GC4, vidéo de Cantin ; UiMotion.CollectFeel) : sans case (CashFly.Enabled = false), un revenu de
--         la base est confié à CollectFeelController.Hold : chiffre relâché à la 1re arrivée des billets de la plaque ;
--         le « +$X » d'argent entre en dépassant (0,45 → 1,1 → 1) et sort en rétrécissant (CollectFeel.Text).
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
-- joueur hors de l'écran ou Enabled = false : l'ancien « +X » sur place (ni plafond ni poursuite, fusion58).
-- Avec ChunksPerSecond > 1, chaque morceau vole de même.
-- Vague 65 (a215) : sans modèle de Clément, le cadre fait ici s'élargit pour que le texte tienne sur une ligne (Amount
-- copié sans retour à la ligne, Config/Hud.TrainGainFly.TextMargin), et le « ×2 » du trail se place juste après le
-- nombre sans le couvrir (aussi sur le BB_Gain sur place). Une bulle ×N prise (BubbleController → NoteBubble, annoncée
-- avant la hausse de Speed) s'affiche « +32 Speed » (Config/Hud.BubbleGain), sans « /s » ; tombée sur la même hausse
-- qu'une seconde du tapis, les deux textes partent séparés, même total.
--
-- API (client) :
--   GainController.FlyGain(text, fromWorld, kind) -> boolean   vague 64 : un « +X » qui jaillit de `fromWorld` et vole
--       jusqu'au compteur du HUD de `kind` ("Speed"), qui pulse à l'arrivée (sans retenir son nombre : l'appelant ne
--       dit pas ce qu'il ajoute) ; false s'il n'a pas pu voler (animations réduites, rien à l'écran…).
--   GainController.NoteBubble(gain)   vague 65 : la prochaine hausse de Speed contient `gain` venu d'une bulle (BubbleGone).
--   a317 (L-299, Config/CashFlash ; détail dans la section « jus » d'une plaque) : voile UI_CashFlash, compteur retenu
--   jusqu'au premier billet 3D, CashRow qui grossit et son Cash_Pad à chaque plaque vidée par le joueur local.
--   a422 (Cantin, 24/11) : ce son part au contact de la plaque, une fois (Cash_Collect s'il manque).
--   GainController.FlashRank(précédent, depuis) -> number   rang de la plaque dans la tournée
--   GainController.FlashGoal(posée, rang) -> number         transparence d'une bande du voile au plus fort
--   GainController.GetPadState() -> { Rank, Notes, Waiting, FlashToken }   pour les bancs
--   a472 (L-365, Config/CashFlash.SoundStart et Predict, Features.PadPredict / PadPredictDev) : Cash_Pad lu à partir de
--   SoundStart s ; le client prévoit l'arrivée sur une de ses plaques (Shared/PadZone, la règle du serveur) et joue son
--   et voile sans attendre le remote, qui ne les rejoue pas ; l'argent, le compteur et « +$X » restent ceux du serveur.
--   GainController.GetPredictState() -> { On, Predicted, Confirmed, Pads, Waiting }   pour les bancs
-- Pour un test dans Studio (barre de commande côté client) :
--   GainController.GetActive() -> { Gains: number, Flyers: number, Pops: number, Bills: number, IncomeFlies: number, TrainFlies: number }
--   GainController.GetPops() -> { Offsets: { Vector3 }, Voices: number }   a480 : apparitions autour du joueur encore
--       visibles (décalages du monde depuis le HumanoidRootPart) et copies du son en cours.
-- a480 (Clément via Cantin, 25/11 ; Features.TreadmillGainPops / TreadmillGainPopsDev, Config/TreadmillFX.GainPops) :
--   allumé, le gain d'une seconde du tapis ne vole plus dans UI_HUD : il sort AUTOUR du joueur, dans le monde 3D, en
--   GainPops.PerSecond copies de BB_Gain (angles et hauteurs variés, Shared/GainPops.Pick), chacune avec la Speed finale
--   (Formulas.ShownSpeed, trail compris ; plus de « ×N ») et un son (GainPops.Sound, au plus MaxVoices à la fois). Le
--   compteur Speed n'est plus retenu : il monte à la hausse de l'attribut et pulse à chaque apparition. Les bulles ×N
--   (BubbleGain) gardent leur affichage.
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
		return `+{Format.short(amount)}` -- vague 67 (a224, Cantin) : « +2 », le nombre seul (L-091 disait « +2 Speed/s »)
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
local NBSP = utf8.char(0xA0) -- vague 70 (a232) : espace insécable, où Roblox ne coupe pas la ligne
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
-- Vague 67 (a224) : échelle du gain du tapis (et d'une bulle), en vol et sur place (Config/Hud.TrainGainFly.Scale ; 1 sans).
local TRAIN_SCALE: number = if TRAIN_FLY and type(TRAIN_FLY.Scale) == "number" and TRAIN_FLY.Scale > 0
	then TRAIN_FLY.Scale
	else 1
local settingsModule = Shared:WaitForChild("Config"):FindFirstChild("Settings")
local SettingsConfig: any = if settingsModule and settingsModule:IsA("ModuleScript") then require(settingsModule) :: any else nil
-- Vague 65 (a215) : gain d'une bulle ×N (Config/Hud.BubbleGain ; facultatif : bancs plus anciens).
local BUBBLE_GAIN: any = if HudConfig then HudConfig.BubbleGain else nil
-- Vague 63 (a206) : « +$X/s » qui vole à chaque pose (Config/Displayed.IncomeFly ; facultatif : bancs plus anciens).
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local displayedModule = Shared:WaitForChild("Config"):FindFirstChild("Displayed")
local DisplayedConfig: any = if displayedModule and displayedModule:IsA("ModuleScript") then require(displayedModule) :: any else nil
local INCOME_FLY: any = if DisplayedConfig then DisplayedConfig.IncomeFly else nil
local DISPLAY_TAG = "DisplayItem" -- tag de code des objets exposés (DisplayService)
type ChaseApi = { IsChased: () -> boolean }

-- a480 (Clément via Cantin, 25/11) : gains du tapis autour du joueur (Config/TreadmillFX.GainPops, Shared/GainPops ;
-- facultatifs : bancs plus anciens). Coupé ou absent : l'affichage d'avant.
local function optionalModule(parent: Instance?, name: string): any
	local module = if parent then parent:FindFirstChild(name) else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end
local treadmillFx: any = optionalModule(Shared:FindFirstChild("Config"), "TreadmillFX")
local GainPops: any = optionalModule(Shared, "GainPops")
local POPS: any = if treadmillFx and GainPops and treadmillFx.GainPops and treadmillFx.GainPops.Enabled == true
	then treadmillFx.GainPops
	else nil

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
-- a401 (vague GC4, vidéo de Cantin) : CollectFeelController (Hold) et l'entrée et la sortie du « +$X » d'argent
-- (UiMotion.CollectFeel.Text ; absent ou coupé : la montée et le fondu de FloatGain, comme avant).
local collectFeel: any = nil
local COLLECT_TEXT: any = (UiMotion :: any).CollectFeel and (UiMotion :: any).CollectFeel.Text
if COLLECT_TEXT and COLLECT_TEXT.Enabled ~= true then
	COLLECT_TEXT = nil
end
local placed: { [string]: boolean }? = nil -- vague 63 : uids exposés à la dernière lecture (nil : pas encore lu)
-- Vague 65 (a215) : Vitesse de bulle annoncée (NoteBubble) et pas encore vue monter, et l'heure de l'annonce.
local bubblePending = 0
local bubbleAt = -math.huge
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

-- a233 (T-150, T-151) : mesures de GetTextBoundsAsync (police, texte, taille 100), vidées à 256 entrées.
local boundsCache: { [string]: number } = {}
local boundsCount = 0

-- a196 : largeur relative de `text` dans la police de `label` (TextService, taille 100) ; sans TextService ou
-- police inconnue : le nombre de caractères.
-- a233 : d'abord label.FontFace par GetTextBoundsAsync (le modèle de Clément est en Montserrat Heavy, une
-- FontFace : label.Font y vaut Unknown et l'exposant tombait sur le chiffre). Le premier appel d'un texte attend
-- (fils de signaux et de task.delay seulement), les suivants viennent du cache. Texte mesuré entre deux « | » : les
-- blancs aux bords (espaces insécables) comptent même si Roblox les ignorait seuls.
local function textWidth(label: TextLabel, text: string): number
	local okFace, faceWidth = pcall(function(): number
		local face = label.FontFace
		local key = `{face.Family}|{face.Weight}|{face.Style}|100|`
		local function measure(s: string): number
			local cached = boundsCache[key .. s]
			if cached then
				return cached
			end
			local params = Instance.new("GetTextBoundsParams")
			params.Text = s
			params.Font = face
			params.Size = 100
			params.Width = 1e5
			local width = (game:GetService("TextService") :: TextService):GetTextBoundsAsync(params).X
			assert(width > 0)
			if boundsCount >= 256 then
				table.clear(boundsCache)
				boundsCount = 0
			end
			boundsCache[key .. s] = width
			boundsCount += 1
			return width
		end
		return measure(`|{text}|`) - measure("||")
	end)
	if okFace and type(faceWidth) == "number" and faceWidth > 0 then
		return faceWidth
	end
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
-- Vague 65 (a215) : `oneLine` (copies de BB_Gain) : Amount ne passe plus à la ligne (TextScaled réduit le texte à la
-- place) ; la place de l'exposant suppose une seule ligne, sinon il tombait sur le nombre.
-- Vague 70 (a232, T-150, T-151) : dans Roblox, TextWrapped = false remet aussi TextScaled à false (texte en petite
-- TextSize) et TextScaled = true remet TextWrapped. La ligne tient donc par des espaces insécables (U+00A0), où Roblox
-- ne coupe pas (vu dans Studio : « +8 Speed/s » reste sur une ligne, réduit à la largeur) ; TextScaled n'est plus touché.
local function addExponent(amountLabel: TextLabel, head: string, tail: string, trailText: string, oneLine: boolean): TextLabel
	local blank = if oneLine then NBSP else " "
	if oneLine then
		head, tail = (string.gsub(head, " ", NBSP)), (string.gsub(tail, " ", NBSP))
	end
	local spec = FLOAT.TrailExponent
	local space = textWidth(amountLabel, blank)
	local gap = math.clamp(math.ceil(textWidth(amountLabel, trailText) * spec.Size / math.max(space, 1)), 1, 8)
	amountLabel.Text = head .. string.rep(blank, gap) .. tail
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
local function dressGain(copy: Instance, source: Instance, kind: Kind, amount: number, text: string?, plain: boolean?): Dressed
	local amountLabel = typed(copy, "Amount", "TextLabel") :: TextLabel?
	local icon = typed(copy, "Icon", "ImageLabel") :: ImageLabel?
	local multiplierLabel = typed(copy, "Multiplier", "TextLabel") :: TextLabel?
	-- Vague 47 (a155) : multiplicateur du trail (Speed seulement), même format que la boutique (« ×2 »).
	-- a480 : `plain` (gains autour du joueur) : jamais de « ×N », le nombre affiché est déjà la Speed finale.
	local trailText: string? = nil
	if kind == SPEED and plain ~= true then
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
				local head, tail = string.sub(text, 1, cut - 1), string.sub(text, cut)
				ok, made = pcall(addExponent, amountLabel, head, tail, trailText, source:IsA("BillboardGui"))
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
	if kind == SPEED and TRAIN_SCALE ~= 1 then
		-- Vague 67 (a224) : le « +X » du tapis sur place, plus gros (TrainGainFly.Scale) ; texte à l'échelle du cadre.
		local s = billboard.Size
		billboard.Size = UDim2.new(s.X.Scale * TRAIN_SCALE, s.X.Offset * TRAIN_SCALE, s.Y.Scale * TRAIN_SCALE, s.Y.Offset * TRAIN_SCALE)
	end

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
	local look = COLLECT_TEXT
	if kind == CASH and look and row then
		-- a401 (vague GC4, vidéo de Cantin) : Row dépasse (From → Over → 1), tient, puis rétrécit jusqu'à 0 en montant un
		-- peu, sans fondu ; la copie est détruite à la fin (≈ 1,15 s).
		local scale = Instance.new("UIScale")
		scale.Name = COPY_SCALE
		scale.Scale = look.From
		scale.Parent = row
		local grow = TweenService:Create(scale, TweenInfo.new(look.InTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = look.Over })
		grow.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				TweenService:Create(scale, TweenInfo.new(look.SettleTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1 }):Play()
			end
		end)
		grow:Play()
		task.delay(look.InTime + look.SettleTime + look.Hold, function()
			local outInfo = TweenInfo.new(look.OutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			local progress = Instance.new("NumberValue")
			progress:GetPropertyChangedSignal("Value"):Connect(function()
				billboard.StudsOffset = base + Vector3.new(spread, look.OutRise * progress.Value, 0)
			end)
			TweenService:Create(progress, outInfo, { Value = 1 }):Play()
			local shrink = TweenService:Create(scale, outInfo, { Scale = 0 })
			shrink.Completed:Connect(function()
				active.Gains -= 1
				billboard:Destroy()
				progress:Destroy()
			end)
			shrink:Play()
		end)
		return
	end
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

------------------------------------------------------------------------------
-- a480 : gains du tapis autour du joueur (Config/TreadmillFX.GainPops)
------------------------------------------------------------------------------

type Pop = { offset: Vector3, untilAt: number }
local pops: { Pop } = {} -- apparitions encore visibles (écart minimal entre deux proches)
local popVoices = 0 -- copies du son en cours (au plus GainPops.MaxVoices)
local popTemplate: Sound? = nil
local popTemplateLooked = false

-- Décalages des apparitions encore visibles (les finies sont retirées).
local function livePops(): { Vector3 }
	local now = os.clock()
	local offsets: { Vector3 } = {}
	for index = #pops, 1, -1 do
		if pops[index].untilAt <= now then
			table.remove(pops, index)
		else
			table.insert(offsets, pops[index].offset)
		end
	end
	return offsets
end

-- Le son d'une apparition : Assets/Sounds/<GainPops.Sound>, volume × VolumeScale, hauteur au hasard ; muet au-delà de
-- MaxVoices copies en même temps (pas de saturation à 6 par seconde).
local function popSound()
	local spec = POPS
	if spec == nil or popVoices >= spec.MaxVoices then
		return
	end
	if not popTemplateLooked then
		popTemplateLooked = true
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local folder = if assets then assets:FindFirstChild("Sounds") else nil
		local found = if folder then folder:FindFirstChild(spec.Sound, true) else nil
		popTemplate = if found and found:IsA("Sound") then found :: Sound else nil
		if popTemplate == nil then
			warnOnce("popSound", `[Gains] son {spec.Sound} absent d'Assets/Sounds : gains du tapis muets`)
		end
	end
	local template = popTemplate
	if template == nil then
		return
	end
	local sound = template:Clone()
	sound.Volume = template.Volume * spec.VolumeScale
	sound.PlaybackSpeed = template.PlaybackSpeed * (1 + (random:NextNumber() * 2 - 1) * spec.PitchJitter)
	sound.Parent = game:GetService("SoundService")
	popVoices += 1
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		popVoices -= 1
		sound:Destroy()
	end
	sound.Ended:Once(finish)
	task.delay(math.max(template.TimeLength, 0) + 2, finish) -- son jamais chargé : la voix est rendue quand même
	sound:Play()
end

-- Une apparition « +X » (texte déjà fait, sans « ×N ») autour du joueur : copie de BB_Gain posée sur le
-- HumanoidRootPart avec un décalage du monde (GainPops.Pick), qui grossit, monte de Rise et s'efface en Life s.
-- false si rien n'a pu s'afficher (pas de BB_Gain ni de personnage).
local function popWorld(text: string): boolean
	local spec = POPS
	local root = rootPart()
	local gui = playerGui()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("UI") else nil
	local template = if folder then folder:FindFirstChild(GAIN_TEMPLATE) else nil
	if spec == nil or root == nil or gui == nil or template == nil or not template:IsA("BillboardGui") then
		if template == nil then
			warnOnce("template", `[Gains] ReplicatedStorage/Assets/UI/{GAIN_TEMPLATE} absent : pas de gain autour du joueur`)
		end
		return false
	end
	local offset: Vector3 = GainPops.Pick(random, livePops(), spec)
	table.insert(pops, { offset = offset, untilAt = os.clock() + spec.Life })
	local billboard = (template :: BillboardGui):Clone()
	local row = typed(billboard, "Row", "GuiObject") :: GuiObject?
	local dressed = dressGain(billboard, template, SPEED, 0, text, true)
	billboard.Adornee = root
	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = offset
	if spec.Scale ~= 1 then
		local s = billboard.Size
		billboard.Size = UDim2.new(s.X.Scale * spec.Scale, s.X.Offset * spec.Scale, s.Y.Scale * spec.Scale, s.Y.Offset * spec.Scale)
	end
	local fades: { Fade } = {}
	if dressed.amount then
		table.insert(fades, { object = dressed.amount :: Instance, property = "TextTransparency", from = dressed.amount.TextTransparency })
	end
	if dressed.icon then
		table.insert(fades, { object = dressed.icon :: Instance, property = "ImageTransparency", from = dressed.icon.ImageTransparency })
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
	progress:GetPropertyChangedSignal("Value"):Connect(function()
		local a = progress.Value
		billboard.StudsOffsetWorldSpace = offset + Vector3.new(0, spec.Rise * a, 0)
		local fade = math.clamp((a - FLOAT.FadeAt) / (1 - FLOAT.FadeAt), 0, 1)
		for _, item in fades do
			(item.object :: any)[item.property] = item.from + (1 - item.from) * fade
		end
	end)
	local rise = TweenService:Create(progress, TweenInfo.new(spec.Life, FLOAT.Style, FLOAT.Direction), { Value = 1 })
	rise.Completed:Connect(function()
		active.Gains -= 1
		billboard:Destroy()
		progress:Destroy()
	end)
	rise:Play()
	popSound()
	return true
end

-- Pour les bancs : décalages des apparitions encore visibles et copies du son en cours.
function GainController.GetPops(): { Offsets: { Vector3 }, Voices: number }
	return { Offsets = livePops(), Voices = popVoices }
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

------------------------------------------------------------------------------
-- a317 (L-299) : le « jus » d'une plaque vidée par le joueur local (Config/CashFlash)
------------------------------------------------------------------------------
-- À chaque plaque CollectPad_xx vidée par le joueur local (DisplayController.OnCollect) :
--   1. voile UI_CashFlash (EdgeGlow.Top, Bottom, Left, Right de Clément) : chaque bande va de sa transparence du moment
--      à FlashGoal(posée, n) en InTime, tient HoldTime, revient à 1 en OutTime, puis l'écran s'éteint ; n = FlashRank ;
--      pas de voile avec les animations réduites (VISUAL EFFECTS sur OFF ou « Réduire les mouvements » de Roblox) ;
--   2. la hausse de Cash (retenue par onCash, comme toute hausse) n'est relâchée qu'à l'arrivée du premier billet 3D au
--      compteur (VfxController.OnCollectLanded) : elle défile en RollTime (HudController.SetNextCashRoll), CashRow grossit
--      (PopScale en PopUpTime, retour en PopDownTime) et Sound (Cash_Pad) part, PlaybackSpeed × (1 ± PitchJitter) ;
--      Cash_Collect n'est plus joué ; « +$X » au-dessus du joueur comme avant. Sans billets : tout de suite.
--   a422 (Cantin, 24/11, CashFlash.SoundOnContact) : le son ne part plus à l'arrivée du premier billet (≈ 0,7 s après
--      le contact avec la fontaine, jusqu'à LandTimeout = 2 s si l'arrivée n'est pas vue) mais au contact, dans
--      onPadCollect, une fois par plaque (PadNote.sounded) : Sound, sinon FallbackSound (Cash_Collect) s'il manque.
--      Écran des gains hors ligne ouvert : pas de son ici, l'encaissement d'avant joue Cash_Collect (classic).
-- La hausse de Cash et le remote de la plaque arrivent dans un ordre non garanti : une hausse de CashCollected attend
-- au plus MatchWindow s une plaque vue ; sans elle (encaissement automatique, gains hors ligne) : comme avant.

local cashFlashModule = Shared:WaitForChild("Config"):FindFirstChild("CashFlash")
local CashFlash: any = if cashFlashModule and cashFlashModule:IsA("ModuleScript") then require(cashFlashModule) :: any else nil
local FLASH_ON: boolean = CashFlash ~= nil and CashFlash.Enabled == true
local FLASH_IN_INFO: TweenInfo = TweenInfo.new(if CashFlash then CashFlash.InTime else 0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- sans Config/CashFlash : jamais joué
local FLASH_OUT_INFO: TweenInfo = TweenInfo.new(if CashFlash then CashFlash.OutTime else 0, Enum.EasingStyle.Quad, Enum.EasingDirection.In) -- sans Config/CashFlash : jamais joué
local PAD_ROLL_INFO: TweenInfo = TweenInfo.new(if CashFlash then CashFlash.RollTime else 0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- sans Config/CashFlash : jamais joué
local PAD_POP_UP_INFO: TweenInfo = TweenInfo.new(if CashFlash then CashFlash.PopUpTime else 0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- sans Config/CashFlash : jamais joué
local PAD_POP_DOWN_INFO: TweenInfo = TweenInfo.new(if CashFlash then CashFlash.PopDownTime else 0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- sans Config/CashFlash : jamais joué
local PAD_SCALE = "CashPadScale" -- V0 proposé : UIScale passager posé sur CashRow (détruit à la fin)
local CONTACT_SOUND: boolean = CashFlash ~= nil and CashFlash.SoundOnContact == true -- a422 : son au contact

-- Plaque vue (remote CashCollect du joueur local) : `landed` à l'arrivée de son premier billet, `claimed` quand une
-- hausse de Cash lui est attribuée, `onLand` appelé à l'arrivée, `sounded` quand son son est parti (a422).
type PadNote = { at: number, landed: boolean, claimed: boolean, sounded: boolean, onLand: (() -> ())? }
-- Hausse de CashCollected qui attend sa plaque (au plus MatchWindow s).
type PadWait = { total: number, releases: { () -> () }, done: boolean }

local padNotes: { PadNote } = {}
local padWaits: { PadWait } = {}
local vfxLands = false -- VfxController.OnCollectLanded branché (sinon les billets ne retiennent rien)
local flashRank = 0
local flashLastAt = -math.huge
local flashToken = 0
local flashPeaks: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any -- transparence posée par Clément
local padPopToken = 0
local markerSounds: any = nil -- Shared/Anim/MarkerSounds (son Cash_Pad, hauteur au hasard)
local classic: (total: number, releases: { () -> () }, fromPad: boolean) -> () -- après classify (plus bas)

-- Rang de la plaque dans la tournée : 1 à la première, +1 si la précédente date de moins de RankWindow s.
function GainController.FlashRank(previous: number, sinceLast: number): number
	local window = if CashFlash then CashFlash.RankWindow else 2
	if previous >= 1 and sinceLast >= 0 and sinceLast < window then
		return previous + 1
	end
	return 1
end

-- Transparence d'une bande au plus fort du voile : posée + (1 − posée) × Strength × (1 − clamp((n − 1)/RankSpan, 0, 1)).
function GainController.FlashGoal(peak: number, rank: number): number
	local strength = if CashFlash then CashFlash.Strength else 0.45
	local span = if CashFlash then CashFlash.RankSpan else 7
	local k = math.clamp((rank - 1) / span, 0, 1)
	return peak + (1 - peak) * strength * (1 - k)
end

local function flashReduced(): boolean
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

-- Bandes du voile et leur transparence posée (lue une fois par bande, puis la bande est mise à 1).
local function flashBands(): (ScreenGui?, { [GuiObject]: number })
	local gui = playerGui()
	local screen = if gui then gui:FindFirstChild(CashFlash.Screen) else nil
	if screen == nil or not screen:IsA("ScreenGui") then
		warnOnce("cashFlash", `[Gains] {CashFlash.Screen} absent : pas de voile à l'encaissement d'une plaque`)
		return nil, {}
	end
	local container = screen:FindFirstChild(CashFlash.Container)
	local bands: { [GuiObject]: number } = {}
	for _, name in CashFlash.Bands do
		local band = if container then container:FindFirstChild(name) else nil
		if band and band:IsA("GuiObject") then
			local object = band :: GuiObject
			local peak = flashPeaks[object]
			if peak == nil then
				peak = object.BackgroundTransparency
				flashPeaks[object] = peak
				object.BackgroundTransparency = 1
			end
			bands[object] = peak :: number
		end
	end
	return screen :: ScreenGui, bands
end

local function flashVeil(rank: number)
	if flashReduced() then
		return
	end
	local screen, bands = flashBands()
	if screen == nil or next(bands) == nil then
		return
	end
	flashToken += 1
	local mine = flashToken
	screen.Enabled = true
	for band, peak in bands do
		TweenService:Create(band, FLASH_IN_INFO, { BackgroundTransparency = GainController.FlashGoal(peak, rank) }):Play()
	end
	task.delay(CashFlash.InTime + CashFlash.HoldTime, function()
		if mine ~= flashToken then
			return -- une autre plaque a relancé le voile
		end
		for band in bands do
			TweenService:Create(band, FLASH_OUT_INFO, { BackgroundTransparency = 1 }):Play()
		end
		task.delay(CashFlash.OutTime + CashFlash.OffDelay, function()
			if mine == flashToken and screen.Parent ~= nil then
				screen.Enabled = false
			end
		end)
	end)
end

-- CashRow grossit (PopScale en PopUpTime) puis revient à 1 (PopDownTime) ; un autre UIScale déjà là (celui de
-- Clément, ou un sursaut de Motion.Pop en cours) : le sursaut habituel à la place.
local function padPop(refs: HudRefs?)
	if refs == nil then
		return
	end
	local row = refs.row
	local scale = row:FindFirstChild(PAD_SCALE)
	if scale == nil or not scale:IsA("UIScale") then
		if row:FindFirstChildOfClass("UIScale") ~= nil then
			bump(refs)
			return
		end
		local created = Instance.new("UIScale")
		created.Name = PAD_SCALE
		created.Parent = row
		scale = created
	end
	local uiScale = scale :: UIScale
	padPopToken += 1
	local mine = padPopToken
	local up = TweenService:Create(uiScale, PAD_POP_UP_INFO, { Scale = CashFlash.PopScale })
	up.Completed:Connect(function()
		if mine ~= padPopToken then
			return
		end
		local down = TweenService:Create(uiScale, PAD_POP_DOWN_INFO, { Scale = 1 })
		down.Completed:Connect(function(state: Enum.PlaybackState)
			if mine == padPopToken and state == Enum.PlaybackState.Completed then
				uiScale:Destroy()
			end
		end)
		down:Play()
	end)
	up:Play()
end

-- Le son d'une plaque : Sound (Cash_Pad), PlaybackSpeed × (1 ± PitchJitter) ; a422 : absent, FallbackSound
-- (Cash_Collect) tel quel, pour qu'un son parte toujours.
local function padSound()
	local name: string = CashFlash.Sound
	local fallback: string? = CashFlash.FallbackSound
	local sounds: any = markerSounds
	local find: any = if sounds then sounds.find else nil
	local playSound: any = if sounds then sounds.playSound else nil
	if find ~= nil and playSound ~= nil then
		local ok, found = pcall(find :: any, name)
		local template: any = if ok then found else nil
		if template ~= nil then
			local played: any = (playSound :: any)(template, nil)
			if played then
				local jitter: number = CashFlash.PitchJitter
				local base: number = template.PlaybackSpeed
				played.PlaybackSpeed = base * (1 + (random:NextNumber() * 2 - 1) * jitter)
				-- a472 (L-365 point 1) : lu à partir de SoundStart s, pour sauter le « cha » du fichier (le fichier n'est
				-- pas touché). pcall : un Sound qui refuserait la position joue du début, comme avant.
				local start: any = CashFlash.SoundStart
				if type(start) == "number" and start > 0 then
					pcall(function()
						played.TimePosition = start
					end)
				end
			end
			return
		end
		local okFallback, foundFallback = pcall(find :: any, fallback)
		local spare: any = if okFallback and fallback then foundFallback else nil
		if spare ~= nil then
			warnOnce("padSound", `[Gains] son {name} absent d'Assets/Sounds : {fallback} à la place`)
			local play: any = playSound
			play(spare, nil)
			return
		end
		warnOnce("padSound", `[Gains] son {name} absent d'Assets/Sounds : plaque muette`)
		return
	end
	Motion.PlaySound(name) -- sans MarkerSounds : même son, sans hauteur au hasard
end

-- La hausse d'une plaque : « +$X » au-dessus du joueur tout de suite, compteur et sursaut à l'arrivée du premier billet
-- d'une des plaques `notes` (ou au bout de LandTimeout s) ; le son au contact (a422), ou à cette arrivée sans
-- SoundOnContact.
local function padJuice(total: number, releases: { () -> () }, notes: { PadNote })
	showGain(CASH, total)
	if CONTACT_SOUND then
		-- Plaque restée muette au contact (écran des gains hors ligne fermé entre le remote et la hausse) : son tout de suite.
		local sounded = false
		for _, note in notes do
			sounded = sounded or note.sounded
		end
		if not sounded and notes[1] then
			notes[1].sounded = true
			padSound()
		end
	end
	local fired = false
	local function go()
		if fired then
			return
		end
		fired = true
		local api: any = hud
		if api and type(api.SetNextCashRoll) == "function" then
			pcall(api.SetNextCashRoll, PAD_ROLL_INFO)
		end
		releaseAll(releases)
		local refs = hudRefs()
		padPop(refs)
		if not CONTACT_SOUND then
			padSound()
		end
	end
	for _, note in notes do
		note.claimed = true
		if note.landed then
			go()
			return
		end
		note.onLand = go
	end
	task.delay(CashFlash.LandTimeout, go)
end

-- Plaques vues depuis moins de MatchWindow s, pas encore attribuées.
local function claimNotes(): { PadNote }
	local now = os.clock()
	local found: { PadNote } = {}
	for _, note in padNotes do
		if not note.claimed and now - note.at <= CashFlash.MatchWindow then
			note.claimed = true
			table.insert(found, note)
		end
	end
	return found
end

-- a422 : une plaque déjà sonnée au contact et pas appariée (hausse arrivée plus de MatchWindow s après le remote) est
-- prise ici, pour que l'encaissement d'avant ne rejoue pas Cash_Collect : un seul son par plaque.
local function takeSounded(): boolean
	if not FLASH_ON then
		return false
	end
	local now = os.clock()
	for _, note in padNotes do
		if note.sounded and not note.claimed and now - note.at <= CashFlash.MatchWindow + CashFlash.LandTimeout then
			note.claimed = true
			return true
		end
	end
	return false
end

local function pruneNotes()
	local now = os.clock()
	local keep = CashFlash.MatchWindow + CashFlash.LandTimeout + 1
	for index = #padNotes, 1, -1 do
		local note = padNotes[index]
		if (note.claimed and note.landed) or now - note.at > keep then
			table.remove(padNotes, index)
		end
	end
end

-- Hausse de CashCollected (plaque, encaissement automatique ou gains hors ligne) : à une plaque vue, ou elle l'attend.
local function padOrClassic(total: number, releases: { () -> () })
	local notes = claimNotes()
	if #notes > 0 then
		padJuice(total, releases, notes)
		return
	end
	local waiting: PadWait = { total = total, releases = releases, done = false }
	table.insert(padWaits, waiting)
	task.delay(CashFlash.MatchWindow, function()
		if waiting.done then
			return
		end
		waiting.done = true
		local index = table.find(padWaits, waiting)
		if index then
			table.remove(padWaits, index)
		end
		classic(waiting.total, waiting.releases, true) -- aucune plaque : encaissement automatique, comme avant
	end)
end

-- Au contact d'une plaque : son (a422) et voile ; renvoie true si le son est parti.
local function contactFx(now: number): boolean
	-- a422 (Cantin, 24/11) : le son part au contact, avant tout le reste ; gains hors ligne ouverts : classic le joue.
	local sounded = CONTACT_SOUND and not screenOpen(offline)
	if sounded then
		padSound()
	end
	local rank = GainController.FlashRank(flashRank, now - flashLastAt)
	flashRank = rank
	flashLastAt = now
	local ok, err = pcall(flashVeil :: any, rank)
	if not ok then
		warnOnce("cashFlashError", `[Gains] voile de la plaque : {err}`)
	end
	return sounded
end

------------------------------------------------------------------------------
-- a472 (L-365 point 5) : ramassage prévu par le client (Config/CashFlash.Predict, Shared/PadZone)
------------------------------------------------------------------------------
-- Chaque image, le HumanoidRootPart du joueur local est comparé aux plaques CollectPad_xx de SA parcelle avec la règle
-- du serveur (PadZone.step, et PadZone.touched au Touched d'une plaque) : arrivée, délai de la plaque écoulé, plaque
-- affichée (AmountGui allumé). Alors contactFx tout de suite (son et voile) et la plaque est notée `predicted` ; son
-- remote CashCollect, arrivé moins de ConfirmWindow s après, ne rejoue ni l'un ni l'autre et fait le reste comme avant
-- (compteur retenu jusqu'au premier billet, « +$X » à la hausse de Cash du serveur). Rien n'est prévu de l'argent.

local PREDICT: any = if CashFlash and type(CashFlash.Predict) == "table" then CashFlash.Predict else nil
local PREDICT_ON: boolean = FLASH_ON and CONTACT_SOUND and PREDICT ~= nil and PREDICT.Enabled == true
local PLOT_TAG = "PlayerPlot" -- Contract/Models.Plot.Tag
local OWNER_ATTRIBUTE = "OwnerUserId" -- posé par PlotService sur la parcelle
local PAD_PATTERN = "^CollectPad_(%d+)$" -- comme DisplayService
local AMOUNT_GUI = "AmountGui" -- comme DisplayService : allumé quand la plaque porte au moins 1 $
local PLOT_RECHECK = 1 -- V0 proposé, absent du doc : s entre deux recherches de sa parcelle
local padZone: any = nil -- Shared/PadZone
local predictTracker: any = nil
local predicted: { [number]: number } = {} -- [plaque] = os.clock() du son prévu, en attente de son remote
local ownPlot: Instance? = nil
local ownPads: { [number]: BasePart } = {}
local padsDirty = true
local plotCheckedAt = -math.huge
local plotLinks: { RBXScriptConnection } = {}
local predictCount = 0 -- pour les bancs : sons prévus
local confirmCount = 0 -- pour les bancs : remotes qui ont confirmé une prévision

local function padShown(slot: number): boolean
	local pad = ownPads[slot]
	local gui = if pad then Find.path(pad, AMOUNT_GUI) else nil
	return gui ~= nil and gui:IsA("LayerCollector") and (gui :: LayerCollector).Enabled
end

local function predictPad(slot: number)
	if screenOpen(offline) then
		return -- gains hors ligne ouverts : l'encaissement d'avant (classic) joue Cash_Collect au remote
	end
	local now = os.clock()
	predicted[slot] = now
	predictCount += 1
	contactFx(now)
end

local function localRoot(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root :: BasePart else nil
end

local function onOwnPadTouched(slot: number, hit: BasePart)
	local character = localPlayer.Character
	local root = localRoot()
	if character == nil or root == nil or not hit:IsDescendantOf(character) or not ownPads[slot] then
		return
	end
	local zone: any = padZone
	local found = zone.touched(predictTracker, os.clock(), root.Position, ownPads, slot, padShown)
	if found then
		predictPad(found)
	end
end

local touchLinked: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function scanOwnPads()
	padsDirty = false
	local pads: { [number]: BasePart } = {}
	local plot = ownPlot
	if plot then
		for _, descendant in plot:GetDescendants() do
			local digits = string.match(descendant.Name, PAD_PATTERN)
			local slot = if digits then tonumber(digits) else nil
			if slot and descendant:IsA("BasePart") and not pads[slot] then
				local part = descendant :: BasePart
				pads[slot] = part
				if not touchLinked[part] then
					touchLinked[part] = true
					-- Contact d'un pied, comme le Touched du serveur (pcall : une plaque sans Touched compte à l'image).
					pcall(function()
						part.Touched:Connect(function(hit: BasePart)
							if ownPads[slot] == part then
								onOwnPadTouched(slot, hit)
							end
						end)
					end)
				end
			end
		end
	end
	ownPads = pads
end

local function setOwnPlot(plot: Instance?)
	if plot == ownPlot then
		return
	end
	for _, link in plotLinks do
		link:Disconnect()
	end
	table.clear(plotLinks)
	ownPlot = plot
	padsDirty = true
	if predictTracker then
		predictTracker.onSlot = nil
	end
	if plot then
		local function mark(inst: Instance)
			if string.match(inst.Name, PAD_PATTERN) then
				padsDirty = true
			end
		end
		table.insert(plotLinks, plot.DescendantAdded:Connect(mark))
		table.insert(plotLinks, plot.DescendantRemoving:Connect(mark))
	end
end

local function predictTick()
	local now = os.clock()
	if now - plotCheckedAt >= PLOT_RECHECK then
		plotCheckedAt = now
		local mine: Instance? = nil
		for _, plot in CollectionService:GetTagged(PLOT_TAG) do
			if plot:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId then
				mine = plot
				break
			end
		end
		setOwnPlot(mine)
	end
	if padsDirty then
		scanOwnPads()
	end
	for slot, at in predicted do
		if now - at > PREDICT.ConfirmWindow then
			predicted[slot] = nil -- pas de remote : le serveur a refusé, rien d'autre ne bouge
		end
	end
	if next(ownPads) == nil then
		return
	end
	local root = localRoot()
	local zone: any = padZone
	local found = zone.step(predictTracker, now, if root then root.Position else nil, ownPads, padShown)
	if found then
		predictPad(found)
	end
end

-- Pour les bancs : ramassages prévus par le client.
function GainController.GetPredictState(): { On: boolean, Predicted: number, Confirmed: number, Pads: number, Waiting: number }
	local pads = 0
	for _ in ownPads do
		pads += 1
	end
	local waiting = 0
	for _ in predicted do
		waiting += 1
	end
	return { On = PREDICT_ON and padZone ~= nil, Predicted = predictCount, Confirmed = confirmCount, Pads = pads, Waiting = waiting }
end

-- DisplayController.OnCollect : une de ses plaques vidée par le joueur local (remote CashCollect).
local function onPadCollect(_amount: number?, slot: number?)
	local now = os.clock()
	local sounded: boolean
	local at = if type(slot) == "number" then predicted[slot] else nil
	if at and slot and now - at <= PREDICT.ConfirmWindow then
		predicted[slot] = nil -- a472 : son et voile déjà partis à l'arrivée prévue
		confirmCount += 1
		sounded = true
	else
		if at and slot then
			predicted[slot] = nil -- prévision trop vieille (le serveur l'avait refusée) : ce remote est un autre ramassage
		end
		sounded = contactFx(now)
	end
	if predictTracker and type(slot) == "number" then
		padZone.confirm(predictTracker, slot, now) -- le délai de la plaque repart, comme au serveur
	end
	local note: PadNote = { at = now, landed = not vfxLands, claimed = false, sounded = sounded, onLand = nil }
	pruneNotes()
	table.insert(padNotes, note)
	local waiting = padWaits[1]
	if waiting then
		table.remove(padWaits, 1)
		waiting.done = true
		padJuice(waiting.total, waiting.releases, { note })
	end
end

-- VfxController.OnCollectLanded : premier billet d'une plaque arrivé (dans l'ordre des plaques).
local function onPadLanded()
	for _, note in padNotes do
		if not note.landed then
			note.landed = true
			local callback = note.onLand
			if callback then
				note.onLand = nil
				callback()
			end
			break
		end
	end
	pruneNotes()
end

-- Pour les bancs : état du « jus » des plaques.
function GainController.GetPadState(): { Rank: number, Notes: number, Waiting: number, FlashToken: number }
	return { Rank = flashRank, Notes = #padNotes, Waiting = #padWaits, FlashToken = flashToken }
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
	-- a317 (L-299) : une hausse de CashCollected (hors gains hors ligne) va d'abord voir si c'est une plaque vidée.
	if fromPad and FLASH_ON and not screenOpen(offline) then
		padOrClassic(total, releases)
		return
	end
	classic(total, releases, fromPad)
end

-- Classement d'avant a317 (toujours celui de l'encaissement automatique, des gains hors ligne, des récompenses…).
function classic(total: number, releases: { () -> () }, fromPad: boolean)
	-- Vague 59 (L-184 point 3) : récompense ou prime de l'index, jamais un revenu de la base (plaque, encaissement
	-- automatique : CashCollected monte aussi ; gains hors ligne) : billets qui volent, avec ou sans FLY.Enabled.
	if not fromPad and not screenOpen(offline) and (screenOpen(rewards) or indexOpen()) then
		billFly(total, releases)
		return
	end
	if not FLY.Enabled then
		-- a401 (vague GC4, vidéo de Cantin) : un revenu de la base (hors gains hors ligne) est confié à
		-- CollectFeelController : le chiffre reste retenu jusqu'à la 1re arrivée des billets (sursaut, Cash_Collect et
		-- tics là-bas), ou défile comme ci-dessous s'il n'y a pas de billets ; le « +$X » part tout de suite.
		local feel = collectFeel
		if fromPad and feel and not screenOpen(offline) then
			local ok, held = pcall(feel.Hold, total, releases)
			if ok and held == true then
				showGain(CASH, total)
				return
			end
		end
		-- Sans case qui vole (L-091, retour de Clément) : l'argent défile tout de suite, le compteur sursaute,
		-- et un ramassage, des gains hors ligne réclamés ou une récompense montrent « +$X » au-dessus du joueur.
		releaseAll(releases)
		bump(hudRefs())
		if fromPad and not takeSounded() then -- a422 : pas un 2e son pour une plaque déjà sonnée au contact
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

-- Un gain du tapis peut voler maintenant ; sinon (réglage coupé, animations réduites) : l'ancien « +X » qui monte sur
-- place. Ni plafond ni poursuite (fusion58, Cantin) : un gain par seconde, et le tapis est en zone safe.
local function canFly(): boolean
	local spec = TRAIN_FLY
	return spec ~= nil
		and spec.Enabled == true
		and not reducedMotion()
end

-- La copie qui vole : le modèle facultatif de Clément (UI_HUD.TrainGainFly.Template), sinon une copie de BB_Gain.Row
-- dans un cadre transparent fait ici ; renvoie aussi le modèle qui porte les attributs <Sorte>Color et <Sorte>Icon, et
-- vrai pour le cadre fait ici (vague 65 : son Amount ne passe pas à la ligne, widenToText l'élargit).
local function makeFlyer(screen: ScreenGui): (GuiObject?, Instance?, boolean)
	local spec = TRAIN_FLY
	local template = typed(screen, spec.Template, "GuiObject") :: GuiObject?
	if template then
		local copy = template:Clone()
		copy.Name = spec.Name
		copy.Visible = true
		return copy, template, false
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("UI") else nil
	local billboard = if folder then folder:FindFirstChild(GAIN_TEMPLATE) else nil
	local row = if billboard then typed(billboard, "Row", "GuiObject") :: GuiObject? else nil
	if billboard == nil or row == nil then
		return nil, nil, false
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
	-- Vague 70 (a232) : plus de TextWrapped = false ici (il coupait TextScaled) ; une ligne : cadre élargi (widenToText).
	copy.Parent = holder
	return holder, billboard, true
end

-- Vague 65 (a215) : le cadre fait ici (`holder`, en px, sans UIScale) s'élargit pour que le texte de `label` tienne sur
-- une ligne à la hauteur de son cadre (TextScaled : taille ≈ hauteur, au plus 100 ou MaxTextSize), plus TextMargin ; sa
-- hauteur ne change pas. Texte plus court : rien ne change. Tailles calculées depuis les UDim2 (Amount enfant de la
-- copie de Row, qui remplit le cadre) : AbsoluteSize n'est pas forcément à jour avant le premier rendu.
local function widenToText(holder: GuiObject, label: TextLabel)
	local width, height = holder.Size.X.Offset, holder.Size.Y.Offset
	local parent = label.Parent
	if parent == nil or parent.Parent ~= holder then
		return -- Amount plus profond dans Row : rien d'élargi (il tient quand même sur une ligne, en plus petit)
	end
	local sx, ox = label.Size.X.Scale, label.Size.X.Offset
	local box = Vector2.new(sx * width + ox, label.Size.Y.Scale * height + label.Size.Y.Offset)
	if box.X <= 0 or box.Y <= 0 or sx <= 0 then
		return
	end
	local size = math.min(box.Y, 100)
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		size = math.min(size, limit.MaxTextSize)
	end
	local text = if label.RichText then (string.gsub(label.Text, "<[^>]*>", "")) else label.Text
	local need = textWidth(label, text) * size / 100 * (1 + TRAIN_FLY.TextMargin)
	if need > box.X then
		holder.Size = UDim2.fromOffset((need - ox) / sx, height)
	end
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
	local flyer, source, built = makeFlyer(screen)
	if flyer == nil or source == nil then
		warnOnce("trainFly", `[Gains] UI_HUD.{spec.Template} et {GAIN_TEMPLATE}.Row absents : le gain monte sur place`)
		return false
	end
	local from = start :: Vector2
	local dressed = dressGain(flyer, source, kind, amount, text)
	-- Vague 65 : le repli s'élargit à son texte (une ligne) avant de partir. a233 : avant d'être à l'écran (la mesure
	-- d'un texte neuf attend un peu).
	if built and dressed.amount then
		widenToText(flyer, dressed.amount)
	end
	local size = screen.AbsoluteSize
	flyer.AnchorPoint = Vector2.new(0.5, 0.5)
	flyer.Position = UDim2.fromOffset(from.X, from.Y)
	flyer.Parent = screen
	local scale = Instance.new("UIScale")
	scale.Name = COPY_SCALE
	scale.Scale = spec.PopFrom
	scale.Parent = flyer
	active.TrainFlies += 1
	local angle = math.rad((random:NextNumber() * 2 - 1) * spec.JetAngle)
	local distance = size.X * (spec.JetMin + random:NextNumber() * (spec.JetMax - spec.JetMin))
	local edgeX, edgeY = size.X * spec.Edge, size.Y * spec.Edge
	local jetX = math.clamp(from.X + math.sin(angle) * distance, edgeX, math.max(edgeX, size.X - edgeX))
	local jetY = math.clamp(from.Y - math.cos(angle) * distance, edgeY, math.max(edgeY, size.Y - edgeY))
	-- Vague 67 (a224) : taille pleine = TrainGainFly.Scale (« tu grossis le tout »).
	TweenService:Create(scale, TweenInfo.new(spec.PopTime, spec.PopStyle, Enum.EasingDirection.Out), { Scale = TRAIN_SCALE }):Play()
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
		TweenService:Create(scale, info, { Scale = spec.EndScale * TRAIN_SCALE }):Play()
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

-- Vague 65 (a215) : la part de la hausse `amount` de Speed venue d'une bulle annoncée (NoteBubble) depuis moins de
-- BubbleGain.Window s ; 0 sans annonce.
local function takeBubble(amount: number): number
	local spec = BUBBLE_GAIN
	if spec == nil or bubblePending <= 0 then
		return 0
	end
	if os.clock() - bubbleAt > spec.Window then
		bubblePending = 0
		return 0
	end
	local part = math.min(amount, bubblePending)
	bubblePending -= part
	return part
end

-- Vague 65 (a215) : « +32 Speed » d'une bulle (gain unique, sans « /s ») : il vole jusqu'au compteur comme celui du
-- tapis (nombre retenu depuis `previous`), sinon monte sur place.
local function showBubble(amount: number, previous: number)
	local text = string.format(BUBBLE_GAIN.Text, Format.short(amount))
	if canFly() then
		local release = holdSpeed(shownSpeed(previous))
		if flyGain(SPEED, amount, text, nil, { release }, 1, 1) then
			return
		end
		release()
	end
	floatGain(SPEED, amount, nil, text)
	pulseSpeed(1, 1)
end

function GainController.NoteBubble(gain: number)
	if type(gain) ~= "number" or not (gain > 0 and gain < math.huge) or BUBBLE_GAIN == nil then
		return
	end
	local now = os.clock()
	if now - bubbleAt > BUBBLE_GAIN.Window then
		bubblePending = 0 -- annonce trop vieille, jamais vue monter : oubliée
	end
	bubblePending += gain
	bubbleAt = now
end

-- a480 : le gain d'une seconde du tapis, en Speed finale (Formulas.ShownSpeed, trail compris, comme le HUD), découpé en
-- GainPops.PerSecond apparitions autour du joueur réparties sur Period s, même total ; le compteur pulse à chacune.
-- false si la première n'a pas pu s'afficher (l'appelant fait l'affichage d'avant).
local function showPops(amount: number): boolean
	local spec = POPS
	local pieces: { number } = GainPops.Split(shownSpeed(amount), spec.PerSecond, spec.MinPiece)
	local count = #pieces
	if count == 0 then
		return true
	end
	if not popWorld(SPEED.Text(pieces[1])) then
		return false
	end
	pulseSpeed(1, count)
	local gap = spec.Period / count
	for rank = 2, count do
		task.delay(gap * (rank - 1), function()
			if popWorld(SPEED.Text(pieces[rank])) then
				pulseSpeed(rank, count)
			end
		end)
	end
	return true
end

local function onTraining(kind: Kind)
	local amount, previous = riseOf(kind.Attribute)
	if amount > 0 and localPlayer:GetAttribute(MACHINE_ATTRIBUTE) == kind.Machine then
		local before: number = previous or 0 -- une hausse a toujours une valeur d'avant
		if kind == SPEED then
			-- Vague 65 : la part d'une bulle part d'abord, avec son texte ; le reste (seconde du tapis) comme avant.
			local bubble = takeBubble(amount)
			if bubble > 0 then
				showBubble(bubble, before)
				amount -= bubble
				before += bubble
				if amount <= 1e-6 * bubble then
					return -- écart d'arrondi seulement
				end
			end
		end
		if kind == SPEED and POPS ~= nil and showPops(amount) then
			return -- a480 : autour du joueur, dans le monde 3D
		elseif kind == SPEED and TREAD ~= nil and CHUNKS > 1 then
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
	collectFeel = sibling("CollectFeelController") -- a401 : chiffre relâché à l'arrivée des billets d'une plaque
	-- a317 (L-299) : plaques vidées par le joueur local, et arrivée de leur premier billet au compteur.
	if FLASH_ON then
		local okSounds, sounds = pcall(function(): any
			local anim = Shared:FindFirstChild("Anim")
			local module = if anim then anim:FindFirstChild("MarkerSounds") else nil
			return if module and module:IsA("ModuleScript") then require(module) :: any else nil
		end)
		markerSounds = if okSounds then sounds else nil
		-- a422 : le son de la plaque est préchargé, pour que même la première plaque sonne au contact (sinon le premier
		-- Play attend le téléchargement du son).
		task.spawn(function()
			pcall(function()
				local list: { Instance } = {}
				for _, name in { CashFlash.Sound, CashFlash.FallbackSound } do
					local found: any = if markerSounds and name then markerSounds.find(name) else nil
					if found ~= nil then
						table.insert(list, found)
					end
				end
				if #list > 0 then
					game:GetService("ContentProvider"):PreloadAsync(list)
				end
			end)
		end)
		local vfx: any = sibling("VfxController")
		local onLanded: any = if vfx then vfx.OnCollectLanded else nil
		if type(onLanded) == "function" then
			(onLanded :: any)(onPadLanded)
			vfxLands = true
		end
		local display: any = sibling("DisplayController")
		local onCollect: any = if display then display.OnCollect else nil
		if type(onCollect) == "function" then
			(onCollect :: any)(onPadCollect)
			-- a472 (L-365 point 5) : ramassage prévu par le client (Features.PadPredict / PadPredictDev).
			if PREDICT_ON then
				local module = Shared:FindFirstChild("PadZone")
				local okZone, zone = pcall(function(): any
					return if module and module:IsA("ModuleScript") then require(module) :: any else nil
				end)
				if okZone and type(zone) == "table" then
					padZone = zone
					predictTracker = (zone :: any).newTracker()
					RunService.Heartbeat:Connect(function()
						local ok, err = pcall(predictTick :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
						if not ok then
							warnOnce("padPredict", `[Gains] ramassage prévu : {err}`)
						end
					end)
				else
					warnOnce("padPredict", "[Gains] Shared/PadZone absent : son et voile au remote CashCollect, comme avant")
				end
			end
		end
	end
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
