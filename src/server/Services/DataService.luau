--!strict
-- DataService (DEV-004) : sauvegarde des joueurs avec ProfileStore (Partie 1, 9.1, 9.3, 9.5, 9.6).
--
-- Rôle : charge le profil d'un joueur à son arrivée (clé « Player_<UserId> »), le met à
-- la version courante du schéma (migrations), complète les champs manquants depuis le
-- modèle, puis le libère à son départ. ProfileStore pose un verrou de session : un profil
-- n'est actif que sur un seul serveur à la fois, ce qui empêche toute duplication.
-- Aucune donnée ne vient du client : ce service n'a aucun remote.
--
-- API (côté serveur uniquement) :
--   DataService.Get(player) -> Data?
--       Données du joueur si son profil est chargé et actif, sinon nil (toujours vérifier).
--       On lit et on modifie directement la table renvoyée ; ProfileStore la sauvegarde
--       (toutes les 5 min, au départ du joueur et à l'arrêt du serveur). Ne jamais garder
--       cette table après un yield sans rappeler Get : le profil a pu être libéré.
--   DataService.WaitFor(player, timeout?) -> Data?
--       Attend le chargement (yield) au plus `timeout` secondes (60 par défaut) ;
--       nil si le joueur part, si le chargement échoue ou si le délai est dépassé.
--   DataService.IsLoaded(player) -> boolean
--   DataService.OnProfileLoaded(listener) -> déconnexion
--       listener(player) est appelé pour chaque profil chargé, y compris ceux déjà
--       chargés au moment de l'abonnement (pas de course au démarrage). Il peut yield.
--   DataService.OnProfileReleasing(listener) -> déconnexion
--       listener(player) est appelé juste avant la libération du profil, quand le joueur
--       part : dernier moment pour écrire dans Get(player). Il ne doit pas yield.
--       À utiliser à la place de Players.PlayerRemoving pour toute écriture au départ.
--   DataService.AddCash(player, amount) -> number?
--       Ajoute `amount` (nombre fini ≥ 0) à l'argent ; renvoie le nouveau solde, ou nil
--       si le profil n'est pas chargé ou si le montant est invalide.
--   DataService.SpendCash(player, amount) -> boolean
--       Retire `amount` si le joueur l'a ; false sinon (rien n'est retiré).
--   DataService.OnCashChanged(listener) -> déconnexion
--       listener(player, cash) après chaque AddCash ou SpendCash (côté serveur).
--       L'argent ne se modifie que par AddCash et SpendCash.
--   DataService.Save(player) -> boolean
--       Demande tout de suite une sauvegarde du profil (Profile:Save de ProfileStore, lancée en
--       tâche de fond : sans yield ici) ; false si le profil n'est pas chargé. Pour une écriture qui
--       ne doit pas attendre la sauvegarde automatique (5 min) : le transfert d'un objet volé
--       (PvPService, 9.6 et 14.3), sauvegardé chez la victime puis chez le voleur.
--   DataService.SaveAsync(player, isSaved) -> boolean
--       Yield. Demande une sauvegarde et attend qu'elle soit écrite : true dès que
--       isSaved(saved) renvoie true, saved = la dernière version sauvegardée du profil
--       (Profile.LastSavedData de ProfileStore, à ne pas modifier) ; false si le profil se ferme
--       avant (joueur parti, session reprise) ou n'est pas chargé. Une sauvegarde ratée est reprise
--       par la sauvegarde automatique ou celle du départ : l'attente continue jusque-là. Pour les
--       achats Robux (9.6, MonetizationService) : PurchaseGranted seulement quand le PurchaseId est
--       sauvegardé, comme le recommande ProfileStore.
--
-- Attribut du Player (écrit seulement ici) : Cash, l'argent du profil, posé au chargement puis à
-- chaque AddCash ou SpendCash. Le HUD l'affiche (HudController, DEV-021) ; il ne sert qu'à
-- l'affichage : le code serveur lit Get(player).Cash.
--
-- Exemple (dans un autre service) :
--   local DataService = require(script.Parent.DataService)
--   DataService.OnProfileLoaded(function(player)
--       local data = DataService.Get(player)
--       if data then
--           print(player.Name, "a", data.Cash, "$")
--       end
--   end)
--   if DataService.SpendCash(player, price) then
--       -- l'achat est payé : donner l'objet
--   end
--
-- Studio : sans « Accès Studio aux services d'API », ProfileStore passe tout seul en mode
-- mock (rien n'est sauvegardé) ; ce service l'écrit dans la sortie au démarrage.
--
-- Versions du schéma : v1 = section 9.5 ; v2 (2026-11-07) = même forme, ItemId du catalogue
-- d'objets v2 (Config/Items, liaison L-045 ; voir MIGRATIONS[2]) ; v3 (2026-11-08, DEV-100) =
-- boutique Robux : Monetization et Boosts ajoutés, Purchases[PurchaseId] = date du don (voir
-- MIGRATIONS[3]) ; v4 (2026-11-08, DEV-111) = index des objets : Index[ItemId] = date de la
-- découverte (IndexService), les objets déjà possédés comptés comme découverts (voir MIGRATIONS[4]).
-- Nouvelle version du schéma (ex. v5 de la Partie 2) :
--   1. ajouter les champs dans Types/Profile et dans TEMPLATE ci-dessous ;
--   2. ajouter MIGRATIONS[5] (transforme un profil v4 en v5 ; ce qui est seulement
--      nouveau est complété depuis TEMPLATE, inutile de le recopier) ;
--   3. passer CURRENT_VERSION à 5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Config.Items)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)

