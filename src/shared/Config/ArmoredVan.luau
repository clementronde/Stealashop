--!strict
-- Casse du siècle (GC6, a409, MAJ 6, DEV-133 ; Partie 2 : « toutes les 30 min, un fourgon blindé géant traverse le
-- boulevard. Les 6 joueurs le frappent ensemble ; chacun reçoit un colis selon ses dégâts (Luxe pour le top 3) »).
-- Lu par ArmoredVanService ; interrupteur Config/Features.ArmoredVan. Plus de colis Standard / Premium / Luxe
-- (vague 76) : les récompenses sont des colis de zone (Shared/ZoneBoxOdds, UnboxService.GiveZoneBoxItem), le meilleur
-- rang pour le top 3. Toute valeur sans source est « V0 proposé (Cantin, 23/11) ». Unités : s, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Rule = { ZoneStep: number, Exclude: { string }?, TopCount: number?, TopWeights: { number }?, TopBoost: number? }

-- Récompense d'un casseur : la première ligne qui convient (rang au plus MaxRank, ou part des dégâts au moins MinShare).
export type RewardTier = {
	MaxRank: number?,
	MinShare: number?,
	Label: string, -- nom du colis dans le message (anglais)
	Rule: Rule,
}

local ArmoredVan = {
	-- Horaire ------------------------------------------------------------------------------------------------------
	Period = 30 * 60, -- Partie 2 : toutes les 30 min
	Offset = 0, -- V0 proposé (Cantin, 23/11) : départs à l'heure pile et à la demie, heure UTC du serveur (os.time)
	WarnBefore = 60, -- V0 proposé (Cantin, 23/11) : annonce 60 s avant le départ
	-- Le fourgon ne part que de jour, avec au moins TravelTime s avant l'alerte de la nuit (sinon il traverserait le
	-- mur) ; un départ dû à un autre moment attend le jour suivant, DawnDelay s après l'aube, puis part (annoncé).
	-- Un départ en attente est remplacé par le suivant à l'heure (jamais deux d'affilée).
	DawnDelay = 20, -- V0 proposé (Cantin, 23/11)

	-- Trajet -------------------------------------------------------------------------------------------------------
	-- De l'arche (ZoneGate) de la zone la plus basse à celle de la plus haute, à vitesse constante, au milieu de la
	-- chaussée ; ne s'arrête pas. Pas cassé à l'arrivée, ou à l'alerte de la nuit : il s'échappe, rien n'est donné.
	TravelTime = 150, -- V0 proposé (Cantin, 23/11) : 2 min 30 pour tout le couloir
	-- Le fourgon ne bloque personne (collisions coupées) : un fourgon qui roule ne pousse pas les joueurs.

	-- Vie ----------------------------------------------------------------------------------------------------------
	-- PV partagés = HPPerDamage × la somme des dégâts par coup des joueurs du serveur au départ (ToolService), au
	-- moins MinHP : tout le serveur à 5 coups/s le casse en HPPerDamage / 5 s, s'il frappe sans arrêt.
	HPPerDamage = 300, -- V0 proposé (Cantin, 23/11) : 60 s à 5 coups/s pour tout le serveur
	MinHP = 3000, -- V0 proposé (Cantin, 23/11)

	-- Récompenses à la casse ------------------------------------------------------------------------------------------
	-- Classement par dégâts. Il faut au moins MinShare des PV pour compter. Zone de référence = la meilleure zone du
	-- joueur (comme les paliers de temps de jeu).
	MinShare = 0.02, -- V0 proposé (Cantin, 23/11) : 2 % des PV au moins
	Rewards = {
		-- Top 3 : le meilleur colis (Partie 2 : « Luxe pour le top 3 ») : zone suivante, ses 3 meilleures raretés.
		{ MaxRank = 3, Label = "Top 3 Box", Rule = { ZoneStep = 1, TopCount = 3, TopWeights = { 60, 30, 10 }, Exclude = { "Secret" } } },
		-- 15 % des dégâts ou plus : colis de sa zone, meilleure rareté × 1,5 (comme le palier de 15 min).
		{ MinShare = 0.15, Label = "Big Box", Rule = { ZoneStep = 0, TopBoost = 1.5 } },
		-- Les autres : colis de sa zone, aux chances des rayons.
		{ MinShare = 0, Label = "Box", Rule = { ZoneStep = 0 } },
	} :: { RewardTier },

	-- Modèle -------------------------------------------------------------------------------------------------------
	-- ENV_Event_ArmoredVan de Clément (ReplicatedStorage/Assets, sinon ServerStorage/Assets ; facultatif) : pivot en bas
	-- au centre, avant vers −Z ; HealthBarPoint (Attachment) facultatif. Absent : un fourgon en blocs construit par le
	-- code (VanSize).
	Asset = "ENV_Event_ArmoredVan",
	VanSize = Vector3.new(14, 12, 30), -- V0 proposé (Cantin, 23/11) : repli « géant » (le camion fait 34 studs de long)
	BillboardAsset = "BB_ArmoredVanHP", -- barre de vie de Clément (Assets/UI), facultative : Fill (GuiObject), HPText (TextLabel)
	BillboardSize = Vector2.new(16, 3), -- V0 : repli, en studs
	BillboardMaxDistance = 400, -- V0 : repli
	RemoveDelay = 3, -- V0 : le fourgon cassé reste 3 s (explosion), puis disparaît

	-- Textes (anglais) -----------------------------------------------------------------------------------------------
	Messages = {
		Soon = "The armored van drives through the corridor in %d s!", -- annonce, %d = secondes
		SoonDetail = "Heist of the century · hit it together", -- petite ligne de l'annonce
		Delayed = "The armored van waits for daylight.", -- départ dû la nuit
		Started = "HEIST OF THE CENTURY! The armored van is in the corridor!",
		StartedDetail = "Break it together · top 3 get the best box",
		Broken = "The armored van is open! Top: %s", -- %s = noms du top 3
		BrokenDetail = "%d players get a box", -- %d = nombre de casseurs récompensés
		Escaped = "The armored van escaped!",
		Reward = "Heist of the century: #%d (%d%% of the damage), %s: %s %s!", -- rang, part, colis, rareté, objet
		TooLittle = "Heist of the century: hit harder next time to get a box!",
		Full = "Heist of the century: inventory full, your box is lost!",
	},
	AnnounceIcon = "ICON_Event_ArmoredVan", -- V0 : icône de l'annonce (Decal de Clément), facultative
}

return DeepFreeze(ArmoredVan)
