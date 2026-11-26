--!strict
-- EconomyProfile (a486, 25/11 ; note d'a479 « économie B/T », section 9) : conversion d'un profil d'une table de
-- l'économie à l'autre (Config/Economy), dans les deux sens. Module pur, sans service ni DataStore : DataService
-- l'appelle au chargement, sur une copie du profil, quand le profil n'est pas dans la table du serveur ; le banc a486
-- l'essaie hors de Studio.
--
-- Règle de Cantin (note, 9.2) : un joueur ne perd rien de ce qu'il a payé ou gagné, et il peut faire tout de suite ce
-- qu'il pouvait faire avant.
--   - Argent (Cash, Offline.Pending) : la « courbe des armes ». Repères = les prix des 6 armes payantes dans les deux
--     tables (Config/Economy, ToolPrices) ; entre deux armes, en proportion sur une échelle logarithmique ; sous la
--     première et au-dessus de la dernière, le rapport de celle-ci. Un montant qui achetait une arme achète la même.
--   - Speed (Stats.Speed) : la « courbe des panneaux » (repères = SpeedRequired des zones 2 à 6), appliquée à la
--     Speed affichée avec le meilleur trail possédé, puis redivisée par ce trail : toute zone ouverte reste ouverte.
--   - Meilleur revenu (Lifetime.BestIncome, WeeklyBoard.BestIncome) : ancien record × (revenu des objets exposés dans
--     la nouvelle table ÷ dans l'ancienne) ; sans objet exposé : gardé tel quel (V0 d'a486). Le revenu du moment
--     relève ensuite le record tout seul (LeaderboardService.TrackBest).
--   - Absence en cours (Offline.Income) : laissée dans l'ancienne table, marquée par Offline.IncomeEconomy ;
--     OfflineService calcule le gain avec l'ancien $/s puis le convertit (ConvertMoney).
--   - Rien d'autre n'est touché : objets, armes, auras, trails, niveaux, arbre, renaissances, index, achats Robux.
-- Retour exact : EconomyBackup garde les montants d'avant la dernière conversion (Before) et ceux d'après (After) ;
-- au retour vers la table de départ, un champ qui n'a pas bougé depuis (sa valeur vaut encore After) reprend Before.
-- Idempotent : le champ Economy du profil (absent = 1) passe à la table voulue ; un profil déjà dans cette table
-- n'est jamais reconverti.
--
-- API :
--   EconomyProfile.ProfileVersion(data) -> number                 table du profil (champ Economy ; absent = 1)
--   EconomyProfile.ConvertMoney(value, from, to) -> number        un montant en dollars
--   EconomyProfile.ConvertShownSpeed(shown, from, to) -> number   une Speed affichée
--   EconomyProfile.ConvertSpeed(speed, trail, from, to) -> number une Speed entraînée (trail = multiplicateur ≥ 1)
--   EconomyProfile.IncomeRatio(items, from, to) -> number?        revenu de `items` ({ IncomeRow } ; a497 : Before, After) dans
--                                                                 `to` ÷ dans `from` ; nil sans objet ou illisible
--   EconomyProfile.Convert(data, want, context) -> { string }?    convertit `data` vers la table `want` ; nil si déjà
--                                                                 dans cette table, sinon les lignes du journal.
--                                                                 context = { TrailMultiplier: number?,
--                                                                 IncomeRatio: number? } (calculés par DataService)
--   EconomyProfile.BackupKeys: { string }                         champs gardés dans EconomyBackup

local Economy = require(script.Parent.Config.Economy)

type Table = any

-- Un objet exposé pour IncomeRatio : sa rareté et la part de son revenu qui ne dépend pas de la table (Factor) ; a497 :
-- ou ses deux revenus, dans la table de départ (Before) et dans celle d'arrivée (After).
export type IncomeRow = { Rarity: string, Factor: number, Before: number?, After: number? }

-- Les 6 armes payantes, dans l'ordre de leur prix (le même dans les deux tables, vérifié plus bas).
local function weaponAnchors(tableData: Table, order: { string }): { number }
	local list: { number } = {}
	for _, id in order do
		table.insert(list, tableData.ToolPrices[id])
	end
	return list
end

local WEAPON_ORDER: { string } = {}
do
	local first: Table = Economy.Tables[1]
	for id, price in first.ToolPrices do
		if type(price) == "number" and price > 0 then
			table.insert(WEAPON_ORDER, id)
		end
	end
	table.sort(WEAPON_ORDER, function(a: string, b: string): boolean
		return first.ToolPrices[a] < first.ToolPrices[b]
	end)
end

local MONEY: { [number]: { number } } = {}
local SPEED: { [number]: { number } } = {}
for version, tableData in Economy.Tables do
	MONEY[version] = weaponAnchors(tableData, WEAPON_ORDER)
	local speed: { number } = {}
	for zone = 2, #tableData.SpeedRequired do
		table.insert(speed, tableData.SpeedRequired[zone])
	end
	SPEED[version] = speed
	-- Une courbe ne s'inverse que si ses repères montent strictement.
	for _, list in { MONEY[version], SPEED[version] } do
		for index = 2, #list do
			assert(list[index] > list[index - 1], `EconomyProfile : repères de la table {version} pas croissants`)
		end
	end
	assert(#MONEY[version] == #MONEY[1] and #SPEED[version] == #SPEED[1], `EconomyProfile : table {version} incomplète`)
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- La courbe de `fromList` vers `toList` (mêmes repères, croissants). Un repère donne exactement son repère ; entre
-- deux repères, le résultat reste entre leurs images (aucun arrondi ne fait passer sous une arme).
local function curve(value: number, fromList: { number }, toList: { number }): number
	if not isFinite(value) or value <= 0 then
		return value
	end
	local n = #fromList
	if value < fromList[1] then
		return math.min(value * (toList[1] / fromList[1]), toList[1])
	end
	if value >= fromList[n] then
		return math.max(value * (toList[n] / fromList[n]), toList[n])
	end
	for index = 1, n - 1 do
		local a, b = fromList[index], fromList[index + 1]
		if value < b then
			-- Deux armes au même prix dans les deux tables (Wrench, Crowbar) : le montant ne bouge pas, au dollar près.
			if toList[index] == a and toList[index + 1] == b then
				return value
			end
			local t = math.log(value / a) / math.log(b / a)
			local result = toList[index] * (toList[index + 1] / toList[index]) ^ t
			return math.clamp(result, toList[index], toList[index + 1])
		end
	end
	return value
end

local EconomyProfile = {}

EconomyProfile.BackupKeys = { "Cash", "Speed", "OfflinePending", "BestIncome", "WeekBestIncome" }

function EconomyProfile.ProfileVersion(data: any): number
	local version = if type(data) == "table" then data.Economy else nil
	if type(version) == "number" and Economy.Tables[version] ~= nil then
		return version
	end
	return 1
end

function EconomyProfile.ConvertMoney(value: number, from: number, to: number): number
	if from == to or MONEY[from] == nil or MONEY[to] == nil then
		return value
	end
	return curve(value, MONEY[from], MONEY[to])
end

function EconomyProfile.ConvertShownSpeed(shown: number, from: number, to: number): number
	if from == to or SPEED[from] == nil or SPEED[to] == nil then
		return shown
	end
	return curve(shown, SPEED[from], SPEED[to])
end

function EconomyProfile.ConvertSpeed(speed: number, trail: number?, from: number, to: number): number
	local multiplier = if isFinite(trail) and (trail :: number) >= 1 then trail :: number else 1
	if not isFinite(speed) or speed <= 0 then
		return speed
	end
	return EconomyProfile.ConvertShownSpeed(speed * multiplier, from, to) / multiplier
end

-- a497 : une ligne peut donner directement le revenu de l'objet dans chaque table (Before dans `from`, After dans `to` :
-- Formulas.ItemIncomeIn), puisque la zone ne compte plus de la même façon dans les deux tables (+25 % par zone, × 10 par
-- zone) ; sinon, comme avant, Income de la rareté de chaque table × Factor.
function EconomyProfile.IncomeRatio(items: { IncomeRow }, from: number, to: number): number?
	local fromTable: Table, toTable: Table = Economy.Tables[from], Economy.Tables[to]
	if fromTable == nil or toTable == nil then
		return nil
	end
	local before, after = 0, 0
	for _, item in items do
		local a: any, b: any
		if item.Before ~= nil or item.After ~= nil then
			a, b = item.Before, item.After
			if isFinite(a) and isFinite(b) and a > 0 and b > 0 then
				before += a
				after += b
			end
		else
			a, b = fromTable.Income[item.Rarity], toTable.Income[item.Rarity]
			if isFinite(a) and isFinite(b) and isFinite(item.Factor) and item.Factor > 0 then
				before += a * item.Factor
				after += b * item.Factor
			end
		end
	end
	if before > 0 and isFinite(after) then
		return after / before
	end
	return nil
end

-- Lecture et écriture des champs convertis (chemin du profil → valeur), sans créer de table qui manque.
local FIELDS: { [string]: { get: (data: any) -> any, set: (data: any, value: number) -> () } } = {
	Cash = {
		get = function(data: any): any
			return data.Cash
		end,
		set = function(data: any, value: number)
			data.Cash = value
		end,
	},
	Speed = {
		get = function(data: any): any
			return if type(data.Stats) == "table" then data.Stats.Speed else nil
		end,
		set = function(data: any, value: number)
			data.Stats.Speed = value
		end,
	},
	OfflinePending = {
		get = function(data: any): any
			return if type(data.Offline) == "table" then data.Offline.Pending else nil
		end,
		set = function(data: any, value: number)
			data.Offline.Pending = value
		end,
	},
	BestIncome = {
		get = function(data: any): any
			return if type(data.Lifetime) == "table" then data.Lifetime.BestIncome else nil
		end,
		set = function(data: any, value: number)
			data.Lifetime.BestIncome = value
		end,
	},
	WeekBestIncome = {
		get = function(data: any): any
			return if type(data.WeeklyBoard) == "table" then data.WeeklyBoard.BestIncome else nil
		end,
		set = function(data: any, value: number)
			data.WeeklyBoard.BestIncome = value
		end,
	},
}

export type Context = { TrailMultiplier: number?, IncomeRatio: number? }

function EconomyProfile.Convert(data: any, want: number, context: Context?): { string }?
	assert(Economy.Tables[want] ~= nil, `EconomyProfile.Convert : table {tostring(want)} inconnue`)
	local have = EconomyProfile.ProfileVersion(data)
	if have == want then
		return nil
	end
	local ctx: Context = context or {}
	local ratio = ctx.IncomeRatio
	local convert: { [string]: (value: number) -> number } = {
		Cash = function(value: number): number
			return EconomyProfile.ConvertMoney(value, have, want)
		end,
		Speed = function(value: number): number
			return EconomyProfile.ConvertSpeed(value, ctx.TrailMultiplier, have, want)
		end,
		-- Dollars entiers en attente du Claim : arrondis vers le bas, comme le gain hors ligne.
		OfflinePending = function(value: number): number
			return math.floor(EconomyProfile.ConvertMoney(value, have, want))
		end,
		BestIncome = function(value: number): number
			return if ratio ~= nil and isFinite(ratio) and ratio > 0 then value * ratio else value
		end,
	}
	convert.WeekBestIncome = convert.BestIncome

	-- Retour exact vers la table d'avant la dernière conversion, champ par champ (voir l'en-tête).
	local backup: any = data.EconomyBackup
	local restorable = type(backup) == "table"
		and backup.From == want
		and backup.To == have
		and type(backup.Before) == "table"
		and type(backup.After) == "table"
	local before: { [string]: number } = {}
	local after: { [string]: number } = {}
	local lines: { string } = {}
	local restored, converted = 0, 0
	for _, key in EconomyProfile.BackupKeys do
		local field = FIELDS[key]
		local value = field.get(data)
		if isFinite(value) and value > 0 then
			local new: number
			if restorable and backup.After[key] == value and isFinite(backup.Before[key]) then
				new = backup.Before[key]
				restored += 1
			else
				new = convert[key](value)
				converted += 1
			end
			field.set(data, new)
			before[key] = value
			after[key] = new
		end
	end
	data.EconomyBackup = { From = have, To = want, Before = before, After = after }
	-- Absence en cours : son $/s reste celui de la table où il a été noté (OfflineService le convertit).
	if type(data.Offline) == "table" and isFinite(data.Offline.Income) and data.Offline.Income > 0 then
		if type(data.Offline.IncomeEconomy) ~= "number" then
			data.Offline.IncomeEconomy = have
		end
	end
	data.Economy = want
	table.insert(lines, `économie table {have} → table {want} : {converted} montant(s) converti(s), {restored} repris de la sauvegarde d'avant`)
	return lines
end

return EconomyProfile
