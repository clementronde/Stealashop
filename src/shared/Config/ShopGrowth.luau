--!strict
-- La boutique du joueur grandit petit à petit (vague 55, a179 ; retour de Cantin du 15/11 : « quand tu
-- améliores ta base […] la base elle est entière d'un coup, il faudrait que ça aille petit à petit »).
-- Lu par ShopStageService (serveur), qui coupe ses copies `Stage_2` à `Stage_k` du gabarit PLOT_Shop au fond du
-- dernier présentoir débloqué, et par RayonService (socles des présentoirs au-delà, cachés). Règle géométrique,
-- sans rien changer au gabarit de Clément : voir l'en-tête de ShopStageService.
--
-- Toutes les valeurs sont des V0 proposés, absents du doc. Unités : studs, mesurés dans le repère de la boutique
-- (avant vers −Z, fond vers +Z ; gabarit de Clément : porte en z −40, fond en z 40, rangs de présentoirs
-- tous les 7 studs, L-141).

local DeepFreeze = require(script.Parent.DeepFreeze)

local ShopGrowth = {
	-- false : la boutique reprend tout de suite la taille entière de chaque niveau, comme avant la vague 55.
	Enabled = true, -- V0
	-- Vague 60 (a195, T-086, Cantin : « un seul présentoir sur les deux ») : dans un rang déjà montré, le socle
	-- et la plaque d'un présentoir pas encore débloqué restent cachés (RayonService). false : tout le rang d'un coup.
	-- Une pièce des visuels d'un rayon sans numéro dans son nom (`…_07`) suit le DisplaySlot le plus proche à moins
	-- de LockedStandRadius (au sol) ; plus loin, c'est le décor du rang, montré avec lui.
	HideLockedStands = true, -- V0
	LockedStandRadius = 6, -- V0 : la plaque est à 5 studs de son socle, le socle voisin du même côté à 8,6
	-- Fond de la boutique = rang du dernier présentoir débloqué + RowMargin (un socle fait 4 de profondeur),
	-- arrondi au-dessus sur la grille du damier : StepOrigin + n × Step (carreaux de 4 depuis la porte).
	RowMargin = 5, -- V0 : au moins 2 studs entre le dos d'un socle et le revêtement du mur du fond
	Step = 4, -- V0 (0 : pas d'arrondi)
	StepOrigin = -40, -- V0 : z de la porte dans le gabarit
	-- Pièces « du fond » : leur bord arrière est à moins de BackZone du fond du gabarit. Une pièce fine
	-- (profondeur ≤ BackThickness : mur du fond, parapet, caméras du fond) avance avec le fond ; une longue pièce
	-- (sol, murs des côtés, toit) est raccourcie en gardant son écart au fond.
	BackZone = 4, -- V0
	BackThickness = 2, -- V0
	-- Une pièce plus longue que ClipMinLength qui dépasse le nouveau fond est raccourcie (à InnerInset avant le
	-- fond si elle ne touchait pas le fond du gabarit : néons du plafond) ; plus courte, elle est retirée si son
	-- centre est au-delà. Raccourcie à moins de MinLength : retirée.
	ClipMinLength = 6, -- V0
	InnerInset = 1.5, -- V0 : épaisseur du mur du fond et de son revêtement, plus un peu
	MinLength = 1, -- V0
}

return DeepFreeze(ShopGrowth)
