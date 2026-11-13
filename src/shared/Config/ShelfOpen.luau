--!strict
-- Ouverture des colis sur le rayon du magasin PNJ et antivol en base (liaison L-112 ; décisions de Cantin
-- du 2026-11-12 au soir ; Features.ShelfOpen). Lu par StoreHeistService, UnboxService, PvPService et
-- DisplayService (serveur), par ShelfOpenController (client) et par Shared/ShelfOpenState (calcul commun
-- de la chance qui monte).
--
-- Déroulé (L-112) : le joueur lance l'ouverture d'un colis sur son rayon ; le serveur tire la chance au
-- hasard (LuckTable) ; les rabats se lèvent (FlapsTime), puis « ×N LUCK » monte de LuckStep à chaque tic,
-- de plus en plus vite, jusqu'à la chance tirée, en RiseMax s au plus (tirée à ×1 : l'objet sort tout de
-- suite après les rabats) ; à la
-- sortie, la rareté du contenu monte par crans (tant qu'un cran réussit, jusqu'à UpgradeTop ; chance du
-- cran n = min(UpgradeChance × la chance, UpgradeChanceCap) × UpgradeDecay^(n − 1)) ; l'objet sort à la
-- place du colis, réservé ReserveTime s à l'ouvreur ; en base, l'objet posé garde un antivol
-- (AntiTheft[rareté] s) pendant lequel il est volable.
--
-- Origine de chaque valeur, notée en commentaire :
--   L-112   décision écrite dans la liaison (Clément ou Cantin) ;
--   T.5x    ligne du tableau d'animations de Clément (docs/claude/notes/ui-motion-skilltree.md) ;
--   V0      proposé, absent du doc, à régler en jeu.
-- Unités : secondes ; chances en multiplicateur (×1 = aucune chance) ; poids relatifs (somme libre).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type LuckEntry = {
	Luck: number, -- chance tirée, ≥ 1
	Weight: number, -- poids relatif, > 0
}

local ShelfOpen = {
	FlapsTime = 0.6, -- V0 : les deux rabats se lèvent et la lumière sort, avant que la chance monte (T.53)
	LuckStep = 1.03, -- T.54 : chance × 1,03 à chaque tic
	-- L-118 point 4 (Clément : « 2 s au plus, avec une accélération ») : la plus forte chance de LuckTable monte
	-- en RiseMax s, une plus petite en RiseMax × √(ses tics / ceux de la plus forte) ; les tics se serrent
	-- (Shared/ShelfOpenState). Montée (rabats non compris) : ×1,5 en 0,85 s, ×2 en 1,1 s, ×3 en 1,4 s,
	-- ×5 en 1,7 s, ×8 en 1,9 s, ×10 en 2 s.
	RiseMax = 2,

	-- L-112 (Cantin) : la chance est tirée au hasard au lancement, elle ne dépend pas du temps passé appuyé.
	-- L-112, table d'équilibrage adoptée par Cantin le 2026-11-12.
	LuckTable = {
		{ Luck = 1, Weight = 55 },
		{ Luck = 1.5, Weight = 20 },
		{ Luck = 2, Weight = 12 },
		{ Luck = 3, Weight = 7 },
		{ Luck = 5, Weight = 4 },
		{ Luck = 8, Weight = 1.5 },
		{ Luck = 10, Weight = 0.5 },
	} :: { LuckEntry },

	-- L-112 (Cantin, 2026-11-12 au soir) : la chance monte la rareté du colis par crans, sans limite de
	-- nombre : tant qu'un cran réussit, la rareté continue de monter (un Secret est possible même depuis un
	-- Commun de zone 1) ; arrêt au premier échec ou à UpgradeTop. Chance du cran n (1, 2, …) =
	-- min(UpgradeChance × la chance tirée, UpgradeChanceCap) × UpgradeDecay^(n − 1). Rareté atteinte sans
	-- objet dans la zone du magasin (la zone 1 n'a que des Communs) : le cran compte quand même, l'objet
	-- est pris dans la zone la plus proche qui en a un de cette rareté (zone + 1, puis − 1, et ainsi de
	-- suite ; un Secret se tire toutes zones), jamais un objet TutorialOnly.
	-- Valeurs des crans : L-112, proposé par l'équilibrage et adopté par Cantin le 2026-11-12 (note
	-- equilibrage-chance-L112.md ; avec UpgradeDecay = 1, un ×10 sur un Commun finissait en Secret une fois
	-- sur deux).
	UpgradeMax = math.huge, -- nombre de crans au plus : sans limite
	UpgradeChance = 0.08, -- chance d'un cran = UpgradeChance × la chance tirée…
	UpgradeChanceCap = 0.9, -- … bornée (sinon un gros tirage donnerait toujours la rareté la plus haute)
	UpgradeDecay = 0.7, -- facteur appliqué à la chance de chaque cran suivant
	UpgradeTop = "Secret", -- rareté la plus haute que les crans peuvent atteindre (Divine exclue)

	ReserveTime = 5, -- L-112 (Cantin) : l'objet sorti n'est prenable que par l'ouvreur pendant 5 s, puis par tous
	RevealTintMinRarity = "Epic", -- L-112 : voile plein écran UI_HUD.RevealTint pour Épique et plus
	AnnounceMinRarity = "Legendary", -- V0 : un objet sorti de cette rareté ou plus est annoncé à tout le serveur

	-- L-112 (Cantin) : durée de l'antivol en base, par rareté (Id de Config/Rarities) ; volable pendant ce temps.
	AntiTheft = {
		Common = 5,
		Uncommon = 10,
		Rare = 20,
		Epic = 30,
		Legendary = 60,
		Mythic = 90,
		Secret = 120,
		Divine = 180,
	} :: { [string]: number },
}

export type ShelfOpenConfig = typeof(ShelfOpen)

return DeepFreeze(ShelfOpen)
