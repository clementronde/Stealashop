--!strict
-- Télémétrie (DEV-054 ; Partie 1, section 14.2) : noms et réglages des envois à AnalyticsService.
-- Lu par TelemetryService (économie et événements custom) et par TutorialService (funnel
-- d'onboarding : seulement l'interrupteur Enabled ; les noms des étapes restent dans
-- Config/Tutorial.FunnelSteps). L'équipe lit ces noms dans le Creator Dashboard (Analytics) : le
-- joueur ne les voit jamais.
--
-- Noms en anglais (événements, monnaie, genres, types de transaction, SKU), sans virgule, guillemet
-- ni apostrophe : Roblox refuse un événement qui en contient (« Event field stepName is invalid »,
-- vu en Studio le 2026-11-07 pour le funnel). TelemetryService les vérifie au démarrage.
--
-- Limites de Roblox (doc « Event types » de l'Analytics, lue le 2026-11-08) : 120 + 20 × joueurs
-- requêtes par minute et par serveur (240 à 6 joueurs) ; 100 noms d'événements custom ; 3 champs
-- custom par événement, en texte, 8 000 combinaisons de valeurs ; 10 monnaies ; au-delà de 20 types
-- de transaction ou de 100 SKU, le reste est regroupé en « Other ». Rien n'est envoyé depuis Studio.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Sens d'un mouvement d'argent : nom d'un membre de Enum.AnalyticsEconomyFlowType.
export type Flow = "Source" | "Sink"

-- Un genre de gain ou de dépense. Sa clé dans Economy part aussi dans le champ custom 1 de chaque
-- envoi (« Kind - Income »).
export type EconomyKind = {
	Flow: Flow, -- Source = gain, Sink = dépense
	-- Nom d'un membre de Enum.AnalyticsEconomyTransactionType (IAP, TimedReward, Onboarding, Shop,
	-- Gameplay, ContextualPurchase), sinon un type à nous (Roblox les accepte).
	Transaction: string,
	Sku: string?, -- SKU fixe ; sans lui, celui donné à l'envoi (Id de l'outil, de l'amélioration…)
	Aggregate: boolean?, -- true : additionné par joueur, un envoi au plus toutes les FlushInterval s
}

local Economy: { [string]: EconomyKind } = {
	-- Gain codé : revenus des objets exposés, encaissés au tapis de caisse (DisplayService).
	Income = { Flow = "Source", Transaction = "Gameplay", Sku = "Income", Aggregate = true },
	-- Gain codé : gains hors ligne (DEV-102, OfflineService), versés dans l'argent au Claim (UI_Offline) : la part
	-- d'un encaissement qui en vient part ici, le reste en Income. Type V0 proposé : TimedReward.
	Offline = { Flow = "Source", Transaction = "TimedReward", Sku = "Offline", Aggregate = true },
	-- Dépenses codées : achats de ShopService (BuyItem), SKU = Id du catalogue.
	Tool = { Flow = "Sink", Transaction = "Shop" }, -- Config/Tools (« Wrench »)
	Upgrade = { Flow = "Sink", Transaction = "Shop" }, -- Config/Upgrades (« Treadmill »)
	Aura = { Flow = "Sink", Transaction = "Shop" }, -- Config/Cosmetics (« Spark »)
	Trail = { Flow = "Sink", Transaction = "Shop" }, -- Config/Cosmetics (« Dust »)
	-- Points d'accroche des gains et dépenses pas encore codés (TelemetryService.LogEconomy) :
	Fence = { Flow = "Source", Transaction = "Shop" }, -- receleur (DEV-034) ; SKU proposé : rareté de l'objet vendu
	DailyReward = { Flow = "Source", Transaction = "TimedReward" }, -- quotidien (DEV-101, RewardService) ; SKU : Day1 à Day7
	PlaytimeReward = { Flow = "Source", Transaction = "TimedReward" }, -- temps de jeu (DEV-101, RewardService) ; SKU : Playtime5 à Playtime60
	-- Gain codé : prime d'une zone complète de l'Index (IndexService, L-083 point 7), SKU IndexZone1 à
	-- IndexZone6. Type V0 proposé : Gameplay (gagnée en jouant, pas au temps).
	IndexReward = { Flow = "Source", Transaction = "Gameplay" },
	Code = { Flow = "Source", Transaction = "Code" }, -- code cadeau ; SKU : le code
	Robux = { Flow = "Source", Transaction = "IAP" }, -- argent acheté en Robux (MAJ 1, MonetizationService) ; SKU : clé du produit (Cash10…)
	Defense = { Flow = "Sink", Transaction = "Shop" }, -- défense de boutique (MAJ 2, DEV-110) ; SKU : Id
}

-- Événements custom (LogCustomEvent) : clé lue par le code = nom envoyé à Roblox.
local Events: { [string]: string } = {
	TheftSuccess = "PvPTheftSuccess", -- vol entre joueurs réussi (dépôt chez le voleur)
	TheftFail = "PvPTheftFail", -- vol entre joueurs raté (l'objet revient à son présentoir)
	BatBoxKnock = "BatBoxKnockdown", -- colis PNJ que la batte fait tomber hors zone safe
	GuardCatch = "GuardCatch", -- porteur d'un colis PNJ rattrapé par un vigile, ou joueur attrapé la nuit sans colis
	RewardClaim = "RewardClaimed", -- récompense réclamée (DEV-101) : argent, colis ou boost ; champs Source, Sku, Gift
	DefenseBought = "DefenseBought", -- achat d'une défense (MAJ 2) : point d'accroche
	PotionPicked = "PotionPicked", -- potion ramassée (vague 28, PotionService) ; champ Potion (Money, Strength…)
	AdminCommand = "AdminCommand", -- commande du panel admin acceptée (vague 29, AdminService) ; champ Command
	-- Vague 41 (audit de sécurité du 14/11), TelemetryService :
	RemoteRefused = "RemoteRefused", -- demandes refusées par Net (Net.OnViolation), cumulées par joueur, remote et raison ; valeur = nombre ; champs Remote, Reason
	DuplicateItem = "DuplicateItem", -- un même uid d'objet chez deux joueurs du serveur (vu au chargement d'un profil) ; joueur = celui qui arrive ; champs Rarity, Zone
	ZoneReached = "ZoneReached", -- 1re entrée d'un profil dans une zone (1 à 6), mesure de la bêta ; valeur = temps de jeu cumulé (s) ; champ Zone
}

local Telemetry = {
	-- Interrupteur : false = rien n'est envoyé à AnalyticsService, ni économie, ni événement
	-- custom, ni étape du funnel (TutorialService).
	Enabled = true,
	-- La monnaie du jeu, une seule : l'argent (Cash du profil, 9.5).
	Currency = "Cash",
	-- V0 proposé, absent du doc : un gain regroupé (Aggregate) part au plus tard FlushInterval s
	-- après le premier ajout de son cumul (voir TelemetryService).
	FlushInterval = 60,
	-- V0 proposé, absent du doc (vague 41) : les demandes refusées (RemoteRefused) d'un joueur partent au
	-- plus RefusalFlushInterval s après la première de leur cumul, et à son départ.
	RefusalFlushInterval = 60,
	-- V0 proposé, absent du doc (vague 41) : intervalle (s) du relevé de la zone de chaque joueur (ZoneReached).
	ZoneCheckInterval = 0.5,
	Economy = Economy,
	Events = Events,
}

export type Telemetry = typeof(Telemetry)

return DeepFreeze(Telemetry)
