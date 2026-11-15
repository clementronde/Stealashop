--!strict
-- Poids des objets (vague 62, a203 ; décision de Cantin et Clément du 2026-11-15 au soir, liaison L-198) : chaque
-- objet tiré a un poids de 1 à 10 000 kg, gardé partout (profil Items[uid].Weight, objet porté, au sol, au rayon,
-- présentoir). Le poids fait la taille du modèle et le revenu, et remplace les mutations de taille : Huge et
-- Colossal deviennent des paliers de poids (Tiny et Big n'existent plus) ; les mutations d'effet (Gold, Neon…)
-- restent un tirage à part (Config/Mutations). Les calculs sont dans Shared/ItemWeight ; ce module n'a que les
-- valeurs. Interrupteur : Features.SingleBoxReveal (false = ni poids, ni taille par le poids : les mutations de
-- taille d'avant, telles quelles).
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

	-- Taille du modèle (Cantin : le poids suit le volume) : (kg / Reference) ^ ScaleExponent, soit 1 kg ≈ ×0,46,
	-- 10 kg = ×1, 1 000 kg ≈ ×4,6, 10 000 kg = ×10.
	ScaleExponent = 1 / 3,
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
	-- parcelle. Objet porté sur la tête (CarryService) : CarryMaxScale (aujourd'hui à sa taille de catalogue, ×1).
	DisplayMaxScale = 10,
	HeldMaxScale = 2,
	RarestMaxScale = 3,
	CarryMaxScale = 1,
	-- V0 : objet tenu à deux mains (AnimationController, HoldItem) à partir de ce poids (l'ancien Big = 80 kg).
	TwoHandsFrom = 50,

	-- Affichage (ItemWeight.Format) : « 3.4 kg », « 12 kg », « 1,250 kg » (V0 : séparateur anglais des milliers, les
	-- textes du jeu sont en anglais, L-036).
	Unit = "kg",
	ThousandsSeparator = ",",
	-- Noms posés par le code (V0) : attribut Weight (kg) des modèles d'objet (présentoir, sol, en main, porté) et
	-- élément facultatif Weight des billboards et cases qui montrent déjà le revenu (Contract/UI).
	Attribute = "Weight",
	Field = "Weight",
}

export type WeightConfig = typeof(Weight)

return DeepFreeze(Weight)
