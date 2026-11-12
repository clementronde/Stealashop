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
local Rarities = require(script.Parent.Rarities)

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
	-- Immunité après un vol subi (6.4) : plus courte que celle d'un joueur (120 s), le bot reste disponible
	-- pour le tuto du joueur suivant.
	TheftImmunity = 30,
	ArriveDelay = 5, -- s à 4 joueurs ou moins avant qu'il (re)vienne : pas d'aller-retour à chaque reconnexion
	CheckInterval = 1, -- présence revue chaque seconde (et tout de suite à l'arrivée d'un joueur)

	-- Modèle proposé à Clément (absent du contrat) : ReplicatedStorage/Assets/Bots/ShopBot, rig R15 avec
	-- Humanoid, HumanoidRootPart et Animations/Idle, sans script. Sans lui : avatar R15 par défaut de Roblox.
	AvatarFolder = "Bots",
	AvatarName = "ShopBot",
}

export type Bot = typeof(Bot)

return DeepFreeze(Bot)
