--!strict
-- Halos des objets exposés, côté client seulement (vague 39, a129, optimisation téléphone : audit
-- docs/claude/notes/perf-telephone.md, correction 2). Lu par DisplayController : le serveur crée toujours
-- le même halo (Shared/RarityHalo) et, de près, rien ne change. Ce qui change au loin est réglé ici.
--
-- Toutes les valeurs sont des V0 proposés, absents du doc. Unités : studs, secondes.

local DeepFreeze = require(script.Parent.DeepFreeze)

local DisplayHalo = {
	-- Lumière (HaloLight) et particules (HaloSparkles) d'un objet exposé allumées seulement à moins de
	-- EffectsDistance studs de la caméra, éteintes au-delà de EffectsDistance + EffectsMargin (l'écart évite
	-- un clignotement à la limite). L'audit propose 40 à 60 studs. 0 : coupure désactivée (comme avant).
	-- VISUAL EFFECTS sur OFF : CosmeticController les éteint tous, cette coupure n'y touche pas.
	EffectsDistance = 50, -- V0
	EffectsMargin = 5, -- V0
	EffectsInterval = 0.25, -- V0 : secondes entre deux revues des distances
	-- Rayons (Légendaire et plus) tournés seulement quand le halo est dans le champ de la caméra ; hors
	-- champ, ils reprennent leur place dès qu'ils y reviennent. false : tournés partout (comme avant).
	RaysOnScreenOnly = true, -- V0
	-- Couleurs des rayons du Secret : l'arc-en-ciel calculé une fois en RainbowSteps teintes (au lieu d'une
	-- ColorSequence neuve par rayon à chaque image), écrites seulement quand la teinte change.
	RainbowSteps = 120, -- V0 : 40 teintes par seconde avec un tour en 3 s
}

export type DisplayHalo = typeof(DisplayHalo)

return DeepFreeze(DisplayHalo)
