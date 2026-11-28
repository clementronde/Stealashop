--!strict
-- La boutique du joueur grandit petit à petit (vague 55, a179 ; retour de Cantin du 15/11 : « quand tu
-- améliores ta base […] la base elle est entière d'un coup, il faudrait que ça aille petit à petit »).
-- Lu par ShopStageService (serveur), qui coupe ses copies `Stage_2` à `Stage_k` du gabarit PLOT_Shop au fond du
-- dernier présentoir débloqué, et par RayonService (socles des présentoirs au-delà, cachés). Règle géométrique,
-- sans rien changer au gabarit de Clément : voir l'en-tête de ShopStageService.
--
-- Toutes les valeurs sont des V0 proposés, absents du doc. Unités : studs, mesurés dans le repère de la boutique
-- (avant vers −Z, fond vers +Z ; gabarit de Clément : porte en z −40, fond en z 40, rangs de présentoirs
-- tous les 7 studs, L-141 ; a427, L-321 du 24/11 : 64 de large, rangs du bas tous les 10 studs, z −33 à −3).

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a486 : table de l'économie à appliquer par-dessus les nombres de ce fichier (Config/Economy.Override : la table 2
-- quand elle est active). nil avec la table 1, ou sans le module (bancs à liste de modules fixe, comme dans
-- Config/Items) : les nombres écrits dans ce fichier, qui SONT la table 1, ne sont jamais remplacés.
local ECO: any = (function(): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild("Economy")
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" and type(result.Override) == "table" and type(result.Override.Version) == "number" then
			return result.Override
		end
	end
	return nil
end)()

