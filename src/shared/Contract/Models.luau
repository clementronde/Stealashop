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
	-- L-086 (a46) : élément sur le départ, que le code ne lit plus. Absent (en tout ou en partie), rien
	-- n'est écrit ; présent, il est contrôlé comme les autres (classe, doublons). Pour une série, aucun
	-- numéro n'est obligatoire.
	Silent: boolean?,
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
	-- Tous les éléments facultatifs, et un modèle qui n'en a aucun doit quand même être signalé
	-- (chaque élément absent = un avertissement) au lieu de compter comme un bloc de greybox « pas
	-- encore livré » : comptoirs du hub sans ShopPad (L-071). Les arches (InfoPoint seul) restent
	-- « pas encore livré » sans lui.
	WarnWhenEmpty: boolean?,
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
		-- Point de pose du panneau planté StoreReqSign devant le magasin (L-108 point 5), dans Bounds
		-- chez Clément. Facultatif : sans lui, pas de panneau (StoreReqSignController).
		{
			Name = "ReqSignPoint",
			Class = "Attachment",
			Optional = true,
			Silent = true, -- rien d'écrit s'il manque : les copies de sauvegarde de Clément (ServerStorage) n'en ont pas
			Note = "facultatif : sans lui, pas de panneau StoreReqSign devant ce magasin, L-108",
		},
	},
}

