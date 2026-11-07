--!strict
-- Interrupteurs des fonctions pas encore livrées (DEV-021 ; décision d'Ironix du 2026-11-07,
-- liaison L-026). false = la fonction n'existe pas encore : ses éléments d'UI sont cachés
-- (HudController). Repasser un interrupteur à true suffit à les réafficher, tels que Clément
-- les a posés (le code ne force jamais Visible = true). NightCycle et ReturnToBase coupent aussi
-- leur service serveur (NightCycleService, ReturnBaseService) et le ciel animé (SkyController).

local DeepFreeze = require(script.Parent.DeepFreeze)

local Features = {
	RobuxShop = false, -- MAJ 1, boutique Robux (5.9) : UI_HUD.RobuxShopButton
	Index = false, -- MAJ 2, index des objets : UI_HUD.IndexButton
	Rebirth = false, -- MAJ 3, renaissance : UI_HUD.RebirthButton
	NightCycle = true, -- DEV-047, cycle jour/nuit (5.12) : UI_HUD.NightCountdown, NightCycleService, SkyController
	ReturnToBase = true, -- DEV-045, bouton Retour base : UI_HUD.ReturnBaseButton, ReturnBaseService
}

export type Features = typeof(Features)

return DeepFreeze(Features)
