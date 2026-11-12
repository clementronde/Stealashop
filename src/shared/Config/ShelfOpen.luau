--!strict
-- Ouverture des colis sur le rayon du magasin PNJ et antivol en base (liaison L-112 ; décisions de Cantin
-- du 2026-11-12 au soir ; Features.ShelfOpen). Lu par StoreHeistService, UnboxService, PvPService et
-- DisplayService (serveur), par ShelfOpenController (client) et par Shared/ShelfOpenState (calcul commun
-- de la chance qui monte).
--
-- Déroulé (L-112) : le joueur lance l'ouverture d'un colis sur son rayon ; le serveur tire la chance au
-- hasard (LuckTable) ; les rabats se lèvent (FlapsTime), puis « ×N LUCK » monte de LuckStep à chaque tic
-- de LuckTick s jusqu'à la chance tirée (tirée à ×1 : l'objet sort tout de suite après les rabats) ; à la
-- sortie, la rareté du contenu monte par crans (UpgradeMax crans, chacun réussi avec UpgradeChance × la
-- chance) ; l'objet sort à la place du colis, réservé ReserveTime s à l'ouvreur ; en base, l'objet posé
-- garde un antivol (AntiTheft[rareté] s) pendant lequel il est volable.
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
	LuckTick = 0.1, -- T.54 : un tic toutes les 0,1 s
	LuckStep = 1.03, -- T.54 : chance × 1,03 à chaque tic (la montée accélère)

	-- L-112 (Cantin) : la chance est tirée au hasard au lancement, elle ne dépend pas du temps passé appuyé.
	-- V0 PROVISOIRE : sera remplacée par la proposition d'équilibrage de la vague 31 (agent a106), après
	-- l'accord de Cantin. Montée : ×1,5 en 1,4 s, ×2 en 2,4 s, ×3 en 3,8 s, ×5 en 5,5 s, ×10 en 7,8 s.
	LuckTable = {
		{ Luck = 1, Weight = 50 },
		{ Luck = 1.5, Weight = 25 },
		{ Luck = 2, Weight = 13 },
		{ Luck = 3, Weight = 8 },
		{ Luck = 5, Weight = 3 },
		{ Luck = 10, Weight = 1 },
	} :: { LuckEntry },

	-- L-112 (Cantin) : la chance monte la rareté du colis par crans, même règle que l'ancienne ouverture en base
	-- (Config/Unbox.UpgradeMax et UpgradeChance, spec du 2026-11-07), réglable à part ici.
	UpgradeMax = 2,
	UpgradeChance = 0.10, -- chaque cran réussit avec UpgradeChance × la chance tirée (bornée à 1)

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
