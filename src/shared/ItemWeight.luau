--!strict
-- ItemWeight (vague 62, contrat entre a202, a203 et a204 ; liaison L-198) : le poids d'un objet tiré à l'ouverture
-- d'un colis, de 1 à 10 000 kg, et ce qui en découle (taille du modèle, revenu, mutation de taille, classe de
-- taille de la cinématique).
--
-- REPLI MINIMAL d'a202 : le vrai module est écrit par a203 (loi du tirage, taille, revenu, paliers). À la fusion,
-- garder la version d'a203 et jeter celle-ci. Ici : poids fixe de 10 kg (la taille d'aujourd'hui), taille 1,
-- revenu ×1, aucune mutation de taille, classe « Small ».
--
-- API (contrat, à ne pas changer sans le dire) :
--   ItemWeight.Roll(rng, luck) -> kg                   luck = multiplicateur de chance de la boîte (≥ 1)
--   ItemWeight.ScaleFor(kg) -> number                  taille du modèle (10 kg = 1)
--   ItemWeight.IncomeFactor(kg) -> number              multiplicateur du revenu
--   ItemWeight.SizeMutationFor(kg) -> string?          "Huge", "Colossal" ou nil
--   ItemWeight.SizeClassFor(kg, freeHeight, modelHeight) -> SizeClass
--       Large = l'objet grandi touche le plafond (freeHeight studs au-dessus du rayon, modelHeight = hauteur du
--       modèle à la taille 1) ; Colossal = palier du haut (la caméra sort du magasin).

export type SizeClass = "Small" | "Large" | "Colossal"

local REFERENCE_KG = 10 -- repli : le poids de la taille d'aujourd'hui

local ItemWeight = {}

function ItemWeight.Roll(_rng: Random, _luck: number): number
	return REFERENCE_KG
end

function ItemWeight.ScaleFor(_kg: number): number
	return 1
end

function ItemWeight.IncomeFactor(_kg: number): number
	return 1
end

function ItemWeight.SizeMutationFor(_kg: number): string?
	return nil
end

function ItemWeight.SizeClassFor(_kg: number, _freeHeight: number, _modelHeight: number): SizeClass
	return "Small"
end

return ItemWeight
