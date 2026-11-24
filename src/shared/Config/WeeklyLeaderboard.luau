--!strict
-- Classements hebdomadaires (GC6, a409, MAJ 6, DEV-140 ; Partie 2 : « top 100 en $/s et en vols = aura du classement »).
-- Lu par WeeklyLeaderboardService ; interrupteur Config/Features.WeeklyLeaderboards. Valeurs absentes du doc :
-- « V0 proposé (Cantin, 23/11) », à régler en jeu.
--
-- Semaine : du lundi 00:00 UTC au dimanche 23:59:59 UTC (Partie 2 : « remise à zéro le lundi »), même calcul que le
-- coffre hebdomadaire (Config/Rewards.Weekly) : numéro = (jour UTC + MondayOffset) // 7. Chaque semaine a ses propres
-- OrderedDataStore (nom + « _W<semaine> ») : la remise à zéro, c'est le nouveau nom, rien n'est effacé.
--
-- Panneaux : ceux du hub (tag Leaderboard, Config/Leaderboard) dont l'attribut Stat vaut une clé de Stats plus bas
-- (WeeklyIncome ou WeeklySteals), remplis par LeaderboardService (AddBoard). Livrés en L-330 (fond du hub), List en
-- ScrollingFrame : LeaderboardScrollController en fait une copie dans le PlayerGui pour qu'on puisse la faire défiler.
-- Statues du n° 1 (L-331) : Statue plus bas, LeaderboardStatueService.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type StatSpec = {
	Title: string, -- Board.Title du panneau (anglais)
	Store: string, -- préfixe du nom de l'OrderedDataStore (suffixe DEV puis « _W<semaine> »)
	Log: boolean, -- codage logarithmique du revenu (comme Config/Leaderboard)
	RankAttribute: string, -- attribut du Player : son rang de la semaine (0 = hors du top)
}

-- Une récompense : rang de MaxRank au plus (le plus petit MaxRank qui convient), un colis de zone (règle de
-- Shared/ZoneBoxOdds, objet donné tout de suite par UnboxService.GiveZoneBoxItem, comme les paliers de temps de jeu).
export type RewardTier = {
	MaxRank: number,
	Rule: { ZoneStep: number, Exclude: { string }?, TopCount: number?, TopWeights: { number }?, TopBoost: number? },
	Label: string, -- nom du colis dans le message (anglais)
}

local LOG_SCALE = 1e13 -- même codage que Config/Leaderboard (log10(1e36) × 1e13 < 2^53)

