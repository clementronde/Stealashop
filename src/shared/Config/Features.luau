--!strict
-- Interrupteurs des fonctions pas encore livrées (DEV-021 ; décision d'Ironix du 2026-11-07,
-- liaison L-026). false = la fonction n'existe pas encore : ses éléments d'UI sont cachés
-- (HudController). Repasser un interrupteur à true suffit à les réafficher, tels que Clément
-- les a posés (le code ne force jamais Visible = true ; ReturnToBase n'a plus d'UI, vague 38). NightCycle et ReturnToBase coupent aussi
-- leur service serveur (NightCycleService, ReturnBaseService) et le ciel animé (SkyController).
-- TruckEvent n'a pas d'UI : false coupe TruckEventService (aucun camion) et TruckController.
-- RobuxShop coupe aussi toute la boutique Robux (DEV-100) : MonetizationService (ni ProcessReceipt,
-- ni gamepass, ni bonus de revenus, ni effet) et RobuxShopController (écran UI_RobuxShop, comptoir).
-- Aperçus (L-071, décision de Clément du 2026-11-08 : les boutons Shop, Index et Rebirth du HUD sont
-- visibles dès maintenant) : RobuxShopPreview montre le bouton Shop et ouvre UI_RobuxShop en vitrine
-- tant que RobuxShop est false (RobuxShopController : aucun achat, aucun appel à MarketplaceService ;
-- le serveur reste coupé) ; RebirthPreview montre le bouton Rebirth et ouvre UI_Rebirth en aperçu
-- (RebirthController : la prochaine renaissance, sans confirmation) tant que la renaissance n'est pas
-- codée (Rebirth, DEV-120). Index passe à true (L-071) : l'index est codé par IndexController.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Features = {
	RobuxShop = false, -- MAJ 1, boutique Robux (5.9) : UI_HUD.RobuxShopButton, MonetizationService, RobuxShopController
	RobuxShopPreview = true, -- L-071 : avec RobuxShop à false, UI_HUD.RobuxShopButton visible et UI_RobuxShop en vitrine (aucun achat)
	Index = true, -- MAJ 2, index des objets : UI_HUD.IndexButton (L-071 : visible dès maintenant, IndexController)
	Rebirth = false, -- MAJ 3, renaissance (DEV-120, pas encore codée) : UI_HUD.RebirthButton
	RebirthPreview = true, -- L-071 : UI_HUD.RebirthButton visible et UI_Rebirth en aperçu (RebirthController), sans renaissance
	NightCycle = true, -- DEV-047, cycle jour/nuit (5.12) : UI_HUD.NightCountdown, NightCycleService, SkyController
	AntiCheat = true, -- DEV-060, contrôle des déplacements (9.6, Config/AntiCheat) : false coupe AntiCheatService (Allow et Verify ne font rien), aucune UI
	ReturnToBase = false, -- DEV-045, retour base : ReturnBaseService (remote ReturnToBase) ; plus de bouton UI_HUD.ReturnBaseButton depuis le 2026-11-14 (L-135 point 3, vague 38) ; false depuis la vague 41 (audit de sécurité du 14/11) : le remote, que plus aucun client n'envoie, est refusé sans effet par le serveur
	TruckEvent = true, -- L-049, événement camion (Config/TruckEvent) : TruckEventService, TruckController
	Settings = true, -- L-095 point 2, réglages : UI_HUD.SettingsButton (montré par SettingsController) et écran UI_Settings ; à false, les réglages sauvegardés s'appliquent quand même (sons, effets)
	ShelfOpen = true, -- L-112, ouverture des colis sur le rayon du magasin PNJ et antivol en base (Config/ShelfOpen) ; false = ancienne ouverture en base (colis rangé, posé, attente, rouleau), gardée en secours jusqu'à la validation en Play
	FortuneTower = false, -- L-108 point 8 (vague 37, a123), événement de la Fortune Tower (Config/FortuneTower) : FortuneTowerService, FortuneTowerController ; false tant que Clément n'a pas validé (en Studio, workspace:SetAttribute("FortuneTest", true) la fait quand même apparaître)
}

export type Features = typeof(Features)

return DeepFreeze(Features)
