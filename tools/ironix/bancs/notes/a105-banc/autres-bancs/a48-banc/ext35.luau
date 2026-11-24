---------------------------------------------------------------- a35 : compléments du faux Roblox (télémétrie, DEV-054)
-- Ajouts au faux d'a30 (stubs.luau) et aux compléments d'a29 et d'a32 (ext29.luau, ext32.luau) :
--   - les énumérations de l'Analytics (AnalyticsEconomyFlowType, AnalyticsEconomyTransactionType,
--     AnalyticsCustomFieldKeys) : de vrais membres (Name, EnumType, GetEnumItems), un membre inconnu
--     lève une erreur comme Roblox. Les autres énumérations restent des textes (« Enum.X.Y »), comme
--     le faux d'a30 ;
--   - AnalyticsService (faux) : chaque appel est noté dans ANALYTICS.all et par sorte
--     (ANALYTICS.economy, .custom, .funnel). Il vérifie ses arguments comme Roblox : un Player, un sens
--     de Enum.AnalyticsEconomyFlowType, des textes non vides sans virgule, guillemet ni apostrophe,
--     un montant > 0, un solde fini, des champs CustomField01 à 03 en texte. Un argument refusé lève
--     « Event field <champ> is invalid » (vu en Studio le 2026-11-07) et l'appel est noté dans
--     ANALYTICS.refused. ANALYTICS_FAILS = true : tout appel lève une erreur (Roblox qui refuse) ;
--   - « prod » : PROD_SERVER = true avant startServer() fait répondre RunService:IsStudio() = false
--     à tous les modules du serveur (voir pre.prod.luau).

ANALYTICS = { all = {}, economy = {}, custom = {}, funnel = {}, refused = {} }
ANALYTICS_FAILS = false
ANALYTICS_FORBIDDEN = { ",", '"', "'", "`", "’", "‘", "“", "”", "«", "»" }

do
	local baseEnum = Enum
	local MEMBERS = {
		AnalyticsEconomyFlowType = { "Source", "Sink" },
		AnalyticsEconomyTransactionType = { "IAP", "TimedReward", "Onboarding", "Shop", "Gameplay", "ContextualPurchase" },
		AnalyticsCustomFieldKeys = { "CustomField01", "CustomField02", "CustomField03" },
	}
	local enums = {}
	for enumName, names in MEMBERS do
		local items = {}
		local list = {}
		for index, name in names do
			local item = setmetatable({ Name = name, Value = index - 1, EnumType = enumName }, {
				__type = "EnumItem",
				__tostring = function()
					return `Enum.{enumName}.{name}`
				end,
			})
			items[name] = item
			table.insert(list, item)
		end
		enums[enumName] = setmetatable({}, {
			__index = function(_, key)
				if key == "GetEnumItems" then
					return function()
						return table.clone(list)
					end
				elseif key == "FromName" then
					return function(_self, name)
						return items[name]
					end
				end
				local item = items[key]
				if item == nil then
					error(`{tostring(key)} is not a valid member of "Enum.{enumName}"`, 2)
				end
				return item
			end,
		})
	end
	Enum = setmetatable({}, {
		__index = function(_, enumName)
			return enums[enumName] or baseEnum[enumName]
		end,
	})
end

function analyticsSafe(text)
	if type(text) ~= "string" or text == "" then
		return false
	end
	for _, token in ANALYTICS_FORBIDDEN do
		if string.find(text, token, 1, true) then
			return false
		end
	end
	return true
end