local ShopGrowth = {
	-- false : la boutique reprend tout de suite la taille entière de chaque niveau, comme avant la vague 55.
	Enabled = true, -- V0
	-- Vague 60 (a195, T-086, Cantin : « un seul présentoir sur les deux ») : dans un rang déjà montré, le socle
	-- et la plaque d'un présentoir pas encore débloqué restent cachés (RayonService). false : tout le rang d'un coup.
	-- Une pièce des visuels d'un rayon sans numéro dans son nom (`…_07`) suit le DisplaySlot le plus proche à moins
	-- de LockedStandRadius (au sol) ; plus loin, c'est le décor du rang, montré avec lui.
	HideLockedStands = true, -- V0
	LockedStandRadius = 6, -- V0 : la plaque est à 5 studs de son socle, le socle voisin du même côté à 10 (L-321)
	-- Fond de la boutique = rang du dernier présentoir débloqué + RowMargin (un socle fait 4 de profondeur),
	-- arrondi au-dessus sur la grille du damier : StepOrigin + n × Step (carreaux de 4 depuis la porte).
	-- RowMargin, Step et StepOrigin sont FIGÉS (L-190 Q3) : Clément coupe les pièces du gabarit à ces fonds, plans
	-- z −12, −4, 4, 8, 16, 24, 32 et 40 (boutique entière). Les changer = lui demander de recouper.
	RowMargin = 5, -- figé (L-190) : au moins 2 studs entre le dos d'un socle et le revêtement du mur du fond
	Step = 4, -- figé (L-190)
	StepOrigin = -40, -- figé (L-190) : z de la porte dans le gabarit
	-- L-285 (demande de Clément, 21/11) : la boutique démarre en carré de 48 × 48 (niveau 1 du gabarit de la porte
	-- en z −40 au fond en z 8, Stage_1/Frame/Back_L1 et PlotBarrier/Barrier_B1). Le fond coupé ne se pose jamais
	-- devant ce z : fond = max(fond calculé, MinBack), StageDepth compris. 8 = StepOrigin + 12 × Step, un plan de
	-- L-190 (fond à 11-12 présentoirs). nil : pas de minimum, comme avant.
	MinBack = 8 :: number?, -- V0 proposé, 2026-11-22, L-285
	-- Pièces « du fond » : leur bord arrière est à moins de BackZone du fond du gabarit. Une pièce fine
	-- (profondeur ≤ BackThickness : mur du fond, parapet, caméras du fond) avance avec le fond ; une longue pièce
	-- (sol, murs des côtés, toit) est raccourcie en gardant son écart au fond.
	BackZone = 4, -- V0
	BackThickness = 2, -- V0
	-- a540 (L-509, Clément 27/11) : boutique coupée, une pièce fine du fond est posée BackPieceOffset derrière le
	-- nouveau fond, hors du plan des bouts coupés des côtés (scintillement). Interrupteur Features.ShopBackPieceOffset.
	BackPieceOffset = 0.03, -- V0 proposé par Clément (L-509)
	-- Une pièce plus longue que ClipMinLength qui dépasse le nouveau fond est raccourcie (à InnerInset avant le
	-- fond si elle ne touchait pas le fond du gabarit : néons du plafond) ; plus courte, elle est retirée si son
	-- centre est au-delà. Raccourcie à moins de MinLength : retirée.
	ClipMinLength = 6, -- V0
	InnerInset = 1.5, -- V0 : épaisseur du mur du fond et de son revêtement, plus un peu
	MinLength = 1, -- V0
	-- Gabarit découpé par Clément (L-190 Q1 et Q2) : avec l'attribut booléen RowCutAttribute = true sur PLOT_Shop,
	-- le code ne raccourcit plus rien. Une pièce dont le bord arrière est au plus à RowCutTolerance au-delà du
	-- fond est gardée telle quelle, une pièce fine du fond avance toujours avec lui, toute autre est retirée.
	-- Sans l'attribut, la coupe ci-dessus reste (filet).
	RowCutAttribute = "RowCut", -- nom convenu avec Clément (L-190)
	RowCutTolerance = 0.05, -- V0 : un tronçon coupé pile sur le plan reste devant le fond
	-- a280 (vague GC2, lot C ; L-217, L-277 ; règle de L-294 décidée par Cantin le 2026-11-23 ; interrupteur
	-- Features.ShopFloor2) : 2e étage de la boutique, un Model `Floor_2` dans le gabarit Assets/Plots/PLOT_Shop
	-- (ShopStageService en pose une copie dans la boutique), ou déjà posé dans la boutique. Avec lui, le bas s'arrête à
	-- GroundSlots présentoirs ; une fois ceux-ci achetés, on achète l'étage (Cost), qui apparaît d'un coup, puis ses places
	-- DisplaySlot_31 à _38 une à une (Costs), dans la suite de l'amélioration Display Stands (règles : Shared/ShopFloor).
	-- Les présentoirs bonus du gamepass (DisplaySlot_21 à _24, posés dans Floor_2 par Clément) s'ouvrent avec l'étage.
	Floor2 = {
		ModelName = "Floor_2", -- L-217
		GroundSlots = 8, -- L-294 : DisplaySlot_01 à _08 au rez-de-chaussée (64 × 48 depuis L-321)
		FirstSlot = 31, -- L-277 : DisplaySlot_31… (_21 à _30 : présentoirs bonus du gamepass)
		Slots = 8, -- L-294 : DisplaySlot_31 à _38
		-- V0 proposé (Cantin, 23/11) : la suite des prix du bas (Config/Upgrades, DisplaySlots, Costs[5] à [13]) : l'étage
		-- au prix de l'ancien 9e présentoir, ses 8 places à ceux des anciens 10e à 17e.
		Cost = 2_800,
		Costs = { 3_600, 4_800, 9_800, 20_000, 42_000, 72_000, 120_000, 300_000 },
	},
}

-- a486 (économie « B/T », Config/Economy) : avec la table 2, prix de l'étage (140K) et de ses 8 places (230K à 18B),
-- remplacés ici, après coup : les lignes Cost et Costs plus haut restent la table 1.
if ECO ~= nil then
	assert(type(ECO.Floor2Cost) == "number" and type(ECO.Floor2Costs) == "table", "Config/ShopGrowth : Floor2Cost ou Floor2Costs absent de Config/Economy")
	ShopGrowth.Floor2.Cost = ECO.Floor2Cost
	ShopGrowth.Floor2.Costs = ECO.Floor2Costs
end

return DeepFreeze(ShopGrowth)
