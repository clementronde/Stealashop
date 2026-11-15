--!strict
-- Vol entre joueurs et règles anti-frustration (Partie 1, sections 6, 6.1, 6.2 et 6.4).
-- Régénération de la vitrine : Balance.Window ; vitesse fixe du voleur qui porte l'objet :
-- Balance.Carry.StolenItemWalkSpeed ; batte : Bat. Règles de jeu : PvPService (serveur) et
-- PvPController (client).

local DeepFreeze = require(script.Parent.DeepFreeze)

local PvP = {
	-- 6 : PV de la vitrine (porte) d'un joueur. Vague 29 (Clément, L-106 point 3 et L-098) : ils ne
	-- viennent plus des dégâts du propriétaire mais d'une base fixe par niveau de boutique (attribut
	-- StageLevel, ShopStageService), que l'arbre multiplie (Glass, Walls). V0 proposé, absent du doc :
	-- base = 50 × les dégâts conseillés de la zone du même rang (Zones[niveau].AdvisedDamage), soit
	-- 50, 500, 4 000, 30 000, 250 000 (Formulas.PlayerWindowHP) : sans arbre, un joueur du même rang
	-- la casse en 9 s environ, comme l'ancienne règle « 50 × ».
	-- Plus lu pour les portes depuis L-163 (a159, ci-dessous) : reste pour Formulas.PlayerWindowHP.
	PlayerWindowHPPerDamage = 50,
	-- L-163 (décision de Clément, 2026-11-14 au soir, avec sa correction « 40 coups ») : n'importe qui peut braquer
	-- n'importe qui. La porte d'une boutique (joueur ou bot) se casse en NOMBRE DE COUPS, le même pour tous :
	-- un coup validé = 1, quelle que soit la force du voleur ou du propriétaire (arme, aura, potion). La force ne
	-- sert plus qu'aux vitrines des magasins PNJ et aux événements. Reinforced Door (GlassThickness) ajoute des
	-- coups (Config/SkillTree). V0 à valider par Cantin :
	DoorHits = 40, -- coups de base : 8 s seul à Balance.Hit.MaxHitsPerSecond (5), hors réparation
	-- La porte encaisse au plus ce nombre de coups par seconde, tous voleurs confondus (un coup compté au plus
	-- toutes les 1/8 s) : à deux ou plus, 40 coups en 5 s environ (hors réparation). Les coups en trop sont ignorés.
	DoorMaxHitsPerSecond = 8,

	-- 6.1 : voler un joueur
	ScoutDistance = 15, -- panneau propriétaire, valeur exposée, PV de la vitrine
	-- Vague 33 (Cantin, 2026-11-13) : plus de chrono pour voler un joueur ; ne sert plus qu'au délai de
	-- reconstruction de sa porte (StealDuration + Balance.Window.RebuildDelay après la casse, au plus tôt,
	-- et pas tant qu'un intrus est dedans : WindowService, PvPService).
	StealDuration = 10,
	StealGrabTime = 1.0,
	StealMaxDistance = 8, -- V0 proposé, absent du doc : comme GrabItem (9.4), du voleur au présentoir

	-- 6.2, usage 1 : défense de sa boutique
	AdrenalineSpeedBonus = 0.25, -- +25 % de vitesse pour la victime jusqu'à la fin de la poursuite
	AutoEquipBatOnAlert = true,
	-- Alerte de la victime (DEV-042) : serveur TheftAlertService (Adrénaline, défenses comptées),
	-- client TheftAlertController (bannière, sirène, flèche, voleur surligné).
	AlertSirenSound = "TheftAlert_Siren", -- V0 proposé, absent du doc : Sound de Clément dans ReplicatedStorage/Assets/Sounds (DEV-051), pas encore livré

	-- 6.4 : règles anti-frustration. Décision de Cantin (2026-11-12) : plus aucune protection des
	-- boutiques, tout le monde peut voler tout le monde (ni bouclier débutant sur la boutique, ni
	-- immunité après un vol subi, ni anti-racket). Restent : le coffre-fort, les 3 s d'immunité aux
	-- coups de batte (Bat.HitImmunity) et le bouclier débutant sur le colis PNJ porté.
	BeginnerShieldDuration = 10 * 60, -- 10 premières minutes de jeu cumulées : son colis PNJ ne tombe pas à la batte
	-- Défense par le propriétaire (Cantin, 2026-11-12) : un joueur frappé à la batte par le propriétaire
	-- dans sa boutique (ou en fuite avec un de ses objets), ou mort dans la boutique d'un autre, est sorti
	-- et ne peut plus voler CETTE boutique pendant ce nombre de secondes (porte et objets).
	KickRobCooldown = 60,
	-- Coffre-fort offert : au moins 1 objet toujours à l'abri. V0 (PvPService) : les VaultSlots objets
	-- exposés qui rapportent le plus ne sont jamais volables (« présentoirs non volables », Partie 2,
	-- section 2) ; ils restent sur leur présentoir et rapportent. Coffre physique (VaultSlot_01, champ
	-- Vault du profil, 9.5) : MAJ 2 (DEV-110).
	VaultSlots = 1,
}

export type PvP = typeof(PvP)

return DeepFreeze(PvP)
