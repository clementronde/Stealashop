--!strict
-- Tutoriel de départ (Partie 1, sections 3, 5.11, 5.12, 6.4 et 14.2 ; TutorialService et
-- TutorialController, DEV-046).
-- Guidage par flèche au sol et bulle courte (`UI_Tutorial`), jamais de mur de texte.
-- L'étape est sauvegardée (Tutorial.Step, 9.5 : 0 = pas commencé) : un joueur qui
-- part au milieu reprend au même endroit.
--
-- Origine des valeurs, notée en commentaire : « doc » = Partie 1 (section citée) ; « V0 » = V0
-- proposé, absent du doc, à régler en playtest.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)
local Rarities = require(script.Parent.Rarities)

export type Step = {
	Index: number,
	Id: string,
	At: number, -- moment visé depuis l'arrivée, en secondes (section 3) : repère d'équilibrage, pas un minuteur
	Goal: string, -- ce qui se passe à cette étape (section 3) ; note pour l'équipe, jamais affichée
	Bubble: string?, -- texte de la bulle, en anglais (L-036), 8 mots au plus ; V0 proposé, absent du doc
	-- Vague 31 (L-112, a107) : bulle quand Features.ShelfOpen = true (colis ouvert sur le rayon), si elle
	-- diffère ; absente = Bubble. TutorialController la choisit.
	ShelfBubble: string?,
}

local Steps: { Step } = {
	{ Index = 1, Id = "ArriveAtPlot", At = 0, Goal = "Arrivée sur sa parcelle, flèche au sol vers la Supérette", Bubble = "Smash the Mini Mart window!" },
	{ Index = 2, Id = "HitWindow", At = 15, Goal = "Premiers coups aux poings sur la vitre (35 PV)", Bubble = "Hit the glass again and again!" },
	{ Index = 3, Id = "GrabBox", At = 25, Goal = "Casse et chrono de 10 s ; colis Premium, vigile lent", Bubble = "Grab a box and run!", ShelfBubble = "Open a box on the shelf!" },
	{ Index = 4, Id = "PlaceBox", At = 45, Goal = "Retour en zone safe (colis dans l'inventaire), colis posé au sol de sa boutique (L-089), attente de 5 s, objet Rare", Bubble = "Bring the box back to your shop!", ShelfBubble = "Bring the item back to your shop!" },
	{ Index = 5, Id = "DisplayItem", At = 60, Goal = "Objet sur un présentoir (5 $/s), premier encaissement", Bubble = "Display your item to earn cash!" },
	{ Index = 6, Id = "Train", At = 2 * 60, Goal = "Le tapis et le banc s'allument, 30 s d'entraînement guidé", Bubble = "Train on the treadmill and bench" },
	{ Index = 7, Id = "BuyTool", At = 3 * 60, Goal = "Flèche vers la boutique d'armes, clé à molette (300 $)", Bubble = "Buy the Wrench!" },
	{ Index = 8, Id = "BuyAura", At = 4 * 60, Goal = "Flèche vers la boutique d'auras, première aura (500 $)", Bubble = "An aura multiplies your damage!" },
	{ Index = 9, Id = "GoToZone2", At = 5 * 60, Goal = "Objectif affiché : la zone 2 (vitesse 22, dégâts 10)", Bubble = "Next goal: Zone 2!" },
	-- Étape 10 : message de fin du bouclier débutant (texte du doc, voir ShieldEndMessage)
	{ Index = 10, Id = "ShieldEnd", At = 10 * 60, Goal = "Fin du bouclier débutant : son colis volé peut tomber à la batte", Bubble = nil },
	-- Vague 36 (L-085 point 4, a121) : le vol entre joueurs, sur la boutique du bot (BotService). Ajoutées à la
	-- fin, sans changer les numéros ni les Id d'avant (un Tutorial.Step sauvegardé garde son sens). Sautées
	-- sans bot sur le serveur : le tuto finit alors à l'étape 10, comme avant. V0 proposés, absents du doc
	-- (étapes, At, bulles). L'étape « le voir défendre sa base » attend la défense du bot (L-117 point 7).
	{ Index = 11, Id = "GoToBotShop", At = 10 * 60 + 30, Goal = "Flèche vers la porte de la boutique du bot", Bubble = "Steal from another shop!" },
	{ Index = 12, Id = "StealFromBot", At = 10 * 60 + 60, Goal = "Casser la porte du bot et lui prendre un objet exposé", Bubble = "Break in and grab an item!" },
	{ Index = 13, Id = "BringStolenHome", At = 10 * 60 + 90, Goal = "Ramener l'objet volé dans sa boutique (dépôt PvPService), fin du tuto", Bubble = "Bring it back to your shop!" },
}

