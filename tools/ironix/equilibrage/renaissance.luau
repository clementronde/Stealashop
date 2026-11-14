--!nocheck
-- Renaissances dans l'économie v2 (passe 3) : proposition de l'agent a145 (2026-11-14), rien n'est dans le jeu.
-- Note : docs/claude/notes/renaissance-proposition.md. Lancer :
--   RAPPORT=renaissance bash tools/ironix/equilibrage/run.sh             rapport complet (6 min environ)
--   RAPPORT=renaissance COURT=1 bash tools/ironix/equilibrage/run.sh     seulement la proposition, joueur moyen
--
-- Une partie simulée enchaîne 10 cycles. Chaque cycle est une partie de Modele.Jouer (économie V2, passe 3) qui
-- part de l'état laissé par la renaissance d'avant et s'arrête quand le joueur a l'argent requis ET l'objet requis.
-- À la renaissance :
--   perd   argent, Speed, niveau du tapis, présentoirs achetés, outils, auras, trails, colis pas encore ouverts,
--          tous les objets sauf ceux qu'il garde ; l'objet requis est remis (il disparaît)
--   garde  Garde objets au choix (les meilleurs, hors objet requis), l'index, l'arbre de compétences, les achats
--          Robux (ni l'index, ni l'arbre, ni le Robux ne sont simulés : le jeu réel ira un peu plus vite)
--   gagne  +Bonus de revenus des présentoirs par renaissance (additionnés : ×1,5, ×2, ×2,5…) et la récompense
--          du palier (seules celles qui changent une durée sont simulées : entraînement, outil gardé)
--
-- L'objet requis tombe d'un colis de sa zone et de sa rareté avec la chance 1 / (nombre d'objets de cette rareté
-- dans la zone, Config/Items.ByZone) ; il ne compte que s'il est gagné après la renaissance d'avant. Quand il
-- manque et que le joueur est en zone 6 avec la moitié de l'argent, il va braquer la zone de l'objet (Chasse).

local Modele = charge("Outil/modele")
local V2 = charge("Outil/proposition_v2")
local Items = Config.Items

local R = {}

R.Bonus = 0.5 -- +50 % de revenus permanents par renaissance (Partie 2, 3.2, gardé)
R.Garde = 3 -- objets gardés (Partie 2, 3.2, gardé)
R.ChasseDes = 0 -- part de l'argent requis à partir de laquelle le joueur part chercher l'objet manquant
-- Fortune Tower (MAJ 2, 2/1 ; Config/FortuneTower, L-145) : hypothèse, pas une valeur du jeu. Une tour toutes les
-- Every s de jeu en zone 6 ; le joueur y gagne Boxes colis, Mythique à Mythic (90 %). Le seul Mythique de la
-- zone 6 est la Clé du coffre ultime : la tour ne sert qu'à l'objet requis de la 10e.
R.Fortune = { Every = 50 * 60, Boxes = 1, Mythic = 0.9 }

-- Cible (consigne du 14/11) : 1re renaissance après la zone 6, vers 7 h 30 à 9 h ; chaque cycle suivant un peu
-- plus court que le premier, jamais moins de 40 % ; 10e vers 60 à 80 h cumulées. Part visée de la durée du
-- 1er cycle, renaissance par renaissance (10e : 8,2 × le 1er cycle, soit 67 h 39 si le 1er fait 8 h 15).
R.Cible1 = 8.25 * 3600
R.Part = { 1, 0.95, 0.9, 0.85, 0.8, 0.8, 0.75, 0.75, 0.7, 0.7 }

