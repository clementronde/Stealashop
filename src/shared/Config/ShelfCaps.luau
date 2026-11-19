--!strict
-- Murs invisibles au-dessus des rayons des magasins PNJ (Cantin, 2026-11-14, liaison L-140 : « des murs
-- invisibles au-dessus des étagères pour qu'il n'y ait personne qui puisse se mettre au-dessus »).
-- Lu par ShelfCapService (serveur) et StoreClimbController (client). Toutes les valeurs sont des V0 proposés, absents du doc, à régler en jeu.
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

	-- Grands meubles sans emplacement de colis (Play du 14/11 : le frigo du fond, `Fridge_Top`, haut à 7,8,
	-- dans les 12 magasins). Dans Bounds, toute pièce solide dont le dessus est assez large pour s'y tenir
	-- et plus haut qu'une marche reçoit aussi un bloc (mêmes règles : Gap au-dessus du dessus, jusqu'au
	-- haut de Bounds).
	-- Dessus d'au moins FurnitureMinTop × FurnitureMinTop studs (la partie dans Bounds) : en dessous, une
	-- pièce fine (mur, pilier, montant, cadre de porte) n'en reçoit pas.
	FurnitureMinTop = 2, -- V0
	-- Meuble haut et étroit (T-061, Play du 19/11 : la comtoise de l'Antiquaire, dessus 1,8 × 2,25 à 8,2 studs
	-- du sol, atteinte d'un seul saut) : un dessus d'au moins FurnitureNarrowMinTop × FurnitureNarrowMinTop
	-- reçoit aussi un bloc quand il est à au moins FurnitureNarrowMinHeight studs au-dessus du sol (plus haut
	-- qu'un perso R15 de 5 studs : un petit meuble plus bas reste libre) et à au plus FurnitureNarrowMaxHeight
	-- (un saut lève les pieds d'environ 7,3 studs, plus la marche que Roblox monte seul ; au-dessus, un
	-- linteau ou un cadre sous un mur, hors de portée).
	FurnitureNarrowMinTop = 1, -- V0
	FurnitureNarrowMinHeight = 5, -- V0
	FurnitureNarrowMaxHeight = 10, -- V0
	-- Dessus à au moins FurnitureMinHeight studs au-dessus du sol du magasin (bas de Bounds) : plus bas,
	-- c'est une marche, on peut y monter sans risque.
	FurnitureMinHeight = 3, -- V0
	-- Dessus à moins de FurnitureCeilingMargin studs du haut de Bounds : mur, plafond, pilier, rien à
	-- couvrir (un perso R15 de 5 studs n'y tient pas debout).
	FurnitureCeilingMargin = 2, -- V0
	-- Attribut d'exception de Clément, sur une pièce ou un modèle (vrai) : pas de bloc au-dessus.
	NoCapAttribute = "NoShelfCap", -- V0
	-- Comptage, attributs posés sur le dossier ShelfCaps de chaque magasin : blocs des rayons (trouvés par
	-- les ShelfSlot) et blocs des grands meubles.
	ShelfCountAttribute = "OnShelves", -- V0
	FurnitureCountAttribute = "OnFurniture", -- V0

	-- Grimpe (Play du 14/11) : en sautant contre une gondole, le perso passait en état Climbing et restait
	-- accroché à la face du rayon, sous le bloc. StoreClimbController (client) coupe l'état Climbing du
	-- perso du joueur local tant qu'il est dans le volume Bounds d'un magasin PNJ, et le rend dehors.
	NoClimbInStores = true, -- V0
	ClimbCheckInterval = 0.2, -- V0 : secondes entre deux vérifications
}

export type ShelfCaps = typeof(ShelfCaps)

return DeepFreeze(ShelfCaps)
