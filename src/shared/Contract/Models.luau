--!strict
-- Contrat d'intégration des modèles (doc, section 10.4) et préfixes de nommage (10.3).
--
-- Règle de recherche (la même pour le code, voir Contract/Find) : un enfant obligatoire
-- est cherché parmi tous les descendants du modèle, pas seulement ses enfants directs
-- (un Attachment vit forcément dans une pièce). Un nom doit y être unique.
--
-- Part.Name est un nom exact, ou un format ("ShelfSlot_%02d") quand From et To sont
-- donnés : série numérotée de From à To. Min = nombre minimum de la série (défaut : To).

export type Part = {
	Name: string,
	From: number?,
	To: number?,
	Min: number?,
	Class: string?, -- classe attendue (IsA), seulement quand le doc la donne
	Tier: boolean?, -- attribut Tier obligatoire (Standard, Premium ou Luxe)
	TierCounts: { [string]: number }?, -- répartition attendue des Tier dans la série
	Invisible: boolean?, -- Transparency = 1
	Tag: string?, -- tag porté par l'élément ou un de ses descendants
	Inside: { Part }?, -- enfants obligatoires de cet élément
	Note: string?, -- précision du doc, ajoutée au message
}

export type ModelSpec = {
	Key: string,
	Label: string, -- nom en clair, au pluriel, pour le rapport
	Category: string, -- catégorie du rapport
	Tag: string?, -- tag qui désigne ces modèles
	Prefix: string?, -- préfixe de nom (10.3) qui désigne ces modèles
	Class: string?,
	PrimaryPart: string?,
	Attributes: { string }?,
	BodyAttachment: boolean?, -- accessoire : un attachment de corps dans Handle
	Parts: { Part },
	Expected: { string }?, -- noms d'exemplaires attendus
	ExpectedCount: number?, -- nombre d'exemplaires attendus
}

-- Vitre pré-fracturée : 30 à 40 éclats (5.4 et MOD-010) ; le 10.4 écrit Shard_01 à
-- Shard_40, donc Shard_01 à Shard_30 obligatoires, jusqu'à Shard_40 permis.
local WINDOW_FRACTURED: Part = {
	Name = "WindowFractured",
	Class = "Model",
	Inside = {
		{ Name = "Shard_%02d", From = 1, To = 40, Min = 30, Note = "30 à 40 éclats, 5.4" },
	},
}

local Store: ModelSpec = {
	Key = "Store",
	Label = "magasins PNJ",
	Category = "Magasins PNJ",
	Tag = "NPCStore",
	Prefix = "STORE_",
	Class = "Model",
	Parts = {
		{ Name = "Window" },
		WINDOW_FRACTURED,
		{ Name = "Shutter" },
		{ Name = "Door" },
		{ Name = "Bounds", Class = "BasePart", Invisible = true },
		-- Plus d'attribut Tier exigé ni de contrôle 6/3/1 (L-033, accepté par Ironix le
		-- 2026-11-07) : le code répartit au hasard 6 Standard, 3 Premium et 1 Luxe sur les 10
		-- emplacements à chaque remplissage. Un Tier laissé sur un emplacement est ignoré.
		{ Name = "ShelfSlot_%02d", From = 1, To = 10, Class = "Attachment" },
		{ Name = "GuardSpawn", Class = "Attachment" },
		{ Name = "SignPart" },
	},
}

