--!strict
-- Motion (DEV-052, client) : animations d'UI sur les écrans de Clément, sans toucher à leur visuel
-- (Partie 1, section 2.2, « Libre pour Ironix : … animer à l'ouverture et à la fermeture »). Module
-- d'aide des contrôleurs, rangé dans le sous-dossier UI : le Loader ne le démarre pas.
--
-- API (client) :
--   Motion.Open(gui)            Enabled = true, puis entrée des cadres racine de l'écran (échelle
--                               Open.From → 1, léger rebond), puis ses cartes une à une (OpenStagger :
--                               cadres avec HoverOutline, sinon enfants de Rows, Tree, Body,
--                               DailyPage ; UIScale passager OpenStagger.ScaleName). Déjà allumé : pas
--                               d'entrée (il compte comme ouvert). En train de se fermer : la fermeture
--                               est annulée et l'écran revient à 1.
--   Motion.Swap(gui, change)    changement d'onglet (L-094) : les cartes visibles sortent (Swap), puis
--                               change() (le contrôleur change de page), puis les nouvelles cartes
--                               entrent comme OpenStagger. Écran éteint ou sans carte : change() tout
--                               de suite. change() est toujours fait, une seule fois.
--   Motion.GetStaggerCount(gui) cartes encore en train d'entrer ou de sortir (banc).
--   Motion.Close(gui, after?)   sortie courte (1 → Close.To), puis Enabled = false, puis after().
--                               Fermé tout de suite, sans animation : un écran déjà fermé, un écran
--                               allumé que Motion n'a jamais vu (copie de StarterGui arrivée
--                               allumée) ou retiré du jeu. after n'est pas appelé si une réouverture
--                               annule la fermeture.
--   Motion.KeepScale(object)    ce cadre racine s'anime à part (RunBanner) : Open et Close de son
--                               écran ne le mettent pas à l'échelle (L-092 3a).
--   Motion.Show(object)       la même chose pour un élément (Visible au lieu d'Enabled), mis
--   Motion.Hide(object, after?)   à l'échelle lui-même (Show.From, Hide.To) : HeistTimer, GuardMeter.
--   Motion.Button(button)       survol (Hover.To, calque Shade à Hover.ShadeTransparency, son
--   Motion.Hover(button)          Hover.Sound), appui (Press), relâché (Release : retour à 1 ou au
--                               survol) ; UIScale Hover.ScaleName, retiré dès que le bouton est revenu
--                               à 1 ; Shade remis à sa transparence d'origine. Toucher fini (tactile,
--                               sans MouseLeave) : retour à 1 (L-092 3g). Hover = ancien nom.
--                               a286 (L-224 point 2) : une croix (Hover.CloseNames) grossit à Hover.CloseTo
--                               (+7 %) en Hover.SizedTime (133 ms).
--   Motion.Success(button)      le bouton saute à Success.From et revient ; son Success.Sound.
--                               Vague 66 (a222, L-210 point 9, HoverFit) : un bouton dans une carte de liste
--                               (sous une ScrollingFrame) grossit au plus jusqu'au bord de sa carte (survol,
--                               rebond de Squash, réussite) ; ailleurs, comme avant.
--   Motion.HoverCard(card)      carte survolée : HoverOutline visible, Icon grossi, penché, décalé ;
--                               tout revient à la sortie (L-091 point 7).
--                               a286 (L-224 point 2) : la carte elle-même grossit à Hover.CardTo (+3 %) en
--                               Hover.SizedTime, par un UIScale passager (aucun si elle en a déjà un).
--                               Vague 59 (L-182) : attribut Hover = Pop sur un bouton : × HoverPop.To en
--                               HoverPop.Time ; sur une carte : elle penche de CardTilt et son Icon grossit
--                               (IconScale) sans bouger. Press = Squash : × PressSquash.To tant que le
--                               bouton est tenu, puis 1,1 et retour au relâché.
--   Motion.Activated(button)    a290 (L-270, Config/UiMotion.ClickZone) : le signal de clic d'un bouton, à brancher à
--                               la place de button.Activated : l'Activated de Roblox, plus le relâché sur la taille
--                               réelle du bouton (ou sa taille survolée au moment de l'appui) que Roblox n'a pas pris
--                               parce que le UIScale de l'appui (Press, Squash) rétrécit aussi sa zone de clic. Un seul
--                               clic par appui ; glissé hors de la zone ou liste défilée : pas de clic. Rien ne change
--                               à l'écran ; la souris qui sort du bouton écrasé sans sortir de la zone le laisse écrasé.
--   Motion.Click(button, play)  joue le clic (play) à la fin de l'image, sauf si l'action a déjà son son
--                               (bouton de réussite, ou UI_Open / UI_Close… au même moment) : un son par action.
--   Close et Hide attendent la fermeture des éléments Appear (Controllers/UI/Appear) ; Open et Close ne
--   mettent pas à l'échelle un cadre racine qui porte Appear, ni OpenStagger les cartes d'une Cascade.
--   Vague 64 (a212) : réglage « animations réduites » (Appear.Reduced) : Open, Close, Show, Hide et les cartes
--   (OpenStagger, Swap) se font d'un coup, sans mouvement. Rythme (Config/UiMotion.VideoRhythm) : Open 0,38 s
--   Back Out, Close Back In 0,2 s jusqu'à 0, cartes de gauche à droite (22 ms d'écart, à partir de +230 ms).
--   Motion.Pop(object, from, info)
--                               sursaut passager from → 1 (UIScale PopScaleName détruit à la fin) :
--                               CashBump, TimerTick. Rien sur un objet qui a déjà un autre UIScale.
--   Motion.SetSoundPlayer(play?) / Motion.PlaySound(name)
--                               sons d'UI (UI_Hover, UI_Success…) : joués par la fonction donnée
--                               (UiFeelController), rien sans elle.
--   Motion.Roll(label, from, to, format, info?)
--                               (info : un autre TweenInfo que Roll ; vague 59 : décompte de Cash après un achat)
--                               le nombre défile de `from` à `to`, écrit par `format` à chaque image
--                               (Shared/Format) ; à la fin, exactement format(to). from = nil
--                               (premier remplissage) : format(to) tout de suite, sans défilement.
--                               Pendant un défilement, une nouvelle valeur repart du nombre affiché.
--                               Deux bouts entiers : on défile en entiers (pas de « $57.3 » entre
--                               $50 et $80).
--   Motion.StopRoll(label)      arrête un défilement ; le texte reste tel quel.
--   Motion.GetState(inst)       "Opening", "Open", "Closing", "Closed", ou nil (jamais animé) :
--                               pour un test (banc, barre de commande en Studio).
--   Motion.CloseGroup(gui)      (vague 75) ferme les autres écrans allumés du groupe de gui, comme Open.
--   Motion.SetCloser(gui, close?)
--                               la fonction de fermeture du contrôleur de cet écran (son propre
--                               chemin : état « ouvert », lignes à retirer…), appelée quand un
--                               autre écran du même groupe s'ouvre ; nil la retire.
--
-- Un seul écran à la fois (liaison L-089 point 4) : les ScreenGui qui portent l'attribut
-- ScreenGroup (posé par Clément, ex. « Menu ») forment un groupe. Motion.Open d'un tel écran ferme
-- d'abord les autres écrans allumés du même groupe, rangés à côté de lui (PlayerGui) : par la
-- fonction donnée à SetCloser, sinon par Motion.Close (écran sans contrôleur). Le groupe se lit sur
-- l'attribut, jamais sur une liste de noms ; un écran sans l'attribut ne ferme rien et n'est
-- jamais fermé ainsi.
--
-- Ce qui est touché, et rien d'autre : Enabled de l'écran, Visible de l'élément, Text du label, et
-- un UIScale nommé UiMotion.ScaleName créé ici sur chaque cadre animé, détruit à la fin de chaque
-- animation (à 1 une fois ouvert, ou écran éteint). Aucune couleur, taille, position, image,
-- police ni transparence de Clément ne change durablement : seuls les effets demandés par Clément
-- (L-091 point 7) touchent, le temps du survol, la transparence du calque Shade d'un bouton, et
-- Visible de HoverOutline, Position et Rotation de l'Icon d'une carte, tous remis à leur valeur
-- d'origine ensuite. Pas d'effet d'échelle :
--   - sur un cadre qui a déjà son propre UIScale (posé par Clément) : son UIScale n'est jamais
--     touché, le cadre apparaît et disparaît d'un coup (une ligne dans la sortie, en Studio) ;
--   - sur un cadre racine taillé à tout l'écran (voile, fond : Size en Scale ≥ 1 sur les deux
--     axes) : réduit, il découvrirait les bords de l'écran.
-- Animations par TweenService : rien ne tourne quand rien ne bouge. La fin d'une animation est
-- celle de ses tweens (Tween.Completed) ; un jeton par écran écarte les fins d'animations
-- remplacées. Valeurs (durées, échelles, styles) dans Config/UiMotion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiMotion"))

export type Phase = "Opening" | "Open" | "Closing" | "Closed"

