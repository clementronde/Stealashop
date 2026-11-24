---------------------------------------------------------------- a38 : compléments du faux Roblox (boutique Robux, DEV-100)
-- Ajouts au faux d'a36 (stubs.luau) et au complément d'a29 (ext29.luau) :
--   - énumérations utilisées par la boutique Robux, avec de vrais membres (Name, EnumType) :
--     ProductPurchaseDecision, MembershipType, InfoType ; les autres restent des textes (« Enum.X.Y ») ;
--   - MarketplaceService (faux), côté serveur et client : UserOwnsGamePassAsync (MARKET.owns, pannes
--     MARKET.ownsFails, délai MARKET.ownsDelay, appels notés dans MARKET.ownsCalls), fenêtres d'achat
--     PromptGamePassPurchase / PromptProductPurchase (notées dans MARKET.prompts), GetProductInfoAsync
--     (MARKET.info, appels dans MARKET.infoCalls), signal PromptGamePassPurchaseFinished, champ
--     ProcessReceipt (posé par le service) ; receipt(...) appelle ProcessReceipt dans une tâche et
--     note la réponse ;
--   - Player:Kick (DataService) : noté dans KICKS ; Humanoid.StateChanged (TrainingService) ;
--   - « prod » : PROD_SERVER = true avant startServer() fait répondre RunService:IsStudio() = false
--     aux modules du serveur ;
--   - faux ProfileStore (SOURCES["stub/ProfileStore"]) pour le vrai DataService : la session s'ouvre
--     après LOAD_DELAY s (jamais pour les clés de LOAD_NEVER), depuis SAVED[clé] (la DataStore) ou
--     PRESET_PROFILES[clé], sinon le modèle ; Save() écrit LastSavedData et SAVED après SAVE_DELAY s
--     puis déclenche OnAfterSave (rien si SAVE_FAILS) ; EndSession écrit SAVED (la sauvegarde de fin
--     de session) et ferme le profil.

-- Humanoid.StateChanged (TrainingService) : un signal comme les autres, jamais déclenché par le banc.
CLASS_EVENTS.StateChanged = true
-- Instance.DescendantRemoving (comptoir de RobuxShopController), jamais déclenché par le banc.
CLASS_EVENTS.DescendantRemoving = true

KICKS = {}
function Methods.Kick(self, message)
	table.insert(KICKS, { player = self, message = message })
end

