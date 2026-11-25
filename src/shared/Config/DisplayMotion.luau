--!strict
-- Mouvement des objets exposés (a317, liaison L-304 point 3, demande de Clément du 2026-11-23, validé sur son
-- prototype tools/clement/collect_motion_proto.luau, « les mouvements très cool »). Côté client seulement : lu par
-- ItemIdleController (qui déplace déjà les pièces des objets exposés) et DisplayController (encaissement d'une
-- plaque). Le serveur ne bouge jamais l'objet ; il lit seulement Headroom (hauteur gardée libre quand il met l'objet à
-- la taille de son présentoir, FitSize) et l'accroche de BB_Item.
--
-- Valeurs du prototype de Clément, en V0 (absentes du doc partagé). Unités : studs, secondes, radians.

local DeepFreeze = require(script.Parent.DeepFreeze)

local DisplayMotion = {
	-- false : objets immobiles comme avant L-304 (sauf l'attribut Idle et les pièces Spin_ / Wave_ de Clément),
	-- aucune hauteur retirée, BB_Item accroché au pied.
	Enabled = true, -- V0

	-- Au repos, chaque objet flotte : bas de sa boîte à FloatGap stud au-dessus de son DisplaySlot_xx, et il monte et
	-- descend de ±BobHeight (sinus de BobPeriod s), décalé de PhaseStep rad d'une place à l'autre (DisplaySlot n :
	-- (n − 1) × PhaseStep), pour que tout ne bouge pas ensemble.
	FloatGap = 0.6, -- V0 (prototype)
	BobHeight = 0.3, -- V0 (prototype)
	BobPeriod = 2.6, -- V0 (prototype)
	PhaseStep = 0.7, -- V0 (prototype)

	-- À l'encaissement de sa plaque : un tour complet sur lui-même, autour de l'axe vertical au centre de sa boîte, en
	-- SpinTime s (Quad Out), avec Hops sauts dans le même temps, le premier de HopHeight, chacun HopDecay × le précédent
	-- (parabole par saut). Validé par Cantin, 23/11 (L-304 Q3) : tous les joueurs qui voient la boutique le voient
	-- (remote CashCollect envoyé à tous, L-091) ; le voile, le compteur et le son restent au joueur local (CashFlash).
	SpinTime = 0.7, -- V0 (prototype)
	Hops = 2, -- V0 (prototype)
	HopHeight = 0.9, -- V0 (prototype)
	HopDecay = 0.45, -- V0 (prototype)

	-- Plus loin de la caméra, l'objet ne bouge plus : il reste posé à FloatGap au-dessus du présentoir (comme les halos
	-- de DisplayController, ANIMATION_DISTANCE = 120 studs). Au plus près, ItemIdleController garde ses règles (hors de
	-- l'écran : figé ; au-delà de ItemIdle.NearDistance : 15 images par seconde).
	MaxDistance = 120, -- V0 (ANIMATION_DISTANCE des halos)

	-- BB_Item accroché au sommet de la boîte de l'objet, BillboardTopOffset stud plus bas (validé par Clément :
	-- l'étiquette touche presque l'objet), StudsOffset (0, BillboardStudsOffset, 0). Avant : au pied, avec le StudsOffset
	-- de Clément (2,2, L-027).
	-- a459 (L-354, Clément 24/11 : « son bas à +0,8 stud au-dessus du haut réel de l'objet ») : BillboardTopOffset passe de
	-- −0,15 à 0,8 ; DisplayService pose le BAS de l'étiquette sur ce point, quel que soit le SizeOffset de BB_Item.
	BillboardAtTop = true, -- V0
	BillboardTopOffset = 0.8, -- Clément (L-354) ; avant −0,15 (L-304)
	BillboardStudsOffset = 0, -- V0 (L-304)

	-- Hauteur gardée libre au-dessus de l'objet quand DisplayService le met à la taille du FitSize de son présentoir
	-- (calculée plus bas : FloatGap + BobHeight + HopHeight, 1,8 stud), pour que l'objet le plus haut ne touche jamais
	-- le plancher de l'étage en flottant et en sautant. Validé par Cantin, 23/11 (L-304 Q2) : pas de changement de la
	-- map. Un objet qui a en plus l'attribut Idle Bob ou SpinBob garde aussi ItemIdle.BobHeight.
	Headroom = 0,
}

DisplayMotion.Headroom = DisplayMotion.FloatGap + DisplayMotion.BobHeight + DisplayMotion.HopHeight

export type DisplayMotion = typeof(DisplayMotion)

return DeepFreeze(DisplayMotion)