-- Une animation d'entrée ou de sortie : échelle de départ (entrée) ou d'arrivée (sortie), tween.
-- Vague 74 (L-259) : `peak` = échelle de passage (premier tween en `peakInfo`, puis `info` jusqu'au but) ; nil : un seul tween.
type Transition = { scale: number, info: TweenInfo, peak: number?, peakInfo: TweenInfo? }

-- Un écran ou un élément animé par Motion.
type Entry = {
	phase: Phase,
	token: number, -- change à chaque animation : une fin d'animation remplacée est ignorée
	tweens: { Tween },
	scales: { [GuiObject]: UIScale }, -- UIScale créés ici, par cadre animé
	after: { () -> () }, -- suites de la fermeture en cours
}

-- Un chiffre qui défile.
type Rolling = {
	token: number,
	value: NumberValue,
	tween: Tween,
	connection: RBXScriptConnection,
	to: number,
	integers: boolean,
}

local OPEN: Transition = {
	scale = UiMotion.Open.From,
	info = TweenInfo.new(UiMotion.Open.Time, UiMotion.Open.Style, UiMotion.Open.Direction),
	peak = UiMotion.Open.Peak,
	peakInfo = TweenInfo.new(UiMotion.Open.PeakTime, UiMotion.Open.PeakStyle, UiMotion.Open.PeakDirection),
}
local CLOSE: Transition = {
	scale = UiMotion.Close.To,
	info = TweenInfo.new(UiMotion.Close.Time, UiMotion.Close.Style, UiMotion.Close.Direction),
	peak = UiMotion.Close.Peak,
	peakInfo = TweenInfo.new(UiMotion.Close.PeakTime, UiMotion.Close.PeakStyle, UiMotion.Close.PeakDirection),
}
local SHOW: Transition = {
	scale = UiMotion.Show.From,
	info = TweenInfo.new(UiMotion.Show.Time, UiMotion.Show.Style, UiMotion.Show.Direction),
}
local HIDE: Transition = {
	scale = UiMotion.Hide.To,
	info = TweenInfo.new(UiMotion.Hide.Time, UiMotion.Hide.Style, UiMotion.Hide.Direction),
}
local STAGGER = UiMotion.OpenStagger
local STAGGER_INFO = TweenInfo.new(STAGGER.Time, STAGGER.Style, STAGGER.Direction)
local SWAP_OUT_INFO = TweenInfo.new(UiMotion.Swap.OutTime, UiMotion.Swap.Style, UiMotion.Swap.Direction)
local ROLL_INFO = TweenInfo.new(UiMotion.Roll.Time, UiMotion.Roll.Style, UiMotion.Roll.Direction)
local HOVER_INFO = TweenInfo.new(UiMotion.Hover.Time, UiMotion.Hover.Style, UiMotion.Hover.Direction)
-- a286 (L-224 point 2) : survol d'une croix (Hover.CloseTo) et d'une carte (Hover.CardTo), en Hover.SizedTime.
local SIZED_INFO = TweenInfo.new(UiMotion.Hover.SizedTime, UiMotion.Hover.Style, UiMotion.Hover.Direction)
local CLOSE_NAMES: { [string]: boolean } = {}
for _, name in UiMotion.Hover.CloseNames do
	CLOSE_NAMES[name] = true
end

local IS_STUDIO = RunService:IsStudio()

-- Vague 59 (a189, L-182 point 1) : apparitions posées par Clément en attribut Appear (Controllers/UI/Appear). Un cadre
-- racine qui porte Appear n'est pas mis à l'échelle par Open et Close (Appear l'anime), les cartes d'une Cascade
-- n'entrent pas par OpenStagger, et Close (ou Hide) attend la fin de leur fermeture. Module absent (banc qui ne
-- monte que Motion) : rien de tout cela, Motion fait comme avant.
type AppearApi = {
	Has: (Instance) -> boolean,
	Covers: (Instance) -> boolean,
	Open: (Instance) -> (),
	Close: (Instance) -> number,
	Reset: (Instance) -> (),
	Reduced: () -> boolean,
}
local appear: AppearApi = (function(): AppearApi
	local module = script.Parent:FindFirstChild("Appear")
	if module ~= nil and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			return result :: any
		end
	end
	return {
		Has = function(_: Instance): boolean
			return false
		end,
		Covers = function(_: Instance): boolean
			return false
		end,
		Open = function(_: Instance) end,
		Close = function(_: Instance): number
			return 0
		end,
		Reset = function(_: Instance) end,
		Reduced = function(): boolean
			return false
		end,
	}
end)()
-- Hover = Pop et Press = Squash (L-182 point 1) : variantes de Motion.Button et Motion.HoverCard, lues sur le bouton
-- (ou la carte) à chaque survol et appui (une copie de Template garde les attributs de son modèle).
local HOVER_ATTRIBUTE = "Hover"
local PRESS_ATTRIBUTE = "Press"
local HOVER_POP = "Pop"
local PRESS_SQUASH = "Squash"

local Motion = {}

-- Clés faibles : un écran détruit (ResetOnSpawn) n'est pas retenu ici.
local entries: { [Instance]: Entry } = setmetatable({}, { __mode = "k" }) :: any
local owners: { [UIScale]: Entry } = setmetatable({}, { __mode = "k" }) :: any -- UIScale créés ici
local rolls: { [TextLabel]: Rolling } = setmetatable({}, { __mode = "k" }) :: any
local noticed: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local closers: { [Instance]: () -> () } = setmetatable({}, { __mode = "k" }) :: any -- SetCloser
local apart: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- KeepScale : animés à part
local rollTokens = 0

-- Contrat (L-089 point 4) : attribut des ScreenGui de Clément, sa valeur nomme le groupe.
local GROUP_ATTRIBUTE = "ScreenGroup"

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

-- Survol réservé à l'élément du dessus (vague 25, retour de Cantin du 2026-11-11) : Roblox envoie
-- MouseEnter à tous les éléments sous la souris, même recouverts (un onglet de mutation de l'Index
-- au-dessus d'un bouton de LeftRail faisait grossir ce bouton). Un élément n'accepte le survol que
-- s'il est le premier élément actif sous la souris (PlayerGui:GetGuiObjectsAtPosition, du plus haut
-- au plus bas) : avant lui, ni GuiButton, ni GuiObject Active, ni élément visible d'un autre écran
-- de groupe (ScreenGroup, ex. « Menu ») allumé. Coordonnées : la souris moins le décalage du haut
-- de l'écran (GetGuiInset), sinon telle quelle ; élément absent des deux listes (coordonnées
-- inconnues, tests) : survol accepté, comme avant.
local function ancestorOf(object: Instance, class: string): Instance?
	local parent = object.Parent
	while parent do
		if parent:IsA(class) then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end

local function screenOf(object: Instance): ScreenGui?
	local found = ancestorOf(object, "ScreenGui")
	return if found then found :: ScreenGui else nil
end

local function within(hit: GuiObject, object: GuiObject): boolean
	return hit == object or hit:IsDescendantOf(object)
end

-- Un élément d'un écran de groupe qui se voit (fond ou image), pas un simple cadre transparent.
local function seen(hit: GuiObject): boolean
	if hit.BackgroundTransparency < 1 then
		return true
	end
	if hit:IsA("ImageLabel") or hit:IsA("ImageButton") then
		local image = hit :: any
		return image.Image ~= "" and image.ImageTransparency < 1
	end
	return false
end

local function firstIs(object: GuiObject, hits: { GuiObject }): boolean
	local own = screenOf(object)
	for _, hit in hits do
		if within(hit, object) then
			return true
		end
		if hit:IsA("GuiButton") or hit.Active then
			return false
		end
		local screen = screenOf(hit)
		if screen and screen ~= own and screen.Enabled and type(screen:GetAttribute(GROUP_ATTRIBUTE)) == "string"
			and seen(hit) then
			return false
		end
	end
	return true
end

local function onTop(object: GuiObject): boolean
	local playerGui = ancestorOf(object, "PlayerGui")
	if playerGui == nil then
		return true
	end
	local ok, mouse, inset = pcall(function(): (Vector2, Vector2)
		local inputs = game:GetService("UserInputService")
		local guis = game:GetService("GuiService")
		local topLeft = guis:GetGuiInset()
		return inputs:GetMouseLocation(), topLeft
	end)
	if not ok then
		return true
	end
	for _, point in { mouse - inset, mouse } do
		local found, hits = pcall(function(): { GuiObject }
			return (playerGui :: any):GetGuiObjectsAtPosition(point.X, point.Y)
		end)
		if found and type(hits) == "table" then
			for _, hit in hits do
				if within(hit, object) then
					return firstIs(object, hits)
				end
			end
		end
	end
	return true
end

function Motion.IsOnTop(object: GuiObject): boolean
	return onTop(object)
end

local function isShown(inst: Instance): boolean
	if inst:IsA("ScreenGui") then
		return (inst :: ScreenGui).Enabled
	elseif inst:IsA("GuiObject") then
		return (inst :: GuiObject).Visible
	end
	return false
end

local function setShown(inst: Instance, shown: boolean)
	if inst:IsA("ScreenGui") then
		(inst :: ScreenGui).Enabled = shown
	elseif inst:IsA("GuiObject") then
		(inst :: GuiObject).Visible = shown
	end
end

-- « UI_WeaponShop.Root » : le chemin depuis l'écran, pour la sortie.
local function pathOf(inst: Instance): string
	local names = { inst.Name }
	local current = inst.Parent
	while current ~= nil and not current:IsA("PlayerGui") and not current:IsA("StarterGui") do
		table.insert(names, 1, current.Name)
		if current:IsA("LayerCollector") then
			break
		end
		current = current.Parent
	end
	return table.concat(names, ".")
end

local function entryOf(inst: Instance): Entry
	local entry = entries[inst]
	if entry == nil then
		local created: Entry = { phase = "Closed", token = 0, tweens = {}, scales = {}, after = {} }
		entries[inst] = created
		return created
	end
	return entry
end

-- Cadre racine taillé à tout l'écran (voile, fond) : pas mis à l'échelle.
local function fillsScreen(object: GuiObject): boolean
	local size = object.Size
	return size.X.Scale >= 1 and size.Y.Scale >= 1
end

-- Cadres à mettre à l'échelle : un élément = lui-même ; un écran = ses cadres racine, sauf ceux
-- qui couvrent tout l'écran et ceux qui s'animent à part (Motion.KeepScale).
local function targetsOf(inst: Instance): { GuiObject }
	if inst:IsA("GuiObject") then
		return if appear.Has(inst) then {} else { inst :: GuiObject } -- vague 59 : un élément Appear s'anime à part
	end
	local list: { GuiObject } = {}
	for _, child in inst:GetChildren() do
		if child:IsA("GuiObject") and not fillsScreen(child :: GuiObject) and not apart[child] and not appear.Has(child) then
			table.insert(list, child :: GuiObject)
		end
	end
	return list
end

-- Le UIScale de cette animation sur `target` (créé à l'échelle `initial` s'il manque), ou nil si le
-- cadre a déjà un UIScale qui n'est pas le sien : celui de Clément, jamais touché.
local function scaleOn(entry: Entry, target: GuiObject, initial: number): UIScale?
	local own = entry.scales[target]
	if own and own.Parent == target then
		return own
	end
	entry.scales[target] = nil
	local existing = target:FindFirstChildOfClass("UIScale")
	if existing ~= nil then
		if owners[existing] == nil and IS_STUDIO and not noticed[target] then
			noticed[target] = true
			print(`[Motion] {pathOf(target)} a déjà un UIScale (celui de Clément) : pas d'effet d'échelle sur ce cadre, il apparaît d'un coup`)
		end
		return nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = UiMotion.ScaleName
	scale.Scale = initial
	owners[scale] = entry
	scale.Parent = target
	entry.scales[target] = scale
	return scale
end

-- Arrête les tweens et retire les UIScale de cette entrée : le cadre retrouve sa taille de Studio.
local function release(entry: Entry)
	for _, tween in entry.tweens do
		tween:Cancel()
	end
	table.clear(entry.tweens)
	for _, scale in entry.scales do
		owners[scale] = nil
		scale:Destroy()
	end
	table.clear(entry.scales)
end

local function runAfter(callbacks: { () -> () })
	for _, callback in callbacks do
		task.spawn(callback) -- une suite en erreur n'empêche pas les autres
	end
end

