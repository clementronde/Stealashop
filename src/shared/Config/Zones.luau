--!strict
-- Les 6 zones de magasins PNJ du couloir (Partie 1, section 4).
-- Zones[n] = zone n. Le code retrouve les magasins par le tag `NPCStore` et
-- l'attribut `Zone` (1 à 6), jamais par leur nom.
--
-- Règles d'où viennent ces chiffres (section 4) :
--   WindowHP   = 35 × AdvisedDamage (casse en 6 s environ à 7 coups/s, régénération 3 %/s)
--   GuardSpeed = 0,9 × AdvisedSpeed − 1 (on distance le vigile à la vitesse conseillée, même avec −10 %)

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Zone = {
	Index: number,
	Theme: string, -- nom affiché de la zone, en anglais (catalogue 10.5, liaison L-036)
	Stores: { string }, -- noms affichés des 2 magasins PNJ, en anglais comme leurs enseignes (L-036)
	WindowHP: number, -- PV de la vitrine
	AdvisedDamage: number, -- dégâts par coup conseillés
	AdvisedSpeed: number, -- WalkSpeed conseillé
	GuardSpeed: number, -- WalkSpeed du vigile de jour
	ReturnDistance: number, -- studs jusqu'à la zone safe
	BaseIncome: number, -- $/s d'un objet Commun de la zone (R zone, section 7.1)
}

local Zones: { Zone } = {
	{
		Index = 1,
		Theme = "Mini Mart",
		Stores = { "Mini Mart", "Kiosk" },
		WindowHP = 35,
		AdvisedDamage = 1,
		AdvisedSpeed = 16,
		GuardSpeed = 13.4,
		ReturnDistance = 60,
		BaseIncome = 1,
	},
	{
		Index = 2,
		Theme = "Toys",
		Stores = { "Toy Shop", "Sweet Shop" },
		WindowHP = 350,
		AdvisedDamage = 10,
		AdvisedSpeed = 22,
		GuardSpeed = 18.8,
		ReturnDistance = 140,
		BaseIncome = 8,
	},
	{
		Index = 3,
		Theme = "Electronics",
		Stores = { "Electronics", "Video Games" },
		WindowHP = 2_800,
		AdvisedDamage = 80,
		AdvisedSpeed = 28,
		GuardSpeed = 24.2,
		ReturnDistance = 240,
		BaseIncome = 60,
	},
	{
		Index = 4,
		Theme = "Jewelry",
		Stores = { "Jewelry", "Watches & Clocks" },
		WindowHP = 21_000,
		AdvisedDamage = 600,
		AdvisedSpeed = 34,
		GuardSpeed = 29.6,
		ReturnDistance = 360,
		BaseIncome = 450,
	},
	{
		Index = 5,
		Theme = "Gallery",
		Stores = { "Art Gallery", "Antiques" },
		WindowHP = 175_000,
		AdvisedDamage = 5_000,
		AdvisedSpeed = 40,
		GuardSpeed = 35,
		ReturnDistance = 500,
		BaseIncome = 3_500,
	},
	{
		Index = 6,
		Theme = "Bank",
		Stores = { "Bank", "Vault" },
		WindowHP = 1_400_000,
		AdvisedDamage = 40_000,
		AdvisedSpeed = 48,
		GuardSpeed = 42.2,
		ReturnDistance = 660,
		BaseIncome = 25_000,
	},
}

return DeepFreeze(Zones)
