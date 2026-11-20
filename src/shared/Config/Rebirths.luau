--!strict
-- Renaissances (Partie 2, section 3.2 ; MAJ 3, DEV-120) : pour renaître, il faut un montant d'argent ET
-- un objet précis, que l'on remet (il disparaît).
--
-- Récompenses (décision de Clément du 2026-11-15, L-173 et L-168 Q2 et Q3 ; vague 56, a183). Une renaissance
-- ne donne plus que :
--   1. un multiplicateur d'argent : +50 % de revenus permanents par renaissance, qui s'additionnent (×1,5
--      après la 1re, ×2 après la 2e, ×3 après la 4e ; Partie 2, gardé). Simulateur (tools/ironix/equilibrage,
--      RAPPORT=renaissance, joueur moyen, 12 parties) : sans « Tapis ×1,5 » ni outil gardé, la 10e arrive à
--      71 h 50 (71 h 52 avec) : les temps de jeu du tableau tiennent. +75 % donnerait 64 h 55 et un 2e cycle
--      plus court que le 1er (96 %, contre 108 %) : à proposer à Clément, pas retenu ici ;
--   2. l'ouverture de tuiles de l'arbre de compétences : RequiresRebirth de Config/SkillTree (V0 : Lock à la
--      1re, Potion Time à la 2e, Door Guard à la 3e, Traps à la 4e), écrite dans UI_Rebirth par RewardText ;
--   3. le titre au-dessus du joueur (Title, L-168 Q2), dès la 1re (V0).
-- Retirés : aura, trail, Marteau-piqueur, Bélier, 2e agent, et « Tapis ×1,5 » des 3e et 6e (ni multiplicateur
-- d'argent ni tuile de l'arbre ; à confirmer par Clément).
--
-- Vague 51 (a164, 2026-11-14) : TOUT LE TABLEAU EST V0, pris dans la proposition du simulateur
-- (docs/claude/notes/renaissance-proposition.md, section 2 ; liaison L-158). Clément a dit oui aux objets
-- requis (question 7) ; l'argent requis, la 1re renaissance après la zone 6 et « 3 objets gardés » (oui de
-- Clément, L-168 Q4) restent à trancher avec Cantin (questions 1 à 6). L'ancien tableau de la
-- Partie 2 (10 K$, Pot de nouilles, ×10 par palier) ne tient plus avec l'économie v2 (section 0 de la note).
-- Lu par RebirthService (serveur, Features.Rebirth), RebirthController (écran UI_Rebirth) et
-- RebirthTitleController (titre).
--
-- Chaque objet requis est un ItemId de Config/Items ; sa rareté et sa zone sont recopiées ici et
-- contrôlées au chargement avec Config/Items : une différence arrête le module avec un message.
-- Vague 76 (a262, 19/11) : mêmes objets, raretés recopiées après leur réattribution V0 (Config/Items, ordre de
-- l'index) : Diamant géant, Trône en or Légendaires ; Statue de la Liberté, Coffre de diamants Mythiques ; Peluche
-- géante Peu commune ; PC gamer Rare ; Couronne Épique. La difficulté des paliers 4 à 6 change : à revoir avec Cantin.
--
-- API (serveur et client) :
--   Rebirths.IncomeBonus   0.5 : +50 % de revenus permanents par renaissance, additionnés
--   Rebirths.CashGrowth    1.3 (V0, non simulé) : au-delà du tableau, l'argent requis ×1,3 à chaque fois
--   Rebirths.KeepItems     3 : objets gardés à la renaissance (Partie 2 ; règle de choix dans RebirthService)
--   Rebirths.Tiers         les 10 lignes du tableau, dans l'ordre (Tiers[n].Level = n) ; la 10e est
--                          la ligne « 10 et suivantes »
--   Rebirths.Title         billboard du titre (nom, texte, palier de départ) ; voir plus bas
--   Rebirths.Get(level) -> Tier?
--       La renaissance numéro `level` (1 = la première) : sa ligne du tableau ; au-delà de la 10e, la
--       ligne « 10 et suivantes » avec l'argent requis ×CashGrowth par renaissance de plus ; nil si
--       `level` n'est pas un entier ≥ 1.
--   Rebirths.IncomeMultiplier(done) -> number     1 + IncomeBonus × done (done = renaissances faites)
--   Rebirths.RewardText(level) -> string          tuiles de l'arbre ouvertes par la renaissance `level`
--                                                 (« New skill: Lock »), "" si elle n'en ouvre aucune
--   Rebirths.TitleText(done) -> string?           texte du titre (« REBIRTH 3 »), nil sous Title.FromLevel

local DeepFreeze = require(script.Parent.DeepFreeze)
local Items = require(script.Parent.Items)
local Rarities = require(script.Parent.Rarities)
local SkillTree = require(script.Parent.SkillTree)

export type Tier = {
	Level: number, -- numéro de la renaissance (1 = la première)
	Cash: number, -- argent requis, en $
	ItemId: string, -- objet requis, remis (Config/Items)
	Rarity: Rarities.RarityId, -- rareté de l'objet (contrôlée avec Config/Items)
	Zone: number, -- zone de l'objet (contrôlée avec Config/Items)
	-- Récompense propre au palier, montrée au joueur (écran UI_Rebirth, GainList), en anglais (L-036) : les
	-- tuiles de l'arbre qu'il ouvre (Rebirths.RewardText) ; vide : la ligne est cachée par RebirthController.
	RewardText: string,
	PlayTimeMinutes: number?, -- temps de jeu simulé (joueur moyen), cumulé depuis la première connexion
}

local INCOME_BONUS = 0.5 -- Partie 2 : « +50 % de revenus permanents, qui s'additionnent »
local CASH_GROWTH = 1.3 -- V0, proposition section 2 : « 9T, puis ×1,3 par renaissance (non simulé) »
local KEEP_ITEMS = 3 -- Partie 2 : « 3 objets au choix » (V0 : les 3 qui rapportent le plus, RebirthService)

-- Textes de la récompense du palier (V0, absents du doc) : une tuile, plusieurs tuiles (noms séparés par « , »).
local REWARD_ONE = "New skill: %s"
local REWARD_MANY = "New skills: %s"

-- Titre au-dessus du joueur (L-168 Q2 : oui de Clément ; élément à venir, facultatif au contrat ; noms
-- proposés par a183, V0). RebirthTitleController pose une copie de Assets/UI/<Billboard> sur la tête de chaque
-- joueur qui a au moins FromLevel renaissances (attribut Rebirths du Player) et écrit Text dans Label.
local TITLE = {
	Billboard = "BB_RebirthTitle",
	Label = "TitleLabel",
	Text = "REBIRTH %d",
	FromLevel = 1, -- V0 : dès la 1re renaissance (la proposition d'a164 le donnait à la 10e)
}

-- Tuiles de l'arbre ouvertes par la renaissance `level` (Config/SkillTree, RequiresRebirth), en une ligne.
local function rewardText(level: number): string
	local names: { string } = {}
	for _, skill in SkillTree.UnlockedBy(level) do
		table.insert(names, skill.DisplayName)
	end
	if #names == 0 then
		return ""
	end
	return string.format(if #names == 1 then REWARD_ONE else REWARD_MANY, table.concat(names, ", "))
end

-- Le tableau de la section 2 de la proposition, ligne par ligne (en commentaire : argent, objet, temps de
-- jeu). La récompense de chaque ligne (RewardText) vient de Config/SkillTree.
local TIERS: { Tier } = {
	{ -- 1 | 20B | Diamant géant (Légendaire, zone 6) | 8 h 14
		Level = 1,
		Cash = 170e6, -- V0 proposé (Cantin, 20/11), avant : 20e9
		ItemId = "Z6_DiamantGeant",
		Rarity = "Legendary",
		Zone = 6,
		RewardText = rewardText(1),
		PlayTimeMinutes = 494,
	},
	{ -- 2 | 500B | Trône en or (Légendaire, zone 6) | 15 h 56
		Level = 2,
		Cash = 4.2e9, -- V0 proposé (Cantin, 20/11), avant : 500e9
		ItemId = "Z6_TroneEnOr",
		Rarity = "Legendary",
		Zone = 6,
		RewardText = rewardText(2),
		PlayTimeMinutes = 956,
	},
	{ -- 3 | 1.3T | Statue de la Liberté (Mythique, zone 6) | 22 h 49
		Level = 3,
		Cash = 11e9, -- V0 proposé (Cantin, 20/11), avant : 1.3e12
		ItemId = "Z6_StatueDeLaLiberte",
		Rarity = "Mythic",
		Zone = 6,
		RewardText = rewardText(3),
		PlayTimeMinutes = 1369,
	},
	{ -- 4 | 2T | Peluche géante (Peu commun, zone 2) | 30 h 08
		Level = 4,
		Cash = 17e9, -- V0 proposé (Cantin, 20/11), avant : 2e12
		ItemId = "Z2_PelucheGeante",
		Rarity = "Uncommon",
		Zone = 2,
		RewardText = rewardText(4),
		PlayTimeMinutes = 1808,
	},
	{ -- 5 | 2.6T | PC gamer (Rare, zone 3) | 36 h 35
		Level = 5,
		Cash = 22e9, -- V0 proposé (Cantin, 20/11), avant : 2.6e12
		ItemId = "Z3_PcGamer",
		Rarity = "Rare",
		Zone = 3,
		RewardText = rewardText(5),
		PlayTimeMinutes = 2195,
	},
	{ -- 6 | 3.2T | Couronne (Épique, zone 4) | 42 h 10
		Level = 6,
		Cash = 27e9, -- V0 proposé (Cantin, 20/11), avant : 3.2e12
		ItemId = "Z4_Couronne",
		Rarity = "Epic",
		Zone = 4,
		RewardText = rewardText(6),
		PlayTimeMinutes = 2530,
	},
	{ -- 7 | 5T | Masque ancien (Légendaire, zone 5) | 49 h 51
		Level = 7,
		Cash = 42e9, -- V0 proposé (Cantin, 20/11), avant : 5e12
		ItemId = "Z5_MasqueAncien",
		Rarity = "Legendary",
		Zone = 5,
		RewardText = rewardText(7),
		PlayTimeMinutes = 2991,
	},
	{ -- 8 | 7T | Coffre de diamants (Mythique, zone 6) | 55 h 59
		Level = 8,
		Cash = 59e9, -- V0 proposé (Cantin, 20/11), avant : 7e12
		ItemId = "Z6_CoffreDeDiamants",
		Rarity = "Mythic",
		Zone = 6,
		RewardText = rewardText(8),
		PlayTimeMinutes = 3359,
	},
	{ -- 9 | 7.5T | Clé du coffre ultime (Mythique, zone 6) | 64 h 06
		Level = 9,
		Cash = 63e9, -- V0 proposé (Cantin, 20/11), avant : 7.5e12
		ItemId = "Z6_CleDuCoffreUltime",
		Rarity = "Mythic",
		Zone = 6,
		RewardText = rewardText(9),
		PlayTimeMinutes = 3846,
	},
	{ -- 10 et suivantes | 9T, puis ×1,3 | Clé du coffre ultime (Mythique, zone 6) | 70 h 07
		Level = 10,
		Cash = 76e9, -- V0 proposé (Cantin, 20/11), avant : 9e12
		ItemId = "Z6_CleDuCoffreUltime",
		Rarity = "Mythic",
		Zone = 6,
		RewardText = rewardText(10),
		PlayTimeMinutes = 4207,
	},
}

for index, tier in TIERS do
	assert(tier.Level == index, `Config.Rebirths : la ligne {index} porte le niveau {tier.Level}`)
	local item = Items.ById[tier.ItemId]
	assert(item ~= nil, `Config.Rebirths : renaissance {index}, objet inconnu de Config/Items ({tier.ItemId})`)
	assert(
		item.Rarity == tier.Rarity and item.Zone == tier.Zone,
		`Config.Rebirths : renaissance {index}, {tier.ItemId} est {item.Rarity} de zone {tostring(item.Zone)} dans Config/Items, {tier.Rarity} de zone {tier.Zone} dans le tableau`
	)
end

local LAST = TIERS[#TIERS]

local function get(level: number): Tier?
	if level ~= level or level < 1 or level % 1 ~= 0 then
		return nil -- NaN, ≤ 0, pas entier ou infini
	end
	local tier = TIERS[level]
	if tier then
		return tier
	end
	-- Au-delà du tableau : la ligne « 10 et suivantes », l'argent ×CashGrowth par renaissance de plus
	-- (arrondi au milliard : un montant lisible).
	local beyond: Tier = {
		Level = level,
		Cash = math.floor(LAST.Cash * CASH_GROWTH ^ (level - LAST.Level) / 1e9 + 0.5) * 1e9,
		ItemId = LAST.ItemId,
		Rarity = LAST.Rarity,
		Zone = LAST.Zone,
		RewardText = rewardText(level),
		PlayTimeMinutes = nil,
	}
	-- :: any : sans lui, le nouveau solveur donne à `beyond` un type en lecture seule, plus un Tier.
	table.freeze(beyond :: any)
	return beyond
end

-- Nombre de renaissances faites, lu dans le profil : entier ≥ 0 (0 pour une valeur invalide).
local function clean(done: number): number
	if type(done) ~= "number" or done ~= done or done < 1 or done == math.huge then
		return 0
	end
	return math.floor(done)
end

local function incomeMultiplier(done: number): number
	return 1 + INCOME_BONUS * clean(done)
end

local function titleText(done: number): string?
	local count = clean(done)
	if count < TITLE.FromLevel then
		return nil
	end
	return string.format(TITLE.Text, count)
end

local Rebirths = {
	IncomeBonus = INCOME_BONUS,
	CashGrowth = CASH_GROWTH,
	KeepItems = KEEP_ITEMS,
	Tiers = TIERS,
	Title = TITLE,
	Get = get,
	IncomeMultiplier = incomeMultiplier,
	RewardText = rewardText,
	TitleText = titleText,
}

export type Rebirths = typeof(Rebirths)

return DeepFreeze(Rebirths)