-- Lance l'animation de `targets` vers l'échelle `goal` ; `start` = échelle de départ imposée (nil :
-- on part de l'échelle actuelle, celle d'une animation interrompue, ou de `fresh` pour un cadre
-- neuf). `finish` est appelé quand tous les tweens sont arrivés, sauf si une autre animation a
-- pris la place entre-temps. L'état (phase, tweens) est posé avant Play : un tween fini tout de
-- suite trouve tout en place.
local function run(entry: Entry, targets: { GuiObject }, start: number?, fresh: number, goal: number, info: TweenInfo, finish: () -> ())
	entry.token += 1
	local token = entry.token
	for _, tween in entry.tweens do
		tween:Cancel()
	end
	table.clear(entry.tweens)
	if appear.Reduced() then
		release(entry) -- vague 64 : animations réduites, aucun mouvement (ouvert ou fermé d'un coup)
		finish()
		return
	end

	local wanted: { [GuiObject]: boolean } = {}
	for _, target in targets do
		wanted[target] = true
	end
	for target, scale in entry.scales do
		if not wanted[target] then -- cadre retiré de l'écran entre-temps
			owners[scale] = nil
			scale:Destroy()
			entry.scales[target] = nil
		end
	end

	local tweens: { Tween } = {}
	for _, target in targets do
		local scale = scaleOn(entry, target, start or fresh)
		if scale ~= nil then
			if start ~= nil then
				scale.Scale = start
			end
			table.insert(tweens, TweenService:Create(scale, info, { Scale = goal }))
		end
	end
	if #tweens == 0 then
		finish()
		return
	end
	entry.tweens = tweens
	local remaining = #tweens
	for _, tween in tweens do
		tween.Completed:Connect(function(state: Enum.PlaybackState)
			if entry.token ~= token or state ~= Enum.PlaybackState.Completed then
				return -- animation remplacée, ou tween annulé
			end
			remaining -= 1
			if remaining == 0 then
				finish()
			end
		end)
	end
	for _, tween in tweens do
		tween:Play()
	end
end

-- Vague 74 (L-259) : comme run, en deux tweens si la transition a un `peak` (départ → peak en peakInfo, puis
-- peak → goal en info). Une autre animation lancée entre les deux (jeton changé) arrête la suite.
local function runTwo(entry: Entry, inst: Instance, start: number?, fresh: number, goal: number, transition: Transition, finish: () -> ())
	local peak, peakInfo = transition.peak, transition.peakInfo
	if peak == nil or peakInfo == nil then
		run(entry, targetsOf(inst), start, fresh, goal, transition.info, finish)
		return
	end
	local second: number = peak
	run(entry, targetsOf(inst), start, fresh, second, peakInfo, function()
		run(entry, targetsOf(inst), nil, second, goal, transition.info, finish)
	end)
end

------------------------------------------------------------------------------
-- Contenu qui arrive après la fenêtre (OpenStagger) et changement d'onglet (Swap), L-094
------------------------------------------------------------------------------

-- Cartes d'un écran animées une à une : leurs UIScale passagers (OpenStagger.ScaleName), les tweens,
-- un jeton (change à chaque nouvelle animation), et le changement de page d'un Swap pas encore fait.
type Stagger = { token: number, scales: { [GuiObject]: UIScale }, tweens: { Tween }, change: (() -> ())? }
local staggers: { [Instance]: Stagger } = setmetatable({}, { __mode = "k" }) :: any
local staggerTokens = 0

local ROWS: { [string]: boolean } = {}
for _, name in STAGGER.Rows do
	ROWS[name] = true
end

-- `object` et ses parents, jusqu'à l'écran, sont visibles.
local function shownIn(object: GuiObject, gui: Instance): boolean
	local current: Instance? = object
	while current ~= nil and current ~= gui do
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		current = current.Parent
	end
	return current == gui
end

-- Cartes visibles de l'écran (un cadre avec un enfant HoverOutline, hors Template) ; sans carte, les
-- enfants visibles des cadres OpenStagger.Rows (prototype ui_feel_proto.luau, staggerItems).
local function staggerItems(gui: Instance): { GuiObject }
	local items: { GuiObject } = {}
	local outline = UiMotion.HoverCard.Outline
	for _, descendant in gui:GetDescendants() do
		if descendant:IsA("GuiObject") and descendant.Name ~= "Template" and descendant:FindFirstChild(outline) ~= nil
			and shownIn(descendant :: GuiObject, gui) then
			table.insert(items, descendant :: GuiObject)
		end
	end
	if #items > 0 then
		return items
	end
	for _, descendant in gui:GetDescendants() do
		if ROWS[descendant.Name] and descendant:IsA("GuiObject") and shownIn(descendant :: GuiObject, gui) then
			for _, child in descendant:GetChildren() do
				if child:IsA("GuiObject") and (child :: GuiObject).Visible and child.Name ~= "Template" then
					table.insert(items, child :: GuiObject)
				end
			end
		end
	end
	return items
end

-- Ordre de lecture : rangée par rangée (à RowTolerance px près), de gauche à droite. Rangée arrondie
-- (et non un écart comparé deux à deux) pour que l'ordre reste cohérent pour table.sort.
local function rowOf(object: GuiObject): number
	return math.floor(object.AbsolutePosition.Y / STAGGER.RowTolerance + 0.5)
end

local function before(a: GuiObject, b: GuiObject): boolean
	local rowA, rowB = rowOf(a), rowOf(b)
	local xA, xB = a.AbsolutePosition.X, b.AbsolutePosition.X
	if rowA ~= rowB then
		return rowA < rowB
	end
	return xA < xB
end

local function runChange(change: () -> ())
	local ok, err = pcall(function()
		change()
	end)
	if not ok and IS_STUDIO then
		warn(`[Motion] changement de page (Swap) en erreur : {err}`)
	end
end

-- Arrête les cartes de l'écran : tweens annulés, UIScale passagers détruits (chaque carte retrouve sa
-- taille), changement de page en attente fait tout de suite.
local function stopStagger(gui: Instance)
	local state = staggers[gui]
	if state == nil then
		return
	end
	staggers[gui] = nil
	state.token = -1
	for _, tween in state.tweens do
		tween:Cancel()
	end
	table.clear(state.tweens)
	for _, scale in state.scales do
		scale:Destroy()
	end
	table.clear(state.scales)
	local change = state.change
	state.change = nil
	if change then
		runChange(change)
	end
end

local function newStagger(gui: Instance): Stagger
	stopStagger(gui)
	staggerTokens += 1
	local state: Stagger = { token = staggerTokens, scales = {}, tweens = {}, change = nil }
	staggers[gui] = state
	return state
end

-- UIScale passager à `value` sur la carte, sauf si elle en a déjà un (celui de Clément, ou d'un effet
-- en cours) : elle n'est alors pas animée.
local function addStaggerScale(state: Stagger, item: GuiObject, value: number): UIScale?
	if item:FindFirstChildOfClass("UIScale") ~= nil then
		return nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = STAGGER.ScaleName
	scale.Scale = value
	scale.Parent = item
	state.scales[item] = scale
	return scale
end

-- La carte a fini (ou a disparu) : son UIScale part ; plus aucune carte : l'écran est oublié.
local function dropStaggerItem(gui: Instance, state: Stagger, item: GuiObject)
	local scale = state.scales[item]
	state.scales[item] = nil
	if scale then
		scale:Destroy()
	end
	if next(state.scales) == nil and state.change == nil and staggers[gui] == state then
		staggers[gui] = nil
	end
end

-- Entrée des cartes (OpenStagger) : toutes à From tout de suite, puis chacune à 1 en Time, la k-ième
-- Start + (k − 1) × Gap s après (k au plus Max), dans l'ordre de lecture (calculé à la fin de l'image,
-- une fois les positions à jour).
local function staggerIn(gui: Instance, items: { GuiObject })
	if appear.Reduced() then
		stopStagger(gui) -- vague 64 : animations réduites, les cartes sont là d'un coup
		return
	end
	local state = newStagger(gui)
	for _, item in items do
		addStaggerScale(state, item, STAGGER.From)
	end
	if next(state.scales) == nil then
		staggers[gui] = nil
		return
	end
	local token = state.token
	task.defer(function()
		if state.token ~= token then
			return
		end
		local list: { GuiObject } = {}
		for item in state.scales do
			table.insert(list, item)
		end
		table.sort(list, before)
		for index, item in list do
			local rank = math.min(index, STAGGER.Max) - 1
			task.delay(STAGGER.Start + rank * STAGGER.Gap, function()
				if state.token ~= token then
					return
				end
				local scale: UIScale? = state.scales[item]
				if not scale then
					return
				end
				if scale.Parent ~= item then
					dropStaggerItem(gui, state, item)
					return
				end
				local tween = TweenService:Create(scale, STAGGER_INFO, { Scale = 1 })
				table.insert(state.tweens, tween)
				tween.Completed:Connect(function(playback: Enum.PlaybackState)
					if playback == Enum.PlaybackState.Completed and state.token == token then
						dropStaggerItem(gui, state, item)
					end
				end)
				tween:Play()
			end)
		end
	end)
end

-- Écran allumé dont le contenu peut changer de page en douceur : ni éteint, ni en train de se fermer.
local function swappable(gui: ScreenGui): boolean
	local entry = entries[gui]
	return gui.Enabled and gui.Parent ~= nil and (entry == nil or entry.phase ~= "Closing") and not appear.Reduced()
end

