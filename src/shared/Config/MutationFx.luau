--!strict
-- Effets des mutations côté client (liaison L-127 point 5, a119) : réglages de MutationFxController.
-- Le design (couleurs, particules, doubles, mouvements, styles du texte) est à Clément, dans Studio :
-- ReplicatedStorage/Assets/FX/Mutations/FX_Mutation_<Id> et Assets/UI/MutationStyles/<Id>. Ici, seulement
-- quand et à quelle distance le code les joue.
--
-- Toutes les valeurs sont des V0 proposés, absents du doc, à faire valider par Clément.
-- Unités : studs, secondes.

local DeepFreeze = require(script.Parent.DeepFreeze)

local MutationFx = {
	-- Plus loin de la caméra, l'objet garde ses couleurs et sa matière (posées une fois), mais ses
	-- particules, sa lumière, ses doubles et son arc-en-ciel sont retirés et rien n'est animé (9.7, pour le
	-- mobile) : comme les objets animés d'ItemIdleController (80 studs).
	MaxDistance = 80, -- V0 : studs
	DistanceCheckInterval = 0.25, -- V0 : secondes entre deux tris par distance (et contrôles des objets)
	-- Couleurs animées (Rainbow, Pulse) et mouvements du texte : au plus ce nombre de fois par seconde.
	PaintRate = 30, -- V0 : images par seconde
	-- Un objet n'est habillé que quand son échelle n'a pas bougé entre deux contrôles (l'objet sorti sur le
	-- rayon grandit de 0,2 à 1 à la révélation, ShelfOpenController) : il est alors à sa taille finale.
	-- Tant que ses pièces arrivent ou changent d'échelle, il attend.
	SettleChecks = 1, -- V0 : contrôles (DistanceCheckInterval) d'échelle stable avant l'habillage
	-- Texte (MutationStyles) : « Shine » balaie le dégradé en ce temps, toutes les MotionPeriod s (Clément).
	ShineTime = 0.6, -- L-127 (Clément)
	-- « Glitch » du texte : saut de l'Offset X de ±GlitchTextOffset pendant GlitchTextTime s, toutes les
	-- 0,5 à 1,2 × MotionPeriod s (Clément).
	GlitchTextOffset = 0.3, -- L-127 (Clément)
	GlitchTextTime = 0.08, -- L-127 (Clément)
	-- « Pulse » du texte : transparence des contours entre 0 et cette valeur (Clément).
	PulseStrokeTransparency = 0.4, -- L-127 (Clément)
}

export type MutationFx = typeof(MutationFx)

return DeepFreeze(MutationFx)
