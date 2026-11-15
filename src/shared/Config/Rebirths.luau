--!strict
-- Renaissances (Partie 2, section 3.2 ; MAJ 3, DEV-120) : pour renaître, il faut un montant d'argent ET
-- un objet précis, que l'on remet (il disparaît). Chaque renaissance donne +50 % de revenus permanents,
-- qui s'additionnent (×1,5 après la 1re, ×2 après la 2e, ×3 après la 4e), et une récompense en plus.
--
-- Vague 51 (a164, 2026-11-14) : TOUT LE TABLEAU EST V0, pris dans la proposition du simulateur
-- (docs/claude/notes/renaissance-proposition.md, section 2 ; liaison L-158). Clément a dit oui aux objets
-- requis (question 7) et aux récompenses (question 8) ; l'argent requis, la 1re renaissance après la
-- zone 6 et « 3 objets gardés » restent à trancher avec Cantin (questions 1 à 6). L'ancien tableau de la
-- Partie 2 (10 K$, Pot de nouilles, ×10 par palier) ne tient plus avec l'économie v2 (section 0 de la note).
-- Lu par RebirthService (serveur, Features.Rebirth) et RebirthController (écran UI_Rebirth).
--
-- Chaque objet requis est un ItemId de Config/Items ; sa rareté et sa zone sont recopiées ici et
-- contrôlées au chargement avec Config/Items : une différence arrête le module avec un message.
--
-- API (serveur et client) :
--   Rebirths.IncomeBonus   0.5 : +50 % de revenus permanents par renaissance, additionnés
--   Rebirths.CashGrowth    1.3 (V0, non simulé) : au-delà du tableau, l'argent requis ×1,3 à chaque fois
--   Rebirths.KeepItems     3 : objets gardés à la renaissance (Partie 2 ; règle de choix dans RebirthService)
--   Rebirths.Tiers         les 10 lignes du tableau, dans l'ordre (Tiers[n].Level = n) ; la 10e est
--                          la ligne « 10 et suivantes »
--   Rebirths.Get(level) -> Tier?
--       La renaissance numéro `level` (1 = la première) : sa ligne du tableau ; au-delà de la 10e, la
--       ligne « 10 et suivantes » avec l'argent requis ×CashGrowth par renaissance de plus ; nil si
--       `level` n'est pas un entier ≥ 1.
--   Rebirths.IncomeMultiplier(done) -> number     1 + IncomeBonus × done (done = renaissances faites)
--   Rebirths.TreadmillMultiplier(done) -> number  produit des « Tapis ×1,5 » gagnés (1 sans renaissance)
--   Rebirths.HasReward(done, effect) -> boolean   une récompense de ce genre déjà gagnée

local DeepFreeze = require(script.Parent.DeepFreeze)
local Items = require(script.Parent.Items)
local Rarities = require(script.Parent.Rarities)