local Server = (script.Parent :: Instance).Parent :: Instance
local ProfileStore = require(Server:WaitForChild("Packages"):WaitForChild("ProfileStore") :: ModuleScript) :: any

type Data = ProfileTypes.Data
export type PlayerListener = (player: Player) -> ()
export type CashListener = (player: Player, cash: number) -> ()

-- Ce que ce service utilise d'un profil ProfileStore.
type StoreProfile = {
	Data: Data,
	Key: string,
	LastSavedData: any, -- dernière version écrite dans la DataStore (lecture seule)
	IsActive: (self: StoreProfile) -> boolean,
	Save: (self: StoreProfile) -> (),
	Reconcile: (self: StoreProfile) -> (),
	EndSession: (self: StoreProfile) -> (),
	AddUserId: (self: StoreProfile, userId: number) -> (),
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> any },
	OnAfterSave: { Connect: (self: any, listener: (lastSavedData: any) -> ()) -> { Disconnect: (self: any) -> () } },
}

type Store = {
	StartSessionAsync: (self: Store, key: string, params: { Cancel: () -> boolean }) -> StoreProfile?,
}

-- Nom de la DataStore des joueurs. Ne jamais le changer : un autre nom = profils vides.
local STORE_NAME = "PlayerData"
-- Délai par défaut de WaitFor, en secondes. V0 proposé, absent du doc : ProfileStore
-- reprend une session bloquée sur un autre serveur au bout d'environ 40 s.
local DEFAULT_WAIT_TIMEOUT = 60

-- Version courante du schéma de sauvegarde (section 9.5 ; v2 : catalogue d'objets v2 ; v3 : boutique
-- Robux ; v4 : index des objets).
local CURRENT_VERSION = 4

-- Attribut du Player lu par le HUD (même nom dans HudController).
local CASH_ATTRIBUTE = "Cash"

-- Modèle d'un nouveau profil, schéma v4 (forme de la section 9.5, plus la boutique Robux et l'index).
-- Il sert aussi à compléter les champs manquants d'un profil existant (Profile:Reconcile de
-- ProfileStore).
local TEMPLATE: Data = {
	Version = CURRENT_VERSION,
	Cash = 0,
	Stats = { Speed = 0, Strength = 0 },
	Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 },
	Tools = { Owned = { "Fists" }, Equipped = "Fists" },
	Cosmetics = { Auras = {}, Trails = {}, EquippedAura = nil, EquippedTrail = nil },
	Items = {},
	Display = {},
	Vault = {},
	Boxes = {},
	Tutorial = { Step = 0, Done = false },
	Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 0 },
	Purchases = {}, -- [PurchaseId] = os.time() du don (MonetizationService)
	Monetization = { Passes = {}, StarterPack = false, OpenNowCredit = 0 }, -- v3
	Boosts = { Cash = 0 }, -- v3
	Index = {}, -- v4 : [ItemId] = os.time() de la découverte (IndexService)
}

-- Journal d'une migration : chaque ligne part dans la sortie, préfixée du joueur et de sa clé.
-- warning = true (orange) pour ce qui change la valeur d'un objet ou reste douteux.
type MigrationLog = (message: string, warning: boolean?) -> ()

