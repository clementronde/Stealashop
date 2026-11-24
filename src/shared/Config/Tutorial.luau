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
local PvP = require(script.Parent.PvP) -- AnyoneCanRob lit le nombre de coups de la porte (PvP.DoorHits)
local Tools = require(script.Parent.Tools) -- vague 61 : prix de la clé à molette (don de l'étape 7)
local Cosmetics = require(script.Parent.Cosmetics) -- vague 61 : prix de l'aura la moins chère (don de l'étape 8)

-- a429 (L-327 point 3) : objet du tuto du catalogue actif (Config/Items.TutorialItemId : Pot de nouilles en v2, Ramen
-- de feu en v3) ; Config/Items lu s'il est là (bancs à liste de modules fixe : le Pot de nouilles, comme avant).
local TUTORIAL_ITEM_ID: string = (function(): string
	local ok, id = pcall(function(): any
		local module = script.Parent:FindFirstChild("Items")
		return if module ~= nil then (require(module :: any) :: any).TutorialItemId else nil
	end)
	return if ok and type(id) == "string" then id else "Z1_PotDeNouilles"
end)()

-- Vague 61 (a199 ; Cantin : « le tuto, il est trop long […] Quitte à leur donner l'argent […] maximum dans son
-- entièreté 2 à 3 minutes ») : le tuto entier en 3 min au plus (cible 2 à 2 min 30, durées des étapes dans les At
-- plus bas). Trois leviers, V0 :
--   - l'étape 10 n'attend plus la fin du bouclier débutant (10 min de jeu cumulées) : on passe de la zone 2 au vol
--     sur le bot, ou à la fin sans bot. false → true : l'ancienne règle (attente, message ShieldEndMessage) ;
--   - dons d'argent aux étapes 7 et 8 (GiftCash) : le prix de la clé à molette puis de l'aura, une seule fois par
--     profil (Tutorial.Gifts), plus d'attente de 300 $ puis de 500 $ à 5 $/s ;
--   - TrainDuration : 10 s de tapis au lieu de 30.
local WAIT_SHIELD_END = false

export type Step = {
	Index: number,
	Id: string,
	At: number, -- moment visé depuis l'arrivée, en secondes (section 3) : repère d'équilibrage, pas un minuteur
	Goal: string, -- ce qui se passe à cette étape (section 3) ; note pour l'équipe, jamais affichée
	Bubble: string?, -- texte de la bulle, en anglais (L-036), 8 mots au plus ; V0 proposé, absent du doc
}

-- Vague 60 (a197, liste des tâches) : ce qu'il faut faire à une étape (Do) et, quand le serveur envoie une
-- progression (have < need, remote TutorialStep), le texte affiché à sa place (Need : {have}, {need} et {left} =
-- need - have, écrits au format NeedFormat). Anglais, V0 proposés, absents du doc.
export type Todo = {
	Do: string,
	Need: string?,
	NeedFormat: ("Money" | "Short" | "Seconds" | "Time")?,
}

