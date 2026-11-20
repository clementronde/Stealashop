--!strict
-- Colis des rayons des magasins PNJ (DEV-015, DEV-017) : tirage à la mise en rayon, étiquette
-- BB_Box et contour des colis (liaison L-031 et L-033, décisions de Clément acceptées par Ironix
-- le 2026-11-07). Lu par StoreHeistService, CarryService et UnboxService (serveur) et par
-- ShelfBoxController, HeistController et le rouleau d'UnboxController (client).
--
-- Vague 76 (Cantin et Clément, 19/11) : plus de types de colis Standard, Premium, Luxe sur les rayons. Chaque zone
-- n'a que certaines raretés (objets ET colis : ZoneOdds) ; chaque emplacement tire la rareté de son colis dans
-- ZoneOdds[zone] ; le contenu (rareté de l'objet) garde ShelfOpen.BoxRarityOdds, limité aux raretés de la zone et
-- ramené à 100 (ContentOdds) ; le temps de prise suit la rareté du colis (GrabTimes). Le camion, la tour de la
-- fortune et les colis offerts gardent leur type et leur table (Rarities.BoxOdds, OddsFor ; zone 1 : Commun seul).
--
-- Origine de chaque valeur, notée en commentaire :
--   L-031, L-033  décision écrite dans la liaison ;
--   V0            V0 proposé, absent du doc, à régler en jeu.
-- Unités : studs, secondes ; pourcentages de 0 à 100.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Rarities = require(script.Parent.Rarities)

-- Raretés de chaque zone et chances des colis du rayon : Rarities.ZoneOdds (vague 76 ; dans Rarities pour que
-- Config/Items et Formulas.ItemIncome les lisent sans autre module). Repris ici sous leurs noms d'avant.
local ZONE_ODDS = Rarities.ZoneOdds
local ZONE_RARITIES = Rarities.ZoneRarities
local ALLOWED = Rarities.ZoneAllowed
local FIRST_ZONE = Rarities.FirstZone


-- `odds` limitée aux raretés de la zone `zone`, ramenée à 100 ; nil si rien n'y reste (ou zone inconnue).
local function limited(odds: { [string]: number }, zone: number): { [string]: number }?
	local allowed = ALLOWED[zone]
	if allowed == nil then
		return nil
	end
	local total = 0
	for rarityId, value in odds do
		if allowed[rarityId] and type(value) == "number" and value > 0 then
			total += value
		end
	end
	if total <= 0 then
		return nil
	end
	local out: { [string]: number } = {}
	for rarityId, value in odds do
		if allowed[rarityId] and type(value) == "number" and value > 0 then
			out[rarityId] = value / total * 100
		end
	end
	return out
end

local ShelfBoxes = {
	-- Serveur (StoreHeistService) ------------------------------------------------------------

	-- Rareté du colis d'un emplacement, par zone (voir plus haut).
	ZoneOdds = ZONE_ODDS,
	-- [zone] = raretés de la zone, de la plus basse à la plus haute.
	ZoneRarities = ZONE_RARITIES,
	-- [RarityId] = première zone où elle existe.
	FirstZone = FIRST_ZONE,
	GrabTimes = Rarities.GrabTimes, -- temps de prise selon la rareté du colis (Rarities)

	-- La rareté `rarityId` existe-t-elle dans la zone `zone` (colis et objets) ? (Rarities.Allows)
	Allows = Rarities.Allows,

	-- Temps de prise d'un colis de rareté `rarityId` (ou de l'objet sorti d'un tel colis).
	GrabTime = Rarities.GrabTime,

	-- Colis qui gardent un type (camion, tour de la fortune, colis offerts) : leur propre table, Rarities.BoxOdds[tier]
	-- (vague 76, décision 3 : inchangée) ; en zone 1 (zone du tuto, L-033), Commun seulement, comme avant. nil pour un
	-- type inconnu. [RarityId] = pourcentage, une rareté absente vaut 0. Une rareté sans objet dans la zone : repli de
	-- chaque appelant (TruckEventService : la plus proche en dessous ; UnboxService : rareté écartée). Fonction pure,
	-- sans tirage : lue par UnboxService (colis offerts, amélioration), TruckEventService et la tour de la fortune.
	OddsFor = function(zone: number, tier: string): { [string]: number }?
		local odds = Rarities.BoxOdds[tier]
		if odds == nil then
			return nil
		end
		if zone == 1 then
			return limited(odds, zone) or ZONE_ODDS[zone]
		end
		return odds
	end,

	-- Poids de la rareté de l'OBJET d'une caisse de rareté `boxRarity` à la chance `luck` (règle de Cantin du
	-- 2026-11-13, vague 32 ; sortie de StoreHeistService par la vague 76 pour que le tirage du serveur et la cote
	-- « 1 IN N » (Shared/ItemOdds) lisent la même règle) : ShelfOpen.BoxRarityOdds[boxRarity], limitée aux raretés
	-- de la zone `zone` quand elle est donnée (rayons des magasins ; rien pour un rayon d'événement), puis les poids
	-- des raretés au-dessus du seuil de ShelfOpen.LuckBoost multipliés par la chance ("AboveBox" : au-dessus de la
	-- caisse ; "AboveLowest" : au-dessus de la plus basse qui reste ; autre valeur : la chance ne compte pas, le
	-- serveur avertit). Poids relatifs (le tirage les ramène à 100). nil si la caisse n'a pas de table ou si rien
	-- ne reste. Config/ShelfOpen n'est chargé qu'ici, au premier appel : ShelfBoxes reste lisible sans lui.
	ContentWeights = function(boxRarity: string, luck: number, zone: number?): { [string]: number }?
		local ShelfOpen = require(script.Parent.ShelfOpen)
		local odds = ShelfOpen.BoxRarityOdds[boxRarity]
		local allowed = if zone then ALLOWED[zone] else nil
		if odds == nil or (zone ~= nil and allowed == nil) then
			return nil
		end
		local lowest: number? = nil
		for _, rarity in Rarities.List do
			if (odds[rarity.Id] or 0) > 0 and (allowed == nil or allowed[rarity.Id]) then
				lowest = rarity.Order
				break
			end
		end
		if lowest == nil then
			return nil
		end
		local boost = if luck > 1 and luck < math.huge then luck else 1
		local mode = ShelfOpen.LuckBoost
		local box = Rarities.ById[boxRarity]
		local threshold: number = lowest
		if mode == "AboveBox" and box then
			threshold = box.Order
		elseif mode ~= "AboveLowest" then
			boost = 1
		end
		local weights: { [string]: number } = {}
		for _, rarity in Rarities.List do
			local weight = odds[rarity.Id] or 0
			if weight > 0 and (allowed == nil or allowed[rarity.Id]) then
				weights[rarity.Id] = if rarity.Order > threshold then weight * boost else weight
			end
		end
		return weights
	end,

	-- Client (ShelfBoxController) ------------------------------------------------------------

	-- Contour noir des colis : Highlight `OutlineHighlight` des modèles BOX_* de Clément (L-031).
	-- Roblox n'affiche que 31 Highlight à la fois et la map compte 120 colis : seuls les colis les
	-- plus proches de la caméra gardent le leur. Les arêtes noires `Outline` (SelectionBox) restent
	-- toujours visibles, en secours.
	OutlineName = "OutlineHighlight", -- L-031 : nom du Highlight dans BOX_*
	-- Vague 39 (audit perf-telephone.md, correction 5) : 20 au lieu des 25 de L-031. Avec 25, les
	-- 6 porteurs (StolenOutline) et les 3 alertes de vol passaient à 34, au-delà des 31 de Roblox (les
	-- derniers ne s'affichent pas, sans erreur) ; 20 + 6 + 3 = 29. V0 proposé, à faire valider par Clément.
	MaxOutlines = 20, -- V0 (L-031 : 25) : contours de colis, la marge sert aux autres Highlight du jeu
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
