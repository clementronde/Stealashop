--!strict
-- OfflineService (DEV-102) : gains hors ligne (Partie 2, section 3 ; liaison L-084, point 1 ; réglages
-- dans Config/Offline).
--
-- Rôle : au retour d'un joueur, sa boutique a gagné pendant son absence
--   gain = absence × revenu par seconde au départ × Offline.Rate
-- absence = maintenant − Offline.LastSeenAt du profil, au plus Offline.MaxHours h ; revenu au départ =
-- Offline.Income du profil : les objets exposés (DisplayService.GetIncome) × le M global
-- (DisplayService.GetGlobalMultiplier : Premium, ×2 Argent, index…), sans les boosts temporaires (boost
-- ×2 argent, compté seulement en jeu : Partie 2, section 4 ; MonetizationService.GetTemporaryIncomeMultiplier).
-- Le gain va dans la caisse de sa boutique (DisplayService.AddOfflineEarnings, attribut CashRegister),
-- pas dans son argent : il l'encaisse sur son CashPad comme le reste (« il le trouve dans sa base »).
-- S'il part sans l'encaisser, la caisse passe dans son argent au départ, comme toujours (DisplayService).
-- Message au retour (Notify « Info », en anglais, L-036) : « Your shop earned $1.2M while you were
-- away! » (Config/Offline.Message, Format.money), seulement si le gain atteint 1 $.
--
-- Profil (v6, Types/Profile.Offline), écrit par ce service seulement, sur le serveur :
--   - LastSeenAt = os.time() et Income = revenu ci-dessus, toutes les Offline.SnapshotInterval s de jeu
--     (un serveur qui plante ne fait perdre que les dernières secondes : la sauvegarde automatique de
--     ProfileStore emporte une heure récente), puis LastSeenAt seul au départ (DataService.OnProfileReleasing) ;
--   - Income n'est relevé qu'en jeu, tant que le joueur a une boutique (PlotService.GetPlot) : au départ,
--     la boutique peut être libérée et le compte de DisplayService oublié juste avant la sauvegarde, et le
--     revenu tomberait à 0. Le dernier relevé (au plus SnapshotInterval s plus tôt) est celui du départ.
--
-- Sécurité : rien ne vient du client (aucun remote). Ne donnent rien :
--   - un profil sans heure (LastSeenAt = 0 : profil d'avant la v6, profil neuf) ;
--   - une heure de départ dans le futur, ou une horloge qui recule (maintenant ≤ LastSeenAt) : l'heure
--     repart de maintenant, sans gain ;
--   - un revenu ou une heure illisible (pas un nombre fini ≥ 0 ; la migration v6 les remet déjà à 0) ;
--   - un profil ouvert sur deux serveurs : ProfileStore n'en laisse qu'une session active. Le serveur
--     qui perd la session n'écrit plus rien (DataService.Get = nil) ; celui qui la reprend lit l'heure
--     écrite par l'autre à sa dernière sauvegarde : l'absence est le vrai temps sans jeu, jamais compté
--     deux fois. Chaque retour remet LastSeenAt à maintenant tout de suite : un 2e chargement ne redonne
--     rien.
-- Avec Rate = 1, revenir souvent ne rapporte pas plus que rester (le gain est ce que la boutique aurait
-- encaissé en jeu, boost en moins).
--
-- Télémétrie : la part d'un encaissement qui vient des gains hors ligne part en économie « Offline »,
-- le reste en « Income » (accroche TelemetryService.ClaimOfflineShare, posée ici). Les gains hors ligne
-- sont comptés en premier dans chaque encaissement qui suit le retour.
--
-- API (côté serveur) :
--   OfflineService.ComputeEarnings(lastSeenAt, now, income) -> (gain, seconds)
--       Le calcul seul, sans rien toucher : seconds = absence comptée (0 à MaxHours × 3600), gain =
--       seconds × income × Rate ; (0, 0) pour une heure inconnue, dans le futur ou illisible. À garder
--       séparé : quand la caisse unique deviendra des cases par présentoir (L-082, point 4), on
--       l'appellera par présentoir, avec le revenu de chacun.
--   OfflineService.GetIncome(player) -> number
--       Revenu compté hors ligne en ce moment ($/s) : exposé × M global ÷ boosts temporaires.
--
-- Choix V0 (Config/Offline) : Rate = 1 et MaxHours = 4, à valider avec Clément (le doc dit 10 % pendant
-- 4 h, Clément « tout l'argent » ; plafond repris du doc). SnapshotInterval = 5 s, NotifyDelay = 3 s.
--
-- Tester dans Studio : workspace:SetAttribute("OfflineTest", "<joueur> <secondes>") (barre de commande
-- serveur ; joueur = nom ou UserId) simule une absence de ce nombre de secondes, avec le revenu actuel :
-- même calcul, même plafond, même caisse, même message et même télémétrie qu'un vrai retour. Hors de
-- Studio, l'attribut n'est pas écouté. Un vrai retour : jouer avec des objets exposés, quitter (profil
-- sauvegardé : « Accès Studio aux services d'API »), attendre, relancer Play.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Offline = require(ReplicatedStorage.Shared.Config.Offline)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)

type Data = ProfileTypes.Data
type OfflineData = ProfileTypes.Offline

-- Ce que ce service garde d'un joueur présent.
type State = {
	pending: number, -- gains hors ligne versés dans la caisse et pas encore encaissés (télémétrie)
}

local IS_STUDIO = RunService:IsStudio()
local NOTIFY_KIND = "Info"

local OfflineService = {}

local states: { [Player]: State } = {}
local reported: { [string]: boolean } = {}
local snapshotClock = 0

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function warnOnce(key: string, message: string)
	if not reported[key] then
		reported[key] = true
		warn(`[OfflineService] {message}`)
	end
end

local function notify(player: Player, message: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, NOTIFY_KIND)
	end)
	if not ok then
		warn(`[OfflineService] Notify vers {player.Name} : {err}`)
	end
end

-- « 2 h 05 min », « 12 min 30 s », « 40 s ».
local function duration(seconds: number): string
	local total = math.floor(seconds)
	local hours, minutes, rest = total // 3600, (total % 3600) // 60, total % 60
	if hours > 0 then
		return string.format("%d h %02d min", hours, minutes)
	elseif minutes > 0 then
		return string.format("%d min %02d s", minutes, rest)
	end
	return `{rest} s`
end

-- Offline du profil (v6). Illisible (profil abîmé après la migration) : remis à zéro, sans gain.
local function offlineOf(data: Data): OfflineData
	local offline = (data :: any).Offline
	if type(offline) ~= "table" then
		offline = { LastSeenAt = 0, Income = 0 }
		data.Offline = offline
	end
	return offline :: OfflineData
end

------------------------------------------------------------------------------
-- Calcul
------------------------------------------------------------------------------

function OfflineService.ComputeEarnings(lastSeenAt: number, now: number, income: number): (number, number)
	if not (isFinite(lastSeenAt) and isFinite(now) and isFinite(income)) then
		return 0, 0
	end
	if lastSeenAt <= 0 or now <= lastSeenAt or income <= 0 then
		return 0, 0
	end
	local cap = math.max(0, Offline.MaxHours) * 3600
	local seconds = math.min(now - lastSeenAt, cap)
	local gain = seconds * income * math.max(0, Offline.Rate)
	if not isFinite(gain) or gain <= 0 then
		return 0, 0
	end
	return gain, seconds
end

-- Boosts temporaires du M global (exclus des gains hors ligne). Seul le boost ×2 argent existe ; une
-- potion Money ×2 (L-085) devra s'ajouter ici. Erreur ou valeur invalide : 1.
local function temporaryMultiplier(player: Player): number
	local ok, value = pcall(MonetizationService.GetTemporaryIncomeMultiplier, player)
	if ok and isFinite(value) and value > 0 then
		return value
	end
	warnOnce("temporary", `GetTemporaryIncomeMultiplier : erreur ou valeur invalide ({tostring(value)}), aucun boost retiré`)
	return 1
end

function OfflineService.GetIncome(player: Player): number
	local income = DisplayService.GetIncome(player) * DisplayService.GetGlobalMultiplier(player) / temporaryMultiplier(player)
	if isFinite(income) and income > 0 then
		return income
	end
	return 0
end

------------------------------------------------------------------------------
-- Profil : relevés et retour
------------------------------------------------------------------------------

-- Heure de présence et, avec une boutique, revenu du moment (voir l'en-tête). `withIncome` = false au
-- départ : DisplayService a pu oublier le compte du joueur juste avant (revenu 0). Sans yield.
local function snapshot(player: Player, data: Data, withIncome: boolean)
	local offline = offlineOf(data)
	offline.LastSeenAt = os.time()
	if withIncome and PlotService.GetPlot(player) ~= nil then
		offline.Income = OfflineService.GetIncome(player)
	end
end

-- Verse `gain` dans la caisse, prévient le joueur. `test` : crochet de Studio.
local function credit(player: Player, gain: number, seconds: number, absence: number, income: number, test: boolean)
	local state = states[player]
	if state == nil or not DisplayService.AddOfflineEarnings(player, gain) then
		warn(`[OfflineService] {player.Name} : {Format.money(gain)} de gains hors ligne pas versés (profil ou caisse absents)`)
		return
	end
	state.pending += gain
	local capped = if seconds < absence then `, comptées {duration(seconds)} (plafond {Offline.MaxHours} h)` else ""
	local label = if test then "test : absence simulée" else "absent"
	print(
		`[OfflineService] {player.Name} {label} {duration(absence)}{capped}, revenu {Format.money(income)}/s × {string.format("%g", Offline.Rate)} : {Format.money(gain)} dans la caisse`
	)
	if gain >= 1 then
		local message = string.format(Offline.Message, Format.money(gain))
		task.delay(math.max(0, Offline.NotifyDelay), function()
			if player.Parent == Players and states[player] == state then
				notify(player, message)
			end
		end)
	end
end

local function onProfileLoaded(player: Player)
	local data = DataService.Get(player)
	if data == nil or states[player] ~= nil then
		return
	end
	local state: State = { pending = 0 }
	states[player] = state
	local offline = offlineOf(data)
	local lastSeenAt, income = offline.LastSeenAt, offline.Income
	local now = os.time()
	-- Tout de suite : un 2e chargement (ou un plantage juste après) ne redonne rien.
	offline.LastSeenAt = now
	if isFinite(lastSeenAt) and lastSeenAt > now then
		warn(`[OfflineService] {player.Name} : heure de départ dans le futur ({lastSeenAt - now} s d'avance) : aucun gain hors ligne`)
		return
	end
	local gain, seconds = OfflineService.ComputeEarnings(lastSeenAt, now, income)
	if gain > 0 then
		credit(player, gain, seconds, now - lastSeenAt, income, false)
	end
end

local function onProfileReleasing(player: Player)
	local data = DataService.Get(player)
	if data and states[player] then
		snapshot(player, data, false)
	end
end

local function onHeartbeat(dt: number)
	snapshotClock += dt
	if snapshotClock < Offline.SnapshotInterval then
		return
	end
	snapshotClock = 0
	for player in states do
		local data = DataService.Get(player)
		if data then
			local ok, err = pcall(snapshot :: any, player, data, true) --:: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
			if not ok then
				warnOnce(`snapshot:{player.UserId}`, `relevé de {player.Name} impossible : {err}`)
			end
		end
	end
end

-- Part hors ligne d'un encaissement de `amount` $ (télémétrie), comptée en premier.
local function claim(player: Player, amount: number): number
	local state = states[player]
	if state == nil or not isFinite(amount) or amount <= 0 then
		return 0
	end
	local share = math.min(amount, math.floor(state.pending))
	if share <= 0 then
		return 0
	end
	state.pending -= share
	return share
end

------------------------------------------------------------------------------
-- Crochet de test (Studio seulement)
------------------------------------------------------------------------------

local function findPlayer(who: string): Player?
	local userId = tonumber(who)
	for _, player in Players:GetPlayers() do
		if player.Name == who or (userId ~= nil and player.UserId == userId) then
			return player
		end
	end
	return nil
end

local function onTestAttribute()
	local value = Workspace:GetAttribute(Offline.TestAttribute)
	if value == nil then
		return
	end
	Workspace:SetAttribute(Offline.TestAttribute, nil)
	local who, secondsText = string.match(tostring(value), "^%s*(%S+)%s+(%S+)%s*$")
	local player = if who then findPlayer(who) else nil
	local absence = if secondsText then tonumber(secondsText) else nil
	if player == nil or absence == nil or not isFinite(absence) or absence <= 0 then
		warn(`[OfflineService] test : « {tostring(value)} » : attendu « <joueur> <secondes> » avec un joueur présent et des secondes > 0`)
		return
	end
	if DataService.Get(player) == nil or states[player] == nil then
		warn(`[OfflineService] test : profil de {player.Name} pas chargé`)
		return
	end
	local now = os.time()
	local income = OfflineService.GetIncome(player)
	local gain, seconds = OfflineService.ComputeEarnings(now - absence, now, income)
	if gain <= 0 then
		print(`[OfflineService] test : {player.Name}, revenu {Format.money(income)}/s : aucun gain hors ligne`)
		return
	end
	credit(player, gain, seconds, absence, income, true)
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function OfflineService.Init()
	-- Accroche de la télémétrie : la part hors ligne d'un encaissement, celle d'avant gardée.
	local baseShare = TelemetryService.ClaimOfflineShare
	TelemetryService.ClaimOfflineShare = function(player: Player, amount: number): number
		local base = baseShare(player, amount)
		return base + claim(player, amount - base)
	end

	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- Après DataService (relevé du départ) et l'encaissement du départ (télémétrie) : au tour suivant.
		task.defer(function()
			states[player] = nil
		end)
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(Offline.TestAttribute):Connect(onTestAttribute)
	end
	print(`[OfflineService] gains hors ligne : {string.format("%g", Offline.Rate * 100)} % des revenus, {Offline.MaxHours} h au plus, versés dans la caisse au retour`)
end

return OfflineService