do
	local VALID_KEYS = { CustomField01 = true, CustomField02 = true, CustomField03 = true }
	local function isPlayer(value)
		return type(value) == "table" and value.ClassName == "Player"
	end
	local function finite(value)
		return type(value) == "number" and value == value and math.abs(value) < math.huge
	end
	-- Refus comme Roblox : noté, puis erreur.
	local function refuse(entry, fieldName)
		entry.refusedField = fieldName
		table.insert(ANALYTICS.refused, entry)
		error(`Event field {fieldName} is invalid`, 0)
	end
	local function checkFields(entry, fields)
		if fields == nil then
			return
		end
		if type(fields) ~= "table" then
			refuse(entry, "customFields")
		end
		for key, value in fields do
			if not VALID_KEYS[key] then
				refuse(entry, "customFields")
			end
			if not analyticsSafe(value) then
				refuse(entry, key)
			end
		end
	end
	local function record(kind, entry)
		entry.kind = kind
		entry.t = now()
		if ANALYTICS_FAILS then
			table.insert(ANALYTICS.refused, entry)
			error("AnalyticsService: events can't be sent from Studio", 0)
		end
	end
	AnalyticsStub = {
		LogEconomyEvent = function(_self, player, flowType, currency, amount, balance, transaction, sku, fields, extra)
			local entry = {
				player = player,
				flow = flowType,
				currency = currency,
				amount = amount,
				balance = balance,
				transaction = transaction,
				sku = sku,
				fields = fields,
				extra = extra,
			}
			record("economy", entry)
			if not isPlayer(player) then
				refuse(entry, "player")
			end
			if type(flowType) ~= "table" or flowType.EnumType ~= "AnalyticsEconomyFlowType" then
				refuse(entry, "flowType")
			end
			if not analyticsSafe(currency) then
				refuse(entry, "currencyType")
			end
			if not finite(amount) or amount <= 0 then
				refuse(entry, "amount")
			end
			if not finite(balance) then
				refuse(entry, "endingBalance")
			end
			if not analyticsSafe(transaction) then
				refuse(entry, "transactionType")
			end
			if sku ~= nil and not analyticsSafe(sku) then
				refuse(entry, "itemSku")
			end
			checkFields(entry, fields)
			if extra ~= nil then
				refuse(entry, "extra")
			end
			table.insert(ANALYTICS.economy, entry)
			table.insert(ANALYTICS.all, entry)
		end,
		LogCustomEvent = function(_self, player, eventName, value, fields, extra)
			local entry = { player = player, name = eventName, value = value, fields = fields, extra = extra }
			record("custom", entry)
			if not isPlayer(player) then
				refuse(entry, "player")
			end
			if not analyticsSafe(eventName) then
				refuse(entry, "eventName")
			end
			if value ~= nil and not finite(value) then
				refuse(entry, "value")
			end
			checkFields(entry, fields)
			if extra ~= nil then
				refuse(entry, "extra")
			end
			table.insert(ANALYTICS.custom, entry)
			table.insert(ANALYTICS.all, entry)
		end,
		LogOnboardingFunnelStepEvent = function(_self, player, step, stepName, fields, extra)
			local entry = { player = player, step = step, name = stepName, fields = fields, extra = extra }
			record("funnel", entry)
			if not isPlayer(player) then
				refuse(entry, "player")
			end
			if not finite(step) then
				refuse(entry, "step")
			end
			if stepName ~= nil and not analyticsSafe(stepName) then
				refuse(entry, "stepName")
			end
			checkFields(entry, fields)
			table.insert(ANALYTICS.funnel, entry)
			table.insert(ANALYTICS.all, entry)
		end,
	}
end

do
	local base = games.server
	local prodRun = nil
	games.server = {
		GetService = function(_self, name)
			if name == "AnalyticsService" then
				return AnalyticsStub
			end
			if name == "RunService" and PROD_SERVER then
				if prodRun == nil then
					prodRun = {}
					for key, value in base:GetService("RunService") do
						prodRun[key] = value
					end
					prodRun.IsStudio = function()
						return false
					end
				end
				return prodRun
			end
			return base:GetService(name)
		end,
		IsLoaded = function()
			return true
		end,
		Loaded = base.Loaded,
	}
end
PROD_SERVER = false

---------------------------------------------------------------- aides des scénarios a35
-- Champ custom d'un envoi (1 à 3), nil s'il n'y en a pas.
function fieldOf(entry, index)
	local fields = entry.fields
	return if fields then fields[string.format("CustomField%02d", index)] else nil
end
-- Envois d'économie d'un joueur (ou de tous), dans l'ordre.
function economyOf(player)
	local out = {}
	for _, e in ANALYTICS.economy do
		if player == nil or e.player == player then
			table.insert(out, e)
		end
	end
	return out
end
-- Événements custom de ce nom (et de ce joueur s'il est donné), dans l'ordre.
function eventsNamed(name, player)
	local out = {}
	for _, e in ANALYTICS.custom do
		if e.name == name and (player == nil or e.player == player) then
			table.insert(out, e)
		end
	end
	return out
end
function funnelOf(player)
	local out = {}
	for _, e in ANALYTICS.funnel do
		if e.player == player then
			table.insert(out, e)
		end
	end
	return out
end
function lastOf(list)
	return list[#list]
end
-- Tous les textes envoyés à Roblox (noms, monnaie, types, SKU, champs) : pour le contrôle des noms.
function sentTexts()
	local out = {}
	for _, e in ANALYTICS.all do
		for _, key in { "currency", "transaction", "sku", "name" } do
			if e[key] ~= nil then
				table.insert(out, e[key])
			end
		end
		if e.fields then
			for _, value in e.fields do
				table.insert(out, value)
			end
		end
	end
	return out
end
function flowName(entry)
	return if type(entry.flow) == "table" then entry.flow.Name else tostring(entry.flow)
end