-- Le tableau proposé. Cash : argent requis ; Objet : ItemId (Config/Items) ; Entrainement : multiplicateur du
-- tapis gagné à ce palier (cumulé) ; Outil : outil gardé à partir de ce palier (Id de Config/Tools).
R.Paliers = {
	{ Cash = 20e9, Objet = "Z6_DiamantGeant", Recompense = "Aura « Renaissance » (sans effet sur les dégâts)" },
	{ Cash = 500e9, Objet = "Z6_TroneEnOr", Recompense = "+1 coffre-fort" },
	{ Cash = 1.3e12, Objet = "Z6_StatueDeLaLiberte", Recompense = "Tapis ×1,5", Entrainement = 1.5 },
	{ Cash = 2e12, Objet = "Z2_PelucheGeante", Recompense = "Trail « Renaissance » (sans effet sur la Speed)" },
	{ Cash = 2.6e12, Objet = "Z3_PcGamer", Recompense = "Marteau-piqueur (= Angle Grinder, gardé)", Outil = "AngleGrinder" },
	{ Cash = 3.2e12, Objet = "Z4_Couronne", Recompense = "Tapis ×1,5 (×2,25 en tout)", Entrainement = 1.5 },
	{ Cash = 5e12, Objet = "Z5_MasqueAncien", Recompense = "Bélier (portes des joueurs seulement)" },
	{ Cash = 7e12, Objet = "Z6_CoffreDeDiamants", Recompense = "2e agent de sécurité (MAJ 5)" },
	{ Cash = 7.5e12, Objet = "Z6_CleDuCoffreUltime", Recompense = "Aura « Légende » (sans effet sur les dégâts)" },
	{ Cash = 9e12, Objet = "Z6_CleDuCoffreUltime", Recompense = "Titre au-dessus de la tête" },
}

-- La même échelle, telle que la Partie 2 (3.2) l'écrit aujourd'hui, pour comparer.
R.PartieDeux = {
	{ Cash = 10e3, Objet = "Z1_PotDeNouilles" },
	{ Cash = 100e3, Objet = "Z2_VoitureTelecommandee" },
	{ Cash = 1e6, Objet = "Z2_RobotJouet", Entrainement = 1.25 },
	{ Cash = 10e6, Objet = "Z3_ConsolePortable" },
	{ Cash = 100e6, Objet = "Z4_DiamantBrut" },
	{ Cash = 1e9, Objet = "Z4_Couronne", Entrainement = 1.25 },
	{ Cash = 10e9, Objet = "Z5_MasqueAncien" },
	{ Cash = 100e9, Objet = "Z6_CoffreDeDiamants" },
	{ Cash = 1e12, Objet = "Z5_Meteorite" },
	{ Cash = 10e12, Objet = "Z6_CleDuCoffreUltime" },
}

local function toolIndex(eco, id)
	for index, tool in eco.Tools do
		if tool.Id == id then
			return index
		end
	end
	error(`renaissance : outil inconnu {id}`)
end

