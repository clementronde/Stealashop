--!strict
-- Renaissances (Partie 2, section 3.2 ; MAJ 3, DEV-120 pas encore codé) : pour renaître, il faut un
-- montant d'argent ET un objet précis, que l'on remet (il disparaît). Chaque renaissance donne +50 %
-- de revenus permanents, qui s'additionnent (×1,5 après la 1re, ×2 après la 2e, ×3 après la 4e), et
-- une récompense en plus. Le tableau du doc est recopié tel quel ; ses temps de jeu visés sont cumulés
-- depuis la première connexion, à ajuster en bêta. Lu aujourd'hui par RebirthController (aperçu de
-- l'écran UI_Rebirth, L-071), plus tard par le service de renaissance (DEV-120).
--
-- Chaque objet requis est un ItemId de Config/Items ; sa rareté et sa zone, écrites dans le doc
-- (« Pot de nouilles (Rare, zone 1) »), sont recopiées ici et contrôlées au chargement avec
-- Config/Items : une différence arrête le module avec un message.
--
-- API (serveur et client) :
--   Rebirths.IncomeBonus   0.5 : +50 % de revenus permanents par renaissance
--   Rebirths.CashGrowth    10 : au-delà du tableau, l'argent requis est multiplié par 10 à chaque fois
--   Rebirths.Tiers         les 10 lignes du tableau, dans l'ordre (Tiers[n].Level = n) ; la 10e est
--                          la ligne « 10 et suivantes »
--   Rebirths.Get(level) -> Tier?
--       La renaissance numéro `level` (1 = la première) : sa ligne du tableau ; au-delà de la 10e, la
--       ligne « 10 et suivantes » avec l'argent requis ×10 par renaissance de plus ; nil si `level`
--       n'est pas un entier ≥ 1.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Items = require(script.Parent.Items)
local Rarities = require(script.Parent.Rarities)

export type Tier = {
	Level: number, -- numéro de la renaissance (1 = la première)
	Cash: number, -- argent requis, en $
	ItemId: string, -- objet requis, remis (Config/Items)
	Rarity: Rarities.RarityId, -- rareté de l'objet, écrite dans le doc (contrôlée avec Config/Items)
	Zone: number, -- zone de l'objet, écrite dans le doc (contrôlée avec Config/Items)
	Reward: string, -- récompense en plus des +50 % de revenus, texte du doc
	-- La même récompense, montrée au joueur (écran UI_Rebirth, GainList), en anglais (L-036) :
	-- V0 proposé, absent du doc (traduction ; « Rebirth Aura » est le texte de la maquette de Clément).
	RewardText: string,
	PlayTimeMinutes: number?, -- temps de jeu visé, cumulé depuis la première connexion ; nil = « — »
}

local INCOME_BONUS = 0.5 -- « +50 % de revenus permanents, qui s'additionnent »
local CASH_GROWTH = 10 -- « 10 et suivantes : ×10 à chaque fois »

