--!strict
-- Bot joueur (liaison L-085 point 4, L-105 point 1, L-108 point 3 ; attendu pour le lancement). Règles de
-- Clément : quand le serveur compte 0 à 4 vrais joueurs, un bot occupe une boutique libre, au niveau de
-- boutique le plus faible, avec les objets les plus faibles (Communs de la zone 1) exposés. Il part quand un
-- 5e vrai joueur arrive ou qu'une boutique manque à un vrai joueur. On le braque comme un joueur (casser sa
-- porte, prendre un objet, le ramener chez soi) ; le tuto s'en sert pour montrer le vol entre joueurs.
-- Serveur : BotService (présence, objets, avatar) et PvPService (vol) ; client : PvPController (panneau,
-- invites). Tout ce qui n'est pas une règle de Clément est V0 proposé, absent du doc.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)
local Bat = require(script.Parent.Bat)
local PvP = require(script.Parent.PvP)
local Rarities = require(script.Parent.Rarities)
local Tutorial = require(script.Parent.Tutorial)
local Zones = require(script.Parent.Zones)

local Bot = {
	Enabled = true, -- false : aucun bot sur le serveur
	MaxRealPlayers = 4, -- L-105 : le bot est là de 0 à 4 vrais joueurs ; il part au 5e
	DisplayName = "Bot", -- V0 proposé : panneau « Bot's Shop », nom au-dessus de son avatar (anglais, L-036)

	-- L-105 : les objets les plus faibles, sur les présentoirs d'une boutique neuve (niveau le plus faible).
	Zone = 1,
	Rarity = "Common" :: Rarities.RarityId,
	ItemCount = Balance.Display.StartSlots, -- 4 présentoirs de départ (5.8)

	-- Porte du niveau le plus faible : PV de base d'une boutique de niveau 1, Formulas.PlayerWindowHP(1) (vague
	-- 29, a93 : 50 × les dégâts conseillés de la zone 1 = 50 ; avant a93 : 50 × 1 dégât, celui d'un profil
	-- neuf, aussi 50), sans Glass ni Walls, régénération de base (5.3).
	StageLevel = 1,

	-- V0 proposés, absents du doc :
	RegenDelay = 60, -- un objet volé au bot revient (un autre Commun de la zone 1) 60 s après le dépôt
	-- Plus d'immunité après un vol subi (Cantin, 2026-11-12 : aucune protection des boutiques).
	ArriveDelay = 5, -- s à 4 joueurs ou moins avant qu'il (re)vienne : pas d'aller-retour à chaque reconnexion
	CheckInterval = 1, -- présence revue chaque seconde (et tout de suite à l'arrivée d'un joueur)

	-- Modèle proposé à Clément (absent du contrat) : ReplicatedStorage/Assets/Bots/ShopBot, rig R15 avec
	-- Humanoid, HumanoidRootPart et Animations/Idle, sans script. Sans lui : avatar R15 par défaut de Roblox.
	AvatarFolder = "Bots",
	AvatarName = "ShopBot",

	-- Vague 37 (a124, L-117 point 7, demandé par Cantin) : le bot défend sa boutique (BotService, voir son
	-- en-tête). Quand un joueur casse sa porte ou lui prend un objet, son avatar se désancre, court vers lui et le
	-- frappe à la batte (BatService.BotSwing : mêmes règles et mêmes effets qu'un coup du propriétaire), puis
	-- rentre à son point d'apparition et se ré-ancre. Toutes ces valeurs sont des V0 proposés, absents du doc,
	-- dérivés de valeurs existantes (calcul en commentaire).
	Defense = {
		Enabled = true, -- false : le bot ne bouge jamais (avatar ancré comme avant la vague 37)
		-- WalkSpeed du bot = celui du vigile de la zone 1 (Zones[1].GuardSpeed = 0,9 × 16 − 1 = 13,4) : la boutique du
		-- bot est au niveau de la zone 1 ; un voleur qui porte (Balance.Carry.StolenItemWalkSpeed = 16) le distance,
		-- comme on distance ce vigile. Le bot ne rattrape que celui qui traîne dans sa boutique.
		RunSpeed = Zones[1].GuardSpeed,
		-- Pendant le tuto du joueur poursuivi (TutorialService.IsActive) : la vitesse du vigile lent du tuto
		-- (Tutorial.GuardSpeed = 12), et au plus TutorialMaxStrikes coup réussi sur ce joueur pendant son tuto.
		TutorialRunSpeed = Tutorial.GuardSpeed,
		TutorialMaxStrikes = 1,
		-- Le coup : il lance SwingBat à Bat.Range (7) studs de sa cible au plus, une fois toutes les Bat.Cooldown
		-- (0,8) s au plus, comme un joueur ; BatService revérifie tout au marqueur Impact.
		SwingRange = Bat.Range,
		SwingCooldown = Bat.Cooldown,
		-- Abandon : la cible est à plus de PvP.ScoutDistance (15) studs du volume Bounds de sa boutique (la distance
		-- du panneau de repérage : « être à la boutique »), ou la poursuite dure depuis plus de
		-- Balance.Guard.IntruderChaseTime (10) s (l'abandon du vigile qui chasse un intrus, « environ 10 secondes »,
		-- Cantin). Un nouveau déclenchement (porte cassée, objet pris) relance le temps.
		LeashDistance = PvP.ScoutDistance,
		GiveUpTime = Balance.Guard.IntruderChaseTime,
		-- Retour : ré-ancré au point d'apparition à 2 studs au plus de lui (à l'horizontale : moins que la moitié de
		-- Balance.Guard.CatchDistance, 4) ; pas arrivé au bout de GiveUpTime s, il y est replacé d'un coup.
		HomeDistance = Balance.Guard.CatchDistance / 2,
		ReturnTimeout = Balance.Guard.IntruderChaseTime,
		-- Chemin simple : entre l'intérieur et l'extérieur, il passe par la porte (PlotDoor/Window) ; le point de
		-- passage est atteint à 3 studs (Bat.PointBlankRange). Contrôle 10 fois par seconde (comme PvPService).
		DoorPassDistance = Bat.PointBlankRange,
		Tick = 0.1,
	},
}

export type Bot = typeof(Bot)

return DeepFreeze(Bot)
