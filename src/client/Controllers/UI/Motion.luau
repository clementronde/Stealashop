--!strict
-- Motion (DEV-052, client) : animations d'UI sur les écrans de Clément, sans toucher à leur visuel
-- (Partie 1, section 2.2, « Libre pour Ironix : … animer à l'ouverture et à la fermeture »). Module
-- d'aide des contrôleurs, rangé dans le sous-dossier UI : le Loader ne le démarre pas.
--
-- API (client) :
--   Motion.Open(gui)            Enabled = true, puis entrée des cadres racine de l'écran (échelle
--                               Open.From → 1, léger rebond). Déjà allumé : pas d'entrée (il compte
--                               comme ouvert). En train de se fermer : la fermeture est annulée et
--                               l'écran revient à 1.
--   Motion.Close(gui, after?)   sortie courte (1 → Close.To), puis Enabled = false, puis after().
--                               Fermé tout de suite, sans animation : un écran déjà fermé, un écran
--                               allumé que Motion n'a jamais vu (copie de StarterGui arrivée
--                               allumée) ou retiré du jeu. after n'est pas appelé si une réouverture
--                               annule la fermeture.
--   Motion.Show(object)         la même chose pour un élément (Visible au lieu d'Enabled), mis
--   Motion.Hide(object, after?)   à l'échelle lui-même (Show.From, Hide.To) : HeistTimer, GuardMeter.
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
-- police ni transparence de Clément ne change, même un instant. Pas d'effet d'échelle :
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
local ROLL_INFO = TweenInfo.new(UiMotion.Roll.Time, UiMotion.Roll.Style, UiMotion.Roll.Direction)

local IS_STUDIO = RunService:IsStudio()

local Motion = {}

-- Clés faibles : un écran détruit (ResetOnSpawn) n'est pas retenu ici.
local entries: { [Instance]: Entry } = setmetatable({}, { __mode = "k" }) :: any
local owners: { [UIScale]: Entry } = setmetatable({}, { __mode = "k" }) :: any -- UIScale créés ici
local rolls: { [TextLabel]: Rolling } = setmetatable({}, { __mode = "k" }) :: any
local noticed: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local closers: { [Instance]: () -> () } = setmetatable({}, { __mode = "k" }) :: any -- SetCloser
local rollTokens = 0

-- Contrat (L-089 point 4) : attribut des ScreenGui de Clément, sa valeur nomme le groupe.
local GROUP_ATTRIBUTE = "ScreenGroup"

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

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
-- qui couvrent tout l'écran.
local function targetsOf(inst: Instance): { GuiObject }
	if inst:IsA("GuiObject") then
		return { inst :: GuiObject }
	end
	local list: { GuiObject } = {}
	for _, child in inst:GetChildren() do
		if child:IsA("GuiObject") and not fillsScreen(child :: GuiObject) then
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
end

local function leave(inst: Instance, transition: Transition, after: (() -> ())?)
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
