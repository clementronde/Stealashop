--!strict
-- Liste unique de tous les remotes du jeu (DEV-002, section 9.4 du doc).
-- ReplicatedStorage/Shared/Net/Definitions, lue par Net (serveur et client).
--
-- Une entrée par remote :
--   Name          nom du remote (le serveur et le client le trouvent par ce nom)
--   Direction     "ClientToServer" ou "ServerToClient"
--   Reliable      false = UnreliableRemoteEvent (peut se perdre, pour les flux fréquents)
--   Args          types attendus des arguments, dans l'ordre (voir ArgSpec)
--   RatePerSecond client → serveur seulement : appels acceptés par joueur sur
--                 toute seconde glissante ; au-delà, l'appel est ignoré
--   Jitter        facultatif (vague 40) : débit régulier. Le remote passe RatePerSecond appels par seconde sur
--                 la durée, et un appel peut arriver jusqu'à Jitter / RatePerSecond s en avance sur ce rythme
--                 sans être perdu (seau à jetons de RateLimiter, au lieu de la fenêtre glissante)
--   Budget        facultatif (a276) : nom d'un budget de Budgets (plus bas), partagé avec d'autres remotes. Un
--                 appel qui passe son débit et la forme des arguments prend aussi un jeton dans ce budget du
--                 joueur ; budget vide : appel ignoré (refus « Budget »)
--
-- Net ne contrôle que la forme des appels (nombre, types, bornes, débit). Les
-- règles de jeu de la colonne « Le serveur vérifie » (distance, outil équipé,
-- recharge, argent…) restent dans les services.
--
-- Ajouter ou renommer un remote : le faire ici, puis mettre à jour la section 9.4
-- du doc partagé dans le même tour.

-- "string" : chaîne UTF-8 valide de longueur Min (défaut 1) à Max (obligatoire)
-- "int"    : nombre entier fini, entre Min et Max s'ils sont donnés
-- "number" : nombre fini (ni NaN ni infini), entre Min et Max s'ils sont donnés
-- "boolean", "Vector3" (composantes finies), "Player", "Instance"
export type ArgKind = "string" | "int" | "number" | "boolean" | "Vector3" | "Player" | "Instance"

export type ArgSpec = {
	Name: string, -- nom lisible, repris dans les messages d'erreur
	Kind: ArgKind,
	Optional: boolean?, -- nil accepté ; seulement pour les derniers arguments
	Min: number?,
	Max: number?,
}

export type Direction = "ClientToServer" | "ServerToClient"

export type RemoteDef = {
	Name: string,
	Direction: Direction,
	Reliable: boolean,
	Args: { ArgSpec },
	RatePerSecond: number?,
	Jitter: number?,
	Budget: string?,
}

