--!strict
-- Optimisation téléphone, passe 2 (a139, 2026-11-14 ; mesures dans docs/claude/notes/perf-telephone.md). Lu par
-- ShelfOpenController, ShelfBoxController et MutationFxController (client). Chaque réglage se coupe : false ou 0
-- redonne l'ancien comportement exact (même chose si ce module manque). De près et à l'écran, rien ne change.
-- Toutes les valeurs sont des V0 proposés, absents du doc. Unités : studs, secondes.
--
-- Règle « garder seulement ce qui gagne » : mesurer chaque réglage en marche puis coupé, dans deux Plays (les
-- modules de Config sont gelés pendant le Play) ; un réglage qui ne gagne rien au-delà du bruit est remis à false.

local DeepFreeze = require(script.Parent.DeepFreeze)

local PerfClient = {
	-- ShelfOpenController : un colis n'est relu que lorsque son état d'ouverture (ShelfOpenState, ShelfOpenAt)
	-- change, ou tant qu'il en a un ; false : les attributs de tous les colis chargés sont lus à chaque image.
	ShelfOpenWatchChanges = true, -- V0 proposé, absent du doc

	-- ShelfBoxController : un colis du rayon trouvé trop loin (au-delà d'OutlineMaxDistance pour son contour,
	-- de la portée de BB_Box pour son étiquette) n'est revu qu'une fois que la caméra s'est rapprochée d'assez
	-- pour qu'il puisse revenir à portée (écart moins ShelfBoxFarTolerance), ou au bout de ShelfBoxFarMaxSkip s.
	-- Les colis portés ou au sol (sans le tag ShelfBox) sont revus comme avant. false : tous revus à chaque tri.
	ShelfBoxFarSkip = true, -- V0 proposé, absent du doc
	ShelfBoxFarTolerance = 2, -- V0 proposé, absent du doc : studs (le colis qui grandit à l'ouverture)
	ShelfBoxFarMaxSkip = 2, -- V0 proposé, absent du doc : secondes au plus sans revoir un colis lointain

	-- MutationFxController : un objet suivi sans mutation n'est plus relu à chaque contrôle (toutes les
	-- MutationFx.DistanceCheckInterval s) ; il l'est quand MutationSize ou MutationEffect change. false : relu.
	MutationFxCacheFlags = false, -- coupé le 2026-11-14 : aucun gain mesuré en Play (2 à 10 ms sur 10 s avec ou sans), perf-telephone.md

	-- MutationFxController : l'effet d'un objet immobile (exposé, au sol, sorti du rayon) hors de l'écran n'est
	-- plus animé (couleurs Rainbow et Pulse, tremblement et saut de Glitch, doubles replacés) : il garde sa
	-- dernière pose et repart au prochain contrôle où il est en vue, comme ItemIdle.OnScreenOnly. Sa sphère
	-- (boîte, doubles, arc, portée de la lumière) est agrandie de MutationFxScreenMargin studs. Les objets portés
	-- sont toujours animés. false : animé hors de l'écran, comme avant.
	MutationFxOnScreenOnly = true, -- V0 proposé, absent du doc
	MutationFxScreenMargin = 2, -- V0 proposé, absent du doc : studs
}

export type PerfClient = typeof(PerfClient)

return DeepFreeze(PerfClient)
