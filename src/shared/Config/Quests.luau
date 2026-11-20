--!strict
-- Quêtes quotidiennes (DEV-132, UI-130 ; vague 80, a266). Lu par QuestService (serveur : tirage, compte, don) et
-- QuestController (client : écran UI_Quests, bouton du HUD). Coupées par Features.Quests.
--
-- Toutes les valeurs sont des V0 proposés (Cantin, 20/11), absentes du doc, sauf « 3 quêtes par jour » et « remise à
-- zéro à minuit UTC » (consigne de la vague 80, comme Config/Rewards).
--
-- Règle : chaque jour UTC, PerDay quêtes différentes sont tirées (poids Weight) pour chaque joueur, à son premier
-- passage du jour (chargement du profil, ou minuit UTC en jeu). Le serveur compte seul la progression, à partir des
-- événements du jeu (aucun remote ne fait avancer une quête) ; le joueur réclame une quête finie (remote ClaimQuest),
-- le serveur donne la récompense (lot de Config/Wheel.Prize). Une quête pas réclamée à minuit UTC est perdue.
--
-- Événements comptés (QuestService) :
--   Heist        objet volé en magasin rapporté sous antivol en zone safe (UnboxService.OnItemStowed) ;
--   OpenBox      objet sorti d'un colis de magasin ou du camion et pris en main (CarryService.OnCarryStarted, objet
--                NPCItem vu pour la première fois ; pas la pluie d'objets) ;
--   EarnCash     argent gagné, toutes sources sauf les lots des quêtes et de la roue (DataService.OnCashChanged) ;
--                l'objectif est fixé au tirage : GoalMinutes minutes de revenus du joueur à ce moment-là (au moins
--                Rewards.MinCashPerMinute $ par minute), comme les récompenses « X min de revenus » ;
--   Treadmill    secondes passées sur un tapis (TrainingService.IsTraining, compté chaque seconde) ;
--   StealPlayer  objet volé à un autre joueur ou à un bot et déposé chez soi (PvPService.OnTheftEnded « Stolen »,
--                BotService.OnTheft « Stolen ») ;
--   BreakWindow  vitrine de magasin PNJ cassée par le joueur (WindowService.OnBroken, Kind NPC, Breaker).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Wheel = require(script.Parent.Wheel)

export type Event = "Heist" | "OpenBox" | "EarnCash" | "Treadmill" | "StealPlayer" | "BreakWindow"

