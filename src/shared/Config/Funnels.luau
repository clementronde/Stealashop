--!strict
-- Funnels (a414, vague GC7, 23/11 ; demande de Cantin : « des funnels dans le jeu ») : les entonnoirs envoyés à
-- AnalyticsService par FunnelService. Le tutoriel garde l'entonnoir d'onboarding de Roblox (TutorialService, étapes
-- Config/Tutorial.FunnelSteps, inchangé : c'est le parcours de chaque nouveau joueur, et ses bancs restent justes).
-- Lus dans le Creator Hub : tableau de bord de l'expérience > Analytics > Funnels (un onglet par entonnoir : 7 avec
-- l'onboarding, sur 10 permis). Le joueur ne les voit jamais.
--
-- Interrupteurs : Features.Analytics et Config/Telemetry.Enabled ; l'un des deux à false = rien n'est envoyé.
--
-- Doc Roblox (AnalyticsService, pages Funnel events et Event types, lues le 23/11) :
--   - onboarding : LogOnboardingFunnelStepEvent(player, step, stepName, champs), une seule fois par joueur ;
--   - entonnoir récurrent : LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName, champs) ;
--   - 10 entonnoirs au plus (onboarding compris), 100 étapes par entonnoir ; seule la 1re fois d'une étape compte
--     dans une session, mais chaque envoi compte dans la limite de 120 + 20 × joueurs requêtes par minute ; une
--     étape envoyée sans les précédentes les compte comme faites ; 10 dernières sessions gardées par joueur ;
--   - rien n'est envoyé depuis Studio ni depuis le client ; courbes visibles après 24 h environ.
--
-- Modes :
--   Once        une seule fois par profil, session fixe (le nom de l'entonnoir) ; étapes notées dans le profil ;
--   Session     une session par passage (GUID, HttpService:GenerateGUID), étapes notées en mémoire seulement.
-- Noms (entonnoir, étapes) : texte sans virgule, guillemet ni apostrophe (Roblox refuse l'événement sinon).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Mode = "Once" | "Session"

export type Step = {
	Key: string, -- clé lue par le code
	Name: string, -- nom affiché dans le Creator Hub
}

export type Funnel = {
	Name: string, -- funnelName envoyé à Roblox (et session des entonnoirs Once)
	Mode: Mode,
	NewOnly: boolean?, -- true : seulement les profils nouveaux (voir FirstSteps)
	Steps: { Step }, -- numéro d'étape = rang dans la liste
}

local Funnels: { [string]: Funnel } = {
	-- 1. Premiers pas de tout nouveau joueur (avec ou sans tutoriel), une fois par profil. Profil nouveau = sans Funnels,
	-- sans temps de jeu, sans braquage, vol ni objet à son 1er chargement ; un ancien profil n'y entre jamais.
	FirstSteps = {
		Name = "FirstSteps",
		Mode = "Once",
		NewOnly = true,
		Steps = {
			{ Key = "Arrive", Name = "Arrivée en jeu" }, -- profil chargé (FunnelService)
			{ Key = "Loaded", Name = "Chargement fini" }, -- écran UI_Loading fermé (FunnelController)
			{ Key = "Treadmill", Name = "Premier tapis" }, -- attribut TrainingMachine = Treadmill (TrainingService)
			{ Key = "Window", Name = "Première vitrine cassée" }, -- vitrine de magasin PNJ (WindowService.OnBroken)
			{ Key = "Steal", Name = "Premier objet volé" }, -- objet sorti d'un colis PNJ porté (CarryService.OnCarryStarted)
			{ Key = "Display", Name = "Premier objet exposé" }, -- un présentoir occupé dans le profil (Display)
			{ Key = "CashOut", Name = "Premier encaissement" }, -- DisplayService.OnCashOut (plaque, auto ; pas au départ)
			{ Key = "Upgrade", Name = "Première amélioration achetée" }, -- ShopService.OnPurchase, genre Upgrade
		},
	},
	-- 2. Progression dans le couloir, une fois par profil (tous les profils ; un ancien profil envoie d'un coup ce qu'il
	-- a déjà fait, à sa 1re session après la vague GC7).
	Progression = {
		Name = "Progression",
		Mode = "Once",
		Steps = {
			{ Key = "Zone1", Name = "Zone 1 atteinte" }, -- ZonesReached du profil (TelemetryService, ZoneReached)
			{ Key = "Zone2", Name = "Zone 2 atteinte" },
			{ Key = "Zone3", Name = "Zone 3 atteinte" },
			{ Key = "Zone4", Name = "Zone 4 atteinte" },
			{ Key = "Zone5", Name = "Zone 5 atteinte" },
			{ Key = "Zone6", Name = "Zone 6 atteinte" },
			{ Key = "Rebirth1", Name = "Première renaissance" }, -- Rebirths ≥ 1 dans le profil (RebirthService)
		},
	},
	-- 3. Boutique Robux, une session par ouverture de l'écran.
	RobuxShop = {
		Name = "RobuxShop",
		Mode = "Session",
		Steps = {
			{ Key = "Open", Name = "Boutique ouverte" }, -- UI_RobuxShop ou UI_RobuxShop_v2 allumé (FunnelController)
			{ Key = "View", Name = "Offre regardée" }, -- liste défilée ou souris sur un BuyButton (FunnelController)
			{ Key = "Buy", Name = "Achat lancé" }, -- clic sur un BuyButton (FunnelController)
			{ Key = "Bought", Name = "Achat réussi" }, -- MarketplaceService, achat fait (FunnelService)
		},
	},
	-- 4. Boutique d'armes, une session par ouverture.
	WeaponShop = {
		Name = "WeaponShop",
		Mode = "Session",
		Steps = {
			{ Key = "Open", Name = "Boutique ouverte" }, -- UI_WeaponShop allumé (FunnelController)
			{ Key = "Buy", Name = "Achat demandé" }, -- clic sur un BuyButton (FunnelController)
			{ Key = "Bought", Name = "Achat fait" }, -- ShopService.OnPurchase, genre Tool
		},
	},
	-- 5. Boutique d'auras et de trails, une session par ouverture.
	AuraShop = {
		Name = "AuraShop",
		Mode = "Session",
		Steps = {
			{ Key = "Open", Name = "Boutique ouverte" }, -- UI_AuraShop allumé (FunnelController)
			{ Key = "Buy", Name = "Achat demandé" }, -- clic sur un BuyButton (FunnelController)
			{ Key = "Bought", Name = "Achat fait" }, -- ShopService.OnPurchase, genre Aura ou Trail
		},
	},
	-- 6. Vol chez un joueur, une session par boutique visitée (entrée, ou prise sans entrée vue).
	PlayerTheft = {
		Name = "PlayerTheft",
		Mode = "Session",
		Steps = {
			{ Key = "Enter", Name = "Entrée chez un joueur" }, -- intrus d'une boutique ouverte au vol (PvPService.GetIntruders)
			{ Key = "Grab", Name = "Objet pris" }, -- PvPService.OnTheftStarted
			{ Key = "Exit", Name = "Sorti avec l objet" }, -- porteur hors du volume Bounds de la boutique volée
			{ Key = "Deposit", Name = "Objet déposé chez soi" }, -- PvPService.OnTheftEnded, Stolen
		},
	},
}

local Config = {
	Funnels = Funnels,
	-- Étapes que le client peut demander (remote FunnelStep) : clé envoyée → entonnoir et étape. Rien d'autre n'est
	-- accepté ; View, Buy et Bought ne comptent que dans une session ouverte par Open.
	ClientSteps = {
		Loaded = { Funnel = "FirstSteps", Step = "Loaded" },
		RobuxOpen = { Funnel = "RobuxShop", Step = "Open" },
		RobuxView = { Funnel = "RobuxShop", Step = "View" },
		RobuxBuy = { Funnel = "RobuxShop", Step = "Buy" },
		WeaponOpen = { Funnel = "WeaponShop", Step = "Open" },
		WeaponBuy = { Funnel = "WeaponShop", Step = "Buy" },
		AuraOpen = { Funnel = "AuraShop", Step = "Open" },
		AuraBuy = { Funnel = "AuraShop", Step = "Buy" },
	} :: { [string]: { Funnel: string, Step: string } },
	-- Écrans suivis par FunnelController : nom du ScreenGui → préfixe des clés ClientSteps (Open, View, Buy).
	Screens = {
		UI_RobuxShop = "Robux",
		UI_RobuxShop_v2 = "Robux",
		UI_WeaponShop = "Weapon",
		UI_AuraShop = "Aura",
	} :: { [string]: string },
	-- V0 proposé (Cantin, 23/11) : étapes demandées par le client acceptées par joueur et par minute (au-delà :
	-- ignorées), pour rester sous la limite de Roblox (240 requêtes par minute à 6 joueurs).
	ClientStepsPerMinute = 20,
	-- V0 proposé (Cantin, 23/11) : relevé (s) des étapes sans signal (tapis, présentoir, zones, renaissance,
	-- entrée et sortie d'une boutique volée).
	PollInterval = 0.5,
	-- V0 proposé (Cantin, 23/11) : défilement (px) de la liste de la boutique Robux qui compte comme « offre regardée ».
	ViewScroll = 40,
	-- V0 proposé (Cantin, 23/11) : durée de chargement envoyée (événement LoadingTime), bornée à cette valeur (s).
	MaxLoadingSeconds = 600,
}

export type Config = typeof(Config)

return DeepFreeze(Config)