local WeeklyLeaderboard = {
	Stats = {
		-- Meilleur revenu par seconde atteint dans la semaine (sans les boosts du moment, comme « Most money/s »).
		WeeklyIncome = { Title = "Money/s this week", Store = "LeaderboardWeek_Income", Log = true, RankAttribute = "WeeklyIncomeRank" },
		-- Vols de la semaine : seulement les vols chez un autre joueur (Lifetime.Steals). a430 : réponse (1) de Clément
		-- en L-325, les braquages de magasins (Lifetime.Heists) ne comptent plus.
		WeeklySteals = { Title = "Steals this week", Store = "LeaderboardWeek_Steals", Log = false, RankAttribute = "WeeklyStealsRank" },
	} :: { [string]: StatSpec },
	Order = { "WeeklyIncome", "WeeklySteals" }, -- ordre de traitement (écritures, récompenses)
	Top = 100, -- Partie 2 : top 100 (une page de GetSortedAsync, 100 au plus)
	DevSuffix = "_DEV", -- comme Config/Leaderboard : stores à part dans le jeu DEV
	DayLength = 86400,
	MondayOffset = 3, -- le jour UTC 0 (1/1/1970) était un jeudi (comme Config/Rewards.Weekly)
	WriteInterval = 120, -- V0 proposé (Cantin, 23/11) : comme Config/Leaderboard
	ReadInterval = 120, -- V0 proposé (Cantin, 23/11)
	FirstReadDelay = 8, -- V0 proposé (Cantin, 23/11) : première lecture peu après le démarrage
	MinBudget = 5, -- V0 proposé (Cantin, 23/11) : sous ce budget DataStore, on attend le tour suivant
	WeekEndsAttribute = "WeeklyBoardEndsAt", -- attribut du Player : heure UTC (os.time) de la remise à zéro

	-- Récompense de la semaine finie, donnée à la première connexion qui suit (ou tout de suite si le joueur est là au
	-- changement de semaine), une fois par classement ; elle attend le joueur, même des semaines après (a430, L-325 (3)). V0 proposé (Cantin, 23/11) ; la Partie 2 dit
	-- « aura du classement », pas encore livrée (AuraId plus bas).
	Rewards = {
		{ MaxRank = 3, Label = "Top 3 Box", Rule = { ZoneStep = 1, TopCount = 2, TopWeights = { 70, 30 }, Exclude = { "Secret" } } },
		{ MaxRank = 10, Label = "Top 10 Box", Rule = { ZoneStep = 1, TopCount = 3, TopWeights = { 60, 30, 10 }, Exclude = { "Secret" } } },
		{ MaxRank = 100, Label = "Top 100 Box", Rule = { ZoneStep = 0, TopBoost = 1.5 } },
	} :: { RewardTier },
	-- Aura du classement (Partie 2) : Id de Config/Cosmetics donné au top AuraMaxRank, quand Clément l'aura faite.
	-- nil = pas d'aura (V0).
	AuraId = nil :: string?,
	AuraMaxRank = 10,

	Messages = {
		Reward = "Weekly leaderboard (%s): #%d! You get %s: %s %s!", -- classement, rang, colis, rareté, objet
		Full = "Weekly leaderboard reward waiting: make room in your inventory!",
	},
	BoardNames = { WeeklyIncome = "Money/s", WeeklySteals = "Steals" }, -- nom du classement dans Messages.Reward
	LogScale = LOG_SCALE,

	-- a430 (L-331, noms proposés par Clément) : statues ENV_Hub_LeaderboardStatue du n° 1 de chaque classement,
	-- habillées par LeaderboardStatueService (serveur) avec l'avatar du n° 1. Facultatives.
	Statue = {
		Tag = "LeaderboardStatue",
		StatAttribute = "Stat", -- WeeklyIncome ou WeeklySteals, comme les panneaux
		Rig = "Rig", -- mannequin R15 (Humanoid, HumanoidRootPart seul ancré)
		NameLabel = "PlayerName", -- TextLabel de Pedestal/Body/Plate
		Height = 18, -- L-331 (Clément) : hauteur de chaque avatar, en studs, pieds sur le socle
		EmptyName = "???", -- L-331 : semaine vide, statue dorée
		BuildDepth = 60, -- V0 proposé (Cantin, 24/11) : studs sous la statue où l'avatar est habillé, hors de vue
		TestAttribute = "WeeklyStatueTest", -- Studio seulement : attribut du Workspace, UserId à montrer (0 = doré)
	},
	ScrollRefresh = 1, -- V0 proposé (Cantin, 24/11) : client, secondes entre deux contrôles des panneaux à défilement
}

-- Semaine (lundi 00:00 UTC) de l'heure `unix` (os.time()).
function WeeklyLeaderboard.WeekOf(unix: number): number
	local day = unix // WeeklyLeaderboard.DayLength
	return (day + WeeklyLeaderboard.MondayOffset) // 7
end

-- Heure UTC (os.time) du début de la semaine `week`.
function WeeklyLeaderboard.WeekStart(week: number): number
	return (week * 7 - WeeklyLeaderboard.MondayOffset) * WeeklyLeaderboard.DayLength
end

-- Valeur -> entier rangé (0 pour une valeur invalide).
function WeeklyLeaderboard.Encode(stat: string, value: number): number
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return 0
	end
	if value == math.huge then
		value = 1e36
	end
	local spec = WeeklyLeaderboard.Stats[stat]
	if spec and spec.Log then
		return math.round(math.log10(1 + value) * LOG_SCALE)
	end
	return math.min(math.floor(value), 2 ^ 53)
end

function WeeklyLeaderboard.Decode(stat: string, stored: number): number
	if type(stored) ~= "number" or stored ~= stored or stored <= 0 then
		return 0
	end
	local spec = WeeklyLeaderboard.Stats[stat]
	if spec and spec.Log then
		return math.max(0, 10 ^ (stored / LOG_SCALE) - 1)
	end
	return stored
end

-- Nom de l'OrderedDataStore d'un classement pour une semaine ; nil si la stat est inconnue.
function WeeklyLeaderboard.StoreName(stat: string, dev: boolean, week: number): string?
	local spec = WeeklyLeaderboard.Stats[stat]
	if spec == nil then
		return nil
	end
	return `{spec.Store}{if dev then WeeklyLeaderboard.DevSuffix else ""}_W{week}`
end

-- Récompense d'un rang (1 = premier), ou nil hors du top.
function WeeklyLeaderboard.RewardFor(rank: number): RewardTier?
	for _, tier in WeeklyLeaderboard.Rewards do
		if rank >= 1 and rank <= tier.MaxRank then
			return tier
		end
	end
	return nil
end

return DeepFreeze(WeeklyLeaderboard)
