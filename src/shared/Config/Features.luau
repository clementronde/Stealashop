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
	RobuxCrate = false, -- vague 63 (L-200, L-204) : caisse exclusive de UI_RobuxShop_v2 (Monetization.Crate) ; false = section Crate cachée (contenu et chances pas décidés)
	Index = true, -- MAJ 2, index des objets : UI_HUD.IndexButton (L-071 : visible dès maintenant, IndexController)
	Rebirth = true, -- MAJ 3, renaissance (DEV-120, codée en V0 vague 51 : RebirthService, remote Rebirth) : UI_HUD.RebirthButton ; true depuis la vague 72 (a244 ; L-216 point 5, L-231 : au lancement, décision de Cantin)
	RebirthPreview = true, -- L-071 : UI_HUD.RebirthButton visible et UI_Rebirth en aperçu (RebirthController), sans renaissance
	NightCycle = true, -- DEV-047, cycle jour/nuit (5.12) : UI_HUD.NightCountdown, NightCycleService, SkyController
	AntiCheat = true, -- DEV-060, contrôle des déplacements (9.6, Config/AntiCheat) : false coupe AntiCheatService (Allow et Verify ne font rien), aucune UI
	ReturnToBase = false, -- DEV-045, retour base : ReturnBaseService (remote ReturnToBase) ; plus de bouton UI_HUD.ReturnBaseButton depuis le 2026-11-14 (L-135 point 3, vague 38) ; false depuis la vague 41 (audit de sécurité du 14/11) : le remote, que plus aucun client n'envoie, est refusé sans effet par le serveur
	TruckEvent = true, -- L-049, événement camion (Config/TruckEvent) : TruckEventService, TruckController
	Settings = true, -- L-095 point 2, réglages : UI_HUD.SettingsButton (montré par SettingsController) et écran UI_Settings ; à false, les réglages sauvegardés s'appliquent quand même (sons, effets)
	GuardChaseV2 = true, -- vague 45 (Cantin, 2026-11-14), poursuite du vigile de magasin (Config/Chase) : ruée jusqu'à 10 studs, puis distance gardée selon la Speed du voleur ; false = l'ancienne vitesse (Zones[zone].GuardSpeed)
	FortuneTower = true, -- L-108 point 8 (vague 37, a123), événement de la Fortune Tower (Config/FortuneTower) : FortuneTowerService, FortuneTowerController ; true depuis la validation de Clément (L-145 réponse (a), vague 42) ; sans ENV_Event_FortuneVault, rien en jeu publié (bloc V0 en Studio seulement) ; en Studio, workspace:SetAttribute("FortuneTest", true) la fait apparaître tout de suite
	WeeklyChest = false, -- MAJ 1, coffre hebdomadaire (DEV-101, Partie 2 3.3 ; Config/Rewards.Weekly) : RewardService (remote ClaimWeekly), RewardsController (UI_Rewards.WeeklyChest, facultatif) ; false = rien ne change en jeu ; en Studio, workspace:SetAttribute("WeeklyChestTest", true) l'allume
	-- Vague 62 (Cantin et Clément, 2026-11-15, L-198) : un seul colis par braquage, cinématique d'ouverture, poids des
	-- objets (Config/Weight, Shared/ItemWeight : taille, revenu, Huge et Colossal par le poids) ; false = l'ouverture
	-- et les mutations de taille d'avant (Tiny, Big, Huge, Colossal tirées à part).
	SingleBoxReveal = true, -- vague 62 (Cantin et Clément, 2026-11-15 ; L-198) : un seul colis par braquage, tirage par la boîte seule, cinématique d'ouverture vue par tous (RevealController, Config/Reveal), objet pris d'office ; false = l'ouverture d'avant (aucun RevealStarted, RevealController ne fait rien)
	-- Vague 63 (a210, L-205) : les 8 auras de Clément (Shine à Chained) à la place des 6 anciennes, proposition à
	-- valider par Clément (Config/Cosmetics.NewAuras) ; true = boutique des 8 et migration des anciennes au chargement
	-- du profil (Cosmetics.Migration, CosmeticService) ; false = la boutique d'aujourd'hui, rien ne change.
	-- Vague 66 (a218, L-210 point 8) : true, prix validés par Clément (L-210 : « OK à tout ») ; le simulateur v2
	-- tourne avec les 8 auras (tools/ironix/equilibrage, RAPPORT=v2).
	NewAuras = true,
	-- Vague 66 (a221, L-210 point 4) : la foule de PNJ qui filme et photographie le voleur à sa sortie d'un magasin PNJ
	-- (Config/Witness.Crowd, WitnessCrowdController, client seul, aucun remote) ; false = rien ne change.
	WitnessCrowd = true,
	-- Vague 72 (a243, L-218, L-216 point 11) : pièges de la boutique (Config/Traps, TrapService, TrapController ; tuile
	-- Traps de Config/SkillTree achetable) ; false = aucun piège posé, tuile « Soon » ; en Studio,
	-- workspace:SetAttribute("TrapsTest", true) les allume sans toucher à cette ligne.
	Traps = false,
}

export type Features = typeof(Features)

return DeepFreeze(Features)
