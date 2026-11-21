--!strict
-- « Espionner » la boutique d'un autre joueur depuis la rue (a301, demande de Cantin du 21/11). Lu par
-- ShopSpyController (client seulement), sous Features.ShopSpy. Le serveur ne change rien : le billboard BB_Item de
-- chaque objet exposé est déjà répliqué à tous les joueurs (DisplayService) ; près de la boutique, dehors, il est
-- seulement dessiné par-dessus les vitres et les murs de la façade (AlwaysOnTop sur la copie, rendu en partant).
--
-- Valeurs V0 proposées (2026-11-21), absentes du doc. Unités : studs, secondes.

local DeepFreeze = require(script.Parent.DeepFreeze)

local ShopSpy = {
	-- Portée : distance du personnage local au volume Bounds de la boutique (contrat 10.4), dehors (0 = dedans : rien
	-- ne change). 40 : la rue devant la façade. Le fond de la boutique (80 studs de profondeur) reste alors sous la
	-- MaxDistance de BB_Item (160, de Clément) avec la caméra derrière le personnage. PvP.ScoutDistance (15) est la
	-- portée du panneau de repérage BB_ShopInfo, pour comparer.
	Range = 40, -- V0 proposé (2026-11-21)
	-- Secondes entre deux revues des distances (comme Config/DisplayHalo.EffectsInterval).
	Interval = 0.25, -- V0 proposé (2026-11-21)
}

export type ShopSpy = typeof(ShopSpy)

return DeepFreeze(ShopSpy)
