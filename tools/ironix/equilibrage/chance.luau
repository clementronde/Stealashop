--!nocheck
-- Chance de l'ouverture des colis dans le magasin (liaison L-112, décisions de Cantin du 2026-11-12 ;
-- agent a106, vague 31). Rien ici n'est dans le jeu : la table « Proposee » est une PROPOSITION, à coller
-- dans src/shared/Config/ShelfOpen.luau (LuckTable) après l'accord de Cantin.
--
-- Règles reprises du code (sans les modifier) :
--   - montée : Shared/ShelfOpenState (rabats FlapsTime, puis × LuckStep tous les LuckTick s) ;
--   - « ? » des témoins : WitnessService.Raise, de 0 à 1 en Witness.FillTime s ; plein = appel, la
--     police part au marqueur Call (Hypotheses.MarqueurAppel) et l'objet sort alors (chance arrêtée là) ;
--   - crans : UnboxService.rollUpgrades (UpgradeMax crans, chacun à UpgradeChance × la chance, borné à 1 ;
--     jamais vers Secret ni au-dessus, jamais vers une rareté que ce colis ne donne pas dans sa zone, ni
--     sans objet dans la zone ; un contenu imposé n'est jamais amélioré).
--
-- Utilisé par rapport.luau (section 12) et, par l'accroche Modele.Ouverture, par les parties simulées.

local ShelfOpen = Config.ShelfOpen
local Witness = Config.Witness
local Rarities = Config.Rarities
local ShelfBoxes = Config.ShelfBoxes
local Items = Config.Items
local Balance = Config.Balance

local Chance = {}

-- Hypothèses (pas des valeurs du jeu).
Chance.Hypotheses = {
	MarqueurAppel = 0.4, -- s entre « ? » plein et départ de la police (marqueur Call posé par Clément à 0,4 s)
	Atteinte = 3, -- s entre la casse et le lancement de l'ouverture (même valeur que Modele.Hypotheses.InStore)
	RemplissageDepart = 0, -- « ? » au lancement : la vitrine cassée l'a vidé (Witness.EmptyTime = 1 s)
}

-- Tables de chance { Luck, Weight }.
Chance.Tables = {
	-- Ce qui est dans le jeu (Config/ShelfOpen, V0 provisoire).
	V0 = ShelfOpen.LuckTable,
	-- PROPOSÉ (a106) : souvent rien, parfois un bon coup, rarement un jackpot.
	--   ×1    : 55 %   l'objet sort juste après les rabats (0,6 s)
	--   ×1,5  : 20 %   petit frisson (2,0 s)
	--   ×2    : 12 %   (3,0 s)
	--   ×3    : 7 %    bon coup, « ? » à moitié (4,4 s)
	--   ×5    : 4 %    gros coup, « ? » orange (6,1 s)
	--   ×8    : 1,5 %  frôle la police : « ? » rouge à 96 % (7,7 s)
	--   ×10   : 0,5 %  jackpot : deux crans sûrs, mais la police part (8,4 s)
	Proposee = {
		{ Luck = 1, Weight = 55 },
		{ Luck = 1.5, Weight = 20 },
		{ Luck = 2, Weight = 12 },
		{ Luck = 3, Weight = 7 },
		{ Luck = 5, Weight = 4 },
		{ Luck = 8, Weight = 1.5 },
		{ Luck = 10, Weight = 0.5 },
	},
}

-- Crans sans limite (décision de Cantin du 2026-11-12 au soir), formule d'a103 :
--   chance du cran n = min(UpgradeChance × chance, UpgradeChanceCap) × UpgradeDecay^(n − 1),
--   arrêt au premier échec ou à UpgradeTop. PROPOSÉ (a106), à coller dans Config/ShelfOpen.
Chance.Crans_Proposes = {
	UpgradeChance = 0.08, -- tirage ×1 : 8 % au premier cran ; ×10 : 80 % (économie proche des 2 crans)
	UpgradeChanceCap = 0.9, -- jamais un cran sûr ; aucun palier de la table ne l'atteint (×10 : 80 %)
	UpgradeDecay = 0.7, -- la chance de chaque cran est celle du précédent × 0,7
	UpgradeTop = "Secret", -- Divine exclue
}

---------------------------------------------------------------------------------------------- montée

-- Même calcul que Shared/ShelfOpenState.ticksTo et revealDelay.
function Chance.Tics(luck)
	if not (luck > 1) then
		return 0
	end
	return math.ceil(math.log(luck) / math.log(ShelfOpen.LuckStep) - 1e-9)
end
function Chance.Delai(luck)
	return ShelfOpen.FlapsTime + Chance.Tics(luck) * ShelfOpen.LuckTick
end

-- Ce qui se passe pour une chance tirée : { Delai, Remplissage (« ? » à la sortie, 0 à 1), Police (bool),
-- Atteinte (chance réellement atteinte : la police arrête la montée) }.
function Chance.Issue(luck)
	local H = Chance.Hypotheses
	local delay = Chance.Delai(luck)
	local full = Witness.FillTime * (1 - H.RemplissageDepart) -- « ? » plein à cet instant
	if delay <= full then
		return { Delai = delay, Remplissage = H.RemplissageDepart + delay / Witness.FillTime, Police = false, Atteinte = luck }
	end
	local stop = full + H.MarqueurAppel -- la police part : l'objet sort tout de suite
	if delay <= stop then
		return { Delai = delay, Remplissage = 1, Police = true, Atteinte = luck }
	end
	local ticks = math.max(0, math.floor((stop - ShelfOpen.FlapsTime) / ShelfOpen.LuckTick))
	return { Delai = stop, Remplissage = 1, Police = true, Atteinte = math.min(luck, ShelfOpen.LuckStep ^ ticks) }
end

-- La prise doit finir avant la fin du chrono du magasin (Balance.Heist.Duration) : vrai si
-- Atteinte + délai + maintien du Tier tient dedans.
function Chance.TientDansChrono(luck, tier)
	local issue = Chance.Issue(luck)
	return Chance.Hypotheses.Atteinte + issue.Delai + Balance.Heist.BoxTiers[tier].GrabTime <= Balance.Heist.Duration
end

function Chance.Poids(luckTable)
	local total = 0
	for _, entry in luckTable do
		total += entry.Weight
	end
	return total
end

function Chance.Tirer(random, luckTable)
	local roll = random() * Chance.Poids(luckTable)
	for _, entry in luckTable do
		if roll < entry.Weight then
			return entry.Luck
		end
		roll -= entry.Weight
	end
	return luckTable[#luckTable].Luck
end

---------------------------------------------------------------------------------------------- crans

local SECRET_ORDER = Rarities.ById.Secret.Order

local function oddsOf(zone, tier, rarityId)
	local odds = ShelfBoxes.OddsFor(zone, tier)
	return if odds then odds[rarityId] or 0 else 0
end
local function hasItem(zone, rarityId)
	local list = Items.AllZones[rarityId] or (Items.ByZone[zone] and Items.ByZone[zone][rarityId])
	return list ~= nil and #list > 0
end

-- Rareté au-dessus de `rarityId` qu'un cran peut viser, ou nil. `regle` : "Jeu" (la règle du code de la
-- vague 30 : 2 crans, jamais Secret, seulement ce que le colis donne dans sa zone), "Libre" (seule la
-- présence d'un objet compte) ou "Infini" (décision de Cantin du 2026-11-12 au soir : aucune limite de
-- zone ni d'objet, jusqu'à `top`, l'Id de la rareté la plus haute qu'un cran peut atteindre).
local function nextFor(zone, tier, rarityId, regle, top)
	local nextRarity = Rarities.List[Rarities.ById[rarityId].Order + 1]
	if nextRarity == nil then
		return nil
	end
	if regle == "Infini" then
		return if nextRarity.Order <= Rarities.ById[top or "Secret"].Order then nextRarity.Id else nil
	end
	if regle == "Libre" then
		return if hasItem(zone, nextRarity.Id) then nextRarity.Id else nil
	end
	if nextRarity.Order >= SECRET_ORDER or oddsOf(zone, tier, nextRarity.Id) <= 0 or not hasItem(zone, nextRarity.Id) then
		return nil
	end
	return nextRarity.Id
end

-- Probabilité de chaque rareté finale, partant de `rarityId`, le cran n réussi avec `pOf(n)` (un nombre
-- est accepté : même chance à chaque cran).
function Chance.Crans(zone, tier, rarityId, pOf, upgradeMax, regle, top)
	if type(pOf) == "number" then
		local p = pOf
		pOf = function()
			return p
		end
	end
	local out = {}
	if regle ~= "Libre" and oddsOf(zone, tier, rarityId) <= 0 then
		out[rarityId] = 1 -- contenu imposé : jamais amélioré
		return out
	end
	local current, reach = rarityId, 1
	for n = 1, upgradeMax do
		local nextId = nextFor(zone, tier, current, regle, top)
		if nextId == nil then
			break
		end
		local p = pOf(n)
		out[current] = (out[current] or 0) + reach * (1 - p)
		reach *= p
		current = nextId
	end
	out[current] = (out[current] or 0) + reach
	return out
end

-- Un « mode » d'ouverture : { Nom, Table (nil = chance fixe 1), UpgradeChance, UpgradeMax, Boost (×,
-- défaut 1), BoostSur ("Crans" : la chance de cran seule ; "Compteur" : la chance tirée), Regle, et pour la
-- règle "Infini" : Cap (UpgradeChanceCap), Decay (UpgradeDecay), Top (UpgradeTop) }.
-- Chance du cran n (formule d'a103) : min(UpgradeChance × chance, Cap) × Decay^(n − 1) ; sans Cap :
-- UpgradeChance × chance bornée à 1, la même à chaque cran (règle de la vague 30).
local function cranChance(mode, luck, n)
	local boost = mode.Boost or 1
	local effective = if mode.BoostSur == "Compteur" then luck else luck * boost
	if mode.Cap ~= nil then
		return math.min(mode.UpgradeChance * effective, mode.Cap) * (mode.Decay or 1) ^ ((n or 1) - 1)
	end
	return math.clamp(mode.UpgradeChance * effective, 0, 1)
end
Chance.CranChance = cranChance
local function pFor(mode, luck)
	return function(n)
		return cranChance(mode, luck, n)
	end
end
Chance.PFor = pFor
local function drawnLuck(mode, luck)
	return if mode.BoostSur == "Compteur" then luck * (mode.Boost or 1) else luck
end

-- Lignes { Luck (tirée), Proba, Atteinte, Police } d'un mode.
function Chance.Lignes(mode)
	local lines = {}
	if mode.Table == nil then
		return { { Luck = 1, Proba = 1, Atteinte = 1, Police = false } }
	end
	local total = Chance.Poids(mode.Table)
	for _, entry in mode.Table do
		local luck = drawnLuck(mode, entry.Luck)
		local issue = Chance.Issue(luck)
		table.insert(lines, { Luck = luck, Proba = entry.Weight / total, Atteinte = issue.Atteinte, Police = issue.Police, Delai = issue.Delai })
	end
	return lines
end

-- Répartition finale des raretés d'un colis (zone, type) dans ce mode : { [RarityId] = proba }.
function Chance.Repartition(zone, tier, mode)
	local result = {}
	local odds = ShelfBoxes.OddsFor(zone, tier)
	for _, line in Chance.Lignes(mode) do
		local p = pFor(mode, line.Atteinte)
		for rarityId, share in odds do
			if share > 0 then
				for finalId, q in Chance.Crans(zone, tier, rarityId, p, mode.UpgradeMax, mode.Regle, mode.Top) do
					result[finalId] = (result[finalId] or 0) + line.Proba * share / 100 * q
				end
			end
		end
	end
	return result
end

-- Résumé d'une répartition : multiplicateur de revenu moyen, P(≥ Épique), P(≥ Légendaire), P(≥ Mythique).
function Chance.Resume(repartition)
	local mean, epic, legendary, mythic = 0, 0, 0, 0
	for rarityId, q in repartition do
		local rarity = Rarities.ById[rarityId]
		mean += q * rarity.IncomeMultiplier
		if rarity.Order >= Rarities.ById.Epic.Order then
			epic += q
		end
		if rarity.Order >= Rarities.ById.Legendary.Order then
			legendary += q
		end
		if rarity.Order >= Rarities.ById.Mythic.Order then
			mythic += q
		end
	end
	return { Moyenne = mean, Epique = epic, Legendaire = legendary, Mythique = mythic }
end

-- Moyenne de la chance tirée, du délai, part des ouvertures avec police, nombre moyen de crans (×1).
function Chance.Stats(mode)
	local luck, delay, police = 0, 0, 0
	for _, line in Chance.Lignes(mode) do
		luck += line.Proba * line.Luck
		delay += line.Proba * (line.Delai or 0)
		if line.Police then
			police += line.Proba
		end
	end
	return { Chance = luck, Delai = delay, Police = police }
end

---------------------------------------------------------------------------------------------- modes

function Chance.Modes()
	return {
		Aujourdhui = { Nom = "Aujourd'hui (ouvert en base, chance ×1)", Table = nil, UpgradeChance = Config.Unbox.UpgradeChance, UpgradeMax = Config.Unbox.UpgradeMax, Base = true },
		V0 = { Nom = "L-112, table V0 du jeu", Table = Chance.Tables.V0, UpgradeChance = ShelfOpen.UpgradeChance, UpgradeMax = ShelfOpen.UpgradeMax },
		Proposee = { Nom = "L-112, table proposée", Table = Chance.Tables.Proposee, UpgradeChance = ShelfOpen.UpgradeChance, UpgradeMax = ShelfOpen.UpgradeMax },
		-- Décision de Cantin (2026-11-12, soir) : crans sans limite, formule d'a103, V0 d'a103.
		InfiniV0 = { Nom = "Crans sans limite, V0 d'a103", Table = Chance.Tables.Proposee, Regle = "Infini", UpgradeMax = math.huge, UpgradeChance = 0.10, Cap = 0.9, Decay = 1, Top = "Secret" },
		-- PROPOSÉ (a106) : la même formule, la chance de chaque cran ×0,6 par rapport au précédent.
		Infini = { Nom = "Crans sans limite, proposé", Table = Chance.Tables.Proposee, Regle = "Infini", UpgradeMax = math.huge, UpgradeChance = Chance.Crans_Proposes.UpgradeChance, Cap = Chance.Crans_Proposes.UpgradeChanceCap, Decay = Chance.Crans_Proposes.UpgradeDecay, Top = Chance.Crans_Proposes.UpgradeTop },
	}
end

-- Accroche pour Modele.Ouverture : renvoie function(random, zone, tier, rarityId, imposed) ->
-- (rareté finale, attente avant présentoir, secondes passées dans le magasin, police partie).
-- Mode « Base » : l'ancienne ouverture en base (attente OpenDelay de la rareté finale, rien dans le magasin).
-- Sinon : chance tirée, montée dans le magasin, antivol ShelfOpen.AntiTheft au lieu d'OpenDelay.
function Chance.Accroche(mode)
	return function(random, zone, tier, rarityId, imposed)
		local luck = 1
		local issue = { Delai = 0, Police = false, Atteinte = 1 }
		if mode.Table ~= nil then
			luck = drawnLuck(mode, Chance.Tirer(random, mode.Table))
			issue = Chance.Issue(luck)
		end
		local final = rarityId
		if not imposed then
			local current = rarityId
			if oddsOf(zone, tier, current) > 0 or mode.Regle == "Libre" then
				for n = 1, mode.UpgradeMax do
					local nextId = nextFor(zone, tier, current, mode.Regle, mode.Top)
					if nextId == nil or random() >= cranChance(mode, issue.Atteinte, n) then
						break
					end
					current = nextId
				end
			end
			final = current
		end
		local wait = if mode.Base or mode.AttenteOpenDelay then Rarities.ById[final].OpenDelay else ShelfOpen.AntiTheft[final]
		return final, wait, if mode.Base then 0 else issue.Delai, issue.Police
	end
end

return Chance
