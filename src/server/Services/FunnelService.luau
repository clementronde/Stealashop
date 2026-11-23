--!strict
-- FunnelService (a414, vague GC7, 23/11 ; demande de Cantin : des entonnoirs « funnels » dans le jeu) : envoie à
-- AnalyticsService les étapes des entonnoirs de Config/Funnels. Le tutoriel garde l'entonnoir d'onboarding de Roblox
-- (TutorialService, inchangé).
-- Lus dans le Creator Hub : tableau de bord de l'expérience > Analytics > Funnels.
--
-- Interrupteurs : Features.Analytics et Config/Telemetry.Enabled ; l'un des deux à false = rien n'est branché.
--
-- Entonnoirs et origine de chaque étape :
--   FirstSteps (LogFunnelStepEvent, session fixe « FirstSteps », nouveaux profils seulement, marques dans le profil) :
--     Arrive     profil chargé (DataService.OnProfileLoaded)
--     Loaded     remote FunnelStep « Loaded » (FunnelController, écran UI_Loading fermé) ; valeur = secondes de
--                chargement, envoyée aussi en événement LoadingTime (TelemetryService, une fois par session)
--     Treadmill  relevé : attribut TrainingMachine = « Treadmill » (TrainingService)
--     Window     WindowService.OnBroken, vitrine de magasin PNJ (Kind NPC) cassée par lui
--     Steal      CarryService.OnCarryStarted, objet sorti d'un colis PNJ (NPCItem)
--     Display    relevé : un présentoir occupé (Display du profil)
--     CashOut    DisplayService.OnCashOut (plaque, encaissement automatique ou par l'API ; pas au départ ni hors ligne)
--     Upgrade    ShopService.OnPurchase, genre Upgrade
--   Progression (LogFunnelStepEvent, session fixe « Progression », une fois par profil, marques dans le profil) :
--     Zone1 à Zone6  relevé : ZonesReached du profil (posé par TelemetryService, mesure ZoneReached)
--     Rebirth1       relevé : Rebirths ≥ 1 (RebirthService)
--   RobuxShop, WeaponShop, AuraShop (une session GUID par ouverture, en mémoire) :
--     Open, View, Buy  remote FunnelStep (FunnelController) ; Open ouvre une nouvelle session, View et Buy ne
--                      comptent que dans une session ouverte
--     Bought           RobuxShop : MarketplaceService.PromptProductPurchaseFinished / PromptGamePassPurchaseFinished,
--                      achat fait ; WeaponShop : ShopService.OnPurchase genre Tool ; AuraShop : genre Aura ou Trail.
--                      Seulement dans une session ouverte (un achat lancé ailleurs n'entre pas dans l'entonnoir).
--   PlayerTheft (une session GUID par boutique visitée, en mémoire) :
--     Enter    relevé : intrus d'une boutique ouverte au vol (PvPService.GetIntruders) ; ouvre la session
--     Grab     PvPService.OnTheftStarted (ouvre la session si l'entrée n'a pas été vue)
--     Exit     relevé : le porteur de l'objet volé est hors du volume Bounds de la boutique volée
--     Deposit  PvPService.OnTheftEnded, résultat Stolen ; la session se ferme à toute fin de vol, ou quand l'intrus
--              repart sans rien avoir pris
--
-- Une étape n'est envoyée qu'une fois par session (et une fois par profil pour FirstSteps et Progression) : Roblox ne
-- compte que la 1re, mais chaque envoi compte dans sa limite (120 + 20 × joueurs requêtes par minute). Les étapes
-- demandées par le client sont bornées à Funnels.ClientStepsPerMinute par joueur. Aucune donnée personnelle : ni
-- nom, ni UserId dans les noms, sessions ou champs (sessions = GUID tirés ici ou nom de l'entonnoir).
--
-- Champ du profil : Funnels (facultatif, sans changement de version), [« New »] = true pour un profil nouveau
-- à son 1er passage ici, [« <entonnoir>/<n° d'étape> »] = true pour une étape de FirstSteps ou de Progression envoyée.
-- Créé au 1er chargement après la vague GC7 (un ancien profil n'a que ses étapes de Progression).
--
-- En Studio, Roblox n'envoie rien : chaque envoi écrit une ligne dans la sortie. Jamais d'erreur, rien n'attend.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net.Net)
local Find = require(Shared.Contract.Find)
local Features = require(Shared.Config.Features)
local FunnelConfig = require(Shared.Config.Funnels)
local Telemetry = require(Shared.Config.Telemetry)
local CarryTypes = require(Shared.Types.Carry)
local ProfileTypes = require(Shared.Types.Profile)

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local PlotService = require(script.Parent.PlotService)
local PvPService = require(script.Parent.PvPService)
local ShopService = require(script.Parent.ShopService)
local TelemetryService = require(script.Parent.TelemetryService)
local WindowService = require(script.Parent.WindowService)

type Data = ProfileTypes.Data
type Funnel = FunnelConfig.Funnel

type Session = {
	funnel: string,
	id: string,
	done: { [number]: boolean },
}

-- Visite d'une boutique de joueur (entonnoir PlayerTheft).
type Visit = {
	victim: Player,
	session: Session,
	grabbed: boolean,
	exited: boolean,
}

local IS_STUDIO = RunService:IsStudio()
local TREADMILL = "Treadmill"
local BOUNDS = "Bounds"
local MAX_ZONE = 6

local FunnelService = {}
-- Après TelemetryService (210), dont il appelle LogEvent, et après les services qu'il écoute.
FunnelService.Priority = 215

local enabled = false
local stepIndex: { [string]: { [string]: number } } = {} -- [entonnoir][clé d'étape] = numéro
local sessions: { [Player]: { [string]: Session } } = {} -- session ouverte de chaque entonnoir Session
local visits: { [Player]: Visit } = {} -- PlayerTheft, par voleur
local budgets: { [Player]: { start: number, count: number } } = {}
local pendingLoaded: { [Player]: boolean } = {} -- « Loaded » reçu avant le chargement du profil
local loadingSent: { [Player]: boolean } = {}
local warned: { [string]: boolean } = {}

------------------------------------------------------------------------------
-- Envoi
------------------------------------------------------------------------------

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[FunnelService] {message}`)
end

local function send(player: Player, funnelKey: string, sessionId: string, step: number): boolean
	local funnel: Funnel? = FunnelConfig.Funnels[funnelKey]
	if funnel == nil then
		return false
	end
	local spec = funnel.Steps[step]
	local name = if spec then spec.Name else tostring(step)
	local call = function()
		AnalyticsService:LogFunnelStepEvent(player, funnel.Name, sessionId, step, name)
	end
	local ok, err = pcall(call :: any) -- :: any : voir pollTheft
	if IS_STUDIO then
		local refused = if ok then "" else ` (refusé par Roblox en Studio : {err})`
		print(`[FunnelService] {player.Name} : {funnel.Name} étape {step} « {name} »{refused}`)
	elseif not ok then
		warnOnce(`refused:{funnelKey}`, `{funnel.Name} refusé par AnalyticsService : {err}`)
	end
	return ok
end

local function indexOf(funnelKey: string, stepKey: string): number?
	local steps = stepIndex[funnelKey]
	return if steps then steps[stepKey] else nil
end

------------------------------------------------------------------------------
-- Entonnoirs une fois par profil (FirstSteps, Progression)
------------------------------------------------------------------------------

local function marksOf(player: Player): { [string]: boolean }?
	local data = DataService.Get(player)
	return if data then data.Funnels else nil
end

-- Étape d'un entonnoir une fois par profil ; true si elle part maintenant.
local function stepOnce(player: Player, funnelKey: string, stepKey: string): boolean
	if not enabled then
		return false
	end
	local marks = marksOf(player)
	local funnel: Funnel? = FunnelConfig.Funnels[funnelKey]
	local step = indexOf(funnelKey, stepKey)
	if marks == nil or funnel == nil or step == nil then
		return false
	end
	if funnel.Mode ~= "Once" or (funnel.NewOnly and marks.New ~= true) then
		return false -- NewOnly : un ancien profil n'y entre jamais
	end
	local key = `{funnelKey}/{step}`
	if marks[key] then
		return false
	end
	marks[key] = true
	send(player, funnelKey, funnel.Name, step)
	return true
end

-- Profil nouveau à son 1er passage ici (voir l'en-tête de Config/Funnels).
local function isNewProfile(data: Data): boolean
	local played = data.Lifetime.PlaySeconds
	return (type(played) ~= "number" or played <= 0)
		and data.Lifetime.Heists == 0
		and data.Lifetime.Steals == 0
		and next(data.Items) == nil
end

------------------------------------------------------------------------------
-- Entonnoirs par session (boutiques, vol chez un joueur)
------------------------------------------------------------------------------

local function newSession(funnelKey: string): Session
	return { funnel = funnelKey, id = HttpService:GenerateGUID(false), done = {} }
end

-- Étape d'une session ; une seule fois par session.
local function stepSession(player: Player, session: Session, stepKey: string): boolean
	local step = indexOf(session.funnel, stepKey)
	if step == nil or session.done[step] then
		return false
	end
	session.done[step] = true
	send(player, session.funnel, session.id, step)
	return true
end

-- Session ouverte du joueur pour une boutique (nil : pas ouverte depuis son arrivée).
local function openSessionOf(player: Player, funnelKey: string): Session?
	local list = sessions[player]
	return if list then list[funnelKey] else nil
end

-- 1re étape (Open) : nouvelle session ; les autres : dans la session ouverte seulement.
local function shopStep(player: Player, funnelKey: string, stepKey: string)
	if not enabled then
		return
	end
	local funnel: Funnel? = FunnelConfig.Funnels[funnelKey]
	if funnel == nil or funnel.Mode ~= "Session" then
		return
	end
	if indexOf(funnelKey, stepKey) == 1 then
		local list = sessions[player] or {}
		sessions[player] = list
		local session = newSession(funnelKey)
		list[funnelKey] = session
		stepSession(player, session, stepKey)
		return
	end
	local session = openSessionOf(player, funnelKey)
	if session then
		stepSession(player, session, stepKey)
	end
end

------------------------------------------------------------------------------
-- Étapes demandées par le client (remote FunnelStep)
------------------------------------------------------------------------------

local function withinBudget(player: Player): boolean
	local now = os.clock()
	local budget = budgets[player]
	if budget == nil or now - budget.start >= 60 then
		budgets[player] = { start = now, count = 1 }
		return true
	end
	if budget.count >= FunnelConfig.ClientStepsPerMinute then
		return false
	end
	budget.count += 1
	return true
end

local function onLoaded(player: Player, seconds: number?)
	if not loadingSent[player] and type(seconds) == "number" then
		loadingSent[player] = true
		local value = math.clamp(math.floor(seconds * 10 + 0.5) / 10, 0, FunnelConfig.MaxLoadingSeconds)
		pcall(TelemetryService.LogEvent, player, "LoadingTime", nil, value)
	end
	if DataService.Get(player) == nil then
		pendingLoaded[player] = true -- envoyé au chargement du profil
		return
	end
	stepOnce(player, "FirstSteps", "Loaded")
end

local function onClientStep(player: Player, key: string, value: number?)
	if not enabled then
		return
	end
	local entry = FunnelConfig.ClientSteps[key]
	if entry == nil then
		warnOnce(`client:{key}`, `étape « {key} » inconnue, ignorée`)
		return
	end
	if not withinBudget(player) then
		return
	end
	if entry.Funnel == "FirstSteps" then
		onLoaded(player, value)
	else
		shopStep(player, entry.Funnel, entry.Step)
	end
end

------------------------------------------------------------------------------
-- Signaux des services
------------------------------------------------------------------------------

local function onProfileLoaded(player: Player)
	local data = DataService.Get(player)
	if data == nil or not enabled then
		return
	end
	if data.Funnels == nil then
		local marks: { [string]: boolean } = {}
		if isNewProfile(data) then
			marks.New = true
		end
		data.Funnels = marks
	end
	stepOnce(player, "FirstSteps", "Arrive")
	if pendingLoaded[player] then
		pendingLoaded[player] = nil
		stepOnce(player, "FirstSteps", "Loaded")
	end
end

local function onWindowBroken(info: WindowService.BreakInfo)
	if info.Kind == "NPC" and info.Breaker then
		stepOnce(info.Breaker, "FirstSteps", "Window")
	end
end

local function onCarryStarted(player: Player, payload: CarryTypes.Payload)
	if payload.Kind == "NPCItem" then
		stepOnce(player, "FirstSteps", "Steal")
	end
end

local function onCashOut(player: Player, amount: number, source: DisplayService.CashOutSource)
	if amount > 0 and source ~= "Leave" and source ~= "Offline" then
		stepOnce(player, "FirstSteps", "CashOut")
	end
end

local function onPurchase(player: Player, kind: string, _id: string, _price: number, _level: number?)
	if kind == "Upgrade" then
		stepOnce(player, "FirstSteps", "Upgrade")
	elseif kind == "Tool" then
		shopStep(player, "WeaponShop", "Bought")
	elseif kind == "Aura" or kind == "Trail" then
		shopStep(player, "AuraShop", "Bought")
	end
end

local function onRobuxBought(player: Player?, purchased: boolean)
	if player and purchased then
		shopStep(player, "RobuxShop", "Bought")
	end
end

-- Vol chez un joueur ---------------------------------------------------------

local function newVisit(thief: Player, victim: Player): Visit
	local visit: Visit = { victim = victim, session = newSession("PlayerTheft"), grabbed = false, exited = false }
	visits[thief] = visit
	return visit
end

local function onTheftStarted(thief: Player, victim: Player, _itemId: string)
	if not enabled then
		return
	end
	local visit = visits[thief]
	if visit == nil or visit.victim ~= victim then
		visit = newVisit(thief, victim)
	end
	local current = visit :: Visit
	current.grabbed = true
	stepSession(thief, current.session, "Grab")
end

local function onTheftEnded(thief: Player, victim: Player, _itemId: string, result: PvPService.TheftResult, _reason: string)
	local visit = visits[thief]
	if visit == nil or visit.victim ~= victim then
		return
	end
	visits[thief] = nil
	if enabled and result == "Stolen" then
		stepSession(thief, visit.session, "Deposit")
	end
end

-- Le voleur est hors du volume Bounds de la boutique de la victime (pas de boutique ou pas de perso : non).
local function isOutside(thief: Player, victim: Player): boolean
	local plot = PlotService.GetPlot(victim)
	local bounds = if plot then Find.path(plot, BOUNDS) else nil
	local character = thief.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if bounds == nil or not bounds:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		return false
	end
	local p = bounds.CFrame:PointToObjectSpace(root.Position)
	local h = bounds.Size / 2
	return math.abs(p.X) > h.X or math.abs(p.Y) > h.Y or math.abs(p.Z) > h.Z
end

local function pollTheft()
	local present: { [Player]: Player } = {} -- intrus → victime, à ce relevé
	for _, victim in Players:GetPlayers() do
		local ok, list = pcall(PvPService.GetIntruders :: any, victim) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if ok and type(list) == "table" then
			for _, thief in list :: { Player } do
				present[thief] = victim
				local visit = visits[thief]
				if visit == nil or visit.victim ~= victim then
					stepSession(thief, newVisit(thief, victim).session, "Enter")
				end
			end
		end
	end
	for thief, visit in visits do
		if visit.grabbed then
			if not visit.exited then
				local ok, theft = pcall(PvPService.GetTheft :: any, thief)
				if ok and theft and (theft :: PvPService.TheftInfo).Victim == visit.victim and isOutside(thief, visit.victim) then
					visit.exited = true
					stepSession(thief, visit.session, "Exit")
				end
			end
		elseif present[thief] ~= visit.victim then
			visits[thief] = nil -- reparti sans rien prendre : la prochaine entrée est une nouvelle session
		end
	end
end

-- Relevés sans signal --------------------------------------------------------

local function pollPlayer(player: Player)
	local data = DataService.Get(player)
	local marks = if data then data.Funnels else nil
	if data == nil or marks == nil then
		return
	end
	if marks.New then
		if player:GetAttribute("TrainingMachine") == TREADMILL then
			stepOnce(player, "FirstSteps", "Treadmill")
		end
		if next(data.Display) ~= nil then
			stepOnce(player, "FirstSteps", "Display")
		end
	end
	local reached = data.ZonesReached
	if reached then
		for zone = 1, MAX_ZONE do
			if reached[tostring(zone)] ~= nil then
				stepOnce(player, "Progression", `Zone{zone}`)
			end
		end
	end
	local rebirths = data.Rebirths
	if type(rebirths) == "number" and rebirths >= 1 then
		stepOnce(player, "Progression", "Rebirth1")
	end
end

local function pollLoop()
	while true do
		task.wait(FunnelConfig.PollInterval)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(pollPlayer :: any, player)
			if not ok then
				warnOnce("poll", `relevé des étapes : {err}`)
			end
		end
		local ok, err = pcall(pollTheft :: any)
		if not ok then
			warnOnce("theft", `relevé des vols : {err}`)
		end
	end
end

------------------------------------------------------------------------------
-- API et démarrage
------------------------------------------------------------------------------

-- Étape d'un entonnoir FirstSteps ou Progression (une fois par profil), pour un service qui en ajoute une.
function FunnelService.StepOnce(player: Player, funnelKey: string, stepKey: string): boolean
	return stepOnce(player, funnelKey, stepKey)
end

-- Vrai quand les entonnoirs partent (Features.Analytics et Telemetry.Enabled).
function FunnelService.IsEnabled(): boolean
	return enabled
end

function FunnelService.Init()
	enabled = Features.Analytics == true and Telemetry.Enabled == true
	if not enabled then
		print("[FunnelService] Features.Analytics ou Config.Telemetry.Enabled à false : aucun entonnoir envoyé")
		return
	end
	local count = 0
	for funnelKey, funnel in FunnelConfig.Funnels do
		count += 1
		local steps: { [string]: number } = {}
		for index, step in funnel.Steps do
			steps[step.Key] = index
		end
		stepIndex[funnelKey] = steps
	end

	DataService.OnProfileLoaded(onProfileLoaded)
	Net.Server.FunnelStep:Connect(onClientStep)
	WindowService.OnBroken(onWindowBroken)
	CarryService.OnCarryStarted(onCarryStarted)
	DisplayService.OnCashOut(onCashOut)
	ShopService.OnPurchase(onPurchase)
	PvPService.OnTheftStarted(onTheftStarted)
	PvPService.OnTheftEnded(onTheftEnded)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, purchased: boolean)
		onRobuxBought(Players:GetPlayerByUserId(userId), purchased)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, _passId: number, purchased: boolean)
		onRobuxBought(player, purchased)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
		visits[player] = nil
		budgets[player] = nil
		pendingLoaded[player] = nil
		loadingSent[player] = nil
	end)
	task.spawn(pollLoop)
	if IS_STUDIO then
		print(`[FunnelService] {count} entonnoirs branchés (+ onboarding du tutoriel par TutorialService) ; rien n'est envoyé depuis Studio`)
	end
end

return FunnelService
