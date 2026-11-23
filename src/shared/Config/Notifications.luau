--!strict
-- Notifications Roblox hors du jeu (Experience Notifications ; MAJ 7 de docs/claude/notes/feuille-de-route-maj.md,
-- Partie 2 section 5 « Notifications Roblox » ; vague GC6, a410). Lu par NotificationService (serveur : planning et
-- envoi) et NotificationController (client : demande de consentement, fenêtre au premier plan ou pas). Coupé par
-- Features.ExperienceNotifications.
--
-- Comment ça marche chez Roblox (doc vérifiée le 23/11) :
--   - consentement : le client appelle ExperienceNotificationService:CanPromptOptInAsync() puis PromptOptIn() ;
--     Roblox ne montre la fenêtre (texte fixe) ni aux moins de 13 ans, ni à qui a déjà accepté, ni à qui l'a vue
--     depuis moins de 30 jours. Le jeu ne sait pas qui a accepté : il envoie, Roblox ne livre qu'aux inscrits ;
--   - envoi : Open Cloud CreateUserNotification, POST https://apis.roblox.com/cloud/v2/users/<userId>/notifications,
--     appelé depuis le serveur par HttpService:RequestAsync (Open Cloud par HttpService, sans proxy) ; en-tête
--     x-api-key = HttpService:GetSecret(SecretName) (une clé d'API ne s'écrit jamais dans le code) ;
--   - limites : une notification par jour et par joueur pour ce jeu, livraison non garantie (liée à l'engagement),
--     jeu d'au moins 100 visites ; aucune fausse urgence ni récompense mensongère.
--
-- À régler dans le Creator Hub (rien ne part tant que ce n'est pas fait ; en Studio, StudioDryRun écrit l'envoi
-- dans la sortie au lieu de l'envoyer) :
--   1. Engagement > Notifications > « Create a Notification String », une par moment ci-dessous (texte proposé dans
--      Text, paramètres entre accolades), puis « Copy Asset ID » dans MessageId du moment ;
--   2. une clé d'API Open Cloud (au nom du groupe) avec le droit user.user-notification:write, limitée à ce jeu,
--      rangée dans les secrets du jeu sous le nom SecretName (Creator Hub > Secrets ; en Studio : Game Settings >
--      Security > Secrets) ;
--   3. Game Settings > Security : « Allow HTTP Requests » allumé.
--
-- Toutes les valeurs sont des V0 proposés (Cantin, 23/11), absentes du doc, sauf le moment « colis prêt » du doc
-- (Partie 2, section 5), remplacé ici par « boutique pleine » : un colis ne s'attend plus hors ligne (vague 50).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type MomentId = "OfflineFull" | "SaturdayEvent" | "ShopStolen"

export type Moment = {
	Id: string,
	-- Asset ID de la chaîne du Creator Hub ; "" = moment coupé (rien n'est planifié ni envoyé).
	MessageId: string,
	-- Texte à créer dans le Creator Hub (anglais, 99 caractères au plus) ; pour mémoire, le code ne l'envoie pas.
	Text: string,
}

local Moments: { [string]: Moment } = {
	-- Gains hors ligne au plafond (Config/Offline.MaxHours après le départ) : {amount} = Format.money de ce qui attend.
	OfflineFull = {
		Id = "OfflineFull",
		MessageId = "",
		Text = "Your shop is full! {amount} is waiting for you in {experienceName}.",
	},
	-- Rendez-vous du samedi (Config/LiveEvents.Weekly), LeadSeconds avant le début : {event} = nom du format.
	SaturdayEvent = {
		Id = "SaturdayEvent",
		MessageId = "",
		Text = "{event} starts soon in {experienceName}! Come join the fun.",
	},
	-- Objet volé dans la boutique pendant que la fenêtre du jeu n'est pas au premier plan : {item} = nom de l'objet.
	ShopStolen = {
		Id = "ShopStolen",
		MessageId = "",
		Text = "Someone stole your {item}! Come back and take it back.",
	},
}

local Notifications = {
	Moments = Moments,
	-- Nom du secret du jeu qui garde la clé d'API Open Cloud.
	SecretName = "OpenCloudNotifications",
	Url = "https://apis.roblox.com/cloud/v2/users/%d/notifications",
	-- Rendez-vous du samedi : notification envoyée tant de secondes avant le début.
	LeadSeconds = 10 * 60,
	-- Boutique volée : au plus une notification par joueur et par serveur dans ce délai (s).
	StolenCooldown = 60 * 60,
	-- File des notifications planifiées (MemoryStoreService, carte triée partagée par tous les serveurs) :
	-- clé « <moment>:<userId> », sortKey = heure d'envoi (Unix). Chaque serveur relit la file toutes les
	-- PollInterval s, au plus PollBatch lignes ; une ligne prise par un serveur lui reste ClaimSeconds s.
	MapName = "ExperienceNotifications_v1",
	PollInterval = 30,
	PollBatch = 50,
	ClaimSeconds = 120,
	-- Client : la demande de consentement s'ouvre après PromptDelay s de jeu, une fois par session.
	PromptDelay = 4 * 60,
	-- Studio : l'envoi est écrit dans la sortie au lieu de partir (aucun secret nécessaire).
	StudioDryRun = true,
	-- Studio seulement : workspace:SetAttribute(TestAttribute, "<moment> <joueur>") envoie ce moment tout de suite
	-- (barre de commande serveur ; joueur = nom ou UserId).
	TestAttribute = "NotificationTest",
}

export type Notifications = typeof(Notifications)

return DeepFreeze(Notifications)
