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
-- sortie, la rareté de l'objet est tirée dans BoxRarityOdds[rareté de la caisse], la chance multipliant
-- les raretés au-dessus d'un seuil (LuckBoost), puis l'objet, sa mutation et sa taille
-- sont tirés (vague 32, règle de Cantin du 2026-11-13, qui remplace les crans) ; l'objet sort à la
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

	-- Règle de Cantin du 2026-11-13 (vague 32 ; remplace les crans de rareté du 2026-11-12) : chaque caisse a
	-- une rareté (celle tirée à la mise en rayon, ShelfBoxes.ZoneOdds ou Rarities.BoxOdds par type de colis :
	-- son modèle BOX_<Rareté>). La rareté de l'OBJET est tirée à l'ouverture, dans la table de sa caisse :
	-- BoxRarityOdds[rareté de la caisse][rareté de l'objet] = poids relatif (une rareté absente = 0). Rien
	-- n'est garanti : une caisse Mythique peut donner un Commun, elle donne seulement plus souvent du rare.
	-- La chance tirée (LuckTable) agit selon LuckBoost, puis le total est ramené à 100 % :
	--   "AboveBox" : les poids des raretés AU-DESSUS de celle de la caisse sont multipliés par la chance
	--   (sa rareté et celles en dessous perdent leur part) ;
	--   "AboveLowest" : les poids de toutes les raretés au-dessus de la plus basse de la table (la plus basse
	--   de poids > 0) sont multipliés par la chance (la plus basse perd sa part). Ex. de la règle de Cantin,
	--   caisse Mythique Commun 35, Rare 25, Épique 20, Légendaire 12, Mythique 7, Secret 1 ; à ×3 : 15 %,
	--   33 %, 26 %, 16 %, 9 %, 1,3 %.
	--   Autre valeur : la chance ne change pas la rareté de l'objet (avertissement du serveur).
	-- L'objet est ensuite choisi dans cette rareté : zone du magasin, sinon la zone la plus proche qui en a
	-- (zone + 1, puis − 1, + 2…) ; un Secret (ou une Divine), toutes zones ; jamais un objet TutorialOnly ;
	-- aucun objet de cette rareté dans tout le catalogue (Divine aujourd'hui) : la rareté la plus proche en
	-- dessous qui en a. Mutation et taille (Config/Mutations) tirées au même moment.
	-- Tables : proposé par l'équilibrage, note equilibrage-caisses-L122.md, en attente de Clément (a108,
	-- 2026-11-13). Chaque table fait 100 ; une caisse donne surtout sa rareté, un peu au-dessus et en dessous.
	BoxRarityOdds = {
		Common = { Common = 88.841, Uncommon = 9, Rare = 1.8, Epic = 0.3, Legendary = 0.05, Mythic = 0.008, Secret = 0.001, Divine = 0 },
		Uncommon = { Common = 23, Uncommon = 64.29, Rare = 10, Epic = 2.3, Legendary = 0.34, Mythic = 0.06, Secret = 0.01, Divine = 0 },
		Rare = { Common = 8.3, Uncommon = 21, Rare = 58.94, Epic = 9.3, Legendary = 2.1, Mythic = 0.31, Secret = 0.05, Divine = 0 },
		Epic = { Common = 3, Uncommon = 8, Rare = 20, Epic = 57.6, Legendary = 9.1, Mythic = 2, Secret = 0.3, Divine = 0 },
		Legendary = { Common = 2, Uncommon = 3, Rare = 8, Epic = 20, Legendary = 56, Mythic = 9, Secret = 2, Divine = 0 },
		Mythic = { Common = 1, Uncommon = 2, Rare = 3, Epic = 8, Legendary = 20, Mythic = 57, Secret = 9, Divine = 0 },
		Secret = { Common = 0.5, Uncommon = 1, Rare = 2, Epic = 3.5, Legendary = 8.5, Mythic = 22, Secret = 62.5, Divine = 0 },
		Divine = { Common = 0.5, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 3.5, Mythic = 8, Secret = 22, Divine = 60 },
	} :: { [string]: { [string]: number } },
	-- Proposé par l'équilibrage (a108 : « AboveLowest » ne change presque rien au-dessus d'une caisse), en
	-- attente de la validation de Clément. "AboveBox" ou "AboveLowest" (voir plus haut).
	LuckBoost = "AboveBox" :: string,

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