-- Le tag désigne la parcelle. Le préfixe PLOT_ n'est pas utilisé pour la trouver :
-- il sert aussi aux morceaux de boutique par niveau (PLOT_Shop_L2, 10.3).
local Plot: ModelSpec = {
	Key = "Plot",
	Label = "parcelles",
	Category = "Parcelles",
	Tag = "PlayerPlot",
	Class = "Model",
	Parts = {
		{ Name = "Window" },
		WINDOW_FRACTURED, -- même vitre que les magasins (WindowService commun, 9.3)
		{ Name = "Shutter" }, -- Partie 2, placé dès le MVP
		{ Name = "ShutterButton" }, -- Partie 2, placé dès le MVP
		{ Name = "DisplaySlot_%02d", From = 1, To = 20 },
		{ Name = "VaultSlot_%02d", From = 1, To = 3 }, -- 02 et 03 : Partie 2
		{ Name = "UnboxBench_%02d", From = 1, To = 4 },
		{ Name = "TrapSlot_%02d", From = 1, To = 4 }, -- Partie 2
		{ Name = "CashPad", Tag = "CashPad" },
		{ Name = "DepositZone", Class = "BasePart" },
		{ Name = "Treadmill", Tag = "Treadmill" },
		{ Name = "Bench", Tag = "Bench" },
		-- Le code écrit « <Pseudo>'s Shop » dans OwnerName (L-019, validé le 2026-11-07 ; en
		-- anglais depuis L-036).
		{ Name = "NameSign", Inside = { { Name = "OwnerName", Class = "TextLabel" } } },
		-- Point d'apparition du propriétaire, axe −Z tourné vers l'allée (L-019).
		{ Name = "SpawnPoint", Class = "Attachment" },
		{ Name = "Bounds", Class = "BasePart" },
	},
}

local Treadmill: ModelSpec = {
	Key = "Treadmill",
	Label = "tapis de course",
	Category = "Parcelles",
	Tag = "Treadmill",
	Parts = {
		{ Name = "UsePoint", Class = "Attachment" },
		{ Name = "Belt" },
	},
}

local Bench: ModelSpec = {
	Key = "Bench",
	Label = "bancs",
	Category = "Parcelles",
	Tag = "Bench",
	Parts = {
		{ Name = "UsePoint", Class = "Attachment" },
	},
}

local Item: ModelSpec = {
	Key = "Item",
	Label = "objets exposés",
	Category = "Objets",
	Prefix = "ITM_",
	Class = "Model",
	PrimaryPart = "Root",
	Attributes = { "ItemId" },
	Parts = {},
	-- 36 objets des 6 zones + 1 Secret (10.5).
	ExpectedCount = 37,
}

local Box: ModelSpec = {
	Key = "Box",
	Label = "colis",
	Category = "Objets",
	Prefix = "BOX_",
	Parts = {
		{ Name = "CarryAttachment", Class = "Attachment" },
		{ Name = "Lid" },
		{ Name = "Tint", Class = "BasePart" },
		-- Où s'accroche l'étiquette du colis (L-023, livré par Clément le 2026-11-07, L-031).
		{ Name = "LabelPoint", Class = "Attachment" },
		-- Contour noir du colis (L-031) : ShelfBoxController le retrouve par ce nom et n'en
		-- garde que 25 actifs à la fois (Roblox en affiche 31 au plus).
		{ Name = "OutlineHighlight", Class = "Highlight" },
	},
	-- Un colis par type (MOD-013), nommés comme l'exemple BOX_Luxe du 10.3.
	Expected = { "BOX_Standard", "BOX_Premium", "BOX_Luxe" },
}

local Tool: ModelSpec = {
	Key = "Tool",
	Label = "outils",
	Category = "Objets",
	Prefix = "TOOL_",
	Parts = {
		{ Name = "Handle", Class = "MeshPart" },
		{ Name = "HitPoint", Class = "Attachment" },
	},
}

local Accessory: ModelSpec = {
	Key = "Accessory",
	Label = "accessoires de vigile",
	Category = "Objets",
	Prefix = "ACC_",
	Class = "Accessory",
	BodyAttachment = true,
	Parts = {
		{ Name = "Handle", Class = "BasePart" },
	},
}

local Models = {}

Models.Store = Store
Models.Plot = Plot
Models.Treadmill = Treadmill
Models.Bench = Bench
Models.Item = Item
Models.Box = Box
Models.Tool = Tool
Models.Accessory = Accessory

-- Ordre du rapport.
Models.List = { Store, Plot, Treadmill, Bench, Item, Box, Tool, Accessory } :: { ModelSpec }

return Models
