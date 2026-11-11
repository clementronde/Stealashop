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

-- V0 proposé, absent du doc : borne de sécurité du nombre de crans d'amélioration d'un colis
-- (6 = de Commun à Secret). La vraie limite est Config.Unbox.UpgradeMax (2).
local MAX_UPGRADES = 6

local function id(name: string): ArgSpec
	return { Name = name, Kind = "string", Max = MAX_ID_LENGTH }
end

local function index(name: string): ArgSpec
	return { Name = name, Kind = "int", Min = 1, Max = MAX_INDEX }
end

local List: { RemoteDef } = {
	-- Client vers serveur (tableau 9.4). Débits : doc quand il en donne, sinon V0.
	{
		Name = "HitWindow",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("windowId") },
		RatePerSecond = 10, -- doc 9.4 et 5.2 : ≤ 10 coups/s
	},
	{
		Name = "GrabItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("slotId") },
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
		Args = { index("plotIndex"), index("slotIndex") },
		RatePerSecond = 5, -- V0 proposé, absent du doc ; maintien vérifié par le service
	},
	{
		-- L-089 (2026-11-09) : boxUid = uid du colis de l'inventaire (Boxes du profil, montré par l'attribut
		-- InventoryState du Player depuis la vague 21) ; point = point du monde visé sur le sol de sa
		-- boutique. Le serveur cherche lui-même le sol sous ce point (Bounds de SA boutique, à portée, ni sur un colis, ni sur un présentoir, ni
		-- dans le décor). Avant : slotIndex d'un présentoir (L-086), d'un établi avant.
		Name = "PlaceBox",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("boxUid"), { Name = "point", Kind = "Vector3" } },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- L-089 : boxUid = uid d'un colis posé au sol de sa boutique (attribut BoxUid de son modèle).
		Name = "OpenBox",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("boxUid") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		-- L-089 : itemUid = un objet de l'inventaire, posé sur ce présentoir libre (depuis la vague 21, plus
		-- envoyé par le client : l'écran d'inventaire envoie PlaceItemAuto ; gardé pour un choix du présentoir).
		Name = "PlaceItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid"), index("slotIndex") },
		RatePerSecond = 5, -- V0 proposé, absent du doc
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
		Args = { id("dropId") },
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
	},
	{
		-- Ajout du 2026-11-07 (DEV-031), absent du tableau 9.4 : bouton EquipButton de
		-- UI_WeaponShop. ShopService vérifie que l'outil existe et qu'il est possédé.
		Name = "EquipTool",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("toolId") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
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
		Name = "HeistTimer",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { id("storeId"), { Name = "endsAt", Kind = "number", Min = 0 } },
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
	{
		-- L-089 : boxUid = uid du colis posé au sol dont l'attente est finie (avant : slotIndex).
		Name = "BoxReady",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { id("boxUid") },
	},
	{
		-- Seulement après OpenBox : l'identité de l'objet n'est jamais envoyée avant (5.7).
		-- Ouverture v2 (DEV-050, 2026-11-07) : itemId = l'objet final, après l'amélioration du
		-- colis ; zone et tier = ceux du colis (composition du rouleau, revenu du Secret) ;
		-- startRarity = la rareté du colis avant amélioration ; upgrades = le nombre de crans
		-- réussis, chacun monte d'une rareté (le client en déduit les raretés des crans).
		-- Mutations (DEV-131, L-084) : mutationSize et mutationEffect = Id de Config/Mutations de
		-- l'objet ouvert (nom et revenu de l'écran d'ouverture), nil sans mutation dans la famille.
		-- L-089 : boxUid = uid du colis ouvert, posé au sol (avant : slotIndex d'un présentoir) ; l'objet
		-- va dans l'inventaire.
		Name = "UnboxReveal",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			id("boxUid"),
			id("itemUid"),
			id("itemId"),
			{ Name = "zone", Kind = "int", Min = 1, Max = MAX_INDEX },
			id("tier"),
			id("startRarity"),
			{ Name = "upgrades", Kind = "int", Min = 0, Max = MAX_UPGRADES },
			{ Name = "mutationSize", Kind = "string", Max = 32, Optional = true },
			{ Name = "mutationEffect", Kind = "string", Max = 32, Optional = true },
		},
	},
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
	{
		-- Ajout de la vague 24 (L-095 point 4), absent du tableau 9.4 : le colis volé du joueur vient d'être
		-- mis à l'abri en zone safe (UnboxService, rangé dans l'inventaire). tier = Tier du colis (Standard,
		-- Premium, Luxe). UiFeelController joue l'arrivée en zone safe (UI_Escape, SafeFlash) avec
		-- l'icône ICON_BOX_<tier>. Rien de sensible : effet visuel du seul joueur concerné.
		Name = "BoxSecured",
		Direction = "ServerToClient",
		Reliable = true,
		Args = {
			{ Name = "tier", Kind = "string", Max = 16 },
		},
	},
}

return {
	List = List,
}
