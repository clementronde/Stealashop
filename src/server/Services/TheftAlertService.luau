--!strict
-- TheftAlertService (DEV-042) : la victime d'un vol entre joueurs, côté serveur (Partie 1, section
-- 6.2, usage 1 ; 9.3 et 9.5). PvPService fait le vol et envoie l'alerte à la victime (TheftAlert(true,
-- voleur, itemId) à la prise de l'objet, TheftAlert(false) à la fin du vol) ; ce service y ajoute,
-- en écoutant les événements de PvPService et de BatService :
--
--   1. Adrénaline (6.2 : « +25 % de vitesse jusqu'à la fin de la poursuite ») : pendant tout vol
--      subi, du début (PvPService.OnTheftStarted : l'objet vient d'être pris) à la fin (OnTheftEnded :
--      dépôt chez le voleur ou échec), la victime court à 1 + PvP.AdrenalineSpeedBonus (× 1,25), par
--      StatsService.SetSpeedModifier(victime, "Adrenaline", …) : le bonus se multiplie aux autres
--      modificateurs, sous le plafond de 70 (StatsService). Plusieurs vols chez la même victime : un
--      seul bonus, jamais cumulé, retiré seulement à la fin du dernier. Aucun compteur ici : à chaque
--      début et à chaque fin, PvPService.GetTheft dit s'il reste un vol chez elle.
--      Mort de la victime : le bonus reste (la poursuite continue ; StatsService le remet à son
--      nouveau personnage). Mort ou départ du voleur, départ de la victime : PvPService fait échouer
--      le vol, le bonus part avec sa fin.
--   2. Réannonce de l'alerte : PvPService envoie TheftAlert(false) à la fin de chaque vol, même si la
--      victime en subit encore un autre. Juste après ce false (dans la même exécution), ce service
--      renvoie d'abord TheftAlert(true, intrus, nil) pour chaque intrus encore dans sa boutique (vague 33,
--      PvPService.GetIntruders : alerte d'intrusion), puis TheftAlert(true, voleur, itemId) pour chaque
--      vol encore en cours chez elle, du plus
--      ancien au plus récent : son écran reste ouvert sur le dernier (TheftAlertController applique
--      les messages d'une même image ensemble ; BatController rééquipe la batte, sans effet si elle
--      est déjà en main). Rien n'est renvoyé à une victime qui part (raison « VictimLeft »).
--   3. Défense réussie : Lifetime.Defenses + 1 dans le profil de la victime (9.5) quand elle frappe
--      son voleur à la batte (BatService.OnHit, usage « Defend » : l'objet est déjà reparti sur son
--      présentoir). Les autres coups (colis PNJ, voleur de quelqu'un d'autre) ne comptent pas.
--
-- Aucun remote reçu, aucune API : tout passe par les événements de PvPService et de BatService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local PvP = require(Shared.Config.PvP)
local Net = require(Shared.Net.Net)
local CarryTypes = require(Shared.Types.Carry)

local BatService = require(script.Parent.BatService)
local DataService = require(script.Parent.DataService)
local PvPService = require(script.Parent.PvPService)
local StatsService = require(script.Parent.StatsService)

type Payload = CarryTypes.Payload

-- Vol encore en cours chez une victime.
type Ongoing = {
	Thief: Player,
	ItemId: string,
	Order: number, -- ordre d'arrivée (OnTheftStarted)
}

-- Clé prévue par StatsService (voir son en-tête).
local ADRENALINE_KEY = "Adrenaline"
local ADRENALINE_MULTIPLIER = 1 + PvP.AdrenalineSpeedBonus

local IS_STUDIO = RunService:IsStudio()

local TheftAlertService = {}
-- V0 proposé, absent du doc : après PvPService (120), dont il écoute les vols.
TheftAlertService.Priority = 125

local orderOf: { [Player]: number } = {} -- numéro d'arrivée du vol en cours de chaque voleur
local counter = 0
local boosted: { [Player]: boolean } = {} -- victimes qui ont l'Adrénaline

local function log(message: string)
	if IS_STUDIO then
		print(`[TheftAlertService] {message}`)
	end
end

-- Vols en cours chez `victim`, du plus ancien au plus récent. PvPService fait foi.
local function ongoingFor(victim: Player): { Ongoing }
	local list: { Ongoing } = {}
	for _, player in Players:GetPlayers() do
		local info = PvPService.GetTheft(player)
		if info and info.Victim == victim then
			table.insert(list, { Thief = player, ItemId = info.ItemId, Order = orderOf[player] or 0 })
		end
	end
	table.sort(list, function(a: Ongoing, b: Ongoing): boolean
		return a.Order < b.Order
	end)
	return list
end

-- Pose ou retire l'Adrénaline de `victim` selon les vols en cours chez elle (voir l'en-tête).
local function refreshAdrenaline(victim: Player, ongoing: { Ongoing })
	local wanted = #ongoing > 0
	if wanted == (boosted[victim] == true) then
		return
	end
	if wanted then
		boosted[victim] = true
		StatsService.SetSpeedModifier(victim, ADRENALINE_KEY, ADRENALINE_MULTIPLIER)
		log(`{victim.Name} : Adrénaline (vitesse × {ADRENALINE_MULTIPLIER}) jusqu'à la fin du vol`)
	else
		boosted[victim] = nil
		StatsService.SetSpeedModifier(victim, ADRENALINE_KEY, nil)
		log(`{victim.Name} : fin de l'Adrénaline, plus aucun vol en cours`)
	end
