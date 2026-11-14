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
	-- Rééquilibrage v2 (Cantin, 2026-11-14 ; docs/claude/notes/equilibrage-v2-proposition.md, section 3) :
	--   Speed affichée = Vitesse entraînée × M trail
	--   WalkSpeed      = min(70, 16 + 4 × log10(1 + Speed affichée / 100)) : « un zéro de plus = +4 de marche »
	--   Plus de banc ni de Force : dégâts d'un coup = P arme × M aura (× potion de force). Formulas.
	Stats = {
		BaseWalkSpeed = 16,
		MaxWalkSpeed = 70, -- au-delà, collisions et caméra instables (une sécurité : Speed 3,2Qa)
		WalkPerDecade = 4, -- V0 proposé (note v2) : WalkSpeed gagné chaque fois que la Speed affichée est multipliée par 10
		SpeedScale = 100, -- V0 proposé (note v2) : Speed affichée à partir de laquelle la marche commence à monter
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
		-- Plafond du serveur, pour tout le monde et pour toutes les cibles (vitrines, portes, camion, tour) :
		-- 5 coups par seconde (Cantin, 2026-11-14 ; avant : 10). C'est aussi le débit du remote HitWindow
		-- (Net/Definitions) et la cadence du client (HitController). Les PV des vitrines en dépendent (Zones).
		MaxHitsPerSecond = 5,
	},

	-- 5.3, 5.4, 9.4, 9.7 : vitrines PNJ et joueurs (WindowService)
	Window = {
		RegenPerSecond = 0.03, -- fraction des PV max régénérée chaque seconde
		-- Chrono de casse (Clément, liaison L-074, 2026-11-10 ; V0 à tester) : au premier coup sur une
		-- vitrine de magasin PNJ, il faut la casser en BreakTimer s, sinon elle revient à ses PV max.
		BreakTimer = 8, -- chrono de police (Cantin, 2026-11-14, passe 3 du rééquilibrage v2 ; avant : 13)
		CrackThresholds = { 0.75, 0.5, 0.25 }, -- fissures visibles à ces fractions des PV
		RebuildDelay = 20, -- reconstruction après la fermeture du rideau
		HPSyncHz = 10, -- WindowHP envoyé en non fiable, 10 fois par seconde au plus
	},

	-- PV des vitrines des magasins PNJ (rééquilibrage v2, passe 3 du 2026-11-14 : chrono de police de 8 s ;
	-- V0 proposés, note equilibrage-v2-proposition.md, « Passe 3 du 14/11 (8 s) »). LES TROIS NOMBRES À
	-- REMPLACER quand la règle change (chrono de police, temps de casse) : Config/Zones en déduit tous les PV,
	-- rien d'autre à toucher.
	--   PV = dégâts du panneau (arme × aura du kit de la zone) × joueurs × temps × Hit.MaxHitsPerSecond
	--        / (1 + Window.RegenPerSecond × temps)
	--   zones 1 à 5 : 1 joueur, SoloBreakTime        → 27,197 × dégâts (27, 272, 3 264, 40 795, 543 933)
	--   dernière zone : LastZoneTeamSize joueurs, LastZoneBreakTime → 54,393 × dégâts (108 786 611)
	--   (passe 2, chrono de 13 s : 11 s partout, soit 41,35 et 82,7 × dégâts : 41, 414, 4 962, 62 030, 827 068, 165.4M)
	-- À garder vrai : un joueur seul au panneau ne casse pas la dernière zone dans le chrono de police
	-- (Window.BreakTimer, 8 s en passe 3), même avec la potion de force : 16,2 s seul, 9,3 s avec la potion.
	WindowHP = {
		SoloBreakTime = 6.5, -- s : zones 1 à 5, un joueur seul au niveau du panneau casse en ce temps
		LastZoneBreakTime = 6.5, -- s : dernière zone, l'équipe au niveau du panneau casse en ce temps
		LastZoneTeamSize = 2, -- joueurs de cette équipe (jamais seul)
	},

	-- 5.3 : panneau au-dessus de la vitrine. Vert si le joueur atteint la valeur
	-- conseillée, orange de 50 à 99 %, rouge en dessous.
	StorePanel = {
		OrangeFrom = 0.5,
	},

	-- 5.3 et 9.4 : braquage d'un magasin PNJ
	Heist = {
		-- Chrono « HEIST » après la casse (Cantin, 2026-11-14, rééquilibrage v2 : 10 → 6 s). Il part à la casse
		-- (il ne reprend plus la fin du chrono de police, Balance.Window.BreakTimer) ; le rideau tombe à la fin.
		Duration = 6,
		BreakerHeadStart = 1, -- avance exclusive du casseur (5.3, point 8 : proposition à valider en section 15)
		MaxCarried = 1, -- un seul colis porté à la fois
		GrabMaxDistance = 8, -- GrabItem (9.4)
		-- Portée tolérée pendant un maintien (début et revérifications, pas la fin ; Cantin, 2026-11-14) : le serveur
		-- voit le perso en retard d'environ vitesse × latence. Tolérance = min(WalkSpeed × (ping + ReachLatencyPad),
		-- ReachToleranceMax), en plus de GrabMaxDistance et autour du volume Bounds. Aussi pour les colis au sol.
		ReachLatencyPad = 0.1, -- s, V0
		ReachToleranceMax = 8, -- studs, V0
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

	-- 9.5 : DataStore des profils joueurs (DataService), choisie selon le jeu Roblox (game.GameId).
	-- Remise à zéro des profils de la place DEV (Cantin, 2026-11-14, rééquilibrage v2) : le jeu DEV lit une
	-- autre DataStore, vide ; le jeu PROD (GameId 10774998269) et tout autre jeu gardent StoreName, à ne
	-- jamais changer. L'ancienne DataStore « PlayerData » du jeu DEV n'est ni effacée ni modifiée : pour y
	-- revenir, DevStoreName = "PlayerData". Pour une nouvelle remise à zéro du DEV : un nouveau nom.
	Profiles = {
		StoreName = "PlayerData", -- PROD : ne jamais le changer (un autre nom = profils vides)
		DevGameId = 10774974820, -- « Steal a Shop [DEV] » (liaison, L-001)
		DevStoreName = "PlayerData_DEV_20261114",
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
		-- Seule exception à la poursuite sans fin (Cantin, 2026-11-13, « environ 10 secondes ») : le vigile sorti à
		-- la fin du chrono pour un intrus resté sans objet (ChaseIntruder) abandonne au bout de ce temps de
		-- poursuite (s). Si l'intrus prend un objet entre-temps, c'est une poursuite de porteur, sans fin.
		IntruderChaseTime = 10,
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
		-- Objet volé à un joueur (ou au bot) : vitesse FIXE, la même pour tous, quels que soient la Vitesse,
		-- le trail, l'Adrénaline ou la potion du voleur (Cantin, 2026-11-13 : contre les voleurs trop rapides ;
		-- remplace le −25 % du doc, 6.1). V0 proposé : 16 = la vitesse d'un joueur neuf, à régler en test.
		StolenItemWalkSpeed = 16,
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
