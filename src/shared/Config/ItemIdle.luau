--!strict
-- Animation idle des objets exposés (liaison L-045 : proposition de Clément, validée par Ironix le
-- 2026-11-07). Lu par ItemIdleController (client). Le contrat (attribut Idle, pièces Spin_<Nom>)
-- est dans Contract/Attributes et Contract/Models.
--
-- Toutes les valeurs sont des V0 proposés, absents du doc, à faire valider par Clément.
-- Unités : tours par seconde, studs, secondes.

local DeepFreeze = require(script.Parent.DeepFreeze)

local ItemIdle = {
	-- Idle = "Spin" ou "SpinBob" : le modèle tourne sur l'axe Y de son pivot.
	SpinTurnsPerSecond = 0.2, -- V0 : un tour en 5 s (« rotation lente »)
	-- Pièces Spin_<Nom> : elles tournent sur leur propre axe Y, autour de leur centre.
	PieceTurnsPerSecond = 0.5, -- V0 : un tour en 2 s (anneau d'hologramme, ventilateurs)
	-- Idle = "Bob" ou "SpinBob" : le modèle monte puis redescend, sans jamais passer sous sa
	-- position de repos (il ne s'enfonce pas dans le présentoir).
	BobHeight = 0.25, -- V0 : studs au plus haut
	BobPeriod = 2.5, -- V0 : secondes pour une montée et une descente
	-- Plus loin de la caméra, l'objet reprend sa position de repos et n'est plus animé (9.7, pour le
	-- mobile), comme les halos de DisplayController (120 studs) et les auras (CosmeticController, 60).
	MaxDistance = 80, -- V0 : studs
	DistanceCheckInterval = 0.25, -- V0 : secondes entre deux tris par distance
}

export type ItemIdle = typeof(ItemIdle)

return DeepFreeze(ItemIdle)
