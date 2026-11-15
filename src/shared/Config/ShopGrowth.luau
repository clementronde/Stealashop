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
	-- Fond de la boutique = rang du dernier présentoir débloqué + RowMargin (un socle fait 4 de profondeur),
	-- arrondi au-dessus sur la grille du damier : StepOrigin + n × Step (carreaux de 4 depuis la porte).
	-- RowMargin, Step et StepOrigin sont FIGÉS (L-190 Q3) : Clément coupe les pièces du gabarit à ces fonds, plans
	-- z −12, −4, 4, 8, 16, 24, 32 et 40 (boutique entière). Les changer = lui demander de recouper.
	RowMargin = 5, -- figé (L-190) : au moins 2 studs entre le dos d'un socle et le revêtement du mur du fond
	Step = 4, -- figé (L-190)
	StepOrigin = -40, -- figé (L-190) : z de la porte dans le gabarit
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
	-- Gabarit découpé par Clément (L-190 Q1 et Q2) : avec l'attribut booléen RowCutAttribute = true sur PLOT_Shop,
	-- le code ne raccourcit plus rien. Une pièce dont le bord arrière est au plus à RowCutTolerance au-delà du
	-- fond est gardée telle quelle, une pièce fine du fond avance toujours avec lui, toute autre est retirée.
	-- Sans l'attribut, la coupe ci-dessus reste (filet).
	RowCutAttribute = "RowCut", -- nom convenu avec Clément (L-190)
	RowCutTolerance = 0.05, -- V0 : un tronçon coupé pile sur le plan reste devant le fond
}

return DeepFreeze(ShopGrowth)
