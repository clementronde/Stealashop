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
--   Motion.Success(button)      le bouton saute à Success.From et revient ; son Success.Sound.
--   Motion.HoverCard(card)      carte survolée : HoverOutline visible, Icon grossi, penché, décalé ;
--                               tout revient à la sortie (L-091 point 7).
--   Motion.Pop(object, from, info)
--                               sursaut passager from → 1 (UIScale PopScaleName détruit à la fin) :
--                               CashBump, TimerTick. Rien sur un objet qui a déjà un autre UIScale.
--   Motion.SetSoundPlayer(play?) / Motion.PlaySound(name)
--                               sons d'UI (UI_Hover, UI_Success…) : joués par la fonction donnée
--                               (UiFeelController), rien sans elle.
--   Motion.Roll(label, from, to, format)
--                               le nombre défile de `from` à `to`, écrit par `format` à chaque image
--                               (Shared/Format) ; à la fin, exactement format(to). from = nil
--                               (premier remplissage) : format(to) tout de suite, sans défilement.
--                               Pendant un défilement, une nouvelle valeur repart du nombre affiché.
--                               Deux bouts entiers : on défile en entiers (pas de « $57.3 » entre
--                               $50 et $80).
--   Motion.StopRoll(label)      arrête un défilement ; le texte reste tel quel.
--   Motion.GetState(inst)       "Opening", "Open", "Closing", "Closed", ou nil (jamais animé) :
--                               pour un test (banc, barre de commande en Studio).
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
type Transition = { scale: number, info: TweenInfo }

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
}
local CLOSE: Transition = {
	scale = UiMotion.Close.To,
	info = TweenInfo.new(UiMotion.Close.Time, UiMotion.Close.Style, UiMotion.Close.Direction),
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

local IS_STUDIO = RunService:IsStudio()

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
		return { inst :: GuiObject }
	end
	local list: { GuiObject } = {}
	for _, child in inst:GetChildren() do
		if child:IsA("GuiObject") and not fillsScreen(child :: GuiObject) and not apart[child] then
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
	return gui.Enabled and gui.Parent ~= nil and (entry == nil or entry.phase ~= "Closing")
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
	run(current, targetsOf(inst), transition.scale, transition.scale, 1, transition.info, function()
		current.phase = "Open"
		release(current)
	end)
	if inst:IsA("ScreenGui") then
		staggerIn(inst, staggerItems(inst)) -- L-094 : les cartes arrivent une à une après la fenêtre
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
	run(entry, targetsOf(inst), nil, 1, transition.scale, transition.info, function()
		entry.phase = "Closed"
		setShown(inst, false)
		release(entry)
		local callbacks = table.clone(entry.after)
		table.clear(entry.after)
		runAfter(callbacks)
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

function Motion.Open(gui: ScreenGui)
	closeGroup(gui)
	enter(gui, OPEN)
end

-- Cadre racine animé à part (RunBanner de UI_Chase, L-092 3a) : Open et Close de son écran ne le
-- mettent pas à l'échelle, pour que deux UIScale ne se gênent pas.
function Motion.KeepScale(object: GuiObject)
	apart[object] = true
end

function Motion.SetCloser(gui: ScreenGui, close: (() -> ())?)
	if close then
		closers[gui] = close
	else
		closers[gui] = nil
	end
end

function Motion.Close(gui: ScreenGui, after: (() -> ())?)
	leave(gui, CLOSE, after)
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

local soundPlayer: ((name: string) -> ())? = nil

function Motion.SetSoundPlayer(play: ((name: string) -> ())?)
	soundPlayer = play
end

function Motion.PlaySound(name: string)
	local play = soundPlayer
	if play then
		local ok = pcall(play, name)
		if not ok and IS_STUDIO then
			warn(`[Motion] son « {name} » : erreur dans le lecteur de sons`)
		end
	end
end

------------------------------------------------------------------------------
-- Boutons : survol, appui, relâché, réussite (L-091 point 7)
------------------------------------------------------------------------------

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
}

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
	if button:FindFirstChildOfClass("UIScale") ~= nil then
		return nil
	end
	local scale = Instance.new("UIScale")
	scale.Name = UiMotion.Hover.ScaleName
	scale.Parent = button
	state.scale = scale
	return scale
end

local function scaleButton(button: GuiButton, state: ButtonState, goal: number, info: TweenInfo, from: number?)
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
		if goal == 1 and not state.over and not state.down then
			if state.scale == current then
				state.scale = nil
			end
			current:Destroy() -- revenu à 1 : rien n'est laissé
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

-- Survol (Hover), appui (Press) et relâché (Release) d'un bouton ; calque Shade s'il existe ; son
-- Hover.Sound au survol. Sans effet la deuxième fois.
function Motion.Button(button: GuiButton)
	local state = buttonState(button)
	if state.wired then
		return
	end
	state.wired = true
	local function hoverIn()
		state.over = true
		if not state.down then
			scaleButton(button, state, UiMotion.Hover.To, HOVER_INFO)
			shadeTo(state, UiMotion.Hover.ShadeTransparency, HOVER_INFO)
		end
		Motion.PlaySound(UiMotion.Hover.Sound)
	end
	local function hoverOut()
		state.over = false
		state.down = false
		scaleButton(button, state, 1, HOVER_INFO)
		shadeTo(state, state.shadeBase, HOVER_INFO)
	end
	-- Vague 25 : survol seulement si le bouton est l'élément du dessus (voir onTop).
	button.MouseEnter:Connect(function()
		if onTop(button) then
			hoverIn()
		end
	end)
	button.MouseLeave:Connect(hoverOut)
	button.MouseButton1Down:Connect(function()
		state.down = true
		scaleButton(button, state, UiMotion.Press.To, PRESS_INFO)
		shadeTo(state, UiMotion.Press.ShadeTransparency, PRESS_INFO)
	end)
	button.MouseButton1Up:Connect(function()
		if not state.down then
			return
		end
		state.down = false
		scaleButton(button, state, if state.over then UiMotion.Hover.To else 1, RELEASE_INFO)
		shadeTo(state, if state.over then UiMotion.Hover.ShadeTransparency else state.shadeBase, RELEASE_INFO)
	end)
	-- L-092 3g : sur un écran tactile, pas de MouseLeave ; à la fin du toucher (doigt levé, ou
	-- glissé hors du bouton), le bouton revient à 1 et Shade à sa transparence d'origine.
	local function touchEnded()
		state.over = false
		state.down = false
		scaleButton(button, state, 1, RELEASE_INFO)
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
	scaleButton(button, state, if state.over then UiMotion.Hover.To else 1, SUCCESS_INFO, UiMotion.Success.From)
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
}

