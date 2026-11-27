--!strict
-- La batte, slot 2 (Partie 1, sections 6.2, 6.4 et 9.4). Lu par BatService (serveur), ToolService
-- (la batte donnée à chaque apparition), BatController (client), CarryService et TruckEventService
-- (colis au sol).
-- Usage 1 : le propriétaire frappe le voleur de sa boutique (même en zone safe).
-- Usage 2 : n'importe qui frappe un porteur de colis PNJ hors zone safe ; le colis tombe au sol.
-- Un objet volé à un joueur ne tombe jamais au sol : il revole vers le présentoir de son propriétaire.
-- a503 (Features.BatFreePvP / …Dev) : hors zone safe, n'importe qui frappe n'importe qui, sans immunité, en ragdoll.
-- Valeurs sans mention : celles du doc. « V0 » : V0 proposé, absent du doc, à régler en jeu.
-- Unités : secondes, studs, studs/s, degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Bat = {
	DisplayName = "Bat",
	Asset = "TOOL_Batte", -- modèle de Clément (convention 10.3), nom confirmé le 2026-11-07 (MOD-027)
	HotbarSlot = 2,

	-- Le coup, identique pour les deux usages ; un seul coup réussi suffit
	Range = 7, -- entre les HumanoidRootPart du frappeur et de la cible, mesuré par le serveur
	Cooldown = 0.8,
	StunDuration = 2, -- voleur ou porteur étourdi 2 s
	HitImmunity = 3, -- 6.4 : immunité aux coups de batte après en avoir reçu un
	FrontHalfAngle = 60, -- V0 : « devant le frappeur » = à 60° au plus de son regard, à l'horizontale (cône de 120°)
	PointBlankRange = 3, -- V0 : plus près que ça (à l'horizontale), la cible est touchée quel que soit l'angle
	ImpactMaxWait = 0.3, -- V0 : le coup part au marqueur Impact de SwingBat, au plus tard 0,3 s après le clic (comme les vitrines)

	-- Knockback du porteur de colis (usage 2) : force absente du doc
	KnockbackHorizontalSpeed = 40, -- V0 proposé, absent du doc : studs/s, dans le sens du coup
	KnockbackVerticalSpeed = 20, -- V0 proposé, absent du doc : studs/s vers le haut
	KnockbackDuration = 0.15, -- V0 : durée de la poussée (celle du coup du vigile)

	-- a503 (décision de Cantin du 26/11) : PvP libre à la batte dans le couloir, sous Features.BatFreePvP (PROD) ou
	-- Features.BatFreePvPDev (jeu DEV). Hors zone safe, n'importe qui frappe n'importe qui (usage « Free » : cible qui
	-- ne porte rien), plus d'immunité après un coup (HitImmunity ignorée), et chaque coup dans le couloir éjecte la
	-- cible en ragdoll (mécanique de la référence « Steal an Egg », docs/references/Poursuite.md) : poussée dans le
	-- sens du coup, vers le haut, RagdollAirTime s en l'air, couchée, relevée RagdollTime s après le coup, assommée
	-- jusqu'à StunDuration. Une cible déjà au sol ou assommée par la batte ne se refrappe pas. Coupé : comme avant.
	RagdollAirTime = 0.45, -- V0 proposé (Cantin, 26/11) : temps de vol jusqu'à la hauteur de départ, sur sol plat ; couché, le corps finit ≈ 0,04 s plus bas (référence : 0,45 à 0,5 s en l'air)
	RagdollBackSpeed = 20, -- V0 proposé (Cantin, 26/11) : studs/s à l'horizontale dans le sens du coup (≈ 10 studs en l'air)
	RagdollTime = 2, -- V0 proposé (Cantin, 26/11) : du coup au relevé, à la fin de StunDuration (référence : relevé 2 à 2,5 s après le coup)
	RagdollWallMargin = 2, -- V0 proposé (Cantin, 26/11) : la poussée s'arrête à 2 studs d'un mur ou d'un plafond (rayon)
	-- Articulations du ragdoll : celles de Config/GlassThrow (RagdollUpperAngle, RagdollTwist), même module Shared/Ragdoll.

	-- Colis au sol après un coup (usage 2)
	DroppedLifetime = 15, -- sans être ramassé, il retourne sur son rayon d'origine
	DroppedGrabTime = 0.5, -- prise en 0,5 s, mains vides, quel que soit le type de colis
	DroppedGrabMaxDistance = 8, -- GrabDropped (9.4)
	GrabActionText = "Grab", -- V0 : invite d'un colis tombé au sol, au-dessus de « Premium Box » (comme le camion)

	-- Son du coup qui touche (vague 26, ui-feel-sons-victoire-camion.md : « à jouer quand le serveur
	-- confirme un coup ») : Sound de Clément dans Assets/Sounds, joué en 3D sur la cible par chaque
	-- client quand l'attribut BatStun de la cible apparaît (posé par BatService à chaque coup réussi).
	HitSound = "SwingBat_Hit",

	-- Messages lus par le joueur (Notify), en anglais (L-036)
	Messages = {
		-- Vague 50 (a158) : ce qui tombe est un objet (le colis porté n'existe plus) ; les clés gardent leur nom.
		BoxKnockedDown = "You got hit! Your item fell to the ground.", -- V0 : au porteur frappé (usage 2)
		TargetShielded = "Beginner shield: you can't knock their item down yet.", -- V0 : au frappeur (6.4)
		TargetShieldedFree = "Beginner shield: you can't hit them yet.", -- a503, V0 : au frappeur, cible qui ne porte rien
	},
}

export type Bat = typeof(Bat)

return DeepFreeze(Bat)
