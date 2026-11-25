--!strict
-- Poids des objets (vague 62, a203 ; décision de Cantin et Clément du 2026-11-15 au soir, liaison L-198) : chaque
-- objet tiré a un poids de 1 à 10 000 kg, gardé partout (profil Items[uid].Weight, objet porté, au sol, au rayon,
-- présentoir). Le poids fait la taille du modèle et le revenu, et remplace les mutations de taille : Huge et
-- Colossal deviennent des paliers de poids (Tiny et Big n'existent plus) ; les mutations d'effet (Gold, Neon…)
-- restent un tirage à part (Config/Mutations). Les calculs sont dans Shared/ItemWeight ; ce module n'a que les
-- valeurs. Toujours actif (a438 : plus de Features.SingleBoxReveal).
--
-- Origine de chaque valeur : « Cantin » = décision de Cantin du 2026-11-15 ; V0 = proposé par a203 au simulateur
-- (bash tools/ironix/equilibrage/run.sh, RAPPORT=poids), absent du doc, à régler en jeu.
-- Unités : kg, pour cent, multiplicateurs (×1 = rien).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Tier = {
	Min: number, -- kg, compris
	Max: number, -- kg, non compris (Min = Max : ce poids exact)
	Chance: number, -- pour cent à ×1 (somme des paliers : 100)
}

export type ScalePoint = {
	Kg: number,
	Scale: number,
}

-- a234 (V0) : courbe poids → taille (voir ScaleCurve dans la table).
-- a418 (décision de Cantin 23/11, variante A2, docs/references/Taille-Objet-De-Base.md) : petits objets × 2, gros
-- inchangés ; seuls les points de 1, 10 et 100 kg bougent (avant : 0.1 ^ (1/3), 1 et 2.6).
local SCALE_CURVE: { ScalePoint } = {
	{ Kg = 1, Scale = 2 * 0.1 ^ (1 / 3) }, -- décision de Cantin 23/11, variante A2 (≈ ×0,93)
	{ Kg = 10, Scale = 2 }, -- décision de Cantin 23/11, variante A2
	{ Kg = 100, Scale = 4.2 }, -- décision de Cantin 23/11, variante A2 (sur la droite de 10 à 500 kg)
	{ Kg = 500, Scale = 7 },
	{ Kg = 10000, Scale = 16 },
}

-- Échelle de `kg` sur SCALE_CURVE : droite entre les deux points voisins en échelle logarithmique (une puissance du
-- poids entre deux points) ; avant le premier point ou après le dernier, la pente du segment le plus proche.
local function scaleAt(kg: number): number
	local count = #SCALE_CURVE
	local index = 1
	while index < count - 1 and kg > SCALE_CURVE[index + 1].Kg do
		index += 1
	end
	local a, b = SCALE_CURVE[index], SCALE_CURVE[index + 1]
	if kg == a.Kg or kg == b.Kg then
		return if kg == a.Kg then a.Scale else b.Scale -- valeur exacte sur un point (10 kg = ×2 tout juste)
	end
	local slope = math.log(b.Scale / a.Scale) / math.log(b.Kg / a.Kg)
	return a.Scale * (math.max(kg, 1e-6) / a.Kg) ^ slope
end

local Weight = {
	Min = 1, -- Cantin : de 1 kg…
	Max = 10000, -- Cantin : … à 10 000 kg
	-- V0 : poids de référence = la taille et le revenu d'aujourd'hui (×1), au milieu du gros du tirage.
	Reference = 10,

	-- V0 : paliers en échelle logarithmique ; dans un palier, le poids est tiré au hasard en échelle
	-- logarithmique (autant de chances entre 100 et 200 kg qu'entre 200 et 400 kg). Cantin : le gros du tirage
	-- autour de 5 à 50 kg (66 % à ×1), 10 000 kg vers 0,001 % à ×1 ; le léger est le moins avantageux.
	Tiers = {
		{ Min = 1, Max = 2, Chance = 6 },
		{ Min = 2, Max = 5, Chance = 14 },
		{ Min = 5, Max = 10, Chance = 22 },
		{ Min = 10, Max = 20, Chance = 24 },
		{ Min = 20, Max = 50, Chance = 20 },
		{ Min = 50, Max = 100, Chance = 8.3 },
		{ Min = 100, Max = 250, Chance = 3.6 },
		{ Min = 250, Max = 500, Chance = 1.2 },
		{ Min = 500, Max = 1000, Chance = 0.5 },
		{ Min = 1000, Max = 2500, Chance = 0.25 },
		{ Min = 2500, Max = 5000, Chance = 0.1 },
		{ Min = 5000, Max = 10000, Chance = 0.049 },
		{ Min = 10000, Max = 10000, Chance = 0.001 },
	} :: { Tier },
	-- Cantin : le multiplicateur de chance de la boîte (celui de la rareté, ×1 à ×8) multiplie les chances des
	-- paliers lourds, comme celles des raretés au-dessus de la caisse (ShelfOpen.LuckBoost « AboveBox »), puis le
	-- total est ramené à 100 % : rien n'est garanti, ×8 rend les paliers lourds 8 fois plus probables que les
	-- légers. V0 : « lourd » = un palier qui commence à LuckFrom kg ou plus.
	LuckFrom = 50,

	-- Taille du modèle (échelle ×, 10 kg = ×2 depuis a418) : courbe par points (ScaleAt, plus bas), droite entre deux
	-- points en échelle logarithmique (kg et taille). a418 (décision de Cantin 23/11, variante A2 : l'objet de base à
	-- environ deux tiers du perso, comme le jeu de référence ; « 500 kg = une voiture » gardé) : sous 10 kg, la racine
	-- cubique × 2 (1 kg ≈ ×0,93) ; puis 10 kg = ×2 (canette de 1,6 stud : 3,2 studs), 20 kg ≈ ×2,5, 50 kg ≈ ×3,36,
	-- 100 kg = ×4,2, 250 kg ≈ ×5,6, 500 kg = ×7 (un objet de 1,6 à 2 studs : 11 à 14 studs, une voiture), 2 500 kg ≈ ×10,9,
	-- 10 000 kg = ×16 (de 500 kg à 10 000 kg : comme a234). a234 (V0, Clément L-219 point 6 et L-220) : 1 kg ≈ ×0,46,
	-- 10 kg = ×1, 50 kg ≈ ×1,95, 100 kg = ×2,6, 250 kg ≈ ×4,6. Avant a234 : (kg / 10) ^ (1/3), soit 10 000 kg = ×10.
	-- Ouverture du colis et objet porté : cette taille (au plus CarryMaxScale) ; présentoir : réduite pour tenir dans
	-- FitSize (DisplayService) ; socle « BEST ITEM » : au plus RarestMaxScale. Points rangés par poids croissant.
	ScaleCurve = SCALE_CURVE,
	ScaleAt = scaleAt, -- (kg) -> échelle ; appelé par Shared/ItemWeight.ScaleFor, poids déjà ramené à Min…Max
	-- Revenu (Cantin : le poids change directement le revenu) : (kg / Reference) ^ IncomeExponent. V0 : la même
	-- racine cubique que la taille (10 000 kg = ×10, comme l'ancien Colossal ; 1 kg ≈ ×0,46) ; moyenne
	-- ×1,22 à ×1, ×1,30 avec la chance tirée dans ShelfOpen.LuckTable, comme les anciennes tailles (×1,30 ; rapport
	-- « poids » du simulateur).
	IncomeExponent = 1 / 3,

	-- V0 : paliers des mutations de taille (étiquette « HUGE », « COLOSSAL » et effet de Clément seulement : elles
	-- ne multiplient plus le revenu, le poids le fait déjà). Colossal = aussi la classe de taille du haut de la
	-- cinématique (la caméra sort du magasin).
	HugeFrom = 250,
	ColossalFrom = 2500,

	-- V0 : poids donné à un objet du profil qui n'en a pas (DataService, au chargement), selon sa mutation de
	-- taille d'avant ; chacun garde au moins son revenu d'avant (taille et effet) et Huge, Colossal restent dans
	-- leur palier : Tiny ×0,5 → 2,2 kg (×0,60, sa taille d'avant) ; Big ×2 → 80 kg (×2) ; Huge ×5 → 1 250 kg (×5) ;
	-- Colossal ×10 → 10 000 kg (×10) ; sans taille → Reference (×1).
	Legacy = {
		Tiny = 2.2,
		Big = 80,
		Huge = 1250,
		Colossal = 10000,
	} :: { [string]: number },

	-- V0 : plafonds d'échelle du modèle. Présentoir et objet posé au sol : à sa taille (Cantin). Objet tenu en main
	-- (HeldItemService) et grand socle « BEST ITEM » (VfxController) : plafonnés pour ne pas cacher le joueur ni la
	-- parcelle. Objet porté sur la tête (CarryService) : à sa taille comme sur un présentoir (a220, Clément L-210 point 3 :
	-- « sa vraie taille, même énorme »), au plus CarryMaxScale (1 = l'ancien rendu, taille du catalogue).
	-- a234 : DisplayMaxScale et CarryMaxScale suivent le haut de ScaleCurve (×16 ; avant ×10), pour que l'objet porté
	-- garde sa taille de l'ouverture ; sur un présentoir qui a FitSize, l'objet est en plus réduit pour y tenir.
	-- RarestMaxScale (a234, L-220 : vraie taille sur le socle, sans FitSize, avec une limite pour ne pas couvrir le hub) :
	-- ×6, soit 9,6 à 12 studs pour un objet de 1,6 à 2 studs, sous LabelPoint (11 studs au-dessus du plateau) ; avant ×3.
	-- a418 (variante A2) : DisplayMaxScale, CarryMaxScale et RarestMaxScale inchangés (le haut de la courbe ne bouge pas).
	DisplayMaxScale = 16,
	-- a418, V0 (décision de Cantin 23/11, variante A2) : 3,4 plafonne les mêmes objets qu'avant (≥ 52 kg ; ×2 avant, ≥ 53 kg) ;
	-- au plus 5,4 studs en main pour un objet de 1,6 stud.
	HeldMaxScale = 3.4,
	RarestMaxScale = 6,
	CarryMaxScale = 16,
	-- a220 (V0) : chez le porteur seulement (CarryController), un objet porté à partir de cette échelle devient
	-- translucide (LocalTransparencyModifier CarryFade) pour qu'il voie encore son perso et la rue ; les autres le voient
	-- plein. CarryFade = 0 : jamais.
	-- a418, V0 (décision de Cantin 23/11, variante A2) : 4 garde à peu près les mêmes objets translucides qu'avant (≥ 86 kg,
	-- 7,5 % des tirages à ×1 ; avant 2,5, ≥ 91 kg, 6,8 %) ; 2,5 rendrait translucides tous ceux de 20 kg et plus.
	CarryFadeFromScale = 4,
	CarryFade = 0.55,
	-- V0 : objet tenu à deux mains (AnimationController, HoldItem) à partir de ce poids (l'ancien Big = 80 kg).
	TwoHandsFrom = 50,

	-- Affichage (ItemWeight.Format) : « 3.4 kg », « 12 kg », « 1,250 kg » (V0 : séparateur anglais des milliers, les
	-- textes du jeu sont en anglais, L-036).
	Unit = "kg",
	ThousandsSeparator = ",",
	-- Noms posés par le code (V0) : attribut Weight (kg) des modèles d'objet (présentoir, sol, en main, porté) et
	-- élément facultatif Weight des billboards et cases qui montrent déjà le revenu (Contract/UI).
	Attribute = "Weight",
	-- a234 : attribut posé par DisplayService sur un objet exposé réduit pour tenir dans le FitSize de son présentoir
	-- (nombre < 1, la réduction ; absent : aucune). VfxController le retire de la copie du socle « BEST ITEM ».
	FitScaleAttribute = "FitScale",
	Field = "Weight",
}

export type WeightConfig = typeof(Weight)

return DeepFreeze(Weight)
