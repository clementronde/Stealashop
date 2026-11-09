--!strict
-- Gains hors ligne (DEV-102 ; Partie 2, section 3 « Gains hors ligne » ; liaison L-084, point 1).
-- Lu par OfflineService (serveur). Au retour, la boutique du joueur a gagné, pendant son absence :
--   absence (s, au plus MaxHours h) × revenu par seconde au départ × Rate
-- revenu au départ = objets exposés × bonus permanents (Premium, ×2 Argent, index), sans les boosts
-- temporaires (boost ×2 argent, compté seulement en jeu : Partie 2, section 4). L'argent va dans la caisse
-- de sa boutique (attribut CashRegister), il l'encaisse sur son CashPad comme le reste.
--
-- Le doc (Partie 2) disait « 10 % des revenus pendant 4 h max » ; Clément a décidé le 2026-11-08 (L-084,
-- journal 15) « tout l'argent qu'il aurait gagné pendant son absence », validé par Ironix le 2026-11-09
-- (Rate = 1, 100 %). Plafond : celui du doc (4 h), à valider avec Clément.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Offline = {
	-- Part des revenus gagnée hors ligne : 1 = 100 % (Clément, L-084 ; validé par Ironix le 2026-11-09).
	Rate = 1,
	-- Plafond de l'absence comptée, en heures (doc, Partie 2). À valider avec Clément.
	MaxHours = 4,
	-- V0 proposé, absent du doc : toutes les SnapshotInterval s de jeu, l'heure et le revenu sont écrits
	-- dans le profil (Offline.LastSeenAt et Offline.Income), pour qu'un serveur qui plante ne fasse pas
	-- perdre l'absence (la sauvegarde automatique de ProfileStore passe toutes les 5 min).
	SnapshotInterval = 5,
	-- V0 proposé, absent du doc : délai (s) entre le chargement du profil et le message, le temps que le
	-- personnage et le HUD apparaissent.
	NotifyDelay = 3,
	-- Message au retour (Notify « Info »), en anglais (L-036) ; %s = la somme (Format.money, « $1.2M »).
	-- Envoyé seulement si le gain atteint 1 $.
	Message = "Your shop earned %s while you were away!",
	-- Studio seulement : workspace:SetAttribute(TestAttribute, "<joueur> <secondes>") simule une absence
	-- de ce nombre de secondes (barre de commande serveur ; joueur = nom ou UserId). Voir OfflineService.
	TestAttribute = "OfflineTest",
}

export type Offline = typeof(Offline)

return DeepFreeze(Offline)
