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
	-- Dépenses codées : achats de ShopService (BuyItem), SKU = Id du catalogue.
	Tool = { Flow = "Sink", Transaction = "Shop" }, -- Config/Tools (« Wrench »)
	Upgrade = { Flow = "Sink", Transaction = "Shop" }, -- Config/Upgrades (« Treadmill »)
	Aura = { Flow = "Sink", Transaction = "Shop" }, -- Config/Cosmetics (« Spark »)
	Trail = { Flow = "Sink", Transaction = "Shop" }, -- Config/Cosmetics (« Dust »)
	-- Points d'accroche des gains et dépenses pas encore codés (TelemetryService.LogEconomy) :
	Fence = { Flow = "Source", Transaction = "Shop" }, -- receleur (DEV-034) ; SKU proposé : rareté de l'objet vendu
	DailyReward = { Flow = "Source", Transaction = "TimedReward" }, -- quotidien (MAJ 1) ; SKU : Day1 à Day7
	PlaytimeReward = { Flow = "Source", Transaction = "TimedReward" }, -- temps de jeu (L-057) ; SKU : Playtime5…
	Code = { Flow = "Source", Transaction = "Code" }, -- code cadeau ; SKU : le code
	Robux = { Flow = "Source", Transaction = "IAP" }, -- argent acheté en Robux (MAJ 1) ; SKU : nom du produit
	Defense = { Flow = "Sink", Transaction = "Shop" }, -- défense de boutique (MAJ 2, DEV-110) ; SKU : Id
}

-- Événements custom (LogCustomEvent) : clé lue par le code = nom envoyé à Roblox.
local Events: { [string]: string } = {
	TheftSuccess = "PvPTheftSuccess", -- vol entre joueurs réussi (dépôt chez le voleur)
	TheftFail = "PvPTheftFail", -- vol entre joueurs raté (l'objet revient à son présentoir)
	BatBoxKnock = "BatBoxKnockdown", -- colis PNJ que la batte fait tomber hors zone safe
	GuardCatch = "GuardCatch", -- porteur d'un colis PNJ rattrapé par un vigile
	DefenseBought = "DefenseBought", -- achat d'une défense (MAJ 2) : point d'accroche
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
	Economy = Economy,
	Events = Events,
}

export type Telemetry = typeof(Telemetry)

return DeepFreeze(Telemetry)