type ItemIdChange = "Same" | "Renamed" | "Retired" | "Unknown" | "Invalid"

-- ItemId v2 d'un ItemId lu dans un profil v1 : inchangé s'il est au catalogue v2, renommé ou
-- remplacé s'il est dans Catalog.RenamedV1 ou Catalog.RetiredV1, gardé tel quel sinon.
local function itemIdV2(id: any): (any, ItemIdChange)
	if type(id) ~= "string" then
		return id, "Invalid"
	end
	if Catalog.ById[id] ~= nil then
		return id, "Same"
	end
	local renamed = Catalog.RenamedV1[id]
	if renamed then
		return renamed, "Renamed"
	end
	local replacement = Catalog.RetiredV1[id]
	if replacement then
		return replacement, "Retired"
	end
	return id, "Unknown"
end

-- Écrit le changement d'un ItemId ; `what` = « objet <uid> » ou « colis de l'établi <n> ».
-- `change` : un ItemIdChange (typé string : l'ancien solveur l'élargit après les comparaisons).
local function logItemId(log: MigrationLog, what: string, old: any, new: any, change: string)
	if change == "Renamed" then
		log(`{what} : {old} renommé {new} (catalogue v2)`)
	elseif change == "Retired" then
		log(`{what} : {old}, retiré du catalogue v2, remplacé par {new}`, true)
	elseif change == "Unknown" then
		log(`{what} : ItemId « {old} » inconnu du catalogue v2, gardé tel quel (ignoré par le jeu)`, true)
	elseif change == "Invalid" then
		log(`{what} : ItemId absent ou qui n'est pas un texte ({tostring(old)}), gardé tel quel`, true)
	end
end

-- v1 → v2 (catalogue d'objets v2, 2026-11-07, liaison L-045). Même forme de profil, seuls les
-- ItemId changent ; rien n'est effacé et chaque changement est écrit dans la sortie :
--   - Items[uid].Id : un ItemId renommé prend son nouveau nom (Z4_Montre → Z4_MontreEnOr,
--     Z5_Vase → Z5_VaseAncien) ; un ItemId retiré devient l'objet qui le remplace (règle dans
--     Config/Items, RetiredV1 : premier objet tirable de même zone et de même rareté, sinon de la
--     rareté la plus proche en dessous). L'objet garde son uid, sa source, son heure et sa zone ; sa
--     rareté suit le catalogue (Items ne la stocke pas) ;
--   - Boxes[n] : même règle pour ItemId, et Rarity remise à celle de l'objet au catalogue v2, pour
--     tous les colis (5.7 : la rareté d'un colis est celle de son objet ; plusieurs objets v1 ont
--     changé de rareté). ReadyAt ne change pas : l'attente promise reste la même ;
--   - un ItemId inconnu (ni au catalogue v2 ni dans ces tables) est gardé tel quel, avec un
--     avertissement : les services l'ignorent sans planter (DisplayService, UnboxService).
local function migrateToV2(data: any, log: MigrationLog)
	local items = data.Items
	if type(items) == "table" then
		for uid, entry in items do
			if type(entry) ~= "table" then
				log(`Items[{tostring(uid)}] n'est pas une table : gardé tel quel`, true)
				continue
			end
			local old = entry.Id
			local new, change = itemIdV2(old)
			if change == "Renamed" or change == "Retired" then
				entry.Id = new
			end
			logItemId(log, `objet {tostring(uid)}`, old, new, change)
		end
	end

	local boxes = data.Boxes
	if type(boxes) == "table" then
		for key, box in boxes do
			local what = `colis de l'établi {tostring(key)}`
			if type(box) ~= "table" then
				log(`{what} : n'est pas une table, gardé tel quel`, true)
				continue
			end
			local old = box.ItemId
			local new, change = itemIdV2(old)
			if change == "Renamed" or change == "Retired" then
				box.ItemId = new
			end
			logItemId(log, what, old, new, change)
			local item = if change == "Unknown" or change == "Invalid" then nil else Catalog.ById[new]
			if item and box.Rarity ~= item.Rarity then
				log(`{what} : rareté {tostring(box.Rarity)} remise à {item.Rarity}, celle de {item.Id} au catalogue v2`)
				box.Rarity = item.Rarity
			end
		end
	end
end