-- Le tableau de la section 3.2, ligne par ligne (en commentaire, le texte du doc).
local TIERS: { Tier } = {
	{ -- 1 | 10 K$ | Pot de nouilles (Rare, zone 1) | Aura « Renaissance » | 20 min
		Level = 1,
		Cash = 10_000,
		ItemId = "Z1_PotDeNouilles",
		Rarity = "Rare",
		Zone = 1,
		Reward = "Aura « Renaissance »",
		RewardText = "Rebirth Aura",
		PlayTimeMinutes = 20,
	},
	{ -- 2 | 100 K$ | Voiture télécommandée (Rare, zone 2) | +1 coffre-fort | 45 min
		Level = 2,
		Cash = 100_000,
		ItemId = "Z2_VoitureTelecommandee",
		Rarity = "Rare",
		Zone = 2,
		Reward = "+1 coffre-fort",
		RewardText = "+1 Safe",
		PlayTimeMinutes = 45,
	},
	{ -- 3 | 1 M$ | Robot jouet (Épique, zone 2) | +25 % de gains d'entraînement | 1 h 15
		Level = 3,
		Cash = 1_000_000,
		ItemId = "Z2_RobotJouet",
		Rarity = "Epic",
		Zone = 2,
		Reward = "+25 % de gains d'entraînement",
		RewardText = "+25% Training Gains",
		PlayTimeMinutes = 75,
	},
	{ -- 4 | 10 M$ | Console portable (Épique, zone 3) | Trail « Renaissance » | 2 h
		Level = 4,
		Cash = 10_000_000,
		ItemId = "Z3_ConsolePortable",
		Rarity = "Epic",
		Zone = 3,
		Reward = "Trail « Renaissance »",
		RewardText = "Rebirth Trail",
		PlayTimeMinutes = 120,
	},
	{ -- 5 | 100 M$ | Diamant brut (Épique, zone 4) | Marteau-piqueur débloqué | 3 h
		Level = 5,
		Cash = 100_000_000,
		ItemId = "Z4_DiamantBrut",
		Rarity = "Epic",
		Zone = 4,
		Reward = "Marteau-piqueur débloqué",
		RewardText = "Jackhammer Unlocked",
		PlayTimeMinutes = 180,
	},
	{ -- 6 | 1 Md$ | Couronne (Légendaire, zone 4) | +25 % de gains d'entraînement | 5 h
		Level = 6,
		Cash = 1_000_000_000,
		ItemId = "Z4_Couronne",
		Rarity = "Legendary",
		Zone = 4,
		Reward = "+25 % de gains d'entraînement",
		RewardText = "+25% Training Gains",
		PlayTimeMinutes = 300,
	},
	{ -- 7 | 10 Md$ | Masque ancien (Légendaire, zone 5) | Bélier débloqué | 8 h
		Level = 7,
		Cash = 10_000_000_000,
		ItemId = "Z5_MasqueAncien",
		Rarity = "Legendary",
		Zone = 5,
		Reward = "Bélier débloqué",
		RewardText = "Battering Ram Unlocked",
		PlayTimeMinutes = 480,
	},
	{ -- 8 | 100 Md$ | Coffre de diamants (Légendaire, zone 6) | 2e agent de sécurité | 12 h
		Level = 8,
		Cash = 100_000_000_000,
		ItemId = "Z6_CoffreDeDiamants",
		Rarity = "Legendary",
		Zone = 6,
		Reward = "2e agent de sécurité",
		RewardText = "2nd Security Guard",
		PlayTimeMinutes = 720,
	},
	{ -- 9 | 1 000 Md$ | Météorite (Mythique, zone 5) | Aura « Légende » | 18 h
		Level = 9,
		Cash = 1_000_000_000_000,
		ItemId = "Z5_Meteorite",
		Rarity = "Mythic",
		Zone = 5,
		Reward = "Aura « Légende »",
		RewardText = "Legend Aura",
		PlayTimeMinutes = 1080,
	},
	{ -- 10 et suivantes | ×10 à chaque fois | Clé du coffre ultime (Mythique, zone 6) | Titre affiché au-dessus de la tête | —
		Level = 10,
		Cash = 10_000_000_000_000, -- ×10 de la 9e
		ItemId = "Z6_CleDuCoffreUltime",
		Rarity = "Mythic",
		Zone = 6,
		Reward = "Titre affiché au-dessus de la tête",
		RewardText = "Overhead Title",
		PlayTimeMinutes = nil,
	},
}

for index, tier in TIERS do
	assert(tier.Level == index, `Config.Rebirths : la ligne {index} porte le niveau {tier.Level}`)
	local item = Items.ById[tier.ItemId]
	assert(item ~= nil, `Config.Rebirths : renaissance {index}, objet inconnu de Config/Items ({tier.ItemId})`)
	assert(
		item.Rarity == tier.Rarity and item.Zone == tier.Zone,
		`Config.Rebirths : renaissance {index}, {tier.ItemId} est {item.Rarity} de zone {tostring(item.Zone)} dans Config/Items, {tier.Rarity} de zone {tier.Zone} dans le doc`
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
	-- Au-delà du tableau : la ligne « 10 et suivantes », l'argent ×10 par renaissance de plus.
	local beyond: Tier = {
		Level = level,
		Cash = LAST.Cash * CASH_GROWTH ^ (level - LAST.Level),
		ItemId = LAST.ItemId,
		Rarity = LAST.Rarity,
		Zone = LAST.Zone,
		Reward = LAST.Reward,
		RewardText = LAST.RewardText,
		PlayTimeMinutes = nil,
	}
	-- :: any : sans lui, le nouveau solveur donne à `beyond` un type en lecture seule, plus un Tier.
	table.freeze(beyond :: any)
	return beyond
end

local Rebirths = {
	IncomeBonus = INCOME_BONUS,
	CashGrowth = CASH_GROWTH,
	Tiers = TIERS,
	Get = get,
}

export type Rebirths = typeof(Rebirths)

return DeepFreeze(Rebirths)
