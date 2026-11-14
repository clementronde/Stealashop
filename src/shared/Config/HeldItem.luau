--!strict
-- Objet tenu en main (demande de Cantin du 2026-11-14, agent a142) : un objet de l'inventaire choisi dans la
-- barre du bas UI_Hotbar va dans la main du joueur, comme un outil, à la taille qu'il a sur un présentoir
-- (HeldItemService, serveur ; HotbarController et InventoryController, client).
--
-- Toutes les valeurs sont des V0 proposés, absents du doc. Unités : studs, degrés, secondes.
--
-- Prise en main (Tool.Grip) : repère de la main droite pendant la pose « outil en main » de Roblox (bras
-- tendu devant) : X vers la droite du joueur, Y vers le haut, -Z devant lui. Boîte de l'objet = boîte de
-- ses pièces dans le repère de son pivot, sans la pièce du halo (RarityHalo), mutation de taille comprise.
--   - petit objet (plus grand côté ≤ LargeSize) : tenu au bout de la main, son centre à la hauteur de la
--     main, sa face arrière à Forward studs devant elle ;
--   - gros objet (plus grand côté > LargeSize : souvent Big, Huge, Colossal) : tenu par-dessous, devant le
--     corps : son bas à LargeBelowHand studs sous la main, décalé de LargeCenterShift studs vers la gauche
--     (la main droite est à environ 1,5 stud du milieu du corps d'un R15), sa face arrière à Forward studs
--     devant la main. Il monte au-dessus de la main au lieu de traîner par terre et reste centré devant
--     le joueur, lisible pour les autres.
-- Yaw : rotation de l'objet autour de la verticale (0 = sa face avant -Z regarde devant le joueur, comme
-- s'il le montrait ; 180 = tournée vers lui). Seuls 0 et 180 gardent la règle de la face arrière.

local DeepFreeze = require(script.Parent.DeepFreeze)

local HeldItem = {
	Forward = 0.1, -- V0 proposé, absent du doc : studs entre la main et la face arrière de l'objet
	LargeSize = 2.5, -- V0 proposé, absent du doc : plus grand côté (studs) au-delà duquel l'objet est « gros »
	LargeBelowHand = 0.6, -- V0 proposé, absent du doc : studs entre le bas d'un gros objet et la main
	LargeCenterShift = 1.5, -- V0 proposé, absent du doc : studs vers la gauche (gros objet centré devant le corps)
	Yaw = 0, -- V0 proposé, absent du doc : degrés
	-- Revérification de l'objet tenu (encore à lui, pas exposé, pas vendu, pas au coffre-fort, pas posé au sol).
	-- Chaque changement de l'inventaire la fait aussi tout de suite.
	CheckInterval = 0.25, -- V0 proposé, absent du doc : secondes
	-- Noms posés par HeldItemService (lus par InventoryController et HotbarController) :
	ToolAttribute = "HeldItemUid", -- sur le Tool de l'objet tenu : son uid
	PlayerAttribute = "HeldItem", -- sur le Player : uid de l'objet tenu, absent sinon
	ModelName = "HeldItem", -- le modèle de l'objet, dans le Tool
	CarriedTag = "CarriedItem", -- tag de code de CarryService : MutationFxController y montre l'effet de la mutation
}

export type HeldItem = typeof(HeldItem)

return DeepFreeze(HeldItem)
