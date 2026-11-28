--!strict
-- Objet tenu en main (demande de Cantin du 2026-11-14, agent a142) : un objet de l'inventaire choisi dans la
-- barre du bas UI_Hotbar va dans la main du joueur, comme un outil, à la taille qu'il a sur un présentoir
-- (HeldItemService, serveur ; HotbarController et InventoryController, client).
--
-- Toutes les valeurs sont des V0 proposés, absents du doc. Unités : studs, degrés, secondes.
--
-- Prise en main (Tool.Grip) : repère de la main droite pendant la pose « outil en main » de Roblox (bras
-- tendu devant) : X vers la droite du joueur, Y vers le haut, -Z devant lui. Boîte de l'objet = boîte de
-- ses pièces dans le repère de son pivot, sans la pièce du halo (RarityHalo), mutation de taille comprise.
--   - petit objet (plus grand côté ≤ LargeSize) : tenu au bout de la main, son centre à la hauteur de la
--     main, sa face arrière à Forward studs devant elle ;
--   - gros objet (plus grand côté > LargeSize : souvent Big, Huge, Colossal) : tenu par-dessous, devant le
--     corps : son bas à LargeBelowHand studs sous la main, décalé de LargeCenterShift studs vers la gauche
--     (la main droite est à environ 1,5 stud du milieu du corps d'un R15), sa face arrière à Forward studs
--     devant la main. Il monte au-dessus de la main au lieu de traîner par terre et reste centré devant
--     le joueur, lisible pour les autres.
-- Yaw : rotation de l'objet autour de la verticale (0 = sa face avant -Z regarde devant le joueur, comme
-- s'il le montrait ; 180 = tournée vers lui). Seuls 0 et 180 gardent la règle de la face arrière.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a469 : module de Config chargé s'il est là (bancs à liste de modules fixe), comme Config/Outlines.
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")

local HeldItem = {
	Forward = 0.1, -- V0 proposé, absent du doc : studs entre la main et la face arrière de l'objet
	-- V0 proposé, absent du doc : plus grand côté (studs) au-delà duquel l'objet est « gros ». a418 (décision de Cantin
	-- 23/11, variante A2) : 5 (avant 2,5), sinon l'objet de base (3,2 studs) serait tenu par-dessous devant le torse.
	LargeSize = 5,
	LargeBelowHand = 0.6, -- V0 proposé, absent du doc : studs entre le bas d'un gros objet et la main
	LargeCenterShift = 1.5, -- V0 proposé, absent du doc : studs vers la gauche (gros objet centré devant le corps)
	Yaw = 0, -- V0 proposé, absent du doc : degrés
	-- Revérification de l'objet tenu (encore à lui, pas exposé, pas vendu, pas au coffre-fort, pas posé au sol).
	-- Chaque changement de l'inventaire la fait aussi tout de suite.
	CheckInterval = 0.25, -- V0 proposé, absent du doc : secondes
	-- Vague 44 (a152, réponse de Cantin du 2026-11-14 : « oui en main ») : un objet volé ramené à sa boutique
	-- (PvPService, dépôt) va dans la main du voleur s'il a les mains libres, sinon dans la barre du bas ou
	-- l'inventaire, jamais tout seul sur un présentoir (inventaire plein : le vol échoue, l'objet revient).
	-- false : l'ancien déroulé (présentoir libre le plus proche, sinon l'inventaire).
	DepositToHand = true,
	-- Noms posés par HeldItemService (lus par InventoryController et HotbarController) :
	ToolAttribute = "HeldItemUid", -- sur le Tool de l'objet tenu : son uid
	PlayerAttribute = "HeldItem", -- sur le Player : uid de l'objet tenu, absent sinon
	ModelName = "HeldItem", -- le modèle de l'objet, dans le Tool
	CarriedTag = "CarriedItem", -- tag de code de CarryService : MutationFxController y montre l'effet de la mutation
	-- a178 : objet tenu encore sous antivol (profil AntiTheft) ; UnboxController y pose BB_AntiTheft. UnlockAt =
	-- heure serveur de la fin (absent : antivol pas encore lancé, verrou montré sans minuteur).
	LockedAttribute = "AntiTheft",
	UnlockAtAttribute = "UnlockAt",
	-- a469 (Cantin, 25/11 : « il y a que moi qui le vois, faudrait que tous les joueurs le voient ») : le revenu de
	-- l'objet tenu ($/s, mutation et poids compris, sans bonus : la règle d'InventoryService) est posé par le serveur
	-- sur le Tool (HeldItemService) et HeldIncomeController montre BB_HeldIncome au-dessus de l'objet tenu par chaque
	-- joueur, pas seulement le sien. Allumé partout (Features.HeldIncomeAll) ou dans le jeu DEV seulement
	-- (Features.HeldIncomeAllDev et ProductIds.IsDev) ; coupé : rien n'est posé, le porteur seul le voit (comme avant).
	IncomeForAll = Features.HeldIncomeAll == true or (Features.HeldIncomeAllDev == true and ProductIds.IsDev == true),
	IncomeAttribute = "HeldIncome", -- sur le Tool : $/s de l'objet (nombre), écrit par le serveur seul
}

export type HeldItem = typeof(HeldItem)

return DeepFreeze(HeldItem)