end

local function onTheftStarted(thief: Player, victim: Player, _itemId: string)
	counter += 1
	orderOf[thief] = counter
	refreshAdrenaline(victim, ongoingFor(victim))
end

local function onTheftEnded(thief: Player, victim: Player, _itemId: string, _result: PvPService.TheftResult, reason: string)
	orderOf[thief] = nil
	local ongoing = ongoingFor(victim)
	refreshAdrenaline(victim, ongoing)
	if reason == "VictimLeft" or victim.Parent ~= Players then
		return
	end
	-- TheftAlert(false) vient de partir (PvPService) : les intrus (vague 33), puis les vols encore en
	-- cours sont réannoncés.
	local list: { Player } = PvPService.GetIntruders(victim)
	for _, intruder in list do
		Net.Server.TheftAlert:Fire(victim, true, intruder, nil)
	end
	for _, theft in ongoing do
		Net.Server.TheftAlert:Fire(victim, true, theft.Thief, theft.ItemId)
	end
	if #ongoing > 0 then
		log(`{victim.Name} : {#ongoing} vol(s) encore en cours, alerte réannoncée`)
	end
end

-- Défense réussie (voir l'en-tête). Sans yield. Un Lifetime illisible (profil abîmé) est signalé,
-- pas réparé ici (comme Lifetime.Heists dans UnboxService).
local function onBatHit(hitter: Player, target: Player, usage: BatService.Usage, _payload: Payload?)
	if usage ~= "Defend" then
		return
	end
	local data = DataService.Get(hitter)
	local lifetime = if data then (data :: any).Lifetime else nil
	if type(lifetime) ~= "table" then
		warn(`[TheftAlertService] {hitter.Name} : Lifetime absent du profil, défense non comptée`)
		return
	end
	local defenses = lifetime.Defenses
	if type(defenses) ~= "number" or defenses ~= defenses then
		warn(`[TheftAlertService] {hitter.Name} : Lifetime.Defenses illisible ({tostring(defenses)}), repart de 0`)
		defenses = 0
	end
	lifetime.Defenses = defenses + 1
	log(`{hitter.Name} frappe son voleur {target.Name} : défense réussie ({defenses + 1} en tout)`)
end

function TheftAlertService.Init()
	PvPService.OnTheftStarted(onTheftStarted)
	PvPService.OnTheftEnded(onTheftEnded)
	BatService.OnHit(onBatHit)
	Players.PlayerRemoving:Connect(function(player: Player)
		orderOf[player] = nil
		boosted[player] = nil
	end)
	log(`Adrénaline × {ADRENALINE_MULTIPLIER} pour la victime d'un vol, défenses à la batte comptées`)
end

return TheftAlertService