-- Changement d'onglet (Swap) : sortie des cartes visibles, de la dernière à la première, puis
-- `change()` (le contrôleur change de page), puis entrée des nouvelles cartes comme OpenStagger.
-- Écran éteint, en train de se fermer ou sans carte : `change()` tout de suite. Un autre Swap ou une
-- fermeture pendant la sortie : `change()` est fait tout de suite, sans entrée animée.
function Motion.Swap(gui: ScreenGui, change: () -> ())
	stopStagger(gui)
	if not swappable(gui) then
		runChange(change)
		return
	end
	local state = newStagger(gui)
	local outs: { GuiObject } = {}
	for _, item in staggerItems(gui) do
		if addStaggerScale(state, item, 1) then
			table.insert(outs, item)
		end
	end
	if #outs == 0 then
		staggers[gui] = nil
		runChange(change)
		staggerIn(gui, staggerItems(gui))
		return
	end
	state.change = change
	table.sort(outs, function(a: GuiObject, b: GuiObject): boolean
		return before(b, a)
	end)
	local token = state.token
	local gap = UiMotion.Swap.OutGap
	for index, item in outs do
		local rank = math.min(index, STAGGER.Max) - 1
		task.delay(rank * gap, function()
			local scale: UIScale? = state.scales[item]
			if state.token ~= token or not scale or scale.Parent ~= item then
				return
			end
			local tween = TweenService:Create(scale, SWAP_OUT_INFO, { Scale = 0 })
			table.insert(state.tweens, tween)
			tween:Play()
		end)
	end
	local total = (math.min(#outs, STAGGER.Max) - 1) * gap + UiMotion.Swap.OutTime
	task.delay(total, function()
		if state.token ~= token then
			return -- déjà fait par stopStagger (autre Swap, fermeture)
		end
		local pending = state.change
		state.change = nil
		stopStagger(gui)
		if pending then
			runChange(pending)
		end
		if swappable(gui) then
			staggerIn(gui, staggerItems(gui))
		end
	end)
end

-- Cartes encore en train d'entrer ou de sortir sur cet écran (banc, barre de commande en Studio).
function Motion.GetStaggerCount(gui: Instance): number
	local state = staggers[gui]
	if state == nil then
		return 0
	end
	local count = 0
	for _ in state.scales do
		count += 1
	end
	return count
end

------------------------------------------------------------------------------
-- Entrée et sortie
------------------------------------------------------------------------------

local function enter(inst: Instance, transition: Transition)
	local entry = entries[inst]
	if isShown(inst) then
		if entry == nil or entry.phase ~= "Closing" then
			-- Déjà affiché, par Motion ou sans lui (copie de StarterGui arrivée allumée) : pas
			-- d'entrée, mais il compte désormais comme ouvert (sa fermeture sera animée).
			local current = entry or entryOf(inst)
			if current.phase == "Closed" then
				current.phase = "Open"
			end
			return
		end
		-- En train de se fermer : la fermeture est annulée, ses suites aussi.
		table.clear(entry.after)
		entry.phase = "Opening"
		run(entry, targetsOf(inst), nil, 1, 1, transition.info, function()
			entry.phase = "Open"
			release(entry)
		end)
		appear.Open(inst) -- vague 59 : ses éléments Appear repartent de là où la fermeture les a laissés
		return
	end
	local current = entryOf(inst)
	release(current)
	table.clear(current.after)
	if inst.Parent == nil then
		current.phase = "Open"
		setShown(inst, true)
		return
	end
	current.phase = "Opening"
	setShown(inst, true)
	runTwo(current, inst, transition.scale, transition.scale, 1, transition, function()
		current.phase = "Open"
		release(current)
	end)
	if inst:IsA("ScreenGui") then
		-- L-094 : les cartes arrivent une à une après la fenêtre ; vague 59 : sauf celles qu'anime Appear (Cascade).
		local items: { GuiObject } = {}
		for _, item in staggerItems(inst) do
			if not appear.Covers(item) then
				table.insert(items, item)
			end
		end
		staggerIn(inst, items)
	end
end

local function leave(inst: Instance, transition: Transition, after: (() -> ())?)
	stopStagger(inst) -- cartes remises à leur taille (la fenêtre rapetisse avec elles), page changée
	local entry = entries[inst]
	if entry ~= nil and entry.phase == "Closing" and isShown(inst) then
		if after then
			table.insert(entry.after, after) -- fermeture déjà en cours : la même suite
		end
		return
	end
	if not isShown(inst) or entry == nil or entry.phase == "Closed" or inst.Parent == nil then
		-- Déjà fermé, allumé sans Motion ou retiré du jeu : fermé tout de suite.
		local current = entryOf(inst)
		release(current)
		current.token += 1
		current.phase = "Closed"
		if isShown(inst) then
			setShown(inst, false)
		end
		local callbacks = table.clone(current.after)
		table.clear(current.after)
		if after then
			table.insert(callbacks, after)
		end
		runAfter(callbacks)
		return
	end
	-- Ouvert ou en train de s'ouvrir : sortie animée, depuis l'échelle actuelle.
	if after then
		table.insert(entry.after, after)
	end
	entry.phase = "Closing"
	-- Vague 59 : fermeture des éléments Appear (0 s s'il n'y en a pas : comme avant), attendue avant d'éteindre.
	local hold = appear.Close(inst)
	local started = os.clock()
	local function closed()
		entry.phase = "Closed"
		setShown(inst, false)
		release(entry)
		appear.Reset(inst) -- éléments Appear remis à l'état de Clément, écran éteint
		local callbacks = table.clone(entry.after)
		table.clear(entry.after)
		runAfter(callbacks)
	end
	runTwo(entry, inst, nil, 1, transition.scale, transition, function()
		local left = hold - (os.clock() - started)
		if left <= 0 then
			closed()
			return
		end
		local token = entry.token
		task.delay(left, function()
			if entry.token == token and entry.phase == "Closing" then
				closed()
			end
		end)
	end)
end

-- Ferme les autres écrans allumés du groupe de `gui` (même attribut ScreenGroup, même parent),
-- sauf ceux déjà en train de se fermer.
local function closeGroup(gui: ScreenGui)
	local group = gui:GetAttribute(GROUP_ATTRIBUTE)
	local parent = gui.Parent
	if type(group) ~= "string" or group == "" or parent == nil then
		return
	end
	for _, other in parent:GetChildren() do
		if other ~= gui and other:IsA("ScreenGui") and (other :: ScreenGui).Enabled
			and other:GetAttribute(GROUP_ATTRIBUTE) == group then
			local entry = entries[other]
			if entry == nil or entry.phase ~= "Closing" then
				local closer = closers[other]
				if closer then
					closer()
				else
					Motion.Close(other :: ScreenGui)
				end
			end
		end
	end
end

-- Vague 26 (L-097 point 8) : UI_Open et UI_Close seulement pour les fenêtres (menus) : un écran qui a un
-- Motion.SetCloser ou un attribut ScreenGroup. Les alertes (UI_Chase, vol en cours…) restent muettes.
-- Un écran fermé par l'ouverture d'un autre de son groupe ne joue pas UI_Close (seul UI_Open s'entend).
local groupClosing = false

local function isWindow(gui: ScreenGui): boolean
	local group = gui:GetAttribute(GROUP_ATTRIBUTE)
	return closers[gui] ~= nil or (type(group) == "string" and group ~= "")
end

-- Vague 72 (a246, bug de L-229 : UI_Open toutes les 0,5 s pendant la poursuite) : un écran tenu caché par
-- Controllers/UI/HudMask (poursuite, cinématique) ne s'ouvre pas vraiment, donc pas de UI_Open. C'était UI_Offline :
-- OfflineController le rouvre à chaque vérification (0,5 s) dès qu'il le trouve éteint, et HudMask le réteint.
local hudMask: any = nil -- module HudMask, false s'il manque

local function masked(gui: ScreenGui): boolean
	if hudMask == nil then
		local module = script.Parent:FindFirstChild("HudMask")
		local ok: boolean, result: any = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
		end
		hudMask = if ok and type(result) == "table" and type(result.GetHidden) == "function" then result else false
	end
	if hudMask == false then
		return false
	end
	local ok, screens = pcall(hudMask.GetHidden)
	return ok and type(screens) == "table" and table.find(screens, gui) ~= nil
end

function Motion.Open(gui: ScreenGui)
	local entry = entries[gui]
	local opening = isWindow(gui) and (not isShown(gui) or (entry ~= nil and entry.phase == "Closing")) and not masked(gui)
	groupClosing = true
	closeGroup(gui)
	groupClosing = false
	enter(gui, OPEN)
	if opening then
		Motion.PlaySound(UiMotion.Sounds.Open)
	end
end

-- Cadre racine animé à part (RunBanner de UI_Chase, L-092 3a) : Open et Close de son écran ne le
-- mettent pas à l'échelle, pour que deux UIScale ne se gênent pas.
function Motion.KeepScale(object: GuiObject)
	apart[object] = true
end

-- a285 (21/11) : réglage « animations réduites » (Appear.Reduced), pour les effets d'UiAttrFx.
function Motion.IsReduced(): boolean
	return appear.Reduced()
end

function Motion.SetCloser(gui: ScreenGui, close: (() -> ())?)
	if close then
		closers[gui] = close
	else
		closers[gui] = nil
	end
end

-- Vague 75 (a260, L-262 point 3) : ferme les autres écrans allumés du groupe de `gui`, comme Motion.Open, pour un
-- écran que son contrôleur allume lui-même (UI_Displayed, Enabled). Sans attribut ScreenGroup : rien.
function Motion.CloseGroup(gui: ScreenGui)
	groupClosing = true
	closeGroup(gui)
	groupClosing = false
end

-- Vague 74 (L-259, clic sur le voile) : ferme `gui` comme son contrôleur (Motion.SetCloser), sinon Motion.Close.
function Motion.Dismiss(gui: ScreenGui)
	local closer = closers[gui]
	if closer then
		closer()
	else
		Motion.Close(gui)
	end
end

function Motion.Close(gui: ScreenGui, after: (() -> ())?)
	local entry = entries[gui]
	-- Vague 26 : UI_Close seulement pour une fenêtre ouverte, et pas si elle part à l'ouverture d'une autre.
	local closing = not groupClosing and isWindow(gui) and isShown(gui) and gui.Parent ~= nil and entry ~= nil
		and (entry.phase == "Open" or entry.phase == "Opening")
	leave(gui, CLOSE, after)
	if closing then
		Motion.PlaySound(UiMotion.Sounds.Close)
	end
end

function Motion.Show(object: GuiObject)
	enter(object, SHOW)
end

function Motion.Hide(object: GuiObject, after: (() -> ())?)
	leave(object, HIDE, after)
end

------------------------------------------------------------------------------
-- Sons (L-091 point 7) : joués par le contrôleur qui en donne le moyen (UiFeelController)
------------------------------------------------------------------------------

local soundPlayer: ((name: string) -> boolean?)? = nil

function Motion.SetSoundPlayer(play: ((name: string) -> boolean?)?)
	soundPlayer = play
end

-- Vague 59 (L-182 point 1, « un seul son par action ») : heure du dernier son d'action (tout sauf UI_Hover), lue par
-- Motion.Click.
local lastActionSound = -math.huge

local SUCCESS_NAMES: { [string]: boolean } = {}
for _, name in UiMotion.Success.Buttons do
	SUCCESS_NAMES[name] = true
end

function Motion.PlaySound(name: string)
	local play = soundPlayer
	if play then
		local ok, played = pcall(play, name)
		if not ok and IS_STUDIO then
			warn(`[Motion] son « {name} » : erreur dans le lecteur de sons`)
		end
		-- Vague 59 : seul un son vraiment joué (le lecteur renvoie true) fait taire le clic ; un son absent
		-- d'Assets/Sounds laisse le clic sonner.
		if ok and played == true and name ~= UiMotion.Hover.Sound then
			lastActionSound = os.clock()
		end
	end
end

-- Clic d'un bouton (vague 59) : `play` joue le son de clic (SettingsController, UI_Click_<Id>), sauf si l'action a
-- déjà le sien : bouton de réussite (Success.Buttons, hors Success.SkipScreens : UI_Success suit), ou son d'action
-- joué par Motion (UI_Open, UI_Close…) dans les ClickGuard s autour du clic (attendu jusqu'à la fin de l'image).
function Motion.Click(button: GuiButton, play: () -> ())
	if SUCCESS_NAMES[button.Name] then
		local skipped = false
		for _, screen in UiMotion.Success.SkipScreens do
			if button:FindFirstAncestor(screen) ~= nil then
				skipped = true
				break
			end
		end
		if not skipped then
			return
		end
	end
	local at = os.clock()
	task.defer(function()
		if lastActionSound >= at - UiMotion.ClickGuard then
			return
		end
		play()
	end)
end

------------------------------------------------------------------------------
-- Boutons : survol, appui, relâché, réussite (L-091 point 7)
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- a299 (Cantin, 21/11) : le survol grossit autour du centre (Config/UiMotion.Hover.Centered)
------------------------------------------------------------------------------

-- Un UIScale grossit l'élément autour de son AnchorPoint : à (0 ; 0), il grossit depuis son coin haut gauche. Le temps
-- que le UIScale de survol existe (bouton, Icon d'une carte, carte), l'élément passe à l'AnchorPoint (0,5 ; 0,5) et sa
-- Position avance d'autant (même place à l'écran) ; à la destruction du UIScale, AnchorPoint et Position de Clément
-- reviennent exactement. Rien pour un élément déjà centré, rangé par un layout (le layout le place), ou réglage coupé.
-- Un autre effet qui écrit la Position d'un élément recentré passe par Motion.Placed (UiAttrFx : IconHover Jump).
type Centering = { anchor: Vector2, rest: UDim2, shift: UDim2, placed: UDim2 }
local centerings: { [GuiObject]: Centering } = setmetatable({}, { __mode = "k" }) :: any
-- (Vector2.new(0,5 ; 0,5) écrit au survol, pas au chargement : les faux Roblox des anciens bancs n'ont pas tous Vector2.)
local LAYOUTS = { "UIListLayout", "UIGridLayout", "UIPageLayout", "UITableLayout" }
local CONSTRAINTS = { "UIAspectRatioConstraint", "UISizeConstraint" }

local function laidOut(object: GuiObject): boolean
	local parent = object.Parent
	if parent == nil then
		return true
	end
	for _, class in LAYOUTS do
		if parent:FindFirstChildOfClass(class) ~= nil then
			return true
		end
	end
	return false
end

-- Décalage du coin d'ancrage au centre, en unités de Position. Size suffit, sauf si une contrainte change la taille
-- dessinée : alors la taille réelle (AbsoluteSize, sans le UIScale `scale` de l'élément) en part du parent.
local function centerShift(object: GuiObject, scale: number): UDim2
	local a = object.AnchorPoint
	local dx, dy = 0.5 - a.X, 0.5 - a.Y
	local constrained = false
	for _, class in CONSTRAINTS do
		if object:FindFirstChildOfClass(class) ~= nil then
			constrained = true
			break
		end
	end
	if constrained then
		local ok, shift = pcall(function(): UDim2?
			local parent = object.Parent :: any
			local own: Vector2 = object.AbsoluteSize
			local room: Vector2 = parent.AbsoluteSize
			if scale <= 0 or own.X <= 0 or own.Y <= 0 or room.X <= 0 or room.Y <= 0 then
				return nil
			end
			return UDim2.fromScale(dx * own.X / scale / room.X, dy * own.Y / scale / room.Y)
		end)
		if ok and shift ~= nil then
			return shift
		end
	end
	local size = object.Size
	return UDim2.new(dx * size.X.Scale, dx * size.X.Offset, dy * size.Y.Scale, dy * size.Y.Offset)
end

-- `object` grossit autour de son centre à partir de maintenant (son UIScale vaut `scale`). Sans effet la deuxième fois.
local function centerOn(object: GuiObject, scale: number)
	if centerings[object] ~= nil or not UiMotion.Hover.Centered then
		return
	end
	-- Lu sous pcall : un objet sans AnchorPoint (faux Roblox d'un ancien banc) n'est pas recentré.
	local read, anchor = pcall(function(): Vector2?
		return object.AnchorPoint
	end)
	if not read or anchor == nil then
		return
	end
	local a: Vector2 = anchor
	if math.abs(a.X - 0.5) < 1e-6 and math.abs(a.Y - 0.5) < 1e-6 then
		return
	end
	if laidOut(object) then
		return
	end
	local rest = object.Position
	local shift = centerShift(object, scale)
	local placed = UDim2.new(
		rest.X.Scale + shift.X.Scale,
		rest.X.Offset + shift.X.Offset,
		rest.Y.Scale + shift.Y.Scale,
		rest.Y.Offset + shift.Y.Offset
	)
	centerings[object] = { anchor = a, rest = rest, shift = shift, placed = placed }
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = placed
end

-- Fin du recentrage : AnchorPoint de Clément, et sa Position exacte (ou la Position du moment moins le décalage, si un
-- autre effet l'a déplacé entre-temps).
local function centerOff(object: GuiObject)
	local entry = centerings[object]
	if entry == nil then
		return
	end
	centerings[object] = nil
	local now = object.Position
	object.AnchorPoint = entry.anchor
	if now == entry.placed then
		object.Position = entry.rest
	else
		local s = entry.shift
		object.Position = UDim2.new(now.X.Scale - s.X.Scale, now.X.Offset - s.X.Offset, now.Y.Scale - s.Y.Scale, now.Y.Offset - s.Y.Offset)
	end
end

-- Position à écrire pour mettre `object` à `position` (comptée avec l'AnchorPoint de Clément), recentré ou non.
function Motion.Placed(object: GuiObject, position: UDim2): UDim2
	local entry = centerings[object]
	if entry == nil then
		return position
	end
	local s = entry.shift
	return UDim2.new(position.X.Scale + s.X.Scale, position.X.Offset + s.X.Offset, position.Y.Scale + s.Y.Scale, position.Y.Offset + s.Y.Offset)
end

-- L'élément est recentré en ce moment (banc, barre de commande en Studio).
function Motion.IsCentered(object: GuiObject): boolean
	return centerings[object] ~= nil
end

-- Un bouton branché par Motion.Button. L'échelle passe par un UIScale Hover.ScaleName, créé au
-- premier effet et détruit dès que le bouton est revenu à 1 (souris sortie, bouton relâché).
type ButtonState = {
	scale: UIScale?,
	tween: Tween?,
	token: number,
	over: boolean,
	down: boolean,
	wired: boolean,
	shade: GuiObject?, -- calque Shade de Clément (enfant direct), s'il existe
	shadeBase: number, -- sa transparence posée par Clément, remise à la sortie
	shadeTween: Tween?,
	bouncing: boolean, -- Press = Squash : rebond du relâché en cours (1,1 puis retour)
	-- a290 (L-270, Config/UiMotion.ClickZone) : appui en cours ou dernier appui, clics donnés par Motion.Activated.
	hold: Hold?,
	tracked: boolean, -- InputBegan du bouton écouté (appuis suivis)
	clicks: Clicks?,
	phantom: Hold?, -- souris relâchée dans le bord du bouton écrasé : survol gardé tant qu'elle reste dans cette zone
	onLeave: (() -> ())?, -- Motion.Button : la souris est sortie de la zone appuyée (comme MouseLeave)
	onRelease: (() -> ())?, -- Motion.Button : relâché de la souris hors du bouton rétréci (comme MouseButton1Up)
}

-- a290 (L-270) : un appui sur le bouton (clic gauche ou doigt). Zone appuyée (minX…maxY) : la taille réelle du bouton
-- (sans le UIScale de Motion) et le rectangle appuyé (grossi par le survol), dans le repère d'AbsolutePosition ;
-- offset passe du repère de l'InputObject à celui d'AbsolutePosition (GetGuiInset ou rien, réglé sur l'appui).
type Hold = {
	kind: Enum.UserInputType,
	input: InputObject,
	offset: Vector2,
	minX: number,
	minY: number,
	maxX: number,
	maxY: number,
	point: Vector2, -- dernier point connu du pointeur (repère d'AbsolutePosition)
	start: Vector2, -- point de l'appui (même repère)
	pivotX: number, -- a299 : centre de la taille réelle du bouton à l'appui (ni le UIScale ni le recentrage ne le déplacent ; une liste qui défile, si)
	pivotY: number,
	scrolls: boolean, -- le bouton est dans une ScrollingFrame
	fired: boolean, -- Activated de Roblox reçu pour cet appui
	rescued: boolean, -- clic donné par le rattrapage
	rescuedAt: number,
	left: boolean, -- la souris est sortie du bouton dessiné (écrasé) pendant l'appui : Roblox peut ne plus donner son clic
}

-- a290 (L-270) : signal de clic d'un bouton (Motion.Activated), en Luau : Connect, Once, Disconnect, Connected.
type Listener = { fn: (...any) -> (), connected: boolean, once: boolean }
type Clicks = { listeners: { Listener }, signal: any }

-- Vague 59 (L-182 point 1) : Hover = Pop et Press = Squash.
local POP = UiMotion.HoverPop
local SQUASH = UiMotion.PressSquash
local POP_INFO = TweenInfo.new(POP.Time, POP.Style, POP.Direction)
local SQUASH_INFO = TweenInfo.new(SQUASH.Time, SQUASH.Style, SQUASH.Direction)
local BOUNCE_INFO = TweenInfo.new(SQUASH.BounceTime, SQUASH.Style, SQUASH.Direction)
local BOUNCE_BACK_INFO = TweenInfo.new(SQUASH.BackTime, SQUASH.Style, SQUASH.Direction)

local function hoverPop(object: Instance): boolean
	return object:GetAttribute(HOVER_ATTRIBUTE) == HOVER_POP
end

local function squashes(object: Instance): boolean
	return object:GetAttribute(PRESS_ATTRIBUTE) == PRESS_SQUASH
end

local PRESS_INFO = TweenInfo.new(UiMotion.Press.Time, UiMotion.Press.Style, UiMotion.Press.Direction)
local RELEASE_INFO = TweenInfo.new(UiMotion.Release.Time, UiMotion.Release.Style, UiMotion.Release.Direction)
local SUCCESS_INFO = TweenInfo.new(UiMotion.Success.Time, UiMotion.Success.Style, UiMotion.Success.Direction)
local SHADE_NAME = "Shade" -- calque d'assombrissement des boutons de Clément (prototypes du 2026-11-10)

local buttons: { [GuiButton]: ButtonState } = setmetatable({}, { __mode = "k" }) :: any

local function buttonState(button: GuiButton): ButtonState
	local state = buttons[button]
	if state then
		return state
	end
	local shade = button:FindFirstChild(SHADE_NAME)
	local shadeObject: GuiObject? = if shade and shade:IsA("GuiObject") then shade :: GuiObject else nil
	local created: ButtonState = {
		scale = nil,
		tween = nil,
		token = 0,
		over = false,
		down = false,
		wired = false,
		shade = shadeObject,
		shadeBase = if shadeObject then shadeObject.BackgroundTransparency else 1,
		shadeTween = nil,
		bouncing = false,
		hold = nil,
		tracked = false,
		clicks = nil,
		phantom = nil,
		onLeave = nil,
		onRelease = nil,
	}
	buttons[button] = created
	return created
end

-- Le UIScale du bouton (créé à 1 s'il manque), ou nil si le bouton a déjà un UIScale qui n'est pas
-- le sien (celui de Clément, ou celui d'une ouverture d'écran) : jamais touché.
local function buttonScale(button: GuiButton, state: ButtonState): UIScale?
	local own = state.scale
	if own and own.Parent == button then
		return own
	end
	state.scale = nil
	centerOff(button) -- a299 : son UIScale a disparu (retiré par un autre), il retrouve son AnchorPoint
	if button:FindFirstChildOfClass("UIScale") ~= nil then
		return nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = UiMotion.Hover.ScaleName
	scale.Parent = button
	state.scale = scale
	centerOn(button, 1) -- a299 : grossit autour de son centre tant que ce UIScale existe
	return scale
end

-- Vague 66 (a222, L-210 point 9, Config/UiMotion.HoverFit) : la carte de liste qui contient le bouton (le premier
-- parent sous une ScrollingFrame qui dessine un cadre : fond, UIStroke ou image ; sinon la carte elle-même, enfant
-- de la liste), ou nil hors d'une liste.
local FIT = UiMotion.HoverFit

local function drawsFrame(object: GuiObject): boolean
	if object.BackgroundTransparency < 1 then
		return true
	end
	local stroke = object:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil and stroke.Enabled and stroke.Transparency < 1 then
		return true
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		local image = object :: any
		return image.Image ~= "" and image.ImageTransparency < 1
	end
	return false
end

local function cardOf(button: GuiButton): GuiObject?
	local found: GuiObject? = nil
	local last: GuiObject? = nil
	local current = button.Parent
	while current ~= nil and not current:IsA("LayerCollector") do
		if current:IsA("ScrollingFrame") then
			return found or last
		end
		if current:IsA("GuiObject") then
			last = current :: GuiObject
			if found == nil and drawsFrame(current :: GuiObject) then
				found = current :: GuiObject
			end
		end
		current = current.Parent
	end
	return nil -- pas dans une liste : comme avant
end

-- Échelle la plus grande qui garde le bouton dans sa carte (le UIScale grossit le bouton autour de son AnchorPoint),
-- ou nil (pas dans une liste, réglage coupé, tailles inconnues).
local function fitLimit(button: GuiButton, state: ButtonState): number?
	if not FIT.Enabled then
		return nil
	end
	local ok, limit = pcall(function(): number?
		local card = cardOf(button)
		if card == nil then
			return nil
		end
		local own = state.scale
		local current = if own and own.Parent == button then own.Scale else 1
		local size, position, anchor = button.AbsoluteSize, button.AbsolutePosition, button.AnchorPoint
		if current <= 0 or size.X <= 0 or size.Y <= 0 then
			return nil
		end
		local inset = FIT.Inset
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke ~= nil and stroke.Enabled and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			inset += stroke.Thickness
		end
		local origin, room = card.AbsolutePosition, card.AbsoluteSize
		local best = math.huge
		local function axis(pivot: number, a: number, length: number, low: number, high: number)
			if a > 0 then
				best = math.min(best, (pivot - low) / (a * length))
			end
			if a < 1 then
				best = math.min(best, (high - pivot) / ((1 - a) * length))
			end
		end
		local width, height = size.X / current, size.Y / current
		axis(position.X + size.X * anchor.X, anchor.X, width, origin.X + inset, origin.X + room.X - inset)
		axis(position.Y + size.Y * anchor.Y, anchor.Y, height, origin.Y + inset, origin.Y + room.Y - inset)
		return if best < math.huge then best else nil
	end)
	return if ok then limit else nil
end

-- `goal` (> 1 : le bouton grossit), ramené au bord de sa carte ; jamais sous 1.
local function fitted(button: GuiButton, state: ButtonState, goal: number): number
	if goal <= 1 then
		return goal
	end
	local limit = fitLimit(button, state)
	return if limit then math.min(goal, math.max(limit, 1)) else goal
end

local function scaleButton(button: GuiButton, state: ButtonState, goal: number, info: TweenInfo, from: number?, after: (() -> ())?)
	state.bouncing = false -- tout nouvel effet remplace un rebond en cours
	if goal == 1 and from == nil and state.scale == nil then
		return -- déjà à 1, sans UIScale : rien à faire
	end
	local scale = buttonScale(button, state)
	if scale == nil then
		return
	end
	local current: UIScale = scale
	local previous = state.tween
	if previous then
		previous:Cancel()
	end
	if from ~= nil then
		current.Scale = from
	end
	state.token += 1
	local token = state.token
	local tween = TweenService:Create(current, info, { Scale = goal })
	state.tween = tween
	tween.Completed:Connect(function(playback: Enum.PlaybackState)
		if playback ~= Enum.PlaybackState.Completed or state.token ~= token then
			return
		end
		state.tween = nil
		if after then
			after()
			return
		end
		if goal == 1 and not state.over and not state.down then
			if state.scale == current then
				state.scale = nil
			end
			current:Destroy() -- revenu à 1 : rien n'est laissé
			if state.scale == nil then
				centerOff(button) -- a299 : AnchorPoint et Position de Clément
			end
		end
	end)
	tween:Play()
end

local function shadeTo(state: ButtonState, transparency: number, info: TweenInfo)
	local shade = state.shade
	if shade == nil or shade.Parent == nil then
		return
	end
	local previous = state.shadeTween
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(shade, info, { BackgroundTransparency = transparency })
	state.shadeTween = tween
	tween:Play()
end

------------------------------------------------------------------------------
-- a290 (L-270) : le clic compte sur toute la zone appuyée (Config/UiMotion.ClickZone)
------------------------------------------------------------------------------
-- Roblox ne donne Activated que si le relâché tombe sur le bouton tel qu'il est dessiné ; écrasé à 0,75 par son
-- UIScale, le bouton perd le quart extérieur de sa zone de clic. Le visuel ne change pas : l'appui est suivi
-- (InputBegan du bouton, puis InputChanged et InputEnded de UserInputService) et un relâché dans la zone appuyée,
-- hors du bouton rétréci, que Roblox n'a pas pris est donné par Motion.Activated(button), une seule fois.
local ZONE = UiMotion.ClickZone
local MOUSE1 = Enum.UserInputType.MouseButton1
local TOUCH = Enum.UserInputType.Touch
local MOVE = Enum.UserInputType.MouseMovement
local held: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- appuis pas encore relâchés
local phantoms: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- survols gardés (ButtonState.phantom)
local inputWired: boolean? = nil -- nil : pas encore essayé ; false : pas de UserInputService (banc)

local function vec(x: number, y: number): Vector2
	return Vector2.new(x, y)
end

local function shifted(point: Vector2, offset: Vector2): Vector2
	return vec(point.X + offset.X, point.Y + offset.Y)
end

-- Point de l'InputObject (souris ou doigt), ou nil.
local function pointOf(input: InputObject): Vector2?
	local ok, point = pcall(function(): Vector2?
		local position = (input :: any).Position
		if position == nil or type(position.X) ~= "number" or type(position.Y) ~= "number" then
			return nil
		end
		return vec(position.X, position.Y)
	end)
	return if ok then point else nil
end

local function insetOf(): Vector2
	local ok, inset = pcall(function(): Vector2
		local value = (game:GetService("GuiService") :: any):GetGuiInset()
		return vec(value.X, value.Y)
	end)
	return if ok and inset then inset else vec(0, 0)
end

local function inButton(button: GuiButton, point: Vector2): boolean
	local position, size = button.AbsolutePosition, button.AbsoluteSize
	return point.X >= position.X and point.X <= position.X + size.X and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

local function inZone(hold: Hold, point: Vector2): boolean
	return point.X >= hold.minX and point.X <= hold.maxX and point.Y >= hold.minY and point.Y <= hold.maxY
end

-- Point d'ancrage du bouton (AnchorPoint) : le UIScale de Motion met le bouton à l'échelle autour de lui.
local function pivotOf(button: GuiButton): (number, number)
	local size, position, anchor = button.AbsoluteSize, button.AbsolutePosition, button.AnchorPoint
	return position.X + size.X * anchor.X, position.Y + size.Y * anchor.Y
end

-- Taille réelle du bouton (sans le UIScale de Motion : appui, survol, rebond, réussite) : x, y, largeur, hauteur.
local function realRect(button: GuiButton, state: ButtonState): (number, number, number, number)
	local size, anchor = button.AbsoluteSize, button.AnchorPoint
	local own = state.scale
	local s = if own and own.Parent == button then own.Scale else 1
	if s <= 0 then
		s = 1
	end
	local px, py = pivotOf(button)
	local w, h = size.X / s, size.Y / s
	return px - w * anchor.X, py - h * anchor.Y, w, h
end

-- Le bouton peut encore être cliqué : dans un écran allumé, visible jusqu'à lui, pas coupé (Interactable).
local function usable(button: GuiObject): boolean
	if button.Parent == nil then
		return false
	end
	local ok, interactable = pcall(function(): any
		return (button :: any).Interactable
	end)
	if ok and interactable == false then
		return false
	end
	local current: Instance? = button
	while current ~= nil do
		if current:IsA("LayerCollector") then
			return (current :: any).Enabled ~= false
		end
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		current = current.Parent
	end
	return false -- hors d'un écran : Roblox ne l'aurait pas cliqué non plus
end

local function newClicks(): Clicks
	local listeners: { Listener } = {}
	local function connect(fn: (...any) -> (), once: boolean): any
		local listener: Listener = { fn = fn, connected = true, once = once }
		table.insert(listeners, listener)
		local connection: any
		connection = {
			Connected = true,
			Disconnect = function(_self: any)
				connection.Connected = false
				listener.connected = false
				local index = table.find(listeners, listener)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
		return connection
	end
	local signal = {
		Connect = function(_self: any, fn: (...any) -> ()): any
			return connect(fn, false)
		end,
		Once = function(_self: any, fn: (...any) -> ()): any
			return connect(fn, true)
		end,
	}
	return { listeners = listeners, signal = signal }
end

-- Chaque fonction branchée reçoit le clic dans son propre fil (une erreur n'arrête pas les autres), comme Roblox.
local function fireClicks(clicks: Clicks, ...: any)
	for _, listener in table.clone(clicks.listeners) do
		if listener.connected then
			if listener.once then
				listener.connected = false
				local index = table.find(clicks.listeners, listener)
				if index then
					table.remove(clicks.listeners, index)
				end
			end
			task.spawn(listener.fn, ...)
		end
	end
end

-- Relâché d'un appui suivi : visuel de la souris (relâché hors du bouton rétréci), puis clic rattrapé.
local function settle(button: GuiButton, state: ButtonState, hold: Hold, input: InputObject)
	local point = pointOf(input)
	if point then
		hold.point = shifted(point, hold.offset)
	end
	local inside = inZone(hold, hold.point)
	local onButton = inButton(button, hold.point)
	-- À la souris, Roblox n'envoie pas MouseButton1Up hors du bouton rétréci : le même relâché qu'au centre, et le
	-- survol gardé tant que la souris reste dans la zone (le bouton regrossit sous elle).
	if hold.kind == MOUSE1 and state.down and inside and not onButton then
		local release = state.onRelease
		if release then
			release()
			if state.over then
				state.phantom = hold
				phantoms[button] = true
			end
		end
	end
	local clicks = state.clicks
	if clicks == nil or not inside or (onButton and not hold.left) or hold.fired then
		return -- sur le bouton dessiné, Roblox décide seul (sauf si la souris en est sortie pendant l'appui :
		-- rattrapé seulement si Roblox ne donne pas son clic) ; hors de la zone : glissé loin, pas de clic
	end
	if input.UserInputState == Enum.UserInputState.Cancel then
		return
	end
	local rx, ry, rw, rh = realRect(button, state)
	local px, py = rx + rw / 2, ry + rh / 2 -- a299 : même point qu'à l'appui (centre de la taille réelle)
	if math.abs(px - hold.pivotX) > ZONE.StillPixels or math.abs(py - hold.pivotY) > ZONE.StillPixels then
		return -- la liste a défilé pendant l'appui
	end
	if hold.kind == TOUCH and hold.scrolls
		and (math.abs(hold.point.X - hold.start.X) > ZONE.TouchSlop or math.abs(hold.point.Y - hold.start.Y) > ZONE.TouchSlop) then
		return -- doigt glissé dans une liste : un défilement, pas un clic
	end
	local found: Clicks = clicks
	task.delay(ZONE.SettleTime, function()
		if hold.fired or hold.rescued or not usable(button) then
			return
		end
		hold.rescued = true
		hold.rescuedAt = os.clock()
		fireClicks(found, input, 1)
	end)
end

-- a290 (L-275) : fin du survol sans MouseLeave (voir Config/UiMotion.HoverWatch). Un survol suivi : sa fin (comme
-- MouseLeave), « occupé » (appui tenu, survol gardé après un relâché dans le bord : la zone appuyée décide) et le
-- décalage du repère de la souris, appris quand elle est sur le bouton (0, ou celui du haut de l'écran).
local HOVER = UiMotion.HoverWatch
type Watch = { out: () -> (), busy: () -> boolean, offset: Vector2? }
local watched: { [GuiObject]: Watch } = setmetatable({}, { __mode = "k" }) :: any
local mousePoint: Vector2? = nil -- dernier point de la souris (InputChanged, repère d'InputObject.Position)

local function inRect(object: GuiObject, point: Vector2, slack: number): boolean
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	return point.X >= position.X - slack and point.X <= position.X + size.X + slack
		and point.Y >= position.Y - slack and point.Y <= position.Y + size.Y + slack
end

local function learn(object: GuiObject, watch: Watch, point: Vector2)
	local inset = insetOf()
	for _, candidate in { vec(0, 0), inset, vec(-inset.X, -inset.Y) } do
		if inRect(object, shifted(point, candidate), 0) then
			watch.offset = candidate
			return
		end
	end
end

local function unwatch(object: GuiObject)
	watched[object] = nil
end

-- moved : la souris vient de bouger (sinon : contrôle de chaque image, écran fermé ou bouton déplacé sous elle).
local function checkWatch(object: GuiObject, watch: Watch, moved: boolean)
	if watched[object] ~= watch then
		return
	end
	if not usable(object) then
		watched[object] = nil
		watch.out()
		return
	end
	local point = mousePoint
	if point == nil or watch.busy() then
		return
	end
	local offset = watch.offset
	if offset == nil then
		if moved then
			learn(object, watch, point) -- premier mouvement sur le bouton après MouseEnter
		end
		return
	end
	if not inRect(object, shifted(point, offset), HOVER.Slack) then
		watched[object] = nil
		watch.out()
	end
end

local function checkAll(moved: boolean)
	local list: { GuiObject } = {}
	for object in watched do
		table.insert(list, object)
	end
	for _, object in list do
		local watch = watched[object]
		if watch then
			if not pcall(checkWatch, object, watch, moved) then
				watched[object] = nil -- objet sans tailles absolues (faux Roblox d'un banc) : MouseLeave seul
			end
		end
	end
end

local function onFocusLost()
	local list: { Watch } = {}
	for object, watch in watched do
		table.insert(list, watch)
		watched[object] = nil
	end
	for _, watch in list do
		watch.out()
	end
end

local function onInputChanged(input: InputObject)
	local kind = input.UserInputType
	if kind ~= MOVE and kind ~= TOUCH then
		return
	end
	local point = pointOf(input)
	if point == nil then
		return
	end
	if kind == MOVE then
		mousePoint = point
	end
	for button in held do
		local state = buttons[button]
		local hold = if state then state.hold else nil
		if state and hold and ((kind == MOVE and hold.kind == MOUSE1) or (kind == TOUCH and hold.input == input)) then
			hold.point = shifted(point, hold.offset)
			-- Souris sortie de la zone appuyée en tenant le bouton : comme MouseLeave avant (il revient à 1).
			if kind == MOVE and state.down and not inZone(hold, hold.point) then
				local leave = state.onLeave
				if leave then
					leave()
				end
			end
		end
	end
	if kind ~= MOVE then
		return
	end
	for button in phantoms do
		local state = buttons[button]
		local hold = if state then state.phantom else nil
		if state == nil or hold == nil then
			phantoms[button] = nil
		elseif not inZone(hold, shifted(point, hold.offset)) then
			phantoms[button] = nil
			state.phantom = nil
			local leave = state.onLeave
			if leave then
				leave()
			end
		end
	end
	if HOVER.Enabled then
		checkAll(true)
	end
end

local function onInputEnded(input: InputObject)
	local kind = input.UserInputType
	if kind ~= MOUSE1 and kind ~= TOUCH then
		return
	end
	for button in held do
		local state = buttons[button]
		local hold = if state then state.hold else nil
		if state == nil or hold == nil then
			held[button] = nil
		elseif (kind == MOUSE1 and hold.kind == MOUSE1) or (kind == TOUCH and hold.input == input) then
			held[button] = nil
			settle(button, state, hold, input)
		end
	end
end

-- InputChanged et InputEnded de UserInputService, branchés une fois ; false sans eux (banc).
local function wireInput(): boolean
	if inputWired == nil then
		inputWired = pcall(function()
			local service = game:GetService("UserInputService") :: any
			service.InputChanged:Connect(onInputChanged)
			service.InputEnded:Connect(onInputEnded)
		end)
		if inputWired and HOVER.Enabled then
			-- a290 (L-275) : chaque image (écran fermé, bouton caché ou déplacé sous la souris) et fenêtre sans focus.
			pcall(function()
				RunService.Heartbeat:Connect(function()
					if next(watched) ~= nil then
						checkAll(false)
					end
				end)
			end)
			pcall(function()
				(game:GetService("UserInputService") :: any).WindowFocusReleased:Connect(onFocusLost)
			end)
		end
	end
	return inputWired == true
end

-- a290 (L-275) : suit le survol d'un bouton ou d'une carte jusqu'à sa fin (out) ; sans effet sans InputChanged (banc).
local function watchHover(object: GuiObject, out: () -> (), busy: () -> boolean)
	if not HOVER.Enabled or not wireInput() then
		return
	end
	local watch: Watch = { out = out, busy = busy, offset = nil }
	watched[object] = watch
	local point = mousePoint
	if point then
		pcall(learn, object, watch, point)
	end
end

local function inScroll(button: GuiButton): boolean
	return ancestorOf(button, "ScrollingFrame") ~= nil
end

-- Suit les appuis du bouton (sans effet la deuxième fois, ni avec ClickZone.Enabled = false, ni sans InputChanged et InputEnded
-- de UserInputService : faux Roblox des bancs ; l'Activated de Roblox reste alors seul).
local function track(button: GuiButton, state: ButtonState)
	if state.tracked or not ZONE.Enabled then
		return
	end
	state.tracked = true
	if not wireInput() then
		return
	end
	local function onBegan(input: InputObject)
		local kind = input.UserInputType
		if kind ~= MOUSE1 and kind ~= TOUCH then
			return
		end
		local point = pointOf(input)
		if point == nil or not wireInput() then
			return
		end
		-- Repère : le point de l'appui est sur le bouton ; décalage du haut de l'écran (GetGuiInset), ou aucun.
		local inset = insetOf()
		local offset = vec(0, 0)
		for _, candidate in { vec(0, 0), inset, vec(-inset.X, -inset.Y) } do
			if inButton(button, shifted(point, candidate)) then
				offset = candidate
				break
			end
		end
		local position, size = button.AbsolutePosition, button.AbsoluteSize
		local x, y, w, h = realRect(button, state)
		local px, py = x + w / 2, y + h / 2 -- a299 : centre de la taille réelle, qui ne bouge ni au UIScale ni au recentrage
		local at = shifted(point, offset)
		state.hold = {
			kind = kind,
			input = input,
			offset = offset,
			minX = math.min(position.X, x),
			minY = math.min(position.Y, y),
			maxX = math.max(position.X + size.X, x + w),
			maxY = math.max(position.Y + size.Y, y + h),
			point = at,
			start = at,
			pivotX = px,
			pivotY = py,
			scrolls = inScroll(button),
			fired = false,
			rescued = false,
			rescuedAt = -math.huge,
			left = false,
		}
		held[button] = true
		state.phantom = nil
		phantoms[button] = nil
	end
	pcall(function()
		button.InputBegan:Connect(function(input: InputObject)
			pcall(onBegan, input) -- bouton sans tailles absolues (faux Roblox d'un banc) : pas de suivi, pas d'erreur
		end)
	end)
end

-- Signal de clic du bouton, à brancher à la place de button.Activated (a290, L-270) : l'Activated de Roblox, plus
-- le relâché dans le bord du bouton écrasé (zone appuyée, voir ClickZone), une seule fois par appui. Mêmes
-- arguments qu'Activated (InputObject, nombre de clics). Connect et Once rendent une connexion (Disconnect,
-- Connected). Toujours le même signal pour un bouton.
function Motion.Activated(button: GuiButton): RBXScriptSignal
	local state = buttonState(button)
	local clicks = state.clicks
	if clicks == nil then
		local created = newClicks()
		clicks = created
		state.clicks = created
		button.Activated:Connect(function(...: any)
			local hold = state.hold
			if hold then
				if hold.rescued and os.clock() - hold.rescuedAt < ZONE.Guard then
					return -- Roblox après le clic rattrapé : un seul clic par appui
				end
				hold.fired = true
			end
			fireClicks(created, ...)
		end)
		track(button, state)
	end
	return (clicks :: Clicks).signal :: any
end

-- Zone de clic de l'appui en cours du bouton (x, y, largeur, hauteur, repère d'AbsolutePosition), ou nil sans appui
-- tenu : pour un test (banc, barre de commande en Studio).
function Motion.GetClickZone(button: GuiButton): (number?, number?, number?, number?)
	local state = buttons[button]
	local hold = if state then state.hold else nil
	if hold == nil or not held[button] then
		return nil, nil, nil, nil
	end
	return hold.minX, hold.minY, hold.maxX - hold.minX, hold.maxY - hold.minY
end

-- Survol (Hover), appui (Press) et relâché (Release) d'un bouton ; calque Shade s'il existe ; son
-- Hover.Sound au survol. Sans effet la deuxième fois.
function Motion.Button(button: GuiButton)
	local state = buttonState(button)
	if state.wired then
		return
	end
	state.wired = true
	-- Vague 59 : Hover = Pop (× HoverPop.To en HoverPop.Time) à la place du survol validé (Hover).
	-- Vague 66 : dans une carte de liste, au plus jusqu'au bord de la carte (HoverFit).
	-- a286 (L-224 point 2) : une croix de fermeture grossit à Hover.CloseTo en Hover.SizedTime.
	local function hoverTo(): number
		return fitted(button, state, if hoverPop(button) then POP.To elseif CLOSE_NAMES[button.Name] then UiMotion.Hover.CloseTo else UiMotion.Hover.To)
	end
	local function hoverInfo(): TweenInfo
		return if hoverPop(button) then POP_INFO elseif CLOSE_NAMES[button.Name] then SIZED_INFO else HOVER_INFO
	end
	-- Press = Squash : au relâché, 1,1 puis retour au repos (survol ou 1) ; un survol quitté pendant le rebond est
	-- pris en compte à la fin du rebond.
	local function bounce()
		-- Pic : 1,1 fois le repos (1,1 au doigt ; au-dessus du survol à la souris, sinon le rebond ne se verrait pas).
		local peak = fitted(button, state, (if state.over then hoverTo() else 1) * SQUASH.Bounce)
		scaleButton(button, state, peak, BOUNCE_INFO, nil, function()
			state.bouncing = false
			scaleButton(button, state, if state.over then hoverTo() else 1, BOUNCE_BACK_INFO)
		end)
		state.bouncing = state.tween ~= nil
	end
	local function hoverIn()
		state.over = true
		if not state.down and not state.bouncing then
			local info = hoverInfo()
			scaleButton(button, state, hoverTo(), info)
			shadeTo(state, UiMotion.Hover.ShadeTransparency, info)
		end
		Motion.PlaySound(UiMotion.Hover.Sound)
	end
	local function hoverOut()
		unwatch(button)
		state.over = false
		state.down = false
		local info = hoverInfo()
		shadeTo(state, state.shadeBase, info)
		if not state.bouncing then
			scaleButton(button, state, 1, info)
		end
	end
	-- Vague 25 : survol seulement si le bouton est l'élément du dessus (voir onTop).
	button.MouseEnter:Connect(function()
		-- a290 (L-270) : la souris retrouve le bouton qui regrossit sous elle (appui gardé dans la zone, ou relâché
		-- dans le bord) : il est déjà survolé, ni second survol ni second son.
		if state.phantom ~= nil then
			state.phantom = nil
			phantoms[button] = nil
			return
		end
		if state.down and state.over then
			return
		end
		if onTop(button) then
			hoverIn()
			-- a290 (L-275) : fin du survol aussi sans MouseLeave (souris sortie du bouton, écran fermé, focus perdu).
			watchHover(button, function()
				state.phantom = nil
				phantoms[button] = nil
				hoverOut()
			end, function(): boolean
				return state.down or held[button] == true or state.phantom ~= nil
			end)
		end
	end)
	button.MouseLeave:Connect(function()
		-- a290 (L-270) : en tenant le bouton, la souris sort du bouton écrasé sans sortir de la zone appuyée : il
		-- reste écrasé (comme au centre) ; il revient à 1 quand elle sort de la zone (onLeave).
		local hold = state.hold
		if hold and held[button] then
			hold.left = true
		end
		if state.down and hold and held[button] and inZone(hold, hold.point) then
			return
		end
		state.phantom = nil
		phantoms[button] = nil
		hoverOut()
	end)
	state.onLeave = hoverOut
	track(button, state)
	button.MouseButton1Down:Connect(function()
		state.down = true
		if squashes(button) then
			scaleButton(button, state, SQUASH.To, SQUASH_INFO)
		else
			scaleButton(button, state, UiMotion.Press.To, PRESS_INFO)
		end
		shadeTo(state, UiMotion.Press.ShadeTransparency, PRESS_INFO)
	end)
	local function released()
		if not state.down then
			return
		end
		state.down = false
		if squashes(button) then
			bounce()
		else
			scaleButton(button, state, if state.over then hoverTo() else 1, RELEASE_INFO)
		end
		shadeTo(state, if state.over then UiMotion.Hover.ShadeTransparency else state.shadeBase, RELEASE_INFO)
	end
	button.MouseButton1Up:Connect(released)
	-- a290 (L-270) : relâché de la souris dans le bord du bouton écrasé (pas de MouseButton1Up) : le même relâché.
	state.onRelease = released
	-- L-092 3g : sur un écran tactile, pas de MouseLeave ; à la fin du toucher (doigt levé, ou
	-- glissé hors du bouton), le bouton revient à 1 et Shade à sa transparence d'origine.
	local function touchEnded()
		state.over = false
		local wasDown = state.down
		state.down = false
		if squashes(button) then
			if not state.bouncing and (wasDown or state.scale ~= nil) then
				bounce() -- doigt levé sans MouseButton1Up : le rebond quand même
			end
		else
			scaleButton(button, state, 1, RELEASE_INFO)
		end
		shadeTo(state, state.shadeBase, RELEASE_INFO)
	end
	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local watch: RBXScriptConnection? = nil
		watch = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local inputState = input.UserInputState
			if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				if watch then
					watch:Disconnect()
				end
				touchEnded()
			end
		end)
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchEnded()
		end
	end)
end

-- Ancien nom (vague 19, boutons du HUD) : le bouton complet, survol compris.
function Motion.Hover(button: GuiButton)
	Motion.Button(button)
end

-- Achat ou validation réussis : le bouton saute à Success.From puis revient (au survol si la souris
-- est dessus), et Success.Sound part Success.SoundDelay s plus tard.
function Motion.Success(button: GuiButton)
	local state = buttonState(button)
	state.down = false
	local rest = if not state.over then 1 elseif hoverPop(button) then POP.To else UiMotion.Hover.To
	-- Vague 66 : dans une carte de liste, le saut et le repos restent dans la carte (HoverFit).
	scaleButton(button, state, fitted(button, state, rest), SUCCESS_INFO, fitted(button, state, UiMotion.Success.From))
	task.delay(UiMotion.Success.SoundDelay, function()
		Motion.PlaySound(UiMotion.Success.Sound)
	end)
end

------------------------------------------------------------------------------
-- Sursaut passager (CashBump, TimerTick…)
------------------------------------------------------------------------------

type PopState = { scale: UIScale, token: number, tween: Tween? }
local pops: { [GuiObject]: PopState } = setmetatable({}, { __mode = "k" }) :: any

-- L'objet passe à l'échelle `from`, puis revient à 1 (`info`), par un UIScale PopScaleName détruit à
-- la fin. Un nouveau sursaut pendant le premier repart de `from`. Sans effet sur un objet qui a déjà
-- un autre UIScale (celui de Clément, ou une autre animation en cours).
function Motion.Pop(object: GuiObject, from: number, info: TweenInfo)
	local state = pops[object]
	if state == nil or state.scale.Parent ~= object then
		if object:FindFirstChildOfClass("UIScale") ~= nil then
			return
		end
		local scale = Instance.new("UIScale")
		scale.Name = UiMotion.PopScaleName
		scale.Parent = object
		local created: PopState = { scale = scale, token = 0, tween = nil }
		state = created
		pops[object] = created
	end
	local current: PopState = state :: PopState
	local previous = current.tween
	if previous then
		previous:Cancel()
	end
	current.token += 1
	local token = current.token
	current.scale.Scale = from
	local tween = TweenService:Create(current.scale, info, { Scale = 1 })
	current.tween = tween
	tween.Completed:Connect(function(playback: Enum.PlaybackState)
		if playback ~= Enum.PlaybackState.Completed or current.token ~= token then
			return
		end
		if pops[object] == current then
			pops[object] = nil
		end
		current.scale:Destroy()
	end)
	tween:Play()
end

------------------------------------------------------------------------------
-- Cartes survolées (HoverCard, L-091 point 7)
------------------------------------------------------------------------------

type CardState = {
	token: number,
	tweens: { Tween },
	scale: UIScale?,
	icon: GuiObject?,
	basePosition: UDim2?, -- Position et Rotation de l'Icon posées par Clément, remises au retour
	baseRotation: number,
	outlineBase: boolean?, -- Visible de HoverOutline avant le survol
	pop: boolean, -- vague 59 : survol Hover = Pop en cours (la carte penche, l'Icon grossit sans bouger)
	cardRotation: number?, -- Rotation de la carte posée par Clément, remise au retour (Pop)
	cardScale: UIScale?, -- a286 (L-224 point 2) : UIScale passager de la carte elle-même (Hover.CardTo), détruit au retour
}

local CARD_POP_INFO = TweenInfo.new(UiMotion.HoverPop.Time, UiMotion.HoverPop.Style, UiMotion.HoverPop.Direction)

local CARD_INFO = TweenInfo.new(UiMotion.HoverCard.Time, UiMotion.HoverCard.Style, UiMotion.HoverCard.Direction)
local CARD_BACK_INFO = TweenInfo.new(UiMotion.HoverCard.BackTime, UiMotion.HoverCard.BackStyle, Enum.EasingDirection.Out)
local cards: { [GuiObject]: CardState } = setmetatable({}, { __mode = "k" }) :: any
-- a285 (21/11) : Position et Rotation de repos d'un Icon qu'un autre effet fait bouger (UiAttrFx : IconHover, Idle) ;
-- la carte s'y fie plutôt qu'à la valeur du moment, pour ne jamais garder un état en plein mouvement.
type Rest = { position: UDim2, rotation: number }
local rests: { [GuiObject]: Rest } = setmetatable({}, { __mode = "k" }) :: any

function Motion.SetRest(object: GuiObject, position: UDim2, rotation: number)
	rests[object] = { position = position, rotation = rotation }
end

function Motion.IsHoverCard(object: GuiObject): boolean
	return cards[object] ~= nil
end

local function cardTweens(state: CardState, list: { Tween }, finish: (() -> ())?)
	for _, tween in state.tweens do
		tween:Cancel()
	end
	state.token += 1
	local token = state.token
	state.tweens = list
	local remaining = #list
	if remaining == 0 then
		if finish then
			finish()
		end
		return
	end
	for _, tween in list do
		tween.Completed:Connect(function(playback: Enum.PlaybackState)
			if playback ~= Enum.PlaybackState.Completed or state.token ~= token then
				return
			end
			remaining -= 1
			if remaining == 0 and finish then
				finish()
			end
		end)
	end
	for _, tween in list do
		tween:Play()
	end
end

-- Carte de Clément (un cadre avec un enfant HoverOutline) : au survol, HoverOutline visible et son
-- enfant Icon grossit (UIScale passager), penche et se décale ; à la sortie, tout revient exactement
-- (Position, Rotation, Visible d'origine) et le UIScale est détruit. Sans effet la deuxième fois.
function Motion.HoverCard(card: GuiObject)
	if cards[card] then
		return
	end
	local spec = UiMotion.HoverCard
	local state: CardState = {
		token = 0,
		tweens = {},
		scale = nil,
		icon = nil,
		basePosition = nil,
		baseRotation = 0,
		outlineBase = nil,
		pop = false,
		cardRotation = nil,
		cardScale = nil,
	}
	cards[card] = state
	local function cardIn()
		local pop = hoverPop(card)
		state.pop = pop
		local info = if pop then CARD_POP_INFO else CARD_INFO
		local outline = card:FindFirstChild(spec.Outline)
		if outline and outline:IsA("GuiObject") then
			if state.outlineBase == nil then
				state.outlineBase = outline.Visible
			end
			outline.Visible = true
		end
		local found = card:FindFirstChild(spec.Icon)
		local icon: GuiObject? = if found and found:IsA("GuiObject") then found :: GuiObject else nil
		local list: { Tween } = {}
		if icon then
			if state.basePosition == nil or state.icon ~= icon then
				local rest = rests[icon]
				state.icon = icon
				state.basePosition = if rest then rest.position else icon.Position
				state.baseRotation = if rest then rest.rotation else icon.Rotation
			end
			local basePosition = state.basePosition :: UDim2
			local scale = state.scale
			if scale == nil or scale.Parent ~= icon then
				scale = nil
				if icon:FindFirstChildOfClass("UIScale") == nil then
					local created = Instance.new("UIScale")
					created.Name = UiMotion.Hover.ScaleName
					created.Parent = icon
					scale = created
				end
				state.scale = scale
			end
			if scale then
				centerOn(icon, scale.Scale) -- a299 : l'Icon grossit autour de son centre (rien sous un UIScale de Clément)
				table.insert(list, TweenService:Create(scale, info, { Scale = if pop then UiMotion.HoverPop.IconScale else spec.IconScale }))
			end
			if pop then
				-- Vague 59 : l'Icon reste à sa place (sa rotation et sa position de Clément).
				icon.Rotation = state.baseRotation
				icon.Position = Motion.Placed(icon, basePosition) -- a299 : recentrée, même place
			elseif card:GetAttribute("IconHover") ~= nil then
				-- a285 : l'Icon saute (IconHover, UiAttrFx) : ni penché ni décalé ici.
			else
				table.insert(list, TweenService:Create(icon, CARD_INFO, {
					Rotation = state.baseRotation + spec.Tilt,
					Position = Motion.Placed(icon, basePosition + UDim2.fromScale(spec.ShiftX, spec.ShiftY)),
				}))
			end
		end
		if not pop then
			-- a286 (L-224 point 2) : la carte grossit de 3 % (Hover.CardTo) en Hover.SizedTime, par un UIScale à elle
			-- (aucun si Clément lui en a déjà mis un).
			local cardScale = state.cardScale
			if cardScale == nil or cardScale.Parent ~= card then
				cardScale = nil
				if card:FindFirstChildOfClass("UIScale") == nil then
					local created = Instance.new("UIScale")
					created.Name = UiMotion.Hover.ScaleName
					created.Parent = card
					cardScale = created
				end
				state.cardScale = cardScale
			end
			if cardScale then
				centerOn(card, cardScale.Scale) -- a299 : la carte grossit autour de son centre (hors layout)
				table.insert(list, TweenService:Create(cardScale, SIZED_INFO, { Scale = UiMotion.Hover.CardTo }))
			end
		end
		if pop then
			if state.cardRotation == nil then
				state.cardRotation = card.Rotation
			end
			table.insert(list, TweenService:Create(card, info, { Rotation = (state.cardRotation :: number) + UiMotion.HoverPop.CardTilt }))
		end
		cardTweens(state, list, nil)
		Motion.PlaySound(UiMotion.Hover.Sound)
	end
	local function cardOut()
		unwatch(card)
		local outline = card:FindFirstChild(spec.Outline)
		if outline and outline:IsA("GuiObject") and state.outlineBase ~= nil then
			outline.Visible = state.outlineBase :: boolean
			state.outlineBase = nil
		end
		local icon = state.icon
		local basePosition = state.basePosition
		local cardRotation = state.cardRotation
		local list: { Tween } = {}
		if cardRotation ~= nil then
			table.insert(list, TweenService:Create(card, CARD_BACK_INFO, { Rotation = cardRotation }))
		end
		if icon ~= nil and basePosition ~= nil then
			local scale = state.scale
			if scale and scale.Parent == icon then
				table.insert(list, TweenService:Create(scale, CARD_BACK_INFO, { Scale = 1 }))
			end
			if not state.pop then
				table.insert(list, TweenService:Create(icon, CARD_BACK_INFO, { Rotation = state.baseRotation, Position = Motion.Placed(icon, basePosition) }))
			end
		end
		local cardScale = state.cardScale -- a286
		if cardScale and cardScale.Parent == card then
			table.insert(list, TweenService:Create(cardScale, CARD_BACK_INFO, { Scale = 1 }))
		end
		if #list == 0 then
			return
		end
		cardTweens(state, list, function()
			if cardRotation ~= nil then
				card.Rotation = cardRotation
				state.cardRotation = nil
			end
			if icon ~= nil and basePosition ~= nil then
				centerOff(icon) -- a299 : AnchorPoint de Clément, puis sa Position
				icon.Position = basePosition
				icon.Rotation = state.baseRotation
				state.basePosition = nil
			end
			local own = state.scale
			state.scale = nil
			if own then
				own:Destroy()
			end
			local ownCard = state.cardScale -- a286
			state.cardScale = nil
			if ownCard then
				ownCard:Destroy()
			end
			centerOff(card) -- a299
		end)
	end
	-- Vague 25 : survol seulement pour la carte du dessus (voir onTop), comme Motion.Button.
	card.MouseEnter:Connect(function()
		if onTop(card) then
			cardIn()
			watchHover(card, cardOut, function(): boolean
				return false
			end) -- a290 (L-275)
		end
	end)
	card.MouseLeave:Connect(cardOut)
end

function Motion.GetState(inst: Instance): Phase?
	local entry = entries[inst]
	return if entry then entry.phase else nil
end

------------------------------------------------------------------------------
-- Chiffres qui défilent
------------------------------------------------------------------------------

function Motion.StopRoll(label: TextLabel)
	local roll = rolls[label]
	if roll == nil then
		return
	end
	rolls[label] = nil
	roll.connection:Disconnect()
	roll.tween:Cancel()
	roll.value:Destroy()
end

function Motion.Roll(label: TextLabel, from: number?, to: number, format: (number) -> string, info: TweenInfo?)
	local current = rolls[label]
	if current ~= nil and current.to == to then
		return -- déjà en route vers cette valeur
	end
	local start: number
	if current ~= nil then
		start = current.value.Value -- le nombre affiché en ce moment
	elseif from ~= nil then
		start = from
	else
		label.Text = format(to) -- premier remplissage : pas de défilement
		return
	end
	local integers = to % 1 == 0 and (if current ~= nil then current.integers else start % 1 == 0)
	Motion.StopRoll(label)
	if start ~= start or to ~= to or start == to or format(start) == format(to) then
		label.Text = format(to) -- rien à faire défiler (ou valeur invalide) : la valeur finale
		return
	end

	rollTokens += 1
	local token = rollTokens
	local rising = to > start
	local value = Instance.new("NumberValue")
	value.Value = start
	local shown: string? = nil
	local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
		local roll = rolls[label]
		if roll == nil or roll.token ~= token then
			return
		end
		local number = value.Value
		if integers then
			number = if rising then math.floor(number) else math.ceil(number)
		end
		local text = format(number)
		if text ~= shown then
			shown = text
			label.Text = text
		end
	end)
	local tween = TweenService:Create(value, info or ROLL_INFO, { Value = to })
	rolls[label] = { token = token, value = value, tween = tween, connection = connection, to = to, integers = integers }
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		local roll = rolls[label]
		if roll == nil or roll.token ~= token or state ~= Enum.PlaybackState.Completed then
			return
		end
		rolls[label] = nil
		connection:Disconnect()
		value:Destroy()
		label.Text = format(to) -- valeur finale exacte
	end)
	tween:Play()
end

return Motion
