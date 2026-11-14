--!strict
-- Contrôle des déplacements (Partie 1, sections 9.6 et 14.3 ; AntiCheatService, DEV-060 ;
-- interrupteur : Config/Features.AntiCheat). V0 prudente : un faux positif gâche la partie d'un
-- joueur honnête, donc chaque marge penche du côté du joueur.
-- Valeurs du doc (9.6) : lues dans Balance.AntiCheat, leur seule source (PvPService lit
-- CarrierPushFactor pour son contrôle du dépôt ; GuardService et BatService, CatchVerticalReach par
-- shared/CatchReach). Les autres : « V0 », proposées, absentes du doc, à
-- régler en jeu. Unités : secondes, studs, studs/s (comme une WalkSpeed).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)

local AntiCheat = {
	-- 9.6 : toutes les 0,25 s, la distance parcourue (à l'horizontale) est comparée à la vitesse
	-- autorisée × 1,25. 3 anomalies en 5 s : retour à la dernière position valide et colis rendu.
	CheckInterval = Balance.AntiCheat.CheckInterval, -- 0,25 s
	SpeedTolerance = Balance.AntiCheat.SpeedTolerance, -- × 1,25
	MaxAnomalies = Balance.AntiCheat.MaxAnomalies, -- 3 anomalies…
	AnomalyWindow = Balance.AntiCheat.AnomalyWindow, -- … en 5 s
	-- 9.6 : saut de plus de 30 studs entre deux contrôles = téléport. V0 : c'est un plancher, le seuil
	-- grandit avec la vitesse autorisée, l'intervalle réel et le retard du réseau (TeleportLag, Stale).
	TeleportDistance = Balance.AntiCheat.TeleportDistance,

	-- Vitesse autorisée = la plus haute Humanoid.WalkSpeed (celle que StatsService applique : trail,
	-- Adrénaline, malus de portage, étourdissement compris) des SpeedMemory dernières secondes : une
	-- baisse met un aller-retour réseau à arriver chez le client. V0.
	SpeedMemory = 2,
	-- V0 : jamais moins : un joueur étourdi ou sur une machine (vitesse 0) peut encore glisser un peu
	-- (les poussées des autres joueurs et des vigiles : PushRadius). Sous la WalkSpeed d'un porteur
	-- (12 avec un objet volé), sinon un speed hack × 2 passerait presque inaperçu en portant.
	MinSpeed = 10,
	-- V0 : réserve de distance gardée d'un contrôle à l'autre, en secondes de déplacement à la vitesse
	-- autorisée (× SpeedTolerance), plus SlackStuds : le réseau livre souvent les positions en rafale.
	-- Une rafale ne fait au plus qu'une anomalie (la réserve repart de 0).
	BurstSeconds = 1,
	SlackStuds = 4, -- V0 : petites corrections de position (marches, collisions)
	-- V0 : un saut est un téléport au-delà de vitesse autorisée × 1,25 × (intervalle + TeleportLag +
	-- temps figé) + SlackStuds, et jamais sous TeleportDistance.
	TeleportLag = 1,
	-- V0 : position figée alors que la vitesse répliquée du HumanoidRootPart dépasse StaleSpeed :
	-- c'est le réseau du joueur qui s'est arrêté, pas le joueur. Ce temps (au plus StaleMax) s'ajoute
	-- à la réserve et au seuil du téléport : la position qui revient d'un coup n'est pas prise pour un
	-- téléport.
	StaleSpeed = 2,
	StaleMax = 3,
	-- V0 : un autre joueur ou un vigile à PushRadius studs ou moins peut pousser : sa vitesse compte
	-- comme vitesse autorisée.
	PushRadius = 6,
	-- V0 proposé, absent du doc (audit du 2026-11-14) : un porteur (colis PNJ ou objet volé) n'est poussé
	-- par un autre joueur qu'à sa propre vitesse × CarrierPushFactor au plus (un complice rapide collé à lui
	-- ne lui ouvre plus sa vitesse) ; un vigile le pousse toujours à sa vitesse. Même plafond pour le
	-- contrôle du dépôt d'un objet volé (PvPService : Balance.Carry.StolenItemWalkSpeed × CarrierPushFactor).
	CarrierPushFactor = 1.5,

	-- Vol (audit du 2026-11-14), V0 proposés, absents du doc : à chaque contrôle, un rayon vers le bas
	-- sous le HumanoidRootPart. Plus de FlyHeight studs entre ses pieds et le sol (pièce qui bloque,
	-- terrain ou eau), sans tomber, pendant FlyTime s = détection « Fly » (ligne, retour au dernier point
	-- au sol hors de Studio, jamais d'expulsion). Un saut monte à environ 7,2 studs (L-140) et dure moins
	-- d'une seconde. « Tomber » : descendre en moyenne d'au moins FlyFallSpeed studs/s depuis le début du
	-- compte (le compte repart alors de 0). Position figée (le réseau s'est arrêté) : le compte attend, au
	-- plus StaleMax s ; un joueur immobile en l'air est donc vu après FlyTime + StaleMax s.
	FlyHeight = 12,
	FlyTime = 1.5,
	FlyFallSpeed = 4,

	-- Capture et coup de batte (GuardService, BatService ; shared/CatchReach), V0 proposé, absent du doc
	-- (audit du 2026-11-14) : la distance (CatchDistance, Bat.Range) se mesure à l'horizontale, avec au
	-- plus CatchVerticalReach studs d'écart en hauteur entre les deux HumanoidRootPart.
	CatchVerticalReach = 10,

	-- Déplacements faits par le code (AntiCheatService.Allow(player, secondes, raison)) : rien n'est
	-- contrôlé pendant la durée du déplacement + AllowSettle + ping × AllowPingFactor (au plus
	-- AllowPingMax), puis le contrôle repart de la nouvelle position. V0 : couvre l'aller-retour réseau
	-- (positions périmées que le client envoie encore) et l'élan après une poussée.
	AllowSettle = 1.5,
	AllowPingFactor = 2,
	AllowPingMax = 1,
	-- V0 : arrivée en retard d'un déplacement du code. Pendant LateArrival s après la fin d'un Allow,
	-- un saut qui dépasserait la réserve est accepté s'il mène à un point qu'on peut atteindre en
	-- marchant depuis la destination du code (le client vient enfin de recevoir le déplacement : à
	-- l'arrivée en jeu, la réplication de la carte le retarde de plusieurs secondes), et ignoré s'il
	-- ramène près du point de départ (positions d'avant encore en route). Vu le 2026-11-09 : 201 studs
	-- pris pour un téléport, 0,4 s après la fin de l'Allow du placement sur la parcelle.
	LateArrival = 10,
	SpawnGrace = 3, -- V0 : après chaque apparition d'un personnage (point d'apparition, puis parcelle)
	-- V0 : après un retour en arrière (fait par ce service), pendant RollbackGrace s (+ ping) seules
	-- les positions qu'on peut atteindre depuis le point du retour sont prises, sans contrôle ; les
	-- autres (positions d'avant encore en route) sont ignorées. Ensuite tout est contrôlé.
	RollbackGrace = 1.5,

	-- Sanctions V0 : une ligne dans la sortie (warn), le colis ou l'objet porté rendu
	-- (CarryService.ReportAnomaly) et retour à la dernière position valide. Jamais d'expulsion : les
	-- récidives sont seulement comptées (attribut StrikesAttribute du Player, journal).
	-- En Studio : détection et ligne seulement, sauf workspace:SetAttribute(StrictAttribute, true).
	StrictAttribute = "AntiCheatStrict",
	StrikesAttribute = "AntiCheatStrikes",
	LogSize = 50, -- V0 : dernières détections gardées (AntiCheatService.GetLog)
}

export type AntiCheat = typeof(AntiCheat)

return DeepFreeze(AntiCheat)