-- a276 (vague GC2, faille F1 de l'audit a272) : budget partagé par plusieurs remotes client → serveur (champ
-- Budget d'une entrée). Seau à jetons par joueur : RatePerSecond jetons rendus par seconde, Burst au plus en réserve.
export type BudgetDef = {
	RatePerSecond: number,
	Burst: number,
}

local Budgets: { [string]: BudgetDef } = {
	-- Remotes qui créent, déplacent ou détruisent un modèle répliqué aux autres clients (Tool en main, objet sur un
	-- présentoir ou au sol, outil, émetteurs d'aura). Chacun a son propre débit (1 à 5 par seconde), mais en les
	-- mêlant un client en faisait ~20 par seconde. V0 proposé (Cantin, 23/11) : 3 par seconde sur la durée, 6 d'un
	-- coup après un temps calme. Un joueur normal fait un ou deux gestes par seconde ; la réserve de 6 laisse passer
	-- une rafale de touches 1 à 6 de la barre ou six objets posés à la suite. Equip Best compte pour un seul appel.
	Models = { RatePerSecond = 3, Burst = 6 },
}

-- V0 proposé, absent du doc : longueur maximale d'un identifiant envoyé par le
-- client (windowId, slotId, itemUid…). Un GUID fait 36 à 38 caractères.
local MAX_ID_LENGTH = 64

-- V0 proposé, absent du doc : borne de sécurité des numéros d'établi et de
-- présentoir. Ce n'est pas la règle de jeu : le service vérifie la vraie limite
-- (20 présentoirs max en V1, section 5.8 ; établis selon les améliorations).
local MAX_INDEX = 100

-- V0 proposé, absent du doc : longueur maximale d'un message Notify.
local MAX_MESSAGE_LENGTH = 200

local function id(name: string): ArgSpec
	return { Name = name, Kind = "string", Max = MAX_ID_LENGTH }
end

local function index(name: string): ArgSpec
	return { Name = name, Kind = "int", Min = 1, Max = MAX_INDEX }
end

-- a265 (vague 79) : étape OBLIGATOIRE d'un maintien d'invite, en dernier argument (GrabItem, OpenShelfBox, StealItem,
-- StealFloorItem, GrabDropped) : "Begin" au début de l'appui, "End" à la fin, "Cancel" au relâché avant la fin. Le
-- service refuse toute autre valeur ; un "Begin" rouvre toujours le maintien à zéro. Un appel sans étape est refusé
-- (le serveur ne déduit jamais l'étape de son état : un client qui l'omettait retrouvait l'ancien défaut).
local function holdPhase(): ArgSpec
	return { Name = "phase", Kind = "string", Max = 8 }
end

local List: { RemoteDef } = {
	-- Client vers serveur (tableau 9.4). Débits : doc quand il en donne, sinon V0.
	{
		Name = "HitWindow",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("windowId") },
		-- 5 coups par seconde au plus, pour tout le monde et toutes les cibles (Cantin, 2026-11-14 ; avant : 10).
		-- Garder égal à Config/Balance.Hit.MaxHitsPerSecond (un banc le vérifie).
		RatePerSecond = 5,
		-- V0 proposé, absent du doc : débit régulier. Le client envoie un coup toutes les 0,2 s exactement ;
		-- un coup arrivé jusqu'à 0,1 s en avance (écarts du réseau) passe quand même, sans dépasser 5 coups par
		-- seconde sur la durée. Sans cela, des coups se perdent et un joueur au plafond tombe sous les 4,42
		-- coups par seconde qu'il faut pour casser une vitrine à son niveau (Config/Zones).
		Jitter = 0.5,
	},
	{
		Name = "GrabItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("slotId"), holdPhase() },
		RatePerSecond = 5, -- V0 proposé, absent du doc ; maintien vérifié par le service
	},
	{
		-- Ajout de la vague 10 (DEV-041, 2026-11-08), absent du tableau 9.4 : prise d'un objet exposé
		-- dans la boutique d'un autre joueur, porte cassée (6.1). plotIndex = attribut PlotIndex de la
		-- parcelle, slotIndex = numéro du présentoir (DisplaySlot_xx). Deux appels, comme GrabItem :
		-- début du maintien, puis fin (PvP.StealGrabTime). Un remote à part de GrabItem : les règles
		-- (protections 6.4, coffre-fort, transfert sûr) sont celles de PvPService, pas du braquage PNJ.
		Name = "StealItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { index("plotIndex"), index("slotIndex"), holdPhase() },
		RatePerSecond = 5, -- V0 proposé, absent du doc ; maintien vérifié par le service
	},
	{
		-- Vague 52 (a170) : depuis la fin du colis porté (a158), boxUid = uid d'un objet sous antivol de
		-- l'inventaire (Items du profil, AntiTheft) ; le nom du remote et de l'argument restent. point = point du
		-- monde visé sur le sol de sa boutique. Le serveur cherche lui-même le sol sous ce point (Bounds de SA
		-- boutique, à portée, ni sur un autre objet posé, ni sur un présentoir, ni dans le décor).
		Name = "PlaceBox",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("boxUid"), { Name = "point", Kind = "Vector3" } },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- Vague 52 (a170) : boxUid = uid d'un objet posé au sol de sa boutique, débloqué (attribut ItemUid du
		-- modèle FloorItem) : le serveur le reprend (a152 : en main, sinon dans l'inventaire).
		Name = "OpenBox",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("boxUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- L-089 : itemUid = un objet de l'inventaire, posé sur ce présentoir libre (depuis la vague 21, plus
		-- envoyé par le client : l'écran d'inventaire envoie PlaceItemAuto ; gardé pour un choix du présentoir).
		Name = "PlaceItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid"), index("slotIndex") },
		RatePerSecond = 5, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- Ajout de la vague 18 (L-089, L-079 : bouton Equip Best de l'écran d'inventaire de Clément, à
		-- venir), absent du tableau 9.4 : les objets qui rapportent le plus vont sur les présentoirs
		-- débloqués (DisplayService, règle V0 dans son en-tête). Aucun argument : le serveur décide tout.
		Name = "EquipBest",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 1, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- Ajout de la vague 21 (L-079, L-091 point 6 : écran UI_Inventory, bouton PlaceButton d'un objet),
		-- absent du tableau 9.4 : itemUid = un objet de l'inventaire (attribut InventoryState du Player),
		-- posé sur le présentoir libre et débloqué le plus proche, sinon le premier libre. InventoryService
		-- vérifie tout (objet à lui, ni exposé, ni au coffre-fort, ni volé ; un présentoir libre).
		Name = "PlaceItemAuto",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- Ajout de la vague 21 (bouton UnequipButton d'un objet exposé de UI_Inventory), absent du tableau
		-- 9.4 : itemUid = un objet exposé, qui retourne dans l'inventaire. InventoryService vérifie tout
		-- (objet à lui et exposé, pas tenu par un voleur, de la place dans l'inventaire).
		Name = "UnplaceItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		Name = "SwingBat",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 3, -- V0 proposé, absent du doc ; la recharge de 0,8 s (9.4) reste au PvPService
	},
	{
		Name = "GrabDropped",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("dropId"), holdPhase() },
		RatePerSecond = 5, -- V0 proposé, absent du doc
	},
	{
		Name = "BuyItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("catalogId") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		Name = "EquipCosmetic",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("cosmeticId") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- Ajout du 2026-11-07 (DEV-031), absent du tableau 9.4 : bouton EquipButton de
		-- UI_WeaponShop. ShopService vérifie que l'outil existe et qu'il est possédé.
		Name = "EquipTool",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("toolId") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		Name = "TrainTap",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 6, -- doc 9.4 : ≤ 6 taps/s au tapis ; le ≤ 3/s du banc reste au TrainingService
	},
	{
		Name = "ReturnToBase",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 1, -- V0 proposé, absent du doc ; la recharge de 90 s (9.4) reste au service
	},
	{
		Name = "TutorialSkip",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 1, -- V0 proposé, absent du doc
	},
	{
		-- Ajout de la vague 19 (DEV-101, 2026-11-09), absent du tableau 9.4 : bouton DailyClaimButton de
		-- UI_Rewards. Aucun argument : RewardService décide du jour (heure du serveur, minuit UTC) et de la
		-- récompense (Config/Rewards) ; une seule réclamation par jour UTC.
		Name = "ClaimDaily",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 2, -- V0 proposé, absent du doc
	},
	{
		-- Ajout de la vague 19 (DEV-101) : ClaimButton d'un palier de temps de jeu de UI_Rewards. minutes =
		-- le palier (Config/Rewards.Playtime : 5, 15, 30, 60) ; RewardService vérifie qu'il existe, que le
		-- temps de jeu du jour (compté par le serveur) l'atteint et qu'il n'est pas déjà réclamé.
		Name = "ClaimPlaytime",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { { Name = "minutes", Kind = "int", Min = 1, Max = 1440 } },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- Ajout de la vague 22 (L-092 3f, DEV-102), absent du tableau 9.4 : bouton ClaimButton de l'écran
		-- UI_Offline. Aucun argument : OfflineService verse ce qui attend dans le profil (Offline.Pending),
		-- puis le remet à 0 ; rien en attente : rien versé (jamais deux fois).
		Name = "ClaimOffline",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 2, -- V0 proposé, absent du doc
	},

	-- Serveur vers client (9.4). Le doc ne donne que les noms (et « id, point
	-- d'impact » pour WindowBroken) : les arguments ci-dessous sont des V0
	-- proposés, absents du doc, à ajuster par le service qui les envoie. Le
	-- serveur n'est pas contrôlé en jeu ; en Studio, Net avertit si un envoi ne
	-- respecte pas ces types.
	{
		-- Non fiable, 10 Hz max (9.4, 9.7) : c'est WindowService qui tient la cadence.
		Name = "WindowHP",
		Direction = "ServerToClient",
		Reliable = false,
		Args = {
			id("windowId"),
			{ Name = "hp", Kind = "number", Min = 0 },
			{ Name = "maxHp", Kind = "number", Min = 0 },
		},
	},
	{
		Name = "WindowBroken",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { id("windowId"), { Name = "impactPoint", Kind = "Vector3" } },
	},
	{
		-- Chaque coup validé (liaison L-028 a, DEV-016), pour que chacun voie les fissures des autres :
		-- point = point de frappe calculé par le serveur ; hitter = le joueur qui a frappé (son client
		-- a déjà joué son retour local). Envoyé par WindowService au frappeur et aux joueurs proches
		-- (Config.Shatter.HitBroadcastRadius). Non fiable : un coup perdu ne coûte qu'une fissure et
		-- un chiffre.
		-- Ajout de la vague 12 (DEV-053, 2026-11-08) : damage = dégâts du coup appliqués par le serveur
		-- (ToolService.GetHitDamage), pour le chiffre de dégâts flottant (DamageNumberController).
		-- WindowHit part désormais pour chaque coup validé, celui qui casse compris (avant
		-- WindowBroken), et sur toute cible : vitrine de magasin PNJ, porte de boutique, cible
		-- d'événement (camion, dont TruckController joue le son du coup). Un coup refusé n'envoie rien.
		Name = "WindowHit",
		Direction = "ServerToClient",
		Reliable = false,
		Args = {
			id("windowId"),
			{ Name = "point", Kind = "Vector3" },
			{ Name = "hitter", Kind = "Player", Optional = true },
			{ Name = "damage", Kind = "number", Min = 0, Optional = true }, -- toujours envoyé ; facultatif car après hitter
		},
	},
	{
		-- endsAt = workspace:GetServerTimeNow() de fin du chrono ; 0 = masquer le chrono.
		-- Ajout de la vague 40 (Cantin, 2026-11-14) : police = true pour le chrono de police (lancé au premier
		-- coup sur une vitrine de magasin PNJ, WindowService, « POLICE IN 8s ») ; absent = chrono « HEIST »
		-- d'après la casse (StoreHeistService). Même identifiant de magasin : le dernier reçu remplace l'autre.
		Name = "HeistTimer",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			id("storeId"),
			{ Name = "endsAt", Kind = "number", Min = 0 },
			{ Name = "police", Kind = "boolean", Optional = true },
		},
	},
	{
		-- active = poursuite en cours ; guard = modèle du vigile (nil à la fin).
		Name = "ChaseState",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "active", Kind = "boolean" },
			{ Name = "guard", Kind = "Instance", Optional = true },
		},
	},
	{
		-- Envoyé à la victime : active = vol en cours ; thief et itemId nil à la fin. Envoyé par
		-- PvPService à la prise de l'objet (true, voleur, ItemId) et à la fin du vol (false).
		-- Plusieurs vols en même temps chez la même victime (DEV-042, 2026-11-08) : juste après chaque
		-- false, TheftAlertService renvoie (true, voleur, ItemId) pour chaque vol encore en cours, du
		-- plus ancien au plus récent ; TheftAlertController garde l'alerte ouverte sur le dernier.
		Name = "TheftAlert",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "active", Kind = "boolean" },
			{ Name = "thief", Kind = "Player", Optional = true },
			{ Name = "itemId", Kind = "string", Max = MAX_ID_LENGTH, Optional = true },
		},
	},
	-- Vague 52 (a170) : BoxReady et UnboxReveal (colis posé puis ouvert en base) retirés.
	{
		-- Guidage du tuto (DEV-046, TutorialService) : step = étape en cours, 0 = plus de tuto (tout
		-- cacher) ; hint = clé de Config.Tutorial.Hints à afficher à la place de la bulle de l'étape
		-- (nil = la bulle de l'étape) ; target = point visé par la flèche au sol (nil = pas de flèche).
		Name = "TutorialStep",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "step", Kind = "int", Min = 0, Max = MAX_INDEX },
			{ Name = "hint", Kind = "string", Max = 32, Optional = true },
			{ Name = "target", Kind = "Vector3", Optional = true },
			-- Vague 60 (a197, liste des tâches) : progression de l'étape (have sur need : argent, secondes de tapis,
			-- Speed, temps de bouclier), nil sans progression ; Shared/TutorialTasks en fait le texte.
			{ Name = "have", Kind = "number", Optional = true },
			{ Name = "need", Kind = "number", Optional = true },
		},
	},
	{
		-- Ajout de la vague 21 (L-091 points 4 et 5), absent du tableau 9.4 : un joueur vient de ramasser
		-- l'argent d'une plaque de sa boutique. Envoyé à tous les clients (DisplayService) : plotIndex =
		-- attribut PlotIndex de la parcelle, slotIndex = numéro de la plaque (CollectPad_xx), amount = $
		-- ramassés. DisplayController fait la gerbe de BurstPoint et prévient OnCollect chez le propriétaire.
		Name = "CashCollect",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			index("plotIndex"),
			index("slotIndex"),
			{ Name = "amount", Kind = "number", Min = 1 },
		},
	},
	{
		-- kind : catégorie libre pour le style du message (ex. "Info", "Warning").
		Name = "Notify",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "message", Kind = "string", Max = MAX_MESSAGE_LENGTH },
			{ Name = "kind", Kind = "string", Max = 32, Optional = true },
		},
	},
	{
		-- Ajout de la vague 23 (L-095 point 2), absent du tableau 9.4 : le joueur enregistre ses réglages
		-- (écran UI_Settings, SettingsController), tous à la fois, une fois qu'il a fini de les changer.
		-- music et sfx = volumes de 0 à 1, vfx = effets visuels complets, click = Id d'un son de clic
		-- (SettingsService vérifie qu'il est dans Config/Settings.Clicks). Rien de sensible : la sauvegarde
		-- ne touche que le champ Settings du profil.
		Name = "SaveSettings",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {
			{ Name = "music", Kind = "number", Min = 0, Max = 1 },
			{ Name = "sfx", Kind = "number", Min = 0, Max = 1 },
			{ Name = "vfx", Kind = "boolean" },
			{ Name = "click", Kind = "string", Max = 16 }, -- Config/Settings.MaxClickLength
		},
		RatePerSecond = 4, -- V0 proposé, absent du doc (Config/Settings.SaveRate) ; le client attend 0,5 s entre deux envois
	},
	-- Vague 52 (a170) : BoxSecured (colis porté mis à l'abri) retiré ; l'objet a ItemSecured.
	{
		-- Ajout de la vague 25 (retour du Play de Cantin du 2026-11-11), absent du tableau 9.4 : le joueur a
		-- rangé sa barre du bas UI_Hotbar (HotbarController, glisser-déposer). slot1 à slot6 = identifiant de
		-- chaque case, dans l'ordre (Shared/HotbarLayout) : "Tool", "Bat", uid d'un colis ou d'un objet, ou ""
		-- pour une case vide ; 6 au plus (un 7e argument est refusé par Net), absent = vide. HotbarService
		-- vérifie que chaque uid est à ce joueur et qu'aucun n'est en double ; refusé, rien ne change. Rien
		-- de sensible : la sauvegarde ne touche que le champ Hotbar du profil.
		Name = "SetHotbar",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {
			{ Name = "slot1", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
			{ Name = "slot2", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
			{ Name = "slot3", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
			{ Name = "slot4", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
			{ Name = "slot5", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
			{ Name = "slot6", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
		},
		RatePerSecond = 4, -- V0 proposé, absent du doc ; le client regroupe ses envois (0,5 s)
	},
	{
		-- Ajout de la vague 27 (arbre de compétences, L-096 point 2), absent du tableau 9.4 : achète le niveau
		-- suivant de la compétence `id` (Config/SkillTree). SkillTreeService vérifie que l'Id existe, que la tuile
		-- est ouverte, que le niveau est codé (Coded) et pas au maximum, et l'argent (prix du serveur) ; refusé,
		-- rien ne change. Le niveau revient au client par l'attribut Skill_<Id> du joueur.
		Name = "BuySkill",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {
			{ Name = "id", Kind = "string", Min = 1, Max = 32 },
		},
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- Ajout de la vague 27 (arbre de compétences, Cameras niveau 2), absent du tableau 9.4 : envoyé par
		-- SkillTreeService au seul propriétaire d'une boutique dont la vitrine est frappée par `attacker`.
		-- CameraAlertController surligne l'attaquant à travers les murs jusqu'à endsAt (heure serveur,
		-- Workspace:GetServerTimeNow). Rien de sensible : effet visuel du seul propriétaire.
		Name = "CameraSpotted",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "attacker", Kind = "Player" },
			{ Name = "endsAt", Kind = "number", Min = 0 },
		},
	},
	{
		-- Vague 28 (potions, L-085), absent du tableau 9.4 : une potion personnelle apparaît pour ce joueur seul
		-- (Config/Potions) : uid de la potion, Id du type (« Speed »…), position au sol.
		Name = "PotionSpawned",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { id("uid"), id("potionId"), { Name = "position", Kind = "Vector3" } },
	},
	{
		-- Vague 28 : la potion `uid` de ce joueur disparaît (ramassée, expirée, retirée).
		Name = "PotionRemoved",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { id("uid") },
	},
	{
		-- Vague 28 : le joueur ramasse sa potion `uid`. PotionService vérifie qu'elle est à lui, encore là, et
		-- à Config/Potions.PickupMaxDistance studs au plus ; refusé, rien ne change.
		Name = "PickPotion",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("uid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- Vague 29 (receleur, DEV-034 ; L-106 point 4, L-107 point 2), absent du tableau 9.4 : le joueur est monté
		-- sur la plaque ShopPad du stand taggé PawnShop et demande ce que le receleur lui offre. PawnShopService
		-- vérifie le profil et la distance au stand (Config/Pawn.Reach), puis répond par PawnOffer.
		Name = "PawnAsk",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 4, -- V0 proposé, absent du doc ; le client regroupe ses demandes
	},
	{
		-- Vague 29 : l'offre du receleur, calculée par le serveur. heldUid et heldItemId = l'objet « tenu en
		-- main » (V0 : le dernier objet obtenu de l'inventaire, ni exposé ni au coffre-fort), "" s'il n'y en a pas
		-- (ou pendant un portage) ; heldPrice = son prix ; allCount et allPrice = les objets de l'inventaire hors
		-- objets exposés, et leur prix total. Prix = Config/Pawn.PriceFactor × $/s de l'objet (DEV-034).
		Name = "PawnOffer",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "heldUid", Kind = "string", Min = 0, Max = MAX_ID_LENGTH },
			{ Name = "heldItemId", Kind = "string", Min = 0, Max = MAX_ID_LENGTH },
			{ Name = "heldPrice", Kind = "number", Min = 0 },
			{ Name = "allCount", Kind = "int", Min = 0 },
			{ Name = "allPrice", Kind = "number", Min = 0 },
		},
	},
	{
		-- Vague 29 : vendre l'objet tenu. itemUid = celui de la dernière PawnOffer (ce que le joueur a vu et
		-- confirmé). PawnShopService vérifie la distance, l'absence de portage, que l'objet est à lui et qu'il est
		-- encore l'objet tenu (sinon refus : rien ne change), recalcule le prix, puis répond par PawnSold.
		Name = "PawnSellHeld",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 2, -- V0 proposé, absent du doc
	},
	{
		-- Vague 29 : vendre tout l'inventaire (hors objets exposés). count = le nombre d'objets confirmé par le
		-- joueur (« 9 items for $2.1M. Deal? ») : si l'inventaire n'a plus ce nombre d'objets, refus (rien ne
		-- change). Le serveur recalcule chaque prix, puis répond par PawnSold.
		Name = "PawnSellAll",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { { Name = "count", Kind = "int", Min = 1, Max = 200 } }, -- Config/Pawn.MaxSellAll
		RatePerSecond = 2, -- V0 proposé, absent du doc
	},
	{
		-- Vague 29 : résultat d'une vente au receleur. count = objets vendus, amount = argent versé (déjà crédité) ;
		-- count = 0 : vente refusée (inventaire changé entre l'offre et la vente, portage), rien n'a changé. Suivi
		-- d'une nouvelle PawnOffer.
		Name = "PawnSold",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "amount", Kind = "number", Min = 0 },
			{ Name = "count", Kind = "int", Min = 0 },
		},
	},
	{
		-- Vague 29 (panel admin, L-108 point 4), absent du tableau 9.4 : une commande de Config/Admin.Commands.
		-- target = joueur visé (absent = soi) ; value, text et text2 = arguments de la commande (Config/Admin).
		-- AdminService refuse tout appelant qui n'est pas admin, toute commande inconnue, et revalide chaque
		-- argument (bornes, Id de Config, cible présente sur le serveur).
		Name = "AdminCommand",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {
			{ Name = "commandId", Kind = "string", Max = 32 },
			{ Name = "target", Kind = "Player", Optional = true },
			{ Name = "value", Kind = "number", Min = 0, Max = 1e15, Optional = true },
			{ Name = "text", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
			{ Name = "text2", Kind = "string", Min = 0, Max = MAX_ID_LENGTH, Optional = true },
		},
		RatePerSecond = 5, -- V0 proposé, absent du doc
	},
	{
		-- Vague 29 : réponse d'AdminService au seul admin qui a envoyé la commande (UI_Admin.Root.StatusLabel).
		Name = "AdminResult",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "commandId", Kind = "string", Max = 32 },
			{ Name = "ok", Kind = "boolean" },
			{ Name = "message", Kind = "string", Max = MAX_MESSAGE_LENGTH },
		},
	},
	{
		-- Vague 31 (L-112) : lancer l'ouverture d'un colis du rayon. Deux appels, comme GrabItem
		-- (Cantin, 2026-11-13) : début du maintien, puis fin (GrabTime du type du colis). slotId = même format
		-- que GrabItem (attribut SlotId du colis). StoreHeistService décide de
		-- tout (magasin ouvert, joueur dedans, colis fermé, témoins) et tire la chance. Même forme que GrabItem.
		Name = "OpenShelfBox",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("slotId"), holdPhase() },
		RatePerSecond = 5, -- V0 proposé, absent du doc (comme GrabItem)
	},
	{
		-- Vague 31 (L-112, agent a105), absent du tableau 9.4 : prise d'un objet sous antivol posé au sol de la
		-- boutique d'un autre joueur (UnboxService), porte cassée. plotIndex = attribut PlotIndex de la parcelle,
		-- itemUid = attribut ItemUid du modèle FloorItem. Deux appels, comme StealItem : début du maintien, puis
		-- fin (PvP.StealGrabTime). PvPService vérifie tout (mêmes règles que StealItem, antivol encore en cours).
		Name = "StealFloorItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { index("plotIndex"), id("itemUid"), holdPhase() },
		RatePerSecond = 5, -- V0 proposé, absent du doc ; maintien vérifié par le service
	},
	{
		-- Vague 33 (demande de Cantin du 2026-11-13), absent du tableau 9.4 : le joueur boit une potion de son
		-- inventaire (champ PotionStock du profil). PotionService vérifie l'Id (Config/Potions), le profil, le
		-- stock (≥ 1) et le personnage vivant ; effet du même type déjà actif : la durée s'ajoute (cumul).
		-- Refusé, rien ne change.
		Name = "UsePotion",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("potionId") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- Vague 33 (Cantin, 2026-11-13, agent a113), absent du tableau 9.4 : lâcher ce qu'on porte au-dessus de la
		-- tête (touche G ou bouton Drop, DropController). Aucun argument : DropService vérifie tout (portage, personnage
		-- vivant, pas étourdi) et CarryService.Drop pose l'objet au sol sous le joueur.
		Name = "DropCarried",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 2, -- V0 proposé, absent du doc
	},
	{
		-- Agent a115 (Cantin, 2026-11-13), absent du tableau 9.4 : le joueur bouge (touche de déplacement ou
		-- joystick) sur le tapis : il en descend (TrainingController). Aucun argument : TrainingService finit
		-- seulement la séance de tapis en cours de ce joueur (rien hors séance, rien au banc).
		Name = "TrainLeave",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- Vague 34 (L-127 point 2, agent a117), absent du tableau 9.4 : réclamer la prime d'une zone complète de
		-- l'Index. zone = la zone visible (Rewards.ClaimButton de UI_Index_v3) ; absente = toutes les zones
		-- complètes pas encore réclamées, en une demande (UnlockedBar.ClaimAllButton). IndexService revérifie
		-- tout d'après le profil (index ouvert, zone complète, pas déjà réclamée) et note chaque prime avant de
		-- la verser (jamais deux fois). Rien à réclamer : rien ne change.
		Name = "ClaimIndexReward",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { { Name = "zone", Kind = "int", Min = 1, Max = MAX_INDEX, Optional = true } },
		RatePerSecond = 2, -- V0 proposé, absent du doc (comme ClaimDaily)
	},
	{
		-- Agent a142 (Cantin, 2026-11-14), absent du tableau 9.4 : mettre en main un objet de l'inventaire choisi
		-- dans la barre du bas (InventoryController.HoldItem). HeldItemService revérifie tout (objet à lui, ni
		-- exposé, ni au coffre-fort, ni tenu par un voleur, ni au sol ; pas de portage) ; le ranger ne passe pas
		-- par ici (le client range le Tool, le serveur le détruit). Rien de sensible : le Tool n'est qu'un visuel.
		Name = "HoldItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- Vague 46 (Cantin, 2026-11-14, agent a154), absent du tableau 9.4 : l'objet sorti d'un colis que portait le
		-- joueur vient d'être mis à l'abri en zone safe (UnboxService, rangé sous antivol). UiFeelController joue
		-- l'arrivée en zone safe (UI_Escape) avec l'icône et le nom de l'objet. Rien de sensible : l'objet est déjà
		-- révélé (porté au-dessus de sa tête, BB_Item), effet visuel du seul joueur concerné.
		Name = "ItemSecured",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { id("itemId") },
	},
	{
		-- Vague 44 (a152, Cantin, 2026-11-14), absent du tableau 9.4 : invite « Take » (touche E) sur un objet
		-- exposé de SA boutique (DisplayController) : il quitte son présentoir pour l'inventaire (barre du bas si
		-- une case est libre). InventoryService revérifie tout (objet à lui et exposé, pas tenu par un voleur,
		-- personnage vivant à portée du présentoir, de la place dans l'inventaire).
		Name = "TakeDisplayItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- a162 (MAJ 0), absent du tableau 9.4 : champ de saisie d'un code cadeau (UI_Settings ou UI_Rewards,
		-- CodeController). CodeService compare à Config/Codes, vérifie la fin et le code déjà pris, donne et note.
		Name = "RedeemCode",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { { Name = "code", Kind = "string", Max = 20 } }, -- Config/Codes.MaxLength
		RatePerSecond = 1, -- V0 proposé, absent du doc
	},
	{
		-- a162 (MAJ 0) : réponse à RedeemCode, au seul joueur. status = Redeemed, Invalid, AlreadyUsed, Expired ou
		-- Unavailable ; message = texte anglais de Config/Codes.Messages.
		Name = "CodeResult",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "status", Kind = "string", Max = 32 },
			{ Name = "message", Kind = "string", Max = MAX_MESSAGE_LENGTH },
		},
	},
	{
		-- Vague 51 (a164, DEV-120), absent du tableau 9.4 : le joueur confirme sa renaissance (2e appui sur
		-- UI_Rebirth.ConfirmButton, RebirthController). level = la renaissance confirmée (faites + 1) : une
		-- demande en retard ou en double est ignorée. RebirthService revérifie tout (Features.Rebirth, argent,
		-- objet requis, rien au sol, rien de porté ni de volé) ; coupé, le remote est ignoré.
		Name = "Rebirth",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { { Name = "level", Kind = "int", Min = 1, Max = 1000 } },
		RatePerSecond = 1, -- V0 proposé, absent du doc
	},
	{
		-- Agent a159 (L-163, décision de Clément du 2026-11-14), absent du tableau 9.4 : le propriétaire verrouille
		-- sa boutique (tuile Curtain devenue Lock, invite de ShopLockController sur sa porte). Aucun argument :
		-- SkillTreeService retrouve sa boutique et décide de tout (porte intacte, pas déjà verrouillée, recharge
		-- finie, durée selon son niveau).
		Name = "LockShop",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 2, -- V0 proposé, absent du doc
	},
	{
		-- Agent a166 (MAJ 1, DEV-101 ; Partie 2, 3.3), absent du tableau 9.4 : bouton WeeklyClaimButton de
		-- UI_Rewards. Aucun argument : RewardService vérifie que le coffre est allumé (Features.WeeklyChest),
		-- les 5 jours de connexion de la semaine (comptés par le serveur) et qu'il n'est pas déjà réclamé.
		Name = "ClaimWeekly",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 2, -- V0 proposé, absent du doc (comme ClaimDaily)
	},
	{
		-- Vague 59 (a192, L-184 point 1), absent du tableau 9.4 : la capture mise en scène, au coup du vigile (marqueur
		-- Impact de Catch, ou délai de secours ; arrestation de nuit : à son début), envoyée au seul joueur attrapé par
		-- GuardService. Rien de sensible : la capture est décidée. outcome = "Shelf", "Drop" ou "None" ; homeIn =
		-- secondes avant le renvoi à la base (0 : pas de renvoi) ; itemId = l'objet porté, s'il y en avait un.
		Name = "CatchScene",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "night", Kind = "boolean" },
			{ Name = "outcome", Kind = "string", Max = 8 },
			{ Name = "homeIn", Kind = "number", Min = 0, Max = 60 },
			{ Name = "itemId", Kind = "string", Max = MAX_ID_LENGTH, Optional = true },
			-- a252 (L-244) : le modèle de celui qui attrape (vigile, policier, conducteur), pour le plan large de la caméra.
			{ Name = "by", Kind = "Instance", Optional = true },
		},
	},
	{
		-- Vague 62 (a202, a204 ; L-198), absent du tableau 9.4 : la cinématique d'ouverture d'un colis, à TOUS les
		-- clients (tout le monde la voit). Rien de sensible : le tirage est fait et ne change plus. opener = qui ouvre
		-- (sa caméra joue la cinématique, il est protégé par le serveur) ; shopId = StoreId du magasin ; slotName = le
		-- rayon (« ShelfSlot_03 », ou le SlotId « <StoreId>/03 ») ; mutation = mutation d'effet (« » sans) ; weight en
		-- kg ; scale = taille finale du modèle (Shared/ItemWeight.ScaleFor) ; sizeClass = « Small », « Large » ou
		-- « Colossal » (ItemWeight.SizeClassFor) ; revealId = id de cette cinématique (RevealEnded, RevealDone).
		Name = "RevealStarted",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "opener", Kind = "Player" },
			id("shopId"),
			id("slotName"),
			id("itemId"),
			{ Name = "rarity", Kind = "string", Max = 32 },
			{ Name = "mutation", Kind = "string", Min = 0, Max = 32 },
			{ Name = "weight", Kind = "number", Min = 0, Max = 1_000_000 },
			{ Name = "scale", Kind = "number", Min = 0, Max = 100 },
			{ Name = "sizeClass", Kind = "string", Max = 16 },
			id("revealId"),
			-- Vague 73 (a251, L-236) : plan de la nouvelle ouverture (Shared/UnboxPlan : actions, rareté montrée après chacune,
			-- cote finale), tiré par le serveur ; absent : la cinématique d'avant.
			{ Name = "plan", Kind = "string", Min = 0, Max = 256, Optional = true },
		},
	},
	{
		-- Vague 62 (a202, a204 ; L-198) : fin de la cinématique revealId, à tous les clients (RevealDone de
		-- l'ouvreur, plafond RevealMaxSeconds, départ ou mort de l'ouvreur) ; l'objet est alors sur sa tête.
		Name = "RevealEnded",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { id("revealId") },
	},
	{
		-- Vague 62 (a202, a204 ; L-198) : l'ouvreur a vu sa cinématique jusqu'au bout (marqueur Land, ou fin du
		-- repli). Le serveur n'accepte que l'ouvreur de cette cinématique, une fois ; sinon il attend son plafond.
		Name = "RevealDone",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("revealId") },
		RatePerSecond = 2, -- V0 proposé, absent du doc
	},
	{
		-- Vague 63 (a206, L-192 Q3, L-202 point 4), absent du tableau 9.4 : DisplayButton d'un objet de la réserve
		-- (UI_Displayed.Panel.Reserve) : itemUid va sur le présentoir libre et débloqué le plus proche. DisplayService
		-- vérifie tout (objet de SA réserve, ni exposé, ni au coffre-fort, ni sous antivol ; sa parcelle ; un présentoir
		-- libre et débloqué, sinon Notify « No free display » et rien ne bouge).
		Name = "PlaceFromReserve",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc (comme PlaceItemAuto)
		Budget = "Models", -- a276 : budget « modèles » partagé (Budgets plus haut)
	},
	{
		-- a314 (L-292, L-271), absent du tableau 9.4 : SellButton d'une ligne de UI_Displayed (objet exposé ou de la
		-- réserve) : le client demande le prix de vente à montrer dans la confirmation. PawnShopService le calcule
		-- (même prix qu'au comptoir du receleur) et répond par DisplayedSellPrice.
		Name = "DisplayedSellAsk",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- a314 : réponse à DisplayedSellAsk. sellable = false : l'objet ne peut pas se vendre (price = 0).
		Name = "DisplayedSellPrice",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			id("itemUid"),
			{ Name = "price", Kind = "number", Min = 0 },
			{ Name = "sellable", Kind = "boolean" },
		},
	},
	{
		-- a314 : YesButton de la confirmation : vendre cet objet. PawnShopService vérifie tout (objet à lui, règles du
		-- receleur sauf la distance ; exposé : retiré de son présentoir, pas tenu par un voleur), recalcule le prix,
		-- retire l'objet et verse l'argent dans la même exécution (une seule vente par objet), puis répond par
		-- DisplayedSold.
		Name = "DisplayedSell",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- a314 : résultat de DisplayedSell. sold = false : refusée, rien n'a changé (amount = 0).
		Name = "DisplayedSold",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			id("itemUid"),
			{ Name = "amount", Kind = "number", Min = 0 },
			{ Name = "sold", Kind = "boolean" },
		},
	},
	{
		-- Vague 64 (a214, bulles ×N du tapis ; Config/Bubbles), absent du tableau 9.4 : une bulle apparaît pour le seul
		-- joueur en séance sur le tapis. Rien de sensible : la valeur est tirée par le serveur, qui seul verse le gain.
		-- lifetime = secondes avant qu'elle disparaisse (Bubbles.Lifetime).
		Name = "BubbleSpawn",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			id("bubbleId"),
			{ Name = "multiplier", Kind = "int", Min = 1, Max = 1000 },
			{ Name = "lifetime", Kind = "number", Min = 0, Max = 60 },
		},
	},
	{
		-- Vague 64 (a214) : la bulle bubbleId s'en va. reason = « Claimed » (prise : gain = Vitesse versée), « Expired »
		-- (personne ne l'a prise à temps) ou « Cleared » (le joueur a quitté le tapis).
		Name = "BubbleGone",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			id("bubbleId"),
			{ Name = "reason", Kind = "string", Max = 16 },
			{ Name = "gain", Kind = "number", Min = 0, Optional = true },
		},
	},
	{
		-- Vague 64 (a214) : clic sur une bulle. BubbleService vérifie tout (bulle à lui, pas expirée, pas déjà prise,
		-- joueur toujours sur le tapis, Bubbles.ClaimMinGap) et calcule le gain lui-même.
		Name = "ClaimBubble",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("bubbleId") },
		RatePerSecond = 4, -- V0 proposé, absent du doc (au plus 2 bulles à la fois, une toutes les 2 à 3 s)
	},
	{
		-- Vague 73 (a254, L-240 point 3 ; Shared/Announce, AnnounceController), absent du tableau 9.4 : une annonce à
		-- tout le serveur dans UI_Announce. message en RichText (balises <font>), detail = petite ligne, icon = noms de
		-- Decals séparés par « | » (vide : l'icône de Clément), plain = message sans balises (repli Notify du client).
		Name = "Announce",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "message", Kind = "string", Max = 400 },
			{ Name = "detail", Kind = "string", Min = 0, Max = 120 },
			{ Name = "icon", Kind = "string", Min = 0, Max = 160 },
			{ Name = "plain", Kind = "string", Max = MAX_MESSAGE_LENGTH },
		},
	},
	{
		-- Vague 80 (a266, DEV-132), absent du tableau 9.4 : bouton ClaimButton d'une ligne de UI_Quests. slot = place de la
		-- quête (1 à Config/Quests.PerDay) ; QuestService vérifie qu'elle est finie et pas réclamée, puis donne la récompense.
		-- Aucune progression ne vient du client.
		Name = "ClaimQuest",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { { Name = "slot", Kind = "int", Min = 1, Max = 3 } },
		RatePerSecond = 2, -- V0 proposé (Cantin, 20/11), comme ClaimDaily
	},
	{
		-- Vague 80 (a266, DEV-141), absent du tableau 9.4 : SpinButton de UI_Wheel. Aucun argument : WheelService vérifie
		-- qu'un tour est permis (gratuit du jour, sinon un tour en plus), tire le secteur et donne le lot.
		Name = "SpinWheel",
		Direction = "ClientToServer",
		Reliable = true,
		Args = {},
		RatePerSecond = 1, -- V0 proposé (Cantin, 20/11)
	},
	{
		-- Vague 80 (a266, DEV-141) : résultat d'un tour, au seul joueur qui a tourné, déjà donné. sector = secteur tiré
		-- (1 à 8, Config/Wheel.Sectors) ; message = le lot (anglais). Le client anime la roue jusqu'à ce secteur.
		Name = "WheelResult",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "sector", Kind = "int", Min = 1, Max = 8 },
			{ Name = "message", Kind = "string", Min = 0, Max = MAX_MESSAGE_LENGTH },
		},
	},
	{
		-- Vague GC6 (a410, MAJ 7), absent du tableau 9.4 : la fenêtre du jeu passe au premier plan (true) ou le quitte
		-- (false) (NotificationController). NotificationService n'en tire qu'une chose : un objet volé dans la boutique
		-- d'un joueur hors du premier plan lui est signalé par une notification Roblox. Rien d'autre ne le lit.
		Name = "ReportFocus",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { { Name = "focused", Kind = "boolean" } },
		RatePerSecond = 2, -- V0 proposé (Cantin, 23/11)
	},
}

return {
	List = List,
	Budgets = Budgets,
}