-- Vague 60 (a197) : une tâche de la liste = une ou plusieurs étapes qui se suivent (Steps, dans l'ordre du jeu :
-- l'étape 14 se joue entre 12 et 13), avec son but (Goal) et sa raison (Why). Anglais, V0 proposés, absents du doc.
export type Task = {
	Id: string,
	Steps: { number },
	Goal: string,
	Why: string,
}

-- Vague 52 (a169, lot C de la vague 48 ; décision de Cantin du 2026-11-14 : plus de colis ramené en zone safe) :
-- le tuto ne parle plus que d'objets. Mêmes numéros et mêmes Id (GrabBox, PlaceBox gardés : un Tutorial.Step
-- sauvegardé garde son sens), aucune étape retirée ; les bulles des étapes 3 et 4 sont celles de l'ouverture
-- sur le rayon (l'ancien champ ShelfBubble, retiré).
-- Vague 61 (a199) : At = moment visé depuis l'arrivée dans le tuto court (V0, calcul du rapport d'a199 : marche à
-- 32 studs/s avec le ×2 d'a198, vitrine de la zone 1 à 15 PV, dons des étapes 7 et 8, 10 s de tapis, pas d'attente du
-- bouclier ; fin vers 2 min 10 avec le message ProtectShop). Avant : 0, 15, 25, 45, 60, 120, 180, 240, 300, 600, 630,
-- 660, 690 et 675 s (plus de 11 min jusqu'au bout).
local Steps: { Step } = {
	{ Index = 1, Id = "ArriveAtPlot", At = 0, Goal = "Arrivée sur sa parcelle, flèche au sol vers la Supérette", Bubble = "Smash the Mini Mart window!" },
	{ Index = 2, Id = "HitWindow", At = 8, Goal = "Premiers coups aux poings sur la vitre (15 PV depuis la vague 61, environ 3,5 s)", Bubble = "Hit the glass again and again!" },
	{ Index = 3, Id = "GrabBox", At = 13, Goal = "Casse et chrono du braquage ; ouvrir un colis sur le rayon (chance ×1,5), le Pot de nouilles sort, le prendre ; vigile lent", Bubble = "Open a box on the shelf!" },
	{ Index = 4, Id = "PlaceBox", At = 21, Goal = "Ramener l'objet en zone safe (rangé sous antivol dans l'inventaire), le poser au sol de sa boutique", Bubble = "Bring the item back to your shop!" },
	{ Index = 5, Id = "DisplayItem", At = 29, Goal = "Antivol de 5 s, reprendre l'objet (en main), le poser sur un présentoir (5 $/s), premier encaissement", Bubble = "Display your item to earn cash!" },
	{ Index = 6, Id = "Train", At = 49, Goal = "Le tapis s'allume, TrainDuration (10 s, vague 61) d'entraînement guidé (plus de banc, v2)", Bubble = "Train on the treadmill" },
	{ Index = 7, Id = "BuyTool", At = 62, Goal = "Le jeu donne le prix de la clé à molette (ToolGift, vague 61), flèche vers la boutique d'armes, l'acheter", Bubble = "Buy the Wrench!" },
	{ Index = 8, Id = "BuyAura", At = 72, Goal = "Le jeu donne le prix de la première aura (AuraGift, vague 61), flèche vers la boutique d'auras, l'acheter", Bubble = "An aura multiplies your strength!" },
	{ Index = 9, Id = "GoToZone2", At = 82, Goal = "Objectif affiché : la zone 2 (Speed 3K, Strength 10), passer son arche", Bubble = "Next goal: Zone 2!" },
	-- Étape 10 : message de fin du bouclier débutant (texte du doc, voir ShieldEndMessage). Vague 61 : sans
	-- WaitShieldEnd, elle ne se joue plus (passage immédiat à l'étape 11, ou fin sans bot) ; gardée pour Tutorial.Step.
	{ Index = 10, Id = "ShieldEnd", At = 92, Goal = "Fin du bouclier débutant : l'objet qu'il porte peut tomber à la batte (vague 61 : plus attendue)", Bubble = nil },
	-- Vague 36 (L-085 point 4, a121) : le vol entre joueurs, sur la boutique du bot (BotService). Ajoutées à la
	-- fin, sans changer les numéros ni les Id d'avant (un Tutorial.Step sauvegardé garde son sens). Sautées
	-- sans bot sur le serveur : le tuto finit alors à l'étape 10, comme avant. V0 proposés, absents du doc
	-- (étapes, At, bulles). Vague 37 : le bot défend sa boutique (bulle BotChase des Hints) ; vague 38 : étape 14.
	{ Index = 11, Id = "GoToBotShop", At = 92, Goal = "Flèche vers la porte de la boutique du bot", Bubble = "Steal from another shop!" },
	{ Index = 12, Id = "StealFromBot", At = 102, Goal = "Casser la porte du bot et lui prendre un objet exposé", Bubble = "Break in and grab an item!" },
	{ Index = 13, Id = "BringStolenHome", At = 118, Goal = "Ramener l'objet volé dans sa boutique (dépôt PvPService), fin du tuto", Bubble = "Bring it back to your shop!" },
	-- Vague 38 (L-085 point 4, L-136 (a), a126) : « le bot défend ». Elle se joue ENTRE 12 et 13 (objet du bot pris
	-- pendant que le bot le poursuit, BotService.IsChasing), mais elle est ajoutée à la fin pour ne changer ni les
	-- numéros ni les Id d'avant (un Tutorial.Step sauvegardé garde son sens). Le bot semé (il ne le poursuit plus,
	-- objet toujours en main) : étape 13 ; frappé, l'objet revole chez le bot : étape 12. V0 proposés, absents du
	-- doc (At, bulle).
	{ Index = 14, Id = "EscapeBot", At = 114, Goal = "Le bot poursuit le joueur qui tient son objet : le semer avec l'objet, ou se le faire reprendre (retour à 12)", Bubble = "The bot fights back: escape with it!" },
}

-- Textes écrits dans le doc, traduits en anglais (L-036). ShieldEndMessage dépasse les 8 mots
-- d'une bulle. Depuis le 2026-11-12 (Cantin, doc 6.4), la boutique est braquable dès le départ : le
-- bouclier ne protège plus que le colis porté. Texte V0 d'Ironix, à valider par Clément (L-115).
local SHIELD_END_MESSAGE = "Beginner protection is over: keep your bat close!"
local NIGHT_BUBBLE = "Night is falling: hurry home!" -- 5.12, pour les nouveaux joueurs

-- Vague 60 (a197, T-099 : « je savais pas qu'est-ce qu'il fallait qu'on fasse, où on en était et pourquoi ») :
-- textes de la liste des tâches (TutorialController, Shared/TutorialTasks). Anglais, V0 proposés, absents du doc.
local TOOL_NAME = "Wrench" -- Tools.ById[ToolToBuy].DisplayName (étape 7 : la clé à molette, 300 $)
-- Vague 61 (a199) : dons des étapes 7 et 8 = le prix de la clé à molette et celui de l'aura la moins chère (Spark),
-- relus dans Config/Tools et Config/Cosmetics (300 $ et 100 $ depuis la vague 68). V0.
local WRENCH: Tools.Tool? = Tools.ById.Wrench
local TOOL_GIFT = if WRENCH then WRENCH.Price else 0
local AURA_GIFT = math.huge
local FIRST_AURA = "" -- vague 73 (a256) : Id de l'aura la moins chère (carte visée par UI_TutorialFocus à l'étape 8)
for _, aura in Cosmetics.Auras do
	if aura.Price < AURA_GIFT then
		AURA_GIFT = aura.Price
		FIRST_AURA = aura.Id
	end
end
local Todos: { [number]: Todo } = {
	[1] = { Do = "Smash the Mini Mart window" },
	[2] = { Do = "Keep hitting until the glass breaks" },
	[3] = { Do = "Open a box on the shelf, grab the item" },
	[4] = { Do = "Run back to your shop with it" },
	[5] = { Do = "Display it, then step on the green pad" },
	[6] = { Do = "Stand on the treadmill", Need = "Train {have} / {need}", NeedFormat = "Seconds" },
	[7] = { Do = "Go to the Weapon Shop and buy it", Need = "Earn cash: {have} / {need} to buy the " .. TOOL_NAME, NeedFormat = "Money" },
	[8] = { Do = "Go to the Aura Shop and buy one", Need = "Earn cash: {have} / {need} to buy an Aura", NeedFormat = "Money" },
	-- Vague 61 (a199) : plus de « Speed: 12 / 3K » à l'étape 9, lu comme une Speed à atteindre avant d'y aller (l'arche ne
	-- bloque pas). Avant : Need = "Speed: {have} / {need} to outrun Zone 2 guards", NeedFormat = "Short".
	[9] = { Do = "Walk through the Zone 2 gate" },
	[10] = { Do = "Keep stealing and earning cash", Need = "Beginner protection ends in {left}", NeedFormat = "Time" },
	[11] = { Do = "Go to the bot's shop" },
	[12] = { Do = "Break its door, grab an item" },
	[13] = { Do = "Run back to your shop with it" },
	[14] = { Do = "Run home, the bot is chasing you!" },
}
local Tasks: { Task } = {
	{ Id = "RobStore", Steps = { 1, 2, 3 }, Goal = "Rob the Mini Mart", Why = "Stolen items earn you cash" },
	{ Id = "BringHome", Steps = { 4 }, Goal = "Bring the item home", Why = "Items earn cash in your shop" },
	{ Id = "Display", Steps = { 5 }, Goal = "Display your item", Why = "Displayed items earn cash every second" },
	{ Id = "Train", Steps = { 6 }, Goal = "Train your Speed", Why = "Speed helps you escape the guards" },
	{ Id = "BuyTool", Steps = { 7 }, Goal = "Buy the " .. TOOL_NAME, Why = "A better tool breaks windows faster" },
	{ Id = "BuyAura", Steps = { 8 }, Goal = "Buy an Aura", Why = "An aura multiplies your strength" },
	{ Id = "Zone2", Steps = { 9 }, Goal = "Reach Zone 2", Why = "Zone 2 stores have better items" },
}
-- Vague 61 (a199) : sans attente du bouclier, l'étape 10 ne se joue plus : pas de tâche « Get ready for PvP ».
if WAIT_SHIELD_END then
	table.insert(Tasks, { Id = "Shield", Steps = { 10 }, Goal = "Get ready for PvP", Why = "Soon other players can bonk you" })
end
table.insert(Tasks, { Id = "RobBot", Steps = { 11, 12, 14 }, Goal = "Rob another shop", Why = "Anyone can rob anyone" })
table.insert(Tasks, { Id = "BringStolen", Steps = { 13 }, Goal = "Bring the stolen item home", Why = "Then it's yours!" })

local Tutorial = {
	-- V0 : interrupteur. false = aucun tutoriel : TutorialService ne pose aucune accroche, ne
	-- change aucun profil et n'envoie rien (ni bulle, ni flèche, ni funnel).
	Enabled = true,

	Steps = Steps,
	SkipFromStep = 5, -- bouton Passer à partir de l'étape 5 (TutorialSkip, 9.4)
	-- Vague 60 (a197, Cantin) : Passer saute UNE étape (la suivante devient l'étape en cours), plus tout le tuto.
	-- false = l'ancienne règle (Passer finit le tuto). V0.
	SkipOneStep = true,
	-- Vague 60 (a197, Cantin : « il ne faut pas que la flèche mène jusqu'à la vitrine ») : la flèche vise toujours la
	-- cible exacte de l'étape. true = l'ancienne règle (d'abord la porte de sa boutique quand on est de l'autre côté
	-- de ses murs). V0.
	ArrowViaDoor = false,

	-- Vague 60 (a197) : liste des tâches (TutorialController, Shared/TutorialTasks ; textes plus haut).
	-- false = pas de liste (ni panneau Tasks, ni ligne sous la bulle) : la bulle seule, comme avant. V0.
	TaskList = true,
	Todos = Todos,
	Tasks = Tasks,
	TasksAhead = 1, -- V0 : tâches à venir montrées après la tâche en cours
	TasksMax = 5, -- V0 : lignes au plus dans la liste (les plus anciennes tâches faites partent d'abord)
	SkipReplyTimeout = 3, -- V0 : s après Passer sans réponse du serveur, la bulle revient (client)
	BubbleMaxWords = 8,
	FirstStoreDistance = 60, -- flèche vers la Supérette, à 60 studs

	-- 5.11 : résultats garantis
	-- Vague 76 : plus de FirstBoxTier (les colis des rayons n'ont plus de type ; zone 1 : colis Communs, l'objet
	-- imposé reste le Pot de nouilles, Rare).
	GuardSpeed = 12, -- vigile lent du tuto
	-- Objet du premier colis (catalogue v2, L-045) : le Pot de nouilles, Rare de la zone 1, marqué
	-- TutorialOnly dans Config/Items : il ne sort d'aucun tirage, Items.Pick(1, "Rare") ne le donne
	-- pas. TutorialService le passe en ItemId à StoreHeistService.SetContentOverride (une Rarity
	-- seule tirerait dans la zone, où aucun Rare n'est tirable).
	-- a429 : Z1_RamenDeFeu avec le catalogue v3 (Features.ItemsV3, ItemsV3Dev).
	GuaranteedItemId = TUTORIAL_ITEM_ID,
	-- Vague 31 (L-112 ; a107). Le Pot de nouilles est l'objet SORTI du premier colis ouvert
	-- sur le rayon (SetContentOverride, appliqué à la sortie ; contenu imposé : aucun cran de rareté).
	-- V0 : chance imposée à l'ouverture du tuto (StoreHeistService.SetLuckOverride). ×1,5 plutôt que ×1 :
	-- le compteur « ×N LUCK » monte 1,4 s (rabats compris : 2 s), assez pour voir la mécanique et le « ? »
	-- des témoins bouger, jamais assez pour la police (×8 et plus) ; ×1 sortirait l'objet sans rien montrer.
	ShelfLuck = 1.5,
	-- V0 : antivol de l'objet du tuto posé au sol (UnboxService.GetAntiTheftDelay ; 20 s pour un Rare,
	-- ShelfOpen.AntiTheft) : les 5 s de l'attente raccourcie du premier colis d'avant (5.11).
	AntiTheftDelay = 5,

	-- Étapes 1 à 4 (section 3) : le braquage de la Supérette, en zone 1 (zone tuto, L-033).
	TutorialZone = 1, -- doc : tout magasin de cette zone compte (la Supérette ou le Kiosque)
	TargetStoreId = "Superette", -- doc : flèche vers la Supérette (STORE_Z1_Superette, Zones[1].StoreIds)
	-- V0 : un joueur des étapes 1 et 2 à cette distance (studs) d'une vitrine de la zone 1 ouverte passe
	-- à l'étape 3, même si c'est un autre joueur qui l'a cassée (même rayon que le chrono HeistTimer).
	StoreNearRadius = 60,
	-- Doc, section 3, étape 6 : « 30 s d'entraînement guidé » (au tapis ; plus de banc, v2). Vague 61 (a199, Cantin : tuto
	-- de 3 min au plus) : 10 s, V0 (on voit la Speed monter ; 30 avant).
	TrainDuration = 10,
	-- Vague 61 (a199, V0) : voir l'en-tête. WaitShieldEnd = false : l'étape 10 passe tout de suite (11 avec un bot, sinon
	-- fin) ; GiftCash : dons d'argent des étapes 7 et 8 (ToolGift, AuraGift), versés une seule fois par profil
	-- (Tutorial.Gifts), seulement s'il manque de quoi payer ; false = plus de don (l'attente d'avant).
	WaitShieldEnd = WAIT_SHIELD_END,
	GiftCash = true,
	ToolGift = TOOL_GIFT,
	AuraGift = AURA_GIFT,
	ToolToBuy = "Wrench", -- doc, étape 7 : la clé à molette (300 $, table 7.2) ; un outil plus fort compte aussi
	GoalZone = 2, -- doc, étape 9 : objectif la zone 2 (Speed 3K, Strength 10 : Wrench × Spark)
	MessageDuration = 8, -- V0 : secondes d'affichage de ShieldEndMessage avant la fin du tuto, puis de l'indice ProtectShop (vague 52)
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
		-- étape 5 (L-089) : objet libre dans l'inventaire (pas en main), rien d'exposé
		PlaceItem = "Open your inventory, then place your item!",
		CollectCash = "Step on the green pad to collect!", -- étape 5 (objet exposé), 7 et 8 (pas assez d'argent) ; V0 proposé (L-091 : plaques CollectPad_xx)
		-- étape 6, flèche vers le tapis : il n'a plus d'invite, on s'entraîne en s'arrêtant dessus (L-071)
		StandOnTreadmill = "Stand on the treadmill to train!",
		NightClosed = "The street opens again at dawn!", -- nuit, étapes 1 à 3 et 9, côté zone safe
		Night = NIGHT_BUBBLE, -- 5.12 : alerte et nuit, joueur dans le couloir
		ShieldEnd = SHIELD_END_MESSAGE, -- 6.4 : fin du bouclier débutant
		-- Vague 31 (L-112 ; a107), V0 proposés, absents du doc :
		WaitReveal = "Watch your luck go up!", -- étape 3 : son colis s'ouvre sur le rayon (flèche : le colis)
		GrabItem = "Grab your item and run!", -- étape 3 : son objet est sorti (flèche : l'objet)
		PlaceFloorItem = "Open your inventory, place it on the floor!", -- étapes 4 et 5 : objet sous antivol dans l'inventaire
		WaitUnlock = "Guard it until it is UNLOCKED!", -- étape 5 : objet au sol, antivol en cours (volable)
		-- Vague 52 (a169, V0 proposés, absents du doc) : depuis a152, l'objet repris du sol (« Take ») va en main ;
		-- TakeUnlocked : antivol fini, objet encore au sol (flèche : l'objet) ; DisplayUnlocked : objet en main
		-- (attribut HeldItem), à poser sur un présentoir libre (invite « Display » ; flèche : le présentoir).
		TakeUnlocked = "UNLOCKED! Take your item!",
		DisplayUnlocked = "Put it on a display!",
		-- Vague 37 (a124, V0 proposé, absent du doc) : étape 12, le bot poursuit le joueur (BotService.IsChasing) ; vague 38 :
		-- poursuivi avec l'objet, il passe à l'étape 14 (sa bulle), plus à 13 avec celle-ci
		BotChase = "The bot is chasing you: run!",
		-- Vague 52 (a169, L-163 : n'importe qui peut braquer n'importe qui ; textes V0, Clément valide ; plus de
		-- 8 mots, comme ShieldEndMessage). AnyoneCanRob : étape 12, porte du bot pas encore cassée (le nombre de
		-- coups est celui de la porte d'une boutique de joueur, PvP.DoorHits d'a159 : 40). ProtectShop : à la fin
		-- du tuto (bot volé et ramené, ou fin sans bot), affiché MessageDuration s avant de tout cacher.
		AnyoneCanRob = `Anyone can rob anyone: every shop door breaks in {PvP.DoorHits} hits!`,
		ProtectShop = "Protect your shop: Reinforced Door, Lock, Cameras!",
		-- Vague 61 (a199, Cantin : « expliquer qu'on te donne de l'argent pour ce tuto ») : étapes 7 et 8, le don versé
		-- (Tutorial.Gifts) et assez d'argent pour payer ; flèche vers la boutique. V0, 8 mots.
		ToolGift = `Here's ${TOOL_GIFT} for the tutorial: buy the {TOOL_NAME}!`,
		AuraGift = `Here's ${AURA_GIFT} for the tutorial: buy an Aura!`,
	} :: { [string]: string },

	-- Flèche au sol de Clément (UI-006, pas encore livrée) : noms proposés, pas encore au contrat. Cherchés
	-- dans ReplicatedStorage/Assets (sous-dossiers compris) ; tant qu'ils manquent, TutorialController
	-- fait une flèche V0. ArrowAsset : un Beam (texture, couleur, largeurs, défilement de Clément),
	-- copié entre les pieds du joueur et la cible. MarkerAsset : un Model ou une pièce, pivot en bas au
	-- centre, posé sur la cible.
	ArrowAsset = "FX_Tutorial_Arrow",
	MarkerAsset = "FX_Tutorial_Marker",
	-- Vague 73 (a256, L-242 point 5) : le repère de Clément rebondit comme le repère V0 (MarkerBob studs d'amplitude,
	-- période MarkerPeriod s ; V0 proposés, absents du doc, ceux du repère V0).
	MarkerBob = 0.5,
	MarkerPeriod = 1.2,
	MarkerBobClement = true, -- false : le repère de Clément reste posé sur la cible (comme avant la vague 73)

	-- Vague 73 (a256, L-242 point 5, UI_TutorialFocus de Clément ; Throw a Seed, section 6 de
	-- docs/claude/notes/2026-11-17_throw-a-seed-a-reprendre.md) : à l'étape où il faut cliquer un bouton d'une
	-- boutique, ce bouton est mis en avant (Focus posé sur lui, Margin px autour ; son UIStroke Veil, l'ancien voile, suit
	-- Veil), Ring l'entoure, et Pointer arrive après HesitateTime s sans clic. Écran absent ou bouton introuvable
	-- (carte pas visible, autre onglet) : rien. Enabled = false : jamais.
	Focus = {
		Enabled = true,
		Screen = "UI_TutorialFocus",
		HesitateTime = 1.2, -- note de Clément (L-242) : « 1,2 s dans la note »
		-- Vague 75 (L-262 point 2, Clément : « on ne grise pas les autres boutons », un encadré met en avant le bouton) :
		-- false = le UIStroke Focus.Veil de Clément est éteint, rien n'assombrit le reste. true : le voile de la vague 73.
		Veil = false,
		Margin = 6, -- V0 proposé, absent du doc : px entre le bouton et le bord de Focus
		-- Étape → écran, fin du nom de la carte (Tool_02_Wrench, Item_Spark) et bouton visé dans la carte. V0.
		Targets = {
			[7] = { Screen = "UI_WeaponShop", CardSuffix = "_Wrench", Button = "BuyButton" },
			[8] = { Screen = "UI_AuraShop", CardSuffix = "_" .. FIRST_AURA, Button = "BuyButton" },
		},
	},

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
		-- Vague 38 (a126, V0 proposé) : étape 14 du tuto, envoyée quand le joueur sème le bot avec son objet (14 → 13),
		-- donc avant le 13 : l'ordre des numéros ne suit pas celui du jeu (ajoutée à la fin, comme l'étape).
		"Bot semé avec son objet",
	},
}

export type Tutorial = typeof(Tutorial)

return DeepFreeze(Tutorial)
