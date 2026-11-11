--!strict
-- Constantes d'équilibrage générales (Partie 1, sections 5.1 à 5.8, 6.2, 9.4, 9.6, 9.7).
-- Durées en secondes, distances en studs, vitesses en WalkSpeed, fractions
-- entre 0 et 1 (0.03 = 3 %). Les valeurs propres à un domaine vivent dans
-- leur module : Training, Night, Bat, PvP, Tutorial, Upgrades.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type BoxTier = "Standard" | "Premium" | "Luxe"

export type BoxTierInfo = {
	DisplayName: string, -- nom affiché, en anglais (L-036) ; la clé reste le Tier (Luxe)
	Look: string, -- aspect sur le rayon, avant la révélation de la rareté (7.3) ; description, jamais affichée
	Count: number, -- colis de ce type par magasin (5.3)
	GrabTime: number, -- durée de maintien pour le prendre (5.3)
}

local TIER_ORDER: { BoxTier } = { "Standard", "Premium", "Luxe" }

-- Clé = BoxTier (valeur de l'attribut `Tier` des ShelfSlot, 10.4)
local BOX_TIERS: { [string]: BoxTierInfo } = {
	Standard = { DisplayName = "Standard", Look = "Carton brun", Count = 6, GrabTime = 0.3 },
	Premium = { DisplayName = "Premium", Look = "Carton bleu scellé", Count = 3, GrabTime = 0.6 },
	Luxe = { DisplayName = "Luxury", Look = "Caisse en bois cerclée d'or", Count = 1, GrabTime = 1.0 },
}

local Balance = {
	-- 5.1 et 7.1 : WalkSpeed = min(70, 16 + Vitesse × 0,05 × trail) ; dégâts × (1 + Force / 100)
	Stats = {
		BaseWalkSpeed = 16,
		SpeedToWalkSpeed = 0.05,
		MaxWalkSpeed = 70, -- au-delà, collisions et caméra instables
		StrengthDivisor = 100,
	},

	-- 5.2 : slot 1 = outil de casse équipé, slot 2 = batte
	Hotbar = {
		ToolSlot = 1,
		BatSlot = 2,
	},

	-- 5.2 et 9.4 : un tap = un coup
	Hit = {
		Range = 8, -- portée d'un coup (5.2)
		ServerMaxDistance = 10, -- distance acceptée par le serveur pour HitWindow (9.4)
		MaxHitsPerSecond = 10, -- plafond serveur, autoclickers tolérés sans avantage
	},

	-- 5.3, 5.4, 9.4, 9.7 : vitrines PNJ et joueurs (WindowService)
	Window = {
		RegenPerSecond = 0.03, -- fraction des PV max régénérée chaque seconde
		-- Chrono de casse (Clément, liaison L-074, 2026-11-10 ; V0 à tester) : au premier coup sur une
		-- vitrine de magasin PNJ, il faut la casser en BreakTimer s, sinon elle revient à ses PV max.
		BreakTimer = 13,
		CrackThresholds = { 0.75, 0.5, 0.25 }, -- fissures visibles à ces fractions des PV
		RebuildDelay = 20, -- reconstruction après la fermeture du rideau
		HPSyncHz = 10, -- WindowHP envoyé en non fiable, 10 fois par seconde au plus
	},

	-- 5.3 : panneau au-dessus de la vitrine. Vert si le joueur atteint la valeur
	-- conseillée, orange de 50 à 99 %, rouge en dessous.
	StorePanel = {
		OrangeFrom = 0.5,
	},

	-- 5.3 et 9.4 : braquage d'un magasin PNJ
	Heist = {
		Duration = 10, -- chrono après la casse ; le rideau tombe à la fin
		BreakerHeadStart = 1, -- avance exclusive du casseur (5.3, point 8 : proposition à valider en section 15)
		MaxCarried = 1, -- un seul colis porté à la fois
		GrabMaxDistance = 8, -- GrabItem (9.4)
		ShelfSlots = 10, -- ShelfSlot_01 à ShelfSlot_10 (10.4)
		TierOrder = TIER_ORDER,
		BoxTiers = BOX_TIERS,
		-- Un seul braquage à la fois (Cantin, 2026-11-11, L-099 point 3) : un joueur dont le braquage n'est
		-- pas fini ne fait aucun dégât à la vitrine d'un autre magasin PNJ. V0 proposés, absents du doc :
		-- le message (anglais, L-036 ; Clément choisira le texte final) et son délai minimal entre deux
		-- envois au même joueur (s).
		OneAtATimeMessage = "Easy there, greedy! Finish your heist first.",
		OneAtATimeCooldown = 3,
	},

	-- 5.4 : séquence de casse, simulée côté client
	Shatter = {
		FreezeFrame = 0.06, -- arrêt sur image
		FlashDuration = 0.08, -- flash blanc
		CameraShakeDuration = 0.25,
		ShardFadeDelay = 1.5, -- les éclats restent au sol avant de s'effacer
		ShardFadeDuration = 1.2,
		MaxShards = 40, -- version pré-fracturée : 30 à 40 éclats
		LowEndShards = 10, -- mobile faible, ou au-delà de MaxFullShattersAtOnce
		MaxFullShattersAtOnce = 2,
		SoundPitchVariation = 0.1, -- ±10 %
	},

	-- 5.5 et 9.7 : vigile de jour (GuardService). Vitesses par zone : Zones.
	Guard = {
		PerThief = 1,
		MaxPerStore = 3,
		MaxActivePerServer = 6, -- 9.7
		PathRecomputeInterval = 0.3, -- PathfindingService sans ligne de vue : au plus un calcul toutes les 0,3 s (L-091)
		CatchDistance = 4, -- vérifiée côté serveur
		-- 2,4 s (Cantin, 2026-11-10 ; le doc disait 1,5) : le temps des animations de Clément, Knockdown
		-- (1,2 s) puis GetUp (1,2 s), pour que le joueur ne reparte pas en glissant pendant qu'il se relève.
		CatchStunDuration = 2.4,
		-- Poursuite sans fin (Cantin, 2026-11-11) : le vigile n'abandonne plus au bout de 20 s ni à 120 studs
		-- d'avance, seulement à la zone safe (ou à la fin du portage). Cette distance ne sert plus qu'à
		-- l'échelle de la jauge GuardMeter du HUD (HudController) : vide à cette distance, pleine à CatchDistance.
		GiveUpLead = 120,
		HeartbeatDistance = 10, -- battements de cœur sous cette distance
		-- V0 proposé, absent du doc (liaison L-077, question posée à Clément) : où s'arrête le retour
		-- du vigile de jour, qui s'y efface en fondu. "Reserve" (b) : il traverse le magasin jusqu'à
		-- son GuardSpawn ; "Door" (a) : il s'arrête à la porte du magasin (`Door`, sinon la vitrine),
		-- côté rue. Passage fermé (rideau baissé, vitrine reconstruite) : devant la porte, dans les
		-- deux cas. Déjà dans le magasin quand il rentre : jusqu'au GuardSpawn, dans les deux cas.
		ReturnEnd = "Reserve",
		ReturnFadeTime = 0.6, -- V0 proposé, absent du doc : durée du fondu de sa disparition (s)
		-- Décision d'Ironix (2026-11-08) : le magasin ne se rouvre (vitrine reconstruite, rideau levé)
		-- qu'une fois tous ses vigiles de jour rentrés, puis ce nombre de secondes (V0).
		ReopenAfterReturn = 3,
	},

	-- 5.6 et 6.1 : porter un colis ou un objet volé
	Carry = {
		NPCBoxSpeedMultiplier = 0.9, -- −10 % avec un colis PNJ
		StolenItemSpeedMultiplier = 0.75, -- −25 % avec un objet volé à un joueur
		CanJump = true,
		-- V0 proposé, absent du doc (L-071, point 4) : espace (studs) entre le haut de la tête et le
		-- dessous du colis ou de l'objet porté (CarryAttachment), soudé à la tête. À régler sur la
		-- hauteur des mains de CarryIdle et CarryRun (bras levés), quand Clément les livre.
		HeadGap = 0.25,
	},

	-- 5.7 et 7.5 : établis et révélation. Attente par rareté : Rarities.
	Unbox = {
		-- Plus lus par le code depuis L-086 (2026-11-08) : les colis s'ouvrent sur les présentoirs, sans
		-- établi. Gardés pour la trace des anciens profils (Upgrades.UnboxBenches).
		StartBenches = 1,
		MaxBenches = 4,
		FullRevealDuration = 4, -- version complète (Rare et plus), jusqu'à l'objet
		TensionEnd = 1.5, -- étape 2 : de 0 à 1,5 s
		ExplosionAt = 2.2, -- étape 3 : de 1,5 à 2,2 s, puis explosion
		FlashDuration = 0.1,
		ShortRevealDuration = 2, -- version courte (Commun, Peu commun)
		SecretSlowMotionDuration = 0.5,
	},

	-- 5.8 : présentoirs, inventaire, receleur. Améliorations : Upgrades.
	Display = {
		StartSlots = 4,
		MaxSlots = 20,
		InventoryMax = 30, -- objets non exposés
		FenceIncomeMultiplier = 120, -- le receleur rachète un objet 120 × son $/s
	},

	-- 6.2 et 9.4 : bouton Retour base
	ReturnToBase = {
		Cooldown = 90,
		AllowedWhileCarrying = false,
	},

	-- 9.6 : contrôle des déplacements (AntiCheatService)
	AntiCheat = {
		CheckInterval = 0.25,
		SpeedTolerance = 1.25, -- distance acceptée = vitesse autorisée × 1,25
		MaxAnomalies = 3, -- 3 anomalies…
		AnomalyWindow = 5, -- … en 5 s : retour à la dernière position valide, colis rendu
		TeleportDistance = 30, -- saut entre deux contrôles qui rend le colis ou l'objet
	},
}

export type Balance = typeof(Balance)

return DeepFreeze(Balance)
