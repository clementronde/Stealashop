--!strict
-- Interrupteurs à chaud (a442, 25/11 ; check-up a417 P5, condition de la décision C2 de Cantin du 24/11) : rallumer
-- ou éteindre un interrupteur de Config/Features en PROD sans republier. Logique : Shared/LiveFeatures ; commande
-- d'admin : server/Services/LiveFeaturesService. Toutes les valeurs sont V0 proposées (2026-11-25), absentes du doc.
--
-- Où se règle un interrupteur en ligne : Creator Hub > le jeu > Configs, une clé booléenne KeyPrefix .. <Nom>
-- (« Feature_ChaseV3 » = true ou false), publiée. Clé absente : la valeur du fichier Config/Features. DEV et PROD
-- sont deux jeux : chacun a ses propres clés.

local DeepFreeze = require(script.Parent.DeepFreeze)

local LiveFeatures = {
	-- false = le fichier seul, comme avant a442 (ni ConfigService, ni attributs, ni commande d'admin).
	Enabled = true,
	-- Clé de ConfigService d'un interrupteur : KeyPrefix .. son nom dans Config/Features, de type booléen.
	KeyPrefix = "Feature_",
	-- Serveur : attente maximale de la première lecture de ConfigService au démarrage, avant que les services ne
	-- lisent leurs interrupteurs. Au-delà : le fichier ; la réponse tardive ne vaut que pour les interrupteurs de Hot.
	BootWaitSeconds = 5,
	-- Client : attente maximale de l'état posé par le serveur (attribut ReadyAttribute du module Config/Features).
	ClientWaitSeconds = 10,
	-- Serveur : nouvel essai de ConfigService après une erreur de lecture.
	RetrySeconds = 60,
	-- Attribut du module Config/Features posé par le serveur quand son état est prêt (les clients l'attendent).
	ReadyAttribute = "LiveFeaturesReady",
	-- Interrupteurs qui changent sur un serveur déjà lancé (ConfigService ou commande d'admin) : lus seulement au
	-- moment de l'action, côté serveur comme côté client (inventaire d'a442). Tous les autres prennent la valeur de
	-- ConfigService au prochain serveur : ils sont lus au chargement d'un module ou dans Init / Start, et un
	-- changement en cours de route laisserait le client et le serveur, ou deux services, en désaccord.
	-- Ajouter un nom ici seulement après avoir vérifié que chaque lecture se fait au moment de l'action.
	Hot = {
		DenounceRecover = true, -- DisguiseService, à la capture par la police
		HeistPartnerBonus = true, -- StoreHeistService, à la rentrée en base de l'objet
		IndexMutations = true, -- IndexController, à l'affichage de l'index
		ShopGlassThrow = true, -- GlassThrowService.IsEnabled, au coup du propriétaire
		ShopGlassThrowDev = true,
		BatFreePvP = true, -- a503 : BatService, à chaque coup de batte (règle, immunité, ragdoll)
		BatFreePvPDev = true,
		GuardScale = true, -- a518 : GuardService, à l'apparition de chaque vigile (Guard/Scale)
		GuardScaleDev = true,
		GuardDayPatrol = true, -- a518 : GuardService, à chaque image (Guard/DayPatrol : ronde posée ou retirée)
		GuardDayPatrolDev = true,
		GuardCatchRagdoll = true, -- a518 : GuardService, à chaque capture par un vigile de magasin (Guard/CatchRagdoll)
		GuardCatchRagdollDev = true,
	} ::{ [string]: boolean },
	-- Qui peut se servir de la commande d'admin : la même règle que le panneau admin (AdminService.IsAdmin, réglée
	-- dans Config/Admin : tout le monde en Studio, Admin.UserIds, rang Admin.MinGroupRank du groupe du studio) ; pas
	-- de liste à part ici (décision du 25/11).
	-- Commande de chat : « /feature » (état), « /feature <Nom> on|off » (surcharge de ce serveur), « /feature <Nom> reset ».
	ChatAlias = "/feature",
	-- Textes du jeu (anglais), montrés au seul admin (remote Notify).
	Messages = {
		NotAdmin = "Not allowed.",
		ServerOnly = "Server only.",
		Unknown = "Unknown switch: %s",
		NotHot = "%s changes on the next server only (Creator Hub > Configs).",
		BadValue = "Use: /feature <Name> on|off|reset",
		Set = "%s = %s on this server (admin).",
		Cleared = "%s back to %s (%s).",
		Off = "Live switches are off.",
	},
}

export type LiveFeatures = typeof(LiveFeatures)

return DeepFreeze(LiveFeatures)
