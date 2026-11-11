--!strict
-- OfflineService (DEV-102) : gains hors ligne (Partie 2, section 3 ; liaison L-084, point 1 ; écran Claim
-- UI_Offline de Clément, L-092 3f ; réglages dans Config/Offline).
--
-- Rôle : au retour d'un joueur, sa boutique a gagné pendant son absence
--   gain = absence × revenu par seconde au départ × Offline.Rate
-- absence = maintenant − Offline.LastSeenAt du profil, au plus Offline.MaxHours h ; revenu au départ =
-- Offline.Income du profil : les objets exposés (DisplayService.GetIncome) × le M global
-- (DisplayService.GetGlobalMultiplier : Premium, ×2 Argent, index…), sans les boosts temporaires (boost
-- ×2 argent, compté seulement en jeu : Partie 2, section 4 ; MonetizationService.GetTemporaryIncomeMultiplier).
-- Depuis la vague 22 (L-092 3f), le gain n'est plus versé tout de suite : ses dollars entiers s'ajoutent à
-- Offline.Pending du profil (les centimes sont perdus, comme avant), montrés au client par l'attribut
-- Offline.PendingAttribute (« OfflinePending ») du Player ; OfflineController ouvre alors l'écran UI_Offline,
-- dont le bouton Claim envoie le remote ClaimOffline (sans argument). Au Claim, tout Offline.Pending est versé
-- dans l'argent (DisplayService.AddOfflineEarnings, source « Offline » des encaissements, comme avant),
-- puis remis à 0, dans la même exécution, sans yield.
--
-- Jamais perdu, jamais payé deux fois : le montant en attente vit dans le profil, sauvegardé avec lui.
--   - pas réclamé (joueur parti, écran fermé par un autre écran du groupe Menu, serveur qui plante après une
--     sauvegarde) : il reste dans Offline.Pending ; l'écran se rouvre (OfflineController) et, au retour
--     suivant, le nouveau gain s'y ajoute : tout est montré et réclamé en une fois ;
--   - réclamé : versé et remis à 0 ensemble, dans le même profil, sauvegardés ensemble ; un 2e Claim (double
--     clic, remote rejoué) trouve 0 et ne verse rien. ProfileStore n'ouvre un profil que sur un serveur à la
--     fois (verrou de session) : un autre serveur ne lit Pending qu'après la fin de session de celui-ci ;
--   - versement refusé (profil absent) : Pending n'est pas touché.
-- Aucun message au retour (l'écran le remplace). Le bouton DoubleButton (×2 contre des Robux) ne passe pas
-- par le serveur tant que la boutique Robux est coupée (OfflineController : « Soon »).
--
-- Profil (v6, Types/Profile.Offline), écrit par ce service seulement, sur le serveur :
--   - LastSeenAt = os.time() et Income = revenu ci-dessus, toutes les Offline.SnapshotInterval s de jeu
--     (un serveur qui plante ne fait perdre que les dernières secondes : la sauvegarde automatique de
--     ProfileStore emporte une heure récente), puis LastSeenAt seul au départ (DataService.OnProfileReleasing) ;
--   - Income n'est relevé qu'en jeu, tant que le joueur a une boutique (PlotService.GetPlot) : au départ,
--     la boutique peut être libérée et le compte de DisplayService oublié juste avant la sauvegarde, et le
--     revenu tomberait à 0. Le dernier relevé (au plus SnapshotInterval s plus tôt) est celui du départ ;
--   - Pending (vague 22) : dollars entiers en attente du Claim. Champ facultatif, sans changement de version
--     (comme IndexRewards) : absent = 0. Une valeur illisible (pas un nombre fini ≥ 0) repart à 0, avec un
--     avertissement.
--
-- Sécurité : le seul remote, ClaimOffline, n'a aucun argument (forme et débit contrôlés par Net) : le
-- montant est celui du profil. Ne donnent rien :
--   - un profil sans heure (LastSeenAt = 0 : profil d'avant la v6, profil neuf) ;
--   - une heure de départ dans le futur, ou une horloge qui recule (maintenant ≤ LastSeenAt) : l'heure
--     repart de maintenant, sans gain ;
--   - un revenu ou une heure illisible (pas un nombre fini ≥ 0 ; la migration v6 les remet déjà à 0) ;
--   - un profil ouvert sur deux serveurs : ProfileStore n'en laisse qu'une session active. Le serveur
--     qui perd la session n'écrit plus rien (DataService.Get = nil) ; celui qui la reprend lit l'heure
--     écrite par l'autre à sa dernière sauvegarde : l'absence est le vrai temps sans jeu, jamais compté
--     deux fois. Chaque retour remet LastSeenAt à maintenant et ajoute le gain à Pending tout de suite,
--     ensemble : un 2e chargement ne redonne rien ;
--   - un Claim sans rien en attente (moins de 1 $).
-- Avec Rate = 1, revenir souvent ne rapporte pas plus que rester (le gain est ce que la boutique aurait
-- encaissé en jeu, boost en moins).
--
-- Télémétrie : la part d'un encaissement qui vient des gains hors ligne part en économie « Offline »,
-- le reste en « Income » (accroche TelemetryService.ClaimOfflineShare, posée ici). Les gains hors ligne
-- sont comptés en premier dans l'encaissement qui suit le Claim (le versement du Claim lui-même).
--
-- API (côté serveur) :
--   OfflineService.ComputeEarnings(lastSeenAt, now, income) -> (gain, seconds)
--       Le calcul seul, sans rien toucher : seconds = absence comptée (0 à MaxHours × 3600), gain =
--       seconds × income × Rate ; (0, 0) pour une heure inconnue, dans le futur ou illisible. À garder
--       séparé : si un jour les gains hors ligne vont sur les plaques de chaque présentoir, on
--       l'appellera par présentoir, avec le revenu de chacun.
--   OfflineService.GetIncome(player) -> number
--       Revenu compté hors ligne en ce moment ($/s) : exposé × M global ÷ boosts temporaires.
--   OfflineService.GetPending(player) -> number
--       Dollars entiers en attente du Claim (0 sans profil). Pour les bancs et la barre de commande.
--   OfflineService.Claim(player) -> number
--       Ce que fait le remote ClaimOffline : verse tout Offline.Pending dans l'argent et le remet à 0 ;
--       renvoie le montant versé (0 : rien en attente, ou profil absent). Sans yield.
--
-- Choix V0 (Config/Offline) : Rate = 1 et MaxHours = 4, à valider avec Clément (le doc dit 10 % pendant
-- 4 h, Clément « tout l'argent » ; plafond repris du doc). SnapshotInterval = 5 s, OpenDelay = 3 s.
--
-- Tester dans Studio : workspace:SetAttribute("OfflineTest", "<joueur> <secondes>") (barre de commande
-- serveur ; joueur = nom ou UserId) simule une absence de ce nombre de secondes, avec le revenu actuel :
-- même calcul, même plafond, même attente du Claim (l'écran s'ouvre), même télémétrie qu'un vrai retour.
-- Hors de Studio, l'attribut n'est pas écouté. Un vrai retour : jouer avec des objets exposés, quitter
-- (profil sauvegardé : « Accès Studio aux services d'API »), attendre, relancer Play.

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
	pending: number, -- gains hors ligne versés mais pas encore comptés par la télémétrie (part « Offline »)
}

local IS_STUDIO = RunService:IsStudio()

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
		local fresh: OfflineData = { LastSeenAt = 0, Income = 0 }
		data.Offline = fresh
		return fresh
	end
	return offline :: OfflineData
end

-- Dollars entiers en attente du Claim (Offline.Pending, facultatif : absent = 0). Illisible : remis à 0,
-- avec un avertissement (on ne peut pas savoir ce qu'il valait).
local function pendingOf(player: Player, offline: OfflineData): number
	local value = (offline :: any).Pending
	if value == nil then
		return 0
	end
	if not isFinite(value) or value < 0 then
		warn(`[OfflineService] {player.Name} : Offline.Pending illisible ({tostring(value)}) : remis à 0`)
		offline.Pending = 0
		return 0
	end
	return math.floor(value)
end

-- Attribut lu par OfflineController : le montant en attente (0 : rien, l'écran reste fermé).
local function publish(player: Player, amount: number)
	if player.Parent == Players and player:GetAttribute(Offline.PendingAttribute) ~= amount then
		player:SetAttribute(Offline.PendingAttribute, amount)
	end
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

-- Boosts temporaires du M global (exclus des gains hors ligne) : le boost ×2 argent, et la potion Money
-- (PotionService enveloppe GetTemporaryIncomeMultiplier, vague 28). Erreur ou valeur invalide : 1.
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

function OfflineService.GetPending(player: Player): number
	local data = DataService.Get(player)
	if data == nil then
		return 0
	end
	return pendingOf(player, offlineOf(data))
end

------------------------------------------------------------------------------
-- Profil : relevés, retour et Claim
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

-- Ajoute les dollars entiers de `gain` à Offline.Pending (en attente du Claim). `test` : crochet de Studio.
-- Sans yield.
local function stash(player: Player, data: Data, gain: number, seconds: number, absence: number, income: number, test: boolean)
	local offline = offlineOf(data)
	local whole = math.floor(gain)
	local total = pendingOf(player, offline) + math.max(0, whole)
	if whole >= 1 then
		offline.Pending = total
	end
	publish(player, total)
	local capped = if seconds < absence then `, comptées {duration(seconds)} (plafond {Offline.MaxHours} h)` else ""
	local label = if test then "test : absence simulée" else "absent"
	print(
		`[OfflineService] {player.Name} {label} {duration(absence)}{capped}, revenu {Format.money(income)}/s × {string.format("%g", Offline.Rate)} : {Format.money(gain)}, {Format.money(total)} en attente du Claim`
	)
end

function OfflineService.Claim(player: Player): number
	local data = DataService.Get(player)
	local state = states[player]
	if data == nil or state == nil then
		return 0
	end
	local offline = offlineOf(data)
	local amount = pendingOf(player, offline)
	if amount < 1 then
		publish(player, 0) -- double clic, remote rejoué : déjà versé
		return 0
	end
	-- Avant le versement : la télémétrie (OnCashOut, dans le même appel) y prend la part hors ligne.
	state.pending += amount
	if not DisplayService.AddOfflineEarnings(player, amount) then
		state.pending -= amount
		warn(`[OfflineService] {player.Name} : Claim de {Format.money(amount)} pas versé (profil absent), gardé en attente`)
		return 0
	end
	-- Versé : remis à 0 dans la même exécution (AddOfflineEarnings ne yield pas).
	offline.Pending = 0
	publish(player, 0)
	print(`[OfflineService] {player.Name} réclame ses gains hors ligne : {Format.money(amount)} versés dans son argent`)
	return amount
end

local function onClaimOffline(player: Player)
	OfflineService.Claim(player)
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
		publish(player, pendingOf(player, offline))
		return
	end
	local gain, seconds = OfflineService.ComputeEarnings(lastSeenAt, now, income)
	if gain > 0 then
		stash(player, data, gain, seconds, now - lastSeenAt, income, false)
	else
		-- Montant d'une session d'avant, pas réclamé : montré de nouveau.
		publish(player, pendingOf(player, offline))
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
local function claimShare(player: Player, amount: number): number
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
	local data = DataService.Get(player)
	if data == nil or states[player] == nil then
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
	stash(player, data, gain, seconds, absence, income, true)
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function OfflineService.Init()
	-- Accroche de la télémétrie : la part hors ligne d'un encaissement, celle d'avant gardée.
	local baseShare = TelemetryService.ClaimOfflineShare
	TelemetryService.ClaimOfflineShare = function(player: Player, amount: number): number
		local base = baseShare(player, amount)
		return base + claimShare(player, amount - base)
	end

	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- Après DataService (relevé du départ) et l'encaissement du départ (télémétrie) : au tour suivant.
		task.defer(function()
			states[player] = nil
		end)
	end)
	Net.Server.ClaimOffline:Connect(onClaimOffline)
	RunService.Heartbeat:Connect(onHeartbeat)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(Offline.TestAttribute):Connect(onTestAttribute)
	end
	print(`[OfflineService] gains hors ligne : {string.format("%g", Offline.Rate * 100)} % des revenus, {Offline.MaxHours} h au plus, versés au Claim (écran UI_Offline)`)
end

return OfflineService
