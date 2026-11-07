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
		Name = "PlaceBox",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { index("benchIndex") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		Name = "OpenBox",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { index("benchIndex") },
		RatePerSecond = 4, -- V0 proposé, absent du doc
	},
	{
		Name = "PlaceItem",
		Direction = "ClientToServer",
		Reliable = true,
		Args = { id("itemUid"), index("slotIndex") },
		RatePerSecond = 5, -- V0 proposé, absent du doc
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
		-- Chaque coup validé qui ne casse pas la vitre (liaison L-028 a, DEV-016), pour que chacun
		-- voie les fissures des autres : point = point de frappe calculé par le serveur ; hitter =
		-- le joueur qui a frappé (son client a déjà joué son retour local). Envoyé par WindowService
		-- au frappeur et aux joueurs proches (Config.Shatter.HitBroadcastRadius). Non fiable : un
		-- coup perdu ne coûte qu'une fissure.
		Name = "WindowHit",
		Direction = "ServerToClient",
		Reliable = false,
		Args = {
			id("windowId"),
			{ Name = "point", Kind = "Vector3" },
			{ Name = "hitter", Kind = "Player", Optional = true },
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
		-- Envoyé à la victime : active = vol en cours ; thief et itemId nil à la fin.
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
		Name = "BoxReady",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { index("benchIndex") },
	},
	{
		-- Seulement après OpenBox : l'identité de l'objet n'est jamais envoyée avant (5.7).
		Name = "UnboxReveal",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { index("benchIndex"), id("itemUid"), id("itemId") },
	},
	{
		Name = "TutorialStep",
		Direction = "ServerToClient",
		Reliable = true,
		Args = { { Name = "step", Kind = "int", Min = 0, Max = MAX_INDEX } },
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
}

return {
	List = List,
}