local CARD_INFO = TweenInfo.new(UiMotion.HoverCard.Time, UiMotion.HoverCard.Style, UiMotion.HoverCard.Direction)
local CARD_BACK_INFO = TweenInfo.new(UiMotion.HoverCard.BackTime, UiMotion.HoverCard.BackStyle, Enum.EasingDirection.Out)
local cards: { [GuiObject]: CardState } = setmetatable({}, { __mode = "k" }) :: any

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
	}
	cards[card] = state
	local function cardIn()
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
				state.icon = icon
				state.basePosition = icon.Position
				state.baseRotation = icon.Rotation
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
				table.insert(list, TweenService:Create(scale, CARD_INFO, { Scale = spec.IconScale }))
			end
			table.insert(list, TweenService:Create(icon, CARD_INFO, {
				Rotation = state.baseRotation + spec.Tilt,
				Position = basePosition + UDim2.fromScale(spec.ShiftX, spec.ShiftY),
			}))
		end
		cardTweens(state, list, nil)
		Motion.PlaySound(UiMotion.Hover.Sound)
	end
	local function cardOut()
		local outline = card:FindFirstChild(spec.Outline)
		if outline and outline:IsA("GuiObject") and state.outlineBase ~= nil then
			outline.Visible = state.outlineBase :: boolean
			state.outlineBase = nil
		end
		local icon = state.icon
		local basePosition = state.basePosition
		if icon == nil or basePosition == nil then
			return
		end
		local list: { Tween } = {}
		local scale = state.scale
		if scale and scale.Parent == icon then
			table.insert(list, TweenService:Create(scale, CARD_BACK_INFO, { Scale = 1 }))
		end
		table.insert(list, TweenService:Create(icon, CARD_BACK_INFO, { Rotation = state.baseRotation, Position = basePosition }))
		cardTweens(state, list, function()
			icon.Position = basePosition
			icon.Rotation = state.baseRotation
			state.basePosition = nil
			local own = state.scale
			state.scale = nil
			if own then
				own:Destroy()
			end
		end)
	end
	-- Vague 25 : survol seulement pour la carte du dessus (voir onTop), comme Motion.Button.
	card.MouseEnter:Connect(function()
		if onTop(card) then
			cardIn()
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

function Motion.Roll(label: TextLabel, from: number?, to: number, format: (number) -> string)
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
	local tween = TweenService:Create(value, ROLL_INFO, { Value = to })
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
