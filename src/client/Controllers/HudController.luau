--!strict
-- HudController (DEV-021, client) : branche l'écran UI_HUD de Clément (contrat 2.2 ; liaison L-026
-- et L-027 ; Partie 1, sections 5.3, 5.5 et 7.1).
--
-- Rôle :
--   - Cash (« $11.1B »), Income (« +$1.2K/s »), Speed, Strength et Damage (« 1.4K ») : écrits au
--     format court (Shared/Format) depuis les attributs du Player posés par le serveur : Cash
--     (DataService), Income (DisplayService), WalkSpeed et Strength (StatsService), Damage
--     (ToolService). Le client n'envoie rien. Attribut pas encore posé (profil en cours de
--     chargement) : « … ».
--     Speed affiche la vitesse de marche (attribut WalkSpeed : 16 au départ, formule 5.1 avec le
--     trail), pas les points d'entraînement (attribut Speed) : c'est le nombre que comparent les
--     panneaux des vitrines, les arches et le message du vigile (décision d'Ironix, 2026-11-07).
--   - HeistTimer : chrono du braquage (« HEIST: 7s »), visible pendant un vol, masqué le reste du
--     temps. Piloté par le remote HeistTimer(storeId, endsAt) que HeistController relaie (endsAt
--     en heure serveur, workspace:GetServerTimeNow() ; 0 = masquer). Plusieurs chronos à la fois
--     (deux magasins proches) : celui qui finit le plus tard, donc le plus récent. Masqué tant que le
--     joueur est poursuivi (ChaseController.IsChased) : « RUN! » prend sa place ; un chrono vu pendant la
--     poursuite ne revient plus pour ce vol, même quand elle finit avant lui (Cantin, 2026-11-13).
--   - GuardMeter et son enfant Fill : CACHÉS depuis le 2026-11-13 (Cantin, SHOW_GUARD_METER). Avant :
--     visibles pendant une poursuite (ChaseController, remote
--     ChaseState). Largeur de Fill = proximité du vigile : pleine à la distance de capture
--     (Balance.Guard.CatchDistance), vide à GiveUpLead studs d'avance (échelle de la jauge seulement :
--     le vigile n'abandonne plus, vague 23), linéaire entre les deux. Seule la largeur en Scale change.
--   - Battements de cœur sous Balance.Guard.HeartbeatDistance (ChaseController.IsClose) : le son
--     HEARTBEAT_SOUND de ReplicatedStorage/Assets/Sounds, en boucle ; silence s'il manque.
--   - NightCountdown (DEV-047) : depuis les attributs du Workspace posés par NightCycleService
--     (NightPhase, NightPhaseEndsAt, NightFallsAt, heures serveur) : le jour « Night in 7:42 »
--     (Night.DayCountdownText), pendant l'alerte « NIGHT FALLS IN 29s » (Night.WarningCountdownText),
--     la nuit « Dawn in 1:42 » (Night.NightCountdownText) ; « 45s » sous une minute. Phase pas
--     encore posée : « … ».
--   - ReturnBaseButton (DEV-045) : un clic envoie ReturnToBase ; le serveur décide (recharge, mains
--     vides) et répond par Notify s'il refuse. Recharge affichée (« 84s ») depuis l'attribut
--     ReturnBaseReadyAt du Player (ReturnBaseService) : dans l'enfant Cooldown (TextLabel) du bouton
--     s'il existe (proposé à Clément, montré pendant la recharge, caché sinon), à défaut dans le
--     texte du bouton lui-même (TextButton), remis tel quel à la fin. Le label décoratif BaseLabel
--     (« BASE ») n'est jamais touché.
--   - Cache les éléments des fonctions pas encore livrées (Config/Features) : RobuxShopButton,
--     IndexButton, RebirthButton, NightCountdown, ReturnBaseButton. Shop et Rebirth restent visibles
--     pendant leur aperçu (RobuxShopPreview, RebirthPreview : L-071, les trois boutons de gauche sont
--     visibles dès maintenant) ; leur clic est branché par RobuxShopController, IndexController et
--     RebirthController, pas ici.
--   - Revenu retenu pendant l'ouverture d'un colis (vague 8) : le serveur expose l'objet, et
--     l'attribut Income monte, dès l'ouverture, plusieurs secondes avant que l'écran UI_Unbox
--     révèle l'objet. UnboxController retient donc Income (HoldIncome) à l'arrivée d'UnboxReveal et
--     le relâche quand l'écran a montré le revenu de l'objet. Pendant ce temps, Income garde la
--     valeur d'avant l'objet ; rien ne change côté serveur (argent et sauvegarde). Plusieurs
--     ouvertures d'affilée : chacune montre la hausse de son objet, dans l'ordre.
--   - Animations (DEV-052, module UI/Motion, valeurs dans Config/UiMotion) : Cash et Income
--     défilent de l'ancienne valeur à la nouvelle (Motion.Roll), au même format ; au premier
--     remplissage, la valeur s'écrit d'un coup. Le revenu retenu ne défile qu'à son relâchement,
--     donc à la révélation de l'objet (DEV-050). HeistTimer et GuardMeter apparaissent et
--     disparaissent par Motion.Show et Motion.Hide (un UIScale passager, créé et retiré par Motion).
--     HeistTimer (ou son enfant Box) sursaute à chaque seconde, avec un tic (TimerTick, L-091).
--   - Argent retenu (L-091 point 3) : GainController retient Cash (HoldCash) pendant qu'un gain vole
--     vers le compteur ; l'argent défile à l'arrivée de la case.
-- Les éléments sont cherchés par leur nom parmi les descendants de l'écran (Contract/Find) : les
-- cadres autour (LeftRail, StatsPanel…) sont décoratifs et peuvent changer. Seuls les textes, la
-- visibilité et la largeur de Fill sont touchés (2.2, « Libre pour Ironix »), jamais un style ;
-- les effets de Motion sont passagers.
-- Roblox copie UI_HUD de StarterGui dans PlayerGui ; un écran recréé (ResetOnSpawn) est rebranché.
--
-- API (client) :
--   HudController.HoldIncome() -> relâcher
--       Income garde la valeur que ce contrôleur connaît à cet instant (la dernière qu'il a vue
--       arriver, même si la suivante est déjà posée sur le Player sans qu'il l'ait encore traitée)
--       jusqu'à l'appel de `relâcher` (sans effet la deuxième fois). Plusieurs retenues : Income
--       montre la valeur gardée par la plus ancienne encore active, puis, quand toutes sont
--       relâchées, la valeur réelle. Une retenue oubliée se relâche toute seule au bout de
--       MAX_INCOME_HOLD secondes.
--   HudController.HoldCash(base) -> relâcher
--       Cash montre `base` jusqu'à l'appel de `relâcher` (voir plus bas, L-091 point 3).
--   HudController.IsHeistTimerShown() -> boolean
--       Le chrono « HEIST » est à l'écran (pour ZoneBannerController, qui attend sa fin ; Cantin, 2026-11-13).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Features = require(Config:WaitForChild("Features"))
local Night = require(Config:WaitForChild("Night"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))
local UiMotion = require(Config:WaitForChild("UiMotion"))

-- Ce que ce contrôleur utilise de HeistController (a10) et de ChaseController (a12).
type HeistApi = {
	OnTimer: (listener: (storeId: string, endsAt: number) -> ()) -> () -> (),
	GetTimers: () -> { [string]: number },
}
type ChaseApi = {
	IsChased: () -> boolean,
	GetDistance: () -> number?,
	IsClose: () -> boolean,
}

type Stat = {
	Attribute: string, -- attribut du Player, posé par le serveur
	Element: string, -- TextLabel du contrat 2.2
	Write: (value: number) -> string,
	Roll: boolean, -- le nombre défile d'une valeur à l'autre (DEV-052)
}

-- Écran branché.
type Hud = {
	gui: ScreenGui,
	stats: { [Stat]: TextLabel },
	written: { [Stat]: number }, -- dernier nombre écrit (départ du défilement) ; absent = premier remplissage
	heistTimer: TextLabel?,
	guardMeter: GuiObject?,
	fill: GuiObject?,
	fillSize: UDim2, -- taille de Fill posée par Clément : seule la largeur en Scale change
	nightCountdown: TextLabel?,
	returnButton: GuiButton?,
	cooldownLabel: TextLabel?, -- ReturnBaseButton.Cooldown, s'il existe
	buttonText: string?, -- texte d'origine du bouton (TextButton sans Cooldown), remis après la recharge
}

local SCREEN = "UI_HUD"

local STATS: { Stat } = {
	{ Attribute = "Cash", Element = "Cash", Write = Format.money, Roll = true },
	{ Attribute = "Income", Element = "Income", Write = Format.income, Roll = true },
	{ Attribute = "WalkSpeed", Element = "Speed", Write = Format.short, Roll = false }, -- vitesse de marche, pas les points
	{ Attribute = "Strength", Element = "Strength", Write = Format.short, Roll = false },
	{ Attribute = "Damage", Element = "Damage", Write = Format.short, Roll = false },
}

local INCOME_ATTRIBUTE = "Income" -- posé par DisplayService ; retenu par HoldIncome
local INCOME_STAT: Stat = STATS[2]
local CASH_STAT: Stat = STATS[1] -- retenu par HoldCash (GainController, L-091 point 3)
for _, stat in STATS do
	if stat.Attribute == INCOME_ATTRIBUTE then
		INCOME_STAT = stat
	elseif stat.Attribute == "Cash" then
		CASH_STAT = stat
	end
end

-- V0 proposé, absent du doc : durée max (s) d'une retenue du revenu, filet de sécurité si elle
-- n'était jamais relâchée. Une ouverture montre son revenu en moins de 10 s ; une file de trois ou
-- quatre ouvertures d'affilée tient dans ce délai.
local MAX_INCOME_HOLD = 60
-- V0 proposé, absent du doc : durée max (s) d'une retenue de l'argent (une case vole en moins d'une
-- seconde, Config/UiMotion.CashFly) : filet de sécurité si elle n'était jamais relâchée.
local MAX_CASH_HOLD = 10
-- Chrono du vol : enfant facultatif de HeistTimer qui sursaute à chaque seconde (tableau de Clément,
-- « HeistTimer.Box », L-091 point 7) ; sans lui, HeistTimer lui-même.
local TIMER_BOX = "Box"
local TICK_INFO = TweenInfo.new(UiMotion.TimerTick.Time, UiMotion.TimerTick.Style, UiMotion.TimerTick.Direction)
-- Chrono rouge à TimerTick.RedBelow s ou moins (L-092 3c ; seuil « n <= 3 » du prototype feel2_proto.luau).
local TIMER_RED: Color3 = UiMotion.TimerTick.RedColor

-- Éléments cachés tant que leur fonction n'existe pas (Config/Features, liaison L-026). Les boutons
-- Shop et Rebirth restent visibles pendant leur aperçu (L-071).
local GATED: { { Element: string, Enabled: boolean } } = {
	{ Element = "RobuxShopButton", Enabled = Features.RobuxShop or Features.RobuxShopPreview },
	{ Element = "IndexButton", Enabled = Features.Index },
	{ Element = "RebirthButton", Enabled = Features.Rebirth or Features.RebirthPreview },
	{ Element = "NightCountdown", Enabled = Features.NightCycle },
	{ Element = "ReturnBaseButton", Enabled = Features.ReturnToBase },
}

-- V0 proposé, absent du doc : nom du son des battements de cœur (DEV-051), cherché comme les sons
-- des marqueurs (MarkerSounds.find : ReplicatedStorage/Assets/Sounds, sous-dossiers compris).
local HEARTBEAT_SOUND = "Chase_Heartbeat"
-- V0 proposé, absent du doc : texte d'une valeur pas encore posée par le serveur.
local UNKNOWN_TEXT = "…"

-- V0 proposé, absent du doc : texte du chrono « HEIST: 7s », en anglais (L-036).
local function timerText(seconds: number): string
	return `HEIST: {seconds}s`
end

-- Attributs posés par le serveur (mêmes noms dans NightCycleService et ReturnBaseService).
local PHASE_ATTRIBUTE = "NightPhase"
local ENDS_AT_ATTRIBUTE = "NightPhaseEndsAt"
local FALLS_AT_ATTRIBUTE = "NightFallsAt"
local READY_AT_ATTRIBUTE = "ReturnBaseReadyAt"
-- V0 proposé, absent du contrat 2.2 : enfant facultatif de ReturnBaseButton où écrire la recharge.
local COOLDOWN_LABEL = "Cooldown"

-- Durée restante : « 7:42 » à partir d'une minute, « 45s » en dessous (secondes arrondies vers le haut).
local function clockText(seconds: number): string
	local s = math.max(0, math.ceil(seconds - 1e-6))
	if s >= 60 then
		return string.format("%d:%02d", s // 60, s % 60)
	end
	return `{s}s`
end

local IS_STUDIO = RunService:IsStudio()
local CATCH_DISTANCE: number = Balance.Guard.CatchDistance
local GIVE_UP_LEAD: number = Balance.Guard.GiveUpLead

local HudController = {}

local localPlayer = Players.LocalPlayer
local heist: HeistApi? = nil
local chase: ChaseApi? = nil
local net: any = nil -- Shared/Net, chargé au démarrage (attend les remotes du serveur)
local hud: Hud? = nil
local shownCountdown: string? = nil -- texte affiché par NightCountdown
local shownCooldown: string? = nil -- recharge affichée sur ReturnBaseButton ; nil = prêt
local timers: { [string]: number } = {} -- storeId → endsAt (heure serveur)
-- Chronos vus pendant une poursuite (storeId → leur endsAt) : plus jamais montrés pour ce vol (Cantin,
-- 2026-11-13). Un nouveau chrono du même magasin (autre endsAt, nouvelle casse) se montre de nouveau.
local muted: { [string]: number } = {}
local shownSeconds: number? = nil -- secondes affichées par HeistTimer ; nil = masqué
-- Couleur d'origine du texte de HeistTimer, gardée pendant qu'il est rouge (clés faibles : écran remplacé).
local timerColors: { [TextLabel]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
local chased = false -- GuardMeter affiché
local SHOW_GUARD_METER = false -- Cantin, 2026-11-13 : jauge de distance au vigile retirée (voir updateGuardMeter)
local heartbeatOn = false
local heartbeatSound: Sound? = nil
local warned: { [string]: boolean } = {}

-- Retenues du revenu (HoldIncome), dans l'ordre de création.
type IncomeHold = { base: any, expiresAt: number }
local incomeHolds: { IncomeHold } = {}
local incomeSeen: any = nil -- dernière valeur d'Income traitée par ce contrôleur
local incomeTracked = false -- incomeSeen suit l'attribut (Start est passé)
-- Retenues de l'argent (HoldCash) : chacune garde l'argent d'avant un gain qui vole vers le compteur.
local cashHolds: { IncomeHold } = {}

local function warnOnce(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(message)
	end
end

-- Contrôleur voisin (même dossier), ou nil s'il manque.
local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		warnOnce(name, `[HUD] {name} absent : la partie du HUD qui en dépend reste cachée`)
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result
	end
	warnOnce(name, `[HUD] {name} : require impossible ({result}) ; la partie du HUD qui en dépend reste cachée`)
	return nil
end

-- Élément `name` de `root`, de la classe `class`, ou nil (un avertissement par élément, en Studio ;
-- le ContractChecker le signale aussi).
local function element(root: Instance, name: string, class: string): Instance?
	local found = Find.path(root, name)
	if found ~= nil and found:IsA(class) then
		return found
	end
	local where = `{root.Name}.{name}`
	warnOnce(where, if found then `[HUD] {where} n'est pas un {class} : ignoré` else `[HUD] {where} introuvable : ignoré`)
	return nil
end

-- Valeurs -------------------------------------------------------------------------------------

-- Dernière valeur d'Income connue de ce contrôleur (avant Start : celle du Player).
local function latestIncome(): any
	return if incomeTracked then incomeSeen else localPlayer:GetAttribute(INCOME_ATTRIBUTE)
end

-- Valeur d'Income à afficher : celle de la plus ancienne retenue active, sinon la dernière connue.
local function shownIncome(): any
	local hold = incomeHolds[1]
	if hold then
		return hold.base
	end
	return latestIncome()
end

local function writeStat(stat: Stat)
	local current = hud
	local label = if current then current.stats[stat] else nil
	if current == nil or label == nil then
		return
	end
	local value = if stat == INCOME_STAT
		then shownIncome()
		elseif stat == CASH_STAT and cashHolds[1] ~= nil then cashHolds[1].base
		else localPlayer:GetAttribute(stat.Attribute)
	if type(value) ~= "number" then
		Motion.StopRoll(label)
		current.written[stat] = nil
		label.Text = UNKNOWN_TEXT
	elseif stat.Roll then
		Motion.Roll(label, current.written[stat], value, stat.Write)
		current.written[stat] = value
	else
		label.Text = stat.Write(value)
	end
end

local function releaseHold(hold: IncomeHold)
	local index = table.find(incomeHolds, hold)
	if index == nil then
		return -- déjà relâchée (ou expirée)
	end
	table.remove(incomeHolds, index)
	writeStat(INCOME_STAT)
end

-- Filet de sécurité : relâche les retenues trop vieilles.
local function expireHolds()
	if #cashHolds > 0 then
		local now = os.clock()
		local expired = false
		for index = #cashHolds, 1, -1 do
			if cashHolds[index].expiresAt <= now then
				table.remove(cashHolds, index)
				expired = true
			end
		end
		if expired then
			warnOnce("cashHold", `[HUD] argent retenu plus de {MAX_CASH_HOLD} s : relâché (GainController ne l'a pas fait)`)
			writeStat(CASH_STAT)
		end
	end
	if #incomeHolds == 0 then
		return
	end
	local now = os.clock()
	local expired = false
	for index = #incomeHolds, 1, -1 do
		if incomeHolds[index].expiresAt <= now then
			table.remove(incomeHolds, index)
			expired = true
		end
	end
	if expired then
		warnOnce("incomeHold", `[HUD] revenu retenu plus de {MAX_INCOME_HOLD} s : relâché (UnboxController ne l'a pas fait)`)
		writeStat(INCOME_STAT)
	end
end

function HudController.HoldIncome(): () -> ()
	local hold: IncomeHold = { base = latestIncome(), expiresAt = os.clock() + MAX_INCOME_HOLD }
	table.insert(incomeHolds, hold)
	return function()
		releaseHold(hold)
	end
end

-- L-091 point 3 : Cash garde `base` (l'argent d'avant un gain) jusqu'à l'appel de `relâcher`, quand
-- la case qui vole arrive au compteur ; puis il défile jusqu'à l'argent réel. Plusieurs retenues :
-- Cash montre la base de la plus ancienne encore active. Une retenue oubliée se relâche toute seule
-- au bout de MAX_CASH_HOLD s. `relâcher` est sans effet la deuxième fois.
function HudController.IsHeistTimerShown(): boolean
	return shownSeconds ~= nil
end

function HudController.HoldCash(base: number): () -> ()
	local hold: IncomeHold = { base = base, expiresAt = os.clock() + MAX_CASH_HOLD }
	table.insert(cashHolds, hold)
	writeStat(CASH_STAT)
	return function()
		local index = table.find(cashHolds, hold)
		if index then
			table.remove(cashHolds, index)
			writeStat(CASH_STAT)
		end
	end
end

-- Chrono du braquage --------------------------------------------------------------------------

local function onTimer(storeId: string, endsAt: number)
	if endsAt > 0 then
		timers[storeId] = endsAt
	else
		timers[storeId] = nil
		muted[storeId] = nil
	end
end

local function updateHeistTimer(current: Hud)
	local label = current.heistTimer
	if label == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	-- Cantin, 2026-11-13 : jamais « HEIST » pendant « RUN! » (UI_Chase.RunBanner est au même endroit, en haut
	-- au centre), et plus jamais pour ce vol une fois RUN! apparu : un chrono vu pendant une poursuite reste
	-- masqué jusqu'à sa fin, même après la poursuite (capture, objet lâché).
	local api = chase
	local hidden = api ~= nil and api.IsChased()
	local endsAt: number? = nil
	for storeId, at in timers do
		if at <= now then
			timers[storeId] = nil -- fini : le rideau est tombé
			muted[storeId] = nil
		else
			if hidden then
				muted[storeId] = at
			end
			if muted[storeId] ~= at and (endsAt == nil or at > endsAt) then
				endsAt = at
			end
		end
	end
	local seconds = if endsAt and not hidden then math.ceil(endsAt - now) else nil
	if seconds == shownSeconds then
		return
	end
	local ticking = seconds ~= nil and shownSeconds ~= nil -- déjà affiché : une seconde de moins
	shownSeconds = seconds
	-- L-092 3c : rouge sous le seuil, couleur d'origine sinon (fin du vol, chrono remonté).
	local red = seconds ~= nil and seconds <= UiMotion.TimerTick.RedBelow
	local original: Color3? = timerColors[label]
	if red and not original then
		timerColors[label] = label.TextColor3
		label.TextColor3 = TIMER_RED
	elseif not red and original then
		timerColors[label] = nil
		label.TextColor3 = original
	end
	if seconds then
		label.Text = timerText(seconds)
		Motion.Show(label)
		if ticking then
			-- TimerTick (L-091 point 7) : sursaut et tic à chaque seconde.
			local box = label:FindFirstChild(TIMER_BOX, true)
			local target: GuiObject = if box and box:IsA("GuiObject") then box :: GuiObject else label
			Motion.Pop(target, UiMotion.TimerTick.From, TICK_INFO)
			Motion.PlaySound(UiMotion.TimerTick.Sound)
		end
	else
		Motion.Hide(label)
	end
end

-- Poursuite -----------------------------------------------------------------------------------

-- 1 = le vigile vous attrape, 0 = il est à GiveUpLead studs ou plus.
local function proximity(distance: number): number
	return math.clamp((GIVE_UP_LEAD - distance) / (GIVE_UP_LEAD - CATCH_DISTANCE), 0, 1)
end

local function setFill(current: Hud, fraction: number)
	local fill = current.fill
	if fill then
		local size = current.fillSize
		fill.Size = UDim2.new(fraction, size.X.Offset, size.Y.Scale, size.Y.Offset)
	end
end

local function updateGuardMeter(current: Hud)
	-- Cantin, 2026-11-13 : la jauge de distance au vigile n'est plus montrée (elle n'a plus de sens avec la
	-- règle du braquage de L-118). GuardMeter reste dans l'UI de Clément, caché ; le reste de la
	-- poursuite (RUN!, battements de cœur, musique) ne change pas.
	if not SHOW_GUARD_METER then
		return
	end
	local api = chase
	local active = api ~= nil and api.IsChased()
	if active ~= chased then
		chased = active
		local meter = current.guardMeter
		if meter then
			if active then
				Motion.Show(meter)
			else
				Motion.Hide(meter)
			end
		end
		if active then
			setFill(current, 0) -- jusqu'à la première mesure
		end
	end
	if api == nil or not active then
		return
	end
	local distance = api.GetDistance()
	if distance then
		setFill(current, proximity(distance))
	end
end

-- Battements de cœur, en boucle tant que le vigile est tout près.
local function setHeartbeat(on: boolean)
	if on == heartbeatOn then
		return
	end
	heartbeatOn = on
	if on and heartbeatSound == nil then
		local template = MarkerSounds.find(HEARTBEAT_SOUND)
		if template then
			local sound = template:Clone() :: Sound
			sound.Looped = true
			sound.Parent = SoundService -- son 2D, pour le joueur local seulement
			heartbeatSound = sound
		else
			warnOnce(
				HEARTBEAT_SOUND,
				`[HUD] son « {HEARTBEAT_SOUND} » absent de ReplicatedStorage/Assets/Sounds (DEV-051) : battements de cœur muets`
			)
		end
	end
	local sound = heartbeatSound
	if sound == nil then
		return
	end
	if on then
		sound:Play()
	else
		sound:Stop()
	end
end

-- Cycle jour / nuit ---------------------------------------------------------------------------

local function countdownText(now: number): string
	local phase = Workspace:GetAttribute(PHASE_ATTRIBUTE)
	local endsAt = Workspace:GetAttribute(ENDS_AT_ATTRIBUTE)
	if type(endsAt) ~= "number" then
		return UNKNOWN_TEXT
	end
	if phase == "Day" then
		local fallsAt = Workspace:GetAttribute(FALLS_AT_ATTRIBUTE)
		local at = if type(fallsAt) == "number" then fallsAt else endsAt + Night.WarningDuration
		return string.format(Night.DayCountdownText, clockText(at - now))
	elseif phase == "Warning" then
		return string.format(Night.WarningCountdownText, math.max(0, math.ceil(endsAt - now - 1e-6)))
	elseif phase == "Night" then
		return string.format(Night.NightCountdownText, clockText(endsAt - now))
	end
	return UNKNOWN_TEXT
end

local function updateNightCountdown(current: Hud, now: number)
	local label = current.nightCountdown
	if label == nil then
		return
	end
	local text = countdownText(now)
	if text ~= shownCountdown then
		shownCountdown = text
		label.Text = text
	end
end

-- Retour base ---------------------------------------------------------------------------------

local function onReturnBase()
	if net then
		net.Client.ReturnToBase:Fire()
	end
end

local function updateReturnButton(current: Hud, now: number)
	local button = current.returnButton
	if button == nil then
		return
	end
	local readyAt = localPlayer:GetAttribute(READY_AT_ATTRIBUTE)
	local left = if type(readyAt) == "number" then math.ceil(readyAt - now - 1e-6) else 0
	local text = if left > 0 then `{left}s` else nil -- « 84s », comme le Notify du serveur
	if text == shownCooldown then
		return
	end
	shownCooldown = text
	local label = current.cooldownLabel
	if label then
		if text then
			label.Text = text
		end
		label.Visible = text ~= nil
	elseif button:IsA("TextButton") then
		(button :: TextButton).Text = text or current.buttonText or ""
	end
end

-- Écran ---------------------------------------------------------------------------------------

local function bind(gui: ScreenGui)
	local stats: { [Stat]: TextLabel } = {}
	for _, stat in STATS do
		local label = element(gui, stat.Element, "TextLabel")
		if label then
			stats[stat] = label :: TextLabel
		end
	end
	local heistTimer = element(gui, "HeistTimer", "TextLabel") :: TextLabel?
	local meter = element(gui, "GuardMeter", "GuiObject") :: GuiObject?
	local fill = if meter then element(meter, "Fill", "GuiObject") :: GuiObject? else nil
	if meter and not SHOW_GUARD_METER then
		meter.Visible = false -- jauge retirée (Cantin, 2026-11-13) : cachée même si Clément la laisse visible
	end

	for _, gate in GATED do
		-- Tous les exemplaires (L-099 point 1 : boutons de LeftRail et de LeftRailTouch).
		local targets: { Instance } = if gate.Enabled then {} else Find.all(gui, gate.Element)
		for _, target in targets do
			if target:IsA("GuiObject") then
				target.Visible = false
			end
		end
	end

	-- Effet « pop » au survol de chaque bouton fixe du HUD (Shop, Index, Rebirth, Base, Invite, Rewards).
	for _, inst in gui:GetDescendants() do
		if inst:IsA("GuiButton") then
			Motion.Hover(inst)
		end
	end

	local nightCountdown = if Features.NightCycle then element(gui, "NightCountdown", "TextLabel") :: TextLabel? else nil
	local returnButton = if Features.ReturnToBase then element(gui, "ReturnBaseButton", "GuiButton") :: GuiButton? else nil
	local cooldownLabel: TextLabel? = nil
	local buttonText: string? = nil
	if returnButton then
		returnButton.Activated:Connect(onReturnBase)
		local found = Find.path(returnButton, COOLDOWN_LABEL)
		if found and found:IsA("TextLabel") then
			local label = found :: TextLabel
			label.Visible = false -- montré pendant la recharge
			cooldownLabel = label
		elseif returnButton:IsA("TextButton") then
			buttonText = (returnButton :: TextButton).Text
		else
			warnOnce(
				"cooldown",
				`[HUD] ReturnBaseButton n'est pas un TextButton et n'a pas d'enfant {COOLDOWN_LABEL} (TextLabel) : la recharge n'est pas affichée`
			)
		end
	end
	shownCountdown = nil
	shownCooldown = nil

	-- Chrono et jauge masqués jusqu'à la prochaine image (update les affiche s'il le faut).
	if heistTimer then
		heistTimer.Visible = false
	end
	if meter then
		meter.Visible = false
	end
	shownSeconds = nil
	chased = false

	hud = {
		gui = gui,
		stats = stats,
		written = {},
		heistTimer = heistTimer,
		guardMeter = meter,
		fill = fill,
		fillSize = if fill then fill.Size else UDim2.new(),
		nightCountdown = nightCountdown,
		returnButton = returnButton,
		cooldownLabel = cooldownLabel,
		buttonText = buttonText,
	}
	for _, stat in STATS do
		writeStat(stat)
	end
end

local function update()
	expireHolds()
	local api = chase
	setHeartbeat(api ~= nil and api.IsClose())
	local current = hud
	if current == nil or current.gui.Parent == nil then
		return
	end
	updateHeistTimer(current)
	updateGuardMeter(current)
	local now = Workspace:GetServerTimeNow()
	updateNightCountdown(current, now)
	updateReturnButton(current, now)
end

function HudController.Start()
	heist = sibling("HeistController")
	chase = sibling("ChaseController")
	-- Le bouton Retour base attend les remotes du serveur ; le reste du HUD, non.
	task.spawn(function()
		local ok, result = pcall(require, Shared:WaitForChild("Net"):WaitForChild("Net"))
		if ok then
			net = result
		else
			warnOnce("net", `[HUD] Net : require impossible ({result}) ; ReturnBaseButton ne fait rien`)
		end
	end)

	incomeSeen = localPlayer:GetAttribute(INCOME_ATTRIBUTE)
	incomeTracked = true
	for _, stat in STATS do
		localPlayer:GetAttributeChangedSignal(stat.Attribute):Connect(function()
			if stat == INCOME_STAT then
				incomeSeen = localPlayer:GetAttribute(INCOME_ATTRIBUTE)
			end
			writeStat(stat)
		end)
	end

	local heistApi = heist
	if heistApi then
		heistApi.OnTimer(onTimer)
		for storeId, endsAt in heistApi.GetTimers() do
			onTimer(storeId, endsAt)
		end
	end

	RunService.Heartbeat:Connect(update)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing)
	end
end

return HudController
