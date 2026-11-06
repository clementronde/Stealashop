--!strict
-- Contrat : tags posés par Clément et lus par le code (doc, section 2.1).
-- Source unique : le code et le ContractChecker lisent cette liste, jamais un nom recopié.
--
-- Count = nombre exact attendu dans la map (Workspace, hors _INBOX_CLEMENT et
-- _SANDBOX_IRONIX) ; absent quand le doc ne donne pas de nombre.
-- PerZone = nombre attendu pour chaque valeur de l'attribut Zone (1 à 6).
-- NeedsZone = chaque exemplaire porte l'attribut Zone.

export type TagSpec = {
	Tag: string,
	Count: number?,
	PerZone: number?,
	NeedsZone: boolean?,
	For: string, -- ce qui porte le tag, en clair, pour le rapport
}

local Tags = {}

Tags.List = {
	-- 12 magasins, un de chaque côté du boulevard par zone (section 4).
	-- Zone sur le magasin : déduit de 2.1 (attribut Zone = 1 à 6), le tableau 10.4 ne le cite pas.
	{ Tag = "NPCStore", Count = 12, PerZone = 2, NeedsZone = true, For = "magasins PNJ STORE_*" },
	-- 6 parcelles dans la zone safe (section 4).
	{ Tag = "PlayerPlot", Count = 6, For = "parcelles PLOT_*" },
	-- 1 tapis, 1 banc et 1 tapis de caisse par parcelle : déduit du 10.4 (enfants Treadmill,
	-- Bench et CashPad de la parcelle), le doc ne donne pas le nombre de tags.
	{ Tag = "Treadmill", Count = 6, For = "tapis de course, 1 par parcelle" },
	{ Tag = "Bench", Count = 6, For = "bancs de musculation, 1 par parcelle" },
	{ Tag = "CashPad", Count = 6, For = "tapis de caisse, 1 par parcelle" },
	-- Une boutique de chaque dans la zone safe (sections 4 et 5.9).
	{ Tag = "WeaponShop", Count = 1, For = "boutique d'armes" },
	{ Tag = "AuraShop", Count = 1, For = "boutique d'auras" },
	{ Tag = "RobuxShop", Count = 1, For = "comptoir Robux (MAJ 1, posé dès MOD-029)" },
	{ Tag = "SafeZone", For = "zone safe" },
	-- Une arche à l'entrée de chaque zone (section 4, MOD-028).
	{ Tag = "ZoneGate", Count = 6, PerZone = 1, NeedsZone = true, For = "arches de zone" },
	-- Un mur géant à l'entrée du couloir (section 5.12).
	{ Tag = "NightWall", Count = 1, For = "mur de nuit" },
	{ Tag = "NightPatrol", For = "points de ronde des vigiles de nuit" },
} :: { TagSpec }

return Tags
