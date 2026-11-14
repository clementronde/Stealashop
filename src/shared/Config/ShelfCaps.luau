--!strict
-- Murs invisibles au-dessus des rayons des magasins PNJ (Cantin, 2026-11-14, liaison L-140 : « des murs
-- invisibles au-dessus des étagères pour qu'il n'y ait personne qui puisse se mettre au-dessus »).
-- Lu par ShelfCapService (serveur). Toutes les valeurs sont des V0 proposés, absents du doc, à régler en jeu.
-- Unités : studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

local ShelfCaps = {
	-- Dossier créé par le code dans chaque magasin PNJ, et nom de chaque bloc (un par rayon).
	FolderName = "ShelfCaps", -- V0
	CapNameFormat = "ShelfCap_%02d", -- V0
	-- Jeu entre le haut de ce qui est posé sur le rayon et le bas du bloc.
	Gap = 0.2, -- V0
	-- Hauteur gardée libre au-dessus d'un emplacement de colis posé SUR le dessus du rayon (colis, objet
	-- sorti, invite) ; un emplacement rangé dans le rayon (sous son dessus) n'en demande pas.
	ContentHeight = 3, -- V0
	-- Un emplacement compte comme posé sur le dessus quand il est à moins de OnTopTolerance du dessus.
	OnTopTolerance = 0.5, -- V0
	-- Jeu le plus grand entre le dessus du rayon et le bas du bloc : sous 5 studs (un perso R15 fait environ
	-- 5 studs), pour que personne ne s'y glisse. Au-delà, le bloc est quand même posé à cette hauteur.
	MaxClearance = 4.5, -- V0
	-- Pièces d'un même meuble : en montant depuis l'emplacement, une pièce solide qui commence à plus de
	-- StackGap au-dessus de la précédente n'est plus le même meuble (une lampe au plafond, par exemple).
	-- Plus grand que l'écart entre deux planches, plus petit qu'un perso.
	StackGap = 3, -- V0
}

export type ShelfCaps = typeof(ShelfCaps)

return DeepFreeze(ShelfCaps)
