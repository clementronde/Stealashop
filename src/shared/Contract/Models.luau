--!strict
-- Contrat d'intégration des modèles (doc, section 10.4) et préfixes de nommage (10.3).
--
-- Règle de recherche (la même pour le code, voir Contract/Find) : un enfant obligatoire
-- est cherché parmi tous les descendants du modèle, pas seulement ses enfants directs
-- (un Attachment vit forcément dans une pièce). Un nom doit y être unique.
--
-- Part.Name est un nom exact, ou un format ("ShelfSlot_%02d") quand From et To sont
-- donnés : série numérotée de From à To. Min = nombre minimum de la série (défaut : To).
--
-- Les objets ITM_* suivent le catalogue (Config/Items, catalogue v2) : noms acceptés et nombre
-- attendu en sont tirés, comme les anciens noms du catalogue v1 que le ContractChecker refuse.

local Items = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("Items"))

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
	-- Élément facultatif : le code a un repli quand il manque. Absent, le ContractChecker écrit un
	-- avertissement (orange, pas compté comme un problème) ; mal nommé ou de la mauvaise classe, un
	-- problème, comme les autres.
	Optional: boolean?,
}

export type ModelSpec = {
	Key: string,
	Label: string, -- nom en clair, au pluriel, pour le rapport
	Category: string, -- catégorie du rapport
	Tag: string?, -- tag qui désigne ces modèles
	Prefix: string?, -- préfixe de nom (10.3) qui désigne ces modèles
	-- Noms exacts qui désignent ces modèles, quand ni un tag ni un préfixe ne suffisent (ENV_ et FX_
	-- sont les préfixes de tout le décor et de tous les effets).
	Names: { string }?,
	Class: string?,
	PrimaryPart: string?,
	Attributes: { string }?,
	BodyAttachment: boolean?, -- accessoire : un attachment de corps dans Handle
	Parts: { Part },
	Expected: { string }?, -- noms d'exemplaires attendus
	ExpectedCount: number?, -- nombre d'exemplaires attendus (noms différents)
	Known: { [string]: boolean }?, -- seuls noms acceptés ; un autre nom est signalé (objets ITM_)
	Renamed: { [string]: string }?, -- ancien nom → nom à prendre
	Retired: { [string]: boolean }?, -- anciens noms retirés du contrat
	SpinPrefix: string?, -- préfixe des pièces qui tournent sans fin sur l'axe Y de leur pivot (objets ITM_)
	WavePrefix: string?, -- préfixe des pièces qui font un va-et-vient sur l'axe Y de leur pivot (objets ITM_)
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
		-- Point d'accroche du panneau d'approche BB_StoreInfo, au-dessus de la vitrine (5.3, point 1 ;
		-- L-044, nom accepté par Clément le 2026-11-07). Facultatif : sans lui, StoreInfoController
		-- pose le panneau au-dessus de Window.
		{
			Name = "InfoPoint",
			Class = "Attachment",
			Optional = true,
			Note = "facultatif : sans lui, le panneau BB_StoreInfo se pose au-dessus de Window, L-044",
		},
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

-- Noms de modèles des objets du catalogue v2, et anciens noms du catalogue v1 (Config/Items).
local itemNames: { [string]: boolean } = {}
for _, item in Items.List do
	itemNames[item.Asset] = true
end
local itemRenamed: { [string]: string } = {}
for old, new in Items.RenamedV1 do
	itemRenamed[`ITM_{old}`] = `ITM_{new}`
end
local itemRetired: { [string]: boolean } = {}
for old in Items.RetiredV1 do
	itemRetired[`ITM_{old}`] = true
end

local Item: ModelSpec = {
	Key = "Item",
	Label = "objets exposés",
	Category = "Objets",
	Prefix = "ITM_",
	Class = "Model",
	PrimaryPart = "Root",
	Attributes = { "ItemId" }, -- = nom du modèle sans ITM_ (10.3)
	Parts = {},
	-- Les 83 objets du catalogue v2 (liaisons L-045 et L-055) : 13 en zone 1, 16 en zone 2, 14 en
	-- zone 3, 15 en zone 4, 12 en zones 5 et 6, 1 Secret.
	ExpectedCount = #Items.List,
	Known = itemNames,
	Renamed = itemRenamed, -- Z4_Montre, Z5_Vase
	Retired = itemRetired, -- les 6 objets retirés du catalogue v1
	-- Animation idle (L-045, proposition de Clément validée par Ironix le 2026-11-07 ; Wave_ : L-055),
	-- jouée côté client par ItemIdleController, aucun script dans le modèle :
	--   - attribut Idle du modèle (Contract/Attributes : Spin, Bob, SpinBob) ;
	--   - pièces Spin_<Nom> (BasePart ou Model) : rotation sans fin autour de l'axe Y de leur pivot
	--     (GetPivot, PivotOffset compris : Clément y règle l'axe, vertical pour l'anneau de la
	--     Figurine holographique, avant-arrière pour les ventilateurs du PC gamer) ;
	--   - pièces Wave_<Nom> (BasePart ou Model) : va-et-vient autour de l'axe Y de leur pivot, de part
	--     et d'autre de la pose de départ (patte du Chat porte-bonheur doré : Wave_Paw et
	--     Wave_PawPads, même pivot, à l'épaule). Toutes les pièces Wave_ d'un objet ont le même angle ;
	-- avec ou sans Idle. Une pièce rangée dans une autre bouge avec elle. Root n'est jamais une pièce
	-- Spin_ ou Wave_ ni dans l'une d'elles (le pivot du modèle bougerait).
	SpinPrefix = "Spin_",
	WavePrefix = "Wave_",
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

-- Camion de l'événement (liaison L-049, livré par Clément le 2026-11-07, noms à valider) : rangé dans
-- ReplicatedStorage/Assets (Events). TruckEventService en pose une copie dans le couloir, qu'il
-- renomme EventTruck. Le camion intact, ce sont les pièces de Pieces assemblées : à l'explosion, ce
-- sont elles qui partent depuis BlastPoint ; Root (invisible) reste sur place.
local Truck: ModelSpec = {
	Key = "Truck",
	Label = "modèles du camion de l'événement",
	Category = "Événements",
	Names = { "ENV_Event_Truck" },
	Class = "Model",
	PrimaryPart = "Root", -- pivot en bas au centre (10.1), long dans l'axe Z
	Parts = {
		{ Name = "Root", Class = "BasePart", Invisible = true, Note = "elle reste en place quand les pièces partent" },
		{
			Name = "Pieces",
			Class = "Model",
			Inside = { { Name = "Piece_%02d", From = 1, To = 20, Note = "Model ou pièce, la version en pièces" } },
		},
		-- Attachments (dans Root chez Clément) : d'où sortent les 12 colis, centre de l'explosion,
		-- point de la barre de vie.
		{ Name = "BoxSpawn_%02d", From = 1, To = 12, Class = "Attachment" },
		{ Name = "BlastPoint", Class = "Attachment" },
		{ Name = "HealthBarPoint", Class = "Attachment" },
		{ Name = "OutlineHighlight", Class = "Highlight" },
	},
	Expected = { "ENV_Event_Truck" },
}

-- Traînée des colis du camion qui volent (L-049) : TruckController copie le Trail et ses deux
-- Attachments sur chaque colis, le temps du vol.
local BoxTrail: ModelSpec = {
	Key = "BoxTrail",
	Label = "traînées des colis du camion",
	Category = "Événements",
	Names = { "FX_BoxTrail" },
	Parts = {
		{ Name = "Trail", Class = "Trail" },
		{ Name = "TrailTop", Class = "Attachment" },
		{ Name = "TrailBottom", Class = "Attachment" },
	},
	Expected = { "FX_BoxTrail" },
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
Models.Truck = Truck
Models.BoxTrail = BoxTrail

-- Ordre du rapport.
Models.List = { Store, Plot, Treadmill, Bench, Item, Box, Tool, Accessory, Truck, BoxTrail } :: { ModelSpec }

return Models
