--!strict
-- Boutons Robux en situation du HUD (vague 59, a190 ; liaison L-182 point 7, L-183 `RightRail`) : « x2 vitesse »
-- sur un tapis et « zZz » dans le couloir. TOUT EST UNE PROPOSITION (V0 proposé, absent du doc) : règles, prix,
-- durées et recharge sont à valider par Clément avant d'être codés côté serveur.
--
-- État aujourd'hui : les boutons se montrent selon leur règle (HudMenuController), écrivent leur prix dans
-- Price.Amount, mais n'achètent rien : Ready = false (l'effet n'est pas codé côté serveur) et Features.RobuxShop
-- = false. Un clic montre seulement « Soon » (même mot que la vitrine de la boutique Robux). Quand l'effet sera
-- codé : produit développeur créé AU NOM DU GROUPE (Id), Ready = true, reçu traité par MonetizationService
-- (achat idempotent, PurchaseId stocké), et ces deux offres pourront rejoindre Config/Monetization.Products.
--
-- ShowWhen (règle d'affichage, lue par le client) :
--   "OnTreadmill"   attribut TrainingMachine du Player = "Treadmill" (TrainingService) ;
--   "InCorridor"    zone du joueur (ZoneGateController.GetZone) au moins MinZone (1 = première zone du couloir).
-- CooldownAttribute : heure serveur (workspace:GetServerTimeNow) de fin de recharge, posée par le serveur sur
-- CooldownHolder (« Workspace » pour une recharge de tout le serveur, « Player » pour celle du joueur). Rien ne la
-- pose encore : Cooldown reste caché.
-- a285 (21/11, L-067) : Id = produit de PROD ; dans le jeu DEV, Config/ProductIds le remplace par celui de DEV
-- (clé = Key ; 0 tant qu'il n'y est pas créé), avant le gel du module.

local DeepFreeze = require(script.Parent.DeepFreeze)
-- a285 : Config/ProductIds chargé s'il est là (bancs d'essai à liste de modules fixe) ; sans lui, les Ids de PROD.
local ProductIds: { Pick: (key: string, prodId: number) -> number } = (function(): any
	local module = script.Parent:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {
		Pick = function(_: string, prodId: number): number
			return prodId
		end,
	}
end)()

export type Boost = {
	Key: string,
	Button: string, -- bouton de UI_HUD (RightRail), caché par Clément, montré par la règle
	ShowWhen: string,
	MinZone: number?,
	Id: number, -- produit développeur (0 = pas encore créé)
	Price: number, -- Robux
	Ready: boolean, -- effet codé côté serveur
	Duration: number, -- s
	CooldownAttribute: string?,
	CooldownHolder: string?,
	[string]: any,
}

local Boosts = {
	SoonText = "Soon",
	List = {
		-- « x2 vitesse » : × 2 sur les gains du tapis pendant 10 min (s'ajoute au gamepass ×2 Training : × 4) ;
		-- racheté pendant l'effet, la durée s'allonge (60 min au plus). Pas de recharge.
		{
			Key = "SpeedBoost",
			Button = "SpeedBoostButton",
			ShowWhen = "OnTreadmill",
			Id = 0,
			Price = 29,
			Ready = false,
			Multiplier = 2,
			Duration = 600,
			MaxDuration = 3600,
			StacksWithGamepass = true,
		},
		-- « zZz » : endort tous les vigiles et policiers du serveur pendant 60 s (les « Zzz » existent déjà) ;
		-- tout le serveur en profite (moment partagé, « X a endormi les vigiles ! »), puis 5 min de recharge pour
		-- tout le serveur, qui part de l'achat. Autre règle possible, à choisir par Clément : le joueur seul
		-- (les vigiles l'ignorent 60 s), 39 R$, 2 min de recharge pour lui.
		{
			Key = "SleepGuards",
			Button = "SleepButton",
			ShowWhen = "InCorridor",
			MinZone = 1,
			Id = 0,
			Price = 79,
			Ready = false,
			Duration = 60,
			Scope = "Server",
			Targets = { "Guards", "NightGuards", "Police" },
			Cooldown = 300,
			CooldownAttribute = "SleepCooldownEndsAt",
			CooldownHolder = "Workspace",
		},
	} :: { Boost },
}

for _, boost in Boosts.List do
	boost.Id = ProductIds.Pick(boost.Key, boost.Id)
end

export type Boosts = typeof(Boosts)

return DeepFreeze(Boosts)
