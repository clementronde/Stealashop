--!strict
-- Vol entre joueurs et règles anti-frustration (Partie 1, sections 6, 6.1, 6.2 et 6.4).
-- Régénération de la vitrine : Balance.Window ; malus de portage −25 % :
-- Balance.Carry.StolenItemSpeedMultiplier ; batte : Bat.

local DeepFreeze = require(script.Parent.DeepFreeze)

local PvP = {
	-- 6 : PV de la vitrine d'un joueur = 50 × les dégâts par coup de son propriétaire
	-- (Formulas.PlayerWindowHP). Même niveau : environ 9 s pour la casser.
	PlayerWindowHPPerDamage = 50,

	-- 6.1 : voler un joueur
	ScoutDistance = 15, -- panneau propriétaire, valeur exposée, PV de la vitrine
	StealDuration = 10, -- temps pour prendre un objet exposé après la casse
	StealGrabTime = 1.0,

	-- 6.2, usage 1 : défense de sa boutique
	AdrenalineSpeedBonus = 0.25, -- +25 % de vitesse pour la victime jusqu'à la fin de la poursuite
	AutoEquipBatOnAlert = true,

	-- 6.4 : règles anti-frustration (non négociables)
	BeginnerShieldDuration = 10 * 60, -- 10 premières minutes de jeu cumulées : boutique inviolable, colis non frappable
	TheftImmunityDuration = 120, -- vitrine invulnérable après un vol subi
	AntiRacketRatio = 0.1, -- impossible de voler un joueur dont la valeur exposée est < 10 % de la sienne
	VaultSlots = 1, -- coffre-fort offert : au moins 1 objet toujours à l'abri (9.5, VaultSlot_01)
}

export type PvP = typeof(PvP)

return DeepFreeze(PvP)
