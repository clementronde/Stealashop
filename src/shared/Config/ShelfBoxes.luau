--!strict
-- Colis des rayons des magasins PNJ (DEV-015, DEV-017) : tirage à la mise en rayon, étiquette
-- BB_Box et contour des colis (liaison L-031 et L-033, décisions de Clément acceptées par Ironix
-- le 2026-11-07). Lu par StoreHeistService et CarryService (serveur) et par ShelfBoxController
-- (client). Le nombre de colis de chaque type, leur temps de prise et leurs probabilités de
-- rareté restent dans Balance.Heist.BoxTiers et Rarities.BoxOdds.
--
-- Origine de chaque valeur, notée en commentaire :
--   L-031, L-033  décision écrite dans la liaison ;
--   V0            V0 proposé, absent du doc, à régler en jeu.
-- Unités : studs, secondes ; pourcentages de 0 à 100.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- ZoneOdds[zone][BoxTier][RarityId] = pourcentage (chaque type fait 100).
export type ZoneOdds = { [number]: { [string]: { [string]: number } } }

local ZONE_ODDS: ZoneOdds = {
	-- L-033 : la zone 1 est la zone tuto. Elle ne tire que des objets Communs, pour les trois
	-- types de colis (6 Standard, 3 Premium et 1 Luxe, placés au hasard comme ailleurs).
	-- Exception : le premier colis du tuto garde son objet Rare garanti (5.11, Tutorial.FirstBoxTier
	-- et Tutorial.GuaranteedRarity). Il est donné à la prise par l'accroche
	-- StoreHeistService.SetContentOverride, que TutorialService posera.
	[1] = {
		Standard = { Common = 100 },
		Premium = { Common = 100 },
		Luxe = { Common = 100 },
	},
}

local ShelfBoxes = {
	-- Serveur (StoreHeistService) ------------------------------------------------------------

	-- Probabilités de rareté propres à une zone : remplacent Rarities.BoxOdds[Tier] dans cette
	-- zone. Une zone absente tire avec Rarities.BoxOdds (7.3).
	ZoneOdds = ZONE_ODDS,

	-- Client (ShelfBoxController) ------------------------------------------------------------

	-- Contour noir des colis : Highlight `OutlineHighlight` des modèles BOX_* de Clément (L-031).
	-- Roblox n'affiche que 31 Highlight à la fois et la map compte 120 colis : seuls les colis les
	-- plus proches de la caméra gardent le leur. Les arêtes noires `Outline` (SelectionBox) restent
	-- toujours visibles, en secours.
	OutlineName = "OutlineHighlight", -- L-031 : nom du Highlight dans BOX_*
	MaxOutlines = 25, -- L-031 : 25 contours, la marge sert aux autres Highlight du jeu
	OutlineMaxDistance = 100, -- V0 : au-delà, aucun contour, même parmi les 25 plus proches
	RefreshInterval = 0.25, -- V0 : tri des colis par distance (contours, étiquettes à revoir)

	-- Étiquette BB_Box d'un colis du rayon : AlwaysOnTop chez Clément, on la verrait à travers les
	-- rayons voisins. Elle n'est active que si un rayon lancé de la caméra vers son LabelPoint
	-- n'est arrêté par rien (colis et personnages ignorés), à MaxDistance de BB_Box au plus.
	LabelChecksPerFrame = 6, -- V0 : rayons lancés par image au plus, répartis sur les images
	LabelCheckInterval = 0.2, -- V0 : un même colis est revu au plus 5 fois par seconde
	LabelRayPasses = 5, -- V0 : pièces transparentes traversées au plus par un rayon (vitres, volumes)
	SeeThroughTransparency = 0.5, -- V0 : une pièce au moins aussi transparente ne cache rien (vitre, Bounds)
	LabelRayTolerance = 0.75, -- V0 : un obstacle à moins de 0,75 stud du LabelPoint ne cache pas l'étiquette (bord du casier)
	LabelFallbackDistance = 32, -- V0 : portée prise si BB_Box n'a pas de MaxDistance (celle de Clément : 32)

	-- Étiquette V0 (rareté seule), tant que BB_Box n'est pas livré dans ReplicatedStorage/Assets/UI.
	V0LabelMaxDistance = 32, -- V0 : même portée que le BB_Box de Clément (L-031)
}

export type ShelfBoxes = typeof(ShelfBoxes)

return DeepFreeze(ShelfBoxes)