export type Quest = {
	Id: string, -- clé gardée dans le profil (jamais changer celle d'une quête en jeu)
	Event: Event,
	Goal: number?, -- objectif fixe (nombre, ou secondes pour Treadmill)
	GoalMinutes: number?, -- EarnCash : objectif en minutes de revenus, fixé au tirage
	Text: string, -- texte de QuestName (anglais) ; %s = l'objectif écrit (« 3 », « $12.5K », « 3:00 »)
	Reward: Wheel.Prize,
	RewardText: string, -- texte de RewardLabel (anglais)
	Weight: number, -- poids du tirage du jour
	Icon: string?, -- Decal ICON_<Icon> livré par Clément (Contract/Icons) ; absent : l'icône du Template reste
}

local Quests = {
	-- Consigne de la vague 80 : 3 quêtes par jour.
	PerDay = 3,

	-- V0 proposé (Cantin, 20/11) : 6 quêtes, objectifs pensés pour 10 à 20 min de jeu chacune.
	List = {
		{
			Id = "Heist",
			Event = "Heist",
			Goal = 3, -- V0 proposé (Cantin, 20/11)
			Text = "Rob %s stores", -- V0 proposé (Cantin, 20/11)
			Reward = { Kind = "Cash", Minutes = 10 }, -- V0 proposé (Cantin, 20/11)
			RewardText = "10 min cash",
			Weight = 3, -- V0 proposé (Cantin, 20/11)
			Icon = "QUEST_Heist",
		},
		{
			Id = "OpenBoxes",
			Event = "OpenBox",
			Goal = 3, -- V0 proposé (Cantin, 20/11)
			Text = "Open %s boxes",
			Reward = { Kind = "Box", Tier = "Standard" }, -- V0 proposé (Cantin, 20/11)
			RewardText = "Standard item",
			Weight = 3, -- V0 proposé (Cantin, 20/11)
			Icon = "QUEST_OpenBoxes",
		},
		{
			Id = "EarnCash",
			Event = "EarnCash",
			GoalMinutes = 15, -- V0 proposé (Cantin, 20/11) : 15 min de revenus
			Text = "Earn %s",
			Reward = { Kind = "Boost", Minutes = 10 }, -- V0 proposé (Cantin, 20/11)
			RewardText = "x2 cash 10 min",
			Weight = 3, -- V0 proposé (Cantin, 20/11)
			Icon = "QUEST_EarnCash",
		},
		{
			Id = "Treadmill",
			Event = "Treadmill",
			Goal = 180, -- V0 proposé (Cantin, 20/11) : 3 min de tapis
			Text = "Run %s on the treadmill",
			Reward = { Kind = "Cash", Minutes = 5 }, -- V0 proposé (Cantin, 20/11)
			RewardText = "5 min cash",
			Weight = 2, -- V0 proposé (Cantin, 20/11)
			Icon = "QUEST_Treadmill",
		},
		{
			Id = "StealPlayer",
			Event = "StealPlayer",
			Goal = 1, -- V0 proposé (Cantin, 20/11)
			Text = "Steal %s item from a player",
			Reward = { Kind = "Box", Tier = "Premium" }, -- V0 proposé (Cantin, 20/11)
			RewardText = "Premium item",
			Weight = 1, -- V0 proposé (Cantin, 20/11)
			Icon = "QUEST_StealPlayer",
		},
		{
			Id = "BreakWindow",
			Event = "BreakWindow",
			Goal = 3, -- V0 proposé (Cantin, 20/11)
			Text = "Break %s store windows",
			Reward = { Kind = "Potion", Potion = "Money", Count = 1 }, -- V0 proposé (Cantin, 20/11)
			RewardText = "Money potion",
			Weight = 2, -- V0 proposé (Cantin, 20/11)
			Icon = "QUEST_BreakWindow",
		},
	} :: { Quest },
	-- Quête par Id (rempli plus bas depuis List).
	ById = {} :: { [string]: Quest },

	-- Longueur d'un jour UTC (comme Config/Rewards.DayLength).
	DayLength = 86400,
	-- V0 proposé (Cantin, 20/11) : cadence (s) du compte du tapis, de minuit UTC et des attributs.
	Tick = 1,

	-- Attributs du Player, écrits par QuestService seulement, lus par QuestController. <i> = 1 à PerDay.
	Attributes = {
		Id = "Quest%d", -- Id de la quête de la place i
		Progress = "Quest%dProgress", -- progression (entière, bornée à Goal)
		Goal = "Quest%dGoal", -- objectif
		Claimed = "Quest%dClaimed", -- true : réclamée
		EndsAt = "QuestsEndsAt", -- heure serveur (GetServerTimeNow) du prochain minuit UTC
	},

	-- Studio seulement (QuestService), barre de commande serveur :
	--   workspace:SetAttribute("QuestTest", "days <n>")                 avance l'horloge des quêtes de n jours
	--   workspace:SetAttribute("QuestTest", "add <joueur> <Event> <n>") ajoute n à cet événement
	--   workspace:SetAttribute("QuestTest", "done <joueur>")            finit ses 3 quêtes
	--   workspace:SetAttribute("QuestTest", "reroll <joueur>")          retire ses quêtes du jour
	TestAttribute = "QuestTest",

	-- Textes et messages, en anglais (L-036). V0 proposés (Cantin, 20/11).
	Messages = {
		Complete = "Quest complete! Claim your reward.",
		NotDone = "Finish this quest first!",
		Claimed = "Quest reward already claimed.",
		ProgressFormat = "%s/%s",
		ClaimText = "CLAIM",
		ClaimedText = "DONE",
		Timer = "New quests in %s", -- %s = « 12:34:56 »
	},
}

for _, quest in Quests.List do
	Quests.ById[quest.Id] = quest
end

export type Quests = typeof(Quests)

return DeepFreeze(Quests)