-- Genre de la récompense d'un palier, lu par RebirthService. Effet en jeu en V0 (vague 51) :
--   Treadmill  gain du tapis × Value (TrainingService.GetGainMultiplier)
--   None       aucune récompense propre (2e renaissance depuis la vague 54 : le coffre-fort n'existe plus ;
--              RewardText vide, la ligne de GainList est cachée par RebirthController)
--   Aura, Trail, Tool, Guard, Title  noté « gagné » (attribut RebirthRewards), sans effet en jeu tant
--              que l'aura, le trail, l'outil, l'agent de sécurité ou le billboard de titre n'existent pas
--              (Config/Cosmetics et Config/Tools n'en ont pas ; les ajouter les mettrait dans les boutiques)
export type RewardEffect = "Aura" | "None" | "Treadmill" | "Trail" | "Tool" | "Guard" | "Title"

export type Tier = {
	Level: number, -- numéro de la renaissance (1 = la première)
	Cash: number, -- argent requis, en $
	ItemId: string, -- objet requis, remis (Config/Items)
	Rarity: Rarities.RarityId, -- rareté de l'objet (contrôlée avec Config/Items)
	Zone: number, -- zone de l'objet (contrôlée avec Config/Items)
	Reward: string, -- récompense en plus des +50 % de revenus, en français (texte de la proposition)
	-- La même récompense, montrée au joueur (écran UI_Rebirth, GainList), en anglais (L-036) : V0
	-- (traduction ; « Rebirth Aura » est le texte de la maquette de Clément).
	RewardText: string,
	Effect: RewardEffect, -- genre de la récompense (voir RewardEffect)
	Value: number?, -- Treadmill : multiplicateur ; nil sinon
	PlayTimeMinutes: number?, -- temps de jeu simulé (joueur moyen), cumulé depuis la première connexion
}

local INCOME_BONUS = 0.5 -- Partie 2 : « +50 % de revenus permanents, qui s'additionnent »
local CASH_GROWTH = 1.3 -- V0, proposition section 2 : « 9T, puis ×1,3 par renaissance (non simulé) »
local KEEP_ITEMS = 3 -- Partie 2 : « 3 objets au choix » (V0 : les 3 qui rapportent le plus, RebirthService)
local TREADMILL_BONUS = 1.5 -- V0, proposition (question 8, oui de Clément) : « Tapis ×1,5 » aux 3e et 6e

-- Le tableau de la section 2 de la proposition, ligne par ligne (en commentaire, son texte).
local TIERS: { Tier } = {
	{ -- 1 | 20B | Diamant géant (Rare, zone 6) | Aura « Renaissance » (cosmétique) | 8 h 14
		Level = 1,
		Cash = 20e9,
		ItemId = "Z6_DiamantGeant",
		Rarity = "Rare",
		Zone = 6,
		Reward = "Aura « Renaissance » (cosmétique)",
		RewardText = "Rebirth Aura",
		Effect = "Aura",
		PlayTimeMinutes = 494,
	},
	{ -- 2 | 500B | Trône en or (Épique, zone 6) | +1 coffre-fort | 15 h 56
		-- Vague 54 (a176, Cantin, 2026-11-15) : le coffre-fort n'existe plus ; palier sans récompense propre
		-- (V0, en attendant une autre récompense choisie par Clément), seulement les +50 % de revenus.
		Level = 2,
		Cash = 500e9,
		ItemId = "Z6_TroneEnOr",
		Rarity = "Epic",
		Zone = 6,
		Reward = "aucune (V0)",
		RewardText = "",
		Effect = "None",
		PlayTimeMinutes = 956,
	},
	{ -- 3 | 1.3T | Statue de la Liberté (Épique, zone 6) | Tapis ×1,5 | 22 h 49
		Level = 3,
		Cash = 1.3e12,
		ItemId = "Z6_StatueDeLaLiberte",
		Rarity = "Epic",
		Zone = 6,
		Reward = "Tapis ×1,5",
		RewardText = "x1.5 Treadmill",
		Effect = "Treadmill",
		Value = TREADMILL_BONUS,
		PlayTimeMinutes = 1369,
	},
	{ -- 4 | 2T | Peluche géante (Légendaire, zone 2) | Trail « Renaissance » (cosmétique) | 30 h 08
		Level = 4,
		Cash = 2e12,
		ItemId = "Z2_PelucheGeante",
		Rarity = "Legendary",
		Zone = 2,
		Reward = "Trail « Renaissance » (cosmétique)",
		RewardText = "Rebirth Trail",
		Effect = "Trail",
		PlayTimeMinutes = 1808,
	},
	{ -- 5 | 2.6T | PC gamer (Légendaire, zone 3) | Marteau-piqueur (puissance de l'Angle Grinder, gardé) | 36 h 35
		Level = 5,
		Cash = 2.6e12,
		ItemId = "Z3_PcGamer",
		Rarity = "Legendary",
		Zone = 3,
		Reward = "Marteau-piqueur (puissance de l'Angle Grinder, gardé aux renaissances suivantes)",
		RewardText = "Jackhammer Unlocked",
		Effect = "Tool",
		PlayTimeMinutes = 2195,
	},
	{ -- 6 | 3.2T | Couronne (Légendaire, zone 4) | Tapis ×1,5 (×2,25 en tout) | 42 h 10
		Level = 6,
		Cash = 3.2e12,
		ItemId = "Z4_Couronne",
		Rarity = "Legendary",
		Zone = 4,
		Reward = "Tapis ×1,5 (×2,25 en tout)",
		RewardText = "x1.5 Treadmill",
		Effect = "Treadmill",
		Value = TREADMILL_BONUS,
		PlayTimeMinutes = 2530,
	},
	{ -- 7 | 5T | Masque ancien (Légendaire, zone 5) | Bélier | 49 h 51
		-- L-163 (porte en nombre de coups, a159) : plus de « force contre les portes », le Bélier est noté
		-- gagné sans effet sur les portes (vague 51, V0).
		Level = 7,
		Cash = 5e12,
		ItemId = "Z5_MasqueAncien",
		Rarity = "Legendary",
		Zone = 5,
		Reward = "Bélier (sans effet sur les portes depuis L-163)",
		RewardText = "Battering Ram Unlocked",
		Effect = "Tool",
		PlayTimeMinutes = 2991,
	},
	{ -- 8 | 7T | Coffre de diamants (Légendaire, zone 6) | 2e agent de sécurité (après la MAJ 5) | 55 h 59
		Level = 8,
		Cash = 7e12,
		ItemId = "Z6_CoffreDeDiamants",
		Rarity = "Legendary",
		Zone = 6,
		Reward = "2e agent de sécurité (après la MAJ 5)",
		RewardText = "2nd Security Guard",
		Effect = "Guard",
		PlayTimeMinutes = 3359,
	},
	{ -- 9 | 7.5T | Clé du coffre ultime (Mythique, zone 6) | Aura « Légende » (cosmétique) | 64 h 06
		Level = 9,
		Cash = 7.5e12,
		ItemId = "Z6_CleDuCoffreUltime",
		Rarity = "Mythic",
		Zone = 6,
		Reward = "Aura « Légende » (cosmétique)",
		RewardText = "Legend Aura",
		Effect = "Aura",
		PlayTimeMinutes = 3846,
	},
	{ -- 10 et suivantes | 9T, puis ×1,3 | Clé du coffre ultime (Mythique, zone 6) | Titre au-dessus de la tête | 70 h 07
		Level = 10,
		Cash = 9e12,
		ItemId = "Z6_CleDuCoffreUltime",
		Rarity = "Mythic",
		Zone = 6,
		Reward = "Titre au-dessus de la tête",
		RewardText = "Overhead Title",
		Effect = "Title",
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
		Reward = LAST.Reward,
		RewardText = LAST.RewardText,
		Effect = LAST.Effect,
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

local function treadmillMultiplier(done: number): number
	local multiplier = 1
	for level = 1, math.min(clean(done), #TIERS) do
		local tier = TIERS[level]
		if tier.Effect == "Treadmill" then
			multiplier *= tier.Value or 1
		end
	end
	return multiplier
end

local function hasReward(done: number, effect: RewardEffect): boolean
	for level = 1, math.min(clean(done), #TIERS) do
		if TIERS[level].Effect == effect then
			return true
		end
	end
	return false
end

local Rebirths = {
	IncomeBonus = INCOME_BONUS,
	CashGrowth = CASH_GROWTH,
	KeepItems = KEEP_ITEMS,
	Tiers = TIERS,
	Get = get,
	IncomeMultiplier = incomeMultiplier,
	TreadmillMultiplier = treadmillMultiplier,
	HasReward = hasReward,
}

export type Rebirths = typeof(Rebirths)

return DeepFreeze(Rebirths)