do
	local baseEnum = Enum
	local MEMBERS = {
		ProductPurchaseDecision = { "NotProcessedYet", "PurchaseGranted" },
		MembershipType = { "None", "BuildersClub", "TurboBuildersClub", "OutrageousBuildersClub", "Premium" },
		InfoType = { "Asset", "Product", "GamePass", "Subscription", "Bundle" },
	}
	local enums = {}
	for enumName, names in MEMBERS do
		local items = {}
		for index, name in names do
			items[name] = setmetatable({ Name = name, Value = index - 1, EnumType = enumName }, {
				__type = "EnumItem",
				__tostring = function()
					return `Enum.{enumName}.{name}`
				end,
			})
		end
		enums[enumName] = setmetatable({}, {
			__index = function(_, key)
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
GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet

---------------------------------------------------------------- MarketplaceService
MARKET = {
	owns = {}, -- [UserId] = { [passId] = true }
	ownsFails = {}, -- [passId] = nombre de pannes restantes (erreur au lieu d'une réponse)
	ownsDelay = 0.1, -- s de réponse de Roblox
	ownsCalls = {}, -- { t, userId, passId, ok }
	prompts = {}, -- { t, kind = "GamePass" | "Product", player, id }
	info = {}, -- [id] = { PriceInRobux = n } ; absent : erreur
	infoCalls = {}, -- { t, id, infoType }
	receipts = {}, -- réponses de ProcessReceipt : { t, receipt, decision, done }
}
MarketplaceStub = {
	PromptGamePassPurchaseFinished = newSignal(),
	PromptProductPurchaseFinished = newSignal(),
	ProcessReceipt = nil,
}
function MarketplaceStub.UserOwnsGamePassAsync(_self, userId, passId)
	taskLib.wait(MARKET.ownsDelay)
	local fails = MARKET.ownsFails[passId] or 0
	if fails > 0 then
		MARKET.ownsFails[passId] = fails - 1
		table.insert(MARKET.ownsCalls, { t = now(), userId = userId, passId = passId, ok = false })
		error("HTTP 500 (Internal Server Error)", 0)
	end
	table.insert(MARKET.ownsCalls, { t = now(), userId = userId, passId = passId, ok = true })
	local list = MARKET.owns[userId]
	return list ~= nil and list[passId] == true
end
function MarketplaceStub.PromptGamePassPurchase(_self, player, id)
	table.insert(MARKET.prompts, { t = now(), kind = "GamePass", player = player, id = id })
end
function MarketplaceStub.PromptProductPurchase(_self, player, id)
	table.insert(MARKET.prompts, { t = now(), kind = "Product", player = player, id = id })
end
function MarketplaceStub.GetProductInfoAsync(_self, id, infoType)
	table.insert(MARKET.infoCalls, { t = now(), id = id, infoType = infoType })
	taskLib.wait(0.05)
	local info = MARKET.info[id]
	if info == nil then
		error("Product info unavailable", 0)
	end
	return table.clone(info)
end
-- Appelle ProcessReceipt comme Roblox (dans une tâche) ; renvoie l'entrée, complétée à la réponse.
local purchaseCount = 0
function receipt(player, productId, purchaseId)
	purchaseCount += 1
	local info = {
		PlayerId = if type(player) == "number" then player else player.UserId,
		ProductId = productId,
		PurchaseId = purchaseId or `P{purchaseCount}`,
		CurrencySpent = 0,
		CurrencyType = "Enum.CurrencyType.Robux",
		PlaceIdWherePurchased = 1,
	}
	local entry = { t = now(), receipt = info, decision = nil, done = false }
	table.insert(MARKET.receipts, entry)
	local handler = MarketplaceStub.ProcessReceipt
	if handler == nil then
		entry.decision = "pas de ProcessReceipt"
		entry.done = true
		return entry
	end
	taskLib.spawn(function()
		entry.decision = handler(info)
		entry.done = true
		entry.doneAt = now()
	end)
	return entry
end
-- Fin d'une fenêtre d'achat de gamepass (Roblox, côté serveur).
function finishPassPurchase(player, passId, wasPurchased)
	MarketplaceStub.PromptGamePassPurchaseFinished:Fire(player, passId, wasPurchased)
	flush()
end

do
	local prodRun = nil
	local function wrap(base, side)
		return {
			GetService = function(_self, name)
				if name == "MarketplaceService" then
					return MarketplaceStub
				end
				if name == "RunService" and side == "server" and PROD_SERVER then
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
	games.server = wrap(games.server, "server")
	games.client = wrap(games.client, "client")
	games.prod = wrap(games.prod, "prod")
end
PROD_SERVER = false

---------------------------------------------------------------- faux ProfileStore
PRESET_PROFILES = {}
SAVED = {}
SESSIONS = {}
LOAD_DELAY = 0
LOAD_NEVER = {}
SAVE_DELAY = 0.2
SAVE_FAILS = false
SAVE_CALLS = 0
SOURCES["stub/ProfileStore"] = [==[
local ProfileStore = { DataStoreState = "Access", IsClosing = false }
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
local function reconcile(target, template)
	for k, v in template do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(target[k]) == "table" and type(v) == "table" then
			reconcile(target[k], v)
		end
	end
end
function ProfileStore.New(_name, template)
	local store = {}
	function store.StartSessionAsync(_self, key, params)
		if LOAD_DELAY > 0 then
			task.wait(LOAD_DELAY)
		end
		if LOAD_NEVER[key] or (params and params.Cancel and params.Cancel()) then
			return nil
		end
		local source = SAVED[key]
		if source == nil then
			source = PRESET_PROFILES[key]
		end
		local data = deepCopy(if source ~= nil then source else template)
		local profile = { Data = data, Key = key, active = true, LastSavedData = deepCopy(data), OnAfterSave = newSignal(), OnSessionEnd = newSignal() }
		function profile.IsActive(self)
			return self.active
		end
		function profile.Reconcile(self)
			reconcile(self.Data, template)
		end
		function profile.AddUserId() end
		function profile.Save(self)
			SAVE_CALLS += 1
			if not self.active then
				return
			end
			task.delay(SAVE_DELAY, function()
				if SAVE_FAILS or not self.active then
					return
				end
				self.LastSavedData = deepCopy(self.Data)
				SAVED[key] = deepCopy(self.Data)
				self.OnAfterSave:Fire(self.LastSavedData)
			end)
		end
		function profile.EndSession(self)
			if not self.active then
				return
			end
			self.active = false
			SAVED[key] = deepCopy(self.Data)
		end
		SESSIONS[key] = profile
		return profile
	end
	return store
end
return ProfileStore
]==]
