--!strict
-- Vigiles de magasin, réglages d'a518 (27/11, liaison L-437, L-438, L-426). Lus par GuardService et ses modules d'aide
-- Guard/Scale, Guard/DayPatrol et Guard/CatchRagdoll. Chaque bloc a son interrupteur dans Config/Features (X en PROD,
-- XDev dans le jeu DEV et TEST). Valeurs sans mention : demandées par Clément ; « V0 » : V0 proposé (Cantin, 27/11),
-- absent du doc, à régler en jeu. Unités : secondes, studs, studs/s, degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Guards = {
	-- L-437 (Features.GuardScale / GuardScaleDev) : taille des vigiles en jeu.
	Scale = {
		-- Clément (27/11) : « 1,5 fois plus gros que les joueurs ». Model:ScaleTo(Size) sur le clone en jeu : un joueur R15
		-- (aucun personnage n'est mis à l'échelle dans ce jeu) vaut 1 ; Guard_Z1 à Z6 sont à environ 1 aujourd'hui.
		Size = 1.5,
		-- V0 : rayon de l'agent du chemin plafonné. La boîte d'un R15 à 1,5, bras compris, donne environ 3 studs de rayon
		-- (6 de large) ; le corps qui heurte (torse) ne fait que 3 de large. 2,5 laisse passer les allées de 5 studs.
		AgentRadiusMax = 2.5,
		Night = true, -- V0 : les vigiles de nuit aussi (false : seulement ceux des magasins)
	},

	-- L-438 (Features.GuardDayPatrol / GuardDayPatrolDev) : ronde du vigile de jour dans son magasin.
	DayPatrol = {
		Speed = 10, -- V0 : marche de la ronde (comme la ronde de nuit, Night.PatrolSpeed, et le retour)
		PauseMin = 1.5, -- V0 : pause à chaque point (Idle, tourné vers la vitrine), tirée entre ces deux bornes (s)
		PauseMax = 3,
		CheckInterval = 2, -- V0 : un vigile de ronde posé dans chaque magasin qui n'en a pas, revu à ce rythme (s)
		-- V0 : points de ronde. Facultatifs, posés par Clément dans le magasin : PointName (Attachment ou pièce), dans
		-- l'ordre des numéros. Sans eux : le GuardSpawn, puis un point devant chaque ShelfSlot, ShelfOffset studs vers le
		-- centre du volume Bounds, gardé à BoundsInset studs de ses bords, à MinSpacing studs au moins l'un de l'autre,
		-- dans l'ordre du tour du magasin.
		PointName = "GuardPatrol_%02d",
		PointMax = 20,
		ShelfOffset = 3.5,
		BoundsInset = 2,
		MinSpacing = 3,
		-- a529 (L-494) : point dans un meuble ou contre lui : place libre cherchée autour du slot, SearchStep studs plus
		-- loin à chaque tour, SearchSteps tours ; le sol et les marches (FootClearance studs au-dessus des pieds) ne
		-- comptent pas.
		SearchStep = 1.5,
		SearchSteps = 3,
		FootClearance = 1,
		LookStep = 0.6, -- V0 : à la pause, un pas de cette longueur vers la vitrine (Window), pour s'y tourner (studs)
	},

	-- L-426 (Features.GuardCatchRagdoll / GuardCatchRagdollDev) : attrapé par un vigile de magasin.
	CatchRagdoll = {
		-- V0 : le voleur part en ragdoll à l'opposé du vigile, à Speed studs/s à l'horizontale, AirTime s en l'air sur sol
		-- plat (≈ Speed × AirTime = 18 studs, puis il glisse un peu) : assez loin pour qu'un autre joueur reprenne l'objet,
		-- qui tombe là où il a été attrapé. Le coup d'avant : 40 studs/s pendant 0,15 à 0,2 s (≈ 7 studs).
		Speed = 30,
		AirTime = 0.6,
		-- V0 : relevé debout Time s après le coup (avant la fin de l'étourdissement, Balance.Guard.CatchStunDuration 2,4).
		Time = 2,
		WallMargin = 2, -- V0 : la poussée s'arrête à 2 studs d'un mur ou d'un plafond (comme la batte, Bat.RagdollWallMargin)
		-- Clément (25/11) : « le garde part de l'objet, il retourne à sa base » : à la fin de Catch, le vigile rentre à son
		-- GuardSpawn au lieu de garder l'objet tombé ; il revient si quelqu'un le reprend. false : il le garde (avant).
		GuardReturns = true,
	},
}

export type Guards = typeof(Guards)

return DeepFreeze(Guards)