-- Le tag désigne la parcelle. Le préfixe PLOT_ n'est pas utilisé pour la trouver :
-- il sert aussi aux morceaux de boutique par niveau (PLOT_Shop_L2, 10.3).
-- Enfants d'une plaque CollectPad_xx (voir plus bas, L-091 et L-107). Liste typée à part : ses
-- éléments n'ont pas tous les mêmes champs.
local COLLECT_PAD_INSIDE: { Part } = {
	{
		Name = "AmountGui",
		Class = "LayerCollector",
		Note = "BillboardGui depuis L-107 (SurfaceGui encore accepté)",
	},
	{ Name = "Amount", Class = "TextLabel" },
	{ Name = "CollectLabel", Class = "TextLabel", Silent = true },
	{ Name = "OfflineLabel", Class = "TextLabel", Silent = true },
	{
		Name = "BurstPoint",
		Class = "Attachment",
		Optional = true,
		Note = "facultatif : sans lui, pas de gerbe au ramassage, L-091",
	},
}

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
		-- L-086 (2026-11-08) : plus de coffre ni d'établis dans la boutique, le code ne lit plus ces noms
		-- (colis posés et ouverts sur les présentoirs). Facultatifs et muets en attendant que Clément les
		-- retire du modèle et des 6 boutiques du hub (L-086, point 4).
		{ Name = "VaultSlot_%02d", From = 1, To = 3, Silent = true },
		{ Name = "UnboxBench_%02d", From = 1, To = 4, Silent = true },
		{ Name = "TrapSlot_%02d", From = 1, To = 4 }, -- Partie 2
		-- L-082 point 4, L-091 points 4 et 5 (2026-11-10) : plus de tapis de caisse global CashPad (retiré
		-- du contrat et du code ; la pièce invisible laissée dans les boutiques n'est plus lue). L'argent
		-- se ramasse sur la plaque de chaque présentoir, CollectPad_xx (même numéro que DisplaySlot_xx).
		-- CollectPad_01 à _04 obligatoires (Rayon_01, toujours dans la boutique) ; _05 à _20 sont dans
		-- Assets/Plots/PLOT_Shop_Rayons et n'arrivent dans la parcelle qu'avec leur rayon (RayonService).
		-- Dedans : AmountGui et Amount (TextLabel), où le code écrit le montant ; BurstPoint
		-- (Attachment avec les ParticleEmitter de la gerbe) facultatif, l'effet seul en dépend.
		-- L-107 point 1 (2026-11-12) : AmountGui passe de SurfaceGui à BillboardGui (texte qui flotte
		-- au-dessus de la plaque). Pendant la pose de Clément, les deux sont acceptés (LayerCollector :
		-- le code ne lit que Enabled et Amount). Dans AmountGui, CollectLabel (« Collect », fixe) et
		-- OfflineLabel (caché, le code n'y écrit rien : les gains hors ligne ne passent pas par les
		-- plaques) : absents, rien n'est écrit (Silent) ; présents, leur classe est contrôlée.
		{
			Name = "CollectPad_%02d",
			From = 1,
			To = 20,
			Min = 4,
			Class = "BasePart",
			Note = "plaques de ramassage, _05 à _20 posées avec leur rayon, L-091",
			Inside = COLLECT_PAD_INSIDE,
		},
		{ Name = "DepositZone", Class = "BasePart" },
		{ Name = "Treadmill", Tag = "Treadmill" },
		-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de banc. L'enfant Bench et son tag sont facultatifs
		-- (le code ne les lit plus : un banc resté dans la parcelle est du décor), en attendant que Clément
		-- le retire.
		{ Name = "Bench", Tag = "Bench", Optional = true },
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
	-- Un colis par type (MOD-013), nommés comme l'exemple BOX_Luxe du 10.3. Les colis par rareté
	-- (BOX_<Rareté>, L-049, L-097 point 3, a79) sont pris en premier par le code, avec repli sur BOX_<Tier> :
	-- facultatifs, contrôlés par le préfixe quand ils sont là (BOX_Divine aussi, rareté pas encore au jeu).
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
-- Camion de base et un par rareté (a79, L-097 point 3) : TruckEventService prend celui de la rareté la
-- plus haute du chargement, sinon ENV_Event_Truck. Contrôlés quand ils sont là, pas attendus.
-- ENV_Event_Truck_Divine : lu depuis l'ajout de la rareté Divine (L-106 point 1).
local TRUCK_NAMES = {
	"ENV_Event_Truck",
	"ENV_Event_Truck_Common",
	"ENV_Event_Truck_Uncommon",
	"ENV_Event_Truck_Rare",
	"ENV_Event_Truck_Epic",
	"ENV_Event_Truck_Legendary",
	"ENV_Event_Truck_Mythic",
	"ENV_Event_Truck_Secret",
	"ENV_Event_Truck_Divine",
}
local Truck: ModelSpec = {
	Key = "Truck",
	Label = "modèles du camion de l'événement",
	Category = "Événements",
	Names = TRUCK_NAMES,
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
	Expected = { "ENV_Event_Truck" }, -- les camions par rareté sont facultatifs (repli sur celui-ci)
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

-- Arches de zone (tag ZoneGate, attribut Zone ; liaison L-071, point 9, a42) : point d'accroche
-- facultatif du panneau BB_ZoneGate, comme celui des magasins. Sans lui, ZoneGateController pose le
-- panneau au-dessus de SignPart (le bandeau des arches du greybox).
-- Depuis L-110 (2026-11-12) : BB_ZoneGate est retiré, plus rien ne s'accroche à InfoPoint ; il reste facultatif.
local ZoneGate: ModelSpec = {
	Key = "ZoneGate",
	Label = "arches de zone",
	Category = "Magasins PNJ",
	Tag = "ZoneGate",
	Parts = {
		{
			Name = "InfoPoint",
			Class = "Attachment",
			Optional = true,
			Note = "facultatif : sans lui, le panneau BB_ZoneGate se pose au-dessus de SignPart, L-071",
		},
	},
}

local Models = {}

Models.Store = Store
Models.Plot = Plot
Models.Treadmill = Treadmill
Models.Item = Item
Models.Box = Box
Models.Tool = Tool
Models.Accessory = Accessory
Models.Truck = Truck
Models.BoxTrail = BoxTrail
Models.ZoneGate = ZoneGate

-- Ordre du rapport.
Models.List = { Store, Plot, Treadmill, Item, Box, Tool, Accessory, Truck, BoxTrail, ZoneGate } :: { ModelSpec }

-- Comptoirs des boutiques d'achat du hub (tags WeaponShop, AuraShop, RobuxShop, 2.1 et 5.9) et leur
-- plaque ShopPad (nom proposé par Clément le 2026-11-08, L-071) : une pièce sous et devant le stand ;
-- marcher dessus ouvre l'écran du comptoir (ShopPadController). Facultative : sans elle, l'invite
-- « Shop » du comptoir ouvre l'écran comme avant. Le reste du comptoir (vendeur, décor) est libre.
local SHOP_PAD: Part = {
	Name = "ShopPad",
	Class = "BasePart",
	Optional = true,
	Note = "facultative : marcher dessus ouvre l'écran du comptoir ; sans elle, seule l'invite « Shop » l'ouvre, L-071",
}
local WeaponShopCounter: ModelSpec = {
	Key = "WeaponShopCounter",
	Label = "comptoirs de la boutique d'armes",
	Category = "Boutiques d'achat",
	Tag = "WeaponShop",
	Parts = { SHOP_PAD },
	WarnWhenEmpty = true,
}
local AuraShopCounter: ModelSpec = {
	Key = "AuraShopCounter",
	Label = "comptoirs de la boutique d'auras",
	Category = "Boutiques d'achat",
	Tag = "AuraShop",
	Parts = { SHOP_PAD },
	WarnWhenEmpty = true,
}
local RobuxShopCounter: ModelSpec = {
	Key = "RobuxShopCounter",
	Label = "comptoirs de la boutique Robux",
	Category = "Boutiques d'achat",
	Tag = "RobuxShop",
	Parts = { SHOP_PAD },
	WarnWhenEmpty = true,
}
Models.WeaponShopCounter = WeaponShopCounter
Models.AuraShopCounter = AuraShopCounter
Models.RobuxShopCounter = RobuxShopCounter
for _, spec in { WeaponShopCounter, AuraShopCounter, RobuxShopCounter } do
	table.insert(Models.List, spec) -- à la fin du rapport
end

-- Stand du receleur (vague 29, DEV-034 ; L-106 point 4, L-107 point 2 ; relevé de Studio du 2026-11-12) :
-- ENV_Hub_PawnStall, taggé PawnShop. Sa plaque ShopPad ouvre UI_PawnShop (ShopPadController, PawnShopController ;
-- le serveur mesure la distance du joueur à cette plaque, PawnShopService) ; la bulle BB_PawnTalk se pose sur la
-- Head du vendeur Vendor_Pawn. Pas d'invite de repli ici : la plaque est obligatoire.
local PawnShopStall: ModelSpec = {
	Key = "PawnShopStall",
	Label = "stands du receleur",
	Category = "Boutiques d'achat",
	Tag = "PawnShop",
	Parts = {
		{
			Name = "ShopPad",
			Class = "BasePart",
			Note = "marcher dessus ouvre le dialogue du receleur (UI_PawnShop)",
		},
		{
			Name = "Vendor_Pawn",
			Inside = { { Name = "Head", Class = "BasePart", Note = "la bulle BB_PawnTalk s'y pose" } },
		},
	},
}
Models.PawnShopStall = PawnShopStall
table.insert(Models.List, PawnShopStall) -- à la fin du rapport
-- Panneau planté devant chaque magasin PNJ (L-108 point 5), modèle de Clément dans
-- ReplicatedStorage/Assets/UI, copié sur chaque ReqSignPoint par StoreReqSignController. Facultatif :
-- absent, une ligne « pas encore livré » ; ses textes manquants sont ignorés par le code.
local StoreReqSign: ModelSpec = {
	Key = "StoreReqSign",
	Label = "panneaux des exigences des magasins (StoreReqSign)",
	Category = "Magasins PNJ",
	Names = { "StoreReqSign" },
	Class = "Model",
	PrimaryPart = "Foot", -- même pied et même pivot qu'UpgradeSign (L-108)
	Parts = {
		{ Name = "Foot", Class = "BasePart" },
		{ Name = "Board", Class = "BasePart" },
		{ Name = "SignGui", Class = "SurfaceGui" },
		{ Name = "StoreName", Class = "TextLabel", Optional = true },
		{ Name = "SpeedReq", Class = "TextLabel", Optional = true },
		{ Name = "StrengthReq", Class = "TextLabel", Optional = true },
	},
}
Models.StoreReqSign = StoreReqSign
-- Avant les comptoirs du hub, qui restent à la fin du rapport.
table.insert(Models.List, table.find(Models.List, WeaponShopCounter) or #Models.List + 1, StoreReqSign)

-- Témoins et police (vague 30, liaison L-111 ; relevé de Studio du 2026-11-12, agents/wave30-studio.md).
-- Témoins NPC_Witness_Z<n>_0<k>, posés dans la map (Map/Zone_<n>/Witnesses) : WitnessService les anime sur
-- place (balade, Look, CallPolice). Leurs animations sont contrôlées à part (Contract/Animations.Witness).
-- L'attribut WatchedStore (nom du magasin regardé) n'est pas exigé ici : s'il manque ou s'il est faux,
-- WitnessService l'écrit en orange au démarrage et le témoin se balade seulement.
local WitnessNpc: ModelSpec = {
	Key = "Witness",
	Label = "témoins",
	Category = "Magasins PNJ",
	Prefix = "NPC_Witness",
	Class = "Model",
	Parts = {
		{ Name = "HumanoidRootPart", Class = "BasePart", Note = "non ancré : le code le fait marcher" },
		{
			Name = "WitnessHead",
			Class = "Attachment",
			Optional = true,
			Note = "facultatif : sans lui, la bulle BB_Witness se pose au-dessus de la Head, L-111",
		},
	},
}
-- Policier appelé par les témoins : ReplicatedStorage/Assets/Guards/NPC_Police, copié en jeu par
-- GuardService (StartDriverChase). Mêmes animations que les vigiles (Contract/Animations.Guard).
local Police: ModelSpec = {
	Key = "Police",
	Label = "policiers",
	Category = "Magasins PNJ",
	Names = { "NPC_Police" },
	Class = "Model",
	Parts = {
		{ Name = "HumanoidRootPart", Class = "BasePart" },
	},
	Expected = { "NPC_Police" },
}
-- Circuit de balade des témoins d'une zone (Map/Zone_<n>/WitnessPaths) : des Attachments au sol,
-- WitnessPath_01, _02… (28 en zone 1), suivis dans l'ordre des numéros, en boucle. Deux au moins ; sans
-- circuit, les témoins restent sur place.
local WitnessPaths: ModelSpec = {
	Key = "WitnessPaths",
	Label = "circuits de balade des témoins",
	Category = "Magasins PNJ",
	Names = { "WitnessPaths" },
	Parts = {
		{
			Name = "WitnessPath_%02d",
			From = 1,
			To = 60,
			Min = 2,
			Class = "Attachment",
			Note = "points du circuit, au sol, dans l'ordre de la balade, L-111",
		},
	},
	Expected = { "WitnessPaths" },
}
Models.Witness = WitnessNpc
Models.Police = Police
Models.WitnessPaths = WitnessPaths
for _, spec in { WitnessNpc, Police, WitnessPaths } do
	-- Avant les comptoirs du hub, qui restent à la fin du rapport.
	table.insert(Models.List, table.find(Models.List, WeaponShopCounter) or #Models.List + 1, spec)
end

-- Design des mutations (vague 34, L-127 point 5, a119), joué par MutationFxController (client).
-- Styles du texte : ReplicatedStorage/Assets/UI/MutationStyles/<Id> (Folder ; Id = un effet de Config/Mutations, ou
-- « Size » pour une taille seule) : TagGradient (étiquette MutationTag de l'inventaire), TextGradient (ligne Mutation
-- de BB_Item), attributs LabelColor, StrokeColor, Motion (None, Shine, Pulse, Glitch, Scan, Spin), MotionPeriod.
local MUTATION_STYLE_IDS = { "Shiny", "Gold", "Neon", "Diamond", "Glitch", "Hacked", "Rainbow", "Size" }
local mutationStyleParts: { Part } = {}
for _, id in MUTATION_STYLE_IDS do
	table.insert(mutationStyleParts, {
		Name = id,
		Class = "Folder",
		Optional = true,
		Note = "sans lui, le texte de cette mutation garde son style, L-127",
		Inside = {
			{ Name = "TagGradient", Class = "UIGradient" },
			{ Name = "TextGradient", Class = "UIGradient" },
		},
	})
end
local MutationStyles: ModelSpec = {
	Key = "MutationStyles",
	Label = "styles du texte des mutations",
	Category = "Objets",
	Names = { "MutationStyles" },
	Class = "Folder",
	Parts = mutationStyleParts,
	Expected = { "MutationStyles" },
}
-- Effets des mutations sur les objets : ReplicatedStorage/Assets/FX/Mutations/FX_Mutation_<Id> (Folder ; attributs
-- ColorMode, TintColor, ShadeMin, Material, Reflectance, Motion, MotionPeriod, EmitterBoxScale, LightBrightness,
-- LightRange, GlitchJump, GlitchSpread ; enfants Emitters, Ghosts, Extras facultatifs). Un FX absent : l'objet reste
-- normal (avertissement unique du client).
local mutationFxNames: { string } = {}
for _, id in { "Shiny", "Gold", "Neon", "Diamond", "Glitch", "Hacked", "Rainbow" } do
	table.insert(mutationFxNames, "FX_Mutation_" .. id)
end
local MutationFxSpec: ModelSpec = {
	Key = "MutationFx",
	Label = "effets des mutations sur les objets",
	Category = "Objets",
	Names = mutationFxNames,
	Class = "Folder",
	Parts = {
		{ Name = "Emitters", Class = "Folder", Note = "particules (vide permis), L-127" },
		-- Facultatifs selon l'effet : absents, rien n'est écrit (Silent) ; présents, contrôlés.
		{ Name = "Ghosts", Class = "Folder", Silent = true, Note = "doubles Ghost_NN et coques Glow_NN, L-127" },
		{ Name = "Extras", Class = "Folder", Silent = true, Note = "RainbowArc, L-127" },
	},
	Expected = mutationFxNames,
}
Models.MutationStyles = MutationStyles
Models.MutationFx = MutationFxSpec
for _, spec in { MutationStyles, MutationFxSpec } do
	-- Avant les comptoirs du hub, qui restent à la fin du rapport.
	table.insert(Models.List, table.find(Models.List, WeaponShopCounter) or #Models.List + 1, spec)
end

-- Vitrine de l'événement de la Fortune Tower (L-108 point 8, vague 37, a123 ; noms proposés à Clément, pas
-- encore validés) : rangée dans ReplicatedStorage/Assets (Events), pivot en bas au centre, face avant vers
-- la rue. FortuneTowerService en pose une copie en zone 6, qu'il renomme FortuneVault. Aucun exemplaire
-- attendu (Expected vide : rien d'écrit tant qu'elle n'est pas livrée) ; livrée, chaque élément absent est
-- un avertissement (orange), jamais un problème : le code a un repli pour chacun.
local FortuneVault: ModelSpec = {
	Key = "FortuneVault",
	Label = "vitrines de l'événement de la Fortune Tower",
	Category = "Événements",
	Names = { "ENV_Event_FortuneVault" },
	Class = "Model",
	Parts = {
		{
			Name = "Window",
			Class = "BasePart",
			Optional = true,
			Note = "facultative : la vitre géante, cachée à la casse ; sans elle, rien n'est caché, L-108",
		},
		{
			Name = "HealthBarPoint",
			Class = "Attachment",
			Optional = true,
			Note = "facultatif : point de la barre de PV ; sans lui, la barre se pose sur Window, L-108",
		},
		{
			Name = "OutlineHighlight",
			Class = "Highlight",
			Optional = true,
			Note = "facultatif : contour éteint à la casse, L-108",
		},
		-- Points au sol où tombe le butin (8 colis) ; facultatifs (Silent) : sans eux, une rangée devant la face avant.
		{ Name = "LootSpawn_%02d", From = 1, To = 8, Class = "Attachment", Silent = true },
	},
	Expected = {},
}
Models.FortuneVault = FortuneVault
table.insert(Models.List, table.find(Models.List, WeaponShopCounter) or #Models.List + 1, FortuneVault)

return Models