-- Chance qu'un objet de cette zone et de cette rareté soit l'objet requis (nil si ce n'est pas sa case).
local function itemShare(itemId)
	local item = Items.ById[itemId]
	assert(item ~= nil and item.Zone ~= nil, `renaissance : objet inconnu ou sans zone {itemId}`)
	local count = 0
	for _, other in Items.ByZone[item.Zone][item.Rarity] do
		if not other.TutorialOnly then
			count += 1
		end
	end
	return item, if item.TutorialOnly then 1 else 1 / math.max(1, count)
end
R.ItemShare = itemShare

-- Une partie de 10 renaissances (ou jusqu'à maxSeconds). Réglages : { Paliers, Bonus, Garde, SansOutil }.
-- Renvoie { Cycles[n] = { Fin, Duree, Zone6, Objet, Revenu, Cash, Garde } } (temps en s, cumulés depuis 0).
function R.Partie(eco, profil, seed, reglages, maxSeconds)
	local paliers = reglages.Paliers or R.Paliers
	local bonus = reglages.Bonus or R.Bonus
	local garde = reglages.Garde or R.Garde
	local depart = { T = 0, Stands = {}, Tool = 1 }
	local training = 1
	local result = { Cycles = {} }
	for n, palier in paliers do
		local item, share = itemShare(palier.Objet)
		local found, foundAt, foundIncome = false, nil, nil
		local towersSeen = 0
		local zoneCount = #eco.Zones
		local options = {
			Depart = depart,
			Revenu = 1 + bonus * (n - 1),
			Entrainement = training,
			SansTuto = n > 1,
			Objet = function(zone, rarityId, income, s)
				if found or zone ~= item.Zone or rarityId ~= item.Rarity then
					return
				end
				-- Premier colis du tuto : Rare garanti, c'est le Pot de nouilles (Config/Tutorial).
				local tutorial = item.TutorialOnly and n == 1
				if tutorial or (not item.TutorialOnly and math.random() < share) then
					found, foundAt, foundIncome = true, s.t, income
				end
			end,
			Chasse = function(s, _out)
				if found or s.zone < zoneCount or s.cash < R.ChasseDes * palier.Cash then
					return nil
				end
				return item.Zone
			end,
			Fin = function(s, out)
				local fortune = if reglages.SansFortune then nil else R.Fortune
				local entered = out.Entrees[zoneCount]
				if not found and fortune and entered and item.Zone == zoneCount and item.Rarity == "Mythic" then
					local towers = (s.t - entered.T) // fortune.Every
					while towersSeen < towers and not found do
						towersSeen += 1
						for _ = 1, fortune.Boxes do
							if not found and math.random() < fortune.Mythic * share then
								found, foundAt, foundIncome = true, s.t, nil
							end
						end
					end
				end
				return found and s.cash >= palier.Cash
			end,
		}
		math.randomseed(seed * 1009 + n)
		local out = Modele.Jouer(eco, profil, seed * 100 + n, maxSeconds, options)
		local s = out.Etat
		if not (found and s.cash >= palier.Cash) then
			break -- pas fini dans le temps donné
		end
		local start = depart.T
		local cycle = {
			Fin = s.t,
			Duree = s.t - start,
			Zone6 = if out.Entrees[zoneCount] then out.Entrees[zoneCount].T - start else nil,
			Objet = foundAt - start,
			Revenu = (function()
				local total = 0
				for _, income in s.stands do
					total += income
				end
				return total * options.Revenu
			end)(),
			Cash = s.cash,
		}
		-- Renaissance : l'objet requis est remis, on garde les meilleurs objets restants.
		local stands = table.clone(s.stands)
		for index, income in stands do
			if income == foundIncome then
				table.remove(stands, index)
				break
			end
		end
		table.sort(stands, function(a, b)
			return a > b
		end)
		local kept = {}
		for index = 1, math.min(garde, #stands) do
			kept[index] = stands[index]
		end
		cycle.Garde = 0
		for _, income in kept do
			cycle.Garde += income
		end
		result.Cycles[n] = cycle
		training *= palier.Entrainement or 1
		local tool = depart.Tool
		if palier.Outil and not reglages.SansOutil then
			tool = toolIndex(eco, palier.Outil)
		end
		depart = { T = s.t, Stands = kept, Tool = tool }
	end
	return result
end

-- Zone 6 (décision 4) : avec des dégâts k × D (D = Angle Grinder × Royal = 2M), temps de casse de la vitrine
-- de 108.8M dans le chrono de 8 s, régénération 3 %/s, 5 coups/s par joueur.
function R.Zone6(k)
	local eco = V2.Construire()
	local info = eco.Zones[#eco.Zones]
	local D = eco.BestDamage
	local function t(hits, mult)
		return Modele.BreakTime(info.WindowHP, D * k * mult, hits)
	end
	return {
		Seul = t(V2.MaxHitsPerSecond, 1),
		SeulPotion = t(V2.MaxHitsPerSecond, V2.PotionStrength),
		Deux = t(2 * V2.MaxHitsPerSecond, 1),
		HP = info.WindowHP,
	}
end

return R
