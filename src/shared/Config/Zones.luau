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
	-- Ville de la zone, écrite sur le bandeau d'entrée UI_ZoneBanner (liaison L-110, noms de Clément du
	-- 2026-11-12). nil : pas encore de ville (zone 1) ; le bandeau écrit alors Theme en capitales.
	City: string?,
	Stores: { string }, -- noms affichés des 2 magasins PNJ, en anglais comme leurs enseignes (L-036)
	-- Les mêmes magasins, dans le même ordre, sous leur nom d'asset (10.3) : le modèle de Clément
	-- s'appelle STORE_Z<n>_<Id> (« STORE_Z1_Superette »). Ce sont les noms de la colonne « Magasins
	-- PNJ » de la section 4, sans accents ni espaces, tels qu'ils sont dans la place. Ils servent
	-- seulement à retrouver le nom affiché d'un magasin (StoreInfoController, DEV-030).
	StoreIds: { string },
	WindowHP: number, -- PV de la vitrine
	AdvisedDamage: number, -- dégâts par coup conseillés
	AdvisedSpeed: number, -- WalkSpeed conseillé
	GuardSpeed: number, -- WalkSpeed du vigile de jour
	ReturnDistance: number, -- studs jusqu'à la zone safe (zones ×1,25 de Clément, 2026-11-08, liaison L-071)
	BaseIncome: number, -- $/s d'un objet Commun de la zone (R zone, section 7.1)
}

local Zones: { Zone } = {
	{
		Index = 1,
		Theme = "Mini Mart",
		Stores = { "Mini Mart", "Kiosk" },
		StoreIds = { "Superette", "Kiosque" },
		WindowHP = 35,
		AdvisedDamage = 1,
		AdvisedSpeed = 16,
		GuardSpeed = 13.4,
		ReturnDistance = 75,
		BaseIncome = 1,
	},
	{
		Index = 2,
		Theme = "Toys",
		City = "LONDON",
		Stores = { "Toy Shop", "Sweet Shop" },
		StoreIds = { "MagasinDeJouets", "Confiserie" },
		WindowHP = 350,
		AdvisedDamage = 10,
		AdvisedSpeed = 22,
		GuardSpeed = 18.8,
		ReturnDistance = 175,
		BaseIncome = 8,
	},
	{
		Index = 3,
		Theme = "Electronics",
		City = "TOKYO",
		Stores = { "Electronics", "Video Games" },
		StoreIds = { "Electronique", "JeuxVideo" },
		WindowHP = 2_800,
		AdvisedDamage = 80,
		AdvisedSpeed = 28,
		GuardSpeed = 24.2,
		ReturnDistance = 300,
		BaseIncome = 60,
	},
	{
		Index = 4,
		Theme = "Jewelry",
		City = "LOS ANGELES",
		Stores = { "Jewelry", "Watches & Clocks" },
		StoreIds = { "Bijouterie", "Horlogerie" },
		WindowHP = 21_000,
		AdvisedDamage = 600,
		AdvisedSpeed = 34,
		GuardSpeed = 29.6,
		ReturnDistance = 450,
		BaseIncome = 450,
	},
	{
		Index = 5,
		Theme = "Gallery",
		City = "PARIS",
		Stores = { "Art Gallery", "Antiques" },
		StoreIds = { "GalerieDArt", "Antiquaire" },
		WindowHP = 175_000,
		AdvisedDamage = 5_000,
		AdvisedSpeed = 40,
		GuardSpeed = 35,
		ReturnDistance = 625,
		BaseIncome = 3_500,
	},
	{
		Index = 6,
		Theme = "Bank",
		City = "NEW YORK",
		Stores = { "Bank", "Vault" },
		StoreIds = { "Banque", "SalleDesCoffres" },
		WindowHP = 1_400_000,
		AdvisedDamage = 40_000,
		AdvisedSpeed = 48,
		GuardSpeed = 42.2,
		ReturnDistance = 825,
		BaseIncome = 25_000,
	},
}

return DeepFreeze(Zones)
