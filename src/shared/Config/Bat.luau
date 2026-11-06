--!strict
-- La batte, slot 2 (Partie 1, sections 6.2, 6.4 et 9.4).
-- Usage 1 : le propriétaire frappe le voleur de sa boutique (même en zone safe).
-- Usage 2 : n'importe qui frappe un porteur de colis PNJ hors zone safe ; le colis tombe au sol.
-- Un objet volé à un joueur ne tombe jamais au sol : il revole vers le présentoir de son propriétaire.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Bat = {
	DisplayName = "Batte",
	Asset = "TOOL_Batte", -- V0 proposé, absent du doc : nom dérivé de la convention 10.3, à confirmer avec Clément
	HotbarSlot = 2,

	-- Le coup, identique pour les deux usages ; un seul coup réussi suffit
	Range = 7,
	Cooldown = 0.8,
	StunDuration = 2, -- voleur ou porteur étourdi 2 s
	HitImmunity = 3, -- 6.4 : immunité aux coups de batte après en avoir reçu un

	-- Knockback du porteur de colis (usage 2) : force absente du doc
	KnockbackHorizontalSpeed = 40, -- V0 proposé, absent du doc : studs/s, dans le sens du coup
	KnockbackVerticalSpeed = 20, -- V0 proposé, absent du doc : studs/s vers le haut

	-- Colis au sol après un coup (usage 2)
	DroppedLifetime = 15, -- sans être ramassé, il retourne sur son rayon d'origine
	DroppedGrabTime = 0.5, -- prise en 0,5 s, mains vides, quel que soit le type de colis
	DroppedGrabMaxDistance = 8, -- GrabDropped (9.4)
}

export type Bat = typeof(Bat)

return DeepFreeze(Bat)