-- Textes écrits dans le doc, traduits en anglais (L-036). ShieldEndMessage dépasse les 8 mots
-- d'une bulle. Depuis le 2026-11-12 (Cantin, doc 6.4), la boutique est braquable dès le départ : le
-- bouclier ne protège plus que le colis porté. Texte V0 d'Ironix, à valider par Clément (L-115).
local SHIELD_END_MESSAGE = "Beginner protection is over: keep your bat close!"
local NIGHT_BUBBLE = "Night is falling: hurry home!" -- 5.12, pour les nouveaux joueurs

local Tutorial = {
	-- V0 : interrupteur. false = aucun tutoriel : TutorialService ne pose aucune accroche, ne
	-- change aucun profil et n'envoie rien (ni bulle, ni flèche, ni funnel).
	Enabled = true,

	Steps = Steps,
	SkipFromStep = 5, -- bouton Passer à partir de l'étape 5 (TutorialSkip, 9.4)
	BubbleMaxWords = 8,
	FirstStoreDistance = 60, -- flèche vers la Supérette, à 60 studs

	-- 5.11 : résultats garantis
	FirstBoxTier = "Premium" :: Balance.BoxTier,
	GuardSpeed = 12, -- vigile lent du tuto
	OpenDelay = 5, -- attente raccourcie du premier colis
	GuaranteedRarity = "Rare" :: Rarities.RarityId,
	-- Objet du premier colis (catalogue v2, L-045) : le Pot de nouilles, Rare de la zone 1, marqué
	-- TutorialOnly dans Config/Items : il ne sort d'aucun tirage, Items.Pick(1, "Rare") ne le donne
	-- pas. TutorialService le passe en ItemId à StoreHeistService.SetContentOverride (une Rarity
	-- seule tirerait dans la zone, où aucun Rare n'est tirable).
	GuaranteedItemId = "Z1_PotDeNouilles",
	-- Vague 31 (L-112, Features.ShelfOpen ; a107). Le Pot de nouilles est l'objet SORTI du premier colis ouvert
	-- sur le rayon (SetContentOverride, appliqué à la sortie ; contenu imposé : aucun cran de rareté).
	-- V0 : chance imposée à l'ouverture du tuto (StoreHeistService.SetLuckOverride). ×1,5 plutôt que ×1 :
	-- le compteur « ×N LUCK » monte 1,4 s (rabats compris : 2 s), assez pour voir la mécanique et le « ? »
	-- des témoins bouger, jamais assez pour la police (×8 et plus) ; ×1 sortirait l'objet sans rien montrer.
	ShelfLuck = 1.5,
	-- V0 : antivol de l'objet du tuto posé au sol (UnboxService.GetAntiTheftDelay ; 20 s pour un Rare,
	-- ShelfOpen.AntiTheft) : le même que l'attente raccourcie du premier colis (OpenDelay).
	AntiTheftDelay = 5,

	-- Étapes 1 à 4 (section 3) : le braquage de la Supérette, en zone 1 (zone tuto, L-033).
	TutorialZone = 1, -- doc : tout magasin de cette zone compte (la Supérette ou le Kiosque)
	TargetStoreId = "Superette", -- doc : flèche vers la Supérette (STORE_Z1_Superette, Zones[1].StoreIds)
	-- V0 : un joueur des étapes 1 et 2 à cette distance (studs) d'une vitrine de la zone 1 ouverte passe
	-- à l'étape 3, même si c'est un autre joueur qui l'a cassée (même rayon que le chrono HeistTimer).
	StoreNearRadius = 60,
	TrainDuration = 30, -- doc, section 3, étape 6 : « 30 s d'entraînement guidé » (tapis et banc cumulés)
	ToolToBuy = "Wrench", -- doc, étape 7 : la clé à molette (300 $, table 7.2) ; un outil plus fort compte aussi
	GoalZone = 2, -- doc, étape 9 : objectif la zone 2 (vitesse conseillée 22, dégâts conseillés 10)
	MessageDuration = 8, -- V0 : secondes d'affichage de ShieldEndMessage avant la fin du tuto
	Tick = 0.5, -- V0 : secondes entre deux contrôles de TutorialService (seuils, zone 2, bouclier, nuit)
	-- Vague 36 (L-085 point 4, a121), étapes 11 à 13 (vol sur la boutique du bot), V0 proposés, absents du doc :
	BotShopRadius = 15, -- studs : à cette distance de la porte du bot (ou dans sa boutique), étape 11 → 12
	-- Secondes au début d'une session (reprise à l'étape 11 à 13) pendant lesquelles un bot absent est attendu
	-- avant de finir le tuto : un serveur neuf le fait venir Bot.ArriveDelay (5) s plus tard, revu chaque
	-- Bot.CheckInterval (1) s ; marge de 2 s.
	BotWait = 8,

	-- Textes écrits dans le doc, traduits en anglais (L-036)
	ShieldEndMessage = SHIELD_END_MESSAGE,
	NightBubble = NIGHT_BUBBLE,

	-- Indices de phase : TutorialService choisit l'indice (remote TutorialStep), TutorialController
	-- affiche son texte à la place de la bulle de l'étape. En anglais (L-036), 8 mots au plus ; V0
	-- proposés, absents du doc, sauf Night et ShieldEnd (textes du doc ci-dessus).
	Hints = {
		EquipFists = "Equip your Fists, then hit!", -- étapes 1 et 2, près de la vitrine sans outil en main (client)
		WindowRebuilding = "Wait, the window is coming back!", -- étape 2 : vitrine cassée, rideau baissé
		-- étapes 4 et 5 (L-089) : colis dans l'inventaire, à poser au sol de sa boutique depuis l'écran
		-- UI_Inventory (vague 21, L-079 : plus de barre Roblox ni de colis tenu en main)
		PlaceBox = "Open your inventory, then place your box!",
		WaitBox = "Wait for your box to open!", -- étape 5 : colis posé au sol, attente pas finie
		OpenBox = "Open your box!", -- étape 5 : colis prêt à ouvrir
		-- étape 5 (L-089) : objet dans l'inventaire, rien d'exposé
		PlaceItem = "Open your inventory, then place your item!",
		CollectCash = "Step on the green pad to collect!", -- étape 5 (objet exposé), 7 et 8 (pas assez d'argent) ; V0 proposé (L-091 : plaques CollectPad_xx)
		-- étape 6, flèche vers le tapis : il n'a plus d'invite, on s'entraîne en s'arrêtant dessus (L-071)
		StandOnTreadmill = "Stand on the treadmill to train!",
		NightClosed = "The street opens again at dawn!", -- nuit, étapes 1 à 3 et 9, côté zone safe
		Night = NIGHT_BUBBLE, -- 5.12 : alerte et nuit, joueur dans le couloir
		ShieldEnd = SHIELD_END_MESSAGE, -- 6.4 : fin du bouclier débutant
		-- Vague 31 (L-112, Features.ShelfOpen ; a107), V0 proposés, absents du doc :
		WaitReveal = "Watch your luck go up!", -- étape 3 : son colis s'ouvre sur le rayon (flèche : le colis)
		GrabItem = "Grab your item and run!", -- étape 3 : son objet est sorti (flèche : l'objet)
		PlaceFloorItem = "Open your inventory, place it on the floor!", -- étapes 4 et 5 : objet sous antivol dans l'inventaire
		WaitUnlock = "Guard it until it is UNLOCKED!", -- étape 5 : objet au sol, antivol en cours (volable)
		DisplayUnlocked = "UNLOCKED! Now put it on display!", -- étape 5 : antivol fini, invite « Display »
	} :: { [string]: string },

	-- Flèche au sol de Clément (UI-006, pas encore livrée) : noms proposés, pas encore au contrat. Cherchés
	-- dans ReplicatedStorage/Assets (sous-dossiers compris) ; tant qu'ils manquent, TutorialController
	-- fait une flèche V0. ArrowAsset : un Beam (texture, couleur, largeurs, défilement de Clément),
	-- copié entre les pieds du joueur et la cible. MarkerAsset : un Model ou une pièce, pivot en bas au
	-- centre, posé sur la cible.
	ArrowAsset = "FX_Tutorial_Arrow",
	MarkerAsset = "FX_Tutorial_Marker",

	-- 14.2 : étapes du funnel d'onboarding, envoyées une seule fois par joueur avec
	-- AnalyticsService:LogOnboardingFunnelStepEvent (index = numéro d'étape). En français : l'équipe
	-- les lit dans le Creator Dashboard, le joueur ne les voit pas (L-036). Jamais de virgule, de
	-- guillemet ni d'apostrophe : Roblox refuse alors l'étape (« Event field stepName is invalid »,
	-- vu en Studio le 2026-11-07) ; les étapes 6 et 10 du doc sont donc reformulées.
	FunnelSteps = {
		"Arrivée sur sa parcelle",
		"Premier coup sur une vitrine",
		"Première vitrine cassée",
		"Premier colis volé",
		"Arrivée en zone safe avec le colis",
		"Colis posé sur un établi", -- nom gardé (L-089 : le colis se pose au sol de la boutique) pour ne pas couper le funnel du Creator Dashboard
		"Premier objet révélé",
		"Premier objet exposé",
		"Premier encaissement",
		"Premier outil acheté",
		-- Vague 36 (a121, V0 proposés) : étapes 11 à 13 du tuto, envoyées seulement pendant le tuto, avec un bot.
		"Boutique du bot atteinte",
		"Premier objet pris au bot",
		"Objet du bot ramené chez soi",
	},
}

export type Tutorial = typeof(Tutorial)

return DeepFreeze(Tutorial)