-- v2 → v3 (boutique Robux, 2026-11-08, DEV-100). Monetization et Boosts sont seulement nouveaux
-- (complétés depuis TEMPLATE). Purchases : la valeur devient la date du don (os.time()), pour que
-- MonetizationService borne l'historique en retirant les plus anciens ; un ancien true (jamais écrit
-- avant la v3) devient 0, le plus ancien. Un Purchases qui n'est pas une table (profil abîmé) repart
-- vide, avec un avertissement.
local function migrateToV3(data: any, log: MigrationLog)
	local purchases = data.Purchases
	if purchases == nil then
		return -- complété depuis TEMPLATE
	end
	if type(purchases) ~= "table" then
		log(`Purchases n'est pas une table ({tostring(purchases)}) : repart vide`, true)
		data.Purchases = {}
		return
	end
	local converted = 0
	for purchaseId, value in purchases do
		if type(value) ~= "number" then
			purchases[purchaseId] = 0
			converted += 1
		end
	end
	if converted > 0 then
		log(`Purchases : {converted} achat(s) au format v3 (date du don inconnue : 0)`)
	end
end

-- v3 → v4 (index des objets, 2026-11-08, DEV-111 ; IndexService). Index est nouveau : [ItemId] =
-- os.time() de la découverte. Tout objet du catalogue que le joueur possède déjà compte comme
-- découvert : ceux de Items, qui contient l'inventaire, les présentoirs et le coffre-fort (Display et
-- Vault n'y renvoient que par uid). Date : l'obtention de sa plus ancienne copie (At), maintenant si
-- elle est illisible. Ne comptent pas : un colis encore sur un établi (son objet reste caché jusqu'à
-- l'ouverture, 5.7) et un ItemId inconnu du catalogue. Un Index déjà là (jamais écrit avant la v4)
-- garde ses entrées lisibles ; un Index qui n'est pas une table repart vide, avec un avertissement.
local function migrateToV4(data: any, log: MigrationLog)
	local now = os.time()
	local index: { [string]: number } = {}
	local old = data.Index
	if type(old) == "table" then
		for itemId, at in old do
			if type(itemId) == "string" and Catalog.ById[itemId] ~= nil and type(at) == "number" and at == at then
				index[itemId] = at
			end
		end
	elseif old ~= nil then
		log(`Index n'est pas une table ({tostring(old)}) : repart vide`, true)
	end
	local counted = 0
	local items = data.Items
	if type(items) == "table" then
		for _, entry in items do
			local itemId = if type(entry) == "table" then entry.Id else nil
			if type(itemId) == "string" and Catalog.ById[itemId] ~= nil then
				local obtained = entry.At
				local at = if type(obtained) == "number" and obtained == obtained and obtained > 0 then obtained else now
				local known = index[itemId]
				if known == nil then
					counted += 1
					index[itemId] = at
				elseif at < known then
					index[itemId] = at
				end
			end
		end
	end
	data.Index = index
	if counted > 0 then
		log(`Index : {counted} objet(s) déjà possédé(s) compté(s) comme découvert(s)`)
	end
end

-- MIGRATIONS[n] fait passer un profil de la version n - 1 à la version n, en place, et écrit ce
-- qu'elle change avec `log`. Un profil sans Version est traité comme une version 0. La v1 est la
-- première : rien à transformer, Reconcile complète tout depuis TEMPLATE. Les champs seulement
-- nouveaux d'une version viennent de TEMPLATE, inutile de les recopier.
local MIGRATIONS: { [number]: (data: any, log: MigrationLog) -> () } = {
	[1] = function(_data: any, _log: MigrationLog) end,
	[2] = migrateToV2,
	[3] = migrateToV3,
	[4] = migrateToV4,
}

-- Messages d'expulsion, lus par le joueur : en anglais (L-036).
local MESSAGES = {
	LoadFailed = "Your save couldn't be loaded. Please come back in a moment.",
	SessionEnded = "Your game was closed on this server, probably because it opened on another one. Rejoin to keep playing.",
	TooNew = "The game was just updated. Join a new server to get your progress back.",
	MigrationFailed = "Your save couldn't be updated. Please come back in a moment. If it keeps happening, let us know.",
}

local DataService = {}
DataService.Priority = 1 -- démarre avant les autres services

local store: Store? = nil
local profiles: { [Player]: StoreProfile } = {}
local loading: { [Player]: boolean } = {}
local joinedAt: { [Player]: number } = {}
local loadedListeners: { PlayerListener } = {}
local releasingListeners: { PlayerListener } = {}
local cashListeners: { CashListener } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value :: any -- le nouveau solveur ne voit pas qu'une valeur affinée reste un T
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return (copy :: any) :: T
end

local function isSaving(): boolean
	return ProfileStore.DataStoreState == "Access"
end

local function kick(player: Player, message: string)
	if player.Parent == Players then
		player:Kick(message)
	end
end

-- Renvoie une fonction qui retire `listener` de `list`.
local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

-- Met `data` à la version courante. "TooNew" : profil écrit par une version plus
-- récente du jeu (serveur pas encore à jour) ; on n'y touche pas.
local function migrate(data: any, log: MigrationLog): "Ok" | "TooNew"
	local version = if type(data.Version) == "number" then data.Version else 0
	if version > CURRENT_VERSION then
		return "TooNew"
	end
	for target = version + 1, CURRENT_VERSION do
		local step = MIGRATIONS[target]
		if step == nil then
			error(`migration vers la v{target} absente`)
		end
		step(data, function(message: string, warning: boolean?)
			log(`migration v{target} : {message}`, warning)
		end)
		data.Version = target
	end
	return "Ok"
end

local function loadProfile(player: Player)
	if store == nil or loading[player] or profiles[player] then
		return
	end
	local activeStore = store :: Store
	loading[player] = true
	local key = `Player_{player.UserId}`

	local ok, result = pcall(function(): StoreProfile?
		return activeStore:StartSessionAsync(key, {
			-- Arrête d'essayer si le joueur est parti pendant le chargement.
			Cancel = function(): boolean
				return player.Parent ~= Players
			end,
		})
	end)
	loading[player] = nil

	if not ok then
		warn(`[DataService] {player.Name} ({key}) : erreur au chargement : {result}`)
		kick(player, MESSAGES.LoadFailed)
		return
	end
	local profile = result
	if profile == nil then
		-- Joueur parti, serveur en arrêt, ou session impossible à ouvrir (ProfileStore abandonne après 120 s).
		if player.Parent == Players then
			warn(`[DataService] {player.Name} ({key}) : session impossible à ouvrir`)
		end
		kick(player, MESSAGES.LoadFailed)
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	-- Migration sur une copie : en cas d'erreur, la sauvegarde d'origine reste intacte.
	local migrated = deepCopy(profile.Data)
	local function migrationLog(message: string, warning: boolean?)
		local line = `[DataService] {player.Name} ({key}) : {message}`
		if warning then
			warn(line)
		else
			print(line)
		end
	end
	local migrateOk, status = pcall(migrate, migrated, migrationLog)
	if not migrateOk then
		warn(`[DataService] {player.Name} ({key}) : échec de la migration : {status}`)
		profile:EndSession()
		kick(player, MESSAGES.MigrationFailed)
		return
	end
	if status == "TooNew" then
		warn(`[DataService] {player.Name} ({key}) : profil en v{profile.Data.Version}, ce serveur ne connaît que la v{CURRENT_VERSION}`)
		profile:EndSession()
		kick(player, MESSAGES.TooNew)
		return
	end
	profile.Data = migrated
	profile:Reconcile()
	profile:AddUserId(player.UserId)

	-- Fin de session sans départ du joueur : profil repris par un autre serveur.
	-- (À l'arrêt du serveur, Roblox expulse déjà tout le monde avec son propre message.)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		joinedAt[player] = nil
		if not ProfileStore.IsClosing then
			kick(player, MESSAGES.SessionEnded)
		end
	end)

	profiles[player] = profile
	joinedAt[player] = os.time()
	player:SetAttribute(CASH_ATTRIBUTE, profile.Data.Cash)
	local mode = if isSaving() then "" else ", mode mock : non sauvegardé"
	print(`[DataService] {player.Name} : profil {key} chargé (v{profile.Data.Version}{mode})`)

	for _, listener in table.clone(loadedListeners) do
		task.spawn(listener, player)
	end
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	for _, listener in table.clone(releasingListeners) do
		local ok, err = pcall(listener, player)
		if not ok then
			warn(`[DataService] OnProfileReleasing ({player.Name}) : {err}`)
		end
	end
	local started = joinedAt[player]
	if started and profile:IsActive() then
		profile.Data.Lifetime.PlaySeconds += math.max(0, os.time() - started)
	end
	profiles[player] = nil
	joinedAt[player] = nil
	profile:EndSession()
end

local function notifyCash(player: Player, cash: number)
	player:SetAttribute(CASH_ATTRIBUTE, cash)
	for _, listener in table.clone(cashListeners) do
		task.spawn(listener, player, cash)
	end
end

local function isValidAmount(amount: number): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

function DataService.Get(player: Player): Data?
	local profile = profiles[player]
	if profile ~= nil and profile:IsActive() then
		return profile.Data
	end
	return nil
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.Get(player) ~= nil
end

function DataService.WaitFor(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or DEFAULT_WAIT_TIMEOUT)
	while true do
		local data = DataService.Get(player)
		if data ~= nil then
			return data
		end
		-- Un chargement raté expulse le joueur : la boucle s'arrête alors aussi.
		if player.Parent ~= Players or os.clock() >= deadline then
			return nil
		end
		task.wait()
	end
end

function DataService.OnProfileLoaded(listener: PlayerListener): () -> ()
	local disconnect = subscribe(loadedListeners, listener)
	for player in table.clone(profiles) do
		if DataService.IsLoaded(player) then
			task.spawn(listener, player)
		end
	end
	return disconnect
end

function DataService.OnProfileReleasing(listener: PlayerListener): () -> ()
	return subscribe(releasingListeners, listener)
end

function DataService.OnCashChanged(listener: CashListener): () -> ()
	return subscribe(cashListeners, listener)
end

function DataService.AddCash(player: Player, amount: number): number?
	local data = DataService.Get(player)
	if data == nil or not isValidAmount(amount) then
		return nil
	end
	data.Cash += amount
	notifyCash(player, data.Cash)
	return data.Cash
end

function DataService.SpendCash(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if data == nil or not isValidAmount(amount) or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	notifyCash(player, data.Cash)
	return true
end

function DataService.Save(player: Player): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	local ok, err = pcall(function()
		profile:Save()
	end)
	if not ok then
		warn(`[DataService] {player.Name} : sauvegarde immédiate impossible : {err}`)
		return false
	end
	return true
end

function DataService.SaveAsync(player: Player, isSaved: (saved: any) -> boolean): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	local confirmed = false
	local function check(saved: any)
		if confirmed or type(saved) ~= "table" then
			return
		end
		local ok, result = pcall(isSaved, saved)
		confirmed = ok and result == true
	end
	check(profile.LastSavedData)
	if confirmed then
		return true
	end
	local connection = profile.OnAfterSave:Connect(check)
	local ok, err = pcall(function()
		profile:Save()
	end)
	if not ok then
		warn(`[DataService] {player.Name} : sauvegarde demandée impossible ({err}) : attente de la suivante`)
	end
	-- Profil fermé avant la confirmation (départ) : false, mais la sauvegarde de fin de session de
	-- ProfileStore contient quand même ce qui a été écrit dans Data.
	while not confirmed and profile:IsActive() do
		task.wait()
	end
	connection:Disconnect()
	return confirmed
end

function DataService.Init()
	for version = 1, CURRENT_VERSION do
		if MIGRATIONS[version] == nil then
			error(`[DataService] MIGRATIONS[{version}] manque pour CURRENT_VERSION = {CURRENT_VERSION}`)
		end
	end

	store = ProfileStore.New(STORE_NAME, TEMPLATE)

	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(releaseProfile)
	-- Joueurs arrivés avant le démarrage du service (Studio, Play rapide).
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

function DataService.Start()
	-- ProfileStore teste l'accès aux DataStores au lancement (en Studio, cela prend un instant).
	while ProfileStore.DataStoreState == "NotReady" do
		task.wait()
	end
	local state = ProfileStore.DataStoreState
	if state == "Access" then
		if RunService:IsStudio() then
			print(`[DataService] Studio avec accès aux services d'API : les profils sont réellement sauvegardés (DataStore « {STORE_NAME} » de cette expérience)`)
		else
			print(`[DataService] DataStore « {STORE_NAME} » actif`)
		end
	elseif state == "NoInternet" then
		warn("[DataService] pas d'accès Internet : mode mock de ProfileStore, aucune sauvegarde dans cette session")
	else
		warn("[DataService] Studio sans « Accès Studio aux services d'API » : mode mock de ProfileStore, aucune sauvegarde dans cette session. Pour tester la sauvegarde : Paramètres du jeu > Sécurité > Enable Studio Access to API Services.")
	end
end

return DataService
